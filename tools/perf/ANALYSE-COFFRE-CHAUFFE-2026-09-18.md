# Le coffre qui chauffe — analyse dans le code, 18-09-2026

Demande de Kathryn : « je vois le coffre encore qui chauffe — analyse dans le
code, pas besoin de me faire perdre du temps au simulateur ». Lecture faite
après le skill `woop-performance`, le skill `woop-chauffe`, le registre
`ECHECS-CHAUFFE-HOME.md` (E75, E76) et les commits chauffe du 05-09 au 18-09.

**Ce document ne mesure rien.** Il désigne, ligne par ligne, ce qui tourne
sur la page du coffre quand personne n'y touche, ce qui devrait dormir et
ne dort pas, et par quoi commencer. Chaque remède garde le dessin. Le seul
chiffre qui comptera viendra de son téléphone, thermique lu à 0 au départ.

## Ce que le registre savait déjà, et ce qu'il ne regardait pas

- E75/E76 (18-09) : forte chauffe « après manège, carte, Profil et stories »,
  thermique 1 → 2 au retour actif, **le sachet 3D garde 30 rendus/s sous
  protection 1**. Correctif 78 (commit 002447c0 : pose du sachet à chaud,
  `BoosterLab.swift`) posé, **jamais installé ni mesuré**. Ce sujet est celui
  de la session manège ; il n'est pas repris ici.
- **La page du coffre elle-même (`CoffreV2.swift`, 4 024 lignes) n'a jamais
  été regardée comme un moteur.** Elle n'a aucun `SondeVol.tic` : elle est
  dans l'angle mort de la sonde (skill §6.8 — « une horloge sans tic n'existe
  pas dans `tics[]` »). Aucune campagne ne l'a donc jamais accusée ni
  disculpée.

## L'inventaire — ce qui tourne quand le coffre est ouvert et immobile

| Moteur | Où | Cadence | Dort quand… | Verdict de lecture |
|---|---|---|---|---|
| **`Projecteur`** (le faisceau sur la pièce) | `CoffreV2.swift:835-925`, posé `:2823` | **20 Hz**, `TimelineView(.animation)` | jamais (ni thermique, ni `paused:`) | **suspect n° 1** |
| `Levitation` ×2 (la pièce respire) | `:943-948`, posé `:2265`, `:3484` | 20 Hz, `TimelineView` | jamais | suspect n° 3, mineur |
| `tourNeon` (le néon tourne) | `:1837`, `:3072-3083` | animation `repeatForever` sur `rotationEffect` | (interpolé par le serveur de rendu) | sain — c'est le bon geste |
| `BarreFine` (jauge « horloge ») | `:1303` | `.periodic(by: 60)` | — | sain |
| Poudre `Canvas` ×4 | `:3113-3145` | pilotée par `page` (le doigt) | au repos, rien | sain au repos |
| `Atterrissage`, `GerbePieces`, `CoinSmoke` | `:979`, `:1061`, `:2851` | 60 Hz, transitoires | remis à `nil` (`:3784`, `:3806`, `:3968`) | sains |
| Films `lecteur`, `histoireLecteur` | `:1785`, `:1827` | transitoires | `pause()` + `nil` (`:2426`, `:3906`) | sains |
| `SpotVideo` (boucle) | `:704-750` | 12 img/s | **seulement sous `-coffreSpot`** (`:663`) — le fond par défaut est une image fixe (`:678`) | hors cause en production |
| Verres `.glassEffect(.clear)` ×5 | `:1217`, `:1590`, `:1608`, `:2103`, `:2671` | — | (posés sur une image fixe) | amplificateur : voir n° 1 |
| **La Home SOUS le coffre** | `HomeNuit.swift:2679` (`fullScreenCover`) + `RythmeEcran.swift:156` | ses 4 familles (≈ 93 battements/s mesurés le 05-09) | `dort("home")` = **story visible ou autre onglet, rien d'autre** | **suspect n° 2** |

## Suspect n° 1 — le `Projecteur` : on redessine trois flous plein cadre pour tourner une lumière de 13°

