import SwiftUI

// MARK: - Le player TAPIS — deux pastilles, le chrono qui se tape
//
// Plan : tools/tapis/PLAN-TAPIS-HIIT.md (§2 machine à états, §3 anatomie).
// J0 : la scène seule au banc (`-tapisLab`). Le panneau vitesse (J1), la
// notif + pop-up flammes (J2), le fond de braise (J2) et la fiche (J3)
// viennent après.
//
// LA COMPOSITION EST LOCALE, PAS UNE EXTRACTION : `nightLens` du parcours
// muscu lit l'état d'instance de LiquidLensLab (restStart, envolAt) — on ne
// l'arrache pas. Les shaders `liquidLens` / `eclipseGlow` sont d'app
// (ShaderLibrary) : on les rappelle ici avec notre propre géométrie, et le
// parcours muscu n'est pas touché (zéro régression possible).
//
// Chaque pastille vit dans SON cadre local (~270 pt) avec son propre fond
// et son `layerEffect` — jamais un layerEffect plein écran par pastille
// (deux rééchantillonnages plein cadre par image seraient le prix ; ici le
// verre ne paie que son carré).
//
// TOUT EST FONCTION PURE DU TEMPS (la loi de LiquidLensLab) : l'arrivée,
// le pouls, l'alternance et le pulse de la phrase dérivent de dates-ancres
// (`naissance`, `setDebut`, `reposDebut`) — jamais un `withAnimation` sur
// un état, jamais une accumulation. Le chrono survit à l'arrière-plan.

// MARK: - L'état de la séance tapis

/// L'état vivant du mode tapis — UN observable, jamais des @State éparpillés
/// sur la page (la fiche porte déjà vidéos et shaders : l'Observation ne
/// réveille que les vues qui lisent).
@MainActor @Observable
final class SeanceTapis {
    enum Etat { case court, repos }

    /// L'instant où les pastilles ARRIVENT (l'ancre de toute la scène).
    let naissance: Date
    private(set) var etat: Etat = .court
    /// Le rang du set en cours (1-based).
    private(set) var setIndex = 1
    /// Les sets terminés — le pilote du fond de braise (J2) et du crescendo.
    private(set) var setsFaits = 0
    /// L'ancre du chrono du set en cours. Le set 1 part tout seul À LA POSE
    /// des pastilles : l'ancre est posée d'avance, le chrono clampe à zéro.
    private(set) var setDebut: Date?
    /// L'ancre du repos (l'entre-sets affiche le temps écoulé, pas un compte).
    private(set) var reposDebut: Date?
    /// Le km/h courant — la molette (J1) écrira ici ; la phase (J2) le lira.
    var vitesse: Double = 0

    /// La durée de l'arrivée : le set 1 démarre quand les pastilles se posent.
    static let arrivee: Double = 0.85

    init(naissance: Date = .now, figee: Bool = false, setsFaits: Int = 0) {
        // Figée (banc) : née posée, l'arrivée est déjà passée.
        self.naissance = figee ? naissance.addingTimeInterval(-30) : naissance
        self.setsFaits = setsFaits
        self.setIndex = setsFaits + 1
        self.setDebut = self.naissance.addingTimeInterval(Self.arrivee)
    }

    /// Le tap sur la pastille chrono pendant l'effort : le set est FAIT.
    /// (J2 : c'est ici que la CardioPhase s'écrit et que la fête part.)
    func stopper(_ now: Date = .now) {
        guard etat == .court else { return }
        etat = .repos
        setsFaits += 1
        setDebut = nil
        reposDebut = now
    }

    /// Le tap sur la pastille chrono au repos : le set suivant part.
    func relancer(_ now: Date = .now) {
        guard etat == .repos else { return }
        etat = .court
        setIndex = setsFaits + 1
        setDebut = now
        reposDebut = nil
    }
}

// MARK: - La scène

