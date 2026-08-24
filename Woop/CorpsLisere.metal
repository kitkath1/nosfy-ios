#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ============================================================================
// LE LISERÉ DU CORPS BLANC — la chirurgie de `galetLisere` pour l'iPod.
//
// Même doctrine que le galet d'aube (les quatre lois : parallèle pas plus
// petit, une cloche pas un trait, viser la couleur d'arrivée, renforcer =
// le halo), mais le SDF d'ellipse est remplacé par le rectangle arrondi
// (l'école `vgRR` de VerreGalet) : une VRAIE distance métrique — le
// liseré suit les coins de la dalle sans approximation, et plus besoin
// de la normalisation ‖∇q‖ de l'ellipse.
//
// LA POUDRE DE DIAMANT EST COUPÉE : son abscisse curviligne (atan2·Reff)
// est fausse sur un rectangle — elle reviendra si le rendu la réclame,
// avec une paramétrisation périmétrique.
//
// C'est un `colorEffect` SANS échantillonnage : coût plein écran
// acceptable, early-outs massifs (tout l'intérieur profond sort en une
// comparaison).
//
// PIÈGE PAYÉ (l'arité) : la signature doit matcher l'appel Swift AU
// FLOAT PRÈS — 7 float2 + 1 float — sinon la page devient BLANCHE sans
// une seule erreur de compilation. L'appel vit dans CorpsNacre.swift.
// ============================================================================

/// La distance signée au rectangle arrondi (pt, négatif dedans).
static inline float clRR(float2 p, float2 demi, float r) {
    const float2 q = abs(p) - demi + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

[[stitchable]] half4 corpsLisere(float2 pos, half4 color,
                                 float2 centre,   // cx, cy du rectangle
                                 float2 demi,     // demi-largeur, demi-hauteur
                                 float2 forme,    // rayon des coins, Δ dedans
                                 float2 ligne,    // σ du cœur, σ du halo
                                 float2 souffle,  // amplitude halo, plancher bas
                                 float2 fondu,    // cos θ plein, cos θ fin
                                 float2 ombre,    // profondeur, τ
                                 float gain)
{
    const float delta = forme.y;
    const float sigma = max(ligne.x, 0.05);
    const float sHalo = max(ligne.y, 0.2);
    if (gain <= 0.002 && ombre.x <= 0.002) return color;

    const float2 rel = pos - centre;
    const float dist = clRR(rel, demi, max(forme.x, 1.0));
    const float dedans = -dist;         // pt, positif dans la matière

    // u = 0 sur la courbe du liseré, Δ pt dans la matière.
    const float u = dist + delta;
    const float port = max(max(5.0 * sigma, 3.2 * sHalo), 3.6);
    const float portOmbre = (ombre.x > 0.002) ? (4.2 + 3.2 * ombre.y) : 0.0;
    if (dist > port || dedans > max(delta + port, portOmbre)) return color;

    // La loi angulaire : cos θ vers le haut — le liseré vif au sommet
    // (la lampe de la maison éclaire d'en haut), MOURANT vers le bas —
    // mais jamais mort : le plancher garde un fil fantôme tout autour,
    // un corps blanc bord à bord sans arête basse se lit coupé.
    const float rn = max(length(rel), 1e-5);
    const float c = -rel.y / rn;
    const float bout = mix(clamp(souffle.y, 0.0, 1.0), 1.0,
                           smoothstep(fondu.y, fondu.x, c));

    // ================= L'OMBRE DU BORD =================
    // La pièce qui fait lire un VOLUME au lieu d'un rectangle crème
    // (la leçon du galet : « ce qui manquait n'était pas de la lumière,
    // c'était le noir contre lequel elle brille »). Dérogation assumée
    // à la respiration unique : large de 25 pt, sans bord — un modelé,
    // pas une rainure. Nulle au sommet (la lumière y tombe d'aplomb),
    // elle s'ouvre en flanc et au pied.
    if (ombre.x > 0.002 && dedans > 0.0) {
        const float flanc = 1.0 - smoothstep(0.788, 0.9962, c);
        const float amp = ombre.x * (0.05 + 0.95 * flanc);
        const float creux = smoothstep(0.2, 2.5, dedans)
                            * exp(-max(dedans - 2.5, 0.0) / max(ombre.y, 1.0))
                            * (1.0 - smoothstep(22.0, 36.0, dedans));
        const float f = clamp(1.0 - amp * creux, 0.0, 1.0);
        color = half4(color.rgb * half(f), color.a);
    }

    if (fabs(u) > port) return color;

    // — LE CŒUR : la cloche fine, sous le pixel.
    const float coeur = exp(-0.5 * (u * u) / (sigma * sigma));
    // — LE SOUFFLE : la cloche large et faible qui fait la lumière
    //   (un trait n'a pas de halo).
    const float halo = exp(-0.5 * (u * u) / (sHalo * sHalo));

    // ±10 % en cos² : jamais une intensité parfaitement constante.
    const float amp = (0.90 + 0.10 * c * c) * bout;
    float k = amp * (coeur + souffle.x * halo);

    k = clamp(gain * k, 0.0, 1.0);
    if (k < 0.002) return color;

    // Source-over d'un blanc OPAQUE à couverture k, en prémultiplié —
    // la loi 3 : le pic tend vers le blanc cible quel que soit le fond.
    const half3 blanc = half3(0.980h, 0.976h, 0.965h);
    const half kk = half(k), inv = half(1.0 - k);
    return half4(blanc * kk + color.rgb * inv, kk + color.a * inv);
}
