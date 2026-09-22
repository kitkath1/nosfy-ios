"""Cuit les carrés anatomiques de l'accueil Exercices depuis DEUX corps de référence
(face, dos), gris sur noir, générés une fois.

Verdicts 22-09 : « beaucoup de noir et de dégradé, les dessins plus petits, fondus,
sexy ». Donc : le dessin occupe ~60 % du carré, centré, et ses bords SE DISSOLVENT
dans le noir (un voile radial cuit dans l'alpha — aucun rectangle, aucun trait
d'image). Le corps est une gravure sombre à fils clairs ; la zone visée est claire ;
sa LUEUR (blanc pur + bloom 5 px) est une couche à part que la card fait respirer.
Le carré, son dégradé et sa lumière de verre sont dessinés par la card SwiftUI.

Sortie : typo-<zone> (RGBA) et typo-<zone>-lueur (RGBA) @1x/2x/3x, à la taille
d'affichage (540 px @3x pour un carré de ~171 pt)."""
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import numpy as np
from collections import deque

CORPS = {}
for nom in ("face", "dos"):
    arr = np.array(Image.open(f"corps-{nom}.png").convert("RGB")).astype(np.int16)
    CORPS[nom] = (arr, arr.mean(axis=2) > 85)
H, W = CORPS["face"][0].shape[:2]

def flood(mask, seeds):
    out = np.zeros_like(mask, dtype=bool); q = deque()
    for (x, y) in seeds:
        if mask[y, x] and not out[y, x]:
            out[y, x] = True; q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            nx, ny = x+dx, y+dy
            if 0 <= nx < W and 0 <= ny < H and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True; q.append((nx, ny))
    return out

# crop = (cx, cy, côté) : le CENTRE de la zone et le côté du carré — généreux,
# pour que le dessin reste petit dans la card et fonde sur les bords.
ZONES = {
  "haut":     {"corps": "face", "seeds": [(450,330),(585,330),(340,300),(680,300),(320,460),(700,460)],
               "cx": 512, "cy": 450, "cote": 950},
  "abdos":    {"corps": "face", "seeds": [(470,460),(545,460),(480,520),(540,520),(485,600),(535,600),(425,520),(600,520),(430,620),(595,620)],
               "cx": 512, "cy": 545, "cote": 880},
  "bas":      {"corps": "face", "seeds": [(420,760),(485,760),(535,760),(600,760),(400,900),(460,900),(560,900),(620,900),(430,1080),(600,1080)],
               "cx": 512, "cy": 930, "cote": 900},
  "fessiers": {"corps": "dos",  "seeds": [(455,670),(565,670)],
               "cx": 512, "cy": 740, "cote": 830},
  "cardio":   {"corps": "face", "seeds": "tout", "cx": 512, "cy": 760, "cote": 2100},
}

GRIS_CORPS = 44       # la masse du corps : presque la nuit (« plus dark »)
GRIS_LIGNE = 100      # les séparations : un fil discret
CLAIR_ZONE = 178      # la zone visée au creux : la lueur a de la place pour monter au blanc pur
TAILLE = 1080

