import SwiftUI

// MARK: - Le coffre du header
//
// Une icône posée à droite de « Bonjour Kathryn », sur la même ligne. Au
// toucher elle FUME — la même fumée que la couronne de filtres de la page
// Exercices (`knobSmoke`, ExosHalo.metal), avec d'autres nombres. Puis la
// page du trésor s'ouvre.

/// La place du coffre, publiée vers le haut.
///
/// Le coffre vit dans la pile du header, DANS le défilement. Sa fumée, elle,
/// déborde de près de cent points — une overlay posée à côté de l'image
/// serait tranchée net par le bord du `ScrollView`, et un trait droit dans
/// un nuage se voit à la première image. Le coffre publie donc son cadre, et
/// c'est le ZStack de la page — hors défilement, hors zone sûre — qui
/// dessine la fumée à cette place.
struct ChestBoundsKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?,
                       nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// Le coffre lui-même : rien qu'une image et un enfoncement.
///
/// L'imageset est pré-rendu aux trois échelles exactes (67 × 42 pt) plutôt
/// que réduit à la volée depuis le PNG de 1254 px : à @3x c'était une
/// réduction 10:1, et les filets d'or du coffre — des traits d'un pixel —
/// se seraient mis à grésiller d'une image à l'autre. Le piège est déjà au
/// dossier (la carte Objectif l'a payé).
struct TreasureChestButton: View {
    /// Le doigt se pose / se lève — c'est la page qui tient l'horloge de la
    /// fumée, parce que c'est elle qui la dessine.
    var onPress: (Bool) -> Void
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("coffre-tresor")
                .resizable()
                .scaledToFit()
                .frame(height: 42)
                .anchorPreference(key: ChestBoundsKey.self, value: .bounds) { $0 }
        }
        .buttonStyle(ChestPressStyle(onPress: onPress))
        .accessibilityLabel("Ton trésor")
        .accessibilityHint("Ouvre la page du trésor")
    }
}

/// L'enfoncement : court et amorti. Le coffre est un objet lourd — il
/// s'enfonce, il ne rebondit pas.
private struct ChestPressStyle: ButtonStyle {
    var onPress: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.72),
                       value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                onPress(pressed)
            }
    }
}

// MARK: - La fumée

/// La fumée du coffre : le MÊME shader que la couronne de filtres, appelé
/// avec d'autres nombres — pas une imitation. Attaque 0,10 s, relâche
/// 0,45 s, plus l'onde de toucher qui part du bord et meurt en un tiers de
/// seconde.
///
/// Au repos ce sous-arbre N'EXISTE PAS (la page ne le monte que si une
/// horloge est posée) : coût nul tant que personne ne touche.
struct ChestSmoke: View {
    /// Le centre du coffre, dans l'espace de la page.
    let center: CGPoint
    let start: Date
    /// Le doigt s'est levé, ou `nil` s'il est encore posé.
    let end: Date?

    /// Le rayon de la « couronne » que la fumée entoure : le coffre fait
    /// 67 × 42 pt, un cercle de 26 pt le coiffe sans déborder de sa masse.
    private static let radius: CGFloat = 26
    /// La portée de l'hôte. L'onde du toucher part à `R + 150 × age` : à
    /// 0,45 s elle est à 93 pt du centre. En deçà, elle mourrait contre le
    /// bord du rectangle — et un nuage à bord droit n'est plus un nuage.
    private static let reach: CGFloat = 96

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date
            let age = now.timeIntervalSince(start)
            let attack = min(age / 0.10, 1.0)
            let release = end.map { now.timeIntervalSince($0) } ?? 0
            let puff = attack * exp(-max(release, 0) / 0.45)
            let t = now.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900)
            let side = Self.reach * 2

            Rectangle()
                .fill(.white)
                .frame(width: side, height: side)
                .colorEffect(ShaderLibrary.knobSmoke(
                    .float2(Float(side), Float(side)),
                    .float(Float(t)),
                    .float4(Float(Self.reach), Float(Self.reach),
                            Float(Self.radius), Float(Self.radius * 1.5)),
                    .float(Float(puff)),
                    .float(Float(age))
                ))
                .position(center)
        }
        .allowsHitTesting(false)
    }
}
