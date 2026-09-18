#include <metal_stdlib>
using namespace metal;

// MARK: - Bouton CONNEXION « diamant »
//
// Une seule passe pour tout l'écrin : la fumée noire fractale qui dérive à
// l'intérieur, le liseré hairline à luminosité inégale qui respire, les halos
// qui débordent aux endroits vifs, et les poussières-particules qui émanent
// du bord. Même grammaire que les autres shaders du projet (hash → bruit de
// valeur → fbm, dither final), mais un théâtre minuscule : tout est monochrome
// blanc, tout est retenu.
//
// La vue passe un rectangle PLUS GRAND que le bouton (marge `pad` de chaque
// côté) : halos et particules vivent dehors, en alpha, sans jamais peindre
// un cadre noir par-dessus la page.

static float bhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 bhash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float bnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = bhash21(i);
    float b = bhash21(i + float2(1.0, 0.0));
    float c = bhash21(i + float2(0.0, 1.0));
    float d = bhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float bfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * bnoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

/// Distance signée au rectangle arrondi (négatif dedans).
static float sdRound(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// La luminosité du liseré à un endroit du bord : des accents organiques qui
/// glissent lentement (respiration), plus généreux en haut et sur les flancs.
static float rimLight(float2 p, float2 halfB, float t) {
    float ang = atan2(p.y, p.x);
    float arc = ang * 0.159154943 + 0.5;          // 0..1 autour du centre
    // Deux échelles d'accents qui rampent en sens contraires : jamais figé,
    // jamais périodique à l'œil. Paramétré par la POSITION sur le bord (pas
    // l'angle) : sur les longs bords horizontaux, l'angle est quasi constant
    // et figeait le bruit — la position, elle, varie franchement.
    float seg = bfbm(p * float2(0.014, 0.05) + float2(t * 0.13, -t * 0.09));
    float fine = bnoise(p * float2(0.032, 0.11) + float2(-t * 0.26, t * 0.19));
    float accents = seg * 0.72 + fine * 0.28;
    accents = accents * accents * accents;         // creuse les vallées
    // Biais d'arête : le haut vit, les flancs aussi, le bas murmure.
    float topness  = clamp(-p.y / max(halfB.y, 1.0), 0.0, 1.0);
    float sideness = clamp(fabs(p.x) / max(halfB.x, 1.0) - 0.72, 0.0, 0.28) / 0.28;
    float bias = 0.22 + 0.62 * topness * topness + 0.45 * sideness;
    // Respiration d'ensemble : assez vive pour être VUE, jamais stroboscopique.
    float breath = 0.82 + 0.18 * sin(t * 1.1 + arc * 12.566);
    return clamp((0.06 + 4.0 * accents) * bias * breath, 0.0, 1.0);
}

// `press` : l'état tap (0 repos → 1 pressé, rampe lissée côté SwiftUI) —
// tout l'écrin monte d'un cran : fumée plus vivante, accents plus vifs,
// facettes plus nombreuses. `burst` : l'onde du toucher (1 au contact → 0
// en ~0,3 s), un anneau de lumière qui s'évase et s'éteint. `warm` : teinte
// de la fumée d'échappée (0 = blanc pur, la maison ; 1 = or) — la page
// aurora la réchauffe, le reste de l'app n'y touche pas.
[[ stitchable ]] half4 diamondButton(float2 position, half4 color,
                                     float2 size, float t,
                                     float pad, float radius,
                                     float press, float burst, float warm) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float r = min(radius, halfB.y);
    float d = sdRound(p, halfB, r);

    float rim = clamp(rimLight(p, halfB, t) * (1.0 + 0.35 * press), 0.0, 1.0);

    // ---- Le liseré : hairline ~1 pt, jamais un cadre.
    float line = exp(-d * d / (0.42 * 0.42)) * (0.08 + 0.92 * rim);

    // ---- Les halos : une buée qui déborde aux endroits vifs, et un soupçon
    // de lueur interne pour que le bord ne soit pas un trait posé sur du vide.
    float outside = max(d, 0.0);
    // Fondu court : la buée reste collée au liseré, la fumée ne
    // s'échappe presque pas du bouton. Au tap, elle s'épanouit un peu.
    //
    // AU REPOS, elle ne pèse plus que 30 % — LE CADRE. À 0,50, la buée
    // valait encore 0,50 · e^(-34/15) · 1,6 ≈ 0,083 d'alpha en arrivant au
    // BORD DU RECTANGLE-HÔTE (pad = 34 pt), soit ~21 niveaux de gris coupés
    // NET en un pixel : sur un fond noir, l'œil ne lit pas une buée, il lit
    // un cadre rectangulaire autour du bouton. À 0,15 la même arête tombe à
    // ~6 niveaux et disparaît dans le noir.
    // Le tap est INTACT : le facteur repart exactement à 0,50 quand `press`
    // atteint 1, donc l'état pressé rend 0,50 + 0,14 = 0,64, au niveau près
    // ce qu'il rendait avant.
    float haloAmp = 0.50 * (0.30 + 0.70 * press) + 0.14 * press;
    float halo = exp(-outside / (15.0 + 5.0 * press))
                 * smoothstep(-0.8, 0.8, d) * haloAmp * rim;
    // L'onde du toucher : un anneau qui s'évase du liseré et s'éteint.
    if (burst > 0.001) {
        float ring = 8.0 + (1.0 - burst) * 30.0;
        float rw = 5.0 + (1.0 - burst) * 9.0;
        halo += exp(-(d - ring) * (d - ring) / (rw * rw)) * burst * 0.22;
    }
    float sheen = exp(-max(-d, 0.0) / 5.0) * smoothstep(0.8, -0.8, d) * 0.05 * rim;

    // ---- La fumée : volutes fractales, domaine déformé, dérive lente.
    float inside = smoothstep(0.6, -1.2, d);
    float smoke = 0.0;
    float smokeOut = 0.0;
    if (d < 30.0) {
        float2 sc = p * float2(0.030, 0.052);      // volutes larges, couchées
        float2 drift = float2(t * 0.030, -t * 0.016);
        // Domaine deux fois déformé : les volutes se tordent sur elles-mêmes
        // au lieu de glisser en nappe — c'est là que vit le démon.
        float q = bfbm(sc + drift);
        float w2 = bfbm(sc * 1.7 - drift * 0.8 + 2.3 * q);
        float s = bfbm(sc * 1.31 + float2(2.2 * q, -1.6 * w2) - drift * 0.6);
        s = pow(clamp(s, 0.0, 1.0), 2.2);
        // Le socle : obsidienne à peine dégradée (haut un poil plus clair).
        // Sombre : l'intérieur lit NOIR traversé de fumée, jamais gris.
        float uvY = clamp((p.y + halfB.y) / (2.0 * halfB.y), 0.0, 1.0);
        float base = mix(0.038, 0.012, uvY);
        // La fumée attrape la lumière du bord : plus dense près des accents.
        // Au tap, le démon s'anime : les volutes montent d'un cran.
        float nearRim = exp(-fabs(d) / 16.0);
        // Le press souffle sur les volutes SANS voiler l'obsidienne : le
        // noir profond reste noir entre les nuages (verdict mesuré : la
        // face pressée virait au marbré gris).
        smoke = base + 0.006 * press
                + s * (0.075 + 0.42 * nearRim * rim) * (1.0 + 0.35 * press)
                + 0.026 * nearRim * rim;
        smoke *= inside;
        // L'effet wahou : au tap, la fumée SORT du bouton — des volutes
        // franches qui s'échappent du liseré et enveloppent l'obsidienne,
        // MORTES avant les voisins (l'input doit rester sobre).
        float escape = exp(-max(d, 0.0) / 12.0) * (1.0 - inside)
                       * smoothstep(30.0, 12.0, d);
        smokeOut = press * escape * s * (0.14 + 0.12 * rim);
    }

    // ---- Les particules : des poussières qui émanent du bord, s'éloignent
    // et s'éteignent. Grille hashée dans une bande autour du liseré ; chaque
    // cellule porte au plus une étincelle, pondérée par la lumière locale.
    float spark = 0.0;
    if (d > -6.0 && d < 26.0) {
        for (int k = 0; k < 2; k++) {
            float cell = (k == 0) ? 11.0 : 17.0;
            float2 id = floor(p / cell);
            float4 h = bhash42(id * 1.93 + float2(4.7 * float(k) + 1.0, 8.1));
            if (h.x < 0.34) {
                float2 c0 = (id + 0.5 + (h.yz - 0.5) * 0.7) * cell;
                // Normale sortante approchée au point d'origine.
                float e = 0.75;
                float2 n = normalize(float2(
                    sdRound(c0 + float2(e, 0.0), halfB, r) - sdRound(c0 - float2(e, 0.0), halfB, r),
                    sdRound(c0 + float2(0.0, e), halfB, r) - sdRound(c0 - float2(0.0, e), halfB, r)) + 1e-4);
                float life = fract(t * (0.09 + 0.13 * h.w) + h.y * 7.0);
                float2 pos = c0 + n * (1.5 + life * 11.0);
                float d0 = sdRound(c0, halfB, r);
                // Ne naissent que sur le liseré, brillent où lui brille.
                float born = smoothstep(4.0, 0.5, fabs(d0));
                float local = rimLight(c0, halfB, t);
                float tw = 0.55 + 0.45 * sin(t * (1.7 + 2.6 * h.z) + h.w * 6.28);
                float2 dp = p - pos;
                float g = exp(-dot(dp, dp) / (0.8 * 0.8));
                spark += g * sin(3.14159 * life) * born * tw
                         * (0.5 + 0.5 * local) * (1.4 + 0.7 * press);
            }
        }
    }

    // ---- Le scintillement bijou : des éclats-ÉTOILES (une bague qu'on
    // tourne sous la lumière) — un cœur vif et deux rayons fins en croix qui
    // fleurissent au pic du flash puis se referment. Ils ne vivent que là où
    // la lumière vit : sur le liseré et dans sa frange intérieure éclairée.
    // Rares (2-4 visibles), brefs, jamais stroboscopiques.
    float glitter = 0.0;
    if (d > -16.0 && d < 4.0) {
        for (int k = 0; k < 2; k++) {
            float cell = (k == 0) ? 9.0 : 14.0;
            float2 idg = floor(p / cell);
            // L'étoile d'une cellule peut rayonner jusque dans la voisine :
            // on échantillonne la cellule et ses 8 voisines.
            for (int oy = -1; oy <= 1; oy++)
            for (int ox = -1; ox <= 1; ox++) {
                float2 idn = idg + float2(ox, oy);
                float4 hg = bhash42(idn * 2.71 + float2(13.7 + 3.1 * float(k), 5.3));
                // Au tap, davantage de facettes s'éveillent, plus souvent.
                if (hg.x >= 0.22 + 0.16 * press) continue;
                float2 cg = (idn + 0.5 + (hg.yz - 0.5) * 0.6) * cell;
                float dg = sdRound(cg, halfB, r);
                // Accroché à la lumière : max sur le liseré, fond en s'enfonçant.
                float on = exp(-fabs(dg) / 6.0);
                float local = rimLight(cg, halfB, t);
                // Flash rare et bref : l'étoile dort presque tout le temps.
                float twk = max(0.0, sin(t * (0.35 + 0.55 * hg.w) + hg.z * 6.283));
                twk = pow(twk, 16.0 - 9.0 * press);
                float amp = twk * on * (0.25 + 0.75 * local);
                if (amp < 0.004) continue;
                float2 dpg = p - cg;
                float rayLen = (2.5 + 10.0 * twk) * (1.0 + 0.4 * press);
                float core = exp(-dot(dpg, dpg) / (0.75 * 0.75));
                float rayH = exp(-dpg.y * dpg.y / (0.42 * 0.42)
                                 - dpg.x * dpg.x / (rayLen * rayLen));
                float rayV = exp(-dpg.x * dpg.x / (0.42 * 0.42)
                                 - dpg.y * dpg.y / (rayLen * rayLen));
                glitter += (core + (rayH + rayV) * 0.55) * amp;
            }
        }
    }

    float lum = smoke + sheen + line + halo + spark + glitter;
    // Dither léger : tue le banding des halos et de la fumée.
    lum += (bhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5) * (2.0 / 255.0);
    lum = clamp(lum, 0.0, 1.0);

    // Dedans : opaque (l'obsidienne). Dehors : de la LUMIÈRE pure —
    // couleur = couverture (ratio 1), blanc pour les halos/éclats, blanc
    // réchauffé d'or (`warm`) pour la fumée d'échappée. L'ancienne
    // pondération (couleur ≈ 0,3 × alpha) était invisible sur le banc noir
    // mais ASSOMBRISSAIT tout fond clair : halos et fumée lisaient comme un
    // voile sale sur l'aurore. La ligne garde son alpha — sinon la rampe du
    // bord mange la hairline exactement là où elle vit (d ≈ 0).
    float aSmoke = clamp(smokeOut * 3.5, 0.0, 1.0);
    float aLight = clamp((line + halo + spark + glitter) * 1.6, 0.0, 1.0);
    float aOut = clamp(aLight + aSmoke * (1.0 - aLight), 0.0, 1.0);
    float a = mix(aOut, 1.0, inside);
    float3 tint = mix(float3(1.0), float3(1.00, 0.84, 0.55), warm);
    float3 cOut = float3(aLight) + tint * (aSmoke * (1.0 - aLight));
    float3 c = mix(cOut, float3(lum), inside);
    c = min(c, float3(a));
    return half4(half3(c), half(a));            // prémultiplié
}

