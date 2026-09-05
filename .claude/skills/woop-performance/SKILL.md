---
name: woop-performance
description: À charger AVANT toute question de fluidité, de saccade, de chauffe ou de batterie dans Woop — et avant toute mesure sur le téléphone. Contient la méthode de mesure (et ses pièges payés), les lois de coût du rendu, et les techniques d'optimisation qui gardent le dessin intact.
---

# Woop — la fluidité et la chaleur

Ce fichier a été payé le 05-09-2026 par **une journée entière de mesures sur son
iPhone 15**, dont une bonne moitié perdue à mesurer faux. Tout ce qui suit est
soit un chiffre relevé sur le téléphone, soit une erreur de méthode commise ici.

**Trois principes cardinaux, dont tout le reste découle :**

1. **La cadence et la chaleur sont DEUX mesures.** Une app peut tenir 60 images
   par seconde en brûlant deux cœurs. Mesurer la cadence seule, c'est ne pas
   voir le problème dont elle se plaint.
2. **Le simulateur ne mesure que le simulateur.** Aucune décision de performance
   ne se prend sans un chiffre pris sur SON téléphone.
3. **Un instrument qui ment est pire que pas d'instrument.** Avant de croire un
   écart, on prouve que la mesure portait bien sur ce qu'on croit.

---

## 1. AVANT TOUTE MESURE — les six pièges déjà payés

Chacun a coûté au moins une heure le 05-09. Les relire prend trente secondes.

1. **L'ÉCRAN QUI S'ENDORT.** Quand il s'éteint, la cadence tombe ET le
   processeur avec. On croit avoir éteint un moteur coûteux : on a mesuré une
   veille. → `SondeVol` pose `isIdleTimerDisabled = true` pendant qu'elle
   mesure. Toute mesure prise sans ça est à jeter.
2. **LE DRAPEAU OUBLIÉ.** Une demi-journée d'essais (`-fondPose`,
   `-sansVerreHome`, `-sansGalet`, `-sansPiece`, `-noGrain`) a été jouée **sans
   `-skipAuth`**, donc sur la PORTE D'ENTRÉE et pas sur la home — où ces
   éléments n'existent même pas. Tous ces « ça ne change rien » étaient faux.
   → **La ligne de la sonde qui nomme l'écran est la PREUVE** qu'on mesure le
   bon. On la lit avant d'interpréter quoi que ce soit.
3. **LA CHALEUR QUI S'ACCUMULE.** Au-dessus de l'état thermique 1, iOS bride, et
   deux essais successifs ne sont plus comparables. **Relancer l'app en boucle
   maintient le téléphone chaud et détruit toute la campagne** — c'est ce qui
   est arrivé, et une partie de ce qu'elle a senti venait de mes propres
   mesures. → Thermique lu à la PREMIÈRE seconde ; si ≥ 1, on attend.
4. **DEUX CADENCES DIFFÉRENTES.** Un % de processeur à 21 img/s et un % à
   60 img/s n'ont pas le même dénominateur. → On publie TOUJOURS la paire
   (cadence, processeur), et on ne compare que des essais à cadence proche.
5. **LA MOYENNE DE LIGNE.** On prend la MÉDIANE des secondes, jamais la moyenne
   (un pic de lancement la ruine), et **on jette les 15 premières secondes** :
   décodeurs et shaders se mettent en route.
6. **DEUX CHANGEMENTS À LA FOIS.** Une balade = un moteur. Deux changements =
   une balade perdue.

---

## 2. LA SONDE — `Woop/Views/SondeVol.swift`, drapeau `-sondeVol`

C'est l'instrument de la maison. Elle écrit **une ligne par seconde** dans
`Documents/vol-<date>.jsonl`, et elle survit aux relances à la main (une clé
`UserDefaults`) : elle peut donc se balader avec l'app sans le Mac.

Ce qu'elle enregistre, et pourquoi chaque champ existe :

| champ | ce qu'il dit | pourquoi il est là |
|---|---|---|
| `img` | images par seconde | la fluidité |
| `pire` | **le pire trou de la seconde, en ms** | c'est LUI qu'on sent au doigt. 58 img/s avec un trou de 300 ms, ça « lague ». La moyenne ment. |
| `cpu` | % processeur du process | **la chaleur**. 100 = un cœur saturé. |
| `therm` | état thermique iOS (0-3) | le seul juge non discutable de « ça chauffe » ; ≥ 1 invalide la comparaison |
| `corps` | recalculs du corps de page /s | sépare « SwiftUI refait la mise en page » de « le compositeur redessine » |
| `tics[]` | battements par groupe d'horloges | dit QUELLE famille anime, sans deviner |
| `onglet`, `seance`, `player`, `ile`, `drag` | le contexte | la preuve qu'on mesure le bon écran |
| `marque` | **elle a tapé la pastille** | relie son ressenti au chiffre |
| `gel` | trou > 2 s (arrière-plan) | à exclure : ce n'est pas une saccade |

