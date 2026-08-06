#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - La pièce de lune
//
// Une pièce d'or quasi-3D : anneau poli, face de laque sombre, et le
// croissant de la maison en néon posé dessus. Elle tourne de GAUCHE À DROITE
// au doigt, et pas ailleurs — un lacet, jamais un tangage libre.
//
// POURQUOI UN FICHIER À PART, ET PAS UN MODE DE `logoMonolith`. Le monolithe
// est l'objet signature de l'app : il fait le splash ET l'écran de connexion,
// il est commité, il est réglé au dixième de point. Y ajouter une branche
// « pièce » pour économiser du code reviendrait à mettre en jeu la première
// image que voit l'utilisatrice pour un gain nul. On lui emprunte ce qui est
// GÉNÉRIQUE — la LUT du croissant, la convention de projection, la softbox —
// et rien d'autre.
//
// CE QUE LA PIÈCE FAIT MIEUX QUE LE PAVÉ. Le monolithe approche sa silhouette
// en lacet par SIX TRANCHES (résidu 0,705 pt à la butée du doigt) parce que
// la silhouette d'un cuboïde tourné n'a pas de forme fermée commode. Un
// cylindre, si : le point de face `pF(z) = A − B·z` est AFFINE en z, donc
// `|pF(z)| − R` est CONVEXE, et son minimum se résout en une ligne —
// `z* = clamp(dot(A,B)/dot(B,B), −h, +h)`. La silhouette est donc EXACTE à
// tous les angles, sans festonnage, et coûte moins cher que trois tranches.

constant float MC_PH = 6.2831853 / 900.0;    // même horloge repliée que l'app

/// La softbox unique de toute la scène, en haut à gauche — la MÊME direction
/// que le monolithe, pour que les deux objets soient éclairés par la même
/// lampe quand ils se croisent dans l'app.
constant float2 MC_KEY = float2(-0.5299, -0.8480);

// MARK: - La pièce

