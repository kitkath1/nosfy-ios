# PLAN 2 — les régressions de la démo du 19-08 (verdicts téléphone)

Trois verdicts de Kathryn sur la version démo installée à 16:10, à
traiter AVANT tout nouveau chantier. Le jumeau de ce plan (l'animation
pré-déchirure + les particules du manège) : `PLAN-SUITE-DEMO.md`.
L'ORDRE D'EMBARQUEMENT est en bas — tout s'implémente à la suite, un
jalon = un film de vérification.

## R1. LA CINÉMATIQUE D'OUVERTURE EST MORTE (régression majeure)

« Avant j'avais une animation spectaculaire cinématique zoom sublime
avant d'afficher le manège quand je clique sur Ouvrir un booster — là
non ! »

- La référence : la MISE EN PLACE du manège (~1,45 s — la braise
  d'abord, la roue qui se dévisse en décélération cubique depuis
  −1,45 cran, les feux en cascade fond→central, caméra 3,4→4,0, verrou
  haptique). Elle existe dans le code (`-boosterStill` la saute).
- Diagnostic : comparer IMAGE PAR IMAGE l'entrée du manège dans les
  deux films déjà en boîte (baseline commitée `repro-manege.mp4` vs
  démo `verif-manege.mp4`, même banc `-boosterManege`) — la roue se
  dévisse-t-elle encore ? Puis relire le diff des fixes sur ce chemin.
- Suspects, dans l'ordre :
  1. le DÉMONTAGE du TabView posé dans la même transaction que le
     montage du manège : la home s'éteint d'un coup — le zoom joue
     peut-être encore mais se LIT comme une coupe noire brutale (la
     cinématique a besoin d'une scène qui s'allume, pas d'un trou) ;
  2. le séquencement 0,32 s (panneau d'abord) : un temps mort perçu
     entre le tap et la lumière ;
  3. une identité SwiftUI perturbée (le manège re-monté/re-attaché, la
     cinématique coupée en route).
- Correctif visé : l'entrée = UN PLAN-SÉQUENCE. Le panneau s'efface →
  le noir se pose (jamais un flash de home nue) → LA ROUE SE DÉVISSE EN
  ZOOM, braise d'abord, cascade des feux. Si la cinématique joue mais
  se lit mal : la renforcer (départ caméra plus lointain, cascade plus
  lente, le noir qui s'allume PAR la scène). Si elle est morte : la
  ressusciter et la protéger d'un test au banc.

## R2. LE PETIT CARRÉ NOIR en haut du sachet (cérémonie)

« Un petit carré noir sur le booster dans le haut quand je veux ouvrir
le booster. »

- Diagnostic : captures aux mêmes beats sim + téléphone
  (`-boosterTear 0,15 / 0,45 / 0,8`), puis bissection par les
  interrupteurs existants `-boosterNoDust/NoSmoke/NoFront/NoTearLight`
  et en cachant un à un les nœuds candidats.
- Suspects : la PERLE de découpe (billboard additif — une texture qui
  manque ou un blend qui retombe rend un QUAD NOIR, surtout au
  téléphone hors HDR sim) ; la surcouche gaussienne de la charge lune ;
  l'émetteur-segment de poudre ; la bande du haut (cap) rendue avec un
  matériau éteint ; un plan du `tearLight` (actif téléphone seulement —
  le `#if !simulator` fait que le SIM NE PEUT PAS montrer ce bug).
- Loi de vérification : ce carré se juge AU TÉLÉPHONE (le suspect
  principal n'existe pas au simulateur).

## R3. ON NE COMPREND PAS QU'ON PEUT DÉCHIRER (l'affordance) + LA VIE

« C'est pas fluide, on ne comprend pas qu'on peut ouvrir/déchirer le
booster — avant il y avait une animation, je te l'ai déjà demandé. »

- C'est la demande RÉPÉTÉE (2e fois — priorité haute) : le sachet posé
  doit VIVRE avant la découpe (l'effet premium) et INVITER au geste.
- Deux volets :
  1. LA VIE : respiration + danse lente du sachet posé, sur le
     nœud-berceau (`swayNode` identité — jamais l'euler du pack à
     lacet π), un seul écrivain par pose (la leçon du 19-08). Diagnostic
     par films comparés HEAD vs `c31065d`/`e6c0857` (la loi « statue »
     de la sortie v3 a probablement débordé sur l'avant-découpe).
  2. L'INVITE : dire « déchire-moi » par la lumière — le fil de braise
     qui BALAYE la ligne de découpe en boucle lente (l'inviteSweep
     renforcé), la lèvre qui pulse, et/ou le chevron de poussière école
     CarteVivante posé sur la bande. Jamais de texte.
- La fluidité d'ensemble : SondeCadence (`-fps`) au téléphone sur trois
  beats (manège au repos, sachet posé, découpe en cours), lire le PIRE
  TROU de la seconde ; leviers si besoin : MSAA 4X→2X,
  `rendersContinuously` gelé hors interaction, poudre bornée.

## L'ORDRE D'EMBARQUEMENT (tout à la suite, après ces deux plans)

1. R1 la cinématique d'ouverture (le sublime d'abord — c'est l'entrée
   du flow) ;
2. R3 la vie + l'invite du sachet (la demande répétée) ;
3. R2 le carré noir (au téléphone) ;
4. Les particules du manège (`PLAN-SUITE-DEMO.md` §B) ;
5. La passe fluidité mesurée (sonde avant/après, téléphone).

Chaque jalon : film au banc, puis build téléphone. Rien n'est commité
tant que Kathryn n'a pas validé à la main.
