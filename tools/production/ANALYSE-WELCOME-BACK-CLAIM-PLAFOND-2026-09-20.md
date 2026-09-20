# Welcome Back, le bouton Claim, la troisième séance, le galet — analyse du 20-09

Sur ta demande de l'après-midi (« analyse, ne code pas… fais plusieurs tests
avant de me confirmer, niveau serveur, niveau front-end… c'est insupportable
pour les utilisateurs »). Enquête à agents (3 enquêteurs, 1 testeur serveur,
vérification contradictoire, critique), résultats condensés ici. **Rien de ce
document n'est codé**, sauf ce que tu as ordonné ensuite (§ 5 : la date sur
le galet, le sticker ×2 seul, la cinématique).

Ce qui a été **mesuré** l'est sur le vrai serveur (`ytnnyjkramgiqyxdrkcu`) :
en **lecture seule** sur tes deux comptes (toi `9f5b775d`, Margaux
`6692fe98`) et le compte de test `be69f505`, et en **écriture sur deux
comptes jetables** créés puis supprimés (0 ligne restante, vérifié). Ce qui
est **lu** l'est dans le code, à la ligne. Ce qui n'a pas été mesuré est dit.

⚠️ Les lectures de tes deux comptes datent de 10:50-11:05 ; à 11:53, sur ton
ordre, la session Compte les a **remis à zéro** (supprimés, qa-24). Les
chiffres ci-dessous restent vrais comme mesure de ce qui s'est passé sur le
build 81 ; les comptes eux-mêmes n'existent plus.

---

## 1. Welcome Back — pourquoi la card revient à chaque fois

### Ce que tu vois
La card « Welcome back · Claim +10 » revient à chaque retour dans l'app, le
même jour, tant que tu n'as pas réussi un Claim.

### Ce que le serveur a fait (MESURÉ)
Il n'a **jamais payé deux fois**. Sur ton compte : un +10 le 18-09 (08:46),
le 19-09 (11:05), le 20-09 (07:21, heure de Paris). Sur celui de Margaux :
un le 19-09 (10:53), un le 20-09 (09:40). Jamais deux le même jour.

Banc sur compte jetable, **14/14 PASS** :
- sans séance finie → `retour_disponible = false`, Claim refusé
  (`premiere_seance_requise`), 0 ligne ;
- après une séance → disponible ; premier Claim → +10, jour `2026-09-20` ;
- second Claim le même jour → `credite:false`, montant 0, **le même reçu** ;
- **six Claims lancés en parallèle** sur un jour jamais pris (la vraie
  course du « 3-6 taps ») → exactement **un** crédit, cinq rejeux, 1 ligne
  au carnet, 0 erreur, 0,16 s.

