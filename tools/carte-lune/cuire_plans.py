#!/usr/bin/env python3
"""LES SIX PLANS D'UNE CARTE — le kit v2, étape 1 du Passage (20-09, sur son « go »).

D'une illustration, de sa profondeur vraie et de son détourage
(`cuire_profondeur.py`), on tire un DIORAMA : six plans RGBA, du plus loin
au plus proche, chacun complété DERRIÈRE par ce que les plans plus proches
lui cachent (inpainting) — quand la caméra les écarte, aucun trou.

    plan 1  le ciel et la lune           (opaque : tout ce qui est plus proche est reconstitué derrière)
    plan 2  les nuages
    plan 3  le lointain (montagnes, rivière)
    plan 4  le moyen (la vallée proche, les pins)
    plan 5  LA CRÉATURE (détourée, seule)
    plan 6  le premier plan (le rocher, les racines)

Les bandes viennent des quantiles de la profondeur HORS créature ; la
créature a son propre plan, et derrière elle le fond est reconstitué. La
reconstitution est OpenCV/Telea pour ce banc (grossière dans les grandes
zones, invisible aux courses de parallaxe du banc) ; LaMa ou le peintre de
la forge prendront le relais pour la qualité finale (plan du Passage, § 4).

Sorties dans `profondeur/<nom>/plans/` :
    <nom>-plan-1..6.png     RGBA, taille de l'illustration
    plans.json              [{fichier, profondeur, nom}] du plus loin au plus proche
    planche-plans.png       les six plans sur magenta + recomposition + test de parallaxe

    python3 cuire_plans.py <nom>      (après cuire_profondeur.py <art> <nom>)
"""
import json
import os
import sys

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as ndi

ICI = os.path.dirname(os.path.abspath(__file__))


def feather(mask, r):
    return ndi.gaussian_filter(mask.astype(np.float32), r)


def inpaint_telea(img8, mask8, rayon=9):
    return cv2.inpaint(img8, mask8, rayon, cv2.INPAINT_TELEA)


_LAMA = None


def _lama():
    """LaMa (ONNX, Carve/LaMa-ONNX, 512×512) : la reconstitution qui INVENTE la
    vallée derrière la créature au lieu d'un fantôme gris (planche-inpaint.png,
    20-09). Chargé une fois ; absent → Telea."""
    global _LAMA
    if _LAMA is None:
        try:
            import onnxruntime as ort
            from huggingface_hub import hf_hub_download
            chemin = hf_hub_download("Carve/LaMa-ONNX", "lama_fp32.onnx")
            _LAMA = ort.InferenceSession(chemin, providers=["CPUExecutionProvider"])
        except Exception as e:  # noqa: BLE001
            print("LaMa indisponible :", str(e)[:100], "→ Telea")
            _LAMA = False
    return _LAMA or None


