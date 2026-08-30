# LES QUATRE TROUS DU BACK-END BOOSTER — le plan avant la ligne

**30-08-2026, sur sa demande : « corrige tout ça, je te file un token ».** Les
quatre trous viennent de `tools/sacre/ANALYSE-FLOW-BACKEND-BOOSTER.md` (§2.4,
§4.7, §4.8). Ce plan dit CE QU'ON FAIT, DANS QUEL ORDRE, et COMMENT ON LE
PROUVE — la migration part au `db push` avec son jeton, révoqué après, et
rien n'est « déployé » sans la vérification du skill woop-backend §6.

---

## 1. Un sachet = une carte (le scellement)

**Le trou.** `BoosterLab.lancerForge()` appelle `ForgeServeur.tirer(jwt:)`
sans `boosterId` alors que `forge-card` sait tout faire avec : relire
`user_boosters`, **imposer `legendary` si `origine = 'legendaire'`**, rendre
la MÊME carte sur un rejeu, et **sceller** `card_id`. Résultat aujourd'hui :
aucune idempotence du tirage, aucun scellement, **la garantie légendaire du
noir jamais armée**, et la consommation (`ouvrir_booster`) part à l'ENVOL
(t5), après le tirage (t2) — un quit entre les deux laisse une carte en base
et un sachet intact.

**La forme juste — consommer AVANT de forger, et forger AVEC l'id.**

À l'engagement (`commitGallery`, le tap sur le sachet central), avant
`lancerForge()` :

1. **obtenir l'id du sachet** :
   - orange → `ouvrir_booster(false)` (rendu **idempotent** par la
     migration : s'il existe déjà un sachet orange OUVERT NON SCELLÉ, il est
     rendu tel quel — c'est la reprise d'un quit entre consommation et
     forge) ;
   - noire → `claim_booster_legendaire()` (déjà idempotente : rend le
     légendaire ouvert non scellé s'il existe, sinon débite 1 pièce d'argent
     et le crée). ⚠️ Plus jamais `ouvrir_booster(true)` pour le noir : sa
     condition `opened_at is null` ne matche JAMAIS un légendaire (créé
     ouvert) — c'est le trou §3 ;
2. `ForgeServeur.tirer(jwt:, boosterId:)` → `forge-card` scelle ;
3. l'envol ne consomme plus rien : `onCarteEnvolee` **relit** (`rafraichir`).

**Sous panne réseau à l'engagement** : pas d'id → **pas de forge serveur** ;
la cérémonie joue le repli (carte-lune-1) comme aujourd'hui hors ligne, et
le sachet reste — jamais une carte serveur « gratuite ». Dit dans la doc.

Le client : `EconomieWoop.consommerBooster(legendaire:)` choisit la bonne
fonction et rend l'id ; `SacreServeur.claimLegendaire` lit du jsonb (§2) ;
`BoosterLab.commitGallery` → `consommerPuisForger()`.

## 2. `claim_booster_legendaire` répond 200, pas 500

