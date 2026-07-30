#include <metal_stdlib>
using namespace metal;

// MARK: - L'aurore de la page de connexion (banc `-loginLab`)
//
// Une nuit très noire en haut, et en bas une aurore CHAUDE qui monte de
// l'horizon : un cœur blanc cramé, des nappes dorées, des braises orange sur
// les flancs, un voile gris lunaire au-dessus — le tout traversé de rideaux
// fractals qui GLISSENT VERS LE BAS, comme si la lumière retombait vers sa
// source. Des halos-voix descendent eux aussi, chacun à son tempo (la
// grammaire du cadran éclipse), et des poussières-bijou s'échappent de la
// lumière : des poussières fines qui montent, et quelques étoiles à rayons
// en croix — la famille diamant, semée dans l'aurore.
//
// En haut, la croix de la référence : deux hairlines pleine page qui se
// croisent, l'étoile-diamant posée à l'intersection.
//
// Même grammaire que les autres shaders du projet : hash → bruit de valeur →
// fbm, domaine déformé deux fois, tone mapping filmique 1-exp(-kL), dither.

static float auhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 auhash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float aunoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = auhash21(i);
    float b = auhash21(i + float2(1.0, 0.0));
    float c = auhash21(i + float2(0.0, 1.0));
    float d = auhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float aufbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * aunoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

/// Une nappe elliptique : le grain de base de toute la lumière d'ici.
static float aublob(float2 q, float2 ctr, float2 sig) {
    float2 d = (q - ctr) / max(sig, float2(1e-3));
    return exp(-dot(d, d));
}

/// La lumière ANALYTIQUE de l'aurore en un point — masses fixes qui
/// respirent + halos-voix qui descendent, SANS les rideaux. Sert deux fois :
/// au fond lui-même, et aux particules pour savoir où naître et de quelle
/// couleur briller. `q` : position / hauteur (x ∈ [0, aspect], y ∈ [0, 1]).
static float3 auroraMass(float2 q, float aspect, float t) {
    // Les tons de la PHOTO de référence : blanc-crème qui crame, or franc
    // (jamais caramel), orange brûlé saturé, braise profonde, et la fumée
    // gris-blanc — c'est elle qui tue le marron : entre le noir et l'orange,
    // du GRIS, pas du brun.
    const float3 blanc   = float3(1.00, 0.98, 0.93);
    const float3 dore    = float3(1.00, 0.72, 0.26);
    const float3 ambre   = float3(1.00, 0.42, 0.08);
    const float3 braise  = float3(0.85, 0.26, 0.045);
    const float3 lunaire = float3(0.80, 0.79, 0.81);

    // Les masses fixes : le socle de l'aurore. Les centres dérivent à peine
    // (30-70 s), les poids respirent — jamais figé, jamais un show.
    float3 c = float3(0.0);
    float b1 = 0.90 + 0.10 * sin(t * 6.2832 / 41.0);
    float b2 = 0.88 + 0.12 * sin(t * 6.2832 / 29.0 + 2.1);
    float b3 = 0.86 + 0.14 * sin(t * 6.2832 / 53.0 + 4.4);
    // Le cœur blanc cramé, bas et un peu à gauche : large et brûlant — la
    // moitié basse de la photo est d'abord BLANCHE.
    c += blanc * (1.95 * b1 * aublob(q,
        float2(aspect * (0.42 + 0.020 * sin(t / 43.0)), 1.08),
        float2(0.24, 0.25)));
    // La nappe dorée au-dessus du cœur — le « plus de doré », serré bas.
    c += dore * (0.48 * b2 * aublob(q,
        float2(aspect * (0.60 + 0.030 * sin(t / 31.0 + 1.0)), 0.98),
        float2(0.34, 0.20)));
    // L'orange brûlé du flanc gauche — SATURÉ et assez lumineux pour rester
    // orange après la rampe (un orange sombre retombe en brun).
    c += ambre * (0.85 * b3 * aublob(q,
        float2(aspect * 0.08, 0.84 + 0.015 * sin(t / 37.0)),
        float2(0.24, 0.21)));
    // La braise du flanc droit, plus haute — la réf. monte à mi-écran à droite.
    c += braise * (0.90 * b2 * aublob(q,
        float2(aspect * 0.95, 0.72 + 0.020 * sin(t / 47.0 + 3.0)),
        float2(0.18, 0.24)));
    // La fumée gris-blanc au-dessus du cœur — le ton de la photo : c'est le
    // gris qui sépare le noir de l'orange, jamais un dégradé brun.
    c += lunaire * (0.30 * b1 * aublob(q,
        float2(aspect * 0.52, 0.62),
        float2(0.50, 0.13)));

    // Les halos-voix : quatre lumières qui DESCENDENT vers la masse, chacune
    // à son tempo (périodes sans rapport entier), et qui naissent/meurent en
    // fondu — jamais d'apparition sèche.
    const float3 vcol[4] = { float3(1.00, 0.70, 0.28),
                             float3(1.00, 0.96, 0.90),
                             float3(0.98, 0.44, 0.10),
                             float3(0.80, 0.79, 0.82) };
    const float vper[4]  = { 17.0, 12.0, 23.0, 31.0 };
    const float vpha[4]  = { 0.15, 0.52, 0.80, 0.33 };
    const float vcx[4]   = { 0.58, 0.36, 0.16, 0.83 };
    const float vy0[4]   = { 0.42, 0.50, 0.46, 0.34 };
    const float vy1[4]   = { 0.88, 0.92, 0.90, 0.72 };
    const float2 vsig[4] = { float2(0.20, 0.11), float2(0.13, 0.08),
                             float2(0.24, 0.14), float2(0.18, 0.12) };
    const float vw[4]    = { 0.38, 0.42, 0.44, 0.20 };
    for (int i = 0; i < 4; i++) {
        float life = fract(t / vper[i] + vpha[i]);
        float env = sin(3.14159 * life);
        float y = mix(vy0[i], vy1[i], life);
        // Le balancement se VOIT : la voix louvoie en descendant, et son
        // enveloppe elle-même palpite — le mouvement, pas juste la dérive.
        float x = aspect * (vcx[i] + 0.065 * sin(life * 6.2832 + vpha[i] * 9.0));
        float2 sig = vsig[i] * (1.0 + 0.16 * sin(life * 12.566 + vpha[i] * 7.0));
        c += vcol[i] * (vw[i] * env * env
                        * aublob(q, float2(x, y), sig));
    }
    return c;
}

