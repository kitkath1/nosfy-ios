#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// LE CUIR DU CARNET — la vie posée SUR les plaques forgées (jalon 1 du
// chantier carnet, 19-08). La plaque porte la matière (grain, embossage,
// tranche) ; le shader ne peint rien de neuf : il fait VIVRE ce qui est
// déjà là. Deux étages, tous deux MULTIPLICATIFS (la leçon de
// l'obsidienne : un reflet qui s'ajoute grise le noir ; un reflet qui
// multiplie révèle la matière et laisse le noir souverain) :
//
// 1. LE REFLET TRAVERSANT — une bande diagonale large qui parcourt le
//    cuir en ~31 s (la période du sheen des cartes swap, l'écran parle
//    d'une seule voix). Elle n'existe que par le grain qu'elle allume.
// 2. LA RESPIRATION DE LA TRANCHE — l'or détecté par sa CHALEUR (R−B),
//    jamais par sa position : ±3 % en deux périodes incommensurables
//    (7,3 s et 3,1 s). La règle de l'obsidienne : l'écart image à image
//    reste sous ~1 niveau sur 255 — une animation qu'on VOIT est un
//    effet, pas une matière.
//
// 3. LA LUMIÈRE FIXE AU MONDE — le tilt (doigt au banc, gyroscope en
//    main) tourne le LIVRE, pas la lampe : le reflet glisse à contresens
//    de la rotation, et la tranche d'or s'embrase quand son flanc regarde
//    la source. C'est ça qui sépare un objet d'un PNG (la leçon du
//    coffre-tresor, mort de ne répondre à rien).
//
// Le nom porte V2 exprès (piège de l'arité : le tilt est entré dans la
// signature) : une metallib périmée tombe sur RIEN — page rouge du banc —
// plutôt que sur une vieille signature.
[[ stitchable ]] half4 carnetCuirV2(float2 position, half4 color,
                                    float2 size, float t, float2 tilt) {
    // L'hôte est l'image de la plaque elle-même : color EST le cuir.
    float2 uv = position / max(size, float2(1.0, 1.0));

    float lum = float(max(color.r, max(color.g, color.b)));

    // ---- 1. Le reflet traversant.
    // La bande vit sur l'axe diagonal (x + 0,55 y), la grammaire du sheen
    // des cartes swap ; elle traverse en 31 s, gaussienne large.
    float band = (uv.x + 0.55 * uv.y) / 1.55;
    float sweep = fract(t / 31.0);
    // La course déborde de part et d'autre : la bande entre et sort, elle
    // ne « rebondit » pas dans le cadre. Le tilt la fait GLISSER : la
    // lampe ne bouge pas, c'est le livre qui tourne dessous.
    float centre = mix(-0.35, 1.35, sweep) - tilt.x * 0.30;
    float d = (band - centre) / 0.22;
    float voile = exp(-d * d);
    // Multiplicatif, et gaté par la luminance locale : le reflet n'existe
    // que là où la plaque a de la matière à montrer. Le plafond (0,30)
    // garde le cuir cuir — un cuir qui flashe est un vinyle. Sous le
    // tilt, la face inclinée vers la lumière en attrape un peu plus.
    float grain = smoothstep(0.015, 0.10, lum);
    float reflet = 1.0 + voile * (0.30 + 0.10 * max(tilt.x, 0.0)) * grain;

    // ---- 2. La respiration de la tranche.
    // L'or se reconnaît à sa chaleur : R franchement au-dessus de B, et
    // assez de lumière pour être une tranche, pas un voile.
    float chaleur = float(color.r) - float(color.b);
    float or_ = smoothstep(0.06, 0.30, chaleur) * smoothstep(0.05, 0.25, lum);
    float souffle = 0.03 * sin(t * 2.0 * M_PI_F / 7.3)
                  + 0.014 * sin(t * 2.0 * M_PI_F / 3.1);
    // L'embrasement du flanc : la tranche vit à DROITE du carnet — le
    // tilt positif la présente à la source et elle prend feu doucement ;
    // négatif, elle s'éteint d'un souffle (jamais à zéro : l'or garde sa
    // braise, la loi du néon qui ne clignote pas).
    float embrase = clamp(0.34 * tilt.x, -0.12, 0.34);
    float braise = 1.0 + or_ * (souffle + embrase);

    half3 rgb = color.rgb * half(reflet * braise);
    return half4(rgb, color.a);
}

