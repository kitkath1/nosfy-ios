# Cartes — mondes nocturnes, rythme et branchement

18 septembre 2026. Plan et atelier artistique, sans modification de l’app ni du
serveur pendant cette passe. Kathryn demande de sceller les deux familles :
La Forêt des Veilles et Les Cimes Éteintes. Dix références sont conservées :
quatre pour la première, quatre créatures et deux paysages pour la seconde.
Les noms FR/EN sont éditoriaux ; le catalogue de lancement et les taux restent
à arrêter avant publication.

## Décisions de Kathryn

- Plusieurs mondes de la nuit, avec des créatures identifiables et attachantes.
  Commencer par le monde forêt / vallée / brume / lune / braise des quatre essais.
- Deuxième famille fixée : montagnes très sombres, noir profond et orange
  braise, suie et obsidienne. Corbeau commun, chauve-souris rare, loup épique,
  dragon légendaire. Les communes peuvent aussi être de beaux paysages.
- Familles prédéfinies et reconnaissables. Ne pas improviser une nouvelle
  créature pour chaque utilisateur. Le corbeau est explicitement validé.
- Même référence = mêmes image, nom, rareté et finition pour tous les joueurs.
- Full art, texte blanc minimal, cadre et lunes de rareté conservés.
- Collection avec emplacements vides comme au profil, sans noms ni visuels des
  cartes manquantes. Découvertes au fil des séances ; comparaison entre amis plus tard.
- Manège et sachet noir à légendaire garantie conservés.
- **Précision après les premières images : le shiny doit aussi être animé.**
  Les v3 actuelles ne sont que des illustrations nacrées, sans nouveau moteur.
- Les découvertes remarquables doivent arriver avec une pratique normale du
  sport. Plusieurs boosters peuvent être gagnés dans une séance ; ne pas exiger
  une pratique quotidienne pour apprécier la collection.

## Une famille de mondes, des signatures distinctes

Noms FR/EN de travail. Les deux premières familles ont des références produites.
Leur présence en atelier ne les rend pas disponibles dans les boosters.

| Monde | Matière et lumière | Créatures proposées |
| --- | --- | --- |
| La Forêt des Veilles / The Vigil Woods — retenue | Écorce mouillée, velours noir, brume lunaire et braise discrète | La Veille ; Les Veilleuses ; Le Passage ; Le Souverain |
| Les Cimes Éteintes / The Darkened Peaks — retenue | Noir profond, orange braise, suie, cendre, obsidienne et failles montagneuses | Corbeau de Suie ; Aile d’Ambre ; Loup de Cendre ; Dragon d’Obsidienne ; paysages communs La Faille Ardente et Le Col des Cendres |
| Le Désert de Verre | Dunes de cendre, verre volcanique, lignes chaudes dans le sable froid | Un renard aux longues oreilles sombres bordées d’argent ; un papillon aux ailes fumées ; un serpent noir au dessin minéral singulier |

Les Marées Muettes sont rejetées par Kathryn. Les premières Cimes sous la lune
(lynx, gypaète, bouquetin) sont également écartées : pas assez dark, trop proches
de la forêt. La version retenue privilégie les ténèbres et les braises orange,
avec une montée du spectaculaire et de la matière shiny selon la rareté.
La commune reste belle mais plus sobre. Un paysage peut être une commune.
Les quatre créatures noir/orange sont validées ensemble ; les deux paysages
sont les compléments demandés et revus en atelier.

Références, noms FR/EN, prompts et SHA-256 :
`references-2026-09-18/README.md`, `cimes-eteintes-2026-09-18/README.md`
et `familles-2026-09-18.json`. Ce manifeste décrit l’atelier, pas une migration
ni un catalogue déjà déployé.

Chaque créature a une silhouette, un regard, un détail de matière et une courte
idée narrative récurrents. Changer un décor ou une couleur ne suffit pas à créer
un nouveau monde. Ne pas ajouter dragons féériques, armures, runes ou néons.
La signature lune / nuit / braise relie l’ensemble sans imposer le même paysage.

**Proposition de première collection : 12 cartes** — 4 communes, 4 rares,
2 épiques, 2 légendaires. Les quatre essais fixent la direction de chaque rareté ;
ils ne limitent pas le produit à quatre cartes. Ne pas lancer la production des
12 images avant d’avoir arrêté la liste et vérifié les références dans le cadre.
Deux légendaires offrent déjà deux rencontres à découvrir. Préserver toutes
les anciennes cartes possédées ; ne pas les remplacer silencieusement.

## Le shiny, au-delà d’une image brillante

La rareté et la finition sont deux propriétés distinctes. Une rare peut avoir
une finition remarquable ; une légendaire garde sa rareté quelle que soit sa
finition. Pour le lancement, proposition : **des références officielles choisies
portent le shiny**, sans ajouter une deuxième loterie à toutes les ouvertures.

