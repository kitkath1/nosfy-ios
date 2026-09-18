# Production — contrôle du 18 septembre 2026

**Verdict : pas encore prête pour la production, même hors Forge.**
Le commit Compte `507018ca` livre son périmètre ; il ne qualifie pas toute
l'application. Ce contrôle complète les preuves du 17-09 et remplace toute
lecture de « serveur prêt » comme une autorisation globale de publication.

## Actualisation après correctif Compte / Gains / Route

Migration20260918083033 **déployée avec accord explicite**. Le défaut de
rémunération sans séance et la démo Route décrits plus bas sont corrigés.
35 contrôles API,51 Compte,13 Outbox,12 sync et1074 Route PASS ; compilation
Debug simulateur partagée réussie. Release isolée en échec sur dépendances
front antérieures non committées ; voir compte-progression-2026-09-18/build-isole.log.
Les données existantes sont conservées. Les anciens
binaires doivent recevoir le nouveau raccord pour payer les prochaines séances.

**Restent avant production** : vraie connexion/révocation Apple et QA iPhone
Compte neuf, restitution après reconnexion, intégration Forge/chauffe,
CGU finales et qualification de la version de sortie. L’analyseur sécurité
remonte52 avertissements (principalement fonctions definer exposées) : les
gardes de ce correctif ont été testées, cela ne constitue pas une revue globale.
Preuves actuelles : `compte-progression-2026-09-18/README.md`.

## Complément Compte, Route et rewards

40 contrôles API supplémentaires PASS : compte neuf vide,7séances, lune,
ouverture des sachets gagnés et collection/rewards/progression retrouvées par
une nouvelle session.2554 contrôles Route et9 pull Swift PASS. Corrigés :
bouton du trésor final, relecture après Apple sans quitter l’app, états Route
vidés entre comptes et réponses anciennes ignorées. L’iPhone76 possède2séances
terminées avec mêmes UUID et séries côté serveur, pas38dans cette installation.
Aucun effacement.77 doit encore être installé/testé avec Apple ; la première
création Apple et la révocation sur identité dédiée restent à mesurer.
Preuves : `compte-iphone-2026-09-18/README.md`.

## Constat initial de08:35 — historique, avant le correctif

## Ce qui est démontré

- Compte neuf au banc : profil incomplet, zéro pièce, zéro sachet, collection
  vide ; inscription, visite et première séance avec une série ; gains personnels,
  rejeu sans doublon, reconnexion, isolation et suppression en cascade.
  `verif_compte.py --flow` : **50 PASS**, journal dans
  `../porte/preuves-2026-09-17/compte-flow-2026-09-18.log`.
- Client Swift d'inscription : **12 PASS** avec réseau remplacé ; session et
  renouvellement : **15 PASS**. Ces 77 contrôles couvrent les scénarios du banc,
  pas toutes les entrées possibles du serveur ni la feuille Apple réelle.
- Lecture du 18-09 à 08:35 Paris : Supabase `ACTIVE_HEALTHY`, connexion Apple
  activée, inscriptions ouvertes, accès anonyme désactivé, JWT de 3 600 secondes.
  Une valeur de configuration absente (`null`) n'est pas une validation.
  Preuve : `preuves-2026-09-18/backend.json`.

## Route du compte vide — corrigée le18-09

Zéro séance terminée démarre au premier galet du chapitre1, en haut,
sans faits ni dates fictives :34 contrôles Swift PASS. Contrôle iPhone
encore à faire. Contrat backend, cause et preuves :
`../duolingo/preuves-compte-vide-2026-09-18/README.md`.
La progression NON VIDE reste en démo par défaut et doit être finalisée
avant de qualifier le parcours de progression en production.

## Ce qui empêche de dire « tout est bon »

