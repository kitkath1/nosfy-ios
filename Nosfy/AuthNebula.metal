#include <metal_stdlib>
using namespace metal;

// MARK: - Nébuleuse de l'écran d'authentification
//
// Le fond de l'écran de connexion : une nuit fractale TRÈS noire — une brume
// qui se fond dans le noir, une veine diagonale granuleuse (haut-centre →
// bas-droite), et des milliers de poussières d'étoiles. Même grammaire que
// DemonSky.metal (LUT tileable, temps périodique sur 900 s, dérives entières,
// compression filmique + dither), mais un autre récit : pas de cœur
// souverain, pas de couleur — une pénombre photographique où les seuls
// blancs francs appartiennent aux diablotins dessinés par-dessus (Canvas).
//
// Deux passes, comme le ciel :
//   authNebulaField — la brume et la veine, en demi-résolution ;
//   authNebulaStars — les poussières, en pleine résolution, plusLighter.

constant float ATAU = 6.28318530718;
constant float APH  = ATAU / 900.0;

constexpr sampler aLut(address::repeat, filter::linear, coord::normalized);

static float ahash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 ahash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// MARK: La veine
//
// La colonne vertébrale de la scène : une centreline en S, du haut-centre au
// bas-droite, qui ondule à peine sur la boucle. Renvoie (distance signée à
// l'axe, abscisse le long de l'axe) — tout le reste (enveloppe, striations,
// nœuds, densité d'étoiles) se déduit de ces deux coordonnées.
static float2 veinCoord(float2 p, float aspect, float ph) {
    float y = p.y;
    // Centreline AJUSTÉE sur la photo (quartique, moindres carrés sur les
    // centroïdes de luminance par bande) : entre en haut vers x 0.49, bombe à
    // droite vers y 0.35 (x 0.54), redescend à GAUCHE vers y 0.8 (x 0.42),
    // remonte à peine au bord bas. Plus l'ondulation lente de la boucle.
    float xf = 0.4691 + y * (0.2728 + y * (0.7272 + y * (-3.5078 + y * 2.5808)));
    float xc = (xf + 0.014 * sin(ph * 2.0 + y * 2.6)) * aspect;
    return float2((p.x - xc) * 0.92, y);
}

// MARK: Passe brume + veine (demi-résolution)

