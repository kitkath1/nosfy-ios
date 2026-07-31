#include <metal_stdlib>
using namespace metal;

// MARK: - Le monolithe — la lune en néon sur un pavé de laque noire
//
// Une scène plein écran, une seule passe OPAQUE : le shader possède son fond
// noir, il n'y a pas de gymnastique d'alpha de carte flottante — le
// fenêtrage des queues de bloom joue le rôle du hostFade. Un petit pavé aux
// coins d'icône, vu de trois quarts par projection orthographique
// analytique : la projection parallèle d'un plan est une application
// linéaire 2×2, la face avant reste donc un sdRound évalué dans un repère
// transformé (jamais de raymarch ; rotation3DEffect rastériserait les
// hairlines et le dither). La silhouette est le min de SIX tranches, avec
// une perspective douce (échelle uniforme par tranche : elle conserve la
// métrique du SDF, une homographie la détruirait). L'ancien min-de-TROIS
// annonçait « 0,2 pt à ±35° » : faux d'un facteur 12 — mesuré 2,83 pt à la
// butée du doigt, soit 8 pixels de créneau. Six tranches ramènent ça à
// 0,048 pt au repos et 0,705 pt à la butée.
//
// LA MATIÈRE EST UNE LAQUE, PAS UN MÉTAL BROSSÉ. Un piano black : noir
// profond (1,4 % au repos), et la lumière ne se pose pas dessus — elle vient
// de DEDANS, sous le verni. Deux nappes de studio lisses et déterministes
// (pas de bruit fractal) glissent sur la face EN SENS INVERSE de la
// rotation : c'est ce glissement, plus que la géométrie, qui prouve qu'on
// tourne un objet réel. Le brossage n'a pas disparu, il est descendu au rang
// de micro-satiné qui ne se révèle QUE dans les nappes les plus vives.
//
// LE CROISSANT EST UN TUBE DE CONTOUR POSÉ SUR DU VERRE DÉPOLI. Le tube :
// un cœur blanc-chaud sur le TRACÉ (|d| ≈ 0), 2,25 pt à mi-hauteur = 1,5 %
// de la face, des flancs orange courts. Le blanc n'est pas peint : il est
// FABRIQUÉ par le tone mapping filmique à partir d'une énergie surchargée —
// c'est la clé anti-criard. L'intérieur n'est PAS un voile ajouté par
// dessus : c'est une dalle de verre rétroéclairé POSÉE sur la laque
// (E = E_laque·(1−alpha) + C_verre·E_verre), à 40 % de luminance, avec
// quatre champs SÉPARÉS — couverture, rétroéclairage par le tube, rampe de
// softbox, et un CREUX à la jonction. Un seul champ ne peut pas porter à la
// fois « où est le verre » et « comment il est éclairé » : c'est ce mélange,
// plus deux glares figés par un max(), qui donnait la nappe orange plate.
//
// Autour de la silhouette court un FILET de 1 pt, orange, avec un point
// chaud qui voyage le long du périmètre : le reflet spéculaire d'une source
// qui glisse sur le chanfrein, jamais une LED de boîtier de gamer. Une raie
// anamorphique traverse la scène et fleurit en étoile là où elle croise
// l'arête. Sous le pavé, une flaque de lumière chaude — l'objet est posé.
//
// Tout est périodique sur 900 s EXACTEMENT : sinus en k·2π/900 avec k
// entier, dérives de bruit sinusoïdales (une dérive linéaire sur une grille
// hashée saute au raccord de boucle), fenêtres d'événements sur des
// diviseurs exacts de 900.

constant float TAU = 6.2831853;
constant float PH = TAU / 900.0;

// L'axe des raies, à −30,000° EXACT (cos/sin analytiques) : les deux raies
// doivent rester parallèles au pixel près sur 500 pt — un écart de 0,6°
// donne 5 pt de divergence aux extrémités.
constant float2 SDIR = float2(0.86603, -0.50000);
constant float2 SNRM = float2(0.50000,  0.86603);

// LE CIEL EST ÉTEINT. Mesuré sur la v4 : 1 900 px du fond lointain
// dépassent 16/255 alors que le halo cible vaut 2,6/255 à 40 pt de l'objet —
// le champ lointain est 6× plus brillant que le champ proche, et l'œil
// ramène le fond au PREMIER PLAN. Surtout : la scène a maintenant une ligne
// de pose, une ombre de contact de 9 pt et une flaque à 38/255. Un objet
// POSÉ SUR UN SOL ne flotte pas dans l'espace en même temps ; deux récits
// contradictoires plafonnent la note quelle que soit l'exécution. Le code
// reste (la maison a déjà un ciel, celui de l'aurore) : remettre STARFIELD
// à 1.0 rallume tout, y compris dans la branche lointaine.
constant float STARFIELD = 0.0;

/// Les deux raies anamorphiques. Retourne (principale, fantôme, abscisse le
/// long des raies, distance en travers de la principale).
///
/// UN CŒUR DIFFRACTIF FIN POSÉ SUR UNE JUPE DE DIFFUSION LARGE : c'est le
/// RAPPORT des deux qui fait lire « lumière » et non « trait de crayon ». La
/// v4 mesurait 0,55 pt de mi-hauteur et RIEN au-delà de ±2 pt. Jupe à 22 %
/// du cœur avec un sigma 6× plus grand : elle porte l'essentiel de l'énergie
/// intégrée, et c'est ce ratio-là que l'œil lit comme du glare.
///
/// Le décalage du contre : l'arête gauche est à x = −77,8 pt ; pour que la
/// raie la croise à y = −10 (le tiers supérieur du bord vertical, là où
/// l'étoile doit fleurir), il faut faceR·0,627. L'ancien 0,30 plaçait le
/// croisement à y = +21 — mesuré sur la capture, point chaud à (−82, +21).
/// Le FANTÔME est décalé de 50 pt VERS LE HAUT, pas vers le bas : une image
/// parasite se DÉPLACE, elle ne vient pas trancher le sujet une seconde fois.
///
/// L'enveloppe : la v4 mourait à 150 pt (4/255 à alongS = 140, mesuré) —
/// une raie qui meurt à 1,5 fois la taille de l'objet ne lit pas comme un
/// artefact d'objectif. Cœur gaussien (sigma 83 pt) + queue exponentielle
/// basse à 22 % : 54/255 à 110 pt, 8/255 à 200 pt, morte à 300 pt, donc
/// AVANT les bords du cadre. C'est le dégradé, pas la longueur, qui
/// distingue une raie d'un trait de crayon.
static float4 lmStreak(float2 pC, float faceR) {
    float alongS = dot(pC, SDIR);
    float across1 = dot(pC, SNRM) + faceR * 0.627;
    float across2 = across1 + faceR * 0.660;
    // L'ENVELOPPE SE RACCOURCIT ET SE FOND. À sigma 118 avec une queue
    // exponentielle à 22 %, les raies couraient sur 600 pt : deux barres
    // parallèles nettes en travers de l'écran, donc deux traits de crayon.
    // Une raie d'objectif NAÎT et MEURT dans le voisinage de sa source. À 68
    // et 54, elles tiennent dans une largeur et demie de pavé, et la queue
    // tombe à 8 % pour que l'extinction soit un fondu et non une coupure.
    float aN = alongS / 68.0, aM = alongS / 54.0;
    float env1 = exp(-aN * aN) + 0.08 * exp(-fabs(alongS) / 40.0);
    float env2 = exp(-aM * aM) + 0.06 * exp(-fabs(alongS) / 32.0);
    float s1 = (exp(-across1 * across1 / (0.80 * 0.80))          // 1,33 pt à mi-hauteur
              + 0.22 * exp(-across1 * across1 / (4.80 * 4.80)))  // jupe, 8,0 pt
             * env1;
    float s2 = (exp(-across2 * across2 / (0.95 * 0.95))
              + 0.24 * exp(-across2 * across2 / (5.20 * 5.20))) * env2;
    return float4(s1, s2, alongS, across1);
}

static float lmHash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 lmHash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float lmNoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = lmHash21(i);
    float b = lmHash21(i + float2(1.0, 0.0));
    float c = lmHash21(i + float2(0.0, 1.0));
    float d = lmHash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float lmFbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * lmNoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

