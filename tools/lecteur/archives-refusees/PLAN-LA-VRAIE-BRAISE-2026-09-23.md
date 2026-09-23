# La vraie braise : la matière du feu, hyper-réaliste

**Plan pour une prochaine session. RIEN N'EST CODÉ.**
Dicté par Kathryn le 23-09-2026 au soir : « je veux l'effet de braise […] mais
**hyper réaliste avec toutes les nuances de jaune, blanc, orange** ».

Il complète `PLAN-LA-FLAMME-NOIRE-2026-09-23.md` (qui dit QUOI faire et dans
quel ordre) : celui-ci dit **de quelle matière** le feu est fait.

Planche (version poussée au maximum, 23-09 tard) :
<https://claude.ai/artifact/FtfhCmdY9CqG1mcDNWH6eo>
Première planche : <https://claude.ai/artifact/2BPpewx2VGeVKFtcE35orp>
Images et scripts : `maquettes-2026-09-23/` — `braise2.py` (six ingrédients),
`braise3.py` (**la version à viser**, douze couches), `h1..h4`, `r1..r4`,
`zoom.jpg`, `zoom-max.jpg`.

---

## 1. LA RAMPE DE CORPS NOIR — douze paliers

C'est elle qui donne toutes les nuances d'un coup. Distance au front → couleur :

| d | RGB | Ce que c'est |
|---|---|---|
| 0,0000 | `1.00 1.00 0.99` | blanc, presque bleuté — le plus chaud |
| 0,0035 | `1.00 0.99 0.90` | blanc chaud |
| 0,0070 | `1.00 0.95 0.68` | jaune paille |
| 0,0110 | `1.00 0.86 0.40` | jaune d'or |
| 0,0160 | `1.00 0.74 0.24` | ambre |
| 0,0220 | `1.00 0.58 0.13` | orange |
| 0,0290 | `0.99 0.42 0.07` | orange rouge |
| 0,0370 | `0.92 0.26 0.04` | vermillon |
| 0,0460 | `0.74 0.14 0.02` | rouge de braise |
| 0,0570 | `0.44 0.06 0.01` | braise sombre |
| 0,0700 | `0.16 0.03 0.01` | brun de cendre |
| 0,0870 | `0.00 0.00 0.00` | noir |

**Dans l'app** : une texture 1×64 RGBA cuite par script. Le shader lit la
distance et échantillonne. Une instruction.

⚠️ Le c&oelig;ur reste **BLANC** — « la brillance vient de la blancheur ».

## 2. LES LANGUES — le feu MONTE

La couche de flamme est **étirée vers le haut** : 26 pas de 2 px, chacun 10 %
plus faible, en gardant le maximum. Sans ça, c'est un contour, pas une flamme.
Un deuxième étirement plus court et plus vif (12 pas de 1,6 px) sur le seul
c&oelig;ur blanc donne les pointes.

## 3. ⭐ LA LUMIÈRE PORTÉE — le détail qui fait tout basculer

**Le papier pas encore mangé est ÉCLAIRÉ par le feu.** Deux flous larges de
l'intensité (σ 26 et σ 70), versés en orange `1.0 0.52 0.18` sur l'image, en
multiplicatif. C'est ce qui manquait le plus : avant, le feu n'éclairait rien.

## 4. DEUX TURBULENCES

Un bruit **lent** (4 octaves) pour les masses de flamme, un bruit **fin**
(9 octaves) pour le crépitement. Intensité = `0,42 + 0,38·lent + 0,30·fin`.
Ils modulent l'intensité, **jamais la teinte**.

## 5. LA FUMÉE

Un voile gris `0.72 0.66 0.62` à 7,5 %, étiré 40 pas vers le haut, flouté à 11.
On ne la voit pas, on la sent.

## 6. LES FLOCONS DE CENDRE

110 points se détachent du front, montent de 8 à 70 px en dérivant de ±10, et
s'éteignent. Ce sont eux qui disent que ça brûle vraiment.

---

## 7. ⚠️ CE QUE ÇA COÛTE — à lire avant d'écrire une ligne

