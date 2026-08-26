# PLAN V7 — « ÇA DOIT ÊTRE COMME UN FILM : DOUX, MÉLODIEUX »

Verdict Kathryn du 26-08, troisième tour. Quatre sujets, dont deux jamais
regardés. **Rien n'est codé** — ce document est l'état des lieux mesuré et les
arbitrages à prendre.

Rappel de ce qui est déjà livré et vérifié (V4/V5/V6, non commité) : le film
d'arrivée à 60 img/s, la couture noire, le header figé après le film, les
corbeaux qui rendent enfin, les fondus d'état adoucis à durée totale constante,
et `BoosterScene` construite une fois au lieu de deux.

---

## 1. CE SONT DES CHAUVES-SOURIS — plus noires, plus petites

### L'état

`NightBirds` trace un glyphe d'**oiseau** : deux `addQuadCurve` lisses,
symétriques, pointes relevées. C'est un goéland vu de loin, pas une
chauve-souris. Réglages actuels dans la Lune de Sang : ivoire 0,62, échelle
2,4, six individus.

### Le conflit, et il est mesuré

Kathryn demande **plus noir**. Or le ciel sous les six trajectoires pèse
**18,4/255 en moyenne** (médiane 13,7) : un trait noir n'y creuse que
**17/255** de contraste. C'est ce qui les rendait introuvables avant, et c'est
pour ça qu'ils sont passés à l'ivoire.

**La sortie n'est pas la couleur, c'est LE CHEMIN.** Le contre-jour suppose un
DISQUE lumineux derrière la silhouette. Ici la lune est un CROISSANT
(`soloNeon: 1`) : il y a bien une zone claire, mais les trajectoires la
frôlent au lieu de la traverser. `drift` étale les six sur une bande de
−34 → +58 pt autour du centre, et l'essentiel de cette bande est du vide noir.

Si on resserre la bande de vol pour qu'elles passent **devant la lueur**, le
fond sous elles monte à 100-250/255 et une silhouette noire y claque — c'est
exactement le plan que l'archive réussissait avec sa lune pleine.

### Les travaux

1. Un glyphe **chauve-souris** : ailes anguleuses (segments, pas des courbes
   molles), pointes marquées, échancrure au bord de fuite, petit corps au
   milieu. À cette taille, c'est l'ANGULARITÉ qui distingue de l'oiseau.
2. Échelle **2,4 → ~1,5** (« plus petit »).
3. Plumage **noir ~0,88** (« plus noir ») — au lieu de l'ivoire 0,62.
4. **Resserrer `drift`** pour croiser la lueur. C'est le point qui décide de
   tout : sans lui, 2 et 3 les font disparaître à nouveau.
5. Garder `lumiere:` (elles meurent avec la lune) — acquis de la V6.

⚠️ **`NightBirds` est PARTAGÉ avec l'archive `MoonSplashView`.** Le glyphe doit
devenir un paramètre (`forme: .oiseau | .chauveSouris`), défaut `.oiseau`, comme
`plumage` l'a fait. On ne touche pas au plan-séquence.

### Ce que je mesurerai

Le contraste sous les silhouettes (masque par `-corbeauxSonde`, luminance du
rendu normal). **Cible : au moins la moitié du trajet au-dessus de 60/255.**
En dessous, le noir n'est pas tenable et il faudra un liseré de lumière au bord
de l'aile plutôt qu'un aplat.

---

## 2. LE SON DE LA LUNE DE SANG — TROUVÉ, ET IL EST INTACT

**Kathryn a raison, et mon premier passage était trop étroit.**

`Woop/Sounds/MoonSplashTheme.m4a` — **176 Ko, 15,56 s** — existe toujours dans
le dépôt. Sa classe `MoonTheme` (dans `RocketHaptics.swift`) est complète :
volume 0,55, `.ambient` + `mixWithOthers`, et même un `stop()` en fondu de
0,35 s « pour que passer le splash ne claque pas ».

**Elle n'est appelée que depuis `MoonSplash.swift`** (lignes 847 et 866) — le
plan-séquence de 13,95 s mis en archive. `LuneDeSangView` ne l'appelle jamais.

Exactement le même schéma que les corbeaux : rien n'a été supprimé, tout est
devenu **orphelin** le jour où l'écran a changé. (Au passage : `AuroraSwipe.wav`
n'est joué par personne non plus.)

### La forme du thème, mesurée (RMS par 0,25 s)

```
 0,00 → 1,00   silence
 1,00 → 6,00   la montée lente (le bourdon qui enfle)
 6,25          ★ L'IMPACT — le pic
 6,50 → 11,0   le pad qui s'ouvre, puis se pose
11,0  → 12,5   décrue vers le silence
13,25 → 15,25  ★ LE PETIT GESTE FINAL  ← très probablement « le bruit de fin »
```

