# LE BACK-END DES REWARDS — gamification contextuelle

**Écrit le 25-08-2026, sur le plan produit de Kathryn (« Gamification
contextuelle — Pills, Moments, Rewards, vidéos et IA »).** Ce document ne
remplace rien : il s'ajoute à [../sacre/SUPABASE-PIPELINE.md] (les
boosters, le ledger, les familles) et ne couvre QUE les rewards. Rien
n'est codé ; c'est la doctrine à trancher puis à construire.

> **RÈGLE ABSOLUE (héritée du Sacre)** — rien ne se fait sur Supabase
> sans Kathryn. CLI, jamais le MCP (le MCP de session pointe AxioSense).

Le principe produit, en une ligne :

> La plupart du temps RIEN (une pill discrète) ; parfois l'app a
> REGARDÉ la séance (Moment) ; parfois elle récompense (Reward) ; très
> rarement l'exceptionnel (Rare). Le backend décide QUAND, l'IA décide
> QUOI RACONTER, le Design System borne CE QU'ELLE A LE DROIT DE FAIRE.

---

## 0. Ce que ce plan change de STRUCTUREL (le pivot)

**Le solde calculé meurt.** Aujourd'hui les pièces sont *calculées*
(`CoffreFortPurse.coins` = séries faites × 20) et le pipeline Sacre le
dit lui-même : « rien n'est débitable ». Des rewards VARIABLES (+40,
+30, claim +20, pièce noire) rendent le calcul impossible : **tout gain
devient une ligne de `coin_ledger` avec une raison**. Conséquences :

1. **Migration de richesse** : au bascule, le solde calculé existant est
   RE-CRÉDITÉ en une ligne `raison = 'migration_calcul'` par user —
   sinon l'utilisateur voit sa fortune disparaître.
2. **La règle des 20 reste LA LOI** : chaque série faite = 20 pièces,
   déterministe, silencieux dans ~60 % des cas. Les bonus sont des
   lignes SUPPLÉMENTAIRES, jamais un remplacement.
3. **Deux monnaies** : `currency in ('yellow','black')` — une COLONNE du
   ledger, pas une deuxième table. Deux soldes dérivés.

---

## 1. Les événements — l'outbox local et le règlement

**Contrainte maison payée** : « rien n'est écrit avant Terminer » (le
trou `save()` de la fiche est documenté). Les décisions de pop-up
arrivent PENDANT la séance, sur l'état local. Donc :

