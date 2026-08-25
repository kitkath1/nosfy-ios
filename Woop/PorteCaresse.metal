#include <metal_stdlib>
using namespace metal;

// MARK: - La caresse de la porte
//
// La lumière qui sort du doigt — transplantée de l'écran de connexion
// (le verdict V2 : « avant il y avait de la lumière qui sortait de mon
// doigt »). ⚠️ La source N'EST PAS LoginAurora.metal (l'archive) : les maths
// vivantes sont celles de `bgAuroraLogin` (AuroraBg.metal:650-669), recopiées
// ici À L'IDENTIQUE — gaussienne isotrope qui s'évase avec l'âge, blanc-crème
// qui dore dès 0,45 s, tone map filmique qui éclaire sans jamais écrêter.
//
// Deux différences avec l'original, et seulement deux :
//  1. la TEXTURE : le fond du login texturait la lueur par ses rideaux (`cur`)
//     — « la lueur a la matière du fond, jamais du coton ». Ici la couche vit
//     AU-DESSUS des vidéos : un petit fbm embarqué (4 octaves) rend la même
//     matière, et le plusLighter marie la lueur à la vidéo qui passe dessous ;
//  2. la SORTIE : l'original composait en fondu écran DANS son fond ; ici la
//     couche est autonome — elle sort sa lumière sur noir, et l'hôte
//     (`Rectangle().fill(.black)`) passe en `.blendMode(.plusLighter)` :
//     noir additif = identité, la lumière s'ajoute (le patron de nebulaStars,
//     DemonSky.swift:138-145). Jamais un alpha qui voile — sur les pixels
//     clairs d'une vidéo, une « lumière » prémultipliée sombre ASSOMBRIT
//     (le piège payé du fond clair).
//
// Le protocole du buffer est CELUI du login, à l'octet : des triplets
// (x, y, âge) en points d'écran et secondes, sentinelle [-4000, -4000, 9]
// quand il est vide — un buffer vide planterait le floatArray.

// Un bruit de valeur, 4 octaves — la matière de la traîne. Petit, local,
// sans dépendance : l'arité de CE shader ne bouge que si SES besoins bougent.
static float pcHash(float2 p) {
    float3 q = fract(float3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

static float pcNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = pcHash(i);
    float b = pcHash(i + float2(1, 0));
    float c = pcHash(i + float2(0, 1));
    float d = pcHash(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float pcFbm(float2 p) {
    float v = 0.0, amp = 0.5;
    for (int i = 0; i < 4; i++) {
        v += amp * pcNoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        amp *= 0.5;
    }
    return v;
}

[[ stitchable ]] half4 porteCaresse(float2 position, half4 color,
                                    float2 size, float t,
                                    device const float *trail, int trailN) {
    // La matière : les « rideaux » du login, en miniature. Une dérive lente
    // pour que la traîne vive même sous un doigt immobile.
    float cur = pow(clamp(pcFbm(position * 0.011
                                + float2(-t * 0.045, 3.7)) * 1.18,
                          0.0, 1.0), 2.5f);

    // ---- La traîne : les maths de bgAuroraLogin, verbatim.
    float L = 0.0, dor = 0.0;
    for (int i = 0; i + 2 < trailN; i += 3) {
        float age = trail[i + 2];
        float amp = exp(-age / 0.65) * (1.0 - smoothstep(1.0, 1.4, age));
        if (amp < 0.01) { continue; }
        float sig = 55.0 + 80.0 * age;
        float2 dt2 = position - float2(trail[i], trail[i + 1]);
        float g = exp(-dot(dt2, dt2) / (sig * sig));
        float w = g * amp * 0.60 * (0.72 + 0.55 * cur);
        L += w;
        dor += w * clamp(age / 0.45, 0.0, 1.0);
    }
    if (L < 0.003) { return half4(0.0, 0.0, 0.0, 1.0) * color.a; }

    float3 tt = mix(float3(1.00, 0.96, 0.88), float3(1.00, 0.78, 0.42),
                    clamp(dor / max(L, 1e-5), 0.0, 1.0));
    float vt = 1.0 - exp(-L * 1.70);
    // Lumière sur noir : l'hôte est opaque (jamais .clear — le `* color.a`
    // final annulerait tout, le piège payé de la gerbe du swap), et le
    // plusLighter de l'appelant fait l'addition.
    return half4(half3(tt * vt), 1.0) * color.a;
}