| Point | Preuve actuelle | Condition de fermeture |
|---|---|---|
| **Intégrité des gains — bloquant backend** | Une clôture authentifiée avec un UUID de séance absent et `p_series=1` répond 200, `faits_raison=seance_inconnue`, et crédite **20 pièces + 1 sachet**. | Valider côté serveur la séance, son propriétaire, sa fin et le travail rémunérable avant tout gain ; mesurer absente / étrangère / inachevée / nombre déclaré incohérent / rejeu / rattrapage réseau. |
| **Révocation Apple incomplète** | Clé fournie et quatre secrets installés le 18-09 à 08:58 Paris. Sonde : apple_400 / invalid_grant pour un code factice ; compte QA nettoyé. La révocation réelle reste non mesurée. | Mesurer un vrai échange Apple, le stockage du jeton, la suppression et la révocation/rejeu sur une identité dédiée. Preuve de pose : `../porte/preuves-apple-2026-09-18/installation.log`. |
| **Compte neuf sur iPhone** | Les contrôles API passent ; QA 08–13 garde des verdicts ouverts. La première séance complète, ses annonces et ses stories n'ont pas été qualifiées dans ce parcours. | Jouer la feuille Apple, Nosfy, séance, gains, annonces/story, relance, déconnexion/reconnexion et suppression sur un compte de test dédié. Forge validée par sa session. |
| **Compte existant et historique** | Le profil Apple identifié par le prénom n'a actuellement qu'une séance ouverte côté serveur ; les ~38 séances évoquées ne sont pas rapprochées de cette identité. | Comparer l'identité de la session iPhone, les séances locales/serveur et la file d'attente, sans effacement. Vérifier ensuite la restitution après relance/reconnexion. |
| **Version réellement publiable** | Release réussie dans l'arbre partagé ; compilation du commit Compte isolé en échec sur des interfaces antérieures hors Compte. | Intégrer les travaux des sessions concernées, puis compiler et qualifier la révision complète destinée à sortir. Journal : `../porte/preuves-2026-09-17/build-commit-arm64.log`. |
| **Forge et chauffe** | Travaux parallèles encore en cours ; leur résultat ne se déduit pas des tests Compte. | Verdicts et preuves des sessions responsables, puis parcours intégré. Aucun test physique lancé par ce contrôle. |
| **Conformité App Store** | Après-midi du 18-09 : `ITSAppUsesNonExemptEncryption = false` (app + widgets) et `Nosfy/PrivacyInfo.xcprivacy` posés, lus dans le bundle compilé (plutil). Bancs économie portés sur `synchroniser_seance` : cardio 22 ✓, faits 14 ✓, coffre 53 ✓ après 083033. | Re-archiver en 80 ; lecture d'App Store Connect (fiche, déclarations) toujours à faire. |
| **CGU visibles dans l'app** | Constat de 08:35 : `ProfilLune.swift` contenait le texte d'attente. **Après-midi du 18-09** : texte posé dans `Nosfy/Views/CGUPage.swift` (14 articles FR/EN, version datée du 18-09, rédigé d'après l'état attesté par le site : Apple seul, profil, séances, carnet, sachets, cartes, bilans IA). **Non relu par Kathryn, affichage non mesuré** sur simulateur ni téléphone. | Relecture juridique par Kathryn (éditeur, contact, âge minimal 15 ans, droit applicable), puis affichage vérifié dans Réglages → CGU, en fr et en en. App Store Connect et ses déclarations n'ont pas été inspectés ici. |

Le point intégrité est **reproduit, pas corrigé** dans ce contrôle. Les autres
entrées adverses du tableau sont les critères du futur correctif, pas des
vulnérabilités déjà toutes démontrées. Le banc du 15-09 acceptait explicitement
la clôture avant réception d'une séance : la nouveauté ici est le test de
l'invariant de rémunération, pas une régression attribuée au commit Compte.

Attention à la reprise hors ligne : `SupabaseSync.push` absorbe les erreurs et
les envois arrivent table par table ; la RPC reçoit ensuite la clôture.
`OutboxGains` traite la plupart des 4xx comme définitifs. Ajouter seulement un
refus HTTP 400 risquerait de perdre le gain légitime après une synchronisation
partielle. Les séries faites/prévues demandent aussi un contrat explicite :
le push actuel n'envoie pas de champ `isDone`. Le correctif doit couvrir cette
chaîne, sans emporter les changements de la session stories/économie.

