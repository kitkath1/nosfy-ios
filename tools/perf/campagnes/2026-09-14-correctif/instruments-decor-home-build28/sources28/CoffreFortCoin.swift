import SwiftUI

// MARK: - La pièce du header
//
// Une pièce de lune posée à droite de « Bonjour Kathryn », sur la même
// ligne. Au toucher : une vibration, un tintement, une fumée claire — puis
// la page du trésor.
//
// ELLE A REMPLACÉ UN COFFRE. Le coffre était un rendu 3D en PNG : sa lumière
// était cuite à l'export, il ne répondait ni au gyroscope ni à rien, et
// c'était le seul objet CLOUÉ d'une page qui respire. D'où le « ça fait un
// peu fake » — le défaut n'était pas la qualité de l'image, c'était qu'une
// image ne peut pas partager la lumière de la page qui la porte.

/// La place de la pièce, publiée vers le haut.
///
/// Elle vit dans la pile du header, DANS le défilement. Sa fumée, elle,
/// déborde largement — une overlay posée à côté d'elle serait tranchée net
/// par le bord du `ScrollView`, et un trait droit dans un nuage se voit à la
/// première image. La pièce publie donc son cadre, et c'est le ZStack de la
/// page — hors défilement — qui dessine la fumée à cette place.
struct CoffreFortCoinBounds: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?,
                       nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

/// La pièce du header.
///
/// LA BOÎTE FAIT 46 pt, L'HÔTE DU SHADER 156. Le shader a besoin de déborder
/// pour son halo ; sans ce `Color.clear` de gabarit, l'hôte imposerait sa
/// taille à la ligne du salut et ferait grandir tout le header de cent
/// points. Une overlay n'est pas rognée par SwiftUI, donc la lumière sort
/// librement.
struct CoffreFortCoinButton: View {
    @Environment(\.decorHomeAuRepos) private var decorAuRepos
    var onPress: (Bool) -> Void
    var action: () -> Void
    /// Le MAT de la pièce, passé tel quel au shader : 0 = l'or du header
    /// v1, 1 = l'anthracite de BRAVO — le métal s'éteint, reflets et
    /// tranche gardés, et le croissant descend de lui-même à 52 %. C'est
    /// la pièce de la home v2 (verdict 24-08 : « en noir pas or, plus
    /// premium, néon discret »).
    var matte: Float = 0

    /// `-sansPiece` : bisection. `static let` — évalué une fois, jamais dans
    /// un `body`.
    private static let sansPiece =
        CommandLine.arguments.contains("-sansPiece")

    /// Le diamètre visible. Parti de 42 (la taille du coffre), monté à 52
    /// pour qu'un bijou qu'on fait tourner ait de quoi se montrer, puis
    /// redescendu à 46 : à 52 elle pesait plus lourd que le salut lui-même.
    static let diameter: CGFloat = 46

    var body: some View {
        Color.clear
            .frame(width: Self.diameter, height: Self.diameter)
            .anchorPreference(key: CoffreFortCoinBounds.self, value: .bounds) { $0 }
            .overlay {
                // ⚠️ `-sansPiece` : la pièce FIGÉE, pour la bisection sur
                // TÉLÉPHONE. Son propre fichier le dit — « un abonnement au
                // tilt d'un @Observable qui réévalue toutes les pièces au
                // rythme du gyroscope : invisible au simulateur (le tilt y
                // reste nul), PAYÉ SUR LE TÉLÉPHONE ». C'est donc le seul
                // suspect qu'aucune mesure au simulateur ne pouvait voir.
                MoonCoinView(coinR: Self.diameter / 2, matte: matte,
                             onTap: {
                    onPress(true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                        onPress(false)
                    }
                    action()
                }, figee: Self.sansPiece || decorAuRepos
                    || ProtectionThermique.shared.ambianceAuRepos)
            }
    }
}

// MARK: - La fumée

