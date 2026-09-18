-- « 0 séance » : en français le zéro reste au singulier (14-09, dans la foulée de 010000,
-- mesuré : la phrase disait « 0 séances »). Même fonction, un seul mot change.

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
               p_n || case when p_n > 1 then ' séances' else ' séance' end, 'cette semaine.')
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
