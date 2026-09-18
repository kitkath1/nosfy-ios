#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// ============================================================================
// LE MÉDAILLON DU GALET — le pouce du slider de validation, calqué sur la
// référence de Kathryn (~/Downloads/woop-galet/ref.png) :
//
//   • un dôme d'obsidienne serti dans sa gorge (le logement circulaire) ;
//   • un TUBE néon — pas un trait : épaisseur vivante, chaud EN BAS comme la
//     réf, un point chaud qui ORBITE et dont la vitesse monte avec la course
//     (la phase arrive TOUTE FAITE de Swift : accumulée, monotone, jamais un
//     facteur sur t — la leçon timeBoost de MoonCoin) ;
//   • la COURONNE DE PERLES intérieure — le cadran pointillé de la réf,
//     devenu JAUGE : les perles s'allument une à une avec la poussée ;
//   • le triangle play TRACÉ (contour néon, centre sombre), pas rempli ;
//   • trois étages de bloom, prémultipliés ;
//   • le grenat du refus et le flash du commit en uniforms.
//
// PIÈGES DÉJÀ PAYÉS, RESPECTÉS ICI :
//   — l'arité : la signature ci-dessous doit matcher l'appel Swift AU FLOAT
//     PRÈS, sinon la page devient BLANCHE sans une erreur de compilation ;
//   — le CADRE FANTÔME : toute énergie meurt bien avant le bord du host
//     (fondu à r = 0,86), aucun pixel ne touche jamais le pad.
// ============================================================================

// La chauffe à trois paliers — orange, or, blanc. Un dégradé direct
// orange → blanc passe par un rose sale à mi-course (le vert monte plus
// vite que le bleu) : l'or au milieu tient la teinte. La même loi que le
// Swift d'hier, gravée côté GPU.
static inline float3 gmHeat(float u) {
    u = clamp(u, 0.0, 1.0);
    if (u < 0.55) {
        float k = u / 0.55;
        return mix(float3(1.00, 0.52, 0.12), float3(1.00, 0.80, 0.42), k);
    }
    float k = (u - 0.55) / 0.45;
    return mix(float3(1.00, 0.80, 0.42), float3(1.0, 1.0, 1.0), k);
}

static inline float gmWrap(float a) {
    // Ramène un angle dans [-π, π] — la distance angulaire du point chaud.
    return a - 6.2831853 * floor((a + 3.14159265) / 6.2831853);
}

