#include <metal_stdlib>
using namespace metal;

// MARK: - L'OUVERTURE — des centaines de milliers de points (23-09)
//
// « Je veux de la matière, du shader, de l'ouverture magique, avec des
//   milliers de particules inférieures à 0,6 px, like three.js —
//   particules noir, orange, rouge. » (Kathryn, 23-09.)
//
// ⚠️ AUCUNE PARTICULE N'EXISTE EN MÉMOIRE. Rien n'est stocké, rien n'est
// mis à jour sur le processeur : la position de chaque point est CALCULÉE
// ici à partir de son seul numéro et du temps. Un appel de dessin, zéro
// tampon, zéro allocation par image.
//
// ⚠️ C'EST DEUX ORDRES DE GRANDEUR MOINS CHER QUE LE FEU. Un shader de
// fragment plein écran travaille sur des MILLIONS de pixels ; ici on ne
// touche que les quelques fragments que les points couvrent.
//
// ⚠️ LE CHAMP EST UN ROTATIONNEL (`particules-curl`, cuit par script) :
// sa divergence est nulle, donc les particules TOURNENT sans jamais
// s'entasser ni laisser de trous. Un champ de bruit pris tel quel crée des
// puits et des sources, et le nuage se troue.
//
// ⚠️ ET SURTOUT : ELLES EMPORTENT L'ÉCRAN (mesuré le 23-09 — sans ça, on
// ne voit que de la poussière orange). Chaque point naît sur un VRAI pixel
// de l'écran qu'on quitte, photographié au moment du geste, et en emporte
// la lumière : le texte clair jette des braises vives, le fond noir
// presque rien. L'écran se défait EN LUI-MÊME, il ne se couvre pas.

// L'état du passage, partagé par les points et par le voile : une seule
// horloge, donc aucun raccord visible entre les deux.
struct Passage {
    float2 taille;
    float2 foyer;
    float  avance;
    // La borne des ÉTINCELLES : tout point dont le numéro lui est
    // inférieur en est une. ⚠️ Elles occupaient un tirage au hasard
    // (24-09) ; les ranger au DÉBUT permet au rendu de ne dessiner que
    // la queue du passage — 22 500 points au lieu de 900 000 pendant la
    // seconde et demie où elles sont seules en vie.
    float  etincelles;
};

struct Point {
    float4 position [[position]];
    float  taille   [[point_size]];
    half4  couleur  [[user(couleur)]];
};

// ⚠️ DEUX STRUCTURES, ET C'EST OBLIGATOIRE. Un shader de fragment ne peut
// PAS recevoir la structure de sortie du sommet telle quelle : `point_size`
// y est interdit (« invalid type for input declaration in a fragment
// function »). On redéclare donc ce qui traverse vraiment — la couleur
// seule — étiqueté `user(couleur)` pour que Metal fasse le raccord.
struct PointDans {
    half4 couleur [[user(couleur)]];
};

// Un générateur pseudo-aléatoire, à partir du numéro du point. Pas de
// tampon d'aléa : la graine EST l'index.
static float hasard(uint n, uint sel) {
    uint h = n * 747796405u + sel * 2891336453u;
    h = ((h >> ((h >> 28) + 4u)) ^ h) * 277803737u;
    h = (h >> 22) ^ h;
    return float(h & 0x00FFFFFFu) / float(0x01000000u);
}

// LA RAMPE : blanc chaud → jaune → orange → rouge de braise → noir.
// Huit paliers, à la main : pas de texture pour huit couleurs. Aucune
// autre couleur n'existe ici — c'est sa loi.
static half3 braise(float age) {
    float x = saturate(age) * 7.0;
    int i = int(x);
    float f = x - float(i);
    half3 c[8] = {
        half3(1.00h, 0.96h, 0.88h), half3(1.00h, 0.78h, 0.30h),
        half3(1.00h, 0.52h, 0.10h), half3(0.92h, 0.28h, 0.05h),
        half3(0.62h, 0.10h, 0.02h), half3(0.26h, 0.03h, 0.01h),
        half3(0.06h, 0.01h, 0.00h), half3(0.00h, 0.00h, 0.00h)
    };
    int j = min(i + 1, 7);
    return mix(c[i], c[j], half(f));
}

