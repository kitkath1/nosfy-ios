# LE BACK-END DES REWARDS — gamification contextuelle

**Écrit le 25-08-2026, sur le plan produit de Kathryn (« Gamification
contextuelle — Pills, Moments, Rewards, vidéos et IA »).** Ce document ne
remplace rien : il s'ajoute à [../sacre/SUPABASE-PIPELINE.md] (les
boosters, le ledger, les familles) et ne couvre QUE les rewards. Rien
n'est codé ; c'est la doctrine à trancher puis à construire.

> **RÈGLE ABSOLUE (héritée du Sacre)** — rien ne se fait sur Supabase
> sans Kathryn. CLI, jamais le MCP (le MCP de session pointe AxioSense).

> **MISE À JOUR DU 30-08.** Kathryn a tranché le coffre et les annonces
> (ses mots, les dix questions, le contrat par catégorie, les jalons) dans
> [../annonces/PLAN-COFFRE-ANNONCES.md](../annonces/PLAN-COFFRE-ANNONCES.md).
> Ce document reste le plan-mère : les paragraphes qu'elle contredit sont
> marqués **« périmé »** avec la date et le commit, et le nouvel état est
> écrit à côté — rien n'est effacé. Ce qui est dit du code a été relu le
> 30-08 (`fichier:ligne`) ; les numéros de `WoopApp.swift` bougent, une
> autre session l'édite.

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

- **Budget de séance** : max N pop-ups par séance — **tranché le 30-08 :
  4 pop-ups, dont ≤ 1 Reward monétaire, ≤ 1 vidéo, et 6 dalles hors
  budget** (une dalle ne consomme pas le budget, `notif_consomme_budget
  = false`) — rechargé par séance.
- **Écart minimal** : jamais deux pop-ups à moins de K séries / M
  minutes — ~~défaut 3 séries ou 6 min~~ → **tranché le 30-08 : 3 séries
  ET 6 min** (`ecart_exige_les_deux = true`, Q5), et l'écart **ne
  s'applique qu'aux rangs tirés au hasard** — pas aux rangs fixes
  ci-dessous (Q1 du plan coffre-annonces, défaut accepté).
- **File de priorité** : Rare > Reward > Moment. Un fait « notable »
  qui arrive pendant un cooldown est ABANDONNÉ ou rétrogradé en pill
  enrichie (`+20 · meilleure série`) — jamais mis en file d'attente
  pour tomber mécaniquement plus tard.
- ~~**Interdiction des positions fixes** : aucun déclencheur du type
  « série 5/10/15 » ; les triggers sont des FAITS (fin d'exo, PR,
  volume, densité), pas des compteurs.~~ **PÉRIMÉ — tranché le 30-08
  dans l'autre sens** (plan coffre-annonces §0, §1 Q1-Q2, §3) : **des
  rangs FIXES 3 / 5 / 10, puis un rang au hasard toutes les 5 à 8
  séries** (15±, 21±…), la vidéo une seule fois au rang 10, le tout sous
  le budget 4 / 1 / 1 / 6 et l'écart 3 séries ET 6 min pour les rangs
  tirés. Le hasard est **déterministe par séance** (`hash(workout_id,
  rang)`) et les rangs vivent dans `reward_rules` (M2 : `popup_rangs_fixes`,
  `popup_rang_video`, `popup_hasard_ecart_min/max`, `popup_hasard_apres`).
  Les FAITS ne décident plus du QUAND — ils nourrissent le QUOI (§3, §4) :
  au rang venu, l'IA choisit de quel fait parler. **Ce que le code fait
  au 30-08** (relu) : `DecideurSerie.pour` (`RestartSheet.swift:608-630`)
  sert **tous les multiples** de 3 et de 5 (3, 5, 6, 9, 10, 12, 15…) —
  sans hasard, sans budget, sans horloge, sans serveur ; c'est le J4 du
  plan coffre-annonces qui le remplace.
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
| Welcome Back                            | ~~absence ≥ 4 jours, cooldown 14 jours, max 2/mois, claim +20~~ → **périmé** : **0 jour d'absence, 0 jour de pause, 31 / mois (= une par jour), claim +10** — en base depuis `20260830090000_welcome_chaque_connexion.sql` (`welcome_absence_jours` 0 · `welcome_cooldown_jours` 0 · `welcome_max_mois` 31) et `pieces_retour_quotidien` = 10 (`gains_coffre.sql:98`, tranché le 28-08). Le jour est celui de **Paris** (30-08, §4 duodecies) |
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
  **Précisé le 30-08** (plan coffre-annonces §0, §5.2.8) : la réponse
  préparée à la série N sert **la PROCHAINE pop-up** (N+1) — on ne
  l'attend jamais, pas même le temps du repos ; ce qui est prêt se lit,
  sinon le gabarit. Borne serveur 10 s (`AbortController`), `ms` mesuré
  dans la réponse (E1).
- **Langue : ANGLAIS** (le parcours est passé EN, commit 9603dc8). Les
  exemples FR du plan produit sont des maquettes, pas des chaînes.
- **Où elle tourne** : edge function `narrate-reward` (même famille que
  `forge-card`), qui logge `{facts_in, json_out}` pour rejouabilité.
  ⚠️ **Elle n'existe pas au 30-08** — sondé : `functions list` →
  `forge-card` seule, `POST /functions/v1/narrate-reward` → 404. C'est
  l'E1 du plan coffre-annonces (J5, en dernier).
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

### ⚠️ LA CARD MATRICE A **DEUX** RENDUS DU MÊME NOMBRE (27-08)

Verdict de Kathryn : *« on est d'accord, il y a deux 4 ! donc pour l'IA
il faudra adapter les 2, chiffre et texte du haut »*.

Sur cette robe, `count` sort **deux fois**, sous deux formes :

| Où | Forme | Composant |
| --- | --- | --- |
| le texte géant du header | **le nombre EN TOUTES LETTRES** (`FOUR`) | `TexteGeant(lignes:)` |
| le chiffre au centre | **le chiffre** (`4`), en verre | `VerreQuatre` + `ChiffreMatrice` |

**La règle qui en découle : UNE seule donnée, DEUX rendus.** L'IA (ou le
backend) n'envoie jamais deux valeurs qui pourraient diverger — elle
envoie `count`, et le client en dérive les deux écritures.
`RewardScene.enLettres(_:)` fait déjà la conversion **côté app**, et
c'est sa place : mettre un nombre en lettres est de la mise en forme
d'une donnée, donc du Design System — même loi que le corps de la typo.

