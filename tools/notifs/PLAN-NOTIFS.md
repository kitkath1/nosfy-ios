# LES NOTIFICATIONS — la dalle noire qui remplace le toaster de verre

**Date** : 28-08. **Simulateur** : `kat-notif`
(`793977E8-595E-46F7-8E14-F2DF9EB79206`, iPhone 16 Pro / iOS 26.5 — 393×852 pt,
la géométrie EXACTE de la capture OPAL de référence).
**DerivedData** : `dd-notif`. **Banc** : `-notifLab`.

---

## §0 — CE QU'ON REMPLACE (repéré, pas supposé)

Le « toaster liquid glass » actuel a un nom et une seule place :

- **`PillGain`** — [RestartSheet.swift:536](../../Woop/Views/RestartSheet.swift#L536).
  Une capsule de verre natif 44 pt de haut :
  `piece-or-mini` + « +20 » + « · » + « 140 this session ».
- Elle est montée **une seule fois** :
  [ExerciseDetailView.swift:1016](../../Woop/Views/ExerciseDetailView.swift#L1016),
  branchée par `IssueSerie.pill` du `DecideurSerie`
  ([RestartSheet.swift:600](../../Woop/Views/RestartSheet.swift#L600)).

Sa raison d'être est écrite dans son propre commentaire et elle **ne change
pas** : *« elle n'interrompt rien »* — elle descend du haut, tient deux
secondes, repart, le doigt n'a jamais rien à faire. **Les nouvelles cards
héritent de ce contrat.** Ce qui change, c'est la ROBE : plus une capsule de
verre, une **dalle noire pleine largeur façon OPAL**.

⚠️ **On ne débranche `PillGain` qu'au jalon 4**, après ton verdict. Tant que le
banc n'est pas validé, la fiche exo garde sa pill : rien ne casse dans le flow.

---

## §1 — LE SOCLE : la dalle OPAL

La forme mesurée sur ta capture (iPhone 16 Pro, à quelques pixels près — elle
se cale au premier tour de boucle visuelle, pas à la règle) :

| | valeur de départ |
|---|---|
| largeur | pleine largeur − 23 pt de marge (≈ 347 pt) |
| hauteur | **138 pt** |
| rayon | 28 pt continu |
| fond | **noir VRAI** (`Color.black`), pas de verre |
| liseré | blanc 0,07 → 0,02, 1 pt, haut → bas |
| ombre | noir 0,55, rayon 22, y +10 |
| padding interne | 20 pt |

**Pourquoi pas de verre.** Trois lois du dépôt convergent : `.regular` est
interdit ; `.clear` givre le contenu NET (or ici tout est du texte) ; et un
verre aux bounds vivants devient un blur plat définitif — or cette card
descend et remonte. La dalle est donc du **noir peint**, comme la card reward
et le pop-up booster. C'est aussi ce que montre OPAL : du noir, pas du verre.

`SocleNotif` porte la dalle + l'ombre + le liseré, et **rien d'autre**. Les
deux variants sont son contenu. Elle vit à **taille CONSTANTE** dès la
première image : l'entrée est un `offset` + une `opacity`, jamais un
redimensionnement.

---

## §2 — VARIANT A « LA JAUGE » (le gain de pièces)

```
┌──────────────────────────────────────────┐
│  PIÈCES GAGNÉES                    ,-·-. │
│  Coffre · 140 cette séance        (  ()  │ ← la pièce TOUCHE le bord,
│  +20 pièces gagnées                `-·-' │   rognée par le coin arrondi
│                                          │
│  ▰▰▰▰▰▰▰▰▰▰▰▰▰▰░░░░░░░░░░░░░░░░░░░░░░    │
└──────────────────────────────────────────┘
```

- **Titre** : capitales, `.inter(17, .heavy)`, tracking −0,5, blanc pur.
- **Sous-titre** : `.inter(13)`, `inkSecondary` (le gris de la maison).
- **Le gain** : « **+20** pièces gagnées » sous le sous-titre — le chiffre en
  `.heavy` monospaced-digit, le mot en gris. Il **compte** de 0 à 20 pendant
  l'entrée (le count-up de la card reward, déjà écrit).
- **La barre** : capsule 7 pt sur une piste blanc 0,08, remplie d'un dégradé
  **blanc froid → blanc pur** (0,30 → 1,00) avec une **tête spéculaire** (un
  petit bloom blanc au point d'arrêt) — le « trop belle ».

  ⚠️ **Elle ne se remplit PAS en changeant sa largeur.** Loi n°5 du dépôt :
  ce qui bouge par image ne doit jamais changer une taille (un layout
  re-calculé à 60 Hz, c'est le lag). La capsule pleine est dessinée **à
  largeur constante** et RÉVÉLÉE par un **masque `Shape` `Animatable`** sur
  la fraction. Le dégradé ne s'étire donc jamais — il est peint une fois, la
  lumière le découvre.

- **La pièce** : `piece-or` à ~78 pt, posée à droite, **décalée pour mordre le
  bord** — le `clipShape` de la dalle la rogne sur le coin arrondi. C'est ça,
  « elle touche ». Un halo blanc très doux dessous pour qu'elle ne flotte pas
  sur du noir mort.

---

## §3 — VARIANT B « LE GROS TEXTE » (YOU WIN)

La grammaire de ta réf (le « YOU MADE » gris coupé, avec le 4 de verre
par-dessus) — elle **existe déjà** dans le dépôt :
`TexteGeant` + `balayageSpot`
([RewardCard.swift:1831](../../Woop/Views/RewardCard.swift#L1831)) : les
rangées géantes en argent sombre, **rognées par les flancs jamais rétrécies**,
révélées par une copie claire masquée par le champ du projecteur qui balaie de
droite à gauche (période ~9,7 s). On la RÉUTILISE, on ne la réécrit pas.

```
┌──────────────────────────────────────────┐
│  ██  ██  ███  ██  ██   ██  ██  ██  ███   │ ← « YOU WIN » géant, COUPÉ
│  ██  ██  ██   ██  ██   ██  ██  ██  ██    │   à gauche ET à droite
│   ████   ███   ████     ████   ██  ███   │
│                                    ,-·-. │
│  +20 PIÈCES                       ( 🪙 ) │ ← la pièce qui TOURNE,
└──────────────────────────────────────────┘   sous le cône du spot
```

- **« YOU WIN »** sur UNE ligne (la dalle fait 138 pt : deux lignes de 112 pt
  n'y tiennent pas), corps ~66 pt `.heavy`, tracking −3, `fixedSize()`, hors
  layout — le clip de la dalle fait la coupe aux deux flancs.
- **Le spot** : le cône du haut + la même horloge `balayageSpot`, donc la
  lumière qui court sur les lettres est celle qui éclaire la pièce. Un seul
  projecteur dans la card, pas deux lumières qui se contredisent.
- **« +20 PIÈCES »** : petites capitales `.inter(12, .semibold)`, tracking +1,
  posées en bas à gauche PAR-DESSUS le géant — l'information lisible sur le
  décor.
- **La pièce qui tourne** : `piece-bravo-loop.mp4` (1 Mo, la boucle déjà
  encodée pour BRAVO), ~56 pt, à droite.

  ⚠️ **Aucun masque sur la couche vidéo** : un masque force un rendu hors
  écran de tout le plan à chaque image (loi payée). Inutile ici — la source
  est sur fond NOIR, elle se fond seule dans la dalle noire, exactement comme
  la vidéo de `DepartSeance`. `AVPlayerLooper` muet, retenu par un
  coordinateur, jamais de `seek(.zero)`.

---

## §4 — LE BANC `-notifLab`

`NotifLab` : la nuit vraie, et les **deux variants empilés l'un sous l'autre**
(ton verdict : « mets-les les uns sous les autres ») — la seule façon de les
comparer sur UNE capture, sans changer d'écran.

- Monté **en tête de `WoopApp.body`**, juste après `RewardBanc.actif` : il ne
  veut rien dessous, ni splash, ni porte, ni fiche exo (le halo orange de la
  fiche traversait déjà le scrim et polluait le jugement de la card reward,
  constaté le 27-08).
- Un tap **rejoue** les deux entrées (démontage → renaissance, la vraie sortie
  suivie de la vraie entrée — jamais une coupe sèche).
- Prises : `-notifNu` (pas de bandeau, captures propres),
  `-notifFige <p>` (l'entrée clouée à un instant — deux tours de fouettage ne
  se comparent jamais s'ils ne sont pas au même point de la rampe),
  `-notifT <s>` (l'horloge du spot figée).

⚠️ **`--terminate-running-process` est obligatoire au `simctl launch`** : une
app déjà vivante revient au premier plan **avec ses anciens arguments**.

---

## §5 — LES JALONS

| # | Ce qui sort | Comment on le juge |
|---|---|---|
| **J0** | `SocleNotif` + `NotifLab` + `-notifLab` dans `WoopApp` : deux dalles noires vides empilées | capture — **la FORME se cale ici** contre ta réf OPAL (hauteur, rayon, marges) |
| **J1** | Variant A complet : titre, sous-titre, +20, barre à dégradé, pièce qui touche | capture posée + **film de l'entrée** (la barre se remplit) |
| **J2** | Variant B complet : YOU WIN coupé, spot, +20 PIÈCES, pièce qui tourne | capture + film (le balayage) |
| **J3** | L'arrivée / la tenue / la sortie, identiques au contrat de `PillGain` | film `simctl io recordVideo`, refermé par SIGINT |
| **J4** | **Ton verdict**, puis le branchement à la place de `PillGain` | seulement si tu valides |

**J4 n'est PAS automatique.** Tant que tu n'as pas tranché, la fiche exo garde
sa pill de verre et rien du flow ne bouge.

---

## §6 — CE QUI EST DÉJÀ DÉCIDÉ, ET CE QUI RESTE OUVERT

**Décidé (je ne te repose pas la question) :**
- Noir peint, pas de verre — trois lois convergentes (§1).
- La barre se révèle par un masque, elle ne change pas de taille (§2).
- Réutilisation de `TexteGeant` / `balayageSpot` pour le variant B (§3).
- La vidéo de la pièce sans détourage ni masque (§3).

**Ouvert — je pars sur ces défauts, dis-moi si tu veux autre chose :**

1. **La langue.** L'app est en ANGLAIS partout (`140 this session`,
   `Welcome back`, `YOU MADE IT`) — tu as écrit « +20 pièces gagnés » en
   français. Je pars sur **l'anglais** (« COINS EARNED » / « +20 coins
   earned » / « YOU WIN » / « +20 COINS ») pour ne pas mélanger deux langues
   dans une même app. Un mot de toi et je bascule tout en français.
2. **Ce que la barre mesure.** Elle a besoin d'un « sur quoi » : je pars sur
   **la progression du coffre** (les pièces vers le prochain palier), la seule
   jauge que l'app connaisse déjà. L'autre lecture possible serait
   « la séance » (séries faites / séries prévues).
3. **La couleur de la pièce.** `piece-or` (l'or de la maison) contre
   `piece-argent`. Je pars sur **l'or** — c'est la pièce du gain partout
   ailleurs (`PillGain`, le podium de la story, le chemin).

---

## §7 — LA DISCIPLINE (les pièges déjà payés qui s'appliquent ici)

1. **`xcodebuild | grep` rend le code de GREP** — build cassé = « exit 0 », et
   on juge une app PÉRIMÉE. Payé TROIS fois. → `xcodebuild` **nu** en tâche de
   fond, et `stat` du `Woop.debug.dylib` avant CHAQUE capture.
2. **Deux builds sur le même `-derivedDataPath` = base verrouillée** →
   `pgrep -fl xcodebuild` avant de lancer. Le `dd-notif` est à moi seul.
3. **Le type-checker** : le corps d'une vue est une addition de vues NOMMÉES.
   Chaque variant est une `struct` à part, chaque sous-bloc une propriété
   nommée. `WoopApp.mainBody` a déjà cessé d'être type-checkable une fois
   (`337a6e3`) — on n'y ajoute qu'**un `static let` et un `else if`**.
4. **Une cinématique se FILME**, jamais screenshot par screenshot (~4 s
   l'image).
5. **`./tools/charge.sh` avant tout `-fps`** — la charge machine invalide la
   mesure, et la vraie cadence se mesure sur le TÉLÉPHONE.
6. **Multi-session** : `WoopApp.swift` porte aussi le travail d'autres
   sessions. Commit par **chemins explicites** ou par hunks, **jamais de
   `git stash`**, et `git diff HEAD` (jamais `git diff` : l'index ment).
