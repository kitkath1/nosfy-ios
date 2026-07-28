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
    float v = 0.006 + 0.028 * pow(max(0.0, n * 0.6 + w * 0.55 - 0.35), 1.6);
    return half4(half3(v), color.a);
}

/// LE VOILE : la grande lumière derrière la bouteille — deux gaussiennes
/// (cœur + jupe), une respiration de bruit, un dither anti-banding. C'est la
/// SEULE nappe additive large autorisée : c'est elle qui rend le verre
/// cristallin, chaque arête se découpe contre elle.
[[ stitchable ]] half4 lightVeil(float2 position, half4 color, float2 size,
                                 float t, float strength) {
    float2 uv = position / max(size, float2(1.0, 1.0));
    // Le centre DÉRIVE — un halo vivant, jamais figé.
    float2 c = float2(0.5 + 0.018 * sin(t * 0.21) + 0.010 * sin(t * 0.53 + 1.7),
                      0.38 + 0.014 * sin(t * 0.17 + 0.9));
    float2 d = (uv - c) * float2(1.0, 1.25);
    float r = length(d) / 0.73;
    float v = 0.46 * exp(-r * r / (2.0 * 0.26 * 0.26))
            + 0.13 * exp(-r * r / (2.0 * 0.62 * 0.62));
    // Structure qui dérive + respiration lente du halo entier.
    float n = gfxVnoise(uv * 3.0 + t * 0.013) * 0.65
            + gfxVnoise(uv * 6.3 + 11.0 - t * 0.010) * 0.35;
    v *= 0.90 + 0.16 * n;
    v *= 0.92 + 0.08 * sin(t * 0.31);
    // Extinction PUREMENT RADIALE — jamais un cadre, jamais une couture.
    float2 e = (uv - c) * float2(1.35, 1.05);
    v *= 1.0 - smoothstep(0.30, 0.56, length(e));
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


/// Le verrou tonal : écrase les gris moyens (l'« opaque »), préserve les
/// noirs et les blancs. Le filet de sécurité anti-lavis.
[[ stitchable ]] half4 glassGamma(float2 position, half4 color, float g) {
    return half4(pow(max(color.rgb, half3(0.0h)), half3(g)), color.a);
}