// MARK: - Input « diamant » (champ de saisie)
//
// Le petit frère sobre du bouton : PAS de fumée, pas de particules — un
// métal noir qui brille à peine (dégradé + reflet traversant lent + micro-
// brossage statique), serclé d'une hairline discrète où QUELQUES accents
// blancs scintillent très légèrement. La hiérarchie tient à cette sobriété :
// le bouton est le bijou, l'input est l'écrin fermé.

/// Les accents du liseré de l'input : mêmes lois que le bouton (bruit
/// paramétré par la position du bord), seuil bien plus dur — n'en survivent
/// que 2-4, inégaux, surtout en haut.
static float inputRim(float2 p, float2 halfB, float t) {
    float seg = bfbm(p * float2(0.016, 0.06) + float2(t * 0.10, -t * 0.07));
    float fine = bnoise(p * float2(0.036, 0.12) + float2(-t * 0.20, t * 0.15));
    float accents = seg * 0.75 + fine * 0.25;
    accents = pow(clamp(accents, 0.0, 1.0), 4.0);  // ne survivent que les pics
    float topness = clamp(-p.y / max(halfB.y, 1.0), 0.0, 1.0);
    float bias = 0.35 + 0.45 * topness * topness;
    float ang = atan2(p.y, p.x);
    float breath = 0.80 + 0.20 * sin(t * 0.9 + ang * 2.0);
    return clamp(4.6 * accents * bias * breath, 0.0, 1.0);
}

