import CoreMotion
import SwiftUI

/// Les PNG du chantier vivent en VRAC dans le bundle (Media/), pas dans
/// l'asset catalog : `Image(_:)` ne les trouve pas (Fault silencieux,
/// carte invisible). On charge par chemin, UNE fois par nom.
private func luneBundled(_ name: String) -> Image {
    guard let p = Bundle.main.path(forResource: name, ofType: "png"),
          let ui = UIImage(contentsOfFile: p)
    else { return Image(systemName: "questionmark.diamond") }
    return Image(uiImage: ui)
}

// MARK: - Banc de la carte-lune récompense (`-luneLab`)

/// Page noire nue : la première carte récompense, tenue en main virtuelle.
/// Deux illusions à juger d'un même geste :
///   — la FENÊTRE : le paysage glisse sous le cadre selon sa profondeur
///     (depth map dédiée) — le cadre est la vitre, il ne bouge pas ;
///   — le FOIL : balayage braise, poussière de diamants, liseré qui
///     accroche — le vocabulaire holo, sans l'arc-en-ciel cartoon.
/// Le doigt incline la carte (retour doux au relâcher) ; laissée seule,
/// elle se balance lentement. Sur iPhone, le gyroscope prend la main et
/// le balancement propre s'efface.
///
/// Sous-flags de capture (le pattern des bancs) :
///   `-luneTilt <tx,ty>` fige l'inclinaison — comparer deux tours de
///     fouettage au MÊME angle ;
///   `-luneStill` coupe le balancement propre (carte posée, foil au repos) ;
///   `-luneFlat` coupe la pose 3D — la parallaxe seule, cadre immobile :
///     c'est le SEUL moyen de mesurer sa direction sans que la perspective
///     pollue la règle ;
///   `-luneSmoke <âge>` fige l'expiration du contour à cet âge — la
///     fouetter image par image sans courir après le tap ;
///   `-luneGlow <gain>` règle le baiser du liseré sur la fumée (défaut
///     0,35 — les démons vivent à 1,55) ;
///   `-luneDive` rejoue la PLONGÉE en boucle (11 s de période) ;
///   `-luneDiveAt <t>` fige la plongée à cet âge (captures) ;
///   `-luneForgeNow` forge une carte au lancement (le test « GPT
///     répond ») ; `-luneForgeQualite low|medium|high` règle le peintre
///     (défaut HIGH — consigne Kathryn) ; `-luneForgeFamille <nom>`
///     force une famille (fouetter un registre, curer le pool) ;
///   `-luneForgeServeur` : le bouton passe par forge-card (le VRAI
///     flow — pool-ou-neuf, user de test) au lieu d'OpenAI en direct.
///
/// LA PLONGÉE (appui long) : la caméra passe la vitre — la carte grossit
/// jusqu'à sortir son cadre de l'écran, un chemin de caméra scripté prend
/// le relais du doigt, la parallaxe s'amplifie, la brume épaissit, les
/// braises montent de la vallée, la lune respire. Puis le monde repose la
/// carte. Huit secondes, aller-retour compris.
struct CarteLuneLab: View {
    private static let frozen: SIMD2<Float>? = {
        guard let raw = UserDefaults.standard.string(forKey: "luneTilt")
        else { return nil }
        let parts = raw.split(separator: ",").compactMap { Float($0) }
        guard parts.count == 2 else { return nil }
        return SIMD2(parts[0], parts[1])
    }()
    private static let still = CommandLine.arguments.contains("-luneStill")
    private static let flat = CommandLine.arguments.contains("-luneFlat")
    private static let smokeFreeze: Float? = UserDefaults.standard
        .string(forKey: "luneSmoke").flatMap(Float.init)
    private static let glow: Float = UserDefaults.standard
        .string(forKey: "luneGlow").flatMap(Float.init) ?? 0.35
    private static let diveAuto = CommandLine.arguments.contains("-luneDive")
    private static let diveFreeze: Float? = UserDefaults.standard
        .string(forKey: "luneDiveAt").flatMap(Float.init)
    private static let forgeNow = CommandLine.arguments.contains("-luneForgeNow")
    private static let forgeServeur = CommandLine.arguments.contains("-luneForgeServeur")

