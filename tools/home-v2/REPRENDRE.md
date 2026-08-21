# REPRENDRE LE CHANTIER DE LA HOME — le prompt de reprise

*Copie tout ce qui suit dans une nouvelle session.*

---

Je reprends le chantier de la **home v2 de Woop** (app iOS de sport, UI en
français, mes commits uniquement — voir `CLAUDE.md`).

## Où on en est

Quatre commits sur `main`, tout est buildé et tourne :

- `98b123c` **LA HOME V3** — la page est UNE grande card aux coins
  concentriques sur un fond vidéo, la phrase « Bonjour Kathryn… », la semaine
  en pochettes, le drag de toute la card, et un secret (la lune néon) sous elle.
- `b2fc37e` **LES DEUX CARDS** — « 4/5 sessions this week » et « 8.4 kg
  weekly volume », reconstruites au pixel depuis ma référence, plus
  l'instrument qui les note.
- `d1b8821` **LE MENU** — le galet de verre au néon, les halos qui s'allument
  depuis la main, la mise au point typographique sur les sections.
- `5d18aef` **LA HOME REÇOIT SES CARDS** + le plan complet.

**Le plan vit dans `tools/home-v2/PLAN-HOME-V2.md`** (§9 à §13) : lis-le, il
porte l'anatomie mesurée, chaque tour de verdicts, et les deux directions
abandonnées avec leurs mesures.

## Ce qui reste

