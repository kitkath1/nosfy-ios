# Cartes — finir le branchement des trois familles

18 septembre 2026. **Plan uniquement, demandé par Kathryn.** Aucun changement
Swift, SQL, Edge Function ou donnée distante dans cette passe. L’approbation
artistique ne signifie pas que les cartes sont disponibles dans l’app.

## Ce qui est arrêté

- Trois familles, 14 références d’atelier : Forêt des Veilles (4), Cimes Éteintes
  (6, dont deux paysages communs), Bois Sans Lune (4 : clairière v2, créatures v3).
  Source : `familles-2026-09-18.json`, noms FR/EN et SHA-256 des PNG originaux.
- Une référence = même illustration, nom localisé, rareté et finition pour tous.
  Les exemplaires et souvenirs de séance sont personnels. Deux scènes du même
  personnage sont deux références, jamais un faux doublon.
- Corbeau, chauve-souris et loup reconnaissables entre Cimes et Bois ; conserver
  visage, proportions et détails, changer pose, angle, action et interaction
  avec le décor. Ne pas simplement recolorer ou changer le fond.
- Full art, cadre actuel, lunes de rareté, texte blanc minimal, manège conservé.
  Les manquantes gardent leurs emplacements vides, sans image ni nom révélé.
- Le sachet noir garantit toujours une légendaire. Comparaison entre amis,
  échanges, nouvelles familles et chapitre Compte sont hors de cette livraison.
- Les PNG ont des reflets peints. Le shiny animé reste à réaliser et mesurer ;
  il ne doit pas retarder un catalogue fiable ni devenir la seule belle récompense.

## Point de départ vérifié, pas une nouvelle mesure serveur

Lecture et preuves des17–18 septembre : `ANALYSE-CARTES-2026-09-17.md`,
`integration-2026-09-18/schema-avant.json` et page documentaire `#forge`.
Le catalogue alors lu contient9 images,28 exemplaires et aucune des14 nouvelles
références. `cards` et `user_cards` existent, ainsi que la relecture de collection
et le cache disque. Ces mécanismes sont à prolonger, pas à recréer.

Défauts à traiter : la collection regroupe par famille ; `card_id` se perd dans
le rendu ; scellement du sachet puis insertion de l’exemplaire sont séparés ;
35 % des tirages demandent une nouvelle création, ainsi qu’une rareté vide ;
les totaux du profil sont en dur. La reprise serveur des sachets non scellés a
une fenêtre de6h, insuffisante pour une reprise durable. Une image décorative
peut apparaître avant la véritable réponse. Aucune correction de ces points ici.

## 1. Préparer le catalogue de lancement

Revoir les14 PNG sous le cadre réel, en petite vignette et sur iPhone : marges
d’ailes/bois, médaillon, contraste de nuit, croissant homogène. Vérifier en
particulier l’anatomie de la chauve-souris suspendue et les noirs de la clairière.
La sélection artistique est faite ; cette QA technique reste ouverte.

Étendre le catalogue existant avec une référence stable et les propriétés :
monde, collection, personnage éventuel, noms FR/EN, rareté, finition,
chemins des ressources immuables, empreinte et statut brouillon/publié/retiré.
La clé éditoriale du manifeste sera mappée à un `card_id` serveur ; ne pas la
confondre avec un UUID déjà déployé. Les variantes normale/shiny éventuelles
ont deux références liées au même personnage. Pas de loterie shiny supplémentaire
implicite : désigner les références qui portent cette finition avant publication.

Publier les ressources avant d’activer leurs références, vérifier leur accès,
les quatre raretés disponibles et les totaux. Ne jamais écraser un fichier
possédé. Une carte retirée des tirages reste lisible par ses propriétaires.
Les cartes historiques conservent leurs identifiants, images et exemplaires ;
aucune fusion automatique par famille ou ressemblance.

**Preuve de sortie :** manifeste publié relu, images/hash vérifiés, chaque rareté
serviable, zéro exemplaire ancien perdu. Les accès administratifs voient le
catalogue ; le profil ne reçoit que les cartes possédées et les totaux nécessaires.
L’absence de spoiler dans l’interface n’est pas une promesse de secret absolu :
le bucket historique est public. Protéger les nouveaux brouillons et décider
explicitement des droits de lecture des nouveaux arts avant publication.

## 2. Rendre l’attribution atomique et rejouable

