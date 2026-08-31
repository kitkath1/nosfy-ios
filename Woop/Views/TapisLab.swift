import SwiftUI

// MARK: - Le banc du player tapis (`-tapisLab`)

/// LA SCÈNE SEULE SUR DU NOIR VRAI (l'école StopLab : rien dessous — un halo
/// de page pollue le jugement).
///
/// Les prises (`TapisBanc`) : `-tapisFige` (née posée, aucune rampe),
/// `-tapisT <s>` (les horloges clouées à naissance + s), `-tapisSet <n>`
/// (née avec n sets faits — une capture par palier, J2), `-tapisAuto`
/// (set → stop → repos → start en boucle : c'est lui qu'on FILME),
/// `-tapisNu` (sans bandeau), `-fps` (la sonde).
///
/// ⚠️ `--terminate-running-process` obligatoire au `simctl launch` : une app
/// déjà vivante revient au premier plan AVEC SES ANCIENS ARGUMENTS.
enum TapisBanc {
    static let actif = CommandLine.arguments.contains("-tapisLab")
    static let fige = CommandLine.arguments.contains("-tapisFige")
    static let nu = CommandLine.arguments.contains("-tapisNu")
    static let auto = CommandLine.arguments.contains("-tapisAuto")
    static let fps = CommandLine.arguments.contains("-fps")

    /// `-tapisT 6.5` — l'instant cloué (secondes après la naissance).
    static let tempsFige: Double? = valeur("-tapisT").flatMap(Double.init)
    /// `-tapisSet 4` — le nombre de sets déjà faits à la naissance.
    static let setsFaits: Int = valeur("-tapisSet").flatMap(Int.init) ?? 0

    private static func valeur(_ drapeau: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: drapeau),
              args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }
}

struct TapisLab: View {
    @State private var seance = SeanceTapis(
        figee: TapisBanc.fige || TapisBanc.tempsFige != nil,
        setsFaits: TapisBanc.setsFaits)
    /// L'identité de la scène : elle change à chaque relance, sinon SwiftUI
    /// réutilise la vue et l'arrivée ne rejoue pas.
    @State private var tour = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TapisScene(seance: seance,
                       onFinish: { rejouer() },
                       tempsFige: TapisBanc.tempsFige)
                .id(tour)
            if !TapisBanc.nu { bandeau }
            if TapisBanc.fps {
                SondeCadence(quoi: "tapis-banc").frame(width: 0, height: 0)
            }
        }
        .statusBarHidden()
        .task {
            guard TapisBanc.auto else { return }
            // Le cycle qu'on filme : 4 s de set, stop, 2,2 s de repos, start.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.0))
                seance.stopper()
                try? await Task.sleep(for: .seconds(2.2))
                seance.relancer()
            }
        }
    }

    private var bandeau: some View {
        Text("pastille chrono = stop/start · pastille km/h = vitesses démo · Finish rejoue l'arrivée")
            .font(.inter(11))
            .foregroundStyle(Color.inkMuted)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 26)
            .allowsHitTesting(false)
    }

    private func rejouer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            seance = SeanceTapis(figee: false,
                                 setsFaits: TapisBanc.setsFaits)
            tour += 1
        }
    }
}
