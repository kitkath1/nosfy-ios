# LA SUITE DU TEST QA DU COMPTE — de la relance à la suppression (14-09, 13 h) — PLAN, rien codé

Son ordre : « après on poursuit ce test QA (de login à se déconnecter puis suppression du
compte) ; fais un plan, ne code pas ». Le premier passage (login → home) est joué et noté
dans l'onglet **Test QA** du site (étapes 1-7, verdicts posés). Ce plan dit ce qui doit
être VRAI avant de reprendre, l'ordre des étapes qui restent, ce que chacun lit, et ce qui
n'entre PAS dans ce test.

## 0. Ce que le premier passage a appris (mesuré, pas déduit)

| Fait | Preuve | Conséquence pour la suite |
|---|---|---|
| Le compte, Nosfy, la home vide dans sa langue, le prénom, l'objectif : **validés** par elle | son retour de 11 h 50 ; serveur : profils « Kiki Style » / fr / but force, user_prefs 7, visite_home_le 09:42 | les étapes 1-6 ne se rejouent pas — sauf si le compte est effacé (étape 11) et recréé |
| Une **séance a été finie** sur ce compte à 12:14 (50 s, 1 exercice) pendant qu'elle manipulait le téléphone | serveur : workouts = 1 ; la sonde l'a vue « EN SÉANCE » sur l'onglet exercices | `premiere_fois` est FAUX désormais ; `retour_disponible` est VRAI aujourd'hui → **le Welcome Back s'ouvre à la home, par la règle backend** (S4) — c'est ce qu'elle a vu à 12:50 : correct par la règle, KO par le design (§ 2) |
| **Le téléphone chauffe** : thermique 2 dès la 2e manche, iOS bride ; froid, la home fait 50 img/s à 30 % de processeur (manche 1) | `tools/perf/campagnes/2026-09-14-1206/1-A.jsonl` | la fluidité se mesure sur un téléphone FROID et débranché du câble (qui charge, donc chauffe) ; la campagne A/B reste à finir (§ 4) |
| **L'onglet Profil ne répond pas** quand le téléphone est chaud | son retour ; le chemin du tap est le même que les deux autres onglets (NavEncre → NavEtat → selection) | à rejouer téléphone froid : si la page arrive, c'est la chaleur ; sinon, la page profil elle-même |
| La card ROUTE vivante n'a jamais été mesurée sur son iPhone ; ses barreaux existent (`-sansVieRoute`, `-sansPlateau`) | 59a5c77 (session porte) | manches B et C du protocole, téléphone froid |

## 1. Ce qui doit être vrai AVANT de reprendre

1. **Un binaire à jour** posé sur l'iPhone, sans argument, construit depuis l'arbre partagé
   après : la pastille blanche + haptique du choix d'objectif (chambre), la pop-up de fin de
   Nosfy à la bonne taille (session porte, RewardCard), le composant « Chapitre » de la card
   ROUTE avec ses deux états (59a5c77). Rien d'autre ne change entre les deux passages.
2. **Le téléphone froid** (thermique 0 lu par la sonde à la première seconde) et **débranché**
   pendant qu'elle teste ; le câble ne sert qu'à poser le build et à lire le journal.
3. **Son compte tel qu'il est** (0fac947b, une séance finie) : on ne l'efface PAS avant —
   c'est l'étape 11 qui l'efface, depuis l'app, et c'est ça qu'on mesure.
4. **Le Welcome Back** : par la règle backend, il est DÛ aujourd'hui (une séance finie, le
   +10 du jour pas pris) — il s'ouvrira à la home. Deux choix, à trancher par elle AVANT :
   (a) on le laisse s'ouvrir et elle le juge (Claim ou Later) — sa robe de prod est celle
   « sans vidéo » (§ 2) ; (b) je prends le +10 du jour au serveur avant le test pour qu'il
   ne s'ouvre pas (`claim_retour_quotidien` avec sa session — non : sans sa session je ne
   peux pas ; donc (a), ou une ligne `coin_ledger` posée par l'admin, ce qui est un mensonge
   dans son livre de compte). **Je propose (a)**, et que « Later » soit un geste du test.

## 2. Le Welcome Back : la règle est bonne, la robe est morte — pourquoi

- La règle (S4, 20260913230000) : `retour_disponible` = une séance finie ET pas de
  `retour_quotidien` aujourd'hui. Elle a fini une séance à 12:14 → la card est due. C'est
  la règle qu'elle a validée le 14-09 (« seulement quand le compte est créé, avec notre
  règle backend »). **Rien à changer au serveur.**
- La robe : `WoopApp.swift` ouvre `RewardPopup(style: .welcome, robe: .video, …)` **sans
  `videoNom`** — depuis le J2 du coffre (beb7327, 30-08). Sans nom de vidéo, la robe
  `.video` n'a pas de vidéo : la card est nue (titre, sous-titre, étoiles, Claim). Les
  deux robes dessinées le 26-08 existent toujours : `.video` avec `"reward-welcome"` (la
  chauve-souris portrait en tête — `Woop/Media/reward-welcome.mp4` est là) et `.texte`
  (« YOU'RE / BACK » géant, le spotlight, la pastille-lune, la chauve-souris qui tient la
  card — 0e591f3). Le banc les rejoue : `-rewardLab -robe welcome|welcomeTexte`.
