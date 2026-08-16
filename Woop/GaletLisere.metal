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
                                 float gain)      // k × voile × respiration
{
    const float delta = ligne.x;
    const float sigma = max(ligne.y, 0.05);
    if (gain <= 0.002) return color;

    const float D = max(domeRS.x, 1.0);
    const float b = D / max(domeRS.y, 0.01);

    const float ex = (pos.x - center.x) / D;
    const float ey = (pos.y - center.y) / b;
    const float q  = ex * ex + ey * ey - 1.0;
    // ‖∇q‖ avec ∇q = 2·(ex/D, ey/b) — la normalisation transforme la
    // fonction implicite en distance métrique près de la courbe.
    const float gl = max(length(float2(2.0 * ex / D, 2.0 * ey / b)), 1e-6);
    const float dist = q / gl;          // pt, négatif dedans

    // u = 0 sur la courbe du liseré.
    const float u = dist + delta;
    const float sHalo = max(souffle.x, 0.2);
    // La fenêtre de travail : la plus large des trois cloches. Au-delà de
    // 3,2 σ le halo vaut 0,6 % — le reste du calque sort ici.
    const float port = max(max(5.0 * sigma, 3.2 * sHalo), 3.6);
    if (fabs(u) > port) return color;

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
    if (bout < 0.004) return color;

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
