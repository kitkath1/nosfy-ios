import SwiftUI
import AVFoundation

// MARK: - LE DÉPART DE SÉANCE — le panneau du galet play
//
// Le galet play de la barre bijou n'allume plus la séance à sec : il
// ouvre CE panneau — le jumeau assumé de la pop-up booster (même verre,
// même nuit qui fond, même primaire diamant, même échappée en encre
// nue), avec en header LA LUNE QUI SE CHARGE entre l'haltère et les
// disques : `start-entrainement-loop.mp4`, recuit en PING-PONG
// aller-retour (couture mesurée à 0,2 quand deux voisines ordinaires
// valent 0,95 — mathématiquement invisible), muet, composé en ADDITIF
// (le noir de la source disparaît sans détourage). La rampe de +20 % de
// la source n'a PAS été aplatie : c'est la lune qui monte en braise —
// en aller-retour elle devient une RESPIRATION de 16 s.
//
// « Commencer » crée la séance (le `startWorkout` existant de la
// racine), bascule sur la page des exercices et ARME le tuto à
// projecteurs (la première fois seulement).

/// Le chef d'orchestre du départ — une seule instance, lue à la racine
/// (l'école `SacreEtat` : un onglet paresseux n'entend personne).
@Observable
final class DepartEtat {
    static let shared = DepartEtat()
    private init() {}

    /// Le panneau du galet play.
    var panneauOuvert = false
    /// Le tuto de la page exercices est demandé (posé par « Commencer »,
    /// consommé par la page à son apparition).
    var tutoDemande = false

    func proposer() {
        guard !panneauOuvert else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            panneauOuvert = true
        }
    }

    func fermer() {
        withAnimation(.easeOut(duration: 0.22)) { panneauOuvert = false }
    }
}

// MARK: - La boucle vidéo du départ

