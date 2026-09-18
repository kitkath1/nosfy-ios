#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ============================================================================
// LE LISERÉ DU GALET — un deuxième trait blanc, À L'INTÉRIEUR du dôme.
//
// Ce n'est pas le bord : le bord reste ce qu'il est. C'est un liseré posé
// sur la nacre, parallèle au bord, décalé de Δ vers le dedans, qui court
// sur tout l'arc visible — le sommet ET les deux flancs bas.
//
// QUATRE LOIS, et chacune interdit la solution SwiftUI évidente :
//
// 1. PARALLÈLE, PAS PLUS PETIT. Le réflexe serait une ellipse mise à
//    l'échelle. C'est faux : avec un écrasement de 1,08, l'écart entre les
//    deux courbes s'ouvre de 8 % en descendant vers les flancs — à Δ = 14
//    ça fait 0,79 pt d'erreur au flanc, soit près de trois largeurs de
//    cheveu, et le liseré se décolle du bord PILE dans la zone qu'on
//    regarde. Il faut une iso-distance vraie, donc la distance signée à
//    l'ellipse, calculée par pixel :
//        q = ((x−cx)/D)² + ((y−cy)/b)² − 1
//        d ≈ q / ‖∇q‖          (pt, signée, erreur < 0,5 % pour |d| < 40)
//    L'approximation du premier ordre suffit largement ici — on ne s'en
//    sert qu'à quelques points de la courbe. (Et elle évite la sdEllipse
//    exacte d'IQ, dont la version « verbatim » a déjà coûté cher.)
//    Mesuré : parallèle à ±0,13 pt sur tout l'arc.
//
// 2. UNE CLOCHE, PAS UN TRAIT. Un stroke a des bords francs : c'est de
//    l'encre, et la maison l'a rejeté trois fois. Le liseré est une
//    gaussienne — cœur sous le pixel (σ ≈ 0,60 pt), queues qui meurent
//    dans la nacre sans jamais montrer où elles s'arrêtent. σ = 0,60 est
//    un SEUIL, pas un réglage : c'est là que le cœur atteint le blanc
//    plein (pic L 246,8). À 0,75 le pic est identique — on n'ajoute que
//    de l'épaisseur.
//
// 3. VISER LA COULEUR D'ARRIVÉE, PAS LA COULEUR AJOUTÉE. Un blanc
//    ADDITIF sur la nacre (228,209,179) sature le rouge bien avant le
//    bleu : le trait vire crème puis écrête. Un additif corrigé en bleu
//    marche sur la nacre et rend BLEU dès qu'il touche du sombre. Ici on
//    fait un source-over d'un blanc opaque à couverture k : le pic tend
//    vers le blanc cible quel que soit le fond (mesuré R−B +7).
//
// 4. « RENFORCE-LE » NE VEUT PAS DIRE « MONTE k ». À k = 1 le cœur est
//    DÉJÀ blanc plein : il n'y a plus rien à monter. Ce qui reste, c'est
//    le SOUFFLE — une seconde cloche très large et très faible autour du
//    cœur. C'est ce qui fait la différence entre un trait blanc et une
//    lumière : un trait n'a pas de halo.
//
// Le plafond de Δ est une affaire de verre, et il se calcule SOUS LE
// DOIGT : la calotte grossit avec la chaleur (Rg = D·(0,62 + 0,06·heat))
// et son limbe échantillonne jusqu'à 1,32 Rg, soit 200 pt au-dessus du
// centre à pleine chaleur — 183 seulement au repos. Le liseré est à
// b − Δ = 223,3 − Δ : la marge vraie est donc Δ < 23,3, pas 40.
//
// Conséquence mesurée : à Δ = 14 le liseré vit ENTIÈREMENT hors du verre.
// Posé au-dessus ou glissé dans la couche, il rend le même pixel — au
// repos comme sous le doigt (flood 0,24, f0 = 0,838). La place n'est pas
// un arbitrage : c'est un non-sujet tant que Δ reste sous le plafond.
// ============================================================================

