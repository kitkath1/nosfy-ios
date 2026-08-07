#include <metal_stdlib>
using namespace metal;

// MARK: - L'aurore orange (banc `-haloLab`)
//
// Le fond de la page de connexion, avec SA loi de couleur — pas une
// imitation : la même mécanique, d'autres nombres.
//
// LA NUIT EST UN PLAFOND, pas un rideau qui dérive. Elle est ancrée en haut
// et elle en prend presque tout : noir TOTAL jusqu'à 42 % de la hauteur
// (le login s'arrête à 30 %), la lumière ne reprend la main qu'à 68 %. Ce
// qui bouge, ce n'est pas la masse, c'est sa LISIÈRE : elle avance et
// recule comme une marée, rongée par les rideaux.
//
// LA LUEUR BLANCHE est collée au bord bas, comme au login : crête à 97,5 %
// de la hauteur, montée très courte, amplitude 2,45 — de très loin le foyer
// le plus puissant de la page. Et ce n'est pas une nappe blanche : le blanc
// est une MARCHE dans la loi de couleur, réservée au seul cœur (v > 0,78).
// C'est ce qui fait une lumière plutôt qu'une tache.
//
// L'ANTI-MARRON de cette famille n'est pas la garde de saturation du header
// de la fiche d'exercice (qui vaut là où la braise ne s'éteint jamais) :
// c'est le GRIS FUMÉE dans les ombres. Entre le noir et l'orange il faut du
// gris ou du noir, jamais un long fondu chaud — sinon la lisière de la nuit
// se salit en brun sur toute sa largeur.

// La palette calibrée, héritée du fond de connexion.
constant float3 HD_BASE  = float3(1.00, 0.56, 0.31);  // le pic, orange franc
constant float3 HD_OR    = float3(1.00, 0.76, 0.33);  // l'anneau doré
constant float3 HD_BRUME = float3(1.00, 0.95, 0.94);  // la brume des ombres
constant float3 HD_CREME = float3(1.00, 0.93, 0.73);  // au-delà de l'orange
constant float3 HD_BLANC = float3(1.00, 0.99, 0.97);  // le cœur, au-delà de la crème
constant float3 HD_FUMEE = float3(0.62, 0.60, 0.60);  // le gris qui tue le brun

constant float HD_K = 1.85;      // le compresseur de niveau
/// Le plafond de nuit : au-dessus, plus un photon. Le login tient 0,30 —
/// ici la nuit en prend davantage, c'est le réglage qui sépare les deux.
constant float HD_NUIT = 0.20;
/// La crête de la lumière : au ras du bord bas, comme la connexion.
constant float HD_CY = 0.975;

static float hdhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 hdhash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float hdnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = hdhash21(i);
    float b = hdhash21(i + float2(1.0, 0.0));
    float c = hdhash21(i + float2(0.0, 1.0));
    float d = hdhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float hdfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * hdnoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

/// Une colonne de lumière : dôme MOU (exposant 2, large) — les bords des
/// foyers ne doivent jamais se lire comme des cercles.
static float hdDome(float x, float c, float w, float p) {
    float d = fabs(x - c) / max(w, 1e-4);
    return exp(-pow(d, p));
}

/// L'ÉNERGIE en un point — un scalaire, pas une couleur : c'est la loi de
/// couleur, plus bas, qui décide ce que devient chaque niveau. Sert deux
/// fois : au champ lui-même, et aux poussières pour savoir où naître.
static float hdEnergy(float2 q, float aspect, float t) {
    // Respirations franches, périodes premières entre elles — c'est elles
    // qu'on doit VOIR.
    float b1 = 0.87 + 0.13 * sin(t * 6.2832 / 19.0);
    float b2 = 0.82 + 0.18 * sin(t * 6.2832 / 13.0 + 2.1);
    float b3 = 0.88 + 0.12 * sin(t * 6.2832 / 17.0 + 4.0);

    // Les trois colonnes, qui dérivent largement.
    float xCoeur  = aspect * 0.38 + 0.035 * sin(t * 6.2832 / 21.0);
    float xDroite = aspect * 0.92 + 0.030 * sin(t * 6.2832 / 15.0 + 2.6);
    float xLarge  = aspect * 0.52 + 0.040 * sin(t * 6.2832 / 25.0 + 1.1);
    float coeur  = hdDome(q.x, xCoeur, 0.180, 2.0);
    float droite = hdDome(q.x, xDroite, 0.230, 2.0);
    // La nappe : très large, elle porte l'ambre sur TOUTE la largeur — sans
    // elle la page n'est plus orange, seulement deux foyers dans du noir.
    float large  = hdDome(q.x, xLarge, 0.780, 2.0);

    // La crête bombe sous le cœur, et respire doucement à la verticale.
    float cy = HD_CY - 0.022 * coeur + 0.010 * sin(t * 6.2832 / 11.0);

    // Chaque famille a sa PORTÉE vers le haut : le cœur reste écrasé au bord
    // bas (c'est ce qui le fait cramer en blanc), le halo orange monte plus
    // haut, la nappe monte jusque sous la nuit. C'est cet étagement qui fait
    // que la page est orange partout et blanche seulement en bas.
    // λ du cœur = 0,085, la valeur mesurée de la connexion : c'est elle qui
    // ÉCRASE le blanc dans le dernier cinquième. À 0,150 il montait deux fois
    // plus haut et cramait la moitié basse de la page en un aplat blanc.
    float upC = exp(-max(cy - q.y, 0.0) / 0.085);
    // Les portées REMONTENT : l'orange et la nappe doivent atteindre la
    // lisière de la nuit, sinon une bande morte s'installe entre le feu et
    // le noir (le défaut mesuré du login, qui l'assume — pas nous).
    float upD = exp(-max(cy - q.y, 0.0) / 0.620);
    float upL = exp(-max(cy - q.y, 0.0) / 0.900);
    float dn  = exp(-max(q.y - cy, 0.0) / 0.125);

    // La nappe reste BASSE en niveau : elle doit teindre la page en orange,
    // pas la pousser au-dessus de la marche du blanc.
    float E = (0.09 + 2.45 * b1 * coeur) * upC * dn
            + (1.20 * b2 * droite) * upD * dn
            + (0.46 * b3 * large) * upL * dn;

    // Les halos-voix : trois lumières qui TRAVERSENT la page sous la nuit,
    // chacune à son tempo (périodes sans rapport entier : deux instants à
    // 10 s d'écart ne se ressemblent jamais). Elles naissent et meurent en
    // fondu — jamais d'apparition sèche.
    const float vper[3]  = { 23.0, 31.0, 17.0 };
    const float vpha[3]  = { 0.15, 0.62, 0.33 };
    const float vcx[3]   = { 0.24, 0.82, 0.55 };
    const float vy0[3]   = { 0.42, 1.00, 0.98 };
    const float vy1[3]   = { 1.02, 0.38, 0.46 };
    const float2 vsig[3] = { float2(0.26, 0.17),
                             float2(0.22, 0.15),
                             float2(0.30, 0.19) };
    const float vw[3]    = { 0.30, 0.26, 0.24 };
    for (int i = 0; i < 3; i++) {
        float life = fract(t / vper[i] + vpha[i]);
        float env = sin(3.14159 * life);
        float y = mix(vy0[i], vy1[i], life);
        // La voix louvoie en traversant, et son enveloppe palpite : le
        // mouvement se VOIT, ce n'est pas une dérive plate.
        float x = aspect * (vcx[i] + 0.10 * sin(life * 6.2832 + vpha[i] * 9.0));
        float2 sig = vsig[i] * (1.0 + 0.16 * sin(life * 12.566 + vpha[i] * 7.0));
        float2 d = (q - float2(x, y)) / sig;
        E += vw[i] * env * env * exp(-dot(d, d));
    }
    return E;
}

