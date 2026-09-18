---
name: woop-cartes
description: Concevoir et réaliser les Cartes de Nosfy, leurs mondes nocturnes, créatures, illustrations IA, finitions shiny, rythme des boosters et catalogue commun relié à Supabase. Utiliser pour reprendre ce chapitre, produire ses cartes ou brancher leur ouverture et leur collection.
---

# Nosfy — Cartes

Travailler dans le dépôt contenant `Woop/Services/LuneForge.swift` et
`tools/carte-lune/`. Les chemins de ce document sont relatifs à cette racine.
« Cartes » est le nom produit ; les identifiants techniques `forge-card`,
`ForgeServeur` et l’ancre documentaire `#forge` peuvent subsister.

## Reprendre le bon état

Lire `CLAUDE.md`, `MULTI-SESSION.md`, puis le chapitre
`docs/site/content/pages/forge.mdx` et ses lignes dans `briques.ts`, `mesures.ts`
et `serveur.ts`. Ils distinguent ce qui a été mesuré, ce qui est proposé et les
risques ouverts. Les conclusions du plan ne valent pas déploiement.

Lire selon la tâche :

- Direction et suite : `tools/carte-lune/PLAN-CARTES-MONDES-2026-09-18.md`.
- Seconde famille : `tools/carte-lune/cimes-eteintes-2026-09-18/README.md`.
- Art existant : `tools/carte-lune/references-2026-09-18/README.md`, ses PNG,
  `prompts.json` et `retouches.json` ; regarder les images avant de les modifier.
- Identité/attribution : `tools/carte-lune/ANALYSE-CARTES-2026-09-17.md`.
- Rythme : `tools/carte-lune/rythme-propose-2026-09-18.py` et son résultat JSON.
  C’est un modèle de proposition, sans réseau, pas un test de l’app déployée.

## Direction approuvée

Créer plusieurs mondes de la nuit, cohérents mais distincts, avec des créatures
reconnaissables. Deux familles sont retenues : La Forêt des Veilles (forêt/vallée/brume) et
Les Cimes Éteintes (montagnes noires, ténèbres et braises orange). Nuit, lune et
braise relient l’univers : noir profond lisible, matières précieuses, présence
poétique, détails visibles à taille de carte. Éviter dragon féérique, palette
arc-en-ciel, néons et surcharge d’ornements.

Dernières décisions artistiques du18-09 :

- Catalogue de familles prédéfinies et identifiables, pas de nouvelle espèce au
  hasard par propriétaire. `tools/carte-lune/familles-2026-09-18.json` conserve
  dix références d’atelier, noms FR/EN et empreintes ; aucune n’est publiée.
- Cimes Éteintes : noir profond, orange braise, suie, cendre, obsidienne.
  Corbeau commun, chauve-souris rare, loup épique, dragon légendaire ; quatre
  créatures validées. Les communes peuvent aussi être de beaux paysages :
  deux paysages ajoutés sur demande. Ne pas remplacer le corbeau apprécié.
- La commune est sobre et soignée. Réserver l’éclat et le spectaculaire aux
  degrés supérieurs ; shiny noir/cuivre très travaillé sur rare et légendaire.
- Marées et créatures marines rejetées. Premières Cimes sous la lune rejetées :
  trop proches du premier monde. Un dragon sombre d’obsidienne est explicitement
  demandé ; l’exclusion porte sur les dragons féériques/colorés.
- Le scellement Git demandé pour les deux premières familles ne vaut pas
  publication Supabase ni validation du cadrage et du shiny animé sur iPhone.

Une créature se reconnaît par sa silhouette, son regard et un détail de matière,
pas seulement son nom ou une couleur. Les autres mondes du plan restent des propositions,
pas un catalogue déjà approuvé ou publié.

Conserver le full art et le cadre existant. L’illustration IA ne porte ni cadre,
ni texte, ni numéros de rareté. `LuneForge` ajoute déjà1/2/3/4lunes ; le cadre
légendaire est argenté. Texte blanc minimal hors de l’art : nom court ; histoire
brève et souvenir de séance dans le détail si ce parcours est réalisé.

Quatre références artistiques, une par rareté, sont le point de départ ; cela
ne signifie pas quatre cartes au total. Toutes gardent la même qualité de
peinture. La commune est intime, la rare porte une présence singulière, l’épique
gagne en échelle/mouvement, la légendaire en présence et matière extraordinaire.
Vérifier le croissant du logo, la zone du médaillon et le recadrage réellement
effectué par `composer`, puis le sujet en vignette sur iPhone.

Utiliser le skill imagegen pour produire/retoucher les PNG : outil intégré par
défaut, versions non destructives, sorties sauvegardées dans le dépôt avec leurs
prompts. Une génération d’atelier n’autorise pas à remplacer une carte possédée.

## Identité commune et découverte

Une référence publiée désigne la même image, le même nom, la même rareté et la
même finition pour tous. Générer une image par propriétaire ne satisfait pas
ce contrat. L’exemplaire et son souvenir de séance appartiennent au joueur ;
l’illustration canonique appartient au catalogue commun.

Conserver les emplacements vides du profil sans révéler les noms ou images des
cartes manquantes. Les totaux peuvent venir du serveur sans divulguer les arts.
La comparaison avec les amis et les échanges sont reportés.