⚠️ Deux dettes qui sortent de là :
1. `enLettres` s'arrête à douze. Au-delà elle rend les chiffres — à
   étendre, ou à borner par contrat (une card qui annonce « 14 » a
   peut-être un autre message à porter).
2. **La langue.** Le jour où l'app parle français, `FOUR` doit devenir
   `QUATRE` : la table est côté client, donc localisable — mais elle
   n'est pas encore branchée sur la locale.

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

- **1 booster = 100 pièces** — ~~conversion CUMULÉE avec report : au
  `settle_session`, `booster_progress` (0-99, par user) + pièces de la
  séance → `n` boosters crédités + nouveau report~~ → **périmé, tranché
  le 30-08 : la conversion est automatique et DÉRIVÉE, sans report
  stocké** (plan coffre-annonces §0 « la jauge », §4 M1.3-4). À 100
  pièces **un sachet apparaît tout seul** et **les pièces retombent** ;
  `convertir_pieces()` (privée) tourne à la fin de `cloturer_seance`,
  `claim_retour_quotidien` et `tirer_noeud_chemin` : tant que
  `solde_or() ≥ prix_booster`, une ligne `-prix` raison
  `conversion_booster` (dans le `check` depuis le 28-08, jamais écrite)
  + un `user_boosters` origine `conversion`, même transaction. Rien ne se
  perd à l'arrondi : le reste EST `solde_or % prix` — vrai par
  construction (solde < 100). **Le témoin d'idempotence est le solde
  lui-même** : un rejeu ne crédite rien, donc ne convertit rien.
  **`booster_progress` reste morte** — créée le 28-08, jamais écrite,
  plus lue depuis le 29-08 (`annonces.sql:30-48`, `reste` dérivé) ; on
  ne la réveille pas, un solde se dérive. Et ~~`claim_booster` inchangé
  pour l'OUVERTURE~~ : l'ouverture est `ouvrir_booster` ; `claim_booster`
  était l'**achat** à 100 pièces — avec la conversion le solde ne
  dépasse plus 99, l'achat ne peut plus réussir : **retiré de l'app et
  fonction fermée** (`revoke … from authenticated`, Q9 défaut, M1.8) ;
  « Ouvrir » ouvre un sachet qui existe déjà.
- **« Vu = pris en compte »** : l'affichage n'accorde rien — le
  crédit est déjà au ledger. Il ENREGISTRE (`reward_events`, kind
  `booster_grant_shown`) pour ne jamais remontrer la cérémonie.
- **Le PROFIL montre le solde ouvrable** : boosters crédités −
  boosters ouverts (solde dérivé, jamais une colonne à la main).
- **Le front recopie** : la page WIN montre les pièces RÉELLES de
  la séance (séries × 20 aujourd'hui, le ledger demain) et les
  boosters DE LA SÉANCE ; le profil montre le TOTAL.

⚠️ **Esquisse PÉRIMÉE (30-08)** — gardée pour l'histoire : la table a été
posée le 28-08 (`20260828160000_wallet_coffre.sql`) et n'a jamais été
écrite ; la forme retenue n'a **aucun état** (ci-dessus). L'origine
s'appelle `conversion`, pas `pieces`.

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

**Confirmé le 30-08** (plan coffre-annonces §1 Q3, défaut accepté) — et
étendu aux pop-ups en séance : « les chiffres changent avec l'IA » veut
dire que l'IA **choisit de quel FAIT parler** (reps, kg, total, rang,
record) et comment le dire ; elle n'invente jamais un chiffre —
`headline.value` est RECOPIÉ d'un fait d'entrée, le serveur rejette
sinon et l'app tombe sur le gabarit. Et elle sert **la PROCHAINE**
pop-up : préparée à la fin de la série N, lue à N+1 si elle est prête,
jamais attendue (§5.2.8 du plan). Si Kathryn veut un jour que l'IA
choisisse des NOMBRES, c'est un autre chantier — ce n'est pas celui-ci.

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

### 4 decies. LE BOOSTER NOIR — la pièce noire ouvre les LÉGENDAIRES
### (ajouté le 28-08 sur le brief de Kathryn ; le plan design est
### ../sacre/PLAN-BOOSTER-NOIR.md)

Verbatim : *« un variant booster noir qui permettra d'ouvrir les
légendaires : si l'user collecte une pièce noire il peut ouvrir ce
fameux booster — donc même expérience que le carrousel de base, mais
noir »*.

**LA RÈGLE, en une ligne : 1 PIÈCE D'ARGENT = 1 BOOSTER NOIR = 1 CARTE
LÉGENDAIRE, garantie.** C'est la seule monnaie de l'app qui achète une
certitude — tout le reste est du hasard mis en scène.

> ⚠️ **LA MONNAIE S'APPELLE ARGENT, ET PLUS « NOIRE » (28-08, verdict « il
> faudrait le même nom »).** Elle portait trois noms — `.argent` dans l'app,
> « pièce noire » dans les plans, `black` en base. **Le dessin a tranché** :
> la planche `piece-argent` mesure `186 · 170 · 153` sur ses hautes lumières,
> un métal PÂLE — une pièce qui ressemble à ça ne peut pas s'appeler noire.
> Le sachet, lui, garde son nom : **la pièce d'argent ouvre le booster
> noir**. Deux objets, deux noms — c'est la tautologie qu'on évite.
> En base : `currency in ('yellow','silver')`, `solde_argent()`. Renommé le
> jour même, tables VIDES — le moment le moins cher de la vie du projet.
> Les mentions de « pièce noire » plus bas dans ce document désignent cette
> pièce d'argent.

#### Ce que ça N'EST PAS

Ce n'est pas un deuxième parcours : le manège, l'engagement, la charge
au maintien, la découpe de braise, le Sacre et l'accueil au profil sont
**le même code**. Le variant est une **ROBE** (les textures du sachet)
plus une **PORTE** (la pièce noire au lieu des 20 pièces jaunes).
Aucune UI de cérémonie à réécrire, aucun fait neuf au fact engine.

#### La chaîne, de la pièce à la carte

