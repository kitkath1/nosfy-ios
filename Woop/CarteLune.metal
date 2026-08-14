#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - La carte-lune récompense — la fenêtre et le foil
//
// Deux illusions dans un seul passage, toutes deux promenées par
// l'inclinaison de la carte (le doigt au banc, le gyroscope en main) :
//
// 1. LA FENÊTRE — une depth map dédiée (carte-lune-1-depth.png) donne à
//    chaque pixel sa distance : 0 sur le cadre et la marge (le plan de
//    l'écran), 1 au fond du ciel. Le paysage glisse sous le liseré
//    proportionnellement à sa profondeur — le cadre ne bouge pas d'un
//    pixel, c'est LUI la vitre. Les sapins quasi noirs sont tenus en
//    avant par la depth map : le frémissement de sous-bois.
//
// 2. LE FOIL — le balayage spéculaire des cartes holo, en braise : cœur
//    or, épaules cuivre, un soupçon de violette sur le bord de fuite —
//    jamais l'arc-en-ciel cartoon. Il mord sur la matière éclairée et
//    effleure seulement le noir. Par-dessus : la poussière de diamants
//    (micro-éclats du lointain, qui s'allument quand l'inclinaison passe
//    sur leur angle propre) et le liseré du cadre qui accroche la lumière
//    au passage de la bande.
//
// La géométrie du cadre est MESURÉE (mesure.py, ~/Downloads/woop-carte-lune) :
// rectangle x 0,1133..0,8849 · y 0,0559..0,9392 de l'image, l'art dedans à
// x 0,118..0,881 · y 0,083..0,891. L'image est affichée entière (sa marge
// noire fond dans la page) : les fractions d'uv SONT les fractions d'image.

