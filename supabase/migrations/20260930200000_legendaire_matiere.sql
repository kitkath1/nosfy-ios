-- ════════════════════════════════════════════════════════════════════════
-- LA MATIÈRE DES LÉGENDAIRES — l'interrupteur (30-09-2026, session légendaire)
--
-- Verdict de Kathryn, 30-09 : « oui oui mets tout dans l'app ! », puis « et
-- même celles déjà obtenues par Margaux, rajoute le nouvel effet ». La Quatre
-- Lunes reçoit sa matière (gravure, feu, météo, lampe du pouce) dans le
-- manège ET la collection, cartes déjà obtenues comprises.
--
-- Rien ne change au schéma : la matière de chaque légendaire est un FICHIER
-- public, publié par tools/carte-lune/publier_matiere.py dans le bucket
-- `cards` à côté des illustrations — `matiere/<card_id>.json` (le pointeur :
-- empreinte, monde, centre du sujet, noms) et `matiere/<sha256>.png`
-- (l'atlas, par empreinte). L'app le lit par l'identifiant de la carte
-- (LuneMatiere.publiee) : aucune table, aucune fonction, aucun argent.
--
-- Cette migration ne pose QUE l'interrupteur, règle du jeu lue par l'app avec
-- les règles des annonces (regles_annonces → DecideurSerie.chargerRegles) :
-- true = la matière s'affiche ; false = toutes les légendaires reviennent au
-- rendu d'avant, sans nouvelle version de l'app. C'est la porte de secours
-- de sa règle HARDCORE n° 6 (« rien ne se pose sans mesure chauffe sur son
-- iPhone ») : la mesure A/B se fait avec -sansMatiere, et si elle le
-- demande, une ligne suffit à tout éteindre.
--
-- Analyse et preuves : tools/carte-lune/ANALYSE-LEGENDAIRE-INVISIBLE-2026-09-29.md,
-- tools/carte-lune/legendaire-2026-09-30/README.md.
-- ════════════════════════════════════════════════════════════════════════

insert into public.reward_rules (key, value)
values ('legendaire_matiere', 'true'::jsonb)
on conflict (key) do nothing;