[[ stitchable ]] half4 authNebulaField(float2 position, half4 color,
                                       float2 size, float t, float reveal,
                                       texture2d<half> lut) {
    float2 sz = max(size, float2(1.0));
    float2 uv = position / sz;
    float aspect = sz.x / sz.y;
    float2 p = float2(uv.x * aspect, uv.y);
    float tn = t / 900.0;
    float ph = t * APH;

    // ---- Warp partagé : les courants qui déforment toute la matière.
    float2 q = float2(
        (float)lut.sample(aLut, p * 0.85 + float2(  7.0,   5.0) * tn).r,
        (float)lut.sample(aLut, p * 0.85 + float2(0.41, 0.17) + float2( -5.0,  -8.0) * tn).g);
    float2 w = (q - 0.5) * 0.9;

    // ---- La brume noire : trois octaves, valeurs écrasées. Elle n'éclaire
    // rien — elle donne au noir sa matière, celle dans laquelle tout se fond.
    float o1 = (float)lut.sample(aLut, p * 1.05 + w * 0.42 + float2(  6.0,  -3.0) * tn).r * 0.55;
    float o2 = (float)lut.sample(aLut, p * 2.30 + w * 0.26 + float2(0.37, 0.71) + float2( -9.0,   6.0) * tn).g * 0.30;
    float o3 = (float)lut.sample(aLut, p * 4.70 + w * 0.15 + float2(0.61, 0.13) + float2( 15.0, -11.0) * tn).r * 0.15;
    float dens = o1 + o2 + o3;
    // Seuil haut : la majorité du champ reste un noir PUR (référence : fond
    // médiane 0, max 13) — la brume n'existe qu'aux abords de la veine.
    float mist = smoothstep(0.52, 1.05, dens);

    // ---- La veine : enveloppe à largeur VIVANTE (paquets et étranglements),
    // striations ridgées étirées le long de l'axe, nœuds brillants rares.
    float2 vc = veinCoord(p, aspect, ph);
    float wmod = (float)lut.sample(aLut, float2(0.13 + vc.y * 0.55 + 2.0 * tn, 0.37)).r;
    float widthV = mix(0.050, 0.165, wmod * wmod);
    float env = exp(-vc.x * vc.x / (widthV * widthV));

    // Le bras secondaire : la FOURCHE de la photo — un bras qui quitte la
    // jonction (~y 0.46) vers le haut-GAUCHE et meurt vers y 0.13.
    float xarm = (0.505 - (0.47 - uv.y) * 0.55) * aspect;
    float dxa = (p.x - xarm) * 0.92;
    float armW = smoothstep(0.48, 0.41, uv.y) * smoothstep(0.10, 0.20, uv.y);
    float env2 = exp(-dxa * dxa / 0.0032) * 0.42 * armW;

    // Le foyer : le nid granuleux et brillant au PIED de la veine (y ~0.84
    // sur la centreline) — la zone la plus lumineuse de la photo.
    float foyer = exp(-vc.x * vc.x / 0.004)
                * exp(-(uv.y - 0.84) * (uv.y - 0.84) / 0.010);

    // Striations : du ridged (crêtes fines) dans un repère ALLONGÉ le long de
    // l'axe — la matière file avec la veine, elle ne la traverse jamais.
    float rn  = (float)lut.sample(aLut, float2(vc.x * 2.6, vc.y * 0.80) + w * 0.20 + float2( 3.0, -6.0) * tn).g;
    float rn2 = (float)lut.sample(aLut, float2(vc.x * 5.4, vc.y * 1.70) + w * 0.14 + float2(0.23, 0.51) + float2(-5.0,  9.0) * tn).r;
    float ridge  = pow(1.0 - abs(2.0 * rn  - 1.0), 3.0);
    float ridge2 = pow(1.0 - abs(2.0 * rn2 - 1.0), 4.0);

    // Les nœuds : les grumeaux brillants de la référence, rares, qui dérivent
    // le long de l'axe.
    float knot = pow((float)lut.sample(aLut, float2(0.71, vc.y * 0.90 + 1.0 * tn)).b, 3.0);

    // ---- Les morsures : des masses d'absorption qui mangent des tronçons de
    // veine — les trous quasi noirs qui font le réalisme.
    float a1 = (float)lut.sample(aLut, p * 0.90 + w * 0.60 + float2(0.19, 0.57) + float2(  8.0,  -5.0) * tn).g;
    float a2 = (float)lut.sample(aLut, p * 2.00 + w * 0.35 + float2(0.47, 0.09) + float2(-10.0,   7.0) * tn).r;
    float hole = smoothstep(0.55, 0.90, a1 * 0.70 + a2 * 0.50);
    float Tv = exp(-1.9 * hole);

    // ---- Émission : tout reste un murmure. La brume se densifie près de la
    // veine (c'est une seule matière), la veine porte les striations et les
    // nœuds, les morsures avalent le tout.
    // Gains calibrés À TRAVERS la compression filmique (le toe divise par
    // ~2,5) sur l'étalon de la photo : corps du filament médiane ~29/255,
    // p90 ~51, nœuds ~90-120, brume hors veine ≤ 6/255. Le foyer perce les
    // morsures (il est DEVANT elles dans la photo).
    float veinE = (env + env2)
                * (0.095 + 0.50 * ridge + 0.26 * ridge2 + 0.60 * knot * ridge)
                + foyer * (0.06 + 0.30 * ridge2 + 0.60 * knot);
    float E = mist * 0.026 * (0.15 + 1.90 * (env + env2))
            + veinE * mix(Tv, 1.0, 0.35 * foyer);

    // Micro-texture des demi-tons : l'émulsion, pas le dégradé.
    float o4 = (float)lut.sample(aLut, p * 12.0 + w * 0.10 + float2(0.07, 0.43) + float2(13.0, -10.0) * tn).g;
    E *= 1.0 + (o4 - 0.5) * 0.50 * smoothstep(0.03, 0.45, E);

    // ---- Compression filmique, exposition liée à la révélation.
    float exposure = 1.15 * (0.35 + 0.65 * reveal);
    float c1 = 1.0 - exp(-exposure * E);
    c1 = c1 * c1 / (c1 + 0.0085);

    // Dither anti-banding, même horloge 24 fps que le ciel.
    float fr = fract(floor(t * 24.0) * 0.618);
    c1 += (ahash21(position * 1.113 + fr * float2(17.0, 29.0)) - 0.5) * (2.2 / 255.0);

    // Monochrome à peine bleuté : de l'argent, jamais une couleur.
    float3 c3 = saturate(c1) * float3(0.985, 0.995, 1.025);
    return half4(half3(c3), 1.0h);
}

