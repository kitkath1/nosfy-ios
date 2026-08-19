import SwiftUI
import SceneKit

// MARK: - Le carnet en VRAIE 3D (`-carnetLab -carnetScene`)

/// L'HYBRIDE SceneKit — le plan acté du dossier de passation
/// (tools/carnet/CHANTIER.md) : les POSES restent des plaques SwiftUI, le
/// MOUVEMENT passe en vraie 3D, au métier du booster. Ce banc porte le
/// moteur de tourne : le livre ouvert est la PLAQUE PHOTO portée en
/// texture (on ne fabrique jamais le papier — loi payée deux fois), la
/// feuille tournante est un vrai maillage subdivisé plié par un
/// modificateur de GÉOMÉTRIE (le pli développable à charnière reculante,
/// cousin du peeling du booster), et les trois choses qu'aucun shader 2D
/// n'a su donner sont VRAIES ici : la silhouette perspective de la
/// feuille, l'ombre portée SceneKit qui balaie le papier, l'éclairage par
/// les normales réelles.
///
/// LA LOI DE LA MATIÈRE : tout est lambert CALIBRÉ — ambiant + clé×cosθ
/// = 1,0 exactement pour une surface à plat. La photo rend à sa luminance
/// au repos (zéro couture aux poses, par construction) ; la lumière ne se
/// voit que quand la géométrie PLIE. Le pli n'invente rien : il incline
/// les mêmes pixels sous la même lumière.
///
/// Pièges booster respectés : zNear 0,5 (jamais 0,05), fond .clear,
/// uniformes KVC au nom EXACT du `#pragma arguments` (un nom qui boite =
/// zéro silencieux), pas d'euler au lacet π, et 18-36 img/s AU SIMULATEUR
/// — le juge de la fluidité est le téléphone.
enum CarnetScene3D {
    // ---- les mesures, en unité scène = hauteur du cadre (881 px) ----
    // Tout vient de la sonde mesure_fenetres.py : cadre de la plaque
    // ouverte (146, 90, 1166 × 881), papier de la page droite en px
    // source (736, 102, 519 × 857), centre objet = centre cadre.
    static let bedW: CGFloat = 1166.0 / 881.0
    static let sheetW = Float(519.0 / 881.0)
    static let sheetH = Float(857.0 / 881.0)
    /// La gouttière : bord gauche de la feuille, à +7 px du centre cadre.
    static let sheetX = Float(7.0 / 881.0)
    /// L'axe de la lumière-clé (espace monde = espace vue, caméra
    /// frontale) : haut-droit, RASANT — la leçon de la première sonde
    /// d'ombre : une clé trop frontale (z 0,755) jette l'ombre DERRIÈRE
    /// la feuille, pile là où la feuille la cache. Rasante, l'ombre se
    /// décale à gauche de la lame, sur le papier — l'ombre V3 validée
    /// (« décalée par la lumière haut-droit »), mais VRAIE cette fois.
    /// La calibration est indifférente à l'axe (le lambert renormalise
    /// par cosθ = keyDir.z) : molettes libres, zéro couture aux poses.
    /// Défauts SONDES (v3, 19-08) : Ly bas — à 0,50 l'ombre de la lame
    /// atterrissait SOUS la page (0,32 unité de chute), invisible.
    static let keyDir = simd_normalize(SIMD3<Float>(
        Float(molette("carnetKeyX", 0.55)),
        Float(molette("carnetKeyY", 0.22)),
        Float(molette("carnetKeyZ", 0.65))))

    /// Les molettes du banc (`-carnetCurlR 0.2` → UserDefaults).
    static func molette(_ key: String, _ def: Double) -> Double {
        guard let raw = UserDefaults.standard.string(forKey: key),
              let v = Double(raw) else { return def }
        return v
    }

    // MARK: le pli développable à charnière reculante

