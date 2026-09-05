# PLAN PERFORMANCE — « optimiser sans perdre les vidéos et tout »

*05-09. Écrit après lecture du code, pas de mémoire. Aucun fichier de l'app n'a
été touché : ceci est un plan.*

---

## 1. CE QUI COÛTE

**Oui, c'est possible — et sans toucher ni aux vidéos, ni au verre, ni aux
respirations.**

1. Les vidéos sont **innocentes** : mesuré, les remplacer par une image fixe ne
   rend rien (37 % contre 38 %).
2. Ce qui brûle, c'est que **l'app RECONSTRUIT des morceaux de page une centaine
   de fois par seconde** pour déplacer une lumière d'un demi-degré — elle
   refabrique le verre, le glyphe et les textes à chaque battement, alors que
   seule la lumière bouge.
3. Elle le fait **aussi pour les pages que tu ne regardes pas** : le Profil et
   les Exercices restent montés derrière l'accueil et continuent de battre.
4. Le remède n'est donc pas « moins de dessin », c'est **« le même dessin, mais
   fabriqué une seule fois »** — la respiration, elle, continue (elle devient
   même plus lisse : 60 images/s au lieu de 20).
5. Une chose ne se sait pas encore : la part qui se passe **hors de l'app**, dans
   la partie du téléphone qui compose l'image. Notre sonde est aveugle à ça —
   c'est pour ça que le profileur passe avant tout (§3).

---

## 2. LE PLAN

### Le taux de change, pour lire les chiffres qui suivent

L'A/B déjà payé (« pas commun 20 Hz + onglets cachés fermés ») a rendu
**10 points de processeur** pour **≈ 51 battements/seconde retirés**
(93/s → 42/s, `RythmeEcran.swift:56-71`).
👉 **≈ 0,20 point de processeur par battement/seconde.**
C'est une règle de trois provisoire : **elle se recalcule à chaque campagne**, et
elle sert à *prédire* un gain — donc à *falsifier* une piste, pas à la vendre.

---

### ▸ CE QUI NE SE VOIT PAS (aucun avis à demander — le dessin ne bouge pas d'un pixel)

---

#### 0. L'INSTRUMENT D'ABORD : deux seaux de sonde, et une mesure à zéro ligne de code

**Technique** : extension du compteur de battements existant.
**Fichier:ligne** : `Woop/Views/SondeVol.swift:163-171` — `tic(_:)` est plafonné à
**5 seaux** (`guard i >= 0, i < 5`), étiquetés « 0 widgets · 1 nappe/menu ·
2 galets · 3 route · 4 semaine ». **Il n'y a aucun seau pour le Profil ni pour les
Exercices** : les horloges du §1 sont donc, aujourd'hui, **invisibles à la sonde**.

**Le geste** : passer à 8 seaux (5 = profil, 6 = exercices, 7 = châssis) et poser
un `tic(5)` dans les 5 horloges de `ProfilLune.swift` et un `tic(6)` dans les 4 de
`ExercisesView.swift`.

**⚠️ AVANT MÊME ÇA — la mesure qui décide de tout le reste, et qui ne coûte pas
une ligne** (5 minutes, téléphone froid) :

| essai | ce qu'on fait | ce qu'on lit |
|---|---|---|
| A | lancement neuf → rester sur l'accueil 60 s | % processeur |
| B | aller au Profil 10 s, revenir à l'accueil, attendre 30 s, mesurer 60 s | % processeur |

- **Si B > A de plus de 3 points** → les onglets cachés battent pour de vrai, et
  le geste ①  est le plus gros levier du document.
- **Si B ≈ A** → SwiftUI suspend déjà les onglets détachés, ① vaut zéro, **et on
  ne l'écrit pas.** (C'est exactement le doute que `tools/nav/PLAN-FLUIDITE.md:302`
  laisse ouvert : « les onglets cachés tiquent-ils ? Jamais mesuré ».)

**Risque sur le dessin** : aucun (aucune vue touchée).

---

#### 1. LA PORTE D'ONGLET QUI MANQUE — le Profil et les Exercices ne dorment jamais

