# Reprise autonome — 15 septembre 2026

**Dernière version installée confirmée :34. CPU Home1 % sur3min, animation du chapitre restaurée, navigation et4 allers-retours validés.35 compilé pour une intégration commitable autonome, installation refusée23:28 faute de liaison. Chauffe ressentie prolongée toujours à confirmer.**

L’utilisateur autorise les manipulations pendant son film. Compte et récompenses conservés. QA chauffe ouverte.

## Ce que les nouveaux essais disent

- Balade30,22:18–22:20 : quatre cycles Home → Exercices (défilement) → Home → Profil (défilement) → Home passent. Le CPU était déjà8–10 % avant le premier aller-retour. Les dernières35s de Home sont autour de7 %, thermique1/protection1, callbacks60,1/s. Cela **ne prouve pas une accumulation causée par la navigation**. Le booster caché ne rend plus : compteur577 constant, isPlaying=false, fenêtre absente. Le journal de mesure est `woop-balade30-nav-mesure.jsonl`, pas celui collecté après la relance.
- Power30,22:22:58–22:23:15 : Home fraîchement relancée, compteurs éteints, thermiqueNominal. CPU échantillonné après4s9,092 %. Piles de rendu SwiftUI/AttributeGraph ; pas de métrique GPU par processus. Ce n’est ni une mesure de watts ni le même processus que la balade.
- Même binaire30,22:26–22:27 : ancien chevron SwiftUI10 % CPU médian ; invitation retirée9 %. Fenêtres15<t≤35,20 lignes chacune.19/20 lignes SwiftUI et20/20 sans invite sont thermique1 ; protection contournée seulement60s, puis restaurée. **Comparaison froide non obtenue, aucun gain causal annoncé.** Le coût reste présent sans invitation : ne pas attribuer les9 % à Core Animation.

## Défauts de raccord trouvés dans le code

Le fond30 remplace structurellement un lecteur précalculé par deux lecteurs au départ, puis recrée le précalculé à e=0. Les lecteurs repartent de leur début et passent par leurs posters. Une reprise de geste capture e, puis l’écrase dans le même événement par T×g ; fermer pendant un départ pouvait aussi imposerT. Ces discontinuités motivent31. Leur correction visuelle et leur coût doivent être vérifiés sur le téléphone.

## Version31 en vérification

Deux lecteurs rognés conservés pendant le mouvement, témoin précalculé sous `-fondPrecompose`. Phase de prise mémorisée et fermeture depuis la phase réelle. Une onde native autour du jour actif (1,4s animée par cycle5,2s), sans shader ni flou ; arrêt hors écran, sous un écran couvrant, avec Reduce Motion ou thermique≥2. Les grands décors restent au repos. `-sansAppelChapitre` permet de comparer exactement ce repère.

Ces changements ne sont pas encore déclarés gain de chauffe ni QA validée. Les logs bruts ne sont pas normalisés ; les gros XML sont conservés compressés.


## Résultats31,22:35–22:42

Installé22:35:59. Le premier relevé demandé45s s’arrête à21,3s :7 secondes seulement après15s, CPU10 % nominal. Crash22:36:21, SIGABRT : pile `NSJSONSerialization → NavDiagnostic.noter → SondeVol.publier`. Le nouveau relevé des animations natives envoyait une valeur non sérialisable ; la valeur exacte n’est pas identifiée. La sonde a été retirée de32 (compilé, non installé).33 reconstruit la liste avec un type strict `[[String:String]]`, borne la visite et vérifie `isValidJSONObject` avant toute écriture. Ce premier31 ne valide ni45s de tenue ni l’absence de plantage.

Test réel31,22:37–22:38 : **PASS35,475s**,12 captures du chapitre,3 ouvertures/fermetures du tiroir, Profil puis Retour. Le slider de lancement n’est jamais actionné. Les images2 et10 montrent l’onde autour du jour15, les autres sa pause. Les vidéos évoluent entre les captures et ne sont démontées qu’au passage sur Profil, pas au retour du pull. Le test reprend un tiroir entièrement ouvert ; il ne prouve pas à lui seul le ressenti d’une interruption en plein départ.

Comparaison repère seul31 : avec,20 secondes stables15<t≤35, CPU10 %, thermique0/protection0 ; sans,CPU12 %, thermique0→1/protection0→1. Callbacks60,1/s. **Pas de coût causal quantifié : conditions thermiques différentes.** Ne pas prétendre que retirer l’onde augmente la consommation.