[[ stitchable ]] half4 haloDawn(float2 position, half4 color,
                                float2 size, float t) {
    float2 q = position / max(size.y, 1.0);
    float aspect = size.x / max(size.y, 1.0);

    float E = hdEnergy(q, aspect, t);

    // ---- Les rideaux : le plan proche. Filaments plus serrés en x qu'en y
    // (des VOILES dressés, pas des nappes), domaine déformé deux fois, et
    // toute la matière glisse VERS LE BAS — la lumière retombe vers sa
    // source. Sans eux, des nappes empilées ne donnent qu'un dégradé
    // vertical sans âme : c'est le contraste qui fait l'aurore, jamais la
    // quantité de lumière.
    float2 ac = float2(q.x * 2.4, (q.y - t * 0.060) * 1.00);
    float w1 = hdfbm(ac + float2(t * 0.026, 0.0));
    float w2 = hdfbm(ac * 1.7 - float2(t * 0.018, t * 0.040) + 2.1 * w1);
    float cur = hdfbm(ac * 1.27 + float2(1.9 * w1, -1.5 * w2));
    cur = pow(clamp(cur * 1.18, 0.0, 1.0), 2.5);
    E *= 0.70 + 1.05 * cur;

    // ---- LA NUIT. Un PLAFOND ancré en haut : au-dessus, plus un photon.
    //
    // Mais surtout : elle ne s'arrête pas sur une ligne. Deux sinus donnaient
    // un front régulier, donc un RIDEAU — le défaut nommé. Ici le seuil est
    // déplacé par du fbm à deux échelles : la lisière n'a plus de forme
    // lisible, elle a des caps et des baies qui dérivent.
    float nzA = hdfbm(float2(q.x * 1.5 + t * 0.020, t * 0.032));
    float nzB = hdfbm(float2(q.x * 3.6 - t * 0.028, 5.7 + t * 0.045));
    float seuil = HD_NUIT + 0.19 * (nzA - 0.5) + 0.11 * (nzB - 0.5)
                          + 0.09 * (cur - 0.45);
    // Le FONDU est long (0,34) : c'est lui qui empêche le bord de se lire.
    E *= smoothstep(seuil, seuil + 0.34, q.y);

    // LA MORSURE : des langues de nuit qui DESCENDENT dans l'orange bien
    // au-delà du fondu, et s'y éteignent. C'est ça, « la nuit mange aussi
    // l'orange » — sans elles, même un front irrégulier reste une frontière.
    float lang = hdfbm(float2(q.x * 4.2 + 3.1, q.y * 1.3 - t * 0.055));
    float prox = 1.0 - smoothstep(seuil, seuil + 0.62, q.y);
    E *= 1.0 - 0.80 * prox * smoothstep(0.42, 0.80, lang);

    // ---- Tone map à teinte conservée : on comprime le NIVEAU, jamais les
    // canaux.
    float v = 1.0 - exp(-E * HD_K);

    // ---- La loi de couleur calibrée : brume dans les ombres, orange franc
    // dans les moyens, anneau doré, crème au sommet — et une MARCHE au bout,
    // au-delà de la crème : le blanc.
    float bas  = 0.50 * pow(max(1.0 - v / 0.664, 0.0), 2.3);
    float haut = clamp(1.10 * pow(smoothstep(0.625, 0.995, v), 1.769), 0.0, 1.0);
    float3 tint = mix(HD_BASE, HD_BRUME, bas);
    // Anti-marron : sous v ≈ 0,30 la teinte glisse vers le GRIS FUMÉE. Un
    // orange sombre lit toujours brun — entre le noir et l'orange il faut du
    // gris, jamais un long fondu chaud. C'est CETTE règle qui tient la
    // lisière de la nuit, pas la garde de saturation du header.
    float grisbas = 0.45 * pow(max(1.0 - v / 0.30, 0.0), 1.5);
    tint = mix(tint, HD_FUMEE, grisbas);
    // L'anneau doré, serré entre l'orange franc et la crème : plus large, il
    // mangerait la plage où vit l'orange VIF.
    float dore = 0.78 * smoothstep(0.55, 0.78, v) * (1.0 - haut);
    tint = mix(tint, HD_OR, dore);
    tint = mix(tint, HD_CREME, haut);
    // La marche du blanc : le cœur seul crame. C'est ce qui fait une
    // lumière, et pas une tache blanche.
    tint = mix(tint, HD_BLANC, smoothstep(0.78, 0.97, v));
    float3 c = clamp(tint * v, 0.0, 1.0);
    // Et la saturation REMONTE dans la lumière : c'est elle qui fait
    // l'orange VIF — sans elle, les tons moyens plafonnent en beige-brun.
    float3 lum = float3(dot(c, float3(0.299, 0.587, 0.114)));
    c = clamp(mix(lum, c, 1.0 + 0.38 * smoothstep(0.35, 0.75, v)), 0.0, 1.0);

    // ---- Les poussières : le plan le plus proche. Fines, rares, nées dans
    // la lumière seulement (une étincelle sur du noir lit comme du bruit de
    // capteur), elles montent en s'éteignant. σ ≥ 0,55 pt — en dessous, un
    // grain passe ENTRE les pixels de la dalle et disparaît. La borne suit
    // la nuit de la page au lieu d'être figée.
    if (q.y > HD_NUIT + 0.14) {
        float lane = 16.0;
        float ix = floor(position.x / lane);
        for (int j = 0; j < 2; j++) {
            float4 h = hdhash42(float2(ix * 1.71 + 3.1, 7.7 + 5.3 * float(j)));
            if (h.x > 0.42) continue;
            float yBirth = mix(1.06, HD_NUIT + 0.22, h.y);
            float life = fract(t * (0.050 + 0.070 * h.w) + h.z * 7.0);
            float rise = 0.16 + 0.18 * h.y;
            float yc = (yBirth - rise * life) * size.y;
            float xc = (ix + 0.5) * lane + (h.z - 0.5) * lane * 0.8
                       + 3.5 * sin(life * 6.2832 * (1.0 + h.w) + h.x * 6.28);
            float2 dp = position - float2(xc, yc);
            float g = exp(-dot(dp, dp) / (0.55 * 0.55));
            if (g <= 0.002) continue;
            float born = hdEnergy(float2(xc, yBirth * size.y) / size.y,
                                  aspect, t);
            float glow = 1.0 - exp(-born * HD_K);
            if (glow < 0.18) continue;
            float env = sin(3.14159 * life);
            float tw = 0.55 + 0.45 * sin(t * (1.9 + 2.4 * h.z) + h.y * 6.28);
            float3 tint2 = mix(float3(1.00, 0.97, 0.92),
                               float3(1.00, 0.80, 0.45), h.w);
            c += tint2 * (g * env * tw * glow * 0.95);
        }
    }

    // Dither : à ces niveaux, les nappes banderaient en anneaux de Mach sur
    // OLED — et un flou n'y changerait rien, on flouterait une image déjà
    // quantifiée.
    c += (hdhash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0))
          - 0.5) * (2.0 / 255.0);
    c = clamp(c, 0.0, 1.0);
    return half4(half3(c), 1.0) * color.a;
}

