-- ═══════════════════════════════════════════════════════════════════════════
-- LE MOTEUR DE FAITS : CE QU'UNE SÉANCE A ÉTÉ, ÉCRIT QUELQUE PART
-- ═══════════════════════════════════════════════════════════════════════════
--
-- VERDICT APPLIQUÉ (30-08, dicté) : « une story muscu et cardio particulière
-- qui arrive quand le user a fait une séance où il S'EST DÉPASSÉ — on prend la
-- meilleure de la semaine. Plus de séries ou plus de poids levé ; et cardio,
-- plus longtemps au HIIT ou de plus grande vitesse plus longtemps. Et la
-- deuxième séance, c'est DEUX SÉANCES LA MÊME JOURNÉE — il faut inscrire ça. »
--
-- Analyse : tools/story/ANALYSE-VARIANTS-ET-FAITS.md
-- Proposition : tools/story/PROPOSITION-BACKEND-FAITS.md
--
-- CE QUE ÇA DÉBLOQUE : les quatre variants de story sont écrits depuis des
-- semaines et AUCUN n'est déclenché — TOP, ×2 et la robe du butin sont
-- aujourd'hui trois drapeaux de banc, et le code le dit lui-même (« le vrai
-- déclencheur viendra du fact engine »). C'est le même manque qui empêche les
-- stickers d'analyser quoi que ce soit.
--
-- ⚠️ **L'APP CALCULE, LE SERVEUR RANGE** (tranché le 30-08, § 6 bis de
-- l'analyse). Deux lois du dépôt s'accordent : « l'écran ne doit jamais
-- attendre le réseau » — la story démarre 2 s après « Terminer », et le seul
-- appel de clôture part par l'outbox sans qu'on attende sa réponse — et « ce
-- qu'on ne croit jamais du client » vise ce qui PAIE. Un fait de story ne paie
-- rien : il choisit une page. Le jour où un fait donnera des pièces, CE
-- fait-là remontera au serveur.
--
-- ⚠️ **UN FAIT EST UN ESTAMPILLAGE, PAS UN CLASSEMENT VIVANT.** Une séance qui
-- a été la meilleure de sa semaine le RESTE, même si une autre la dépasse le
-- surlendemain — sinon une story déjà vue deviendrait fausse après coup. C'est
-- la loi des dates du chemin, appliquée aux faits.
-- ═══════════════════════════════════════════════════════════════════════════

-- ── 1. La table ────────────────────────────────────────────────────────────
--
-- ⚠️ `workout_id` N'A PAS DE CLÉ ÉTRANGÈRE, et c'est délibéré — exactement
-- comme `coin_ledger.workout_id`. Les faits partent par l'OUTBOX : ils peuvent
-- arriver AVANT que la séance elle-même n'ait été poussée. Une FK ferait
-- échouer l'écriture d'un fait pour une raison qui ne le concerne pas, et une
-- file qui échoue est une file qui se bouche.

