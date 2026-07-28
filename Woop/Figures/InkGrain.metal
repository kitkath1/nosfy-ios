#include <metal_stdlib>
using namespace metal;

/// Grain de film monochrome pour le splash. Bruit blanc par pixel, additif :
/// sur un fond presque noir, seul le grain qui éclaircit se voit — c'est le
/// rendu pellicule des scènes sombres. `time` est quantifié côté SwiftUI pour
/// que le grain change par pas de 2-3 images, pas à chaque frame.
[[ stitchable ]] half4 inkGrain(float2 position, half4 color, float time) {
    float2 p = floor(position) + float2(time * 137.0, time * 291.0);
    float n = fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    half g = half(n) * 0.35h;
    return half4(g, g, g, color.a);
}
