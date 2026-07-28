# Woop — Design System

App perso muscu/cardio. Direction : **premium minimal, monochrome blanc sur noir profond**, violet en unique couleur d'accent. Tout ce qui « sent le procédural », le néon épais ou le cartoon est hors-jeu. Les micro-détails comptent : le design se juge sur des crops zoomés et des captures comparées à des références réelles.

## Fondations

- **Palette** ([Theme.swift](Woop/Theme.swift)) : fond `woopBase` quasi noir à dominante froide ; surfaces « métal » en 3 tons (`woopMetalHigh/Mid/Low`) ; violet en 3 niveaux (`woopViolet`, `VioletCore`, `VioletDeep`) — un assaisonnement, jamais une teinte ; encres blanches à 3 opacités (`inkPrimary/Secondary/Muted`).
- **Matière** : toute carte = dégradé métal + reflet spéculaire + biseau 1 pt (`metalSurface`).
- **Token de lumière — azimut ~225°** : la seule source de la scène est le cœur de la nébuleuse en **bas à gauche**. Les biseaux des cartes s'allument côté bas-gauche et s'éteignent vers le haut-droite : les cartes sont des objets DANS le ciel, jamais posés dessus. Toute nouvelle surface suit ce token.
- **Chromie une seule famille** : le fond est N&B strict (±3,5 % max), ses ombres portent un sous-ton légèrement **violacé** (la famille de la marque — le CTA émerge du fond au lieu de vibrer contre lui). Le glow du CTA est contenu (il ne doit jamais teinter le ciel).
- **Typo** : SF Rounded partout, titres bold, chiffres en très grand.
- **Grain** (`WoopGrain`) : tramage statique ±, indispensable sur OLED contre le banding des dégradés sombres.

## Le ciel de la home (DemonSky)

Fond nébuleuse photoréaliste N&B — référence : une astrophoto réelle (cœur cramé blanc en bas-gauche, voûte noire étoilée, nuages volumétriques éclairés par la tranche, grain argentique). Fichiers : [DemonSky.metal](Woop/DemonSky.metal), [DemonSky.swift](Woop/DemonSky.swift), [NebulaNoise.swift](Woop/NebulaNoise.swift), intégré via `WoopBackground` (animé sur la home seulement, image figée ailleurs).

### Architecture

- **Deux passes** : nébuleuse en **demi-résolution** (tout y est diffus, upscale bilinéaire invisible, ÷4 de coût) + étoiles en **pleine résolution** (sub-pixel), composées en `plusLighter`. 30 fps bridés (`TimelineView(minimumInterval:)` — jamais nu : 120 Hz = ×4 GPU).
- **LUT de bruit** 512² tileable générée au lancement (fbm ×2, ridged multifractal Musgrave), passée en `.image` — 1 fetch remplace ~40 instructions de hash. Jamais de donnée dans le canal alpha (prémultiplication).
- **Simulation de lumière, pas peinture de dégradés** : accumulation HDR (le cœur monte à ~10) → émission (cœur + filaments + nuages éclairés) → absorption multiplicative (Beer-Lambert : silhouettes et masses noires DEVANT la lumière) → tone mapping filmique `1-exp(-kL)` → toe OLED. L'ordre est la règle.
- **Boucle de 900 s exactement** : dérives = nombre ENTIER de répétitions de texture par période, sinus en `k·2π/900` avec k entier, événements par fenêtres divisant 900. Le raccord est invisible ; float32 garanti (jamais de temps brut vers le GPU).

### Couches (de l'arrière vers l'avant)

1. Poudre d'étoiles (milliers, sub-pixel, loi de puissance `pow(h,14)`, stables)
2. Étoiles moyennes + brillantes (scintillement par sessions, halo Moffat)
3. Nébuleuse : nuages fbm warpés + rim lighting 2-tap vers le cœur + cœur HDR + wisps ridgés log-polaires + kaliset (texture fractale du halo)
4. Masses noires d'absorption (voûte) + silhouettes dans le halo
5. Héros (~7 étoiles, aigrettes rares) et brume de vent bas-droite
6. Particules fines d'avant-plan (bokeh précieux, scintillement marqué)

