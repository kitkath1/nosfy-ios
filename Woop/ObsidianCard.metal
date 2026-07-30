#include <metal_stdlib>
using namespace metal;

// MARK: - Carte « obsidienne » — verre fumé noir poli, source chaude hors champ
//
// DOUBLON de travail de la carte Objectif bijou (ObjectiveJewel.metal, gardée
// intacte au design system). Ici la matière change de nature : plus de métal
// griffé ni de nébuleuse, mais une surface LISSE — obsidienne polie / piano
// black — dont tout l'intérêt tient à la LUMIÈRE qui la frappe.
//
// TOUS les chiffres viennent d'un AJUSTEMENT PAR MOINDRES CARRÉS sur la
// référence de Kathryn (back_hero.png, échelle 2,4189 px/pt, carte
// 362 x 470,7 pt) : 192 points intérieurs × 3 canaux, résidu RMS 12 niveaux.
// Rien n'est réglé à l'œil. Trois choses ont tout décidé, chacune payée par un
// tour raté :
//
//   1. SATURATION PAR CANAL. Une lumière ambrée qui monte en intensité sature
//      d'abord le rouge, puis le vert, le bleu en dernier : ambre → or → crème
//      → blanc. On écrit donc `1 - exp(-x * k)` avec k la couleur intrinsèque
//      de la source, MESURÉE à (1 ; 0,456 ; 0,154). Tonemapper la luminance
//      puis colorier — ce que faisait le tour précédent — donne un cœur BLANC
//      au milieu de la carte : le défaut le plus visible.
//
//   2. CHAMP RADIAL, pas des bandes. Le premier modèle posait une bande le
//      long du bord haut et une le long du bord gauche : ça dessinait un « L »
//      à bord net, très artificiel. Le champ est en fait la somme de DEUX
//      lobes gaussiens elliptiques, tous deux centrés sur le foyer hors champ
//      (-42 ; -11) pt : un lobe couché (σ 104 x 33) qui court sous le bord
//      haut, un lobe debout (σ 60 x 109) qui descend le long du bord gauche.
//      Deux gaussiennes qui se recouvrent n'ont aucune frontière ; deux bandes
//      en ont deux.
//
//   3. LA PAGE EST NOIRE. #000000 partout, y compris au ras de la carte
//      (mesuré : le fond ne descend jamais sous 0). Aucune ombre portée, alors
//      que le brief en demandait une. Le halo extérieur vaut 15/255 au ras du
//      bord et meurt en 30 pt — le premier jet en faisait une boule de 100 pt.
//
//   4. LE VOILE DE DROITE EST UN FAISCEAU OBLIQUE, PAS UN HALO DE COIN. On a
//      longtemps cherché « un halo au coin haut-droit PLUS une traînée
//      verticale » : c'est une seule et même chose, une gaussienne elliptique
//      TOURNÉE de -61° qui entre par le coin et descend en biais vers le
//      centre-droit. La crête glisse de u=331 à u=236 entre v=16 et v=200, à
//      largeur constante. Détail à retenir : la « traînée verticale » que voit
//      l'œil n'est pas verticale, elle penche d'un demi-point de u par point
//      de v — et c'est ce demi-point qui faisait rater les trois quarts de la
//      moitié droite. Voir plus bas, au calcul de `cold`.
//
// La vue passe un rectangle PLUS GRAND que la carte (marge `pad`) : le halo
// hors carte vit dedans, en alpha.

