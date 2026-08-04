#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - La lentille liquide — la pièce d'art
//
// UN SEUL OBJET, du premier pixel au chronomètre : la bulle de verre.
// Le doigt guide tout — l'émergence, la condensation, et jusqu'à la VISION :
// en fin de course, le verre cesse de montrer la page et révèle le monde
// d'après, courbé dans la bille — le velours, les quatre voix qui tournent
// déjà (formules et horloge d'eclipseHalo : à la coupe elles continuent
// leur geste sans le savoir), le cadran qu'on devine. Au relâcher, ce monde
// DÉBORDE de la bille — le noir ne vient jamais du fond : il sort d'elle.
//
// Il n'existe AUCUNE transition dans ce fichier : pas de balayage, pas de
// voile, pas de drain, pas de flash. Des matériaux et de la lumière.

static float lhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float lnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = lhash21(i);
    float b = lhash21(i + float2(1.0, 0.0));
    float c = lhash21(i + float2(0.0, 1.0));
    float d = lhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float lfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * lnoise(p);
        p = p * 2.03 + float2(11.7, 5.9);
        a *= 0.5;
    }
    return v;
}

// Le fbm du VELOURS — clone exact d'`efbm` (EclipseHalo.metal), mêmes
// décalages (17.1, 9.3) : le monde peint ici doit tisser le MÊME drap que
// le cadran, sinon la coupe se voit dans la trame.
static float vfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * lnoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

// MARK: Le monde-éclipse
//
// La scène du cadran, peinte pour un rayon R quelconque — les quatre voix
// d'eclipseHalo (mêmes constantes, même horloge `t`), le disque de velours,
// le liseré. Utilisée par la VISION (courbée dans la bille), par le
// DÉBORDEMENT (à l'échelle réelle), et — c'est le point — IDENTIQUE à ce
// que le cadran affichera après la coupe : les halos ne sentent rien.
static float3 eclipseWorld(float2 d, float r, float R, float t, float ig) {
    const float3 cols[4] = { float3(0.93, 0.95, 1.00),
                             float3(1.00, 0.70, 0.33),
                             float3(1.00, 1.00, 1.00),
                             float3(1.00, 0.78, 0.50) };
    const float speed[4] = {  6.2832 / 47.0, -6.2832 / 29.0,
                              6.2832 / 19.0, -6.2832 / 71.0 };
    const float phase[4] = { 0.4, 2.6, 4.4, 5.6 };
    const float rho0[4]  = { 1.02, 0.98, 1.01, 1.14 };
    const float srs[4]   = { 0.34, 0.19, 0.10, 0.42 };
    const float sts[4]   = { 0.66, 0.50, 0.34, 0.72 };
    const float bper[4]  = { 13.0, 8.1, 5.2, 21.0 };
    const float bbase[4] = { 0.72, 0.62, 0.50, 0.66 };
    const float bamp[4]  = { 0.28, 0.38, 0.50, 0.30 };
    const float wgt[4]   = { 0.50, 0.85, 0.85, 0.32 };
    const float kap[4]   = { 5.0, 9.0, 22.0, 3.5 };

    float2 n = r > 0.5 ? d / r : float2(0.0, -1.0);
    float insideDisc = 1.0 - smoothstep(R - 1.0, R + 0.5, r);
    float occ = smoothstep(R - 0.5, R + 1.8, r);
    float angP = atan2(d.y, d.x);

    float3 light = float3(0.0);
    float3 rimGlow = float3(0.0);
    float3 backTint = float3(0.0);
    for (int i = 0; i < 4; i++) {
        float igv = clamp(ig * 1.9 - float(i) * 0.24, 0.0, 1.0);
        igv = igv * igv * (3.0 - 2.0 * igv);
        if (igv < 0.003) { continue; }
        float ang = phase[i] + t * speed[i];
        float2 hd = float2(cos(ang), sin(ang));
        float rho = R * (rho0[i] + 0.05 * sin(t * 6.2832 / (bper[i] * 2.7)
                                              + phase[i] * 3.0));
        float dAng = angP - ang;
        dAng -= 6.2832 * floor(dAng / 6.2832 + 0.5);
        float rad = r - rho;
        float arc = dAng * max(rho, 1.0);
        float sr = srs[i] * R;
        float sg = sts[i] * R;
        float q = (rad * rad) / (sr * sr) + (arc * arc) / (sg * sg);
        float breath = bbase[i] + bamp[i] * sin(t * 6.2832 / bper[i]
                                                + phase[i] * 5.0);
        float g = 0.52 * exp(-q) + 0.48 * exp(-q * 0.32);
        float wv = wgt[i] * igv;
        float facing = max(dot(n, hd), 0.0);
        light += cols[i] * (g * breath * wv);
        rimGlow  += cols[i] * (pow(facing, kap[i]) * breath * wv);
        backTint += cols[i] * (pow(facing, 2.5) * breath * wv);
    }

    // Le velours du disque (drap vfbm ≡ efbm) + le liseré aux accents —
    // chacun calculé UNIQUEMENT là où il existe : le débordement couvre
    // l'écran entier, deux fbm par pixel pour rien mettaient le simulateur
    // à genoux.
    float3 velvet = float3(0.0);
    if (insideDisc > 0.001) {
        float edge = pow(clamp(r / max(R, 1.0), 0.0, 1.0), 5.0);
        float cloth = 0.80 + 0.40 * vfbm(d * 0.02 + float2(7.0, 3.0));
        velvet = (float3(0.008, 0.008, 0.011) + backTint * 0.05)
                 * (edge * cloth);
    }
    float dr2 = (r - R) * (r - R);
    float ring = exp(-dr2 / 1.35);
    float3 rim = float3(0.0);
    if (ring > 0.004) {
        float acc = vfbm(d * 0.05 + float2(t * 0.11, -t * 0.07));
        acc = acc * acc * acc;
        rim = (float3(0.05) + rimGlow * (0.55 + 2.2 * acc)) * ring;
    }

    float3 c = light * occ + rim + velvet * insideDisc;
    return 1.0 - exp(-c * 1.55);
}

