# PROMPT DE REPRISE — LA DUOLINGUO_PAGE (à coller dans la nouvelle session)

Copie tout ce qui suit dans la nouvelle session :

---

Tu reprends le chantier de la DUOLINGUO_PAGE (« LE CHEMIN DE FEU ») de
Woop. Lis D'ABORD, en entier : `tools/duolingo/PLAN-DUOLINGUO.md` (toute
l'histoire, §1 à §13, avec les verdicts et les pièges payés) et la mémoire
`woop-duolinguo-page`. Ce prompt te donne ce que le plan ne dit pas
encore : pourquoi la dernière salve a ÉCHOUÉ, et comment travailler.

## L'état exact

- Commits (tous sur main) : `89ddc1c` (J0+J1 colonne), `7410abb` (J2+J3
  galets+dalle), `3988733` (J4), `b06f1b3` (transitions), `9a08031`
  (travelling), `fa404ea` (feu unique). Banc : `-duoLab` (+ `-duoEcran
  <1-5>`, `-duoEtape <n>`, `-duoFreeze`, `-duoAuto`, `-duoGalets`,
  `-duoFocus <pt>`). Sim dédié `kat-duo` (iPhone 17 Pro), DerivedData
  `dd-duo/`, build en `generic/platform=iOS Simulator` puis simctl
  install. D'autres sessions travaillent le même repo : committer PAR
  CHEMINS, ne stager que tes fichiers.