    /// La FORGE : la carte générée du moment remplace carte-lune-1 dans la
    /// même scène — même shader, même cadre, mêmes gestes. C'est le contrat
    /// du set rendu visible : seule l'illustration change.
    @State private var carte: LuneForge.Carte?
    @State private var chauffe = false
    @State private var forgeNote: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CarteVivante(frozen: Self.frozen, still: Self.still,
                         flat: Self.flat, smokeFreeze: Self.smokeFreeze,
                         glow: Self.glow, diveAuto: Self.diveAuto,
                         diveFreeze: Self.diveFreeze,
                         art: carte.map { Image(uiImage: $0.art) },
                         depth: carte.map { Image(uiImage: $0.depth) })
            VStack(spacing: 10) {
                Spacer()
                if let note = forgeNote {
                    Text(note)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.white.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 40)
                }
                Button(action: forger) {
                    HStack(spacing: 8) {
                        if chauffe { ProgressView().tint(.white.opacity(0.6)) }
                        Text(chauffe ? "la forge chauffe…" : "Forger une carte")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(chauffe ? 0.5 : 0.85))
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
                }
                .disabled(chauffe)
                .padding(.bottom, 26)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .task { if Self.forgeNow { forger() } }
    }

    private func forger() {
        guard !chauffe else { return }
        chauffe = true
        forgeNote = nil
        Task {
            do {
                let c: LuneForge.Carte
                if Self.forgeServeur {
                    // Le VRAI flow : forge-card décide pool-ou-neuf.
                    let jwt = try await ForgeServeur.jwtBanc()
                    c = try await ForgeServeur.tirer(
                        jwt: jwt,
                        famille: UserDefaults.standard
                            .string(forKey: "luneForgeFamille"))
                } else {
                    c = try await LuneForge.forger()
                }
                carte = c
                forgeNote = "\(c.famille.nom) · \(c.famille.rarete)"
                    + (Self.forgeServeur ? " · serveur" : "")
            } catch {
                forgeNote = "forge froide : \(error.localizedDescription)"
            }
            chauffe = false
        }
    }
}

// MARK: - Le gyroscope

/// La main réelle : l'attitude du téléphone, ramenée à un couple (tx, ty)
/// dans [-1, 1]. Le tangage neutre est CAPTURÉ au premier échantillon —
/// personne ne tient un téléphone à plat, le repos est la pose naturelle.
/// Au simulateur, aucun échantillon n'arrive : `live` reste faux et le
/// banc garde son balancement propre.
final class LuneMotion {
    static let shared = LuneMotion()
    private let mgr = CMMotionManager()
    private var pitchRef: Float?
    private var rollRef: Float?
    private(set) var live = false
    private(set) var tilt = SIMD2<Float>(0, 0)

    /// Le neutre se reprend à la pose de tenue ACTUELLE — appelé au
    /// montage d'une carte. Sans lui, le neutre daterait du premier
    /// écran de la vie du process (et le ROLL n'avait même pas de
    /// référence : une prise en main roulée penchait la carte juste
    /// après le raccord booster).
    func recalibrate() {
        pitchRef = nil
        rollRef = nil
    }

    func start() {
        guard mgr.isDeviceMotionAvailable, !mgr.isDeviceMotionActive
        else { return }
        mgr.deviceMotionUpdateInterval = 1.0 / 60.0
        mgr.startDeviceMotionUpdates(using: .xArbitraryZVertical,
                                     to: .main) { [weak self] m, _ in
            guard let self, let m else { return }
            let pitch = Float(m.attitude.pitch)
            let roll = Float(m.attitude.roll)
            if pitchRef == nil { pitchRef = pitch }
            if rollRef == nil { rollRef = roll }
            live = true
            let target = SIMD2(
                max(-1, min(1, (roll - (rollRef ?? 0)) * 2.0)),
                max(-1, min(1, (pitch - (pitchRef ?? 0)) * 2.0)))
            // Filtre doux : le poignet tremble, la carte non.
            tilt += (target - tilt) * 0.16
        }
    }
}

