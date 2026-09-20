# Le médaillon rejoue Nosfy — analyse avant de coder (20-09-2026)

**Sa demande (20-09, après la refonte du Profil) :** « quand on clique sur la
pastille avec l'initiale, on revoit tout le scénario de l'onboarding, mais on
ne peut pas modifier les réponses sauf le prénom — pas la langue, ça va être
compliqué — et un chevron est toujours présent qui revient à la page profil.
Attention à la chauffe. Ne code pas, analyse. »

Rien n'est codé. Ce document dit ce qui existe, ce qu'il faudrait toucher, où
ça peut casser, et ce qu'elle doit trancher.

---

## 1. Ce qui existe aujourd'hui (lu, pas deviné)

### Le film — `Nosfy/Views/NosfyOnboarding.swift` (2 203 lignes)

Neuf étapes, dans cet ordre (`enum Etape`, l. 166) :

| étape | ce qu'elle voit | ce qui coûte | durée |
|---|---|---|---|
| `intro` | le poème + la bande `nosfy-nuit` (vidéo AVEC son, 300 × 200) puis Nietzsche sur le noir | une vidéo + son, `MotsFlou` (flou animé mot par mot) | 19 s, **pas de saut au tap** (son verdict 13-09) |
| `accueil` | la bête `nosfy-accueil-loop` + la tirade « Bienvenue dans mon univers noir » | une vidéo en boucle, le halo qui s'allume (6 flous, transformés par ressorts) | ~10 s, saut au tap |
| `langue` | « Dans quelle langue dois-je vous parler ? » + 2 cards | halo | tap |
| `prenom` | « comment dois-je vous appeler ? » + le champ | halo, clavier | saisie |
| `but` | 3 cards (force / poids / forme) | halo | tap |
| `jours` | la semaine tapable, « trois fois. » | halo | 2,4 s après le dernier tap |
| `bien` | « Bien. » | halo qui s'embrase | 1,6 s |
| `fin` | `nosfy-end` plein écran AVEC son, la musique se retire | une vidéo + son | 8,1 s |
| `bienvenue` | la sortie : « Let's go, prénom », le galet noir en boucle, la flamme qui crache, le bouton primaire | `duo-galet-noir` en boucle, `FlammeVive` (**TimelineView 60 Hz**), halo en projecteur | jusqu'au bouton |

Autour : la musique `MoonSplashTheme` en boucle (`NosfySon`), les haptiques,
l'île (`IleNosfy`) et le halo (`HaloIle`) au-dessus de tout.

### Comment il est monté et ce qu'il écrit

- Il vit **à la racine** (`NosfyApp.swift:2144` et `:2172`), en couche
  `zIndex(9.5)` au-dessus de toute l'app, quand `nosfyOuvert` est vrai — jamais
  dans un onglet. C'est ce qui lui permet de couvrir la barre bijou.