**Technique** : la porte d'horloge déjà en place, appliquée aux deux pages qui
l'ont ratée (`paused: … || RythmeEcran.dort("profile")`).

**Ce que la machine cesse de faire** : reconstruire, derrière l'accueil, la
bannière de halos, le rond d'avatar, la poignée de lune et ses flèches — des
pages qui ne rendent **aucun pixel visible**.

**Fichier:ligne** — le mécanisme existe et n'est pas branché :

- `Woop/Views/RythmeEcran.swift:76` — `static func dort(_ onglet: String)` :
  générique, prête, **utilisée uniquement pour `"home"`** (`:73`).
- `Woop/WoopApp.swift:1271` — le châssis écrit déjà `ongletActif` à chaque bascule.
- `Woop/Views/ProfilLune.swift` — **5 horloges, aucune `paused:`** :
  `:1238` (20 Hz, la poignée), `:1420` (30 Hz, le sachet qui danse),
  `:1504` (30 Hz, `RondAvatar`), `:1929` (20 Hz, `FlechesInvite`),
  `:2032` (30 Hz, `BanniereHalos`, plein cadre de bannière).
  Le châssis lui passe pourtant `\.ongletCache` (`WoopApp.swift:1224`) : **aucune
  vue du fichier ne le lit** (vérifié par grep sur tout le dépôt).
- `Woop/Views/ExercisesView.swift` — **4 horloges, aucune `paused:`** :
  `:1078` (30 Hz), `:1539` (**60 Hz, un `Canvas`**), `:2201` (30 Hz),
  `:2284` (30 Hz). Même remarque : `\.ongletCache` lui est passé
  (`WoopApp.swift:1212`) et n'est lu que par `ExosFond.swift:143`.

**Gain attendu** : au repos, le Profil bat ≈ **100 battements/s** (20+30+30+20).
À 0,20 pt/battement → **jusqu'à 16 points**. Prudent, parce que ces fermetures
sont plus petites que celles des widgets : **fourchette annoncée 6 à 16 points**
sur l'accueil, *après* une visite au Profil. Zéro pendant qu'on REGARDE le Profil.

**Risque sur le dessin** : **AUCUN** — par construction, on n'éteint que ce qui
n'est pas à l'écran ; au retour, l'horloge repart (le pattern est déjà celui de la
home, `RythmeEcran.swift:71-79`).