// MARK: - La scène

// MARK: - LA CARTE VIVANTE — le composant qu'on rebranche partout

/// « CarteVivante » : LE RÉSULTAT du chantier, en un seul composant.
/// Tout ce qui se voit au banc vit ICI : l'inclinaison au doigt (ou au
/// gyroscope, ou le balancement propre), le foil qui balaie, le tap qui
/// fait expirer la fumée du contour (+ haptique + poussière sonore), et
/// l'appui long qui PLONGE dans le monde de la carte.
///
/// LE CONTRAT DE REBRANCHEMENT (booster, collection, fin de séance…) :
///   CarteVivante(art: Image?, depth: Image?)  — c'est TOUT.
///   nil/nil → carte-lune-1 ; sinon l'art composé (cadre posé) et SA
///   depth. Le composant est autonome : gestes, sons, haptiques, 60 fps.
///   Les autres paramètres sont les flags de fouettage du banc
///   (-luneTilt, -luneStill, -luneDive…), tous facultatifs.
///
/// Sous le capot : 60 fps (la loi des cinématiques), inclinaison
/// FONCTION PURE DU TEMPS (le pattern du monolithe) — glissement pendant
/// le geste, retour exponentiel vers le balancement propre au relâcher,
/// rien ne s'accumule par image.
struct CarteVivante: View {
    var frozen: SIMD2<Float>? = nil
    var still = false
    var flat = false
    var smokeFreeze: Float? = nil
    var glow: Float = 0.35
    var diveAuto = false
    var diveFreeze: Float? = nil
    /// La carte FORGÉE du moment (art + depth) — nil : carte-lune-1.
    var art: Image? = nil
    var depth: Image? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var began = false
    @State private var dragging = false
    @State private var tiltAtGrab = SIMD2<Float>(0, 0)
    @State private var tiltLive = SIMD2<Float>(0, 0)
    @State private var releaseAt: Date = .distantPast
    @State private var releaseTilt = SIMD2<Float>(0, 0)
    /// LA CARESSE QUI ALLUME LE FOIL : frotter la carte fait monter une
    /// brillance (la bande, elle, suit déjà le doigt via le tilt), qui
    /// s'éteint en comète (~0,9 s) au relâcher — l'astiquage. Portée
    /// par le paramètre `foil` existant : l'ARITÉ du stitchable est
    /// soudée, on n'y touche pas (le piège de la page blanche).
    @State private var polish: Float = 0
    @State private var strokeAt: Date = .distantPast
    @State private var lastTrans: CGSize = .zero
    @State private var polishTickArmed = true
    /// Le dernier toucher : l'aura fait expirer le CONTOUR entier (le geste
    /// des démons) — pas de point de naissance, une seule date suffit.
    @State private var tapAt: Date = .distantPast
    /// La plongée en cours, s'il y en a une.
    @State private var diveStart: Date?

    /// La partition de la plongée : 1,4 s de traversée, un LONG voyage, et
    /// le retour amorcé à 8,4 s — dix secondes en tout (« trop timide » à
    /// huit : l'immersion se compte en temps passé dedans autant qu'en
    /// profondeur).
    private static let diveTotal: Float = 10.0
    private static let epoch = Date()

