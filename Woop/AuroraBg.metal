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
// Le jaune du néon de la lune (le tube du logo posé sur la connexion), plus
// clair et plus VERT que l'or : c'est ce demi-ton qui fait « jaune » et non
// « doré ». Réservé à la home.
constant float3 BG_JAUNE = float3(1.00, 0.83, 0.42);

// La forme de la lumière, par page. Mesuré au pixel sur `-bgLab` : avec les
// valeurs de la CONNEXION, le noir occupe 40 % de la hauteur, une bande morte
// s'étale de 40 à 50 %, l'orange vit de 50 à 80 % et le blanc est écrasé dans
// le dernier cinquième.
constant float4 BG_SHAPE_LOGIN = float4(0.975, 0.080, 0.125, 0.30);
// La HOME depuis le 2026-08-04 : la lumière a CHANGÉ DE BORD (verdict
// Kathryn, réf. « My Jams »). Le halo ne monte plus du sol — il DESCEND du
// haut, depuis la Dynamic Island, et le bas de la page est rendu à la nuit :
// la pile de cartes y vit sur du noir. Même champ, même matière : le shader
// est simplement RETOURNÉ (y et inclinaison verticale inversés). Ces valeurs
// se lisent donc dans le repère retourné — crête 0.94 = à 6 % du bord
// HAUT de l'écran ; nuit 0.44 = le noir est total sous 56 % de la hauteur.
// Montée 0.17 et nuit 0.44 (au lieu de 0.15/0.46) : « augmente le halo » —
// la lumière descend un peu plus loin dans la page.
constant float4 BG_SHAPE_HOME  = float4(0.940, 0.170, 0.420, 0.440);
// Le niveau du champ, propre à la home : à pleine puissance (v1), le cœur
// blanc noyait le titre et la lumière tenait 60 % de l'écran. Ici le champ
// n'est qu'une nappe d'or — le BLANC appartient au bloom de l'île, seul.
// 0,40 : le champ n'est plus qu'une nappe d'OR — à 0,58 puis 0,52, son cœur
// gauche montait encore au blanc aux crues de la respiration et mangeait le
// titre (« encore trop sur le côté gauche, on voit plus le texte »). Le
// BLANC de la page part désormais essentiellement de l'île : c'est le bloom
// qui le porte, seul.
constant float BG_HOME_GAIN = 0.40;
// Où vivent les foyers (cœur blanc, halo orange), en fraction de largeur.
// La home tire les siens vers la GAUCHE : sa lumière descend se poser sur le
// coin doré de la carte Objectif, et le bord droit retombe dans la nuit.
// Le cœur blanc est AU RAS du bord (0,07) : à 0,18 son flanc passait encore
// derrière le titre, qui se noyait à chaque crue de la respiration.
constant float2 BG_FOYERS_LOGIN = float2(0.38, 0.90);
constant float2 BG_FOYERS_HOME  = float2(0.07, 0.50);
// La naissance : la crête part AU-DESSUS du cadre (là où vivait la lune) et
// descend se poser — pendant l'aube, la lumière est VERSÉE par le haut.
constant float4 BG_SHAPE_HOME_BIRTH = float4(1.060, 0.100, 0.200, 0.520);

constant float BG_K      = 1.85;    // le compresseur de niveau

