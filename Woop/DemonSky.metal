#include <metal_stdlib>
using namespace metal;

// MARK: - Ciel nébuleuse
//
// Deux passes :
//   nebulaField — la nébuleuse, rendue en DEMI-résolution (tout y est diffus,
//                 l'upscale bilinéaire est invisible et divise le coût par 4) ;
//   nebulaStars — les étoiles, en pleine résolution (elles sont sub-pixel,
//                 l'upscale les détruirait), composées en plusLighter.
//
// La v1 peignait des dégradés ; ici on simule de la lumière : une source HDR
// (le cœur monte à ~10 en linéaire), de la matière qui l'absorbe
// (Beer-Lambert : la poussière d'avant-plan MULTIPLIE ce qui est derrière),
// des volumes éclairés par la tranche (dérivée directionnelle de densité vers
// le cœur = bords embrasés, centres sombres), et une compression filmique
// 1-exp(-kL) qui crame le cœur au blanc pur en gardant des centaines de gris.
//
// Le bruit vient d'une LUT tileable (NebulaNoise.swift) : 1 fetch ≈ 40
// instructions de hash économisées. Les filaments viennent d'un kaliset
// calculé en direct — 11 itérations coûtent moins qu'une octave de bruit.
//
// TEMPS : tout est périodique sur 900 s. Les dérives linéaires translatent
// la LUT d'un nombre ENTIER de répétitions par période (champ périodique →
// raccord invisible), tout le reste est en sin(k·2π·t/900) avec k entier.
// Un float32 encaisse t ≤ 900 sans le moindre pas visible.

constant float TAU = 6.28318530718;
constant float PH  = TAU / 900.0;          // pulsation de base de la boucle
constant float2 CORE = float2(-0.04, 1.10); // cœur, hors cadre bas-gauche

constexpr sampler kLut(address::repeat, filter::linear, coord::normalized);

// MARK: Hachage

static float hash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 hash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

// MARK: Étoile filante
//
// ~1 par 2 minutes : boucle découpée en 9 fenêtres de 100 s, chaque fenêtre
// tire (ou pas) un météore déterministe — trajectoire diagonale descendante
// dans la moitié haute, tête blanche chaude, traînée qui se refroidit et
// s'évanouit en ~1 s après le passage. Sortie anticipée en ~8 instructions
// 98 % du temps.
static float3 meteor(float2 pos, float2 sz, float t) {
    float win = floor(t / 100.0);
    float4 h = hash42(float2(win * 1.93 + 4.7, 8.1));
    if (h.x > 0.75) { return float3(0.0); }
    float lifeT = (t - win * 100.0) - h.y * 96.0;
    if (lifeT < 0.0 || lifeT > 1.6) { return float3(0.0); }

    float lead = saturate(lifeT / 0.6);
    float2 A = float2(mix(0.10, 0.85, h.z) * sz.x, mix(0.06, 0.38, h.w) * sz.y);
    float2 dir = normalize(float2(mix(-1.0, 1.0, fract(h.z * 13.7)),
                                  mix(0.35, 0.80, fract(h.w * 7.9))));
    float len = mix(180.0, 300.0, fract(h.y * 11.3));

    float2 pa = pos - A;
    float along = clamp(dot(pa, dir), 0.0, len * lead);
    float dperp = length(pos - (A + dir * along));
    float tail = exp(-(len * lead - along) / 70.0);       // la traînée refroidit
    float core = exp(-dperp * dperp / 1.8);
    float2 head = A + dir * len * lead;
    float hot = exp(-dot(pos - head, pos - head) / 6.0)
              * (1.0 - step(0.6, lifeT)) * 1.5;           // tête, tant qu'elle vole
    float fade = 1.0 - smoothstep(0.55, 1.5, lifeT);      // tout s'évanouit
    return float3(1.0, 0.98, 0.92) * (core * tail * 1.2 + hot) * fade;
}

// MARK: Passe nébuleuse (demi-résolution)

