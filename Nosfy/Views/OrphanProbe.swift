import UIKit

/// SONDE ORPHELIN (27-08) — pour trancher le gel TOTAL de l'app après le
/// chemin Home→Duolingo→Commencer, SANS deviner.
///
/// Hypothèse à prouver ou réfuter : un conteneur de transition (UITransitionView)
/// laissé orphelin par un fullScreenCover démonté pendant une bascule d'onglet
/// reste dans la key window AU-DESSUS de tout, capte le doigt mais ne route
/// plus rien → toute l'app gelée, même au retour home.
///
/// La sonde fait DEUX choses à la fois, toutes les 0,5 s :
///   1. elle est un TÉMOIN DE VIE du fil principal — si les lignes cessent
///      pendant le gel, c'est un DEADLOCK, pas un orphelin ;
///   2. elle interroge `keyWindow.hitTest(centre)` et liste toute vue
///      plein écran interactive résiduelle (Transition/host) au-dessus du
///      contenu — si le hit du centre n'est plus le contenu vivant, ou qu'une
///      couche plein écran interactive traîne, l'ORPHELIN est prouvé, et sa
///      classe NOMME le coupable.
///
/// Gardée par `-orphanProbe` : inerte en prod. Lecture par Console.app en USB,
/// sans toucher l'écran.
enum OrphanProbe {
    private static var timer: Timer?

    static func start() {
        guard CommandLine.arguments.contains("-orphanProbe") else { return }
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            tick()
        }
        print("[orphan] sonde armée (0,5 s)")
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private static func tick() {
        guard let w = keyWindow() else { print("[orphan] pas de key window"); return }
        let centre = CGPoint(x: w.bounds.midX, y: w.bounds.midY)
        let hit = w.hitTest(centre, with: nil)
        let hitCls = hit.map { String(describing: type(of: $0)) } ?? "nil"

        // Les vues plein écran, interactives, résiduelles au-dessus du contenu.
        var pleinEcran: [String] = []
        func walk(_ v: UIView) {
            let cls = String(describing: type(of: v))
            let couvre = v.bounds.width >= w.bounds.width - 1
                && v.bounds.height >= w.bounds.height - 1
            let suspecte = cls.contains("Transition")
                || cls.contains("DropShadow")
                || cls.contains("PresentationContainer")
            if couvre, v.isUserInteractionEnabled, !v.isHidden, v.alpha > 0.01,
               suspecte {
                pleinEcran.append("\(cls) frame=\(v.frame)")
            }
            v.subviews.forEach(walk)
        }
        walk(w)

        // Y a-t-il un VC modal encore présenté ? (un orphelin en a un mort/aucun)
        var modal = "aucun"
        if let root = w.rootViewController {
            var vc: UIViewController? = root
            var chaine: [String] = []
            while let cur = vc {
                if cur.presentedViewController != nil {
                    chaine.append(String(describing: type(of: cur)))
                }
                vc = cur.presentedViewController
            }
            if !chaine.isEmpty { modal = chaine.joined(separator: "→") }
        }

        print("[orphan] vivant hit=\(hitCls) modalPrésenté=\(modal) "
              + "couchesPleinÉcranSuspectes=\(pleinEcran.isEmpty ? "aucune" : pleinEcran.joined(separator: " | "))")
    }
}
