import UIKit
import SceneKit

/// Diagnostic local des gestes, uniquement avec `-navProbe`.
/// Aucune reconnaissance ajoutée : on observe les gestes existants et les
/// cibles UIKit aux trois centres de la navigation. Aucun texte du compte.
enum NavDiagnostic {
    static let actif = CommandLine.arguments.contains("-navProbe")
    private static var sortie: FileHandle?
    private static var ouvert = false
    private static var releveAnimations = false
    private static let debut = ProcessInfo.processInfo.systemUptime
    /// Ne prolonge ni la vue ni son coordinateur : une vue détachée ne doit
    /// apparaître que si le moteur la conserve réellement en vie.
    private final class VueSceneKitFaible {
        weak var vue: SCNView?
        let role: String
        let rendus: (() -> UInt64?)?

        init(_ vue: SCNView, role: String, rendus: (() -> UInt64?)?) {
            self.vue = vue
            self.role = role
            self.rendus = rendus
        }
    }
    private static var registreSceneKit: [ObjectIdentifier: VueSceneKitFaible] = [:]

    /// Appel sur le fil principal, comme la capture. La closure de compteur
    /// doit capturer le coordinateur faiblement ; aucun delegate n'est posé.
    static func enregistrer(_ vue: SCNView, role: String,
                            rendus: (() -> UInt64?)? = nil) {
        guard actif else { return }
        registreSceneKit = registreSceneKit.filter { $0.value.vue != nil }
        registreSceneKit[ObjectIdentifier(vue)] = VueSceneKitFaible(
            vue, role: role, rendus: rendus)
    }

    private static func capturer(_ scn: SCNView, role: String,
                                 rendus: (() -> UInt64?)?,
                                 fenetrePrincipale: UIWindow?) -> [String: Any] {
        func rectangle(_ rect: CGRect) -> [String: CGFloat] {
            ["x": rect.origin.x, "y": rect.origin.y,
             "largeur": rect.width, "hauteur": rect.height]
        }
        // L'alpha propre ne révèle pas un parent transparent.
        var ancetre: UIView? = scn
        var cacheeDansHierarchie = false
        var alphaCumule: CGFloat = 1
        while let v = ancetre {
            cacheeDansHierarchie = cacheeDansHierarchie || v.isHidden
            alphaCumule *= v.alpha
            ancetre = v.superview
        }
        var etat: [String: Any] = [
            "identite": String(describing: ObjectIdentifier(scn)),
            "role": role,
            "taille": ["largeur": scn.bounds.width, "hauteur": scn.bounds.height],
            "bounds": rectangle(scn.bounds),
            "isHidden": scn.isHidden, "alpha": scn.alpha,
            "cacheeDansHierarchie": cacheeDansHierarchie,
            "alphaCumule": alphaCumule,
            "isPlaying": scn.isPlaying,
            "rendersContinuously": scn.rendersContinuously,
            "windowNonNil": scn.window != nil
        ]
        if let fenetre = scn.window {
            etat["cadreFenetre"] = rectangle(scn.convert(scn.bounds, to: fenetre))
            etat["fenetrePrincipale"] = fenetre === fenetrePrincipale
        } else {
            // Aucune conversion de coordonnées entre racines détachées.
            etat["cadreFenetre"] = NSNull()
            etat["fenetrePrincipale"] = false
        }
        if let scene = scn.scene { etat["scenePaused"] = scene.isPaused }
        else { etat["scenePaused"] = NSNull() }
        if let nombre = rendus?() { etat["rendusTermines"] = nombre }
        else { etat["rendusTermines"] = NSNull() }
        return etat
    }

