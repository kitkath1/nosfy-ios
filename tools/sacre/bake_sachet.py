#!/usr/bin/env python3
"""
bake_sachet.py — LE SACHET HÉROS de la card booster, v3 : LE CORPS PAR LE PLASTIQUE.

Entrée  : Nosfy/Assets.xcassets/booster-orange.imageset/booster-orange.png
          (1054 × 1408, RGBA — un VRAI détourage, fait hors d'ici.)
Sortie  : Nosfy/Assets.xcassets/booster-hero.imageset/booster-hero.png

L'HISTOIRE DE CE FICHIER, en trois verdicts de Kathryn (30-08) :
  v1  un alpha « de luminance » reparti du rendu → un voile gris rectangulaire
      (156 841 px mi-transparents sombres). « Très mal détouré. »
  v2  la recette du coffre (`bake_vignettes.py` : durcir 0,55 + coupe 1310) →
      « toujours le bug du détourage, tu vas trop vite ». Au zoom natif :
      (1) la coupe à 1310 tombe AU MILIEU du cran du bas — il finit à 1321 ;
      (2) deux PIEDS ORANGE sous les coins et un bloom le long des flancs, qui
      survivent à TOUT seuil : ils sont OPAQUES dans l'alpha de la source
      (bloom dans l'anneau de 40 px hors du corps : 51 450 px à 0,55, encore
      16 402 à 0,90). L'alpha ne distingue pas cette lueur du plastique.
  v3  CE FICHIER. Ce qui les distingue, c'est la COULEUR : le plastique est
      SOMBRE, la lueur est orange et claire. Le corps = par ligne, le span du
      plastique opaque et sombre (lissé sur 15 lignes — un sachet n'a pas de
      trou), + 4 px pour le liseré néon qui vit SUR le bord, crans prolongés
      droits, FLANCS DROITS sous le cadre néon (y ≥ 1180 : c'est là que vivent
      les pieds — un critère « neutre » R−G < 25 les excluait mais mangeait les
      flancs, qui reflètent l'orange : 766 px de large au lieu de 780), coupe
      à 1322. Mesuré : bloom 51 450 → 3 295 px (− 94 %), cran complet, liseré
      entier. Preuve : tools/sacre/vignettes/sachet-corps-plastique.png.

⚠️ Ce N'EST PAS le re-détourage interdit par `bake_vignettes.py` (« je
reconstruisais une silhouette que quelqu'un avait déjà détourée ») : on part
de l'alpha livré et on en RETIRE la lueur que l'auteur y a laissée opaque.
La règle reste : la lueur appartient à la SCÈNE (la card la refait en radial).
"""
import os, json
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = f"{REPO}/Nosfy/Assets.xcassets/booster-orange.imageset/booster-orange.png"
OUT = f"{REPO}/Nosfy/Assets.xcassets/booster-hero.imageset"
VIG = f"{REPO}/tools/sacre/vignettes"

COUPE = 1322          # la fin réelle du cran du bas (+1) ; en dessous, le reflet
DROIT = 1180          # sous le cadre néon, le sachet est droit — et les pieds y vivent
LUMA_PLASTIQUE = 70   # le plastique est sombre ; la lueur est claire
LISERE = 4            # px : le liseré néon vit SUR le bord du plastique
LISSAGE = 15          # lignes : le contour d'un sachet est doux
PLUME = 1.2
MARGE = 6

im = Image.open(SRC).convert("RGBA")
s = np.asarray(im).astype(float)
al, rgb = s[..., 3] / 255.0, s[..., :3]
H, W = al.shape
lum = rgb.max(axis=2)

# ── LE CORPS : le span du plastique sombre, par ligne ─────────────────────
plastique = (al > 0.9) & (lum < LUMA_PLASTIQUE)
plastique[COUPE:] = False
lo = np.full(H, -1); hi = np.full(H, -1)
for y in range(COUPE):
    xs = np.where(plastique[y])[0]
    if len(xs) >= 20:
        lo[y], hi[y] = xs[0], xs[-1]
valides = np.where(lo >= 0)[0]
first = valides[0]
lo[:first] = lo[first]; hi[:first] = hi[first]            # le cran du haut : droit
lo_ref = int(np.median(lo[DROIT - 40:DROIT]))
hi_ref = int(np.median(hi[DROIT - 40:DROIT]))
lo[DROIT:COUPE] = lo_ref; hi[DROIT:COUPE] = hi_ref        # sous le cadre : droit
lo_s = ndi.median_filter(lo[:COUPE], size=LISSAGE)
hi_s = ndi.median_filter(hi[:COUPE], size=LISSAGE)
corps = np.zeros((H, W), bool)
for y in range(COUPE):
    corps[y, lo_s[y]:hi_s[y] + 1] = True
