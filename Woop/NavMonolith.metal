#include <metal_stdlib>
using namespace metal;

// MARK: - Barre d'onglets « monolithe » — obsidienne + fil de métal liquide
//
// Deux formes, deux matières, une seule passe :
//
//   1. LA BARRE — une capsule d'obsidienne. Noir profond, presque opaque, dont
//      tout l'intérêt tient à un spéculaire très LARGE et très FAIBLE (3 %)
//      accroché à l'arête haute-gauche. C'est ce 3 % qui fait « piano black »
//      plutôt que « sticker gris » : au-delà, la pierre devient du plastique.
//
//   2. LA PASTILLE — l'onglet sélectionné, cerclé d'un fil de MÉTAL LIQUIDE.
//      Elle voyage d'un onglet à l'autre ; la barre, elle, ne bouge jamais.
//
// Le fil n'est pas éclairé. Pas de normale, pas de matcap, pas de fresnel :
// c'est un train de rayures échantillonné en dents de scie, dont la coordonnée
// ACCÉLÈRE à l'approche du contour (`dir -= 1.7 * edge * contour`). Les rayures
// s'y compriment, et cette compression seule LIT comme un fil rond de chrome
// qui reflète tout un studio. Portage de la recette Paper Design (liquid-metal),
// où le champ de bord arrive par une texture ; ici la pastille est une capsule
// analytique, donc `edge` sort directement du SDF — ni texture, ni ratio.
//
// Les éclats orange bordés de bleu : les trois canaux échantillonnent la MÊME
// dent de scie à trois décalages minuscules. Là où la marche est raide, ils
// tombent de part et d'autre — orange d'un côté, bleu de l'autre. La dispersion
// n'existe QUE sur des transitions dures : `softness` haut la tue.
//
// La vue passe un rectangle PLUS GRAND que la barre (marge `pad`) : l'ombre
// portée vit dehors, en alpha.

static float nhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float nnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = nhash21(i);
    float b = nhash21(i + float2(1.0, 0.0));
    float c = nhash21(i + float2(0.0, 1.0));
    float d = nhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float nfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * nnoise(p);
        p = p * 2.07 + float2(11.7, 5.3);
        a *= 0.5;
    }
    return v;
}

