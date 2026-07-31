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

## Les composants « diamant » (la famille)

La bibliothèque de composants de l'app — même matière, même grammaire
(monochrome blanc, hairline, obsidienne), sept états sur le banc
`-buttonLab` : **bouton retour rond / input vide / input actif / bouton
repos / bouton tap / secondary repos / secondary tap**. La hiérarchie se
lit d'un coup d'œil : primaire tap > repos > secondary tap > input actif >
secondary repos > input vide, le rond en murmure. Méthode de fabrication :
boucle workflow capture simulateur → juge (grille /10 chiffrée, 3 frames
espacées d'1 s pour l'animation) → orfèvre.

Les SURFACES de la famille ont leurs propres bancs : la surface de base
(toutes les cartes), la carte Objectif « bijou » (`-cardLab`) et le cadran
éclipse (`-counterLab`). Même grammaire, autre échelle : sur un bouton la
lumière est un accent, sur une surface elle doit tenir une matière — c'est
là que le brossage, la nébuleuse et l'abscisse curviligne du liseré
apparaissent.

**L'effet wahou du tap** (commun aux deux boutons texte) : au toucher, des
volutes de fumée noire S'ÉCHAPPENT du liseré et enveloppent le bouton par
l'extérieur (portée ~25 pt, fondue avant les voisins), en plus de l'éveil
intérieur — tout éclot sur la rampe de 0,30 s, se résorbe en 0,55 s.
Absent au repos : le contraste fait le wahou.

## Le bouton primaire « diamant »