    /// LE MOTEUR : la charnière verticale recule (A = w·(1−q)) pendant que
    /// le segment libre tourne de α = π·q — l'atterrissage miroir est
    /// garanti par construction (le modèle V2, prouvé aux sondes). Le pli
    /// n'est pas une arête : un congé cylindrique de rayon r (arc r·α)
    /// la remplace — r respire en sin(πq) et meurt aux poses, la feuille
    /// se pose PLATE. Le cône du jury : la charnière penche avec y
    /// (skewK), le bas mène, ancré à la reliure. Normales ET tangentes
    /// tournées à la main — sans elles, l'éclairage reste plat (le piège
    /// payé du booster).
    static let geometryModifier = """
    #pragma arguments
    float qTurn;
    float curlR0;
    float sheetWu;
    float skewK;
    #pragma body
    float q = clamp(qTurn, 0.0, 1.0);
    float x = _geometry.position.x;
    float yn = _geometry.position.y;
    float alpha = 3.14159265 * q;
    float A = max(sheetWu * (1.0 - q) + skewK * yn * sin(alpha), 0.0);
    float r = max(curlR0 * sin(alpha), 0.0025);
    float dm = x - A;
    if (dm > 0.0) {
        float arc = r * alpha;
        float phi;
        float px;
        float pz;
        if (dm <= arc) {
            phi = dm / r;
            px = A + r * sin(phi);
            pz = r * (1.0 - cos(phi));
        } else {
            phi = alpha;
            float t = dm - arc;
            px = A + r * sin(alpha) + t * cos(alpha);
            pz = r * (1.0 - cos(alpha)) + t * sin(alpha);
        }
        _geometry.position.x = px;
        _geometry.position.z += pz;
        float c = cos(phi);
        float s = sin(phi);
        float nx = _geometry.normal.x;
        float nz = _geometry.normal.z;
        _geometry.normal.x = nx * c - nz * s;
        _geometry.normal.z = nx * s + nz * c;
        float tx = _geometry.tangent.x;
        float tz = _geometry.tangent.z;
        _geometry.tangent.x = tx * c - tz * s;
        _geometry.tangent.z = tx * s + tz * c;
    }
    """

    /// L'OR DE LA TRANCHE LIBRE — le bijou de la V4, gardé : un fil d'or
    /// permanent au bord libre de la feuille, qui FLARE au rasant (quand
    /// la tranche passe face caméra). En émission : il vit au-dessus du
    /// lambert, insensible à l'ombre — l'or fuit de la lumière.
    static let surfaceModifier = """
    #pragma arguments
    float goldGlow;
    float goldEdgeU;
    #pragma body
    float du = abs(_surface.diffuseTexcoord.x - goldEdgeU);
    float band = exp(-pow(du / 0.005, 2.0));
    float3 gN = normalize(_surface.normal);
    float3 gV = normalize(_surface.view);
    float graze = pow(1.0 - abs(dot(gN, gV)), 2.0);
    _surface.emission.rgb += float3(1.0, 0.72, 0.30) * band * goldGlow
        * (0.20 + 1.6 * graze);
    """

    // MARK: le maillage de la feuille — deux peaux, comme le sachet

    /// Recto et verso sont DEUX maillages coïncidents aux enroulements
    /// opposés (winding + normales), chacun sa matière : le recto porte le
    /// papier + le contenu, le verso le papier NU en miroir (uv.x
    /// inversée — le puits de gouttière tombe du bon côté tout seul, et
    /// un grain de papier n'a pas de sens de lecture). Le même
    /// modificateur de géométrie les plie d'un seul geste.
    static func sheetMesh(verso: Bool) -> SCNGeometry {
        let nx = 160, ny = 24
        var pos: [Float] = []
        var nor: [Float] = []
        var tan: [Float] = []
        var uv: [Float] = []
        for j in 0 ... ny {
            for i in 0 ... nx {
                let fx = Float(i) / Float(nx)
                let fy = Float(j) / Float(ny)
                pos += [fx * sheetW, (fy - 0.5) * sheetH, 0]
                nor += [0, 0, verso ? -1 : 1]
                tan += [1, 0, 0, 1]
                uv += [verso ? 1 - fx : fx, 1 - fy]
            }
        }
        var idx: [UInt32] = []
        for j in 0 ..< ny {
            for i in 0 ..< nx {
                let a = UInt32(j * (nx + 1) + i)
                let b = a + 1
                let c = a + UInt32(nx + 1)
                let d = c + 1
                if verso {
                    idx += [a, d, b, a, c, d]
                } else {
                    idx += [a, b, d, a, d, c]
                }
            }
        }
        let nV = pos.count / 3
        func source(_ v: [Float], _ sem: SCNGeometrySource.Semantic,
                    _ comps: Int) -> SCNGeometrySource {
            SCNGeometrySource(
                data: v.withUnsafeBufferPointer { Data(buffer: $0) },
                semantic: sem, vectorCount: nV, usesFloatComponents: true,
                componentsPerVector: comps, bytesPerComponent: 4,
                dataOffset: 0, dataStride: comps * 4)
        }
        let element = SCNGeometryElement(
            data: idx.withUnsafeBufferPointer { Data(buffer: $0) },
            primitiveType: .triangles, primitiveCount: idx.count / 3,
            bytesPerIndex: 4)
        return SCNGeometry(sources: [source(pos, .vertex, 3),
                                     source(nor, .normal, 3),
                                     source(tan, .tangent, 4),
                                     source(uv, .texcoord, 2)],
                           elements: [element])
    }