// La masse analytique des foyers (sans rideaux) — partagée entre le champ et
// la naissance des poussières, pour qu'elles naissent DANS la lumière.
// `sh` : le glissement du plan MOYEN (les foyers) sous l'inclinaison.
// `shape` = (hauteur de la crête, λ de montée, λ de chute, plancher de nuit).
// La connexion garde les valeurs mesurées d'origine — crête au ras du bord bas,
// montée très courte. La home, elle, remonte tout : c'est le SEUL réglage qui
// change entre les deux pages, et il vaut mieux qu'il soit un paramètre qu'un
// second shader recopié.
// `foyers` = (abscisse du cœur blanc, abscisse du halo orange), en fraction
// de largeur : la connexion les garde à leurs places mesurées (0.38, 0.90),
// la home les tire vers la GAUCHE — sa lumière fait écho au coin doré de la
// carte Objectif (verdict du 2026-08-04).
// `cine` = (niveau 0→1, abscisse de la lune en fraction de LARGEUR). La
// cinématique de connexion : les foyers remontent vers la lune et le feu du
// bas S'ÉTEINT en proportion — l'énergie quitte la page, elle ne fusionne
// pas au centre. La fusion créait une nappe à luminance moyenne plein écran,
// c'est-à-dire exactement le marron (verdict « fond marron moche »).
static float2 bgMass(float2 q, float aspect, float t, float sh, float4 shape,
                     float2 foyers, float2 cine) {
    // Respirations franches, périodes premières entre elles — c'est elles
    // qu'on doit VOIR : « anime davantage » (verdict v2).
    float b1 = 0.87 + 0.13 * sin(t * 6.2832 / 19.0);
    float b2 = 0.82 + 0.18 * sin(t * 6.2832 / 13.0 + 2.1);
    float b3 = 0.88 + 0.12 * sin(t * 6.2832 / 17.0 + 4.0);

    // Les foyers dérivent largement, et glissent avec l'inclinaison.
    float xCoeur  = aspect * foyers.x + 0.035 * sin(t * 6.2832 / 21.0)       + sh;
    float xDroite = aspect * foyers.y + 0.030 * sin(t * 6.2832 / 15.0 + 2.6) + sh;
    // Ce sont les SOURCES qui se déplacent — vers l'abscisse de la lune,
    // pas vers le centre : la lumière ne change pas de couleur, elle change
    // d'adresse, et l'œil la suit jusqu'à l'objet dans lequel on va plonger.
    float xLune = aspect * cine.y;
    xCoeur  = mix(xCoeur,  xLune, cine.x);
    xDroite = mix(xDroite, xLune, cine.x);

    // Dômes MOUS (exposant 2, larges) : les bords des foyers ne doivent pas
    // se lire — « trop superposé » (verdict v2).
    float coeur  = bgDome (q.x, xCoeur, 0.180, 2.0);
    float droite = bgGauss(q.x, xDroite, 0.210);

    // La crête bombe sous le cœur, et respire doucement à la verticale.
    float cy = shape.x - 0.022 * coeur + 0.010 * sin(t * 6.2832 / 11.0);

    // Le halo orange MONTE plus haut que le cœur : son λ s'allonge.
    float lamUp = shape.y * (1.0 + 1.85 * droite);
    float up = exp(-max(cy - q.y, 0.0) / lamUp);
    float dn = exp(-max(q.y - cy, 0.0) / shape.z);

    // Socle discret : ce qui vit entre les foyers doit être du sombre, pas du
    // brun — un tapis chaud trop large est exactement le « brun opaque ».
    // L'amplitude du halo orange le laisse à v ≈ 0,8 à la crête : un anneau
    // or-orange au bord droit, PAS une fusion blanche avec le cœur.
    // Le drainage : le feu du bas MEURT pendant que la lune s'engorge. Rien
    // ne traverse l'orange sombre — la lumière s'éteint sur place et renaît
    // plus haut, dans le monolithe (côté SwiftUI).
    float h = (0.09 + 2.45 * b1 * coeur + 1.28 * b2 * droite)
            * (1.0 - 0.55 * cine.x);
    float E = h * up * dn;

    // La brume grise de la marge gauche : SON plan, plus haut, plus lent.
    float colG = bgGauss(q.x, aspect * 0.045 + sh * 0.7, 0.105);
    float upG  = exp(-max(1.02 - q.y, 0.0) / 0.165);
    float Eg = 0.55 * b3 * colG * upG * (1.0 - 0.85 * cine.x);

    return float2(E, Eg);
}

// Le champ complet (foyers, rideaux, brume grise, poussières) : partagé
// entre le banc nu et la page de connexion. `curOut` rend la texture des
// rideaux au point courant — la caresse du login s'en habille pour avoir la
// matière du fond, jamais du coton.
static float3 bgField(float2 position, float2 size, float t, float2 tilt,
                      float4 shape, float2 foyers, float doreBoost,
                      float2 cine, float gain, thread float &curOut) {
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
    float2 m = bgMass(qf, aspect, t, shMid - shFar, shape, foyers, cine);
    float E = m.x, Eg = m.y;
    // La naissance : pendant l'aube de la cinématique, TOUTE la masse est
    // mise à l'échelle — à 0 la page est la nuit pure, à 1 elle est
    // elle-même. Sur E, avant le tone map : la montée traverse les teintes
    // calibrées au lieu d'un fondu gris.
    E *= gain;

    // Les rideaux : le plan PROCHE. Moyenne 1 par construction — mais en
    // nappes LARGES et douces (domaine réduit, contraste baissé) : ils font
    // bouger la lumière sans la découper en couches.
    float2 ac = float2((q.x - shNear) * 2.3,
                       (q.y + lift - t * 0.070) * 1.05);
    float w1 = bgFbm(ac + float2(t * 0.030, 0.0));
    float w2 = bgFbm(ac * 1.7 - float2(t * 0.020, t * 0.045) + 2.1 * w1);
    float cur = bgFbm(ac * 1.27 + float2(1.9 * w1, -1.5 * w2));
    cur = pow(clamp(cur * 1.18, 0.0, 1.0), 2.5);
    curOut = cur;
    E *= 0.70 + 1.05 * cur;
    Eg *= 0.80 + 0.42 * cur;   // la brume est plus lisse que le feu

    // La nuit avale le haut de l'écran. Où elle s'arrête est LE réglage qui
    // sépare les deux pages : la connexion lui laisse la moitié, la home la
    // rétrécit à ses quarante pour cent.
    float nuit = smoothstep(shape.w, shape.w + 0.28, q.y + lift);
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
    // `doreBoost` élargit l'anneau vers le BAS de la plage : la home veut le
    // jaune du néon de la lune bien plus présent que la connexion, sans pour
    // autant manger la crème du cœur — donc on descend le seuil, on ne monte
    // pas l'amplitude.
    float doreT = clamp(doreBoost + cine.x, 0.0, 1.0);
    float dore = (0.75 + 0.25 * doreT)
               * smoothstep(0.55 - 0.22 * doreT, 0.78, v) * (1.0 - haut);
    tint = mix(tint, mix(BG_OR, BG_JAUNE, doreT), dore);
    tint = mix(tint, BG_CREME, haut);
    tint = mix(tint, BG_BLANC, smoothstep(0.78, 0.97, v));
    float3 c = clamp(tint * v, 0.0, 1.0);
    // Et la saturation REMONTE dans la lumière (recette anti-caramel du
    // login, mesurée au pixel) : c'est elle qui fait l'orange VIF — sans
    // elle, les tons moyens plafonnent en beige-brun.
    float3 lum = float3(dot(c, float3(0.299, 0.587, 0.114)));
    c = clamp(mix(lum, c, 1.0 + 0.38 * smoothstep(0.35, 0.75, v)), 0.0, 1.0);

    // La brume grise, en fondu écran : elle éclaire sans jamais écrêter.
    float vg = 1.0 - exp(-Eg * BG_K);
    c = 1.0 - (1.0 - c) * (1.0 - BG_GRIS * vg);

    // ---- Les poussières : le plan le plus proche. Fines, rares, nées dans
    // la lumière seulement, elles montent en s'éteignant. σ ≥ 0,55 pt — en
    // dessous, un grain passe ENTRE les pixels de la dalle et disparaît.
    // Les poussières ne naissent que là où il y a de la lumière : la borne
    // suit donc la nuit de la page au lieu d'être figée à mi-écran.
    if (q.y > shape.w + 0.16) {
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
                float2 born = bgMass(qo, aspect, t, 0.0, shape, foyers, cine);
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
            float2 born = bgMass(qo, aspect, t, 0.0, shape, foyers, cine);
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

    return c;
}

// Dither commun : sur un dégradé sombre aussi long, sans lui le fond
// s'annelle en escaliers sur OLED.
static float3 bgDither(float3 c, float2 position, float t) {
    c += (bgHash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0))
          - 0.5) * (2.0 / 255.0);
    return clamp(c, 0.0, 1.0);
}