// MARK: Les volutes d'encre
//
// La fumée noir-orangé qui suit le doigt, PEINTE DANS LA COUCHE que le
// verre réfracte — on la voit se tordre derrière la bille. Ses couleurs
// sont celles des quatre voix : ce sont les FUTURS halos, ils convergent
// dans la vision quand elle s'allume.
[[ stitchable ]] half4 inkVeil(float2 position, half4 color, float2 size,
                               float2 center, float R, float pDrive,
                               float t, float vision) {
    float gate = smoothstep(0.05, 0.35, pDrive) * (1.0 - vision);
    if (gate < 0.004) { return half4(0.0); }
    float2 rel = position - center;
    // Sorties précoces : les volutes vivent dans un couloir — pas deux fbm
    // par pixel sur tout l'écran.
    if (fabs(rel.x) > 175.0) { return half4(0.0); }
    // Le couloir du geste : sous la bille, le chemin déjà parcouru.
    float belowY = position.y - (center.y + R * 0.15);
    float wake = smoothstep(-30.0, 60.0, belowY)
                 * (1.0 - smoothstep(0.0, size.y * 0.78, belowY));
    float widen = 70.0 + 40.0 * smoothstep(0.0, 500.0, belowY);
    float corridor = exp(-pow(rel.x / widen, 2.0));
    float2 q = position * 0.012;
    float f1 = lfbm(q + float2(0.0, t * 0.10));
    float f2 = lfbm(q * 1.9 + float2(3.7, -t * 0.16) + 1.8 * f1);
    float wisp = pow(clamp(f2 * 1.35 - 0.25, 0.0, 1.0), 2.2);
    float a = wisp * wake * corridor * gate * 0.34;
    // Charbon dans les creux ; or profond et champagne dans les crêtes.
    float3 c = mix(float3(0.13, 0.10, 0.085),
                   mix(float3(1.00, 0.70, 0.33), float3(1.00, 0.78, 0.50), f1),
                   smoothstep(0.35, 0.85, f2));
    return half4(half3(c * a), half(a)) * color.a;
}