/// Un seul hachage, trois sorties — la place du grain le long du liseré
/// (x), son écart à la courbe (y) et sa phase de scintillement (z).
static inline float3 lisHash3(float n) {
    float3 q = fract(float3(n, n * 1.37, n * 2.71)
                     * float3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.xxy + q.yzz) * q.zyx);
}

[[stitchable]] half4 galetLisere(float2 pos, half4 color,
                                 float2 center,   // cx, cy du dôme (calque)
                                 float2 domeRS,   // D, écrasement
                                 float2 ligne,    // Δ (vers le dedans), σ
                                 float2 souffle,  // σ du halo, amplitude
                                 float2 fondu,    // cos θ plein, cos θ fin
                                 float2 poudre,   // amplitude, temps
                                 float2 ombre,    // profondeur max × voile, τ
                                 float gain)      // k × voile × respiration
{
    const float delta = ligne.x;
    const float sigma = max(ligne.y, 0.05);
    // Les deux témoins de l'A/B sont indépendants : éteindre le liseré ne
    // doit pas éteindre l'ombre, et réciproquement.
    if (gain <= 0.002 && ombre.x <= 0.002) return color;

    const float D = max(domeRS.x, 1.0);
    const float b = D / max(domeRS.y, 0.01);

    const float ex = (pos.x - center.x) / D;
    const float ey = (pos.y - center.y) / b;
    const float q  = ex * ex + ey * ey - 1.0;
    // ‖∇q‖ avec ∇q = 2·(ex/D, ey/b) — la normalisation transforme la
    // fonction implicite en distance métrique près de la courbe.
    const float gl = max(length(float2(2.0 * ex / D, 2.0 * ey / b)), 1e-6);
    const float dist = q / gl;          // pt, négatif dedans
    const float dedans = -dist;         // pt, positif dans la matière

    // u = 0 sur la courbe du liseré.
    const float u = dist + delta;
    const float sHalo = max(souffle.x, 0.2);
    // La fenêtre de travail : la plus large des trois cloches, PLUS la
    // portée de l'ombre du bord (qui rentre loin dans la matière).
    const float port = max(max(5.0 * sigma, 3.2 * sHalo), 3.6);
    const float portOmbre = (ombre.x > 0.002) ? (4.2 + 3.2 * ombre.y) : 0.0;
    if (dist > port || dedans > max(port, portOmbre)) return color;

    // — LE DÉGRADÉ DES DEUX EXTRÉMITÉS. Sans lui le liseré est GUILLOTINÉ
    //   par le bord de l'écran : il s'arrête net, à pleine intensité, et
    //   un trait qui s'arrête net se lit comme un trait tracé. Il doit
    //   mourir DANS la nuit, avant que l'écran ne le coupe. Le fondu
    //   travaille sur cos θ (qui décroît quand on descend vers les
    //   flancs), donc il est parfaitement symétrique gauche/droite sans
    //   qu'on ait à connaître le signe.
    const float rn = max(sqrt(ex * ex + ey * ey), 1e-5);
    const float c  = -ey / rn;                       // cos θ, + vers le haut
    const float bout = smoothstep(fondu.y, fondu.x, c);

    // ================= L'OMBRE DU BORD =================
    // Le plus gros écart à la maquette, mesuré par trois chemins
    // indépendants. À hauteur d'écran égale (y = 120 pt), en partant du
    // bord vers l'intérieur (0, 1, 2, 3, 4, 6, 9, 12, 20, 30 pt) :
    //   maquette : 102  169  150  113  107  132  144  157  172  199
    //   nous     : 103  161  173  186  197  209  212  211  216  213
    // Sa matière PLONGE de 60 L juste derrière son bord et met 25 pt à
    // remonter ; la nôtre monte tout droit et ne redescend jamais. Le
    // trait clair, nous l'avions déjà (169 contre 161 à 1 pt) — ce qui
    // manquait, c'est le noir contre lequel il brille.
    //
    // ATTENTION, CECI EST UNE DÉROGATION ASSUMÉE. La règle de la maison
    // (« sur toute coupe, la dérivée ne change de signe qu'une fois »)
    // est née du rejet de l'« épaule » : un creux étroit coincé entre
    // deux clairs se lit comme un contour DESSINÉ. Ce creux-ci est
    // l'inverse d'une rainure : large de 25 pt, il n'a pas de bord, et
    // c'est le modelé d'un dôme éclairé par le haut, pas un trait.
    //
    // Il s'ouvre en θ : presque rien au sommet (la lumière y tombe
    // d'aplomb), pleine profondeur passé 38° sur les flancs. Mesuré chez
    // elle : −20 L au sommet, −90 L à 40°.
    if (ombre.x > 0.002 && dedans > 0.0) {
        // Au SOMMET la maquette n'a pas d'ombre du tout : sur l'axe, elle
        // et nous lisons 205 / 205 / 211 / 220 à 2, 3, 4 et 6 pt sous la
        // crête — identiques. La lumière y tombe d'aplomb, il n'y a pas de
        // limbe à ombrer. Le creux ne s'ouvre qu'en descendant.
        const float flanc = 1.0 - smoothstep(0.788, 0.9962, c);  // 0 au sommet
        const float amp = ombre.x * (0.05 + 0.95 * flanc);
        // La FORME, relevée sur la maquette (profondeur normalisée à
        // y = 120 pt) : 0 à 1 pt, 0,29 à 2, 0,86 à 3, 1,00 à 4, puis
        // 0,81 à 6, 0,70 à 9, 0,56 à 12, 0,45 à 20, 0,14 à 30. Donc une
        // ouverture BRUTALE entre 1,4 et 3,7 pt — elle épargne le premier
        // point, sans quoi le liseré de bord n'aurait plus sur quoi se
        // poser — puis une remontée en exponentielle de τ ≈ 14, et une
        // extinction franche vers 30 pt pour que la matière retrouve
        // vraiment son niveau au lieu de traîner un voile gris.
        // PIÈGE PAYÉ : les profondeurs de la maquette sont relevées depuis
        // le seuil L=100, pas depuis le contour géométrique. Chez nous ces
        // deux repères sont distants de 2,3 pt (notre bloom atteint L=100
        // à 2,3 pt DEHORS), chez elle d'à peine 1 : commander le creux à
        // 3,7 pt le posait mesuré à 6. Il vit donc à 2,5 pt du contour.
        const float creux = smoothstep(0.2, 2.5, dedans)
                            * exp(-max(dedans - 2.5, 0.0) / max(ombre.y, 1.0))
                            * (1.0 - smoothstep(22.0, 36.0, dedans));
        const float f = clamp(1.0 - amp * creux, 0.0, 1.0);
        color = half4(color.rgb * half(f), color.a);
    }

    if (bout < 0.004) return color;
    if (fabs(u) > port) return color;

    // — LE CŒUR : la cloche fine, sous le pixel.
    const float coeur = exp(-0.5 * (u * u) / (sigma * sigma));
    // — LE SOUFFLE : la cloche large et faible qui fait la lumière.
    const float halo = exp(-0.5 * (u * u) / (sHalo * sHalo));

    // La loi angulaire de fond : ±10 % en cos². À intensité parfaitement
    // constante le liseré se lirait comme un trait tracé ; ce souffle-là
    // le rend un peu plus vif au sommet sans jamais le segmenter.
    const float amp = (0.90 + 0.10 * c * c) * bout;

    float k = amp * (coeur + souffle.y * halo);

    // — LA POUDRE DE DIAMANT. Des grains nés SUR le liseré, qui dérivent
    //   le long de lui. Trois règles payées sur la poudre du galet :
    //   (1) la finesse vient de la TAILLE, jamais de l'opacité — un grain
    //       à alpha divisé DISPARAÎT, un grain à σ 0,34 pt reste net et
    //       devient minuscule ;
    //   (2) aucune croix, aucune branche : un pictogramme d'étincelle est
    //       un dessin, pas de la lumière ;
    //   (3) la graine dépend de la CELLULE, jamais du temps — re-tirer par
    //       image donne de la neige de télévision.
    //   L'éclat est en puissance 4 : à un instant donné, un grain sur ~50
    //   est allumé. « Quasi invisible » est une DENSITÉ, pas une opacité.
    if (poudre.x > 0.001 && fabs(u) < 3.0) {
        // Abscisse curviligne le long du liseré (le repère (s, u) est
        // orthogonal au premier ordre : les distances y sont justes).
        const float Reff = 0.5 * (D + b) - delta;
        const float s = atan2(ex, -ey) * Reff;
        const float cell = 5.0;
        const float derive = poudre.y * 5.5;
        const float gcell = floor((s + derive) / cell);
        float a = 0.0;
        for (int i = -1; i <= 1; ++i) {
            const float id = gcell + float(i);
            const float3 hs = lisHash3(id * 1.61803 + 11.0);
            const float cs = (id + 0.5 + (hs.x - 0.5) * 0.9) * cell - derive;
            const float cu = (hs.y - 0.5) * 4.2;
            float tw = 0.5 + 0.5 * sin(poudre.y * 1.7 + hs.z * 6.2831853);
            tw *= tw; tw *= tw;                       // puissance 4
            if (tw < 0.02) continue;
            const float2 dd = float2(s - cs, u - cu);
            a += exp(-0.5 * dot(dd, dd) / (0.34 * 0.34)) * tw;
        }
        k += min(a, 1.0) * poudre.x * bout;
    }

    k = clamp(gain * k, 0.0, 1.0);
    if (k < 0.002) return color;

    // Source-over d'un blanc OPAQUE à couverture k, en prémultiplié : le
    // fond garde sa part (1−k), l'alpha suit la même loi. Rien à écrêter,
    // aucune dérive de teinte, et ça marche à l'identique sur la nacre et
    // sur la nuit.
    const half3 blanc = half3(0.980h, 0.976h, 0.965h);
    const half kk = half(k), inv = half(1.0 - k);
    return half4(blanc * kk + color.rgb * inv, kk + color.a * inv);
}

