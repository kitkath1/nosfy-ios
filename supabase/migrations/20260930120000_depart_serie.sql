-- ════════════════════════════════════════════════════════════════════════
-- LE DÉPART DE SÉRIE — 30-09-2026 (session Réglages)
--
-- Verdict de Kathryn, 30-09 : « rajoute un onglet Réglages : la langue, et en
-- dessous le format de départ de série — le user peut choisir le galet blanc
-- ou le slider », puis « il faut ajouter la règle backend aussi, qui transforme
-- l'app avec le slider ou le galet ». Le choix suit donc le COMPTE (comme la
-- langue), pas le téléphone : une réinstallation ou un autre iPhone le retrouve.
--
-- Même forme, à la lettre, que l'objectif hebdo (20260905110000) :
--   ① la préférence vit dans `user_prefs`, une ligne par compte — une
--      préférence de personne n'est pas une règle du jeu ;
--   ② le DÉFAUT, lui, est une règle du jeu (`depart_serie_defaut`) : il vaut
--      pour qui n'a jamais choisi, et il se change en une ligne. Décision D1 du
--      plan : le slider (« enlever le galet »), le galet reste au choix.
--
-- `null` dans la colonne = jamais choisi → le défaut. On ne matérialise pas le
-- défaut dans la ligne : le jour où la règle change, ceux qui n'ont jamais
-- choisi suivent.
--
-- Plan : tools/reglages/PLAN-REGLAGES-2026-09-30.md
-- ════════════════════════════════════════════════════════════════════════

-- ── ② le défaut, règle du jeu ──────────────────────────────────────────
insert into public.reward_rules (key, value)
values ('depart_serie_defaut', '"slider"'::jsonb)
on conflict (key) do nothing;

-- ── ① la préférence, dans la ligne du compte ───────────────────────────
-- ⚠️ La colonne est posée AVANT les fonctions qui la lisent (piège ③).
alter table public.user_prefs
  add column if not exists depart_serie text;

do $$
begin
  if not exists (select 1 from pg_constraint
                  where conname = 'user_prefs_depart_serie_valeurs') then
    alter table public.user_prefs
      add constraint user_prefs_depart_serie_valeurs
      check (depart_serie is null or depart_serie in ('galet', 'slider'));
  end if;
end $$;

comment on column public.user_prefs.depart_serie is
  'Le format de départ de série choisi dans Réglages : « galet » (le galet blanc, le monde blanc, le sommet) ou « slider » (le slider obsidienne, droit sur le chrono). null = jamais choisi → reward_rules.depart_serie_defaut.';

-- ── LA LECTURE : le choix, sinon le défaut ─────────────────────────────
-- jsonb et jamais un texte nu : le client lit un objet, comme partout.
-- `choisi` dit si la valeur vient de la personne ou de la règle.
create or replace function public.depart_serie()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'ok', auth.uid() is not null,
    'depart_serie', coalesce(
       (select p.depart_serie from public.user_prefs p where p.user_id = auth.uid()),
       (select r.value #>> '{}' from public.reward_rules r where r.key = 'depart_serie_defaut'),
       'slider'),
    'choisi', exists (select 1 from public.user_prefs p
                       where p.user_id = auth.uid() and p.depart_serie is not null));
$$;

-- ── L'ÉCRITURE : un acte, idempotent par construction ──────────────────
-- Un format inconnu est une erreur MÉTIER : 200 avec un motif, jamais un raise
-- (un 500 ne se distingue pas d'un serveur cassé).
-- ⚠️ L'insert d'une ligne neuve pose `objectif_hebdo` à la valeur EFFECTIVE
-- (`objectif_hebdo()`, le défaut pour qui n'a jamais choisi) : la colonne est
-- `not null`, et c'est la seule valeur qui ne change rien à ce que la
-- personne voit. Une ligne existante garde son objectif intact.
create or replace function public.definir_depart_serie(p_format text)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'raison', 'sans_session');
  end if;
  if p_format is null or p_format not in ('galet', 'slider') then
    return jsonb_build_object('ok', false, 'raison', 'format_inconnu',
                              'formats', jsonb_build_array('galet', 'slider'),
                              'depart_serie', public.depart_serie() -> 'depart_serie');
  end if;

  insert into public.user_prefs (user_id, objectif_hebdo, depart_serie, updated_at)
  values (v_uid, public.objectif_hebdo(), p_format, now())
  on conflict (user_id) do update
    set depart_serie = excluded.depart_serie,
        updated_at   = now();

  -- on rend le nouvel état : l'appelante vient d'écrire, elle ne doit pas
  -- avoir à re-demander pour savoir où elle en est.
  return jsonb_build_object('ok', true, 'depart_serie', p_format, 'choisi', true);
end;
$$;

revoke all on function public.depart_serie()               from public, anon;
revoke all on function public.definir_depart_serie(text)   from public, anon;
grant execute on function public.depart_serie()             to authenticated;
grant execute on function public.definir_depart_serie(text) to authenticated;
