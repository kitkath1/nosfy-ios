#include <metal_stdlib>
using namespace metal;

// MARK: - Le cadran éclipse
//
// Un disque de velours noir posé sur la nuit, et derrière lui quatre lumières
// qui tournent — deux blanches lunaires, deux dorées — chacune à son tempo,
// comme quatre voix d'un même mouvement lent. Le disque les occulte : la
// lumière ne vit qu'au-delà du bord, en couronne, étirée le long du cercle.
// Le liseré hairline s'allume localement au passage de chaque halo, et le
// velours attrape un souffle de leur couleur près du bord.
//
// Au toucher : UNE bouffée, pas un état. Les quatre voix enflent un instant,
// une onde part du bord, et des volutes de fumée fractale S'ÉCHAPPENT du
// cadran en glissant vers l'extérieur, puis tout se dissout en une seconde —
// le cadran répond au doigt, il ne se transforme pas. (Les étoiles-bijou
// intérieures ont été essayées puis retirées : « cheap » au verdict.)

static float ehash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float enoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = ehash21(i);
    float b = ehash21(i + float2(1.0, 0.0));
    float c = ehash21(i + float2(0.0, 1.0));
    float d = ehash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float efbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * enoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

// Les quatre voix. Périodes d'orbite et de respiration toutes différentes et
// sans rapport entier : le mouvement ne boucle jamais à l'œil.
//   0 « la basse »   — blanc lunaire, large et lent, sens horaire (47 s)
//   1 « l'alto »     — or profond, serré contre le bord, anti-horaire (29 s)
//   2 « le soprano » — blanc pur, petit et vif (19 s)
//   3 « le ténor »   — champagne, très large, presque immobile (71 s)
//
// `puff` : l'enveloppe de la bouffée (attaque 0,10 s, extinction ~0,7 s,
// calculée côté SwiftUI depuis l'horodatage du tap). `age` : secondes depuis
// le tap — c'est lui qui fait GLISSER les volutes vers l'extérieur et qui
// porte l'onde du toucher. Au repos : puff = 0, age grand, tout dort.
[[ stitchable ]] half4 eclipseHalo(float2 position, half4 color,
                                   float2 size, float t, float R,
                                   float puff, float age,
                                   float ignite, float gloss) {
    // Deux blancs purs, deux ors réchauffés d'orange (demande du 2026-07-30 :
    // « une teinte légèrement orangée en plus dans les halos »).
    const float3 cols[4] = { float3(0.93, 0.95, 1.00),
                             float3(1.00, 0.70, 0.33),
                             float3(1.00, 1.00, 1.00),
                             float3(1.00, 0.78, 0.50) };
    const float speed[4] = {  6.2832 / 47.0, -6.2832 / 29.0,
                              6.2832 / 19.0, -6.2832 / 71.0 };
    const float phase[4] = { 0.4, 2.6, 4.4, 5.6 };
    const float rho0[4]  = { 1.02, 0.98, 1.01, 1.14 };
    const float srs[4]   = { 0.34, 0.19, 0.10, 0.42 };   // σ radial (× R)
    const float sts[4]   = { 0.66, 0.50, 0.34, 0.72 };   // σ d'arc (× R)
    const float bper[4]  = { 13.0, 8.1, 5.2, 21.0 };     // respiration (s)
    const float bbase[4] = { 0.72, 0.62, 0.50, 0.66 };
    const float bamp[4]  = { 0.28, 0.38, 0.50, 0.30 };
    const float wgt[4]   = { 0.50, 0.85, 0.85, 0.32 };
    const float kap[4]   = { 5.0, 9.0, 22.0, 3.5 };      // finesse sur le liseré

    float2 p = position - size * 0.5;
    float r = length(p);
    float2 n = r > 0.5 ? p / r : float2(0.0, -1.0);

    // L'occultation : la lumière n'existe qu'au-delà du bord du disque.
    float occ = smoothstep(R - 0.5, R + 1.8, r);
    // L'intérieur du velours (opaque) — c'est lui qui fait l'éclipse.
    float insideDisc = 1.0 - smoothstep(R - 1.0, R + 0.5, r);

    float3 light = float3(0.0);
    float3 rimGlow = float3(0.0);
    float3 backTint = float3(0.0);
    float3 smokeGlow = float3(0.0);
    float3 reflGlow = float3(0.0);
    for (int i = 0; i < 4; i++) {
        float ang = phase[i] + t * speed[i];
        float2 hd = float2(cos(ang), sin(ang));
        // La distance au centre respire elle aussi, très légèrement. À la
        // bouffée, les voix s'écartent À PEINE : une respiration, pas un show.
        float rho = R * (rho0[i] + 0.05 * sin(t * 6.2832 / (bper[i] * 2.7)
                                              + phase[i] * 3.0)
                         + 0.03 * puff);
        // Coordonnées POLAIRES autour du disque : l'étirement suit l'ARC —
        // le halo se COURBE en croissant qui épouse le bord, au lieu de
        // s'allonger en barre droite le long d'une tangente (l'effet
        // « rectangulaire » des grandes voix).
        float angP = atan2(p.y, p.x);
        float dAng = angP - ang;
        dAng -= 6.2832 * floor(dAng / 6.2832 + 0.5);   // repli sur [-π, π]
        float rad = r - rho;
        float arc = dAng * max(rho, 1.0);
        float sr = srs[i] * R * (1.0 + 0.26 * puff);
        float sg = sts[i] * R * (1.0 + 0.18 * puff);
        float q = (rad * rad) / (sr * sr) + (arc * arc) / (sg * sg);
        float breath = bbase[i] + bamp[i] * sin(t * 6.2832 / bper[i]
                                                + phase[i] * 5.0);
        // Un cœur discret dans un VOILE large : la lumière diffuse loin,
        // sans jamais dessiner son enveloppe.
        float g = 0.52 * exp(-q) + 0.48 * exp(-q * 0.32);
        // L'allumage en canon de la naissance : la basse d'abord, puis les
        // voix hautes — à ignite = 1 (le régime courant), rien ne change.
        float ig = clamp(ignite * 1.9 - float(i) * 0.24, 0.0, 1.0);
        ig = ig * ig * (3.0 - 2.0 * ig);
        float w = wgt[i] * (1.0 + 0.35 * puff) * ig;
        light += cols[i] * (g * breath * w);
        // Ce que chaque voix pose sur le liseré et sur le velours.
        float facing = max(dot(n, hd), 0.0);
        rimGlow  += cols[i] * (pow(facing, kap[i]) * breath * w);
        backTint += cols[i] * (pow(facing, 2.5) * breath * w);
        // Et ce qu'elle donne à la fumée : une loi bien plus serrée — les
        // volutes ne jaillissent que FACE aux voix, l'ombre entre elles
        // reste muette (sinon quatre voix couvrent tout : donut gris).
        smokeGlow += cols[i] * (pow(facing, 7.0) * breath * w);
        // Et son REFLET dans la laque du disque (liquid glass noir).
        reflGlow += cols[i] * (pow(facing, kap[i] * 0.5 + 2.0) * breath * w);
    }

    // La couronne : hairline au bord exact, faible partout, vive au passage
    // des halos, avec les accents-bijou de la famille diamant.
    float dr2 = (r - R) * (r - R);
    float ring = exp(-dr2 / 1.35);
    float acc = efbm(p * 0.05 + float2(t * 0.11, -t * 0.07));
    acc = acc * acc * acc;
    float3 rim = (float3(0.05) + rimGlow * (0.55 + 2.2 * acc))
                 * ring * (1.0 + 0.30 * puff);

    // L'onde du toucher : un anneau qui part du liseré, s'évase et s'éteint
    // en un tiers de seconde — elle vieillit avec `age`, pas avec l'enveloppe.
    float waveAmp = exp(-age / 0.32);
    if (waveAmp > 0.01) {
        float ringR = R + age * 190.0;
        float rw = 6.0 + age * 40.0;
        float wave = exp(-(r - ringR) * (r - ringR) / (rw * rw));
        light += float3(0.95, 0.96, 1.00) * (wave * waveAmp * 0.30);
    }

    // La bouffée : au tap, des volutes fractales S'ÉCHAPPENT du cadran —
    // domaine deux fois déformé (elles se tordent au lieu de glisser en
    // nappe), et le champ est échantillonné de plus en plus LOIN vers
    // l'intérieur à mesure que `age` grandit : les volutes glissent
    // visiblement vers l'extérieur, puis l'enveloppe les dissout. Tout ce
    // bloc dort au repos : rien ne coûte quand personne ne touche.
    float3 smokeOut = float3(0.0);
    if (puff > 0.004 && r > R - 3.0) {
        float2 slide = n * (age * 85.0);
        float2 sc = (p - slide) * 0.022;
        float2 drift = float2(t * 0.030, -t * 0.017);
        float q1 = efbm(sc + drift);
        float w2 = efbm(sc * 1.7 - drift * 0.8 + 2.3 * q1);
        float s = efbm(sc * 1.31 + float2(2.2 * q1, -1.6 * w2) - drift * 0.6);
        // Exposant haut : des FILAMENTS qui se tordent, avec des TROUS —
        // jamais un donut de brume uniforme autour du cadran.
        s = pow(clamp(s, 0.0, 1.0), 3.1);
        float out = max(r - R, 0.0);
        // La portée s'ouvre avec la bouffée puis se referme avec elle.
        float envel = exp(-out / (R * (0.14 + 0.26 * puff)));
        // La fumée est ÉCLAIRÉE par les quatre voix, elle n'est pas un voile
        // gris : elle fleurit face aux lumières et se tait presque dans
        // l'ombre — c'est le contraste angulaire qui tue le donut.
        float glowLum = clamp(dot(smokeGlow, float3(0.42)), 0.0, 1.0);
        float3 lit = mix(float3(0.86, 0.88, 0.94),
                         normalize(smokeGlow + 1e-4), 0.62);
        smokeOut = lit * (puff * envel * s * 0.62 * occ
                          * (0.06 + 0.94 * glowLum));
    }

    // Le velours : noir absolu au centre (le chrono vit là), un souffle de
    // matière près du bord — qui attrape la couleur de la lumière derrière.
    float edge = pow(clamp(r / max(R, 1.0), 0.0, 1.0), 5.0);
    float cloth = 0.80 + 0.40 * efbm(p * 0.02 + float2(7.0, 3.0));
    float3 velvet = (float3(0.008, 0.008, 0.011) + backTint * 0.05)
                    * (edge * cloth);
    // Liquid glass noir (gloss > 0) : le velours devient laque. Les quatre
    // voix se REFLÈTENT dans le disque — arcs doux couchés contre le bord
    // interne — et une nappe froide vernit le haut du dôme. À gloss = 0,
    // le velours d'origine est intouché.
    if (gloss > 0.001) {
        float nrD = clamp(r / max(R, 1.0), 0.0, 1.0);
        float innerBand = smoothstep(0.40, 0.88, nrD)
                          * (1.0 - smoothstep(0.945, 1.0, nrD));
        float3 lacquer = reflGlow * (innerBand * 0.30);
        float sheenUp = pow(clamp(-p.y / max(R, 1.0), 0.0, 1.0), 2.4);
        lacquer += float3(0.72, 0.78, 0.92) * (sheenUp * innerBand * 0.062);
        velvet += lacquer * (gloss * insideDisc);
    }

    // Le fondu de l'hôte : TOUTE la lumière extérieure meurt dans le noir
    // bien avant le bord du rectangle du shader — sinon le premier tap
    // révèle que le théâtre vit dans un carré.
    float halfSide = min(size.x, size.y) * 0.5;
    float hostFade = 1.0 - smoothstep(halfSide - 64.0, halfSide - 8.0, r);
    float3 c = (light * occ + smokeOut) * hostFade + rim
               + velvet * insideDisc;
    // L'alpha : dehors, seule la lumière existe — le cadran ne peint jamais
    // un carré noir par-dessus la page (le spotlight du fond doit passer
    // partout où il n'y a rien). La couleur reste PLEINE (on ne la multiplie
    // pas par la couverture : la lumière s'ajoute, elle ne se voile pas —
    // multiplier éteindrait tous les tons moyens des halos).
    float lightA = clamp(max(max(c.r, c.g), c.b) * 2.6, 0.0, 1.0);
    float a = mix(lightA, 1.0, insideDisc);
    // Tone mapping filmique : les superpositions saturent en douceur.
    c = 1.0 - exp(-c * 1.55);
    // Grain argentique, discret et vivant (re-semé ~12 fois par seconde).
    float grain = (ehash21(position * 1.31
                           + float2(fmod(floor(t * 12.0), 120.0) * 7.3, 0.0))
                   - 0.5) * 0.016;
    c = max(c + grain * a, 0.0);
    return half4(half3(c), half(a)) * color.a;
}

