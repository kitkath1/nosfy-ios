#include <metal_stdlib>
using namespace metal;

// MARK: - La flamme ember (banc `-emberLab`)
//
// La flamme emoji 3D laquée, PLEINE et charnue — jamais néon — posée sur une
// nuit noire à peine réchauffée. Toute la composition vit dans ce seul
// fragment : fond noir chaud + vignette braise, souffle radial qui meurt
// autour de la base (et qui n'entre PAS dans la poche concave du crochet —
// la lumière ne contourne pas les creux), corps SDF (cercle de base + pointe
// en S le long d'un Bézier + lobe du crochet, encoche soustraite au smax
// serré pour un bec rasoir), rim rouge profond assombri sous le bord du haut,
// bord ourlé de lumière dans la moitié chaude, sheen laqué du flanc gauche,
// creux du crochet embrasé en croissant, flamme interne à frontière DIFFUSE,
// cœur gouttelette inversée jaune-blanc (plafonné sous lum 246) avec son halo
// doré, et les braises en vol.
//
// Géométrie : repère de MESURE-FORME.md — origine au centre du cercle de
// base, y+ vers le bas, unité = hauteur de flamme h. La coupe de l'encoche a
// été RALLONGÉE (B à ny −0,37, k3 0,008) par rapport au fit Nelder-Mead :
// avec les valeurs d'origine le haut de l'encoche restait ponté et le creux
// devenait une poche fermée — vérifié numériquement : ouverture f 0,378,
// bec (+0,219), vallée f 0,485 contre 0,358/+0,219/0,484 mesurés.