**Elle dort avec l'app** (sinon un écran éteint s'enregistre comme un gel de
20 s) et **tient l'écran éveillé** pendant qu'elle mesure.

### Le geste complet, de bout en bout

```bash
# 1. construire et poser (JAMAIS de | grep ni | tee : on lirait le code du tube)
xcodebuild -project Woop.xcodeproj -scheme Woop \
  -destination 'generic/platform=iOS' -derivedDataPath "$DD" \
  -allowProvisioningUpdates build > "$LOG" 2>&1 ; echo "EXIT=$?"
xcrun devicectl device install app --device <UDID-devicectl> "$APP"

# 2. lancer AVEC les drapeaux — ⚠️ après `--`, sinon devicectl les mange
xcrun devicectl device process launch --terminate-existing \
  --device <UDID> fr.kathryn.woop -- -sondeVol -skipAuth

# 3. récupérer (--username pour lister, --user pour copier : ce n'est pas une faute de frappe)
xcrun devicectl device info files --device <UDID> \
  --domain-type appDataContainer --domain-identifier fr.kathryn.woop --username mobile
xcrun devicectl device copy from --device <UDID> \
  --domain-type appDataContainer --domain-identifier fr.kathryn.woop --user mobile \
  --source "Documents/vol-….jsonl" --destination ./vol.jsonl
```

**La lecture** : médiane des secondes, `t > 15`, `gel == 0`, et on annonce
`(cadence, processeur, thermique, n)`. Jamais un chiffre nu.

### La campagne honnête

**Ordre alterné A B B A A B**, jamais A A A puis B B B — le téléphone chauffe
dans un sens. 3 répétitions × 60 s. Téléphone froid au départ. Et **le barreau
se prouve** : on vérifie dans la sortie que le drapeau a bien pris.

### Ses marques valent de l'or

Quand elle tape la pastille, l'instant est estampillé. Le 05-09, ses trois
marques sont tombées **pile** sur des creux à 6-9 img/s avec des trous de 115 à
382 ms. Son doigt et la sonde disent la même chose : **on la croit, et on
cherche à l'endroit qu'elle montre.**

---

## 3. LE PROFILEUR — l'arbitre qui manque

`xcrun xctrace record --template 'SwiftUI' --attach Woop` donne **« View Body »**
— combien de fois chaque type de vue est reconstruit, et pour combien de temps.
C'est le seul outil qui CLASSE les coûts au lieu de les deviner.

**État au 05-09 : INJOIGNABLE sur ce téléphone.** « Timed out waiting for device
to boot », alors que tout est correct — vérifié :
`developerModeStatus: enabled`, `pairingState: paired`, `transportType: wired`,
`ddiServicesAvailable: true`. Essayé en `--launch`, en `--attach`, par UDID et
par `--device-name`. Ce n'est pas la configuration.

**Avant de re-perdre une heure dessus :** relancer l'essai, et si ça échoue
encore, ne pas insister — on a la sonde. Autres pistes non épuisées :
`Animation Hitches` et `Metal System Trace` (le temps du serveur de rendu et le
GPU, que le % de processeur ne peut **structurellement** pas voir), et
**MetricKit** (`MXCPUMetric`, `MXAnimationMetric`), qui ne demande aucun câble.

⚠️ Le profileur **CLASSE, il ne CHIFFRE pas** : il coûte lui-même, et le câble
charge la batterie donc chauffe. Le chiffre reste la sonde, téléphone débranché.

---

## 4. LES LOIS DE COÛT — ce qui brûle, mesuré ici

### Les chiffres de référence (iPhone 15, 05-09)

| | processeur |
|---|---|
| écran NU (le châssis rend du noir, aucune page) | **1 %** |
| n'importe quelle page, immobile, personne n'y touchant | **27 à 39 %** |

**Le châssis ne coûte rien. Tout est dans les pages.** Une page statique devrait
être à 2 %.

### La découverte centrale

**Le corps de la page est recalculé 0 fois par seconde** — SwiftUI ne refait
aucune mise en page — **et pourtant ça brûle**. Le coût n'est donc pas
l'invalidation : c'est que **des horloges profondes redessinent en continu**, et
que chaque battement force à recomposer l'écran **à travers le verre**.

Compté sur l'accueil immobile : la home 32 battements/s · les widgets 30 · la
nappe 16 · les galets 15 → **≈ 93 à 128 par seconde**.

### Le classement des postes, mesuré

- **LE VERRE : le quart.** Six verres natifs éteints → 37 % → 28 %. Un verre
  posé **sur une vidéo** ne peut RIEN mettre en cache : ce qu'il y a dessous
  change à chaque image, il refait son flou en boucle.
- **LES VIDÉOS : rien.** Remplacer les deux calques du fond par une image fixe :
  37 % contre 38 %. **Innocentées, ne pas y revenir.**
- **LES HORLOGES DÉSACCORDÉES : beaucoup.** Quatre familles à 12, 20, 24 et
  30 Hz ne tombent pas sur les mêmes images : leurs redessins s'ajoutent au lieu
  de se confondre. Les aligner sur un pas commun + fermer les onglets cachés :
  **37,5 % → 27,5 %**.