### Vie du ciel (micro-animations)

| Animation | Amplitude / période | Où |
|---|---|---|
| Évolution des nuages | dérives ×3, transformation visible en 10-20 s | toutes les couches fbm |
| Respiration de portée du halo | ±28 % (90 s + 39 s) | `reach` |
| Vacillement du cœur | ±9 % (7/47/180 s) | `coreI *=` |
| Marées des masses noires | ±24 % (450/180/90 s) | `tide` |
| Rafales de brume | onde progressive en x, s'éteint entre deux bouffées (36/22 s) | `gust` (clampé ≥ 0) |
| Sessions de scintillement | enveloppe 40-90 s par étoile | `session` |
| Flash de héros | +3.6×, ~1/30-45 s, fenêtres de 45 s | `spikes` |
| Étoile filante | ~1/2 min, fenêtres de 100 s, tête chaude + traînée | `meteor()` |
| Éclaircie furtive | déchirure ~10 s / ~2,5 min, rallume les étoiles derrière | `clearing` (2 passes sync) |
| Seeing | piqué ±9 % (60 s), quasi commun | `sig *=` |
| Occultation | l'étoile gonfle en s'éteignant (`T` bas → bloom) | `sig *=` |
| Révélation | 2 s de montée d'exposition, étoiles par rang de luminosité | uniform `reveal` |

### Profondeur (le plongeon 3D)

Un seul vecteur `tilt` (gyroscope CoreMotion lissé 0,8 s + recentrage lent ~15 s + **scroll** ×0.0009), démultiplié par couche : poudre ±8 pt → moyennes ±42 → héros ±66 → **particules ±84 pt**, nébuleuse ±18. Pleine amplitude à ~12° d'inclinaison. Coupé par Reduce Motion ; nul au simulateur (pas de capteur).

### Curseurs principaux

`E *= mix(0.32, …)` rampe verticale de noirceur · `exposure 1.18` · toe `0.0085` · ambiante `0.010` · masses `-2.2` · brume `0.24 * gust` · flicker/reach du cœur · gains des couches d'étoiles · multiplicateurs de `tilt`.

### Interdits (appris en itérant)

