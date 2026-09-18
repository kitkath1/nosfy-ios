import SwiftUI

// MARK: - Géométrie de la dalle

/// TOUTE la géométrie de l'ensemble carte blanche + pastille, en un seul
/// endroit : le banc la fouette, et les morphismes à venir (la carte qui se
/// réduit ou s'agrandit au drag) n'auront qu'à animer ces nombres-là.
///
/// Les contraintes qui tiennent l'incrustation :
/// - `shoulder` = rayon de la pastille + `gap` : le blanc épouse la pierre à
///   distance constante.
/// - `notchInset` = (marge pastille − marge carte) − `gap` : les murs de
///   l'encoche tombent à `gap` des flancs de la pastille.
/// - `notchDepth` ≥ `fillet` + `shoulder`, sinon le S n'a pas la place de se
///   dérouler et les rayons se replient.
enum SlabGeometry {
    /// Marge de la carte blanche au bord d'écran.
    static let cardMargin: CGFloat = 12
    /// Rayon des coins hauts — assez grand pour que la crête se lise comme un
    /// DÔME et non comme une carte : c'est le blanc qui se lève de la page.
    /// `NotchedCardShape` le plafonne de toute façon à la moitié de la hauteur.
    static let topRadius: CGFloat = 100
    /// Rayon des coins bas — petits, comme la référence : le bord file
    /// presque directement dans le S de l'encoche.
    static let bottomRadius: CGFloat = 8

    /// Marge de la pastille au bord d'écran.
    static let pillMargin: CGFloat = 34
    static let pillHeight: CGFloat = 64
    static let pillRadius: CGFloat = 22
    /// Le filet de NOIR entre le blanc et la pastille — c'est lui qu'on lit
    /// comme « incrusté ».
    static let gap: CGFloat = 7

    static let fillet: CGFloat = 7
    static var shoulder: CGFloat { pillRadius + gap }
    static var notchInset: CGFloat { pillMargin - cardMargin - gap }
    /// La pastille pénètre de `notchDepth − gap` au-dessus du bord bas de la
    /// carte : à 40, un peu plus de la moitié de sa hauteur est enchâssée.
    static let notchDepth: CGFloat = 40
    /// Ce que la pastille laisse dépasser SOUS le bord bas de la carte.
    static var pillDrop: CGFloat { pillHeight - (notchDepth - gap) }
}

// MARK: - La dalle : le dôme blanc de lancement + la pastille

/// Le plancher de la fiche d'exercice, et le GESTE de la page : un dôme de
/// papier qui monte du bas de l'écran, porte l'invite « Glisser pour
/// démarrer », et que le doigt tire vers le haut pour lancer la série. La
/// pastille de séance reste incrustée dans son échancrure.
///
/// Deux choses le distinguent de l'ancienne dalle-formulaire. Sa CRÊTE n'a
/// pas d'arête : elle s'éteint dans le noir de la page (`crestFade`) — le
/// blanc se lève, il ne se pose pas. Et son drag n'est plus un teaser
/// décoratif : c'est le début du geste de la lentille, que le blanc de ce
/// dôme prolongera en inondant la page.
struct ExerciseSetupSlab: View {
    let exercise: Exercise
    /// Fraction des séries faites, pour le filet de la pastille.
    var progress: Double = 0
    let label: String
    /// Fraction de la course déjà parcourue [0,1] — la page s'en sert pour
    /// se remplir du MÊME papier que ce dôme : quand la lentille se pose
    /// dessus, il n'y a aucune couture, juste la suite du même blanc.
    @Binding var flood: Double
    /// Le doigt a tiré le dôme jusqu'au bout de sa course.
    let onLaunch: () -> Void

    /// Ce que le doigt a tiré vers le haut, en points — toujours positif.
    @State private var pull: CGFloat = 0
    @State private var fired = 0

    /// La course qui déclenche. Assez longue pour qu'un frôlement en passant
    /// ne lance rien, assez courte pour tenir dans un pouce.
    private static let travel: CGFloat = 116

    /// L'incrustation fait partie de l'IDENTITÉ de l'écran : la pastille est
    /// toujours là, l'échancrure toujours creusée. Le branchement sur l'état
    /// réel de la séance viendra avec le retravail du composant pastille —
    /// la forme sait déjà se refermer (`notchDepth` animatable).
    private let hasPill = true