[[ stitchable ]] half4 bgAurora(float2 position, half4 color,
                                float2 size, float t, float2 tilt) {
    float cur = 0.0;
    float3 c = bgField(position, size, t, tilt, BG_SHAPE_LOGIN,
                       BG_FOYERS_LOGIN, 0.0, float2(0.0), 1.0, cur);
    c = bgDither(c, position, t);
    return half4(half3(c), 1.0) * color.a;
}

// La HOME : le même fond, la même matière, mais RETOURNÉ — la lumière ne
// monte plus du sol, elle DESCEND du haut. Le champ calibré est appelé sur
// la position verticale inversée (l'inclinaison verticale suit) : les foyers,
// les rideaux, la loi de couleur anti-brun, tout est réutilisé tel quel, et
// même les poussières jouent le jeu — nées dans la lumière, elles TOMBENT
// maintenant du halo au lieu d'en monter. Surtout pas un second champ.
// Par-dessus, le foyer NOMMÉ de la page : un bloom serré sur la Dynamic
// Island — c'est d'elle que la lumière semble sourdre — posé en fondu écran
// (jamais d'écrêtage), texturé par les rideaux comme la caresse du login.
// `birth` : l'aube de la cinématique de connexion. La crête part au-dessus
// du cadre — là où la lune s'est dissoute — et descend se poser pendant que
// la masse monte de rien à tout : la lumière est versée par le haut. Hors
// cérémonie, 1.
[[ stitchable ]] half4 bgAuroraHome(float2 position, half4 color,
                                    float2 size, float t, float2 tilt,
                                    float birth) {
    float cur = 0.0;
    float b = clamp(birth, 0.0, 1.0);
    float bs = b * b * (3.0 - 2.0 * b);
    float4 shape = mix(BG_SHAPE_HOME_BIRTH, BG_SHAPE_HOME, bs);
    float2 flipped = float2(position.x, size.y - position.y);
    float2 tiltF = float2(tilt.x, -tilt.y);
    // « Anime davantage les halos » (le même verdict que sur le login) : les
    // foyers de la home DÉRIVENT plus largement que ceux de la connexion —
    // le paramètre est là pour ça — et le niveau du champ respire, ample et
    // lent. Périodes premières entre elles : jamais de pompage synchronisé.
    float2 foyers = BG_FOYERS_HOME;
    foyers.x += 0.055 * sin(t * 6.2832 / 17.0 + 1.3);
    foyers.y += 0.045 * sin(t * 6.2832 / 23.0 + 4.2);
    float gain = BG_HOME_GAIN * (0.86 + 0.20 * sin(t * 6.2832 / 11.0 + 0.7));
    // L'ANNEAU JAUNE SE REFERME (2026-08-05, « la teinte est un peu trop
    // dorée »). Il valait 1 sur la home : il remplaçait l'or par le jaune du
    // néon, montait son amplitude ET abaissait son seuil de 0,55 à 0,33 — le
    // jaune baignait donc toute la plage moyenne. Mesuré contre la
    // carte-braise de la fiche d'exercice, qui appelle LE MÊME champ avec
    // l'anneau éteint : G/R 0,72-0,87 chez nous contre 0,55 chez elle. À
    // 0,30 le jaune redevient un accent près de la crête, l'orange reprend
    // le milieu.
    float3 c = bgField(flipped, size, t, tiltF, shape, foyers, bs * 0.30,
                       float2(0.0), b * gain, cur);

    // LA BRAISE. La descente vers le noir se délavait en gris-beige
    // (saturation mesurée 0,38 quand la fiche d'exercice tient 0,78 au même
    // niveau) : c'était la vieille parade anti-marron, qui dégrise sous
    // v ≈ 0,30. Or le marron est un orange sombre DÉSATURÉ — l'orange sombre
    // SATURÉ, lui, est une braise. On re-teinte donc le bas de la lumière
    // vers l'orange profond À LUMINANCE CONSTANTE : la teinte tourne, le
    // niveau ne bouge pas, donc rien ne s'assombrit ni ne se salit. Le blanc
    // de l'île est hors d'atteinte, la bande s'éteint bien avant lui.
    {
        float lum = dot(c, float3(0.299, 0.587, 0.114));
        float band = smoothstep(0.010, 0.055, lum)
                   * (1.0 - smoothstep(0.36, 0.74, lum));
        if (band > 0.001) {
            float3 braise = float3(1.00, 0.50, 0.19);
            float3 reh = braise * (lum / dot(braise, float3(0.299, 0.587, 0.114)));
            c = mix(c, reh, band * 0.62 * bs);
        }
    }

    // Le bloom de l'île : un cœur crème serré autour d'elle, une nappe d'or
    // large qui coule dessous. En fondu écran, il éclaire sans jamais brûler
    // le champ. Le cœur reste SUR l'île ; la nappe, elle, penche à gauche —
    // vers le coin allumé de la carte Objectif — et elle VIT : son propre
    // souffle (9 s, à contretemps du champ), une dérive latérale lente, et
    // les rideaux qui la texturent plus franchement que la v3.
    // Le SOUFFLE BLANC de l'île (verdict du 2026-08-04) : bien plus poussé —
    // amplitude 3,3, élargi le long de l'île, avec sa propre respiration —
    // mais tenu COURT en hauteur (σ vertical resserré à 4,2 % de l'écran) :
    // il doit mourir avant « Bonjour Kathryn », jamais descendre dessus.
    float souffle = 0.82 + 0.26 * sin(t * 6.2832 / 9.0 + 2.0);
    float souffleIle = 0.88 + 0.16 * sin(t * 6.2832 / 7.3 + 1.1);
    float sway = 0.38 + 0.035 * sin(t * 6.2832 / 14.0 + 5.1);
    float2 pi1 = position - float2(size.x * 0.5, 10.0);
    float2 pi2 = position - float2(size.x * sway, 30.0);
    float2 di1 = pi1 / float2(size.x * 0.19, size.y * 0.042);
    float2 di2 = pi2 / float2(size.x * 0.42, size.y * 0.15);
    float coeurIle = exp(-dot(di1, di1));
    float Li = (3.30 * coeurIle * souffleIle
              + 1.00 * exp(-dot(di2, di2)) * souffle)
             * (0.62 + 0.75 * cur) * bs;
    if (Li > 0.001) {
        float vi = 1.0 - exp(-Li * 1.6);
        // La JUPE DU BLOOM était peinte en jaune (BG_JAUNE, G/R 0,83) — et
        // c'est ELLE, pas le champ, qui portait toute la plage moyenne du
        // haut de page : refermer l'anneau doré n'y avait rien changé
        // (mesuré 0,72 → 0,73). Elle passe à la braise. Le CŒUR reste blanc :
        // le souffle sous l'île est intact, seule sa nappe se réchauffe.
        float3 ti = mix(float3(1.00, 0.58, 0.24), float3(1.00, 0.99, 0.96),
                        clamp(coeurIle * 1.35, 0.0, 1.0));
        c = 1.0 - (1.0 - c) * (1.0 - ti * vi);
    }

    c = bgDither(c, position, t);
    return half4(half3(c), 1.0) * color.a;
}