// LE FRONT. Une seule fonction, lue par les points ET par le voile : le
// noir arrive exactement là où les braises viennent de partir. Deux
// formules séparées dériveraient, et on verrait la couture.
static float front(float2 p, float2 foyer) {
    // ⚠️ 0,44 ET PAS 0,30 : à 0,30 le front traversait l'écran en un tiers
    // du passage et TOUT vivait en même temps — un lavis brun uniforme,
    // sans bord, sans cause (mesuré le 23-09 : 74 % de l'écran au-dessus
    // du noir, d'un coin à l'autre). Une combustion se voit à son FRONT.
    return distance(p, foyer) * 0.44;
}

vertex Point particuleSommet(uint id [[vertex_id]],
                             constant Passage &pa    [[buffer(0)]],
                             texture2d<float> curl   [[texture(0)]],
                             texture2d<float> ecran  [[texture(1)]]) {
    constexpr sampler tourne(filter::linear, address::repeat);
    constexpr sampler plaque(filter::linear, address::clamp_to_edge);

    // LA NAISSANCE : une position de départ, tirée du numéro du point.
    float2 p0 = float2(hasard(id, 1u), hasard(id, 2u));

    // CE QU'ELLE EMPORTE : la couleur du pixel sur lequel elle naît.
    float3 src = ecran.sample(plaque, p0).rgb;
    float  lum = dot(src, float3(0.30, 0.59, 0.11));
    float  clair = saturate(lum * 3.2);          // 0 sur le noir, 1 sur l'encre

    // ⚠️ TROIS POPULATIONS, TIRÉES DU SEUL NUMÉRO DU POINT (23-09, « encore
    // plus d'effet »). Un nuage d'une seule espèce est plat : tout part à la
    // même vitesse, à la même taille, et ça se voit.
    //   · LE FOND (45 %) : large, lent, sombre — il donne le VOLUME ;
    //   · LE DEVANT (52 %) : fin, rapide, vif — il donne le grain ;
    //   · LES ÉTINCELLES (2,5 %, ≈ 22 000) : minuscules, deux fois et demie
    //     plus longues à mourir, elles montent BEAUCOUP plus haut et restent
    //     blanches. C'est elles qu'on suit des yeux. Sa loi, mot pour mot :
    //     la brillance vient de la blancheur, jamais de l'épaisseur.
    bool fond   = hasard(id, 11u) < 0.45;
    bool etincelle = float(id) < pa.etincelles;

    // ⚠️ L'OUVERTURE SE PROPAGE DEPUIS LE DOIGT. Plus on est loin du
    // foyer, plus on part tard : c'est ce délai qui donne sa CAUSE au
    // mouvement — rien ne part « partout en même temps ».
    float retard = front(p0, pa.foyer) + hasard(id, 3u) * 0.10;
    // ⚠️ LA PLUPART VIVENT TRÈS PEU, QUELQUES-UNES LONGTEMPS (le cube sur
    // un tirage uniforme). C'est ça qui laisse du NOIR derrière le front —
    // une vie longue pour toutes, et l'écran reste allumé partout — et qui
    // donne les dernières braises qui meurent sur l'écran suivant.
    // Ce qui brûle clair brûle plus longtemps.
    float h9 = hasard(id, 9u);
    float vie = 0.18 + 0.55 * h9 * h9 * h9 + 0.14 * clair;
    vie *= etincelle ? 2.80 : (fond ? 1.25 : 1.00);
    float age = (pa.avance - retard) / vie;

    Point s;
    if (age <= 0.0 || age >= 1.0) {
        // Hors de sa vie : on la jette hors du cadre. Moins cher qu'un
        // branchement dans le fragment shader.
        s.position = float4(-2.0, -2.0, 0.0, 1.0);
        s.taille = 0.0;
        s.couleur = half4(0.0h);
        return s;
    }

    // LA TRAJECTOIRE : elle monte, et le rotationnel l'enroule.
    // ⚠️ DEUX OCTAVES. Une seule donnait de grosses volutes molles : la
    // seconde, trois fois plus serrée, ajoute les petits tourbillons qui
    // font la fumée. L'échantillonneur est en `repeat`, donc le pavage à
    // 2,7 ne coûte rien de plus qu'une lecture.
    float2 c = curl.sample(tourne, p0).rg - 0.5;
    c += (curl.sample(tourne, p0 * 2.7 + 0.37).rg - 0.5) * 0.45;
    // Les étincelles échappent au champ : elles filent presque droit.
    if (etincelle) c *= 0.30;

    float d = age * age * 0.42;                     // elle accélère
    // Le fond traîne, le devant file, l'étincelle s'arrache.
    float vitesse = etincelle ? 1.95 : (fond ? 0.65 : 1.25);
    float2 p = p0 + c * d * 2.6 * vitesse;
    p.y -= d * 0.55 * vitesse;
    // un frémissement propre à chaque point, sinon elles voyagent en bloc
    p.x += (hasard(id, 5u) - 0.5) * d * 0.12;

    // Repère de Metal : −1…1, l'origine au centre, y vers le HAUT.
    s.position = float4(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0, 0.0, 1.0);

    // ⚠️ SOUS LE PIXEL. Le point fait 2,6 px de DALLE — soit moins d'un
    // point d'écran à 3× — et son fragment porte une chute radiale : ce
    // qu'on voit est une tache bien plus petite, qui s'ADDITIONNE à ses
    // voisines. C'est ce dépôt fractionnaire qui donne le grain de
    // three.js ; un point d'un pixel plein donnerait du poivre.
    s.taille = etincelle ? 1.8 : (fond ? 3.4 : 2.2);

    // LE TEMPS DE LA BRAISE. Un point né sur du noir démarre un peu plus
    // loin dans la rampe ; un point né sur de l'encre claire passe par le
    // blanc chaud. ⚠️ Le décalage reste PETIT (0,12) : à 0,26 les points
    // nés sur le noir sautaient le jaune et l'orange et naissaient déjà
    // rouge sombre — sur une app noire, c'est-à-dire TOUS (23-09).
    // Les étincelles refroidissent deux fois moins vite : elles restent
    // blanches longtemps après que le nuage est retombé au rouge.
    float t = saturate(age + 0.06 * (1.0 - clair));
    if (etincelle) t = saturate(age * 0.55);
    // ⚠️ LA PLUPART SONT SOMBRES, QUELQUES-UNES CRÈVENT LE BLANC. Un
    // tirage uniforme (0,35…1,00) donnait une nappe brune homogène — son
    // mot pour ça est « opaque ». La puissance 2,2 écrase la masse vers le
    // bas et laisse une minorité clipper en blanc : le noir absolu entre,
    // et la brillance par la blancheur, jamais par l'épaisseur.
    float eclat = 0.12 + 0.88 * pow(hasard(id, 7u), 2.2);
    // ⚠️ LE PLANCHER EST L'EFFET, PAS LE BONUS. Cette app est NOIRE : si
    // la braise n'existe que là où l'écran brille, il ne se passe rien.
    // L'écran clair ajoute, il ne fonde pas.
    // ⚠️ LE GAIN PASSE PAR LA COULEUR, JAMAIS PAR L'ALPHA (payé le 23-09 :
    // les étincelles étaient INVISIBLES). L'alpha est `saturate`é à 1 ;
    // tout ce qu'on y empile au-delà est jeté en silence, et une étincelle
    // « 2,4 fois plus forte » finissait exactement aussi terne que le
    // reste — en plus petit, donc plus sombre. La couleur est en `half` :
    // elle passe au-dessus de 1 et le mélange additif la garde.
    float gain = (0.95 + 1.50 * clair)
               * (etincelle ? 3.60 : (fond ? 0.42 : 1.00));
    // ⚠️ LE FRONT EST FAIT DE BRAISES, PAS D'UNE BANDE DE LUMIÈRE. Le
    // point flambe à sa NAISSANCE puis retombe tout de suite : ce sont ces
    // milliers d'éclats neufs, côte à côte, qui dessinent la ligne de feu.
    // Un halo dessiné le long du front aurait été un balayage — jamais.
    gain *= 1.0 + 2.20 * exp(-age * 16.0);
    // ⚠️ UNE SEULE CHOSE REFROIDIT, ET C'EST LA RAMPE. Un facteur
    // `pow(1 - age)` EN PLUS de la rampe et de l'éclat, c'était trois
    // extinctions multipliées : la braise était noire au quart de sa vie,
    // et le front n'avait pas de traîne (mesuré le 23-09 — l'écran vide à
    // l'avancement 0,58). La rampe finit déjà sur du noir : elle suffit.
    float naissance = saturate(age / 0.05);   // pour qu'aucune ne « claque »
    s.couleur = half4(braise(t) * half(eclat * gain), half(naissance));
    return s;
}

