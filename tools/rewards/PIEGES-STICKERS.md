# PIÈGES DES STICKERS PNG SUR LES CARDS NOIRES — payés le 26-08-2026

**Pour la prochaine session qui posera un sticker sur une card reward.**
Trois pièges m'ont coûté une dizaine d'allers-retours sur la
chauve-souris et la pastille du Welcome Back v2. Ils sont tous
reproductibles, et tous évitables.

---

## PIÈGE 1 — Détourer par la LUMINANCE rend un objet sombre FANTÔME

**Le symptôme** : le sticker apparaît translucide, « bizarre », on voit
la card à travers lui (verdict de Kathryn : « l'image est trop
transparente ! elle doit être pleine comme l'image de base »).

**La cause** : j'ai posé `alpha = luminance`. C'est une bonne ruse pour
un objet CLAIR sur fond noir. **Sur un objet NOIR posé sur du noir,
c'est une faute** : la matière de l'objet étant sombre, elle devient
elle-même transparente.

**La mesure** (sonde à refaire systématiquement) :

```python
al = np.array(Image.open(png).convert('RGBA'))[:, :, 3] / 255
dedans = al > 0.02
print(al[dedans].mean())      # doit être > 0.97
```

Avant : chauve-souris **0,46** (61 % de ses pixels sous la moitié),
pastille **0,85**. Après réparation : **0,993** et **0,996**.

**Le remède** : détourer par la **SILHOUETTE**, jamais par la
luminance — masque binaire (dedans = 1, dehors = 0), fermeture
morphologique pour souder les parties fines (les oreilles), remplissage
des trous, plus grande composante connexe, et un fondu de **1,5 px sur
le SEUL contour** (distance transform). ⚠️ Jamais un flou global : il
remange la matière et on retombe dans le piège.

**Cas particulier** : pour une forme géométrique simple (la pastille est
un carré arrondi), ne pas suivre le contour du tout — prendre la BOÎTE
du sujet et dessiner la forme exacte (`rounded_rectangle`). Suivre un
contour trop sombre déchirait son flanc gauche.

---

## PIÈGE 2 — Un sticker en `.background` d'une card opaque N'APPARAÎT PAS

**Le symptôme** : on veut que le personnage soit « caché par la card »,
on le met en `.background(alignment: .top)` avec un offset négatif… et
il ne se voit **nulle part**, même la partie qui dépasse au-dessus.

**Ce que j'ai cru voir** : deux « oreilles » au-dessus du bord — c'était
en réalité **les câbles de la photo de fond de la fiche exo**. Toujours
vérifier sur une capture PLEINE avant de conclure.

**Le remède** : garder le sticker en `.overlay`, et obtenir l'effet
« derrière » par la POSITION, pas par la couche.

---

## PIÈGE 3 — Un masque « coupe au bord » décapite le personnage

**Le symptôme** : on masque tout ce qui descend sous la ligne du bord
pour simuler « caché par la card » — et il ne reste que les oreilles.

**La cause** : dans l'asset, l'ordre vertical est **oreilles en haut,
tête au milieu, griffes en bas**. Un masque qui garde « les 80 % du
haut » garde donc les oreilles et coupe la tête.

**Le remède, et c'est tout ce qu'il fallait** : **aucun masque**. On
pose simplement le BAS du sticker (ses griffes) sur la ligne du bord :

```swift
.offset(y: respire - hauteurSticker * 1.0)   // le bas = le bord haut
```

Le corps n'existe pas (il a été coupé au détourage), donc rien ne
dépasse dans la card : la tête et les oreilles flottent au-dessus, les
griffes se posent sur la bordure. C'est la grammaire de la réf de
Kathryn (le personnage « Nosfy »).

---

## LEÇON DE MÉTHODE

Sur ce chantier j'ai enchaîné les essais de position au lieu de
diagnostiquer. Les trois pièges se voyaient à la mesure (l'opacité) ou
sur une capture pleine (le faux positif des câbles). **Mesurer d'abord,
déplacer ensuite** — et quand un point résiste, s'arrêter et proposer un
choix plutôt que tâtonner (verdicts reçus : « tu me saoules », « stop
coding », « t'y arrives pas »).

⚠️ Et n'ajouter QUE ce qui est demandé : j'avais ajouté un éclairage des
griffes et une bande claire au bord haut « pour aider » — non demandés,
retirés (« MAIS NON JE VEUX JUSTE QU'IL SOIT POSÉ EN HAUT »).
