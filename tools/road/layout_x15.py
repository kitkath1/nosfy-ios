import math
# Candidats de layout pour le chemin — base 874 pt, bande utile des galets.
# Contrainte : Ø 93 (×1,5 de 62), lune Ø 117 ; on mesure l'ÉCART ENTRE BORDS
# minimal entre toutes les paires de galets d'un écran (pas seulement voisins).
def ecart_min(nodes):
    m = 1e9; pair=None
    for i in range(len(nodes)):
        for j in range(i+1, len(nodes)):
            (x1,y1,d1),(x2,y2,d2) = nodes[i], nodes[j]
            e = math.hypot(x1-x2, y1-y2) - (d1+d2)/2
            if e < m: m = e; pair=(i,j)
    return m, pair

def sinus(n, pas, amp, w, phase=1.1, y0=700, lunes=()):
    out=[]
    for k in range(n):
        y = y0 - k*pas
        dx = amp*math.sin(w*k + phase)
        d = 117 if k in lunes else 93
        out.append((dx,y,d))
    return out

def zigzag(n, pas, amp, y0=700, lunes=()):
    out=[]
    for k in range(n):
        y = y0 - k*pas
        dx = amp * (1 if k%2==0 else -1)
        d = 117 if k in lunes else 93
        out.append((dx,y,d))
    return out

print("ACTUEL (10/écran, pas 58, Ø62, sinus 0.82, amp 78) :")
cur = [(min(max(78*math.sin(0.82*k+1.1),-92),92), 700-58*k, 62) for k in range(10)]
print("  écart min entre bords = %.1f" % ecart_min(cur)[0])
print()
cands = [
 ("A  9/écran pas 68.75 sinus lent 0.82 amp 78 (l'ancienne proposition ×1,5)", sinus(9,68.75,78,0.82,lunes=(4,8))),
 ("B  9/écran pas 68.75 zigzag ±60", zigzag(9,68.75,60,lunes=(4,8))),
 ("C  9/écran pas 68.75 sinus période 4 (w=1.57) amp 95", sinus(9,68.75,95,1.5708,phase=0.4,lunes=(4,8))),
 ("D  7/écran pas 90 sinus lent 0.82 amp 78", sinus(7,90,78,0.82,lunes=(6,))),
 ("E  6/écran pas 108 sinus lent 0.82 amp 78", sinus(6,108,78,0.82,lunes=(5,))),
 ("F  8/écran pas 78 sinus période 5 (w=1.26) amp 88", sinus(8,78,88,1.2566,phase=0.3,lunes=(3,7))),
 ("G  9/écran pas 68.75 sinus période 3 (w=2.09) amp 80", sinus(9,68.75,80,2.0944,phase=0.5,lunes=(4,8))),
]
for nom, nodes in cands:
    e, pair = ecart_min(nodes)
    ymin = min(n[1] for n in nodes); ymax=max(n[1] for n in nodes)
    print("%-62s écart min %6.1f (paire %s)  y %d→%d" % (nom, e, pair, ymax, ymin))

print()
print("ZIGZAGS ×1,5 — écart min entre bords (toutes paires), 874 pt de base")
import random
def zig_doux(n, pas, amp, jit, y0=700, lunes=(), seed=3):
    rnd = random.Random(seed); out=[]
    for k in range(n):
        y = y0 - k*pas + rnd.uniform(-jit, jit)
        a = amp * rnd.uniform(0.80, 1.0)
        dx = a * (1 if k%2==0 else -1)
        d = 117 if k in lunes else 93
        out.append((dx,y,d))
    return out
for nom, nodes in [
 ("B1  9/écran pas 68.75 zigzag ±60", zigzag(9,68.75,60,lunes=(4,8))),
 ("B2  9/écran pas 68.75 zigzag ±70", zigzag(9,68.75,70,lunes=(4,8))),
 ("B3  9/écran pas 68.75 zigzag doux 48-60 + jitter 6", zig_doux(9,68.75,60,6,lunes=(4,8))),
 ("B4 10/écran pas 61 zigzag ±62 (8 sessions + 2 lunes)", zigzag(10,61,62,lunes=(4,9))),
 ("B5 10/écran pas 61 zigzag ±70", zigzag(10,61,70,lunes=(4,9))),
 ("B6  8/écran pas 78 zigzag ±58 (6 sessions + 2 lunes)", zigzag(8,78,58,lunes=(4,7))),
 ("B7  9/écran pas 72 zigzag ±60 (y 700→124, mord la dalle ?)", zigzag(9,72,60,lunes=(4,8))),
]:
    e, pair = ecart_min(nodes)
    ymin = min(n[1] for n in nodes); ymax=max(n[1] for n in nodes)
    print("%-62s écart min %6.1f (paire %s)  y %d→%d" % (nom, e, pair, ymax, ymin))
