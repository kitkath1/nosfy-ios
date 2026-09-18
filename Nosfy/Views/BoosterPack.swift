import SceneKit
import SwiftUI
import os

// MARK: - Le maillage du booster (`booster.bin`)

/// Le sachet vient d'un GLB Sketchfab décortiqué hors-ligne (le pipeline
/// maison de `MoonSDF.bin` : pas de dépendance, pas de conversion USDZ).
/// Le fichier porte la géométrie DEBOUT, centrée, hauteur 1 :
/// `WBST` + nVerts (u32) + nIndices (u32) + yTear (f32), puis positions ×3,
/// normales ×3, tangentes ×4, UV ×2 (f32) et indices (u32).
///
/// Les UV parlent la langue du pack : `v` court le long du sachet (0,03 en
/// bas → 0,97 en haut), `u` le traverse. La face avant vit dans la bande
/// u [0,353 ; 0,644], le dos dans la même bande décalée de +0,345 (sommets
/// dédoublés à l'export). La découpe d'ouverture est donc une simple
/// frontière en `v` — aucun redécoupage de maillage à l'ouverture.
enum BoosterBin {
    struct Mesh {
        let geometry: SCNGeometry
        /// La frontière artwork/serti haut, en Y modèle : la ligne de déchirure.
        let yTear: Float
    }

    static func load() -> Mesh? {
        guard let url = Bundle.main.url(forResource: "booster", withExtension: "bin"),
              let data = try? Data(contentsOf: url), data.count > 16,
              data.prefix(4) == Data("WBST".utf8) else { return nil }
        let nV = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 4, as: UInt32.self) })
        let nI = Int(data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 8, as: UInt32.self) })
        let yTear = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: 12, as: Float.self) }

        var off = 16
        func slice(_ bytes: Int) -> Data {
            defer { off += bytes }
            return data.subdata(in: off ..< off + bytes)
        }
        let pos = slice(nV * 12), nor = slice(nV * 12)
        let tan = slice(nV * 16), uv = slice(nV * 8)
        let idx = slice(nI * 4)

        func source(_ d: Data, _ sem: SCNGeometrySource.Semantic, _ comps: Int) -> SCNGeometrySource {
            SCNGeometrySource(data: d, semantic: sem, vectorCount: nV,
                              usesFloatComponents: true, componentsPerVector: comps,
                              bytesPerComponent: 4, dataOffset: 0, dataStride: comps * 4)
        }
        let element = SCNGeometryElement(data: idx, primitiveType: .triangles,
                                         primitiveCount: nI / 3, bytesPerIndex: 4)
        let geo = SCNGeometry(sources: [source(pos, .vertex, 3),
                                        source(nor, .normal, 3),
                                        source(tan, .tangent, 4),
                                        source(uv, .texcoord, 2)],
                              elements: [element])
        return Mesh(geometry: geo, yTear: yTear)
    }
}

// MARK: - Les shaders de découpe

/// Corps et bande arrachable sont DEUX rendus du même maillage, séparés par
/// la frontière `v` de la ligne de déchirure — le corps jette tout ce qui
/// est au-dessus, la bande tout ce qui est en dessous. La déchirure avance
/// en `u` sous le doigt : la bande jette aussi ce qui est derrière le front,
/// avec un bord rongé (hachage sur `v`) et une lèvre en fusion.
///
/// PIÈGE (cousin de l'arité des stitchables) : les noms du
/// `#pragma arguments` doivent répondre EXACTEMENT aux `setValue(_:forKey:)`
/// Swift — un nom qui boite et l'uniforme reste à zéro, sans un mot.
enum BoosterShader {
    /// v de la ligne de déchirure (frontière artwork / serti haut).
    static let vCut: Float = 0.8896
    /// Bande u de la face ; le dos vit à +0,345, replié par le shader.
    static let u0: Float = 0.353
    static let u1: Float = 0.644

    /// Le repli commun des deux bandes + la teinte braise du bord fondu.
    /// CONTRAINTE : un seul modificateur `.surface` par matériau — un seul
    /// `#pragma body`. Tout ce que la peau réclame (découpe, rim, mylar)
    /// vit donc dans la MÊME chaîne, découpe d'abord (les fragments jetés
    /// ne paient pas la suite).
    private static let preamble = """
    #pragma arguments
    float tearU;
    float tornGlow;
    float rimGain;
    float metalLift;
    float inviteU;
    float inviteGlow;
    float moonCharge;
    float deathGold;
    float lipGlow;
    float skewU;
    float cornerU;
    #pragma body
    float bu = _surface.diffuseTexcoord.x;
    if (bu > 0.68) { bu -= 0.345; }
    float bv = _surface.diffuseTexcoord.y;
    float3 ember = float3(1.0, 0.42, 0.13);
    """

    /// La peau mouillée, après les discards : rim Fresnel blanc au rasant,
    /// rugosité qui se resserre sur les bords (la laque s'y aiguise — c'est
    /// lui qui étire les barres du studio en stries), et la remontée
    /// gris-mylar du film pour la recette métal (metalLift 0 = laque noire,
    /// 1 = mylar : un métal au basecolor noir est un trou noir).
    private static let sheen = """
    // La lueur d'INVITE : un front fantôme qui balaie la ligne de
    // découpe — le geste montré par la lumière, sans un mot d'UI.
    // (La CHARGE de la lune ne vit pas ici : deux pièges payés — à cet
    // étage `_surface.emission` est vide, et une texture liée par KVC ne
    // se lie pas de façon fiable. Elle vit dans moonGlowNode, une
    // surcouche additive à carte pré-masquée.)
    float invBand = exp(-pow((bv - 0.8896) / 0.010, 2.0));
    float invFront = exp(-pow((bu - inviteU) / 0.035, 2.0));
    _surface.emission.rgb += ember * invBand * invFront * inviteGlow * 1.6;
    // La fente qui FUIT DE LA LUMIÈRE : le fil d'or CONTINU de la
    // lèvre — la charge au maintien et le tell des cartes rares
    // l'allument (l'invite, elle, reste un front qui balaie).
    _surface.emission.rgb += float3(1.0, 0.72, 0.30) * invBand * lipGlow * 1.5;
    // La CHARGE de la lune : les traits du croissant et de son étoile
    // vivent dans la DIFFUSE (elle, elle est chargée à cet étage —
    // l'émission est vide et les textures KVC ne se lient pas, pièges
    // payés). On les RE-ÉMET, masqués autour du croissant, pilotés par
    // la déchirure. À pleine charge, le trait franchit le seuil de bloom.
    float moonMask = exp(-(pow((bu - 0.50) / 0.11, 2.0)
                           + pow((bv - 0.68) / 0.13, 2.0)));
    _surface.emission.rgb += _surface.diffuse.rgb * moonMask * moonCharge * 5.0;

    float3 shN = normalize(_surface.normal);
    float3 shV = normalize(_surface.view);
    float shRim = pow(1.0 - saturate(dot(shN, shV)), 3.5);
    _surface.diffuse.rgb = mix(_surface.diffuse.rgb,
                               max(_surface.diffuse.rgb, float3(0.45)), metalLift);
    _surface.emission.rgb += float3(1.0, 0.98, 0.94) * shRim * rimGain;
    _surface.roughness = _surface.roughness * mix(1.0, 0.55, shRim);
    """

    /// LA MORT PAR L'OR : à l'effacement du sachet, l'émission ne
    /// s'assombrit JAMAIS en rouge — de l'orange qui baisse sur noir
    /// traverse le marron (la loi anti-brun de toujours). `deathGold`
    /// GLISSE la teinte vers un or-blanc de même luminance ; c'est la
    /// chute hors cadre qui efface, pas une extinction rouge.
    private static let deathTail = """
    float dLum = dot(_surface.emission.rgb, float3(0.299, 0.587, 0.114));
    _surface.emission.rgb = mix(_surface.emission.rgb,
                                dLum * float3(1.7, 1.35, 0.8), deathGold);
    """

    /// Le corps : muet sous la ligne, et sur la tranche ouverte le
    /// DÉGRADÉ DE REFROIDISSEMENT — blanc fusion au front, or profond
    /// dans le sillage, puis l'EXTINCTION PAR LA LUMINOSITÉ seule : la
    /// teinte ne quitte jamais l'or (le rouge sombre est interdit — ce
    /// sont la saturation et l'or qui tiennent, jamais le brun). Un
    /// filet de braise dorée subsiste dans la fente : c'est lui que la
    /// houle du zoom fait respirer.
    static let body = preamble + """
    if (bv > 0.8896) { discard_fragment(); }
    float lip = smoothstep(0.012, 0.0, 0.8896 - bv);
    float opened = smoothstep(bu, bu + 0.012, tearU);
    float behind = saturate((tearU - bu) / 0.20);
    float3 heat = mix(float3(1.0, 0.93, 0.78), float3(1.0, 0.55, 0.18), behind);
    _surface.emission.rgb += heat * lip * opened * tornGlow
        * (0.09 + 2.71 * pow(1.0 - behind, 2.0));
    // Le FIL D'OR devant le front : la lame posée sur la ligne, qui
    // attend le doigt (capture 1 de la référence).
    _surface.emission.rgb += float3(1.0, 0.80, 0.42)
        * lip * (1.0 - opened) * tornGlow * 1.3;
    // Le RENFLEMENT blanc-or AU front — le bloom fait le halo.
    float frontGlow = exp(-pow((bu - tearU) / 0.015, 2.0));
    _surface.emission.rgb += float3(1.0, 0.93, 0.72)
        * lip * frontGlow * tornGlow * 4.5;
    // L'OMBRE FAUSSE du rouleau sur l'illustration (capture 2) : une
    // ellipse douce sous le front, qui meurt avec la braise.
    float sh = exp(-(pow((bu - tearU) / 0.05, 2.0)
                     + pow((0.8896 - bv) / 0.035, 2.0)));
    _surface.diffuse.rgb *= 1.0 - 0.45 * sh * tornGlow;
    """ + sheen + deathTail

    /// La bande : plus AUCUN discard derrière le front — elle reste
    /// entière et le peeling (modificateur de géométrie) la soulève.
    /// La morsure blanche vit à cheval sur le front — le MÊME front
    /// oblique que la géométrie (skew + coin), sinon la braise et le
    /// pli divergent au coin.
    static let cap = preamble + """
    if (bv < 0.8896) { discard_fragment(); }
    float nvc = saturate((bv - 0.8896) / 0.077);
    float cornerC = exp(-pow((bu - 0.353) / 0.06, 2.0));
    float frontC = tearU + skewU * nvc + cornerU * nvc * cornerC;
    float jag = (fract(sin(bv * 817.7) * 43758.5453) - 0.5) * 0.014;
    float front = frontC + jag;
    float d = abs(bu - front);
    float burn = smoothstep(0.020, 0.0, d);
    _surface.emission.rgb += (ember * 2.2 + float3(1.0, 0.85, 0.6) * burn) * burn * tornGlow;
    // Le TUBE DE BRAISE : les flancs enroulés (la normale a quitté la
    // frontale) s'allument — la tranche du rouleau remplace la
    // tearLight, morte au simulateur. Indifférent au pli avant/dos.
    float3 rollN = normalize(_surface.normal);
    float turned = 1.0 - abs(rollN.z);
    _surface.emission.rgb += ember * turned * turned * tornGlow * 0.9;
    """ + sheen