| étape | qui décide | la garantie |
| --- | --- | --- |
| **le gain de la pièce noire** | `roll_rare` au `settle_session` — RNG **serveur** : p = 1/30 séances, pity garanti à la 45ᵉ, cooldown dur 10 séances (§2) | jamais un `Double.random` client, jamais farmable en rejouant l'UI — **le seul événement infalsifiable de l'app** (§8) |
| **le solde noir** | une ligne `coin_ledger` `currency = 'black'`, `delta = +1` | solde DÉRIVÉ (somme des deltas), jamais une colonne à la main — la loi du §0 |
| **l'annonce** | `RewardPopup`, atmosphère **RARE**, vidéo `reward-rare.mp4` (déjà recuite) | « vu = pris en compte » : la ligne est au ledger AVANT la cérémonie, l'affichage n'accorde rien |
| **la réserve** | `claim_booster_legendaire()` : débit `delta = -1, currency = 'black', raison = 'ouverture_booster_noir'` + une ligne `user_boosters` `origine = 'legendaire'` | la garde `claim_booster` réutilisée **telle quelle** — verrou `for update skip locked`, retour idempotent si déjà scellée : un double tap, un réseau qui coupe ou un retour arrière ne tirent JAMAIS deux légendaires |
| **le tirage** | `forge-card`, **pool `legendary` forcé côté serveur** en lisant `origine` sur la ligne réservée (patch écrit le 28-08, non déployé) | le client ne demande JAMAIS une rareté : il n'envoie que le `booster_id` de SA réserve — un paramètre `rarete` accepté de l'app serait la faille de tout le système |

**Le booster noir ne coûte AUCUNE pièce jaune** — *tranché le 28-08 par
Kathryn : « le prix, une pièce noire, pas plus »*. Le jaune se paie 20
jaunes à l'ouverture (`claim_booster`), le noir se paie **1 noire, et
rien d'autre** : deux monnaies, deux portes. Le §9.2 est clos sur ce
point.

**Le manège noir est SÉPARÉ** (verdict du même jour : « on n'aura jamais
les deux ensemble ») et **la cérémonie garde la braise** — donc, côté
backend, **deux réserves qui ne se croisent jamais** et aucune notion de
robe à servir : le sachet noir est une texture, pas une donnée.

#### ⚠️ LA MIGRATION — ET LA CORRECTION DU 28-08

Ce paragraphe annonçait « une migration de la contrainte `origine` », en
supposant la table déployée. **Vérifié en l'écrivant : elle ne l'est pas.**
`supabase/migrations/` ne contient que `workouts`, `logged_exercises`,
`strength_sets`, `cardio_phases`, `syntheses`, `cards` et `user_cards` :
**`user_boosters` et `coin_ledger` n'existent nulle part** — le SQL de
SUPABASE-PIPELINE.md est écrit, jamais passé. Le J3 du booster noir n'est
donc pas un `alter`, c'est la CRÉATION des deux tables, avec ce que le noir
demande dès le départ.

**Le fichier est écrit et NON APPLIQUÉ** :
`supabase/migrations/20260828120000_booster_noir.sql` — les deux tables aux
schémas exacts du pipeline, plus : `origine` qui accepte `'legendaire'`, la
colonne `currency` (`yellow`/`black`), les raisons `piece_noire` et
`ouverture_booster_noir`, la fonction `claim_booster_legendaire()` et
`solde_noir()`. Il porte aussi les `alter` défensifs pour l'autre monde —
si le SQL du pipeline a été passé avant lui, les `create if not exists`
sauteraient EN SILENCE et la contrainte resterait fausse.

> Rien ne part sans Kathryn, et par la CLI (`supabase db push`), jamais par
> le MCP de session.

#### Les deux réserves ne se mélangent pas

Le manège jaune lit `user_boosters where origine <> 'legendaire' and
opened_at is null` ; le manège noir lit `origine = 'legendaire' and
opened_at is null`. **Deux compteurs, deux pills, deux anneaux** — un
anneau MIXTE (des sachets noirs au milieu des jaunes) demanderait une
matière par clone et une rareté qui suit le slot engagé : c'est un autre
chantier (Q1 du plan design).

#### ⚠️ LE TROU QUE LE BOOSTER NOIR REND GRAVE (trouvé le 28-08)

`forge-card` accepte deux manettes d'atelier du CLIENT : `famille` et
`force_new`. **N'importe quel compte peut donc demander « La lune
souveraine » à volonté, sans pièce noire.** Le défaut existe depuis le
premier jour et ne se voyait pas : tant que toutes les cartes se valaient,
tricher ne rapportait qu'une image. Une légendaire GARANTIE n'a de valeur
que si elle ne s'obtient pas autrement.

Le patch les réserve au compte d'atelier, nommé au déploiement
(`FORGE_DEV_USER`) ; non renseigné, elles sont fermées pour tout le monde.
**Conséquence à assumer** : le banc `CarteLuneLab` perd ses leviers tant
que la variable n'est pas posée.

Deux autres bornes du même patch :
- **la garantie tient sur les DEUX chemins.** Le tirage saute le pool dans
  35 % des cas et forgeait alors une famille prise au hasard dans les 25 —
  donc une commune, avec une pièce noire. La rareté imposée borne
  maintenant le pool ET la forge neuve.
- **l'idempotence est au sachet.** Un `booster_id` déjà scellé rend SA
  carte ; le scellement (`user_boosters.card_id`) est écrit après l'insert
  dans `user_cards`. Double tap, réseau coupé, retour arrière : jamais deux
  légendaires pour une pièce.

#### Ce que l'IA a le droit d'en dire

Rien de plus qu'ailleurs : les MOTS de la card d'annonce (§4, atmosphère
RARE, gabarit déterministe derrière). **Ni la rareté, ni le tirage, ni
la robe** — la pièce noire est un fait serveur, et une légendaire est
une promesse : elle ne se raconte pas au conditionnel.

### 4 undecies. CE QUE LE COFFRE ATTEND — le wallet à deux monnaies
### (ajouté le 28-08 ; l'analyse du composant est
### ../coffre-v2/PLAN-PIED-COFFRE.md, le flow ../rewards/CHANTIERS-UX.md §7)

Le pied du coffre doit montrer, **par page**, quatre faits : le solde
DISPONIBLE, la règle, la progression vers le prochain booster, et le nombre
de sachets ouvrables. Ce qu'il demande au serveur :

**✅ TOUT CECI EST EN LIGNE depuis le 28-08**
(`20260828160000_wallet_coffre.sql`, appliquée et vérifiée) :

