#include <metal_stdlib>
using namespace metal;

// Utilitaires bruit — internes au fichier, préfixés pour ne pas entrer en
// collision avec les autres shaders de l'app.
static float gfxHash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}
static float gfxVnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = gfxHash(i), b = gfxHash(i + float2(1, 0));
    float c = gfxHash(i + float2(0, 1)), d = gfxHash(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/// L'environnement : des volutes de fumée cosmique à 2-6 %, qui dérivent très
/// lentement. Sans environnement à refléter, aucun verre n'est crédible.
[[ stitchable ]] half4 glassSmoke(float2 position, half4 color, float t) {
    float2 p = position * 0.004 + float2(t * 0.020, -t * 0.012);
    float n = gfxVnoise(p) * 0.65 + gfxVnoise(p * 2.13 + 17.0) * 0.35;
    // Déformation de domaine : des volutes, pas des patates.
    float w = gfxVnoise(p * 1.7 + n * 1.8);
    float v = 0.008 + 0.040 * pow(max(0.0, n * 0.6 + w * 0.55 - 0.35), 1.6);
    return half4(half3(v), color.a);
}

/// LE VOILE : la grande lumière derrière la bouteille — deux gaussiennes
/// (cœur + jupe), une respiration de bruit, un dither anti-banding. C'est la
/// SEULE nappe additive large autorisée : c'est elle qui rend le verre
/// cristallin, chaque arête se découpe contre elle.
[[ stitchable ]] half4 lightVeil(float2 position, half4 color, float2 size,
                                 float t, float strength) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    // Le centre DÉRIVE — un halo vivant, jamais figé. La clé penche à
    // gauche : un plateau studio a un côté dominant, jamais un axe parfait.
    float2 c = float2(0.488 + 0.018 * sin(t * 0.21) + 0.010 * sin(t * 0.53 + 1.7),
                      0.38 + 0.014 * sin(t * 0.17 + 0.9));
    float2 d = (uv - c) * float2(1.0, 1.25);
    float r = length(d) / 0.73;
    // CONCENTRÉ : le cœur brille, la jupe est courte — les coins du cadre
    // restent noirs. La lumière est un événement, pas un papier gris.
    float v = 0.46 * exp(-r * r / (2.0 * 0.24 * 0.24))
            + 0.10 * exp(-r * r / (2.0 * 0.50 * 0.50));
    // Structure qui dérive + respiration lente du halo entier.
    float n = gfxVnoise(uv * 3.0 + t * 0.013) * 0.65
            + gfxVnoise(uv * 6.3 + 11.0 - t * 0.010) * 0.35;
    v *= 0.90 + 0.16 * n;
    v *= 0.92 + 0.08 * sin(t * 0.31);
    // Extinction PUREMENT RADIALE — jamais un cadre, jamais une couture.
    float2 e = (uv - c) * float2(1.35, 1.05);
    v *= 1.0 - smoothstep(0.22, 0.44, length(e));
    v += (gfxHash(position) - 0.5) * 0.02;
    v = clamp(v, 0.0, 0.60) * strength;
    return half4(half3(v), color.a);
}

/// Les volutes du cosmos : deux colonnes de fumée qui montent le long des
/// flancs de la bouteille. fBM déformé par lui-même, seuil doux — des masses
/// nuageuses qui respirent, jamais de la soie procédurale.
[[ stitchable ]] half4 cosmosWisps(float2 position, half4 color, float t, float2 size) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    // Deux bandes latérales, éteintes au centre (la bouteille) et aux bords.
    float sideDist = abs(uv.x - 0.5);
    float band = smoothstep(0.10, 0.24, sideDist) * (1.0 - smoothstep(0.32, 0.48, sideDist));
    float vert = smoothstep(0.06, 0.30, uv.y) * (1.0 - smoothstep(0.72, 0.96, uv.y));

    // fBM 4 octaves, étiré verticalement, qui monte lentement.
    float2 p = float2(uv.x * 3.2, uv.y * 5.5 - t * 0.045);
    float2 warp = float2(gfxVnoise(p * 1.3 + 31.0), gfxVnoise(p * 1.1 + 7.0));
    float2 q = p + 1.7 * warp;
    float n = 0.0; float amp = 0.5;
    for (int i = 0; i < 4; i++) {
        n += amp * gfxVnoise(q);
        q = q * 2.07 + 13.1;
        amp *= 0.5;
    }
    float v = 0.16 * pow(max(0.0, n - 0.36), 1.7) * band * vert;
    return half4(half3(v), color.a);
}


