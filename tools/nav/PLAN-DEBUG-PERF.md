# PLAN DE DÉBOGAGE — « dès que j'ouvre Woop, ça chauffe »

05-09. Court exprès. Le long document (`PLAN-PERFORMANCE.md`) contient l'étude ;
celui-ci contient **ce qu'on fait, dans quel ordre, et comment on le prouve**.

---

## LE FAIT, en une ligne

**Écran noir sans aucune page : 1 % de processeur. N'importe quelle page,
immobile, personne n'y touchant : 27 à 39 %.** Téléphone froid, mesuré huit
fois. Une page statique devrait être à 2 %.

Et : **le corps de la page est recalculé 0 fois par seconde.** SwiftUI ne refait
aucune mise en page. Donc ce n'est pas « l'app calcule trop » — c'est
**« l'app REDESSINE trop »**.

---

## LA CAUSE, telle qu'elle se lit dans le code

Le motif, trouvé dans `WidgetsCards.swift:261-291`, et il est partout :

```
20 fois par seconde :
  · un dégradé CONIQUE recalculé            (cardLisereConique)
  · dessiné en TROIS traits superposés
  · dont DEUX sont FLOUTÉS (blur 2,4 et 1,2)
  · le tout sous un GlassEffectContainer + un verre natif
pour faire tourner la lumière de ±3° sur 9,4 secondes.
```

**Trois degrés.** Le mouvement est imperceptible à l'image près — c'est une
respiration qu'« on ne voit pas, on la sent », dit le code lui-même. Mais la
machine, elle, refabrique deux gaussiennes et un dégradé, sous un verre, vingt
fois par seconde, pour chaque card. Et le verre posé dessus ne peut **rien**
mettre en cache, puisque ce qu'il y a dessous vient de changer.

C'est ça, la chaleur. Pas les vidéos (mesurées innocentes : 37 % contre 38 %).

---

## LE PLAN, dans l'ordre

### ① LE GESTE DE FOND : animer au lieu de redessiner *(aucun changement visible)*

Ce qui bouge ici est **une rotation**. Une rotation est une valeur *animable* :
le système sait l'interpoler lui-même, image par image, **sans jamais
reconstruire ce qu'il fait tourner**.

- **Avant** : `TimelineView` 20 Hz → on recalcule le dégradé, on redessine trois
  traits, on refait deux flous.
- **Après** : le liseré est construit **une seule fois** ; un
  `.rotationEffect(.degrees(phase))` animé par
  `withAnimation(.linear(duration: 9.4).repeatForever(autoreverses: false))`
  le fait tourner. Le dégradé, les traits et les flous ne sont **plus jamais
  refabriqués**.
- **Ce qu'elle voit** : la même respiration, **plus lisse** (interpolée à la
  cadence de l'écran au lieu d'être échantillonnée à 20 Hz).

⚠️ **Le piège, déjà payé** (`PageCard.swift:372-374`) : un `repeatForever` posé
par `withAnimation` **se fait avaler quand le parent est ré-évalué**. La phase
vit donc dans la FEUILLE et se ré-arme à `.task` / `onChange`. Si un site refuse
cette discipline : une vraie `CABasicAnimation` dans un `UIViewRepresentable`,
qui vit côté serveur de rendu et qu'aucune ré-évaluation ne peut annuler.

**Sites, par coût décroissant** — les mêmes trois questions à chaque fois :
*qu'est-ce que le temps fait ici ? est-ce animable ? le reste peut-il sortir de
la fermeture ?*

| site | ce que le temps y fait | animable ? |
|---|---|---|
| `WidgetsCards.swift:261` | rotation ±3° d'un liseré conique | **oui** — rotation |
| `WidgetsCards.swift:1019` et suivants (9 horloges) | à vérifier une par une | |
| `MenuNappe.swift:183-292` | 2 scalaires (`souffle`, `braise`) dans 109 lignes | **oui** — échelle + opacité |
| `HomeNuit.swift` (5 horloges d'ambiance) | opacités, échelles | **oui** a priori |
| `GaletEtape.swift:246` | shader nourri du temps | **non** — un shader a besoin du temps |

**Le barreau** : `-souffleHorloge` rejoue l'ancienne forme, pour un A/B dans le
même binaire.
**La preuve de dessin** : film 3 s des deux versions à 60 img/s, comparés
**image par image après recalage de phase** (une capture unique ne prouve rien :
les deux respirent, elles ne seront jamais en phase).
**La preuve de gain** : seau de sonde à 0/s, et la paire (cadence, processeur).

### ② LE VERRE SUR CE QUI BOUGE *(à trancher avec elle)*

Un verre natif ne peut rien mettre en cache si ce qu'il y a **dessous** change.
Mesuré : les six verres de l'accueil éteints → **37 % → 28 %**, le seul poste
isolé de toute la campagne.

Le geste ① traite la cause **par en dessous** : si plus rien ne redessine sous
le verre, le verre se tait tout seul. **On mesure donc ① AVANT de toucher au
verre.** Si l'écart persiste, alors seulement on lui pose la question.

### ③ CE QUI EST DÉJÀ FAIT, et qui n'est pas encore prouvé

- 18 horloges de l'accueil alignées sur un pas commun (20 Hz) + fermées quand
  l'accueil n'est pas affiché ;
- 9 horloges du Profil et d'Exercices fermées de même (elles tournaient derrière
  la home sans afficher un pixel) ;
- la pièce de lune du Profil figée (identique au pixel, documenté) ;
- le galet du chemin ramené de 120 Hz à 20 ;
- le ruban retiré (×3,2 en séance, mesuré).
**Aucune de ces trois premières n'a encore son chiffre** : son téléphone est
resté à l'état thermique 2. À mesurer à froid, et à dire tel quel.

---

## COMMENT ON MESURE, à partir de maintenant

La méthode complète est dans le skill `woop-performance`. Le minimum :

1. téléphone **froid** — thermique lu à la première seconde, si ≥ 1 on attend ;
2. **ordre alterné A B B A**, jamais A A A puis B B B ;
3. 3 × 60 s, **médiane** des secondes, les 15 premières jetées ;
4. on publie **la paire (cadence, processeur)**, jamais un chiffre nu ;
5. **un seul moteur à la fois** ;
6. la ligne `onglet` de la sonde est **la preuve** qu'on mesurait le bon écran.

---

## CE QU'ON NE SAIT TOUJOURS PAS

- **La part GPU.** La sonde ne mesure que les fils de l'app. Le serveur de rendu
  et le GPU lui sont invisibles — c'est structurel, et ça explique pourquoi le %
  ne bouge pas entre 60 et 21 images par seconde. Seul `Animation Hitches` ou
  `Metal System Trace` le diraient.
- **Le profileur d'Apple refuse de s'attacher** (« Timed out waiting for device
  to boot ») alors que tout est correct : mode développeur activé, appairé,
  câble, DDI disponible. Essayé en `--launch`, en `--attach`, par UDID et par
  nom. Sans lui, on classe à la main.
- **Le reste des 27 %.** ① et ② n'expliquent pas tout. On ne prétendra pas le
  contraire avant de l'avoir mesuré.