// LA PAGE PROFIL : le champ de la home MIROITÉ — le halo vient de la
// DROITE. Copie conforme de `bgAuroraHome` avec le flip x DANS le shader
// (jamais un scaleEffect côté SwiftUI : la parallaxe répondrait à
// l'envers, le dither serait recalculé sur des positions incohérentes) ;
// le flip vit ICI et pas dans bgField : le champ est partagé avec le
// login. Le cœur du bloom de l'île reste centré (l'île est au milieu) ;
// seule sa NAPPE penche — à droite désormais (sway miroité). Nouvelle
// fonction, signature identique : l'arité des appels existants ne bouge
// pas d'un cheveu.
[[ stitchable ]] half4 bgAuroraProfil(float2 position, half4 color,
                                      float2 size, float t, float2 tilt,
                                      float birth) {
    float cur = 0.0;
    float b = clamp(birth, 0.0, 1.0);
    float bs = b * b * (3.0 - 2.0 * b);
    float4 shape = mix(BG_SHAPE_HOME_BIRTH, BG_SHAPE_HOME, bs);
    float2 flipped = float2(size.x - position.x, size.y - position.y);
    float2 tiltF = float2(-tilt.x, -tilt.y);
    float2 foyers = BG_FOYERS_HOME;
    foyers.x += 0.055 * sin(t * 6.2832 / 17.0 + 1.3);
    foyers.y += 0.045 * sin(t * 6.2832 / 23.0 + 4.2);
    float gain = BG_HOME_GAIN * (0.86 + 0.20 * sin(t * 6.2832 / 11.0 + 0.7));
    float3 c = bgField(flipped, size, t, tiltF, shape, foyers, bs * 0.30,
                       float2(0.0), b * gain, cur);

    // La braise à luminance constante — la même loi que la home.
    {
        float lum = dot(c, float3(0.299, 0.587, 0.114));
        float band = smoothstep(0.010, 0.055, lum)
                   * (1.0 - smoothstep(0.36, 0.74, lum));
        if (band > 0.001) {
            float3 braise = float3(1.00, 0.50, 0.19);
            float3 reh = braise * (lum / dot(braise, float3(0.299, 0.587, 0.114)));
            c = mix(c, reh, band * 0.62 * bs);
        }
    }

    // Le bloom de l'île : cœur centré intact, la nappe miroitée à droite.
    float souffle = 0.82 + 0.26 * sin(t * 6.2832 / 9.0 + 2.0);
    float souffleIle = 0.88 + 0.16 * sin(t * 6.2832 / 7.3 + 1.1);
    float sway = 0.62 - 0.035 * sin(t * 6.2832 / 14.0 + 5.1);
    float2 pi1 = position - float2(size.x * 0.5, 10.0);
    float2 pi2 = position - float2(size.x * sway, 30.0);
    float2 di1 = pi1 / float2(size.x * 0.19, size.y * 0.042);
    float2 di2 = pi2 / float2(size.x * 0.42, size.y * 0.15);
    float coeurIle = exp(-dot(di1, di1));
    float Li = (3.30 * coeurIle * souffleIle
              + 1.00 * exp(-dot(di2, di2)) * souffle)
             * (0.62 + 0.75 * cur) * bs;
    if (Li > 0.001) {
        float vi = 1.0 - exp(-Li * 1.6);
        float3 ti = mix(float3(1.00, 0.58, 0.24), float3(1.00, 0.99, 0.96),
                        clamp(coeurIle * 1.35, 0.0, 1.0));
        c = 1.0 - (1.0 - c) * (1.0 - ti * vi);
    }

    c = bgDither(c, position, t);
    return half4(half3(c), 1.0) * color.a;
}

