#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - La lentille liquide — la pièce d'art
//
// UN SEUL OBJET, du premier pixel au chronomètre : la bulle de verre.
// Le doigt guide tout — l'émergence, la condensation, et jusqu'à la VISION :
// en fin de course, le verre cesse de montrer la page et révèle le monde
// d'après, courbé dans la bille — le velours, les quatre voix qui tournent
// déjà (formules et horloge d'eclipseHalo : à la coupe elles continuent
// leur geste sans le savoir), le cadran qu'on devine. Au relâcher, ce monde
// DÉBORDE de la bille — le noir ne vient jamais du fond : il sort d'elle.
//
// Il n'existe AUCUNE transition dans ce fichier : pas de balayage, pas de
// voile, pas de drain, pas de flash. Des matériaux et de la lumière.

static float lhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float lnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = lhash21(i);
    float b = lhash21(i + float2(1.0, 0.0));
    float c = lhash21(i + float2(0.0, 1.0));
    float d = lhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float lfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * lnoise(p);
        p = p * 2.03 + float2(11.7, 5.9);
        a *= 0.5;
    }
    return v;
}

// Deux octaves : pour les champs DOUX (nuages, grain) — la troisième
// octave y est invisible et le simulateur compte ses fbm.
static float lfbm2(float2 p) {
    float v = 0.5 * lnoise(p);
    v += 0.25 * lnoise(p * 2.03 + float2(11.7, 5.9));
    return v;
}

// Le fbm du VELOURS — clone exact d'`efbm` (EclipseHalo.metal), mêmes
// décalages (17.1, 9.3) : le monde peint ici doit tisser le MÊME drap que
// le cadran, sinon la coupe se voit dans la trame.
static float vfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * lnoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

