#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ============================================================================
// LA SCÈNE DU SLIDER — le sol sous le geste. Un fond n'est pas un dégradé,
// c'est une SCÈNE (la leçon du header exo) : ici le médaillon est une SOURCE
// qui éclaire le monde autour de lui.
//
//   • le LIT DE BRAISES : une flaque de chaleur sous le médaillon — elle
//     respire au repos, suit le doigt en course et monte en température
//     avec lui (la palette feu du panneau : blanc chaud → jaune → orange →
//     rouge) ;
//   • le REFLET : l'anneau néon se mire dans l'obsidienne polie SOUS la
//     piste — une colonne étroite, étirée par la course, jamais un spot ;
//   • les RAIS DU PHARE : trois lames de lumière très discrètes qui
//     rayonnent du médaillon et TOURNENT avec lui (rot arrive ACCUMULÉ de
//     Swift — jamais un facteur sur t, la leçon timeBoost).
//
// PIÈGES DÉJÀ PAYÉS, RESPECTÉS ICI :
//   — l'arité : la signature matche l'appel Swift AU FLOAT PRÈS, sinon la
//     page devient BLANCHE sans une erreur de compilation ;
//   — le CADRE FANTÔME : toute énergie meurt avant les bords du host, sur
//     les quatre côtés.
// ============================================================================

// La palette feu du panneau, gravée côté GPU — trois segments, jamais une
// interpolation directe blanc → rouge (elle passe par un rose sale).
static inline float3 gsFire(float u) {
    u = clamp(u, 0.0, 1.0);
    if (u < 0.35) {
        return mix(float3(1.00, 0.97, 0.88), float3(1.00, 0.84, 0.35),
                   u / 0.35);
    }
    if (u < 0.70) {
        return mix(float3(1.00, 0.84, 0.35), float3(1.00, 0.55, 0.18),
                   (u - 0.35) / 0.35);
    }
    return mix(float3(1.00, 0.55, 0.18), float3(0.88, 0.22, 0.10),
               (u - 0.70) / 0.30);
}

[[ stitchable ]] half4 galetStage(float2 pos, half4 color,
                                  float2 size,
                                  float t,
                                  float rot,
                                  float ax,
                                  float p,
                                  float mood,
                                  float refuse,
                                  float flash) {
    float2 q = pos / size;                  // 0..1 dans le host
    float aspect = size.x / size.y;
    // Le doigt, à mi-hauteur du host ; distances isotropes (en hauteurs).
    float2 d = q - float2(ax, 0.5);
    d.x *= aspect;

    // Les quatre bords : tout meurt avant — le cadre fantôme n'existera pas.
    float edge = smoothstep(0.0, 0.10, q.x) * smoothstep(1.0, 0.90, q.x)
               * smoothstep(0.0, 0.14, q.y) * smoothstep(1.0, 0.86, q.y);
    if (edge <= 0.0) { return half4(0.0); }

    // Le souffle du repos — même horloge que le médaillon (t * 1,55) :
    // toute la scène bat au même cœur. Il s'efface dès que la main pousse.
    float souffle = 0.5 + 0.5 * sin(t * 1.55);
    float calm = 1.0 - 0.8 * clamp(mood * 2.2, 0.0, 1.0);
    float3 fire = gsFire(mood * 0.9 + 0.06);
    fire = mix(fire, float3(0.62, 0.13, 0.16), refuse);   // le grenat du refus

    float3 acc = float3(0.0);

    // ------------------------------------------------- le lit de braises
    // Elliptique, plus large que haut : une flaque au sol, pas un projecteur.
    float2 e = d; e.y *= 1.45;
    float pool = exp(-dot(e, e) / (0.055 + 0.10 * mood));
    float poolI = (0.020 + 0.028 * souffle) * (calm * 0.8 + 0.2)
                + 0.22 * mood + 0.30 * flash;
    acc += fire * pool * poolI;

    // --------------------------------------------------------- le reflet
    // Sous la piste seulement : l'aplomb du médaillon, qui s'étire avec la
    // course — l'obsidienne est polie, elle rend la lumière en colonne.
    float below = max(q.y - 0.70, 0.0);
    float refl = exp(-d.x * d.x / 0.006)
               * exp(-below / (0.055 + 0.045 * p))
               * step(0.70, q.y);
    acc += fire * refl * (0.030 + 0.22 * mood + 0.05 * souffle * calm);

    // -------------------------------------------------- les rais du phare
    // Trois lames qui tournent AVEC l'anneau — lentes au repos, vives en
    // course. Elles n'existent qu'hors du médaillon, et meurent vite.
    float rr = length(d);
    float th = atan2(d.y, d.x);
    float blades = pow(0.5 + 0.5 * sin(3.0 * th + rot * 0.9), 10.0);
    float rays = blades * exp(-rr * 1.9) * smoothstep(0.14, 0.30, rr);
    acc += float3(1.0, 0.78, 0.42) * rays
           * (0.020 + 0.030 * souffle * calm + 0.14 * mood)
           * (1.0 - refuse);

    acc *= edge;
    // Additif côté Swift (plusLighter) : l'alpha ne fait que porter.
    float alp = clamp(max(max(acc.r, acc.g), acc.b), 0.0, 1.0);
    return half4(half3(acc), half(alp));
}
