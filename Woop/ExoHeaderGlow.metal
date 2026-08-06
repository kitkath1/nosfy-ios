#include <metal_stdlib>
using namespace metal;

// MARK: - Le halo du header de la fiche d'exercice
//
// UNE SEULE SOURCE, HORS CADRE, EN HAUT À DROITE. Et c'est tout le sujet :
// la version d'avant cadrait `bgAurora` — le fond du LOGIN, dont la lumière
// monte du sol. Un cadrage calé en bas finit forcément sur sa ligne la plus
// brillante, et juste au-dessus vivent deux foyers ÉCRÊTÉS (relevés à 255,0
// sur 70 pt de large, deux fois). Un pixel à 255 n'est plus une nappe, c'est
// un DISQUE : l'œil n'y lit qu'un objet posé sur du noir. Tant que la carte
// noire coupait la page à 115 pt, on s'arrêtait AVANT le sommet et personne
// ne le voyait ; la carte retirée, ils sont apparus.
//
// La leçon, payée en quatre tours : `bgAurora` n'est pas un dégradé, c'est
// une SCÈNE — un horizon, un soleil, des rideaux. Tout recadrage d'une scène
// montre un morceau de scène. On ne tire pas un dégradé d'une scène par
// recadrage, reflet, flou ou masque : on l'ÉCRIT.
//
// D'où ce champ, qui ne fait qu'une chose et ne peut structurellement pas en
// faire d'autre :
//   * un dôme à SOMMET PLAT (exp(−r^p), p > 2 — la leçon des dômes de
//     l'aurore : « un sommet plat, pas une pointe qui brûle son centre »),
//     donc jamais d'écrêtage, donc jamais de disque ;
//   * son centre est posé de sorte qu'on n'en voie JAMAIS le cœur nu — on
//     voit la lumière, pas l'ampoule ;
//   * une remontée (le « fill » des éclairagistes) sous le chevron : sans
//     elle un côté est mort, et ça se lit tout de suite ;
//   * la LOI ANTI-BRUN de la maison : un orange qui s'éteint en fondu chaud
//     passe par le marron, et le marron fait cheap. Entre l'orange et la
//     nuit, on passe par un GRIS FROID — la saturation redescend puis la
//     couleur vire, elle ne rougit pas jusqu'au noir.
//
// Aucun bord n'existe dans ce champ : pas de coupure possible, pas de bande,
// pas de couture. C'est structurel, pas réglé.

static float ehgHash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Dôme elliptique à sommet plat, INCLINABLE. `p` > 2 aplatit la crête : le
// centre ne brûle pas, il PLAFONNE — c'est ce qui interdit le disque.
// `a` incline le grand axe : une retombée parfaitement horizontale se relit
// comme une BANDE, une retombée en biais se lit comme une lumière.
static float ehgDome(float2 pos, float2 c, float2 r, float p, float a) {
    float2 d = pos - c;
    float ca = cos(a), sa = sin(a);
    float2 q = float2(d.x * ca + d.y * sa, -d.x * sa + d.y * ca) / r;
    float d2 = max(dot(q, q), 1e-6);
    return exp(-pow(d2, p * 0.5));
}

// La palette : la lignée braise de la maison (celle d'ExosHalo), à flancs
// LUMINEUX — un orange sombre lit toujours brun.
constant float3 EHG_CREME  = float3(1.000, 0.938, 0.790);  // le cœur
constant float3 EHG_JAUNE  = float3(1.000, 0.830, 0.420);  // l'écho du néon
constant float3 EHG_ORANGE = float3(1.000, 0.580, 0.280);  // le vif
constant float3 EHG_BRAISE = float3(1.000, 0.450, 0.160);  // le creux
// LE GRIS FROID, et il n'est pas décoratif : c'est lui qui interdit le
// marron. Légèrement prune, jamais neutre — un gris neutre ferait une
// cendre morte, celui-ci garde une couleur en s'éteignant.
constant float3 EHG_CENDRE = float3(0.470, 0.398, 0.520);