// LA BANNIÈRE DU PROFIL : trois GRANDS halos — le blanc à cœur, le jaune,
// l'orange braise — qui NAVIGUENT dans le rectangle et se FONDENT l'un
// dans l'autre (composition en écran : la lumière s'additionne sans
// jamais cramer). Le noir est interdit par construction : le plancher est
// une braise profonde SATURÉE (la leçon anti-marron : l'orange sombre
// désaturé est un marron, l'orange sombre saturé est une braise).
// Périodes premières entre elles : la danse ne repasse jamais deux fois
// par le même chemin. `t` en secondes (mod 900 côté hôte).
[[ stitchable ]] half4 banniereHalos(float2 position, half4 color,
                                     float2 size, float t) {
    float A = size.x / max(size.y, 1.0);
    float2 p = float2(position.x / size.y, position.y / size.y);

    // Le plancher : jamais noir — une braise profonde, et respire à
    // peine (période 31 s). Le marron se corrige APRÈS composition, à
    // luminance constante.
    float plancher = 1.0 + 0.10 * sin(t * 6.2832 / 31.0 + 2.1);
    float3 c = float3(0.130, 0.046, 0.010) * plancher;

    // LE BLANC — le cœur de lumière, TRÈS large : les halos se marchent
    // dessus, c'est ce chevauchement qui fait le fondu.
    {
        float2 ctr = float2(A * (0.50 + 0.17 * sin(t * 6.2832 / 17.0)),
                            0.32 + 0.13 * sin(t * 6.2832 / 23.0 + 1.7));
        float sig = 0.60 * (1.0 + 0.10 * sin(t * 6.2832 / 19.0 + 0.6));
        float2 d = (p - ctr) / sig;
        float g = exp(-dot(d, d));
        float souffle = 0.92 + 0.14 * sin(t * 6.2832 / 13.0 + 3.9);
        float3 h = float3(1.00, 0.965, 0.905) * (1.18 * g * souffle);
        c = 1.0 - (1.0 - c) * (1.0 - clamp(h, 0.0, 1.0));
    }
    // LE JAUNE — l'or qui rôde à gauche, fondu dans le blanc.
    {
        float2 ctr = float2(A * (0.26 + 0.16 * sin(t * 6.2832 / 13.0 + 0.8)),
                            0.60 + 0.15 * sin(t * 6.2832 / 19.0 + 4.0));
        float sig = 0.54 * (1.0 + 0.12 * sin(t * 6.2832 / 29.0 + 2.2));
        float2 d = (p - ctr) / sig;
        float g = exp(-dot(d, d));
        float souffle = 0.90 + 0.16 * sin(t * 6.2832 / 11.0 + 1.3);
        float3 h = float3(1.00, 0.80, 0.30) * (1.00 * g * souffle);
        c = 1.0 - (1.0 - c) * (1.0 - clamp(h, 0.0, 1.0));
    }
    // L'ORANGE — la braise qui veille à droite, large et lente.
    {
        float2 ctr = float2(A * (0.76 + 0.15 * sin(t * 6.2832 / 29.0 + 2.4)),
                            0.56 + 0.14 * sin(t * 6.2832 / 11.0 + 5.3));
        float sig = 0.56 * (1.0 + 0.11 * sin(t * 6.2832 / 17.0 + 4.8));
        float2 d = (p - ctr) / sig;
        float g = exp(-dot(d, d));
        float souffle = 0.90 + 0.15 * sin(t * 6.2832 / 23.0 + 0.4);
        float3 h = float3(1.00, 0.46, 0.12) * (1.05 * g * souffle);
        c = 1.0 - (1.0 - c) * (1.0 - clamp(h, 0.0, 1.0));
    }

    // L'ANTI-MARRON (la leçon de la maison) : le marron est un orange
    // moyen DÉSATURÉ — on re-teinte la plage basse et moyenne vers la
    // braise saturée À LUMINANCE CONSTANTE : la teinte tourne, le niveau
    // ne bouge pas, le brun disparaît sans assombrir.
    {
        float lum = dot(c, float3(0.299, 0.587, 0.114));
        float band = smoothstep(0.015, 0.09, lum)
                   * (1.0 - smoothstep(0.42, 0.80, lum));
        if (band > 0.001) {
            float3 braise = float3(1.00, 0.44, 0.10);
            float3 reh = braise * (lum / dot(braise, float3(0.299, 0.587, 0.114)));
            c = mix(c, reh, band * 0.60);
        }
    }

    // L'épaule douce : les blancs restent crémeux, jamais coupés net.
    c = c / (1.0 + 0.14 * c);
    c = clamp(c * 1.16, 0.0, 1.0);

    c = bgDither(c, position, t);
    return half4(half3(c), 1.0) * color.a;
}

