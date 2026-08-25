# LE VARIANT 4 « SPOTLIGHT » — la lampe, et la matrice dans le chiffre

**Écrit le 25-08-2026, rien n'est codé.** Le plan fin du quatrième
variant de `RewardPopup`, sur les DEUX réfs de Kathryn :

1. **« 300 TPS »** — la lampe suspendue VISIBLE dont le cône tombe sur
   un chiffre de métal sombre, l'unité dans une petite pill de verre
   posée dessus.
2. **La matrice violette** (réf type sécurité Apple) — une trame de
   MICRO-MOTS pseudo-aléatoires, presque noirs, qui S'ÉCLAIRENT PAR
   VAGUES de blanc dégradé. Chez nous : **dans le chiffre uniquement**.

Son cadrage : « une UI compliquée avec des micro-détails énormes —
qu'on travaille très finement ». Donc : des jalons courts, une capture
validée à chaque pas, sim dédié **kat-popup** (les autres ignorés).

---

## 1. La scène (de bas en haut)

Le squelette commun des variants (scrim 0,68, dalle noire, verre, voile
noir AU-DESSUS — la grammaire BoosterPopup) avec le voile le plus
sombre de la famille (proche RARE : ~0,95 → 0,85, la nuit gagne).

1. **LA LAMPE SUSPENDUE** — un objet physique, pas un halo :
   - la TIGE : un trait de 2-2,5 pt, blanc ~0,10, qui descend du bord
     HAUT de la card et passe DERRIÈRE le bloc titre (sur le noir il se
     devine à peine — c'est voulu, la lampe est accrochée au plafond de
     la card) ;
   - le DÔME : une demi-ellipse ~92 × 60, matière sombre (dégradé blanc
     0,14 → 0,03), son arête basse soulignée d'un fil clair ;
   - la BOUCHE : une ellipse fine (~84 × 12) BLANCHE et chaude qui
     bloom doucement — c'est la seule source de la scène.
2. **LE CÔNE** — un trapèze de la bouche vers le chiffre (largeur ~60 →
   ~250), dégradé vertical blanc 0,26 → 0, FLANCS FONDUS par un masque
   horizontal (clair → opaque → clair : jamais d'arête franche — un
   trait à bord franc sur du noir est de l'ENCRE, pas de la lumière, la
   leçon des stries) ; une FLAQUE elliptique douce là où il touche le
   chiffre. Le cône OSCILLE d'1-2° au gyro, ancré à la bouche.
3. **LE CHIFFRE** — métal SOMBRE (il n'existe que là où la lumière le
   touche) : face en dégradé blanc ~0,30 en crête → 0,06 au pied, et
   DEDANS, la matrice (§2). Corps ~150-170 pt heavy, monospacé.
4. **LA PILL D'UNITÉ** — une petite capsule de VERRE (la recette maison
   `.regular.tint(noir)` + liseré) posée SUR le flanc droit du chiffre,
   à cheval sur son bord (le « TPS » de la réf), texte 13 semibold.
5. Header (titre + sous-titre à l'Apple) et « Close » : inchangés — le
   layout commun aux quatre variants.
6. Pas de poudre plein-champ ici : la scène est la lampe. (Option
   ultérieure : 2-3 poussières DANS le cône seulement.)

---

## 2. LA MATRICE DANS LE CHIFFRE — l'effet cœur

### Ce qu'on voit (la cible)

- Une TRAME de micro-mots type matrice — tokens pseudo-aléatoires
  (`Ka824HDs`, `5KX+FsJ`, séparés de `:..` comme la réf) — en rangées
  serrées (~8-9 pt, monospacé, tracking léger), remplissant le rectangle
  du chiffre, **visible UNIQUEMENT dans le glyphe** (masque texte).
- Au REPOS : les tokens presque noirs (blanc 0,05-0,09) sur le métal —
  une texture qu'on devine, pas qu'on lit.
- **LES VAGUES** : 2-3 fronts de lumière blanche dégradée qui BALAIENT
  la trame lentement (périodes premières entre elles, jamais de boucle
  perceptible). Un token s'allume quand un front le traverse — et le
  dégradé coupe **AU MILIEU des tokens, caractère par caractère** (la
  réf montre des mots à moitié allumés : c'est LE micro-détail qui fait
  vrai).
- **La vague maîtresse ÉMANE DU CÔNE** : le raccord des deux réfs — la
  lampe éclaire la matrice, le front le plus fort descend du point
  d'impact du cône. Les autres vagues sont des échos latéraux faibles.
- Des GLINTS : 3-4 tokens « élus » par passage, plus brillants que la
  vague (blanc 0,9), une frame de sur-brillance qui retombe — les
  paillettes de la trame.
- Les MUTATIONS (v2, optionnel) : très rarement (≤ 1-2/s sur TOUTE la
  trame), UN caractère d'UN token change — le tic Matrix, subliminal.

### L'interaction (gyro + drag, la demande)

- **GYRO** : l'axe des vagues suit l'inclinaison (la lumière « coule »
  du côté haut du téléphone), les glints répondent au tilt comme un
  foil. SkyMotion réutilisé (jamais un 6ᵉ CMMotionManager), lecture
  dans la FEUILLE de l'effet seulement (la page n'entend rien).
- **DRAG** : le doigt posé sur le chiffre devient UNE SOURCE de vague —
  un front circulaire suit le doigt sous la trame (la lampe qu'on
  promène), et au lâcher la source RESSORT vers le cône. ⚠️ La leçon
  payée deux fois aujourd'hui : le ressort vit sur un MODIFICATEUR
  animable (`.offset`), jamais sur une valeur modèle lue dans le calcul
  par frame (elle saute à sa cible sous `withAnimation`).
