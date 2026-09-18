import SwiftUI

/// La synthèse écrite par Claude. Rien n'est appelé tant que Kathryn n'a pas
/// touché le bouton : pas de requête au chargement de l'onglet.
struct SynthesisCard: View {
    let workouts: [Workout]
    var period: Timeframe = .week

    @State private var service = SynthesisService()

    var body: some View {
        WoopCard(neon: service.state != .idle) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.woopVioletCore.opacity(0.18))
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.woopViolet)
                            .neonGlow(radius: 8, opacity: 0.6)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Ce que ta semaine raconte")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text(period == .week ? "Analyse de tes 7 derniers jours"
                                             : "Analyse du mois en cours")
                            .font(.caption)
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                }

                content

                Button {
                    Task { await service.generate(from: workouts, period: period) }
                } label: {
                    Label(
                        service.state == .idle ? "Générer la synthèse" : "Régénérer",
                        systemImage: "wand.and.stars"
                    )
                }
                .buttonStyle(WoopSecondaryButtonStyle())
                .disabled(service.state == .loading)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch service.state {
        case .idle:
            Text("Claude relit tes séances et te dit ce qui progresse, ce qui stagne, et quoi viser ensuite.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Color.inkMuted)

        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.woopViolet)
                Text("Analyse en cours…")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Color.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .ready(let text):
            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)

        case .failed(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.woopGold)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
