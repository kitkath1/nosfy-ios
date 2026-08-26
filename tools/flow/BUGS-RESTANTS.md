# ANALYSE — les bugs restants du flow end-to-end

État au **26-08-2026, 19 h 05**. Ce fichier est **la passation** : il est écrit
pour une session qui n'a rien vu de la précédente.

Le chantier amont (les 14 points de l'audit du matin) est livré et raconté dans
`PLAN-STABILISATION-FLOW.md`, à côté. Ici ne vivent que **les verdicts du
téléphone du soir**, ceux de la deuxième salve.

---

## 0. LA RÈGLE DU CHANTIER

> **On veut d'abord pouvoir utiliser l'application de bout en bout sur le
> téléphone sans rencontrer de bugs.**

Rien de neuf tant que le flow ne tient pas : pas de backend, pas de règles de
gamification, pas d'architecture. Le parcours à valider :

`Onboarding → Home → démarrer séance → exercice → série → repos → retour
exercice → pill + pièces → Moments → Rewards → exercice suivant → fin de
séance → pièces cumulées → booster → ouverture → carte → collection → Home`

**Ses screenshots portent les vrais bugs. Ne jamais les ignorer.**

### Les contraintes du dépôt

- **Les commits sont TOUJOURS de Kathryn.** Aucun trailer `Co-Authored-By`,
  aucune mention « Generated with Claude Code », aucune signature. L'auteur
  reste la config git locale — jamais `--author`.
- **Une autre session travaille en parallèle** (le flow story). Ne pas toucher
  `StoryEnded.swift`, `StorySuite.swift`, `StoryFlow.swift`,
  `Woop/Media/story-*.mp4`, `tools/story/`. Elle a aussi `SessionSlate.swift`
  en main.
- **Committer par CHEMINS EXPLICITES**, jamais `git add -A`, et **relire
  `git log -3` avant chaque commit** (collision déjà payée deux fois).
- ⚠️ **Un build qui échoue n'est pas forcément le vôtre.** Vérifier l'horodatage
  du fichier fautif : l'autre session écrit en direct. Le 26-08 à 18 h 59,
  `SessionSlate.swift` était en cours d'écriture — erreur de compilation qui ne
  venait de personne d'ici.
- ⚠️ **`xcodebuild | grep` rend le code de `grep`** : un build échoué se lit
  « exit 0 » et on capture une app périmée. Piège payé deux fois.

---

## 1. LA SESSION ACTIVE — **traité, à re-vérifier au téléphone**

### Le verdict

> « J'ai lancé une session et réalisé 4 séries. Lorsque je reviens sur la partie
> **détail exercice sous le galet**, le player de session n'est plus visible.
> Conséquence directe : je n'ai plus aucun moyen de terminer la session depuis
> cet écran. […] le bouton `Stop` ne répond pas correctement ; cliquer dessus ne
> me permet pas réellement de terminer la session ; je ne peux pas non plus
> ouvrir / drag le menu correctement ; je me retrouve donc bloquée dans une
> session active sans moyen fiable de la fermer. »

C'était **trois bugs différents sous un seul symptôme**. Les trois sont traités
(commits `83bd44d` et `0c7ab1a`), aucun n'est validé par elle.

### 1a. Le stop ouvrait un panneau LOCAL — corrigé `83bd44d`

Le panneau de fin était un `fullScreenCover` porté par **la pastille
elle-même**. Trois pastilles sont montées dans l'app (home, page exos, card de
réglage, ardoise — quatre en fait) : **trois `stopAsk` qui s'ignorent**, et une
seconde feuille présentée depuis une vue enfouie ne va nulle part.

Le panneau de fin existe déjà à la racine : `PausePanneauHote`
(`Woop/Views/PlayerSeance.swift`), monté inconditionnellement dans le ZStack de
`WoopApp.mainBody`, **au-dessus du TabView**, câblé sur `terminerSeance()` —
donc sur la vraie clôture, le trophée, les pièces et la pop-up booster.