**LE BARREAU ET LE CHIFFRE** :
`-sansRepos` (`RythmeEcran.swift:33-36`) rallume tout le mécanisme → c'est le
témoin, il existe déjà.
1. **Preuve d'exécution** : sur l'accueil, seaux 5 et 6 de la sonde à **0/s**
   (aujourd'hui : > 0 — à établir au geste ⓪).
2. **Preuve de gain** : `-sansRepos` contre défaut, ordre alterné, thermique 0 :
   écart attendu **≥ 6 points**. En dessous de 3 : la piste est morte, on l'écrit.
3. **Preuve de non-régression** : film 3 s du Profil affiché, avant/après →
   **identique**.

---

#### 2. LA PIÈCE DU PROFIL N'EST PAS GELÉE — un mot, documenté « identique au pixel »

**Technique** : `figee: true` sur `MoonCoinView` (le drapeau existe et fait
exactement ça).

**Ce que la machine cesse de faire** : une horloge à 6 Hz, **un dispatch de shader
Metal par battement**, et surtout **un abonnement au gyroscope** — `SkyMotion` est
`@Observable` et publie à 30 Hz (`DemonSky.swift:34`), donc la pastille se
réévalue au rythme du poignet, en permanence.

**Fichier:ligne** : `Woop/Views/ProfilLune.swift:903-905` —
`MoonCoinView(coinR: 11, draggable: false, yawOverride: 0.34, idleLife: 0, fps: 6, reveal: 0.34, matte: 0)`
— il manque `figee: true`.
La preuve que c'est sans risque est écrite dans le composant lui-même,
`Woop/Views/MoonCoinLab.swift:60-66` : « pour une pièce déjà posée (`idleLife: 0`
+ `yawOverride`), le rendu est **IDENTIQUE AU PIXEL** — c'est du coût pur qui s'en
va » ; et `:116-123` montre que `figee` coupe l'horloge **et** la lecture du tilt.
Le même appel est déjà corrigé ailleurs : `SetHistoryRow.swift:184-186`.

**Gain attendu** : 1 à 3 points sur le Profil (6 battements/s + la chaîne gyro).
Petit, mais **gratuit et sans débat**.

**Risque sur le dessin** : **AUCUN**, documenté au pixel par le dépôt.

**LE BARREAU ET LE CHIFFRE** : capture du bandeau trésor avant/après →
**diff strictement 0** (pas « ≤ 2/255 » : 0). Puis % processeur sur le Profil
immobile, thermique 0 : **−1 point ou plus**.

*(Deux autres appels sont dans le même cas mais hors des pages au repos :
`WahouReveal.swift:596`, `BravoLab.swift:646`. À faire au passage, sans les
mesurer.)*

---

#### 3. LE SOUFFLE SORT DE L'HORLOGE — « le modificateur animable »

**C'est le geste de fond du document, et c'est LA technique 2026 qui répond à sa
question.**

**Technique** : `ViewModifier` + `Animatable` sur la **phase**, armé une seule
fois par `withAnimation(.linear(duration: T).repeatForever(autoreverses: false))`.
SwiftUI ré-évalue alors **le modificateur seul**, image par image ; le contenu
qu'il enveloppe (`_ViewModifier_Content`) est **déjà construit** et n'est jamais
rebâti. La courbe reste un **sinus exact** (elle est calculée dans le modificateur
à partir de la phase), donc **même image, à la sous-image près**.

**Ce que la machine cesse de faire** : reconstruire, 20 fois par seconde, tout ce
qui ne dépend pas du temps — au premier rang **un verre natif**.

**Fichier:ligne — le cas le plus cher, et il est flagrant** :
`Woop/Views/MenuNappe.swift:183-292`, le galet du menu. Fermeture de **109 lignes
à 20 Hz**. Or, dedans, `t` ne sert qu'à **deux scalaires** :
- `souffle` (`:187-188`) → un `.scaleEffect` (`:285`) ;
- `braise` (`:264-265`) → l'opacité d'un `RadialGradient` et un `.scaleEffect` (`:271-281`).

Tout le reste est **invariant** et refabriqué pour rien à chaque battement :
le `GlassEffectContainer` + `verreHome(.clear.interactive())` +
`glassEffectID("galet")` (`:231-238`), la `navette`, le `NeonMaison` (`:246`), la
doublure de transport (`:204-229`).

**Et la braise se factorise exactement** : ses deux arrêts sont `0.44 * braise` et
`0.18 * braise`, l'arrêt `.clear` reste clair — le dégradé **constant** (0,44 /
0,18 cuits) sous un `.opacity(braise)` donne **la même image, à l'arithmétique
près**. Zéro reconstruction de dégradé.

**Les autres sites, même patron, même preuve** :

| fichier:ligne | ce qui dépend de `t` | réductible à |
|---|---|---|
| `ProfilLune.swift:1929` (`FlechesInvite`) | `.opacity` de 2 chevrons | opacité animable, exacte |
| `ProfilLune.swift:1238` (la poignée) | `0.75·vie` et `0.95·vie` sur 2 halos | 2 opacités animables, exactes |
| `ProfilLune.swift:1420` (le sachet) | `rotationEffect` + `scaleEffect` | 2 transforms animables, exacts |
| `HomeNuit.swift:4874` (`InviteTirage`) | opacités des chevrons | idem |
| `WidgetsCards.swift:1020` (`CardVolume`) | 7 valeurs `vive` | les **7 `Text(j.lettre)`** et leurs positions (`:1038-1042`) sortent de la fermeture : moitié du travail par battement |