// MARK: Passe poussières (pleine résolution)

/// Une couche de poussière : grille hashée, au plus une étoile par cellule,
/// luminosités en loi de puissance (l'écrasante majorité au ras du seuil),
/// errance en Lissajous, scintillement par sessions pour les brillantes.
/// Version resserrée du starLayer de DemonSky — même physique, sans héros.
static float astarLayer(float2 pos, float t, float cellPt, float density,
                        float alphaPow, float gain, float2 seed,
                        float2x2 grid, float wanderAmp, float T, float rev) {
    float2 sp = grid * pos;
    float2 id = floor(sp / cellPt);
    float2 f = fract(sp / cellPt);

    float4 h = ahash42(id + seed);
    if (h.x > density * mix(0.30, 1.0, T)) { return 0.0; }

    float b = pow(h.y, alphaPow) * gain;
    if (b < 0.003) { return 0.0; }

    float2 stp = 0.5 + 0.36 * (h.zw * 2.0 - 1.0);
    float wk  = 20.0 + floor(h.z * 40.0);
    float wk2 = 14.0 + floor(h.y * 26.0);
    stp += wanderAmp * float2(sin(APH * wk * t + h.w * ATAU),
                              0.6 * cos(APH * wk2 * t + h.z * ATAU));

    float2 dp = (f - stp) * cellPt;
    float r2 = dot(dp, dp);
    if (r2 > cellPt * cellPt * 0.16) { return 0.0; }

    float sig = 0.38 + 0.45 * saturate(b);
    float sub = min(sig / 0.48, 1.0);
    sig = max(sig, 0.48);
    float s = exp(-r2 / (2.0 * sig * sig)) * sub * sub;

    // Scintillement par sessions : brillantes seulement, jamais d'extinction.
    float twA = 0.38 * smoothstep(0.12, 0.90, b);
    if (twA > 0.002) {
        float ks = 10.0 + floor(fract(h.z * 31.7) * 12.0);
        float session = smoothstep(0.15, 0.60,
                                   0.5 + 0.5 * sin(APH * ks * t + h.w * ATAU * 1.9));
        float k1 = 240.0 + floor(h.z * 380.0);
        s *= 1.0 + twA * session * sin(APH * k1 * t + h.z * ATAU);
    }

    // Révélation par rang de luminosité : les brillantes d'abord.
    s *= smoothstep(0.0, 0.12, b - (1.0 - rev) * 0.55);
    return s * min(b, 1.4) * T;
}