fragment half4 particuleFragment(PointDans s [[stage_in]],
                                 float2 dans [[point_coord]]) {
    // La chute radiale : le point n'est pas un carré, c'est une tache.
    float r = length(dans - 0.5) * 2.0;
    float a = saturate(1.0 - r);
    // ⚠️⚠️ LE GRAIN (24-09) — « elles doivent être encore plus fines,
    // genre 0,4 px, en dégradé ».
    // ON NE PEUT PAS ÉCRIRE « 0,4 PIXEL » ET L'OBTENIR : un point plus
    // petit qu'un pixel ne devient pas plus fin, il devient plus DUR — le
    // rastériseur lui donne quand même un fragment plein, et on obtient du
    // poivre. Ce qui donne vraiment un grain sous le pixel, c'est la
    // CHUTE : le point garde ses 2 à 3 px de dalle, mais son cœur visible
    // se resserre et tout le reste devient dégradé.
    //   · avant : a², le cœur visible faisait ≈ 1,2 px ;
    //   · ici   : a⁴, il tombe à ≈ 0,4 px — et la tache autour n'est plus
    //     qu'un halo qui s'ADDITIONNE à ses voisines.
    // ⚠️ ET ÇA ASSOMBRIT LE NUAGE : a⁴ ne dépose que 40 % de la lumière de
    // a² à pic égal. Le facteur passe donc de 3,2 à 5,0 — une compensation
    // PARTIELLE, volontairement : le pic ne bouge presque pas (donc pas de
    // néon), et c'est le nombre de points qui rattrapera le reste si elle
    // trouve le nuage trop sombre. Le nombre, jamais l'épaisseur.
    a = a * a;
    a = a * a;
    // ⚠️ ADDITIF : le fond est noir, les taches s'ajoutent. C'est
    // l'accumulation qui fait la matière, pas l'opacité de chacune.
    return half4(s.couleur.rgb * half(a) * s.couleur.a * 5.0h, 0.0h);
}

