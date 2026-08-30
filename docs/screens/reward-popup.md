# Écran — LA POP-UP DE RÉCOMPENSE (RewardPopup)

`Woop/Views/RewardCard.swift` (2694 l. — le composant et ses six robes) ·
décideur `Woop/Views/RestartSheet.swift:608-630` (`DecideurSerie`) · montage
de production `Woop/Views/ExerciseDetailView.swift:1086` (le `RewardPopup(`) ·
banc `Woop/Views/RewardLab.swift` (`-rewardLab`).

> **Convention de ce document.** Ce qui est écrit sans marque est **vérifié
> dans le code** (29-08, lecture ligne par ligne ; **relu le 30-08 au soir**,
> numéros de ligne relevés ce jour-là — `WoopApp.swift` et
> `SacreServeur.swift` sont dans l'arbre de travail d'une autre session, à
> re-relever avant tout patch). Ce qui porte **?** n'est pas sûr et attend une
> décision. Ce qui porte **CIBLE** est décidé mais n'existe pas encore. Ce qui
> porte **DÉCIDÉ 30-08** vient de `tools/annonces/PLAN-COFFRE-ANNONCES.md`
> (ses mots, §0 ; les dix défauts du §1 — « oui sur tout ») : **rien de tout
> ça n'est codé**, ni dans l'app ni au serveur. Ce qui porte **périmé** décrit
> l'état d'hier ; on le garde pour l'histoire, l'état d'aujourd'hui est écrit
> à côté. Les tables de la base ne sont pas décrites ici : seulement ce que le
> backend doit **décider** et **renvoyer**.