1. **LE SLIDER DE DÉPART** — la pièce qui manque le plus au flow. Il y a
   ~170 pt libres en bas de la home, c'est sa place. Spec au § 9.5 : noir,
   minimal, un dot blanc/verre, un fil très fin, presque pas de texte ; drag
   vers la droite pour démarrer, lueur orange **extrêmement** subtile
   derrière le dot pendant le drag, haptique à la validation. La matière
   existe : `galetMedaillon` (le galet du slider de séance, un shader qui
   PEINT son cristal et brille donc sur n'importe quel fond).
2. **LE TIROIR DU BAS** (plan § 13, chantier B) — le geste existe déjà (la
   card se soulève, la lune s'allume dessous). Il lui manque son **cran
   d'aimantation à 90 pt** (au-delà elle reste ouverte) et son contenu réel :
   le **player** de la séance en cours (« Session du 21 août · En séance ·
   18 min » + un stop minuscule).
3. **Les micro-détails du § 13.7 pas encore livrés** : le flash de 0,08 s sur
   l'item choisi, la pulse des halos depuis sa position, leur extinction dans
   l'ordre **inverse** de l'allumage, et la dérive gyro.

## Les lois de la maison — ne les redécouvre pas

**Le verre :**
- `.regular` est **interdit**. `.clear` **givre** ce qui est net → contenu
  DOUX seulement (halos, vidéo), l'encre nette au-dessus.
- **L'encre doit être au-dessus du CONTENEUR de verre**, pas seulement
  au-dessus du verre : dedans elle est lentillée.
- **Le verre natif ne montre que ce qu'il RÉFRACTE.** Sur du noir il est à
  jeun (p95 mesuré à 23). Il faut lui donner un monde — la vidéo, un halo.
- **Un `glassEffect` aux bounds vivants reste flou plat pour toujours** :
  taille constante, révélation par clip ou par montage.
- **Le verre natif IGNORE `.opacity`** : pour le cacher il faut le DÉMONTER.
- **Le Liquid Glass se lit par ses BORDS.** Fondre le bord d'une nappe
  supprime exactement ce qui fait le verre — il ne reste qu'un frost.

**La forme et la lumière :**
- **Un halo n'a pas de bord, une feuille en a forcément un.** Si le dessin
  demande « fondu », l'objet ne peut pas être une surface : c'est une lumière.
- **La loi anti-brun** : une rampe de couleur s'écrit **en canaux** (on
  éteint le bleu puis le vert quand la lumière tombe), jamais en `mix()`
  entre deux teintes — le chemin droit passe par un orange désaturé.
- **Des foyers lumineux se CUMULENT** : c'est leur somme qui doit être juste.
- Pas de pastille derrière un titre, pas d'anneau qui part d'un bouton (c'est
  la grammaire d'Android). Apple rend l'actif plus PRÉSENT et ÉLOIGNE les
  autres.

**L'animation :**
- **Une chaîne d'`asyncAfter` ne peut pas être fluide** : chaque réveil est
  une marche. Un SEUL curseur `p` de 0 à 1, animé une fois, dont chaque pièce
  dérive sa fenêtre.
- Les rampes échelonnées ne jouent pas sous un `withAnimation` ordinaire →
  `struct View, Animatable`.
- **Jamais de ressort sur l'échelle de tout l'écran** : il dépasse sa cible
  et fait un va-et-vient visible partout.
- **Un `scaleEffect` sur un `AVPlayerLayer` SAUTE** au lieu de glisser (une
  couche UIKit n'interpole pas dans la transaction SwiftUI). Le fond ne
  recule pas — c'est le contenu qui recule.
- La courbe des feuilles d'Apple : `.timingCurve(0.22, 1, 0.36, 1)`.

**SwiftUI, deux pièges :**
- **Un `onLongPressGesture`, même à 0,01 s, VOLE le tap qui le suit.** Un
  seul `DragGesture(minimumDistance: 0)` donne l'appui ET le tap.
- Le vérificateur de types **sature** sur une vue aux mesures inlinées, et
  les découper en instructions dans un `@ViewBuilder` donne « type '()'
  cannot conform to 'View' » → un petit **type de mesures** calculé dehors.

## La méthode

- **On mesure, on ne devine pas.** `tools/home-v2/compare_widget.py` note un
  rendu contre la référence. ⚠️ Il est calibré : **2 px de décalage coûtent
  1,3 point**, donc 6/10 veut dire « placé à 3-5 px près ».
- Les références de Kathryn sont des images **retouchées** (unsharp mask) :
  la fine ligne noire autour des formes est du *ringing*, on ne la reproduit
  pas, ni ses irrégularités.
- Build : `xcodebuild -project Woop.xcodeproj -scheme Woop -destination
  "platform=iOS Simulator,id=<sim>" -derivedDataPath dd-booster build`.
  ⚠️ **`xcodebuild | grep` rend le code de sortie de GREP** : utiliser
  `set -o pipefail` et vérifier le `stat` du dylib avant toute capture.
- **Deux simulateurs** : `kat-cal-18` (E307BE14-B36F-48DE-ABB1-CD933B5C6EAD)
  est CELUI DE KATHRYN — on y installe pour qu'elle voie ; les captures se
  font sur un second (iPhone 17 Pro, D8A31930-1D84-42BF-A129-051BB6B9195B),
  éteint après usage. Sinon on capture SON écran et on en tire de faux
  diagnostics.
- **`WoopApp.swift` porte aussi le chantier PLAYER d'une autre session** :
  committer **par hunks** (checkout HEAD → réappliquer ses seuls hunks → add
  → **restaurer le fichier complet**). Ne pas oublier la restauration.

## Les bancs

`-homeV2` la page · `-cardsLab` les deux cards · `-menuLab` le menu au doigt ·
`-menuRejoue` le menu en boucle · `-semaineFaits <n>` · `-semaineMaterialise` ·
`-tirageFige <pt>` · `-fondRasant` (la chambre noire archivée) ·
`-phraseFige <p>` · `-arriveeFige <s>` · `-galetChoisit <n>`.
Tous se cumulent, et chacun s'ouvre **tout seul** : le simulateur ne sait pas
poser un doigt.

---

**Commence par lire `tools/home-v2/PLAN-HOME-V2.md`, puis dis-moi ce que tu
proposes pour le slider de départ.**
