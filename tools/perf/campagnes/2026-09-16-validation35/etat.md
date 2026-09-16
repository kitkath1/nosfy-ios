# Reprise iPhone35 et skill chauffe — 16 septembre 2026

**35 est installé. Aucun nouveau parcours tactile ni verdict de chauffe Home35
n'est validé ce matin.** Le runner XCTest ne parvient pas à activer le mode
automatisation ; la Home reste recouverte par Welcome Back, puis l'app devient
inactive. Ces données ne remplacent pas les validations34 du15-09.

## Exécution sur l'appareil

Heures locales Europe/Paris (UTC+2), iPhone15 iOS26.6.1, app Release1.0/build35.
Sources : agencement35 compilé le15-09, sans modification Swift ce matin ;
snapshot dans `../2026-09-15-reprise-autonome/`.

- 07:30 : CoreDevice se connecte par `localNetwork`. USB absent des réponses
  `idevice_id -l` exécutées avec accès aux services du Mac. Ce constat ne prouve
  pas que le réseau cause l'échec de XCTest.
- 07:30:53 : installation réussie ; `device info apps` relit `bundleVersion=35`.
- 07:31:12 : lancement accepté avec `-sondeVol -ecranEveille -navProbe
  -sondeAnimations -openTab home`, protection thermique normale.
- 07:31:36–07:32:36 : premier runner, échec **avant toute assertion** :
  `Timed out while enabling automation mode`.
- Une seule reprise après contrôle de verrouillage/liaison échoue de la même
  manière. Aucun appui Later, aucun parcours Home→Profil n'est donc attesté.
- 07:36:24 : lancement accepté sur Profil avec `-sansSondeVol -ecranEveille
  -navProbe -openTab profile`, après sauvegarde des données. Le journal confirme
  la sélection Profil et le maintien éveillé, mais passe presque immédiatement
  en `applicationState=1` (inactive). Ne pas dire que son affichage interactif
  est vérifié. Dernière collecte identique ; le runner n'est plus dans la liste
  des processus. Aucun redémarrage de l'iPhone ni suppression de données.

L'utilisateur a été informé que le pilotage est bloqué et invité à rétablir le
câble s'il est disponible. Aucun essai identique supplémentaire lancé sans
changement de condition. La désactivation de la sonde a été demandée via le
lancement accepté ; aucune capture visuelle finale n'est disponible.

## Données : deux motifs d'exclusion

`vol-20260916-073113.jsonl` :283 lignes, t=1,0 à287,4s. Après15s :269 lignes,
CPU médian17 %, thermique0, **welcome=1 sur toutes les269 lignes**. Ce chiffre
porte sur la fenêtre de bienvenue et son contexte, pas la Home dégagée. Il
n'attribue pas le coût à un composant précis.

Le journal nav ajoute une invalidation : parmi ses284 relevés `etat`,22 sont
active0 et262 inactive1. L'événement `scene-inactive` commence au lancement du
premier runner. La sonde continue ses callbacks pendant cette inactivité ;
60callbacks/s ne prouvent donc pas ici un écran contrôlable.

L'analyseur du skill retient **zéro ligne Home exploitable**, car Welcome Back
est présent. L'inactivité se contrôle séparément dans nav ; cet analyseur ne
fait pas de jointure approximative entre les deux horloges.

## Skill livré et validé

Source : `.agents/skills/woop-chauffe/`. Découverte locale via le lien
`~/.codex/skills/woop-chauffe` vers cette source, sans copie divergente.
Liens ajoutés aux instructions projet et à l'ancien skill performance.

- `SKILL.md` : reprise depuis les preuves, critères CPU/thermique/navigation,
  conservation des animations, cycle de vie des vues, limites et fin d'essai.
- `references/iphone.md` : outils iPhone, échecs connus, contexte actif,
  captures vidéo, collecte et pièges des commits partagés.
- `scripts/analyse_sonde.py` : lecture seule, fenêtres explicites, exclusion
  des surcouches et séparation des catégories thermiques/protection.

Validation structurelle officielle PASS. Le premier appel du validateur échoue
car PyYAML est absent ; installation dans un venv temporaire isolé, puis PASS.
Aucune dépendance Python ajoutée à l'application ni à son environnement global.

Sept contrôles de l'analyseur passent : récupération des164 lignes34 et des
groupes76nominales/88protégées ; rejet des269 lignes sous bienvenue35 ; refus d'un
champ absent, d'un infini, d'un temps réinitialisé, d'une catégorie invalide ;
respect des bornes et exclusion player/autre page/banc. L'analyse34 avec
`--end180` retient163 lignes (dernier179,7s), contre164 sans borne supérieure
(dernier180,7s) : différence attendue, pas une nouvelle mesure du téléphone.

## Suite précise, sans refaire la bissection

Quand le pilotage est rétabli : sur **35 déjà installé**, fermer Later et
constater la vraie Home active. Effectuer une endurance normale de plusieurs
minutes,4cycles Exercices/Profil et une récupération ; vérifier le rendu du
Chapitre et les retours du pull. Garder les protections thermiques et collecter
avant relance. Suspendre le stress à serious/critical. Ne pas transposer le1 %
mesuré34 à35, ni le traduire en absence garantie de chauffe.

QA04 reste ouverte. QA07 conserve seulement la validation d'accès obtenue34.
Les preuves34 restent dans `../2026-09-15-reprise-autonome/etat.md`.

## Documentation et sélection

Le skill est commité dans `5a39b01`. Génération et vérification du site local
réussies après la mise à jour effective des deux notes QA ; capture Etat390
relue. L'artefact destiné au commit est généré dans le checkout isolé pour ne
pas absorber les contenus serveur des autres sessions. Les limites de ce
checkout décrites E51 restent applicables ; sa génération ne vaut pas validation
de ses références hors sélection. Les données brutes ne sont pas normalisées.

Incident de préparation consigné E37 : le premier script en entrée standard
échoue sur UTF-8 avant écriture ; le premier artefact, lancé trop tôt, est
remplacé après exécution du script depuis un fichier UTF-8. Seuls les journaux
de la génération finale sont utilisés comme preuve de documentation à jour.