// MARK: - LE VOILE
//
// L'écran qu'on quitte doit disparaître pendant que les particules
// montent, et l'écran suivant apparaître dessous.
//
// ⚠️ IL NE MONTE PAS UNIFORMÉMENT : il noircit là où le front vient de
// passer, avec LE MÊME `front()` que les points. Un fondu au noir global
// par-dessus des braises, c'est un rideau posé sur une animation — deux
// choses. Ici c'est une seule : ce qui part laisse du noir.

struct SommetVoile { float4 position [[position]]; };

vertex SommetVoile voileSommet(uint id [[vertex_id]]) {
    // Un quad plein cadre, sans tampon : quatre coins déduits de l'index.
    float2 c[4] = { float2(-1,-1), float2(1,-1), float2(-1,1), float2(1,1) };
    SommetVoile s;
    s.position = float4(c[id], 0.0, 1.0);
    return s;
}

fragment half4 voileFragment(float4 pos [[position]],
                             constant Passage &pa [[buffer(0)]]) {
    float2 uv = pos.xy / pa.taille;
    // Le noir suit le front, avec un petit retard : les braises partent
    // d'abord, le noir les suit.
    // ⚠️ IL DOIT ÊTRE PLEIN PARTOUT AVANT `CoupeEtat.milieu` (0,62), sinon
    // l'écran change sous les yeux : 0,44 × 0,99 (le coin le plus loin)
    // + 0,06 + 0,10 = 0,60. Toucher au front oblige à refaire ce calcul.
    float monte = saturate((pa.avance - front(uv, pa.foyer) - 0.06) / 0.10);
    // Puis il s'efface, et l'écran suivant apparaît À TRAVERS les
    // dernières braises.
    float part = saturate((pa.avance - 0.64) / 0.33);
    float o = monte * (1.0 - part);
    // Prémultiplié : du noir à `o`.
    return half4(0.0h, 0.0h, 0.0h, half(o));
}
