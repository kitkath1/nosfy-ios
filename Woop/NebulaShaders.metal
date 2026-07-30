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

/// Renvoie (distance à la veine, abscisse curviligne 0-1, côté signé).
/// L'espace est corrigé de l'aspect : une distance vaut la même chose en x
/// et en y, comme sur la photo.
static float3 veinField(float2 uv, float aspect) {
    float2 p = float2(uv.x * aspect, uv.y);
    float best = 1e9, bestS = 0.0, bestSide = 0.0;
    float total = 0.0;
    for (int i = 0; i < 12; ++i) {
        float2 a = float2(kVein[i].x * aspect, kVein[i].y);
        float2 b = float2(kVein[i + 1].x * aspect, kVein[i + 1].y);
        total += length(b - a);
    }
    float acc = 0.0;
    for (int i = 0; i < 12; ++i) {
        float2 a = float2(kVein[i].x * aspect, kVein[i].y);
        float2 b = float2(kVein[i + 1].x * aspect, kVein[i + 1].y);
        float2 ab = b - a, ap = p - a;
        float seg = length(ab);
        float h = clamp(dot(ap, ab) / max(dot(ab, ab), 1e-8), 0.0, 1.0);
        float2 r = ap - ab * h;
        float d = length(r);
        if (d < best) {
            best = d;
            bestS = (acc + h * seg) / max(total, 1e-6);
            bestSide = (ab.x * r.y - ab.y * r.x) < 0.0 ? -1.0 : 1.0;
        }
        acc += seg;
    }
    return float3(best, bestS, bestSide);
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
    float ph = nhash21(floor(pImg * 7.0)) * NTAU;
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

// MARK: - 3. La vague de distorsion le long de la veine
//
// Un WARP DES UV, jamais un voile blanc : ce sont les nuages clairs EUX-MÊMES
// qui ondulent. Amplitude 3-6 px, λ ≈ 220 px, ~30 px/s qui REMONTE le tracé,
// et l'amplitude s'éteint dès qu'on s'éloigne de la veine.

[[ stitchable ]] float2 nebulaVeinWave(float2 position, float2 size,
                                       float t, float4 w0) {
    // w0 = (amplitude px, longueur d'onde px, vitesse px/s, demi-largeur)
    float2 sz = max(size, float2(1.0));
    float2 uv = position / sz;
    float aspect = sz.x / sz.y;
    float3 vf = veinField(uv, aspect);

    float near = 1.0 - smoothstep(w0.w * 0.25, w0.w * 2.2, vf.x);
    if (near <= 0.001) { return position; }

    float phase = (position.y + t * w0.z) / max(w0.y, 1.0) * NTAU;
    float dx = sin(phase) * w0.x
             + sin((position.y - t * w0.z * 0.42) / (w0.y * 2.7) * NTAU + 1.1) * w0.x * 0.55;
    float dy = cos(phase * 0.7 + 0.6) * w0.x * 0.30;
    return position + float2(dx, dy) * near;
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
