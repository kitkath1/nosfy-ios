import SwiftUI
import UIKit

// MARK: - Le slider de validation

/// LE GESTE QUI ENGAGE. Un CTA se tape sans y penser ; une série qu'on
/// enregistre et un repos qu'on lance méritent qu'on les pousse. C'est le même
/// geste que le galet blanc de la fiche et que le galet de la barre — la
/// maison ne connaît qu'une façon de démarrer quelque chose : on la POUSSE.
///
/// LE POUCE REPREND LE LANGAGE DU GALET PLAY, il ne le réutilise pas : le
/// triangle de la barre est un `static float nsdPlay()` local à
/// NavMonolith.metal, inatteignable depuis Swift comme depuis un autre
/// shader — le fichier le dit lui-même (« le glyphe vit dans le shader, on ne
/// peut pas le masquer »). On le REDESSINE donc, avec la même grammaire :
/// galet d'obsidienne, anneau de néon chaud, triangle laqué.
///
/// LE REFUS EST UN VRAI ÉTAT, pas une absence d'effet. Sans lui, un slide qui
/// ne part pas se lit comme un geste raté — la faute revient au doigt. Ici le
/// composant DIT non : il se raidit à mi-course, vire au grenat, revient sec,
/// et frappe deux fois dans la main.
struct GaletSlide: View {
    var label: String = "Glisser pour lancer le repos"
    /// La validation. Rend `true` si tout est en règle : le pouce va au bout
    /// et `onConfirm` part. Rend `false` et c'est le refus qui se joue.
    var validate: () -> Bool = { true }
    var onConfirm: () -> Void

    @State private var drag: CGFloat = 0
    @State private var refused = false
    @State private var refusedAt: Date = .distantPast
    @State private var okBeat = 0
    @State private var noBeat = 0
    /// LA TRAÎNE. Les positions successives du pouce, horodatées — la fumée
    /// n'est pas un panache collé au galet, c'est ce qu'il LAISSE DERRIÈRE.
    /// C'est la technique de l'encre de la lentille, qui garde le chemin du
    /// doigt plutôt que sa position.
    @State private var puffs: [Puff] = []
    @State private var lastPuffAt: Date = .distantPast
    @State private var dragging = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Puff: Identifiable {
        let id = UUID()
        let x: CGFloat
        let born: Date
        let drift: CGFloat
        let size: CGFloat
        let spark: Bool
    }

    /// Une bouffée vit 1,1 s. Au-delà elle ne pèse plus rien à l'écran mais
    /// coûte encore une passe : on la retire.
    private static let puffLife: Double = 1.1

    private let height: CGFloat = 66
    private let inset: CGFloat = 6
    private var thumb: CGFloat { height - inset * 2 }

    /// LE GRENAT DU REFUS. L'app n'a pas de rouge — sa palette est violet, or
    /// et argent — et c'en est presque une loi. Celui-ci est donc le plus
    /// sourd possible : un grenat qui a la densité de l'obsidienne, pas un
    /// rouge d'alerte système. Il ne vit qu'une demi-seconde, et nulle part
    /// ailleurs dans l'app.
    private static let garnet = Color(red: 0.62, green: 0.13, blue: 0.16)

    var body: some View {
        GeometryReader { geo in
            let travel = max(geo.size.width - inset * 2 - thumb, 1)
            let p = drag / travel
            ZStack(alignment: .leading) {
                track(progress: p)
                Text(label)
                    .font(.inter(14, .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .frame(maxWidth: .infinity)
                    // Le libellé décrit le geste, il n'a pas à lui survivre.
                    .opacity(max(0, 1 - Double(p / 0.45)))
                smoke
                galet(progress: p)
                    .frame(width: thumb, height: thumb)
                    .offset(x: inset + drag)
                    .gesture(push(travel: travel))
            }
        }
        .frame(height: height)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9), trigger: okBeat)
        .accessibilityRepresentation {
            Button(label) { if validate() { onConfirm() } }
        }
    }

    // MARK: La piste

