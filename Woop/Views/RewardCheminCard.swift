import SwiftUI
import UIKit

// LA CARD À GRATTER — `Claim → Nosfy → Scratch → Reward`.
//
// Trois couches, et AUCUNE ne se recalcule par image (la loi de la page
// ré-évaluée) :
//   1. la récompense, dessous, montée une fois ;
//   2. la surface noire embossée, masquée par le tracé du doigt — le masque
//      est un `Canvas` mis à jour sur les ÉVÉNEMENTS DE TOUCHE, pas à la
//      cadence de l'écran ;
//   3. la poudre de diamant, un `Canvas` BORNÉ À LA CARD (jamais plein
//      écran : un Canvas rasterise toute sa surface même vide), au nombre de
//      grains plafonné.
//
// ⚠️ Le masque ne porte JAMAIS sur une couche vidéo : un masque sur un
// `AVPlayerLayer` force un rendu hors écran de tout le plan à chaque image.
// C'est le NOIR qui porte le masque, la vidéo vit dessous, intacte.

struct CardRecompense: View {
    let tirage: RecompenseTiree
    var dejaRevele: Bool = false
    var onRevele: () -> Void = {}
    var onFermer: () -> Void = {}

    static let largeur: CGFloat = 321
    static let hauteur: CGFloat = 424
    /// Le pinceau, en points — et la grille de couverture qu'il marque.
    private static let pinceau: CGFloat = 30
    private static let colonnes = 18
    private static let rangees = 26
    /// Le seuil de bascule. Un chiffre à régler au doigt, pas une loi.
    private static let seuil: CGFloat = 0.55