    /// Ce que la dalle a monté à l'écran : la résistance s'épaissit vers la
    /// fin de la course, pour que le geste se SENTE arriver au bout.
    private var lift: CGFloat {
        let u = min(pull / Self.travel, 1)
        return u * Self.travel * 0.34
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            card
                .padding(.horizontal, SlabGeometry.cardMargin)
                .padding(.bottom, hasPill ? SlabGeometry.pillDrop : 0)
                // Le geste vit sur le dôme SEUL : posé sur la pile entière,
                // il volerait les touchers des boutons de la pastille.
                .gesture(lifter)

            if hasPill {
                WorkoutPill(exercise: exercise, progress: progress)
                    .padding(.horizontal, SlabGeometry.pillMargin)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .offset(y: -lift)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: fired)
    }

    private var lifter: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                pull = max(0, -v.translation.height)
                flood = Double(min(pull / Self.travel, 1))
            }
            .onEnded { _ in
                if pull >= Self.travel {
                    fired += 1
                    // La page est déjà blanche : la lentille se pose dessus
                    // sans que rien ne change de couleur.
                    flood = 1
                    onLaunch()
                } else {
                    withAnimation(.easeOut(duration: 0.22)) { flood = 0 }
                }
                withAnimation(.spring(response: 0.42,
                                      dampingFraction: 0.74)) {
                    pull = 0
                }
            }
    }

    // MARK: Le dôme de papier

    /// Pas du blanc pur : sur l'OLED noir, le #FFF crame dans une pièce
    /// sombre. Un blanc cassé à peine chaud, comme la référence.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)

    private var cardShape: NotchedCardShape {
        NotchedCardShape(topRadius: SlabGeometry.topRadius,
                         bottomRadius: SlabGeometry.bottomRadius,
                         notchInset: SlabGeometry.notchInset,
                         notchDepth: hasPill ? SlabGeometry.notchDepth : 0,
                         shoulderRadius: SlabGeometry.shoulder,
                         filletRadius: SlabGeometry.fillet)
    }

    /// La crête ne se coupe pas : le papier s'allume sur ses premiers points
    /// de haut. Une arête franche entre le blanc et le noir, c'est un COLLAGE
    /// — et c'est ce que « un peu fondue » voulait dire.
    private var crestFade: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.0), location: 0.0),
                .init(color: .white.opacity(0.28), location: 0.045),
                .init(color: .white.opacity(0.90), location: 0.145),
                .init(color: .white, location: 0.24)
            ],
            startPoint: .top, endPoint: .bottom)
    }

    private var card: some View {
        VStack(spacing: 11) {
            Image(systemName: "arrow.up")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.58))
            Text(label)
                .font(.inter(15, .medium))
                .foregroundStyle(Color.black.opacity(0.55))
        }
        .padding(.top, 84)
        // Le contenu se retire de l'encoche quand elle se creuse.
        .padding(.bottom, (hasPill ? SlabGeometry.notchDepth : 0) + 26)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(cardShape.fill(Self.paper).mask(crestFade))
        // La zone tactile suit l'échancrure : sans ça, la carte volerait les
        // touchers destinés aux boutons de la pastille.
        .contentShape(cardShape)
    }
}

// MARK: - La carte des séries

/// UNE carte pour toute la partie « série » — elle a absorbé la rangée de
/// pastilles de l'ancienne dalle. Tant qu'aucune série n'a été lancée, elle
/// ne raconte qu'une chose : il n'y en a aucune.
///
/// Les points sont des POINTS, pas des lumières : la matière lumineuse
/// (`LightDial`) viendra quand le modèle saura dire « prévue » et « en
/// cours » — aujourd'hui une série n'est que faite ou pas faite.
struct SeriesCard: View {
    let done: Int
    let total: Int

    private static let shape = RoundedRectangle(cornerRadius: 22,
                                                style: .continuous)

    /// La série qu'on est en train de faire : la première pas encore cochée,
    /// ou la dernière quand tout est fait.
    private var current: Int { min(done + 1, max(total, 1)) }

