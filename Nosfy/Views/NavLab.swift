import SwiftUI

// MARK: - Banc d'essai de la barre d'onglets bijou (`-navLab`)

// Le composant lui-même vit dans Woop/Views/JewelTabBar.swift ; ici, seulement
// la page nue et le panneau de fouettage.

/// Page nue : la barre seule, en bas, et le panneau de fouettage. On n'itère
/// JAMAIS dans l'app réelle — la home met dix secondes à revenir et on perd le
/// fil de l'œil.
struct NavLab: View {
    /// Quatre onglets et le galet au milieu — la fusion Calendrier → Progression
    /// libère la place, et Profil complète la symétrie pour que le bouton tombe
    /// EXACTEMENT au centre de la barre.
    private static let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Accueil"),
        ("figure.strengthtraining.functional", "Entraînements"),
        ("chart.line.uptrend.xyaxis", "Progression"),
        ("person", "Profil"),
    ]

    private enum Page: String, CaseIterable { case barre = "BARRE", galet = "PLAY" }

    @State private var selection = 0
    @State private var params = JewelParams()
    @State private var play = PlayParams()
    @State private var withPlay = true
    @State private var showPanel = true
    @State private var page: Page = .galet
    /// Le fond : l'aurore du login (le vrai décor), le gris #141414 de la
    /// référence d'origine, ou le noir pur. Comparer les trois est le seul
    /// moyen de savoir si l'ombre portée tient sur le feu.
    @State private var bg = 0

    var body: some View {
        ZStack {
            switch bg {
            case 0: AuroraLoginBackground().ignoresSafeArea()
            case 1: Color(red: 0.078, green: 0.078, blue: 0.082).ignoresSafeArea()
            default: Color.black.ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if showPanel { panel } else { Spacer(minLength: 0) }

                JewelTabBar(items: Self.tabs, selection: $selection,
                            params: params, play: withPlay ? play : nil)
                    .frame(height: 64)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onTapGesture(count: 2) { showPanel.toggle() }
    }

    private var panel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Picker("", selection: $page) {
                        ForEach(Page.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    Spacer()
                    Button(["aurore", "gris", "noir"][bg]) { bg = (bg + 1) % 3 }
                        .font(.inter(11))
                        .foregroundStyle(Color.inkSecondary)
                    Button("défauts") {
                        params = JewelParams(); play = PlayParams()
                    }
                    .font(.inter(11))
                    .foregroundStyle(Color.inkSecondary)
                }
                .padding(.bottom, 8)

                if page == .barre {
                    row("contour", $params.contour, 0, 1)
                    row("repetition", $params.repetition, 0.2, 6)
                    row("floor", $params.floorLevel, 0, 0.6)
                    row("softness", $params.softness, 0.005, 0.9)
                    row("shiftRed", $params.shiftRed, 0, 0.20)
                    row("shiftBlue", $params.shiftBlue, 0, 0.20)
                    row("distortion", $params.distortion, 0, 1)
                    row("angle", $params.angle, 0, 360)
                    row("speed", $params.speed, 0, 1.5)
                    row("influence", $params.influence, 1, 20)
                    row("lineW", $params.lineW, 0.4, 5)
                    row("gold", $params.gold, 0, 1)
                    row("glow", $params.glow, 0, 1)
                } else {
                    Toggle("galet", isOn: $withPlay)
                        .font(.inter(11))
                        .foregroundStyle(Color.inkMuted)
                        .tint(Color.woopGold)
                        .frame(height: 26)
                    row("rayon", $play.radius, 16, 42)
                    row("remontée", $play.rise, 0, 26)
                    row("écart", $play.gap, 0, 24)
                    row("gloss", $play.gloss, 8, 900)
                    row("chanfrein", $play.chamfer, 0.4, 5)
                    row("glyphe", $play.glyph, 5, 24)
                    row("arrondi", $play.round, 0, 0.35)
                    row("souffle", $play.breath, 0, 1)
                    row("souffle vit", $play.breathSpeed, 0.1, 3)
                    row("blancheur", $play.whiteness, 0, 1.6)
                    row("invite", $play.invite, 0, 0.6)
                    row("rasant", $play.fresnel, 0, 0.35)
                    row("anneau W", $play.ringW, 0.4, 4)
                    row("anneau", $play.ringAmt, 0, 1.2)
                    row("buée", $play.halo, 0, 0.9)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ name: String, _ value: Binding<Double>,
                     _ lo: Double, _ hi: Double) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.inter(11))
                .foregroundStyle(Color.inkMuted)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: lo...hi)
                .tint(Color.woopGold)
            Text(String(format: abs(hi) > 20 ? "%.0f" : "%.3f", value.wrappedValue))
                .font(.inter(10).monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
                .frame(width: 46, alignment: .trailing)
        }
        .frame(height: 26)
    }
}
