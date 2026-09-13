# LE THÈME DE NOSFY — une musique de fond « magique mais pas princesse »

*13-09-2026 · plan, rien n'est codé · le son du film de Nosfy*

Sa consigne : « une petite musique de fond magique mais pas princesse, discrète, pour
l'onboarding — et quand j'appuie sur un bouton, un bruit ». Et son verdict sur le premier
jet : « tu as mis le son du splash, j'imaginais un nouveau ».

---

## 0. Ce que la maison a, et ce qu'elle a perdu

| | mesuré |
|---|---|
| `Woop/Sounds/` | 13 sons : trois **thèmes** (`MoonSplashTheme` 15,6 s, `LensTheme` 9,4 s, `LuneSangTheme` 5,5 s — le dernier est un RECUT du premier) et dix **bruits** courts (0,07 → 1,45 s : `DialTap`, `DialTick`, `Paillette`, `AuroraSparkle`, `NeonIgnite`…) |
| leur origine | **synthétisés** — le vocabulaire est dans les commentaires de `PiluleVagabonde` : « des partiels non harmoniques (le grain cristal, jamais la cloche), une attaque de 22 ms (aucun clic), une longue traîne, un glissando doux » |
| le script | **`moonmusic5.py` — PERDU.** `recuit_theme.sh` le dit : « jamais commité, mort avec le scratchpad de sa session ». On ne pouvait plus que COUPER dedans |
| la forme du splash | un *cue*, pas une boucle : silence → montée → impact à 6,3 s → pad → creux → geste final. Il commente une image précise (la pose de la lune). Mis en boucle sous l'onboarding, son impact revient toutes les 15 s — c'est ce qui sonnait « splash » |
| les outils | `numpy 2.0.2` et `scipy 1.13.1` sont là : on peut synthétiser pour de vrai |

**La leçon, avant tout :** le script du thème vit dans `tools/porte/theme_nosfy.py`, avec sa
graine fixe, et il **part dans le commit** avec le fichier. Un son qu'on ne peut pas
régénérer est un son qu'on ne peut pas retoucher — c'est exactement ce qui est arrivé à
la lune de sang.

---

## 1. « Magique mais pas princesse » — ce que ça veut dire, acoustiquement

Ce qui fait *princesse* : une mélodie, un mode majeur, une harpe ou un glockenspiel en
arpèges, un tempo. Ce qui fait *magique* : de la hauteur (des partiels qui brillent), de la
lenteur, de l'espace (une longue réverbération), et l'**imprévu** — des éclats qui ne
reviennent jamais au même endroit.

Donc : **une texture, pas un morceau.** Aucune mélodie, aucun tempo, aucune tierce
majeure. Une lenteur qui se compte en dizaines de secondes, et des cristaux clairsemés.

**Et « moins flippant que le thème du splash »** (sa précision, 13-09). Ce qui rend le splash
inquiétant est mesurable : le bourdon **très grave** (55 Hz), les partiels **froids** (très
inharmoniques, comme du verre), et l'impact. Le thème de Nosfy garde la nuit mais **chauffe**
la matière :

| | le splash (flippant) | Nosfy (magique) |
|---|---|---|
| le grave | 55 Hz, sombre, qui enfle | **110 Hz**, doux, qui respire — jamais ne gronde |
| le mode | éolien pur (tout mineur) | **dorien** — la sixte majeure éclaire sans faire « princesse » |
| les cristaux | très inharmoniques, froids | **presque harmoniques** (f · 2,0 f · 3,02 f) — chauds, comme un bol, pas une vitre |
| les événements | un impact | **aucun** — rien ne surgit, tout apparaît |
| l'air | peu | **plus d'air** (−32 dB), plus haut (3 → 7 kHz) : de la lumière |

Le test, à l'oreille : les yeux fermés, on doit se sentir **accueillie dans une pièce
sombre**, pas surveillée dedans.