C'est, mot pour mot, « le motif à traquer » du skill (§5③) :

```
20 fois par seconde (CoffreV2.swift:845-849) :
  corps(balayage:)  →  deux éventails à dégradé (:865, :894)
                        + deux masques latéraux (:880, :899)
                        + DEUX flous gaussiens, rayons 19 et 13 (:887, :904)
                        + la flaque, flou 11 (:922)
                        dans un .frame(W, H) plein cadre (:924)
                        sous .compositingGroup() (:926)
                        en .blendMode(.plusLighter) (:852)
pour :  .rotationEffect(.degrees(13 * balayage))   (:906)
    et  .opacity(force * (1 + 0.055 * sin(t·2π/5.5)))  (:849)
```

**Ce que le temps fait ici (question 1 du skill)** : deux scalaires — un angle
de ±13° (`balayageCoffre`, `:807` : somme de deux sinus, 0,62 et 0,29 rad/s)
et une respiration d'opacité de 5,5 %. **Tout le reste ne dépend pas du
temps** et est refabriqué à chaque tic.

**Pourquoi le commentaire du code se trompe** (`:830-832` : « sans
`Equatable` le faisceau se reconstruirait avec ses deux flous à chaque
image »). `Equatable` empêche la *page* de re-évaluer `Projecteur` pendant
un drag ; il n'empêche pas la **fermeture de la `TimelineView`** d'appeler
`corps(balayage:)` vingt fois par seconde. Et chaque appel produit un arbre
neuf : `.compositingGroup()` impose une passe hors écran de tout le groupe
(skill §4 : « `.compositingGroup()`, `.blendMode`, `.mask`, `.shadow` = des
passes hors écran »), et un flou dont l'entrée est refaite n'est jamais mis
en cache (« une gaussienne à rayon animé n'est jamais mise en cache — faire
respirer l'OPACITÉ »). Ici le rayon est constant, mais l'entrée du flou est
un groupe qui **tourne** : le serveur de rendu recalcule la gaussienne
plein cadre à chaque tic.

**Pourquoi c'est cohérent avec E76** (thermique 2 pour peu de CPU) : trois
gaussiennes plein cadre à 20 Hz, c'est du **GPU**, que `cpu` de la sonde ne
peut « structurellement » pas voir (skill §3). Le fil principal ne calcule
presque rien ; le téléphone chauffe quand même.

**Les cinq verres** (`:1217` …) sont posés sur cette scène : un verre
`.clear` sur un fond qui change 20 fois par seconde refait son flou 20 fois
par seconde (skill §4, « un verre posé sur une vidéo ne met RIEN en cache »
— ici ce n'est pas une vidéo, c'est le projecteur, même effet).

### Le remède, sans toucher au dessin

Deux factorisations du skill, dans l'ordre :

1. **Sortir tout ce qui ne dépend pas du temps de la fermeture.** Les deux
   éventails + masques + flous + la flaque se construisent **une fois**
   (une valeur stockée chez le parent rare — leçon 6 du §6 : « dans un body
   évalué par image, les enfants sont des VALEURS STOCKÉES »). Le plus sûr :
   les cuire en **une image** à la taille de la scène (`ImageRenderer`, ou
   `.drawingGroup()` sur ce sous-arbre constant) — trois flous calculés une
   seule fois pour toute la vie de la page.
2. **Animer, ne plus redessiner.** Sur cette image : `rotationEffect` et
   `opacity`. La respiration d'opacité (un sinus) est une animation
   `repeatForever` ordinaire. Le balayage est **une somme de deux sinus** :
   c'est le cas §6.5 du skill, trois voies, à MONTRER —
   - la période dominante seule (0,62 rad/s ; change le caractère du
     balayage — verdict sur capture) ;
   - l'exacte : une `struct View + Animatable` sur `t`
     (`.linear(2310 s).repeatForever`) qui réapplique `13 · balayageCoffre(t)`
     à l'image cuite — le body est évalué par image, mais il ne pose qu'une
     rotation sur une image déjà rasterisée : plus aucun flou recalculé.
     C'est la voie qui garde le dessin **à l'identique**, et celle de
     `LisereRespirant.swift` (« tourner la peinture, pas la vue »).

   Ce que ça change à l'œil, à dire honnêtement : rien sur la forme (même
   image, tournée) ; le flou porte sur l'image déjà peinte, comme aujourd'hui.
   L'ancre de rotation (`:858`, le haut de la barre) se conserve.
