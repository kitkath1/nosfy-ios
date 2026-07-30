#include <metal_stdlib>
using namespace metal;

// MARK: - La carte « swap » de la home aurora (banc `-homeLab`)
//
// Le noir MAT — pas l'obsidienne polie du bouton : une matière poudrée qui
// n'attrape presque rien — traversé par un reflet chaud qui dérive lentement,
// orange au bord d'attaque, jaune d'or au cœur, et serti d'une hairline aux
// accents dorés. La retenue d'abord : le noir domine, la couleur ne vit que
// dans le reflet et sur l'arête. Chaque carte reçoit une `seed` : quatre
// cartes du carrousel, quatre phases — jamais deux reflets synchrones.
//
// Leçon du bouton ([[diamondButton]]) : la lumière HORS de la carte est
// émissive (couleur = couverture) — sur le ciel réchauffé, un voile pondéré
// lirait comme une ombre sale.

static float schash21(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

static float4 schash42(float2 p) {
    float4 p4 = fract(float4(p.xyxy) * float4(0.1031, 0.1030, 0.0973, 0.1099));
    p4 += dot(p4, p4.wzxy + 33.33);
    return fract((p4.xxyz + p4.yzzw) * p4.zywx);
}

static float scnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    float a = schash21(i);
    float b = schash21(i + float2(1.0, 0.0));
    float c = schash21(i + float2(0.0, 1.0));
    float d = schash21(i + float2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

static float scfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) {
        v += a * scnoise(p);
        p = p * 2.03 + float2(17.1, 9.3);
        a *= 0.5;
    }
    return v;
}