[[ stitchable ]] half4 authNebulaStars(float2 position, half4 color,
                                       float2 size, float t, float reveal,
                                       texture2d<half> lut) {
    float2 sz = max(size, float2(1.0));
    float2 uv = position / sz;
    float aspect = sz.x / sz.y;
    float2 p = float2(uv.x * aspect, uv.y);
    float tn = t / 900.0;
    float ph = t * APH;

    // Extinction : la brume dense éteint ses étoiles (proxy deux octaves,
    // mêmes échelles et dérives que la passe brume).
    float qq = (float)lut.sample(aLut, p * 0.85 + float2(7.0, 5.0) * tn).r;
    float2 wp = float2(qq - 0.5, 0.5 - qq) * 0.9;
    float dens = (float)lut.sample(aLut, p * 1.05 + wp * 0.42 + float2( 6.0, -3.0) * tn).r * 0.55
               + (float)lut.sample(aLut, p * 2.30 + wp * 0.26 + float2(0.37, 0.71) + float2(-9.0,  6.0) * tn).g * 0.30;
    float T = exp(-1.2 * smoothstep(0.40, 0.95, dens));

    // Le couloir de la veine : la poussière s'y densifie — la voie lactée est
    // une POPULATION, pas un dégradé. La fourche et le foyer du pied de veine
    // reçoivent leur population aussi (le nid brillant de la photo).
    float2 vc = veinCoord(p, aspect, ph);
    float xarm = (0.505 - (0.47 - uv.y) * 0.55) * aspect;
    float dxa = (p.x - xarm) * 0.92;
    float armW = smoothstep(0.48, 0.41, uv.y) * smoothstep(0.10, 0.20, uv.y);
    float foyer = exp(-vc.x * vc.x / 0.004)
                * exp(-(uv.y - 0.84) * (uv.y - 0.84) / 0.010);
    float envV = exp(-vc.x * vc.x / 0.020)
               + 0.55 * exp(-dxa * dxa / 0.006) * armW
               + 2.0 * foyer;

    const float2x2 g0 = float2x2( 1.000,  0.000,  0.000,  1.000);
    const float2x2 g1 = float2x2( 0.946, -0.326,  0.326,  0.946);
    const float2x2 g2 = float2x2( 0.839,  0.545, -0.545,  0.839);
    const float2x2 g3 = float2x2( 0.990, -0.139,  0.139,  0.990);

    float s = 0.0;
    // Poudre sub-pixel : des milliers de piqûres au ras du seuil, partout.
    // Gains calibrés sur la référence : dans le fond, AUCUNE poussière ne
    // dépasse ~15/255 — seule la veine porte quelques grains francs.
    s += astarLayer(position, t,  2.9, 1.00, 15.0, 0.30, float2(13.1,  7.7), g0, 0.045, T, reveal);
    // Voile intermédiaire.
    s += astarLayer(position, t,  7.5, 0.90, 10.0, 0.42, float2(41.7,  3.3), g1, 0.045, T, reveal);
    // Étoiles moyennes, rares.
    s += astarLayer(position, t, 22.0, 0.70,  6.5, 0.62, float2(23.9, 11.3), g2, 0.045, T, reveal);
    // La population de la veine : des centaines de grains fins qui dansent
    // dans le couloir — c'est elle qui dessine la voie lactée.
    s += astarLayer(position, t,  4.6, 0.95,  9.0, 0.66, float2(91.3,  5.7), g2, 0.11, T, reveal)
       * envV;
    // Une poignée de brillantes calmes.
    s += astarLayer(position, t, 110.0, 0.30,  3.0, 0.42, float2( 5.3, 29.1), g3, 0.045,
                    mix(1.0, T, 0.4), reveal);

    // Grain photographique centré, maximal dans les demi-tons.
    float lp = 1.0 - exp(-(dens * 0.7 + s));
    float frame = floor(t * 24.0);
    float g = ahash21(position + fract(frame * 0.618) * float2(17.0, 29.0)) - 0.5;
    s += g * 0.010 * (1.0 - abs(2.0 * lp - 1.0));

    // Argent froid, chroma quasi nulle. plusLighter : jamais de négatif.
    float3 c3 = clamp(s * float3(0.975, 0.99, 1.02), float3(0.0), float3(1.0));
    return half4(half3(c3), 1.0h);
}