    private static func sstep(_ a: Float, _ b: Float, _ v: Float) -> Float {
        let t = max(0, min(1, (v - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    /// L'âge de la plongée, ou nil hors plongée. `-luneDiveAt` prime,
    /// `-luneDive` boucle sur une période de 11 s.
    private func diveAge(at date: Date) -> Float? {
        if let f = diveFreeze { return f }
        if diveAuto {
            let a = Float(date.timeIntervalSince(Self.epoch)
                .truncatingRemainder(dividingBy: 13.5))
            return a < Self.diveTotal ? a : nil
        }
        guard let s = diveStart else { return nil }
        let a = Float(date.timeIntervalSince(s))
        return (a >= 0 && a < Self.diveTotal) ? a : nil
    }

    /// L'enveloppe 0 → 1 → 0 de la plongée — fonction pure.
    private func diveEnv(at date: Date) -> Float {
        guard let a = diveAge(at: date) else { return 0 }
        return Self.sstep(0, 1.4, a) * (1 - Self.sstep(8.4, 10.0, a))
    }

    /// ~1 de course sur 150 pt de glissement.
    private static let tiltPerPoint: Float = 1.0 / 150.0
    /// Le doigt s'arrête où le balancement culmine : au-delà de ~0,7 la
    /// fenêtre n'a plus rien à donner et l'étirement se voit.
    private static let tiltLimit: Float = 0.7

    /// Le balancement propre : une Lissajous lente, deux périodes premières
    /// entre elles — la carte ne repasse jamais deux fois par le même chemin.
    private func sway(at date: Date) -> SIMD2<Float> {
        guard !still, !reduceMotion else { return .zero }
        let t = date.timeIntervalSinceReferenceDate
        return SIMD2(0.58 * Float(sin(t * 2 * .pi / 7.3)),
                     0.42 * Float(sin(t * 2 * .pi / 9.7 + 1.2)))
    }

    /// L'instant du montage — l'origine de l'éveil (rearmé à onAppear).
    @State private var mountAt = Date()

    /// L'ÉVEIL : au montage la carte part de PLAT et se met à respirer
    /// en ~2 s. Le raccord booster pose CarteVivante sur une carte
    /// scène parfaitement frontale — un premier frame incliné (phase
    /// arbitraire du sway, roll du gyro) serait LA couture. Le doigt et
    /// les poses figées du banc ne sont jamais atténués.
    private func wake(at date: Date) -> Float {
        let age = Float(date.timeIntervalSince(mountAt))
        guard age.isFinite, age >= 0, age < 8 else { return 1 }
        // TEMPS MORT 0,6 s : pendant le recouvrement du raccord (fondu
        // + extinction de la SCNView, ~0,55 s), la carte reste PLATE.
        // Un sway déjà éveillé au-dessus de la carte scène figée = une
        // double image qui tourne — LA couture (audit v5).
        return 1 - exp(-max(age - 0.6, 0) / 0.8)
    }

    /// La brillance de caresse à une date donnée : ce que le frottement
    /// a chargé, éteint en exponentielle — la comète.
    private func caresse(at date: Date) -> Float {
        let age = Float(date.timeIntervalSince(strokeAt))
        guard age.isFinite, age >= 0, age < 4 else { return 0 }
        return polish * exp(-age / 0.9)
    }

    /// L'inclinaison du DOIGT (ou du gyroscope, ou du balancement) à une
    /// date donnée — fonction pure.
    private func baseTilt(at date: Date) -> SIMD2<Float> {
        if let frozen { return frozen }
        if LuneMotion.shared.live {
            return dragging ? tiltLive
                : LuneMotion.shared.tilt * wake(at: date)
        }
        if dragging { return tiltLive }
        let age = Float(date.timeIntervalSince(releaseAt))
        let sw = sway(at: date)
        guard age.isFinite, age >= 0, age < 30 else {
            return sw * wake(at: date)
        }
        // Le relâcher rejoint le balancement : l'écart s'éteint, jamais
        // de saut — la carte reprend sa respiration où elle se trouve.
        let swAtRelease = sway(at: releaseAt)
        return (sw + (releaseTilt - swAtRelease) * exp(-2.6 * age))
            * wake(at: date)
    }

    /// L'inclinaison rendue : pendant la plongée, un CHEMIN DE CAMÉRA
    /// scripté prend le relais du doigt — lent, ample, il regarde vers
    /// l'horizon de braise. Le fondu se fait par l'enveloppe, jamais un
    /// saut : la caméra EMPRUNTE la carte au doigt puis la lui rend.
    private func tilt(at date: Date) -> SIMD2<Float> {
        let base = baseTilt(at: date)
        let env = diveEnv(at: date)
        guard env > 0, let a = diveAge(at: date) else { return base }
        // UNE dérive lente et MONOTONE : période plus longue que le voyage
        // (moins d'un demi-cycle), pas de changement de cap en route — la
        // caméra glisse, elle ne cherche pas. Trois vitesses qui se
        // composaient (chemin + course + dolly), c'était le « les éléments
        // bougent bizarrement » payé au banc.
        let ta = Double(a - 1.4)
        let path = SIMD2(
            Float(0.40 * sin(ta * 2 * .pi / 15.0)),
            Float(0.16 + 0.08 * sin(ta * 2 * .pi / 19.0 + 1.3)))
        return base * (1 - env) + path * env
    }

    /// La taille de la carte pour une scène donnée — UNE formule, partagée
    /// entre le rendu et la conversion du tap.
    static func cardSize(in scene: CGSize) -> CGSize {
        let w = min(scene.width - 46, 380)
        return CGSize(width: w, height: w * 1448.0 / 1086.0)
    }

    /// L'âge de l'expiration en cours (négatif = rien). `-luneSmoke` prime.
    private func auraAge(at date: Date) -> Float {
        if let forced = smokeFreeze { return forced }
        let a = Float(date.timeIntervalSince(tapAt))
        return (a.isFinite && a >= 0 && a < 1.7) ? a : -1
    }

    var body: some View {
        GeometryReader { geo in
            let cs = Self.cardSize(in: geo.size)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: frozen != nil && smokeFreeze != nil)) { tl in
                let tilt = tilt(at: tl.date)
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let dEnv = diveEnv(at: tl.date)
                let dAge = diveAge(at: tl.date) ?? 0
                // Le dolly de la plongée : il pousse pendant TOUT le
                // voyage et se replie avec l'enveloppe — jamais de saut.
                let dolly = Self.sstep(1.8, 8.0, dAge) * dEnv
                ZStack {
                    // PALIER 1 SOUVERAIN (verdict Kathryn : « plus
                    // naturel ») : une seule image, la fenêtre au pivot —
                    // le palier 2 multiplane est débranché, son pipeline
                    // attend le chantier full-IA.
                    // Le foil S'ALLUME à l'éveil (à foil 0 / tilt 0 le
                    // shader est l'identité — la bande dorée serait
                    // sinon PEINTE dès la première frame, pile sur la
                    // couture du raccord). Les poses figées du banc
                    // gardent leur foil plein.
                    // …et LA CARESSE par-dessus : l'astiquage pousse le
                    // foil au-delà de sa croisière (plafond 1,45 — plus
                    // haut, l'iridescence clippe en aplats).
                    CarteLuneCard(size: cs, tilt: tilt, t: t, dive: dEnv,
                                  dolly: dolly,
                                  foil: frozen != nil ? 1 : min(Self.sstep(
                                      0.15, 1.8,
                                      Float(tl.date.timeIntervalSince(mountAt)))
                                      + 0.7 * caresse(at: tl.date), 1.45),
                                  art: art, depth: depth)
                    // La pose 3D : la carte se penche VERS l'œil qui se
                    // déplace. Dans le monde elle s'amortit : la parallaxe
                    // raconte le voyage, la rotation ne fait qu'y vaciller.
                    .rotation3DEffect(.degrees(flat ? 0 : Double(tilt.y) * -7.5
                                               * (1 - Double(dEnv) * 0.75)),
                                      axis: (x: 1, y: 0, z: 0),
                                      perspective: 0.42)
                    .rotation3DEffect(.degrees(flat ? 0 : Double(tilt.x) * 10.5
                                               * (1 - Double(dEnv) * 0.75)),
                                      axis: (x: 0, y: 1, z: 0),
                                      perspective: 0.42)
                    // La traversée : la carte grossit jusqu'à sortir son
                    // cadre de l'écran DANS LES DEUX AXES (en hauteur il ne
                    // sort qu'à ×2,33 — payé au banc), puis le dolly
                    // continue de POUSSER doucement pendant tout le
                    // voyage : la caméra ne s'arrête jamais.
                    .scaleEffect(1.0 + 1.90 * CGFloat(dEnv)
                                 + 0.35 * CGFloat(dolly))
                    // L'aura NE TOURNE PAS avec la carte (la loi de la
                    // révélation) — et elle passe DEVANT : la marge noire de
                    // l'image est opaque, derrière elle serait mangée. Elle
                    // ne recouvre jamais l'art : le shader s'arrête au
                    // contour. Dans le monde, plus de contour : elle s'efface.
                    CarteLuneAura(cardSize: cs, t: t,
                                  age: auraAge(at: tl.date), glow: glow)
                        .opacity(Double(1 - dEnv))
                }
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .contentShape(Rectangle())
        // Glisser = incliner ; un relâcher quasi immobile = un tap, la
        // bouffée de fumée naît sous le doigt.
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !began {
                    began = true
                    tiltAtGrab = tilt(at: .now)
                }
                let travel = abs(v.translation.width) + abs(v.translation.height)
                if !dragging && travel > 10 {
                    dragging = true
                    lastTrans = v.translation
                }
                guard dragging else { return }
                let raw = tiltAtGrab + SIMD2(
                    Float(v.translation.width) * Self.tiltPerPoint,
                    Float(-v.translation.height) * Self.tiltPerPoint)
                tiltLive = SIMD2(
                    max(-Self.tiltLimit, min(Self.tiltLimit, raw.x)),
                    max(-Self.tiltLimit, min(Self.tiltLimit, raw.y)))
                // L'ASTIQUAGE : la vitesse du frottement charge la
                // brillance. Un petit toc feutré quand elle prend —
                // la carte ronronne sous le chiffon.
                let dPolish = Float(abs(v.translation.width - lastTrans.width)
                    + abs(v.translation.height - lastTrans.height))
                lastTrans = v.translation
                // On repart du poli DÉCRU (jamais du souvenir plein) :
                // la comète s'éteint, le chiffon la rallume.
                polish = min(caresse(at: .now) + dPolish * 0.0045, 1)
                strokeAt = .now
                if caresse(at: .now) > 0.75, polishTickArmed {
                    polishTickArmed = false
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred(intensity: 0.5)
                } else if caresse(at: .now) < 0.35 {
                    polishTickArmed = true
                }
            }
            .onEnded { _ in
                if dragging {
                    releaseTilt = tiltLive
                    releaseAt = .now
                } else if diveAge(at: .now) == nil {
                    // Un tap : le contour expire — où qu'on touche, c'est
                    // l'objet entier qui répond (le geste des démons).
                    // Le doigt sent l'air partir, la poussière tinte à
                    // peine. (Dans le monde, pas d'expiration : il n'y a
                    // plus de contour.)
                    tapAt = .now
                    LuneBreath.shared.exhale()
                    DustChime.shared.puff()
                }
                began = false
                dragging = false
            })
        // L'appui long ouvre la PLONGÉE — le geste des cartes immersives.
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.6)
            .onEnded { _ in
                guard !reduceMotion, diveAge(at: .now) == nil else { return }
                diveStart = .now
                LuneBreath.shared.dive()
            })
        .onAppear {
            mountAt = Date()
            // Le neutre gyro = la pose de tenue de CET écran.
            LuneMotion.shared.recalibrate()
            LuneMotion.shared.start()
            LuneBreath.shared.prepare()
            DustChime.shared.prepare()
        }
    }
}

