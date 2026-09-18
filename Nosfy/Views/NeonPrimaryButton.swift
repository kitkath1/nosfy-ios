import SwiftUI
import UIKit

// MARK: - Bouton « primary néon »
//
// Une plaque de métal noir brossé (NeonPrimary.metal, `neonPlate`) et un
// lettrage Inter qui, au repos, n'est qu'un DÉGRADÉ BLANC — de la lumière de
// studio sur du métal poli. Sous le doigt, le lettrage s'ALLUME de l'ambre du
// logo lune, avec le grésillement d'un tube qui s'amorce, et la plaque
// s'alourdit derrière lui.
//
// Le point qui décide de tout : ce n'est pas le bouton qui s'allume, c'est le
// TEXTE. La plaque ne fait que recevoir sa lumière. Un bouton qui s'illumine
// en entier ressemble à un néon publicitaire ; un lettrage qui s'allume sur une
// plaque sombre ressemble à un objet.

/// L'ambre du logo lune, relevé canal par canal sur LogoMonolith.metal :
/// tube (1,00 ; 0,30 ; 0,045) → (1,00 ; 0,45 ; 0,135), halo (1,00 ; 0,42 ; 0,13).
/// Le cœur du tube est plus clair que sa gaine — un néon vu de près a un
/// filament blanc-chaud au milieu de sa couleur.
private enum NeonInk {
    static let core = Color(red: 1.00, green: 0.965, blue: 0.90)
    static let tube = Color(red: 1.00, green: 0.72, blue: 0.42)
    static let halo = Color(red: 1.00, green: 0.42, blue: 0.13)
}

// MARK: - L'amorçage du tube

/// Le « petit bruit de lumière » : un tube au néon ne s'allume pas d'un trait,
/// il AMORCE. Deux ou trois décharges très brèves, de plus en plus proches,
/// puis le régime s'établit. Tout est en secondes depuis l'appui.
///
/// La courbe est écrite à la main plutôt que tirée d'un bruit aléatoire : un
/// grésillement aléatoire donne un résultat différent à chaque appui, et
/// l'oreille — ici l'œil — entend « bug » plutôt que « néon ». Un vrai tube
/// grésille toujours de la même façon.
private func igniteEnvelope(_ s: Double) -> Double {
    if s < 0 { return 0 }
    // Les décharges : (début, durée, niveau). Entre elles, le noir.
    let bursts: [(Double, Double, Double)] = [
        (0.000, 0.026, 0.85),   // première amorce, franche
        (0.052, 0.018, 0.35),   // elle retombe presque
        (0.082, 0.034, 1.00),   // deuxième, plus forte
        (0.130, 0.020, 0.55),
    ]
    for (t0, dur, level) in bursts where s >= t0 && s < t0 + dur {
        return level
    }
    if s < 0.150 { return 0.10 }               // les creux entre décharges
    // Puis le régime s'établit, avec un léger dépassement — un tube chauffe
    // au-delà de son point d'équilibre avant d'y redescendre.
    let u = min((s - 0.150) / 0.16, 1.0)
    let eased = u * u * (3 - 2 * u)
    return 0.55 + 0.45 * eased + 0.13 * sin(u * .pi) * (1 - u)
}

/// L'extinction, elle, est douce et sans grésillement : un tube ne clignote
/// qu'à l'amorçage, jamais en s'éteignant — il refroidit.
private func extinguishEnvelope(_ s: Double) -> Double {
    let u = min(max(s / 0.26, 0), 1)
    return 1 - u * u
}

// MARK: - Le composant

struct NeonPrimaryButton: View {
    var title: String
    /// Taille et graisse du lettrage. Elles ne sont pas fixées, parce que c'est
    /// le point encore ouvert : plus le trait est large, plus la gravure a de
    /// place pour se lire (sur la référence, le mur fait un tiers de la largeur
    /// du trait).
    var fontSize: CGFloat = 15
    var weight: Font.Weight = .semibold
    var tracking: CGFloat = 0.9
    /// Fige l'allumage (bancs et captures). Le pattern des bancs de la maison :
    /// figer l'état transitoire plutôt que taper au bon centième.
    var benchGlow: Double? = nil
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false
    /// Date du dernier changement d'état. C'est elle qui pilote l'enveloppe :
    /// on ne stocke jamais l'intensité, on la RECALCULE à chaque image depuis
    /// le temps écoulé. Une intensité stockée se désynchronise dès qu'une
    /// image est sautée.
    @State private var since: Date = .distantPast
    @State private var wasPressed = false

    private let height: CGFloat = 58
    private let radius: CGFloat = 16
    /// Marge de débordement du shader — le biseau a besoin d'un point ou deux
    /// pour son antialiasing. Le halo du néon, lui, vit hors de ce cadre.
    private static let pad: CGFloat = 8

