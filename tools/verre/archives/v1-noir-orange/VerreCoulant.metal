#include <metal_stdlib>
using namespace metal;

// MARK: - Le VERRE GONFLÉ — la matière de la carte des séries
//
// Réécrit le 15-08 depuis la référence de Kathryn (userimg-01851 / 01462),
// MESURÉE au pixel (échelle 1,38 px/pt, carte ~360 pt). Le verdict qui a tué
// les versions précédentes : « on dirait du blur, pas de la glass — des
// corner borders dégradés et un halo posé vite fait ». La photo, elle,
// contient HUIT systèmes optiques, tous mesurés par traversées de pixels :
//
//   1. Le flanc GAUCHE n'est pas un trait : une ÉPAULE de ~14 pt à DEUX
//      facettes — trait (173), creux (141), REBOND de seconde facette (169),
//      décroissance lente vers 88. C'est elle qui fait lire « gonflé ».
//   2. Le flanc DROIT est l'inverse : un fil quasi blanc (218) et la lumière
//      qui FLAQUE vers l'intérieur — corps 65 → 112 sur ~19 pt.
//   3. Le bord HAUT est discret au centre (70) et s'allume vers les coins.
//   4. Le coin HAUT-DROIT a une nappe DIAGONALE intérieure (~30-45 sur fond
//      11) qui entre par le coin et meurt en ~90 pt.
//   5. Le quart BAS-DROIT porte une BRUME chaude intérieure (jusqu'à 81,66,53).
//   6. Tout le bas est voilé de SÉPIA (40,28,18) qui monte sur ~20 pt ; la
//      teinte chaude mesurée est un sépia doré (g/r≈0,66, b/r≈0,40), jamais
//      un orange saturé.
//   7. DEHORS : un bloom sépia qui ÉPOUSE le flanc gauche (24→99 sur ~5 pt
//      d'air), une flaque crème sous le coin bas-droit, l'orange sous le
//      bas-gauche, et des RAYONS diagonaux qui traversent l'air.
//   8. Un GRAIN de film sur tout le corps ; le socle n'est pas plat.
//
// L'architecture est celle de l'obsidienne (ObsidianCard.metal, la seule
// matière de la maison calée sur photo) : SDF + champs mesurés + saturation
// PAR CANAL `1 - exp(-E·k)` — l'anti-marron est structurel, les cœurs
// montent d'eux-mêmes à la crème. La vue passe un rectangle PLUS GRAND que
// la carte (marge `pad`) : les blooms et rayons vivent dehors, en alpha.

static float vgHash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