- Les outils qui marchent et qu'il faut GARDER : `tools/duolingo/
  recuit_duo.sh` (cuisson, invariant du zéro respecté : tous les bords de
  fichiers meurent à 0 mesuré), `tools/duolingo/sonde_ligne.py` (la sonde
  de calques, calibrée sur les captures de Kathryn dans `shots/
  verdict-calques-*.png` — seuil 7, ses captures scorent 10,5/14,0),
  le détecteur de flash en V, les maquettes mesurées dans `shots/`.

## ⚠️ LA RÉGRESSION À RÉPARER EN PREMIER (avant toute autre chose)

> « et il n'y a plus le fondu des pills, t'as régressé de fou […] c'est
> horrible »

En tuant TOUS les rideaux runtime (§13, l'invariant du zéro), la session
précédente a aussi tué **le fondu profond des capsules en voyage**. Le
chiffre : les bouts cuits font 200 px = **67 pt** de fondu à l'écran ;
avant, le rideau runtime couvrait **~300 pt** pendant le scroll. Résultat :
en voyage, la capsule montre ses bouts presque nets — la régression
qu'elle voit. Répare D'ABORD ça, en un tour court, et fais-le valider
avant toute autre chose. Pistes (à trancher avec elle) : recuire les
capsules avec des fondus BEAUCOUP plus profonds (500-700 px, l'émergence
sur un tiers de la capsule — le zéro reste cuit, pas de runtime) ; OU
rendre le rideau runtime aux SEULES capsules (ses calques condamnés
étaient ceux des flammes — sur le verre sombre, un rideau profond ne
s'était jamais fait flagger) ; OU les deux. Le portillon : le fondu en
voyage doit se voir À L'ŒIL sur un film lent, pas seulement à la sonde.

## Le verdict de Kathryn qui motive ta reprise (24-08, verbatim)

> « ok ça marche toujours pas […] ça va pas, scroll trop cheap, regarde
> les flammes c'est la même histoire, tu changes rien, tu vas trop vite,
> c'est cheap et archi nul »

C'est le TROISIÈME verdict négatif sur les transitions de flammes. Les
deux d'avant : « des genres de calques, pas naturel, on ne doit pas
savoir que c'est deux composants » ; « pas fondu dans le noir, trop
haut, trop fort ».

## Le diagnostic honnête (ce que la session précédente a compris trop tard)

1. **Le problème de COUTURE est résolu, le problème de BEAUTÉ ne l'est
   pas.** La sonde de ligne mesure 2,8 en transition (contre 14 sur ses
   captures) : il n'y a plus d'arête, c'est prouvé. Mais le résultat est
   un GRAND BROUILLARD GRIS qui voyage — sans couture, et cheap quand
   même. Ne re-livre pas une n-ième mécanique anti-couture : ce combat
   est gagné, ce n'est pas le sujet.
2. **Le feu unique est trop GROS et trop MOU.** Le fichier feu
   (804×1080 = 540 pt de fenêtre) domine l'écran pendant la transition ;
   affaibli (gain 0,62) puis flouté par le rack focus (10 pt en voyage),
   il devient une brume laiteuse pleine page. La capture de Kathryn le
   montre : 60 % de l'écran est un nuage gris. Sa loi (mémoire
   woop-design-gouts, PLAN-HOME-V2 LOI 2) : **le noir est la matière, la
   lumière est RARE**. Une transition doit montrer MOINS, pas plus.
3. **Le rack focus sur des flammes déjà diffuses = de la bouillie.** Le
   blur en voyage était pensé pour du verre net ; sur un gradient mou il
   ne raconte rien, il salit. Piste : le flou ne devrait exister que sur
   le VERRE (les capsules, peut-être le galet noir) — ou mourir tout
   court. `-duoFocus 0` le coupe : COMMENCE par juger la page avec le
   flou mort.
4. **« Tu vas trop vite » — dit TROIS fois.** La méthode a échoué autant
   que la matière : des salves entières livrées d'un bloc, jugées sur
   des métriques, jamais un réglage validé par Kathryn avant le suivant.

## La méthode imposée pour ta reprise

- **La boucle courte de la maison** (mémoire
  woop-methode-visuelle-boucle-courte) : UN changement à la fois, build,
  capture/film, montre, verdict de Kathryn, puis seulement le suivant.
  Pas de salve. Pas de « je livre tout et on verra ».
- Commence par un TOUR D'ÉCOUTE à coût nul : monte-lui 3 réglages A/B au
  banc (flou mort / flammes plus petites / transitions plus sombres) et
  fais-la trancher AVANT de cuire quoi que ce soit.
- Les sondes existantes restent tes portillons de NON-RÉGRESSION (ligne
  < 7, zéro flash, bords à 0) — mais le juge de la beauté, c'est elle,
  jamais une sonde.

## Les pistes qu'elle n'a pas encore vues (à proposer, pas à imposer)

- **Réduire radicalement les feux** : un cœur de ~240-300 pt total sur la
  couture (pas 540), VIF et dessiné (gain remonté, pas de flou runtime),
  beaucoup de noir autour. La transition = du noir qui respire avec un
  cœur de feu précis qui passe — pas un nuage.
- **La transition sombre** : au lieu d'ajouter de la matière au voyage,
  en retirer — le feu s'incline (baisse brève de luminance au passage de
  la couture), le noir domine à mi-course, et la lumière se rallume à la
  pose. C'est l'inverse de ce qui a été fait jusqu'ici.
- **Peut-être** : plus de vidéo de flamme du tout aux coutures 1/2 et
  3/4 — un simple souffle de lumière shader très bas (école bgAurora),
  ou RIEN (le noir assumé entre les écrans, les capsules restant les
  deux seuls événements de verre). Oser la soustraction.
- Les capsules (2/3 et 4/5) sont le point FORT validé (« c'est top que
  tu as fait le même élément de capsule ») — n'y touche que pour les
  affiner, jamais pour les charger.

## Les pièges déjà payés (NE PAS LES REPAYER — la liste complète est au plan §8/§9bis/ter/§12/§13)

Les majeurs : parallaxe sur minY−restY jamais minY nu ; galets cuits en
UNE passe crf 17 ; `${flt}[v]` en zsh ; CalqueVideoPilote pour naître en
pause ; VStack NON-lazy ; JAMAIS `-loop 1` sur une image de filtre
(entrée infinie, 115 Mo sans moov) ; un voile par ZONES pose une marche à
la couture ; un rideau runtime EST un calque ; la sonde de coupe qui
moyenne les rangées absout les calques (d'où sonde_ligne.py) ; xcodebuild
jamais pipé vers grep/tail ; simctl launch avec
--terminate-running-process.

Bon courage — et va LENTEMENT.
