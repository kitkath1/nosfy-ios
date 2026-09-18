# Cartes — collection commune et illustrations IA

Analyse demandée le 17 septembre 2026. Aucun code applicatif, migration,
déploiement, tirage, crédit ou génération IA effectué. Seule la documentation
est modifiée ; le chapitre « Forge » devient « Cartes ». Les identifiants
techniques existants restent inchangés.

## L’intention

Un catalogue commun que les joueurs peuvent collectionner et comparer.
Une carte précise possède la même illustration, le même nom et la même rareté
chez tous ses propriétaires. La génération enrichit ce catalogue partagé ;
chaque joueur doit ensuite obtenir son exemplaire par les règles du jeu.

Exemple proposé : deux joueurs possèdent « L’oiseau souverain », référence
LUNE-023. Cette référence désigne exactement le même visuel chez les deux.
Le numéro est un exemple de conception, pas une référence déjà attribuée.

Question laissée ouverte : une seule illustration par carte prévue, ou plusieurs
versions officielles distinctes et numérotées ? Dans les deux cas, chaque version
doit être une référence stable et commune. Aucun choix de variante n’est appliqué.

## Ce que le serveur contient réellement

Lecture seule par la CLI, projet Woop `ytnnyjkramgiqyxdrkcu`, le 17-09.

| Observation | Résultat |
|---|---|
| Illustrations dans `cards` | 9 : 6 communes, 2 rares, 0 épiques, 1 légendaire |
| Familles représentées | 7 ; « Montagnes invisibles » et « Petite lune perdue » ont chacune deux illustrations |
| Familles prévues dans le code | 25 : 4 communes, 11 rares, 4 épiques, 6 légendaires |
| Exemplaires dans `user_cards` | 28, tous sur un seul compte ; 9 `card_id` distincts |
| Carte possédée par deux comptes | 0 observée ; le modèle le permet, le parcours à deux comptes reste à tester |
| Provenance séance | 0 exemplaire avec `workout_id` renseigné |
| Carte scellée sans exemplaire correspondant | 0 observée ; ce contrôle ne reproduit pas une panne entre les deux écritures |
| Profondeur précalculée | `depth_path` nul pour les 9 illustrations ; l’app utilise sa profondeur analytique |
| Publication / numérotation | Pas de statut brouillon/publié, numéro ou édition dans `cards` |

Le principe de partage est explicitement documenté dans
`supabase/migrations/20260814180000_cartes_lune.sql` : une image stockée commune,
et des exemplaires personnels qui la référencent. Le catalogue est lisible par
les comptes authentifiés ; chaque collection personnelle est filtrée par son
propriétaire. Partager une référence ne rend pas toutes les collections publiques.

## Ce qui empêche encore une collection comparable

1. **Les familles masquent les cartes.** La fonction distante `ma_collection()`
   regroupe par famille et rareté, compte tous les exemplaires, puis choisit
   l’image obtenue le plus récemment. Deux illustrations différentes d’une même
   famille deviennent un seul emplacement ×N. Ce cas existe déjà dans les données.
   Côté app, `CollectionLune.destination/poser` utilise aussi la famille ;
   `LuneForge.Carte` ne garde pas l’identifiant renvoyé par le serveur.
2. **La création et la distribution sont mêlées.** Le code courant impose une
   création IA dans 35 % des tirages ordinaires, et en crée aussi si la rareté tirée
   n’a pas d’image disponible. La nouvelle image entre immédiatement dans le
   catalogue. Il n’existe pas d’étape de sélection artistique avant distribution.
   La rareté est correctement tirée une seule fois depuis le correctif v6 ;
   ce correctif n’a pas changé la politique de création.
3. **Le catalogue est décrit trois fois.** Familles et raretés dans Deno et
   Swift ; objectifs 4/11/4/6 encore en dur dans le profil. Un ensemble de cartes
   publié doit porter lui-même les références et le total à collectionner.
4. **L’attribution n’est pas entièrement transactionnelle.** `forge-card` scelle
   le sachet, puis écrit séparément `user_cards`. Si la deuxième écriture échoue,
   le rejeu rend la carte scellée sans réparer la collection. Risque identifié
   à la lecture, non reproduit et aucune anomalie correspondante observée.
5. **La reprise reste à terminer.** L’ouverture ordinaire reprend un sachet
   ouvert non scellé dans une fenêtre de 6 h ; le marqueur de cérémonie côté
   téléphone et le parcours coupure/relance demandent une validation complète.
   Une reprise durable doit respecter les anciens sachets déjà présents.

Le stockage et le cache disque des images existent. La documentation historique
qui annonçait une collection seulement en mémoire, ou un `booster_id` jamais
transmis, est périmée. Ces travaux ne doivent pas être reconstruits inutilement.

## La direction artistique à finir