    /// LE PEELING (modificateur de GÉOMÉTRIE de la bande) : l'ENROULEMENT
    /// DÉVELOPPABLE À CHARNIÈRE MOBILE — la bande s'enroule en spirale
    /// autour du FRONT lui-même (la ligne quasi verticale qui avance avec
    /// tearU), comme un scotch qu'on pèle. Plus jamais l'axe horizontal
    /// fixe hingeY : il donnait un volet basculé à angle plafonné.
    ///
    /// Géométrie mesurée dans booster.bin : u→x affine de pente −2,795
    /// (torn = cu < frontU = côté +x modèle) ; le sachet vit sous une
    /// scale de node (0,75, 1, 0,45) — le rouleau est calculé en unités
    /// MONDE puis recompensé par axe, sinon il s'écrase en ellipse.
    /// Spirale d'Archimède (r grandit avec θ) : les tours ne se
    /// superposent jamais sur le même cylindre (z-fighting).
    /// Le frisson module le RAYON (une onde qui voyage dans l'étoffe),
    /// plus l'angle du volet. Normales ET tangentes tournent avec la
    /// matière — sans elles le spéculaire et le froissé restent plats.
    ///
    /// AUCUNE porte en v : les sommets sous la ligne de déchirure
    /// suivent le rouleau (leurs fragments sont de toute façon jetés par
    /// le discard de surface) — c'est ce qui évite la membrane étirée
    /// entre le corps immobile et la bande enroulée.
    static let capGeometry = """
    #pragma arguments
    float tearU;
    float curlR;
    float curlK;
    float skewU;
    float cornerU;
    float flutterAmp;
    float flutterW;
    float curlDir;
    float breathGain;
    float releaseT;
    float rollWobble;
    #pragma body
    // LE FRONT EN POSITION X, PAS EN u : les deux peaux du sachet (tube)
    // ont des pentes u→x OPPOSÉES — un gate en cu enroule la face et
    // étire le dos en drapeau (payé aux deux premières captures). La
    // ligne de front est verticale en espace modèle : tout sommet de
    // bande à sa gauche (+x = côté départ de la découpe) roule, les
    // deux plis ensemble. x(u) face avant : 1,3933 − 2,795·u.
    float cv = _geometry.texcoords[0].y;
    float nv = saturate((cv - 0.8896) / 0.077);
    float xs = _geometry.position.x;
    float corner = exp(-pow((xs - 0.4067) / 0.17, 2.0));
    float frontU = tearU + skewU * nv + cornerU * nv * corner;
    float xFront = 1.3933 - 2.795 * frontU;
    float dm = xs - xFront;
    if (dm > 0.0) {
        float dw = dm * 0.75;
        float r = curlR * (1.0 + flutterAmp
            * sin(scn_frame.time * flutterW + xs * 14.0 + cv * 26.0));
        // L'ACCROCHE de l'envol : le rouleau se SUR-TEND (rayon serré
        // de 20 %) et tremble en bloc — il résiste avant la rupture.
        r = r * (1.0 - 0.20 * releaseT);
        float theta = dw / max(r, 0.005);
        r = r + curlK * theta;
        theta = dw / max(r, 0.005) + rollWobble;
        float c = cos(theta);
        float s = sin(theta);
        _geometry.position.x = xFront + (r * s) / 0.75;
        _geometry.position.z += curlDir * r * (1.0 - c) / 0.45;
        float nx = _geometry.normal.x;
        float nz = _geometry.normal.z;
        _geometry.normal.x = nx * c - curlDir * nz * s;
        _geometry.normal.z = curlDir * nx * s + nz * c;
        float tx = _geometry.tangent.x;
        float tz = _geometry.tangent.z;
        _geometry.tangent.x = tx * c - curlDir * tz * s;
        _geometry.tangent.z = curlDir * tx * s + tz * c;
    } else {
        _geometry.position.z += sin(scn_frame.time * 1.2 + cv * 3.0)
            * breathGain * saturate(1.0 - abs(cv - 0.5) * 1.6);
    }
    """

    /// La RESPIRATION du corps : le même bombé que la partie non pelée
    /// de la bande — les deux copies du maillage respirent d'un seul
    /// souffle, sinon un jour s'ouvre pile sur la ligne de déchirure.
    static let bodyGeometry = """
    #pragma arguments
    float breathGain;
    #pragma body
    float bgv = _geometry.texcoords[0].y;
    _geometry.position.z += sin(scn_frame.time * 1.2 + bgv * 3.0)
        * breathGain * saturate(1.0 - abs(bgv - 0.5) * 1.6);
    """
}

// MARK: - La robe du sachet

/// LA ROBE : le variant du sachet, et RIEN D'AUTRE qu'un jeu de textures.
///
/// Le booster noir (28-08, `tools/sacre/PLAN-BOOSTER-NOIR.md`) est « la même
/// expérience, mais noire » : le manège, l'engagement, la charge au maintien,
/// la découpe de braise et le Sacre sont LE MÊME CODE. Le studio ne bouge pas
/// non plus — verdict de Kathryn, « le noir garde la braise » : ni lumière,
/// ni poudre, ni sol à teinter. Une robe ne change que le DESSIN plaqué.
///
/// La normal map est COMMUNE aux deux : elle décrit les plis du maillage, pas
/// le dessin — même sachet, mêmes froissures (et la laque lit la même image
/// en `clearCoatNormal` : deux fichiers pourraient diverger).
enum RobeBooster {
    /// Le sachet du set Lune : néons orange dessinés, liseré qui ÉMET.
    case lune
    /// Le sachet des légendaires : encre, liseré IRISÉ (un foil, il
    /// réfléchit), croissant débossé. Textures baked par
    /// `tools/sacre/bake_booster_noir.py`.
    case noire

    var color: String {
        switch self {
        case .lune: return "booster-color"
        case .noire: return "booster-noir-color"
        }
    }

    var emiss: String {
        switch self {
        case .lune: return "booster-emiss"
        case .noire: return "booster-noir-emiss"
        }
    }

    /// LE TELL — la fente qui fuit. Sur le noir il ne demande pas de
    /// drapeau (le sachet des légendaires SAIT ce qu'il abrite), mais il ne
    /// s'allume QUE dans la cérémonie : **au manège, verdict Kathryn du
    /// 28-08, « la fente trop moche, enlève »** — dix sachets qui fuient par
    /// le sertissage, ça fait dix lampes de poche dans une nuit qu'on veut
    /// noire. C'est l'appelant qui applique la réserve (`!gallery`).
    var tellPermanent: Bool { self == .noire }

    /// LA PALETTE DU STUDIO — la lumière du monde, pas celle de la découpe.
    ///
    /// Kathryn, 28-08, devant le premier rendu noir : *« pas de halo orange
    /// mais noir stp très dark, il est trop orange — mets noir un peu violet
    /// si tu veux, et blanc »*, puis *« les boosters doivent être noirs et
    /// l'écosystème aussi »*. La braise du set Lune repeignait le sachet noir
    /// en ambre : un albédo d'encre ne rend que ce qu'on lui envoie.
    ///
    /// Ce qui reste ORANGE sur la robe noire : **la découpe**. Le feu de la
    /// déchirure vit dans le shader (`ember`, `burn`, `heat`) et n'appartient
    /// pas au studio — un monde froid où la coupure est la seule braise, c'est
    /// le contraste qu'on cherche.
    struct PaletteStudio {
        /// La directionnelle (260) — la lumière qui sculpte les plis.
        let cle: UIColor
        /// L'omni du bas : la braise du jaune, l'améthyste du noir.
        let bas: UIColor
        /// L'échelle de cette omni — le noir la veut BASSE (« très dark »).
        let basEchelle: CGFloat
        /// Le `multiply` du sol : il teinte le reflet des sachets.
        let sol: UIColor
        /// La poussière de l'anneau, et les bouffées du cran.
        let poudre: UIColor
        /// L'horizon de l'environnement HDR (les barres blanches ne bougent
        /// pas : c'est le « et blanc » du verdict).
        let horizonHDR: SIMD3<Float>
        /// Sa force, et celle de sa reprise au sol. Le noir les veut BASSES :
        /// sans art lumineux dessiné dans le bas du sachet (le jaune a son
        /// lac de braise), le moindre feu rasant fait une TACHE au lieu d'un
        /// horizon — c'est ce halo-là que le verdict chasse.
        let horizonForce: Float
        let solForce: Float
    }

    /// LA MATIÈRE — la laque du set Lune, le MAT du sachet noir.
    ///
    /// Kathryn, 28-08 : *« plus d'effet mat sur le booster dans le noir »*.
    /// Le vernis épais (clearCoat 1,0 à rugosité 0,04) est ce qui fait le
    /// sachet laqué du set Lune ; sur une encre sans néon dessiné, il ne
    /// rend qu'une vitre grise. Le noir garde un vernis MINCE — assez pour
    /// que le foil du liseré vive, trop peu pour que la grande face brille.
    struct Matiere {
        let rugosite: CGFloat
        let vernis: CGFloat
        let vernisRugosite: CGFloat
        /// Le métal du corps (0 = laque : encre F0 4 % ; > 0 = foil laminé)
        /// et le relèvement du film qui va avec (`metalLift`, sinon métal
        /// noir = trou noir — la leçon du banc mylar).
        var metal: CGFloat = 0
        var metalLift: CGFloat = 0
    }

    /// `-noirMatiere <n>` (18-09) — LE BANC DE LA MATIÈRE NOIRE. Verdict de
    /// Kathryn sur son iPhone, manège noir ouvert : « trop mat, pas assez
    /// réaliste ». Le mat du 28-08 chassait la « vitre grise » d'un vernis
    /// épais sous un horizon orange FORT ; le studio noir a depuis été
    /// refroidi et presque éteint (horizon 0,09), et il ne restait plus rien
    /// à refléter. Cinq candidates jugées à l'écran, sur SON téléphone
    /// (tools/sacre/ANALYSE-SACHET-NOIR-MATIERE-2026-09-18.md) : la 1 « plus
    /// sombre » → la 5, LAQUE SOMBRE, « ok très bien » (18-09 18:10). Elle
    /// est la valeur par DÉFAUT ; le mat du 28-08 reste au banc en 9.
    static let variantNoir: Int = UserDefaults.standard
        .string(forKey: "noirMatiere").flatMap(Int.init) ?? 0

    var matiere: Matiere {
        switch self {
        case .lune: return Matiere(rugosite: 0.35, vernis: 1.0,
                                   vernisRugosite: 0.04)
        case .noire:
            switch Self.variantNoir {
            case 1: // laque noire — la recette Lune
                return Matiere(rugosite: 0.35, vernis: 1.0, vernisRugosite: 0.05)
            case 2: // satin — reflet présent, doux
                return Matiere(rugosite: 0.45, vernis: 0.75, vernisRugosite: 0.14)
            case 3: // foil noir — métal sombre laminé (au banc : le film
                    // remonté à 0,45 vire au GRIS clair, la leçon mylar)
                return Matiere(rugosite: 0.24, vernis: 0.55, vernisRugosite: 0.08,
                               metal: 0.55, metalLift: 0.45)
            case 4: // foil sombre — un soupçon de métal, le film reste noir
                return Matiere(rugosite: 0.30, vernis: 0.85, vernisRugosite: 0.06,
                               metal: 0.32, metalLift: 0.14)
            case 9: // le mat du 28-08 (témoin d'A/B)
                return Matiere(rugosite: 0.62, vernis: 0.30, vernisRugosite: 0.32)
            default: // 5, LAQUE SOMBRE — la valeur de la maison depuis le 18-09
                return Matiere(rugosite: 0.38, vernis: 1.0, vernisRugosite: 0.06)
            }
        }
    }

