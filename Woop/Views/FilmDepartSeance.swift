import AVFoundation
import SwiftUI
import UIKit

/// Une lecture au départ, au-dessus du châssis. La fin du fichier et le tap
/// empruntent le même chemin ; aucun minuteur ne décide de la navigation.
struct FilmDepartSeance: View {
    var onFin: () -> Void
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Lecteur(actif: phase == .active, passer: reduceMotion, onFin: onFin)
            .background(.black)
            .ignoresSafeArea()
            .statusBarHidden(true)
    }

    private struct Lecteur: UIViewRepresentable {
        var actif: Bool
        var passer: Bool
        var onFin: () -> Void

        func makeUIView(context: Context) -> Hote {
            let vue = Hote()
            vue.onFin = onFin
            vue.actif = actif
            vue.preparer(passer: passer)
            return vue
        }

        func updateUIView(_ vue: Hote, context: Context) {
            vue.onFin = onFin
            vue.actif = actif
            if passer { vue.finir("mouvement-reduit") }
            else { vue.actualiser() }
        }

        static func dismantleUIView(_ vue: Hote, coordinator: ()) {
            vue.liberer()
            vue.onFin = nil
        }
    }

    private final class Hote: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        private var video: AVPlayerLayer { layer as! AVPlayerLayer }
        private var lecteur: AVPlayer?
        private var observation: NSKeyValueObservation?
        private var notifications: [NSObjectProtocol] = []
        private var terminee = false
        var actif = false
        var onFin: (() -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            isOpaque = true
            video.videoGravity = .resizeAspect
            isAccessibilityElement = true
            accessibilityIdentifier = "depart-compte-rebours"
            accessibilityLabel = L("La séance commence", "Your session starts")
            accessibilityHint = L("Toucher pour passer", "Tap to skip")
            accessibilityTraits = .button
            addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                        action: #selector(passerFilm)))
        }

        required init?(coder: NSCoder) { fatalError() }

        func preparer(passer: Bool) {
            NavDiagnostic.noter("depart.film-monte", destination: passer ? "mouvement-reduit" : "lecture")
            guard !passer, let url = Bundle.main.url(forResource: "count", withExtension: "mp4") else {
                Task { @MainActor [weak self] in self?.finir(passer ? "mouvement-reduit" : "fichier-absent") }
                return
            }
            // Même recette que le carillon de l'île : la musique continue,
            // le mode silencieux de l'iPhone reste respecté.
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            let item = AVPlayerItem(url: url)
            let player = AVPlayer(playerItem: item)
            player.actionAtItemEnd = .pause
            lecteur = player
            video.player = player
            for nom in [AVPlayerItem.didPlayToEndTimeNotification,
                        AVPlayerItem.failedToPlayToEndTimeNotification,
                        AVPlayerItem.playbackStalledNotification] {
                notifications.append(NotificationCenter.default.addObserver(
                    forName: nom, object: item, queue: .main) { [weak self] n in
                        let raison = n.name == AVPlayerItem.didPlayToEndTimeNotification
                            ? "fin" : "lecture-indisponible"
                        Task { @MainActor [weak self] in self?.finir(raison) }
                    })
            }
            observation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
                let statut = item.status
                Task { @MainActor [weak self] in
                    guard let self, !self.terminee else { return }
                    if statut == .failed { self.finir("echec-lecture") }
                    else { self.actualiser() }
                }
            }
            print("[depart-film] lecteur créé · count.mp4 · une lecture")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            actualiser()
        }

        func actualiser() {
            guard !terminee else { return }
            if actif, window != nil, lecteur?.currentItem?.status == .readyToPlay {
                if lecteur?.rate == 0 { lecteur?.play() }
            } else {
                lecteur?.pause()
            }
        }

        @objc private func passerFilm() { finir("tap") }
        override func accessibilityActivate() -> Bool {
            guard !terminee else { return false }
            finir("accessibilite")
            return true
        }

        func finir(_ raison: String) {
            guard !terminee else { return }
            NavDiagnostic.noter("depart.film-fini", destination: raison)
            let fin = onFin
            liberer()
            print("[depart-film] terminé · \(raison) · lecteur libéré")
            // Éviter une écriture SwiftUI pendant updateUIView.
            Task { @MainActor [weak self] in
                guard self?.onFin != nil else { return }
                self?.onFin = nil
                fin?()
            }
        }

        func liberer() {
            terminee = true
            lecteur?.pause()
            observation?.invalidate()
            observation = nil
            notifications.forEach(NotificationCenter.default.removeObserver)
            notifications.removeAll()
            video.player = nil
            lecteur?.replaceCurrentItem(with: nil)
            lecteur = nil
        }
    }
}

enum DepartFilmBanc {
    static let seul = CommandLine.arguments.contains("-countLab")
    static let sansFilm = CommandLine.arguments.contains("-sansCount")
}

/// Le même lecteur sans séance ni appel serveur, pour mesurer son cycle de vie.
struct FilmDepartLab: View {
    @State private var lecture = true
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if lecture {
                FilmDepartSeance { lecture = false }
            } else {
                Button(L("Rejouer le décompte", "Replay countdown")) { lecture = true }
                    .accessibilityIdentifier("depart-rejouer")
            }
        }
    }
}