- Il prend UNE fermeture, `onFini(reponses)`, appelée quand elle tape le bouton
  de la sortie. Aujourd'hui `onFini` = `ecrireProfil` (`NosfyApp.swift:397`) :
  1. `InscriptionCompte.garder(reponses)` — pose le **brouillon** et le drapeau
     « inscription en cours » ;
  2. `ProfilServeur.definirProfil(langue, prenom, but, objectifHebdo)` — l'appel
     serveur `definir_profil`, qui rend le profil et le met en cache
     (`woop.prenom`, la clé que lit le médaillon) ;
  3. `Langue.poser`, `ChambreEtat.shared.objectif = …`,
     `PremiereArrivee.poserPremiereFois(p.seances == 0)` ;
  4. puis, chez l'appelant : `porteEteinte = true`, le film se dissout,
     `startConnexionCinematic()` (l'arrivée sur la home).
- À son `onAppear` (l. 262), s'il trouve un brouillon, **il saute directement à
  la sortie** — c'est la reprise d'une inscription coupée.
- Ses réponses : `Reponses { langue, prenom, but, jours: Set<Int> }` ; le
  serveur ne garde que le **nombre** de jours (`objectif_hebdo`), pas lesquels.

### Ce que le serveur permet déjà (site, brique `b-fn-definir-profil` 🟢)

`definir_profil` : « Paramètres facultatifs conservés lors d'un complément »,
rejeu idempotent mesuré le 20-09 (32 PASS). Autrement dit : **envoyer le prénom
seul** (`definirProfil(langue: nil, prenom: "Kat", but: nil, objectifHebdo: nil)`)
change le prénom et **ne touche ni la langue, ni le but, ni l'objectif**. Aucune
migration, aucune fonction nouvelle : le back-end est prêt tel quel.

### Le médaillon

`MedaillonProfil` (`ProfilLune.swift`) n'a **aucun geste** aujourd'hui : c'est un
dessin (disque laqué, liseré, bague, la lettre). Le tap est à ajouter.

---

## 2. Ce qu'il faudrait faire — le plan, en six gestes

### ① Un mode « revisite » sur le film, pas un second film

`NosfyOnboarding` reçoit deux entrées de plus : `revisite: Bool` et
`profilActuel` (langue, prénom, but, objectif — ce que le serveur tient, lu du
cache). On **ne duplique pas** le film (deux exemplaires divergeraient au
premier réglage, la loi de la maison) : le même code, avec quatre différences
lues sur `revisite`.

### ② Les réponses verrouillées, sauf le prénom

- `langue` : les deux cards restent, **celle de sa langue est marquée** (une
  coche ou le liseré plein), l'autre est éteinte à 35 % et **inerte** ; taper la
  sienne avance, comme avant. Sa réplique reste « Français. » / « English. ».
- `prenom` : le champ, **pré-rempli** avec son prénom actuel, modifiable,
  toujours obligatoire (le rouge du refus reste).
- `but` : même règle que la langue — sa card marquée, les deux autres éteintes
  et inertes.
- `jours` : le serveur ne sait pas QUELS jours, seulement combien. La semaine
  s'affiche **inerte** et « trois fois. » est dit tout de suite avec son
  objectif actuel ; le film repart seul après 2,4 s (la minuterie existe).
- `intro`, `accueil`, `bien`, `fin`, `bienvenue` : inchangés — « on revoit tout
  le scénario ».

Aucune de ces différences ne change une ligne du parcours d'inscription : elles
sont toutes derrière `if revisite`.

### ③ Le chevron, toujours là

Un chevron **en haut à gauche**, posé **au-dessus** du film (dans son
`.overlay`, au-dessus de l'île), présent à **toutes** les étapes — y compris
l'intro qu'on ne peut pas sauter au tap : le chevron n'est pas un saut, c'est
une sortie. Au tap : la musique et les bruits s'arrêtent (`NosfySon`), la vue
est **démontée** (donc chaque `NosfyReel` meurt avec elle, c'est déjà leur
`dismantleUIView`), fondu-flou vers le profil, **rien n'est écrit**.

Deux points de vigilance lus dans le code :
- le film porte un `.contentShape(Rectangle()).onTapGesture` sur tout l'écran
  (l. 250) : un `Button` posé au-dessus gagne le tap, le geste du fond ne voit
  rien — c'est le comportement SwiftUI, à vérifier au doigt ;
- **pas de verre** sur ce chevron : un `ChipVerre` (Liquid Glass) au-dessus de
  `nosfy-nuit`, `nosfy-accueil-loop`, `nosfy-end` et du galet, c'est un flou
  refait à chaque image de vidéo pendant tout le film. Un glyphe blanc sur un
  disque noir à 55 % suffit, et il se lit sur tous les plans.

### ④ La sortie « Entrer » n'écrit QUE le prénom

Un second `onFini` pour la revisite, **qui ne passe pas par `ecrireProfil`** :

```
ProfilServeur.definirProfil(langue: nil, prenom: p, but: nil, objectifHebdo: nil)
```

et rien d'autre. Ce qu'il ne doit surtout **pas** faire, et pourquoi (chaque
ligne est un piège lu dans `ecrireProfil`) :

| ne pas appeler | sinon |
|---|---|
| `InscriptionCompte.garder(reponses)` | un **brouillon** est posé ; au prochain lancement, `onAppear` du film le trouve et **rouvre le film à la sortie** sur un compte terminé (l. 262), et `NosfyApp:376/385` y voit une inscription à reprendre |
| `PremiereArrivee.poserPremiereFois(p.seances == 0)` | un compte sans séance repasserait par **la première arrivée** de la home (phrase, card vierge, pop-up) |
| `ChambreEtat.shared.objectif = …` / `Langue.poser` | inutiles (rien n'a changé) et une valeur `nil` mal lue pourrait écraser la vraie |
| `startConnexionCinematic()` / `porteEteinte` | c'est l'arrivée sur la home ; ici on **revient au profil**, le film se dissout et c'est tout |

Le cache `woop.prenom` est déjà posé par `definirProfil` → `garder(p)` : le
médaillon, le prénom de la ligne et « @prenom » changent tout seuls
(`@AppStorage`), la home aussi (`b-ux-prenom-home`).

Hors ligne / serveur en panne : l'écran d'erreur de la maison (`EcranErreur`,
déjà branché dans le film, l. 231) prend l'écran avec « Réessayer » ; le chevron
reste la sortie. Le prénom n'est pas gardé en brouillon : si elle sort, rien n'a
changé, ni sur le téléphone ni au serveur — c'est honnête et simple.

### ⑤ Le montage : à la racine, comme un cover, jamais dans l'onglet

Le film doit couvrir la barre bijou et vivre au-dessus de tout : on ne le pose
pas dans `ProfilLuneView` (il y vivrait **sous** la barre, on pourrait changer
d'onglet en plein film — c'est exactement la leçon du Sacre, déménagé à la
racine le 15-09). Le médaillon **demande** (`RevisiteNosfy.shared.demandee =
true`, une petite porte observée comme `SacreEtat.arriveeDemandee`), la racine
**monte** le film (`zIndex(9.5)`, `.transition(.fonduFlou)`), et le démonte
quand il finit ou quand le chevron le ferme.

Pendant qu'il est monté, **la page profil dort** : c'est la discipline des
covers du 18-09 (`RythmeEcran.couvert`, `.couvreLaHome()`) — le galet, le spot,
Nosfy pendu et tout ce qui est sous le film s'arrêtent, sinon on paie le film
**plus** la page qu'il cache (le piège du rideau). À la fermeture, la page se
réveille : le galet reprend, Nosfy pendu **rejoue** (on est « revenu sur
l'onglet » au sens de la règle du 20-09) — à trancher si c'est voulu.

### ⑥ Le tap du médaillon

`MedaillonProfil` reçoit une action ; au tap : haptique légère, un rebond
d'échelle (comme les pills), puis la demande. Zone de tap 44 pt minimum (le
disque fait 60, c'est bon). Pendant le dépliement de la carte (`carteP > 0`),
on n'ouvre pas le film.

---

## 3. La chauffe — ce qu'on sait, ce qu'on ne sait pas

**Ce qu'on sait.** Le film est un objet **borné dans le temps** (60 à 90 s,
déclenché par elle, jamais permanent) : sa chauffe n'est pas celle d'une home
qui tourne des heures. Ce qui compte, c'est **qu'il ne laisse rien derrière lui**
et **que rien ne tourne sous lui** :

- ses quatre vidéos sont des `AVPlayerLayer` démontés à chaque changement
  d'étape (le piège du rideau, déjà traité dans le film) ;
- son barreau existe : `-sansNosfyVideo` (les posters à la place) ;
- ses trois postes non mesurés sur iPhone restent ceux du film d'inscription,
  pas de la revisite : `MotsFlou` (un flou à rayon animé par mot — « jamais mis
  en cache », loi du skill), `FlammeVive` (TimelineView 60 Hz pendant toute la
  sortie), le halo (6 flous, transformés par ressorts — cachés tant que le rayon
  ne bouge pas). La sortie du 20-09 est notée « reste iPhone » dans la mémoire
  de cette session-là.

**Ce qu'on ne sait pas.** Aucun chiffre de ce film sur son iPhone : ni
l'inscription, ni a fortiori une revisite. Avant de poser le tap du médaillon,
la mesure honnête est : sonde `-sondeVol`, téléphone froid, une revisite
complète chevron compris, puis 60 s de profil après la fermeture — c'est **le
retour** qui prouve que rien n'est resté allumé (le `therm` qui redescend, les
`tics` à zéro, le galet seul).

**Ce que la revisite ne doit pas ajouter** : aucun verre sur le film (le
chevron nu), aucune vidéo de plus, aucune horloge de plus. Elle coûte ce que le
film coûte déjà, pas un watt de plus.

---

## 4. Ce qu'elle doit trancher (quatre questions, une ligne chacune)

1. **L'intro de 19 s est rejouée à chaque fois ?** « On revoit tout le scénario »
   dit oui ; le chevron permet d'en sortir à tout moment. Sinon : entrer à
   l'accueil (10 s) — à dire.
2. **Les réponses verrouillées** : cards éteintes avec la sienne marquée
   (proposé), ou seulement la phrase et le film qui avance seul ?
3. **Le chevron** : un glyphe nu sur disque noir (proposé, pour la chauffe), ou
   la chip de verre de la page profil (un flou par image de vidéo) ?
4. **Au retour sur le profil**, Nosfy pendu rejoue-t-il (c'est un « retour sur
   l'onglet ») ou reste-t-il envolé ?

---

## 5. Ce que ça touche, et ce que ça ne touche pas

| fichier | quoi |
|---|---|
| `Nosfy/Views/NosfyOnboarding.swift` | `revisite`, `profilActuel`, les 4 verrous, le chevron, `onAppear` sans brouillon en revisite |
| `Nosfy/Views/ProfilLune.swift` | le tap du médaillon → la demande |
| `Nosfy/NosfyApp.swift` | le montage à la racine, la fermeture `onFini` de revisite (prénom seul), la couverture |
| un petit `RevisiteNosfy` (état observé) | la porte entre le profil et la racine |
| `docs/site/content/briques.ts` | `b-po-profil` : le prénom est **modifiable** depuis le profil (site d'appel nouveau de `definir_profil` → à écrire dans le même commit, mesuré) |

**Aucune migration, aucune fonction serveur, aucun asset nouveau.** Le seul
appel réseau nouveau est `definir_profil` avec le prénom seul — un site d'appel
de plus sur une fonction 🟢, à mesurer (appel fait, réponse lue) avant de
repeindre la brique.

---

## 6. Le scénario qu'elle a tranché (20-09, après lecture) — et mon avis

**Ses mots :** pas la page de récap (la sortie « Let's go ») ; les images du début
et la nuit noire ; Nosfy « Bienvenue dans mon monde » ; puis il **dit** la langue
choisie ; puis « je dois vous appeler Margaux, vous souhaitez le changer ? » et
elle saisit ou pas ; puis « vous avez utilisé Nosfy pour : » et le choix fait ;
« Bien. » ; la vidéo ; retour au profil. On peut **changer les phrases** : le
film parle en mode « je me souviens », pas en mode questionnaire.

### Le film en mode « souvenir » — étape par étape

| étape | inscription | revisite (« souvenir ») | front / back |
|---|---|---|---|
| intro | poème + nuit + Nietzsche | **identique** | front — rien |
| accueil | « Bienvenue dans mon univers noir. » | **identique** (« mon monde » est déjà « mon univers noir ») | front — rien |
| langue | question + 2 cards | **une phrase, pas de card** : « Nous nous parlons en français. » / « We speak English. » ; le film avance seul (2 s) | front — la langue est en cache (`woop.langue`) |
| prénom | question + champ obligatoire | « Je vous appelle **Margaux**. » puis « Vous souhaitez changer ? » ; le champ, **pré-rempli**, et **on peut ne rien changer** : un tap ailleurs ou « Terminé » sur le même prénom → « Très bien, Margaux. » ; le vide reste refusé (le rouge) | front — `woop.prenom` en cache ; l'écriture = `definir_profil(prenom)` **seulement si ça a changé** |
| but | question + 3 cards | **une phrase** : « Vous êtes venu pour **être plus fort**. » ; le film avance seul | front — ⚠️ voir « le but » ci-dessous |
| jours | la semaine | **retirée** (elle ne l'a pas listée) | — |
| bien | « Bien. » | **identique** | front — rien |
| fin | la vidéo `nosfy-end` | **identique** | front — rien |
| bienvenue | la sortie « Let's go » | **retirée** : à la fin de la vidéo, le film se dissout **vers le profil** (fondu-flou), sans bouton | front |

Le chevron (§ 2 ③) reste, partout, nu.

### Ce que je challenge, et ce que j'améliorerais

1. **Le but n'est pas dans le téléphone.** Le prénom et la langue sont en
   cache ; le but (`force` / `poids` / `forme`) ne l'est pas — le serveur l'a
   (`profil()` le rend), le téléphone l'oublie. Deux façons, toutes deux
   **front** (le serveur n'a rien à faire) :
   - **le garder en cache** comme le prénom (`ProfilServeur.garder` pose déjà
     `woop.prenom` ; poser `woop.but` au même endroit, rafraîchi par les mêmes
     lectures) — **c'est celle que je recommande** : la phrase est prête avant
     même d'ouvrir le film, hors ligne compris ;
   - ou l'aller chercher en ouvrant le film (un appel `profil()` pendant les
     19 s de l'intro, 200 ms) — plus fragile hors ligne.
   Hors ligne ET jamais mis en cache (compte réinstallé sans réseau) : la
   phrase du but **se tait** plutôt que d'inventer (la loi du vide).
2. **Écrire seulement si ça change.** Si elle sort du film avec le même prénom,
   **aucun appel** : rien à envoyer, rien à attendre, pas d'écran d'erreur
   possible hors ligne. Le film finit pareil.
3. **Le prénom écrit AVANT la vidéo de fin, pas après.** Elle tape le nouveau
   prénom → « Enchanté, Kat. » → le but → « Bien. » → la vidéo (8 s). Si l'appel
   part au moment où elle valide le prénom, il a 12 s pour aboutir pendant
   qu'elle regarde ; au retour sur le profil, le médaillon est **déjà** à la
   nouvelle lettre. Si l'appel échoue : l'écran d'erreur de la maison, avec
   « Réessayer », et le chevron pour renoncer (le prénom d'avant reste).
4. **La fin : pas de bouton, pas de récap — mais une respiration.** La vidéo
   de fin finit dans son noir ; enchaîner directement sur le profil depuis ce
   noir est le raccord le plus propre (le même que « le noir de sa fin est ce que
   l'interrupteur attend », 13-09). Rien à ajouter.
5. **Le chevron pendant l'intro.** Elle ne peut pas sauter l'intro au tap (sa
   règle) ; en revisite, le chevron est la seule sortie et il est là dès la
   première seconde. Je garde l'intro entière : c'est ce qu'elle veut revoir.
6. **Nosfy pendu au retour.** Revenir du film = « revenir sur l'onglet » au
   sens de la règle du matin : il rejouerait. Je trouve ça juste (le film
   vient de finir sur lui, il réapparaît pendu puis s'envole) — mais c'est un
   choix de rendu, à voir sur le téléphone.

### Front ou back, en une ligne chacun

- **Back-end : rien.** Aucune migration, aucune fonction, aucun droit :
  `definir_profil(prenom)` existe, garde les autres champs, est mesuré (32 PASS).
- **Front, dans l'ordre :** le cache du but (`ProfilServeur.garder`) → le mode
  « souvenir » du film (phrases, champ pré-rempli, étapes retirées, fin sans
  bouton) → le chevron → le montage à la racine avec la page profil qui dort →
  le tap du médaillon → la fin qui n'écrit que le prénom, et seulement s'il a
  changé.
- **Le site :** `b-po-profil` (le prénom devient modifiable depuis le profil) et
  la note de `b-fn-definir-profil` (un site d'appel de plus) — dans le même
  commit, après un appel réel lu.
- **La mesure :** une revisite complète sur son iPhone, chevron compris, puis
  60 s de profil — le retour à zéro est la preuve.
