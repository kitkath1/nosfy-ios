# TOP SESSION — la robe d'EXCEPTION : la paillette du sport, le halo
# rouge-blanc de la page, et la mini-card néon qui dépasse

> **PAYÉ le 26-08 au soir (TS1 → TS6 en deux tours), NON commité.**
> Ce qui a bougé par rapport au plan :
> - **TS1** : le détourage par silhouette-luminance MORDAIT le flanc
>   gauche (la matière du bord passe sous 8/255 — l'ÉCLAIRAGE n'est
>   pas la FORME). La silhouette étant CONNUE, elle est tracée
>   ANALYTIQUEMENT : bbox au seuil 3 + squircle de rayon 0,22 · côté
>   (celui du rendu), fondu 1,5 px au contour. Alpha sujet = 1,000
>   sur les deux (`detoure_pastilles_top.py`).
> - **TS2-TS4** : la page vit dans `StoryTopScene` (StorySuite) ; la
>   verrière plonge dedans (mode `.top` de StoryEnded), le résumé
>   émigre en page à lui (mode `.resume`, horloge REBASÉE, pills
>   posée, haptiques tues) — **4 pages** les jours d'exception, la
>   pagination du chef est passée en table de rôles. Pills énorme
>   recuite plein format (`story-pilule-top`, 2648×1664 natif).
> - **⚠️ LE BUG DE LA PASTILLE (verdict Kathryn)** : elle naissait
>   PENDANT l'atterrissage — deux échelles se battaient (la plongée
>   1,6 → 1 et son 0,86 → 1) et sa dérive partait du MILIEU d'une
>   sinusoïde. Elle naît après le slam, flottement GATÉ par la
>   naissance, ombre vraie dessous.
> - **Le tour premium** (« plein de micro-détails, un titre et
>   sous-titre comme les autres cards ») : kicker « BEST OF THE
>   WEEK » tracké + « Top Cardio / Top Lifting » + sous-titre gris ;
>   poudre de diamant dans la card ; glint rare sur le mot (5 s) ;
>   fil rouge sous l'arête ; flash de l'arête blanche à l'impact ;
>   pop + tick haptique de la mini-card.
> - Bancs : `-storyTop` (cardio) / `-storyTopMuscu`. Fouettage :
>   1517 frames, AUCUN flash. Vérifié : les 4 pages s'enchaînent
>   TOP → Résumé → Détails → Analyse ; muscu affiche le volume RÉEL
>   (3260 kg des lignes de démo). Restent : verdicts téléphone
>   (halo/cadence du 2648, SondeCadence), le POP-REWARD (§5, avec le
>   backend), les mots définitifs (§7).

**Écrit le 26-08-2026 au soir, sur le brief de Kathryn (deux
captures : la Welcome v2 « YOU'RE BACK » comme layout de départ, et
la mini-card « Conversion rate 3.0x » au néon vert comme référence
du wahou) — RIEN n'est codé.** C'est un NOUVEAU variant de la
famille rewards, ET la PREMIÈRE page de la story dans les cas
d'exception.

> Le brief, mot à mot : « on reprend le même layout que la card
> rewards version 2 avec la pastille — deux variants : top session
> CARDIO → paillete_basket, top session MUSCULATION →
> pailette_haltère — on enlève la chauve-souris — le texte à
> travailler, animé, couleurs plus rouges — cette card est la
> première vue de la story — une pills en gros derrière qui part du
> côté droit, énorme — tout le contour de la page un halo rouge,
> blanc pur, montrer que c'est important, très premium — la card
> arrive de façon fantastique après la scène d'entrée — une
> mini-card néon vert très puissant qui dépasse de la card, wahou. »

---

## 1. CE DONT ON HÉRITE (mesuré, pas supposé)

**Le layout de départ** : la robe Welcome v2 TEXTE —
`RewardPopup(style: .welcome, robe: .texte)` dans
`RewardCard.swift` : le `TexteGeant` en argent DERRIÈRE (deux
lignes), la **pastille** au centre (`PastilleLuneReward`, le PNG
détouré `sticker-pastille-lune`), la pill « Claim +N » et le
« Later ». **La chauve-souris MEURT** (dit deux fois) : ni le
sticker `chauve-tient` du haut, ni la vidéo.

**Les assets, sondés le 26-08 (sur le Bureau)** :
| fichier | dimensions | fond |
| --- | --- | --- |
| `~/Desktop/paillete_basket.png` | 1254×1254 | noir, PAS d'alpha |
| `~/Desktop/pailette_haltère.png` | 1403×1121 | noir, PAS d'alpha |