- Ridged mono-fréquence en polaire → **caustiques d'eau/soie**. Worley visible → **peau de girafe**. Les motifs procéduraux lisibles tuent le premium instantanément.
- Pulsation sinusoïdale globale unique (métronome), translation radiale (eau qui ruisselle), scintillement synchronisé (guirlande), scintillement de la poudre sub-pixel (fourmillement d'aliasing).
- Addition de calques sans absorption : le sombre doit pouvoir **gagner** sur le clair (profondeur), jamais l'inverse.
- Calibrer sur **captures comparées à la référence**, jamais à l'œil du code.

### Contrat ciel ↔ interface

- **Noir souverain** : ≥60 % de l'écran sous ~5 % de luminance ; le blanc cramé est un événement localisé bas-gauche, jamais une marée pleine largeur. Roll-off sous la tab bar hors hotspot.
- **Un seul ciel** : l'horloge est globale (temps absolu mod 900 s) — chaque onglet rend les mêmes pixels, animés seulement quand l'onglet est visible, **tamisés à −45 %** hors home. Le ciel ne se fige jamais sous les yeux.
- **Tab bar en verre fumé permanent** (`toolbarColorScheme(.dark)`) : la lumière qui traverse du verre sombre est une signature ; l'adaptatif devenait laiteux sur la brume.
- **Test du poster** (contrôle qualité) : 6-8 captures à des instants aléatoires de la boucle — chaque image isolée doit tenir au mur comme une astrophoto crédible. Toute frame qui échoue désigne le paramètre à retendre.

### Budget

~1-1,5 ms GPU/frame (A16+) : demi-résolution pour tout le diffus, pleine résolution réservée au sub-pixel, LUT plutôt qu'ALU, `half` pour la couleur / `float` pour coordonnées-temps-kaliset, pause hors `scenePhase.active`.

## La carte Objectif (crête)

La carte « Objectif hebdomadaire » de la home : un verre noir liquide dont le bord haut est **découpé en mesa**, avec une **corniche de nébuleuse blanche** accrochée à la découpe et un **fil de lumière** qui cerne toute la silhouette. Fichiers : [ObjectiveCard.swift](Woop/Views/ObjectiveCard.swift) (forme + verre + liseré), passe `objectiveCrest` dans [DemonSky.metal](Woop/DemonSky.metal) (la matière), contenu dans [HomeView.swift](Woop/Views/HomeView.swift).

- **Un seul profil** : `CrestProfile` (rise 46 pt, épaules en fractions de largeur `xa→xb` / `xc→xd`, asymétriques) est la source unique — la `Shape` Swift l'échantillonne à 1,5 pt, le shader le reçoit en uniforms et recalcule les MÊMES smoothsteps. C'est ce qui soude la matière à la bordure ; toute retouche du profil se fait là et nulle part ailleurs.
- **Repère-crête** : le shader travaille en (x le long du bord, y = profondeur SOUS le bord) — la matière épouse la mesa au lieu de la traverser. Bande `exp(-dy·k)` plus épaisse sur le plateau que sur les épaules (×0.35) : les flancs restent du verre sombre cerclé d'un fil.
- **Même grammaire que le ciel** : émission (rim embrasé à la bordure + nuages 3 octaves + wisps ridgés) → absorption Beer-Lambert (silhouettes qui mordent, y compris la crête) → compression filmique + toe OLED + dither 24 fps. Même horloge globale (temps absolu mod 900 s, dérives entières) : la carte est une fenêtre sur le même cosmos.
- **Le contraste est la règle** : seuil de nuages haut (les trouées NOIRES entre les masses font respirer la corniche), chute rapide (au niveau du titre il ne reste que du verre noir). La version laiteuse qui remplissait la mesa a été retendue — une purée grise tue le premium.
- **Liseré** : trois passes concentriques (halo 8 pt flouté 16, lueur 2,5 pt floutée 3, fil net 1,4 pt), traits centrés jamais rognés — la lumière déborde dans le ciel. Dégradé vertical (blanc pur à la crête → 0.36 en bas), masque qui n'éteint jamais le bas. Calques statiques, mis en cache par Core Animation.
- **Verre** : assise quasi noire (seul calque immuable → porte l'ombre), nébuleuse en `plusLighter`, grain, voile spéculaire. Ordre non négociable (cf. MistyMetalSurface).
- **Exception assumée au token 225°** : la bordure de la carte est sa propre source (la crête éclaire la matière qui la touche). C'est l'événement lumineux de la home avec le cœur de la nébuleuse — les deux seuls.
- **Deux passes, comme le ciel** : le diffus (`objectiveCrest`) en demi-résolution — le shader est écrit en unités relatives à `fall`, les uniforms arrivent divisés par deux ; la poudre d'étoiles (`objectiveCrestStars`) en pleine résolution, géométrie évaluée avant tout fetch, éteinte par les mêmes masses (proxy 2 octaves + silhouettes). Le dither 24 fps s'applique aussi dans la sortie anticipée (sinon couture de bruit en forme de crête au milieu du verre).
- **Objectif atteint** : le liseré se réchauffe vers l'or-récompense (`achieved`) — la seule célébration, pas de néon.
- **Hiérarchie** : cette carte est la SEULE à porter un ciel. `TimelineView` bridé 30 fps, endormi hors écran (`onScrollVisibilityChange`) et sous Reduce Motion. Les ronds trophées de la carte sont en style `luminous` (intérieur plus sombre + halo chaud) ; WeekDetail garde le rendu métal d'origine.