static float scRound(float2 p, float2 b, float r) {
    float2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

/// Les accents de la hairline : mêmes lois que la famille diamant (bruit
/// paramétré par la position sur le bord, seuil dur — n'en survivent que
/// quelques-uns, surtout en haut), décalés par la seed de la carte.
static float scRim(float2 p, float2 halfB, float t, float seed) {
    float2 off = float2(seed * 37.0, seed * 21.0);
    float seg = scfbm(p * float2(0.015, 0.055) + off + float2(t * 0.11, -t * 0.08));
    float fine = scnoise(p * float2(0.034, 0.11) + off - float2(t * 0.22, -t * 0.16));
    float accents = seg * 0.74 + fine * 0.26;
    accents = pow(clamp(accents, 0.0, 1.0), 4.0);
    float topness = clamp(-p.y / max(halfB.y, 1.0), 0.0, 1.0);
    float bias = 0.34 + 0.46 * topness * topness;
    float ang = atan2(p.y, p.x);
    float breath = 0.80 + 0.20 * sin(t * 0.9 + ang * 2.0 + seed * 6.0);
    return clamp(4.4 * accents * bias * breath, 0.0, 1.0);
}

// `charge` : la montée du geste (0 au repos → 1 quand le doigt a décidé).
// Tout l'écrin s'embrase : la hairline s'épaissit et vire à l'or, le halo
// déborde loin, les facettes s'éveillent — les bords FONDENT en lumière.
[[ stitchable ]] half4 swapCard(float2 position, half4 color,
                                float2 size, float t,
                                float pad, float radius, float seed,
                                float charge) {
    float2 center = size * 0.5;
    float2 p = position - center;
    float2 halfB = max(center - pad, float2(1.0));
    float r = min(radius, min(halfB.x, halfB.y));
    float d = scRound(p, halfB, r);
    float inside = smoothstep(0.6, -1.2, d);

    // ---- Le noir MAT, presque absolu : une poudre statique très fine qui
    // ne se voit que là où la lumière passe. Aucun dégradé franc — la carte
    // est un vide, pas une plaque (verdict « minimal, aéré »).
    float powder = scnoise(p * 0.9 + seed * 13.0) * 0.55
                 + scnoise(p * 2.7 + seed * 7.0) * 0.45;
    float uvY = clamp((p.y + halfB.y) / (2.0 * halfB.y), 0.0, 1.0);
    float matte = mix(0.019, 0.008, uvY) * (1.0 + 0.30 * (powder - 0.5));

    // ---- La lumière : un souffle qui descend du bord haut (le velours
    // qu'on devine), et un reflet très lent qui traverse en ~34 s — blanc
    // à peine tiédi d'or, jamais une couleur posée sur la carte.
    float band = (p.x + p.y * 0.55) / max(halfB.x, 1.0);
    float cpos = fract(t / 34.0 + seed * 0.37) * 3.4 - 1.7;
    float sheen = exp(-(band - cpos) * (band - cpos) / (0.62 * 0.62));
    float3 light = float3(1.00, 0.94, 0.86)
                   * (sheen * (0.008 + 0.022 * powder));
    light += float3(1.00, 0.97, 0.93)
             * (exp(-uvY * 6.5) * 0.016 * (0.6 + 0.4 * powder));

    // ---- La hairline : blanche en haut comme toute la famille diamant,
    // réchauffée d'or seulement en descendant — l'arête est la SEULE
    // couleur de la carte, et elle murmure. Sous le geste, elle prend feu :
    // la teinte glisse vers l'or franc, le trait s'épaissit.
    float rim = scRim(p, halfB, t, seed);
    float3 rimCol = mix(float3(1.00, 0.98, 0.94),
                        float3(1.00, 0.78, 0.44), uvY * 0.85);
    rimCol = mix(rimCol, float3(1.00, 0.74, 0.30), charge * 0.70);
    float lw = 0.42 + 0.30 * charge;
    float line = exp(-d * d / (lw * lw))
                 * (0.09 + 0.62 * rim) * (1.0 + 1.0 * charge);

    // Le halo de repos : une buée collée au trait, à peine là.
    float halo = exp(-max(d, 0.0) / 5.0)
                 * smoothstep(-0.8, 0.8, d) * 0.10 * rim;

    // ---- LE GLOW DU GESTE : un DÉGRADÉ, pas de la fumée. Toute sa forme
    // est lisse — aucune modulation par le bruit du liseré, c'est ce qui
    // donnait l'aspect enfumé. Un foyer chaud parcourt lentement le
    // pourtour (un tour en ~8 s, décalé par carte), la lumière s'y masse et
    // se dégrade vers l'or profond en s'éloignant.
    float2 nrm = length(p) > 0.5 ? normalize(p) : float2(0.0, -1.0);
    float ga = t * 0.78 + seed * 2.1;
    float2 gdir = float2(cos(ga), sin(ga));
    // Un second foyer, opposé et plus faible : la lumière n'a jamais un
    // seul côté mort, elle respire tout autour.
    float lobe = pow(max(dot(nrm, gdir), 0.0), 3.0)
                 + 0.30 * pow(max(-dot(nrm, gdir), 0.0), 3.4);
    float w = 0.13 + 0.87 * lobe;

    // Dehors : à peine une buée serrée contre l'arête. Le halo derrière la
    // carte reste un murmure — c'est la retenue qui fait le premium.
    float outside = max(d, 0.0);
    float reach = 9.0 + 13.0 * charge;
    float glow = exp(-outside / reach) * smoothstep(-1.2, 1.2, d)
                 * w * charge * 0.20;
    float grad = clamp(outside / (reach * 1.6), 0.0, 1.0);
    float3 glowCol = mix(float3(1.00, 0.96, 0.89),
                         float3(1.00, 0.74, 0.32), grad);

    // ---- ET C'EST DEDANS QUE LA LUMIÈRE VIT : une nappe qui entre par
    // l'arête du côté du foyer et se dégrade vers le cœur de la carte —
    // blanche contre le bord, dorée en s'enfonçant, éteinte bien avant le
    // centre. Le noir mat reste le sujet ; la lumière le caresse.
    float inward = max(-d, 0.0);
    float pool = exp(-inward / 30.0) * 0.82 + exp(-inward / 72.0) * 0.18;
    float innerGlow = pool * w * charge * 0.30 * inside;
    float3 innerCol = mix(float3(1.00, 0.98, 0.94),
                          float3(1.00, 0.82, 0.44),
                          clamp(inward / 95.0, 0.0, 1.0));

    // LE FONDU D'HÔTE : toute la lumière meurt AVANT le bord du rectangle
    // du shader. Sans lui, le halo bute sur le bord et la carte se met à
    // porter une plaque d'or rectangulaire — le débord doit se dissoudre
    // dans le noir, jamais se faire couper.
    float fade = 1.0 - smoothstep(pad * 0.42, pad * 0.96, d);
    glow *= fade;

    // ---- Les pointes-bijou : minuscules et rares au repos, elles
    // s'éveillent en nombre quand le geste monte.
    float glitter = 0.0;
    if (fabs(d) < 4.0 + 10.0 * charge) {
        float cell = 13.0 - 4.0 * charge;
        float2 idg = floor(p / cell);
        float4 hg = schash42(idg * 3.07 + float2(7.3 + seed * 5.0, 2.9));
        if (hg.x < 0.16 + 0.34 * charge) {
            float2 cg = (idg + 0.5 + (hg.yz - 0.5) * 0.6) * cell;
            float dg = scRound(cg, halfB, r);
            float on = exp(-fabs(dg) / (3.0 + 5.0 * charge));
            float twk = max(0.0, sin(t * (0.4 + 0.5 * hg.w) + hg.z * 6.283));
            twk = pow(twk, 16.0 - 11.0 * charge);
            float2 dpg = p - cg;
            float core = exp(-dot(dpg, dpg) / (0.7 * 0.7));
            // Sous le geste, les facettes ouvrent leurs rayons en croix —
            // la grammaire bijou de la maison.
            float rayL = 1.0 + 9.0 * charge * twk;
            float rH = exp(-dpg.y * dpg.y / (0.40 * 0.40)
                           - dpg.x * dpg.x / (rayL * rayL));
            float rV = exp(-dpg.x * dpg.x / (0.40 * 0.40)
                           - dpg.y * dpg.y / (rayL * rayL));
            glitter = (core + (rH + rV) * 0.5 * charge) * on * twk
                      * (0.6 + 0.8 * charge)
                      * (1.0 - smoothstep(pad * 0.45, pad * 0.94, d));
        }
    }

    // ---- Composition. Dedans : le noir mat, sa lumière, et le dégradé qui
    // entre par l'arête du côté du foyer (l'obsidienne reste noire au
    // centre). Dehors : de la lumière émissive pure (couleur = couverture) —
    // jamais un voile, la carte ne doit pas salir l'aurore derrière elle.
    float3 inCol = float3(matte) + light
                   + rimCol * (line * inside * 0.9)
                   + innerCol * innerGlow;
    float aRim = clamp((line + halo + glitter) * 1.6, 0.0, 1.0);
    float aGlow = clamp(glow, 0.0, 1.0);
    float aOut = clamp(aRim + aGlow * (1.0 - aRim), 0.0, 1.0);
    float3 outCol = rimCol * aRim + glowCol * (aGlow * (1.0 - aRim));
    float a = mix(aOut, 1.0, inside);
    float3 c = mix(outCol, inCol, inside);
    // Dither : toute la matière vit sous 4 % de blanc.
    c += (schash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0))
          - 0.5) * (2.0 / 255.0) * a;
    c = clamp(min(c, float3(a)), 0.0, 1.0);
    return half4(half3(c), half(a));            // prémultiplié
}