    @State private var nosfyRange = false
    @State private var nosfyPrise: CGSize = .zero
    @State private var nosfyPose: CGSize = .zero
    @State private var trace: [CGPoint] = []
    @State private var cases = Set<Int>()
    @State private var revele = false
    @State private var grains: [(pos: CGPoint, naissance: Date)] = []
    @GestureState private var gratteEnCours = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            recompense
            if !revele { voileAGratter }
            if !revele && !nosfyRange { nosfy }
        }
        .frame(width: Self.largeur, height: Self.hauteur)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay { liseréCard }
        .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
        // hors du `clipShape` ET hors du cadre : la sortie vit sous la card.
        .overlay(alignment: .bottom) { fermer.offset(y: 46) }
        .onAppear { demarrer() }
    }

    // MARK: la coque

    private var liseréCard: some View {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
            .stroke(.white.opacity(0.14), lineWidth: 0.8)
            .allowsHitTesting(false)
    }

    /// ⚠️ Le mot de sortie posait sur un sachet et devenait illisible. Il vit
    /// maintenant SOUS la card, sur le voile — c'est aussi plus juste : la
    /// card est l'objet, la sortie n'en fait pas partie.
    private var fermer: some View {
        Button(action: onFermer) {
            Text(revele ? "Close" : "Later")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .padding(.vertical, 12)
                .padding(.horizontal, 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func demarrer() {
        if dejaRevele { revele = true }
        RocketHaptics.shared.prepare()
        // banc `-rewardAuto` : Nosfy se range seul, puis la lune se gratte —
        // le film complet sans doigt (le simulateur n'en pose pas).
        guard CommandLine.arguments.contains("-rewardAuto") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                nosfyRange = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeOut(duration: 0.45)) { revele = true }
        }
    }

    // MARK: la surface à gratter

    /// LA SURFACE — l'asset `dark-scratch` : presque noir de bout en bout
    /// (luminance moyenne 13,7 sur 255, 99ᵉ centile 23,1) avec ses croissants
    /// EN RELIEF. C'est la lune embossée dans le noir qu'elle décrivait, et la
    /// surface à gratter : un seul objet pour les deux.
    private var voileAGratter: some View {
        Image("dark-scratch")
            .resizable()
            .scaledToFill()
            .frame(width: Self.largeur, height: Self.hauteur)
            .clipped()
            .overlay { invite }
            .mask { masqueGrattage }
            .overlay { poudre }
            .contentShape(Rectangle())
            .gesture(gratter)
            .allowsHitTesting(nosfyRange)
    }

    /// Le mot qui dit quoi faire — il s'efface dès le premier trait.
    @ViewBuilder private var invite: some View {
        if trace.isEmpty && nosfyRange {
            Text("Scratch to reveal")
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.30))
        }
    }

    /// LE MASQUE — plein, moins le tracé. Il ne se redessine QUE quand le
    /// tracé change, c'est-à-dire sur les événements de touche.
    private var masqueGrattage: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .color(.white))
            guard trace.count > 0 else { return }
            var p = Path()
            p.move(to: trace[0])
            for pt in trace.dropFirst() { p.addLine(to: pt) }
            ctx.blendMode = .destinationOut
            ctx.stroke(p, with: .color(.black),
                       style: StrokeStyle(lineWidth: Self.pinceau * 2,
                                          lineCap: .round, lineJoin: .round))
            // le point isolé (un tap qui ne bouge pas) doit gratter aussi
            if trace.count == 1 {
                let r = Self.pinceau
                ctx.fill(Path(ellipseIn: CGRect(x: trace[0].x - r,
                                                y: trace[0].y - r,
                                                width: r * 2, height: r * 2)),
                         with: .color(.black))
            }
        }
    }

    @ViewBuilder private var poudre: some View {
        if !grains.isEmpty {
            PoudreGrattage(grains: grains)
                .allowsHitTesting(false)
        }
    }

    // MARK: le geste du grattage

    private var gratter: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($gratteEnCours) { _, e, _ in e = true }
            .onChanged { g in marquer(g.location, vitesse: g.velocity) }
            .onEnded { _ in finirGrattage() }
    }

    /// Un point n'entre que s'il a AVANCÉ : sans cette décimation le tracé
    /// grossit sans fin et le masque finit par coûter cher à redessiner.
    private func marquer(_ p: CGPoint, vitesse: CGSize) {
        if let d = trace.last, hypot(p.x - d.x, p.y - d.y) < 7 { return }
        trace.append(p)
        semerGrains(p)
        marquerCases(p)
        let v = min(1, hypot(vitesse.width, vitesse.height) / 900)
        if !reduceMotion { RocketHaptics.shared.dragLevel(0.18 + 0.5 * v) }
        if CGFloat(cases.count) / CGFloat(Self.colonnes * Self.rangees)
            >= Self.seuil { reveler() }
    }

    /// LA COUVERTURE se mesure sur une GRILLE, pas sur des pixels d'écran :
    /// on marque les cases sous le pinceau, et le taux est un rapport de
    /// cases. Aucune lecture de framebuffer, aucun coût par image.
    private func marquerCases(_ p: CGPoint) {
        let cw = Self.largeur / CGFloat(Self.colonnes)
        let ch = Self.hauteur / CGFloat(Self.rangees)
        let r = Self.pinceau
        let c0 = max(0, Int((p.x - r) / cw)), c1 = min(Self.colonnes - 1, Int((p.x + r) / cw))
        let r0 = max(0, Int((p.y - r) / ch)), r1 = min(Self.rangees - 1, Int((p.y + r) / ch))
        guard c0 <= c1, r0 <= r1 else { return }
        for c in c0 ... c1 {
            for l in r0 ... r1 { cases.insert(l * Self.colonnes + c) }
        }
    }

    private func semerGrains(_ p: CGPoint) {
        guard !reduceMotion else { return }
        if grains.count >= 90 {
            let vieux = Date().addingTimeInterval(-0.9)
            grains.removeAll { $0.naissance < vieux }
        }
        guard grains.count < 90 else { return }
        // cinq grains par pas de doigt au lieu de trois : la paillette se
        // fait par le NOMBRE de petits, pas par la taille de chacun.
        for _ in 0 ..< 5 {
            let a = Double.random(in: 0 ..< 2 * .pi)
            let d = CGFloat.random(in: 4 ... Self.pinceau)
            grains.append((CGPoint(x: p.x + cos(a) * d, y: p.y + sin(a) * d),
                           Date()))
        }
    }

    private func finirGrattage() {
        RocketHaptics.shared.dragEnd()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let vieux = Date().addingTimeInterval(-0.9)
            grains.removeAll { $0.naissance < vieux }
        }
    }

    private func reveler() {
        guard !revele else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        RocketHaptics.shared.dragEnd()
        withAnimation(.easeOut(duration: 0.45)) { revele = true }
        onRevele()
    }

    // MARK: Nosfy

    /// LE STICKER — la vignette holographique au croissant. Il FLOTTE au-dessus
    /// de la card (ombre portée, léger bercement), on l'attrape, on le pousse
    /// dans la card : arrivé dedans il se range, et c'est ÇA qui arme le
    /// grattage.
    ///
    /// ⚠️ `@GestureState` sur la prise : un geste peut mourir sans `onEnded`
    /// (app en fond, Reachability qui vole le doigt) — sans lui, Nosfy resterait
    /// collé au doigt à vie.
    ///
    /// ⚠️ **QUATRE FOIS PLUS PETIT** (28-08) : 132 → **33 pt**. Et ces 33 pt
    /// posent un problème que le réglage seul ne voit pas — **on passe SOUS les
    /// 44 pt de cible tactile d'Apple**, donc l'objet deviendrait joli et
    /// inattrapable. La vignette rétrécit, mais la **PRISE reste à 64 pt** :
    /// un `contentShape` par-dessus, exactement la parade de la maison pour une
    /// vue trop petite ou sans taille propre pour attraper un geste.
    /// L'ombre suit l'échelle — un rayon de 18 sous un objet de 33 est un
    /// halo, pas une ombre portée.
    private var nosfy: some View {
        Image("sticker-nosfy")
            .resizable()
            .scaledToFit()
            .frame(width: 33)
            .rotationEffect(.degrees(-7))
            .shadow(color: .black.opacity(0.7), radius: 5, y: 3)
            .frame(width: 64, height: 64)
            .contentShape(Rectangle())
            .offset(x: nosfyPose.width + nosfyPrise.width,
                    y: -Self.hauteur * 0.30 + nosfyPose.height + nosfyPrise.height)
            .gesture(porterNosfy)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
            .zIndex(3)
    }

    private var porterNosfy: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { g in nosfyPrise = g.translation }
            .onEnded { g in
                nosfyPrise = .zero
                let y = -Self.hauteur * 0.30 + nosfyPose.height + g.translation.height
                if y > -Self.hauteur * 0.08 { rangerNosfy() }
                else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                        nosfyPose.width += g.translation.width
                        nosfyPose.height += g.translation.height
                    }
                }
            }
    }

    private func rangerNosfy() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
            nosfyRange = true
        }
    }

    // MARK: la récompense, dessous

    @ViewBuilder private var recompense: some View {
        switch tirage.type {
        case .coins: RecompensePieces(tirage: tirage, revele: revele)
        case .boosters: RecompenseBoosters(tirage: tirage, revele: revele)
        }
    }
}

