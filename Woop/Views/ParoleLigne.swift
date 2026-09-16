import SwiftUI
import UIKit

/// Le phrasé de MotsFlou (onboarding), dans une seule ligne. La lecture se
/// termine au dernier mot et s'annule hors écran ; aucune boucle au repos.
struct ParoleLigne: View {
    var texte: String
    var replique: String
    var taille: CGFloat
    var tracking: CGFloat
    var opacite: Double
    var retard: Double
    var active: Bool
    @State private var poses = false
    @State private var derniereLecture: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private struct Lecture: Equatable {
        var replique: String
        var active: Bool
        var reduite: Bool
    }
    private var visible: Bool {
        active && scenePhase == .active
            && !DepartEtat.shared.welcomeOuverte && !DepartEtat.shared.welcomePremiereOuverte
    }

    var body: some View {
        // Une nouvelle réplique est floue dès sa première image ; aucun flash
        // du texte complet avant le démarrage de la tâche. Hors écran : pose nette.
        let net = !visible || reduceMotion || (poses && derniereLecture == replique)
        let mots = MotsFlou.partition([(texte, true)], base: retard)
        let font = UIFont(name: "Inter-SemiBold", size: taille)
            ?? .systemFont(ofSize: taille, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .kern: tracking]
        let espace = (" " as NSString).size(withAttributes: attrs).width
        let largeur = mots.reduce(CGFloat(0)) { $0 + ($1.texte as NSString).size(withAttributes: attrs).width }
            + CGFloat(max(0, mots.count - 1)) * espace
        GeometryReader { geo in
            HStack(spacing: espace) {
                ForEach(Array(mots.enumerated()), id: \.offset) { _, mot in
                    Text(mot.texte)
                        .font(.inter(taille, .semibold))
                        .tracking(tracking)
                        .foregroundStyle(.white.opacity(opacite))
                        .lineLimit(1)
                        .fixedSize()
                        .contentTransition(.numericText())
                        .blur(radius: net ? 0 : 12)
                        .opacity(net ? 1 : 0)
                        .scaleEffect(net ? 1 : 0.96)
                        .offset(y: net ? 0 : 5)
                        .animation(!visible || reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1,
                            duration: 1.05).delay(mot.retard), value: poses)
                        .animation(!visible || reduceMotion ? nil : .easeOut(duration: 0.25), value: mot.texte)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .scaleEffect(min(1, geo.size.width / max(largeur, 1)), anchor: .leading)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
        }
        .allowsHitTesting(false)
        .task(id: Lecture(replique: replique, active: visible, reduite: reduceMotion)) {
            guard visible, !reduceMotion else { poserSansAnimation(true); return }
            guard derniereLecture != replique else { poserSansAnimation(true); return }
            derniereLecture = replique
            poserSansAnimation(false)
            do { try await Task.sleep(for: .milliseconds(30)) } catch { return }
            guard !Task.isCancelled else { return }
            poses = true
            // Un impact SOFT par mot, pas par lettre. Le générateur et cette
            // tâche ne survivent pas à la réplique.
            let haptique = UIImpactFeedbackGenerator(style: .soft)
            var precedent = 0.0
            for mot in mots {
                do { try await Task.sleep(for: .seconds(max(0, mot.retard - precedent))) }
                catch { return }
                guard !Task.isCancelled, visible else { return }
                haptique.impactOccurred(intensity: 0.28)
                precedent = mot.retard
            }
        }
    }

    private func poserSansAnimation(_ valeur: Bool) {
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { poses = valeur }
    }

    static func retard(apres fragments: [PhraseFragment]) -> Double {
        guard !fragments.isEmpty else { return 0 }
        // Le premier mot du fragment suivant donne exactement la pause du film.
        let suite = MotsFlou.partition(fragments.map { ($0.texte, $0.clair) } + [("suite", true)])
        return suite.last?.retard ?? 0
    }
}
