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

    /// L'inclinaison sous le doigt (±1 par axe). Au banc c'est le drag qui
    /// incline (le simulateur n'a pas de gyroscope) ; dans l'app ce sera
    /// SkyMotion. `-carnetTilt <tx,ty>` la fige pour les captures (le
    /// pattern `-luneTilt`).
    @State private var tilt: CGSize = CarnetLab.tiltFige ?? .zero

    private static let tiltFige: CGSize? = {
        guard let raw = UserDefaults.standard.string(forKey: "carnetTilt")
        else { return nil }
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return CGSize(width: parts[0], height: parts[1])
    }()

    var body: some View {
        GeometryReader { geo in
            let spread = geo.size.width - Self.margeOuvert * 2
            // L'invariant : la hauteur de l'objet, tirée du spread validé.
            let hauteur = spread * PlaqueCarnet.ouvert.objetH
                / PlaqueCarnet.ouvert.objetW
            let plaque = index == 1 ? PlaqueCarnet.ouvert : PlaqueCarnet.ferme
            ZStack {
                Color.black
                CarnetVivant(plaque: plaque,
                             largeur: plaque.largeurCadre(pourHauteurObjet: hauteur),
                             tilt: tilt)
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
        // Le drag incline, le tap feuillette : le tap ne bouge pas de
        // 6 pt, les deux gestes cohabitent sans se voler.
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in
                    guard Self.tiltFige == nil else { return }
                    tilt = CGSize(
                        width: max(-1, min(1, v.translation.width / 130)),
                        height: max(-1, min(1, v.translation.height / 130)))
                }
                .onEnded { _ in
                    guard Self.tiltFige == nil else { return }
                    withAnimation(.spring(response: 0.42,
                                          dampingFraction: 0.86)) {
                        tilt = .zero
                    }
                })
    }
}

/// Le carnet qui répond : l'inclinaison tourne l'OBJET (rotations 3D à
/// perspective courte — c'est elle qui donne l'épaisseur, la grammaire de
/// la pile swap) pendant que le shader garde la lumière fixe au monde.
/// `Animatable` sur le tilt : sans lui, le ressort du retour au repos
/// n'animerait que les transforms et le shader SAUTERAIT à zéro (le piège
/// des rampes sous withAnimation, payé sur les fondus échelonnés).
struct CarnetVivant: View, Animatable {
    let plaque: PlaqueCarnet
    var largeur: CGFloat
    var tilt: CGSize
    var detoure = false

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(tilt.width, tilt.height) }
        set { tilt = CGSize(width: newValue.first, height: newValue.second) }
    }

    var body: some View {
        VuePlaque(plaque: plaque, tilt: tilt, detoure: detoure)
            .frame(width: largeur)
            .rotation3DEffect(.degrees(Double(tilt.width) * 7),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.62)
            .rotation3DEffect(.degrees(-Double(tilt.height) * 5),
                              axis: (x: 1, y: 0, z: 0), perspective: 0.62)
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

    /// Les rayons de coin de l'objet, en pixels source — mesurés au
    /// gradient : le dos (gauche) est presque vif, la couverture (droite)
    /// s'arrondit. La sonde a aussi montré que la lueur de tranche vit
    /// ENTIÈREMENT à l'intérieur des arêtes dures (luminance 0 au-delà) :
    /// le détourage n'ampute aucune lumière.
    var rayonG: CGFloat = 0
    var rayonD: CGFloat = 0

    static let ferme = PlaqueCarnet(
        nom: "carnet-ferme",
        crop: CGRect(x: 170, y: 143, width: 783, height: 1089),
        objetW: 767, objetH: 1073,
        rayonG: 8, rayonD: 36)
    static let ouvert = PlaqueCarnet(
        nom: "carnet-ouvert",
        crop: CGRect(x: 146, y: 90, width: 1166, height: 881),
        objetW: 1150, objetH: 865,
        rayonG: 26, rayonD: 26)

    /// La largeur d'affichage du CADRE pour que l'OBJET ait cette hauteur
    /// à l'écran — c'est par elle que les deux états tiennent le même
    /// livre en main.
    func largeurCadre(pourHauteurObjet h: CGFloat) -> CGFloat {
        h * (objetW / objetH) * (crop.width / objetW)
    }
}

// MARK: - Le carnet de la home

/// LE CARNET FERMÉ DE LA HOME — il remplace la pile swap sous « Derniers
/// entraînements » (tranché 18-08 ; la pile vit toujours au design system,
/// banc `-deckLab`). Détouré aux arêtes dures, il est un objet DANS la
/// scène aurora : les étoiles vivent autour de lui, jamais derrière un
/// rectangle mort. Le gyroscope (SkyMotion, lissé) l'incline comme la main
/// du banc — au simulateur il reste droit, le capteur est muet.
///
/// L'ouverture est le jalon 3 : le tap ne fait pour l'instant qu'un
/// souffle haptique — le carnet accuse réception, il ne promet rien.
struct CarnetHome: View {
    /// La hauteur de couverture sur la home — l'étalon validé au banc
    /// (l'invariant : elle ne changera pas à l'ouverture).
    static let hauteur: CGFloat = 248

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            let g = SkyMotion.shared.tilt
            // Presque l'amplitude du doigt : à 0,55 l'effet passait sous
            // le seuil du regard (« je vois pas d'effet », verdict
            // téléphone 19-08) — un objet qui répond timidement répond
            // pas.
            let tilt = CGSize(width: g.dx * 0.90, height: g.dy * 0.65)
            CarnetVivant(
                plaque: .ferme,
                largeur: PlaqueCarnet.ferme
                    .largeurCadre(pourHauteurObjet: Self.hauteur),
                tilt: tilt, detoure: true)
        }
    }
}

/// L'hôte d'une plaque : chargée du bundle (Woop/Media, ressource nue —
/// le pattern des cartes-lune : par chemin, jamais par le catalogue),
/// découpée à son cadre, et VIVANTE — le shader `carnetCuirV1` fait
/// traverser un reflet dans le grain du cuir et respirer l'or de la
/// tranche (30 Hz, horloge mod 900 comme toute la maison).
struct VuePlaque: View {
    let plaque: PlaqueCarnet
    var tilt: CGSize = .zero
    /// Détouré aux arêtes dures : sur la home, le carnet est un OBJET posé
    /// dans la scène — sans détourage, le rectangle noir de la plaque
    /// éteindrait les étoiles autour de lui.
    var detoure = false

    var body: some View {
        if let image = Self.charge(plaque) {
            GeometryReader { geo in
                let s = geo.size.width / plaque.crop.width
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                    let t = Float(tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 900))
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .colorEffect(ShaderLibrary.carnetCuirV2(
                            .float2(geo.size.width, geo.size.height),
                            .float(t),
                            .float2(Float(tilt.width), Float(tilt.height))))
                        .mask {
                            if detoure {
                                // La silhouette mesurée : dos presque vif
                                // à gauche, couverture arrondie à droite,
                                // marges symétriques du cadre (8 px).
                                UnevenRoundedRectangle(
                                    topLeadingRadius: plaque.rayonG * s,
                                    bottomLeadingRadius: plaque.rayonG * s,
                                    bottomTrailingRadius: plaque.rayonD * s,
                                    topTrailingRadius: plaque.rayonD * s,
                                    style: .continuous)
                                    .padding(8 * s)
                            } else {
                                Rectangle()
                            }
                        }
                }
            }
            .aspectRatio(plaque.crop.width / plaque.crop.height,
                         contentMode: .fit)
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
