# LES RETOUCHES DU FILM DE NOSFY — après le premier vrai test

*13-09-2026 · analyse, rien n'est codé · fait suite à `PLAN-SORTIE-PROJECTEUR.md`*

Le vrai test Apple est passé sur l'iPhone de Kathryn (« ok j'ai réussi très bien ! »).
Sept demandes en sortent. Avant elles, ce que le serveur dit du test.

---

## 0. Ce que le test a VRAIMENT fait au serveur (mesuré, 11:2x)

```
auth.users
- b8dc40f5  email=None            identités=apple  dernière connexion 11:22:32  user_prefs=0
- 30871045  kat44426@gmail.com    identités=email  dernière connexion None      user_prefs=0
```

- **Un compte NEUF est né** (`b8dc40f5`, identité `apple`), **sans email**. Apple ne l'a pas
  lié à la ligne `kat44426@gmail.com` créée le 29-07 : la liaison automatique se fait sur
  un email vérifié, et **on ne demande aucun scope à Apple** (décision du 05-09 : Nosfy
  demande le prénom lui-même). Sans scope, le jeton d'identité n'a pas d'email.
- **Conséquence :** « mon compte de test officiel kat44426@gmail.com » est en réalité
  **l'identité Apple `b8dc40f5`**. La ligne email du 29-07 est un compte mort (jamais
  connecté). Si tu veux l'email attaché au compte Apple, il faut demander le scope
  `.email` — et Apple ne le rend qu'à la **première** autorisation : il faudrait révoquer
  Woop dans Réglages → Compte Apple → Se connecter avec Apple, puis recommencer. À
  trancher ; je recommande de **ne pas** le faire : l'email ne sert à rien dans l'app.
- `user_prefs = 0` → le verdict a été **nouvelle** → le film s'est ouvert. Cohérent.
- **Rien n'a été écrit** à la fin du film (`definir_profil()` n'existe pas — jalon 2).
  Le prochain test dira donc encore « nouvelle ».
- Le site : `b-po-apple` passe à 🟢 avec cette preuve (fait dans la foulée, hors code app).

---

## 1. « Le texte encore plus Apple »

**Aujourd'hui** (`MotsFlou`, NosfyOnboarding.swift:928) : Inter SemiBold 30, tracking
par défaut, chaque mot sort du flou (11 → 0) en montant de 9 pt, `easeOut` 0,78 s, avec
une cadence irrégulière (longueur du mot + ponctuation + grain), clair / sourd 0,42.

