#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// LE CUIR DU CARNET — la vie posée SUR les plaques forgées (jalon 1 du
// chantier carnet, 19-08). La plaque porte la matière (grain, embossage,
// tranche) ; le shader ne peint rien de neuf : il fait VIVRE ce qui est
// déjà là. Deux étages, tous deux MULTIPLICATIFS (la leçon de
// l'obsidienne : un reflet qui s'ajoute grise le noir ; un reflet qui
// multiplie révèle la matière et laisse le noir souverain) :
//
// 1. LE REFLET TRAVERSANT — une bande diagonale large qui parcourt le
//    cuir en ~31 s (la période du sheen des cartes swap, l'écran parle
//    d'une seule voix). Elle n'existe que par le grain qu'elle allume.
// 2. LA RESPIRATION DE LA TRANCHE — l'or détecté par sa CHALEUR (R−B),
//    jamais par sa position : ±3 % en deux périodes incommensurables
//    (7,3 s et 3,1 s). La règle de l'obsidienne : l'écart image à image
//    reste sous ~1 niveau sur 255 — une animation qu'on VOIT est un
//    effet, pas une matière.
//
// Le nom porte V1 exprès (piège de l'arité) : une metallib périmée tombe
// sur RIEN — page rouge du banc — plutôt que sur une vieille signature.
[[ stitchable ]] half4 carnetCuirV1(float2 position, half4 color,
                                    float2 size, float t) {
    // L'hôte est l'image de la plaque elle-même : color EST le cuir.
    float2 uv = position / max(size, float2(1.0, 1.0));

    float lum = float(max(color.r, max(color.g, color.b)));

    // ---- 1. Le reflet traversant.
    // La bande vit sur l'axe diagonal (x + 0,55 y), la grammaire du sheen
    // des cartes swap ; elle traverse en 31 s, gaussienne large.
    float band = (uv.x + 0.55 * uv.y) / 1.55;
    float sweep = fract(t / 31.0);
    // La course déborde de part et d'autre : la bande entre et sort, elle
    // ne « rebondit » pas dans le cadre.
    float centre = mix(-0.35, 1.35, sweep);
    float d = (band - centre) / 0.22;
    float voile = exp(-d * d);
    // Multiplicatif, et gaté par la luminance locale : le reflet n'existe
    // que là où la plaque a de la matière à montrer. Le plafond (0,30)
    // garde le cuir cuir — un cuir qui flashe est un vinyle.
    float grain = smoothstep(0.015, 0.10, lum);
    float reflet = 1.0 + voile * 0.30 * grain;

    // ---- 2. La respiration de la tranche.
    // L'or se reconnaît à sa chaleur : R franchement au-dessus de B, et
    // assez de lumière pour être une tranche, pas un voile.
    float chaleur = float(color.r) - float(color.b);
    float or_ = smoothstep(0.06, 0.30, chaleur) * smoothstep(0.05, 0.25, lum);
    float souffle = 0.03 * sin(t * 2.0 * M_PI_F / 7.3)
                  + 0.014 * sin(t * 2.0 * M_PI_F / 3.1);
    float braise = 1.0 + or_ * souffle;

    half3 rgb = color.rgb * half(reflet * braise);
    return half4(rgb, color.a);
}
