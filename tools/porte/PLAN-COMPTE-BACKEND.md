# LE COMPTE — le plan du back-end de la porte

*13-09-2026, soir. Écrit AVANT tout chantier, sur ta consigne (« refais un plan avant de
faire les chantiers backend »). Le site (page Compte) dit ce qui EST ; ce fichier dit ce
qu'on veut faire, et dans quel ordre.*

> **État au 13-09, 22:10 — après ton « go » (les défauts du § 4 pris tels quels).**
> **Fait et mesuré, côté serveur** : C1 (anonymes coupés → 422, les 7 fantômes effacés, il
> reste les 2 comptes de test) · § 6 S1–S4 (`20260913230000_premiere_arrivee`, mesuré sur un
> compte jetable : `premiere_fois` vrai après l'onboarding, visite posée une seule fois,
> `retour_disponible` faux et claim refusé sans séance) · C3 serveur (`20260913231000_apple_jetons`,
> edge functions `apple-jeton` et `supprimer-compte` déployées ; le compte jetable a été
> supprimé par la fonction : auth.users, profils, user_prefs, sessions à 0).
> **Attend toi** : la clé `.p8` Sign in with Apple (Key ID + Team ID) — sans elle
> `apple-jeton` répond `cle_absente` et la suppression efface sans révoquer.
> **Attend la session porte** (contrats envoyés) : C0, C2, C3 côté app, C4, et la première
> arrivée côté app.

---

## 0. Tes verdicts, et ce qu'ils tuent

Tes mots (21:10), un par ligne, avec la conséquence :

| Tu as dit | Conséquence |
|---|---|
| « pour accéder à l'app on doit créer un compte Apple » | **Pas de mode invité.** On n'est jamais dans l'app sans compte. La décision ① du site (« l'app doit-elle dire qu'elle n'est pas connectée ? ») **meurt** : il n'y a plus de « pas connectée » possible. |
| « si on a un compte créé, on arrive dans l'app, pas plus simple que ça » | **La porte ne se montre que sans session.** Avec une session gardée, la home direct. ⚠️ Aujourd'hui la porte s'affiche **à chaque lancement** (`WoopApp.swift:332-335`, `showAuth` vaut vrai sauf `-skipAuth`) — c'est le chantier C0. |
| « se déconnecter remet à l'écran de login » | **Décision ② tranchée** : le bouton reste, et il ramène la porte. Aujourd'hui il n'efface que `woop.phone` — avec une session Apple il ne déconnecte **rien** (chantier C2). |
| « on crée que par Apple, pas d'OTP ou lien magique, basta » | La brique « signup, OTP ou magic link » est **retitrée** : par Apple et rien d'autre. Chez Supabase, les autres portes se ferment (C1) — surtout les **comptes anonymes**, encore ouverts. |
| « migrer la maquette locale, c'est quoi ? » | C'était : garder les pièces et sachets gagnés **sans compte**, et les rattacher au compte à la première connexion. Sans mode invité, **il n'y a plus rien à migrer** : la brique est retirée du site. |
| « la suppression, tu peux check ensuite » | Vérifié (§ 1) : « Supprimer mon compte » ouvre la confirmation et **ne supprime rien**. C'est le chantier C3, le plus cher, parce qu'Apple l'exige (§ C3). |

---

## 1. L'état mesuré ce soir (21:20, Paris)

