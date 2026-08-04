#include <metal_stdlib>
using namespace metal;

// MARK: - Le halo braise de la page Exercices (fond NOIR)
//
// Le NOIR est revenu (le papier blanc jurait avec le reste de l'app — verdict
// de Kathryn sur la v2), mais le halo a survécu : un champ de blobs jaune
// crème / orange vif / cœur blanc qui morphe lentement au MILIEU de la page,
// derrière les cartes — la lumière glisse dans les gouttières. Grammaire de
// l'aurore login (gaussiennes elliptiques, périodes incommensurables), et la
// composition additive-depuis-le-noir calibrée de la lignée bgAurora :
// compression du NIVEAU seul, anti-marron (du gris entre le noir et l'orange,
// jamais un long fondu chaud), saturation qui remonte dans la lumière.

static float exhHash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Blob elliptique mou (exposant > 2 : un sommet plat, pas une pointe qui
// brûle son centre — la leçon des dômes de l'aurore).
static float exhBlob(float2 q, float2 c, float2 w, float p) {
    float2 d = (q - c) / w;
    float r = dot(d, d);
    return exp(-pow(r, p * 0.5));
}

// La palette : la lignée braise (BG_JAUNE / BG_BASE), à flancs LUMINEUX —
// un orange sombre lit toujours brun. C'est elle qui devra se raccorder au
// lit de feu du header de la fiche (HeaderEmberCard).
constant float3 EXH_CREME  = float3(1.000, 0.938, 0.790);  // le seuil du cœur
constant float3 EXH_JAUNE  = float3(1.000, 0.830, 0.420);  // l'écho du néon
constant float3 EXH_ORANGE = float3(1.000, 0.580, 0.280);  // le vif
constant float3 EXH_BRAISE = float3(1.000, 0.450, 0.160);  // le creux du bas
constant float3 EXH_BLANC  = float3(1.000, 0.970, 0.900);  // le cœur

// `pulse` : la réponse de la page au choix d'une section — une brève montée
// de lumière (attaque 0,08 s, retombée exp 0,35 s côté Swift) qui accuse
// réception, calée sur le souffle sonore de la pose.
[[ stitchable ]] half4 exosHalo(float2 position, half4 color,
                                float2 size, float t, float pulse) {
    float2 q = position / max(size.y, 1.0);
    float aspect = size.x / max(size.y, 1.0);

    // Respirations amples, périodes premières entre elles — le « morphisme »
    // est LÀ : poids et rayons qui gonflent, centres qui dérivent, jamais en
    // phase.
    float b1 = 0.86 + 0.14 * sin(t * 6.2832 / 19.0);
    float b2 = 0.84 + 0.16 * sin(t * 6.2832 / 13.0 + 2.1);
    float b3 = 0.88 + 0.12 * sin(t * 6.2832 / 17.0 + 4.0);
    float b4 = 0.85 + 0.15 * sin(t * 6.2832 / 23.0 + 1.2);

    // JAUNE, haut-gauche. Le cluster vit FRANCHEMENT À GAUCHE, derrière les
    // cartes — tout le flanc droit appartient à la molette, qui travaille
    // sur la nuit. Les dérives combinent deux sinus incommensurables par
    // axe : la trajectoire ne boucle jamais.
    float2 cJ = float2(aspect * 0.24 + 0.028 * sin(t * 6.2832 / 31.0)
                                     + 0.014 * sin(t * 6.2832 / 47.0 + 1.7),
                       0.400 + 0.024 * sin(t * 6.2832 / 37.0 + 0.8));
    float2 wJ = float2(0.195, 0.180) * (1.0 + 0.09 * sin(t * 6.2832 / 29.0));
    float mJ = 0.85 * b1 * exhBlob(q, cJ, wJ, 2.6);

    // ORANGE VIF, bas du cluster.
    float2 cO = float2(aspect * 0.36 + 0.026 * sin(t * 6.2832 / 41.0 + 2.9),
                       0.600 + 0.026 * sin(t * 6.2832 / 27.0 + 4.4)
                             + 0.012 * sin(t * 6.2832 / 53.0));
    float2 wO = float2(0.185, 0.190) * (1.0 + 0.08 * sin(t * 6.2832 / 43.0 + 3.3));
    float mO = 0.80 * b2 * exhBlob(q, cO, wO, 2.6);

    // BRAISE, le creux du bas.
    float2 cD = float2(aspect * 0.30 + 0.020 * sin(t * 6.2832 / 59.0 + 5.1),
                       0.720 + 0.020 * sin(t * 6.2832 / 33.0 + 2.2));
    float mD = 0.45 * b3 * exhBlob(q, cD, float2(0.160, 0.110), 2.2);

    // Le CŒUR BLANC entre jaune et orange : la traversée claire du milieu.
    float2 cW = float2(aspect * 0.28 + 0.018 * sin(t * 6.2832 / 39.0 + 0.4),
                       0.495 + 0.016 * sin(t * 6.2832 / 21.0 + 3.6));
    float mW = 0.70 * b4 * exhBlob(q, cW, float2(0.130, 0.120), 2.0);

    float M = mJ + mO + mD + mW;

    // La nuit garde les marges — et le COULOIR DROIT presque entier : la
    // lumière s'éteint dès la moitié de la largeur, il n'en reste qu'un
    // souffle (0,06) sous les graduations de la molette.
    float latL = smoothstep(-0.02, 0.085, q.x);
    float latR = smoothstep(aspect * 0.88, aspect * 0.52, q.x);
    M *= latL * (0.06 + 0.94 * latR)
       * (1.0 - 0.60 * smoothstep(0.80, 1.02, q.y))
       * (1.0 + 0.20 * clamp(pulse, 0.0, 1.0));

    // ---- Tone map à teinte conservée, depuis le noir.
    float v = 1.0 - exp(-M * 1.55);

    // La teinte : moyenne des voix au prorata de leur masse…
    float3 tint = (EXH_JAUNE * mJ + EXH_ORANGE * mO
                   + EXH_BRAISE * mD + EXH_BLANC * mW) / max(M, 1e-4);
    // …anti-marron : sous v ≈ 0,30 la teinte glisse vers le GRIS fumée —
    // entre le noir et l'orange il faut du gris ou du noir, jamais un long
    // fondu chaud.
    float grisbas = 0.45 * pow(max(1.0 - v / 0.30, 0.0), 1.5);
    tint = mix(tint, float3(0.62, 0.60, 0.60), grisbas);
    // Au sommet : la crème, puis le blanc — la marche calibrée de l'aurore.
    tint = mix(tint, EXH_CREME, smoothstep(0.60, 0.92, v));
    tint = mix(tint, EXH_BLANC, smoothstep(0.84, 0.99, v));
    float3 c = clamp(tint * v, 0.0, 1.0);

    // Et la saturation REMONTE dans la lumière — sans elle, les tons moyens
    // plafonnent en beige-brun (recette anti-caramel, mesurée au pixel).
    float3 lum = float3(dot(c, float3(0.299, 0.587, 0.114)));
    c = clamp(mix(lum, c, 1.0 + 0.38 * smoothstep(0.35, 0.75, v)), 0.0, 1.0);

    // Dither : sans lui, l'annelage est GARANTI sur OLED.
    c += (exhHash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0))
          - 0.5) * (2.0 / 255.0);
    c = clamp(c, 0.0, 1.0);

    return half4(half3(c), 1.0) * color.a;
}

