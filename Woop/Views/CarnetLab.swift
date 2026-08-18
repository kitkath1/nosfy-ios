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

    /// Les DEUX états du carnet — fermé face à soi, ouvert en double page.
    /// Le trois-quarts a été retiré du cycle (verdict 19-08 : « une étape
    /// en trop ») : c'était une plaque de référence pour la forge, pas un
    /// état de l'expérience ; elle vit dans ~/Downloads/woop-carnet/refs.
    /// Les flags restent la voie des captures (un banc se lance dans un
    /// état connu) ; le tap est la voie du doigt — `simctl launch` sur une
    /// app déjà ouverte ne relit PAS ses arguments.
    private static let plaques = ["carnet-ferme", "carnet-ouvert"]

    @State private var index = Self.ouvert ? 1 : 0

    /// LA seule molette de taille : la marge latérale de la DOUBLE PAGE.
    /// Tout le reste s'en déduit par l'INVARIANT PHYSIQUE — la hauteur de
    /// la couverture, identique fermé/ouvert (verdicts 19-08 : « pas la
    /// même taille, ça devrait pour l'animation », puis « c'est fake,
    /// refais l'analyse »). La sonde mesure_plaques.py (arêtes dures au
    /// gradient, jamais un seuil de luminance : il attrape le reflet au
    /// sol du fermé et la lueur de tranche de l'ouvert, et les échelles
    /// divergent) a montré que les deux plaques sont deux RENDUS
    /// indépendants : hauteur ouvert/fermé 0,806, spread/fermé 1,50.
    /// À hauteur de couverture égale, le spread mesuré fait 1,86× la
    /// largeur du fermé — la courbure des pages mange le reste des 2×.
    private static let margeOuvert: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            let spread = geo.size.width - Self.margeOuvert * 2
            // L'invariant : la hauteur de l'objet, tirée du spread validé.
            let hauteur = spread * PlaqueCarnet.ouvert.objetH
                / PlaqueCarnet.ouvert.objetW
            let plaque = index == 1 ? PlaqueCarnet.ouvert : PlaqueCarnet.ferme
            ZStack {
                Color.black
                VuePlaque(plaque: plaque)
                    .frame(width: plaque.largeurCadre(pourHauteurObjet: hauteur))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            index = (index + 1) % Self.plaques.count
        }
    }
}

/// Une plaque MESURÉE : le cadre utile découpé dans l'image source, et les
/// dimensions de l'objet aux arêtes DURES dedans. Les marges du cadre sont
/// SYMÉTRIQUES (8 px de chaque côté) : le centre du cadre EST le centre de
/// l'objet — une marge inégale décentre le carnet et l'œil le voit.
/// Mesures : ~/Downloads/woop-carnet/sondes/mesure_plaques.py.
struct PlaqueCarnet {
    let nom: String
    /// Le cadre découpé dans la plaque source, en pixels.
    let crop: CGRect
    /// L'objet aux arêtes dures, en pixels (centré dans le cadre).
    let objetW: CGFloat
    let objetH: CGFloat

    static let ferme = PlaqueCarnet(
        nom: "carnet-ferme",
        crop: CGRect(x: 170, y: 143, width: 783, height: 1089),
        objetW: 767, objetH: 1073)
    static let ouvert = PlaqueCarnet(
        nom: "carnet-ouvert",
        crop: CGRect(x: 146, y: 90, width: 1166, height: 881),
        objetW: 1150, objetH: 865)

    /// La largeur d'affichage du CADRE pour que l'OBJET ait cette hauteur
    /// à l'écran — c'est par elle que les deux états tiennent le même
    /// livre en main.
    func largeurCadre(pourHauteurObjet h: CGFloat) -> CGFloat {
        h * (objetW / objetH) * (crop.width / objetW)
    }
}

/// L'hôte d'une plaque : chargée du bundle (Woop/Media, ressource nue —
/// le pattern des cartes-lune : par chemin, jamais par le catalogue),
/// découpée à son cadre.
struct VuePlaque: View {
    let plaque: PlaqueCarnet

    var body: some View {
        if let image = Self.charge(plaque) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            // Une plaque manquante se VOIT : un carré rouge est un cri,
            // un écran noir est un mensonge.
            Color.red.frame(width: 80, height: 80)
        }
    }

    private static func charge(_ plaque: PlaqueCarnet) -> UIImage? {
        guard let chemin = Bundle.main.path(forResource: plaque.nom,
                                            ofType: "png"),
              let image = UIImage(contentsOfFile: chemin) else { return nil }
        guard let cg = image.cgImage?.cropping(to: plaque.crop) else {
            return image
        }
        return UIImage(cgImage: cg)
    }
}

#Preview { CarnetLab() }
