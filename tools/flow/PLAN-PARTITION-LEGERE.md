# LA PARTITION ALLÉGÉE — le numéro, le trait, et les flammes-stickers

> **PAYÉ le 26-08 au soir, sur le « ok » de Kathryn.** P1 à P5 sont
> codés et filmés ; ce qui suit reste la doctrine du chantier.
> Ce qui a été fait, et ce qui a bougé par rapport au plan :
> - **P1** `sticker-flamme-serree` rogné à sa boîte utile
>   (384×384 → **184×238**, marge de 2 px pour l'antialiasing du
>   liseré) en `@1x/@2x/@3x` propres : le cadre EST la flamme ;
> - **P2** la rangée = trait argent (Capsule 2,4 × 30, dégradé
>   0,95 → 0,25, **place toujours réservée** même éteint) + `01`
>   monospacé + nom ; **photo et chevron morts** ;
> - **P3** la règle A est CODÉE et VUE : « 03 · Développé couch… ·
>   cinq flammes **+2** » — et les non faites en sticker à 0,16.
>   La variante B (une flamme + « +N ») n'est pas codée : la A
>   suffit à l'œil, on la garde tant qu'un verdict ne la refuse pas ;
> - **P4** la lune est morte ; la pièce prend **`figee: true`**
>   (nouveau paramètre de `MoonCoinView`) — l'horloge est en pause
>   ET le `tilt` n'est plus lu, donc plus d'abonnement au gyro ;
> - **P5** la page détail exercice hérite des stickers, et **la
>   cérémonie survit** : l'onde et la couronne de six diamants sont
>   sorties dans `CeremonieFlamme`, le flash-symbole est remplacé
>   par un **pop d'échelle du sticker** (une seule cloche, jamais
>   deux animations) ;
> - **la démo couvre enfin le cas « plus de cinq »** :
>   `StorySession.demo` donne 3, 4 puis **7** séries.
> - **P6 non fait** : le `padding(.horizontal, 6)` de `StoryDetails`
>   et la mesure des 342 pt attendent le tour suivant.


**Écrit le 26-08-2026 sur le verdict de Kathryn (« je trouve ce
composant un peu lourd ») et sa maquette de référence — RIEN n'est
codé.** Le chantier touche TROIS composants partagés :
`SlateRang` (la rangée d'exercice), `SetHistoryRow` (la ligne de
série) et **`FlammesRow`** — qui vit aussi dans la **page détail
exercice** (« il faut aussi modifier le composant flamme de la page
détail exercice »).

> Les verdicts, mot à mot :
> « les flammes sont pas assez fines : prends les stickers flammes
> rouge, tu mets une flamme et à côté +3 ou autre »
> « les chevrons c'est pas fou : enlève »
> « enlève les lunes c'est trop chargé (à gauche) »
> « enlève l'image, mets comme l'image le chiffre et un trait fin
> dégradé »
> « c'est lourd, trop de flammes : mets simplement les petits
> stickers flamme, et quand c'est plus de 5, sur la dernière flamme
> tu mets +X ; pour les flammes pas faites tu mets un sticker mais
> très transparent »

---

## 0. CE QUE LA CARTOGRAPHIE A MESURÉ (et deux surprises)

Avant de dessiner, les faits — tous mesurés, pas supposés.

**La rangée d'aujourd'hui** (`SessionSlate.swift:413-471`) :
vignette `ExercisePhoto` 30×30 + nom + `FlammesRow` (100 pt) +
chevron 11,5 — hauteur 50 pt.

**Les flammes** (`FlammeJauge.swift:1199-1296`) ne sont PAS des
stickers : ce sont **deux SF Symbols empilés** (`flame.fill` en
ventre flouté + `flame` en contour) — d'où le « pas assez fines »,
c'est un trait de symbole. Chaque flamme ALLUMÉE coûte
**~3 passes offscreen** (1 blur + 2 shadow). Une partition de
5 exercices × 5 flammes = **~75 passes offscreen**, même immobiles.
Le gel (`t: 0`) supprime l'horloge, PAS le rendu.

⚠️ **SURPRISE 1 — la pièce n'est pas gelée.** Le commentaire de
`SetHistoryRow.swift:161-163` affirme que `draggable: false` évite
« une TimelineView par pièce ». **C'est faux, mesuré** :
`MoonCoinView` (`MoonCoinLab.swift:105`) enveloppe TOUJOURS son
corps dans un `TimelineView`, `paused` seulement sous
`reduceMotion`. Chaque ligne « faite » porte donc **une horloge à
6 Hz + un dispatch shader Metal**, plus un abonnement `@Observable`
à `SkyMotion.tilt` (`DemonSky.swift:17-23`) qui, **sur téléphone
seulement** (au sim `tilt` reste à zéro — LE SIM EST AVEUGLE À CE
COÛT), réévalue TOUTES les pièces au rythme du gyroscope.
C'est probablement la vraie cause du « un peu lourd ».
Le remède existe déjà dans la maison : `SeriesCoinFlight`
(`RestartSheet.swift:414-510`) — **UNE horloge pour tout le champ,
N appels shader bruts** (« empiler des MoonCoinView, c'est un
TimelineView par pièce — interdit », écrit noir sur blanc `:407`).