// MARK: - La gerbe du swipe
//
// À l'instant où la carte s'arrache, des CENTAINES de bijoux jaillissent de
// son contour : la poussière fine et les éclats à rayons en croix de la
// famille diamant, blancs au cœur, dorés en s'éloignant. Ils partent
// RADIALEMENT — c'est ce qui rend la gerbe calculable : un fragment connaît
// son angle, donc le secteur d'où vient la particule qui pourrait le
// toucher, et il n'en teste qu'une poignée. Le sens du swipe ne dévie pas
// les trajectoires (ça casserait l'inversion) : il ACCÉLÈRE le côté vers
// lequel la carte est partie, et la gerbe se couche naturellement.
//
// Hébergée par la PILE, pas par la carte : la carte, elle, a déjà disparu.

/// Le rayon du contour de la carte dans une direction donnée (boîte
/// arrondie approchée — dans un nuage de particules, les coins ne se
/// racontent pas).
static float sbBoxRadius(float2 dir, float2 halfB, float rad) {
    float tx = halfB.x / max(fabs(dir.x), 1e-3);
    float ty = halfB.y / max(fabs(dir.y), 1e-3);
    return min(tx, ty) - rad * 0.30;
}

[[ stitchable ]] half4 swapBurst(float2 position, half4 color,
                                 float2 size, float t,
                                 float2 emit, float2 halfB, float radius,
                                 float2 way, float age) {
    if (age < 0.0 || age > 1.30) { return half4(0.0); }

    float2 p = position - emit;
    float r = length(p);
    // Rejets grossiers : rien dans la carte, rien au-delà de la portée du
    // moment. C'est ce qui rend la gerbe abordable en plein écran.
    float inner = min(halfB.x, halfB.y) * 0.45;
    float outer = max(halfB.x, halfB.y) + 620.0 * age + 40.0;
    if (r < inner || r > outer) { return half4(0.0); }

    const float SECTORS = 180.0;
    float ang = atan2(p.y, p.x);
    float sIdx = floor((ang + 3.14159265) / 6.2831853 * SECTORS);

    float3 c = float3(0.0);
    float a = 0.0;

    // Cinq secteurs (le nôtre et ses voisins : un éclat déborde sur les
    // côtés), trois particules par secteur — 540 bijoux dans la gerbe.
    for (int k = -2; k <= 2; k++) {
        float s = sIdx + float(k);
        s = s - SECTORS * floor(s / SECTORS);
        for (int j = 0; j < 3; j++) {
            float4 h = schash42(float2(s * 1.37 + 3.1, 7.9 + 5.3 * float(j)));
            // Naissances échelonnées : la gerbe s'ouvre, elle ne claque pas.
            float u = age - h.x * 0.13;
            if (u <= 0.0) { continue; }
            float span = 0.52 + 0.60 * h.y;
            float life = u / span;
            if (life >= 1.0) { continue; }

            float th = (s + 0.5 + (h.z - 0.5) * 0.85) / SECTORS * 6.2831853
                       - 3.14159265;
            float2 dir = float2(cos(th), sin(th));
            // Le côté vers lequel la carte est partie reçoit l'élan.
            float push = 1.0 + 0.85 * max(dot(dir, way), 0.0);
            float speed = (120.0 + 300.0 * h.w) * push;
            // Décélération douce : les bijoux s'ouvrent puis se posent.
            float travel = speed * u * (1.0 - 0.42 * life);
            float rr = sbBoxRadius(dir, halfB, radius) + travel;
            float2 dp = p - dir * rr;
            float q = dot(dp, dp);
            if (q > 900.0) { continue; }

            float env = sin(3.14159265 * life);
            float twk = 0.62 + 0.38 * sin(t * (3.1 + 5.0 * h.z) + h.y * 6.283);
            float amp = env * env * twk;
            if (amp < 0.004) { continue; }

            // Un quart d'éclats-ÉTOILES (cœur + rayons en croix), le reste
            // en poussière fine : la hiérarchie de la famille diamant.
            float jewel = step(0.74, h.x);
            float core = exp(-q / (0.62 * 0.62 + jewel * 0.25));
            float lum = core;
            if (jewel > 0.5) {
                float rayL = 2.0 + 7.5 * env;
                lum += (exp(-dp.y * dp.y / (0.42 * 0.42)
                            - dp.x * dp.x / (rayL * rayL))
                        + exp(-dp.x * dp.x / (0.42 * 0.42)
                              - dp.y * dp.y / (rayL * rayL))) * 0.50;
            }
            // Blanches au départ, dorées en mourant : elles refroidissent
            // vers l'or de la page, jamais vers le gris.
            float3 tint = mix(float3(1.00, 0.99, 0.95),
                              float3(1.00, 0.76, 0.38),
                              clamp(life * 1.2, 0.0, 1.0) * (0.35 + 0.65 * h.y));
            float g = lum * amp;
            c += tint * g;
            a += g;
        }
    }

    // Le fondu d'hôte, ici aussi : les derniers bijoux se dissolvent avant
    // le bord du rectangle, sinon la gerbe se fait trancher au carré.
    float2 toEdge = min(position, size - position);
    float hostFade = smoothstep(0.0, 70.0, min(toEdge.x, toEdge.y));

    a = clamp(a * 1.5, 0.0, 1.0) * hostFade;
    c = clamp(c, 0.0, 1.0) * a;      // émissif, prémultiplié
    return half4(half3(c), half(a)) * color.a;
}

