#include <metal_stdlib>
using namespace metal;

// MARK: - Le médaillon laqué de la flamme-jauge
//
// La recette du galet play de la nav bar, transposée au FEU : un galet MAT,
// et dedans la flamme EXTRUDÉE en laque orange — c'est le contraste mat/laqué
// qui fait le bijou, jamais la brillance partout. La lampe vit DANS la laque :
// un cœur surexposé au fondu d'écran (jamais une addition, la leçon du login),
// une teinte qui dérive de l'orange au blanc chaud, et la nappe qui traverse
// le galet pour aller mourir sur la carte.
//
// La flamme n'est pas un glyphe échantillonné : c'est un SDF sculpté — un
// ventre rond, une langue effilée qui monte en penchant à droite, et la
// TAILLE creusée sur le flanc gauche. Le cœur intérieur est GRAVÉ dans la
// laque : un sillon fin dont le chanfrein attrape le spéculaire.

namespace jauge {

inline float sdCircle(float2 p, float r) { return length(p) - r; }

/// Capsule à rayons inégaux (Inigo Quilez, VERBATIM) : le tronc de la
/// flamme — large au ventre, presque rien à la pointe. La première version
/// « de tête » mélangeait longueurs et longueurs² dans la branche du cône :
/// le médaillon entier devenait une barre diagonale.
inline float sdUneven(float2 p, float2 pa, float2 pb, float ra, float rb) {
    p -= pa; pb -= pa;
    float h = dot(pb, pb);
    float2 q = float2(dot(p, float2(pb.y, -pb.x)), dot(p, pb)) / h;
    q.x = abs(q.x);
    float b = ra - rb;
    float2 c = float2(sqrt(max(h - b * b, 1e-6)), b);
    float k = c.x * q.y - c.y * q.x;
    float m = dot(c, q);
    float n = dot(q, q);
    if (k < 0.0) return sqrt(h * n) - ra;
    if (k > c.x)  return sqrt(h * (n + 1.0 - 2.0 * q.y)) - rb;
    return m - ra;
}

inline float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

inline float smax(float a, float b, float k) { return -smin(-a, -b, k); }

/// Le SDF de la flamme, en coordonnées normalisées (rayon du galet = 1).
/// `sway` penche la pointe — la flamme se courbe, elle ne pivote pas.
inline float sdFlamme(float2 q, float sway) {
    // La courbure : le haut part avec le vent, le pied reste planté.
    float bend = smoothstep(0.35, -0.75, q.y);
    q.x -= sway * 0.16 * bend * bend;
    // Le ventre — CHARNU : c'est lui le bijou, la pointe n'est qu'un accent.
    float d = sdCircle(q - float2(0.0, 0.26), 0.385);
    // La langue, du ventre à la pointe, penchée à droite.
    d = smin(d, sdUneven(q, float2(0.02, 0.26), float2(0.115, -0.52),
                         0.34, 0.040), 0.10);
    // La TAILLE : le flanc gauche se creuse — c'est l'asymétrie qui fait
    // lire « flamme » et non « goutte ».
    d = smax(d, -sdCircle(q - float2(-0.52, -0.20), 0.20), 0.09);
    return d;
}

/// Le cœur gravé : la petite flamme intérieure, même grammaire, plus petite.
inline float sdCoeur(float2 q, float sway) {
    float bend = smoothstep(0.45, -0.20, q.y);
    q.x -= sway * 0.10 * bend * bend;
    float d = sdCircle(q - float2(0.0, 0.40), 0.155);
    d = smin(d, sdUneven(q, float2(0.01, 0.40), float2(0.065, 0.055),
                         0.135, 0.020), 0.07);
    d = smax(d, -sdCircle(q - float2(-0.26, 0.16), 0.115), 0.06);
    return d;
}

} // namespace jauge