/// Distance signée au rectangle arrondi (négatif dedans).
static float lmSdRound(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Abscisse curviligne le long du périmètre, 0..1 (départ coin haut-gauche,
/// sens horaire) — la paramétrisation honnête d'un filet : l'angle depuis le
/// centre fige le motif sur les longs bords (piège payé sur le bouton).
static float lmArc(float2 p, float2 b, float r) {
    float wx = max(b.x - r, 0.0);
    float wy = max(b.y - r, 0.0);
    float qc = 1.5707963 * r;
    float P = 4.0 * (wx + wy) + 4.0 * qc;
    float2 c = float2(clamp(p.x, -wx, wx), clamp(p.y, -wy, wy));
    float2 dv = p - c;
    float ang = atan2(dv.y, dv.x);
    bool cx = fabs(p.x) > wx;
    bool cy = fabs(p.y) > wy;
    float s;
    if (!cx && p.y < 0.0) {
        s = p.x + wx;
    } else if (cx && cy && p.x > 0.0 && p.y < 0.0) {
        s = 2.0 * wx + (ang + 1.5707963) * r;
    } else if (!cy && p.x > 0.0) {
        s = 2.0 * wx + qc + (p.y + wy);
    } else if (cx && cy && p.x > 0.0) {
        s = 2.0 * wx + qc + 2.0 * wy + ang * r;
    } else if (!cx) {
        s = 2.0 * wx + 2.0 * qc + 2.0 * wy + (wx - p.x);
    } else if (cx && cy && p.y > 0.0) {
        s = 4.0 * wx + 2.0 * qc + 2.0 * wy + (ang - 1.5707963) * r;
    } else if (!cy) {
        s = 4.0 * wx + 3.0 * qc + 2.0 * wy + (wy - p.y);
    } else {
        s = 4.0 * wx + 3.0 * qc + 4.0 * wy + (ang + 3.1415927) * r;
    }
    return fract(s / max(P, 1.0));
}

/// La poussière d'étoiles : trois grilles à pas premiers entre eux,
/// magnitudes en loi de puissance (la hiérarchie fait lire « ciel »),
/// plancher de sigma avec conservation d'énergie (la poudre sub-pixel ne
/// fourmille pas), halo Moffat sur les seules vives — zéro aigrette. Le
/// champ BALANCE sinusoïdalement au lieu de dériver : une dérive linéaire
/// sur une grille hashée saute au raccord de boucle.
static float lmStars(float2 pos, float t) {
    float star = 0.0;
    for (int k = 0; k < 3; k++) {
        float cell = (k == 0) ? 17.0 : (k == 1) ? 29.0 : 41.0;
        float amp = (k == 0) ? 14.0 : (k == 1) ? 8.0 : 4.0;
        float2 sway = amp * float2(sin(PH * (2.0 + float(k)) * t + 1.3 * float(k)),
                                   -0.7 * cos(PH * (3.0 + float(k)) * t + 0.7 * float(k)));
        float2 q = pos + sway;
        float2 id = floor(q / cell);
        float4 h = lmHash42(id * 1.71 + float2(3.3 + 5.1 * float(k), 7.7));
        if (h.x > 0.40) continue;
        float2 c0 = (id + 0.5 + (h.yz - 0.5) * 0.9) * cell;
        float2 dp = q - c0;
        float r2 = dot(dp, dp);
        if (r2 > 36.0) continue;
        float kk = 7.0 + floor(h.w * 13.0);
        float tw = 0.42 + 0.58 * pow(max(0.0, sin(PH * kk * t + h.z * TAU)), 3.0);
        float sig = 0.30 + 0.30 * h.w;
        float sub = min(sig / 0.48, 1.0);
        sig = max(sig, 0.48);
        float s = exp(-r2 / (2.0 * sig * sig)) * sub * sub;
        if (h.z > 0.965) {
            float rh2 = r2 / (2.6 * 2.6);
            s += 0.10 * pow(1.0 + rh2, -1.75);
        }
        star += s * (0.028 + 0.42 * pow(h.z, 2.8)) * tw;
    }
    return min(star, 0.55);
}

// `tilt` : gyroscope SkyMotion (±1 par axe, nul au simulateur).
// `userYaw` : la rotation au doigt, en radians — calculée côté Swift comme
// une fonction PURE du temps (glissement, puis inertie amortie analytique,
// puis retour doux au repos) : un paramètre de shader ne s'interpole pas
// tout seul.
// `reveal` : rampe 2 s côté Swift. `benchBoost` / `benchSweep` : sentinelles
// -1 = piloté par l'horloge. `sdfRanges` = (padding, tight, wide) et
// `moonPlace` = (cx, cy, k) : la géométrie du croissant, source de vérité
// dans MoonSDF.swift — jamais recopiée ici.
[[ stitchable ]] half4 logoMonolith(float2 position, half4 color,
                                    float2 size, float t,
                                    float2 tilt, float userYaw,
                                    float reveal, float faceR,
                                    float benchBoost, float benchSweep,
                                    float debugSDF,
                                    float3 sdfRanges, float3 moonPlace,
                                    texture2d<half> moonSDF) {
    constexpr sampler kFace(address::clamp_to_edge, filter::linear, coord::normalized);

    // ---- Mode debug (`-logoDebugSDF`) : la LUT du croissant en clair, pour
    // vérifier que ce que le GPU LIT est bien ce que le CPU a ÉCRIT — une
    // conversion d'espace couleur à l'upload courberait l'encodage des
    // distances et déplacerait le contour. Rouge = le tracé décodé (|d| < 1
    // texel), vert = le canal serré brut, bleu = l'intérieur décodé.
    if (debugSDF > 0.5) {
        float2 duv = position / max(min(size.x, size.y), 1.0);
        if (duv.x > 1.0 || duv.y > 1.0) return half4(0.0h, 0.0h, 0.0h, 1.0h);
        half4 s = moonSDF.sample(kFace, duv);
        float dRaw = (float(s.r) - 0.5) * 2.0 * sdfRanges.y;   // en uc
        float onLine = (fabs(dRaw) < 0.004) ? 1.0 : 0.0;
        float insideD = (dRaw < 0.0) ? 0.45 : 0.0;
        return half4(half(onLine), half(float(s.r)), half(insideD), 1.0h);
    }

    // ---- Les horloges.
    float exposure = mix(0.35, 1.0, reveal);
    float ignite = smoothstep(0.30, 1.0, reveal);
    // Respiration du néon : trois voix incommensurables (17,0 / 39,1 /
    // 8,9 s), plancher cumulé ≈ 0,89 — jamais le métronome.
    float breath = 1.0 + 0.050 * sin(PH * 53.0 * t + 1.7)
                       + 0.035 * sin(PH * 23.0 * t + 4.2)
                       + 0.020 * sin(PH * 101.0 * t + 0.6);
    float flick = 1.0 + 0.040 * sin(PH * 127.0 * t + 1.1)
                      + 0.018 * sin(PH * 17.0 * t + 3.7);
    float tempo = sin(PH * 7.0 * t + 2.4);

    // La montée du néon : fenêtres de 112,5 s (8 par boucle), départ jitté
    // par hash replié modulo 8 — la fenêtre à cheval sur le raccord de
    // boucle garde le même hash des deux côtés.
    float boostEnv;
    if (benchBoost >= 0.0) {
        boostEnv = benchBoost;
    } else {
        float braw = floor((t + 56.25) / 112.5);
        float bh = lmHash21(float2(fmod(braw, 8.0) * 1.37 + 8.1, 3.9));
        float e = (t + 56.25 - braw * 112.5) - (20.0 + bh * 40.0);
        boostEnv = (e > 0.0)
            ? smoothstep(0.0, 3.0, e) * exp(-max(e - 3.0, 0.0) / 6.0) : 0.0;
    }
    float neonGain = (1.0 + 0.18 * boostEnv) * breath * flick * ignite;
    float bloomWiden = 1.0 + 0.10 * boostEnv;

    float2 C = float2(size.x * 0.5, size.y * 0.46);
    float2 pC = position - C;
    float2 para = float2(-3.0 * sin(PH * 11.0 * t + 0.7) - 3.0 * tilt.x,
                         -2.0 * sin(PH * 17.0 * t + 1.3) - 2.0 * tilt.y);
    float2 dither2 = fract(floor(t * 24.0) * 0.618) * float2(17.0, 29.0);

    // ---- E0 : loin de tout, il n'y a plus que les deux raies — le ciel est
    // éteint. Le seuil vaut faceR·1,6 + 150 = 271,6 pt alors que la nouvelle
    // enveloppe porte la raie à ~300 pt : SANS ce bloc elle serait tranchée
    // net sur un arc de cercle en travers de l'écran. Le halo, lui, vaut
    // 0,03/255 à cette distance, il n'a pas besoin d'y survivre.
    // Coût : 3 produits scalaires et 6 exp — MOINS que les 3 boucles de
    // lmStars qu'on retire.
    float rC = length(pC);
    if (rC > faceR * 1.6 + 150.0) {
        float4 sq0 = lmStreak(pC, faceR);
        float3 E0 = lmStars(position + para, t) * STARFIELD * float3(0.92, 0.95, 1.02)
                  + float3(1.00, 0.72, 0.34) * ((0.32 * sq0.x + 0.109 * sq0.y) * neonGain);
        float3 c0 = 1.0 - exp(-1.35 * E0 * exposure);
        c0 = c0 * c0 / (c0 + 0.0085);
        c0 += (lmHash21(position * 1.113 + dither2) - 0.5) * (1.6 / 255.0);
        return half4(half3(saturate(c0)), 1.0h);
    }

    // ---- La projection. Lacet de repos POSITIF : la tranche s'ouvre à
    // GAUCHE, comme sur la référence. Le doigt ajoute `userYaw` ; le
    // micro-balancement et le gyroscope restent des dérives de caméra.
    float yaw = 0.2450 + userYaw
              + 0.0175 * sin(PH * 11.0 * t + 0.7)
              + 0.0087 * sin(PH * 29.0 * t + 2.9)
              + 0.05 * tilt.x;
    float pitch = -0.0698 + 0.0070 * sin(PH * 17.0 * t + 1.3) + 0.04 * tilt.y;
    float cyw = cos(yaw), syw = sin(yaw), cpt = cos(pitch), spt = sin(pitch);
    float2 Ex = float2(cyw, syw * spt);
    float2 Ey = float2(0.0, cpt);
    float2 Ez = float2(syw, -cyw * spt);

    // LA PERSPECTIVE, en une division par tranche. Les fuyantes verticales
    // d'un cuboïde restent verticales quel que soit l'objectif : ce qui donne
    // le volume, c'est que la face ARRIÈRE est plus loin, donc plus PETITE.
    // Une échelle UNIFORME par tranche CONSERVE la métrique du SDF
    // (sdRound(p/s)·s EST une distance) ; une homographie complète
    // demanderait un jacobien par pixel pour garder faceMask, le filet à
    // sigma 0,50 pt et le bombé en POINTS.
    // Mesuré : la tranche gauche tombe de 15,49 à 12,39 pt = 7,75 % de la
    // silhouette (la fiche demande ~7 %, la métrique ≥ 6 %) SANS mentir sur
    // l'épaisseur du solide ; le chant du HAUT passe de 4,31 à 1,44 pt — la
    // référence ne montre d'épaisseur qu'à gauche ; le bord extérieur gauche
    // sort 3,4 pt plus court que l'arête, et la tranche se PINCE toute seule
    // dans les coins (13,8 pt à mi-hauteur contre 17,9 au coin sur la v4).
    const float PERSP = 0.962;

    float hD = faceR * 0.42;
    float invDet = 1.0 / max(Ex.x * Ey.y - Ey.x * Ex.y, 1e-5);
    float2 iR0 = float2(Ey.y, -Ey.x) * invDet;
    float2 iR1 = float2(-Ex.y, Ex.x) * invDet;
    float2 b = float2(faceR);
    float rc = faceR * 0.44;

    // SIX tranches, pas trois. Le commentaire de tête annonçait « à ±35°
    // l'erreur de festonnage reste sous 0,2 pt » : FAUX d'un facteur 12.
    // Résidu radial maximal mesuré contre une silhouette à 161 tranches, le
    // seuil de visibilité étant 1 pixel physique = 0,333 pt à 3x :
    //     lacet total    14°      34°      49° (butée du doigt)
    //     N = 3        0,297    1,564    2,828  ← la v4 créneautait dès 20°
    //     N = 6        0,048    0,266    0,705
    // Le coût (+3 sdRound, ~+45 ALU) ne tombe QUE dans la branche de
    // proximité : la sortie anticipée élimine déjà 80 % de l'écran.
    float dSil = 1e9;
    float2 pF = float2(0.0), pM = float2(0.0);
    for (int k = 0; k < 6; k++) {
        float s = float(k) * 0.2;                  // 0 = face avant, 1 = arrière
        float sc = mix(1.0, PERSP, s);             // s = 0 → sc = 1 : la face
                                                   // avant est BIT-IDENTIQUE
        float2 q = pC / sc - Ez * (hD * (1.0 - 2.0 * s));
        float2 pk = float2(dot(iR0, q), dot(iR1, q));
        dSil = min(dSil, lmSdRound(pk, b, rc) * sc);
        if (k == 0) pF = pk;
        if (k == 2) pM = pk;                       // l'abscisse du filet
    }
    float dF = lmSdRound(pF, b, rc);

    // Coutures plus sèches : 1,5 pt de fondu peignaient un dégradé là où il
    // faut une ARÊTE, et les deux se noyaient l'un dans l'autre. 1,1 pt =
    // 3,3 px à 3x, encore trois échantillons d'antialiasing.
    float faceMask = smoothstep(0.5, -0.6, dF);
    float bodyCov = smoothstep(0.60, -0.60, dSil);
    float flankMask = bodyCov * (1.0 - faceMask);

    // LA source unique de toute la scène : une softbox large en haut-gauche.
    // C'est elle qui explique À LA FOIS le socle et les lustres de la face,
    // le trait d'arête, la rasance de la tranche, l'assise du filet et le
    // lobe haut-gauche du halo. REMONTÉE ICI (elle était ligne 356) parce
    // que le verre dépoli en a besoin bien avant la face.
    const float2 KEY = float2(-0.5299, -0.8480);

    // ---- Le croissant, lu dans la SDF pré-calculée. R prioritaire tant
    // qu'il ne sature pas ; hors texture, prolongement analytique — le clamp
    // seul étalerait le canal G en croix.
    float padding = sdfRanges.x, tightR = sdfRanges.y, wideR = sdfRanges.z;
    float ucToPt = moonPlace.z * 2.0 * faceR;
    float2 uv = (pF / (2.0 * faceR) + 0.5 - moonPlace.xy)
                / (padding * moonPlace.z) + 0.5;
    float2 uvc = clamp(uv, 0.0, 1.0);
    half4 msdf = moonSDF.sample(kFace, uvc);
    float dOutUc = length(uv - uvc) * padding;
    float dT = (float(msdf.r) - 0.5) * 2.0 * tightR;
    float dW = (float(msdf.g) - 0.5) * 2.0 * wideR;
    // Fondu R→G au lieu d'une bascule sèche : la bascule tombait à
    // 0,98·0,125 uc = 13,22 pt et l'enfoncement maximal du croissant vaut
    // 12,55 pt — 0,67 pt de marge seulement, et les deux canaux ne
    // quantifient pas au même pas (0,106 pt contre 0,635 pt), donc un pixel
    // qui basculait sautait de ~0,6 pt. Deux instructions, zéro mouchetures.
    float mixW = smoothstep(0.86, 0.98, fabs(dT) / tightR);
    float dPt = (mix(dT, dW, mixW) + dOutUc) * ucToPt;
    float dAbs = fabs(dPt);
    float dIn = max(-dPt, 0.0);                 // profondeur DANS le croissant

    // Le tube n'est pas uniforme : des accents fbm par abscisse, à dérive
    // sinusoïdale, plancher 0,78 — un néon inégal, jamais interrompu.
    float2 drTube = float2(2.9 * sin(PH * 2.0 * t + 0.4),
                           2.3 * cos(PH * 3.0 * t + 1.9));
    float accTube = lmFbm(uv * 5.0 + drTube);
    float tubeMod = 0.78 + 0.44 * accTube * accTube;
    // Un point de DÉPOLI intègre la lumière sur une longue portion de tube :
    // il ne peut pas suivre l'inégalité du néon au point près, sinon le
    // remplissage clignote par plaques EN MÊME TEMPS que le tube — et on
    // retombe sur le scintillement synchronisé que la maison refuse.
    float glassMod = 1.0 + 0.55 * (tubeMod - 1.0);

    // LE TUBE : 2,25 pt à mi-hauteur = 1,48 % de la face de 152 pt (la fiche
    // demande 1,5 % ; la v4 mesurait 3,64 pt = 2,39 %, c'est LITTÉRALEMENT
    // « l'épaisseur du logo » de la designer). Le 8,5 NE BOUGE PAS : c'est
    // l'écrêtage filmique qui FABRIQUE le blanc, pas une couleur peinte —
    // vérifié au gain MINIMUM (tubeMod 0,80 × breath·flick 0,843) : le cœur
    // sort encore 253/253/253, il ne vire jamais au jaune délavé.
    float coreG = exp(-dPt * dPt / (0.82 * 0.82));
    float flankG = exp(-dAbs / 1.15);
    // 3,4 et non 8,5 : LE PIÈGE DU FILMIQUE. À énergie élevée, 1-exp(-1.35·E)
    // écrête TOUS les canaux, donc toute couleur devient blanche quelle que
    // soit sa teinte — à 8,5 même un orange pur sortait 250/246/234, soit
    // 10 273 pixels quasi blancs et 0,06 de saturation. Tant que le tube
    // portait seul le blanc, il fallait cette énergie ; maintenant que le FIL
    // DE PLASMA s'en charge, le tube peut redescendre et rester DORÉ. Mesure
    // à l'envers pour la cible (255, 165, 60) : E = (3,4 ; 0,92 ; 0,24).
    float tubeE = (3.4 * coreG + 0.34 * flankG) * tubeMod * neonGain;
    // La couleur suit l'ÉNERGIE, pas la géométrie : les seuils se recalent
    // tout seuls sur le tube rétréci (le blanc démarre à |dPt| = 0,79 pt).
    // La rampe vers le blanc est SUPPRIMÉE. C'est elle qui délavait le tube :
    // elle éclaircissait la couleur au moment précis où le filmique
    // l'écrêtait déjà, et les deux effets se cumulaient. Le tube reste dans
    // la famille orange→or sur toute sa course ; le blanc n'appartient plus
    // qu'au fil de plasma, ce qui EST la structure de la référence — une
    // paroi dorée, un cœur blanc.
    float3 tubeC = mix(float3(1.00, 0.30, 0.045), float3(1.00, 0.45, 0.135),
                       smoothstep(0.6, 2.4, tubeE));
    tubeC *= float3(1.0, 1.0 + 0.015 * tempo, 1.0 + 0.030 * tempo);

    // ---- LE FIL DE PLASMA : le DOUBLET. C'est ce que montre la référence et
    // qu'un tube simple ne peut pas produire — dans un vrai néon, le gaz qui
    // brille est plus ÉTROIT que le verre qui le contient. On lit donc, de
    // l'extérieur vers l'intérieur : l'arête du verre, un court retrait plus
    // sombre, un fil très fin et plus blanc, puis le dépoli. Ce n'est pas
    // « plus de lumière » : c'est une DISCONTINUITÉ DE PLUS, et c'est elle
    // qui fait lire un objet à trois couches au lieu d'un trait qui s'élargit.
    //
    // Le fil vit à 2,10 pt DEDANS, donc il s'éteint tout seul là où le
    // croissant est plus mince que ça — la pointe de la queue se pince
    // exactement comme sur la photo, sans le moindre cas particulier.
    // Sigma 0,34 pt = 0,57 pt à mi-hauteur = 1,7 px à 3x : le demi-pixel
    // demandé. Une gaussienne, jamais un step : rien à anticréneler.
    //
    // Il porte SA PROPRE inégalité, à une autre échelle et une autre dérive
    // que celle du tube : le gaz vit dans un verre immobile. Deux champs
    // synchronisés auraient refait un seul trait, simplement plus épais.
    float2 drFil = float2(3.7 * sin(PH * 3.0 * t + 1.7),
                          2.9 * cos(PH * 2.0 * t + 0.3));
    float accFil = lmFbm(uv * 7.0 + drFil);
    // Plancher 0,58 : le plasma d'un néon hésite, il ne se coupe jamais.
    float filMod = 0.58 + 0.80 * accFil * accFil;
    float filD = dIn - 2.10;
    float filE = 4.2 * exp(-filD * filD / (0.34 * 0.34)) * filMod * neonGain;
    // Plus BLANC que l'arête : c'est le cœur, pas la paroi.
    float3 filC = float3(1.00, 0.93, 0.82);

    // ---- LE VERRE DÉPOLI : QUATRE CHAMPS SÉPARÉS. Un seul champ ne peut
    // pas porter à la fois la COUVERTURE (où est le verre) et le MODELÉ
    // (comment il est éclairé) — c'est ce mélange qui donnait la nappe.
    float glassCov = smoothstep(0.35, -1.25, dPt);          // couverture pure
    float glassE = 0.0;
    float3 glassC = float3(0.0);
    if (glassCov > 0.0) {
        // Le grain du DÉPOLI : la troisième chose qui empêche la nappe. uv
        // couvre 161,9 pt, donc 18 cycles/uv = 0,111 c/pt pour l'octave de
        // base ; lmFbm empile 4 octaves à 2,03 → la plus fine est à 0,93 c/pt,
        // 26 % SOUS la limite maison de 1,25. Dérive sinusoïdale à k = 5 et 4
        // (entiers) : le grain rampe sans scintiller et boucle exactement.
        float2 drFrost = float2(1.7 * sin(PH * 5.0 * t + 2.2),
                                1.3 * cos(PH * 4.0 * t + 0.5));
        float frost = 0.93 + 0.14 * lmFbm(uv * 18.0 + drFrost);
        // Le rétroéclairage PAR LE TUBE : 3,40 pt de longueur → 1,00 au
        // contour, 0,532 à 12,55 pt (l'enfoncement maximal du croissant vaut
        // 0,1163 uc = 12,55 pt : tout le modelé tient dans cette course).
        float edgeLit = 0.52 + 0.48 * exp(-dIn / 3.40);
        // La SOFTBOX qui traverse le dépoli — le « plus clair près du tube
        // HAUT-GAUCHE » de la fiche. Dénominateur 0,95·faceR pour que le
        // clamp ne se déclenche jamais sur le croissant.
        float keyRamp = 1.0 + 0.18 * clamp(dot(pF, KEY) / (faceR * 0.95), -1.0, 1.0);
        // LE CREUX, « la signature tube de verre posé sur la matière » : une
        // gaussienne NÉGATIVE de 1,63 pt à mi-hauteur centrée à 1,95 pt du
        // contour — 0,8 pt au-delà de la demi-largeur du tube, elle mord donc
        // pile à la jonction et nulle part ailleurs.
        // Le creux se REPLACE : à 1,95 pt il s'étalait de 1,0 à 2,9 pt et
        // avalait le fil de plasma qui vit à 2,10. Il doit être le RETRAIT
        // ENTRE l'arête et le fil, donc plus près du bord et plus serré.
        float groove = 1.0 - 0.42 * exp(-(dIn - 1.15) * (dIn - 1.15) / (0.55 * 0.55));
        // L'amplitude 0,82 sort d'une INVERSION EXACTE de la chaîne
        // (c1 = (c2+√(c2²+0,034c2))/2 puis E = −ln(1−c1)/1,35), balayée sur
        // l'histogramme RÉEL des profondeurs : ventre L = 105,5, 100 % des
        // pixels dans la fenêtre 90-115 de la fiche.
        glassE = 0.82 * glassCov * edgeLit * keyRamp * groove * frost
                      * glassMod * neonGain;
        // Beer-Lambert : contre le tube le trajet dans le verre est court et
        // la couleur reste CRÉMEUSE ; au fond du ventre le trajet est long,
        // le bleu est absorbé, on redescend vers l'ambre. (1,00/0,46/0,13)
        // était la couleur d'un FLANC de néon, pas d'un verre : un dépoli
        // diffuse la lumière du cœur BLANC, il est bien plus clair en G et B.
        glassC = mix(float3(1.00, 0.56, 0.22), float3(1.00, 0.78, 0.54), edgeLit);
    }
    float glassA = 0.62 * glassCov;             // l'opacité du dépoli

    // Le bloom écran (du glare d'objectif : il ne tourne pas avec l'objet) :
    // exp serré + Moffat FENÊTRÉ.
    // LA CORRECTION CAPITALE : un glare est la convolution d'une source
    // LINÉIQUE par une PSF — il est SYMÉTRIQUE autour du tracé, il ne peut
    // pas être constant d'un côté. max(dPt,0) le figeait à 0,31·tubeMod sur
    // TOUT l'intérieur du croissant : 44 % de l'énergie du ventre,
    // parfaitement plate et teintée (1,00/0,52/0,18). Avec fabs, à 12,5 pt
    // de profondeur le bloom tombe de 0,310 à 0,073 (−76 %) et la place est
    // libérée pour un verre MODELÉ. Dehors, fabs(dPt) == max(dPt,0) : le
    // halo extérieur ne bouge pas d'un LSB.
    float dp = dAbs;
    float dm16 = dp / 16.0;
    float bloomE = (0.20 * exp(-dp / (7.0 * bloomWiden))
                  + 0.11 * pow(1.0 + dm16 * dm16, -1.8)
                         * exp(-dp / (34.0 * bloomWiden)))
                 * tubeMod * neonGain;
    // `fringe` SUPPRIMÉ : il mélangeait vers (0,86/0,70/0,58), un chaud
    // DÉSATURÉ, précisément dans la plage 5-8/255 — c'était le seul
    // générateur de BRUN du fichier. Le toe c²/(c+0,0085) est déjà un
    // amplificateur de saturation à bas niveau (G/R sort à 0,373 pour
    // E=0,052 et 0,275 pour E=0,010, à teinte d'entrée constante) : une
    // lueur chaude qui s'éteint devient plus saturée, JAMAIS grise. La
    // désaturation était contre-productive.
    const float3 bloomCol = float3(1.00, 0.50, 0.16);

    // ---- Le spill dans le verni, et LE FANTÔME SPÉCULAIRE.
    float spillWash = 0.0, specNeon = 0.0;
    if (faceMask > 0.0) {
        const float2 POLISH = float2(0.9272, -0.3746);      // l'axe de satiné
        float uvPerPt = 1.0 / (2.0 * faceR * padding * moonPlace.z);   // 1/161,9
        float2 aUV = POLISH * (7.0 * uvPerPt);
        // MIN et non MOYENNE : le min de distances décalées EST, par
        // définition, la distance à la forme DILATÉE par le segment qui
        // joint les taps — l'isoligne s'ALLONGE de 14 pt le long de l'axe de
        // polissage. Une MOYENNE de distances ne fait que déplacer
        // l'isoligne de 2,5 pt : elle ne fabrique aucun étirement. C'est ce
        // qui rend le reflet ANAMORPHIQUE au lieu d'isotrope — un halo
        // isotrope autour d'un tube posé sur une laque est le tell n°1 du
        // rendu amateur.
        float gm = min(float(msdf.g),
                   min(float(moonSDF.sample(kFace, clamp(uv + aUV, 0.0, 1.0)).g),
                       float(moonSDF.sample(kFace, clamp(uv - aUV, 0.0, 1.0)).g)));
        // fabs : même faute que le bloom, même remède. max(dS,0) figeait le
        // spill à 0,195 sous TOUT le croissant — 39 % de l'énergie du ventre.
        float dS = fabs(((gm - 0.5) * 2.0 * wideR + dOutUc) * ucToPt);
        // La queue large descend de 0,045/46 pt à 0,030/38 pt : c'est elle
        // qui posait un voile chaud sur TOUTE la face et empêchait la laque
        // de retomber sous les 12/255 de la fiche loin du croissant.
        spillWash = (0.150 * exp(-dS / 11.0)
                   + 0.030 * exp(-dS / 38.0)) * neonGain;

        // LE REFLET NÉON SPÉCULAIRE — « il manque le reflet néon dans le
        // logo », « il manque l'effet néon spéculaire ». Une laque, c'est un
        // verni transparent sur du noir : le tube s'y MIRE. Le double se
        // déplace le long de la projection du rayon de vue dans le plan de la
        // face — direction −M⁻¹(Ez) ≈ (−0,969, −0,246), et NON KEY : c'est de
        // la réflexion, pas de la diffusion. CONSÉQUENCE MAJEURE : quand le
        // doigt tourne le pavé, le reflet S'ÉCARTE du tube (7,5 pt au repos,
        // 14,6 pt à la butée) — aucun autre indice ne vend le verni aussi
        // fort. Il est volontairement POUSSÉ DEHORS et ÉTALÉ (7,7 pt à
        // mi-hauteur) : à sa longueur physique de 2,8 pt il collerait au tube
        // et l'ÉPAISSIRAIT — exactement le reproche n°1.
        float2 ezL = float2(dot(iR0, Ez), dot(iR1, Ez));
        float2 mirD = ezL * (-1.0 / max(length(ezL), 1e-3));   // garde : Ez → 0 si yaw et pitch nuls
        float mirLen = 4.0 + 14.0 * length(float2(syw, spt));
        float2 uvm = uv + mirD * (mirLen * uvPerPt);
        float2 uvmc = clamp(uvm, 0.0, 1.0);
        float dMir = ((float(moonSDF.sample(kFace, uvmc).g) - 0.5) * 2.0 * wideR
                      + length(uvm - uvmc) * padding) * ucToPt;
        specNeon = (0.115 * exp(-dMir * dMir / (4.6 * 4.6))
                  + 0.030 * exp(-fabs(dMir) / 13.0))
                 * smoothstep(-0.5, 2.5, dPt)     // DEHORS du croissant seulement :
                 * neonGain;                      // la fenêtre 90-115 reste propre
    }

    // ---- La normale 2D du contour (différences finies) : partage
    // dessus/flanc, chanfrein, éclairage d'arête.
    float2 nF = float2(0.0, -1.0);
    if (dSil < 8.0) {
        float e = 0.75;
        float2 grad = float2(
            lmSdRound(pF + float2(e, 0.0), b, rc) - lmSdRound(pF - float2(e, 0.0), b, rc),
            lmSdRound(pF + float2(0.0, e), b, rc) - lmSdRound(pF - float2(0.0, e), b, rc));
        nF = grad / max(length(grad), 1e-4);
    }
    // ---- La face : une LAQUE. Une seule rampe alignée sur la softbox, DEUX
    // LUSTRES étroits qui glissent en sens inverse de la rotation, un satiné
    // résiduel, un Fresnel COURT — et par-dessus, le verre dépoli du
    // croissant POSÉ (jamais additionné).
    float3 faceCol = float3(0.0);
    if (faceMask > 0.0) {
        // UNE rampe, dans l'axe de la lumière. Deux mix séparables sur ux et
        // uy fabriquaient un gradient bilinéaire dont les isovaleurs sont des
        // hyperboles : l'œil n'y lit pas une source. Le facteur 2,756·faceR
        // n'est pas arbitraire — |dot(pF,KEY)| vaut exactement
        // faceR·(|KEY.x|+|KEY.y|) = 104,7 aux deux coins de la diagonale,
        // donc kA sort pile dans [0,1] sans clamp perdu.
        float kA = saturate(0.5 - dot(pF, KEY) / (2.756 * faceR));
        float kS = kA * kA * (3.0 - 2.0 * kA);
        float base = mix(0.0310, 0.0090, kS);      // 8,7/255 → 1,8/255 (v4 : 5,5 → 1,2)
        // DEUX LUSTRES, pas un nuage. 0,34 en unités g valait 25,8 pt
        // d'e-fold, soit ~78 pt visibles : la MOITIÉ de la face couverte
        // d'une écharpe diffuse — la « bande grise » de la v2 revenue par la
        // porte de la LARGEUR. 0,15 → 11,4 pt d'e-fold, 19 pt à mi-hauteur.
        // Ils GLISSENT toujours en sens inverse du lacet : c'est ça, le verni.
        float ca = 0.8480, sa = -0.5299;
        float2 g = float2(pF.x * ca - pF.y * sa, pF.x * sa + pF.y * ca) / faceR;
        float slide = -yaw * 1.35 + 0.055 * sin(PH * 13.0 * t + 0.9);
        float dA = (g.y + 0.44 + slide) / 0.150;
        float dB2 = (g.y - 0.58 + slide * 0.72) / 0.075;
        float sheen = 0.050 * exp(-dA * dA) + 0.020 * exp(-dB2 * dB2);
        // Amplitude du principal réduite de 44 % : un trait étroit paraît
        // plus lumineux qu'une nappe à énergie égale.
        float2 gs = float2(pF.x * ca - pF.y * sa, pF.x * sa + pF.y * ca);
        float satin = lmNoise(float2(gs.x * 0.030, gs.y * 1.05)) - 0.5;
        sheen *= max(0.0, 1.0 + satin * 0.10);     // ±5 % : le lustre est fin
        // Fresnel RACCOURCI : 16 pt de portée peignaient un halo à
        // l'INTÉRIEUR du bord sur 16 pt (mesuré 29/255 en x = −66..−60 alors
        // que la face au centre est à 8). Ce halo + le chant gris, ce sont
        // les 30 pt qui font lire « cadre ». 7 pt : la laque va jusqu'à
        // l'arête, elle redevient noire à 7 pt du bord.
        float facing = max(dot(nF, KEY), 0.0);
        float rimUp = saturate(-dF / 7.0);
        float fres = pow(1.0 - rimUp, 3.2) * 0.048 * facing;
        // Le bombé du verni doublonne maintenant avec areteCol, qui vit à
        // cheval sur dF = 0 : le maintenir à 5,5 pt / 0,115 empilerait deux
        // hautes lumières sur le même bord et REDONNERAIT de l'épaisseur.
        // 3,2 pt : il rentre SOUS le trait d'arête au lieu de le déborder.
        float bulge = saturate((-dF) / 3.2);
        float lobe = pow(1.0 - bulge, 2.0) * pow(facing, 3.0) * 0.085;
        // LA GARANTIE ANTI-GRIS : on SÉPARE la matière de la lumière. Tout
        // multiplier par (0,955/0,978/1,045) rendait le noir BLEUTÉ — un noir
        // neutre-froid sous une nappe neutre-froide, par définition, c'est du
        // gris (mesuré R/B = 1,14). Ici la MATIÈRE noire est chaude (c'est le
        // rebond de la flaque orange, R:B = 1,39) et la LUMIÈRE est à peine
        // tiède (la softbox). Aucun pixel de face ne peut plus être neutre.
        faceCol = base                  * float3(1.00, 0.86, 0.72)
                + (sheen + fres + lobe) * float3(1.00, 0.97, 0.95)
                + spillWash             * float3(1.00, 0.54, 0.22)
                + specNeon              * float3(1.00, 0.66, 0.34);
        // LE VERRE EST UNE DALLE TRANSLUCIDE POSÉE SUR LA LAQUE, il ne s'y
        // AJOUTE PAS : E = E_laque·(1−alpha) + C_verre·E_verre. La matière
        // multiplie la lumière — et l'additif est exactement ce qui donnait
        // le « papier calque posé par-dessus ». 38 % de laque restent
        // visibles À TRAVERS le dépoli : le lustre, le satiné et le Fresnel
        // TRAVERSENT le croissant au lieu de s'arrêter à son bord.
        faceCol = faceCol * (1.0 - glassA) + glassC * glassE;
    }

    // ---- LA TRANCHE : une ÉPAISSEUR ÉCLAIRÉE, plus jamais un fossé.
    // Mesuré sur la v4 : 10/255 devant, 4/255 derrière, sous une face à
    // 29/255 et un liseré à 17 — trois lignes parallèles, donc un CADRE.
    // C'est la LUMINANCE qui lit l'épaisseur, pas la largeur : la tranche
    // doit rester partout AU-DESSUS de la laque plate (10,6/255).
    float3 flankCol = float3(0.0);
    if (flankMask > 0.0) {
        // L'épaisseur LOCALE exacte : dF est la distance à l'arête, −dSil la
        // distance au bord extérieur ; leur somme EST le chant le long de la
        // normale, y compris là où la perspective le pince dans les coins.
        // L'ancienne constante globale (16,07 pt) écrasait le dégradé partout
        // où le chant est plus étroit — les coins restaient bloqués au niveau
        // du bord arrière. Plancher 0,75 pt : pas de division par zéro à la
        // pointe des coins, et pas de saut d'un pixel à l'autre.
        float thick = max(dF - dSil, 0.75);
        float sD = saturate(dF / thick);          // 0 = arête avant, 1 = bord extérieur
        // DU MÉTAL NOIR OÙ GLISSE UN REFLET, pas un aplat brun. Le brun
        // uniforme lisait « carton peint » : un chant, c'est une surface
        // presque noire sur laquelle COURT l'image d'une source. C'est le
        // reflet qui fabrique la matière, jamais la teinte de fond — et le
        // fond doit rester noir pour que le reflet ait quelque chose à
        // trancher. On avait corrigé « la tranche est un fossé » en la
        // peignant en brun ; la vraie réponse était de l'éclairer, pas de la
        // teinter.
        float base = 0.014 * (1.0 - 0.42 * sD);
        // LE REFLET : une bande spéculaire étroite dont la hauteur sur le
        // chant DÉPEND DU LACET. Quand le doigt tourne l'objet, elle balaie
        // la tranche — c'est ce balayage qui prouve que la surface est
        // réfléchissante et non peinte. Sinus du lacet : le reflet revient,
        // il ne file pas à l'infini.
        float mPos = 0.36 + 0.30 * sin(yaw * 2.1) + 0.045 * sin(PH * 13.0 * t + 0.9);
        float md = (sD - mPos) / 0.150;
        // Une pièce a PLUSIEURS sources : une seule bande relit encore comme
        // un aplat rayé. La seconde est plus faible, plus fine, plus loin.
        float md2 = (sD - mPos - 0.40) / 0.085;
        float mirror = exp(-md * md) + 0.30 * exp(-md2 * md2);
        // Le chant GAUCHE reçoit la softbox en RASANCE : c'est lui qui porte
        // le reflet, le haut n'en attrape qu'un filet.
        float graz = pow(saturate(-nF.x), 1.3);
        float spec = mirror * (0.040 + 0.150 * graz + 0.055 * saturate(-nF.y));
        // Le grain reste : 1,6·faceR = 0,22 cycle/pt, 5,7× sous la limite.
        float chant = lmNoise(float2(lmArc(pM, b, rc) * 1.6 * faceR, sD * 2.2)) - 0.5;
        spec *= max(0.0, 1.0 + chant * 0.22);
        // BICHROME comme l'arête : le reflet est BLANC (le studio) ; la
        // chaleur n'apparaît que là où le néon peut réellement l'atteindre,
        // c'est-à-dire par le bas et près du croissant.
        float warmF = saturate(0.05 + 0.80 * pow(saturate(nF.y), 3.0) + 1.7 * bloomE);
        float3 cRefl = mix(float3(0.88, 0.94, 1.06), float3(1.00, 0.56, 0.22), warmF);
        flankCol = float3(base) * float3(0.95, 0.97, 1.06) + cRefl * spec;
    }

    // ---- L'ARÊTE : le trait clair qui SÉPARE le chant de la face. C'est
    // l'élément le plus explicitement demandé par la référence et le seul
    // TOTALEMENT absent : entre le chant (11/9/7) et la face (29/23/20) il
    // n'y avait qu'une marche de 18 niveaux produite par le Fresnel. Sans ce
    // trait, la tranche et la face sont la même substance et l'épaisseur ne
    // se lit pas. C'est un reflet de SOFTBOX sur le chanfrein : `ignite` et
    // non `neonGain` — il ne respire pas avec le tube.
    float3 areteCol = float3(0.0);
    if (fabs(dF) < 2.6 && bodyCov > 0.0) {
        // LA PORTE : (dF − dSil) EST l'épaisseur de chant restante. Elle vaut
        // 12,4 pt à gauche, 1,4 en haut, et 0 sur les bords DROIT et BAS où
        // dSil ≡ dF — aucun trait parasite là où la référence n'en a pas, et
        // elle se pince toute seule dans les coins avec la perspective.
        // Aucun produit scalaire avec Ez n'est nécessaire : la géométrie se
        // porte elle-même.
        float hasFlank = saturate((dF - dSil) / 2.0);
        float facingA = max(dot(nF, KEY), 0.0);
        float aAmp = 0.76 * hasFlank * (0.25 + 0.75 * pow(facingA, 1.4));
        float aLine = exp(-dF * dF / (0.70 * 0.70));   // 1,17 pt à mi-hauteur = 3,5 px @3x
        areteCol = float3(1.00, 0.72, 0.44) * (aLine * aAmp * ignite);
        // → coin HG (161, 131, 91), arête verticale gauche (109, 94, 70) :
        //   une marche NETTE entre le chant à 60/255 et la face à 30/255.
    }

    // ---- LE BISEAU. La V4 avait un bord LARGE et doux : il lisait comme un
    // chanfrein, une matière qui tourne. La v5 l'a réduit à un filet net pour
    // tuer la bande morte — et a jeté la douceur avec l'eau du bain. La
    // référence a les DEUX : un filet FIN posé sur un dégradé de quelques
    // points. La règle qui évite de refabriquer le cadre : ce terme AJOUTE
    // toujours de la lumière, il n'en retire jamais. Une tombée d'arête
    // (mix vers 0,78) creusait un fossé plus sombre que la face ; un biseau
    // qui s'allume, lui, arrondit le bord au lieu de l'encadrer.
    float3 bevelCol = float3(0.0);
    if (faceMask > 0.0 && dF > -8.0) {
        float bv = exp(-max(-dF, 0.0) / 2.7);
        float bAmp = 0.058 * bv * (0.22 + 0.78 * saturate(dot(nF, KEY)));
        // Bichrome lui aussi, pour la même raison que le filet.
        float bWarm = saturate(0.10 + 2.4 * bloomE + 0.55 * saturate(nF.y));
        bevelCol = mix(float3(0.86, 0.93, 1.06), float3(1.00, 0.52, 0.18), bWarm)
                 * (bAmp * faceMask);
    }

    // ---- LE FILET : 1 pt, orange, avec un point chaud qui VOYAGE le long
    // du périmètre. Sigma 0,55 pt → 1,3 pt à mi-hauteur : un trait, pas un
    // liseré. Le point chaud est un reflet : quand le doigt tourne l'objet,
    // il se déplace le long de l'arête (décalage d'abscisse par le lacet).
    float3 rimCol = float3(0.0);
    if (fabs(dSil) < 7.0) {
        float s01 = lmArc(pM, b, rc);
        // La base du filet : la softbox sur le chanfrein — vive en
        // haut-gauche, éteinte en bas-droite, jamais coupée (plancher 0,12).
        // Une softbox LARGE ne fait pas un lobe en cos². Le carré écrasait
        // l'arête verticale gauche (seat 0,34 contre 0,95 au coin ; mesuré
        // R = 33 contre 87) alors que la référence les veut TOUTES DEUX
        // vives. wrap = 1−(1−fw)² est le lobe d'une source étendue, et sa
        // dérivée est FINIE en 0 : pas de coude au terminateur (ce qu'un
        // pow d'exposant < 1 aurait donné).
        float fw = saturate(dot(nF, KEY));
        float wrap = fw * (2.0 - fw);
        // LE CHANFREIN INFÉRIEUR QUI FUIT : ce n'est PAS un reflet — la
        // softbox est en haut-gauche, dot(nF,KEY) vaut 0 en bas — c'est de
        // la TRANSMISSION, le néon vit DANS la pierre et sort par le bas.
        // C'est elle qui alimente la flaque, et c'est l'écart n°6 de la
        // fiche. Exposant 4 : le bas s'allume, le bas-DROITE reste éteint.
        float leak = pow(saturate(nF.y), 4.0) * (0.55 + 0.45 * saturate(-nF.x));
        // L'ARÊTE ARRIÈRE N'EST PAS UNE SOURCE, C'EST UN MIROIR. Le terme de
        // flanc gauche à 0,30 posait un trait orange continu tout le long du
        // bord arrière : saturé, d'épaisseur constante, il lisait comme un
        // contour DESSINÉ. Une arête vue de trois quarts ne fait que renvoyer
        // ce qu'il y a autour d'elle — et autour, c'est du noir. Elle doit
        // donc être PAUVRE et INÉGALE : 0,12 de socle, et une modulation
        // lente le long de l'abscisse qui la fait respirer au lieu de courir
        // d'un trait. La lumière franche reste au haut-gauche (la softbox) et
        // au bas (la fuite du néon), là où il y a vraiment quelque chose à
        // réfléchir.
        float backBreak = 0.62 + 0.38 * lmNoise(float2(s01 * 9.0, 3.1));
        float seat = 0.055 + 0.50 * wrap
                   + 0.12 * pow(saturate(-nF.x), 1.6) * backBreak
                   + 0.52 * leak;
        // → gauche 0,745 · coin HG 0,664 · haut 0,543 · BAS 0,341 ·
        //   bas-droite 0,126 · droite 0,055 (rapport vif/éteint 13:1)
        // 45 tours par boucle : 900/45 = 20,000 s PILE, k ENTIER, la
        // périodicité 900 s est intacte. 550,6 pt / 20 s = 27,5 pt/s. Le
        // couplage au lacet passe de 0,28 à 0,42 rad⁻¹ : sur la course
        // complète du doigt le reflet glisse de 141 pt le long de l'arête —
        // c'est ce glissement qui prouve qu'on tourne un objet réel.
        float head = (benchSweep >= 0.0) ? benchSweep : fract(t * 45.0 / 900.0
                                                             - yaw * 0.42);
        float ds = s01 - head;
        ds -= floor(ds + 0.5);
        // TROIS étages au lieu de deux : un NOYAU spéculaire (8,3 pt à
        // mi-hauteur, contre 18,3 — un point chaud, pas une tache), un LOBE
        // symétrique (25,7 pt), une TRAÎNÉE derrière seulement (e-fold
        // 24,8 pt). Un reflet qui glisse sur un chanfrein, pas une LED.
        float comet = exp(-ds * ds / (0.0090 * 0.0090))
                    + 0.55 * exp(-ds * ds / (0.028 * 0.028))
                    + 0.30 * exp(-max(-ds, 0.0) / 0.045)
                           * smoothstep(0.006, -0.006, ds);
        // Plancher 0,55 : à 0,35 le point mourait sur toute la moitié droite.
        // Il doit faire le TOUR COMPLET, plus vif au nord-ouest.
        float travel = comet * (0.55 + 0.45 * wrap);
        float lineAmp = seat * 1.62 + travel * 1.20;
        // 0,50 au lieu de 0,55 : au noyau du voyageur l'écrêtage du filmique
        // remonte la mi-hauteur de SORTIE à 1,38 pt ; à 0,55 elle passait à
        // 1,51 pt, hors spec. Au repos elle vaut 1,07 pt. Sigma effectif
        // 0,354 pt = 1,06 px à 3x : pas d'aliasing.
        float line = exp(-dSil * dSil / (0.50 * 0.50)) * lineAmp;
        // La buée est RECALÉE sur la nouvelle échelle (×4,8) : à 1,5 pt et
        // 12 % elle aurait posé 105/255 de jupe autour du pavé — le reproche
        // de départ, en pire.
        float mist = exp(-max(dSil, 0.0) / 1.1) * smoothstep(-0.6, 0.6, dSil)
                   * lineAmp * 0.035;
        // 0,50 en G donnait (207,148,51) : teinte 38°, ambre pâle. 0,42 sort
        // (203,124,36) : teinte 32°, saturation 0,82 — l'orange FRANC de la
        // référence, et toujours au-dessus du seuil de brun (R/G = 1,63).
        // L'ARÊTE EST BICHROME — et c'est LA raison pour laquelle un orange
        // uniforme lisait « faux ». Dans la référence, le tour de l'objet est
        // partagé par DEUX sources de température différente : la softbox du
        // studio, blanche et froide, qui frappe le haut et la droite ; le
        // néon, chaud, qui rebondit sur le biseau à gauche et en bas. Une
        // seule teinte modulée en intensité ne lit pas comme une géométrie
        // ÉCLAIRÉE — elle lit comme un contour DESSINÉ par-dessus l'objet.
        // La chaleur suit donc ce que le néon peut réellement atteindre :
        // le flanc gauche, la fuite du chanfrein bas, et le glare local.
        float warmth = saturate(0.08 + 0.60 * pow(saturate(-nF.x), 1.3)
                                     + 0.80 * leak + 2.2 * bloomE);
        float3 cWarm = mix(float3(0.82, 0.90, 1.06),   // le studio
                           float3(1.00, 0.42, 0.10),   // le néon
                           warmth);
        float3 cHot = float3(1.00, 0.94, 0.86);
        // Seuils recalés sur la nouvelle échelle (max 1,21 au repos, 3,4 au
        // noyau) : le filet au repos reste 100 % ORANGE et SEUL le noyau du
        // voyageur blanchit. À 0,55/1,30 tout l'arc aurait viré au blanc.
        rimCol = mix(cWarm, cHot, smoothstep(1.60, 3.10, line)) * (line + mist)
                 * neonGain;
    }

    // ---- LES DEUX RAIES ANAMORPHIQUES et L'ÉTOILE. La fiche : « deux raies
    // parallèles diagonales, la principale vive, la seconde discrète ; une
    // étoile fleurit au croisement de l'arête GAUCHE ».
    float4 sq = lmStreak(pC, faceR);       // .x principale .y fantôme
                                           // .z abscisse   .w travers
    // L'ÉTOILE : UN SEUL croisement. Avec le nouveau décalage, l'abscisse
    // vaut −62,3 au croisement de l'arête GAUCHE (à (−77,8 ; −10,1), le
    // tiers supérieur du bord vertical) et +67,7 au croisement de l'arête
    // HAUTE : la porte sépare proprement les deux. La v4 fleurissait aux
    // deux — deux étoiles, aucune au bon endroit.
    // Et elles s'effacent : 0,32 → 0,21. Une raie d'objectif est un ARTEFACT,
    // elle ne doit jamais rivaliser avec le sujet qui la produit.
    float3 streakCol = float3(1.00, 0.72, 0.34) * ((0.21 * sq.x + 0.070 * sq.y) * neonGain);
    if (fabs(dSil) < 12.0) {
        float aN = sq.z / 68.0;
        float env1 = exp(-aN * aN) + 0.08 * exp(-fabs(sq.z) / 40.0);
        float core1 = exp(-sq.w * sq.w / (0.80 * 0.80));
        float leftGate = smoothstep(10.0, -35.0, sq.z)
                       * smoothstep(0.05, -0.35, nF.x);   // normale tournée à gauche
        float onEdge = exp(-dSil * dSil / (3.2 * 3.2));
        // Deux couches, SANS aigrette (interdite maison) : un PIP à E = 2,9
        // → (253, 250, 215), un blanc FABRIQUÉ par le filmique dans un disque
        // de 3 pt ; plus une BOUFFÉE ronde de ~12 pt. Les deux « branches »
        // de l'étoile ne sont pas peintes, elles sont HÉRITÉES — la raie
        // fournit la diagonale, le liseré de l'arête fournit la verticale.
        // C'est comme ça qu'une étoile de studio se forme.
        float starPip = core1 * env1 * onEdge * leftGate * 3.40;
        float starBlm = exp(-dSil * dSil / (9.0 * 9.0))
                      * exp(-sq.w * sq.w / (9.0 * 9.0)) * leftGate * 0.55;
        streakCol += float3(1.00, 0.72, 0.34) * ((starPip + starBlm) * neonGain);
    }

    // ---- LE SOL. Un sol éclairé par une source-ligne POSÉE DESSUS décroît
    // de façon MONOTONE À PARTIR de la ligne de contact : profil exponentiel
    // ancré sur yBase, jamais une gaussienne centrée 27 pt plus bas (une
    // gaussienne centrée sous le pied NE PEUT PAS toucher le pied).
    // yBase = faceR·1,045 = 79,4 pt : la base mesurée sur la capture.
    float yBase = faceR * 1.045;
    float dy = pC.y - yBase;                          // > 0 = sous l'objet
    float px = pC.x - faceR * 0.06;
    float poolX = exp(-(px * px) / (faceR * 1.15 * faceR * 1.15));
    float poolY = exp(-max(dy, 0.0) / (faceR * 0.30)) // e-fold 22,8 pt
                * smoothstep(-7.0, 4.0, dy);
    float pool = poolX * poolY;
    // L'OMBRE DE CONTACT a l'échelle du JEU entre l'objet et le sol (3,2 pt
    // de sigma), PAS l'échelle de l'objet : l'ancienne (sigma_y 16 pt contre
    // 20 pt pour la flaque) mangeait la moitié de la lumière, d'où le trou
    // de 25 pt. On la sépare de l'occlusion ambiante LARGE, décalée à
    // l'opposé de la softbox, qui module la forme sans jamais la couper.
    // Plancher 0,06 : une ombre de contact sur un sol éclairé n'est pas noire.
    float cl = dy / 4.5;
    float ctLine = exp(-cl * cl);
    float sx = pC.x - faceR * 0.22;
    float ctWide = exp(-(sx * sx) / (faceR * 0.85 * faceR * 0.85)
                       - (max(dy, 0.0) * max(dy, 0.0)) / (faceR * 0.22 * faceR * 0.22));
    float occl = max(1.0 - 0.62 * ctLine - 0.30 * ctWide, 0.06);
    // 0,075 donnait 22/255 en théorie, 14,5 mesurés — et 36 pt trop bas.
    // 0,26 avec la nouvelle géométrie : 4,5/255 SUR la ligne de pose, 35 à
    // 5 pt, 38 au pic (12 pt), 25 à 25, 10 à 45, 2,7 à 70. C'est la
    // PROXIMITÉ du pic qui prouve la pose, pas la profondeur de l'ombre.
    // Teinte (1,00/0,46/0,14) → sortie (38, 18, 5) : saturation 0,87,
    // teinte 23°. Le caramel naît d'une luminance moyenne à saturation
    // BASSE : à B/R = 0,13 c'est de la lumière renversée, pas une nappe.
    float3 poolCol = float3(1.00, 0.46, 0.14) * (pool * occl * 0.26 * neonGain);

    // ---- LE HALO D'AMBIANCE — « il manque les ombres ». Mesuré sur la v4 :
    // anneau 85-100 pt à 0,42/0,37/0,36, et la médiane ne bouge pas de
    // 0,4/255 entre 85 et 310 pt. L'objet est découpé aux ciseaux sur du noir.
    // Profil MOFFAT FENÊTRÉ, pas exp pur : le Moffat (1+r²/a²)^−β est le
    // profil de voile de verre d'un objectif — pas de genou, donc pas
    // d'anneau visible. La fenêtre exp(−r/170) est OBLIGATOIRE : une queue
    // de Moffat non fenêtrée EST la nappe de caramel que la maison refuse.
    // ANCRÉ SUR LA SILHOUETTE, pas sur le croissant : c'est la lumière de
    // l'objet qui s'échappe par ses arêtes, elle doit épouser son contour.
    float dOut = max(dSil, 0.0);
    float2 uOut = pC / max(rC, 1e-3);
    float mA = dOut / 26.0;
    float haloR = pow(1.0 + mA * mA, -0.85) * exp(-dOut / 170.0);
    // Un halo UNIFORME lirait « ombre portée d'autocollant ». 0,80 vers la
    // softbox, 0,86 vers le bas (le chanfrein qui nourrit la flaque), 0,34 à
    // droite. Le facteur occl ferme la boucle : la MÊME occlusion mange le
    // halo et la flaque, donc la ligne de contact est cohérente.
    float angH = 0.34
               + 0.46 * pow(max(dot(uOut, KEY), 0.0), 1.4)
               + 0.52 * pow(max(uOut.y, 0.0), 1.8);
    float haloE = 0.062 * haloR * angH * neonGain
                * mix(1.0, occl, saturate(uOut.y));
    const float3 haloCol = float3(1.00, 0.42, 0.13);
    // Profil : 14,6/255 au ras du liseré | 6,7 à 20 pt | 2,6 à 40 | 0,44 à 80
    // | 0,03 à 150. Aire au-dessus de 8/255 : ~1,5 % du cadre — la métrique
    // « ≥ 95 % des pixels < 8/255 » tient avec 3,5 points de marge.

    // ---- La nuit derrière — ÉTEINTE (cf. STARFIELD en tête de fichier).
    // Le compilateur replie tout ce bloc à zéro ; la fonction lmStars reste
    // référencée, donc aucun avertissement, et le ciel se rallume d'un seul
    // chiffre le jour où un autre hôte en voudra un.
    float star = 0.0;
    if (STARFIELD > 0.0 && bodyCov < 1.0) {
        float starVis = smoothstep(1.5, 3.5, dSil)
                      * (1.0 - 0.55 * saturate(bloomE * 2.0));
        star = lmStars(position + para, t) * starVis * STARFIELD;
    }

    // ---- Composition : le pavé OCCULTE le sol (jamais additionné) ; le
    // filet, le glare, les raies et le halo vivent par-dessus tout.
    // BUG CORRIGÉ : mix(E, body, bodyCov) multiplie DÉJÀ E par (1−bodyCov).
    // Le facteur explicite le faisait une SECONDE fois — la flaque partait en
    // (1−bodyCov)², donc à la lisière du pavé elle ne valait que 25 % au lieu
    // de 50 %. C'était la troisième cause du décollement de l'objet.
    float3 E = star * float3(0.92, 0.95, 1.02) + poolCol;
    // Le voile a disparu : il est DANS faceCol, mélangé à la laque et non
    // ajouté par-dessus. L'arête s'ajoute au corps — elle est déjà fenêtrée
    // par hasFlank et se fera occulter par bodyCov comme le reste.
    float3 body = faceCol * faceMask + flankCol * flankMask + areteCol + bevelCol
                + (tubeC * tubeE + filC * filE) * faceMask;
    E = mix(E, body, bodyCov);
    // Le bloom et les raies restent additionnés APRÈS : un glare d'objectif
    // est DEVANT l'objet, aucun verre ne l'atténue.
    E += rimCol + bloomCol * bloomE + streakCol + haloCol * haloE * (1.0 - bodyCov);
    float3 c = 1.0 - exp(-1.35 * E * exposure);
    c = c * c / (c + 0.0085);
    // Dither : à 1,4 % de luminance il n'y a que 4 niveaux entiers — sans
    // lui la laque et le bloom bandent en escalier sur OLED.
    c += (lmHash21(position * 1.113 + dither2) - 0.5) * (1.6 / 255.0);
    return half4(half3(saturate(c)), 1.0h);
}
