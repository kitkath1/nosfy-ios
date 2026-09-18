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
    /// V3 — LE PAPIER VIVANT, aux formules PROUVÉES du physicien
    /// (wf_578b2998 : isométrie 0,0000 %, C1 exact aux coutures, garde-fous
    /// d'angle contre le passage sous le lit) et aux verdicts du jury :
    /// — le CÔNE RAMPE : k(q) = skewK2·(1−q)^1,5 + skewK1, le coin mène
    ///   au départ, le pli se redresse à la pose ;
    /// — l'ARC AÉRIEN : le segment libre est un arc de courbure λ =
    ///   sin α·(ventre statique − traîne·qVel) + torsion différentielle
    ///   (le bas précède, le coin haut retombe en dernier) — C1 avec le
    ///   congé pour tout λ, limite λ→0 d'ordre 2 stable ;
    /// — le FLUTTER : fenêtré sin²α (meurt C1 aux poses) × smoothstep
    ///   charnière, porté LE LONG de la normale tournée ;
    /// — la GOUTTIÈRE : bombé quartique 16s²(1−s)² (valeur ET pente
    ///   nulles aux deux bouts — le sin(πx/A) cassait le C1 à la
    ///   couture), normales nourries sinon le bombé n'existe pas ;
    /// — les DEUX FAUTES du physicien corrigées : l'écart des peaux
    ///   tourne AVEC la surface (sinon recto/verso s'inversent passé
    ///   90°), et la normale du cône porte sa composante y (l'erreur
    ///   des 4,6° au relight rasant) ;
    /// — le VENTRE TRANSVERSE : tranché GADGET (courbure de Gauss non
    ///   nulle = caoutchouc), jamais implémenté.
    /// `qVel` arrive LISSÉ du CPU (EMA 60 ms — le brut tremblote au
    /// settle du ressort, interdit).
    static let geometryModifier = """
    #pragma arguments
    float qTurn;
    float qVel;
    float curlR0;
    float sheetWu;
    float skewK1;
    float skewK2;
    float torsK;
    float aerialBelly;
    float aerialVel;
    float flutAmp;
    float flutKy;
    float flutWt;
    float gutterAmp;
    float gutterW;
    #pragma body
    float q = clamp(qTurn, 0.0, 1.0);
    float qv = clamp(qVel, -10.0, 10.0);
    float x = _geometry.position.x;
    float yn = _geometry.position.y;
    float alpha = 3.14159265 * q;
    float sa = sin(alpha);
    float skewK = skewK1 + skewK2 * pow(1.0 - q, 1.5);
    float A = max(sheetWu * (1.0 - q) + skewK * yn * sa, 0.0);
    float r = max(curlR0 * sa, 0.0025);
    float dm = x - A;
    if (dm > 0.0) {
        float arcLen = r * alpha;
        float Lfree = max(sheetWu - A - arcLen, 1e-3);
        float lam = sa * (aerialBelly * sa - aerialVel * qv)
            + 3.14159265 * torsK * (-yn / 0.4865) * sa / Lfree;
        lam = clamp(lam, min(0.02 - alpha, 0.0) / Lfree,
                    max(3.1116 - alpha, 0.0) / Lfree);
        float phi;
        float px;
        float pz;
        if (dm <= arcLen) {
            phi = dm / r;
            px = A + r * sin(phi);
            pz = r * (1.0 - cos(phi));
        } else {
            float t = dm - arcLen;
            float P0x = A + r * sa;
            float P0z = r * (1.0 - cos(alpha));
            phi = alpha + lam * t;
            if (fabs(lam) > 1e-4) {
                px = P0x + (sin(phi) - sa) / lam;
                pz = P0z + (cos(alpha) - cos(phi)) / lam;
            } else {
                px = P0x + t * cos(alpha) - 0.5 * lam * t * t * sa;
                pz = P0z + t * sin(alpha) + 0.5 * lam * t * t * cos(alpha);
            }
            float wPose = sa * sa;
            float wHinge = smoothstep(0.0, 0.18, dm);
            float aF = flutAmp * min(fabs(qv) * 0.25, 1.5) * wPose * wHinge;
            float rip = sin(yn * flutKy + dm * 6.0 + scn_frame.time * flutWt);
            px += aF * rip * (-sin(phi));
            pz += aF * rip * cos(phi);
        }
        float z0 = _geometry.position.z;
        _geometry.position.x = px - z0 * sin(phi);
        _geometry.position.z = pz + z0 * cos(phi);
        float side = (_geometry.normal.z >= 0.0) ? 1.0 : -1.0;
        _geometry.normal = normalize(float3(-sin(phi),
                                            skewK * sa * sin(phi),
                                            cos(phi))) * side;
        float c = cos(phi);
        float s = sin(phi);
        float tx = _geometry.tangent.x;
        float tz = _geometry.tangent.z;
        _geometry.tangent.x = tx * c - tz * s;
        _geometry.tangent.z = tx * s + tz * c;
    } else {
        float g0 = min(gutterW, A);
        if (g0 > 1e-3 && x < g0) {
            float sg = x / g0;
            float bump = 16.0 * sg * sg * (1.0 - sg) * (1.0 - sg);
            float gA = gutterAmp * sa * min(g0 / gutterW, 1.0);
            _geometry.position.z += gA * bump;
            float dzdx = gA * 32.0 * sg * (1.0 - sg) * (1.0 - 2.0 * sg) / g0;
            float sideG = (_geometry.normal.z >= 0.0) ? 1.0 : -1.0;
            _geometry.normal = normalize(float3(-dzdx, 0.0, 1.0)) * sideG;
        }
    }
    """

    /// L'OR DE LA TRANCHE LIBRE — le bijou de la V4, gardé : un fil d'or
    /// permanent au bord libre de la feuille, qui FLARE au rasant (quand
    /// la tranche passe face caméra). En émission : il vit au-dessus du
    /// lambert, insensible à l'ombre — l'or fuit de la lumière.
    /// V2 — l'or du bord libre, plus LE SATIN DE COURBURE : un spéculaire
    /// doux de papier noir, GATÉ PAR LA FLEXION (nul quand la normale
    /// regarde la caméra — les poses restent la photo nue) et porté par
    /// la diffuse (il vit sous la lumière, donc il meurt dans l'ombre —
    /// un satin en émission brillerait dans le noir, mensonge).
    static let surfaceModifier = """
    #pragma arguments
    float goldGlow;
    float goldEdgeU;
    float sheenGain;
    float keyLx;
    float keyLy;
    float keyLz;
    #pragma body
    float du = abs(_surface.diffuseTexcoord.x - goldEdgeU);
    float band = exp(-pow(du / 0.005, 2.0));
    float3 gN = normalize(_surface.normal);
    float3 gV = normalize(_surface.view);
    float graze = pow(1.0 - abs(dot(gN, gV)), 2.0);
    _surface.emission.rgb += float3(1.0, 0.72, 0.30) * band * goldGlow
        * (0.20 + 1.6 * graze);
    float3 kL = normalize(float3(keyLx, keyLy, keyLz));
    float3 kH = normalize(kL + gV);
    float bend = clamp((1.0 - abs(dot(gN, gV))) * 2.2, 0.0, 1.0);
    _surface.diffuse.rgb += float3(0.96, 0.97, 1.0)
        * pow(clamp(dot(gN, kH), 0.0, 1.0), 48.0) * sheenGain * bend;
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
            mat.setValue(0.0 as CGFloat, forKey: "qVel")
            mat.setValue(CGFloat(m.molette("carnetCurlR", 0.16)),
                         forKey: "curlR0")
            mat.setValue(CGFloat(m.sheetW), forKey: "sheetWu")
            // Les défauts du physicien (wf_578b2998) — chaque clé répond
            // EXACTEMENT au #pragma arguments (un nom qui boite = zéro
            // silencieux, le piège payé du booster).
            mat.setValue(CGFloat(m.molette("carnetSkew1", 0.06)),
                         forKey: "skewK1")
            mat.setValue(CGFloat(m.molette("carnetSkew2", 0.26)),
                         forKey: "skewK2")
            mat.setValue(CGFloat(m.molette("carnetTors", 0.035)),
                         forKey: "torsK")
            mat.setValue(CGFloat(m.molette("carnetBelly", 0.5)),
                         forKey: "aerialBelly")
            mat.setValue(CGFloat(m.molette("carnetAir", 0.22)),
                         forKey: "aerialVel")
            mat.setValue(CGFloat(m.molette("carnetFlutter", 0.004)),
                         forKey: "flutAmp")
            mat.setValue(CGFloat(m.molette("carnetFlutKy", 12)),
                         forKey: "flutKy")
            mat.setValue(CGFloat(m.molette("carnetFlutWt", 50)),
                         forKey: "flutWt")
            mat.setValue(CGFloat(m.molette("carnetGutter", 0.012)),
                         forKey: "gutterAmp")
            mat.setValue(CGFloat(m.molette("carnetGutterW", 0.12)),
                         forKey: "gutterW")
            mat.setValue(CGFloat(m.molette("carnetGold", 0.8)),
                         forKey: "goldGlow")
            mat.setValue(CGFloat(m.molette("carnetSheen", 0.55)),
                         forKey: "sheenGain")
            mat.setValue(CGFloat(m.keyDir.x), forKey: "keyLx")
            mat.setValue(CGFloat(m.keyDir.y), forKey: "keyLy")
            mat.setValue(CGFloat(m.keyDir.z), forKey: "keyLz")
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

    /// L'état de la tourne, servi chaque frame par l'intégrateur du banc
    /// (position ET vitesse — c'est la vitesse qui fait vivre le papier :
    /// arc aérien, flutter, claquement d'atterrissage).
    func setDyn(q: Float, v: Float) {
        for mat in feuilleMats {
            mat.setValue(CGFloat(q), forKey: "qTurn")
            mat.setValue(CGFloat(v), forKey: "qVel")
        }
    }

    /// Pose figée (captures `-carnetQ`) : vitesse nulle, la photo est
    /// reine.
    func setQ(_ v: Float) { setDyn(q: v, v: 0) }
}

// MARK: - L'intégrateur du papier

/// LE RESSORT ANALYTIQUE — la mécanique de la page, résolue en forme
/// close à chaque frame (inconditionnellement stable : à 18 img/s au
/// simulateur comme à 120 Hz au téléphone, la même trajectoire). Deux
/// régimes : le SUIVI (la page chasse le doigt avec un retard massique —
/// le papier a une masse, il ne se téléporte pas sous la main) et la
/// POSE (l'aimant, qui HÉRITE de la vitesse du doigt : l'élan se
/// conserve, jamais un redémarrage à zéro — le feel d'Apple Books).
struct RessortPapier {
    var q: Float = 0
    var v: Float = 0
    var cible: Float = 0
    /// ω du régime courant (rad/s) et son amortissement ζ.
    var omega: Float = 12.0
    var zeta: Float = 0.92

    /// Le suivi du doigt : réponse ~0,11 s, quasi critique.
    mutating func suivre(_ t: Float) {
        cible = t
        omega = 56.0
        zeta = 0.995
    }

    /// L'aimant vers la pose : response 0,46 s, un souffle d'overshoot
    /// (le papier claque puis s'éteint — l'arc aérien fait le reste).
    mutating func poser(vers t: Float) {
        cible = t
        omega = 2 * .pi / 0.46
        zeta = 0.90
    }

    /// Un pas exact d'oscillateur amorti (forme close sous-amortie).
    mutating func pas(dt rawDt: Float) {
        let dt = min(max(rawDt, 1.0 / 240.0), 1.0 / 12.0)
        let z = min(zeta, 0.9995)
        let wd = omega * sqrt(1 - z * z)
        let e = exp(-z * omega * dt)
        let c = cos(wd * dt)
        let s = sin(wd * dt)
        let dx = q - cible
        let b = (v + z * omega * dx) / wd
        q = cible + e * (dx * c + b * s)
        v = e * (v * c - (dx * omega * omega + z * omega * v) / wd * s)
    }

    var posee: Bool {
        abs(q - cible) < 0.0004 && abs(v) < 0.004
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
            context.coordinator.figer(a: Float(v))
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

    /// LE DÉMONTAGE (la leçon du manège du booster) : un CADisplayLink
    /// retient sa cible — sans invalidation, le coordinateur survivrait
    /// à son écran et son intégrateur chanterait dans le vide.
    static func dismantleUIView(_ uiView: SCNView,
                                coordinator: Coordinator) {
        coordinator.teardown()
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var moteur: CarnetSceneMoteur?
        var fige = false
        /// q public pour la boucle auto et le tap (l'état vrai vit dans
        /// le ressort).
        var q: Float { ressort.q }

        private var ressort = RessortPapier()
        /// qVel LISSÉ (EMA 60 ms) — le brut tremblote au settle du
        /// ressort et ferait frissonner l'arc aérien (loi du physicien).
        private var qvLisse: Float = 0
        private var link: CADisplayLink?
        private var derniereFrame: CFTimeInterval = 0
        private var baseQ: Float = 0
        private var autoTimer: Timer?

        /// La course du doigt pour une tourne complète, en points.
        private let course: Float = 240

        private func reveille() {
            guard link == nil else { return }
            derniereFrame = CACurrentMediaTime()
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: .main, forMode: .common)
            link = l
        }

        @objc private func tick() {
            guard let moteur else { return }
            let now = CACurrentMediaTime()
            let dt = Float(now - derniereFrame)
            derniereFrame = now
            ressort.pas(dt: dt)
            qvLisse += (ressort.v - qvLisse) * (1 - exp(-dt / 0.06))
            moteur.setDyn(q: ressort.q, v: qvLisse)
            // Posée ET plus personne sous le doigt : le lien s'endort
            // (l'état final est écrit, vitesse nulle — la photo reprend).
            if ressort.posee, !doigtDessus {
                ressort.q = ressort.cible
                ressort.v = 0
                moteur.setDyn(q: ressort.q, v: 0)
                link?.invalidate()
                link = nil
            }
        }

        private var doigtDessus = false

        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard moteur != nil, !fige else { return }
            switch g.state {
            case .began:
                doigtDessus = true
                baseQ = ressort.q
                reveille()
            case .changed:
                let t = Float(g.translation(in: g.view).x)
                ressort.suivre(max(0, min(1, baseQ - t / course)))
            case .ended, .cancelled:
                doigtDessus = false
                // L'aimant sur l'élan PRÉDIT — et le ressort HÉRITE de la
                // vitesse déjà acquise par le suivi : l'élan se conserve.
                let vx = Float(g.velocity(in: g.view).x)
                let fin = ressort.q - vx * 0.16 / course
                ressort.poser(vers: fin > 0.5 ? 1 : 0)
                reveille()
            default:
                break
            }
        }

        @objc func tap(_ g: UITapGestureRecognizer) {
            guard moteur != nil, !fige else { return }
            SwapFeedback.shared.tap()
            ressort.poser(vers: ressort.q > 0.5 ? 0 : 1)
            reveille()
        }

        /// Pose figée `-carnetQ` : l'état du ressort s'aligne, rien ne
        /// bouge plus.
        func figer(a v: Float) {
            ressort.q = v
            ressort.cible = v
            ressort.v = 0
            fige = true
        }

        /// Aller-retour perpétuel (le banc à filmer), 2,4 s par temps.
        func autoTourne() {
            autoTimer = Timer.scheduledTimer(withTimeInterval: 2.4,
                                             repeats: true) { [weak self] _ in
                guard let self else { return }
                self.ressort.poser(vers: self.ressort.q > 0.5 ? 0 : 1)
                self.reveille()
            }
        }

        func teardown() {
            link?.invalidate()
            link = nil
            autoTimer?.invalidate()
            autoTimer = nil
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
