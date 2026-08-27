# LA PAGE « WIN » — le butin : la pièce du coffre, le compteur qui
# roule, et les boosters qui se plaquent

**Écrit le 26-08-2026 dans la nuit, sur le brief de Kathryn (la
référence : la pochette booster noire à liseré holographique) — RIEN
n'est codé.** Une QUATRIÈME page de base pour la story (cinquième
les jours TOP) : après l'analyse, LE BUTIN — ce que la séance a
rapporté, et ce que ça ouvre.

> Le brief : « une card après la troisième story, qui change de
> contenu en fonction de la séance — le titre aussi, et les
> stickers. Une grosse pills en bas de l'écran où on voit le côté
> or. Dans le header de la card, la vidéo de la pièce (fond
> transparent) du coffre v3 de ce matin, en petit — et derrière, en
> gros, pareil que la story 3 : "WIN". En dessous, même police, le
> nombre de pièces, ça s'anime "+100 pièces". Un booster = 100
> pièces : à chaque 100 pièces tu viens plaquer, UN À LA FOIS, les
> boosters — ils s'animent comme les stickers, en bas de card, ils
> peuvent dépasser de la card, un peu sur le côté, pas plaqués
> droits, et peuvent se chevaucher. Et la règle backend + front :
> la pop-up booster vue = pris en compte, et dans le profil on voit
> le nombre total de boosters qu'on peut ouvrir. »

---

## 1. CE QUI EXISTE DÉJÀ (sondé, pas supposé)

- **La pièce du coffre v3** : `Woop/Media/coffre-arrivee.mp4` —
  recuite CE MATIN par la session coffre (commit db15250 : l'image
  6 à 78, 3,04 s, la pièce or qui tourne et FINIT SUR LA TRANCHE,
  **bords à zéro absolu**). « Fond transparent » au sens de la
  maison : noir + contenu = contenu, `plusLighter` sur la card
  noire — aucun détourage à faire. L'école du header vidéo des
  rewards s'applique telle quelle : LECTURE UNIQUE, GEL sur la
  dernière frame (la tranche), tap = replay.
- **La pochette booster** : `~/Desktop/booster_1.png` — 1054×1492,
  fond noir, PAS d'alpha. À détourer par SILHOUETTE (l'école des
  pastilles) : le liseré holographique FERME le contour, donc
  seuil bas + `fill_holes` capture le corps noir ; la forme n'est
  pas un squircle (les crêtes crantées du haut/bas) — le tracé
  analytique ne s'applique PAS ici, la silhouette mesurée oui.
  Sonde de sortie : alpha moyen dans le sujet > 0,98.
- **Le côté or de la pills** : le bulbe AMBRÉ-OR existe déjà en
  définition native — `story-macro-flanc` (1500×1352, le bas de la
  gélule, l'or au cœur). Réutilisé ANCRÉ BAS (le bulbe qui monte
  du bord), zéro recuit. Si le cadrage ne rend pas « le côté or »
  assez franc sur capture → recuit dédié `story-macro-or` depuis
  `rouge_liquid` (zone du bulbe, y 2050..3300).
- **Le mot géant + la card noire** : l'école de la story 3
  (`StoryCard` — bigWord ×1,55, masques flancs + dissolution,
  fond graphite R36, taille rewards) se recopie.
- **La règle des pièces** : 20 pièces par série faite (LA LOI,
  `tools/rewards/`). Démo : 18 séries = 360 pièces = 3 boosters
  pleins + 60 de report.

---

## 2. LA SCÈNE, de bas en haut

1. **Le noir** de la story.
2. **LA PILLS CÔTÉ OR, EN BAS** : le bulbe doré qui monte du bord
   bas de l'écran (~0,95·L de large, ancré bas, additive) — l'or
   sous le butin, la seule dorure de la scène avec la pièce.
