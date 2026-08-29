import SwiftUI

// MARK: - Le banc de la card STOP (`-stopLab`)

/// LA CARD SEULE SUR DU NOIR VRAI — elle ne veut RIEN dessous (ni splash, ni
/// porte, ni home : un halo de page traverse le scrim et pollue le jugement,
/// constaté sur la card reward le 27-08).
///
/// Les prises (`StopBanc`) : `-stopFige` (posée), `-stopNu` (sans bandeau),
/// `-stopAuto` (ouvre / ferme en boucle — le film), `-stopSliderAuto` (le
/// slider commet seul), `-fps` (la sonde).
///
/// Cancel, le scrim et STOP rejouent tous l'entrée : la vraie SORTIE puis la
/// vraie ENTRÉE — jamais une coupe sèche, c'est le raccord qu'on juge.
///
/// ⚠️ `--terminate-running-process` est obligatoire au `simctl launch` :
/// une app déjà vivante revient au premier plan AVEC SES ANCIENS ARGUMENTS.
struct StopLab: View {
    @State private var ouverte = true
    /// L'identité de l'hôte : elle change à chaque relance, sinon SwiftUI
    /// réutilise la vue et l'entrée ne rejoue pas.
    @State private var tour = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StopCardHote(ouverte: ouverte,
                         duree: "24 min", series: 3, gain: 60,
                         onTerminer: { rejouer() },
                         onContinuer: { rejouer() })
                .id(tour)
            if !StopBanc.nu { bandeau }
            if StopBanc.fps {
                SondeCadence(quoi: "stop-banc").frame(width: 0, height: 0)
            }
        }
        .statusBarHidden()
        .task {
            guard StopBanc.auto else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.4))
                ouverte = false
                try? await Task.sleep(for: .seconds(1.0))
                tour += 1
                ouverte = true
            }
        }
    }

    private var bandeau: some View {
        Text("cancel · scrim · stop — chacun rejoue l'entrée")
            .font(.inter(11))
            .foregroundStyle(Color.inkMuted)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 26)
            .allowsHitTesting(false)
    }

    private func rejouer() {
        ouverte = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            tour += 1
            ouverte = true
        }
    }
}