[[ stitchable ]] half4 nebulaField(float2 position, half4 color,
                                   float2 size, float t, float reveal,
                                   float2 tilt,
                                   texture2d<half> lut) {
    float2 sz = max(size, float2(1.0));
    // Parallaxe gyroscopique : la nébuleuse est un plan lointain, ±12 pt
    // visuels (la passe est en demi-résolution : 6 pt de couche = 12 à l'écran).
    float2 uv = (position + tilt * 6.0) / sz;
    float aspect = sz.x / sz.y;
    float2 p = float2(uv.x * aspect, uv.y);

    float2 pc = p - CORE;
    float d = length(pc);
    float2 toCore = -pc / max(d, 1e-4);
    float tn = t / 900.0;                   // temps en périodes (dérives LUT)
    float ph = t * PH;                      // phase (sinus)

    // ---- Warp partagé -------------------------------------------------------
    // UN seul champ de warp pour les nuages, les wisps et les veines : tous
    // suivent les mêmes courants, condition nécessaire pour que les mondes ne
    // jurent pas entre eux. Le warp dérive dans une direction différente des
    // nuages : le mouvement RELATIF déforme la matière localement au lieu de
    // la faire défiler en bloc.
    float2 q = float2(
        (float)lut.sample(kLut, p * 0.85 + float2( 6.0,  3.0) * tn).r,
        (float)lut.sample(kLut, p * 0.85 + float2(0.41, 0.17) + float2(-3.0, -6.0) * tn).g);
    float2 w = (q - 0.5) * 1.15;

    // ---- Nuages -------------------------------------------------------------
    // Trois lectures multi-octaves à trois échelles/dérives : le différentiel
    // de vitesses entre octaves fait l'évolution interne de la matière. Les
    // dérives sont assez rapides pour que la matière se transforme à vue
    // (10-20 s) — un fond qu'on ne voit jamais bouger n'est qu'un poster.
    float o1 = (float)lut.sample(kLut, p * 1.05 + w * 0.42 + float2( 6.0, -3.0) * tn).r * 0.55;
    float o2 = (float)lut.sample(kLut, p * 2.30 + w * 0.26 + float2(0.37, 0.71) + float2(-9.0, 6.0) * tn).g * 0.30;
    float d12 = o1 + o2;
    float o3 = (float)lut.sample(kLut, p * 4.70 + w * 0.15 + float2(0.61, 0.13) + float2( 15.0, -12.0) * tn).r * 0.15;
    float dens = d12 + o3;
    float cloud = smoothstep(0.22, 0.92, dens);

    // ---- Rim lighting 2-tap (iq) -------------------------------------------
    // La densité ré-échantillonnée un pas VERS le cœur : si elle augmente en
    // allant vers la lumière, on est sur le flanc éclairé. Bords embrasés
    // côté cœur, centres sombres — la lecture 3D des nuages tient là.
    const float eps = 0.030;
    float2 pe = p + toCore * eps;
    float e1 = (float)lut.sample(kLut, pe * 1.05 + w * 0.42 + float2( 6.0, -3.0) * tn).r * 0.55;
    float e2 = (float)lut.sample(kLut, pe * 2.30 + w * 0.26 + float2(0.37, 0.71) + float2(-9.0, 6.0) * tn).g * 0.30;
    float rim = clamp((d12 - (e1 + e2)) * 14.0, 0.0, 1.0);
    rim *= rim;

    // ---- Cœur aveuglant (HDR) ----------------------------------------------
    // Gaussien serré très intense + halo lorentzien FENÊTRÉ : la queue en
    // 1/d² porte la lueur jusqu'à mi-écran, la fenêtre exponentielle la tue
    // au-delà — le haut-droite doit rester noir, comme la référence.
    // L'écrêtage au blanc est fait par la courbe filmique, jamais par un clamp.
    // Respiration de portée : la fenêtre du halo s'étend et se rétracte de
    // ±8 % sur ~90 s — la lueur AVANCE visiblement sur l'écran puis recule.
    float reach = 1.0 + 0.20 * sin(ph * 10.0 + 0.9)
                      + 0.08 * sin(ph * 23.0 + 2.2);
    float coreI = 7.0 * exp(-d * d * 10.0)
                + 0.09 / (d * d + 0.010) * exp(-d * 2.4 / reach);
    // Vacillement : une source réelle n'est jamais parfaitement constante.
    // ±7 % par trois ondes incommensurables (≈7 s, 47 s, 180 s) — clairement
    // vivant en vision périphérique, jamais mécanique.
    coreI *= 1.0 + 0.055 * sin(ph * 129.0 + 0.7)
                 + 0.022 * sin(ph * 19.0 + 2.3)
                 + 0.012 * sin(ph * 5.0 + 4.1);

    // Nuages d'avant-plan en silhouette DANS le halo : une tranche de densité
    // indépendante qui absorbe la lueur — les masses sombres se découpent sur
    // le blanc, c'est l'ordre de profondeur qui fait le volumétrique.
    float f1 = (float)lut.sample(kLut, p * 1.55 + w * 0.30 + float2(0.73, 0.29) + float2(-4.0, 6.0) * tn).g;
    float f2 = (float)lut.sample(kLut, p * 3.10 + w * 0.20 + float2(0.11, 0.83) + float2( 8.0,  2.0) * tn).r;
    float front = smoothstep(0.52, 0.98, f1 * 0.7 + f2 * 0.45);
    float Tclouds = exp(-2.2 * front);

    // ---- Nuages profonds du haut (absorption pure) ---------------------------
    // De grosses masses NOIRES qui dérivent dans la voûte : elles ne
    // rayonnent rien, elles avalent la faible lueur ambiante (et les étoiles,
    // côté passe étoiles) — des halos noirs profonds qui respirent lentement.
    float topMask = smoothstep(0.55, 0.15, uv.y);
    float tc1 = (float)lut.sample(kLut, p * 1.35 + w * 0.50 + float2(0.19, 0.57) + float2( 6.0, -4.0) * tn).g;
    float tc2 = (float)lut.sample(kLut, p * 2.80 + w * 0.30 + float2(0.47, 0.09) + float2(-8.0,  6.0) * tn).r;
    float topCloud = smoothstep(0.45, 0.95, tc1 * 0.7 + tc2 * 0.5);
    // Éclaircie furtive : toutes les ~2,5 min, une déchirure s'ouvre ~10 s
    // là où un champ lent est haut — le ciel s'ouvre, puis se referme.
    float clearing = smoothstep(0.90, 0.97, sin(ph * 6.0 + 0.4))
                   * smoothstep(0.55, 0.85,
                       (float)lut.sample(kLut, p * 0.9 + float2(1.0, -1.0) * tn + 0.31).r);
    topCloud *= 1.0 - 0.85 * clearing;
    // Marées d'opacité : l'absorption respire de ±24 % sur des périodes de
    // marée (450 s, 180 s, 90 s, incommensurables) — la voûte vit sur un
    // temps que personne ne peut suivre consciemment.
    float tide = 1.0 + 0.20 * (0.55 * sin(ph * 2.0 + 1.1)
                             + 0.30 * sin(ph * 5.0 + 3.7)
                             + 0.35 * sin(ph * 10.0 + 2.9));
    float Ttop = exp(-2.2 * topCloud * topMask * tide);

    // ---- Filaments : kaliset en direct --------------------------------------
    // p' = abs(p)/dot(p,p) - c : pliage + inversion sphérique + translation,
    // itérés — un limit set kleinien dont les frontières sont des filaments
    // ramifiés auto-similaires. L'orbit trap Σ|‖p‖-‖p_prev‖| explose près de
    // ces frontières : c'est lui qu'on dessine. En float impérativement :
    // dot(p,p) écrase ou explose la mantisse d'un half.
    // Animation : c et la rotation oscillent à peine — le limit set dépend
    // continûment de c, la fractale se métamorphose sans jamais défiler.
    float ck = 0.532 + 0.011 * sin(ph * 3.0);
    float ang = 0.45 + 0.055 * sin(ph * 1.0 + 1.3);
    float ca = cos(ang), sa = sin(ang);
    float2x2 R = float2x2(ca, -sa, sa, ca);
    float2 z = pc * 2.1 + float2(0.32, -0.18)
             + 0.02 * float2(sin(ph * 2.0), cos(ph * 1.0));
    float acc = 0.0, pl = 0.0, wk = 1.0;
    for (int i = 0; i < 11; i++) {
        z = R * z;
        z = abs(z) / max(dot(z, z), 1e-6) - ck;
        float l = length(z);
        acc += wk * abs(l - pl);
        pl = l;
        wk *= 0.86;                        // les itérations profondes pèsent
    }                                      // moins : anti-fourmillement
    // L'orbit trap a une base élevée (~10-20, mesuré) : on n'en garde que les
    // variations hautes, en texture fractale douce — jamais en aplat.
    float fil = pow(saturate(acc * 0.05 - 0.32), 2.0);

    // ---- Wisps radiaux (ridged multifractal en log-polaire) -----------------
    // log(d) : le zoom devient translation, les features gardent la même
    // taille apparente à tous les rayons — l'auto-similarité, l'anti-soie.
    // Fréquence angulaire ENTIÈRE (3 tours) : la couture atan2 disparaît dans
    // le wrap du sampler. Animé par le warp seul : les wisps ondulent sur
    // place, ils ne ruissellent jamais radialement.
    float theta = atan2(pc.y, pc.x) / TAU;
    float2 lp = float2(theta * 3.0, log(max(d, 1e-3)) * 0.85) + w * 0.22;
    float wisp = pow((float)lut.sample(kLut, lp).b, 3.5);

    // ---- Émission (accumulation HDR linéaire) --------------------------------
    // Les morsures sombres dans le halo viennent des silhouettes (Tclouds) :
    // de la matière DEVANT la lumière — pas d'un motif dessiné par-dessus.
    float glowFall = saturate(0.12 / (d * d + 0.02)) * exp(-d * 1.5);
    float darkCore = mix(1.0, 0.10, smoothstep(0.52, 0.88, cloud));
    // Trois éclairages des nuages : une lueur ambiante infime (le haut-droite
    // reste presque noir), la DIFFUSION de la lumière du cœur (les masses
    // proches du souffle s'embrasent en bloc — la bande de transition de la
    // référence), et le rim directionnel (bords embrasés côté cœur).
    float cloudE = darkCore
                 * (0.010 * cloud
                    + (coreI * 0.27 + 1.8 * rim * saturate(coreI)) * pow(cloud, 1.4));
    float filM = smoothstep(0.08, 0.30, dens);   // les filaments naissent en
                                                 // lisière de matière

    // ---- Brume de vent bas-droite ---------------------------------------------
    // Une nappe basse poussée latéralement (dérive x rapide relativement au
    // reste), qui RESPIRE par rafales : deux sinus lents incommensurables —
    // jamais le métronome d'une pulsation unique.
    // La nappe elle-même se balance lentement (~41 s / 60 s) : la brume ne
    // reste jamais posée au même endroit.
    float2 mc = p - float2(0.95 * aspect + 0.045 * sin(ph * 22.0 + 1.7),
                           1.02 + 0.030 * sin(ph * 15.0));
    float mistMask = exp(-(mc.x * mc.x * 2.0 + mc.y * mc.y * 4.6));
    float m1 = (float)lut.sample(kLut, p * 2.60 + w * 0.50 + float2( -9.0, -2.0) * tn).g;
    float m2 = (float)lut.sample(kLut, p * 5.20 + w * 0.30 + float2(0.53, 0.21) + float2(-14.0,  3.0) * tn).r;
    float mist = smoothstep(0.30, 0.95, m1 * 0.65 + m2 * 0.45);
    // Rafales directionnelles : la phase dépend de x — la bouffée TRAVERSE
    // la nappe en quelques secondes au lieu d'arriver partout à la fois.
    // Deux porteuses incommensurables (≈36 s et 22 s), creusées : entre deux
    // rafales la nappe s'éteint presque — la respiration se VOIT.
    // Entre deux rafales la nappe s'éteint COMPLÈTEMENT (gust clampé à 0) :
    // la respiration devient un événement qu'on regarde.
    float gust = max(0.42 + 0.65 * (0.6 * sin(ph * 25.0 + p.x * 7.0 + 2.1)
                                  + 0.4 * sin(ph * 41.0 + p.x * 4.0 + 0.6)), 0.0);
    float mistE = mist * mistMask * 0.24 * gust;

    // Les wisps ridgés portent les filaments (crêtes fines ramifiées) ; le
    // kaliset n'est plus qu'une respiration fractale du halo.
    float E = coreI * Tclouds * (0.82 + 0.36 * fil)
            + 3.4 * wisp * glowFall * filM
            + cloudE
            + mistE;
    E *= Ttop;   // les masses noires du haut avalent tout ce qui est derrière

    // La nuit tombe du haut : rampe verticale explicite — le haut de l'écran
    // ne reçoit presque rien, la lumière n'existe qu'en bas.
    E *= mix(0.32, 1.0, smoothstep(0.02, 0.88, uv.y));

    // ---- Teinte thermique -----------------------------------------------------
    // La structure vit dans la luminance ; la chromie n'est qu'un mix ±6 %
    // entre un gris froid (matière sombre) et un sépia chaud (matière exposée
    // au cœur). La compression filmique désature le cœur vers le blanc pur —
    // le comportement d'un capteur.
    float warmth = smoothstep(0.15, 2.5, E);
    float3 tint = mix(float3(0.955, 0.985, 1.045),
                      float3(1.055, 1.000, 0.915), warmth);

    // ---- Compression filmique ------------------------------------------------
    // Révélation : à l'apparition de l'écran, l'exposition monte de −1.5 EV
    // à 0 en ~2 s — le ciel révèle ses détails comme des yeux qui
    // s'habituent à l'obscurité. `reveal` arrive déjà lissé (smoothstep).
    float exposure = 1.18 * (0.35 + 0.65 * reveal);
    float3 L = E * tint;
    float3 c = 1.0 - exp(-exposure * L);
    // Toe : les presque-noirs tombent à zéro — le fond reste un vrai noir OLED.
    c = max(c - 0.0085, 0.0) * 1.0085;

    // Tramage anti-banding (le grain animé de la passe étoiles complète).
    c += (hash21(position * 1.113 + 37.7) - 0.5) * (1.6 / 255.0);

    return half4(half3(saturate(c)), 1.0h);
}