// MARK: - La poudre de diamant

/// LA POUDRE DU DOIGT — bornée à la card, jamais plein écran.
///
/// ⚠️ **DE LA PAILLETTE, PAS DE LA POUSSIÈRE** (28-08 : « la poudre doit être
/// plus fine, de paillette »). Ce qui fait une paillette n'est pas la taille
/// moyenne, c'est le RÉGIME du scintillement : des grains presque tous
/// minuscules et sourds, et quelques-uns qui ÉCLATENT une image. D'où
/// `pow(|sin|, 4)` — une puissance élevée écrase les valeurs moyennes et ne
/// laisse passer que les crêtes. Un scintillement en sinus nu donne un
/// grouillement uniforme ; c'est de la poussière, pas du diamant.
///
/// Le scintillement vient d'un ANGLE par grain, jamais d'un blur par grain
/// (un blur par objet coûte 27 img/s, mesuré dans cette maison).
struct PoudreGrattage: View {
    let grains: [(pos: CGPoint, naissance: Date)]

    /// 0,7 s : plus court qu'avant (0,9). Une paillette ne traîne pas.
    private static let vie: Double = 0.7

    // MARK: - LE RÉGIME DIAMANT — la seule définition de l'app
    //
    // ⚠️ Sorti en `static` le 29-08, parce qu'une DEUXIÈME poudre était née
    // dans le coffre avec ses propres cotes — grains de 0,8 à 2,2 pt, soit
    // deux fois et demie ceux-ci. Verdict : *« les petites particules sont
    // trop grosses, prends la petite poussière de diamant des pop-up »*.
    // Deux poudres dans une app, c'est deux vérités sur ce qu'est une
    // paillette. Il n'y en a plus qu'une, et elle est ici.

    /// ⚠️ **LE RÉGIME AVANT LA TAILLE.** Ce qui fait « diamant » plutôt que
    /// « grouillement », ce n'est pas la moyenne, c'est la RARETÉ des crêtes :
    /// des grains presque tous sourds, quelques-uns qui éclatent. La
    /// puissance 4 est ce qui creuse entre les deux.
    static func eclat(_ phase: Double) -> Double { pow(abs(sin(phase)), 4) }

    /// 0,30 → 0,95 pt. **Le grain le plus gros reste SOUS le point** — avant,
    /// le plus petit faisait déjà 1,2 et ça se lisait comme de la semoule.
    static func rayon(_ eclat: Double) -> CGFloat { CGFloat(0.30 + 0.65 * eclat) }

    /// Une paillette sur cinq tire vers le FROID : c'est ce qui fait
    /// « diamant » plutôt que « craie ».
    static func teinte(_ i: Int) -> Color {
        i % 5 == 0 ? Color(red: 0.82, green: 0.92, blue: 1.0) : .white
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { tl in
            Canvas { ctx, _ in
                let t = tl.date
                for (i, g) in grains.enumerated() {
                    let age = t.timeIntervalSince(g.naissance)
                    guard age < Self.vie else { continue }
                    let u = age / Self.vie
                    let monte = CGFloat(u) * 26
                    let fondu = (1 - u) * (1 - u)
                    // LE RÉGIME : crêtes rares, fond sourd.
                    let phase = Double(i) * 12.9898 + age * 13
                    let eclat = Self.eclat(phase)
                    let r = Self.rayon(eclat)
                    let a = fondu * (0.22 + 0.78 * eclat)
                    // une dérive latérale propre à chaque grain
                    let d = CGFloat(sin(Double(i) * 7.13)) * monte * 0.45
                    let p = CGPoint(x: g.pos.x + d, y: g.pos.y - monte)
                    let teinte = Self.teinte(i)
                    ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r,
                                                    width: r * 2, height: r * 2)),
                             with: .color(teinte.opacity(a)))
                }
            }
            .blendMode(.plusLighter)
        }
    }
}