| ce qu'il affiche | d'où ça vient |
| --- | --- |
| solde or | `etat_coffre() → solde_or` |
| solde argent | `etat_coffre() → solde_argent` (ou `solde_argent()` seule) |
| 62/100 vers le prochain booster | ~~`booster_progress.reste` — table créée~~ → `etat_coffre() → reste`, **dérivé** (`solde_or % prix_booster`, 29-08 ; `sachet_scelle…sql:455-461`) ; avec la conversion automatique du 30-08 il est vrai par construction (§4 sexies) |
| sachets orange ouvrables | `etat_coffre() → boosters_or` |
| sachets noirs ouvrables | **= le solde argent** (le sachet naît au claim) |
| les PRIX | `reward_rules` — **sortis du code** |

**UN SEUL APPEL, PAS QUATRE** : `etat_coffre()` rend
`{ solde_or, solde_argent, boosters_or, reste, prix_booster,
pieces_par_serie }`. Ce n'est pas qu'une économie d'allers-retours : c'est
**la garantie que le coffre et le profil ne peuvent pas afficher deux
vérités** — un nombre montré à deux endroits n'a le droit d'exister qu'une
fois. Vérifié en ligne le 28-08 :
`{"reste":0,"solde_or":0,"boosters_or":0,"prix_booster":100,"solde_argent":0,"pieces_par_serie":20}`.

**Trois lois de ce wallet, à ne pas perdre :**

1. **Le solde est DÉRIVÉ, toujours** (`sum(delta)` filtré par monnaie) —
   jamais une colonne tenue à la main. C'est déjà la forme de `solde_noir()`.
2. **Les deux monnaies ne se ressemblent pas.** L'or se CONVERTIT (100 = 1
   booster, ~~report cumulé~~ conversion automatique dérivée — 30-08, §4
   sexies) ; la legendary TOMBE (RNG serveur, 1 = 1 booster).
   Le back-end ne doit donc pas exposer de progression pour la seconde —
   **et surtout jamais le *pity timer*** : rendu visible, il devient
   farmable, et la rareté est toute la valeur de cette pièce (§8, anti-abus).
3. ~~Le prix du booster orange n'existe nulle part dans le code~~ →
   **✅ LES PRIX SONT EN BASE** (`reward_rules`, 28-08, sur le verdict « le
   prix, écris-le aussi dans Supabase ») :

   | clé | valeur | ce que ça dit |
   | --- | --- | --- |
   | `pieces_par_serie` | 20 | ce qu'une série RAPPORTE (la loi des 20) |
   | `prix_booster` | 100 | ce que 100 pièces DEVIENNENT (conversion automatique, 30-08 — l'achat `claim_booster` est fermé ; §4 sexies) |
   | `prix_booster_legendaire` | 1 | une pièce d'argent, et rien d'autre |

   **L'app les LIT, elle ne les connaît pas.** `claim_booster_legendaire()`
   lit déjà son prix dans la table plutôt qu'en constante — le jour où
   l'économie bouge, rien à redéployer. C'est la table de configuration du
   §2 : seuils, budgets, cooldowns et probabilités la rejoindront.

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
adressable directement, **et la migration de la contrainte
`user_boosters.origine`** — voir §4 decies).

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
   séance, et le prix du booster jaune du Sacre reste-t-il cohérent avec
   l'inflation des bonus ? — ~~la valeur d'échange de la pièce noire~~
   **TRANCHÉE le 28-08 : 1 noire = 1 booster noir = 1 légendaire, et
   rien d'autre à payer** (§4 decies).
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

---

## §4 duodecies — LE VERSEMENT DE CONNEXION (10 pièces), 28-08

Verdict de Kathryn : *« quand tu te connectes, à chaque connexion tu manges
10 pièces — faudra le lier à la pop-up welcome back (les deux variants) et
dans le backend »*.

Le Welcome Back devient un **versement**, pas une politesse. UX au §8bis de
`CHANTIERS-UX.md`.

### La règle

| | |
|---|---|
| montant | **10 pièces jaunes** |
| déclencheur | le premier lancement d'un **jour calendaire** — jour de **Paris** (30-08, ci-dessous) |
| annonce | `RewardPopup(style: .welcome)`, les deux robes, `count: 10`, `unit: "Coins"` — puis une **dalle « +10 »** sur la home, dans l'app, pas une notification iPhone (30-08) |
| encaissement | le bouton **Claim** de la pop-up — **les +10 partent AU TAP** (30-08, Q8) |

