#include <metal_stdlib>
#include "NeonIconsData.h"
using namespace metal;

// MARK: - Les trois icônes néon (banc `-iconLab`)
//
// Chocolat, bras, pêche : trois corps de VERRE NOIR posés sur une nuit noire,
// révélés par la seule lumière qu'ils reflètent. Rien n'est peint : le liseré
// rasoir, les glissés de laque et les points chauds sortent tous du même
// calcul — silhouette exacte, relief, environnement.
//
// MESURÉ SUR LES RÉFÉRENCES (planches 1254 px, luminance perceptuelle) :
//  - la lumière est BLANCHE et froide (saturation 0,016 à 0,041) ;
//  - moins de 1 % des pixels dépassent 128 — le noir fait tout le travail ;
//  - le liseré fait 3 à 4 px de largeur à mi-hauteur, soit 0,3 % du côté ;
//  - le halo hors silhouette est un MURMURE : 1,8/255 au ras du corps,
//    éteint à 64 px. Ce n'est pas un bloom, c'est une buée.
//
// DEUX PIÈGES PAYÉS :
//  1. au seuil du bruit (2/255) le halo s'étend sur 30 à 45 px et gonfle tout
//     masque tracé d'autant — les silhouettes de NeonIconsData.h sont calées
//     sur la CRÊTE du liseré, pas sur le pied du halo ;
//  2. faire le GALBE avec la distance au polygone strie l'objet d'un éventail
//     par sommet (220 sommets, 220 plis). Le SDF ne sert qu'au BISEAU du bord,
//     sur une bande étroite ; le galbe est analytique, donc lisse par nature.
//
// Repère : origine au centre de la planche, y vers le haut, demi-côté = 1.

