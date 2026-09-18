# Cartes — preuve de la passe plan et skill du18 septembre

- Direction du premier monde approuvée par Kathryn ; shiny animé demandé.
- Skill créé dans `.agents/skills/woop-cartes/`, avec métadonnées d’interface.
  Lien `~/.codex/skills/woop-cartes` résolu vers ce dossier, fichiers copiés
  comparés à leur préparation. `quick_validate.py` : Skill is valid.
- Premier lancement du validateur : PyYAML absent. Environnement temporaire
  isolé créé dans `/tmp/woop-cartes-skill-20260918/validation-env`, dépendance
  installée, validation rejouée avec succès. Aucun changement du Python système.
-15 références de lecture du skill présentes ; calcul de rythme réexécuté,
  résultat identique au JSON archivé. Masse de probabilité, espérance et nombre
  de légendaires par cycle contrôlés dans le calcul.
- Documentation : `npm run artefact` puis `npm run verif`, PASS43s,23tests.
  Captures localhost390/1440 relues, largeur/scrollWidth identiques.
  Capture ciblée supplémentaire du rythme et de l’appel IA à390px relue.
- Chapitre Cartes :20lignes,1àvalider,14enchantier,5bons. Shiny et rythme restent
  des mesures ouvertes. Aucune pastille de branchement repeinte sur la base du plan.

Le calcul porte sur des ouvertures théoriques ; il exclut les boosters noirs,
le catalogue/doublons et la protection supplémentaire par séances. Le11,104%
calculé ne décrit ni le tirage actuel ni la totalité de la proposition finale.

Aucun code de l’app modifié, aucun nouvel art généré pendant cette passe, aucun
appel de tirage, déploiement Supabase, test sur téléphone ou commit effectué.
La validation de skill porte sur sa structure et ses références, pas sur
l’exécution autonome d’un futur chantier applicatif.