⚠️ **C'EST LA DOCTRINE, ET LE BRANCHEMENT DU 29-08 EN AVAIT DÉVIÉ.** Ce que
le code fait au 30-08 (relu) : à chaque `scenePhase == .active`
(`WoopApp.swift:83-92`), `SacreServeur.reglerRetourQuotidien()`
(`SacreServeur.swift:282-291`) poste `.retourQuotidien` une fois par jour
UTC (marqueur `UserDefaults`) → `claim_retour_quotidien()`
(`gains_coffre.sql:135-162`) crédite — **les +10 partent tout seuls, sans
card, sans Claim, sans dalle** ; la card `.welcome` n'a aucune porte de
production (son « Claim » = `fermer()`, `RewardCard.swift:873-874`), et
`ExerciseDetailView.swift:2270` double encore le montant en constante.
**Le 30-08 rétablit la doctrine** (plan coffre-annonces §0, §1 Q7-Q8,
§5.3.10) : `reglerRetourQuotidien()` sort du `scenePhase` ; une **porte
sur la home** lit `etat_coffre().retour_disponible` (nouveau, lu sans
payer) et montre la card ; **Claim** poste `.retourQuotidien` (outbox +
index = l'idempotence) et pousse la dalle « +10 » dans la file **au tap**
(le montant est local, le journal rattrape ; si le serveur répond « déjà
pris » — autre appareil — rien de plus ne s'affiche) ; « Later » ferme, la
card revient au prochain premier plan du même jour. Le marqueur UTC local
disparaît : le serveur sait.

⚠️ **« À CHAQUE CONNEXION » NE PEUT PAS ÊTRE PRIS AU MOT — C'EST FARMABLE.**
Tuer l'app et la relancer EST une connexion : dix pièces toutes les trois
secondes, en boucle, et l'économie du coffre (100 pièces = un booster) ne veut
plus rien dire. **Une fois par jour calendaire** est la seule lecture qui
tienne, et c'est aussi celle qui correspond à ce qu'un humain appelle « je me
connecte ».

✅ **TRANCHÉ PAR KATHRYN LE 28-08 : « oui, une fois par jour calendaire ».**

### Le schéma — rien de neuf, une raison de plus et un index

`coin_ledger` existe déjà (migration `20260828160000_wallet_coffre.sql`). Il
suffit d'ajouter la raison à la contrainte :

```sql
alter table public.coin_ledger drop constraint if exists coin_ledger_raison_check;
alter table public.coin_ledger add constraint coin_ledger_raison_check
  check (raison in ('serie_faite', 'ouverture_booster', 'doublon',
                    'cadeau', 'annulation', 'retour_quotidien', …));
```

Le prix vit dans `reward_rules`, comme `pieces_par_serie` et `prix_booster` —
**l'app le LIT, elle ne le connaît pas** :

```sql
insert into public.reward_rules (cle, valeur)
values ('pieces_retour_quotidien', 10) on conflict (cle) do update …;
```

⚠️ **L'IDEMPOTENCE SE POSE COMME CELLE DU BOOSTER NOIR : UN INDEX UNIQUE
PARTIEL.** Pas un compteur applicatif — il se remet à zéro à la réinstallation
— et pas un verrou.

```sql
create unique index if not exists coin_ledger_retour_jour_unique
  on public.coin_ledger (user_id, (created_at at time zone 'UTC')::date)
  where raison = 'retour_quotidien';
```

(Esquisse. Posé le 28-08 autrement : une **colonne `jour`** remplie par la
fonction + l'index partiel `(user_id, jour)` — `gains_coffre.sql:117-151` ;
on n'indexe pas une expression `at time zone`, elle n'est pas immutable.
C'est justement ce qui rend le fuseau **une ligne à changer**.)

Deux appareils le même matin ne créditent alors qu'une fois, et le second
appel rend simplement « déjà pris » au lieu d'échouer.

⚠️ **LE FUSEAU EST UNE DÉCISION, PAS UN DÉTAIL.** En UTC, quelqu'un qui ouvre
l'app à 1 h du matin à Paris touche le versement de la veille. ~~Deux options :
UTC (simple, faux aux marges) ou le fuseau déclaré du profil (juste, une
colonne de plus).~~ ✅ **TRANCHÉ LE 30-08** (« chaque jour à minuit chez
elle », Q7 défaut accepté) : **une clé serveur `fuseau_jour = "Europe/Paris"`
dans `reward_rules`**, lue par une fonction interne `jour_courant()` =
`(now() at time zone (clé))::date` — ni UTC, ni table de profil : le jour
devient une ligne à changer si elle déménage (M1.1-2 du plan
coffre-annonces). ⚠️ Ce qu'il ne faut SURTOUT pas, et ça ne bouge pas, c'est
le fuseau envoyé par le client à chaque appel : il se change dans les
réglages du téléphone, et c'est le farm par voyage dans le temps — **jamais
le fuseau du téléphone**. **Au 30-08 le code est encore en UTC** des deux
côtés (`gains_coffre.sql:149-151`, `SacreServeur.swift:282-291`) : la
pastille ne bouge qu'après la sonde du J1 (`jour` = date Paris, lu dans le
carnet).

### La fonction

`claim_retour_quotidien()` — `security definer`, sur le modèle exact de
`claim_booster_legendaire()` : elle lit son montant dans `reward_rules`,
insère dans `coin_ledger`, laisse l'index trancher les doublons, et renvoie
`(credite boolean, montant int, solde int)`. La pop-up n'a rien à décider ;
elle affiche ce qu'on lui répond.

### ⚠️ CE QUE ÇA FORCE AILLEURS

**La page des gains du coffre doit basculer sur le ledger.** Elle dérive
aujourd'hui des SÉANCES (`séries × 20`, `CoffreFortFlow`). Un versement de
connexion n'est pas une séance : **il n'y apparaîtrait jamais**. C'est ce
besoin-ci qui rend la bascule obligatoire, et non plus seulement souhaitable
(annoncée au §17 du plan coffre). Même chose pour le solde du pied
(`variantes`, `dispo`) : une seule source, le ledger.

---

## §4 terdecies — LES BOOSTERS DU CHEMIN, ET CELUI DE CHAQUE SÉANCE (28-08)

Verdict : *« dans les gains il y a aussi les gains booster issus des rewards
du Duolingo, note-le — et à la fin de chaque séance on gagne automatiquement
un booster basique »*.

### 1. CE QUI EXISTE DÉJÀ — le chemin donne des boosters, et c'est commité

Deux commits, à relire avant de toucher à quoi que ce soit :

- **`a339141`** — la route sort du cover et monte à la racine ; la lune du
  chemin appelait `SacreEtat.proposer()` et la pièce faisait descendre une
  capsule « +40 ». Le commit dit lui-même : *« la card reward robe `.piece` et
  **l'écriture `coin_ledger`** viendront avec leur hôte, jalon 7 bis »* — donc
  l'écriture au ledger était DÉJÀ notée comme manquante.
- **`5ac641f`** — la card à gratter : les deux galets spéciaux ouvrent la même
  card, et *« le montant, la monnaie et la combinaison de boosters viennent du
  TIRAGE fait AU CLAIM »*.

Le tirage vit dans `RewardChemin.swift` (`TirageRecompense.tirer`) et rend,
côté boosters :

| tirage | ce qu'on gagne | taux de base |
|---|---|---|
| commun | `[.orange, .orange]` | le reste |
| rare | `[.orange, .legendaryBlack]` | 11 % |
| légendaire | `[.legendaryBlack, .legendaryBlack]` | 1 % |

⚠️ **Avec pitié** : après 12 nœuds communs d'affilée, le taux rare DOUBLE à
chaque nœud jusqu'à ce qu'il tombe. Le compteur vit par utilisateur ET par
piste — **et il devra vivre côté serveur, sinon il est falsifiable** (déjà
écrit dans le fichier).

**Un nœud de chemin peut donc rapporter jusqu'à DEUX boosters d'un coup**, et
aucun de ces boosters n'apparaît aujourd'hui dans l'historique des gains.

### 2. LA RÈGLE NOUVELLE — un booster basique à CHAQUE fin de séance

⚠️ **ET LE SCHÉMA L'AVAIT DÉJÀ ANTICIPÉE.** Rien à migrer côté boosters :
`user_boosters` (migration `20260828120000_booster_noir.sql`) porte déjà

```sql
origine text not null default 'seance'
        check (origine in ('seance', 'achat', 'cadeau', 'legendaire')),
workout_id uuid,                          -- la séance qui l'a gagné
create unique index user_boosters_seance_unique
  on public.user_boosters (user_id, workout_id) where workout_id is not null;
```

`'seance'` est la valeur PAR DÉFAUT, et l'index unique sur (user, séance)
**garantit qu'une re-synchro ne crédite jamais deux fois**. La règle demandée
n'a donc besoin que de son appel : à la clôture d'une séance, une ligne
`user_boosters(origine: 'seance', workout_id: …)`.

⚠️ **CE QU'IL MANQUE, C'EST `'chemin'`** — les boosters du Duolingo n'ont pas
d'origine à eux et se rangeraient sous `'cadeau'`, ce qui rend l'historique
illisible. Une valeur de plus dans la contrainte, et le nœud en référence :

```sql
alter table public.user_boosters drop constraint if exists user_boosters_origine_check;
alter table public.user_boosters add constraint user_boosters_origine_check
  check (origine in ('seance', 'achat', 'cadeau', 'legendaire', 'chemin'));
alter table public.user_boosters add column if not exists noeud_id integer;
create unique index if not exists user_boosters_chemin_unique
  on public.user_boosters (user_id, noeud_id) where origine = 'chemin';
```

Même outil que partout ailleurs : **un index unique partiel**, pas un
compteur. La leçon `chemin.reclamees` (« une lune se re-réclame à chaque
lancement, boosters infinis ») est aujourd'hui tenue par des `UserDefaults` —
elle se remet à zéro à la réinstallation.

### 3. ⚠️ CE QUE ÇA COÛTE À L'ÉCONOMIE — à trancher, pas à supposer

Aujourd'hui : **20 pièces la série, 100 pièces le booster.** Une séance de
5 séries rapporte 100 pièces, soit un booster.

Si chaque séance donne EN PLUS un booster automatique, **une séance en
rapporte deux**, et le prix de 100 pièces ne décide plus de grand-chose pour
quelqu'un de régulier. Ce n'est pas un bug — c'est peut-être exactement
l'intention (« la séance est toujours récompensée »). Mais il faut le savoir
et choisir :

1. **On assume** — le booster de séance est le socle, les pièces servent aux
   boosters EN PLUS (recommandé si le but est que finir une séance soit
   toujours payant).
2. **On monte le prix** du booster acheté (150-200) pour que l'achat garde un
   sens à côté du don.
3. **On distingue les robes** — le booster de séance est un `orange` ; ce que
   les pièces achètent devient autre chose.

Le prix vit dans `reward_rules`, donc ce choix se change sans toucher au code.

### 4. LA CONSÉQUENCE, POUR LA TROISIÈME FOIS

Trois sources de gains ne passent pas par les séances comptées :
**le versement de connexion (§4 duodecies), les boosters du chemin, et le
booster de fin de séance.** L'historique du coffre les rate tous les trois.

⚠️ **La bascule de `pageGains` sur `coin_ledger` + `user_boosters` n'est plus
une amélioration, c'est la condition pour que la page dise la vérité.** Elle
affiche aujourd'hui `séances × séries × 20`, une reconstruction — pas un
journal. Une ligne par ÉVÉNEMENT, avec son origine :

| ligne | origine |
|---|---|
| « 12 séries · +240 » | `coin_ledger / serie_faite` |
| « Retour quotidien · +10 » | `coin_ledger / retour_quotidien` |
| « Séance terminée · 1 booster » | `user_boosters / seance` |
| « Chemin · 2 boosters » | `user_boosters / chemin` |
| « Chemin · +150 » | `coin_ledger / chemin` |

C'est aussi ce qui donnera enfin des lignes AVEC UNE IMAGE DE SACHET dans
l'historique : `GainCoffre.robe` est aujourd'hui toujours `nil`, donc chaque
ligne montre la pièce d'or — je l'avais signalé en livrant la page.

---

## §4 quaterdecies — LES ANNONCES : UNE SEULE PAR ÉVÉNEMENT (29-08)

Verdicts de Kathryn du 29-08 : *« notification et pop-up rewards sont
liées »*, puis, sur la question posée : **« oui une seule annonce par
événement je suis d'accord »**.

L'analyse complète (neuf composants, quatre formules, l'ordre de branchement)
vit dans [PLAN-ANNONCES.md](PLAN-ANNONCES.md). Les deux fiches écran :
`docs/screens/notification.md` et `docs/screens/reward-popup.md`. **Depuis le
30-08, le contrat par catégorie et la chaîne de fin de séance sont tranchés
dans [../annonces/PLAN-COFFRE-ANNONCES.md](../annonces/PLAN-COFFRE-ANNONCES.md)
(§0, §3)** — ce paragraphe est amendé ci-dessous, pas remplacé.

### 1. LA RÈGLE

> **Toute annonce d'un gain passe par la même famille, et un gain ne se dit
> qu'UNE FOIS.** Il n'y a pas « les notifications » et « les pop-ups » : il y
> a **une décision — annoncer, et comment — qui rend l'un de trois formats.**

| Format | Ce qu'il coûte | Quand |
|---|---|---|
| **le silence** | rien | ~60 % des séries (un RÉSULTAT, pas un paramètre) |
| **la NOTIFICATION** (4 robes) | rien : elle traverse, on ne la tape pas | le cas courant d'un gain |
| **la POP-UP** (6 robes) | l'écran, un scrim, un geste | quand il y a un FAIT à raconter |

~~⚠️ **La pop-up REMPLACE la dalle, elle ne s'y ajoute pas.** Aujourd'hui la
fin de séance en enchaîne DEUX (la capsule à +1,6 s, la pop-up booster à
+5,2 s) — c'est exactement ce que cette règle interdit.~~ **PÉRIMÉ pour la
clôture — tranché le 30-08** (plan coffre-annonces §0 « clôture », §1 Q4-Q5,
§3). **La règle « une annonce PAR ÉVÉNEMENT » reste** ; ce qui tombe, c'est
la lecture « une fin de séance = un événement ». Une clôture en compte **deux
ou trois** — les pièces, le sachet forfaitaire, et la pièce d'argent (1/30)
— plus les sachets convertis à 100 : **chaque événement a SA dalle, et les
dalles s'EMPILENT** sur une **page noire** montée après la story (« un petit
chargement » : elle attend la réponse de `cloturer_seance`, borne 4 s, repli
local dit comme tel). Puis **le CHEMIN**, pas la home (actualisation +
animation « séance terminée » sur la route), puis la **pop-up « Ouvrir »** —
qui est une **INVITATION** (« ton sachet t'attend »), pas une seconde
annonce : le sachet a déjà été dit dans la pile. La page WIN de la story dit
déjà pièces + sachet ; la page noire les **redit** en dalles — c'est le
« reçu » (Q5). La clé `annonce_une_par_evenement` reste à `true` — son
commentaire en base (`annonces.sql:139-144`, « interdit deux annonces à la
fin ») est périmé, à réécrire avec M1.

**Ce que le code fait au 30-08** (relu, `WoopApp.swift` de 17:47) :
`terminerSeance()` (:455-536) bascule **toujours sur la home** (:489) — et
`celebrateFinishedWorkout()` (:1666-1673) force `.home` une seconde fois ;
`push` + `cloturer_seance` partent en `Task.detached` (:510-513), jamais
attendus ; story à +2,0 s (:532-535). À sa fermeture, `enchainerApresStory()`
(:543-556) : **une** capsule `notifPieces = gain` (le calcul LOCAL) à +0,3 s,
retirée à +3,3 s, puis `SacreEtat.shared.proposer()` à +3,4 s — sur la home.
Un seul créneau de dalle (`DepartSeance.swift:43`, hôte `WoopApp.swift:1237-1244`)
— une seconde écriture **écrase** la première ; robe pièces seule, ni robe
booster ni robe argent ; la réponse de `cloturer_seance` est lue
(`OutboxGains.swift:191-205`) mais **aucune annonce ne la regarde** — la pièce
d'argent finit dans un `print`. C'est le J3 du plan coffre-annonces
(`PileAnnonces.swift`, atterrir sur le chemin, « Ouvrir » après la route).

### 2. LE CONSTAT QUI L'A RENDUE NÉCESSAIRE (mesuré le 29-08)

**Neuf composants annoncent un gain**, et **quatre formules indépendantes
recalculent le même nombre** :

```
WoopApp.swift:442              a.setCount * 20
ExerciseDetailView.swift:2171  max(faites,1) * gainParSerie
StorySuite.swift:1489          session.series * 20
CoffreFortPurse                séries × 20
```

Ce ne sont pas deux composants liés : c'est **une seule fonction manquante —
annoncer un gain — réimplémentée neuf fois.** Deux d'entre eux sont d'ailleurs
morts sans qu'on l'ait vu (la page BRAVO, le vol de pièces de la home).
(Relevé du 30-08 : `WoopApp.swift:442` est devenu `:473` et lit
`seriesPayantes × EconomieWoop.piecesParSerie` — le taux vient du serveur ;
`StorySuite.swift:1489` compte encore `× 20`.)

⚠️ ~~**ET CE QUI DÉCIDE AUJOURD'HUI EST CE QUE LE §2 INTERDIT**~~ — **relu le
30-08 : le §2 ne l'interdit plus.** Kathryn a tranché des **rangs fixes 3 / 5 /
10, puis un rang au hasard toutes les 5-8 séries**, sous le budget 4 / 1 / 1 /
6 et l'écart 3 séries ET 6 min pour les rangs tirés (§2 amendé ; plan
coffre-annonces §3). Ce que `DecideurSerie.pour` (`RestartSheet.swift:608-630`)
fait de faux n'est donc plus le principe, c'est le reste : ses trois modulos
(`% 10`, `% 5`, `% 3`) servent **tous les multiples** (6, 9, 12, 15…), sans
hasard, sans budget, sans horloge, sans serveur — et les 21 clés de rythme de
`reward_rules` (`annonces.sql:96-152`, comptées une à une le 30-08 soir ;
`regles_annonces()` en rend 18, les trois `rare_*` retirées) ne sont lues par
personne. Et la règle
ne tient même pas sa promesse (mesuré le 29-08, le code est le même au 30-08 :
`ExerciseDetailView.swift:2356-2375`) : `settleSeries` diffère son écriture de
0,55 s alors que le rang est lu tout de suite — **le MOMENT tombe à la 4ᵉ
série, la pop-up à la 6ᵉ, la vidéo rare à la 11ᵉ**, et la pill sous-compte de
20 pièces.