// MARK: Passe étoiles (pleine résolution)

/// Une couche du champ : grille hashée, au plus une étoile par cellule.
/// La luminosité suit une loi de puissance pow(h, alpha) — l'écrasante
/// majorité des étoiles est une poudre sub-pixel au ras du seuil, les
/// brillantes sont rares : c'est la statistique, pas la position, qui fait
/// le photographique.
///   - PSF : cœur gaussien (sigma quasi fixe = anti-aliasing intégré) ;
///     halo Moffat (ailes lourdes, comme une vraie PSF de capteur) réservé
///     aux brillantes ; aigrettes réservées aux héros.
///   - Scintillement : brillantes seulement (les faibles scintillent sous le
///     seuil de perception — les animer ferait fourmiller l'image), deux
///     sinus incommensurables, jamais d'extinction.
///   - Dérive : balancement sinusoïdal (une dérive linéaire sur une grille
///     hashée sauterait au raccord de la boucle de 900 s).
///   - `T` : transmittance de la poussière — module l'INTENSITÉ et aussi la
///     DENSITÉ (dans un nuage épais il n'y a pas que des étoiles éteintes,
///     il y en a moins).
///   - `sigmaMul` : élargit le cœur gaussien — 1.0 pour une étoile ponctuelle,
///     ~2.5 pour une particule flottante douce (bokeh d'avant-plan).
static float3 starLayer(float2 pos, float t, float cellPt, float density,
                        float alphaPow, float gain, float2 seed,
                        float2x2 grid, float sway, float2 swayK,
                        bool halos, bool spikes, float T, float sigmaMul,
                        float rev) {
    float2 sp = grid * pos;
    sp += cellPt * sway * float2(sin(PH * swayK.x * t + seed.x),
                                 cos(PH * swayK.y * t + seed.y));
    float2 id = floor(sp / cellPt);
    float2 f = fract(sp / cellPt);

    float4 h = hash42(id + seed);
    if (h.x > density * mix(0.25, 1.0, T)) { return float3(0.0); }

    float b = pow(h.y, alphaPow) * gain;
    if (b < 0.003) { return float3(0.0); }

    float2 stp = 0.5 + 0.36 * (h.zw * 2.0 - 1.0);
    // Errance individuelle, période 15-45 s, quantifiée sur la boucle.
    float wk = 20.0 + floor(h.z * 40.0);
    stp += 0.045 * sin(PH * wk * t + h.w * TAU) * float2(1.0, 0.8);

    float2 dp = (f - stp) * cellPt;
    float r2 = dot(dp, dp);
    if (r2 > cellPt * cellPt * 0.16) { return float3(0.0); }

    float sig = (0.38 + 0.45 * saturate(b)) * sigmaMul;
    // Seeing : le piqué respire (±9 % sur ~60 s), quasi commun à tout le
    // ciel — certaines « nuits » sont plus nettes que d'autres.
    sig *= 1.0 + 0.09 * sin(PH * 15.0 * t + h.x * 2.0);
    // Occultation : une étoile qui s'éteint derrière un nuage GONFLE en
    // s'estompant — une extinction à travers un bord de matière, pas un
    // variateur. C'est le détail qui vend la profondeur.
    sig *= 1.0 + 0.6 * (1.0 - smoothstep(0.15, 0.55, T));
    float s = exp(-r2 / (2.0 * sig * sig));

    if (halos && b > 0.5) {
        float rh2 = r2 / ((1.2 + 4.5 * b) * (1.2 + 4.5 * b));
        s += 0.16 * pow(1.0 + rh2, -1.75);            // Moffat β≈1.75
    }
    if (spikes && b > 0.85) {
        s += 0.30 * (exp(-(abs(dp.x) * 0.35 + abs(dp.y) * 2.8))
                   + exp(-(abs(dp.y) * 0.35 + abs(dp.x) * 2.8)));
    }

    // Seuil bas à 0.12 : les particules d'avant-plan et les étoiles moyennes
    // scintillent aussi — seule la poudre sub-pixel reste immobile (elle
    // fourmillerait en aliasing).
    float twA = 0.38 * smoothstep(0.12, 0.90, b);
    if (twA > 0.002) {
        // Sessions : une enveloppe lente propre à chaque étoile (40-90 s) —
        // chaque étoile a ses moments de scintillement et ses moments calmes,
        // comme sous une vraie turbulence qui va et vient.
        float ks = 10.0 + floor(fract(h.z * 31.7) * 12.0);
        float session = smoothstep(0.15, 0.60,
                                   0.5 + 0.5 * sin(PH * ks * t + h.w * TAU * 1.9));
        float k1 = 240.0 + floor(h.z * 380.0);        // ~0.3-0.7 Hz perçus
        float k2 =  90.0 + floor(h.w * 140.0);
        s *= 1.0 + twA * session * (0.6 * sin(PH * k1 * t + h.z * TAU)
                                  + 0.4 * sin(PH * k2 * t + h.w * TAU * 2.7));
    }

    // Flash de héros : la vraie scintillation produit de rares éclats de
    // 1 à 2 magnitudes. Boucle découpée en 12 fenêtres de 75 s ; dans chaque
    // fenêtre, ~1 héros à l'écran tire un flash — attaque 80 ms, décroissance
    // exponentielle ~160 ms. Déterministe sur la boucle (aucun état).
    if (spikes) {
        float win = floor(t / 45.0);
        float hw = hash21(id * 0.37 + win * 13.7 + seed);
        if (hw < 0.26) {
            float dtf = (t - win * 45.0) - fract(hw * 57.3) * 41.0;
            if (dtf > -0.08 && dtf < 0.8) {
                float env = smoothstep(-0.08, 0.0, dtf) * exp(-max(dtf, 0.0) / 0.16);
                s *= 1.0 + 3.6 * env;
            }
        }
    }

    // Révélation : les étoiles s'allument par rang de luminosité décroissant
    // (les brillantes d'abord, la poudre en dernier), comme des yeux qui
    // s'habituent à l'obscurité. `rev` = 1 hors apparition.
    s *= smoothstep(0.0, 0.12, b - (1.0 - rev) * 0.55);

    // Blanc à peine froid ; une étoile sur six à peine chaude.
    float3 tintS = mix(float3(0.92, 0.95, 1.05), float3(1.05, 0.98, 0.90),
                       step(0.84, fract(h.y * 17.3)));
    return tintS * (s * min(b, 1.4) * T);
}