**Chez Supabase (lu par l'API de gestion, rien de deviné)**

| Réglage | Valeur | Verdict |
|---|---|---|
| Provider **Apple** | activé, client id posé | ✔ la porte Apple passe (mesuré au banc `-sessionAdoptee` cet après-midi) |
| Provider **e-mail / mot de passe** | activé, **confirmation d'e-mail exigée** (autoconfirm off) | le compte de test du banc en dépend (`kat44426+woop-forge-test`) — à trancher, § 4 (c) |
| **Comptes anonymes** | **activés** | ✗ à couper (C1) — 5 comptes anonymes du 29-07 existent, 0 séance |
| Inscription | ouverte | nécessaire : `disable_signup` bloquerait AUSSI la première entrée Apple |
| Téléphone / SMS | coupé | ✔ |
| Captcha | coupé | ✔ (inutile avec Apple seul) |
| Durée de session | jeton 1 h, refresh tournant | ✔ |

**Les comptes qui existent** : 9 — **5 anonymes** (29-07, jamais revus), **3 e-mail**
(deux du 29-07 jamais connectés, plus le compte de test du banc, 23 séances de démo),
**1 Apple** (créé le 13-09 à 09:22, 69 séances : le compte de test officiel par Apple).

**Ce qu'une suppression doit effacer** : les 12 tables publiques qui portent `user_id`
(`workouts`, `logged_exercises`, `strength_sets`, `cardio_phases`, `workout_facts`,
`coin_ledger`, `user_cards`, `user_boosters`, `booster_progress`, `user_prefs`, `profils`,
`exercices_choisis`) sont **toutes** en clé étrangère `on delete cascade` vers
`auth.users` — mesuré. Effacer la ligne `auth.users`, c'est effacer tout.

**Dans l'app (lu dans le code)**

| Quoi | Où | État |
|---|---|---|
| L'entrée Apple → session → `profil()` → connue / nouvelle | `AppleAuth.entrer`, `PorteEntree`, `WoopApp` (session porte, commit 996b9d3) | branché ; **non mesuré sur le vrai chemin Apple** (son téléphone est en maquette) |
| La fin de Nosfy → `definir_profil` | `WoopApp.ecrireProfil` | branché et mesuré (existe, onboarding_termine, prénom, objectif) |
| La porte à chaque lancement | `WoopApp.swift:332-335` | ✗ contraire au verdict 2 |
| « Se déconnecter » | `ProfilLune.swift:1837-1845` | ✗ n'efface que `woop.phone` ; la session Apple (jeton, refresh, `woop.apple.userID`) reste, la porte ne revient pas |
| « Supprimer mon compte » | `ProfilLune.swift:1853-1862`, alerte 1912 | ✗ confirmation puis une note « sera activée avec la connexion Apple » |
| Le jeton | `SupabaseSession` en `UserDefaults` | ✗ part dans les sauvegardes (brique Keychain, déjà 🔴) |
| Les caches locaux d'une personne | `woop.prenom`, `objectifHebdo`, `woop.onboarding.du`, `ChambreEtat.serveur`, les séances SwiftData | à effacer à la déconnexion, sinon la personne suivante hérite « Hello Kat, » |

---

## 2. Le parcours cible, en six lignes

1. **Lancement, session gardée** → la home direct ; le jeton se rafraîchit en silence.
   Si le refresh est refusé (jeton révoqué, compte supprimé ailleurs) → la porte.
2. **Lancement, sans session** → la porte, le bouton Apple, la feuille native.
3. **Apple répond** → `grant_type=id_token` → session → `profil()` :
   `onboarding_termine` → **la home** ; sinon → **le film de Nosfy** → `definir_profil` → la home.
4. **Se déconnecter** → on pousse ce qui reste à pousser, on oublie tout ce qui est à elle
   sur le téléphone, on révoque le refresh au serveur → **la porte**.
5. **Supprimer mon compte** → confirmation → le serveur révoque le jeton Apple, efface
   `auth.users` (et donc tout) → l'app oublie tout → **la porte**.
6. **Une seule identité** : Apple. E-mail / mot de passe ne sert qu'au banc (§ 4 (c)).

---

## 3. Les chantiers, dans l'ordre

Chaque chantier dit : ce qu'on écrit au serveur, ce qu'on écrit dans l'app, **la mesure**
qui a le droit de faire bouger une pastille du site, et le coût.

### C0 — La porte seulement sans session *(app · session porte · ½ j)*

- **App** : à la racine, `showAuth` vaut vrai **seulement** si `SupabaseSession` n'a ni
  `woop.apple.userID` ni refresh. Avec une session : la home, et `token()` rafraîchit
  en tâche de fond ; un refresh refusé (400 `invalid_grant`) → `oublier()` → la porte.
  Le raccourci `-skipAuth` reste pour les captures.
- **Serveur** : rien.
- **Mesure** : se connecter, tuer l'app, relancer → la home sans porte ; révoquer la
  session côté serveur (`auth.sessions` effacée), relancer → la porte.
- **Site** : nouvelle brique « la porte à chaque lancement » 🔴 → 🟢.

### C1 — Fermer les autres portes chez Supabase *(serveur · moi · 1 h)*

- **Serveur** : `external_anonymous_users_enabled = false` (API de gestion, pas une
  migration) ; effacer les **5 comptes anonymes** et les **2 comptes e-mail jamais
  connectés** du 29-07 (0 séance chacun, mesuré) ; garder le compte de test du banc et
  le compte Apple de test. Le provider e-mail : § 4 (c).
- **App** : rien.
- **Mesure** : `POST /auth/v1/signup` anonyme → refusé ; `select count(*) from auth.users` → 2.
- **Site** : brique « portes fermées » 🔵 → 🟢, carte du serveur (compte).

### C2 — La déconnexion vraie *(app + serveur · ½ j)*

- **Serveur** : rien de nouveau — `POST /auth/v1/logout` existe (il révoque le refresh).
- **App (session porte, sur ce contrat)** : `SupabaseSession.oublier()` :
  1. pousser ce qui attend (`push()`), avec la règle du § 4 (a) hors ligne ;
  2. `POST /auth/v1/logout` avec le jeton courant (une panne réseau n'empêche pas d'oublier) ;
  3. effacer `woop.phone`, `woop.apple.userID`, le jeton, le refresh, `woop.prenom`,
     `objectifHebdo`, `woop.onboarding.du`, `ChambreEtat.shared.serveur`, et les séances
     SwiftData (§ 4 (a)) — **tout ce qui est à elle**, rien de l'app (la porte vue,
     le tuto vu restent) ;
  4. `showAuth = true` : la porte revient, sans le film d'entrée.