    static func noter(_ evenement: String, destination: String = "") {
        guard actif else { return }
        if !ouvert {
            ouvert = true
            let format = DateFormatter()
            format.dateFormat = "yyyyMMdd-HHmmss"
            let dossier = FileManager.default.urls(for: .documentDirectory,
                                                   in: .userDomainMask)[0]
            let url = dossier.appendingPathComponent("nav-\(format.string(from: Date())).jsonl")
            FileManager.default.createFile(atPath: url.path, contents: nil)
            sortie = try? FileHandle(forWritingTo: url)
        }
        let nav = NavEtat.shared
        var ligne: [String: Any] = [
            "t": Date.timeIntervalSinceReferenceDate,
            "evenement": evenement, "destination": destination,
            "page": nav.page.rawValue,
            "selection": SondeVol.shared.onglet,
            "enVol": nav.enVol, "enSuivi": nav.enSuivi,
            "bande": nav.bandeVisiblePubliee,
            "visite": DepartEtat.shared.visiteOuverte,
            "applicationState": UIApplication.shared.applicationState.rawValue,
            "ecranEveille": UIApplication.shared.isIdleTimerDisabled,
            "therm": ProcessInfo.processInfo.thermalState.rawValue
        ]
        if evenement == "etat" {
            let fenetrePrincipale = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow })
            registreSceneKit = registreSceneKit.filter { $0.value.vue != nil }
            var vuesSceneKit: [[String: Any]] = []
            var identites = Set<ObjectIdentifier>()
            for entree in registreSceneKit.values {
                guard let scn = entree.vue else { continue }
                identites.insert(ObjectIdentifier(scn))
                vuesSceneKit.append(capturer(scn, role: entree.role,
                                             rendus: entree.rendus,
                                             fenetrePrincipale: fenetrePrincipale))
            }
            if let fenetre = fenetrePrincipale {
                let y = fenetre.bounds.maxY - 39
                ligne["cibles"] = [-76.0, 0, 76].map { dx -> [String: Any] in
                    let point = CGPoint(x: fenetre.bounds.midX + dx, y: y)
                    var vue = fenetre.hitTest(point, with: nil)
                    var chaine: [String] = []
                    while let v = vue, chaine.count < 10 {
                        chaine.append(String(String(describing: type(of: v)).prefix(160)))
                        vue = v.superview
                    }
                    return ["x": point.x, "y": point.y, "chaine": chaine]
                }
                var barres: [[String: Any]] = []
                func visiter(_ vue: UIView) {
                    if let barre = vue as? UITabBar {
                        barres.append(["cachee": barre.isHidden,
                                       "alpha": barre.alpha,
                                       "interactive": barre.isUserInteractionEnabled,
                                       "cadre": String(describing: barre.convert(barre.bounds, to: fenetre))])
                    }
                    if let scn = vue as? SCNView,
                       identites.insert(ObjectIdentifier(scn)).inserted {
                        vuesSceneKit.append(capturer(scn, role: "nonEnregistre",
                                                     rendus: nil,
                                                     fenetrePrincipale: fenetre))
                    }
                    vue.subviews.forEach(visiter)
                }
                visiter(fenetre)
                ligne["barresSysteme"] = barres
                if CommandLine.arguments.contains("-sondeAnimations"),
                   !releveAnimations, ProcessInfo.processInfo.systemUptime - debut > 20 {
                    releveAnimations = true
                    // Valeurs textuelles uniquement : une valeur d'animation
                    // non sérialisable a fait avorter le diagnostic31.
                    var animations: [[String: String]] = []
                    var vues = Set<ObjectIdentifier>()
                    func lire(_ c: CALayer, chemin: String, alpha: Float) {
                        guard vues.count < 1500,
                              vues.insert(ObjectIdentifier(c)).inserted else { return }
                        let a = alpha * c.opacity * (c.isHidden ? 0 : 1)
                        for cle in c.animationKeys() ?? [] {
                            guard let animation = c.animation(forKey: cle) else { continue }
                            animations.append([
                                "chemin": chemin, "cle": cle,
                                "type": String(describing: type(of: animation)),
                                "propriete": String(describing: (animation as? CAPropertyAnimation)?.keyPath),
                                "duree": String(describing: animation.duration),
                                "repetitions": String(describing: animation.repeatCount),
                                "alphaAncetres": String(describing: a),
                                "cadre": String(describing: c.frame)
                            ])
                        }
                        for (i, enfant) in (c.sublayers ?? []).enumerated() {
                            lire(enfant, chemin: chemin + "/\(i):\(type(of: enfant))", alpha: a)
                        }
                    }
                    lire(fenetre.layer, chemin: "fenetre", alpha: 1)
                    ligne["animationsNatives"] = animations
                }
            }
            ligne["vuesSceneKit"] = vuesSceneKit
        }
        guard JSONSerialization.isValidJSONObject(ligne),
              let donnees = try? JSONSerialization.data(withJSONObject: ligne,
                                                         options: [.sortedKeys]) else { return }
        sortie?.write(donnees + Data([10]))
    }
}