⚠️ **SURPRISE 2 — la vignette coûte 6,3 Mo pour 30 pt.**
`ExercisePhoto` (`ExercisePhoto.swift:24-33`) décode le PNG plein
format (1122×1402, **aucune variante de scale** dans les
`Contents.json`) puis le réduit ×12 en linéaire avec
`.interpolation(.high)` — le filtre le plus cher. Cinq exercices =
**~31 Mo de bitmaps résidents** pour cinq pastilles de 30 pt.
Kathryn veut la retirer : le gain est bien plus grand qu'un dessin.

⚠️ **CORRECTION D'UNE MESURE COMMITÉE.** Le commentaire posé au
commit précédent annonce ~342 pt de largeur minimale pour
`SetHistoryRow` ; la mesure fine sur les vraies fontes donne
**≈ 353 pt** (et **374** au pire cas réaliste `Set 12 · 120 kg ·
180 s`). Trois montages sur quatre sont SOUS cette barre dès qu'un
écran fait ≤ 396 pt : `StoryDetails`, `ExerciseDetailView:1504`
(`largeur − 44`), et l'ardoise sur un 375 pt. **Le présent
chantier règle le problème par la soustraction** (voir §3).

---

## 1. LA RANGÉE D'EXERCICE — le numéro et le trait

La maquette : un chiffre à deux positions, le nom, rien d'autre —
et un **trait vertical fin en dégradé** à gauche de la ligne
ACTIVE. Tout le reste s'en va.

**Ce qui MEURT** : la vignette `ExercisePhoto` (−30 pt de large,
−6,3 Mo de décodage par exercice) et le chevron (−11,5 pt).

**Ce qui NAÎT** :
- **le numéro** : `01`, `02`, `03` — deux chiffres, `monospacedDigit`
  obligatoire (le layout ne doit pas respirer entre 9 et 10),
  `.inter(17-18, .medium)`, blanc 0,92 sur la ligne active,
  blanc ~0,34 sur les autres (la maquette montre un contraste
  franc entre l'active et les endormies) ;
- **le trait** : `Capsule` de **2,4 pt de large**, hauteur ~28-30,
  en dégradé VERTICAL — la grammaire existe déjà, c'est la lame
  chaude du curseur de molette
  (**`SetEntrySheet.swift:552-561`** : `LinearGradient` +
  `.shadow`), le SEUL trait vertical à dégradé de l'app. Ici en
  ARGENT (blanc 0,95 → blanc 0,25) et sans ombre chaude, pour
  rester dans la nuit de la story ;
  ⚠️ le trait ne vit QUE sur la ligne active — sur les autres, sa
  place est réservée (largeur constante) mais il est éteint : rien
  ne doit bouger horizontalement quand l'actif change.
- **le nom** : inchangé (`.inter(14, .semibold)`, `lineLimit(1)`),
  mais il gagne les 41 pt libérés — « Woodchopper poulie haute »
  (183,5 pt) tiendra ENFIN entier dans la story.

**L'aération** : la maquette respire beaucoup plus que la rangée
actuelle (50 pt). Cible **62-68 pt** par rangée repliée — à trancher
sur capture, avec le pas vertical de la maquette comme référence.

⚠️ **Le précédent CONTRAIRE, à connaître** : le chemin Duolinguo a
DÉBRANCHÉ ses numéros d'étape avec un verdict écrit
(`DuolinguoPage.swift:774-781`) : « un chiffre d'étape se lit comme
un contenu, une flamme se lit comme une intention ». Ce n'est pas
une contradiction — là-bas le chiffre disait un RANG dans un
parcours, ici il dit l'ORDRE d'une séance déjà faite. Mais la
mécanique `GaletEtape(numero:)` existe et reste débranchée : on ne
la réveille pas.

---

## 2. LES FLAMMES — des stickers, et une seule règle

### 2.1 Le sticker, et son piège de canevas

L'asset est **`sticker-flamme`** (l'orange laquée à liseré blanc —
il n'y a QUE deux flammes au catalogue, l'orange et la noire ; pas
de troisième « rouge »). Mesuré : canevas **384×384**, boîte utile
**180×234** — soit **46,9 % en largeur, 28,6 % en AIRE**. C'est le
sticker le plus perdu dans son cadre de toute la famille.

