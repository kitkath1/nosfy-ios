# LA FORGE ET LE COMPTE POUR DE VRAIS COMPTES — audit du 17-09 et plan (rien codé)

Son ordre : « check le backend de la forge pour qu'on termine cette partie ; le compte : il
manque quoi pour jouer des vrais comptes, et tout est bien connecté d'un nouveau user à un
user existant ? » Puis : « ne code pas, lance un audit et plan ». Tout ce qui suit est LU
(fichier:ligne) ou MESURÉ (appel fait, réponse lue) le 17-09 entre 10:15 et 11:10, Paris.
Deux correctifs ont été écrits puis RETIRÉS de l'arbre sur son ordre ; ils sont ici, en
proposition (§ 4).

## 0. Le verdict en quatre lignes

- **Le serveur est prêt** pour de vrais comptes (48 migrations posées = 48 fichiers, les portes
  fermées — 34 preuves vertes de `verif_portes.py` ce matin). Une seule pièce manque, et elle
  n'empêche pas de jouer : **la clé Sign in with Apple (.p8)**, à créer par toi.
- **La chaîne nouveau user → user existant est cohérente dans le code** : Apple → session →
  `profil()` → Nosfy ou la home ; relance → session gardée au Keychain → la home ; déconnexion,
  suppression → la porte. Elle a été mesurée au simulateur (14-09) et, sur ton téléphone,
  seulement jusqu'à l'étape 7 du Test QA : **les étapes 8-11 (relance, déconnexion,
  reconnexion, suppression) n'ont jamais été validées sur ton iPhone.**
- **Deux défauts trouvés en relisant la chaîne d'un vrai compte** (§ 2) : la forge sert
  ~10 % de légendaires au lieu de 3 % sur son chemin « neuve » ; et l'app ne sait pas que
  son jeton meurt au bout d'une heure (401 partout après une heure d'app vivante).
- **Le travail du compte du 14-09 n'est pas commité** (`Compte.swift` non suivi, 4 migrations
  non suivies, les diffs d'AppleAuth / Supabase / SupabaseSync / ForgeServeur) — voir § 3.

## 1. Ce qui est mesuré, tel quel

| Quoi | Mesure du 17-09 | Preuve |
|---|---|---|
| Migrations | 48 fichiers = 48 posées, rien en attente, rien d'orphelin ; dernière `20260916064928` | `verif_portes.py` [5] |
| L'argent est fermé au client | insert coin_ledger / user_boosters / user_cards / workout_facts / reward_rules → 403 ; PATCH / DELETE → 0 ligne ; solde_or 26 → 26 | `verif_portes.py` [1] |
| Comptes au serveur | **2** : `be69f505` (e-mail, le compte de test = `FORGE_DEV_USER`, 23 séances, 28 cartes, 31 sachets fermés, **142 sessions** accumulées) et `e3920e3a` (TON compte Apple du 14-09 : prénom Kathryn, en, onboarding terminé, visite faite, **32 séances finies de 4 à 55 s à 0 série** — les tests de perf —, 1 cardio_seance +48, 1 serie_faite +20, 3 retour_quotidien, **0 carte, 2 sachets fermés jamais ouverts**) | SQL par l'API de gestion |
| Le pool de cartes | 6 common · 2 rare · **0 epic** · 1 legendary | `select count(*) from cards group by rarete` |
| Secrets des edge functions | `OPENAI_API_KEY`, `FORGE_DEV_USER`, `SUPABASE_*` — **aucun `APPLE_KEY_ID` / `APPLE_TEAM_ID` / `APPLE_PRIVATE_KEY`** | `GET /v1/projects/…/secrets` |
| Auth | `jwt_exp` 3600 · rotation du refresh ON · Apple ON (`fr.kathryn.woop`) · anonymes OFF · signup ON (nécessaire à la 1re entrée Apple) · e-mail ON (le banc) | `GET /v1/projects/…/config/auth` |
| `apple_jetons` / `apple_revocations` | 0 / 0 | SQL |
| `forge-card` déployée | v5 du 15-09 05:59 UTC ; le corps téléchargé = le dépôt (serrure présente, 4 × `FAMILLES[Math.floor(Math.random() * FAMILLES.length)]`) | `GET /v1/projects/…/functions/forge-card/body` |
| Un jeton frais du compte de test | `iat → exp` = 3600 s | `POST /auth/v1/token?grant_type=password` |