[[ stitchable ]] half4 nebulaStars(float2 position, half4 color,
                                   float2 size, float t, float reveal,
                                   float2 tilt,
                                   texture2d<half> lut) {
    float2 sz = max(size, float2(1.0));
    float2 uv = position / sz;
    float aspect = sz.x / sz.y;
    float2 p = float2(uv.x * aspect, uv.y);
    float d = length(p - CORE);
    float tn = t / 900.0;
    float ph = t * PH;

    // Proxy de la densité de nuages : les deux premières octaves de la passe
    // nébuleuse, mêmes échelles, mêmes dérives — l'extinction des étoiles
    // coïncide avec les masses qu'on voit.
    float qq = (float)lut.sample(kLut, p * 0.85 + float2(6.0, 3.0) * tn).r;
    float2 wp = float2(qq - 0.5, 0.5 - qq) * 1.0;
    float dens = (float)lut.sample(kLut, p * 1.05 + wp * 0.42 + float2( 6.0, -3.0) * tn).r * 0.55
               + (float)lut.sample(kLut, p * 2.30 + wp * 0.26 + float2(0.37, 0.71) + float2(-9.0, 6.0) * tn).g * 0.30;
    // Seuls les nuages VRAIMENT denses éteignent : la référence fourmille
    // d'étoiles jusque dans les zones de brume moyenne.
    float T = exp(-1.8 * smoothstep(0.38, 0.95, dens));

    // Les masses noires du haut (mêmes champs que la passe nébuleuse) avalent
    // aussi les étoiles : un halo noir qui n'éteindrait pas le ciel derrière
    // lui ne serait qu'une tache.
    float topMask = smoothstep(0.55, 0.15, uv.y);
    float tc1 = (float)lut.sample(kLut, p * 1.35 + wp * 0.50 + float2(0.19, 0.57) + float2( 6.0, -4.0) * tn).g;
    float tc2 = (float)lut.sample(kLut, p * 2.80 + wp * 0.30 + float2(0.47, 0.09) + float2(-8.0,  6.0) * tn).r;
    float topCloud = smoothstep(0.45, 0.95, tc1 * 0.7 + tc2 * 0.5);
    // Même éclaircie que la passe nébuleuse : quand le ciel s'ouvre, les
    // étoiles derrière la déchirure se rallument.
    float clearing = smoothstep(0.90, 0.97, sin(ph * 6.0 + 0.4))
                   * smoothstep(0.55, 0.85,
                       (float)lut.sample(kLut, p * 0.9 + float2(1.0, -1.0) * tn + 0.31).r);
    topCloud *= 1.0 - 0.85 * clearing;
    // Même marée que la passe nébuleuse : quand une masse s'épaissit, elle
    // avale ses étoiles au même moment.
    float tide = 1.0 + 0.20 * (0.55 * sin(ph * 2.0 + 1.1)
                             + 0.30 * sin(ph * 5.0 + 3.7)
                             + 0.35 * sin(ph * 10.0 + 2.9));
    T *= exp(-1.6 * topCloud * topMask * tide);

    // Les étoiles se noient dans le blanc cramé du cœur — sur un capteur,
    // le halo les avale bien avant le centre. Même formule que la passe
    // nébuleuse : l'avalement coïncide avec le blanc qu'on voit.
    float coreI = 7.0 * exp(-d * d * 10.0)
                + 0.09 / (d * d + 0.010) * exp(-d * 2.4);
    float wash = saturate(1.0 - coreI * 0.40);

    const float2x2 g0 = float2x2( 1.000,  0.000,  0.000,  1.000);
    const float2x2 g1 = float2x2( 0.946, -0.326,  0.326,  0.946);
    const float2x2 g2 = float2x2( 0.839,  0.545, -0.545,  0.839);
    const float2x2 g3 = float2x2( 0.990, -0.139,  0.139,  0.990);

    float3 s = float3(0.0);
    // Parallaxe gyroscopique : chaque couche glisse proportionnellement à sa
    // profondeur — la poudre lointaine à peine, les particules d'avant-plan
    // le plus. C'est ce différentiel qui fait la fenêtre « 3D ».
    // L0 — poudre : des milliers de piqûres sub-pixel, stables, doublement
    // absorbées (elles sont derrière toute la colonne de matière).
    s += starLayer(position + tilt *  8.0, t,   2.9, 1.00, 14.0, 0.42, float2(13.1,  7.7),
                   g0, 1.5, float2(2.0, 3.0), false, false, T, 1.0, reveal) * T;
    s += starLayer(position + tilt * 24.0, t,   8.0, 0.95, 10.0, 0.60, float2(41.7,  3.3),
                   g1, 2.0, float2(3.0, 2.0), false, false, T, 1.0, reveal) * T;
    s += starLayer(position + tilt * 42.0, t,  23.0, 0.75,  6.0, 1.05, float2(23.9, 11.3),
                   g2, 2.5, float2(1.0, 4.0), true,  false, T, 1.0, reveal);
    // L3 — héros : ~7 étoiles marquantes, halo Moffat, aigrettes rarissimes,
    // quasi d'avant-plan (peu absorbées).
    s += starLayer(position + tilt * 66.0, t, 105.0, 0.25,  3.0, 0.85, float2( 5.3, 29.1),
                   g3, 1.2, float2(2.0, 1.0), true,  true,
                   mix(1.0, T, 0.25), 1.0, reveal);
    // Particules flottantes — fines et précieuses : petites poussières de
    // lumière d'avant-plan qui scintillent et portent l'essentiel du plongeon
    // (±84 pt). Jamais absorbées : elles flottent DEVANT la nébuleuse.
    s += starLayer(position + tilt * 84.0, t,  58.0, 0.45,  5.0, 0.50, float2(61.7, 17.9),
                   g1, 4.0, float2(1.0, 2.0), false, false, 1.0, 1.7, reveal);
    s *= wash;

    // Étoile filante : rare, déterministe, au-dessus du wash (elle brûle dans
    // l'atmosphère, devant tout).
    s += meteor(position + tilt * 30.0, sz, t);

    // Grain photographique animé, pondéré par une estimation de la luminance
    // de fond : maximal dans les demi-tons, quasi nul dans les noirs (le
    // niveau de noir OLED ne remonte pas) comme dans le blanc cramé.
    float lumaProxy = 1.0 - exp(-(coreI + dens * 0.6));
    float frame = floor(t * 24.0);
    float g = hash21(position + fract(frame * 0.618) * float2(17.0, 29.0));
    s += g * 0.011 * (1.0 - abs(2.0 * lumaProxy - 1.0));

    return half4(half3(min(s, float3(1.0))), 1.0h);
}