C'est EXACTEMENT le cas de `pailette_lune` (1254×1254, fond noir) :
**le pipeline de détourage de la pastille existe déjà** —
[PLAN-WELCOME-V2-DETOURAGE.md](PLAN-WELCOME-V2-DETOURAGE.md) — et
il rend un imageset propre (`sticker-pastille-lune`, 863×846). On
le rejoue tel quel pour produire `sticker-pastille-basket` et
`sticker-pastille-haltere`. ⚠️ L'haltère n'est PAS carrée
(1403×1121) : la pastille est un squircle — le cadrage du glyphe
dans la pastille se juge sur capture, pas au ratio.

**La pills énorme** : `story-pilule-droite.mp4` existe (le miroir
home, le corps qui sort à droite) — mais « énorme, qui part du côté
droit » à l'échelle de la page peut demander un cadrage plus gros :
le master `~/Downloads/pills_2.mp4` (2160×3836) est là, l'école des
recuits story est écrite (`../story/recuit_story_ended.sh`).

---

## 2. LA SCÈNE, de bas en haut (la page story d'exception)

1. **Le noir** de la story.
2. **LA PILLS ÉNORME**, qui entre par le CÔTÉ DROIT — plus grosse
   que celle du résumé (~1,1–1,3 × la largeur d'écran, cadrée sur
   le corps du verre), additive sur le noir, le mouvement CUIT
   (l'école CalqueVideo). Elle est DERRIÈRE la card.
3. **LE HALO DE LA PAGE** — tout le CONTOUR de l'écran s'embrase :
   un liseré intérieur ROUGE qui monte vers le BLANC PUR aux
   arêtes (« montrer que c'est important »). La grammaire : un
   `RoundedRectangle` au rayon de l'écran (52), stroke épais très
   flouté vers l'intérieur + un stroke fin blanc pur presque sec —
   deux couches, jamais un contour fermé d'épaisseur égale et
   MESURÉ à la sonde de luminance (⚠️ la leçon du halo à +2,2 est
   payée : des valeurs hautes exprès, mais vérifiées sur pixels).
   Il RESPIRE lentement (fonction pure de `t`), et il n'existe QUE
   sur cette page — c'est le signe de l'exception.
   ⚠️ Anti-brun : le rouge tient sa saturation (R = 1,00, on
   désature le VERT), calé sur `Feu.lit`, jamais un rouge neuf.
4. **LA CARD** — le layout Welcome v2, re-costumé :
   - **le texte géant derrière** passe de l'argent au registre
     ROUGE (encre en dégradé chaud, école harmonisation-rouge),
     ANIMÉ — le souffle lent + un glint rare, jamais une agitation ;
   - **la pastille** au centre : squircle anthracite identique,
     glyphe = LA PAILLETTE DU SPORT — `basket` (top cardio) ou
     `haltère` (top muscu) ;
   - **pas de chauve-souris** ;
   - en STORY : PAS de « Claim / Later » (rien à réclamer — c'est
     une page qui se lit ; le tap = la grammaire du chef
     d'orchestre). En POP-REWARD (§5) : les boutons restent.
5. **LA MINI-CARD NÉON** — le wahou : une petite card (gabarit de
   la réf « Conversion rate 3.0x ») qui DÉPASSE du bord de la
   grande card (ancrée sur son arête, ~55 % dedans / 45 % dehors,
   légèrement tournée), avec **un chiffre au néon VERT très
   puissant** : la stat qui justifie l'exception (« Best week »,
   « +18 % », « 12,4 km »…). Le nombre est RECOPIÉ d'un fait,
   jamais inventé. Le néon : encre verte + bloom (blur serré +
   plusLighter) — c'est le SEUL vert de la scène, et c'est voulu :
   il crie sur le rouge.
   ⚠️ Elle dépasse d'un hôte : l'école « la fente gonfle son
   hôte » — elle vit en OVERLAY de la card, jamais dans son flux.
6. **Les segments** `StoryProgress`, inchangés.

## 3. L'ARRIVÉE FANTASTIQUE (après la scène d'entrée)

La card n'apparaît pas : elle ATTERRIT. Après la coupe de la
verrière (la scène d'entrée de la story reste identique) :

- la pills énorme est déjà là (elle décode depuis le plongeon,
  loi du flash noir) ;
- la card PLONGE depuis l'avant (échelle ~1,6 → 1,0, flou de
  naissance qui se résout, courbe à traîne longue) et SLAM —
  l'haptique la plus lourde (`SwapFeedback.slam()`), l'école de
  l'arrivée royale ;
- le halo de page S'ALLUME sur l'impact (0 → plein en ~0,5 s,
  puis la respiration) ;
- la mini-card néon arrive EN RETARD (~0,4 s après le slam), par
  rotation+translation courte depuis derrière l'arête — le retard
  fait le wahou ;
- le texte géant fond pendant le plongeon (il est déjà là quand la
  card se pose).
Tout en fonctions pures de `t`, keyframes pour l'aller-retour
d'échelle (⚠️ jamais deux `withAnimation` sur la même valeur).

## 4. LE TEXTE — « il faut trouver un texte »

Le gabarit : DEUX lignes géantes (le contrat `bigLines`, 3-9
signes par ligne). Candidats à trancher, par variant :

| variant | ligne 1 / ligne 2 | ton |
| --- | --- | --- |
| cardio | `TOP` / `RUN` | sec, brutal |
| cardio | `BEST` / `CARDIO` | descriptif |
| muscu | `TOP` / `LIFT` | sec |
| muscu | `PEAK` / `POWER` | épique |
| les deux | `BEST` / `WEEK` | le fait lui-même |

Le sous-texte (petit, sous la pastille) : la phrase du fait —
« Your best cardio this week. » — VRAIE, du fact engine, gabarit
déterministe d'abord, IA ensuite (même moule que la story card).

## 5. LE POP-REWARD — le même variant, côté récompenses

**C'est AUSSI un nouveau variant de `RewardPopup`** (noté au plan
backend, §4 quater — écrit ce soir) : `style: .top` avec
`sport: cardio | muscu`, robe unique. Différences avec la page
story : les boutons Claim/Later vivent, le halo de page est plus
court (une pop-up n'a pas de contour d'écran à elle — le halo vit
sur le SCRIM), la pills énorme devient un fond de card. Le
déclencheur : le fait « meilleure séance de la semaine » (volume ou
densité par catégorie, fenêtre 7 j) — le moteur §2 du backend
décide QUAND, jamais le client.

## 6. LES JALONS (une capture validée à chaque pas)

- **TS1 — les pastilles.** Le détourage des deux paillettes
  (pipeline Welcome v2 rejoué) → `sticker-pastille-basket` +
  `sticker-pastille-haltere`, planche de contrôle dans la pastille
  squircle aux deux tailles.
- **TS2 — la card re-costumée.** Le layout Welcome v2 sans
  chauve-souris, texte géant rouge animé, pastille-sport, au banc
  (`-topLab` dans le RewardLab existant). Les deux variants côte à
  côte.
- **TS3 — la page story.** La pills énorme + le halo de contour
  rouge/blanc (mesuré à la sonde de luminance) + la card posée.
- **TS4 — l'arrivée fantastique** : plongée + slam + halo qui
  s'allume + mini-card en retard. Filmée au banc auto, fouettage
  (détecteur de flash, cadence).
- **TS5 — la mini-card néon vert** et son fait ; verdict wahou.
- **TS6 — le branchement story** : la page d'exception s'insère
  AVANT le résumé quand le fait existe (4 pages ce jour-là, les
  segments suivent) ; non-régression du flow normal ; verdicts
  téléphone.

## 9. LE LAYOUT RÉVISÉ (verdict 26-08 nuit — « le gros texte
## toujours en haut, le titre et sous-titre en dessous »).
## **PAYÉ sur le « go », avec la première tranche du §8** : les
## balayages blancs sont MORTS (la lame du mot TOP retirée — celle
## de la story 3 l'était déjà — et la nappe qui traversait la
## pastille remplacée par le CATCH-LIGHT A2 à pulses apériodiques,
## `JaugeVent.flicker`) ; le mot est EN HAUT à traîne étirée (mort
## à 0,98) avec les NAPPES DIFFUSES de la story 3 dedans (5
## bosses, périodes premières) ; pastille 0,34·l AU CENTRE qui
## MORD sur RUN ; titre SF 25 + sous-titre 15 seuls dans le tiers
## bas (kicker MORT) ; plus A1 (crête angulaire ±4°/11 s), C8
## (settle à masse 0,006 sur-amorti), C9 (la pastille SE POSE :
## −6 pt + squash 1,03/0,97 en cloche), C11 (odomètre 0 → 42 en
## 0,7 s + néon qui S'AMORCE ambre → vert), C13 (l'amorce
## électrique : deux à-coups, 60 ms d'extinction), D16 (le grain
## doux de la pose). ⚠️ La loi du type-checker re-payée (« tout est
## pré-typé » — le pulse hissé hors du builder). Fouettage : 1423
## frames, AUCUN flash. Puis LE « OK TOP » et quatre retouches,
## payées dans la foulée : flancs à 18 % et pied mort à 0,88
## (« plus fondu sur le côté et le bottom »), 7 nappes plus claires
## et plus larges (« plus d'effet à l'intérieur »), le mot collé au
## sommet −6 pt (« un peu remonté »), et la POUDRE enfin visible —
## `PoudreStory` gagne un `gain` (1,7 ici, 1 = la story 3
## inchangée). Restent du §8 : A3-A4, B5-B7, C10, C12, C14, C15 —
## sur verdict de capture, un à la fois.

Le layout du premier jet (mot géant CENTRÉ derrière tout, kicker +
titre en tête, sous-titre sous la pastille) est REFUSÉ : « pas trop
de lignes de texte comme t'as fait ». La card se réaligne sur SA
SŒUR — la story card de la page 3 — pour la consistance :

1. **LE MOT GÉANT EN HAUT** — exactement l'école du mot argent de
   la story 3, recolorée rouge : même corps (`l × 1,30 / lettres ×
   1,55`), mêmes masques (flancs + dissolution verticale), la TÊTE
   pleine en haut de la card et le corps qui FOND EN DESCENDANT
   dans la card (« le texte va dans le fondu de la card en bas ») —
   la dissolution s'étire plus bas que sur la story 3 (mort à
   ~0,80 au lieu de 0,70), le mot IRRIGUE la card au lieu de
   flotter au centre.
