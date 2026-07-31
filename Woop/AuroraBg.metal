#include <metal_stdlib>
using namespace metal;

// MARK: - Le fond aurora nu (banc `-bgLab`)
//
// Un écran noir dont le BAS s'embrase : un cœur blanc puissant qui fuit sous
// le cadre, un halo orange qui monte à droite, une brume gris-chaud qui longe
// la marge gauche — et la moitié haute rendue à la nuit. La recette de
// lumière est celle de l'aurore de la home (commit 34b0892), chèrement
// calibrée : compression du NIVEAU seul (jamais canal par canal — c'est le
// « burn »), teinte pic 1,00/0,56/0,31 qui plafonne à L=169, crème au-delà,
// brume dans les ombres pour que l'anthracite reste chaud sans virer marron.
//
// La profondeur : trois plans qui ne glissent pas à la même vitesse sous
// l'inclinaison de l'appareil (`tilt`, lissé côté Swift, [-1,1]) — le champ
// loin bouge à peine, les foyers un peu plus, les rideaux et les poussières
// franchement. C'est l'écart entre les trois qui fait le relief, pas la
// course de chacun.

static float bgHash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 bgHash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float bgNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = bgHash21(i);
    float b = bgHash21(i + float2(1.0, 0.0));
    float c = bgHash21(i + float2(0.0, 1.0));
    float d = bgHash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float bgFbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * bgNoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

static float bgGauss(float x, float c, float w) {
    float d = (x - c) / w;
    return exp(-d * d);
}

// Dôme à sommet plat (exposant > 2) : une cloche étroite brûlerait son centre.
static float bgDome(float x, float c, float w, float p) {
    float d = abs(x - c) / w;
    return exp(-pow(d, p));
}

// La palette héritée de l'aurore calibrée.
constant float3 BG_BASE  = float3(1.00, 0.56, 0.31);  // le pic, à L≈112
constant float3 BG_OR    = float3(1.00, 0.76, 0.33);  // l'écho doré du néon du logo
constant float3 BG_BRUME = float3(1.00, 0.95, 0.94);  // la brume des ombres
constant float3 BG_CREME = float3(1.00, 0.93, 0.73);  // ce que devient l'orange > 169
constant float3 BG_BLANC = float3(1.00, 0.99, 0.97);  // le cœur, au-delà de la crème
constant float3 BG_GRIS  = float3(0.91, 0.90, 0.89);  // la brume de la marge gauche

constant float BG_CY     = 0.975;   // la crête, au ras du bord bas
constant float BG_LAM_UP = 0.080;   // montée de la lumière
constant float BG_LAM_DN = 0.125;   // chute sous la crête
constant float BG_K      = 1.72;    // le compresseur de niveau

// La masse analytique des foyers (sans rideaux) — partagée entre le champ et
// la naissance des poussières, pour qu'elles naissent DANS la lumière.
// `sh` : le glissement du plan MOYEN (les foyers) sous l'inclinaison.
static float2 bgMass(float2 q, float aspect, float t, float sh) {
    // Respirations franches, périodes premières entre elles — c'est elles
    // qu'on doit VOIR : « anime davantage » (verdict v2).
    float b1 = 0.87 + 0.13 * sin(t * 6.2832 / 19.0);
    float b2 = 0.82 + 0.18 * sin(t * 6.2832 / 13.0 + 2.1);
    float b3 = 0.88 + 0.12 * sin(t * 6.2832 / 17.0 + 4.0);

    // Les foyers dérivent largement, et glissent avec l'inclinaison.
    float xCoeur  = aspect * 0.38 + 0.035 * sin(t * 6.2832 / 21.0)       + sh;
    float xDroite = aspect * 0.90 + 0.030 * sin(t * 6.2832 / 15.0 + 2.6) + sh;

    // Dômes MOUS (exposant 2, larges) : les bords des foyers ne doivent pas
    // se lire — « trop superposé » (verdict v2).
    float coeur  = bgDome (q.x, xCoeur, 0.180, 2.0);
    float droite = bgGauss(q.x, xDroite, 0.210);

    // La crête bombe sous le cœur, et respire doucement à la verticale.
    float cy = BG_CY - 0.022 * coeur + 0.010 * sin(t * 6.2832 / 11.0);

    // Le halo orange MONTE plus haut que le cœur : son λ s'allonge.
    float lamUp = BG_LAM_UP * (1.0 + 1.60 * droite);
    float up = exp(-max(cy - q.y, 0.0) / lamUp);
    float dn = exp(-max(q.y - cy, 0.0) / BG_LAM_DN);

    // Socle discret : ce qui vit entre les foyers doit être du sombre, pas du
    // brun — un tapis chaud trop large est exactement le « brun opaque ».
    // L'amplitude du halo orange le laisse à v ≈ 0,8 à la crête : un anneau
    // or-orange au bord droit, PAS une fusion blanche avec le cœur.
    float h = 0.09 + 2.45 * b1 * coeur + 1.28 * b2 * droite;
    float E = h * up * dn;

    // La brume grise de la marge gauche : SON plan, plus haut, plus lent.
    float colG = bgGauss(q.x, aspect * 0.045 + sh * 0.7, 0.105);
    float upG  = exp(-max(1.02 - q.y, 0.0) / 0.165);
    float Eg = 0.55 * b3 * colG * upG;

    return float2(E, Eg);
}

