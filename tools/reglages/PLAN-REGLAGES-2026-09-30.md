# PLAN — L'onglet Réglages (langue · départ de série) — 30-09-2026

> **Plan seul. Aucune ligne de code, aucun banc, aucun commit.**
> Maquette jouable (HTML, pas le Swift) : lien dans le compte-rendu de la session.
>
> Demande de Kathryn, 30-09 : « rajoute un onglet dans la navigation
> "Réglages" : langue choisie (déjà prévue dans le back-end, ça change toute
> l'app), et en dessous format de départ de série : le user peut choisir le
> galet blanc ou le slider. Dans toutes les pages détail exercices, enlever le
> galet et remplacer par notre composant slider : qui lance un exercice arrive
> direct sur le chrono. Liquid glass, page noire, dégradé de blanc, type Apple
> minimal, très peu de texte, bel effet magnifique. »

---

## 0. Ce qui existe déjà (lu dans le code et sur le site, rien de déduit)

### 0.1 La navigation

- Le châssis a **trois onglets** : `WoopTab` = `home, exercises, profile`
  (`Nosfy/NosfyApp.swift:146-161`), ordre `order` (`:547`), `TabView` natif
  (`:1810-1843`). Chaque page immersive masque la barre native
  (`.toolbarVisibility(.hidden, for: .tabBar)`) et reçoit `\.ongletCache`.
- Ce qu'elle voit en bas de la home, c'est la **nav d'encre** : `NavBande` →
  `NavEncre` (`Nosfy/Views/NavEncre.swift:27-65`, `:621`). `NavDest` =
  `home, exos, profil`, avec son glyphe, son nom et le pont `ongletWoop`. Le
  pont nav ↔ onglet est dans `NosfyApp.swift:1881-1899`, et l'onglet Exercices
  passe par **la porte unique** `allerAuxExercices` (`:1158`).
- La géométrie suit le nombre de destinations : `NavGeo.centre` est calculé
  sur `NavDest.allCases.count` et le pas vaut 76 pt (`NavEncre.swift:479-483`).
  Quatre glyphes tiennent sur 304 pt, donc un quatrième point se place tout
  seul.
- Le menu colonne de la home (`MenuNappe.swift:717-724`) dit déjà : « le
  "Réglages" est retiré… **le temps qu'il ait une page** ».

### 0.2 La langue : le back-end est prêt, 🟢 sur le site

- `Langue.swift` : une seule vérité, `profils.langue` au serveur. Le cache
  local s'appelle `woop.langue`, le serveur gagne, et les textes passent par
  `L("fr", "en")`.
- Écriture : `ProfilServeur.definirProfil(langue:prenom:but:objectifHebdo:)` →
  `definir_profil`. Les champs omis sont conservés. Site : `b-fn-definir-profil`
  🟢 et `b-tb-profils` 🟢 (32 PASS, rejoué le 20-09).
- **Le geste « changer la langue » existe déjà** dans la revisite du profil
  (`NosfyApp.swift:427-460`, `reecrireRevisite`). Il n'écrit que ce qui a
  changé et récupère le cas « l'appel a échoué, mais le serveur porte déjà le
  changement ».
- « Ça change toute l'app » : oui. `.id(langueApp)` (`NosfyApp.swift:1875`)
  fait renaître le `TabView` entier quand `woop.langue` change.
- **Trous connus** (lus) : ces textes ne suivront pas la langue tant qu'on ne
  les corrige pas.
  - Dates écrites en dur en `fr_FR` : `ChambreDonnees.swift:468, 595, 601,
    653, 658, 663`, `ChargeFiche.swift:416`, `HomeNuit.swift:2017, 2022`.
  - Date écrite en dur en `en_US` : `WorkoutPill.swift:236`.
  - Noms de la nav en français seul : `NavDest.nom`, `tabItems`.
  - Les textes serveur déjà nés (stories passées, annonces) restent dans leur
    langue : « l'app ne traduit jamais un texte serveur ».

### 0.3 Le départ de série aujourd'hui

- **Le galet blanc** = `LaunchPebble` (`LaunchPebble.swift:22`). C'est un
  **glissé vers le haut**, pas un tap. Il n'a qu'**un seul site** :
  `ExerciseDetailView.swift:1063` (label « Start exercise »).
  `CardioFiche` et `ChargeFiche` sont des sous-vues de cette fiche. Il n'y a
  pas d'autre page détail, donc « toutes les pages détail » = cette fiche,
  dans ses trois robes.
- **Muscu, 5 étapes avant le chrono** :
  1. galet ;
  2. monde blanc (`LiquidLensLab`) ;
  3. bulle poussée à 0,985 ;
  4. film du sommet ;
  5. chrono environ **10 s après**.

  Les testeuses s'y perdent (`tools/exos-accueil/ANALYSE-EXPERIENCE-COMPLETE-2026-09-21.md`).
- **Cardio** (HIIT, escalier, tapis lent) : le galet appelle `lancerTapis`
  (`ExerciseDetailView.swift:2485`), `TapisScene` remplace la fiche, et le
  chrono part seul 0,85 s plus tard (`TapisScene.swift:260, 281`).
- **Piscine** : pas de galet, un compteur de longueurs, pas de chrono. On n'y
  touche pas.
- **Un chemin sans galet existe déjà** : `launchPosed()`
  (`ExerciseDetailView.swift:3498`). Il saute le galet, le monde blanc et le
  sommet (`LiquidLensLab.posedStart`, `:432`), mais joue encore **3-2-1 (3,4 s)**
  avant 0:00. Aujourd'hui seul « Recommencer » l'appelle.
- **Le slider** = `SliderObsidienne` (`SliderObsidienne.swift:28`, shader
  `NavMonolith.metal:590`). Il s'arme à 72 % de la piste, et `onConfirm:` se
  passe toujours **par son nom**, jamais en closure finale. Il vit déjà en
  production à cinq endroits : départ de séance (home), « Finish set »,
  « Slide to start rest », Stop, « Finish » cardio. **Jamais comme départ de
  série.**
- **Aucune préférence n'existe** : il n'y a pas de clé galet/slider.

### 0.4 Les portes des autres sessions, à ne pas doubler

- La sortie de fiche passe par `quitterLaFiche()`
  (`ExerciseDetailView.swift:3286`), commits `be784c8d` et `2b7252ec`, session
  chevron du 30-09. L'onglet Exercices en séance passe par
  `allerAuxExercices`. **On n'ajoute aucune deuxième porte.**
- ⚠️ **Hunks d'autres sessions dans l'arbre, non commités** au 30-09 :
  - `SliderObsidienne.swift` (+80 lignes) ;
  - `LaunchPebble.swift` ;
  - `LiquidLensLab.swift` (MM) ;
  - `TapisScene.swift` (MM) ;
  - `NosfyApp.swift`.

  À relire dans `MULTI-SESSION.md` et `git diff` avant le jalon 2, et à ne
  jamais emporter.
- ⚠️ La garde des bancs (`NosfyApp.swift:2663-2672`) rejette **en silence**
  tout drapeau qu'elle ne connaît pas. Chaque nouveau drapeau s'y ajoute.

### 0.5 Défaut suspect, lu et non mesuré

Le bouton d'accessibilité du galet (`onLaunch`, `LaunchPebble.swift:169`)
appelle `launch()` sans relever la lentille. En muscu, la lentille serait
montée à opacité 0 et le chrono ne viendrait jamais
(`ExerciseDetailView.swift:1264-1266`). **À vérifier au simulateur avec
VoiceOver au jalon 2.** Tant que ce n'est pas mesuré, la pastille ne bouge pas.

---

## 1. Ce qu'on construit

```
Nav d'encre :  Accueil · Exercices · Profil · Réglages (4e point, gearshape)

Page Réglages (noire, lune de blanc, verre)
 ├─ Langue           ( Français | English )       ← commutateur obsidienne
 └─ Départ de série  [ vitrine de verre : dôme du galet OU slider, figé ]
                     ( Galet | Slider )           ← commutateur obsidienne

Fiche exercice, mode Slider :   slider en bas → glisse → écran du chrono (3, 2, 1, GO → 0:00)
Fiche exercice, mode Galet  :   inchangée (galet → monde blanc → sommet → chrono)
```

### 1.1 La préférence

- `enum DepartSerie: String { case galet, slider }`, clé `woop.departSerie`
  (`@AppStorage`), dans un fichier neuf `Nosfy/Services/DepartSerie.swift`.
- La fiche la lit **au montage**. On ne change pas de mode en pleine série :
  la page Réglages n'est pas atteignable pendant une série, puisque la nav est
  masquée quand `running != nil`.

### 1.2 La page Réglages : la robe

> **Correction du 30-09 (Kathryn : « reprends le composant slider qu'on a
> partout, et un autre composant pour le réglage, c'est trop cheap »).** La
> pilule de verre et les tuiles de la v1 sont **abandonnées**. Le réglage se
> fait avec le **commutateur obsidienne**, taillé dans la matière du slider.
> Maquette v2, faite des vrais pixels de l'app :
> <https://claude.ai/artifact/5ijMQQwXy3ptLt8988w3Z7>.

| Couche | Ce que c'est | Pourquoi |
|---|---|---|
| Fond | Noir absolu et **une seule** lune de blanc en haut (blanc 20 % → 0). **Image fixe** : ni `TimelineView`, ni vidéo. | C'est ce dégradé que le verre de la vitrine réfracte. Sur du noir pur, le verre ne montre rien. |
| Titre | « Réglages » / « Settings », Inter 34 gras, **encre en dégradé de blanc**, comme le titre de la fiche. | Le seul grand mot de la page. |
| Étiquettes | « LANGUE » / « DÉPART DE SÉRIE » en capitales espacées, 42 %, comme « DERNIÈRE CHARGE » dans la fiche. | La voix des petites légendes de l'app. |
| **Commutateur obsidienne** (×2) | La **piste du slider** et son **pouce chrome élargi** à une demi-piste. Le mot choisi s'écrit en blanc **dans** le pouce ; l'autre reste à 30 % sur la pierre. On le fait glisser au doigt, ou on touche un mot. Ressort de 0,5 s, haptique `.selection`. | C'est le composant qu'on a partout. Le pouce éclaire les lettres : c'est la loi du slider (`SliderObsidienne.texte`). |
| Vitrine de verre | Au-dessus du commutateur de départ, une plaque de verre liquide qui montre **ce que le choix lance** : le dôme nacré du galet, ou le slider. Les deux s'échangent en fondu, avec une montée de 3 pt et un flou. | On choisit ce qu'on voit, pas une étiquette. C'est aussi le seul verre de la page. |
| Sortie | Chevron maison, carré de verre sombre, comme sur la fiche. | Même grammaire que les autres pages immersives. |

**Texte total : 7 mots.** Réglages · Langue · Français · English · Départ de
série · Galet · Slider.

**Interdit ici** : aucun balayage, aucun reflet qui court. La seule lumière qui
bouge est celle du pouce sous le doigt. Pas de néon, pas de couleur.

#### Le commutateur en Swift : `CommutateurObsidienne`, un fichier neuf

- **Aucun nouveau shader.** On réutilise `sliderObsidienne`
  (`NavMonolith.metal:590`). Il prend déjà la position **et la demi-largeur**
  du pouce (`.float4(px, pw, ph, press)`, `SliderObsidienne.swift:306-327`).
  Le pouce élargi, c'est donc `pw = (W/2 − encart)/2`, et `px` est le centre
  de la moitié choisie.
- ⚠️ **Pas de `TimelineView` au repos.** `SliderObsidienne` en fait tourner
  une à 60 Hz tant qu'il est monté (`:198`). Pour le commutateur, on passe un
  `t` **fixe** au shader, et `px` devient une valeur animable (`Animatable`),
  animée par un ressort. Le shader ne se redessine que pendant les 0,5 s du
  ressort. Sa loi, mesurée le 05-09 : redessiner pour animer coûte 3 à 8 fois
  plus qu'animer.
- Le mot blanc « mangé » par le pouce : c'est le masque de
  `SliderObsidienne.texte`, repris (les lettres ne vivent qu'à l'aplomb du
  pouce).
- La vitrine n'affiche que des **images figées**, rendues une seule fois par
  `ImageRenderer` : le dôme de `LaunchPebble` endormi et le slider posé.
  Jamais deux shaders vivants.
- Barreaux : `-sansVitrine` et `-sansCommutateurShader` (le commutateur
  retombe alors en capsule plate). Banc : `-commutateurLab`.

### 1.3 Les effets, un par geste

1. **L'arrivée** : les deux sections montent de 3 pt, flou 6 → 0, décalées de
   90 ms. Un ressort unique, sans horloge.
2. **Le pouce glisse** d'un mot à l'autre. Le mot blanc suit le pouce, lettre
   par lettre.
3. **La langue change** : la page s'éteint au noir, le `TabView` renaît
   (`.id(langueApp)`) et la page se rallume dans l'autre langue. `selection`
   vit dans `RootView`, hors du `.id`, donc on reste sur Réglages.
4. **Le format change** : la vitrine échange le dôme et le slider, en fondu
   avec une montée.

### 1.4 La langue depuis Réglages : une seule porte

- On sort de `reecrireRevisite` une fonction `changerLangue(_:)`, **la même**
  pour la revisite et pour Réglages. Elle appelle
  `definirProfil(langue: x, prenom: nil, but: nil, objectifHebdo: nil)`,
  puis `Langue.poser` avec la réponse, et garde le cas de récupération.
- On **attend le serveur**, comme la revisite. Le serveur gagne à chaque
  `home()`, donc un cache posé seul serait défait au prochain retour à
  l'accueil. Pendant l'appel, le pouce reste à mi-course. En cas d'échec, il
  revient à sa place et l'haptique signale l'erreur (le refus grenat du
  slider).
- Mode maquette (`AppleAuth.Maquette`) : le cache seul, comme aujourd'hui.

### 1.5 La fiche en mode Slider

- **Même emplacement que le galet** (`ExerciseDetailView.swift:1063`) :
  `SliderObsidienne(label: L("Lancer la série", "Start set"), onConfirm: …)`.
- **Muscu** : `onConfirm` → `launchPosed()`, qui existe déjà.
  - On arrive **sur l'écran du chrono**, sans galet, sans monde blanc et sans
    sommet.
  - Le cadran joue son « 3, 2, 1, GO » (3,4 s), puis compte à partir de 0:00.
    C'est ce qu'elle a demandé dans les retours du TF85 (voir plus bas et D2).
  - `onLivePhase` / `suivreMuscu` sont inchangés, donc la Live Activity suit.
- **Cardio** : `onConfirm` → `lancerTapis(mode)`, déjà direct. Le « 3, 2, 1,
  GO » du premier set vient de l'étape 3 du plan TF85, dans la session
  woochoper-ios-ad.
- ⚠️ **Recouvrement avec les retours du TF85**
  (`tools/production/PLAN-RETOURS-TESTFLIGHT-85-2026-09-30.md`, session
  woochoper-ios-ad).
  - Son étape 3 touche `ExerciseDetailView`, `LiquidLensLab`, `SetEntrySheet`,
    `TapisScene`, `CardioFiche` et `ChambreHiit` (le 3-2-1 GO, le gainage en
    temps seul, les reps seules), avec la migration `strength_sets.duree_s`.
  - **Ordre : son étape 3 d'abord, le J2 de Réglages ensuite.** Le slider
    appellera alors le même départ, GO compris.
- **Piscine** : rien ne change.
- **Mode Galet** : chaque ligne actuelle est gardée.
- **La réserve de hauteur** : `reserveGalet = 172` (`:259`, `:1782`),
  `LaunchPebble.height` (`:1914`), et les graphes de `CardioFiche.swift:38-41`
  et `ChargeFiche.swift:87` suivent le mode. Le slider fait 68 pt, soit une
  réserve d'environ 110. Mesure au simulateur dans les deux modes : les
  graphes ne doivent pas sauter.
- **À surveiller** :
  - le départ posé met `dive = 8` (page zoomée ×8 **sous** la lentille
    opaque, `:395`, `:1103`). Il faut vérifier qu'elle ne se rend pas pour
    rien, puisqu'une vue cachée reste une vue rendue (piège « rideau ») ;
  - la condition de la nav (`:795`) : en mode Slider, `flood` reste à 0.
- **La transition** : la coupe existante (`CoupeEtat`), pas un nouveau film.

---

## 2. Décisions pour Kathryn

| # | Question | Recommandation |
|---|---|---|
| D1 | Le format **par défaut**, pour un compte neuf et pour un compte existant. | **Slider** (tes mots : « enlever le galet »). Le galet reste au choix dans Réglages. |
| D2 | « Direct sur le chrono » : on arrive **sur l'écran du chrono**, qui fait son « 3, 2, 1, GO » (3,4 s) ? Ou 0:00 tout de suite, sans GO ? | **Le GO reste.** Le slider ne remplace que le galet, le monde blanc et le sommet (environ 10 s). Ton retour du TF85 demande justement ce 3-2-1 GO. |
| D3 | Le choix du format suit-il le **compte** (serveur) ou le **téléphone** ? | **TRANCHÉ le 30-09 par Kathryn : le compte** (« il faut ajouter la règle backend aussi »). Migration `20260930120000_depart_serie.sql` **posée** : `user_prefs.depart_serie`, défaut `reward_rules.depart_serie_defaut = "slider"`, `depart_serie()` et `definir_depart_serie(p_format)`. Mesurée : `tools/reglages/verif_depart_serie.py`, 12 ✓ 0 ✗. |
| D4 | Le 4ᵉ point de la nav : glyphe et place. | **`gearshape`, en dernier**, après Profil. On ne remet pas Réglages dans le menu colonne : une seule porte. |
| D5 | Mots des tuiles : « Galet » / « Slider » en FR, « Pebble » / « Slider » en EN ? | Oui. |

---

## 3. Jalons, chacun avec sa preuve

**J0 : ce plan et la maquette HTML.** Fait. Pas de banc.

**J1 : l'onglet et la page Réglages.**
- Fichiers :
  - `NavDest.reglages` et ses deux ponts (`NavEncre.swift`) ;
  - `WoopTab.settings`, `order`, `Tab(…)` et `openTab` (au relancement, on
    retombe sur l'accueil, jamais sur Réglages) dans `NosfyApp.swift` ;
  - nouveaux fichiers `Nosfy/Views/ReglagesPage.swift`,
    `Nosfy/Views/CommutateurObsidienne.swift` (réutilise le shader
    `sliderObsidienne`) et `Nosfy/Services/DepartSerie.swift`.
- `changerLangue(_:)` sort de `reecrireRevisite`.
- Noms de la nav passés à `L()`.
- Les 9 dates en dur (§0.2) passent à la langue courante.
- Barreaux : `-sansVitrine` et `-sansCommutateurShader`. Bancs :
  `-reglagesLab` et `-commutateurLab`, ajoutés à la garde.
- Preuve :
  - simulateur FR → EN → FR ;
  - compte neuf **et** compte existant ;
  - capture et crops ×3.

**J2 : la fiche en mode Slider.**
- **Après l'étape 3 du TF85** (session woochoper-ios-ad).
- `ExerciseDetailView.swift` : emplacement du galet, `launchPosed()` branché
  sur le slider, réserve de hauteur.
- Hauteurs de `CardioFiche` et `ChargeFiche`.
- `LiquidLensLab` et `TapisScene` ne bougent pas si D2 = « le GO reste ».
- Drapeaux `-departSlider` et `-departGalet`, ajoutés à la garde.
- Preuve :
  - film au simulateur : muscu et cardio, dans les deux modes ;
  - VoiceOver (§0.5) ;
  - Live Activity ;
  - sortie par `quitterLaFiche` intacte.

**J3 : son iPhone.**
- Chauffe mesurée, thermique lu à 0 au départ :
  - Réglages immobile ;
  - fiche en mode Slider **contre** fiche en mode Galet.

  Méthode : skill `woop-performance`, sonde `-sondeVol`.
- Parcours complet dans les deux langues.
- Coordination du téléphone dans `MULTI-SESSION.md`.

**J4 : le site de doc, dans le même commit que le code.**
- `b-reglages-langue` : un nouveau site d'appel de `definir_profil`. Il passe
  🟢 **seulement** après un appel réel, réponse lue.
- `b-reglages-depart` : 🟡 local (en v1).
- Ensuite `npm run artefact`, puis `npm run verif`, puis republication au même
  lien.

**J5 : TestFlight.** Seulement avec la session TestFlight, sur ton ordre. **Ce
chantier n'est dans aucun build envoyé.**

---

## 4. Risques

- **Le mur du type-checker** : le `body` de la racine tombe dès qu'on lui
  ajoute un overlay. Le nouvel onglet est donc une sous-vue nommée, comme
  `ongletHome`.
- **Le verre `.interactive()` vole le geste** (piège payé) : il sert
  seulement sur les deux contrôles, jamais sur un conteneur qui défile.
- **La renaissance du `TabView`** quand la langue change coûte un pic unique.
  C'est acceptable sur un geste rare, et il faut le mesurer au J3.
- **Les hunks d'autres sessions** dans le slider, le galet, la lentille et le
  tapis (§0.4) : on les relit avant d'y toucher, et on commite par chemins.
- **Skills à charger avant le J1** : `woop-architecture` (la loi du verre) et
  `woop-performance`.