static float chash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float csstep(float a, float b, float v) {
    float t = clamp((v - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

static float cvnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = chash21(i), b = chash21(i + float2(1.0, 0.0));
    float c = chash21(i + float2(0.0, 1.0)), d = chash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float cfbm3(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * cvnoise(p);
        p = p * 2.03 + 17.7;
        a *= 0.5;
    }
    return v;
}

/// Deux octaves : l'air du monde tourne à 60 Hz sur tout l'écran — quatre
/// octaves par pixel se paient en cadence, et la brume n'a pas besoin de
/// plus fin (elle est grande et lente).
static float cfbm2(float2 p) {
    return 0.5 * cvnoise(p) + 0.25 * cvnoise(p * 2.03 + 17.7);
}

static float cfbm4(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * cvnoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

static float cRoundBox(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// MARK: - L'air du monde (palier 2)
//
// Ce qui vit ENTRE les plans de la caméra multiplane : la brume qui dérive
// et les braises qui montent. C'est l'air qui donne la DISTANCE — sans lui,
// des calques étagés restent des calques. `band` : 0 = l'air lointain
// (fin, haut), 1 = l'air proche (épais, bas, braises plus larges).
[[stitchable]] half4 carteLuneAir(float2 position, half4 color,
                                  float2 size, float t,
                                  float vie, float band) {
    if (vie < 0.005) { return half4(0.0); }
    float2 uv = position / size;
    float grad = csstep(0.25 + 0.30 * (1.0 - band), 1.0, uv.y);
    // La brume : grand bruit lent, plus dense vers le bas du plan.
    float2 mf = uv * float2(3.2, 4.0) + float2(t * 0.020, -t * 0.007)
              + band * 7.3;
    float mist = cfbm2(mf);
    float mA = csstep(0.28, 0.66, mist) * grad * (0.10 + 0.12 * band) * vie;
    float3 c = float3(0.60, 0.58, 0.62) * mA;
    // Les braises montantes — coefficient du temps CONSTANT (jamais ·vie).
    float cell = 7.0 - 2.0 * band;
    float2 ep = position + float2(0.0, t * (20.0 + 14.0 * band));
    float2 ecid = floor(ep / cell);
    float ernd = chash21(ecid + 5.13 + band * 11.0);
    float egate = step(0.975, ernd);
    float2 ejit = float2(chash21(ecid + 23.1), chash21(ecid + 57.7)) * 0.56 + 0.22;
    float2 efp = (ep / cell - ecid - ejit) * cell;
    float etw = 0.55 + 0.45 * cos(6.2831 * chash21(ecid + 91.7) + t * 0.9);
    float espark = exp(-dot(efp, efp) * (1.7 - 0.8 * band));
    float eA = egate * etw * espark * grad * (0.55 + 0.55 * band) * vie;
    c += float3(1.00, 0.60, 0.28) * eA;
    float a = min(mA + eA * 0.6, 1.0);
    return half4(half3(c), half(a));
}

// MARK: - L'aura de la carte : l'expiration du contour
//
// LE composant des démons du coffre-fort (`wahouAura`), porté à la carte
// récompense : au toucher, ce n'est pas une bouffée qui naît sous le doigt —
// c'est tout le CONTOUR qui expire d'un coup, et le champ s'échappe
// RADIALEMENT (« ce qui répond au toucher doit avoir la forme de l'objet
// touché »). Les trois lois de la fumée de la maison : le champ glisse avec
// l'âge (une origine), le bruit déformé DEUX fois (des volutes), l'exposant
// qui creuse les filaments à trous.
//
// La robe est la SEULE chose qui change des démons : la fumée noire ne se
// lit sur une page noire que par la lumière — ici une couverture charbon
// qui se devine par elle-même (la demande de Kathryn : presque noir, pas
// noir), et le baiser du liseré orange tout contre le cadre, à gain faible
// (`glow`, les démons vivent à 1,55 — nous au murmure).
//
// Vit dans son PROPRE hôte à marge autour de la carte (le modèle
// WahouAura) : jamais dans le calque de l'image — l'aura appartient à la
// scène, pas à l'objet, et elle ne tourne pas avec lui.
[[stitchable]] half4 carteLuneAura(float2 position, half4 color,
                                   float2 size, float t,
                                   float2 demi, float rayon,
                                   float age, float glow) {
    if (age < 0.0 || age >= 1.7) { return half4(0.0); }
    float2 p = position - size * 0.5;
    float d = cRoundBox(p, demi, rayon);
    // Rien à l'intérieur : la carte est opaque, l'aura vit dehors.
    float dehors = smoothstep(-1.0, 3.0, d);
    if (dehors <= 0.002) { return half4(0.0); }
    float lit = exp(-max(d, 0.0) / 72.0);

    float ag = age / 1.7;
    // L'éclat : montée très courte, longue traîne.
    float souffle = pow(ag, 0.20) * exp(-ag * 2.5);
    float2 dir = normalize(p + float2(1e-4, 1e-4));
    float2 sc = (p - dir * (170.0 * ag)) * 0.019;
    float w1 = cfbm4(sc + float2(t * 0.024, -t * 0.017));
    float f = cfbm4(sc * 1.42 + float2(2.3 * w1, -1.7 * w1));
    f = pow(clamp(f, 0.0, 1.0), 2.3);
    // Elle porte loin en vieillissant : collée au bord, ce serait un
    // liseré qui palpite, pas de l'air chassé.
    float portee = exp(-max(d, 0.0) / (54.0 + 190.0 * ag));
    float fumee = clamp(souffle * f * portee * 3.4 * 2.35 * dehors, 0.0, 1.0);

    float a = fumee * 0.90;
    float3 c = float3(0.085, 0.083, 0.098) * a
             + float3(1.00, 0.55, 0.18) * (fumee * lit * glow);
    return half4(half3(c), half(a));
}

// Le nom porte un V2 : une metallib périmée (le pas incrémental Metal ne
// suit pas toujours) ne peut pas contenir ce symbole — l'appel Swift tombe
// alors sur RIEN plutôt que sur une vieille signature, et le mismatch
// silencieux (carte nue sans une erreur) devient impossible.
// Le nom porte un V5 : l'arité a changé (`dolly` est arrivé), et une
// metallib périmée ne peut pas contenir ce symbole — l'appel Swift tombe
// sur RIEN plutôt que sur une vieille signature.
//
// `dive` (0 → 1) est LA PLONGÉE : la caméra passe la vitre et voyage dans
// le monde de la carte (le geste des cartes immersives, PALIER 1 souverain
// — une seule image, verdict Kathryn « plus naturel »). Dedans : la
// parallaxe s'amplifie, le foil et le reflet de vitre s'éteignent (il n'y
// a plus de verre), la brume épaissit, la poussière de diamants cède la
// place aux BRAISES MONTANTES de la vallée, la lune respire, et une
// vignette de cinéma guide l'œil au centre.
//
// `dolly` (0 → 1) est LA CAMÉRA QUI VOYAGE : un zoom différentiel par
// profondeur — chaque pixel s'écarte du centre proportionnellement à
// (profondeur − pivot) : le ciel recule, les sapins avancent vers l'œil.
// C'est l'avancée dans une image unique, sans couche ni couture.
[[stitchable]] half4 carteLuneV5(float2 position, SwiftUI::Layer layer,
                                 float2 size, float2 tilt, float time,
                                 float amp, float foil, float dive,
                                 float dolly,
                                 texture2d<half> depthTex) {
    float2 uv = position / size;
    constexpr sampler ds(address::clamp_to_edge, filter::linear);
    float depth = float(depthTex.sample(ds, uv).r);

    // — La fenêtre. L'œil se déplace avec l'inclinaison : le lointain suit
    //   l'œil, le proche reste. On échantillonne à rebours du glissement.
    //   La verticale bouge moins (une carte se penche plus qu'elle ne se
    //   cabre) : c'est le geste de la main, pas une symétrie d'écran.
    //
    //   Deux garde-fous ANALYTIQUES (la depth map, floutée, bave sur le
    //   liseré — elle ne suffit pas) : le glissement s'annule hors de la
    //   vitre, et l'échantillon reste borné à l'intérieur de l'art — sans
    //   quoi le liseré embrasé est aspiré dans la scène et coule en verre
    //   fondu le long du bord.
    //   La rampe d'entrée est LARGE (~6 pt) : serrée, le glissement passe de
    //   zéro à plein sur une lame de rasoir et l'orée de l'art ondule en
    //   coulure dès que l'inclinaison est diagonale (vu à la planche).
    float inWin = csstep(0.118, 0.135, uv.x) * (1.0 - csstep(0.864, 0.881, uv.x))
                * csstep(0.083, 0.096, uv.y) * (1.0 - csstep(0.878, 0.891, uv.y));
    //   Et la parade de fond : près de N'IMPORTE QUEL bord, TOUT le
    //   déplacement s'éteint (enveloppe intérieure unique, ~17 pt) — pas
    //   seulement l'axe du bord : au flanc gauche, c'était le glissement
    //   VERTICAL qui ondulait encore l'orée. La profondeur vit au centre —
    //   la lune, la vallée ; les bords sont la vitre, ils ne respirent pas.
    float env = csstep(0.118, 0.165, uv.x) * (1.0 - csstep(0.834, 0.881, uv.x))
              * csstep(0.083, 0.130, uv.y) * (1.0 - csstep(0.844, 0.891, uv.y));
    //   La plaque du coin et le disque du médaillon sont une ZONE MORTE
    //   analytique — plus jamais « profondeur 0 » dans la depth map : depuis
    //   le pivot, une rampe qui plonge vers 0 traverse 0,45 et la scène
    //   glisse en sens opposés de part et d'autre — la gélatine du logo au
    //   drag. Un masque qui MULTIPLIE le vecteur ne change jamais son signe.
    float ar0 = size.y / size.x;
    float2 q2 = float2(uv.x, uv.y * ar0);
    float2 pA = float2(0.118, 0.205 * ar0);
    float2 pB = float2(0.315, 0.056 * ar0);
    float2 dAB = normalize(pB - pA);
    float sdPlate = dAB.x * (q2.y - pA.y) - dAB.y * (q2.x - pA.x);
    float plate = 1.0 - csstep(0.0, 0.055, sdPlate);
    float disc = 1.0 - csstep(0.075, 0.150,
                              length(q2 - float2(0.200, 0.135 * ar0)));
    float calm = 1.0 - max(plate, disc);
    //   Le PIVOT : la profondeur 0,45 (les montagnes) reste COLLÉE au cadre.
    //   Le ciel recule d'un côté, les sapins avancent de l'autre — courses
    //   bipolaires, moitié moindres pour le même relief : c'est le remède au
    //   « ça se décolle », l'affiche entière ne coulisse plus jamais d'un bloc.
    //   (Hors vitre, env·inWin annulent le terme négatif du pivot.)
    //
    //   Et le SIGNE est celui de la pose 3D : à tilt.x > 0 la rotation
    //   approche le bord gauche — l'œil est passé à GAUCHE, le lointain doit
    //   fuir à gauche avec lui. Inversé (payé au banc), l'intérieur glisse à
    //   contre-sens de la rotation : perception immédiate de décalcomanie.
    // En plongée la course s'amplifie : la caméra AVANCE dans l'étagement.
    float2 shift = float2(tilt.x, tilt.y * 0.72)
                 * ((depth - 0.45) * amp * (1.0 + 4.8 * dive))
                 * env * inWin * calm;
    // Le dolly interne : zoom différentiel par profondeur autour du centre
    // de l'art — le lointain s'éloigne, le proche vient. Mêmes gardes que
    // le glissement : le vecteur entier s'éteint aux bords et sur la vitre.
    // À 0,15 le monde S'OUVRE — le maxSampleOffset (36×30) le couvre.
    shift += (position - float2(0.4995, 0.487) * size)
           * ((depth - 0.45) * dolly * 0.15) * env * inWin * calm;
    float2 lo = float2(0.121, 0.086) * size + 2.0;
    float2 hi = float2(0.878, 0.888) * size - 2.0;
    float2 sPos = mix(position, clamp(position + shift, lo, hi), inWin);
    half4 c = layer.sample(sPos);

    float lum = dot(float3(c.rgb), float3(0.299, 0.587, 0.114));

    // Espace centré carte, corrigé d'aspect (x-normalisé).
    float ar = size.y / size.x;
    float2 pn = float2(uv.x - 0.4991, (uv.y - 0.4976) * ar);

    // L'aire de l'art : le foil vit dedans, la marge noire reste morte.
    float inArt = csstep(0.118, 0.132, uv.x) * (1.0 - csstep(0.867, 0.881, uv.x))
                * csstep(0.083, 0.097, uv.y) * (1.0 - csstep(0.877, 0.891, uv.y));

    // — Le balayage spéculaire. Une bande diagonale dont le centre est
    //   promené par l'inclinaison ; d est la coordonnée signée dans la bande.
    float sp = dot(pn, normalize(float2(0.62, 1.0)));
    float center = tilt.x * 0.44 - tilt.y * 0.52;
    float d = (sp - center) / 0.145;
    float band = exp(-d * d);
    // L'irisation contenue : l'or au cœur, le cuivre sur le bord d'attaque,
    //   la violette en murmure sur le bord de fuite.
    half3 gold   = half3(1.00, 0.82, 0.50);
    half3 copper = half3(1.00, 0.44, 0.20);
    half3 violet = half3(0.60, 0.38, 0.92);
    float side = clamp(d * 0.5 + 0.5, 0.0, 1.0);
    half3 irid = mix(copper, gold, half(csstep(0.18, 0.55, side)));
    irid = mix(irid, violet, half(csstep(0.78, 1.0, side) * 0.34));
    // La réponse matière : mord sur l'éclairé, effleure le noir profond.
    float resp = mix(0.14, 1.0, csstep(0.015, 0.30, lum));
    // (dans le monde, plus de verre : le foil s'éteint avec la plongée)
    half3 add = irid * half(band * resp * inArt * 0.38 * foil
                            * (1.0 - 0.85 * dive));

    // — La poussière de diamants. Des cellules rares ; dans chacune, UN
    //   éclat façonné (cœur gaussien d'un point, croix discrète), posé au
    //   hasard dans la cellule — jamais la cellule entière, qui ferait un
    //   carré. L'éclat naît quand l'inclinaison (et un souffle d'horloge)
    //   passe sur son angle propre. Elle préfère le lointain — le ciel
    //   s'étoile.
    float cellSize = 6.0;
    float2 cid = floor(position / cellSize);
    float rnd = chash21(cid);
    float gate = step(0.966, rnd);
    float2 jit = float2(chash21(cid + 13.7), chash21(cid + 41.9)) * 0.56 + 0.22;
    float2 fp = (position / cellSize - cid - jit) * cellSize;   // en points
    float phase = 6.2831 * chash21(cid + 71.3)
                + 2.3 * tilt.x + 1.7 * tilt.y + time * 0.16;
    float tw = pow(max(cos(phase), 0.0), 24.0);
    float spark = exp(-dot(fp, fp) * 1.9)
                + 0.30 * exp(-fabs(fp.x) * 2.6 - fabs(fp.y) * 7.0)
                + 0.30 * exp(-fabs(fp.y) * 2.6 - fabs(fp.x) * 7.0);
    // (la zone morte retient aussi la poussière : pas d'étoiles sur le logo)
    float dustZone = csstep(0.45, 0.90, depth) * inArt * calm;
    add += half3(1.00, 0.93, 0.80)
         * half(gate * tw * spark * dustZone * 1.35 * foil
                * (1.0 - 0.85 * dive));

    // — Les braises de la plongée. Une seconde famille de grains, qui MONTE
    //   (sa grille dérive toujours — le coefficient du temps est constant,
    //   jamais multiplié par `dive`, sinon la phase saute aux transitions) ;
    //   seule sa VISIBILITÉ suit la plongée. Elles naissent de la vallée.
    //   Branche uniforme : hors plongée, le GPU saute tout le bloc.
    if (dive > 0.001) {
    float2 ep = position + float2(0.0, time * 26.0);
    float2 ecid = floor(ep / cellSize);
    float ernd = chash21(ecid + 5.13);
    float egate = step(0.972, ernd);
    float2 ejit = float2(chash21(ecid + 23.1), chash21(ecid + 57.7)) * 0.56 + 0.22;
    float2 efp = (ep / cellSize - ecid - ejit) * cellSize;
    float ephase = 6.2831 * chash21(ecid + 91.7) + time * 0.9;
    float etw = 0.55 + 0.45 * cos(ephase);
    float espark = exp(-dot(efp, efp) * 1.6);
    float emberZone = (1.0 - csstep(0.35, 0.75, depth)) * inArt * calm;
    add += half3(1.00, 0.60, 0.28)
         * half(egate * etw * espark * emberZone * 2.4 * dive);

    // — La lune respire. Un halo braise très doux autour du croissant, qui
    //   gonfle et retombe lentement — le cœur du monde, pendant la plongée.
    float dm = length(q2 - float2(0.500, 0.272 * ar0));
    float halo = exp(-dm * dm * 90.0) * (0.40 + 0.28 * sin(time * 0.7));
    add += half3(1.00, 0.62, 0.30) * half(halo * 0.55 * dive * inArt);
    }

    // — Le liseré qui accroche. L'anneau du cadre (SDF du rectangle arrondi
    //   mesuré) s'embrase au passage d'une bande élargie du même balayage.
    float2 he = float2(0.3858, 0.4417 * ar);
    float rad = 0.052;
    float2 q = abs(pn) - (he - rad);
    float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
    //   Le reflet est un ÉCLAT localisé qui court le long du liseré — pas un
    //   lavis : plus large que la bande de l'art, il embrasait des colonnes
    //   entières de cadre.
    float ring = 1.0 - smoothstep(0.0, 0.0045, fabs(sd));
    float glint = ring * exp(-d * d * 0.9);
    add += half3(1.00, 0.74, 0.40)
         * half(glint * 0.42 * foil * (1.0 - 0.85 * dive));

    // — Le reflet de vitre. Une nappe blanche très douce SUR le verre — le
    //   troisième plan (surface / cadre / scène). Le monde réfléchi est
    //   DEVANT le pivot : la nappe se déplace à CONTRE-SENS du lointain,
    //   et c'est ce désaccord qui achève de vendre la profondeur. Deux
    //   lobes parallèles (la vitre a une épaisseur), bord très doux.
    float2 rdir = normalize(float2(1.0, 0.38));
    float ru = dot(pn, rdir) - (tilt.x * 0.16 + tilt.y * 0.10);
    float sheet = exp(-pow(ru / 0.115, 2.0))
                + 0.45 * exp(-pow((ru - 0.055) / 0.030, 2.0));
    float inGlass = csstep(0.115, 0.125, uv.x) * (1.0 - csstep(0.874, 0.884, uv.x))
                  * csstep(0.080, 0.090, uv.y) * (1.0 - csstep(0.888, 0.898, uv.y));
    add += half3(0.90, 0.94, 1.00)
         * half(sheet * inGlass * 0.055 * foil * (1.0 - 0.85 * dive));

    // — La brume qui dérive. Le voile de la vallée respire même carte
    //   posée — c'est la vie au repos. Un grand bruit lent qui ne fait
    //   qu'ÉCLAIRCIR la brume déjà peinte (garde de luminance : jamais de
    //   gris posé sur un sapin net).
    float2 mflow = q2 * float2(2.1, 2.8) + float2(time * 0.021, -time * 0.008);
    float mist = cfbm3(mflow);
    float mzone = csstep(0.58, 0.70, uv.y) * (1.0 - csstep(0.86, 0.891, uv.y))
                * inArt;
    float mistA = mzone * csstep(0.35, 0.75, mist) * csstep(0.03, 0.22, lum);
    // La brume épaissit dans le monde : c'est elle, l'air de la vallée.
    add += half3(0.62, 0.60, 0.62)
         * half(mistA * 0.10 * (1.0 + 3.2 * dive) * foil);

    // — La fumée du tap. Gris très foncé quasi noir : sur cette carte elle
    //   se lit par ce qu'elle ÉTEINT (la braise, le liseré, les étoiles) —
    //   et elle passe PAR-DESSUS le cadre, jusque dans la marge : le monde
    //   qui s'échappe de la fenêtre. Tout est fonction de l'ÂGE (le pattern
    //   des bouffées de la flamme bijou) : figeable, rien ne s'accumule.
    // Fusion en écran : la lumière se pose sans jamais claquer au blanc.
    half3 outc = 1.0h - (1.0h - c.rgb) * (1.0h - min(add, 1.0h));

    // — La vignette de plongée : les bords s'éteignent doucement, l'œil est
    //   tenu au centre du monde — le langage du cinéma, pas une UI.
    float vign = csstep(0.38, 0.80, length(pn * float2(1.0, 0.78)));
    outc *= half(1.0 - 0.40 * dive * vign);
    return half4(outc, c.a);
}
