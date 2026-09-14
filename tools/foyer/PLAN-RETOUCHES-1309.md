# LES DEUX CHANTIERS DU 13-09 — ① LA POP-UP STOP · ② LA PAGE HOME EN SÉANCE

> **Rien n'est codé** (sa consigne). Ses mots, verbatim : « le bouton stop est
> trop collé et il doit être 2 fois plus gros » · « le médaillon oui plus gros,
> tu remontes le contenu alors, du bouton et tout, car **on voit rien** » ·
> « **baisse la partie timer et la partie avec la date et le nombre de sets** » ·
> « la pop-up avec le Nosfy est cassée : trop blanc, pas assez fondu — du noir
> fondu à sa moitié et le background noir de la card » · « espacer davantage le
> titre et le sous-titre » · « dans le slider enlève le texte — dans TOUS les
> composants : le texte apparaît quand le user commence à slider, même font que
> les boutons primary » · « la hauteur de la pop-up Stop ≠ celle des rewards,
> alors que c'est le même composant » · « sur la home on ne comprend pas qu'on
> peut cliquer : un effet on-tap, ou tout l'écran qui change pour comprendre
> qu'on peut afficher l'overlay ».

---

# CHANTIER ① — LA POP-UP STOP (`StopCard.swift`)

## A. LA COMPOSITION DE LA CARD — le vrai défaut (refait le 14-09, « wtf »)

**Le diagnostic, sur SA capture** : ce n'était pas d'abord un problème de
dégradé — **le bloc de texte MARCHE SUR le Nosfy**. La bête, bord à bord et
centrée, descend DERRIÈRE « Stop the session? » et le bilan : ses pattes
passent sous les lettres. Mon premier « fondu » (raide, calé sur la card)
faisait une coupe ; le second (doux) fond ses pattes… qui restent SOUS le
titre. Tant que la bête et le texte se partagent la même bande, c'est cassé.

**Le chevauchement, MESURÉ** (capture `stop-438-A12.png`, hauteur famille déjà
posée) : la matière de la bête va de 656 à 2006 px pendant que l'encre blanche
commence à 1306 — **~700 px de bête sous le texte, la moitié de la card**. Le
fondu actuel n'atteint le noir total qu'au pied (loc 1,0) : par construction,
la bête traverse le titre.

**LA LOI DE COMPOSITION — des BANDES qui ne se chevauchent JAMAIS**
(card famille 332 × 438, ratio 1,32 — tranché le 14-09) :

| bande | y (sur 438) | contenu |
|---|---|---|
| 1 · la scène | 0 → ~225 | le mot STOP + **le BUSTE de la bête** — elle ÉMERGE du noir, ses ~30 % du bas déjà dissous |
| — le fondu | ~150 → 225 | le noir monte de 0 à **1,0 — TOTAL avant la bande 2** : plus un pixel de bête sous le texte |
| 2 · l'encre | ~245 → 300 | titre (espacement A/B 12-16) puis bilan |
| 3 · le slider | ~325 → 383 | muet au repos, Inter 18 à la prise |
| 4 · Cancel | ~395 → 430 | inchangé |

**Trois gestes, dans l'ordre :**
1. **Caler la VIDÉO en HAUT de la card** (alignement `.top`, jamais un
   redimensionnement — loi vidéo intacte) pour que la bête vive dans la
   bande 1 : son buste dans la lumière, son bas dans le fondu.
2. **Le fondu se cale sur LE TITRE, pas sur le pied de card** : noir TOTAL à
   `(y du titre − 20 pt)`. C'est la définition mesurable de « fondu à ses
   30 % du bas » : la bête n'a plus de bas — elle sort du noir comme le mot
   STOP sort de l'ombre.
3. **Preuve à la pipette AVANT de montrer** : sur la colonne de la bête,
   α(noir) = 1,0 à la ligne du titre ; la pente du fondu s'étale sur ≥ 70 pt
   (aucune marche > 0,3) ; et AUCUN pixel de bête (luminance > 12) sous
   `y(titre) − 20`.

