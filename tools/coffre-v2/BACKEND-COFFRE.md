# LE BACKEND DE LA PAGE REWARDS — état des lieux au 28-08

*Analyse demandée par Kathryn : « résume un peu tout le backend de cette page,
et elle est liée à d'autres pages aussi ».*

Références : `PLAN-PIED-COFFRE.md` (le design) · `../rewards/PLAN-REWARDS-BACKEND.md`
(les règles, §4 nonies → terdecies) · `../rewards/CHANTIERS-UX.md` §7-8bis
(les flows) · `../sacre/SUPABASE-PIPELINE.md` (le déploiement).

---

## 1. LE FAIT CENTRAL, EN UNE PHRASE

> **La page affiche six nombres. Aucun ne survit à la fermeture de l'app. Et
> le serveur qui les tiendrait est DÉJÀ déployé, mais personne ne l'appelle.**

Ce n'est pas un oubli : c'était la méthode — poser la mise en scène d'abord,
brancher ensuite, en gardant chaque nombre à UNE seule source pour que le
branchement ne touche aucune vue. Le moment de brancher est arrivé, parce que
trois règles nouvelles (§5) sont impossibles à tenir en local.

---

## 2. CE QUE LA PAGE LIT AUJOURD'HUI — tout est local

| ce qu'on voit | d'où ça vient | nature |
|---|---|---|
| le solde en pièces | `CoffreFortPurse.coins(doneSeries:)` = **séries × 20**, recalculé depuis les `Workout` SwiftData | **maquette assumée**, un seul fichier |
| les boosters orange en attente | `SacreEtat.shared.boostersEnAttente`, un `var` en mémoire **initialisé à 1** | **ne persiste pas** |
| les pièces d'argent / boosters noirs | `SacreEtat.shared.boostersNoirsEnAttente`, 0 sauf `-sacreNoir` | **ne persiste pas** |
| la jauge « 60 to go » | `dispo % 100`, arithmétique locale | dérivé |
| le prix (100) | `CoffreV2.prixBooster`, constante Swift | **en dur, alors que `reward_rules` le porte déjà** |
| l'historique des gains | `@Query` sur `Workout` dans `CoffreFortFlow`, qui refait `séries × 20` | **une reconstruction, pas un journal** |

⚠️ **ET LA DÉPENSE EST SIMULÉE.** `dispo = coins − boostersEnAttente × 100` :
la page SOUSTRAIT à la main ce que les sachets en réserve ont coûté, parce que
rien ne débite jamais. C'est juste tant qu'un seul appareil joue ; ça se
contredit dès le deuxième.

---

## 3. CE QUI EXISTE CÔTÉ SERVEUR — déployé, et jamais appelé

**Tables** (`20260828120000_booster_noir.sql`, `20260828160000_wallet_coffre.sql`)

- `user_boosters` — `origine` ∈ (`seance`, `achat`, `cadeau`, `legendaire`),
  `workout_id`, `opened_at`, `card_id`.
  ⚠️ Deux index uniques partiels y font DÉJÀ l'idempotence :
  `user_boosters_seance_unique (user_id, workout_id)` et
  `user_boosters_noir_ouvert_unique`.
- `coin_ledger` — `delta`, `raison`, `currency` ∈ (`yellow`, `silver`).
  Le solde est **dérivé** (`sum(delta)`), jamais stocké : un solde stocké se
  désynchronise, une somme ne peut pas mentir.
- `reward_rules` — `pieces_par_serie` = 20, `prix_booster` = 100,
  `prix_booster_legendaire` = 1. **Les prix sortent du code : l'app les LIT.**
- `booster_progress` — l'avancement vers le prochain sachet.

**Fonctions** : `solde_argent()`, `etat_coffre()`, `claim_booster_legendaire()`.

**Client Swift** : `Services/SacreServeur.swift` — `etatCoffre()`,
`soldeArgent()`, `claimLegendaire()`. ⚠️ **Écrit, compilé, et appelé par
personne** (vérifié : la seule autre occurrence du nom est un commentaire).

**Edge functions** : `forge-card` (ce que le booster CONTIENT — le tirage des
cartes, le scellement, la légendaire forcée pour un booster noir),
`weekly-synthesis`.

---

## 4. LES PAGES LIÉES — huit, et pourquoi

La page Rewards n'est pas une feuille : c'est le **guichet** d'une économie que
sept autres écrans alimentent ou dépensent.