/// Distance signée au rectangle arrondi (négatif dedans), rayon du HAUT et
/// du BAS distincts — l'écrin de la fiche est inégal (55 / 30 ouvert).
static float vgSd(float2 p, float2 b, float rH, float rB) {
    float r = (p.y < 0.0) ? rH : rB;
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Normale sortante (le liseré prend la luminance de SON côté).
static float2 vgNormal(float2 p, float2 b, float rH, float rB) {
    float r = (p.y < 0.0) ? rH : rB;
    float2 s = sign(p);
    float2 q = abs(p) - b + r;
    if (max(q.x, q.y) > 0.0) return normalize(max(q, 1e-4)) * s;
    return (q.x > q.y) ? float2(s.x, 0.0) : float2(0.0, s.y);
}

/// Lobe gaussien elliptique TOURNÉ — `axis` = (cos θ, sin θ) de l'axe long.
static float vgLobe(float2 p, float2 c, float2 axis, float2 s) {
    float2 d = p - c;
    float2 e = float2(dot(d, axis), dot(d, float2(-axis.y, axis.x))) / s;
    return exp(-dot(e, e));
}

// Les couleurs INTRINSÈQUES (couleurs de LUMIÈRE, jamais de peinture —
// elles ne servent qu'à travers 1-exp(-E·k)).
constant float3 vgBlancChaud = float3(1.000, 0.965, 0.930); // les fils froids
constant float3 vgSepia      = float3(1.000, 0.640, 0.360); // la brume chaude
constant float3 vgCreme      = float3(1.000, 0.780, 0.520); // les flaques crème
constant float3 vgNeutre     = float3(0.940, 0.945, 0.980); // l'épaule gauche
constant float3 vgVoile      = float3(1.000, 0.930, 0.860); // la nappe du coin HD

[[ stitchable ]] half4 verreGonfle(float2 position, half4 color,
                                   float2 size, float t,
                                   float pad, float rHaut, float rBas) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 b = max(center - pad, float2(1.0));
    float rH = min(rHaut, min(b.x, b.y));
    float rB = min(rBas,  min(b.x, b.y));
    float d = vgSd(p, b, rH, rB);
    float inside = smoothstep(0.6, -0.6, d);
    float2 n = vgNormal(p, b, rH, rB);

    // Repère des mesures : points depuis le coin haut-gauche de la CARTE.
    float W = 2.0 * b.x, H = 2.0 * b.y;
    float2 q = p + b;
    float tIn = max(-d, 0.0);            // profondeur DANS le verre
    float tOut = max(d, 0.0);            // distance dans l'AIR

    // Les poids de bord (la normale dit quel flanc on regarde).
    float wR = max(n.x, 0.0), wL = max(-n.x, 0.0);
    float wT = max(-n.y, 0.0), wB = max(n.y, 0.0);

    // Les distances aux quatre coins (les points chauds y vivent).
    float dTL = length(q);
    float dTR = length(q - float2(W, 0.0));
    float dBL = length(q - float2(0.0, H));
    float dBR = length(q - float2(W, H));

    // La respiration : on module des PORTÉES, jamais des amplitudes (moduler
    // l'amplitude clignote, moduler l'étendue respire — la loi de la maison).
    float swell = 1.0 + 0.050 * sin(t * 6.2832 / 8.7)
                      + 0.030 * sin(t * 6.2832 / 13.1 + 2.0);

    float3 E = float3(0.0);      // l'énergie lumineuse, par canal
    float3 rgb = float3(0.0);
    float a = inside;

    if (inside > 0.001) {
        // ---- 8. LE SOCLE : noir de verre, jamais plat — 11/255 au
        // haut-centre, à peine plus dense au pied (la chaleur du bas est
        // ADDITIVE, elle vient de la brume, pas du socle).
        float3 base = mix(float3(0.046, 0.045, 0.048),
                          float3(0.049, 0.044, 0.040),
                          smoothstep(0.0, H, q.y));

        // ---- 1. L'ÉPAULE GAUCHE — deux facettes. Profil mesuré : montée
        // au ras du trait, CREUX à ~2,3 pt, rebond de seconde facette à
        // ~3,6 pt, décroissance lente (portée 8,5 pt) éteinte vers 16 pt.
        // Son épaisseur ONDULE en descendant (la coulée de l'obsidienne) :
        // on module la PROFONDEUR, jamais l'amplitude.
        float coulee = 1.0 + 0.070 * sin(q.y * 0.045 - t * 0.18)
                           + 0.050 * sin(q.y * 0.021 - t * 0.11 + 1.3);
        float te = tIn / coulee;
        // Tour 4 : l'équilibre mesuré/vu — le plateau tient (la référence
        // donne 115→103→93→88) mais l'épaule reste ÉTROITE (~14 pt
        // visibles) : à 17-19 pt elle lisait « gouttière givrée », pas
        // « biseau de verre ».
        float facette1 = smoothstep(0.3, 1.4, te) * exp(-max(te - 1.4, 0.0) / 9.5) * 0.58;
        float creux    = -0.20 * exp(-(te - 2.3) * (te - 2.3) / 0.55);
        float facette2 =  0.46 * exp(-(te - 3.6) * (te - 3.6) / 1.8);
        float profil = max(facette1 + creux + facette2, 0.0)
                     * smoothstep(15.5, 9.0, te);
        // L'épaule vit sur le flanc gauche et TOURNE avec les coins
        // (haut-gauche et bas-gauche) — pow garde les 45° allumés.
        // Débords de coins BAISSÉS (tour 4) : ils lactaient tout l'arc.
        float wEp = pow(wL, 0.55)
                  + 0.22 * exp(-dTL / 52.0) + 0.20 * exp(-dBL / 52.0);
        E += (0.95 * profil * min(wEp, 1.25)) * vgNeutre;

        // ---- 2. LA FLAQUE DU FLANC DROIT — la lumière du fil blanc qui
        // se reflète DANS le côté : exponentielle depuis l'arête droite,
        // portée 13 pt, plus forte à mi-hauteur. BAISSÉE au tour 2 : à
        // 0,72 elle fusionnait avec le fil et l'air en une nappe cramée
        // de 40 pt (mesuré 205-240 sur tout le flanc) — le fil ne
        // tranche que sur du verre SOMBRE (référence : corps 65 à 19 pt,
        // 112 au ras, fil 218, air 35).
        float tR = max(W - q.x, 0.0);
        float profR = 0.40 + 0.60 * exp(-(q.y - 0.52 * H) * (q.y - 0.52 * H)
                                        / (0.45 * H * 0.45 * H));
        // Tour 6 : la flaque s'élargit (la référence a tout le TIERS
        // droit du corps plus clair et chaud, pas 13 pt) — un cœur serré
        // et une jupe large, la recette du faisceau de l'obsidienne.
        E += (0.62 * exp(-tR / 18.0) * profR) * float3(1.0, 0.90, 0.80);
        E += (0.22 * exp(-tR / 52.0) * profR) * float3(1.0, 0.86, 0.74);

        // ---- 4. LA NAPPE DU COIN HAUT-DROIT — une gaussienne elliptique
        // TOURNÉE qui entre par le coin et descend en biais vers le
        // centre (le faisceau oblique de l'obsidienne, transposé) :
        // crête mesurée mourant en ~90 pt.
        // Tour 5 : une LAME, pas un brouillard — à σ 34 elle noyait tout
        // le coin d'un gris uniforme ; la photo montre une lame diagonale
        // DISTINCTE sur un corps qui reste sombre. Plus fine (24), plus
        // longue (140), le centre poussé hors du coin.
        E += (0.26 * vgLobe(q, float2(W + 14.0, -14.0),
                            normalize(float2(-0.60, 0.80)),
                            float2(140.0 * swell, 24.0))) * vgVoile;

        // ---- 5 + 6. LA BRUME CHAUDE — le voile sépia du bas (portée
        // 14 pt, renforcé vers les deux coins) et la flaque du quart
        // bas-droit (mesurée à (81,66,53) au ras du coin).
        float tB = max(H - q.y, 0.0);
        float coins = 0.45 + 0.95 * exp(-dBR / 110.0) + 0.55 * exp(-dBL / 120.0);
        E += (0.24 * exp(-tB / (14.0 * swell)) * coins) * vgSepia;
        E += (0.85 * exp(-dBR / (64.0 * swell))) * vgCreme;
        // La lueur douce du coin haut-gauche (derrière « Training ») —
        // la référence n'y est pas noire, un souffle neutre entre par
        // le coin.
        E += (0.10 * vgLobe(q, float2(-6.0, -6.0),
                            normalize(float2(0.80, 0.60)),
                            float2(90.0, 34.0))) * float3(1.0, 0.97, 0.94);
        // La BANDE CRÈME de la tranche basse (zB-coin-bd) : une épaule
        // CHAUDE, étroite (~5 pt), qui n'existe que vers les coins — au
        // centre la tranche basse reste un simple fil.
        float bandeBas = smoothstep(0.3, 1.5, tIn)
                       * exp(-max(tIn - 1.5, 0.0) / 7.0)
                       * pow(wB, 0.6)
                       * (0.50 + 0.85 * exp(-dBR / 90.0)
                               + 0.50 * exp(-dBL / 100.0));
        E += (0.65 * bandeBas) * vgCreme;
        // L'ÉPAULE DU HAUT — la référence montre l'épaisseur sur les
        // QUATRE tranches : sous le fil du haut, une bande discrète de
        // ~5 pt court sur toute la largeur.
        float bandeHaut = smoothstep(0.3, 1.4, tIn)
                        * exp(-max(tIn - 1.4, 0.0) / 4.5)
                        * pow(wT, 0.6);
        E += (0.22 * bandeHaut) * vgNeutre;

        // La voûte : le court reflet qui descend du bord haut.
        E += (0.14 * exp(-q.y / 7.0)) * float3(1.0, 0.98, 0.96);

        // ---- Les STRIES : deux traînées diagonales DANS la masse du
        // verre, alignées sur la lumière (la photo en a, faibles). Elles
        // DÉRIVENT à peine — le verre est vivant, jamais un balayage.
        float2 axStrie = normalize(float2(-0.86, 0.51));
        float drift = 8.0 * sin(t * 0.07);
        E += (0.048 * vgLobe(q, float2(0.66 * W + drift, 0.26 * H),
                             axStrie, float2(0.42 * W, 26.0)))
             * float3(1.0, 0.97, 0.93);
        E += (0.032 * vgLobe(q, float2(0.30 * W - drift, 0.74 * H),
                             axStrie, float2(0.40 * W, 20.0)))
             * float3(1.0, 0.88, 0.72);
        // LA FUMÉE — la référence n'a pas un corps propre : une brume
        // chaude inégale, à grande échelle, comme de la lumière dans un
        // verre enfumé. Deux lobes larges et faibles, qui dérivent à
        // peine ; le grain fin fait le reste.
        E += (0.045 * vgLobe(q, float2(0.72 * W - drift, 0.85 * H),
                             normalize(float2(0.92, -0.39)),
                             float2(0.55 * W, 0.30 * H)))
             * float3(1.0, 0.80, 0.60);
        E += (0.030 * vgLobe(q, float2(0.22 * W + drift, 0.42 * H),
                             normalize(float2(0.95, 0.31)),
                             float2(0.40 * W, 0.26 * H)))
             * float3(1.0, 0.94, 0.88);

        // ---- 3 + le TRAIT : gaussien sur l'arête (σ 0,75 pt), intensité
        // ANGULAIRE mesurée — droit 218, gauche 173, haut 70 au centre,
        // bas chaud — et les quatre coins qui s'allument.
        float gT = exp(-d * d / (2.0 * 0.75 * 0.75));
        float profRimR = 0.55 + 0.45 * exp(-(q.y - 0.50 * H) * (q.y - 0.50 * H)
                                           / (0.40 * H * 0.40 * H));
        // Le fil GAUCHE s'ORE en descendant (la référence : gris-chaud en
        // haut du flanc, doré franc vers le coin bas) — la teinte suit la
        // position, jamais l'intensité seule (la leçon oIris).
        float3 cFilG = mix(float3(1.0, 0.96, 0.90), float3(1.0, 0.78, 0.52),
                           smoothstep(0.45 * H, H, q.y));
        float3 eRim = (2.10 * wR * profRimR) * float3(1.0, 0.975, 0.955)
                    + (1.15 * wL) * cFilG
                    + (0.28 * wT) * vgBlancChaud
                    + (0.26 * wB) * vgSepia;
        // Les coins : haut-droit blanc, bas-droit crème (le plus chaud),
        // bas-gauche orange, haut-gauche discret.
        eRim += (0.95 * exp(-dTR / 52.0)) * vgBlancChaud
              + (2.00 * exp(-dBR / 58.0)) * vgCreme
              + (1.65 * exp(-dBL / 55.0)) * float3(1.0, 0.58, 0.26)
              + (0.55 * exp(-dTL / 46.0)) * float3(1.0, 0.97, 0.94);
        E += eRim * gT;

        // ---- 8. LE GRAIN DE FILM — par canal, faible, il vit dans la
        // matière (la photo en a partout).
        float grain = (vgHash(position * 0.91) - 0.5) * 0.012;

        rgb = base + (1.0 - exp(-E)) + grain;
        rgb *= inside;
    }

    // ================= DEHORS : la lumière dans l'AIR =================
    if (inside < 0.999) {
        float3 Eo = float3(0.0);

        // ---- 7a. Le bloom sépia qui ÉPOUSE le flanc gauche (mesuré :
        // 24 → 99 sur ~5 pt d'air, au ras du trait).
        float profAirL = 0.35 + 0.65 * exp(-(q.y - 0.55 * H) * (q.y - 0.55 * H)
                                           / (0.40 * H * 0.40 * H));
        Eo += (0.60 * exp(-tOut / 4.0) * wL * profAirL) * float3(1.0, 0.80, 0.62);
        // Le souffle blanc du flanc droit — PRESQUE RIEN (mesuré sur la
        // référence : l'air à droite reste à 35/255, la lumière flaque
        // DEDANS, jamais dehors).
        Eo += (0.07 * exp(-tOut / 4.0) * wR) * vgBlancChaud;
        // Le fil du haut déborde d'un souffle près des coins.
        Eo += (0.10 * exp(-tOut / 3.0) * wT
               * (exp(-dTR / 80.0) + exp(-dTL / 80.0))) * vgBlancChaud;

        // ---- 7b. Les FLAQUES des coins bas : l'orange sous le
        // bas-gauche, la crème sous le bas-droit (la plus lumineuse).
        Eo += (0.60 * exp(-dBL / (42.0 * swell))) * float3(1.0, 0.55, 0.25);
        Eo += (0.75 * exp(-dBR / (36.0 * swell))) * vgCreme;
        // L'air au-dessus du coin haut-droit (faible, large).
        Eo += (0.10 * exp(-dTR / 60.0)) * vgBlancChaud;

        // ---- 7c. Les RAYONS — les traînées diagonales qui traversent
        // l'air sous la carte (anamorphiques : très longues, très fines).
        float2 axRay = normalize(float2(0.94, -0.34));
        Eo += (0.16 * vgLobe(q, float2(0.16 * W, H + 10.0), axRay,
                             float2(0.55 * W, 5.0))) * float3(1.0, 0.72, 0.45);
        Eo += (0.10 * vgLobe(q, float2(0.08 * W, H + 20.0),
                             normalize(float2(0.90, -0.44)),
                             float2(0.48 * W, 3.5))) * float3(1.0, 0.62, 0.32);
        Eo += (0.10 * vgLobe(q, float2(0.94 * W, H + 12.0),
                             normalize(float2(0.88, 0.47)),
                             float2(0.40 * W, 4.0))) * vgCreme;

        float3 air = 1.0 - exp(-Eo);
        float aAir = max(air.r, max(air.g, air.b));
        rgb += air * (1.0 - inside);
        a = inside + (1.0 - inside) * aAir;
    }

    // Dither : un demi-niveau — un dégradé à 4 % bande atrocement sans lui.
    rgb += (vgHash(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0)) - 0.5)
           * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}