Le player ne présente plus rien, il **demande** :

```swift
DepartEtat.shared.pauseOuverte = true
```

### 1b. LE TAP NE PARTAIT JAMAIS — **la vraie cause**, corrigée `0c7ab1a`

Après 1a, elle a re-testé : **« ça marche toujours pas »**. Le câblage était
pourtant vérifié de bout en bout — `DepartEtat` est bien `@Observable`
(`DepartSeance.swift`), `PausePanneauHote` est monté sans condition et lit
`depart.pauseOuverte`, son `onTerminer` appelle `terminerSeance()`, et le
panneau reste monté en permanence (transparent, sourd quand il est vide), donc
ce n'est même pas un problème d'insertion.

La cause est en amont de tout ça :

> **Un `Button` SwiftUI posé sous un `DragGesture` d'ANCÊTRE se fait ANNULER dès
> que le drag reconnaît.** C'est exactement le bouton dans un `ScrollView` qui
> perd son highlight au premier millimètre de défilement.

Or la home porte le tirage **sur toute la page**
(`HomeNuit`, `.simultaneousGesture(tirageGeste)`), et son seuil est descendu à
**2 pt** — c'est moi qui l'ai descendu, ce matin, pour la fluidité du pull
qu'elle réclamait (mesurée 36,8 → 51 img/s au simulateur, **60,1 sur
l'appareil**). Le player en dock vit dessous. **Deux points de tremblement de
doigt suffisaient donc à tuer l'action du stop.**

Correctif : les deux boutons du player (`medallionButton`, `roundButton` dans
`WorkoutPill.swift`) **ne sont plus des `Button`**. Ils portent

```swift
.padding(8).contentShape(Circle())
.highPriorityGesture(TapGesture().onEnded { action() })
```

