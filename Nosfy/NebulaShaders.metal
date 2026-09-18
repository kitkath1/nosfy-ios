#include <metal_stdlib>
using namespace metal;

// MARK: - Les passes GPU de la nébuleuse vivante
//
// Même grammaire que DemonSky.metal : des [[stitchable]] appelés depuis
// SwiftUI par colorEffect / distortionEffect. AUCUN MTKView — même GPU, même
// hiérarchie, même horloge, blend modes natifs, 30 fps plafonnés.
//
// Toutes les passes lisent le CHAMP (`field`), une texture calculée au
// lancement à partir du PNG lui-même, en espace LINÉAIRE (aucune conversion
// sRGB ne vient recourber la donnée) :
//     R = énergie      — la luminance normalisée de la photo ;
//     G = 0,5 + 0,5·tx — tangente aux filaments (gradient tourné de 90°) ;
//     B = 0,5 + 0,5·ty
// D'où le principe : toute émission est multipliée par R. Une particule ne
// peut pas naître dans le noir, une brume ne peut pas éclairer du vide.

constant float NTAU = 6.28318530718;

constexpr sampler nRep(address::repeat, filter::linear, coord::normalized);
constexpr sampler nClamp(address::clamp_to_edge, filter::linear, coord::normalized);

// MARK: Hachages

static float nhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 nhash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// MARK: Le champ

/// Énergie (luminance normalisée) au point uv.
static float fieldEnergy(texture2d<half> field, float2 uv) {
    return (float)field.sample(nClamp, uv).r;
}

/// Tangente aux filaments (unité, espace image) — pré-calculée hors shader.
/// Aux rares points de bascule d'orientation la norme s'effondre : on
/// retombe alors sur une montée douce, jamais sur un NaN.
static float2 fieldTangent(texture2d<half> field, float2 uv) {
    half4 s = field.sample(nClamp, uv);
    float2 T = float2((float)s.g, (float)s.b) * 2.0 - 1.0;
    float L = length(T);
    return (L < 0.25) ? float2(0.0, -1.0) : T / L;
}

// MARK: La veine — géométrie mesurée sur la photo

constant float2 kVein[13] = {
    float2(0.500, 0.08), float2(0.485, 0.20), float2(0.520, 0.28),
    float2(0.545, 0.36), float2(0.520, 0.44), float2(0.470, 0.51),
    float2(0.440, 0.56), float2(0.420, 0.60), float2(0.460, 0.66),
    float2(0.500, 0.72), float2(0.530, 0.80), float2(0.550, 0.88),
    float2(0.520, 0.96)
};

/// La longueur curviligne totale du tracé, en unités « aspect » (× la hauteur
/// pour l'avoir en pixels). Constante : la polyligne ne change pas.
constant float kVeinLen = 0.89857;

/// LE REPÈRE DE LA VEINE — un champ de distance signée à la polyligne, plus le
/// repère local. C'est la pièce qui garantit un masque PARFAITEMENT CONTINU :
/// aucun rectangle, aucun segment empilé, aucun bord droit ne peut en sortir,
/// puisque tout est fonction d'une distance euclidienne à une courbe.
///
///   valeur de retour : la distance (unités aspect) ;
///   sOut  : l'abscisse curviligne 0-1 (0 = en haut du tracé) ;
///   tanOut: la tangente unitaire, orientée vers le HAUT du tracé ;
///   sideOut : +1/−1 selon le côté, pour orienter la normale.
///
/// L'espace est corrigé de l'aspect : une distance vaut la même chose en x et
/// en y, comme sur la photo. Et comme cet espace n'est que l'espace pixel
/// divisé par la hauteur, une DIRECTION y est aussi une direction en pixels.
static float veinLookup(float2 uv, float aspect,
                        thread float &sOut, thread float2 &tanOut,
                        thread float &sideOut) {
    float2 p = float2(uv.x * aspect, uv.y);
    float best = 1e9, bestAcc = 0.0, total = 0.0, bestSide = 1.0;
    float2 bestT = float2(0.0, -1.0);
    for (int i = 0; i < 12; ++i) {
        float2 a = float2(kVein[i].x * aspect, kVein[i].y);
        float2 b = float2(kVein[i + 1].x * aspect, kVein[i + 1].y);
        float2 ab = b - a, ap = p - a;
        float seg = max(length(ab), 1e-6);
        float h = clamp(dot(ap, ab) / (seg * seg), 0.0, 1.0);
        float2 r = ap - ab * h;
        float d = length(r);
        if (d < best) {
            best = d;
            bestAcc = total + h * seg;
            bestT = -ab / seg;                 // remonte le tracé
            bestSide = (bestT.x * r.y - bestT.y * r.x) < 0.0 ? -1.0 : 1.0;
        }
        total += seg;
    }
    sOut = bestAcc / max(total, 1e-6);
    tanOut = bestT;
    sideOut = bestSide;
    return best;
}