/// LA POCHE D'OMBRE : le verre absorbe le contre-jour en incidence rasante —
/// l'intérieur de la bouteille reste plus sombre que le voile derrière elle
/// (réf. carafe : c'est cette poche qui fait claquer la dentelle de l'orbe).
/// Rendu en MULTIPLY : la valeur est une transmission, 1 = lumière intacte.
/// Jamais un aplat : demi-largeur locale, épaules absorbantes, base noyée
/// de lumière, matière qui dérive, respiration propre.
[[ stitchable ]] half4 glassPocket(float2 position, half4 color, float2 size,
                                   float t, float strength) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    // Demi-largeur locale du corps : col étroit, épaules qui s'évasent.
    float hw = mix(0.085, 0.360, smoothstep(0.235, 0.475, uv.y));
    // La frontière paroi→centre ondule (bruit BF) : jamais une verticale.
    float edgeJitter = 0.030 * (gfxVnoise(float2(uv.y * 2.6, t * 0.05)) - 0.5);
    float wallDist = hw - abs(uv.x - 0.5) + edgeJitter;
    // L'incidence rasante : falloff LARGE — un dégradé de verre, pas une bande.
    float graze = 1.0 - smoothstep(0.015, 0.24, wallDist);
    // Le socle : même au centre, la double paroi retient de la lumière.
    float d = 0.35 + 0.40 * graze;
    // Les épaules absorbent plus — la courbure s'y traverse par la tranche.
    d += 0.10 * smoothstep(0.50, 0.315, uv.y) * smoothstep(0.19, 0.30, uv.y);
    // Le haut du col, vu par la tranche, absorbe plus que tout.
    d += 0.12 * smoothstep(0.30, 0.21, uv.y);
    // L'asymétrie du plateau : la clé est à gauche, la droite s'enfonce —
    // et l'écart dérive lentement, jamais figé, jamais en phase.
    d += (0.035 + 0.030 * gfxVnoise(float2(t * 0.045, uv.y * 1.7))) * (uv.x - 0.5) * 2.0;
    // La base se noie dans la flaque de lumière : la poche s'y dissout.
    d *= 1.0 - smoothstep(0.800, 0.935, uv.y);
    // Et s'ouvre au col, au-dessus de l'épaule du verre.
    d *= smoothstep(0.155, 0.205, uv.y);
    // La matière dérive, la respiration reste discrète (le pompage est un
    // défaut : ±3 %, période longue).
    float n = gfxVnoise(uv * float2(5.0, 7.5) + float2(t * 0.017, -t * 0.011)) * 0.65
            + gfxVnoise(uv * float2(9.7, 13.0) + 5.0 + float2(-t * 0.009, t * 0.013)) * 0.35;
    d *= 0.90 + 0.16 * n;
    d *= 0.97 + 0.03 * sin(t * 0.11 + 2.1);
    d = clamp(d * strength, 0.0, 0.80);
    // Le grain de matière se pose APRÈS la transmission : un plancher de
    // bruit que rien n'écrase — c'est lui qui interdit l'aplat CGI.
    float g = gfxVnoise(uv * float2(38.0, 55.0) + float2(t * 0.021, -t * 0.014)) - 0.5;
    float T = clamp(1.0 - d + g * 0.045, 0.03, 1.0);
    return half4(half3(T), color.a);
}

/// Le verrou tonal : écrase les gris moyens (l'« opaque »), préserve les
/// noirs et les blancs. Le filet de sécurité anti-lavis.
[[ stitchable ]] half4 glassGamma(float2 position, half4 color, float g) {
    return half4(pow(max(color.rgb, half3(0.0h)), half3(g)), color.a);
}
