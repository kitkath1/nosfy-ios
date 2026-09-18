#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ============================================================================
// LE VERRE DU GALET — le cristal PEINT (bancs `-homeV2`, `-phraseLab`)
//
// Pourquoi un shader plutôt que le `glassEffect` natif, alors que le natif
// était magnifique : parce qu'une lentille ne montre QUE ce qu'elle réfracte,
// et qu'elle le DÉPLACE. Sur la page noire elle n'a rien à manger (surface
// mesurée à p95 = 23, « on voit rien ») ; nourrie d'un fantôme du chiffre elle
// redevient superbe (178) mais le déplacement fait un DOUBLE, et ce double est
// structurel — c'est la définition d'une lentille.
//
// Ici, rien n'est réfracté : le cristal est DESSINÉ. C'est l'école du galet du
// slider de séance (`galetMedaillon`), qui brille sur un fond blanc comme il
// brillerait sur du noir, parce qu'il invente sa lumière au lieu de
// l'emprunter. On y gagne aussi ce que le natif ne sait pas faire : la
// DISPERSION (le rouge et le bleu qui ne sortent pas au même endroit de
// l'arête), et un COL réglable au pixel — une union lisse de deux SDF, à la
// métaballe (l'école du lait de molette, aujourd'hui mort), au lieu d'un
// `spacing` de conteneur.
//
// PIÈGES DÉJÀ PAYÉS, RESPECTÉS ICI :
//   — l'arité : la signature doit matcher l'appel Swift AU FLOAT PRÈS, sinon
//     la page devient BLANCHE sans une seule erreur de compilation ;
//   — le CADRE FANTÔME : toute énergie meurt avant le bord de l'hôte (l'hôte
//     est padé de 34 pt, et l'alpha part de la couverture du SDF) ;
//   — jamais `.clear` sous un `colorEffect` : l'hôte est rempli de BLANC
//     opaque, c'est le shader qui décide de chaque alpha.
// ============================================================================

static inline float vgHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static inline float vgNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = vgHash(i), b = vgHash(i + float2(1, 0));
    float c = vgHash(i + float2(0, 1)), d = vgHash(i + float2(1, 1));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/// La distance signée à un rectangle arrondi.
