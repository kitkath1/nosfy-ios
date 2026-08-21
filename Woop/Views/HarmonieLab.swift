import SwiftUI

// MARK: - LA CONSOLE D'HARMONIE — `-harmonie`
//
// Les trois objets de la home (les deux cards et l'ardoise de la semaine) sur
// leur VRAI fond vidéo, avec les interrupteurs qui séparent leurs micro-écarts.
// Sans le fond, aucun de ces réglages ne se juge : un liseré sur du noir de
// laboratoire ne dit rien de ce qu'il fait sur la nappe de flamme.
//
// LES TROIS ÉCARTS QUE LA CONSOLE ISOLE :
//
//  1. **LE LISERÉ.** Les cards en portent un (angulaire, avec son bloom et ses
//     deux crêtes), l'ardoise n'en a pas. Trois états à comparer : tout
//     allumé, tout éteint, ou le cheveu seul sur l'ardoise.
//
//  2. **LA TYPOGRAPHIE.** Mesuré : le gros chiffre des cards est en
//     **système (SF), regular, 29,75 pt** ; « Cette semaine. » est en
//     **Inter, semibold, 20 pt**. Trois écarts d'un coup — famille, corps
//     (+49 %) et graisse. L'interrupteur met les cards en Inter semibold pour
//     voir si l'accord vaut mieux que le contraste.
//
//  3. **LE VERRE.** ⚠️ On sait déjà ce que la loi dit : `.clear` GIVRE ce qui
//     est net, et une card de 170 pt n'est QUE de l'encre nette. On s'attend
//     donc à un frost, pas à une lentille — mais un verdict à l'œil vaut mieux
//     qu'une loi récitée, et c'est vite vu.
struct HarmonieLab: View {
    @State private var lisereCards = true
    @State private var lisereSemaine = true
    @State private var verre = true
    @State private var interUnifie = true
    @State private var panneau = true

    var body: some View {
        ZStack(alignment: .bottom) {
            GrandeCardVideo(naissance: 1)

            VStack(alignment: .leading, spacing: 26) {
                CardsRangee(arrivee: 1,
                            lisere: lisereCards, verre: verre)
                SemaineStrip(faits: 3, prevus: 4, arrivee: 1,
                             lisere: lisereSemaine, verre: verre)
                Spacer(minLength: 0)
            }
            .padding(.leading, 24)
            .padding(.top, 120)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .topLeading)
            .environment(\.harmonieInter, interUnifie)

            if panneau { reglages }
        }
        .preferredColorScheme(.dark)
        .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.2)) { panneau.toggle() }
        }
    }

    private var reglages: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HARMONIE — double tap pour cacher")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.4))
            bascule("liseré des cards", $lisereCards)
            bascule("liseré angulaire sur l'ardoise", $lisereSemaine)
            bascule("les trois en VERRE natif", $verre)
            bascule("gros chiffres en Inter semibold", $interUnifie)
            Text(interUnifie
                 ? "cards : Inter semibold 29,75 — ardoise : Inter semibold 20"
                 : "cards : SF regular 29,75 — ardoise : Inter semibold 20")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.black.opacity(0.86))
        .transition(.move(edge: .bottom))
    }

    private func bascule(_ titre: String,
                         _ v: Binding<Bool>) -> some View {
        Toggle(isOn: v) {
            Text(titre)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.86))
        }
        .toggleStyle(.switch)
        .tint(Color(red: 1.0, green: 0.62, blue: 0.24))
    }
}

// MARK: - L'accord typographique, en environnement

/// L'interrupteur passe par l'ENVIRONNEMENT plutôt que par un paramètre : les
/// gros chiffres vivent à trois niveaux de profondeur dans les cards, et faire
/// descendre un booléen à la main jusqu'à eux salirait quatre signatures pour
/// un essai.
private struct HarmonieInterCle: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var harmonieInter: Bool {
        get { self[HarmonieInterCle.self] }
        set { self[HarmonieInterCle.self] = newValue }
    }
}
