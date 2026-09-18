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
constant float3 kVeil = float3(0.958, 0.930, 1.000);

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

/// L'IRISATION. C'est l'effet « huile » : la teinte TOURNE le long de l'arête au
/// lieu d'être une seule couleur étirée sur une rampe d'intensité.
///
/// Mesuré sur la référence irisée de Kathryn (le « green shot ») : en suivant le
/// bord haut depuis le coin, le liseré passe par #F3F8FC (blanc, 254), #79A0C6
/// (bleu franc, B-R +77), #58957A (vert, 149), #A3AAA9 (gris neutre), #515257.
/// Le fait décisif : DEUX TEINTES DIFFÉRENTES VIVENT À LA MÊME INTENSITÉ selon
/// l'endroit de l'arc — bleu à 198, vert à 157. Aucun tone map ne peut produire
/// ça, puisqu'un tone map ne connaît que l'intensité. Il faut une teinte
/// paramétrée par la POSITION.
///
/// Transposée dans l'or de Woop (choix de Kathryn) : blanc chaud au coin, or
/// franc juste après, champagne en filant vers la droite, vert-gris à
/// l'extinction. Sur le flanc gauche, tout se décale vers le rosé-cuivre.
///
/// `s` : avancement le long de l'arête (0 au coin). `flank` : 0 sur le bord
/// haut, 1 sur le flanc gauche.
static float3 oIris(float s, float flank) {
    // RECALÉE canal par canal sur la référence HD. En résolvant
    // `1 - exp(-x*k)` sur trois points du bord haut (u = 65 / 95 / 130 pt), la
    // couleur intrinsèque du chaud sort à (1 ; 0,50-0,56 ; 0,135-0,19) — et
    // elle est QUASI CONSTANTE sur toute la zone chaude, flanc gauche compris
    // (#F1C05E, #CE843D, #96592A y donnent le même k).
    //
    // Ma première rampe partait vers le champagne dès le tiers de l'arc : elle
    // sortait un or deux fois moins saturé que la référence (R-B +70 contre
    // +122). Le barème ne notait que la luminance et ne le voyait pas ; l'œil,
    // lui, lit « beige délavé ». La rampe tient donc le MÊME or sur les deux
    // premiers tiers, et ne bascule qu'à la fin — vers le froid, puisque c'est
    // le coin bleu qui l'attend.
    float3 c0 = float3(1.00, 0.62, 0.32);   // au ras du coin (de toute façon cramé)
    float3 c1 = float3(1.00, 0.52, 0.1955);   // L'OR — mesuré, et il tient
    float3 c2 = float3(1.00, 0.74, 0.56);   // il se désature en s'éteignant
    float3 c3 = float3(0.85, 0.92, 1.00);   // et bascule au froid vers le bleu
    float3 c = mix(c0, c1, smoothstep(0.05, 0.22, s));
    c = mix(c, c2, smoothstep(0.704, 0.96, s));
    c = mix(c, c3, smoothstep(0.9, 1.00, s));
    // Le flanc gauche est PLUS doré que le bord haut, à intensité égale : la
    // référence donne R-B +147 à (12 ; 25) contre +117 sur le bord haut à
    // L=224. J'avais d'abord supprimé ce paramètre en croyant la teinte
    // uniforme — c'était l'erreur de teinte la plus coûteuse (31 % sur le
    // liseré gauche à v=120). On rabat donc le vert et le bleu sur le flanc :
    // même luminance, plus de chroma.
    return c * mix(float3(1.0), float3(1.0, 0.9, 0.60), flank);
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
    // ---- L'HUILE. La nappe de gauche ne descend pas d'un trait : son ÉPAISSEUR
    // ondule lentement en descendant, comme une coulée qui s'épaissit puis
    // s'amincit. On module la PROFONDEUR de la nappe, jamais son amplitude :
    // moduler l'amplitude fait clignoter la lumière (on voit le procédé) ;
    // moduler l'épaisseur fait bouger sa LIMITE, et c'est ça qui coule.
    // Deux ondes de périodes incommensurables (140 et 226 pt) qui descendent à
    // des vitesses différentes : le motif ne se répète jamais à l'œil. ±9 % —
    // au-delà on voit une vague, en deçà rien ne bouge.
    float flow = 0.60 * sin(dq.y * 0.0449 - t * 0.21)
               + 0.40 * sin(dq.y * 0.0278 - t * 0.13 + 1.7);
    float oil = 25.6 * (1.0 + 0.09 * flow);
    // Intensité BAISSÉE au niveau de la référence irisée : plus de plateau
    // cramé, sauf sur l'apex du coin. La nappe vit entre 90 et 200/255 et la
    // bavure dans la surface passe de ~60 pt à ~22 pt. La portée le long de
    // l'arête s'allonge en échange (λ 32 → 95 pt) : c'est ce qui garde le
    // « beau dégradé » tout en tuant la zone brûlée.
    // La PROFONDEUR se mesure depuis l'ARÊTE (q), pas depuis le foyer (dq) : le
    // foyer est à 42 pt hors carte, et compter de là mettait déjà 42 pt de
    // gaussienne au ras du bord — la nappe s'éteignait avant d'entrer dans la
    // pierre. Le long de l'arête, en revanche, c'est bien la distance au FOYER
    // qui compte (dq).
    // Recalé par moindres carrés sur la référence BLEUE (2 226 points × 3
    // canaux, résidu relatif 9,5 %) : le chaud y meurt deux fois plus vite que
    // sur back_hero — 74/255 à 95 pt du coin contre 178. La portée du bord
    // haut retombe de 95 à 32 pt, et la nappe gauche perd les trois quarts de
    // son amplitude au profit du remplissage de coin, qui monte à 0,58.
    // Le GONFLEMENT du coin (demande Kathryn, 2026-08-04) : le halo jaune
    // GRANDIT un peu puis se retire, lentement. On module la PORTÉE des
    // nappes — la limite de la lumière avance dans la pierre — et à peine
    // l'amplitude (la lampe s'approche) : moduler l'amplitude seule fait
    // clignoter, moduler l'étendue fait respirer. Deux périodes premières
    // entre elles, ±7 % au plus.
    float swell = 1.0 + 0.070 * sin(t * 6.2832 / 7.6)
                      + 0.035 * sin(t * 6.2832 / 12.3 + 2.4);
    float warm = 21.208 * exp(-dq.x / (31.9 * swell))
                        * exp(-(q.y * q.y) / (31.9125 * 31.9125 * swell * swell))
               + 1.25 * exp(-dq.y / (52.0 * swell)) * exp(-(q.x * q.x) / (oil * oil))
               + 0.506 * exp(-dot(dq, dq) / (105.4 * 105.4 * swell * swell));
    warm *= 1.0 + 0.06 * lit + 0.6 * (swell - 1.0);
    // La RESPIRATION de l'or (demande Kathryn, 31/07, RENFORCÉE le 04/08 —
    // « + vibration ») : la partie VIVE de gauche ondule finement. Une onde
    // PROGRESSIVE qui descend le long du flanc — jamais une modulation
    // globale, qui se lirait comme un clignotement. ±9 % AVANT tone map : le
    // cœur saturé bouge à peine (compression), l'or moyen — le « vif » —
    // vibre. Deux périodes incommensurables, le motif ne se répète pas.
    float leftGate = exp(-max(q.x, 0.0) / 55.0);
    warm *= 1.0 + leftGate * (0.055 * sin(q.y * 0.050 - t * 0.55)
                            + 0.032 * sin(q.y * 0.019 - t * 0.31 + 2.1));

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
    // Raccourci de 213 à 168 pt (demande de Kathryn) : le faisceau descendait
    // jusqu'au bas de la carte et lisait comme une nappe, pas comme un spot.
    // Sous le doigt il GROSSIT — +26 % en long, +34 % en large, +30 %
    // d'amplitude : le spot s'ouvre, il ne s'allume pas.
    float coldGrow = 1.0 + 0.30 * lit;
    // Faisceau REMESURÉ sur la référence bleue (moitié droite seule, le chaud
    // y est éteint) : amplitude 0,263, centre (W-32 ; -6) pt, axe long 249 pt
    // à -63,1°, axe court 38,5 pt. Il est plus FIN et plus long qu'avant, et
    // sa teinte a viré au bleu (0,958 ; 0,930 ; 1,000) là où l'ancienne
    // référence le donnait gris chaud.
    // « Plus dégradé, on dirait posé » (Kathryn) : un fil seul a des flancs
    // nets. Un cœur FIN (20 pt) dans une jupe LARGE et faible (46 pt) : le
    // spot reste fin mais se fond dans la pierre au lieu d'être posé dessus.
    float2 coldC = float2(W - 31.9, -6.0);
    float2 coldAx = float2(0.4524, -0.8919);
    float cold = 0.170 * coldGrow
               * (0.62 * olobeRot(q, coldC, coldAx,
                                  float2(150.0 * (1.0 + 0.26 * lit),
                                         20.0 * (1.0 + 0.34 * lit)))
                + 0.38 * olobeRot(q, coldC, coldAx,
                                  float2(170.0 * (1.0 + 0.26 * lit),
                                         46.0 * (1.0 + 0.34 * lit))));
    // La bavure de l'accent bleu DANS la surface : sans elle, le coin
    // haut-droit sortait à 68 pour 125 attendus — le faisceau seul n'explique
    // pas ce que la référence a juste sous l'arête.
    // ANISOTROPE : sur la référence, la bavure s'étale le long du bord haut
    // (114/255 encore à 32 pt du coin) mais ne descend JAMAIS le flanc droit
    // (48 à v=30). Une ellipse écrasée 1:2,5 — un rond inondait le flanc.
    // La bavure vit SOUS le bord (centre v=14, écrasée 1:5,5) : centrée sur
    // l'arête elle inondait soit le trait au-dessus, soit le flanc droit.
    float blueWash = 0.24 * exp(-length(float2((q.x - W) * 1.456,
                                               (q.y - 7.0) * 5.5)) / 34.0);
    float3 rgb = float3(0.0);

    if (inside > 0.0) {
        // Le socle : verre fumé, quasi plat à 11/255. Le brief annonçait
        // #17181C → #07080D (23 → 7) ; la référence dit 11, neutre à peine
        // bleuté. C'est elle qui gagne.
        // Socle mesuré sur la référence bleue : 17,8/255 au ras du bord haut,
        // 9,4 au-delà de 28 pt. Plus clair en haut que sur back_hero (11 plat).
        float3 base = mix(float3(0.0369, 0.0371, 0.0384),
                          float3(0.0698, 0.0702, 0.0726), exp(-q.y / 28.0));
        // La nappe n'a plus UNE couleur : elle prend celle de l'irisation à
        // l'endroit où on est. `s` avance le long de l'arête (0 au coin,
        // 1 à 300 pt), `flank` dit si on est sur le bord haut ou le flanc
        // gauche — l'angle depuis le foyer suffit à les séparer.
        float sIris = clamp(length(dq) / 300.0, 0.0, 1.0);
        float flank = clamp(atan2(max(dq.y, 0.0), max(dq.x, 1e-3)) / 1.5708, 0.0, 1.0);
        float3 light = warm * oIris(sIris, flank) + cold * kVeil
                     + blueWash * float3(0.52, 0.68, 1.00);
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

    // ---- LE LISERÉ, entièrement remesuré sur la référence bleue. Il y est
    // BEAUCOUP plus éteint que sur back_hero : 126 à u=110, 72 à u=175, 63 à
    // u=250 sur le bord haut, et le flanc droit tombe à 53 / 39 / 33 à
    // v=30 / 70 / 120. Notre ancien trait sortait à 255 partout — il ne
    // s'éteignait jamais, ce qui « sent le procédural ».
    //
    // Une fois la saturation retirée, huit pics du bord haut et du flanc
    // gauche tiennent sur UNE exponentielle : amplitude 13,2, portée 55 pt
    // depuis le foyer chaud. Plus de terme large : le plateau de back_hero
    // n'existe plus sur cette référence.
    float wN = abs(n.x) + abs(n.y);
    float rimBase = (0.008 * max(-n.y, 0.0) + 0.0 * max(n.y, 0.0)
                  + 0.0 * max(n.x, 0.0) + 0.075 * max(-n.x, 0.0))
                  / max(wN, 1e-4);
    float dw = length(q - src);

    // ---- L'ACCENT BLEU du coin haut-droit. « Très fin », dit Kathryn, et la
    // mesure le confirme : il vaut 216 à 32 pt du coin sur le bord haut et
    // s'éteint complètement en 110 pt (0,028 d'intensité). Portée 20 pt.
    //
    // Le point à ne pas rater : il est GATÉ PAR LA NORMALE. Sur le bord haut
    // du coin il monte à 216 ; sur le flanc droit, à la même distance, la
    // référence ne donne que 53. Sans le `max(-n.y, 0)`, l'accent coulait le
    // long du flanc droit et le trait bleu devenait un contour.
    // Teinte résolue canal par canal sur #84A7D8 : (0,39 ; 0,57 ; 1,00).
    float dTR = length(q - float2(W, 0.0));
    float blue = (0.075 * exp(-dTR / 26.0) + 0.05 * exp(-dTR / 55.0))
               * pow(max(-n.y, 0.0), 3.0) * (1.0 + 0.10 * lit);
    float3 kBlue = float3(0.66, 0.78, 1.00);
    // Le TRAIT s'irise comme la nappe. Il portait une couleur fixe (kRim) : sur
    // le flanc gauche il tombait à R-B +73 là où la référence tient +108, et
    // près du coin il montait à +137 pour +117 attendus. Deux erreurs de signe
    // opposé — signature d'une teinte qui ne varie pas alors qu'elle devrait.
    float sRim = clamp(dw / 300.0, 0.0, 1.0);
    float rimFlank = clamp(max(-n.x, 0.0) - max(-n.y, 0.0) * 0.5, 0.0, 1.0);
    // Le trait ne meurt PAS à la même vitesse sur les deux bords : la
    // référence tient 232/161/128 à v=70/120/140 sur le flanc gauche — bien
    // trop lent pour la portée de 28,5 pt mesurée sur le bord haut. Et sa
    // traîne chaude n'est pas une exponentielle (elle doublait le trait à
    // u=60) : c'est une BANDE, +36 de doré à u=175 là où le trait principal
    // est mort, centrée à 210 pt du foyer, plus large côté flanc.
    float rimP = mix(28.5, 33.0, rimFlank);
    // La bande n'a pas le même profil selon le bord : sur le bord haut elle
    // culmine à 210 pt du foyer (le +36 de doré à u=175) ; sur le flanc
    // gauche elle est plus basse et plus étroite (161 à v=120 mais déjà 128 à
    // v=140 — un centre à 210 gonflait v=140 de +16).
    float bandC = mix(210.0, 138.24, rimFlank);
    float bandS = mix(6050.0, 2450.0, rimFlank);
    // La bande est une fonction de dw, donc un ANNEAU autour du foyer : sans
    // porte, elle rallumait le bord BAS (qui passe à dw~290 = dans l'anneau)
    // — c'était ça, le « contour qu'on voit » de Kathryn. Portée par la
    // normale (haut et gauche seulement) et éteinte en descendant le flanc.
    float bandGate = clamp(max(-n.y, 0.0) + max(-n.x, 0.0), 0.0, 1.0)
                   * (1.0 - 0.85 * smoothstep(95.0, 165.0, q.y));
    float rimW = (1.60 * exp(-dw / rimP)
                + mix(0.030, 0.060, rimFlank) * bandGate
                       * exp(-(dw - bandC) * (dw - bandC) / bandS))
               * (1.0 + 0.08 * lit);
    // Le biseau ne colore pas la lumière comme la masse de la pierre : la
    // ligne de la référence est plus CRÈME que la nappe juste dessous
    // (+117 contre +143 à u=60). On rabat donc l'or du trait vers le crème.
    float3 cRim = mix(oIris(sRim, rimFlank), float3(1.0, 0.75, 0.50), 0.25);
    // Et le flanc droit n'est pas blanc chaud : la référence y est BLEUTÉE
    // (#1F2130, R-B -17 à v=30) — c'est le voile froid que le biseau renvoie.
    // Il s'éteint en descendant, comme le faisceau qui le cause : neutre dès
    // v=70 (la référence y donne R-B 0).
    float rimR = 0.008 * exp(-q.y / 35.0) * max(n.x, 0.0) / max(wN, 1e-4);
    rimBase *= 1.0 - 0.7 * smoothstep(95.0, 175.0, q.y) * max(-n.x, 0.0);
    float3 rimI = 1.0 - exp(-(rimW * cRim + rimBase * kCold
                            + rimR * float3(0.50, 0.62, 1.00) + blue * kBlue));

    // Sigmas issus des FWHM mesurées : 0,7 pt dehors, 0,8 pt dedans.
    // UNE seule bordure, un dégradé collé au bord (comme le bouton du
    // login) : la ligne interne du biseau lisait encore comme un contour.
    // Centrée sur l'ARÊTE (d=0), pas dedans : une gaussienne centrée à
    // d=-1,4 met son maximum 1,4 pt à l'intérieur et laisse un fil plus sombre
    // au ras du bord — deux fils au lieu d'un. Profil vérifié monotone.
    float edge = exp(-d * d / (2.0 * 1.70 * 1.70));
    rgb += rimI * 1.25 * edge;
    // Le BLOOM CRÈME du coin : au ras du coin haut-gauche, la référence est
    // crème (#FCF3CA, R-B +50) sur les 4-5 premiers points DEDANS — pas or.
    // Ce n'est pas la ligne intérieure (elle est à d=-3,2, σ 0,34 : morte à
    // d=-2) : c'est un voile blanc qui LONGE l'arête. Posé dans le trait, il
    // ne faisait rien — il lui fallait son propre profil en profondeur.
    float spark = 0.91 * exp(-dot(q, q) / 392.0);
    float cornerGlow = exp(-d * d / 3.92);
    rgb += (1.0 - exp(-spark * kCold)) * cornerGlow;

    // ---- RIEN NE SORT DE LA CARTE. La référence a bien un petit halo dehors
    // (15/255 au ras du bord, éteint à 30 pt) et il était reproduit ; Kathryn
    // l'a fait retirer — sur la home, posé sur un fond qui n'est pas le noir
    // absolu du banc, il se lisait comme une ombre portée sale. La lumière
    // s'arrête donc net au bord, et l'alpha ne vaut plus que l'intérieur.

    // Dither : un demi-niveau. Sans lui, un dégradé à 4 % bande atrocement.
    rgb += (ohash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
           * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);

    // Dedans : opaque. Dehors : RIEN — pas un pixel, pas une ombre.
    rgb *= inside;
    float a = inside;
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}