// MARK: Distance signée à un polygone, avec sa pente
//
// Renvoie float3(distance signée, gradient x, gradient y). Le gradient est
// unitaire et pointe vers l'EXTÉRIEUR : il donne la normale du biseau sans
// re-échantillonner le SDF (une évaluation par pixel, pas cinq — sur 220
// segments la différence n'est pas discutable).
static float3 sdPolyG(float2 p, constant float2 *v, int n) {
    float2 w0 = p - v[0];
    float dd = dot(w0, w0);
    float2 bmin = w0;
    float s = 1.0;
    for (int i = 0, j = n - 1; i < n; j = i, i++) {
        float2 e = v[j] - v[i];
        float2 w = p - v[i];
        float2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
        float q = dot(b, b);
        if (q < dd) { dd = q; bmin = b; }
        bool3 c = bool3(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
        if (all(c) || all(!c)) s = -s;
    }
    float d = s * sqrt(max(dd, 1e-20));
    float2 g = s * normalize(bmin + float2(1e-9));
    return float3(d, g);
}

/// Distance non signée à une polyligne — les plis intérieurs.
static float sdLigne(float2 p, thread const float2 *v, int n) {
    float dd = 1e9;
    for (int i = 0; i < n - 1; i++) {
        float2 e = v[i + 1] - v[i];
        float2 w = p - v[i];
        float2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
        dd = min(dd, dot(b, b));
    }
    return sqrt(dd);
}

// MARK: Le biseau du bord
//
// Un quart de cercle : la peau se relève sur une bande étroite. On ne garde
// que sa PENTE — c'est elle qui couche la normale et allume le fil.
static float penteBiseau(float t, float R) {
    float u = clamp(t / R, 0.0, 1.0);
    float h = sqrt(max(2.0 * u - u * u, 1e-6));
    return (1.0 - u) / (h * R);
}

// MARK: Le galbe analytique
//
// Une calotte : hauteur A au centre, plate au bord. On en rend le GRADIENT,
// jamais la hauteur — seul le gradient entre dans la normale.
static float2 gradCalotte(float2 p, float2 c, float2 r, float A) {
    float2 q = (p - c) / r;
    float s = dot(q, q);
    if (s >= 1.0) return float2(0.0);
    float z = sqrt(max(1.0 - s, 1e-4));
    return -A * q / (r * z);
}

/// Le gradient d'un sillon gaussien creusé le long d'une polyligne.
static float2 gradSillon(float2 p, thread const float2 *v, int n,
                         float largeur, float profondeur) {
    // Gradient par différences centrées : le sillon est court, deux
    // évaluations de plus ne coûtent rien ici.
    float e = 0.004;
    float d0 = sdLigne(p, v, n);
    float dx = sdLigne(p + float2(e, 0), v, n) - sdLigne(p - float2(e, 0), v, n);
    float dy = sdLigne(p + float2(0, e), v, n) - sdLigne(p - float2(0, e), v, n);
    float u = d0 / largeur;
    float f = -profondeur * 2.0 * u * exp(-u * u) / largeur;   // d/dd de -P·e^(-u²)
    return f * float2(dx, dy) / (2.0 * e);
}

// MARK: L'environnement
//
// Le monde que le verre reflète : un studio NOIR percé de quelques nappes.
// Vue de face, la laque ne reflète que du noir — c'est la condition du
// premium. La lumière n'apparaît qu'aux angles rasants et sous les nappes.
static float envLum(float3 R) {
    float e = 0.0;

    // La grande nappe haut-gauche : c'est elle qu'on voit glisser sur le galbe.
    float3 cle = normalize(float3(-0.42, 0.80, 0.43));
    e += 1.05 * smoothstep(0.80, 0.985, dot(R, cle));

    // Le retour bas-droite, plus serré et plus froid.
    float3 ret = normalize(float3(0.66, -0.62, 0.42));
    e += 0.55 * smoothstep(0.88, 0.995, dot(R, ret));

    // L'HORIZON : une couronne de lumière au ras du monde. C'est elle, et
    // elle seule, qui fait le fil de l'arête — sur tout le tour, modulée par
    // l'azimut pour que le liseré vive au lieu de cercler bêtement l'objet.
    float hz = smoothstep(0.55, 0.02, abs(R.z));
    float2 a = normalize(R.xy + float2(1e-9));
    float vers = 0.5 + 0.5 * dot(a, normalize(float2(-0.40, 0.92)));
    e += 1.25 * hz * (0.22 + 0.78 * vers * vers);

    return e;
}

// MARK: sRGB
static half3 versSRGB(float3 lin) {
    float3 c = clamp(lin, 0.0, 1.0);
    float3 s = mix(12.92 * c, 1.055 * pow(max(c, 1e-8), 1.0 / 2.4) - 0.055,
                   step(0.0031308, c));
    return half3(s);
}

// MARK: Les reliefs, icône par icône
//
// Chaque icône rend le GRADIENT de son galbe intérieur. Le biseau du bord,
// lui, est commun : il sort du SDF de la silhouette.

/// La pêche : deux joues séparées d'un sillon, la feuille et la queue.
static float2 galbePeche(float2 p) {
    float2 sillon[8] = {
        float2( 0.030,  0.400), float2( 0.160,  0.250), float2( 0.260,  0.050),
        float2( 0.300, -0.100), float2( 0.280, -0.250), float2( 0.220, -0.380),
        float2( 0.150, -0.500), float2( 0.100, -0.600),
    };
    float2 feuille[4] = {
        float2( 0.090,  0.430), float2( 0.280,  0.520), float2( 0.450,  0.570),
        float2( 0.600,  0.600),
    };
    float2 queue[3] = {
        float2( 0.030,  0.400), float2(-0.010,  0.520), float2(-0.055,  0.610),
    };

    float2 g = gradCalotte(p, float2(0.005, -0.060), float2(0.680, 0.560), 0.150);
    g += gradSillon(p, sillon, 8, 0.055, 0.045);
    g += gradCalotte(p, float2(0.345, 0.515), float2(0.290, 0.115), 0.030);
    g += gradSillon(p, feuille, 4, 0.030, 0.012);
    g += gradSillon(p, queue, 3, 0.028, 0.014);
    return g;
}

/// Le bras : avant-bras, biceps, poing — trois galbes et leurs plis.
static float2 galbeBras(float2 p) {
    float2 pliCoude[5] = {
        float2(-0.150,  0.360), float2(-0.120,  0.150), float2(-0.100, -0.050),
        float2(-0.080, -0.200), float2(-0.040, -0.330),
    };
    float2 poignet[3] = {
        float2(-0.300,  0.430), float2(-0.150,  0.420), float2(-0.020,  0.400),
    };
    float2 g = gradCalotte(p, float2(-0.360, 0.080), float2(0.300, 0.560), 0.130);
    g += gradCalotte(p, float2(0.180, -0.320), float2(0.470, 0.330), 0.150);
    g += gradCalotte(p, float2(-0.120, 0.600), float2(0.330, 0.220), 0.090);
    g += gradSillon(p, pliCoude, 5, 0.045, 0.040);
    g += gradSillon(p, poignet, 3, 0.040, 0.030);
    return g;
}

/// Le chocolat : la tablette rainurée, les rabats, le sachet.
static float2 galbeChocolat(float2 p) {
    float2 rainureV[2] = { float2(0.000, 0.660), float2(0.000, 0.060) };
    float2 rainureH[2] = { float2(-0.400, 0.360), float2(0.400, 0.360) };
    float2 rabat[3] = {
        float2(-0.520, 0.130), float2(0.000, -0.180), float2(0.520, 0.130),
    };
    float2 g = gradCalotte(p, float2(0.000, 0.380), float2(0.470, 0.330), 0.055);
    g += gradSillon(p, rainureV, 2, 0.030, 0.055);
    g += gradSillon(p, rainureH, 2, 0.030, 0.055);
    g += gradSillon(p, rabat, 3, 0.045, 0.050);
    return g;
}

// MARK: Le rendu

[[stitchable]] half4 neonIcon(float2 pos,
                              half4 color,
                              float2 size,
                              float time,
                              float icon)
{
    float demi = 0.5 * min(size.x, size.y);
    float2 p = (pos - 0.5 * size) / demi;
    p.y = -p.y;
    float px = 1.0 / demi;              // un pixel, dans les unités du repère

    float3 dg;
    float2 galbe;
    if (icon < 0.5) {
        dg = sdPolyG(p, kSilChocolat, kSilChocolatN);
        galbe = galbeChocolat(p);
    } else if (icon < 1.5) {
        dg = sdPolyG(p, kSilBras, kSilBrasN);
        galbe = galbeBras(p);
    } else {
        dg = sdPolyG(p, kSilPeche, kSilPecheN);
        galbe = galbePeche(p);
    }

    float d = dg.x;
    float2 g = dg.yz;
    float t = max(-d, 0.0);

    // Le biseau : une bande étroite au bord, et rien au-delà.
    float pente = min(penteBiseau(t, 0.026), 42.0);

    // ∇H = -pente·g (le biseau) + galbe. La normale : N ∝ (-∇H, 1).
    float2 gradH = -pente * g + galbe;
    float3 N = normalize(float3(-gradH, 1.0));
    float3 V = float3(0.0, 0.0, 1.0);
    float NoV = clamp(dot(N, V), 0.0, 1.0);
    float3 R = 2.0 * NoV * N - V;

    float F = 0.042 + 0.958 * pow(1.0 - NoV, 5.0);
    float env = envLum(R);

    // Le corps : une laque presque noire. Pas zéro — un noir absolu tue le
    // galbe et l'objet redevient une découpe.
    float corps = 0.0035;

    float dedans = 1.0 - smoothstep(-px, px, d);
    float lum = dedans * (F * env + corps);

    // Le halo : une buée, pas un bloom.
    lum += 0.0070 * exp(-max(d, 0.0) / 0.017);

    return half4(versSRGB(float3(lum)), 1.0h) * color.a;
}
