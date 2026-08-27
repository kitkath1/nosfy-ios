import math, numpy as np
from PIL import Image
# Écran 402×874 pt @3x. Positions des galets = la formule de EcranSpec (k=1 : 874 pt de haut).
def pos(n, ecran=0):
    id_ = ecran*10+n
    y = 700 - n*58
    phase = 1.1 + 1.9*ecran
    jitter = math.sin(id_*12.9898)*10
    dx = min(max(78*math.sin(0.82*n+phase)+jitter, -92), 92)
    return 201+dx, y
def lum(a): return 0.2126*a[...,0]+0.7152*a[...,1]+0.0722*a[...,2]
def stats(img, cx, cy, D):
    r = int(D/2*3)+8
    x, y = int(cx*3), int(cy*3)
    crop = np.asarray(img.crop((x-r, y-r, x+r, y+r)).convert('RGB')).astype(float)
    L = lum(crop)
    h, w = L.shape; yy, xx = np.mgrid[0:h,0:w]; rr = np.hypot(xx-w/2, yy-h/2)/(D/2*3)
    corps = L[(rr<0.80)]; anneau = L[(rr>0.90)&(rr<1.06)]
    def clair(v): 
        v = np.sort(v); return v[int(len(v)*0.9):].mean()   # les 10 % les plus clairs
    return dict(corps_moy=corps.mean(), corps_clair=clair(corps), anneau_clair=clair(anneau), anneau_moy=anneau.mean()), crop
img = Image.open('road-2-etats-etape5.png')
etats = {0:'accompli',1:'accompli',2:'RATÉ',3:'accompli',4:'accompli',5:'ACTIF',6:'prochain',7:'verrouillé',8:'verrouillé',9:'LUNE verrouillée'}
print("%-3s %-17s %7s %7s %8s %8s" % ('n','état','corpsµ','corps↑','anneauµ','anneau↑'))
tiles=[]
for n in range(10):
    cx, cy = pos(n); D = 78 if n==9 else 62
    s, crop = stats(img, cx, cy, D)
    print("%-3d %-17s %7.1f %7.1f %8.1f %8.1f" % (n, etats[n], s['corps_moy'], s['corps_clair'], s['anneau_moy'], s['anneau_clair']))
    tiles.append(Image.fromarray(crop.astype('uint8')).resize((150,150)))
sheet = Image.new('RGB', (150*10, 150)); [sheet.paste(t,(i*150,0)) for i,t in enumerate(tiles)]
sheet.save('planche-etats.png')
# Écart entre bords voisins (formule) et position du panneau vs galet actif (shot 1, étape 0)
print()
for n in range(9):
    (x1,y1),(x2,y2) = pos(n), pos(n+1); d1 = 78 if n==9 else 62; d2 = 78 if n+1==9 else 62
    print("n%d→n%d  centres %.1f pt  écart bords %.1f" % (n, n+1, math.hypot(x1-x2,y1-y2), math.hypot(x1-x2,y1-y2)-(d1+d2)/2))
ax, ay = pos(0)
print("\nGalet actif étape 0 : centre (%.1f, %.1f) pt ; panneau posé à x=201 (centre page), y = %d−116 = %d ; hauteur panneau ~110 → couvre y %d→%d, galets n1 (y %.0f) et n2 (y %.0f) dessous" % (ax, ay, ay, ay-116, ay-116-55, ay-116+55, pos(1)[1], pos(2)[1]))
print("Décalage horizontal galet→panneau : %.1f pt" % (201-ax))
