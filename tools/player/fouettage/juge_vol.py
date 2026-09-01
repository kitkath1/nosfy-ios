import os, subprocess, sys
from PIL import Image
film, dossier = sys.argv[1], sys.argv[2]
os.makedirs(dossier, exist_ok=True)
for f in os.listdir(dossier):
    os.remove(os.path.join(dossier, f))
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", film,
                "-vf", "fps=60", os.path.join(dossier, "f%04d.png")], check=True)
frames = sorted(os.listdir(dossier))
lums = []
for f in frames:
    im = Image.open(os.path.join(dossier, f)).convert("L").resize((40, 90))
    px = im.load()
    lums.append(sum(px[x, y] for y in range(0, 90, 2) for x in range(0, 40, 2)) // (45 * 20))
haut, bas = max(lums), min(lums)
seuil_h, seuil_b = haut - 3, bas + 3
etats = ["page" if l >= seuil_h else "player" if l <= seuil_b else "vol" for l in lums]
runs = []
i = 0
while i < len(etats):
    if etats[i] == "vol":
        j = i
        while j < len(etats) and etats[j] == "vol":
            j += 1
        runs.append((i, j - i, etats[i-1] if i > 0 else "?", etats[j] if j < len(etats) else "?"))
        i = j
    else:
        i += 1
ouv = [n for _, n, av, ap in runs if av == "page" and ap == "player"]
fer = [n for _, n, av, ap in runs if av == "player" and ap == "page"]
print(f"frames 60fps: {len(frames)} ; OUVERTURES: {ouv} ; FERMETURES: {fer}")
moy = sum(ouv)/max(len(ouv),1)
ok = moy >= 5 and all(n >= 3 for n in ouv) and len(ouv) >= 2
print("VERDICT VOL:", "OK (moy>=5, min>=3)" if ok else "ECHEC")
sys.exit(0 if ok else 1)