corps = ndi.binary_dilation(corps, iterations=LISERE)
# la plume ; au-dessus du cadre néon, jamais plus opaque que la source (son
# antialiasing des flancs). ⚠️ SOUS LE CADRE (y ≥ DROIT), ON NE PONDÈRE PLUS
# PAR L'ALPHA DE LA SOURCE : l'auteur y a FONDU le cran dans son reflet
# (mesuré : alpha médian 1,00 à y = 1240 → 0,58 à y = 1321) — en le
# multipliant, on livrait un cran à demi transparent, et c'est CE fondu qui se
# lisait comme une coupe au pied. Là, le corps est du plastique : opaque.
pond = np.clip(al * 1.2, 0, 1)
pond[DROIT:] = 1.0
alpha = np.clip(ndi.gaussian_filter(corps.astype(float), PLUME) * pond, 0, 1)

ys, xs = np.where(alpha > 0.02)
x0, x1, y0, y1 = max(0, xs.min() - MARGE), min(W, xs.max() + MARGE + 1), \
                 max(0, ys.min() - MARGE), min(H, ys.max() + MARGE + 1)
out = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
out[..., :3] = rgb[y0:y1, x0:x1].round().astype(np.uint8)
out[..., 3] = (alpha[y0:y1, x0:x1] * 255).round().astype(np.uint8)
print(f"corps par le plastique : {int(corps.sum())} px, flancs sous {DROIT} : "
      f"{lo_ref}-{hi_ref} ; livré {x1 - x0}×{y1 - y0} (x {x0}-{x1 - 1}, y {y0}-{y1 - 1})")

os.makedirs(OUT, exist_ok=True)
Image.fromarray(out).save(f"{OUT}/booster-hero.png")
with open(f"{OUT}/Contents.json", "w") as f:
    json.dump({"images": [{"filename": "booster-hero.png", "idiom": "universal"}],
               "info": {"author": "xcode", "version": 1}}, f, indent=2)

# ── v4 : LES DEUX PIÈCES — le capuchon et le corps, séparés par la déchirure ─
#
# Le geste (PLAN §13) : au drag, le sachet SE DÉCHIRE — le capuchon (le cran
# du haut + un peu de plastique) monte avec le doigt, le corps reste. Les deux
# pièces sont cuites ici sur le MÊME canevas que le héros (elles se posent au
# pixel l'une sur l'autre dans SwiftUI, même `scaledToFit`), séparées par une
# LIGNE EN ZIGZAG — dents de ~5 px, amplitude ±6 — tirée d'un bruit
# DÉTERMINISTE (jamais un `random` : deux captures doivent être comparables).
# La ligne vit sous le cran et au-dessus du cadre néon (mesuré : cran 0 → ~40,
# plastique noir ensuite, cadre à partir de ~90) : là où un vrai sachet cède.
# Le corps reçoit sur son bord déchiré un LISERÉ DE PLASTIQUE ARRACHÉ (blanc
# chaud, 14 px en dégradé — 1 px ne ferait rien à 8,5 px/pt), le capuchon un
# plus fin (6 px). Ce liseré n'existe QUE là : fermé, on ne le voit pas.
Hh, Wh = out.shape[:2]
Y_TEAR = 62                                   # px @héros, depuis le haut
xs_ = np.arange(Wh)
dents = 6 * np.sign(np.sin(xs_ * 0.62)) * (0.6 + 0.4 * np.abs(np.sin(xs_ * 0.173 + 1.0)))
onde = 3 * np.sin(xs_ * 0.041 + 0.7)
ligne = (Y_TEAR + dents + onde).round().astype(int)
yy = np.arange(Hh)[:, None]
haut = yy < ligne[None, :]                    # le capuchon
cap = out.copy(); cap[..., 3] = np.where(haut, out[..., 3], 0)
corps_px = out.copy(); corps_px[..., 3] = np.where(haut, 0, out[..., 3])
# le liseré arraché : un dégradé blanc chaud DEPUIS la ligne, vers le bas sur
# le corps (14 px) et vers le haut sur le capuchon (6 px), là où il y a du sachet
dist_bas = np.clip(yy - ligne[None, :], 0, 10_000)
dist_haut = np.clip(ligne[None, :] - 1 - yy, 0, 10_000)
chaud = np.array([255, 236, 214], float)
for piece, dist, prof in ((corps_px, dist_bas, 14.0), (cap, dist_haut, 6.0)):
    k = np.clip(1 - dist / prof, 0, 1) ** 1.6 * 0.85
    k = k * (piece[..., 3] > 128)
    piece[..., :3] = (piece[..., :3] * (1 - k[..., None]) + chaud * k[..., None]).round().astype(np.uint8)
for nom, arr in (("booster-hero-cap", cap), ("booster-hero-corps", corps_px)):
    d_ = f"{REPO}/Nosfy/Assets.xcassets/{nom}.imageset"
    os.makedirs(d_, exist_ok=True)
    Image.fromarray(arr).save(f"{d_}/{nom}.png")
    with open(f"{d_}/Contents.json", "w") as f:
        json.dump({"images": [{"filename": f"{nom}.png", "idiom": "universal"}],
                   "info": {"author": "xcode", "version": 1}}, f, indent=2)
