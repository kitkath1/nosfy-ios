# LE CARNET DE CUIR — dossier de passation (19-08-2026, session fraîche)

La collection d'entraînements de la home est un carnet relié plein cuir :
fermé sur la home (remplace la pile swap), il s'ouvre EN PLACE en double
page ; les sessions sont des pages (Apple-style noir minimal — LA LOI :
jamais de gaufrage cuir côté pages) ; swipe = tourne de page ; tap page =
story. Réfs forgées : `~/Downloads/woop-carnet/refs/`, sondes :
`~/Downloads/woop-carnet/sondes/` (mesure_plaques.py, mesure_fenetres.py).

## Ce qui est VALIDÉ (ne pas y retoucher sans verdict)

- **Le carnet fermé sur la home** (commits ec9008d, 276d4d6) : plaque
  détourée aux arêtes dures (UnevenRounded 8/36), étoiles au ras du cuir,
  gyro SkyMotion (amorcé par AuroraHomeBackground — il était MORT sur
  toute la home aurora avant 276d4d6), amplitudes 0,90/0,65.
- **La cohérence physique** (d5749e0) : une seule molette (marge spread
  36), l'invariant = hauteur de couverture 248 pt ; fermé 177 pt de large
  = spread 330/1,86. Les deux plaques sont deux rendus IA étrangers —
  toujours mesurer aux ARÊTES DURES (gradient), jamais au seuil de
  luminance (reflet au sol / lueur de tranche faussent tout).
- **La matière vivante des plaques** (845bdcd, a706bc8) : carnetCuirV2
  (reflet multiplicatif 31 s, tranche qui respire ±3 %, lumière fixe au
  monde sous tilt) — RAS.
- **La page de session** (fe7920d) : contenu NU sur la fenêtre papier
  MESURÉE — jamais un fond, jamais un coin. Fenêtre droite (hauteur 248,
  depuis le centre objet) : x +1,40…+151,53, y −123,29…+123,52, coins
  10/8,9 pt, papier #1F1F1F, gradient 40→24/255, puits gouttière ±43 pt.
  Partition : insets 22/24/20/16, date .inter(16,.semibold), mesures
  .inter(11) inkMuted, sticker 54 pt bas-gauche (ombre -2/+3 r3 0,35),
  « +N » or 12,5 + piece-woop 16. La feuille porte les PIXELS de la
  plaque (crop px 736,102,519×857) — on ne fabrique jamais le papier.
- **Le design system swap** (b53ef64) : SwapCardSurface/Heading/Stat,
  A/B jumeaux prouvé. SwapDeck vit toujours (banc -deckLab).

## Ce qui est REJETÉ (les verdicts, la loi)

- Les stickers gaufrés cuir dans les pages (« pas Apple »), le carton
  posé sur le livre, la page-widget.
- **TOUTE simulation maison du papier qui se déforme** : 4 versions de
  shader (tapis-roulant → pli reculant → diagonale → cône bombé) —
  verdicts « trop image », « tordu », « matière horrible », 0/10. Le jury
  4 lentilles (wf_e7335097 : ombres 4,5 · matière 4,5 · géo 3,5 · luxe
  4,5) a tout mesuré ; même corrigée, la V4 reste rejetée EN MOUVEMENT.
  Leçon : les juges n'ont vu que des POSES — juger le FILM (recordVideo).
- La vidéo pré-rendue pour la tourne (mon erreur : morte pour les vraies
  données/interaction — REJETÉE à raison).

## LE PLAN ACTÉ : l'hybride SceneKit (la session fraîche commence ici)

Les POSES restent plaques+SwiftUI. Le MOUVEMENT (ouverture + tourne)
passe en VRAIE 3D — le métier du booster :

1. **La scène** : couvertures = SCNBox chanfreinés texturés des plaques
   (color/normal éventuelles à forger) ; bloc de pages avec tranches
   dorées ; feuille tournante = SCNPlane subdivisé.