**LE composant bouton primaire du système** (CTA « CONNEXION » de l'auth, et
tout appel à l'action majeur) : un bijou d'obsidienne — fumée noire vivante
serclée d'une hairline qui scintille. Référence : capture d'un bouton premium
(ligne inégale, halos discrets, fumée). Fichiers :
[DiamondButton.metal](Woop/DiamondButton.metal) (l'écrin, une passe),
`DiamondPrimaryButton` dans
[ConnexionButtonLab.swift](Woop/Views/ConnexionButtonLab.swift) (texte +
flèche ; `DiamondConnexionButton` en est l'alias historique). Banc d'essai :
argument de lancement `-buttonLab` → page noire nue.

Il porte désormais **tous les appels à l'action majeurs** : « COMMENCER UN
ENTRAÎNEMENT » de la home, la confirmation de nouvelle séance, « LANCER
L'ENTRAÎNEMENT » de la fiche d'exercice. Le libellé est un paramètre ; la
gouttière de la flèche (46 pt) est réservée dans la mise en page et un
libellé long rétrécit un peu (`minimumScaleFactor` 0,72) plutôt que de
passer dessous. Au-delà d'une trentaine de signes, le registre gravé
décroche — c'est la limite du composant, pas un réglage.
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
- **État TAP (l'éveil du bijou)** — paramètres `press`/`burst` du shader,
  pilotés par `DiamondPressStyle` (republie `isPressed`, tasse le bouton à
  0,988 — l'objet a un poids) :
  - rampe lissée horodatée côté SwiftUI : 0,30 s à l'allumage, 0,55 s au
    relâcher ;
  - **onde du toucher** : un anneau de lumière qui s'évase du liseré
    (rayon 8 → 38 pt) et s'éteint en ~0,3 s — le contact se VOIT naître ;
  - le fond s'accentue : volutes de fumée +70 %, socle +1,2 %, toujours
    noire dominante ;
  - le scintillement se démultiplie : accents +35 %, plus de facettes
    éveillées (seuil +0,16), flashs plus fréquents (pow 16 → 7), rayons
    +40 %, particules +50 %, buée épanouie (fondu 15 → 20 pt) ;
  - dans le banc, la copie `benchPress: 1` fige l'état tap sous le bouton
    au repos — les deux se comparent d'un coup d'œil.
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

## Le bouton retour rond (icône seule)

Le bouton icône du système (retour, fermetures) — remplacera les boutons
de navigation actuels. `DiamondBackButton` dans
[ConnexionButtonLab.swift](Woop/Views/ConnexionButtonLab.swift), anneau
`diamondRing` dans [DiamondButton.metal](Woop/DiamondButton.metal).

- **Forme** : disque de 46 pt, en tête de pile côté gauche.
- **Fond** : Liquid Glass NATIF (`glassEffect(.regular.tint(noir 0.45)
  .interactive(), in: Circle())`) — le fond se réfracte dans le verre,
  même matériau que le socle de la carte Objectif. Jamais un disque plat.
- **Anneau** : hairline ~1 pt imparfaite posée SUR le verre — 2-3 accents
  inégaux qui rampent (dérives 0,14/0,26, respiration ±22 %), pointes de
  scintillement rares — un murmure ; l'intérieur du shader est transparent,
  le verre respire dessous.
- **Icône** : chevron 16 pt medium, dégradé blanc 95 % → 55 %, centré.

## La surface « diamant » (toutes les cartes)

`DiamondSurface` / `.diamondSurface(cornerRadius:neon:)` dans
[Theme.swift](Woop/Theme.swift) — la surface de base de l'app, celle que
portent `WoopCard` et toutes les cartes. Elle remplace l'ancienne « surface
métal » (dégradé `#191920` → `#07070A` + reflet spéculaire blanc 7,5 % en
haut), qui lisait gris-vert sur le fond quasi noir.

**Pourquoi le noir pur** : les photos d'exercice ont un fond NOIR ABSOLU.
Sous elles, la moindre plaque grise redessinait le rectangle de l'image dans
la carte. En noir pur, l'image n'a plus de bord — photo, carte et page ne
font qu'une seule matière, et seuls le corps et le muscle en lumière
flottent. C'est aussi ce qui autorise à mélanger les formats de photo (4:5,
3:4, 3:2 selon la série) sans que personne puisse le voir.

- **Fond** : `Color.woopCard` = noir pur. Un seul token, trois surfaces
  (carte standard, carte hebdomadaire brumeuse, carré de séance récente).
- **Liseré** : `WoopGradient.diamondRim` — exactement celui du bouton
  primaire (blanc 65 % en haut → éteint à 40 % de la hauteur). Il ne suit
  PAS l'azimut 225° du ciel comme l'ancien `bevel` : les composants diamant
  sont éclairés par leur propre lumière de bijou, pas par celle de la scène.
  Variante `diamondRimNeon` (blanc 88 %, murmure violet à mi-parcours) pour
  la surface mise en avant.
- **Éclats** : `.diamondGlints(strength: 0.5)` — les facettes du bouton, en
  murmure. À 1.0 elles appartiennent au CTA ; une page entière de cartes qui
  scintillent au même volume que le bouton d'action n'a plus de hiérarchie.
  0,75 sur la surface `neon`.
- **Ce qui a disparu** : l'ombre portée (rayon 22, y 14). Sur du noir posé
  sur du noir elle ne dessine rien — c'était le poste le plus cher de la
  carte, payé pour zéro pixel. Idem le reflet spéculaire.
- **Budget** : les éclats s'endorment hors écran (`onScrollVisibilityChange`,
  même contrat que la carte hebdomadaire) — une grille d'exercices en porte
  une douzaine à la fois. La sonde vit sur un calque vide qui, lui, ne
  disparaît jamais : sous le pli on retire le `TimelineView`, pas
  l'observateur, sinon plus personne pour annoncer le retour.
- **Réserve connue** : sur les écrans à ciel (home, liste d'exercices), une
  carte noire ne « fond » pas dans la nébuleuse — elle y découpe un trou.
  Assumé pour l'instant : le ciel sera traité séparément.

## La carte Objectif « bijou » (la pierre sertie)

La carte « Objectif hebdomadaire » de la home — la seule surface de l'app qui
porte un ciel INTÉRIEUR. Tout en une passe :
[ObjectiveJewel.metal](Woop/ObjectiveJewel.metal) (`objectiveJewel`), vue
`JewelSurface` dans [ObjectiveCard.swift](Woop/Views/ObjectiveCard.swift).
Banc : `-cardLab` → page noire, la carte au repos et sa copie « doigt posé ».

**Trajet des itérations (leçons)** : mesa + nébuleuse spectaculaire → rejetée
(« écrase la home ») ; cordon discret + étoiles → rejeté (« pas de matière ») ;
blob radial de lumière → rejeté (« lampe torche, cheap ») ; métal brossé sous
lavis directionnel → rejeté (trop clair, il lisait gris brossé, pas pierre) ;
et le **Liquid Glass natif teinté fumé** → abandonné ici : il grisait la pierre
(amplitude intérieure mesurée 2,2:1 contre 19:1 sur la référence) et sa
réfraction contredisait la lecture « bijou serti ». Ce qui tient : du VIDE noir
que seule la lumière du sertissage détache de la page.

- **Architecture** : une passe `colorEffect` sur un rectangle élargi de 18 pt —
  halos et éclats vivent HORS de la carte, en alpha prémultiplié, jamais en
  aplat noir sur le ciel.
- **Forme** : rayon 30 pt continu, marges 20 pt.
- **La pierre** : obsidienne 2,4 % → 0,35 %, sous un clair-obscur (`vfall`) —
  la lumière tombe d'en haut, TOUT ce qui éclaire s'éteint vers le bas. Sans
  lui, la nébuleuse rallume le tiers bas et le dégradé s'INVERSE dans la moitié
  basse (mesuré : 7,4 → 11,3/255 au lieu de descendre).
- **Les griffes** : brossage anisotrope à −22° qui **MULTIPLIE** la lumière au
  lieu de s'y ajouter — une griffe n'existe que là où la lumière tombe. C'est ce
  qui autorise des sillons jusqu'au noir sans grisailler les zones sombres, là
  où un terme additif écrêterait. Gating `rightness` : muet à gauche, pleine
  matière sur le flanc droit (la demande d'origine).
- **La lumière rasante** : un voile large qui traverse en ~34 s, sur une course
  PLUS COURTE que la carte — un effet qu'on ne voit qu'une seconde sur trente
  n'existe pas.
- **La nébuleuse et les poussières** : nappes fbm à domaine déformé ; étoiles
  sur trois grilles premières entre elles (le semis reste dense sans faire
  motif), magnitudes en **loi de puissance** (`pow(h.z, 2.8)`) — c'est la
  hiérarchie « beaucoup de très faibles, deux ou trois vives » qui fait lire
  « ciel » plutôt que « bruit de capteur ». Une distribution plate ne marche pas.
- **Le sertissage** : hairline 0,53 pt (σ 0,32), lumière INÉGALE paramétrée par
  l'**abscisse curviligne** du périmètre (`jArc`) et non par l'angle depuis le
  centre — l'angle fige les accents sur les longs bords horizontaux (piège payé
  sur le bouton primaire), l'abscisse les fait ramper à vitesse constante,
  coins compris. Le bruit est échantillonné sur un CERCLE d'abscisse : aucune
  couture au raccord. Plancher de fil à 10 % : sans lui la lumière n'est plus
  inégale, elle est INTERROMPUE — et un fil coupé ne sertit rien.
- **Les halos** : collés au trait (fondu ~2,2 pt), aux accents seulement. Au-delà
  c'est le brouillard diffus qui est refusé.
- **Les éclats de taille** : cœur vif + rayons hairline en croix, seuil 0,13,
  flashs `pow 12` — 2 à 4 visibles sur TOUT le périmètre, jamais une guirlande.
- **Le TAP** (`ObjectiveCardPressStyle` republie `isPressed` ; rampe 0,35 s
  horodatée côté SwiftUI) : une braise DANS la pierre (+0,9 % sous le bord
  haut) et le liseré qui ne monte que de 14 %. Une carte n'est pas un bouton :
  allumer le cadre seul faisait un interrupteur, et elle ne doit pas exploser
  sous le doigt.
- **`achieved`** : SEULE la lumière du liseré se réchauffe vers l'or-récompense
  (`1.0 / 0.945 / 0.80`) ; la pierre, elle, reste noire.
- **Contenu** (inchangé) : titre 12 pt medium capitales tracking 2,2 à 58 %,
  `ShimmeringNumber` 34 pt (glint argenté ~7 s, fenêtré 22 %), sous-titre 13 pt,
  trophées 44 pt justifiés en style `luminous`. Carte purement consultative.
- **Budget** : une passe pleine résolution à 30 fps, endormie hors écran
  (`onScrollVisibilityChange`) et sous Reduce Motion, horloge globale 900 s.
  Dither obligatoire : à 2 % de luminance, un dégradé propre bande en escalier.
- **Nyquist (leçon chère)** : à 3x il vaut 1,5 cycle/pt. Au-dessus, la griffe ne
  griffe plus, elle SABLE (poudre grise) ; très en dessous, elle devient une
  traînée nuageuse — du flou de mouvement, pas du métal. La fenêtre est étroite,
  et le réglage se fait à l'AMPLITUDE, jamais à la fréquence seule.
- **Reste à faire** : le brossage déborde encore en traînées larges là où la
  référence tient des hairlines de 1-2 px — cible mesurée : écart-type
  passe-bande 2,7/255 sur le flanc droit, au-delà de 4/255 c'est raté. Trop
  visible est une faute aussi grave qu'invisible. `GlassLight` et `GlassBorder`
  sont devenus du code mort dans ObjectiveCard.swift.

## La carte « obsidienne » (verre fumé noir, source hors champ)

Le DOUBLON de travail de la carte Objectif : même contrat, autre matière.
[ObsidianCard.metal](Woop/ObsidianCard.metal) (`obsidianSurface`), vue
`ObsidianGlassCard` dans [ObsidianCard.swift](Woop/Views/ObsidianCard.swift).
Banc : `-obsidianLab`. La carte bijou reste intacte : les deux sont
interchangeables sur la home, on peut les comparer sans rien réécrire.

Ici on ne cherche plus une pierre qui contient un ciel, mais une **plaque de
verre fumé lisse éclairée par une lampe posée hors du cadre**, en haut à gauche.
Toute la matière est de la lumière ; il n'y a aucune texture.

**Calquée sur une référence photographique**, puis **retouchée à l'œil**. Deux
régimes successifs, et l'ordre compte :

1. *Le calque.* Référence finale `ref/blue-hd.png` (la variante à accent bleu),
   échelle 2,2873 px/pt. Écart final **6,0 % pondéré sur 34 points de
   contrôle**, soit 9,4/10 — luminance 4,9 %, teinte 8,2 %.
2. *L'œil.* Kathryn a ensuite fait dévier du calque sur cinq points (voir plus
   bas). Ces écarts sont VOULUS : ne pas les « corriger » en relançant un
   ajustement sur la référence.

Outillage : `~/Downloads/woop-obsidian`. `preview` rend le shader hors app en
5 s (`./preview <shader> <png> <lit> [t]`), `measure-hd.py` sort la table
« nous / réf / écart » et la note, `diag.py` sort les profils du bord et les
R−B, `descc*.py` fait une descente par coordonnées qui note le VRAI rendu.

**Le barème doit noter la TEINTE, pas seulement la luminance.** Un or deux fois
moins saturé que la référence (R−B +70 contre +122) passait à 9,0/10 sur un
barème de luminance seule — un défaut que l'œil voit immédiatement. La note est
`0,65 × luminance + 0,35 × teinte`, et elle est tombée à 8,1 le jour où la
teinte est entrée dedans.

- **Là où le brief texte contredit la référence, la référence gagne.** Trois
  valeurs annoncées étaient fausses : socle `#17181C` (mesuré 11/255, deux fois
  plus noir), ombre portée sous la carte (il n'y en a AUCUNE : la page reste
  `#000000` jusqu'au ras du bord), spot froid bleuté `#303442` (il est gris
  légèrement CHAUD, `#6D635B`). Rayon annoncé 36-42 pt, mesuré 27 — retenu
  **20 pt**, voir les écarts voulus plus bas.
- **Saturation PAR CANAL** : `1 - exp(-x * k)` avec `k` la couleur intrinsèque
  de la source (chaude : `1 / 0,456 / 0,154`). Une lumière ambrée qui monte
  sature le rouge d'abord, le bleu en dernier — ambre → or → crème → blanc.
  Tonemapper la luminance PUIS colorier donne un cœur BLANC au milieu de la
  carte : erreur la plus visible du parcours.
- **La décroissance le long des arêtes est EXPONENTIELLE** (λ 32 pt), pas
  gaussienne. Vérifiable : l'intensité vaut 2,87 / 1,058 / 0,354 / 0,108 /
  0,018 à u = 65 / 95 / 130 / 175 / 225 pt — une seule exponentielle les tient
  à 3 % près. Une gaussienne tombe huit fois trop vite dans la traîne tout en
  étant juste au milieu, et **aucun terme ajouté ne rattrape** : il faudrait
  qu'une fonction décroissante vaille plus loin que près. Il faut changer la
  FORME, pas ajouter un lobe.
- **Deux nappes, pas deux bandes** : exponentielle le long de l'arête ×
  gaussienne en profondeur, une pour le bord haut, une pour le bord gauche,
  plus un remplissage de coin. Une bande à profondeur courte et forte
  amplitude dessine un « L » à bord net, très artificiel.
- **Le voile de droite est un FAISCEAU OBLIQUE**, pas un halo de coin : sa
  crête glisse de u=331 à u=236 entre v=16 et v=200 (pente −0,50 pt de u par pt
  de v) à largeur constante (FWHM 63 pt). Un halo de coin + une traînée
  verticale ne peuvent pas produire ça ensemble.
- **UNE SEULE bordure, un dégradé collé à l'arête.** La référence a un double
  trait (contour + seconde ligne 3,2 pt à l'intérieur, deux fois plus
  brillante : le biseau du verre) et il a longtemps été reproduit. Kathryn l'a
  fait retirer, référence en main — son propre écran de login n'a qu'une lueur
  dégradée : « c'est juste UNE qui est dégradée ». Un profil gaussien unique
  (centre d = −1,4 pt, σ 1,05) remplace les deux. **Test de non-régression** :
  la luminance doit DÉCROÎTRE de façon monotone depuis l'arête vers l'intérieur
  — une bosse plus loin, c'est une seconde ligne qui repousse (`diag.py`).
- **Le trait n'existe QUE là où la lumière le touche.** En bas et à droite, le
  contraste bord/surface doit être nul (mesuré +1 et −1 niveau) : la carte n'est
  pas cernée, elle fond dans le noir. Tant qu'il restait +6 en bas, Kathryn
  voyait « le liseré d'une card ».
- **Piège : une fonction de la distance au FOYER est un ANNEAU.** La bande
  chaude du trait (`bandC`), écrite en `dw = |q - src|`, rallumait le bord BAS —
  qui repasse dans l'anneau à dw ≈ 290 pt. C'était ça, le contour fantôme. Elle
  est désormais portée par la normale (haut et gauche seulement) et éteinte en
  descendant le flanc.
- **Le trait n'a pas la couleur de la nappe** : plus crème (mix 25 % vers
  `1 / 0,75 / 0,50`). Le biseau renvoie la lumière presque telle quelle, la
  masse de la pierre la colore.
- **Le bloom crème du coin a besoin de SON profil en profondeur.** Au ras du
  coin haut-gauche la référence est crème (`#FCF3CA`, R−B +50), pas or. Posé
  dans le trait, ce voile ne faisait rien : les deux lignes sont mortes à
  d = −2 pt, là où lui doit vivre. Il lui faut sa propre gaussienne.
- **La bavure bleue vit SOUS le bord**, pas sur l'arête : ellipse écrasée 1:3,8
  centrée à v = 7 pt. Centrée sur l'arête, elle inondait soit le trait
  au-dessus, soit tout le flanc droit.
- **L'accent bleu est gaté par la NORMALE** (`pow(max(-n.y,0), 3)`) : sans ça il
  coule le long du flanc droit et devient un contour.
- **La grille de points** (haut-droit) est antialiasée par couverture, pas par
  seuil : à 3x, un point de moins d'un point de diamètre scintille sinon.
- **Le TAP** : la source avance de 2,5 pt et gagne 6 %, le faisceau s'OUVRE
  (+26 % en long, +34 % en large). Deux impacts haptiques à 90 ms d'écart,
  faible puis fort — un seul impact se lit comme un interrupteur, deux se
  lisent comme un gonflement.
- **Rien ne sort de la carte.** La référence a un petit halo dehors ; Kathryn
  l'a fait retirer, parce que sur un fond qui n'est pas le noir absolu du banc
  il se lit comme une ombre portée sale.

### Les cinq écarts VOULUS par rapport à la référence

Ils sont le fruit de plusieurs allers-retours sur simulateur et ne doivent pas
être « recalés » :

1. **Rayon 20 pt** (mesuré 27) — trop rond une fois la carte en place.
2. **Nappe gauche réduite deux fois** (amplitude 1,84 → 1,25) et surtout
   **raccourcie** (portée 69,5 → 52 pt) : c'est la PORTÉE qui faisait « toute la
   bordure orange », pas l'amplitude. L'or se contient près du coin.
3. **Faisceau plus fin et FONDU** : un cœur de 20 pt d'axe court noyé dans une
   jupe de 46 pt. Un fil seul a des flancs nets et se lit « posé par-dessus » ;
   la jupe le fait entrer dans la pierre.
4. **Bleu à peine devinable** : R−B ramené de −25 à −14 sur le bord haut-droit.
   Il reste une présence froide, pas une zone bleue.
5. **L'or de gauche RESPIRE** : onde progressive descendante, ±3 % avant tone
   map, deux périodes incommensurables. Deux règles apprises ici — on module
   l'ÉPAISSEUR de la nappe, jamais son amplitude (l'amplitude fait clignoter,
   on voit le procédé) ; et l'écart image à image doit rester **sous ~1 niveau
   sur 255** en moyenne. À ±8 % Kathryn a dit « je vois l'animation », et une
   animation qu'on voit est un effet, pas une matière.

- **Reste à faire** : le contenu (titre, chiffre, trophées) n'a pas été
  retouché — il passe aujourd'hui DANS la zone chaude, et la grille de points
  mord sur les deux derniers trophées.

## Les photos d'exercice

Le catalogue est illustré par des **photographies**, plus par des figures
vectorielles (`ExerciseFigures` / `FigureEngine` supprimés). Registre :
clair-obscur, fond noir absolu, corps en silhouette, et le muscle travaillé
en surbrillance blanche anatomique. Composant : `ExercisePhoto` dans
[ExercisePhoto.swift](Woop/Views/ExercisePhoto.swift), assets `exo-<id>`.

- **Vignette de grille** (`fills: true`) : la photo REMPLIT la carte, bord à
  bord, recadrée au centre — c'est là que tombe le muscle en lumière sur
  toute la série. Le corps entier dans 150 pt serait un fil illisible.
- **Héros de la fiche** (`fills: false`) : la photo entière, jamais rognée —
  le mouvement complet (l'appui, l'angle, la machine) est l'information.
- **Pastille de séance** (46 pt) : même recadrage centré que la vignette.
- Le rognage est DANS le composant : une image `.fill` non coupée déborde
  silencieusement sur ses voisines, et sur du noir sur du noir on ne s'en
  aperçoit qu'au moment où un corps traverse une autre carte.
- **Un exercice sans photo n'existe pas** : le catalogue et les images sont
  tenus ensemble (`exercise.image` dérive de l'identifiant). Les deux
  exercices dont l'image a été retirée — soulevé de terre roumain, gainage
  militaire sur une jambe — ont été supprimés du catalogue. Les séances déjà
  enregistrées qui les citent gardent leur nom et se passent d'image.

## Le bouton secondaire

Le second rôle sous le primaire (« CRÉER UN COMPTE »).
`DiamondSecondaryButton` + `diamondSecondary`/`secondaryRim`.

- **Forme** : identique au primaire (58 pt / rayon 19 / marges 26),
  marge shader 30 pt (la fumée du tap s'échappe autour).
- **Fond** : NOIR PROFOND calme (3,0 % → 1,1 %) — ni le métal de l'input,
  ni la fumée du primaire. Une profondeur, pas une matière qui vit.
- **Liseré** : très discret mais FRANCHEMENT animé — rim dédié
  (`secondaryRim`, dérives 0,17/0,32, respiration ±24 %) : l'amplitude est
  basse, pas la vie. Pas de croix, pas de halos marqués.
- **Texte** : mêmes lois que CONNEXION (13,5 pt medium, tracking 4,6) mais
  EN RETRAIT : dégradé blanc 78 % → 40 %.
- **État TAP** : la fumée d'éveil — absente au repos, au toucher des
  volutes plus mobiles que celles du primaire naissent du liseré,
  fleurissent vers le centre (éclosion `mix(nearRim·1.6, 1, press)`) ET
  s'échappent autour (l'effet wahou) ; le liseré se relève (+25 %), les
  pointes scintillent davantage. Même rampe que le primaire (0,30/0,55 s)
  via `DiamondPressStyle`.

## Le cadran éclipse (compteur)

Le chrono d'effort en scène : un disque de velours noir posé sur la nuit,
QUATRE lumières qui tournent derrière — le disque les occulte, elles le
couronnent. `EclipseCounter` dans
[CounterLab.swift](Woop/Views/CounterLab.swift), tout l'arrière dans
[EclipseHalo.metal](Woop/EclipseHalo.metal) (`eclipseHalo`), banc `-counterLab`
(+ `-counterPressed` : bouffée figée au pic).

- **Forme** : disque 250 pt, hôte shader avec débord ×0,58 — et un
  `hostFade` qui fond TOUTE la lumière extérieure dans le noir avant le bord
  du rectangle : le tap ne doit jamais révéler que le théâtre vit dans un
  carré (appris à la première démo).
- **Les quatre voix** (jamais un rapport entier entre les périodes — le
  mouvement ne boucle pas à l'œil) : la basse (blanc lunaire, large, 47 s),
  l'alto (or orangé `1.0/0.70/0.33`, serré contre le bord, 29 s,
  anti-horaire), le soprano (blanc pur, petit et vif, 19 s), le ténor
  (abricot `1.0/0.78/0.50`, très large, 71 s). Chacune respire à son tempo
  (5,2–21 s). Étirées LE LONG du cercle (repère radial/tangentiel) : une
  lueur qui épouse le bord, jamais une « boule floue » (rejet immédiat).
- **L'éclipse** : occultation nette au bord (`smoothstep` ±2 px) ; la
  lumière ne déborde JAMAIS dedans. Couronne hairline au bord exact, faible
  partout, vive face aux voix, accents fbm qui rampent.
- **Le velours** : noir absolu au centre (le chrono vit là), un souffle de
  matière près du bord (`pow(r/R,5)`, ≤5 %) teinté par la lumière derrière.
- **Le chrono** : Inter Light 56 (graisse dédiée, hors du quatuor de
  Theme.swift — la Regular pèse à cette taille), dégradé blanc → 46 %,
  chiffres tabulaires. Caption petites capitales 10,5 tracking 3,8 à 30 %.
- **L'aiguille-balayage** : un fil 1,2 pt qui fait le tour en une minute —
  tête vive (92 %), queue qui se perd (7 %). Un trait, pas un anneau.
- **Le TAP — une bouffée, pas un état** : au contact (pas au relâcher),
  enveloppe attaque 0,10 s / extinction 0,7 s rejouée depuis l'horodatage :
  onde du toucher qui s'évase du liseré (~0,3 s), voix qui enflent d'un
  quart, volutes fractales qui GLISSENT vers l'extérieur (le champ est
  advecté par l'âge de la bouffée, 85 pt/s) puis se dissolvent. La fumée est
  ÉCLAIRÉE par les voix (loi serrée `cos⁷`) : elle fleurit face aux lumières
  et se tait dans l'ombre — sinon quatre voix couvrent tout et c'est un
  donut gris. Les étoiles-bijou intérieures ont été essayées puis retirées
  (« cheap »).
- **Le son** : tic minuscule chaque seconde (`DialTick`), un ton plus bas au
  passage de la minute (`DialTock`), souffle feutré au tap (`DialTap`) —
  synthétisés (modes résonants amortis + choc filtré, Woop/Sounds), joués en
  `.ambient` + `mixWithOthers` : le cadran ne coupe jamais la musique de la
  salle. Vibration du tap : `.impact(flexibility: .soft, intensity: 0.85)`.
- **Le spotlight de la nuit** (`nightSpotlight`, plein écran sous le cadran) :
  un pinceau oblique très fin qui descend du haut (~61°, balancement 29 s,
  respiration 23 s), ~5 % au cœur, dither obligatoire — à cette intensité un
  dégradé propre bande en escalier sur OLED.