[[ stitchable ]] half4 diamondInput(float2 position, half4 color,
                                    float2 size, float t,
                                    float pad, float radius, float active) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float r = min(radius, halfB.y);
    float d = sdRound(p, halfB, r);
    float inside = smoothstep(0.6, -1.2, d);

    // ---- Le métal noir qui brille à peine.
    float metal = 0.0;
    if (inside > 0.0) {
        float uvY = clamp((p.y + halfB.y) / (2.0 * halfB.y), 0.0, 1.0);
        float base = mix(0.052, 0.024, uvY);
        // Reflet traversant (~33 s par passage) : il MULTIPLIE le socle —
        // il révèle la matière, n'ajoute jamais de gris dans le noir.
        float band = (p.x + p.y * 0.35) / max(halfB.x, 1.0);
        float c = fract(t / 33.0) * 3.0 - 1.5;
        float sheen = exp(-(band - c) * (band - c) / (0.35 * 0.35));
        // Micro-brossage horizontal STATIQUE, visible seulement dans la lumière.
        float bru = bnoise(float2(p.x * 0.9, p.y * 7.0)) - 0.5;
        // Lumière d'éveil : à l'état actif, un voile doux descend du bord
        // haut dans le fond noir — un tout petit peu de lumière, perceptible
        // sans jamais éclabousser.
        float wake = active * exp(-uvY * 3.8) * 0.075;
        metal = base * (1.0 + 0.8 * sheen) + wake
                + bru * 0.012 * (0.4 + 0.6 * sheen);
        metal = max(metal, 0.0) * inside;
    }

    // Au repos (input vide), le liseré murmure : les accents tombent à
    // ~55 % de leur pleine lumière — l'éveil (focus/texte) les rallume.
    float rim = inputRim(p, halfB, t) * (0.55 + 0.45 * active);

    // ---- Hairline discrète, accents localisés, souffle minuscule.
    float line = exp(-d * d / (0.42 * 0.42)) * (0.12 + 0.88 * rim);
    float outside = max(d, 0.0);
    float halo = exp(-outside / 6.0) * smoothstep(-0.8, 0.8, d) * 0.14 * rim;

    // ---- Scintillement très léger : des pointes sur les accents, SANS
    // rayons en croix — la retenue est la différence avec le bouton.
    float glitter = 0.0;
    if (fabs(d) < 4.0) {
        float2 idg = floor(p / 10.0);
        float4 hg = bhash42(idg * 3.17 + float2(7.9, 2.3));
        if (hg.x < 0.20) {
            float2 cg = (idg + 0.5 + (hg.yz - 0.5) * 0.6) * 10.0;
            float dg = sdRound(cg, halfB, r);
            float on = exp(-fabs(dg) / 3.0);
            float local = inputRim(cg, halfB, t);
            float twk = max(0.0, sin(t * (0.4 + 0.5 * hg.w) + hg.z * 6.283));
            twk = pow(twk, 14.0);
            float2 dpg = p - cg;
            float gg = exp(-dot(dpg, dpg) / (0.7 * 0.7));
            glitter = gg * on * twk * local * 0.8;
        }
    }

    float lum = metal + line + halo + glitter;
    lum += (bhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5) * (2.0 / 255.0);
    lum = clamp(lum, 0.0, 1.0);
    float a = mix(clamp((line + halo + glitter) * 1.6, 0.0, 1.0), 1.0, inside);
    return half4(half3(lum * a), half(a));      // prémultiplié
}