2. **Le pli** = GEOMETRY SHADER MODIFIER — le précédent est ÉCRIT ET PAYÉ :
   le peeling développable du booster, `BoosterPack.swift:201-274`
   (spirale d'Archimède, normales ET tangentes tournées à la main,
   compensation de scale). Uniformes par KVC (piège : nom qui boite =
   zéro silencieux, BoosterPack.swift:65).
3. **La lumière** : directionnelle + env HDR FABRIQUÉ au runtime (fichier
   Radiance écrit en cache — une MTLTexture directe est ignorée,
   BoosterPack.swift:1146-1282) ; vraies ombres SceneKit.
4. **Le contenu** : page en vol = snapshot ImageRenderer en texture le
   temps du geste ; au repos = SwiftUI vivant par-dessus la scène.
5. **Le raccord 3D↔2D** : aspect EXACT + recouvrement « wake » (la leçon
   du sachet : aucun fondu ne survit à 14 % d'écart d'aspect,
   BoosterPack.swift:448-462 ; CarteLuneLab.swift:327).
6. **Drag** → q du modifier ; aimant sur predictedEnd (déjà au banc).
7. **Pièges booster à relire avant la première ligne** : cube noir omni
   (attenuationEnd < 1 au simu), zNear 0,5, euler à lacet π, SCNView
   fond noir en dur → .clear, et 18-36 img/s AU SIMULATEUR — le juge est
   LE TÉLÉPHONE (rebuild Xcode obligatoire pour Kathryn).
8. Un modèle 3D GLB/USDZ de carnet fourni par Kathryn accélérerait la
   coque (pipeline booster.bin : GLB décortiqué hors-ligne) — sinon
   géométrie en code.

## Les bancs et flags