/// Renvoie (distance à la veine, abscisse curviligne 0-1, côté signé).
static float3 veinField(float2 uv, float aspect) {
    float s, side; float2 T;
    float d = veinLookup(uv, aspect, s, T, side);
    return float3(d, s, side);
}

// MARK: Bruit fractal

static float nfbm(texture2d<half> lut, float2 p, float2 warp, int oct) {
    float s = 0.0, amp = 0.55, f = 1.0;
    for (int i = 0; i < oct; ++i) {
        float2 q = p * f + warp * f * 0.30 + float2(0.317, 0.641) * float(i);
        s += amp * (float)lut.sample(nRep, q).r;
        amp *= 0.5;
        f *= 2.03;
    }
    return s;
}

/// Déformation type curl : deux échantillons du bruit décalés, tournés de 90°.
static float2 ncurl(texture2d<half> lut, float2 p, float t) {
    float e = 0.035;
    float a = (float)lut.sample(nRep, p + float2(0.0, e) + float2(0.031, -0.017) * t).g;
    float b = (float)lut.sample(nRep, p - float2(0.0, e) + float2(0.031, -0.017) * t).g;
    float c = (float)lut.sample(nRep, p + float2(e, 0.0) + float2(-0.021, 0.013) * t).g;
    float d = (float)lut.sample(nRep, p - float2(e, 0.0) + float2(-0.021, 0.013) * t).g;
    return float2((a - b), -(c - d)) * 3.4;
}

// MARK: - 0. LE FLUX : la matière claire de la photo COULE le long de la veine
//
// C'est la passe décisive. Ce n'est PAS un voile qui glisse par-dessus : ce
// sont les STRUCTURES CLAIRES DE L'IMAGE elles-mêmes — filaments, nœuds,
// toutes les nuances de gris et de blanc — qui se déplacent, chacune à sa
// vitesse, tangentiellement au tracé. On échantillonne la couche de lueur avec
// des UV DÉPLACÉS : glow(uv − flow(uv)·f(t)). Des centaines de micro-détails
// bougent donc simultanément, et ils épousent forcément la courbure puisque
// c'est la courbe qui fournit la direction.
//
// Quatre exigences tenues ici :
//
//  a) RESPIRATION PÉRISTALTIQUE. L'amplitude ET la phase varient le long de
//     l'abscisse curviligne s (bruit basse fréquence sur s) : un segment
//     pousse pendant que le suivant retient. S'y ajoute une dilatation
//     PERPENDICULAIRE minuscule, elle aussi déphasée le long de s — la veine
//     gonfle et dégonfle par vagues, et sa luminosité suit la dilatation.
//
//  b) ANTI-BAVE — le flow-map cycling. Une advection d'UV continue finit par
//     étirer la texture et claquer au raccord de boucle. On échantillonne donc
//     DEUX fois, aux phases p et p+0,5, et on mélange par un poids
//     triangulaire w = |2p − 1| : chaque copie n'est visible qu'au milieu de
//     sa course, jamais à son raccord. Le flux devient perpétuel, sans bave ni
//     couture. C'est ce qui sépare « la veine coule » de « l'image glisse ».
//
//  c) MICRO-DÉTAIL PRÉSERVÉ. La photo reste affichée NON déplacée et nette à
//     100 % : cette passe est purement ADDITIVE. L'amplitude reste sous ~25 px
//     et l'échantillonnage se fait sur la lueur PLEINE RÉSOLUTION en filtrage
//     linéaire. Deux octaves de micro-turbulence décorrèlent les vitesses de
//     deux détails voisins — « chaque détail à sa vitesse ».
//
//  d) LE NOIR RESTE NOIR. Le masque est un champ de distance signée à la
//     polyligne : parfaitement continu, feather large, aucun bord droit
//     possible. L'amplitude est multipliée par ce masque (donc nulle au bord,
//     sans discontinuité) et par la luminance locale : les nœuds les plus
//     brillants avancent le plus, le vide n'avance pas du tout.
//
// La texture `glow` est construite en amont (NebulaGlow) en espace LINÉAIRE :
//   R = le micro-détail (masque non-net soustrait : les filaments seuls) ;
//   G = la composante large — les halos blancs ;
//   B = la lueur brute.

