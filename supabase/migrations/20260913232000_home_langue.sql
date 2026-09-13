-- ════════════════════════════════════════════════════════════════════════
-- LA LANGUE, RENDUE PAR home() — 13-09 soir (Kathryn : « fais déjà dans la documentation
-- la mécanique de langue et notifie au backend de gérer ça »).
--
-- La règle : la langue de la personne vit dans `profils.langue` (écrite par
-- `definir_profil(p_langue)` à la fin de Nosfy, et depuis le Profil) ; `home()` la rend
-- à chaque apparition de la home — le serveur gagne, l'app n'en garde qu'un cache
-- (`woop.langue`). Un compte sans langue = « fr ». Et TOUT texte que le serveur écrira
-- pour la personne (phrases de la home, annonces, stories, mots géants) naîtra dans
-- cette langue : l'app ne traduit jamais un texte serveur.
-- Reprise de la définition VIVE de home() (pg_get_functiondef), une clé ajoutée.
-- ════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.home()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  p public.profils%rowtype;
  r jsonb;
  v_enc timestamptz;
  v_total integer;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  r := public.widget_regularite('semaine');
  select w.started_at into v_enc from public.workouts w
   where w.user_id = v_uid and w.ended_at is null order by w.started_at desc limit 1;
  select count(*) into v_total from public.workouts w where w.user_id = v_uid and w.ended_at is not null;
  return jsonb_build_object(
    'prenom',             p.prenom,
    -- 13-09 (langue, sa demande : « le serveur gagne, comme le prénom ») : la langue du profil, 'fr' par défaut
    'langue',             coalesce(nullif(p.langue, ''), 'fr'),
    -- 13-09 : la première arrivée (onboarding fini, aucune séance) et la visite guidée
    'premiere_fois',      p.onboarding_termine_at is not null and v_total = 0,
    'visite_home',        p.visite_home_le is not null,
    'onboarding_termine', p.onboarding_termine_at is not null,
    'faites',             r->'faites',
    'objectif',           r->'objectif',
    'reste',              r->'reste',
    'en_seance',          v_enc is not null,
    'minutes_en_seance',  case when v_enc is null then 0 else floor(extract(epoch from (now() - v_enc)) / 60)::int end,
    'derniere_seance_at', (select max(w.ended_at) from public.workouts w where w.user_id = v_uid and w.ended_at is not null),
    'seances_total',      v_total
  );
end;
$function$
;
