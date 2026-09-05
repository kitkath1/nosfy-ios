import SwiftUI
import UIKit

// MARK: - La sonde de cadence

/// LE SEUL JUGE FIABLE DU « ÇA LAG ». Un `CADisplayLink` compte les
/// battements RÉELLEMENT servis par l'écran et publie la moyenne chaque
/// seconde.
///
/// Pourquoi une sonde plutôt qu'une mesure d'écran : compter les images
/// DIFFÉRENTES d'un enregistrement (`mpdecimate`) ne mesure pas la
/// cadence — un fond lent produit peu d'images différentes tout en
/// tournant à 60, et le verdict est faux dans les deux sens. Le
/// display link, lui, rate un battement exactement quand le fil
/// principal a manqué son rendez-vous : c'est la définition du lag.
///
/// `-fps` l'allume. Elle ne dessine rien.
struct SondeCadence: UIViewRepresentable {
    /// L'étiquette publiée avec la mesure (« home », « panneau »…).
    var quoi: String

    final class Sonde: NSObject {
        var quoi = ""
        private var link: CADisplayLink?
        private var coups = 0
        private var depuis: CFTimeInterval = 0
        /// Le pire écart entre deux battements de la fenêtre — une
        /// moyenne honnête peut cacher un à-coup, et c'est l'à-coup
        /// qu'on voit.
        private var pire: CFTimeInterval = 0
        private var precedent: CFTimeInterval = 0

        func demarre() {
            let l = CADisplayLink(target: self, selector: #selector(coup))
            l.add(to: .main, forMode: .common)
            link = l
            depuis = CACurrentMediaTime()
            precedent = depuis
        }

        func arrete() {
            link?.invalidate()
            link = nil
        }

        @objc private func coup(_ l: CADisplayLink) {
            let t = l.timestamp
            let dt = t - precedent
            precedent = t
            if dt > pire { pire = dt }
            coups += 1
            let age = t - depuis
            guard age >= 1.0 else { return }
            print(String(format: "[cadence] %@ : %.1f img/s (pire trou %.0f ms)",
                         quoi, Double(coups) / age, pire * 1000))
            coups = 0
            pire = 0
            depuis = t
        }
    }

    func makeCoordinator() -> Sonde { Sonde() }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.isUserInteractionEnabled = false
        context.coordinator.quoi = quoi
        // ⚠️ LA GARDE VIT ICI AUSSI (04-09, lot 2, cause n° 8). Elle ne
        // vivait QUE dans l'extension `View.sondeCadence(_:)` ci-dessous
        // — et deux appels construisaient `SondeCadence(...)` EN DIRECT
        // (la pilule, le grand player). Résultat : deux `CADisplayLink`
        // réveillaient le fil principal à chaque battement d'écran, sur
        // l'app de PRODUCTION, pendant toute la séance — et un display
        // link permanent empêche un écran ProMotion de descendre son
        // taux de rafraîchissement au repos. De la chaleur gratuite.
        guard CommandLine.arguments.contains("-fps") else { return v }
        context.coordinator.demarre()
        return v
    }

    func updateUIView(_ v: UIView, context: Context) {
        context.coordinator.quoi = quoi
    }

    static func dismantleUIView(_ v: UIView, coordinator: Sonde) {
        coordinator.arrete()
    }
}

extension View {
    /// Pose la sonde si `-fps` est passé au lancement.
    @ViewBuilder
    func sondeCadence(_ quoi: String) -> some View {
        if CommandLine.arguments.contains("-fps") {
            overlay(SondeCadence(quoi: quoi).frame(width: 0, height: 0))
        } else {
            self
        }
    }
}
