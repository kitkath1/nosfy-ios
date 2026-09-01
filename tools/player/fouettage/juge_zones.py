"""Le juge SPÉCIAL PAGES SOMBRES (exos) : la luminance globale ne
distingue pas la page du player (amp ~6). Signature à DEUX ZONES :
  · HAUT  = le titre « Exercices » (x 150-520, y 190-300) — clair sur
    la page, couvert par le corps noir seulement en toute fin de vol ;
  · MILIEU = les titres de la grille (x 60-460, y 880-1120) — clairs
    sur la page, couverts dès p ~0,55.
États : page = les deux clairs (>=150) ; player = les deux éteints
(<80) ; sinon VOL. Puis les mêmes lois : ouvertures/fermetures moy>=5
min>=3, transitions <3 frames interdites, frames page stables
comparées (boîte de dalle + casse grossière)."""
import os, subprocess, sys
from PIL import Image, ImageFilter

film, dossier = sys.argv[1], sys.argv[2]
os.makedirs(dossier, exist_ok=True)
if not any(f.endswith(".png") for f in os.listdir(dossier)):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", film,
                    "-vf", "fps=60", os.path.join(dossier, "f%04d.png")],
                   check=True)
frames = sorted(f for f in os.listdir(dossier) if f.endswith(".png"))

hauts, mils = [], []
for f in frames:
    im = Image.open(os.path.join(dossier, f)).convert("L")
    h = im.crop((150, 190, 520, 300)).getextrema()[1]
    m = im.crop((60, 880, 460, 1120)).getextrema()[1]
    hauts.append(h)
    mils.append(m)

etats = []
for h, m in zip(hauts, mils):
    if h >= 120 and m >= 100:
        etats.append("page")
    elif h < 80 and m < 80:
        etats.append("player")
    else:
        etats.append("vol")

runs, courts = [], []
i = 0
while i < len(etats):
    if etats[i] == "vol":
        j = i
        while j < len(etats) and etats[j] == "vol":
            j += 1
        av = etats[i - 1] if i > 0 else "?"
        ap = etats[j] if j < len(etats) else "?"
        runs.append((i, j - i, av, ap))
        if av != "?" and ap != "?" and av != ap and (j - i) < 3:
            courts.append((i, j - i, av, ap))
        i = j
    else:
        i += 1
ouv = [n for _, n, av, ap in runs if av == "page" and ap == "player"]
fer = [n for _, n, av, ap in runs if av == "player" and ap == "page"]
print(f"frames {len(frames)} ; OUVERTURES: {ouv} ; FERMETURES: {fer} ; "
      f"transitions <3 frames {courts}")
moy = sum(ouv) / max(len(ouv), 1)
v1 = moy >= 5 and all(n >= 3 for n in ouv) and len(ouv) >= 2 and not courts
print("VERDICT VOL+SAUT (zones):", "OK" if v1 else "ECHEC")

stables = [i for i in range(8, len(etats) - 8)
           if all(e == "page" for e in etats[i - 8:i + 9])]
if len(stables) < 2:
    print("aucun plateau page stable — juge page aveugle ici")
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
    return (min(xs), max(xs), min(ys), max(ys)) if xs else None


# Le player MICRO-OUVERT masque la pilule sans changer les zones :
# un plateau n'est un VRAI repos que si la dalle s'y voit.
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
    print(f"dalle avant {ba} vs apres {bb}")
    v2 = ba is None and bb is None  # pas de dalle des deux cotes = coherent
else:
    d = [abs(p - q) for p, q in zip(ba, bb)]
    print(f"dalle avant {ba} vs apres {bb} ; ecarts {d}")
    v2 = d[0] <= 6 and d[2] <= 6 and d[3] <= 20 and d[1] <= 40
pa = ia.resize((20, 43)).filter(ImageFilter.GaussianBlur(1))
pb = ib.resize((20, 43)).filter(ImageFilter.GaussianBlur(1))
xa, xb = pa.load(), pb.load()
diffs = [abs(xa[x, y] - xb[x, y]) for y in range(43) for x in range(20)]
moy2 = sum(diffs) / len(diffs)
print(f"page f{a+1} vs f{b+1} ; casse grossiere : moy {moy2:.2f} "
      f"(seuil 10) ; max bloc {max(diffs)}")
v2 = v2 and moy2 <= 10
print("VERDICT PAGE (zones):", "OK" if v2 else "ECHEC")
sys.exit(0 if v1 and v2 else 1)
