---
name: woop-architecture
description: Les lois d'architecture et les pièges PAYÉS de l'app Woop (SwiftUI + SceneKit + Metal). À lire AVANT d'écrire ou de modifier une vue, un geste, un shader, une couche vidéo ou un asset de ce dépôt — et avant de déclarer qu'un changement marche. Couvre le mur du type-checker, les pages qui se ré-évaluent par image, l'identité des données d'un ForEach, l'arbitrage des gestes, la loi du verre, les couches AVPlayer/UIKit, les stitchables Metal, la discipline de build et de mesure, et la coexistence de sessions parallèles.
---

# Écrire du code dans Woop

Ce dépôt n'a pas de tests. Ce qui tient lieu de filet, ce sont **les lois
ci-dessous** — chacune écrite après un bug qui a coûté des heures ou des jours.
Elles ne sont pas des préférences de style : ce sont des causes racines.

**Trois principes cardinaux**, dont tout le reste découle :

1. **Un corps de vue est une ADDITION DE VUES NOMMÉES.** Pas une expression.
2. **Rien ne se lit dans le corps d'une page s'il change à chaque image.**
3. **Rien n'est « fait » sans une MESURE.** Un jugement n'est pas une donnée.

---

## 1. Écrire une vue — le mur du type-checker

**Le corps d'une vue est une addition de vues NOMMÉES, jamais un empilement
d'expressions.** Toute fermeture de plus de deux lignes posée dans un appel du
corps rapproche du mur — et **le mur ne se voit qu'en build PROPRE** :

> `unable to type-check this expression in reasonable time`

Payé au commit `337a6e3` : `WoopApp.mainBody` avait cessé d'être
type-checkable. Les builds Xcode quotidiens sont INCRÉMENTAUX et réutilisaient
leur cache — pendant ce temps ni archive, ni TestFlight, ni un autre Mac ne
pouvaient construire l'app. **Aucun contournement ne marche** (tous essayés :
`-solver-expression-time-threshold`, `-solver-memory-threshold`,
`SWIFT_ENABLE_BATCH_MODE=NO`, `SWIFT_COMPILATION_MODE=singlefile`). Il faut
DÉCOUPER.

En pratique :

- une condition composée sort en `private var xVisible: Bool` ;
- une fermeture d'action sort en `private func` ;
- une sous-partie de l'écran sort en `private var xxx: some View` ou, mieux,
  en `struct` à part ;
- un tableau de couleurs ou de constantes sort en `static let` (le
  type-checker mord aussi sur les tables de couleurs).

---

## 2. La page qui se ré-évalue par image

**Symptômes** : « ça saccade », « ça colle au doigt », « la molette n'est pas
fluide ». Ce n'est JAMAIS un réglage d'animation. C'est qu'un `@State` écrit à
la cadence de l'écran vit sur la vue qui contient tout.

Les six règles, dans cet ordre :

1. **Ce qui se calcule par image se CACHE.** Une liste dérivée devient un
   `@State` rempli sur `onChange` de sa source — jamais une propriété calculée
   relue par le corps.
2. **L'état vivant vit dans un `@Observable`**, pas en `@State` sur la page :
   l'Observation ne réveille QUE la vue qui LIT la propriété touchée.