⚠️ **Conséquence dure** : un `.frame(16)` ne montre qu'une flamme
de **7,5 pt** de large. Le piège est déjà payé ailleurs
(`MenuNappe.swift:797-803` : « à 34 pt la coupe mange la moitié du
sticker et on ne reconnaît plus rien »). Donc **le cadre doit
valoir ~2,1× la flamme voulue** : pour une flamme visible de
14 pt, cadre ≈ 30 pt.

**Deux voies, à trancher** :
- **(a) au layout** : cadre 28-30 pt, chevauchement négatif entre
  flammes (spacing −8 à −10) pour que la rangée reste courte.
  Zéro travail d'asset, mais des cadres qui se recouvrent.
- **(b) au fichier** — RECOMMANDÉE : recuire une variante
  `sticker-flamme-serree` rognée à sa boîte utile (180×234 → le
  cadre EST la flamme), en `@1x/@2x/@3x` propres. Le layout
  redevient honnête, et le décodage tombe (0,59 Mo → ~0,15 Mo).
  C'est un script de 10 lignes, école `recuit_*`.

### 2.2 LA RÈGLE, unique et partout la même

Aujourd'hui : 5 fentes, et au-delà **4 flammes + « +N »**
(`FlammeJauge.swift:1211-1228`). Kathryn la reformule :

> **Une flamme par série FAITE, jusqu'à 5. Au-delà de 5, la
> DERNIÈRE flamme porte un « +X » collé à elle. Les séries NON
> FAITES sont la même flamme, mais très transparente.**

Traduction contractuelle :
- `montrees = min(done, 5)` flammes pleines ;
- si `done > 5` → la 5ᵉ porte `+\(done - 5)` **à côté d'elle**
  (`.inter(11, .semibold)`, dégradé blanc 0,92 → 0,38, la typo du
  `+N` actuel qui, elle, est bonne) ;
- les non faites : la MÊME flamme à **opacité 0,14-0,18**
  (mesurer sur capture : l'actuel `white 0.16` du symbole éteint
  est la bonne valeur de départ), en nombre `min(total - done,
  5 - montrees)` — la rangée ne dépasse JAMAIS 5 objets ;