Trois PNG existants relus : Forêt de pins (commune), Dragon des ténèbres (rare),
L’oiseau souverain (légendaire). Copies de lecture dans `/tmp/woop-cartes-analyse/`.

Mon appréciation : lune, nuit et braise donnent une cohérence nette. La forêt
commune est presque absorbée par le noir ; le dragon est mieux reconnaissable ;
l’oiseau a davantage de relief mais son cadrage et son décor peuvent être
beaucoup plus singuliers pour une légendaire. Cette appréciation porte sur ces
trois images, pas sur un test visuel de tout le catalogue sur téléphone.

La charte actuelle demande déjà une finition élevée pour toutes les raretés.
Il faut la faire respecter par une sélection : sujet reconnaissable en vignette,
silhouette mémorable, plans séparés par la lumière, matière détaillée, lune
cohérente et cadrage qui fonctionne sous le cadre réel. Une commune peut être
calme et magnifique ; les raretés supérieures gagnent en composition, échelle,
présence et matière. Les effets foil et tilt accompagnent une bonne illustration.

**Proposition : atelier IA → propositions → sélection humaine → publication →
tirages dans le catalogue publié.** Les essais rejetés restent hors du catalogue
des joueurs. Après publication, un visuel reste stable ; une nouvelle illustration
devient une nouvelle version identifiée. La rareté conserve un tirage défini au
serveur ; une réserve vide doit être traitée explicitement, sans changer en
silence la rareté promise.

Ce fonctionnement permet de travailler les images autant que nécessaire en
atelier, puis de faire ouvrir les sachets avec des images déjà disponibles.
Il reste une proposition à valider ; la génération pendant le tirage fonctionne
encore comme avant dans l’app déployée.

## Plan de réalisation proposé

1. **Catalogue :** fixer les références officielles, nom, rareté, illustration,
   éventuelle version et statut de publication. Une seule source pour l’app et
   le serveur. Définir le premier ensemble à terminer sans changer ses cartes
   déjà possédées ; examiner les 9 images existantes avant toute migration.
2. **Atelier artistique :** produire et sélectionner les images du premier
   ensemble. Commencer par une commune, une rare, une épique et une légendaire
   de référence ; les valider dans le vrai cadre et à taille de téléphone avant
   d’étendre la série. Aucune génération lancée pendant cette analyse.
3. **Distribution fiable :** tirer dans les références publiées, sceller et
   attribuer dans une transaction, dériver la séance depuis le sachet, protéger
   les doubles appels et les reprises. La garantie du sachet noir est conservée.
4. **Collection fidèle :** conserver le `card_id` jusqu’au rendu, afficher les
   véritables doublons par carte ; les variantes distinctes restent identifiables.
   Les totaux viennent de l’ensemble publié. La comparaison entre joueurs pourra
   s’appuyer sur ces références ; une page sociale n’est pas incluse d’office.
5. **QA :** deux comptes obtiennent la même référence et affichent les mêmes
   pixels ; vérification des doublons, de la réinstallation, de la reprise après
   coupure, des appels concurrents et de la garantie légendaire. Contrôler aussi
   le chargement des images et l’arrêt des effets hors écran sur iPhone.
6. **Documentation :** passer chaque ligne au vert seulement après sa preuve.
   Le chapitre Cartes reste en chantier ; aucune promesse « Tout est bon » à
   partir de cette seule analyse.

## Sources principales

- `supabase/functions/forge-card/index.ts` : choix, création, scellement, attribution.
- `supabase/migrations/20260814180000_cartes_lune.sql` : catalogue et exemplaires.
- Définition distante de `public.ma_collection()` lue le 17-09 : groupement par famille.
- `Woop/Services/ForgeServeur.swift` : réponse reçue, image habillée, identifiant perdu.
- `Woop/Views/SacreAccueil.swift` : collection par famille et cache disque par `card_id`.
- `Woop/Services/LuneForge.swift` et `Woop/Views/ProfilLune.swift` : familles et totaux.
- `tools/carte-lune/PROMPTS.md` : charte de génération existante.


## Validation de cette documentation

Chapitre, navigation et carte de domaine renommés « Cartes » ; ancre technique
`#forge` conservée. Artefact régénéré, vérificateur complet PASS20s (23 tests,
contrôles de contenu, de rendu et de largeur). Captures localhost1440/390 relues,
aucun débordement. Preuves dans `tools/carte-lune/preuves-analyse-2026-09-17/`.
Le premier contrôle a refusé un titre de61 caractères : raccourci, puis chaîne
de vérification complète rejouée. L’assertion de navigation a été ajustée pour
lire « Cartes » avec son compteur séparé ; le chapitre et les deux largeurs
ont ensuite été vérifiés. Aucun commit, aucun correctif applicatif déployé.