// MARK: Le monde-éclipse
//
// La scène du cadran, peinte pour un rayon R quelconque — les quatre voix
// d'eclipseHalo (mêmes constantes, même horloge `t`), le disque de velours,
// le liseré. Utilisée par la VISION (courbée dans la bille), par le
// DÉBORDEMENT (à l'échelle réelle), et — c'est le point — IDENTIQUE à ce
// que le cadran affichera après la coupe : les halos ne sentent rien.
static float3 eclipseWorld(float2 d, float r, float R, float t, float ig,
                           float rimK, float occK) {
    // LA PALETTE DE L'ENCRE, jusqu'au bout : le halo EST l'encre qui
    // continue — orange franc, orange doré, jaune, et au plus un blanc
    // CHAUD discret. (La parité de palette avec EclipseCounter est
    // suspendue pour la Transformation — loi de Kathryn, 04-08 soir.)
    // TYPE FEU, PLUS ORANGÉ (Kathryn : « les halos plus orangés » —
    // l'or recule). VERROU : les arcs de reflet de liquidLens (rc[])
    // clonent ces valeurs — les changer ENSEMBLE, toujours.
    //
    // HARMONISATION AVEC LA HOME (22-08). Son verdict : « à la place du
    // orange et trop de doré, plus de rouge et de orange et de blanc et
    // orange léger ». Les quatre voix disent désormais exactement ces
    // quatre mots, dans l'ordre :
    //   #1 ROUGE       — c'était LE doré (0,78/0,40), le coupable désigné
    //   #2 ORANGE      — intacte, elle était déjà juste
    //   #3 BLANC chaud — intacte, c'est le « blanc » demandé
    //   #4 ORANGE LÉGER — un cran de vert en moins, elle dorait encore
    // R reste à 1,00 sur les quatre : on désature le vert, on ne noircit
    // pas le rouge (l'anti-marron de la maison).
    //
    // 2e PASSE, même jour, après « c'est trop orange — ALTERNE du rouge du
    // orange du blanc comme la vidéo flamme ». Les quatre voix ORBITENT
    // autour du disque : c'est leur rotation qui fait l'alternance, encore
    // faut-il qu'elles soient assez ÉCARTÉES pour qu'on les distingue. À
    // 0,36 / 0,54 / 0,92 / 0,56 de G/R, trois d'entre elles étaient le
    // même orange et on ne lisait qu'un aplat. Elles s'écartent sur la
    // rampe mesurée dans `home-fond-flamme.mp4` (racines 0,13 → chaud
    // 0,41), le blanc gardant sa place à part :
    //     #1 rouge profond · #2 orange franc · #3 BLANC · #4 rouge-orange
    // Et LE BLEU TOMBE À ZÉRO (0,12-0,20 → 0,02) : la vidéo tient B/R à
    // 0,01, et c'est ce bleu-là qui délavait le feu en nappe plate.
    // (#3 passe du crème 0,92/0,78 au BLANC franc 0,96/0,90 — « assez
    // violent » : un blanc cassé sur du rouge se lit encore comme du jaune.)
    const float3 cols[4] = { float3(1.00, 0.17, 0.02),
                             float3(1.00, 0.46, 0.03),
                             float3(1.00, 0.96, 0.90),
                             float3(1.00, 0.29, 0.02) };
    const float speed[4] = {  6.2832 / 47.0, -6.2832 / 29.0,
                              6.2832 / 19.0, -6.2832 / 71.0 };
    const float phase[4] = { 0.4, 2.6, 4.4, 5.6 };
    const float rho0[4]  = { 1.02, 0.98, 1.01, 1.14 };
    // LE BLANC MONTE (22-08, « rajoute du blanc assez violent »). La voix
    // blanche était la plus FAIBLE des quatre (poids 0,45, le plus bas) et
    // la plus SERRÉE (srs 0,10, sts 0,34, kappa 22) : sur un lit devenu
    // franchement rouge, elle ne se voyait plus du tout. Elle devient la
    // voix DOMINANTE — poids 0,45 → 1,05 — et elle s'ÉLARGIT assez pour se
    // lire comme un lobe et non comme un fil (srs ×1,7, sts ×1,35, kappa
    // 22 → 11). Les trois autres ne bougent pas d'un cheveu : c'est le
    // contraste avec elles qui fait l'alternance.
    // ⚠️ `srs`/`sts`/`wgt` sont CLONÉS dans les reflets (rsr/rst/rwg) —
    // les trois y changent à l'identique, comme la palette.
    const float srs[4]   = { 0.34, 0.19, 0.23, 0.42 };
    const float sts[4]   = { 0.66, 0.50, 0.58, 0.72 };
    const float bper[4]  = { 13.0, 8.1, 5.2, 21.0 };
    const float bbase[4] = { 0.72, 0.62, 0.50, 0.66 };
    const float bamp[4]  = { 0.28, 0.38, 0.50, 0.30 };
    const float wgt[4]   = { 0.55, 0.85, 1.05, 0.50 };
    const float kap[4]   = { 5.0, 9.0, 11.0, 3.5 };

    float2 n = r > 0.5 ? d / r : float2(0.0, -1.0);
    float insideDisc = 1.0 - smoothstep(R - 1.0, R + 0.5, r);
    // occK : les voix SURVIVENT derrière la pastille — la lentille est
    // DEVANT le halo, c'est son Beer-Lambert qui occulte, jamais un trou
    // peint (la signature « éclipse » mesurée : limbe in/out 0,47).
    float occ = mix(1.0, smoothstep(R - 0.5, R + 1.8, r), occK);
    float angP = atan2(d.y, d.x);

    float3 light = float3(0.0);
    float3 rimGlow = float3(0.0);
    float3 backTint = float3(0.0);
    /// L'énergie de la SEULE voix blanche (#3) — le masque qui servira à
    /// tirer la teinte vers le blanc après le tone-map.
    float blancW = 0.0;
    // LE CANON DE LA NAISSANCE suit la matière : l'orange de l'encre
    // d'abord, l'or, le blanc — la bleutée en DERNIER : le froid n'est
    // qu'un refroidissement d'une lumière déjà là, jamais un allumage.
    const float dly[4] = { 0.30, 0.00, 0.55, 0.12 };
    for (int i = 0; i < 4; i++) {
        float igv = clamp((ig - dly[i]) / (1.0 - dly[i]), 0.0, 1.0);
        igv = igv * igv * (3.0 - 2.0 * igv);
        if (igv < 0.003) { continue; }
        float ang = phase[i] + t * speed[i];
        float2 hd = float2(cos(ang), sin(ang));
        // L'énergie S'ÉTEND depuis le bord du verre vers son orbite :
        // elle émane de l'objet, elle n'apparaît pas sur place.
        float grow = mix(0.97, rho0[i], igv);
        float rho = R * (grow + 0.05 * sin(t * 6.2832 / (bper[i] * 2.7)
                                           + phase[i] * 3.0));
        float dAng = angP - ang;
        dAng -= 6.2832 * floor(dAng / 6.2832 + 0.5);
        float rad = r - rho;
        float arc = dAng * max(rho, 1.0);
        float sr = srs[i] * R;
        float sg = sts[i] * R;
        float q = (rad * rad) / (sr * sr) + (arc * arc) / (sg * sg);
        float breath = bbase[i] + bamp[i] * sin(t * 6.2832 / bper[i]
                                                + phase[i] * 5.0);
        float g = 0.52 * exp(-q) + 0.48 * exp(-q * 0.32);
        float wv = wgt[i] * igv;
        float facing = max(dot(n, hd), 0.0);
        // LA MÊME MATIÈRE : chaque voix naît à la teinte de l'encre
        // (orange → or) et GLISSE vers sa couleur — les chaudes restent
        // orange par nature, le blanc et la bleutée sont l'encre qui
        // refroidit. À ig = 1, les voix exactes du cadran.
        // La porteuse de la NAISSANCE : elle partait de l'encre et glissait
        // vers l'or. Elle glisse maintenant vers l'orange — l'apparition du
        // galet ne passe plus par une étape dorée (verdict 22-08).
        float3 carrier = mix(float3(1.00, 0.24, 0.02),
                             float3(1.00, 0.40, 0.03), igv);
        float3 colv = mix(carrier, cols[i],
                          igv * igv * (3.0 - 2.0 * igv));
        light += colv * (g * breath * wv);
        rimGlow  += colv * (pow(facing, kap[i]) * breath * wv);
        backTint += colv * (pow(facing, 2.5) * breath * wv);
        // LA PART DE LA VOIX BLANCHE, mise de côté. Voir la note du
        // « blanc qui arrive jaune » juste avant le retour : on ne peut pas
        // la lire dans `light` après coup (les quatre voix y sont fondues),
        // il faut la garder pendant qu'on la connaît.
        if (i == 2) { blancW += g * breath * wv; }
    }

    // Le velours du disque (drap vfbm ≡ efbm) + le liseré aux accents —
    // chacun calculé UNIQUEMENT là où il existe : le débordement couvre
    // l'écran entier, deux fbm par pixel pour rien mettaient le simulateur
    // à genoux.
    float3 velvet = float3(0.0);
    if (insideDisc > 0.001) {
        float edge = pow(clamp(r / max(R, 1.0), 0.0, 1.0), 5.0);
        float cloth = 0.80 + 0.40 * vfbm(d * 0.02 + float2(7.0, 3.0));
        velvet = (float3(0.008, 0.008, 0.011) + backTint * 0.05)
                 * (edge * cloth);
    }
    float dr2 = (r - R) * (r - R);
    float ring = exp(-dr2 / 1.35);
    float3 rim = float3(0.0);
    if (ring > 0.004) {
        float acc = vfbm(d * 0.05 + float2(t * 0.11, -t * 0.07));
        acc = acc * acc * acc;
        // rimK : derrière la pastille-lentille, le liseré fin est quasi
        // éteint — une ligne de 1-2 px sous la dispersion du verre devient
        // un arc-en-ciel (l'arc vert mesuré par les quatre juges : le
        // canal vert seul échantillonnait la ligne).
        rim = (float3(0.05) + rimGlow * (0.55 + 2.2 * acc)) * (ring * rimK);
    }

    float3 c = light * occ + rim + velvet * insideDisc;
    float3 outc = 1.0 - exp(-c * 1.55);

    // ========= LE BLANC QUI ARRIVAIT JAUNE (22-08, 3e passe) =========
    // Mesuré sur l'arc haut-droit du cadran : R=220 G=109 B=29, soit
    // G/R 0,50 — un OR, pas un blanc. Il ne paraissait blanc que par
    // contraste simultané avec le rouge autour.
    //
    // LA CAUSE EST LE TONE-MAP, pas la palette. `1-exp(-c·1,55)` sature
    // canal par canal, et sous la voix blanche il y a un lit devenu
    // franchement rouge : **le canal R est déjà proche de son plafond**.
    // Une lumière blanche AJOUTÉE là-dessus fait donc monter G et B sur
    // un R qui ne bouge plus — la teinte glisse vers le jaune avant
    // d'atteindre le blanc, et il faudrait une énergie déraisonnable pour
    // finir la course. Monter le poids de la voix (ce qu'on a fait au
    // tour d'avant) ne fait qu'aggraver : ça allume un or plus fort.
    //
    // LE REMÈDE : on ne l'AJOUTE plus, on TIRE VERS lui. Un `mix` impose
    // la teinte quelle que soit la matière dessous — il est insensible à
    // la saturation du rouge, par construction. La luminance, elle, est
    // conservée (on vise le niveau déjà atteint, jamais un blanc plat) :
    // le lobe garde son modelé, il change seulement de couleur.
    // 2,20 et non 1,30 (« mets plus de blanc ») : le masque atteint son
    // plein ailleurs qu'au seul cœur du lobe, donc le blanc a une SURFACE
    // au lieu d'un point. C'est un réglage sans risque maintenant que la
    // composition est un `mix` — pousser une addition aurait rallumé l'or.
    float mBlanc = clamp(blancW * occ * 2.20, 0.0, 1.0);
    if (mBlanc > 0.003) {
        float niveau = max(max(outc.r, outc.g), outc.b);
        outc = mix(outc, float3(1.00, 0.97, 0.94) * niveau, mBlanc);
    }
    return outc;
}

