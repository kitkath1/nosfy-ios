# Départ depuis Route — count.mp4, version53, 16 septembre 2026

**Actualisation17-09 : correctif57 confirmé sur iPhone par Kathryn.**
Le lecteur est monté indépendamment des ancres et précède Exercices. Le récit
ci-dessous décrit53 ; diagnostic, régression Release et confirmation dans
[la reprise du17-09](reprise-start-17/etat.md). La chauffe reste ouverte.

La vidéo demandée est intégrée : **Commencer → film → Exercices**. La séance
naît au tap avec un UUID unique et son début part dans Supabase en parallèle.
Reprendre une séance existante ne rejoue pas le film.

## Sources et comportement

- `Woop/Views/FilmDepartSeance.swift` : un AVPlayerLayer, une lecture, aucun
  minuteur de navigation ni boucle. Fin réelle, tap, erreur de lecture et
  Réduire les animations empruntent la même sortie unique. Pause hors écran,
  observers retirés, item et lecteur libérés au démontage.
- `Woop/WoopApp.swift` : le noir couvre le changement d'onglet, les trois pages
  et le halo sont au repos jusqu'à la fin. Double callback protégé par l'état
  du film et une lecture du contexte SwiftData, même avant la mise à jour Query.
- `Woop/Services/OuvertureSeanceServeur.swift` : insertion par UUID avec
  `resolution=ignore-duplicates,return=representation`. Réponse lue ; sur rejeu,
  relecture de la ligne conservée. Un départ tardif ne peut pas effacer ended_at.
  Reprise au premier plan, annulation ciblée sur UUID et ended_at nul. La file
  d'annulation persiste avec le propriétaire ; elle attend l'envoi en cours.
- `Woop/Views/ActiveWorkoutView.swift` : annulation locale reliée à ce retrait.
  Aucune migration, aucun changement de RLS ni d'économie.

Le fichier source `~/Downloads/count.mp4` : HEVC2160×3840,24images/s,
145images,6,041667s,2689954octets, piste AAC. Le recuit reproductible
`tools/flow/recuit_count.sh` livre H.2641080×1920, même cadence/durée,
563444octets, AAC128k. Fondus cuits, ratio conservé sur fond noir.
Le son suit le silencieux et laisse jouer la musique. Son audible/haptique
non validés par une capture. Ni le poids ni le codec ne prouvent la chauffe.

## Preuves fonctionnelles et serveur

Release53 compilée et installée sur iPhone15, version relue à18:37:32 Paris.
Le manifeste `sources53.json` décrit la copie cohérente de l'arbre partagé,
pas un checkout du seul changement. Les premiers builds échouent sur une copie
ancienne d'EconomieWoop ne portant pas encore clotureRepondue ; la dépendance
actuelle est recopiée seulement dans les bancs, puis les deux builds passent.

Simulateur isolé `woop-count-20260916` (iPhone15/iOS26.5), Debug53 :
**3 tests exécutés,0 échec,60,505s**. Fin naturelle/relecture ; tap puis
arrière-plan7s/reprise ; vrai panneau Start de Route double-tapé, film visible,
Exercices et exactement une séance locale. Captures XCTest exportées et vues
dans `preuves/route-avant-start.png`, `route-countdown.png` et
`route-arrivee-exercices.png`. Aucun test du nouveau tuto J2/J3, non livré.

Compte QA uniquement, explicitement autorisé par Kathryn après le premier
refus de validation automatique. Les identifiants existants du banc passent
uniquement par l'environnement du processus ; ni mots de passe ni jetons
dans les preuves. Pas d'identifiants nouveaux dans le code.

Le vrai parcours crée UUID55DA4BCB-B8FB-4943-9FDA-CEB6E9B89A57 ; après arrêt
de l'app, la lecture REST rend une ligne du compte QA, ended_at nul, et
`home().en_seance=true`. Le script vérifie aussi le double envoi, la conservation
du départ initial, le départ retardé après une fin et l'annulation retardée
après une fin. Deux passages :1 fixture puis1 fixture+la séance du parcours.
**Trois UUID de test supprimés et absence relue**, aucun autre UUID visé ;
aucun appel de clôture économique ni de récompense dans le script.
Journaux bruts `preuves/serveur-contrat.log`, `preuves/serveur-app.log`,
`preuves/tests.log`. La persistance d'annulation après kill/hors ligne est
relue dans le code ; ce scénario de panne complet n'a pas été exécuté.