static float fhash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Bruit de valeur lisse (pour la robe de rubis — l'écoulement des rouges).
static float vnoise(float2 x) {
    float2 i = floor(x), f = fract(x);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = fhash21(i);
    float b = fhash21(i + float2(1.0, 0.0));
    float c = fhash21(i + float2(0.0, 1.0));
    float d = fhash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float fsmin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

static float fsmax(float a, float b, float k) {
    return -fsmin(-a, -b, k);
}

// LE VENT est calculé côté CPU (EmberWind, une fois par frame) et entre
// par les uniforms windA/windB/sweepSig : ces signaux ne dépendent pas du
// pixel — les évaluer ici coûtait une fortune pour rien.

// Capsule inégale à orientation libre (iq), pour l'encoche du crochet,
// la goutte interne et le cœur.
static float sdUneven(float2 p, float2 pa, float ra, float2 pb, float rb) {
    float2 ba = pb - pa;
    float l = max(length(ba), 1e-6);
    float2 dir = ba / l;
    float2 q = p - pa;
    float2 pp = float2(dot(q, float2(dir.y, -dir.x)), dot(q, dir));
    pp.x = abs(pp.x);
    float b = (ra - rb) / l;
    float a = sqrt(max(1.0 - b * b, 1e-6));
    float k = dot(pp, float2(-b, a));
    if (k < 0.0)     return length(pp) - ra;
    if (k > a * l)   return length(pp - float2(0.0, l)) - rb;
    return dot(pp, float2(a, b)) - ra;
}

// Le rayon du cône le long du Bézier. `pow(tt, 0.86)` coûtait 37 appels par
// pixel : remplacé par le mélange linéaire/racine qui l'approche à 1 % près
// (0,86 est à 28 % du chemin entre l'exposant 1 et l'exposant 1/2).
static float coneRadius(float tt, float r0, float rg) {
    return r0 + rg * mix(tt, sqrt(tt), 0.28);
}

// Cône arrondi le long d'un Bézier quadratique : 12 échantillons puis
// raffinement dichotomique — reste largement sous le pixel (Nyquist 3×),
// pour un tiers du coût de la version à 24+6.
static float sdBezierCone(float2 p, float2 P0, float2 P1, float2 P2,
                          float r0, float rg) {
    float best = 1e9;
    float bt = 0.0;
    for (int i = 0; i <= 12; i++) {
        float tt = float(i) / 12.0;
        float2 b = mix(mix(P0, P1, tt), mix(P1, P2, tt), tt);
        float f = length(p - b) - coneRadius(tt, r0, rg);
        if (f < best) { best = f; bt = tt; }
    }
    float step = 1.0 / 12.0;
    for (int j = 0; j < 5; j++) {
        step *= 0.5;
        for (int s = -1; s <= 1; s += 2) {
            float tt = clamp(bt + float(s) * step, 0.0, 1.0);
            float2 b = mix(mix(P0, P1, tt), mix(P1, P2, tt), tt);
            float f = length(p - b) - coneRadius(tt, r0, rg);
            if (f < best) { best = f; bt = tt; }
        }
    }
    return best;
}

// Les braises en vol : positions mesurées de la référence (repère normalisé).
// x, y, rayon (× h), élongation.
constant float4 kSparks[20] = {
    float4(-0.011, -0.787, 0.0030, 1.0),
    float4(-0.145, -0.723, 0.0030, 1.0),
    float4( 0.173, -0.656, 0.0052, 1.4),
    float4(-0.066, -0.581, 0.0020, 1.0),
    float4( 0.335, -0.526, 0.0020, 1.0),
    float4(-0.198, -0.494, 0.0028, 1.0),
    float4( 0.282, -0.467, 0.0095, 1.5),
    float4(-0.173, -0.425, 0.0080, 2.2),
    float4(-0.220, -0.339, 0.0020, 1.0),
    float4(-0.255, -0.299, 0.0024, 1.0),
    float4(-0.264, -0.286, 0.0028, 1.0),
    float4(-0.390, -0.274, 0.0058, 2.2),
    float4(-0.281, -0.250, 0.0024, 1.0),
    float4( 0.321, -0.352, 0.0038, 1.3),
    float4( 0.464, -0.213, 0.0070, 2.4),
    float4(-0.393, -0.007, 0.0026, 1.0),
    float4( 0.418,  0.139, 0.0028, 1.0),
    float4( 0.363,  0.179, 0.0036, 1.3),
    float4( 0.306,  0.221, 0.0034, 1.6),
    float4(-0.360,  0.231, 0.0028, 1.3),
};
// angle (rad) de l'étirement, part d'or dans la couleur.
constant float2 kSparkAux[20] = {
    float2(0.00, 0.80), float2(0.00, 0.60), float2(1.43, 0.90),
    float2(0.00, 0.50), float2(0.00, 0.70), float2(0.00, 0.50),
    float2(0.49, 0.95), float2(2.22, 0.75), float2(0.00, 0.40),
    float2(0.00, 0.50), float2(0.00, 0.60), float2(0.79, 0.70),
    float2(0.00, 0.50), float2(0.52, 0.60), float2(1.15, 0.65),
    float2(0.00, 0.50), float2(0.35, 0.60), float2(0.79, 0.70),
    float2(0.35, 0.55), float2(1.59, 0.60),
};
// intensité par braise (les grosses étirées restent des braises, pas des lampes).
constant float kSparkAmp[20] = {
    0.55, 0.50, 0.75, 0.45, 0.50, 0.45, 0.80, 0.60, 0.40, 0.45,
    0.50, 0.60, 0.45, 0.50, 0.50, 0.45, 0.50, 0.55, 0.45, 0.50,
};

[[ stitchable ]] half4 emberFlame(float2 position, half4 color,
                                  float2 size, float t,
                                  float2 tapPix, float tapAge,
                                  float4 windA, float4 windB, float sweepSig) {
    // Le VENT, calculé une fois par frame côté CPU (EmberWind) : ces
    // signaux sont identiques pour tous les pixels — les recalculer ici
    // coûtait ~24 bruits par pixel et cassait la cadence.
    float wTip   = windA.x;   // la pointe, en tête du souffle
    float wLean  = windA.y;   // le corps, 0,12 s plus tard
    float wDust  = windA.z;   // la poussière, 0,20 s
    float wInner = windA.w;   // la flamme interne, 0,35 s
    float wCore  = windB.x;   // le cœur, 0,45 s
    float gust   = windB.y;   // l'énergie turbulente du moment
    float inhale = windB.z;   // l'inspiration (apériodique)
    float lick   = windB.w;   // la lèche de bougie
    // ---- repère : la flamme au bas de l'écran, base tronquée de 0,0115 h
    // comme dans la référence, taille bornée par la fenêtre de recadrage.
    float h = size.x * 0.75;
    float2 baseC = float2(size.x * 0.5, size.y - 0.3261 * h);
    float2 p = (position - baseC) / h;
    float aa = 0.7 / h;   // ~2 px machine
    // le repère SCÈNE, avant l'inspiration : les braises volent dans l'air,
    // elles ne respirent pas avec la silhouette
    float2 pScene = p;
    float2 tapP = (tapPix - baseC) / h;

    // ---- l'inspiration : apériodique (8-14 s, jamais la même), la
    // silhouette s'étire puis se rassoit, ancrée à la base
    p.y /= 1.0 + inhale * smoothstep(0.35, -0.75, p.y);

    // ---- la danse : la pointe valse, la base reste ancrée ----
    // Profil en hauteur au carré : nul sur le cercle de base, plein à l'apex.
    float lift = clamp((-p.y - 0.18) / 0.50, 0.0, 1.0);
    lift *= lift;
    float bend = 0.055 * wTip * lift;
    // le DÉHANCHÉ : le vent, avec un léger retard sur la pointe (linéaire
    // en hauteur : la base reste assise, la flamme ENTIÈRE danse)
    float leanA = 0.034 * wLean;
    float lean = leanA * clamp(-p.y + 0.30, 0.0, 1.2);
    // l'ondulation du contour : vagues larges qui remontent, dont
    // l'amplitude vit avec la rafale — pendant une bourrasque la flamme
    // frémit plus fort, puis se rassérène
    float ripAmp = 0.6 + 1.3 * gust;
    float ripple = 0.0075 * ripAmp * lift * sin(6.5 * p.y + 2.6 * t)
                 + 0.0040 * ripAmp * lift * sin(10.0 * p.y - 4.1 * t + 1.3);
    float2 pw = float2(p.x - bend - lean - ripple, p.y);
    // ---- la CASCADE : la respiration naît dans le cœur et se PROPAGE en
    // onde vers le bord puis le sol (~1,1 s par hauteur de flamme). Évaluée
    // PAR PIXEL avec ce retard : ce n'est jamais un flash global, c'est une
    // vague — « la flamme respire de l'intérieur ». Deux ondes pour un
    // souffle vivant, jamais métronomique.
    float radC = length(p - float2(0.010, 0.095));
    float tW = t - 1.1 * radC;
    float breath = (0.75 + 0.50 * gust)
                 * (0.70 * sin(2.0 * M_PI_F * 0.21 * tW + 0.6)
                  + 0.30 * sin(2.0 * M_PI_F * 0.53 * tW + 2.0));

    // ---- silhouette (sur le domaine dansé) ----
    float dBody = length(pw) - 0.3376;
    float dSpout = sdBezierCone(pw, float2(-0.0747, -0.6726),
                                   float2( 0.1201, -0.4774),
                                   float2(-0.0694, -0.1152),
                                   0.0036, 0.1948);
    float d = fsmin(dBody, dSpout, 0.1124);
    d = fsmin(d, length(pw - float2(0.1669, -0.1491)) - 0.1436, 0.0636);
    float dPre = d;   // avant l'encoche : les parois de la coupe ne sont pas
                      // des bords éclairés — leur couleur vient du corps
    float dCut = sdUneven(pw, float2(0.1733, -0.198), 0.0112,
                             float2(0.1763, -0.370), 0.0620);
    d = fsmax(d, -dCut, 0.008);

    // ---- fond : noir chaud + vignette braise + souffle collé au corps ----
    float ynorm = position.y / max(size.y, 1.0);
    float3 bg = mix(float3(0.030, 0.028, 0.031),   // #080708 en haut
                    float3(0.034, 0.030, 0.033),   // à peine plus chaud en bas
                    smoothstep(0.10, 0.85, ynorm));
    // l'air de la nuit bouge : l'asymétrie du souffle orbite très lentement
    // — et le halo S'INCLINE du côté où la flamme penche (la physique
    // cohérente, c'est ce qui vend la danse)
    float rr = length(p - float2(0.020 * sin(2.0 * M_PI_F * 0.050 * t)
                                     + 0.30 * leanA + 0.25 * (0.055 * wTip),
                                 0.012 * cos(2.0 * M_PI_F * 0.037 * t)));
    float Lring = 34.0 * exp(-max(rr - 0.076, 0.0) / 0.26);
    float wLow = smoothstep(-0.80, -0.10, p.y);
    // la lumière n'entre pas dans la poche concave du crochet…
    float pocket = exp(-pow((pw.x - 0.170) / 0.11, 2.0)
                       - pow((p.y + 0.30) / 0.15, 2.0));
    // …et le flanc droit du lobe reste plus sombre que le flanc gauche
    float rightDim = 0.38 * smoothstep(0.20, 0.34, pw.x)
                   * smoothstep(0.26, 0.05, p.y)
                   * smoothstep(-0.42, -0.24, p.y);
    float Lhug = 43.0 * exp(-max(d, 0.0) / 0.070) * wLow
               * (1.0 - 0.62 * pocket) * (1.0 - rightDim);
    // la braise qui refroidit, JAMAIS grise — le souffle respire en
    // contre-phase légère du cœur (±5 %, local au halo, jamais global)
    bg += ((Lring + Lhug) * (1.0 + 0.07 * max(breath, 0.0)) / 255.0)
        * float3(2.3, 0.69, 0.43);

    // ---- braises en vol : chacune naît à son ancre mesurée, monte en
    // dérive courbe, s'éteint en fondu et renaît — l'enveloppe est NULLE aux
    // deux bouts du cycle (jamais de pop, jamais de téléportation) ----
    for (int i = 0; i < 20; i++) {
        float4 s = kSparks[i];
        float2 axr = kSparkAux[i];
        float fi = float(i);
        float T = 9.0 + 7.0 * fhash21(float2(fi, 3.7));    // 9–16 s par braise
        float u = fract(t / T + fhash21(float2(fi, 8.2)));
        float wob = 0.7 + 0.6 * fhash21(float2(fi, 5.1));
        float2 drift = float2(
            0.020 * sin(2.0 * M_PI_F * wob * u + fi * 2.13),
            -0.16 * u);
        float env = smoothstep(0.0, 0.18, u)
                  * (1.0 - smoothstep(0.62, 1.0, u));
        float2 q = p - (s.xy + drift);
        float ca = cos(axr.x), sa = sin(axr.x);
        float2 qr = float2(ca * q.x + sa * q.y, -sa * q.x + ca * q.y);
        qr.x /= s.w;
        float dd = length(qr) / s.z;
        // née près d'un pic du cœur → braise plus vive (causalité lisible)
        float tb = t - u * T;
        float bb = 0.70 * sin(2.0 * M_PI_F * 0.21 * tb + 0.6)
                 + 0.30 * sin(2.0 * M_PI_F * 0.53 * tb + 2.0);
        float fl = kSparkAmp[i] * env * (1.0 + 0.30 * max(bb, 0.0))
                 * (0.85 + 0.18 * sin(t * 2.3 + fi * 2.71));
        float3 sc = mix(float3(0.906, 0.439, 0.282),   // #E77048
                        float3(0.973, 0.902, 0.376),   // #F8E660
                        axr.y);
        bg += sc * exp(-dd * dd * 1.1) * fl;
        bg += float3(0.55, 0.20, 0.12) * exp(-dd * dd * 0.16) * 0.08 * fl;
    }

    // ---- la poussière de rubis, plan LOINTAIN (derrière la flamme) :
    // sequins ~1 px, dérive lente — la profondeur du nuage. Un par cellule,
    // la masse fait l'effet. (Version validée : voisinage 3x3, densité
    // pleine — la « grille advectée » à 4 cellules laissait voir son motif.)
    {
        float cellF = 0.021;
        float2 ci = floor(pScene / cellF);
        for (int gx = -1; gx <= 1; gx++)
        for (int gy = -1; gy <= 1; gy++) {
            float2 cc = ci + float2(gx, gy);
            if (fhash21(cc + 269.3) > 0.60) continue;
            float h1 = fhash21(cc + 201.7);
            float h2 = fhash21(cc + 223.1);
            float h3 = fhash21(cc + 247.9);
            float Tf = 2.0 + 1.6 * h1;
            float u = fract(t / Tf + h2);
            float2 pos = (cc + float2(0.15 + 0.7 * h1, 0.15 + 0.7 * h2))
                             * cellF
                + float2(0.010 * sin(6.2832 * (0.5 + h1) * u + h2 * 6.2832)
                             + 0.06 * wInner * u,
                         -(0.035 + 0.045 * h3) * u);
            float env = smoothstep(0.0, 0.15, u)
                      * (1.0 - smoothstep(0.60, 1.0, u));
            float tw = 0.65 + 0.35 * sin(6.2832 * (1.5 + 1.5 * h3) * t
                                         + h1 * 6.2832);
            float2 rel = pScene - pos;
            float g = exp(-dot(rel, rel) / (0.0013 * 0.0013));
            float cool = clamp(1.4 * u - 0.2, 0.0, 1.0);
            float3 vif = mix(float3(0.910, 0.278, 0.235),      // #E8473C
                             float3(0.933, 0.373, 0.275), h2); // #EE5F46
            float3 sombre = mix(float3(0.557, 0.129, 0.094),   // #8E2118
                                float3(0.353, 0.078, 0.055), h1);
            float w = exp(-max(d, 0.0) / 0.50) + 0.05;
            bg = mix(bg, mix(vif, sombre, cool),
                     min(g * env * tw * w * 0.70, 0.65));
        }
    }

    // ---- corps laqué ----
    // la couleur se lit sur la profondeur AVANT l'encoche (dinB) : les parois
    // de la coupe restent couleur de chair, seul le croissant les embrase.
    float din = -d;                     // profondeur vraie (alpha, portes)
    float dinB = -dPre;                 // profondeur de chair (couleur)
    float warmth = smoothstep(-0.25, -0.17, p.y);   // la chauffe vers la base

    // ---- LE VENT DANS LA CHAIR : trois voiles d'encre qui MONTENT en
    // continu à travers le corps (domaine déformé par la turbulence, courbé
    // par le vent, vitesses étagées = parallaxe interne), plus des
    // filaments de chaleur étirés le long du flux — les couleurs voyagent,
    // portées, jamais figées. Vitesses FIXES dans les champs (un gain
    // variable sur t saute) ; le vent agit par l'offset shiftW, borné et
    // lisse.
    float shiftW = 0.22 * wLean * smoothstep(0.30, -0.55, p.y);
    float2 qB = p + float2(shiftW, 0.0);
    float2 warpQ = float2(
        vnoise(qB * 2.1 - float2(0.0, 0.030 * t)),
        vnoise(qB * 2.1 + 47.3 - float2(0.0, 0.026 * t))) - 0.5;
    float vBack  = vnoise(qB * 3.1 + 0.55 * warpQ
                          - float2(0.0, 0.045 * t)) - 0.5;
    float vMid   = vnoise(qB * 4.6 + 0.75 * warpQ
                          - float2(0.0, 0.085 * t) + 31.9) - 0.5;
    float vFront = vnoise(qB * 6.2 + 0.95 * warpQ
                          - float2(0.0, 0.140 * t) + 67.1) - 0.5;
    float fil = smoothstep(0.12, 0.30,
        vnoise(float2(qB.x * 9.0, qB.y * 2.3) + 1.4 * warpQ
               - float2(0.0, 0.200 * t) + 83.7) - 0.5);
    float3 edgeCol = mix(float3(0.847, 0.251, 0.184),    // #D8402F (haut)
                         float3(0.910, 0.373, 0.286),    // #E85F49 (bas)
                         warmth);
    // le bord bas du cercle n'est pas ourlé : il replonge dans le rouge
    edgeCol = mix(edgeCol, float3(0.776, 0.259, 0.169),  // #C6422B
                  smoothstep(0.24, 0.31, p.y));
    // le rim VIT : plus chaud là où un filament du voile vient l'affleurer
    // — le bord cesse d'être un autocollant uniforme
    edgeCol = mix(edgeCol, float3(0.941, 0.514, 0.337),  // #F08356
                  0.28 * max(vMid, 0.0));
    float3 bandCol = mix(float3(0.725, 0.196, 0.184),    // rim assombri #B9322F
                         float3(0.800, 0.231, 0.157),    // #CC3B28 (bas)
                         warmth);
    float3 interiorCol = mix(float3(0.761, 0.208, 0.157),  // #C23528 (haut)
                             float3(0.827, 0.231, 0.149),  // #D33B26 (bas)
                             warmth);
    float3 bodyCol = mix(edgeCol, bandCol, smoothstep(0.004, 0.045, dinB));
    bodyCol = mix(bodyCol, interiorCol, smoothstep(0.06, 0.18, dinB));
    // les trois voiles s'impriment dans la chair — palette mesurée
    // uniquement, la fusion se fait en rampe, jamais en bande
    float veilGate = smoothstep(0.035, 0.10, dinB);
    bodyCol = mix(bodyCol, float3(0.545, 0.129, 0.102),   // voile arrière
                  0.18 * max(-vBack, 0.0) * veilGate);
    bodyCol = mix(bodyCol, float3(0.933, 0.459, 0.224),   // chair qui monte
                  0.24 * max(vMid, 0.0) * veilGate);
    bodyCol = mix(bodyCol, float3(0.949, 0.545, 0.302),   // voile avant
                  0.16 * max(vFront, 0.0) * veilGate);
    bodyCol = mix(bodyCol, float3(0.957, 0.604, 0.318),   // filaments léchés
                  0.11 * fil * veilGate * warmth);
    // la colonne du ventre : le corail vif autour de l'axe — un DÔME, pas un
    // rectangle : le seuil vertical descend avec |x| et les épaules sont des
    // gaussiennes plates (aucun coin visible).
    float vx = abs(pw.x + 0.038);
    // un VRAI dôme : gaussienne douce (jamais de ^4 : le plateau + flancs
    // raides dessinaient un rectangle) et rampe verticale très large
    float ventreW = smoothstep(-0.32, -0.03, p.y + 2.2 * vx * vx)
                  * exp(-pow(vx / 0.105, 2.0))
                  * smoothstep(0.03, 0.15, dinB);
    bodyCol = mix(bodyCol, float3(0.933, 0.459, 0.224), 0.85 * ventreW); // #EE7539
    // l'apex s'éclaire (la pointe fine est plus claire que le rim du S)
    bodyCol = mix(bodyCol, float3(0.839, 0.282, 0.235),             // #D6483C
                  smoothstep(-0.56, -0.66, p.y));
    // bord ourlé de lumière dans la moitié chaude (subsurface au ras du bord)
    float edgeLight = warmth * exp(-pow((dinB - 0.004) / 0.010, 2.0))
                    * (1.0 - smoothstep(0.20, 0.30, p.y))
                    * (1.0 + 0.20 * max(breath, 0.0));   // la vague au bord
    bodyCol = mix(bodyCol, float3(0.941, 0.514, 0.337), 0.68 * edgeLight); // #F08356

    // sheen laqué : ourlet pêche du flanc gauche de la pointe, avec une
    // traîne intérieure chaude (le vernis attrape la lumière)
    // le vernis vit : le reflet glisse lentement le long du flanc (~32 s)
    float sheenPos = exp(-pow((p.y + 0.37
                               + 0.035 * sin(2.0 * M_PI_F * 0.031 * t)) / 0.17,
                              2.0))
                   * smoothstep(0.02, -0.06, pw.x);
    // le GLISSEMENT de laque : plus de métronome — la nappe est déclenchée
    // par les RAFALES (elle descend le flanc quand le vent se lève, recule
    // s'il retombe) : la haute lumière d'une laque SE DÉPLACE, portée
    float Ssw = sweepSig;
    float sweepEnv = smoothstep(0.55, 0.66, Ssw)
                   * (1.0 - smoothstep(0.86, 0.95, Ssw));
    float ySweep = mix(-0.66, 0.12, smoothstep(0.55, 0.95, Ssw));
    sheenPos += 0.9 * exp(-pow((p.y - ySweep) / 0.14, 2.0)) * sweepEnv
              * smoothstep(0.03, -0.05, pw.x);
    bodyCol = mix(bodyCol, float3(0.941, 0.514, 0.337),             // #F08356
                  min(0.65 * exp(-pow((dinB - 0.005) / 0.055, 2.0)) * sheenPos,
                      0.85));

    // le creux du crochet s'embrase : croissant doré sur les parois — et il
    // RESPIRE doucement, chauffé par l'interne (local, jamais global)
    float2 pc = pw - float2(0.176, -0.225);
    pc.y += 0.020 * max(breath, 0.0);   // la bouffée REMONTE la paroi
    float cuspGlow = exp(-max(dCut, 0.0) / 0.045)
                   * exp(-pow(pc.x / 0.095, 2.0) - pow(pc.y / 0.105, 2.0))
                   * (0.85 + 0.25 * max(breath, 0.0));   // après le pic du cœur
    bodyCol = mix(bodyCol, float3(0.965, 0.753, 0.533),             // #F6C088
                  min(1.1 * cuspGlow, 0.95));

    // ---- flamme interne, frontière diffuse — elle flotte un peu plus vite
    // que le corps et en RETARD de phase sur lui (0,35 s) ----
    float sway = 0.018 * wInner + 0.70 * (0.055 * wInner);
    // la HOULE : la pointe de l'interne serpente (vague qui remonte sa
    // hauteur) — l'amplitude vit avec la rafale
    float serp = 0.018 * (0.7 + 0.8 * gust)
               * sin(3.5 * p.y + 2.0 * M_PI_F * 0.19 * t + 0.4);
    float2 pi2 = p - float2((sway + serp) * clamp(0.3 - p.y, 0.0, 0.9), 0.0);
    float dInner = fsmin(length(pi2 - float2(0.0, 0.19)) - 0.185,
                         sdUneven(pi2, float2(0.010, -0.034), 0.010,
                                       float2(0.004,  0.100), 0.115), 0.08);
    // l'interne est CONTENU par le rim : il s'éteint au ras du bord du corps
    float gate = smoothstep(0.012, 0.075, din);
    // feather étroit à la pointe, large près de la panse (mesure : ~0,05 h,
    // « plus large près du cœur ») — il respire à peine
    float feather = mix(0.050, 0.085, smoothstep(-0.05, 0.15, p.y))
                  * (1.0 + 0.07 * sin(2.0 * M_PI_F * 0.17 * t + 1.1)
                         + 0.05 * breath);
    float inner = smoothstep(feather, -0.045, dInner) * gate;
    // subsurface : le corps chauffe à l'approche de l'interne
    float ss = exp(-max(dInner, 0.0) / 0.09) * warmth;
    float3 col = mix(bodyCol, float3(0.933, 0.392, 0.220),             // #EE6438
                     0.55 * ss * (1.0 + 0.18 * max(breath, 0.0)));
    // orange au bord diffus, or au centre
    float3 innerCol = mix(float3(0.933, 0.541, 0.251),   // #EE8A40
                          float3(0.961, 0.761, 0.361),   // #F5C25C
                          smoothstep(0.012, -0.055, dInner));
    col = mix(col, innerCol, inner);

    // ---- cœur : gouttelette inversée + halo doré qui saigne ----
    // Le SOLISTE : la panse respire (±8 %), et sa pointe LÈCHE vers le haut
    // comme une bougie — elle s'étire, danse un peu de côté, et se rassoit.
    // Trois périodes propres (0,37 / 0,29 / 0,21+0,53 Hz), toutes distinctes
    // de celles du corps.
    // physique de bougie : dérive lente portée par le vent + lèches vives
    // occasionnelles (bruit apériodique), plus hautes en rafale
    float2 coreTip = float2(
        0.012 + 0.018 * wCore,
       -0.028 - 0.030 * lick - 0.015 * gust);
    float dCore = sdUneven(pi2, coreTip, 0.013,
                                float2(0.010,  0.180), 0.098)
                - 0.008 * breath;
    float goldHalo = exp(-max(dCore, 0.0) / 0.038)
                   * (1.0 + 0.18 * breath);
    float3 haloCol = mix(float3(0.929, 0.627, 0.290),    // #EDA04A (haut)
                         float3(0.949, 0.745, 0.369),    // #F2BE5E (bas)
                         smoothstep(-0.03, 0.12, p.y));
    col = mix(col, haloCol, 0.8 * goldHalo * inner);
    float core = smoothstep(0.02, -0.008, dCore)
               * smoothstep(-0.045, 0.02, p.y) * gate;
    float3 coreCol = mix(float3(0.973, 0.863, 0.494),    // #F8DC7E (pointe)
                         float3(0.984, 0.949, 0.729),    // #FBF2BA (panse)
                         smoothstep(-0.02, 0.20, p.y));
    coreCol = mix(coreCol, float3(0.988, 0.965, 0.776),  // #FCF6C6 — jamais blanc
                  smoothstep(-0.05, -0.085, dCore) * smoothstep(0.02, 0.10, p.y));
    // l'éclat respire avec la panse, PLAFONNÉ sous le blanc pur (lum ≤ 248)
    coreCol = min(coreCol * (1.0 + 0.07 * breath),
                  float3(0.992, 0.973, 0.816));
    col = mix(col, coreCol, core);

    // ---- la soie d'or : dans le halo, un voile satiné à GRANDES ondes qui
    // circule lentement — la richesse sans le grain. Aucun point, jamais :
    // sur cette laque, toute granularité lit « paillette de fête », donc
    // cheap. Le premium, c'est la lumière en nappes.
    if (inner > 0.02) {
        float soie = vnoise(p * 6.5 + float2(0.050 * t, -0.160 * t))
                   + 0.5 * vnoise(p * 12.0 + float2(-0.040 * t, -0.100 * t));
        soie = soie / 1.5 - 0.5;
        float soieGate = inner * (1.0 - core)
                       * (0.55 + 0.45 * clamp(goldHalo, 0.0, 1.0));
        col += float3(1.0, 0.90, 0.62) * (0.06 * soie) * soieGate;
    }

    // ---- composition : le bord garde sa hairline (alpha inclut d ≈ 0) ----
    float alphaBody = smoothstep(aa, -aa, d);
    float3 outc = mix(bg, col, alphaBody);

    // l'ourlet du sheen : un liseré INTÉRIEUR — dehors il ne reste presque
    // rien (le brouillard blanc hors silhouette est un rendu néon, interdit)
    float hem = exp(-pow((d + 0.006) / 0.013, 2.0))
              * mix(0.10, 1.0, alphaBody);
    outc = mix(outc, float3(0.965, 0.804, 0.725),        // #F6CDB9
               min(0.95 * hem * sheenPos, 0.93));

    // la nuit se referme tout en haut du cadre — rampe TRÈS large : toute
    // rampe courte trace une couture horizontale visible sur l'écran
    outc = mix(float3(0.004, 0.001, 0.016), outc,
               smoothstep(-2.05, -0.95, p.y));

    // ---- la pluie de mini-braises : la poussière hyper fine qui s'échappe
    // d'elle en continu — l'apex surtout, le bec du crochet, le flanc gauche.
    for (int i = 0; i < 56; i++) {
        float fi = float(i);
        float h1 = fhash21(float2(fi, 21.7));
        float h2 = fhash21(float2(fi, 43.1));
        float h3 = fhash21(float2(fi, 87.9));
        float Tp = 3.0 + 4.0 * h1;
        float u = fract(t / Tp + h2);
        float2 e0;
        if (h3 < 0.60) {
            e0 = float2(-0.0747 + 0.055 * wTip + 0.04 * (h1 - 0.5), -0.66);
        } else if (h3 < 0.80) {
            e0 = float2(0.219 + 0.03 * (h2 - 0.5), -0.35);
        } else {
            e0 = float2(-0.26 + 0.10 * h1, -0.42 - 0.10 * h2);
        }
        float2 pos = e0 + float2(
            0.030 * sin(6.2832 * (0.6 + 0.8 * h2) * u + h1 * 6.2832)
                + 0.04 * (h1 - 0.5) * u + 0.10 * wDust * u,
            -(0.10 + 0.15 * h3) * u - 0.02 * u * u);
        float env = smoothstep(0.0, 0.10, u)
                  * (1.0 - smoothstep(0.55, 1.0, u));
        float2 rel = pScene - pos;
        float rr2f = dot(rel, rel);
        if (rr2f > 0.00004) continue;
        float cool = clamp(1.4 * u - 0.2, 0.0, 1.0);
        float3 ec = mix(mix(float3(0.910, 0.278, 0.235),
                            float3(0.933, 0.373, 0.275), h2),
                        mix(float3(0.557, 0.129, 0.094),
                            float3(0.353, 0.078, 0.055), h1), cool);
        outc += ec * exp(-rr2f / (0.0016 * 0.0016)) * env * (0.45 + 0.30 * h1);
    }

    // ---- la poussière de rubis, plan PROCHE (devant la flamme) : des
    // CENTAINES de sequins rouges 2 px qui alternent vif/foncé, frémissent
    // et refroidissent en vol. Version validée « plein plein ».
    {
        float cellN = 0.017;
        float2 ci = floor(pScene / cellN);
        for (int gx = -1; gx <= 1; gx++)
        for (int gy = -1; gy <= 1; gy++) {
            float2 cc = ci + float2(gx, gy);
            if (fhash21(cc + 369.3) > 0.75) continue;
            float h1 = fhash21(cc + 301.7);
            float h2 = fhash21(cc + 323.1);
            float h3 = fhash21(cc + 347.9);
            float Tn = 1.5 + 1.5 * h1;
            float u = fract(t / Tn + h2);
            float2 pos = (cc + float2(0.15 + 0.7 * h1, 0.15 + 0.7 * h2))
                             * cellN
                + float2(0.014 * sin(6.2832 * (0.6 + 0.9 * h1) * u
                                     + h2 * 6.2832)
                             + 0.09 * wDust * u,
                         -(0.070 + 0.080 * h3) * u);
            float env = smoothstep(0.0, 0.15, u)
                      * (1.0 - smoothstep(0.60, 1.0, u));
            float tw = 0.72 + 0.28 * sin(6.2832 * (2.0 + 2.0 * h3) * t
                                         + h1 * 6.2832);
            float2 rel = pScene - pos;
            float g = exp(-dot(rel, rel) / (0.0026 * 0.0026));
            float cool = clamp(1.4 * u - 0.2, 0.0, 1.0);
            float3 vif = mix(float3(0.910, 0.278, 0.235),      // #E8473C
                             float3(0.933, 0.373, 0.275), h2); // #EE5F46
            float3 sombre = mix(float3(0.557, 0.129, 0.094),   // #8E2118
                                float3(0.353, 0.078, 0.055), h1);
            float w = exp(-abs(d) / 0.50) + 0.06;
            outc = mix(outc, mix(vif, sombre, cool),
                       min(g * env * tw * w * 0.85, 0.85));
        }
    }

    // ---- le TAP : ~320 sequins rouges jaillissent du point touché,
    // freinent, montent, refroidissent du vif au sombre et s'éteignent ----
    if (tapAge >= 0.0 && tapAge < 2.2) {
        for (int i = 0; i < 320; i++) {
            float fi = float(i);
            float h1 = fhash21(float2(fi, 5.1));
            float h2 = fhash21(float2(fi, 9.7));
            float h3 = fhash21(float2(fi, 15.3));
            float lifeP = 0.7 + 1.4 * h3;
            float uu = tapAge / lifeP;
            if (uu >= 1.0) continue;
            float ang = 6.2832 * h1;
            float spd = 0.10 + 0.45 * h2 * h2;
            float dec = 1.0 - 0.55 * uu;               // le freinage de l'air
            float2 pos = tapP
                + float2(cos(ang), sin(ang)) * (spd * tapAge * dec)
                + float2(0.0, -0.05 * tapAge * tapAge); // la montée des braises
            float2 rel = pScene - pos;
            float rr2t = dot(rel, rel);
            if (rr2t > 0.00004) continue;
            float env = 1.0 - smoothstep(0.45, 1.0, uu);
            float cool = clamp(1.3 * uu - 0.15, 0.0, 1.0);
            float3 ec = mix(mix(float3(0.910, 0.278, 0.235),
                                float3(0.933, 0.373, 0.275), h2),
                            mix(float3(0.557, 0.129, 0.094),
                                float3(0.353, 0.078, 0.055), h1), cool);
            float g = exp(-rr2t / (0.0014 * 0.0014));
            outc = mix(outc, ec, min(g * env * 0.75, 0.8));
        }
    }

    // ---- la mote brillante : une par ~31 s, elle traverse lentement la
    // nuit avec une traînée douce ----
    float mcyc = floor(t / 31.0);
    float mu = fract(t / 31.0) * (31.0 / 6.0);
    if (mu < 1.0) {
        float mh = fhash21(float2(mcyc, 11.7));
        float2 mp0 = float2(-0.55 + 0.15 * mh, -0.50 - 0.38 * mh);
        float2 mp1 = float2(0.58, mp0.y + 0.16);
        float2 mp = mix(mp0, mp1, mu) + float2(0.0, 0.05 * sin(6.2832 * mu));
        float envM = smoothstep(0.0, 0.20, mu)
                   * (1.0 - smoothstep(0.80, 1.0, mu));
        float2 dirM = normalize(mp1 - mp0);
        float2 rel = p - mp;
        float along = dot(rel, dirM);
        float perp = dot(rel, float2(-dirM.y, dirM.x));
        float3 gold = float3(0.973, 0.902, 0.376);
        outc += gold * exp(-dot(rel, rel) / (0.006 * 0.006)) * 0.85 * envM;
        float behind = clamp(-along, 0.0, 0.14);
        outc += gold * exp(-pow(perp / 0.0045, 2.0)) * exp(-behind / 0.045)
              * (along < 0.0 ? 1.0 : 0.0) * 0.20 * envM;
    }

    // le grain de toile : dent anisotrope à ~1 %, légèrement advectée —
    // ce qui tue le look « vecteur plat » sans un seul point scintillant
    float grain = vnoise(float2(p.x * 220.0, p.y * 90.0)
                         + float2(0.0, 0.35 * t)) - 0.5;
    outc += grain * 0.012 * (0.25 + 0.75 * alphaBody);

    // dither léger contre le banding
    float n = fhash21(position * 1.7 + 13.1) - 0.5;
    outc += n * (1.6 / 255.0);

    return half4(half3(saturate(outc)), 1.0h) * color.a;
}