    private func track(progress p: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.34))
            // La traînée : ce qui est déjà poussé s'allume. Elle chauffe avec
            // la course, elle ne s'allume pas d'un coup à l'arrivée.
            GeometryReader { g in
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.48, blue: 0.10)
                            .opacity(0.10 + 0.26 * Double(p)),
                                 Color(red: 1.0, green: 0.70, blue: 0.32)
                            .opacity(0.05 + 0.20 * Double(p))],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(0, inset + drag + thumb / 2))
                    .frame(maxHeight: .infinity)
            }
            Capsule(style: .continuous)
                .strokeBorder(refused
                              ? Self.garnet.opacity(0.85)
                              : Color.white.opacity(0.10),
                              lineWidth: refused ? 1.4 : 1)
        }
        .background {
            // Le verre, comme partout ailleurs dans la page.
            Color.clear.glassEffect(
                .regular.tint(Color.black.opacity(0.28)),
                in: Capsule(style: .continuous))
        }
        // LE REFUS TEINTE LA PISTE ENTIÈRE, brièvement. Un liseré rouge seul
        // se confond avec un état ; un bain court se lit comme un ÉVÉNEMENT.
        .overlay {
            Capsule(style: .continuous)
                .fill(Self.garnet.opacity(refused ? 0.22 : 0))
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: refused ? 0.10 : 0.34), value: refused)
    }

    // MARK: Le pouce

    // MARK: La fumée

    /// LA TRAÎNE, au `Canvas` et non au shader — et c'est un choix de coût,
    /// pas de facilité. Ce slider vit DANS un sheet, au-dessus d'un cadran qui
    /// est déjà un `layerEffect` plein écran à 60 Hz avec trois `colorEffect`
    /// dedans. Une quatrième passe de shader par-dessus, c'est là que la
    /// cadence se perd. Un Canvas de vingt disques flous ne coûte rien et se
    /// règle au doigt.
    ///
    /// La fumée MONTE et RECULE : elle a l'inertie de ce qui vient d'être
    /// poussé. Elle est blanche au cœur, cendre au bord — une fumée
    /// entièrement blanche est de la vapeur, une fumée grise est de la suie ;
    /// il faut les deux.
    private var smoke: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: puffs.isEmpty)) { tl in
            let now = tl.date
            Canvas { ctx, size in
                for p in puffs {
                    let age = now.timeIntervalSince(p.born)
                    guard age >= 0, age < Self.puffLife else { continue }
                    let u = age / Self.puffLife
                    // Elle enfle en s'éteignant : une bouffée qui rétrécit en
                    // disparaissant a l'air aspirée, pas dissipée.
                    let r = p.size * (0.5 + 1.9 * u)
                    let a = (1 - u) * (1 - u) * (p.spark ? 0.55 : 0.24)
                    let cx = p.x + p.drift * CGFloat(u) * 26
                    let cy = size.height / 2 - CGFloat(u) * 17
                    let rect = CGRect(x: cx - r, y: cy - r,
                                      width: r * 2, height: r * 2)
                    ctx.fill(
                        Path(ellipseIn: rect),
                        with: .radialGradient(
                            Gradient(colors: [
                                .white.opacity(a),
                                Color(white: p.spark ? 0.92 : 0.62)
                                    .opacity(a * 0.45),
                                .clear]),
                            center: CGPoint(x: cx, y: cy),
                            startRadius: 0, endRadius: r))
                }
            }
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .onChange(of: now) { _, t in
                // Le ménage se fait ici, pas dans le geste : une bouffée doit
                // mourir même si le doigt s'est arrêté.
                if puffs.contains(where: {
                    t.timeIntervalSince($0.born) >= Self.puffLife }) {
                    puffs.removeAll { t.timeIntervalSince($0.born) >= Self.puffLife }
                }
            }
        }
    }

    /// Une bouffée toutes les 28 ms tant que le doigt avance — assez pour que
    /// la traîne soit continue, assez peu pour qu'elle reste une vingtaine de
    /// disques à l'écran.
    private func emit(at x: CGFloat) {
        let now = Date.now
        guard now.timeIntervalSince(lastPuffAt) > 0.028 else { return }
        lastPuffAt = now
        let spark = Int.random(in: 0..<5) == 0
        puffs.append(Puff(x: x,
                          born: now,
                          drift: CGFloat.random(in: -1.0 ... -0.25),
                          size: CGFloat.random(in: spark ? 3...5 : 6...11),
                          spark: spark))
        if puffs.count > 34 { puffs.removeFirst(puffs.count - 34) }
    }

    /// Le galet : obsidienne, anneau chaud, triangle laqué. Le langage du
    /// galet de la barre, redessiné.
    ///
    /// IL CHAUFFE DE L'ORANGE VERS LE BLANC. Un métal qu'on pousse ne devient
    /// pas « plus orange », il monte en température : orange, puis or, puis
    /// blanc. C'est la couleur qui dit que le seuil approche, avant même que
    /// le pouce y soit.
    private func galet(progress p: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 0.14, green: 0.13, blue: 0.14),
                             Color(red: 0.045, green: 0.042, blue: 0.048)],
                    center: UnitPoint(x: 0.34, y: 0.24),
                    startRadius: 1, endRadius: thumb * 0.92))
            Circle()
                .strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(0.26),
                             Color.white.opacity(0.03)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 0.9)
            // L'anneau : il chauffe de l'orange au blanc avec la course, et
            // vire au grenat au refus.
            Circle()
                .strokeBorder(refused ? Self.garnet : Self.heat(p),
                              lineWidth: 1.6 + 0.9 * p)
                .opacity(refused ? 0.95 : 0.42 + 0.55 * Double(p))
                .blur(radius: 0.4)
            Triangle()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.96),
                             Color(red: 1.0, green: 0.86, blue: 0.62)
                                .opacity(1 - 0.4 * Double(p))],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: thumb * 0.30, height: thumb * 0.33)
                .offset(x: thumb * 0.04)
        }
        .shadow(color: (refused ? Color.clear : Self.heat(p))
            .opacity(refused ? 0 : 0.20 + 0.45 * Double(p)),
                radius: 10 + 14 * p)
        .shadow(color: Self.garnet.opacity(refused ? 0.55 : 0), radius: 10)
        .animation(.easeOut(duration: 0.12), value: refused)
    }

    /// LA CHAUFFE. Orange à froid, or à mi-course, blanc au seuil. Trois
    /// paliers et non deux : un dégradé direct orange → blanc passe par un
    /// rose sale vers 50 %, parce que le vert monte plus vite que le bleu.
    /// L'or au milieu tient la teinte.
    static func heat(_ p: CGFloat) -> Color {
        let u = min(max(Double(p), 0), 1)
        if u < 0.55 {
            let k = u / 0.55
            return Color(red: 1.0,
                         green: 0.52 + (0.80 - 0.52) * k,
                         blue: 0.12 + (0.42 - 0.12) * k)
        }
        let k = (u - 0.55) / 0.45
        return Color(red: 1.0,
                     green: 0.80 + (1.0 - 0.80) * k,
                     blue: 0.42 + (1.0 - 0.42) * k)
    }

    // MARK: Le geste

    private func push(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                guard !refused else { return }
                drag = min(max(v.translation.width, 0), travel)
                if !reduceMotion { emit(at: inset + drag + thumb / 2) }
            }
            .onEnded { _ in
                guard !refused else { return }
                // Le seuil est à 72 % : assez haut pour qu'un frôlement ne
                // parte pas, assez bas pour que le dernier centimètre ne soit
                // pas une épreuve.
                guard drag > travel * 0.72 else {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.72)) { drag = 0 }
                    return
                }
                guard validate() else {
                    refuse(travel: travel)
                    return
                }
                okBeat += 1
                CommitHaptic.play()
                // La traîne s'éteint d'elle-même ; on n'en émet plus.
                withAnimation(.spring(response: 0.24,
                                      dampingFraction: 0.85)) { drag = travel }
                onConfirm()
                // Le pouce revient pendant que le sheet se referme.
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)
                    .delay(0.45)) { drag = 0 }
            }
    }

    /// LE REFUS. Il se voit, il se sent, et il RENVOIE — dans cet ordre, en
    /// 0,42 s. Le retour est sec (amortissement 0,92, pas de rebond) : un
    /// ressort qui rebondit a l'air de jouer, et on ne joue pas quand on
    /// refuse.
    private func refuse(travel: CGFloat) {
        refused = true
        noBeat += 1
        RefusalHaptic.play()
        withAnimation(.easeOut(duration: 0.26)) { drag = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            refused = false
        }
    }
}

