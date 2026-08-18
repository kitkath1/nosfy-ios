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

    /// `-carnetFeuille` : le banc du MOTEUR DE TOURNE (tournePageV1) — la
    /// double page posée, une page mock premium dans la fenêtre droite,
    /// le drag horizontal l'enroule. `-carnetQ <q>` fige la tourne.
    private static let feuilleLab = CommandLine.arguments
        .contains("-carnetFeuille")
    private static let qFige: CGFloat? = {
        guard let raw = UserDefaults.standard.string(forKey: "carnetQ"),
              let v = Double(raw) else { return nil }
        return CGFloat(v)
    }()
    /// La tourne en cours au banc feuille.
    @State private var q: CGFloat = CarnetLab.qFige ?? 0

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
                if Self.feuilleLab {
                    bancFeuille(spread: spread, hauteur: hauteur)
                } else {
                    CarnetObjet(p: Self.pFige ?? (ouvert ? 1 : 0),
                                tilt: tilt, hauteur: hauteur)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !Self.feuilleLab else { return }
            SwapFeedback.shared.tap()
            withAnimation(.carnetOuverture) { ouvert.toggle() }
        }
        // Le drag incline (banc objet) ou tourne la page (banc feuille) ;
        // le tap ne bouge pas de 6 pt, les deux gestes cohabitent.
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { v in
                    if Self.feuilleLab {
                        guard Self.qFige == nil else { return }
                        q = max(0, min(1, -v.translation.width / 240))
                    } else {
                        guard Self.tiltFige == nil else { return }
                        tilt = CGSize(
                            width: max(-1, min(1, v.translation.width / 130)),
                            height: max(-1, min(1, v.translation.height / 130)))
                    }
                }
                .onEnded { v in
                    if Self.feuilleLab {
                        guard Self.qFige == nil else { return }
                        // L'aimant : la tourne finit toujours posée — sur
                        // l'élan prédit, jamais sur la position seule.
                        let fin = -v.predictedEndTranslation.width / 240
                        withAnimation(.spring(response: 0.5,
                                              dampingFraction: 0.86)) {
                            q = fin > 0.5 ? 1 : 0
                        }
                    } else {
                        guard Self.tiltFige == nil else { return }
                        withAnimation(.spring(response: 0.42,
                                              dampingFraction: 0.86)) {
                            tilt = .zero
                        }
                    }
                })
    }

    /// Le banc du moteur : la double page posée, la session suivante nue
    /// sur le papier de la plaque (c'est elle que la tourne révèle), la
    /// page courante en vol par-dessus.
    @ViewBuilder
    private func bancFeuille(spread: CGFloat, hauteur: CGFloat) -> some View {
        let fen = FenetrePage.droite(hauteur: hauteur)
        ZStack {
            VuePlaque(plaque: .ouvert, detoure: true)
                .frame(width: PlaqueCarnet.ouvert
                    .largeurCadre(pourHauteurObjet: hauteur))
            PageSession(date: "16. Août", mesures: "4 séries · 48 reps",
                        sticker: "sticker-bras", pieces: 80)
                .frame(width: fen.width, height: fen.height)
                .offset(x: fen.midX, y: fen.midY)
            PageEnVol(q: q, fenetre: fen)
        }
    }
}

/// LA FENÊTRE PAPIER — le rectangle réel du papier dans la plaque ouverte,
/// MESURÉ par la sonde mesure_fenetres.py (arêtes au gradient, coins par
/// cercles ajustés) : jamais des insets devinés — c'est l'inset deviné qui
/// faisait la page-widget posée sur le livre. Coordonnées depuis le CENTRE
/// de l'objet, pour une hauteur d'objet étalon de 248 pt.
struct FenetrePage {
    /// La page droite : papier x [+1,40 … +151,53], y [−123,29 … +123,52],
    /// gouttière à +1,40 du centre, coins extérieurs ~10 / 8,9 pt.
    static func droite(hauteur h: CGFloat) -> CGRect {
        let k = h / 248.0
        return CGRect(x: 1.40 * k, y: -123.29 * k,
                      width: 150.14 * k, height: 246.81 * k)
    }
}

