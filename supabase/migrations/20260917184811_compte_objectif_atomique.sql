-- Compte : une inscription refusee ne modifie ni profil ni objectif.
-- Regression mesuree : tools/serveur/verif_compte.py (objectif 99).

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
  -- Refuser AVANT l'upsert : definir_objectif rend un refus métier en JSON,
  -- que l'ancien PERFORM ignorait en terminant pourtant l'inscription.
  if p_objectif_hebdo is not null and (p_objectif_hebdo < 1 or p_objectif_hebdo > 14) then
    return jsonb_build_object('ok', false, 'raison', 'hors_bornes', 'min', 1, 'max', 14);
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

revoke execute on function public.definir_profil(text, text, text, integer, boolean) from public, anon;
grant execute on function public.definir_profil(text, text, text, integer, boolean) to authenticated;