- Haptique : la prise du doigt = light 0,5 ; PAS de haptique par vague
  (trop bavard) — à juger au téléphone.

### La couleur — À TRANCHER PAR KATHRYN

La réf est VIOLETTE ; les goûts maison sont monochrome blanc (et
« refuse néon »), mais le violet EST l'accent de l'app. Proposition :
**blanc lunaire par défaut** (les vagues en blanc dégradé pur), et une
pointe violette optionnelle réservée à l'atmosphère RARE. À valider sur
capture, les deux côte à côte au banc.

### Le contenu des tokens — À TRANCHER (le micro-détail premium)

Deux écoles :

- **A. Aléatoire pur** (la réf) : hash déterministe, alphabet
  alphanumérique + `:..` — abstrait, crypto, froid.
- **B. LES VRAIES DONNÉES d'elle** : les tokens sont des bribes réelles
  de la séance — `24KG`, `12x3`, `AUG25`, `SETS`, `+20`, des dates,
  des charges passées. Illisible au repos, mais quand une vague passe
  on ATTRAPE un vrai fragment de son entraînement. C'est le genre de
  micro-détail « énorme » qui ne se remarque qu'à la deuxième fois.

Recommandation : B, avec un fond de A pour la densité (70 % aléatoire,
30 % de bribes réelles, positions stables par hash).

---

## 3. La techno — comment le rendre SANS tuer la cadence

**L'idée clé : la trame ne se redessine JAMAIS par frame.** Deux
couches de LA MÊME trame + des masques qui bougent :

```
[trame sombre]           statique, opacité 0,07      (rendue UNE fois)
[trame claire]           statique, blanc 0,85
   .mask( LE CHAMP DE VAGUES )                       (2-3 gradients animés)
les deux .mask( LE GLYPHE )                          (le chiffre, fixe)
```

- La trame = une grille de `Text` posée UNE fois (contenu par hash
  déterministe — jamais un random par frame). Elle déborde le glyphe →
  **le piège de la fente** s'applique : elle vit en
  `Color.clear.overlay` (hors layout), clip constant.
- Le CHAMP DE VAGUES = 2-3 `LinearGradient`/`EllipticalGradient` dont
  seuls les CENTRES/ANGLES bougent (TimelineView 30 Hz) — du pur GPU.
  L'allumage « caractère par caractère » est GRATUIT : le masque coupe
  la trame où il veut, y compris au milieu d'un token.
- Les GLINTS : un petit Canvas (≤ 12 étoiles, l'additif demandé au
  CONTEXTE — la loi PoudreBooster).
- Les MUTATIONS : un tick d'état LENT (~0,8 s) qui change UN token —
  re-rendu de la trame accepté à cette cadence-là, jamais à 30 Hz.
- Les masques ont des BOUNDS STABLES (taille constante, la loi du
  verre s'applique aux masques aussi) ; AUCUN `.blur` sur le texte fin
  (9 pt au 3× = net obligatoire, Nyquist tranquille) ; pas de
  `drawingGroup()` sans mesure (les 3 pièges de PAGE_DEMON).
- Budget : viser < 2 ms/frame au device. Mesure au banc par
  `SondeCadence` (`-fps`) — et se rappeler que le sim tourne à
  18-36 img/s : LE VERDICT DE CADENCE EST AU TÉLÉPHONE.

---

## 4. Le banc — kat-popup, boucles courtes

- `-spotLab` : la pop-up spotlight SEULE, ouverte direct, sans
  auto-fermeture ; REJOUER l'entrée ; `-spotTilt x,y` pour figer le
  gyro en capture (le pattern `-carnetTilt`).
- Variantes au banc : 1 chiffre / 2 chiffres / un MOT (« SETS ») — la
  trame doit vivre dans les trois.
- Fouettage standard : films, détecteur de flash (croisé aux pts),
  relecture adverse, aller-retours, non-régression des 3 autres robes.

## 5. Les jalons (un = une capture validée par Kathryn)

- **S1 — la trame morte** : contenu, typo, densité, opacité de repos,
  masquée dans le chiffre, sur la scène nue. (Le choix A/B des tokens
  et blanc/violet se tranchent ICI, sur images.)
- **S2 — les vagues** : le champ, les vitesses, l'allumage mi-token.
- **S3 — la lampe + le cône** : l'objet, la flaque, le raccord
  vague-maîtresse ← cône.
- **S4 — gyro + drag** : la source au doigt, le ressort, l'haptique.
- **S5 — glints + pill d'unité + finitions** (mutations si le budget
  cadence le permet).

## 6. Accessibilité & garde-fous

- reduceMotion : vagues FIGÉES sur un état joli (un front posé aux
  deux tiers), gyro coupé, drag conservé.
- VoiceOver : la trame et la lampe `accessibilityHidden`, la card reste
  `.isModal`, la valeur annoncée une fois posée.
- 2 chiffres et mots longs : la trame remplit le bounding du texte —
  aucune géométrie codée en dur sur « un digit ».

---

*Bibliothèque vidéo : `chauve_sourie_pièce_rewads_4.mp4` reçue le
25-08 (HEVC 4K paysage, 6,0 s, 9,3 Mo) — 4ᵉ variante de la famille
Reward pièce, mêmes règles de recuisson que les autres
([PLAN-REWARDS-BACKEND.md](PLAN-REWARDS-BACKEND.md) §6).*