/// La page en vol : un layer à DEUX faces — moitié droite le recto (papier
/// synthétique raccordé à la plaque + contenu), moitié gauche le VERSO nu
/// pré-composé à sa position d'atterrissage — remappé par `tournePageV2`.
/// Les zones désertées sortent en ombre-alpha ou transparentes : la page
/// de dessous apparaît toute seule. `Animatable` sur q — le ressort de
/// l'aimant joue dans le shader.
struct PageEnVol: View, Animatable {
    var q: CGFloat
    let fenetre: CGRect
    var contenu = PageSession()

    var animatableData: CGFloat {
        get { q } set { q = newValue }
    }

    var body: some View {
        HStack(spacing: 0) {
            PapierPage(gouttiereADroite: true)
                .frame(width: fenetre.width)
            ZStack {
                PapierPage(gouttiereADroite: false)
                contenu
            }
            .frame(width: fenetre.width)
        }
        .frame(width: fenetre.width * 2, height: fenetre.height)
        .compositingGroup()
        .layerEffect(ShaderLibrary.tournePageV2(
            .float2(fenetre.width * 2, fenetre.height),
            .float(Float(q))),
            maxSampleOffset: CGSize(width: fenetre.width * 2, height: 0))
        .allowsHitTesting(false)
        // Le centre du layer EST la gouttière : la feuille est épinglée là.
        .offset(x: fenetre.minX, y: fenetre.midY)
    }
}

/// LE PAPIER SYNTHÉTIQUE de la feuille en vol — calé sur les MESURES du
/// papier de la plaque (neutre, L 40→24/255 vertical, puits de gouttière
/// ~22 pt, grain 0,05) : le raccord posé ↔ vol se joue à moins de 2/255,
/// sinon on voit le swap au départ de la tourne. Coins mesurés 10/8,9 pt
/// côté tranche, vifs côté reliure.
struct PapierPage: View {
    /// Le verso posé porte sa reliure à DROITE (il a été retourné).
    var gouttiereADroite = false

    var body: some View {
        let forme = UnevenRoundedRectangle(
            topLeadingRadius: gouttiereADroite ? 10 : 0,
            bottomLeadingRadius: gouttiereADroite ? 9 : 0,
            bottomTrailingRadius: gouttiereADroite ? 0 : 9,
            topTrailingRadius: gouttiereADroite ? 0 : 10,
            style: .continuous)
        ZStack {
            LinearGradient(colors: [Color(white: 0.157),
                                    Color(white: 0.094)],
                           startPoint: .top, endPoint: .bottom)
            GrainTexture.tuile
                .resizable(resizingMode: .tile)
                .opacity(0.05)
                .blendMode(.overlay)
        }
        .overlay(alignment: gouttiereADroite ? .trailing : .leading) {
            LinearGradient(
                colors: gouttiereADroite
                    ? [.clear, .black.opacity(0.50)]
                    : [.black.opacity(0.50), .clear],
                startPoint: .leading, endPoint: .trailing)
                .frame(width: 22)
        }
        .clipShape(forme)
    }
}

