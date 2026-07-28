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
              * (1.0 - smoothstep(0.55, 0.72, lifeT)) * 1.5;  // extinction ~170 ms
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
        (float)lut.sample(kLut, p * 0.85 + float2( 13.0,  8.0) * tn).r,
        (float)lut.sample(kLut, p * 0.85 + float2(0.41, 0.17) + float2(-8.0, -13.0) * tn).g);
    float2 w = (q - 0.5) * 1.15;

    // ---- Nuages -------------------------------------------------------------
    // Trois lectures multi-octaves à trois échelles/dérives : le différentiel
    // de vitesses entre octaves fait l'évolution interne de la matière. Les
    // dérives sont assez rapides pour que la matière se transforme à vue
    // (10-20 s) — un fond qu'on ne voit jamais bouger n'est qu'un poster.
    float o1 = (float)lut.sample(kLut, p * 1.05 + w * 0.42 + float2( 10.0, -5.0) * tn).r * 0.55;
    float o2 = (float)lut.sample(kLut, p * 2.30 + w * 0.26 + float2(0.37, 0.71) + float2(-14.0, 9.0) * tn).g * 0.30;
    float d12 = o1 + o2;
    float o3 = (float)lut.sample(kLut, p * 4.70 + w * 0.15 + float2(0.61, 0.13) + float2( 24.0, -18.0) * tn).r * 0.15;
    float dens = d12 + o3;
    float cloud = smoothstep(0.22, 0.92, dens);

    // ---- Rim lighting 2-tap (iq) -------------------------------------------
    // La densité ré-échantillonnée un pas VERS le cœur : si elle augmente en
    // allant vers la lumière, on est sur le flanc éclairé. Bords embrasés
    // côté cœur, centres sombres — la lecture 3D des nuages tient là.
    // eps serré : le liseré embrasé devient une ARÊTE fine, pas un dégradé
    // large — la hiérarchie bord dur / bord mou, signature d'une photo.
    const float eps = 0.014;
    float2 pe = p + toCore * eps;
    float e1 = (float)lut.sample(kLut, pe * 1.05 + w * 0.42 + float2( 10.0, -5.0) * tn).r * 0.55;
    float e2 = (float)lut.sample(kLut, pe * 2.30 + w * 0.26 + float2(0.37, 0.71) + float2(-14.0, 9.0) * tn).g * 0.30;
    float rim = clamp((d12 - (e1 + e2)) * 24.0, 0.0, 1.0);
    rim *= rim;

    // ---- Cœur aveuglant (HDR) ----------------------------------------------
    // Gaussien serré très intense + halo lorentzien FENÊTRÉ : la queue en
    // 1/d² porte la lueur jusqu'à mi-écran, la fenêtre exponentielle la tue
    // au-delà — le haut-droite doit rester noir, comme la référence.
    // L'écrêtage au blanc est fait par la courbe filmique, jamais par un clamp.
    // Respiration de portée : la fenêtre du halo s'étend et se rétracte de
    // ±8 % sur ~90 s — la lueur AVANCE visiblement sur l'écran puis recule.
    // Halo COMPACT : fenêtre courte (le récit est « une source souveraine dans
    // l'angle », pas une marée pleine largeur) — le pic gaussien monte en
    // échange, pour un vrai blanc cramé localisé.
    float reach = 1.0 + 0.20 * sin(ph * 10.0 + 0.9)
                      + 0.08 * sin(ph * 23.0 + 2.2);
    float coreI = 9.0 * exp(-d * d * 9.0)
                + 0.09 / (d * d + 0.010) * exp(-d * 3.4 / reach);
    // Vacillement : une source réelle n'est jamais parfaitement constante.
    // ±7 % par trois ondes incommensurables (≈7 s, 47 s, 180 s) — clairement
    // vivant en vision périphérique, jamais mécanique.
    coreI *= 1.0 + 0.055 * sin(ph * 129.0 + 0.7)
                 + 0.022 * sin(ph * 19.0 + 2.3)
                 + 0.012 * sin(ph * 5.0 + 4.1);

    // Nuages d'avant-plan en silhouette DANS le halo : une tranche de densité
    // indépendante qui absorbe la lueur — les masses sombres se découpent sur
    // le blanc, c'est l'ordre de profondeur qui fait le volumétrique.
    float f1 = (float)lut.sample(kLut, p * 1.55 + w * 0.30 + float2(0.73, 0.29) + float2(-7.0, 10.0) * tn).g;
    float f2 = (float)lut.sample(kLut, p * 3.10 + w * 0.20 + float2(0.11, 0.83) + float2( 13.0,  4.0) * tn).r;
    float front = smoothstep(0.45, 0.88, f1 * 0.7 + f2 * 0.45);
    float Tclouds = exp(-3.0 * front);

    // ---- Nuages profonds du haut (absorption pure) ---------------------------
    // De grosses masses NOIRES qui dérivent dans la voûte : elles ne
    // rayonnent rien, elles avalent la faible lueur ambiante (et les étoiles,
    // côté passe étoiles) — des halos noirs profonds qui respirent lentement.
    float topMask = smoothstep(0.68, 0.15, uv.y);
    float tc1 = (float)lut.sample(kLut, p * 0.90 + w * 0.70 + float2(0.19, 0.57) + float2( 14.0, -9.0) * tn).g;
    float tc2 = (float)lut.sample(kLut, p * 2.00 + w * 0.40 + float2(0.47, 0.09) + float2(-18.0, 13.0) * tn).r;
    // Seuil resserré : des MASSES discrètes découpées dans la pénombre, plus
    // un absorbeur omniprésent. Échelles réduites : des silhouettes d'un
    // tiers d'écran que l'œil peut suivre — et, dérives inchangées, ~40 %
    // plus rapides à l'écran.
    float topCloud = smoothstep(0.50, 0.88, tc1 * 0.75 + tc2 * 0.45);
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
    float Ttop = exp(-2.6 * topCloud * topMask * tide);

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
    // La nappe respire en ÉPAISSEUR — l'ancien ballant latéral (±118 px)
    // clapotait comme un bassin ; converti en gonflement, même budget.
    float2 mc = p - float2(0.95 * aspect + 0.015 * sin(ph * 22.0 + 1.7),
                           1.02 + 0.030 * sin(ph * 15.0));
    float mcy = 4.6 * (1.0 + 0.12 * sin(ph * 9.0 + 0.8));
    float mistMask = exp(-(mc.x * mc.x * 2.0 + mc.y * mc.y * mcy));
    // Rafales CELLULAIRES : deux champs grossiers contra-dérivants — leur
    // interférence fait naître et mourir des bouffées SUR PLACE, en 12-25 s,
    // sans aucune direction de propagation. (Les ondes sinusoïdales à phase
    // spatiale d'avant balayaient l'écran à 65-188 px/s : la signature
    // optique exacte d'une vague.) L'extinction complète est conservée.
    float gc1 = (float)lut.sample(kLut, p * 2.4 + float2( 5.0, -3.0) * tn).r;
    float gc2 = (float)lut.sample(kLut, p * 2.4 + float2(0.29, 0.53) + float2(-4.0,  6.0) * tn).g;
    float gust = pow(smoothstep(0.48, 0.85, (gc1 + gc2) * 0.5), 2.0) * 2.2;
    // Brume FINE (grain ×1.5), feuilletage légèrement VERTICAL (convection de
    // fumée qui monte) à composantes latérales OPPOSÉES entre octaves : plus
    // aucun courant laminaire. Flancs incisifs (seuil resserré).
    float m1 = (float)lut.sample(kLut, p * float2(5.4, 4.4) + w * 0.72 + float2( -4.0, 28.0) * tn).g;
    float m2 = (float)lut.sample(kLut, p * float2(11.0, 9.0) + w * 0.48 + float2(0.53, 0.21) + float2(  7.0, 40.0) * tn).r;
    float mist = smoothstep(0.40, 0.88, m1 * 0.52 + m2 * 0.36);
    float mistE = mist * mistMask * 0.27 * gust;

    // Les wisps ridgés portent les filaments (crêtes fines ramifiées) ; le
    // kaliset n'est plus qu'une respiration fractale du halo.
    // Bouillonnement de la zone claire : une couche de brume dédiée qui roule
    // DANS l'anneau de transition du halo, par vagues progressives — deux
    // champs rapides, deux porteuses incommensurables. C'est le spectacle.
    float band = smoothstep(0.12, 0.50, coreI) * smoothstep(4.0, 1.2, coreI);
    // Bouillonnement fin et ascendant, même logique anti-eau que la brume.
    float b1 = (float)lut.sample(kLut, p * float2(6.4, 5.2) + w * 0.90 + float2( -5.0, 30.0) * tn).g;
    float b2 = (float)lut.sample(kLut, p * float2(13.0, 11.0) + w * 0.62 + float2(0.29, 0.67) + float2(  8.0, 42.0) * tn).r;
    float boil = smoothstep(0.44, 0.90, b1 * 0.48 + b2 * 0.44);
    // Même construction cellulaire que la brume, champs décalés : des
    // bouffées locales, jamais une onde qui traverse.
    float gb1 = (float)lut.sample(kLut, p * 2.4 + float2(0.37, 0.61) + float2( 5.0, -3.0) * tn).r;
    float gb2 = (float)lut.sample(kLut, p * 2.4 + float2(0.66, 0.14) + float2(-4.0,  6.0) * tn).g;
    float gust2 = pow(smoothstep(0.42, 0.80, (gb1 + gb2) * 0.5), 2.0) * 2.4;

    // Les silhouettes mordent TOUT — brume et bouillonnement compris. Sans
    // ça, l'additif rebouche les morsures noires et la profondeur disparaît.
    float biteAll = mix(0.30, 1.0, Tclouds);
    float E = coreI * Tclouds * (0.82 + 0.36 * fil)
            + 3.4 * wisp * glowFall * filM
            + cloudE
            + (mistE + boil * band * gust2 * coreI * 0.40) * biteAll;

    // Micro-texture des hautes lumières : une octave fine active seulement
    // dans le clair — la différence entre un dégradé d'ordinateur et une
    // émulsion argentique.
    float o4 = (float)lut.sample(kLut, p * 12.0 + w * 0.10 + float2(0.07, 0.43) + float2(20.0, -15.0) * tn).g;
    E *= 1.0 + (o4 - 0.5) * 0.30 * smoothstep(0.12, 0.80, E);

    // La nuit tombe du haut : rampe verticale explicite — le noir monte
    // depuis le haut et descend plus bas dans l'écran.
    E *= mix(0.18, 1.0, smoothstep(0.10, 0.95, uv.y));

    // Voile de la voûte : une lueur infime et informe (réutilise q, gratuit).
    // Elle n'existe QUE pour être dévorée : les masses noires qui la
    // traversent deviennent des fumées lisibles — du sombre sur sombre.
    // Voile calibré à rebours pour L15/255 en sortie de chaîne : une pénombre
    // VISIBLE sur OLED. (Le 0.040 d'avant atterrissait à L11 — les fumées
    // dévoraient un noir déjà noir, sous le plancher de la dalle.)
    E += 0.062 * (0.7 + 0.6 * q.x) * smoothstep(0.95, 0.20, uv.y);
    E *= Ttop;   // les masses noires avalent le voile et tout ce qui est derrière
    // Liseré fantôme sur les bords des fumées (maximal à mi-densité).
    E += 0.034 * pow(4.0 * topCloud * (1.0 - topCloud), 2.0)
               * smoothstep(0.95, 0.20, uv.y);
    // Rim des fumées : le flanc côté cœur s'éclaire (2-tap sur le champ tc),
    // pondéré par leur propre opacité — des VOLUMES orientés par la source,
    // pas des trous plats.
    float2 pf = p + toCore * 0.016;
    float tcr = (float)lut.sample(kLut, pf * 0.90 + w * 0.70 + float2(0.19, 0.57) + float2( 14.0, -9.0) * tn).g * 0.75
              + (float)lut.sample(kLut, pf * 2.00 + w * 0.40 + float2(0.47, 0.09) + float2(-18.0, 13.0) * tn).r * 0.45;
    float fumeRim = clamp((tc1 * 0.75 + tc2 * 0.45 - tcr) * 20.0, 0.0, 1.0);
    E += 0.035 * fumeRim * fumeRim * topMask * (1.0 - Ttop);
    // Protection de la tab bar : roll-off dans les 10 % inférieurs, HORS
    // hotspot bas-gauche — les libellés reposent sur du fumé, pas du lait.
    E *= 1.0 - 0.50 * smoothstep(0.90, 1.0, uv.y) * smoothstep(0.25, 0.50, uv.x);

    // ---- Teinte thermique -----------------------------------------------------
    // La structure vit dans la luminance ; la chromie n'est qu'un mix ±3.5 %.
    // Le froid des ombres est légèrement VIOLACÉ (le sous-ton de la marque —
    // le CTA émerge du fond au lieu de vibrer contre lui), le chaud est un
    // sépia discret que la compression filmique désature vers le blanc pur.
    float warmth = smoothstep(0.15, 2.5, E);
    float3 tint = mix(float3(0.985, 0.965, 1.045),
                      float3(1.030, 0.995, 0.950), warmth);

    // ---- Compression filmique ------------------------------------------------
    // Révélation : à l'apparition de l'écran, l'exposition monte de −1.5 EV
    // à 0 en ~2 s — le ciel révèle ses détails comme des yeux qui
    // s'habituent à l'obscurité. `reveal` arrive déjà lissé (smoothstep).
    float exposure = 1.12 * (0.35 + 0.65 * reveal);
    float3 L = E * tint;
    float3 c = 1.0 - exp(-exposure * L);
    // Toe QUADRATIQUE : même noir OLED final, mais raccord C1 — la version
    // clippée dessinait un contour fantôme au pourtour des zones noires.
    c = c * c / (c + 0.0085);

    // Tramage anti-banding, sur la MÊME horloge 24 fps que le grain de la
    // passe étoiles (un dither statique sous une scène animée lit « pattern
    // figé ») et renforcé : l'upscale demi-rés divise son efficacité par deux.
    float fr = fract(floor(t * 24.0) * 0.618);
    c += (hash21(position * 1.113 + fr * float2(17.0, 29.0)) - 0.5) * (2.2 / 255.0);

    return half4(half3(saturate(c)), 1.0h);
}