    /// La force de l'horizon HDR que la matière noire reflète — elle va
    /// AVEC la matière (un vernis sans lumière à renvoyer ne se voit pas).
    private static var horizonNoir: Float {
        switch variantNoir {
        case 1: return 0.22
        case 2: return 0.16
        case 3: return 0.28
        case 4: return 0.25
        case 9: return 0.09
        default: return 0.13
        }
    }

    var palette: PaletteStudio {
        switch self {
        case .lune:
            return PaletteStudio(
                cle: UIColor(red: 1.0, green: 0.93, blue: 0.85, alpha: 1),
                bas: UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1),
                basEchelle: 1.0,
                sol: UIColor(red: 1.0, green: 0.80, blue: 0.65, alpha: 1),
                poudre: UIColor(red: 1.0, green: 0.92, blue: 0.78, alpha: 1),
                horizonHDR: SIMD3<Float>(1.0, 0.45, 0.14),
                horizonForce: 0.4, solForce: 0.12)
        case .noire:
            return PaletteStudio(
                // Blanc à peine bleuté : le foil irisé rend TOUTES les
                // couleurs qu'on lui donne — une clé neutre le laisse
                // arc-en-ciel au lieu de le teindre.
                cle: UIColor(red: 0.90, green: 0.93, blue: 1.0, alpha: 1),
                // LE VIOLET EST UN SOUPÇON, PAS UNE COULEUR (« violet plus
                // discret », 28-08) : désaturé et à un cinquième de la
                // braise — il ne se nomme qu'au bord des plis.
                bas: UIColor(red: 0.55, green: 0.48, blue: 0.88, alpha: 1),
                basEchelle: 0.12,
                sol: UIColor(red: 0.88, green: 0.90, blue: 1.0, alpha: 1),
                // LA POUDRE EST NOIR ET BLANC (verdict du même jour) :
                // blanc pur, et son grain perd son halo braise
                // (`pearlDotBlanche`) — sinon la poussière rallume en or ce
                // que le studio vient d'éteindre.
                poudre: .white,
                horizonHDR: SIMD3<Float>(0.34, 0.28, 0.72),
                horizonForce: Self.horizonNoir, solForce: 0.02)
        }
    }
}

// MARK: - La scène

/// Le sachet noir laqué dans son studio : la matière de la référence vient
/// de TROIS étages — le dessin (couleur + néons émissifs), les plis (la
/// normal map du GLB, gardée telle quelle), et un environnement fabriqué
/// (lame chaude + barre froide) qui fait glisser les reflets sur les plis
/// quand le pack s'incline. Le bloom de la caméra allume les néons.
final class BoosterScene {
    let scene = SCNScene()
    let packNode = SCNNode()
    /// Le tell des rares (`-boosterShiny`) — la cérémonie sait qu'une
    /// carte rare dort dedans avant même le premier geste.
    static let shinyTell = CommandLine.arguments.contains("-boosterShiny")
    /// LE BERCEAU : le nœud qui porte TOUTE la respiration (bob, sway,
    /// tremblement de découpe), PRÈS DE L'IDENTITÉ. Jamais d'animation
    /// ni d'écriture d'euler sur le pack au lacet π : à lacet π la
    /// décomposition change de forme au bruit près, et une animation de
    /// composante (`eulerAngles.z`) ou son blend-out y devient une
    /// roulette russe — LE « booster qui tourne » à la fin de
    /// l'arrachement, c'était exactement ça.
    let swayNode = SCNNode()
    let bodyNode: SCNNode
    let capNode: SCNNode
    let cardNode: SCNNode
    let moonGlowNode: SCNNode
    let moonGlowMaterial: SCNMaterial
    let perleNode: SCNNode
    private var tearLightSource: SCNLight?
    let sparks: SCNParticleSystem
    let accents: SCNParticleSystem
    let sparkNode = SCNNode()
    let cameraNode = SCNNode()
    let yTear: Float
    /// L'anneau de la galerie : cinq clones muets (pas de carte, pas de
    /// découpe) mirés dans le sol d'encre. Le VRAI sachet prend la place
    /// du clone centré à l'engagement — identiques, l'échange est invisible.
    let galleryPacks: [SCNNode]
    let floorNode: SCNNode
    /// LA NAPPE D'ALLUMAGE du sol (l'arrivée royale) : la lueur qui
    /// monte du CENTRE de l'anneau — un plan émissif additif (le sol
    /// .constant ignore les lumières, et une omni = le cube noir).
    let floorGlowNode = SCNNode()
    private let still: Bool
    /// La robe et sa palette : lues par le studio (les lumières, le sol, la
    /// poudre) et par les régies qui rallument (`dim`, `celebrate`).
    private let robe: RobeBooster
    private let palette: RobeBooster.PaletteStudio
    private let keyLight = SCNLight()
    private let embers = SCNLight()

    /// La progression de déchirure, 0…1, monotone (on ne recolle pas).
    private(set) var tearProgress: Float = 0