/// LA PAGE DE SESSION — le contenu NU posé sur le papier (la partition du
/// 19-08) : AUCUN fond, aucun coin, aucune bordure — le papier de la
/// plaque EST le sol, la hiérarchie vit par la lumière (la loi du bac à
/// vinyles). La date est le titre ET le folio ; le sticker vit en BAS,
/// artwork, jamais mascotte centrée ; l'or reste l'or.
struct PageSession: View {
    var date = "18. Août"
    var mesures = "5 séries · 60 reps"
    var sticker = "sticker-flamme"
    var pieces = 100

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(date)
                .font(.inter(16, .semibold))
                .tracking(0.2)
                .foregroundStyle(Color.inkPrimary)
            Text(mesures)
                .font(.inter(11))
                .foregroundStyle(Color.inkMuted)
                .padding(.top, 3)

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 0) {
                Image(sticker)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    // La seule licence matière : l'ombre de contact — le
                    // papier est à 32/255, pas à 0 : elle « colle »
                    // l'autocollant. Pas plus fort, sinon cartoon.
                    .shadow(color: .black.opacity(0.35), radius: 2.5, y: 1)
                Spacer(minLength: 6)
                // Un chiffre ne se plie JAMAIS (payé : « +100 » wrappé en
                // colonne — la rangée dépassait la fenêtre de 20 pt).
                HStack(spacing: 4) {
                    Text("+\(pieces)")
                        .font(.inter(12.5, .semibold))
                        .foregroundStyle(Color.woopGold)
                        .lineLimit(1)
                        .fixedSize()
                    Image("piece-woop")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                }
            }
        }
        // La reliure est à GAUCHE : le texte sort de la pénombre de
        // gouttière (leading 24) et respire moins côté tranche (16).
        .padding(EdgeInsets(top: 22, leading: 24, bottom: 20, trailing: 16))
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

                // LES FEUILLES — un carnet ne s'ouvre pas d'un bloc
                // (« et pour les feuilles ?? », verdict 19-08) : trois
                // pages libres suivent la couverture en cascade, chacune
                // avec son retard, et se posent sous la page de gauche.
                // À la pose elles ont toutes disparu dessous.
                ForEach([3, 2, 1], id: \.self) { i in
                    let retard = 0.09 * CGFloat(i)
                    let q = max(0, min(1, (p - retard) / (1 - retard)))
                    let wFeuille = cadreO / 2 - 4 * CGFloat(i)
                    // Le papier PLOIE en plein vol (sin πq) et se tend aux
                    // poses ; chaque feuille un peu plus que la précédente.
                    let flexion = CGFloat(sin(Double(q) * .pi))
                        * (9 + 3 * CGFloat(i))
                    FeuilleLibre(teinte: 0.052 - 0.009 * Double(i),
                                 bow: flexion)
                        .frame(width: wFeuille,
                               height: hauteur - 8 - 3 * CGFloat(i))
                        .overlay {
                            Color.black.opacity(
                                (1 - abs(cos(Double(q) * .pi))) * 0.30)
                                .allowsHitTesting(false)
                        }
                        .rotation3DEffect(.degrees(-180 * Double(q)),
                                          axis: (x: 0, y: 1, z: 0),
                                          anchor: .leading,
                                          perspective: 0.5)
                        .offset(x: wFeuille / 2 - course * (1 - p))
                }

                // La couverture qui pivote autour du dos. Avant 90° : le
                // fermé. Après : son verso — la page de gauche à
                // l'ÉCHELLE VRAIE de la plaque ouverte. Le « resize des
                // côtés » à la pose (verdict 19-08) venait d'un verso
                // étiré au format couverture : la FENÊTRE du panneau fond
                // plutôt de la largeur couverture à la largeur page entre
                // 90° et 180° — 6 % avalés en plein vol, invisibles — et
                // à 180° le panneau EST la moitié gauche de la plaque :
                // la bascule finale ne bouge plus un pixel.
                let fenetre = p <= 0.5 ? cadreF
                    : cadreF + (cadreO / 2 - cadreF)
                        * min(1, (p - 0.5) / 0.42)
                Group {
                    if p <= 0.5 {
                        VuePlaque(plaque: ferme, tilt: tilt, detoure: true)
                            .frame(width: cadreF)
                    } else {
                        // Le pré-miroir du CONTENU (la rotation à 180° le
                        // remettra à l'endroit), gouttière calée sur la
                        // charnière.
                        VuePlaque(plaque: ouvert, tilt: tilt, detoure: true)
                            .frame(width: cadreO)
                            .scaleEffect(x: -1)
                            .offset(x: -cadreO / 2)
                    }
                }
                .frame(width: fenetre, alignment: .leading)
                .clipped()
                // Le clair-obscur du vol : la couverture s'assombrit vue
                // par la tranche, comme tout objet qui quitte la lumière.
                .overlay {
                    Color.black.opacity((1 - abs(cos(theta))) * 0.38)
                        .allowsHitTesting(false)
                }
                .rotation3DEffect(.degrees(-180 * Double(p)),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading, perspective: 0.5)
                .offset(x: fenetre / 2 - course * (1 - p))
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