// LA TOURNE DE PAGE, DEUXIÈME FORME — le moteur du feuilletage. La V1
// (cylindre-tapis-roulant) a été autopsiée et exécutée le 19-08 : la page
// filait HORS du livre (A négatif sans jamais pivoter au dos), le verso
// était le miroir lisible du recto, et l'éclairage multiplicatif sur une
// base noire avait 4 niveaux d'amplitude — invisible par construction.
//
// V2 : LE PLI RECULANT. La page est un segment épinglé à la reliure ; le
// pli recule vers la reliure (A = wp·(1−q)) pendant que la partie libre
// pivote de α = π·q autour de lui. À q=1, le pli est à la reliure, l'angle
// à π : l'atterrissage est le miroir exact (x = −s) — la page ne quitte
// JAMAIS le livre. L'inverse est trivial (x linéaire en s), il n'y a que
// deux nappes (le plat, la levée), et la nappe levée choisit sa face au
// signe de cos α.
//
// Le LAYER porte deux faces : moitié droite = le recto (papier + contenu),
// moitié gauche = le VERSO pré-composé à sa position d'atterrissage — le
// dos d'une feuille n'est jamais le miroir de sa face.
//
// Les ombres sortent en ALPHA (half4(0,0,0,a)) dans les zones désertées :
// c'est la plaque SOUS le layer qui les reçoit — la pénombre précède la
// feuille qui avance.
[[ stitchable ]] half4 tournePageV2(float2 position, SwiftUI::Layer layer,
                                    float2 size, float q) {
    float wp = size.x * 0.5;      // la largeur de page ; la reliure au
    float x0 = wp;                // centre du layer
    float xr = position.x - x0;
    float y = position.y;
    float qq = clamp(q, 0.0, 1.0);
    float vol = sin(M_PI_F * qq);

    float A = wp * (1.0 - qq);    // le pli, qui recule vers la reliure
    float alpha = M_PI_F * qq;    // l'angle de la partie levée
    float ca = cos(alpha);
    float sa = sin(alpha);

    half4 out = half4(0.0);
    float zTop = -1.0;
    float sGagnant = -1.0;

    // 1. Le plat : le recto encore posé, l'ombre du pli qui se dresse.
    if (xr >= 0.0 && xr <= A) {
        out = layer.sample(float2(x0 + xr, y));
        float portee = max(26.0 * sa, 3.0);
        float ombre = 0.32 * vol * exp(-(A - xr) / portee);
        out.rgb *= half(1.0 - ombre);
        zTop = 0.0; sGagnant = xr;
    }

    // 2. La nappe levée : le segment [A, wp] pivoté de α autour du pli.
    //    Recto tant que la face regarde le lecteur (cos α > 0), verso
    //    ensuite — échantillonné dans la moitié gauche du layer.
    if (fabs(ca) > 0.02) {
        float s = A + (xr - A) / ca;
        if (s >= A - 0.5 && s <= wp) {
            float z = (s - A) * sa;
            if (z >= zTop) {
                float u = (s - A) / max(wp - A, 1.0);
                half4 c;
                float l;
                if (ca > 0.0) {
                    c = layer.sample(float2(x0 + s, y));
                    // La courbure par la LUMIÈRE : la crête prend le jour,
                    // le pied reste au sol — c'est elle qui dit « papier »
                    // (l'amplitude est calibrée pour une base ~35/255 :
                    // la crête peut monter vers 60-90, la loi de
                    // l'obsidienne ne vaut pas pour le papier).
                    l = 0.92 + 0.55 * sa * (0.35 + 0.65 * u)
                      + 0.22 * pow(sa, 3.0) * sin(u * M_PI_F);
                } else {
                    c = layer.sample(float2(x0 - s, y));
                    // Le verso naît dans l'ombre et vient à la lumière en
                    // se posant — avec le MODELÉ de la courbure (payé :
                    // sans le sinus, une bande morte uniforme).
                    l = 0.72 + 0.42 * (1.0 - sa)
                      + 0.18 * sa * sin(u * M_PI_F)
                      + 0.08 * sa * u;
                }
                c.rgb *= half(l);
                out = c; zTop = z; sGagnant = s;
            }
        }
    }

    // 3. La pénombre : devant le bord libre, une ombre en alpha se pose
    //    sur ce qui vit sous le layer.
    if (zTop < 0.0) {
        float xFree = A + (wp - A) * ca;
        float d = (ca >= 0.0) ? (xr - xFree) : (xFree - xr);
        if (d >= 0.0) {
            float a = 0.30 * vol * exp(-d / 7.0);
            out = half4(0.0, 0.0, 0.0, half(a));
        }
    }

    // La tranche du bord libre : un cheveu de braise, jamais un néon.
    if (sGagnant > wp - 1.7 && out.a > half(0.01)) {
        half3 braiseC = half3(1.0, 0.62, 0.25);
        out.rgb = mix(out.rgb, braiseC * max(out.r, half(0.20)),
                      half(0.5));
    }

    return out;
}