[[ stitchable ]] half4 bgAurora(float2 position, half4 color,
                                float2 size, float t, float2 tilt) {
    float2 q = position / max(size.y, 1.0);
    float aspect = size.x / max(size.y, 1.0);

    // Les trois plans de la parallaxe (en fraction de hauteur d'écran).
    float shFar  = tilt.x * 0.010;
    float shMid  = tilt.x * 0.028;
    float shNear = tilt.x * 0.055;
    // L'inclinaison verticale fait monter ou rentrer la lumière — le plan
    // proche respire plus fort que le lointain.
    float lift = tilt.y * 0.016;

    float2 qf = float2(q.x - shFar, q.y + lift * 0.6);
    float2 m = bgMass(qf, aspect, t, shMid - shFar);
    float E = m.x, Eg = m.y;

    // Les rideaux : le plan PROCHE. Moyenne 1 par construction — mais en
    // nappes LARGES et douces (domaine réduit, contraste baissé) : ils font
    // bouger la lumière sans la découper en couches.
    float2 ac = float2((q.x - shNear) * 2.3,
                       (q.y + lift - t * 0.070) * 1.05);
    float w1 = bgFbm(ac + float2(t * 0.030, 0.0));
    float w2 = bgFbm(ac * 1.7 - float2(t * 0.020, t * 0.045) + 2.1 * w1);
    float cur = bgFbm(ac * 1.27 + float2(1.9 * w1, -1.5 * w2));
    cur = pow(clamp(cur * 1.18, 0.0, 1.0), 2.5);
    E *= 0.70 + 1.05 * cur;
    Eg *= 0.80 + 0.42 * cur;   // la brume est plus lisse que le feu

    // La nuit avale la moitié haute.
    float nuit = smoothstep(0.36, 0.64, q.y + lift);
    E *= nuit;
    Eg *= nuit;

    // ---- Tone map à teinte conservée : on comprime le NIVEAU, jamais les
    // canaux.
    float v = 1.0 - exp(-E * BG_K);

    // ---- La loi de couleur calibrée (brume dans les ombres, crème au
    // sommet), plus une marche : au-delà de la crème, le blanc.
    float bas  = 0.50 * pow(max(1.0 - v / 0.664, 0.0), 2.3);
    float haut = clamp(1.10 * pow(smoothstep(0.625, 0.995, v), 1.769), 0.0, 1.0);
    float3 tint = mix(BG_BASE, BG_BRUME, bas);
    // Anti-marron : sous v ≈ 0,30 la teinte glisse vers le GRIS fumée — un
    // orange sombre lit toujours brun, entre le noir et l'orange il faut du
    // gris ou du noir, jamais un long fondu chaud.
    float grisbas = 0.45 * pow(max(1.0 - v / 0.30, 0.0), 1.5);
    tint = mix(tint, float3(0.62, 0.60, 0.60), grisbas);
    // La touche de JAUNE : un ANNEAU doré serré entre l'orange franc et la
    // crème — l'écho du néon. Plus large, il mangerait la plage v 0,45-0,72
    // où vit l'orange VIF (le défaut mesuré de la v2).
    float dore = 0.55 * smoothstep(0.62, 0.80, v) * (1.0 - haut);
    tint = mix(tint, BG_OR, dore);
    tint = mix(tint, BG_CREME, haut);
    tint = mix(tint, BG_BLANC, smoothstep(0.78, 0.97, v));
    float3 c = clamp(tint * v, 0.0, 1.0);

    // La brume grise, en fondu écran : elle éclaire sans jamais écrêter.
    float vg = 1.0 - exp(-Eg * BG_K);
    c = 1.0 - (1.0 - c) * (1.0 - BG_GRIS * vg);

    // ---- Les poussières : le plan le plus proche. Fines, rares, nées dans
    // la lumière seulement, elles montent en s'éteignant. σ ≥ 0,55 pt — en
    // dessous, un grain passe ENTRE les pixels de la dalle et disparaît.
    if (q.y > 0.46) {
        float2 pp = position - float2(shNear, lift) * size.y;
        float lane = 16.0;
        float ix = floor(pp.x / lane);
        for (int j = 0; j < 2; j++) {
            float4 h = bgHash42(float2(ix * 1.71 + 3.1, 7.7 + 5.3 * float(j)));
            if (h.x > 0.42) continue;
            float yBirth = mix(1.06, 0.66, h.y);
            float life = fract(t * (0.045 + 0.065 * h.w) + h.z * 7.0);
            float rise = 0.13 + 0.15 * h.y;
            float yc = (yBirth - rise * life) * size.y;
            float xc = (ix + 0.5) * lane + (h.z - 0.5) * lane * 0.8
                       + 3.5 * sin(life * 6.2832 * (1.0 + h.w) + h.x * 6.28);
            float2 dp = pp - float2(xc, yc);
            float g = exp(-dot(dp, dp) / (0.60 * 0.60));
            if (g > 0.002) {
                float2 qo = float2(xc / size.y, yBirth);
                float2 born = bgMass(qo, aspect, t, 0.0);
                float glow = clamp(born.x + born.y, 0.0, 1.0);
                if (glow < 0.15) continue;   // jamais d'étincelle sur du noir
                float env = sin(3.14159 * life);
                float tw = 0.55 + 0.45 * sin(t * (1.9 + 2.4 * h.z) + h.y * 6.28);
                float3 pt = mix(float3(1.00, 0.97, 0.92),
                                float3(1.00, 0.80, 0.45), h.w);
                c += pt * (g * env * tw * glow * 1.05);
            }
        }
        // Quelques étoiles-bijou, rares : un cœur et une croix discrète qui
        // fleurit puis se referme.
        float laneS = 34.0;
        float ix0 = floor(pp.x / laneS);
        for (int o = -1; o <= 1; o++) {
            float ixs = ix0 + float(o);
            float4 h = bgHash42(float2(ixs * 2.93 + 11.3, 6.7));
            if (h.x > 0.32) continue;
            float yBirth = mix(1.02, 0.70, h.y);
            float life = fract(t * (0.035 + 0.045 * h.w) + h.z * 7.0);
            float rise = 0.16 + 0.18 * h.y;
            float yc = (yBirth - rise * life) * size.y;
            float xc = (ixs + 0.5) * laneS + (h.z - 0.5) * laneS * 0.6
                       + 4.5 * sin(life * 6.2832 * (0.8 + h.w) + h.x * 6.28);
            float2 dp = pp - float2(xc, yc);
            if (dot(dp, dp) > 30.0 * 30.0) continue;
            float2 qo = float2(xc / size.y, yBirth);
            float2 born = bgMass(qo, aspect, t, 0.0);
            float glow = clamp(born.x + born.y, 0.0, 1.0);
            if (glow < 0.15) continue;
            float env = sin(3.14159 * life);
            float flash = max(0.0, sin(t * (0.50 + 0.60 * h.w) + h.z * 6.283));
            flash = pow(flash, 7.0);
            float amp = env * glow * (0.25 + 0.75 * flash);
            if (amp < 0.006) continue;
            float rl = 1.8 + 6.0 * flash;
            float core = exp(-dot(dp, dp) / (0.60 * 0.60));
            float rH = exp(-dp.y * dp.y / (0.33 * 0.33) - dp.x * dp.x / (rl * rl));
            float rV = exp(-dp.x * dp.x / (0.33 * 0.33) - dp.y * dp.y / (rl * rl));
            float3 st = mix(float3(1.00, 0.99, 0.95),
                            float3(1.00, 0.82, 0.48), h.w * 0.8);
            c += st * ((core + (rH + rV) * 0.55) * amp * 0.95);
        }
    }

    // Dither : sur un dégradé sombre aussi long, sans lui le fond s'annelle.
    c += (bgHash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0))
          - 0.5) * (2.0 / 255.0);
    c = clamp(c, 0.0, 1.0);
    return half4(half3(c), 1.0) * color.a;
}
