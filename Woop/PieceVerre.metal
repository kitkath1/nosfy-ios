#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - LA PIÈCE DE VERRE (chantier coffre v2, jalon C4)
//
// L'OBJET N'EST PAS UNE PIÈCE DE MÉTAL, et c'est tout le malentendu qu'on
// vient de payer. `moonCoin` dessine un palet d'or : anneau poli opaque, laque,
// croissant posé dessus. La référence de Kathryn (son propre rendu,
// `Liquid_pièces.mp4`) montre autre chose : **un CABOCHON DE VERRE ÉPAIS,
// transparent, avec un disque noir suspendu dedans et le croissant gravé sur
// ce disque**. On voit à travers le bourrelet ; on voit le bord ARRIÈRE par
// transparence à travers le bord avant. Aucun réglage de `moonCoin` ne pouvait
// y mener — c'est un autre objet, il lui faut son shader.
//
// LES COTES SONT MESURÉES, PAS CHOISIES. Profil radial de la référence en 4K
// natif (`tools/coffre-v2/compare_piece.py ref`, anneaux de 1,15/26) :
//
//   r/R        L    sat    haut     bas     lecture
//   0,00-0,60  0,7→20  0,75-1,00           LA FACE — noire, le croissant y vit
//   0,64      21,9   0,47                  la lèvre intérieure
//   0,69      31,4   0,04   36,2   36,7    le tore commence — NEUTRE
//   0,73      61,1   0,01   93,9   49,3    la montée, éclairée par le HAUT
//   0,77      73,6   0,01  104,7   65,8    ★ ARC 1 — le sommet
//   0,82      57,8   0,02   83,0   45,6
//   0,86      58,1   0,03   58,2   61,1
//   0,91      32,9   0,04   39,4   27,7    ★ LA GORGE — le creux
//   0,95      55,4   0,01   49,7   65,9    ★ ARC 2 — éclairé par le BAS
//   1,00      45,5   0,01   41,1   54,0    le bord extérieur
//   1,04       9,3   0,02                  il meurt
//
// Trois faits qui commandent tout le shader :
//  1. **Le tore occupe 38 % du rayon** (0,62 → 1,00). C'est énorme : c'est
//     l'épaisseur du verre qu'on regarde par la tranche, pas un liseré.
//  2. **Il est NEUTRE** (sat 0,01-0,04) sur la pièce de verre, alors que la
//     face est saturée à 0,75-1,00 (le néon). Le verre ne colore rien : il
//     transporte de la lumière blanche.
//  3. **Les deux arcs n'ont pas la même source** : le premier est dominé par
//     le HAUT (105 contre 66), le second par le BAS (66 contre 50). C'est la
//     signature d'un tore transparent : la clé frappe le dessus, et le
//     dessous renvoie sa réflexion interne. Un seul spéculaire ne sait pas
//     produire ça.
//
// La pièce d'OR est le MÊME objet : même profil, même géométrie, mais le verre
// est teinté ambre (sat 0,30-0,47) et rend un peu plus (L 44→82 contre 31→74).

constant float PV_PH = 6.2831853 / 900.0;

/// La même softbox que tout le reste de l'app — le monolithe, la pièce d'or,
/// la nuit de la home. Deux objets éclairés par deux lampes ne peuvent pas
/// cohabiter dans une page.
constant float2 PV_KEY = float2(-0.5299, -0.8480);

/// Une gaussienne, en unités de `u` (la traversée du tore).
static inline float pvArc(float u, float centre, float largeur) {
    const float x = (u - centre) / max(largeur, 1e-4);
    return exp(-x * x);
}

