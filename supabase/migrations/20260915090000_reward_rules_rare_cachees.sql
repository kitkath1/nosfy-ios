-- ════════════════════════════════════════════════════════════════════════
-- LES DÉS DU SERVEUR NE SE LISENT PLUS — 15-09
--
-- Verdict appliqué : « le back-end ne doit surtout jamais exposer le pity timer —
-- rendu visible, il devient farmable » (annonces.sql:160-172, §8 anti-abus de la note
-- rewards), noté « c'est noté, pas résolu » depuis le 29-08, litige b-rg-rare du site.
--
-- MESURÉ le 15-09 sur le compte de test (tools/serveur/verif_portes.py) :
--   GET /rest/v1/reward_rules?select=key,value&key=like.rare_*   (jeton authenticated)
--   → 200 [{rare_une_chance_sur 30}, {rare_pity_seances 45}, {rare_cooldown_seances 10}]
-- La policy « les règles sont publiques en lecture » (wallet_coffre.sql:78) disait
-- `using (true)` : n'importe quel compte lisait les trois clés de la rareté.
--
-- Le remède le plus court : la MÊME policy, avec la clause qui manquait. Pour un
-- client, une règle dont la clé commence par `rare_` n'existe pas. Pour les fonctions
-- `security definer` (roll_rare, appelée par cloturer_seance — annonces.sql:205-221),
-- rien ne change : elles s'exécutent en propriétaire de la table et ne passent pas par
-- la policy. Aucun appelant ne bouge : l'app ne lit la table en direct que pour les
-- cinq `chemin_*` (SacreServeur.reglesChemin), et `regles_annonces()` excluait déjà
-- ces trois clés (annonces.sql:176-181).
--
-- Vérification, après la pose (le même script) : rare_* → [] · chemin_* → 5 clés ·
-- regles_annonces() rend exactement les clés que le REST montre · etat_coffre() rend
-- toujours prix_booster 100 (le definer lit) · le témoin inventé → 404.
-- ════════════════════════════════════════════════════════════════════════

drop policy if exists "les règles sont publiques en lecture" on public.reward_rules;

create policy "les règles sont publiques en lecture, sauf les dés"
  on public.reward_rules for select to authenticated
  using (key not like 'rare\_%');

comment on table public.reward_rules is
  'Les règles du jeu, éditables à la main. Lisibles par tout compte connecté SAUF les clés rare_* (la rareté de la pièce d''argent : exposée, elle devient farmable) — celles-là ne se lisent que par les fonctions security definer (roll_rare). Écriture par migration seulement : aucune policy d''écriture.';
