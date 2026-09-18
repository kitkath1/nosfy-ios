# Chauffe75 : Profil, manège, stories et charge système

18 septembre2026. iPhone15 réel, iOS26.6.1, câble branché et charge visible.
Version installée75, bundle fr.kathryn.woop. Aucun compte vidé, aucune séance
créée/clôturée, aucun booster consommé. **Chauffe non résolue ni validée pour
TestFlight.** Le bon fonctionnement avec écouteurs reste une exigence.

## Ce qui est mesuré

La première observation réelle du Profil reste nominale45s. La trace suivante,
nommée à tort profil-cpu, est la **Home**, capture relue : thermique0 puis1.
Sur16,404s, Nosfy compte820ms de samplesCPU ; BTLEServer15887ms, soit environ
97% d’un cœur. La plupart des piles de l’app sont SwiftUI, pas SceneKit.
Cela n’innocente ni le GPU, ni les animations, ni les effets des étapes précédentes.

Profil vérifié à10:17 :79,2s stables à thermique0, CPU médian26% sur79lignes
entre15,2 et94,4s. Une SCNView560×700 à30Hz. Le test tactile associé échoue
sur un sélecteur de nav inadapté ; sa réussite fonctionnelle n’est pas revendiquée.

Même binaire75, comparaison Profil B1/A/B2, argument de lancement seulement :

| État | Fenêtre stable | Lignes | Thermique | CPU médian |
|---|---|---:|---|---:|
| Sachet rangé B1 |15,2–61,9s|47|0|16%|
| Sachet visible A |15,2–58,9s|44|0|21%|
| Sachet rangé B2 |15,2–61,9s|47|1|18%|

Le parcours passe193,838s. A finit à thermique1. Instruments Metal est actif
pendant une partie de A : sa surcharge et le changement thermique empêchent
un pourcentage causal propre. Les captures B1/A/B2 montrent la bonne page.
Même sachet rangé, le Profil reste coûteux ; aucun budget acceptable n’en est déduit.

La trace Metal dure11,678581s. Ses samplesCPU attribuent1526ms à Nosfy,
avec SwiftUI dominant ; SceneKit apparaît dans177ms de piles inclusives.
Les intervalles GPU Active sont exportés et réunis par processus/canal dans
`preuves/nosfy-chauffe75-gpu-union.json`. Les sommes brutes peuvent se
chevaucher. La composition backboardd n’est pas attribuable entièrement à Nosfy,
et ces durées ne sont ni des watts ni une température.

À10:35:29, **Nosfy arrêté**, TimeProfiler11,435537s : aucun sample app ;
BTLEServer11110ms, encore environ97% d’un cœur. Activité système confirmée
indépendamment de la présence de l’app. Les piles mentionnent CoreUARP,
sans identification certaine d’un accessoire. Aucun lien causal exclusif avec
les écouteurs, ni solution consistant à les désactiver, n’est affirmé.
Redémarrage ponctuel demandé à Kathryn ; attente de sa réponse.

## Correction complémentaire76 en cours

Les moteurs haptiques du booster ne démarrent plus à la simple construction
d’un décor Profil. Ils s’arrêtent à la suspension et au relais carte. Le moteur partagé des
cinématiques s’arrête au stop ; la carte libère souffle, sons et gyro
à sa sortie et en arrière-plan. Un reset ne rallume plus un moteur fermé.
Dessin, cadence3D, gestes et audio avec écouteurs conservés.
Release76 compilée et installée ; résultats physiques ci-dessous. Aucune baisse
thermique attribuée à cette correction.

## Mesures invalides et limites

- PowerProfiler échoue deux fois par PID (« Cannot find process »), puis en
  mode tous processus (Location Energy Model incompatible). Aucune donnée
  d’énergie exploitable ; ces tentatives ne prouvent rien en watts.
- Export xctrace avant finalisation : « Document Missing Template Error ».
  Export repris seulement après fin de sauvegarde, sans refaire la capture.
- Symbolication Metal : avertissements de chevauchement de dylibs. Les données
  exportées sont conservées, les noms de piles n’offrent pas tous la même précision.
- Profil : sélecteur person absent, test interrompu ; app ensuite arrêtée
  explicitement. Le prochain runner vérifie Retour et arrête aussi sur échec.
- Deux blocages iOS verrouillé, puis déverrouillages confirmés par Kathryn.
- Analyse GPU initiale par dictionnaire incorrecte : duration de latence
  écrasait celle de l’intervalle. Reprise par position du schéma, résultats
  corrigés archivés ; aucune valeur intermédiaire utilisée comme preuve.
- Ni séance active prolongée ni endurance corrigée76 ni confort avec écouteurs
  validés dans cette campagne75. Les anciens succès73 restent historiques.

Les journaux bruts, captures, exports compressés et empreintes sont dans
`preuves/`. Les paquets Instruments restent aussi dans /tmp/nosfy-chauffe75-*.trace.

## Résultat de76 installé —10:49 à10:56

Version76 confirmée par CoreDevice après installation. L’endurance est **SKIP**
avant lancement, état non nominal ; le runner ne transforme pas ce saut en
réussite thermique. Deux contrôles fonctionnels courts passent ensuite :
Profil→stories→booster→carte→arrière-plan/reprise→Home67,505s ;
manège→arrière-plan/reprise→fermeture→retour normal35,585s.

Le moteur haptique du décor Profil n’est pas démarré pendant sa visite.
Le premier démarrage suit l’ouverture réelle au banc. Arrêt booster confirmé
au relais, arrêt carte en arrière-plan, reprise, puis second arrêt à fermeture.
Le gyroscope stories est rendu. Le moteur partagé Rocket des cinématiques
n’a pas été exercé par ce banc stories direct : son arrêt n’est pas déclaré
mesuré. La version le compile avec playsHapticsOnly, auto-arrêt et stop explicite.

Retour après carte :9lignes, t57–65,2s, CPU médian5%, callbacks60,1/s,
pire17ms, thermique1. La scène du Profil reste retenue hors fenêtre, sans scène
ni rendu continu, compteur231 stable ; la cérémonie a été démontée.
Retour après manège : absence de SceneKit dans les derniers états, valeurs
par fenêtre dans preuves/resume76.json. Le premier parcours reste à thermique1.
Au second, la sonde app voit0 puis1 ; le runner voit1 : conserver ces lectures,
sans reconstruire un départ froid garanti ni revendiquer un refroidissement.

Capture de retour normal relue : Home sans sonde ni boutons du banc. Option
-sansSondeVol appliquée, app terminée ; aucun compte ni gain modifié.
Un premier listing visait par erreur Documents/vol, qui n’existe pas ; reprise
sur Documents, sans perte de données. Une consultation des apps avant la fin
de l’installation lisait encore75 ; la consultation post-installation confirme76.

**Les arrêts testés fonctionnent ; la chauffe durable n’est toujours pas
résolue.** Le coût actif du Profil et de la carte, le contexte Bluetooth,
la séance active prolongée et le confort avec écouteurs restent à vérifier.
Un redémarrage ponctuel attend l’accord utilisateur ; Bluetooth n’est pas
 désactivé pour contourner l’exigence. Aucun envoi TestFlight effectué.
