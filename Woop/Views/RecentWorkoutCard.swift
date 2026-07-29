import SwiftUI

// MARK: - Carte carrée « dernier entraînement »

/// Carré de verre noir : pastille d'icône en haut, date et résumé en bas.
/// Au repos la carte suit le token de lumière de la scène (biseau bas-gauche).
/// Au toucher elle devient sa propre source : le contour s'embrase d'un halo
/// blanc qui déborde sur le ciel, puis s'éteint lentement au relâcher.
struct RecentWorkoutCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IconBadge(symbol: symbol)

            Spacer(minLength: 12)

            Text(workout.relativeDateLabel)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)

            Text(workout.rowSummary)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.inkMuted)
                .lineLimit(2)
                .padding(.top, 5)
        }
        .padding(17)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
    }

    /// Une silhouette par dominante de séance — la première catégorie gagne.
    private var symbol: String {
        switch workout.categories.first {
        case .cardio: return "figure.run"
        case .abdos: return "figure.core.training"
        case .fessiers: return "figure.strengthtraining.functional"
        case nil: return "dumbbell"
        }
    }
}

// MARK: - Pastille d'icône

/// Petit disque de verre à peine plus clair que la carte. L'icône est un trait
/// blanc, pas une couleur : la carte reste monochrome jusqu'au toucher.
struct IconBadge: View {
    let symbol: String
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.085), .white.opacity(0.015)],
                        center: .top, startRadius: 1, endRadius: size
                    )
                )
            Circle()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.30), location: 0.0),
                            .init(color: .white.opacity(0.05), location: 0.45),
                            .init(color: .white.opacity(0.0), location: 1.0)
                        ],
                        startPoint: .bottomLeading, endPoint: .topTrailing
                    ),
                    lineWidth: 1
                )
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.88))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Style à halo

/// Habille le label (surface noire, biseau) et pilote l'embrasement avec
/// `isPressed` : ligne vive sur le contour + trois couronnes floutées qui
/// débordent de la carte. L'allumage est immédiat, l'extinction traîne —
/// une braise, pas un interrupteur.
struct RecentCardGlowStyle: ButtonStyle {
    var cornerRadius: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        configuration.label
            .background {
                ZStack {
                    // Plus sombre que le métal des grandes cartes : ces carrés
                    // sont taillés dans le noir, la lumière n'y vit que sur
                    // les arêtes.
                    shape.fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.070, green: 0.070, blue: 0.090), location: 0.0),
                                .init(color: Color(red: 0.040, green: 0.040, blue: 0.056), location: 0.5),
                                .init(color: Color(red: 0.024, green: 0.024, blue: 0.035), location: 1.0)
                            ],
                            startPoint: UnitPoint(x: 0.2, y: 0.0),
                            endPoint: UnitPoint(x: 0.8, y: 1.0)
                        )
                    )
                    shape.fill(WoopGradient.specular)

                    // Au toucher l'intérieur se soulève à peine : la lumière
                    // du contour se réfléchit dans le verre.
                    shape.fill(
                        RadialGradient(
                            colors: [.white.opacity(0.075), .white.opacity(0.015)],
                            center: UnitPoint(x: 0.5, y: 0.1),
                            startRadius: 0, endRadius: 240
                        )
                    )
                    .opacity(pressed ? 1 : 0)
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.65), radius: 18, y: 12)
            }
            .overlay {
                // Biseau de repos — même token de lumière que le reste de la
                // scène (azimut ~225°).
                shape.strokeBorder(WoopGradient.bevel, lineWidth: 1)
                    .opacity(pressed ? 0 : 1)
            }
            .overlay {
                // L'embrasement : une ligne vive et trois couronnes de plus en
                // plus larges et diffuses. Les strokes sont centrés sur le
                // contour pour que le halo déborde réellement de la carte.
                ZStack {
                    shape.stroke(Color.white.opacity(0.95), lineWidth: 1.2)
                    shape.stroke(Color.white.opacity(0.55), lineWidth: 3)
                        .blur(radius: 3)
                    shape.stroke(Color.white.opacity(0.34), lineWidth: 7)
                        .blur(radius: 9)
                    shape.stroke(Color.white.opacity(0.22), lineWidth: 12)
                        .blur(radius: 22)
                }
                .opacity(pressed ? 1 : 0)
                .allowsHitTesting(false)
            }
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(pressed ? .easeOut(duration: 0.14) : .easeOut(duration: 0.55),
                       value: pressed)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: pressed) { _, new in new }
    }
}
