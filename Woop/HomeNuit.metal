#include <metal_stdlib>
using namespace metal;

// MARK: - LE RASANT DE LA CHAMBRE NOIRE (bancs `-homeV2`, `-rasantLab`)
//
// La home v2 n'a qu'UNE source de lumière et elle est HORS CADRE, en haut à
// gauche. Ce shader ne peint que ça : une flaque allongée qui RASE le mur en
// diagonale. Le coin haut-droit doit rester du noir absolu — c'est ce noir
// qui fera exister le liseré de néon de la lune.
//
// Le plan : tools/home-v2/PLAN-HOME-V2.md (§ 2.1). Les cibles mesurées du
// jalon 1 : sommet L ≈ 112 (la v1 monte à 200), plus rien au-delà de x = 300
// ni de y = 330, et ≥ 78 % des pixels sous L = 24.
//
// TROIS PARTIS PRIS, chacun payé ailleurs dans l'app :
//
// 1. SUPPORT COMPACT. Le champ est `pow(1 - d, e)` sur une distance
//    anisotrope, jamais une gaussienne : il vaut EXACTEMENT zéro au-delà de
//    son ellipse. Une gaussienne ne s'éteint jamais tout à fait — elle laisse
//    partout un plancher à L = 3-6 qui, sur OLED, se lit comme un voile gris
//    sur toute la page. C'est le diagnostic chiffré du « plat marron opaque »
//    de la v1 : la teinte était juste, c'est l'absence de VRAI noir qui
//    salissait.
//
// 2. L'ELLIPSE EST TOURNÉE. Une flaque ronde posée dans un coin est une
//    tache ; une ellipse allongée sur son axe (52°) est une lumière qui VIENT
//    de quelque part. Toute la différence entre « un halo » et « une lampe ».
//
// 3. LA SATURATION REMONTE QUAND LA LUMIÈRE TOMBE. Cœur blanc-chaud, queue
//    braise SATURÉE. C'est la loi anti-brun de la maison : un fondu vers un
//    orange désaturé donne du marron sur toute la lisière (payé sur l'aurore
//    de la home, sur le fond de connexion, sur le halo du header d'exercice).

/// Le cœur : un blanc à peine chaud. Ce n'est PAS de l'orange — l'orange est
/// réservé à la queue et au liseré de la lune. Mesuré à (1,00 / 0,94 / 0,86)
/// le cœur rendait rgb(120,113,103) : un GRIS, la chaleur ne se lisait pas.
/// Deux crans de vert et de bleu en moins suffisent — au-delà, le cœur vire
/// à la lampe de chevet et le blanc de la lune n'a plus de rival.
constant float3 NR_CHAUD  = float3(1.00, 0.92, 0.82);
/// La queue : la braise, saturée. Elle ne vit que là où la lumière meurt.
constant float3 NR_BRAISE = float3(1.00, 0.62, 0.24);
/// L'ORANGE DU FLANC. Plus vif que la braise de la queue — c'est de la
/// lumière AJOUTÉE (pas une teinte mélangée), donc sa saturation ne salit
/// rien : elle donne un orange franc là où il y a du niveau pour le porter.
constant float3 NR_ORANGE = float3(1.00, 0.52, 0.16);
/// LE CŒUR BLANC : le filament. Presque neutre — c'est sa NEUTRALITÉ qui le
/// fait lire comme du blanc au milieu d'une lumière chaude. Un cœur teinté
/// serait juste « plus de la même chose ».
constant float3 NR_BLANC  = float3(1.00, 0.985, 0.96);

static float nrhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float nrnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = nrhash21(i);
    float b = nrhash21(i + float2(1.0, 0.0));
    float c = nrhash21(i + float2(0.0, 1.0));
    float d = nrhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

/// Le genou d'un canal : linéaire jusqu'à `k`, puis asymptotique vers 1.
static float nrGenou(float x, float k) {
    if (x <= k) { return x; }
    float r = 1.0 - k;
    return k + r * (1.0 - exp(-(x - k) / r));
}

