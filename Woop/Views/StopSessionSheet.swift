import SwiftUI
import AVFoundation
import UIKit

// MARK: - Le panneau « Terminer la session ? »

/// LE STOP DU MINI-PLAYER POSE LA QUESTION — partout où la dalle vit
/// (fiche exo, calendrier, page exercice) : l'école du panneau
/// « Recommencer ? », à la lettre. NOTRE panneau, jamais un sheet
/// système ; le verre-nuit qui fond, la poignée, le tirage vers le bas
/// pour dire non. En tête : la vidéo PAUSE — un palindrome pré-encodé
/// (coupé d'une seconde à chaque bout, aller + retour dans le fichier),
/// en boucle muette : on ne voit jamais que c'est une vidéo.
struct StopSessionSheet: View {
    var onEnd: () -> Void = {}
    var onContinue: () -> Void = {}
    /// Le rappel de ce qui est déjà fait — la vraie séance nourrira ces
    /// trois chiffres (démo en attendant) : le panneau parle à
    /// l'utilisatrice, pas au vide.
    var series: Int = 0
    var exos: Int = 0
    var startedAt: Date? = nil

    /// Le drag de rangement — toute la surface, les boutons gardent
    /// leurs taps (12 pt de course avant que le drag n'existe).
    @State private var pull: CGFloat = 0
    /// L'entrée : le panneau naît sous le bord et monte en ressort.
    @State private var posee = false
    /// La petite caméra du header, posée en one-shot — AUCUNE horloge :
    /// une TimelineView 60 Hz re-cadrait la couche vidéo à chaque frame
    /// pour une pose finie en 2 s (le lag payé au premier montage).
    @State private var camPosee = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Coins hauts seuls — le bas appartient à l'écran (le CADRE
    /// FANTÔME est une faute déjà payée).
    private static let shape = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 34, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 34),
        style: .continuous)

    var body: some View {
        GeometryReader { g in
            // 0,47 : l'écart texte → boutons se resserre (verdict 18-08,
            // « réduis l'écart ») — la coupe vient du Spacer, le bas
            // reste ancré.
            let panelH = g.size.height * 0.47
            ZStack(alignment: .bottom) {
                // Le voile — un tap, c'est « non, je continue ».
                Color.black.opacity(posee ? 0.50 : 0)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: continuer)
                panneau(W: g.size.width, panelH: panelH)
                    .offset(y: (posee ? 0 : panelH + 60) + pull)
            }
            .frame(width: g.size.width, height: g.size.height,
                   alignment: .bottom)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.45,
                                  dampingFraction: 0.86)) { posee = true }
        }
    }

    private func panneau(W: CGFloat, panelH: CGFloat) -> some View {
        VStack(spacing: 0) {
            pauseHeader(W: W, slotH: panelH * 0.32)
            Text("Terminer la session ?")
                .font(.inter(20, .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
                .padding(.horizontal, 30)
            Text(sousTitre)
                .font(.inter(12.5))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
                .padding(.horizontal, 30)
            Spacer(minLength: 0)
            DiamondPrimaryButton(title: "Terminer la session") { onEnd() }
                .padding(.horizontal, 26)
            // L'échappée : de l'encre seule — sur la nuit, un cadre
            // clair se lit comme un bug (l'école du footer de BRAVO).
            Button(action: continuer) {
                Text("Non, continuer la séance")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.bottom, 24)
        }
        .frame(height: panelH)
        .frame(maxWidth: .infinity)
        // Le verre est le vrai, et par-dessus LA NUIT QUI FOND : quasi
        // opaque en haut (elle épouse le noir de la vidéo), transparente
        // en pied — la page respire à travers, le diamant vit sur l'air.
        .background {
            ZStack {
                Color.clear.glassEffect(
                    .regular.tint(Color.black.opacity(0.30)),
                    in: Self.shape)
                Self.shape
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.95),
                                  location: 0),
                            .init(color: Color.black.opacity(0.88),
                                  location: 0.38),
                            .init(color: Color.black.opacity(0.25),
                                  location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
            }
        }
        .clipShape(Self.shape)
        // Le fil du bord — seulement là où la feuille se détache.
        .overlay {
            Self.shape
                .strokeBorder(LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.16), location: 0),
                        .init(color: Color.white.opacity(0.03), location: 0.18),
                        .init(color: .clear, location: 0.45)
                    ],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
        .contentShape(Self.shape)
        .simultaneousGesture(dismissDrag)
    }

    // MARK: La vidéo pause et sa petite caméra

    /// La caméra entre par la GÉOMÉTRIE, en ONE-SHOT : un scale qui se
    /// pose (traîne longue) et un fondu court — deux animations, zéro
    /// horloge. La source est sur du noir : en ADDITIF le noir
    /// disparaît, il ne reste que la lumière sur la nuit du panneau.
    private func pauseHeader(W: CGFloat, slotH: CGFloat) -> some View {
        PauseLoopVideo()
            // La source est large (16:9) : la hauteur commande.
            // 1,32 : « grossis un peu plus » (verdict 18-08).
            .frame(width: slotH * (16.0 / 9.0) * 1.32,
                   height: slotH * 1.32)
            // LE FONDU DE BORD : la nébuleuse est éclairée jusqu'aux
            // bords — l'additif n'efface que le noir, le rectangle
            // se voyait. Le centre reste, les bords fondent.
            .mask {
                EllipticalGradient(
                    stops: [
                        .init(color: .white, location: 0.36),
                        .init(color: .clear, location: 0.88),
                    ],
                    center: .center,
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.72)
            }
            .blendMode(.plusLighter)
            .scaleEffect((camPosee || reduceMotion) ? 1.0 : 1.12)
            .animation(.timingCurve(0.16, 0.6, 0.3, 1, duration: 1.8),
                       value: camPosee)
            .opacity(camPosee ? 1 : 0)
            .animation(.easeOut(duration: 0.45), value: camPosee)
            .offset(y: 8)
            .frame(width: W, height: slotH)
            .clipped()
            .onAppear { camPosee = true }
            .frame(height: slotH)
    }

    /// « Déjà 3 séries validées · 2 exercices · 23 min — tout est
    /// gardé. » Le panneau rappelle l'effort avant de demander ; sans
    /// chiffres, la phrase sobre d'origine.
    private var sousTitre: String {
        var morceaux: [String] = []
        if series > 0 {
            morceaux.append("\(series) série\(series > 1 ? "s" : "") "
                + "validée\(series > 1 ? "s" : "")")
        }
        if exos > 0 {
            morceaux.append("\(exos) exercice\(exos > 1 ? "s" : "")")
        }
        if let s = startedAt {
            let m = max(1, Int(Date.now.timeIntervalSince(s) / 60))
            morceaux.append(m >= 60
                ? "\(m / 60) h \(String(format: "%02d", m % 60))"
                : "\(m) min")
        }
        guard !morceaux.isEmpty else {
            return "La séance s'arrête ici — tout est gardé."
        }
        return "Déjà " + morceaux.joined(separator: " · ")
            + " — tout est gardé."
    }

    private func continuer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.88)) {
            posee = false
        }
        Task {
            try? await Task.sleep(for: .milliseconds(360))
            onContinue()
        }
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { v in
                pull = max(0, v.translation.height)
            }
            .onEnded { _ in
                if pull > 90 {
                    continuer()
                } else {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.82)) {
                        pull = 0
                    }
                }
            }
    }
}

// MARK: - La vidéo pause en boucle

/// Le gabarit boucle pure de la maison (l'école DemonVideo) : un
/// `AVPlayerLayer` nu, un `AVPlayerLooper` RETENU par le Coordinator
/// (relâché, la boucle s'arrête au premier tour), muet, jamais
/// didPlayToEndTime+seek. Le fichier est un PALINDROME ré-encodé.
private final class PauseLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

private struct PauseLoopVideo: UIViewRepresentable {
    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PauseLayerView {
        let v = PauseLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.playerLayer.videoGravity = .resizeAspect
        guard let url = Bundle.main.url(
            forResource: "pause-overlay-loop",
            withExtension: "mp4") else {
            // Sans le fichier, le panneau reste le panneau — jamais un
            // rectangle noir « en attendant ».
            return v
        }
        let item = AVPlayerItem(url: url)
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(player: p,
                                                    templateItem: item)
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        return v
    }

    func updateUIView(_ v: PauseLayerView, context: Context) {}

    static func dismantleUIView(_ v: PauseLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}
