-- ════════════════════════════════════════════════════════════════════════
-- LES RANGS DES POP-UPS VIVENT EN BASE — 15-09, étape 5 (M2 du plan annonces)
--
-- tools/annonces/PLAN-COFFRE-ANNONCES.md §4 M2 et §5.2 (7), tranchés le 30-08 :
-- « rangs fixes 3 / 5 / 10, puis un rang au hasard toutes les 5 à 8 séries ; la vidéo une
-- seule fois, au rang 10 ; budget 4 pop-ups / 1 en pièces / 1 vidéo ; écart 3 séries ET
-- 6 min pour les rangs tirés ». Jusqu'ici `DecideurSerie` (RestartSheet.swift) tirait TOUS
-- les multiples de 3, 5 et 10, sans hasard ni budget, avec trois chiffres en dur.
--
-- Cinq clés, `do nothing` : elles se règlent à la main, sans version de l'app. Elles sortent
-- par `regles_annonces()` (elle agrège tout sauf rare_*), que l'app lit désormais à
-- l'apparition de la home (SacreServeur.reglesAnnonces → DecideurSerie.regles). Le rang se
-- tire AU CLIENT depuis ces clés (il ne paie rien) ; le hasard est déterministe par séance.
-- ════════════════════════════════════════════════════════════════════════

insert into public.reward_rules (key, value) values
  ('popup_rangs_fixes',       '[3,5,10]'::jsonb),
  ('popup_rang_video',        '10'::jsonb),
  ('popup_hasard_apres',      '10'::jsonb),
  ('popup_hasard_ecart_min',  '5'::jsonb),
  ('popup_hasard_ecart_max',  '8'::jsonb)
on conflict (key) do nothing;