- **Pendant la séance** : tout est LOCAL. Un journal d'événements
  (l'outbox) s'écrit sur disque au fil de l'eau :
  `{session_uuid, serie_index, type, facts, montant, ts}`.
  Les pills et pop-ups s'affichent depuis ce journal — zéro réseau
  requis pour jouer la séance.
- **Au règlement** (Terminer, ou reprise après crash) : l'outbox part au
  backend en batch → `settle_session(session_uuid, events[])` écrit les
  lignes `coin_ledger` en une transaction, **idempotente** par clé
  `(user_id, session_uuid, serie_index, raison)` — le rejeu d'un batch
  ne crédite jamais deux fois. C'est la garde `claim_booster` du Sacre,
  appliquée aux gains.
- **Un claim en cours de séance** (Welcome Back, pièce noire) qui doit
  être FIABLE passe, lui, en ligne directe avec la même clé
  d'idempotence — s'il échoue (offline), il reste dans l'outbox et se
  règle plus tard : l'UI a le droit d'afficher le gain tout de suite,
  le ledger rattrape.

---

## 2. Le moteur de décision — QUAND (backend, jamais l'IA)

**Le pacing n'est pas un dé.** Une probabilité par série produit des
paquets (trois pop-ups d'affilée) et des déserts. Le « ~60 % de séries
silencieuses » est un RÉSULTAT, pas un paramètre. Le moteur :

- **Budget de séance** : max N pop-ups par séance (défaut 3-4 pour ~20
  séries, dont ≤ 1 Reward monétaire, ≤ 1 vidéo), rechargé par séance.
- **Écart minimal** : jamais deux pop-ups à moins de K séries / M
  minutes (défaut 3 séries ou 6 min).
- **File de priorité** : Rare > Reward > Moment. Un fait « notable »
  qui arrive pendant un cooldown est ABANDONNÉ ou rétrogradé en pill
  enrichie (`+20 · meilleure série`) — jamais mis en file d'attente
  pour tomber mécaniquement plus tard.
- **Interdiction des positions fixes** : aucun déclencheur du type
  « série 5/10/15 » ; les triggers sont des FAITS (fin d'exo, PR,
  volume, densité), pas des compteurs.
- **La rareté vit CÔTÉ SERVEUR** : le tirage de la pièce noire (et de
  tout drop) est un RNG serveur avec *pity timer* (garantie douce après
  X séances) et cooldown dur — jamais un `Double.random` client, jamais
  farmable en rejouant l'UI.

Configuration dans une table `reward_rules` (lue par l'app au lancement,
cache local) : seuils, budgets, cooldowns, probabilités, pity. Tout se
règle sans redéployer l'app.

**LES NOMBRES DE DÉPART (tranchés le 25-08 par délégation — « fais une
probabilité, je te laisse faire » ; ils vivent dans `reward_rules`,
modifiables sans app) :**

| règle                                   | valeur v1                    |
| --------------------------------------- | ---------------------------- |
| pop-ups max / séance (~20 séries)       | 4, dont ≤ 1 Reward monétaire |
| vidéo max / séance                      | 1                            |
| écart minimal entre pop-ups             | 3 séries ET 6 minutes        |
| bonus monétaire                         | +40 (fort) / +30 (progrès) / +20 (surprise), plafond 60/séance |
| même type de fait                       | 1 fois / séance, 2 fois / semaine |
| **pièce noire** (RNG serveur, au settle)| p = 1/30 séances, pity garanti à la 45ᵉ sans drop, cooldown dur 10 séances après un drop |
| Welcome Back                            | absence ≥ 4 jours, cooldown 14 jours, max 2/mois, claim +20 |
| Moment « fin d'exo »                    | max 2 / séance, jamais deux exercices consécutifs |

---

## 3. Les FAITS — le fact engine (backend, calcul pur)

L'IA ne calcule JAMAIS. Le backend produit une liste de faits typés,
chacun **pré-calculé et pré-formaté** :

```
fact = { id, kind, value, unit, comparison, window, rank }
  ex.  { f1, charge_max_exo, 24, kg, +4 vs dernière séance, 14j, #1 }
       { f2, volume_exo, 1280, kg, +12 %, semaine, #2 }
       { f3, hiit_sequence, 3×40s, 17 km/h, meilleure, 14j, #1 }
```

Fenêtres canoniques : série / exercice / séance / semaine / 14 jours / mois/
record. Détections v1 : charge max, reps à charge égale, volume exo,
volume séance, densité (volume/min), séries cumulées, minutes cumulées,
fin d'exercice, meilleure séquence HIIT (notamment sur tapis de course)

**LE TROU DE DONNÉES HIIT — DÉCISION DU 25-08** : l'expérience HIIT
sera RETRAVAILLÉE pour être **déclarative** (l'utilisateur déclare ce
qu'il a réellement tenu) — c'est le chantier UX n° 1 de
[CHANTIERS-UX.md](CHANTIERS-UX.md). En attendant : une phase jouée
jusqu'au bout = un fait (planifié ≈ réalisé), assumé.

Côté schéma : les agrégats se calculent sur les tables de séance au
règlement (vues matérialisées ou calcul dans `settle_session`), et les
faits « live » de la séance en cours se calculent EN LOCAL sur l'état de
la fiche (le backend fournit à l'app, en début de séance, les
RÉFÉRENCES historiques : max 14j par exercice, volume hebdo, records —
un seul fetch, petit, cacheable).

---

## 4. La couche IA — QUOI RACONTER (bornée, typée, remplaçable)

- **Entrée** : la liste de faits (§3) + le contexte (type de séance,
  budget restant, atmosphère candidate).
- **Sortie** : un JSON STRICT, tout en enums —

```
{ fact_id, headline_value: "24", headline_unit: "KG",
  title, subtitle,
  variant: halo | neon | galet | spotlight,
  atmosphere: neutral | effort | performance | reward | rare,
  layout: chiffre_geant | chiffre_stats | titre_dominant | minimal,
  video: none | reward_1 | reward_2 | reward_3 | fire | lune | rare }
```

- **Les nombres affichés sont RECOPIÉS des faits**, jamais reformulés :
  l'IA choisit `fact_id` et des textes courts, le client affiche
  `value/unit` du fait lui-même (zéro hallucination arithmétique).
- **Latence : le repos est le budget.** La demande part à la fin de la
  série ; la réponse a 30-90 s pour arriver avant le retour fiche. Pas
  de réponse à temps → **gabarits déterministes de secours** (un par
  kind de fait) — l'utilisateur ne voit jamais un spinner de pop-up.
- **Langue : ANGLAIS** (le parcours est passé EN, commit 9603dc8). Les
  exemples FR du plan produit sont des maquettes, pas des chaînes.
- **Où elle tourne** : edge function `narrate-reward` (même famille que
  `forge-card`), qui logge `{facts_in, json_out}` pour rejouabilité.
- Les « petites surprises de composition » (§5 du plan produit) sont
  l'enum `layout` + micro-options typées (chiffre décentré : bool,
  halo bas/haut : enum, mini-stats : liste de fact_ids) — **jamais du
  style libre** : le client ne sait RENDRE que la grammaire.

### LES TEXTES SONT DYNAMIQUES, LES LAYOUTS SONT FIGÉS (26-08)

Kathryn : « de toute façon les textes seront plus tard dynamiques, ils
changeront grâce à l'IA — on ne fait que les layouts ». Conséquences
contractuelles :

- **Aucun mot n'est en dur dans une robe** : `title`, `subtitle`, et
  pour les robes à TEXTE GÉANT (You Made It, Welcome v2) une entrée
  `bigLines: [String]` (1 à 3 lignes courtes).
- **La longueur est un CONTRAT** : chaque robe déclare son maximum
  (ex. 3 à 9 signes par ligne géante) — au-delà, la typo casse. L'IA
  reçoit cette borne et la respecte ; le client tronque en dernier
  recours, il ne rétrécit JAMAIS (une ligne géante rétrécie n'est plus
  géante).
- **Les tailles, graisses et couleurs restent au Design System** :
  l'IA choisit les MOTS et le variant, jamais la typo.

### L'AUDIT DE CE QUI EST DÉJÀ PARAMÉTRABLE (26-08, mesuré dans le code)

Question de Kathryn : « dans les autres variants c'est aussi
paramétrable IA, sans toucher l'UI ? » — voici l'état RÉEL de
`RewardPopup`, robe par robe.

**Déjà des entrées (l'IA peut les remplir sans qu'on touche l'UI) :**
`count` (le chiffre), `title`, `subtitle`, `unit`, `style` (le variant),
`robe` (les deux cards Welcome), `videoNom` (la vidéo du header).
`TexteGeant` accepte déjà ses `lignes` en paramètre.

**Encore EN DUR — la dette à payer avant de brancher l'IA :**

| ce qui est figé | où | ce qu'il faut |
| --- | --- | --- |
| « YOU'RE / BACK » | à l'appel de la robe texte | remonter jusqu'à `RewardPopup` : une entrée **`bigLines: [String]`** |
| « YOU / MADE / IT » | valeur par défaut de `TexteGeant` | idem — la valeur par défaut ne doit servir qu'au banc |
| « Claim », « Later », « Close » | les boutons | des entrées **`actionLabel` / `dismissLabel`** |
| les stickers (flamme noire, pastille-lune, chauve-souris) | codés par robe | une entrée **`sticker:`** le jour où l'IA choisit l'objet montré |
| les bribes de la matrice (`24KG`, `+20`, `17KMH`…) | liste figée dans `TrameMatrice` | elles doivent venir des **vrais faits** de la séance (§3) |

**LA LOI, elle, ne change pas** : l'IA fournit les MOTS et le variant ;
les tailles, graisses, couleurs, espacements, halos et animations
restent au Design System. Une robe déclare sa **longueur maximale** par
ligne ; au-delà le client TRONQUE, il ne rétrécit jamais.

### Le contrat par CATÉGORIE (quand elles arriveront)

Chaque catégorie du plan (Moment, Reward, Rare, Welcome Back) déclare :
1. **les robes autorisées** (toutes ne conviennent pas : une pièce noire
   ne se raconte pas sur la robe galet) ;
2. **les champs attendus** (un Reward a un montant, un Moment n'en a
   pas ; un Welcome Back a un bouton d'action, un Moment n'a que Close) ;
3. **les vidéos autorisées** (§6) ;
4. **l'atmosphère par défaut** (§5) ;
5. **les longueurs maximales** de ses textes.

C'est ce tableau — et lui seul — que l'IA reçoit : elle choisit DANS
ce que la catégorie permet, jamais en dehors. Le jour où une catégorie
naît, on ajoute une ligne au tableau : aucune UI à toucher.

### Les données personnelles pour l'IA (question du 25-08 : poids, taille, âge ?)

Doctrine : **v1 SANS données corporelles.** Ce qui rend la narration
précise et cohérente, ce n'est pas le corps, c'est l'HISTORIQUE (les
fenêtres 14 j / semaine / record) et l'OBJECTIF déclaré — les faits
comparatifs suffisent à tout le plan produit. Ensuite, en v2, un
**profil optionnel** apporte trois choses réelles :

1. **Poids de corps** → les charges RELATIVES (« 1,2 × votre poids » —
   le fait le plus premium de la muscu) et les estimations calories du
   cardio. Le plus utile des trois.
2. **Âge / taille** → seulement pour des normes (FC max théorique,
   IMC) — apport faible pour la narration ; à ne prendre que si un
   chantier santé les justifie.
3. **Objectif + niveau déclarés** (prise de masse / perte / débutant /
   confirmé) → le TON et le choix du fait à raconter. Gros apport,
   zéro sensibilité.

Règles dures : profil OPTIONNEL, stocké chez nous (RLS), et l'IA ne
reçoit JAMAIS les valeurs brutes dans chaque prompt — le fact engine
dérive des ratios (`charge/poids_corps`) et l'IA ne voit que le ratio,
comme n'importe quel autre fait. Les données corporelles sont des
données SANTÉ : elles n'entrent pas en clair dans un prompt tiers.

### 4 ter. LA STORY CARD `.story` — stickers de performance + analyse
### (ajouté le 26-08 par le chantier story v2, voir
### ../story/PLAN-STORY-V2-ENDED.md §6 sexies)

Le flow story post-séance se termine sur un CINQUIÈME variant de la
famille rewards : la **story card** (fond noir rewards, stickers
animés + poudre de diamant + texte géant derrière + analyse). Son
contrat :

**LES STICKERS SONT DES FAITS, PAS DES DÉCORS.** Chaque sticker de la
planche (`WoopSticker`, les PNG du calendrier) correspond à UNE
catégorie de performance :

| catégorie de la séance | sticker | statut |
| --- | --- | --- |
| haut du corps (muscu) | `bras` (le muscle) | tranché 26-08 |
| cardio | `basket` | tranché 26-08 |
| abdos | `chocolat` (la tablette) | tranché 26-08 |
| bas du corps | `jambes` (le short) | tranché 26-08 (tour 2) |
| piscine / nage | `piscine` (la goutte d'eau) | tranché 26-08 (tour 2) |
| fessiers | `abricot` | à confirmer |
| intensité / record / streak | `flamme` | à confirmer |

⚠️ `abricot` portait « bas du corps » jusqu'au 26-08 : le short lui a
pris la place (verdict Kathryn), l'abricot redescend sur les fessiers —
la catégorie que le calendrier lui donnait déjà. La goutte d'eau entre
avec l'exercice `piscine` du catalogue (`.cardio`, `.steady`,
`poids du corps`) : la nage est un cardio, mais elle a SON sticker, pas
la basket du tapis.

Le fact engine (§3) calcule les VOLUMES PAR CATÉGORIE de la séance
(séries × charge par groupe, minutes cardio) ; les **deux catégories
dominantes** donnent les deux stickers. Le moteur choisit DANS la
planche — l'IA ne choisit JAMAIS un sticker librement, elle reçoit
les deux déjà tranchés (même doctrine que les nombres : recopiés des
faits, jamais inventés).

**LE PAYLOAD `.story`** (mêmes lois que le §4 : enums, bornes,
gabarits de secours) — **amendé le 26-08 (tour 5)** :

```
{ stickers: [bras|basket|chocolat|jambes|piscine|abricot|flamme]
            (2 ou 3),
  bigWord: "KING" | "BOSS" | "SOLID" | … — 3 à 6 LETTRES, choisi
           par TABLE de tiers de performance (volume / PR /
           densité → tier → mot), jamais un choix libre,
  lines: [ { words: [{text, gris: bool}] } ] — EXACTEMENT 6 LIGNES
         (verdict Kathryn : « l'IA devra respecter 6 phrases »),
         ≤ 20 signes par ligne, drapeaux gris PAR MOT }
```

**LES PHRASES SONT VRAIES** (verdict 26-08) : elles citent LE NOM
DU CATALOGUE (`ExerciseCatalog`, tronqué au contrat) et LA
PERFORMANCE (« 28 kg on bench », jamais « you did great »). Les
faits v1 se calculent EN LOCAL du `StorySession` (meilleure série
exo+charge, groupe dominant, volume total, densité, série la plus
longue) — le fact engine serveur (§3) les remplacera avec ses
fenêtres comparatives. **Une famille de gabarits de 6 lignes par
catégorie dominante** (haut du corps / cardio / abdos / bas du
corps / piscine / fessiers) à trous typés, ex. :
`["Big push day.", "{kg} kg on", "{exo_court},", "your best set.",
"{series} sets in {min} min.", "Keep pressing."]` — les nombres
RECOPIÉS des faits (la loi du §4). L'IA, quand elle arrive,
remplit LE MÊME MOULE : 6 lignes, la borne de signes, les drapeaux
gris — jamais une forme neuve.

Tailles, graisses, halo spotlight, poudre, animations des stickers :
au Design System, JAMAIS à l'IA (la loi du §4 ne bouge pas).

**LE MOMENT DU CALCUL** : la story se regarde APRÈS Terminer (ou
depuis le calendrier, des jours plus tard) — le budget latence n'est
pas celui du repos. Le payload `.story` se génère AU RÈGLEMENT
(`settle_session` → `narrate-reward` en asynchrone → stocké avec la
séance) ; l'app le LIT, elle ne l'attend jamais. Pas de réponse
stockée → gabarit déterministe (stickers des faits + bigWord par
table + lignes gabarit).

### 4 quater. LE VARIANT « TOP SESSION » — l'exception qui s'annonce
### (ajouté le 26-08 au soir, brief Kathryn — le plan design est
### ../rewards/PLAN-TOP-SESSION.md)

Un NOUVEAU variant de `RewardPopup`, ET la première page de la story
les jours d'exception : le layout Welcome v2 (texte géant +
pastille) SANS la chauve-souris, la pastille portant LA PAILLETTE DU
SPORT — `basket` (top cardio) ou `haltère` (top muscu) — le texte
géant en ROUGE animé, un halo de page rouge/blanc pur, une pills
énorme derrière, et une mini-card à NÉON VERT qui dépasse de la
card avec LA stat qui justifie l'exception.

**Le contrat** :

```
{ style: top, sport: cardio | muscu,
  bigLines: [2 lignes, 3-9 signes]     — table de candidats §4 du
                                          plan design, IA plus tard,
  sousTexte: ≤ 40 signes               — la phrase du fait, VRAIE,
  stat: { value, unit, label } (mini-card) — RECOPIÉE d'un fait,
                                             jamais reformulée }
```

**Le déclencheur (moteur §2, jamais le client, jamais l'IA)** : le
fait « MEILLEURE SÉANCE DE LA SEMAINE » par catégorie — muscu :
volume max 7 j ; cardio : minutes ou densité max 7 j. Rare par
construction (au plus 1/semaine/catégorie) ; priorité au-dessus de
Reward, sous Rare ; en STORY il ne consomme pas le budget pop-ups
(c'est une page, pas une interruption) ; en POP-REWARD il compte
comme Reward et respecte tous les cooldowns.

**Deux assets à détourer** (fond noir, PAS d'alpha — le pipeline
PLAN-WELCOME-V2-DETOURAGE se rejoue) : `~/Desktop/paillete_basket.png`
(1254×1254) et `~/Desktop/pailette_haltère.png` (1403×1121).

### 4 quinquies. LA STORY V2 EST LA STORY (verdict 26-08 : « on
### remplace l'ancienne par cette story »)

L'ancienne story (lune néon, `StoryOne`/`StoryTwo`/`StoryThree` et
leurs quatre mp4) est SUPPRIMÉE du dépôt. La story canonique est le
flow v2 — trois pages, quatre les jours d'exception — et voici CE
QUE LE BACKEND LUI DOIT, page par page, calculé AU RÈGLEMENT
(`settle_session`) et STOCKÉ avec la séance (l'app LIT, elle
n'attend jamais) :

| page | ce que le backend fournit |
| --- | --- |
| SESSION ENDED (verrière + résumé) | les agrégats de séance : minutes, séries, exos, kcal (le calcul de dépense remplacera l'estimation minutes × 7) |
| TOP SESSION (exception, à la place du résumé sur la page 0 — le résumé émigre en page 2) | le fait « meilleure séance de la semaine » par catégorie (§4 quater) + LA stat de la mini-card (minutes ou volume, RECOPIÉE) |
| DÉTAILS | rien de neuf : la partition vient des séries persistées |
| STORY CARD (analyse) | le payload `.story` du §4 ter : 2-3 stickers par catégories dominantes, `bigWord` par table de tiers, 6 lignes vraies |

Gabarits déterministes de secours pour TOUT (déjà codés côté app) —
l'IA est une couche qui se pose après, le moule ne change pas.

### 4 sexies. LA PAGE « WIN » ET LA RÈGLE DES BOOSTERS (ajouté le
### 26-08 nuit — le plan design est ../story/PLAN-STORY-WIN.md)

La story gagne une 4ᵉ page de base : LE BUTIN — la pièce du coffre
en header, « WIN » derrière, le compteur de pièces qui roule, et
UN BOOSTER PLAQUÉ à chaque 100 pièces. La règle :

- **1 booster = 100 pièces, conversion CUMULÉE avec report** : au
  `settle_session`, `booster_progress` (0-99, par user) + pièces de
  la séance → `n` boosters crédités + nouveau report. Rien ne se
  perd à l'arrondi. Crédit idempotent par `session_uuid` (la story
  rejouée ne recrédite JAMAIS) — la réserve rejoint le pipeline
  Sacre existant (`claim_booster` inchangé pour l'OUVERTURE).
- **« Vu = pris en compte »** : l'affichage n'accorde rien — le
  crédit est déjà au ledger. Il ENREGISTRE (`reward_events`, kind
  `booster_grant_shown`) pour ne jamais remontrer la cérémonie.
- **Le PROFIL montre le solde ouvrable** : boosters crédités −
  boosters ouverts (solde dérivé, jamais une colonne à la main).
- **Le front recopie** : la page WIN montre les pièces RÉELLES de
  la séance (séries × 20 aujourd'hui, le ledger demain) et les
  boosters DE LA SÉANCE ; le profil montre le TOTAL.

```sql
-- l'état de conversion, par user :
create table booster_progress (
  user_id uuid primary key references auth.users (id) on delete cascade,
  reste int not null default 0 check (reste between 0 and 99),
  updated_at timestamptz not null default now()
);
-- le crédit au settle : n lignes de réserve booster
-- (la table des boosters du Sacre, origine = 'pieces'),
-- clé d'idempotence (user_id, session_uuid, 'booster_conversion').
```

### 4 septies. LE VARIANT « ×2 » — deux séances le même jour (ajouté
### le 27-08 nuit — le plan design est ../rewards/PLAN-VARIANT-X2.md)

Un NOUVEAU variant d'exception, frère de TOP SESSION (§4 quater) :
quand l'utilisateur va DEUX FOIS à la salle le même jour, la story de
la deuxième séance ouvre sur la page « ×2 » (pastille ×2, univers
dark/white, fumée rouge/noir/blanc, halo noir/rouge/orange), et le
calendrier pose le sticker `fois2` AVEC les autres stickers du jour.

**Le contrat** :

```
{ style: double,
  sessions: [ { session_uuid, started_at (local), minutes,
                categorie } × 2 ]          — les DEUX séances du jour,
                                             RECOPIÉES (la mini-card
                                             montre leurs heures),
  bigLines: [2 lignes, 3-9 signes]         — table §5 du plan design,
  sousTexte: ≤ 40 signes                   — « Two sessions today. »,
  stat: { value, unit, label }             — total minutes du jour,
                                             ou les deux heures (Q4) }
```

**Le déclencheur (moteur §2, jamais le client, jamais l'IA)** : le
fait « DEUXIÈME SÉANCE VALIDE RÉGLÉE LE MÊME JOUR LOCAL ». Le jour est
celui de l'UTILISATEUR — la timezone du device part avec le
`settle_session` (nouveau champ `tz`), jamais UTC (une séance à 23 h
et une à 1 h ne font pas un ×2, deux séances à 7 h et 19 h en font
un). « Valide » = le seuil de séance du streak (Q5 du plan design).
S'allume UNE fois par jour, au 2ᵉ settle ; un 3ᵉ settle ne rallume
rien (Q2). Priorité : au-dessus de Reward, au niveau de TOP ; si TOP
et ×2 tombent le même jour, les deux pages existent (ordre : Q3). En
STORY il ne consomme pas le budget pop-ups (une page) ; en
POP-REWARD (`RewardStyle.double`, à coder avec `.top`) il compte
comme Reward et respecte les cooldowns.

**Le sticker `fois2` est un FAIT dérivé, pas un état** : `count(
séances valides du jour local) ≥ 2` — calculé à la lecture (le
calendrier groupe déjà par jour), rétroactif de fait, AUCUNE table
catalogue ni migration (mémoire Supabase : ajouter un sticker ne
demande rien au schéma). Idempotence : le fait est une fonction des
séances, il n'a pas de ledger propre ; l'AFFICHAGE de la page ×2
s'enregistre (`reward_events`, kind `double_shown`, clé
`(user_id, jour_local)`) pour ne jamais remontrer la cérémonie.

**Deux assets à détourer** (RGB, pas d'alpha) :
`~/Desktop/PAILETE_FOIS_2.png` (1254², fond noir — recette squircle
analytique de `detoure_pastilles_top.py`) et `~/Desktop/
STICKER_FOIS_2.png` (1254², fond BLANC + ombre portée — recette
NOUVELLE « cœur + couronne analytique », le liseré n'étant pas
séparable du fond par la luminance : mesuré).

### 4 octies. LA STORY, TOUS SES VARIANTS ET LEUR ORDRE (ajouté le
### 27-08 sur le verdict de Kathryn — la loi de composition)

Verbatim : « si cardio de fou ou muscu de fou pendant la semaine ⇒ on
affiche en premier le rewards muscu ou cardio (si la DEUXIÈME séance
est la meilleure, on affiche avant la card fois 2) puis le reste
jusqu'au booster ⇒ booster apparaît SYSTÉMATIQUEMENT ».

#### La table des pages (l'état au 27-08)

| # | page | quand | contrat backend | l'IA complète |
| --- | --- | --- | --- | --- |
| 0a | **SESSION ENDED** (verrière + résumé) | TOUJOURS, sauf si une exception prend l'ouverture | agrégats : minutes, séries, exos, kcal | non (des nombres) |
| 0b | **TOP SESSION** (`style: top`, §4 quater) | fait « meilleure séance de la semaine » (cardio ou muscu) | `{sport, bigLines, sousTexte, stat}` | OUI : `bigLines` + `sousTexte` (gabarit déterministe d'abord) |
| 0c | **×2** (`style: double`, §4 septies) | 2ᵉ séance valide du même jour LOCAL | `{sessions × 2, bigLines, sousTexte, stat}` | OUI : `bigLines` + `sousTexte` |
| 1 | **RÉSUMÉ** (page à lui) | seulement si une exception a pris l'ouverture | les mêmes agrégats | non |
| 2 | **DÉTAILS** (partition) | TOUJOURS | rien de neuf (les séries persistées) | non |
| 3 | **STORY CARD** (`.story`, §4 ter) | TOUJOURS | 2-3 stickers, `bigWord`, 6 lignes VRAIES | OUI : les 6 lignes + le `bigWord` |
| 4 | **WIN — le butin** (§4 sexies) | **TOUJOURS — systématique** | pièces de la séance, boosters crédités, report | OUI (facultatif) : la couronne (« Big win. ») |

#### L'ORDRE, la loi

1. **L'ouverture appartient à l'exception**, quand il y en a une —
   c'est le wahou, il ne se mérite pas deux fois : la page
   d'exception REMPLACE l'acte B de SESSION ENDED, et le résumé
   émigre en page 1.
2. **Entre deux exceptions le même jour** : TOP passe d'abord (le
   fait de la SEMAINE prime) — **SAUF si c'est la deuxième séance du
   jour qui EST la meilleure de la semaine** : alors ×2 s'affiche
   AVANT TOP (la nouvelle prime sur le palmarès : c'est la séance
   qu'on vient de finir qui a tout fait). Les deux pages existent,
   dans cet ordre ; le résumé les suit.
3. **Puis le reste, toujours dans le même ordre** : Résumé (s'il a
   émigré) → Détails → Story card.
4. **WIN FERME TOUJOURS LA STORY** — le butin est systématique, même
   à 0 booster (la couronne dit alors « Steady grind. »). Une story
   ne se termine jamais sans dire ce qu'elle a rapporté.

Donc : 4 pages ordinaires, 5 avec une exception, **6 avec les deux**.
Le moteur ne rend qu'une LISTE de rôles ordonnée — le client ne
décide de rien, il monte ce qu'on lui donne.

#### Ce que l'IA a le droit de faire (le wahou dans le cadre)

L'IA COMPLÈTE, elle ne décide pas : le déclencheur, les nombres et
l'ordre sont au moteur. Elle écrit les MOTS, dans le moule (§5, « le
contrat Design System ») : `bigLines` 2 × 3-9 signes, `sousTexte`
≤ 40 signes, les 6 lignes de la story card. Toujours un gabarit
déterministe derrière (l'app ne l'attend jamais — calculé au settle,
stocké avec la séance). Un mot qui ne rentre pas dans le gabarit est
REJETÉ, pas tronqué : la mise en page est un fait, pas une négociation.

### 4 nonies. LES ROBES — deux variants de plus, et qui choisit
### (ajouté le 27-08 ; les plans design sont ../story/PLAN-STORY-CARD-
### COLONNE.md et ../story/PLAN-WIN-RENVERSE.md)

Deux pages de la story gagnent un DEUXIÈME habillage. Ce ne sont pas
de nouveaux faits, pas de nouveaux contrats : **le payload ne change
pas d'un signe** — c'est la même donnée, portée autrement.

```
robes:
  story_card: rangee | colonne
  butin:      poche  | renverse
```

- **story card `.colonne`** : les stickers passent en COLONNE sur le
  flanc gauche et deviennent SAISISSABLES (on les prend dans la
  main, ils reviennent à leur place), le texte s'ancre en bas et
  ÉMERGE de la nuit, le mot géant descend derrière. Payload `.story`
  du §4 ter inchangé — une seule attention pour l'IA : dans cette
  robe la DERNIÈRE des six lignes est la seule qui reste pleinement
  lumineuse (c'est la chute), le gabarit doit continuer d'y mettre
  l'impératif, jamais un chiffre.
- **butin `.renverse`** : les boosters PENDENT au bord haut et
  tombent du ciel, la pièce et le mot se posent au sol (traîne et
  gravure inversées), le mot change de métal et le filament change
  de couleur. Règle des boosters du §4 sexies inchangée.

**QUI CHOISIT — le moteur, jamais le client.** La robe est calculée
au `settle_session` et STOCKÉE avec la séance, comme le reste. Deux
exigences :

1. **elle est STABLE pour une séance donnée** — la story rejouée
   montre la même robe ; une robe qui change à la relecture se lit
   comme un bug, pas comme une surprise ;
2. **elle ne dépend jamais de l'appareil** (ni horloge locale, ni
   aléa client) : un hash du `session_uuid`, une alternance
   persistée, ou un FAIT.

Règle de choix à trancher par Kathryn (Q5 des deux plans) :
alternance stricte, tirage stable par hash, ou un fait — par exemple
le butin `.renverse` les jours où la séance rapporte ≥ 3 boosters
(le ciel s'ouvre quand il y a beaucoup à donner), et la story card
`.colonne` quand la séance porte 3 stickers pleins.

L'IA n'entre pas ici : **une robe n'est pas un mot.** Elle écrit ce
qui se lit, jamais ce qui se montre.

---

## 5. Le contrat Design System — CE QU'ELLE A LE DROIT

Le socle est acquis et vivant dans l'app : les TROIS variants de
`RewardPopup` (`.halo` réf Apple, `.neon` réf WWDC — la robe brume
diluée, TRANCHÉE, ne pas re-« réaliser » —, `.galet` verre saisissable),
plus un QUATRIÈME à créer : **`.spotlight`** (réf « 300 TPS » du 25-08 :
la lampe suspendue visible, son cône sur un chiffre de MÉTAL SOMBRE en
relief, l'unité dans une petite pill de verre posée sur le chiffre —
détail dans [CHANTIERS-UX.md](CHANTIERS-UX.md) §4). La grammaire
BoosterPopup (le noir AU-DESSUS du verre), la poudre, les sons
(tick/arpège), le boum haptique, l'entrée en fondu noir.

Atmosphères (des TOKENS, pas des styles libres) :

| token        | matière                                | usage               |
| ------------ | -------------------------------------- | ------------------- |
| NEUTRAL      | halo blanc froid                       | info, stats         |
| EFFORT       | rouge/orange, nuit profonde            | HIIT, intensité     |
| PERFORMANCE  | orange dense + poussières              | record, progression |
| REWARD       | noir + lumière chaude + vidéo          | bonus pièces        |
| RARE         | quasi noir, vidéo pièce noire          | exceptionnel        |

⚠️ La loi anti-brun de la maison s'applique aux atmosphères chaudes
(« R reste à 1,00, on désature le VERT », la saturation TIENT) — EFFORT
et PERFORMANCE se calent sur le feu de la page exo, pas sur un orange
neuf.

---

## 6. Les vidéos — la bibliothèque et ses vérités mesurées

Sondées le 25-08 (elles existent TOUTES sous les noms du plan) :

| fichier                            | mesuré                       |
| ---------------------------------- | ---------------------------- |
| chauve_sourie_pièce_rewads_1.mp4   | HEVC 4K paysage, 9,0 s, 17 Mo |
| chauve_sourie_pièce_rewads_2.mp4   | HEVC 4K paysage, 8,0 s, 15 Mo |
| chauve_sourie_pièce_rewads_3.mp4   | HEVC 4K paysage, 7,0 s, 14 Mo |
| chauve_sourie_pièce_rewads_4.mp4   | HEVC 4K paysage, 6,0 s, 9,3 Mo (reçue le 25-08 soir) |
| chauve_sourie_fire.mp4             | HEVC 4K paysage, 7,0 s, 6 Mo  |
| chauve_sourie_go_to_lune.mp4       | HEVC 4K paysage, 7,0 s, 2,3 Mo|
| chauve_sourie_pièce_noire_rare.mp4 | HEVC 4K paysage, 8,0 s, 12 Mo |
| chauve_welcome_back.mp4            | HEVC 4K **PORTRAIT**, 7,0 s, 14 Mo |

Conséquences dures :

1. **Recuisson obligatoire** (~90 Mo bruts) : 4K → 1080, cible < 1 Mo
   pièce (la recette booster-loop : 4,5 Mo → 705 Ko). Pas de boucle à
   coudre ici (lecture unique) — mais l'exposition à plat reste utile.
2. **7-9 s c'est LONG en pleine séance.** Deux coupes par vidéo à la
   recuisson : une version COURTE 2,5-4 s (Reward en cours de séance)
   et la pleine longueur (Rare, Welcome Back, post-séance). Piège
   ffmpeg payé : `-ss` ne coupe pas le graphe — trim + setpts DANS le
   graphe.
3. **`chauve_welcome_back` est PORTRAIT** : son intégration header n'est
   pas celle des paysages — layout dédié.
4. **Le contenu doit être VU avant d'être branché** — la leçon « les
   noms des vidéos Downloads MENTENT » : extraire dernière frame + une
   frame médiane de chacune au banc, vérifier que la dernière frame est
   STABLE et sombre (le « stop dernière frame → fondu noir permanent »
   en dépend).
5. Pièges déjà payés qui s'appliquent : HEVC/H.264 **sans alpha** (le
   fond noir se fond dans la pop-up noire — c'est le design, pas un
   problème) ; `clipsToBounds + masksToBounds` côté UIKit ; le slot
   vidéo de `RewardPopup` est la couche halo/âme, prévu dès le début ;
   `AVPlayerLayer` ne coûte rien, c'est le Canvas et le verre qui
   coûtent (mesure SondeCadence du 18-08).

### LA RECUISSON EST FAITE (25-08 soir) — et le MODE DÉMO

Les 9 vidéos sont recuites dans `Woop/Media` (1080, H.264, muettes,
0,3-2 Mo pièce, dernières frames TOUTES vérifiées stables et sombres —
`reward-fire` meurt même sur du noir pur, fondu idéal) :
`reward-piece-1…5`, `reward-fire`, `reward-lune`, `reward-rare`,
`reward-welcome` (portrait). `chauve_sourie_pièce_rewads_5.mp4` reçue
le 25-08 soir (4K paysage 5,0 s) est la 5ᵉ de la famille.

**LE MODE DÉMO (à prendre en compte partout)** : une fois le flow
end-to-end branché (l'autre session le prépare), Kathryn enchaînera de
VRAIES séances — jusqu'à ~30 séries — pour VOIR tous les variants dans
sa page exo. Donc : un preset `reward_rules` **« demo »** qui délie les
plafonds (budget pop-ups ∞, cooldowns ~0, rotation forcée des styles et
des vidéos, pièce noire déclenchable) — activé par un drapeau de
lancement, JAMAIS le preset par défaut. L'API du composant est prête :
`RewardPopup(style:videoNom:)` se pilote de l'extérieur.

### En produire PLUS ? (question du 25-08)

**Pas pour lancer — oui pour durer.** La rareté fait le premium : 7
vidéos suffisent à ouvrir tout le système, et une vidéo vue partout
cesse d'être un événement. MAIS la famille Reward pièce (la plus
fréquente : jusqu'à ~1 vue/séance) tournera sur 3 variantes — l'usure
arrivera en quelques semaines. Donc, quand Kathryn en produit :

- **priorité 1** : +2 ou 3 variantes de la famille Reward pièce (la
  rotation) ;
- **priorité 2** : 1 alternative ON FIRE et 1 « palier/chapitre » pour
  le chemin (go_to_lune tient le rôle seul aujourd'hui) ;
- **priorité 3** : une déclinaison RARE (la pièce noire mérite de ne
  jamais montrer deux fois la même scène).

**Le cahier de tournage** (pour que tout s'intègre sans retouche) :
fond noir VRAI (pas gris foncé — il se fond dans la pop-up), dernière
frame STABLE et sombre (le stop-dernière-frame en dépend), une VERSION
COURTE 2,5-4 s pensée AU TOURNAGE (pas une coupe de sauvetage), sujet
dans les deux tiers hauts (le tiers bas se fond dans le corps), paysage
16:9 4K (portrait réservé aux familles plein écran type Welcome Back),
24 fps ok, pas d'audio nécessaire (la maison sonne déjà :
tick/arpège/boum).

---

## 7. Schémas — ce qui s'AJOUTE au pipeline Sacre

Esquisses (à écrire avec Kathryn, comme le Sacre) :

```sql
-- coin_ledger EXISTANT, deux ajouts :
alter table coin_ledger add column currency text not null default 'yellow'
  check (currency in ('yellow','black'));
alter table coin_ledger add column session_uuid uuid;
alter table coin_ledger add column serie_index int;
-- idempotence fine (les gains par série + les bonus) :
create unique index coin_ledger_evenement_unique
  on coin_ledger (user_id, session_uuid, serie_index, raison)
  where session_uuid is not null;

-- le journal des mises en scène (ce qui a été MONTRÉ, pour les
-- cooldowns, l'anti-répétition et le debug de l'IA) :
create table reward_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  session_uuid uuid,
  kind text not null check (kind in
    ('pill','moment','reward','rare','welcome_back')),
  fact_kind text, variant text, atmosphere text, video text,
  montant int default 0, currency text default 'yellow',
  shown_at timestamptz not null default now()
);

-- la configuration vivante du moteur (§2) :
create table reward_rules ( key text primary key, value jsonb not null );

-- welcome back : l'état par user (le temps SERVEUR fait foi —
-- l'horloge client est truquable) :
create table welcome_state (
  user_id uuid primary key references auth.users (id) on delete cascade,
  last_seen_at timestamptz not null default now(),
  last_welcome_at timestamptz,
  claims_count int not null default 0
);
```

RPCs : `settle_session(...)` (§1), `roll_rare(...)` (RNG serveur + pity,
appelée PAR settle, jamais par le client), `claim_welcome()` (vérifie
absence + cooldown serveur, crédite, idempotente),
`claim_booster_legendaire()` (débite 1 `black`, réserve un booster
`origine='legendaire'` — la garde `claim_booster` réutilisée telle
quelle ; nécessite que le pool légendaire de `forge-card` soit
adressable directement).

---

## 8. Anti-abus — parce que les données sont DÉCLARÉES

Les poids/reps sont saisis par l'utilisateur : un « PR » se fabrique en
tapant 28 au lieu de 24. Doctrine :

- Les **Moments** (non monétaires) peuvent être généreux — mentir ne
  rapporte que de la mise en scène.
- Les **Rewards monétaires** sont bornés : budget de bonus par séance
  (ex. ≤ 60 pièces bonus), cooldown par type de fait, et jamais
  déclenchés deux fois par la même comparaison dans la fenêtre.
- La **pièce noire** ne dépend d'AUCUNE performance déclarée : RNG
  serveur pur (pity + cooldown) — le seul événement infalsifiable.
- Welcome Back : temps serveur, cooldown, plafond de claims.

---

## 9. À TRANCHER par Kathryn (bloquants, dans l'ordre)

1. **La mort de BRAVO.** Le plan la prononce (« la page Bravo disparaît
   complètement ») — or BRAVO est commitée, aimée, et l'envol fin de
   repos (7495c85) pointe vers elle. La retirer du flux par défaut :
   oui ; la recycler comme UNE mise en scène de Moment « fin d'exo »,
   ou la tuer tout à fait ?
2. **Les montants** : bonus performance (+40 ? +30 ?), plafond par
   séance, valeur d'échange de la pièce noire (1 noire = 1 légendaire
   direct — confirme), et le prix du booster jaune du Sacre reste-t-il
   cohérent avec l'inflation des bonus ?
3. ~~La rareté réelle~~ — **TRANCHÉ le 25-08 par délégation** (« fais
   une probabilité, je te laisse faire ») : les nombres de départ sont
   au §2, dans `reward_rules`, modifiables sans redéployer.
4. **Moment ET pill, ou Moment À LA PLACE de la pill ?** Doctrine
   proposée : la pill +20 TOUJOURS (la loi des 20 est sacrée), le
   Moment par-dessus quand il y a un fait — à confirmer.
5. **La langue** : EN partout, ou FR/EN localisé dès v1 ?
6. **L'IA v1** : vrais appels `narrate-reward` dès le départ, ou
   gabarits déterministes d'abord (le moteur §2 + faits §3 suffisent à
   faire vivre tout le système sans IA) ? — recommandation : gabarits
   d'abord, l'IA est une couche qui se pose après, le JSON est le même.

---

## 10. Jalons (le design d'abord, le backend après — comme le plan)

- **J0 — mocks UI, zéro backend** : les pills du header (états +20 /
  pièce animée / total), les 3 variants acceptant titre/sous-titre/
  mini-stat/halo variable, le slot vidéo (fondu noir, stop dernière
  frame), les 5 atmosphères, un banc `-rewardScenarios` qui rejoue les
  9 scénarios types du plan (série banale → pièce noire) en dur.
- **J1 — recuisson vidéos** + vérité des contenus (frames extraites).
- **J2 — l'outbox local** + le moteur de décision en local (règles en
  dur), pills et pop-ups branchées sur la vraie séance.
- **J3 — Supabase avec Kathryn** : migration ledger (currency,
  session_uuid), `settle_session`, `reward_events`, `reward_rules`,
  migration de richesse.
- **J4 — rareté serveur** : `roll_rare`, pity, pièce noire de bout en
  bout + `claim_booster_legendaire`.
- **J5 — Welcome Back** (état serveur + claim + les deux variantes).
- **J6 — l'IA** : `narrate-reward`, gabarits de secours, log rejouable.
