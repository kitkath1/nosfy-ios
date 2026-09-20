#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - LA VIE VIOLENTE d'une légendaire — M1 : le feu (banc -mondeVie, 20-09 nuit)
//
// Un seul passage sur le MONDE COMPOSÉ (les six plans). Il lit deux textures
// cuites par carte / par monde (cuire_vie.py) :
//   masques  R = le feu (les pixels chauds, dilatés vers le haut)
//            G = l'émissif (la lave, la braise dans la matière)
//            B = le ciel (réservé à M2)
//   bruit    R = bruit lent, G = bruit rapide — TUILABLE, cuit, jamais procédural
// et fait quatre choses, toutes causées par la peinture :
//   1. LES FLAMMES : à un pixel, une flamme existe s'il y a du feu un peu
//      PLUS BAS, à une distance que le bruit fait varier — c'est ce qui
//      découpe des langues qui montent et se tordent ; cœur blanc, corps
//      braise, bord rouge sombre qui meurt vite.
//   2. LA CHALEUR : au-dessus du feu, l'image ondule (déplacement de
//      l'échantillon par le bruit, ±4 px) — jamais un flou.
//   3. LES BRAISES : une grille de cellules ancrée au feu ; chaque braise a
//      sa naissance, sa vie, sa dérive ; les SALVES : une pulsation toutes
//      les ~3 s, et la bouffée de la main.
//   4. LA LAVE PULSE : l'émissif monte et descend sur deux houles.
// Les masques vivent dans l'espace de l'ART : `art0` (origine) et `artSize`
// (taille affichée) retrouvent les uv de la peinture depuis la position.
//
// L'ARITÉ est soudée à l'appel Swift (VieModifier) : un paramètre de plus ou
// de moins et la page est BLANCHE sans erreur de compilation.