    // MARK: les textures — les pixels de la plaque, jamais autre chose

    private static func sourcePlaque() -> CGImage? {
        guard let chemin = Bundle.main.path(forResource: "carnet-ouvert",
                                            ofType: "png"),
              let brute = UIImage(contentsOfFile: chemin) else { return nil }
        return brute.cgImage
    }

    /// Le contenu d'une page, rendu UNE fois en image (la partition
    /// validée fe7920d) — à l'échelle native du papier (519 px pour
    /// 150,14 pt de fenêtre).
    @MainActor
    private static func contenu(date: String, mesures: String,
                                sticker: String, pieces: Int) -> UIImage? {
        let r = ImageRenderer(content: PageSession(
            date: date, mesures: mesures, sticker: sticker, pieces: pieces)
            .frame(width: 150.14, height: 246.81))
        r.scale = 519.0 / 150.14
        r.isOpaque = false
        return r.uiImage
    }

    /// Le LIT : le cadre entier de la plaque ouverte, avec la session
    /// suivante déjà posée NUE dans la fenêtre papier de droite (c'est
    /// elle que la tourne révèle).
    @MainActor
    static func bedTexture() -> UIImage? {
        guard let src = sourcePlaque(),
              let cadre = src.cropping(to: CGRect(x: 146, y: 90,
                                                  width: 1166, height: 881))
        else { return nil }
        let taille = CGSize(width: 1166, height: 881)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: taille, format: format)
            .image { _ in
                UIImage(cgImage: cadre).draw(
                    in: CGRect(origin: .zero, size: taille))
                contenu(date: "16. Août", mesures: "4 séries · 48 reps",
                        sticker: "sticker-bras", pieces: 80)?
                    .draw(in: CGRect(x: 590, y: 12, width: 519, height: 857))
            }
    }

    /// Une peau de feuille : le papier de la plaque (crop 736, 102,
    /// 519 × 857 — celui de PapierPage), coins arrondis côté tranche en
    /// ALPHA (le papier de la plaque est arrondi, un coin carré qui vole
    /// se voit), et le contenu de la session courante sur le recto.
    @MainActor
    static func sheetTexture(avecContenu: Bool) -> UIImage? {
        guard let src = sourcePlaque(),
              let papier = src.cropping(to: CGRect(x: 736, y: 102,
                                                   width: 519, height: 857))
        else { return nil }
        let taille = CGSize(width: 519, height: 857)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: taille, format: format)
            .image { _ in
                UIBezierPath(
                    roundedRect: CGRect(origin: .zero, size: taille),
                    byRoundingCorners: [.topRight, .bottomRight],
                    cornerRadii: CGSize(width: 34, height: 34)).addClip()
                UIImage(cgImage: papier).draw(
                    in: CGRect(origin: .zero, size: taille))
                if avecContenu {
                    contenu(date: "18. Août", mesures: "5 séries · 60 reps",
                            sticker: "sticker-flamme", pieces: 100)?
                        .draw(in: CGRect(origin: .zero, size: taille))
                }
            }
    }
}

// MARK: - La scène

/// Le montage : lit lambert (la plaque, éclairée à 1,0 pile), feuille à
/// deux peaux au-dessus, une clé directionnelle qui CALIBRE et OMBRE à la
/// fois, un ambiant qui donne le plancher. Caméra frontale, objectif
/// long — le regard de la plaque (photo produit, presque orthographique).
final class CarnetSceneMoteur {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    /// Les deux matières de la feuille — c'est ELLES qu'on pilote (qTurn
    /// par KVC, le nom répond au `#pragma arguments` exactement).
    let feuilleMats: [SCNMaterial]

