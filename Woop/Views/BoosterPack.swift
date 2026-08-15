import SceneKit
import SwiftUI

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
    private let still: Bool
    private let keyLight = SCNLight()
    private let embers = SCNLight()

    /// La progression de déchirure, 0…1, monotone (on ne recolle pas).
    private(set) var tearProgress: Float = 0

    init?(still: Bool, mylar: Bool = false, gallery: Bool = false) {
        guard let mesh = BoosterBin.load() else { return nil }
        yTear = mesh.yTear
        self.still = still

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
            m.diffuse.contents = Self.image("booster-color")
            m.emission.contents = Self.image("booster-emiss")
            // 0,6 : la recette VALIDÉE. Le piège de la lanterne a été payé
            // DEUX fois maintenant : à 1,9, les nappes douces de la carte
            // emiss (lac, halo du croissant) font du sachet un verre ambré.
            // Les néons n'ont pas besoin de bloomer — ils sont dessinés.
            m.emission.intensity = 0.6
            m.normal.contents = Self.image("booster-normal")
            m.normal.intensity = 0.8
            if mylar {
                m.metalness.contents = 1.0
                m.roughness.contents = 0.14
                m.clearCoat.contents = 0.5
                m.clearCoatRoughness.contents = 0.10
            } else {
                m.metalness.contents = 0.0
                m.roughness.contents = 0.35
                m.clearCoat.contents = 1.0
                m.clearCoatRoughness.contents = 0.04
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
            m.setValue((mylar ? 1.0 : 0.0) as CGFloat, forKey: "metalLift")
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
        if Self.shinyTell {
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
        // PIÈGE SIMULATEUR : le GPU paravirtualisé rend le volume de
        // clustering de cette omni en CUBE NOIR collé au front (une
        // bissection entière pour le coincer — ni particules, ni carte,
        // ni surcouche : la LUMIÈRE). Sur iPhone elle est saine ; au
        // banc simulé, la lèvre de braise du shader porte seule la lueur.
        #if !targetEnvironment(simulator)
        if !CommandLine.arguments.contains("-boosterNoTearLight") {
            sparkNode.addChildNode(tearLightNode)
        }
        #endif

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
        fm.multiply.contents = UIColor(red: 1.0, green: 0.80, blue: 0.65, alpha: 1)
        floor.materials = [fm]
        floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, -0.52, 0)
        floorNode.isHidden = true
        scene.rootNode.addChildNode(floorNode)

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
        keyLight.color = UIColor(red: 1.0, green: 0.93, blue: 0.85, alpha: 1)
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        scene.rootNode.addChildNode(keyNode)

        embers.type = .omni
        embers.intensity = 38
        embers.color = UIColor(red: 1.0, green: 0.45, blue: 0.15, alpha: 1)
        embers.attenuationEndDistance = 3
        let emberNode = SCNNode()
        emberNode.light = embers
        emberNode.position = SCNVector3(0, -0.9, 0.7)
        scene.rootNode.addChildNode(emberNode)

        scene.lightingEnvironment.contents = Self.hdrStudio ?? Self.studioEnvironment()
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
        } else if !still {
            beginIdleBreath()
        }
    }

    /// Le flottement au repos : une respiration, pas un manège. Appelé à
    /// l'init hors galerie, et à l'arrivée du dolly d'engagement.
    func beginIdleBreath() {
        guard !still else { return }
        // Sur le BERCEAU, jamais sur le pack : autour de l'identité la
        // décomposition d'euler est stable, l'animation de composante et
        // son blend-out sont sains.
        // Le tell des rares : la respiration s'amplifie (×1,5) — le
        // sachet est habité, la main le sent avant l'œil.
        let amp: Double = Self.shinyTell ? 1.5 : 1.0
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

    /// Pose tout l'anneau pour une rotation donnée (cran flottant, sans
    /// butées — un cercle n'en a pas).
    func applyGallery(offset: Float) {
        let n = Float(Self.ringCount)
        for (i, pack) in galleryPacks.enumerated() {
            let theta = (Float(i) - offset) * (2 * .pi / n)
            pack.position = SCNVector3(
                sinf(theta) * Self.ringRadius, -0.02,
                -Self.ringRadius + cosf(theta) * Self.ringRadius)
            pack.eulerAngles.y = .pi + theta
            // Le feu appartient au sachet qui se présente ; les dos du
            // fond restent lisibles mais éteints.
            let facing = max(cosf(theta), 0)
            pack.opacity = 1
            for child in pack.childNodes {
                child.geometry?.firstMaterial?.emission.intensity =
                    CGFloat((0.08 + 0.52 * facing * facing) * galleryLight[i])
            }
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
    /// le voile de fumée qui monte du sillage. Interrupteurs de bissection
    /// au banc : `-boosterNoDust` / `-boosterNoSmoke`.
    func setSparking(_ on: Bool) {
        let noDust = CommandLine.arguments.contains("-boosterNoDust")
        let noSmoke = CommandLine.arguments.contains("-boosterNoSmoke")
        sparks.birthRate = (on && !noDust) ? 4200 : 0
        accents.birthRate = (on && !noSmoke) ? 26 : 0
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
        embers.intensity = on ? 60 : 38
        SCNTransaction.commit()
    }

    /// La lumière qui SALUE — réservée à l'instant où la carte se
    /// présente (l'ancienne « levée » généreuse, à sa vraie place).
    func celebrate() {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        scene.lightingEnvironment.intensity = 1.5
        keyLight.intensity = 320
        embers.intensity = 140
        SCNTransaction.commit()
    }

    /// Les lumières braise de la cérémonie, pilotées par la sortie :
    /// l'omni de scène et la tearLight (téléphone) meurent AVEC le
    /// sachet — sinon elles le repeignent en rouge-orangé pendant la
    /// chute (audit v5). k = 1 pleine braise, 0 éteintes.
    func setEmberLights(_ k: CGFloat) {
        embers.intensity = 60 * k
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

    private static func image(_ name: String) -> UIImage? {
        guard let path = Bundle.main.path(forResource: name, ofType: "png") else { return nil }
        return UIImage(contentsOfFile: path)
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
    static let hdrStudio: URL? = makeHDRStudio()

    private static func makeHDRStudio() -> URL? {
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
        let warm = SIMD3<Float>(1.0, 0.45, 0.14)
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
                 color: warm, peak: 0.4),
            // la braise au sol, discrète (elle noyait le bas du VERSO,
            // qui n'a pas de lac dessiné pour l'excuser)
            Glow(gx: gaussX(0.5, 0.20 * Float(W)), gy: gaussY(0.97, 0.05 * Float(H)),
                 color: warm, peak: 0.12),
        ]
        return build(glows, name: "booster-studio.hdr", W: W, H: H)
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