create table if not exists public.workout_facts (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  workout_id  uuid not null,
  kind        text not null,
  -- EN QUOI elle s'est dépassée. Vide pour un `double_jour` : il n'y a rien à
  -- battre, il y a deux séances.
  mesure      text,
  -- Ce qu'elle a atteint, et ce qu'il fallait battre. Les deux, parce que la
  -- page doit pouvoir écrire « 12 séries — ton record de la semaine était 9 ».
  valeur      numeric,
  precedent   numeric,
  -- Le jour de la SÉANCE (pas celui de l'écriture) : c'est lui qui porte
  -- l'unicité du ×2.
  jour        date not null,
  -- Ce que la page dit et qui ne rentre pas dans un nombre. Pour le ×2 :
  -- {"heures":["07:12","19:40"],"minutes":114} — au champ près ce que
  -- `DoubleFait(heures:minutes:)` attend déjà côté app.
  detail      jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  -- ⚠️ La liste est écrite EN ENTIER : le jour où `record_charge` arrive, on
  -- recopie CETTE liste, jamais la première — c'est le piège qui a déjà rendu
  -- une migration inapplicable ici.
  constraint workout_facts_kind_check check (kind in (
    'top_muscu','top_cardio','double_jour')),
  constraint workout_facts_mesure_check check (mesure is null or mesure in (
    'series','volume_kg','hiit_secondes','vitesse_duree'))
);

alter table public.workout_facts enable row level security;

-- Lecture seule pour l'utilisateur : les écritures passent par la fonction.
do $$ begin
  create policy "chacun ne voit que ses faits" on public.workout_facts
    for select to authenticated using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;

-- ── 2. Les index — chacun empêche exactement une chose ─────────────────────

-- L'IDEMPOTENCE. C'est elle, et elle seule, qui rend le rejeu de l'outbox sûr :
-- une même séance ne porte jamais deux fois le même fait.
create unique index if not exists workout_facts_unique
  on public.workout_facts (user_id, workout_id, kind);

-- UN SEUL ×2 PAR JOUR : la troisième séance de la journée ne crée pas un
-- second « deuxième ».
create unique index if not exists workout_facts_double_jour_unique
  on public.workout_facts (user_id, jour)
  where kind = 'double_jour';

-- La lecture : « les faits de cette semaine », « ceux de ce jour ».
create index if not exists workout_facts_user_jour_idx
  on public.workout_facts (user_id, jour desc);

-- ── 3. Les règles, en base et pas dans du Swift ────────────────────────────

insert into public.reward_rules (key, value) values
  -- Il suffit d'en battre UNE : une séance courte mais très lourde se dépasse
  -- autant qu'une longue et légère.
  ('top_mesures_muscu',  '["series","volume_kg"]'::jsonb),
  ('top_mesures_cardio', '["hiit_secondes","vitesse_duree"]'::jsonb),
  -- La « semaine », glissante.
  ('top_fenetre_jours',  '7'::jsonb),
  -- ⚠️ SANS LUI, LA PREMIÈRE SÉANCE DE LA SEMAINE EST MÉCANIQUEMENT LA
  -- MEILLEURE, et la page TOP se déclencherait un lundi sur deux pour une
  -- séance ordinaire. Se dépasser suppose un précédent.
  ('top_min_seances',    '2'::jsonb)
on conflict (key) do update set value = excluded.value;

-- ── 4. L'ACTE : « cette séance est close, voici ses faits » ────────────────
--
-- Une fonction par ACTE, pas par table : un fait seul n'a pas de sens, et deux
-- appels laisseraient un état à moitié rangé.

create or replace function public.poser_faits_seance(
  p_workout uuid,
  p_jour    date,
  p_faits   jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  f         jsonb;
  v_poses   integer := 0;
  v_connus  integer := 0;
  v_ignores integer := 0;
begin
  if p_workout is null or p_jour is null then
    raise exception 'poser_faits_seance : il faut la séance et son jour';
  end if;

  for f in select * from jsonb_array_elements(coalesce(p_faits, '[]'::jsonb))
  loop
    -- ⚠️ **UN `kind` INCONNU EST IGNORÉ, PAS REFUSÉ.** Une version d'app plus
    -- récente qui posterait un fait que ce serveur ne connaît pas encore
    -- déclencherait une violation de `check` → 500 → et l'outbox garderait la
    -- ligne pour toujours : la file se boucherait sur un fait décoratif. On
    -- range ce qu'on comprend, on compte le reste.
    if (f->>'kind') is null
       or (f->>'kind') not in ('top_muscu','top_cardio','double_jour') then
      v_ignores := v_ignores + 1;
      continue;
    end if;

    begin
      insert into public.workout_facts
        (user_id, workout_id, kind, mesure, valeur, precedent, jour, detail)
      values (
        auth.uid(), p_workout, f->>'kind',
        -- Même raison : une mesure inconnue ne fait pas tomber le fait, elle
        -- devient nulle. Le fait « elle s'est dépassée » vaut mieux que rien.
        case when (f->>'mesure') in ('series','volume_kg',
                                     'hiit_secondes','vitesse_duree')
             then f->>'mesure' else null end,
        nullif(f->>'valeur','')::numeric,
        nullif(f->>'precedent','')::numeric,
        p_jour,
        coalesce(f->'detail', '{}'::jsonb));
      v_poses := v_poses + 1;
    exception
      when unique_violation then
        -- Déjà rangé. ⚠️ Ce n'est PAS une erreur : l'outbox doit pouvoir
        -- rejouer sans savoir, et une erreur métier rend 200 avec un motif,
        -- jamais un 500.
        v_connus := v_connus + 1;
      when invalid_text_representation then
        -- Un nombre illisible ne bouche pas la file non plus.
        v_ignores := v_ignores + 1;
    end;
  end loop;

  return jsonb_build_object('poses',   v_poses,
                            'connus',  v_connus,
                            'ignores', v_ignores);
end $$;

grant execute on function public.poser_faits_seance(uuid, date, jsonb)
  to authenticated;

-- ── Retour arrière ─────────────────────────────────────────────────────────
-- ⚠️ Le Down retire la FONCTION, jamais les LIGNES : un fait rangé est arrivé,
-- et on ne rembobine pas ce qui s'est passé.
--   drop function if exists public.poser_faits_seance(uuid, date, jsonb);
