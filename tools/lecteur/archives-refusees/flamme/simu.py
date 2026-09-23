# -*- coding: utf-8 -*-
"""UNE VRAIE COMBUSTION, SIMULÉE — puis cuite.

Le bruit empilé restera du bruit : il n'a pas de TOURBILLONS. Une flamme
réelle est un fluide — elle a des vortex, de la flottabilité, de la
vorticité qui s'enroule. Aucun `fbm` ne fabrique ça.

Donc on ne dessine plus le feu : on le SIMULE, une fois, hors ligne, puis
on cuit le résultat en atlas. C'est exactement la loi de la maison — « cuit
par script à la publication » — et à l'écran ça coûte UNE lecture de
texture.

Le solveur, classique (Stam 1999) et suffisant :
  · advection semi-lagrangienne du carburant et de la chaleur ;
  · flottabilité : le chaud monte, proportionnellement à sa température ;
  · CONFINEMENT DE VORTICITÉ — l'étape qui fait tout : elle réinjecte les
    petits tourbillons que la grille mange. Sans elle, une simulation de
    feu est molle et ressemble à de la fumée ;
  · projection (Poisson par Jacobi) pour garder le champ incompressible ;
  · combustion : le carburant brûle là où il est chaud, se transforme en
    chaleur, et la chaleur se dissipe.
"""
import numpy as np

def advect(q, u, v, dt):
    h, w = q.shape
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float32)
    x = np.clip(xs - dt*u, 0, w-1.001); y = np.clip(ys - dt*v, 0, h-1.001)
    x0 = x.astype(np.int32); y0 = y.astype(np.int32)
    x1 = x0+1; y1 = y0+1
    fx = x-x0; fy = y-y0
    return ((q[y0,x0]*(1-fx) + q[y0,x1]*fx)*(1-fy)
          + (q[y1,x0]*(1-fx) + q[y1,x1]*fx)*fy)

def projeter(u, v, iters=28):
    h, w = u.shape
    div = np.zeros_like(u); p = np.zeros_like(u)
    div[1:-1,1:-1] = -0.5*((u[1:-1,2:]-u[1:-1,:-2]) + (v[2:,1:-1]-v[:-2,1:-1]))
    for _ in range(iters):
        p[1:-1,1:-1] = (div[1:-1,1:-1] + p[1:-1,2:] + p[1:-1,:-2]
                        + p[2:,1:-1] + p[:-2,1:-1]) / 4.0
    u[1:-1,1:-1] -= 0.5*(p[1:-1,2:] - p[1:-1,:-2])
    v[1:-1,1:-1] -= 0.5*(p[2:,1:-1] - p[:-2,1:-1])
    return u, v

def vorticite(u, v, eps):
    """LE CONFINEMENT DE VORTICITÉ — il rend au feu les tourbillons que la
    grille lui a mangés. C'est CETTE étape qui sépare une flamme d'un nuage."""
    h, w = u.shape
    cur = np.zeros_like(u)
    cur[1:-1,1:-1] = ((v[1:-1,2:]-v[1:-1,:-2]) - (u[2:,1:-1]-u[:-2,1:-1]))*0.5
    a = np.abs(cur)
    gx = np.zeros_like(u); gy = np.zeros_like(u)
    gx[1:-1,1:-1] = (a[1:-1,2:]-a[1:-1,:-2])*0.5
    gy[1:-1,1:-1] = (a[2:,1:-1]-a[:-2,1:-1])*0.5
    n = np.sqrt(gx*gx+gy*gy) + 1e-5
    gx /= n; gy /= n
    u += eps * ( gy*cur)
    v += eps * (-gx*cur)
    return u, v

def simuler(H=520, W=260, pas=700, graine=5):
    """Le front de combustion part du BAS (le pouce) et remonte."""
    r = np.random.default_rng(graine)
    carb = np.ones((H, W), np.float32)              # le papier
    chal = np.zeros((H, W), np.float32)             # la chaleur
    u = np.zeros((H, W), np.float32)
    v = np.zeros((H, W), np.float32)
    # le grain du papier : il ne brûle pas partout à la même vitesse
    grain = r.random((H//6, W//6)).astype(np.float32)
    from scipy.ndimage import zoom, gaussian_filter
    grain = zoom(grain, (H/grain.shape[0], W/grain.shape[1]), order=1)[:H,:W]
    grain = gaussian_filter(grain, 2.0); grain = (grain-grain.min())/np.ptp(grain)
    carb *= 0.72 + 0.56*grain

    # l'allumage : une ligne irrégulière tout en bas
    chal[-3:, :] = 0.85 + 0.5*r.random((3, W)).astype(np.float32)

    sorties = []
    jalons = set(np.linspace(60, pas-1, 8).astype(int))
    for t in range(pas):
        # FLOTTABILITÉ : le chaud monte
        v -= chal * 0.95
        v[-5:, :] -= 0.14*r.random((5, W)).astype(np.float32)
        u[-5:, :] += (r.random((5, W)).astype(np.float32)-0.5)*0.30

        # ⚠️ BEAUCOUP DE VORTICITÉ : c'est elle qui fait les tourbillons.
        u, v = vorticite(u, v, 7.0)
        u, v = projeter(u, v)

        chal = advect(chal, u, v, 1.0)
        u = advect(u, u, v, 1.0); v = advect(v, u, v, 1.0)

        # ⚠️ LA COMBUSTION EST UN FRONT MINCE, PAS UN EMBRASEMENT.
        # Le carburant ne s'allume qu'au-dessus d'un seuil net, et il se
        # consume LENTEMENT : c'est ce qui garde une zone de réaction
        # étroite. À taux élevé, tout part d'un coup et on obtient des
        # taches plates — le premier réglage, refusé.
        allume = np.clip((chal - 0.26) / 0.16, 0, 1)
        feu = allume * np.clip(carb, 0, 1) * 0.20
        carb = np.clip(carb - feu*2.2, 0, None)
        chal = chal + feu*2.1
        # ⚠️ DISSIPATION FORTE : sans elle la chaleur s'accumule et remplit
        # l'écran d'orange. Une flamme est MINCE et le reste est noir.
        chal *= 0.974
        # ⚠️ LA DIFFUSION EST CE QUI PROPAGE LE FRONT : la chaleur doit
        # passer au carburant voisin pour l'allumer. Trop faible, le feu
        # s'éteint sur place (réglage précédent) ; trop forte, il devient
        # un nuage. 0,62 est l'équilibre trouvé.
        chal = gaussian_filter(chal, 0.62)
        u *= 0.990; v *= 0.990

        if t in jalons:
            sorties.append((carb.copy(), chal.copy()))
    return sorties

if __name__ == "__main__":
    from PIL import Image
    import numpy as np
    sor = simuler()
    print("images :", len(sor))
    np.save("simu_carb.npy", np.stack([c for c, _ in sor]))
    np.save("simu_chal.npy", np.stack([h for _, h in sor]))
    print("cuit.")