Un `highPriorityGesture` **passe devant les gestes d'ancêtre** : le stop gagne,
et la fluidité du pull n'est pas re-vendue pour le payer. Au passage la zone de
tap passe de 34 à 50 pt (le minimum d'Apple).

> **LOI À RETENIR** — dès qu'une page porte un drag large à seuil bas, tout
> bouton qu'elle couvre doit prendre un `highPriorityGesture`, ou il est mort.
> Chercher les autres : le slider, les cards, l'ardoise.

### 1c. Le menu qu'on n'attrape plus — corrigé `0c7ab1a`

Même cause, autre victime : « je ne peux pas non plus ouvrir / drag le menu
correctement ». Le drag page-large à 2 pt volait l'amorce du galet du menu.

Correctif : `.simultaneousGesture(enSeance ? nil : tirageGeste)`. **En séance le
tiroir est DÉJÀ ouvert** (c'est le départ qui l'a levé) — le tirage n'a plus
rien à faire, il ne peut que nuire. On le démonte, on ne remonte pas son seuil.

### 1d. Le player absent de la fiche détail — corrigé `0c7ab1a`

Mesuré : `ExerciseDetailView` montait **zéro** `WorkoutPill`, alors que
`HomeNuit`, `ExercisesView`, `ExerciseSetupCard` et `SessionSlate` en portent
une. De cet écran, il n'existait **littéralement aucun bouton pour finir**.

Il y entre en **overlay**, pas dans le flux : la page a déjà deux
`safeAreaInset` et une géométrie qu'on ne renégocie pas pour un dock. Il porte
la pilule flottante (`docked: false`) — le verdict « séance = le galet néon
SEUL » vaut pour la HOME, qui a une bande découverte ; la fiche n'en a pas.

### ⚠️ CE QUI RESTE À FAIRE ICI

- **Le verdict téléphone.** Rien de tout ça n'est validé par elle.
- **La chasse aux autres boutons affamés** (loi 1b). Le geste page-large existe
  toujours hors séance : tout ce qu'il couvre est suspect.
- Si le stop ne répond TOUJOURS pas : poser un `print` dans `demanderLaPause()`
  et un `.onChange(of: depart.pauseOuverte)` à la racine. Ça tranche en une
  minute entre « le tap ne part pas » et « le tap part, le panneau ne monte
  pas » — dans ce second cas, le panneau est à `.zIndex(5)` et la racine porte
  des étages jusqu'à 20 : chercher qui est monté au-dessus en séance.

---

## 2. LA ZONE ORANGE DE LA HOME EN SÉANCE — **non fait**

> « la card / zone orange actuelle est trop courte. Le menu se retrouve trop
> proche du widget `This Week`. Il faut allonger légèrement cette zone vers le
> bas, afin que le menu soit positionné clairement sous `This Week`. […] On doit
> conserver la même DA, simplement améliorer la hauteur et l'espacement
> vertical. »

**La géométrie, telle qu'elle est écrite** (`HomeNuit.swift`) :

| ce que c'est | où | valeur |
|---|---|---|
| la levée de la card en séance | `leveeSeance` | **140** |
| la levée du tiroir hors séance | `leveeTiroir` | la même, **140** |
| le repos de la card | `reposCard` | `-140` en séance |
| la bande découverte | — | 34 d'air · 62 de slider · 10 · 34 de réserve |
| la hauteur du player en dock | `WorkoutPill` | **76** |
| le padding du mobilier | — | `.padding(.bottom, leveeTiroir + 6)` |

La bande de 140 a été calée **pour le slider**, pas pour le player : les 34 du
haut sont mesurés sur la gerbe de poudre du commit (33,8 pt au-dessus du cadre).
En séance, c'est un player de 76 qui l'habite.

**Deux leviers, et il faut MESURER lequel :**
1. baisser la levée en séance (`leveeSeance` séparé de `leveeTiroir`) → la card
   orange descend, la zone s'allonge vers le bas — mais la bande se resserre
   sous les 76 pt du player ;
2. pousser le mobilier vers le bas en séance (le `.padding(.bottom)`) → l'air
   entre `This Week` et le menu grandit sans toucher à la card.

Son texte dit « allonger la zone » ET « le menu plus bas sous This Week » : ce
sont deux effets, probablement les deux leviers.

⚠️ **C'est du calage visuel pur. Ne pas le deviner.** Le banc existe :
`-homeSeance` force la home en séance sans base de données. Capturer, mesurer
les bords au gradient numpy, régler, re-capturer. **On mesure la géométrie, on
ne la déduit pas** — leçon déjà payée ce matin : une ancre de panneau déduite
de `expandedHeader + 4` donnait 367 quand la sonde disait **500,7**, et le
panneau mangeait le titre de l'exercice.

---

## 3. LES GALETS × 1,5 — **non fait**, le calcul est fait

> « Il faut les augmenter d'environ **×1,5** […] ne surtout pas les coller
> davantage entre eux. Au contraire : garder une vraie respiration, conserver
> une distance régulière, augmenter leur taille **sans réduire l'espacement
> visuel du parcours**. Le chemin doit sembler plus premium et plus physique,
> pas plus compact. »

**Ce qui est écrit aujourd'hui** — `EcranSpec.etapes` dans `DuolinguoPage.swift` :

```swift
for ecran in 0..<5 {
    for n in 0..<10 {
        let id = ecran * 10 + n
        let y: CGFloat = 700 - CGFloat(n) * 58        // PAS = 58
        let phase = 1.1 + 1.9 * Double(ecran)
        let jitter = sin(Double(id) * 12.9898) * 10
        let dx = min(max(78 * sin(0.82 * Double(n) + phase) + jitter, -92), 92)
        out.append(EtapeSpec(id: id, ecran: ecran, dx: dx, y: y,
                             tresor: n == 9))
    }
}
```

et au point de montage : `taille: e.tresor ? 78 : 62`.

**Le chiffre qui décide** : le pas est de **58** pour un galet de **62** — le
code le dit lui-même, « les pastilles se frôlent ». L'écart entre deux bords est
donc **négatif (−4)** : elles se chevauchent déjà. À ×1,5 (Ø 93) et pas
inchangé, elles se chevaucheraient de **35 pt**. Impossible.

**La solution tranchée : passer le chapitre de 10 à 9 nœuds et le pas à 97.**

| | aujourd'hui | proposé |
|---|---|---|
| nœuds par chapitre | 10 | **9** |
| pas vertical | 58 | **97** (874 / 9) |
| Ø galet | 62 | **93** (×1,5) |
| Ø nœud-lune | 78 | **117** (×1,5) |
| écart entre bords | **−4** | **+4** |

L'espacement **augmente** — la consigne est tenue. Et 9 nœuds, c'est exactement
ce que demande le point 4 : 7 séances + 2 lunes.

**Les pièges de ce changement :**
- `id = ecran * 10 + n` sert ailleurs : le budget de verre natif filtre sur
  `e.id % 10 <= 1 || e.id % 10 >= 8`. **Garder la base 10** (n va de 0 à 8, les
  ids sautent le 9) ou reprendre les deux endroits. Ne pas passer à `× 9`
  distraitement.
- La zone de tap est `Circle().inset(by: pad - 2)` avec `pad = 26`
  (`GaletEtape.swift`), donc Ø = `taille + 4`. À 93 elle vaut **97**, soit
  exactement le pas : elle ne vole pas le doigt du voisin, mais elle est à la
  limite. Ne pas grandir le `pad`.
- Tout est en base **874** (`let k = hauteur / 874.0`) : c'est un repère de
  maquette, pas la hauteur réelle. Rester dedans.
- `EtatDuo.nees` et `etat.etape` indexent des ids : vérifier le seed de démo.

---

## 4. LES NŒUDS LUNE / BOOSTER — **non fait**

> « un galet Lune **avant la 5e session** » et « un galet Lune **à la fin du
> chapitre / dernière session** ». « Au tap → utiliser **le même overlay
> d'ouverture de booster déjà existant**. Il ne faut pas recréer une nouvelle
> interface spécifique. »

**Ce qui existe déjà** :
- un seul nœud-lune par chapitre, le dernier (`tresor: n == 9`), Ø 78, glyphe
  `moon.fill` ;
- l'état `EtapeEtat.lune(dispo: Bool)` est écrit, avec sa matière (le plus
  sombre du chemin verrouillé, le plus vif disponible) ;
