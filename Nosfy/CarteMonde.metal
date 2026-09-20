#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Le monde ouvert d'une carte (banc -mondeLab, 20-09)
//
// La carte a ouvert son verre : l'illustration NUE remplit l'écran et le
// doigt conduit. Ce passage ne fait qu'une chose — la parallaxe VRAIE :
// une carte de profondeur cuite par carte (Depth Anything, cuire_profondeur.py ;
// 0,45 = le pivot, 1 = le fond du ciel, 0,10 = le plus près) déplace chaque
// pixel selon sa distance quand le téléphone penche (`tilt`) et quand le
// doigt promène l'image (`pan`, une part différentielle : le proche suit
// plus que le lointain). Pas de cadre, pas de zone morte, pas de foil :
// la matière légendaire viendra dans un autre passage.
//
// L'ARITÉ est soudée à l'appel Swift (MondeCarteLab.swift) : un paramètre
// de plus ou de moins et la page est BLANCHE sans erreur de compilation.
[[stitchable]] half4 carteMonde(float2 position, SwiftUI::Layer layer,
                                float2 size, float2 tilt, float2 pan,
                                float amp, float vignette,
                                texture2d<half> depthTex) {
    // Hors de l'image, RIEN : SwiftUI appelle aussi ce passage sur la marge
    // de `maxSampleOffset` autour de la vue, et un échantillon borné y
    // répéterait le dernier rang de pixels (la bande étirée vue au banc).
    if (position.x < 0.0 || position.y < 0.0 || position.x > size.x || position.y > size.y) {
        return half4(0.0h);
    }
    float2 uv = position / size;
    constexpr sampler ds(address::clamp_to_edge, filter::linear);
    float depth = float(depthTex.sample(ds, uv).r);
    float rel = depth - 0.45;
    // la verticale bouge moins (une main se penche plus qu'elle ne se cabre)
    float2 shift = float2(tilt.x, tilt.y * 0.72) * (rel * amp)
                 + pan * (rel * 0.22);
    // l'échantillon reste dans l'image : jamais de bord aspiré
    float2 lo = float2(2.0);
    float2 hi = size - 2.0;
    half4 c = layer.sample(clamp(position + shift, lo, hi));
    // une vignette de cinéma, douce — l'œil est tenu au centre
    float2 pn = uv - 0.5;
    float v = smoothstep(0.42, 0.88, length(pn * float2(1.0, 0.78)));
    c.rgb *= half(1.0 - vignette * v);
    return c;
}
