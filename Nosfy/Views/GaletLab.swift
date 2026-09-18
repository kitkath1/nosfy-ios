import SwiftUI

// MARK: - Banc du galet d'aube (`-galetLab`)

/// LE GALET SEUL, sur la nuit — la fiche d'exercice sans la fiche.
///
/// La règle du banc : reproduire la MISE EN PAGE de `ExerciseDetailView`
/// au point près (page noire pleine, `safeAreaInset` bas, slot de 160 pt),
/// et rien d'autre. Pas de photo, pas de titre, pas de carte Série, pas de
/// flamme — ces composants vivent dans d'autres sessions, on ne touche à
/// aucun de leurs fichiers. Ce qu'on voit ici est, au pixel, ce que la
/// fiche montre en bas de son écran.
///
/// Les prises :
/// - `-galetFlood <u>` fige la course du doigt (u ∈ [0,1], défaut 0 = le
///   repos, la nuit pleine — c'est l'état qu'on règle).
/// - `-galetT <s>` fige l'horloge de la respiration. Sans elle, D respire
///   de ±6,5 pt et la crête de ±6 pt : deux captures ne sont jamais
///   comparables, et toute mesure au dixième de point est un mensonge.
/// - `-galetMire` pose une mire : l'axe, les deux bords d'écran et les
///   graduations tous les 20 pt sous la crête — pour lire une capture sans
///   compter les pixels à la main.
struct GaletLab: View {
    @State private var flood: Double = GaletLab.floodArg ?? 0

    private static let floodArg: Double? = Self.number(after: "-galetFlood")
    private static let mire = CommandLine.arguments.contains("-galetMire")
    /// `-galetFPS` : le rythme de la timeline d'animation. ATTENTION à ce
    /// qu'il dit vraiment — il compte les battements du display link, pas
    /// les images que le GPU a fini de rendre. Il répond donc 60 des deux
    /// côtés de l'A/B : ce qu'il prouve, c'est que le fil principal ne cale
    /// pas, rien de plus. (Et le film + `mpdecimate` ne sait pas trancher
    /// non plus : le liseré AJOUTE du mouvement, donc plus d'images
    /// « distinctes » — allumé, il semble plus fluide qu'éteint. Le seul
    /// juge du coût GPU reste l'appareil.)
    private static let fps = CommandLine.arguments.contains("-galetFPS")

    static let tFreeze: Double? = Self.number(after: "-galetT")

    private static func number(after flag: String) -> Double? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: flag), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return v
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            LaunchPebble(
                label: "Start exercise",
                flood: $flood,
                asleep: false,
                onDrive: { _, _ in },
                onRelease: { _, _ in },
                onLaunch: {}
            )
        }
        .overlay { if Self.mire { mireOverlay } }
        .overlay { if Self.fps { compteur } }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    /// Une `TimelineView` posée par-dessus, à la même cadence demandée que
    /// le galet : elle ne mesure pas le galet, elle mesure ce que le
    /// système ARRIVE à rendre pendant que le galet travaille.
    private var compteur: some View {
        TimelineView(.animation) { tl in
            Color.clear
                .onChange(of: tl.date) { _, d in
                    Self.tick(d)
                }
        }
        .allowsHitTesting(false)
    }

    private static var t0: Date?
    private static var n = 0

    private static func tick(_ d: Date) {
        n += 1
        guard let s = t0 else { t0 = d; return }
        let age = d.timeIntervalSince(s)
        if age >= 2.0 {
            print(String(format: "CADENCE %.1f img/s (%d images en %.2f s)",
                         Double(n) / age, n, age))
            t0 = d; n = 0
        }
    }

    /// La mire : elle ne sait rien du galet, elle mesure l'écran. Le zéro
    /// des graduations est la crête au repos — `slotTop + 20`, c'est-à-dire
    /// (hauteur − zone sûre basse − 160) + 20.
    private var mireOverlay: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let crest = h - geo.safeAreaInsets.bottom - LaunchPebble.height + 20
            ZStack(alignment: .topLeading) {
                Path { p in
                    p.move(to: CGPoint(x: w / 2, y: crest - 40))
                    p.addLine(to: CGPoint(x: w / 2, y: h))
                }
                .stroke(Color.green.opacity(0.35), lineWidth: 0.5)

                ForEach(0..<10, id: \.self) { k in
                    let y = crest + CGFloat(k) * 20
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: k % 5 == 0 ? 34 : 16, y: y))
                        p.move(to: CGPoint(x: w, y: y))
                        p.addLine(to: CGPoint(x: w - (k % 5 == 0 ? 34 : 16),
                                              y: y))
                    }
                    .stroke(Color.green.opacity(k % 5 == 0 ? 0.55 : 0.28),
                            lineWidth: 0.5)
                }
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}
