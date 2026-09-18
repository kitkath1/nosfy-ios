-- ════════════════════════════════════════════════════════════════════════
-- LA PHRASE : LE ZÉRO A SA PHRASE, LE VIDE SANS GENRE, LE DÉBUT SANS REDITE — 14-09, 08:15
--
-- Mesuré à l'écran après 020000 : « Hey Kat, / déjà / 0 séances / cette semaine. » —
-- « déjà » avec zéro ne se dit pas, et le 3e fragment est composé par l'app avec le
-- compte du téléphone. Donc :
--   · `active` à 0 a SA phrase (fr « pas encore / de séance / cette semaine. »,
--     en « no workout yet / this week. / Let's go. ») ;
--   · `phrases.active` est un GABARIT compté (n ≥ 1) dont l'app remplace le 3e fragment,
--     `phrases.active_zero` la phrase du zéro ; `phrase` (l'état courant) reste exacte.
-- Le vide, sans adjectif genré (le profil n'a pas de genre, décision du 05-09) :
--   « Hey Kat, / et si on faisait / ta première / séance ? »
-- Le début de séance, sans redite : « Allez Kat, / on y est, / la séance / commence. »
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.phrase_home(
  p_etat text,
  p_langue text,
  p_prenom text,
  p_n integer default 0)
returns jsonb
language plpgsql
immutable
as $$
declare
  v_fr boolean := coalesce(p_langue, 'fr') <> 'en';
  v_qui text := nullif(btrim(coalesce(p_prenom, '')), '');
  v_salut text;
begin
  if p_etat in ('seance', 'seance_debut') then
    v_salut := case when v_fr then coalesce('Allez ' || v_qui || ',', 'Allez,')
                    else coalesce('Alright ' || v_qui || ',', 'Alright,') end;
  else
    v_salut := case when v_fr then coalesce('Hey ' || v_qui || ',', 'Hey,')
                    else coalesce('Hello ' || v_qui || ',', 'Hello there,') end;
  end if;

  return case p_etat
    when 'vide' then
      case when v_fr
        then jsonb_build_array(v_salut, 'et si on faisait', 'ta première', 'séance ?')
        else jsonb_build_array(v_salut, 'your first workout', 'is waiting.', 'Let''s go.') end
    when 'active' then
      case
        when p_n <= 0 and v_fr then jsonb_build_array(v_salut, 'pas encore', 'de séance', 'cette semaine.')
        when p_n <= 0 then jsonb_build_array(v_salut, 'no workout yet', 'this week.', 'Let''s go.')
        when v_fr then jsonb_build_array(v_salut, 'déjà',
               p_n || case when p_n > 1 then ' séances' else ' séance' end, 'cette semaine.')
        else jsonb_build_array(v_salut, 'you''ve done',
               p_n || case when p_n = 1 then ' workout' else ' workouts' end, 'this week.') end
    when 'seance_debut' then
      case when v_fr
        then jsonb_build_array(v_salut, 'on y est,', 'la séance', 'commence.')
        else jsonb_build_array(v_salut, 'you''re in', 'a session', 'right now.') end
    else
      case when v_fr
        then jsonb_build_array(v_salut, 'déjà',
               p_n || case when p_n > 1 then ' minutes' else ' minute' end, 'dans les jambes.')
        else jsonb_build_array(v_salut, 'you''ve been at it',
               p_n || case when p_n = 1 then ' minute' else ' minutes' end, 'so far.') end
  end;
end;
$$;

-- home() : `phrases.active` devient un gabarit compté (n ≥ 1), `phrases.active_zero` s'ajoute.
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
  v_faites integer;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  r := public.widget_regularite('semaine');
  v_faites := coalesce((r->>'faites')::int, 0);
  select w.started_at into v_enc from public.workouts w
   where w.user_id = v_uid and w.ended_at is null order by w.started_at desc limit 1;
  select count(*) into v_total from public.workouts w where w.user_id = v_uid and w.ended_at is not null;
  v_langue := coalesce(nullif(p.langue, ''), 'fr');
  v_min := case when v_enc is null then 0 else floor(extract(epoch from (now() - v_enc)) / 60)::int end;
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
    'phrase', jsonb_build_object(
      'etat', v_etat,
      'fragments', public.phrase_home(v_etat, v_langue, p.prenom,
                     case when v_etat = 'active' then v_faites else v_min end)),
    'phrases', jsonb_build_object(
      'vide',         public.phrase_home('vide', v_langue, p.prenom, 0),
      'active',       public.phrase_home('active', v_langue, p.prenom, greatest(v_faites, 1)),
      'active_zero',  public.phrase_home('active', v_langue, p.prenom, 0),
      'seance_debut', public.phrase_home('seance_debut', v_langue, p.prenom, 0),
      'seance',       public.phrase_home('seance', v_langue, p.prenom, greatest(v_min, 1)))
  );
end;
$function$;