// MARK: - La carte

/// Le rendu nu : l'image + le shader, SANS horloge — tout arrive en
/// paramètres. L'ARITÉ de l'appel est soudée à `carteLune` dans
/// CarteLune.metal : un paramètre de plus ou de moins et la page est
/// BLANCHE, sans une erreur de compilation.
struct CarteLuneCard: View {
    var size: CGSize
    var tilt: SIMD2<Float>
    var t: Float
    /// La plongée (0 → 1) : parallaxe amplifiée, foil éteint, braises,
    /// lune qui respire, vignette — tout est dans le shader.
    var dive: Float = 0
    /// Le dolly interne (0 → 1) : le zoom différentiel par profondeur —
    /// le lointain recule, le proche avance. La caméra qui voyage.
    var dolly: Float = 0
    /// Course de la parallaxe au fond du ciel, en points, à pleine
    /// inclinaison. Le `maxSampleOffset` doit la couvrir.
    var amp: Float = 13
    var foil: Float = 1
    /// Carte forgée : l'art et SA depth remplacent carte-lune-1 — le
    /// shader, lui, ne sait même pas que l'image a changé (le contrat).
    var art: Image? = nil
    var depth: Image? = nil

    private static let card = luneBundled("carte-lune-1")
    private static let depth = luneBundled("carte-lune-1-depth")