// MARK: - Anneau « diamant » (bouton icône rond, retour)
//
// Le liseré seul, posé SUR le Liquid Glass natif : un cercle hairline
// imparfait et discret — deux-trois accents qui rampent, des pointes qui
// s'allument à peine. TOUT l'intérieur est transparent : le verre respire
// dessous, le shader ne peint que la lumière.

[[ stitchable ]] half4 diamondRing(float2 position, half4 color,
                                   float2 size, float t, float pad) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float radius = min(center.x, center.y) - pad;
    float d = length(p) - radius;

    // Accents : sur un cercle, l'angle est une abscisse honnête (vitesse
    // uniforme le long du trait) — deux nappes en sens contraires.
    float ang = atan2(p.y, p.x);
    float2 ring = float2(cos(ang), sin(ang));
    float seg = bfbm(ring * 1.8 + float2(t * 0.14, -t * 0.10));
    float fine = bnoise(ring * 4.5 + float2(-t * 0.26, t * 0.20));
    float accents = seg * 0.72 + fine * 0.28;
    accents = pow(clamp(accents, 0.0, 1.0), 4.0);
    float topness = clamp(-p.y / max(radius, 1.0), 0.0, 1.0);
    float bias = 0.40 + 0.45 * topness * topness;
    float breath = 0.78 + 0.22 * sin(t * 1.1 + ang * 2.0);
    float rim = clamp(3.6 * accents * bias * breath, 0.0, 1.0);

    float line = exp(-d * d / (0.42 * 0.42)) * (0.13 + 0.80 * rim);
    float halo = exp(-max(d, 0.0) / 5.0) * smoothstep(-0.8, 0.8, d) * 0.12 * rim;

    // Pointes rares, minuscules — le bijou murmure.
    float glitter = 0.0;
    if (fabs(d) < 3.5) {
        float2 idg = floor(p / 8.0);
        float4 hg = bhash42(idg * 3.57 + float2(3.3, 9.1));
        if (hg.x < 0.22) {
            float2 cg = (idg + 0.5 + (hg.yz - 0.5) * 0.6) * 8.0;
            float dg = length(cg) - radius;
            float on = exp(-fabs(dg) / 2.5);
            float twk = max(0.0, sin(t * (0.5 + 0.6 * hg.w) + hg.z * 6.283));
            twk = pow(twk, 14.0);
            float2 dpg = p - cg;
            glitter = exp(-dot(dpg, dpg) / (0.65 * 0.65)) * on * twk * 0.7;
        }
    }

    float lum = line + halo + glitter;
    lum += (bhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5) * (1.5 / 255.0);
    lum = clamp(lum, 0.0, 1.0);
    float a = clamp(lum * 1.6, 0.0, 1.0);
    return half4(half3(lum * a), half(a));      // prémultiplié, verre dessous
}

