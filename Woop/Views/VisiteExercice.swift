import SwiftUI

/// Une seule invitation après le décompte. La vraie carte reste accessible ;
/// la brume et le phrasé reprennent la visite d'accueil, sans horloge continue.
struct VisiteExercice: View {
    let ancre: Anchor<CGRect>
    var onPasser: () -> Void

    var body: some View {
        GeometryReader { ext in
            GeometryReader { g in
                let carte = g[ancre]
                let poche = carte.insetBy(dx: -18, dy: -18)
                let largeur = min(300, g.size.width - 48)
                ZStack {
                    BrumeVisite(rect: poche, rayon: 38, fondu: 100,
                                opacite: 1, flou1: false)
                    Color.clear
                        .contentShape(.interaction,
                                      PerceVisite(rect: poche, rayon: 38), eoFill: true)
                        .onTapGesture(perform: onPasser)

                    VStack(alignment: .leading, spacing: 10) {
                        MotsFlou([(L("Choisissez un exercice", "Choose an exercise"), true)],
                                 taille: 32)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(L("Choisissez un exercice", "Choose an exercise"))
                            .accessibilityIdentifier("visite-exercice-titre")
                        MotsFlou([(L("Il s’ajoutera à votre séance.", "It will be added to your session."), false)],
                                 taille: 17,
                                 base: MotsFlou.duree([(L("Choisissez un exercice", "Choose an exercise"), true)]) - 0.3)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(L("Il s’ajoutera à votre séance.", "It will be added to your session."))
                            .accessibilityIdentifier("visite-exercice-description")
                    }
                        .frame(width: largeur, height: 150, alignment: .topLeading)
                        .position(x: 24 + largeur / 2,
                                  y: min(poche.maxY + 120, g.size.height - ext.safeAreaInsets.bottom - 100))
                        .allowsHitTesting(false)

                    Button(action: onPasser) {
                        Text(L("Passer", "Skip"))
                            .font(.inter(15, .medium))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(minWidth: 60, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: 46, y: ext.safeAreaInsets.top + 22)
                    .accessibilityIdentifier("visite-exercice-passer")
                }
            }
            .ignoresSafeArea()
        }
    }
}