// MARK: - La fumée de la couronne
//
// La bouffée du cadran éclipse, portée sur la molette : au doigt posé, des
// volutes fractales DISCRÈTES s'échappent de la couronne — domaine deux fois
// déformé (elles se tordent au lieu de glisser en nappe), champ échantillonné
// de plus en plus loin vers l'intérieur avec l'âge (les volutes glissent vers
// l'extérieur), exposant haut (des filaments à trous, jamais un donut de
// brume). Tout dort au repos : l'hôte n'est même pas monté sans toucher.

static float exhNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = exhHash21(i);
    float b = exhHash21(i + float2(1.0, 0.0));
    float c = exhHash21(i + float2(0.0, 1.0));
    float d = exhHash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float exhFbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * exhNoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

// `knob` = (centre x, centre y, rayon du disque, rayon de l'anneau de
// graduations). `puff` : l'enveloppe de la bouffée (attaque 0,10 s côté
// Swift, extinction exponentielle au relâcher). `age` : secondes depuis le
// toucher — porte la glisse des volutes et l'onde. La fumée naît du DISQUE
// et grimpe aussi LE LONG DE L'ANNEAU — les volutes habillent les traits.
[[ stitchable ]] half4 knobSmoke(float2 position, half4 color,
                                 float2 size, float t, float4 knob,
                                 float puff, float age) {
    if (puff < 0.004) { return half4(0.0); }
    float2 C = knob.xy;
    float R = max(knob.z, 4.0);
    float ring = max(knob.w, R);
    float2 p = position - C;
    float r = length(p);
    float3 smoke = float3(0.0);

    if (r > R - 3.0) {
        float2 n = p / max(r, 1e-3);
        float2 slide = n * (age * 80.0);
        float2 sc = (p - slide) * 0.030;
        float2 drift = float2(t * 0.030, -t * 0.017);
        float q1 = exhFbm(sc + drift);
        float w2 = exhFbm(sc * 1.7 - drift * 0.8 + 2.3 * q1);
        float s = exhFbm(sc * 1.31 + float2(2.2 * q1, -1.6 * w2) - drift * 0.6);
        // Exposant plus doux qu'au compteur (2,6 contre 3,1) : PLUS de
        // volutes visibles — le verdict « plus de fumée » —, toujours des
        // filaments à trous, jamais un donut.
        s = pow(clamp(s, 0.0, 1.0), 2.6);
        float outR = max(r - R, 0.0);
        float envel = exp(-outR / (R * (0.22 + 0.60 * puff)));
        smoke = float3(0.87, 0.89, 0.95) * (puff * envel * s * 0.85);

        // Les volutes de l'anneau : le même champ, accroché au rayon des
        // graduations — la fumée grimpe le long des traits.
        float rd = fabs(r - ring);
        float envRing = exp(-rd / (10.0 + 24.0 * puff));
        smoke += float3(0.88, 0.90, 0.96) * (puff * envRing * s * 0.38);

        // L'onde du toucher : un anneau qui part du bord, s'évase et meurt
        // en un tiers de seconde.
        float waveAmp = exp(-age / 0.32);
        if (waveAmp > 0.01) {
            float ringR = R + age * 150.0;
            float rw = 5.0 + age * 32.0;
            float wave = exp(-(r - ringR) * (r - ringR) / (rw * rw));
            smoke += float3(0.95, 0.96, 1.00) * (wave * waveAmp * 0.22);
        }
    }

    // Émissif prémultiplié + fondu d'hôte : les leçons payées — la lumière
    // porte sa couverture, et rien ne meurt contre le bord du rectangle.
    // Marge COURTE (16 pt) : la couronne vit à ~26 pt du bord droit de son
    // hôte — une marge de 40 pt éteindrait la fumée sur la couronne même.
    float2 toEdge = min(position, size - position);
    float hostFade = smoothstep(0.0, 16.0, min(toEdge.x, toEdge.y));
    float a = clamp(max(smoke.r, max(smoke.g, smoke.b)) * 2.6, 0.0, 1.0)
            * hostFade;
    float3 c = clamp(smoke, 0.0, 1.0) * hostFade;
    return half4(half3(min(c, float3(a))), half(a)) * color.a;
}