Conserver le manège et le sachet noir à légendaire garantie. Une réponse tardive
ou un échec réseau ne doit pas faire passer une carte de repli pour une véritable
acquisition. Reprendre le même sachet sans payer/attribuer deux fois.

## Shiny animé : décision du18 septembre

Kathryn demande une animation en plus des reflets. Les PNG nacrés produits ne
l’implémentent pas. La finition est distincte de la rareté : une référence shiny
possède un visuel, un poster et un effet officiels communs à tous. Si une version
normale et shiny coexistent, conserver deux références liées à la même créature.
Le choix des références shiny et leur distribution restent à définir ; ne pas
ajouter implicitement une deuxième loterie.

Partir de `CarteVivante`, du foil et du tilt existants. Donner à chaque shiny un
éveil bref et une réaction à la lumière/au geste adaptés à sa créature. Charger
`woop-chauffe` avant toute animation ou mesure : vie limitée à la carte visible,
arrêt hors écran/recouverte/arrière-plan, Reduce Motion et protections thermiques,
poster sans saut de pose. Ne pas animer en permanence toute la grille. Mesurer
le supplément sur iPhone ; aucune promesse de coût nul ou de chauffe résolue.

## Générosité et rythme

Le joueur ne fait pas du sport tous les jours. Évaluer les découvertes en séances
et en semaines pour1/2/3séances hebdomadaires, ainsi qu’en ouvertures : une séance
peut donner plusieurs boosters. Conserver les gains existants tant que le
changement de barème n’est pas demandé. Ne pas confondre budget des pop-ups,
gain de boosters, rareté des cartes et pièce d’argent (`rare_*`).

Le plan propose une première découverte remarquable, une limite aux communes
consécutives et aux longues attentes de légendaire. Ses taux et seuils ne sont
pas actifs. Simuler le catalogue réel, les doublons, les boosters noirs et les
pratiquants occasionnels avant de les fixer. Les garanties modifient les taux
effectifs : annoncer le résultat calculé, pas seulement les poids de base.
Absence et rejeu ne remettent pas la progression à zéro. La qualité artistique
et les souvenirs doivent porter l’attachement ; le shiny n’est pas l’unique
récompense désirable.

## Atelier, app et serveur

Le skill guide le développement ; il n’est pas exécuté par l’iPhone ni transmis
automatiquement à OpenAI. Relire le code pour expliquer le fonctionnement réel.
Au18-09, `BoosterLab.lancerForge()` ouvre le sachet à l’engagement dans le manège,
puis `ForgeServeur.tirer` appelle Supabase ; `forge-card` sert le pool ou génère
une nouvelle image via OpenAI. Ce n’est pas un appel à la conversation Codex.

Cible du plan : génération IA en atelier → sélection → publication → attribution
serveur pendant l’ouverture. Préparer les images avant les tirages des joueurs
permet de garder des références stables et de ne pas faire dépendre le manège
d’une génération. Ne pas présenter cette cible comme déjà branchée.

Pour le backend, appliquer le skill Supabase et relire les migrations actives.
Sources d’appel : `Woop/Views/BoosterLab.swift`, `Woop/Services/ForgeServeur.swift`,
`Woop/Views/SacreAccueil.swift`, `supabase/functions/forge-card/index.ts`.
Pièges établis le17-09, à vérifier avant chaque reprise :

- `ma_collection()` et le client regroupent par famille et perdent l’identité
  précise. Les images différentes ne doivent pas devenir de faux doublons.
- Scellement du sachet et insertion `user_cards` sont deux écritures ; les rendre
  atomiques avec les éventuels compteurs de garantie et le verrouillage pertinent.
- Le catalogue mélange création et distribution, sans statut de publication.
  Une rareté vide se traite explicitement avant de consommer, sans changer la promesse.
- Le cache disque et la relecture serveur existent déjà : ne pas les reconstruire.
- La provenance de séance doit venir du serveur ; les sachets de conversion
  n’ont pas tous un `workout_id`. Ne pas inventer une séance ni croire le client.

## Terminer avec une preuve

Pour une livraison fonctionnelle : deux comptes partagent la même référence,
collection conservée après relance/réinstallation, vrais doublons, appels
concurrents/rejeu/coupure, garantie noire, cadence et coût shiny sur iPhone.
Rapporter séparément art approuvé, code écrit, backend déployé, parcours observé
et performance mesurée. Mettre à jour le site local et son livrable selon les
règles du dépôt. Ne passer aucune ligne au vert sur la seule existence du skill,
d’un plan, d’une image ou d’un build.


## Personnages récurrents, scènes distinctes

Décision explicite de Kathryn : les mêmes personnages reviennent entre les
familles. Conserver le visage, les proportions et les détails distinctifs du
corbeau, de la chauve-souris et du loup en prenant les images validées comme
références. **Changer la pose, l’angle, le mouvement et l’interaction avec le
décor à chaque nouvelle carte de famille.** Une simple recoloration de la
même pose ou le remplacement du fond ne suffit pas : cela paraît faux.
La récurrence du personnage ne fusionne pas les références collectionnables ;
chaque illustration officielle garde son identité et ses vrais doublons.

Pour Les Bois Sans Lune : vraie nuit profonde sous des pins très denses,
ombres noires, reflets nacrés blancs clairement perceptibles sur matière noire.
Éviter le rendu de jour désaturé et les personnages simplement copiés-collés.
