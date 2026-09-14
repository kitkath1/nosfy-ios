# LE FOYER — LA HOME QUAND UNE SÉANCE EST EN COURS (dicté par Kathryn le 05-09)

> **Rien n'est codé. Rien ne sera codé avant que tu aies tranché le §1.**
>
> Sa demande, ses mots : « tu vas faire un refacto de la HomePAGE quand une session
> est en cours, un écran magnifique à la Apple » · « un écran quasi full noir avec
> notre navigation » · « un texte en blanc et gris, il bouge en continu comme une
> IA ? » · « en dessous on retrouve des éléments de design de la pastille de
> navigation » · « on a le mot *Choisissez un exercice* si le user n'a pas lancé un
> exo (mais je crois que dans tous les cas c'est ça) » · « le bouton Reprendre ça
> mène à la page exercice ? » · « il faut un bouton Terminer » · « faut réfléchir où
> il peut voir le détail, l'overlay avec le détail de la séance et morphisme ? » ·
> « en dessous de la page card, toujours la même structure, tu mets les flammes
> légères (celles de la pastille notifications / overlay) et celle-ci devient plus
> claire quand on augmente dans le temps ou les séries, c'est plus chaud ! » ·
> **« quand on arrive sur la home, une animation de transition avec la pastille qui
> se morphe pour transformer la home, très important, comme si elle venait puis
> morphisme de la page, on la voit grossir »** · **« CET ÉTAT DE LA HOME EST
> UNIQUEMENT QUAND LA SESSION EST EN COURS, ON VOIT LES WIDGETS EN SUPER BLUR, UN
> PEU VOLANT AUSSI, COMME DANS LE SCREENSHOT »**.
>
> **Méthode.** Site de doc lu (`docs/site/content/serveur.ts` · `briques.ts` ·
> `mesures.ts`) : **aucune brique ne couvre cet écran** — ce chantier est purement
> vue/geste, zéro migration, zéro fonction serveur, zéro site d'appel. Une seule
> brique vise la home : `b-deux-nombres` 🔴 (« la home recompte les pièces côté
> client »), et **sa preuve est périmée** — elle pointe `HomeNuit.swift:2373-2380`
> alors que l'appel `CoffreFortPurse.coins(doneSeries:)` vit à `:2470-2474`. Corrigé
> dans le commit du J5 (§10).
>
> ⚠️ **Une autre session travaille dans cet arbre** (fluidité nav/pilule,
> `SondeVol`, l'appui long du galet). Tous les hunks chez elle sont marqués
> **POINT DE COUTURE** au §9 : décrits, pas écrits, avec un défaut sûr.

---

## §0 · CE QU'ELLE A TRANCHÉ — et ce que le code en dit

| sa phrase | ce que le code dit (vérifié) | verdict |
|---|---|---|
| « quasi full noir avec notre navigation » | La `NavBande` vit au **châssis** (`WoopApp.swift:1515-1544`), pas dans la home. Elle ne saura jamais que le Foyer existe. | ✅ gratuit |
| « les flammes de la pastille » | C'est **`BraisesVague`** (`PiluleVagabonde.swift:92`) : UN `Canvas`, N colonnes, UN flou, `plusLighter`. Un composant, deux clients (mini-pastille `:989`, grand player `:1385`). Elle a une entrée **`force`** qui pilote déjà hauteur ET opacités (`:127-144`). | ✅ existe |
| « plus clair / plus chaud » | `force` fait le « plus clair ». La **teinte** manque — mais elle est cuite ailleurs : `TapisBraise.paliers` (`TapisScene.swift:161-169`), 7 paliers en progression **géométrique** (×1,17 à ×1,46). | ⚠️ 6 lignes à coudre |
| « un texte blanc et gris qui bouge comme une IA » | Existe déjà en deux exemplaires : `InviteAnimee` (`PiluleVagabonde.swift:167`, dégradé blanc qui traverse « Choisissez un exercice » en 2,6 s à 20 Hz) et le `.mask` **permanent** de `PhraseVue` (`HomeNuit.swift:525-530`). | ✅ existe |
| « les éléments de design de la pastille » | Tous nommés : le chrono (`WoopApp.swift:1123-1131`), le ticket papier `TicketSeries` (`PiluleVagabonde.swift:211`), l'invite, le médaillon stop, les braises, le rayon `NotifGeo.rayon` = 28. | ✅ existe |
| « il faut un bouton Terminer » | `DepartEtat.shared.pauseOuverte = true`. `StopCardHote` est **déjà monté à la racine** (zIndex 13, `WoopApp.swift:1399-1418`), reçoit déjà `series:`/`gain:`/`duree:`, son slider appelle déjà `terminerSeance()` (`:478`). | ✅ zéro plomberie |
| « le screenshot avec les widgets en super blur » | **Ta capture est un ÉTAT RÉEL de l'app, pas une maquette** — voir §7. | 🔴 et c'est le régime qui chauffe |

---

## §1 · CE QU'IL ME RESTE À TE DEMANDER — 5 décisions, rien ne part sans

**D1 — « ON LA VOIT GROSSIR » : tu l'as refusé deux fois le 04-09.** C'est gravé
dans le code, mot pour mot : « je veux pas que ça grandisse, c'est horrible »
(`PiluleVagabonde.swift:1396`) et « il grossit, c'est horrible » (`:1405`), et le
châssis en a fait une loi : « il MONTE du bas, rien ne grandit »
(`WoopApp.swift:1053-1055`). Ce refus portait sur **pastille → player**. Ta demande
d'aujourd'hui porte sur **pastille → page d'arrivée**, et ici **rien n'est mis à
l'échelle** : c'est une *fenêtre de découpe* qui s'agrandit sur un contenu déjà
posé à sa taille finale — aucun glyphe ne s'étire. Je crois que ce n'est pas la
même chose. **Je ne le décide pas : c'est le J1, montré SEUL, en film, avant qu'une
autre ligne soit écrite.** *(défaut si tu dis non : la même forme figée + un fondu
de 0,42 s — une ligne.)*

**D2 — « SOUS LA PAGE CARD » N'EST PAS UNE ZONE VISIBLE.** La card va bord à bord
(marges 0) et son `.padding(.bottom, 50)` est **intégralement occupé par la nav**
(`PageCard.swift:291-296`). Une flamme posée strictement dessous ne se verrait que
derrière la nav. → **les flammes seront DANS la card, arête basse collée à sa
robe** : même lecture (« la lumière vient du bas »), zone réellement visible, coins
30 respectés. *(défaut : dedans. Un barreau `-foyerDebord` te montre l'option
débordante côte à côte, sur capture — je ne te refuse pas ta phrase par un
paragraphe.)*

**D3 — LA LANGUE.** La phrase de la home est en **anglais** par ton verdict du
22-08 (« le mélange se voyait ») : « Alright Kathryn, / you've been at it / 24
minutes / so far. » (`HomeNuit.swift:343-359`). Ton brief d'aujourd'hui est en
français. Les deux ne peuvent pas cohabiter sur le même écran. *(défaut : je garde
l'anglais, comme le reste de la home.)*

**D4 — LES WIDGETS EN SUPER BLUR : d'où vient la lumière ?** Deux hypothèses, une
capture chacune, avant toute ligne (§7). *(défaut : je fais les deux captures au
J0 et je te les montre côte à côte.)*

**D5 — PENDANT UNE SÉANCE, LE CHEMIN RESTE-T-IL ATTEIGNABLE DEPUIS LA HOME ?** La
`CardRoute` porte **l'unique porte du chemin** (`CardRoute.swift:172-176`,
`HomeNuit.swift:3428-3435`), et son `|| enSeance` (`:3413`) existe exactement pour
qu'elle survive à la séance. Si le Foyer la remplace, le chemin n'est plus
atteignable depuis la home tant qu'une séance tourne. **La régression a déjà été
payée deux fois** — je ne la reprends pas en silence. *(défaut : je garde une porte
tapable, nette, aux cotes de la route, au-dessus du flou.)*

---

## §2 · L'ÉTAT DES LIEUX — ce qui est vrai aujourd'hui, lu ligne à ligne

| pièce | où | verdict |
|---|---|---|
| La home EST `HomeNuitPage` | `WoopApp.swift:1173` | ✅ — ⚠️ le commentaire `HomeNuit.swift:1878` (« l'onglet Accueil monte toujours `HomeAuroraView` ») **MENT**, il date d'avant |
| `enSeance` | `HomeNuit.swift:1938`, dérivé du `@Query endedAt == nil` (`:1928`) | ✅ une seule machine à états, la base |
| Ce qui change en séance | phrase réécrite · CardRoute en mode séance · invite/fumée/tirage démontés · lune absente | ✅ court, et c'est tout |
| Le ruban `BordSeance` | mesuré **60,1 → 9,3 img/s** sur ton iPhone 15 → **retiré de l'app** par la session parallèle (arbre de travail) | 🔴 mort, et son analyse tient (`tools/home-v2/ANALYSE-RUBAN-SEANCE.md`) |
| La rangée de widgets | `if verreMonte, net < 0.995` (`HomeNuit.swift:3336`) | 🔴 **voir §7 — la garde ne mord PAS en séance** |
| `matchedGeometryEffect` | 2 appels, tous deux pilule ⇄ île, dans des branches **mutuellement exclusives**, aucun `isSource: false` | 🔴 **le dépôt n'a AUCUN morph natif fonctionnel** — la maison « anime à la main » (`ExerciseDetailView.swift:1437`) |
| « exercice courant » | **n'existe pas** : ni `Workout` ni `LoggedExercise` ne le mémorisent (`Models.swift`) | 🔴 voir §5 |
| `-stopOuvre` | déclaré (`StopCard.swift:464`), **aucun lecteur dans tout `Woop/`** | 🔴 le lancer ne fait rien |
| `JewelTabBar` | `barreBijouVisible` exige `selection != .exercises && != .profile && != .home` — il n'existe QUE ces trois onglets | 🔴 **jamais montée** : l'appui long du galet est une porte MORTE à l'écran |
| `main` seul | `onPlayHold:` appelé au châssis (`WoopApp.swift:1303`), absent de `HEAD` | 🔴 **main ne compile pas seul** — piège déjà connu, ne jamais `stash` ce hunk |

---

## §3 · L'ÉCRAN — l'anatomie, et le repère qui a fait tomber trois propositions

⚠️ **LE PIÈGE DES COTES, ATTRAPÉ AVANT D'ÊTRE PAYÉ.** La racine de `PageCard` vit
**DANS LA ZONE SÛRE** (`PageCard.swift:95-98`, verdict T1 « le chevron coupé »). Sur
un iPhone 15 : `Hs = 852 − 59 − 34 = 759`, et le contenu de page s'arrête à
`759 − 50 = 709` **en local**. Coter depuis `UIScreen.height − 50 = 802` est faux de
34 à 93 pt — un « Terminer » posé à 756 tomberait **sous l'arête de la robe, clippé,
invisible**. → **toutes les cotes sont prises depuis un `GeometryReader` posé DANS
le slot `page` : `B = geo.size.height`, jamais une constante.**

De haut en bas, une addition de **six vues nommées** (loi n°1 — le mur du
type-checker) :

⚠️ **Et je viens de refaire la faute en écrivant ce plan** : ma première table posait
« Terminer » à `1,05 × B` — c'est-à-dire **sous l'arête de la robe**, exactement le
défaut que le paragraphe ci-dessus dénonce. Toutes les cotes ci-dessous sont des
**fractions de B, strictement < 1**, et elles se vérifient au juge de cotes du J2
contre l'**arête réelle**.

| y (fraction de B) | pièce | détail |
|---|---|---|
| 0 → 0,05 | rien | du noir. C'est la moitié de la beauté. |
| 0,05 → 0,55 | **la phrase** | `PhraseVue` telle quelle, 4 fragments, Inter 30 semibold, x 28, clair/sourd/clair/sourd. **Elle ne bouge pas d'un point** : son bas est le raccord mesuré `DepartCine.courseTexte = 441`. |
| 0,62 | **le signe** | point blanc 6 pt + « SÉANCE EN COURS », Inter 10,5, tracking 1,6, blanc 0,52. Respire en **opacité seule**, 2,9 s, `repeatForever` posé une fois (école `BadgeSetsNeon`, `PageCard.swift:481-495`) — **pas** la `TimelineView` 20 Hz de `CardRoute`. |
| 0,70 | **le chrono** | 72 pt thin, `monospacedDigit`, tracking −2, blanc 0,92, **aucune ombre**. UNE `TimelineView(.periodic(by: 1))` **scopée au seul `Text`**. |
| 0,80 | **le ticket** | `TicketSeries("N SETS")` 104 × 34, rotation −4°. **C'est la porte du détail.** |
| 0,89 | **la capsule** | 246 × 56, rayon **28** (`NotifGeo.rayon` — la famille de la pastille), fond mat `white 0.055`, liseré angulaire **FIXE** (le halo vient du feu derrière, pas d'un `.blur` ni d'un verre). Texte : `InviteAnimee`. |
| 0,965 | **Terminer** | du texte, pas un bouton. Inter 13, blanc 0,38, cible 160 × 44. |

**Le chrono, deux corrections que personne n'avait vues :** la recette de la
pastille **n'a aucun format heures** — elle rend `s/60` brut, donc « **84:12** »
après 1 h 24. Le `H:MM:SS` est du **code neuf**, à écrire **une seule fois** dans un
helper partagé (pastille + grand player + Foyer, sinon trois formats qui divergent).
Et `monospacedDigit` ne suffit pas : le **nombre de glyphes change**, donc la
largeur saute. → capture de cotes obligatoire à **1:24:10**, pas seulement à 24:52.

---

## §4 · LE MORPH — « on la voit grossir »

**Le principe.** Un seul scalaire `naissance` 0 → 1, passé à une `Shape` **Animatable**
qui interpole le rect ET le rayon (28 → 30 bas / 0 haut), montée par un
`ViewModifier` qui reçoit l'arbre **déjà construit**. Le contenu est posé à sa taille
**finale dès la première image** : c'est la fenêtre de découpe qui grandit. **Zéro
`scaleEffect`, zéro frame animée, zéro relayout** — la loi « ce qui bouge par image
ne change jamais une taille », tenue par construction. Trois précédents maison :
`StoryPortal` (`StoryFlow.swift:543-622`, le seul « ça devient la page » en
production), `FormeCardExos` + `CarteLevee` (`ExercisesView.swift:254-298`),
`CardMorph` (`CalLab.swift:929-1000`).

**Quatre corrections qui viennent des contradicteurs, et chacune aurait tué le morph :**

1. ⚠️ **LE MORPH SERAIT NEUTRALISÉ SI ON LE MONTE DANS LA PAGE.** `pageEnCard` porte
   **trois `.animation(_:value:)`**, dont un sur **`value: enSeance`** — la valeur
   même qui déclenche le morph (`PageCard.swift:297, 300, 307`). Et le dépôt écrit à
   cet endroit précis qu'« un `.animation(value:)` **NEUTRALISE** le `withAnimation`
   ambiant pour son sous-arbre » (`:301-306`, la parade au snap de 52 pt). La courbe
   voulue serait remplacée par `easeInOut 0,25`. → **le morph se monte en `.overlay`
   sur la `PageCard`**, au niveau des satellites (`HomeNuit.swift:2371-2406`), qui
   sont appliqués APRÈS et échappent aux trois `.animation`.
2. ⚠️ **LE MORPH NE SE VERRAIT JAMAIS SI ON LE DÉCLENCHE SUR `enSeance`.** Dans le
   flow réel, la séance s'ouvre depuis le chemin puis l'app **change d'onglet 0,05 s
   plus tard** (`HomeNuit.swift:4256-4276` → `onRoute(.exercises)`). Le morph se
   jouerait derrière un onglet caché. Pire : au moment où `enSeance` bascule, la
   pastille **vient d'apparaître** — elle n'a jamais été à l'écran, donc « elle
   grossit » raconterait un geste que tu n'as pas fait. → **on déclenche sur « la
   home devient VISIBLE alors qu'une séance tourne »** (`enSeance && !ongletCache`),
   **une seule fois par séance**, par jeton. C'est la seule formulation où le rect de
   départ correspond à une pastille que l'œil a vraiment vue — et c'est exactement ta
   phrase : « quand on **arrive** sur la home ».
3. ⚠️ **UNE LIGNE AJOUTÉE DANS `onChange(of: enSeance)` NE S'EXÉCUTERAIT JAMAIS.** Ce
   handler a **trois sorties** (`HomeNuit.swift:2650-2681`) : `guard encore else {
   rendreLaHome(); return }`, une branche `if tiroirOuvert { … return }`, puis un
   `guard tirage == 0 … else { return }`. Les deux départs réels passent par la
   branche qui **retourne**. → l'écriture se fait **en tête du handler**, avant tout
   `guard` : un hunk de trois lignes, pas « une ligne ».
4. ⚠️ **LE MASQUE DOIT MOURIR À L'ARRIVÉE.** `PageCard` clippe **déjà**
   (`PageCard.swift:290`) ; un second clip plein écran laissé en place paierait une
   passe de composition **pendant toute la séance** pour ne rien découper — la faute
   exacte de 693f0ee. → `if p < 0.999 { .mask(...) }`.

**Le rect de départ.** Personne ne le publie (`PiluleEtat` n'a que `yRatio`,
`dessin`, `dansIle`). On le **recalcule** depuis les mêmes constantes physiques —
avec **une seule conversion de repère** : la page publie son rect une fois par
apparition (`onGeometryChange(for: CGRect.self) { $0.frame(in: .global) }`) et on
**soustrait** son origine. ⚠️ Jamais mélanger `UIScreen` (physique, où vit la
pastille) et la zone sûre (où vit la page) dans une même formule : **59 pt d'écart
silencieux**. ⚠️ Et `frame(in: .global)` **INCLUT déjà l'offset des ancêtres**
(`PageCard.swift:243-247`) — piège déjà payé. **Branche `dansIle`** : si la pastille
est rangée dans la Dynamic Island, la page naît de `IleGeo` (126 × 37,3, haut 11),
pas d'un rect fantôme à `yRatio`.

**Interruptions.** Changement d'onglet, clôture, doigt à 0,2 s, **et app mise en
fond** (`scenePhase != .active` → `naissance` saute à 1 dans une `Transaction` sans
animation : un morph repris vingt minutes plus tard est un défaut). Plus
`.allowsHitTesting(naissance > 0.98)` — un masque déplace les pixels, **pas la zone
tactile** (payé deux fois).

**⚠️ Le morph ouvrira sur du VIDE si on ne fait que ça.** La pastille est démontée,
un trou s'ouvre — et « comme si la page naissait d'elle » ne se voit pas. **Greffe
non négociable** : faire **voyager les objets** de la pastille (mini-card, ticket,
chrono) vers leurs places, et surtout **le médaillon stop qui RÉTRÉCIT**. C'est la
réponse honnête à ton « il grossit, c'est horrible » : **quelque chose rapetisse
pendant la course, donc ce n'est pas un zoom, c'est un dépliage.**

---

## §5 · LES TROIS QUESTIONS QUE TU AS POSÉES — mes réponses, et elles sont des CONSTATS DE CODE

**« Choisissez un exercice, je crois que dans tous les cas c'est ça » → TU AS RAISON,
et il n'y a donc PAS de bouton « Reprendre ».**
Ce n'est pas un raccourci, c'est ce que disent les données :
- **aucun `LoggedExercise` n'est mémorisé comme courant** — ni `Workout` ni
  `LoggedExercise` ne portent la notion (`Models.swift`) ;
- **ressortir d'une fiche et y revenir crée un SECOND `LoggedExercise`**
  (`ExerciseDetailView.swift:2468`, « un passage = un bloc », voulu) — donc un bouton
  « Reprendre » **ferait mentir le compteur de séries, donc l'argent** ;
- toutes les portes de retour existantes aboutissent déjà à la **LISTE**
  (`selection = .exercises`), jamais à une fiche.

Écrire « Reprendre » serait un mensonge : le bouton ne reprend rien, il fait choisir.
**Tu gardes ton cercle de lumière, tu changes de mot.** *Ce qui le ferait dire
« Reprendre » un jour : `Workout.exerciceCourantID` + la réutilisation du bloc au
lieu d'en créer un second. C'est un chantier de MODÈLE, pas de vue — il est nommé
ici, il n'est pas dans ces jalons.*

⚠️ **Nuance mesurée, à ne pas se raconter** : la pastille lit
`a.orderedExercises.first` (`WoopApp.swift:1101`) — **le PREMIER bloc, jamais le
courant**, et il ne redevient jamais `nil`. Donc « Choisissez un exercice » ne
réapparaît **plus jamais** après la première série ancrée. Si tu veux l'invite « dans
tous les cas », c'est **un choix assumé** (on n'affiche jamais de nom d'exercice),
pas l'état naturel du code.

**« Où voit-il le détail ? Un overlay avec morphisme ? » → AUCUN OVERLAY NEUF. Il
existe déjà, il est validé, il est à un doigt.**
Tap sur le **bloc-chrono entier** (cible ≈ 393 × 148, dix fois le ticket ; le ticket
reste la poignée visuelle) → `ouvrirGrandPlayer()` (`WoopApp.swift:1057-1062`) →
`GrandPlayer` : tête fixe, partition `SlateListe` scrollante et dépliable, pied
« Page exercices » + médaillon stop. **Il MONTE du bas, rien ne grandit**
(`WoopApp.swift:1053-1055`) — et c'est délibéré : *le seul endroit où tu as vu
grossir, tu as dit non deux fois.* Trois raisons de code, pas de goût : (1)
`SlateListe` est LE composant de partition, déjà partagé par l'ardoise, le player et
la story — une seconde serait un second endroit à corriger ; (2) elle porte déjà son
`ScrollView` + un `GeometryReader` : emboîtée, elle reçoit une hauteur nulle et
**disparaît** (l'écran noir du 04-09) ; (3) un overlay monté « au cas où » serait
**rendu même caché** — le piège du rideau.

**« Il faut un bouton Terminer » → `DepartEtat.shared.pauseOuverte = true`, et rien
d'autre.** Zéro chemin de clôture neuf. ⚠️ Et c'est la **quatrième** porte vivante,
pas la cinquième : celle de l'appui long du galet passe par `JewelTabBar`, **jamais
montée** (§2).
⚠️ **L'état « 0 série » doit être écrit dans le plan** : toute la queue festive est
sous `guard gain > 0` (`WoopApp.swift:537`), et `gain = seriesPayantes ×
piecesParSerie`. **Une séance sans une seule série cochée se clôt en SILENCE** — pas
de story, pas d'annonce, pas de booster. C'est exactement l'état par défaut d'un
écran de séance qui vient de naître. Sinon, le premier verdict téléphone sera « j'ai
tapé Terminer et il ne s'est rien passé ».

---

## §6 · LE FEU ET LE TEXTE

### Les flammes — `BraisesVague`, telle quelle, plus une entrée de teinte

**Deux causes, deux leviers, jamais mélangés** (ta phrase dit « le temps **ou** les
séries ») :
- **les MINUTES portent l'amplitude** → `force` (elle pilote déjà hauteur ET les
  trois opacités du dégradé, `PiluleVagabonde.swift:127-144`) ;
- **les SÉRIES portent la teinte** → `chaleur`, indexée sur `TapisBraise.paliers`
  (`TapisScene.swift:161-169`), 7 paliers, progression **géométrique** ×1,17→×1,46
  (une progression arithmétique faisait lire les trois derniers paliers comme un
  seul — mesuré au tapis).

Fonction **pure**, appelée **sur événement** (changement de `seriesPayantes`, boucle
des minutes qui existe déjà `HomeNuit.swift:2643-2649`), **jamais dans un corps de
vue**. La transition entre paliers s'interpole **dans le Canvas** sur `tl.date`
(`sstep` 0,25 s pour monter, 0,80 s pour descendre — patron `TapisScene.swift:317-330`)
: **aucune horloge de plus**.

**La rampe — la loi anti-brun tenue par construction** : `R = 1,00 toujours, seul le
VERT bouge, B = vert × 0,28` (`BordSeance.swift:135-137, 179-182` : « une braise dont
on baisse le rouge vire au brun — faute payée trois fois »). À 0 série le feu **rentre
dans ses racines** (le rouge le plus profond) : l'état bas se dit par la
**luminance**, jamais par une désaturation — il n'y a pas de cendre grise dans cette
maison.

⚠️ **Ce qui ne varie JAMAIS avec la chaleur** : `partBasse`, `colonnes`, la `frame`.
Ce sont des géométries de layout.

⚠️ **LE RAPPORT FLOU/HAUTEUR EST UNE LOI, PAS UN GOÛT.** La vague que tu as validée
deux fois fait 11/69 = **0,16**. À 0,33 (le double), treize colonnes floutées ne se
lisent plus comme des colonnes : c'est une nappe uniforme. → on **garde le rapport de
la pastille**.

⚠️ **UN SEUL FEU À L'ÉCRAN.** La vague de la pastille tourne **déjà** en permanence
pendant toute la séance (`force: 0.42`, 9 colonnes, flou 11, 15 Hz —
`PiluleVagabonde.swift:989`). Ajouter une seconde vague sans figer la première, c'est
**deux Canvas + deux flous + deux `plusLighter` par image**. Aucune proposition ne
l'avait compté. → règle explicite : tant que le Foyer occupe la page, la pastille est
**démontée** (ce qui règle les deux problèmes d'un coup).

⚠️ **ET LE COÛT PROPRE DE `BraisesVague` N'EST CHIFFRÉ NULLE PART DANS LE DÉPÔT.**
Aucune sonde `-fps` publiée sur la pastille seule. Toute comparaison de surfaces est
une **opinion habillée en calcul** — et le dépôt a mesuré que le coût n'est pas le
dessin (« le shader a lagué aussi »). → **la mesure manquante se produit AVANT le
chantier** (J−1, §10).

**Le repli, documenté** : la voie vidéo est déjà en production —
`home-fond-flamme.mp4`, collé par son arête basse, `plusLighter`, bascule vers
l'image de pose quand l'onglet est caché (`ProgressPage.swift:220, 232-251`). Une
couche `AVPlayerLayer` ne coûte rien. On y perd la modulation continue.

**Et ta règle du 04-09 tient toujours** : « une flamme = une série **ACCOMPLIE**,
jamais une promesse » (`FlammeJauge.swift:1239-1249`). Elle vise les **glyphes**
comptables (`FlammesRow`, 4 max puis « +N ») ; la vague continue, elle, dit la
chaleur de ce qui est **fait** (minutes écoulées, séries tombées) — les deux règles ne
se contredisent pas, elles se renforcent.

### Le texte vivant

⚠️ **LA TECHNIQUE ÉVIDENTE NE MARCHE PAS.** Animer les `startPoint`/`endPoint` d'un
`LinearGradient` sous `withAnimation` : les points d'un dégradé sont un paramètre de
**ShapeStyle**, pas une géométrie interpolée — **le masque sauterait au lieu de
glisser**, et les deux seuls balayages du dépôt le confirment (`InviteAnimee`
recalcule ses stops à 20 Hz ; `BarreBlancheAnimee` déplace une vue en `.offset`).

→ **La forme juste** : un dégradé **FIXE** à 5 stops (0,52 · 0,52 · 1,00 · 0,52 ·
0,52) dans un cadre **2,2× plus large** que le bloc, déplacé par un simple
`.offset(x:)` sous **UN** `withAnimation(.linear(4,6).repeatForever)` posé au
`onAppear` et **réarmé** par `onChange(of: vivant, initial: true)`, sur une **feuille
isolée** — école `BadgeSetsNeon` (`PageCard.swift:434-497`), avec son caveat écrit :
*un `repeatForever` posé par `withAnimation` se fait avaler quand le parent est
ré-évalué.* **Porte obligatoire** : `vivant = enSeance && !ongletCache &&
!reduceMotion`.

**Refusé** : la crête blanche saturée qui balaye (c'est du néon), la lettre-par-lettre
(c'est du cartoon), le `.blur` animé (27 img/s l'objet).

**Ce qu'il DIT** — et c'est ça, « une IA » : pas un effet, **une phrase qui sait où
on en est** et qui se réécrit sous les yeux, au même endroit, sans qu'on ait rien
tapé. Contrat verrouillé : **exactement 4 fragments** (3 ou 5 lignes déplaceraient le
bas de 38 pt et casseraient le raccord `courseTexte = 441`), échangés **au sommet du
flou** donc invisibles (`muer()`, `HomeNuit.swift:1976-1981`). Deux déclencheurs
nouveaux : franchissement d'un palier de séries, palier de minutes.

> « Trois séries / de faites. / Le feu / a monté d'un cran. »
> « Une heure / tout rond. / Tu peux / t'arrêter là. »

⚠️ La source des mots est un `@Observable` de fragments **déjà calculés**, jamais
dérivés dans un body — et **pas** `SemaineStats.calcule`, qui **filtre les séances non
terminées** et ne peut donc rien nourrir ici.

---

## §7 · LES WIDGETS EN SUPER BLUR — et la découverte qui explique ta capture

**🔴 TA CAPTURE EST UN ÉTAT RÉEL DE L'APP, ET C'EST LE RÉGIME QUI CHAUFFE.**

La garde `if verreMonte, net < 0.995` (`HomeNuit.swift:3336`) porte sur le **PULL**,
pas sur la séance. En séance il n'y a pas de geste de tirage, donc **`net = 0` : la
garde ne mord pas**. Et `verreMonte` naît à **`true`** (`:2053`) ; il n'est mis à
`false` que par `lancer()` (`:3985`). Donc : **application relancée alors qu'une
séance est ouverte → `verreMonte = true` → les deux widgets en verre natif brûlent
pendant toute la séance, au-dessus de deux calques vidéo vivants.** C'est exactement
ce que tu as photographié.

Deux conséquences, l'une bonne, l'autre coûteuse :

**LA BONNE.** La lumière de ta capture ne vient **pas** des cards : elle vient de la
**vidéo de fond qui passe à travers leur verre**. Le code le dit noir sur blanc :
« Presque noire en mode plein, mais **ABSENTE en mode verre** : un fond opaque
derrière un verre, c'est un verre posé sur un mur — il ne peut rien réfracter »
(`WidgetsCards.swift:251`). En mode verre la card est un **trou**
(`fill(white 0.012)` à `opacity 0`, bezel absente). **Sans verre, c'est une plaque
opaque à 0,014 de blanc**, dont le point le plus clair vaut 0,157 — floutée, elle
donne un **voile gris à 10 %**, et elle POSE un rectangle noir là où la vidéo passait
seule : la home devient **plus sombre** qu'avant, pas plus lumineuse.

→ **« Enlever le verre pour pouvoir flouter fort » produit l'INVERSE de ton
screenshot.** C'est le défaut fatal que les deux contradicteurs ont trouvé
séparément, et je l'ai vérifié de mes yeux.

**LA COÛTEUSE.** Un flou posé sur du verre natif **empile deux passes** — le code
l'appelle « l'opération la plus chère de la page » et **plafonne le flou du tirage à
6 pt** pour cette raison (`HomeNuit.swift:3365-3372`). Tu demandes un **super** blur :
bien au-delà de 6.

**DONC : LA QUESTION SE TRANCHE PAR DEUX CAPTURES, PAS PAR UN AVIS** (D4). Au banc
`-homeSeance`, rangée montée en séance, flou 28, rien d'autre : ① `verre: true`,
② `verre: false`. Mesurées **sur les pixels CLAIRS**, jamais en moyenne de ligne (le
noir tire vers le beige). Si la lumière est bien le fond vu à travers le verre, tout
le raisonnement « sans verre » est à l'envers, et la vraie piste est un **régime
« nappe »** de `CardCorps` : bezel opaque supprimée (la vidéo passe), les deux lueurs
radiales remontées de 0,157/0,106 à ~0,45/0,30 — **la lumière se FABRIQUE**.

**Le « un peu volant »** : deux `offset` + une `scaleEffect` par nappe, périodes
incommensurables, `repeatForever` posé **une fois**, sur une **vue autonome qui porte
ses propres `@State`** — sinon, au remontage (changement d'onglet, ouverture du
player), `onAppear` réécrit une valeur **déjà égale**, SwiftUI ne voit aucun
changement, **et le vol reste figé pour le reste de la séance**. Plus un relancement
sur `willEnterForeground` (un `repeatForever` est retiré des couches en arrière-plan).

**Trois corrections non négociables, quel que soit le chemin :**
1. garder une **porte tapable, nette**, vers le chemin au-dessus du flou (D5) ;
2. monter le calque sur `enSeance || nappe > 0.001` — sinon la sortie est une **coupe
   franche** (le `if` disparaît dans la même mise à jour que l'animation) ;
3. ajouter `.opacity(RasantHorloge.iso ? 0 : 1)` comme **ses cinq blocs voisins**
   (`HomeNuit.swift:3304, 3378, 3445, 3491, 3639`) — sinon le calque pollue la sonde
   `-isoRasant` qui sert à juger la home, et **personne ne verra le biais**.

⚠️ **ET « FEUILLE AU FOND DU ZSTACK » N'EST PAS UNE PROTECTION.** Tout ce qui vit
dans le slot `page` est **dans la composition de la card**, au même titre que le
ruban : le diagnostic du ruban n'était pas « il est en overlay », c'était « il est
dans la composition d'une card qui contient une vidéo vivante et des panneaux de
verre ». **Seul le VIDAGE de la card achète quelque chose** — et `fondPage(e)` (la
`GrandeCardVideo`, **deux lecteurs AVPlayer**) est un **FRÈRE** de `mobilierScene`
(`HomeNuit.swift:2794` vs `:2828`) : un `if enSeance` posé dans le mobilier **ne la
touche pas**. Il faut **deux points de coupe, pas un**.

⚠️ **ET LA PASTILLE EST UN VERRE `.regular.interactive()` MONTÉ AU-DESSUS DE LA PAGE**
(`WoopApp.swift:1464`, zIndex 6). Poser des flammes à 12 Hz dessous, c'est lui faire
**re-capturer son backdrop douze fois par seconde** — le mécanisme exact accusé pour
le ruban, transposé un cran plus haut. C'est peut-être la **cause résiduelle** que le
relevé `-sansBord` n'a pas fait tomber. → barreau **`-sansPastille`**, le suspect que
personne n'a encore isolé.

---

## §7 bis · LA PASTILLE S'ALLÈGE, ET LA MATIÈRE SE PRÉCISE (dicté le 05-09)

Ses mots : « enlève sur la pastille les *11 sets*, laisse que dans le détail ! » ·
« enlève les flammes de la mini pastille : on a que l'animation qui rentre dedans et
basta » · « dans la mini pastille on a sous le nom de l'exercice : juste le timer de
la session et le nombre de rep / et basta, allège » · « c'est lourd » · « plus de
blur effet, on doit encore deviner un peu le texte derrière ».

**LA PASTILLE, APRÈS — trois lignes, et rien d'autre :**

| ligne | contenu |
|---|---|
| 1 | le nom de l'exercice (ou `InviteAnimee` s'il n'y en a pas) |
| 2 | le chrono de la séance |
| 3 | le nombre de reps |

Plus de `TicketSeries` (`PiluleVagabonde.swift:211`), plus de `BraisesVague`
(`:989`). **Seule reste l'animation d'entrée.**

⚠️ **CE QUE ÇA RÈGLE PAR CONSTRUCTION.** Le §6 listait « un seul feu à l'écran »
comme une règle à tenir à la main — la vague de la pastille tournait pendant toute la
séance, et personne ne l'avait comptée. En l'éteignant, la règle cesse d'être une
discipline : elle devient une **propriété**.

⚠️ **CE QUE ÇA COÛTE, ET QU'IL FAUT DIRE.** Le ticket était le seul endroit où le
**compte de séries** se lisait sans ouvrir le détail. Le nombre de **reps** ne le
remplace pas : ce n'est pas la même information. Si « où j'en suis » doit rester
lisible d'un coup d'œil, c'est une décision à prendre, pas un oubli à constater plus
tard.

⚠️ **POINT DE COUTURE.** `PiluleVagabonde.swift` appartient à la session parallèle :
ces trois retraits sont **décrits, pas écrits**.

**ET SUR L'ÉCRAN DE SÉANCE** — j'ai retiré le ticket là aussi. Le tap vivait déjà sur
**tout le bloc du chrono** (§5), le ticket n'en était que la poignée visuelle : la
porte du détail ne bouge pas. **À confirmer** : sa phrase disait « sur la pastille ».
S'il doit rester sur la page, il revient en une ligne.

**LE FLOU — le réglage, pas l'effet.** Plus fort que maintenant, mais **pas un
effacement** : on doit *encore deviner* le texte derrière. C'est le seul énoncé de ce
plan qui fixe une cible perceptive plutôt qu'un nombre — donc il se juge à la
capture. Le J0 (§11) pose désormais **trois rayons** en plus des deux régimes de
verre, et le bon est celui où **le chiffre d'un widget se devine sans se lire**.

---

## §8 · CE QUI N'EST **PAS** DANS CE PLAN

Les verdicts du 05-09 sur les **widgets / chambres longues** (le tour HIIT en scroll
horizontal, l'anneau de comparaison supprimé, « meilleur jour » + sticker flamme, la
règle « une séance n'est pas un récap semaine ») **ne sont pas de ce chantier** —
elle l'a précisé elle-même : « j'ai confondu la session ». Ils sont rangés entiers
dans **`tools/home-v2/VERDICTS-CHAMBRES-05-09.md`**, avec leurs deux pièges déjà
mesurés (la sonde de scroll constante qui ne rappelle jamais ; un flou par cercle =
27 img/s).

## §9 · LE CÂBLAGE — ce que j'écris, et ce que je ne touche pas

| fichier | quoi |
|---|---|
| `Woop/Views/Foyer.swift` | **NEUF** — tout le chantier : la page (six vues nommées), les cotes (depuis `geo`, jamais `UIScreen`), la fonction pure de chaleur, la `Shape` Animatable, les deux `ViewModifier`, l'`@Observable` (deux booléens), le banc. |
| `Woop/Views/HomeNuit.swift` | **modifié — 3 hunks** : ① `if enSeance` dans `mobilierScene` **ET** ② `fond: { if enSeance { Color.clear } else { fondPage(e) } }` (deux points de coupe) ; ③ `muer()` gagne deux déclencheurs. Fichier **propre** au `git status` du jour. |
| `Woop/Views/PiluleVagabonde.swift` | ⚠️ **POINT DE COUTURE** — 6 lignes sur `BraisesVague` (`var chaleur` + les deux stops chauds). **Une seule source de vague** : leur propre commentaire le dit (« deux vagues qui divergeraient ne seraient plus une famille »). *Repli si le lot n'est pas commité à temps : une vague locale marquée « à fusionner » — dette **visible**.* |
| `Woop/WoopApp.swift` | ⚠️ **POINT DE COUTURE** — trois lignes, **après leur lot** (ordre de commit : leur hunk `onPlayHold` d'abord, sinon `main` ne compile pas seul). ⚠️ Le drapeau de démontage de la pastille doit vivre **au châssis**, où `selection` est connu : `!(seanceOccupeLaPage && selection == .home)` — sinon la pastille disparaît **de toute l'app** pendant toute la séance, y compris de la fiche exo où elle est le **seul** accès au player et au stop. Défaut sûr : pastille **visible**. |
| `docs/screens/home-seance.md` | **NEUF** — la fiche qui manque (`docs/screens/` n'en a aucune pour la home ni pour la séance). Gabarit de `progress.md`. |
| `docs/site/content/briques.ts` | **une ligne** : corriger la preuve périmée de `b-deux-nombres` (elle pointe `HomeNuit.swift:2373-2380`, l'appel vit à `:2470-2474`). Puis `npm run artefact` **PUIS** `npm run verif`, puis republier au **même** lien. |

**Deux bugs latents trouvés en chemin — à corriger avant tout jalon qui promet « le
ticket ouvre le détail » :**
- 🔴 `SlateGroupe(id: le.exerciseID)` : **deux blocs du même exercice ⇒ deux rangées
  d'identifiant IDENTIQUE** dans le même `ForEach` (rangées fantômes, dépli qui
  saute). Trois sites (`WoopApp.swift:1086`, `StoryFlow.swift:136`,
  `SessionSlate.swift:208`). Les bancs ne peuvent pas le révéler : eux préfixent
  l'index. Fix : `id: "\(le.order)-\(le.exerciseID)"`.
- 🔴 `groupesDeSeance` **peut rendre un tableau vide** : la garde ne couvre que
  `lignes.isEmpty`, mais le `compactMap` jette toute ligne dont l'exercice est inconnu
  du catalogue. Et `GrandPlayer` fait `groupes[0]` — **crash d'index** le jour où on le
  rebranche. Fix : garde sur le **résultat**, et `groupes.first` partout.

---

## §10 · LES BANCS ET LA MESURE — le protocole vit dans le SKILL

⚠️ **`woop-performance` (`.claude/skills/woop-performance/SKILL.md`) est
l'autorité sur tout ce qui suit, et il est OBLIGATOIRE avant la première mesure.**
Il a été payé le 05-09 par une journée entière sur son iPhone 15. Je ne recopie
pas son protocole ici — je note seulement ce qu'il change **pour ce chantier**.

### Ce que le skill CORRIGE dans ce plan

1. 🔴 **LA VIDÉO EST INNOCENTÉE, MESURÉE.** Remplacer les deux calques du fond
   par une image fixe : **37 % contre 38 %** de processeur. Mon §7 et mon §9
   demandaient de démonter `fondPage(e)` en invoquant la chaleur — **cet argument
   est mort**. On démonte la vidéo parce qu'elle veut **« quasi full noir »**,
   pas pour gagner des images. Le hunk reste ; sa justification change.
2. 🔴 **LE VRAI COUPABLE EST LE VERRE : le quart.** Six verres natifs éteints :
   **37 % → 28 %**. Et « un verre posé **sur une vidéo** ne peut RIEN mettre en
   cache ». → **la décision D4 n'est plus seulement esthétique, elle est la plus
   chère de l'écran** : garder le verre des widgets en séance, c'est garder le
   poste n°1 de la chauffe, au-dessus d'une vidéo vivante.
3. 🔴 **REDESSINER POUR ANIMER COÛTE 3 À 8 FOIS PLUS.** Mesuré A/B, à cadence
   égale : `TimelineView` 20 Hz = **33-38 %** ; la même image en valeur animable
   + `repeatForever` = **4-18 %**. → Le point qui respire, le souffle du texte et
   le liseré de la capsule **n'ont pas le droit** d'être des `TimelineView` — et
   pour le liseré, le patron existe déjà : `LisereRespirant.swift` (on ne tourne
   pas la vue, on tourne **la peinture**, le contour posé en masque).
   ⚠️ La braise reste une exception **légitime** : un `Canvas` nourri du temps est
   le seul cas que le skill autorise. Mais elle doit alors battre sur le **pas
   commun** (`RythmeEcran.pas`, 20 Hz) — des horloges désaccordées s'ajoutent au
   lieu de se confondre (**37,5 % → 27,5 %** rien qu'en les alignant).
4. 🔴 **LA PORTE D'ONGLET EXISTE MAINTENANT.** `RythmeEcran.dort("home")`
   (`Woop/Views/RythmeEcran.swift`) remplace ma consommation directe de
   `\.ongletCache`. **Toute horloge neuve s'y branche**, sinon elle tourne
   derrière les autres pages pour rien.
5. ⚠️ **ET LE PIÈGE QUI VISE EXACTEMENT CE CHANTIER** (skill §6, point 9) :
   **une séance ouverte fausse toute mesure « au repos »** — elle tient les
   galets, la card route et la vidéo. Or *tout* ce plan se joue séance ouverte :
   aucune de ses mesures ne se compare à un relevé « au repos » pris ailleurs.

### Les bancs de ce chantier (vérifiés par moi)

- `-activeWorkout -skipAuth` sème une **vraie** séance (−8 min, 1 bloc, 1 série
  faite) ; `-activeWorkoutLong` en sème 6 (21 séries, 11 payantes).
  **Pas de `-demoData`** (il sème une séance ouverte qui persiste).
- ⚠️ **`-homeSeance` ne crée AUCUN `Workout`** : il force seulement `enSeance`.
  Tout écran qui reçoit un `Workout` est **injugeable** sous ce drapeau.
- ⚠️ **UNE SÉANCE DE BANC MEURT TOUTE SEULE** : la purge du lancement clôture en
  **silence** toute séance ouverte depuis plus de 3 h (`WoopApp.swift:1945-1976`).
  Un banc repris après le déjeuner juge un écran **hors séance** sans un mot.
  → relancer `-fermeSeances -activeWorkout -skipAuth` **à chaque tour**.
- ⚠️ **`-stopOuvre` ne fait rien** (déclaré, aucun lecteur). Le film « Terminer →
  StopCard » se joue au banc à vrais touchers, ou via `-clotureTest` (qui **saute
  la card**).
- **Tout nouveau moteur arrive avec son barreau** : `-sansFoyer`, `-sansSouffle`,
  `-sansFlammes`, et **`-sansPastille`** (le suspect que personne n'a isolé).

## §10 bis · CE QUI EST ÉCRIT AU 06-09 (rien commité)

`Woop/Views/Foyer.swift` — **NEUF** : `FoyerPage` (six vues nommées), `FoyerGeo`
(les cotes, **prises depuis la hauteur réelle du slot de page**, jamais depuis
`UIScreen`), `FoyerChaleur` (fonction pure, sept paliers géométriques),
`LueursFoyer`, `SouffleTexte`, `SigneSeance`, `ChronoFoyer` (avec le format
heures, qui est du **code neuf**), `FoyerBanc`, `FoyerLab`.

`Woop/Views/HomeNuit.swift` — **deux hunks**, dans les zones qu'aucune autre
session ne tient (vérifié auprès d'elles) : le slot `fond:` (la vidéo démontée
en séance, la sonde `-fps` préservée) et le slot `contenu:` (`if enSeance`), plus
la vue nommée `foyerEnSeance`.

**Ce que ça respecte, et qui se vérifie à la lecture :** aucune horloge neuve qui
redessine. Les lueurs, le souffle et le point sont des **valeurs animables**
posées une fois en `repeatForever` sur des **feuilles** isolées, réarmées par
`.task(id:)` — le patron `LisereRespirant` de la session perf. Les deux seules
horloges sont celles dont le CONTENU change : le chrono (1 s, scopé au seul
`Text`) et la braise (`Canvas`), qui bat sur le **pas commun** `RythmeEcran.pas`
et **dort** sous un onglet caché.

**Ce qui n'est PAS écrit, et pourquoi :**

- **les widgets en super blur** — ils attendent **D4** (§7). Les monter avant de
  savoir d'où vient la lumière serait le compromis implicite qu'elle a interdit ;
- **le morph** (§4) — il attend **D1**, et il se montre SEUL, en film ;
- **la teinte dans `BraisesVague`** — six lignes chez la session parallèle
  (§7 bis). En attendant, une nappe chaude POSÉE par-dessus : un dégradé constant
  sous une opacité animable, **aucune horloge de plus**, loi anti-brun tenue
  (R = 1,00, seul le vert bouge). **Dette visible, nommée dans le code.**
- **`-foyerLab`** — le banc est écrit mais n'est monté nulle part : sa porte est
  dans `WoopApp.swift`, qui appartient à une autre session. On juge donc sur la
  VRAIE app (`-activeWorkout -skipAuth`), ce qui vaut mieux.

---

## §11 · LES JALONS — chacun MONTRÉ avant le suivant, rien commité avant ton œil

| jalon | geste | preuve |
|---|---|---|
| **J−1** | **LE PLANCHER DE CE CHANTIER, avec la sonde du skill.** `-sondeVol -skipAuth -fermeSeances -activeWorkout`, iPhone **froid** (thermique 0), campagne **ABBA** 3 × 60 s, un barreau à la fois : **`-sansPastille`** (le suspect que personne n'a isolé — un verre `.regular.interactive()` monté au-dessus de tout) et **`-sansFlammes`** sur la vague de la pastille. Le reste du terrain est **déjà mesuré par le skill** : la vidéo est innocentée, le verre pèse le quart, les horloges désaccordées 10 points. | La paire **(cadence, processeur, thermique, n)**, médiane sur `t > 15`, `gel == 0` — jamais un chiffre nu. **Tant que le résidu séance-ouverte n'est pas nommé, aucun nouveau calque n'est justifiable.** ⚠️ Et ce chantier vit **séance ouverte** : ses relevés ne se comparent à aucun relevé « au repos » pris ailleurs (skill §6.9). |
| **J0** | **LES DEUX CAPTURES DE LA LUMIÈRE** (D4) : rangée montée en séance, flou 28, `verre: true` vs `verre: false`. Plus ta réponse au §1. | Deux captures côte à côte, mesurées sur les **pixels clairs**. C'est **ta lecture** qui est la preuve. |
| **J1** | **LA NAISSANCE, TOUTE SEULE** — un rectangle noir vide qui devient la page. Rien d'autre à l'écran : pas de texte, pas de chrono, pas de flamme. **C'est le mouvement que tu juges, pas le dessin.** | **FILM** (`recordVideo --codec h264 --force`, fermé par `kill -INT` — jamais SIGKILL : simctl n'écrit l'en-tête qu'à la fermeture propre), puis le juge de film qui lit les `pts` (le recordVideo est **VFR**, compter les images ne dit rien) : zéro flash, zéro palier, zéro trou noir. Trois rejeux : depuis `yRatio` bas, **depuis l'île**, depuis la borne basse. Puis **TON verdict** — et si c'est « horrible », on bascule sur le repli **au même jalon**. |
| **J2** | **L'ÉCRAN MUET** — les six vues nommées, cotes seules, rien qui bouge. | **9 captures** : trois chronos cloués (**24:52**, 7:03, **1:24:10** — le cas heures) × trois compteurs (0, 3, 11 SETS). Un juge de cotes lit **l'arête réelle de la robe**, jamais une constante. |
| **J3** | **LE FEU** — les 7 paliers, les deux leviers séparés. | **7 captures**, machine calme, puis le sondeur de braise **re-sondé sur les captures** : G/R dans 0,30–0,45 **sur les pixels clairs**, B/R ≤ 0,035, rapports de luminance voisins entre ×1,17 et ×1,46. ⚠️ Les G/R du tapis ont été cuits sur une nappe **RADIALE** : ils **ne se transportent pas** sur des colonnes linéaires sans être re-sondés. C'est ce jalon qui le prouve ou qui les corrige. |
| **J4** | **LE SOUFFLE DU TEXTE** + la respiration du point + les deux déclencheurs de `muer()`. | **FILM 12 s** au banc auto (le souffle est **invisible** au simulateur sans rejeu automatique — leçon de `-mueAuto`) + 4 captures dont on lit la luminance en trois points pour prouver que le dégradé **se déplace**. Non-régression : la phrase fait toujours **exactement 4 lignes**, son bas est toujours au raccord. |
| **J5** | **LES WIDGETS EN SUPER BLUR** (§7), selon le verdict du J0 — avec les trois corrections non négociables. Puis les coutures et le site de doc dans le **même** commit. | Capture + `-fps` **téléphone**, et la non-régression **hors séance** : la home au repos **identique au pixel** (diff de capture), puisque tout le code est derrière `if enSeance`. |
| **J6** | **TON VERDICT, AU TÉLÉPHONE.** 2 min de séance vraie, la main sur le dos de l'appareil. | Ta main, tes yeux, et le relevé. **Le simulateur ne compte pas ici.** |

---

## §12 · LES PIÈGES DÉJÀ PAYÉS QUI VISENT CE CHANTIER

1. **Le rideau** — une vue montée mais cachée est **rendue**. On démonte, on ne voile
   jamais.
2. **Le verre natif ignore `.opacity`** — on le **démonte** (`HomeNuit.swift:2048-2053`).
   Une pastille « éclipsée » à opacité 0 resterait **visible en verre**.
3. **`.offset` déplace les pixels, pas la zone tactile** — payé deux fois.
4. **Un `Button` sous un `DragGesture` d'ancêtre se fait annuler** → `contentShape` +
   `highPriorityGesture`.
5. **Un verre `.interactive()` VOLE le geste de son hôte** (mesuré le 04-09).
6. **Le double `withAnimation`** — deux au même tour = **rien**.
7. **Le mur du type-checker** — une addition de vues **nommées**, jamais une
   expression.
8. **`main` ne compile pas seul** — ne **jamais** `stash` ni `checkout --` le hunk
   `onPlayHold` sans l'avoir **daté**.
9. **Committer par chemins explicites**, jamais `git add -A` : une autre session
   travaille ici.

---

## §13 · CE QUI N'EST PAS PROUVÉ DANS CE PLAN — et je le dis avant qu'on me le demande

- **Le coût propre de `BraisesVague` n'est toujours chiffré nulle part** — le skill
  mesure des familles d'horloges, pas ce composant seul. Tout rapport de surface que
  j'aurais pu écrire serait une opinion habillée en calcul. C'est le J−1.
- **Le budget est mesuré, et il est négatif.** Le skill le dit en un chiffre :
  **écran nu 1 %, n'importe quelle page immobile 27 à 39 %**. Il n'y a pas de marge à
  dépenser — il n'y a que des postes à reprendre. Ce chantier doit donc **rendre plus
  qu'il ne prend**, et c'est le J−1 qui dira de combien.
- **`matchedGeometryEffect` à travers la frontière d'un `Tab` natif n'a jamais été
  éprouvé ici** — la question demande un banc, pas un raisonnement. On anime à la
  main, comme la maison.
- **Le rendu du morph** (« est-ce que ça se lit comme un dépliage et pas comme un
  zoom ») ne se juge qu'au **film**, et par toi. C'est le seul risque de ce chantier
  qui ne se répare pas en une ligne.
- **L'état « 0 série » n'a jamais été vu à l'écran** : la clôture est muette sous
  `guard gain > 0` — c'est l'état par défaut d'un écran de séance qui vient de
  naître, et il n'est filmé nulle part.