    var body: some View {
        (art ?? Self.card)
            .resizable()
            .frame(width: size.width, height: size.height)
            .layerEffect(Self.dithered(ShaderLibrary.carteLuneV5(
                .float2(size.width, size.height),
                .float2(CGFloat(tilt.x), CGFloat(tilt.y)),
                .float(t), .float(amp), .float(foil),
                .float(CGFloat(dive)), .float(CGFloat(dolly)),
                .image(depth ?? Self.depth))),
                maxSampleOffset: CGSize(width: 36, height: 30))
    }

    /// Dithering natif : casse le banding des rampes du ciel déplacé.
    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}

// MARK: - L'aura

/// L'hôte de `carteLuneAura` : l'expiration du contour au toucher, portée
/// des démons du coffre-fort. Un rectangle à MARGE autour de la carte (la
/// fumée a de quoi mourir avant le bord de son rectangle — une volute
/// coupée net se lit comme une plaque), qui ne tourne pas avec elle.
/// `demi`/`rayon` décrivent le liseré VISIBLE, pas l'image : la carte
/// occupe 0,772 × 0,883 de son PNG (mesuré), le contour part de là.
struct CarteLuneAura: View {
    var cardSize: CGSize
    var t: Float
    var age: Float
    var glow: Float

    static let marge: CGFloat = 110

