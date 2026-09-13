-- ════════════════════════════════════════════════════════════════════════
-- LE PRÉNOM OBLIGATOIRE, SANS CASSER LES COMPLÉMENTS — 13-09 nuit, mesuré
-- dans la foulée de 20260913203000 : `definir_profil(p_but => 'courir')` sur
-- un profil terminé qui AVAIT un prénom rendait 23514 « violates check
-- constraint profils_prenom_si_termine ». Cause : Postgres vérifie le CHECK
-- sur la ligne CANDIDATE de l'INSERT avant de voir le conflit — et cette
-- ligne portait prenom null + date de fin. Le DO UPDATE aurait gardé le
-- prénom, mais on n'y arrivait jamais.
--
-- Remède : la ligne candidate est construite avec ce que le profil a déjà
-- (prénom, langue, but, date) — elle est donc toujours valide ; le refus
-- « prenom_requis » reste le seul chemin de sortie sans prénom.
-- ════════════════════════════════════════════════════════════════════════

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
  ex public.profils%rowtype;
begin
  if v_uid is null then
    return jsonb_build_object('ok', false, 'raison', 'sans_session');
  end if;
  select * into ex from public.profils where user_id = v_uid;
  -- LA RÈGLE (13-09) : finir l'onboarding sans prénom, ni donné ni déjà là → refus.
  if p_onboarding_termine and v_prenom is null
     and nullif(btrim(coalesce(ex.prenom, '')), '') is null then
    return jsonb_build_object('ok', false, 'raison', 'prenom_requis');
  end if;
  insert into public.profils (user_id, langue, prenom, but, onboarding_termine_at, updated_at)
  values (v_uid,
          coalesce(p_langue, ex.langue),
          coalesce(v_prenom, ex.prenom),
          coalesce(p_but, ex.but),
          coalesce(ex.onboarding_termine_at, case when p_onboarding_termine then now() else null end),
          now())
  on conflict (user_id) do update
    set langue     = excluded.langue,
        prenom     = excluded.prenom,
        but        = excluded.but,
        onboarding_termine_at = excluded.onboarding_termine_at,
        updated_at = now();
  if p_objectif_hebdo is not null then
    perform public.definir_objectif(p_objectif_hebdo);
  end if;
  return public.profil() || jsonb_build_object('ok', true);
end;
$$;