**⚠️ LE PIÈGE, ET LE DÉPÔT L'A DÉJÀ PAYÉ** — `Woop/Views/PageCard.swift:372-374` :
« un `repeatForever` posé par `withAnimation` **se fait avaler quand le parent est
ré-évalué** ». Donc : l'état de phase vit **dans la feuille** (jamais chez un
parent qui se réévalue) et se **ré-arme** à `.task` / `onChange`. Si un site refuse
cette discipline, la sortie de secours est une vraie `CABasicAnimation`
(`repeatCount: .infinity`) dans un `UIViewRepresentable` : elle vit sur le calque,
côté serveur de rendu, et **aucune ré-évaluation SwiftUI ne peut l'annuler**.

**Gain attendu** : le seau « nappe » vaut 10 battements/s → **2 points** au taux de
change ; mais cette fermeture-là contient un verre natif, donc elle est **au-dessus
de la moyenne** : **fourchette 2 à 6 points** pour le galet seul, plus 1 à 3 pour
les cinq autres sites.

**Risque sur le dessin** : **INVISIBLE** — la courbe et l'amplitude sont
conservées à l'identique ; le souffle devient interpolé à 60 Hz au lieu d'être
échantillonné à 20, donc **plus lisse, jamais différent**.

**LE BARREAU ET LE CHIFFRE** :
1. Nouveau drapeau `-souffleHorloge` = l'ancienne forme (la `TimelineView`), pour
   un A/B **ordre contre ordre** dans le même binaire.
2. **Preuve de dessin** : film 3 s à 60 img/s des deux versions, **comparaison
   image par image après recalage de phase** — écart max attendu ≤ 1/255 hors
   anticrénelage. (Pas de diff sur capture unique : les deux respirent, elles ne
   seront jamais en phase.)
3. **Preuve d'exécution** : seau 1 (nappe) à **0/s** au repos.
4. **Preuve de gain** : ≥ 2 points, sinon on le dit et on s'arrête là.

---

### ▸ CE QUI DEMANDE SON AVIS (le dessin peut changer — ne rien faire avant qu'elle ait vu)

---

#### 4. LES LENTILLES DE VERRE MONTÉES HORS CHAMP, sur le chemin

**Technique** : rétrécir la fenêtre de montage — du verre monté sur trois écrans
à celui de l'écran courant.

**Fichier:ligne** : `Woop/Views/DuolinguoPage.swift:1258` —
`lentille: abs(e.ecran - etat.ecranCourant) <= 1 && (e.n <= 1 || e.n >= 7 || e.special)`.
Avec `parEcran = 9` (`:172`), ça fait **4 à 5 verres natifs visibles** et
**8 à 10 verres natifs MONTÉS INVISIBLES** (les deux écrans voisins).

**Pourquoi c'est crédible** : c'est **la seule famille qui ait jamais bougé de
9 points** au barreau (`-sansVerreHome`, six verres éteints).

**Gain attendu** : ordre de grandeur 3 à 9 points **quand la route est ouverte**
(zéro sur l'accueil au repos — ce n'est pas le même écran).

**Risque sur le dessin** : **invisible en régime** (les galets concernés sont hors
écran) ; **à surveiller pendant le défilement** — un verre qui se monte au moment
où il entre en champ peut faire un « pop ». C'est ça qu'elle doit juger, pas le
repos. Repli si pop : fenêtre `<= 1` uniquement dans le sens du défilement.