3. **Une porte** : `paused:` sur ce qui reste d'horloge quand
   `scenePhase != .active`, sous protection thermique, et sous
   `reduceMotion` — aujourd'hui aucune.
4. **Son barreau et son tic** : `-sansProjecteur` (le faisceau en pose fixe)
   et `SondeVol.tic("coffre.projecteur")` — sans quoi on ne pourra ni
   l'accuser ni le disculper sur le téléphone (règle de CLAUDE.md : « tout
   nouveau moteur coûteux arrive avec son barreau »). Le coffre n'en a
   aujourd'hui **aucun**.

## Suspect n° 2 — la Home ne dort pas sous le coffre (ni sous le chemin, ni sous la fiche)

`RythmeEcran.dort(onglet)` (`RythmeEcran.swift:156-159`) rend vrai dans deux
cas : une story couvre (`stories` non vide) ou l'onglet actif est un autre.
**Un `fullScreenCover` n'est ni l'un ni l'autre.** Les stories ont reçu leur
couverture exactement pour ça (`StoryFlow.swift:649` / `:662`, commentaire de
`RythmeEcran.swift:124` : « une story plein écran recouvre les pages gardées
dans le TabView »). Les trois autres covers de la Home n'en ont pas :

- le coffre — `HomeNuit.swift:2679` (`CoffreFortFlow`) ;
- le chemin — `:2646` (`DuolinguoPage`) ;
- la fiche exo posée sur le chemin — `:2667` (`ExercisesView`).

Les 32 lectures de `dortHome` (`HomeNuit` 8, `WidgetsCards` 15, `MenuNappe` 6,
`CardRoute` 3) restent donc à « éveillé » pendant tout le temps du coffre :
les ≈ 93 battements/s de la Home immobile (mesure du 05-09) s'additionnent au
projecteur. **C'est une lecture, pas une mesure** : un `fullScreenCover`
retire la vue du dessous de la hiérarchie UIKit (plus de composition), mais
les fermetures des `TimelineView` et les `task` des feuilles continuent de
tourner côté SwiftUI tant que `dort` dit non — c'est précisément ce que la
couverture des stories a corrigé. Même mécanisme, même remède :

```swift
// dans CoffreFortFlow (et DuolinguoPage, ExercisesView-en-cover), comme StoryFlow:649
.onAppear    { RythmeEcran.shared.stories.insert(couverture) }
.onDisappear { RythmeEcran.shared.stories.remove(couverture) }
```

(ou un `.couvreLaHome()` unique, pour ne plus l'oublier au prochain cover.)
Invisible par construction : la Home n'est pas à l'écran.

## Suspect n° 3 — `Levitation` : 20 relectures de mise en page par seconde pour un sinus

`:943-948` : `content.offset(y: -force·3,2·sin(t·2π/4,7))` dans une
`TimelineView` à 20 Hz. Le contenu est déjà construit (le commentaire a
raison là-dessus), mais l'offset change 20 fois par seconde → 20 passes de
mise en page et de composition, ×2 objets, à travers `.parallaxe`. C'est une
valeur **animable** : `withAnimation(.easeInOut(2,35 s).repeatForever
(autoreverses: true))` sur un `@State` d'offset, dans la feuille (piège
§5③bis : la phase vit dans la feuille et se ré-arme à `.task`), donne le
même mouvement à 60 Hz pour zéro relecture. Gain modeste, geste sûr.

## Ce qui a été vérifié et n'est PAS en cause

- Le fond vidéo en boucle (`SpotVideo`) n'existe qu'avec `-coffreSpot` ;
  le fond de production est `coffre-arche`, une image fixe (`:678-686`).