La règle serveur est **« une fois par jour civil de Paris »** — pas « 24 h
après » : un Claim à 23 h 50 redevient disponible à minuit (mesuré : 30 min
d'écart entre deux crédits quand la date change) ; une ligne du jour vieille
de 25 h bloque tant que la date n'a pas changé. C'est un index unique
`(user_id, jour)` sur le carnet, doublé d'un reçu `retour:<jour>` :
incassable par construction.

### Pourquoi elle revient quand même (LU, identique dans le build 81, HEAD et l'arbre)
L'app **n'a aucune mémoire « déjà montrée aujourd'hui »**. À chaque passage
au premier plan (`NosfyApp.swift:110-138`) et 3 s après la chute de la porte
au lancement (`:2365-2379`), elle relit `etat_coffre` et propose la card sur
un seul critère : `retour_disponible` vrai (`Compte.swift:234-252`). « Later »,
un tap à côté de la card, une app tuée : rien n'est retenu, la card revient
au retour suivant. **Seul un Claim arrivé au serveur l'éteint.** Combiné au
bouton fragile (§ 2), « à chaque fois » = à chaque fois jusqu'au tap qui
passe.

Fenêtre annexe (lue, non reproduite) : au lancement, deux chaînes proposent
la card ; si tu tapes Claim pendant que la seconde relit `etat_coffre`, une
réponse partie avant le Claim (même version) peut la rouvrir ~4 s après.

### Le correctif, à coder sur ton mot (rien côté serveur)
1. Un marqueur **« présentée le <jour rendu par le serveur> pour ce
   compte »**, posé à l'ouverture de la card, qui survit à une app tuée et
   s'efface avec le compte ; `proposerWelcomeBack` s'y retient tant que le
   jour serveur n'a pas changé.
2. Une seule porte au lancement (la chaîne `phase` OU `.task(id: enPorte)`).
3. Ne proposer que sur une valeur **relue** dans cette passe, jamais en
   cache.

**Décision à prendre (personne ne l'a posée) :** si tu fermes par « Later »,
que devient le +10 du jour ?
- marqueur posé **à l'ouverture** → la card ne revient plus de la journée,
  le +10 est perdu pour ce jour ;
- marqueur posé **au Claim encaissé seulement** → « Later » la fait revenir
  au **prochain lancement** (pas à chaque retour de fond).
Je recommande la seconde : un « Later » ne doit pas coûter 10 pièces.

**Décision « 24 heures » ou « demain à minuit » :** le serveur ne connaît
que le jour civil. Exemple chiffré, lu dans ton carnet : tes Claims du 19
(11:05) et du 20 (07:21) sont espacés de **20 h 16** ; ceux de Margaux de
**22 h 46**. En « 24 h glissantes », **vos deux Claims de ce matin auraient
été refusés**. Je recommande de garder « demain à minuit » (c'est aussi la
règle de la Route et de la flamme) ; si tu veux 24 h pile, c'est un
changement de règle serveur (fonction + index) et l'horloge du coffre
change de sens.

---

## 2. Le bouton Claim — « il faut appuyer 3 à 6 fois »

### Ce que le serveur a vu (MESURÉ, journaux d'accès)
**Un seul appel** `claim_retour_quotidien` par jour et par téléphone, répondu
en 50-120 ms, aucune erreur, aucun rejeu. Mais sur ton iPhone cet unique
appel arrive **16 s** (20-09) et **32 s** (19-09) après l'ouverture de la
card ; chez Margaux 3,4 s et 10 s. Le serveur et la file d'attente (outbox)
sont **hors de cause** : le tap ne déclenche rien pendant 15-30 s, puis un
tap déclenche et tout s'enchaîne en moins d'une seconde.

### Ce qui est certain (LU, bit à bit le build 81)
- **Un tap pendant l'entrée de la card (1,45 s) encaisse sans fermer** :
  `BoutonClaim(action: { onClaim?(); fermer() })` — le +10 part, mais
  `fermer()` refuse tant que la card n'est pas « posée »
  (`RewardCard.swift:186`). Tu retapes ; le second tap est avalé en silence
  (`guard retourDisponible`). Ça explique **deux** taps, pas six.
- **Plus aucune quittance locale au tap depuis le 18-09** (commit
  `c303e58d`) : la dalle « +10 » ne naît que de la **réponse serveur**.
  Trois commentaires du code et la pastille verte du site disent encore le
  contraire (`Annonces.swift:21`, `EconomieNosfy.swift:462-466`,
  `Compte.swift:262`, `briques.ts` b-rg-le-versement-lui-part-vraiment).
- **Le tap réel n'a jamais été mesuré au doigt** : le banc
  `-welcomeClaimAuto` appelle `reclamerRetour()` directement, sans passer
  par le bouton ; « ça a fini par marcher » du 16-09 est déjà le symptôme.

### Ce qui reste à départager (SUPPOSÉ, à mesurer sur ton iPhone)
Le bouton empile : un verre `.clear.interactive()` (connu pour voler le
geste, mémoire du 04-09) + un `Button` + un `highPriorityGesture(Tap)` +
un `DragGesture(0)` simultané (l'haptique et le rétrécissement — **c'est
lui qui te fait sentir que « ça répond »** alors que rien ne part) + la
pièce 3D avec son propre `onTapGesture` sans `allowsHitTesting(false)`
(`RewardCard.swift:1902-1971`, `MoonCoinLab.swift:150`) + la card entière
sous un drag d'ancêtre à 3 pt (`CarteGyro`). Un doigt qui dérive de 3 pt
annule le Button ; le TapGesture ne tolère qu'un tap immobile.

### Le correctif, à coder sur ton mot (rien côté serveur)
1. **Instrumenter d'abord** : `accessibilityIdentifier("bouton-claim")`,
   quatre points de trace `[claim]` (pose du doigt, tap reconnu, action,
   envoi) + compteur des refus de `fermer()`, et un XCUITest dans
   `tools/tapis/tests/MoletteIPhoneUITests.swift` (il existe et a tourné
   sur ton iPhone le 18-09).
2. Un tap pendant l'entrée **termine l'entrée et ferme** (ou le bouton ne
   prend pas le doigt tant qu'il n'est pas posé) — le défaut certain.
3. Un bouton à **l'école des galets** : `DragGesture(minimumDistance: 0)`,
   `onEnded` → action si le doigt a bougé de moins de 12 pt ; verre sans
   `.interactive()` ; `allowsHitTesting(false)` sur la pièce 3D. Barreaux
   `-sansVerreClaim`, `-sansGyroCard` pour accuser ou disculper chacun.
4. Un état **« en cours »** dès le tap (haptique une fois, bouton grisé,
   spinner) et la fermeture à la réponse ; à décider : reposer la dalle
   « +10 » locale au tap (l'état d'avant le 18-09, en évitant le doublon
   avec l'event serveur) ou un « encaissé » sur le bouton.

---

## 3. La troisième séance — « pas possible, attends demain »

### Ce qui existe déjà (commit `dd0c6052` de la session Route, 10:49)
La règle « deux séances par jour » est **posée au serveur et dans le
téléphone** : `reward_rules.chemin_seances_par_jour_max = 2`,
`seances_chemin_plafonnees()` (garde les deux premières séances avec
travail de chaque jour LOCAL), la clôture ne paie rien à la 3e
(`plafond_jour`), la lune du rang 3 est refusée ; `PlafondJour.swift` fait
le même calcul dans l'app ; la **pop-up native Apple** (`.alert` SwiftUI,
un bouton OK, FR/EN) existe à quatre portes : galet actif de la Route,
« tire pour commencer » de la Home (tap et tirage), racine
(`startWorkout`, `demarrerDepuisChemin`). Mesuré au simulateur seulement.

### Ce qui NE tient PAS encore
1. **La règle n'entre en vigueur que demain** (`chemin_plafond_depuis =
   2026-09-21`, choisi pour ne pas te retirer les 4 séances de ce matin).
   MESURÉ aujourd'hui sur compte jetable : une 3e séance est **payée**
   (20 pièces + sachet), **comptée** (rang 3) et **débloque le galet 3**
   (199 pièces). C'est pour ça que tu as vu ×4. → Ta décision (11:20) :
   **le plafond s'applique dès aujourd'hui**. La session Route n'est plus
   joignable (dit par la session Profil) : la migration d'une ligne
   (`chemin_plafond_depuis → 2026-09-20`) et `PlafondJour.depuis` sont
   préparées dans l'arbre par cette session, **à déployer sur ton mot**
   (« push »). Les deux comptes Apple ayant été remis à zéro à 11:53 sur ton
   ordre (session Compte, qa-24), il n'y a plus de galet à perdre : le
   nouveau compte vivra sous la règle dès sa première journée.
2. **Le build 81 ignore la règle** : dès qu'elle est active, la Route de
   Margaux comptera 3 galets là où le serveur en compte 2, la lune sera
   refusée sans explication et la 3e séance affichera « 0 pièce ». → Build
   82 à envoyer vite.
3. **Le serveur juge un RANG, pas ce qu'il a déjà payé** (mesuré en
   transaction annulée) : une séance plus ancienne qui arrive en retard
   (outbox, téléphone hors ligne) devient rang 2 et est payée en plus →
   **trois séances payées, trois sachets le même jour** pendant que la
   Route n'en compte que deux. Et une séance que le téléphone **date
   d'hier** est payée sans contrôle (seul « pas dans le futur » est
   vérifié). Correctif : avant de payer, compter les **reçus payés** du
   même jour local sous le verrou qui existe déjà ; poser
   `workouts.recue_at` (première synchro) pour ne pas croire l'horloge du
   téléphone. Contrairement au Welcome Back, ce plafond **n'a aucun index**
   qui le garde.
4. **La fiche exercice crée une séance à quatre endroits sans la garde**
   (`ExerciseDetailView.swift:2529, 2856, 3259, 3383`) : une 3e séance
   peut y naître sans pop-up ; le serveur ne la paie pas — mais **l'app
   ne décode pas `plafond_jour`** : la story dira « 0 pièce » au lieu de
   « journée pleine ».
5. Le refus sur un **tirage** de la card Home n'a jamais été joué : la card
   pourrait rester à la hauteur où le doigt l'a lâchée, derrière l'alerte
   (`HomeNuit.swift:4416`).
6. Le bouton OK est **violet** parce que toute l'app porte
   `.tint(.woopViolet)` — un `.tint(.white)` sur l'alerte seule est à
   mesurer. Les mots posés : « Deux séances aujourd'hui — C'est le maximum
   d'une journée pour la Route. Revenez demain ! » — à toi de dire si tu
   veux les tiens.
7. Toute utilisatrice peut **modifier ou effacer ses séances payées**
   (politique RLS `update/delete own` sur `workouts`, sans lien avec le
   carnet) : à restreindre aux séances ouvertes.

### « 24 heures » ou « jour calendaire »
Le déployé compte par **jour civil local du téléphone**, rattaché à la FIN
de la séance (mesuré : 23:30, 23:50 puis 00:10 = trois séances payées en
40 min ; une séance finie à 00:05 compte pour aujourd'hui, rang 1). Je
recommande de le garder : « revenez demain » est littéralement vrai.

⚠️ **Trois définitions du « jour » cohabitent** : Welcome Back = jour civil
de Paris ; plafond = jour local de la séance (fuseau envoyé par le
téléphone, Paris si le build ne l'envoie pas — le 81) ; le fait ×2 de la
story (`double_jour`) = jour de Paris sur le DÉBUT, séances vides comprises.
Une seule décision de ta part, appliquée aux quatre briques.

---

## 4. Le galet — la date, le sticker ×2

- **TODAY retiré** (ta décision : « c'est la date et basta ») : le galet
  actif porte la date du jour comme les galets faits ; le 2e galet du même
  jour porte le sticker ×2 ; la capsule « ×3 » est retirée (le plafond
  interdit un 3e galet). Fait dans l'arbre le 20-09, non commité.
- Le sticker ×2 **n'a jamais été vu sur ton téléphone** (absent du build
  81) : à juger sur le 82.
- **Question de lecture** : avec le plafond actif, le galet actif porte la
  date du jour mais son tap dit « revenez demain ». Tu liras « 20 » sur un
  galet réservé à demain. Date du jour, date de demain, ou rien sur
  l'actif quand la journée est pleine ?

---

## 5. Ce qui a été codé aujourd'hui sur ton ordre (arbre, non commité)

Voir `tools/production/testflight-fix-2026-09-20/README.md` (la table par
retour). En plus, cet après-midi :
- **la date sur le galet** (§ 4) : `GaletEtape.swift`, `DuolinguoPage.swift`
  (`Lecture.date`), `CardRoute.swift` (commentaires) ;
- **la cinématique du galet accompli** (ta demande : « une grosse
  animation cinématique sur le galet, avec des halos, et après il se
  dézoome pour montrer que la session a été faite, et après le reste de
  l'expérience ») : `DuolinguoPage.swift` — la colonne grossit 1,6× autour
  du galet (0,6 s), le sceau + premier halo d'or + haptique, l'onde, second
  halo, dézoom (0,7 s), écran suivant, puis les gains défilent sur la
  Route. Verre éteint pendant le zoom, autres galets à 0,45 ; une
  transformation animée, aucun redessin ; barreau `-sansCineGalet` ;
  coupée par « Réduire les animations » et un téléphone chaud (comme la
  fête d'avant). **Non mesurée sur ton iPhone.**

---

## 6. Pièges pour la suite

- **L'index git partagé porte 285 suppressions préparées** (`D `), dont
  `PlafondJour.swift`, quatre médias et trois migrations posées — les
  fichiers sont sur le disque et dans HEAD ; un `git commit` nu ou `-a`
  les retirerait de `main`. Cause : les commits par index temporaire depuis
  le 18-09 n'ont pas rafraîchi l'index partagé. Remède, sur ton mot :
  désindexer **uniquement** ces chemins
  (`git reset -q -- $(git diff --cached --name-only --diff-filter=D)`),
  jamais un reset global (il défait les hunks préparés des autres sessions).
- Le `.gitattributes` de la racine est un lien symbolique bouclé : un
  `grep -r` lancé sur `.` rend **0 résultat en silence**. Chercher dans
  `Nosfy`, `NosfyShared`, `NosfyWidgets`, `tools` nommément.
- Le « build 81 » n'est pas HEAD : la référence est
  `testflight-api-2026-09-19/sources.json` (l'arbre du 19-09 10:05).

---

## 7. L'ordre que je propose

0. Te dire (fait ici) : sans la date avancée, une 3e séance ce soir est
   payée et fait un galet.
1. Tes trois décisions : « demain à minuit » ou « 24 h pile » ; « Later »
   perd-il le +10 du jour ; la date sur l'actif quand la journée est pleine.
2. Le plafond dès aujourd'hui (session Route) + fermer le trou du rang
   (migration) + les quatre portes de la fiche exercice + décoder
   `plafond_jour`.
3. Le Claim : instrumenter, puis corriger le défaut certain (entrée 1,45 s),
   puis le geste tolérant ; mesurer au doigt sur ton iPhone.
4. Le Welcome Back : le marqueur du jour + une seule porte au lancement ;
   rejouer Later / voile / app tuée / Claim abouti.
5. Le site : b-wb-porte et b-rg-le-versement-lui-part-vraiment en 🔴,
   b-route-plafond-jour et la règle serveur avec leurs réserves (fait dans
   l'arbre le 20-09 avec ce document).
6. Build 82 sur TestFlight, et vous deux qui retestez : le seul verdict.