Chaque référence shiny partage son illustration, son poster immobile et son
effet entre tous ses propriétaires. Si une même carte existe plus tard en
finition normale et shiny, les deux versions ont des références distinctes,
liées à la même créature ; les doublons se comptent par référence exacte.

Effet proposé : un bref éveil au dévoilement, puis une matière qui accroche la
lumière au geste. Ailes nacrées pour les Veilleuses ; une lumière qui parcourt
les bois et révèle le pelage pour le Souverain. Une animation propre à la
créature, mesurée, sans vidéo permanente sur toutes les cartes de la grille.

Réutiliser `CarteVivante` et le foil/tilt existants, pas un moteur par monde.
Charger le skill chauffe avant d’implémenter : carte visible et premier plan
seulement, arrêt quand recouverte / hors écran / en arrière-plan, Reduce Motion,
protections thermiques, poster lisible et pose sans saut. Mesurer sur iPhone
le coût supplémentaire d’un shiny et les retours collection/manège. Une baisse
CPU ou une capture ne prouve pas à elle seule l’absence de chauffe.

## Rythme : compter les séances et les ouvertures

État du code relu le18-09 et des règles documentées :

- Un booster forfaitaire à la clôture si au moins une série ; le cardio payé
  sans série reçoit aussi son booster. Une séance vide n’en reçoit pas par ce chemin.
- Les pièces se convertissent automatiquement : prix documenté100,20par série.
  Avec solde initial0, hors bonus/autres gains, 10séries =200pièces =2boosters
  convertis +1forfaitaire =3boosters ;20séries =5boosters au total.
- Un booster révèle une carte. Les poids de `forge-card` sont60/27/10/3.
  Le sachet noir impose une légendaire. Les paramètres `rare_*` existants
  concernent la pièce d’argent ; ce ne sont pas des protections de tirage de carte.

À3% indépendants, même après6séances de3boosters ordinaires, la probabilité de
n’avoir aucune légendaire est encore57,80% (`0,97^18`), hors sachets noirs.
Une moyenne ne protège donc pas les joueurs les moins chanceux.

### Proposition de départ à calibrer, non déployée

- Poids de base :45%communes,35%rares,15%épiques,5%légendaires.
- Premier booster ordinaire : rare ou mieux.
- Après deux communes consécutives : le prochain est rare ou mieux.
- Première légendaire au plus tard au6e booster ordinaire ouvert ; ensuite,
  au maximum12ouvertures ordinaires entre deux légendaires.
- Ajouter une protection pour les petits gains : après6séances éligibles
  clôturées sans légendaire, la prochaine ouverture ordinaire en garantit une.
  Compter les séances distinctes côté serveur depuis la dernière attribution,
  pas les jours écoulés. Cette protection complémentaire n’est pas incluse dans
  le modèle par ouvertures ci-dessous ; son effet reste à simuler avec les gains.
- Les compteurs avancent à l’attribution réussie et une seule fois par sachet.
  Une coupure, un rejeu ou une absence ne les remet pas à zéro.
- Définir le traitement des sachets noirs avant implémentation : proposition,
  leur légendaire satisfait l’accueil et remet à zéro l’attente d’une légendaire,
  sans avancer un compteur d’ouverture ordinaire. Le calcul ci-dessous les exclut.

Le calcul exact de la partie par ouvertures donne une première légendaire en moyenne
à5,095ouvertures ; les suivantes à9,006ouvertures. **Avec les protections, les
légendaires représentent environ11,10% des ouvertures en régime établi,
pas5%.** La garantie par séances et les boosters noirs peuvent encore modifier
ce taux. Ce résultat est explicite pour juger la générosité.

| Boosters ouverts par séance | Première légendaire, maximum | Suivante, maximum |
| --- | --- | --- |
| 1 | 6 séances | 12 séances |
| 2 | 3 séances | 6 séances |
| 3 | 2 séances | 4 séances |
| 5 | 2 séances | 3 séances |

Ces bornes supposent l’ouverture de tous les boosters indiqués et excluent la
protection complémentaire par séances. Sans elle, à1séance par semaine et1booster,
la suite peut prendre12semaines : c’est précisément le cas qui motive la limite
de6séances avant une ouverture garantie. Ne pas présenter ce candidat comme
déjà équilibré ou déployé.
Àl’inverse, les séances riches en boosters peuvent épuiser vite une petite
collection. Évaluer aussi cartes nouvelles, doublons et variété, pas uniquement
le nombre de légendaires. Le shiny ne doit pas devenir l’unique belle récompense.

Calcul reproductible : `rythme-propose-2026-09-18.py` ; résultats JSON du même nom.
Modèle théorique sans réseau, sans cartes attribuées, sans déploiement. Il ne
mesure ni rétention, ni plaisir, ni comportements de vrais joueurs. Élargir la
calibration à1/2/3séances par semaine, aux séances courtes, longues et cardio,
avec la liste réelle du catalogue et ses doublons avant activation.