### 3. QUI DÉCIDE QUOI

| Décision | Où | Pourquoi pas ailleurs |
|---|---|---|
| annoncer ou se taire | **serveur** (`reward_rules`) | le pacing n'est pas un dé, et une règle client est falsifiable |
| quel FORMAT | **serveur** | c'est le budget d'attention, la ressource rare |
| quelle ROBE | **client**, rotation déterministe | elle s'affiche AVANT toute réponse ; la demander au serveur, c'est l'attendre |
| le MONTANT | client d'abord, **serveur qui rattrape** | §1 : « l'UI affiche le gain tout de suite, le ledger rattrape » |
| la RARETÉ | **serveur, toujours** | un RNG client se rejoue jusqu'à la légendaire |

### 4. CE QUI EST FAIT — ✅ DÉPLOYÉ ET VÉRIFIÉ LE 29-08

`20260829120000_annonces.sql` + `20260829130000_roll_rare_prive.sql`

| # | Quoi | Pourquoi |
|---|---|---|
| 1 | **`reste` devient DÉRIVÉ** (`solde_or mod prix_booster`) dans `etat_coffre()` | `booster_progress.reste` était créé, lu, **et écrit par personne** : la jauge du coffre et celle de la notification affichaient **0/100 en permanence**. Et un solde stocké viole la loi n° 1 |
| 2 | **`roll_rare(uuid)`** — p = 1/30, pity 45, cooldown 10, **compteur DÉRIVÉ du journal** | la pièce d'argent **ne pouvait pas être gagnée** : solde bloqué à 0 → booster noir inatteignable → toute la robe noire du Sacre hors du jeu |
| 3 | **`cloturer_seance` tire au règlement** et rend `argent`, `reste`, `prix_booster` | une seule annonce suppose **une seule réponse** : tout ce que la dalle doit dire est là, plus rien à redemander |
| 4 | **21 clés de rythme** dans `reward_rules` (dont `annonce_une_par_evenement` ; comptées une à une le 30-08 soir, `annonces.sql:98-151`) | le rythme se règle **sans redéployer l'app** — c'est toute la raison d'être de la table |
| 5 | **`regles_annonces()`** — un appel, toutes les règles agrégées | une règle ajoutée demain ne demande **aucun changement de client** |

