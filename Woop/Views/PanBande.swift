import SwiftUI
import UIKit

// MARK: - LE PAN MAÎTRE DE BANDE, À LA RACINE (03-09, plan final
// `nav-definitif` — remplace la v1 en `.background`, qui ne recevait
// JAMAIS le doigt : le contentShape SwiftUI de devant revendiquait le
// toucher sans repli vers le frère de fond. Cause première de « le drag
// ne fait rien », lue et clouée.)

/// Les cotes de la bande — UNE source, consommée ici ET par `PageCard`.
enum BandeCote {
    /// Le trait (grabber) + son air — compacté 18 → 12 le 04-09
    /// (« trop haut ») ; la dalle, elle, est l'invariant fouetté et ne
    /// bouge PAS.
    /// Le trait + son air — 12 → 6 (04-09, 2e passe) : le trait n'a plus
    /// de geste (le tap efface la nav), il n'a plus besoin de sa marge.
    static let grab: CGFloat = 6
    /// La dalle player, hauteur canonique — l'invariant fouetté.
    static let dalle: CGFloat = 76
}

/// L'HÔTE DU PAN DE BANDE — monté UNE SEULE FOIS à la racine (à côté de
/// `PlayerMondeHote`), le patron EXACT du `PanMaitre` du player
/// (`PlayerMonde.swift:759-784`) : une SONDE non-interactive dans
/// l'arbre, le `UIPanGestureRecognizer` sur LA FENÊTRE — elle voit TOUS
/// les touchers, quelle que soit la hit-view. Les TAPS restent aux vues
/// SwiftUI (glyphes → aller, dalle → ouvrir, mini → déployer) : un pan
/// coopératif (`simultaneous → true`) ne begin que sur un vrai
/// mouvement, un tap pur ne l'arme jamais.
///
/// LA GÉOMÉTRIE vient de `NavEtat` : la SEULE `PageCard` visible publie
/// le rect fenêtre de sa bande (+ enSeance, + bandeVisible). La porte
/// du pan refuse tout toucher hors de ce rect — et tout toucher né dans
/// la bande SYSTÈME du bas (`safeAreaInsets.bottom`) : c'est la parade
/// géométrique honnête contre Reachability/Home (le tap immobile de
/// dépli reste disponible partout, lui n'est jamais volé).
///
/// LE ROUTAGE (verrouillé au lever, l'école de la rafale) :
///   · départ DALLE + drag UP   → le player (`suivreDelta`) ;
///   · départ DALLE + drag DOWN → le REPLI (fini l'overlay surprise) ;
///   · départ GRABBER ou NAV    → repli/dépli, les deux sens.
/// ⚠️ `PlayerMonde.swift` : ZÉRO ligne touchée.
struct NavPanHote: UIViewRepresentable {

    final class Coord: NSObject, UIGestureRecognizerDelegate {
        /// La fenêtre déjà équipée — le pan ne se pose qu'UNE fois
        /// (static PROPRE à cette classe, jamais celui du player).
        static weak var fenetrePosee: UIWindow?
        weak var sonde: UIView?
        weak var fenetre: UIWindow?
        weak var panPose: UIPanGestureRecognizer?

        enum Mode { case indecis, player }
        enum Zone { case grabber, dalle, nav }
        var mode: Mode = .indecis
        var tyAncre: CGFloat = 0
        var rAncre: CGFloat = 0
        let crie = CommandLine.arguments.contains("-gesteSonde")

        func retirer() {
            if let p = panPose, let w = fenetre {
                w.removeGestureRecognizer(p)
            }
            if Coord.fenetrePosee === fenetre { Coord.fenetrePosee = nil }
        }

        private func zoneDe(_ yLocal: CGFloat) -> Zone {
            if yLocal < BandeCote.grab { return .grabber }
            if NavEtat.shared.bandeEnSeance,
               yLocal < BandeCote.grab + BandeCote.dalle { return .dalle }
            return .nav
        }