/// `knobs` = (rimIn, moonFit, teinte, **tangage**).
///   rimIn   : où finit la face et où commence le verre — MESURÉ à 0,62.
///   teinte  : 0 = verre neutre · 1 = verre ambre (la pièce d'or).
///   tangage : en radians, ajouté au tangage de repos. C'est LUI qui donne
///             l'ellipse de la référence (ratio 0,902 → 25,6°).
[[ stitchable ]] half4 pieceVerre(float2 position, half4 color,
                                  float2 size, float t,
                                  float2 tilt, float userYaw,
                                  float coinR, float reveal,
                                  float idleLife,
                                  float3 sdfRanges, float3 moonPlace,
                                  float4 knobs,
                                  texture2d<half> moonSDF) {
    constexpr sampler kFace(address::clamp_to_edge, filter::linear,
                            coord::normalized);

    const float2 pC = position - size * 0.5;

    // ------------------------------------------------------------------
    // LA PROJECTION — reprise VERBATIM de `moonCoin`
    // ------------------------------------------------------------------
    // Elle est exacte et elle est payée : la silhouette d'un cylindre en lacet
    // se résout en fermé parce que `|A − B·z| − R` est CONVEXE en z, donc son
    // minimum sur l'épaisseur est le projeté borné. Aucune tranche, aucun
    // festonnage, et c'est ce qui permettra à la pièce de se RETOURNER sans
    // qu'aucune approximation ne lâche à 90°.
    const float live = 1.0;
    float yaw = 0.052 + userYaw
              + (0.0130 * sin(PV_PH * 11.0 * t + 0.7)
               + 0.0068 * sin(PV_PH * 29.0 * t + 2.9)
               + 0.055 * tilt.x) * live
              + idleLife * (0.058 * sin(PV_PH * 140.0 * t + 0.4)
                          + 0.030 * sin(PV_PH * 93.0 * t + 2.2));
    // ⚠️ LE TANGAGE EST PILOTÉ, ET C'EST LA CORRECTION LA PLUS IMPORTANTE DU
    // PREMIER TOUR. La référence montre une ellipse **plus large que haute**
    // (ratio mesuré 0,902) : on regarde la pièce **d'au-dessus**, donc c'est
    // l'axe VERTICAL qui est comprimé — un TANGAGE. Le premier jet ne pilotait
    // que le lacet et rendait un cercle (ratio 1,018) : la note est tombée à
    // 2,66/10 avant même qu'on parle de matière. On ne juge pas une matière sur
    // une pose fausse.
    float pitch = -0.045 + knobs.w
                + (0.0060 * sin(PV_PH * 17.0 * t + 1.3)
                            + 0.030 * tilt.y) * live
                + idleLife * 0.014 * sin(PV_PH * 77.0 * t + 1.1);

    const float cyw = cos(yaw), syw = sin(yaw);
    const float cpt = cos(pitch), spt = sin(pitch);

    const float3 EX3 = float3(cyw, syw * spt, -syw * cpt);
    const float3 EY3 = float3(0.0, cpt, spt);
    const float3 EZ3 = float3(syw, -cyw * spt, cyw * cpt);
    const float2 Ex = EX3.xy, Ey = EY3.xy, Ez = EZ3.xy;

    // ⚠️ LE DÉTERMINANT S'ANNULE À 90°. `Ex.x·Ey.y = cos(yaw)·cos(pitch)` : au
    // passage par la tranche il tombe à zéro et l'inverse explose. Le `max`
    // borne la casse, mais c'est la SORTIE ANTICIPÉE plus bas qui décide du
    // rendu à cet instant — c'est le point à filmer au banc, pas à supposer.
    const float invDet = 1.0 / max(Ex.x * Ey.y - Ey.x * Ex.y, 1e-5);
    const float2 iR0 = float2(Ey.y, -Ey.x) * invDet;
    const float2 iR1 = float2(-Ex.y, Ex.x) * invDet;

    // L'ÉPAISSEUR. Bien plus qu'une pièce de métal (0,088 R) : la référence
    // montre un cabochon, un galet de verre. Mesuré sur son rendu : le
    // bourrelet fait 38 % du rayon en projection, ce qui demande une
    // demi-épaisseur de l'ordre de 0,22 R pour que la tranche se voie ainsi.
    const float hD = coinR * 0.220;

    const float2 A = float2(dot(iR0, pC), dot(iR1, pC));
    const float2 B = float2(dot(iR0, Ez), dot(iR1, Ez));

    const float bb = max(dot(B, B), 1e-6);
    const float zs = clamp(dot(A, B) / bb, -hD, hD);
    const float dSil = length(A - B * zs) - coinR;

    // Le verre pose une lueur plus large que le métal (il la transporte), mais
    // elle reste bornée : une pièce POSE sa lumière, elle n'inonde pas.
    const float reach = coinR * 0.34;
    if (dSil > reach) { return half4(0.0); }

    const float2 pF = A - B * hD;
    const float rF = length(pF);
    const float dFace = rF - coinR;

    const float faceMask = smoothstep(0.55, -0.55, dFace);
    const float bodyCov = smoothstep(0.60, -0.60, dSil);

    const float2 rd = (rF > 1e-4) ? pF / rF : float2(1.0, 0.0);
    const float rN = rF / max(coinR, 1e-3);

    float3 col = float3(0.0);
    float alpha = 0.0;

    // ------------------------------------------------------------------
    // LES DEUX LAMPES
    // ------------------------------------------------------------------
    // La clé en haut à gauche (celle de toute l'app) et le RENVOI du bas.
    // Le tore de la référence porte deux arcs de sources différentes : sans la
    // seconde lampe, on n'obtient qu'un croissant clair et le verre retombe en
    // demi-lune morte — la leçon est déjà écrite dans `moonCoin`.
    const float3 L1 = normalize(float3(PV_KEY.x, PV_KEY.y, 0.62));
    const float3 L2 = normalize(float3(0.22, 0.88, 0.42));
    const float3 V = float3(0.0, 0.0, 1.0);
    const float3 H1 = normalize(L1 + V);
    const float3 H2 = normalize(L2 + V);

    // ------------------------------------------------------------------
    // LA TEINTE — le verre neutre, et le verre ambre
    // ------------------------------------------------------------------
    // MESURÉ : sur la pièce de verre le bourrelet est à sat 0,01-0,04 (il ne
    // colore RIEN), sur la pièce d'or à sat 0,30-0,47 — et dans les DEUX cas
    // les hautes lumières montent au blanc (253,253,253 et 254,253,242). La
    // teinte vit donc dans les DEMI-TEINTES, jamais dans le pic : un verre
    // teinté n'est pas un métal doré, c'est un filtre que la lumière traverse.
    const float teinte = clamp(knobs.z, 0.0, 1.0);
    const float3 VERRE  = mix(float3(0.780, 0.790, 0.800),
                              float3(0.980, 0.660, 0.300), teinte);
    const float3 VERRE_H = mix(float3(1.000, 1.000, 1.000),
                               float3(1.000, 0.965, 0.870), teinte);

    // ------------------------------------------------------------------
    // LE TORE DE VERRE — le sujet
    // ------------------------------------------------------------------
    const float rimIn = clamp(knobs.x, 0.40, 0.90);
    if (faceMask > 0.001 && rN > rimIn - 0.05) {
        // `u` traverse le bourrelet : 0 à la lèvre intérieure, 1 au bord.
        const float u = clamp((rN - rimIn) / max(1.0 - rimIn, 1e-3), 0.0, 1.0);

        // LA SECTION EST UN DEMI-TORE. L'angle de la section balaie 180° d'un
        // bord à l'autre : c'est LUI qui fait tourner la normale et courir les
        // reflets. Un bourrelet plat n'a qu'une normale, donc une seule valeur,
        // donc pas d'arc.
        const float th = u * 3.14159265;
        const float s = -cos(th);              // −1 dedans → +1 dehors
        const float nz = max(sin(th), 0.02);   // le dessus du bourrelet

        const float3 N = normalize(EX3 * (rd.x * s) + EY3 * (rd.y * s)
                                   + EZ3 * nz);
        const float ndv = clamp(dot(N, V), 0.0, 1.0);
        const float sp1 = pow(clamp(dot(N, H1), 0.0, 1.0), 46.0);
        const float sp2 = pow(clamp(dot(N, H2), 0.0, 1.0), 30.0);
        const float wr1 = pow(clamp(dot(N, H1), 0.0, 1.0), 7.0);
        const float wr2 = pow(clamp(dot(N, H2), 0.0, 1.0), 5.0);

        // LE FRESNEL D'UN VERRE, et il est bien plus fort que celui d'un
        // métal : c'est ce qui allume le pourtour là où aucune lampe ne
        // frappe, et c'est la moitié de la lecture « transparent ».
        const float fres = pow(1.0 - ndv, 2.6);

        // LES TROIS TERMES RADIAUX, CALÉS SUR LA MESURE. Ils portent la
        // structure que les lampes seules ne savent pas produire — les
        // caustiques d'un tore ne sont pas un spéculaire, ce sont des
        // réflexions internes, et leur place est une propriété de la
        // GÉOMÉTRIE. On les pose donc où la référence les montre.
        const float arc1  = pvArc(u, 0.39, 0.115);   // r/R 0,77
        const float gorge = pvArc(u, 0.76, 0.085);   // r/R 0,91
        const float arc2  = pvArc(u, 0.87, 0.075);   // r/R 0,95

        // ⚠️⚠️ **LE VERRE EST NOIR, ET C'EST TOUTE LA LEÇON DU PREMIER TOUR.**
        // Histogramme du tore de la référence, sur 170 568 pixels :
        //     L   0-10  →  45,0 %      ← ON VOIT LE FOND À TRAVERS
        //     L  10-30  →  16,0 %
        //     L  30-60  →  11,3 %
        //     L  60-100 →   7,7 %
        //     L 100-160 →   7,6 %
        //     L 160-220 →   7,5 %
        //     L 220-255 →   5,1 %
        //     médiane 14 · moyenne 51 · p90 183 · p99 254
        //
        // Autrement dit : **la moitié du bourrelet est NOIRE**, et sa moyenne
        // de 51 n'est due qu'aux 12 % de pixels très clairs — de FINES LIGNES.
        // Un verre transparent ne renvoie pas de la lumière partout : il la
        // CONCENTRE en caustiques et laisse passer le reste.
        //
        // Mon premier jet posait une base de 0,30 + un Fresnel de 0,86 sur
        // TOUT l'anneau : un bol de porcelaine blanche opaque, médiane ~200.
        // Il n'y a pas de réglage qui rattrape ça — il fallait retirer la
        // base, pas la baisser.
        //
        // LA LOI QUI EN SORT : **rien de constant sur le bourrelet.** Chaque
        // terme est soit angulairement concentré (haut/bas), soit radialement
        // fin (une gaussienne étroite). Les flancs gauche et droit tombent à
        // presque zéro, et c'est ça qui fait lire « on voit à travers ».

        // ★ ARC 1 — dominé par le HAUT (mesuré 105 contre 66 sur la référence).
        // L'exposant 3,0 (et non 1,15) est ce qui ÉTEINT les flancs : à 90° de
        // la verticale il ne reste plus rien.
        const float haut = pow(max(-rd.y, 0.0), 3.0);
        // ★ ARC 2 — la réflexion interne du dessous (66 contre 50) : plus
        // douce, plus basse, mais tout aussi concentrée.
        const float bas  = pow(max(rd.y, 0.0), 2.6);

        // LE LISERÉ DE BORD. Le Fresnel d'un verre allume son contour — mais
        // c'est une LIGNE, pas une nappe : une gaussienne étroite au bord.
        const float liseré = pvArc(u, 1.00, 0.085);

        float3 verre =
              VERRE_H * (2.30 * sp1 + 0.95 * sp2)          // les deux lampes
            + VERRE_H * (2.05 * arc1 * haut)               // ★ la caustique du haut
            + VERRE   * (1.35 * arc2 * bas)                // ★ celle du bas
            + VERRE   * (0.62 * wr1 * haut + 0.42 * wr2 * bas)
            + VERRE   * (0.85 * fres * liseré)             // le contour, en ligne
            + VERRE   * (0.10 * (haut + bas));             // le pied, jamais constant

        // LA GORGE : un sillon, donc une OMBRE — jamais un trait noir peint.
        verre *= 1.0 - 0.52 * gorge;

        // LA TRANSPARENCE — et c'est elle qui fait lire « verre » plutôt que
        // « anneau clair ». Sur la référence on voit le bord ARRIÈRE à travers
        // le bord avant : en bas du cabochon, un second arc court À
        // L'INTÉRIEUR de la bande. Un tore est une surface de révolution, donc
        // son bord arrière se projette au MÊME rayon mais à l'angle opposé :
        // on rejoue donc la caustique au point antipodal, atténuée, et l'objet
        // devient traversable.
        const float hautA = pow(max(rd.y, 0.0), 3.0);
        verre += VERRE * (0.55 * arc1 * hautA);

        const float bande = smoothstep(rimIn - 0.030, rimIn + 0.030, rN);
        col = mix(col, verre, bande * faceMask);
        // ⚠️ L'ALPHA SUIT LA LUMIÈRE, PAS LA GÉOMÉTRIE. Un bourrelet
        // transparent ne couvre pas ce qu'il y a derrière : là où il est noir,
        // il doit être VIDE (le fond passe), pas peint en noir. C'est la même
        // règle que le prémultiplié en bas de fichier, et c'est ce qui
        // permettra au verre natif et au sol de la chambre de se voir à
        // travers la pièce.
        alpha = max(alpha, bande * faceMask
                    * clamp(max(verre.r, max(verre.g, verre.b)), 0.0, 1.0));
    }

    // ------------------------------------------------------------------
    // LA FACE — le disque noir SUSPENDU DANS le verre
    // ------------------------------------------------------------------
    if (faceMask > 0.001 && rN < rimIn + 0.03) {
        // MESURÉ : la face de la référence tient entre L 0,7 et L 20, et sa
        // saturation est celle du NÉON (0,75 à 1,00) — autrement dit, tout ce
        // qui s'y voit vient du croissant. Le fond est un vrai noir, pas un
        // gris. Un disque « sombre mais habité » ferait un palet de métal.
        // ⚠️ **CETTE FACE EST UN TROU NOIR, ET LE PREMIER TOUR L'AVAIT RATÉE
        // D'UN FACTEUR DIX.** Mesuré au centre de la référence : **L 0,7 sur
        // 255**. Pas « sombre » : NOIR. Tout ce qu'on lit dans ce disque vient
        // du croissant (saturation 0,75 à 1,00 sur tout le rayon — c'est la
        // signature d'une seule source orange, et de rien d'autre). Mon
        // premier jet sortait à 0,116 en normalisé contre 0,010 : une laque
        // habitée, un dôme large, un renvoi de bourrelet — trois clartés qui
        // n'existent pas chez elle et qui, ensemble, faisaient un palet.
        float3 laque = float3(0.0022, 0.0021, 0.0024);

        // LE DÔME, RÉDUIT AU SOUFFLE. Il existe sur la référence (le dessus
        // bombé du cabochon prend le ciel) mais il vit à L 10-25 dans le HAUT
        // de la face, pas sur tout le disque. Étroit, faible, et haut.
        const float2 vk = pF / max(coinR, 1e-3) - PV_KEY * 0.52;
        const float dome = exp(-dot(vk, vk) * 3.40);
        laque += mix(float3(0.020, 0.021, 0.024),
                     float3(0.024, 0.019, 0.014), teinte) * dome;

        // Le rejaillissement du bourrelet : court, carré, et trois fois plus
        // discret qu'au premier tour.
        const float renvoi = smoothstep(rimIn - 0.30, rimIn - 0.02, rN);
        laque += VERRE * (0.018 * renvoi * renvoi);

        const float dedans = smoothstep(rimIn + 0.020, rimIn - 0.020, rN);
        col = mix(col, laque, dedans * faceMask);
        alpha = max(alpha, dedans * faceMask);
    }

    // ------------------------------------------------------------------
    // LA TRANCHE — l'épaisseur du galet
    // ------------------------------------------------------------------
    const float flank = clamp(bodyCov - faceMask, 0.0, 1.0);
    if (flank > 0.001) {
        const float2 pS = A - B * zs;
        const float2 sd = normalize(pS + 1e-5);
        const float3 N = normalize(EX3 * sd.x + EY3 * sd.y);
        const float ndv = clamp(dot(N, V), 0.0, 1.0);
        const float sp = pow(clamp(dot(N, H1), 0.0, 1.0), 38.0);
        const float wr = pow(clamp(dot(N, H1), 0.0, 1.0), 6.0);
        // Un chant de VERRE est un guide de lumière : son Fresnel est
        // dominant, et c'est lui qui l'allume tout autour.
        const float fres = pow(1.0 - ndv, 2.0);

        float3 chant = VERRE * (0.16 + 0.52 * wr + 0.78 * fres)
                     + VERRE_H * (1.05 * sp);
        col = mix(col, chant, flank);
        alpha = max(alpha, flank);
    }

    // ------------------------------------------------------------------
    // LE CROISSANT — gravé dans la laque, jamais posé dessus
    // ------------------------------------------------------------------
    const float moonFit = clamp(knobs.y, 0.30, 1.20);
    const float halfFace = coinR * moonFit;
    const float padding = sdfRanges.x, tightR = sdfRanges.y, wideR = sdfRanges.z;
    const float2 uv = (pF / (2.0 * halfFace) + 0.5 - moonPlace.xy)
                      / (padding * moonPlace.z) + 0.5;
    const float2 uvc = clamp(uv, 0.0, 1.0);
    const half4 msdf = moonSDF.sample(kFace, uvc);
    const float dOutUc = length(uv - uvc) * padding;
    const float ucToPt = moonPlace.z * 2.0 * halfFace;
    float dT = ((float(msdf.r) - 0.5) * 2.0 * tightR + dOutUc) * ucToPt;
    float dW = ((float(msdf.g) - 0.5) * 2.0 * wideR + dOutUc) * ucToPt;
    const float dMoon = mix(dT, dW,
        smoothstep(0.55, 0.95, fabs(dT) / max(tightR * ucToPt, 1e-3)));

    // Le tube. La référence le montre FIN et net, avec ses hachures internes
    // lisibles : le trait ne doit pas s'empâter.
    const float tube = max(coinR * 0.021, 0.75);
    const float aTube = fabs(dMoon);
    const float coeur = exp(-pow(aTube / (tube * 0.40), 2.0));
    const float gaine = exp(-pow(aTube / (tube * 1.10), 2.0));
    const float lueur = exp(-aTube / (tube * 1.30));

    const float souffle = 1.0 + 0.180 * sin(PV_PH * 180.0 * t + 1.7)
                              + 0.055 * sin(PV_PH * 53.0 * t + 4.2)
                              + 0.030 * sin(PV_PH * 101.0 * t + 0.6);
    const float voyage = 0.72 + 0.55 * pow(max(sin(atan2(pF.y, pF.x)
                                    - PV_PH * 260.0 * t), 0.0), 3.0);

    const float3 NEON_COEUR = float3(1.000, 0.930, 0.780);
    const float3 NEON = float3(1.000, 0.520, 0.105);
    const float allume = reveal * souffle;
    float3 neon = NEON_COEUR * (coeur * 1.30 * voyage)
                + NEON * (gaine * 0.92 + lueur * 0.30);
    neon *= allume;

    const float surFace = faceMask
        * smoothstep(rimIn + 0.005, rimIn - 0.030, rN);
    col += neon * surFace;
    alpha = max(alpha, clamp(max(neon.r, max(neon.g, neon.b)), 0.0, 1.0)
                       * surFace);

    // LE BAIN. Sans lui le croissant est un autocollant sur un disque ; c'est
    // ce bain qui le met DEDANS la pièce.
    // ⚠️ MAIS IL EST COURT. Mesuré sur la face de la référence : **52 % de ses
    // pixels sont sous L 3** et sa médiane est à **2,7**. La saturation de
    // 0,75 qu'on lit partout ne dit pas que la face est baignée d'orange —
    // elle dit que le PEU qui s'y trouve est orange. Mon premier bain à 0,42 R
    // rendait un disque BRUN ; il tombe à 0,17 R, et le noir revient.
    const float bain = exp(-max(aTube - tube, 0.0) / (coinR * 0.17));
    col += NEON * (0.105 * bain * allume * faceMask);

    // ------------------------------------------------------------------
    // LE BLOOM
    // ------------------------------------------------------------------
    {
        const float out01 = max(dSil, 0.0);
        const float pres = exp(-out01 / (coinR * 0.050));
        const float loin = exp(-out01 / (coinR * 0.130));
        const float3 bloom = VERRE * (0.42 * pres + 0.030 * loin)
                           + NEON * (0.022 * loin * allume);
        col += bloom * (1.0 - bodyCov);
        alpha = max(alpha, (0.42 * pres + 0.036 * loin) * (1.0 - bodyCov));
    }

    if (alpha < 0.0015) { return half4(0.0); }

    const float2 toEdge = min(position, size - position);
    const float hostFade = smoothstep(0.0, 12.0, min(toEdge.x, toEdge.y));

    // Le piège du prémultiplié : l'alpha d'une lumière émissive EST sa propre
    // intensité, sinon le `min` final écrête un canal et le halo se désature.
    col = max(col, 0.0);
    alpha = clamp(max(alpha, max(col.r, max(col.g, col.b))), 0.0, 1.0);

    alpha *= hostFade;
    col *= hostFade;
    return half4(half3(min(col, float3(alpha))), half(alpha)) * color.a;
}
