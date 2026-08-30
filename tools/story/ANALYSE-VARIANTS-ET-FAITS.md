# ANALYSE — LES STORIES, LEURS VARIANTS, ET LE SEUL CHAÎNON QUI MANQUE

**30-08.** Sa question : « les stories, c'est bon ? C'est en lien avec les
variants ? Selon le meilleur score de la semaine, ou le fois 2, ou les cards
rewards différentes à la fin des boosters, + l'IA dans la card 3, l'avant-
dernière, avec les stickers qui analysent la séance ? »

> Ce qui porte `fichier:ligne` est **vérifié dans le code**. Ce qui porte une
> réponse HTTP est **sondé sur le serveur**, témoin compris. Le reste porte
> **?** et attend sa décision.

---

## 0 · La réponse courte

**Oui, tout ce qu'elle décrit existe — et rien ne le déclenche.**

La mécanique des variants est écrite, complète et juste : la story change
vraiment de pages selon l'exception, et l'ordre est même une grammaire (« la
page d'exception s'insère AVANT le résumé »). Ce qui manque n'est pas quatre
choses, c'en est **une seule** :

> **Personne ne calcule jamais si cette séance a été exceptionnelle.**

Les quatre déclencheurs qu'elle nomme sont aujourd'hui **quatre drapeaux de
banc**. Le code le dit lui-même, en toutes lettres (`StoryFlow.swift:638`) :
*« le vrai déclencheur viendra du fact engine »*.

---

## 1 · Ce qu'une story est, exactement

`StoryFlow.swift:275` — **cinq rôles de page**, et l'ordre EST la grammaire :

```
ordinaire :  ouverture → details → analyse → butin          (4 pages)
exception :  ouverture → resume  → details → analyse → butin (5 pages)
```

⚠️ **La page d'exception ne s'ajoute pas à la fin : elle PREND l'ouverture**, et
le résumé qu'elle portait descend d'un cran (`:280-283`). C'est pour ça qu'un
jour d'exception a cinq pages et un jour ordinaire quatre — pas parce qu'on
aurait ajouté un écran, mais parce que l'ouverture a changé de sujet.

Et **`analyse` est bien l'avant-dernière** — sa « card 3 » est exactement celle
qu'elle décrit.

---

## 2 · Les quatre variants, et ce qui les déclenche AUJOURD'HUI

