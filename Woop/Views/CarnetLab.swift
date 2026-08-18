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
    private static let ouvertFlag = CommandLine.arguments.contains("-carnetOuvert")

    /// Le tap OUVRE et FERME le carnet (jalon 3) — plus un cycle d'images,
    /// un objet. `-carnetOuvert` démarre posé sur la double page (les
    /// captures ont besoin d'états connus ; `simctl launch` sur une app
    /// déjà ouverte ne relit pas ses arguments).
    @State private var ouvert = CarnetLab.ouvertFlag

    /// `-carnetP <p>` fige l'ouverture en plein vol (captures du jalon 3) —
    /// le simulateur n'a pas de doigt, le pattern `-lensFreeze`.
    private static let pFige: CGFloat? = {
        guard let raw = UserDefaults.standard.string(forKey: "carnetP"),
              let v = Double(raw) else { return nil }
        return CGFloat(v)
    }()

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
            ZStack {
                Color.black
                CarnetObjet(p: Self.pFige ?? (ouvert ? 1 : 0), tilt: tilt,
                            hauteur: hauteur)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            SwapFeedback.shared.tap()
            withAnimation(.carnetOuverture) { ouvert.toggle() }
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

/// LE LIVRE — un seul objet à deux états : `p` va de 0 (fermé) à 1
/// (ouvert en double page). L'ANATOMIE DE L'OUVERTURE : le dos voyage du
/// flanc gauche au centre pendant que la couverture pivote de 180° autour
/// de lui ; sous elle, la plaque ouverte n'expose que sa moitié droite
/// (le dos est SON centre : le masque ne bouge jamais dans son repère) ;
/// passé 90°, le verso de la couverture EST la page de gauche — la moitié
/// gauche de la plaque ouverte, étirée de 6 % au format de la couverture
/// (le débord mesuré au jalon 1) et PRÉ-MIROITÉE pour que le miroir de la
/// rotation la remette à l'endroit. La bascule du contenu se fait PILE à
/// 90°, quand la couverture est vue par la tranche (largeur projetée
/// nulle) : le raccord est invisible par construction. Et grâce à
/// l'invariant de hauteur payé au jalon 1, RIEN ne se remet à l'échelle.
///
/// `Animatable` sur p ET le tilt (paire imbriquée) : la courbe
/// d'ouverture et le ressort du retour jouent aussi dans les shaders (le
/// piège des rampes sous withAnimation, payé sur les fondus échelonnés).
struct CarnetObjet: View, Animatable {
    var p: CGFloat
    var tilt: CGSize = .zero
    let hauteur: CGFloat

    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(p, AnimatablePair(tilt.width, tilt.height)) }
        set {
            p = newValue.first
            tilt = CGSize(width: newValue.second.first,
                          height: newValue.second.second)
        }
    }

    var body: some View {
        let ferme = PlaqueCarnet.ferme
        let ouvert = PlaqueCarnet.ouvert
        let wF = hauteur * ferme.objetW / ferme.objetH
        let wS = hauteur * ouvert.objetW / ouvert.objetH
        let cadreF = ferme.largeurCadre(pourHauteurObjet: hauteur)
        let cadreO = ouvert.largeurCadre(pourHauteurObjet: hauteur)
        // Le voyage du dos : du flanc gauche du fermé (centre − wF/2)
        // jusqu'au centre de la double page.
        let course = wF / 2
        let theta = Double(p) * .pi

        ZStack {
            if p >= 1 {
                // Posé : la plaque ouverte entière, seule et vivante.
                VuePlaque(plaque: ouvert, tilt: tilt, detoure: true)
                    .frame(width: cadreO)
            } else {
                // Le corps du livre : la moitié droite de la plaque
                // ouverte, qui suit le dos. L'ombre de gouttière naît et
                // meurt avec le vol (sin πp) : posée, la plaque porte déjà
                // la sienne.
                VuePlaque(plaque: ouvert, tilt: tilt, detoure: true)
                    .frame(width: cadreO)
                    .mask { Rectangle().padding(.leading, cadreO / 2) }
                    .overlay(alignment: .leading) {
                        LinearGradient(
                            colors: [.black.opacity(0.55), .clear],
                            startPoint: .leading, endPoint: .trailing)
                            .frame(width: 54)
                            .padding(.leading, cadreO / 2)
                            .opacity(sin(Double(p) * .pi))
                            .allowsHitTesting(false)
                    }
                    .offset(x: -course * (1 - p))

                // La couverture qui pivote autour du dos. Avant 90° : le
                // fermé. Après : son verso, la page de gauche.
                Group {
                    if p <= 0.5 {
                        VuePlaque(plaque: ferme, tilt: tilt, detoure: true)
                            .frame(width: cadreF)
                    } else {
                        ZStack(alignment: .leading) {
                            VuePlaque(plaque: ouvert, tilt: tilt,
                                      detoure: true)
                                .frame(width: cadreO)
                                .scaleEffect(x: (cadreF * 2) / cadreO, y: 1,
                                             anchor: .leading)
                        }
                        .frame(width: cadreF, alignment: .leading)
                        .clipped()
                        // Le pré-miroir : la rotation à 180° remettra la
                        // page à l'endroit.
                        .scaleEffect(x: -1)
                    }
                }
                // Le clair-obscur du vol : la couverture s'assombrit vue
                // par la tranche, comme tout objet qui quitte la lumière.
                .overlay {
                    Color.black.opacity((1 - abs(cos(theta))) * 0.38)
                        .allowsHitTesting(false)
                }
                .rotation3DEffect(.degrees(-180 * Double(p)),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading, perspective: 0.5)
                .offset(x: course * p)
            }
        }
        .frame(width: wS)
        // L'inclinaison de l'objet entier : perspective courte, la
        // grammaire de la pile swap — c'est elle qui donne l'épaisseur.
        .rotation3DEffect(.degrees(Double(tilt.width) * 7),
                          axis: (x: 0, y: 1, z: 0), perspective: 0.62)
        .rotation3DEffect(.degrees(-Double(tilt.height) * 5),
                          axis: (x: 1, y: 0, z: 0), perspective: 0.62)
    }
}

/// La courbe de l'ouverture : franche au départ, posée à l'arrivée — une
/// couverture a du poids, elle ne rebondit pas (le papier claque, il ne
/// ressort pas).
extension Animation {
    static let carnetOuverture = Animation.timingCurve(
        0.30, 0, 0.22, 1, duration: 0.58)
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
/// Le tap OUVRE le carnet en place (jalon 3) : la couverture pivote, la
/// double page prend la section. Le second tap le referme. Les pages de
/// séances (jalon 4) viendront habiter la double page.
struct CarnetHome: View {
    /// La hauteur de couverture sur la home — l'étalon validé au banc
    /// (l'invariant : elle ne change pas à l'ouverture).
    static let hauteur: CGFloat = 248

    @State private var ouvert = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
            let g = SkyMotion.shared.tilt
            // Presque l'amplitude du doigt : à 0,55 l'effet passait sous
            // le seuil du regard (« je vois pas d'effet », verdict
            // téléphone 19-08) — un objet qui répond timidement répond
            // pas.
            let tilt = CGSize(width: g.dx * 0.90, height: g.dy * 0.65)
            CarnetObjet(p: ouvert ? 1 : 0, tilt: tilt,
                        hauteur: Self.hauteur)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            SwapFeedback.shared.tap()
            withAnimation(.carnetOuverture) { ouvert.toggle() }
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