// MARK: La tache d'encre — L'ENCRE DANS L'EAU
//
// Une TACHE, pas un tube — et une tache qui suit le VRAI tracé : les
// stations vivent en abscisse curviligne (x, y, âge, flânerie), le pixel
// cherche sa distance SIGNÉE au chemin — descentes, crochets, boucles,
// tout est permis au doigt (le paramétrage par la hauteur seule tirait
// des traits droits dès que le geste se repliait). La silhouette est
// tordue par le domaine, la densité vit en lobes, des VRILLES s'étirent
// (des champs continus, jamais des points), la composition suit
// Beer-Lambert. DISCRÈTE : ambres translucides, jamais des bruns. Et
// dedans : les nuages de lait, et les CAUSTIQUES — deux champs ridés qui
// dérivent en sens contraires, leurs croisements s'allument et
// s'éteignent : des filaments de lumière qui scintillent, la lumière qui
// danse dans l'eau. Naissance et dissolution en fondu — aucune alpha
// n'atteint un bord de garde (le verre réfracte et agrandit toute coupe).
[[ stitchable ]] half4 inkTrail(float2 position, half4 color, float2 size,
                                device const float *sta, int staCount,
                                float2 bMin, float2 bMax, float t,
                                float dry, float birth, float scale,
                                float night, float2 pillC) {
    position *= scale;
    int K = staCount / 4;
    // Sur la nuit, dry = 1 n'éteint plus rien : le condensat est un état
    // permanent du cadran, pas une fin.
    if (K < 2 || (night < 0.5 && dry >= 0.999) || birth < 0.004) {
        return half4(0.0);
    }
    // ===== LA TRANSFORMATION (nuit) : rien ne disparaît. La matière se
    // REGROUPE au centre de la bulle — l'image du vol se CONTRACTE vers
    // elle (interrogation radiale amont : conservation exacte) — pendant
    // que son énergie s'étend derrière en HALO (peint par eclipseGlow).
    // Le cadran naîtra de ce condensat.
    float cond = night > 0.5 ? dry : 0.0;
    float pull = 1.0 + 2.2 * cond * cond;
    float2 posGeo = pillC + (position - pillC) * pull;
    if (posGeo.x < bMin.x - 240.0 || posGeo.x > bMax.x + 240.0 ||
        posGeo.y < bMin.y - 240.0 || posGeo.y > bMax.y + 240.0) {
        return half4(0.0);
    }
    // La distance signée au tracé : le segment le plus proche, son u,
    // son âge, sa flânerie, son côté. 23 segments de maths simples —
    // les fbm, eux, n'existent que près du chemin.
    float bestD2 = 1e12;
    float u = 0.0, age = 0.0, linger = 0.0;
    float wSum = 0.0, uSum = 0.0, aSum = 0.0, lSum = 0.0;
    for (int k = 0; k < K - 1; k++) {
        float2 p0 = float2(sta[k * 4],       sta[k * 4 + 1]);
        float2 p1 = float2(sta[(k+1) * 4],   sta[(k+1) * 4 + 1]);
        float2 v = p1 - p0;
        float vv = max(dot(v, v), 1e-4);
        float hseg = clamp(dot(posGeo - p0, v) / vv, 0.0, 1.0);
        float2 dv = posGeo - (p0 + v * hseg);
        float d2 = dot(dv, dv);
        float uk = (float(k) + hseg) / float(K - 1);
        float ak = mix(sta[k * 4 + 2], sta[(k+1) * 4 + 2], hseg);
        float lk = mix(sta[k * 4 + 3], sta[(k+1) * 4 + 3], hseg);
        if (d2 < bestD2) {
            bestD2 = d2;
            u = uk; age = ak; linger = lk;
        }
        // Voronoï DOUX : les attributs se mélangent entre segments
        // proches — aucun pli ne peut plus tracer d'arête.
        float wk = exp(-d2 / (70.0 * 70.0));
        wSum += wk; uSum += wk * uk; aSum += wk * ak; lSum += wk * lk;
    }
    if (wSum > 1e-5) {
        u = uSum / wSum; age = aSum / wSum; linger = lSum / wSum;
    }
    // Distance NON signée : continue partout (le signe sautait sur la
    // frontière de Voronoï des plis concaves → arêtes droites). Les deux
    // bords billowent quand même : les champs sont spatiaux, pas miroirs.
    float sd = sqrt(bestD2);
    if (sd > 230.0) { return half4(0.0); }
    float live = exp(-age * 0.5);
    // LE DOMAINE TORDU : la silhouette billowe — c'est elle qui vit.
    // Deux octaves partout : la tache est floue, la troisième octave est
    // sous son propre flou — le simulateur, lui, la paie plein pot.
    float2 posA = posGeo;
    float2 p = posA * 0.006;
    float warpA = lfbm2(p + float2(0.0, -t * 0.055)) * 1.16;
    float warpB = lfbm2(p * 2.3 + float2(5.2, t * 0.085)) * 1.16;
    // En se condensant, la silhouette se LISSE : le cœur liquide prime.
    float d1 = sd - ((warpA - 0.5) * 110.0 + (warpB - 0.5) * 34.0)
                    * (1.0 - 0.55 * cond);
    // La pointe naît en fondu ; la base s'élargit et se noie (au-delà du
    // départ, la distance devient radiale d'elle-même : le fondu est
    // géométrique, aucun bord).
    // Dans la NUIT, la nappe naît en VOILE : la densité pleine n'arrive
    // que plus haut derrière la pastille — jamais de soupe au contact.
    float tipIn = smoothstep(0.0, mix(0.06, 0.22, night), u);
    float spread = 34.0 * smoothstep(0.85, 1.0, u);
    // LES LOBES : le cœur + deux nappes fantômes, chacun sa largeur.
    float wMain = (26.0 + 15.0 * (1.0 - u) + 17.0 * min(age * 0.5, 1.0))
                  * (0.80 + 0.55 * linger) * (1.0 - 0.18 * night) + spread;
    // LA CONDENSATION conserve la matière : l'image se contracte (pull),
    // la densité monte d'autant — rien ne pâlit, tout se resserre.
    float rarefy = min(pull, 2.6);
    float off1 = (30.0 + 34.0 * (warpB - 0.35)) * (1.0 - 0.6 * cond);
    float off2 = (-36.0 - 30.0 * (warpA - 0.35)) * (1.0 - 0.6 * cond);
    float dens = exp(-(d1 * d1) / (wMain * wMain))
                 * (0.54 + 0.46 * warpA) * (0.85 + 0.45 * linger);
    float wHeart = wMain * 0.42;
    dens += exp(-(d1 * d1) / (wHeart * wHeart))
            * (0.45 + 0.55 * warpB) * (0.55 + 0.65 * linger);
    float w1 = wMain * 0.55;
    float dl1 = d1 - off1;
    dens += exp(-(dl1 * dl1) / (w1 * w1)) * 0.34 * (0.35 + 0.85 * warpB);
    float w2 = wMain * 0.44;
    float dl2 = d1 - off2;
    dens += exp(-(dl2 * dl2) / (w2 * w2)) * 0.27 * (0.35 + 0.85 * warpA);
    // Le grain du pigment mouillé — seulement dans l'encre visible.
    if (dens > 0.05) {
        float fine = lfbm2(posA * 0.030
                           + float2(warpB * 2.1, t * 0.05));
        dens *= 0.72 + 0.55 * fine;
    }
    // LES VRILLES : l'encre fraîche en jette, la vieille se pose.
    float vrilEnv = exp(-(d1 * d1) / (wMain * wMain * 4.0));
    if (vrilEnv > 0.015) {
        float tf = lfbm2(float2(posA.y * 0.013 + warpA * 1.7,
                                posA.x * 0.011 - t * 0.07
                                + warpB * 1.3)) * 1.16;
        dens += pow(smoothstep(0.52, 0.88, tf), 2.0) * vrilEnv
                * (0.35 + 0.65 * live) * 0.55 * (1.0 - cond);
    }
    dens *= mix(1.0, rarefy, night);
    dens *= tipIn * birth;
    // Le grain de poussière du centre : la contraction mappe le voisinage
    // du pixel central pile sur la pointe du chemin — adouci.
    dens *= 1.0 - 0.30 * night
            * (1.0 - smoothstep(0.0, 12.0, length(posGeo - pillC)));
    // La fleur d'eau sous la bille — au point exact du doigt.
    float2 tip = float2(sta[0], sta[1]);
    float2 dtp = position - tip;
    float bloom = exp(-dot(dtp, dtp) / (78.0 * 78.0))
                  * (0.40 + 0.60 * live) * birth
                  * (1.0 - smoothstep(0.10, 0.45, cond));
    if (dens < 0.004 && bloom < 0.004) { return half4(0.0); }
    // DISCRÈTE : des ambres translucides, jamais des bruns — la sienne et
    // l'ombre ne sont plus que des soupçons, la fumée se lit dans la FORME.
    // Sur le papier, le jaune porte et la sienne ombre ; dans la NUIT,
    // c'est le BLANC qui porte la lumière (orange et jaune la réchauffent),
    // et l'ombre n'existe pas — la nuit est déjà l'ombre.
    float3 yellow = float3(1.00, 0.88, 0.45);
    // Anti-brun : sur la nuit, la saturation MONTE quand la lumière
    // baisse — l'ambre boueux venait d'un orange trop lavé.
    float3 orange = mix(float3(1.00, 0.55, 0.20),
                        float3(1.00, 0.58, 0.24), night);
    float3 sienna = float3(0.62, 0.28, 0.10);
    float3 bloomC = mix(float3(1.00, 0.72, 0.32),
                        float3(1.00, 0.84, 0.60), night);
    // Le voile porteur de la nuit est une crème DORÉE : du blanc pur à
    // faible alpha sur du noir lit « fumée grise » — une seconde matière.
    // 22-08 : la crème RESTE (elle est structurelle, sans elle la fumée
    // devient grise), mais elle se chauffe — crème d'orange, plus crème
    // d'or. C'est le « blanc et orange léger » du verdict.
    float3 lowC = mix(yellow, float3(1.00, 0.82, 0.54), night);
    float3 c = mix(lowC, orange, smoothstep(0.10, 0.55, dens));
    c = mix(c, sienna, 0.18 * smoothstep(0.65, 1.70, dens)
                        * (1.0 - night));
    c = mix(c, yellow, (0.22 + 0.16 * night)
                        * smoothstep(0.62, 0.92, warpB)
                        * (1.0 - smoothstep(0.9, 1.6, dens)));
    c = mix(c, sienna, 0.10 * smoothstep(0.70, 0.95, warpA)
                        * smoothstep(0.35, 0.9, dens) * (1.0 - night));
    // LES NUAGES DE BLANC : des poches de lait qui dérivent dans l'encre.
    float cmask = 0.0;
    if (dens > 0.12) {
        float cloud = lfbm2(posA * 0.008
                            + float2(t * 0.050, -t * 0.075)
                            + warpA * 0.9);
        cmask = smoothstep(0.52, 0.82, cloud)
                * smoothstep(0.15, 0.50, dens);
        c = mix(c, float3(1.00, 0.985, 0.955), 0.75 * cmask);
    }
    // LES CAUSTIQUES : deux champs ridés à contre-courant — leurs
    // croisements sont des filaments de lumière qui naissent, glissent et
    // s'éteignent. Du scintillement CONNEXE : jamais des paillettes.
    float glintM = 0.0;
    if (dens > 0.10) {
        float n1 = lnoise(posA * 0.021
                          + float2(t * 0.11, -t * 0.07) + warpA * 0.6);
        float n2 = lnoise(posA * 0.017
                          + float2(-t * 0.09, t * 0.06));
        float r1 = pow(1.0 - fabs(2.0 * n1 - 1.0), 6.0);
        float r2 = pow(1.0 - fabs(2.0 * n2 - 1.0), 6.0);
        // La lumière ne danse que dans l'EAU : les caustiques meurent
        // avec le séchage, et restent un murmure — pas du strass.
        glintM = r1 * r2 * smoothstep(0.12, 0.40, dens)
                 * (1.0 - smoothstep(1.2, 1.9, dens))
                 * (0.30 + 0.70 * live);
        c = mix(c, float3(1.00, 0.96, 0.88), min(1.7 * glintM, 0.85));
    }
    // Sur le papier, DISCRÈTE (−40 %) : une présence qui se devine. Sur
    // la NUIT, l'inverse : l'alpha est la seule lumière — l'encre doit
    // RAYONNER, blanche et chaude, seule source vivante de la descente.
    // En se condensant, l'encre CHAUFFE vers l'or-blanc du cadran —
    // puis SE REMET au verre : le condensat passe le relais à la laque
    // et aux chiffres. Aucune disparition : une passation.
    float fold = 1.0 - dry;
    if (night > 0.5) {
        // L'encre chauffe en se condensant — mais vers un BLANC-ORANGE, non
        // plus vers « l'or-blanc du cadran ». C'était l'or le plus visible
        // de toute l'apparition : le dernier instant avant que le galet ne
        // se forme, celui qu'on regarde.
        c = mix(c, float3(1.00, 0.80, 0.50),
                0.6 * smoothstep(0.35, 0.90, cond));
        // La passation est LONGUE, et elle ne finit JAMAIS à zéro : le
        // condensat RESTE — un cœur d'encre calme marbre l'intérieur du
        // cadran à demeure (« le cadran est ce condensat »). La matière
        // de la pill de base ne quitte plus le verre.
        fold = 0.40 + 0.60 * (1.0 - smoothstep(0.70, 1.0, cond));
    }
    float aInk = (1.0 - exp(-dens * mix(0.72, 0.95, night)))
                 * (0.28 + 0.30 * live) * (1.0 + 0.42 * night)
                 * (1.0 + 0.18 * cmask + 0.55 * glintM);
    float aBloom = bloom * mix(0.13, 0.02, night);
    float total = aInk + aBloom;
    if (total < 0.0008) { return half4(0.0); }
    float3 cTot = (c * aInk + bloomC * aBloom) / total;
    // LA BRAISE : sur la nuit, l'encre a le droit d'être incandescente —
    // le plafond montait à peine à 0,46 : une brique poudreuse, pas du
    // métal en fusion (pic mesuré 138/255 par le panel).
    float a = min(total * fold, mix(0.40, 0.58, night));
    return half4(half3(cTot * a), half(a)) * color.a;
}

