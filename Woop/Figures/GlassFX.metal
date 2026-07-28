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
    float v = 0.016 + 0.050 * pow(max(0.0, n * 0.6 + w * 0.55 - 0.35), 1.6);
    return half4(half3(v), color.a);
}

/// L'ondulation du miroir de sol : un frisson de laque noire, pas une vague.
[[ stitchable ]] float2 floorRipple(float2 position, float t) {
    float dx = sin(position.y * 0.224 + t * 0.9)
             + 0.6 * sin(position.y * 0.111 - t * 0.6);
    float dy = 0.5 * sin(position.x * 0.15 + t * 0.7);
    return float2(position.x + dx, position.y + dy);
}

/// Le verrou tonal : écrase les gris moyens (l'« opaque »), préserve les
/// noirs et les blancs. Le filet de sécurité anti-lavis.
[[ stitchable ]] half4 glassGamma(float2 position, half4 color, float g) {
    return half4(pow(max(color.rgb, half3(0.0h)), half3(g)), color.a);
}