def inpaint_rgb(img8, mask8, rayon=9, fin=True):
    """Reconstitution par LaMa : à la résolution NATIVE par tuiles de 512 px
    (recouvrement 128) quand `fin` — derrière la créature, là où ça se voit —
    sinon en DEMI-résolution (deux tuiles sur l'image réduite à 512×768,
    ~8× moins de calcul : les bandes derrière les plans ne se découvrent
    que sur quelques pixels). Telea si LaMa manque."""
    sess = _lama()
    if sess is None or not mask8.any():
        return inpaint_telea(img8, mask8, rayon)
    H, W, _ = img8.shape
    if not fin:
        names = [i.name for i in sess.get_inputs()]
        S = 512
        h2 = int(round(H * S / W / 8)) * 8
        im = np.asarray(Image.fromarray(img8).resize((S, h2), Image.BICUBIC)).astype(np.float32) / 255
        mk = (np.asarray(Image.fromarray(mask8 * 255).resize((S, h2), Image.NEAREST)) > 127).astype(np.float32)
        acc = np.zeros((h2, S, 3), np.float32)
        poids = np.zeros((h2, S), np.float32)
        fen = np.outer(np.hanning(S), np.hanning(S)).astype(np.float32) + 1e-3
        for yy in sorted(set([0, max(0, h2 - S)] + list(range(0, max(1, h2 - S + 1), 384)))):
            yy = min(yy, h2 - S)
            m = mk[yy:yy + S]
            if not m.any():
                continue
            x = im[yy:yy + S].transpose(2, 0, 1)[None]
            y = sess.run(None, {names[0]: x, names[1]: m[None, None]})[0][0].transpose(1, 2, 0)
            y = y / 255.0 if y.max() > 2 else y
            acc[yy:yy + S] += np.clip(y, 0, 1) * fen[..., None]
            poids[yy:yy + S] += fen
        rec_petit = im.copy()
        ok = poids > 0
        rec_petit[ok] = acc[ok] / poids[ok][..., None]
        rec = np.asarray(Image.fromarray((rec_petit * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)).astype(np.float32)
        a = np.clip(ndi.gaussian_filter((mask8 > 0).astype(np.float32), 1.5)[..., None] * 1.2, 0, 1)
        return np.clip(img8.astype(np.float32) * (1 - a) + rec * a, 0, 255).astype(np.uint8)
    ys, xs = np.nonzero(mask8)
    y0, y1 = max(0, ys.min() - 96), min(H, ys.max() + 96)
    x0, x1 = max(0, xs.min() - 96), min(W, xs.max() + 96)
    T, PAS = 512, 384
    out = img8.astype(np.float32).copy()
    poids = np.zeros((H, W), np.float32)
    acc = np.zeros((H, W, 3), np.float32)
    fen = np.outer(np.hanning(T), np.hanning(T)).astype(np.float32) + 1e-3
    names = [i.name for i in sess.get_inputs()]
    ty = list(range(y0, max(y0 + 1, y1 - T + 1), PAS)) + [max(y0, y1 - T)]
    tx = list(range(x0, max(x0 + 1, x1 - T + 1), PAS)) + [max(x0, x1 - T)]
    for yy in sorted(set(min(max(v, 0), H - T) for v in ty)):
        for xx in sorted(set(min(max(v, 0), W - T) for v in tx)):
            m = mask8[yy:yy + T, xx:xx + T]
            if not m.any():
                continue
            tuile = img8[yy:yy + T, xx:xx + T].astype(np.float32) / 255
            x = tuile.transpose(2, 0, 1)[None]
            mm = (m > 0).astype(np.float32)[None, None]
            y = sess.run(None, {names[0]: x, names[1]: mm})[0][0].transpose(1, 2, 0)
            y = y / 255.0 if y.max() > 2 else y
            acc[yy:yy + T, xx:xx + T] += np.clip(y, 0, 1) * 255 * fen[..., None]
            poids[yy:yy + T, xx:xx + T] += fen
    ok = poids > 0
    rec = out.copy()
    rec[ok] = acc[ok] / poids[ok][..., None]
    # fondu : la reconstitution SEULEMENT dans le masque (bord adouci de 3 px)
    a = ndi.gaussian_filter((mask8 > 0).astype(np.float32), 1.5)[..., None]
    a = np.clip(a * 1.2, 0, 1)
    return np.clip(out * (1 - a) + rec * a, 0, 255).astype(np.uint8)


def main():
    nom = sys.argv[1]
    d = os.path.join(ICI, "profondeur", nom)
    out = os.path.join(d, "plans")
    os.makedirs(out, exist_ok=True)
    # l'illustration retrouvée par la planche du kit (même dossier de références)
    src = None
    for rac in ("references-2026-09-18", "cimes-eteintes-2026-09-18", "bois-sans-lune-2026-09-18"):
        for f in sorted(os.listdir(os.path.join(ICI, rac))):
            if f.endswith(".png") and nom.split("-")[0] in f and "v3" in f:
                src = os.path.join(ICI, rac, f)
    if len(sys.argv) > 2:
        src = sys.argv[2]
    assert src, "illustration introuvable : passe son chemin en 2e argument"
    art = np.asarray(Image.open(src).convert("RGB"))
    H, W, _ = art.shape
    depth = np.asarray(Image.open(os.path.join(d, f"{nom}-depth-nue.png")).convert("L")).astype(np.float32) / 255
    sujet = np.asarray(Image.open(os.path.join(d, f"{nom}-sujet.png")).convert("L")).astype(np.float32) / 255
    if depth.shape != (H, W):
        depth = np.asarray(Image.fromarray((depth * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)).astype(np.float32) / 255
        sujet = np.asarray(Image.fromarray((sujet * 255).astype(np.uint8)).resize((W, H), Image.BILINEAR)).astype(np.float32) / 255

    # ── 1. le fond sans la créature, et sa profondeur continue derrière elle
    suj_dur = (sujet > 0.5).astype(np.uint8)
    # LA GARDE DU SUJET : un paysage pur (Faille, Col, Clairière) n'a pas de
    # créature — rembg rend alors un masque vide ou une tache absurde. Sous
    # 3 % ou au-dessus de 60 % de l'image, pas de plan créature : le monde se
    # découpe en bandes de profondeur seulement.
    part = float(suj_dur.mean())
    if part < 0.03 or part > 0.60:
        print(f"sujet ignoré ({part * 100:.1f} % de l'image) : paysage sans créature")
        suj_dur = np.zeros_like(suj_dur)
    suj_large = cv2.dilate(suj_dur, np.ones((13, 13), np.uint8))
    fond = inpaint_rgb(art, suj_large * 255, 11)
    depth8 = (depth * 255).astype(np.uint8)
    depth_fond = cv2.inpaint(depth8, suj_large * 255, 11, cv2.INPAINT_TELEA).astype(np.float32) / 255
    depth_fond = ndi.gaussian_filter(depth_fond, 2.0)
    # pour le RELIEF (la variante SceneKit) : le fond sans la créature, et sa profondeur continue
    Image.fromarray(fond).save(os.path.join(out, f"{nom}-fond.png"))
    Image.fromarray((np.clip(depth_fond, 0, 1) * 255).astype(np.uint8)).convert("RGB").save(os.path.join(out, f"{nom}-fond-depth.png"))   # RGB : SceneKit refuse le gris 8 bits

    # ── 2. les bandes : quantiles de la profondeur hors créature (proche → loin)
    vals = depth_fond[suj_large == 0]
    q = np.quantile(vals, [0.22, 0.45, 0.66, 0.86])
    # bandes du plus proche (6) au plus loin (1) — la créature sera le 5
    bornes = [(-1.0, q[0]), (q[0], q[1]), (q[1], q[2]), (q[2], q[3]), (q[3], 2.0)]
    noms = ["le premier plan", "le moyen", "le lointain", "les nuages", "le ciel et la lune"]
    plans = []   # (image RGBA, profondeur, nom), du proche au loin
    nearer = np.zeros((H, W), np.uint8)
    for i, ((lo, hi), n_) in enumerate(zip(bornes, noms)):
        bande = ((depth_fond >= lo) & (depth_fond < hi)).astype(np.uint8)
        # la couleur : le fond reconstitué derrière tout ce qui est plus proche
        if nearer.any():
            couleur = inpaint_rgb(fond, cv2.dilate(nearer, np.ones((7, 7), np.uint8)) * 255, 9, fin=False)
        else:
            couleur = fond
        # l'alpha : la bande, plus tout ce qui est plus proche (reconstitué) ; le ciel est opaque
        alpha = np.clip(feather(np.maximum(bande, nearer), 1.6), 0, 1)
        if i == len(bornes) - 1:
            alpha = np.ones((H, W), np.float32)
        prof = float(np.median(depth_fond[bande > 0])) if bande.any() else float((lo + hi) / 2)
        rgba = np.dstack([couleur, (alpha * 255).astype(np.uint8)])
        plans.append((rgba, prof, n_))
        nearer = np.maximum(nearer, bande)
    # la créature : son plan à elle, profondeur = la sienne (si elle existe)
    if suj_dur.any():
        alpha_c = np.clip(feather(suj_dur, 0.8) * 1.15, 0, 1)
        prof_c = float(np.median(depth[suj_dur > 0]))
        rgba_c = np.dstack([art, (alpha_c * 255).astype(np.uint8)])
        # ordre final du plus loin au plus proche : ciel, nuages, lointain, moyen, créature, premier plan
        ordre = [plans[4], plans[3], plans[2], plans[1], (rgba_c, prof_c, "la créature"), plans[0]]
        # la créature passe DEVANT le moyen mais derrière le premier plan si sa profondeur le dit
        if prof_c < plans[0][1]:
            ordre = [plans[4], plans[3], plans[2], plans[1], plans[0], (rgba_c, prof_c, "la créature")]
    else:
        ordre = [plans[4], plans[3], plans[2], plans[1], plans[0]]
    manifeste = []
    for k, (rgba, prof, n_) in enumerate(ordre, start=1):
        f = f"{nom}-plan-{k}.png"
        Image.fromarray(rgba, "RGBA").save(os.path.join(out, f))
        manifeste.append({"fichier": f, "profondeur": round(prof, 3), "nom": n_})
    json.dump(manifeste, open(os.path.join(out, "plans.json"), "w"), ensure_ascii=False, indent=1)

    # ── 3. la planche : chaque plan sur magenta, la recomposition, un test de parallaxe
    w = 300
    h = int(w * H / W)
    vues = []
    for rgba, prof, n_ in ordre:
        im = Image.fromarray(rgba, "RGBA").resize((w, h), Image.BILINEAR)
        fond_mag = Image.new("RGBA", (w, h), (255, 0, 255, 255))
        vues.append(Image.alpha_composite(fond_mag, im).convert("RGB"))
    recomp = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for rgba, _, _ in ordre:
        recomp = Image.alpha_composite(recomp, Image.fromarray(rgba, "RGBA"))
    vues.append(recomp.convert("RGB").resize((w, h), Image.BILINEAR))
    # le test de parallaxe : chaque plan décalé selon (profondeur − 0,45) × 60 px — les trous se voient ici
    para = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    for rgba, prof, _ in ordre:
        dx = int(-(prof - 0.45) * 60 * 1.6)
        dy = int(-(prof - 0.45) * 60 * 0.9)
        im = Image.fromarray(rgba, "RGBA")
        s = 1.0 + max(0.0, 0.45 - prof) * 0.18
        im = im.resize((int(W * s), int(H * s)), Image.BILINEAR)
        cal = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        cal.paste(im, ((W - im.width) // 2 + dx, (H - im.height) // 2 + dy), im)
        para = Image.alpha_composite(para, cal)
    vues.append(para.convert("RGB").resize((w, h), Image.BILINEAR))
    pl = Image.new("RGB", (len(vues) * (w + 8) + 8, h + 30), (4, 4, 6))
    x = 8
    for v in vues:
        pl.paste(v, (x, 22))
        x += w + 8
    pl.save(os.path.join(out, "planche-plans.png"))
    print("OK", nom, "—", [(m["nom"], m["profondeur"]) for m in manifeste])


if __name__ == "__main__":
    main()