// MARK: - Le triangle

/// Le triangle du play, aux coins adoucis — un triangle à angles vifs a l'air
/// d'un pictogramme, pas d'un objet laqué.
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = min(rect.width, rect.height) * 0.16
        let a = CGPoint(x: rect.minX, y: rect.minY)
        let b = CGPoint(x: rect.maxX, y: rect.midY)
        let c = CGPoint(x: rect.minX, y: rect.maxY)
        p.move(to: CGPoint(x: a.x, y: a.y + r))
        p.addArc(tangent1End: a, tangent2End: b, radius: r)
        p.addArc(tangent1End: b, tangent2End: c, radius: r)
        p.addArc(tangent1End: c, tangent2End: a, radius: r)
        p.closeSubpath()
        return p
    }
}

// MARK: - L'haptique du refus

/// LE REFUS DANS LA MAIN. L'app n'avait AUCUN retour d'erreur — ni `.error`,
/// ni `.warning`, ni `UINotificationFeedbackGenerator` parmi ses vingt-cinq
/// sites haptiques. Celui-ci est donc le premier, et il est écrit court
/// exprès : DEUX coups secs et rapprochés, la façon universelle de dire non.
/// Un coup unique se confond avec une validation ; une montée se confond avec
/// un chargement.
/// LA FIN DU SLIDE, DANS LA MAIN. Un `.sensoryFeedback(.impact)` seul est un
/// coup plat : il dit « touché », pas « ça y est ». Ce qu'il faut ici, c'est
/// une COURSE qui se termine — une montée courte, puis le heurt franc de
/// l'arrivée. Trois transitoires en 0,12 s : deux légers rapprochés qui
/// enflent, un net qui ferme.
///
/// Écrite à part plutôt que reprise de `SwapFeedback.shared.slam()` : le slam
/// est la signature de la carte qui quitte la pile, et deux gestes qui
/// tapent pareil finissent par se confondre dans la main.
enum CommitHaptic {
    static func play() {
        let soft = UIImpactFeedbackGenerator(style: .soft)
        let rigid = UIImpactFeedbackGenerator(style: .rigid)
        soft.prepare(); rigid.prepare()
        soft.impactOccurred(intensity: 0.45)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) {
            soft.impactOccurred(intensity: 0.72)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            rigid.impactOccurred(intensity: 1.0)
        }
    }
}

enum RefusalHaptic {
    static func play() {
        let gen = UIImpactFeedbackGenerator(style: .rigid)
        gen.prepare()
        gen.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            gen.impactOccurred(intensity: 0.7)
        }
    }
}