// MARK: - Bouton secondaire « diamant »
//
// Sous le primaire : un NOIR PROFOND (pas le métal de l'input, pas la fumée
// du bouton — une profondeur calme) serclé d'un liseré discret, imparfait
// et FRANCHEMENT animé (il vit, il ne réclame rien). Au tap, la fumée naît
// du bord et fleurit vers le centre — l'éveil du second rôle.

/// Le rim du secondary : la retenue de l'input mais des dérives plus vives
/// et une respiration plus profonde — l'animation se VOIT, la discrétion
/// reste (c'est l'amplitude qui est basse, pas la vie).
static float secondaryRim(float2 p, float2 halfB, float t) {
    float seg = bfbm(p * float2(0.016, 0.06) + float2(t * 0.17, -t * 0.12));
    float fine = bnoise(p * float2(0.036, 0.12) + float2(-t * 0.32, t * 0.25));
    float accents = seg * 0.75 + fine * 0.25;
    accents = pow(clamp(accents, 0.0, 1.0), 4.0);
    float topness = clamp(-p.y / max(halfB.y, 1.0), 0.0, 1.0);
    float bias = 0.35 + 0.45 * topness * topness;
    float ang = atan2(p.y, p.x);
    float breath = 0.76 + 0.24 * sin(t * 1.2 + ang * 2.0);
    return clamp(3.7 * accents * bias * breath, 0.0, 1.0);
}