⚠️ **Les trois clés de rareté sont RETIRÉES de `regles_annonces()`** : un pity
timer visible est farmable. Mais la table reste en lecture publique pour
`authenticated` — **la vraie protection serait une table à part sans policy de
lecture**. C'est noté, pas résolu.

⚠️ **Ce que la migration NE tranche PAS** : la conversion automatique des
pièces en sachets (§4 sexies). `claim_booster()` débite déjà 100 pièces ;
convertir EN PLUS au règlement paierait deux fois le même travail. C'est la
question d'économie ouverte du §6.7 de la fiche coffre, et elle appartient à
Kathryn. La migration rend seulement la jauge **honnête**.
✅ **Tranchée le 30-08** : conversion automatique, l'achat `claim_booster`
retiré — voir §4 sexies (amendé) et §7.3 ci-dessous. Ce que `etat_coffre()`
montre au 30-08 : `reste = solde_or % prix` sur le solde **TOTAL**
(`sachet_scelle…sql:455-461`) — la sonde du site lit `solde_or 1360 → reste
60`, treize tranches de 100 qui ne sont des sachets nulle part ; c'est M1 qui
les convertit.

### 5. CÔTÉ APP — les deux tuyaux morts, branchés

Les deux existaient **des deux côtés** (fonction serveur déployée le 28-08,
cas d'outbox écrit et traité) et **personne ne les postait** :

- **`.noeudChemin`** — `RewardCheminEtat.reclamer` n'écrivait que
  `UserDefaults` pendant que la card affichait « **Added to your balance** ».
  L'écran mentait. Elle poste maintenant le tirage NEUF (jamais une relecture
  du journal), **après** l'ouverture de la card.
