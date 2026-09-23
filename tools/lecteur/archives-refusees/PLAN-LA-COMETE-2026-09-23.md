# ⏸ MIS DE CÔTÉ LE 23-09 AU SOIR — elle revient au feu

**« Ignore mon dernier prompt, je veux l'effet de braise et tout revient
arrière, mais hyper réaliste avec toutes les nuances de jaune, blanc, orange.
Pardon, je me suis trompée. »** (Kathryn, 23-09.)

Le feu reprend la transition : voir `PLAN-LA-VRAIE-BRAISE-2026-09-23.md`.

**Ce document n'est PAS mort pour autant.** La comète reste la meilleure
réponse connue à un besoin que le feu ne couvre pas : **le chargement**, quand
on attend le serveur et qu'on ne sait pas combien de temps. Le feu, lui, est un
PASSAGE : il a un début et une fin. Si un jour il faut un indicateur d'attente,
tout est ici, script de rendu compris.

⚠️ Ne pas coder la comète sans qu'elle le redemande.

---

# La comète : le chargement et le passage de toute l'app

**Plan pour une prochaine session. RIEN N'EST CODÉ.**
Dicté par Kathryn le 23-09-2026 au soir.

Planche : <https://claude.ai/artifact/HPhJgfoMZzSpM6oSTLWV36>
Images et script de rendu : `comete-2026-09-23/` (`comete.py`).

---

## 0. ⚠️ CE QUI EST MORT

**LE FEU EST MORT.** La flamme noire, la braise avec sa rampe de température,
l'embrasement depuis la card : **tout ça est refusé**, verdict du 23-09 au soir
(« c'est horrible là »). Le plan `PLAN-LA-VRAIE-BRAISE` a été supprimé, et le
chantier 3 de `PLAN-LA-FLAMME-NOIRE` est remplacé par ce document.

Ses mots : « plus petit, plus abstrait, **pas néon**, très très fine, et comète
et particules qui se dessinent progressivement comme un vrai dessin […] car ça
sera le chargement pour chaque [écran]. Fais hardcore. »

**Ce qui SURVIT du feu** : la braise du header pendant la séance (un dégradé
radial dont une valeur va et vient) et la série en cours portée par une braise.
Elles sont déjà dans l'arbre et n'ont pas été refusées. Le feu meurt comme
MOUVEMENT, pas comme couleur d'ambiance.

---

## 1. Le geste

**Un point de lumière se déplace et laisse un trait.** Le dessin se construit
sous les yeux, comme une main qui trace. Quand il se referme, l'écran est prêt.

Trois couches, et rien d'autre :

| Couche | Ce que c'est | Réglage rendu |
|---|---|---|
| **Le noyau** | le point le plus blanc de l'écran, **1 px**, à la position courante | halo 1,6 px ×5,0 + halo 6 px ×4,2 |
| **La queue** | les 8,5 % derniers pas, intensité `u²·²` | halo 3 px ×1,2 |
| **Le trait** | ce qui reste derrière, en **argent** | 0,58 + halo 2,2 px ×0,22 |
| **Les particules** | elles se détachent et dérivent (σ 10 px, montée 6 px) | 5,5 % de chance par pas |

Tracé en **double résolution puis réduit** : c'est ce qui garde le trait à 1 px
sans escalier.

---

## 2. Les lois tenues

- **La brillance vient de la blancheur, jamais de l'épaisseur.** Trait 1 px,
  halo court, **noir absolu entre**. Rien n'est épais, rien n'est néon.
- **La lumière a une cause et un bord.** C'est UN POINT, il a une position à
  chaque instant. **Rien ne balaie** : le point trace, il ne traverse pas.
- **Blanc et argent seuls.** Le halo tire très légèrement vers le bleu froid
  (canal bleu ×1,05). Aucune autre couleur.
- **Abstrait.** Aucune forme ne représente quoi que ce soit — c'est ce qui
  permet de s'en servir PARTOUT sans raconter une histoire différente par écran.

---

## 3. Les quatre tracés proposés

Voir `comete-2026-09-23/` :

| Forme | Fichiers | Pour quoi |
|---|---|---|
| **Le cercle** | `cercle1..4` | ✅ **recommandé** — une ligne qui se referme dit où elle en est sans un chiffre |
| **La spirale** | `spirale1..4` | les attentes longues : un tracé plus tenu |
| **L'entrelacs** (lissajous 3:2) | `lissajous1..4` | le plus beau à l'arrêt, le moins lisible en cours |
| **Les trois arcs** | `trois1..4` | trois étapes visibles, pour un chargement qui dure |

⚠️ **Ne PAS appeler « trois arcs » une allusion aux Trois Lunes.** Trois Lunes
reste intacte (loi du 20-09) : on ne l'étend pas, on ne l'empile pas.

---

## 4. En situation, pour changer d'écran

`s1..s4` : l'écran qu'on quitte s'éteint pendant que le trait se dessine. Quand
le cercle se ferme, l'autre est là. Minutage rendu : 0 · 200 · 380 · 500 ms.

---

## 5. Ce que ça coûte — et pourquoi c'est MIEUX que le feu

Une courbe paramétrique, un point par image, un trait qui s'accumule.
**Pas de texture, pas de bruit cuit, pas de shader plein écran.**

Deux façons de le poser, à trancher :

- **`Canvas` SwiftUI** avec un chemin qui s'allonge (`trim(from:to:)` sur un
  `Path`) + une couche de particules. Simple, mais un `Canvas` plein écran est
  cher — il redessine. ⚠️ Piège connu de ce dépôt.
- **Une `Shape` avec `trim`** animée, plus un petit `Canvas` réservé aux
  particules, ou des particules pré-cuites. `trim` s'anime **sans redessiner le
  chemin** : c'est la forme la moins chère, et c'est celle à essayer d'abord.

**Le vrai gain, au-delà du dessin** : le feu était un shader sur une
photographie de l'écran — cher, complexe, impossible à réutiliser comme
chargement. La comète est **la même chose partout** : changer d'écran, attendre
le serveur, ouvrir une fiche. Un seul geste dans toute l'app.

⚠️ Barreau : `-sansComete`. Et **rien ne se garde sans une mesure sur SON
iPhone**, thermique lu à 0 au départ.

---

## 6. À trancher avec elle

- **D1** — La forme : cercle (recommandé), spirale, entrelacs, trois arcs.
- **D2** — La durée : 0,5 s pour un passage ; un chargement, lui, boucle jusqu'à
  la réponse.
- **D3** — Le trait **reste** jusqu'au bout, ou **s'efface** derrière la comète ?
  (Ici il reste : c'est ce qui fait « un dessin » plutôt qu'« un point qui
  tourne ».)
- **D4** — Où exactement : tous les passages du lecteur, ou aussi le Go, les
  attentes serveur, l'ouverture d'une fiche ?

---

## 7. Ce qui est vrai au moment où ceci est écrit

- Dans l'arbre, **non commité** : les carrés réservés au choix, le chevron du
  retour, la braise du header, la série en cours portée.
  Captures : <https://claude.ai/artifact/BCyvc6t4eQVaeVFh9jZnyn>
- `CoupeBlanche.swift` (le cercle blanc) est **commité** en `e7cc9ef8` et
  toujours en place. Il meurt quand la comète arrive.
- **Aucune chauffe n'a jamais été mesurée** sur le lecteur.
- ⚠️ **Le dépôt ne compile pas seul** : 12 erreurs d'autres chantiers non
  commités (`tools/production/testflight-83-2026-09-22/`).