**Ce qui fait « Apple » dans une apparition de texte** (la présentation d'Apple
Intelligence, l'accueil iOS) — quatre choses, pas une :

| | aujourd'hui | proposition |
|---|---|---|
| tracking | défaut (Inter est déjà serré) | **−2,6 % du corps** → −0,8 pt à 30 : plus dense, plus « display » |
| montée | 9 pt | **5 pt** — Apple monte à peine, il *se pose* |
| échelle | aucune | **0,96 → 1,00** par mot — le mot arrive de légèrement plus loin |
| courbe | `easeOut` 0,78 s | **`timingCurve(0.2, 0.8, 0.2, 1)` sur 0,9 s** — départ vif, très long amortissement |
| flou | 11 → 0 | **8 → 0** : moins de flou mais plus long à se résoudre |
| interligne | 0,52 × corps | **0,58 × corps** — plus d'air entre les lignes |

Le sourd reste 0,42 (c'est la voix de la home, mesurée). Coût : zéro couche — les mêmes
valeurs animées, autrement. **À juger au téléphone**, pas au sim : la courbe se sent, elle
ne se voit pas en capture.

---

## 2. Le mot de fin : « Bien. » avant le résultat

**Aujourd'hui :** après les jours, l'île répond « Quatre fois. On s'y tient. » et la page
part directement au projecteur.

**Proposition :** une étape à part entière, `.bien`, entre `jours` et `bienvenue` — l'écran
ne porte QUE le mot, en grand (44 pt), centré, clair, en fondu-flou ; le halo s'embrase
avec lui (haptique *moyen*) ; **1,6 s**, puis le projecteur. Pas de réplique dans l'île : ce
mot-là est l'écran entier. C'est la respiration qui manque avant la lumière qui change de
camp.

Coût : une case dans `Etape`, un `case` dans `contenu`, un `Task` de 1,6 s. Rien d'autre.

---

## 3. « Et avant le début du texte »

Je lis : *un temps avant que le premier mot arrive*. **Aujourd'hui** le seuil commence à
écrire à `base: 0` — en même temps que le halo s'allume (1,2 s) : le texte et la lumière se
courent après.

**Proposition :** la lumière AVANT le texte (la loi de la maison) — le premier mot du seuil
part à **0,9 s**, quand le halo est presque plein, et le flash de l'anneau (0,52 s) tombe dans
ce silence. Si tu voulais un *mot* avant le texte plutôt qu'un temps, dis-le : ce serait un
« … » ou un souffle, et je le déconseille — le silence est plus Apple qu'un signe.

---

## 4. Revoir l'onboarding sur le téléphone : le mode maquette

**Déjà codé, pas encore posé** (`AppleAuth.Maquette`, build `be7w3cozz` vert) :

- je lance **une fois** `Woop -parcoursMaquette` par câble → c'est **durable** ;
- ensuite **l'icône suffit** : porte → « Se connecter avec Apple » joue Apple *sans* Apple
  (0,7 s, rien ne part au réseau) → verdict *nouvelle* → le film → home ;
- `-parcoursMaquetteConnue` pour jouer une connue (porte → app direct) ;
- `-parcoursReel` pour revenir au vrai Apple.

Le compte de test officiel (`b8dc40f5`) ne sert qu'aux vrais tests. À poser dès que tu dis
go — c'est le build d'après les retouches, pour ne pas poser deux fois.

---

## 5. Le halo s'anime quand le texte bouge

**Aujourd'hui** (`HaloIle`, :756) : quatre horloges indépendantes (respire 4,3 s, dérive 11 s,
nappe 7 s, langue 19 s) + l'embrasement quand l'île répond. **Il ne sait pas quand des mots
arrivent.** Le texte et la lumière vivent côte à côte, pas ensemble.

**Deux façons, et je recommande la première :**

- **A · un battement par mot.** `MotsFlou` prévient à chaque apparition de mot ; le halo
  répond par une poussée de **+4 % sur un ressort de 0,35 s** (capsule blanche 0,58 → 0,74
  le temps du mot). Trente mots = trente petites poussées — la lumière *parle avec lui*.
  C'est littéralement « s'animer quand le texte bouge ». Coût : une animation de valeur par
  mot, aucune horloge, aucun redessin.
- **B · une pulsation pendant la parole.** Un battement régulier (0,9 s) tant qu'une tirade
  se dit. Plus simple, mais régulier — et on a déjà payé « une cadence régulière s'entend
  comme une machine ».

⚠️ Le halo est cinq couches floutées en `plusLighter` : on n'anime que des transformations
(échelle, opacité). Jamais le rayon de flou, jamais la couleur — ça redessine.

---

## 6. La langue est trop longue

**Aujourd'hui :** deux phrases françaises + deux phrases anglaises à 30 pt (≈ 8 lignes), puis
les cards à **3,4 s**. C'est l'écran le plus long du film, pour le réglage le plus simple.

**Proposition :** garder la phrase française (c'est le seuil, il a été voulu), **réduire
l'anglais à une seule ligne** (« What language should he speak? ») en sourd, et faire
arriver les cards à **2,0 s**. Un tap suffit pour une Française (le français est déjà
choisi). Le seuil passe de ~5 s à ~2,5 s sans perdre sa phrase.

Variante plus courte encore, si 2,5 s est encore trop : pas d'anglais du tout, les cards à
1,4 s. Je préfère garder l'anglais — c'est lui qui dit qu'il y a un choix.

---

## 7. Le personnage Nosfy en vidéo — APRÈS les retouches, mais voilà ce que ça engage

Quand il dit « Bienvenue dans mon univers noir », **une vidéo de Nosfy en boucle**.

- **La pièce existe :** `VideoReward(nom:relance:boucle:entier:)` (RewardCard) et
  `ReelHote` (PorteEntree) — des couches `AVPlayer` UIKit. Lois payées : **bord à bord**
  (une vidéo posée ailleurs qu'en bord laisse voir son rectangle), `clipsToBounds` +
  `masksToBounds`, boucle **cuite en ping-pong** dans le fichier (jamais un seek qui
  rebrousse), et « son noir est vrai » — un fond noir + `plusLighter` rend le noir
  transparent sans alpha.
- **Le format :** H.264 ou HEVC, fond **noir pur**, le personnage seul, la boucle cuite.
  C'est toi qui fournis la vidéo ; je la recuis (`ffmpeg`, `trim + setpts` dans le graphe —
  le piège du `-ss` est payé).
- **La place :** sous la tirade, dans la lumière du halo — ou DANS le halo (à la place de la
  capsule blanche) : le personnage *est* la lumière. À trancher sur une capture.
- **Le prix :** une vidéo + cinq couches floutées + du texte mot par mot = la famille
  « les widgets en verre brûlent ». **Mesure obligatoire au téléphone avant verdict**
  (`-sondeVol`, thermique à 0), et son barreau `-sansNosfyVideo`.
- **Quand :** une seule fois par film (2,2 s de tirade → la boucle vit ~4 s), puis la
  couche est DÉMONTÉE — pas cachée (le piège du rideau : une vue montée mais cachée est
  rendue).

---

## 8. L'ordre, et ce qu'on mesure

| rang | geste | coût | mesure |
|---|---|---|---|
| ① | le texte plus Apple (§1) | 6 valeurs | au téléphone, à l'œil — la courbe ne se capture pas |
| ② | « Bien. » (§2) + le temps avant le texte (§3) | petit | film |
| ③ | la langue raccourcie (§6) | petit | chrono : < 2,5 s avant les cards |
| ④ | le halo qui parle avec les mots (§5 A) | une animation par mot | cadence `-sondeVol`, avant/après |
| ⑤ | poser le build + `-parcoursMaquette` (§4) | 0 | tu rejoues à l'icône |
| ⑥ | la vidéo de Nosfy (§7) | une couche vidéo | cadence + thermique, barreau `-sansNosfyVideo` |

①→④ partent ensemble dans un seul build, ⑤ le pose, ⑥ attend ta vidéo.

**Verrous :** on n'anime jamais le flou ni la couleur du halo · une vidéo est démontée,
jamais cachée · rien n'est écrit au serveur tant que `definir_profil()` n'existe pas ·
la pastille Apple est 🟢 parce qu'elle est mesurée (§0), pas parce que tu l'as dit.