### Le travail : un RECUT, pas un simple rebranchement

Le thème a été composé pour 13,95 s et ses accents tombent sur les accidents
de caméra de CE plan-là. La Lune de Sang fait 4,45 s et sa pose est à 1,30 s.
Joué tel quel, l'impact arriverait 5 secondes après la pose.

Trois morceaux à raccorder sur la partition (à affiner à la mesure) :

| morceau | source | va sur |
|---|---|---|
| A — la montée | ~4,95 → 6,25 s | naissance + plongée, **impact calé sur tPose = 1,30** |
| B — le pad | 6,25 → ~8,5 s | les trois états |
| C — le geste final | 13,25 → 15,56 s | l'extinction, fondu enchaîné |

⚠️ On ne re-synthétise RIEN : les scripts d'origine (`moonmusic5.py`) n'ont
jamais été commités et sont perdus avec leur scratchpad. On coupe dans le
fichier existant — c'est la même loi que le recuit des vidéos.

⚠️ `MoonTheme.stop()` doit être câblé sur le tap-qui-passe et sur `finish()`,
sinon le thème survit à l'écran qui l'a lancé.

---

## 3. « C'EST HACHÉ » — trois causes distinctes, à ne pas confondre

### (a) Des images réellement perdues — et aucune courbe ne rattrape ça

Mesuré au dernier lancement : **286 ms de trou dans la première seconde**, puis
**100 ms dans la deuxième**. À 60 Hz, c'est **17 images puis 6** qui ne sont
jamais servies, en plein pendant la naissance et la plongée de la lune.