struct TapisScene: View {
    var seance: SeanceTapis
    /// La fin de session (le slider « Finish » commet — tranché §10.1).
    var onFinish: () -> Void = {}
    /// BANC : les horloges clouées à cet instant après la naissance.
    var tempsFige: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                // La scène vivante : tout ce qui dérive de l'horloge vit sous
                // CE TimelineView — de l'extérieur (la fiche, au J3), la
                // scène entière est la feuille : rien au-dessus ne s'invalide.
                TimelineView(.animation(minimumInterval: 1 / 60)) { tl in
                    vivante(w: w, h: h, now: date(tl.date))
                }
                zonesTactiles(w: w, h: h)
                pied(w: w, h: h)
            }
        }
    }

    /// L'horloge du banc : `-tapisT` cloue tout à naissance + t.
    private func date(_ d: Date) -> Date {
        guard let t = tempsFige else { return d }
        return seance.naissance.addingTimeInterval(t)
    }

    // MARK: la scène vivante (fonction pure de `now`)

    private func vivante(w: CGFloat, h: CGFloat, now: Date) -> some View {
        let age = now.timeIntervalSince(seance.naissance)
        let t = age
        // L'ARRIVÉE — deux courbes en miroir, l'école nightLens : e2 lissé,
        // l'étirement suit la vitesse et meurt à la pose.
        let u = min(max(age / SeanceTapis.arrivee, 0), 1)
        let e2 = u * u * (3 - 2 * u)
        let vel = 6 * u * (1 - u)
        let squash = 1 - 0.10 * min(vel / 1.5, 1) * (1 - sstep(0.85, 1.0, u))
        let landed = age - SeanceTapis.arrivee
        // Le rebond de la pose (les deux oscillations lisibles).
        let rebond = landed > 0 ? 2.6 * sin(landed * 2.1) * exp(-landed * 1.1) : 0
        let ig = Float(sstep(0.0, 0.8, max(landed, 0)))
        // La braise : vive pendant la chute, braise de veille une fois posée.
        let fall = 0.24 * (1 - sstep(0.0, 1.2, max(landed, 0)))
        let veille = (0.11 + 0.05 * sin(t * 0.9)) * sstep(0.6, 1.6, max(landed, 0))
        let ember = Float(min(max(fall, veille), 1.0))

        let yChrono = h * 0.335
        let yVitesse = h * 0.695
        // Les offsets d'entrée : le chrono perce le bord haut, la vitesse le
        // bord bas — des offsets, jamais une taille animée.
        let offChrono = (1 - CGFloat(e2)) * -(yChrono + 180) + CGFloat(rebond)
        let offVitesse = (1 - CGFloat(e2)) * (h - yVitesse + 180) - CGFloat(rebond)

        return ZStack {
            pastilleChrono(now: now, t: t, ig: ig, ember: ember,
                           squash: squash, landed: landed)
                .position(x: w / 2, y: yChrono)
                .offset(y: offChrono)
            pastilleVitesse(t: t, ig: ig, ember: ember, squash: squash)
                .position(x: w / 2, y: yVitesse)
                .offset(y: offVitesse)
            // L'encre de la page (phrase, légende) vit AU-DESSUS des
            // pastilles, zIndex OBLIGATOIRE : le `layerEffect` peint jusqu'à
            // `maxSampleOffset` (110 pt) AU-DELÀ de son cadre — sans zIndex,
            // ce halo de calque couvrait la phrase ET la légende (mesuré sur
            // capture, 31-08 : les deux textes à zéro pixel).
            phrase(now: now)
                .position(x: w / 2, y: h * 0.115)
                .zIndex(10)
            legende
                .position(x: w / 2, y: h * 0.545)
                .opacity(sstep(0.5, 1.0, u))
                .zIndex(10)
        }
        .allowsHitTesting(false)
    }

    // MARK: la phrase (« Tap to stop » / « Tap to start »)

    /// Le pulse est une fonction de l'horloge — jamais un `repeatForever`
    /// d'état (avalé quand un parent se ré-évalue, payé 2× sur PageCard).
    private func phrase(now: Date) -> some View {
        let texte = seance.etat == .court ? "Tap to stop" : "Tap to start"
        let t = now.timeIntervalSince(seance.naissance)
        let pulse = 0.32 + 0.58 * (0.5 - 0.5 * cos(t * 2 * .pi / 2.6))
        let entree = sstep(SeanceTapis.arrivee * 0.7,
                           SeanceTapis.arrivee + 0.4, t)
        return Text(texte)
            .font(.inter(20, .semibold))
            .foregroundStyle(Self.encreApple)
            .opacity(pulse * entree)
    }

    private var legende: some View {
        Text("select km/h")
            .font(.inter(13, .medium))
            .tracking(1.4)
            .foregroundStyle(Color.white.opacity(0.45))
    }

    // MARK: la pastille CHRONO

    private func pastilleChrono(now: Date, t: Double, ig: Float,
                                ember: Float, squash: Double,
                                landed: Double) -> some View {
        // LE POULS DE LA SECONDE (l'école nightLens : attaque 0,10 s, la
        // somme one(ph)+one(ph+1) traverse la bascule sans pop au wrap) —
        // calé sur l'ancre du set : la pastille bat quand la seconde tombe.
        var pulse = 0.0
        if seance.etat == .court, let d0 = seance.setDebut,
           now.timeIntervalSince(d0) > 0 {
            let ph = now.timeIntervalSince(d0)
                .truncatingRemainder(dividingBy: 1.0)
            func one(_ x: Double) -> Double {
                x <= 0 ? 0 : sstep(0, 0.10, x) * exp(-max(x - 0.10, 0) / 0.30)
            }
            pulse = one(ph) + one(ph + 1.0)
        }
        return lentille(cote: Self.coteChrono, t: t, ig: ig, ember: ember,
                        squash: squash, pulse: pulse)
            .overlay(encreChrono(now: now))
    }

    /// L'encre du cadran : caption + chrono, et l'ALTERNANCE ⏹ (tranché
    /// 31-08 : les 2 premiers sets de la séance seulement, puis extinction ;
    /// le glyphe et le chrono se croisent sur LA MÊME horloge que le compte).
    private func encreChrono(now: Date) -> some View {
        let court = seance.etat == .court
        let elapsed: Int = {
            guard court, let d0 = seance.setDebut else { return 0 }
            return max(0, Int(now.timeIntervalSince(d0)))
        }()
        // L'alternance : toutes les 3 s, une fenêtre de 0,6 s pour ⏹.
        var g = 0.0
        if court && seance.setIndex <= Self.setsAvecAlternance,
           let d0 = seance.setDebut {
            let ph = max(0, now.timeIntervalSince(d0))
                .truncatingRemainder(dividingBy: 3.0)
            g = sstep(2.40, 2.55, ph) * (1 - sstep(2.85, 3.0, ph))
        }
        let repos = seance.reposDebut.map {
            max(0, Int(now.timeIntervalSince($0)))
        }
        return VStack(spacing: 6) {
            Text(court ? "SET \(seance.setIndex)"
                       : "REST \(chrono(repos ?? 0))")
                .font(.inter(12, .semibold))
                .tracking(3.0)
                .foregroundStyle(Color.white.opacity(0.50))
            ZStack {
                if court {
                    Text(chrono(elapsed))
                        .font(.inter(46, .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.92))
                        .opacity(1 - g)
                    glyphe("stop.fill", corps: 40)
                        .opacity(g)
                } else {
                    glyphe("play.fill", corps: 44)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: la pastille VITESSE

    private func pastilleVitesse(t: Double, ig: Float, ember: Float,
                                 squash: Double) -> some View {
        // Ses halos vivent au RALENTI (t × 0,45) : elle veille, elle ne
        // respire pas — la première marche de dégradation si la cadence
        // du duo tombe (§8 du plan), déjà à moitié prise.
        lentille(cote: Self.coteVitesse, t: t * 0.45, ig: ig, ember: ember,
                 squash: squash, pulse: 0)
            .overlay(encreVitesse)
    }

    private var encreVitesse: some View {
        VStack(spacing: 4) {
            Text(seance.vitesse.formatted(
                .number.precision(.fractionLength(1))))
                .font(.inter(44, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.92))
            Text("km/h")
                .font(.inter(12, .semibold))
                .tracking(2.4)
                .foregroundStyle(Color.white.opacity(0.50))
        }
        .allowsHitTesting(false)
    }

    // MARK: la lentille (le verre commun aux deux pastilles)

    /// Le carré local d'une pastille : son fond (noir + halos eclipseGlow +
    /// grain), compacté puis réfracté par `liquidLens` — les MÊMES shaders
    /// que le cadran muscu, la géométrie en moins de voyages : le centre est
    /// fixe, le verre ne paie que son carré (jamais un layerEffect plein
    /// écran par pastille).
    private func lentille(cote: CGFloat, t: Double, ig: Float, ember: Float,
                          squash: Double, pulse: Double) -> some View {
        let c = Float(cote / 2)
        let rayon = Float(cote * 0.36)
        let lens = ShaderLibrary.liquidLens(
            .float2(Float(cote), Float(cote)), .float2(c, c), .float(rayon),
            .float(0.72), .float(0.12), .float(ember),
            .float(Float(squash)), .float(1.0), .float(Float(t)),
            .float(0.0), .float(0.0), .float(0.0), .float(0.66),
            .float(0.0), .float(0.0), .float(Float(pulse)), .float(ig))
        let glow = ShaderLibrary.eclipseGlow(
            .float2(Float(cote), Float(cote)), .float2(c, c), .float(rayon),
            .float(Float(t)), .float(ig), .float(Float(pulse)),
            .float(0.0), .float(0.0))
        return ZStack {
            Color.black
            // La nappe du glow vaut encore ~50 % au bord du cadre local
            // (exp(-(r/1,55R)²), mesuré dans le shader) : sans ce masque
            // radial elle se COUPE AU CARRÉ — la loi des démarcations. Le
            // masque est statique, sur du SwiftUI (jamais sur une vidéo).
            Rectangle().fill(.white).colorEffect(glow)
                .mask(RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white, location: 0.44),
                        .init(color: .clear, location: 0.86)]),
                    center: .center, startRadius: 0, endRadius: cote / 2))
            WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
        }
        .frame(width: cote, height: cote)
        .compositingGroup()
        .layerEffect(lens, maxSampleOffset: CGSize(width: 110, height: 110))
    }

    // MARK: les zones tactiles

    /// Les taps vivent HORS du TimelineView (des cibles fixes : rien à
    /// ré-évaluer par image) et en `highPriorityGesture` — jamais un
    /// `Button` : un drag d'ancêtre (le tirage PageCard, au J3) l'annulerait
    /// à 2 pt de tremblement (loi WorkoutPill).
    private func zonesTactiles(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Color.clear
                .frame(width: Self.coteChrono, height: Self.coteChrono)
                .contentShape(Circle())
                .highPriorityGesture(TapGesture().onEnded { tapChrono() })
                .position(x: w / 2, y: h * 0.335)
            Color.clear
                .frame(width: Self.coteVitesse, height: Self.coteVitesse)
                .contentShape(Circle())
                .highPriorityGesture(TapGesture().onEnded { tapVitesse() })
                .position(x: w / 2, y: h * 0.695)
        }
    }

    private func tapChrono() {
        switch seance.etat {
        case .court: seance.stopper()
        case .repos: seance.relancer()
        }
    }

    /// J1 : le panneau vitesse (raccourcis + grosse molette). Au banc, en
    /// attendant, le tap fait tourner des vitesses de démonstration.
    private func tapVitesse() {
        guard TapisBanc.actif else { return }
        let demo: [Double] = [0, 7, 12, 17]
        let i = demo.firstIndex(of: seance.vitesse) ?? 0
        seance.vitesse = demo[(i + 1) % demo.count]
    }

    // MARK: le pied

    private var piedValide: Bool { true }

    private func pied(w: CGFloat, h: CGFloat) -> some View {
        SliderObsidienne(label: "Finish", height: 62,
                         labelCentre: true,
                         validate: { piedValide },
                         onConfirm: onFinish)
            .padding(.horizontal, 20)
            .frame(width: w)
            .position(x: w / 2, y: h - 78)
    }

    // MARK: constantes et outils

    /// L'alternance chrono ⇄ ⏹ ne joue que sur les premiers sets (tranché
    /// 31-08 : un tutoriel, pas un état — réglable ici, au banc).
    private static let setsAvecAlternance = 2
    private static let coteChrono: CGFloat = 280
    private static let coteVitesse: CGFloat = 250

    /// Le blanc dégradé « très Apple » de la maison (titres de rewards).
    private static let encreApple = LinearGradient(
        colors: [Color.white.opacity(0.95), Color.white.opacity(0.55)],
        startPoint: .top, endPoint: .bottom)

    private func glyphe(_ nom: String, corps: CGFloat) -> some View {
        Image(systemName: nom)
            .font(.system(size: corps, weight: .bold))
            .foregroundStyle(Self.encreApple)
    }

    private func chrono(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        guard b > a else { return x < a ? 0 : 1 }
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }
}