/// Distance signée au rectangle arrondi (négatif dedans). `r = b.y` → capsule.
static float nsdRound(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Une dent de scie devenue bande douce. On passe par un TRIANGLE avant le
/// seuil : la dent de scie brute casse net au raccord (aliasing garanti sur un
/// fil de 3 pt à 3x), le triangle est continu partout et reste symétrique — un
/// reflet n'a pas de sens de lecture.
static float nstripe(float s, float soft) {
    float w = 0.5 * soft + 0.006;
    float tri = fabs(s * 2.0 - 1.0);
    return smoothstep(0.5 - w, 0.5 + w, tri);
}

/// Densité linéaire (color burn). Teinté par l'or, un chrome moyen tombe en
/// ambre et un chrome vif reste blanc : c'est exactement le comportement d'un
/// miroir doré, blanc au rasant et or dans le corps. Une rampe jaune peinte à
/// la main ne fait jamais ça.
static float nburn(float c, float tint) {
    return 1.0 - min(1.0, (1.0 - c) / max(tint, 1e-4));
}

// `pill`  = (centre x dans le repère barre, demi-largeur, demi-hauteur, press)
// `mtl`   = (repetition, angle en radians, softness, contour)
// `mtl2`  = (distortion, speed, shiftRed, shiftBlue)
// `look`  = (influence du bord W, dose d'or, demi-largeur du fil, buée)
// `floorLvl` = le plancher du fil. Un métal ne tombe JAMAIS au noir : il
//              reflète un environnement sombre, ce qui est très différent d'un
//              trou. Sans plancher, l'anneau se lit troué, en pointillés.
[[ stitchable ]] half4 navMonolith(float2 position, half4 color,
                                   float2 size, float t, float pad,
                                   float4 pill, float4 mtl, float4 mtl2,
                                   float4 look, float floorLvl) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float d = nsdRound(p, halfB, halfB.y);
    float inside = smoothstep(0.7, -0.7, d);

    float ux = clamp((p.x + halfB.x) / (2.0 * halfB.x), 0.0, 1.0);
    float uy = clamp((p.y + halfB.y) / (2.0 * halfB.y), 0.0, 1.0);

    float3 rgb = float3(0.0);

    // ---- LA PIERRE ------------------------------------------------------
    if (inside > 0.0) {
        // Socle : #16171A en haut → #050507 en bas, en gamma d'affichage. Le
        // dégradé est COURT — une pierre, pas un ciel.
        float3 top = float3(0.0863, 0.0902, 0.1020);
        float3 bot = float3(0.0196, 0.0196, 0.0275);
        float g = uy * uy * (3.0 - 2.0 * uy);
        float3 base = mix(top, bot, g);

        // Le dôme : un glow INTÉRIEUR qui colle à la paroi, pondéré haut-gauche.
        // Il suit donc la courbe des calottes au lieu de barrer la capsule d'un
        // dégradé linéaire — c'est ce qui donne le galet poli.
        float wall = exp(-max(-d, 0.0) / 3.4);
        float upleft = clamp(0.64 * (1.0 - uy) + 0.36 * (1.0 - ux), 0.0, 1.0);
        float sheen = wall * pow(upleft, 2.0) * 0.125;

        // Nappe large sous l'arête haute : la source est loin, au-dessus.
        float dome = exp(-uy * 4.6) * (0.48 + 0.52 * (1.0 - ux)) * 0.040;

        // La vignette : le bas et les flancs rentrent au noir vrai. Sans elle,
        // la capsule est une plaque ; avec, elle se creuse.
        float vig = 1.0 - 0.40 * smoothstep(0.42, 1.0, uy)
                        - 0.12 * smoothstep(0.58, 1.0, fabs(ux * 2.0 - 1.0));
        vig = clamp(vig, 0.0, 1.0);

        // Le liseré noir : une bande PLUS SOMBRE que la pierre, juste en dedans
        // de l'arête. Sans elle, la capsule est une découpe posée sur la page ;
        // avec, elle a une tranche, et le hairline du dessus a enfin quelque
        // chose contre quoi briller.
        float bevel = exp(-max(-d, 0.0) / 2.0);
        float3 stone = base * vig * (1.0 - 0.52 * bevel) + sheen + dome;

        // Le gloss des calottes : les deux bouts attrapent une lumière rasante,
        // le gauche un peu plus que le droit. C'est ce qui dit que la capsule
        // TOURNE aux extrémités au lieu de s'arrêter net.
        float sideness = pow(clamp(fabs(ux * 2.0 - 1.0), 0.0, 1.0), 3.2);
        stone += bevel * sideness * (0.60 + 0.40 * (1.0 - ux)) * 0.115;

        rgb = stone * inside;
    }

    // ---- LE LISERÉ DE LA BARRE ------------------------------------------
    // Un hairline argent, presque rien, vivant seulement sur l'arête haute.
    // La barre ne porte PAS d'or : tout l'or appartient à la pastille. C'est
    // cette retenue qui fait le bijou — deux liserés dorés, et c'est un jouet.
    float topness = clamp(-p.y / max(halfB.y, 1.0), 0.0, 1.0);
    float capAmt = 0.008 + 0.105 * pow(topness, 2.2);
    float capLine = exp(-d * d / (0.62 * 0.62)) * capAmt;
    rgb += capLine * float3(0.86, 0.89, 0.95);

    // ---- LA PASTILLE ----------------------------------------------------
    float2 q = p - float2(-halfB.x + pill.x, 0.0);
    float2 pb = max(float2(pill.y, pill.z), float2(1.0));
    float dp = nsdRound(q, pb, pb.y);
    float adp = fabs(dp);
    float press = pill.w;

    // Le puits : l'intérieur de la pastille est LÉGÈREMENT plus clair que la
    // pierre autour — une cuvette qui attrape l'ambiance, plus lumineuse en
    // haut. Deux pour cent, pas davantage.
    float pin = smoothstep(0.8, -0.8, dp);
    float wy = clamp((q.y + pb.y) / (2.0 * pb.y), 0.0, 1.0);
    // Pas de `* inside` : sous le doigt la pastille GROSSIT jusqu'à déborder de
    // la capsule, et ce qui dépasse doit exister — pierre et cerne compris.
    // Clippée à la barre, elle se ferait trancher net à l'arête.
    rgb += pin * (0.030 + 0.034 * (1.0 - wy) + 0.014 * press);

    // ---- LE FIL DE MÉTAL LIQUIDE ----------------------------------------
    float W = max(look.x, 0.5);
    float n = nfbm(q * 0.055 + float2(t * 0.09, -t * 0.07)) - 0.5;

    // `edge` : le champ de bord (le canal R de la texture, chez Paper). Une
    // crête centrée sur le fil, qui retombe sur W points de part et d'autre.
    float edge = 1.0 - smoothstep(0.0, W, adp);
    edge += (1.0 - edge) * mtl2.x * n;
    edge = clamp(edge, 0.0, 1.0);

    // La coordonnée rayée. Trois termes : une rampe directionnelle qui défile,
    // la COMPRESSION au contour (le cœur de l'effet), et une ondulation qui ne
    // vit que dans l'épaisseur du fil — `edge * (1 - edge)` s'annule au centre
    // comme au loin, donc le métal coule sur ses flancs sans jamais baver.
    //
    // La rampe est normalisée par la HAUTEUR de la pastille, et l'axe est
    // quasi vertical : on veut environ une période et demie du haut au bas du
    // cerne, et presque rien en travers. C'est ce qui donne les deux lobes
    // horizontaux du chrome — arête haute vive, flancs éteints, arête basse
    // rallumée par le rebond. Normalisée sur le grand axe, la pastille reçoit
    // moins d'une période sur toute sa hauteur et le fil se lit en croissant
    // de lune ; normalisée sur la hauteur avec une répétition forte, c'est un
    // zèbre. La fenêtre utile est étroite : `repetition` autour de 0,8.
    float scale = max(pb.y, 1.0);
    float2 axis = float2(cos(mtl.y), sin(mtl.y));
    float dir = dot(q / scale, axis) * mtl.x;
    dir -= t * mtl2.y;
    dir -= 1.7 * edge * mtl.w;
    dir -= 2.5 * n * (edge * (1.0 - edge));

    float soft = mtl.z;
    float3 chrome = float3(nstripe(fract(dir + mtl2.z), soft),
                           nstripe(fract(dir), soft),
                           nstripe(fract(dir - mtl2.w), soft));

    // Le plancher, AVANT la teinte : l'or doit brûler un métal qui a déjà son
    // ambiance, sinon les creux virent au brun sale.
    float fl = clamp(floorLvl, 0.0, 1.0);
    chrome = fl + (1.0 - fl) * chrome;

    // L'or, en densité linéaire.
    float3 gold = float3(1.000, 0.780, 0.340);
    float3 burned = float3(nburn(chrome.r, gold.r),
                           nburn(chrome.g, gold.g),
                           nburn(chrome.b, gold.b));
    chrome = mix(chrome, burned, clamp(look.y, 0.0, 1.0));

    // La bande visible : un plateau, pas une gaussienne — il faut de la place
    // pour que la structure du fil (vif / ligne sombre / vif) se lise.
    float lw = max(look.z, 0.3);
    float band = 1.0 - smoothstep(lw * 0.70, lw * 1.55, adp);

    // Anisotropie : le haut du cerne prend la source, le bas récupère le rebond
    // du sol — deux lobes, pas un. Un anneau d'égale luminosité tout autour est
    // un contour vectoriel ; un anneau à un seul lobe est un croissant de lune.
    // C'est la seconde cloche, en bas, qui referme l'objet.
    float tq = clamp(-q.y / pb.y, 0.0, 1.0);
    float lift = 0.26 + 0.62 * pow(tq, 1.15) + 0.30 * pow(1.0 - tq, 2.4);
    float arc = atan2(q.y, q.x);
    float breath = 0.82 + 0.18 * sin(t * 0.55 + arc * 2.0);

    float ringAmt = band * lift * breath * (1.0 + 0.50 * press);
    rgb += chrome * ringAmt;

    // La buée : très courte, collée au fil. Au-delà de ~3 pt ce n'est plus un
    // sertissage, c'est du néon.
    float halo = exp(-max(adp - lw, 0.0) / 2.6) * look.w * lift * (1.0 + 0.6 * press);
    rgb += chrome * halo * 0.30;

    // ---- LE TRAIT NOIR --------------------------------------------------
    // Un contour SERRÉ, juste dehors, qui cerne la capsule sur tout son tour.
    // Ce n'est pas l'ombre portée — celle-ci est large, orientée vers le bas et
    // ne dit que la hauteur de vol. Le trait, lui, est un liseré de ~1,5 pt qui
    // détache la pierre du fond PARTOUT, y compris là d'où vient la lumière :
    // sans lui, l'arête haute se dissout dans la page et la capsule perd son
    // bord franc. Il part 0,8 pt dehors pour laisser le hairline d'argent
    // occuper l'arête sans être mangé.
    float outline = exp(-max(d - 0.8, 0.0) / 1.6) * (1.0 - inside) * 0.88;

    // ---- LA LUMIÈRE SUR LE TRAIT ----------------------------------------
    // Les deux bouts du liseré noir attrapent un lustre, ÉTIRÉ verticalement :
    // une traînée, pas un point. C'est la signature du plastique noir poli —
    // une matière molle rend une source large et l'étale le long de sa
    // courbure, là où un métal la rendrait en éclat serré. Le foyer est posé un
    // peu au-dessus du milieu, comme la source de la référence.
    float sideness = pow(clamp(fabs(ux * 2.0 - 1.0), 0.0, 1.0), 4.0);
    float smear = exp(-pow(fabs(uy - 0.40) * 2.4, 1.7));
    // Serré contre le trait : étalé, le lustre cesse d'être une peau et devient
    // un halo — la faute qui transforme n'importe quel sertissage en néon.
    float lustre = exp(-fabs(d - 0.5) / 1.15) * sideness * smear;
    rgb += lustre * float3(0.88, 0.91, 0.98) * 0.30;
    // Un cœur plus serré au creux de la traînée : sans lui le lustre est une
    // brume, avec lui la matière a une peau.
    rgb += exp(-fabs(d - 0.3) / 0.8) * sideness * pow(smear, 2.6)
           * float3(0.96, 0.97, 1.0) * 0.22;

    // ---- L'OMBRE PORTÉE -------------------------------------------------
    float shadow = exp(-max(d - 2.0, 0.0) / 22.0) * (1.0 - inside)
                 * (0.26 + 0.62 * smoothstep(-0.2, 0.9, uy)) * 0.60;
    shadow = max(shadow, outline);

    // Dither : un demi-niveau. Sans lui, un dégradé de 2 % bande atrocement
    // sur OLED — et toute la matière est faite de dégradés de 2 %.
    rgb += (nhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
           * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);

    float lum = max(max(rgb.r, rgb.g), rgb.b);
    // `pin` entre dans l'alpha : la part de pastille qui dépasse de la capsule
    // doit être OPAQUE (sa pierre est noire, donc invisible sans alpha propre).
    float a = clamp(max(max(inside, pin), max(lum * 1.6, shadow)), 0.0, 1.0);
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}