2. **LA PASTILLE, PLUS PETITE ET AU CENTRE** (verdict ajouté dans
   la foulée) : elle redescend de 0,46·l à **~0,34·l** (≈ 113 pt —
   le gabarit de la pastille Welcome, 124 pt, était la bonne
   échelle) et se pose AU CENTRE de la card — mordant encore sur la
   traîne du mot (le chevauchement fait la profondeur), mais c'est
   un médaillon, plus une pièce maîtresse qui mange la card.
3. **LE TITRE PUIS LE SOUS-TITRE, EN DESSOUS** — deux lignes
   SEULEMENT (le kicker « BEST OF THE WEEK » MEURT — c'était la
   ligne de trop) :
   - le titre « Top Cardio » / « Top Lifting » à LA taille de la
     story 3 (le registre de ses lignes : **SF 25 bold**, blanc
     0,94) — « reprends la meilleure taille pour le mini titre » ;
   - le sous-titre (« Your best cardio this week. ») en SF 15
     semibold, gris 0,55, à 6 pt sous le titre.
   Le bloc s'assoit dans le TIERS BAS de la card, sur la fin du
   fondu du mot — le texte vit DANS la matière, pas sur un aplat.
4. **La mini-card néon ne bouge pas** (le wahou est validé).

Hypothèse posée (à corriger d'un mot si fausse) : « le texte qui va
dans le fondu » = le MOT GÉANT dont la traîne fond vers le bas — et
le bloc titre/sous-titre s'assoit sur cette traîne. Si Kathryn
voulait le bloc titre/sous-titre COLLÉ au bord bas de la card, c'est
un offset, pas un chantier.

## 8. LA LISTE DE CHIRURGIEN — micro-détails UI et
## micro-animations (verdict 26-08 : « arrête les balayages blancs,
## c'est trop cheap » — PLAN SEULEMENT, rien n'est codé)

**LE VERDICT D'ABORD, enregistré comme loi** : les EFFETS DE
BALAYAGE BLANC MEURENT — la lame qui traverse le mot ET la nappe
elliptique qui balaie la pastille (les deux du tour précédent).
Une lumière premium n'est jamais une traversée : elle VIT SUR
PLACE — elle glisse, s'accroche, s'amorce. Tout ce qui suit
respecte cette loi.

### A. La lumière (sans jamais balayer)

1. **L'arête qui respire par la CRÊTE** : le liseré de la card
   devient angulaire (école `cardLisereConique`) — une crête de
   lumière FIXE au coin haut-gauche qui glisse de ±4° sur 11 s
   (période première, jamais un métronome). La lampe vit dans la
   pièce, l'objet respire dessous.
2. **Le catch-light de la pastille** : un point spéculaire FIXE en
   haut-gauche du squircle (à 0,30/0,22 de sa face), qui
   s'intensifie par micro-pulses APÉRIODIQUES (bruit de valeur,
   école `JaugeVent.flicker`, amplitude 4 %, jamais de sinus nu) —
   le verre accroche la lumière, il n'est pas traversé.