| page | lien | sens |
|---|---|---|
| **Profil** (`ProfilLune`) | les deux pills (or, noir) lisent `SacreEtat` + `CoffreFortPurse` et ouvrent le manège | ⚠️ **même source que le pied du coffre, exprès** — « un nombre montré à deux endroits n'existe qu'une fois » |
| **Le Manège** (`BoosterPopup` / `SacreEtat`) | « Ouvrir » ferme le coffre puis monte le manège À LA RACINE | dépense un booster |
| **Le chemin Duolingo** (`RewardChemin`, commits `a339141`, `5ac641f`) | les galets lune/pièce tirent AU CLAIM : 100-200 pièces, une pièce d'argent (6 %), ou **1 à 2 boosters** | **alimente**, et n'écrit nulle part |
| **Welcome Back** (`RewardPopup .welcome`, 2 robes) | **10 pièces, une fois par jour calendaire** (tranché le 28-08) | alimente — §4 duodecies |
| **Fin de séance** | **un booster basique automatique** (règle du 28-08) | alimente — §4 terdecies |
| **Home** (`HomeAuroraView`, `HomeNuit`) | affichent les pièces via `CoffreFortPurse` | lit |
| **BRAVO** (`BravoLab`) | annonce `perSeries` (+20) | lit |
| **`forge-card`** | ce qu'on trouve DANS le sachet | consomme le booster |

⚠️ **`CoffreFortPurse` est le point de passage de CINQ écrans hors du coffre.**
C'est pour ça qu'il a été sorti dans son propre fichier avant tout le
chantier : laisser l'économie de l'app dans le fichier d'une page qu'on
démonte, c'est faire dépendre cinq compilations du sort d'un écran.

---

## 5. LES TROIS RÈGLES NOUVELLES, ET CE QU'ELLES FORCENT

1. **10 pièces par jour calendaire** au Welcome Back (§4 duodecies) — ✅ tranché.
2. **1 à 2 boosters** par nœud de chemin (§4 terdecies) — déjà commité côté app,
   jamais écrit côté serveur.
3. **1 booster basique à chaque fin de séance** (§4 terdecies) — ⚠️ le schéma
   l'avait anticipée : `user_boosters.origine` vaut `'seance'` PAR DÉFAUT et
   l'index unique sur (user, séance) empêche déjà le double crédit.

**Aucune des trois ne passe par « séries × 20 ».** L'historique des gains les
rate donc toutes les trois, et le solde aussi.

> ⚠️ **C'est ce qui fait basculer le sujet : lire le ledger n'est plus une
> amélioration, c'est la condition pour que la page dise la vérité.**

Et c'est aussi ce qui donnera enfin des **lignes avec un sachet** dans
l'historique : `GainCoffre.robe` est aujourd'hui toujours `nil`, donc chaque
ligne montre la pièce d'or — signalé en livrant la page.

---

## 6. LA QUESTION D'ÉCONOMIE QUI RESTE OUVERTE

Une séance de 5 séries rapporte 100 pièces = un booster. Si elle donne **en
plus** un booster automatique, une séance en rapporte **deux**, et le prix de
100 pièces ne décide plus grand-chose pour quelqu'un de régulier.

Ce n'est pas forcément un défaut — c'est peut-être l'intention (« finir une
séance est toujours payant »). Trois sorties, détaillées au §4 terdecies :
assumer · monter le prix (150-200) · ou distinguer les robes. **Le prix vivant
dans `reward_rules`, ce choix se change sans toucher au code.**

---

## 7. L'ORDRE DE BRANCHEMENT (le moins risqué d'abord)

1. **Écrire** — `serie_faite` dans `coin_ledger` à la clôture d'une séance, et
   la ligne `user_boosters(origine: 'seance', workout_id:)`. Rien ne lit
   encore : on remplit le journal avant de s'en servir.
2. **Lire les prix** depuis `reward_rules` au lieu des constantes Swift.
3. **Lire les soldes** par `etat_coffre()` — le corps de `variantes` disparaît,
   la vue ne bouge pas d'une ligne (c'est écrit dans son propre commentaire).
4. **Basculer l'historique** sur `coin_ledger` + `user_boosters`.
5. **Le chemin** : `origine = 'chemin'` + `noeud_id`, et la pitié côté serveur
   (aujourd'hui au front, donc falsifiable).
6. **Le Welcome Back** : `claim_retour_quotidien()` + son index unique partiel.

⚠️ **Étapes 1 et 2 d'abord, parce qu'elles ne changent RIEN à l'écran** — un
branchement qui ne se voit pas est un branchement qu'on peut défaire.