// MARK: Le halo de la transformation
//
// L'ÉNERGIE de l'encre diffusée : les quatre voix du cadran (formules
// exactes d'eclipseWorld) s'allument DERRIÈRE la pastille à mesure que
// la matière se condense — et le verre, devant, les réfracte : le halo
// se reflète dans la matière Liquid Glass sans un seul trucage.
// LE LIT DE FEU, en coordonnées MONDE — une seule fonction pour les deux
// entrées (le cadran posé, et la caméra du travelling qui le rase). Le
// VERROU tient : il n'existe qu'un seul feu, une seule palette.
static float3 glowShade(float2 d, float r, float R, float t, float ig,
                        float pulse, float flare, float flareAng) {
    // occK 0,55 : un lobe d'or doit se voir CONTINUER à travers le limbe
    // — l'indice de transparence le plus fort. rimK 0,05 : le liseré
    // peint du monde se calme derrière l'objet.
    float3 c = eclipseWorld(d, r, R, t, ig, 0.02, 0.55);
    // LA NAPPE : l'énergie diffuse de l'encre, étalée DERRIÈRE tout le
    // disque — le monde que le verre réfracte. Sans elle, la lentille
    // transmet du noir sur du noir et l'intérieur lit « peint ». Elle
    // respire lentement entre l'orange et l'or : l'encre, toujours.
    float napp = exp(-(r * r) / (1.55 * R * 1.55 * R));
    // LA NAPPE OCCULTÉE : l'arrière du cœur s'assombrit de 70 % — la
    // nuit derrière le disque reste nuit (le Beer-Lambert n'a plus à
    // lutter contre une inondation) ; le monde au large, celui que le
    // limbe-miroir échantillonne, reste intact.
    napp *= mix(0.30, 1.0, smoothstep(0.72 * R, 1.06 * R, r));
    if (napp > 0.004) {
        // (LA TEINTE DE LA NAPPE EST DESCENDUE PLUS BAS — elle se construit
        // désormais APRÈS le champ de flamme, parce qu'elle en DÉPEND. Voir
        // « LA RAMPE DE LA VIDÉO » quelques lignes plus loin.)
        // LA BRAME DE FLAMME : le lit VIT — des langues qui montent et
        // lèchent autour du verre. Le champ s'ADVECTE vers le large le
        // long de chaque rayon (aucune couture angulaire, aucune
        // particule, jamais un strobe : une respiration de feu).
        // LA BRAME EN FLOW-MAP : deux couches advectées en alternance,
        // fondues en triangle — l'offset reste BORNÉ. (Advecter sans
        // borne le long de fdir déchiquetait le champ en rais fins :
        // deux pixels voisins divergeaient de TOUT l'offset accumulé.)
        // Langues étirées le long du rayon (anisotropie 0,55).
        float2 fdir = d / max(r, 1.0);
        float Tf = 2.6;
        float ph0 = fract(t / Tf);
        float ph1 = fract(t / Tf + 0.5);
        float2 off = fdir * (R * 0.22 * Tf);
        float2 q0 = d - off * ph0;
        float2 q1 = d - off * ph1;
        float qr0 = dot(q0, fdir);
        float qr1 = dot(q1, fdir);
        q0 = (q0 - fdir * qr0) + fdir * (qr0 * 0.55);
        q1 = (q1 - fdir * qr1) + fdir * (qr1 * 0.55);
        float w0 = 1.0 - fabs(2.0 * ph0 - 1.0);
        float fl = mix(vfbm(q1 * 0.010 + float2(9.4, 2.6)),
                       vfbm(q0 * 0.010 + float2(3.7, 8.1)), w0);

        // ============ LA RAMPE DE LA VIDÉO (22-08) ============
        // Verdict : « c'est trop orange — il faut alterner du rouge, du
        // orange, du blanc, comme la vidéo flamme de la home ».
        //
        // Je ne l'ai pas devinée : je l'ai MESURÉE dans
        // `Woop/Media/home-fond-flamme.mp4` (72 frames, 5 millions de
        // pixels de feu, teinte moyenne par niveau de luminance) :
        //
        //     racines   31· 4· 0   G/R 0,13   B/R 0,00
        //     corps bas 97·22· 1   G/R 0,23   B/R 0,01
        //     corps    138·47· 2   G/R 0,34   B/R 0,01
        //     le + chaud 211·87· 7  G/R 0,41   B/R 0,03
        //
        // DEUX RÉVÉLATIONS, et c'est la deuxième qui explique l'aplat :
        //  1. son feu vit entre 0,13 et 0,41 de G/R — je peignais à 0,60 ;
        //  2. **il n'a AUCUN BLEU.** B/R = 0,010 sur toute la vidéo. Mon
        //     bleu à 0,16-0,28 lavait la saturation et transformait un feu
        //     en nappe d'orange plate. Un feu, ça n'a pas de bleu.
        //
        // ET L'ALTERNANCE VIENT DE LÀ : la teinte suit désormais LA
        // CHALEUR (le champ de flamme + la distance), plus le rayon seul.
        // Rouge aux extrémités où la flamme s'éteint, orange dans le
        // corps — et le BLANC reste au registre du dessus (les pointes,
        // et la voix blanche des quatre). Trois registres qui alternent
        // au lieu d'un aplat : c'est ça, une flamme.
        float heat = clamp(0.66 * fl + 0.52 * napp - 0.06, 0.0, 1.0);
        heat = clamp(heat + 0.05 * sin(t * 0.45), 0.0, 1.0);
        const float3 vRacine = float3(1.00, 0.13, 0.005);
        const float3 vCorps  = float3(1.00, 0.30, 0.015);
        const float3 vChaud  = float3(1.00, 0.44, 0.035);
        float3 warm = heat < 0.55
            ? mix(vRacine, vCorps, heat / 0.55)
            : mix(vCorps, vChaud, (heat - 0.55) / 0.45);
        // LA RAFALE DU TAP : les flammes sortent un peu, du côté touché —
        // la MÊME brame, amplifiée un souffle, jamais une couche neuve.
        float gust = flare * (0.30 + 0.70
                              * (0.5 + 0.5 * cos(atan2(d.y, d.x)
                                                 - flareAng)));
        float cl = (0.55 + 0.75 * fl) * (1.0 + 1.5 * gust);
        c += warm * (napp * 0.50 * ig * cl);
        // LA BRAME PORTE TOUT : le champ advecté module le lit ENTIER
        // (voix comprises) — les rais eux-mêmes s'écoulent vers le
        // large, plus seulement l'enveloppe qui respire.
        c *= 0.72 + 0.55 * fl;
        // LES POINTES BLANCHES : un feu a des langues qui BLANCHISSENT —
        // rares, portées par le même champ, vivantes sur toute la vie
        // du cadran (plus seulement au sommet de la rampe).
        // LE TROISIÈME REGISTRE — et il compte double maintenant. Sur un lit
        // devenu franchement rouge, c'est LUI qui porte tout le blanc du
        // « rouge / orange / blanc » : sans lui l'alternance n'a que deux
        // termes. Seuil abaissé (0,58 → 0,52) et amplitude montée
        // (0,85 → 1,25) : les pointes sont plus nombreuses et elles
        // BLANCHISSENT vraiment au lieu de se deviner.
        // « ASSEZ VIOLENT » (22-08) : seuil 0,52 → 0,44 (beaucoup plus de
        // langues blanchissent), exposant 2,0 → 1,6 (elles montent plus
        // vite au blanc au lieu de se deviner), amplitude 1,25 → 2,30, et
        // la teinte quitte le crème pour un vrai blanc chaud. C'est le
        // registre le plus haut du feu : sur un lit rouge, il doit
        // TRANCHER, pas s'harmoniser.
        // Seuil 0,44 → 0,34 et exposant 1,6 → 1,25 : bien plus de langues
        // blanchissent, et elles montent au blanc plus tôt dans leur course.
        float tip = pow(max(fl - 0.34, 0.0) / 0.66, 1.25);
        // MÊME REMÈDE QUE LA VOIX BLANCHE : on TIRE vers le blanc, on ne
        // l'ajoute pas. Ici `c` porte déjà tout le lit rouge (dont le
        // canal R est saturé) — une addition y montait en jaune. Le `mix`
        // impose la teinte, et on garde la luminance de la pointe pour
        // qu'elle reste une POINTE et non une tache plate. L'amplitude
        // redescend à 1,55 : elle compensait un blanc qui n'arrivait
        // jamais, elle n'a plus à le faire.
        float mTip = clamp(napp * ig * tip * 2.70 * (1.0 + 2.6 * gust),
                           0.0, 1.0);
        if (mTip > 0.003) {
            float niv = max(max(max(c.r, c.g), c.b), 0.55);
            c = mix(c, float3(1.00, 0.97, 0.93) * niv, mTip);
        }
        // ET LE HALO ENTIER se soulève avec la rafale — voix comprises,
        // du côté touché : l'effet du tap se voit, pas seulement les
        // langues.
        c *= 1.0 + 0.40 * gust;
    }
    // LE HALO PULSE AVEC LA PASTILLE — même battement, même seconde.
    c *= 1.0 + 0.12 * pulse;
    return c;
}

