import SwiftUI

// MARK: - Le corps blanc de l'iPod

/// LA NACRE PLEIN ÉCRAN : la matière du galet d'aube portée sur la page
/// entière de l'iPod du mois. La grammaire est celle du dôme
/// (`LaunchPebble`) : un fond à UNE SEULE RESPIRATION — sur toute coupe
/// verticale la dérivée ne change jamais de signe, l'épaule est morte —
/// et le brillant est un FOYER séparé, localisé sous la lampe
/// haut-gauche (la loi de la maison, `normalize(-1, -1.15)`). Un
/// gradient radial ne sait faire que des ANNEAUX : sur un rectangle
/// 393×852 il en dessinerait un lisible — le fond est donc LINÉAIRE
/// vertical, le foyer un voile elliptique localisé.
/// Toutes les teintes sont TIRÉES vers le papier maison
/// (0.956, 0.952, 0.942), jamais additionnées — le blanc ajouté arrive
/// JAUNE (la leçon de la page exo).
struct CorpsNacre: View {
    /// Le rayon des coins — l'intention : suivre l'écran. VERDICT
    /// MESURÉ au banc (A/B 40 vs 52) : à 40, le voile noir du portail
    /// pointe dans les quatre coins de la dalle (~52-55 physiques) ;
    /// à 52 le blanc épouse le bord — c'est le chiffre déjà tranché
    /// par la maison (StoryPortal, qui refuse `_displayCornerRadius`).
    /// L'estimation « 40 » vit toujours dans `-corpsRayon 40`.
    static let rayonEcran: CGFloat = {
        if let i = CommandLine.arguments.firstIndex(of: "-corpsRayon"),
           i + 1 < CommandLine.arguments.count,
           let v = Double(CommandLine.arguments[i + 1]) {
            return CGFloat(v)
        }
        return 52
    }()

    var rayon: CGFloat = CorpsNacre.rayonEcran
    /// L'ALLUMAGE [0,1] : le corps arrive voilé et MONTE au blanc
    /// pendant le portail — le blanc s'allume, il ne se coupe jamais
    /// net contre le noir (la loi crestFade du dôme d'exercice).
    var allume: CGFloat = 1

    // Les teintes (verdict 24-08 : « une matière un peu plus iPod ») :
    // le PLASTIQUE, pas la nacre crème — des blancs NEUTRES, à peine
    // chauds (−0,004 sur le bleu, juste de quoi éviter le clinique),
    // et une descente courte : l'iPod est presque plat, son volume
    // vient du liseré et de l'ombre du bord, pas d'un dégradé.
    private static let hautC = Color(red: 0.980, green: 0.979, blue: 0.976)
    private static let corpsC = Color(red: 0.958, green: 0.957, blue: 0.954)
    private static let flancC = Color(red: 0.934, green: 0.933, blue: 0.929)
    private static let piedC = Color(red: 0.908, green: 0.907, blue: 0.903)
    private static let foyerC = Color(red: 0.998, green: 0.997, blue: 0.994)

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: rayon, style: .continuous)
    }

    var body: some View {
        // Une couche = une variable : la loi anti-type-checker de la
        // maison (les overlays enchaînés ont déjà TUÉ le compilateur).
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)
            let lisere = lisereShader(w: w, h: h)
            ZStack {
                nacreFond
                nacreFoyer(w: w, h: h)
                nacreGrain
            }
            .compositingGroup()
            // LE CÔTÉ BRILLANT AU SHADER : filet + souffle + l'ombre
            // du bord (le noir contre lequel la lumière brille), sur
            // le SDF du rectangle arrondi. Le fond est OPAQUE sous le
            // colorEffect — jamais de `.clear`, le × color.a avale
            // tout.
            .colorEffect(lisere)
            .clipShape(forme)
            // Le voile d'arrivée : une extinction UNIFORME, pas une
            // teinte — la matière garde ses rapports internes.
            .brightness(-0.20 * Double(1 - min(max(allume, 0), 1)))
        }
        .allowsHitTesting(false)
    }

    /// L'appel du shader — l'ARITÉ d'abord : 7 `float2` + 1 `float`,
    /// comptés DEUX fois côté Metal et côté Swift (le piège payé : un
    /// écart d'un float = la page BLANCHE, sans une seule erreur).
    /// Les scalaires vivent ici en littéraux nommés par position :
    /// forme (rayon, Δ 10 dedans), ligne (σ 0,60, σ halo 3,4),
    /// souffle (amplitude 0,16, plancher bas 0,12), fondu (cos θ
    /// plein 0,35, fin −0,62), ombre (profondeur 0,46, τ 14).
    private func lisereShader(w: CGFloat, h: CGFloat) -> Shader {
        ShaderLibrary.corpsLisere(
            .float2(Float(w * 0.5), Float(h * 0.5)),
            .float2(Float(w * 0.5), Float(h * 0.5)),
            .float2(Float(rayon), 10.0),
            .float2(0.60, 3.4),
            .float2(0.16, 0.12),
            .float2(0.35, -0.62),
            .float2(0.46, 14.0),
            .float(1.0))
    }

    /// Le fond : UNE descente monotone, opaque (un `colorEffect`
    /// viendra vivre dessus au jalon du shader — jamais de `.clear`
    /// sous un colorEffect, le `× color.a` avale tout).
    private var nacreFond: some View {
        forme.fill(LinearGradient(
            stops: [
                .init(color: Self.hautC, location: 0.0),
                .init(color: Self.corpsC, location: 0.45),
                .init(color: Self.flancC, location: 0.80),
                .init(color: Self.piedC, location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom))
    }

    /// LE FOYER : le brillant du plastique — un reflet FROID et
    /// discret sous la lampe haut-gauche (le gloss d'un iPod, pas la
    /// chaleur d'une nacre), blend normal (en plusLighter il
    /// écrêterait au blanc pur sur un fond à L≈245).
    private func nacreFoyer(w: CGFloat, h: CGFloat) -> some View {
        Ellipse()
            .fill(RadialGradient(
                stops: [
                    .init(color: Self.foyerC.opacity(0.30), location: 0.0),
                    .init(color: Self.foyerC.opacity(0.12), location: 0.60),
                    .init(color: Self.foyerC.opacity(0.0), location: 1.0),
                ],
                center: .center, startRadius: 0, endRadius: w * 0.48))
            .frame(width: w * 0.95, height: 260)
            .position(x: w * 0.30, y: h * 0.10)
            .blur(radius: 16)
    }

    /// Le grain : 3-4 %, invisible en tant que tel — c'est lui qui
    /// sépare « matière » d'« aplat logiciel », et le casse-banding v1
    /// des grandes nappes claires OLED (anneaux de Mach).
    private var nacreGrain: some View {
        GrainTexture.tuile
            .resizable(resizingMode: .tile)
            .opacity(0.035)
            .blendMode(.overlay)
    }

}