**Le trou.** Un refus métier (« pas assez d'argent ») sort en `raise
exception P0002` → HTTP 500 — le client ne distingue pas un refus d'une panne
(skill §3). Et elle rend une LIGNE `user_boosters`, l'autre porte rend du
jsonb : deux langues.

**La forme juste.** `returns jsonb` : `{ouvert, booster_id, raison,
solde_argent, prix}` ; refus → 200 `{ouvert: false, raison:
'argent_insuffisant', …}`. ⚠️ **Changer le type de retour d'une fonction
existante refuse le `create or replace`** (« cannot change return type ») :
`drop function if exists` D'ABORD — le piège qui casse À LA POSE, déjà payé
sur un `check`.

## 3. La pile noire se consomme

Réglé par §1 (le noir passe par `claim_booster_legendaire`, qui débite la
pièce d'argent — la fonction avait ZÉRO appelant) et par §2.
`ouvrir_booster(true)` est aligné pour dire la même chose (un légendaire
ouvert non scellé), mais le client ne l'appelle plus pour le noir.

## 4. Le tirage du chemin remonte au serveur

**Le trou.** `RewardChemin.TirageRecompense` tire au CLIENT (6 % pièce
noire, 1 % double légendaire, 11 % rare, pitié ×2 après 12 communs), puis
`reclamer_noeud_chemin` ENREGISTRE ce que le client raconte. « Ce qu'on ne
croit jamais du client : un tirage de récompense, un compteur de pitié. »

**La forme juste.** Une nouvelle fonction `tirer_noeud_chemin(p_noeud
integer, p_pieces boolean) returns jsonb` :

- **déjà réclamé** → rend le résultat STOCKÉ (pièces + monnaie depuis
  `coin_ledger raison = 'chemin'`, robes depuis `user_boosters origine in
  ('chemin','cadeau')` du même nœud) avec `deja_reclame: true` — un rejeu
  (timeout, double tap) rend le MÊME tirage, jamais un second ;
- sinon **tire côté serveur** (`random()`), avec les taux LUS dans
  `reward_rules` (six clés nouvelles : `chemin_taux_piece_noire` 0,06 ·
  `chemin_taux_double_legendaire` 0,01 · `chemin_taux_rare` 0,11 ·
  `chemin_pitie` 12 · `chemin_pieces_min` 100 · `chemin_pieces_max` 200) et
  **la pitié DÉRIVÉE du journal** (jamais un compteur) : le nombre de nœuds
  communs d'affilée sur la piste, lu dans `coin_ledger` (piste pièces : des
  'yellow' depuis la dernière 'silver') ou dans `user_boosters` (piste
  boosters : des nœuds tout-'lune' depuis le dernier nœud à 'noire') ;
- **écrit** dans la même transaction (les deux index tiennent l'unicité) ;
- rend `{deja_reclame, type: 'coins'|'boosters', montant, monnaie, robes,
  rarete, solde, solde_argent}`.

L'ancienne `reclamer_noeud_chemin(p_noeud, p_pieces, p_monnaie, p_boosters)`
**reste** (l'outbox peut encore porter un nœud tiré avant cette version) ;
le client ne la poste plus.

**Le client.** `RewardCheminEtat.reclamer(id, pieces:)` : l'état passe à
`claiming` (il existait pour ça), l'appel est SYNCHRONE (la révélation a
besoin du résultat — c'est le prix de l'anti-triche, et l'état machine le
disait : « un échec REVIENT à available, jamais un galet mort ») ; sur la
réponse, `RecompenseTiree` est CONSTRUITE depuis le serveur, persistée dans
le journal, révélée. Sans serveur (`EconomieWoop.possible` faux — maquette,
`-demoData`) : le tirage local d'aujourd'hui, dit comme tel. La pitié locale
(`chemin.secs.*`) ne sert plus qu'à la maquette.

---

## 5. La migration — `20260830160000_sachet_scelle_et_tirage.sql`

Dans cet ordre (une fonction avant celle qui s'en sert, les clés avant la
fonction qui les lit) :

1. `reward_rules` : les six clés du chemin (`on conflict do nothing`).
2. `drop function if exists public.claim_booster_legendaire();` puis la
   version jsonb (§2) — `security definer`, `set search_path = public`,
   `revoke … from public, anon`, `grant … to authenticated`.
3. `create or replace function public.ouvrir_booster(boolean)` — même
   signature (pas de drop), avec la reprise du sachet ouvert non scellé
   (§1) ; le cas légendaire aligné (§3).
4. `create function public.tirer_noeud_chemin(integer, boolean)` (§4) —
   `random()` côté serveur, `unique_violation` attrapée, **littéraux TYPÉS**
   dans les `jsonb_build_object`.
5. `create or replace function public.etat_coffre()` — `boosters_or` compte
   aussi l'orange ouvert non scellé des six dernières heures, et la clé
   `noirs_ouverts` (§9.5).
6. `create or replace function public.reclamer_noeud_chemin(…)` — même
   signature, délègue à `tirer_noeud_chemin` (§9.6).

Et hors migration : `supabase functions deploy forge-card` (le scellement
AVANT la collection, §9.7).

Aucune table, aucune colonne, aucun index nouveau : les index d'unicité
existants tiennent tout.

## 6. La preuve, sur le COMPTE DE TEST, corps lus

Tout est dans **`tools/sacre/verif_backend_sachet.py`** (un verdict ✓/✗ par
ligne, exit 1 si une preuve manque) :

- `migration list --linked` avant / après le push.
- `etat_coffre` porte `noirs_ouverts`.
- `claim_booster_legendaire` : avec 1 pièce d'argent → 200 `{ouvert: true,
  booster_id}` ; rejoué → le MÊME id (reprise) et `noirs_ouverts = 1` ; sans
  argent → 200 `{ouvert: false, raison: 'argent_insuffisant'}`.
- `ouvrir_booster(false)` deux fois de suite : **le même id** tant qu'il n'est
  pas scellé (la reprise), et `boosters_or` **ne bouge pas** entre les deux.
- `forge-card` avec ce `booster_id` : une carte, rejouée → la MÊME ;
  `user_boosters.card_id` scellé ; `boosters_or` descend d'un ; l'ouverture
  suivante rend un AUTRE id.
- `tirer_noeud_chemin` : `(9001, true)` → 200 `noeud_invalide` ; `(3, false)`
  → 200 `piste_invalide` ; sur le premier nœud VALIDE encore libre du compte
  (pièces : 3, 21, 39 ; sachets : 8, 17, 26, 35, 44, 12, 30) un tirage, puis
  rejoué : même `montant`/`monnaie` ou mêmes `robes` dans le même ordre,
  `deja_reclame: true`. ⚠️ Quand le compte n'a plus de nœud libre, la preuve
  le DIT (✗) au lieu de prouver sur un nœud inventé.
- `reclamer_noeud_chemin(nœud déjà tiré, 1 000 000, 'silver', {})` →
  `deja_reclame`, et `solde_argent` inchangé.
- le scellement DEPUIS L'APP : `-boosterManege -boosterCine -boosterScelle`
  (sans `-demoData` — la garde `EconomieWoop.possible` ne consomme pas
  d'argent en démo) : le log dit `banc scellement : sachet <id>`, puis
  `user_boosters` (policy select) montre ce sachet avec un `card_id`.
- témoin inventé → 404.

## 7. La doc

`docs/site/index.html` ne s'édite plus à la main : les lignes (état ·
preuve · témoin) partent par message à la session 13, comme ce matin.

## 8. Ce que ce plan NE fait PAS

- La conversion 100 pièces = 1 sachet (question d'économie ouverte).
- « Un nœud rend deux sachets sous un index (user, nœud) » : le contournement
  `chemin` + `cadeau` reste (il est lisible et jamais dupliqué) — trancher
  l'index est une autre migration.
- Le chapitre du chemin (« où commence un chapitre ») : hors périmètre.
- La garde « les séances d'avant sont faites » (un nœud réclamé avant d'être
  dépassé) reste au client : le serveur borne le nœud et sa piste (§9.4),
  pas l'avancement.

## 9. La relecture adverse du 30-08 — 16 constats, 11 corrections

Trois lentilles (pose, argent, client), 100 outils, AVANT la pose. Les 16
constats se recoupent en 11 corrections, toutes appliquées :

1. **La course rend le STOCKÉ.** Sur `unique_violation` (deux requêtes en
   vol, deux appareils), `tirer_noeud_chemin` rendait le tirage NEUF que
   l'index venait de refuser — l'écran annonçait une pièce d'argent quand le
   ledger portait 150 jaunes. Les deux branches relisent ce qui a été écrit.
2. **La reprise orange est bornée à six heures.** Sans borne, les orphelins
   d'avant la migration (chaque manège d'avant ouvrait sans sceller) seraient
   rendus un par un et le compteur ne descendrait pas pendant N ouvertures.
   La reprise NOIRE n'a pas de borne (au plus un, par l'index, déjà payé).
3. **Le galet se dégrave sur un échec.** La page gravait le nœud au tap, et sa
   copie de `reclamees` ne se relisait qu'à la naissance : un échec serveur
   laissait un galet gravé et mort. `onLune`/`onPiece` rendent maintenant le
   verdict (`async -> Bool`) et la page dégrave sur `false`.
4. **Le nœud est borné et rapproché de sa piste.** `(45, true)`, `(46, true)`…
   créditaient 100-200 pièces par entier neuf. Refus 200 `noeud_invalide` /
   `piste_invalide`, géométrie lue dans `reward_rules`.
5. **Les sachets ouverts non scellés se voient.** Consommer AVANT de forger
   créait un état invisible : forge qui ne scelle pas → compte à 0 → porte
   fermée → reprise jamais déclenchée. `etat_coffre` compte l'orange ouvert
   des six dernières heures dans `boosters_or` et rend `noirs_ouverts` ;
   `boostersNoirs = argent + noirsOuverts` côté app.
6. **L'ancienne `reclamer_noeud_chemin` ne croit plus le client** :
   `(9999, 1 000 000, 'silver', {})` créditait un million d'argent. Elle
   délègue à `tirer_noeud_chemin` (même forme de réponse, l'outbox d'hier
   vide encore).
7. **`forge-card` scelle AVANT la collection**, et lit la ligne touchée :
   deux forges sur le même sachet (reprise pendant une peinture de 90 s)
   inséraient deux `user_cards`. La perdante rend la carte de l'autre.
8. **`claimLegendaire` lit les deux dialectes** (ligne d'avant / jsonb
   d'après) : l'app et la base se déploient par deux actes.
9. **Deux raisons de ne pas avoir d'id, distinguées** au manège : la garde
   `-demoData` (forge du banc sans sachet, comme avant) et le refus serveur
   (pas de forge).
10. **Le banc du scellement** : `-boosterScelle` consomme sur le compte de
    test avec le jwt du banc — la seule façon de prouver le scellement au
    sim (pas de `woop.phone`, donc pas de session).
11. **La maquette n'écrit plus rien** : elle postait son tirage local dans
    l'outbox, gardé sous `-demoData`, vidé au lancement suivant sur le compte
    réel. `poster(noeud:)` est mort.

Et `array_agg(… order by (origine = 'cadeau'), obtained_at)` : les deux
lignes d'un nœud naissent avec le même `now()`, l'ordre des robes ne se
départageait pas.
