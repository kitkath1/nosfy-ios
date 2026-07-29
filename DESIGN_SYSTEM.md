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

## La carte Objectif (métal brossé sous lavis)

La carte « Objectif hebdomadaire » de la home : un rectangle arrondi (30 pt) de **métal brossé sombre sous un lavis de lumière blanche directionnel** venant du coin haut-gauche — référence : les mocks glassmorphism premium (carte sombre éclairée par une source hors-champ). Fichiers : [ObjectiveCard.swift](Woop/Views/ObjectiveCard.swift), passe `objectiveCrest` dans [DemonSky.metal](Woop/DemonSky.metal).

**Trajet des itérations (leçons)** : mesa + nébuleuse spectaculaire → rejetée (« écrase la home ») ; cordon discret + étoiles → rejeté (« pas de matière ») ; blob radial de lumière → rejeté (« lampe torche, cheap »). Ce qui tient : une MATIÈRE (le brossage) sous une LUMIÈRE directionnelle. Un dégradé sombre sans texture lit « plastique ».

- **Le lavis** : projection diagonale depuis le coin haut-gauche, réponse de métal (épaule vive `pow 2.6`, longue traîne), irrégularisé ±12 % par un bruit large — coin ~33 %, mi-carte ~6 %, bas-droit noir absolu. Il respire (±9 %, périodes incommensurables).
- **Le reflet traversant** : bande anisotrope lente (~36 s/passage) qui MULTIPLIE le lavis (il révèle la matière, n'ajoute jamais de gris dans le noir).
- **Le brossage** : micro-stries ~14:1 STATIQUES (la surface ne bouge pas, c'est la lumière qui vit), centrées, visibles seulement dans la lumière.
- **Grain de film** : discret dans le noir (anti-banding), renforcé dans le dégradé (~9/255) — la signature des mocks premium. Tombée d'arête aux bords (l'objet a une épaisseur). Chromie : blancs FROIDS acier.
- **L'arête usinée** : hairline 0,8 pt en dégradé ANGULAIRE à pics spéculaires — arc blanc froid au coin haut-gauche courant sur le bord haut, écho discret au coin opposé, quasi-noir entre ; lueur serrée sous l'arc seulement. Au TOUCHER (Button sans action + `ObjectiveCardPressStyle` qui republie `isPressed`) : tout s'allume et pulse (±20 %, 1,9 s), allumage 0,22 s / extinction 0,9 s, haptique douce. `achieved` réchauffe l'arc vers l'or.
- **Socle** : Liquid Glass natif teinté fumé (`glassEffect(.regular.tint(noir 0.55).interactive())`) — le ciel se réfracte au scroll ; jamais de fill opaque dessous. Fil inscrit à 1,5 pt + souffle haut (épaisseur du verre). Grain WoopGrain par-dessus.
- **Contenu** : titre 15 pt, `ShimmeringNumber` 34 pt (glint argenté ~7 s, fenêtré 22 %), sous-titre 13 pt, trophées 44 pt justifiés en style `luminous`. Carte purement consultative (ni chevron, ni navigation).
- **Budget** : une seule passe demi-résolution (3 fetches), `TimelineView` 30 fps, endormie hors écran et sous Reduce Motion. Boucle 900 s (dérives entières, k entiers). NebulaStrip n'est plus chauffée au lancement (gardée en réserve).

## Le bouton primaire « diamant »

**LE composant bouton primaire du système** (CTA « CONNEXION » de l'auth, et
tout appel à l'action majeur) : un bijou d'obsidienne — fumée noire vivante
serclée d'une hairline qui scintille. Référence : capture d'un bouton premium
(ligne inégale, halos discrets, fumée). Fichiers :
[DiamondButton.metal](Woop/DiamondButton.metal) (l'écrin, une passe),
`DiamondConnexionButton` dans
[ConnexionButtonLab.swift](Woop/Views/ConnexionButtonLab.swift) (texte +
flèche). Banc d'essai : argument de lancement `-buttonLab` → page noire nue.
Validé **10/10** par la boucle workflow (capture → juge sur grille chiffrée →
orfèvre), 3 rounds.

- **Architecture** : tout l'effet dans UNE passe `colorEffect` sur un
  rectangle élargi de 34 pt de marge — halos, particules et éclats vivent
  HORS du bouton, en alpha prémultiplié, jamais en aplat noir sur la page.
- **Forme** : 58 pt de haut, rayon 19 pt continu (PAS une capsule),
  marges latérales 26 pt.
- **Liseré** : hairline ~1 pt à luminosité INÉGALE — accents fbm paramétrés
  par la POSITION sur le bord (l'angle `atan2` fige les accents sur les
  longs bords : leçon), vifs en haut et sur les flancs, murmure en bas ;
  respiration ~6 s. La visibilité se règle à la LUMINOSITÉ, jamais à
  l'épaisseur.
- **Halos** : buée blanche aux accents seulement, amplitude ≤ 0.50 (au-delà
  = néon = interdit), fondu court (~15 pt) — la lumière reste collée au
  bouton.
- **Fumée** : NOIRE dominante (socle 3,8 % → 1,2 %), volutes fbm à double
  déformation de domaine, 3 plans de nuances superposés en parallaxe, plus
  dense (+30-50 %) sous les accents du liseré — elle « touche » la lumière.
  Jamais laiteuse : moyenne intérieure ≤ 8 %.
- **Particules** : poussières ~1 px éjectées le long de la normale du bord,
  3-8 visibles, pondérées par la lumière locale.
- **Éclats-étoiles** (l'effet bague) : cœur vif + rayons hairline en croix
  qui FLEURISSENT au pic du flash (~12 pt) puis se referment ; flashs rares
  (~1 s toutes les 7-18 s par site), 2-4 visibles — des étincelles, jamais
  des confettis.
- **Texte** : capitales 13,5 pt medium, tracking 4,6, dégradé blanc → gris
  PRONONCÉ (100 % → 54 %) ; flèche `arrow.right` light 15 pt à 22 pt du bord.
- **Pièges appris** : l'alpha du bord doit inclure la hairline (sinon la
  rampe d'opacité la mange à d ≈ 0) ; le shader JIT-compile ~5 s au premier
  rendu (capture noire avant) ; vérifier l'ANIMATION sur 3 captures espacées
  d'1 s, jamais sur une seule frame.

## L'input « diamant » (champ de saisie)

Le petit frère SOBRE du bouton primaire — avec lui, le trio de l'auth :
**input vide / input actif / bouton**. La hiérarchie est le cœur du
composant : le bouton est le bijou, l'input est l'écrin fermé qui s'éveille
au toucher. Shader `diamondInput`/`inputRim` dans
[DiamondButton.metal](Woop/DiamondButton.metal), vue `DiamondInputField`
dans [ConnexionButtonLab.swift](Woop/Views/ConnexionButtonLab.swift).
Banc : `-buttonLab` (vide + actif empilés au-dessus du bouton).

- **Fond** : métal noir qui brille à peine — dégradé vertical (5,2 % → 2,4 %),
  reflet traversant lent (~33 s/passage, MULTIPLICATIF : il révèle, ne grise
  jamais), micro-brossage horizontal statique visible seulement dans la
  lumière. AUCUNE fumée, aucune particule, aucune croix : la sobriété EST
  le composant.
- **Liseré** : hairline ~1 pt discrète, 2-4 accents blancs localisés
  (bruit positionnel, seuil dur `pow 4`, gain 4,6), respiration ±20 %.
  Scintillement : pointes fines aux accents (flashs rares `pow 14`),
  jamais de rayons en croix (réservés au bouton).
- **Deux états** (paramètre `active` du shader, rampe lissée 0,45 s côté
  SwiftUI — un paramètre de shader ne s'interpole pas tout seul, on
  horodate le basculement et le TimelineView fait la rampe) :
  - **Vide** : le liseré murmure (accents à 55 % de leur pleine lumière),
    placeholder en dégradé blanc foncé (62 % → 34 %).
  - **Actif** (focus ou texte) : accents à pleine lumière, texte en dégradé
    blanc clair comme le bouton (100 % → 58 %), et **lumière d'éveil** —
    un tout petit peu de lumière descend du bord haut dans le fond noir
    (7,5 % au sommet, éteinte avant mi-hauteur ; `exp(-uvY·3.8)`).
- **Icône** (enveloppe) : weight light 15 pt, dégradé blanc 92 % → 48 %.
- **Forme** : 54 pt de haut, rayon 17 pt continu, mêmes marges que le
  bouton (26 pt), marge shader 14 pt (le souffle des accents est minuscule).
