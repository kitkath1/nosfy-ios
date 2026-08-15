import SwiftUI

// MARK: - La ligne d'historique d'une série

/// LA LIGNE DE LA FICHE, née de `StorySetRow` (la story 2) — même gabarit
/// de 58 pt, même lune noire sur son halo, même pièce gelée. Deux choses en
/// plus que la story n'avait pas besoin de savoir : l'état « À VENIR »
/// (la story ne montre que du vécu) et la métrique TEMPS. La story garde
/// sa ligne à elle : deux montages, deux vies — on ne réécrit pas une page
/// commitée pour en habiller une autre.
///
/// À venir : tout baisse d'un ton — les encres s'éteignent, le halo de la
/// lune meurt, et le gain devient une promesse (« À venir ») au lieu d'un
/// chiffre d'or.
struct SetHistoryRow: View {
    let rank: Int
    let reps: Int
    let kilos: Double
    /// Les secondes affichées : le temps sous tension pour une série faite,
    /// le repos prévu pour une série à venir.
    let seconds: Int
    let done: Bool
    var coins: Int = CoffreFortPurse.perSeries

    var body: some View {
        HStack(spacing: 12) {
            moon

            Text("Série \(rank)")
                .font(.inter(15, .medium))
                .foregroundStyle(Color.white.opacity(done ? 0.94 : 0.55))
                .lineLimit(1)
                .fixedSize()

            Spacer(minLength: 6)

            // fixedSize : les métriques ne se REPLIENT jamais — à
            // l'étroit, c'est le titre qui cède (payé : les valeurs
            // passaient à la ligne dans la vraie fiche).
            HStack(spacing: 8) {
                metric("\(reps)", "reps")
                sep
                metric(kiloText, "kg")
                sep
                metric("\(seconds)", "s")
            }
            .fixedSize()
            .layoutPriority(1)

            Spacer(minLength: 6)

            gain
                .fixedSize()
                .layoutPriority(1)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        // 58 → 66 : 4 pt d'air de plus en haut et en bas (15-08) — les
        // petites cartes noires respirent dans la carte dépliée.
        .frame(height: 66)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.black.opacity(done ? 0.72 : 0.55),
                             Color.black.opacity(done ? 0.50 : 0.40)],
                    startPoint: .top, endPoint: .bottom))
        }
        .overlay {
            // Le filet en lumière rasante de la story : franc en haut à
            // gauche, éteint en bas à droite — jamais un contour fermé.
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(LinearGradient(
                    stops: [.init(color: .white.opacity(done ? 0.16 : 0.09),
                                  location: 0),
                            .init(color: .white.opacity(0.04),
                                  location: 0.38),
                            .init(color: .white.opacity(0.0), location: 1)],
                    startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(done
            ? "Série \(rank) faite : \(reps) répétitions, \(kiloText) kilos"
            : "Série \(rank) à venir")
    }

    /// La lune noire de la maison — le halo ne brûle que pour le vécu.
    private var moon: some View {
        ZStack {
            if done {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(red: 1.0, green: 0.46, blue: 0.09)
                            .opacity(0.15), .clear],
                        center: .center, startRadius: 5, endRadius: 15))
            }
            MoonShape()
                .fill(LinearGradient(
                    colors: [Color(red: 0.085, green: 0.078, blue: 0.072),
                             Color(red: 0.022, green: 0.021, blue: 0.020)],
                    startPoint: .top, endPoint: .bottom))
                .overlay {
                    MoonShape()
                        .stroke(Color(red: 1.0, green: 0.56, blue: 0.18)
                            .opacity(done ? 0.40 : 0.16), lineWidth: 0.6)
                }
                .frame(width: 15, height: 15)
        }
        .frame(width: 32, height: 32)
    }

    /// Le gain — la pièce GELÉE de la maison (draggable: false obligatoire,
    /// une TimelineView par pièce ferait une horloge par ligne). À venir :
    /// pas de pièce, une promesse d'encre.
    @ViewBuilder
    private var gain: some View {
        if done {
            HStack(spacing: 5) {
                Text("+\(coins)")
                    .font(.inter(14, .semibold))
                    .foregroundStyle(Color.woopGold.opacity(0.92))
                    .monospacedDigit()
                MoonCoinView(coinR: 13, draggable: false, yawOverride: 0.34,
                             idleLife: 0, fps: 6, reveal: 0.34, matte: 1)
                    // Le double cadre : l'extérieur porte le bloom du
                    // shader, l'intérieur décide de l'encombrement.
                    .frame(width: 13 * MoonCoinView.hostScale,
                           height: 13 * MoonCoinView.hostScale)
                    .frame(width: 28, height: 28)
            }
        } else {
            Text("À venir")
                .font(.inter(12))
                .foregroundStyle(Color.white.opacity(0.35))
                .frame(height: 28)
        }
    }

    private var sep: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 11)
    }

    private func metric(_ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.inter(14, .medium))
                .foregroundStyle(Color.white.opacity(done ? 0.80 : 0.45))
                .monospacedDigit()
            Text(unit)
                .font(.inter(10.5))
                .foregroundStyle(Color.white.opacity(done ? 0.38 : 0.22))
        }
    }

    private var kiloText: String {
        kilos == kilos.rounded()
            ? String(Int(kilos)) : String(format: "%.1f", kilos)
    }
}