*(La hauteur famille 438 est posée ; l'encre reste ancrée bas avec ses
espacements — l'air gagné par 438 va à la bande 1, pas au texte.)*

## B. Titre / sous-titre : plus d'air

`spacing: 7` aujourd'hui (`:319`) → **A/B sur capture : 12 et 16**.

## C. Le slider : muet au repos, la voix du primaire

**La cause du « moche », chiffrée** : le label du slider est en **système
~10 pt** (`SliderObsidienne.swift:338` : height × 0,169) contre **Inter 18
semibold** au bouton primaire (`BoutonPrimaire.swift:162`).

**La règle, posée UNE fois dans le composant** → les 6 écrans héritent (stop,
repos de série, départ home, tapis, 2 bancs) :
1. au repos : **aucun texte** ;
2. le texte **naît avec la prise** (opacité branchée sur la valeur de prise qui
   existe déjà — aucune horloge) ;
3. **Inter 18 semibold**, tracking −0,2, en phrase.

*Risque nommé : un slider muet ne dit plus ce qu'il fait — décision assumée,
vérifiée au doigt au banc ; repli d'une ligne par site si besoin.*

## D. LA STOP DEVIENT UNE ROBE — le composant autonome meurt (tranché 14-09)

Ses mots : « même taille que la famille des pop-ups ; **la tienne ne doit
jamais exister, c'est une robe/variant de toutes nos pop-ups** ».

**L'architecture existe déjà** : `RewardPopup` porte SIX robes
(`RewardStyle: halo · neon · galet · spotlight · fire · welcome`,
`RewardCard.swift:59-60`) — la Stop devient la **septième** : `case stop`.

- **hauteur** : celle de la famille — 332 × 438 (ratio 1,32). La condensation
  du 04-09 (372) est annulée par sa loi du 13-09.
- **ce que la robe `stop` apporte** : la vidéo de la bête + son masque cuit,
  le mot « STOP » derrière, la lampe, et **des COMMANDES à elle** (slider +
  Cancel au lieu du bouton claim) — le composant doit gagner un slot de
  commandes par robe, c'est LE morceau neuf du refactor.
- **ce qui migre tel quel** : le noir fondu du §A, les espacements du §B, le
  slider muet du §C — ils se posent DANS la robe, pas dans un fichier à part.
- **ce qui meurt** : `StopCard` la struct ; l'hôte (`StopCardHote`, le film
  Animatable, les portes `pauseOuverte`) reste et monte désormais
  `RewardPopup(style: .stop)`.
- ⚠️ le fichier `RewardCard.swift` est VIVANT chez d'autres sessions (les
  paramètres « sortie de Nosfy » du 13-09 y sont entrés) : couture à annoncer
  avant d'écrire, commit par chemins.

---

# CHANTIER ② — LA PAGE HOME EN SÉANCE (`Foyer.swift`)

## E. La nouvelle composition — le groupe du bas se RESSOUDE

Ce que tu as dit : le médaillon **plus gros**, le bouton **remonté** (« on voit
rien » en bas), et **le timer + la carte date/sets DESCENDENT**. Résultat : le
noir vit entre la phrase et le groupe ; en bas, un seul bloc soudé
carte → chrono → bouton → médaillon, aéré et lisible.

| pièce | aujourd'hui (B = 709) | proposé |
|---|---|---|
| le point + la phrase | 34 · 74 → 218 | inchangés |
| **LE NOIR** | éparpillé | **un seul vide : 218 → 355** |
| carte du jour + ticket | 284 → ~362 | **↓ 355 → 433** (0,500) |
| chrono 80 pt | 396 → 476 | **↓ 443 → 523** (0,625) — collé sous la carte : date · sets · temps se lisent comme UN groupe |
| bouton | 570 → 628 | **↑ 546 → 604** (0,770) |
| médaillon stop | Ø 34, collé (628/627 : −1 pt d'air) | **Ø 68**, 620 → 688 (0,875) — air 16 pt, marge robe 21 |

Le doublement du médaillon : **un paramètre `taille:` dans `MedaillonStop`**
(le dessin reste fin — un `scaleEffect(2)` épaissirait liseré et glyphe).
⚠️ Composant partagé du player : couture annoncée avant d'écrire.

## F. L'affordance du détail — « on ne comprend pas qu'on peut cliquer »

Reco : **B + A**, cumulés :

- **A. L'impulsion du ticket** : toutes les ~9 s, la carte+ticket respire UNE
  fois (échelle 1,000 → 1,015, 0,7 s) — ça « propose d'ouvrir » sans un mot.
- **B. LA PRESSION QUI RÉPOND PAR TOUT L'ÉCRAN** (ta phrase, en
  rouge·blanc·noir — jamais un changement de teinte) : dès que le doigt SE POSE
  sur le groupe carte/chrono, **la lumière du feu monte d'un cran partout**
  (fond +20 %, braise +15 %, lèvre du bouton +20 %) pendant la pression ; au
  relâcher, l'overlay s'ouvre et la lumière retombe. Trois opacités animables,
  zéro redessin.
  ⚠️ Geste : zone bornée AVANT les paddings, jamais un `highPriorityGesture`
  (les deux voleurs de taps déjà payés).

---

# LES JALONS — captures d'abord, rien sans ton go

| jalon | chantier | preuve |
|---|---|---|
| J1 | ① A+B : le Nosfy fondu + titres 12/16 | 2 captures A/B (et « cassée » se précise dessus) |
| J2 | ① C : sliders muets + Inter 18 | capture + film 6 s du texte qui naît à la prise |
| J3 | ① D : la robe `stop` dans RewardPopup, StopCard meurt | reward et stop côte à côte, même hauteur — et le film de la stop rejoué (rien ne doit changer à l'œil sauf la hauteur et §A-C) |
| J4 | ② E : la composition ressoudée + médaillon Ø 68 | capture + juge de cotes |
| J5 | ② F : la pression plein écran + l'impulsion | film 10 s : pose → l'écran monte → relâche → overlay |

**Tout est tranché.** (14-09 : la hauteur = celle de la famille, et la Stop
devient une robe de `RewardPopup` — le composant autonome ne doit jamais exister.)
