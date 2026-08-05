//
//  FlameJewel.metal
//  Woop
//
//  La flamme néon : l'anatomie de l'émoji feu — la robe aux trois pointes,
//  la goutte intérieure — dessinée en TUBES de lumière sur la nuit, le même
//  ADN que la lune du logo. Le trait est la source : un cœur blanc qui
//  n'est pas peint mais FABRIQUÉ (énergie surchargée + tone mapping
//  filmique — la clé anti-criard du logo), des flancs jaunes courts, une
//  gaine orange, un halo rouge qui saigne loin. Le dégradé blanc→jaune→rouge
//  vit deux fois : en travers du trait, et le long de la hauteur (les bas
//  dorés et chargés, les pointes rouges et fines).
//
//  La chorégraphie est MAJESTUEUSE, jamais agitée : ondoiement maître 7,3 s
//  à base ancrée (le haut en retard de phase), la goutte qui suit la robe
//  avec 0,4 s de décalage (la parallaxe fait la profondeur), des crans qui
//  croissent et se résorbent sur ~11 et ~17 s, la respiration du tube à
//  voix incommensurables (8,9 / 17,0 / 39,1 s — celles de la lune), un
//  point chaud qui voyage le long du tracé, et toutes les ~8 s une
//  gouttelette de néon qui se détache de l'apex, monte et s'éteint.
//
//  Le doigt tourne (3D légère : parallaxe robe/goutte + amincissement de
//  trois quarts, dôme de laque sombre derrière). Le tap : surtension du
//  tube, gerbe de braises, fumée orange en filaments depuis l'apex.
//
//  Tout est FONCTION PURE du temps et des horodatages.
//

#include <metal_stdlib>
using namespace metal;

// MARK: - Outils

static inline float fj_hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static inline float fj_noise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = fj_hash(i);
    float b = fj_hash(i + float2(1, 0));
    float c = fj_hash(i + float2(0, 1));
    float d = fj_hash(i + float2(1, 1));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static inline float fj_fbm(float2 p) {
    float v = 0.0, a = 0.55;
    for (int i = 0; i < 3; i++) {
        v += a * fj_noise(p);
        p = p * 2.03 + float2(11.7, 5.3);
        a *= 0.5;
    }
    return v;
}

static inline float fj_smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

/// Soustraction douce : creuser une région dans une forme sans coin dur.
static inline float fj_smax(float a, float b, float k) {
    return -fj_smin(-a, -b, k);
}

/// Distance exacte à une Bézier quadratique (iq), + l'abscisse t du point le
/// plus proche — elle pilote l'effilement des tracés.
static inline float2 fj_bezier(float2 pos, float2 A, float2 B, float2 C) {
    float2 a = B - A;
    float2 b = A - 2.0 * B + C;
    float2 c = a * 2.0;
    float2 d = A - pos;
    float kk = 1.0 / max(dot(b, b), 1e-5);
    float kx = kk * dot(a, b);
    float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
    float kz = kk * dot(d, a);
    float res, tOut;
    float p = ky - kx * kx;
    float p3 = p * p * p;
    float q = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
    float h = q * q + 4.0 * p3;
    if (h >= 0.0) {
        h = sqrt(h);
        float2 x = (float2(h, -h) - q) / 2.0;
        float2 uv = sign(x) * pow(abs(x), float2(1.0 / 3.0));
        float tt = clamp(uv.x + uv.y - kx, 0.0, 1.0);
        float2 qv = d + (c + b * tt) * tt;
        res = dot(qv, qv);
        tOut = tt;
    } else {
        float z = sqrt(-p);
        float v = acos(clamp(q / (p * z * 2.0), -1.0, 1.0)) / 3.0;
        float m = cos(v), n = sin(v) * 1.732050808;
        float3 tt = clamp(float3(m + m, -n - m, n - m) * z - kx, 0.0, 1.0);
        float2 q0 = d + (c + b * tt.x) * tt.x;
        float2 q1 = d + (c + b * tt.y) * tt.y;
        float d0 = dot(q0, q0), d1 = dot(q1, q1);
        if (d0 <= d1) { res = d0; tOut = tt.x; }
        else          { res = d1; tOut = tt.y; }
    }
    return float2(sqrt(res), tOut);
}