- **`.retourQuotidien`** — posté au retour au premier plan, **avant** le
  vidage (s'il échoue, le vidage le rejoue dans la foulée). Le marqueur local
  compte le jour **en UTC**, comme la fonction serveur : deux fuseaux
  différents feraient sauter un versement.
  ⚠️ **C'est ce branchement-là qui a dévié de la doctrine du §4 duodecies**
  (le Claim, l'encaissement au tap) : posté au premier plan, il crédite sans
  card ni bouton. Le 30-08 le rétablit (J2 : porte sur la home lisant
  `retour_disponible`, Claim → outbox → dalle « +10 » au tap) ; le marqueur
  UTC local disparaît et le jour passe à Paris (M1).

### 6. CE QUI RESTE, DANS L'ORDRE

1. ⚠️ **Le ménage** — le décalage d'un rang, le plancher `max(…, 4)`, le chip
   « … » qui ouvre une récompense fausse, le Claim qui annonce des séries au
   lieu de pièces.
2. **Le grain de la série dans l'outbox** — elle n'a ni `serie_index` ni
   `facts` ; le crédit ne part qu'à la clôture, en bloc.
3. **Un seul point d'annonce** — `DecideurSerie` sort de la fiche exo et
   devient le passage obligé des cinq chaînes.
4. **Le fact engine** (§3), puis les vrais faits dans la matrice du
   `.spotlight` — qui affiche aujourd'hui des performances inventées.
5. **`narrate-reward`** (§4) — **en dernier**, et le §9.6 le recommande
   lui-même : « gabarits d'abord ». ⚠️ Aucune IA n'a jamais écrit un texte
   affiché dans cette app : `weekly-synthesis` est du code mort (sa vue n'est
   montée nulle part) et le texte de `forge-card` est un prompt pour le
   peintre. Et **l'IA n'a nulle part où écrire** : les mots géants sont câblés
   en dur, `RewardPopup` ne remonte jamais `lignes`.

### 7. ~~À TRANCHER~~ → TRANCHÉ (30-08), point par point

1. ✅ **Une notification ne consomme PAS le budget des 4 pop-ups** —
   `notif_consomme_budget = false`, plafond propre `notifs_max_seance = 6`
   (verdict du 30-08, « le rythme » : « une dalle ne consomme pas le
   budget » ; Q5 du plan coffre-annonces). Les valeurs posées le 29-08
   sont les bonnes ; ce qui manque, c'est le lecteur (J4).
2. ✅ **L'écart minimal est « 3 séries ET 6 min »** — `ecart_exige_les_deux
   = true` (Q5 du 30-08). Précision Q1 : il ne s'applique **qu'aux rangs
   tirés au hasard** après le 10 ; les rangs fixes 3 / 5 / 10 gagnent
   (deux séries entre 3 et 5, et c'est voulu).
3. ✅ **La conversion automatique** — tranchée le 30-08, **option 1 du §4
   terdecies.3, « on assume »** (la question d'économie ouverte du §6.7 de la
   fiche coffre) : à 100 pièces **un sachet apparaît tout seul**, le nombre
   monte (1, 2…), **les pièces retombent** ; le sachet forfaitaire de clôture
   s'affiche aussi. Dérivée, pas de report stocké (`convertir_pieces()`, M1 ;
   §4 sexies amendé). Conséquence assumée (Q9) : le solde ne dépasse plus
   99, **l'achat `claim_booster` ne peut plus réussir — il disparaît de l'app
   (`CoffreV2.swift:2542-2551`, `ProfilLune.swift:1255-1265`) et la fonction
   est fermée** (`revoke … from authenticated`) ; « Ouvrir » ouvre un sachet
   qui existe déjà.
4. ✅ ~~`claim_booster_legendaire()` rend toujours **500** sur un refus
   métier~~ — **fait depuis `9ef6da1`** (30-08,
   `20260830160000_sachet_scelle_et_tirage.sql:55-127`) : `drop` puis
   recréée en `returns jsonb`, un refus métier rend **200** avec un motif
   (`{ouvert:false, raison:'argent_insuffisant', solde_argent, prix}`),
   idempotente sur un légendaire ouvert non scellé ;
   `SacreServeur.claimLegendaire` (`SacreServeur.swift:127-128`) lit
   l'objet. Les deux côtés ont bougé ensemble, comme ce point l'exigeait.