## 2. Les deux défauts (🔴 sur le site : `b-fo-poids-60-27-10-3`, `b-po-jeton-une-heure`)

### 2.1 La forge : la rareté du chemin « neuve » ne suit pas les poids

`forge-card/index.ts` : le pool (65 % des tirages, `Math.random() >= PART_NEUF`, :230) tire
la rareté aux poids 60 / 27 / 10 / 3 (`tireRarete`, :83-88) puis une carte de cette rareté.
Le chemin « neuve » (35 %, **et tout tirage dont le pool est vide pour la rareté** — aujourd'hui
toute épique) n'a pas de famille et prend `FAMILLES[random]` dans les 25 (:257) : 4 communes,
11 rares, 4 épiques, **6 légendaires**. Pour un vrai compte :

| rareté | annoncé | servi (0,65 × poids + 0,35 × part des familles) |
|---|---|---|
| common | 60 % | ≈ 45 % |
| rare | 27 % | ≈ 33 % |
| epic | 10 % | ≈ 12 % |
| legendary | 3 % | **≈ 10 %** |

Ça vide la valeur de la garantie légendaire du sachet noir (une sur dix « gratuite »). Le
sachet noir lui-même est juste (:245-248 impose une famille légendaire). Personne ne l'a vu
parce que le compte de test forge avec ses manettes (`famille`, `force_new`) et que ton compte
Apple n'a **jamais forgé** (0 carte).

Conséquence collatérale à connaître : **toute épique et 35 % du reste passent par OpenAI**
(gpt-5 + gpt-image-1, 60-90 s, un coût par carte) — c'est le design « deux vitesses », pas un
défaut, mais avec 0 épique au pool c'est 10 % des tirages qui attendent 60-90 s à coup sûr.

### 2.2 Le compte : le jeton vit une heure, l'app ne le sait pas

`Supabase.swift:144` — `if let accessToken { return accessToken }` : une fois obtenu, le jeton
d'accès est rendu tel quel jusqu'à la mort du process. Le projet signe des jetons d'**une
heure** (`jwt_exp` 3600, mesuré). iOS garde le process des heures en arrière-plan. Au-delà
d'une heure d'app vivante : `home()`, `etat_coffre`, `widget_*`, `ma_collection`, la clôture de
séance par l'outbox → **401**. L'outbox range le 401 « à rejouer » (`OutboxGains.swift:232`)
et rejoue… avec le même jeton mort. Seule une poussée de séances en panne remet le compteur
à zéro (`SupabaseSync.push` → `invalidate()`, :95) — par accident, pas par dessein. Le refresh
au Keychain, lui, marche (C0, mesuré le 14-09) : il n'est juste jamais rappelé à temps.

Ce que ça donne pour une vraie personne : une séance longue (ou l'app laissée ouverte le
matin, reprise le soir) → la story de fin se joue, mais les gains partent en file et n'arrivent
qu'au prochain lancement froid ; la home et le coffre montrent le cache ou rien.

## 3. Ce qui manque pour jouer avec de vrais comptes — dans l'ordre où ça bloque