La protection30/31 remplace aussi une vidéo visible par le poster quand iOS passe àfair. Cela crée un autre changement instantané de pose.33 garde le lecteur visible et demande rate0, puis reprend le même lecteur au refroidissement. Hors écran, le démontage et la fermeture restent effectifs. Validation33 encore attendue.


## Isolement de la perle hebdomadaire33,22:47–22:49

33 installé22:47:53. Sonde réparée :35s complets, JSON des animations obtenu, pas de plantage. La capture montre notamment une animation système `CAMatchMoveAnimation` de durée infinie ; cette durée n’est pas un nombre JSON valide ([contrat Apple](https://developer.apple.com/documentation/foundation/jsonserialization)). Cela fournit un candidat précis pour le crash31, sans réexécuter le code fautif.

Même33, un seul drapeau différent : `-sansSoufflePerle` pose uniquement le dernier point fait dans « séances cette semaine ». Chapitre et chevrons conservés. Fenêtre15<t≤35 : normale10,5 % CPU (0→1), sans perle1 % (therm1). **En ne retenant que thermique1/protection1 après15s : normale12 % médian,n12 ; sans perle1 %,n20.** Dernières lignes13 % contre1 %. Callbacks60,1/s, pire17ms. C’est une piste isolée bien plus nette que les chevrons ; les fenêtres restent successives et ne mesurent pas la puissance GPU.

Le34 remplace seulement cette interpolation SwiftUI par deux petites images des dégradés d’origine (calculées une fois à la taille du point), un fondu natif et une échelle1→1,06 en4,7s. Même palette, diamètre, centre du dégradé et période. Le témoin original est `-perleSwiftUI`. Hors écran et quand la protection agit, la respiration s’arrête. Le34 doit encore prouver le dessin visible, la charge à froid et la tenue après balade.


## Validation34 — résultats complets

34 réellement installé (bundleVersion34 vérifié). Home normale22:53:29–22:56:30 :180,7s,164 relevés après15s, CPU médian1 %,60,1 callbacks/s, intervalle maximum17ms, aucun popup ni séance.76 secondes stables à thermique0,88 à thermique1. Bascule0→1 à53,8s, retour0 à143,1s ; dernières30s nominales et CPU1 %. La sonde des couches à froid montre souffle-perle, robe-perle, appel-chapitre et les deux chevrons actifs. Le1 % n’est donc plus limité au rendu protégé.

Trois retours du tiroir puis Profil PASS35,164s ; Home → Exercices → Profil → Réglages PASS9,231s. Douze captures vérifiées : point orange présent, onde du chapitre visible, vidéo et chevrons animés. Le test ne lance aucune séance et ne modifie pas le compte.

Balade34,22:59–23:02 : quatre cycles avec défilement Exercices et Profil PASS66,481s. Après90s de récupération, les dernières75s sont sur Home :74 relevés, CPU1 %, callbacks60,1/s, maximum17ms. Thermique1/protection1 sur cette fin : récupération CPU confirmée, récupération thermique non confirmée à cet instant. Compteurs éteints23:02:12, Home normale restaurée.

La préparation du commit impose35, décrit en E56. Il garde le même moteur natif mais rend son branchement indépendant du code non commité d’autrui. Le35 reçoit une vérification distincte ; ne pas présenter les durées34 comme celles35.


## Livraison et limite35

35 compile avec l’intégration autonome du widget. À23:28, l’installation est refusée avant lancement : CoreDeviceError4000, connexion invalidée, timeout réseau60 ; l’appareil est ensuite signalé unavailable. Aucun test35 annoncé comme passé. La dernière version réellement relue est34. La sonde a été éteinte à23:02:12 et la Home normale restaurée ; le compte reste intact.

Les commits gardent la refonte étrangère de WidgetsCards hors de l’index. Le checkout isolé conserve les limites E51 ; la compilation de la copie de travail complète35 ne certifie pas que ce checkout partiel compile.


Documentation isolée35 : artefact généré (1 866 093 octets),8 tests passés/1 échoué sur les références hors périmètre E51. La documentation locale complète est régénérée séparément pour conserver aussi les sources des autres sessions. Aucun feu vert attribué au checkout partiel.

Documentation complète du working tree : artefact généré et `npm run verif` entièrement vert (15s), y compris source, livrable, dix pages et largeurs390. Captures Etat390/1440 relues. Le livrable destiné au commit reste celui du checkout isolé pour préserver la séparation des autres chantiers ; sa limite E51 est conservée.