[[ stitchable ]] half4 diamondSecondary(float2 position, half4 color,
                                        float2 size, float t,
                                        float pad, float radius, float press) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float r = min(radius, halfB.y);
    float d = sdRound(p, halfB, r);
    float inside = smoothstep(0.6, -1.2, d);

    // Le noir profond : à peine plus clair que la page, dégradé murmuré.
    float uvY = clamp((p.y + halfB.y) / (2.0 * halfB.y), 0.0, 1.0);
    float deep = mix(0.030, 0.011, uvY) * inside;

    // Le liseré : discret mais vivant. Au tap, il se relève un peu.
    float rim = secondaryRim(p, halfB, t) * (0.80 + 0.25 * press);

    // ---- La fumée d'éveil : absente au repos. Au tap, elle NAÎT DU LISERÉ
    // et S'ÉCHAPPE AUTOUR du bouton — des volutes qui l'enveloppent par
    // l'extérieur (l'effet wahou) pendant qu'elle fleurit aussi dedans.
    // Plus mobile que la fumée du primaire, noire dominante, magnifique.
    float smoke = 0.0;
    float smokeOut = 0.0;
    if (press > 0.001 && d < 30.0) {
        float2 sc = p * float2(0.030, 0.052);
        float2 drift = float2(t * 0.048, -t * 0.026);
        float q = bfbm(sc + drift);
        float w2 = bfbm(sc * 1.7 - drift * 0.8 + 2.3 * q);
        float s = bfbm(sc * 1.31 + float2(2.2 * q, -1.6 * w2) - drift * 0.6);
        s = pow(clamp(s, 0.0, 1.0), 2.0);
        float nearRim = exp(-fabs(d) / 14.0);
        // Dedans : éclosion du bord vers le centre sur la rampe.
        float bloom = mix(nearRim * 1.6, 1.0, press);
        smoke = press * bloom * (0.010 + s * (0.10 + 0.28 * nearRim * rim))
                * inside;
        // Dehors : les volutes s'échappent FRANCHEMENT du liseré et
        // enveloppent le bouton — portée ~25 pt, fondue, jamais jusqu'aux
        // voisins. C'est l'effet wahou : il doit se voir au premier regard.
        float escape = exp(-max(d, 0.0) / 15.0) * (1.0 - inside);
        smokeOut = press * escape * s * (0.13 + 0.12 * rim);
    }
    float line = exp(-d * d / (0.42 * 0.42)) * (0.10 + 0.78 * rim);
    float halo = exp(-max(d, 0.0) / 5.0) * smoothstep(-0.8, 0.8, d) * 0.10 * rim;

    float glitter = 0.0;
    if (fabs(d) < 3.5) {
        float2 idg = floor(p / 10.0);
        float4 hg = bhash42(idg * 2.93 + float2(11.3, 6.7));
        if (hg.x < 0.18 + 0.10 * press) {
            float2 cg = (idg + 0.5 + (hg.yz - 0.5) * 0.6) * 10.0;
            float dg = sdRound(cg, halfB, r);
            float on = exp(-fabs(dg) / 2.5);
            float twk = max(0.0, sin(t * (0.4 + 0.5 * hg.w) + hg.z * 6.283));
            twk = pow(twk, 14.0 - 5.0 * press);
            float2 dpg = p - cg;
            glitter = exp(-dot(dpg, dpg) / (0.65 * 0.65)) * on * twk * 0.6;
        }
    }

    float lum = deep + smoke + smokeOut + line + halo + glitter;
    lum += (bhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5) * (1.5 / 255.0);
    lum = clamp(lum, 0.0, 1.0);
    float a = mix(clamp((line + halo + glitter + smokeOut * 2.2) * 1.6, 0.0, 1.0),
                  1.0, inside);
    return half4(half3(lum * a), half(a));      // prémultiplié
}