[[ stitchable ]] half4 eclipseGlow(float2 position, half4 color,
                                   float2 size, float2 center, float R,
                                   float t, float ig, float pulse,
                                   float flare, float flareAng) {
    if (ig < 0.004) { return half4(0.0); }
    float2 d = position - center;
    float r = length(d);
    if (r > size.y * 0.9) { return half4(0.0); }
    float3 c = glowShade(d, r, R, t, ig, pulse, flare, flareAng);
    float a = clamp(max(max(c.r, c.g), c.b) * 0.9, 0.0, 1.0);
    return half4(half3(c), half(a)) * color.a;
}

// LA CAMÉRA DU TRAVELLING — le MÊME lit de feu, regardé de tout près.
// Le zoom vit ICI, dans le shader : le champ est recalculé à pleine
// résolution à tout grossissement (l'école ConnexionCine — une image
// agrandie, « c'était exactement le cheap »). `camZ` est le
// grossissement, `camO` l'origine écran du monde.
[[ stitchable ]] half4 successGlow(float2 position, half4 color,
                                   float2 size, float2 center, float R,
                                   float t, float ig, float pulse,
                                   float flare, float flareAng,
                                   float camZ, float2 camO) {
    if (ig < 0.004) { return half4(0.0); }
    float2 d = (position - camO) / max(camZ, 0.0001) - center;
    float r = length(d);
    if (r > size.y * 0.9) { return half4(0.0); }
    float3 c = glowShade(d, r, R, t, ig, pulse, flare, flareAng);
    float a = clamp(max(max(c.r, c.g), c.b) * 0.9, 0.0, 1.0);
    return half4(half3(c), half(a)) * color.a;
}

