import SwiftUI

// MARK: - LE COMMUTATEUR OBSIDIENNE (30-09, Réglages)
//
// Kathryn, 30-09, devant la v1 (une pilule de verre, deux tuiles) : « reprends
// le composant slider qu'on a partout, et un autre composant pour le réglage,
// c'est trop cheap ». Le réglage se fait donc dans LA MATIÈRE DU SLIDER : la
// même capsule d'obsidienne, le même pouce de chrome — élargi à une demi-piste.
//
// AUCUN NOUVEAU SHADER. `sliderObsidienne` (NavMonolith.metal:590) prend déjà
// la position ET la demi-largeur du pouce (`pill = (x, demi-largeur,
// demi-hauteur, pression)`, x compté depuis le bord gauche de la piste) : le
// pouce large n'est qu'un autre jeu d'uniformes.
//
// ⚠️ LA DIFFÉRENCE QUI COMPTE AVEC LE SLIDER : AUCUNE HORLOGE. `SliderObsidienne`
// tient une `TimelineView` à 60 Hz tant qu'il est à l'écran (sa poudre, son fil
// qui court). Ici le temps du shader est FIGÉ, et la seule chose qui bouge — le
// pouce — est une valeur ANIMABLE : le shader ne se redessine que pendant les
// 0,4 s du ressort. Une page Réglages immobile ne coûte rien (la loi du 05-09 :
// redessiner pour animer coûte 3 à 8 fois plus qu'animer).
//
// Le mot choisi s'écrit en blanc DANS le pouce, l'autre reste à 30 % sur la
// pierre — c'est la lampe du slider : le pouce éclaire les lettres, rien ne
// court tout seul. Pendant le geste, le blanc suit le pouce lettre par lettre.
//
// Barreau : `-sansCommutateurShader` (la matière retombe en capsule plate).

struct CommutateurObsidienne: View {
    /// Les deux mots, gauche puis droite.
    let mots: [String]
    /// 0 = gauche, 1 = droite.
    @Binding var choix: Int
    /// Ce que VoiceOver annonce (« Langue », « Départ de série »).
    let nom: String
    /// Un choix part au serveur : le pouce se voile et ne répond plus.
    var enAttente: Bool = false
    var height: CGFloat = 56

    /// Le centre du pouce pendant le geste — `nil` au repos.
    @State private var tire: CGFloat?
    @State private var origine: CGFloat = 0
    @State private var bouge = false
    @State private var garde: Task<Void, Never>?

    static let sansShader = CommandLine.arguments.contains("-sansCommutateurShader")
    static let ressort = Animation.spring(response: 0.42, dampingFraction: 0.80)

    /// Les cotes du slider, relevées sur la même référence
    /// (`SliderObsidienne.medalH` / `encart`).
    private var pouceH: CGFloat { height * 0.683 }
    private var encart: CGFloat { height * 0.151 }

    var body: some View {
        GeometryReader { geo in
            let g = Cotes(W: geo.size.width, encart: encart)
            let x = tire ?? g.centre(choix)
            ZStack {
                MatiereObsidienne(x: x, demiLargeur: g.demiLargeur,
                                  demiHauteur: pouceH / 2,
                                  largeur: g.W, hauteur: height,
                                  plate: Self.sansShader)
                encres(g, x: x)
            }
            .frame(width: g.W, height: height)
            .contentShape(Capsule())
            .gesture(geste(g))
        }
        .frame(height: height)
        .opacity(enAttente ? 0.55 : 1)
        .allowsHitTesting(!enAttente)
        .animation(.easeOut(duration: 0.2), value: enAttente)
        .sensoryFeedback(.selection, trigger: choix)
        .onDisappear { garde?.cancel() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(nom)
        .accessibilityValue(mots.indices.contains(choix) ? mots[choix] : "")
        .accessibilityAdjustableAction { sens in
            withAnimation(Self.ressort) { choix = sens == .increment ? 1 : 0 }
        }
    }

    // MARK: Les deux encres

    /// Le gris sur la pierre, le blanc dans le pouce — le même mot, deux fois,
    /// et le pouce en MASQUE du blanc : c'est lui qui « mange » les lettres.
    private func encres(_ g: Cotes, x: CGFloat) -> some View {
        ZStack {
            rangee(g)
                .foregroundStyle(Color.white.opacity(0.30))
            rangee(g)
                .foregroundStyle(LinearGradient(
                    colors: [Color(white: 0.98), Color(white: 0.66)],
                    startPoint: .top, endPoint: .bottom))
                .mask {
                    Capsule()
                        .frame(width: g.demiLargeur * 2, height: pouceH)
                        .position(x: x, y: height / 2)
                }
        }
        .allowsHitTesting(false)
    }

    private func rangee(_ g: Cotes) -> some View {
        ZStack {
            ForEach(mots.indices, id: \.self) { i in
                Text(mots[i])
                    .font(.inter(16, .semibold))
                    .tracking(-0.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: g.demiLargeur * 2 - 16)
                    .position(x: g.centre(i), y: height / 2)
            }
        }
        .frame(width: g.W, height: height)
    }

    // MARK: Le geste

    /// Un seul geste : le glissé du pouce, ou le tap sur un mot. ⚠️ Un
    /// `DragGesture` n'appelle pas toujours `onEnded` (l'app qui part, un
    /// geste système qui vole le doigt) : un chien de garde rejoint alors le
    /// côté le plus proche, jamais un état inventé.
    private func geste(_ g: Cotes) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if tire == nil, !bouge { origine = g.centre(choix) }
                if abs(v.translation.width) > 4 { bouge = true }
                if bouge { tire = g.borne(origine + v.translation.width) }
                armerGarde(g)
            }
            .onEnded { v in finir(g, tap: v.location.x) }
    }

    private func finir(_ g: Cotes, tap: CGFloat?) {
        garde?.cancel()
        let j: Int
        if bouge, let t = tire { j = t > g.W / 2 ? 1 : 0 }
        else if let tap { j = tap > g.W / 2 ? 1 : 0 }
        else { j = choix }
        bouge = false
        withAnimation(Self.ressort) {
            tire = nil
            choix = j
        }
    }

    private func armerGarde(_ g: Cotes) {
        garde?.cancel()
        garde = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, bouge || tire != nil else { return }
            finir(g, tap: nil)
        }
    }

    /// La géométrie d'une piste de largeur W : deux moitiés, un pouce par
    /// moitié, l'encart du slider sur le bord extérieur, la moitié de l'encart
    /// au milieu (les deux pouces possibles ne se touchent pas).
    struct Cotes {
        let W: CGFloat
        let encart: CGFloat
        var demiLargeur: CGFloat { max((W / 2 - encart * 1.5) / 2, 1) }
        func centre(_ i: Int) -> CGFloat {
            i == 0 ? encart + demiLargeur : W - encart - demiLargeur
        }
        func borne(_ x: CGFloat) -> CGFloat { min(max(x, centre(0)), centre(1)) }
    }
}