| couche | matière | rôle |
|---|---|---|
| **le bourdon** | la2 (110 Hz) et mi3 (165 Hz), doux, qui respirent sur 12 s ; une trace de la1 (55 Hz) à −14 dB seulement | le sol — chaud, pas grondant. ⚠️ **le haut-parleur d'un iPhone ne rend rien sous ~200 Hz** : c'est le 110 Hz qui existe au haut-parleur, le 55 n'est là qu'au casque, et à peine |
| **le pad** | quatre partiels sur la3 · mi4 · fa#4 · ré5 (la, do, ré, mi, fa# : **dorien** — la sixte majeure fa# éclaire sans faire « princesse » ; jamais le do#), chacun désaccordé de ±3 cents et chorusé lentement | la nappe — ce qui fait « il y a de la musique » sans qu'on puisse la chanter |
| **les cristaux** | 7 éclats par cycle, à des instants tirés d'une graine fixe (jamais réguliers) : partiels à f · 2,0 f · 3,02 f (**presque harmoniques** — chauds comme un bol, pas froids comme une vitre : c'est ça, « moins flippant »), attaque 22 ms, traîne exponentielle 2,5 → 4 s, glissando descendant de 0,6 % | la magie. Sept par cycle de 24 s : assez pour scintiller, trop peu pour devenir une mélodie |
| **l'air** | un bruit rose filtré 3 → 7 kHz à −32 dB, qui respire avec le bourdon | la lumière — ce qui empêche la nuit d'être un cachot |
| **l'espace** | une réverbération à queue de 3,2 s (convolution `scipy.signal.fftconvolve` avec une réponse synthétique à décroissance exponentielle) | la pièce noire dans laquelle tout ça vit |

Mixage : bourdon −18 dB · pad −20 · cristaux −26 · air −38, puis **−24 LUFS intégrés**,
crête < −6 dBFS. Et par-dessus, les **18 %** de l'app : elle doit se chercher, pas
s'imposer. « Discrète » se mesure — pas au jugé.

---

## 2. La forme : une boucle exacte, par construction

