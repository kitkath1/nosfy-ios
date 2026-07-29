import SwiftUI

/// La comète qui avance VRAIMENT sur l'écran verrouillé.
///
/// Une Live Activity ne peut pas exécuter d'animation à elle : la seule chose
/// que le système anime en continu, ce sont ses jauges (`ProgressView(timerInterval:)`).
/// Le hack : superposer deux jauges sur le même axe — la première dessine le
/// parcouru, la seconde, en retard de quelques secondes et fondue en
/// `destinationOut`, l'efface. Ce qui survit est la différence : un segment
/// de lumière qui se déplace, dont le bord droit est la tête de la comète.
/// Trois paires empilées à des retards croissants et des opacités
/// décroissantes font la queue graduée.
///
/// La comète traverse le filament en `span` secondes (90 min par défaut : la
/// position raconte l'avancement de la séance, comme une aiguille de montre).
struct ProgressComet: View {
    let startedAt: Date
    /// Temps de traversée complète du filament.
    var span: TimeInterval = 90 * 60

    var body: some View {
        ZStack {
            // Le filament : la ligne de vie, éteinte aux deux bouts.
            Rectangle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.13), location: 0.25),
                            .init(color: .white.opacity(0.13), location: 0.75),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 1)

            // Le halo : la même paire, étirée en hauteur — pas de blur en
            // Live Activity, l'empilement d'échelles fait la lueur.
            cometLayer(tail: 70, opacity: 0.07)
                .scaleEffect(x: 1, y: 7, anchor: .center)
            cometLayer(tail: 40, opacity: 0.14)
                .scaleEffect(x: 1, y: 3.4, anchor: .center)

            // La queue, du plus diffus au plus vif, la tête en dernier.
            cometLayer(tail: 420, opacity: 0.14)
            cometLayer(tail: 170, opacity: 0.30)
            cometLayer(tail: 55, opacity: 0.65)
            cometLayer(tail: 16, opacity: 1.0)
            cometLayer(tail: 16, opacity: 1.0)
        }
    }

    /// Une paire jauge/gomme : ce qui reste est le segment [tête - tail ; tête].
    private func cometLayer(tail: TimeInterval, opacity: Double) -> some View {
        ZStack {
            bar(delay: 0)
                .tint(.white)
            bar(delay: tail)
                .tint(.white)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .opacity(opacity)
    }

    /// Une jauge nue démarrée `delay` secondes après la séance : à l'instant t
    /// elle est remplie à (t − début − delay) / span.
    private func bar(delay: TimeInterval) -> some View {
        ProgressView(timerInterval: startedAt.addingTimeInterval(delay)
                        ... startedAt.addingTimeInterval(delay + span),
                     countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
            .progressViewStyle(.linear)
    }
}
