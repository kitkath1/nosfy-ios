#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - La pastille du butin
//
// Une capsule de nuit, cerclée d'un fil d'or de 0,7 pt. TOUT est dessiné ici,
// et c'est la condition du zoom : la géométrie arrive en POINTS D'ÉCRAN, déjà
// multipliée par la caméra. Le fil reste donc un vrai fil antialiasé à
// n'importe quel grossissement — jamais une image agrandie. C'est l'école du
// monolithe de la connexion : « la caméra du shader pousse, le rendu reste
// vectoriel, net à tout grossissement ».
//
// LE LISERÉ N'EST PAS UN CONTOUR, C'EST UNE ARÊTE ÉCLAIRÉE. Mesuré sur la
// référence de Kathryn, l'or varie de 1 à 240 sur 255 le long du périmètre —
// un facteur 240 — avec DEUX FOYERS diamétralement opposés. Un `strokeBorder`
// uniforme ne peut pas rendre ça, et un liseré clair posé à plat sur la nuit
// se lit comme un bug (la leçon des cartes swap). Ici l'or ne vit que là où
// la lumière rase le métal, et il s'éteint ailleurs.
//
// L'INTÉRIEUR est mesuré lui aussi : 7/255 en haut, 0 en bas, gris NEUTRE.
// C'est plus noir et plus froid que l'anthracite des cartes de la home
// (14 → 6, chaudes) : la pastille n'est pas dans leur matière.

static float pfbm(float2 p) {
    float3 q = fract(float3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

[[ stitchable ]] half4 bravoPill(float2 position, half4 color,
                                 float2 size, float2 center,
                                 float2 halfB, float rimW,
                                 float t, float amount, float flare) {
    if (amount < 0.002) { return half4(0.0); }
    const float2 p = position - center;

    // ---- La capsule : SDF exacte, donc net à toute échelle.
    const float hy = max(halfB.y, 1.0);
    const float hx = max(halfB.x, hy);
    const float2 q = float2(max(abs(p.x) - (hx - hy), 0.0), p.y);
    const float d = length(q) - hy;          // < 0 dedans

    // Un pixel machine, pour l'antialiasing — jamais une constante en points.
    const float aa = 0.8;

    // ---- L'intérieur : 7/255 en haut → 0 en bas, neutre (mesuré).
    const float inside = smoothstep(aa, -aa, d);
    const float uvY = clamp((p.y + hy) / (2.0 * hy), 0.0, 1.0);
    float3 col = float3(mix(0.0275, 0.0, uvY));
    // Un grain très fin : sans lui, une rampe de 7 niveaux BANDE sur OLED.
    col += (pfbm(position * 1.7) - 0.5) * (1.4 / 255.0);
    col *= inside;

    // ---- L'ARÊTE. La normale sortante, approchée sur l'ellipse
    // circonscrite : suffisant pour moduler une lumière, et sans branche.
    const float2 n = normalize(float2(p.x / hx, p.y / hy) + 1e-5);
    // Les deux foyers, opposés, et qui DÉRIVENT très lentement : l'or vit,
    // il n'est pas peint. 47 s, premier avec rien d'autre sur la page.
    const float a0 = -1.98 + 0.16 * sin(t * 6.2832 / 47.0);
    const float2 f1 = float2(cos(a0), sin(a0));
    const float k1 = pow(max(dot(n, f1), 0.0), 3.0);
    const float k2 = pow(max(dot(n, -f1), 0.0), 3.0);
    // 0,10 au plus terne, 1,0 au foyer : le facteur 240 de la référence, en
    // luminance perçue.
    const float lit = 0.10 + 0.90 * clamp(k1 + k2, 0.0, 1.0);

    const float3 GOLD = float3(1.000, 0.762, 0.318);
    const float3 GOLD_HOT = float3(1.000, 0.920, 0.780);

    // Le fil lui-même : une bande centrée sur d = 0, épaisse de rimW.
    const float band = smoothstep(rimW * 0.5 + aa, rimW * 0.5 - aa, abs(d));
    float3 gold = mix(GOLD, GOLD_HOT, clamp(lit * lit, 0.0, 1.0));
    col += gold * (band * lit);

    // ---- LA BUÉE, dehors seulement, et seulement AUX FOYERS. C'est elle
    // qu'on voit déborder sur la référence, en haut et en bas.
    const float out = max(d, 0.0);
    // MESURÉ ET CORRIGÉ : à 0,22 avec une décroissance large, la buée
    // remontait l'intérieur de la capsule à 44/255 près du fil, quand la
    // référence de Kathryn y mesure 7. Elle doit rester COLLÉE au fil.
    const float haze = exp(-out / (2.0 + 1.6 * rimW)) * clamp(k1 + k2, 0.0, 1.0);
    col += GOLD * (haze * 0.085);
    // Et un souffle très court collé au fil, côté intérieur : le verre prend
    // la lumière de son propre cerclage.
    col += GOLD * (exp(-max(-d, 0.0) / 2.4) * inside * lit * 0.010);

    // ---- LE SOUFFLE DU JAILLISSEMENT. Quand les lunes s'échappent, la
    // capsule s'éclaire DE L'INTÉRIEUR, à l'endroit d'où elles partent — la
    // place de la pièce, à −0,252 de la largeur. Ce n'est pas un flash posé
    // dessus : c'est l'énergie qui sort, donc elle naît dans la matière et le
    // fil d'or la reprend au passage.
    if (flare > 0.003) {
        const float2 src = float2(-0.252 * 2.0 * hx, 0.0);
        const float dl = length(p - src);
        const float core = exp(-dl / (hy * 1.15));
        const float wide = exp(-dl / (hy * 3.4));
        col += float3(1.000, 0.895, 0.735) * (core * 0.62 * flare * inside);
        col += float3(1.000, 0.762, 0.318) * (wide * 0.26 * flare);
        // Le fil d'or prend le souffle sur toute sa longueur.
        col += GOLD_HOT * (band * flare * 0.55);
    }

    col *= amount;
    const float a = clamp(max(max(col.r, col.g), col.b) * 1.45, 0.0, 1.0);
    return half4(half3(col), half(a)) * color.a;
}