// MARK: - Le spotlight de la nuit
//
// Sous tout le reste : un pinceau de lumière très fin qui descend du haut,
// oblique, et se perd avant le bas de la page. Un cône qui s'ouvre à peine,
// une bouffée à la source, et un balancement d'une trentaine de secondes —
// à 2 % de blanc, c'est ce qui donne un SOL à la scène sans qu'on voie
// jamais « un effet ». Le dither est obligatoire : à cette intensité, un
// dégradé propre bande en escalier sur OLED.
[[ stitchable ]] half4 nightSpotlight(float2 position, half4 color,
                                      float2 size, float t) {
    // La source : hors champ en haut à gauche, elle dérive très lentement.
    float2 src = float2(size.x * (0.17 + 0.035 * sin(t / 37.0)),
                        -size.y * 0.10);
    float ang = 1.06 + 0.045 * sin(t / 29.0);          // ~61°, vers le bas-droite
    float2 dir = float2(cos(ang), sin(ang));
    float2 d = position - src;
    float along = dot(d, dir);
    float across = dot(d, float2(-dir.y, dir.x));

    // Le cône : il s'ouvre à peine — un pinceau, pas un projecteur.
    float k = clamp(along / max(size.y, 1.0), 0.0, 1.8);
    float width = size.x * (0.055 + 0.20 * k);
    float beam = exp(-(across * across) / (width * width))
                 * exp(-max(along, 0.0) / (size.y * 0.80))
                 * step(0.0, along);
    // La bouffée à la source : le pinceau naît d'une lueur, pas d'un point.
    float mouth = exp(-dot(d, d) / (size.x * 0.34 * size.x * 0.34));
    // Respiration lente : 23 s, jamais synchrone avec le balancement.
    float breath = 0.80 + 0.20 * sin(t * 6.2832 / 23.0);

    float lum = (beam * 0.052 + mouth * 0.026) * breath;
    // Dither : à 2 % de blanc, il n'y a que 5 niveaux entiers disponibles.
    lum += (ehash21(position * 1.7 + float2(fmod(floor(t * 8.0), 90.0) * 5.1,
                                            0.0)) - 0.5) * (1.6 / 255.0);
    lum = max(lum, 0.0);
    // Blanc à peine tiédi : la lumière de la scène, pas une couleur.
    float3 c = lum * float3(1.0, 0.985, 0.96);
    float a = clamp(lum * 3.4, 0.0, 1.0);
    return half4(half3(c), half(a)) * color.a;
}
