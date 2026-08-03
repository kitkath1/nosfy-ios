import SwiftUI
import SwiftData

/// Le quatrième onglet. Il existe d'abord pour une raison de COMPOSITION : à
/// quatre onglets, deux de chaque côté, le bouton de séance tombe exactement au
/// centre de la barre. À trois, il serait décentré et la barre bancale.
///
/// Il ne contient donc que ce qui est déjà vrai dans l'app — le numéro retenu à
/// la connexion, l'objectif de la semaine, le compte des séances. Rien
/// d'inventé : une page qui promet des réglages absents est pire qu'une page
/// courte.
struct ProfileView: View {
    @Query(sort: \Workout.startedAt, order: .reverse) private var workouts: [Workout]

    private var finished: [Workout] { workouts.filter { !$0.isActive } }
    private var phone: String? {
        UserDefaults.standard.string(forKey: "woop.phone")
    }

    /// Les séances de la semaine en cours.
    private var thisWeek: Int {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: .now) else { return 0 }
        return finished.filter { interval.contains($0.startedAt) }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // EXACTEMENT le même ciel que les autres onglets : horloge
                // globale, état partagé — changer d'onglet ne change rien.
                WoopBackground(animated: true)
                ScrollView {
                    VStack(spacing: 18) {
                        identityCard
                        goalCard
                        totalCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Profil")
        }
    }

    private var identityCard: some View {
        WoopCard {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.07)).frame(width: 52, height: 52)
                    Image(systemName: "person.fill")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(phone ?? "Pas encore connectée")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(phone == nil ? "Le numéro s'enregistre à la connexion."
                                      : "Numéro retenu sur cet appareil.")
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
            }
        }
    }

    private var goalCard: some View {
        WoopCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.woopGold.opacity(0.14)).frame(width: 44, height: 44)
                    Image(systemName: "target")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.woopGold)
                        .neonGlow(.woopGold, radius: 7, opacity: 0.5)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(thisWeek) / \(Goal.weeklyTarget) cette semaine")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Objectif hebdomadaire.")
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
            }
        }
    }

    private var totalCard: some View {
        WoopCard(cornerRadius: 18, padding: 18) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.woopVioletCore.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.woopViolet)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(finished.count) séance\(finished.count > 1 ? "s" : "") terminée\(finished.count > 1 ? "s" : "")")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Depuis le début.")
                        .font(.caption)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer()
            }
        }
    }
}