// MARK: Passe crête d'objectif (carte hebdomadaire, demi-résolution)
//
// La corniche de nébuleuse de la carte « Objectif » : une couverture de
// matière blanche accrochée à la silhouette découpée du bord haut, qui
// s'évanouit dans le verre noir quelques dizaines de points plus bas.
// Même grammaire que le ciel — émission HDR, absorption Beer-Lambert,
// compression filmique, dither — mais dans le REPÈRE DE LA CRÊTE : x défile
// le long du bord, y mesure la profondeur SOUS le bord. La matière épouse
// donc la mesa au lieu de la traverser.
//
// Même découpe que le ciel : cette passe (tout est diffus) se rend en
// DEMI-résolution, la poudre d'étoiles dans objectiveCrestStars en pleine.
// Toutes les longueurs sont donc relatives à `fall` — les uniforms arrivent
// déjà divisés par deux, le shader n'a pas à le savoir.
//
// Le profil (épaules, hauteur) arrive en uniforms et reproduit exactement
// ObjectiveCrestShape (ObjectiveCard.swift) : les deux fonctions sont
// jumelles, c'est ce qui soude la matière à la bordure.
//
// Même horloge que le ciel : temps absolu mod 900 s, dérives entières par
// période — la carte est une fenêtre sur le MÊME cosmos, pas un gadget
// indépendant qui vivrait à son propre rythme.

