# Premier vrai utilisateur TestFlight — analyse du 19 septembre 2026

**Mise à jour après la demande de Kathryn :** les **50 cartes sont requises
pour le lancement** et restent le chantier de la session Cartes. La recommandation
initiale de reporter les 36 références manquantes est retirée. Le défaut de reçu
après reconnexion est désormais corrigé et mesuré :
[preuves du correctif](../stories-historique-2026-09-19/README.md).

**Verdict : préparer un pilote fermé est justifié ; l’expérience complète de
la version distribuée n’est pas encore validée.** Le lancement dépend d’un
binaire actuel disponible dans TestFlight et de son statut Apple. La création
Apple et le lendemain doivent faire partie du premier essai de ce binaire.
Il n’est pas nécessaire d’achever toute la feuille de route pour commencer
ce pilote. Aucun téléphone utilisé, aucun code produit modifié ou déployé.

## Ce qui a été relu et mesuré dans cette passe

- Supabase : `ACTIVE_HEALTHY`, inscriptions ouvertes, Apple actif pour
  `fr.kathryn.woop`, quatre secrets Apple présents, six Edge Functions actives.
  Lecture seule : `backend-config.json`. La présence des secrets ne prouve
  pas un échange réussi avec un vrai code Apple.
- Parcours Compte : **50 PASS, 0 FAIL**, deux comptes temporaires nettoyés.
  Profil et objectif, compte neuf vide, première séance, gains, absence de
  doublon, séparation entre comptes, reconnexion et suppression :
  `compte-flow.log`.
- Client Swift d’inscription : **12 PASS**, réseau remplacé. Réponses gardées
  en cas de panne, refus ou réponse incomplète ; entrée après confirmation :
  `inscription.log`.
- Les **20 contrôles Swift connectés et 44 API** de la passe précédente
  restent la preuve des échanges de séances, reçus, annonces, quotidien,
  boosters, collection et pull. Voir `../reverification-front-back-2026-09-19/`.
- **Release iPhone arm64 : BUILD SUCCEEDED**, sans signature ni archive.
  `build-release.log` et `build-constats.json` : app et widgets 1.0 (1), iOS 26
  minimum, chiffrement non exempt déclaré faux, manifeste de confidentialité
  présent. Les 249 sources suivies par le manifeste de la passe connectée sont
  identiques au contrôle final. Ce build ne produit pas un accès TestFlight.

**Limite essentielle :** les comptes des bancs API sont créés par l’API admin,
puis utilisent des sessions ordinaires. Un utilisateur réel entre uniquement
par Sign in with Apple (`AppleAuth.entrer`). La feuille Apple a une preuve
historique du 14 septembre ; l’échange et la révocation depuis la pose de la
clé du 18 septembre ne sont pas prouvés sur la version destinée à sortir.

## Le parcours que le premier testeur doit pouvoir faire

| Étape | Ce qui est étayé | Ce qui manque pour conclure sur la version TestFlight |
|---|---|---|
| Installer puis créer son compte Apple | Entitlement présent, provider actif, inscriptions ouvertes ; ancien parcours Apple mesuré | Binaire distribué identifié et première entrée Apple sur celui-ci |
| Choisir langue, prénom et objectif | Écriture du profil confirmée ; panne et reprise testées | Enchaînement visuel complet depuis la feuille Apple |
| Arriver avec un compte vide | API : zéro séance, pièce, sachet et carte ; calcul Route au premier galet | Montage normal de la home, de la visite et du Coffre dans cette installation |
| Faire une séance | Travail fait synchronisé, clôture durable, gains sans doublon | Une séance depuis les commandes normales du binaire distribué |
| Voir story et galet accompli | Reçu réel dans la story ; deux parcours UI simulateur pour story → Route | Même chaîne depuis cette première inscription, sans données de banc |
| Ouvrir un booster et retrouver sa carte | API et vrais décodeurs ; autre session : orange/noir et reprise après réponse perdue PASS au simulateur | Parcours depuis le sachet gagné par ce nouveau compte |
| Revenir le lendemain | Disponibilité serveur, Claim sans double versement, gardes Welcome Back testées | Retour à J+1 de cette identité dans la version distribuée |
| Se reconnecter et retrouver son historique | Séances, gains et collection relus ; comptes isolés ; reçu de story désormais restauré, 24 contrôles Swift connectés et 17 API PASS | Parcours dans le binaire distribué contenant le correctif |
| Supprimer son compte | Suppression backend et cascade testées | Stockage puis révocation d’un vrai jeton Apple depuis la nouvelle configuration |

