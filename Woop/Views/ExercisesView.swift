import SwiftUI

struct ExercisesView: View {
    @State private var filter: ExerciseCategory?

    /// Ouvre une fiche dès le lancement : `-openExercise woop-haute`. Même
    /// usage que `-openTab` et `-openActiveSheet` (captures d'écran
    /// automatisées uniquement) — sans ça, la fiche n'est atteignable qu'au
    /// doigt, et le simulateur ne se pilote pas en ligne de commande.
    @State private var deepLinked: Exercise?

    private var shown: [ExerciseCategory] {
        filter.map { [$0] } ?? ExerciseCategory.allCases
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // EXACTEMENT le même ciel que la home : horloge globale, état
                // partagé (scroll, révélation, gyro) — changer d'onglet ne
                // change rien. Un onglet caché n'est pas rendu : coût nul.
                WoopBackground(animated: true)
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        Text("Construis tes séances à partir de ta bibliothèque.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Color.inkSecondary)

                        CategoryFilter(selection: $filter)

                        ForEach(shown) { category in
                            VStack(alignment: .leading, spacing: 14) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(category.rawValue)
                                        .font(.system(.title3, design: .rounded, weight: .semibold))
                                        .foregroundStyle(Color.inkPrimary)
                                    Text(category.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(Color.inkMuted)
                                }

                                LazyVGrid(
                                    columns: [GridItem(.flexible(), spacing: 14),
                                              GridItem(.flexible(), spacing: 14)],
                                    spacing: 14
                                ) {
                                    ForEach(ExerciseCatalog.exercises(in: category)) { exercise in
                                        NavigationLink {
                                            ExerciseDetailView(exercise: exercise)
                                        } label: {
                                            ExerciseCard(exercise: exercise)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 130)
                }
            }
            .navigationTitle("Exercices")
            .navigationDestination(item: $deepLinked) { ExerciseDetailView(exercise: $0) }
            .task {
                if let id = UserDefaults.standard.string(forKey: "openExercise") {
                    deepLinked = ExerciseCatalog.exercise(id: id)
                }
            }
        }
    }
}

// MARK: - Filtre de catégorie

struct CategoryFilter: View {
    @Binding var selection: ExerciseCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "Tout", isOn: selection == nil) { selection = nil }
                ForEach(ExerciseCategory.allCases) { category in
                    FilterChip(title: category.rawValue, isOn: selection == category) {
                        selection = selection == category ? nil : category
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private struct FilterChip: View {
        let title: String
        let isOn: Bool
        let action: () -> Void

        var body: some View {
            Button(action: { withAnimation(.easeOut(duration: 0.2)) { action() } }) {
                Text(title)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(isOn ? Color.white : Color.inkSecondary)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(isOn ? AnyShapeStyle(WoopGradient.neonFill)
                                            : AnyShapeStyle(Color.white.opacity(0.045)))
                    )
                    .overlay(
                        Capsule().strokeBorder(
                            isOn ? Color.white.opacity(0.35) : Color.white.opacity(0.09),
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Carte d'exercice

struct ExerciseCard: View {
    let exercise: Exercise

    private static let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Bord à bord, sans marge : le noir de la photo EST le noir de la
            // carte, une marge ne séparerait rien de rien — elle ne ferait que
            // rapetisser le corps.
            ExercisePhoto(exercise: exercise)
                .frame(height: 152)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.inter(12.5, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                    .fixedSize(horizontal: false, vertical: true)

                Text(exercise.muscle)
                    .font(.inter(10))
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(1)

                Text(exercise.equipment.rawValue.uppercased())
                    .font(.inter(8, .bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.32))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.05)))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 14)
            .padding(.top, 11)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(Self.shape)
        .diamondSurface(cornerRadius: 22)
    }
}