**LE BARREAU ET LE CHIFFRE** : drapeau `-lentilleLarge` (l'ancienne fenêtre) contre
défaut, sur `-cheminReel`. Compter les verres montés par une sonde (`tic(2)` +
un compteur d'instances). Cadence attendue en hausse d'au moins **5 img/s** ;
film du défilement complet, à ses yeux, avant tout commit.

---

#### 5. LA ROBE DE LA CARD : un découpage plein écran, par image, par page montée

**Technique** : remplacer un `clipShape` de page entière par **deux caches noirs**
aux coins bas (le fond derrière la card étant noir, l'image est la même).

**Fichier:ligne** : `Woop/Views/PageCard.swift:290` `.clipShape(Self.robeCard)`,
et `:311-316` — `UnevenRoundedRectangle(topLeading: 0, bottomLeading: 30,
bottomTrailing: 30, topTrailing: 0, style: .continuous)`.
**Coins inégaux + `.continuous`** : ça ne peut pas se replier sur le
`cornerRadius` d'un calque — c'est donc, très probablement, **un vrai masque hors
écran sur toute la page, à chaque image, et ×2 pages montées**.
C'est la même famille que le ruban condamné le 05-09 (`PageCard.swift:281-288` :
plein cadre, ×2 pages, **9,3 → 30,2 img/s**).

**⚠️ Ce n'est PAS établi, c'est une hypothèse** : elle se tranche par le débogueur
de rendu, **avant** d'écrire une ligne (§3, étape 7).

**Gain attendu** : inconnu tant que le profileur n'a pas parlé. Si le masque part
bien hors écran : c'est le plus gros poste du côté cadence.

**Risque sur le dessin** : **invisible** si tout ce qui est hors de la card est
opaque et noir ; **visible** sinon (un coin qui « bave »). À prouver par capture.

**LE BARREAU ET LE CHIFFRE** : ① « Color Offscreen-Rendered » sur le téléphone,
avant/après, sur la **zone de la card seule** (pas l'écran entier : tout est jaune,
la note de la contre-expertise est juste) ; ② diff pixel = 0 sauf sur l'arc
d'anticrénelage (≤ 2 px de large) ; ③ cadence en séance, médiane sur 60 s.

---

#### 6. LES SHADERS GÉNÉRATEURS N'ONT PAS BESOIN DE SwiftUI

**Technique** : héberger un shader **purement génératif** dans un calque Metal à
horloge propre (`MTKView` / `CAMetalLayer` en `UIViewRepresentable`), au lieu de
republier un `Shader` dans l'arbre SwiftUI à chaque battement.

**Pourquoi c'est licite ici** : ces sites sont
`Rectangle().fill(.white).colorEffect(…)` — la source est **une constante**, le
shader ne lit **rien** de ce qu'il y a dessous. Le `.metal` ne change pas d'une
ligne, les uniformes non plus : **la même fonction, le même temps, la même image**.

**Fichier:ligne** :
- `ProfilLune.swift:2030-2041` (`BanniereHalos`, 30 Hz, plein cadre de bannière —
  la page à 39 %) ;
- `HomeNuit.swift:4694-4700` et `:4833-4840`, `MenuNappe.swift:935 / :979`,
  `ExercisesView.swift:2201` (mêmes formes, montages conditionnels à vérifier
  avant de les toucher).

**Ce que la machine cesse de faire** : rebâtir un nœud d'effet, le rediffuser dans
la liste d'affichage et valider une transaction, 30 fois par seconde — la passe
GPU, elle, reste identique.

**Gain attendu** : **à chiffrer par le profileur** (c'est précisément ce que
l'instrument « SwiftUI » sait dire : durée de corps de vue par type). Ne pas
promettre de points avant §3.

**Risque sur le dessin** : **invisible en théorie**, mais l'objet change d'hôte —
donc à prouver par diff, et à ne faire **qu'après** les gestes 0-3.

**LE BARREAU ET LE CHIFFRE** : diff pixel sur deux captures **au même temps
`t` imposé** (le shader est une fonction du temps : on peut le geler des deux
côtés) → **écart 0**. Puis seau de sonde à 0/s et % processeur.

---

#### 7. LE FOYER ADDITIF DE LA HOME, MONTÉ EN PERMANENCE POUR NE RIEN DESSINER

**Technique** : la loi maison — **« on DÉMONTE, on n'éteint pas »** (elle est
écrite en toutes lettres à `MenuNappe.swift:1303-1308`, et c'est elle qui a tué le
coût de `MenuHalos`).

**Fichier:ligne** : `Woop/Views/DepartCine.swift:718`
`.overlay { lueur.blendMode(.plusLighter) }` et `:758` `.compositingGroup()`.
Au repos `e = 0`, donc `f = sstep(0.74, 1.66, 0) = 0` (`:110`, `:247`, `:776`) :
la lueur **ne dessine rien**, mais elle est montée, composée, et le groupe force
une **passe hors écran sur toute la card, à chaque image**.
**Et l'A/B qui a innocenté la vidéo ne l'innocente pas** : `poseSeule` (`:696`,
`:726`) ne remplace que les `CalqueVideo` — la lueur et le groupe restent montés
**des deux côtés**. Ce poste n'a **jamais été mesuré**.

**Gain attendu** : inconnu côté processeur (probablement une fraction de point) ;
**potentiellement gros côté cadence**. À arbitrer par le profileur.

**Risque sur le dessin** : **VISIBLE si on s'y prend mal.** Le groupe isole
l'addition de la braise, du foyer et de la pilule ; le retirer change la façon
dont l'ensemble se pose sur ce qu'il y a derrière. Le commentaire `:751-758` dit
exactement pourquoi il est là. **Donc : on conditionne le montage
(`if f > 0.001`), on ne supprime jamais le groupe.**

**LE BARREAU ET LE CHIFFRE** : drapeau `-foyerMonte` (ancien comportement) ;
capture de la home au repos → **diff 0** ; puis capture au milieu du film de départ
(`e ≈ 0,85`) → **diff 0** aussi, sinon on remet.

---

## 3. FAIRE MARCHER LE PROFILEUR

**Il n'est pas cassé : il n'a jamais été lancé.** `xcrun xctrace list templates`
répond sur cette machine, et les trois modèles dont on a besoin sont là :
**`SwiftUI`**, **`Animation Hitches`**, **`Metal System Trace`**.
Sans lui, on devine : la sonde de vol mesure **les fils de l'app**
(`SondeVol.swift:222-250`) et ne voit **rien** du serveur de rendu — c'est
structurel, et ça explique pourquoi le % ne bouge pas entre 60 et 21 img/s.

**Dans l'ordre :**

1. **Le téléphone** — Réglages → Confidentialité et sécurité → **Mode développeur**
   activé, appareil appairé, déverrouillé pendant toute la trace.
2. **Le bon binaire** — build **de développement** (signé avec `get-task-allow` ;
   une build TestFlight/App Store **ne se profile pas**). Sortie dans un
   `-derivedDataPath` à part. ⚠️ **Jamais `xcodebuild | grep` ni `| tee`** : c'est
   le code de sortie du tube qu'on lit (piège payé quatre fois).
3. **Le bon écran** — installer, puis lancer **avec les drapeaux voulus**
   (`-skipAuth`, `-sondeVol`…). Le demi-journée perdue vient de là : la ligne de
   la sonde qui nomme l'onglet est la **preuve** qu'on mesure bien cet écran-là.
4. **L'appareil** — `xcrun xctrace list devices` → relever l'UDID.
5. **TRACE N° 1, LE PROCESSEUR DANS L'APP** :
   `xcrun xctrace record --template 'SwiftUI' --device <UDID> --attach Woop --time-limit 30s --output ~/Desktop/woop-swiftui.trace`
   👉 elle donne **« View Body » : combien de fois chaque type de vue est
   reconstruit, et combien ça dure**. C'est **l'arbitre qui manque** depuis le
   début : il classe les ~100 battements/s par coût réel, et il valide ou tue les
   gestes 1, 3 et 6 **avant** qu'on les écrive.
6. **TRACE N° 2, CE QUI SE PASSE HORS DE L'APP** :
   `--template 'Animation Hitches'` (puis `'Metal System Trace'` si besoin).
   👉 elle donne **le temps de commit du serveur de rendu et le temps GPU** —
   exactement ce que le % de processeur ne peut pas voir, et donc le seul juge des
   gestes 5 et 7.
7. **La carte des passes hors écran** — téléphone branché, Xcode → Debug → View
   Debugging → Rendering → **Color Offscreen-Rendered Yellow**.
   ⚠️ Sur cette app **tout l'écran vire au jaune** : ça ne CLASSE pas. On ne s'en
   sert que **comparativement**, sur **une zone** (la card, un coin), avant/après
   **un seul** changement. Et jamais au simulateur (loi payée : « le simulateur ne
   mesure que le simulateur », A/B du 04-09 : 5 contre 8 img/s).
8. **Lire sans ouvrir Instruments** :
   `xcrun xctrace export --input woop-swiftui.trace --toc`, puis
   `xcrun xctrace export --input … --xpath '<le chemin de la table voulue>'`.
9. **Ce qui invalide une trace** : thermique ≥ 1 au démarrage · l'app lancée depuis
   le débogueur · un second simulateur ou une autre app lourde (`./tools/charge.sh`
   **avant**) · l'écran qui s'endort.
10. **Ce que le profileur NE dit pas** : il coûte lui-même. **Il CLASSE, il ne
    CHIFFRE pas.** Le chiffre reste la sonde de vol, **téléphone débranché** — et
    le câble de la trace charge la batterie, donc chauffe : les deux mesures ne se
    font jamais dans la même minute.

*Arbitre de fond, gratuit et sans câble : **MetricKit** (`MXCPUMetric`,
`MXAnimationMetric`, `MXDisplayMetric`) — un rapport par jour, en usage réel, sur
son téléphone à elle. Long, mais c'est le seul juge qui ne modifie rien.*

---

## 4. LA MÉTHODE (à partir de maintenant, tout essai qui n'en sort pas est jeté)

1. **Téléphone froid.** Thermique lu **à la première seconde** de la sonde. Si
   ≥ 1 : on attend, on ne « corrige » pas.
2. **Ordre alterné : A B B A A B.** Jamais A A A puis B B B — le téléphone chauffe
   dans un sens.
3. **3 répétitions × 60 s par barreau.** On garde la **médiane des secondes**, pas
   la moyenne. **On jette les 10 premières secondes** (mise en route des décodeurs
   et des shaders).
4. **Toujours publier la PAIRE (cadence, % processeur).** Un % à 21 img/s et un %
   à 60 img/s n'ont pas le même dénominateur — comparer les deux est une faute
   déjà payée.
5. **Un seul moteur à la fois.** Deux changements dans une balade = une balade
   perdue.
6. **Le drapeau se PROUVE, il ne se suppose pas** : la ligne de la sonde qui nomme
   l'onglet et l'écran est la preuve.
7. **L'écran ne dort pas** — déjà tenu (`SondeVol.swift:demarrer()`,
   `isIdleTimerDisabled`). Une cadence qui tombe **avec** le processeur, c'est une
   veille, pas une victoire.
8. **On jette** : toute seconde à thermique ≥ 2 · toute campagne où l'app a été
   relancée en boucle · tout essai dont le drapeau n'est pas prouvé · tout A/B où
   les deux côtés ne sont pas dans la même dizaine de minutes.
9. **On recalcule le taux de change** (points par battement/seconde) à chaque
   campagne, et on l'écrit. C'est lui qui rend les prédictions falsifiables.
10. **Une pastille ne se repeint pas en vert parce qu'on a écrit le code** : elle
    se repeint quand la mesure a été **lue**.

---

## 5. CE QU'ON N'A PAS PU TRANCHER

- **Les onglets cachés battent-ils vraiment ?** C'est la question ⓪. Tout le
  geste ① en dépend, et **personne ne l'a mesurée** (`PLAN-FLUIDITE.md:302`).
- **Où passent les 27 % « plancher » d'une page immobile ?** Le taux de change
  (0,20 pt/battement) explique bien les 10 points déjà gagnés, mais **il ne
  démontre pas** que le reste soit de la même nature. Réponse : trace n° 1.
- **Pourquoi le processeur ne bouge pas entre 60 et 21 img/s ?** Toujours
  inexpliqué. Un coût par image ne peut pas être plat ; donc soit le coût est
  par battement (et les horloges ne sont pas affamées par la cadence comme on le
  croyait), soit il est ailleurs. Réponse : traces n° 1 **et** n° 2, ensemble.
- **Le liseré angulaire des widgets** (`WidgetsCards.swift:261-291`) : son angle
  n'est réductible ni à une opacité ni à une transformation, donc il échappe au
  geste 3. Une piste existe (dégradé constant **tourné** sous un masque statique)
  mais elle **n'est pas exacte** — le flou mélange des échantillons voisins du
  dégradé. **Non proposée.**
- **Le coût réel d'un verre natif** : les 9 points de `-sansVerreHome` mesurent
  *capture + flou + composite* ensemble. On ne sait toujours pas quelle part est
  dans l'app et quelle part est au serveur de rendu. Réponse : trace n° 2.

---

## 6. LES PISTES ÉCARTÉES (on ne les rouvre pas)

- **Un `GlassEffectContainer` par grappe** — les six verres de l'accueil sont
  **déjà** chacun dans un conteneur, à bounds verrouillés ; regrouper met l'encre
  dedans (elle sort givrée) et rend les bounds vivants (blur plat définitif).
- **Baisser la cadence du shader de la bannière du Profil** — sa jumelle
  (`RondAvatar`, 30 Hz) resterait : deux horloges désaccordées **ajoutent** leurs
  images sales (30/s → 40/s). Ça empire.
- **Sortir le liseré animé de sous le verre des widgets** — la « preuve » invoquée
  compare un liseré animé à un liseré **statique** ; et le fond du verre reste la
  vidéo à 24 i/s, donc rien ne devient statique.
- **`Glass.identity` comme barreau + éteindre le verre des onglets cachés** —
  l'API existe, mais le verre d'un onglet détaché ne compose pas : le gain visé
  (2 à 5 pts) n'existe pas, et le barreau acquitterait le verre à tort (le
  conteneur, lui, reste monté).
