#include <metal_stdlib>
using namespace metal;

// MARK: - Bouton « primary néon » — obsidienne fumée, métal liquide, paillettes
//
// La plaque est la SŒUR de la barre d'onglets bijou (NavMonolith.metal) : même
// obsidienne, mêmes noirs, même façon de se creuser — poussée plus loin, parce
// qu'ici il n'y a pas de pastille pour porter le bijou : c'est la plaque
// elle-même qui doit être exquise. Le néon, lui, est celui du logo lune.
//
// Ce qui fait la profondeur, et qu'un simple dégradé ne donne JAMAIS (le
// premier jet en était un et il lisait « cheap ») — les cinq sont nécessaires,
// aucun ne suffit :
//
//   1. LE DÉGRADÉ EST COURT. #121316 en haut → #050507 en bas. Une pierre, pas
//      un ciel. Un dégradé long fait une surface peinte.
//   2. LA VIGNETTE creuse le bas et les flancs jusqu'au noir vrai. Sans elle
//      l'objet est une plaque ; avec, c'est un galet.
//   3. LE BISEAU EST PLUS SOMBRE QUE LA PIERRE, juste en dedans de l'arête.
//      C'est ce qui lui donne une TRANCHE, et c'est contre lui que le hairline
//      du dessus a enfin quelque chose contre quoi briller. Contre-intuitif :
//      on ASSOMBRIT le bord pour que l'objet paraisse plus brillant.
//   4. LE GLOW COLLE À LA PAROI et se pondère en haut à gauche : il suit la
//      courbure au lieu de barrer la plaque d'un dégradé linéaire.
//   5. LA FUMÉE. Sous le verre, des nappes de noir qui bougent — c'est le
//      « dégradé de noir magique à l'intérieur ». Sans elle, les quatre
//      premiers points donnent un objet propre mais MORT : un noir uniforme
//      n'a pas d'intérieur, il a une surface.
//
// Par-dessus, deux choses que la nav bar n'a pas :
//
//   LE MÉTAL LIQUIDE — un brossage anisotrope qui se COMPRIME en approchant de
//   l'arête. Des rayures d'espacement constant lisent « plaque rayée » ; des
//   rayures qui se resserrent au bord lisent « métal massif tourné », parce que
//   c'est ce que fait la perspective sur une surface qui s'incurve. Une traînée
//   spéculaire les traverse lentement — sans mouvement, un brossage n'est
//   qu'une texture ; ce qui trahit le métal, c'est que sa haute lumière SE
//   DÉPLACE.
//
//   LES PAILLETTES — de très rares éclats, un par cellule de 27 pt, jamais au
//   même instant. Presque toutes argent ; une sur cinq dorée. Elles ne brillent
//   QUE là où la lumière les frappe : une paillette dans la zone noire du bas
//   serait une poussière, pas un bijou.

constant float3 kNeonSpill = float3(1.00, 0.42, 0.13);  // le halo du tube lune
// La matière est NEUTRE : R-B = 0 aux quatre points mesurés sur la
// référence. Ni bleu de studio ni chaleur — du gris pur.
constant float3 kStudio    = float3(1.00, 1.00, 1.00);  // la lampe, neutre
constant float3 kPolish    = float3(0.97, 0.98, 1.00);  // la tranche polie

static float npHash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// Bruit de valeur lissé — la brique de la fumée.
static float npValue(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = npHash21(i), b = npHash21(i + float2(1, 0));
    float c = npHash21(i + float2(0, 1)), e = npHash21(i + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, e, f.x), f.y);
}

/// LA FUMÉE sous le verre. Trois octaves qui DÉRIVENT À DES VITESSES
/// DIFFÉRENTES — c'est le point : trois octaves qui bougent ensemble donnent
/// une texture qui glisse, et l'œil voit un calque qui défile. À des vitesses
/// différentes, les nappes se traversent et se recomposent sans jamais se
/// répéter : ça ne glisse plus, ça VIT.
///
/// Les échelles sont larges (28, 13 et 6 pt) : la fumée doit se lire comme des
/// nappes, pas comme du grain. Le grain, c'est le brossage, et il a déjà sa
/// place.
static float npSmoke(float2 q, float t) {
    float n = 0.52 * npValue(q / 28.0 + float2(t * 0.013, -t * 0.008))
            + 0.31 * npValue(q / 13.0 + float2(-t * 0.021, t * 0.016) + 11.3)
            + 0.17 * npValue(q / 6.0  + float2(t * 0.034, t * 0.027) + 27.7);
    return n - 0.5;
}

