#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Le champ de pièces
//
// De VRAIES pièces, dessinées — pas des ellipses peintes. La gerbe était un
// `Canvas` à dégradé CUIT, et c'est exactement le défaut que le coffre du
// header a payé : « une image ne peut pas partager la lumière de la page qui
// la porte ». Un or décidé à l'avance ne sait rien de la scène, d'où le rendu
// crème. Ici chaque pièce est éclairée par LA lampe de la page (MC_KEY, la
// même softbox que la pièce du header) et par LE NÉON de la lune.
//
// LA GÉOMÉTRIE EST EMPRUNTÉE À `moonCoin`, PAS RECOPIÉE. La silhouette d'un
// cylindre en lacet s'y résout en forme FERMÉE : la face se projette en
// ellipse de demi-axe R·|cos ψ|, et l'épaisseur ajoute une translation de
// h·|sin ψ| — le corps est donc l'enveloppe convexe de deux ellipses, c'est-à-
// dire une « capsule elliptique ». Exact à tous les angles, sans festonnage,
// et sans une seule tranche.
//
// MAIS C'EST UN MODÈLE RÉDUIT, ET C'EST VOLONTAIRE. Le piège de Nyquist a
// déjà été payé sur la carte Objectif : un shader réglé à 26 pt et rendu à
// 7 pt CRÉPITE — le spéculaire de l'anneau et le tube de néon deviennent du
// bruit. On garde donc la silhouette, le liseré, UN spéculaire, la tranche,
// et un croissant obtenu par différence de deux disques. Rien de plus.
//
// UNE SEULE PASSE POUR TOUTES LES PIÈCES. Chaque pixel boucle sur le champ
// avec un test d'appartenance qui coupe avant tout calcul : les pièces
// couvrent quelques pour cent de l'écran, donc on paie ~une évaluation réelle
// par pixel couvert, pas N.
//
// Chaque pièce tient en SIX flottants : x, y, R, lacet, allumage, alpha.

constant float2 CF_KEY = float2(-0.5299, -0.8480);   // la softbox de la maison

/// Un croissant, par DIFFÉRENCE DE DEUX DISQUES — deux `length` et rien
/// d'autre. À sept points de rayon, un glyphe vectoriel serait du bruit ;
/// une forme booléenne reste lisible parce qu'elle n'a pas de détail à perdre.
static float crescentSD(float2 p, float r) {
    const float d1 = length(p) - r;
    const float d2 = length(p - float2(r * 0.42, -r * 0.30)) - r * 0.86;
    return max(d1, -d2);
}