- **`compositingGroup()` autour d'un verre** — il n'enlève pas une passe, il en
  ajoute une ; et il est **porteur** (une opacité ancêtre à
  `DuolinguoPage.swift:1295`, un `blendMode` enfant à `GaletEtape.swift:527`).
- **Cuire le verre au `drawHierarchy`** — il n'y a, dans cette app, **aucun verre
  sur fond immobile** qui vaille d'être cuit ; et une capture 8 bits écrête le
  spéculaire, c'est-à-dire le seul trait qui fait lire « Liquid Glass ».
  *(À garder quand même en doctrine : `ImageRenderer` ne capture PAS un verre — il
  rend un trou transparent, en silence. Tout le dépôt cuit à l'`ImageRenderer`.)*
- **Poser une aiguille « occupation du fil principal »** — elle est bornée
  d'avance par le % déjà affiché, et la donnée décisive est **déjà** dans les
  fichiers `vol-*.jsonl` de sa balade du 05-09.
- **Quantifier la VALEUR du temps pour aligner les phases** — quantifier la valeur
  n'aligne pas l'instant du changement ; et à 66 ms d'échantillon sur une grille
  de 50, chaque battement tombe dans un seau neuf : gain **nul**, et un
  tressautement à 5 Hz en prime.
- **Un `GlassEffectContainer` unique pour l'accueil** — deux des six sites ne sont
  pas montés sur l'accueil (un banc, un panneau fermé), et un conteneur au niveau
  page a des bounds vivants : risque de panne plate **sur les six d'un coup**.
- **Réécrire la nappe du menu en un seul `colorEffect`** — `MenuHalos` est
  **démonté** menu fermé (`MenuNappe.swift:1309`) : gain 0 sur la page mesurée.
  *(Le seul morceau vrai de cette piste est devenu le geste 7.)*
- **Un SDF pour le liseré des widgets** — un SDF qui change au même rythme
  invalide le verre exactement pareil ; et l'objet pèse ~1,5 % du ruban, donc des
  dixièmes d'image par seconde.
- **Les gaussiennes et ombres de la pilule** — les six passes citées **ne
  coexistent jamais** (île amarrée ≠ pastille qui roule), et sous le doigt il n'y
  en a qu'une. L'intérieur est déjà gelé (`fige: etat.enMouvement`).

---

### L'ORDRE, EN UNE LIGNE

**⓪ la mesure à zéro ligne de code → §3 le profileur → ① la porte d'onglet →
② la pièce gelée → ③ le souffle animable → *(re-mesurer, recalculer le taux de
change)* → ④⑤⑥⑦, et seulement avec son avis sur le dessin.**
