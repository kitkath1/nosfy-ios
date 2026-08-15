# LE SACRE × SUPABASE — ce qui existe, ce qui manque

**Note du 15-08-2026.** À lire avant toute session Supabase.
**RÈGLE ABSOLUE : rien ne se fait sans Kathryn** — pas de migration
poussée, pas de fonction déployée, pas de table créée en autonome.

**Piège de compte** — le MCP Supabase de la session pointe *AxioSense*
(un autre projet). Le repo, lui, est lié au bon projet
(`supabase/.temp/project-ref` = `ytnnyjkramgiqyxdrkcu`). Passer par la
**CLI**, jamais par le MCP. Et le jeton du `~/.zshenv` est celui du
compte PRO (Axione) : il ne doit pas servir à Woop — il faut un access
token perso rangé dans `.secrets/supabase-access-token`.

---

## Ce qui EXISTE déjà (et qui est bon)

**Migration locale `20260814180000_cartes_lune.sql`**
- `cards` — le pool canonique partagé : `famille`, `rarete` (contrainte
  sur les 4 registres), `scene`, `art_path`, `depth_path`. RLS : lisible
  par tout compte authentifié, **aucune policy d'insert client**.
- `user_cards` — la collection : `user_id`, `card_id`, `obtained_at`,
  `workout_id`. RLS : chacun ne lit que la sienne.
- bucket storage `cards`, public en lecture, écritures service_role.

**Edge function `forge-card`** (déployée, vérifiée) — elle fait déjà :
- le **tirage de rareté** pondéré : `common 60 / rare 27 / epic 10 /
  legendary 3` ;
- **pool ou neuf** : 65 % des tirages piochent une carte existante du
  pool, 35 % en forgent une neuve (`PART_NEUF = 0.35`) ;
- la génération (directeur artistique GPT-5 → `gpt-image-1` avec les
  deux références), l'upload storage, l'insert `cards` ;
- **l'insert `user_cards`** avec le `workout_id` ;
- le renvoi de l'URL publique.

**Les 25 familles** sont dans la fonction ET dans `LuneForge.swift`, avec
la même répartition que les registres du profil : 4 common, 11 rare,
4 epic, 6 legendary — les totaux `4 / 11 / 4 / 6` affichés sont donc
justes, mais **codés en dur à trois endroits**.

---

## Ce qui MANQUE (par ordre de blocage)

### 1. Lire la collection depuis l'app — *le vrai trou*
Personne côté Swift ne lit `user_cards`. `CollectionLune`
(`Woop/Views/SacreAccueil.swift`) est un store **en mémoire** qui meurt
avec le process : la page profil oublie tout au relancement.

À faire : un `CollectionStore` (REST maison, dans l'idiome de
`SupabaseSync.swift`, sans SDK) qui charge `user_cards` joint à `cards`,
**agrège les doublons** (plusieurs lignes du même `card_id` = une
vignette + pastille ×N), trie par `obtained_at` (c'est lui qui donne
l'ordre « à la suite »), et alimente les quatre registres.

### 2. Le cache des images
Les arts sont des PNG du bucket public. Sans cache disque, la page
profil retélécharge la collection entière à chaque affichage. Il faut un
cache par `card_id` + une image de repli tant que le téléchargement
n'est pas fini (le dos vide fait très bien l'affaire).

### 3. Le solde de pièces — *aujourd'hui impossible à débiter*
Les pièces sont **calculées** (`CoffreFortPurse.coins(doneSeries:)`,
20 par série faite) : il n'existe aucun solde stocké, donc **on ne peut
pas payer 20 pièces pour ouvrir un booster**. Deux options à trancher
ensemble :
- une table `coin_ledger` (gains et dépenses, le solde = la somme) —
  auditable, la plus solide ;
- ou garder le calcul et ne stocker que les dépenses (`booster_opens`).

### 4. Les boosters gagnés mais pas encore ouverts
Le flow prévoit : séance terminée → pop-up → carrousel de boosters. Rien
ne stocke un booster **en attente**. Il faut une table `user_boosters`
(`user_id`, `workout_id`, `obtained_at`, `opened_at` nullable) : c'est
elle qui remplit le manège (N sachets), qui survit à une fermeture de
l'app, et qui interdit d'ouvrir deux fois le même.

### 5. L'idempotence et l'anti-rejeu
`forge-card` tire une carte à **chaque appel** : rien n'empêche d'appeler
la fonction en boucle. La garde doit être **serveur** : un tirage ne
s'exécute que s'il consomme un booster non ouvert (`opened_at is null`),
dans une transaction. Sinon la collection se remplit gratuitement.

### 6. Le lien « séance terminée → booster »
`workout_id` existe déjà dans `user_cards`, mais aucune règle ne dit
« une séance terminée = un booster », ni ne protège contre : la même
séance rejouée, une séance reprise, ou plusieurs appareils. À écrire
côté serveur (contrainte d'unicité sur `(user_id, workout_id)` dans
`user_boosters`).

### 7. Le mode avion
Une séance peut se terminer sans réseau (c'est le cas d'usage réel : la
salle). Le booster doit être **promis localement** et réclamé au premier
lancement connecté — même logique de rattrapage que la sync des séances.

### 8. L'authentification du vrai flux
`ForgeServeur.jwtBanc()` est un JWT **de banc**. Le flux d'app doit
utiliser la session du compte connecté (identité par numéro, cf.
`WoopConfig.accounts`).

### 9. La source unique des familles
Les 25 familles et leurs raretés vivent en double (Deno + Swift), et les
totaux des registres en triple (`ProfilLune.registresProfil`). Une seule
source : une table `families` (ou dériver les totaux d'un `count` sur
`cards`), sinon chaque ajout de famille demandera trois modifications
cohérentes.

### 10. Détails à ne pas oublier
- `depth_path` est **null** partout : l'app utilise sa depth analytique
  v0. Prévoir la génération, ou assumer et documenter.
- Vérifier que la migration locale est bien **poussée en remote** (elle
  n'a jamais été confirmée appliquée).
- Les policies d'écriture pour les nouvelles tables (wallet, boosters) :
  le défaut-refus doit rester la loi, tout passe par des fonctions.
- Que se passe-t-il quand un registre est **complet** ? (le doublon d'une
  famille déjà possédée est le cas normal — vérifier que l'UI et le
  store le rendent bien, et décider s'il rapporte des pièces.)

---

## L'ordre proposé pour la session Supabase

1. `user_boosters` + le lien séance → booster (la brique qui débloque le
   vrai flow de bout en bout).
2. La garde serveur d'idempotence sur `forge-card`.
3. Le `CollectionStore` de lecture + le cache d'images (la page profil
   devient vraie).
4. Le solde de pièces et le coût d'ouverture.
5. Le rattrapage hors-ligne.
6. La source unique des familles.