Une opération serveur doit vérifier le compte et le sachet, reprendre son
résultat si déjà attribué, choisir uniquement une référence publiée, puis
sceller, créer l’exemplaire et avancer les garanties dans une même transaction.
Verrouiller dans un ordre constant le joueur puis le sachet : deux appareils
ne doivent pas contourner les compteurs ou consommer deux sachets pour un même
geste. Une contrainte d’unicité relie l’acquisition à son sachet ; une clé de
requête idempotente couvre aussi le choix du sachet avant que son ID soit reçu.

Conserver la garantie noire et le prix déjà gérés. La provenance de séance
vient du serveur, jamais d’un `workout_id` cru dans la requête cliente. Les
sachets de conversion sans origine de séance gardent une provenance honnête.
Un catalogue vide/refus réseau avant attribution ne doit pas dégrader la rareté
promise ou perdre le sachet. Une panne après commit permet de relire le même
résultat ; après rollback, aucun gain ni compteur partiel. Prévoir une reprise
au-delà de6h, et une réparation auditée des éventuels anciens sachets scellés
sans exemplaire, en conservant leur `card_id` et sans double attribution.

Séparer l’atelier IA du tirage des utilisateurs. L’atelier crée et fait valider
les illustrations ; l’ouverture distribue celles déjà publiées. Supprimer la
création aléatoire pendant le manège uniquement lors de ce futur branchement.

**Preuve de sortie :** même sachet rejoué/concurrent = même carte et un seul
exemplaire ; panne injectée aux étapes critiques = tout ou rien ; garantie noire
respectée ; reprise ancienne sans perte ; aucune écriture client directe.

## 3. Relier le résultat jusqu’à la collection

Transporter `card_id`, famille, personnage, noms localisés, rareté, finition,
ressources et identité de l’exemplaire jusqu’au dévoilement puis au profil.
Adapter `ForgeServeur`, `LuneForge.Carte`, les modèles de carte reçue,
`BoosterLab`, `CollectionLune` et `ma_collection()` ensemble. Prévoir la
compatibilité des anciens clients pendant le déploiement, par contrat versionné
ou déploiement additif avant bascule ; ne pas changer silencieusement leur forme.

Compter les doublons par `card_id`, les exemplaires par acquisition. Le cache
existant se clé par référence/empreinte, pas seulement par famille ; le vider
ne détruit aucune propriété. Purger l’état d’affichage au changement de compte.
Les totaux viennent du catalogue publié, restent cohérents quand il évolue et
ne provoquent pas une plage négative si une ancienne collection dépasse un total.

Le manège révèle uniquement la carte réellement attribuée. Si le téléchargement
échoue après attribution, afficher l’attente/reprise du même résultat : aucune
fausse carte acquise, aucune nouvelle dépense. Déconnexion, réinstallation et
nouvel appareil doivent retrouver la même collection depuis le serveur.

**Preuve de sortie :** deux comptes possèdent la même référence et les mêmes
pixels, tout en ayant des collections séparées ; un même personnage dans deux
mondes reste deux cartes ; relance/réinstallation retrouvent les acquisitions ;
les manquantes sont vides et les libellés FR/EN désignent la même référence.

## 4. Un rythme généreux pour quelques séances par semaine

**Candidat à simuler, pas un barème actif ni une décision déployée.** Il remplace
le candidat historique6/12 ouvertures et6séances du premier plan.

- Poids de base proposés :45 % communes,35 % rares,15 % épiques,5 % légendaires.
- Première ouverture ordinaire : rare ou mieux ; jamais plus de deux communes
  ordinaires consécutives. Si une garantie légendaire est acquise, elle prime.
- Première légendaire : au plus tard au6e booster ordinaire, ou à la prochaine
  ouverture ordinaire après2séances éligibles distinctes, première borne atteinte.
- Ensuite : au plus tard au8e booster ordinaire depuis la dernière légendaire,
  ou à la prochaine ouverture ordinaire après3séances éligibles sans légendaire.
- Les séances comptent à leur clôture serveur vérifiée ; un rejeu de clôture ne
  recompte pas. Utiliser les vrais critères d’éligibilité des gains, sans changer
  le barème des séances. La nouvelle protection ne doit pas récompenser des UUID
  de séances inventés : la validation de clôture est une dépendance de production.
