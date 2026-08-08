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
    var onConfirm: () -> Void

    /// Les repos proposés. Six valeurs, toutes visibles d'un coup : une liste
    /// qu'il faut dérouler pour choisir entre 30 s et 1 min est une liste de
    /// trop.
    static let restChoices: [Int] = [30, 45, 60, 90, 120, 180]

    var body: some View {
        VStack(spacing: 0) {
            header
            // TOUT TIENT SANS DÉFILER, et ce n'est pas un confort : le repos
            // est le SEUL champ obligatoire, et un champ obligatoire qu'il
            // faut aller chercher sous la ligne de flottaison est un champ
            // qu'on oublie — le slide refuserait sans que rien n'explique
            // pourquoi. Trois blocs, une moitié d'écran, aucun défilement.
            VStack(spacing: 14) {
                FluidPicker(title: "RÉPÉTITIONS", unit: "reps",
                            value: repsBinding, range: 1...50, step: 1)
                FluidPicker(title: "CHARGE", unit: "kg",
                            value: $kilos, range: 4...100, step: 1)
                restRow
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            Spacer(minLength: 0)

            GaletSlide(label: "Glisser pour lancer le repos",
                       validate: { rest != nil },
                       onConfirm: onConfirm)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .padding(.top, 4)
        }
        // LA HAUTEUR EST UN ARBITRAGE, pas un confort. À 0,50 le contenu
        // était comprimé et le header passait sous la poignée ; plus haut que
        // 0,62 la feuille mange l'auréole du cadran — or c'est elle qui donne
        // au verre quelque chose à réfracter. 0,62 est le point où les trois
        // blocs respirent sans que la lumière du fond disparaisse.
        .presentationDetents([.fraction(0.62)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(34)
        // LE FOND DU SHEET EST DU VERRE, pas une dalle : c'est la page
        // derrière qui doit continuer d'exister sous la feuille.
        // LE TEINT EST LÉGER À DESSEIN. À 0,42 de noir, le verre n'était plus
        // du verre : il ne restait qu'une dalle sombre, parce qu'un verre ne
        // se voit QUE par ce qu'il déforme. Sur le cadran et ses halos il a de
        // quoi mordre — c'est là qu'il faut le juger, pas sur du noir.
        .presentationBackground {
            Color.clear.glassEffect(
                .regular.tint(Color.black.opacity(0.24)),
                in: RoundedRectangle(cornerRadius: 34, style: .continuous))
        }
        .presentationBackgroundInteraction(.disabled)
    }

    /// `reps` est un `Int` mais la molette travaille en `Double` : une molette
    /// qui saute d'entier en entier n'est pas fluide, elle CLIQUE. Elle glisse
    /// donc en continu et n'arrondit qu'à la lecture.
    private var repsBinding: Binding<Double> {
        Binding(get: { Double(reps) }, set: { reps = Int($0.rounded()) })
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Série \(rank)")
                .font(.inter(20, .semibold))
                .foregroundStyle(Color.inkPrimary)
            Text("Note tes perfs avant de lancer le repos.")
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Text("REPOS")
                    .font(.inter(9.5, .medium))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.42))
                // La seule information manquante possible : on la désigne,
                // plutôt que d'attendre que le slide la reproche.
                if rest == nil {
                    Text("à choisir")
                        .font(.inter(9.5, .medium))
                        .tracking(0.4)
                        .foregroundStyle(Color(red: 1.0, green: 0.66, blue: 0.28)
                            .opacity(0.85))
                }
            }
            HStack(spacing: 7) {
                ForEach(Self.restChoices, id: \.self) { s in
                    restChip(s)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .foregroundStyle(on ? Color.white : Color.white.opacity(0.58))
                .shadow(color: on ? Color(red: 1.0, green: 0.86, blue: 0.66)
                    .opacity(0.55) : .clear, radius: on ? 7 : 0)
                .shadow(color: on ? Color.white.opacity(0.35) : .clear,
                        radius: on ? 2 : 0)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background {
                    if on {
                        // Le noir mat. Un chip noir sur un verre sombre n'a
                        // plus de contour pour exister : c'est le liseré
                        // chaud, très fin, qui le tient — sans lui il
                        // disparaîtrait dans la feuille.
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.035, green: 0.033, blue: 0.036))
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.78,
                                                       blue: 0.48).opacity(0.55),
                                                 Color(red: 1.0, green: 0.55,
                                                       blue: 0.20).opacity(0.12)],
                                        startPoint: .top, endPoint: .bottom),
                                        lineWidth: 1)
                            }
                    } else {
                        Color.clear.glassEffect(
                            .regular.tint(Color.black.opacity(0.24)),
                            in: Capsule(style: .continuous))
                    }
                }
        }
        .buttonStyle(.plain)
    }

    static func restLabel(_ s: Int) -> String {
        switch s {
        case ..<60: return "\(s)s"
        case 60: return "1min"
        case 90: return "1min30"
        default: return "\(s / 60)min"
        }
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
                      faceLabel: "SÉRIE 1",
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