- **UN RUBAN ANIMÉ PLEIN CADRE** (3 flous + masque + `blendMode` à 20 Hz, sur
  CHAQUE page montée) : en séance, **9,3 → 30,2 img/s** une fois retiré. ×3,2.
- **HORS DE CAUSE, mesurés** : le ciel nébuleuse (plus monté), le gyroscope, le
  fond vidéo.

### Les lois de rendu (héritées, toujours vraies)

- Un `Canvas` **rasterise toute sa surface, même vide**.
- Un verre natif **animé** fait tomber 60 → 14 img/s ; un verre aux **bounds
  vivants** devient un blur plat définitif.
- `glassEffect(.regular)` est **interdit** sur les objets « liquid glass ».
- `.blur` pose un voile sur **tout le rectangle de l'hôte** ; une gaussienne à
  **rayon animé** n'est jamais mise en cache — faire respirer l'OPACITÉ, jamais
  le rayon.
- `.compositingGroup()`, `.blendMode`, `.mask`, `.shadow` = des passes **hors
  écran**.
- Une couche `AVPlayerLayer` ne coûte presque rien (décodage matériel) ; ce qui
  coûte, c'est ce que le fil principal redessine. Un **masque** sur une couche
  vidéo force un rendu hors écran de tout le plan à chaque image.
- Un `@State` écrit à la cadence de l'écran **sur la vue qui contient tout**
  ré-évalue toute la page. Remède : `@Observable` + un `ViewModifier` qui SEUL
  relit la valeur (`OffsetVol` dans `PlayerMonde.swift`, `DessinPilule` dans
  `PiluleVagabonde.swift`).
- **On DÉMONTE, on n'éteint pas** : une vue montée mais cachée rend quand même
  (le « rideau »). Une `SCNView` effacée par l'opacité rend quand même.

---

## 5. LES REMÈDES QUI GARDENT LE DESSIN

Sa règle, et elle prime : **« oui, elle respire en permanence »**. La page qu'on
REGARDE ne se fige jamais. On ne gagne donc que sur ce qui ne se voit pas.

### ① La porte d'onglet — le premier réflexe

Le `TabView` garde les trois pages **montées** : sans porte, les trois animent en
même temps. `RythmeEcran.dort("profile" | "exercises" | "home")`
(`Woop/Views/RythmeEcran.swift`) ferme une horloge quand sa page n'est pas
affichée. **Invisible par construction.**
⚠️ Le mécanisme existe depuis le 05-09 : **le brancher sur toute nouvelle
horloge**, sinon elle tournera derrière les autres pages pour rien.

### ② Le pas commun

Toutes les horloges d'ambiance d'une page battent sur `RythmeEcran.pas` (20 Hz).
Deux horloges désaccordées font deux recompositions ; au même pas, elles se
confondent. **Aucun changement de dessin.**

### ③ Ne pas redessiner pour animer

**La question à se poser avant d'écrire une `TimelineView`** : ce qui bouge
est-il une **valeur animable** (opacité, échelle, rotation, offset) ? Si oui,
une animation (`withAnimation(.repeatForever)`, `phaseAnimator`,
`keyframeAnimator`, ou un `ViewModifier` `Animatable`) l'interpole **sans jamais
reconstruire le contenu** — et c'est plus lisse (60 Hz au lieu de 20).
Une `TimelineView` ne se justifie que si le contenu lui-même change (un
`Canvas`, un shader nourri du temps, un chrono).
⚠️ **Piège payé** (`PageCard.swift`) : un `repeatForever` posé par
`withAnimation` **se fait avaler quand le parent est ré-évalué**. L'état de
phase vit dans la FEUILLE et se ré-arme à `.task`/`onChange` ; sinon, une vraie
`CABasicAnimation` dans un `UIViewRepresentable`, qui vit côté serveur de rendu.

### ④ Les drapeaux existants pour mesurer

`-sondeVol` (la sonde) · `-ecranNu` (le plancher du châssis) ·
`-sansRepos` (rallume toutes les horloges : le témoin) ·
`-fondPose` (les calques vidéo sur leur image de pose) ·
`-sansVerreHome` (les verres natifs de l'accueil) ·
`-sansVerreRoute` / `-avecVerreRoute` (persistants) · `-sansBord` (le ruban).

**Tout nouveau moteur coûteux arrive avec son barreau** — sans quoi on ne pourra
jamais l'accuser ni le disculper.

---

## La checklist avant de dire « c'est plus fluide »

1. Le chiffre vient-il de **son téléphone**, pas du simulateur ?
2. L'état thermique était-il **à 0 au départ** des deux essais ?
3. La ligne de la sonde prouve-t-elle que je mesurais **le bon écran** ?
4. Ai-je publié **la paire (cadence, processeur)** ?
5. Un seul moteur a-t-il changé entre les deux essais ?
6. Ai-je dit ce que je **n'ai pas** pu prouver ?