// ---------------------------------------------------------------------------
// §20 Pil-1 — LE MÉTAL SABLÉ (la réf : l'icône Slack en métal noir pailleté).
// colorEffect : le CORPS seul — obsidienne sablée au grain fin, paillettes
// d'argent rares qui scintillent, biseau rim-light sur l'arc haut. Le néon
// blanc et la date gravée vivent en SwiftUI au-dessus.
// ⚠️ Nyquist (payé sur ObjectiveJewel) : cellules ≥ 2 pt — un grain plus fin
// aliase sans raster 3×.
// Arité : 3 args (float2 centre, float2 Rt, float2 regl) — l'appel Swift
// suit AU FLOAT PRÈS (page blanche sinon).

static float hachePill(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

// v2 (verdict « trop cheap, je veux du relief 3D ») : le VRAI relief — un
// profil de galet bombe-biseaute (plateau + epaule cosinus), les NORMALES
// derivees du profil, une lumiere haut-gauche : diffus + speculaire +
// rim. Le puck existe, il n'est plus peint.
static float hauteurPill(float r, float R, float bev) {
    if (r >= R) { return 0.0; }
    float plat = R - bev;
    if (r <= plat) {
        // le plateau bombe a peine (le dome de la ref)
        return 1.0 - 0.10 * (r / plat) * (r / plat);
    }
    float u = (r - plat) / bev;                 // 0..1 sur l'epaule
    return 0.90 * cos(u * 1.5707963);
}

[[stitchable]] half4 pillMetal(float2 pos, half4 color, float2 centre,
                               float2 Rt, float2 regl) {
    float R = Rt.x, t = Rt.y;
    float grainAmp = regl.x, sparkGain = regl.y;
    float2 d = pos - centre;
    float r = length(d);
    if (r > R + 1.5) { return half4(0.0h); }
    float edge = 1.0 - smoothstep(R - 0.8, R + 0.8, r);
    float bev = R * 0.22;
    // les normales par difference finie du profil (l'echelle z donne le
    // moelleux du relief)
    float zScale = R * 0.55;
    float e = 1.0;
    float hx1 = hauteurPill(length(d + float2(e, 0.0)), R, bev);
    float hx0 = hauteurPill(length(d - float2(e, 0.0)), R, bev);
    float hy1 = hauteurPill(length(d + float2(0.0, e)), R, bev);
    float hy0 = hauteurPill(length(d - float2(0.0, e)), R, bev);
    float3 n = normalize(float3((hx0 - hx1) * zScale * 0.5,
                                (hy0 - hy1) * zScale * 0.5, 1.0));
    float3 L = normalize(float3(-0.42, -0.72, 0.55));
    float diff = max(dot(n, L), 0.0);
    float3 V = float3(0.0, 0.0, 1.0);
    float3 Rf = reflect(-L, n);
    float spec = pow(max(dot(Rf, V), 0.0), 28.0);
    // la matiere : obsidienne sablee (grain 2 pt, la borne Nyquist)
    float g = hachePill(floor(pos / 2.0)) - 0.5;
    float base = 0.085 + g * grainAmp;
    // le sable casse le speculaire (sablage : le highlight est granuleux)
    float specG = spec * (0.75 + 0.5 * g * 4.0);
    float v = base * (0.55 + 1.35 * diff) + specG * 0.34;
    // les paillettes d'argent : fines, elles ne vivent que la ou la
    // lumiere tombe (diff), scintillement lent
    float2 cell = floor(pos / 2.2);
    float h = hachePill(cell);
    float tw = 0.5 + 0.5 * sin(t * 1.6 + h * 43.98);
    v += step(0.976, h) * tw * sparkGain * (0.35 + 0.65 * diff);
    return half4(half3(clamp(v, 0.0, 1.0)), 1.0h) * half(edge);
}

// ============================================================================
// LA GOUTTE DE VERRE (§22) — le galet-étape recalé sur la référence
// « CHAPITRE » : une goutte de verre noir POSÉE sur le noir de la page,
// photographiée plus que dessinée. Ce qui la fait exister sur du noir pur
// (le verre natif y rend un trou) : le liseré spéculaire NET qui court sur
// l'arc haut, la lumière qui POOLE dans l'épaisseur du bas — une ligne
// vive doublée d'une nappe large et douce — et deux glints aux flancs.
//
// La forme n'est pas un cercle : trois harmoniques basses modulent le
// rayon par GRAINE — chaque goutte du chemin est unique, comme des gouttes
// réelles tombées sur une dalle. La normale du contour porte la correction
// tangentielle (dérivée de la forme) : les lumières suivent la goutte,
// jamais le cercle qui l'approxime.
// ============================================================================

[[stitchable]] half4 goutteVerre(float2 pos, half4 color,
                                 float2 centre,   // cx, cy (pt de la vue)
                                 float2 Ra,       // R rayon, aspect (1 = rond)
                                 float2 graine,   // graine d'arcs, chaud (or)
                                 float2 gains,    // gainRim, gainPool (l'état)
                                 float2 vie,      // press 0-1, souffle 0-1
                                 float2 divers,   // refus 0-1, largeur du cheveu en pt (0 = 0,017·rr)
                                 float2 profil,   // plancher de l'anneau, resserré 0/1 (le passé)
                                 float2 finition) { // fumée du dôme, gain
    // ⚠️ ARITÉ : 8 × float2 + rien — l'appel Swift (GaletEtape.goutteShader)
    // DOIT passer exactement ces huit float2 (page BLANCHE sans erreur sinon).
    float gain = finition.y;
    // ================================================================
    // LA PASTILLE-BIJOU (réf 2, « à partir de maintenant ») : un ROND
    // parfait, l'effet BOUTON à DEUX bordures — l'anneau externe vif,
    // l'interstice noir, l'anneau interne discret — et la lumière en
    // ARCS INÉGAUX le long des anneaux (l'école du liseré fin de la
    // flamme : des lobes en cosinus qui meurent en fondu, jamais un
    // anneau égal). Dôme de verre fumé sombre, chiffre au-dessus.
    // La FUMÉE est semi-transparente : la lentille native vit dessous.
    // ================================================================
    float R = Ra.x;
    float s = graine.x;
    float2 q = (pos - centre) / R;
    q.y /= Ra.y;
    float rr = length(q);
    if (rr > 1.30) { return half4(0.0h); }
    float th = atan2(q.y, q.x);
    float aa = 1.0 / R;
    float mask = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, rr);
    float press = vie.x, souffle = vie.y, refus = divers.x;
    float gRim = gains.x * (1.0 + 0.12 * souffle + 0.22 * press + 0.55 * refus);
    float gPool = gains.y * (1.0 + 0.35 * press + 0.30 * refus);

    // LES ARCS — la lampe en haut (léger biais gauche), le contre-arc
    // en bas à droite, et deux étincelles seedées. Fondu en cosinus :
    // un lobe naît, culmine, meurt — le liseré fin de la maison.
    float thLampe = -1.85 + 0.25 * sin(s * 1.7);
    float thContre = 1.25 + 0.30 * sin(s * 2.3 + 1.1);
    // LE PASSÉ, « très fin et pas régulier » (27-08, audit §5 bis, calculé
    // au fouet) : retirer le plancher ne suffit pas — le soft-clip aplatit
    // les lobes larges (cos^3,5 / cos^4) en plateaux, 73 % du périmètre
    // reste allumé. Resserré (`profil.y` = 1) : lampe cos^12, contre-arc
    // cos^14, et les deux étincelles HARMONIQUES (sin 2θ / sin 3θ = perles
    // à 180° / 120°, un motif périodique — l'inverse de « pas régulier »)
    // meurent pour UNE perle à angle seedé. Mesuré : CV ≥ 1,05 sur toutes
    // les graines, 30-38 % du périmètre au-dessus de L 60.
    float serre = clamp(profil.y, 0.0, 1.0);
    float pL = mix(3.5, 12.0, serre);
    float pC = mix(4.0, 14.0, serre);
    float lobeL = pow(max(cos(th - thLampe), 0.0), pL);
    float lobeC = pow(max(cos(th - thContre), 0.0), pC);
    float et1 = pow(0.5 + 0.5 * sin(2.0 * th + s * 5.1), 10.0);
    float et2 = pow(0.5 + 0.5 * sin(3.0 * th + s * 7.7 + 2.1), 12.0);
    float thPerle = s * 3.3 + 0.7;
    float perle = pow(max(cos(th - thPerle), 0.0), 40.0);
    // les étincelles du bijou, ou la perle seule du passé
    float etincelles = mix(0.55 * et1 + 0.40 * et2, 0.45 * perle, serre);

    // LA LARGEUR DU CHEVEU EN POINTS ABSOLUS (27-08, audit §3/§5 bis) :
    // `divers.y` = w en pt (0,55 = le 0,53 pt d'aujourd'hui à Ø 62, figé) —
    // en rr, ×1,5 aurait épaissi tout le chemin. La gaussienne est
    // exp(-(x/w)²) : l'épaisseur VISIBLE vaut ~2,1·w. ⚠️ REPLI OBLIGATOIRE :
    // un appelant qui passe 0 (la mire, l'ancien Swift) garde 0,017·rr —
    // sans repli, w = 0 → division par zéro → anneau MORT partout, sans
    // erreur (l'école de la page blanche).
    float wExt = divers.y > 0.0 ? divers.y / R : 0.017;
    float wInt = divers.y > 0.0 ? (divers.y * 0.82) / R : 0.014;

    // L'ANNEAU EXTERNE — LE PLANCHER EST L'ANNEAU RÉGULIER (la seule
    // composante indépendante de θ) : il vit par état (`profil.x`) —
    // 0,45 le bijou, 0,55 / 0,70 le futur « bordures beaucoup plus
    // claires », 0 le passé (rare contre continu).
    float plancher = max(profil.x, 0.0);
    float profExt = plancher + 0.85 * lobeL + 0.42 * lobeC + etincelles;
    float annExt = exp(-pow((rr - 0.960) / wExt, 2.0)) * profExt
                 * 1.7 * gRim;

    // L'INTERSTICE NOIR (0,87-0,93) : rien — c'est lui, l'effet bouton.

    // L'ANNEAU INTERNE — discret, ses arcs légèrement tournés (organique).
    // Resserré : un seul cheveu — l'interne s'éteint presque (0,25 · lampe).
    float lobeL2 = pow(max(cos(th - thLampe - 0.45), 0.0), mix(3.0, 12.0, serre));
    float lobeC2 = pow(max(cos(th - thContre + 0.35), 0.0), 4.0);
    float profIntBijou = plancher * 0.71 + 0.55 * lobeL2 + 0.30 * lobeC2 + 0.30 * et2;
    float profInt = mix(profIntBijou, 0.25 * lobeL2, serre);
    float annInt = exp(-pow((rr - 0.885) / wInt, 2.0)) * profInt
                 * 1.25 * gRim;

    // LE DÔME — verre fumé sombre : un souffle de ciel en haut, une
    // lueur de fond TRÈS basse dans le bas du verre.
    float up = max(0.0, -q.y / max(rr, 1e-4));
    float dn = max(0.0, q.y / max(rr, 1e-4));
    float dome = 0.026 + 0.030 * exp(-pow((rr - 0.38) / 0.40, 2.0)) * up;
    float fond = exp(-pow((rr - 0.68) / 0.17, 2.0)) * pow(dn, 1.6)
               * 0.18 * gPool;

    // le bloom externe : le souffle du bijou, mort avant le pad
    float dehors = max(0.0, rr - 1.0);
    float glowOut = exp(-pow(dehors / 0.05, 2.0)) * step(1.0, rr)
                  * profExt * 0.10 * gRim;
    if (mask <= 0.0) {
        float g = 1.0 - exp(-glowOut * 1.7);
        return half4(half3(g * gain), 0.0h);
    }

    // LA FUMÉE DU DÔME par état (`finition.x`) : 0,52 le bijou, 0,20 le
    // futur — le disque est CREUX, la vidéo passe au travers (le verre vide
    // de ce qui vient). Repli 0,52 si l'appelant passe 0.
    float fumee = finition.x > 0.0 ? finition.x : 0.52;
    float lignes = annExt + annInt + fond;
    float l = 1.0 - exp(-lignes * 1.7);
    float3 or3 = float3(1.0, 0.84, 0.58);
    // `chaud` (graine.y) < 0,9 : l'or ne vit que dans la nappe basse (le
    // parfait, 0,5). chaud ≥ 0,9 : LES CHEVEUX EUX-MÊMES sont d'or — la lune
    // disponible, le réclamé (27-08 : plus d'anneau d'or SwiftUI par-dessus,
    // « moins de liseré parfait partout »).
    float partFond = lignes > 0.0 ? fond / max(lignes, 1e-4) : 0.0;
    float tOr = graine.y >= 0.9 ? 0.92 : graine.y * partFond;
    float3 teinte = mix(float3(1.0), or3, tOr);
    // l'ombre d'encastrement : le dôme est ENFONCÉ dans la bague —
    // un voile qui n'assombrit que ce qui passe dessous (vidéo), sous
    // l'arc haut interne.
    float up2 = max(0.0, -q.y / max(rr, 1e-4));
    float occ = 0.18 * up2 * exp(-pow((rr - 0.80) / 0.09, 2.0));
    float alpha = min(1.0, fumee + l + occ);
    float3 rgb = teinte * l + float3(dome);
    return half4(half3(rgb * gain), half(alpha)) * half(mask);
}