// MARK: - Les tracés (la calligraphie)

/// La robe : la goutte au S — creux à gauche, apex qui se recourbe à
/// droite — et deux crans latéraux joints en V VIFS (min franc, jamais de
/// fondu : c'est le pli net qui fait l'enseigne pliée à la main).
/// `mL`/`mR` : la métamorphose lente des crans.
static inline float fj_robe(float2 p, float mL, float mR) {
    // Les griffes d'abord : leur champ sert aussi de BURIN pour les V.
    // B pousse au LARGE (±1,26) : la quadratique longe l'ellipse — le
    // manchon autour d'elle preserve le rim, et tout ce qui est en dedans
    // au-dessus de y = 0,36 est rendu a la nuit. La droite est posee plus
    // BAS que la gauche (0,715 vs 0,775) : l'asymetrie de l'enseigne pliee
    // a la main vit en hauteur ET en epaisseur.
    float2 b2 = fj_bezier(p, float2(-0.32, -0.04), float2(-1.10, 0.42),
                          float2(-0.685, 0.775));
    float2 b3 = fj_bezier(p, float2(0.32, -0.04), float2(1.26, 0.26),
                          float2(0.735, 0.715));
    float wL = mix(0.130 * mL, 0.008, pow(b2.y, 0.85));
    float wR = mix(0.170 * mR, 0.008, pow(b3.y, 0.85));

    // Le lobe, CISAILLE vers la gauche sous l'apex (la jupe de la ref
    // balaie a gauche ; l'apex ne bouge pas), pointe epaissie (0,026 :
    // les flancs restent fusionnes ~0,035 sous la pointe — une pointe
    // calligraphiee, pas une epingle).
    float2 pl = p;
    pl.x += 0.20 * smoothstep(1.05, 0.35, p.y);
    float2 b1 = fj_bezier(pl, float2(0.0, -0.25), float2(0.42, 1.24),
                          float2(-0.195, 1.64));
    float lobe = b1.x - mix(0.63, 0.026, pow(b1.y, 1.42));

    // L'anneau en oeuf (rx/ry 0,90 — mesure ref 0,905).
    float2 ec = p - float2(0.0, -0.02);
    ec.y *= 0.900;
    float dc = (length(ec) - 0.98) / 0.900;
    // Les V : creuses par le champ des griffes — la nuit s'ouvre partout
    // au-dessus de y = 0,36 HORS du manchon (largeur de griffe + 0,012),
    // qui s'effile avec elle : le rim reste INTACT jusqu'aux pointes qui
    // le capuchonnent, plus jamais de moignon de coupe. Le chapeau
    // au-dessus de la ligne des pointes fait le reste.
    float vL = max((0.20 + 1.35 * max(0.0, abs(p.x) - 0.58)) - p.y,
                   (wL + 0.012 + 0.075 * pow(b2.y, 2.2)) - b2.x);
    float vR = max((0.20 + 1.35 * max(0.0, abs(p.x) - 0.58)) - p.y,
                   (wR + 0.042 + 0.075 * pow(b3.y, 2.2)) - b3.x);
    dc = fj_smax(dc, -vL, 0.05);
    dc = fj_smax(dc, -vR, 0.05);
    // Le chapeau : l'arc se termine par une face RADIALE a chaque pointe
    // (le long de la normale a l'ellipse) — jamais une tranche horizontale.
    float capL = -dot(p - float2(-0.685, 0.775),
                      normalize(float2(-0.685, 0.644)));
    float capR = -dot(p - float2(0.735, 0.715),
                      normalize(float2(0.735, 0.595)));
    dc = fj_smax(dc, -capL, 0.05);
    dc = fj_smax(dc, -capR, 0.05);
    float d = fj_smin(lobe, dc, 0.22);
    // La TAILLE du flanc droit : le galbe rentre de la ref.
    float2 lp = p - float2(0.58, 0.62);
    d += 0.050 * exp(-dot(lp, lp) / 0.09);
    // ... et le flanc GAUCHE pousse dehors, en miroir : la jupe de la ref
    // descend a -0,63 a f0,60 — sans cette lentille elle rentre a -0,53.
    float2 lq = p - float2(-0.50, 0.56);
    d -= 0.045 * exp(-dot(lq, lq) / 0.07);
    // Les griffes posees en dernier, immunisees contre tous les burins.
    d = min(d, b2.x - wL);
    d = min(d, b3.x - wR);
    return d;
}

