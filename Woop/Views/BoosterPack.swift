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
    float3 shN = normalize(_surface.normal);
    float3 shV = normalize(_surface.view);
    float shRim = pow(1.0 - saturate(dot(shN, shV)), 3.5);
    _surface.diffuse.rgb = mix(_surface.diffuse.rgb,
                               max(_surface.diffuse.rgb, float3(0.45)), metalLift);
    _surface.emission.rgb += float3(1.0, 0.98, 0.94) * shRim * rimGain;
    _surface.roughness = _surface.roughness * mix(1.0, 0.55, shRim);
    """

    /// Le corps : muet sous la ligne, lèvre braise sur la tranche ouverte.
    static let body = preamble + """
    if (bv > 0.8896) { discard_fragment(); }
    float lip = smoothstep(0.012, 0.0, 0.8896 - bv);
    float opened = smoothstep(bu, bu + 0.012, tearU);
    _surface.emission.rgb += ember * lip * opened * tornGlow * 2.4;
    """ + sheen

    /// La bande : rongée derrière le front, cœur blanc sur la morsure.
    static let cap = preamble + """
    if (bv < 0.8896) { discard_fragment(); }
    float jag = (fract(sin(bv * 817.7) * 43758.5453) - 0.5) * 0.014;
    float front = tearU + jag;
    if (bu < front) { discard_fragment(); }
    float d = bu - front;
    float burn = smoothstep(0.020, 0.0, d);
    _surface.emission.rgb += (ember * 2.2 + float3(1.0, 0.85, 0.6) * burn) * burn * tornGlow;
    """ + sheen
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
    let bodyNode: SCNNode
    let capNode: SCNNode
    let cardNode: SCNNode
    let sparks: SCNParticleSystem
    let sparkNode = SCNNode()
    let cameraNode = SCNNode()
    let yTear: Float
    private let keyLight = SCNLight()
    private let embers = SCNLight()

    /// La progression de déchirure, 0…1, monotone (on ne recolle pas).
    private(set) var tearProgress: Float = 0

    init?(still: Bool, mylar: Bool = false) {
        guard let mesh = BoosterBin.load() else { return nil }
        yTear = mesh.yTear

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
        func material(modifier: String) -> SCNMaterial {
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
            m.shaderModifiers = [.surface: modifier]
            m.setValue(0.0 as CGFloat, forKey: "tearU")
            m.setValue(0.0 as CGFloat, forKey: "tornGlow")
            m.setValue(0.55 as CGFloat, forKey: "rimGain")
            m.setValue((mylar ? 1.0 : 0.0) as CGFloat, forKey: "metalLift")
            return m
        }
        bodyNode = SCNNode(geometry: mesh.geometry.copy() as? SCNGeometry)
        bodyNode.geometry?.materials = [material(modifier: BoosterShader.body)]
        capNode = SCNNode(geometry: mesh.geometry.copy() as? SCNGeometry)
        capNode.geometry?.materials = [material(modifier: BoosterShader.cap)]

        // ---- la carte récompense, endormie dans le sachet ----
        // Placeholder du chantier cartes : la carte-lune détourée, à plat.
        let plane = SCNPlane(width: 0.60, height: 0.60 * 1.519)
        let cm = SCNMaterial()
        cm.lightingModel = .constant
        cm.diffuse.contents = Self.image("booster-carte")
        cm.emission.contents = Self.image("booster-carte")
        cm.emission.intensity = 0
        cm.isDoubleSided = true
        plane.materials = [cm]
        cardNode = SCNNode(geometry: plane)
        cardNode.position = SCNVector3(0, -0.035, 0)
        cardNode.eulerAngles.y = .pi

        // ---- les étincelles du front de déchirure ----
        sparks = Self.makeSparks()
        sparkNode.addParticleSystem(sparks)
        sparkNode.position = SCNVector3(0, yTear + 0.01, -0.07)

        packNode.addChildNode(bodyNode)
        packNode.addChildNode(capNode)
        packNode.addChildNode(cardNode)
        packNode.addChildNode(sparkNode)
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
        scene.rootNode.addChildNode(packNode)

        // ---- caméra + studio ----
        let camera = SCNCamera()
        camera.zNear = 0.05
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = -0.4
        camera.bloomThreshold = 1.0
        camera.bloomIntensity = 0.55
        camera.bloomBlurRadius = 12
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 2.05)
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
        scene.background.contents = UIColor.black
        print("[booster-bench] scène : mylar=\(mylar) env=\(Self.hdrStudio?.lastPathComponent ?? "FALLBACK 8 bits") emission=\(bodyNode.geometry?.firstMaterial?.emission.intensity ?? -1)")

        if !still {
            // Le flottement au repos : une respiration, pas un manège.
            let bob = CABasicAnimation(keyPath: "position.y")
            bob.fromValue = -0.032
            bob.toValue = -0.008
            bob.duration = 2.8
            bob.autoreverses = true
            bob.repeatCount = .infinity
            bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            packNode.addAnimation(bob, forKey: "bob")
            let sway = CABasicAnimation(keyPath: "eulerAngles.z")
            sway.fromValue = -0.022
            sway.toValue = 0.022
            sway.duration = 3.7
            sway.autoreverses = true
            sway.repeatCount = .infinity
            sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            packNode.addAnimation(sway, forKey: "sway")
        }
    }

    // MARK: réglages vivants

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
        sparks.birthRate = sparking ? 520 : 0
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
    func dim(_ on: Bool) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.4
        scene.lightingEnvironment.intensity = on ? 0.55 : 1.5
        keyLight.intensity = on ? 110 : 320
        embers.intensity = on ? 60 : 140
        SCNTransaction.commit()
    }

    // MARK: fabriques

    private static func image(_ name: String) -> UIImage? {
        guard let path = Bundle.main.path(forResource: name, ofType: "png") else { return nil }
        return UIImage(contentsOfFile: path)
    }

    private static func makeSparks() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.birthRate = 0
        p.particleLifeSpan = 0.42
        p.particleLifeSpanVariation = 0.18
        p.particleSize = 0.011
        p.particleSizeVariation = 0.006
        p.particleVelocity = 0.34
        p.particleVelocityVariation = 0.22
        p.emittingDirection = SCNVector3(0, 0.6, -1)
        p.spreadingAngle = 55
        p.acceleration = SCNVector3(0, -0.6, 0)
        p.particleColor = UIColor(red: 1.0, green: 0.72, blue: 0.35, alpha: 1)
        p.particleColorVariation = SCNVector4(0.06, 0.1, 0.05, 0)
        p.blendMode = .additive
        p.particleImage = sparkDot()
        p.isLightingEnabled = false
        return p
    }

    /// Un point braise doux, dessiné à la main — pas d'asset.
    private static func sparkDot() -> UIImage {
        let side = 32.0
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        return renderer.image { ctx in
            let colors = [UIColor.white.withAlphaComponent(0.95).cgColor,
                          UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.5).cgColor,
                          UIColor.clear.cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: colors, locations: [0, 0.35, 1])!
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