// LA RAMPE. Le premier essai montait au crème vers 0,84 puis comprimait le
// niveau : crème × 0,62 = BEIGE, et tout le header virait moutarde. C'est
// l'erreur exactement inverse de la loi maison. L'orange saturé doit tenir
// TOUTE la plage utile ; le jaune n'apparaît que dans le dernier dixième,
// et le crème pas du tout — on ne voit jamais le cœur nu.
static float3 ehgHue(float v) {
    // Le gris froid tient jusqu'à 0,30 — mesuré, pas choisi. À 0,16 le coin
    // du chevron sortait à rgb(35,16,6) : saturation 0,83, luminance 20.
    // Un orange saturé à luminance 20, ça s'appelle du BRUN, et c'est
    // exactement ce que la loi maison interdit entre l'orange et la nuit.
    // Toute la retombée basse doit se DÉSATURER avant de s'éteindre.
    float3 c = mix(EHG_CENDRE, EHG_BRAISE, smoothstep(0.09, 0.30, v));
    c = mix(c, EHG_ORANGE, smoothstep(0.24, 0.50, v));
    c = mix(c, EHG_JAUNE,  smoothstep(0.88, 1.00, v));
    return c;
}

// `t` : le temps, pour la RESPIRATION seule (±5 % sur 22 s, dérive du foyer
// sur 31 s — deux périodes premières entre elles, la trajectoire ne boucle
// jamais). Un dégradé parfaitement figé sonne mort sur un écran vivant ;
// au-delà de ça, rien ne bouge, et surtout pas le grain.
[[ stitchable ]] half4 exoHeaderGlow(float2 position, half4 color,
                                     float2 size, float t) {
    float2 p = position;
    float w = max(size.x, 1.0);
    float h = max(size.y, 1.0);

    // LA VIE. Grammaire de la maison, reprise telle quelle : des périodes
    // PREMIÈRES entre elles (13, 17, 19, 23, 29, 31, 37, 41, 47 s), deux
    // sinus incommensurables par axe pour les dérives — la trajectoire ne
    // boucle jamais, donc l'œil ne peut pas apprendre le cycle et la
    // lumière ne « repasse » jamais au même endroit. Poids, rayons,
    // centres et inclinaison respirent SÉPARÉMENT : s'ils étaient en
    // phase, ça ferait un clignotement ; déphasés, ça fait une flamme
    // lente.
    float bw1 = 1.0 + 0.16 * sin(t * 6.2832 / 19.0);          // poids cœur
    float bw2 = 1.0 + 0.18 * sin(t * 6.2832 / 13.0 + 2.1);    // poids halo
    float br1 = 1.0 + 0.10 * sin(t * 6.2832 / 17.0 + 4.0);    // rayon cœur
    float br2 = 1.0 + 0.12 * sin(t * 6.2832 / 23.0 + 1.2);    // rayon halo
    float2 dk = float2(w * (0.038 * sin(t * 6.2832 / 31.0)
                            + 0.019 * sin(t * 6.2832 / 47.0 + 1.7)),
                       h * (0.032 * sin(t * 6.2832 / 37.0 + 0.8)
                            + 0.017 * sin(t * 6.2832 / 29.0 + 3.4)));
    float tilt = -0.10 + 0.055 * sin(t * 6.2832 / 41.0);

    // DEUX dômes, pas un — et c'est ce qui sépare une lumière d'un
    // aplat de dégradé. Une seule gaussienne large lave tout le haut de la
    // page d'un voile uniforme : ça se lit comme un calque posé, pas comme
    // une source. Une vraie lumière a un CŒUR serré et un HALO ample, de
    // rayons très différents, et leur somme n'est plus une exponentielle :
    // elle tombe vite près de la source puis traîne longtemps. C'est cette
    // cassure de pente que l'œil lit comme de la profondeur.
    // Le cœur est posé PRESQUE HORS CADRE, contre le bord droit : la
    // lumière ENTRE dans l'image au lieu d'y être posée. Un foyer planté au
    // milieu du haut se lit comme un calque ; un foyer qui déborde du cadre
    // se lit comme une source qui existe ailleurs. Sa hauteur (0,27 h) tient
    // la consigne : le plus chaud au niveau du chevron et du « … ».
    float core = ehgDome(p,
                         float2(w * 0.88, h * 0.27) + dk,
                         float2(w * 0.30, h * 0.19) * br1,
                         2.6, tilt);
    float halo = ehgDome(p,
                         float2(w * 0.82, h * 0.30) + dk * 0.55,
                         float2(w * 0.75, h * 0.36) * br2,
                         2.0, tilt - 0.03);
    // LA REMONTÉE, à gauche, sous le chevron. Faible : elle ne doit jamais
    // se lire comme une seconde source — sinon on retombe sur deux lobes
    // symétriques, c'est-à-dire deux halos. Elle ne sert qu'à empêcher le
    // coin de mourir tout à fait.
    float fill = ehgDome(p,
                         float2(w * 0.02, h * 0.20),
                         float2(w * 0.36, h * 0.22),
                         2.0, 0.0);

    // L'ONDULATION D'ATMOSPHÈRE : deux ondes TRÈS larges (moins d'une
    // demi-période sur toute la bande) qui dérivent lentement. C'est ce qui
    // empêche la lueur de rester un objet mathématique — de la lumière qui
    // traverse quelque chose n'est jamais parfaitement lisse. Amplitude
    // tenue à ±5 % : au-delà on verrait les ondes, et une onde qu'on voit
    // n'est plus de l'air, c'est un motif.
    float ripple = 1.0
        + 0.050 * sin(p.x / w * 3.1 + t * 0.21)
        + 0.038 * sin((p.x * 0.6 + p.y * 1.3) / w * 2.4 - t * 0.13);

    // Les poids sont calculés pour que le PIRE CAS reste sous 1 : cœur et
    // halo à leur maximum EN MÊME TEMPS (0,44×1,16 + 0,33×1,18), ondulation
    // à son maximum (×1,088) → 0,975. Ça arrive rarement, mais ça arrive :
    // les périodes sont premières, donc tôt ou tard tout se croise. Si v
    // saturait ne serait-ce qu'une seconde, le sommet s'aplatirait en
    // palier — et un palier, c'est un disque, c'est-à-dire un halo.
    float v = clamp((core * 0.44 * bw1 + halo * 0.33 * bw2) * ripple
                    + fill * 0.10, 0.0, 1.0);

    // Compression du NIVEAU SEUL : la teinte reste saturée, seule
    // l'intensité est comprimée. L'inverse (comprimer la couleur) est
    // exactement ce qui fabrique du beige.
    float lvl = pow(v, 1.06) * 0.90;
    float3 c = ehgHue(v) * lvl;

    // Poussière : rare, faible, et seulement DANS la lumière (v²). Sans
    // elle un dégradé pur a l'air d'un plastique ; avec trop d'elle, on
    // retombe sur les points posés sur la laque, refusés ailleurs.
    float star = step(0.9988, ehgHash21(floor(p * 0.85) + 7.0));
    c += float3(1.000, 0.930, 0.800) * (star * 0.12 * v * v);

    // Dither FIXE (pas de `t`) : sur un dégradé sombre de 300 pt, l'OLED
    // fait des marches sans lui — mais un dither animé grésillerait.
    c += (ehgHash21(p * 1.113) - 0.5) * (2.0 / 255.0);

    // LA SORTIE DU CADRE, et elle n'est pas facultative. Mesuré : à la
    // dernière ligne de la bande le champ vaut encore rgb(4,3,4), et la
    // ligne suivante est du noir pur. 4/255, pleine largeur, sur de l'OLED
    // dans le noir : c'est UNE LIGNE. Toute cette page a consisté à tuer ce
    // bord-là ; on n'en laisse pas un au fond du cadre. Le grain s'éteint
    // avec le signal, sinon c'est lui qui dessine l'arête.
    c *= 1.0 - smoothstep(0.82, 1.0, p.y / h);

    return half4(half3(clamp(c, 0.0, 1.0)), 1.0) * color.a;
}