[[ stitchable ]] half4 nebulaVeinFlow(float2 position, half4 color,
                                      float2 size, float t, float reveal,
                                      float4 g0,  // halfWidth, gain, ampPx, haloGain
                                      float4 g1,  // cycleA, cycleB, dilPx, dilCycle
                                      float4 g2,  // wavePx, waveLenPx, waveSpeed, sheenGain
                                      float4 g3,  // sheenPeriodA, sheenPeriodB, sheenWidth, turb
                                      texture2d<half> glow,
                                      texture2d<half> field,
                                      texture2d<half> lut) {
    float2 sz = max(size, float2(1.0));
    float2 uv = position / sz;
    float aspect = sz.x / sz.y;

    float s, side;
    float2 T;
    float d = veinLookup(uv, aspect, s, T, side);

    // ---- Le masque : distance signée → rampe lisse. Continu par nature.
    float hw = max(g0.x, 1e-4);
    if (d >= hw) { return half4(0.0h); }
    float mask = 1.0 - smoothstep(hw * 0.28, hw, d);
    mask = mask * mask * (3.0 - 2.0 * mask);       // C1, aucun bord dur
    if (mask <= 0.004) { return half4(0.0h); }

    float2 pImg = float2(uv.x * aspect, uv.y);
    float energy = fieldEnergy(field, uv);

    // ---- La direction : la tangente aux FILAMENTS de la photo, recalée sur
    // l'axe du tracé (jamais perpendiculaire, jamais verticale uniforme).
    float2 Tf = fieldTangent(field, uv);
    if (dot(Tf, T) < 0.0) { Tf = -Tf; }
    float2 dir = normalize(mix(T, Tf, 0.70) + 1e-6);
    // Micro-turbulence : deux octaves, statiques en uv (le cycling exige un
    // champ constant dans le temps) — deux détails voisins ne vont pas à la
    // même vitesse, ni exactement dans la même direction.
    // ⚠️ Les échelles restent BASSES (2,1 et 4,3 tuiles) : au-delà, la
    // turbulence varie d'un pixel à l'autre, deux pixels voisins vont chercher
    // la lueur à deux endroits sans rapport, et le flux se lit comme un PEIGNE
    // de striations. À 2,1 tuiles la longueur de corrélation vaut ~25 px : deux
    // DÉTAILS voisins ont bien des vitesses différentes, deux PIXELS voisins
    // non.
    float2 turb = ncurl(lut, pImg * 2.10, 0.0) * (g3.w * 0.66)
                + ncurl(lut, pImg * 4.30, 0.0) * (g3.w * 0.28);
    dir = normalize(dir + turb);
    float2 N = float2(-T.y, T.x) * side;           // la normale au tracé

    // ---- Le péristaltisme : amplitude et phase pilotées par s.
    float ampS = 0.34 + 1.18 * (float)lut.sample(nRep, float2(s * 2.45 + t * 0.0040, 0.19)).r;
    float phS  = (float)lut.sample(nRep, float2(s * 1.75, 0.63)).g;
    float dPh  = (float)lut.sample(nRep, float2(s * 1.28 + 0.21, 0.41)).b * NTAU;
    float spd  = 0.42 + 1.16 * nfbm(lut, pImg * 2.35, float2(0.0), 2);
    float enF  = clamp(0.22 + 1.55 * energy, 0.0, 1.60);

    float travel = g0.z * clamp(ampS * spd * enF, 0.16, 1.28) * mask;

    // ---- La dilatation perpendiculaire (2-6 px, 7-14 s, déphasée le long de
    // s) et la vague qui remonte le tracé (3-6 px, λ ≈ 220 px, ~30 px/s).
    float dil = sin(t * NTAU / max(g1.w, 1.0) + dPh);
    float sPx = s * kVeinLen * sz.y;
    float wave = sin((sPx - t * g2.z) / max(g2.y, 1.0) * NTAU + dPh * 0.5);
    float2 osc = N * (g1.z * dil * mask + g2.x * wave * mask);
    float2 uvB = uv - osc / sz;

    // ---- Le flow-map cycling, deux couches (vitesses et amplitudes
    // différentes) : le mouvement gagne de la profondeur et ne ressemble
    // jamais à une image qui glisse en bloc.
    float2 step1 = dir * (travel * 1.70) / sz;
    float p1 = fract(t / max(g1.x, 1.0) + phS);
    float w1 = abs(2.0 * p1 - 1.0);
    half4 a1 = glow.sample(nClamp, uvB - step1 * p1);
    half4 b1 = glow.sample(nClamp, uvB - step1 * fract(p1 + 0.5));

    float2 step2 = dir * (travel * 0.92) / sz;
    float p2 = fract(t / max(g1.y, 1.0) + phS * 0.63 + 0.37);
    float w2 = abs(2.0 * p2 - 1.0);
    half4 a2 = glow.sample(nClamp, uvB - step2 * p2);
    half4 b2 = glow.sample(nClamp, uvB - step2 * fract(p2 + 0.5));

    float detail = mix((float)a1.r, (float)b1.r, w1) * 0.60
                 + mix((float)a2.r, (float)b2.r, w2) * 0.40;
    float halo   = mix((float)a1.g, (float)b1.g, w1) * 0.60
                 + mix((float)a2.g, (float)b2.g, w2) * 0.40;

    // ---- Les VAGUES de sheen : deux paquets gaussiens qui REMONTENT le tracé.
    // Elles modulent le champ continu — elles ne dessinent jamais de bande.
    float h1 = 1.0 - fract(t / max(g3.x, 1.0));
    float h2 = 1.0 - fract(t / max(g3.y, 1.0) + 0.41);
    float e1 = (s - h1) / max(g3.z, 1e-3);
    float e2 = (s - h2) / max(g3.z * 1.45, 1e-3);
    float sheen = exp(-e1 * e1) + 0.68 * exp(-e2 * e2);

    // ---- La luminosité suit la dilatation (+8-14 % quand ça gonfle).
    float swell = 1.0 + 0.12 * dil;
    // Hors matière, rien : le noir reste noir, absolument. Le plancher est
    // volontairement TRÈS bas (5 %) — sinon le flux dépose de la lumière
    // advectée dans le vide et la photo se voile.
    float near = clamp(0.05 + 2.10 * energy, 0.0, 1.0);

    float emis = (detail * g0.y + halo * g0.w * near)
               * mask * near * swell * (1.0 + g2.w * sheen) * reveal;
    // Tramage : la composante large est lisse, elle se quantifierait en
    // courbes de niveau sur huit bits.
    emis = clamp(emis + (nhash21(position * 1.11) - 0.5) * 0.0031, 0.0, 1.0);
    if (emis < 0.0015) { return half4(0.0h); }

    // Noir → gris froid → blanc. Aucune couleur.
    return half4(half(emis), half(emis * 1.004), half(emis * 1.016), 1.0h);
}

