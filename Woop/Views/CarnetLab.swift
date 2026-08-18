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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CarnetPlaque(nom: Self.ouvert ? "carnet-ouvert"
                         : (Self.cote ? "carnet-ferme-cote" : "carnet-ferme"))
                .padding(.horizontal, Self.ouvert ? 8 : 48)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

/// Une plaque du carnet, chargée du bundle (Woop/Media, ressource nue —
/// le pattern des cartes-lune : par chemin, jamais par le catalogue).
struct CarnetPlaque: View {
    let nom: String

    var body: some View {
        if let chemin = Bundle.main.path(forResource: nom, ofType: "png"),
           let image = UIImage(contentsOfFile: chemin) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            // Une plaque manquante se VOIT : un carré rouge est un cri,
            // un écran noir est un mensonge.
            Color.red.frame(width: 80, height: 80)
        }
    }
}

#Preview { CarnetLab() }
