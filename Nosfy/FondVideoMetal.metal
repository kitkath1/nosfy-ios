#include <metal_stdlib>
using namespace metal;

struct FondVideoSommet {
    float4 position [[position]];
    float2 uv;
};

struct FondVideoUniformes {
    float4 hote;
    float4 braise;
    float4 pilule;
};

vertex FondVideoSommet fondVideoSommet(uint id [[vertex_id]]) {
    const float2 positions[] = { float2(-1, -1), float2(3, -1), float2(-1, 3) };
    FondVideoSommet out;
    out.position = float4(positions[id], 0, 1);
    out.uv = float2(positions[id].x * 0.5 + 0.5, 0.5 - positions[id].y * 0.5);
    return out;
}

// Chaque fichier est rogné à une boîte légèrement différente de son ratio
// d'affichage. Reproduire resizeAspectFill, centré, puis le clip de cette boîte.
static float3 fondVideoCalque(texture2d<float> image, float2 point, float4 rect) {
    float2 local = point - rect.xy;
    if (any(local < 0) || any(local >= rect.zw)) return float3(0);
    float2 pixels = float2(image.get_width(), image.get_height());
    float facteur = max(rect.z / pixels.x, rect.w / pixels.y);
    float2 uv = (local - rect.zw * 0.5) / (pixels * facteur) + 0.5;
    constexpr sampler lecteur(coord::normalized, address::clamp_to_edge, filter::linear);
    return image.sample(lecteur, uv).rgb;
}

fragment float4 fondVideoFragment(FondVideoSommet in [[stage_in]],
                                 constant FondVideoUniformes &u [[buffer(0)]],
                                 texture2d<float> braise [[texture(0)]],
                                 texture2d<float> pilule [[texture(1)]]) {
    float2 point = in.uv * u.hote.xy;
    float3 base = fondVideoCalque(braise, point, u.braise);
    float3 ajout = fondVideoCalque(pilule, point, u.pilule) * u.hote.z;
    // Diagnostic SDR : addition des RGB décodés BGRA, sortie opaque. Les
    // vidéos n'ont pas de tags colorimétriques ; la fidélité doit être comparée
    // sur l'appareil. Le scrim SwiftUI reste au-dessus, identique au témoin.
    return float4(saturate(base + ajout), 1);
}