/// La goutte intérieure : une base ronde et une pointe désaxée, fondues —
/// elle est calligraphiée à part, ce n'est PAS la robe réduite.
static inline float fj_goutte(float2 p) {
    // Un cercle + un CÔNE TANGENT, DÉSAXÉS : le ventre penche à droite
    // (+0,035), la pointe finit à GAUCHE de l'axe du ventre — le même
    // sens que le flick d'apex de la robe. C'est ce désaxement de 4 %
    // qui fait calligraphié plutôt que géométrique. La largeur file en
    // loi 1,55 : le fuseau s'allonge sans s'amaigrir.
    float d = length(p - float2(0.035, -0.18)) - 0.52;
    float2 b = fj_bezier(p, float2(0.035, -0.18), float2(-0.01, 0.48),
                         float2(-0.03, 1.02));
    d = fj_smin(d, b.x - mix(0.48, 0.005, smoothstep(0.0, 1.0, pow(b.y, 1.9))), 0.035);
    return d;
}

// MARK: - Le tube

/// Le néon de la maison : quatre couches de lumière pour UN trait — cœur
/// blanc (fabriqué par la saturation du tone mapping, jamais peint), flancs
/// jaunes, gaine orange, halo rouge. `hgt` fait glisser toute la parure du
/// doré (en bas) vers le rouge (aux pointes) ; `m` est la modulation
/// locale (respiration, point chaud, surtension du tap).
static inline float3 fj_tube(float d, float hgt, float m, float wScale) {
    // Le cœur reste BLANC sur TOUTE la calligraphie (la référence le garde
    // jusqu'à cinq pixels des pointes) : c'est l'ÉPAULE qui rougit en
    // montant, jamais le filament. Et le halo est TENU court — la nuit
    // retombe sous 8/255 à deux rayons d'anneau, c'est le contraste qui
    // claque, pas la quantité de lumière.
    // Le tube de la ref est ORANGE a filament IVOIRE (253,250,212 sur
    // 1-3 px), jamais un fil blanc frange d'orange : le coeur est un
    // creme chaud, fin (~0,4 % de la largeur de flamme), et c'est la
    // GAINE orange qui porte la masse. Aucun rouge nulle part : le bord
    // le plus froid de la ref reste un orange franc (G/R 0,45) — la
    // pointe est un orange PLUS DENSE, pas un brun.
    float hR = pow(hgt, 1.55);
    float3 cW = mix(float3(1.05, 0.32, 0.16), float3(1.02, 0.30, 0.18),
                    pow(hgt, 3.2));
    float3 cY = mix(float3(1.00, 0.78, 0.26), float3(1.00, 0.56, 0.15), hR);
    float3 cO = mix(float3(1.00, 0.42, 0.10), float3(0.99, 0.38, 0.10), hR);
    float3 cR = mix(float3(1.00, 0.38, 0.11), float3(0.94, 0.24, 0.07), hR);
    // Le pic du tube plafonne CREME (B/R 0,64 comme la ref), jamais au
    // blanc : l'energie bleue a d=0 reste sous le coude du tone mapping.
    // Gaussiennes ETROITES + traine exponentielle longue (le profil
    // 1 : 2,2 : 5,2 de la ref) : le tranchant vient des largeurs, la
    // presence vient de la traine.
    float w0 = 0.0056 * wScale, w1 = 0.013 * wScale;
    float w2 = 0.052 * wScale, w3 = 0.115 * wScale;
    float aW = mix(3.6, 2.7, pow(hgt, 3.0));
    float3 e = cW * (aW * exp(-(d * d) / (w0 * w0)))
             + cY * (1.30 * exp(-(d * d) / (w1 * w1)))
             + cO * (1.15 * exp(-(d * d) / (w2 * w2)))
             + cR * (0.48 * exp(-abs(d) / w3));
    return e * m;
}