// MARK: - La matière, un seul shader, animable

/// La capsule d'obsidienne et son pouce de chrome, par `sliderObsidienne`,
/// temps FIGÉ. `x` est la seule valeur animée : SwiftUI l'interpole et le
/// shader ne se redessine que pendant le mouvement.
///
/// Sert aussi la vitrine de Réglages (le slider au repos, pouce à gauche).
struct MatiereObsidienne: View, Animatable {
    /// Centre du pouce, depuis le bord gauche de la piste.
    var x: CGFloat
    let demiLargeur: CGFloat
    let demiHauteur: CGFloat
    let largeur: CGFloat
    let hauteur: CGFloat
    var plate = false

    var animatableData: CGFloat {
        get { x }
        set { x = newValue }
    }

    /// Marge de l'hôte du shader : l'ombre et le débord du pouce vivent
    /// dedans (`SliderObsidienne.pad`).
    private static let pad: CGFloat = 52
    /// Le temps du shader, figé : le fil de métal ne court pas, il est POSÉ.
    private static let tFige: Float = 0

    // Les réglages du fil de métal liquide — ceux du slider, À LA LETTRE
    // (`SliderObsidienne.swift:170-187`). Les changer ici ferait deux chromes.
    private static let repetition: Float = 0.80
    private static let angle: Float = 94 * .pi / 180
    private static let softness: Float = 0.20
    private static let contour: Float = 0.88
    private static let distortion: Float = 0.42
    private static let speed: Float = 0.20
    private static let shiftRed: Float = 0.017
    private static let shiftBlue: Float = 0.032
    private static let influence: Float = 7.0
    private static let gold: Float = 0.0
    private static let lineW: Float = 1.05
    private static let glow: Float = 0.30
    private static let floorLevel: Float = 0.30

    var body: some View {
        Color.clear
            .frame(width: largeur, height: hauteur)
            .background {
                if plate { capsulePlate } else { matiere }
            }
            .allowsHitTesting(false)
    }

    /// Le barreau : la même géométrie, sans shader.
    private var capsulePlate: some View {
        ZStack {
            Capsule().fill(Color(white: 0.03))
            Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            Capsule()
                .fill(Color(white: 0.17))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 1))
                .frame(width: demiLargeur * 2, height: demiHauteur * 2)
                .position(x: x, y: hauteur / 2)
        }
        .frame(width: largeur, height: hauteur)
    }

    private var matiere: some View {
        // TOUS les scalaires en `let` typés AVANT l'appel (le mur du
        // type-checker, payé dans `SliderObsidienne.matiere`).
        let pad = Float(Self.pad)
        let hw = Float(largeur + 2 * Self.pad)
        let hh = Float(hauteur + 2 * Self.pad)
        let h = Float(hauteur)
        let px = Float(x)
        let pw = Float(demiLargeur)
        let ph = Float(demiHauteur)
        let amp: Float = 1.42
        let pic: Float = 0.239
        var shader = ShaderLibrary.sliderObsidienne(
            .float2(hw, hh), .float(Self.tFige), .float(pad),
            .float4(px, pw, ph, 0),
            .float4(Self.repetition, Self.angle, Self.softness, Self.contour),
            .float4(Self.distortion, Self.speed, Self.shiftRed, Self.shiftBlue),
            .float4(Self.influence, Self.gold, Self.lineW, Self.glow),
            .float(Self.floorLevel),
            .float4(0.100, 0.60, h * 0.056, pic),
            .float4(h * 0.029, h * 0.019, 30, 32),
            .float4(0.62, h * 0.26, 0, 0),
            .float4(0, 0, 0, amp))
        // La matière est faite de dégradés de 2 % : sur OLED ils bandent.
        shader.dithersColor = true
        return Rectangle()
            // JAMAIS `.clear` : l'alpha nul de l'hôte avale tout le rendu.
            .fill(.white)
            .frame(width: CGFloat(hw), height: CGFloat(hh))
            .colorEffect(shader)
    }
}