// MARK: - 1. La veine vivante
//
// Un masque spatial DOUX, LARGE et IRRÉGULIER autour de la trajectoire
// mesurée — jamais une ligne. Dedans : bruit fractal très lent déformé en
// curl, circulation interne le long de la veine, zones qui s'allument puis
// s'effacent, respiration NON synchronisée, fine brume qui glisse. Le tout
// MULTIPLIÉ par l'énergie de la photo : le noir reste noir, absolument.
//
// Le rectangle est posé exactement sur le cadre de l'image : uv = position/size
// est donc l'unité image, et le calage est parfait sur tous les iPhone.

[[ stitchable ]] half4 nebulaLivingVein(float2 position, half4 color,
                                        float2 size, float t, float reveal,
                                        float4 p0,   // halfWidth, edgeNoise, gain, lumaFloor
                                        float4 p1,   // mainCycle, breathCycle, flowSpeed, —
                                        texture2d<half> field,
                                        texture2d<half> lut) {
    float2 sz = max(size, float2(1.0));
    float2 uv = position / sz;
    float aspect = sz.x / sz.y;

    float energy = fieldEnergy(field, uv);
    float lum = max(energy - p0.w, 0.0) / max(1.0 - p0.w, 1e-3);
    // Puissance > 1 : SEULS les cœurs vraiment clairs s'allument. La brume
    // grise des bords reste noire — c'est ça, le noir souverain.
    lum = lum * lum * sqrt(lum);
    if (lum <= 0.0008) { return half4(0.0h); }

    float3 vf = veinField(uv, aspect);
    float2 pImg = float2(uv.x * aspect, uv.y);

    // ---- La déformation lente : la matière ondule, elle ne défile pas.
    float2 warp = ncurl(lut, pImg * 1.6, t * 0.020);

    // ---- Le bord IRRÉGULIER du masque : jamais un ruban régulier.
    float edge = nfbm(lut, pImg * 2.4 + warp * 0.12 + float2(0.0, -t * 0.004), float2(0.0), 3);
    float hw = p0.x * (1.0 + p0.y * (edge - 0.5) * 2.0);
    float mask = 1.0 - smoothstep(hw * 0.10, hw, vf.x);
    if (mask <= 0.002) { return half4(0.0h); }

    // ---- La circulation interne : des striations qui REMONTENT le tracé.
    float flow = nfbm(lut, float2(vf.z * vf.x * 9.0, vf.y * 5.2 - t * p1.z * 12.0)
                      + warp * 0.20, float2(0.0), 3);
    float stripes = 0.55 + 0.75 * smoothstep(0.30, 0.78, flow);

    // ---- Les zones qui s'allument puis s'effacent : bruit très lent, LOCAL.
    // Deux porteuses incommensurables : aucune boucle identifiable.
    float slow = nfbm(lut, pImg * 1.05 + warp * 0.35
                      + float2(0.013, -0.009) * t, float2(0.0), 4);
    float slow2 = nfbm(lut, pImg * 0.62 - warp * 0.22
                       + float2(-0.007, 0.005) * t, float2(0.0), 3);
    float ignite = smoothstep(0.34, 0.86, slow * 0.62 + slow2 * 0.48);

    // ---- La respiration : la phase est TIRÉE DU BRUIT, donc différente
    // partout — jamais un clignotement global.
    //
    // ⚠️ ICI ÉTAIT LE DÉFAUT DES BANDES RECTANGULAIRES. La phase venait d'un
    // hash sur floor(pImg × 7) : une CELLULE de 0,143 en y (375 px) et 0,31 en
    // uv.x (407 px). La respiration était donc constante par pavé et sautait
    // d'un pavé à l'autre — d'où la pile de bandes horizontales à bords droits
    // dans une colonne, relevée sur l'image de différence. La phase est
    // maintenant un ÉCHANTILLONNAGE BILINÉAIRE du bruit : continue partout,
    // aucun bord droit possible, et les variations restent locales.
    float ph = (float)lut.sample(nRep, pImg * 0.78 + float2(0.13, 0.71)).r * NTAU;
    float breath = 0.5 + 0.5 * sin(t * NTAU / p1.y + ph);
    float major = 0.5 + 0.5 * sin(t * NTAU / p1.x + ph * 0.37 + 1.7);

    // ---- La fine brume qui glisse DANS la matière, presque imperceptible.
    float haze = nfbm(lut, pImg * 3.1 + float2(-t * 0.0045, -t * 0.0032)
                      + warp * 0.5, float2(0.0), 2);
    float veil = 0.82 + 0.36 * (haze - 0.5);

    float emis = p0.z * mask * lum * stripes * ignite * veil
               * (0.46 + 0.34 * breath + 0.32 * major) * reveal;
    emis = clamp(emis, 0.0, 1.0);

    // Noir → gris froid → blanc : une pointe de bleu très légère dans les
    // valeurs basses, rien de plus. Aucune couleur.
    // Tramage ±0,4/255 : un champ aussi lisse et aussi sombre se quantifie en
    // courbes de niveau visibles (le « bois veiné »). Un demi-niveau de bruit
    // blanc les efface sans rien coûter.
    emis = max(0.0, emis + (nhash21(position * 1.37) - 0.5) * 0.0031);
    half3 c = half3(half(emis), half(emis * 1.002), half(emis * 1.012));
    return half4(c, 1.0h);
}