    init?(still: Bool, mylar: Bool = false, gallery: Bool = false,
          robe: RobeBooster = .lune) {
        guard let mesh = BoosterBin.load() else { return nil }
        yTear = mesh.yTear
        self.still = still
        self.robe = robe
        self.palette = robe.palette

        // ---- la matière commune, corps et bande ----
        // Deux recettes au banc. L'ancienne (metalness 0,45 sur albédo noir)
        // teintait les reflets PAR le noir : elle mangeait les stries
        // blanches ET assombrissait le film — le pire des deux mondes.
        // « Laque » : le corps reste encre (F0 4 %), tout le mouillé vient
        //   de la couche de vernis, dont le Fresnel rend des stries BLANCHES
        //   quel que soit l'albédo.
        // « Mylar » (-boosterMylar) : le vrai sachet de chips aluminisé,
        //   miroir neutre plein champ — le shader remonte le film vers un
        //   gris 0,45 (metalLift), sinon métal noir = trou noir.
        // Dans les deux cas la laque reçoit SA PROPRE normal map
        // (clearCoatNormal) — sans elle le vernis ignore les plis et les
        // stries refusent de se froisser.
        func material(modifier: String, geometry: String? = nil) -> SCNMaterial {
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = Self.image(robe.color)
            m.emission.contents = Self.image(robe.emiss)
            // 0,6 : la recette VALIDÉE. Le piège de la lanterne a été payé
            // DEUX fois maintenant : à 1,9, les nappes douces de la carte
            // emiss (lac, halo du croissant) font du sachet un verre ambré.
            // Les néons n'ont pas besoin de bloomer — ils sont dessinés.
            // La robe noire n'a pas SA valeur : son émissive est CALIBRÉE au
            // bake sur le profil du jaune (moyenne 0,81 · p99 33, contre 0,80
            // et 38) — sinon un foil irisé, qui couvre bien plus de surface
            // qu'un fil de néon, sortait trois fois plus chaud que lui.
            m.emission.intensity = 0.6
            m.normal.contents = Self.image("booster-normal")
            m.normal.intensity = 0.8
            if mylar {
                m.metalness.contents = 1.0
                m.roughness.contents = 0.14
                m.clearCoat.contents = 0.5
                m.clearCoatRoughness.contents = 0.10
            } else {
                m.metalness.contents = robe.matiere.metal
                m.roughness.contents = robe.matiere.rugosite
                m.clearCoat.contents = robe.matiere.vernis
                m.clearCoatRoughness.contents = robe.matiere.vernisRugosite
            }
            m.clearCoatNormal.contents = Self.image("booster-normal")
            m.clearCoatNormal.intensity = 1.1
            m.isDoubleSided = true
            if let geometry {
                m.shaderModifiers = [.surface: modifier, .geometry: geometry]
            } else {
                m.shaderModifiers = [.surface: modifier]
            }
            m.setValue(0.0 as CGFloat, forKey: "tearU")
            m.setValue(0.0 as CGFloat, forKey: "tornGlow")
            m.setValue(0.55 as CGFloat, forKey: "rimGain")
            m.setValue((mylar ? 1.0 : robe.matiere.metalLift) as CGFloat, forKey: "metalLift")
            m.setValue(-1.0 as CGFloat, forKey: "inviteU")
            m.setValue(0.0 as CGFloat, forKey: "inviteGlow")
            m.setValue(0.0 as CGFloat, forKey: "moonCharge")
            m.setValue(0.0 as CGFloat, forKey: "deathGold")
            m.setValue(0.0 as CGFloat, forKey: "lipGlow")
            m.setValue(Self.benchValue("boosterSkew", 0.012), forKey: "skewU")
            m.setValue(Self.benchValue("boosterCorner", 0.022), forKey: "cornerU")
            m.setValue(Self.benchValue("boosterBreath", still ? 0 : 0.008),
                       forKey: "breathGain")
            return m
        }
        bodyNode = SCNNode(geometry: mesh.geometry.copy() as? SCNGeometry)
        bodyNode.geometry?.materials = [material(modifier: BoosterShader.body,
                                                 geometry: BoosterShader.bodyGeometry)]
        capNode = SCNNode(geometry: mesh.geometry.copy() as? SCNGeometry)
        capNode.geometry?.materials = [material(modifier: BoosterShader.cap,
                                                geometry: BoosterShader.capGeometry)]
        // LE TELL DES CARTES RARES (`-boosterShiny`, en attendant la
        // rareté servie par la forge) : avant même le doigt, la fente
        // FUIT de la lumière — le fil d'or de la lèvre pulse lentement.
        // Le joueur SAIT qu'il se passe quelque chose, sans un mot d'UI.
        // Sur la robe noire il n'est plus un drapeau de banc — le sachet des
        // légendaires abrite TOUJOURS une légendaire —, mais **jamais au
        // manège** : dix sachets qui fuient par le sertissage, ça fait dix
        // lampes de poche dans une nuit qu'on veut noire (verdict Kathryn,
        // 28-08 : « la fente trop moche dans le manège, enlève »).
        if Self.shinyTell || (robe.tellPermanent && !gallery) {
            for node in [bodyNode, capNode] {
                guard let m = node.geometry?.firstMaterial else { continue }
                let leak = CABasicAnimation(keyPath: "lipGlow")
                leak.fromValue = 0.10
                leak.toValue = 0.52
                leak.duration = 2.2
                leak.autoreverses = true
                leak.repeatCount = .infinity
                leak.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                m.addAnimation(leak, forKey: "shinyLeak")
            }
        }
        // Les réglages du rouleau (banc : -boosterCurlR / -boosterCurlK /
        // -boosterFlutter / -boosterFlutterW / -boosterCurlDir).
        // curlDir −1 = vers la caméra (à trancher à la capture — le piège
        // des enroulements GLB inversés).
        if let capMat = capNode.geometry?.firstMaterial {
            capMat.setValue(Self.benchValue("boosterCurlR", 0.055), forKey: "curlR")
            capMat.setValue(Self.benchValue("boosterCurlK", 0.0045), forKey: "curlK")
            capMat.setValue(Self.benchValue("boosterFlutter", still ? 0 : 0.12),
                            forKey: "flutterAmp")
            capMat.setValue(Self.benchValue("boosterFlutterW", 16), forKey: "flutterW")
            capMat.setValue(Self.benchValue("boosterCurlDir", -1), forKey: "curlDir")
            capMat.setValue(0.0 as CGFloat, forKey: "releaseT")
            capMat.setValue(0.0 as CGFloat, forKey: "rollWobble")
        }

        // ---- la surcouche de CHARGE de la lune ----
        // Un second rendu du maillage, additif, dont la carte émissive est
        // PRÉ-MASQUÉE hors-ligne (croissant + étoile seuls, centre mesuré
        // au centroïde). Son emission.intensity EST la charge — une vraie
        // propriété animable, aucun uniforme KVC à lier (deux pièges de
        // liaison payés avant d'en arriver là).
        // La charge de la lune vit DANS le shader de découpe (re-émission
        // de la diffuse masquée) — cinq pièges de surcouche payés avant
        // d'y revenir. Le nœud fantôme reste pour l'API, vide.
        moonGlowMaterial = SCNMaterial()
        moonGlowNode = SCNNode()

        // ---- la carte récompense, endormie dans le sachet ----
        // L'ASPECT DE LA FORGE (1086×1448 ≈ 1,333), plus jamais 1,519 :
        // le raccord CarteVivante est un recouvrement même-image — aucun
        // fondu ne survit à 14 % d'écart d'aspect. Et la carte de
        // cérémonie porte le MÊME art que CarteVivante (carte-lune-1 par
        // défaut ; la forge remplacera les deux côtés à la fois).
        let plane = SCNPlane(width: 0.60, height: 0.60 * 1448.0 / 1086.0)
        let cm = SCNMaterial()
        cm.lightingModel = .constant
        cm.diffuse.contents = Self.image("carte-lune-1")
        cm.emission.contents = Self.image("carte-lune-1")
        cm.emission.intensity = 0
        cm.isDoubleSided = true
        plane.materials = [cm]
        cardNode = SCNNode(geometry: plane)
        cardNode.position = SCNVector3(0, -0.035, 0.03)
        cardNode.eulerAngles.y = .pi
        // La carte DORT CACHÉE tant que le sachet est clos : sa tête
        // dépassait la ligne de déchirure et se voyait par la fente
        // ouverte (le carré noir des captures). Elle se montre à
        // l'ouverture, pas avant.
        cardNode.isHidden = true
        // LE DOS de la carte (le motif croissants du sachet) : un second
        // plan collé dos à dos — la carte peut sortir DOS D'ABORD pour
        // le retournement.
        // (carte-dos.png ré-exportée au ratio 1,333 depuis dos_booster —
        // champ de croissants pur, sans le liseré du cadre : plus aucun
        // écrasement sur le plan.)
        let backPlane = SCNPlane(width: 0.60, height: 0.60 * 1448.0 / 1086.0)
        let backMat = SCNMaterial()
        backMat.lightingModel = .constant
        backMat.diffuse.contents = Self.image("carte-dos")
        backMat.isDoubleSided = false
        backPlane.materials = [backMat]
        let backNode = SCNNode(geometry: backPlane)
        backNode.position = SCNVector3(0, 0, -0.001)
        backNode.eulerAngles.y = .pi
        cardNode.addChildNode(backNode)

        // ---- le front de déchirure : trois températures ----
        // La MORSURE blanche vit dans le shader ; ici, la POUDRE DE
        // DIAMANT qui coule de l'entaille (froide, fine, lente — le jet
        // d'étincelles orange a été recalé « feu d'artifice »), et le
        // VOILE DE FUMÉE presque invisible qui monte du sillage.
        sparks = Self.makeDiamondFall()
        accents = Self.makeSmokeVeil()
        sparkNode.addParticleSystem(sparks)
        sparkNode.addParticleSystem(accents)
        // Le tell des rares, troisième voix : quelques poussières de
        // diamant s'échappent de la fente close — ça fuit.
        if Self.shinyTell { sparks.birthRate = 1.2 }
        sparkNode.position = SCNVector3(0, yTear + 0.01, -0.07)
        // LA PERLE DE DÉCOUPE : la bille incandescente qui suit le doigt
        // — c'est ELLE qui coupe. Billboard additif, pulsation rapide,
        // le bloom la fait rayonner. Cachée hors découpe.
        let perlePlane = SCNPlane(width: 0.055, height: 0.055)
        let perleMat = SCNMaterial()
        perleMat.lightingModel = .constant
        perleMat.diffuse.contents = Self.pearlDot()
        perleMat.blendMode = .add
        perleMat.writesToDepthBuffer = false
        perleMat.isDoubleSided = true
        perlePlane.materials = [perleMat]
        perleNode = SCNNode(geometry: perlePlane)
        perleNode.position = SCNVector3(0, 0, -0.02)
        perleNode.constraints = [SCNBillboardConstraint()]
        perleNode.isHidden = true
        let pulse = CABasicAnimation(keyPath: "scale")
        pulse.fromValue = SCNVector3(0.86, 0.86, 0.86)
        pulse.toValue = SCNVector3(1.14, 1.14, 1.14)
        pulse.duration = 0.055
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        perleNode.addAnimation(pulse, forKey: "perlePulse")
        sparkNode.addChildNode(perleNode)
        // LA LUMIÈRE DE LA DÉCHIRURE : le front qui brûle éclaire le
        // mylar — une omni braise qui SUIT le doigt (elle vit sur le
        // porteur de poudre), calibrée sur la braise de scène (38).
        let tearLight = SCNLight()
        tearLight.type = .omni
        tearLight.color = UIColor(red: 1.0, green: 0.5, blue: 0.18, alpha: 1)
        tearLight.intensity = 0
        // Atténuation 3,0 comme la braise omni maison : en dessous de
        // ~1,0 le simulateur rend le volume de clustering de l'omni en
        // CUBE NOIR (le carré fantôme, une bissection entière pour le
        // coincer). Intensité compensée en conséquence.
        tearLight.attenuationEndDistance = 3.0
        tearLightSource = tearLight
        let tearLightNode = SCNNode()
        tearLightNode.light = tearLight
        tearLightNode.position = SCNVector3(0, 0, -0.03)
        // LE CUBE NOIR N'ÉPARGNE PAS L'IPHONE : le volume de clustering
        // de cette omni est ressorti en CARRÉ NOIR au front de découpe
        // SUR TÉLÉPHONE aussi (screenshot 20-08, en plein arrachage —
        // « sur iPhone elle est saine » était faux). La lèvre de braise
        // du shader porte seule la lueur, partout ; l'omni ne revient
        // qu'au banc, sur demande explicite (`-boosterTearLight`), pour
        // les A/B.
        if CommandLine.arguments.contains("-boosterTearLight") {
            sparkNode.addChildNode(tearLightNode)
        }

        bodyNode.name = "corps"
        capNode.name = "bande"
        moonGlowNode.name = "lune"
        cardNode.name = "carte"
        sparkNode.name = "poudre"
        packNode.addChildNode(bodyNode)
        packNode.addChildNode(capNode)
        packNode.addChildNode(moonGlowNode)
        packNode.addChildNode(cardNode)
        if !CommandLine.arguments.contains("-boosterNoFront") {
            packNode.addChildNode(sparkNode)
        }
        // La vraie face avant du maillage regarde -Z : demi-tour pour la
        // présenter à la caméra. Et le PINCEMENT : l'asset est trapu (0,81),
        // à x·0,75 il retombe au ratio d'un vrai booster (0,60) — échelle
        // choisie pour que le dessin plaqué retrouve EXACTEMENT ses
        // proportions natives (l'étirement d'arc s'annule, croissant rond).
        // Et l'AMINCISSEMENT z·0,45 : le GLB est un sachet de chips gonflé ;
        // il n'abrite qu'UNE carte — le profil doit être une pochette fine,
        // pas un coussin (verdict Kathryn 14-08).
        packNode.eulerAngles.y = .pi
        packNode.scale = SCNVector3(0.75, 1, 0.45)
        packNode.position = SCNVector3(0, -0.02, 0)
        swayNode.name = "berceau"
        swayNode.addChildNode(packNode)
        scene.rootNode.addChildNode(swayNode)

        // ---- l'anneau de la galerie + le sol miroir ----
        var clones: [SCNNode] = []
        for _ in 0 ..< Self.ringCount {
            let group = SCNNode()
            for src in [bodyNode, capNode] {
                let child = SCNNode()
                if let g = src.geometry?.copy() as? SCNGeometry,
                   let m = g.firstMaterial?.copy() as? SCNMaterial {
                    // Les uniformes du clone, SEMÉS (jamais parier sur
                    // ce que copy() emporte des valeurs KVC) : la lune
                    // éteinte, le rim à sa valeur de croisière.
                    m.setValue(0.0 as CGFloat, forKey: "moonCharge")
                    m.setValue(0.55 as CGFloat, forKey: "rimGain")
                    g.materials = [m]
                    child.geometry = g
                }
                group.addChildNode(child)
            }
            group.scale = SCNVector3(0.75, 1, 0.45)
            group.isHidden = true
            scene.rootNode.addChildNode(group)
            clones.append(group)
        }
        galleryPacks = clones

        // Le sol : encre pure, seul le reflet des sachets y vit (la
        // réflexion se compose PAR-DESSUS le diffuse noir), teinté braise,
        // éteint à une hauteur de sachet.
        let floor = SCNFloor()
        floor.reflectivity = 0.11
        floor.reflectionFalloffStart = 0
        floor.reflectionFalloffEnd = 0.42
        floor.reflectionResolutionScaleFactor = 0.4
        let fm = SCNMaterial()
        fm.lightingModel = .constant
        fm.diffuse.contents = UIColor(white: 0.004, alpha: 1)
        fm.multiply.contents = palette.sol
        floor.materials = [fm]
        floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.52, 0)
        floorNode.isHidden = true
        scene.rootNode.addChildNode(floorNode)
        // La nappe d'allumage (l'arrivée royale) : enfant du sol —
        // l'opacity/isHidden de l'engagement l'emportent gratuitement.
        // PILOTÉE PAR placingStep (horloge bornée) et RETOMBE À ZÉRO
        // avant la pose : le manège posé garde son look d'aujourd'hui.
        let glowPlane = SCNPlane(width: 5.2, height: 5.2)
        let gm = SCNMaterial()
        gm.lightingModel = .constant
        gm.diffuse.contents = UIColor.black
        gm.emission.contents = Self.grainDePoudre(robe)
        gm.blendMode = .add
        gm.writesToDepthBuffer = false
        glowPlane.materials = [gm]
        floorGlowNode.geometry = glowPlane
        floorGlowNode.eulerAngles.x = -.pi / 2
        floorGlowNode.position = SCNVector3(0, 0.005, -Self.ringRadius)
        floorGlowNode.opacity = 0
        floorNode.addChildNode(floorGlowNode)