- **À trancher par elle** sur le catalogue (page Les annonces) : la robe de prod du Welcome
  Back = vidéo chauve-souris, ou texte géant, ou une troisième (« trois variants avec des
  vidéos de pièce et chauve-souris et screen » — son mot). Le code de prod change d'UNE
  ligne quand c'est tranché (`videoNom:` / `robe:`).

## 3. Les étapes qui restent, dans l'ordre — et ce que chacun lit

| # | Elle fait | Elle doit voir (front) | Je lis (back) | Piège connu |
|---|---|---|---|---|
| 7 | Onglet **Profil**, puis la roue | rond « KS », « Kiki Style », « @kikistyle », Level 1 ; Réglages : son prénom, « 0 pièces lune · Level 1 » (10 après un Claim), les trois lignes | rien au serveur (cache `woop.prenom`) | téléphone chaud = page qui n'arrive pas ; froid d'abord |
| 8 | **Tuer** l'app, la rouvrir | mini splash, puis la home DIRECT, pas de porte, pas de pop-up de première fois ; le Welcome Back s'il est dû (§ 1.4) | journal : `[home-serveur] home()` sans `[PORTE]` ; `[welcome-back] ouverte` (dû) ou `retenue` ; auth.sessions = 1 | le splash ne joue qu'en DEBUG à chaque lancement (`porteDejaVue`) — c'est le « mini splash » qu'elle a nommé |
| 9 | Réglages → **Se déconnecter** | « Déconnexion… » puis la porte (carrousel, sans le film) | `[session] logout → révoqué` ; `[compte] effacé : 14 clés…` ; `[compte] la porte est rendue (deconnexion)` ; auth.sessions = 0 ; sa séance de 12:14 reste au serveur (poussée) | hors ligne avec une séance non poussée → REFUS lisible sous les lignes (voulu, § 4 (a) du plan compte) |
| 10 | **Se connecter avec Apple** à nouveau | la feuille, la cérémonie (braises), la home DIRECT sans Nosfy ; sa phrase avec son prénom ; **pas** de pop-up de première fois (visite faite au serveur) ; les widgets montrent sa séance de 12:14 (le pull la ramène) | `[PORTE] verdict = CONNUE → app` ; `[pull] seances_depuis(tout) → total 1, insérées 1` ; `[compte] apple-jeton → 503 cle_absente` ; auth.sessions = 1 | si `[PORTE] profil() en panne → on joue le film` : c'est le réseau, pas l'aiguillage |
| 11 | Réglages → **Supprimer mon compte** → « Supprimer » | « Suppression… » puis la porte ; rouvrir : la porte encore | `[compte] supprimer-compte → ok · révocation Apple : aucun_jeton` ; auth.users sans 0fac947b, profils/workouts/user_prefs emportés ; `[compte] la porte est rendue (suppression)` | la révocation Apple attend sa clé .p8 (`aucun_jeton`) — App Store, pas ce test |
| 12 | (bonus) Apple → **recréer** le compte | Nosfy à nouveau (nouvelle), home vide, pop-up de première fois et visite REJOUENT (compte neuf : `visite_home` faux) | un nouvel id dans auth.users ; profils neuf | même Apple ID, nouvel uuid — attendu |

Chaque verdict se pose dans `docs/site/content/qa.ts` (front : son mot ; back : ma lecture),
puis `npm run artefact && npm run verif`, republier au même lien.

## 4. Ce qui n'entre PAS dans ce test (et vit ailleurs)

- **La fluidité et la chauffe** : la campagne A/B (`tools/perf/campagne-home.sh`, manches B
  et C à jouer téléphone froid, puis le profileur `xctrace` Time Profiler / SwiftUI si le
  téléphone accepte) — c'est le skill `woop-performance`, et un chantier à part. Ce qu'on
  sait déjà : froid, 50 img/s / 30 % (la norme mesurée de la maison : 27-39 %) ; chaud,
  bridé. Le verdict « ça doit être fluide » se joue sur ce chantier, pas dans le test QA.
- **Le design du Welcome Back** (§ 2) : une décision sur le catalogue, puis une ligne.
- **La première séance finie d'un compte neuf** (le Welcome Back du lendemain, la flamme,
  les widgets qui se remplissent) : une étape à ajouter au Test QA quand 7-11 sont verts.
- **La clé .p8** : la révocation Apple à la suppression, exigée à la revue App Store.

## 5. Le déroulé proposé, en une séance de 20 minutes

1. Elle pose le téléphone 10 minutes, écran éteint, débranché : il refroidit.
2. Câble : je pose le build à jour (désinstallation NON nécessaire : son compte et sa
   session restent), je lance sans argument, je lis 30 s de journal, je débranche.
3. Elle joue 7 → 11 dans l'ordre, un message par étape (« ok » ou ce qui cloche).
4. Je lis le serveur à chaque étape (le moniteur toutes les 20 s), je pose les verdicts,
   je republie l'onglet Test QA.
5. Si 7 échoue encore téléphone froid : on s'arrête là, et la page profil devient le sujet
   (journal par le câble, `xctrace` sur la page).