| Variant | Ce qui devrait le déclencher | Ce qui le déclenche réellement | Vérifié |
|---|---|---|---|
| **TOP SESSION** (meilleure séance de la semaine) | un fait : « meilleure de la semaine », muscu ou cardio | `-storyTop` / `-storyTopMuscu`, un drapeau de banc | `StoryFlow.swift:643-645` |
| **×2** (deux séances le même jour) | un fait : « deuxième séance du jour » | `-storyDouble`, un drapeau de banc | `StoryFlow.swift:649` |
| **La card du butin** (`poche` / `renverse`) | « le moteur tranchera », robe stable par séance | `-winRenverse`, un drapeau de banc | `StorySuite.swift:1455-1469` |
| **La page `analyse`** (l'IA + les stickers) | l'analyse de la séance | **rien** — la page existe, l'IA vit ailleurs (§ 3) | `StoryFlow.swift:344` |

**L'arbitrage entre variants, lui, est déjà tranché et codé** (`:286-289`) : si
×2 et TOP tombent le même jour, **×2 gagne l'ouverture** — « c'est le jour ; la
semaine attendra ». Cette règle-là n'attend rien de personne.

---

## 3 · L'IA — elle existe, et elle n'est pas là où elle devrait être

- `SynthesisService` appelle une **edge function qui détient seule la clé
  Anthropic** (`SynthesisService.swift:50`) — donc la clé n'est pas dans l'app,
  c'est bien fait.
- `SynthesisCard` la monte… **dans l'onglet Progression**
  (`ProgressionView.swift:42`), et **nulle part ailleurs** (grep sur tout le
  dépôt : un seul site d'appel).
- La page `analyse` de la story, elle, rend `StoryAnalyse`
  (`StoryFlow.swift:344`) — **une autre vue, sans IA**.

⚠️ **Deux objets faits l'un pour l'autre, jamais présentés.** Ce n'est pas un
manque de code : c'est un branchement de trois lignes qui n'a jamais été fait.
La vraie question n'est pas technique :

**?** L'IA de la story doit-elle analyser **cette séance-là** (un texte par
séance, généré à la clôture) ou **la période** (ce que fait la card de
Progression aujourd'hui) ? Ce n'est pas le même appel, ni le même prix, ni le
même cache.

---

## 4 · Les stickers « qui analysent la séance » — ils n'analysent rien

- Home et calendrier : `stickers[i % 7]` (`HomeNuit.swift:1567`) — l'index du
  jour dans la semaine.
- Panneau de la route : `SemaineStrip.sticker(1)`
  (`DuolinguoPage.swift:2242`) — **le 1 est écrit en dur**.
- Serveur : `workouts?select=sticker` → **400**, la colonne n'existe pas
  (témoin `colonne_bidon` → 400 aussi).

**Aucune séance ne décide de son sticker, nulle part.** Pour qu'un sticker
*analyse* la séance, il lui faut la même chose que tout le reste de ce document :
un fait.

---

## 5 · Ce qui manque, en une phrase et un dessin

Un **fait** est une phrase vraie sur une séance, dérivée d'elle et des
précédentes : « c'est la meilleure de la semaine », « c'est la deuxième
d'aujourd'hui », « c'est un record de charge », « c'est du cardio ».

```
                      ┌─ meilleure de la semaine ─→ 🏆 page TOP SESSION
                      │
🏋️ une séance finie ──┼─ deuxième du jour ────────→ ✌️ page ×2
   + celles d'avant   │
                      ├─ record / volume / durée ─→ 🎴 robe du butin, sticker
                      │
                      └─ le texte de la séance ───→ 🤖 page analyse (l'IA)
```

**Un seul calcul, quatre sorties.** C'est pour ça que ce chantier vaut mieux que
quatre petits : le chemin en a besoin aussi (« ce jour-là a été fait »), et les
stickers aussi.

**Sondé** : `workout_facts` → **404**, la table n'existe pas. Et `SupabaseSync`
n'a qu'un `push`, donc même les séances ne se relisent pas.

---

## 6 · Ce qu'il faut décider avant d'écrire une ligne

| # | Question | Pourquoi ça bloque |
|---|---|---|
| 1 | ~~**Où le fait est-il calculé** ?~~ | **TRANCHÉ — voir § 6 bis** |
| 2 | **« Meilleure de la semaine » se mesure sur quoi** — volume, durée, kcal, séries ? | c'est ce qui décide de la page TOP, et deux réponses donnent deux pages différentes le même jour |
| 3 | **L'IA analyse la séance ou la période ?** (§ 3) | ce n'est pas le même appel ni le même coût |
| 4 | **Le sticker se déduit d'un fait ou reste décoratif ?** | s'il analyse la séance, il lui faut le même moteur ; sinon il faut au moins qu'il soit le MÊME des deux côtés |
| 5 | **La robe du butin se tire ou se mérite ?** | « stable par séance » est écrit dans le code, mais stable *selon quoi* n'est pas décidé |

---

## 6 bis · DANS L'APP OU AU SERVEUR ? — deux lois du dépôt suffisent

**Recommandation : le fait se calcule DANS L'APP, à la clôture, et part au
serveur avec le reste — comme un ENREGISTREMENT, pas comme une autorité.**

Ce n'est pas un compromis mou : deux lois déjà écrites ici tranchent, et elles
ne se contredisent pas.

**① « L'écran ne doit jamais attendre le réseau. »** C'est écrit sur le flow de
fin de séance : une séance entière = trois appels, *tout le reste est local, et
c'est voulu*. Or la story démarre **deux secondes après « Terminer »**, et le
seul appel serveur de la clôture part par l'**outbox** — c'est-à-dire sans qu'on
attende sa réponse, exprès, pour qu'un gain ne soit jamais perdu. Faire venir le
fait du serveur, ce serait soit faire attendre la story, soit lui donner sa page
d'exception **au tour suivant** — donc jamais le bon jour.

**② « Ce qu'on ne croit JAMAIS du client. »** Cette loi vise une liste
précise : un tirage, un compteur de pitié, un fuseau, un montant, un « j'ai déjà
réclamé ». Le point commun : **ça paie**. Un fait de story ne paie rien — il
choisit une page. Le falsifier ne donne pas une pièce, ça donne une jolie image
à quelqu'un qui l'a truquée pour lui-même.

**Et l'app a ce qu'il faut pour calculer juste** : « deuxième séance du jour » se
lit sur deux dates, « meilleure de la semaine » sur la semaine locale — et
l'appareil qui vient de s'entraîner est précisément celui qui a l'historique.

### La limite, et le jour où elle bascule

⚠️ **Le jour où un fait PAIE — un bonus « record », des pièces pour un ×2 — ce
fait-là remonte au serveur, sans discussion.** Il rejoint alors la liste de la
loi ②, et l'app n'en garde qu'un affichage provisoire. La frontière n'est donc
pas « app ou serveur » : c'est **« est-ce que ça paie ? »**.

⚠️ **Une seule implémentation, jamais deux.** L'app calcule, le serveur RANGE
(une colonne sur `workouts`, ou `workout_facts`). Recalculer côté serveur « pour
vérifier » créerait exactement la double vérité qu'on passe la journée à tuer —
et sur un second appareil, c'est le fait RANGÉ qu'on relit, pas un recalcul
local sur un historique qu'on n'a pas.

**Conséquence pratique** : ranger les faits n'est pas une option, c'est ce qui
rend le calcul local honnête. Et ça retombe sur le même trou que partout —
`SupabaseSync` n'a qu'un `push` (§ 5).

---

## 7 · L'ordre le moins cher, une fois décidé

1. **Le fait le plus simple d'abord : « deuxième séance du jour ».** Il ne
   demande aucune table, aucune IA, aucune décision de mesure — il se lit sur
   deux dates. Il allume la page ×2, qui est **peinte et inatteignable
   aujourd'hui**. ⏱️
2. **« Meilleure de la semaine »**, une fois la mesure choisie (§ 6.2) — il
   allume TOP SESSION. ⏱️
3. **Brancher l'IA sur la page `analyse`** — trois lignes, une fois tranché ce
   qu'elle analyse. ⏱️
4. **Ranger les faits** (`workout_facts`, ou une colonne sur `workouts`) pour
   qu'ils survivent et servent le chemin, les stickers et les stories. ⏳
5. **Le sticker dérivé d'un fait.** ⏳

**Rien de tout ça n'est codé.** Ce document est l'analyse qui précède, et les
cinq questions du § 6 lui appartiennent.
