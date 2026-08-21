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
/// Le rayon est BRIDÉ aux deux demi-côtés : au-delà, la formule ne rend plus
/// une boîte arrondie mais une VESICA — deux arcs de cercle qui se coupent en
/// pointes sur le petit côté. C'est ce qui pinçait la pastille dès que sa
/// demi-hauteur dépassait sa demi-largeur, et l'ovalisait sous le doigt.
static float nsdRound(float2 p, float2 b, float r) {
    r = min(r, min(b.x, b.y));
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Triangle équilatéral, apex vers le BAS dans un repère y-haut (recette iq).
static float nsdTri(float2 p, float r) {
    const float k = 1.7320508;
    p.x = fabs(p.x) - r;
    p.y = p.y + r / k;
    if (p.x + k * p.y > 0.0) p = float2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
    p.x -= clamp(p.x, -2.0 * r, 0.0);
    return -length(p) * sign(p.y);
}

/// Le glyphe play : le même triangle, tourné pointe à DROITE, puis arrondi par
/// soustraction. Notre y DESCEND — le quart de tour se prend donc dans l'autre
/// sens qu'en repère mathématique, et c'est exactement le piège : le signe
/// inverse donne un triangle qui pointe à gauche, soit un bouton « retour ».
/// Le décalage `0.14 r` recentre le glyphe OPTIQUEMENT : un triangle posé sur
/// son centre géométrique penche toujours du côté de son dos.
static float nsdPlay(float2 p, float r, float round) {
    float2 q = float2(p.y, p.x - r * 0.14);
    return nsdTri(q, r) - round;
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
// `play`     = (centre x dans le repère barre, remontée y, rayon, grésillement).
//              Un rayon nul éteint tout le bloc : la barre d'origine, intacte.
// `playMtl`  = (dureté du lobe spéculaire, chanfrein en pt, rayon du glyphe,
//               force du rasant du galet)
// `playRing` = (demi-largeur de l'anneau, sa dose, l'allumage 0→1, la buée)
// `playFx`   = (arrondi du glyphe, vitesse du grésillement, sa blancheur, —)
[[ stitchable ]] half4 navMonolith(float2 position, half4 color,
                                   float2 size, float t, float pad,
                                   float4 pill, float4 mtl, float4 mtl2,
                                   float4 look, float floorLvl,
                                   float4 play, float4 playMtl, float4 playRing,
                                   float4 playFx) {
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

    // ---- LE BOUTON PLAY -------------------------------------------------
    // Un galet noir SATINÉ dans lequel le glyphe play est EXTRUDÉ en laque
    // noire. Tout le secret tient là : le galet est MAT, le glyphe est
    // BRILLANT. Un disque brillant partout se lit en plastique ; c'est le
    // contraste mat/laqué qui donne le noir profond de la référence, où
    // presque tout est noir et où le liseré spéculaire SEUL dessine la forme.
    float playA = 0.0;
    if (play.z > 0.5) {
        float R = play.z;
        float2 qb = p - float2(-halfB.x + play.x, -play.y);
        float rr = length(qb);
        float dd = rr - R;

        // L'ombre du galet SUR la pierre : il flotte au-dessus de la barre, il
        // doit s'y poser. Peinte avant le disque, sinon elle passe dessus.
        rgb *= 1.0 - exp(-max(dd - 1.0, 0.0) / 9.0) * 0.47;

        // --- le galet, mat ---
        float din = smoothstep(0.7, -0.7, dd);
        float ux2 = clamp(qb.x / R * 0.5 + 0.5, 0.0, 1.0);
        float uy2 = clamp(qb.y / R * 0.5 + 0.5, 0.0, 1.0);
        float3 pbase = mix(float3(0.0980, 0.1020, 0.1137),
                           float3(0.0157, 0.0157, 0.0196),
                           uy2 * uy2 * (3.0 - 2.0 * uy2));
        // Le dôme intérieur colle à la paroi, pondéré haut-gauche : c'est lui
        // qui fait le galet POLI plutôt que le rond découpé.
        float pwall = exp(-max(-dd, 0.0) / (R * 0.34));
        float pupleft = clamp(0.62 * (1.0 - uy2) + 0.38 * (1.0 - ux2), 0.0, 1.0);
        float3 stone2 = pbase * (1.0 - 0.34 * pwall)
                      + pwall * pow(pupleft, 2.2) * 0.10;
        // Le rasant : l'anneau extérieur du galet attrape la lumière au bord.
        // C'est LUI, le « un peu plus de reflet » — la capsule plafonne à 3 %
        // de spéculaire, le galet monte à ~9 %. Même famille, un cran au-dessus.
        stone2 += pow(clamp(rr / R, 0.0, 1.0), 6.0) * playMtl.w
                  * (0.45 + 0.55 * (1.0 - uy2)) * float3(0.84, 0.87, 0.94);

        // --- le glyphe, laqué ---
        float gr = max(playMtl.z, 1.0);
        // Le chanfrein ne peut pas AVALER le glyphe : au-delà de ~45 % du
        // rayon, le triangle n'est plus qu'un galet dans le galet et le play
        // cesse de se lire. Ce plafond est ce qui garde la forme reconnaissable
        // quand on pousse le bourrelet de laque à fond.
        float ch = clamp(playMtl.y, 0.3, gr * 0.45);
        float rnd = gr * clamp(playFx.x, 0.0, 0.35);
        float dg = nsdPlay(qb, gr, rnd);
        // Gradient du SDF — unitaire par construction, donc échantillonné à pas
        // FIXE en points. Jamais `dfdx` : sur un chanfrein d'un point à 3x, une
        // dérivée d'écran ne rend que du bruit.
        float e = 0.30;
        float2 gn = normalize(float2(
            nsdPlay(qb + float2(e, 0.0), gr, rnd) - nsdPlay(qb - float2(e, 0.0), gr, rnd),
            nsdPlay(qb + float2(0.0, e), gr, rnd) - nsdPlay(qb - float2(0.0, e), gr, rnd))
            + float2(1e-5, 0.0));
        // Chanfrein en quart-de-rond : la normale bascule de l'horizontale au
        // contour jusqu'à la verticale sur le plat du glyphe.
        float uch = clamp(-dg / ch, 0.0, 1.0);
        float nxy = sqrt(max(1.0 - uch * uch, 0.0));
        float3 nrm = normalize(float3(gn * nxy, uch + 0.02));

        // Deux sources, comme la pierre : une large en haut-gauche, un rebond
        // faible en bas-droite. L'exposant ÉNORME fait la laque — sous ~150
        // c'est du métal brossé, pas de l'émail.
        float3 V = float3(0.0, 0.0, 1.0);
        float3 H1 = normalize(normalize(float3(-0.52, -0.66, 0.54)) + V);
        float3 H2 = normalize(normalize(float3(0.46, 0.60, 0.46)) + V);
        float gloss = max(playMtl.x, 4.0);
        float spec = pow(max(dot(nrm, H1), 0.0), gloss)
                   + pow(max(dot(nrm, H2), 0.0), gloss * 0.40) * 0.30;
        // Genou doux : un lobe aussi dur écrête en escalier sur quatre pixels.
        // `x/(1+x)` le couche sans lui prendre son nerf.
        spec = spec / (1.0 + 0.55 * spec);

        // Le noir de la laque n'est pas plat : il renvoie l'ambiance du dôme.
        float3 lacquer = float3(0.0196, 0.0208, 0.0235)
                       + pwall * pow(pupleft, 2.4) * 0.030;
        float gin = smoothstep(0.55, -0.55, dg);
        float3 pcol = mix(stone2, lacquer + spec * float3(0.94, 0.96, 1.00) * 1.15,
                          gin);

        // --- LA LAMPE ---------------------------------------------------------
        // PAS de grésillement. Un tube qui accroche se lit comme une PANNE, pas
        // comme une invitation : l'œil est câblé pour lire une lumière qui saute
        // comme un défaut, et le bouton a alors l'air cassé. Ce qu'il faut, c'est
        // une respiration — continue, sans accident, qui ne redescend jamais à
        // zéro. Deux sinus incommensurables suffisent : l'œil n'y entend aucune
        // période, et n'y voit aucune saccade.
        //
        // Et TOUT part du triangle. Le glyphe n'est pas un pictogramme qu'on
        // colorie : c'est LA SOURCE. Un cœur qui sature en blanc, l'orange qui
        // reprend la main en s'en éloignant, une seule nappe continue qui
        // traverse la laque, éclaire le galet mat par en dedans, puis va mourir
        // sur la page. Le triangle rempli d'un aplat — mesuré à R = 0,710
        // CONSTANT sur dix-huit points de large, plafonné par le fondu écran —
        // ne lisait pas comme une lampe : une lampe a un cœur surexposé, et
        // c'est le contraste cœur/bord qui fait la lumière, jamais l'intensité
        // moyenne.
        float ign = clamp(playRing.z, 0.0, 1.0);
        float sz = clamp(play.w, 0.0, 1.0);
        float vs = max(playFx.y, 0.05);
        // LES HORLOGES. Elles battaient à 10,1 s et 15,3 s : à cette lenteur, la
        // lampe ne « clignote » plus du tout — on peut regarder le bouton dix
        // secondes sans rien voir bouger, et l'invite n'existe pas. 2,6 s et
        // 4,2 s : un cœur au repos. Toujours deux périodes incommensurables,
        // toujours des sinus — c'est ce qui sépare une respiration d'un
        // grésillement (refusé : « ça fait bug »).
        float a1 = 0.5 + 0.5 * sin(t * 2.42 * vs);
        float a2 = 0.5 + 0.5 * sin(t * 1.49 * vs + 2.1);
        // Et le plancher descend de 0,68 à 0,55 : il faut voir la lumière
        // MONTER. Jamais zéro pour autant — une lampe qui s'éteint se lit comme
        // une panne, pas comme une invitation.
        float lvl = 0.55 + 0.30 * a1 + 0.15 * a2;
        float amp = max(sz * lvl, ign);
        float aura = max(ign, sz * lvl);
        // La teinte dérive lentement de l'orange au blanc chaud, sur la seconde
        // horloge : le glyphe change de TEMPÉRATURE, pas de luminosité — c'est
        // beaucoup plus doux à l'œil qu'une pulsation d'intensité.
        float blanc = clamp(playFx.z * (0.30 + 0.55 * a2) + ign, 0.0, 1.0);
        // Le SDF du glyphe, normalisé par son rayon : UNE seule coordonnée pour
        // tout le champ de lumière, dedans comme dehors.
        float dgn = dg / max(gr, 1.0);
        float core = smoothstep(0.12, -0.55, dgn);
        float3 chaud = float3(1.00, 0.50, 0.11);
        float3 blancChaud = float3(1.00, 0.96, 0.90);
        if (amp > 0.001) {
            float3 fire = mix(chaud, blancChaud,
                              clamp(0.30 + 0.90 * blanc, 0.0, 1.0) * core);
            // Le cœur POUSSE au-delà de 1 avant d'être écrêté : c'est cette
            // surexposition, et elle seule, qui fait lire une source plutôt
            // qu'une surface teintée. Le facteur est dosé pour qu'au CREUX de la
            // respiration il retombe SOUS l'écrêtage : sinon le cœur reste collé
            // à 1 tout le temps et la lampe cesse de battre.
            float lampe = clamp(amp * (0.45 + 1.30 * core), 0.0, 1.0);
            // Fondu écran, jamais une addition : la leçon du login — une
            // addition écrête et le blanc devient une tache plate.
            pcol = 1.0 - (1.0 - pcol) * (1.0 - fire * (lampe * gin));
            // Le galet s'éclaire PAR son glyphe. La nappe décroît sur ~1,15
            // rayon de glyphe (13 pt) au lieu de 0,42 (4,6 pt) : elle traverse
            // la pierre entière au lieu de s'arrêter au chanfrein, et c'est ce
            // noir HABITÉ — pas un anneau — qui pose le bouton sur la page.
            float bleed = exp(-max(dgn, 0.0) / 1.15) * (1.0 - gin);
            pcol = 1.0 - (1.0 - pcol)
                   * (1.0 - mix(chaud, fire, 0.30) * (bleed * amp * 0.46));
        }

        rgb = mix(rgb, pcol, din);

        // --- PAS D'ANNEAU AU REPOS -------------------------------------------
        // Le fil de métal liquide était rallumé EN PERMANENCE par le souffle :
        // `playRing.y + 0,50 × aura`, avec `aura` ≈ 0,5 à 0,7 même au repos. Le
        // curseur « anneau » était donc à zéro et le liseré doré s'affichait
        // quand même — mesuré à L = 0,478 juste dehors contre 0,341 quatre
        // points plus loin, un fil de deux points tout autour du galet.
        // Verdict : « il ne faut pas de contour métal ». L'anneau et sa buée
        // n'obéissent plus qu'à leurs curseurs, tous deux à zéro par défaut :
        // le galet se tient par son rasant et par sa lampe, pas par un
        // sertissage. Le banc (`-navLab`) peut toujours les rallumer.
        float add = fabs(dd);
        float rw = max(playRing.x, 0.3);
        float ringAmt = 0.0, phalo = 0.0;
        if (playRing.y > 0.001 || playRing.w > 0.001) {
            float rdir = dot(qb / max(R, 1.0), axis) * mtl.x * 1.30 - t * mtl2.y
                       - 1.7 * (1.0 - smoothstep(0.0, W, add)) * mtl.w;
            float3 rchrome = float3(nstripe(fract(rdir + mtl2.z), soft),
                                    nstripe(fract(rdir), soft),
                                    nstripe(fract(rdir - mtl2.w), soft));
            rchrome = fl + (1.0 - fl) * rchrome;
            rchrome = mix(rchrome, float3(nburn(rchrome.r, gold.r),
                                          nburn(rchrome.g, gold.g),
                                          nburn(rchrome.b, gold.b)),
                          clamp(look.y, 0.0, 1.0));
            float rtq = clamp(-qb.y / max(R, 1.0), 0.0, 1.0);
            ringAmt = (1.0 - smoothstep(rw * 0.70, rw * 1.55, add))
                    * (0.30 + 0.58 * pow(rtq, 1.15) + 0.26 * pow(1.0 - rtq, 2.4))
                    * playRing.y;
            phalo = exp(-max(add - rw, 0.0) / 2.6) * playRing.w;
            rgb += rchrome * (ringAmt + phalo * 0.34);
        }

        // L'INVITE : la nappe large et très douce qui déborde sur la page. Elle
        // ne cerne pas le bouton — elle est la CONTINUATION de la lampe du
        // glyphe une fois la pierre traversée, même teinte, même respiration.
        // Sa portée passe de 18 à 26 pt : sous ~20 pt ce n'est plus une nappe,
        // c'est un contour, et c'est précisément ce qui la faisait lire comme un
        // sertissage de plus. Elle ne vit que DEHORS (`1 - din`), sinon elle
        // laiterait le galet et tuerait son noir.
        // Elle RESPIRE avec le glyphe, et franchement : son amplitude suit le
        // CARRÉ de la respiration (rapport 2,2 entre creux et crête au lieu de
        // 1,25 — à 1,25 personne ne voit rien), et sa portée enfle avec elle,
        // donc la nappe avance et recule au lieu de seulement pâlir.
        float appel = clamp(aura, 0.0, 1.0);
        float invite = exp(-max(add, 0.0)
                           / (playFx.w * 130.0 * (0.72 + 0.38 * appel)
                              + 40.0 * ign))
                     * (0.05 + 0.36 * appel * appel) * (1.0 - din);
        rgb += mix(chaud, blancChaud, blanc) * (invite * playFx.w * 6.5);

        playA = max(din, max(max(ringAmt, phalo * 0.7), invite * 1.2));
    }

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
    // COURTE. Sur l'ancienne home noire une ombre de 22 pt de constante ne se
    // voyait pas ; sur l'aurore embrasée c'est un lavis NOIR sur un sol
    // incandescent, et le rectangle du shader le tranchait net. Elle se réduit
    // donc à un contact — 9 pt, un tiers de la force. Ce qui détache la capsule
    // sur ce fond, ce n'est de toute façon pas son ombre : c'est son noir.
    float shadow = exp(-max(d - 2.0, 0.0) / 9.0) * (1.0 - inside)
                 * (0.26 + 0.62 * smoothstep(-0.2, 0.9, uy)) * 0.34;
    shadow = max(shadow, outline);

    // Dither : un demi-niveau. Sans lui, un dégradé de 2 % bande atrocement
    // sur OLED — et toute la matière est faite de dégradés de 2 %.
    rgb += (nhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
           * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);

    float lum = max(max(rgb.r, rgb.g), rgb.b);
    // `pin` entre dans l'alpha : la part de pastille qui dépasse de la capsule
    // doit être OPAQUE (sa pierre est noire, donc invisible sans alpha propre).
    //
    // La lumière molle, elle, porte sa PROPRE couverture — pas 1,6 fois. Au
    // delà, le shader retire au fond plus qu'il ne lui ajoute : sur l'aurore
    // blanche de la home, le halo du galet devenait un voile beige (mesuré :
    // (1,00 0,99 0,97) qui tombe à (0,90 0,82 0,73) — il ASSOMBRISSAIT le sol
    // qu'il était censé éclairer). Couleur = couverture : ça éclaire, ça ne
    // salit pas. C'est la règle de `swapCard`, elle vaut ici aussi.
    float a = clamp(max(max(max(inside, pin), playA),
                        max(lum, shadow)), 0.0, 1.0);

    // ---- LE FONDU D'HÔTE ------------------------------------------------
    // Toute la lumière et toute l'ombre meurent AVANT le bord du rectangle.
    // Sans lui elles butent dessus et la barre porte une PLAQUE rectangulaire :
    // mesurée au pixel sur la home, une cassure franche à y = 702 pt — le haut
    // exact du rectangle — l'aurore pure au-dessus, voilée en dessous, en
    // travers de tout l'écran. C'est la leçon déjà écrite dans `swapCard`
    // (AuroraHome.metal) : le débord se dissout, il ne se coupe jamais.
    // La capsule, la pastille et le galet vivent tous à plus de 40 pt du bord :
    // le fondu ne les touche pas, il n'éteint que ce qui déborde.
    // La bande de fondu vaut 0,42 × `pad` : assez large pour éteindre sans
    // marche, assez étroite pour laisser à la nappe du galet une vingtaine de
    // points de pleine amplitude au-dessus de lui. Plus large, elle mangeait
    // l'invite ; plus étroite, le fondu redevenait une arête.
    float2 toEdge = min(position, size - position);
    float host = smoothstep(0.0, pad * 0.42, min(toEdge.x, toEdge.y));
    rgb *= host;
    a *= host;
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}

// MARK: - LE SLIDER OBSIDIENNE — la capsule longue et son pouce de chrome
//
// Même fichier que la barre, EXPRÈS : les huit helpers du dessus sont `static`
// (linkage interne, ils ne traversent pas les fichiers). Un `.metal` neuf les
// obligerait à être dupliqués, et deux tables qui divergent d'un pouième
// donnent deux matières différentes à l'œil. La parenté avec la nav bar est
// ici une propriété du code, pas une intention.
//
// Le pouce est le bloc `navMonolith:188-272` REPRIS TEL QUEL — c'est « le
// shader liquid glass de la navbar » : les trois canaux échantillonnent la
// même dent de scie à trois décalages minuscules, et les franges orange
// bordées de bleu tombent toutes seules sur deux arcs opposés. Un seul
// réglage change : l'or passe à zéro. La référence montre du CHROME.
//
// La piste, elle, est mesurée au pixel sur la référence de Kathryn
// (~/Downloads/woop-slider/ref.png, relevé complet dans SPEC-REF.md). Trois
// faits, et ils font toute la matière :
//
//   1. LE FOND est un voile blanc de 9,4 % en haut qui MEURT à 60 % de la
//      hauteur. La moitié basse est du noir ABSOLU — plus noir que la page.
//      C'est ce noir-là qui fait la profondeur, pas un dégradé qui traverse.
//   2. LE BORD est un anneau d'obsidienne pure de 5 % de la hauteur. Il ne se
//      voit qu'en HAUT (en bas le fond est déjà noir, il n'a rien à trancher)
//      — d'où la lecture « border très sombre » qui semble n'être qu'en haut.
//   3. LA LUMIÈRE DES FLANCS est un lobe étroit qui culmine à 30° AU-DESSUS
//      de l'horizontale, symétrique gauche/droite, éteint avant le sommet.
//      Elle vit DANS l'anneau, par-dessus : c'est elle qui le ronge par
//      l'intérieur sur les calottes et le laisse entier sur l'arête haute.
//      Un liseré d'égale intensité tout autour ferait un contour vectoriel.
//
// `pill`   = (centre x dans le repère PISTE, demi-largeur, demi-hauteur, press)
// `mtl`    = (repetition, angle en radians, softness, contour)
// `mtl2`   = (distortion, speed, shiftRed, shiftBlue)
// `look`   = (influence du bord en pt, dose d'or, demi-largeur du fil, buée)
// `floorLvl` = plancher du métal, appliqué AVANT la teinte
// `piste`  = (voile du haut, fin du voile en fraction de hauteur,
//             épaisseur de l'anneau noir en pt, pic du liseré de flanc)
// `piste2` = (profondeur du liseré en pt, sa demi-largeur en pt,
//             son centre angulaire en degrés, sa largeur angulaire en degrés)
// `ombre`  = (dose, étalement en pt, décalage y en pt, —)
// `fx`     = (braise du déjà-poussé, refus 0→1, flash du commit, —)
[[ stitchable ]] half4 sliderObsidienne(float2 position, half4 color,
                                        float2 size, float t, float pad,
                                        float4 pill, float4 mtl, float4 mtl2,
                                        float4 look, float floorLvl,
                                        float4 piste, float4 piste2,
                                        float4 ombre, float4 fx) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float d = nsdRound(p, halfB, halfB.y);
    float dep = -d;                          // profondeur DANS la pierre
    float inside = smoothstep(0.7, -0.7, d);
    float H = 2.0 * halfB.y;
    float uy = clamp((p.y + halfB.y) / H, 0.0, 1.0);

    float3 rgb = float3(0.0);

    // ---- L'ANNEAU NOIR --------------------------------------------------
    // Une bande d'obsidienne pure en dedans de l'arête. `ring` vaut 1 dedans.
    // Sa sortie est FRANCHE — 0,45 pt de part et d'autre. Relevé sur la
    // référence : le noir tient jusqu'à 5,0 % de la hauteur et la pierre est
    // pleine à 6,2 % ; une transition molle rend l'anneau à moitié moins
    // épais qu'il ne mesure, et la « border très sombre » disparaît.
    float rz = max(piste.z, 0.5);
    float ring = 1.0 - smoothstep(rz - 0.45, rz + 0.45, dep);

    // ---- LE FOND ---------------------------------------------------------
    // Le voile relevé sur la référence suit un smoothstep, pas une droite :
    // il tient son plateau sur le premier tiers puis lâche d'un coup. Une
    // rampe linéaire donne un ciel ; celui-ci donne une pierre couchée.
    float s = clamp(uy / max(piste.y, 0.05), 0.0, 1.0);
    float veil = piste.x * (1.0 - s * s * (3.0 - 2.0 * s));
    rgb += veil * (1.0 - ring) * inside;

    // La braise du déjà-poussé : ce qui est DERRIÈRE le pouce s'est réchauffé.
    // « Extrêmement subtile » est une consigne, pas une figure de style — à
    // 2 % on la voit déjà, à 5 % la capsule n'est plus noire.
    if (fx.x > 0.001) {
        float behind = 1.0 - smoothstep(pill.x - 40.0, pill.x + 8.0,
                                        p.x + halfB.x);
        rgb += fx.x * behind * (1.0 - ring) * inside
               * float3(1.00, 0.42, 0.16);
    }

    // Le refus : la pierre prend la densité du grenat. Pas une alerte —
    // l'obsidienne reste de l'obsidienne, elle rougit du dedans.
    rgb = mix(rgb, mix(rgb, float3(0.62, 0.13, 0.16), 0.20) * inside,
              clamp(fx.y, 0.0, 1.0));

    // ---- LA LUMIÈRE DES FLANCS -------------------------------------------
    // La normale de la capsule : on replie p sur son épine dorsale, et ce qui
    // reste EST la normale. Sur les longues arêtes elle vaut (0, ±1) — le
    // lobe s'y éteint tout seul, sans masque ni test de côté.
    float spine = max(halfB.x - halfB.y, 0.0);
    float2 qn = float2(p.x - clamp(p.x, -spine, spine), p.y);
    float2 nrm = normalize(qn + float2(0.0, 1e-4));
    float ang = asin(clamp(-nrm.y, -1.0, 1.0)) * 57.2957795;
    float sig = max(piste2.w, 1.0);
    float lobe = exp(-pow((ang - piste2.z) / sig, 2.0));
    // La coupure haute. Sans elle le lobe remonte sur l'arête et les quatre
    // coins deviennent les maxima structurels : le procédé se voit.
    //
    // Elle est SERRÉE (+12° / +34° autour du centre) alors que le lobe, lui,
    // est LARGE (sigma 32°). C'est la mesure qui l'impose : la référence tient
    // 27/255 encore à l'horizontale — un lobe étroit y tombait à 9 — mais
    // s'éteint net avant 60°. Une gaussienne symétrique ne peut pas faire les
    // deux ; c'est la coupure qui taille le haut, pas le sigma.
    lobe *= smoothstep(piste2.z + 34.0, piste2.z + 12.0, ang);
    float dd = fabs(dep - piste2.x);
    float lwp = max(piste2.y, 0.3);
    float bandP = 1.0 - smoothstep(lwp * 0.70, lwp * 1.55, dd);
    // Au commit, les deux bouts de la capsule s'ALLUMENT. C'est le liseré de
    // flanc qui porte l'arrivée : la piste ne peut pas devenir blanche (elle
    // resterait de l'obsidienne éclairée, pas de l'obsidienne allumée) — ce
    // sont ses arêtes qui prennent la lumière, comme un objet qu'on approche
    // d'une source.
    rgb += piste.w * lobe * bandP * (1.0 + 2.10 * clamp(fx.z, 0.0, 1.0))
           * inside * float3(0.97, 0.98, 1.00);

    // Le cheveu : la crête juste à l'aplomb de l'anneau, un pour cent. C'est
    // lui qui donne une TRANCHE à la pierre — sans quoi la capsule est une
    // découpe posée sur la page.
    float topness = clamp(-p.y / max(halfB.y, 1.0), 0.0, 1.0);
    float hair = exp(-pow((dep - max(piste.z, 0.5)) / 2.4, 2.0))
               * (0.004 + 0.011 * pow(topness, 2.2));
    rgb += hair * float3(0.86, 0.89, 0.95) * inside;

    // ---- L'ONDE DU COMMIT ------------------------------------------------
    // La lumière part du pouce et court aux DEUX bouts en ~0,20 s. C'est une
    // onde, pas un fondu : un fondu global dit « la page a changé », une onde
    // qui part d'un point dit « c'est CE geste-là qui l'a déclenchée ».
    // Elle continue au-delà des bouts et meurt dehors — un front qui s'arrête
    // sur l'arête se lit comme un défaut de rendu.
    if (fx.z > 0.001) {
        float dxw = fabs((p.x + halfB.x) - pill.x);
        float front = (1.0 - fx.z) * 2.2 * (2.0 * halfB.x);
        float onde = exp(-pow((dxw - front) / max(halfB.y * 0.72, 1.0), 2.0));
        rgb += onde * fx.z * 0.80 * inside;
        // et la pierre entière prend la lumière, une fois, brièvement.
        rgb += fx.z * fx.z * 0.11 * (1.0 - ring) * inside;
    }

    // ---- LE POUCE : LE PUITS ---------------------------------------------
    float2 q = p - float2(-halfB.x + pill.x, 0.0);
    float2 pb = max(float2(pill.y, pill.z), float2(1.0));
    float dp = nsdRound(q, pb, pb.y);
    float adp = fabs(dp);
    float press = pill.w;

    // Pas de `* inside` : sous le doigt le pouce GROSSIT jusqu'à déborder de
    // la capsule, et ce qui dépasse doit exister. Clippé, il se ferait
    // trancher net à l'arête.
    // Le puits est PLUS CLAIR que celui de la barre : relevé sur la référence,
    // le verre ajoute un blanc quasi CONSTANT de 9,6 % à ce qu'il y a derrière
    // (41 en haut / 25 en bas, sur un fond qui vaut lui 17 puis 0). La barre,
    // elle, creuse une cuvette dégradée — deux objets, deux lectures.
    float pin = smoothstep(0.8, -0.8, dp);
    float wy = clamp((q.y + pb.y) / (2.0 * pb.y), 0.0, 1.0);
    rgb += pin * (0.115 + 0.020 * (1.0 - wy) + 0.014 * press);

    // ---- LE FIL DE MÉTAL LIQUIDE (le bloc de la nav bar, intact) ---------
    float W = max(look.x, 0.5);
    float n = nfbm(q * 0.055 + float2(t * 0.09, -t * 0.07)) - 0.5;

    float edge = 1.0 - smoothstep(0.0, W, adp);
    edge += (1.0 - edge) * mtl2.x * n;
    edge = clamp(edge, 0.0, 1.0);

    // La rampe est normalisée par la HAUTEUR du pouce : le pouce du slider est
    // une capsule couchée (rapport 1,68) là où celui de la barre est un
    // disque, et c'est justement pour ça qu'on ne normalise pas sur le grand
    // axe — sinon le fil reçoit moins d'une période et se lit en croissant.
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

    float fl = clamp(floorLvl, 0.0, 1.0);
    chrome = fl + (1.0 - fl) * chrome;

    float3 gold = float3(1.000, 0.780, 0.340);
    float3 burned = float3(nburn(chrome.r, gold.r),
                           nburn(chrome.g, gold.g),
                           nburn(chrome.b, gold.b));
    chrome = mix(chrome, burned, clamp(look.y, 0.0, 1.0));

    float lw = max(look.z, 0.3);
    float band = 1.0 - smoothstep(lw * 0.70, lw * 1.55, adp);

    float tq = clamp(-q.y / pb.y, 0.0, 1.0);
    float lift = 0.26 + 0.62 * pow(tq, 1.15) + 0.30 * pow(1.0 - tq, 2.4);
    float arc = atan2(q.y, q.x);
    float breath = 0.82 + 0.18 * sin(t * 0.55 + arc * 2.0);

    // L'amplitude du fil (`fx.w`) : la nav bar sertit un onglet DANS une barre
    // déjà claire ; ici le fil est seul sur du noir absolu et doit porter la
    // forme à lui tout seul. Mesuré : à l'amplitude de la barre le liseré
    // plafonne à 134/255 là où la référence en tient 190.
    // Le flash du commit : le fil entier prend la lumière, une fois.
    float amp = fx.w > 0.01 ? fx.w : 1.0;
    float ringAmt = band * lift * breath * amp * (1.0 + 0.50 * press)
                  * (1.0 + 1.80 * clamp(fx.z, 0.0, 1.0));
    rgb += chrome * ringAmt;

    float halo = exp(-max(adp - lw, 0.0) / 2.6) * look.w * lift
               * (1.0 + 0.6 * press);
    rgb += chrome * halo * 0.30;

    // ---- L'OMBRE PORTÉE --------------------------------------------------
    // Relevée sur la référence : sous la capsule le fond passe de 27 à 16
    // (41 % d'assombrissement), et il est ENCORE à 18 trente points plus bas —
    // c'est une ombre LARGE et molle, pas un contact. Sur les flancs elle ne
    // vaut plus que 11 %, au-dessus rien du tout.
    //
    // Le poids vertical est un CARRÉ, pas un smoothstep : c'est le seul galbe
    // qui donne les trois mesures d'un coup (0,04 en haut, 0,23 sur le flanc,
    // 1,00 dessous). Un smoothstep laissait un quart d'ombre au-dessus de la
    // capsule — une pièce éclairée par le bas.
    float vsh = clamp((p.y + halfB.y) / H, 0.0, 1.0);
    float shadow = ombre.x * exp(-max(d - 1.0, 0.0) / max(ombre.y, 1.0))
                 * (1.0 - inside) * (0.04 + 0.96 * vsh * vsh);

    // Dither : un demi-niveau. Sans lui, un dégradé de 2 % bande atrocement
    // sur OLED — et toute cette matière est faite de dégradés de 2 %.
    rgb += (nhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
           * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);

    float lum = max(max(rgb.r, rgb.g), rgb.b);
    float a = clamp(max(max(inside, pin), max(lum, shadow)), 0.0, 1.0);

    // ---- LE FONDU D'HÔTE -------------------------------------------------
    // Toute la lumière et toute l'ombre meurent AVANT le bord du rectangle :
    // le débord se dissout, il ne se coupe jamais.
    float2 toEdge = min(position, size - position);
    float host = smoothstep(0.0, pad * 0.42, min(toEdge.x, toEdge.y));
    rgb *= host;
    a *= host;
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}
