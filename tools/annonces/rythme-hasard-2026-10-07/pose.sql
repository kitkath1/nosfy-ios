-- 07-10-2026, sa demande : « il peut y en avoir plus souvent mais de manière aléatoire ».
-- Par exercice : 1re pop-up tirée à la série 2, 3 ou 4, puis tous les 1 à 3 séries,
-- 6 au plus par exercice. Le rang 10 garde la vidéo rare (une par séance).
begin;
update reward_rules set value = '[10]'::jsonb where key = 'popup_rangs_fixes';
update reward_rules set value = '1'::jsonb  where key = 'popup_hasard_apres';
update reward_rules set value = '1'::jsonb  where key = 'popup_hasard_ecart_min';
update reward_rules set value = '3'::jsonb  where key = 'popup_hasard_ecart_max';
update reward_rules set value = '1'::jsonb  where key = 'ecart_min_series';
update reward_rules set value = '1'::jsonb  where key = 'ecart_min_minutes';
update reward_rules set value = '6'::jsonb  where key = 'popups_max_seance';
commit;