/// Une page libre du carnet : papier noir SOUPLE — son bord libre PLOIE
/// en vol (la couverture est rigide, le papier ne l'est pas : c'est ce
/// contraste qui fait le vivant, un rectangle raide qui tourne fait une
/// carte à jouer). La tranche suit la courbure, en cheveu de braise.
struct FeuilleLibre: View {
    var teinte: Double
    /// La flexion du bord libre, en points (0 = feuille posée).
    var bow: CGFloat = 0

    var body: some View {
        FormeFeuille(bow: bow)
            .fill(LinearGradient(
                colors: [Color(white: teinte + 0.014),
                         Color(white: teinte)],
                startPoint: .top, endPoint: .bottom))
            .overlay {
                FormeFeuille(bow: bow)
                    .stroke(Color.white.opacity(0.045), lineWidth: 0.7)
            }
            .overlay {
                TrancheFeuille(bow: bow)
                    .stroke(Color(red: 1.0, green: 0.62, blue: 0.25)
                        .opacity(0.28), lineWidth: 0.8)
            }
    }
}

/// La silhouette d'une feuille qui ploie : le bord libre (droit) est une
/// courbe tirée vers la reliure, les autres bords restent tenus.
struct FormeFeuille: Shape {
    var bow: CGFloat
    var animatableData: CGFloat {
        get { bow } set { bow = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let c: CGFloat = 7
        p.move(to: CGPoint(x: r.minX, y: r.minY + 2))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY),
                       control: CGPoint(x: r.maxX - c - bow, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - 2))
        p.closeSubpath()
        return p
    }
}

/// Le bord libre seul — pour que la tranche de braise suive la flexion.
struct TrancheFeuille: Shape {
    var bow: CGFloat
    var animatableData: CGFloat {
        get { bow } set { bow = newValue }
    }

    func path(in r: CGRect) -> Path {
        var p = Path()
        let c: CGFloat = 7
        p.move(to: CGPoint(x: r.maxX - c, y: r.minY + 4))
        p.addQuadCurve(to: CGPoint(x: r.maxX - c, y: r.maxY - 4),
                       control: CGPoint(x: r.maxX - c - bow, y: r.midY))
        return p
    }
}

/// La courbe de l'ouverture : un ressort discret — la couverture se POSE
/// (léger amorti, jamais de rebond : le papier claque, il ne ressort
/// pas), et le retard en cascade des feuilles fait le reste du naturel.
extension Animation {
    static let carnetOuverture = Animation.spring(
        response: 0.60, dampingFraction: 0.88)
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

    /// LE CACHE — la cause du « pas assez fluide » (verdict 19-08) :
    /// `UIImage(contentsOfFile:)` ne cache RIEN, et le body d'une vue
    /// Animatable tourne à chaque image — le PNG de 1,3 Mo se redécodait
    /// 60 fois par seconde en plein vol. La plaque se décode UNE fois,
    /// recadrée et pré-réduite en miniature (~2× l'affichage — la leçon
    /// des dos du booster : les sources font 4× la résolution utile).
    private static var cache: [String: UIImage] = [:]

    private static func charge(_ plaque: PlaqueCarnet) -> UIImage? {
        if let faite = cache[plaque.nom] { return faite }
        guard let chemin = Bundle.main.path(forResource: plaque.nom,
                                            ofType: "png"),
              let brute = UIImage(contentsOfFile: chemin),
              let cg = brute.cgImage?.cropping(to: plaque.crop)
        else { return nil }
        let cible: CGFloat = 900
        let k = min(1, cible / plaque.crop.height)
        let taille = CGSize(width: (plaque.crop.width * k).rounded(),
                            height: (plaque.crop.height * k).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let mini = UIGraphicsImageRenderer(size: taille, format: format)
            .image { _ in
                UIImage(cgImage: cg).draw(in: CGRect(origin: .zero,
                                                     size: taille))
            }
        cache[plaque.nom] = mini
        return mini
    }
}

#Preview { CarnetLab() }