/// Le médaillon entier : galet mat, flamme laquée, lampe. `size` en points,
/// `souffle` la respiration lente [0;1], `derive` le balancement [-1;1],
/// `boost` l'inspiration de la cérémonie [0;1].
[[ stitchable ]] half4 jaugeLacque(float2 pos, half4 color,
                                   float2 size, float time,
                                   float souffle, float derive, float boost) {
    float R = min(size.x, size.y) * 0.5;
    float2 p = (pos - size * 0.5) / R;
    float t = time;

    // ---- le galet, mat --------------------------------------------------
    float da = length(p) - 0.985;
    float aGalet = smoothstep(0.02, -0.02, da);
    if (aGalet <= 0.001) return half4(0.0);

    float uy = clamp(p.y * 0.5 + 0.5, 0.0, 1.0);
    float ux = clamp(p.x * 0.5 + 0.5, 0.0, 1.0);
    // La pierre sombre, à peine chaude, plus claire en tête.
    float3 pbase = mix(float3(0.1250, 0.1000, 0.0920),
                       float3(0.0330, 0.0245, 0.0260),
                       uy * uy * (3.0 - 2.0 * uy));
    // Le dôme intérieur collé à la paroi, pondéré haut-gauche : le POLI.
    float pwall = exp(-max(-da, 0.0) / 0.34);
    float pupleft = clamp(0.62 * (1.0 - uy) + 0.38 * (1.0 - ux), 0.0, 1.0);
    float3 rgb = pbase * (1.0 - 0.30 * pwall)
               + pwall * pow(pupleft, 2.2) * 0.085;
    // Le rasant du bord — et en bas, c'est la BRAISE qui remonte, pas le ciel.
    float rim = pow(clamp(length(p), 0.0, 1.0), 6.0);
    rgb += rim * (0.35 + 0.65 * uy) * float3(0.34, 0.115, 0.035) * (0.55 + 0.45 * souffle);
    rgb += rim * (1.0 - uy) * float3(0.110, 0.115, 0.130);
    // Le SERTISSAGE : une ligne fine au ras du bord, blanche en tête, braise
    // au pied — c'est elle qui fait lire « galet poli », pas « rond flou ».
    float lisere = 1.0 - smoothstep(0.0, 0.030, fabs(da + 0.030));
    rgb += lisere * mix(float3(0.30, 0.11, 0.04), float3(0.16, 0.15, 0.15),
                        1.0 - uy) * (0.7 + 0.3 * souffle);

    // ---- la flamme, laquée ----------------------------------------------
    float2 q = p * (1.0 / 0.82) - float2(0.0, 0.02);
    float sway = derive;
    float d = jauge::sdFlamme(q, sway);
    float dc = jauge::sdCoeur(q, sway);
    // Le sillon du cœur, gravé dans la laque : le chanfrein du canal attrape
    // la lumière tout seul, par les différences finies.
    float dg = max(d, -(abs(dc) - 0.030));

    // Chanfrein quart-de-rond, normale basculée — la recette du play. Large :
    // c'est la LARGEUR du chanfrein qui donne sa présence à la bande
    // spéculaire, un fil trop fin ne se voit pas à 58 pt.
    float ch = 0.165;
    float e = 0.022;
    float2 gn = normalize(float2(
        jauge::sdFlamme(q + float2(e, 0.0), sway) - jauge::sdFlamme(q - float2(e, 0.0), sway),
        jauge::sdFlamme(q + float2(0.0, e), sway) - jauge::sdFlamme(q - float2(0.0, e), sway))
        + float2(1e-5, 0.0));
    float uch = clamp(-dg / ch, 0.0, 1.0);
    float nxy = sqrt(max(1.0 - uch * uch, 0.0));
    float3 nrm = normalize(float3(gn * nxy, uch + 0.02));

    // Deux sources ; l'exposant ÉNORME fait la laque, le genou la couche.
    float3 V = float3(0.0, 0.0, 1.0);
    float3 H1 = normalize(normalize(float3(-0.52, -0.66, 0.54)) + V);
    float3 H2 = normalize(normalize(float3(0.46, 0.60, 0.46)) + V);
    float spec = pow(max(dot(nrm, H1), 0.0), 160.0) * 1.25
               + pow(max(dot(nrm, H2), 0.0), 70.0) * 0.32;
    spec = spec / (1.0 + 0.55 * spec);

    // La laque : un orange braise PROFOND — sombre, mais jamais désaturé.
    float3 lacquer = float3(0.330, 0.085, 0.014)
                   + pwall * pow(pupleft, 2.4) * float3(0.06, 0.020, 0.005);
    float gin = smoothstep(0.030, -0.030, dg);
    rgb = mix(rgb, lacquer + spec * float3(1.00, 0.88, 0.72) * 1.20, gin);

    // ---- la lampe -------------------------------------------------------
    // Deux horloges incommensurables + le souffle partagé de la carte ; le
    // boost de la cérémonie pousse l'inspiration par-dessus.
    float a1 = 0.5 + 0.5 * sin(t * 2.42);
    float a2 = 0.5 + 0.5 * sin(t * 1.49 + 2.1);
    float lvl = 0.42 + 0.22 * a1 + 0.12 * a2 + 0.34 * souffle;
    float amp = clamp(lvl + 0.55 * boost, 0.0, 1.35);
    // Le cœur de la lampe suit le CŒUR GRAVÉ : c'est lui la mèche.
    float dn = d / 0.9;
    float core = smoothstep(0.10, -0.42, dn);
    float meche = smoothstep(0.10, -0.16, dc);
    // Le blanc reste un SOMMET, pas un état : la laque doit rester ORANGE —
    // une mèche blanche en continu lit « bougie », pas « bijou ».
    float blanc = clamp(0.10 + 0.28 * a2 + 0.60 * boost, 0.0, 1.0);
    float3 chaud = float3(1.00, 0.42, 0.06);
    float3 blancChaud = float3(1.00, 0.90, 0.68);
    float3 fire = mix(chaud, blancChaud, blanc * (0.30 * core + 0.42 * meche));
    float lampe = clamp(amp * (0.30 + 0.80 * core + 0.55 * meche), 0.0, 1.0);
    // Fondu écran, jamais une addition.
    rgb = 1.0 - (1.0 - rgb) * (1.0 - fire * (lampe * gin));
    // La nappe : le galet s'éclaire PAR sa flamme, et va mourir au bord.
    float bleed = exp(-max(dn, 0.0) / 0.85) * (1.0 - gin);
    rgb = 1.0 - (1.0 - rgb)
              * (1.0 - chaud * (bleed * (0.16 + 0.20 * souffle + 0.25 * boost)));

    // Prémultiplié : la leçon du fond clair — l'alpha multiplie TOUT.
    float a = aGalet;
    return half4(half3(rgb * a), a);
}