3. **LA CARD** (taille rewards, R36, fond graphite de la story 3,
   arête rasante) :
   - **le header** : la VIDÉO DE LA PIÈCE en petit (~96 pt),
     `plusLighter`, lecture unique → GEL sur la tranche ;
   - **derrière elle, « WIN »** — le mot géant école story 3
     (mêmes masques), **EN OR** — TRANCHÉ par Kathryn (« or, car
     argent c'est rare d'en avoir ! ») : la page du butin est
     DORÉE de bout en bout, pièce + pills + mot, c'est LE thème.
     Encre or riche (l'école FlammePalette : blanc chaud → or →
     braise, la saturation qui tient — jamais un jaune neuf) ;
   - **dessous, MÊME REGISTRE : le compteur** — « +360 pièces »
     qui ROULE de 0 (l'odomètre de la mini-card TOP, école C11),
     SF bold, blanc ;
   - **en bas : LES BOOSTERS PLAQUÉS** — voir §3 ;
   - **le titre-couronne** (petit, sous le compteur) : DYNAMIQUE
     par la séance — gabarits (« Nice haul. » / « Big win. » /
     « Jackpot. » par paliers de boosters), le contrat des textes
     du backend.
4. **Les segments** : 4 pages de base, 5 les jours TOP — le compte
   suit la table des rôles (déjà dynamique).

## 3. LA CHORÉGRAPHIE DU BUTIN (le cœur de la page)

Tout est fonction pure de `t`, un seul récit :

1. la card se pose (entrée douce, pas de slam — le slam appartient
   à la page TOP) ; la pièce JOUE (3 s), « WIN » fond derrière ;
2. **le compteur roule** 0 → N pièces sur ~2,2 s, sortie douce ;
3. **à CHAQUE franchissement de 100**, un BOOSTER SE PLAQUE — un à
   la fois, cadencé par le compteur lui-même (à 100, 200, 300…) :
   le slam de pose de l'école stickers (échelle 1,5 → 1, ombre qui
   s'écrase), un GRAIN RIGIDE par plaquage — trois boosters, trois
   grains, jamais une rafale continue ;
   - penchés (« pas plaqués droits ») : rotations −9° / +6° / −4°,
     décalés latéralement, ils SE CHEVAUCHENT comme les stickers
     de la story 3 et DÉPASSENT du bord bas/latéral de la card
     (⚠️ en OVERLAY de la scène, jamais dans le flux — le piège de
     la fente qui gonfle son hôte) ;
   - **la borne des 5** (la loi des flammes) : au-delà de 5
     boosters, le cinquième porte un « ×N » — on ne tapisse pas ;
   - lévitation glaciale ensuite (±2 pt, horloges premières).
4. le titre-couronne fond en dernier.

## 4. LA RÈGLE — backend ET front (écrite aussi au plan backend,
## §4 sexies)

**1 booster = 100 pièces, et RIEN ne se perd** :

- la conversion vit AU RÈGLEMENT (`settle_session`) sur un
  compteur CUMULÉ : `booster_progress` (0-99) + pièces de la
  séance → `n` boosters crédités + nouveau report. Une séance de
  60 pièces n'offre rien aujourd'hui mais 40 pièces demain
  suffisent — le joueur n'est jamais volé par l'arrondi ;
- le crédit est une ligne idempotente (clé `session_uuid`) — la
  story REJOUÉE ne recrédite jamais ;
- « la pop-up vue = pris en compte » : l'AFFICHAGE n'accorde rien
  (le crédit est déjà au ledger au settle) — il ENREGISTRE
  (`reward_events`, kind `booster_grant_shown`) pour ne jamais
  remontrer la même cérémonie ;
- **le front** : la page WIN montre les boosters DE LA SÉANCE ; le
  PROFIL montre le SOLDE TOTAL ouvrable (crédités − ouverts, le
  Sacre les ouvre — la garde `claim_booster` existe déjà) ;
- la story affiche des nombres RECOPIÉS (pièces réelles de la
  séance = séries × 20 aujourd'hui, le ledger demain).

## 5. LES JALONS

- **W1 — les assets** : détourage silhouette de `booster_1.png`
  (+ planche gris/nuit, sonde alpha) ; verdict A/B du côté or
  (macro-flanc ancré bas vs recuit dédié).
- **W2 — la card** : header pièce (lecture unique + gel) + « WIN »
  + compteur qui roule, au banc (la page 4 branchée derrière
  l'analyse, `-storyLab`).
- **W3 — la chorégraphie** : les boosters plaqués au rythme du
  compteur, chevauchement, débord, grains haptiques ; la borne
  des 5.
- **W4 — le dynamique** : titre-couronne par gabarits, N pièces
  réel de la séance, non-régression 3/4/5 pages (ordinaire, WIN,
  TOP+WIN).
- **W5 — fouettage** + verdicts téléphone. La règle backend
  s'implémente avec le chantier backend (pas ici).

## 7. LE TOUR 2 — LES VERDICTS DE LA MAQUETTE (26-08 nuit).
## **PAYÉ sur le « OK png qui flotte »** : la vidéo du header est
## MORTE (remplacée par `piece-or-mini` — pose, flottement, prise
## au doigt, placement libre clampé qui RESTE) ; WIN à 0,52·l et
## dissolution morte à 0,60 ; card recentrée 0,53·H (l'écart des
## hauteurs, mesuré 0,47) ; boosters DANS la card, animés (sway,
## souffle, lévitation) et saisissables ; LA POUDRE DU DOIGT
## (`PoudreDoigt` : les grains naissent DU déplacement, ~0,8 s de
## vie, une seule horloge, ménage au lâcher — jamais par image) ;
## le rect de la card remonté au chef (bouger un objet ne ferme
## pas la story). Fouettage sans flash. ⚠️ La SAISIE et la poudre
## ne se testent qu'AU DOIGT — verdict téléphone/sim manuel.
## Le plan du tour disait :

Kathryn a envoyé SA maquette de la page et cinq verdicts. Le
premier jet est corrigé point par point :

1. **LA VIDÉO DU HEADER MEURT** (« je veux pas de la pièce
   transparence » — c'était le « big beug »). À la place, LA PIÈCE
   DU PODIUM : **`piece-or-mini`** (132×132 RGBA, détourée ce matin
   par la session coffre — le verre à lune d'or, EXACTEMENT celle
   de la maquette). Elle vit comme un OBJET, pas comme un film :
   - elle S'ANIME à l'arrivée (la pose, école pièce du calendrier) ;
   - elle FLOTTE (lévitation glaciale, horloges premières) ;
   - elle SE SAISIT : on la déplace au doigt DANS la card.
   **Option v2 recommandée** : la planche `piece-or` (2880×2560 =
   8×8, SOIXANTE-QUATRE poses de rotation à vitesse constante,
   recuite ce matin — `tools/coffre-v2/recuit_pieces.py`) permet
   une pièce qui TOURNE sous le doigt (l'angle suit le drag,
   l'école MoonCoin) — v1 : le PNG mini qui flotte et se déplace.
2. **« PLUS DE FONDU »** : le mot WIN grossit (il mange toute la
   largeur sur la maquette) et sa dissolution descend plus bas
   (~0,55 — il IRRIGUE la moitié de la card).
3. **LA CARD À LA MÊME HAUTEUR que la story 3** : même gabarit ET
   même position (centre 0,53·H — le premier jet était à 0,47,
   c'est le « pas la même hauteur que la card précédente »).
4. **LES BOOSTERS, RÉVISÉS** (« PLUTÔT : dans la card, à
   l'INTÉRIEUR ») : le débord du premier brief MEURT — ils vivent
   DEDANS, ANIMÉS comme les stickers de la story 3 (sway,
   respiration, lévitation), et **SAISISSABLES** : on les bouge au
   doigt comme la pièce — et le déplacement SOULÈVE DE LA POUDRE
   DE DIAMANT (émission de grains au doigt, l'école de la gerbe du
   coffre : la poudre naît DU mouvement, elle ne préexiste pas).
5. **LES LOIS DU DOIGT** : la card WIN remonte son rect au chef
   d'orchestre (comme la story 3) — un drag né dedans ne ferme pas
   la story et ne change pas de page ; les prises des objets sont
   des gestes d'ENFANT (les Buttons affamés sous le chef, payé) ;
   le placement est LIBRE dans les bornes intérieures de la card
   (clamp), retombée douce au lâcher — ressort sur le MODIFICATEUR,
   jamais sur l'état animé.

## 8. LE TOUR 3 — LA RAFALE DE VERDICTS (26-08 nuit, PAYÉ)

Kathryn (« désolée je te balance plein de trucs ») — sept verdicts en
rafale, tous payés le soir même, NON commités :

- **les boosters plus bas et « qui bougent de manière plus jolie »** :
  posés À CHEVAL sur le bord bas (« on les voit de moitié dans la
  card ») et LIBRES jusqu'aux murs de l'écran (« on peut les sortir
  évidemment ») ; leur nage = le flottement de la pastille Welcome
  (trois horloges premières, dérive latérale, balancement lent
  ±2,4° à 0,43 Hz, souffle 0,018) — plus le tremblé ±3° ;
- **« pièce or mini bouge aussi »** : la même nage (flotte ±8,5,
  dérive ±4,5, balancement ±3° lent) ;
- **WIN « plus majestueux, plus chirurgien, micro-détails or, fondu
  dans le gris »** : GRAVÉ (ombre interne noir 0,40 à +1,5 pt), cinq
  NAPPES D'OR qui naissent dans les lettres (périodes premières —
  jamais un balayage) + six SCINTILLES apériodiques (enveloppe
  puissance 12), halo d'or doux qui respire derrière, traîne en
  quatre paliers morte à 0,86 (elle fond dans le graphite) ;
- **« un peu plus fond de carte »** : le mot recule (opacité 0,66 →
  0,46) ; **« plus dégradé gris → noir »** : le fond de la card en
  trois paliers (0,145 → 0,075 → 0,02) ;
- **« fondu aussi sur les côtés »** : les flancs mangent 26 % ;
- **LE FILAMENT** : un fin liseré halo rouge/blanc (capsule 1,8 pt,
  rouge → blanc → rouge, lueur rouge r 8 + blanche r 1,6, −6°) qui
  passe DERRIÈRE le mot, à sa propre lumière — il vivait d'abord
  DANS le bloc du mot et héritait de son opacité 0,46 : invisible.
  Sorti dans le fond de la card, avant le mot ;
- **« un gros bloc noir, la vidéo n'est pas fondue »** : les bords
  de COUPE du crop `story-macro-flanc` faisaient un rectangle. Un
  masque SwiftUI par image sur une couche vidéo coûte la cadence —
  le fondu est CUIT : `story-macro-or.mp4` = le même bulbe avec un
  scrim numpy (haut éteint jusqu'à 42 %, flancs 16 %), l'école
  recuit_calques. Aucun masque au rendu.

**LE LAG, MESURÉ** (« les animations lag sur la card ») — l'école
mpdecimate, images UNIQUES par seconde au sim, fenêtre WIN
localisée par la signature du bas d'écran : 58 avant le mot
majestueux ; 41 après (cinq blurs par-nappe + deux masques à
60 Hz) ; les remèdes : plus de blur par nappe (le dégradé radial
EST la douceur), la poudre du doigt montée SEULEMENT quand il y a
des grains, **l'horloge du mot QUANTIFIÉE à 20 Hz** (ses masques ne
se recomposent qu'une image sur trois), et la vidéo au fondu cuit
→ **63 img/s** (la page d'avant : 83 ; la verrière : 49, jamais
reprochée). ⚠️ Le type-checker a mordu deux fois (le mot, le
filament) — « tout est pré-typé », les scalaires hissés.

Reste ouvert : le verdict AU DOIGT (saisie, poudre), la cadence
TÉLÉPHONE à la SondeCadence, et si le lag persiste : `drawingGroup`
sur le bloc du mot (les trois pièges de drawingGroup à relire
avant).

## 6. À TRANCHER PAR KATHRYN

1. ~~« WIN » argent ou or~~ — **TRANCHÉ : OR** (« or, car argent
   c'est rare d'en avoir ! »).
2. **La borne** : 5 boosters plaqués max + « ×N », ça te va ?
3. **Le titre-couronne** : les gabarits par paliers (« Nice
   haul. » / « Big win. » / « Jackpot. ») — tes mots ?
4. **La conversion cumulée avec report** (recommandée — rien ne se
   perd) ou stricte par séance ?
5. **La pièce qui tourne** : v1 (le PNG qui flotte et se déplace)
   d'abord, ou directement la planche des 64 poses (rotation au
   doigt) ?
6. **Les objets déplacés** : ils RESTENT où on les pose (proposé)
   ou reviennent à leur place en ressort ?

## 9. Tour 4 — les trois verdicts de la capture (26-08, soir)

Verbatim : « le filament rouge qui bouge, s'anime aussi » / « les
boosters, j'ai dit *dans la card, qu'on peut bouger* » / « ça lag, la
pièce — l'animation, fais un truc plus premium, et d'elle sortent des
petites poudres de diamant ! »

1. **Le filament VIT.** Il ne respirait qu'en opacité (+3 pt de
   dérive) : invisible. Désormais son POINT DE LUMIÈRE blanc glisse
   le long du fil (`pic = 0,5 + 0,26·sin(0,47·t)` — le courant dans
   un néon, jamais un balayage sur le mot), le fil ondule sur deux
   horloges (±5 et ±2 pt) et bascule de −6° ± 2,6° à 0,29 rad/s.
   Toujours à 20 Hz quantifié, derrière WIN. Vérifié sur 5 instants
   à 1,25 img/s : le nœud est à droite, au centre, à gauche, revient.
2. **Les boosters DANS la card.** Le à-cheval du tour 3 meurt :
   `y = h/2 − 0,60·hb` (le bord bas à ~10 pt du bord de la card),
   toujours saisissables et libres jusqu'aux murs de l'écran (« on
   peut les sortir évidemment » — le doigt décide).
3. **La pièce premium.** Elle ne nage plus comme un sticker : elle
   PLANE sur une courbe de Lissajous (0,53 / 0,62 + 1,13 rad/s —
   jamais un aller-retour), inclinée ±2,2°, souffle d'échelle ±2 %,
   un halo d'or radial (r 78, 0,20 ± 0,06) qui respire dessous, et
   `PoudrePiece` : 26 grains-étoiles qui NAISSENT au bord de la
   pièce (r 44-52), s'écartent de 22 pt et montent de 16 sur une vie
   de 1,4-2,8 s, scintillement tranché (cube), blanc / or pâle,
   plusLighter, Canvas à 30 Hz dans le cadre de la pièce — donc la
   poussière la SUIT au doigt.

Mesure : cadence WIN mpdecimate 73 img/s uniques (tour 3 : 63) —
le Canvas à 30 Hz ne coûte rien de visible, le « lag de la pièce »
était surtout la nage saccadée d'un aller-retour à trois sinus.
Reste : le verdict au doigt (saisie, poudre du doigt, poudre de la
pièce qui suit) et SondeCadence téléphone.

## 10. Tour 5 — la poche, le holo, le retour, l'or métal (26-08, soir)

Verbatim, dans l'ordre : « les boosters sont dans la card et on les
voit de moitié, et ils bougent plus — là ils sont juste plaqués » /
« quand je bouge les boosters, leur bordure terne (là où c'est holo)
s'allume, et ils reviennent à leur place ensuite dans le footer de la
card » / « de base ils bougent davantage ; au drag vers le bas ils
reviennent à leur place » / « toujours un qui dépasse un peu plus que
les autres ; sous le "+" un sous-titre (enlève "pièces" à côté), baisse
un peu le texte, monte un peu les boosters et grossis-les » / « WIN
encore plus fondu, et plus travaillé dans l'or ».

1. **LA POCHE.** Les boosters ne sont plus des objets posés SUR la
   card : une couche `poche()` COUPÉE par la forme de la card
   (`clipShape(forme)`), le centre de chacun posé près du bord bas —
   la moitié basse vit sous la coupe, comme des cartes dans une
   poche. Ils MONTENT de la poche à leur franchissement de 100
   (`sortie = (1 − outLong(pose,3)) · 0,62·hb`, plus un souffle
   d'échelle 6 %) au lieu de tomber du ciel. Bornes : de la moitié
   (jamais plus bas) jusqu'au haut de la card, ±(l/2 − 0,45·wb).
   130 pt (était 116), repos à `h/2 − 0,12·hb` ; LE HÉROS (celui du
   milieu, ou le premier s'il est seul) repose à `−0,28·hb` : il
   dépasse toujours plus.
2. **LA NAGE ×3.** ±18 pt de houle (deux horloges 0,62 / 1,13), ±6 de
   dérive, ±4,5° de balancement — la part visible respire
   franchement (tour 4 : ±5, « plaqués »).
3. **LE HOLO S'ALLUME.** `sticker-booster-holo` = la frise irisée du
   sticker extraite par SATURATION (`detoure_booster_holo.py` : S>0,22
   & V>0,30, composantes >400 px, puis un COULOIR de 14 px autour de
   la frise colorée qui reprend ses segments gris — mesuré : haut-
   droite et bas-droite manquaient — fermeture 5×5, dilatation 2,
   flou 1 ; couverture 4,2 %). En Swift : deux couches du masque
   (trait net + lueur flou 3) colorées d'un `AngularGradient` irisé
   cyan → magenta → or → vert dont la TEINTE TOURNE AVEC LE DOIGT
   (`1,1·dx + 0,7·dy + 24·t`, horloge 20 Hz) — un vrai holo qu'on
   incline —, plusLighter, allumé par `tenus` (`.animation` scopée
   0,28 s). Banc `-winHolo` : le booster 1 tenu allumé pour filmer.
4. **LE RETOUR.** `objet(revient: true)` : au lâcher, ressort
   (`response 0,62 / damping 0,58`) vers la poche — la place n'est
   jamais gardée (Q6 tranchée : RETOUR, pour les boosters ; la pièce
   reste où on la pose). Haptique `.impact(light, 0,6)` à chaque
   saisie (`saisies`).
5. **LE TEXTE.** « +360 » seul (SF 44 bold), sous-titre « pièces
   gagnées » SF 15 gris 0,55, couronne SF 13 or pâle 0,72 sous 6 pt ;
   bloc descendu à 0,07·h.
6. **L'OR MÉTAL.** L'encre du mot passe à SIX paliers (champagne, or,
   une BANDE DE REFLET étroite à 0,40 ± 0,05 qui DÉRIVE à 0,31 rad/s,
   ambre, bronze au pied) sous un BISEAU champagne (offset −1,3) qui
   affleure au bord haut des lettres, gravure creusée à 0,45 / 1,8 ;
   7 nappes (était 5), 9 scintilles (était 6) ; « encore plus
   fondu » : traîne à cinq paliers morte à 0,80 (était 0,86), flancs
   30 %, opacité 0,42 (était 0,46).

Vérifié au film (kat-story, `-storyLab -storyAuto -winHolo`) — la
page WIN se localise à la PLANCHE-CONTACT (0,5 img/s) : `-storyAuto`
BOUCLE la story, la fenêtre de WIN dépend du démarrage (22-32 s sur
ce film, 31-37 avant — la mesure du tour 4 à « 50 img/s » sur 31-37
était donc prise sur la VERRIÈRE, pas sur WIN). Cadence mpdecimate
sur la vraie fenêtre : **80 img/s uniques** au repos, 76 avec le holo
allumé au banc (tour 4 : 73, tour 3 : 63). Reste AU DOIGT : la prise, le holo qui tourne, le retour à
ressort.