[[ stitchable ]] half4 loginAurora(float2 position, half4 color,
                                   float2 size, float t,
                                   device const float *trail,
                                   int trailN) {
    float2 q = position / max(size.y, 1.0);
    float aspect = size.x / max(size.y, 1.0);

    // ---- La masse de lumière, et les rideaux qui la traversent.
    float3 mass = auroraMass(q, aspect, t);

    // Rideaux d'aurore : filaments plus serrés en x qu'en y (des VOILES
    // dressés, pas des nappes), domaine deux fois déformé, et toute la
    // matière glisse VERS LE BAS (q.y - v·t : la phase descend).
    float2 ac = float2(q.x * 3.1, (q.y - t * 0.045) * 1.15);
    float w1 = aufbm(ac + float2(t * 0.016, 0.0));
    float w2 = aufbm(ac * 1.7 - float2(t * 0.010, t * 0.024) + 2.1 * w1);
    float cur = aufbm(ac * 1.27 + float2(1.9 * w1, -1.5 * w2));
    cur = pow(clamp(cur * 1.18, 0.0, 1.0), 2.5);
    // La modulation CREUSE : du noir entre les filaments — c'est le contraste
    // qui fait l'aurore, jamais la quantité de lumière. (Profondeur bornée :
    // la scène dérive, elle ne doit pas POMPER en énergie globale.)
    mass *= 0.50 + 0.85 * cur;
    // Et les langues de l'aurore : là où un filament passe dans la frange
    // haute de la masse, il s'allume en doré — c'est lui qu'on voit monter
    // (et retomber) au bord de la lumière.
    float fringe = aublob(q, float2(aspect * 0.5, 0.80), float2(0.55, 0.20));
    mass += float3(1.00, 0.60, 0.20) * (pow(cur, 2.4) * fringe * 0.28);

    // ---- Très noir en haut : la nuit avale toute la lumière avant la
    // moitié — seule la croix et ses poussières y ont droit de cité. La
    // rampe est FRANCHE : un long fondu fabrique du marron, pas de la nuit.
    float dark = smoothstep(0.24, 0.70, q.y);
    mass *= dark;

    // ---- L'ombre du texte : une flaque de nuit derrière le bloc titre/
    // sous-titre (bas-gauche) — c'est elle qui rend le texte lisible sur le
    // cœur crème, et elle remet « du noir entre les lumières ». Elle éteint
    // aussi la caresse qui passerait sur les mots.
    mass *= 1.0 - 0.45 * aublob(q, float2(aspect * 0.30, 0.70),
                                float2(0.40, 0.16));

    // ---- Les traces du doigt : de grosses lueurs douces qui suivent la
    // caresse et s'évanouissent en s'évasant — blanches au contact, dorées
    // en mourant. Elles vivent même dans le noir du haut : la page répond
    // partout. Triplets (x, y, âge en s) côté SwiftUI.
    // Serrées (le chemin se lit, pas un projecteur), longues à mourir (la
    // traîne persiste derrière le doigt), dorées dès 0,45 s, et TEXTURÉES
    // par les rideaux : la lueur a la matière du fond, jamais du coton.
    for (int i = 0; i + 2 < trailN; i += 3) {
        float2 tp = float2(trail[i], trail[i + 1]);
        float age = trail[i + 2];
        float amp = exp(-age / 0.65) * (1.0 - smoothstep(1.0, 1.4, age));
        if (amp < 0.01) continue;
        float sig = 55.0 + 80.0 * age;
        float2 dt2 = position - tp;
        float g = exp(-dot(dt2, dt2) / (sig * sig));
        mass += mix(float3(1.00, 0.96, 0.88), float3(1.00, 0.78, 0.42),
                    clamp(age / 0.45, 0.0, 1.0))
                * (g * amp * 0.60 * (0.72 + 0.55 * cur));
    }

    // Tone mapping filmique : les superpositions saturent en douceur, le
    // cœur crame sans jamais clipper sec.
    float3 c = 1.0 - exp(-mass * 1.70);

    // ---- La gradation anti-caramel (verdict des juges, mesuré au pixel) :
    // la photo passe du noir au gris cendré puis à l'orange FRANC — jamais
    // par le brun. Sous ~30 % de lumière la couleur retombe vers le gris ;
    // dans les hautes lumières la saturation REMONTE au lieu de plafonner
    // en beige-camel.
    float3 g3 = float3(dot(c, float3(0.299, 0.587, 0.114)));
    float vmax = max(c.r, max(c.g, c.b));
    float keep = mix(0.30, 1.0, smoothstep(0.06, 0.34, vmax));
    float push = 0.45 * smoothstep(0.45, 0.85, vmax);
    c = clamp(mix(g3, c, keep + push), 0.0, 1.0);

    // ---- La croix de la référence : deux hairlines pleine page, inégales
    // le long de leur course, qui meurent doucement loin de l'intersection.
    float2 cr = float2(size.x * 0.66, size.y * 0.27);
    float dx = position.x - cr.x;
    float dy = position.y - cr.y;
    float modV = 0.35 + 0.65 * aunoise(float2(position.y * 0.016, 3.7 + t * 0.05));
    float modH = 0.35 + 0.65 * aunoise(float2(position.x * 0.016, 9.1 - t * 0.04));
    float fadeV = 1.0 - smoothstep(0.14, 0.40, fabs(dy) / size.y);
    float fadeH = 1.0 - smoothstep(0.12, 0.42, fabs(dx) / size.y);
    float lineV = exp(-dx * dx / (0.55 * 0.55)) * modV * fadeV;
    float lineH = exp(-dy * dy / (0.55 * 0.55)) * modH * fadeH;
    c += float3(0.92, 0.93, 0.97) * ((lineV + lineH) * 0.052);
    // L'étoile-diamant à l'intersection : elle SCINTILLE comme un bijou —
    // un frémissement rapide et menu, des flashs francs mais rares où les
    // rayons fleurissent, et entre les deux elle respire à peine.
    // Apériodique (deux flashs incommensurables + frémissement) : deux
    // instants à 5 s d'écart ne se ressemblent jamais. Le cœur ne clippe
    // pas : au pic, le surplus part dans les RAYONS — une taille de
    // diamant, pas un point cramé.
    float shimmer = 0.82 + 0.18 * sin(t * 6.8 + 2.0 * sin(t * 2.3));
    float flash = pow(max(0.0, sin(t * 0.83 + 0.7)), 10.0)
                  + 0.5 * pow(max(0.0, sin(t * 0.47 + 2.9)), 12.0);
    float twk = (0.38 + 0.30 * sin(t * 0.34 + 1.3) + 0.85 * flash) * shimmer;
    float rayL = 13.0 + 21.0 * clamp(twk, 0.0, 1.2);
    float sH = exp(-dy * dy / (0.60 * 0.60) - dx * dx / (rayL * rayL));
    float sV = exp(-dx * dx / (0.60 * 0.60) - dy * dy / (rayL * rayL));
    float sCore = exp(-(dx * dx + dy * dy) / (1.15 * 1.15));
    float starLum = min(((sH + sV) * 0.42 + sCore * 0.75)
                        * (0.45 + 0.55 * twk), 0.92);
    c += float3(1.00, 0.99, 0.95) * starLum;

    // ---- Les poussières-bijou : elles NAISSENT dans la lumière (pondérées
    // par la masse analytique à leur origine) et MONTENT en s'éteignant —
    // l'aurore relâche ses étincelles. Deux familles : la poussière fine
    // (menue, nombreuse), et les étoiles à rayons en croix (rares, les
    // « trop belles »). Chaque colonne-couloir porte ses particules : la
    // course peut être longue, la particule ne quitte jamais son couloir.
    if (q.y > 0.26) {
        // La poussière fine : couloirs de 14 pt, deux graines par couloir.
        {
            float lane = 14.0;
            float ix = floor(position.x / lane);
            for (int j = 0; j < 2; j++) {
                float4 h = auhash42(float2(ix * 1.71 + 3.1, 7.7 + 5.3 * float(j)));
                if (h.x > 0.50) continue;
                float yBirth = mix(1.08, 0.58, h.y);
                float life = fract(t * (0.055 + 0.075 * h.w) + h.z * 7.0);
                float rise = (0.14 + 0.16 * h.y);
                float yc = (yBirth - rise * life) * size.y;
                float xc = (ix + 0.5) * lane + (h.z - 0.5) * lane * 0.8
                           + 3.5 * sin(life * 6.2832 * (1.0 + h.w) + h.x * 6.28);
                float2 dp = position - float2(xc, yc);
                float g = exp(-dot(dp, dp) / (0.55 * 0.55));
                if (g > 0.002) {
                    float2 qo = float2(xc, yBirth * size.y) / size.y;
                    float3 born = auroraMass(qo, aspect, t);
                    float glow = clamp(dot(born, float3(0.5)), 0.0, 1.0);
                    // Nées DANS la lumière seulement : une étincelle sur du
                    // noir lit comme du bruit de capteur.
                    if (glow < 0.15) continue;
                    float env = sin(3.14159 * life);
                    float tw = 0.55 + 0.45 * sin(t * (1.9 + 2.4 * h.z) + h.y * 6.28);
                    float3 tint = mix(float3(1.00, 0.97, 0.92),
                                      float3(1.00, 0.80, 0.45), h.w);
                    c += tint * (g * env * tw * glow * 1.20);
                }
            }
        }
        // Les étoiles-bijou : couloirs de 30 pt, une par couloir, rayons en
        // croix qui fleurissent au pic — on regarde aussi les couloirs
        // voisins, leurs rayons débordent.
        {
            float lane = 30.0;
            float ix0 = floor(position.x / lane);
            for (int o = -1; o <= 1; o++) {
                float ix = ix0 + float(o);
                float4 h = auhash42(float2(ix * 2.93 + 11.3, 6.7));
                if (h.x > 0.45) continue;
                float yBirth = mix(1.05, 0.62, h.y);
                float life = fract(t * (0.040 + 0.050 * h.w) + h.z * 7.0);
                float rise = (0.18 + 0.20 * h.y);
                float yc = (yBirth - rise * life) * size.y;
                float xc = (ix + 0.5) * lane + (h.z - 0.5) * lane * 0.6
                           + 4.5 * sin(life * 6.2832 * (0.8 + h.w) + h.x * 6.28);
                float2 dp = position - float2(xc, yc);
                if (dot(dp, dp) > 34.0 * 34.0) continue;
                float2 qo = float2(xc, yBirth * size.y) / size.y;
                float3 born = auroraMass(qo, aspect, t);
                float glow = clamp(dot(born, float3(0.5)), 0.0, 1.0);
                if (glow < 0.15) continue;
                float env = sin(3.14159 * life);
                // Le flash : l'étoile dort, fleurit, se referme.
                float flash = max(0.0, sin(t * (0.55 + 0.65 * h.w) + h.z * 6.283));
                flash = pow(flash, 7.0);
                float amp = env * glow * (0.30 + 0.70 * flash);
                if (amp < 0.006) continue;
                float rl = (2.0 + 7.0 * flash);
                float core = exp(-dot(dp, dp) / (0.55 * 0.55));
                float rH = exp(-dp.y * dp.y / (0.32 * 0.32)
                               - dp.x * dp.x / (rl * rl));
                float rV = exp(-dp.x * dp.x / (0.32 * 0.32)
                               - dp.y * dp.y / (rl * rl));
                float3 tint = mix(float3(1.00, 0.99, 0.95),
                                  float3(1.00, 0.82, 0.48), h.w * 0.8);
                c += tint * ((core + (rH + rV) * 0.55) * amp * 1.05);
            }
        }
    }

    // Dither : à ces niveaux, les nappes banderaient en escalier sur OLED.
    c += (auhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0))
          - 0.5) * (2.0 / 255.0);
    c = clamp(c, 0.0, 1.0);
    return half4(half3(c), 1.0) * color.a;
}