- Les moteurs d'événement (atterrissage, gerbe, fumée, films d'ouverture et
  d'histoire) sont démontés après usage (`nil` explicite, `pause()`).
- Le néon tourne par animation, pas par horloge (`:3080-3084`) — c'est le
  bon geste et il n'y a rien à reprendre.
- Aucun `.blur` à rayon animé en continu : les deux rayons variables
  (`:1166`, `:3439`) retombent à 0 exact hors transition.
- Les vidéos du coffre sont recuites à la largeur de l'écran (1206),
  12-24 img/s, H.264/HEVC matériel.

## Par quoi commencer, et comment le prouver

Une balade = un moteur (skill §1.6). Dans l'ordre du gain attendu :

1. **`-sansProjecteur`** (faisceau en pose fixe, même image) — A B B A A B,
   3 × 60 s, coffre ouvert immobile, thermique 0 au départ, la paire
   (cadence, cpu) **et la trajectoire thermique** — c'est elle qui compte
   ici, le CPU sera plat des deux côtés. Si la pente thermique change,
   la refonte « image cuite + Animatable » est justifiée ; on la montre
   ensuite (capture A/B du faisceau) avant de la garder.
2. **La couverture** des trois covers — invisible, mesurable par les
   `tics[]` de la Home qui doivent tomber à 0 sous le coffre.
3. `Levitation` en animation — après, et seulement si 1 et 2 ne suffisent
   pas à ramener le coffre sous la Home.

Ce qui reste hors de portée de cette lecture : le poids relatif exact du
projecteur et de la Home réveillée ; l'énergie des cinq verres ; et le
sachet 3D (session manège, correctif 78 à installer). Rien de ceci ne se
décide au simulateur.

## Posé le 18-09 après-midi, sur son « bah fais » — compilé, NON mesuré

Le dessin n'a pas bougé d'un pixel ; tout est invisible par construction ou
derrière un drapeau. Build simulateur `EXIT 0`.

- **La couverture des covers** — `RythmeEcran.swift` : un ensemble
  `couvertures` distinct de `stories` (pour ne pas changer le sens de
  `storyVisible`, lu par le châssis, le Profil et la sonde), lu par
  `dort(onglet)` ; un modificateur `.couvreLaHome()` (`CouvertureHome`,
  une clé par cover, `onAppear`/`onDisappear` comme `StoryFlow`). Posé
  sur : `CoffreFortFlow` (dans son body — les quatre appelants d'un coup,
  la poignée intacte), le chemin et la fiche posée dessus
  (`HomeNuit.swift`), et **le manège** à la racine (`NosfyApp.swift`,
  calque plein écran sur le TabView — QA 18). Vérifié en lecture : le
  coffre se ferme (`onClose()`) 0,45 s avant l'ouverture du manège, le
  projecteur ne tourne donc pas sous lui.
- **Le projecteur** — `CoffreV2.swift`, `Projecteur` : barreau
  `-sansProjecteur` (pose fixe, balayage 0, sans horloge) ; porte
  `paused:` quand `scenePhase != .active`, sous Reduce Motion ou sous
  `ProtectionThermique.ambianceAuRepos` (le faisceau se pose, ne
  disparaît pas) ; `SondeVol.shared.tic(5)` dans la fermeture. `Equatable`
  réécrit à la main sur les entrées (les wrappers d'environnement ne se
  synthétisent pas).
- **La sonde** — `SondeVol.swift` : sixième groupe de tics, `tics[5]` =
  coffre. Le JSON gagne une case ; `analyse_sonde.py` n'indexe pas les tics.

Ce qui reste à mesurer, sur son téléphone, thermique 0 : (1) `-sansProjecteur`
A B B A A B, trajectoire thermique ; (2) sous le coffre, `tics[0..4]` doivent
tomber à 0 et `tics[5]` apparaître ; (3) sous le manège, `tics[0..4]` à 0.
La refonte « image cuite + Animatable » n'est pas faite : elle se décide
après (1), et se montre avant d'être gardée.