// MARK: - La fumée

/// Une bouffée : un panache de filaments qui monte de l'apex, s'élargit et
/// s'éteint en ~3 s.
static inline float3 fj_puff(float2 w, float2 o, float a, float seed,
                             thread float &alpha) {
    alpha = 0.0;
    if (a < 0.0 || a > 3.2) return float3(0.0);
    float2 rel = w - o;
    float up = rel.y;
    if (up < -0.3 || up > 4.6) return float3(0.0);

    float rise = 2.3 * (1.0 - exp(-a * 0.7)) + 0.3 * a;
    float drift = 0.18 * sin(seed * 9.0 + a * 0.9);
    float lat = rel.x - drift * up
              - 0.16 * sin(up * 2.1 - a * 1.6 + seed * 6.28)
              - 0.05 * sin(up * 5.0 + a * 2.3);
    float width = 0.20 + 0.24 * max(up, 0.0) + 0.12 * a;
    float env = exp(-(lat * lat) / (width * width));
    env *= smoothstep(-0.12, 0.30, up);
    env *= smoothstep(rise + 0.55, rise - 1.0, up);

    float2 q = float2(rel.x * 2.4, rel.y * 1.35 - a * 2.2);
    q.x += 0.6 * sin(a * 1.2 + up * 1.4 + seed * 12.0);
    float n = fj_fbm(q + seed * 31.0);
    float wisp = pow(smoothstep(0.30, 0.85, n), 1.2);

    float fade = smoothstep(0.0, 0.16, a) * (1.0 - smoothstep(1.9, 3.1, a));
    alpha = clamp(env * wisp * fade * 0.95, 0.0, 0.75);

    float3 warm = mix(float3(0.80, 0.16, 0.05), float3(1.0, 0.52, 0.15),
                      clamp(n * 1.3 - 0.2, 0.0, 1.0));
    warm = mix(warm, float3(1.0, 0.72, 0.28),
               smoothstep(0.5, -0.2, up) * 0.6);
    return warm;
}

// MARK: - Les braises (le pointillisme)

/// Rares, petites, à scintillement lent. `burst` (le tap) fait éclore une
/// gerbe le temps d'un souffle. `dR` (la distance à la robe) les tient HORS
/// du verre : la référence n'a aucune moucheture posée sur le tracé — les
/// braises ne vivent qu'au-dessus de l'apex, dans la nuit libre.
static inline float3 fj_embers(float2 w, float t, float yaw, float burst,
                               float dR) {
    float3 acc = float3(0.0);
    float2 rw = (w - float2(0.0, 0.45)) / float2(1.6, 1.9);
    float prox = exp(-dot(rw, rw) * 1.3);
    float hors = smoothstep(0.0, 0.30, dR);
    if (prox * hors < 0.10) return acc;

    for (int s = 0; s < 2; s++) {
        float sc = (s == 0) ? 2.2 : 3.4;
        float2 gp = w * sc + float2(yaw * 0.15 + float(s) * 17.0, 0.0);
        gp.y -= t * (0.24 + 0.16 * float(s));
        float2 cell = floor(gp);
        float r0 = fj_hash(cell);
        if (r0 > 0.12 + 0.30 * min(burst, 1.0)) continue;
        float2 jit = float2(fj_hash(cell + 7.1), fj_hash(cell + 3.7));
        float2 f = fract(gp) - (0.2 + 0.6 * jit);
        float r1 = fj_hash(cell + 11.3);
        float tw = 0.25 + 0.75 * pow(0.5 + 0.5 * sin(t * (1.1 + 2.6 * r1)
                                                     + r1 * 40.0), 2.0);
        float g = exp(-dot(f, f) * (300.0 * sc));
        float3 tint = mix(float3(1.0, 0.72, 0.25), float3(1.0, 0.28, 0.08),
                          fj_hash(cell + 5.9));
        acc += tint * g * tw * 0.42 * prox * hors;
    }
    return acc;
}