[[ stitchable ]] half4 objectiveCrest(float2 position, half4 color,
                                      float2 size, float t,
                                      float4 shoulders, float2 geom,
                                      texture2d<half> lut) {
    float2 sz = max(size, float2(1.0));
    float u = position.x / sz.x;
    float rise = geom.x, fall = max(geom.y, 1.0);

    // Silhouette — jumelle de CrestProfile.edgeY (Swift).
    float plateau = smoothstep(shoulders.x, shoulders.y, u)
                  * (1.0 - smoothstep(shoulders.z, shoulders.w, u));
    float dyPt = position.y - rise * (1.0 - plateau);   // pt sous la crête

    // Sortie anticipée : plus bas il n'y a que du verre noir — la majorité
    // des fragments de la carte s'arrête ici. Le tramage reste appliqué :
    // un noir mathématique contre un noir tramé dessinerait une couture
    // animée en forme de crête au milieu du verre.
    if (dyPt > fall * 2.1) {
        float frq = fract(floor(t * 24.0) * 0.618);
        float dth = (hash21(position * 1.113 + frq * float2(17.0, 29.0)) - 0.5) * (2.0 / 255.0);
        return half4(half3(saturate(float3(dth))), 1.0h);
    }

    float dy = max(dyPt, 0.0) / fall;    // profondeur normalisée sous le bord
    float tn = t / 900.0;
    float ph = t * PH;

    // ---- Repère-crête, warp partagé ----------------------------------------
    // Feuilleté : la matière est une STRATE posée le long du bord, étirée par
    // lui. Échelle contenue (1.8 répétition sur la largeur) et warp doux :
    // les formes restent larges et soyeuses, jamais un semis de flocons.
    float2 pc = float2(u * 1.8, dy * 1.0);
    float2 q = float2(
        (float)lut.sample(kLut, pc * 0.9 + float2( 7.0,  4.0) * tn).r,
        (float)lut.sample(kLut, pc * 0.9 + float2(0.41, 0.23) + float2(-5.0, -8.0) * tn).g);
    float2 w = (q - 0.5) * 0.60;

    // ---- Le foyer : une lumière qui vit SOUS la crête -----------------------
    // Le récit de la carte : une source cachée DANS la bande — le grand foyer
    // à droite (u≈0.70, 25-45 pt sous le bord), un écho discret à gauche, une
    // épine faible sur toute la largeur. Jamais À la bordure : le fil de
    // lumière est un événement séparé, dessiné par SwiftUI par-dessus.
    // La source ne respire presque pas ; c'est le rideau devant elle qui
    // fait le spectacle.
    float u0 = 0.70 + 0.020 * sin(ph * 3.0 + 1.1);
    float2 g0 = float2((u - u0) / 0.26, (dy - 0.40) / 0.30);
    float2 g1 = float2((u - 0.33) / 0.20, (dy - 0.52) / 0.34);
    float dspine = (dy - 0.42) / 0.42;
    float src = 5.2 * exp(-dot(g0, g0))
              + 1.35 * exp(-dot(g1, g1))
              + 0.36 * exp(-dspine * dspine);
    src *= 1.0 + 0.06 * sin(ph * 13.0 + 0.7) + 0.04 * sin(ph * 29.0 + 2.4);

    // ---- Le rideau : les occulteurs qui cachent puis dévoilent --------------
    // Un pont de nuages DEVANT le foyer, qui dérive le long de la crête assez
    // vite pour qu'on le VOIE : la lumière s'éteint quand une masse passe,
    // se rallume dans une déchirure — cycles de ~10-30 s. Deux échelles à la
    // même dérive LUT (36 répétitions/période, entière → boucle propre), donc
    // des vitesses apparentes différentes : la parallaxe interne du rideau.
    // C'est LUI l'absorption Beer-Lambert de la carte.
    float oc1 = (float)lut.sample(kLut, pc * float2(1.15, 0.80) + w * 0.30 + float2(36.0, -2.0) * tn).g;
    float oc2 = (float)lut.sample(kLut, pc * float2(2.40, 1.65) + w * 0.20 + float2(0.29, 0.61) + float2(36.0, 3.0) * tn).r;
    float occ = smoothstep(0.38, 0.85, oc1 * 0.62 + oc2 * 0.48);
    float Tocc = exp(-3.4 * occ);
    float L = src * Tocc;                        // ce qui perce le rideau

    // Silver lining : le bord d'un occulteur FACE au foyer s'embrase — la
    // dérivée directionnelle de densité vers la source (2-tap, même geste que
    // le rim du ciel). C'est le détail qui vend « la lumière est derrière ».
    float2 toSrc = float2(u0 - u, 0.40 - dy);
    toSrc *= rsqrt(max(dot(toSrc, toSrc), 1e-5));
    const float leps = 0.030;
    float ol1 = (float)lut.sample(kLut, (pc + toSrc * leps) * float2(1.15, 0.80) + w * 0.30 + float2(36.0, -2.0) * tn).g;
    float ol2 = (float)lut.sample(kLut, (pc + toSrc * leps) * float2(2.40, 1.65) + w * 0.20 + float2(0.29, 0.61) + float2(36.0, 3.0) * tn).r;
    float occB = smoothstep(0.38, 0.85, ol1 * 0.62 + ol2 * 0.48);
    float lining = clamp((occ - occB) * 9.0, 0.0, 1.0);
    lining *= lining;

    // ---- Le voile : une soie à deux densités --------------------------------
    // Les grandes formes dominent (o1), les octaves fines ne sont qu'un
    // frémissement — le contraire fait un semis de flocons durs. Deux
    // lectures du même champ : `soft`, la fumée translucide continue, et
    // `dense`, les cœurs qui s'embrasent. Jamais de seuil binaire.
    float o1 = (float)lut.sample(kLut, pc * 1.00 + w * 0.40 + float2( 6.0, -3.0) * tn).r * 0.58;
    float o2 = (float)lut.sample(kLut, pc * 2.30 + w * 0.26 + float2(0.33, 0.71) + float2(-9.0,  5.0) * tn).g * 0.30;
    float o3 = (float)lut.sample(kLut, pc * 4.80 + w * 0.15 + float2(0.57, 0.13) + float2( 14.0, -8.0) * tn).r * 0.12;
    float dens = o1 + o2 + o3;
    float soft = smoothstep(0.15, 0.95, dens);
    float dense = smoothstep(0.45, 1.10, dens);

    // ---- Bande : accrochée au bord, flancs presque propres ------------------
    // Chute rapide (au niveau du titre : verre noir) et épaules quasi nues
    // (×0.16) : la matière vit sur la mesa, les flancs n'ont que le fil.
    float band = exp(-dy * mix(5.5, 3.4, plateau)) * mix(0.16, 1.0, plateau);

    // ---- Wisps : LA structure de la soie ------------------------------------
    // Le ridged multifractal (canal B), échantillonné 6× plus serré en
    // profondeur qu'en largeur : des STRIES horizontales feuilletées qui
    // épousent la crête — c'est lui qui fait la soie de la référence, la fbm
    // n'est plus qu'une brume de fond. Animé par le warp seul : les stries
    // ondulent sur place, ne ruissellent jamais.
    float wisp = pow((float)lut.sample(kLut, float2(u * 2.6, dy * 1.4) + w * 0.30
                                             + float2(4.0, 0.0) * tn).b, 2.0);

    // Liseré de matière à la crête : discret — la fumée frôle le fil, elle
    // ne le dessine pas.
    float rim = exp(-abs(dyPt) / (fall * 0.13));

    // ---- Émission ------------------------------------------------------------
    // Tout est suspendu à L, mais la fumée reste LISIBLE éteinte (la
    // référence garde un voile gris continu même loin du foyer) : les stries
    // ridgées portent la structure, la fbm n'est qu'une brume, les cœurs un
    // relief discret.
    float E = L * (0.38 + 0.20 * band)                      // halo direct
            + soft * band * (0.13 + 1.00 * L)               // brume continue
            + dense * band * 0.30 * L                       // cœurs discrets
            + wisp * band * (0.28 + 2.8 * L)                // LES filaments
            + 2.4 * lining * saturate(src) * band           // silver lining
            + rim * (0.08 + 0.40 * soft + 0.60 * L * soft)  // baiser à la crête
                  * mix(0.30, 1.0, plateau);                // épaules nues

    // Micro-texture des hautes lumières — un frémissement, pas un grain dur.
    float o4 = (float)lut.sample(kLut, pc * 9.0 + w * 0.10 + float2(0.07, 0.43) + float2(12.0, -9.0) * tn).g;
    E *= 1.0 + (o4 - 0.5) * 0.12 * smoothstep(0.10, 0.70, E);

    // ---- Compression filmique ------------------------------------------------
    // Même chromie que le ciel (mêmes ordres de grandeur que sa passe
    // nébuleuse) : froid violacé dans les gris, sépia discret dans le clair
    // que la compression ramène au blanc pur.
    float3 tint = mix(float3(0.985, 0.970, 1.040),
                      float3(1.025, 0.995, 0.955), smoothstep(0.15, 2.2, E));
    float3 c = 1.0 - exp(-1.50 * E * tint);
    c = c * c / (c + 0.0085);

    // Tramage anti-banding, même horloge 24 fps que le ciel.
    float fr = fract(floor(t * 24.0) * 0.618);
    c += (hash21(position * 1.113 + fr * float2(17.0, 29.0)) - 0.5) * (2.0 / 255.0);

    return half4(half3(saturate(c)), 1.0h);
}