    var body: some View {
        let w = cardSize.width + Self.marge * 2
        let h = cardSize.height + Self.marge * 2
        Rectangle()
            .fill(.white)
            .frame(width: w, height: h)
            .colorEffect(ShaderLibrary.carteLuneAura(
                .float2(w, h), .float(t),
                .float2(cardSize.width * 0.386, cardSize.height * 0.4417),
                .float(cardSize.width * 0.052),
                .float(CGFloat(age)), .float(CGFloat(glow))))
            .allowsHitTesting(false)
    }
}

// MARK: - Le monde (palier 2)

/// LA CAMÉRA MULTIPLANE — le secret des cartes immersives, et de Disney
/// avant elles : quatre plans réels découpés de l'illustration
/// (gen_layers.py : les bandes de la depth map + inpainting derrière
/// chaque plan), étagés, avec l'AIR entre eux (brume + braises, shader
/// `carteLuneAir`). La caméra scriptée les écarte (parallaxe vraie, sans
/// une déchirure) et AVANCE : le dolly grandit chaque plan selon sa
/// proximité — on entre dans la vallée.
///
/// Le monde apparaît PENDANT la traversée (fondu sur l'enveloppe) : à
/// dolly nul et décalages quasi nuls, sa pile coïncide avec l'art de la
/// carte — la couture est introuvable, on ne « charge » jamais un monde,
/// on le rejoint.
struct CarteLuneWorld: View {
    var cardSize: CGSize
    var tilt: SIMD2<Float>
    var t: Float
    var age: Float
    var env: Float

