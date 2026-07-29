#include <metal_stdlib>
using namespace metal;

// MARK: - Bouton CONNEXION « diamant »
//
// Une seule passe pour tout l'écrin : la fumée noire fractale qui dérive à
// l'intérieur, le liseré hairline à luminosité inégale qui respire, les halos
// qui débordent aux endroits vifs, et les poussières-particules qui émanent
// du bord. Même grammaire que les autres shaders du projet (hash → bruit de
// valeur → fbm, dither final), mais un théâtre minuscule : tout est monochrome
// blanc, tout est retenu.
//
// La vue passe un rectangle PLUS GRAND que le bouton (marge `pad` de chaque
// côté) : halos et particules vivent dehors, en alpha, sans jamais peindre
// un cadre noir par-dessus la page.

static float bhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 bhash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float bnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = bhash21(i);
    float b = bhash21(i + float2(1.0, 0.0));
    float c = bhash21(i + float2(0.0, 1.0));
    float d = bhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float bfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * bnoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

/// Distance signée au rectangle arrondi (négatif dedans).
static float sdRound(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// La luminosité du liseré à un endroit du bord : des accents organiques qui
/// glissent lentement (respiration), plus généreux en haut et sur les flancs.
static float rimLight(float2 p, float2 halfB, float t) {
    float ang = atan2(p.y, p.x);
    float arc = ang * 0.159154943 + 0.5;          // 0..1 autour du centre
    // Deux échelles d'accents qui rampent en sens contraires : jamais figé,
    // jamais périodique à l'œil. Paramétré par la POSITION sur le bord (pas
    // l'angle) : sur les longs bords horizontaux, l'angle est quasi constant
    // et figeait le bruit — la position, elle, varie franchement.
    float seg = bfbm(p * float2(0.014, 0.05) + float2(t * 0.13, -t * 0.09));
    float fine = bnoise(p * float2(0.032, 0.11) + float2(-t * 0.26, t * 0.19));
    float accents = seg * 0.72 + fine * 0.28;
    accents = accents * accents * accents;         // creuse les vallées
    // Biais d'arête : le haut vit, les flancs aussi, le bas murmure.
    float topness  = clamp(-p.y / max(halfB.y, 1.0), 0.0, 1.0);
    float sideness = clamp(fabs(p.x) / max(halfB.x, 1.0) - 0.72, 0.0, 0.28) / 0.28;
    float bias = 0.22 + 0.62 * topness * topness + 0.45 * sideness;
    // Respiration d'ensemble : assez vive pour être VUE, jamais stroboscopique.
    float breath = 0.82 + 0.18 * sin(t * 1.1 + arc * 12.566);
    return clamp((0.06 + 4.0 * accents) * bias * breath, 0.0, 1.0);
}

[[ stitchable ]] half4 diamondButton(float2 position, half4 color,
                                     float2 size, float t,
                                     float pad, float radius) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float r = min(radius, halfB.y);
    float d = sdRound(p, halfB, r);

    float rim = rimLight(p, halfB, t);

    // ---- Le liseré : hairline ~1 pt, jamais un cadre.
    float line = exp(-d * d / (0.42 * 0.42)) * (0.08 + 0.92 * rim);

    // ---- Les halos : une buée qui déborde aux endroits vifs, et un soupçon
    // de lueur interne pour que le bord ne soit pas un trait posé sur du vide.
    float outside = max(d, 0.0);
    // Fondu court : la buée reste collée au liseré, la fumée ne
    // s'échappe presque pas du bouton.
    float halo = exp(-outside / 15.0) * smoothstep(-0.8, 0.8, d) * 0.50 * rim;
    float sheen = exp(-max(-d, 0.0) / 5.0) * smoothstep(0.8, -0.8, d) * 0.05 * rim;

    // ---- La fumée : volutes fractales, domaine déformé, dérive lente.
    float inside = smoothstep(0.6, -1.2, d);
    float smoke = 0.0;
    if (inside > 0.0) {
        float2 sc = p * float2(0.030, 0.052);      // volutes larges, couchées
        float2 drift = float2(t * 0.030, -t * 0.016);
        // Domaine deux fois déformé : les volutes se tordent sur elles-mêmes
        // au lieu de glisser en nappe — c'est là que vit le démon.
        float q = bfbm(sc + drift);
        float w2 = bfbm(sc * 1.7 - drift * 0.8 + 2.3 * q);
        float s = bfbm(sc * 1.31 + float2(2.2 * q, -1.6 * w2) - drift * 0.6);
        s = pow(clamp(s, 0.0, 1.0), 2.2);
        // Le socle : obsidienne à peine dégradée (haut un poil plus clair).
        // Sombre : l'intérieur lit NOIR traversé de fumée, jamais gris.
        float uvY = clamp((p.y + halfB.y) / (2.0 * halfB.y), 0.0, 1.0);
        float base = mix(0.038, 0.012, uvY);
        // La fumée attrape la lumière du bord : plus dense près des accents.
        float nearRim = exp(-fabs(d) / 16.0);
        smoke = base + s * (0.075 + 0.42 * nearRim * rim) + 0.026 * nearRim * rim;
        smoke *= inside;
    }

    // ---- Les particules : des poussières qui émanent du bord, s'éloignent
    // et s'éteignent. Grille hashée dans une bande autour du liseré ; chaque
    // cellule porte au plus une étincelle, pondérée par la lumière locale.
    float spark = 0.0;
    if (d > -6.0 && d < 26.0) {
        for (int k = 0; k < 2; k++) {
            float cell = (k == 0) ? 11.0 : 17.0;
            float2 id = floor(p / cell);
            float4 h = bhash42(id * 1.93 + float2(4.7 * float(k) + 1.0, 8.1));
            if (h.x < 0.34) {
                float2 c0 = (id + 0.5 + (h.yz - 0.5) * 0.7) * cell;
                // Normale sortante approchée au point d'origine.
                float e = 0.75;
                float2 n = normalize(float2(
                    sdRound(c0 + float2(e, 0.0), halfB, r) - sdRound(c0 - float2(e, 0.0), halfB, r),
                    sdRound(c0 + float2(0.0, e), halfB, r) - sdRound(c0 - float2(0.0, e), halfB, r)) + 1e-4);
                float life = fract(t * (0.09 + 0.13 * h.w) + h.y * 7.0);
                float2 pos = c0 + n * (1.5 + life * 11.0);
                float d0 = sdRound(c0, halfB, r);
                // Ne naissent que sur le liseré, brillent où lui brille.
                float born = smoothstep(4.0, 0.5, fabs(d0));
                float local = rimLight(c0, halfB, t);
                float tw = 0.55 + 0.45 * sin(t * (1.7 + 2.6 * h.z) + h.w * 6.28);
                float2 dp = p - pos;
                float g = exp(-dot(dp, dp) / (0.8 * 0.8));
                spark += g * sin(3.14159 * life) * born * tw
                         * (0.5 + 0.5 * local) * 1.4;
            }
        }
    }

    // ---- Le scintillement bijou : des éclats-ÉTOILES (une bague qu'on
    // tourne sous la lumière) — un cœur vif et deux rayons fins en croix qui
    // fleurissent au pic du flash puis se referment. Ils ne vivent que là où
    // la lumière vit : sur le liseré et dans sa frange intérieure éclairée.
    // Rares (2-4 visibles), brefs, jamais stroboscopiques.
    float glitter = 0.0;
    if (d > -16.0 && d < 4.0) {
        for (int k = 0; k < 2; k++) {
            float cell = (k == 0) ? 9.0 : 14.0;
            float2 idg = floor(p / cell);
            // L'étoile d'une cellule peut rayonner jusque dans la voisine :
            // on échantillonne la cellule et ses 8 voisines.
            for (int oy = -1; oy <= 1; oy++)
            for (int ox = -1; ox <= 1; ox++) {
                float2 idn = idg + float2(ox, oy);
                float4 hg = bhash42(idn * 2.71 + float2(13.7 + 3.1 * float(k), 5.3));
                if (hg.x >= 0.22) continue;
                float2 cg = (idn + 0.5 + (hg.yz - 0.5) * 0.6) * cell;
                float dg = sdRound(cg, halfB, r);
                // Accroché à la lumière : max sur le liseré, fond en s'enfonçant.
                float on = exp(-fabs(dg) / 6.0);
                float local = rimLight(cg, halfB, t);
                // Flash rare et bref : l'étoile dort presque tout le temps.
                float twk = max(0.0, sin(t * (0.35 + 0.55 * hg.w) + hg.z * 6.283));
                twk = pow(twk, 16.0);
                float amp = twk * on * (0.25 + 0.75 * local);
                if (amp < 0.004) continue;
                float2 dpg = p - cg;
                float rayLen = 2.5 + 10.0 * twk;   // la croix fleurit au pic
                float core = exp(-dot(dpg, dpg) / (0.75 * 0.75));
                float rayH = exp(-dpg.y * dpg.y / (0.42 * 0.42)
                                 - dpg.x * dpg.x / (rayLen * rayLen));
                float rayV = exp(-dpg.x * dpg.x / (0.42 * 0.42)
                                 - dpg.y * dpg.y / (rayLen * rayLen));
                glitter += (core + (rayH + rayV) * 0.55) * amp;
            }
        }
    }

    float lum = smoke + sheen + line + halo + spark + glitter;
    // Dither léger : tue le banding des halos et de la fumée.
    lum += (bhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5) * (2.0 / 255.0);
    lum = clamp(lum, 0.0, 1.0);

    // Dedans : opaque (l'obsidienne). Dehors : seule la lumière existe.
    // La ligne elle-même porte son alpha — sinon la rampe d'opacité du bord
    // mange la hairline exactement là où elle vit (d ≈ 0).
    float a = mix(clamp((line + halo + spark + glitter) * 1.6, 0.0, 1.0), 1.0, inside);
    return half4(half3(lum * a), half(a));      // prémultiplié
}