/// Distance signée au rectangle arrondi (négatif dedans), en POINTS.
static float npRound(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Normale sortante — elle donne au biseau la lumière de SON côté.
static float2 npNormal(float2 p, float2 b, float r) {
    float2 s = sign(p);
    float2 q = abs(p) - b + r;
    if (max(q.x, q.y) > 0.0) return normalize(max(q, 1e-4)) * s;
    return (q.x > q.y) ? float2(s.x, 0.0) : float2(0.0, s.y);
}

/// Le BROSSAGE, avec la compression au bord.
///
/// `dIn` = profondeur depuis l'arête. On ne lit pas le bruit à la hauteur `q.y`
/// mais à une hauteur DÉFORMÉE : près du bord, un même intervalle de `q.y`
/// couvre plus de bruit, donc les rayures s'y resserrent — la même idée que sur
/// la nav bar, où la compression sur l'arête transforme un trait plat en fil
/// ROND.
///
/// Nyquist : à 3x, un pas plus fin que 0,67 pt moire. Le pas au centre vaut
/// 0,9 pt et la compression est PLAFONNÉE à 1,7× — soit 0,53 pt au plus serré,
/// juste sous la limite. Sans ce plafond, le bord scintille dès que la vue
/// bouge d'un pixel.
static float npBrush(float2 q, float dy) {
    // `dy` = distance à l'arête HORIZONTALE la plus proche, pas au contour.
    // Mesurée au contour, la compression suit les arcs des coins et dessine
    // des anneaux concentriques — on voit un tourbillon, pas un brossage.
    // Une rayure de métal brossé reste DROITE : elle se resserre en haut et en
    // bas, jamais autour des angles.
    float squeeze = 1.0 + 0.7 * exp(-dy / 4.5);
    float y = q.y * squeeze / 0.9;
    float i = floor(y), f = fract(y);
    // La clé du hash ne dépend PAS de x : la rayure court d'un bord à l'autre,
    // sans couture. Un premier jet indexait sur `floor(q.x / 90)` en croyant
    // varier le motif — ça découpait la plaque en blocs de 90 pt à rupture
    // franche. Une rayure de métal ne change jamais de FORME en cours de
    // route ; elle change d'INTENSITÉ.
    float fine = mix(npHash21(float2(37.0, i)),
                     npHash21(float2(37.0, i + 1.0)),
                     f * f * (3.0 - 2.0 * f)) - 0.5;
    float press = 0.70 + 0.30 * sin(q.x * 0.041 + 1.3) * sin(q.x * 0.0117);
    return fine * press;
}

/// `lit` : 0 au repos, 1 le doigt posé (rampe côté SwiftUI).
[[ stitchable ]] half4 neonPlate(float2 position, half4 color, float2 size,
                                 float t, float pad, float radius, float lit) {
    float2 q = position - pad;
    float W = size.x - 2.0 * pad;
    float H = size.y - 2.0 * pad;
    float2 b = float2(W, H) * 0.5;
    float2 p = q - b;
    float r = min(radius, min(b.x, b.y));

    float d = npRound(p, b, r);
    float inside = clamp(0.5 - d * 3.0, 0.0, 1.0);
    float2 n = npNormal(p, b, r);
    float dIn = max(-d, 0.0);
    float ux = clamp(q.x / max(W, 1.0), 0.0, 1.0);
    float uy = clamp(q.y / max(H, 1.0), 0.0, 1.0);

    float3 rgb = float3(0.0);

    if (inside > 0.0) {
        // 1. LE SOCLE, court. Il s'ALOURDIT à l'allumage : le haut monte, le bas
        // descend. « Plus lourd » n'est pas plus sombre, c'est plus CONTRASTÉ.
        float3 top = mix(float3(0.0784, 0.0784, 0.0784),
                         float3(0.0941, 0.0941, 0.0941), lit);
        float3 bot = mix(float3(0.0196, 0.0196, 0.0196),
                         float3(0.0118, 0.0118, 0.0118), lit);
        float g = uy * uy * (3.0 - 2.0 * uy);
        float3 base = mix(top, bot, g);

        // 5. LA FUMÉE, en MULTIPLICATIF. Une fumée additive éclaircit le noir
        // et le rend laiteux ; en multipliant, les nappes sombres restent du
        // noir vrai et seules les claires respirent. ±34 % sur un socle qui vit
        // entre 5 et 22/255, soit 2 à 7 niveaux : c'est peu, et c'est
        // exactement ce qu'il faut — au-delà on voit un nuage posé sur un
        // bouton. Le dither d'un demi-niveau, plus bas, est ce qui rend ces
        // 2 niveaux lisibles au lieu de les faire bander.
        float smoke = npSmoke(q, t);
        base *= 1.0 + smoke * 0.68;

        // 2. LA VIGNETTE : le bas et les flancs rentrent au noir vrai.
        float vig = 1.0 - 0.42 * smoothstep(0.40, 1.0, uy)
                        - 0.16 * smoothstep(0.55, 1.0, fabs(ux * 2.0 - 1.0));
        vig = clamp(vig, 0.0, 1.0);

        // 3. LE BISEAU SOMBRE, juste en dedans de l'arête : la tranche.
        float bevel = exp(-dIn / 2.2);
        base *= vig * (1.0 - 0.50 * bevel);

        // 4. LE GLOW QUI COLLE À LA PAROI, pondéré haut-gauche : le galet poli.
        float wall = exp(-dIn / 3.6);
        float upleft = clamp(0.62 * (1.0 - uy) + 0.38 * (1.0 - ux), 0.0, 1.0);
        float sheen = wall * pow(upleft, 2.0) * 0.115;
        float dome = exp(-uy * 4.4) * (0.46 + 0.54 * (1.0 - ux)) * 0.038;
        // La fumée module aussi CE QUI ÉCLAIRE : c'est ce qui la fait passer
        // pour un volume sous le verre plutôt que pour une salissure dessus.
        float lightHere = (sheen + dome) * (1.0 + smoke * 0.85);

        // ---- LE MÉTAL LIQUIDE. Le brossage module la RÉFLEXION
        // (multiplicatif), jamais la lumière (additif) : une rayure ne crée pas
        // de lumière là où il n'y en a pas, elle en renvoie plus ou moins.
        float brush = npBrush(q, min(q.y, H - q.y));
        base *= 1.0 + brush * 0.055;

        // PAS DE TRAÎNÉE SPÉCULAIRE. Mesuré sur la référence de Kathryn (la
        // pièce noire mate) : dans toute l'image il n'y a qu'UN seul éclat, et
        // il est sur la TRANCHE polie, jamais sur la face. Une face mate ne
        // renvoie pas de haute lumière — la traînée de métal liquide qui vivait
        // ici était le contraire exact de la matière visée.

        // ---- LE DÉBORDEMENT DU NÉON : un SOUFFLE, pas une inondation. Un
        // premier réglage trois fois plus fort faisait virer la plaque au
        // cuivre — on ne voyait plus un métal noir chauffé mais du bronze.
        float2 nd = (q - float2(W * 0.5, H * 0.52)) / float2(W * 0.40, H * 0.52);
        float spill = exp(-dot(nd, nd)) * lit;
        float2 nu = (q - float2(W * 0.5, H * 0.06)) / float2(W * 0.50, H * 0.30);
        spill += 0.35 * exp(-dot(nu, nu)) * lit;
        float warmSheen = max(brush, 0.0) * spill * 0.30;

        // ---- LE MOUCHETIS. Mesuré sur la référence : écart-type 9 niveaux
        // sur une face qui en vaut 45, soit 20 % — ce n'est PAS discret. Un
        // grain pour 445 px, taille médiane 2 px. Et il est À DEUX FACES :
        // 1,07 % de grains clairs, 0,61 % de sombres. Ce n'est donc pas de la
        // poussière ajoutée par-dessus (qui ne saurait qu'éclaircir), c'est la
        // matière elle-même qui est granuleuse — du sablé, du fondu brut.
        // D'où un facteur MULTIPLICATIF centré sur 1 : il éclaircit et
        // assombrit à parts voisines.
        float gr = npHash21(floor(q * 3.0) + 61.0);
        float speck = (gr - 0.5) * 2.0;
        speck = sign(speck) * pow(fabs(speck), 2.6);   // rare et franc
        base *= 1.0 + speck * 0.52;

        // Tone map PAR CANAL : une lumière ambrée qui monte sature le rouge
        // d'abord, le bleu en dernier. Tonemapper la luminance puis colorier
        // donnerait un cœur blanc — l'erreur classique de ce projet.
        float3 light = (lightHere + 0.06 * spill) * kStudio
                     + (0.155 * spill + warmSheen) * kNeonSpill
;
        rgb = base + (1.0 - exp(-light));
    }

    // ---- LE HAIRLINE. Argent, presque rien, vivant SEULEMENT sur l'arête
    // haute — la retenue de la nav bar : un seul filet, jamais un contour. En
    // bas, pas de trait mais un réchauffement à l'allumage : la lumière du tube
    // passe sous la plaque.
    float wN = abs(n.x) + abs(n.y);
    float topness = clamp(-n.y / max(wN, 1e-4), 0.0, 1.0);
    float leftness = clamp(-n.x / max(wN, 1e-4), 0.0, 1.0);
    float downness = clamp(n.y / max(wN, 1e-4), 0.0, 1.0);

    float edge = exp(-d * d / (2.0 * 0.62 * 0.62));
    float3 rimI = (0.115 * pow(topness, 2.0) + 0.045 * leftness) * kPolish
                             * (1.0 + 0.30 * lit)
                + (0.035 + 0.30 * lit) * downness * kNeonSpill;
    rgb += (1.0 - exp(-rimI)) * edge;

    // Dither d'un demi-niveau. Il n'est pas cosmétique ici : toute la fumée vit
    // dans une plage de 2 à 7 niveaux, et sans lui elle se réduirait à trois ou
    // quatre marches franches.
    rgb += (npHash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
           * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);

    rgb *= inside;
    float a = inside;
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}