// MARK: La lentille
//
// `vision` : le monde d'après apparaît DANS le verre (0 → 1, sous le
// doigt). `spill` : ce monde déborde de la bille et recouvre la page
// (0 → 1, au relâcher). `sceneIg` : l'allumage des voix de la scène — il
// se poursuit tel quel côté cadran (naissance antidatée).
[[ stitchable ]] half4 liquidLens(float2 position, SwiftUI::Layer layer,
                                  float2 size, float2 center, float R,
                                  float f0, float disp, float ember,
                                  float squash, float shade, float t,
                                  float vision, float spill, float sceneIg) {
    float2 d = position - center;
    d.y *= squash;
    float r = length(d);
    float2 n = r > 0.5 ? d / r : float2(0.0, -1.0);
    float nr = r / max(R, 1.0);
    float2 lo = float2(0.5), hi = size - 0.5;
    float maxDim = max(size.x, size.y);

    // Le rayon du monde débordé (départ lent, le monde ÉCLOT puis inonde),
    // et l'échelle de la scène : le cadran qu'on devine PETIT dans la
    // bille grandit jusqu'à DEVENIR la bille.
    float Rw = R + pow(spill, 1.30) * (1.45 * maxDim);
    float sceneR = R * mix(0.36, 1.0, smoothstep(0.0, 0.65, spill));

    // ---- Dehors : le papier intact — ou le TROU vers le monde d'après.
    // Le débordement ne peint rien : il REND TRANSPARENT — dessous, le
    // VRAI monde du cadran est déjà monté (halos réels, vraie horloge).
    // Le monde qu'on devine est le monde qu'on obtient, et la coupe
    // technique consiste à retirer un calque déjà transparent : rien.
    if (nr >= 1.0) {
        if (spill > 0.001 && r < Rw) {
            return half4(0.0);
        }
        float outD = r - R;
        // Au bord du débordement, la page est REPOUSSÉE : compression
        // radiale douce juste devant le front.
        float push = (spill > 0.001)
            ? 24.0 * exp(-pow((r - Rw) / 30.0, 2.0)) : 0.0;
        half4 base = layer.sample(clamp(position + n * push, lo, hi));
        float3 rgb = float3(base.rgb);
        // L'ombre portée de la bulle, et la lueur de la braise du drag.
        float downing = clamp(0.30 + 0.70 * (0.5 + 0.5 * n.y), 0.0, 1.0);
        float sh = exp(-(outD * outD) / (R * 0.16 * R * 0.16))
                   * downing * 0.085 * shade;
        float crest = 0.35 + 0.65 * pow(clamp(-n.y, 0.0, 1.0), 1.2);
        float glow = exp(-outD / (R * 0.032)) * ember * crest;
        rgb = rgb * (1.0 - sh) + float3(1.0, 0.52, 0.14) * (glow * 0.18);
        // Le ménisque du front, côté papier.
        if (spill > 0.001) {
            float men = exp(-pow((r - Rw) / 16.0, 2.0));
            rgb += float3(1.0, 0.96, 0.88) * (men * 0.14);
        }
        return half4(half3(rgb), base.a);
    }

    // ---- Dedans : la calotte de verre.
    float bell = sqrt(max(1.0 - nr * nr, 0.0));
    float f = mix(1.32, f0, pow(bell, 0.82));
    float sep = disp * 0.055 * pow(nr, 2.4);
    float2 dir = float2(d.x, d.y / squash);
    float2 pR = clamp(center + dir * (f * (1.0 - sep)), lo, hi);
    float2 pG = clamp(center + dir * (f * (1.0 + sep * 0.40)), lo, hi);
    float2 pB = clamp(center + dir * (f * (1.0 + sep * 1.35)), lo, hi);
    half4 sG = layer.sample(pG);
    float3 rgb = float3(layer.sample(pR).r, sG.g, layer.sample(pB).b);

    // ---- L'habillage du verre — il ne cède JAMAIS : verre clair et verre
    // plein de nuit ont les mêmes reflets.
    rgb *= 1.0 - 0.045 * pow(nr, 3.5) * shade;
    float frost = smoothstep(0.955, 1.0, nr);
    rgb = mix(rgb, float3(0.965, 0.955, 0.935), frost * 0.14 * shade);

    // ---- Le ruban « inspiration » du drag (meurt dans la condensation).
    if (ember > 0.004) {
        float seat = 0.30 + 0.70 * pow(clamp(-n.y, 0.0, 1.0), 1.1);
        float swellR = 0.86 + 0.14 * lfbm(n * 1.15
                                          + float2(t * 0.09, -t * 0.06));
        float bandC = 0.80 * swellR;
        float dBand = (nr - bandC) / 0.115;
        float body = exp(-dBand * dBand);
        float3 col = mix(float3(1.00, 0.78, 0.28),
                         float3(0.98, 0.42, 0.06),
                         clamp(dBand * 0.7 + 0.5, 0.0, 1.0));
        rgb -= float3(0.14, 0.095, 0.055) * (body * seat * ember * 0.60);
        rgb += col * (body * seat * ember * 0.78);
        float soot = exp(-pow((nr - (bandC + 0.135)) / 0.05, 2.0));
        rgb -= float3(0.20, 0.15, 0.11) * (soot * seat * ember * 0.55);
        float capMask = clamp(body * seat * ember, 0.0, 1.0);
        rgb = mix(rgb, min(rgb, float3(0.95, 0.86, 0.72)), capMask * 0.85);
    }

    // ---- LA VISION : le monde d'après, courbé DANS le verre. Le doigt la
    // fait naître (fin de course) ; la scène est petite — on la DEVINE —
    // puis elle grandit avec le débordement jusqu'à devenir la bille.
    if (vision > 0.001) {
        float2 dFish = n * (pow(nr, 1.45) * R);
        float3 seen = eclipseWorld(dFish, length(dFish), sceneR, t, sceneIg);
        // La profondeur du verre : la vision est plus dense au cœur.
        float depth = 0.55 + 0.45 * bell;
        float inside = 1.0 - smoothstep(R - 1.0, R + 0.5, r);
        rgb = mix(rgb, seen, vision * depth * inside);
    }

    // ---- Les reflets, par-dessus tout — l'identité du verre.
    float band = smoothstep(0.82, 0.965, nr) * (1.0 - smoothstep(0.975, 1.0, nr));
    float up = clamp(-n.y, 0.0, 1.0);
    float down = clamp(n.y, 0.0, 1.0);
    float specK = shade * (1.0 - 0.78 * clamp(ember, 0.0, 1.0))
                  * (1.0 - 0.45 * smoothstep(0.6, 1.0, spill));
    rgb += float3(1.0) * (pow(up, 2.6) * band * 0.17 * specK);
    rgb += float3(1.0) * (pow(down, 3.2) * band * 0.06 * specK);
    float lip = exp(-pow((nr - 0.994) / 0.010, 2.0));
    rgb += float3(1.0, 0.99, 0.96) * (lip * 0.09 * shade
                                      * (1.0 - 0.6 * smoothstep(0.7, 1.0, spill)));

    // Anticrénelage du bord : sur le papier on retombe sur lui ; sur le
    // monde débordé on fond vers le TRANSPARENT — le vrai monde dessous.
    float aa = smoothstep(R - 1.6, R + 0.4, r);
    if (spill > 0.001) {
        float keep = 1.0 - aa;
        return half4(half3(clamp(rgb, 0.0, 2.0)) * keep, keep);
    }
    float3 outRGB = float3(layer.sample(position).rgb);
    rgb = mix(rgb, outRGB, aa);
    return half4(half3(clamp(rgb, 0.0, 2.0)), sG.a);
}