- `etatDe` le rend disponible quand `etat.etape >= e.id` ;
- **l'overlay booster existe et est monté à la racine** :
  `SacreEtat.shared.proposer()` (`Woop/Views/BoosterPopup.swift`) — la même
  école que le panneau de pause, un état partagé lu par la racine, « un onglet
  non encore construit n'écoute personne ».

**Ce qu'il reste, et c'est court** :
1. un second nœud-lune. Avec les 9 nœuds du point 3 :
   `S1 S2 S3 S4 [LUNE] S5 S6 S7 [LUNE]` → lunes à `n == 4` et `n == 8` ;
2. ajouter `var lune = false` à `EtapeSpec` (garder `tresor` pour le nœud de fin
   de chapitre, il sert ailleurs) et un `var moon: Bool { tresor || lune }` ;
3. `etatDe` : la première branche devient `if e.moon` ;
4. `dateDe` : le garde devient `guard !e.moon` (une lune ne porte pas de date) ;
5. `tape(_:)` : sur une lune **disponible**, appeler
   `SacreEtat.shared.proposer()` et **rien d'autre** — pas d'avance d'étape.
   Aujourd'hui `tape` ne connaît pas le cas trésor : il tombe dans la logique
   d'avancement.

---

## 5. FAIT / EN COURS / À VENIR — **à moitié fait** (`0c7ab1a`)