    var body: some View {
        HStack(spacing: 14) {
            if total == 0 {
                // Rien à compter : une seule phrase, et la carte se tait.
                Text("0 série en cours")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.inkSecondary)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Série \(current) sur \(total)")
                        .font(.inter(15, .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(subtitle)
                        .font(.inter(12))
                        .foregroundStyle(Color.inkMuted)
                }
            }

            Spacer(minLength: 8)

            if total > 0 { dots }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background {
            // Le même verre fumé que les chips du header : sur cette page, il
            // n'y a qu'une seule matière sombre.
            Color.clear
                .glassEffect(.regular.tint(Color.black.opacity(0.5)),
                             in: Self.shape)
        }
        .overlay(Self.shape.strokeBorder(Color.white.opacity(0.08),
                                         lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(total == 0 ? "Aucune série en cours"
                                       : "Série \(current) sur \(total)")
    }

    private var subtitle: String {
        guard total > 0 else { return "0 série en cours" }
        if done == 0 { return "\(total) série\(total > 1 ? "s" : "") au total" }
        return "\(done) faite\(done > 1 ? "s" : "") sur \(total)"
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(i < done ? 0.88 : 0.16))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Les pastilles de séries

/// La rangée 1 → n : chaque série est une pastille — pleine et noire pour
/// celle qu'on règle, cochée d'or pour celles qui sont faites (l'or reste
/// réservé à ce qui a été gagné), cerclée d'un fil pour celles qui attendent.
/// Elle remplace l'empilement vertical « Série 1 / Série 2 » : les rangées de
/// réglage en dessous éditent la pastille choisie.
struct SetChipsRow: View {
    let sets: [DraftSet]
    @Binding var selected: Int
    let canAdd: Bool
    let onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(sets.enumerated()), id: \.element.id) { i, set in
                    chip(index: i, set: set)
                }
                if canAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.5))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle().strokeBorder(
                                    Color.black.opacity(0.22),
                                    style: StrokeStyle(lineWidth: 1,
                                                       dash: [3, 3]))
                            )
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        // Les paillettes d'une série qui se coche débordent de la rangée —
        // une gerbe rognée par son cadre n'est plus une gerbe.
        .overlay { SparkleBurst(trigger: sets.filter(\.isDone).count) }
    }

    private func chip(index i: Int, set: DraftSet) -> some View {
        let current = i == selected
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                selected = i
            }
        } label: {
            ZStack {
                if set.isDone {
                    Circle().fill(Color.black.opacity(0.06))
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.woopGold)
                } else if current {
                    Circle().fill(Color.black)
                    Text("\(i + 1)")
                        .font(.inter(14, .semibold))
                        .foregroundStyle(.white)
                } else {
                    Circle().strokeBorder(Color.black.opacity(0.16),
                                          lineWidth: 1)
                    Text("\(i + 1)")
                        .font(.inter(14, .medium))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }
            .frame(width: 34, height: 34)
            // L'anneau de sélection reste lisible même sur une série faite.
            .overlay {
                if current, set.isDone {
                    Circle().strokeBorder(Color.black.opacity(0.55),
                                          lineWidth: 1.4)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Série \(i + 1)"
                            + (set.isDone ? ", faite" : ""))
    }
}

// MARK: - Une rangée de réglage

/// Une ligne de la carte blanche : un puits gris à peine creusé dans le
/// papier, l'icône dans son chip, le libellé, et le réglage à droite. Les
/// « bords » de cette carte ne sont pas des traits : ce sont des différences
/// de niveau — papier, gris 0,035, gris 0,05.
struct SetupRow<Control: View>: View {
    let icon: String
    let label: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.55))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.black.opacity(0.05))
                )
            Text(label)
                .font(.inter(15, .medium))
                .foregroundStyle(Color.black.opacity(0.75))
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.035))
        )
    }
}

// MARK: - Les steppers clairs

/// Le MÊME système que les steppers de la fiche noire — deux signes qui
/// incrémentent, une valeur qui s'ouvre sur une roue de verre, la répétition
/// au maintien — recolorié pour vivre sur le papier. Les correctifs durement
/// gagnés (contentShape plein cadre, buttonRepeatBehavior) sont conservés.
struct LightStepperControl<Wheel: View>: View {
    let text: String
    let onMinus: () -> Void
    let onPlus: () -> Void
    @ViewBuilder var wheel: Wheel

    @State private var picking = false

    private let shape = RoundedRectangle(cornerRadius: 11, style: .continuous)

