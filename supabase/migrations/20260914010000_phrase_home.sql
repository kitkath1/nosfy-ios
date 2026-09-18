-- ════════════════════════════════════════════════════════════════════════
-- LA PHRASE DE LA HOME, EN DEUX LANGUES, SERVIE PAR home() — 14-09, 06:00
--
-- Kathryn (relayée par la session porte) : « notifie la session backend de faire
-- anglais / français déjà pour les variants de la Home en mode empty, active et en
-- cours (la noire) » — et sur le wording français : « il faut que ça soit harmonieux
-- en UI, en ligne et en mot ». La règle du 13-09 (b-po-langue-serveur) s'applique :
-- un texte servi à la personne naît dans SA langue (profils.langue, « fr » sinon),
-- l'app ne traduit jamais.
--
-- LA FORME est un contrat dur (HomeNuit.PhraseTexte) : QUATRE fragments — clair /
-- sourd / clair / sourd, la fin sur un sourd — chaque fragment ≤ 300 pt à 30 pt Inter
-- semibold (≈ 18 lettres), le prénom dans le premier. Le plus long fragment ici :
-- « you've been at it » (17), déjà mesuré à l'écran.
--
-- TROIS ÉTATS, décidés ICI (une seule vérité, la même que premiere_fois / en_seance) :
--   vide    — onboarding fini, aucune séance finie
--   active  — N séances finies cette semaine (N ≥ 0 : la phrase compte, même à 0)
--   seance  — une séance poussée sans fin (minutes_en_seance)
-- home() rend `phrase` {etat, fragments[4]} ET `phrases` {vide, active, seance,
-- seance_debut} pour que l'app puisse aussi composer localement (le compte du
-- téléphone, les minutes qui courent) sans un appel par minute.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.phrase_home(
  p_etat text,            -- 'vide' | 'active' | 'seance' | 'seance_debut'
  p_langue text,
  p_prenom text,
  p_n integer default 0)  -- séances (active) ou minutes (seance)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_fr boolean := coalesce(p_langue, 'fr') <> 'en';
  v_qui text := nullif(btrim(coalesce(p_prenom, '')), '');
  v_salut text;
begin
  -- Le premier fragment porte le prénom ; sans prénom, la phrase reste vraie.
  if p_etat in ('seance', 'seance_debut') then
    v_salut := case when v_fr then coalesce('Allez ' || v_qui || ',', 'Allez,')
                    else coalesce('Alright ' || v_qui || ',', 'Alright,') end;
  else
    v_salut := case when v_fr then coalesce('Salut ' || v_qui || ',', 'Salut,')
                    else coalesce('Hello ' || v_qui || ',', 'Hello there,') end;
  end if;

  return case p_etat
    when 'vide' then
      case when v_fr
        then jsonb_build_array(v_salut, 'ta première séance', 't''attend.', 'On y va.')
        else jsonb_build_array(v_salut, 'your first workout', 'is waiting.', 'Let''s go.') end
    when 'active' then
      case when v_fr
        then jsonb_build_array(v_salut, 'tu as fait',
               p_n || case when p_n = 1 then ' séance' else ' séances' end, 'cette semaine.')
        else jsonb_build_array(v_salut, 'you''ve done',
               p_n || case when p_n = 1 then ' workout' else ' workouts' end, 'this week.') end
    when 'seance_debut' then
      case when v_fr
        then jsonb_build_array(v_salut, 'tu es en', 'pleine séance', 'là, maintenant.')
        else jsonb_build_array(v_salut, 'you''re in', 'a session', 'right now.') end
    else -- 'seance'
      case when v_fr
        then jsonb_build_array(v_salut, 'tu tiens depuis',
               p_n || case when p_n = 1 then ' minute' else ' minutes' end, 'déjà.')
        else jsonb_build_array(v_salut, 'you''ve been at it',
               p_n || case when p_n = 1 then ' minute' else ' minutes' end, 'so far.') end
  end;
end;
$$;
comment on function public.phrase_home(text, text, text, integer) is
  'La phrase de la home : QUATRE fragments (clair/sourd/clair/sourd, fin sur un sourd, ≤ 18 lettres chacun), dans la langue donnée (fr sauf en), le prénom dans le premier. États : vide (aucune séance finie), active (n séances cette semaine), seance (n minutes), seance_debut (< 1 min). Pure : l''app peut la rappeler par home().phrases.';

-- home() rend la phrase de l'état courant et les quatre variantes
create or replace function public.home()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_uid uuid := auth.uid();
  p public.profils%rowtype;
  r jsonb;
  v_enc timestamptz;
  v_total integer;
  v_langue text;
  v_min integer;
  v_etat text;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  r := public.widget_regularite('semaine');
  select w.started_at into v_enc from public.workouts w
   where w.user_id = v_uid and w.ended_at is null order by w.started_at desc limit 1;
  select count(*) into v_total from public.workouts w where w.user_id = v_uid and w.ended_at is not null;
  v_langue := coalesce(nullif(p.langue, ''), 'fr');
  v_min := case when v_enc is null then 0 else floor(extract(epoch from (now() - v_enc)) / 60)::int end;
  -- L'ÉTAT DE LA PHRASE, une seule vérité : en séance > première fois > active.
  v_etat := case
    when v_enc is not null and v_min < 1 then 'seance_debut'
    when v_enc is not null then 'seance'
    when p.onboarding_termine_at is not null and v_total = 0 then 'vide'
    else 'active' end;
  return jsonb_build_object(
    'prenom',             p.prenom,
    'langue',             v_langue,
    'premiere_fois',      p.onboarding_termine_at is not null and v_total = 0,
    'visite_home',        p.visite_home_le is not null,
    'onboarding_termine', p.onboarding_termine_at is not null,
    'faites',             r->'faites',
    'objectif',           r->'objectif',
    'reste',              r->'reste',
    'en_seance',          v_enc is not null,
    'minutes_en_seance',  v_min,
    'derniere_seance_at', (select max(w.ended_at) from public.workouts w where w.user_id = v_uid and w.ended_at is not null),
    'seances_total',      v_total,
    -- 14-09 : LA PHRASE (l'état courant) et ses quatre variantes, dans la langue du profil
    'phrase', jsonb_build_object(
      'etat', v_etat,
      'fragments', public.phrase_home(v_etat, v_langue, p.prenom,
                     case when v_etat = 'active' then (r->>'faites')::int else v_min end)),
    'phrases', jsonb_build_object(
      'vide',         public.phrase_home('vide', v_langue, p.prenom, 0),
      'active',       public.phrase_home('active', v_langue, p.prenom, coalesce((r->>'faites')::int, 0)),
      'seance_debut', public.phrase_home('seance_debut', v_langue, p.prenom, 0),
      'seance',       public.phrase_home('seance', v_langue, p.prenom, greatest(v_min, 1)))
  );
end;
$function$;