**C'est le plus cher de tout ce qu'on a posé.** Les langues (26 décalages) et la
lumière portée (deux flous larges) demandent plusieurs passes.

- **Tout ce qui peut être cuit l'est** : le champ de combustion, les deux
  turbulences, la rampe. Trois textures dans les assets, comme les carrés
  anatomiques. Le shader **lit et seuille**, il ne génère rien.
- **Il ne vit que 0,6 s**, sur une **photographie** de l'écran qu'on quitte,
  jamais sur une vue vivante. C'est le seul endroit de l'app qui a le droit
  d'être aussi cher.
- **Barreau obligatoire** : `-sansFlamme`.
- **Repli si la mesure dit non** : garder la rampe et les langues, retirer la
  lumière portée et la fumée. On perd le détail qui fait tout, on garde le feu.

⚠️ **Rien n'est mesuré.** Les images sont un calcul Python sur les captures. Ça
se décide sur SON iPhone, thermique lu à 0 au départ.

---

## 8. Les cards, au moment de choisir

Inchangé depuis la première version de ce plan :

| Quand | Ce qui se passe |
|---|---|
| **La liste apparaît** | chaque card monte de 10 pt et s'allume, 30 ms après la précédente |
| **Le doigt appuie** | la card se réchauffe ; il se lève, elle refroidit (la loi de la lampe) |
| **Le tap** | le foyer du feu est posé **au point touché** : l'embrasement part de la card |

⚠️ **Aucune card ne respire ni ne scintille au repos.** Seize exercices qui
bougent tout seuls, c'est un sapin de Noël.

---

## 9. ⭐ LES SIX COUCHES DE PLUS — « fais hyper réaliste le plus possible »

Verdict du 23-09 tard. `braise3.py` les rend toutes. Elles sont ce qui sépare
une belle flamme d'une photographie.

| | Couche | Ce que c'est | Réglage |
|---|---|---|---|
| **A** | **La roussissure** | le papier **brunit AVANT de s'enflammer** — une bande brune court devant le front | 5,5 centièmes, puissance 1,6, brun `0.30 0.16 0.07` à 70 % |
| **B** | **Les braises qui survivent** | des grumeaux **rougeoient derrière le front** et s'éteignent | bruit 7 oct. > 0,68, vie `(1-derr/0,075)^2,1` |
| **C** | **Le bourrelet** | la tranche **se recroqueville vers le feu** : un liseré clair, puis son ombre | liseré à derr 0,004 ; ombre à 0,016 |
| **D** | **Les craquelures** | le charbon se fend en **réseau de fibres** | crête de bruit 10 oct. > 0,86 |
| **E** | **La halation** | l'&oelig;il bave autour des très hautes lumières | deux flous σ 34 et σ 95, sur le seul blanc > 0,80 |
| **F** | **Le tremblement de chaleur** | l'air **réfracte** au-dessus du front | déplacement suivant le gradient de la turbulence fine |

**A est la plus importante des six.** Sans la roussissure, le papier passe du
blanc au feu sans transition : c'est le signe le plus sûr du faux.

---

## 10. ⚠️ LA VÉRITÉ SUR LE COÛT — à lire AVANT de coder

**`braise3.py` est un rendu de laboratoire.** Douze couches, six flous larges,
deux déplacements de pixels. Sur une image fixe en Python, c'est gratuit.
**Sur un iPhone, en 0,6 s, ce n'est PAS tenable tel quel.** Une page immobile de
cette app coûte déjà 27 à 39 % de processeur.

**Ce qui EST tenable, et garde 90 % du résultat :** trois textures cuites par
script (champ de combustion, turbulence lente, turbulence fine) + la rampe de
64 px. Le shader lit trois textures et compose la rampe, les langues, la
roussissure et les braises du charbon. **Une passe.**

**L'ordre de sacrifice, si la mesure dit non :**

1. le tremblement de chaleur (un déplacement par pixel) ;
2. la halation (deux flous larges) ;
3. la lumière portée (deux flous larges) ;
4. la fumée.

**Les quatre à ne PAS lâcher** — ce sont elles qui portent le réalisme : la
rampe, les langues, **la roussissure**, le bourrelet.