    var body: some View {
        HStack(spacing: 0) {
            facet("minus", action: onMinus)

            Button { picking = true } label: {
                HStack(spacing: 5) {
                    Text(text)
                        .font(.inter(15, .semibold))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .contentTransition(.numericText())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.30))
                }
                .frame(minWidth: 84, minHeight: 34)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            facet("plus", action: onPlus)
        }
        .background(shape.fill(Color.black.opacity(0.05)))
        .overlay {
            shape.strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .popover(isPresented: $picking) {
            wheel
                .frame(width: 210, height: 178)
                .presentationCompactAdaptation(.popover)
                // La même roue de verre fumé que la fiche noire : l'app est en
                // scheme sombre, la roue écrit en blanc — un verre clair la
                // rendrait illisible.
                .presentationBackground {
                    Color.clear
                        .glassEffect(.regular.tint(Color.black.opacity(0.45)),
                                     in: .rect)
                }
        }
    }

    private func facet(_ symbol: String,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.45))
                .frame(width: 38, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }
}

struct LightNumberStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unit: String

    private var choices: [Int] {
        Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
    }

    var body: some View {
        LightStepperControl(
            text: display(value),
            onMinus: { value = max(range.lowerBound, value - step) },
            onPlus: { value = min(range.upperBound, value + step) }
        ) {
            Picker(label, selection: $value) {
                ForEach(choices, id: \.self) { Text(display($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
        }
    }

    private func display(_ v: Int) -> String {
        guard unit == "s" else { return "\(v) \(unit)" }
        if v < 60 { return "\(v) s" }
        let m = v / 60, s = v % 60
        return s == 0 ? "\(m) min" : "\(m):\(String(format: "%02d", s))"
    }
}

struct LightDecimalStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    private var choices: [Double] {
        Array(stride(from: range.lowerBound, through: range.upperBound, by: step))
    }

    var body: some View {
        LightStepperControl(
            text: display(value),
            onMinus: { value = max(range.lowerBound, value - step) },
            onPlus: { value = min(range.upperBound, value + step) }
        ) {
            Picker(label, selection: $value) {
                ForEach(choices, id: \.self) { Text(display($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
        }
    }

    private func display(_ v: Double) -> String {
        let number = v.formatted(.number.precision(.fractionLength(0...1)))
        return unit.isEmpty ? number : "\(number) \(unit)"
    }
}

// MARK: - Glisser pour lancer

/// Le slider de lancement — PLACEHOLDER assumé, retravaillé plus tard : une
/// piste en capsule creusée dans le papier, un pouce blanc qui porte la
/// flèche, le libellé qui s'efface sous le geste. Passé 70 % du voyage, le
/// relâcher déclenche ; en deçà, le pouce revient en ressort.
struct SlideToStart: View {
    let label: String
    let onTrigger: () -> Void

    @State private var drag: CGFloat = 0
    @State private var fired = 0

    private let height: CGFloat = 60
    private let inset: CGFloat = 6
    private var thumb: CGFloat { height - inset * 2 }

    var body: some View {
        GeometryReader { geo in
            let travel = max(geo.size.width - inset * 2 - thumb, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.045))
                Capsule().strokeBorder(Color.black.opacity(0.07), lineWidth: 1)

                Text(label)
                    .font(.inter(14, .medium))
                    .foregroundStyle(Color.black.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    // Le libellé s'efface à mesure que le pouce avance : il
                    // décrit le geste, il n'a pas à lui survivre.
                    .opacity(max(0, 1 - Double(drag / (travel * 0.5))))

                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.10), radius: 8, y: 2)
                    .overlay {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                    .frame(width: thumb, height: thumb)
                    .offset(x: inset + drag)
                    .gesture(
                        DragGesture()
                            .onChanged { v in
                                drag = min(max(v.translation.width, 0), travel)
                            }
                            .onEnded { _ in
                                if drag > travel * 0.7 {
                                    fired += 1
                                    withAnimation(.spring(response: 0.25,
                                                          dampingFraction: 0.8)) {
                                        drag = travel
                                    }
                                    onTrigger()
                                    // Le pouce revient pendant que le plein
                                    // écran du compteur couvre la page.
                                    withAnimation(.spring(response: 0.45,
                                                          dampingFraction: 0.8)
                                        .delay(0.5)) {
                                        drag = 0
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35,
                                                          dampingFraction: 0.7)) {
                                        drag = 0
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: height)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: fired)
        .accessibilityRepresentation {
            Button(label) { onTrigger() }
        }
    }
}