// MARK: - LA FENTE (l'entrée dorée)
//
// Une OUVERTURE, pas un bouton. La différence tient en une chose : un bouton
// appelle le doigt, une fente appelle un OBJET. Ce qui la fait lire comme un
// trou, c'est que son dedans est plus SOMBRE que la page, et qu'une ombre
// tombe de sa lèvre haute — la lumière vient de la page, donc l'intérieur
// d'un creux est dans l'ombre. Sans ça, on dessine une pastille.
//
// Sa lumière est celle de la famille néon de la maison : cœur crème, gaine
// ambre, buée large — posée en lumière et jamais en contour. Et elle
// SCINTILLE avec la recette de l'étoile-diamant du login : un frémissement
// menu, des flashs francs mais rares, apériodiques (deux périodes sans
// rapport entier), pour que deux instants à cinq secondes d'écart ne se
// ressemblent jamais.
//
// `awake`   : 0 elle dort (un trait, presque rien), 1 elle appelle.
// `swallow` : 0 → 1 pendant qu'elle avale la carte — sa lumière enfle et
//             son cœur blanchit à mesure qu'elle mange.

static float hdRoundBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// MARK: - LE TROU NOIR
//
// HUIT TOURS ONT ÉCHOUÉ SUR LA MÊME CAUSE : la fente n'était pas un TROU,
// c'était un OBJET. Un contour lumineux FERMÉ, d'épaisseur égale partout,
// autour d'un aplat noir, avec un halo rayonnant sur la page — c'est la
// grammaire d'un galet rétroéclairé. On ne rentre pas dans un bouton.
//
// LE MÉCANISME D'ENTRÉE EST ACQUIS ET GELÉ : la ligne de coupe DROITE, et
// LA CONTRADICTION (l'arête lointaine coupée par la carte, la lèvre proche
// qui coupe la carte). Aucune plaque n'est des deux côtés d'un même objet,
// donc « elle passe derrière » n'est plus une lecture disponible. On n'y
// touche pas.
//
// CE QUI SE JOUE ICI, C'EST LA MATIÈRE — le verdict était « ça fait très
// cheap », et il portait sur trois choses dont aucune n'était la couleur :
//   • la lèvre était du CHROME : une bande claire à bord net, d'épaisseur
//     constante. C'est un dock en plastique, et c'était le seul élément de
//     la page qui ne fût ni obsidienne ni lumière ;
//   • le bord de la fente s'arrêtait NET sur la page : s'il y a un dedans et
//     un dehors, c'est une pièce posée ;
//   • RIEN NE VIVAIT : le contour était identique à toutes les images et sur
//     toute sa longueur, alors que dans cette page tout ce qui est beau
//     bouge à sa LISIÈRE — c'est la leçon de l'aurore.
//
// LA FORME, elle, NE BOUGE PAS. Une lentille à pointes a été essayée et
// refusée : « plus de déformation ». Le premium ne vient pas d'une
// silhouette bizarre, il vient de l'obsidienne grainée, d'une spéculaire
// unique et asymétrique, et d'un bord qui se dissout.
//
// `couche` : 0 = le dedans, peint DERRIÈRE la carte ; 1 = la lèvre proche
// (opaque) et ce qui sort, peints DEVANT elle.
// `sunk` : de combien de points le bord bas de la carte est passé sous
// l'arête lointaine. `haut` : idem pour son bord HAUT — la carte se
// raccourcit en s'enfonçant, son sommet a donc sa propre course et une
// occlusion qui ne connaît que le pied éteint la page longtemps après le
// passage. `cw` : sa demi-largeur.
[[ stitchable ]] half4 goldSlot(float2 position, half4 color,
                                float2 size, float t,
                                float pad, float awake, float swallow,
                                float couche, float rayon,
                                float sunk, float haut, float cw,
                                float charge, float eclat) {
    float2 p = position - size * 0.5;
    float2 b = max(size * 0.5 - pad, float2(2.0));
    float ouvert = clamp(awake, 0.0, 1.0);

    const float HD_COUPE = 8.0;
    float yBasC = -b.y + sunk;

    // LE SIXIÈME TEMPS : une fois la carte avalée, la fente SE RESSERRE de
    // trois points, tient, puis se rouvre lentement. C'est le seul moment de
    // toute la séquence où elle agit d'elle-même — et c'est ce qui la rend
    // vivante plutôt que subie. Piloté par `sunk`, donc pur et rejouable.
    float ferme = smoothstep(66.0, 104.0, sunk)
                * (1.0 - smoothstep(112.0, 168.0, sunk));
    float2 bEff = float2(b.x, b.y - 3.0 * ferme);
    float r = min(bEff.y, rayon);
    float d = hdRoundBox(p, bEff, r);

    // LE CONTOUR EST LISSE, et c'est une décision. Une version faisait
    // respirer la lisière par un bruit lent — juste sur un vrai trou, faux
    // ici : sur un contour qu'on TRICHE, une ondulation ne dit pas
    // « vivant », elle dit « mal détouré ».

    float inside = smoothstep(0.9, -0.9, d);
    float levre = smoothstep(HD_COUPE - 1.2, HD_COUPE + 1.2, p.y);

    // L'obturation : ce qui SORT faiblit quand la carte bouche. Le dedans,
    // lui, n'est jamais éteint globalement — il est peint DERRIÈRE la carte,
    // donc la carte le couvre déjà. Les deux ensemble s'annulaient : mesuré,
    // la gorge tombait à 43 % à l'instant précis où la silhouette devait s'y
    // détacher, et la carte redevenait noir sur noir.
    float blocage = smoothstep(0.0, 46.0, max(sunk, 0.0));
    // LE LISERÉ NAÎT DU GESTE, ET DE RIEN D'AUTRE. Au repos la fente n'a NI
    // liseré NI lueur : c'est un dégradé de noir, point. C'est la loi déjà
    // payée sur les cartes (verdict du 2026-08-04 : « le liseré clair au
    // repos, on dirait un bug ») — et c'est elle qui règle enfin le mur des
    // dix tours. Un contour lumineux fermé posé en permanence sur la page
    // EST un objet ; un contour qui n'existe que sous le doigt est une
    // RÉPONSE. On ne peut pas lire comme un bouton ce qui n'est pas là.
    // L'ÉCLAT — le seul moment où la fente parle SANS le doigt.
    //
    // Toute la lumière de la fente descendait de `charge` (le geste) ou de
    // `sunk` (la course de la carte). Une fois la carte au fond, les deux sont
    // immobiles : il n'existait AUCUN événement « ça y est, elle est tombée ».
    // Or c'est lui qui amorce la révélation — le trait s'embrase, et c'est de
    // cet embrasement que la carte renaît.
    //
    // Il s'ajoute au feu au lieu de le remplacer : à cet instant le doigt vient
    // de lâcher, `charge` retombe, et une lumière qui décroît pendant que
    // l'éclat monte donnerait un creux au milieu du beat.
    float feu = clamp(charge + 1.35 * eclat, 0.0, 1.0);
    // L'éclat POUSSE au-delà du plafond du geste : sans ça, une fente déjà à
    // pleine charge n'aurait rien de plus à donner et le beat serait muet.
    float sur = clamp(eclat, 0.0, 1.0);
    float lueur = ouvert * (feu + 0.9 * sur) * (1.0 - 0.30 * blocage);

    // Le scintillement du fond. Il module la TEMPÉRATURE plus que la
    // luminance : à ±30 % de luminance sur une gorge presque noire, c'est le
    // grésillement du galet, déjà refusé.
    float frem = 0.90 + 0.10 * sin(t * 3.4 + 2.0 * sin(t * 1.7));
    float flash = pow(max(0.0, sin(t * 0.79 + 0.7)), 9.0)
                + 0.55 * pow(max(0.0, sin(t * 0.47 + 2.9)), 12.0);
    float vif = (0.78 + 0.22 * flash) * frem;

    // ---- LE DEDANS (couche 0) : du graphite, une braise au FOND.
    // LE DÉGRADÉ ÉTAIT À L'ENVERS DEPUIS LE DÉBUT, et c'est LUI la touche de
    // piano. Je le justifiais par « la lumière entre par le bas, le cœur
    // blanc est sous la fente » — le raisonnement est faux : la LÈVRE PROCHE
    // bouche cette lumière. La seule paroi qu'elle puisse éclairer est la
    // LOINTAINE. Mesuré sur la version refusée, la bouche s'éclaircissait en
    // descendant (18,5 → 29,8, +61 %) : une cavité plus claire au fond qu'à
    // son entrée n'existe pas.
    //
    // Le vrai profil est celui de toute entaille : LA TRANCHE du matériau,
    // vue de champ sur trois points et demi juste sous l'arête, puis un
    // DÉCROCHEMENT franc — la matière finit, le vide commence — puis un
    // puits qui s'éteint vite puis lentement.
    //
    // Le plancher est à 18, pas plus bas, et ce n'est pas un goût : WoopGrain
    // pose par-dessus tout ~180 carrés blancs fixes à 2 % (HaloDawnLab:32).
    // Sur un fond à 11 ça fait +42 % de modulation — ça refabrique les
    // petites étincelles refusées deux fois, dans une couche qu'aucun dither
    // ne rattrape.
    float z = p.y + b.y;
    float tranche = clamp(1.0 - z / 3.5, 0.0, 1.0);
    tranche *= tranche * (3.0 - 2.0 * tranche);
    // Le puits s'assombrit CONTINÛMENT jusqu'au bas de la fente : c'est la
    // loi qui manquait. Une cavité plus claire au fond qu'à son entrée
    // n'existe pas — et une forme qui s'assombrit vers le bas se lit comme
    // un creux, quand celle qui s'éclaircit se lit comme un objet bombé.
    float puits = exp(-max(z - 3.8, 0.0) / 9.5)
                + 0.055 * exp(-max(z - 3.8, 0.0) / 30.0);
    // Le gain horizontal. LE CŒUR BLANC N'EST PAS À GAUCHE : mesuré, le
    // maximum de la page est en bas au CENTRE (L 241-245, saturation 0,075) ;
    // la gauche est l'orange sombre et saturé (L 198, sat 0,44). J'éclairais
    // depuis une source qui n'existe pas — c'est exactement ce que l'œil
    // appelle « fake ». Maximum ramené à x = −0,12, rapport 1,42:1.
    float xn = p.x / max(b.x, 1.0);
    float gainX = 1.04 - 0.31 * (xn + 0.12) - 0.10 * (xn + 0.12) * (xn + 0.12);
    gainX = clamp(gainX, 0.70, 1.06);
    const float3 teinteT = float3(1.00, 0.90, 0.78);
    const float3 teinteP = float3(0.74, 0.72, 0.72);
    // LE PLANCHER EST À 18/255, ET C'EST LE COROLLAIRE OBLIGATOIRE DE LA
    // CAVITÉ OPAQUE. Tant que le fond du trou était un film, sa valeur à
    // l'écran était celle de la page (216) et le plancher de la MATIÈRE ne se
    // voyait pas. Opaque, c'est lui qu'on regarde : à 0,061 il rendait 11/255,
    // et `WoopGrain` pose par-dessus tout des carrés blancs à 2 % — soit +42 %
    // de modulation sur un fond à 11, exactement les petites étincelles déjà
    // refusées deux fois, dans une couche qu'aucun dither ne rattrape.
    // 0,095 × 0,74 = 0,0703 → 17,9/255. Le seuil est mesuré, pas choisi.
    float3 dedans = teinteP * (0.095 + 0.303 * puits)
                  + teinteT * (0.303 * tranche * gainX);

    // LA NAPPE DE CONTACT — le rebond de la braise sur ce qui descend. Elle
    // VOYAGE avec le bord bas de la carte, donc plus de désert au milieu de
    // la course ni de « pop » à l'entrée, et l'occlusion est gratuite : la
    // carte est peinte par-dessus, rien ne fuit au-dessus de son bord.
    //
    // Elle se PINCE au franchissement (+42 %) : c'est ça, l'événement du
    // milieu. Il n'est pas porté par des particules — mesuré au jury, la
    // poussière ne couvre qu'UN POUR CENT de la bouche et ne peut donc rien
    // porter du tout.
    // ELLE EST UNE BANDE, PAS UN DEMI-PLAN. `exp(-max(p.y - yBasC, 0)/9)`
    // vaut UN partout AU-DESSUS du bord bas de la carte, puisque le `max`
    // y est nul : la nappe était à pleine puissance sur toute la hauteur.
    // Cachée derrière la carte au centre, elle FUYAIT de dix points sur ses
    // deux flancs et l'ourlait d'un gris plus clair sur toute sa hauteur —
    // deux sombres à quinze niveaux l'un de l'autre avec une couture douce
    // entre eux, et l'œil lit un CALQUE translucide, pas deux objets. Une
    // fois la carte au fond, le même débord devenait un RECTANGLE clair à
    // bords verticaux dans un trou aux coins arrondis.
    //
    // C'est le piège de la distance signée, celui qui avait déjà rempli
    // tout le creux de buée au troisième tour et qui est commenté en toutes
    // lettres plus haut. Il faut donc éteindre du côté HAUT aussi.
    //
    // Et le garde-fou latéral s'arrête À la largeur de la carte, plus dix
    // points au-delà : une lumière de contact ne dépasse pas l'objet
    // qu'elle touche.
    float nappe = exp(-max(p.y - yBasC, 0.0) / 9.0)
                * smoothstep(-3.5, 1.0, p.y - yBasC)
                * (1.0 - smoothstep(cw - 14.0, cw - 1.0, fabs(p.x)))
                * smoothstep(0.0, 3.0, sunk)
                * (1.0 + 0.42 * smoothstep(20.0, 6.0, (HD_COUPE + b.y) - sunk));
    dedans += float3(0.070, 0.060, 0.052) * (nappe * feu);

    // ---- LA LÈVRE PROCHE : de l'OBSIDIENNE, plus du chrome.
    //
    // La matière de la carte, descendue de deux crans : un graphite grainé
    // de poudre et brossé à l'horizontale. Une surface qui EXISTE sans qu'on
    // ajoute un lumen — c'est la loi de `swapCard`, et c'est ce qui sépare
    // un bijou d'une pièce moulée.
    float grain = hdnoise(p * float2(0.42, 5.6) + 13.0) - 0.5;
    float poudre = hdnoise(p * 1.1 + 41.0) - 0.5;
    float sousLevre = max(p.y - HD_COUPE, 0.0);
    // LA LÈVRE OPAQUE N'EXISTE PLUS, ET SA SUPPRESSION EST GRATUITE.
    //
    // Le pixel le plus SOMBRE de toute la composition (L 7,4) était dix
    // points SOUS la ligne de coupe, dans cette lèvre : la chose qui est
    // DEVANT était quatre fois plus sombre que la cavité. Pour un trou c'est
    // impossible, et c'est ça, avec le reflet central, qui fabriquait la
    // touche de piano.
    //
    // Or elle n'occultait RIEN : `masqueDeBouche` est un demi-plan pleine
    // largeur à la ligne de coupe, appliqué en `.mask` sur les cartes —
    // aucun pixel de carte ne peut exister en dessous, quoi que fasse le
    // shader. Ces vingt-trois points d'obsidienne ne servaient qu'à poser
    // une barre noire sur la page.
    //
    // Sous la coupe, désormais : LA PAGE. L'entaille ne fait plus que
    // trente-neuf points de haut, et elle finit sur une droite.
    float corps = 0.0;
    float3 obsidienne = float3(0.0);
    (void)poudre; (void)grain; (void)sousLevre;

    // PLUS DE SPÉCULAIRE AU MILIEU DE LA MASSE. Mesuré sur la capture : un
    // pic à L 78 à mi-hauteur d'une forme sombre qui vaut 20 autour. Un
    // reflet au MILIEU d'une masse sombre est la signature d'une surface
    // CONVEXE — une barre de caoutchouc, une touche de piano, un galet. Un
    // trou n'a jamais de lumière en son centre : elle est au BORD, ou nulle
    // part. C'était le défaut le plus destructeur de la version refusée.
    float cote = 0.34 + 0.66 * (1.0 - smoothstep(-0.9, 0.8, p.x / b.x));

    // LE CHEVEU DE L'ARÊTE PROCHE : un point de haut, à peine plus clair que
    // la page (1,06 ×), et il MEURT AUX DEUX BOUTS — il ne touche ni le coin
    // gauche ni le droit. Une ligne claire qui n'atteint aucun des deux
    // coins ne peut pas fermer un contour : le grief payé huit fois
    // (« contour lumineux fermé d'épaisseur égale ») devient
    // géométriquement inatteignable, pour le prix d'un profil en x.
    float cheveu = exp(-pow((p.y - HD_COUPE) / 0.9, 2.0))
                 * exp(-pow((xn + 0.20) / 0.62, 4.0))
                 * (1.0 - smoothstep(0.86, 1.0, fabs(xn)));

    // LE LISERÉ, sur le contour et allumé par le seul geste. Cœur mince,
    // gaine courte : le rapport cœur/halo est ce qui fait qu'un filet EST un
    // filet et pas une bande.
    float lw = 0.75 + 0.55 * feu + 0.85 * sur;
    float coeurL = exp(-d * d / (lw * lw));
    float gaineL = exp(-fabs(d) / (2.6 + 2.2 * feu + 5.0 * sur))
                 * (d > 0.0 ? 1.0 : exp(d * 0.55));

    // ---- LA LUEUR QUI MONTE : ce qui sort de la bouche et se pose sur la
    // page AU-DESSUS d'elle. Rien en dessous, rien sur les côtés — un trou
    // n'éclaire pas la page qui l'entoure par en dessous ; une lampe posée
    // dessus, si, et c'était l'indice le plus bruyant de tous.
    float dehors = max(d, 0.0);
    float monte = exp(-dehors / (11.0 + 14.0 * feu + 26.0 * sur))
                * smoothstep(-1.0, 2.0, d)
                * (1.0 - smoothstep(-b.y - 2.0, -b.y + 24.0, p.y));

    // LA SILHOUETTE de la carte coupe ce qui sort. Elle mord 4 pt sur les
    // épaules : une ligne qui s'arrête SUR l'objet est un T franc ; une
    // ligne qui s'arrête à son bord se relit « le bord droit finit où
    // l'arrondi commence » — une forme, pas une occlusion.
    //
    // ET C'ÉTAIT ÇA, LE CALQUE — celui qu'on voit PENDANT la descente et une
    // fois la carte rentrée. La silhouette n'avait qu'UNE borne, le bord BAS
    // de la carte : au-dessus de lui elle valait 1, sans fin, sur toute la
    // hauteur du rectangle hôte. Une fois la carte avalée (`sunk` > 66) son
    // bord bas passe SOUS la fente, et la silhouette se met alors à éteindre
    // le liseré et la lueur PARTOUT — y compris 78 pt au-dessus et 30 pt en
    // dessous de l'ouverture, là où il n'y a plus la moindre carte. Mesuré :
    // une marche VERTICALE de 24 à 26 niveaux à |x| = 82,5 exactement, sous
    // une fente où plus rien ne descend. Une occlusion à bord droit, pleine
    // hauteur, posée sur une page qui n'a rien à occulter : c'est la
    // définition d'un calque, et il durait toute la fin de la séquence.
    //
    // Une occlusion est BORNÉE PAR L'OBJET QUI L'OPÈRE. Trois bornes, donc,
    // et pas une :
    //   • le bord BAS (`yBasC`), déjà là ;
    //   • le bord HAUT (`yHautC`) : la carte se RACCOURCIT en s'enfonçant,
    //     son sommet descend deux fois plus vite que son pied. Sans cette
    //     borne, une carte partie depuis longtemps continue d'occulter ;
    //   • la LIGNE DE COUPE : `masqueDeBouche` interdit tout pixel de carte
    //     en dessous. Rien ne peut y occulter quoi que ce soit.
    float yHautC = -b.y + haut;
    float sil = smoothstep(0.5, -0.5, p.y - yBasC)
              * smoothstep(-0.5, 0.5, p.y - yHautC)
              * smoothstep(HD_COUPE + 0.5, HD_COUPE - 0.5, p.y)
              * (1.0 - smoothstep(cw - 4.5, cw - 3.5, fabs(p.x)))
              * smoothstep(0.0, 2.0, sunk);

    // ---- LA POUSSIÈRE DE DIAMANT — l'ATMOSPHÈRE, pas le mécanisme.
    //
    // Écrite par COULOIRS, jamais une boucle sur N particules : un pixel
    // n'examine que trois couloirs voisins, et chaque couloir porte UN grain
    // dont la position se déduit du temps et d'un haché. Fonction PURE :
    // rien ne s'accumule, rien ne dérive, `-deckSunk` fige un état
    // reproductible.
    //
    // Les seuils anti-cheap, payés ailleurs (le grésillement du galet, les
    // étoiles-bijou du cadran, refusés deux fois) : RARES (quatre à sept
    // grains visibles, régime DÉNOMBRABLE — entre quinze et quatre-vingts
    // c'est de la neige de télévision), LENTS (six à onze secondes pour
    // monter), MENUS, et chacun sa vie avec naissance et mort en fondu.
    float lane = 15.0;
    float poussiere = 0.0;
    float devant = 0.0;
    for (int k = -1; k <= 1; k++) {
        float ix = floor(p.x / lane) + float(k);
        float4 h = hdhash42(float2(ix * 1.73 + 11.3, 4.1));
        if (h.x > 0.55) { continue; }
        float vie = 6.0 + 5.0 * h.y;
        float uu = fract(t / vie + h.z);
        float prof = h.w;
        float my = mix(HD_COUPE - 2.0, -b.y + 3.0, uu);
        float mx = (ix + 0.5) * lane
                 + (h.y - 0.5) * lane * 0.55
                 + (1.2 + 2.4 * prof) * sin(t * (0.28 + 0.22 * h.z)
                                            + h.w * 6.2831);

        // L'ONDE D'ÉTRAVE : la carte descend dans le volume, les grains
        // qu'elle rattrape sont chassés devant elle et écartés sur ses
        // flancs. Le seul instant du geste où ça arrive — et ça n'invente
        // aucun vocabulaire, c'est la même poussière qui réagit.
        float sous = max(my - yBasC, 0.0);
        float etrave = exp(-sous / 10.0)
                     * (1.0 - smoothstep(cw - 2.0, cw + 12.0, fabs(mx)))
                     * smoothstep(0.0, 3.0, sunk);
        my += 9.0 * etrave;
        mx += (mx < 0.0 ? -1.0 : 1.0) * 6.5 * etrave;

        float env = smoothstep(0.0, 0.14, uu) * (1.0 - smoothstep(0.66, 1.0, uu));
        env *= 0.45 + 0.55 * pow(max(0.0, sin(t * (0.9 + 1.7 * h.z)
                                              + h.y * 6.2831)), 3.0);

        float2 dp = float2(p.x - mx, p.y - my);
        float taille = 0.55 + 0.75 * prof;
        // LE DIAMANT de la maison : un cœur menu et une croix à quatre
        // branches. C'est la croix, pas la tache, qui dit « pierre ».
        float coeurG = exp(-dot(dp, dp) / (taille * taille));
        float croix = exp(-dp.y * dp.y / (0.42 * 0.42))
                        * exp(-fabs(dp.x) / (2.6 + 3.0 * prof))
                    + exp(-dp.x * dp.x / (0.42 * 0.42))
                        * exp(-fabs(dp.y) / (1.8 + 2.2 * prof));
        float g = (coeurG + croix * 0.30) * env * (0.45 + 0.55 * prof);
        // Les plus proches passent DEVANT la carte : deux ou trois grains,
        // plus pâles. C'est ce croisement — quelques-uns devant, la plupart
        // cachés derrière — qui fait le VOLUME.
        if (prof > 0.82) { devant += g * 0.55; }
        else             { poussiere += g; }
    }
    poussiere *= inside * ouvert * (0.18 + 0.82 * feu);
    devant *= inside * ouvert * feu;

    // ---- LA FUMÉE, aux ÉPAULES.
    //
    // Les trois lois du coffre du header (`coinSmoke`), déjà payées : le
    // champ GLISSE à mesure que la bouffée vieillit — donc la fumée a une
    // ORIGINE, elle n'apparaît pas autour —, le bruit est déformé deux fois,
    // et l'exposant fait les FILAMENTS À TROUS. Sans lui on obtient un
    // disque de brume, un donut, et c'est immédiatement cheap.
    //
    // Elle sort aux deux points où la largeur de la carte rencontre la
    // fente — là où l'air est chassé. Asymétrique par construction : la
    // volute gauche est plus grosse et part la première. Une bouffée
    // symétrique est un dessin animé.
    float fumee = 0.0;
    float age = clamp((sunk - (HD_COUPE + b.y)) / 58.0, 0.0, 1.0);
    if (age > 0.004 && p.y < HD_COUPE + 6.0) {
        float bouffee = sin(3.14159 * pow(age, 0.72));
        for (int s = 0; s < 2; s++) {
            float sgn = (s == 0) ? -1.0 : 1.0;
            float gros = (s == 0) ? 1.0 : 0.74;   // la gauche est plus grosse
            float retard = (s == 0) ? 0.0 : 0.09; // et part la première
            float ag = max(age - retard, 0.0);
            float2 src = float2(sgn * (cw - 7.0), HD_COUPE - 1.0);
            float2 q = p - src;
            if (q.y > 8.0) { continue; }
            // Le glissement : vers le HAUT, et un peu vers l'extérieur.
            float2 slide = float2(sgn * 13.0, -46.0) * ag;
            float2 sc = (q - slide) * 0.042;
            float w1 = hdfbm(sc + float2(t * 0.021, -t * 0.014));
            float f = hdfbm(sc * 1.34 + float2(2.1 * w1, -1.5 * w1)
                            - float2(t * 0.012, -t * 0.009));
            f = pow(clamp(f, 0.0, 1.0), 2.7);
            // L'enveloppe : elle s'amincit en montant et meurt loin du
            // point de sortie. Jamais de contour — elle se dissout.
            float haut = clamp(-q.y / 62.0, 0.0, 1.0);
            float lat = exp(-fabs(q.x - sgn * 13.0 * ag) / (11.0 + 26.0 * haut));
            float enveloppe = exp(-max(-q.y, 0.0) / (24.0 + 30.0 * ag))
                            * lat * (1.0 - haut * 0.55);
            fumee += bouffee * gros * enveloppe * f;
        }
        fumee *= 0.62 * feu;
    }

    // LE SOUFFLE DE LA LÈVRE : au franchissement, un unique reflet part du
    // centre et file vers les deux bouts. Un BALAYAGE, pas un flash — et
    // piloté par `sunk`, donc pur et rejouable au banc.
    float dS = sunk - (HD_COUPE + b.y);
    float souffle = exp(-dS * dS / (10.0 * 10.0));
    float balayage = exp(-pow((fabs(p.x) - fabs(dS) * 5.5) / 9.0, 2.0)) * souffle;

    // Le fondu d'hôte : toute la lumière meurt AVANT le bord du rectangle,
    // sinon la fente porte une plaque rectangulaire.
    float fade = 1.0 - smoothstep(pad * 0.40, pad * 0.94, dehors);

    // MONOCHROME. « Le orange est horrible » : la fente a quitté la famille
    // chaude. Du graphite et du blanc sur une page d'ambre, c'est le gris
    // que la règle de la maison exige entre le noir et l'orange — et c'est
    // le goût de la maison, premium et minimal.
    const float3 nacre  = float3(1.00, 0.98, 0.96);
    const float3 cendre = float3(0.88, 0.86, 0.85);
    // Le filet du geste reprend la famille de l'arête des cartes : cœur
    // presque blanc, gaine ambre. Il n'existe que sous le doigt, donc il ne
    // peut pas salir la page au repos.
    const float3 creme  = float3(1.00, 0.97, 0.90);
    const float3 ambre  = float3(1.00, 0.68, 0.30);
    // La fumée est GRISE. Jamais blanche, jamais orange : c'est la couleur
    // que la maison met entre le noir et l'ambre.
    const float3 gris   = float3(0.66, 0.64, 0.63);

    // LE LISERÉ est coupé par la carte comme le reste : c'est la moitié
    // « la fente est DERRIÈRE elle » de la contradiction, et elle est
    // intouchable.
    float3 lum = teinteT * (cheveu * 0.30)
               + creme  * (coeurL * (0.30 + 1.05 * feu + 1.30 * sur)
                           * vif * cote * (1.0 - sil))
               + ambre  * (gaineL * (0.22 + 0.72 * feu + 0.95 * sur)
                           * vif * cote * (1.0 - sil))
               + nacre  * (balayage * levre * inside * 0.50 * cote)
               + nacre  * (devant * 0.85)
               + cendre * (monte * 0.26 * lueur * (1.0 - sil))
               + gris   * (fumee * 0.85 * fade);
    lum *= fade;

    // ---- Composition prémultipliée.
    float a;
    float3 c;
    if (couche < 0.5) {
        // LE DEDANS, opaque : sous la fente la page vaut L 0,7, et le
        // moindre pour cent de transparence injectait dans toute la gorge de
        // quoi doubler sa valeur. Un trou à travers lequel on voit la page
        // n'est pas un trou, c'est une découpe.
        // LA FORME SE REFERME. En arrêtant le noir à la ligne de coupe,
        // il ne restait qu'une bande interrompue par la carte, dont les deux
        // bouts — les arcs de coin de la fente — ne se rattachaient à rien :
        // deux oreilles posées sur la zone la plus claire de l'écran, et une
        // silhouette composite « carte + appendices » où l'œil ne peut plus
        // décider qui déborde de quoi.
        //
        // J'avais supprimé la lèvre parce qu'elle n'occultait rien : c'était
        // vrai, mais elle faisait autre chose — elle FERMAIT LA FORME. Un
        // trou n'est pas seulement un occulteur, c'est une silhouette.
        //
        // UNE SEULE LOI, ET C'EST TOUT LE SUJET. La version d'avant posait
        // un SECOND dégradé — une dissolution du bord bas — par-dessus
        // celui du puits, pour adoucir la marche contre la page. Les deux
        // pentes se croisaient vers le bas de la fente, et deux dégradés qui
        // se croisent font un GENOU : mesuré, une marche sur 97 % de la
        // largeur à huit points du bas, aux trois profondeurs. Un genou qui
        // traverse toute la largeur, c'est le bord bas d'un calque
        // translucide posé sur la page.
        //
        // ET LA COUVERTURE ÉTAIT LE CALQUE. Faire suivre à l'ALPHA la loi de
        // la matière tuait bien le genou, mais au prix exact du sujet : plus
        // la cavité s'enfonçait, plus elle devenait TRANSPARENTE. Mesuré sur
        // l'écran, au point près et confirmé par le modèle : à 4 pt sous
        // l'arête R 72 (prédit 70,6), à 58 pt R 216 (prédit 218) pour une
        // page à 229 — 89 % de la page passait au travers du fond du trou.
        // Une cavité qui se fond dans la PAGE au lieu de se fondre dans le
        // NOIR n'est pas un trou : c'est un film gris posé dessus. C'était ça,
        // le « calque » — pendant la descente il débordait de 17 pt de chaque
        // côté de la carte et de 23 pt sous la ligne de coupe, et une fois la
        // carte avalée il était tout ce qui restait à l'écran.
        //
        // Le test qui tranche, et qu'aucun réglage ne trompe : deux instants
        // du fond éloignés (`-haloFreeze 0` / `300`) changent tout ce qu'il y
        // a derrière la fente. Un TROU rend les mêmes pixels aux deux
        // instants. Un calque, non.
        //
        // Le genou, lui, n'a jamais eu besoin de l'alpha : il venait de DEUX
        // dégradés qui se croisaient. Il n'en reste qu'un, la loi du puits, et
        // une courbe unique n'a pas de genou par construction. Le bord bas
        // n'est pas une marche à adoucir — c'est la lèvre proche, et une
        // entaille FINIT quelque part.
        a = clamp(inside, 0.0, 1.0);
        c = (dedans + nacre * poussiere) * a;
        c = min(c, float3(a));
    } else {
        // LA LÈVRE, matière opaque, la fumée et la lumière PAR-DESSUS en
        // additif vrai (c au-delà de la couverture : licite en
        // prémultiplié). Un voile porté par l'alpha ASSOMBRIT ce qu'il
        // recouvre — mesuré au jury, il éteignait le rail de la carte de
        // 255 à 198. De la lumière qui assombrit est une plaque.
        a = clamp(corps, 0.0, 1.0);
        c = obsidienne * a + lum;
    }
    // LE DITHER, FIGÉ DANS LA BOUCHE. Animé à ±2/255 sur une gorge à R 27,
    // c'est 7 % de modulation par pixel ET par image, exactement à la
    // fréquence spatiale des cœurs de grain : c'est le grésillement du
    // galet, littéralement, et il a déjà été refusé. Dedans il est spatial
    // et à ±1/255 ; dehors, où les dégradés sont plus doux, on garde
    // l'animé qui tue le banding de l'OLED.
    float dansBouche = inside * (1.0 - levre);
    float dth = dansBouche > 0.5
        ? (hdhash21(position * 1.113) - 0.5) * (1.0 / 255.0)
        : (hdhash21(position * 1.113
                    + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
          * (2.0 / 255.0);
    c += dth * max(a, 0.25);
    c = clamp(c, 0.0, 1.0);
    return half4(half3(c), half(a));
}