// MARK: - L'aurore de la home
//
// La petite sœur du fond de la connexion : les mêmes tons de la photo (noir
// neutre, gris cendré, orange brûlé, doré, cœur crème) mais bien PLUS
// discrète — elle ne monte qu'au bas de la page, sous le contenu, et vit
// surtout par ses rideaux qui glissent vers le bas et ses halos qui
// descendent. Pas de croix, pas d'étoiles-bijou : ici la page a déjà ses
// cartes, le fond ne doit que respirer.

static float auroraBlob(float2 q, float2 ctr, float2 sig) {
    float2 dd = (q - ctr) / max(sig, float2(1e-3));
    return exp(-dot(dd, dd));
}

[[ stitchable ]] half4 homeAurora(float2 position, half4 color,
                                  float2 size, float t) {
    float2 q = position / max(size.y, 1.0);
    float aspect = size.x / max(size.y, 1.0);

    const float3 blanc   = float3(1.00, 0.98, 0.93);
    const float3 dore    = float3(1.00, 0.72, 0.26);
    const float3 ambre   = float3(1.00, 0.42, 0.08);
    const float3 lunaire = float3(0.80, 0.79, 0.81);

    float b1 = 0.90 + 0.10 * sin(t * 6.2832 / 41.0);
    float b2 = 0.88 + 0.12 * sin(t * 6.2832 / 29.0 + 2.1);

    // Le cœur, très bas et à gauche : il ne fait qu'affleurer le bord.
    float3 mass = blanc * (0.62 * b1 * auroraBlob(q,
        float2(aspect * (0.38 + 0.02 * sin(t / 43.0)), 1.14),
        float2(0.26, 0.16)));
    // La nappe dorée qui la couronne.
    mass += dore * (0.30 * b2 * auroraBlob(q,
        float2(aspect * (0.62 + 0.03 * sin(t / 31.0 + 1.0)), 1.06),
        float2(0.36, 0.14)));
    // Les braises des deux flancs, basses.
    mass += ambre * (0.34 * b2 * auroraBlob(q,
        float2(aspect * 0.03, 0.99), float2(0.20, 0.13)));
    mass += ambre * (0.26 * b1 * auroraBlob(q,
        float2(aspect * 1.00, 0.94), float2(0.17, 0.14)));
    // Le gris cendré qui sépare la nuit de la braise — c'est lui qui
    // empêche le fondu de virer au marron.
    mass += lunaire * (0.13 * b1 * auroraBlob(q,
        float2(aspect * 0.50, 0.86), float2(0.46, 0.09)));

    // Trois voix qui descendent, chacune à son tempo — la vie du fond.
    const float3 vcol[3] = { float3(1.00, 0.70, 0.28),
                             float3(1.00, 0.96, 0.90),
                             float3(0.98, 0.44, 0.10) };
    const float vper[3]  = { 19.0, 14.0, 26.0 };
    const float vpha[3]  = { 0.15, 0.52, 0.80 };
    const float vcx[3]   = { 0.58, 0.33, 0.86 };
    const float vw[3]    = { 0.20, 0.17, 0.18 };
    for (int i = 0; i < 3; i++) {
        float life = fract(t / vper[i] + vpha[i]);
        float env = sin(3.14159 * life);
        float y = mix(0.72, 1.06, life);
        float x = aspect * (vcx[i] + 0.06 * sin(life * 6.2832 + vpha[i] * 9.0));
        mass += vcol[i] * (vw[i] * env * env
                           * auroraBlob(q, float2(x, y), float2(0.17, 0.10)));
    }

    // Les rideaux : ils glissent vers le bas et CREUSENT la lumière — du
    // noir entre les filaments, jamais une nappe.
    float2 ac = float2(q.x * 3.1, (q.y - t * 0.045) * 1.15);
    float w1 = scfbm(ac + float2(t * 0.016, 0.0));
    float w2 = scfbm(ac * 1.7 - float2(t * 0.010, t * 0.024) + 2.1 * w1);
    float cur = scfbm(ac * 1.27 + float2(1.9 * w1, -1.5 * w2));
    cur = pow(clamp(cur * 1.18, 0.0, 1.0), 2.5);
    mass *= 0.44 + 0.98 * cur;

    // La nuit avale tout dans la moitié haute : le contenu de la page vit
    // sur du noir, l'aurore n'est qu'un sol.
    mass *= smoothstep(0.44, 0.88, q.y);

    float3 c = 1.0 - exp(-mass * 1.70);

    // La gradation anti-caramel : sous les basses lumières la couleur
    // retombe vers le gris, dans les hautes la saturation remonte.
    float3 g3 = float3(dot(c, float3(0.299, 0.587, 0.114)));
    float vmax = max(c.r, max(c.g, c.b));
    float keep = mix(0.30, 1.0, smoothstep(0.06, 0.34, vmax));
    float push = 0.45 * smoothstep(0.45, 0.85, vmax);
    c = clamp(mix(g3, c, keep + push), 0.0, 1.0);

    c += (schash21(position * 1.113 + fract(t * 0.618) * float2(17.0, 29.0))
          - 0.5) * (2.0 / 255.0);
    c = clamp(c, 0.0, 1.0);
    return half4(half3(c), 1.0) * color.a;
}