[[ stitchable ]] half4 coinField(float2 position, half4 color, float2 size,
                                 device const float *coins, int coinsCount,
                                 float t, float2 neonSrc, float neonAmp) {
    const int N = coinsCount / 6;
    if (N <= 0) { return half4(0.0); }

    float3 acc = float3(0.0);
    float aAcc = 0.0;

    for (int i = 0; i < N; i++) {
        const float cx = coins[i * 6 + 0];
        const float cy = coins[i * 6 + 1];
        const float R  = coins[i * 6 + 2];
        const float yaw = coins[i * 6 + 3];
        const float lit = coins[i * 6 + 4];
        const float aMul = coins[i * 6 + 5];
        if (aMul < 0.004 || R < 0.3) { continue; }

        // ---- LE TEST D'APPARTENANCE, avant tout calcul. C'est lui qui rend
        // la boucle gratuite : la pièce ne porte rien au-delà de son halo.
        const float2 p = position - float2(cx, cy);
        const float reach = R * 2.15;
        if (dot(p, p) > reach * reach) { continue; }

        const float s = sin(yaw), c = cos(yaw);
        const float ax = max(R * fabs(c), R * 0.055);   // demi-axe de la face
        const float h  = R * 0.088;                     // demi-épaisseur
        const float ex = h * fabs(s);                   // ce que la tranche ouvre

        // ---- LE CORPS : capsule elliptique, en forme fermée.
        const float2 q = float2(max(fabs(p.x) - ex, 0.0), p.y);
        const float body = length(float2(q.x / ax, q.y / R)) - 1.0;
        const float aa = 1.6 / R;                       // ~1 px, en unités SDF
        const float cov = smoothstep(aa, -aa, body);
        if (cov < 0.004) {
            // Le halo, seul, hors du métal : une pièce POSE sa lumière.
            const float outD = length(p) - R;
            const float glow = exp(-max(outD, 0.0) / (R * 0.55));
            acc += float3(1.000, 0.762, 0.318) * (glow * 0.085 * aMul);
            aAcc = max(aAcc, glow * 0.10 * aMul);
            continue;
        }

        // ---- LA FACE (proche) et LA TRANCHE. La face est l'ellipse décalée
        // du côté vers lequel la pièce se tourne ; ce qui reste du corps est
        // l'épaisseur, et c'est elle qui fait lire un SOLIDE.
        const float side = (s >= 0.0) ? 1.0 : -1.0;
        const float2 pf = float2(p.x - ex * side, p.y);
        const float face = length(float2(pf.x / ax, pf.y / R)) - 1.0;
        const float onFace = smoothstep(aa, -aa, face);
        const float onEdge = clamp(cov - onFace, 0.0, 1.0);

        // ---- LA LUMIÈRE. Une normale approchée sur l'ellipse, et deux
        // sources : la softbox de la page, et LE NÉON DE LA LUNE — la pièce
        // de la pastille est une petite lampe orange, et le métal qui vole
        // près d'elle DOIT la refléter, sinon la gerbe flotte au-dessus de la
        // scène au lieu d'y appartenir.
        const float2 n = normalize(float2(pf.x / ax, pf.y / R) + 1e-5);
        const float key = max(dot(n, -CF_KEY), 0.0);
        const float2 toNeon = normalize(neonSrc - float2(cx, cy) + 1e-5);
        const float neonFace = max(dot(n, toNeon), 0.0);

        // Le MÉTAL MAT, comme la pièce de la pastille : un anthracite neutre
        // qui garde tous ses reflets (mesuré sur la référence : [42,41,37]).
        const float3 MAT = float3(0.118, 0.112, 0.104);
        const float3 MAT_HOT = float3(0.268, 0.258, 0.242);
        const float3 NEON = float3(1.000, 0.520, 0.105);
        const float3 NEON_CORE = float3(1.000, 0.930, 0.780);

        // LA FACE EST PLATE, ET C'ÉTAIT LE BUG. L'éclairer avec la normale de
        // la SILHOUETTE lui donnait un point chaud radial : une BILLE, pas une
        // pièce. Une face de laque a une normale CONSTANTE — son irradiance ne
        // varie pas. Ce qui la fait lire, c'est un dégradé LINÉAIRE très doux
        // (le brossage sous la softbox) et un fresnel sur son pourtour.
        const float across = dot(float2(pf.x / ax, pf.y / R), -CF_KEY);
        const float sheen = 0.5 + 0.5 * across;
        // Le lambert de la face entière : il ne dépend que du LACET, donc il
        // est le même sur toute la face — c'est ça, une surface plane.
        const float faceLam = 0.45 + 0.55 * fabs(c);
        float3 col = MAT * (0.62 + 0.52 * sheen) * faceLam;
        // Le fresnel du pourtour : une laque s'éclaircit au ras de son bord.
        const float fres = pow(clamp(1.0 + face, 0.0, 1.0), 3.0);
        col += MAT_HOT * (fres * 0.55);
        // LE REFLET DU NÉON sur la laque — resserré, sinon la pièce devient
        // orange au lieu d'être un métal qui REÇOIT une lumière orange.
        col += NEON * (pow(neonFace, 3.2) * 0.42 * neonAmp);
        col += NEON_CORE * (pow(neonFace, 12.0) * 0.26 * neonAmp);

        // LA TRANCHE, elle, a une vraie normale qui tourne : c'est LÀ que vit
        // le spéculaire, et c'est ce fil clair qui fait lire un solide.
        const float2 nE = normalize(float2(p.x, p.y * 0.35) + 1e-5);
        const float keyE = max(dot(nE, -CF_KEY), 0.0);
        const float3 edgeCol = MAT_HOT * (0.55 + 2.2 * pow(keyE, 3.0))
                             + NEON * (0.26 * neonAmp * pow(neonFace, 2.0));
        col = mix(col, edgeCol, onEdge * 0.92);

        // ---- LE CROISSANT, sur la face seulement, et il S'ALLUME OU NON.
        // Une pièce éteinte reste une PIÈCE : on la devine à son métal qui
        // accroche la softbox. On ne fait jamais apparaître une lumière, on
        // monte l'allumage de la même matière.
        if (lit > 0.004) {
            const float2 pc = float2(pf.x / max(fabs(c), 0.10), pf.y);
            const float cs = crescentSD(pc, R * 0.52);
            const float tube = smoothstep(R * 0.13, 0.0, fabs(cs));
            const float bloom = exp(-max(fabs(cs), 0.0) / (R * 0.26));
            const float3 neon = NEON_CORE * (tube * 1.25) + NEON * (bloom * 0.55);
            col += neon * (lit * onFace);
        }

        acc += col * (cov * aMul);
        aAcc = max(aAcc, cov * aMul);
    }

    const float a = clamp(max(max(acc.r, acc.g), acc.b) * 1.25 + aAcc * 0.35,
                          0.0, 1.0);
    return half4(half3(acc), half(a)) * color.a;
}