// MARK: La lentille
//
// `vision` : le monde d'après apparaît DANS le verre (0 → 1, sous le
// doigt). `spill` : ce monde déborde de la bille et recouvre la page
// (0 → 1, au relâcher). `sceneIg` : l'allumage des voix de la scène — il
// se poursuit tel quel côté cadran (naissance antidatée).
[[ stitchable ]] half4 liquidLens(float2 position, SwiftUI::Layer layer,
                                  float2 size, float2 center, float R,
                                  float f0, float disp, float ember,
                                  float squash, float shade, float t,
                                  float vision, float spill, float sceneIg,
                                  float nightFill, float ripple,
                                  float ripplePhase, float pulse,
                                  float nScene) {
    float2 d = position - center;
    d.y *= squash;
    float r = length(d);
    float2 n = r > 0.5 ? d / r : float2(0.0, -1.0);
    float nr = r / max(R, 1.0);
    float2 lo = float2(0.5), hi = size - 0.5;
    float maxDim = max(size.x, size.y);

    // Le rayon du monde débordé (départ lent, le monde ÉCLOT puis inonde),
    // et l'échelle de la scène : le cadran qu'on devine PETIT dans la
    // bille grandit jusqu'à DEVENIR la bille.
    float Rw = R + pow(spill, 1.30) * (1.45 * maxDim);
    float sceneR = R * mix(0.36, 1.0, smoothstep(0.0, 0.65, spill));

    // ---- Dehors : le papier intact — ou le TROU vers le monde d'après.
    // Le débordement ne peint rien : il REND TRANSPARENT — dessous, le
    // VRAI monde du cadran est déjà monté (halos réels, vraie horloge).
    // Le monde qu'on devine est le monde qu'on obtient, et la coupe
    // technique consiste à retirer un calque déjà transparent : rien.
    if (nr >= 1.0) {
        if (spill > 0.001 && r < Rw) {
            return half4(0.0);
        }
        float outD = r - R;
        // Au bord du débordement, la page est REPOUSSÉE : compression
        // radiale douce juste devant le front.
        float push = (spill > 0.001)
            ? 24.0 * exp(-pow((r - Rw) / 30.0, 2.0)) : 0.0;
        half4 base = layer.sample(clamp(position + n * push, lo, hi));
        float3 rgb = float3(base.rgb);
        // L'ombre portée de la bulle, et la lueur de la braise du drag.
        float downing = clamp(0.30 + 0.70 * (0.5 + 0.5 * n.y), 0.0, 1.0);
        float sh = exp(-(outD * outD) / (R * 0.16 * R * 0.16))
                   * downing * 0.085 * shade;
        float crest = 0.35 + 0.65 * pow(clamp(-n.y, 0.0, 1.0), 1.2);
        float glow = exp(-outD / (R * 0.032)) * ember * crest;
        rgb = rgb * (1.0 - sh) + float3(1.0, 0.52, 0.14) * (glow * 0.18);
        // LE SILLON DE CONTACT : le verre PÈSE sur son lit d'or — un
        // creux étroit contre le limbe, muet sur le papier.
        float nOn = smoothstep(0.05, 0.35, nightFill);
        float groove = exp(-pow(outD / max(R * 0.055, 2.0), 2.0));
        rgb *= 1.0 - groove * 0.25 * nOn;
        // Le ménisque du front, côté papier.
        if (spill > 0.001) {
            float men = exp(-pow((r - Rw) / 16.0, 2.0));
            rgb += float3(1.0, 0.96, 0.88) * (men * 0.14);
        }
        return half4(half3(rgb), base.a);
    }

    // ---- Dedans : la calotte de verre.
    float bell = sqrt(max(1.0 - nr * nr, 0.0));
    // Le LANGAGE du verre (fenêtre/arcs/miroir/fil) suit la SCÈNE :
    // dans la nuit, nScene = la rampe d'ignition des voix elle-même —
    // la fenêtre du jour meurt PENDANT que les arcs naissent, même
    // rampe. La MATIÈRE (absorption), elle, suit nightFill.
    float nightOn = max(smoothstep(0.05, 0.35, nightFill), nScene);
    // LE VERRE RECUEILLE : sur la nuit, la bande qui échantillonne HORS
    // du disque passe de 6 % à 17 % du rayon — la couronne du halo se
    // replie ~3:1 dans le sixième externe. Garde-fou maxSampleOffset :
    // (edgeF − 1)·R ≤ 105 pt. Jour : nightOn = 0, formule d'origine.
    float edgeF = 1.32 + nightOn * clamp(105.0 / max(R, 1.0) - 0.32,
                                         0.0, 0.26);
    float f = mix(edgeF, f0, pow(bell, mix(0.82, 1.45, nightOn)));
    // L'ONDE DE LA GOUTTE : après l'atterrissage, une vague circulaire
    // traverse la surface — l'eau qui tremble, brève, amortie.
    if (ripple > 0.002) {
        f *= 1.0 + ripple * 0.05 * sin(nr * 24.0 - ripplePhase)
                 * (0.35 + 0.65 * bell);
    }
    float sep = disp * 0.055 * pow(nr, 2.4);
    // Au limbe, sur la nuit, les trois canaux se resserrent : l'écart
    // faisait échantillonner le halo or par le seul canal vert — un fil
    // teal + indigo sur le bord (mesuré par deux juges). La dispersion
    // vit dans le corps du verre, pas sur son fil.
    // Kill COMPLET dès 0,90 : le sillon de contact est un trait fin
    // juste dehors — la dispersion résiduelle en refaisait une frange.
    sep *= 1.0 - nightOn * smoothstep(0.70, 0.90, nr);
    float2 dir = float2(d.x, d.y / squash);
    // Chaque échantillon reste À PORTÉE du layerEffect (maxSampleOffset
    // 110) : au sommet du zoom, R explose et les offsets dépassaient la
    // garantie — le GPU rendait des TUILES rectangulaires (les blocs à
    // x = 256/512 mesurés par le panel). Le verre ne cède JAMAIS.
    float2 pR = center + dir * (f * (1.0 - sep));
    float2 pG = center + dir * (f * (1.0 + sep * 0.40));
    float2 pB = center + dir * (f * (1.0 + sep * 1.35));
    pR = clamp(position + clamp(pR - position, -105.0, 105.0), lo, hi);
    pG = clamp(position + clamp(pG - position, -105.0, 105.0), lo, hi);
    pB = clamp(position + clamp(pB - position, -105.0, 105.0), lo, hi);
    half4 sG = layer.sample(pG);
    float3 rgb = float3(layer.sample(pR).r, sG.g, layer.sample(pB).b);

    // ---- L'habillage du verre — il ne cède JAMAIS : verre clair et verre
    // plein de nuit ont les mêmes reflets.
    rgb *= 1.0 - 0.045 * pow(nr, 3.5) * shade;
    float frost = smoothstep(0.955, 1.0, nr);
    // Le givre gris est une teinte froide : il meurt sur la nuit.
    rgb = mix(rgb, float3(0.965, 0.955, 0.935),
              frost * 0.14 * shade * (1.0 - nightOn));

    // ---- LA NUIT DANS LE VERRE : pendant le zoom du sommet, l'intérieur
    // se remplit d'une nuit lunaire — on n'entre pas dans un décor, on
    // entre dans l'OBJET. Le velours vfbm (le drap du cadran), et une
    // clarté de lune à peine posée par le haut du verre.
    float mA = 0.5;
    if (nightFill > 0.001) {
        // LE VERRE QUI SE REMPLIT — un VOLUME traversé, jamais une
        // peinture. La nuit est une nuit d'ENCRE : le bleu meurt en
        // premier, la traversée est ambre sombre.
        float inside = 1.0 - smoothstep(R - 1.0, R + 0.5, r);
        // LA PAROI : la corde s'amincit VITE au limbe — le monde chaud
        // traverse le bord du verre plein ; le cœur garde la nuit.
        // La paroi reste PLEINE jusqu'à nr ≈ 0,95 : le fil de feu du
        // limbe fait ~8 px (la signature validée : 5-9 px), plus jamais
        // une bande de transmission de 60 px.
        float chord = pow(bell, mix(1.45, 0.55, nightOn));
        // LE MARBRE DE L'ÉPAISSEUR : la densité varie — deux échelles du
        // drap, dérives à contre-courant, parallaxe (le fond bouge
        // moins). Poche dense = plus sombre ET plus rouge ; veine = plus
        // claire ET plus or : la PROFONDEUR varie, pas une teinte.
        float2 md = d * mix(1.00, 0.72, bell);
        mA = vfbm(md * 0.011 + float2(t * 0.017, -t * 0.011));
        float mB = vfbm(md * 0.034 + mA * 0.7
                        + float2(-t * 0.010, t * 0.006));
        float marble = 0.62 * mA + 0.38 * mB
                       + 0.05 * sin(t * 0.42 + mA * 6.0);
        // Le marbre naît AVEC la nuit — jamais une trame qui « apparaît ».
        float mAmp = 0.45 * smoothstep(0.15, 0.55, nightFill);
        // L'ONYX : profondeur 3,0, spectre qui tue le caramel (le R/B
        // 2,70 mesuré ÉTAIT la signature de l'absorption trop courte).
        // Cœur T_r ≈ 2 % — un noir vivant, jamais un aplat.
        float L = 2.7 * chord * nightFill * inside * (0.78 + mAmp * marble);
        L *= 1.0 - 0.14 * pulse;
        float3 T = exp(-float3(1.95, 2.35, 2.85) * L);
        float cloth = 0.80 + 0.40 * mA;
        float moon = pow(clamp(-d.y / max(r, R * 0.18), 0.0, 1.0), 2.0);
        // LA BRAISE QUI COUVE : seules les poches denses émettent, au
        // FOND du volume (bell²) — le limbe TRANSMET. Lune baissée : la
        // vraie lumière vient du lit d'or, en bas. Sous les chiffres, la
        // braise se calme (lisibilité de « 0:00 »).
        float pool = smoothstep(0.45, 0.85, marble)
                     * (1.0 - 0.35 * exp(-(r * r)
                                         / (0.30 * R * 0.30 * R)));
        // Émissions au strict minimum : un objet transparent n'émet
        // presque rien — le marbre vfbm reste la seule vie interne.
        float3 nightC = float3(0.0040, 0.0034, 0.0028) * cloth
                        + float3(0.006, 0.005, 0.004) * moon
                        + float3(0.014, 0.008, 0.003)
                          * (pool * bell * bell);
        // L'ABSORPTION EN LINÉAIRE : défaire le tonemap du monde
        // échantillonné, traverser T, re-tonemapper — la SOURCE perce la
        // fumée, les ombres meurent franchement.
        float3 linW = -log(max(1.0 - min(rgb, float3(0.985)),
                               float3(0.015))) * (1.0 / 1.55);
        rgb = 1.0 - exp(-(linW * T) * 1.55);
        rgb += nightC * (1.0 - T);
    }

    // ---- Le ruban « inspiration » du drag (meurt dans la condensation).
    if (ember > 0.004) {
        float seat = 0.30 + 0.70 * pow(clamp(-n.y, 0.0, 1.0), 1.1);
        float swellR = 0.86 + 0.14 * lfbm(n * 1.15
                                          + float2(t * 0.09, -t * 0.06));
        float bandC = 0.80 * swellR;
        float dBand = (nr - bandC) / 0.115;
        float body = exp(-dBand * dBand);
        // Le ruban « inspiration » du drag : sa tête dorait, elle passe à
        // l'orange — son pied était déjà de la braise, il ne bouge pas.
        float3 col = mix(float3(1.00, 0.66, 0.20),
                         float3(0.98, 0.42, 0.06),
                         clamp(dBand * 0.7 + 0.5, 0.0, 1.0));
        rgb -= float3(0.14, 0.095, 0.055) * (body * seat * ember * 0.60);
        rgb += col * (body * seat * ember * 0.78);
        float soot = exp(-pow((nr - (bandC + 0.135)) / 0.05, 2.0));
        rgb -= float3(0.20, 0.15, 0.11) * (soot * seat * ember * 0.55);
        float capMask = clamp(body * seat * ember, 0.0, 1.0);
        rgb = mix(rgb, min(rgb, float3(0.95, 0.86, 0.72)), capMask * 0.85);
    }

    // ---- LA VISION : le monde d'après, courbé DANS le verre. Le doigt la
    // fait naître (fin de course) ; la scène est petite — on la DEVINE —
    // puis elle grandit avec le débordement jusqu'à devenir la bille.
    if (vision > 0.001) {
        float2 dFish = n * (pow(nr, 1.45) * R);
        float3 seen = eclipseWorld(dFish, length(dFish), sceneR, t,
                                   sceneIg, 1.0, 1.0);
        // La profondeur du verre : la vision est plus dense au cœur.
        float depth = 0.55 + 0.45 * bell;
        float inside = 1.0 - smoothstep(R - 1.0, R + 0.5, r);
        rgb = mix(rgb, seen, vision * depth * inside);
    }

    // ---- Les reflets, par-dessus tout — l'identité du verre.
    float band = smoothstep(0.82, 0.965, nr) * (1.0 - smoothstep(0.975, 1.0, nr));
    float up = clamp(-n.y, 0.0, 1.0);
    float down = clamp(n.y, 0.0, 1.0);
    float specK = shade * (1.0 - 0.78 * clamp(ember, 0.0, 1.0))
                  * (1.0 - 0.45 * smoothstep(0.6, 1.0, spill));
    float fres = 0.06 + 0.94 * pow(1.0 - bell, 5.0);
    // LES ARCS DES VOIX : les VRAIS halos se reflètent sur la courbe —
    // géométrie miroir sphérique exacte (azimut conservé, compression
    // radiale ~3:1, Fresnel qui les éteint vers le cœur), ancrés sur les
    // positions qui DÉRIVENT. VERROU : ces constantes sont le clone
    // exact d'eclipseWorld (cols/speed/phase/rho0/srs/sts/bper/bbase/
    // bamp/wgt) — toute retouche de palette du halo DOIT se refléter ici.
    float reflOn = nightOn * specK;
    float lipEnv = 0.0;
    if (reflOn > 0.004 && nr > 0.50) {
        // ⚠️ CLONE EXACT de `cols[]` d'eclipseWorld — harmonisation 22-08,
        // 2e passe : rouge profond / orange / BLANC / rouge-orange, calés
        // sur la vidéo flamme de la home, bleu à zéro. Le verrou tient :
        // le galet ne peut pas refléter un halo qui n'existe plus.
        const float3 rc[4]  = { float3(1.00, 0.17, 0.02),
                                float3(1.00, 0.46, 0.03),
                                float3(1.00, 0.96, 0.90),
                                float3(1.00, 0.29, 0.02) };
        const float rsp[4]  = {  6.2832 / 47.0, -6.2832 / 29.0,
                                 6.2832 / 19.0, -6.2832 / 71.0 };
        const float rph[4]  = { 0.4, 2.6, 4.4, 5.6 };
        const float rr0[4]  = { 1.02, 0.98, 1.01, 1.14 };
        // (voix blanche élargie — clone de srs/sts, 22-08)
        const float rsr[4]  = { 0.34, 0.19, 0.23, 0.42 };
        const float rst[4]  = { 0.66, 0.50, 0.58, 0.72 };
        const float rbp[4]  = { 13.0, 8.1, 5.2, 21.0 };
        const float rbb[4]  = { 0.72, 0.62, 0.50, 0.66 };
        const float rba[4]  = { 0.28, 0.38, 0.50, 0.30 };
        // (voix blanche dominante — clone de wgt, 22-08 : le blanc doit se
        // refléter DANS le verre aussi, sinon le galet dément son halo)
        const float rwg[4]  = { 0.55, 0.85, 1.05, 0.50 };
        float phi = atan2(d.y, d.x);
        float3 refl = float3(0.0);
        for (int i = 0; i < 4; i++) {
            float ang = rph[i] + t * rsp[i];
            float rho = rr0[i] + 0.05 * sin(t * 6.2832 / (rbp[i] * 2.7)
                                            + rph[i] * 3.0);
            float br  = rbb[i] + rba[i] * sin(t * 6.2832 / rbp[i]
                                              + rph[i] * 5.0);
            float s = min((1.0 + sqrt(1.0 + 8.0 * rho * rho))
                          / (4.0 * rho), 1.0) - 0.055;
            float dA = phi - ang;
            dA -= 6.2832 * floor(dA / 6.2832 + 0.5);
            float sigA = 1.15 * rst[i] / rho;
            float gA = exp(-dA * dA / (sigA * sigA));
            float sigR = 0.035 + 0.28 * rsr[i];
            float drr = (nr - s) / sigR;
            refl   += rc[i] * (gA * exp(-drr * drr) * br * rwg[i]);
            lipEnv += gA * br * rwg[i];
        }
        rgb += min(refl * (fres * 0.42 * reflOn * (0.85 + 0.30 * mA)
                           * (1.0 + 0.30 * pulse)), float3(0.14));
    }
    float nGain = 1.0 + 0.25 * nightFill;
    // Le lobe haut n'a rien à refléter la nuit (le ciel EST la nuit) ;
    // le lobe bas devient feu et suit les voix via lipEnv.
    rgb += float3(1.0) * (pow(up, 2.6) * band * 0.13 * specK * nGain
                          * (1.0 - 0.75 * nightOn));
    // Le spéculaire du lobe BAS, la nuit : il prenait la teinte du feu —
    // et le feu n'est plus doré (22-08).
    rgb += mix(float3(1.0), float3(1.00, 0.50, 0.14), nightOn)
           * (pow(down, 3.2) * band * 0.06 * specK * nGain
              * mix(1.0, 0.40 + 0.60 * min(lipEnv, 1.0), nightOn));
    // Le fil ne brille QUE face aux voix — fini le cercle parfait : la
    // séparation vient de l'éclairage, jamais d'un contour.
    float lip = exp(-pow((nr - 0.994) / 0.010, 2.0));
    // LE FIL DU LIMBE : c'est LUI qu'on lit comme « le galet a un liseré
    // doré ». Il reste clair — un fil de verre n'est pas une braise — mais
    // il quitte l'or pour un blanc chaud d'orange.
    rgb += mix(float3(1.0, 0.99, 0.96), float3(1.00, 0.86, 0.68), nightOn)
           * (lip * mix(0.09, 0.030 + 0.11 * min(lipEnv, 1.0), nightOn)
              * shade * nGain
              * (1.0 - 0.6 * smoothstep(0.7, 1.0, spill)));
    // LA FENÊTRE SPÉCULAIRE : compacte, bord DUR, étirée en arc (deux
    // lobes), calée sur la caustique validée de la phase blanche —
    // nr 0,61, azimut −29°, hors zone des chiffres. Base dès le papier :
    // rien ne s'allume en couche.
    float3 N3 = float3(n.x * nr, n.y * nr, bell);
    // Resserrée (« too much » de Kathryn) : −60 % de surface, lobes
    // rapprochés en ARC, un tiers d'intensité en moins, teinte chaude —
    // un reflet de fenêtre, plus une fève de bonbon.
    const float3 Lw  = float3(0.533, -0.296, 0.792);
    const float3 Lw2 = float3(0.494, -0.359, 0.792);
    float sw = max(max(dot(N3, Lw), dot(N3, Lw2)), 0.0);
    float winCore = smoothstep(0.9865, 0.9955, sw);
    float winSh   = 0.16 * smoothstep(0.952, 0.9865, sw);
    // LA PASSATION : la fenêtre du jour MEURT sur la rampe même qui
    // allume les arcs des voix — une lumière qui change de source,
    // jamais un spot synthétique sur la nuit (« trop jouet », Kathryn).
    float winK = 0.18 * pow(1.0 - nightOn, 1.6) * specK;
    rgb += float3(1.00, 0.965, 0.90) * ((0.50 * winCore + winSh) * winK);
    // LE LIMBE-MIROIR : Schlick × échantillon RÉFLÉCHI au-delà du bord —
    // le limbe recopie le VRAI lit d'or (sa trame, ses voix, son heure) :
    // embrasé en bas face au halo, nuit en haut.
    // Resserré (61 → ~23 px) et calmé la nuit — le limbe ne vit que là
    // où le monde l'éclaire ; il respire avec le pouls.
    float rimZ = smoothstep(mix(0.80, 0.90, nightOn),
                            mix(0.97, 0.985, nightOn), nr)
                 * (1.0 - smoothstep(mix(0.988, 0.994, nightOn), 1.0, nr));
    // Asservi aux voix comme le fil : le miroir ne recopie plus la nappe
    // symétrique — l'anneau CASSE côté nuit.
    // Le pouls du miroir est retiré : le lit pulse désormais lui-même
    // (eclipseGlow) et le miroir l'échantillonne — le garder ici
    // multiplierait les deux battements.
    float rimW = rimZ * (0.55 - 0.25 * nightOn) * specK
                 * mix(1.0, 0.35 + 0.65 * min(lipEnv, 1.0), nightOn);
    if (rimW > 0.004) {
        float mEnv = (1.0 + (1.0 - nr) * 2.3) / max(nr, 0.5);
        mEnv = min(mEnv, 1.0 + 100.0 / max(r, 1.0));
        float3 env = float3(layer.sample(clamp(center + dir * mEnv,
                                               lo, hi)).rgb);
        // Anti-clip : la saturation feu du monde survit au reflet.
        // Le monde reflété est plus rouge qu'avant : l'anti-clip le suit
        // d'un cran, sinon le miroir re-verdirait ce que le lit vient de
        // perdre (le rapport compte, pas la valeur absolue).
        env *= mix(float3(1.0), float3(1.00, 0.88, 0.72), nightOn);
        rgb += env * (fres * rimW);
    }

    // Anticrénelage du bord : sur le papier on retombe sur lui ; sur le
    // monde débordé on fond vers le TRANSPARENT — le vrai monde dessous.
    float aa = smoothstep(R - 1.6, R + 0.4, r);
    if (spill > 0.001) {
        float keep = 1.0 - aa;
        return half4(half3(clamp(rgb, 0.0, 2.0)) * keep, keep);
    }
    float3 outRGB = float3(layer.sample(position).rgb);
    rgb = mix(rgb, outRGB, aa);
    return half4(half3(clamp(rgb, 0.0, 2.0)), sG.a);
}