24 s, **sans couture** — pas par fondu enchaîné cuit, mais par arithmétique : **toutes les
modulations ont une période qui divise 24 s** (le bourdon 12 s, le chorus 8 s, l'air 24 s),
et les cristaux sont placés dans les 24 s avec leurs traînes qui **débordent au début**
(la queue du dernier éclat est ajoutée en tête). L'image 0 et l'image 24 s sont
mathématiquement la même : la boucle est invisible parce qu'elle n'existe pas.

Le film dure ~11 s d'accueil + ~40 s de questions : deux tours et demi. Aucun événement
ne se répète à l'oreille en si peu de temps.

---

## 3. Le bruit du tap — de la même matière

`DialTap` est un bruit de cadran, pas de Nosfy. Le tap du film sera **un cristal du thème**,
seul, court (attaque 22 ms, traîne 0,45 s), à −12 dB — fabriqué **par le même script**, avec
les mêmes partiels. Le tap et la musique sont alors la même matière : on n'entend pas
« un son d'interface sur une musique », on entend Nosfy.

Deux tailles : `NosfyTap` (cards, jours, Passer, Entrer) et `NosfyPaillette` (quand il
répond dans l'île — plus haut de deux octaves, traîne 1,2 s).

---

## 4. Les fichiers, et leur place

| fichier | quoi |
|---|---|
| `tools/porte/theme_nosfy.py` | le script (numpy + scipy), graine fixe, **commité** |
| `Woop/Sounds/NosfyTheme.m4a` | 24 s, AAC 128 kbit/s, ~400 Ko |
| `Woop/Sounds/NosfyTap.wav` · `NosfyPaillette.wav` | les deux bruits |

Dans `NosfySon` : `theme = "NosfyTheme"`, `tap()` → `NosfyTap`, `paillette()` →
`NosfyPaillette`. Le reste — fondu d'entrée 1,5 s, sortie 1,2 s, `.ambient`, 18 % — est
déjà écrit et reste.

---

## 5. Ce qu'on mesure avant de lui faire écouter

- **−24 LUFS** intégrés, crête vraie < −6 dBFS (`ffmpeg -af ebur128`).
- **La couture** : RMS des 50 ms autour de 0 s et de 24 s identiques à 0,5 dB près.
- **Le spectre** : rien au-dessus de 8 kHz (les cristaux au casque deviennent des
  couteaux à 12 kHz), et l'octave du bourdon présente à 110 Hz.
- **Deux écoutes** : le haut-parleur de l'iPhone ET le casque — ce n'est pas le même son.

---

## 6. Trois variantes, parce qu'un goût ne se décrit pas

Le script prend un profil, et l'app un banc `-nosfyTheme <nom>` pour les comparer **sur
le téléphone**, sans rebuild :

| variante | ce qui change |
|---|---|
| **A · chaude** | la recette ci-dessus telle quelle — dorien, cristaux de bol, air haut |
| **B · cristal** | 11 éclats au lieu de 7, traînes plus longues, pad −3 dB — plus « magique » |
| **C · brume** | 4 éclats, l'air à −26 dB, le bourdon qui respire sur 8 s — plus « discrète » |

Aucune des trois ne descend sous 110 Hz en force, aucune n'a d'impact : le « flippant » du
splash est exclu **par recette**, pas par réglage.

Trois fichiers de 400 Ko, un tour d'écoute, et on garde une.

**Si tu préfères un morceau à toi** (Artlist, Epidemic, une compo) : on ne synthétise
rien, on applique la loi du recut de `recuit_theme.sh` — couper dans la source, jamais
l'écraser, mesurer la forme au RMS, caler.

---

## 7. L'ordre

| rang | geste | mesure |
|---|---|---|
| ① | `theme_nosfy.py` : les trois variantes + les deux bruits | LUFS, crête, couture, spectre |
| ② | `NosfySon` : les nouveaux noms + le banc `-nosfyTheme` | — |
| ③ | build, pose, **tu écoutes les trois** — haut-parleur puis casque | ton verdict |
| ④ | on garde une, les deux autres sortent de `Woop/Sounds` | poids de l'app |

**Ce qui attend en parallèle, déjà écrit et pas encore posé :** la bête plus petite et plus
fondue (recuite : flancs, haut 12 %, bas 28 %, gain 0,88), le seuil sans « Quelqu'un vous
attend » (« Dans quelle langue **dois-je** vous parler ? »), et la phrase après la langue
(« Nous nous comprenons. J'ai trois questions pour vous. »). Un build les pose quand tu veux.

---

## LA FIN — la musique du projecteur (13-09, nuit)

**Ce qui est resté :** D · touches (piano électrique, `NosfyTheme.m4a`, 50 %) pour tout le
film. A/B/C (bourdon + cristaux) refusés — « comme le splash ».

**Le premier jet de fin, F · fête (`theme_nosfy2.py`) — REFUSÉ : « horrible, on dirait un
truc chinois ».** Diagnostic : ce n'est pas la joie, c'est l'instrument. La corde pincée
(Karplus-Strong, l'instrument des « perles ») jouée en **arpèges qui montent** sur des accords
à neuvièmes, avec de la réverbération, c'est un **guzheng** — timbre, geste et gamme (un
arpège de maj9 est presque pentatonique). Loi : **plus aucune corde pincée dans le film.**

**La deuxième proposition (`theme_nosfy3.py`), deux variantes, aperçus envoyés à −16 LUFS :**

| | tempo | accords | ce qui fait la joie | ce qui l'empêche d'être princesse ou chinoise |
|---|---|---|---|---|
| **G · ÉLAN** | 100 BPM, 8 mesures = 19,2 s | I·V·vi·IV (A · E · F#m · D) | une nappe de scies désaccordées dont le filtre **s'ouvre** à chaque accord ; le piano électrique de D en frappes sur le temps ; basse ronde en noires ; kick feutré sur chaque temps ; souffle sur les contretemps ; le **pompage** discret de la nappe sous le kick (0,70) ; 2e moitié : l'octave au-dessus, loin | aucune corde, aucun arpège ; pas de mélodie ; des septièmes partout ; la scie filtrée est un timbre de keynote, pas de conte |
| **H · SOLEIL** | 84 BPM, 8 mesures = 22,9 s | I·IV·V·I (A · D · E · A) | des **cuivres de synthèse** (scies, vibrato qui n'arrive qu'après 0,4 s) qui gonflent 0,6 s sur chaque accord, deux mesures chacun ; le piano en accords **brisés avec la septième** ; basse et kick sur 1 et 3, caisse claire feutrée sur 2 et 4 ; plus lent, plus large | même loi ; la septième dans le brisé casse la pentatonique ; la caisse claire est un souffle 1,5–7 kHz, pas un claquement |

Commun : scies **additives** (harmoniques sous 11 kHz, jamais de repliement), réverbération
courte sur l'harmonie seule (la basse et le kick restent secs), bande à 9 kHz, largeur
stéréo 0,14–0,16, crête −3 dB, boucle exacte repliée. ⚠️ Piège payé : `int(t·sr)` tronque
et la gaine de pompage voyait un `x` négatif → `x**1.6` = NaN → un WAV de 19 ko à moitié
mort ; `np.clip` avant la puissance.

**À faire quand elle a choisi :** master −24 LUFS → `Woop/Sounds/NosfyFin.m4a` (même nom,
`NosfySon.fete` inchangé), F sort de `tools/porte/theme/`, build, pose, son verdict au
haut-parleur du téléphone.