// MARK: Passe étoiles de la crête (pleine résolution)
//
// La poudre de la corniche, séparée de la passe diffuse pour la même raison
// que le ciel : les étoiles sont sub-pixel (l'upscale demi-rés les
// détruirait), le diffus est payé au quart du prix. Composée en plusLighter.
//
// Grille hashée de 11 pt, au plus une étoile par cellule. La géométrie est
// évaluée AVANT tout fetch : l'écrasante majorité des fragments sort sans
// toucher la texture ; seuls les pixels réellement éclairés paient les
// 4 fetches d'extinction.

[[ stitchable ]] half4 objectiveCrestStars(float2 position, half4 color,
                                           float2 size, float t,
                                           float4 shoulders, float2 geom,
                                           texture2d<half> lut) {
    constexpr half4 kBlack = half4(0.0h, 0.0h, 0.0h, 1.0h);
    float2 sz = max(size, float2(1.0));
    float u = position.x / sz.x;
    float rise = geom.x, fall = max(geom.y, 1.0);

    // Silhouette — mêmes uniforms que la passe diffuse (échelle pleine).
    float plateau = smoothstep(shoulders.x, shoulders.y, u)
                  * (1.0 - smoothstep(shoulders.z, shoulders.w, u));
    float dyPt = position.y - rise * (1.0 - plateau);
    float dy = max(dyPt, 0.0) / fall;
    if (dy > 1.9) { return kBlack; }        // plus d'étoiles si bas

    float ph = t * PH;

    // ---- Étoiles : la poudre nette dans le noir de la bande -----------------
    // Jitter 0.28 et sigma borné : la queue gaussienne retombe sous 0,5 %
    // AVANT le bord de cellule — la cellule voisine ne dessinant pas cette
    // étoile, une queue qui la traverserait serait tranchée net. Le cutoff
    // radial (même 0.16 que starLayer) borne aussi le coût.
    const float cell = 11.0;
    float2 id = floor(position / cell);
    float4 h = hash42(id + float2(31.7, 7.3));
    float s = 0.0;
    if (h.x < 0.62) {
        float b = pow(h.y, 7.0) * 1.2;
        if (b > 0.004) {
            float2 stp = (id + 0.5 + 0.28 * (h.zw * 2.0 - 1.0)) * cell;
            float2 dp = position - stp;
            float r2 = dot(dp, dp);
            if (r2 < cell * cell * 0.16) {
                float sig = 0.50 + 0.40 * saturate(b);
                s = b * exp(-r2 / (2.0 * sig * sig));
                // Seules les brillantes respirent — deux sinus
                // incommensurables, k entiers sur la boucle de 900 s.
                float twA = 0.35 * smoothstep(0.25, 0.9, b);
                s *= 1.0 + twA * (0.6 * sin(ph * (240.0 + floor(h.z * 300.0)) + h.z * TAU)
                                + 0.4 * sin(ph * ( 91.0 + floor(h.w * 120.0)) + h.w * TAU));
            }
        }
    }

    // ---- Poussières flottantes : rares, larges, elles dérivent amplement ----
    // Le temps ne module que des POSITIONS (règle de l'atmosphère) : la
    // grille entière dérive en Lissajous lente (k entiers), chaque grain
    // erre en plus autour de son point. Devant tout : pas d'extinction.
    float2 mp = position + float2(9.0 * sin(PH * 7.0 * t + 0.8),
                                  6.0 * cos(PH * 11.0 * t + 2.1));
    const float mcell = 36.0;
    float2 mid_ = floor(mp / mcell);
    float4 mh = hash42(mid_ + float2(5.3, 91.7));
    float mote = 0.0;
    if (mh.x < 0.34) {
        float2 mstp = (mid_ + 0.5 + 0.30 * (mh.zw * 2.0 - 1.0)) * mcell;
        mstp += 3.5 * float2(sin(PH * (12.0 + floor(mh.z * 20.0)) * t + mh.w * TAU),
                             cos(PH * (16.0 + floor(mh.w * 14.0)) * t + mh.z * TAU));
        float2 mdp = mp - mstp;
        float mr2 = dot(mdp, mdp);
        if (mr2 < mcell * mcell * 0.16) {
            float msig = 1.1 + 1.3 * mh.z;
            mote = (0.05 + 0.16 * mh.y * mh.y) * exp(-mr2 / (2.0 * msig * msig));
        }
    }

    if (s < 0.002 && mote < 0.002) { return kBlack; }

    float band = exp(-dy * mix(5.5, 3.4, plateau)) * mix(0.16, 1.0, plateau);

    // Extinction des étoiles par le RIDEAU de la passe diffuse (mêmes
    // champs, mêmes dérives) : quand une masse voile le foyer, elle avale
    // ses étoiles au même moment — sinon elles flotteraient devant.
    float ext = 1.0;
    if (s >= 0.002) {
        float tn = t / 900.0;
        float2 pc = float2(u * 2.6, dy * 1.05);
        float qq = (float)lut.sample(kLut, pc * 0.9 + float2(7.0, 4.0) * tn).r;
        float2 w = float2(qq - 0.5, 0.5 - qq) * 0.85;
        float oc1 = (float)lut.sample(kLut, pc * float2(1.15, 0.80) + w * 0.30 + float2(36.0, -2.0) * tn).g;
        float oc2 = (float)lut.sample(kLut, pc * float2(2.40, 1.65) + w * 0.20 + float2(0.29, 0.61) + float2(36.0, 3.0) * tn).r;
        ext = exp(-2.0 * smoothstep(0.38, 0.85, oc1 * 0.62 + oc2 * 0.48));
    }

    float E = 1.5 * s * ext * mix(0.30, 1.0, band) * smoothstep(1.9, 0.6, dy)
            + mote * smoothstep(1.6, 0.25, dy);

    // Même compression que la passe diffuse : les étoiles s'écrasent au
    // blanc sur la même courbe que la matière qu'elles habitent.
    float c = 1.0 - exp(-1.50 * E);
    c = c * c / (c + 0.0085);
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
///   - `wanderAmp` : amplitude d'errance individuelle (en fraction de
///     cellule) — 0.045 pour les étoiles, ~0.11 pour la poussière qui danse.
static float3 starLayer(float2 pos, float t, float cellPt, float density,
                        float alphaPow, float gain, float2 seed,
                        float2x2 grid, float sway, float2 swayK,
                        float wanderAmp,
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
    // Errance en LISSAJOUS : deux porteuses incommensurables par grain —
    // chaque poussière décrit sa propre boucle paresseuse, comme dans un rai
    // de soleil. Vitesse moyenne nulle : jamais de direction commune (une
    // chute partagée = boule à neige).
    float wk  = 20.0 + floor(h.z * 40.0);
    float wk2 = 14.0 + floor(h.y * 26.0);
    stp += wanderAmp * float2(sin(PH * wk * t + h.w * TAU),
                              0.6 * cos(PH * wk2 * t + h.z * TAU));

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
    // Conservation d'énergie sous 0.48 px : une gaussienne sub-pixel qui
    // dérive scintille avec la phase d'échantillonnage (shimmer d'aliasing) —
    // on plafonne le sigma et on compense l'amplitude.
    float sub = min(sig / 0.48, 1.0);
    sig = max(sig, 0.48);
    float s = exp(-r2 / (2.0 * sig * sig)) * sub * sub;

    if (halos && b > 0.5) {
        float rh2 = r2 / ((1.2 + 4.5 * b) * (1.2 + 4.5 * b));
        s += 0.16 * pow(1.0 + rh2, -1.75);            // Moffat β≈1.75
    }
    // Pas d'aigrettes : la croix de diffraction à l'échelle d'un téléphone
    // lit « clip-art d'étoile » — le Moffat et les flashs rares suffisent aux
    // héros. (`spikes` ne marque plus que la couche héros, pour les flashs.)

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

    // Continuum chromatique : majoritairement froid-argent, rares chaudes —
    // jamais deux populations binaires, chroma plafonnée à ~3 % (de l'argent,
    // pas des LED).
    float3 tintS = mix(float3(0.955, 0.975, 1.028), float3(1.030, 0.990, 0.945),
                       pow(fract(h.y * 17.3), 5.0));
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
    float qq = (float)lut.sample(kLut, p * 0.85 + float2(13.0, 8.0) * tn).r;
    float2 wp = float2(qq - 0.5, 0.5 - qq) * 1.0;
    float dens = (float)lut.sample(kLut, p * 1.05 + wp * 0.42 + float2( 10.0, -5.0) * tn).r * 0.55
               + (float)lut.sample(kLut, p * 2.30 + wp * 0.26 + float2(0.37, 0.71) + float2(-14.0, 9.0) * tn).g * 0.30;
    // Seuls les nuages VRAIMENT denses éteignent : la référence fourmille
    // d'étoiles jusque dans les zones de brume moyenne.
    float T = exp(-1.8 * smoothstep(0.38, 0.95, dens));

    // Les masses noires du haut (mêmes champs que la passe nébuleuse) avalent
    // aussi les étoiles : un halo noir qui n'éteindrait pas le ciel derrière
    // lui ne serait qu'une tache.
    float topMask = smoothstep(0.68, 0.15, uv.y);
    float tc1 = (float)lut.sample(kLut, p * 0.90 + wp * 0.70 + float2(0.19, 0.57) + float2( 14.0, -9.0) * tn).g;
    float tc2 = (float)lut.sample(kLut, p * 2.00 + wp * 0.40 + float2(0.47, 0.09) + float2(-18.0, 13.0) * tn).r;
    float topCloud = smoothstep(0.50, 0.88, tc1 * 0.75 + tc2 * 0.45);
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
    // Extinction durcie : une masse qui passe devant un champ d'étoiles et
    // les éteint une à une est le 2ᵉ signal de mouvement le plus fort du ciel.
    T *= exp(-2.2 * topCloud * topMask * tide);

    // Les étoiles se noient dans le blanc cramé du cœur — sur un capteur,
    // le halo les avale bien avant le centre. Même formule que la passe
    // nébuleuse (respiration `reach` comprise : l'avalement coïncide avec le
    // blanc qu'on voit, et le rai qui balaie allume la poussière).
    float reach = 1.0 + 0.20 * sin(ph * 10.0 + 0.9)
                      + 0.08 * sin(ph * 23.0 + 2.2);
    float coreI = 9.0 * exp(-d * d * 9.0)
                + 0.09 / (d * d + 0.010) * exp(-d * 3.4 / reach);
    float wash = saturate(1.0 - coreI * 0.40);
    // Luminance de fond estimée : chaque population de poussière a sa zone —
    // la fine dans le noir, la liaison jusqu'aux gris moyens, les motes du
    // rai dans la lumière seulement.
    float lp = 1.0 - exp(-(coreI + dens * 0.6));
    float fineMask = 1.0 - smoothstep(0.30, 0.45, lp);
    float liaisonMask = 1.0 - smoothstep(0.42, 0.72, lp);

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
    // Balancements propres réduits (un ciel qui se cisaille est physiquement
    // impossible) — la parallaxe gyroscopique, elle, garde toute son ampleur.
    s += starLayer(position + tilt *  8.0, t,   2.9, 1.00, 14.0, 0.42, float2(13.1,  7.7),
                   g0, 0.8, float2(2.0, 3.0), 0.045, false, false, T, 1.0, reveal) * T;
    s += starLayer(position + tilt * 24.0, t,   8.0, 0.95, 10.0, 0.60, float2(41.7,  3.3),
                   g1, 1.0, float2(3.0, 2.0), 0.045, false, false, T, 1.0, reveal) * T;
    s += starLayer(position + tilt * 42.0, t,  23.0, 0.75,  6.0, 1.05, float2(23.9, 11.3),
                   g2, 0.8, float2(1.0, 4.0), 0.045, true,  false, T, 1.0, reveal);
    // Poussière FINE scintillante — le liant qui transforme « ciel étoilé »
    // en « nébuleuse poussiéreuse » : ~1500-2000 piqûres au ras du seuil,
    // réservées au noir, derrière toute la colonne de matière (×T).
    s += starLayer(position + tilt * 54.0, t,   6.5, 0.55,  8.0, 0.30, float2(91.3,  5.7),
                   g2, 1.0, float2(2.0, 3.0), 0.045, false, false, T, 1.25, reveal)
       * fineMask * T;
    // L3 — héros : ~7 étoiles marquantes, halo Moffat, quasi d'avant-plan.
    s += starLayer(position + tilt * 66.0, t, 105.0, 0.25,  3.0, 0.85, float2( 5.3, 29.1),
                   g3, 0.3, float2(2.0, 1.0), 0.045, true,  true,
                   mix(1.0, T, 0.25), 1.0, reveal);
    // Particules de LIAISON — densifiées et tolérées jusqu'aux gris moyens :
    // le pont granulométrique entre la poudre du noir et les motes du rai.
    s += starLayer(position + tilt * 76.0, t,  40.0, 0.55,  5.0, 0.45, float2(61.7, 17.9),
                   g1, 4.0, float2(3.0, 5.0), 0.11, false, false, 1.0, 1.7, reveal)
       * liaisonMask;
    s *= wash;

    // MOTES DANS LE RAI — la poussière qui danse dans le faisceau, l'effet
    // signature. Fenêtrées sur l'anneau de lumière uniquement (hors wash et
    // hors masques sombres), allumées par la respiration du halo (reach est
    // dans coreI), et MORDUES par les silhouettes qui traversent le rai —
    // de la poussière volumétrique, pas des autocollants.
    float beam = smoothstep(0.10, 0.45, coreI) * (1.0 - smoothstep(1.2, 3.5, coreI));
    if (beam > 0.01) {
        float sf1 = (float)lut.sample(kLut, p * 1.55 + wp * 0.30 + float2(0.73, 0.29) + float2(-7.0, 10.0) * tn).g;
        float sf2 = (float)lut.sample(kLut, p * 3.10 + wp * 0.20 + float2(0.11, 0.83) + float2( 13.0,  4.0) * tn).r;
        float TcS = exp(-3.0 * smoothstep(0.45, 0.88, sf1 * 0.7 + sf2 * 0.45));
        s += starLayer(position + tilt * 92.0, t,  30.0, 0.35,  4.5, 0.90, float2(77.3, 41.9),
                       g3, 3.0, float2(5.0, 2.0), 0.12, false, false, 1.0, 2.4, reveal)
           * beam * TcS;
    }

    // Étoile filante : rare, déterministe, au-dessus du wash (elle brûle dans
    // l'atmosphère, devant tout).
    s += meteor(position + tilt * 30.0, sz, t);

    // Grain photographique animé, pondéré par une estimation de la luminance
    // de fond : maximal dans les demi-tons, quasi nul dans les noirs (le
    // niveau de noir OLED ne remonte pas) comme dans le blanc cramé.
    // Grain CENTRÉ (bidirectionnel, comme l'argentique — la version non
    // centrée dérivait les demi-tons de +0,6 %), même horloge 24 fps que le
    // dither de la passe nébuleuse.
    float frame = floor(t * 24.0);
    float g = hash21(position + fract(frame * 0.618) * float2(17.0, 29.0)) - 0.5;
    s += g * 0.011 * (1.0 - abs(2.0 * lp - 1.0));

    // Borne basse obligatoire : la passe est composée en plusLighter, une
    // composante négative (grain centré) aurait un comportement indéfini.
    return half4(half3(clamp(s, float3(0.0), float3(1.0))), 1.0h);
}