`-carnetLab` (objet : tap = ouvrir/fermer, drag = tilt ; `-carnetP <p>`
fige l'ouverture, `-carnetTilt <tx,ty>`, `-carnetOuvert`) ·
`-carnetLab -carnetFeuille` (moteur maison V4-sobre : drag = tourne,
`-carnetQ <q>` fige) · `-carnetLab -carnetFeuille -carnetApple`
(RÉFÉRENCE DE GESTE : UIPageViewController .pageCurl, nos pages dedans —
l'étalon à battre). PIÈGE : sans `-carnetLab` devant, le splash lune.

Infra : dd-carnet/ (jamais commité), sims kat-carnet-a/b (Kathryn REGARDE
kat-carnet-b), captures `~/Downloads/woop-carnet/ab/`, commits toujours
PAR CHEMINS. `$SECONDS` ne se réutilise pas dans un même shell
(START=$SECONDS). `simctl launch` sur app ouverte ne relit pas les args.

## LA 3D — état au 19-08 soir (session interrompue, reprendre ICI)

FAIT (commits ea92b68 puis le moteur v3) : `CarnetScene.swift`, banc
`-carnetLab -carnetScene` (drag = tourne, tap = aller-retour, `-carnetQ`
fige, `-carnetSceneAuto` boucle à filmer). Lit = plaque photo lambert
calibré (raccord MESURÉ 987/988 px, camD 3,43) ; feuille deux peaux ;
GEOMETRY MODIFIER V3 aux formules PROUVÉES du physicien (jury
wf_578b2998) : cône rampant k(q)=0,26·(1−q)^1,5+0,06, arc aérien
(ventre 0,5 + traîne 0,22·qVel, garde-fous d'angle), torsion ±0,035,
flutter fenêtré sin²α, gouttière quartique C1, écart des peaux tourné
avec la surface, normale du cône exacte (les 2 fautes corrigées) ;
intégrateur CADisplayLink (ressort analytique, élan conservé, EMA 60 ms
sur qVel, teardown booster). Vraie ombre SceneKit, or du bord libre,
satin v1, clé rasante. NON VU À L'ÉCRAN depuis le passage v3 du
modifier : builder + capturer AVANT tout verdict.

## CE QU'IL MANQUE (les retouches chiffrées du jury, PAS appliquées)

Jury 4 lentilles (physique 5 · lumière 5,5 · matière 7 · geste 5,5),
verdicts complets dans le run wf_578b2998 ; l'essentiel à porter :

1. **Ressorts du geste (Coordinator.poser, un seul régime aujourd'hui)** :
   flick |v|>1,2 → response 0,38/ζ0,80 ; lâcher mou → 0,55/0,95 ;
   annulation (q<0,1 vers 0) → 0,30/ζ1,0 (0,25 si repoussé v<−0,5).
   Suivi du doigt : ω 56 → ~28 (τ≈40 ms, « la page chasse le doigt »).
2. **Mapping du drag** : course 240 → 300 pt, q = acos(1−2s)/π (le bord
   reste sous le doigt, mort de la zone morte) ; aimant à HYSTÉRÉSIS sur
   l'élan projeté q+0,18·v (commit>0,42 en avant, retour<0,58 en
   arrière ; pichenette ≥900 pt/s ⇒ commit dès q≥0,12).
3. **Rebond lumineux de la feuille** (le verso est une dalle éteinte,
   « tue-le-realisme ») : DANS le surface modifier, émission +=
   diffuse·fillGain·saturate(dot(N, normalize(−0,35,−0,15,0,55)))·gate
   de flexion — la photo ré-émise, jamais un gris plat ; fillGain ~0,35.
   ET ambiant 0,30 → 0,20 (les noirs remontés = plastique, juge matière).
4. **Ombre qui pince** : rampe pilotée par q depuis le tick (propriétés
   de keyLight) — mi-vol R20/A0,72 ; q<0,12 et q>0,72 → lerp vers
   R~7/A~0,80. Clé couchée (0,60, 0,24, 0,52) pour l'ombre longue.
5. **Or vivant** : base 0,20→0,14, flare pow2×1,6→pow4×2,2, STRATES
   procédurales le long de y (0,6–1,4 — le trait uniforme lit stroke
   CSS) ; tranches HAUT/BAS à 0,4× (largeur 0,003 uv, mortes à 8 % côté
   reliure) — tue la coupe rasoir noire du bord bas.
6. **Vallée d'occlusion sur le LIT** : surface modifier du lit, bande
   ×(1−0,20·exp(−((u−u_pli)·bedW/0,06)²)·sin πq) au pied du congé
   (u_pli = 0,5 + (sheetX + A)/bedW), qTurn à pousser aussi au bedMat.
7. **Satin** : gain 0,55 → 0,12, exposant 48 → 28 (jury : au-delà ça
   brille plastique).
8. **Haptique d'atterrissage** : UIImpactFeedbackGenerator .rigid 0,5
   quand q franchit 0,985 avec v>0,8 (une fois par pose) ; le flap du
   claquement sort déjà tout seul de l'arc aérien (élan résiduel).
9. **Chorégraphie des pièces** (polish, plutôt jalon 4) : le +80 de la
   page dessous n'apparaît qu'à q≥0,72 (l'instant deux-pièces-jumelles
   de q0,5) — à régler quand le contenu passera en SwiftUI vivant.
10. **Ombre de contact analytique** aux extrêmes (q<0,12 / q>0,88,
    alpha 0,30, ~26 pt) si la rampe (4) ne pince pas assez — reporté.
11. **INTERDIT confirmé** : ventre transverse en y (courbure de Gauss
    = caoutchouc) — ne jamais l'implémenter.

Après application : captures aux poses + film -carnetSceneAuto (frames
SERRÉES, mod 2 — le film sous-échantillonné a menti une fois), raccord
sonde, verdicts Kathryn sur B, PUIS la fluidité au téléphone. Ensuite
seulement : l'ouverture en 3D (couvertures SCNBox — étape 1 du plan).

## Restes hors 3D

Son + haptiques du papier (« pas de bruit » — à faire), respiration
d'invite du coin au repos, jalon 4 (vraies séances via @Query +
StorySession(workout:), une session/page, feuilletage branché dans
CarnetHome ouvert), jalon 6 (StoryPortal depuis le rect de page —
promouvoir un StoryLaunch partagé, celui de CalLab est private), jalon 7.
Économie : +20 pièces/série. Mémoire de session : woop-carnet-cuir.md.