// MARK: - Le shader

/// `size` en points, `t` l'horloge mod 900, `yaw` le lacet du doigt (rad),
/// `reveal` la rampe d'arrivée [0,1], `puffs` les âges des deux dernières
/// bouffées (négatif = pas de bouffée).
[[ stitchable ]] half4 flameJewel(float2 position, half4 color, float2 size,
                                  float t, float yaw, float reveal,
                                  float2 puffs) {
    float su = size.x / 4.6;
    float2 w = float2((position.x - size.x * 0.5) / su,
                      (size.y * 0.58 - position.y) / su);

    float rv = reveal * reveal * (3.0 - 2.0 * reveal);
    const float TAU = 6.2831853;

    // La surtension du tap.
    float flare = 0.0;
    for (int i = 0; i < 2; i++) {
        float a = (i == 0) ? puffs.x : puffs.y;
        if (a >= 0.0 && a < 3.2) flare += exp(-3.0 * a);
    }
    flare = min(flare, 1.2);

    // Le lacet : le doigt + une dérive propre, très lente.
    float yawT = yaw + 0.05 * sin(TAU * t / 19.0) + 0.02 * sin(TAU * t / 7.7);
    float squeeze = 1.0 / (0.84 + 0.16 * cos(yawT));

    // Le dôme de laque sombre : l'objet est POSÉ dans un monde. À peine
    // au-dessus du noir, éclairé par le bas où vit le néon.
    float rr = length((w - float2(0.0, 0.25)) * float2(0.50, 0.44));
    float3 col = float3(0.085, 0.032, 0.015)
               * (1.0 - smoothstep(0.18, 1.30, rr))
               * (0.55 + 0.45 * smoothstep(1.1, -0.9, w.y))
               * (1.0 + flare * 0.7);

    // La respiration du néon : trois voix incommensurables (celles de la
    // lune : 8,9 / 17,0 / 39,1 s) — jamais le métronome.
    float breath = 1.0 + 0.050 * sin(TAU * t / 8.9 + 1.7)
                       + 0.035 * sin(TAU * t / 17.0 + 4.2)
                       + 0.020 * sin(TAU * t / 39.1 + 0.6);

    bool nearFlame = abs(w.x) < 2.6 && w.y > -2.4 && w.y < 3.0;
    // La distance à la robe, portée hors du bloc pour les braises (loin
    // de la flamme, elle vaut « très loin » : les braises y sont libres).
    float dRE = 1e3;
    if (nearFlame) {
        // ---- L'ondoiement maître : base ancrée, le haut en retard.
        float anchor = smoothstep(-0.7, 1.6, w.y);
        float delay = 0.35 * (w.y + 1.0);
        float swR = 0.10 * sin(TAU * (t - delay) / 7.3)
                  + 0.035 * sin(TAU * (t - delay) / 11.7 + 1.3);
        float swG = 0.10 * sin(TAU * (t - delay - 0.4) / 7.3)
                  + 0.035 * sin(TAU * (t - delay - 0.4) / 11.7 + 1.3);
        float bend = anchor * (0.30 + 0.70 * anchor);

        // ---- La robe.
        float2 qR = w - float2(yawT * 0.08, 0.28);
        qR.x = qR.x * squeeze - bend * swR;
        float mL = 1.0 + 0.12 * sin(TAU * t / 17.3 + 0.9);
        float mR = 1.0 + 0.12 * sin(TAU * t / 11.1 + 3.9);
        float dR = fj_robe(qR, mL, mR);
        dRE = dR;

        // ---- La goutte : plus de parallaxe, un temps de retard. Elle est
        // POSÉE bas — son tube vient embrasser l'anneau du bas et les deux
        // lumières fusionnent en une seule bande blanche (la référence).
        float2 qG = w - float2(yawT * 0.26, 0.28);
        qG.x = qG.x * squeeze - bend * swG;
        float2 qD = (qG - float2(0.0, -0.45)) / 0.83;
        float dG = fj_goutte(qD) * 0.83;

        // ---- La modulation du tube : respiration, et le point chaud qui
        // voyage le long du tracé. Le tube garde la MÊME grosseur de
        // l'apex à la base (la référence) : seule sa COULEUR glisse vers
        // le rouge — le plancher est haut, le bas à peine plus chargé.
        float hgt = pow(smoothstep(-0.85, 1.05, qR.y), 1.35);
        float theta = atan2(qR.y - 0.28, qR.x);
        float phi = TAU * fract(t / 13.7);
        float hot = exp(3.5 * (cos(theta - phi) - 1.0));
        float m = (1.00 + 0.22 * smoothstep(0.15, -0.95, qR.y) + 0.45 * hot)
                * breath * (1.0 + 0.9 * flare);

        col += fj_tube(dR, hgt, m,
                       mix(1.00, 1.26, smoothstep(0.15, 0.95, hgt)));
        // La goutte : son tube pèse AUTANT que celui de la robe sur TOUT
        // le périmètre — la pointe et les flancs hauts ne se noient plus
        // dans le remplissage, la fusion n'a lieu qu'en bas.
        float hgtG = smoothstep(-0.6, 1.5, qG.y);
        float mG = (1.02 + 0.45 * smoothstep(0.1, -0.9, qD.y)) * breath
                 * (1.0 + 1.1 * flare);
        // La pointe de goutte prend le même rouge que les pointes de robe.
        col += fj_tube(dG, hgtG * 0.85, mG, mix(1.12, 0.94, hgtG));

        // ---- Les intérieurs : des champs séparés, jamais un voile unique.
        // La robe : un souffle sombre + la lumière qui colle à la paroi.
        if (dR < 0.0) {
            // La goutte OCCULTE le bain : elle est un corps de verre posé
            // DEVANT la robe — la référence n'additionne jamais les deux
            // lumières, sinon l'axe de la goutte tourne au lait.
            float occl = smoothstep(-0.03, 0.14, dG);
            // Le tube ÉCLAIRE ce qu'il enferme : la nuit franche ne règne
            // qu'au-dessus des griffes — le bain remonte jusqu'à leur
            // racine, jamais le noir absolu à deux millimètres du trait.
            col += float3(1.00, 0.40, 0.125)
                 * (0.15 + 0.85 * smoothstep(0.45, -1.05, qR.y))
                 * (1.0 + 0.4 * flare) * occl;
            // Le collage-paroi : un biseau long, jamais NUL en haut —
            // c'est lui qui décolle le sticker de la nuit.
            col += float3(1.0, 0.42, 0.11) * exp(dR / 0.24) * 0.36
                 * (0.60 + 0.40 * smoothstep(0.55, -1.00, qR.y)) * breath;
            // La CUVETTE : entre goutte et anneau, le bain qui monte vers
            // l'or blanc — généreuse et sans brutalité, jamais l'aplat.
            col += float3(1.0, 0.46, 0.17)
                 * pow(smoothstep(-0.20, -1.12, qR.y), 1.15) * 0.80
                 * breath * occl;
        }
        // La goutte : rétroéclairée par son tube, le cœur d'or qui monte
        // au blanc à sa base — le point le plus chaud de l'image.
        if (dG < 0.0) {
            // La goutte est un corps PLEIN aux QUATRE stations de la
            // référence : sombre → ambre → OR → blanc — la rampe est
            // LONGUE (1,02 → -0,74) pour que jamais deux stations ne se
            // télescopent en bande laiteuse.
            float gBase = smoothstep(1.02, -0.74, qD.y);
            // La lueur de paroi : allumée même sous la pointe, comme la
            // zone étroite juste sous l'apex de goutte de la référence.
            col += float3(1.0, 0.36, 0.09) * exp(dG / 0.20)
                 * (0.20 + 0.22 * gBase) * breath;
            // Le ventre : un PLANCHER d'ambre rétroéclairé — le rouge ne
            // faiblit jamais, même au tiers haut, jamais la caverne.
            col += float3(1.0, 0.27, 0.075) * (1.08 + 1.05 * pow(gBase, 0.80))
                 * breath;
            // L'or des hanches, allongé : il occupe le terrain que le
            // blanc a rendu (le bleu tenu court : or, jamais blanchi).
            col += float3(1.0, 0.55, 0.12) * pow(gBase, 2.8) * 1.45
                 * (1.0 + 0.9 * flare);
            // Le blanc chaud : resserré à la TOUTE base et coupé de bleu
            // — le blanc naît du tone mapping aux derniers pourcents,
            // jamais d'un plateau peint qui crame.
            col += float3(1.06, 0.74, 0.24) * pow(gBase, 18.0) * 2.3
                 * (1.0 + 1.2 * flare);
            // LA fusion avec le tube : confinée au dernier millimètre du
            // liseré — le rim disparaît en bas, jamais les flancs.
            col += float3(1.05, 0.74, 0.24) * exp(dG / 0.026)
                 * pow(gBase, 6.0) * 1.5;
        }

        // ---- L'événement : toutes les ~8 s, une gouttelette de néon se
        // détache de l'apex, monte, s'affine, s'éteint.
        float cyc = floor(t / 7.9);
        float rE = fj_hash(float2(cyc, 0.31));
        if (rE < 0.72) {
            float fr = fract(t / 7.9);
            float env = smoothstep(0.05, 0.22, fr)
                      * (1.0 - smoothstep(0.55, 0.90, fr));
            if (env > 0.001) {
                float2 pe = float2(0.07 + 0.28 * (rE - 0.5)
                                   + 0.12 * sin(fr * 5.0 + rE * 30.0),
                                   1.50 + fr * 1.05);
                float se = 0.075 * (1.0 - 0.45 * fr);
                // Une goutte de lumière PLEINE, étirée vers le haut — pas
                // un anneau : le contour creux photographiait une bulle.
                // Discrète : une étincelle qui s'échappe, pas un fanal.
                float2 ve = (qR - pe) * float2(1.0, 0.62) / se;
                float eg = exp(-dot(ve, ve) * 3.0);
                col += mix(float3(1.0, 0.44, 0.12), float3(1.0, 0.72, 0.34),
                           eg) * eg * env * 0.85 * breath;
            }
        }
    }

    // Le pointillisme des braises — le tap en fait éclore une gerbe.
    col += fj_embers(w, t, yawT, flare, dRE);

    // La fumée, par-dessus tout : née de l'apex, tournée avec la flamme.
    float2 oSmoke = float2(0.07 + yawT * 0.30, 1.85);
    for (int i = 0; i < 2; i++) {
        float a = (i == 0) ? puffs.x : puffs.y;
        float sa;
        float3 sc = fj_puff(w, oSmoke, a, 0.37 + float(i) * 0.41, sa);
        col = mix(col, sc, sa);
        col += sc * sa * 0.22;
    }

    // Le blanc FABRIQUÉ : tone mapping filmique de l'énergie surchargée.
    col = 1.0 - exp(-col);
    col = clamp(col, 0.0, 1.0) * rv;
    return half4(half3(col), 1.0h);
}