| # | Manque | Qui | Coût | Bloque quoi |
|---|---|---|---|---|
| 1 | **Commiter le compte du 14-09** : `Woop/Services/Compte.swift` (non suivi !), les 4 migrations `20260914010000/011000/020000/021000` (non suivies, mais POSÉES au serveur), et les diffs `AppleAuth.swift`, `Supabase.swift`, `SupabaseSync.swift`, `ForgeServeur.swift` — sans eux, `main` ne compile pas seul et la déconnexion / suppression n'existent pas dans l'historique | toi (l'ordre), moi (les chemins) | 1 h | tout binaire construit depuis un clone propre |
| 2 | **Le jeton d'une heure** (§ 2.2) | app | 1 h | toute session > 1 h, l'app laissée ouverte |
| 3 | **La rareté du chemin neuve** (§ 2.1) | edge function + déploiement | 1 h | l'économie des cartes, la valeur du noir |
| 4 | **Le Test QA 8-11 sur ton iPhone** : relance → home direct ; Se déconnecter → la porte ; Apple à nouveau → CONNUE, pas de Nosfy ; Supprimer → la porte, `auth.users` sans la ligne | toi + moi | 20 min | la certitude « nouveau → existant » sur le vrai chemin Apple |
| 5 | **Ta première forge sur ton vrai compte** (2 sachets fermés t'attendent) : un sachet → `ouvrir_booster` → `forge-card` → la carte au mur du profil | toi | 5 min | la forge n'a jamais été jouée hors du compte d'atelier |
| 6 | **La clé .p8** (`tools/porte/poser-cle-apple.sh <p8> <KEY_ID> <TEAM_ID>`) | toi | 15 min | la révocation Apple à la suppression — App Store 5.1.1 (v), pas le jeu |
| 7 | Hygiène : `be69f505` traîne 142 sessions (`grant_type=password` à chaque banc, jamais de logout) ; `m-retirer-le-repli-jwtbanc` (le repli `jwtBanc()` du manège est déjà inerte en release : `sessionBanc` jette hors DEBUG, `ForgeServeur.swift:136-138`) | serveur | 1 h | rien — à ranger |

Ce qui est **déjà juste** et qu'on ne retouche pas : la serrure (pas de sachet, pas de carte —
16 preuves du 15-09), le scellement idempotent (`is('card_id', null)`), `ma_collection()` et le
mur du profil (28 cartes retrouvées après désinstallation), la session au Keychain, la porte
seulement sans session, la loi du vide, `definir_profil` avec prénom obligatoire, le Welcome
Back jamais avant la première séance, les portes anonyme / SMS / captcha fermées.

## 4. Le plan — quatre chantiers, chacun avec sa mesure

### C1 — Le jeton qui se renouvelle avant de mourir *(app, `Supabase.swift`, 1 h)*

Le correctif écrit puis retiré (il compilait, `BUILD SUCCEEDED` au simulateur ; les helpers
ont été compilés à part avec `swiftc` et lancés sur un vrai jeton : sub lu, `exp` dans 3578 s,
valide à 60 s de marge, invalide à 3700 s, invalide sur un jeton illisible) :

```swift
// token() — à la place de `if let accessToken { return accessToken }` (les deux sites : banc et réel)
if let accessToken, Self.encoreValide(accessToken) { return accessToken }

/// Le jeton vit encore au moins `marge` secondes (son `exp`). Illisible = mort.
static func encoreValide(_ jwt: String, marge: TimeInterval = 60) -> Bool {
    guard let exp = charge(du: jwt)?["exp"] as? Double else { return false }
    return Date(timeIntervalSince1970: exp).timeIntervalSinceNow > marge
}
/// La charge utile du JWT (base64url), sans vérifier la signature — `sujet(du:)` la réutilise.
static func charge(du jwt: String) -> [String: Any]? { … le corps actuel de sujet(du:), rendant json … }
```

Optionnel, même chantier : `OutboxGains` appelle `SupabaseSession.shared.invalidate()` sur un
401 avant de rendre `.aRejouer` — ceinture et bretelles.

**Mesure** : au simulateur, `-sessionBanc`, forcer `marge: 3700` le temps d'un lancement →
chaque `token()` repasse par le refresh (journal), la home répond ; puis sur ton téléphone,
l'app ouverte à 9 h, une séance finie à 10 h 15 → les gains au journal AVANT la relance.

### C2 — La rareté du chemin neuve *(edge function, 1 h + déploiement sur ton ordre)*

Le diff exact est gardé (`patch-forge-card-rarete.diff`, 70 lignes) ; l'idée :

```ts
// la rareté se tire UNE fois, avant pool-ou-neuf — les deux chemins la partagent
const rarete = rareteImposee ?? tireRarete();
if (!forceNeuf && Math.random() >= PART_NEUF) { …pool de cette rareté… }
if (!carte) {
  const famille = (voulu ? FAMILLES.find(…) : null) ?? familleTiree(rarete);   // une famille DE cette rareté
```

`familleTiree(r)` = une famille au hasard **parmi celles de la rareté r**. Les manettes
d'atelier gardent leur `famille` voulue. Syntaxe vérifiée (esbuild — pas de deno sur ce Mac).

**Mesure** : `supabase functions deploy forge-card`, puis `tools/serveur/verif_forge.py`
(la serrure, 16 preuves) — et une preuve nouvelle à ajouter : 200 appels à blanc sont
impossibles (chaque forge coûte), donc on lit la rareté **dans le journal de la fonction**
(`tools/serveur/verif_faits.py` sait lire les logs) sur les forges réelles à venir, ou on
expose un `--stats` d'atelier qui tire 1 000 raretés sans peindre (à écrire, 20 lignes).

### C3 — Le Test QA 8-11 sur ton iPhone *(20 min, téléphone froid)*

Le déroulé est écrit (`tools/porte/PLAN-QA-COMPTE-SUITE.md` § 3 et § 5) et l'onglet Test QA
attend ses verdicts. Préalable : un binaire de l'arbre à jour (après C1 de préférence). Je lis
le serveur à chaque étape, tu dis « ok » ou ce qui cloche. Bonus 12 : Apple → recréer → Nosfy
à nouveau (compte neuf, nouvel uuid — attendu).

### C4 — Ta première forge, et la clé Apple *(toi, 20 min)*

- Un de tes deux sachets fermés : coffre → ouvrir → la carte ; je lis `user_boosters.card_id`,
  `user_cards`, `ma_collection()`, le journal de `forge-card` (pool ou neuve, quelle rareté).
- La clé .p8 : portail développeur → Keys → Sign in with Apple → `poser-cle-apple.sh` ; la
  sonde `apple-jeton` doit passer de `cle_absente` à `apple_400` ; à la prochaine entrée
  Apple, `apple_jetons` gagne sa première ligne.

### L'ordre que je propose

**1 (commit) → C1 → C2 → C3 → C4**, la doc du site avec chaque étape (les deux 🔴 posés ce
matin ne repassent au vert qu'une fois mesurés). Rien ne part sans ton ordre : ni commit, ni
`functions deploy`, ni republication du livrable en ligne (« toute la doc reste sur le site
local », ton mot).

## 5. Ce qui a bougé dans l'arbre ce matin (à ta disposition, rien de commité)

- `docs/site/content/briques.ts` : `b-fo-poids-60-27-10-3` → 🔴 ; `b-po-jeton-une-heure`
  (nouvelle, 🔴) ; `b-dg-la-collection-est-vide-au` et `b-dg-le-solde-repart-a-zero`, deux
  lignes PÉRIMÉES du 29-08 (elles contredisaient `b-fo-lire-user-cards` et `b-deux-nombres`)
  → 🟢 avec leur preuve ; `b-fo-le-tirage-la-rarete-le` et `b-fo-user-cards-se-remplit-a`
  perdent leur « preuve à citer » ; `b-po-cle-apple` relue (aucun secret APPLE_*).
- `docs/site/content/serveur.ts` : `b-ed-forge-card` (le corps déployé = le dépôt, et le
  défaut), `b-tb-apple-jetons` (0 / 0).
- `docs/site/scripts/alleger.py` (nouveau) + un appel dans `captures.py` : le livrable avait
  franchi les 2 Mo (2 056 876 o, le poids du texte des pages) ; les JPEG de `sips` ne sont pas
  optimisés — les mêmes pixels réécrits par Pillow (optimize + progressive) pèsent 30 % de
  moins : 511 727 → 358 694 o, livrable à 1 854 409 o. Le vérificateur passe (tout vert).
- `supabase/functions/forge-card/index.ts` et `Woop/Services/Supabase.swift` : les deux
  correctifs ont été **retirés** sur ton ordre ; le fichier de la forge est revenu à HEAD,
  `Supabase.swift` a retrouvé exactement ses diffs du 14-09.