    private static let planes: [Image] = (0...3).map {
        luneBundled("carte-lune-L\($0)")
    }
    /// Profondeur de chaque plan (les bandes de la depth map, pivot 0,45)
    /// et son grandissement au dolly : le proche grossit plus vite — c'est
    /// l'avancée.
    private static let depths: [Float] = [1.00, 0.72, 0.50, 0.16]
    private static let grow: [CGFloat] = [0.02, 0.06, 0.12, 0.26]
    /// La course de parallaxe du monde, en points. Elle DÉMARRE calée sur
    /// celle de la fenêtre de la carte (~30 pt à l'instant du raccord —
    /// désaccordées, les deux ciels glissaient différemment et la
    /// traversée dédoublait l'image), puis s'élargit une fois le monde
    /// seul en scène : des vrais calques peuvent voyager loin.
    private func course(_ age: Float) -> CGFloat {
        // 34 au raccord = la course exacte de la fenêtre de la carte à cet
        // instant ; puis CONSTANTE à 42 dès la fin du raccord — une course
        // qui s'élargit pendant que le chemin tourne et que le dolly
        // pousse, c'est une vitesse de plus que l'œil ne sait pas lire.
        34 + 8 * CGFloat(Self.sstep(1.6, 2.4, age))
    }

    private static func sstep(_ a: Float, _ b: Float, _ v: Float) -> Float {
        let t = max(0, min(1, (v - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }

    var body: some View {
        // L'aire de l'art dans l'image de la carte (le crop de
        // gen_layers.py : x 0,127..0,872 · y 0,092..0,882), centrée avec
        // son léger décalage vertical.
        let artW = cardSize.width * (0.872 - 0.127)
        let artH = cardSize.height * (0.882 - 0.092)
        let artDY = cardSize.height * (((0.092 + 0.882) / 2) - 0.5)
        // Le dolly attend la fin du raccord : avancer pendant le fondu,
        // c'est écarter les deux images l'une de l'autre.
        let dolly = CGFloat(Self.sstep(1.8, 6.2, age))
        ZStack {
            plane(0, dolly: dolly)
            plane(1, dolly: dolly)
            plane(2, dolly: dolly)
            // UN seul air (le proche) : le lointain coûtait un plein écran
            // de bruit par image pour un voile à peine lisible.
            air(band: 1, artW: artW, artH: artH)
            plane(3, dolly: dolly)
            // La vignette du monde : le regard tenu au centre.
            RadialGradient(colors: [.clear, .black.opacity(0.38)],
                           center: .center,
                           startRadius: artW * 0.42,
                           endRadius: artW * 0.95)
        }
        .frame(width: artW, height: artH)
        .clipped()
        .offset(y: artDY)
        // Le monde n'apparaît que CADRE DÉJÀ HORS ÉCRAN — dans les DEUX
        // axes (en hauteur, il ne sort qu'à ×2,33 soit env ≈ 0,70) : le
        // raccord se joue entre deux images quasi identiques, courtes
        // fenêtres symétriques à l'aller et au retour — jamais de cadre
        // fantôme (la « transition bizarre » payée au banc, deux fois).
        .opacity(Double(Self.sstep(0.74, 0.90, env)))
        .allowsHitTesting(false)
    }

    private func plane(_ i: Int, dolly: CGFloat) -> some View {
        // Le lointain suit l'œil (le signe payé au banc sur la fenêtre) ;
        // le proche va à contre-sens. Le sur-balayage est quasi NUL au
        // raccord — à 1,14 dès l'entrée, le monde arrivait 14 % plus
        // grand que la carte et le fondu POPPAIT (payé au banc) ; il
        // s'installe une fois seul en scène, quand les courses s'ouvrent.
        let k = CGFloat(Self.depths[i] - 0.45)
        let c = course(age)
        let over = 1.02 + 0.12 * CGFloat(Self.sstep(1.6, 3.2, age))
        let dx = -CGFloat(tilt.x) * k * c
        let dy = -CGFloat(tilt.y * 0.72) * k * c
        return Self.planes[i]
            .resizable()
            .scaledToFill()
            .scaleEffect(over + dolly * Self.grow[i])
            .offset(x: dx, y: dy)
    }

    private func air(band: Float, artW: CGFloat, artH: CGFloat) -> some View {
        Rectangle()
            .fill(.white)
            .frame(width: artW, height: artH)
            .colorEffect(ShaderLibrary.carteLuneAir(
                .float2(artW, artH), .float(t),
                .float(CGFloat(env)), .float(CGFloat(band))))
            .scaleEffect(1.2)
    }
}

#Preview { CarteLuneLab() }