/// LA CUISSON DU SHADER DE FUMÉE, hors du chemin d'affichage.
///
/// SwiftUI compile un shader PARESSEUSEMENT, à son premier usage, et cette
/// compilation-là tombe sur le fil principal — la leçon est déjà écrite dans
/// `MoonSDF` (« C'était le "ça bugue au début" »). Or `coinSmoke` était le
/// seul pipeline encore FROID du parcours d'une séance : `moonCoin` est
/// chauffé bien avant par les pièces de l'historique de la fiche, mais la
/// fumée, elle, n'existe que si un doigt se pose. Le premier tap de la page
/// BRAVO payait donc la cuisson entière.
///
/// Et sur BRAVO ça ne coûte pas qu'un à-coup : toute la cérémonie est une
/// FONCTION DU TEMPS MURAL. Une image qui n'est pas présentée n'est pas
/// retardée, elle est DÉTRUITE — la caméra repart là où le temps est arrivé.
/// Un blocage au premier tap ne fait donc pas « saccader » la vidéo : il fait
/// SAUTER le plan, exactement comme le splash le faisait avant sa garde.
enum CoinSmokeWarm {
    /// Un exemplaire aux arguments inertes, uniquement pour forcer la
    /// compilation. La signature est recopiée à l'identique de l'appel réel
    /// ci-dessous : se tromper d'arité chaufferait une AUTRE variante et ne
    /// servirait à rien (le piège du stitchable, payé ailleurs).
    private static var probe: Shader {
        ShaderLibrary.coinSmoke(.float2(100, 100), .float(0),
                                .float3(50, 50, 20), .float(0), .float(0),
                                .float3(0, 0, 0), .float(0))
    }

    static func warmUp() {
        Task.detached(priority: .utility) {
            try? await probe.compile(as: .colorEffect)
        }
    }
}

/// La fumée de la pièce, en deux teintes.
///
/// UNE FUMÉE SE LIT PAR CONTRASTE AVEC CE QU'IL Y A DERRIÈRE, et le derrière
/// n'est pas le même des deux côtés :
///   — dans le header, le fond est le halo ORANGE CLAIR de l'aurore : il
///     faut une fumée CLAIRE et délicate. Une fumée sombre y ferait une
///     tache, pas un souffle.
///   — sur la page du trésor, le fond est noir : il faut une fumée SOMBRE,
///     à peine plus claire que la nuit. Une fumée blanche y serait un nuage
///     posé sur l'écran.
///
/// Au repos ce sous-arbre N'EXISTE PAS (la page ne le monte que si une
/// horloge est posée) : coût nul tant que personne ne touche.
struct CoinSmoke: View {
    /// Le centre de la pièce, dans l'espace de la page.
    let center: CGPoint
    /// Son rayon — la fumée sort du métal, pas d'un point.
    var radius: CGFloat = 23
    let start: Date
    /// Le doigt s'est levé, ou `nil` s'il est encore posé.
    let end: Date?
    var palette: Palette = .light

    enum Palette {
        /// Header, sur le halo orange.
        case light
        /// Page du trésor, sur la nuit.
        case dark

        /// Trois `Float`, et non un `SIMD3` : c'est la surcharge de
        /// `Shader.Argument` utilisée partout ailleurs dans le projet.
        var tint: (Float, Float, Float) {
            switch self {
            case .light: return (0.900, 0.912, 0.960)
            // Composée pour culminer autour de 20/255 une fois multipliée
            // par sa couverture : « à peine plus claire que le fond ».
            case .dark: return (0.340, 0.312, 0.292)
            }
        }

        var gain: Float {
            switch self {
            case .light: return 0.30
            case .dark: return 0.52
            }
        }
    }

    /// La portée de l'hôte : l'enveloppe meurt à ~0,9 rayon du métal, et le
    /// fondu d'hôte du shader en mange 14 de plus.
    private var side: CGFloat { radius * 2 + 132 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date
            let age = now.timeIntervalSince(start)
            let attack = min(age / 0.10, 1.0)
            let release = end.map { now.timeIntervalSince($0) } ?? 0
            let puff = attack * exp(-max(release, 0) / 0.45)
            let t = now.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900)

            Rectangle()
                .fill(.white)
                .frame(width: side, height: side)
                .colorEffect(ShaderLibrary.coinSmoke(
                    .float2(Float(side), Float(side)),
                    .float(Float(t)),
                    .float3(Float(side / 2), Float(side / 2), Float(radius)),
                    .float(Float(puff)),
                    .float(Float(age)),
                    .float3(palette.tint.0, palette.tint.1, palette.tint.2),
                    .float(palette.gain)
                ))
                .position(center)
        }
        .allowsHitTesting(false)
    }
}