> « la différence entre accompli / actif / à venir n'est pas assez évidente. […]
> les galets futurs doivent avoir des **bordures beaucoup plus claires /
> visibles** […] On doit comprendre instantanément `FAIT / EN COURS / À VENIR`
> sans avoir besoin de réfléchir. »

### Le diagnostic

L'état ne se disait **que par trois pouièmes de lumière**. Dans `gainsEtat`
(`GaletEtape.swift`) : verrouillé `0.85`, prochain `0.92`, actif `1.0`, accompli
`0.95`. Et dans l'encre : `0.85 / 0.90 / 1.0 / 0.92`. **C'est illisible d'un
coup d'œil, et c'était exactement le verdict.** Le fichier assume ce choix (« la
photo est la loi, la matière ne meurt jamais ») — mais la lisibilité passe
avant.

### Ce qui est fait

Un **liseré d'état**, qui change de **nature** et pas d'intensité :

| état | bord |
|---|---|
| **à venir** (prochain) | anneau blanc **0,72**, épaisseur `taille × 0,032` |
| **à venir** (lointain) | anneau blanc **0,52**, `× 0,026` |
| **en cours** | **rien** — l'actif porte déjà le seul halo du chemin |
| **fait** | trait sourd 0,30, `× 0,018` |
| **raté** | rien — son encre est déjà fantôme |
| **lune** | l'or, 0,85 disponible / 0,30 verrouillée |

Valeurs hautes **exprès** : la leçon du halo est payée — un premier réglage
« élégant » donnait **+2,2** de luminance sur ses voisins, c'est-à-dire rien, et
il a fallu monter à 0,55 pour atteindre **+32,9**.

### Ce qui reste

- **L'état accompli plus affirmé** : « contenu clairement visible, date lisible,
  lumière contrôlée, impression que l'étape a réellement été validée ». Le
  liseré ne suffit pas ; `gainsEtat` et l'alpha de l'encre doivent trancher.
- **La flamme du futur** : « translucide mais identifiable ». Elle existe
  (`glyphe: "flame.fill"` pour les futurs) mais son alpha n'a pas été rejugé.
- **La mesure.** Capturer la route, découper chaque galet, comparer la luminance
  **sur les pixels clairs** — jamais en moyenne de ligne (règle payée : un juge
  qui affirme ne remplace pas une sonde qui mesure).

---

## 6. L'OVERLAY « COMMENCER LA SESSION » MAL RATTACHÉ — **non fait**

> « on ne comprend pas assez **à quel galet il appartient**. […] overlay plus
> proche du galet concerné ; petit lien visuel / halo ; continuité de lumière ;
> léger mouvement commun ; ligne très discrète ; ou simplement un positionnement
> plus évident. […] Pas avoir l'impression d'une card indépendante flottant dans
> le parcours. »