**Sa sœur** : [notification.md](notification.md). Les deux ne font qu'un
sujet — voir `tools/rewards/PLAN-ANNONCES.md` (l'analyse du couple) et, pour
ce qui est **tranché**, `tools/annonces/PLAN-COFFRE-ANNONCES.md` (30-08 : §3
le contrat par catégorie, §5.2 les pop-ups en séance, §5.3 le Welcome Back,
§6 les jalons J4-J5).

---

## 1 · Rôle

**Interrompre, quand ça vaut la peine.** C'est l'exact contraire de la
notification : la pop-up prend l'écran, éteint la page sous un scrim à 0,68, et
demande un geste pour repartir. Elle existe pour les ~40 % de fins de série
qui « méritent » quelque chose.

Elle porte trois intentions, aujourd'hui mélangées dans le même composant :

1. **Le MOMENT** — raconter un fait vrai de la séance en cours (« 12 reps at
   40 kg — that's 240 coins so far »).
2. **Le REWARD** — annoncer un gain, avec sa vidéo les grands jours.
3. **Le WELCOME BACK** — le versement de retour, seule robe à porter un
   bouton `Claim`.

⚠️ **Aujourd'hui aucune des trois ne crédite quoi que ce soit** (§3).

**DÉCIDÉ 30-08** (plan §0, §1 Q1-Q3, §3) : la pop-up s'ouvre aux rangs
**3 / 5 / 10**, puis **un rang au hasard toutes les 5 à 8 séries**, sous un
budget de **4 par séance** (1 en pièces, 1 vidéo) et un écart minimal
« 3 séries ET 6 min » pour les rangs tirés ; **l'IA écrit les mots, jamais un
chiffre** — elle choisit de quel fait parler, les nombres viennent des faits ;
et elle sert la **prochaine** pop-up, jamais attendue. Le « ~40 % » ci-dessus
est l'état d'aujourd'hui (tous les multiples de 3 et de 5), pas la cible.

---

## 2 · Affiche

**La carte** : largeur `min(80 % de l'écran, 332 pt)`, ratio 1,32, rayon 36,
scrim noir 0,68, ombre **blanche** vers le bas, un tilt 3D au gyro. Sur toutes
les robes : 72 grains de poudre de diamant en `Canvas` 30 Hz, un tick de
cadran par chiffre qui monte, un boum à l'atterrissage, un arpège de cristal.

**Six robes** (`RewardStyle`), plus un dédoublement de la sixième
(`WelcomeRobe`) — donc **sept dressages** :

| Robe | Ce qu'on voit | Vidéo | Boutons |
|---|---|---|---|
| **`.halo`** | le voile s'OUVRE vers le bas, deux nappes blanches montent du sol en `.screen`, chiffre argent 190 pt, chiffres fantômes ±1 rognés par les flancs | optionnelle — ⚠️ **avec une vidéo, le halo et les fantômes disparaissent** et le chiffre tombe à 118 pt | Close |
| **`.neon`** | plus rien de néon : « YOU / MADE / IT » en mots géants, lampe en éventail, chiffre en **vrai verre** saisissable au doigt. **Pas de titre.** Le sous-titre seul en bas | — | Close |
| **`.galet`** | comme `.halo` mais halo de sol discret, et par-dessus le chiffre un **galet de verre** de 152 pt qui dérive, s'incline au gyro, se saisit | — | Close |
| **`.spotlight`** | ⚠️ **la carte n'est plus noire** (dégradé opaque gris→noir) ; vidéo de fond `fond-matrice-loop` **câblée en dur**, bord à bord ; le nombre **en toutes lettres** tout en haut ; chiffre en métal sombre sous une trame de micro-mots qui pleut. **Ni titre ni sous-titre** | fond en dur, + le slot | Close |
| **`.fire`** | braise rouge, chiffre à **430 pt quasi invisible** (blanc 0,028) que seul le balayage du spot révèle, sticker flamme au centre ; au tap, gerbe de 42 sprites + **secousse à force double** | optionnelle | Close |
| **`.welcome` / `.video`** | carte repeinte en **noir plein**, tilt 3D coupé, header vidéo en boucle sur 56 % de la hauteur, projecteur qui monte du bas, titre+sous-titre sous la vidéo | `reward-welcome`, **en boucle** | **Claim** + Later |
| **`.welcome` / `.texte`** | pas de vidéo ; « YOU'RE / BACK » en mots géants, pastille lune qui flotte, la chauve-souris **statique** au bord haut. Ni titre ni sous-titre | — | **Claim** + Later |

⚠️ **Le contrat de texte n'est pas uniforme** : `title` est **jeté** par
`.neon`, `.spotlight` et welcome/`.texte` ; `subtitle` est jeté par
`.spotlight` et welcome/`.texte` ; `unit` est jeté par `.neon` et `.welcome`.
Le backend peut remplir les quatre champs et n'en voir aucun à l'écran selon
la robe.

⚠️ **Aucun mot géant ne vient d'un champ de texte de l'API** — mais le fil
existe déjà, et c'est une nuance qui change le travail restant. Sur les trois
montages de `TexteGeant` : `.spotlight` **passe** `lignes:` (`:408`, le nombre
en toutes lettres dérivé de `count`), welcome/`.texte` **passe** deux
littéraux (`:503`), et `.neon` seul laisse jouer le défaut « YOU / MADE /
IT ». Il ne manque donc pas un fil à tirer : il manque **une source** — et le
commentaire du composant pose déjà la loi qui la borne, *« l'IA fournit les
MOTS, jamais la mise en forme d'une donnée »*.

**Ce que la production affiche vraiment** : `count: max(séries faites, 4)` —
⚠️ **un plancher de 4 en dur**, artefact de banc resté dans le chemin réel :
aux séries 1, 2 et 3 la carte annonce « 4 ». Titre `"Training"`, sous-titre
`"Congratulations, you've completed your training!"`, unité `"Sets"` — quatre
chaînes anglaises en dur au site d'appel, hors de tout catalogue.

---

## 3 · Actions

| # | Action | Geste | Appel backend |
|---|---|---|---|
| A1 | **Fermer** | le lien du bas (« Close », ou « Later » en welcome), 44 pt | **aucun** |
| A2 | **Claim** (welcome seulement) | la capsule de verre « Claim · +N » avec la pièce 3D | ⚠️ **aucun** — son action est *littéralement* `fermer`, la même que Later (`RewardCard.swift:874` : `BoutonClaim(montant: count, action: fermer)`). **DÉCIDÉ 30-08** : le tap **paie** — il poste `.retourQuotidien` et pousse la dalle « +10 » (plan §5.3, J2) |
| A3 | **Fermer au scrim** | taper à côté de la carte | aucun |
| A4 | **Relancer la vidéo** | taper la vidéo (elle rembobine) | aucun |
| A5 | **Reculer la vidéo après le gel** | incliner le téléphone ou glisser — le playhead recule jusqu'à 2,4 s | aucun |
| A6 | **Saisir le verre** | le galet (`.galet`) ou le chiffre de verre (`.neon`) : prise, dérive, retour en ressort | aucun |
| A7 | **Attiser le feu** (`.fire`) | taper : 42 sprites de flamme + secousse | aucun |

⚠️⚠️ **AUCUN APPEL RÉSEAU DANS TOUT LE COMPOSANT NI DANS SA CHAÎNE.** `grep`
sur `URLSession|Supabase` dans `RewardCard.swift` : **zéro occurrence**. Le
geste de récompense est entièrement décoratif.

⚠️ **Le montant du Claim est faux** : le bouton affiche `count`, qui est un
**nombre de SÉRIES**, pas des pièces. Pour 4 séries il annonce « +4 » là où
l'économie de la maison en donne **80**.

⚠️ **La carte est inerte pendant 1,45 s** : `fermer()` sort immédiatement tant
que la rampe d'entrée n'est pas finie. Close, Later, Claim et le scrim sont
morts, sans aucun signe à l'écran.

### Ce qui l'ouvre

| Porte | Statut | Ce qu'elle produit |
|---|---|---|
| **fin de série** — `DecideurSerie.pour` (`ExerciseDetailView.swift:2241`) → `jouerIssue` (`:2277-2301`) → `rewardShow = true` | **production** | `RestartSheet.swift:614-628` : `% 10 == 0` → `.fire` + vidéo `reward-rare` · `% 5 == 0` → `.halo` · `% 3 == 0` → `.moment` en `.galet` · sinon la pill. ⚠️ Ce sont **tous les multiples** de 3 et de 5 — 3, 5, 6, 9, 10, 12, 15, 18, 20… — **pas « 3/5/10 »** : sans hasard, sans budget, sans horloge, sans serveur. **DÉCIDÉ 30-08** : rangs fixes **3 / 5 / 10**, puis un rang au hasard toutes les 5-8 séries sous budget (plan §3, §5.2 point 7, J4) |
| **le chip « … » du header** (`ExerciseDetailView.swift:1885-1897`) | ~~production, sans aucun drapeau~~ **périmé depuis le 29-08** : derrière **`-rewardAtelier`** (`:1888`), plus dans l'app livrée (§10) | fait tourner les **six** robes et ouvre une récompense **fausse** — au banc seulement |
| neuf drapeaux de banc (`-rewardAuto`, `-spotLab`, `-rewardVideo`, `-rewardDemo`, `-fireLab`, `-welcomeTexte`, `-welcomeLab`, `-ymiLab`, `-rewardFlow`) | bancs | — |
| `RewardLab` (`-rewardLab`) · `RewardChemin` (`-rewardChemin refneon`) | bancs | — |

⚠️ **Le décideur ne sait produire que TROIS robes sur six** : `.fire`,
`.halo`, `.galet`. **`.neon`, `.spotlight` et `.welcome` n'ont aucun chemin
depuis le jeu** — elles ne s'ouvrent que par le chip « … » ou par un drapeau.

**Périmé depuis le 29-08 — LE RANG ÉTAIT DÉCALÉ D'UN CRAN** (gardé pour
l'histoire ; corrigé, §10). `faites` était lu **synchroniquement** juste après
`settleSeries(f, coins: true)` — or cette écriture est **différée de 0,55 s**.
Le décideur jugeait donc le rang de la série **précédente** :

| ce que le code voulait | ce qui arrivait à l'écran (28-08) |
|---|---|
| MOMENT à la 3ᵉ série | à la **4ᵉ** |
| pop-up `.halo` à la 5ᵉ | à la **6ᵉ** |
| vidéo rare à la 10ᵉ | à la **11ᵉ** |

Et la pill **sous-comptait de 20 pièces** à chaque fois (`max(faites,1) * 20`).
Le banc `-serieFin` passait `serie: n` en dur — il ne reproduisait pas le
décalage, donc ne pouvait pas le révéler.

**Aujourd'hui** (`ExerciseDetailView.swift:2234-2244`) : la série en cours
compte pour elle-même (`ecrites + 1`, sauf si elle était déjà écrite), le rang
est **mémorisé** dans `rangIssue` (`:2240`) et passé au décideur avec
`total = rang × gainParSerie` (`:2243`) — le MOMENT retombe à la 3ᵉ, la
pop-up à la 5ᵉ, la vidéo à la 10ᵉ, la pill ne sous-compte plus.

---

## 4 · Sorties

| Depuis | Vers |
|---|---|
| **Close / Later / Claim / scrim** | la carte s'efface en 0,42 s, puis `onClose()` |
| `onClose` depuis la fin de série | le panneau **« Recommencer ? »**, +0,26 s — *« un seul chemin vers le panneau »*, et le code le tient |
| `onClose` depuis le chip « … » | rien : on reste sur la fiche |
| `onClose` sous `-rewardDemo` | la **combinaison suivante** (12 combos en boucle) |

**Qui entre ici** : uniquement la **fiche exo**. La pop-up n'est montée nulle
part ailleurs en production — ni sur la home, ni sur le chemin, ni en fin de
séance (qui a ses propres annonces). **DÉCIDÉ 30-08** : la robe `.welcome`
gagne une **porte sur la home** — au premier plan, si
`etat_coffre().retour_disponible` (clé serveur nouvelle, lue sans payer) → la
card ; Claim → outbox → dalle « +10 » (plan §4 M1 point 7, §5.3, J2). La
pop-up « Ouvrir » après la route animée n'est **pas** ce composant : c'est la
card sachet (`BoosterCardHote`), une invitation, pas une annonce (plan §1 Q4).

---

## 5 · États

| État | Aujourd'hui | CIBLE |
|---|---|---|
| **entrée** | une rampe de 1,45 s (chiffre qui monte, sons, atterrissage). ⚠️ **Tous les boutons sont morts pendant ce temps**, sans aucun signe | **DÉCIDÉ 30-08** (plan §1 Q8, §5.3) : le Claim **paie au tap** — le montant est local (10, lu du serveur), la dalle « +10 » part tout de suite, l'outbox poste `.retourQuotidien` et **l'index (user, jour) rattrape** ; si le serveur dit « déjà pris » (autre appareil), rien ne s'affiche de plus. Le trou d'1,45 s reste à distinguer d'un bouton mort |
| **chargement** | **n'existe pas** — rien n'est distant | **n'existera pas non plus** : la loi « le montant est local, le journal rattrape » (plan §1 Q8) — pas d'état d'attente sur le Claim, pas de spinner ; la robe ne s'ouvre que si `retour_disponible` a été lu **avant** (la porte, §4) |
| **vide** | ⚠️ **n'existe pas non plus, et c'est un bug** : sous 4 séries la carte affiche « 4 » (plancher en dur) | le vrai compte, ou pas de carte |
| **erreur** | **aucune gestion** ; si la vidéo manque du bundle, la vue reste **un rectangle noir muet**, sans repli ni message | un repli visible ; le Claim doit dire son échec, il a coûté un geste |
| **vidéo finie** | gel sur la dernière image (`actionAtItemEnd = .pause`), puis elle « revit » au tilt (recul jusqu'à 2,4 s) ; ⚠️ **une seule finit sur du noir** (`reward-fire`, YAVG 16) — les autres gèlent sur une image claire | **?** le gel sur une image claire est-il voulu ? |
| **welcome en boucle** | ⚠️ la boucle est un `seek(.zero)` sur `didPlayToEndTime` — **la forme que la maison interdit par écrit** (elle laisse une image noire au raccord) ; et l'observateur **n'est jamais retiré** (pas de `dismantleUIView`) : chaque ouverture laisse un lecteur vivant | `AVPlayerLooper`, et la vidéo palindrome qui existe déjà (§6) |
| **reduceMotion** | ⚠️ **non respecté** par trois `TimelineView` (la lumière des mots géants, la lampe en éventail, le projecteur de welcome) : ils balaient à 30 Hz quoi qu'il arrive | à corriger |

---

## 6 · Les vidéos

**Douze fichiers de la famille, 15,1 Mio.** Toutes 1080p H.264 24 fps, muettes.

| vidéo | poids · durée | qui la joue |
|---|---|---|
| `reward-rare` | 1,28 Mio · 8,04 s | **production** — la seule que le moteur sait montrer (`serie % 10 == 0` : 10, 20, 30… — **DÉCIDÉ 30-08** : une seule fois par séance, au rang 10, plan §1 Q2) |
| `reward-nosfy-coins` | 2,66 Mio · 14,00 s | **production** — la card à gratter du chemin, **en boucle infinie** dans un header de 232 pt |
| `duo-nosfy-reward` | 0,30 Mio · 5,92 s | **production** — la fente du panneau de départ (210×234, cuite au ratio) |
| `reward-welcome` | 0,99 Mio · 7,04 s **portrait** | production *par le chip « … »* seulement |
| `reward-fire` · `reward-lune` · `reward-piece-1..5` | 7,93 Mio | ⚠️ **bancs uniquement** — jamais vues par une utilisatrice |
| `reward-welcome-loop` | 1,91 Mio · 14,00 s | ⚠️ **ORPHELINE** — son nom n'apparaît nulle part dans le code |

⚠️ **`reward-welcome-loop` est le palindrome cuit de `reward-welcome`** — la
vidéo faite pour boucler proprement, et c'est **mesuré au pixel**, pas déduit
d'une durée : la différence moyenne entre l'image `t` et son symétrique vaut
**0,37 à 0,58** contre un témoin de **5,15 à 7,35** entre deux instants
réellement différents, et sa première moitié est `reward-welcome` (écart 0,12
à 0,19). ⚠️ Elle fait **336 images = 169 + 167**, pas le double exact : un
palindrome correct ne redouble pas ses deux images extrêmes — un fichier
« exactement double » serait justement un palindrome **raté**.

La robe welcome boucle donc **la mauvaise vidéo** — la version non
palindromique, recousue par un `seek(.zero)`. **?** remplacement oublié, ou
fichier abandonné ?

⚠️ **6,14 Mio de vidéo morte partent dans le binaire** :
`reward-welcome-loop`, `coffre-salle-loop`, `coffre-salut`. Le groupe `Woop`
est synchronisé **sans exceptions** — tout ce qui est dans le dossier est
copié.

⚠️ **Deux `reward-piece-*` n'ont PAS de chauve-souris** : `piece-3` (deux
pièces de verre en rotation) et `piece-5` (une pièce dans un cube). Vérifié à
plusieurs instants. Elles sont pourtant rangées dans la même table de rotation
que les autres — **?** plans « objet nu » voulus, ou prises à refaire ?

⚠️ **Aucune version courte n'existe**, alors que le plan la déclare
obligatoire (*« 7-9 s c'est LONG en pleine séance »*). `reward-rare`
immobilise **8 s de séance toutes les 10 séries** aujourd'hui, et rien ne
l'écourte. **DÉCIDÉ 30-08** : la vidéo **une seule fois par séance** (budget
« 1 vidéo », clé `popup_rang_video = 10`, plan §4 M2), le budget tenu en
mémoire de séance ; la version courte reste à cuire.

**La recuisson du 25-08 n'a laissé aucun script** : la recette (4K HEVC →
1080 H.264, `trim + setpts` dans le graphe) ne vit qu'en prose. La prochaine
vidéo se recuit de mémoire, et le piège du `-ss` se repaie.

---

## 7 · Le backend et ses règles

> Le détail vit dans `tools/rewards/PLAN-REWARDS-BACKEND.md` (§2 pacing,
> §3 faits, §4 IA, §5 contrat design) et l'analyse du couple dans
> `tools/rewards/PLAN-ANNONCES.md`. ⚠️ **Ce que ces deux plans disent du
> rythme est périmé depuis le 30-08** : le §2 du plan rewards interdit « tout
> déclencheur à position fixe (série 5/10/15) » (`:79`) — Kathryn a tranché
> **des rangs fixes 3 / 5 / 10, puis du hasard** (`PLAN-COFFRE-ANNONCES.md`
> §0, §1 Q1-Q2, §2.7). La référence des décisions est ce dernier plan.

### 7.1 Ce que le backend doit fournir — ce qui existe, ce qui manque

| Ce qu'il faut | État (relu le 30-08 au soir) |
|---|---|
| **le moteur de décision** (budget, écart minimal, priorité) | ⚠️ **n'existe pas** — ce qui décide est `serie % 10 / 5 / 3` (`RestartSheet.swift:614-628`), donc **tous** les multiples, sans budget ni horloge. ~~Exactement le « déclencheur à position fixe » que le plan §2 interdit~~ **périmé** : **DÉCIDÉ 30-08**, les positions fixes **3 / 5 / 10 sont voulues**, puis un rang au hasard toutes les 5-8 séries (hasard déterministe par séance), budget 4 / 1 pièces / 1 vidéo, écart « 3 séries ET 6 min » pour les rangs tirés. Le rang est **tiré au client depuis les clés serveur** (M2 : `popup_rangs_fixes`, `popup_rang_video`, `popup_hasard_ecart_min/max`, `popup_hasard_apres`) — **pas de moteur serveur, pas de table `popup_servies`** : une pop-up ne paie rien (plan §4 M2 + « ce qu'on ne fait pas », §5.2 point 7, J4) |
| **le fact engine** | ~~n'existe pas, ni serveur ni local~~ **périmé depuis 6557a90 (30-08)**. Ce qui existe et est **DÉPLOYÉ** : la table `workout_facts` et `poser_faits_seance(p_workout, p_jour, p_faits)` (`supabase/migrations/20260830100000_moteur_faits.sql:42-69, 116-178`). Sondé le 30-08 : `rpc/poser_faits_seance` sans corps → **400 P0001** (la garde `:128-130` qui répond — la fonction existe ; un témoin inventé → 404 : `PLAN-COFFRE-ANNONCES.md` §2.7) ; `GET workout_facts` 404 → 200, rejeu → 23505 (`docs/site/content/sondes.ts:16`, `tools/story/test_flow_faits.sh`). **Ce qui reste vrai** : **personne ne l'appelle** (`grep poser_faits_seance Woop/` → 0 ; site `b-st-moteur-faits` 🔵), et ses faits sont des faits de **SÉANCE** — `top_muscu`, `top_cardio`, `double_jour` (`:65-66`), pour les stories — **pas de série** : le `{kind, value, unit, comparison, window, rank}` par série de ce chantier n'existe toujours pas. Et l'app **calcule**, le serveur **range** (`:20-26`) : le calcul côté app reste à écrire (chantier stories, hors lot) |
| **le crédit d'une pop-up** | ⚠️ **n'existe pas** : `.moment` et `.reward` ne font que `rewardShow = true` (`ExerciseDetailView.swift:2298-2299`). **DÉCIDÉ 30-08** : ce n'est plus un manque — une pop-up **ne paie rien**, elle raconte ; le gain est celui de la série (20, `cloturer_seance`), et c'est la dalle qui l'annonce (plan §3, §4 « ce qu'on ne fait pas ») |
| **le claim du Welcome Back** | ✅ le versement part **tout seul** : à chaque `scenePhase == .active` (`WoopApp.swift:83-92`), `reglerRetourQuotidien()` (`SacreServeur.swift:282-291`) poste `.retourQuotidien` **une fois par jour UTC** (marqueur `UserDefaults`, `:286-289`) → `claim_retour_quotidien()` → +10, **sans dalle**. ⚠️ Le bouton `Claim` de la card n'appelle toujours rien (`RewardCard.swift:874` : `action: fermer`), et la robe n'a **aucune porte de production** (bancs `-welcomeLab` / chip d'atelier). **DÉCIDÉ 30-08** : **au tap**, et **minuit Paris** — clé serveur `fuseau_jour = "Europe/Paris"`, jamais le fuseau du téléphone ; `etat_coffre().retour_disponible` lu sans payer pour ouvrir la porte ; le Claim poste, la dalle « +10 » part au tap ; `reglerRetourQuotidien()` quitte le `scenePhase`, le marqueur UTC disparaît (plan §1 Q7-Q8, §4 M1 points 1-2 et 7, §5.3 ; site `b-rg-le-versement-lui-part-vraiment` 🟢 + litige) |
| **le contrat par catégorie** (quelle robe pour quel événement) | ~~annoncé au §4 du plan, jamais écrit~~ **ÉCRIT le 30-08** : `PLAN-COFFRE-ANNONCES.md` **§3** — le tableau « quand… / annonce / robe / qui sait quoi » (dalle « +20 » à la série ordinaire ; `.galet` (3) · `.halo` (5) · `.fire` + vidéo (10) · au hasard ensuite ; `.welcome` au 1er lancement après minuit Paris ; `.neon` et `.spotlight` **hors contrat**, à retirer si rien ne les prend). On y renvoie, on ne le recopie pas |
| **les clés de pacing dans `reward_rules`** | ~~la table ne porte que quatre prix~~ **périmé depuis le 29-08** : les clés de rythme sont en base (`20260829120000_annonces.sql:96-152` — 21 comptées ici, le plan en dit 22) et `regles_annonces()` les rend (`:174-181`) ; **personne ne les lit** (grep Swift : un commentaire, `ExerciseDetailView.swift:2269`). **DÉCIDÉ 30-08** : + 5 clés de rangs (M2), lues en début de séance par `SacreServeur.reglesAnnonces` (J4) |
| **l'IA qui écrit le texte** (`narrate-reward`) | ⚠️ **n'existe pas — MESURÉ le 30-08** : `supabase functions list` → `forge-card` seule (ACTIVE v4, `verify_jwt` true) ; `POST /functions/v1/narrate-reward` → **404** (`PLAN-COFFRE-ANNONCES.md` §2.2). Sa forme est **DÉCIDÉE** — §7.2 et plan §4 E1 |

### 7.2 L'IA : ce qui existe vraiment

Deux edge functions **dans le dépôt** (`supabase/functions/`), et **une seule
au serveur** (`functions list`, 30-08) :

- **`forge-card`** — ✅ appelée par le manège du Sacre. GPT-5 écrit une
  *scène*, `gpt-image-1` la peint, l'URL revient. ⚠️ Le texte de GPT-5 n'est
  **jamais affiché** : c'est un prompt pour le peintre. La clé vit dans
  l'edge function, l'appelant est vérifié (`admin.auth.getUser`), la rareté
  n'est **jamais** acceptée du client, et depuis 9ef6da1 (30-08) elle
  **scelle** la carte sur le sachet (`booster_id`) avant de créditer la
  collection. **C'est le patron à copier.**
- **`weekly-synthesis`** — Claude écrit 4-6 phrases françaises.
  ⚠️ **Écrite, jamais déployée, jamais montée** (sondé 30-08 : absente de
  `functions list`, `POST` → 404 — site `b-edge-weekly` ⚪) : la seule vue qui
  l'affiche (`SynthesisCard`) vit dans `ProgressionView`, qui **n'est montée
  nulle part** — l'onglet Progrès affiche le calendrier depuis le 18-08.
  ⚠️ Son auth ne vérifie que le préfixe « Bearer », sans valider le jeton —
  sans conséquence tant qu'elle n'est pas au serveur.

⇒ **Aucune IA n'a jamais écrit un texte affiché dans cette app.** On ne peut
pas dire « ça marche déjà, on recopie » : ni la latence, ni le rendu, ni
l'échec n'ont été vus.

Ce qui manquait pour que l'IA écrive un titre de pop-up — et ce que le 30-08
en a **décidé** (plan §4 E1, §5.2 points 8-9, J5 ; rien n'est codé) :
1. **un contrat JSON typé** — les deux fonctions rendent du texte libre.
   **DÉCIDÉ** : sortie **forcée par schéma JSON** `{fact_id, title ≤ 22,
   subtitle ≤ 64, big_lines[1-3] ≤ 8 signes, style ∈ enum, video ∈ enum,
   headline:{value, unit}}` ; `headline.value` **recopié** d'un fait d'entrée,
   rejet serveur sinon → gabarit. L'IA choisit le fait et les mots, **jamais un
   chiffre** (§1 Q3) ;
2. **des bornes de longueur** — il n'y en a **nulle part** : ni dans le
   prompt, ni côté serveur, ni au rendu (`Text(title)` sans `lineLimit`,
   `RewardCard.swift:760-778` ; `TexteGeant` `:1825-1843`). Un titre de 40
   signes casse la carte. **DÉCIDÉ** : les bornes du schéma côté serveur, et
   `RewardPopup` apprend à recevoir `bigLines` / `actionLabel` avec
   `lineLimit` + troncature (§5.2 point 9) — **préalable à tout texte IA** ;
3. **une persistance** — un texte non stocké se regénère : la même série
   raconterait deux histoires. **DÉCIDÉ** : une table `reward_narrations
   (user, workout, serie_index)` **seulement** si le rejeu doit rendre le même
   texte — **pas au J1** ; au J5, log `{facts_in, json_out, model, ms}` dans
   la console de la fonction ;
4. **un budget de latence** — `forge-card` assume 60-90 s ; une fin de série
   n'a pas ce budget. **DÉCIDÉ** : l'IA sert la **PROCHAINE** pop-up — à la
   fin de la série N (après `jouerIssue`, `ExerciseDetailView.swift:2245-2247`)
   la fiche envoie les faits (rang, exo, reps, kg, total, record éventuel)
   **dans le corps** à `narrate-reward` et range la réponse dans
   `prochaineAnnonce` ; à N+1 la pop-up lit ce qui est prêt, sinon le
   **gabarit** (le `.moment` actuel généralisé, un par sorte de fait) ;
   `AbortController` à **10 s** et `ms` mesuré dans la réponse ; **jamais
   d'attente, jamais de spinner**. Modèle : celui de forge-card (`gpt-5`,
   `reasoning_effort: low`), le seul appel IA vérifié en prod.

⚠️ Et **ne pas copier** de `ForgeServeur` le repli sur un **compte de test aux
identifiants en dur dans le binaire** : une fonction facturée au token serait
ouverte à qui désassemble l'app.

---

## 8 · Bancs

| Argument | Effet |
|---|---|
| `-rewardLab` | le banc : la carte seule sur du noir, rien d'autre monté |
| `-robe <nom>` | `halo\|neon\|galet\|spotlight\|fire\|welcome\|welcomeTexte` |
| `-rewardFreeze <p>` | cloue la rampe d'entrée (captures) |
| `-rewardT <s>` | fige l'horloge des vies |
| `-rewardMire` | graduations 20 pt + axes |
| `-rewardAuto` | balaye les six robes en boucle, depuis la fiche |
| `-rewardDemo` | 12 combos (robe, vidéo) enchaînés par « Close » |
| `-rewardVideo` · `-rewardFlow` | la table des vidéos ; une série sur cinq porte une vidéo |
| `-spotLab` · `-fireLab` · `-welcomeLab` · `-welcomeTexte` · `-ymiLab` | une robe à la fois |
| `-serieFin <n>` | rejoue l'issue de la n-ième série (rang passé en dur — il ne pouvait donc pas révéler le décalage, corrigé le 29-08) |
| **`-rewardAtelier`** | rend le chip « … » du header, qui fait tourner les six robes. **Sans lui, la pop-up n'a plus qu'une seule porte : la fin de série** |

⚠️ **Le banc ne couvre pas les combinaisons robe + vidéo** : il ne passe
`videoNom` que pour welcome. Or `.halo` **perd son halo et ses fantômes** avec
une vidéo, et c'est `.fire` **avec** `reward-rare` que la production sert.

---

## 9 · À vérifier au téléphone

Rien n'a été validé sur l'appareil : la saisie du galet et du chiffre de
verre, le recul de la vidéo au gyro, la secousse du `.fire`, les sons et
haptiques, la cadence des robes à deux décodeurs (`.spotlight` + vidéo), et
le trou d'inertie de 1,45 s au doigt.

---

## 10 · Le ménage

### ✅ Fait le 29-08

| Quoi | Ce qui a changé |
|---|---|
| **Le décalage d'un rang** | le rang est calculé en tenant compte de l'écriture différée (la série en cours compte pour elle-même) **et MÉMORISÉ** dans `rangIssue` — une relecture de `sets` changerait de valeur sous la card, entre sa naissance (+0,34 s) et l'écriture (+0,55 s). Le MOMENT retombe à la 3ᵉ série, la pop-up à la 5ᵉ, la vidéo rare à la 10ᵉ, et la pill ne sous-compte plus |
| **Le plancher `max(…, 4)`** | ne vaut plus que pour l'**atelier**, là où il avait été écrit. Le jeu dit le vrai rang |
| **Le chip « … »** | derrière **`-rewardAtelier`**. Il n'est plus dans l'app livrée — il ouvrait une récompense fausse, atteignait le Welcome Back en deux taps, et sa fermeture **ouvrait le panneau « Recommencer ? »** |
| **Le Claim en séries** | la robe welcome annonce des **pièces** (`10`) avec l'unité `Coins`. ⚠️ Constante Swift **provisoire**, à remplacer par `regles_annonces()` |

### Ce qui reste

| Quoi | Où |
|---|---|
| ⚠️ le **`seek(to: .zero)`** et l'**observateur jamais retiré** | `RewardCard.swift:2560-2567` |
| ⚠️ `reduceMotion` ignoré par trois horloges | — |
| ⚠️ la constante `piecesRetourQuotidien = 10` doublant la base | `ExerciseDetailView.swift:2270` — **DÉCIDÉ 30-08** : retirée au profit de la réponse serveur (plan §5.3 point 10, J2) |
| ⚠️ le décideur à **tous** les multiples de 3 et de 5 | `RestartSheet.swift:614-628` — **DÉCIDÉ 30-08** : décideur à budget, rangs 3/5/10 puis hasard (J4) |
| ⚠️ `RewardPopup` sans bornes ni entrée pour des lignes géantes | `RewardCard.swift:68-82, 760-778, 1825-1843` — **DÉCIDÉ 30-08** : `bigLines`, `actionLabel`, `lineLimit` + troncature (J4, préalable à J5) |
| code mort : `disqueNuit`, `ChiffreNeon`, `UnitePlate` (~150 l.) | `RewardCard.swift` |
| 6,14 Mio de vidéo orpheline dans le bundle | `Woop/Media` |
| robes `.neon` et `.spotlight` **hors contrat** (aucun événement, plan §3) | `RewardCard.swift` — à retirer si rien ne les prend |

---

## 11 · Ce qui est DÉCIDÉ le 30-08, et où ça se lit

Rien de ce tableau n'est codé. La source est
`tools/annonces/PLAN-COFFRE-ANNONCES.md` ; on y renvoie, on ne le recopie pas.

| Décision | Où dans le plan | Jalon |
|---|---|---|
| rangs fixes **3 / 5 / 10**, puis un rang au hasard toutes les **5-8** séries ; vidéo **une** fois, au 10 | §0, §1 Q1-Q2, §4 M2 (5 clés `popup_*`), §5.2 point 7 | J4 |
| budget **4 / séance**, 1 en pièces, 1 vidéo, 6 dalles ; écart « 3 séries **ET** 6 min » ; une dalle ne consomme pas le budget | §0, §3 ; les clés `ecart_exige_les_deux = true` et `notif_consomme_budget = false` sont déjà en base (`annonces.sql:110, 150`), personne ne les lit | J4 |
| l'IA écrit les **mots**, choisit le **fait**, n'invente jamais un chiffre ; elle sert la **prochaine** pop-up | §1 Q3, §4 E1, §5.2 points 8-9 | J5 |
| le contrat par catégorie (robe ↔ événement) | §3 | écrit |
| Welcome Back : **au tap**, **minuit Paris** (clé `fuseau_jour`), porte sur la home via `retour_disponible`, dalle « +10 » au tap | §1 Q7-Q8, §4 M1, §5.3 | J1 (serveur) + J2 (app) |
| une pop-up **ne paie rien** ; pas de table `popup_servies` | §4 « ce qu'on ne fait pas » | — |
| `.neon` et `.spotlight` hors contrat | §3 | — |

**La porte de sortie du J4, mesurée** (plan §6) : 30 séries au banc →
pop-ups à 3, 5, 10 puis 15-18, 21-26… ; jamais 6 / 9 / 12 ; ≤ 4 ; une vidéo ;
écart tenu. Tant que ça n'a pas été mesuré, ce document décrit les modulos.