# le portillon des pièces : réassemblées, elles REDONNENT le héros (hors liseré)
ensemble = np.maximum(cap[..., 3], corps_px[..., 3])
print(f"[pièces] ligne de déchirure à y = {Y_TEAR} ± {int(np.abs(dents + onde).max())} px "
      f"= {Y_TEAR / Hh:.4f} de la hauteur (→ `CoteBooster.ligneDechirure`) ; "
      f"capuchon {int((cap[..., 3] > 128).sum())} px, corps {int((corps_px[..., 3] > 128).sum())} px ; "
      f"alpha réassemblé ≡ héros : {'OUI' if np.array_equal(ensemble, out[..., 3]) else 'NON ⚠️'}")

# ── LE PORTILLON ───────────────────────────────────────────────────────────
anneau = ndi.binary_dilation(corps, iterations=40) & ~corps
bloom = int(((alpha > 0.1) & anneau).sum())
A = out[..., 3].astype(float) / 255.0
larg = []
for y in range(A.shape[0]):
    p = np.where(A[y] > 0.9)[0]
    if len(p):
        t = np.where((A[y, :p[0]] > 0.1) & (A[y, :p[0]] < 0.9))[0]
        larg.append(len(t))
# ⚠️ La sonde du cran se lit TROIS lignes au-dessus de la coupe : la dernière
# ligne est la ligne PLUMÉE (gaussienne 1,2 px), elle ne peut pas être opaque
# — une première version l'y lisait et criait « COUPÉ » sur un cran entier.
# Et la transition du bord vaut la plume + le liseré dilaté : 4 px, pas 2 (la
# référence sticker-booster est une coupe NETTE, sans plume).
y_cran = COUPE - 3 - y0
cran = int((A[y_cran] > 0.5).sum()) if 0 <= y_cran < A.shape[0] else 0
print(f"[portillon] BLOOM hors corps : {bloom} px (v2 : 51 450 ; visé < 5 000) "
      f"{'OK' if bloom < 5000 else '⚠️'}")
print(f"[portillon] bord : transition médiane {np.median(larg):.0f} px, "
      f"p90 {np.percentile(larg, 90):.0f} (visé ≤ 4 : plume + liseré) "
      f"{'OK' if np.percentile(larg, 90) <= 4 else '⚠️'}")
print(f"[portillon] le cran du bas : {cran} px sur la ligne y = {COUPE - 3} "
      f"(la dernière non plumée) {'OK' if cran > 600 else '⚠️ COUPÉ'}")
print(f"[portillon] alpha aux bords du fichier : haut {int(out[0, :, 3].max())}, "
      f"bas {int(out[-1, :, 3].max())}, gauche {int(out[:, 0, 3].max())}, "
      f"droite {int(out[:, -1, 3].max())} (0 attendu)")

# ── LA PLANCHE : coins sur gris, entier sur trois fonds, le liseré ────────
os.makedirs(VIG, exist_ok=True)
hero = Image.fromarray(out)


def tuile(box, fond, size):
    im2 = hero.crop(box)
    f2 = Image.new("RGB", im2.size, (fond,) * 3)
    f2.paste(im2, (0, 0), im2)
    return f2.resize(size, Image.LANCZOS)


hw, hh = hero.size
P = Image.new("RGB", (1260, 560), (0, 0, 0))
P.paste(tuile((0, hh - 370, 560, hh), 60, (420, 277)), (0, 0))
P.paste(tuile((hw - 560, hh - 370, hw, hh), 60, (420, 277)), (420, 0))
P.paste(tuile((0, 0, 560, 370), 60, (420, 277)), (840, 0))
for i, fond in enumerate((17, 60, 4)):
    e = hero.copy(); e.thumbnail((212, 283))
    f2 = Image.new("RGB", e.size, (fond,) * 3); f2.paste(e, (0, 0), e)
    P.paste(f2, (i * 212, 277))
P.paste(tuile((hw // 2 - 280, 300, hw // 2 + 280, 670), 60, (420, 277)), (636, 277))
P.save(f"{VIG}/sachet-hero-fonds.png")
print(f"planche → {VIG}/sachet-hero-fonds.png")

# la planche de la déchirure : fermée · capuchon levé de 40 px · de 90 px, sur gris
def dechire(lev):
    f2 = Image.new("RGB", (hw, 420), (60, 60, 60))
    c_ = Image.fromarray(corps_px).crop((0, 0, hw, 420))
    f2.paste(c_, (0, 0), c_)
    k_ = Image.fromarray(cap).crop((0, 0, hw, 420))
    f2.paste(k_, (0, -lev), k_)
    return f2.resize((420, int(420 * 420 / hw)), Image.LANCZOS)


D = Image.new("RGB", (1260, int(420 * 420 / hw)), (0, 0, 0))
for i, lev in enumerate((0, 40, 90)):
    D.paste(dechire(lev), (i * 420, 0))
D.save(f"{VIG}/sachet-dechirure.png")
print(f"planche → {VIG}/sachet-dechirure.png (fermé · 40 px · 90 px)")
