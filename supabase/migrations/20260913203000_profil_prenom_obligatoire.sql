-- ════════════════════════════════════════════════════════════════════════
-- LE PRÉNOM EST OBLIGATOIRE POUR FINIR L'ONBOARDING — 13-09 nuit
--
-- Règle de Kathryn, mot pour mot (relayée par la session porte) : « le user ne
-- peut pas passer le prénom, donc pas de skip, mais un message qui devient
-- rouge dans l'input s'il tape à côté ». Côté serveur, trois conséquences :
--  · `definir_profil(…, p_onboarding_termine = true)` REFUSE un prénom nul ou
--    vide (espaces compris) quand le profil n'en a pas déjà un → 200
--    {ok false, raison 'prenom_requis'}, rien n'est écrit ;
--  · une fois l'onboarding terminé, `profils.prenom` ne peut plus être nul ni
--    vide : contrainte CHECK, la base refuse même un écrivain direct ;
--  · le prénom est rangé sans espaces autour (btrim).
-- Même signature, mêmes droits (CREATE OR REPLACE garde les privilèges ; anon
-- reste révoqué par 20260913201000).
-- ════════════════════════════════════════════════════════════════════════

alter table public.profils drop constraint if exists profils_prenom_si_termine;
alter table public.profils add constraint profils_prenom_si_termine
  check (onboarding_termine_at is null or (prenom is not null and btrim(prenom) <> ''));

comment on constraint profils_prenom_si_termine on public.profils is
  'Onboarding terminé ⇒ prénom non nul et non vide (règle du 13-09 : pas de skip du prénom).';

create or replace function public.definir_profil(
  p_langue text default null,
  p_prenom text default null,
  p_but text default null,
  p_objectif_hebdo integer default null,
  p_onboarding_termine boolean default true)
returns jsonb
language plpgsql
volatile
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_prenom text := nullif(btrim(coalesce(p_prenom, '')), '');
  v_existant text;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'raison', 'sans_session');
  end if;
  select nullif(btrim(coalesce(prenom, '')), '') into v_existant
    from public.profils where user_id = v_uid;
  -- LA RÈGLE : finir l'onboarding sans prénom, ni donné ni déjà là → refus.
  if p_onboarding_termine and v_prenom is null and v_existant is null then
    return jsonb_build_object('ok', false, 'raison', 'prenom_requis');
  end if;
  insert into public.profils (user_id, langue, prenom, but, onboarding_termine_at, updated_at)
  values (v_uid, p_langue, v_prenom, p_but,
          case when p_onboarding_termine then now() else null end, now())
  on conflict (user_id) do update
    set langue     = coalesce(excluded.langue, profils.langue),
        prenom     = coalesce(excluded.prenom, profils.prenom),
        but        = coalesce(excluded.but, profils.but),
        onboarding_termine_at = coalesce(profils.onboarding_termine_at, excluded.onboarding_termine_at),
        updated_at = now();
  if p_objectif_hebdo is not null then
    perform public.definir_objectif(p_objectif_hebdo);
  end if;
  return public.profil() || jsonb_build_object('ok', true);
end;
$$;

comment on function public.definir_profil(text, text, text, integer, boolean) is
  'La fin du questionnaire en UN appel : upsert du profil (null ne vide rien, prénom rangé sans espaces), relais de l''objectif à definir_objectif (user_prefs, 1..14), date de fin d''onboarding posée une fois. REFUSE {ok:false, raison:prenom_requis} un onboarding terminé sans prénom (règle du 13-09). Rend profil() + ok.';
