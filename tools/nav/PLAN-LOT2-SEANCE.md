# PLAN LOT 2 — LA SÉANCE EST IMPRATICABLE

Analyse du 04-09, sur le verdict téléphone : « quand je clique sur active session il y
a de gros bugs, la navigation redevient des petits points alors qu'on avait dit non,
impossible de cliquer sur la bulle, pas d'overlay, l'application devient impraticable
et chauffe en permanence. »

**Rien n'a été modifié.** Chaque cause ci-dessous porte un `fichier:ligne` LU. Ce qui
n'a pas pu être prouvé par lecture est marqué « soupçon » et rangé en §3.

---

## 1 · Ce qui se passe

Le pivot du 04-09 a tué le **geste** du repli de la nav, mais pas son **état** : le
châssis pose encore « nav repliée » à chaque départ de séance, et plus rien ne peut la
redéployer — voilà les petits points, et voilà pourquoi le premier tap ne navigue pas.

La bulle, elle, est montée **59 pt trop bas** : ses cotes sont écrites en pixels
d'écran, mais on l'a posée dans la zone qui commence sous l'heure. Poussée sur le côté,
elle se fait avaler par « l'île » — et un tap sur l'île ne fait que l'en sortir, il
n'ouvre jamais le player : c'est exactement « impossible de cliquer, pas d'overlay ».

La chauffe est indépendante des deux : trois horloges de la bulle tournent en continu
dès la première seconde de séance, dont une vague de braises redessinée 30 fois par
seconde **à l'intérieur** d'une ombre de rayon 22 qui doit être recalculée avec elle.

---

## 2 · L'ordre des gestes

Du plus haut rendement au plus bas. **1 à 5 rendent l'app utilisable. 6 à 10 coupent la
chauffe. 11 et 12 rendent le doigt fluide.**

---

### ① Démonter le repli mort — la nav redevient une nav

**Où** · `Woop/WoopApp.swift:1235-1237` · `Woop/Views/NavEncre.swift:117`, `:133`,
`:318`, `:584-588`, `:630-633`

**Ce qu'on change**

