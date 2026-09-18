#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - Le badge du trésor
//
// Une plaque d'or en capsule, le nombre de pièces posé dessus (le texte vit
// côté SwiftUI, jamais dans le shader), et la POUSSIÈRE qui la nimbe.
//
// La poussière reprend la recette du galet (PebbleDust) : deux nappes qui
// dérivent à des vitesses différentes, un hachage par cellule, et un grain
// sur soixante qui s'allume vraiment — c'est cette minorité qui fait
// l'éclat. Deux différences ici : l'enveloppe suit la SDF de la capsule (et
// non la crête d'un dôme), et le grain est DORÉ, pas crème — sur une plaque
// d'or, une poussière blanche se lit comme de la neige.

/// Un seul hachage par cellule, trois sorties : la place du grain (x, y) et
/// son éclat (z). Nommé `tb…` — `static` porte une liaison interne, mais
/// deux fichiers de la même bibliothèque ne gagnent rien à partager un nom.
static inline float3 tbHash3(float2 p) {
    float3 q = fract(float3(p.xyx) * float3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.xxy + q.yzz) * q.zyx);
}

/// SDF d'une capsule (rectangle dont le rayon vaut la demi-hauteur) :
/// négatif dedans, positif dehors, en points.
static inline float tbCapsule(float2 p, float2 hs) {
    const float r = hs.y;
    const float2 d = abs(p) - (hs - r);
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

/// `plate` = (centre x, centre y, largeur, hauteur) de la capsule dans les
/// coordonnées de l'hôte. L'hôte DÉBORDE la plaque : la poussière et le halo
/// vivent dehors, et `hostFade` les éteint avant le bord du rectangle —
/// la leçon payée partout ailleurs (une lumière qui meurt contre son cadre
/// dessine son cadre).
[[ stitchable ]] half4 treasureBadge(float2 pos, half4 color,
                                     float2 size, float4 plate,
                                     float t, float emission) {
    const float2 c = plate.xy;
    const float2 hs = plate.zw * 0.5;
    const float2 p = pos - c;
    const float d = tbCapsule(p, hs);
    const float outd = max(d, 0.0);

    float3 col = float3(0.0);
    float a = 0.0;

    // ------------------------------------------------------------------
    // La plaque
    // ------------------------------------------------------------------
    if (d < 1.0) {
        // Le corps : clair en haut, profond en bas — l'or est un métal, il
        // ne s'éclaire pas à plat. Deux segments, pas un dégradé linéaire :
        // le ton moyen (le woopGold de la maison) doit tomber au MILIEU,
        // sinon la plaque vire au laiton.
        const float u = clamp((p.y + hs.y) / max(hs.y * 2.0, 1e-3), 0.0, 1.0);
        const float3 gTop = float3(1.000, 0.918, 0.690);
        const float3 gMid = float3(0.949, 0.749, 0.325);
        const float3 gBot = float3(0.505, 0.330, 0.106);
        float3 body = (u < 0.5) ? mix(gTop, gMid, u * 2.0)
                                : mix(gMid, gBot, (u - 0.5) * 2.0);

        // Le balayage : une bande oblique qui traverse la plaque en une
        // vingtaine de secondes. Exposant 9 — un reflet d'or est ÉTROIT ;
        // large, il repeint la plaque en blanc et l'aplatit.
        const float sw = sin(p.x * 0.026 + p.y * 0.015 - t * 0.32);
        body += float3(0.34, 0.29, 0.17) * pow(max(sw, 0.0), 9.0);

        // Le liseré : un cheveu clair sur tout le pourtour, plus vif en
        // haut (la lumière vient de là, comme sur tout le reste de l'app).
        const float rim = smoothstep(-1.7, -0.15, d);
        const float top = 0.55 + 0.45 * smoothstep(0.4, -0.9, p.y / max(hs.y, 1e-3));
        body = mix(body, float3(1.0, 0.965, 0.855), rim * 0.72 * top);

        col = body;
        // L'antialias du bord, et lui seul : la plaque est opaque.
        a = smoothstep(0.9, -0.9, d);
        col *= a;
    }

    // ------------------------------------------------------------------
    // Le halo : la plaque pose sa lumière sur la nuit
    // ------------------------------------------------------------------
    if (d > -1.0) {
        const float halo = exp(-outd / 11.0) * 0.20 * emission;
        col += float3(0.98, 0.76, 0.36) * halo;
        a = max(a, halo);
    }

    // ------------------------------------------------------------------
    // La poussière
    // ------------------------------------------------------------------
    // Au-delà de 46 pt il ne reste que 2 % de la densité : invisible, et
    // c'est la moitié des pixels du calque qu'on s'épargne.
    if (outd > 0.5 && outd < 46.0) {
        // L'enveloppe suit la capsule ; le biais vers le HAUT fait monter la
        // poudre au lieu de la faire flotter en anneau.
        const float env = exp(-outd / 15.0);
        const float up = smoothstep(hs.y * 0.30, -hs.y * 1.70, p.y);
        const float dens = env * (0.26 + 0.74 * up) * emission;

        if (dens > 0.004) {
            const float cell = 3.4;
            const float sigma = 0.44;
            const float inv2s2 = 1.0 / (2.0 * sigma * sigma);
            float g = 0.0;
            // Deux nappes à des vitesses différentes : la parallaxe donne
            // l'épaisseur, et le grain qui sort par le haut rentre par le
            // bas sans qu'aucun ne naisse ni ne meure à l'écran.
            for (int L = 0; L < 2; ++L) {
                const float speed = 2.6 + 1.5 * float(L);
                const float2 sp = float2(pos.x + 41.3 * float(L),
                                         pos.y + t * speed);
                const float2 gc = floor(sp / cell);
                const float2 f = sp / cell - gc;
                for (int j = -1; j <= 1; ++j) {
                    for (int i = -1; i <= 1; ++i) {
                        const float2 id = gc + float2(i, j)
                                          + float2(87.1 * float(L), 0.0);
                        const float3 hh = tbHash3(id);
                        const float2 gp = float2(i, j) + 0.5
                                          + (hh.xy - 0.5) * 0.8 - f;
                        const float dd = length(gp) * cell;
                        // pow³ : la masse reste sous le seuil, un grain sur
                        // soixante s'allume vraiment.
                        const float br = hh.z * hh.z * hh.z;
                        const float tw = 0.55 + 0.45
                            * sin(t * (0.8 + 1.4 * hh.x) + hh.y * 6.2831853);
                        g += exp(-dd * dd * inv2s2) * (0.06 + 0.46 * br) * tw;
                    }
                }
            }
            // Plafond dur : aucun grain ne doit pouvoir se détacher du voile.
            const float ga = min(g * dens, 0.30);
            col += float3(1.00, 0.83, 0.47) * ga;
            a = max(a, ga);
        }
    }

    if (a < 0.002) { return half4(0.0); }

    // Émissif prémultiplié + fondu d'hôte : la lumière porte sa couverture,
    // et rien ne meurt contre le bord du rectangle.
    const float2 toEdge = min(pos, size - pos);
    const float hostFade = smoothstep(0.0, 10.0, min(toEdge.x, toEdge.y));
    a = clamp(a, 0.0, 1.0) * hostFade;
    col = clamp(col, 0.0, 1.0) * hostFade;
    return half4(half3(min(col, float3(a))), half(a)) * color.a;
}
