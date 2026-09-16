-- LES VIDÉOS DES POP-UPS DE RÉCOMPENSE DE SÉRIE — 15-09-2026 (soir)
--
-- Verdict Kathryn : « connecte tout ça au backend ». Le Moment de la fiche (fin de
-- série) montre une pop-up de récompense à VIDÉO chauve-souris — mais UNE SEULE
-- (`reward-rare`) était codée EN DUR dans `DecideurSerie` ; les autres
-- (reward-piece-1..5, reward-fire, reward-lune) existaient dans l'app sans jamais
-- être branchées. On les met en RÈGLE, comme le reste du barème :
--   · `popup_video_rare`     : la vidéo du cas RARE (rang vidéo, une par séance) ;
--   · `popup_videos_reward`  : le POOL des vidéos des autres pop-ups reward, où
--     l'app tire AU HASARD (déterministe par séance + rang).
--
-- `regles_annonces()` les rend DÉJÀ (elle agrège tout reward_rules) : aucune
-- fonction à changer. `insert … do nothing` — réglables à la main.
-- ⚠️ `reward-nosfy-coins` n'est PAS ici : c'est la récompense de la ROUTE Duolingo
-- (RewardCheminVariants), pas le Moment de la fiche (Kathryn 15-09).

insert into public.reward_rules (key, value) values
  ('popup_video_rare',    '"reward-rare"'::jsonb),
  ('popup_videos_reward', '["reward-piece-1","reward-piece-2","reward-piece-3","reward-piece-4","reward-piece-5","reward-fire","reward-lune"]'::jsonb)
on conflict (key) do nothing;
