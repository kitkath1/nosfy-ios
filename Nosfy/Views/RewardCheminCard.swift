import SwiftUI
import UIKit

// LA CARD À GRATTER — `Claim → Scratch → Reward`.
//
// ⚠️ Payé sur TestFlight 81 (19-09), premier verdict au doigt de cette card :
// « le petit ticket » (le sticker Nosfy) VERROUILLAIT le grattage — le voile
// noir était sourd tant qu'on ne l'avait pas traîné 93 pt vers le bas, il
// sortait de la card sans borne, et le seul mot d'aide n'apparaissait
// qu'après. Puis 55 % d'une grille qui comptait le bandeau vidéo : gratter
// toute la moitié basse, là où le chiffre est écrit, ne suffisait pas ; sous
// le trou on lisait « +0 coins ». Depuis le 20-09 : le voile écoute le doigt
// dès l'ouverture, le sticker n'est plus qu'une décoration posée dans la
// card, le mot est là d'emblée, le seuil est 30 % hors bandeau, et le
// montant réel est écrit sous le voile.
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
    /// Le seuil de bascule, en part des cases HORS bandeau vidéo. 0,55 sur la
    /// grille entière était inatteignable là où le chiffre est écrit (mesuré
    /// sur le build 81 : toute la moitié basse = 46 %). À 0,30, deux traits
    /// de pouce sur le chiffre suffisent, et `reveler` finit le travail.
    private static let seuil: CGFloat = 0.30
    /// LE BARREAU de la texture haptique du grattage : `-sansHaptiqueGrattage`
    /// la coupe, pour l'accuser ou la disculper sur iPhone (le simulateur ne
    /// vibre pas).
    private static let sansHaptique = CommandLine.arguments.contains("-sansHaptiqueGrattage")

    @State private var trace: [CGPoint] = []
    @State private var cases = Set<Int>()
    @State private var revele = false
    @State private var grains: [(pos: CGPoint, naissance: Date)] = []
    /// LA TEXTURE DU GRATTAGE — un tic léger par point accepté, jamais plus
    /// d'un toutes les 40 ms. ⚠️ Payé sur TestFlight 81 (19-09) : « la
    /// vibration énorme » était le grondement continu de la fusée
    /// (`RocketHaptics.dragLevel`, un événement de 60 s tenu sous le doigt et
    /// relancé à 1,0 à chaque pose). Un grattage est une texture, pas un
    /// moteur.
    @State private var texture = UIImpactFeedbackGenerator(style: .light)
    @State private var dernierTic: TimeInterval = 0
    @GestureState private var gratteEnCours = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            recompense
            if !revele { voileAGratter }
            if !revele { nosfy }
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
    /// ⚠️ 20-09 : « Later » promettait un plus tard qui n'existait pas (la
    /// card ne se rouvrait jamais). Elle se retrouve maintenant par le galet
    /// (`rouvrir`) et au lancement : le mot le dit.
    private var fermer: some View {
        Button(action: onFermer) {
            Text(revele ? L("Fermer", "Close") : L("Gratter plus tard", "Scratch later"))
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
        if !reduceMotion && !Self.sansHaptique { texture.prepare() }
        // banc `-rewardAuto` : la lune se gratte seule — le film complet
        // sans doigt (le simulateur n'en pose pas). Le rangement du sticker
        // à 1,6 s est mort avec le geste : il n'y a plus rien à ranger.
        guard CommandLine.arguments.contains("-rewardAuto") else { return }
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
            // ⚠️ Plus de `.allowsHitTesting(nosfyRange)` : le voile écoute le
            // doigt dès l'ouverture, sans condition.
    }

    /// Le mot qui dit quoi faire — là DÈS L'OUVERTURE, centré sur le voile
    /// sous le sticker, et il s'efface au premier trait. ⚠️ Payé sur
    /// TestFlight 81 (19-09) : il n'apparaissait qu'après le rangement du
    /// ticket, en blanc à 30 % — celle qui ne rangeait pas ne lisait jamais
    /// « scratch ».
    @ViewBuilder private var invite: some View {
        if trace.isEmpty {
            Text(L("GRATTER POUR RÉVÉLER", "SCRATCH TO REVEAL"))
                .font(.system(size: 13, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.60))
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
            .onChanged { g in marquer(g.location) }
            .onEnded { _ in finirGrattage() }
    }

    /// Un point n'entre que s'il a AVANCÉ : sans cette décimation le tracé
    /// grossit sans fin et le masque finit par coûter cher à redessiner.
    private func marquer(_ p: CGPoint) {
        if let d = trace.last, hypot(p.x - d.x, p.y - d.y) < 7 { return }
        trace.append(p)
        semerGrains(p)
        marquerCases(p)
        tic()
        if couverture >= Self.seuil { reveler() }
    }

    /// Un tic par point accepté, cadencé : deux points à moins de 40 ms ne
    /// font qu'un tic. Coupé par « Réduire les animations » et par le barreau.
    private func tic() {
        guard !reduceMotion, !Self.sansHaptique else { return }
        let t = Date().timeIntervalSinceReferenceDate
        guard t - dernierTic >= 0.040 else { return }
        dernierTic = t
        texture.impactOccurred(intensity: 0.35)
    }

    /// LA PREMIÈRE RANGÉE QUI COMPTE. Sur la robe pièces, le bandeau vidéo
    /// (232 pt sur 424) n'a rien à révéler : il est gratté si on y passe,
    /// mais il n'entre pas dans le taux. 232 / (424 / 26) = 14,2 → les
    /// rangées 0 à 13 sont exclues ; la 14 (228-244 pt) compte, elle porte
    /// déjà le fondu vers le noir. La robe boosters compte toute la grille.
    private var rangeeDepart: Int {
        guard tirage.type == .coins else { return 0 }
        let ch = Self.hauteur / CGFloat(Self.rangees)
        return min(Self.rangees - 1, Int(RecompensePieces.hauteurBandeau / ch))
    }

    /// Le taux de cases grattées, hors bandeau.
    private var couverture: CGFloat {
        let depart = rangeeDepart
        let comptees = cases.lazy.filter { $0 / Self.colonnes >= depart }.count
        let total = Self.colonnes * (Self.rangees - depart)
        return CGFloat(comptees) / CGFloat(max(total, 1))
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let vieux = Date().addingTimeInterval(-0.9)
            grains.removeAll { $0.naissance < vieux }
        }
    }

    /// La bascule : au seuil, la card FINIT LE GRATTAGE ELLE-MÊME — le voile
    /// (et le sticker) se fondent en 0,45 s, le `.heavy` marque le moment.
    private func reveler() {
        guard !revele else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        withAnimation(.easeOut(duration: 0.45)) { revele = true }
        onRevele()
    }

    // MARK: Nosfy

    /// LE STICKER — la vignette holographique au croissant, POSÉE dans la
    /// card comme une décoration du voile : 33 pt, penchée, son ombre portée.
    /// Il s'efface avec le voile à la révélation (échelle 0,4 + fondu).
    ///
    /// ⚠️ Payé sur TestFlight 81 (19-09) : il se traînait, et c'est LUI qui
    /// armait le grattage — 93 pt vers le bas pour que le voile écoute, sans
    /// ressort ni borne : lâché de côté il sortait de la card clippée et la
    /// card ne se grattait plus jamais (« le petit ticket qu'on peut faire
    /// disparaître »). Plus de geste, plus de prise, plus de `.rigid` du
    /// rangement : `allowsHitTesting(false)`, le doigt passe au voile dessous.
    /// Sa position est fixe (−30 % de la hauteur), donc toujours DANS la card.
    private var nosfy: some View {
        Image("sticker-nosfy")
            .resizable()
            .scaledToFit()
            .frame(width: 33)
            .rotationEffect(.degrees(-7))
            .shadow(color: .black.opacity(0.7), radius: 5, y: 3)
            .offset(y: -Self.hauteur * 0.30)
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
            .zIndex(3)
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
