import SceneKit
import SwiftUI
import UIKit

// MARK: - Le relief : la « photo 3D » d'une carte (banc -mondeLab -mondeRelief, 20-09)

/// Sa question du soir : « pas un système plus joli qui transporte ? ».
/// Celui-ci : la peinture n'est plus découpée en tranches, elle est POSÉE SUR
/// UN MAILLAGE que sa profondeur vraie bombe — chaque pixel à sa distance,
/// le cerf a du volume, les rochers des arêtes, la vallée s'enfonce en
/// continu. La créature reste détachée devant (son plan à elle) : derrière
/// elle, le fond reconstitué. C'est ce que font les photos 3D de Facebook et
/// les photos spatiales d'Apple, rendu ici par SceneKit — le moteur du booster.
///
/// Trois voix, toutes de la main :
///   · l'inclinaison (gyroscope, doigt) déplace la CAMÉRA, qui regarde le
///     centre — la parallaxe vient de la géométrie, pas d'un décalage peint ;
///   · l'ouverture (`ouvert` 0 → 1) fait MONTER le relief : la peinture plate
///     se bombe en 0,8 s — la traversée du verre ;
///   · l'approche (`zoom` 1 → 2) avance la caméra : le proche vient, le
///     lointain reste.
///
/// La loi du rideau : une SCNView rend même effacée par l'opacité — l'hôte ne
/// la monte qu'après le tap et la démonte au retour ; `isPlaying` suit.
/// Aucun éclairage (matériau constant) : la peinture porte sa propre lumière.
struct MondeRelief: UIViewRepresentable {
    var fond: UIImage
    var fondDepth: UIImage
    var creature: UIImage?
    var creatureProfondeur: Float
    var tilt: SIMD2<Float>
    var ouvert: CGFloat
    var pan: CGSize
    var zoom: CGFloat
    var ecran: CGSize