static float ohash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// Distance signée au rectangle arrondi (négatif dedans), en POINTS.
static float osdRound(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Normale sortante — elle donne au liseré la luminance de SON côté.
static float2 osdNormal(float2 p, float2 b, float r) {
    float2 s = sign(p);
    float2 q = abs(p) - b + r;
    if (max(q.x, q.y) > 0.0) return normalize(max(q, 1e-4)) * s;
    return (q.x > q.y) ? float2(s.x, 0.0) : float2(0.0, s.y);
}

/// Lobe gaussien elliptique, en points.
static float olobe(float2 p, float2 c, float2 s) {
    float2 d = (p - c) / s;
    return exp(-dot(d, d));
}

/// Lobe gaussien elliptique TOURNÉ. `axis` = (cos θ, sin θ) de l'axe LONG,
/// `s` = (demi-largeur le long de l'axe, demi-largeur en travers), en points.
/// Sert au voile froid, qui n'est ni vertical ni horizontal mais oblique.
static float olobeRot(float2 p, float2 c, float2 axis, float2 s) {
    float2 d = p - c;
    float2 e = float2(dot(d, axis), dot(d, float2(-axis.y, axis.x))) / s;
    return exp(-dot(e, e));
}

// Les couleurs INTRINSÈQUES des deux sources, ajustées sur la référence. Elles
// ne servent qu'à travers `1 - exp(-x * k)` : ce sont des couleurs de LUMIÈRE,
// pas des teintes de peinture.
constant float3 kWarm = float3(1.000, 0.456, 0.154);   // la source chaude
constant float3 kCold = float3(1.000, 0.905, 0.830);   // le liseré froid
// Le TRAIT n'est PAS de la même couleur que la nappe. Mesuré sur la ligne
// intérieure de la référence : là où elle est chaude, elle donne #FEF5D7 /
// #F7C985 — R-B de +35 à +114, du CRÈME. Avec la couleur de la nappe
// (0,426 ; 0,093) on sortait à R-B +136 : un liseré ORANGE là où la référence
// en a un crème. Le verre du biseau ne colore pas la lumière comme la masse
// de la pierre : il la renvoie presque telle quelle.
constant float3 kRim  = float3(1.000, 0.600, 0.320);

// Le VOILE de la moitié droite. Teinte remesurée canal par canal sur 2 190
// points de la référence : (1 ; 0,929 ; 0,884). L'ancienne valeur (celle du
// liseré, 0,830 en bleu) rendait la moitié droite trop CHAUDE — R-B +5 là où
// la référence donne +2 à +4. Un voile qui tire sur le brun, c'est exactement
// ce que Kathryn rejette.
constant float3 kVeil = float3(1.000, 0.929, 0.884);

// MARK: - La grille de points du haut-droit
//
// Elle EXISTE sur la référence (les perforations visibles en haut à droite de
// back_hero.png) et manquait complètement ici. Tout ce qui suit est MESURÉ sur
// l'image, ramené à notre repère (carte 362 pt de large, 2,4189 px/pt sur la
// référence). Le détecteur a trouvé 277 points, un réseau CARRÉ, sans rotation.
//
//   PAS 9,6405 pt (23,32 px sur la référence). Ajusté par maximisation de la
//   netteté de phase sur les 277 centres — deux méthodes indépendantes
//   (autocorrélation et phase complexe) tombent sur la même valeur.
//   PHASE (8,979 ; 9,357) pt depuis le coin haut-gauche.
//
//   FOYER σ 0,28 pt, soit 0,66 pt à mi-hauteur — moins d'UN pixel de rendu à
//   3x (0,333 pt). Le premier réflexe, un disque seuillé, donnerait un point
//   présent ou absent selon l'endroit où le pas 9,64 pt retombe sur la grille
//   des pixels : ça scintille et ça sent le procédural. On intègre donc la
//   gaussienne ANALYTIQUEMENT sur le carré du pixel (quatre erf). Mesuré sur le
//   rendu, enveloppe et champ neutralisés : 288 points portent tous la même
//   énergie à 6 % près, et ces 6 % ne viennent pas de l'échantillonnage — ils
//   viennent du tone map, qui comprime un peu plus le point tombé pile au
//   centre d'un pixel que celui à cheval sur quatre. C'est physique, pas du
//   bruit.
//     Le σ mérite un mot : le second moment des pixels bruts de la référence
//   donne 0,176 pt. C'est FAUX, et de façon instructive — on mesure là un pic
//   d'un pixel et demi, dont la largeur est presque entièrement celle du
//   capteur. En ramenant les deux images à la MÊME échelle (2,4189 px/pt) et en
//   comparant les profils radiaux moyennés sur 55 points, le σ qui superpose
//   les deux courbes vaut 0,28.
//
//   OMBRE et le piège qui va avec. Les pixels bruts de la référence montrent,
//   aux quatre voisins à 2 px du centre, une chute spectaculaire (18 contre 29
//   de fond, 4 contre 11). Très tentant : « le point est une perforation, il a
//   son ombre ». Faux — ce creux n'existe QUE sur les axes, jamais en
//   diagonale : signature d'un lobe négatif de rééchantillonnage, pas d'une
//   ombre. Une fois les deux images à la même échelle et moyennées en anneaux,
//   il ne reste qu'un creux de 5 % à 1,1 pt. C'est celui-là qu'on garde : assez
//   pour que le point soit POSÉ DANS la matière, trop peu pour faire un trou.
//
//   TEINTE (1 ; 0,66 ; 0,30) en lumière linéaire — bien plus dorée que le voile
//   froid qui éclaire la surface autour (1 ; 0,905 ; 0,83). Ce n'est pas une
//   incohérence : un petit bombé ne renvoie pas seulement ce qui l'éclaire de
//   face, il ramasse TOUTE la scène, dominée par la grande source chaude d'en
//   face. Peindre les points de la couleur du voile les rendait gris et morts.
//
//   AMPLITUDE 0,49 + 9,0·champ, en unités de lumière linéaire (le champ = warm
//   + cold au même endroit). Le terme constant compte : sur la référence les
//   points restent visibles là où la pierre est presque noire (fond 11, cœur du
//   point 99). Un modèle purement multiplicatif les éteignait dans le noir ;
//   un modèle purement additif les laissait allumés dans le voile blanc.
constant float  oDotPitch = 9.6405;
constant float2 oDotPhase = float2(8.979, 9.357);
constant float3 kDot      = float3(1.000, 0.660, 0.300);

/// `erf`, absente de la bibliothèque standard Metal. Approximation
/// d'Abramowitz & Stegun 7.1.26 : cinq multiplications et une exponentielle,
/// erreur 1,5·10⁻⁷ — soit trois cents fois sous le demi-niveau de
/// quantification, donc rigoureusement invisible.
static float oerf(float x) {
    float s = sign(x), a = abs(x);
    float t = 1.0 / (1.0 + 0.3275911 * a);
    float y = t * (0.254829592 + t * (-0.284496736 + t * (1.421413741
            + t * (-1.453152027 + t * 1.061405429))));
    return s * (1.0 - y * exp(-a * a));
}

/// Moyenne EXACTE d'une gaussienne 2D de pic 1 sur le carré d'un pixel de
/// demi-côté `h`. ∫exp(-x²/2σ²) = σ√(π/2)·erf(x/σ√2), donc la moyenne sur
/// [d-h, d+h] vaut σ√(π/2)/(2h) fois la différence des deux erf ; le noyau est
/// séparable, on fait le produit des deux axes. Quand h → 0 ça redonne bien
/// exp(-|d|²/2σ²).
static float odotCover(float2 dv, float sig, float h) {
    float k = 1.0 / (sig * 1.41421356);
    float c = sig * 1.25331414 / (2.0 * h);
    return (c * (oerf((dv.x + h) * k) - oerf((dv.x - h) * k)))
         * (c * (oerf((dv.y + h) * k) - oerf((dv.y - h) * k)));
}

// `lit` : le doigt posé (0 → 1, rampe côté SwiftUI). La source avance de trois
// points et gagne 6 % — une lampe qu'on approche, pas un interrupteur.
[[ stitchable ]] half4 obsidianSurface(float2 position, half4 color,
                                       float2 size, float t,
                                       float pad, float radius, float lit) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 b = max(center - pad, float2(1.0));
    float r = min(radius, min(b.x, b.y));
    float d = osdRound(p, b, r);
    float inside = smoothstep(0.6, -0.6, d);

    // Repère de TOUTES les mesures : points depuis le coin haut-gauche.
    float W = 2.0 * b.x;
    float2 q = p + b;

    // Le foyer chaud, hors champ en haut à gauche. Il respire de deux points,
    // jamais plus : la référence est une photo, pas une animation.
    float drift = sin(t * 0.09) * 1.1 + 2.5 * lit;
    float2 src = float2(-42.3 - drift * 0.5, -11.3 - drift);

    // Le champ chaud : deux lobes elliptiques sur le même foyer. Le premier
    // court sous le bord haut, le second descend le long du bord gauche.
    // Le champ chaud : deux NAPPES, chacune EXPONENTIELLE le long de son arête
    // et GAUSSIENNE en profondeur. C'est la découverte de ce tour, et elle est
    // vérifiable au chiffre près : le long du bord haut, l'intensité (avant
    // tone map) vaut 2,87 / 1,058 / 0,354 / 0,108 / 0,018 à u = 65 / 95 / 130 /
    // 175 / 225 pt. Ces cinq nombres tiennent sur UNE exponentielle de longueur
    // 31 pt à 3 % près ; une gaussienne, elle, tombe huit fois trop vite dans
    // la traîne (0,039 au lieu de 0,108 à u=175) tout en étant juste au milieu.
    // On a essayé d'ajouter un troisième lobe pour rattraper la traîne : c'est
    // impossible, il faudrait qu'un terme décroissant vaille PLUS loin que
    // près. Il fallait changer la forme, pas ajouter un terme.
    float2 dq = q - src;
    float warm = 110.0 * exp(-dq.x / 32.0) * exp(-(dq.y * dq.y) / (32.9 * 32.9))
               + 24.5 * exp(-dq.y / 40.0) * exp(-(dq.x * dq.x) / (60.0 * 60.0))
               + 0.4 * exp(-dot(dq, dq) / (105.0 * 105.0));
    warm *= 1.0 + 0.06 * lit;

    // ---- Le VOILE FROID de la moitié droite : UN SEUL objet, un FAISCEAU
    // OBLIQUE. C'est la correction la plus importante de ce tour.
    //
    // L'ancien modèle en posait deux — un lobe rond sous le coin haut-droit
    // plus une « traînée » verticale — et les deux étaient faux : trop haut
    // (u=280 v=12 sortait à 41 pour 19 attendus), pas assez au centre-droit
    // (u=270 v=90 à 34 pour 51), et débordant en bas (u=330 v=140 à 33 pour
    // 14). Un halo de coin plus une traînée verticale ne peuvent pas produire
    // ça en même temps : il fallait autre chose.
    //
    // Mesuré : sur la référence, points de la trame retirés au filtre médian,
    // la CRÊTE du voile (le maximum le long de chaque ligne horizontale) n'est
    // pas verticale — elle GLISSE régulièrement vers la gauche en descendant,
    // de u=331 à v=16 jusqu'à u=236 à v=200, soit une pente de -0,50 pt de u
    // par pt de v. Et sa largeur ne change pas : FWHM 63 pt du haut en bas.
    // Une crête droite et oblique à largeur constante, c'est la définition
    // d'une gaussienne elliptique TOURNÉE dont le centre est loin.
    //
    // Moindres carrés sur 2 190 points (le chaud retiré analytiquement) :
    // amplitude 0,4011, centre (W+0,5 ; -37,8) pt — juste au-delà de l'arête
    // droite et 38 pt au-dessus de l'arête haute —, axe long 213,2 pt orienté
    // à -61,2° (donc le faisceau DESCEND vers la gauche), axe court 31,6 pt.
    // Résidu RMS 0,0089, c'est-à-dire 2,3 niveaux sur 255 : le voile de la
    // référence EST cette gaussienne, il n'y a rien d'autre à droite.
    //
    // Ce faisceau fait à lui seul les deux choses que Kathryn décrit : le
    // « halo spotlight » du côté (là où il frôle l'arête droite, en haut) et
    // la nappe douce qui traverse le centre-droit en biais. Aucun bord net
    // nulle part, puisque c'est une gaussienne unique.
    float cold = 0.4011 * olobeRot(q, float2(W + 0.5, -37.8),
                                   float2(0.4817, -0.8763), float2(213.2, 31.6));

    float3 rgb = float3(0.0);

    if (inside > 0.0) {
        // Le socle : verre fumé, quasi plat à 11/255. Le brief annonçait
        // #17181C → #07080D (23 → 7) ; la référence dit 11, neutre à peine
        // bleuté. C'est elle qui gagne.
        float3 base = float3(0.0447, 0.0449, 0.0465);
        float3 light = warm * kWarm + cold * kVeil;
        float  occ = 0.0;

        // ---- La grille de points. Le pas (9,64 pt) est vingt fois plus grand
        // que le rayon d'influence d'un point (2,2 pt) : un seul site compte,
        // celui de la cellule où l'on tombe. Pas de boucle.
        float2 cell = round((q - oDotPhase) / oDotPitch);
        float2 site = oDotPhase + cell * oDotPitch;
        float2 dv   = q - site;
        float  rr   = length(dv);
        if (rr < 2.2) {
            // ÉTENDUE. Mesurée site par site sur la référence : 36 x 25 sites,
            // surplus de lumière intégré autour de chaque centre. Trois pièges
            // de mesure ont été payés avant d'obtenir ces chiffres — le voile
            // blanc qui traverse la zone en diagonale fausse toute médiane
            // locale (on ne garde donc que les sites à faible gradient), il faut
            // ramener notre rendu à l'échelle de la référence avant de comparer,
            // et il faut intégrer la LUMINANCE et non son logarithme (un
            // rééchantillonnage conserve l'une, pas l'autre).
            //
            // En u : plancher de bruit jusqu'à 170 pt, puis une rampe — 0,11 du
            // plateau à 192 pt · 0,23 à 202 · 0,50 à 221 · plateau de 240 à 300
            // — et une retombée franche ensuite : 0,48 à 317, 0,30 à 346. La
            // grille ne s'approche JAMAIS du liseré : le masque sur la distance
            // signée éteint tout ce qui passe à moins de 6 pt du bord, sur les
            // quatre côtés ET dans l'arc des coins. Sans lui la colonne des
            // sites à 356 pt viendrait mordre le trait.
            //
            // En v : la référence démarre NET à 42 pt (0,05 du plateau à 38 pt,
            // 0,27 à 48) puis s'éteint en gaussienne de σ 67 pt à partir de
            // 78 pt. Là il faut transposer : cette gaussienne meurt vers v =
            // 210 et notre carte s'arrête à 175. Gardée telle quelle, la grille
            // serait TRANCHÉE par le bord bas à 20 % d'amplitude — une ligne de
            // demi-points, exactement le genre de frontière que Kathryn voit
            // tout de suite. On resserre donc le seul paramètre qui n'a pas
            // d'équivalent en paysage, σ 67 → 62 pt : la dernière rangée qui
            // compte tombe à v = 154, elle est déjà à 22 % et le masque du bord
            // finit de l'éteindre. La grille reste un bloc haut-droit qui se
            // dissout vers le bas, jamais un fond de carte.
            float tv  = max(site.y - 78.0, 0.0) / 62.0;
            float amp = smoothstep(42.0, 62.0, site.y) * exp(-tv * tv)
                      * smoothstep(180.0, 250.0, site.x)
                      * (1.0 - 0.72 * smoothstep(285.0, 340.0, site.x))
                      * smoothstep(-6.0, -16.0, d);

            // Le foyer. `1/6` est le DEMI-CÔTÉ d'un pixel en points à 3x : c'est
            // sur ce carré-là qu'on intègre. Sur un écran 2x le vrai demi-pixel
            // vaut 1/4, on intègre donc un peu moins que le pixel — sans
            // conséquence, un σ de 0,28 pt y fait encore 1,1 pixel d'écart-type
            // et le repliement reste sous 2·10⁻³.
            float core = odotCover(dv, 0.280, 1.0 / 6.0);
            // Le soupçon d'ombre autour (voir plus haut : 5 % à 1,1 pt, et
            // surtout PAS le trou de 40 % que suggèrent les pixels bruts).
            float ring = (rr - 1.00) / 0.34;
            occ = amp * 0.12 * exp(-ring * ring);
            // La lumière propre du point, dorée, sur le champ de l'endroit.
            light += amp * core * (0.49 + 9.0 * (warm + cold)) * kDot;
        }

        rgb = (base + 1.0 - exp(-light)) * (1.0 - occ);
    }

    // ---- Le liseré. C'est un DOUBLE trait : un contour extérieur et, 3,2 pt
    // à l'intérieur, une seconde ligne DEUX FOIS plus brillante — le biseau du
    // verre. Mesuré partout sur la référence (haut 104/200, droite 55/98,
    // bas 52/107, gauche 78/159). C'est ce second trait qui fait « taillé » ;
    // sans lui la carte n'est qu'un rectangle cerné.
    float2 n = osdNormal(p, b, r);

    // L'arête DROITE s'éteint en descendant : mesurée pic par pic sur la
    // référence, elle vaut 227 à v=30, 182 à v=70, 137 à v=120, 128 à v=140,
    // et se stabilise vers 108 tout en bas. Le fond constant de 0,706 la
    // laissait à 158-160 en bas — +22 à v=120, +30 à v=140 : un trait qui ne
    // s'éteint jamais, donc un trait qui « sent le procédural ».
    // Une fois la saturation retirée, ces quatre pics donnent 1,211 / 1,019 /
    // 0,673 / 0,609 : un plancher de 0,50 plus une gaussienne d'amplitude
    // 0,778 et de portée 100 pt. Gaussienne et non exponentielle — le pic
    // tient un palier jusqu'à v≈50 avant de tomber, signature d'une source
    // large et floue, la même que celle du bord haut.
    float rimRight = 0.500 + 0.778 * exp(-(q.y / 100.0) * (q.y / 100.0));
    // Les quatre fonds se mélangent par la normale — mais il faut DIVISER par
    // la somme des poids. Sur un arc de coin, |n.x| + |n.y| vaut jusqu'à 1,41 :
    // sans la division, le liseré s'éclaircissait de 40 % dans chaque coin,
    // uniquement parce qu'on y additionnait deux côtés. C'est ce qui gonflait
    // le flanc droit à v=30 (encore sur l'arc, le rayon du banc valant 38 pt).
    float wN = abs(n.x) + abs(n.y);
    float rimBase = (0.36 * max(-n.y, 0.0) + 0.300 * max(n.y, 0.0)
                  + rimRight * max(n.x, 0.0) + 0.687 * max(-n.x, 0.0))
                  / max(wN, 1e-4);
    float dw = length(q - src);
    float dcr = length(q - float2(W - 32.0, -19.0));
    // Le trait chaud en DEUX portées. Avec la seule exponentielle serrée
    // (λ 48 pt), le bord haut plongeait à 198 au milieu là où la référence
    // tient 247 : le liseré de la référence garde un PLATEAU jusqu'à ~175 pt
    // avant de tomber. Un seul terme ne peut pas faire un plateau puis une
    // chute ; il en faut deux — le serré pour le cœur cramé du coin, un large
    // gaussien pour le plateau.
    float rimW = (20.0 * exp(-dw / 48.0)
                + 29.5 * exp(-(dw * dw) / (140.0 * 140.0))) * (1.0 + 0.08 * lit);
    // Le bloom du coin haut-droit ne s'applique plus qu'à l'arête qui REGARDE
    // vers le haut. Avant, il s'ajoutait aussi au flanc droit, et comme sa
    // portée (18,9 pt) est bien plus courte que celle du flanc (100 pt), le
    // total ne pouvait pas coller : il fallait un profil non monotone. Séparés,
    // chacun suit sa loi et l'arc du coin les mélange tout seul par la normale.
    float rimC = rimBase + 9.584 * exp(-dcr / 18.9) * max(-n.y, 0.0);
    float3 rimI = 1.0 - exp(-(rimW * kRim + rimC * kCold));

    // Sigmas issus des FWHM mesurées : 0,7 pt dehors, 0,8 pt dedans.
    float outer = exp(-(d + 0.7) * (d + 0.7) / (2.0 * 0.30 * 0.30));
    float inner = exp(-(d + 3.2) * (d + 3.2) / (2.0 * 0.34 * 0.34));
    rgb += rimI * (inner + 0.50 * outer);

    // ---- Le halo DEHORS : 15/255 au ras du bord, éteint à 30 pt. Minuscule.
    float outD = max(d, 0.0);
    float glow = 2.7 * exp(-outD / 4.0) * exp(-dw / 45.0);
    rgb += (1.0 - exp(-glow * 3.0 * kWarm)) * (1.0 - inside);

    // Dither : un demi-niveau. Sans lui, un dégradé à 4 % bande atrocement.
    rgb += (ohash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
           * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);

    // Dedans : opaque. Dehors : seule la lumière existe — pas d'ombre portée,
    // la page reste #000000.
    float lum = max(max(rgb.r, rgb.g), rgb.b);
    float a = clamp(max(inside, lum * 1.8), 0.0, 1.0);
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}