C'est littéralement du haché, et c'est la première chose à tuer. Suspects, à
ISOLER et pas à deviner : l'ouverture du store SwiftData/CoreData au lancement
(le journal montre une récupération d'erreur 512), la compilation des shaders,
la LUT `MoonSDF`. La vue attend déjà `MoonSDF.isReady` avant de poser son
horloge — donc le trou vient d'ailleurs.

### (b) La structure en marches

Palier 0,55 s → fondu → palier 0,55 s → fondu → palier. Même avec le
smootherstep de la V6, **une teinture qui S'ARRÊTE une demi-seconde puis repart
se lit comme un pas**. C'est la structure elle-même qui fait les marches, pas
la raideur des fondus.

**TRANCHÉ PAR KATHRYN** : « il faut les états, mais plus fondus, pas aussi
coupés. » Donc **on garde les trois états, on supprime les arrêts.**

Une seule courbe **continue** de bout en bout : la teinture ne s'immobilise
plus jamais complètement, elle RALENTIT sur chaque état puis repart. Les trois
états restent parfaitement lisibles — mais par leur **couleur** (ivoire →
ambre → sang), plus par un arrêt du mouvement.

⚠️ **Ça révoque une loi écrite en tête du fichier** — « 0,55 s par palier est
un plancher : en dessous, l'œil ne lit plus trois états mais un dégradé
continu ». Elle défendait la lisibilité des états ; la demande vise la
fluidité. **La révocation est explicite et doit être écrite dans le fichier**,
pas subie — avec sa contrepartie : si les états cessent de s'arrêter, il faut
**creuser l'écart de COULEUR entre eux** pour qu'ils se lisent sans le secours
de l'immobilité. Sinon on obtient le dégradé continu que la loi redoutait.

### (c) L'haptique « horrible »

`RocketHaptics.paliers` tire **trois impacts transitoires** (intensité 1,0 /
0,85 / 0,85, netteté 0,30 / 0,08 / 0,08), chacun doublé d'un grondement continu
de 0,28-0,36 s. **Trois coups frappés en 4,45 s**, calés pile sur les trois
états — l'haptique SOULIGNE donc les marches au lieu de les fondre.

Le vocabulaire juste pour ce plan existe, il a été écrit pour l'ancien splash
et perdu avec lui : **« rien n'est frappé, tout respire »**.

**Proposition** : zéro transitoire (ou un seul, très doux, à la pose), et une
**enveloppe continue unique** dont l'intensité suit la courbe de lumière —
elle monte avec la plongée, culmine à la pose, et redescend avec l'extinction.
⚠️ Le simulateur est MUET en haptique : ça se juge sur l'appareil, uniquement.

---

## 4. LES DEUX WIDGETS PROGRESS DE LA PAGE 3

### La cause — et ce n'est PAS une chute de cadence

Page 3 mesurée au banc (`-porteVue -portePage 2 -fps`) :
**60,0 img/s, pire trou 17 ms**, huit secondes d'affilée. La page va bien.

Le défaut est une **quantification temporelle**. `.flotte` tourne dans un
`TimelineView(minimumInterval: 1/30)` : la dérive continue de 4 pt n'est
recalculée que **30 fois par seconde**. Sur un écran à 60 Hz c'est **une marche
toutes les 2 images** ; sur le ProMotion du téléphone, **une toutes les 4**.
D'où « ça bouge en saccadé » alors que le compteur dit 60.

⚠️ **La sonde de cadence ne peut pas voir ce défaut** : elle compte les images
SERVIES, pas si l'animation qu'elles portent est en escalier. C'est une limite
à retenir — elle a déjà validé cette page.

### L'historique, qui dit que ça n'a jamais marché

Le flottement a été demandé le 23-08. Il a coûté **60 → 14 img/s** (un verre qui
bouge force la recapture de son fond). Il a donc été bridé à **12 Hz** pour
survivre, puis remonté à **30 Hz** le 26-08 contre un verdict « tout est haché ».
Il n'a jamais été bon à aucun des trois réglages.

### LA DÉCISION DE KATHRYN : on GARDE le flottement, on le rend fluide

Donc pas question de le retirer. Il faut le rendre lisse **et** payable, et
c'est le point le plus difficile de ce plan.

### Pourquoi c'est difficile — la vraie contrainte

Les deux widgets sont de VRAIES cards de la home (`CardVolume`, `CardSeances`)
avec `verre: true`, donc un `glassEffect` **natif** à l'intérieur de
`CardCorps`. Le `.offset` du flottement déplace donc **du verre natif**, et
un verre qui bouge **re-capture son fond à chaque position**.

Et ce qu'il y a derrière, page 3, c'est **la vidéo du header qui joue**. C'est
le pire cas mesuré du dépôt : « verre sur vidéo vivante 14 img/s, verre sur du
noir 59 ». Poser une image fixe sous le verre a déjà été **révoqué par toi**
(« la vidéo se reflète justement dans leur verre »). Cette porte-là est fermée.

### ⚠️ LA PISTE DE L'ANIMATION DÉCLARATIVE A ÉTÉ ESSAYÉE — ELLE EST FAUSSE

J'ai remplacé l'échantillonnage 30 Hz par une animation **déclarative**
(`repeatForever`), en pariant qu'une animation confiée au serveur de rendu
serait à la fois plus lisse ET moins chère, le corps de la vue cessant d'être
réévalué.

**Résultat mesuré : la page 3 est tombée de 60,0 à 14,0 img/s** — exactement
le « 60 → 14 » que l'histoire du fichier annonçait déjà. Revenu en arrière
(retour mesuré à 54-57 img/s).

**LA LEÇON, et elle vaut pour tout le dépôt :** déplacer du verre natif coûte
**par image, quel que soit QUI pilote le mouvement**. Le verre re-capture son
fond à chaque position — ici une vidéo en train de jouer. Doubler la cadence
du mouvement double la note. Ce n'est donc pas la façon d'animer qu'il faut
changer, **c'est le fait que la vitre bouge**.

### ⚠️ ET LE « SACCADÉ » NE VIENT PROBABLEMENT PAS DE LÀ

Calcul refait : à ±4 pt sur 6 s, un pas de 1/30 s déplace **0,14 pt** — très
en dessous du seuil de perception. L'escalier que j'avais diagnostiqué
n'existe pas à cette amplitude, et mon diagnostic du tour précédent était
donc faux. Le vrai suspect est que **la page entière perd des images sur ton
téléphone** — ce que le simulateur ne montrait pas à 30 Hz (il tenait 60),
mais qu'il a montré net dès que j'ai doublé la cadence. Il n'était pas
aveugle : il était sous le seuil.

### LA SEULE PISTE QUI RESTE — et elle demande ton feu vert

**Ne bouger que le CONTENU, pas la vitre.** Le verre reste fixe, l'encre et le
liseré dérivent de ±4 pt à l'intérieur. À cette amplitude l'œil lit exactement
la même chose, la re-capture disparaît, et le flottement devient gratuit.

⚠️ **Invasif** : ça touche `CardCorps`, partagé avec la home — une erreur là
se verrait sur la home aussi. Je ne le fais pas sans ton accord.

⚠️ **`compositingGroup()` est INTERDIT ici** — loi déjà payée : il répare la
géométrie du verre natif mais **tue sa réfraction**.

### La mesure — et elle doit se faire SUR LE TÉLÉPHONE

Le simulateur dit **60,0 img/s, pire trou 17 ms** sur cette page. Il ne
reproduit donc pas ton « ça lag de fou » : il est aveugle au coût GPU du verre
(loi du dépôt). **Toute cette section se juge à la sonde `-fps` sur
l'appareil**, avant et après. Je ne changerai rien sur la foi du simulateur.

⚠️ **À décider** : la card « Sets » de la page 2 porte le **même** flottement.
Si la piste 1 marche, elle en profite gratuitement — je l'y applique aussi
sauf avis contraire.

---

---

## 5. « PLUS ANIMÉ, PLUS DE DÉTAIL MICRO-UI, GENRE 10 FOIS PLUS »

C'est la demande la plus lourde du lot, et elle **entre en tension directe avec
« ça lag »** : chaque détail ajouté est un coût. La règle du chantier est donc
non négociable : **tout détail doit être GRATUIT ou presque**, c'est-à-dire
peint dans une surface qui existe DÉJÀ.

Deux surfaces existent et sont déjà payées :
- le **shader** `logoMonolith` (une seule passe, plein écran) ;
- le **`Canvas`** des chauves-souris (un seul contexte 2D).

⚠️ **La règle qui tue le lag** : aucun nouveau `TimelineView`, aucune nouvelle
couche `glassEffect`, aucun nouveau lecteur vidéo, aucune vue SwiftUI par
particule. Une seule image, jamais N copies redessinées à 60 Hz — c'est la loi
déjà payée deux fois dans ce dépôt (la pastille, la chauve-souris de la card).

### Les candidats, du moins cher au plus cher

| # | détail | où | coût |
|---|---|---|---|
| 1 | **Poussière d'étoiles** qui dérive lentement, densité et taille variées | shader (starfield déjà là) | ~0 |
| 2 | **Micro-scintillement** du tube néon : variations d'intensité fines et irrégulières | shader (`idleLife` existe) | ~0 |
| 3 | **Chauves-souris en 2 ou 3 PLANS** : lointaines minuscules et lentes, proches plus grandes et rapides → profondeur | Canvas existant | quasi nul |
| 4 | **Braises / cendres** qui montent lentement devant la lune | Canvas existant | faible |
| 5 | **Voiles de nuage** qui passent devant le croissant et le voilent une seconde | shader | faible |
| 6 | **Halo qui respire** — le rayon pulse très légèrement, hors phase avec les états | shader | ~0 |
| 7 | **Micro-éclats** sur l'arête du croissant, qui glissent le long du tube | shader | faible |
| 8 | **Vignette vivante** : les coins respirent avec la lumière | shader | ~0 |

### Ce que je propose

Une **première salve : 1, 2, 3, 6** — les quatre à coût nul ou quasi nul, qui
donnent le plus de vie par pixel. On mesure à la sonde **sur l'appareil**. Si
le budget tient, deuxième salve : 4, 5, 7, 8.

⚠️ « Dix fois plus » se juge à l'œil, pas au compteur : je te montrerai un
film court après chaque salve plutôt que de tout empiler d'un coup et de
découvrir à la fin que la page ne tient plus 60 img/s.

---

## ORDRE PROPOSÉ

1. **Le son** (§2) — le plus gros effet pour le moins de risque : le fichier
   existe, la classe existe, il n'y a qu'un recut et trois appels à écrire.
2. **Le trou de 286 ms** (§3a) — c'est la moitié du « haché », et c'est du
   vrai lag, pas du ressenti. Aucune courbe ne le rattrapera.
3. **La courbe continue** (§3b) — tranché : états gardés, arrêts supprimés,
   écart de couleur creusé.
4. **Les chauves-souris** (§1) — glyphe paramétré, plus petit, noir, et
   surtout le chemin qui croise la lueur.
5. **L'haptique** (§3c) — enveloppe continue qui suit la lumière. ⚠️ Muette
   au simulateur : verdict téléphone obligatoire.
6. **La micro-vie, salve 1** (§5) — les quatre détails à coût nul.
7. **Le flottement fluide** (§4) — en dernier parce que c'est le seul point
   qui exige une mesure SUR L'APPAREIL avant et après, et que je refuse de le
   changer sur la foi d'un simulateur qui dit déjà 60 img/s.

## LES DEUX SEULS POINTS ENCORE OUVERTS

- **§4** : le flottement de la card « Sets » (page 2) suit-il le même
  traitement que les deux widgets ? (Par défaut : oui.)
- **§5** : la salve 1 (étoiles, scintillement du tube, chauves-souris en
  plusieurs plans, halo qui respire) te va, ou tu veux d'autres détails
  d'abord ?

Tout le reste est tranché et peut partir.
