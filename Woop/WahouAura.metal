#include <metal_stdlib>
using namespace metal;

// MARK: - L'AURA DE LA RÉVÉLATION
//
// Ce qui vit AUTOUR de la carte une fois qu'elle s'est posée : des éclats de
// fumée noire, et une poussière de diamant orange très fine et très dense.
//
// LA FUMÉE NOIRE A UN PROBLÈME QUE PERSONNE NE VOIT VENIR : sur un fond noir,
// elle est invisible. Peinte en noir sur du noir, c'est un shader qui tourne
// pour rien. Elle n'existe que par DEUX choses, et il faut les deux :
//   • elle OCCULTE la braise qui reste sous le voile — des volumes encore plus
//     noirs qui traversent la lueur, c'est ça qui donne la masse ;
//   • elle est ÉCLAIRÉE par le tube de la carte. Une fumée près d'une source
//     s'allume ; loin d'elle, elle est noire. C'est ce dégradé — orange contre
//     la carte, noir au bout — qui la rend lisible, et c'est aussi ce qui la
//     rattache à l'objet au lieu d'en faire un calque posé derrière.
//
// LES TROIS LOIS DE LA FUMÉE DE LA MAISON, déjà payées sur le coffre du
// header (`coinSmoke`) et sur la fente :
//   • le champ GLISSE à mesure que la bouffée vieillit — donc la fumée a une
//     ORIGINE, elle n'apparaît pas AUTOUR ;
//   • le bruit est déformé DEUX fois — une seule déformation donne des nappes,
//     pas des volutes ;
//   • l'exposant fait les FILAMENTS À TROUS. Sans lui on obtient un disque de
//     brume, puis un donut, et c'est immédiatement cheap.
// Et les sources sont ASYMÉTRIQUES par construction, tailles et retards
// différents : une bouffée symétrique est un dessin animé.
//
// LA POUSSIÈRE, ELLE, EST LE PARI INVERSE DE CELLE DE LA FENTE. Là-bas la loi
// était RARE et DÉNOMBRABLE (quatre à sept grains) parce qu'entre quinze et
// quatre-vingts on tombe dans la neige de télévision. Ici on en veut BEAUCOUP.
// Ce qui sépare une nuée d'étincelles d'une neige de télévision n'est pas le
// nombre, ce sont trois choses :
//   • chaque grain est MENU et FAIBLE — c'est la masse qui brille, jamais
//     l'individu ;
//   • le mouvement est COHÉRENT : tous s'écartent de la carte et montent. Du
//     bruit isotrope, même dense, ne se lit que comme du bruit de capteur ;
//   • l'enveloppe est SERRÉE contre le contour de la carte et s'éteint vite.
//     Une densité uniforme sur tout le cadre, c'est de la neige ; une densité
//     qui décrit la silhouette de l'objet, c'est son aura.
// Et la forme reste celle de la maison : un cœur menu plus une croix à quatre
// branches. C'est la croix, pas la tache, qui dit « pierre ».
//
// Le shader travaille dans le repère de la carte à sa taille de PILE, et c'est
// la caméra qui l'agrandit — comme la carte elle-même. Il rend donc une petite
// surface (moins d'un demi-écran) même quand l'aura couvre tout l'écran, et le
// grain de la poussière GROSSIT avec le zoom, ce que fait un vrai objectif.

static float wahash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 wahash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float wanoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = wahash21(i);
    float b = wahash21(i + float2(1.0, 0.0));
    float c = wahash21(i + float2(0.0, 1.0));
    float d = wahash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float wafbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * wanoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