3. **Le halo de page à deux houles** : la respiration 7,3 s + une
   sous-onde 1,9 s à 20 % d'amplitude — deux périodes premières,
   une houle organique.
4. **L'ombre de la card sur la pills** : une ellipse multiply 0,25
   derrière la card, côté pills — la card EXISTE dans la scène,
   elle ne flotte pas devant un fond.

### B. La matière

5. **Le grain de nuit** : un bruit statique 1:1 à 0,035 d'opacité
   sur le fond de la card, JAMAIS animé — un noir premium n'est
   pas un aplat.
6. **La lumière rasante d'usinage** : 1 px blanc 0,22 → 0 sur
   3 px, sur la SEULE arête haute (l'école SetHistoryRow — un
   contour ouvert, jamais fermé).
7. **Le mot IMPRIMÉ, pas posé** : TOP/RUN gagne une ombre interne —
   la copie du texte décalée de +1 pt en noir 0,5 SOUS le dégradé
   rouge : la gravure, pas l'autocollant.

### C. Les micro-animations (l'arrivée, au chirurgien)

8. **Le settle à masse** : après le slam, 1,000 → 0,996 → 1,000 en
   0,42 s (ressort sur-amorti, un seul rebond mort) — l'objet
   pèse.
9. **La pastille SE POSE** : née après le slam, elle descend de
   6 pt avec un squash 1,03/0,97 sur 0,26 s pendant que l'ombre
   s'étale (l'école de la pièce du calendrier) — une pose, pas une
   apparition.
