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

// Deux octaves : pour les champs DOUX (nuages, grain) — la troisième
// octave y est invisible et le simulateur compte ses fbm.
static float lfbm2(float2 p) {
    float v = 0.5 * lnoise(p);
    v += 0.25 * lnoise(p * 2.03 + float2(11.7, 5.9));
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

// MARK: La tache d'encre — L'ENCRE DANS L'EAU
//
// Une TACHE, pas un tube — et une tache qui suit le VRAI tracé : les
// stations vivent en abscisse curviligne (x, y, âge, flânerie), le pixel
// cherche sa distance SIGNÉE au chemin — descentes, crochets, boucles,
// tout est permis au doigt (le paramétrage par la hauteur seule tirait
// des traits droits dès que le geste se repliait). La silhouette est
// tordue par le domaine, la densité vit en lobes, des VRILLES s'étirent
// (des champs continus, jamais des points), la composition suit
// Beer-Lambert. DISCRÈTE : ambres translucides, jamais des bruns. Et
// dedans : les nuages de lait, et les CAUSTIQUES — deux champs ridés qui
// dérivent en sens contraires, leurs croisements s'allument et
// s'éteignent : des filaments de lumière qui scintillent, la lumière qui
// danse dans l'eau. Naissance et dissolution en fondu — aucune alpha
// n'atteint un bord de garde (le verre réfracte et agrandit toute coupe).
[[ stitchable ]] half4 inkTrail(float2 position, half4 color, float2 size,
                                device const float *sta, int staCount,
                                float2 bMin, float2 bMax, float t,
                                float dry, float birth, float scale,
                                float night) {
    position *= scale;
    int K = staCount / 4;
    if (K < 2 || dry >= 0.999 || birth < 0.004) { return half4(0.0); }
    // ===== L'ÉVAPORATION (nuit) : l'encre rend son souffle à la nuit.
    // Toute l'IMAGE du vol s'élève (la géométrie est interrogée plus bas
    // que le pixel : ce qui est tombé remonte sans la pastille).
    float ev = night > 0.5 ? dry : 0.0;
    float lift = ev * ev * 380.0;
    if (position.x < bMin.x - 240.0 || position.x > bMax.x + 240.0 ||
        position.y < bMin.y - 240.0 - lift ||
        position.y > bMax.y + 240.0) {
        return half4(0.0);
    }
    float2 posGeo = position + float2(0.0, lift);
    // La distance signée au tracé : le segment le plus proche, son u,
    // son âge, sa flânerie, son côté. 23 segments de maths simples —
    // les fbm, eux, n'existent que près du chemin.
    float bestD2 = 1e12;
    float u = 0.0, age = 0.0, linger = 0.0;
    float wSum = 0.0, uSum = 0.0, aSum = 0.0, lSum = 0.0;
    for (int k = 0; k < K - 1; k++) {
        float2 p0 = float2(sta[k * 4],       sta[k * 4 + 1]);
        float2 p1 = float2(sta[(k+1) * 4],   sta[(k+1) * 4 + 1]);
        float2 v = p1 - p0;
        float vv = max(dot(v, v), 1e-4);
        float hseg = clamp(dot(posGeo - p0, v) / vv, 0.0, 1.0);
        float2 dv = posGeo - (p0 + v * hseg);
        float d2 = dot(dv, dv);
        float uk = (float(k) + hseg) / float(K - 1);
        float ak = mix(sta[k * 4 + 2], sta[(k+1) * 4 + 2], hseg);
        float lk = mix(sta[k * 4 + 3], sta[(k+1) * 4 + 3], hseg);
        if (d2 < bestD2) {
            bestD2 = d2;
            u = uk; age = ak; linger = lk;
        }
        // Voronoï DOUX : les attributs se mélangent entre segments
        // proches — aucun pli ne peut plus tracer d'arête.
        float wk = exp(-d2 / (70.0 * 70.0));
        wSum += wk; uSum += wk * uk; aSum += wk * ak; lSum += wk * lk;
    }
    if (wSum > 1e-5) {
        u = uSum / wSum; age = aSum / wSum; linger = lSum / wSum;
    }
    // Distance NON signée : continue partout (le signe sautait sur la
    // frontière de Voronoï des plis concaves → arêtes droites). Les deux
    // bords billowent quand même : les champs sont spatiaux, pas miroirs.
    float sd = sqrt(bestD2);
    if (sd > 230.0) { return half4(0.0); }
    float live = exp(-age * 0.5);
    // LE DOMAINE TORDU : la silhouette billowe — c'est elle qui vit.
    // Deux octaves partout : la tache est floue, la troisième octave est
    // sous son propre flou — le simulateur, lui, la paie plein pot.
    float2 posA = posGeo;
    float2 p = posA * 0.006;
    float warpA = lfbm2(p + float2(0.0, -t * 0.055)) * 1.16;
    float warpB = lfbm2(p * 2.3 + float2(5.2, t * 0.085)) * 1.16;
    // En s'évaporant, la silhouette se DÉCHIRE : les warps s'exagèrent.
    float d1 = sd - ((warpA - 0.5) * 110.0 + (warpB - 0.5) * 34.0)
                    * (1.0 + 0.8 * ev);
    // La pointe naît en fondu ; la base s'élargit et se noie (au-delà du
    // départ, la distance devient radiale d'elle-même : le fondu est
    // géométrique, aucun bord).
    // Dans la NUIT, la nappe naît en VOILE : la densité pleine n'arrive
    // que plus haut derrière la pastille — jamais de soupe au contact.
    float tipIn = smoothstep(0.0, mix(0.06, 0.22, night), u);
    float spread = 34.0 * smoothstep(0.85, 1.0, u);
    // LES LOBES : le cœur + deux nappes fantômes, chacun sa largeur.
    float wMain = (26.0 + 15.0 * (1.0 - u) + 17.0 * min(age * 0.5, 1.0))
                  * (0.80 + 0.55 * linger) * (1.0 - 0.18 * night) + spread;
    // L'ÉTALEMENT : les volutes gonflent, la densité se conserve — elle
    // pâlit PARCE QU'elle s'étale, jamais parce qu'on la baisse.
    float wGrow = 1.0 + 2.6 * ev;
    wMain *= wGrow;
    float rarefy = 1.0 / wGrow;
    float off1 = (30.0 + 34.0 * (warpB - 0.35)) * (1.0 + 0.5 * ev);
    float off2 = (-36.0 - 30.0 * (warpA - 0.35)) * (1.0 + 0.5 * ev);
    float dens = exp(-(d1 * d1) / (wMain * wMain))
                 * (0.54 + 0.46 * warpA) * (0.85 + 0.45 * linger);
    float wHeart = wMain * 0.42;
    dens += exp(-(d1 * d1) / (wHeart * wHeart))
            * (0.45 + 0.55 * warpB) * (0.55 + 0.65 * linger)
            * (1.0 - 0.5 * ev);
    float w1 = wMain * 0.55;
    float dl1 = d1 - off1;
    dens += exp(-(dl1 * dl1) / (w1 * w1)) * 0.34 * (0.35 + 0.85 * warpB);
    float w2 = wMain * 0.44;
    float dl2 = d1 - off2;
    dens += exp(-(dl2 * dl2) / (w2 * w2)) * 0.27 * (0.35 + 0.85 * warpA);
    // Le grain du pigment mouillé — seulement dans l'encre visible.
    if (dens > 0.05) {
        float fine = lfbm2(posA * 0.030
                           + float2(warpB * 2.1, t * 0.05));
        dens *= 0.72 + 0.55 * fine;
    }
    // LES VRILLES : l'encre fraîche en jette, la vieille se pose.
    float vrilEnv = exp(-(d1 * d1) / (wMain * wMain * 4.0));
    if (vrilEnv > 0.015) {
        float tf = lfbm2(float2(posA.y * 0.013 + warpA * 1.7,
                                posA.x * 0.011 - t * 0.07
                                + warpB * 1.3)) * 1.16;
        dens += pow(smoothstep(0.52, 0.88, tf), 2.0) * vrilEnv
                * (0.35 + 0.65 * live) * 0.55 * (1.0 - ev);
    }
    dens *= mix(1.0, rarefy, night);
    dens *= tipIn * birth;
    // La fleur d'eau sous la bille — au point exact du doigt.
    float2 tip = float2(sta[0], sta[1]);
    float2 dtp = position - tip;
    float bloom = exp(-dot(dtp, dtp) / (78.0 * 78.0))
                  * (0.40 + 0.60 * live) * birth
                  * (1.0 - smoothstep(0.10, 0.45, ev));
    if (dens < 0.004 && bloom < 0.004) { return half4(0.0); }
    // DISCRÈTE : des ambres translucides, jamais des bruns — la sienne et
    // l'ombre ne sont plus que des soupçons, la fumée se lit dans la FORME.
    // Sur le papier, le jaune porte et la sienne ombre ; dans la NUIT,
    // c'est le BLANC qui porte la lumière (orange et jaune la réchauffent),
    // et l'ombre n'existe pas — la nuit est déjà l'ombre.
    float3 yellow = float3(1.00, 0.88, 0.45);
    float3 orange = mix(float3(1.00, 0.55, 0.20),
                        float3(1.00, 0.64, 0.32), night);
    float3 sienna = float3(0.62, 0.28, 0.10);
    float3 bloomC = mix(float3(1.00, 0.72, 0.32),
                        float3(1.00, 0.90, 0.70), night);
    float3 lowC = mix(yellow, float3(0.99, 0.975, 0.945), night);
    float3 c = mix(lowC, orange, smoothstep(0.10, 0.55, dens));
    c = mix(c, sienna, 0.18 * smoothstep(0.65, 1.70, dens)
                        * (1.0 - night));
    c = mix(c, yellow, (0.22 + 0.16 * night)
                        * smoothstep(0.62, 0.92, warpB)
                        * (1.0 - smoothstep(0.9, 1.6, dens)));
    c = mix(c, sienna, 0.10 * smoothstep(0.70, 0.95, warpA)
                        * smoothstep(0.35, 0.9, dens) * (1.0 - night));
    // LES NUAGES DE BLANC : des poches de lait qui dérivent dans l'encre.
    float cmask = 0.0;
    if (dens > 0.12) {
        float cloud = lfbm2(posA * 0.008
                            + float2(t * 0.050, -t * 0.075)
                            + warpA * 0.9);
        cmask = smoothstep(0.52, 0.82, cloud)
                * smoothstep(0.15, 0.50, dens);
        c = mix(c, float3(1.00, 0.985, 0.955), 0.75 * cmask);
    }
    // LES CAUSTIQUES : deux champs ridés à contre-courant — leurs
    // croisements sont des filaments de lumière qui naissent, glissent et
    // s'éteignent. Du scintillement CONNEXE : jamais des paillettes.
    float glintM = 0.0;
    if (dens > 0.10) {
        float n1 = lnoise(posA * 0.021
                          + float2(t * 0.11, -t * 0.07) + warpA * 0.6);
        float n2 = lnoise(posA * 0.017
                          + float2(-t * 0.09, t * 0.06));
        float r1 = pow(1.0 - fabs(2.0 * n1 - 1.0), 6.0);
        float r2 = pow(1.0 - fabs(2.0 * n2 - 1.0), 6.0);
        // La lumière ne danse que dans l'EAU : les caustiques meurent
        // avec le séchage, et restent un murmure — pas du strass.
        glintM = r1 * r2 * smoothstep(0.12, 0.40, dens)
                 * (1.0 - smoothstep(1.2, 1.9, dens))
                 * (0.30 + 0.70 * live);
        c = mix(c, float3(1.00, 0.96, 0.88), min(1.7 * glintM, 0.85));
    }
    // Sur le papier, DISCRÈTE (−40 %) : une présence qui se devine. Sur
    // la NUIT, l'inverse : l'alpha est la seule lumière — l'encre doit
    // RAYONNER, blanche et chaude, seule source vivante de la descente.
    // LA DÉCHIRURE EN ÉCHARPES : un seuil SPATIAL monte dans un bruit
    // large — les volutes fines meurent d'abord, les cœurs en dernier,
    // chacune à son heure. Jamais un front, jamais un fondu global.
    float wispK = 1.0;
    if (ev > 0.001) {
        float wispN = lfbm2(posGeo * 0.0045
                            + float2(t * 0.03, -t * 0.05)) * 1.16;
        float th = -0.15 + 1.05 * ev;
        wispK = smoothstep(th, th + 0.25,
                           wispN + 0.28 * min(dens, 1.2));
        wispK *= 1.0 - smoothstep(0.93, 1.0, ev);
        // Et en s'évaporant, l'encre REFROIDIT : la braise glisse vers
        // le blanc de lune — elle ne meurt pas, elle devient la nuit.
        c = mix(c, float3(0.94, 0.95, 0.97),
                0.75 * smoothstep(0.15, 0.85, ev));
    }
    float fold = night > 0.5 ? wispK : 1.0 - dry;
    float aInk = (1.0 - exp(-dens * mix(0.72, 0.95, night)))
                 * (0.28 + 0.30 * live) * (1.0 + 0.30 * night)
                 * (1.0 + 0.18 * cmask + 0.55 * glintM);
    float aBloom = bloom * mix(0.13, 0.02, night);
    float total = aInk + aBloom;
    if (total < 0.0008) { return half4(0.0); }
    float3 cTot = (c * aInk + bloomC * aBloom) / total;
    float a = min(total * fold, mix(0.40, 0.46, night));
    return half4(half3(cTot * a), half(a)) * color.a;
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
                                  float vision, float spill, float sceneIg,
                                  float nightFill, float ripple,
                                  float ripplePhase) {
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
    // L'ONDE DE LA GOUTTE : après l'atterrissage, une vague circulaire
    // traverse la surface — l'eau qui tremble, brève, amortie.
    if (ripple > 0.002) {
        f *= 1.0 + ripple * 0.05 * sin(nr * 24.0 - ripplePhase)
                 * (0.35 + 0.65 * bell);
    }
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

    // ---- LA NUIT DANS LE VERRE : pendant le zoom du sommet, l'intérieur
    // se remplit d'une nuit lunaire — on n'entre pas dans un décor, on
    // entre dans l'OBJET. Le velours vfbm (le drap du cadran), et une
    // clarté de lune à peine posée par le haut du verre.
    if (nightFill > 0.001) {
        float cloth = 0.80 + 0.40 * vfbm(d * 0.02 + float2(7.0, 3.0));
        float3 nightC = float3(0.012, 0.013, 0.020) * cloth;
        nightC += float3(0.050, 0.056, 0.072)
                  * pow(clamp(-n.y, 0.0, 1.0), 2.0);
        float depth = 0.55 + 0.45 * bell;
        float inside = 1.0 - smoothstep(R - 1.0, R + 0.5, r);
        rgb = mix(rgb, nightC, nightFill * depth * inside);
    }

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
