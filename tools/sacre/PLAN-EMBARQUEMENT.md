# PLAN D'EMBARQUEMENT — la démo booster complète (19-08 soir)

LE plan unique. Il consolide `PLAN-SUITE-DEMO.md` + `PLAN-REGRESSIONS-DEMO.md`
+ les verdicts profil du soir. Rien ne se code tant que ce plan n'a pas
le GO de Kathryn ; ensuite TOUT s'embarque dans l'ordre du bas, un
jalon = un film de vérification, build téléphone à chaque jalon validé.
Les enquêtes du workflow `diagnostic-regressions-demo` (en cours)
alimentent les jalons 2-3-4 — leurs conclusions s'ajoutent ici.

## 1. LES PARTICULES DU MANÈGE — demandées DIX FOIS, plus jamais oubliées

La référence : les petites particules qui accompagnent la vidéo du
booster dans l'overlay de la pop-up (grains 0,5-1,9 px, opacité ≤ 0,28,
additifs, très fins — le calibrage validé deux fois).

Trois moments, une matière :
- AU REPOS : un voile ambiant fin qui monte du sol miroir autour de
  l'anneau (lent, rare, presque rien — la nuit qui respire) ;
- À LA ROTATION (le manège qu'on tourne) : la poudre S'ANIME AVEC le
  mouvement — les grains traînent derrière la roue (l'école de la
  poudre qui penche du calendrier), densité liée à la vitesse du scrub ;
- AU CHANGEMENT DE BOOSTER (le cran qui claque) : une petite bouffée au
  tick, calée sur l'haptique de détente.

Technique : `SCNParticleSystem` DANS la scène (GPU — mesuré : la vidéo
ne coûte rien, le Canvas du fil principal coûte) ; grains émissifs
SEULS, jamais une lumière ajoutée (le cube noir des omni au sim) ;
extinction à l'engagement (l'éclatement radial les emporte) ; morts
avec le manège (teardown déjà la loi).

## 2. LA CINÉMATIQUE D'OUVERTURE (régression — mécanisme identifié)

Les films avant/après le prouvent : la cinématique (braise, la roue qui
se dévisse depuis −1,45 cran, feux en cascade, caméra 3,4→4,0) EXISTE
toujours — mais avant, le gel HDR retardait son départ APRÈS le fondu
d'entrée : elle se voyait en entier. Le gel est mort (pré-cuisson —
voulu), et la cinématique joue maintenant CACHÉE derrière le fondu au
noir : une coupe noire sèche, puis le manège déjà posé.

Correctif : SÉQUENCER l'entrée en plan-séquence — le panneau s'efface →
le noir se pose (jamais un flash de home nue) → le fondu court → et
SEULEMENT ALORS la mise en place démarre, visible du premier au dernier
cran. La renforcer au passage si besoin (départ caméra plus lointain,
cascade plus lente — le sublime se juge au téléphone).

## 3. LE SACHET PRÊT À DÉCHIRER : LA VIE + L'INVITE (demande répétée ×2)

- LA VIE : le sachet posé doit s'animer « de base » (respiration +
  danse lente — l'effet premium), sur le nœud-berceau (`swayNode`
  identité, jamais l'euler du pack à lacet π), UN SEUL écrivain par
  pose. L'enquête git dira où la loi « statue » de la sortie v3 a
  débordé sur l'avant-découpe.
- L'INVITE : dire « déchire-moi » par la lumière — le fil de braise qui
  balaye la ligne de découpe en boucle lente, la lèvre qui pulse ;
  jamais de texte.
- « Une fois le booster choisi, prêt à être déchiré, ça beug » : même
  zone — l'enquête liste les écrivains en conflit sur cette pose.

## 4. LE CARRÉ NOIR en haut du sachet (cérémonie, téléphone)

Suspects par ordre : la PERLE de découpe (billboard additif — texture
manquante/blend retombé = quad noir), la surcouche de charge lune,
l'émetteur-segment de poudre, la bande cap, un plan du `tearLight`
(`#if !simulator` — ACTIF téléphone : CE BUG NE PEUT PAS SE VOIR AU
SIM). Bissection par les interrupteurs `-boosterNo*` + captures
téléphone aux beats `-boosterTear`.

## 5. LA PAGE PROFIL — le booster tirable (verdicts du soir)

- a. **TRANSPARENT après la pose de la carte — « non ! »** Suspects :
  (1) le REMONTAGE du TabView à la fermeture du Sacre (le fix perf du
  19-08) reconstruit ProfilLune en plein vol — la transition
  `.move + .opacity` du géant interrompue = opacité fantôme ;
  (2) la sonde de scroll à mi-course après l'auto-scroll de l'accueil
  (`fondu = 1 − scrollY/90` → le géant à moitié effacé alors qu'on est
  « en haut » visuellement). Diagnostic : banc `-profilAccueil` filmé,
  sonde des valeurs scrollY/fondu à l'écran.
- b. **CONFLITS scroll / carte dépliée** : scroller la grande carte
  orange fait réapparaître le géant en beug sévère ; la poignée-lune
  (l'état enterré) beugue aussi. Diagnostic au banc ; remèdes visés :
  une seule vérité d'état (planque/enterre/ouvert), transitions
  idempotentes (le géant ne rejoue pas son entrée à chaque frame de
  scroll), la sonde unique (le piège de la sonde constante).
- c. **RELANCER LE MANÈGE (démo)** : le bouton OUVRIR est verrouillé
  par les pièces (`disabled` si pieces < 20 — ses vraies données sont
  dessous). EN DÉMO : le verrou SAUTE (le libellé du manque peut
  rester, le bouton ouvre toujours) ; et `boostersEnAttente` ne tombe
  plus à 0 définitivement (la pill revient — la démo doit boucler à
  l'infini : pop-up home OU pill OU tirage du géant → manège).

## 6. LA FEATURE — une carte de la collection s'OUVRE (état résultat)

Tap sur une carte posée dans la grille → l'état RÉSULTAT plein écran :
`CarteVivante` avec l'art de CETTE carte (tilt au doigt
droite/gauche, la caresse du foil, et l'appui long = LA PLONGÉE — « 
rejouer le film ») ; CHEVRON maison en haut à gauche → retour profil.
Transition : la carte MONTE depuis son slot (zoom depuis la vignette,
l'école de la carte dépliable/DescenteCarte à l'envers), et le retour
la repose au même slot. Les doublons ouvrent la même carte (la
pastille ×N ne change rien).

## 7. LA PASSE FLUIDITÉ (mesurée, jamais au feeling)

`SondeCadence` (`-fps` : cadence + pire trou) au téléphone sur quatre
beats : manège au repos, manège en rotation, sachet posé, découpe.
Avant/après chaque jalon ci-dessus. Leviers si besoin : MSAA 4X→2X,
`rendersContinuously` gelé hors interaction, poudre bornée, blends
isolés.

## L'ORDRE D'EMBARQUEMENT

1. **Jalon A** — la cinématique d'ouverture (2) + les particules du
   manège (1) : l'entrée du flow, le sublime d'abord.
2. **Jalon B** — la vie + l'invite du sachet (3).
3. **Jalon C** — le profil : transparence, conflits, verrou démo,
   la boucle infinie (5).
4. **Jalon D** — la carte de la collection qui s'ouvre (6).
5. **Jalon E** — le carré noir (4, au téléphone) + la passe fluidité
   (7).

Chaque jalon : film au banc → build téléphone → verdict Kathryn. Rien
n'est commité sans son GO final.
