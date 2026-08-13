import SwiftUI

// MARK: - Banc de la flamme-jauge (`-jaugeLab`)

/// Page noire nue, la carte seule au centre. La série avance TOUTE SEULE
/// toutes les 2,6 s (1 → 5, puis retour) pour juger l'allumage des petites
/// flammes, le compte qui roule et la poussée de la braise — et un toucher
/// sur la carte avance à la main, comme le sous-titre l'invite.
struct FlammeJaugeLab: View {
    @State private var done = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            FlammeJauge(done: done)
                .padding(.horizontal, 16)
                .contentShape(Rectangle())
                .onTapGesture { avance() }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                avance()
            }
        }
    }

    private func avance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            done = done % 5 + 1
        }
    }
}
