import Combine
import SwiftUI

// MARK: - Exercice lancé

/// La page d'effort : noir absolu, un anneau de lumière qui s'allume toutes les
/// cinq secondes, le chrono en pointillisme au centre.
///
/// C'est le seul écran de l'app qui rompt avec le ciel — ni nébuleuse, ni
/// brume, ni violet. La profondeur ne vient pas d'un décor mais de son absence :
/// du noir absolu, et de la lumière posée dessus. Un fond `woopBase` (1,6 %)
/// suffirait à casser l'effet sur OLED.
///
/// Rien n'est écrit dans la base tant que « Terminer » n'a pas été touché :
/// toute la session vit ici, en mémoire. C'est ce qui rend l'annulation
/// gratuite — aucune séance fantôme à nettoyer.
struct LiveExerciseView: View {
    let exercise: Exercise
    /// Le rang de la série en cours, à partir de 1.
    let seriesNumber: Int
    /// Ce qui est visé — « 12 reps · 20 kg ». Réglé avant de lancer, donc le
    /// compteur n'a plus qu'à mesurer : rien ne reste à inventer après coup.
    let target: String
    /// Appelé avec la durée écoulée, en secondes.
    let onFinish: (Int) -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// La seule source de vérité du temps. Tout le reste s'en déduit — jamais
    /// d'accumulation image par image, donc revenir d'arrière-plan affiche la
    /// bonne valeur sans le moindre rattrapage.
    @State private var startedAt = Date.now
    /// Échantillonné à 4 Hz. Ne sert QU'À l'haptique et à VoiceOver : l'affichage,
    /// lui, lit l'horloge en continu dans le cadran.
    @State private var tick = 0
    @State private var confirmCancel = false

    /// En deçà, annuler ne demande rien : personne ne perd trois secondes.
    private static let confirmThreshold = 20

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LightDial(startedAt: startedAt, calm: reduceMotion)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Les halos sont des dégradés sombres : sur OLED ils bandent sans
            // tramage, exactement comme les nappes du ciel.
            WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                footer
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        // Un écran qui s'éteint au bout de trente secondes rend la page inutile.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onReceive(Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()) { _ in
            let value = Int(Date.now.timeIntervalSince(startedAt))
            if value != tick { tick = value }
        }
        // Le premier tour se présente : un allumage se sent. Ensuite, plus rien
        // qu'au passage de la minute — cent vingt vibrations sur dix minutes,
        // c'est une nuisance, pas une signature.
        .sensoryFeedback(.impact(weight: .light, intensity: 0.45), trigger: hapticStep)
        .alert("Annuler cette série ?", isPresented: $confirmCancel) {
            Button("Continuer l'effort", role: .cancel) {}
            Button("Annuler", role: .destructive) { onCancel() }
        } message: {
            Text("La série ne sera pas validée : les \(spokenElapsed) écoulées seront perdues.")
        }
    }

    // MARK: Habillage

    private var header: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 5) {
                Text("Série \(seriesNumber)".uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.34))
                if !target.isEmpty {
                    Text(target)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.62))
                }
                Text(exercise.name)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .lineLimit(1)
            }
            .padding(.horizontal, 70)

            HStack {
                Button("Annuler") { cancel() }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.42))
                    .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var footer: some View {
        Button { onFinish(max(0, tick)) } label: {
            Text("Terminer")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(Capsule().fill(Color.white.opacity(0.055)))
                // Pas de verre liquide ici : il n'y a rien derrière à réfracter.
                // Un filet de lumière sur le noir dit mieux « bouton » qu'un
                // matériau qui n'a rien à traverser.
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.17), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 30)
        .padding(.bottom, 34)
        // Le cadran est un Canvas, donc muet. Une seule étiquette parlante pour
        // toute la page, rafraîchie à chaque seconde.
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Terminer la série \(seriesNumber). \(spokenElapsed) écoulées.")
    }

    // MARK: Logique

    private var spokenElapsed: String { LightDial.spoken(max(0, tick)) }

    /// Chaque allumage pendant le premier tour, puis un seul par tour.
    private var hapticStep: Int {
        let step = tick / 5
        return step < 12 ? step : 12 + tick / 60
    }

    private func cancel() {
        if tick >= Self.confirmThreshold {
            confirmCancel = true
        } else {
            onCancel()
        }
    }
}