- **la version ultra-compacte** que Kathryn cite (« une flamme et à
  côté +3 ») est le cas `1 flamme + « +3 »`. Deux lectures
  possibles — **à trancher** :
  - **A** : la règle ci-dessus (jusqu'à 5 flammes, +X au-delà) ;
  - **B** : TOUJOURS une seule flamme + « +N » (le maximum
    d'allègement, la rangée fait 45 pt au lieu de 100).
  Les deux se prototypent en une heure, verdict sur capture côte
  à côte.

### 2.3 Ce que ça supprime

Le sticker remplace les deux SF Symbols empilés : **plus de blur,
plus de deux ombres, plus de plusLighter** — les ~3 passes
offscreen par flamme allumée TOMBENT À ZÉRO. Sur la partition,
c'est ~75 passes offscreen supprimées.

⚠️ Ce qui MEURT avec elles, et qu'il faut assumer : le tremblé
(`vif`), la respiration (`souffle`), la dérive (`sway`), et surtout
**LA CÉRÉMONIE D'ALLUMAGE** (`FlammeJauge.swift:1291-1337` : le
flash, l'onde, la couronne de six diamants sur 0,8 s). Dans la
partition elle était déjà morte (`igniteAt: nil`), donc rien à
perdre. **Sur la page détail exercice, elle est VIVANTE** — c'est
la récompense visuelle d'une série validée. → §4.

---

## 3. LA LIGNE DE SÉRIE — la lune s'en va (et la pièce ?)

**La lune MEURT** (`SetHistoryRow.swift:89-159`) : « c'est trop
chargé à gauche ». Ce qui part avec elle : 32 pt de large, **trois
rastérisations de path** (18 cubiques chacune, corps + liseré +
néon), un **blur offscreen**, et surtout **l'animation
`repeatForever` par ligne** (`:154-158`, sans garde
`reduceMotion`) — une animation implicite perpétuelle par ligne,
qui maintient son calque vivant en permanence.

À la place, la maquette de la rangée suggère l'alignement : le
numéro de série (`Set 1`) se cale sur la colonne du numéro
d'exercice — la ligne de série devient un décalage, pas un objet.

**LA PIÈCE — la vraie question de poids** (§0, surprise 1). Trois
options, à trancher :
1. **La garder telle quelle** — chaque ligne faite garde son
   horloge 6 Hz + son shader (invisible au sim, réel au
   téléphone) ;
2. **UNE horloge pour toute la liste** — l'école `SeriesCoinFlight`
   (`RestartSheet.swift:414-510`) : un seul `TimelineView`, N
   appels `ShaderLibrary.moonCoin` bruts. Le rendu ne change pas
   d'un pixel ;
3. **La pièce devient une image** dans la liste (le shader reste
   pour BRAVO et le coffre, là où on la regarde vraiment) — le
   maximum d'allègement.
Recommandation : **(2)** — même image, coût divisé, aucun verdict
esthétique à re-rendre.

**Le gain de largeur** : −32 (lune) sur la ligne, −41 (photo +
chevron) sur la rangée. La ligne de série retombe à **≈ 321 pt**
de minimum : sous la barre partout, y compris sur un 375 pt. **Le
problème de largeur du §0 disparaît par la soustraction** — et le
`.padding(.horizontal, 6)` de compensation posé dans
`StoryDetails` pourra revenir à 24.

---

## 4. LA PAGE DÉTAIL EXERCICE — le même composant, l'autre vie

`FlammesRow` a **DEUX appelants** :
- `SessionSlate.swift:437` — la partition, **gelée** (`t: 0`) ;
- `FlammeJauge.swift:285` — la carte « Séries » de la page détail
  exercice (`ExerciseDetailView.swift:1470`), **vivante** : elle
  reçoit `t`, `date`, `igniteAt`, et joue la cérémonie à chaque
  série validée.

Kathryn : « il faut aussi modifier le composant flamme de la page
détail exercice ». Donc **une seule rangée de stickers pour les
deux**, mais avec un contrat d'animation explicite :

| | partition | page détail exercice |
|---|---|---|
| flammes | stickers, gelées | stickers |
| non faites | sticker à 0,16 | sticker à 0,16 |
| « +X » | oui, dès `done > 5` | oui |
| cérémonie | AUCUNE | **à conserver, portée sur le sticker** |

**La cérémonie, sur un sticker** : le flash `flame.fill` disparaît
(plus de symbole), mais **l'onde** (`Circle().stroke` 8 → 34 pt) et
**la couronne de six diamants** vivent au-dessus du sticker sans
rien lui demander — elles sont déjà des couches SwiftUI
indépendantes (`FlammeJauge.swift:1313-1337`). S'y ajoute un
**pop d'échelle** du sticker lui-même (1,0 → 1,18 → 1,0, keyframes
— ⚠️ un aller-retour ne se fait JAMAIS en deux `withAnimation`,
loi payée). Le reste (`vif`/`souffle`/`sway`) meurt : un sticker
qui tremble en permanence ferait cheap, et c'est justement ce
qu'on fuit.

⚠️ **Non-régression obligatoire** : `FlammeJauge` est aussi montée
dans **`PorteEntree.swift:1496`** (l'onboarding) et au banc
`-jaugeLab`. Les trois écrans se recapturent.

---

## 5. LES JALONS (une capture validée à chaque pas)

- **P1 — l'asset.** Recuit `sticker-flamme-serree` (§2.1 voie b) +
  planche de contrôle : la flamme à 14, 18, 24 pt sur noir, à côté
  de l'ancienne SF Symbol pour juger la finesse.
- **P2 — la rangée d'exercice.** Numéro + trait dégradé + nom, la
  photo et le chevron morts. Capture posée à côté de la maquette
  de Kathryn (pas vertical, contraste actif/endormi, graisse du
  chiffre).
- **P3 — les flammes-stickers**, règle §2.2 variantes A et B côte à
  côte, dans la partition. Verdict de Kathryn sur la variante.
- **P4 — la ligne de série** : la lune morte, l'alignement des
  colonnes, et la pièce passée à UNE horloge (§3, option 2).
  Mesure AVANT/APRÈS à la `SondeCadence`, **sur téléphone** (le sim
  est aveugle au coût du gyro).
- **P5 — la page détail exercice** : la rangée neuve + la cérémonie
  portée sur le sticker ; non-régression `PorteEntree` et
  `-jaugeLab`. Verdicts téléphone.
- **P6 — les largeurs** : le `padding(.horizontal, 6)` de
  `StoryDetails` revient à 24, et le commentaire des 342 pt est
  corrigé à 353 (§0).

---

## 6. À TRANCHER PAR KATHRYN

1. **La règle des flammes** : variante **A** (jusqu'à 5 flammes,
   « +X » sur la dernière) ou **B** (TOUJOURS une flamme + « +N »,
   l'allègement maximal) ?
2. **Le numéro** : `01`/`02` à deux positions (comme la maquette)
   ou `1`/`2` ? Et sur la ligne de série : `Set 1` reste, ou
   devient `1` aligné sous le numéro d'exercice ?
3. **Le trait** : argent (proposé) ou chaud comme la lame de la
   molette (`SetEntrySheet`) ? Et vit-il sur la ligne ACTIVE
   seulement, ou aussi sur les faites ?
4. **La pièce** : option 1, 2 ou 3 du §3 ? (recommandation : 2)
5. **La cérémonie** sur la page détail exercice : on la garde
   (onde + couronne + pop) ou la séance devient muette là aussi ?