## Contrôle physique et limites

**Un test physique passe99,016s**, iPhone15/iOS26.6.1, Release53,
connexion filaire, batterie en charge visible sur la capture ; luminosité
non relevée. Arguments : `-countLab -sansServeur -sondeVol -navProbe
-ecranEveille`. Aucune séance personnelle créée ou terminée par ce banc.
Fin, trois relectures, tap pour passer et pause en arrière-plan7s passent.
Le film en verre sur fond noir et le retour au bouton de lab sont constatés
sur les captures XCTest. Retour « ok c bon » de Kathryn pendant la validation.

Les158 lignes vol sont corrélées aux158 événements nav `etat` (même ordre,
écart horloge relatif stable à0,1s). Toutes sont thermique0 ; les fenêtres
ci-dessous sont applicationState0, protection0. Les bornes UTC des fenêtres
et leurs chiffres complets vivent dans `preuves/mesure-lecteur.json`.

| Fenêtre du lecteur isolé | Lignes / étendue | CPU médian / max | Cadence / pire intervalle |
|---|---|---|---|
| repos avant, t15,2–24,4 | 10 /9,2s | 0,5 % /4 % | 60,1 callbacks/s /17ms |
| lecture1, t28,4–30,5 | 3 /2,1s | 8 % /8 % | 60,1 /17ms |
| lecture2, t38,6–39,6 | 2 /1,0s | 0,5 % /1 % | 60,1 /17ms |
| lecture3, t47,7–49,7 | 3 /2,0s | 4 % /4 % | 60,1 /17ms |
| récupération, t76,3–95,5 | 20 /19,2s | 0 % /0 % arrondis | 60,1 /17ms |

Fenêtres vidéo très courtes, captures/automatisation actives : ces médianes
ne décrivent pas un coût stable général. Pas d'A/B avec le fichier4K, donc
aucun gain énergétique attribué au recuit. Le début du lancement est exclu
séparément : pic CPU21 %, pire57ms sur les15 premières secondes. Toutes les
lignes brutes sont conservées. La fin de la récupération capturée après la
fenêtre montre50 callbacks/s et33ms ; ne pas la remplacer par la médiane60,1.
L'analyseur du skill reproduit les20 lignes de récupération ; son champ nommé
`home_retenue` décrit ici **le lab**, pas la Home (valeurs de contexte par défaut).

La mesure montre le retour à une faible charge après démontage. Elle ne
mesure ni watts, ni GPU, ni chauffe durable. La QA thermique de la Home reste
ouverte. Aucun changement de rendu supplémentaire après ce test.

Relance normale avec `-sansSondeVol` acceptée18:42:51. Le contrôle suivant
échoue sur sa précondition « app déjà lancée » ; `activate()` la lance puis
capture la vraie Home noire sans HUD, avec la séance courante, à18:43:34.
La capture a été vue (conservée dans `/tmp/woop-count53/restauration-captures-apres`,
non ajoutée à l'archive publique de tests synthétiques). Processus34542 présent
à18:44:53. **Retour normal constaté, test de précondition en échec**, cause de
l'arrêt entre les deux commandes non établie. Aucun second parcours de stress.

## Documentation

Flow, carte serveur et schémas décrivent le nouveau départ. Génération des
SVG puis `npm run artefact` et `npm run verif` passent :32 tests, bornes des
preuves, livrable autonome, largeur390 des10pages, captures. Flow constaté
sur le livrable390 et sur http://localhost:3111/#flow à1440. Captures archivées.
Le livrable pèse environ1,99Mo, proche de sa borne2Mo. J1 du plan du05-09
est livré ; J2/J3 restent planifiés. Aucun nouvel ordre de commit reçu depuis
le commit de l'île `b90bee9` : ce changement reste dans l'arbre partagé.
La republication de l'artefact Claude nécessite son outil Artifact, absent des
outils de cette session. Le lien local http://localhost:3111 sert la source.