// LE MÉTAL DU PROFIL : la page rendue à un noir de MÉTAL BROSSÉ hyper
// réaliste — micro-stries anisotropes (sur-échantillonnées ×3 : le
// Nyquist des stries, payé sur la carte Objectif), un large reflet
// diagonal très doux (la tôle qui accroche une lumière lointaine), une
// vignette profonde. STATIQUE : le métal ne bouge pas, le shader se rend
// une fois (pas de TimelineView côté hôte).
[[ stitchable ]] half4 profilMetal(float2 position, half4 color,
                                   float2 size) {
    float2 uv = position / max(size, float2(1.0));

    // Les stries du brossage : du bruit étiré à l'extrême en x, trois
    // prises moyennées en y pour éteindre le scintillement.
    float stries = 0.0;
    for (int i = 0; i < 3; i++) {
        float y = position.y + (float(i) - 1.0) * 0.35;
        float2 q = float2(position.x * 0.011, y * 1.35);
        float n = fract(sin(dot(floor(q), float2(127.1, 311.7))) * 43758.5453);
        float n2 = fract(sin(dot(floor(q) + float2(0.0, 1.0),
                                 float2(127.1, 311.7))) * 43758.5453);
        float fy = fract(q.y);
        fy = fy * fy * (3.0 - 2.0 * fy);
        stries += mix(n, n2, fy);
    }
    stries /= 3.0;

    // Le fond : un noir chaud à peine modelé par les stries.
    float v = 0.030 + 0.026 * stries;

    // Le reflet : une bande diagonale large, très douce — elle éclaire le
    // brossage plus qu'elle n'éclaire le fond (le métal se lit là).
    float axe = dot(uv, normalize(float2(0.42, 1.0)));
    float bande = exp(-pow((axe - 0.42) / 0.34, 2.0));
    v += bande * (0.030 + 0.050 * stries);

    // La vignette : les bords rendus à la nuit.
    float2 e = uv - float2(0.5, 0.46);
    v *= 1.0 - 0.55 * clamp(dot(e, e) * 1.9, 0.0, 1.0);

    // La teinte : un métal légèrement chaud, jamais bleu.
    float3 c = v * float3(1.03, 0.99, 0.94);
    return half4(half3(clamp(c, 0.0, 1.0)), 1.0) * color.a;
}

