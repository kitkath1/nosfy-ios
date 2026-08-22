import SwiftUI

// MARK: - Le sheet de saisie

/// ENREGISTRER LA SÉRIE, SANS QUITTER LE CADRAN. Le sheet occupe la moitié
/// basse ; le cadran reste derrière, flouté et assombri. Rien n'a été quitté,
/// rien n'a été poussé : c'est le même écran, avec une feuille dessus.
///
/// Le verre est le NATIF (`glassEffect`), comme les chips du header et la card
/// des séries — il a quelque chose à réfracter ici : la photo et le halo sur
/// la fiche, le cadran et ses auréoles sur le chrono.
struct SetEntrySheet: View {
    /// Le numéro de la série en cours (pour le titre).
    var rank: Int = 1
    /// Les valeurs de départ — celles de la série précédente.
    @Binding var reps: Int
    @Binding var kilos: Double
    /// Le repos choisi, en secondes. `nil` = pas encore choisi, et c'est LUI
    /// qui fait refuser le slide : sans repos, il n'y a rien à lancer.
    @Binding var rest: Int?
    /// Tirer la feuille vers le bas la range — notre panneau n'a plus de
    /// système pour le faire à sa place.
    var onDismiss: () -> Void = {}
    var onConfirm: () -> Void

    /// Les repos proposés. Six valeurs, toutes visibles d'un coup : une liste
    /// qu'il faut dérouler pour choisir entre 30 s et 1 min est une liste de
    /// trop.
    static let restChoices: [Int] = [30, 45, 60, 90, 120, 180]

    /// LE MOOD DU SLIDER, 0 → 1 : écrit par le galet (saisie × course), lu
    /// par la feuille — le fond S'EMBRASE pendant que le doigt avance :
    /// blanc chaud, jaune, orange, rouge. La palette de la maison — jamais
    /// de violet ici (verdict de Kathryn). Fonction pure du doigt :
    /// dé-draguer la fait redescendre d'elle-même, rien à annuler.
    @State private var mood: CGFloat = 0
    /// Le drag de rangement (sur la zone du header seulement : les molettes
    /// possèdent leurs propres glissements).
    @State private var pull: CGFloat = 0
    /// Le compteur de refus — chaque incrément fait TREMBLER les pastilles
    /// repos en rouge : le slide qui refuse montre POURQUOI.
    @State private var restNudge = 0

    /// La secousse : l'offset et le rouge voyagent ensemble.
    private struct ChipNudge {
        var x: CGFloat = 0
        var red: Double = 0
    }