Le panneau est `PanneauDepartChemin` (`DuolinguoPage.swift`) — verre + mini-card
flamme/date (elle réutilise déjà `MiniCardJour`, la mini-card de « This Week »
de la home : les deux LISENT la même source, c'est voulu).

**La clé est déjà dans le fichier** : la position à l'écran du galet actif est
calculable exactement, c'est l'expression qui le pose —

```swift
.position(x: largeur / 2 + e.dx,
          y: (CGFloat(e.ecran) * 874 + e.y) * k)
```

Il suffit de la lire **une fois** et d'en placer les deux : le galet et le
panneau. Puis, dans l'ordre de coût croissant : ancrer le panneau sous le galet
(pas au centre de la page), tirer un filet d'un demi-point du galet au panneau,
faire déborder le halo de l'actif sur l'arête du panneau, et donner aux deux le
**même** bercement (`CapsuleVivante` existe déjà, périodes premières 11 s / 13 s
— ne pas les mettre en phase).

⚠️ **La leçon des deux objets qui doivent s'accorder** : ils LISENT la même
source, ils ne recopient pas la même valeur. J'ai créé ce matin un écart
« 26 AUG » (galet) contre « 26. AOÛT » (mini-card) à dix points l'un de l'autre,
parce que deux formateurs vivaient côte à côte.

---

## 7. LES GALETS DÉPLAÇABLES — **non fait, ET MAL LOCALISÉ**

> « je peux attraper certaines pastilles / galets et les déplacer librement dans
> l'interface. Elles peuvent partir pratiquement n'importe où, puis elles
> reviennent automatiquement à leur position. […] Les galets ne sont **pas
> draggable**. On peut éventuellement conserver une très légère réaction
> physique au toucher : scale, micro déplacement, compression, rebond. »

**⚠️ CE N'EST PAS LA ROUTE.** Vérifié dans le code : les galets du parcours
**ne bougent pas**. `GaletEtape` n'a aucun offset de drag ; il est posé en
`.position` et son `DragGesture(minimumDistance: 0)` ne sert qu'à deux choses —
lire `g.location` pour le micro-tilt vers le doigt, et **refuser** le geste
au-delà de 12 pt de course (« un tap, pas la fin d'un scroll qui passait par
là »). C'est déjà exactement la micro-interaction qu'elle décrit.

**Les trois suspects, classés :**

1. **LE GALET DU MENU** (`MenuNappe.swift`) — c'est lui qui s'attrape, se
   promène et **revient à sa place au lâcher**. Et ce chantier l'a rendu
   beaucoup plus facile à saisir : padding de prise 34 → **44** en vertical et
   30 → **56** en trailing, seuil d'extraction 12 → **5**. Son symptôme est
   apparu au moment où on a élargi sa prise. **C'est le plus probable.**
2. Les **pastilles des widgets de la home en édition** (`WidgetsCards.swift`,
   `DemandesCards` / le fantôme qu'on déplace pour réordonner).
3. Le **galet saisissable de la card reward** (la robe `.galet`, une pastille de
   vrai verre qu'on prend au doigt — mais elle vit dans la pop-up, pas « dans
   l'interface »).

**Ce qu'il faut faire : lui demander sur quel écran**, ou borner la course du
galet du menu à un petit rayon (une réaction, pas un déplacement) au lieu de le
laisser suivre le doigt partout. **Ne pas toucher `GaletEtape` : il est déjà
conforme.**

---

## 8. LE PLAYER QUI FLOTTE — **fait** (`83bd44d`), verdict attendu

> « le logo Lune du player flotte ; le bouton Stop flotte ; ils remontent /
> redescendent légèrement. Ils doivent être parfaitement fixes. »

Mesuré sur huit images de la page exercice, séance ouverte : le bord haut de la
dalle est à **794,67 pt sur les huit** — la géométrie ne bouge pas. Mais le
centroïde lumineux de la lune varie de **21 pt** et celui du médaillon de
**45 pt**, à une période de ~2,6 s. C'était donc **le souffle**, pas un offset
parasite.

La cause exacte : l'animation `repeatForever(value: lueur)` était posée
**au-dessus des `.padding` et du `.frame(height:)`** du pill. `lueur` ne pilote
que des opacités, mais elle bascule dans un `onAppear` qui tombe **pendant**
l'insertion animée du player (le `withAnimation` de 0,62 s de l'entrée en
séance) : la géométrie en vol héritait de l'aller-retour infini. Elle est
descendue sur les **deux seules vues qui lisent `lueur`**, et coupée en dock.

> **LOI** — une animation ne doit jamais couvrir plus que ce que sa valeur
> touche.

---

## 9. CE QUI TRAÎNE DES TOURS PRÉCÉDENTS

- **La sonde vidéo n'existe toujours pas.** `AVPlayerItem.accessLog()` →
  `numberOfStalls`, `numberOfDroppedVideoFrames`. Le cellier (`AssetsVideo`) et
  le préroll sont posés mais **jamais prouvés**, et
  ⚠️ **`SondeCadence` est AVEUGLE à un décodeur en retard** : un display link à
  60 ne voit pas une vidéo qui cale. C'est le trou de mesure du chantier.
- **Le son de la vidéo d'accueil** (« il y a un son en plus, il faut l'atténuer
  à la fin »). Vérifié : `onb-arrivee.mp4` n'a **aucune piste audio**, le player
  est `isMuted`, aucun `AVAudioPlayer` ne tourne sur ce chemin. Le seul candidat
  est le **Taptic Engine** — la partition haptique de 3,9 s du splash,
  `hapticContinuous` jusqu'à 0,70. **Lui demander ce qu'elle entend avant
  d'atténuer la mauvaise chose.** Elle n'a pas encore répondu.
- Les **chiffres des widgets** ne s'animent pas.
- Le **vrai picker natif d'Apple** (décision D4) : pari minimal fait.
- La **direction artistique du portail lune** attend son verdict.
- **§14, l'expérience de fin**, volontairement non touchée.
- Deux choses restent du **démo assumé** en attendant le backend (décision D2) :
  les jours « faits » du parcours (`EtatDuo.faits`, motif déterministe) et
  `DecideurSerie.pour` qui est **une place, pas un moteur**.

---

## 10. LES BANCS

| argument | ce qu'il ouvre |
|---|---|
| `-homeSeance` | la home en séance, sans base |
| `-pullAuto` | un doigt synthétique qui écrit `tirage` à 60 Hz |
| `-pullSonde <1-7>` | isole le mobilier, la card vidéo, chaque flou |
| `-flouAvant` | l'A/B des flous **sur le même binaire** |
| `-menuSonde` | le menu sans son flou |
| `-fps` | la cadence à l'écran |
| `-serieFin <n>` | l'issue de la n-ième série (1 pill · 3 Moment · 5 popup · 10 rare) |
| `-portailFige <s>` | la traversée de la lune figée |
| `-duoLab`, `-duoGalets`, `-homeChemin` | la route |
| `-corbeauxEchelle <n>`, `-corbeauxOff` | les corbeaux du splash |

Simulateurs : `kat-popup`, `kat-duo`, `kat-exos`, `kat-flow-15`.
Appareil : « iPhone de Frédéric » — ⚠️ les arguments de `devicectl` se passent
**APRÈS `--`**.

---

## 11. LES LOIS PAYÉES, À NE PAS RÉAPPRENDRE

1. **Un `Button` sous un `DragGesture` d'ancêtre est mort** dès que le drag
   reconnaît. Remède : `highPriorityGesture`. *(payée aujourd'hui — c'était le
   stop)*
2. **Une animation ne couvre jamais plus que ce que sa valeur touche.**
   *(payée aujourd'hui — c'était le player qui flotte)*
3. **On mesure la géométrie, on ne la déduit pas.** *(75 pt d'erreur sur l'ancre
   d'un panneau)*
4. **Un réglage visuel qui ne se mesure pas n'existe pas.** *(+2,2 de luminance
   = rien ; il en fallait +32,9)*
5. **Mesurer une couleur sur les PIXELS CLAIRS**, jamais en moyenne de ligne.
6. **Quand deux objets doivent s'accorder, ils LISENT la même source.**
7. **Une transition ne finit jamais sur un gris uniforme.**
8. **`xcodebuild | grep` rend le code de `grep`.**
9. **Deux relances rapides du simulateur donnent des captures CROISÉES** :
   `UserDefaults` se met à jour, `CommandLine` garde les anciens arguments.
   Laisser **5 s** entre le terminate et le launch.
10. **Un juge qui affirme ne remplace pas une sonde qui mesure.**
