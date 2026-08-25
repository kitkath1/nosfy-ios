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