/// Le plan de la lune qui se charge — l'école exacte de la pop-up
/// booster : `AVPlayerLooper` (jamais un seek sur didPlayToEndTime),
/// looper RETENU, muet, et le démontage qui rend tout.
struct DepartLoopVideo: UIViewRepresentable {
    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoosterLoopLayerView {
        let v = BoosterLoopLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.playerLayer.videoGravity = .resizeAspectFill
        guard let url = Bundle.main.url(
            forResource: "start-entrainement-loop",
            withExtension: "mp4") else {
            // Sans le fichier, le panneau reste le panneau — jamais un
            // rectangle noir « en attendant ».
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(
            player: p, templateItem: AVPlayerItem(url: url))
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        return v
    }

    func updateUIView(_ v: BoosterLoopLayerView, context: Context) {}

    static func dismantleUIView(_ v: BoosterLoopLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

// MARK: - L'hôte

/// Le conteneur reste MONTÉ (transparent, sourd au doigt quand il est
/// vide) : c'est lui qui joue l'entrée et la sortie — l'école du
/// « Recommencer », à la lettre.
struct DepartPanneauHote: View {
    var ouverte: Bool
    var onCommencer: () -> Void = {}
    var onFermer: () -> Void = {}

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                Color.clear
                if ouverte {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { onFermer() }
                        .transition(.opacity)
                    DepartPanneau(W: g.size.width,
                                  onCommencer: onCommencer,
                                  onFermer: onFermer)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(ouverte)
        .animation(.spring(response: 0.45, dampingFraction: 0.86),
                   value: ouverte)
    }
}

// MARK: - Le panneau

struct DepartPanneau: View {
    var W: CGFloat
    var onCommencer: () -> Void = {}
    var onFermer: () -> Void = {}

    @State private var pull: CGFloat = 0
    @State private var naissance = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Coins HAUTS seuls — le bas appartient à l'écran.
    private static let forme = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 34, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 34),
        style: .continuous)
    /// Le ratio du fichier recuit (1080×608) — l'emplacement est taillé
    /// dessus pour que rien ne soit recadré.
    private static let ratioVideo: CGFloat = 1080.0 / 608.0

    private var slotH: CGFloat { W / Self.ratioVideo }
    private var hauteur: CGFloat { slotH + 246 }

    var body: some View {
        panneau(W: W, slotH: slotH)
            .frame(width: W, height: hauteur)
            .offset(y: pull)
            .contentShape(Self.forme)
            .simultaneousGesture(dismissDrag)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { v in pull = max(0, v.translation.height) }
            .onEnded { _ in
                if pull > 90 {
                    onFermer()
                } else {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.82)) { pull = 0 }
                }
            }
    }

    private func panneau(W: CGFloat, slotH: CGFloat) -> some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: slotH + 34)

            Text("Ta séance commence ici.")
                .font(.inter(20, .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 30)
            Text("Choisis ton premier exercice — la lune s'occupe du feu.")
                .font(.inter(12.5))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 7)
                .padding(.horizontal, 30)

            Spacer(minLength: 0)

            DiamondPrimaryButton(title: "Commencer",
                                 smokeWarmth: 0.55) {
                onCommencer()
            }
            .padding(.horizontal, 26)
            .padding(.top, 32)

            Button { onFermer() } label: {
                Text("Plus tard")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.bottom, 34)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            GeometryReader { p in
                let H = max(p.size.height, 1)
                let pied = min(slotH / H, 0.9)
                ZStack {
                    // Jamais `.interactive()` sur un grand verre : il
                    // vole les gestes de ce qui vit dessus.
                    Color.clear.glassEffect(
                        .regular.tint(Color.black.opacity(0.30)),
                        in: Self.forme)
                    Self.forme
                        .fill(LinearGradient(stops: [
                            .init(color: .black.opacity(0.95), location: 0),
                            .init(color: .black.opacity(0.93),
                                  location: pied * 0.56),
                            .init(color: .black.opacity(0.72),
                                  location: pied),
                            .init(color: .black.opacity(0.56),
                                  location: min(pied + 40 / H, 0.99)),
                            .init(color: .black.opacity(0.54), location: 1)
                        ], startPoint: .top, endPoint: .bottom))
                        .allowsHitTesting(false)
                }
            }
        }
        // L'OBJET DE LUMIÈRE : le plan en additif, la caméra vivante
        // par transformation (jamais la frame — un AVPlayerLayer
        // redimensionné 60×/s relayoute et re-rend chaque image), des
        // périodes PREMIÈRES entre elles et avec les 16 s du plan :
        // aucun instant n'est deux fois le même.
        .overlay(alignment: .top) {
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                        paused: reduceMotion)) { tl in
                    let e = tl.date.timeIntervalSince(naissance)
                    let pose: CGFloat = reduceMotion
                        ? 1 : 1 + 0.10 * CGFloat(exp(-e * 1.9))
                    let respire: CGFloat = reduceMotion ? 1
                        : 1 + 0.045 * CGFloat(sin(e * 2 * .pi / 37.0))
                            + 0.022 * CGFloat(sin(e * 2 * .pi / 23.0 + 1.7))
                    let dx: CGFloat = reduceMotion ? 0
                        : 6 * CGFloat(sin(e * 2 * .pi / 41.0 + 0.6))
                    let dy: CGFloat = reduceMotion ? 0
                        : 4 * CGFloat(sin(e * 2 * .pi / 29.0))
                    DepartLoopVideo()
                        .frame(width: slotH * Self.ratioVideo,
                               height: slotH)
                        .blendMode(.plusLighter)
                        .scaleEffect(pose * respire)
                        .offset(x: dx, y: dy)
                }
            }
            .frame(width: W, height: slotH)
            .allowsHitTesting(false)
        }
        .clipShape(Self.forme)
        .overlay {
            Self.forme
                .strokeBorder(LinearGradient(stops: [
                    .init(color: Color.white.opacity(0.16), location: 0),
                    .init(color: Color.white.opacity(0.03), location: 0.18),
                    .init(color: .clear, location: 0.45)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
    }
}