/// `coinR` : rayon de la face, en points.
/// `moonPlace` = (cx, cy, k) et `sdfRanges` = (padding, tight, wide) —
/// source de vérité dans MoonSDF.swift, jamais recopiées ici.
/// `knobs` : les quatre curseurs du banc de fouettage (voir MoonCoinLab).
[[ stitchable ]] half4 moonCoin(float2 position, half4 color,
                                float2 size, float t,
                                float2 tilt, float userYaw,
                                float coinR, float reveal,
                                float idleLife,
                                float3 sdfRanges, float3 moonPlace,
                                float4 knobs,
                                texture2d<half> moonSDF) {
    constexpr sampler kFace(address::clamp_to_edge, filter::linear,
                            coord::normalized);

    const float2 pC = position - size * 0.5;

    // ------------------------------------------------------------------
    // La projection
    // ------------------------------------------------------------------
    // Lacet de repos LÉGÈREMENT positif : une pièce parfaitement de face est
    // un disque, et un disque ne dit pas qu'il a une épaisseur. Trois degrés
    // suffisent à ouvrir la tranche à gauche et à faire lire le solide.
    const float live = 1.0;
    float yaw = 0.052 + userYaw
              + (0.0130 * sin(MC_PH * 11.0 * t + 0.7)
               + 0.0068 * sin(MC_PH * 29.0 * t + 2.9)
               + 0.055 * tilt.x) * live
              + idleLife * (0.058 * sin(MC_PH * 140.0 * t + 0.4)
                          + 0.030 * sin(MC_PH * 93.0 * t + 2.2));
    // Le tangage est BRIDÉ. La consigne est « de gauche à droite, pas plus » :
    // il ne reste qu'un souffle, juste assez pour que la pièce ne soit pas une
    // découpe de papier.
    float pitch = -0.045 + (0.0060 * sin(MC_PH * 17.0 * t + 1.3)
                            + 0.030 * tilt.y) * live
                + idleLife * 0.014 * sin(MC_PH * 77.0 * t + 1.1);

    const float cyw = cos(yaw), syw = sin(yaw);
    const float cpt = cos(pitch), spt = sin(pitch);

    // Les axes de l'objet dans l'espace de la VUE, en 3D — le monolithe n'en
    // garde que la projection 2D, mais l'anneau a besoin de la composante z
    // pour que sa normale tourne vraiment et que le spéculaire coure autour.
    const float3 EX3 = float3(cyw, syw * spt, -syw * cpt);
    const float3 EY3 = float3(0.0, cpt, spt);
    const float3 EZ3 = float3(syw, -cyw * spt, cyw * cpt);
    const float2 Ex = EX3.xy, Ey = EY3.xy, Ez = EZ3.xy;

    // L'inverse du 2×2 [Ex Ey] : écran → coordonnées de face.
    const float invDet = 1.0 / max(Ex.x * Ey.y - Ey.x * Ex.y, 1e-5);
    const float2 iR0 = float2(Ey.y, -Ey.x) * invDet;
    const float2 iR1 = float2(-Ex.y, Ex.x) * invDet;

    // L'épaisseur. Une pièce réelle fait ~8 % de son rayon en demi-épaisseur
    // (24 mm de diamètre pour 2 mm d'épaisseur) — au-delà on dessine un palet.
    const float hD = coinR * 0.088;

    const float2 A = float2(dot(iR0, pC), dot(iR1, pC));
    const float2 B = float2(dot(iR0, Ez), dot(iR1, Ez));

    // LA SILHOUETTE, EN FERMÉ. `|A − B·z| − R` est convexe en z : son minimum
    // sur [−hD, +hD] est le projeté, borné. Aucune tranche, aucun festonnage.
    const float bb = max(dot(B, B), 1e-6);
    const float zs = clamp(dot(A, B) / bb, -hD, hD);
    const float dSil = length(A - B * zs) - coinR;

    // Sortie anticipée : au-delà du halo il n'y a rien. C'est 80 % des pixels.
    // Resserrée avec le bloom : la nappe est morte à 0,155 rayon,
    // inutile de calculer un halo sur 0,92 pour le multiplier par zéro.
    const float reach = coinR * 0.52;
    if (dSil > reach) { return half4(0.0); }

    // La face avant, et ses coordonnées.
    const float2 pF = A - B * hD;
    const float rF = length(pF);
    const float dFace = rF - coinR;

    const float faceMask = smoothstep(0.55, -0.55, dFace);
    const float bodyCov = smoothstep(0.60, -0.60, dSil);
    const float flank = clamp(bodyCov - faceMask, 0.0, 1.0);

    float3 col = float3(0.0);
    float alpha = 0.0;

    // La direction radiale sur la face, et sa version écran.
    const float2 rd = (rF > 1e-4) ? pF / rF : float2(1.0, 0.0);
    const float rN = rF / max(coinR, 1e-3);          // 0 au centre, 1 au bord

    // Les deux lampes. La clé en haut à gauche, et une DOUCINE d'en bas :
    // sur la référence l'anneau porte un arc clair en haut-gauche ET une
    // bande claire en bas — un seul spot ne sait pas produire les deux, et
    // l'anneau tombe alors en demi-lune morte.
    const float3 L1 = normalize(float3(MC_KEY.x, MC_KEY.y, 0.70));
    const float3 L2 = normalize(float3(0.28, 0.86, 0.34));
    const float3 V = float3(0.0, 0.0, 1.0);
    const float3 H1 = normalize(L1 + V);
    const float3 H2 = normalize(L2 + V);

    // L'or. Une pièce est un MÉTAL : pas de diffus, la couleur vient du
    // spéculaire teinté. Un or peint en aplat clair fait du carton doré.
    // MESURÉ (tour 4) : saturation 0,241 contre 0,298 sur la référence — mon
    // or tirait au CHAMPAGNE PÂLE. La faute au blanc : `GOLD_HOT` était à
    // (1,000 / 0,955 / 0,830), donc quasi neutre, et multiplié par 3,3 il
    // lavait la teinte partout où il frappait. Une haute lumière d'or reste
    // DE L'OR : elle monte en luminance sans monter vers le blanc.
    const float3 GOLD = float3(1.000, 0.762, 0.318);
    const float3 GOLD_HOT = float3(1.000, 0.898, 0.606);
    const float3 GOLD_DEEP = float3(0.238, 0.130, 0.026);

    // ------------------------------------------------------------------
    // LE LUSTRE — la matière qui respire
    // ------------------------------------------------------------------
    // PAS un balayage. La première version faisait traverser une barre à
    // 120 % d'intensité en une demi-seconde : voyante dans sa forme, et
    // pourtant MESURÉE à 1,13× la luminance de repos — donc nulle dans son
    // effet. Le pire des deux mondes.
    //
    // On reprend la recette des cartes de l'accueil (`swapCard`,
    // AuroraHome.metal) : une nappe LARGE et FAIBLE — 1,3 à 4,3 % — qui
    // dérive en une trentaine de secondes. Rien ne « passe » : on remarque
    // seulement, au bout d'un moment, que l'objet n'est pas mort.
    const float2 SWEEP = normalize(float2(0.60, -0.80));
    const float sPos = dot(pF / max(coinR, 1e-3), SWEEP);
    // 37,5 s = 900/24 : la période DIVISE l'horloge repliée de l'app, donc
    // aucun hoquet au raccord de boucle.
    const float drift = sin(MC_PH * 24.0 * t);
    const float sheen = exp(-pow((sPos - 0.95 * drift) / 0.62, 2.0));

    // ------------------------------------------------------------------
    // L'ANNEAU — le sujet
    // ------------------------------------------------------------------
    const float rimIn = clamp(knobs.x, 0.50, 0.94);  // bord intérieur, en rN
    if (faceMask > 0.001 && rN > rimIn - 0.06) {
        // La bande, et son profil : un BOURRELET de section demi-ronde. C'est
        // lui qui fait courir le reflet — un anneau plat n'a qu'une normale,
        // donc une seule valeur, donc pas d'arc.
        const float u = clamp((rN - rimIn) / max(1.0 - rimIn, 1e-3), 0.0, 1.0);
        // PLAT SUR LE DESSUS, épaulements aux bords — un LISTEL, pas une
        // demi-ronde. Au tour 3 la section était un demi-cercle pur : une
        // seule bande étroite regardait la lumière, d'où le « cerceau fin »
        // alors que la référence montre une bande MASSIVE claire sur toute
        // sa largeur (mesuré : elle tient 0,592 à r/R 0,95 quand je tombais
        // à 0,382). L'exposant écrase le milieu et raidit les bords.
        const float x = u * 2.0 - 1.0;
        const float s = sign(x) * pow(fabs(x), 1.75);
        const float nz = sqrt(max(1.0 - s * s, 0.0));

        // La normale, montée en 3D dans l'espace de la vue.
        const float3 N = normalize(EX3 * (rd.x * s) + EY3 * (rd.y * s)
                                   + EZ3 * nz);
        const float ndv = clamp(dot(N, V), 0.0, 1.0);
        const float sp1 = pow(clamp(dot(N, H1), 0.0, 1.0), 78.0);
        const float sp2 = pow(clamp(dot(N, H2), 0.0, 1.0), 34.0);
        const float wr1 = pow(clamp(dot(N, H1), 0.0, 1.0), 9.0);

        // Fresnel : sur un métal poli, la tranche du bourrelet s'allume
        // quand elle fuit le regard. C'est ce qui donne le liseré vif tout
        // autour, y compris là où aucune des deux lampes ne frappe.
        const float fres = pow(1.0 - ndv, 3.2);

        // MESURÉ contre la référence (tour 1) : mon or chaud sortait à
        // luma 0,587 quand le sien est à 0,952 — j'avais du BRONZE. Un or
        // poli n'est pas « du jaune moyen » : c'est un miroir teinté, donc
        // presque tout son signal est spéculaire, et ses hautes lumières
        // montent jusqu'au BLANC CHAUD. On triple donc le lobe large et on
        // quadruple le pic, et c'est le creux entre les deux qui redonne la
        // profondeur — pas un aplat sombre.
        // L'ENVIRONNEMENT. Un or poli ne reflète pas une lampe, il reflète
        // une PIÈCE : une nappe claire au-dessus, un retour plus sourd en
        // dessous, du noir sur les côtés. C'est ÇA qui fait courir deux arcs
        // le long de l'anneau — deux points spéculaires ne savent produire
        // que deux taches. Maintenant que le listel est plat, c'est
        // l'environnement qui porte la variation, plus la courbure.
        const float env = 0.30
                        + 0.62 * pow(max(-rd.y, 0.0), 1.4)
                        + 0.28 * pow(max(rd.y, 0.0), 2.4);

        float3 rim = GOLD * (0.255 + 2.05 * wr1 * env)
                   + GOLD * (0.62 * fres)
                   + GOLD_HOT * (2.45 * sp1 + 0.95 * sp2)
                   + GOLD * (0.85 * pow(clamp(dot(N, H2), 0.0, 1.0), 6.0));
        // Le TOURNAGE : un poli de tour laisse des stries circulaires, qui
        // modulent finement le reflet le long de l'anneau. Sans elles la
        // bande est un dégradé lisse — propre, et mort.
        const float lathe = 1.0 + 0.10 * sin(atan2(rd.y, rd.x) * 46.0)
                                * (0.35 + 0.65 * wr1);
        rim *= lathe;
        // Le creux entre les deux lobes : sans lui l'anneau est un tore
        // uniforme et le métal ne se lit pas. Moins profond qu'au tour 1 —
        // c'est lui qui noyait l'or.
        rim = mix(GOLD_DEEP, rim, clamp(0.46 + 0.90 * (wr1 + sp2), 0.0, 1.0));

        const float band = smoothstep(rimIn - 0.012, rimIn + 0.012, rN);
        col = mix(col, rim, band * faceMask);
        alpha = max(alpha, band * faceMask);
    }

    // ------------------------------------------------------------------
    // LA GORGE ET LE LISERÉ — l'anneau de la référence est DOUBLE
    // ------------------------------------------------------------------
    // Lecture de la référence, de l'extérieur vers le centre : tore d'or vif,
    // puis une GORGE sombre, puis un LISERÉ clair, puis la laque. Au tour 2
    // je n'avais qu'un cerceau — d'où le « fil de fer » au lieu du métal
    // massif : c'est la gorge qui donne son épaisseur au listel, parce
    // qu'elle prouve qu'il est EN RELIEF sur la face.
    if (faceMask > 0.001) {
        const float grooveC = rimIn - 0.026;
        const float lipC = rimIn - 0.068;
        // La gorge : un sillon, donc une ombre — pas un trait noir peint.
        const float groove = exp(-pow((rN - grooveC) / 0.014, 2.0));
        col *= 1.0 - 0.82 * groove * faceMask;

        // Le liseré : une arête tournée, très fine et très claire. Elle prend
        // la clé de plein fouet parce qu'elle est presque verticale.
        const float lip = exp(-pow((rN - lipC) / 0.013, 2.0));
        const float lipLam = 0.42 + 0.58 * clamp(dot(rd, -MC_KEY), 0.0, 1.0);
        col += (GOLD * 0.80 + GOLD_HOT * 1.30) * (lip * lipLam * faceMask);
        alpha = max(alpha, lip * 0.9 * faceMask);
    }

    // ------------------------------------------------------------------
    // LA FACE — une laque sombre, pas un trou
    // ------------------------------------------------------------------
    if (faceMask > 0.001 && rN < rimIn + 0.02) {
        // Un dégradé chaud qui remonte vers le centre, plus une inclinaison
        // vers la clé : la référence montre une face NOIRE mais habitée, où
        // l'ambre affleure. Un noir plat ferait un disque découpé.
        // MESURÉ (tour 2) : j'avais la face À L'ENVERS. Centre à 0,152 quand
        // la référence est à 0,028, et pourtour à 0,058 quand elle est à
        // 0,314. Le creux de la lune doit être un TROU NOIR — c'est lui qui
        // fait lire un croissant plutôt qu'un disque lumineux — et c'est le
        // POURTOUR qui se réchauffe, parce que l'or de l'anneau rejaillit
        // sur le vernis juste à côté de lui.
        const float toRim = smoothstep(0.06, rimIn, rN);
        float3 lacquer = mix(float3(0.0055, 0.0038, 0.0026),
                             float3(0.0575, 0.0282, 0.0072),
                             toRim);
        // Le rejaillissement de l'anneau : court, et carré — il ne porte que
        // sur le dernier tiers de la face.
        const float bounce = smoothstep(rimIn - 0.52, rimIn - 0.02, rN);
        lacquer += GOLD * (0.185 * bounce * bounce);
        const float lam = dot(rd, -MC_KEY) * rN;
        lacquer *= 1.0 + 0.52 * lam;

        // Le vernis : une nappe spéculaire large et FAIBLE. La règle du piano
        // black — un lustre large et discret, jamais un point brillant.
        const float2 vk = pF / max(coinR, 1e-3) - MC_KEY * 0.42;
        lacquer += float3(0.34, 0.30, 0.26) * (0.055 * exp(-dot(vk, vk) * 2.6));

        const float inner = smoothstep(rimIn + 0.010, rimIn - 0.014, rN);
        col = mix(col, lacquer, inner * faceMask);
        alpha = max(alpha, inner * faceMask);
    }

    // ------------------------------------------------------------------
    // LA TRANCHE — l'épaisseur, jamais un fossé
    // ------------------------------------------------------------------
    if (flank > 0.001) {
        // Le chant est un cylindre : sa normale est purement radiale. On la
        // prend au point de silhouette, ce qui la rend juste à tous les
        // angles sans cas particulier.
        const float2 pS = A - B * zs;
        const float2 sd = normalize(pS + 1e-5);
        const float3 N = normalize(EX3 * sd.x + EY3 * sd.y);
        const float ndv = clamp(dot(N, V), 0.0, 1.0);
        const float sp = pow(clamp(dot(N, H1), 0.0, 1.0), 46.0);
        const float wr = pow(clamp(dot(N, H1), 0.0, 1.0), 7.0);
        const float fres = pow(1.0 - ndv, 2.4);

        // C'est la LUMINANCE qui lit l'épaisseur, pas la largeur : un chant
        // sombre à côté d'une face sombre creuse un fossé, et la pièce se
        // décolle en deux morceaux.
        float3 edge = GOLD * (0.14 + 0.48 * wr + 0.34 * fres)
                    + GOLD_HOT * (0.85 * sp);
        // Le cannelage : un très fin peigne le long du chant, qui n'apparaît
        // qu'en rasant. Trop marqué il crénellerait — il reste une texture.
        const float ang = atan2(sd.y, sd.x);
        edge *= 1.0 + 0.16 * sin(ang * 78.0) * (1.0 - ndv);

        col = mix(col, edge, flank);
        alpha = max(alpha, flank);
    }

    // ------------------------------------------------------------------
    // L'ARÊTE — le trait clair qui sépare le chant de la face
    // ------------------------------------------------------------------
    {
        const float lip = exp(-pow(dFace / 1.5, 2.0)) * bodyCov;
        col += GOLD_HOT * (0.42 * lip);
        alpha = max(alpha, lip * 0.8);
    }

    // ------------------------------------------------------------------
    // L'APPLICATION DU LUSTRE
    // ------------------------------------------------------------------
    {
        const float onMetal = smoothstep(rimIn - 0.11, rimIn + 0.02, rN);
        const float g = sheen * bodyCov;
        // 5 % sur le métal poli, 0,8 % sur la laque mate. Le vernis ne
        // renvoie pas comme l'or : une nappe d'intensité égale sur les deux
        // aplatirait la pièce en découpe de papier.
        col += (GOLD * 0.052 + GOLD_HOT * 0.030) * (g * onMetal);
        col += GOLD * (0.008 * g * (1.0 - onMetal) * faceMask);
    }

    // ------------------------------------------------------------------
    // LE CROISSANT — la lune de la maison, en néon
    // ------------------------------------------------------------------
    // La LUT est cuite en unités-croissant ; `moonFit` dit quelle part de la
    // face elle occupe. Elle doit tenir DANS l'anneau, gorge comprise.
    const float moonFit = clamp(knobs.y, 0.30, 1.20);
    const float halfFace = coinR * moonFit;
    const float padding = sdfRanges.x, tightR = sdfRanges.y, wideR = sdfRanges.z;
    const float2 uv = (pF / (2.0 * halfFace) + 0.5 - moonPlace.xy)
                      / (padding * moonPlace.z) + 0.5;
    const float2 uvc = clamp(uv, 0.0, 1.0);
    const half4 msdf = moonSDF.sample(kFace, uvc);
    // Hors texture, prolongement analytique : le clamp seul étalerait le
    // canal en croix.
    const float dOutUc = length(uv - uvc) * padding;
    const float ucToPt = moonPlace.z * 2.0 * halfFace;
    float dT = ((float(msdf.r) - 0.5) * 2.0 * tightR + dOutUc) * ucToPt;
    float dW = ((float(msdf.g) - 0.5) * 2.0 * wideR + dOutUc) * ucToPt;
    // Fondu R→G : le canal serré est juste au bord, le large porte le bloom.
    const float dMoon = mix(dT, dW, smoothstep(0.55, 0.95, fabs(dT) / max(tightR * ucToPt, 1e-3)));

    // Le TUBE. Trois couches : le cœur presque blanc, la gaine orange, le
    // halo. Une seule couche fait un trait fluo, pas un néon.
    const float tube = max(coinR * 0.030, 0.85);
    const float aTube = fabs(dMoon);
    const float core = exp(-pow(aTube / (tube * 0.42), 2.0));
    const float shell = exp(-pow(aTube / (tube * 1.15), 2.0));
    // MESURÉ (tour 1) : le halo du tube portait à 3,4 largeurs et NOYAIT le
    // creux du croissant — centre à 0,136 quand la référence est à 0,028.
    // Le creux d'une lune doit être NOIR, c'est ce qui la fait lire comme
    // une lune et pas comme un disque lumineux. On resserre, et c'est le
    // SPILL sur la laque (plus bas) qui reprend le travail d'ambiance —
    // là où la référence est claire, elle, à mi-rayon.
    const float glow = exp(-aTube / (tube * 1.35));

    // La respiration du néon : trois voix incommensurables, jamais un
    // métronome. Même recette que le monolithe.
    // LE SOUFFLE DE LA LUNE. Elle doit « clignoter doucement ». On garde le
    // GONFLEMENT plutôt qu'un vrai battement — un néon qui s'éteint et se
    // rallume lit comme un tube défectueux, ou pire, comme une notification
    // — mais on lui donne enfin une amplitude VISIBLE : ±18 % sur cinq
    // secondes, contre ±5,5 % avant, où le souffle existait sur le papier et
    // pas à l'œil. Les trois périodes (5 s, 17,0 s, 8,9 s) divisent 900 et
    // sont incommensurables entre elles : jamais de métronome.
    const float breath = 1.0 + 0.180 * sin(MC_PH * 180.0 * t + 1.7)
                             + 0.055 * sin(MC_PH * 53.0 * t + 4.2)
                             + 0.030 * sin(MC_PH * 101.0 * t + 0.6);
    // Le point chaud qui VOYAGE le long du tube : c'est lui qui donne
    // l'impression que le gaz circule. Il suit l'angle, donc il tourne avec
    // la pièce.
    const float travel = 0.72 + 0.55 * pow(max(sin(atan2(pF.y, pF.x) * 1.0
                                    - MC_PH * 260.0 * t), 0.0), 3.0);

    const float3 NEON_CORE = float3(1.000, 0.930, 0.780);
    const float3 NEON = float3(1.000, 0.520, 0.105);
    const float lit = reveal * breath;
    float3 neon = NEON_CORE * (core * 1.35 * travel)
                + NEON * (shell * 0.95 + glow * 0.34);
    neon *= lit;

    // Le néon vit SUR la face, jamais sur l'anneau ni hors de la pièce.
    const float onFace = faceMask * smoothstep(rimIn + 0.005, rimIn - 0.035, rN);
    col += neon * onFace;
    alpha = max(alpha, clamp(max(neon.r, max(neon.g, neon.b)), 0.0, 1.0) * onFace);

    // Le SPILL : le néon éclaire la laque autour de lui, et se mire un peu
    // dans l'anneau. Sans lui le croissant est un autocollant sur un disque.
    // MESURÉ (tour 1) : à mi-rayon la référence tient 0,40–0,48 de luminance
    // quand je tombais à 0,05 — sa laque BAIGNE dans la lueur du tube. C'est
    // ce bain qui fait que le croissant est DEDANS la pièce ; sans lui il
    // est posé dessus comme un autocollant.
    const float spill = exp(-max(aTube - tube, 0.0) / (coinR * 0.44));
    // Sans le facteur `(1 − 0,5·rN)` du tour 2, qui ÉTEIGNAIT le bain à
    // mesure qu'on s'éloignait du centre — c'est-à-dire exactement là où la
    // référence est la plus claire.
    col += NEON * (0.185 * spill * lit * faceMask);

    // ------------------------------------------------------------------
    // LE BLOOM — la pièce pose sa lumière sur la nuit
    // ------------------------------------------------------------------
    {
        const float out01 = max(dSil, 0.0);
        // MESURÉ (tour 1) : à r/R = 1,21 ma nappe tenait encore 0,042 quand
        // la référence est à 0,001 — quarante fois trop. Une pièce POSE sa
        // lumière sur la nuit, elle ne l'inonde pas : le halo doit être
        // MORT à un cinquième de rayon du métal, sinon il grise la page et
        // la pièce cesse d'être un objet pour devenir une lampe.
        const float near = exp(-out01 / (coinR * 0.062));
        const float wide = exp(-out01 / (coinR * 0.155));
        const float3 bloom = GOLD * (0.50 * near + 0.036 * wide)
                           + NEON * (0.030 * wide * lit);
        col += bloom * (1.0 - bodyCov);
        alpha = max(alpha, (0.50 * near + 0.042 * wide) * (1.0 - bodyCov));
    }

    if (alpha < 0.0015) { return half4(0.0); }

    // Le fondu d'hôte : la nappe large porte loin, et rien ne doit mourir
    // contre le bord du rectangle — une lumière qui meurt sur son cadre
    // DESSINE son cadre.
    const float2 toEdge = min(position, size - position);
    const float hostFade = smoothstep(0.0, 12.0, min(toEdge.x, toEdge.y));

    // LE PIÈGE DU PRÉMULTIPLIÉ, payé au tour 2. L'alpha était calculé par une
    // formule SÉPARÉE de la couleur ; partout où la couleur dépassait, le
    // `min` final écrêtait le rouge (le plus fort sur de l'or) pendant que le
    // vert et le bleu passaient — le halo doré se DÉSATURAIT en blanc-vert.
    // On ne peint pas par-dessus : l'alpha d'une lumière émissive EST sa
    // propre intensité, donc il doit couvrir sa couleur par construction.
    col = max(col, 0.0);
    alpha = clamp(max(alpha, max(col.r, max(col.g, col.b))), 0.0, 1.0);

    alpha *= hostFade;
    col *= hostFade;
    // Émissif prémultiplié : la lumière porte sa propre couverture.
    return half4(half3(min(col, float3(alpha))), half(alpha)) * color.a;
}