static inline float vgRR(float2 p, float2 c, float2 b, float r) {
    float2 q = abs(p - c) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Le minimum LISSE : c'est lui, le tuyau. À `k` grand le col est gras, à `k`
/// petit les deux corps se séparent — et entre les deux il y a exactement la
/// forme qu'on veut (la pastille reste une pastille, un col la tient).
///
/// ⚠️ LE SEUIL, mesuré : le pont n'apparaît que si `k` dépasse environ **4×
/// l'écart** des deux surfaces. Au milieu d'un intervalle de 12 pt, les deux
/// distances valent 6 : `smin(6, 6, k) = 6 − k/4`, qui ne passe sous zéro qu'à
/// partir de k = 24. Avec k = 17 il ne se passe RIEN, et on croit le shader
/// cassé.
static inline float vgSmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

/// Le champ complet : le galet, le panneau, et leur union lisse.
static inline float vgField(float2 p, float4 gal, float2 pc, float2 pb,
                            float pr, float k) {
    float dG = vgRR(p, gal.xy, float2(gal.z), gal.w);
    float dP = vgRR(p, pc, pb, pr);
    return vgSmin(dG, dP, k);
}

/// `gal` = (centre x, centre y, demi-côté, rayon d'angle) du galet.
/// `pan` = (centre x, centre y, demi-largeur, demi-hauteur) du panneau OUVERT.
/// `mat` = (ouverture 0→1, brillance, épaisseur d'arête, dispersion).
/// `mat2` = (scintillement, lissage du col, dose des rubans, leur pas en pt).
[[ stitchable ]] half4 verreGalet(float2 position, half4 color,
                                  float2 size, float t,
                                  float4 gal, float4 pan,
                                  float4 mat, float4 mat2)
{
    float ouvert = clamp(mat.x, 0.0, 1.0);
    float brillance = mat.y;
    float epaisseur = max(mat.z, 0.6);
    float disp = mat.w;
    float scint = mat2.x;
    float k = max(mat2.y, 0.5) * (0.30 + 0.70 * ouvert);

    // LE PANNEAU NAÎT DU GALET : fermé, son centre est DANS le galet et ses
    // demi-tailles sont rétractées — il est donc invisible, avalé par l'union.
    // Il en sort en coulant. C'est ce que le conteneur natif ne savait pas
    // faire : là, l'ouverture est une matière qui s'étire, pas une vue qui
    // apparaît.
    float2 pc = mix(gal.xy, pan.xy, ouvert);
    float2 pb = float2(pan.z * mix(0.16, 1.0, ouvert),
                       pan.w * mix(0.28, 1.0, ouvert));
    float pr = min(pb.y, pan.w);

    float d = vgField(position, gal, pc, pb, pr, k);

    // La couverture, antialiasée sur un point.
    float aa = 1.0 - smoothstep(-0.7, 0.7, d);
    if (aa <= 0.002) { return half4(0.0h); }

    // La normale de surface, par différences finies sur le champ.
    float e = 0.8;
    float dx = vgField(position + float2(e, 0), gal, pc, pb, pr, k)
             - vgField(position - float2(e, 0), gal, pc, pb, pr, k);
    float dy = vgField(position + float2(0, e), gal, pc, pb, pr, k)
             - vgField(position - float2(0, e), gal, pc, pb, pr, k);
    float2 n = normalize(float2(dx, dy) + 1e-5);

    // Face à la lampe de la page : haut-gauche, comme TOUT le reste (loi 1).
    float lobe = 0.5 + 0.5 * dot(n, normalize(float2(-1.0, -1.15)));
    float dedans = max(-d, 0.0);

    // L'ARÊTE : une bande collée au bord intérieur. C'est la pièce maîtresse —
    // un verre, c'est d'abord un bord qui accroche la lumière.
    float bande = exp(-pow(dedans / epaisseur, 2.0));
    float spec = pow(lobe, 5.0) * bande * brillance;
    // LE POINT CHAUD : un spéculaire très dur par-dessus l'arête. C'est lui qui
    // fait ÉTINCELER — sans lui, l'arête est une lueur, pas un reflet.
    float dur = pow(lobe, 26.0) * bande * 0.85 * brillance;
    // LA CONTRE-LUMIÈRE : un filet ténu du côté OPPOSÉ. C'est ce qui sépare le
    // verre du métal peint — la lumière enveloppe un corps transparent.
    float contre = pow(1.0 - lobe, 9.0) * bande * 0.34 * brillance;
    // LA CAUSTIQUE : le trait clair qui court à l'intérieur, en retrait de
    // l'arête. C'est l'épaisseur du verre qui se voit.
    float caustique = exp(-pow((dedans - epaisseur * 2.1) / (epaisseur * 0.62),
                               2.0))
                    * pow(lobe, 3.0) * 0.55 * brillance;
    // ========================================================================
    // LES RUBANS DE CAUSTIQUE — LA PIÈCE QUI MANQUAIT.
    //
    // Mesuré : un éclairage qui ne dépend que de la distance au bord est
    // RADIALEMENT MONOTONE, donc il ne fait que des anneaux concentriques —
    // 3,0 alternances clair/sombre par ligne, contre 5,2 pour le verre natif
    // nourri. C'est toute la différence entre un galet mat verni et un
    // cristal : **un cristal n'est pas un bord éclairé, c'est une image
    // DÉFORMÉE vue à travers un corps.** Ce qu'on voit dans le natif, ce sont
    // les replis d'une forme claire pliée par la lentille : des rubans qui se
    // croisent, à bords durs, avec du NOIR entre eux.
    //
    // Ici on les peint : une phase qui monte avec l'épaisseur, TORDUE par
    // l'angle (deux harmoniques : c'est ça qui plie) et par un bruit très
    // basse fréquence, puis découpée en rubans à bords durs. Deux familles
    // d'échelles différentes qui se croisent — un seul train de rubans se lit
    // comme des rayures.
    // ========================================================================
    // PREMIER ESSAI, MESURÉ ET RATÉ : une phase en `dedans / pas` suit les
    // ISOLIGNES du SDF — donc des contours parallèles au bord, et le galet
    // sortait en CARTE TOPOGRAPHIQUE (12,5 alternances par ligne pour une
    // cible de 5). Ce n'est pas ce que montre un verre : un verre montre
    // l'image PLIÉE d'une source, c'est-à-dire deux ou trois rubans LARGES et
    // crémeux qui traversent le corps en ondulant, pas douze cheveux
    // concentriques.
    //
    // La bonne loi est donc une ONDE PLANE dans l'axe de la lampe, tordue par
    // une seconde onde en travers (c'est elle qui plie) et par un bruit très
    // basse fréquence. Bords DOUX (exposant 2,4 et non 6) : la largeur du
    // ruban fait la crème.
    float2 q = position - gal.xy;
    float2 dirA = normalize(float2(-1.0, -1.15));   // l'axe de la lampe
    float2 dirB = float2(-dirA.y, dirA.x);          // en travers
    float pas = max(mat2.w, 4.0);
    float ph1 = dot(q, dirA) / pas
              + 1.55 * sin(dot(q, dirB) / (pas * 1.55))
              + vgNoise(position * 0.03) * 0.7;
    float tri1 = abs(fract(ph1) - 0.5) * 2.0;
    float ruban1 = pow(1.0 - tri1, 2.4) * (0.30 + 0.70 * lobe);
    float ph2 = dot(q, dirB) / (pas * 1.7)
              - 1.15 * sin(dot(q, dirA) / (pas * 1.1)) + 2.1;
    float tri2 = abs(fract(ph2) - 0.5) * 2.0;
    float ruban2 = pow(1.0 - tri2, 3.4) * (0.22 + 0.78 * lobe) * 0.45;
    float rubans = (ruban1 + ruban2) * mat2.z * brillance;

    // LE CORPS : le verre a une matière, pas seulement un bord. Mesuré à 0,11,
    // la surface plafonnait à p95 = 13 — l'objet n'était qu'un contour, et un
    // contour n'est pas du verre. La nappe intérieure monte donc à 0,26 et
    // reste orientée vers la lampe.
    float corps = smoothstep(0.0, 30.0, dedans) * (0.28 + 0.72 * lobe) * 0.26
                * (0.45 + 0.55 * ruban1);
    // La nappe LARGE du côté de la lampe : la lumière qui traverse
    // l'épaisseur, indépendante du bord.
    float traverse = pow(clamp(lobe, 0.0, 1.0), 2.2)
                   * smoothstep(0.0, 14.0, dedans) * 0.22 * brillance;

    // L'ÉCLAT QUI DÉRIVE le long de l'arête du galet, sur 14 s. Lent : un
    // reflet qui court vite est du strass.
    float ang = atan2(position.y - gal.y, position.x - gal.x);
    float phase = -2.25 + 0.85 * sin(t * 6.28318 / 14.0);
    float ecart = atan2(sin(ang - phase), cos(ang - phase));
    float eclat = exp(-pow(ecart / 0.22, 2.0)) * bande * scint;

    float lum = spec + dur + contre + caustique + corps + traverse + eclat
              + rubans;

    // LA DISPERSION — le rouge sort un cheveu plus tôt que le bleu, de part et
    // d'autre de l'arête. C'est elle qui fait « cristal » plutôt que
    // « plastique brillant », et c'est précisément ce qu'un verre natif ne
    // donne pas.
    // Mesuré à 1,4 pt d'écart et 0,30/0,34 de dose : l'arête sortait MAGENTA —
    // les deux franges tombaient au même endroit et s'additionnaient sur le
    // rouge et le bleu sans rien au milieu. La dispersion doit être une paire
    // ÉQUILIBRÉE et discrète : le chaud à l'extérieur du bord, le froid en
    // retrait, et le vert entre les deux.
    float bandeR = exp(-pow((dedans + disp) / epaisseur, 2.0))
                 * pow(lobe, 5.0) * brillance;
    float bandeB = exp(-pow(max(dedans - disp, 0.0) / epaisseur, 2.0))
                 * pow(lobe, 5.0) * brillance;
    float bandeV = exp(-pow(dedans / epaisseur, 2.0))
                 * pow(lobe, 5.0) * brillance;
    float3 c = float3(lum + bandeR * 0.16,
                      lum + bandeV * 0.10,
                      lum + bandeB * 0.14);

    // La teinte : un blanc à peine chaud — celui de la lampe.
    c *= float3(1.000, 0.978, 0.952);

    // L'alpha : le corps est franchement transparent, l'arête franchement
    // présente. Prémultiplié (la loi des blooms de `galetMedaillon`).
    float alpha = aa * clamp(0.36 + 0.95 * lum, 0.0, 1.0);
    c = min(c, float3(1.0));

    return half4(half3(c * alpha), half(alpha)) * color.a;
}