- **Au passage** : le jeton et le refresh descendent au **Keychain** (brique 🔴
  « il part dans les sauvegardes ») — même chantier, même fichier.
- **Mesure** : au banc `-sessionBanc`, se déconnecter → `auth.sessions` du compte vide,
  les 8 clés absentes, la porte à l'écran, et « Hello there, » à la prochaine entrée.
- **Site** : b-po-deconnecter 🔴 → 🟢, b-po-keychain 🔴 → 🟢.

### C3 — La suppression vraie *(serveur + app · 1 j, + une clé Apple à créer par toi)*

**Pourquoi c'est cher.** L'App Store (règle 5.1.1 (v)) exige que la suppression soit
possible **dans l'app**, et, pour une app qui entre par Apple, que l'app **révoque les
jetons Sign in with Apple** au moment de supprimer. Révoquer demande un secret que seul
un serveur peut tenir. Donc une **edge function**, comme `forge-card` (la seule déployée
aujourd'hui).

- **Ce qu'il te faut faire, une fois** : dans le portail développeur Apple, *Keys → +*,
  cocher *Sign in with Apple*, télécharger la clé `.p8` (une seule fois possible), me
  donner le **Key ID** et le **Team ID**. La clé va dans les secrets de Supabase
  (`supabase secrets set`), **jamais** dans le dépôt.
- **Serveur, en deux fonctions** :
  1. `apple-jeton` : appelée par l'app **juste après l'entrée Apple**, avec le
     `authorizationCode` qu'Apple rend (valable 5 minutes, à usage unique — celui que
     Supabase n'utilise pas dans le flux `id_token`). Elle l'échange chez Apple
     (`POST appleid.apple.com/auth/token`, secret signé ES256 avec la `.p8`) contre un
     **refresh token Apple**, et le range dans une table `apple_jetons (user_id, refresh,
     créé le)` — lisible par personne (pas de RLS ouverte : service role seul).
  2. `supprimer-compte` : vérifie le jeton de la personne, lit son refresh Apple, le
     **révoque** chez Apple (`POST /auth/revoke`), puis efface `auth.users` (service role,
     `auth.admin.deleteUser`) — la cascade fait le reste (mesuré, § 1). Une révocation
     en panne s'imprime et **n'empêche pas** l'effacement (on ne laisse pas une personne
     coincée avec un compte qu'elle veut détruire) ; elle est rejouée par un cron tant
     que la table garde une ligne orpheline.
- **App (session porte, sur ce contrat)** : après l'entrée Apple, envoyer le
  `authorizationCode` à `apple-jeton` (une panne n'empêche pas d'entrer) ; l'alerte
  « Supprimer ton compte ? » appelle `supprimer-compte`, puis `oublier()` (C2) → la porte.
- **Mesure** : un compte **jetable** créé par l'admin (pas le compte de test du banc),
  quelques lignes posées dans 4 tables, suppression depuis l'app au banc → `auth.users`
  et les 12 tables à 0 pour cet id ; la révocation Apple, elle, ne se mesure qu'avec un
  vrai compte Apple : **une fois, sur ton téléphone**, avec un Apple ID que tu acceptes
  de « cesser d'utiliser » pour Woop (Réglages → Apple ID → Connexion avec Apple).
- **Site** : b-po-supprimer 🔴 → 🟢 ; carte du serveur : `apple_jetons`, `apple-jeton`,
  `supprimer-compte`.

### C4 — Ce que ça ferme au passage *(app · session porte · 1 h)*

- Les **deux numéros en dur** et le mot de passe dérivé (`WoopConfig.credentials`,
  `Supabase.swift:27-35`) : le chemin `grant_type=password` ne survit que sous `#if DEBUG`
  pour le banc `-sessionBanc` ; en release, Apple seul. → b-po-identifiants 🔴 → 🟢,
  b-po-porte 🔴 → 🟢 (la clé `woop.phone` meurt).
- « Kathryn » en dur ×3 dans `ProfilLune` → le prénom du profil (la clé `woop.prenom`,
  déjà lue par la home). → b-po-profil 🔵 → 🟢.

---

## 4. Ce qui reste à trancher — avec le défaut que je prends si tu ne dis rien

**(a) Les séances du téléphone à la déconnexion.** Une autre personne peut se connecter
sur le même téléphone ; ses séances ne doivent pas se mélanger aux tiennes. Défaut :
**on pousse, puis on efface le téléphone**. Hors ligne avec des séances non poussées :
**on refuse de se déconnecter** (« Connecte-toi au réseau d'abord ») plutôt que de
perdre une séance. L'autre choix : effacer sans pousser, jamais.

**(b) La suppression : immédiate ou 30 jours de grâce ?** Défaut : **immédiate et
définitive** — Apple accepte les deux, l'immédiat n'a pas de file d'attente à tenir ni
d'écran « ton compte sera supprimé le… ». La grâce coûte une table, un cron, un écran.

**(c) La porte e-mail de Supabase.** Le banc (`-sessionBanc`, toutes les mesures du site)
entre par e-mail / mot de passe avec le compte de test. Défaut : **on la garde**, avec la
confirmation d'e-mail exigée (déjà le cas) — un inconnu qui s'inscrirait par e-mail
n'obtient rien tant qu'il ne confirme pas, et l'app n'a de toute façon aucun écran
e-mail. L'autre choix : la fermer, et faire entrer le banc par une session posée
(`-sessionAdoptee` avec un refresh gardé dans `.secrets/`) — plus propre, plus fragile.

**(d) Les 7 comptes fantômes du 29-07** (5 anonymes, 2 e-mail jamais connectés, 0 séance).
Défaut : **on les efface** dans C1.

**(e) Un compte Apple sans e-mail.** On ne demande rien à Apple (`requestedScopes` vide,
c'est voulu) : `auth.users.email` est vide pour un compte Apple. Défaut : **on s'en
passe** — rien dans l'app n'écrit à la personne. Si un jour une notification par e-mail
existe, on demandera l'e-mail à Apple à ce moment-là (et il ne sera rendu qu'à la
première autorisation : à ranger tout de suite).

---

## 5. L'ordre, et ce qui bouge sur le site

| Ordre | Chantier | Qui | Coût | Pastilles |
|---|---|---|---|---|
| 1 | C1 fermer les portes | moi (serveur) | 1 h | + « portes fermées » 🟢 |
| 2 | C0 la porte seulement sans session | session porte | ½ j | + « porte à chaque lancement » 🔴 → 🟢 |
| 3 | C2 déconnexion vraie + Keychain | session porte, contrat ici | ½ j | b-po-deconnecter, b-po-keychain 🔴 → 🟢 |
| 4 | C3 suppression vraie | moi (serveur) + session porte (app) + **toi (la clé .p8)** | 1 j | b-po-supprimer 🔴 → 🟢, + 3 lignes serveur |
| 5 | C4 les numéros en dur, « Kathryn » ×3 | session porte | 1 h | b-po-identifiants, b-po-porte, b-po-profil |

Aucune pastille ne bouge avant sa mesure. Chaque chantier serveur arrive avec sa
migration, sa mesure lue, et le site dans le même commit.

**Ce que ce plan ne fait pas** : la lecture des séances depuis le serveur (le `pull`
qui manque — brique b-sy-jamais-ecrit, page Serveur). C'est elle qui fera qu'un
téléphone neuf retrouve ses séances après C0. Chantier à part, plus gros, à planifier
après celui-ci.

---

## 6. La première arrivée sur la home — ce que le serveur doit savoir (analyse du 13-09, 22:00, rien codé)

Son plan : `tools/porte/PLAN-PREMIERE-ARRIVEE.md` (session porte, elle fait le design). Lu en
entier, avec le code du Welcome Back (`etat_coffre`, `claim_retour_quotidien`) et `profil()`.
**Ce qui n'a PAS besoin du serveur** : la langue (déjà dans `profils.langue`, rendue par
`profil()` — c'est l'app qui ne la lit pas), la phrase de première fois (l'app la choisit
sur `seances = 0`, déjà rendu), la pop-up Welcome « première fois » (sa porte est un tap,
local), la visite elle-même, le chapitre 1 vierge (chantier du chemin, dans le téléphone).

**Ce qu'il faut, en UNE migration, au même « go »** (coût : 1 h, mesuré comme le reste) :

| # | Quoi | Pourquoi |
|---|---|---|
| S1 | `profils.visite_home_le` (timestamptz, null) | la mémoire de la visite guidée : une réinstallation ne la rejoue pas, et c'est une donnée (qui a vu la visite, quand) |
| S2 | `marquer_visite_home()` — pose la date **une fois** (jamais réécrite ; la ligne `profils` est créée si elle manque), rend `profil()` | appelée par l'app au dernier tap de la visite |
| S3 | `profil()` rend `visite_home` (vrai/faux) ; `home()` rend `visite_home` et `premiere_fois` (onboarding terminé ET aucune séance finie) | la porte lit `profil()`, la home lit `home()` : chacune sait sans calculer |
| S4 | `etat_coffre.retour_disponible` **faux tant qu'aucune séance n'est finie** ; `claim_retour_quotidien` refuse de même (`credite false, raison premiere_seance_requise`) | le Welcome Back n'a rien à fêter le soir de la première arrivée ; une règle au serveur vaut mieux qu'une exception dans l'app, et le refus côté claim empêche d'encaisser le +10 en contournant l'écran |

⚠️ **Ce que S4 change** : le +10 du premier jour ne se prend qu'après la première séance
finie. C'est le défaut que je propose ; si tu veux que le +10 du premier jour reste, dis-le
et S4 ne touche que le jour de la première arrivée (plus fragile : il faut une date de
plus).

Sur le site : `marquer_visite_home` est posée ⚪ sur la carte du serveur (page Compte), et
les notes de `profils`, `profil()`, `home()`, `etat_coffre` disent ce qui vient.