    var body: some View {
        // CADENCE À DEUX RÉGIMES. L'amorçage du tube a besoin de 60 images par
        // seconde — ses décharges durent 18 à 34 ms, à 30 fps on en sauterait
        // une sur deux et le grésillement deviendrait aléatoire. Le repos, lui,
        // n'a que la fumée et les paillettes, qui bougent sur des périodes de 5
        // à 80 s : 20 fps y suffit largement.
        //
        // Ce n'est pas de la coquetterie. Ce shader tourne sur toute la surface
        // du bouton ; à 60 fps en permanence il occupait 15 % d'un cœur À LUI
        // SEUL, et le banc en affiche quatre. Un composant qui s'anime doit
        // payer sa cadence à l'usage, pas au maximum.
        let idle = benchGlow == nil && !wasPressed
            && Date.now.timeIntervalSince(since) > 0.5
        TimelineView(.animation(minimumInterval: idle ? 1.0 / 20.0 : 1.0 / 60.0,
                                paused: reduceMotion)) { tl in
            let now = tl.date
            let s = now.timeIntervalSince(since)
            let glow = envelope(s)
            let t = Float(now.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900))

            content(glow: glow, t: t)
        }
        .frame(height: height)
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .onTapGesture { action() }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !pressed { setPressed(true) } }
                .onEnded { _ in setPressed(false) }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(title)
    }

    private func envelope(_ s: Double) -> Double {
        if let benchGlow { return benchGlow }
        if reduceMotion { return wasPressed ? 1 : 0 }
        return wasPressed ? igniteEnvelope(s) : extinguishEnvelope(s)
    }

    private func setPressed(_ p: Bool) {
        guard p != pressed else { return }
        pressed = p
        wasPressed = p
        since = .now
        if p {
            // L'amorçage se SENT : un choc sec et bref, pas un impact mou. Un
            // tube qui claque, pas un bouton qui s'enfonce.
            let gen = UIImpactFeedbackGenerator(style: .rigid)
            gen.prepare()
            gen.impactOccurred(intensity: 0.55)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.082) {
                gen.impactOccurred(intensity: 0.85)
            }
        }
    }

    @ViewBuilder
    private func content(glow: Double, t: Float) -> some View {
        ZStack {
            plate(glow: glow, t: t)
            lettering(glow: glow)
        }
        // Le bouton s'ENFONCE d'un cheveu — 1,5 pt, pas davantage : au-delà,
        // la plaque quitte son ombre et l'objet flotte.
        .scaleEffect(1 - 0.006 * glow)
    }

    private func plate(glow: Double, t: Float) -> some View {
        GeometryReader { geo in
            let w = geo.size.width + Self.pad * 2
            let h = geo.size.height + Self.pad * 2
            Rectangle()
                .fill(.white)
                .frame(width: w, height: h)
                .colorEffect(Self.dithered(ShaderLibrary.neonPlate(
                    .float2(w, h), .float(t),
                    .float(Float(Self.pad)), .float(Float(radius)),
                    .float(Float(glow)))))
                .offset(x: -Self.pad, y: -Self.pad)
        }
        // L'ombre portée : elle se RESSERRE quand le bouton s'allume — l'objet
        // descend vers sa surface. C'est l'autre moitié de « plus lourd ».
        .shadow(color: .black.opacity(0.55 + 0.25 * glow),
                radius: 18 - 6 * glow, y: 9 - 3 * glow)
        // Et la lumière du tube passe SOUS la plaque : un halo ambre au sol,
        // qui n'existe que bouton allumé.
        .shadow(color: NeonInk.halo.opacity(0.16 * glow), radius: 14, y: 4)
        .allowsHitTesting(false)
    }

    /// LE LETTRAGE EST UN CREUX, pas une couleur.
    ///
    /// Mesuré au pixel sur la pièce de référence de Kathryn (le dollar
    /// incrusté dans le noir mat), en travers d'une hampe :
    ///
    ///     face 49 51 | 36 13 5 1 0 2 5 7 9 11 16 | 17 18 … 18 | 32 48 58 61 | 54 face
    ///                  ^ le mur d'ombre tombe à ZÉRO            ^ le mur de lumière
    ///
    /// Trois faits, et aucun n'est « la forme est plus sombre » :
    ///   1. le fond de la cuvette vaut 35 % de la face (17-18 contre 49-51) ;
    ///   2. le mur qui tourne le dos à la lumière tombe à 0 — plus sombre que
    ///      le fond lui-même. C'est ce trait noir qui fait TOUT le relief ;
    ///   3. le mur opposé ne dépasse la face que de +6. Sur une matière mate,
    ///      un mur éclairé ne peut pas beaucoup dépasser sa surface — le
    ///      surligner davantage donnerait du plastique embossé.
    ///
    /// LE SENS DE LA LUMIÈRE se lit dans les deux axes et il est contre-
    /// intuitif : dans un SILLON, ce sont les murs OPPOSÉS à la source qui
    /// s'éclairent. Sur la référence le mur gauche et le mur haut tombent tous
    /// deux à 0, le mur droit monte à 61 et le mur bas à 67 — donc la lampe est
    /// EN HAUT À GAUCHE, et le trait clair se pose en bas à droite. Poser le
    /// clair en haut à gauche, réflexe naturel, inverserait le relief : les
    /// lettres sortiraient de la plaque au lieu d'y entrer.
    ///
    /// Réalisation : deux copies décalées d'un demi-point. À 15 pt, une hampe
    /// d'Inter fait 5,7 px à 3x et le mur ne peut faire qu'un pixel ou deux —
    /// à cette taille, une gravure EST une gravure typographique, il n'y a pas
    /// la place pour un dégradé de paroi.
    private func lettering(glow: Double) -> some View {
        ZStack {
            // Le mur d'ombre, en haut à gauche. Noir pur, comme la référence.
            label.foregroundStyle(.black)
                .offset(x: -0.5, y: -0.5)
            // Le mur de lumière, en bas à droite. Discret — +6 sur la face.
            label.foregroundStyle(Color(white: 0.34))
                .offset(x: 0.5, y: 0.5)
            // Le fond de la cuvette, par-dessus les deux : 35 % de la face.
            label.foregroundStyle(Color(white: 0.055))
        }
        .compositingGroup()
        .allowsHitTesting(false)
    }

    private var label: some View {
        Text(title)
            .font(.inter(fontSize, weight))
            .tracking(tracking)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}
