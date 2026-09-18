-- ════════════════════════════════════════════════════════════════════════
-- LE FRANÇAIS DE LA PHRASE, REFAIT — 14-09, 08:10
--
-- Son verdict, mot pour mot, sur la première version (mesurée à l'écran) : « en français
-- c'est horrible, notamment début de séance et le vide ». Refait ici, même fonction,
-- mêmes contraintes (quatre fragments, clair / sourd / clair / sourd, ≤ 18 lettres, le
-- prénom dans le premier). Le principe : des mots qu'on dit, jamais une tournure écrite.
--
--   vide          Hey Kat, / prête pour / ta première ? / C'est parti.
--   active        Hey Kat, / déjà / 3 séances / cette semaine.
--   seance_debut  Allez Kat, / c'est parti, / la séance / est lancée.
--   seance        Allez Kat, / déjà / 12 minutes / dans les jambes.
--
-- L'anglais ne change pas. Le mot du 3e fragment suit le nombre : « 0 séance », « 1 séance »,
-- « 3 séances » ; « 1 minute », « 12 minutes ».
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
        then jsonb_build_array(v_salut, 'prête pour', 'ta première ?', 'C''est parti.')
        else jsonb_build_array(v_salut, 'your first workout', 'is waiting.', 'Let''s go.') end
    when 'active' then
      case when v_fr
        then jsonb_build_array(v_salut, 'déjà',
               p_n || case when p_n > 1 then ' séances' else ' séance' end, 'cette semaine.')
        else jsonb_build_array(v_salut, 'you''ve done',
               p_n || case when p_n = 1 then ' workout' else ' workouts' end, 'this week.') end
    when 'seance_debut' then
      case when v_fr
        then jsonb_build_array(v_salut, 'c''est parti,', 'la séance', 'est lancée.')
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
