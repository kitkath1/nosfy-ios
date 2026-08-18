import SwiftUI

// MARK: - Banc du carnet de cuir (`-carnetLab`)

/// LE CARNET DE CUIR — le banc du chantier (ouvert le 2026-08-18) : la
/// collection d'entraînements de la home devient un carnet relié plein
/// cuir, embossé du croissant, tranche dorée. Fermé sur la home à la place
/// de la pile swap ; ouvert EN PLACE dans la section sur une double page
/// de sessions ; tap sur une page → la story (le portail de la maison).
///
/// La loi des pages, tranchée d'entrée par Kathryn : l'intérieur est
/// APPLE-STYLE NOIR MINIMAL — la grammaire des pochettes du bac à vinyles
/// (noir, grain, sheen d'angle, typo Inter, zéro bordure). Le cuir ne
/// franchit JAMAIS la reliure : il est la coque, pas le papier.
///
/// Ce premier tour ne montre que les PLAQUES forgées de référence
/// (~/Downloads/woop-carnet/refs, posées dans Woop/Media) : le fermé par
/// défaut, l'ouvert avec `-carnetOuvert`, le trois-quarts avec
/// `-carnetCote`. La matière vivante (relight, parallaxe de depth, fil
/// d'or qui respire) vient aux tours suivants.
///
/// Mesures des plaques (python, 18-08) : fermé — objet 773 × 1141 px dans
/// 1122 × 1402 (ratio 0,677), or de tranche RGB(184, 127, 35) sur le flanc
/// droit ; ouvert — objet 1155 × 882 px dans 1467 × 1072 (ratio 1,310).
struct CarnetLab: View {
    private static let ouvert = CommandLine.arguments.contains("-carnetOuvert")
    private static let cote = CommandLine.arguments.contains("-carnetCote")

    /// Les trois plaques, dans l'ordre du feuilletage au tap. Les flags
    /// restent la voie des captures (un banc se lance dans un état connu) ;
    /// le tap est la voie du doigt — `simctl launch` sur une app déjà
    /// ouverte ne relit PAS ses arguments, et jongler avec `terminate`
    /// n'est pas un geste de fouettage.
    private static let plaques = ["carnet-ferme", "carnet-ferme-cote",
                                  "carnet-ouvert"]

    @State private var index =
        Self.ouvert ? 2 : (Self.cote ? 1 : 0)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CarnetPlaque(nom: Self.plaques[index])
                .padding(.horizontal, index == 2 ? 6 : 40)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            index = (index + 1) % Self.plaques.count
        }
    }
}

/// Une plaque du carnet, chargée du bundle (Woop/Media, ressource nue —
/// le pattern des cartes-lune : par chemin, jamais par le catalogue) et
/// RECADRÉE sur l'objet : les plaques forgées portent de larges marges
/// noires, et « scaledToFit » sur la plaque entière rendait le carnet
/// petit dans son propre cadre (verdict 19-08 : « un peu plus gros »).
/// Les cadres viennent de la mesure python (seuil de luminance 8/255,
/// +12 px de respiration pour la lueur de tranche).
struct CarnetPlaque: View {
    let nom: String

    /// Le cadre utile de chaque plaque, en pixels de l'image source.
    private static let cadres: [String: CGRect] = [
        "carnet-ferme": CGRect(x: 166, y: 138, width: 797, height: 1165),
        "carnet-ferme-cote": CGRect(x: 246, y: 166, width: 665, height: 1175),
        "carnet-ouvert": CGRect(x: 142, y: 86, width: 1179, height: 906),
    ]

    var body: some View {
        if let image = Self.charge(nom) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            // Une plaque manquante se VOIT : un carré rouge est un cri,
            // un écran noir est un mensonge.
            Color.red.frame(width: 80, height: 80)
        }
    }

    private static func charge(_ nom: String) -> UIImage? {
        guard let chemin = Bundle.main.path(forResource: nom, ofType: "png"),
              let image = UIImage(contentsOfFile: chemin) else { return nil }
        guard let cadre = cadres[nom],
              let cg = image.cgImage?.cropping(to: cadre) else { return image }
        return UIImage(cgImage: cg)
    }
}

#Preview { CarnetLab() }