/// Trois octaves suffisent : on cherche l'air d'une pièce, pas un nuage.
static float nrfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * nrnoise(p);
        p = p * 2.03 + float2(11.7, 5.9);
        a *= 0.5;
    }
    return v;
}

/// `src` = (x, y de la lampe, rayon LE LONG du faisceau, rayon EN TRAVERS),
/// en LARGEURS D'ÉCRAN — un cercle reste rond sur n'importe quel appareil.
/// `mat` = (amplitude, exposant d'extinction, angle de l'axe en degrés,
/// souffle). `fin` = (dose de braise, plancher d'ambiance, dose d'air, —).
/// `sup` = (dose du cœur blanc, sa taille, dose du flanc orangé, sa hauteur).
///
/// ⚠️ Toute signature qui bouge ici DOIT bouger dans l'appel Swift au même
/// commit : un stitchable dont l'arité ne correspond plus rend la page
/// BLANCHE, sans une seule erreur de compilation (piège déjà payé).
[[ stitchable ]] half4 nuitRasant(float2 position, half4 color,
                                  float2 size, float t, float2 tilt,
                                  float4 src, float4 mat, float4 fin,
                                  float4 sup)
{
    float w = max(size.x, 1.0);
    float2 p = position / w;

    // La lampe et sa dérive gyro : ±6 pt au plein débattement. Une lampe
    // parfaitement immobile derrière un écran qui bouge se lit comme un
    // autocollant.
    float2 lampe = src.xy + tilt * 0.015;
    float rx = max(src.z, 1e-3);
    float ry = max(src.w, 1e-3);
    float amp = mat.x;
    float expo = max(mat.y, 0.2);
    float ang = mat.z * (M_PI_F / 180.0);
    float souffle = mat.w;

    // L'axe du rasant : la lumière coule du coin vers le bas-droit. On mesure
    // la distance DANS ce repère — allongée le long du faisceau, serrée en
    // travers.
    float2 e1 = float2(cos(ang), sin(ang));
    float2 e2 = float2(-sin(ang), cos(ang));
    float2 r = p - lampe;
    float2 q = float2(dot(r, e1) / rx, dot(r, e2) / ry);
    float d = length(q);

    float v = pow(saturate(1.0 - d), expo);

    // L'air de la pièce : une modulation très basse fréquence, très faible,
    // qui dérive lentement. Sans elle la flaque est une figure mathématique ;
    // avec elle, c'est de la lumière qui traverse quelque chose. Elle
    // MULTIPLIE le champ (elle ne s'y ajoute pas) : hors de l'ellipse, zéro
    // reste zéro.
    float air = nrfbm(p * 2.3 + float2(t * 0.006, -t * 0.004));
    v = saturate(v * (1.0 + fin.z * (air - 0.5) * 2.0));

    // Les deux respirations, sur des périodes premières entre elles : à
    // périodes voisines elles battent ensemble et la page PULSE au lieu de
    // respirer.
    float b1 = 1.0 + souffle * 0.05 * sin(t * 6.28318 / 37.0);
    float b2 = 1.0 + souffle * 0.05 * sin(t * 6.28318 / 23.0 + 1.7);

    // LA LOI DE COULEUR, et elle ne s'écrit PAS en `mix` entre deux teintes.
    //
    // Premier essai, mesuré le 20-08 : `mix(NR_BRAISE, NR_CHAUD, …)` — le
    // chemin droit entre un blanc-chaud et une braise saturée PASSE PAR UN
    // ORANGE DÉSATURÉ, et à L 35-60 la sonde a rendu sat 0,23 quand les
    // tranches voisines tenaient 0,42 et 0,50 : le creux de saturation au
    // milieu de la queue, c'est-à-dire une plaque BRUNE, visible à l'œil sur
    // la capture. Le remède n'est pas de forcer la dose, c'est de changer de
    // chemin : on part du blanc-chaud et on ÉTEINT LE BLEU puis le vert à
    // mesure que la lumière tombe. La teinte glisse blanc → ambre → braise
    // sans jamais traverser un gris chaud, donc la saturation ne fait que
    // MONTER quand L descend. C'est la loi anti-brun de la maison, écrite en
    // canaux plutôt qu'en interpolation.
    // La rampe est LARGE et haute (0,08 → 0,78) : l'ambre ne se réserve plus
    // à la queue, il prend déjà les demi-teintes — c'est la seule façon que
    // l'orange se VOIE, puisque la queue, elle, est trop sombre pour porter
    // une couleur. Réglée à (0,04 → 0,50), la lumière restait blanche partout
    // où elle avait assez de niveau pour être vue.
    float chute = 1.0 - smoothstep(0.08, 0.78, v);   // 0 au cœur, 1 en queue
    float dose = fin.x * chute;
    float3 teinte = NR_CHAUD;
    teinte.b *= mix(1.0, 0.26, dose);
    teinte.g *= mix(1.0, 0.66, dose);

    // LE CŒUR BLANC — le filament. Un lobe serré, en blanc presque neutre :
    // il ne grossit PAS le halo, il en change la couleur au centre. C'est la
    // réponse juste à « plus de blanc » — monter l'amplitude, elle, aurait
    // agrandi la flaque, et c'est le rendu 0,84 écarté au banc.
    //
    // ⚠️ PREMIER ESSAI, MESURÉ : un lobe centré sur la lampe est INVISIBLE.
    // La lampe est hors cadre, donc son cœur aussi — la contribution au pixel
    // le plus clair de l'écran valait +0,001. Tout lobe qui doit se VOIR se
    // place dans le CADRE : celui-ci vit sur l'axe du faisceau, à 0,22 largeur
    // d'écran de la lampe, ce qui le garde solidaire d'elle quand on la
    // déplace au banc.
    float2 coeurC = lampe + e1 * 0.22;
    float dc = length(p - coeurC) / max(sup.y, 1e-3);
    float coeur = pow(saturate(1.0 - dc), 2.6) * sup.x;

    // LE FLANC ORANGÉ — la coulée qui descend le long du bord GAUCHE, la
    // lumière qui bave sur le mur sous la lampe. Elle a son propre lobe
    // (vertical, collé au bord) et sa propre teinte : versée dans le champ
    // principal, elle n'aurait fait que réchauffer tout le halo, et l'orange
    // ne se serait vu nulle part.
    // Étroite et LONGUE (0,32 × 0,62) : une coulée, pas une seconde tache. Un
    // lobe rond a été essayé — il se lisait comme un deuxième foyer, et la
    // page n'a qu'une source.
    float2 fq = float2((p.x + 0.02) / 0.32, (p.y - sup.w) / 0.62);
    float flanc = pow(saturate(1.0 - length(fq)), 1.7) * sup.z;

    float3 c = teinte * (v * amp * b1 * b2)
             + NR_BLANC * (coeur * amp * b1)
             + NR_ORANGE * (flanc * b2);

    // Le plancher d'ambiance : ZÉRO par défaut. Sur OLED le vrai noir est la
    // matière de la page ; le banc peut le lever pour comparer.
    c += fin.y;

    // Le tramage. Un dégradé de cette largeur BANDE sur OLED (bandes de Mach)
    // et aucun flou n'y change rien — on flouterait une image déjà quantifiée.
    // ±0,75/255 : invisible, et le dégradé devient continu.
    c += (nrhash21(position) - 0.5) * (1.5 / 255.0);

    // LE GENOU. Trois foyers qui s'additionnent (le champ, le filament, le
    // flanc) finissent forcément par écrêter quelque part — mesuré : 2 853
    // pixels à 255 dans le rouge, et un écrêtage ne se lit pas comme « très
    // lumineux », il se lit comme une TACHE plate au bord dur. Au-dessus de
    // 0,80, la montée devient exponentielle décroissante : la limite est
    // asymptotique, donc aucun réglage de curseur ne peut plus la franchir.
    c = max(c, 0.0);
    const float genou = 0.80;
    c = float3(nrGenou(c.r, genou), nrGenou(c.g, genou), nrGenou(c.b, genou));

    return half4(half3(c) * color.a, color.a);
}
