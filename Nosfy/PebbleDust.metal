#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ============================================================================
// LA POUDRE DU GALET — une BRUME, pas des points.
//
// Le Canvas ne pouvait pas y arriver : pour qu'un semis cesse d'être
// comptable, il faut que l'écart entre voisins tombe sous ~2 pt, donc des
// milliers de grains — impossible en formes SwiftUI à 30 Hz. Ici chaque
// pixel demande aux quelques cellules qui l'entourent si un grain y vit :
// le coût est constant, la densité est libre.
//
// LES QUATRE LOIS, mesurées sur les rejets précédents :
// 1. DENSITÉ — cellule de 3,1 pt = 0,10 grain/pt² : l'œil ne sépare plus.
// 2. FORME — un grain est une GAUSSIENNE (σ 0,42 pt) centrée en position
//    fractionnaire : le cœur reste sous le pixel (« hyper fin ») mais la
//    queue s'étale sur 3-4 px. Un pixel allumé scintille et lit « mort ».
// 3. RÉPARTITION — grille JITTERÉE (±0,4 cellule), jamais un tirage
//    uniforme : le Poisson fait des paquets et des trous, et les paquets
//    se lisent comme des points.
// 4. CHAMP — la densité meurt en exponentielle au-dessus de la crête et
//    s'éteint sur les flancs avec la lumière : la poudre est une texture
//    DANS le halo, jamais un collier posé par-dessus.
//
// Et le piège du bouillonnement : la graine dépend de la CELLULE, jamais
// du temps. Le temps ne fait que dériver le repère et respirer l'éclat —
// re-tirer par image donnerait de la neige de télévision.
// ============================================================================

/// UN SEUL hachage par cellule, trois sorties : la place du grain (x, y)
/// et son éclat (z). Deux hachages coûtaient le double pour rien — sur un
/// champ à 0,1 grain/pt², chaque appel se paie 18 fois par pixel.
static inline float3 dustHash3(float2 p) {
    float3 q = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.xxy + q.yzz) * q.zyx);
}

[[stitchable]] half4 pebbleDust(float2 pos, half4 color,
                                float2 center,   // centre du dôme
                                float2 domeRS,   // rayon, écrasement
                                float t,
                                float emission)
{
    const float D = domeRS.x, squash = max(domeRS.y, 0.01);
    const float2 d = float2(pos.x - center.x, (pos.y - center.y) * squash);
    const float r = max(length(d), 0.5);
    const float above = r - D;
    // Au-delà de 110 pt la densité vaut 2,5 % : invisible, et c'est la
    // moitié des pixels du calque qu'on s'épargne.
    if (above < -8.0 || above > 110.0) return half4(0.0);

    const float2 n = d / r;
    // Le haut seulement : la poudre monte de la crête, pas des flancs.
    const float ang = smoothstep(0.08, 0.72, clamp(-n.y, 0.0, 1.0));
    // Le CHAMP : plein juste au-dessus de la crête, moitié à 20 pt, un
    // dixième à 65 pt — une exponentielle, aucun bord.
    float dens = exp(-max(above, 0.0) / 30.0) * ang
                 * smoothstep(-8.0, 3.0, above);
    if (dens < 0.003) return half4(0.0);

    const float cell = 3.1;
    const float sigma = 0.42;
    const float inv2s2 = 1.0 / (2.0 * sigma * sigma);

    float a = 0.0;
    // DEUX nappes qui montent à des vitesses différentes : la parallaxe
    // donne l'épaisseur, et le grain qui sort par le haut rentre par le
    // bas sans qu'aucun ne naisse ni ne meure à l'écran. (Trois nappes ne
    // se voyaient pas et coûtaient un tiers de la cadence.)
    for (int L = 0; L < 2; ++L) {
        const float speed = 2.2 + 1.3 * float(L);
        const float2 sp = float2(pos.x + 37.7 * float(L),
                                 pos.y + t * speed);
        const float2 g = floor(sp / cell);
        const float2 f = sp / cell - g;
        for (int j = -1; j <= 1; ++j) {
            for (int i = -1; i <= 1; ++i) {
                const float2 id = g + float2(i, j) + float2(91.3 * L, 0.0);
                const float3 hh = dustHash3(id);
                const float2 gp = float2(i, j) + 0.5
                                  + (hh.xy - 0.5) * 0.8 - f;
                const float dd = length(gp) * cell;
                // pow³ : la masse reste sous le seuil, un grain sur
                // soixante s'allume vraiment — c'est cette minorité qui
                // fait l'éclat, pas quatre gros points.
                const float br = hh.z * hh.z * hh.z;
                const float tw = 0.55 + 0.45
                    * sin(t * (0.7 + 1.3 * hh.x) + hh.y * 6.2831853);
                a += exp(-dd * dd * inv2s2) * (0.05 + 0.42 * br) * tw;
            }
        }
    }

    // Plafond dur : aucun grain ne doit pouvoir se détacher du voile.
    a = min(a * dens * emission, 0.17);
    if (a < 0.002) return half4(0.0);
    const float3 c = float3(0.99, 0.97, 0.93);
    return half4(half3(c * a), half(a));
}