    @MainActor
    init() {
        let m = CarnetScene3D.self

        // ---- l'éclairage calibré : ambiant + clé·cosθ = 1 à plat ----
        // cosθ de la clé sur une surface face caméra = keyDir.z (0,755).
        let ambientK = CGFloat(m.molette("carnetAmbient", 0.30))
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 1000 * ambientK
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 1000 * (1 - ambientK) / CGFloat(m.keyDir.z)
        key.castsShadow = true
        // L'ombre LARGE et FRANCHE (sondes v3) : sur un papier à 20-30
        // niveaux, une ombre fine ou timide n'existe pas — la loi de
        // l'autopsie V1 (le multiplicatif sur base sombre s'efface).
        key.shadowColor = UIColor(white: 0,
                                  alpha: m.molette("carnetShadowA", 0.65))
        key.shadowRadius = m.molette("carnetShadowR", 14)
        key.shadowSampleCount = 8
        key.shadowMapSize = CGSize(width: 2048, height: 2048)
        let keyNode = SCNNode()
        keyNode.light = key
        // La lumière voyage à CONTRESENS de keyDir (elle vient du
        // haut-droit-devant) : on tourne son −z vers −keyDir.
        keyNode.simdOrientation = simd_quatf(from: SIMD3<Float>(0, 0, -1),
                                             to: -m.keyDir)
        scene.rootNode.addChildNode(keyNode)

        // ---- le lit : la plaque photo, session suivante incluse ----
        let bed = SCNPlane(width: m.bedW, height: 1.0)
        let bedMat = SCNMaterial()
        bedMat.lightingModel = .lambert
        // Une plaque manquante se VOIT (jamais un noir menteur).
        bedMat.diffuse.contents = m.bedTexture() ?? UIColor.red
        bedMat.diffuse.wrapS = .clamp
        bedMat.diffuse.wrapT = .clamp
        bed.materials = [bedMat]
        let bedNode = SCNNode(geometry: bed)
        bedNode.castsShadow = false
        scene.rootNode.addChildNode(bedNode)

        // ---- la feuille : deux peaux, un seul pli ----
        func peau(verso: Bool) -> (SCNNode, SCNMaterial) {
            let mat = SCNMaterial()
            mat.lightingModel = .lambert
            mat.diffuse.contents = m.sheetTexture(avecContenu: !verso)
                ?? UIColor.red
            mat.diffuse.wrapS = .clamp
            mat.diffuse.wrapT = .clamp
            mat.shaderModifiers = [.geometry: m.geometryModifier,
                                   .surface: m.surfaceModifier]
            mat.setValue(0.0 as CGFloat, forKey: "qTurn")
            mat.setValue(CGFloat(m.molette("carnetCurlR", 0.16)),
                         forKey: "curlR0")
            mat.setValue(CGFloat(m.sheetW), forKey: "sheetWu")
            mat.setValue(CGFloat(m.molette("carnetSkew", 0.08)),
                         forKey: "skewK")
            mat.setValue(CGFloat(m.molette("carnetGold", 0.8)),
                         forKey: "goldGlow")
            // Le bord libre : u=1 au recto, u=0 au verso (uv en miroir).
            mat.setValue(CGFloat(verso ? 0.0 : 1.0), forKey: "goldEdgeU")
            let node = SCNNode(geometry: m.sheetMesh(verso: verso))
            node.geometry?.materials = [mat]
            return (node, mat)
        }
        let (recto, rectoMat) = peau(verso: false)
        let (dos, dosMat) = peau(verso: true)
        feuilleMats = [rectoMat, dosMat]
        let feuille = SCNNode()
        feuille.addChildNode(recto)
        feuille.addChildNode(dos)
        // Épinglée à la gouttière, un souffle au-dessus du lit — le
        // congé minimal (2r = 0,005) laisse la page posée porter sa
        // fine ombre de contact, celle qui « pince » (le verdict V4).
        feuille.position = SCNVector3(m.sheetX, 0, 0.002)
        scene.rootNode.addChildNode(feuille)

        // ---- la caméra : frontale, longue focale, zNear 0,5 ----
        let camera = SCNCamera()
        camera.zNear = 0.5
        camera.fieldOfView = m.molette("carnetFov", 26)
        camera.projectionDirection = .horizontal
        camera.wantsHDR = false
        cameraNode.camera = camera
        // 3,43 : mesuré au raccord — à 3,52 l'objet 3D rendait 962 px
        // d'arêtes dures contre 988 au banc SwiftUI (2,7 % trop petit,
        // largeur ∝ 1/D). Centres déjà alignés (603/601).
        cameraNode.position = SCNVector3(0, 0, m.molette("carnetCamD", 3.43))
        scene.rootNode.addChildNode(cameraNode)

        scene.background.contents = UIColor.clear
    }