// MARK: - Éclats bijou en overlay (home)
//
// Les éclats-ÉTOILES du CONNEXION, extraits en overlay autonome : un cœur
// vif + deux rayons fins en croix qui fleurissent au pic du flash puis se
// referment, accrochés au périmètre d'un rectangle arrondi. AUCUN fond,
// aucun liseré — seule la lumière existe (prémultiplié), la surface reste
// celle du composant hôte. `strength` module rareté et amplitude : 1.0 =
// registre du CONNEXION, ~0.5 = murmure pour les cartes.

[[ stitchable ]] half4 diamondGlints(float2 position, half4 color,
                                     float2 size, float t,
                                     float pad, float radius,
                                     float strength) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float r = min(radius, min(halfB.x, halfB.y));
    float d = sdRound(p, halfB, r);
    // Les étoiles ne vivent que sur le liseré et sa frange intérieure.
    if (d < -16.0 || d > 6.0) { return half4(0.0); }

    float glitter = 0.0;
    for (int k = 0; k < 2; k++) {
        float cell = (k == 0) ? 9.0 : 14.0;
        float2 idg = floor(p / cell);
        for (int oy = -1; oy <= 1; oy++)
        for (int ox = -1; ox <= 1; ox++) {
            float2 idn = idg + float2(ox, oy);
            float4 hg = bhash42(idn * 2.71 + float2(13.7 + 3.1 * float(k), 5.3));
            if (hg.x >= 0.20 * strength) continue;
            float2 cg = (idn + 0.5 + (hg.yz - 0.5) * 0.6) * cell;
            float dg = sdRound(cg, halfB, r);
            float on = exp(-fabs(dg) / 6.0);
            float local = rimLight(cg, halfB, t);
            float twk = max(0.0, sin(t * (0.35 + 0.55 * hg.w) + hg.z * 6.283));
            twk = pow(twk, 16.0);
            float amp = twk * on * (0.25 + 0.75 * local) * strength;
            if (amp < 0.004) continue;
            float2 dpg = p - cg;
            float rayLen = 2.5 + 10.0 * twk;
            float core = exp(-dot(dpg, dpg) / (0.75 * 0.75));
            float rayH = exp(-dpg.y * dpg.y / (0.42 * 0.42)
                             - dpg.x * dpg.x / (rayLen * rayLen));
            float rayV = exp(-dpg.x * dpg.x / (0.42 * 0.42)
                             - dpg.y * dpg.y / (rayLen * rayLen));
            glitter += (core + (rayH + rayV) * 0.55) * amp;
        }
    }
    float lum = clamp(glitter, 0.0, 1.0);
    float a = clamp(glitter * 1.6, 0.0, 1.0);
    return half4(half3(lum * a), half(a));      // prémultiplié
}
