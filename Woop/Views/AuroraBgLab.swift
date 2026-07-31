import SwiftUI
import CoreMotion

// MARK: - Banc du fond aurora nu (`-bgLab`)
//
// Écran noir total, l'aurore vit dans le bas (shader `bgAurora`), et la
// parallaxe 3D répond au mouvement de l'appareil. Au simulateur, où le
// gyroscope est muet, le doigt fait l'inclinaison : on caresse l'écran, les
// plans glissent, on lâche, ça revient en ressort amorti.

/// L'inclinaison de l'appareil, lissée, dans [-1, 1]. La ligne de base suit
/// TRÈS lentement la pose de la main : l'effet répond au geste, pas à la
/// posture — posé sur une table ou tenu au lit, il revient toujours au repos.
@MainActor
final class BgTilt: ObservableObject {
    @Published var value: CGPoint = .zero
    private let mgr = CMMotionManager()
    private var base: CGPoint?

    init() {
        guard mgr.isDeviceMotionAvailable else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 60.0
        mgr.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let m = motion else { return }
            let raw = CGPoint(x: m.attitude.roll, y: m.attitude.pitch)
            let b = self.base ?? raw
            // Constante de temps ~3 s : une inclinaison tenue redevient le repos.
            self.base = CGPoint(x: b.x * 0.995 + raw.x * 0.005,
                                y: b.y * 0.995 + raw.y * 0.005)
            let dx = max(-1, min(1, (raw.x - b.x) / 0.45))
            let dy = max(-1, min(1, (raw.y - b.y) / 0.45))
            // Lissage court : ni gigue, ni retard sensible.
            self.value = CGPoint(x: self.value.x * 0.85 + dx * 0.15,
                                 y: self.value.y * 0.85 + dy * 0.15)
        }
    }
}

struct AuroraBgLab: View {
    @StateObject private var tilt = BgTilt()
    /// Le doigt (simulateur) : l'excursion en cours, puis — au lâcher — un
    /// ressort amorti PUR fonction du temps, aucune mutation par image.
    @State private var drag: CGSize = .zero
    @State private var released: CGSize = .zero
    @State private var releaseDate: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let now = tl.date
            let t = Float(now.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 4096))
            let finger = fingerTilt(at: now)
            let tx = Float(max(-1, min(1, tilt.value.x + finger.width)))
            let ty = Float(max(-1, min(1, tilt.value.y + finger.height)))
            GeometryReader { geo in
                Rectangle()
                    .fill(.black)   // JAMAIS .clear : le `* color.a` final avale tout
                    .colorEffect(ShaderLibrary.bgAurora(
                        .float2(geo.size),
                        .float(t),
                        .float2(tx, ty)))
            }
        }
        .ignoresSafeArea()
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { g in
                    releaseDate = nil
                    drag = CGSize(width: g.translation.width / 140.0,
                                  height: g.translation.height / 200.0)
                }
                .onEnded { _ in
                    released = drag
                    drag = .zero
                    releaseDate = Date()
                }
        )
    }

    /// Ressort amorti : e^-4Δt · cos(9Δt) — deux oscillations à peine, puis rien.
    private func fingerTilt(at now: Date) -> CGSize {
        if drag != .zero { return drag }
        guard let d = releaseDate else { return .zero }
        let dt = now.timeIntervalSince(d)
        guard dt < 2.0 else { return .zero }
        let k = exp(-4.0 * dt) * cos(9.0 * dt)
        return CGSize(width: released.width * k, height: released.height * k)
    }
}

#Preview {
    AuroraBgLab()
}