    /// La tourne, posée d'un coup (drag en cours, ou pose figée).
    func setQ(_ v: Float) {
        for mat in feuilleMats {
            mat.removeAnimation(forKey: "tourne")
            mat.setValue(CGFloat(v), forKey: "qTurn")
        }
    }

    /// L'aimant : la tourne finit toujours posée, au ressort du banc
    /// feuille (response 0,5, damping 0,86) — via CASpringAnimation sur
    /// l'uniforme (le précédent payé : lipGlow du booster).
    func springQ(from current: Float, to target: Float) {
        for mat in feuilleMats {
            mat.setValue(CGFloat(target), forKey: "qTurn")
            let a = CASpringAnimation(keyPath: "qTurn")
            a.fromValue = current
            a.toValue = target
            a.stiffness = 158
            a.damping = 21.6
            a.mass = 1
            a.duration = a.settlingDuration
            mat.addAnimation(a, forKey: "tourne")
        }
    }
}

// MARK: - Le banc

/// L'hôte SCNView : drag horizontal = la tourne sous le doigt, lâcher =
/// aimant sur l'élan prédit, tap = tourne complète (aller-retour). Le
/// fond est .clear — le banc pose son noir derrière (le pattern booster).
struct CarnetSceneStage: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.rendersContinuously = true
        let moteur = CarnetSceneMoteur()
        view.scene = moteur.scene
        view.pointOfView = moteur.cameraNode
        context.coordinator.moteur = moteur

        // `-carnetQ <q>` fige la tourne (les captures ont besoin d'états
        // connus — le simulateur n'a pas de doigt).
        if let raw = UserDefaults.standard.string(forKey: "carnetQ"),
           let v = Double(raw) {
            moteur.setQ(Float(v))
            context.coordinator.q = Float(v)
            context.coordinator.fige = true
        } else if CommandLine.arguments.contains("-carnetSceneAuto") {
            // La tourne en boucle, mains libres — LE FILM est le juge
            // (la leçon du jury V4 : il n'avait vu que des poses).
            context.coordinator.autoTourne()
        } else {
            let pan = UIPanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.pan(_:)))
            view.addGestureRecognizer(pan)
            let tap = UITapGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coordinator.tap(_:)))
            view.addGestureRecognizer(tap)
        }
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var moteur: CarnetSceneMoteur?
        var q: Float = 0
        var fige = false
        private var baseQ: Float = 0

        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard let moteur, !fige else { return }
            switch g.state {
            case .began:
                baseQ = q
            case .changed:
                let t = Float(g.translation(in: g.view).x)
                q = max(0, min(1, baseQ - t / 240))
                moteur.setQ(q)
            case .ended, .cancelled:
                // L'aimant sur l'élan PRÉDIT, jamais la position seule.
                let vx = Float(g.velocity(in: g.view).x)
                let fin = q - vx * 0.12 / 240
                let cible: Float = fin > 0.5 ? 1 : 0
                moteur.springQ(from: q, to: cible)
                q = cible
            default:
                break
            }
        }

        @objc func tap(_ g: UITapGestureRecognizer) {
            guard let moteur, !fige else { return }
            SwapFeedback.shared.tap()
            let cible: Float = q > 0.5 ? 0 : 1
            moteur.springQ(from: q, to: cible)
            q = cible
        }

        /// Aller-retour perpétuel au ressort du banc, 2,4 s par temps.
        func autoTourne() {
            Timer.scheduledTimer(withTimeInterval: 2.4,
                                 repeats: true) { [weak self] _ in
                guard let self, let moteur = self.moteur else { return }
                let cible: Float = self.q > 0.5 ? 0 : 1
                moteur.springQ(from: self.q, to: cible)
                self.q = cible
            }
        }
    }
}

/// Le banc plein écran : le noir de la maison derrière la scène.
struct CarnetSceneBanc: View {
    var body: some View {
        ZStack {
            Color.black
            CarnetSceneStage()
        }
        .ignoresSafeArea()
    }
}