Le retour quotidien dépend du jour serveur après une première séance terminée.
Le test de Claim ne constitue pas une observation à J+1. La règle actuelle peut
autoriser un Claim dès le jour de cette première séance : ne pas décrire le
backend comme imposant une attente de 24 heures.

## Ce qui conditionne l’invitation

1. **Figer les sources et produire l’archive actuelle.** Les preuves d’archive
   et d’export du build 79, datées du 18 septembre, précèdent les derniers
   changements. Les identifiants de l’app et des widgets sont en place ; le
   numéro inscrit dans le projet reste 1, les builds de banc utilisent des
   surcharges. Choisir le prochain numéro après lecture des builds App Store
   Connect, puis conserver les sources exactes et la preuve de signature.
2. **Relire App Store Connect.** Fiche `fr.kathryn.woop`, état du build,
   métadonnées de test, contact, confidentialité et conformité du build final.
   Cette passe n’a pas accès à un état authentifié d’App Store Connect ; aucun
   build prêt à inviter n’est donc affirmé. Le manifeste de confidentialité et
   la déclaration de chiffrement sont déjà dans les sources.
3. **Choisir le bon circuit pour le testeur.** Une personne qui n’est pas un
   utilisateur App Store Connect est un testeur externe, même seule et invitée
   en privé. Le premier build externe passe par TestFlight App Review ; ne pas
   envoyer une version « TestFlight Internal Only » pour ce groupe. Le délai
   dépend d’Apple et aucun délai fixe n’est promis.
4. **Publier et vérifier les 50 cartes demandées.** Ce prérequis est suivi
   par la session Cartes ; la dernière mesure du catalogue donnait 14 références.
   Le présent correctif Stories ne modifie aucun art ni catalogue.

Références Apple relues le 19 septembre :
[inviter des testeurs externes](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers),
[états des builds](https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses),
[conformité des builds bêta](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-export-compliance-information-for-beta-builds).

## Le seuil entre pilote et ouverture plus large

Le premier pilote fermé sert à mesurer l’entrée Apple et le parcours normal,
avec les défauts connus annoncés. Pour annoncer une expérience complète,
intégrer le correctif de reçu après reconnexion et vérifier le parcours ci-dessus,
y compris J+1 et le cycle du compte, sur la même version distribuée. Si la
création Apple, la sauvegarde, les gains ou l’ouverture bloquent ce pilote,
ne pas élargir les invitations avant correction.

Les 50 cartes conditionnent le lancement demandé : les 36 références restantes
sont en cours dans une autre session. Le conseil IA par exercice reste absent au serveur,
avec un texte de repli dans l’app ; il ne faut pas le présenter comme livré.
La chauffe, les haptiques et les alertes d’exploitation restent des réserves
distinctes. Les tests d’API ne ferment pas ces lignes et cette analyse ne
demande aucun nouvel essai sur le téléphone personnel.

## Documentation et Git

Cette passe actualise la page Compte, la page QA et la mesure de distribution.
Le vieux KO Cartes de QA19 est remplacé par les preuves du 19 septembre :
parcours simulateur réussis, validation physique toujours ouverte. Les preuves
de l’autre session sont conservées et aucun travail Cartes n’est modifié.

Aucun commit/push demandé ou effectué. Nouveaux fichiers : ce dossier.
Fichiers partagés modifiés par lignes : `docs/site/content/pages/porte.mdx`,
`docs/site/content/pages/qa.mdx`, `docs/site/content/qa.ts`,
`docs/site/content/mesures.ts`, `docs/site/index.html`, `MULTI-SESSION.md`.

Livrable documentaire régénéré puis vérifié : 23 tests réussis, dix pages sans
débordement à 390 px, livrable identique au build (`doc-artefact.log`,
`doc-verif.log`). `main` et `origin/main` alignés au contrôle final.