    /// Le maillage : 2 × 3 unités (le 2:3 des illustrations), assez dense pour
    /// que les arêtes suivent la profondeur sans polygones visibles.
    static let largeur: CGFloat = 2.0
    static let hauteur: CGFloat = 3.0
    static let segments = (w: 220, h: 330)
    /// L'amplitude du relief à pleine ouverture, en unités de scène : le point
    /// le plus proche (profondeur 0,10) vient de 0,35 × amp vers la caméra.
    static let amp: Float = 0.70
    /// La caméra : à cette distance, la hauteur du maillage remplit l'écran
    /// (champ vertical 60°) ; la largeur déborde — la marge de la parallaxe.
    static let distance: Float = 2.6

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: .zero)
        v.backgroundColor = .black
        v.delegate = context.coordinator
        v.antialiasingMode = .none
        v.preferredFramesPerSecond = 60
        v.rendersContinuously = true
        v.isPlaying = true
        v.scene = context.coordinator.scene
        v.pointOfView = context.coordinator.camera
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        context.coordinator.appliquer(tilt: tilt, ouvert: Float(ouvert), pan: pan, zoom: Float(zoom))
    }

    static func dismantleUIView(_ v: SCNView, coordinator: Coordinator) {
        v.isPlaying = false
        v.scene = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fond: fond, fondDepth: fondDepth, creature: creature,
                    creatureProfondeur: creatureProfondeur, ecran: ecran)
    }

    /// SceneKit ne sait pas faire une texture Metal d'une image GRISE 8 bits
    /// (crash `MTLDebugValidateMTLPixelFormat`, payé au sim le 20-09) : toute
    /// image qu'on lui donne est redessinée en RGBA.
    static func rgba(_ im: UIImage) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = 1
        f.opaque = false
        return UIGraphicsImageRenderer(size: im.size, format: f).image { _ in
            im.draw(in: CGRect(origin: .zero, size: im.size))
        }
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let scene = SCNScene()
        /// La cible de la caméra (écrite par SwiftUI) et sa position lissée
        /// (écrite dans le rendu SceneKit, à chaque image) : un ressort
        /// exponentiel de ~90 ms — le geste devient « lourd », donc naturel.
        private var cible = SCNVector3(0, 0, MondeRelief.distance)
        private var lisse = SCNVector3(0, 0, MondeRelief.distance)
        private var derniere: TimeInterval = 0

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt = derniere == 0 ? 1.0 / 60 : min(0.05, time - derniere)
            derniere = time
            let k = Float(1 - exp(-dt / 0.09))
            lisse.x += (cible.x - lisse.x) * k
            lisse.y += (cible.y - lisse.y) * k
            lisse.z += (cible.z - lisse.z) * k
            camera.position = lisse
        }
        let camera = SCNNode()
        let relief: SCNNode
        let plaqueCreature: SCNNode?
        let materiau: SCNMaterial
        let ecran: CGSize

        init(fond: UIImage, fondDepth: UIImage, creature: UIImage?, creatureProfondeur: Float, ecran: CGSize) {
            self.ecran = ecran
            self.plaqueCreatureProfondeur = creatureProfondeur
            scene.background.contents = UIColor.black

            // — le maillage du fond, bombé par sa profondeur dans le shader de géométrie
            let plan = SCNPlane(width: MondeRelief.largeur, height: MondeRelief.hauteur)
            plan.widthSegmentCount = MondeRelief.segments.w
            plan.heightSegmentCount = MondeRelief.segments.h
            let m = SCNMaterial()
            m.diffuse.contents = MondeRelief.rgba(fond)
            m.diffuse.minificationFilter = .linear
            m.diffuse.magnificationFilter = .linear
            m.lightingModel = .constant
            m.isDoubleSided = true
            let depthProp = SCNMaterialProperty(contents: MondeRelief.rgba(fondDepth))
            depthProp.minificationFilter = .linear
            depthProp.magnificationFilter = .linear
            m.setValue(depthProp, forKey: "depthTex")
            m.setValue(NSNumber(value: 0.0), forKey: "amp")
            m.setValue(NSNumber(value: MondeRelief.distance), forKey: "dist")
            // La profondeur du kit : 1 = le fond du ciel, 0,45 = le pivot (ne
            // bouge pas), 0,10 = le plus près. Le proche VIENT vers la caméra
            // — LE LONG DU RAYON DE VUE : un point qui avance grossirait par
            // perspective (le cerf flottait, les coins se tordaient — payé au
            // sim) ; on réduit x,y d'autant, et au repos la projection est la
            // peinture exacte. Seule l'inclinaison révèle le relief.
            m.shaderModifiers = [
                .geometry: """
                #pragma arguments
                texture2d<float, access::sample> depthTex;
                float amp;
                float dist;
                #pragma body
                constexpr sampler s(filter::linear, address::clamp_to_edge);
                float d = depthTex.sample(s, _geometry.texcoords[0]).r;
                float dz = (0.45 - d) * amp;
                float k = (dist - dz) / dist;
                _geometry.position.xy *= k;
                _geometry.position.z += dz;
                """
            ]
            plan.materials = [m]
            materiau = m
            relief = SCNNode(geometry: plan)
            scene.rootNode.addChildNode(relief)

            // — la créature : son plan à elle, devant le fond, à sa profondeur
            if let c = creature {
                let p = SCNPlane(width: MondeRelief.largeur, height: MondeRelief.hauteur)
                let mc = SCNMaterial()
                mc.diffuse.contents = MondeRelief.rgba(c)
                mc.lightingModel = .constant
                mc.isDoubleSided = true
                mc.blendMode = .alpha
                mc.writesToDepthBuffer = false
                // Jamais occultée par le fond bombé (derrière elle, la profondeur
                // reconstituée peut venir plus près qu'elle : ses jambes disparaissaient).
                mc.readsFromDepthBuffer = false
                p.materials = [mc]
                let n = SCNNode(geometry: p)
                n.position.z = 0
                n.renderingOrder = 10
                plaqueCreature = n
                scene.rootNode.addChildNode(n)
            } else {
                plaqueCreature = nil
            }

            // — la caméra : elle regarde toujours le centre du monde
            let cam = SCNCamera()
            cam.fieldOfView = 60
            cam.zNear = 0.05
            cam.zFar = 20
            camera.camera = cam
            camera.position = SCNVector3(0, 0, MondeRelief.distance)
            let regard = SCNLookAtConstraint(target: relief)
            regard.isGimbalLockEnabled = true
            camera.constraints = [regard]
            scene.rootNode.addChildNode(camera)
        }

        func appliquer(tilt: SIMD2<Float>, ouvert: Float, pan: CGSize, zoom: Float) {
            // le relief monte avec l'ouverture ; la créature avance à sa profondeur
            let amp = MondeRelief.amp * ouvert
            materiau.setValue(NSNumber(value: amp), forKey: "amp")
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0
            let zc = (0.45 - plaqueCreatureProfondeur) * amp + 0.015
            plaqueCreature?.position.z = zc
            let kc = (MondeRelief.distance - zc) / MondeRelief.distance
            plaqueCreature?.scale = SCNVector3(kc, kc, 1)
            // la caméra : l'inclinaison la déplace (elle regarde le centre), le
            // doigt promène le regard, pincer avance
            let course: Float = 0.30 * ouvert
            let px = Float(pan.width / max(ecran.width, 1)) * 0.9 * ouvert
            let py = Float(pan.height / max(ecran.height, 1)) * 1.3 * ouvert
            let z = MondeRelief.distance - (zoom - 1) * 1.0
            cible = SCNVector3(-tilt.x * course - px, tilt.y * 0.72 * course + py, z)
            SCNTransaction.commit()
        }

        private var plaqueCreatureProfondeur: Float
    }
}