// MARK: - 2. Les particules diamants
//
// Des centaines de grains GPU : une cellule ≈ un grain. Le spawn est REJETÉ
// si l'énergie de la photo y est sous le seuil — impossible d'avoir une
// particule dans le noir. Chaque grain AVANCE le long du champ tangent aux
// filaments (deux pas : la trajectoire est courbe, elle épouse la crête) et
// traîne 8-16 px derrière lui : c'est la traînée qui DESSINE les courbes.

static float segDist(float2 p, float2 a, float2 b) {
    float2 ab = b - a, ap = p - a;
    float h = clamp(dot(ap, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
    return length(ap - ab * h);
}

[[ stitchable ]] half4 nebulaDiamondDust(float2 position, half4 color,
                                         float2 size, float t, float reveal,
                                         float4 q0,  // cell, gate, gain, flareChance
                                         float4 q1,  // speedMin, speedMax, trailMin, trailMax
                                         float4 q2,  // lifeMin, lifeMax, sizeMin, sizeMax
                                         texture2d<half> field) {
    float2 sz = max(size, float2(1.0));
    float cs = max(q0.x, 4.0);
    float2 cellId = floor(position / cs);

    float acc = 0.0;
    float spikes = 0.0;

    for (int j = -1; j <= 1; ++j) {
        for (int i = -1; i <= 1; ++i) {
            float2 cid = cellId + float2(float(i), float(j));
            float4 r = nhash42(cid + 0.5);

            float2 spawn = (cid + float2(r.x, r.y)) * cs;
            float2 uv = spawn / sz;
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) { continue; }

            half4 fs = field.sample(nClamp, uv);
            float w = (float)fs.r;
            // ⚠️ LE REJET : rien ne naît sous le seuil de luminance.
            if (w < q0.y) { continue; }

            float life = mix(q2.x, q2.y, r.z);
            float u = fract(t / life + r.w * 7.13 + nhash21(cid) * 3.7);
            float age = u * life;

            // Deux pas d'advection : la course suit la COURBE du filament.
            float2 T0 = float2((float)fs.g, (float)fs.b) * 2.0 - 1.0;
            float L0 = length(T0);
            T0 = (L0 < 0.25) ? float2(0.0, -1.0) : T0 / L0;
            float speed = mix(q1.x, q1.y, fract(r.x * 7.31 + r.z * 2.17));
            float d = speed * age;
            float2 mid = spawn + T0 * (d * 0.5);
            float2 T1 = fieldTangent(field, mid / sz);
            float2 cur = spawn + normalize(T0 + T1 + 1e-6) * d;

            float trail = min(mix(q1.z, q1.w, fract(r.y * 3.77 + r.w * 5.11)), d);
            float2 tail = cur - T1 * trail;

            // Nés du noir, morts dans le noir ; scintillement individuel.
            // ⚠️ LE SECOND REJET : un grain qui a dérivé jusque dans le noir
            // s'éteint sur place. Aucune poussière ne traverse le vide.
            float wLocal = fieldEnergy(field, cur / sz);
            if (wLocal < q0.y * 0.72) { continue; }
            float born = sin(3.14159265 * u);
            float tw = 0.32 + 0.68 * pow(0.5 + 0.5 * sin(t * (0.6 + 2.2 * r.z)
                                                         + r.w * 24.1), 2.0);
            float depth = 0.35 + 0.65 * r.z;                 // profondeurs variées
            float a = q0.z * born * born * tw * depth
                    * clamp(wLocal * 1.6, 0.0, 1.0) * reveal;
            if (a < 0.012) { continue; }

            float rad = mix(q2.z, q2.w, r.w) * 0.5;

            // Le grain, puis sa traînée (plus fine, plus sourde).
            float dHead = length(position - cur);
            float head = exp(-(dHead * dHead) / max(rad * rad * 1.35, 0.02));
            float dTail = segDist(position, tail, cur);
            float tl = exp(-(dTail * dTail) / max(rad * rad * 0.85, 0.02))
                     * smoothstep(0.0, 1.0, trail / max(q1.z, 1.0)) * 0.34;
            acc += a * (head + tl);

            // Les rares ÉCLATS : diffraction fine en croix/diamant, 0,4-1,4 s,
            // aucune explosion, aucune flare colorée.
            if (r.x < q0.w) {
                float fl = pow(max(0.0, sin(3.14159265 * u)), 9.0);
                if (fl > 0.02) {
                    float2 dp = position - cur;
                    float sp = max(rad * 6.0, 5.0);
                    float cross = exp(-abs(dp.x) * 3.2 / sp) * exp(-dp.y * dp.y * 2.6 / (sp * sp))
                                + exp(-abs(dp.y) * 3.2 / sp) * exp(-dp.x * dp.x * 2.6 / (sp * sp));
                    float diag = exp(-abs(dp.x + dp.y) * 3.6 / sp)
                                 * exp(-(dp.x - dp.y) * (dp.x - dp.y) * 2.2 / (sp * sp));
                    spikes += a * fl * (cross * 0.5 + diag * 0.22);
                }
            }
        }
    }

    float v = clamp(acc + spikes, 0.0, 1.0);
    if (v < 0.003) { return half4(0.0h); }
    // Blanc froid, strictement monochrome.
    return half4(half3(half(v), half(v), half(v * 1.02)), 1.0h);
}

// MARK: - 4. Brume et profondeur
//
// Quelques nappes de noir / gris très sombre au-dessus de la nébuleuse :
// presque invisibles, déplacement lent, elles MASQUENT puis RÉVÈLENT des
// détails. Plusieurs couches à vitesses différentes. Elles ne blanchissent
// jamais l'image (le noir n'ajoute pas de lumière) et elles s'effacent là où
// la photo est vive : le contraste des diablotins et des crêtes est intact.

[[ stitchable ]] half4 nebulaDarkMist(float2 position, half4 color,
                                      float2 size, float t, float reveal,
                                      float4 m0,   // opacity, speed, scale, guard
                                      texture2d<half> field,
                                      texture2d<half> lut) {
    float2 sz = max(size, float2(1.0));
    float2 uv = position / sz;
    float aspect = sz.x / sz.y;
    float2 p = float2(uv.x * aspect, uv.y);

    float2 warp = ncurl(lut, p * 1.1, t * 0.012);

    // Trois nappes, trois vitesses, trois échelles : jamais un motif reconnu.
    float n1 = nfbm(lut, p * m0.z * 0.85 + warp * 0.30
                    + float2(0.5, -1.0) * (t * m0.y), float2(0.0), 3);
    float n2 = nfbm(lut, p * m0.z * 1.70 - warp * 0.20
                    + float2(-0.8, -0.55) * (t * m0.y * 1.9), float2(0.0), 3);
    float n3 = nfbm(lut, p * m0.z * 0.42 + warp * 0.45
                    + float2(0.3, -0.62) * (t * m0.y * 0.55), float2(0.0), 2);

    float d = smoothstep(0.42, 0.92, n1) * 0.50
            + smoothstep(0.50, 0.98, n2) * 0.28
            + smoothstep(0.36, 0.88, n3) * 0.42;

    // Le garde-fou : là où la photo est vive (crêtes, limbes, yeux), la brume
    // s'ouvre — elle ne mange jamais un diablotin ni un nœud.
    float energy = fieldEnergy(field, uv);
    float guard = 1.0 - clamp(energy * m0.w, 0.0, 0.92);

    float a = clamp(d, 0.0, 1.0) * m0.x * guard * reveal;
    // Noir prémultiplié : elle occulte, elle n'éclaire rien.
    return half4(0.0h, 0.0h, 0.0h, half(a));
}