10. **Le kicker qui se resserre** : « BEST OF THE WEEK » naît avec
    son tracking qui descend de 6,0 → 2,8 en 0,5 s pendant que
    l'opacité monte — le titre Apple se condense en naissant.
11. **L'odomètre de la mini-card** : le 42 ROULE de 0 en 0,7 s à
    sortie douce (école `count`), et le néon s'allume en DEUX
    temps — ambre faible 0,1 s, puis vert plein : un tube
    s'amorce, il ne fade pas.
12. **Trois plans au poignet** : gyro différentiel — mot géant ×2,
    pastille ×5, mini-card ×7 (elle est au-dessus) ; jamais de
    rotation 3D (le verdict de la card qui laguait).
13. **L'amorce électrique du halo** : à l'impact, l'arête blanche
    s'allume par DEUX à-coups (60 ms d'extinction entre les deux)
    avant de tenir — remplace le flash simple : un néon réel
    s'amorce.
14. **L'impact a une conséquence** : quand la mini-card claque, la
    GRANDE card encaisse — 1,5° de rotation opposée, amortie en
    0,3 s.
15. **La poudre SOULEVÉE** : au slam, les grains naissent en
    ANNEAU depuis le point d'impact (rayon 0 → l en 0,8 s) puis
    reprennent leur vie lente — la poussière est soulevée par
    l'atterrissage, elle ne préexiste pas.

### D. L'haptique fine

16. Le grain doux À LA POSE de la pastille (n° 9), distinct du
    slam ; le tick de la mini-card reste sur SON image d'impact —
    trois événements, trois textures, jamais une rafale.

L'ordre de paiement proposé : d'abord LA MORT DES BALAYAGES (retrait
sec), puis A1-A2 (la lumière juste), puis C8-C9-C11-C13 (l'arrivée),
puis le reste sur verdict de capture — un item à la fois, la boucle
courte.

## 7. À TRANCHER PAR KATHRYN

1. **Les mots** des deux lignes géantes (le tableau du §4) — et le
   sous-texte : FR ou EN (le parcours est EN) ?
2. **La mini-card** : quelle stat exactement (le « 3.0x » de chez
   nous) — et son libellé ?
3. **La place dans la story** : page d'exception AVANT le résumé
   (recommandé — l'exception d'abord, 4 pages ce jour-là) ou À LA
   PLACE du résumé ?
4. **Le déclencheur v1** : « meilleure séance de la semaine » par
   volume (muscu) et minutes/densité (cardio) — ces deux
   définitions te vont ?
5. **Le halo de page** : rouge → blanc pur proposé ; l'or de la
   maison a-t-il sa place (lune) ou strictement rouge/blanc ?
