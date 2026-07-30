#include <metal_stdlib>
using namespace metal;

// MARK: - Carte Objectif « bijou » — métal noir, griffes, nébuleuse, liseré
//
// Une seule passe pour toute la carte, dans la grammaire des composants
// diamant (DiamondButton.metal) mais à l'échelle d'une SURFACE, pas d'un
// bouton : un métal noir presque absolu, griffé de brossage anisotrope que
// seule une lumière rasante révèle (surtout sur le flanc droit), une
// nébuleuse d'arrière-plan à peine perceptible avec ses poussières
// d'étoiles, et tout autour un liseré hairline de ~0,5 pt à la lumière
// INÉGALE qui rampe lentement — un bijou serti, avec ses éclats de taille.
//
// La vue passe un rectangle PLUS GRAND que la carte (marge `pad`) : les
// halos et les éclats vivent dehors, en alpha, sans jamais peindre un cadre
// noir par-dessus la page.

static float jhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 jhash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float jnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = jhash21(i);
    float b = jhash21(i + float2(1.0, 0.0));
    float c = jhash21(i + float2(0.0, 1.0));
    float d = jhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float jfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * jnoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

/// Distance signée au rectangle arrondi (négatif dedans).
static float jsdRound(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Abscisse CURVILIGNE le long du périmètre, 0..1 (départ coin haut-gauche,
/// sens horaire). C'est la bonne paramétrisation d'un liseré : l'angle
/// depuis le centre fige le bruit sur les longs bords horizontaux (piège
/// déjà payé sur le bouton), tandis que l'abscisse avance à vitesse
/// constante — les accents ont la même taille partout et peuvent RAMPER.
static float jArc(float2 p, float2 b, float r) {
    float wx = max(b.x - r, 0.0);          // demi-longueur droite, horizontale
    float wy = max(b.y - r, 0.0);          // demi-longueur droite, verticale
    float qc = 1.5707963 * r;              // quart d'arc
    float P = 4.0 * (wx + wy) + 4.0 * qc;
    float2 c = float2(clamp(p.x, -wx, wx), clamp(p.y, -wy, wy));
    float2 dv = p - c;
    float ang = atan2(dv.y, dv.x);
    bool cx = fabs(p.x) > wx;
    bool cy = fabs(p.y) > wy;
    float s;
    if (!cx && p.y < 0.0) {                        // bord haut
        s = p.x + wx;
    } else if (cx && cy && p.x > 0.0 && p.y < 0.0) { // coin haut-droit
        s = 2.0 * wx + (ang + 1.5707963) * r;
    } else if (!cy && p.x > 0.0) {                 // bord droit
        s = 2.0 * wx + qc + (p.y + wy);
    } else if (cx && cy && p.x > 0.0) {            // coin bas-droit
        s = 2.0 * wx + qc + 2.0 * wy + ang * r;
    } else if (!cx) {                              // bord bas
        s = 2.0 * wx + 2.0 * qc + 2.0 * wy + (wx - p.x);
    } else if (cx && cy && p.y > 0.0) {            // coin bas-gauche
        s = 4.0 * wx + 2.0 * qc + 2.0 * wy + (ang - 1.5707963) * r;
    } else if (!cy) {                              // bord gauche
        s = 4.0 * wx + 3.0 * qc + 2.0 * wy + (wy - p.y);
    } else {                                       // coin haut-gauche
        s = 4.0 * wx + 3.0 * qc + 4.0 * wy + (ang + 3.1415927) * r;
    }
    return fract(s / max(P, 1.0));
}

/// La lumière du liseré à l'abscisse `s` : des accents inégaux, organiques,
/// qui rampent très lentement le long du bord (respiration d'ensemble en
/// plus). Le bruit est échantillonné sur un CERCLE d'abscisse — continu au
/// raccord 1 → 0, jamais de couture visible dans le coin haut-gauche.
static float jRim(float s, float2 p, float2 halfB, float t) {
    float a = 6.2831853 * s;
    float2 ring = float2(cos(a), sin(a));
    float seg  = jfbm(ring * 2.6 + float2(t * 0.045, -t * 0.033));
    float fine = jnoise(ring * 8.5 + float2(-t * 0.085, t * 0.062));
    float acc = seg * 0.70 + fine * 0.30;
    // Exposant modéré : à 3,4 seuls les pics survivaient et tout le reste du
    // tour tombait à zéro — ce n'était plus une lumière inégale, c'était un
    // fil COUPÉ. Ici les creux vivent encore, les pics dominent toujours.
    acc = pow(clamp(acc, 0.0, 1.0), 2.2);
    // Biais d'arête : le haut porte la lumière, les flancs la tiennent, le
    // bas murmure — une pierre éclairée d'en haut, pas un néon fermé. Le
    // terme de flanc s'amortit près du haut : sans cet amortissement les
    // quatre coins deviennent les maxima structurels et le procédé se voit.
    float topness  = clamp(-p.y / max(halfB.y, 1.0), 0.0, 1.0);
    float sideness = clamp(fabs(p.x) / max(halfB.x, 1.0) - 0.80, 0.0, 0.20) / 0.20;
    float bias = 0.22 + 0.50 * topness * topness
               + 0.58 * sideness * (1.0 - 0.60 * topness);
    float breath = 0.83 + 0.17 * sin(t * 0.55 + a * 1.7);
    return clamp(2.3 * acc * bias * breath, 0.0, 1.0);
}

// `lit` : le doigt posé sur la carte (0 → 1, rampe côté SwiftUI). L'éveil se
// joue surtout DANS la pierre — une braise sous le bord haut, des griffes
// plus vives — et à peine sur le liseré : allumer le cadre seul faisait un
// interrupteur, et une carte n'est pas un bouton, elle ne doit pas exploser
// sous le doigt.
// `warm` : objectif atteint — SEULE la lumière du liseré se réchauffe vers
// l'or-récompense ; la pierre, elle, reste noire.
[[ stitchable ]] half4 objectiveJewel(float2 position, half4 color,
                                      float2 size, float t,
                                      float pad, float radius,
                                      float lit, float warm) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float r = min(radius, min(halfB.x, halfB.y));
    float d = jsdRound(p, halfB, r);
    float inside = smoothstep(0.6, -0.9, d);

    float ux = clamp((p.x + halfB.x) / (2.0 * halfB.x), 0.0, 1.0);
    float uy = clamp((p.y + halfB.y) / (2.0 * halfB.y), 0.0, 1.0);
    // Le flanc droit est celui qui porte la matière : c'est là que le métal
    // se griffe et que la nébuleuse respire. Le seuil haut s'arrête avant le
    // bord pour que le DERNIER quart atteigne la pleine matière au lieu de
    // redescendre juste là où on regarde.
    float rightness = smoothstep(0.20, 0.80, ux);
    // Le clair-obscur : la lumière tombe d'en haut. Tout ce qui éclaire la
    // pierre s'éteint vers le bas — sinon la nébuleuse rallume le tiers bas
    // et le dégradé s'inverse dans la moitié basse.
    float vfall = mix(1.0, 0.18, uy * uy * (3.0 - 2.0 * uy));

    float surf = 0.0;
    if (inside > 0.0) {
        // ---- La lumière rasante : un voile large qui traverse la carte en
        // ~34 s. Sa course est plus courte que la carte, pour qu'il y ait
        // TOUJOURS un morceau de lumière dans le cadre — un effet qu'on ne
        // voit qu'une seconde sur trente n'existe pas.
        float band = (p.x * 0.94 + p.y * 0.34) / max(halfB.x, 1.0);
        float cph = fract(t / 34.0) * 2.6 - 1.3;
        float graze = exp(-(band - cph) * (band - cph) / (0.85 * 0.85));

        // ---- La nébuleuse : des nappes fractales, un cordon diagonal avec
        // ses filaments. L'octave de base fait un cinquième de carte : plus
        // large, elle ne donne qu'un unique bombement qu'on ne lit pas.
        float2 nc = p * 0.026;
        float q = jfbm(nc + float2(t * 0.0055, -t * 0.0038));
        float neb = jfbm(nc * 1.55 + 1.9 * q);
        neb = pow(clamp(neb, 0.0, 1.0), 2.1) * 0.105
              * (0.35 + 0.90 * rightness) * vfall;

        // ---- L'épaisseur du verre : un souffle sous le bord haut, la trace
        // de lumière qui sépare une plaque noire d'une pierre taillée. Il
        // suit le flanc droit : posé sur toute la largeur, il devenait un
        // bandeau gris derrière « OBJECTIF HEBDOMADAIRE ».
        float topWash = exp(-uy * 4.5) * 0.019 * (0.45 + 0.75 * rightness);

        // ---- Le socle : obsidienne. Presque rien — il faut que le VIDE
        // existe dans la pierre, sinon la carte est un rectangle gris posé
        // sur la page noire, et c'est le plancher qui la détache, pas sa
        // lumière. Le doigt posé fait monter une braise DANS la pierre.
        float base = mix(0.024, 0.0035, uy) + 0.009 * lit * exp(-uy * 2.2);

        // Toute la lumière posée sur la pierre, avant que le métal la griffe.
        float wash = base + neb + topWash
                   + graze * 0.020 * (0.20 + 0.95 * rightness) * vfall;

        // ---- Les griffes : brossage anisotrope à -22°, long dans le sens de
        // la griffe, fin en travers. Le PAS est ce qui compte : à 3x le
        // Nyquist vaut 1,5 cycle/pt — au-dessus (on était à 8,5 et 21), la
        // griffe ne griffe plus, elle sable. Les trois échelles restent donc
        // sous 1,25 : des hairlines séparées par du noir franc.
        float ca = 0.9272, sa = -0.3746;
        float2 g = float2(p.x * ca - p.y * sa, p.x * sa + p.y * ca);
        float sc1 = jnoise(float2(g.x * 0.026, g.y * 0.34)) - 0.5;
        float sc2 = jnoise(float2(g.x * 0.060, g.y * 0.72)) - 0.5;
        float sc3 = jnoise(float2(g.x * 0.017, g.y * 1.22)) - 0.5;
        float brush = sc1 * 0.42 + sc2 * 0.36 + sc3 * 0.22;
        // Les griffes franches : les crêtes seules, très rares, plus vives.
        float sharp = pow(max(sc3 * 2.0, 0.0), 5.0) * 0.7
                    + pow(max(sc2 * 2.0, 0.0), 6.0) * 0.4;
        // Le brossage MODULE la lumière au lieu de s'y AJOUTER : une griffe
        // n'existe que là où la lumière tombe. C'est ce qui permet une
        // modulation quasi totale — sillons au noir, crêtes vives — sans
        // grisailler les zones sombres, là où un terme additif écrêterait.
        float gain = (0.9 + 3.2 * rightness)
                   * (0.55 + 0.85 * graze + 0.30 * lit);
        float scratch = max(0.0, 1.0 + (brush + sharp * 0.35) * gain);

        // ---- Les poussières d'étoiles : trois grilles de pas premiers entre
        // eux (le semis reste dense sans jamais faire motif), et des
        // magnitudes en loi de puissance — beaucoup de très faibles, deux ou
        // trois vives. C'est la hiérarchie qui fait lire « ciel » plutôt que
        // « bruit de capteur ».
        float stars = 0.0;
        for (int k = 0; k < 3; k++) {
            float cell = (k == 0) ? 16.0 : (k == 1) ? 25.0 : 39.0;
            float2 id = floor(p / cell);
            float4 h = jhash42(id * 1.71 + float2(3.3 + 5.1 * float(k), 7.7));
            if (h.x < 0.44) {
                float2 c0 = (id + 0.5 + (h.yz - 0.5) * 0.9) * cell;
                float tw = 0.40 + 0.60 * pow(max(0.0, sin(t * (0.22 + 0.45 * h.w)
                                                          + h.z * 6.283)), 3.0);
                float2 dp = p - c0;
                float sig = 0.32 + 0.32 * h.w;
                stars += exp(-dot(dp, dp) / (sig * sig))
                         * (0.022 + 0.40 * pow(h.z, 2.8)) * tw;
            }
        }
        stars *= (0.30 + 1.00 * rightness) * vfall;

        surf = (wash * scratch + stars) * inside;
    }

    // ---- Le liseré : hairline ~0,5 pt, lumière INÉGALE, jamais un cadre.
    float s = jArc(p, halfB, r);
    float rim = clamp(jRim(s, p, halfB, t) * (1.0 + 0.14 * lit), 0.0, 1.0);
    // Le plancher du fil : sans lui la lumière n'est plus inégale, elle est
    // INTERROMPUE — le bas et le flanc droit disparaissaient, et un fil coupé
    // ne sertit rien. Sigma 0,32 pt = 0,53 pt de large : le cheveu demandé.
    float line = exp(-d * d / (0.32 * 0.32)) * (0.10 + 0.90 * rim);
    // La buée : collée au trait, courte. Au-delà de ~2 pt ce n'est plus un
    // sertissage qui respire, c'est le brouillard diffus qu'elle refuse.
    float halo = exp(-max(d, 0.0) / (2.2 + 0.8 * lit))
                 * smoothstep(-0.8, 0.8, d) * (0.16 + 0.05 * lit) * rim;
    // Un souffle INTÉRIEUR serré : le bord n'est pas posé sur du vide, mais
    // il ne se dissout pas en bavure de 2 pt là où le liseré faiblit.
    float inner = exp(-max(-d, 0.0) / 3.0) * smoothstep(0.8, -0.8, d)
                  * 0.085 * (0.25 + 0.75 * rim);

    // ---- Les éclats de taille : un cœur vif et deux rayons fins en croix
    // qui fleurissent au pic du flash puis se referment. Rares (2-4 visibles
    // à la fois sur tout le périmètre), brefs — une pierre qu'on tourne sous
    // la lumière, jamais une guirlande.
    float glitter = 0.0;
    if (d > -12.0 && d < 5.0) {
        for (int k = 0; k < 2; k++) {
            float cell = (k == 0) ? 19.0 : 29.0;
            float2 idg = floor(p / cell);
            for (int oy = -1; oy <= 1; oy++)
            for (int ox = -1; ox <= 1; ox++) {
                float2 idn = idg + float2(ox, oy);
                float4 hg = jhash42(idn * 2.71 + float2(13.7 + 3.1 * float(k), 5.3));
                if (hg.x >= 0.13 + 0.03 * lit) continue;
                float2 cg = (idn + 0.5 + (hg.yz - 0.5) * 0.6) * cell;
                float dg = jsdRound(cg, halfB, r);
                float on = exp(-fabs(dg) / 4.5);
                if (on < 0.02) continue;
                float local = jRim(jArc(cg, halfB, r), cg, halfB, t);
                float twk = max(0.0, sin(t * (0.30 + 0.45 * hg.w) + hg.z * 6.283));
                twk = pow(twk, 12.0 - 3.0 * lit);
                float amp = twk * on * (0.35 + 0.65 * local);
                if (amp < 0.004) continue;
                float2 dpg = p - cg;
                float rayLen = 2.6 + 13.0 * twk;
                float core = exp(-dot(dpg, dpg) / (0.62 * 0.62));
                float rayH = exp(-dpg.y * dpg.y / (0.34 * 0.34)
                                 - dpg.x * dpg.x / (rayLen * rayLen));
                float rayV = exp(-dpg.x * dpg.x / (0.34 * 0.34)
                                 - dpg.y * dpg.y / (rayLen * rayLen));
                glitter += (core + (rayH + rayV) * 0.50) * amp;
            }
        }
    }

    // La pierre est neutre ; seule la lumière du sertissage peut se réchauffer.
    float light = line + halo + inner + glitter;
    float3 tint = mix(float3(1.0), float3(1.0, 0.945, 0.80), clamp(warm, 0.0, 1.0));
    float3 rgb = float3(surf) + light * tint;
    // Dither : sans lui, une nébuleuse à 2 % bande atrocement. Un demi-niveau
    // suffit — `dithersColor` en pose déjà autant côté SwiftUI, et le tapis
    // cumulé mangeait exactement la finesse des griffes.
    rgb += (jhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
           * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);

    // Dedans : opaque (la pierre). Dehors : seule la lumière existe.
    // L'alpha prend le MAXIMUM des deux au lieu de mélanger : composer la
    // ligne par son propre alpha l'élève au carré, et le murmure du bord bas
    // se retrouvait écrasé d'un facteur 3 pendant que les accents écrêtaient.
    // `rgb` porte déjà l'énergie prémultipliée (surf est multiplié par
    // `inside`) : on la borne à l'alpha au lieu de la remultiplier, sinon le
    // dither fuiterait en voile gris sur toute la marge hors carte.
    float a = clamp(max(inside, light * 1.6), 0.0, 1.0);
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}
