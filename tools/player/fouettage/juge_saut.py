"""Le détecteur de SAUT v3 (§3.4bis point 5). La luminance globale ne
sait PAS résoudre une reprise en vol sur page sombre (le bord de card
qui traverse la dalle claire fait des falaises LÉGITIMES de ~25 % de
l'amplitude par frame). Les vrais signaux :
  a. FLASH : une frame ultra-claire ISOLÉE au milieu d'un vol ;
  b. TÉLÉPORTATION : une transition page<->player dont le run de vol
     fait < 3 frames (le vol légitime le plus court : 0,22 s = 13) ;
  c. le filet grossier : aucun pas EN VOL > 45 % de l'amplitude (une
     vraie téléportation traverse la moitié du profil d'un coup)."""
import os, sys
from PIL import Image

dossier = sys.argv[1]
frames = sorted(f for f in os.listdir(dossier) if f.endswith(".png"))
lums = []
for f in frames:
    im = Image.open(os.path.join(dossier, f)).convert("L").resize((40, 90))
    px = im.load()
    lums.append(sum(px[x, y] for y in range(0, 90, 2)
                    for x in range(0, 40, 2)) // (45 * 20))
haut, bas = max(lums), min(lums)
amp = max(haut - bas, 1)
seuil_h, seuil_b = haut - 3, bas + 3
etats = ["page" if l >= seuil_h else "player" if l <= seuil_b else "vol"
         for l in lums]

# a. le flash isolé
flashs = [i for i in range(1, len(lums) - 1)
          if lums[i] >= haut - 2
          and lums[i - 1] < haut - 6 and lums[i + 1] < haut - 6]

# b. les runs de vol trop courts entre DEUX états différents
courts = []
i = 0
while i < len(etats):
    if etats[i] == "vol":
        j = i
        while j < len(etats) and etats[j] == "vol":
            j += 1
        av = etats[i - 1] if i > 0 else "?"
        ap = etats[j] if j < len(etats) else "?"
        if av != "?" and ap != "?" and av != ap and (j - i) < 3:
            courts.append((i, j - i, av, ap))
        i = j
    else:
        i += 1

# c. le filet grossier
mx, imx = 0, -1
for i in range(len(lums) - 1):
    if etats[i] == "vol" or etats[i + 1] == "vol":
        d = abs(lums[i + 1] - lums[i])
        if d > mx:
            mx, imx = d, i + 1
seuil_c = amp * 0.45

print(f"frames {len(frames)} ; amp {amp} ; flashs isoles {flashs} ; "
      f"transitions <3 frames {courts} ; max pas en vol {mx} @f{imx} "
      f"(filet {seuil_c:.1f})")
ok = not flashs and not courts and mx <= seuil_c
print("VERDICT SAUT:", "OK" if ok else "ECHEC")
sys.exit(0 if ok else 1)