        // ---- caméra + studio ----
        // La galerie regarde à l'OBJECTIF LONG (champ 42°, caméra reculée,
        // le regard Pocket : presque pas de convergence) ; la cérémonie
        // garde son cadrage commité (60° à 2,05).
        let camera = SCNCamera()
        // 0,5 et pas 0,05 : la précision du tampon de profondeur se
        // concentre près de zNear — à 0,05 les deux peaux du sachet
        // aminci (z·0,45) se battaient au pixel, le dessin du recto
        // scintillait à travers le dos (glitch vu par Kathryn au manège).
        // Rien dans la scène ne s'approche à moins de ~1,5 de la caméra.
        camera.zNear = 0.5
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = -0.4
        camera.bloomThreshold = 1.0
        camera.bloomIntensity = 0.55
        camera.bloomBlurRadius = 12
        // z 4,0 à 42° : l'écran étroit d'un téléphone ne montre ~1,3 unité
        // de large — il faut ce recul pour que les voisins de l'anneau
        // dépassent des bords comme chez Pocket.
        camera.fieldOfView = gallery ? 42 : 60
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, gallery ? 4.0 : 2.05)
        scene.rootNode.addChildNode(cameraNode)

        keyLight.type = .directional
        keyLight.intensity = 260
        keyLight.color = palette.cle
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        scene.rootNode.addChildNode(keyNode)

        embers.type = .omni
        embers.intensity = 38 * palette.basEchelle
        embers.color = palette.bas
        embers.attenuationEndDistance = 3
        let emberNode = SCNNode()
        emberNode.light = embers
        emberNode.position = SCNVector3(0, -0.9, 0.7)
        scene.rootNode.addChildNode(emberNode)

        let env = robe == .noire ? Self.hdrStudioNoire : Self.hdrStudio
        scene.lightingEnvironment.contents = env ?? Self.studioEnvironment()
        scene.lightingEnvironment.intensity = 1.0
        // Fond TRANSPARENT (15-08, page profil : le sachet flotte nu sur
        // la page — l'éclairage vient de lightingEnvironment, pas d'ici ;
        // les bancs posent leur propre noir derrière).
        scene.background.contents = UIColor.clear
        print("[booster-bench] lune: geo=\(moonGlowNode.geometry != nil) op=\(moonGlowNode.opacity)")
        print("[booster-bench] scène : mylar=\(mylar) env=\(Self.hdrStudio?.lastPathComponent ?? "FALLBACK 8 bits") emission=\(bodyNode.geometry?.firstMaterial?.emission.intensity ?? -1)")

        if gallery {
            packNode.isHidden = true
            floorNode.isHidden = false
            for p in galleryPacks { p.isHidden = false }
            armGalleryDust()
        } else if !still {
            beginIdleBreath()
        }
    }

    // MARK: le tell servi par la forge

    /// LA SCÈNE APPREND LA RARETÉ (epic/legendary) à l'engagement — la
    /// fente FUIT de la lumière, quelques poussières s'échappent.
    /// Débranché du flag de banc `-boosterShiny` (qui reste l'override
    /// d'atelier). Un seul armement par cérémonie.
    private(set) var tellArme = false

    /// `discret: true` = la scène APPREND la rareté (l'amplitude de la
    /// respiration, le soupir qui re-posera la fuite) mais ne touche à
    /// RIEN maintenant — une réponse forge qui atterrit pendant la
    /// charge ou la découpe ne doit pas écraser les écritures `lipGlow`
    /// du doigt ni relancer des poussières en plein geste.
    func setTell(discret: Bool = false) {
        guard !tellArme else { return }
        tellArme = true
        guard !discret else { return }
        poserShinyLeak()
        sparks.birthRate = 1.2
    }

    /// LA VRAIE CARTE DANS LA SCÈNE : la forge habille la carte
    /// SceneKit AVANT qu'elle soit montrée — sinon l'utilisatrice
    /// regardait carte-lune-1 monter du sachet puis la CarteVivante se
    /// monter avec l'art réel : le swap visible que le gel de la
    /// poignée ne couvrait pas. Jamais après coup : carte visible =
    /// texture figée.
    func habillerCarte(_ art: UIImage) {
        guard cardNode.isHidden else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0
        cardNode.geometry?.firstMaterial?.diffuse.contents = art
        SCNTransaction.commit()
    }

    /// Le fil d'or de la lèvre qui pulse — posé à l'armement, RETIRÉ
    /// pendant la charge et la découpe (le pulse masquerait les
    /// écritures `lipGlow` du doigt), re-posé au soupir si rien n'est
    /// entamé. Idempotent.
    func poserShinyLeak() {
        guard tellArme || Self.shinyTell else { return }
        for node in [bodyNode, capNode] {
            guard let m = node.geometry?.firstMaterial,
                  !m.animationKeys.contains("shinyLeak") else { continue }
            let leak = CABasicAnimation(keyPath: "lipGlow")
            leak.fromValue = 0.10
            leak.toValue = 0.52
            leak.duration = 2.2
            leak.autoreverses = true
            leak.repeatCount = .infinity
            leak.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            m.addAnimation(leak, forKey: "shinyLeak")
        }
    }

    func retirerShinyLeak() {
        for node in [bodyNode, capNode] {
            node.geometry?.firstMaterial?
                .removeAnimation(forKey: "shinyLeak")
        }
    }

    /// Le flottement au repos : une respiration, pas un manège. Appelé à
    /// l'init hors galerie, et à l'arrivée du dolly d'engagement.
    /// IDEMPOTENT : re-poser bob/sway en cours de cycle les ferait
    /// REPARTIR de `fromValue` — un micro-saut à chaque filet.
    func beginIdleBreath() {
        guard !still else { return }
        guard !swayNode.animationKeys.contains("bob") else { return }
        // Sur le BERCEAU, jamais sur le pack : autour de l'identité la
        // décomposition d'euler est stable, l'animation de composante et
        // son blend-out sont sains.
        // Le tell des rares : la respiration s'amplifie (×1,5) — le
        // sachet est habité, la main le sent avant l'œil.
        let amp: Double = (Self.shinyTell || tellArme) ? 1.5 : 1.0
        let bob = CABasicAnimation(keyPath: "position.y")
        bob.fromValue = -0.012 * amp
        bob.toValue = 0.012 * amp
        bob.duration = 2.8
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        swayNode.addAnimation(bob, forKey: "bob")
        let sway = CABasicAnimation(keyPath: "eulerAngles.z")
        sway.fromValue = -0.022 * amp
        sway.toValue = 0.022 * amp
        sway.duration = 3.7
        sway.autoreverses = true
        sway.repeatCount = .infinity
        sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        swayNode.addAnimation(sway, forKey: "sway")
    }

    // MARK: la poudre du manège

    /// LA POUDRE DU MANÈGE — les grains très fins de la vidéo de
    /// l'overlay, portés en scène : un voile qui monte du sol miroir
    /// autour de l'anneau, qui S'ANIME avec la rotation (la traîne du
    /// geste) et souffle une bouffée au cran. GPU pur
    /// (SCNParticleSystem) ; grains émissifs SEULS, jamais une lumière
    /// ajoutée (le cube noir des omni au simulateur).
    private let galleryDust = SCNParticleSystem()
    /// UN POOL de bouffées en rotation : retirer un système d'un nœud
    /// détruit ses particules VIVANTES — avec un système unique, chaque
    /// cran tuait la bouffée du cran précédent, et un scrub normal
    /// (plusieurs crans/s) ne montrait JAMAIS rien.
    private let cranPuffs = (0 ..< 3).map { _ in SCNParticleSystem() }
    private var puffIndex = 0
    private let galleryDustNode = SCNNode()
    private let galleryPuffNode = SCNNode()

    private func armGalleryDust() {
        guard !CommandLine.arguments.contains("-boosterNoDust") else { return }
        let dust = galleryDust
        dust.particleImage = Self.grainDePoudre(robe)
        dust.birthRate = 9
        // Le voile est DÉJÀ là à la première image de l'arrivée (les
        // grains attrapent la première lumière) — jamais un plateau vide.
        dust.warmupDuration = 4.0
        dust.birthLocation = .volume
        dust.emitterShape = SCNTube(innerRadius: 0.85, outerRadius: 1.65,
                                    height: 0.06)
        dust.particleLifeSpan = 5.5
        dust.particleLifeSpanVariation = 2.0
        dust.particleVelocity = 0.045
        dust.particleVelocityVariation = 0.03
        dust.emittingDirection = SCNVector3(0, 1, 0)
        dust.spreadingAngle = 16
        dust.particleSize = 0.006
        dust.particleSizeVariation = 0.0035
        dust.particleColor = palette.poudre.withAlphaComponent(0.28)
        dust.particleColorVariation = SCNVector4(0, 0.03, 0.05, 0.08)
        dust.blendMode = .additive
        dust.isLightingEnabled = false
        galleryDustNode.position = SCNVector3(0, -0.5, -Self.ringRadius)
        galleryDustNode.addParticleSystem(dust)
        scene.rootNode.addChildNode(galleryDustNode)

        // Les bouffées du cran (le pool) — réarmées à la volée par le
        // coordinateur, calées sur l'haptique de détente. VISIBLES :
        // la poudre de la vidéo de l'overlay, pas un soupçon.
        for puff in cranPuffs {
            puff.particleImage = Self.grainDePoudre(robe)
            puff.birthRate = 420
            puff.emissionDuration = 0.12
            puff.loops = false
            puff.birthLocation = .volume
            puff.emitterShape = SCNBox(width: 0.55, height: 0.06,
                                       length: 0.16, chamferRadius: 0)
            puff.particleLifeSpan = 1.3
            puff.particleLifeSpanVariation = 0.45
            puff.particleVelocity = 0.2
            puff.particleVelocityVariation = 0.1
            puff.emittingDirection = SCNVector3(0, 1, 0)
            puff.spreadingAngle = 40
            puff.particleSize = 0.0075
            puff.particleSizeVariation = 0.0035
            puff.particleColor = palette.poudre.withAlphaComponent(0.42)
            puff.blendMode = .additive
            puff.isLightingEnabled = false
        }
        galleryPuffNode.position = SCNVector3(0, -0.5, 0.08)
        scene.rootNode.addChildNode(galleryPuffNode)
    }

    /// 0 = repos (le voile), 1 = rotation pleine — la poudre suit la roue.
    func setGalleryDustDrive(_ v: Float) {
        let k = CGFloat(min(max(v, 0), 1))
        galleryDust.birthRate = 9 + 66 * k
        galleryDust.speedFactor = 1 + 1.4 * k
    }

    /// L'extinction à l'engagement (l'éclatement radial emporte le
    /// voile) ; le retour à l'anneau le rallume.
    func setGalleryDustOn(_ on: Bool) {
        galleryDust.birthRate = on ? 9 : 0
        galleryDust.speedFactor = 1
    }

    /// LE STUDIO DE LA GALERIE : 0 = noir de constellation (seules les
    /// émissions de shader vivent), 1 = les valeurs commitées de l'init
    /// (key 260, embers 38, IBL 1,0) — dim()/celebrate() supposent cet
    /// état EXACT. Piloté par la mise en place, jamais pendant la découpe.
    func setGalleryStudio(_ k: Float) {
        let c = CGFloat(min(max(k, 0), 1))
        keyLight.intensity = 260 * c
        embers.intensity = 38 * c * palette.basEchelle
        scene.lightingEnvironment.intensity = 1.0 * c
    }

    /// L'inspiration de la pose : UNE respiration ample du clone centré.
    /// Échelle ABSOLUE autour de la base 0,75/1/0,45 (le pincement) ;
    /// aucun autre écrivain de scale sur les clones — et une échelle n'a
    /// pas de forme alternative : le piège du lacet π ne s'applique pas.
    func centerBreathIn() {
        let breath = CABasicAnimation(keyPath: "scale")
        breath.fromValue = SCNVector3(0.75, 1.0, 0.45)
        breath.toValue = SCNVector3(0.7725, 1.035, 0.4635)
        breath.duration = 0.55
        breath.autoreverses = true
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        galleryPacks[0].addAnimation(breath, forKey: "poseBreath")
    }

    /// La bouffée du cran qui claque — le pool tourne : on ne réarme
    /// que le plus ancien, dont les grains sont déjà morts.
    func galleryDustPuff() {
        let puff = cranPuffs[puffIndex]
        puffIndex = (puffIndex + 1) % cranPuffs.count
        galleryPuffNode.removeParticleSystem(puff)
        galleryPuffNode.addParticleSystem(puff)
    }

    // MARK: la galerie

    /// L'anneau est un VRAI CERCLE (le manège Pocket) : huit sachets sur
    /// un rayon de 1,4, chacun tourné vers l'EXTÉRIEUR du cercle — devant
    /// on lit la face, et la rangée du fond montre les DOS aux croissants.
    /// Le devant du cercle coïncide avec la place de cérémonie (z 0).
    /// Dix sachets, rayon 1,25 : les voisins ±1 se font couper par les
    /// bords de l'écran (faces de trois-quarts), et la rangée du fond
    /// (±4) montre ses petits DOS dans les interstices — la géographie
    /// exacte de la réf Pocket. (À 1,6 les ±1 sortaient de l'écran d'un
    /// cheveu : mesuré à la capture.)
    static let ringCount = 10
    static let ringRadius: Float = 1.25

    /// L'allumage en cascade de la mise en place : un facteur par sachet,
    /// multiplié à l'émission de l'anneau (1 = plein feu).
    var galleryLight = [Float](repeating: 1, count: BoosterScene.ringCount)

    /// LA CONSTELLATION : la charge de lune par clone, canal shader
    /// moonCharge — les += du modifier ignorent emission.intensity.
    /// 0 = l'état de la galerie posée (aujourd'hui).
    var moonLight = [Float](repeating: 0, count: BoosterScene.ringCount)
    /// Le lit des écritures KVC (gyro 60 Hz × 20 matériaux) : on n'écrit
    /// que le changement. Semé sur les valeurs des clones à la création.
    private var appliedMoon = [CGFloat](repeating: 0,
                                        count: BoosterScene.ringCount)
    private var appliedRim = [CGFloat](repeating: 0.55,
                                       count: BoosterScene.ringCount)

    /// Pose tout l'anneau pour une rotation donnée (cran flottant, sans
    /// butées — un cercle n'en a pas). `centerSpin` : le lacet propre du
    /// sachet central (la pichenette posée) — la pose de l'anneau le
    /// PORTE au lieu de l'écraser : un seul écrivain par pose.
    func applyGallery(offset: Float, centerSpin: Float = 0) {
        let n = Float(Self.ringCount)
        let centre = ((Int(offset.rounded()) % Self.ringCount)
            + Self.ringCount) % Self.ringCount
        for (i, pack) in galleryPacks.enumerated() {
            let theta = (Float(i) - offset) * (2 * .pi / n)
            pack.position = SCNVector3(
                sinf(theta) * Self.ringRadius, -0.02,
                -Self.ringRadius + cosf(theta) * Self.ringRadius)
            // LE TRIPLET ENTIER, jamais une composante : à lacet π (le
            // clone centré), le getter décompose le quaternion sur sa
            // forme alternative au bruit près — 60 écritures/s (gyro) =
            // sachets qui culbutent. Le piège d'e6c0857, porté ici.
            let spin = (i == centre) ? centerSpin : 0
            pack.eulerAngles = SCNVector3(0, .pi + theta + spin, 0)
            // Le feu appartient au sachet qui se présente ; les dos du
            // fond restent lisibles mais éteints.
            let facing = max(cosf(theta), 0)
            pack.opacity = 1
            let moon = CGFloat(moonLight[i])
            let rim = CGFloat(0.55 * galleryLight[i])
            let dirty = moon != appliedMoon[i] || rim != appliedRim[i]
            for child in pack.childNodes {
                let m = child.geometry?.firstMaterial
                m?.emission.intensity =
                    CGFloat((0.08 + 0.52 * facing * facing) * galleryLight[i])
                if dirty {
                    // La lune vit sur son propre canal shader ; le rim
                    // Fresnel est une émission de SHADER hors intensity
                    // (la fuite du vrai noir) — scalé par galleryLight.
                    m?.setValue(moon, forKey: "moonCharge")
                    m?.setValue(rim, forKey: "rimGain")
                }
            }
            if dirty { appliedMoon[i] = moon; appliedRim[i] = rim }
        }
    }

    // MARK: réglages vivants

    /// Le plancher de CHARGE hérité du maintien : quand la déchirure
    /// prend le relais d'un doigt qui a chargé, la lune ne retombe pas.
    var holdChargeFloor: CGFloat = 0

    /// LA CHARGE AU MAINTIEN : le doigt posé sans déchirer — la lune
    /// monte en incandescence, la fente s'éclaire (fil d'or continu),
    /// la braise de scène enfle. c = 0…1 ; le relâcher est le soupir
    /// (la rampe redescend), la déchirure hérite via holdChargeFloor.
    func setHoldCharge(_ c: CGFloat) {
        for node in [bodyNode, capNode] {
            let m = node.geometry?.firstMaterial
            m?.setValue(0.55 * c, forKey: "moonCharge")
            m?.setValue(0.8 * c, forKey: "lipGlow")
        }
        setEmberLights(0.633 + 0.367 * c)
    }

    /// Pose le front de déchirure (monotone) et nourrit les étincelles.
    func setTear(_ progress: Float, sparking: Bool) {
        tearProgress = max(tearProgress, min(progress, 1))
        let u = BoosterShader.u0 + tearProgress * (BoosterShader.u1 - BoosterShader.u0) * 1.03
        for node in [bodyNode, capNode] {
            node.geometry?.firstMaterial?.setValue(CGFloat(u), forKey: "tearU")
            node.geometry?.firstMaterial?.setValue(1.0 as CGFloat, forKey: "tornGlow")
        }
        // Le front en espace modèle : x = (0,5 - s)·largeur, sur la face avant.
        sparkNode.position.x = (0.5 - tearProgress) * 0.78
        setSparking(sparking)
        // La lune se charge avec la progression (et l'invite se tait dès
        // la première morsure) — l'écho sur la surcouche ET la lumière
        // qui se répand.
        for node in [bodyNode, capNode] {
            node.geometry?.firstMaterial?
                .setValue(max(CGFloat(tearProgress), holdChargeFloor),
                          forKey: "moonCharge")
        }
        // Le front allumé sous le doigt, une braise résiduelle sinon.
        tearLightSource?.intensity = sparking
            ? CGFloat(22 + 42 * tearProgress)
            : CGFloat(10 * tearProgress)
        for node in [bodyNode, capNode] {
            node.geometry?.firstMaterial?
                .setValue(0.0 as CGFloat, forKey: "inviteGlow")
        }
    }

    /// Le battement de la lune quand la bande cède : un flash bref qui
    /// retombe à l'incandescence de veille (elle veille jusqu'à la carte).
    func moonPulse() {
        for node in [bodyNode, capNode] {
            guard let m = node.geometry?.firstMaterial else { continue }
            let pulse = CABasicAnimation(keyPath: "moonCharge")
            pulse.fromValue = 2.0
            pulse.toValue = 1.0
            pulse.duration = 0.45
            pulse.timingFunction = CAMediaTimingFunction(name: .easeOut)
            m.addAnimation(pulse, forKey: "moonPulse")
            m.setValue(1.0 as CGFloat, forKey: "moonCharge")
        }
        if let light = tearLightSource {
            let flash = CABasicAnimation(keyPath: "intensity")
            flash.fromValue = 120
            flash.toValue = 10
            flash.duration = 0.5
            flash.timingFunction = CAMediaTimingFunction(name: .easeOut)
            light.addAnimation(flash, forKey: "tearFlash")
            light.intensity = 10
        }
    }

    /// La lueur d'invite : le front fantôme balaie la ligne de découpe
    /// (~0,9 s), s'allume vite, meurt en fin de course.
    func inviteSweep() {
        for node in [bodyNode, capNode] {
            guard let m = node.geometry?.firstMaterial else { continue }
            let sweep = CABasicAnimation(keyPath: "inviteU")
            sweep.fromValue = 0.34
            sweep.toValue = 0.66
            sweep.duration = 0.9
            sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            let glow = CAKeyframeAnimation(keyPath: "inviteGlow")
            glow.values = [0, 1, 1, 0]
            glow.keyTimes = [0, 0.18, 0.72, 1]
            glow.duration = 0.9
            m.addAnimation(sweep, forKey: "inviteSweep")
            m.addAnimation(glow, forKey: "inviteGlow")
        }
    }

    /// Allume ou éteint le front : la poudre de diamant (BEAUCOUP), et
    /// le voile de fumée qui monte du sillage. LE VOILE EST COUPÉ PAR
    /// DÉFAUT (bissection du carré noir, 20-08 : ses quads sombres
    /// alpha 0,10±0,04 unité ont exactement le gabarit du carré vu au
    /// front — si la texture ne module pas sur le GPU du téléphone, le
    /// quad sort en rectangle plein) — `-boosterSmoke` le rallume au
    /// banc pour l'A/B. Bissection poudre : `-boosterNoDust`.
    func setSparking(_ on: Bool) {
        let noDust = CommandLine.arguments.contains("-boosterNoDust")
        let smoke = CommandLine.arguments.contains("-boosterSmoke")
        sparks.birthRate = (on && !noDust) ? 4200 : 0
        accents.birthRate = (on && smoke) ? 26 : 0
        perleNode.isHidden = !on
    }

    /// L'éteignoir de la lèvre, une fois la bande partie.
    func fadeTornGlow(over seconds: TimeInterval) {
        let start = CACurrentMediaTime()
        let action = SCNAction.customAction(duration: seconds) { [weak self] _, _ in
            let t = Float((CACurrentMediaTime() - start) / seconds)
            let g = CGFloat(max(0, 1 - t))
            self?.bodyNode.geometry?.firstMaterial?.setValue(g, forKey: "tornGlow")
        }
        bodyNode.runAction(action)
    }

    /// La pénombre de cérémonie pendant la découpe (le geste Pocket).
    /// SYMÉTRIQUE : la levée restaure l'état INITIAL exact — le bug du
    /// « trop clair en bas » venait d'une levée qui installait un état
    /// plus lumineux (env 1,5 / braise 140) et qui survivait au retour
    /// à l'anneau.
    func dim(_ on: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        scene.lightingEnvironment.intensity = on ? 0.55 : 1.0
        keyLight.intensity = on ? 110 : 260
        embers.intensity = (on ? 60 : 38) * palette.basEchelle
        SCNTransaction.commit()
    }

    /// La lumière qui SALUE — réservée à l'instant où la carte se
    /// présente (l'ancienne « levée » généreuse, à sa vraie place).
    func celebrate() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        scene.lightingEnvironment.intensity = 1.5
        keyLight.intensity = 320
        embers.intensity = 140 * palette.basEchelle
        SCNTransaction.commit()
    }

    /// Les lumières braise de la cérémonie, pilotées par la sortie :
    /// l'omni de scène et la tearLight (téléphone) meurent AVEC le
    /// sachet — sinon elles le repeignent en rouge-orangé pendant la
    /// chute (audit v5). k = 1 pleine braise, 0 éteintes.
    func setEmberLights(_ k: CGFloat) {
        embers.intensity = 60 * k * palette.basEchelle
        tearLightSource?.intensity = 10 * k
    }

    /// La pointe de bloom du flip : attaque brève, décrue douce.
    func bloomSpike() {
        guard let camera = cameraNode.camera else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1
        camera.bloomIntensity = 1.15
        SCNTransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.6
            camera.bloomIntensity = 0.6
            SCNTransaction.commit()
        }
    }

    /// La bande s'ARRACHE en quatre temps : ACCROCHE (le dernier bout
    /// se déchire en rampe, le rouleau se sur-tend et tremble — il
    /// résiste), RUPTURE à 0,42 s (pile le claquement grave cuit dans
    /// `dechirure-finale`), GLISSEMENT en espace monde (reparentage +
    /// bake — le piège du pincement — puis la bande FILE hors cadre en
    /// planant, roulis total ≤ 0,5 rad : le tumble est MORT, la copie
    /// du maillage complet qui culbutait se lisait « le booster
    /// tourne »), et la MORT HORS CADRE (jamais d'évaporation sur
    /// place, jamais d'opacité sur le rouleau double-face).
    /// À appeler AVANT setTear(1) : la rampe part de la valeur vivante
    /// (un saut 0,82→1 téléporterait un demi-tour de rouleau).
    func flyOffCap() {
        guard let capMat = capNode.geometry?.firstMaterial,
              let bodyMat = bodyNode.geometry?.firstMaterial else { return }
        // 1) L'accroche : tearU file au bout en 0,30 s…
        let uEnd = CGFloat(BoosterShader.u0
            + (BoosterShader.u1 - BoosterShader.u0) * 1.03)
        for m in [bodyMat, capMat] {
            let ramp = CABasicAnimation(keyPath: "tearU")
            ramp.fromValue = m.value(forKey: "tearU")
            ramp.toValue = uEnd
            ramp.duration = 0.30
            ramp.timingFunction = CAMediaTimingFunction(name: .easeIn)
            m.addAnimation(ramp, forKey: "tearRamp")
            m.setValue(uEnd, forKey: "tearU")
        }
        // …le rouleau se serre…
        let strain = CABasicAnimation(keyPath: "releaseT")
        strain.fromValue = 0
        strain.toValue = 1
        strain.duration = 0.30
        strain.timingFunction = CAMediaTimingFunction(name: .easeIn)
        capMat.addAnimation(strain, forKey: "strain")
        capMat.setValue(1.0 as CGFloat, forKey: "releaseT")
        // …et tremble en deux rebonds amortis (~5 Hz : lisible même
        // aux 18-36 img/s du simulateur).
        let wobble = CAKeyframeAnimation(keyPath: "rollWobble")
        wobble.values = [0, 0.07, -0.05, 0.025, 0]
        wobble.keyTimes = [0, 0.25, 0.55, 0.8, 1]
        wobble.duration = 0.42
        capMat.addAnimation(wobble, forKey: "wobble")

        // 2) La rupture, puis le vol.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) { [weak self] in
            guard let self else { return }
            // La PRÉSENTATION, pas le modèle : le sachet est en pleine
            // bascule animée — le modèle rendrait la pose finale et la
            // bande se téléporterait.
            let world = self.capNode.presentation.worldTransform
            self.capNode.removeFromParentNode()
            self.scene.rootNode.addChildNode(self.capNode)
            self.capNode.transform = world
            // DEUX TRANSACTIONS CHAÎNÉES, jamais d'animations à
            // fillMode .forwards : à leur frontière la présentation
            // retombait UNE frame sur le modèle — le maillage complet
            // du sachet culbutant sur place (payé à la capture). Avec
            // les transactions, le MODÈLE voyage avec la présentation
            // et finit hors cadre : aucun retour possible.
            let p0 = self.capNode.position
            let e0 = self.capNode.eulerAngles
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.30
            SCNTransaction.animationTimingFunction =
                CAMediaTimingFunction(controlPoints: 0.25, 0.6, 0.6, 1)
            self.capNode.position = SCNVector3(p0.x + 0.45, p0.y + 0.60,
                                               p0.z + 0.35)
            self.capNode.eulerAngles = SCNVector3(e0.x, e0.y, e0.z + 0.22)
            SCNTransaction.completionBlock = { [weak self] in
                guard let self else { return }
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.55
                SCNTransaction.animationTimingFunction =
                    CAMediaTimingFunction(controlPoints: 0.4, 0, 0.9, 0.6)
                self.capNode.position = SCNVector3(p0.x + 1.7, p0.y + 0.95,
                                                   p0.z + 0.70)
                self.capNode.eulerAngles = SCNVector3(e0.x, e0.y, e0.z + 0.5)
                SCNTransaction.completionBlock = { [weak self] in
                    self?.capNode.isHidden = true
                }
                SCNTransaction.commit()
            }
            SCNTransaction.commit()
        }
    }

    // MARK: fabriques

    /// Un réglage de banc : la paire `-boosterX 0.06` arrive par le
    /// domaine d'arguments d'UserDefaults (même circuit que -boosterTear).
    private static func benchValue(_ key: String, _ fallback: CGFloat) -> CGFloat {
        guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
        return CGFloat(UserDefaults.standard.double(forKey: key))
    }

    /// LE CACHE DES TEXTURES — deux robes ne décodent pas deux fois.
    ///
    /// Une `BoosterScene` décode ~36 Mo à chaque construction (color et emiss
    /// en 2048², normal en 1024²), et il s'en construit plusieurs par session :
    /// le four, la porte, le géant du profil, le manège. C'est la dépense
    /// MESURÉE de `WoopApp` (129 ms rendus, « le four réchauffait pour un
    /// convive déjà servi »). Une seconde robe la doublait ; le cache la
    /// paie une fois pour toutes.
    ///
    /// Rien à purger : trois fichiers par robe, et `UIImage` ne garde ici que
    /// le décodé d'images que TOUTE la session réutilise. Sérialisé par le
    /// verrou — `attach` vit sur le fil principal, mais le four cuit, lui,
    /// depuis une file de fond.
    private static let cacheImages = OSAllocatedUnfairLock(
        initialState: [String: UIImage]())

    private static func image(_ name: String) -> UIImage? {
        cacheImages.withLock { cache in
            if let deja = cache[name] { return deja }
            guard let path = Bundle.main.path(forResource: name,
                                              ofType: "png"),
                  let ui = UIImage(contentsOfFile: path) else { return nil }
            cache[name] = ui
            return ui
        }
    }

    /// La POUDRE DE DIAMANT : elle ne jaillit pas, elle COULE — vitesse
    /// quasi nulle, cône serré vers le bas, chute lente, rideau dense de
    /// micro-étoiles blanches à peine dorées. La densité fait le velours,
    /// la lenteur fait le luxe. Longue traîne qui fond.
    private static func makeDiamondFall() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 0
        p.particleLifeSpan = 1.4
        p.particleLifeSpanVariation = 0.4
        p.particleSize = 0.0018
        p.particleSizeVariation = 0.0011
        p.particleVelocity = 0.04
        p.particleVelocityVariation = 0.03
        p.emittingDirection = SCNVector3(0, -0.6, -0.5)
        p.spreadingAngle = 20
        p.acceleration = SCNVector3(0, -0.15, 0)
        p.emitterShape = SCNBox(width: 0.07, height: 0.008, length: 0.008,
                                chamferRadius: 0)
        p.birthLocation = .volume
        // Blanc à peine doré — du diamant qui a quitté le feu.
        p.particleColor = UIColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1)
        p.particleColorVariation = SCNVector4(0.0, 0.03, 0.08, 0)
        p.blendMode = .additive
        p.particleImage = diamondGlint()
        p.isLightingEnabled = false
        // La traîne fond au lieu de mourir sec.
        let fade = CAKeyframeAnimation()
        fade.values = [1.0, 1.0, 0.0]
        fade.keyTimes = [0, 0.55, 1]
        fade.duration = 1.0
        p.propertyControllers = [
            .opacity: SCNParticlePropertyController(animation: fade),
        ]
        return p
    }

    /// Le VOILE DE FUMÉE : une dizaine de volutes par seconde, grosses et
    /// presque invisibles, en fondu alpha (la fumée VOILE, elle n'illumine
    /// pas), qui montent lentement du sillage, tournent et gonflent en se
    /// dissolvant. La mémoire du passage.
    private static func makeSmokeVeil() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 0
        p.particleLifeSpan = 2.6
        p.particleLifeSpanVariation = 0.6
        p.particleSize = 0.10
        p.particleSizeVariation = 0.04
        p.particleVelocity = 0.06
        p.particleVelocityVariation = 0.03
        p.emittingDirection = SCNVector3(0, 1, -0.15)
        p.spreadingAngle = 30
        p.particleAngleVariation = 180
        p.particleAngularVelocity = 18
        p.particleAngularVelocityVariation = 14
        p.particleColor = UIColor(red: 0.42, green: 0.38, blue: 0.34, alpha: 0.55)
        p.blendMode = .alpha
        p.particleImage = smokeWisp()
        p.isLightingEnabled = false
        // Naît de rien, s'installe, se dissout. (Le contrôleur de TAILLE
        // a été retiré : suspect du carré noir — taille fixe.)
        let fade = CAKeyframeAnimation()
        fade.values = [0.0, 1.0, 1.0, 0.0]
        fade.keyTimes = [0, 0.22, 0.55, 1]
        fade.duration = 1.0
        p.propertyControllers = [
            .opacity: SCNParticlePropertyController(animation: fade),
        ]
        return p
    }

    /// La micro-étoile à quatre branches — LA signature diamant : un cœur
    /// vif et quatre aiguilles fines qui fondent.
    private static func diamondGlint() -> UIImage {
        let side = 24.0
        let mid = side / 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let g = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            // les quatre aiguilles
            let armColors = [UIColor.white.withAlphaComponent(0.9).cgColor,
                             UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let arm = CGGradient(colorsSpace: space, colors: armColors,
                                 locations: [0, 1])!
            for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
                g.saveGState()
                g.clip(to: CGRect(x: dx == 0 ? mid - 0.8 : (dx > 0 ? mid : 0),
                                  y: dy == 0 ? mid - 0.8 : (dy > 0 ? mid : 0),
                                  width: dx == 0 ? 1.6 : mid,
                                  height: dy == 0 ? 1.6 : mid))
                g.drawLinearGradient(arm,
                    start: CGPoint(x: mid, y: mid),
                    end: CGPoint(x: mid + dx * mid, y: mid + dy * mid),
                    options: [])
                g.restoreGState()
            }
            // le cœur
            let core = [UIColor.white.cgColor,
                        UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let coreGrad = CGGradient(colorsSpace: space, colors: core,
                                      locations: [0, 1])!
            g.drawRadialGradient(coreGrad,
                startCenter: CGPoint(x: mid, y: mid), startRadius: 0,
                endCenter: CGPoint(x: mid, y: mid), endRadius: 3.2,
                options: [])
        }
    }

    /// Le grain que porte la robe : la perle braise, ou sa sœur blanche.
    private static func grainDePoudre(_ robe: RobeBooster) -> UIImage {
        robe == .noire ? pearlDotBlanche() : pearlDot()
    }

    /// LA MÊME PERLE, SANS SA BRAISE — le grain de la poudre noire.
    /// Un grain additif garde SA couleur quoi qu'on fasse du studio : tant
    /// que son halo est or, la poussière du manège noir rallume en or ce
    /// que les lumières viennent d'éteindre (« la poudre doit être noir et
    /// blanche »). Mêmes rayons, mêmes paliers : seule la teinte tombe.
    private static func pearlDotBlanche() -> UIImage {
        let side = 64.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let colors = [UIColor.white.cgColor,
                          UIColor(white: 1, alpha: 0.75).cgColor,
                          UIColor(white: 0.92, alpha: 0.28).cgColor,
                          UIColor.clear.cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 0.18, 0.45, 1])!
            ctx.cgContext.drawRadialGradient(grad,
                startCenter: CGPoint(x: side / 2, y: side / 2), startRadius: 0,
                endCenter: CGPoint(x: side / 2, y: side / 2), endRadius: side / 2,
                options: [])
        }
    }

    /// La perle : cœur blanc fusion, halo braise généreux — la comète.
    private static func pearlDot() -> UIImage {
        let side = 64.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let colors = [UIColor.white.cgColor,
                          UIColor(red: 1, green: 0.85, blue: 0.55, alpha: 0.75).cgColor,
                          UIColor(red: 1, green: 0.45, blue: 0.12, alpha: 0.28).cgColor,
                          UIColor.clear.cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 0.18, 0.45, 1])!
            ctx.cgContext.drawRadialGradient(grad,
                startCenter: CGPoint(x: side / 2, y: side / 2), startRadius: 0,
                endCenter: CGPoint(x: side / 2, y: side / 2), endRadius: side / 2,
                options: [])
        }
    }

    /// Une volute douce, sans bord — le voile.
    private static func smokeWisp() -> UIImage {
        let side = 64.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let colors = [UIColor.white.withAlphaComponent(0.16).cgColor,
                          UIColor.white.withAlphaComponent(0.06).cgColor,
                          UIColor.clear.cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 0.45, 1])!
            ctx.cgContext.drawRadialGradient(grad,
                startCenter: CGPoint(x: side / 2, y: side / 2), startRadius: 0,
                endCenter: CGPoint(x: side / 2, y: side / 2), endRadius: side / 2,
                options: [])
        }
    }

    /// Le studio HDR : la rampe de barres VERTICALES FINES qui fait les
    /// longues stries de la réf — une barre-clé blanc chaud flanquée de
    /// deux filets (le look « rampe de studio »), une contre-barre froide
    /// à l'opposé, l'horizon braise aminci, la braise au sol.
    ///
    /// POURQUOI EN FLOAT : l'ancien studio passait par
    /// `UIGraphicsImageRenderer` — 8 bits sRGB, plafonné à 1,0. Après
    /// l'exposition (×0,757) les reflets culminaient à ~0,59 : ils ne
    /// POUVAIENT PAS franchir le seuil de bloom (1,0), les stries
    /// sortaient grises. Ici la barre-clé rayonne à 6,0 — les hautes
    /// lumières redeviennent chaudes. Pas d'anisotropie dans SceneKit :
    /// l'étirement vertical des stries vient de la barre HAUTE ET FINE
    /// promenée par la courbure des plis (normal map à 0,8).
    ///
    /// POURQUOI UN FICHIER : une MTLTexture crue donnée à
    /// `lightingEnvironment.contents` est IGNORÉE sans un mot (SceneKit ne
    /// la préfiltre pas — vérifié aux sondes : texture vivante, rendu
    /// inchangé au pixel près). Un fichier Radiance `.hdr` écrit dans les
    /// caches et tendu par URL, lui, est préfiltré comme il faut.
    static let hdrStudio: URL? = makeHDRStudio(robe: .lune)
    /// Le même studio, l'horizon passé à l'améthyste — les barres blanches
    /// ne bougent pas : c'est ce qui donne au foil ses éclats. Cuit à la
    /// PREMIÈRE scène noire (le four de `WoopApp` ne réchauffe que le jaune :
    /// une cuisson est un 1024×512 CPU + une écriture disque).
    static let hdrStudioNoire: URL? = makeHDRStudio(robe: .noire)

    private static func makeHDRStudio(robe: RobeBooster) -> URL? {
        let cal = CommandLine.arguments.contains("-boosterEnvCal")
        print("[booster-bench] makeHDRStudio: envCal=\(cal)")
        let W = 1024, H = 512
        // Tous les feux sont des gaussiennes séparables : un profil en x,
        // un profil en y, le pixel vaut la somme des produits.
        func gaussX(_ center: Float, _ sigma: Float) -> [Float] {
            (0 ..< W).map { x in
                let d = Float(x) - center * Float(W)
                return exp(-d * d / (2 * sigma * sigma))
            }
        }
        func gaussY(_ center: Float, _ sigma: Float) -> [Float] {
            (0 ..< H).map { y in
                let d = Float(y) - center * Float(H)
                return exp(-d * d / (2 * sigma * sigma))
            }
        }
        /// La course verticale d'une barre : pleine entre v0 et v1,
        /// éteinte en douceur sur `cap` pixels aux deux bouts.
        func runY(_ v0: Float, _ v1: Float, _ cap: Float) -> [Float] {
            (0 ..< H).map { y in
                let f = Float(y)
                let a = min(max((f - (v0 * Float(H) - cap)) / (2 * cap), 0), 1)
                let b = min(max(((v1 * Float(H) + cap) - f) / (2 * cap), 0), 1)
                return a * a * (3 - 2 * a) * b * b * (3 - 2 * b)
            }
        }
        struct Glow {
            let gx: [Float]
            let gy: [Float]
            let color: SIMD3<Float>
            let peak: Float
        }
        /// La cuisson : somme des feux sur fond de nuit, encodée RGBE
        /// (Radiance à plat, sans RLE — les lecteurs l'acceptent), posée
        /// dans les caches, rendue par URL.
        func build(_ glows: [Glow], name: String, W: Int, H: Int) -> URL? {
            let base = SIMD3<Float>(0.022, 0.018, 0.016)
            var data = Data(capacity: 64 + W * H * 4)
            data.append(contentsOf: Array("#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n-Y \(H) +X \(W)\n".utf8))
            for y in 0 ..< H {
                for x in 0 ..< W {
                    var c = base
                    for g in glows { c += g.color * (g.peak * g.gx[x] * g.gy[y]) }
                    let m = max(c.x, max(c.y, c.z))
                    if m < 1e-9 {
                        data.append(contentsOf: [0, 0, 0, 0])
                    } else {
                        // m = significand·2^exponent, significand ∈ [1;2) —
                        // replié en f ∈ [0,5;1) : l'échelle RGBE canonique.
                        let e = m.exponent + 1
                        let scale = Float(m.significand) / 2 * 256 / m
                        data.append(contentsOf: [
                            UInt8(min(c.x * scale, 255)),
                            UInt8(min(c.y * scale, 255)),
                            UInt8(min(c.z * scale, 255)),
                            UInt8(clamping: e + 128),
                        ])
                    }
                }
            }
            let url = FileManager.default.urls(for: .cachesDirectory,
                                               in: .userDomainMask)[0]
                .appendingPathComponent(name)
            do {
                try data.write(to: url)
                return url
            } catch {
                print("[booster-bench] écriture .hdr ratée : \(error)")
                return nil
            }
        }
        let white = SIMD3<Float>(1.0, 0.96, 0.90)
        // L'horizon : braise sur le set Lune, améthyste sur le noir (« pas
        // de halo orange… noir un peu violet et blanc »).
        let warm = robe.palette.horizonHDR
        let tall = runY(0.10, 0.78, 40)
        // `-boosterEnvCal` : la mire d'azimut — huit barres de couleurs
        // distinctes à u = i/8. Une capture, et on LIT quelle tranche de
        // l'équirect la face renvoie vers la caméra, au lieu de le deviner
        // barre par barre.
        if CommandLine.arguments.contains("-boosterEnvCal") {
            let mire: [(Float, SIMD3<Float>)] = [
                (0.000, SIMD3<Float>(1, 0, 0)), (0.125, SIMD3<Float>(1, 0.5, 0)),
                (0.250, SIMD3<Float>(1, 1, 0)), (0.375, SIMD3<Float>(0, 1, 0)),
                (0.500, SIMD3<Float>(0, 1, 1)), (0.625, SIMD3<Float>(0.2, 0.3, 1)),
                (0.750, SIMD3<Float>(1, 0, 1)), (0.875, SIMD3<Float>(1, 1, 1)),
            ]
            let run = runY(0.05, 0.95, 20)
            return build(mire.map { Glow(gx: gaussX($0.0, 6), gy: run,
                                         color: $0.1, peak: 4.0) },
                         name: "booster-studio-cal.hdr", W: W, H: H)
        }
        // LA GÉOGRAPHIE (mesurée à la mire `-boosterEnvCal`) : la face posée
        // recto renvoie u ≈ 0,30 vers la caméra. Une barre DANS cet axe
        // allume toute la face en lanterne ; on laisse donc 0,30 dans le
        // noir et on pose les barres à côté — un pli incliné de θ tourne le
        // reflet de 2θ, les plis moyens vont chercher la barre-clé à 0,20,
        // les rails raides la contre-barre à 0,42. La face plate reste encre.
        let glows: [Glow] = [
            // la barre-clé et ses deux filets, la rampe de studio
            Glow(gx: gaussX(0.20, 5), gy: tall, color: white, peak: 8.0),
            Glow(gx: gaussX(0.165, 3), gy: tall, color: white, peak: 2.5),
            Glow(gx: gaussX(0.235, 3), gy: tall, color: white, peak: 2.5),
            // la contre-barre froide, de l'autre côté de l'axe
            Glow(gx: gaussX(0.42, 4), gy: runY(0.15, 0.70, 40),
                 color: SIMD3<Float>(0.80, 0.86, 1.0), peak: 3.0),
            // l'horizon braise, aminci (un blob gras grise le noir)
            Glow(gx: gaussX(0.5, 0.30 * Float(W)), gy: gaussY(0.66, 0.06 * Float(H)),
                 color: warm, peak: robe.palette.horizonForce),
            // la braise au sol, discrète (elle noyait le bas du VERSO,
            // qui n'a pas de lac dessiné pour l'excuser)
            Glow(gx: gaussX(0.5, 0.20 * Float(W)), gy: gaussY(0.97, 0.05 * Float(H)),
                 color: warm, peak: robe.palette.solForce),
        ]
        return build(glows,
                     name: robe == .noire ? "booster-studio-noir.hdr"
                                          : "booster-studio.hdr",
                     W: W, H: H)
    }

    /// L'ancien studio 8 bits, gardé en secours si Metal manque à l'appel.
    private static func studioEnvironment() -> UIImage {
        let W = 512.0, H = 256.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: W, height: H))
        return renderer.image { ctx in
            let g = ctx.cgContext
            UIColor(red: 0.030, green: 0.024, blue: 0.020, alpha: 1).setFill()
            g.fill(CGRect(x: 0, y: 0, width: W, height: H))
            func glow(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double,
                      _ color: UIColor, _ alpha: Double) {
                g.saveGState()
                g.translateBy(x: cx, y: cy)
                g.scaleBy(x: rx / max(ry, 1), y: 1)
                let colors = [color.withAlphaComponent(alpha).cgColor,
                              color.withAlphaComponent(0).cgColor] as CFArray
                let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors, locations: [0, 1])!
                g.drawRadialGradient(grad, startCenter: .zero, startRadius: 0,
                                     endCenter: .zero, endRadius: ry, options: [])
                g.restoreGState()
            }
            // la lame chaude de l'horizon
            glow(W * 0.5, H * 0.66, W * 0.55, H * 0.16,
                 UIColor(red: 1.0, green: 0.45, blue: 0.14, alpha: 1), 0.55)
            // la barre-softbox blanche, haute à gauche
            glow(W * 0.24, H * 0.16, W * 0.20, H * 0.07,
                 UIColor(red: 1.0, green: 0.92, blue: 0.82, alpha: 1), 0.9)
            // l'éclat froid, discret, à droite
            glow(W * 0.82, H * 0.30, W * 0.06, H * 0.16,
                 UIColor(red: 0.75, green: 0.82, blue: 1.0, alpha: 1), 0.5)
            // la braise au sol
            glow(W * 0.5, H * 0.97, W * 0.35, H * 0.10,
                 UIColor(red: 1.0, green: 0.35, blue: 0.10, alpha: 1), 0.4)
        }
    }
}