3. **Les enfants lourds sont des `struct View` aux entrées STABLES** (tableau
   caché, `CGFloat`, référence d'observable, `@Binding`). **Jamais une closure
   en propriété** : SwiftUI ne peut plus prouver l'égalité et rejoue le corps à
   chaque passage du parent.
4. **Ce qui se redessine par image passe en `Canvas`** — un dessin, pas N
   calques. ⚠️ Un `Canvas` n'est pas animable : lui donner `Animatable` sur
   toutes ses valeurs pilotes (`AnimatablePair` s'il y en a plusieurs), sinon
   les changements d'état CLAQUENT au lieu de monter en fondu.
5. **Ce qui bouge par image ne doit JAMAIS changer une TAILLE.** Un
   `padding`/`frame` animé au doigt re-layoute tout ce qu'il contient. Une
   couche `AVPlayerLayer` redimensionnée à 60 Hz **est** le lag. Remède :
   un **masque** (`clipShape` d'une `Shape` `Animatable`) + des **offsets**.
6. **Ce qui BOUGE par image passe par un `ViewModifier`** — `body(content:)`
   reçoit l'arbre DÉJÀ construit ; le relire soixante fois ne reconstruit rien.

Autres coûts mesurés, à connaître : un `Canvas` plein écran **rasterise toute
sa surface même vide** ; un verre natif animé fait tomber 60 → 14 img/s ; un
`blur` par objet coûte 27 img/s ; une `SCNView` effacée par l'opacité **rend
quand même** (il faut la mettre en pause).

---

## 3. L'identité des données — ForEach, `.equatable()`, `@State` invisible

**Un `ForEach` ne rejoue ses rangées que quand SES DONNÉES changent.**

- ❌ `if etat.contains(id)` capturé dans la closure du ForEach → rangées gelées
  à vie sur leur image de naissance.
- ❌ un booléen en propriété de vue-enfant → tient pour les taps, PAS pour
  l'ensemencement de naissance.
- ✅ **La seule forme robuste : le dépliage EST DANS LA DONNÉE.**
  `RangDonnee: Identifiable, Equatable` (groupe + déplié) — chaque bascule
  devient un changement de données.

**Corollaires payés :**

- `ForEach(Array(x.enumerated()), id: \.element.id)` — un `id:` par chemin de
  clé REMPLACE l'identité de la donnée et regèle les rangées. Le rang descend
  DANS la donnée, la boucle reste `ForEach(rangs)` nue.
- **Un `@State` dans une vue montée en `.equatable()` est INVISIBLE** :
  `EquatableView` court-circuite l'invalidation. Remède : l'état remonte chez
  l'hôte en `@Binding` **ET** entre dans le `==`. Ne jamais le redescendre.

---

## 4. Les gestes

- **Un `Button` sous un `DragGesture` d'ANCÊTRE se fait annuler** dès que le
  drag reconnaît (2 pt de tremblement suffisent). Remède : ce n'est plus un
  `Button`, c'est
  `.contentShape(...).highPriorityGesture(TapGesture().onEnded { … })`.
  **Ne pas remonter le seuil du drag pour réparer ça** : la fluidité se paie
  en mesures, on ne la re-vend pas pour un bouton.
- **Un `DragGesture` n'appelle pas toujours `onEnded`** (app en arrière-plan,
  présentation, Reachability qui vole le doigt au bord bas). Deux remèdes,
  tous les deux nécessaires : remise à plat sur `startLocation` en tête de
  `onChanged`, et un **chien de garde** (~0,30 s, réarmé, avec jeton) qui
  rejoint l'état STABLE le plus proche — jamais un état inventé. ⚠️ Le chien
  de garde doit COMMETTRE l'action si le seuil était franchi, pas seulement
  remettre à zéro (sinon : une page abandonnée montée au-dessus de tout).
- **Une vue sans taille intrinsèque n'attrape pas les gestes** : un
  `Color.clear + contentShape` parmi des enfants en `.position()` n'a aucune
  taille propre.
- **Les pixels et le hit-test sont DEUX choses.** `visualEffect`/`offset`
  déplacent les PIXELS, pas la zone tactile : une page poussée hors écran
  continue de manger tous les touchers. Remède : `.allowsHitTesting(faux)` dès
  qu'elle quitte sa place.
- Un geste de debug ne vit QUE sur son banc (`isEnabled:` sur un flag) : un
  `onTapGesture(count: 2)` global vole le 2ᵉ tap des séquences rapides.

---

## 5. Le verre, le flou, la lumière

- **`glassEffect(.regular)` est INTERDIT** pour tout objet « liquid glass » —
  c'est le givré laiteux, la source de dix reproches.
- **`glassEffect(.clear)`** = le verre validé, mais il réfracte aux BORDS et
  GIVRE l'intérieur : il ne marche que sur du contenu **doux** (halos,
  dégradés, lumière).
- **Du contenu NET sous un verre** (texte, glyphes) = seulement la calotte
  `liquidLens`.
- `.blur` pose un **voile UNIFORME sur le rectangle de l'hôte** — ce n'est pas
  un flou local.
- Le verre au mauvais `colorScheme` se règle sur le verre SEUL
  (`.environment(\.colorScheme, …)`), payé deux fois.
- Un verre aux **bounds vivants** (redimensionné frame à frame) devient un
  blur plat définitif.
- **Loi anti-brun** des ambiances chaudes : « R reste à 1,00, on désature le
  VERT » — la saturation TIENT.

---

## 6. Vidéo, UIKit, SceneKit

- Une couche `AVPlayerLayer` **ne coûte rien** (décodage matériel) : ce qui
  coûte, c'est ce que le fil principal redessine et ce que le compositeur doit
  rééchantillonner.
- Une vidéo qui déborde son cadre veut `clipsToBounds` **ET** `masksToBounds`
  (SwiftUI ne rattrape pas UIKit).
- Un masque sur une couche vidéo force un rendu HORS ÉCRAN de tout le plan à
  chaque image : les fondus de bord se **cuisent dans le fichier**.
- Boucler : `AVPlayerLooper` (jamais `seek(.zero)` sur `didPlayToEndTime`), le
  looper RETENU par le coordinateur, et muet.
- ffmpeg : **`-ss` ne coupe pas le graphe** — la seule forme juste est
  `trim + setpts` DANS le graphe.
- SceneKit : jamais d'écriture d'euler ni d'animation de composante sur un
  nœud **au lacet π** (la décomposition change de forme au bruit près : c'est
  « l'objet qui tourne » sans raison). Toute respiration vit sur un nœud
  BERCEAU à l'identité.
- Une scène SceneKit décode ses textures **sans cache** à chaque construction
  (~36 Mo ici) : cacher avant d'en ajouter une variante.

---

## 7. Metal / shaders

- **Changer l'arité d'un `[[stitchable]]` sans changer l'appel Swift ne
  produit AUCUNE erreur** : la vue rend son `fill`, donc **une page BLANCHE**.
  Une page entièrement blanche dans cette app veut presque toujours dire
  « un appel de shader ne correspond plus à sa signature ».
- Un uniforme porte souvent **DEUX rôles** : grepper tous ses sites avant de
  le toucher.
- Au runtime, un `float4` peut sortir à ZÉRO et une boucle `for`+`continue`
  être mal JITée : diagnostiquer par **sondes couleur**, pas par lecture.
- Un stitchable ne se juge qu'à la **capture**.

---

## 8. Les ressources

- **`Woop/Media` contient des ressources NUES.** `Image("nom")` cherche dans
  les catalogues d'assets et ne trouve RIEN, **en silence**. Le chargement
  passe par `Bundle.main.path(forResource:ofType:)` ou `.url(forResource:)`.
- Le dossier `Woop` est un **groupe synchronisé** (`objectVersion 70`) : un
  fichier ajouté sur le disque entre dans la cible tout seul — mais il faut
  quand même le `git add` (trois fichiers source ont déjà manqué au dépôt).

---

## 9. Vérifier — la discipline qui vaut les tests

**Le build :**

- `xcodebuild … | grep …` rend le code de **grep**. `… ; echo "EXIT=$?" | tee`
  rend celui de **tee**. Payé TROIS fois : on installe alors une app PÉRIMÉE
  en croyant juger son propre code. → capturer `$?` dans une variable **sur la
  ligne du build**, ou lancer `xcodebuild` **nu** en tâche de fond.
- **Deux builds sur le même `-derivedDataPath` = base verrouillée.** Vérifier
  `pgrep -fl xcodebuild` avant de lancer.
- Xcode 16+ : le binaire principal est un **stub de 58 Ko**, le vrai code est
  dans `Woop.app/Woop.debug.dylib` — c'est SA date qu'on regarde.

**La mesure :**

- **Un juge qui affirme ne remplace pas une sonde qui mesure.** Tout grief
  d'un agent se RE-MESURE avant d'entrer dans un plan, à plus forte raison
  avant d'être annoncé. Quand un avis contredit une mesure, **la mesure gagne**.
- Mesurer une couleur en moyenne de ligne est un artefact (le noir tire vers
  le beige) : on mesure sur les **pixels clairs** de la zone.
- La charge machine invalide les mesures de cadence : `./tools/charge.sh`
  avant tout `-fps` (🔴 au-dessus de 2), et **la vraie cadence se mesure sur le
  TÉLÉPHONE**.
- Une cinématique se **filme** (`simctl io recordVideo`, refermé par SIGINT),
  jamais screenshot par screenshot (~4 s l'image).
- Les `print()` remontent par `simctl launch --console-pty` (pas `log stream`).
- ⚠️ `--terminate-running-process` est obligatoire pour qu'un banc reçoive ses
  arguments : une app déjà vivante revient au premier plan **avec ses anciens
  arguments**.

**Avant de montrer :** transitions filmées, non-régression mesurée sur ce
qu'on n'a pas voulu changer, et on dit ce qu'on n'a PAS pu vérifier.

---

## 10. Plusieurs sessions dans le même dépôt

Il arrive que deux sessions travaillent en parallèle sur cet arbre.

- Chacune **ignore le travail de l'autre** et ne committe QUE le sien, par
  **chemins explicites** (`git add <fichier>`) ou par hunks.
- **Jamais de `git stash`** : il emporte le travail de l'autre.
- `git diff` compare à l'INDEX (qui peut être périmé) : lire `git diff HEAD`.
- Bissecter par chemins : `git checkout <sha> -- <fichiers>`.

---

## La checklist avant de dire « c'est fait »

1. Le build est-il vert **sur un `$?` lu sans pipe** ?
2. Ai-je regardé la **capture entière** — pas seulement la zone que je
   soupçonnais ?
3. Ce que je n'ai pas voulu changer est-il **mesuré identique** ?
4. Ce que je ne peux pas prouver (un geste, un rendu sur téléphone),
   l'ai-je **dit explicitement** au lieu de le laisser croire ?
5. Ce qui a été appris se range-t-il dans une mémoire ou un plan, pour ne pas
   être repayé ?