Les anciennes mesures sur le chemin (origine de chapitre, jour/séance,
après-35) restent ouvertes dans la documentation. Elles doivent être tranchées
ou explicitement exclues du périmètre publié ; le nombre « 38 » ne prouve pas
à lui seul qu'elles fonctionnent. Les états locaux, archives et références du
site ne sont pas tous des défauts de production : ne pas repeindre ces lignes
pour obtenir artificiellement une carte verte.

## Ton historique : observation, sans nettoyage

Le script `etat_backend.py` sélectionne un profil au prénom Kathryn/Kiki Style
et vérifie une identité Apple. La correspondance avec la session du téléphone
**n'a pas été vérifiée**. Résultat à cette date :

| Mesure serveur | Valeur |
|---|---:|
| Préfixe de compte | `9f5b775d` |
| Séances terminées / ouvertes | 0 / 1 |
| Séries / phases cardio | 0 / 0 |
| Cartes / sachets non scellés | 0 / 0 |
| Solde or / argent | 0 / 0 |

Le préfixe diffère du compte `e3920e3a` documenté le 14-09. Cela ne permet
de conclure ni à une perte de données, ni à une synchronisation correcte des
38 séances. Aucun compte existant n'a été modifié pendant ce contrôle.
Le téléphone reste disponible pour la session chauffe.

## Reproduire et relire

```sh
# Lecture seule, aucun contenu de séance ni secret imprimé
python3 tools/production/etat_backend.py

# Deux comptes QA temporaires, nettoyés ; ne touche pas l'historique existant
python3 tools/serveur/verif_compte.py --integrite
```

Le nouveau contrôle donne **32 PASS, 1 FAIL** et une sortie 1 attendue tant
que le défaut subsiste. Preuve : `preuves-2026-09-18/integrite-gains.log`.
Une seule tentative sur une séance absente ; aucun tirage Forge. Les deux
identités de test ont été nettoyées après lecture du gain indu.

Le site de référence porte ce verdict en pages **Test QA**, **Compte** et
**Coffre**, avec la RPC en rouge dans **Serveur**. `CLAUDE.md` conserve la
règle demandée : documentation et preuves actualisées à chaque changement
ou défaut découvert, « tout est bon » uniquement après validation du périmètre.

## Sources de plateforme

- [Apple — Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/) : suppression du compte depuis l'app et révocation des jetons Sign in with Apple.
- [Supabase — Production checklist](https://supabase.com/docs/guides/platform/going-into-prod) : disponibilité, accès et sauvegardes sont des sujets de mise en production. L'état `ACTIVE_HEALTHY` observé ici ne mesure ni restauration ni charge et ne vérifie pas l'abonnement du projet.

Le lien Artifact distant n'est pas republié par cette session : aucun outil
de publication correspondant n'est disponible. Les sources du site local et
le livrable autonome sont les sorties mises à jour.

## Vérification de la documentation

`npm run artefact` puis `npm run verif` réussis : types, tests, livrable
identique à son rebuild, poids 1 862 575 octets, captures État/Compte relues
à 390 et 1440 px, dix pages sans débordement horizontal. La synthèse QA
a aussi été capturée et relue à 390 px. Journaux :
`preuves-2026-09-18/docs-artefact.log` et `docs-verif.log`.
La réussite de ce vérificateur porte sur le site documentaire, pas sur
l’aptitude de l’app à être publiée. Le test d’intégrité backend reste rouge.
Le libellé trompeur « rien à faire pour toi » a été retiré des compteurs de
chantier : certains prérequis peuvent attendre Kathryn. La clé Apple, absente
lors de cette première lecture, a ensuite été fournie et installée à 08:58 Paris.

## Nom livré sur iPhone et dans Xcode — 18-09 à09:37 Paris

Le projet, les cibles, les schémas et les dossiers sont renommés Nosfy ; les
outils et chemins de preuve suivent ces noms. Release74 compilée, signée et
installée comme mise à jour : CoreDevice relit Nosfy74 avec le bundle existant.
Pas de reset ni déconnexion ; cela ne remplace pas la QA d’un compte existant.
Preuves : `tools/nom/preuves-2026-09-18/README.md`. La session Home/Route peut
ensuite installer75. Les blocages de publication listés plus haut restent ouverts.