## Quand OpenAI intervient

**Parcours actuel lu dans le code :** la fin de séance produit les gains.
Lors du choix d’un sachet dans le manège, `BoosterLab.lancerForge()` ouvre le
sachet puis appelle `ForgeServeur.tirer` avec son identifiant. Supabase appelle
`forge-card`, qui choisit la rareté puis une image existante, ou une génération.

Le code réserve35% à une création neuve et en crée aussi si le catalogue de
la rareté est vide. Dans cette branche, GPT-5 rédige la scène et `gpt-image-1`
peint via l’API d’images. Ce sont les modèles écrits dans le dépôt, pas une
recommandation de modèles actuels. La clé OpenAI vit côté serveur. L’app
n’appelle pas cette conversation et un skill n’est pas chargé automatiquement
dans l’API : charte et contrats doivent être fournis au code de l’atelier.

Le commentaire historique60–90s de génération n’est pas une nouvelle mesure.
Le client attend jusqu’à300s et peut montrer une carte de repli avant l’arrivée
du résultat. Cette image ne doit pas être confondue avec une carte attribuée.

**Cible recommandée :** atelier IA → sélection → références publiées → tirage
serveur à l’ouverture → téléchargement/cache → vrai dévoilement → collection.
La génération OpenAI prépare le catalogue, avant les ouvertures des joueurs.
Le manège garde ses gestes et sa mise en scène ; en réseau lent, attendre/reprendre
la vraie carte sans faire passer un placeholder pour la récompense. Ne pas
rallonger artificiellement la cérémonie pour remplir un délai de génération.

OpenAI confirme que l’API d’images sert à générer ou modifier des illustrations :
<https://developers.openai.com/api/docs/guides/image-generation> (lu le18-09).
Le choix atelier/distribution est une décision d’architecture Woop.

## Ordre de réalisation et preuves attendues

1. **Fixer le premier ensemble.** Noms de travail, silhouettes, liste des12cartes
   proposée et références shiny. Les autres mondes restent une réserve artistique.
2. **Valider quatre références dans le cadre.** Lisibilité en vignette, croissant
   homogène, ailes et bois non masqués. Premier prototype shiny à mesurer au
   téléphone avant d’étendre l’effet. Produire ensuite les images manquantes.
3. **Calibrer la progression.** Simulation avec les vraies règles de gains,
   cadence1/2/3séances, doublons, bornes et effet des boosters noirs. Fixer la
   garantie du petit pratiquant ; placer les valeurs côté serveur.
4. **Catalogue commun.** Identité précise, monde/collection, créature, nom,
   rareté, finition, chemins immuables, statut de publication. Le catalogue
   administratif peut être complet ; l’API du profil ne dévoile pas l’art des
   manquantes. Traiter une réserve vide avant débit, sans inventer une rareté.
5. **Attribution fiable.** Verrouiller et sceller le sachet, attribuer la carte
   et avancer les garanties dans une transaction. Préserver les reprises et
   les anciennes cartes. Déduire la provenance d’une séance du serveur ; les
   sachets de conversion n’ont actuellement pas tous de séance associée.
6. **App.** Conserver `card_id` et la finition jusqu’au rendu, collection avec
   vrais doublons et emplacements vides, totaux venant du serveur, cache existant.
   Éviter tout repli de compte atelier ou de carte décorative présenté comme réel.
7. **QA puis documentation.** Deux vrais comptes obtiennent la même référence,
   mêmes pixels et même effet ; tests coupure/double appel/réinstallation,
   garantie noire et cadence ; QA visuelle et coût sur iPhone. La ligne concernée
   passe au vert sur sa preuve, jamais sur la création de ce plan ou du skill.

## Sources locales relues

- `Woop/Views/BoosterLab.swift` : `lancerForge`, `engager`, réponse tardive et repli.
- `Woop/Services/ForgeServeur.swift` : `tirer`, délai, téléchargement, habillage.
- `supabase/functions/forge-card/index.ts` : poids, pool/neuf, modèles, scellement.
- `supabase/migrations/20260830210000_conversion_jour_flamme.sql` : forfait/conversion.
- `supabase/migrations/20260915160000_economie_cardio.sql` : clôture cardio.
- `docs/site/content/serveur.ts` : valeurs documentées et pièce d’argent.
- `ANALYSE-CARTES-2026-09-17.md` : identité perdue et attribution non transactionnelle.
- `references-2026-09-18/README.md` : images déjà produites et limites de revue.

Skill demandé : `.agents/skills/woop-cartes/SKILL.md`, à rendre découvrable dans
`~/.codex/skills/woop-cartes` comme le skill chauffe du projet. Le skill guide
les prochaines sessions de développement ; il ne déploie rien à lui seul.


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
