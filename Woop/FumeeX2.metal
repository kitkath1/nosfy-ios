// LA FUMÉE DU VARIANT « ×2 » (plan tools/rewards/PLAN-VARIANT-X2.md §3.1)
// — « dans le footer de la card, une alternance de fumée rouge, noire
// et blanche, animée ». Un colorEffect BORNÉ à la bande du footer
// (jamais plein écran — la loi du Canvas) : trois panaches montent du
// bord bas, chacun avec SA teinte (passée en uniforme — la partition
// des couleurs vit en Swift, le shader ne fait que la matière), fbm à
// quatre octaves avec déformation de domaine, deux vents à périodes
// premières, et un FRISSON au battement ×2 (`bat`). Sortie
// PRÉMULTIPLIÉE : le noir est une fumée qui ASSOMBRIT (rgb 0, alpha),
// le blanc et le rouge sont retenus par l'alpha de leur teinte.
//
// ⚠️ LA MONTÉE EN CHALEUR EST MORTE (verdict 27-08 : « l'effet flamme
// est tout much, laisse comme c'était avant ») — la fumée reste DIFFUSE
// (enveloppe large, rampe longue). Ne pas la ressusciter sans verdict.
//
// ⚠️ Arité : (position, color) + size, time, bat, teinteA/B/C — l'appel
// Swift doit passer EXACTEMENT ces six uniformes dans cet ordre (le
// piège du stitchable : page BLANCHE sans erreur).
#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

static float hashX2(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float noiseX2(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hashX2(i);
    float b = hashX2(i + float2(1.0, 0.0));
    float c = hashX2(i + float2(0.0, 1.0));
    float d = hashX2(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fbmX2(float2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * noiseX2(p);
        p = p * 2.03 + float2(17.1, 9.7);
        a *= 0.5;
    }
    return v;
}

[[ stitchable ]] half4 fumeeX2(float2 position, half4 color,
                                float2 size, float time, float bat,
                                half4 teinteA, half4 teinteB, half4 teinteC)
{
    float2 uv = position / size;          // y vers le bas
    float hauteur = 1.0 - uv.y;           // 0 au pied, 1 au sommet
    float centres[3] = { 0.22, 0.52, 0.80 };
    half4 teintes[3] = { teinteA, teinteB, teinteC };
    float3 rgb = float3(0.0);
    float alpha = 0.0;
    float turb = 1.0 + 0.22 * bat;
    for (int k = 0; k < 3; k++) {
        float fk = float(k);
        // le panache monte (vitesse propre) et penche au vent (périodes
        // premières, jamais deux panaches en phase)
        float2 p = float2((uv.x - centres[k]) * 2.6, uv.y * 2.0);
        p.y += time * (0.11 + 0.03 * fk);
        p.x += 0.35 * sin(time * (0.07 + 0.02 * fk) + fk * 2.1) * hauteur;
        // la déformation de domaine à UNE octave (cadence), le fbm à trois
        float n1 = noiseX2(p * 1.3 * turb + float2(fk * 13.7, 0.0));
        float n = fbmX2(p * 1.25 + n1 * 1.1 + float2(0.0, time * 0.02));
        // l'enveloppe : LARGE et douce (« plus diffuse ») ; née sous le
        // bord bas, morte au sommet de la bande
        float dx = uv.x - centres[k] - 0.06 * sin(time * 0.13 + fk);
        float larg = 0.15 + 0.30 * hauteur;
        float env = exp(-dx * dx / (larg * larg))
            * (1.0 - smoothstep(0.50, 1.0, hauteur))
            * smoothstep(-0.05, 0.10, hauteur);
        // la matière : une rampe LONGUE — c'est elle qui fait le diffus
        float d = smoothstep(0.30, 0.82, n) * env;
        float a = d * float(teintes[k].a);
        rgb += float3(teintes[k].rgb) * a;
        alpha += a;
    }
    alpha = clamp(alpha, 0.0, 1.0);
    return half4(half3(min(rgb, float3(alpha))), half(alpha));
}