// La page de connexion : le même fond, plus deux choses. L'ombre du bloc
// texte — le cœur blanc monte juste derrière le titre et l'input, sans elle
// rien n'est lisible — et la caresse du doigt, portée du login aurora : de
// grosses lueurs douces qui suivent le doigt et meurent en s'évasant,
// blanches au contact, dorées dès 0,45 s, texturées par les rideaux.
// Triplets (x, y, âge en s) côté SwiftUI.
[[ stitchable ]] half4 bgAuroraLogin(float2 position, half4 color,
                                     float2 size, float t, float2 tilt,
                                     float2 cine,
                                     device const float *trail, int trailN) {
    float cur = 0.0;
    float3 c = bgField(position, size, t, tilt, BG_SHAPE_LOGIN,
                       BG_FOYERS_LOGIN, 0.0, cine, 1.0, cur);

    // PAS d'ombre de lisibilité : deux tentatives (0,42 puis 0,20 de force)
    // ont éteint la nappe orange de pleine largeur qui fait le fond —
    // verdict de Kathryn les deux fois : « t'as pas mis le nouveau
    // background ». Le titre est blanc, l'input et le bouton sont des pavés
    // sombres : tout le monde se défend seul sur la lumière.

    // La caresse : accumulée en niveau, teinte au prorata de l'âge, posée en
    // fondu écran — elle éclaire sans jamais écrêter, même sur le cœur blanc.
    float L = 0.0;
    float dor = 0.0;
    for (int i = 0; i + 2 < trailN; i += 3) {
        float2 tp = float2(trail[i], trail[i + 1]);
        float age = trail[i + 2];
        float amp = exp(-age / 0.65) * (1.0 - smoothstep(1.0, 1.4, age));
        if (amp < 0.01) continue;
        float sig = 55.0 + 80.0 * age;
        float2 dt2 = position - tp;
        float g = exp(-dot(dt2, dt2) / (sig * sig));
        float w = g * amp * 0.60 * (0.72 + 0.55 * cur);
        L += w;
        dor += w * clamp(age / 0.45, 0.0, 1.0);
    }
    if (L > 0.001) {
        float3 tt = mix(float3(1.00, 0.96, 0.88), float3(1.00, 0.78, 0.42),
                        clamp(dor / L, 0.0, 1.0));
        float vt = 1.0 - exp(-L * 1.70);
        c = 1.0 - (1.0 - c) * (1.0 - tt * vt);
    }

    c = bgDither(c, position, t);
    return half4(half3(c), 1.0) * color.a;
}


// MARK: - La dissolution de la lune
//
// Le tube de néon devient POUSSIÈRE : des centaines de braises naissent SUR
// l'arc du croissant, dans un balayage qui court le long du tube (la
// dissolution voyage, elle ne claque pas), dérivent en apesanteur pendant
// l'apnée, puis la gravité les reprend et elles retombent en arcs — la pluie
// d'étoiles des cartes swap, réappliquée à la lune. La page change DERRIÈRE
// ce nuage : il est le seul témoin de continuité, et la couture devient
// introuvable.
//
// Même inversion que `swapBurst` : le mouvement COMMUN (dérive + gravité) est
// retiré avant la recherche du secteur — ce qui reste est quasi radial autour
// du centre du croissant, donc un fragment ne teste que cinq secteurs.
//
// `e`     : l'horloge de la cérémonie (secondes depuis le tap).
// `moon`  : (centre x, centre y, rayon de l'arc du tube — en points écran).
// `tilt`  : la parallaxe de l'appareil, comme les poussières du fond.
//
// Les temps ci-dessous DOIVENT suivre ConnexionCine (Swift) : le balayage de
// dissolution, l'instant de la chute. Ils sont dupliqués sciemment — un
// uniform par constante coûterait plus qu'il ne protège.
constant float MD_SWEEP0 = 1.45;   // le balayage s'amorce…
constant float MD_SWEEP  = 0.60;   // …et court le long de l'arc
constant float MD_FALL   = 2.55;   // la gravité reprend le nuage
constant float MD_GRAV   = 150.0;  // pt/s² — une chute DOUCE
constant float MD_END    = 3.70;

