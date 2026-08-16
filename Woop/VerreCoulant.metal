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

// `mode` — LE MINI DEBUG de la restauration (16-08) :
//   0 FINAL          le rendu normal
//   1 SDF            la géométrie analytique seule (forme/rayon/coins)
//   2 INSIDE ONLY    la matière intérieure, alpha extérieur = 0 DUR
//   3 OUTSIDE ONLY   la lumière d'air seule (cellule visible = FAIL)
//   4 BRIGHTNESS ×16 le final ×16 sur alpha plein — chasse aux fuites
// `t` est GELÉ à 0 par l'hôte pendant toute la calibration (la loi du
// brief : mêmes pixels à chaque frame ; à t=0 swell/coulée/drift sont
// des constantes et le dither ne dépend que de la position).
// `map` — la CollapsedGlassControlMap (Phase 8) : l'empreinte optique de
// la référence, extraite offline (tools/verre/controlmap.py). R = scatter
// blanc / G = hotspots spéculaires / B = chaleur / A = rugosité. La map
// MODULE la physique (elle est la géographie des accidents), elle ne
// s'affiche jamais telle quelle. Une map noire = aucune modulation.
[[ stitchable ]] half4 verreGonfle(float2 position, half4 color,
                                   float2 size, float t,
                                   float pad, float rHaut, float rBas,
                                   float mode, float allege,
                                   texture2d<half, access::sample> map) {
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

    // ===== LE CHEMIN COURT (16-08) =====
    // `allege` vaut 1 pendant la course (dépliement sous le doigt ou
    // ressort). Mesuré au film AVANT de toucher quoi que ce soit : la
    // course tenait 30 images distinctes par seconde, et le témoin SANS
    // allègements en faisait 34,7 — la preuve que le drapeau était passé
    // au verre sans y rien faire (le fichier le disait lui-même).
    // Ce qui tombe pendant la course : les accidents FINS, la ControlMap
    // et le grain. Ce qui reste : la géométrie, les grands champs et les
    // fils — tout ce qui porte la LECTURE d'un objet en mouvement.
    // Au repos, `allege` vaut 0 et l'image est au pixel près la même.
    float fin = 1.0 - allege;    // 1 au repos, 0 en course
    float3 E = float3(0.0);      // l'énergie lumineuse, par canal
    float3 rgbIn = float3(0.0);  // la matière intérieure (avant clip)
    float3 air = float3(0.0);    // la lumière d'air (hors carte)
    float aAir = 0.0;

    if (inside > 0.001) {
        // ---- 8. LE SOCLE : noir de verre, jamais plat — 11/255 au
        // haut-centre, à peine plus dense au pied (la chaleur du bas est
        // ADDITIVE, elle vient de la brume, pas du socle).
        // Phase 3 : recalé sur la cible centre 0,050 = base + retombées
        // (la référence : 11-13/255 au haut-centre, à peine plus chaud
        // au pied).
        float3 base = mix(float3(0.037, 0.036, 0.039),
                          float3(0.041, 0.037, 0.034),
                          smoothstep(0.0, H, q.y));

        // ===== LE FACTEUR D'OUVERTURE (16-08) =====
        // Sa loi : « ne touche JAMAIS à la mini card, que la grande ».
        // `ouvert` vaut EXACTEMENT 0 tant que la carte fait sa taille
        // repliée (125 pt) : la petite est protégée par CONSTRUCTION.
        // Tout ce qui ne concerne que la carte dépliée passe par lui.
        float ouvert = smoothstep(200.0, 320.0, H);
        // ===== SES DEUX FENÊTRES (16-08) =====
        // Ses carrés verts, convertis au pixel : y 121-204 pt et
        // y 329-412 pt, deux fenêtres de 83 pt séparées par 125 pt de
        // vide. Sa loi : « pas de halo bizarre SAUF aux endroits où j'ai
        // mis les carrés verts ; pour le reste, juste le trait fin comme
        // la mini card ». Tout ce qui est halo, épaule ou accident sur le
        // flanc gauche de la GRANDE carte ne vit donc plus que là-dedans.
        // EN CLOCHES, PAS EN CRÉNEAUX (16-08) : « atténue et dégrade, ça
        // fait trop posé à l'arrache ». Un créneau à bords raides se lit
        // comme un autocollant ; une cloche se lit comme de la lumière.
        // Centres des fenêtres : 162 et 370 pt, sigma 34 — elles montent
        // et redescendent sur toute leur longueur au lieu de s'allumer
        // d'un coup.
        // Recalées de −38 pt : mesuré à l'écran, la première cloche
        // culminait à y≈200 au lieu de 162. Le repère du shader et
        // celui de la capture ne coïncident pas sur la carte dépliée
        // (son haut déborde de la zone visible) : on cale sur ce qui
        // se VOIT, pas sur ce que je crois.
        float f1 = q.y - 124.0, f2 = q.y - 332.0;
        float fenL = exp(-f1 * f1 / (2.0 * 34.0 * 34.0))
                   + exp(-f2 * f2 / (2.0 * 34.0 * 34.0));
        fenL = clamp(fenL, 0.0, 1.0);
        // L'extinction du flanc gauche emporte AUSSI l'épaule intérieure :
        // sinon le fil s'éteint mais le verre reste clair derrière lui, et
        // l'œil ne voit aucun trou (« je vois pas ce que tu as fait »).
        // (Les deux extinctions de l'ancienne conception sont retirées :
        // elles se battaient avec les fenêtres — la seconde tombait pile
        // sur la fenêtre basse et l'éteignait.)
        float creuxOuvert = 1.0;

        // ---- 1. L'ÉPAULE GAUCHE — deux facettes. Profil mesuré : montée
        // au ras du trait, CREUX à ~2,3 pt, rebond de seconde facette à
        // ~3,6 pt, décroissance lente (portée 8,5 pt) éteinte vers 16 pt.
        // Son épaisseur ONDULE en descendant (la coulée de l'obsidienne) :
        // on module la PROFONDEUR, jamais l'amplitude.
        float coulee = 1.0 + 0.070 * sin(q.y * 0.045 - t * 0.18)
                           + 0.050 * sin(q.y * 0.021 - t * 0.11 + 1.3);
        float te = tIn / coulee;
        // FOUETTAGE MICROSCOPIQUE du 16-08 (ses deux crops du coin TL) :
        // l'épaule mesurée HAUTEUR PAR HAUTEUR. Le motif constant de la
        // référence : fil FIN → SILLON PROFOND à ~1,9 pt (0,23 au coin !)
        // → facette — et tout VARIE avec la hauteur : pas de facette en
        // haut (y<20 %) ni en bas (y>70 %), sillon profond en haut
        // (0,23) et doux au milieu (0,47), bande courte en haut (10 pt),
        // pleine au milieu (13 pt), morte dès 6 pt en bas.
        // EN POINTS ABSOLUS (16-08) — la cause du « pâté » de la carte
        // dépliée. Ces trois lois étaient en fraction de hauteur : le
        // régime ÉPAULE LARGE (10 à 13 pt) est défini de 10 à 35 % de la
        // hauteur, ce qui fait 32 pt sur la mini carte mais **120 pt** sur
        // la dépliée. Le haut du flanc y vivait donc en régime épais sur
        // toute sa longueur visible. Ce n'était pas un trait plus gros,
        // c'était le régime épais qui durait quatre fois trop longtemps.
        // Conversion exacte à 125 pt (0,20·125 = 25 · 0,34·125 = 42,5 ·
        // 0,62·125 = 77,5 · 0,78·125 = 97,5 · 0,10·125 = 12,5 ·
        // 0,35·125 = 43,75 · 0,60·125 = 75 · 0,80·125 = 100).
        float facetteH = smoothstep(25.0, 42.5, q.y)
                       * (1.0 - smoothstep(77.5, 97.5, q.y));
        float larg = mix(mix(10.0, 13.0, smoothstep(12.5, 43.75, q.y)),
                         6.0, smoothstep(75.0, 100.0, q.y));
        float corps = smoothstep(0.3, 1.3, te)
                    * exp(-max(te - 1.3, 0.0) / 6.5) * 0.40
                    * smoothstep(larg + 3.0, larg - 3.0, te);
        float facette2 = 0.55 * exp(-(te - 3.4) * (te - 3.4) / 1.4)
                       * facetteH;
        // LE SILLON — multiplicatif : c'est LUI le « double trait » du
        // biseau. Profond au coin, doux à mi-hauteur.
        float sillonP = mix(0.78, 0.38, smoothstep(18.75, 50.0, q.y));
        float sillon = 1.0 - sillonP * exp(-(te - 1.9) * (te - 1.9) / 0.55);
        float profil = max((corps + facette2) * sillon, 0.0);
        // Les débords de coins TUÉS (ils faisaient le double-pic du
        // coin : 0,69 à 6 pt PUIS 0,69 à 10 pt — un artefact).
        float wEp = pow(wL, 0.55)
                  + 0.06 * exp(-dTL / 40.0) + 0.06 * exp(-dBL / 40.0);
        E += (0.95 * profil * min(wEp, 1.1) * creuxOuvert
              * mix(1.0, fenL, ouvert)) * vgNeutre;

        // ---- 2. LA FLAQUE DU FLANC DROIT — la lumière du fil blanc qui
        // se reflète DANS le côté : exponentielle depuis l'arête droite,
        // portée 13 pt, plus forte à mi-hauteur. BAISSÉE au tour 2 : à
        // 0,72 elle fusionnait avec le fil et l'air en une nappe cramée
        // de 40 pt (mesuré 205-240 sur tout le flanc) — le fil ne
        // tranche que sur du verre SOMBRE (référence : corps 65 à 19 pt,
        // 112 au ras, fil 218, air 35).
        float tR = max(W - q.x, 0.0);
        // PHASE 4 : la flaque GROSSIT vers le bas (mesuré : 0,30 à
        // y=20 %, 0,44 à 65 %, 0,6+ à 85 % — c'est en bas qu'elle vit,
        // et elle survit au fil mort : le « lait sans fil » de y>85 %).
        float fy = q.y / H;
        float profR = 0.50 + 0.50 * smoothstep(0.20, 0.85, fy);
        // ... et le CREUX SOMBRE à ~1,5 pt : la flaque meurt au ras de
        // l'arête — entre elle et le cœur spéculaire, le verre redevient
        // foncé (le profil mesuré : montée, CREUX à -2 px, cœur à 0).
        // ... et le creux S'EFFACE en bas (mesuré à y=85 % : le lait
        // touche l'arête, 0,77 à -2 px pendant que le fil est mort) :
        // c'est le « lait sans fil », la signature du bas du flanc.
        // Le creux n'existe QUE dans le tiers haut (mesuré : 0,35 à
        // 1,4 pt à y=21-34 %) ; sous y=45 % la photo n'a plus de creux
        // du tout — le fil se prolonge en ÉPAULE (0,61 à 1,4 pt, 0,59 à
        // 2,1). Mon creux courait sur toute la hauteur : il coupait le
        // flanc en deux.
        float creuxD = mix(smoothstep(0.4, 2.6, tR), 1.0,
                           smoothstep(0.34, 0.50, fy));
        // LA DIFFUSION INTERNE (sa loi n°2, « micro diffusion dans la
        // matière ») : sous y=45 % la photo tient 0,55-0,62 jusqu'à 4 pt
        // et ne retombe au noir qu'à 18 pt. J'étais à 0,33 — d'où la
        // droite « plate ». Portée 15 pt, amplitude ×1,8.
        E += (1.05 * exp(-tR / 13.0) * creuxD * profR
              * smoothstep(0.08, 0.24, fy))
             * float3(1.0, 0.90, 0.80);
        // LE GLISSEMENT (17-08, sa loi n°1) : sous le coin droit la
        // lumière ne s'arrête pas au fil — elle ACCROCHE le coin, se
        // comprime dans la courbe et GLISSE dans le verre. C'est elle
        // qui fait lire « gonflé » au lieu de « bord éclairé ».
        // Mesuré à l'arc (θ<12°) : 0,49-0,63 à 2-7 pt sous le coin,
        // éteint à 7-14 pt (0,21) ; et une seconde flaque à y=28 %
        // (0,47 à 3-7 pt), morte à y=40 %. Portée COURTE : elle hugge
        // l'arête, elle n'éclaire pas la carte.
        // Le profil radial mesuré (réf, pas de 0,7 pt) le dit exactement :
        // fil au bord — SILLON à 1,4 pt (0,35) — puis une BANDE claire et
        // LARGE de 2,8 à 8,4 pt (0,60-0,77) — puis une chute NETTE à
        // 10,5 pt. Elle vit de y=18 % à 40 %, pic à 26 %, et meurt plus
        // bas (la flaque prend le relais). Ce n'est pas une nappe qui
        // décroît : c'est une bande DÉTACHÉE du fil, et c'est ce
        // détachement qui donne l'épaisseur du verre.
        // ... et elle est en LENTILLE, pas en dalle : étroite et vive en
        // haut (y=21 % : 0,77 mais finie à 5,5 pt), large au ventre
        // (y=26-30 % : 9,5 pt), éteinte à 40 %.
        // ASYMÉTRIQUE : elle monte doucement depuis y=16 % et TOMBE vite
        // après le ventre (à y=34 % la photo est déjà revenue à 0,46).
        // ANCRÉE EN POINTS, PAS EN FRACTION (16-08). C'est LA cause du
        // « gros halo blanc une fois déplié » : ce ventre était écrit en
        // fraction de hauteur (fy) alors que son front est en points. La
        // carte passant de 125 à 480 pt, son centre glissait de y=27 à
        // y=104 pt et son front de 5,5 à 44 pt — elle enflait huit fois.
        // La conversion est EXACTE à 125 pt : 0,216·125 = 27 pt,
        // 0,00135·125² = 21,1 et 0,0077·125² = 120,3 — la carte repliée ne
        // bouge donc pas d'un centième, par construction.
        float dyD = q.y - 27.0;
        float bellD = exp(-dyD * dyD / (dyD < 0.0 ? 21.1 : 120.3));
        // LA DEUXIÈME TACHE, tuée le 17-08 : je l'avais construite en
        // DALLE — smoothstep d'entrée à 2,6 pt, plateau, puis falaise à
        // 9,6. Mesuré à y=26 % (2 / 5 / 9 / 14 pt) : elle fait
        // 0,55 / 0,68 / 0,44 / 0,21 (un SOMMET à 5 pt puis ça retombe),
        // moi 0,66 / 0,75 / 0,72 / 0,21 — plat jusqu'à 9 pt PUIS une
        // falaise. Un dessus plat avec une falaise, ça a un CONTOUR :
        // ça se lit comme un losange collé au bord. Un seul lobe, pas
        // de seuil, pas d'épaule : la lumière n'a plus de bord.
        // ELLE EST EN DIAGONALE — son verdict du 17-08, et la carte
        // numérique de sa photo (case de 2 pt) le prouve : le front de
        // lumière est à 5 pt du bord à y=24, 7 pt à y=30, 10 pt à y=34,
        // 13 pt à y=40. **Il rentre d'1 pt tous les 2 pt de descente.**
        // La mienne était à 4-6 pt de y=24 à y=40 — PENTE ZÉRO, parce
        // qu'une lumière fonction de la seule distance au bord ne PEUT
        // être qu'une bande parallèle au bord. Ce n'est pas une bande :
        // c'est un COIN de lumière qui entre par l'angle et s'ouvre en
        // descendant (5 pt de large à y=26, 11 pt à y=40).
        float frontD = 2.0 + 0.50 * (q.y - 20.0);
        float bandeD = smoothstep(0.8, 2.4, tR)
                     * (1.0 - smoothstep(frontD - 2.0, frontD + 2.0, tR))
                     * bellD;
        E += (0.92 * bandeD) * float3(1.0, 0.94, 0.88);

        // ---- 4. LA NAPPE DU COIN HAUT-DROIT — une gaussienne elliptique
        // TOURNÉE qui entre par le coin et descend en biais vers le
        // centre (le faisceau oblique de l'obsidienne, transposé) :
        // crête mesurée mourant en ~90 pt.
        // Phase 3 : la lame TR recalée sur sa zone (médiane cible 0,102
        // — mesurée chez moi à 0,375, 3,7× trop).
        E += (0.02 * vgLobe(q, float2(W + 14.0, -14.0),
                            normalize(float2(-0.60, 0.80)),
                            float2(95.0, 20.0))) * vgVoile;
        // LE VOILE DU HAUT — ressuscité avec ses coordonnées : la zone
        // haute de la référence tient à 0,106 de médiane contre 0,050
        // au centre — il Y A un souffle qui descend du fil (tué à tort
        // au premier passage de la purge).
        // ... plus discret vers le coin TR (sa zone mesure 0,102 contre
        // 0,106 au haut-centre : le voile n'est pas uniforme).
        E += (0.16 * exp(-q.y / 9.0)
              * (1.0 - 0.5 * smoothstep(0.75, 0.95, q.x / W)))
             * float3(1.0, 0.97, 0.94);
        // LE LIT DU BIJOU (fouettage 16-08) : sous la tranche haute, de
        // x=4 à 26 %, le ventre de la référence tient 0,22 constant à
        // 3 pt sous le fil.
        float fxB = q.x / W;
        E += (0.11 * smoothstep(0.030, 0.065, fxB)
                   * (1.0 - smoothstep(0.24, 0.32, fxB))
                   * exp(-q.y / 6.5)) * float3(1.0, 0.95, 0.90);
        // LA TRAÎNÉE DU BIJOU (re-challenge de ses deux téléphones) :
        // une bande spéculaire LARGE (σ 2,2 pt, posée 1,5 pt DANS le
        // verre) qui ENVELOPPE le coin TL — elle monte du flanc, tourne
        // avec l'arc, et meurt vite sur la tranche haute (anisotrope :
        // pleine où la normale regarde à gauche, un tiers sur le haut).
        // C'est ELLE qu'on voit à l'échelle de ses screenshots — le fil
        // d'un pixel y disparaît.
        // (Recadré : SA cible n'est PAS le coin — c'est LA BARRE de la
        // tranche haute juste avant le coin, x≈12-22 %. La traînée du
        // coin revient à la prescription des juges : un CŒUR spéculaire
        // fusionné au fil + un halo serré, LONGUE sur le flanc (65 pt),
        // COURTE sur la tranche haute (26 pt) — et modeste à l'apex.)
        float dcC = d + 0.8;
        float coeurC = exp(-dcC * dcC / (2.0 * 1.2 * 1.2));
        float dhC = d + 2.0;
        float haloC = 0.25 * exp(-dhC * dhC / (2.0 * 5.5 * 5.5));
        float porteeC = mix(1.00 * rH, 2.50 * rH, wL);
        // LE COIN LUI-MÊME EST QUASI ÉTEINT (son verdict du 16-08 :
        // « très très minimal dans le coin gauche ») — l'apex meurt,
        // seule la descente du flanc et l'approche survivent.
        // 16-08, sa marque verte sur le coin haut-gauche : « enlève le
        // blanc trop fort dans le coin gauche — idéalement il ressemble au
        // coin droit ». Mesuré arc par arc, et elle a raison au chiffre :
        // ses DEUX coins du haut sont JUMEAUX (0,83/0,76 · 0,67/0,64 ·
        // 0,59/0,56 · 0,41/0,46 · 0,37/0,35 à 0-15-30-45-90°), quand mon
        // gauche écrasait mon droit de +0,37 à la diagonale (0,78 contre
        // 0,41). Le coupable est CE terme : sa portée de 53 pt à 45° le
        // fait culminer pile sur la diagonale, là où sa photo est au plus
        // bas. On le divise, et l'apex meurt plus large.
        float apexMort = 1.0 - 0.88 * exp(-dTL / (0.69 * rH));
        E += (0.26 * (0.15 + 0.85 * wL) * (coeurC + haloC)
              * exp(-dTL / porteeC) * apexMort) * float3(1.0, 0.96, 0.92);
        // LA BARRE-BIJOU « juste avant le coin gauche » (sa flèche,
        // 16-08) : le segment de la tranche haute x 12-22 % — un cœur
        // de 2 pt POSÉ DANS LE VERRE avec son halo, qui LUIT à l'échelle
        // réelle. C'est l'événement mesuré à 0,72-0,76 de pic chez elle.
        float segG = exp(-(fxB - 0.175) * (fxB - 0.175) / 0.0016);
        float dcT = d + 0.9;
        float coeurT = exp(-dcT * dcT / (2.0 * 1.1 * 1.1));
        float dhT = d + 2.2;
        float haloT = 0.30 * exp(-dhT * dhT / (2.0 * 4.5 * 4.5));
        E += (1.35 * segG * wT * (coeurT + haloT))
             * float3(1.0, 0.97, 0.93);
        // LE BAIN DU COIN : la luminescence douce qui remplit le
        // triangle (x<22 %, y<38 %) — le pont vers l'aura du médaillon,
        // comme chez elle. Sans lui, le coin est vide entre fil et
        // médaillon.
        // ... élargi et RÉCHAUFFÉ vers le médaillon (juge n°2 : chez
        // elle le bain et l'aura se REJOIGNENT, aucun noir entre eux).
        float bainW = smoothstep(0.32, 0.02, fxB)
                    * smoothstep(0.50, 0.02, q.y / H);
        float3 cBain = mix(float3(1.0, 0.95, 0.90),
                           float3(1.0, 0.86, 0.68),
                           smoothstep(0.10, 0.45, q.y / H));
        // Divisé par deux (16-08) : c'est lui qui tenait encore le coin
        // haut-gauche à +0,13 sur la diagonale et +0,10 sur la tranche
        // haute après que le fil et la traînée aient été dégonflés.
        E += (0.09 * bainW) * cBain;

        // ---- 5 + 6. LA BRUME CHAUDE — le voile sépia du bas (portée
        // 14 pt, renforcé vers les deux coins) et la flaque du quart
        // bas-droit (mesurée à (81,66,53) au ras du coin).
        float tB = max(H - q.y, 0.0);
        float coins = 0.45 + 0.95 * exp(-dBR / 110.0) + 0.55 * exp(-dBL / 120.0);
        E += (0.14 * exp(-tB / 14.0) * coins) * vgSepia;
        // Phase 3 : le lait BR à sa cible (médiane 0,252) — et il ne
        // déborde plus sur la zone droite (portée 34, plus 48).
        E += (0.30 * exp(-dBR / 32.0)) * vgCreme;
        // LA BRAISE DU BAS (17-08) — « il manque un halo orangé en bas
        // de carte, elle doit être plus en avant que les autres ». Deux
        // sources croisées (le crop de référence pour le dedans, sa
        // capture du Bureau pour l'air). Son maximum DÉRIVE VERS LA
        // DROITE en montant : x=72 % à 1 pt, 74 % à 4 pt, 78 % à 8 pt,
        // 80 % à 14 pt — 2,2 pt vers la droite par point de montée.
        // Cibles : 0,55 / 0,41 / 0,36 / 0,29 de luminance, chromie
        // +0,50 → +0,25. C'est l'événement le PLUS FORT de son bas
        // (0,55 contre 0,28 au doré de x=30 %) ; chez moi c'était
        // l'inverse. Large et douce (σ 30 pt) : un halo, pas un trait.
        // ================= LE BAS : TROIS OBJETS =================
        // 17-08. Elle décrit « un petit halo ET un petit trait légèrement
        // en diagonal arrondi » ; la carte de CHROMIE de sa photo montre
        // en fait TROIS choses distinctes, que ma nappe unique écrasait :
        //
        //   1. LE CHEVEU EN ARC, couché sur l'arête basse. Épaisseur
        //      1,0-1,3 pt — le calibre exact du trait blanc du coin. Sa
        //      crête est à 0,00 pt sur toute sa longueur (il ne penche
        //      pas) ; c'est sa LUMIÈRE qui monte et retombe en arc :
        //      0,39 (x=52 %) / 0,54 (58) / 0,67 (61) / 0,86 (64) /
        //      0,70 (67) / 0,54 (70) / 0,46 (73). Son cœur est si chargé
        //      qu'il vire au blanc chaud (chromie +0,24 au sommet contre
        //      +0,33 sur les flancs) : c'est la saturation qui le blanchit,
        //      pas une couleur blanche.
        //   2. LE RAYON À 41°, qui part de x=75 % sur l'arête et monte
        //      vers la droite : sa trace mesurée passe par 72,8 % à 3 pt,
        //      78 % à 6 pt, 79,2 % à 12 pt, 81,2 % à 15 pt, 83,2 % à
        //      18-22 pt — soit +1,16 pt vers la droite par pt de hauteur.
        //      Large de 22 à 30 pt, il meurt vers 25 pt. C'est LUI le
        //      « fameux trait incliné ».
        //   3. LE HALO, dessous, dans l'air (plus bas).
        //
        // La nappe large ne disparaît pas mais elle RECULE (0,82 → 0,32) :
        // son rôle n'était pas de porter la lumière, seulement de poser le
        // fond sur lequel les deux autres se détachent. Une nappe qui
        // porte tout, c'est le « beaucoup trop gros » de son verdict.
        float dxB = q.x - 0.72 * W;
        float sxB = (dxB < 0.0) ? 40.0 : 24.0;
        float braise = exp(-dxB * dxB / (2.0 * sxB * sxB))
                     * exp(-tB / 6.0)
                     * (1.0 - smoothstep(0.86, 0.99, q.x / W));
        E += (0.32 * braise) * float3(1.0, 0.52, 0.16);

        // LE CHEVEU DU TRAIT VERT (16-08). Après trois tentatives à côté,
        // elle a tranché en DESSINANT un trait vert sur sa capture : « je
        // veux que tu poses un cheveu orange dégradé à la place du trait
        // vert, très très fin ». Mesuré dans son image (pixels verts purs,
        // carte recalée à 1,641 px/pt) : de (74,9 % ; 0,61 pt au-dessus de
        // l'arête) à (79,1 % ; 9,75 pt) — 17,8 pt de long, incliné à 31°.
        // Ce n'était donc NI le cheveu horizontal que j'avais posé sur toute
        // la braise, NI un événement sur l'arête : c'est un court trait
        // OBLIQUE qui monte du bas vers la droite. La leçon : quand trois
        // lectures échouent, demander le trait au lieu de re-mesurer.
        float2 vA = float2(0.749 * W, H - 0.61);
        float2 vB = float2(0.791 * W, H - 9.75);
        float2 vAB = vB - vA;
        float tSeg = clamp(dot(q - vA, vAB) / dot(vAB, vAB), 0.0, 1.0);
        float dSeg = length(q - (vA + tSeg * vAB));
        // TRÈS TRÈS FIN (sa loi) : sigma 0,34 pt, soit 0,8 pt de large à
        // mi-hauteur — le calibre du trait blanc du coin. Et DÉGRADÉ : vif
        // au pied, éteint en haut.
        float cheveuV = exp(-dSeg * dSeg / (2.0 * 0.34 * 0.34))
                      * (1.0 - 0.80 * tSeg * tSeg);
        E += (fin * 1.05 * cheveuV) * float3(1.0, 0.64, 0.28);

        // 1. LE CHEVEU EN ARC — son noyau est celui du trait du coin
        // (σ 0,50), pas celui des tranches : c'est un cheveu, pas un fil.
        float dxArc = q.x - 0.64 * W;
        float arcBas = exp(-dxArc * dxArc / (2.0 * 12.0 * 12.0));
        float gBas = exp(-d * d / (2.0 * 0.50 * 0.50));
        E += (3.50 * arcBas * gBas * wB) * float3(1.0, 0.60, 0.28);

        // 2. LE RAYON À 41°.
        float xr = 0.75 * W + 1.15 * tB;
        float dxr = (q.x - xr) * 0.656;          // distance PERPENDICULAIRE
        float rayon = exp(-dxr * dxr / (2.0 * 7.2 * 7.2))
                    * exp(-tB / 16.0)
                    * smoothstep(0.0, 2.5, tB);
        E += (0.55 * rayon) * float3(1.0, 0.55, 0.22);
        // La nappe douce DANS l'arc du coin haut-gauche (ses crops du
        // 16-08) : un patch court et rond juste derrière le biseau —
        // plus le long lobe diagonal d'avant.
        E += (0.05 * vgLobe(q, float2(4.0, 4.0),
                            normalize(float2(0.80, 0.60)),
                            float2(42.0, 30.0))) * float3(1.0, 0.97, 0.94);
        // La BANDE CRÈME de la tranche basse (zB-coin-bd) : une épaule
        // CHAUDE, étroite (~5 pt), qui n'existe que vers les coins — au
        // centre la tranche basse reste un simple fil.
        float bandeBas = smoothstep(0.3, 1.5, tIn)
                       * exp(-max(tIn - 1.5, 0.0) / 5.5)
                       * pow(wB, 0.6)
                       * (0.50 + 0.85 * exp(-dBR / 90.0)
                               + 0.50 * exp(-dBL / 100.0));
        E += (0.28 * bandeBas) * vgCreme;
        // (L'ÉPAULE DU HAUT est MORTE — Phase 3 : la zone haute de la
        // référence tient à 0,106 de médiane, la bande la poussait à
        // 0,139 ; le haut de la référence n'a que son fil et les
        // événements des coins.)

        // (PHASE 3 — LE NOIR : la voûte, les deux stries et les deux
        // lobes de fumée sont MORTS. La loi du brief : aucune lumière
        // qui ne pointe pas son pixel dans la référence — les stries que
        // je voyais appartenaient au FOND du mock, et la fumée peignait
        // la « grande plaque grise » du verdict. Le corps est NOIR par
        // défaut ; s'il faut une traînée un jour, elle reviendra avec
        // ses coordonnées mesurées, portée par la ControlMap.)

        // ---- 3 + le TRAIT : gaussien sur l'arête (σ 0,75 pt).
        // PHASE 4 : le fil DROIT porte son ENVELOPPE MESURÉE, point par
        // point — mort 0-11 %, ACCIDENT local à 19-21 % (0,62), rampe,
        // PLATEAU 0,86-0,93 de 48 à 84 % (pic 55-60 %), MORT BRUTALE à
        // 89 % : il ne touche jamais le coin bas-droit. Fini la
        // gaussienne unique « trop propre ».
        float gT = exp(-d * d / (2.0 * 0.75 * 0.75));
        // L'ALLUMAGE EN POINTS ABSOLUS (16-08). Il était en fraction de
        // hauteur : au coin de la grande carte (y = rayon = 55 pt), fy vaut
        // 0,115 et le fil était donc ÉTEINT — mesuré 0,07 contre 0,75 sur
        // la mini carte. C'est ça, « le petit trait blanc est quasi
        // effacé ». Conversion exacte à 125 pt : 0,13·125 = 16,3 ·
        // 0,19·125 = 23,8 · 0,195·125 = 24,4 · 0,0009·125² = 14,1.
        // ... et ancré au POINT DE TANGENCE du coin, pas au haut de la
        // carte : le même y absolu ne tombe pas au même endroit de l'arc
        // selon le rayon. Avec l'ancrage au haut, le fil s'allumait à 30°
        // sur la grande carte (y=27,5 pt) alors qu'il y est mort sur la
        // petite (y=13 pt) — d'où le +0,37 mesuré à 30°. `yFil` compte
        // les points SOUS la tangente du coin : identique dans les deux
        // états (16,3 − 26 = −9,7 et 23,8 − 26 = −2,2).
        float yFil = q.y - rH;
        float envR = (0.22 * smoothstep(-9.7, -2.2, yFil)
                      + 0.12 * exp(-(yFil + 1.6) * (yFil + 1.6) / 14.1)
                      + 0.66 * smoothstep(0.33, 0.53, fy))
                   * (1.0 - 0.97 * smoothstep(0.825, 0.870, fy));
        // Le fil GAUCHE s'ORE en descendant (la référence : gris-chaud en
        // haut du flanc, doré franc vers le coin bas) — la teinte suit la
        // position, jamais l'intensité seule (la leçon oIris).
        float3 cFilG = mix(float3(1.0, 0.96, 0.90), float3(1.0, 0.78, 0.52),
                           smoothstep(0.45 * H, H, q.y));
        // PHASE 7 — LA TRANCHE HAUTE, événement par événement (mesurée) :
        // morte aux extrêmes, événement neutre à 7-21 % (pic 0,72 à
        // 18 %), bosse à 30-33 %, ligne calme ~0,47, et LA LUEUR
        // ORANGE : la teinte du fil vire à l'or de 58 à 90 % (chromie
        // R-B au pic 0,26 à 81-84 %) — la « microscopique lueur » du
        // brief, posée à ses coordonnées.
        float fx = q.x / W;
        // Recalé au re-challenge : la rampe d'entrée revient à (3,5-11 %)
        // et la base démarre plus bas sur la section gauche (la traînée
        // du coin porte désormais cette lumière-là) — la courbe cible :
        // 0,21 / 0,37 / 0,36 / 0,41 / 0,47 / 0,58 / 0,76 / 0,61.
        float baseT = mix(0.50, 0.62, smoothstep(0.10, 0.30, fx));
        float envT = (baseT * smoothstep(0.035, 0.11, fx)
                          * (1.0 - smoothstep(0.88, 0.94, fx))
                      + 0.35 * exp(-(fx - 0.185) * (fx - 0.185) / 0.0013)
                      + 0.58 * exp(-(fx - 0.315) * (fx - 0.315) / 0.0020));
        float warmT = smoothstep(0.55, 0.80, fx)
                    * (1.0 - smoothstep(0.86, 0.93, fx));
        envT += 0.34 * warmT;
        float3 cTop = mix(vgBlancChaud, float3(1.0, 0.66, 0.34), warmT);
        // LA TRANCHE BASSE : ligne continue 0,5-0,6 + LE HOTSPOT GOLD à
        // x=31-33 % (0,87-0,94 — le liseré qui touche la tranche sous le
        // point de jauge). ASYMÉTRIQUE, comme la mesure : montée lente
        // depuis 16 %, chute rapide après 36 %.
        // 17-08, son verdict : « la bordure du bas est TROP DORÉE, elle
        // doit être plus foncée — sauf la partie éclairée par le halo ».
        // Mesuré sur son fil (0 pt), de x=20 à 50 % : elle tient
        // 0,25 / 0,29 / 0,36 / 0,30 / 0,24 / 0,26 — je tenais
        // 0,57 / 0,74 / 0,83 / 0,71 / 0,50 / 0,47. Mon hotspot doré de
        // x=32 % faisait plus du DOUBLE du sien (0,83 contre 0,36) : ce
        // n'est pas un hotspot chez elle, c'est une bosse de rien.
        // La seule partie claire de son bas, c'est là où la braise la
        // touche (0,45-0,51 de x=62 à 74 %) — et c'est la braise qui la
        // porte, pas le fil.
        // LE CREUX DU MILIEU (16-08, sa remarque) : « la bordure du bas au
        // milieu est plus foncée ». Mesuré sur son fil : 0,36 à x=32 %,
        // 0,24 à 44 %, 0,26 à 50 %, puis 0,37 à 56 % — un vrai creux entre
        // deux bosses, rapport bosse/creux 1,50. Le mien : 0,38 / 0,30 /
        // 0,30 / 0,36, rapport 1,27 — le creux existe mais il est deux fois
        // moins profond. On le CREUSE sans toucher aux deux bosses, qui
        // sont déjà justes.
        float creuxMil = 1.0 - 0.26 * exp(-(fx - 0.465) * (fx - 0.465)
                                          / 0.0060);
        float dxG = fx - 0.325;
        float envB = 0.42 + 0.30 * exp(-dxG * dxG
                                       / (dxG < 0.0 ? 0.0085 : 0.0045));
        // LES DEUX ACCIDENTS GOLD (mesurés à (74, 96) et (78, 92),
        // chromie 0,33-0,36, quelques pixels, asymétriques — le point 20
        // du brief) : posés à leurs coordonnées, jamais centrés.
        envB *= creuxMil;
        envB += 0.25 * exp(-(fx - 0.74) * (fx - 0.74) / 0.00025)
              + 0.20 * exp(-(fx - 0.785) * (fx - 0.785) / 0.00018);
        float3 cBas = mix(vgSepia, float3(1.0, 0.72, 0.35),
                          smoothstep(0.18, 0.32, fx)
                          * (1.0 - smoothstep(0.36, 0.52, fx)));
        // PHASE 5 — LE FIL GAUCHE, hiérarchie mesurée : le fil est
        // DISCRET (0,295 — c'est la 2e facette, 3 pt dedans, qui brille
        // à 0,655), avec DEUX événements : l'arrivée brutale à y=10 %
        // (0,71) et l'accident de y=43 % (0,59).
        // Fouetté au microscope (16-08) : le fil gauche de la référence
        // est un PLATEAU brillant continu (0,62-0,83 sur toute la
        // hauteur) avec son pic à y≈25 % — mes événements ponctuels
        // laissaient des creux de −0,42 entre eux.
        float envL = 0.90
                   + 0.50 * exp(-(fy - 0.23) * (fy - 0.23) / 0.0035);
        // ===== L'IMPERFECTION DE LA GRANDE CARTE (16-08) =====
        // Sa loi : « ne touche jamais à la mini card, QUE la grande ».
        // `ouvert` vaut EXACTEMENT 0 tant que la carte fait sa taille
        // repliée (125 pt) et ne monte qu'au dépliement : la petite est
        // protégée par CONSTRUCTION, pas par un réglage qu'on pourrait
        // rater. Tout ce qui suit est multiplié par lui.
        // 1. LES VAGUES. Son flanc gauche n'est pas moins accidenté que le
        //    mien : il a une LONGUEUR D'ONDE. Mesuré sur sa photo, sa
        //    crête fait trois inflexions espacées de 15 à 25 pt (0,87 puis
        //    creux 0,67 puis remontée 0,77), quand mes variations à moi
        //    n'ont aucune période — du bruit, pas des vagues. Sur la
        //    grande carte, la même structure à son échelle : deux
        //    extinctions et un rebond entre elles.
        // EN POINTS ABSOLUS, sur SES repères (elle a marqué deux zones au
        // rectangle vert sur la carte dépliée : y 60-156 pt en haut,
        // y 380-474 pt en bas). En fraction de hauteur, mes vagues
        // tombaient ailleurs que là où elle regarde.
        //   · vif      autour de y = 110 pt  (sa marque haute)
        //   · éteint   autour de y = 240 pt
        //   · éteint   autour de y = 425 pt  (sa marque basse)
        // ATTENTION À LA SATURATION : le fil est porté par 1-exp(-E) avec
        // un E déjà grand — moduler l'énergie de ±30 % ne déplace la
        // luminance que de 0,05, ce qui se mesure mais NE SE VOIT PAS
        // (« je vois pas ce que tu as fait le long de la bordure »). Pour
        // qu'une extinction se lise, il faut couper les DEUX TIERS de
        // l'énergie, pas un tiers.
        // Hors fenêtres : un fil FIN et discret, comme la mini carte.
        // Dedans : le trait très lumineux calé sur son carré violet
        // (luminance 0,94 pour 6,8 pt d'épaisseur — brillant ET net).
        float vagueL = mix(1.0, 0.66 + 0.62 * fenL, ouvert);
        envL *= max(vagueL, 0.12);
        // LA TRANCHE FINE (17-08) : le fil droit de la photo est un
        // CHEVEU RAIDE — 0,92 au bord, 0,66 à 0,7 pt, 0,42 à 1,4 pt.
        // Le mien avait un DOS PLAT (0,62 / 0,67 / 0,40) : trop large
        // pour son énergie, donc « sage ». σ 0,75 → 0,55 et l'amplitude
        // remonte : même masse de lumière, mais taillée.
        // ... et son épaisseur VARIE avec la hauteur (mesuré à 1,4 pt :
        // 0,42 à y=50 %, 0,61 à 60 %, 0,76 à 70 %) : cheveu à mi-hauteur,
        // épaule vers le bas. C'est cette variation qui rend la tranche
        // « nerveuse » au lieu de sage — un fil d'épaisseur constante lit
        // comme un trait tracé.
        float sR = mix(0.55, 0.95, smoothstep(0.42, 0.80, fy));
        float gR = exp(-d * d / (2.0 * sR * sR));
        E += (3.60 * wR * envR * gR) * float3(1.0, 0.975, 0.955);
        float3 eRim = (envT * wT) * cTop
                    + (envB * wB) * cBas;
        // Le fil GAUCHE vit À PART : sigma fin (0,6) et PIC DÉCALÉ DE
        // 0,9 pt DEDANS — un pic posé sur d=0 perd la moitié de sa
        // lumière dans la couverture alpha de l'arête (payé : −0,19 sur
        // le pic de y=25 % avec un fil pourtant assez énergique).
        // LE TRAIT LUMINEUX DE LA BORDURE GAUCHE (16-08, sa marque rouge).
        // Elle l'a placé au pixel : de y=19 % à y=40 % de la hauteur,
        // 27 pt de long, posé juste à l'extérieur du bord — « un trait très
        // lumineux blanc qui dépasse légèrement, comme celui de la partie
        // orange ». C'est SA façon de rendre la bordure imparfaite : une
        // seule portion reste lumineuse, le reste s'éteint.
        // ANCRÉ EN POINTS lui aussi : en fraction, ses 27 pt devenaient
        // 96 pt une fois la carte dépliée. (0,170·125 = 21,3 ·
        // 0,212·125 = 26,5 · 0,378·125 = 47,3 · 0,425·125 = 53,1.)
        // EN CLOCHE, PAS EN CRÉNEAU (16-08) : « le petit trait, fais le
        // dégradé, on dirait qu'il est posé comme ça ». Mesuré, il avait
        // les deux défauts qui font « collé » — une entrée BRUTALE (il
        // montait de 0,17 à 0,55 en deux points, la marche la plus raide
        // de toute la bordure) et un DESSUS PLAT (saturé à 1,00 de y=24
        // à 50 pt). Sa référence n'a jamais de palier : son fil descend
        // continûment. Donc un sommet unique à y=32 pt, une montée de
        // 8 pt et une descente plus longue de 12 pt.
        float dyL = q.y - 32.0;
        float sL = (dyL < 0.0) ? 5.0 : 7.5;
        float segL = exp(-dyL * dyL / (2.0 * sL * sL));
        float dcL2 = d + 0.7;
        E += (1.15 * segL * wL
              * exp(-dcL2 * dcL2 / (2.0 * 0.55 * 0.55)))
             * float3(1.0, 0.985, 0.965);
        // ===== GESTE 3 : LA NATURE DU FIL, PAS SEULEMENT SA FORCE =====
        // Son verdict : « des halos pas de la même taille, des cheveux
        // fins et d'autres points fins, des liserés blancs et d'autres
        // moins blancs ». Mesuré, mon fil déplié gardait une épaisseur
        // quasi constante (médiane 5,4 pt, écart-type 2,26, avec 80 pt
        // d'affilée strictement identiques) : je faisais varier
        // l'INTENSITÉ, jamais la FORME. Trois régimes alternent
        // maintenant — cheveu (0,55), épaule (1,6), halo large (3,0) —
        // à des hauteurs choisies, jamais périodiques.
        // 6,8 pt à mi-hauteur = sigma 2,9 ; hors fenêtre, le cheveu de
        // la mini carte (0,50).
        float sFil = mix(0.60, 0.50 + 1.75 * fenL, ouvert);
        float dfg = d + 0.9;
        // Au passage du MINI-COIN gauche, le fil devient un CHEVEU de
        // ~0,4 px (son verdict) : l'amplitude chute à 30 % sous 8 pt du
        // coin — seul le centre antialiasé survit.
        // ... et il s'éteint PLUS TÔT et PLUS BAS en approchant l'angle :
        // à la diagonale du coin (dTL ≈ 11 pt) sa photo est à 0,41 quand je
        // tenais 0,62 — le reste de l'excès venait de ce fil-là, qui
        // gardait encore 40 % de sa force là où il doit avoir presque
        // disparu. (Sans effet sur la bordure plus bas : à mi-hauteur,
        // dTL dépasse 60 pt et le facteur vaut 1.)
        float cheveuTL = mix(0.12, 1.0, smoothstep(0.38 * rH, 1.15 * rH, dTL));
        E += (envL * wL * cheveuTL
              * exp(-dfg * dfg / (2.0 * sFil * sFil))) * cFilG;
        // ===== GESTE 4 : LES POINTS FINS =====
        // Trois accidents ponctuels de 4 à 6 pt, plus brillants que leur
        // entourage, posés là où le fil est en régime CHEVEU — jamais
        // dans les halos, où ils se noieraient.
        float ptsL = exp(-(q.y - 128.0) * (q.y - 128.0) / (2.0 * 2.4 * 2.4))
                   + exp(-(q.y - 298.0) * (q.y - 298.0) / (2.0 * 1.9 * 1.9))
                   + exp(-(q.y - 352.0) * (q.y - 352.0) / (2.0 * 2.2 * 2.2));
        E += (fin * 0.38 * ouvert * fenL * ptsL * wL
              * exp(-dfg * dfg / (2.0 * 0.45 * 0.45))) * float3(1.0, 0.98, 0.95);
        // 2. L'ARC INTÉRIEUR. Dans sa photo, un fuseau vit à 4 pt DEDANS,
        //    jamais sur l'arête : il monte de 0,35 à 0,68 entre y=28 et
        //    50 pt, tient jusqu'à 62, retombe à 0,26 vers 95 — et il se
        //    réchauffe au ventre (chromie +0,12 contre +0,01 en haut).
        //    Doré, donc, pas blanc : c'est ce que dit la mesure.
        float tLg = max(q.x, 0.0);
        float arcL = exp(-(tLg - 5.5) * (tLg - 5.5) / (2.0 * 3.4 * 3.4))
                   * exp(-(q.y - 165.0) * (q.y - 165.0) / (2.0 * 95.0 * 95.0));
        E += (fin * 0.34 * ouvert * fenL * arcL) * float3(1.0, 0.88, 0.72);
        // 3. LE CHEVEU COURT sur l'arête — l'accident bref, le pendant
        //    gauche du petit trait oblique du bas : chez elle la crête
        //    remonte de 0,67 à 0,77 en SIX points quand tout le reste
        //    évolue sur vingt.
        float cheveuLc = exp(-(q.y - 305.0) * (q.y - 305.0)
                             / (2.0 * 13.0 * 13.0))
                       * exp(-dfg * dfg / (2.0 * 0.55 * 0.55));
        E += (fin * 0.55 * ouvert * fenL * cheveuLc * wL) * float3(1.0, 0.975, 0.945);
        // Les coins : haut-droit blanc, bas-droit crème (le plus chaud),
        // bas-gauche orange, haut-gauche discret.
        // PHASE 4 : les coins sont des HOTSPOTS (mesurés : ils meurent
        // en 10-20 pt), plus des queues de 50 pt — c'est la queue du TR
        // qui coulait le long du flanc droit (+0,5 d'énergie à y=23 %).
        // LE FOUET DU COIN DROIT (17-08) : un hotspot isotrope
        // (exp(-dTR/10)) donne un ARRONDI ÉCLAIRÉ — 0,47 tout le long
        // de l'arc, « trop dessiné ». La photo, elle, a une amplitude
        // ANGULAIRE : plateau discret côté flanc, épaule à 40°, PIC À
        // LA DIAGONALE 48-54° (0,88 / 0,81 / 0,78), décrue jusqu'à
        // 0,36 sur la tranche haute. La lumière accroche le coin et se
        // COMPRIME dans la courbe : elle n'est pas répartie, elle est
        // concentrée là où l'arc tourne le plus vite face à la source.
        float2 vTR = float2(q.x - (W - rH), rH - q.y);
        // Le gate s'ouvre TARD côté flanc : à θ<10° c'est le fil du
        // flanc qui porte la lumière, pas le coin (sinon les deux
        // s'additionnent et le bout du coin crame, +0,16 mesuré).
        // ... et le gate suit le RAYON : 6 pt sur un arc de 26 font 13°,
        // mais seulement 6° sur un arc de 55 — le trait se décalait le long
        // de l'arc au lieu de rester à sa place.
        float gateTR = smoothstep(-0.115 * rH, 0.115 * rH, vTR.x)
                     * smoothstep(0.0, 0.23 * rH, vTR.y);
        // LE GARDE (payé cash) : `atan2(0,0)` est indéfini, et partout à
        // gauche/sous le coin les deux max() valaient 0 → NaN. Or
        // **NaN × 0 = NaN** : `gateTR` à zéro ne protège de RIEN, le NaN
        // traverse E, rgbIn et l'alpha — un PANNEAU NOIR rectangulaire
        // sur tout l'intérieur de la carte (bords à x=W-26 pt et y=26 pt,
        // la signature du coin). Invisible aux sondes de flanc, qui ne
        // regardent que les 18 premiers points : c'est zones.py qui l'a
        // attrapé (centre 0,001 au lieu de 0,048).
        float thTR = atan2(max(vTR.y, 1e-4), max(vTR.x, 1e-4));
        // SON VERDICT DU 17-08 : « t'as fait une TACHE, c'est un petit
        // TRAIT DIAGONAL FIN ». Mesuré à la coupe perpendiculaire, tous
        // les 4° : sa lumière de coin est un PIC COURT — 0,53 (36°),
        // 0,73 (44°), **0,88 (48°)**, 0,77 (52°), 0,67 (56°) — un
        // événement de 16° d'arc, soit 7 pt de long. La mienne était un
        // PLATEAU de 20° (0,62 → 0,78 → 0,69) : la même lumière étalée
        // sur le double de surface, et l'œil ne lit plus un trait mais
        // une tache. Un socle constant + un pic serré (σ 4,5°), plus
        // l'épaulement de 40° qui allongeait la tache.
        // RECALÉ À LA RÉSOLUTION NATIVE (17-08) : mon « pic à 0,88 à
        // 48° » était un ARTEFACT — j'avais mesuré sa photo AGRANDIE
        // (490 px étirés à 1086) et le LANCZOS dépasse sur un trait d'un
        // pixel. Sa vraie valeur native à 48° est 0,55, et son maximum
        // n'est pas là : la MASSE lumineuse (seule grandeur qui ne
        // dépend pas de la résolution) vaut 0,40 / 0,45 / 0,61 / 0,79 /
        // 0,73 / 0,64 / 0,52 à 32-40-48-56-64-72-80° — une houle douce
        // qui culmine à 56-64°, pas un paquet sur la diagonale. Je
        // posais ×1,24 de sa lumière sur l'arc, et ×1,94 à 48°.
        float dthS = thTR - 0.977;                 // 56° : son vrai ventre
        float arcTR = 0.46 + 0.50 * exp(-dthS * dthS / 0.075);
        // ... et il est FIN : sa coupe fait 1,1-1,3 pt de large contre
        // 1,5-1,6 chez moi. Le coin prend donc son PROPRE noyau (σ 0,50
        // au lieu du 0,75 des tranches — on ne touche pas à la border,
        // elle est bonne), posé 0,9 pt dans le verre, là où sa crête est
        // mesurée de 44° à 56°.
        float dcTR = d + 0.9;
        float gCoin = exp(-dcTR * dcTR / (2.0 * 0.42 * 0.42));
        E += (arcTR * gateTR * gCoin) * vgBlancChaud;
        // ===== LE COIN DROIT DE LA GRANDE CARTE (16-08) =====
        // Sur un arc de 55 pt, aucun ancrage simple ne reproduit le profil
        // d'un arc de 26 : les termes qui le composent sont ancrés les uns
        // au haut de la carte, les autres à la largeur, les autres à
        // l'arête — et le même angle ne tombe pas au même endroit dans
        // chacun. Plutôt que de tordre cinq lois, on POSE le manque, mesuré
        // angle par angle contre la mini carte (déficit de luminance
        // converti en énergie) : 0,79 à 0° · 0,27 à 10° · 0,15 à 20-30° ·
        // 0,41 à 40° · 0,75 à 60° · 0,32 à 90°. Deux bosses, une à
        // l'entrée du coin et une à 60°, plus un socle.
        float dth0 = thTR;
        float dth60 = thTR - 1.047;
        float manqueTR = 0.15
                       + 0.75 * exp(-dth0 * dth0 / (2.0 * 0.209 * 0.209))
                       + 0.70 * exp(-dth60 * dth60 / (2.0 * 0.314 * 0.314));
        float gTRc = smoothstep(1.6 * rH, 0.6 * rH, dTR);
        E += (ouvert * manqueTR * gTRc * gCoin) * vgBlancChaud;
        eRim += (2.20 * exp(-dBR / 13.0)) * vgCreme
              + (1.65 * exp(-dBL / 20.0)) * float3(1.0, 0.58, 0.26)
              + (0.18 * exp(-dTL / 8.0)) * float3(1.0, 0.97, 0.94);
        E += eRim * gT;

        // ---- 10. LA CONTROLMAP — les accidents de la référence, à
        // leurs positions : nappes laiteuses (R), hotspots (G), touches
        // ambre (B) — dont la chaîne de y=74 % — et la rugosité (A) qui
        // nourrit le grain. Trois fréquences : nappes et taches par la
        // map, grain fin procédural.
        // LA CONTROLMAP ET LE GRAIN NE SURVIVENT PAS À LA COURSE : un
        // échantillonnage de texture et un hash par pixel, pour des
        // accidents que l'œil ne peut pas lire sur une carte qui bouge.
        half4 cm = half4(0.0);
        if (fin > 0.5) {
            constexpr sampler smp(address::clamp_to_edge, filter::linear);
            cm = map.sample(smp, float2(q.x / W, q.y / H));
            E += (0.32 * float(cm.r)) * vgNeutre;
            E += (0.95 * float(cm.g)) * vgBlancChaud;
            E += (0.40 * float(cm.b)) * vgSepia;
        }

        // ---- 8. LE GRAIN DE FILM — par canal, faible, il vit dans la
        // matière (la photo en a partout) ; la rugosité de la map le
        // densifie localement.
        float grain = fin * (vgHash(position * 0.91) - 0.5)
                    * (0.012 + 0.030 * float(cm.a));

        rgbIn = base + (1.0 - exp(-E)) + grain;
    }

    // ================= DEHORS : la lumière dans l'AIR =================
    if (inside < 0.999) {
        float3 Eo = float3(0.0);

        // ---- 7a. Le bloom sépia qui ÉPOUSE le flanc gauche (mesuré :
        // 24 → 99 sur ~5 pt d'air, au ras du trait).
        // FOUETTÉ (16-08, ses crops) : la référence est NOIRE dehors au
        // coin (0,02) — le soupçon sépia n'existe qu'à MI-hauteur, serré
        // sur 2-3 pt. Amplitude ÷3, portée 4→2,5, mort au-dessus de 30 %.
        float profAirL = smoothstep(0.30, 0.50, q.y / H)
                       * (0.40 + 0.60 * exp(-(q.y - 0.55 * H) * (q.y - 0.55 * H)
                                            / (0.35 * H * 0.35 * H)));
        Eo += (0.22 * exp(-tOut / 2.5) * wL * profAirL) * float3(1.0, 0.80, 0.62);
        // ... et LE DÉBORDEMENT du trait de sa marque rouge : il « dépasse
        // légèrement », donc une portée courte (1,6 pt) et blanche, bornée
        // à la même tranche de hauteur que le cœur.
        float dyLA = q.y - 32.0;
        float sLA = (dyLA < 0.0) ? 5.0 : 7.5;
        float segLA = exp(-dyLA * dyLA / (2.0 * sLA * sLA));
        Eo += (0.60 * segLA * wL * exp(-tOut / 1.6))
              * float3(1.0, 0.98, 0.96);
        // Le souffle blanc du flanc droit — PRESQUE RIEN (mesuré sur la
        // référence : l'air à droite reste à 35/255, la lumière flaque
        // DEDANS, jamais dehors).
        Eo += (0.07 * exp(-tOut / 4.0) * wR) * vgBlancChaud;
        // Le fil du haut déborde d'un souffle près des coins.
        Eo += (0.10 * exp(-tOut / 3.0) * wT
               * (exp(-dTR / 80.0) + exp(-dTL / 80.0))) * vgBlancChaud;

        // ---- 7b. Les FLAQUES des coins bas — PHASE 2 : ras, fines,
        // locales (l'air de la référence est NOIR à 0,08-0,15 ; seuls
        // les hotspots des coins débordent, et de quelques points).
        // LE SOUFFLE DE LA BRAISE : sous l'arête, cœur à x=69 %,
        // mesuré dans sa capture 0,18 à 2 pt, 0,11 à 4, 0,07 à 6,
        // 0,05 à 8 — éteint vers 10. Le seuil anti-cellule (2 %
        // d'énergie) et la borne de 16 pt le tiennent : rien ne fuit.
        float dxAir = q.x - 0.64 * W;
        Eo += (0.42 * exp(-tOut / 4.5) * wB
               * exp(-dxAir * dxAir / (2.0 * 30.0 * 30.0)))
              * float3(1.0, 0.52, 0.16);
        Eo += (0.28 * exp(-dBL / 16.0)) * float3(1.0, 0.55, 0.25);
        Eo += (0.35 * exp(-dBR / 16.0)) * vgCreme;

        // (LES TROIS RAYONS SONT MORTS — Phase 2 de la restauration :
        // ils appartenaient au FOND du mock, pas à la carte, et ils
        // peignaient la cellule rectangulaire. Interdits tant qu'on ne
        // peut pas pointer leur pixel dans la référence.)

        air = 1.0 - exp(-Eo);
        // LE SEUIL — la loi anti-cellule : sous ~2 % d'énergie, l'air
        // est RÉELLEMENT transparent (l'alpha résiduel de 1-3/255 sur
        // tout le rectangle du shader, c'était LA boîte visible à ×16).
        float airE = max(air.r, max(air.g, air.b));
        float bloomAlpha = smoothstep(0.020, 0.055, airE);
        // ET LA BORNE SPATIALE : au-delà de ~16 pt de la tranche, plus
        // rien ne vit, hotspots compris.
        bloomAlpha *= smoothstep(16.0, 5.0, tOut);
        air *= bloomAlpha;
        aAir = max(air.r, max(air.g, air.b));
    }

    // ================= LA COMPOSITION, PAR MODE =================
    int m = int(mode + 0.5);
    float3 rgb; float a;
    if (m == 1) {
        // SDF : damier dehors, gris plein dedans, l'arête en blanc —
        // la géométrie nue, pour la superposition au calque.
        float chk = fmod(floor(position.x / 12.0) + floor(position.y / 12.0), 2.0);
        float3 c = mix(float3(0.06 + 0.05 * chk), float3(0.42), inside);
        c = mix(c, float3(1.0), exp(-d * d / 1.2));
        return half4(half3(c), 1.0);
    } else if (m == 2) {
        // INSIDE ONLY : alpha extérieur = 0 DUR.
        rgb = rgbIn * inside;
        a = inside;
    } else if (m == 3) {
        // OUTSIDE ONLY : l'air seul + un cheveu d'arête pour se repérer.
        float cheveu = exp(-d * d / 0.8) * 0.18;
        rgb = air * (1.0 - inside) + cheveu;
        a = clamp((1.0 - inside) * aAir + cheveu, 0.0, 1.0);
    } else if (m == 4) {
        // ×16 : le final multiplié, alpha PLEIN — toute fuite devient
        // un panneau. À ce niveau on ne doit voir que la carte et les
        // halos collés à elle.
        float3 tot = rgbIn * inside + air * (1.0 - inside);
        return half4(half3(clamp(tot * 16.0, 0.0, 1.0)), 1.0);
    } else {
        // FINAL.
        rgb = rgbIn * inside + air * (1.0 - inside);
        a = inside + (1.0 - inside) * aAir;
    }

    // Dither : un demi-niveau, position seule (t est gelé).
    rgb += (vgHash(position * 1.113) - 0.5) * (1.0 / 255.0);
    rgb = clamp(rgb, 0.0, 1.0);
    return half4(half3(min(rgb, float3(a))), half(a));      // prémultiplié
}