// MARK: - La fumée de la pièce
//
// Deux emplois, deux teintes, UN shader :
//   — sur la page du trésor, fond noir : une fumée SOMBRE, à peine plus
//     claire que la nuit (8 à 25/255). C'est ce que Kathryn a demandé, et
//     c'est ce qui fait « premium » — on devine une matière, on ne voit pas
//     un nuage posé dessus.
//   — dans le header, fond orange clair de l'aurore : une fumée CLAIRE et
//     délicate. La même fumée sombre y ferait une TACHE, pas un souffle :
//     une fumée se lit par contraste avec ce qu'il y a derrière, et le
//     derrière n'est pas le même.
//
// LE TRAMAGE N'EST PAS UNE COQUETTERIE. À 8–25/255, un dégradé lisse tombe
// sur des marches de 1/255 : le nuage se casse en ANNEAUX concentriques
// parfaitement visibles sur un écran OLED. Un bruit décorrélé de ±0,5/255
// suffit à casser la quantification — l'œil intègre, les marches
// disparaissent, et ça coûte un hachage par pixel.

static inline float mcHash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static inline float mcNoise(float2 p) {
    const float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    const float a = mcHash(i), b = mcHash(i + float2(1.0, 0.0));
    const float c = mcHash(i + float2(0.0, 1.0)), d = mcHash(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static inline float mcFbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; ++i) { v += a * mcNoise(p); p *= 2.03; a *= 0.5; }
    return v;
}