    /// La silhouette du panneau : coins hauts seuls — le bas appartient à
    /// l'écran, et un rim de verre au ras du bord physique est une faute
    /// déjà payée (le CADRE FANTÔME).
    private static let shape = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 34, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 34),
        style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            // TOUT TIENT SANS DÉFILER, et ce n'est pas un confort : le repos
            // est le SEUL champ obligatoire, et un champ obligatoire qu'il
            // faut aller chercher sous la ligne de flottaison est un champ
            // qu'on oublie — le slide refuserait sans que rien n'explique
            // pourquoi. Trois blocs, une moitié d'écran, aucun défilement.
            VStack(spacing: 0) {
                header
                // 20 d'interligne (et non 14) : « repos est trop collé »
                // (verdict Kathryn) — les trois blocs respirent.
                VStack(spacing: 20) {
                    FluidPicker(title: "REPS", unit: "reps",
                                value: repsBinding, range: 1...50, step: 1)
                    FluidPicker(title: "WEIGHT", unit: "kg",
                                value: $kilos, range: 4...100, step: 1)
                    restRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }
            Spacer(minLength: 0)

            // LE SLIDER DE LA HOME (22-08, « mets celui de la home pour
            // consistance »). Le médaillon braise de `GaletSlide` est
            // ARCHIVÉ : deux sliders de validation dans la même app, c'est
            // deux grammaires du même geste, et celle de la home est
            // désormais la seule.
            //
            // Le passage est un remplacement PUR : `SliderObsidienne`
            // expose exactement les quatre mêmes propriétés — label,
            // validate, onMood, onConfirm. Aucun adaptateur, aucune
            // reprise de flow.
            //   — le VETO survit : `validate` à false ⇒ grenat + deux coups
            //     secs, et les pastilles de repos tremblent toujours ;
            //   — l'EMBRASEMENT survit : `onMood` nourrit la même nappe de
            //     feu du panneau. Mieux, la rampe de braise du slider EST
            //     `SetEntrySheet.fire` (c'est écrit dans son en-tête) : les
            //     deux étaient déjà la même famille de couleur.
            // Hauteur 62 — celle de la home, à la lettre (elle était 70).
            SliderObsidienne(label: "Slide to start rest",
                             height: 62,
                             validate: {
                                 // Le refus MONTRE sa raison : sans repos
                                 // choisi, les pastilles tremblent en rouge.
                                 if rest == nil { restNudge += 1 }
                                 return rest != nil
                             },
                             onConfirm: onConfirm,
                             onMood: { m in mood = m })
                // 20 : la pilule s'ALIGNE sur la grille des molettes et des
                // chips (verdict jury) — l'air du médaillon est garanti par
                // l'emboîtement, plus par la marge.
                .padding(.horizontal, 20)
                .padding(.bottom, 38)
                // 40 ET NON 18 (« trop collé », verdict Kathryn) : la marge
                // se mesure depuis la PILULE, mais l'œil, lui, mesure depuis
                // l'ANNEAU du médaillon — il monte 7 pt au-dessus d'elle et
                // son halo une dizaine encore. À 18, il ne restait que ~5 pt
                // d'air sous les pastilles. Le panneau grandit d'autant
                // (0,62 → 0,67 dans LiquidLensLab) : sans ça la colonne
                // déborde et la VStack reprend l'air qu'on vient de donner.
                .padding(.top, 40)
        }
        // LE VERRE EST LE VRAI — dans l'arbre du cadran, il échantillonne
        // l'auréole et les chiffres POUR DE VRAI. Le sheet système est mort :
        // sa présentation reculait toute la fenêtre (le cadre gris mesuré
        // autour de l'écran), et un verre dans sa couche n'avait rien à
        // réfracter. Ici, c'est le même verre que les chips du header sur la
        // braise — la maison n'en connaît qu'un.
        .background {
            ZStack {
                Color.clear.glassEffect(
                    .regular.tint(Color.black.opacity(0.30)),
                    in: Self.shape)
                // L'EMBRASEMENT — le fond suit le doigt : une nappe qui
                // monte du slider et traverse la palette de la maison,
                // blanc chaud → jaune → orange → rouge, avec la course.
                // Elle vit SUR le verre et SOUS le contenu : la couleur
                // baigne la feuille sans jamais teinter les chiffres.
                Self.shape
                    .fill(LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Self.fire(mood)
                                .opacity(0.10 * Double(mood)),
                                  location: 0.55),
                            .init(color: Self.fire(mood)
                                .opacity(0.34 * Double(mood)),
                                  location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
            }
        }
        // Le fil du bord : SEULEMENT là où la feuille se détache de la page.
        // Un liseré qui suivrait les flancs jusqu'au bas d'écran est
        // exactement la faute qu'on vient de tuer.
        .overlay {
            Self.shape
                .strokeBorder(LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.16), location: 0),
                        .init(color: Color.white.opacity(0.03), location: 0.18),
                        .init(color: .clear, location: 0.45)
                    ],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
        }
        // La poignée est à NOUS désormais — le système n'en pose plus.
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
        .offset(y: pull)
        // LE RANGEMENT : tirer la feuille depuis son header. Les molettes et
        // le galet gardent leurs gestes — le drag de rangement ne vit que
        // sur la zone haute.
        .gesture(dismissDrag)
    }

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .local)
            .onChanged { v in
                guard v.startLocation.y < 110 else { return }
                pull = max(0, v.translation.height)
            }
            .onEnded { v in
                guard v.startLocation.y < 110 else { return }
                if pull > 90 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.82)) { pull = 0 }
                }
            }
    }

    /// `reps` est un `Int` mais la molette travaille en `Double` : une molette
    /// qui saute d'entier en entier n'est pas fluide, elle CLIQUE. Elle glisse
    /// donc en continu et n'arrondit qu'à la lecture.
    private var repsBinding: Binding<Double> {
        Binding(get: { Double(reps) }, set: { reps = Int($0.rounded()) })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Set \(rank)")
                .font(.inter(20, .semibold))
                .foregroundStyle(Color.inkPrimary)
            Text("Log your set before starting the rest.")
                .font(.inter(12.5))
                .foregroundStyle(Color.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        // 34 ET NON 20 : `presentationDragIndicator` ne RÉSERVE rien, elle se
        // dessine par-dessus le contenu. À 20, la poignée tombait exactement
        // sur la ligne du titre.
        .padding(.top, 34)
    }

    // MARK: Le repos

    private var restRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("REST")
                    .font(.inter(9.5, .medium))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.42))
                // La seule information manquante possible : on la désigne
                // en ROUGE, plutôt que d'attendre que le slide la reproche.
                if rest == nil {
                    Text("required")
                        .font(.inter(9.5, .medium))
                        .tracking(0.4)
                        .foregroundStyle(Color(red: 1.0, green: 0.40, blue: 0.30)
                            .opacity(0.9))
                }
            }
            HStack(spacing: 7) {
                ForEach(Self.restChoices, id: \.self) { s in
                    restChip(s)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // LE REFUS SE MONTRE ICI : le slide bute → les pastilles tremblent
        // (±8 pt, 0,4 s) dans une lueur rouge qui s'éteint — on comprend
        // d'un coup d'œil pourquoi le drag n'a pas marché.
        .keyframeAnimator(initialValue: ChipNudge(),
                          trigger: restNudge) { view, v in
            view.offset(x: v.x)
                .shadow(color: Color(red: 1.0, green: 0.25, blue: 0.18)
                    .opacity(v.red * 0.65), radius: 9)
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                CubicKeyframe(-8, duration: 0.06)
                CubicKeyframe(7, duration: 0.07)
                CubicKeyframe(-4, duration: 0.07)
                CubicKeyframe(2, duration: 0.07)
                CubicKeyframe(0, duration: 0.09)
            }
            KeyframeTrack(\.red) {
                LinearKeyframe(1.0, duration: 0.08)
                LinearKeyframe(0.75, duration: 0.20)
                LinearKeyframe(0.0, duration: 0.42)
            }
        }
    }

    private func restChip(_ seconds: Int) -> some View {
        let on = rest == seconds
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                rest = seconds
            }
        } label: {
            // LA SÉLECTION SE DIT PAR LA LUMIÈRE, PAS PAR LE REMPLISSAGE.
            // C'est la loi de la maison — la pastille de la barre, le tube des
            // cards, l'anneau du galet : rien n'est jamais « rempli » pour
            // dire qu'il est choisi, tout s'ALLUME. Le chip doré plein était
            // l'exception. Sélectionné, le chip devient donc le plus NOIR de
            // la feuille, et son chiffre le plus blanc.
            Text(Self.restLabel(seconds))
                .font(.inter(12.5, on ? .semibold : .regular))
                .foregroundStyle(on ? FlammePalette.blanc
                                    : Color.white.opacity(0.58))
                .shadow(color: on ? FlammePalette.blanc.opacity(0.40)
                                  : .clear, radius: on ? 6 : 0)
                .shadow(color: on ? Color.white.opacity(0.30) : .clear,
                        radius: on ? 2 : 0)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if on {
                        // LE MÉDAILLON DU PLAYER, EN PASTILLE (verdict
                        // Kathryn : « le même liseré blanc joli et l'ombre
                        // que les boutons play et pause »). Le disque laqué
                        // devient une capsule laquée, les crans du liseré
                        // sont les MÊMES valeurs (LisereMedaillon), et la
                        // bague blanche du nord-ouest déborde dehors : c'est
                        // elle qui décolle la pièce de la feuille.
                        //
                        // JAMAIS de plusLighter ici : dans la couche du
                        // verre du panneau, un blend mode fait apparaître le
                        // CALQUE — un rectangle clair aux bords de son hôte
                        // (payé sur la scène du slider, juste dessous). Sur
                        // une laque quasi noire, le simple par-dessus rend
                        // la même lumière.
                        Capsule(style: .continuous)
                            .fill(RadialGradient(
                                colors: [Color(white: 0.105),
                                         Color(white: 0.035)],
                                center: UnitPoint(x: 0.30, y: 0.24),
                                startRadius: 2, endRadius: 46))
                            // Le halo chaud en sourdine — l'ambiance du
                            // médaillon, celle qui empêche le noir d'être
                            // un trou.
                            .overlay {
                                Capsule(style: .continuous)
                                    .fill(RadialGradient(
                                        stops: [
                                            .init(color: FlammePalette.flamme
                                                .opacity(0.07), location: 0),
                                            .init(color: FlammePalette.or
                                                .opacity(0.02), location: 0.55),
                                            .init(color: .clear, location: 1),
                                        ], center: .center,
                                        startRadius: 0, endRadius: 30))
                            }
                            // Le liseré premium, aux crans du médaillon.
                            .overlay {
                                Capsule(style: .continuous)
                                    .stroke(AngularGradient(
                                        stops: LisereMedaillon.crans,
                                        center: .center, angle: .zero),
                                        lineWidth: 0.8)
                            }
                            // La bague : tracée DEHORS du bord, floutée.
                            .overlay {
                                Capsule(style: .continuous)
                                    .inset(by: -1.25)
                                    .stroke(AngularGradient(
                                        stops: LisereMedaillon.bague,
                                        center: .center, angle: .zero),
                                        lineWidth: 2.4)
                                    .blur(radius: 1.0)
                                    .opacity(0.85)
                            }
                    } else {
                        Color.clear.glassEffect(
                            .regular.tint(Color.black.opacity(0.24)),
                            in: Capsule(style: .continuous))
                            .overlay {
                                // TANT QU'AUCUN REPOS N'EST CHOISI, les
                                // pastilles VIVENT en rouge : un liseré
                                // grenat qui pulse doucement — l'invitation
                                // permanente, avant même que le slide ne
                                // refuse.
                                if rest == nil {
                                    Capsule(style: .continuous)
                                        .strokeBorder(
                                            Color(red: 0.90, green: 0.22,
                                                  blue: 0.18),
                                            lineWidth: 1)
                                        .phaseAnimator([0.14, 0.52]) { v, o in
                                            v.opacity(o)
                                        } animation: { _ in
                                            .easeInOut(duration: 1.05)
                                        }
                                }
                            }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    /// Anglais (22-08) : « 1min30 » n'existe pas en anglais — au-delà de la
    /// minute on lit une DURÉE (`1:30`), pas une phrase. Sous la minute, les
    /// secondes gardent leur forme courte.
    static func restLabel(_ s: Int) -> String {
        switch s {
        case ..<60: return "\(s)s"
        case 60: return "1 min"
        case 90: return "1:30"
        default: return "\(s / 60) min"
        }
    }

    /// LA PALETTE DU DRAG — blanc chaud, jaune, orange, rouge : le feu de
    /// la maison. Trois segments, jamais une interpolation directe
    /// blanc→rouge (elle passerait par un rose sale — la leçon de la
    /// chauffe du médaillon).
    static func fire(_ u: CGFloat) -> Color {
        let x = min(max(Double(u), 0), 1)
        if x < 0.35 {
            let k = x / 0.35
            return Color(red: 1.0,
                         green: 0.97 - (0.97 - 0.84) * k,
                         blue: 0.88 - (0.88 - 0.35) * k)
        }
        if x < 0.70 {
            let k = (x - 0.35) / 0.35
            return Color(red: 1.0,
                         green: 0.84 - (0.84 - 0.55) * k,
                         blue: 0.35 - (0.35 - 0.18) * k)
        }
        let k = (x - 0.70) / 0.30
        return Color(red: 1.0 - (1.0 - 0.88) * k,
                     green: 0.55 - (0.55 - 0.22) * k,
                     blue: 0.18 - (0.18 - 0.10) * k)
    }
}

// MARK: - Le banc

/// `-setLab`. LE VRAI CADRAN, pas une maquette. Un premier essai posait le
/// sheet au-dessus d'un cercle dessiné à la main : on ne voyait rien du verre,
/// parce qu'un verre ne se voit que par ce qu'il déforme et qu'il n'y avait
/// que du noir dessous. Le banc monte donc `LiquidLensLab` en mode parcours,
/// à froid — on tire la bulle, on arrive dans la nuit, et « Terminer la
/// série » ouvre la feuille sur les halos.
struct SetEntryLab: View {
    var body: some View {
        LiquidLensLab(headline: "Woodchopper\npoulie haute",
                      faceLabel: "SET 1",
                      onFinish: { _ in })
            .preferredColorScheme(.dark)
    }
}

// MARK: - La molette fluide

/// UNE RÉGLETTE QUI GLISSE, pas deux boutons qui cliquent. Passer de 20 à
/// 42,5 kg avec un « + » demande quarante-cinq appuis ; ici c'est un geste.
/// La valeur vit au centre, la graduation défile dessous, et le doigt sent les
/// crans sans que la course s'arrête.
struct FluidPicker: View {
    let title: String
    let unit: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    /// L'écart entre deux graduations, en points. 13 : assez serré pour que la
    /// règle se lise comme une matière, assez large pour viser au doigt.
    private static let tick: CGFloat = 13
    /// Une graduation haute — et un chiffre — tous les cinq crans.
    private static let major = 5

    @State private var dragStart: Double?
    @State private var lastTick: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.inter(9.5, .medium))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.42))
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(display)
                        .font(.inter(30, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.96))
                        .contentTransition(.numericText())
                    Text(unit)
                        .font(.inter(12))
                        .foregroundStyle(Color.white.opacity(0.42))
                }
            }
            ruler
        }
    }

    private var display: String {
        value == value.rounded() ? String(Int(value.rounded()))
                                 : String(format: "%.1f", value)
    }

    private var ruler: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let mid = w / 2
            let unitsVisible = Double(w / Self.tick)
            let first = max(range.lowerBound, value - unitsVisible / 2 - 2)
            let last = min(range.upperBound, value + unitsVisible / 2 + 2)
            ZStack {
                // Les graduations, dessinées au Canvas : une centaine de
                // `Rectangle` SwiftUI par règle coûterait une centaine de
                // nœuds pour des traits d'un point.
                Canvas { ctx, size in
                    var v = first.rounded()
                    while v <= last {
                        let x = mid + CGFloat(v - value) * Self.tick / CGFloat(step)
                        if x >= -6, x <= size.width + 6 {
                            let isMajor = Int(v) % Self.major == 0
                            let h: CGFloat = isMajor ? 17 : 9
                            let a: Double = isMajor ? 0.34 : 0.16
                            // Les bords s'éteignent : la règle n'a pas de fin
                            // franche, elle s'enfonce dans la nuit.
                            let edge = min(1, min(x, size.width - x) / 46)
                            ctx.fill(
                                Path(roundedRect: CGRect(x: x - 0.6,
                                                         y: (size.height - h) / 2,
                                                         width: 1.2, height: h),
                                     cornerRadius: 0.6),
                                with: .color(.white.opacity(a * max(0, edge))))
                        }
                        v += step
                    }
                }
                // Le curseur : une lame chaude au centre, immobile. C'est la
                // matière qui bouge sous elle, pas l'inverse.
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.86, blue: 0.60),
                                 Color(red: 1.0, green: 0.55, blue: 0.14)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 2.4, height: 30)
                    .shadow(color: Color(red: 1.0, green: 0.5, blue: 0.12)
                        .opacity(0.7), radius: 7)
            }
            .frame(width: w, height: 46)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        let origin = dragStart ?? value
                        if dragStart == nil { dragStart = value }
                        let delta = -Double(g.translation.width / Self.tick) * step
                        let v = min(max(origin + delta, range.lowerBound),
                                    range.upperBound)
                        value = (v / step).rounded() * step
                        // Le cran sous le doigt : un grain à chaque
                        // graduation franchie, jamais à chaque image.
                        let t = Int((value / step).rounded())
                        if t != lastTick {
                            lastTick = t
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                    .onEnded { _ in dragStart = nil }
            )
        }
        .frame(height: 46)
        .background {
            Color.clear.glassEffect(
                .regular.tint(Color.black.opacity(0.22)),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