[[ stitchable ]] half4 galetMedaillon(float2 pos, half4 color,
                                      float2 size,
                                      float t,
                                      float rot,
                                      float p,
                                      float grip,
                                      float refuse,
                                      float flash) {
    // Le repère : centre du host, normalisé par sa demi-taille.
    float2 uv = (pos - size * 0.5) / (size.y * 0.5);
    float r = length(uv);
    float ang = atan2(uv.y, uv.x);          // +y vers le BAS : bas = +π/2

    // Tout meurt avant le bord du host — le cadre fantôme n'existera pas.
    float edge = smoothstep(0.98, 0.86, r);
    if (edge <= 0.0) { return half4(0.0); }

    float3 acc = float3(0.0);
    float  alp = 0.0;

    // LE SOUFFLE DU REPOS (verdict Kathryn : « anime davantage son halo au
    // repos, pareil pour la border ») : une respiration lente qui
    // n'appartient qu'à l'ATTENTE — elle s'efface dès que la main arrive,
    // le geste a sa propre vie.
    float souffle = 0.5 + 0.5 * sin(t * 1.55);
    float calm = 1.0 - 0.8 * clamp(grip + p * 2.0, 0.0, 1.0);

    // ------------------------------------------------------------ le dôme
    // L'obsidienne : un disque sombre, à peine plus clair au zénith, avec
    // une sheen très douce en haut-gauche — un verre poli, pas un aplat.
    // Il s'étend JUSQUE SOUS le tube : le moindre anneau translucide entre
    // les deux laissait la piste transparaître À TRAVERS le médaillon
    // (mesuré au round 2 — le bord de la capsule se lisait dans le verre).
    float domeIn = smoothstep(0.668, 0.63, r);
    if (domeIn > 0.0) {
        float3 base = mix(float3(0.052, 0.048, 0.052),
                          float3(0.010, 0.009, 0.012),
                          smoothstep(0.0, 0.60, r));
        float sheen = exp(-dot(uv - float2(-0.26, -0.30),
                               uv - float2(-0.26, -0.30)) / 0.16) * 0.055;
        // LE VOILE SPÉCULAIRE (verdict jury, remonté au round 4) : la moitié
        // haute du dôme prend un vrai voile de verre, qui meurt avant
        // l'équateur — c'est lui qui dit « bombé » et non « disque mat ».
        sheen += smoothstep(0.05, -0.60, uv.y) * 0.075;
        // La braise du tube se reflète dans le bas du verre.
        float glow = exp(-dot(uv - float2(0.0, 0.34),
                              uv - float2(0.0, 0.34)) / 0.30)
                     * (0.030 + 0.10 * p + 0.05 * grip);
        float3 c = base + sheen + gmHeat(p) * glow;
        acc += c * domeIn;
        alp = max(alp, domeIn);
    }

    // ------------------------------------------------- la gorge du serti
    // L'anneau sombre entre le dôme et le monde : le médaillon est SERTI,
    // pas posé. Un fil de lumière très fin court sur son épaule haute.
    float gorge = exp(-pow((r - 0.720) / 0.050, 2.0)) * 0.90;
    acc += float3(0.010, 0.009, 0.011) * gorge;
    alp = max(alp, gorge);
    // L'ÉPAULE DE VERRE (verdict jury) : un arc fin HORS du néon, haut-
    // gauche, blanc chaud — et son écho bas-gauche plus faible. C'est ce qui
    // fait « serti dans le rail » au lieu de « posé dessus ».
    {
        float dArc = gmWrap(ang - (-2.30));
        float arcTL = exp(-dArc * dArc / 0.55);
        float dEcho = gmWrap(ang - 2.55);
        float echoBL = exp(-dEcho * dEcho / 0.40) * 0.40;
        float arc = exp(-pow((r - 0.736) / 0.009, 2.0))
                    * (arcTL + echoBL) * 0.50;
        acc += float3(0.90, 0.86, 0.80) * arc;
        alp = max(alp, arc);
    }
    float shoulderBias = 0.5 - 0.5 * sin(ang + 0.65);
    shoulderBias *= shoulderBias;
    float hair = exp(-pow((r - 0.792) / 0.009, 2.0))
                 * (0.02 + 0.10 * shoulderBias);
    acc += float3(0.82, 0.79, 0.75) * hair;
    alp = max(alp, hair);

    // ------------------------------------------------------------ le tube
    // La matière de la réf : chaud EN BAS, presque éteint en haut, un point
    // chaud qui tourne (rot, accumulé côté Swift, accélère avec la course),
    // l'épaisseur qui respire avec lui.
    // LA TEMPÉRATURE EST VERROUILLÉE (verdict jury) : la matière du tube ne
    // change presque pas en glissant — c'est l'intensité et la rotation qui
    // disent la course, jamais un néon qui vire jaune-crème.
    float3 neon = gmHeat(p * 0.45);
    neon = mix(neon, float3(0.62, 0.13, 0.16), refuse);   // le grenat sourd
    {
        // Le maximum vit à ~7 h (bas légèrement GAUCHE, verdict jury) —
        // pas à 6 h pile : la réf n'est jamais symétrique.
        float warmth = 0.5 + 0.5 * sin(ang - 0.40);
        float dHot = gmWrap(ang - rot);
        float hot = exp(-dHot * dHot / 0.42);
        float dHot2 = gmWrap(ang - rot - 3.14159265);
        float hot2 = exp(-dHot2 * dHot2 / 0.85) * 0.30;   // l'écho opposé
        // Au repos la respiration est FRANCHE (l'invite) ; en course elle
        // s'efface derrière l'intensité du geste.
        float breathe = 0.92 + (0.08 + 0.20 * calm) * sin(t * 1.7);
        // LE GRADIENT SURVIT À LA COURSE (verdict jury) : le haut reste un
        // ambre PROFOND presque éteint, quel que soit p — c'est le contraste
        // bas/haut qui fait la matière, pas la puissance globale.
        // Le plancher tient le tube VISIBLE sur tout le tour (la réf garde
        // un fil ambre jusqu'au zénith) — mais il DESCEND avec la course :
        // à mi-course le haut doit être « presque éteint » (ratio ~0,12).
        float I = (0.17 - 0.07 * p + 0.55 * warmth)
                  * (0.40 + 0.30 * grip + 0.26 * p) * breathe
                + (hot + hot2) * (0.50 + 0.70 * p + 0.32 * grip) * (0.35 + 0.65 * warmth);
        I *= (1.0 - 0.35 * refuse);
        I += flash * 1.6;

        // La teinte suit la température locale : ambre profond en haut,
        // le néon plein en bas — jamais un anneau uniforme.
        float3 deepAmber = float3(0.54, 0.29, 0.13);
        float3 nc = mix(deepAmber, neon, 0.22 + 0.78 * warmth);
        nc = mix(nc, float3(0.62, 0.13, 0.16), refuse);

        // LARGEUR CONSTANTE (verdict jury) : c'est l'intensité qui meurt en
        // haut, jamais la largeur. Et le cœur est DOUX — un falloff qui
        // fond dans le halo, pas un trait graphique à bord net.
        float w = 0.019;
        float dr = r - 0.652;
        float core = exp(-dr * dr / (w * w));
        float mid  = exp(-dr * dr / 0.0032);
        // Le halo déborde vers l'EXTÉRIEUR-BAS — décalé hors du tube, plus
        // doré que le cœur, et PLAFONNÉ : la nappe surexposée du bas à
        // mi-course était une faute mesurée.
        // La queue du halo est LONGUE (verdict jury : la réf respire jusqu'à
        // ~0,3 diamètre) — le pic reste plafonné, seul le rayon s'étire.
        float drW = r - 0.652 - 0.035 - 0.03 * warmth;
        float wide = exp(-drW * drW / 0.052);
        float Ih = min(I, 1.35);
        float3 goldHalo = mix(float3(1.0, 0.72, 0.34), nc, 0.35);
        float3 c = nc * (core * 1.05 + mid * 0.34) * I
                 + goldHalo * wide * 0.10 * Ih;
        // LE DÉBORD INTÉRIEUR (verdict jury) : le bas du tube LAVE
        // l'intérieur du dôme — un voile orange qui remonte sous les perles,
        // au lieu d'un verre trop propre.
        float inner = exp(-max(0.652 - r, 0.0) / 0.10)
                      * (1.0 - step(0.652, r)) * warmth;
        c += nc * inner * (0.13 + 0.08 * p) * (0.6 + 0.4 * grip);
        // Le cœur blanchit à peine — le blanc appartient au flash.
        c += float3(1.0, 0.96, 0.86) * core * min(I, 1.2)
             * (0.08 + 0.08 * p + 0.6 * flash)
             * (1.0 - refuse) * (0.4 + 0.6 * warmth);
        acc += c;
        alp = max(alp, min((core + mid * 0.4 + wide * 0.12) * I, 1.0));
    }

    // ------------------------------------------------ l'aura qui respire
    // Un halo large AU-DELÀ du tube, qui enfle et retombe avec le souffle —
    // la vie du bouton quand personne n'y touche. Il garde le biais bas de
    // la matière (chaud à 7 h, éteint au zénith) et s'efface en course.
    {
        float warmth = 0.5 + 0.5 * sin(ang - 0.40);
        float drA = max(r - 0.68, 0.0);
        float aura = exp(-drA * drA / 0.018)
                     * (0.030 + 0.065 * souffle) * (calm * 0.85 + 0.15)
                     * (0.45 + 0.55 * warmth) * (1.0 - refuse);
        acc += float3(1.0, 0.72, 0.34) * aura;
        alp = max(alp, aura);
    }

    // -------------------------------------------------- la couronne-jauge
    // Les perles de la réf, devenues le COMPTE de la poussée : elles
    // s'allument une à une depuis le bas, dans les deux sens, et la
    // dernière allumée « pop ». Au repos, seules celles du bas veillent.
    if (fabs(r - 0.470) < 0.10) {
        const int N = 24;
        for (int k = 0; k < N; k++) {
            // k = 0 en bas, puis on remonte en alternant droite/gauche —
            // la jauge grandit symétriquement, comme une couronne qu'on
            // allume par le bas.
            float half_ = float((k + 1) / 2);
            float side = (k % 2 == 0) ? 1.0 : -1.0;
            float phi = 1.5707963 + side * half_ * (6.2831853 / float(N));
            float2 pk = float2(cos(phi), sin(phi)) * 0.470;
            float d2 = dot(uv - pk, uv - pk);
            // Des POINTS fins, pas des billes (verdict jury) : cœur serré,
            // halo court, et la taille NE BOUGE JAMAIS avec la course —
            // seule la GRADATION du bas vers le haut la module (2 % du
            // diamètre en bas, 1 % en haut).
            float warmthK = 0.5 + 0.5 * sin(phi);
            float sz = 0.00018 + 0.00016 * warmthK;
            float dot_ = exp(-d2 / sz);
            float halo_ = exp(-d2 / (sz * 4.5));

            float pk01 = (float(k) + 0.5) / float(N);
            float lit = smoothstep(pk01 - 0.045, pk01, p);
            float pop = exp(-max(p - pk01, 0.0) * 16.0);
            float warmth = warmthK;
            // GRADATION CONTINUE (verdict jury) : plein feu en bas, ~15 %
            // en haut — jamais une coupure nette. Le plancher garde les
            // perles hautes PRÉSENTES, à peine.
            float grade = 0.15 + 0.85 * warmth * warmth;
            // Amplitude de veille resserrée : aucune perle ne doit dominer
            // ses voisines de plus de ~1,3x (verdict jury).
            float idle = warmth * warmth
                         * (0.15 + (0.05 + 0.10 * calm)
                            * sin(t * 1.3 + float(k) * 1.7))
                         * (0.5 + 0.5 * grip)
                       + 0.038 + 0.022 * souffle * calm;
            float I = max(lit * (0.80 + 0.85 * pop) * grade, idle);
            I *= (1.0 - refuse);
            // Or-orange, jamais blanc-crème : la perle est du néon, pas une
            // LED.
            float3 c = gmHeat(min(p * 0.5 + 0.18, 0.72));
            acc += (c * (dot_ * 1.05 + halo_ * 0.10)
                    + float3(1.0, 0.92, 0.78) * dot_ * 0.12 * lit) * I;
            alp = max(alp, min((dot_ + halo_ * 0.2) * I, 1.0));
        }
    }

    // ------------------------------------------------- le triangle tracé
    // Le play de la réf est une ENSEIGNE : un contour d'or néon aux coins
    // doux, centre sombre — jamais un pictogramme plein.
    {
        // ~30 % de la largeur du médaillon, trait franc — le jury a rendu
        // deux verdicts contraires (plus petit / plus grand) : la mesure du
        // crop de la réf tranche à ~0,30 de large pour 0,38 de haut.
        float2 q = uv - float2(0.036, 0.0);
        float2 A = float2(-0.125, -0.185);
        float2 B = float2( 0.175,  0.0);
        float2 C = float2(-0.125,  0.185);
        // Distance au périmètre : le min des trois segments.
        float sd = 1e3;
        float2 e0 = B - A, e1 = C - B, e2 = A - C;
        float2 v0 = q - A, v1 = q - B, v2 = q - C;
        float2 d0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
        float2 d1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
        float2 d2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
        sd = sqrt(min(min(dot(d0, d0), dot(d1, d1)), dot(d2, d2)));

        float core = exp(-sd * sd / (0.014 * 0.014));
        float glow = exp(-sd * sd / 0.0022);
        float I = 0.80 + 0.20 * grip + 0.35 * flash
                + 0.10 * souffle * calm;
        I *= (1.0 - 0.4 * refuse);
        // #EDB66E — l'ambre-or de la réf (le crème était trop pâle), et un
        // halo SERRÉ de la même teinte : une enseigne, pas un pictogramme.
        float3 gold = mix(float3(0.93, 0.71, 0.43),
                          float3(0.62, 0.13, 0.16), refuse);
        acc += (gold * (core * 1.28 + glow * 0.30)
                + float3(1.0, 0.95, 0.82) * core * 0.02) * I;
        alp = max(alp, min(core * I, 1.0));
    }

    acc *= edge;
    alp = clamp(alp, 0.0, 1.0) * edge;
    // Prémultiplié : la lumière est DANS acc, l'alpha ne fait que porter.
    return half4(half3(acc), half(alp));
}