[[ stitchable ]] half4 moonDust(float2 position, half4 color,
                                float2 size, float t, float e,
                                float3 moon, float2 tilt) {
    if (e < MD_SWEEP0 || e > MD_END) { return half4(0.0); }

    float2 C = moon.xy + tilt * 9.0;
    float R = max(moon.z, 8.0);

    // Le mouvement commun : une dérive de fumée qui monte à peine pendant
    // l'apesanteur, puis la chute — douce d'abord (la gravité "reprend" le
    // nuage, elle ne le lâche pas d'une falaise).
    float uf = max(e - MD_FALL, 0.0);
    float2 common = float2(0.0, -6.0 * min(e - MD_SWEEP0, 1.2))
                  + float2(0.0, 0.5 * MD_GRAV * uf * uf);

    float2 pc = position - C - common;
    float rc = length(pc);
    // Rejet grossier : la portée du nuage au moment courant.
    float reach = R + 90.0 * (e - MD_SWEEP0) + 40.0;
    if (rc > reach) { return half4(0.0); }

    const float SECTORS = 160.0;
    float ang = atan2(pc.y, pc.x);
    float sIdx = floor((ang + 3.14159265) / 6.2831853 * SECTORS);

    float3 c = float3(0.0);
    float a = 0.0;

    for (int k = -2; k <= 2; k++) {
        float s = sIdx + float(k);
        s = s - SECTORS * floor(s / SECTORS);
        for (int j = 0; j < 4; j++) {
            float4 h = bgHash42(float2(s * 1.71 + 3.7, 9.1 + 4.7 * float(j)));
            float th = (s + 0.5 + (h.z - 0.5) * 0.9) / SECTORS * 6.2831853
                       - 3.14159265;

            // Le CROISSANT : les braises naissent sur l'arc, denses côté dos
            // (à gauche), rares vers les pointes — la silhouette de la lune
            // se lit dans le nuage lui-même. `open` est l'angle du creux.
            float back = cos(th - 3.14159265);       // 1 au dos, -1 au creux
            float cres = smoothstep(-0.55, 0.25, back);
            if (h.w > 0.15 + 0.85 * cres) { continue; }

            // Le balayage : la dissolution part du DOS et court vers les
            // pointes, avec un peu de flottement par braise.
            float sweep = (1.0 - cres) * MD_SWEEP;
            float tb = MD_SWEEP0 + sweep + h.x * 0.22;
            float u = e - tb;
            if (u <= 0.0) { continue; }

            // L'arrachement : un souffle radial MINUSCULE qui décélère —
            // la lune ne explose pas, elle s'effrite.
            float speed = 14.0 + 34.0 * h.y;
            float drift = speed * u / (1.0 + 0.9 * u);
            float wob = sin(t * (0.8 + 1.4 * h.z) + h.w * 6.283) * 2.6;
            float rr = R * (0.86 + 0.28 * h.z) + drift + wob;
            float2 pos = float2(cos(th), sin(th)) * rr;
            float2 dp = pc - pos;
            float q = dot(dp, dp);
            if (q > 900.0) { continue; }

            // L'enveloppe : née dans le balayage, elle vit longtemps — la
            // fin n'arrive qu'avec la pluie posée.
            float life = clamp((e - tb) / (MD_END - tb), 0.0, 1.0);
            float env = min(u / 0.10, 1.0) * (1.0 - smoothstep(0.72, 1.0, life));
            float twk = 0.62 + 0.38 * sin(t * (1.6 + 3.8 * h.z) + h.y * 6.283);
            // Loi de puissance : une nuée de minuscules, quelques franches.
            float bright = 0.55 + 0.45 * pow(h.z, 2.2);
            float amp = env * twk * bright;
            if (amp < 0.004) { continue; }

            // La queue de comète, seulement quand ça TOMBE : alignée sur la
            // vitesse (dérive radiale mourante + gravité).
            float lum;
            float core = exp(-q / (0.92 * 0.92));
            if (uf > 0.02) {
                float2 vel = float2(cos(th), sin(th))
                             * (speed / ((1.0 + 0.9 * u) * (1.0 + 0.9 * u)))
                             + float2(0.0, MD_GRAV * uf);
                float vlen = max(length(vel), 1.0);
                float2 vu = vel / vlen;
                float along = dot(dp, vu);
                float across = dot(dp, float2(-vu.y, vu.x));
                float tl = 4.0 + 15.0 * clamp(vlen / 320.0, 0.0, 1.0);
                float trail = exp(-across * across / (0.50 * 0.50))
                              * exp(-max(-along, 0.0) / tl) * step(along, 0.0);
                lum = core + trail * 0.48;
            } else {
                lum = core;
            }

            // Une braise sur neuf ouvre une croix courte — le bijou.
            if (h.x > 0.89) {
                float rayL = 1.5 + 3.2 * env;
                lum += (exp(-dp.y * dp.y / (0.30 * 0.30)
                            - dp.x * dp.x / (rayL * rayL))
                        + exp(-dp.x * dp.x / (0.30 * 0.30)
                              - dp.y * dp.y / (rayL * rayL))) * 0.40;
            }

            // Blanches-crème à la naissance (le tube), or puis braise en
            // tombant — la couleur RACONTE le refroidissement.
            float3 tint = mix(float3(1.00, 0.95, 0.86),
                              float3(1.00, 0.64, 0.22),
                              clamp(life * 1.5, 0.0, 1.0));
            float g = lum * amp;
            c += tint * g;
            a += g;
        }
    }

    // L'arc encore allumé : la part du tube que le balayage n'a pas prise
    // brille toujours — c'est LUI qui couvre le fondu du monolithe. Il
    // s'éteint du dos vers les pointes, exactement au rythme des naissances.
    float back = cos(ang - 3.14159265);
    float cres = smoothstep(-0.55, 0.25, back);
    float lit = step(e, MD_SWEEP0 + (1.0 - cres) * MD_SWEEP);
    float ring = exp(-pow(fabs(rc - R), 2.0) / (3.2 * 3.2))
               * cres * lit * smoothstep(MD_END, MD_SWEEP0, e);
    c += float3(1.00, 0.58, 0.18) * (ring * 0.85);
    c += float3(1.00, 0.88, 0.62) * (exp(-pow(fabs(rc - R), 2.0) / 1.1) * cres * lit * 0.85);
    a += ring * 0.8;

    // Fondu d'hôte + couleur = couverture (émissif) : les leçons payées.
    float2 toEdge = min(position, size - position);
    float hostFade = smoothstep(0.0, 60.0, min(toEdge.x, toEdge.y));
    a = clamp(a * 3.4, 0.0, 1.0) * hostFade;
    c = clamp(c, 0.0, 1.0) * a;
    return half4(half3(c), half(a)) * color.a;
}