def carre(zone, spec):
    a, gris = CORPS[spec["corps"]]
    tout = spec["seeds"] == "tout"
    m = gris.copy() if tout else flood(gris, spec["seeds"])
    rgb = np.zeros_like(a, dtype=np.uint8)
    rgb[gris] = GRIS_CORPS
    if not tout:
        corps_dilate = np.array(Image.fromarray((gris*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))) > 0
        lignes = corps_dilate & (a.mean(axis=2) < 45)
        rgb[lignes] = GRIS_LIGNE
        yy = np.arange(H)[:, None]
        deg = np.clip(1 - (yy - 200) / 1100, 0.55, 1.0)
        val = (CLAIR_ZONE * deg).astype(np.uint8)
        for c in range(3): rgb[..., c][m] = np.broadcast_to(val, (H, W))[m]
    else:
        # Le cardio : une SILHOUETTE fondue, sans aucun trait — le corps entier en
        # lumière douce (plus clair au cœur), les séparations effacées.
        yy = np.arange(H)[:, None]; k = np.clip(1 - np.abs(yy - 430) / 900, 0.5, 1)
        val = (120 + 85 * k).astype(np.uint8)
        m = np.array(Image.fromarray((gris*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))) > 0
        gris = m
        for c in range(3): rgb[..., c][m] = np.broadcast_to(val, (H, W))[m]
    # l'alpha du dessin : le corps (avec ses lignes), bords légèrement adoucis
    corps_alpha = Image.fromarray(((gris | (m)) * 255).astype(np.uint8))
    if not tout:
        corps_alpha = ImageChops.lighter(corps_alpha, Image.fromarray((lignes*255).astype(np.uint8)))
    corps_alpha = corps_alpha.filter(ImageFilter.GaussianBlur(0.8))
    base = Image.merge("RGBA", (Image.fromarray(rgb[...,0]), Image.fromarray(rgb[...,1]), Image.fromarray(rgb[...,2]), corps_alpha))
    # LE CHEVEU DE LUMIÈRE : le bord de la zone, 2 px au source (≈ 1 px affiché), blanc pur —
    # c'est lui qui fait la brillance, pas l'épaisseur.
    mk = Image.fromarray((m*255).astype(np.uint8))
    if not tout:
        ferme = mk.filter(ImageFilter.MaxFilter(7)).filter(ImageFilter.MinFilter(7))
        bord = ImageChops.subtract(ferme, ferme.filter(ImageFilter.MinFilter(5)))
        bord = ImageChops.multiply(bord, mk)
        rgb[np.array(bord) > 0] = 236
    # la lueur : la zone en blanc pur + un bloom serré (5 px) + un souffle large et faible
    serre = mk.filter(ImageFilter.GaussianBlur(6)).point(lambda v: int(v*0.55))
    hors_corps = Image.fromarray(((~np.array(Image.fromarray((gris*255).astype(np.uint8)).filter(ImageFilter.MaxFilter(9))).astype(bool)) * 255).astype(np.uint8))
    serre = ImageChops.multiply(serre, hors_corps)
    alpha = ImageChops.lighter(mk, serre)
    yy = np.arange(H)[:, None]
    deg = np.clip(1 - (yy - 200) / 1600, 0.6, 1.0)
    alpha = Image.fromarray((np.array(alpha).astype(np.float32) * np.broadcast_to(deg, (H, W))).astype(np.uint8))
    lueur = Image.merge("RGBA", (Image.new("L", mk.size, 255),)*3 + (alpha,))

    # le carré : centré sur la zone, généreux
    cx, cy, s = spec["cx"], spec["cy"], spec["cote"]; x0, y0 = cx - s//2, cy - s//2
    def cadre(img):
        sq = Image.new("RGBA", (s, s), (0,0,0,0))
        src = img.crop((max(x0,0), max(y0,0), min(x0+s, W), min(y0+s, H)))
        sq.paste(src, (max(0,-x0), max(0,-y0)))
        return sq.resize((TAILLE, TAILLE), Image.LANCZOS)
    sq, lu = cadre(base), cadre(lueur)
    # LE FONDU : un voile radial dans l'alpha — plein au centre, rien au bord.
    yy, xx = np.mgrid[0:TAILLE, 0:TAILLE]
    r = np.sqrt((xx - TAILLE/2)**2 + (yy - TAILLE/2)**2) / (TAILLE/2)
    t = np.clip((0.98 - r) / (0.98 - 0.58), 0, 1); voile = (t*t*(3-2*t) * 255).astype(np.uint8)
    for img in (sq, lu):
        al = np.array(img.split()[3]).astype(np.int32) * voile // 255
        img.putalpha(Image.fromarray(al.astype(np.uint8)))
    for k, px in ((1,180),(2,360),(3,540)):
        sq.resize((px,px), Image.LANCZOS).save(f"typo-{zone}@{k}x.png")
        lu.resize((px,px), Image.LANCZOS).save(f"typo-{zone}-lueur@{k}x.png")
    sq.resize((720,720), Image.LANCZOS).save(f"typo-{zone}-720.png")
    lu.resize((720,720), Image.LANCZOS).save(f"typo-{zone}-lueur-720.png")
    print(zone, "zone px", int(m.sum()))

for z, s in ZONES.items(): carre(z, s)