- Supprimer l'écrivain du châssis : `.onChange(of: active != nil) { _, enSeance in if
  enSeance { NavEtat.shared.mini = true } }` (WoopApp.swift:1235-1237).
- Retirer `mini` de la chaîne de dessin : `navH` devient la constante 42
  (NavEncre.swift:318, aujourd'hui `mini ? 20 : 42`), `NavBande` cesse de monter
  `NavMini` — les quatre points (NavEncre.swift:586, et les points eux-mêmes :545-563).
- Supprimer le garde de `aller()` : `guard !etat.mini else { etat.poser(false); return }`
  (NavEncre.swift:630-633).

**Ce que ça répare** · Les petits points disparaissent. Le premier tap navigue au lieu
de « déplier ». C'est mot pour mot son verdict n° 1.

**Pourquoi c'est un piège fermé aujourd'hui** · `mini` n'est plus remis à `false` par
personne : le pan de bande refuse désormais tout départ hors dalle (`PanBande.swift:116-123`),
et « tout tap sur la bande déploie » a été retiré (`NavEncre.swift:600-603`). Une fois
posé, il ne se lève plus jamais — et il ne se réinitialise pas non plus à la fin de la
séance.

**Risque de régression** · Faible. `mini` ne pilote plus que du dessin et une hauteur.
⚠️ mais `navH` est lu par la card pour réserver sa place : vérifier au téléphone que la
card ne saute pas de 22 pt au départ de séance (c'était le mouvement qu'on voyait).

---

### ② Poser la bulle en coordonnées d'écran — elle est 59 pt trop bas

**Où** · `Woop/WoopApp.swift:1399-1409` (le montage) · `Woop/Views/PiluleVagabonde.swift:443-444`
(la loi du composant, écrite noir sur blanc)

**Ce qu'on change** · Ajouter `.ignoresSafeArea()` au montage de `PiluleVagabonde` dans
le châssis (et donc à `GrandPlayer`, `WoopApp.swift:1417-1428`, qui reçoit
`UIScreen.main.bounds.size`, une cote physique elle aussi).

**La preuve** · Le composant le DEMANDE dans son propre en-tête : « LA DYNAMIC ISLAND —
ses cotes (iPhone 15/15 Pro, coordonnées **PHYSIQUES : l'hôte de la pilule doit ignorer
la zone sûre**) » (PiluleVagabonde.swift:443-444). Le châssis ne l'ignore pas : dans tout
`mainBody` (WoopApp.swift:1121 → ~1648) il n'y a **aucun** `.ignoresSafeArea()` sur la
ZStack racine (les seuls sont sur des enfants : `:1464` la nav, `:1601` un fond noir).

**Ce que ça répare, au point près (iPhone 15, safeTop 59)**

- La pose basse autorisée est `utile.upperBound = hauteur − 96 = 756` (WoopApp.swift:1400).
  Rendue à 59 pt plus bas, elle tombe à 815 : la bulle fait 96 de haut, elle occupe donc
  767 → 863 — la nav vit à 792 → 834, l'écran s'arrête à 852. **Lâchée en bas, la bulle
  est posée SUR la nav et déborde de l'écran.**
- L'île est dessinée à `IleGeo.centreY = 29,65` (PiluleVagabonde.swift:447-450, position
  posée à `:610`). Rendue à 89 : ce n'est plus la bulle rangée dans la Dynamic Island,
  **c'est une barre noire en travers du haut de page**, 60 pt sous la vraie île.

**Risque de régression** · Moyen, et il est mesurable : `utile` (WoopApp.swift:1400) a
peut-être été réglé « à l'œil » POUR compenser ce décalage. Après le correctif, refaire
un tour de pose haute / pose basse au doigt avant de sceller.

---

### ③ L'île doit ouvrir le player — sinon c'est un trou

**Où** · `Woop/Views/PiluleVagabonde.swift:697-701` (`sortirDeLIle`) · `:605` (le tap) ·
`:371-374` (l'entrée) · `:329` (l'état)

**Ce qui se passe** · Lâchée avec `xFin < 70` ou `xFin > W − 70` (PiluleVagabonde.swift:371),
c'est-à-dire après un simple déplacement **latéral de ~125 pt**, la bulle est aspirée
dans l'île. À partir de là `body` ne monte plus `corps` (`:514`) : **le tap qui ouvre le
player n'existe plus**. Le seul geste restant est `.onTapGesture { sortirDeLIle() }`
(`:605`) — il la fait ressortir, il n'ouvre rien.

**Et ça ne se répare pas tout seul** · `dansIle` vit dans `PiluleEtat.shared`, un
singleton (`:327-329`). Les cinq seules occurrences dans tout `Woop/` sont sa déclaration,
son écriture à `true` (`:373`), sa lecture (`:514`), et `sortirDeLIle` (`:697`, `:700`).
**Aucune fin de séance, aucun départ de séance ne le remet à `false`.** Une fois dedans,
on y reste — y compris à la séance suivante.

**Ce qu'on change** · Deux gestes, à trancher par elle :

- (a) **minimal** : le tap sur l'île OUVRE le player (`onOuvrir()`), et c'est un drag
  qui l'en sort (le drag est déjà là, `:607-609`) ;
- (b) **prudent** : élargir la porte d'entrée — un jet latéral de 125 pt est trop peu
  pour un geste accidentel ; et remettre `dansIle = false` au départ de séance.

**Ce que ça répare** · « Impossible de cliquer sur la bulle, pas d'overlay. » C'est le
chemin le plus probable pour ce verdict-là : elle a déplacé la bulle, elle est partie
dans l'île, et plus rien n'ouvrait le player.

**Risque de régression** · Faible, mais c'est un choix de design, pas une correction :
elle doit dire ce que fait le tap sur l'île.

---

### ④ La nav peut disparaître pour de bon dans l'onglet Exercices

**Où** · `Woop/Views/ExerciseDetailView.swift:618` · `Woop/Views/PageCard.swift:167-176`,
`:227` · `Woop/WoopApp.swift:1459`

**Certitude : soupçon fort** (le chemin est lu, l'issue demande le téléphone).

**Le mécanisme** · La nav du châssis n'est montée que si `NavEtat.shared.bandeVisiblePubliee`
(WoopApp.swift:1459). Ce drapeau est **global**, et deux `PageCard` du **même onglet**
l'écrivent : la liste (`ExercisesView.swift:478`, `bandeVisible: !etat.clavier`) et la
fiche poussée (`ExerciseDetailView.swift:618`, `bandeVisible: running == nil && flood < 0.01`).
Pendant un exercice en cours, la fiche publie `false` : **la nav n'existe plus du tout.**
Au retour à la liste, la fiche est démontée — et le `onChange(of: bandeVisible)` de la
liste (PageCard.swift:167) ne se rejoue pas, puisque SA valeur n'a pas bougé. Le seul
autre republieur est `onGeometryChange` (`:227`), qui ne parle que si la géométrie change.

**Ce que ça répare** · « L'application devient impraticable » dans sa forme la plus
brutale : plus aucune barre de navigation à l'écran, et donc plus aucune sortie.

**Ce qu'on change** · Un seul écrivain. Soit la fiche cesse de publier (elle n'est pas
la card de l'onglet), soit la publication porte l'identité de qui écrit et le dernier
démonté rend la main.

**Risque de régression** · Moyen : c'est ce drapeau qui fait disparaître la nav quand le
clavier sort. À refaire au banc clavier.

---

### ⑤ Le grand player prend tout l'écran avant même de se voir

**Où** · `Woop/Views/PiluleVagabonde.swift:1246` (`.frame(width:height:)` plein écran) ·
`:1265-1273` (les offsets) · `Woop/WoopApp.swift:1417`

**Le mécanisme** · Le player est monté dès `morphPlayer > 0.001` (WoopApp.swift:1417),
à `zIndex(8.4)` — **au-dessus de la bulle (6)**. Il est plein écran (`:1246`), il est
descendu par un `.offset` (`:1267`) et effacé par `.opacity` (`:1264`). Or la loi du
dépôt est écrite dans son propre commentaire : **un offset déplace les pixels, pas la
zone tactile** — et une vue à opacité 0 reste parfaitement tappable. Pendant toute la
montée (ressort de 0,62 s, WoopApp.swift:1049-1052) et toute la descente, **tout l'écran
appartient à un player invisible.**

**Ce qu'on change** · `.allowsHitTesting(morph > 0.98)` sur le GrandPlayer.

**Risque de régression** · Très faible. C'est une ligne.

---

### ⑥ La vague de braises de la bulle : 30 images/s, toute la séance, dans une ombre

**Où** · `Woop/Views/PiluleVagabonde.swift:833-835` · `:106-107` · `:147-148` ·
`:715`, `:718`, `:719`

**Le mécanisme** · La robe au repos monte `BraisesVague(force: 0.42, …, fige: etat.enMouvement)`
(`:833-835`). `enMouvement` vaut `enDrag || enVol` (`:336`) : **au repos il est faux**,
donc la `TimelineView(.animation(minimumInterval: 1/30, paused: fige))` (`:106-107`)
tourne 30 fois par seconde **du début à la fin de la séance**. Chaque tour : un `Canvas`
qui remplit 9 dégradés, puis `.blur(radius: 11)` (`:147`), puis `.blendMode(.plusLighter)`
(`:148`) — une passe hors écran. Et tout ça vit dans le `.background { robe }` de `corps`
(`:715`), donc **à l'intérieur** du `.compositingGroup()` (`:718`) suivi de
`.shadow(radius: 22, y: 10)` (`:719`) : une **seconde** gaussienne sur tout le groupe,
recalculée elle aussi 30 fois par seconde.

**Ce qu'on change** · Trois gestes indépendants, du moins cher au plus cher :

- (a) sortir la vague du groupe qui porte l'ombre — l'ombre se dessine sur la FORME,
  pas sur le contenu animé ;
- (b) descendre la mini vague à 12–15 Hz (69 pt de haut, floutés à 11 : ça ne se lit pas
  à 30) ;
- (c) lui donner une vraie porte de repos — elle chante quelques secondes après un
  changement d'exercice, puis se tait.

**Risque de régression** · Aucun sur la fonction, tout sur le rendu : c'est SA braise.
(a) et (b) sont invisibles à l'œil, (c) est un choix qu'elle doit valider.

---

### ⑦ L'invite « Choisissez un exercice » bat à 30 Hz et n'a aucune porte

**Où** · `Woop/WoopApp.swift:1094-1096` · `Woop/Views/PiluleVagabonde.swift:165-181`

**Le mécanisme** · Tant qu'aucun exercice n'est choisi, la bulle affiche
`InviteAnimee(taille: 17)` (WoopApp.swift:1095). Sa `TimelineView(.animation(minimumInterval:
1/30))` (`PiluleVagabonde.swift:165`) **n'a pas de `paused:`** : elle balaye un dégradé
sur du texte 30 fois par seconde. C'est précisément l'état du **début de chaque séance**
— avant qu'elle ait choisi son exercice, c'est-à-dire pendant tout le moment où elle
tripote la bulle.

**Ce qu'on change** · Un `paused:` (le mouvement de la bulle, l'onglet caché), ou une
lueur qui passe et s'arrête.

**Risque de régression** · Nul.

---

### ⑧ Deux sondes de debug tournent en production

**Où** · `Woop/Views/PiluleVagabonde.swift:754-756` · `:1278` ·
`Woop/Views/SondeCadence.swift:64-69`, `:83-84`

**Le mécanisme** · `SondeCadence` démarre son `CADisplayLink` sans condition, dans
`makeUIView` (`SondeCadence.swift:66-68`). Le garde `-fps` ne vit **que** dans l'extension
`View.sondeCadence(_:)` (`:83-84`). Or la bulle et le grand player l'appellent **en
direct** : `SondeCadence(quoi: "pilule")` (PiluleVagabonde.swift:755) et
`SondeCadence(quoi: "player-morph")` (`:1278`). Résultat : deux display links réveillent
le fil principal à chaque battement d'écran, **et impriment une ligne par seconde**, sur
l'app de production, pendant toute la séance.

**Ce qu'on change** · Passer par `.sondeCadence("pilule")`, ou ajouter le même garde
`-fps` dans `SondeCadence.makeUIView`. Deux lignes.

**Risque de régression** · Nul. C'est de la dette pure.

**Gain probable** · Un display link permanent empêche l'écran de descendre son taux de
rafraîchissement au repos. Sur un ProMotion, c'est de la chaleur gratuite.

---

### ⑨ L'île est un moteur à elle toute seule — et c'est là qu'elle s'est retrouvée coincée

**Où** · `Woop/Views/PiluleVagabonde.swift:596-600` · `:658-676` · `:690-693`

**Le mécanisme** · Quand la bulle est dans l'île (voir ③), le corps monté est
`TimelineView(.animation(minimumInterval: 1/30))` (`:596`), et son contenu redessine à
chaque image : trois nappes floutées à 24, 12 et 6 (`:661`, `:667`, `:675`) **plus deux
ombres dont le rayon est animé** (`:690-691`, `radius: 7 + 5 * s`). Une ombre à rayon
variable ne peut pas être mise en cache : elle est recalculée à chaque image.

**Ce qu'on change** · Rayons d'ombre FIXES (faire varier l'opacité, pas le rayon), et la
cadence à 12–15 Hz.

**Risque de régression** · Rendu seulement. Le battement « pulsar » se garde à 15 Hz.

---

### ⑩ Le verre natif interactif reste allumé, et l'ancien player est monté pour rien

**Où** · `Woop/Views/PiluleVagabonde.swift:823-827`, `:487-493` ·
`Woop/Views/PlayerMonde.swift:329`, `:462` · `Woop/WoopApp.swift:1387`

**Deux choses, même geste : à MESURER avant de trancher.**

- **Le verre** · `Color.clear.glassEffect(.regular.tint(...).interactive(), …)`
  (`PiluleVagabonde.swift:823-827`) est allumé en permanence, **y compris sous le doigt** :
  la doublure mate qui devait le remplacer pendant le drag est enfermée derrière un
  drapeau de banc, `mateAuDrag = CommandLine.arguments.contains("-piluleMate")`
  (`:490-493`) — donc `false` au téléphone, donc la branche mate (`:815`) n'est **jamais**
  prise. La loi du dépôt dit qu'un verre animé fait tomber 60 → 14 img/s ; le commentaire
  `:485-489` dit honnêtement que ça n'a pas été mesuré sur le natif d'iOS 26. **Le geste
  est de MESURER** (`-fps` puis `-fps -piluleMate`), pas de décider ici.
- **L'ancien player** · `PlayerMondeHote(seance: active, …)` est monté au châssis
  (`WoopApp.swift:1387`) et son corps naît dès `seance != nil` (`PlayerMonde.swift:329`) —
  arbre complet, plus un `PanMaitre()` posé sur la FENÊTRE (`:462`). Or **plus rien ne
  l'ouvre** : les deux seuls `etat.ouvrir()` du fichier (`:578`, `:621`) sont dans des
  tâches de banc. Il est inoffensif pour les touchers (son corps est
  `.allowsHitTesting(etat.ouvert)`, `:351` ; la porte du pan est
  `PlayerEtat.shared.ouvert`, `:735-740`) — mais c'est un arbre entier monté pour rien
  pendant toute la séance. Le monter sous condition coûte une ligne.

**Risque de régression** · Pour le verre : c'est un verdict d'œil, pas de code. Pour
l'ancien player : vérifier qu'aucun autre chemin (stop, clôture) ne compte sur sa
présence — `onChange(of: seance == nil)` (`:360-362`) y vit.

---

### ⑪ La bulle entière se reconstruit à chaque image du doigt

**Où** · `Woop/Views/PiluleVagabonde.swift:752` · `:522` · `:348` · `:406-417` ·
`:426-434`

**Le mécanisme** · `corps` — appelé depuis `body` (`:522`), donc dans la portée de suivi
d'observation — fait `.offset(etat.dessin)` (`:752`). Or `dessin` est écrit **à chaque
événement du doigt** (`suivre()`, `:348`) puis **à chaque battement d'écran** par le
`CADisplayLink` du vol de rappel (`:406-417`, moteur `:426-434`). Lire une propriété
d'`@Observable` dans le body rend TOUT le body dépendant : à chaque image, SwiftUI
reconstruit `contenu()` (`:712` → `contenuPilule`, WoopApp.swift:1082-1119 : la
mini-card du jour, l'invite 30 Hz, la TimelineView du chrono, le médaillon stop avec ses
deux dégradés angulaires, son `.blur(1.0)` et ses deux `.plusLighter`), puis `robe`
(`:715`), puis le `compositingGroup` + `shadow 22` (`:718-719`), puis le ticket (`:723`).

C'est mot pour mot le piège déjà payé : **un @State écrit par image sur la vue qui
contient tout.**

**Ce qu'on change** · Le patron existe déjà dans le dépôt, appliqué au player :
`OffsetVol` (`PlayerMonde.swift:919-926`), un `ViewModifier` minuscule qui SEUL relit la
valeur. Le corps de la bulle ne doit alors plus jamais lire `dessin`.

**Risque de régression** · Faible, mais réel : ⚠️ `.offset` déplace les pixels et **pas**
la zone tactile (39f95f9). Aujourd'hui la position commise est du vrai layout (`.position`,
`:751`) et seul le résidu est en offset — le correctif ne change pas ça, mais il faut
refouetter le tap après un drag.

---

### ⑫ Le halo de cible relit la position du doigt 30 fois par seconde, pendant le drag

**Où** · `Woop/Views/PiluleVagabonde.swift:521` · `:534-541` · `:551`

**Le mécanisme** · `body` lit `etat.enDrag` (`:521`) : pendant le drag, une **seconde**
horloge à 30 Hz démarre (`cibleIle`, `:534`), et son corps relit `etat.dessin.height`
(`:551`) pour dessiner un halo `.blur(radius: 22)` à échelle animée. Deux horloges plus
la reconstruction de ⑪, sur le même fil, pendant que le doigt bouge : c'est là que ça
décroche.

**Ce qu'on change** · Le halo lit une valeur ARRONDIE (par ex. `proche` quantifiée par
pas de 0,05) pour ne se rejouer que quand ça se voit, ou il vit dans son propre modifier.

**Risque de régression** · Nul à l'œil.

---

**Et deux micro-correctifs indépendants, une fois le player ouvrable** (ils ne se voient
pas tant qu'on n'a pas obtenu d'overlay, mais ils sont réels) :

- `PiluleVagabonde.swift:1267` puis `:1273` appliquent `fermeture` **deux fois** :
  l'écran descend au **double** de la vitesse du doigt ;
- `.simultaneousGesture(dragFermeture)` (`:1268`) est posé plein écran et
  `partition.scrollDisabled(enGeste)` (`:1239`) coupe le scroll de la partition dès le
  premier pixel de geste.

---

## 3 · Ce qu'on ne peut pas prouver sans le téléphone

- **Ce qui chauffe le PLUS.** Les moteurs sont lus et comptés, leur poids relatif ne se
  lit pas. Il existe déjà un barreau (`-sansBord`, `BordSeance.swift:39`) et un relevé
  du 03-09 (`CHAUFFE-HOME.md:179-187`) qui dit : ruban éteint, **ça chauffe quand même**.
  La méthode est l'A/B, un moteur à la fois, main sur le dos, pas la lecture.
- **Le verre natif `.interactive()`** (⑩). La loi 60 → 14 img/s a été mesurée sur
  l'ANCIEN verre ; le natif d'iOS 26 n'a jamais été mesuré ici. `-fps` puis
  `-fps -piluleMate` tranchera.
- **La nav qui disparaît pour de bon** (④). Le chemin est lu, l'issue dépend de l'ordre
  réel des démontages SwiftUI au `pop` — ça se constate, ça ne se déduit pas.
- **Le décalage de 59 pt** (②). Il est certain par construction ; ce qui ne l'est pas,
  c'est si `utile` (WoopApp.swift:1400) avait été réglé à l'œil POUR le compenser. Une
  capture avant/après le dira en dix secondes.
- **Une `TimelineView` d'onglet caché tique-t-elle ?** Question déjà classée
  NON PROUVABLE À LA LECTURE dans le dépôt (`ANALYSE-CHAUFFE-GESTES.md:91`). On ne la
  rouvre pas par déduction.

---

## 4 · Les causes écartées

- **Le grand player qui rejoue son corps à chaque image + `fermeture` compté deux fois** —
  le double offset est réel (`:1267`/`:1273`), mais le chemin n'est jamais atteint : elle
  dit « pas d'overlay », donc le player ne s'est pas ouvert. Gardé en micro-correctif.
- **Les horloges de la home qui tourneraient sous l'onglet caché** — les quatre moteurs
  cités sont coupés au MONTAGE par `!enSeance` (HomeNuit.swift:3542, `:3568`), l'un est
  du code de banc (`:2966`), un autre n'a aucun site d'appel. Aucune ne survit à une séance.
- **Le ruban de séance (`BordSeance`) multiplié par le nombre de PageCard** — il pèse,
  mais l'A/B `-sansBord` du 03-09 a déjà montré que l'app chauffe sans lui
  (`CHAUFFE-HOME.md:179-187`), il est byte pour byte celui d'avant le pivot (dernier
  commit 7635d81), et le ×N ne tient pas au compte (l'onglet Progression est archivé,
  le Profil n'a pas de PageCard). Dette réelle, pas la cause du 04-09.
- **Le second Canvas de braises, plein écran, dans le grand player** — même mur : le
  player n'est monté que si `morphPlayer > 0.001` (WoopApp.swift:1417), et `fermer()`
  (`:1453-1458`) le démonte. Il n'existe pas « en permanence ».
- **La bulle laissée vivante DERRIÈRE le grand player (le rideau)** — la structure est
  réelle, l'état décrit n'est pas celui qu'elle a vécu : sans overlay, il n'y a rien
  derrière quoi rester. Et tous les moteurs cités s'allument au DÉPART de séance, pas au
  tap : ils ne peuvent pas expliquer « la chauffe commence au clic ».
- **Les deux pans de fenêtre** — hors de cause : `NavPanHote` (`PanBande.swift:43`) n'est
  **instancié nulle part** (grep : la seule occurrence est sa déclaration), et la porte de
  `PanMaitre` est `PlayerEtat.shared.ouvert` (`PlayerMonde.swift:735-740`), qui reste faux
  puisque plus rien n'ouvre l'ancien player.
