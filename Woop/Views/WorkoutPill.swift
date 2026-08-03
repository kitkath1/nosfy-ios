import SwiftUI

// MARK: - La pastille de séance en cours

/// La pastille noire incrustée sous la carte blanche de la fiche — l'UI du
/// mini-player de la référence, reprise TELLE QUELLE même si elle parle
/// musique : vignette, titre, sous-titre, pause, cœur, filet de progression.
/// Le composant sera retravaillé plus tard pour parler entraînement ; ici on
/// copie la référence, on n'interprète pas.
///
/// Sur la page noire, la pastille n'existe que par deux choses : l'échancrure
/// de la carte blanche qui la dessine en négatif, et le soulèvement obsidienne
/// — un noir à peine remonté sous un cheveu de lumière. Sans lui, dès que
/// l'œil quitte le blanc, la pierre disparaît dans la page.
struct WorkoutPill: View {
    let exercise: Exercise
    /// Fraction de la séance accomplie, pour le filet de progression.
    var progress: Double = 0

    /// Pause et cœur : des PLACEHOLDERS assumés — l'état est purement visuel,
    /// le composant sera rebranché quand il sera retravaillé.
    @State private var paused = false
    @State private var loved = false

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        HStack(spacing: 12) {
            ExercisePhoto(exercise: exercise)
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.inter(14, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text("Entraînement en cours")
                    .font(.inter(11))
                    .foregroundStyle(Color.inkMuted)
            }

            Spacer(minLength: 8)

            roundButton(paused ? "play.fill" : "pause.fill") { paused.toggle() }
            roundButton(loved ? "heart.fill" : "heart") { loved.toggle() }
        }
        .padding(.leading, 11)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background(shape.fill(Color(white: 0.045)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        // Le filet de progression, posé sur le bord bas comme dans la
        // référence : un cheveu, pas une barre.
        .overlay(alignment: .bottom) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule().fill(Color.white.opacity(0.85))
                        .frame(width: geo.size.width
                               * min(max(progress, 0.04), 1))
                }
            }
            .frame(height: 2.5)
            .padding(.horizontal, 14)
            .padding(.bottom, 7)
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Entraînement en cours — \(exercise.name)")
    }

    private func roundButton(_ symbol: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color.white.opacity(0.10)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.08),
                                               lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
