-- Remet le rythme d'avant le 07-10 (3, 5, 10, puis tous les 5 à 8 après 10, 4 au plus).
begin;
update reward_rules set value = '[3,5,10]'::jsonb where key = 'popup_rangs_fixes';
update reward_rules set value = '10'::jsonb where key = 'popup_hasard_apres';
update reward_rules set value = '5'::jsonb  where key = 'popup_hasard_ecart_min';
update reward_rules set value = '8'::jsonb  where key = 'popup_hasard_ecart_max';
update reward_rules set value = '3'::jsonb  where key = 'ecart_min_series';
update reward_rules set value = '6'::jsonb  where key = 'ecart_min_minutes';
update reward_rules set value = '4'::jsonb  where key = 'popups_max_seance';
commit;
