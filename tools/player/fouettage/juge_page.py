"""Le juge PAGE v3 (§3.4bis point 2) : « rien ne casse en UI » par
SONDES D'ÉLÉMENTS, pas par égalité de pixels — les pages portent des
VIDÉOS de fond qui vivent (flammes home) : deux frames « page » ne
sont jamais égales pixel à pixel, et ce n'est pas une casse.

1. LA DALLE : dans la bande basse (H-170..H), la boîte englobante des
   pixels clairs (>60) — même centre et même étendue avant/après
   (± 6 px : la pilule respire, elle ne déménage pas).
2. LA CASSE GROSSIÈRE : les deux frames réduites à 20×43 et floutées —
   un élément qui déménage ou disparaît déplace des BLOCS entiers ;
   le scintillement vidéo se moyenne. Seuil généreux (moy <= 10)."""
import os, sys
from PIL import Image, ImageFilter

dossier = sys.argv[1]
frames = sorted(f for f in os.listdir(dossier) if f.endswith(".png"))
lums = []
for f in frames:
    im = Image.open(os.path.join(dossier, f)).convert("L").resize((40, 90))
    px = im.load()
    lums.append(sum(px[x, y] for y in range(0, 90, 2)
                    for x in range(0, 40, 2)) // (45 * 20))
haut = max(lums)
# Les frames de comparaison sont des PLATEAUX : la frame et ses ±8
# voisines au niveau page (haut-5) — jamais une frame de pic de
# respiration ni un début de montée du player.
stables = [i for i in range(8, len(lums) - 8)
           if all(l >= haut - 5 for l in lums[i - 8:i + 9])]
if len(stables) < 2:
    print(f"aucun plateau page stable ({len(stables)}) — juge aveugle ici")
    sys.exit(1)


def boite_dalle(im):
    W, H = im.size
    bande = im.crop((0, H - 170, W, H))
    px = bande.load()
    xs, ys = [], []
    for y in range(0, 170, 2):
        for x in range(0, W, 4):
            if px[x, y] > 60:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (min(xs), max(xs), min(ys), max(ys))


# ⚠️ Le player MICRO-OUVERT (p ~0,1) recouvre pile la bande et masque
# la pilule SANS changer la luminance globale : un plateau n'est un
# VRAI repos que si la dalle s'y voit. On préfère donc les plateaux
# AVEC dalle ; s'il n'y en a pas (page hors séance), on garde tous.
def a_dalle(i):
    im = Image.open(os.path.join(dossier, frames[i])).convert("L")
    b = boite_dalle(im)
    # la PILULE est LARGE (~1030 px) ; le trait (104 px) ou un reflet
    # ne comptent pas comme dalle
    return b is not None and (b[1] - b[0]) > 600


candidats = stables[::5] if len(stables) > 60 else stables
avec = [i for i in candidats if a_dalle(i)]
if len(avec) >= 2:
    stables = avec
a, b = stables[0], stables[-1]
ia = Image.open(os.path.join(dossier, frames[a])).convert("L")
ib = Image.open(os.path.join(dossier, frames[b])).convert("L")
W, H = ia.size


ba, bb = boite_dalle(ia), boite_dalle(ib)
if ba is None or bb is None:
    print(f"dalle : INTROUVABLE (avant {ba}, apres {bb})")
    ok1 = False
else:
    d = [abs(p - q) for p, q in zip(ba, bb)]
    print(f"dalle avant {ba} vs apres {bb} ; ecarts {d}")
    # xmin/ymin = la STRUCTURE (ancrage de la pilule) : +-6 px.
    # xmax = la fin du TEXTE (le chrono avance, il s'allonge) : +-40.
    # ymax = le bas de la LUEUR (badge/galet qui respirent) : +-20.
    ok1 = d[0] <= 6 and d[2] <= 6 and d[3] <= 20 and d[1] <= 40

pa = ia.resize((20, 43)).filter(ImageFilter.GaussianBlur(1))
pb = ib.resize((20, 43)).filter(ImageFilter.GaussianBlur(1))
xa, xb = pa.load(), pb.load()
diffs = [abs(xa[x, y] - xb[x, y]) for y in range(43) for x in range(20)]
moy = sum(diffs) / len(diffs)
print(f"page f{a+1} vs f{b+1} ; casse grossiere 20x43 : moy {moy:.2f} "
      f"(seuil 10) ; max bloc {max(diffs)}")
ok2 = moy <= 10
print("VERDICT PAGE:", "OK" if ok1 and ok2 else "ECHEC")
sys.exit(0 if ok1 and ok2 else 1)
