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
    /// ⚠️ `-tapisTourne` EST MORT, et c'est une leçon, pas un nettoyage.
    /// Il appelait la fonction du geste DIRECTEMENT : il court-circuitait le
    /// hit-testing, la zone de prise et l'arbitrage. Il « prouvait » donc la
    /// trigonométrie — jamais en doute — et RIEN sur le fait qu'un toucher
    /// réel atteigne le geste. Pendant ce temps la zone de prise était 190 pt
    /// trop haute et rien ne le montrait. Une sonde qui mesure la mauvaise
    /// chose est pire qu'un juge : elle a l'autorité d'un chiffre.
    /// Ce qui se prouve maintenant se prouve AU DOIGT, à l'écran.
    /// `-tapisSansChiffres` — SONDE D'ABLATION : l'anneau sans ses valeurs.
    /// Verdict rendu (01-09) : AUCUN coût (57/56/60/60 avec, 59/55/60/60
    /// sans). Gardée : c'est elle qui m'a évité de réécrire les chiffres en
    /// vues pour rien.
    static let sansChiffres = CommandLine.arguments.contains("-tapisSansChiffres")
    /// `-sansBraiseTapis` — LE BARREAU du moteur (skill perf) : les deux
    /// pastilles en braise PEINTE (aucun shader), même place, même taille.
    /// L'essai B de la campagne ABBA sur son téléphone ; sans lui on ne
    /// pourra jamais accuser ni disculper les deux `braiseGlow` à 60 Hz.
    static let sansBraise = CommandLine.arguments.contains("-sansBraiseTapis")
    /// `-tapisMode escalier|modere` — le banc dans un autre mode que le HIIT.
    static let mode: ModeCardio = {
        switch valeur("-tapisMode") {
        case "escalier": return .escalier
        case "modere": return .tapisModere
        default: return .hiit
        }
    }()

    /// `-tapisT 6.5` — l'instant cloué (secondes après la naissance).
    static let tempsFige: Double? = valeur("-tapisT").flatMap(Double.init)
    /// `-tapisSet 4` — le nombre de sets déjà faits à la naissance.
    static let setsFaits: Int = valeur("-tapisSet").flatMap(Int.init) ?? 0
    /// `-tapisChoisi 15` — la vitesse vient d'être SCELLÉE (1 s après la
    /// naissance). Un drapeau d'ÉTAT, pas un faux geste : il ne simule aucun
    /// doigt, il pose la scène à l'instant de la confirmation pour qu'elle se
    /// capture avec `-tapisT`.
    static let choisi: Int? = valeur("-tapisChoisi").flatMap(Int.init)

    private static func valeur(_ drapeau: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: drapeau),
              args.indices.contains(i + 1) else { return nil }
        return args[i + 1]
    }
}

struct TapisLab: View {
    @State private var seance = SeanceTapis(
        mode: TapisBanc.mode,
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
        .onAppear {
            if let v = TapisBanc.choisi {
                seance.vitesse = Double(v)
                seance.vitesseChoisie = v
                seance.vitesseScellee = seance.naissance.addingTimeInterval(1.0)
            }
        }
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
        Text("pastille chrono = stop/start · pastille km/h = la molette · Finish rejoue l'arrivée")
            .font(.inter(11))
            .foregroundStyle(Color.inkMuted)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 26)
            .allowsHitTesting(false)
    }

    private func rejouer() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            seance = SeanceTapis(mode: TapisBanc.mode, figee: false,
                                 setsFaits: TapisBanc.setsFaits)
            tour += 1
        }
    }
}
