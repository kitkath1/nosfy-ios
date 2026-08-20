# PLAN — la suite du chantier booster (19-08, après la démo)

Verdicts de Kathryn sur la démo : (1) **régression** — « avant le paquet
s'animait de base avant la déchirure (l'effet premium) et c'était plus
fluide » ; (2) **les particules du manège** — la poudre qui accompagne la
vidéo du booster dans l'overlay n'existe pas au carrousel ; (3) le bouton
démo de la home (flow aléatoire) **reste**.

## A. La vie du sachet avant la déchirure (la régression)

Deux sujets distincts sous le même verdict :

### A1. L'animation manquante (l'effet premium)
- **Diagnostic d'abord, jamais à l'intuition** : filmer le beat
  pré-déchirure au banc `-boosterLab` à HEAD, puis aux commits d'avant
  (`c31065d` cérémonie sensorielle, `e6c0857` sortie v5) — même banc,
  même cadrage ; mesurer l'amplitude du mouvement (sonde numpy sur les
  bords du sachet, delta inter-frames). Bissection git sur le beat si le
  coupable ne saute pas aux yeux.
- Suspects, dans l'ordre : la loi « sachet = STATUE » de la sortie v3
  appliquée trop tôt (elle ne devait régner qu'APRÈS la libération de la
  carte, pas avant la découpe) ; `bob`/`sway` retirés et jamais réarmés
  sur le chemin galerie → engagement ; `beginIdleBreath` appauvri.
- Correctif visé : respiration + danse lente sur le NŒUD-BERCEAU
  (`swayNode`, identité — jamais l'euler du pack au lacet π, le piège
  payé) ; UN SEUL ÉCRIVAIN par pose (la leçon du 19-08 : le gyro
  n'écrase plus rien) ; la lueur de la lèvre qui respire avec.

### A2. La fluidité
- Déjà posé dans la démo du 19-08 : home DÉMONTÉE sous le manège
  (contention CPU/GPU), studio HDR pré-cuit au lancement (le hitch de
  plusieurs secondes à la première ouverture), séquencement pop-up →
  manège (plus de warm-up SceneKit sous la sortie du panneau).
- Mesurer AU TÉLÉPHONE à la `SondeCadence` (`-fps` : cadence + pire
  trou de la seconde) avant/après. Si insuffisant : MSAA 4X→2X au
  manège, `rendersContinuously` gelé hors interaction.

## B. Les particules du manège (la poudre de l'overlay, en scène)

- La référence de matière : les grains de la pop-up et du courant
  ascendant — 0,5-1,9 px, opacité ≤ 0,28, additifs, TRÈS fins (le
  calibrage validé deux fois).
- **Voie recommandée : `SCNParticleSystem` DANS la scène** (GPU — les
  mesures du panneau l'ont prouvé : la vidéo ne coûte rien, le Canvas
  du fil principal coûte) : un émetteur en anneau autour des sachets +
  un voile qui monte du sol miroir ; blend additif, vie 4-8 s, taille
  ~0,004, vitesse lente vers le haut ; les grains s'éteignent à
  l'engagement (l'éclatement radial les emporte) et meurent avec le
  manège (le teardown du CADisplayLink est déjà la loi).
- Variante si le grain SceneKit fait cheap : couche Canvas SwiftUI
  au-dessus de la SCNView — mais horloge en PAUSE au repos (l'école du
  bac des mois) et bande bornée au cadre (le piège de l'enfant plus
  large que l'écran).
- Danger connu : JAMAIS une lumière ajoutée pour les éclairer (le cube
  noir des omni au simulateur) — des grains émissifs seuls.

## C. Ce que la démo du 19-08 porte déjà (à juger à la main)

- Bouton démo home → pop-up → manège → **tirage ALÉATOIRE serveur**
  (pool ~1 s / neuve 60-90 s) lancé à l'engagement → la vraie carte dans
  la cérémonie si la forge répond avant le dévoilement (sinon
  carte-lune-1, l'art se pose à l'arrivée) → envol → profil, carte posée
  avec son vrai art.
- Les fixes gestes/glitch : pan + long-press enfin simultanés (la
  déchirure peut naître d'un doigt qui a chargé), triplets euler partout
  en galerie + bande morte gyro (plus de culbute au poignet), resets de
  la pichenette (plus de yaws parasites), engagement toujours RECTO
  (demi-tour pendant le dolly si engagé dos — la découpe s'arme
  toujours).
- Limites assumées v1 : collection EN MÉMOIRE (perdue au redémarrage —
  `user_cards` se branchera AVEC Kathryn) ; si une carte NEUVE arrive
  après le dévoilement, l'art (et la rareté affichée) se posent en
  retard sur la carte déjà montrée ; auth = session du compte si elle
  existe, sinon le user de test du banc (dev).