/// `ring` = (centre x, centre y, rayon de la pièce).
/// `tint` = la couleur de la fumée, `gain` son intensité maximale.
[[ stitchable ]] half4 coinSmoke(float2 position, half4 color,
                                 float2 size, float t,
                                 float3 ring, float puff, float age,
                                 float3 tint, float gain) {
    if (puff < 0.004) { return half4(0.0); }
    const float2 C = ring.xy;
    const float R = max(ring.z, 4.0);
    const float2 p = position - C;
    const float r = length(p);
    if (r < R - 3.0) { return half4(0.0); }

    // Les volutes SORTENT de la pièce : le champ glisse vers l'extérieur à
    // mesure que la bouffée vieillit, donc la fumée a une origine — elle ne
    // se contente pas d'apparaître autour.
    const float2 n = p / max(r, 1e-3);
    const float2 slide = n * (age * 74.0);
    const float2 sc = (p - slide) * 0.028;
    const float2 drift = float2(t * 0.030, -t * 0.018);
    const float q1 = mcFbm(sc + drift);
    const float w2 = mcFbm(sc * 1.7 - drift * 0.8 + 2.3 * q1);
    float f = mcFbm(sc * 1.31 + float2(2.2 * q1, -1.6 * w2) - drift * 0.6);
    // L'exposant fait les FILAMENTS À TROUS. Sans lui on obtient un disque
    // de brume — un donut, pas de la fumée.
    f = pow(clamp(f, 0.0, 1.0), 2.7);

    const float outR = max(r - R, 0.0);
    const float envel = exp(-outR / (R * (0.24 + 0.62 * puff)));
    float a = puff * envel * f * gain;

    // Le fondu d'hôte : rien ne meurt contre le bord du rectangle.
    const float2 toEdge = min(position, size - position);
    a *= smoothstep(0.0, 14.0, min(toEdge.x, toEdge.y));
    if (a < 0.0012) { return half4(0.0); }

    // Le tramage, décorrélé par pixel ET par image.
    const float dth = (mcHash(position * 1.73 + float2(t * 11.0, t * 7.0)) - 0.5)
                      / 255.0;
    a = clamp(a + dth, 0.0, 1.0);
    const float3 c = clamp(tint + dth, 0.0, 1.0) * a;
    return half4(half3(c), half(a)) * color.a;
}