- Une ouverture réussie avance une seule fois ses compteurs. La légendaire
  effectivement attribuée, y compris noire, satisfait la garantie d’accueil et
  remet à zéro l’attente de légendaire. Le noir ne compte pas comme ouverture
  ordinaire. Compteurs persistants côté joueur ; absence, erreur et réinstallation
  ne les effacent pas. Pas de perte de progression liée aux jours sans sport.
- Les séances terminées avant la dernière attribution ne sont pas reportées
  dans le cycle suivant. Un joueur peut stocker ses sachets : la garantie existe
  à la prochaine ouverture, elle ne prétend pas attribuer automatiquement une carte.

En ouvrant au moins un booster après chaque séance éligible, les bornes proposées
sont : première légendaire en2séances maximum, suivantes en3séances maximum.
À1séance/semaine :2puis3semaines au maximum ; à2séances/semaine :1puis1,5semaine
en rythme régulier ; à3séances/semaine : au plus une semaine entre légendaires.
Les séances longues avec plusieurs boosters peuvent atteindre la borne par
ouvertures plus tôt. Ce sont des plafonds conditionnels calculés, pas des mesures
joueur ni des dates garanties en cas d’interruption ou de sachets non ouverts.

Le catalogue retenu ne contient que3légendaires. Proposer une priorité aux
légendaires encore manquantes jusqu’à avoir découvert les3, puis des doublons
normaux ; cette proposition ne change pas les références partagées entre joueurs.
Simuler avant fixation :1/2/3séances par semaine, petits gains/cardio/séances
longues,1/2/3/5boosters, noirs, stock non ouvert, absences et vrais doublons.
Rapporter médiane/p95/maximum avant légendaire, taux effectif par rareté, nouvelles
cartes par séance et temps pour découvrir les14. Le chiffre historique11,10 %
concerne un autre modèle et ne doit pas être réutilisé pour celui-ci.

L’attachement vient de belles découvertes, personnages familiers et souvenirs.
Ne pas ralentir artificiellement les légendaires pour compenser un petit catalogue.
Le lancement peut rester modeste ; son extension éditoriale vient ensuite.

## 5. Shiny et QA avant le verdict final

Réutiliser foil/tilt existants, puis un éveil bref sur la carte visible seulement.
Finition officielle partagée, poster immobile, arrêt hors écran/recouverte/en
arrière-plan, Reduce Motion et protections thermiques. Charger le skill chauffe
avant toute réalisation. Pas de grille animée en permanence. Mesurer le supplément
sur iPhone après repos et comparer au même parcours sans l’effet.

La QA finale couvre compte neuf et existant, deux comptes séparés, même référence,
doublons, FR/EN, absence d’accès croisé, tentative d’écriture directe, stock noir,
concurrence, coupure avant/après attribution et téléchargement, reprise après6h,
déconnexion/réinstallation, catalogue vide, ancienne version cliente et rollback.
Tester sur comptes QA dédiés ; ne pas remettre le compte personnel à zéro.

Déployer d’abord les changements additifs et ressources vérifiées ; basculer le
tirage sous règle serveur réversible, puis le client compatible. Une désactivation
suspend les nouveaux tirages sans effacer les cartes déjà attribuées. Relever les
erreurs d’attribution, reprises, latence et écarts collection/sachets. Aucune clé
privilégiée dans l’app ; droits et RLS testés avec deux identités réelles.

**« Tout est bon » seulement après preuves du parcours réel.** Aujourd’hui : art
retenu, galerie documentaire produite ; branchement, cadence, rendu iPhone et
shiny animé encore à faire. Les résultats vont dans les briques/mesures du site,
source et livrable ensemble. Le contrôle de chauffe débranché et l’haptique de
l’île restent des validations distinctes, encore ouvertes dans leur chapitre.

## Références de mise en œuvre à relire

- `Nosfy/Services/ForgeServeur.swift`, `Nosfy/Views/BoosterLab.swift`,
  `Nosfy/Views/SacreAccueil.swift` et `supabase/functions/forge-card/index.ts`.
- `ANALYSE-CARTES-2026-09-17.md` et le manifeste des familles.
- [RLS Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security) :
  droits SQL et politiques par propriétaire se vérifient ensemble.
- [Fonctions de base de données](https://supabase.com/docs/guides/database/functions) :
  cadrer les privilèges du point d’entrée ; ne pas exposer une écriture privilégiée
  sans contrôle d’identité. Documentation consultée le18-09, à relire à l’implémentation.
