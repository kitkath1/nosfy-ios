#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ============================================================================
// LES HALOS DE LA MOLETTE — la lumière SOUS le verre natif.
//
// L'essai demandé (« si tu mets des halos ça donne quoi, sans toucher au
// verre ») : la texture-lait est morte — à la place, la grammaire du
// profil qu'elle aime déjà : des HALOS doux qui dérivent sous la dalle
// .clear, comme BanniereHalos sous le couvercle du profil. Le verre est
// INTOUCHÉ : ce shader ne fait que le contenu.
//
// (La version lait-métaballes vit dans le scratchpad
// LiquideMolette-lait.metal si l'A/B la rappelle.)
//
// TROIS LOIS :
//
// 1. NOIR ET BLANC. Des lueurs lune sur la nuit — zéro orange, zéro
//    teinte, zéro texture : de la LUMIÈRE pure, pas de la matière.
//
// 2. DES GAUSSIENNES, PAS DES DISQUES. Un halo n'a pas de bord — cœur
//    doux, queues qui meurent sans montrer où elles s'arrêtent.
//
// 3. LA RÈGLE (dictée) : au repos les halos se voient franchement
//    (veille) ; sous le doigt tout s'éveille, les halos proches sont
//    aspirés vers le contact et un halo naît sous le doigt.
// ============================================================================

static inline float3 lqHash3(float n) {
    float3 q = fract(float3(n, n * 1.37, n * 2.71)
                     * float3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.xxy + q.yzz) * q.zyx);
}

[[stitchable]] half4 liquideMolette(float2 pos, half4 color,
                                    float2 taille,  // w, h du rect hôte
                                    float2 doigt,   // point de contact (px)
                                    float2 etat,    // vie 0→1, t (s)
                                    float2 forme,   // rayon (px), vitesse
                                    float2 regle,   // veille, éveil
                                    float2 corps)   // nombre, remous
{
    // LES HALOS BLANCS (le verdict : « plus de lumière halo blanc
    // comme on avait avant ») : des gaussiennes SOMMÉES — pas de bord,
    // pas de disque, de la lumière. La pièce nacrée unique était trop
    // sage ; ici la molette porte sa propre clarté, et le verre la
    // réfracte par-dessus la scène qui transparaît.
    const float vie = clamp(etat.x, 0.0, 1.0);
    const float t = etat.y;
    const float rH = max(forme.x, 14.0);
    const float vit = (0.04 + 0.16 * clamp(forme.y, 0.0, 1.0))
                    * 6.2831853;
    const int n = int(clamp(corps.x, 1.0, 14.0));
    const float remous = clamp(corps.y, 0.0, 1.0);

    float somme = 0.0;
    float chaleur = 0.0;
    for (int i = 0; i < 14; ++i) {
        if (i >= n) break;
        const float3 h = lqHash3(float(i) * 1.618 + 7.0);
        const float3 h2 = lqHash3(float(i) * 2.113 + 3.0);
        const float2 base = float2(0.14 + 0.72 * h.x,
                                   0.14 + 0.72 * h.y) * taille;
        const float2 amp = float2(0.08 + 0.14 * h.z,
                                  0.08 + 0.14 * h2.x) * taille;
        const float w1 = (0.5 + 0.9 * h2.y) * vit;
        const float w2 = (0.4 + 0.8 * h2.z) * vit;
        float2 c = base
            + float2(sin(t * w1 + h.z * 6.2831853) * amp.x,
                     cos(t * w2 + h.x * 6.2831853) * amp.y);
        const float2 vers = doigt - c;
        const float att = exp(-dot(vers, vers)
                              / (2.0 * 130.0 * 130.0))
                        * vie * (0.35 + 0.25 * remous);
        c += vers * att;
        const float resp = 1.0 + 0.08
            * sin(t * (0.25 + 0.30 * h.y) + h2.z * 6.2831853);
        const float sg = rH * (0.62 + 0.55 * h2.x) * resp;
        const float2 dd = pos - c;
        const float g = exp(-dot(dd, dd) / (2.0 * sg * sg));
        somme += (0.60 + 0.40 * h.z) * g;
        // Un halo sur trois tire vers le chaud (l'accent orange).
        chaleur += (h2.y > 0.66 ? 1.0 : 0.0) * g;
    }
    // LE HALO DU DOIGT : franc, il naît au contact.
    if (vie > 0.01) {
        const float sD = rH * 0.95;
        const float2 dD = pos - doigt;
        somme += vie * 1.05 * exp(-dot(dD, dD) / (2.0 * sD * sD));
    }

    const float vieF = regle.x + (regle.y - regle.x) * vie;
    const float k = clamp(somme * 0.62 * vieF, 0.0, 0.92);
    if (k < 0.004) return half4(0.0h);

    // Blanc lune, tiré vers l'orange là où la chaleur domine.
    const float w = clamp(chaleur / max(somme, 0.001), 0.0, 1.0);
    const float3 lune = float3(0.975, 0.980, 1.000);
    const float3 chaud = float3(1.000, 0.640, 0.300);
    const float3 col = mix(lune, chaud, w * 0.55);
    const half kh = half(k);
    return half4(half3(col) * kh, kh);
}