// MARK: - La pierre des chips de filtre (ARCHIVE)
//
// La matière de la barre de nav extraite pour une capsule de filtre — les
// chips ont vécu le temps de la v2 papier, remplacées par la molette-arc.
// La recette reste : socle #16171A→#050507, sheen de paroi, dôme, vignette,
// bevel, gloss des calottes, hairline argent, trait noir, ombre courte.

static float chipSDF(float2 p, float2 halfB, float r) {
    float2 qd = abs(p) - (halfB - r);
    return length(max(qd, 0.0)) + min(max(qd.x, qd.y), 0.0) - r;
}

[[ stitchable ]] half4 chipStone(float2 position, half4 color,
                                 float2 size, float t, float pad,
                                 float press) {
    float2 halfB = size * 0.5 - pad;
    float2 p = position - size * 0.5;
    float d = chipSDF(p, halfB, halfB.y);
    float inside = smoothstep(0.7, -0.7, d);

    float ux = clamp((p.x + halfB.x) / max(2.0 * halfB.x, 1.0), 0.0, 1.0);
    float uy = clamp((p.y + halfB.y) / max(2.0 * halfB.y, 1.0), 0.0, 1.0);

    float g = uy * uy * (3.0 - 2.0 * uy);
    float3 base = mix(float3(0.0863, 0.0902, 0.1020),
                      float3(0.0196, 0.0196, 0.0275), g);

    float wall = exp(-max(-d, 0.0) / 3.4);
    float upleft = clamp(0.64 * (1.0 - uy) + 0.36 * (1.0 - ux), 0.0, 1.0);
    float sheen = wall * upleft * upleft * 0.125;

    float dome = exp(-uy * 4.6) * (0.48 + 0.52 * (1.0 - ux)) * 0.040;
    float vig = clamp(1.0 - 0.40 * smoothstep(0.42, 1.0, uy)
                          - 0.12 * smoothstep(0.58, 1.0, abs(ux * 2.0 - 1.0)),
                      0.0, 1.0);

    float bevel = exp(-max(-d, 0.0) / 2.0);
    float3 stone = base * vig * (1.0 - 0.52 * bevel)
                 + float3(sheen + dome);

    float side = abs(ux * 2.0 - 1.0);
    stone += float3(bevel * pow(side, 3.2) * (0.60 + 0.40 * (1.0 - ux)) * 0.115);

    float topness = clamp(1.0 - uy * 2.0, 0.0, 1.0);
    float capAmt = 0.008 + 0.105 * pow(topness, 2.2);
    float capLine = exp(-d * d / (0.62 * 0.62)) * capAmt;
    stone += float3(0.86, 0.89, 0.95) * capLine;

    float sideness = pow(side, 4.0);
    float smear = exp(-pow(abs(uy - 0.40) * 2.4, 1.7));
    stone += float3(0.88, 0.91, 0.98)
             * (exp(-abs(d - 0.5) / 1.15) * sideness * smear * 0.30);
    stone += float3(0.96, 0.97, 1.00)
             * (exp(-abs(d - 0.3) / 0.8) * sideness * pow(smear, 2.6) * 0.22);

    stone += float3(0.035 * press * wall);

    float outline = exp(-max(d - 0.8, 0.0) / 1.6) * (1.0 - inside) * 0.88;
    float shadow = exp(-max(d - 1.5, 0.0) / 6.0) * (1.0 - inside)
                 * (0.10 + 0.72 * smoothstep(0.1, 0.9, uy)) * 0.17;

    float dth = (exhHash21(position * 1.113 + fract(t * 0.618)
                           * float2(17.0, 29.0)) - 0.5) / 255.0;

    float2 toEdge = min(position, size - position);
    float hostFade = smoothstep(0.0, pad * 0.42, min(toEdge.x, toEdge.y));
    float a = max(inside, max(outline, shadow)) * hostFade;
    float3 rgb = clamp(stone + dth, 0.0, 1.0) * inside * hostFade;
    return half4(half3(min(rgb, float3(a))), half(a)) * color.a;
}