static float waRoundBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// `demi`   : la demi-taille de la carte, dans son repère de pile.
/// `rayon`  : son rayon de coin.
/// `vie`    : 0 → 1, l'aura s'installe.
/// `devant` : 0 la couche DERRIÈRE la carte (fumée + poussière), 1 la couche
///            DEVANT (les quelques grains les plus proches, et rien d'autre —
///            c'est ce croisement, quelques-uns devant et la plupart derrière,
///            qui fait le VOLUME. Sans lui l'aura est un décor peint.)
/// `age`    : l'âge du TOUCHER, en secondes. Négatif si personne n'a touché.
[[ stitchable ]] half4 wahouAura(float2 position, half4 color,
                                 float2 size, float t,
                                 float2 demi, float rayon,
                                 float vie, float devant, float age) {
    float2 p = position - size * 0.5;
    float d = waRoundBox(p, demi, rayon);
    float v = clamp(vie, 0.0, 1.0);
    if (v <= 0.002) { return half4(0.0); }

    // Rien à l'intérieur de la carte : elle est opaque, tout ce qu'on y
    // peindrait serait recouvert (couche 0) ou salirait sa face (couche 1).
    float dehors = smoothstep(-1.0, 3.0, d);
    if (dehors <= 0.002) { return half4(0.0); }

    // L'ÉCLAIRAGE PAR LE TUBE : la seule source de la scène.
    //
    // Sa PORTÉE est tout le sujet de la fumée noire. À 30 pt, mesuré, la
    // volute n'atteignait 42/255 qu'en son point le plus vif sur un fond à 10 :
    // une fumée qu'on devine n'est pas une fumée. Sur une scène noire, la seule
    // chose VISIBLE d'un volume noir est la part que la source éclaire — donc
    // c'est cette portée, et elle seule, qui décide si l'effet existe. 72 pt
    // porte jusqu'au tiers de la marge ; au-delà la fumée redevient noire, et
    // c'est ce dégradé qui la rattache à la carte au lieu d'en faire un fond.
    float lit = exp(-max(d, 0.0) / 72.0);

    const float3 ambre  = float3(1.00, 0.55, 0.18);
    const float3 braise = float3(1.00, 0.72, 0.34);
    const float3 blanc  = float3(1.00, 0.96, 0.90);

    float3 c = float3(0.0);
    float a = 0.0;

    // ---- LA FUMÉE (couche 0 seulement : devant la carte elle la voilerait,
    // et un voile qui assombrit ce qu'il recouvre est une plaque).
    if (devant < 0.5) {
        // Trois bouffées, périodes sans rapport entier : deux instants à cinq
        // secondes d'écart ne se ressemblent jamais.
        const float sper[5] = { 3.10, 4.30, 5.70, 2.60, 6.70 };
        const float spha[5] = { 0.00, 0.41, 0.73, 0.19, 0.58 };
        const float sgro[5] = { 1.00, 0.72, 0.86, 0.64, 0.94 };
        const float2 ssrc[5] = { float2(-0.82, 0.72),
                                 float2( 0.88, -0.55),
                                 float2( 0.66, 0.86),
                                 float2(-0.90, -0.30),
                                 float2(-0.20, 0.94) };
        float fumee = 0.0;
        for (int s = 0; s < 5; s++) {
            float age = fract(t / sper[s] + spha[s]);
            // L'ÉCLAT : montée très courte, longue traîne. Une enveloppe
            // symétrique donne une respiration, pas un éclat.
            float souffle = pow(age, 0.28) * exp(-age * 2.9);
            if (souffle < 0.01) { continue; }
            float2 src = float2(ssrc[s].x * (demi.x + 14.0),
                                ssrc[s].y * (demi.y + 14.0));
            float2 q = p - src;
            // Le glissement : la bouffée s'écarte de la carte et monte.
            float2 fuite = float2(sign(src.x) * 26.0, -44.0) * age;
            float2 sc = (q - fuite) * 0.026 / sgro[s];
            float w1 = wafbm(sc + float2(t * 0.020, -t * 0.014));
            float f = wafbm(sc * 1.36 + float2(2.2 * w1, -1.6 * w1)
                            - float2(t * 0.011, -t * 0.008));
            f = pow(clamp(f, 0.0, 1.0), 2.6);
            float2 e = (q - fuite) / (sgro[s] * (46.0 + 62.0 * age));
            float enveloppe = exp(-dot(e, e));
            fumee += souffle * sgro[s] * enveloppe * f;
        }
        // LA BOUFFÉE DU TOUCHER. Ce n'est pas une sixième source : c'est tout
        // le CONTOUR qui expire d'un coup. Une source ponctuelle de plus se
        // serait fondue dans les cinq autres et personne n'aurait fait le lien
        // avec son doigt — ce qui répond au toucher doit avoir la forme de
        // l'objet touché, pas une forme de plus.
        //
        // Le champ s'échappe RADIALEMENT : chaque point voit le bruit fuir
        // droit devant lui, en s'éloignant de la carte. C'est la même loi que
        // les cinq autres (le champ glisse à mesure que la bouffée vieillit,
        // donc elle a une origine) appliquée à une origine qui est une ligne
        // et non un point.
        if (age >= 0.0 && age < 1.7) {
            float ag = age / 1.7;
            float souffle = pow(ag, 0.20) * exp(-ag * 2.5);
            float2 dir = normalize(p + float2(1e-4, 1e-4));
            float2 sc = (p - dir * (170.0 * ag)) * 0.019;
            float w1 = wafbm(sc + float2(t * 0.024, -t * 0.017));
            float f = wafbm(sc * 1.42 + float2(2.3 * w1, -1.7 * w1));
            f = pow(clamp(f, 0.0, 1.0), 2.3);
            // Elle porte LOIN en vieillissant : une bouffée qui reste collée au
            // bord est un liseré qui palpite, pas de l'air chassé.
            float portee = exp(-max(d, 0.0) / (54.0 + 190.0 * ag));
            fumee += souffle * f * portee * 3.4;
        }

        fumee = clamp(fumee * 2.35 * v * dehors, 0.0, 1.0);
        // La couverture EST la fumée : c'est elle qui mange la braise du fond.
        // Sa couleur, elle, ne vient que du tube — noire au bout, ambre contre
        // la carte, et ÉMISSIVE : la part éclairée s'ajoute par-dessus la
        // couverture (licite en prémultiplié). Portée par l'alpha seule, une
        // fumée lumineuse assombrirait ce qu'elle recouvre — et de la lumière
        // qui assombrit est une plaque, jamais un volume.
        a += fumee * 0.90;
        c += float3(0.010, 0.008, 0.008) * (fumee * 0.90)
           + ambre * (fumee * lit * 1.55);
    }

    // ---- LA POUSSIÈRE DE DIAMANT. Écrite par COULOIRS : un pixel n'examine
    // que trois couloirs voisins, chacun portant deux grains dont la position
    // se déduit du temps et d'un haché. Fonction PURE — rien ne s'accumule,
    // rien ne dérive, un banc figé rend deux fois la même image.
    // PLUS DENSE ET PLUS FINE : le couloir tombe à 4,2 pt et porte TROIS
    // grains. La finesse et la densité vont ensemble — plus il y en a, plus
    // chacun doit être menu, sinon la nuée se referme en texture et redevient
    // de la neige.
    float lane = 3.4;
    float grains = 0.0;
    float coeurs = 0.0;
    for (int k = -1; k <= 1; k++) {
        float ix = floor(p.x / lane) + float(k);
        for (int j = 0; j < 3; j++) {
            float4 h = wahash42(float2(ix * 1.77 + 5.3, 3.1 + 9.7 * float(j)));
            // La profondeur décide qui passe devant : deux grains sur dix.
            float prof = h.w;
            bool front = prof > 0.80;
            if ((devant > 0.5) != front) { continue; }

            float duree = 1.9 + 2.6 * h.y;
            float uu = fract(t / duree + h.z * 7.0);
            // LE MOUVEMENT COHÉRENT : ils montent et s'écartent de l'axe. Une
            // dérive commune, c'est une nuée ; des directions au hasard, c'est
            // du bruit de capteur.
            float mx = (ix + 0.5) * lane + (h.x - 0.5) * lane * 0.9
                     + sign((ix + 0.5) * lane) * 16.0 * uu * uu
                     + 2.2 * sin(t * (0.6 + 0.9 * h.z) + h.y * 6.2831);

            // LES GRAINS NAISSENT DEHORS, ET C'EST LA CORRECTION QUI FAIT
            // TOUT. Ils étaient tirés dans le rectangle entier : les couloirs
            // qui tombent sur la carte — les quatre cinquièmes — voyaient leurs
            // grains naître SOUS elle, où `dehors` les efface. Mesuré, il ne
            // restait que 0,02 % de pixels touchés : une nuée dense sur le
            // papier, un désert à l'écran. Une aura se sème sur le CONTOUR de
            // l'objet, pas dans sa boîte englobante.
            float span = demi.y + 100.0;
            bool libre = fabs(mx) > demi.x + 6.0;
            float u = fract(h.x * 6.13 + 0.37);
            float y0 = libre
                ? mix(-span, span, h.x)
                : (h.x < 0.5 ? mix(-span, -demi.y - 6.0, u)
                             : mix(demi.y + 6.0, span, u));
            float my = y0 - (26.0 + 34.0 * h.y) * uu;

            float2 dp = float2(p.x - mx, p.y - my);
            // Rejet précoce : sans lui on paierait la croix sur tout le cadre.
            if (dot(dp, dp) > 90.0) { continue; }

            // LA TAILLE APPARENTE D'UN GRAIN, CE N'EST PAS SON CŒUR — C'EST SA
            // CROIX. Le cœur tient dans un point ; les branches, elles,
            // portaient jusqu'à 4 pt dans ce repère, soit près de 8 pt à
            // l'écran une fois la caméra posée. C'est ça qu'on lisait comme
            // « trop gros », et baisser le sigma du cœur n'y aurait rien
            // changé. Les branches tombent donc de 1,2 à 0,52, et leur poids
            // de 0,34 à 0,20 : il reste juste ce qu'il faut d'étoile pour dire
            // « pierre », plus assez pour faire un flocon.
            //
            // LE PLANCHER EST LE NYQUIST DU 3×, et il n'est pas négociable.
            // La scène est rendue dans une texture à sa taille naturelle puis
            // agrandie : un sigma de 0,34 pt fait tout juste UN pixel de
            // texture. En dessous, le grain passe ENTRE les échantillons — il
            // ne devient pas plus fin, il se met à clignoter, et une poussière
            // qui grésille est le défaut déjà refusé deux fois dans ce projet.
            float taille = 0.34 + 0.14 * prof;
            float coeur = exp(-dot(dp, dp) / (taille * taille));
            // LE DIAMANT DE LA MAISON : un cœur menu et une croix à quatre
            // branches. C'est la croix, pas la tache, qui dit « pierre ».
            float croix = exp(-dp.y * dp.y / (0.20 * 0.20))
                            * exp(-fabs(dp.x) / (0.52 + 0.62 * prof))
                        + exp(-dp.x * dp.x / (0.20 * 0.20))
                            * exp(-fabs(dp.y) / (0.40 + 0.50 * prof));

            // Naissance et mort en fondu, plus un scintillement propre : sans
            // vie individuelle, une nuée dense devient une texture fixe.
            // Le scintillement garde un PLANCHER haut (0,62). Un `pow(sin, 4)`
            // pur passe les trois quarts du temps près de zéro : la nuée
            // clignotait au lieu de briller, et une nuée qui clignote est de la
            // neige. Ce qui doit varier, c'est l'éclat — pas l'existence.
            float env = smoothstep(0.0, 0.10, uu) * (1.0 - smoothstep(0.55, 1.0, uu));
            env *= 0.62 + 0.38 * pow(max(0.0, sin(t * (1.4 + 2.3 * h.z)
                                                  + h.y * 6.2831)), 4.0);
            float g = (coeur + croix * 0.20) * env * (0.35 + 0.65 * prof);
            grains += g;
            coeurs += coeur * env * prof;
        }
    }
    // L'ENVELOPPE : serrée contre le contour, éteinte vite. C'est elle, et pas
    // le nombre, qui sépare une aura d'une neige.
    float pres = exp(-max(d, 0.0) / 74.0) * dehors;
    grains *= pres * v * (devant > 0.5 ? 0.62 : 1.0);
    coeurs *= pres * v;

    // FAIBLE À L'UNITÉ, mais pas INVISIBLE. La masse brille, jamais
    // l'individu — c'est la seule façon d'être dense sans être cheap. Le grain
    // le plus vif culmine autour de 150/255 sur un fond à 10 ; le gros de la
    // nuée vit entre 25 et 60, là où l'œil lit une poussière et pas des points.
    // Des grains plus menus portent moins d'énergie : le gain remonte pour que
    // la MASSE garde la même présence. C'est la nuée qu'on règle, jamais le
    // grain — un grain qu'on voit individuellement n'est plus de la poussière.
    float3 poudre = mix(ambre, braise, 0.45) * (grains * 2.10)
                  + blanc * (coeurs * 0.44);
    c += poudre;

    // LA LUMIÈRE DOIT PORTER SA PROPRE COUVERTURE, ET C'EST LE `drawingGroup`
    // QUI L'EXIGE.
    //
    // Toute cette aura était écrite en ÉMISSIF PUR — de la couleur avec un
    // alpha nul, ce qui est licite en prémultiplié et donne exactement ce
    // qu'on veut : une poussière qui éclaire le fond sans le voiler. Ça
    // marchait tant que le shader se composait directement sur l'écran.
    //
    // `drawingGroup` change la règle : la scène est d'abord rendue dans une
    // TEXTURE prémultipliée, et une texture prémultipliée n'a pas de place
    // pour de la couleur à alpha zéro — elle est mise à zéro au passage. La
    // fumée et la poussière disparaissaient donc entièrement, et pas parce
    // qu'elles étaient trop fines : parce qu'elles n'avaient aucune couverture
    // à faire valoir.
    //
    // On la leur donne : l'alpha suit le canal le plus fort. Sur une scène
    // noire c'est rigoureusement le même rendu qu'en émissif ; sur la braise à
    // huit pour cent qui reste sous le voile, l'écart est sous le niveau de
    // quantification.
    float pic = max(c.r, max(c.g, c.b));
    a = clamp(max(a, pic), 0.0, 1.0);
    c = min(c, float3(a));

    // Dither : à ces niveaux les volutes banderaient en anneaux de Mach sur
    // OLED, et un flou n'y changerait rien — on flouterait une image déjà
    // quantifiée.
    c += (wahash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0))
          - 0.5) * (2.0 / 255.0) * max(a, 0.20);
    c = clamp(c, 0.0, 1.0);
    return half4(half3(c), half(a));
}