static float vsstep(float a, float b, float v) {
    float t = clamp((v - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

static float vhash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

[[stitchable]] half4 carteVie(float2 position, SwiftUI::Layer layer,
                              float2 size, float2 art0, float2 artSize,
                              float time, float force, float bouffee,
                              float3 lune,
                              texture2d<half> masques, texture2d<half> bruit) {
    constexpr sampler sm(address::clamp_to_edge, filter::linear);
    constexpr sampler sb(address::repeat, filter::linear);
    float2 uv = (position - art0) / artSize;                 // l'espace de l'art
    bool dedans = uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0;
    float px = artSize.x / 1024.0;                            // un pixel d'art, en points

    // — le bruit, deux échelles, qui MONTE (le feu monte)
    float2 b1 = float2(bruit.sample(sb, uv * float2(3.0, 4.5) + float2(0.0, -time * 0.55)).rg);
    float2 b2 = float2(bruit.sample(sb, uv * float2(7.0, 10.0) + float2(time * 0.07, -time * 1.6)).rg);
    float n = 0.62 * float(b1.x) + 0.38 * float(b2.y);           // 0..1, tordu et rapide

    // — 1. les flammes : du feu un peu plus bas, à une hauteur que le bruit tord
    float hauteur = (0.015 + 0.115 * n) * force;                 // en fraction de l'art — VIOLENT
    float feuBas = dedans ? float(masques.sample(sm, uv + float2(0.0, hauteur)).r) : 0.0;
    float feuIci = dedans ? float(masques.sample(sm, uv).r) : 0.0;
    float langue = vsstep(0.18, 0.90, feuBas) * (1.0 - vsstep(0.0, 0.10, uv.y));
    // le scintillement : vite (8-12 Hz), jamais un métronome
    float flick = 0.72 + 0.28 * sin(time * 61.0 + n * 9.0) * sin(time * 37.0 + uv.x * 40.0);
    float flamme = langue * flick * (0.55 + 0.45 * n);
    // le cœur blanc là où le feu est dense, la braise autour, le rouge qui meurt au bord
    half3 coeur = half3(1.00, 0.93, 0.78);
    half3 braise = half3(1.00, 0.52, 0.16);
    half3 rouge = half3(0.55, 0.08, 0.02);
    float intens = flamme * (0.85 + 0.6 * feuIci);
    half3 couleurFlamme = mix(rouge, braise, half(vsstep(0.15, 0.55, intens)));
    couleurFlamme = mix(couleurFlamme, coeur, half(vsstep(0.62, 0.98, intens)));

    // — 2. la chaleur : l'image ondule au-dessus du feu (déplacement, pas de flou)
    float chaleur = dedans ? float(masques.sample(sm, uv + float2(0.0, 0.05)).r) : 0.0;
    float2 ondule = float2(sin(time * 9.0 + uv.y * 90.0 + n * 6.0), cos(time * 7.0 + uv.x * 70.0))
                  * (4.0 * px) * chaleur * force;
    half4 c = layer.sample(clamp(position + ondule, float2(1.0), size - 1.0));

    // — 3. les braises : cellules de 5 px, ancrées au feu, naissance / vie / dérive
    float cell = 5.0 * px;
    float2 gp = (position - art0) / cell;
    float2 cid = floor(gp);
    float rnd = vhash(cid);
    float vie = 1.6 + 2.2 * vhash(cid + 3.1);
    float age = fract((time + rnd * 40.0) / vie);              // 0 → 1, chaque braise sa vie
    float2 src = (cid + float2(0.5, 0.5)) * cell + art0;        // d'où elle est née
    float2 srcUV = (src - art0) / artSize;
    float feuSrc = (srcUV.x > 0.0 && srcUV.x < 1.0 && srcUV.y > 0.0 && srcUV.y < 1.0)
                 ? float(masques.sample(sm, srcUV + float2(0.0, 0.01)).r) : 0.0;
    float gate = step(1.0 - 0.16 * (0.6 + 0.4 * force) - 0.30 * bouffee, rnd) * step(0.30, feuSrc);
    // la salve : une pulsation toutes les ~3 s (apériodique), plus la bouffée de la main
    float salve = 0.55 + 0.45 * pow(max(sin(time * 2.1) * sin(time * 0.73 + 1.0), 0.0), 3.0) + bouffee;
    float montee = (60.0 + 120.0 * vhash(cid + 7.7)) * px * age * (0.8 + 0.5 * bouffee);
    float derive = (9.0 * px) * sin(time * 3.0 + rnd * 6.28) - 14.0 * px * age * (bouffee);
    float2 pos = src + float2(derive, -montee);
    float d2 = dot(position - pos, position - pos) / (px * px);
    float taille = (1.2 + 2.2 * step(0.78, vhash(cid + 1.7))) * (1.0 - 0.45 * age);
    float braiseK = exp(-d2 / (2.0 * taille * taille)) * gate * salve * (1.0 - age) * (1.0 - age);
    half3 couleurBraise = mix(half3(1.00, 0.52, 0.16), half3(1.00, 0.88, 0.62), half(step(age, 0.12)));
    couleurBraise = mix(couleurBraise, half3(0.55, 0.08, 0.02), half(vsstep(0.55, 0.9, age)));

    // — 4. la lave pulse (deux houles) — l'émissif s'éclaire depuis la peinture
    float emi = dedans ? float(masques.sample(sm, uv).g) : 0.0;
    float pulse = 0.25 + 0.20 * sin(time * 0.86) + 0.12 * sin(time * 2.9 + uv.y * 20.0) + 0.10 * n;
    half3 lave = half3(1.00, 0.45, 0.12) * half(emi * pulse * force);

    // — M2 · LA LUNE QUI BAT : son halo respire fort (0,4 → 1), et à chaque
    //   battement une ONDE fine s'en détache — une lumière qui a une cause et
    //   un bord, jamais un balayage. `lune` = (x, y, rayon) dans l'art ; r = 0 : pas de lune.
    half3 clairLune = half3(0.0h);
    if (lune.z > 0.0 && dedans) {
        float ar = artSize.y / artSize.x;
        float2 dl = float2(uv.x - lune.x, (uv.y - lune.y) * ar);
        float dist = length(dl);
        float bat = 0.4 + 0.6 * pow(0.5 + 0.5 * sin(time * 2.09), 2.0);           // 3 s
        float halo = exp(-dist * dist / (lune.z * lune.z * 9.0)) * bat;
        float phase = fract(time / 3.0);
        float rOnde = lune.z * (1.2 + 3.6 * phase);
        float onde = exp(-pow((dist - rOnde) / (0.004 + 0.002 * phase), 2.0)) * (1.0 - phase) * (1.0 - phase);
        float cielIci = float(masques.sample(sm, uv).b);
        clairLune = half3(1.00, 0.92, 0.72) * half((halo * 0.55 + onde * 0.7) * force * (0.5 + 0.5 * cielIci));
    }
    // — M2 · L'ÉCLAIR : toutes les 6 à 15 s (apériodique), le ciel entier
    //   s'éclaire 80 ms, deux fois, et une branche cuite (canal B du bruit)
    //   se dessine dans le ciel — miroir selon l'éclair.
    float periode = 6.0 + 9.0 * vhash(float2(floor(time / 10.0), 3.0));
    float tE = fmod(time, periode);
    float flash = (tE < 0.08 ? 1.0 : (tE > 0.16 && tE < 0.22 ? 0.7 : 0.0));
    half3 eclair = half3(0.0h);
    if (flash > 0.0 && dedans) {
        float cielIci = float(masques.sample(sm, uv).b);
        float miroir = step(0.5, vhash(float2(floor(time / periode), 7.0)));
        float2 uvB = float2(mix(uv.x, 1.0 - uv.x, miroir) * 0.9 + 0.05, uv.y * 0.85);
        float branche = float(bruit.sample(sm, uvB).b) * cielIci;
        eclair = half3(0.82, 0.88, 1.00) * half((0.28 * cielIci + 1.6 * branche) * flash * force);
    }

    // — la fusion en écran : la lumière se pose, jamais claquée au blanc
    half3 add = couleurFlamme * half(intens * 0.9) + couleurBraise * half(braiseK) + lave + clairLune + eclair;
    half3 outc = 1.0h - (1.0h - c.rgb) * (1.0h - min(add, 1.0h));
    return half4(outc, c.a);
}