        // LA PORTE — lue à la POSE du toucher, jamais en cours de geste.
        // `monte` couvre vol d'ouverture + posé + vol de fermeture du
        // player ; le rect vient de la PageCard visible ; le strip
        // système du bas est REFUSÉ (un drag doit naître au-dessus —
        // c'est la seule parade réelle contre Reachability, dite
        // honnêtement : les derniers pt du bas restent au tap).
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldReceive t: UITouch) -> Bool {
            guard !PlayerEtat.shared.monte,
                  !DepartEtat.shared.pauseOuverte,
                  NavEtat.shared.bandeVisiblePubliee,
                  let w = fenetre else { return false }
            let rect = NavEtat.shared.bandeRectFenetre
            guard rect != .zero else { return false }
            let p = t.location(in: w)
            // Le plancher est PHYSIQUE (le strip des gestes système, sous
            // la ligne de zone sûre), plus jamais relatif au rect : depuis
            // le 04-09 la bande vit ENTIÈREMENT au-dessus de cette ligne
            // (descente morte) — un rect-relatif aurait amputé la rangée
            // de points pour rien.
            let plancher = w.bounds.maxY - w.safeAreaInsets.bottom
            let ok = rect.contains(p) && p.y < plancher
            if crie, ok {
                print("GESTE-SONDE bande RECOIT p=(\(Int(p.x)),\(Int(p.y))) "
                    + "rect=(\(Int(rect.minY))-\(Int(rect.maxY)))")
            }
            return ok
        }

        // LA DÉCISION, avant de consommer le doigt : un refus ici REND
        // le toucher intact (latéral → le TabView, les taps glissés).
        func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer)
            -> Bool {
            guard let pan = g as? UIPanGestureRecognizer,
                  let w = fenetre else { return false }
            let t = pan.translation(in: w)
            guard abs(t.y) >= abs(t.x) else { return false }
            // La zone au POINT DE POSE, en coordonnées de bande.
            let pose = CGPoint(x: pan.location(in: w).x - t.x,
                               y: pan.location(in: w).y - t.y)
            let yLocal = pose.y - NavEtat.shared.bandeRectFenetre.minY
            let zone = zoneDe(yLocal)
            // ⚠️ LE REPLI EST MORT (pivot 04-09) : la nav ne se drague
            // PLUS — plus de mini, plus de card qui bouge. Le pan ne sert
            // qu'à la DALLE du player (drag vers le haut = ouvrir). Tout
            // autre départ REFUSE, et le toucher repart intact.
            guard zone == .dalle, t.y < 0 else {
                if crie { print("GESTE-SONDE bande LAISSE (\(zone))") }
                return false
            }
            mode = .player
            if crie { print("GESTE-SONDE bande DÉCIDE player/dalle") }
            return true
        }

        @objc func pan(_ g: UIPanGestureRecognizer) {
            guard let w = fenetre else { return }
            let ty = g.translation(in: w).y
            switch g.state {
            case .began:
                tyAncre = ty
                suivre(ty)
            case .changed:
                suivre(ty)          // UNE FOIS DÉCIDÉ, ON NE CHANGE PLUS.
            case .ended, .cancelled, .failed:
                // `.cancelled` = le vol système : commit IMMÉDIAT à la
                // vélocité — les chiens des moteurs restent le filet.
                let vy = g.velocity(in: w).y
                switch mode {
                case .player: PlayerEtat.shared.commettre(velocite: vy)
                case .indecis: break
                }
                if crie { print("GESTE-SONDE bande COMMET v=\(Int(vy))") }
                mode = .indecis
            default: break
            }
        }

        private func suivre(_ ty: CGFloat) {
            switch mode {
            case .player:
                PlayerEtat.shared.suivreDelta(-(ty - tyAncre))
            case .indecis: break
            }
        }

        // COOPÉRATIF, comme le maître du player : les recognizers de tap
        // tournent indépendamment ; un tap pur n'arme jamais le pan
        // (aucun mouvement), un vrai drag fait échouer le tap de
        // lui-même (mouvement) — zéro double-action.
        func gestureRecognizer(
            _ g: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith o: UIGestureRecognizer
        ) -> Bool { true }
    }

    func makeCoordinator() -> Coord { Coord() }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false      // une SONDE, jamais une cible
        context.coordinator.sonde = v
        return v
    }

    func updateUIView(_ v: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let w = v.window, Coord.fenetrePosee !== w else { return }
            let pan = UIPanGestureRecognizer(
                target: context.coordinator,
                action: #selector(Coord.pan(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = context.coordinator
            w.addGestureRecognizer(pan)
            Coord.fenetrePosee = w
            context.coordinator.panPose = pan
            context.coordinator.fenetre = w
            if context.coordinator.crie {
                print("GESTE-SONDE bande POSÉ sur la fenêtre")
            }
        }
    }

    static func dismantleUIView(_ v: UIView, coordinator: Coord) {
        coordinator.retirer()
    }
}
