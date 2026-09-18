import SwiftUI
import UIKit

// MARK: - Le slider de validation — LE MÉDAILLON  ⚠️ ARCHIVÉ (22-08)
//
// PLUS AUCUN APPELANT. Son unique site — la feuille de saisie de série
// (`SetEntrySheet`) — est passé à `SliderObsidienne`, celui de la home :
// « archive notre slider dans l'overlay pour ajouter les reps et mets celui
// de la home pour consistance ». Deux sliders de validation dans la même
// app, c'était deux grammaires pour le même geste.
//
// Il dort ici comme dorment `ExerciseSetupCard` et `NotchedCard` : rien
// n'est perdu, tout est mesuré, et le jour où une cérémonie mérite un
// médaillon braise plutôt qu'un geste noir, il est prêt. Ne pas le croire
// vivant : le fouetter ne changera plus un pixel à l'écran.

/// LE GESTE QUI ENGAGE, recalé sur la référence de Kathryn
/// (~/Downloads/woop-galet/ref.png). Un CTA se tape sans y penser ; une série
/// qu'on enregistre et un repos qu'on lance méritent qu'on les POUSSE.
///
/// CE QUE LA RÉFÉRENCE COMMANDE, mesuré au pixel :
///   — le pouce est un MÉDAILLON qui CHEVAUCHE la piste (il déborde en haut
///     et en bas, serti dans sa gorge), jamais un galet inscrit ;
///   — son anneau est un TUBE néon chaud EN BAS, au point chaud qui ORBITE —
///     et sa rotation ACCÉLÈRE avec la course (verdict de Kathryn) ; la
///     phase est ACCUMULÉE (monotone, jamais un facteur sur t — la leçon
///     timeBoost de MoonCoin, sinon la phase saute) ;
///   — une COURONNE DE PERLES intérieure, devenue JAUGE : elles s'allument
///     une à une avec la poussée, depuis le bas ;
///   — le triangle play est TRACÉ (contour néon), pas rempli ;
///   — le fil de la piste est DOUBLE (argent dedans, or dehors) et il est
///     ÉCLAIRÉ : l'or suit le médaillon le long de la course ;
///   — la poussière du drag est BLANCHE et PRÉCIEUSE — des grains qui
///     scintillent, semés à la distance parcourue, plus jamais de fumée.
///
/// LE ZOOM EST MORT (verdict de Kathryn : « enlève le zoom »). Ce qui reste
/// du canal caméra est devenu COULEUR : `onMood` (saisie × course, la même
/// formule, RÉVERSIBLE par construction — dé-draguer la fait redescendre
/// d'elle-même) et le panneau s'embrase avec la course : blanc chaud,
/// jaune, orange, rouge. La main reçoit le reste : un grondement continu
/// qui enfle avec la poussée (le moteur de la lentille) et un CRAN par
/// perle de couronne franchie. Et sur la piste, la poussière s'est vue
/// rejoindre par une vingtaine de MICRO-DIAMANTS taillés, froids sur la
/// braise.
///
/// LE REFUS reste un état : la piste et le tube virent au grenat sourd, la
/// couronne s'éteint, le mood retombe SEC — et la main reçoit le double
/// coup. Rien de tout cela n'existe nulle part ailleurs dans l'app.
struct GaletSlide: View {
    var label: String = "Glisser pour lancer le repos"
    /// La validation. Rend `true` si tout est en règle : le pouce va au bout
    /// et `onConfirm` part. Rend `false` et c'est le refus qui se joue.
    var validate: () -> Bool = { true }
    /// Le mood, 0 → 1 : ce que le panneau lit pour S'EMBRASER (saisie ×
    /// course) — l'ex-canal caméra, recyclé en couleur.
    var onMood: (CGFloat) -> Void = { _ in }
    var onConfirm: () -> Void

    @State private var drag: CGFloat = 0
    @State private var dragging = false
    /// La saisie LISSÉE — le mood et le tube ne claquent pas à la prise.
    @State private var grip: CGFloat = 0
    /// LA PHASE DU TUBE : accumulée frame par frame, jamais recalculée d'un
    /// facteur — elle ne peut qu'avancer, de plus en plus vite avec la course.
    @State private var rot: Double = 0
    @State private var lastFrame: Date?
    @State private var refused = false
    @State private var okBeat = 0
    @State private var flashAt: Date = .distantPast
    /// LA POUSSIÈRE. Semée à la distance parcourue, jamais au temps.
    @State private var dusts: [Dust] = []
    @State private var lastDustX: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Dust: Identifiable {
        let id = UUID()
        let born: Date
        let x: CGFloat
        let y: CGFloat
        /// La vitesse héritée du pouce — la poussière reste DERRIÈRE.
        let vx: CGFloat
        let rise: CGFloat
        let size: CGFloat
        /// Le scintillement : chaque grain a sa fréquence et sa phase.
        let freq: Double
        let phase: Double
        /// Une pointe d'or au grain qui vient de naître près du tube.
        let gold: Bool
    }

    /// LES MICRO-DIAMANTS : une vingtaine au plus, froids et TAILLÉS —
    /// quatre branches fines, un cœur vif — semés à la distance comme la
    /// poussière mais plus rares. Le froid sur la braise : c'est lui qui
    /// fait « précieux ».
    struct Diamond: Identifiable {
        let id = UUID()
        let born: Date
        let x: CGFloat
        let y: CGFloat
        let vx: CGFloat
        let rise: CGFloat
        /// La demi-longueur des branches, en points.
        let ray: CGFloat
        let freq: Double
        let phase: Double
        /// L'assiette de la croix — chaque pierre est sertie de biais.
        let tilt: Double
    }
    @State private var gems: [Diamond] = []
    @State private var lastGemX: CGFloat?
    /// La dernière perle franchie — le cran haptique ne tape qu'au passage.
    @State private var lastPearl = 0
    /// L'odomètre du son : Paillettes se nourrit de CHAQUE déplacement —
    /// un traqueur à part, le seuil de la poussière ne le concerne pas.
    @State private var lastSoundX: CGFloat?

    /// LA TRACE QUI REFROIDIT : là où le doigt passe, le sol garde une
    /// braise ~1 s — blanc-chaud à la naissance, rouge sombre à la mort.
    struct Ember: Identifiable {
        let id = UUID()
        let born: Date
        let x: CGFloat
        let y: CGFloat
        let r: CGFloat
    }
    @State private var embers: [Ember] = []
    @State private var lastEmberX: CGFloat?

    private static let dustLife: Double = 0.9
    private static let gemLife: Double = 1.15
    private static let emberLife: Double = 1.0

    /// `-galetFreeze <p>` : la POSE du slider — pouce à p, saisie pleine,
    /// gestes coupés. Le simulateur ne drague pas : c'est la seule façon de
    /// capturer la course, l'or qui voyage et la couronne à mi-jauge.
    private static let frozen: CGFloat? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-galetFreeze"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return CGFloat(min(max(v, 0), 1))
    }()

    /// `-galetAuto` : LE FILM du geste, en boucle de 6,5 s — poussée, tenue,
    /// dé-drag (le mood doit redescendre de lui-même), relâcher-ressort,
    /// silence. La poussière, les diamants, la rotation accélérée et
    /// l'embrasement ne se jugent qu'en mouvement.
    private static let cycling = CommandLine.arguments.contains("-galetAuto")

    /// La course du doigt synthétique — fonction pure du temps.
    private static func autoP(_ t: Double) -> (p: CGFloat, grip: Bool) {
        let tau = t.truncatingRemainder(dividingBy: 6.5)
        func ss(_ a: Double, _ b: Double, _ x: Double) -> Double {
            let u = min(max((x - a) / (b - a), 0), 1)
            return u * u * (3 - 2 * u)
        }
        switch tau {
        case ..<0.6: return (0, false)
        case ..<2.9: return (CGFloat(0.93 * ss(0.6, 2.9, tau)), true)
        case ..<3.4: return (0.93, true)
        case ..<4.4: return (CGFloat(0.93 - 0.58 * ss(3.4, 4.4, tau)), true)
        default:
            // Le ressort du relâcher : retombée amortie depuis 0,35.
            let e = tau - 4.4
            return (CGFloat(max(0.35 * exp(-6.0 * e) * cos(5.2 * e), 0)),
                    false)
        }
    }

    private let height: CGFloat = 70
    private let inset: CGFloat = 8
    /// Le médaillon déborde la piste comme la réf — 73 pt donnaient un
    /// anneau de ~90, « réduis un peu le gros bouton » (verdict Kathryn,
    /// round 6) le ramène à 68 pt : anneau ~84, le débord respire encore.
    private let medal: CGFloat = 68
    /// L'EMBOÎTEMENT (verdict jury) : au repos, l'anneau vit DANS la pilule
    /// — un liseré de piste reste visible à sa gauche, comme la réf. L'ancre
    /// ne descend donc jamais sous ce seuil.
    private var axPad: CGFloat { medal * 1.9 * 0.652 / 2 + 6 }

    /// LE GRENAT DU REFUS — la densité de l'obsidienne, pas une alerte.
    private static let garnet = Color(red: 0.62, green: 0.13, blue: 0.16)
    /// L'argent chaud du fil intérieur — mesuré sur la réf : (110,100,90).
    private static let silver = Color(red: 0.43, green: 0.39, blue: 0.35)
    /// L'or du fil extérieur — mesuré aux bouts de la réf : (132,109,90).
    private static let gold = Color(red: 1.0, green: 0.72, blue: 0.38)
    /// L'or sourd des DEUX BOUTS, plus terreux que le fil du pouce.
    private static let bout = Color(red: 0.86, green: 0.51, blue: 0.20)

    /// LA LUMIÈRE D'UN BOUT — un dégradé radial, la seule douceur qui ne
    /// coûte ni flou (LE CALQUE) ni bord franc (les ANNEAUX). Posée à cheval
    /// sur la calotte, elle en éclaire la courbe et déborde dehors.
    // LES HALOS DE LA PISTE SONT DES LISERÉS, PAS DES FLOUS ni des lueurs
    // rondes : `.blur` peint LE CALQUE (voile uniforme sur tout le rectangle
    // de l'hôte), une échelle de liserés fait des ANNEAUX, et une lueur
    // radiale posée dans le corps fait GROSSIR la pilule. Ce qui reste — un
    // trait dont la teinte s'éteint — est ce qui tient les trois verdicts.

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let travel = max(W - axPad * 2, 1)
            let pAuto: CGFloat? = Self.cycling
                ? Self.autoP(Date.now.timeIntervalSinceReferenceDate).p : nil
            let p = Self.frozen ?? pAuto ?? min(max(drag / travel, 0), 1)
            // L'ancre : le centre du médaillon, borné pour que l'anneau
            // reste emboîté dans la pilule aux deux bouts.
            let ax = axPad + p * travel
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let now = tl.date
                let flash = max(0, 1 - now.timeIntervalSince(flashAt) / 0.4)
                ZStack {
                    track(W: W, p: p, ax: ax, flash: flash)
                        .frame(width: W, height: height)
                        // LA SCÈNE — le sol sous le geste (GaletStage.metal)
                        // en BACKGROUND : ses 170 pt débordent la piste sans
                        // peser dans le layout (un hôte plus haut dans la
                        // pile poussait tout le slider de 50 pt vers le bas,
                        // coupé par le bas d'écran — payé au round 6).
                        // PAS DE BLEND MODE ICI — c'était LE CALQUE
                        // (« on voit un calque derrière le slider ») : un
                        // `plusLighter` posé dans la couche du Liquid Glass
                        // du panneau force un groupe de composition, et le
                        // verre se redessine SUR le rectangle de l'hôte —
                        // mesuré au pixel : une dalle claire de 362 × 70 pt
                        // aux coins CARRÉS autour de la pilule. Sur une
                        // piste quasi noire, le simple par-dessus rend la
                        // même lumière (le shader sort déjà prémultiplié).
                        .background {
                            stage(t: now, p: p, ax: ax, W: W, flash: flash)
                                .frame(width: W, height: 170)
                                .allowsHitTesting(false)
                        }
                        // La poussière déborde elle aussi la piste (170 pt)
                        // — en OVERLAY pour la même raison : zéro emprise.
                        .overlay {
                            dust(now: now)
                                .frame(width: W, height: 170)
                        }
                    // LE MÉDAILLON — hôte CONSTANT (le zoom est mort) : le
                    // shader normalise tout par `size`, le rendu est celui
                    // du repos, au pixel. +2,5 pt : recentré sur l'axe
                    // optique de la piste (verdict jury — le bloom bas
                    // alourdit la lecture).
                    medallion(t: now, p: p, flash: flash)
                        .frame(width: medal * 1.9, height: medal * 1.9)
                        .position(x: ax, y: height / 2 + 2.5)
                        .allowsHitTesting(false)
                    // La prise : le disque du médaillon, rien d'autre — la
                    // piste n'est pas un tapis à doigt.
                    Circle()
                        .fill(Color.clear)
                        .frame(width: medal + 8, height: medal + 8)
                        .contentShape(Circle())
                        .position(x: ax, y: height / 2)
                        .gesture(push(travel: travel))
                }
                .onChange(of: now) { _, d in
                    step(to: d, p: p, ax: ax)
                }
            }
            .animation(.spring(response: 0.34, dampingFraction: 0.76),
                       value: drag)
        }
        .frame(height: height)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: okBeat)
        .accessibilityRepresentation {
            Button(label) { if validate() { onConfirm() } }
        }
    }

    // MARK: La piste

    /// Le verre bombé et son DOUBLE FIL. L'argent tient la forme ; l'or est
    /// une LUMIÈRE : il n'existe qu'autour du médaillon (et un souffle aux
    /// deux bouts, comme la réf) — il voyage avec le doigt.
    private func track(W: CGFloat, p: CGFloat, ax: CGFloat,
                       flash: Double) -> some View {
        let axU = UnitPoint(x: ax / max(W, 1), y: 0.5)
        return ZStack(alignment: .leading) {
            // Le corps : un verre sombre BOMBÉ (verdict jury) — l'épaule
            // haute prend la lumière sur son premier quart, le cœur est
            // noir pur, et le bas remonte d'un souffle chaud.
            Capsule(style: .continuous)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.165, green: 0.158,
                                           blue: 0.158), location: 0),
                        .init(color: Color(red: 0.050, green: 0.045,
                                           blue: 0.050), location: 0.28),
                        .init(color: Color(red: 0.008, green: 0.007,
                                           blue: 0.009), location: 0.46),
                        .init(color: Color(red: 0.008, green: 0.007,
                                           blue: 0.009), location: 0.80),
                        .init(color: Color(red: 0.088, green: 0.073,
                                           blue: 0.060), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom))
            // Le creux : l'ombre interne du bord haut — la gorge est creusée.
            Capsule(style: .continuous)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.55), location: 0),
                        .init(color: .clear, location: 0.20)
                    ],
                    startPoint: .top, endPoint: .bottom))
                .blendMode(.multiply)
            // LE SHEEN D'ÉPAULE, biaisé côté médaillon (verdict jury) : le
            // lavis gris occupe le haut du corps et s'éteint aux deux tiers
            // droits — la lumière a un côté.
            Capsule(style: .continuous)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.115), location: 0),
                        .init(color: .clear, location: 0.30)
                    ],
                    startPoint: .top, endPoint: .bottom))
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white.opacity(0.55),
                                  location: 0.35),
                            .init(color: .clear, location: 0.70)
                        ],
                        startPoint: .leading, endPoint: .trailing)
                }
            // LA BRAISE DU DÉJÀ-POUSSÉ : ORANGE SATURÉ collé au pouce qui
            // meurt sur 40 % de la longueur poussée (le kaki pleine largeur
            // était la faute) — et bornée au cœur par le bombé.
            Capsule(style: .continuous)
                .fill(LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.55),
                        .init(color: Color(red: 1.0, green: 0.55, blue: 0.20)
                            .opacity(0.10 * Double(p)), location: 0.78),
                        .init(color: Color(red: 1.0, green: 0.55, blue: 0.20)
                            .opacity(0.25 + 0.14 * Double(p)), location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing))
                .frame(width: max(ax + 10, 1))
                .frame(maxHeight: .infinity)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.25), location: 0),
                            .init(color: .white, location: 0.35),
                            .init(color: .white, location: 0.8),
                            .init(color: .white.opacity(0.4), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom)
                }
                .opacity(refused ? 0 : 1)
            // LA PORTÉE SUR LE CORPS (verdict jury) : la lumière du médaillon
            // éclaire la LAQUE elle-même autour de lui — pas seulement le
            // fil. C'est ce qui fait une source, pas une déco.
            Capsule(style: .continuous)
                .fill(RadialGradient(
                    colors: [Color(red: 1.0, green: 0.58, blue: 0.24)
                        .opacity(0.055 + 0.05 * Double(p)),
                             .clear],
                    center: axU, startRadius: 12, endRadius: 118))
                .opacity(refused ? 0 : 1)
            // Le libellé — centré dans l'espace À DROITE du médaillon, comme
            // la réf : il ne passe jamais sous lui.
            Text(label)
                .font(.inter(14.5, .medium))
                .foregroundStyle(Color.white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.leading, 72)
                .opacity(max(0, 1 - Double(p / 0.40)))
            // LE FIL D'ARGENT — la forme. Plus présent aux extrémités qu'au
            // centre (verdict jury : rien ne reste iso-brillant sur tout le
            // périmètre).
            Capsule(style: .continuous)
                .strokeBorder(Self.silver, lineWidth: 0.9)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.68), location: 0),
                            .init(color: .white.opacity(0.50), location: 0.3),
                            .init(color: .white.opacity(0.50), location: 0.7),
                            .init(color: .white.opacity(0.68), location: 1)
                        ],
                        startPoint: .leading, endPoint: .trailing)
                }
            // LA GORGE (verdict jury) : un vide NOIR franc entre le fil
            // argent et le fil or — sans elle, les deux fusionnent en un
            // trait et c'est le tell qui trahit l'implémentation.
            Capsule(style: .continuous)
                .inset(by: -2.4)
                .strokeBorder(Color.black.opacity(0.92), lineWidth: 2)
            // L'OR QUI VOYAGE — la lumière du médaillon déposée sur le fil :
            // gaussienne serrée autour du pouce, plancher quasi nul au loin.
            Capsule(style: .continuous)
                .strokeBorder(refused ? Self.garnet
                                      : GaletSlide.heat(p * 0.5),
                              lineWidth: 1.1)
                .mask {
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white.opacity(0.30),
                                  location: 0.55),
                            .init(color: .clear, location: 1)
                        ]),
                        center: axU,
                        startRadius: 8,
                        endRadius: 100 + 55 * p)
                }
                .opacity(0.55 + 0.45 * Double(p))
            // LES DEUX BOUTS : deux LUMIÈRES posées sur les extrémités, qui
            // enveloppent les courbes et débordent un peu dehors.
            //
            // PLUS UN SEUL `.blur` ICI — C'ÉTAIT LE CALQUE, isolé à la
            // sonde : un flou SwiftUI laisse un voile clair UNIFORME sur
            // tout le rectangle de son hôte (mesuré +5 sur un fond de 14,
            // bords CARRÉS, 362 × 70 pt). C'est la composante continue de
            // son pyramidal qui fuit : ni le masque ni le blend mode n'y
            // changent rien — retirer le masque n'en enlevait que la
            // moitié. Et l'échelle de liserés qui a suivi faisait des
            // ANNEAUX (chaque trait a un bord franc dehors). Un dégradé
            // radial, lui, n'a AUCUN bord : c'est la seule douceur gratuite.
            // Elles vivent SUR LE CONTOUR, pas dans le corps — la réf de
            // Kathryn (« c'était comme ça avant, c'était bien ») montre un
            // fil qui se réchauffe aux deux bouts, jamais une lueur ronde
            // posée dans la piste : celle-là faisait grossir la pilule.
            // L'extinction vit dans la TEINTE (le dégradé meurt à 18 % de
            // chaque bord), plus dans un masque — et sans flou : masque et
            // flou étaient LE CALQUE. Emprise dehors : 3,5 pt, moins que
            // les ~15 du flou d'origine.
            Capsule(style: .continuous)
                .inset(by: -2)
                .strokeBorder(LinearGradient(
                    stops: [
                        .init(color: Self.bout, location: 0),
                        .init(color: Self.bout.opacity(0), location: 0.177),
                        .init(color: Self.bout.opacity(0), location: 0.823),
                        .init(color: Self.bout, location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing),
                    lineWidth: 3)
                .opacity(0.55)
            // LE FIL D'OR EXTÉRIEUR au pouce — le halo du bijou, hors du
            // bord, qui suit le doigt. La gaussienne du masque est devenue
            // la TEINTE du trait : même loi (plein jusqu'à 16 pt du pouce,
            // éteinte à 130 + 80 p). UNE SEULE PASSE, à l'encart d'origine :
            // la deuxième, plus large, dessinait un second contour et
            // c'était ça, la pilule « grossie ».
            Capsule(style: .continuous)
                .inset(by: -4)
                .strokeBorder(RadialGradient(
                    colors: [refused ? Self.garnet : Self.gold,
                             (refused ? Self.garnet : Self.gold).opacity(0)],
                    center: axU,
                    startRadius: 16,
                    endRadius: 130 + 80 * p),
                    lineWidth: 1.6)
                .opacity((0.14 + 0.86 * Double(p)) * (refused ? 0.9 : 1)
                         + flash * 0.6)
            // Le bain du refus : bref, entier — un ÉVÉNEMENT, pas un état.
            Capsule(style: .continuous)
                .fill(Self.garnet.opacity(refused ? 0.20 : 0))
        }
        .animation(.easeOut(duration: refused ? 0.10 : 0.30), value: refused)
    }

    // MARK: Le médaillon

    private func medallion(t: Date, p: CGFloat, flash: Double) -> some View {
        let tS = Float(t.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 900))
        // JAMAIS .clear sous un colorEffect : l'alpha nul de l'hôte avale
        // TOUT le rendu (la leçon gravée dans ExoHeaderGlow) — blanc, et
        // c'est le shader qui décide de chaque alpha.
        return Rectangle()
            .fill(.white)
            .colorEffect(ShaderLibrary.galetMedaillon(
                .float2(Float(medal * 1.9), Float(medal * 1.9)),
                .float(reduceMotion ? 0 : tS),
                .float(Float(rot)),
                .float(Float(p)),
                .float(Float(grip)),
                .float(refused ? 1 : 0),
                .float(Float(flash))))
    }

    // MARK: La scène

    /// Le sol sous le geste — GaletStage.metal. L'arité de l'appel matche
    /// la signature AU FLOAT PRÈS (le piège de la page blanche).
    private func stage(t: Date, p: CGFloat, ax: CGFloat, W: CGFloat,
                       flash: Double) -> some View {
        let tS = Float(t.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 900))
        // JAMAIS .clear sous un colorEffect (la leçon ExoHeaderGlow).
        return Rectangle()
            .fill(.white)
            .colorEffect(ShaderLibrary.galetStage(
                .float2(Float(W), 170),
                .float(reduceMotion ? 0 : tS),
                .float(Float(rot)),
                .float(Float(ax / max(W, 1))),
                .float(Float(p)),
                .float(Float(grip * (0.35 + 0.65 * p))),
                .float(refused ? 1 : 0),
                .float(Float(flash))))
    }

    // MARK: La poussière

    /// Des GRAINS, pas des bouffées : 1 à 3 pt, cœur presque blanc, une
    /// pointe d'or à la naissance, un scintillement propre à chacun. Ils
    /// héritent de la vitesse du pouce et restent derrière lui — puis
    /// montent d'un souffle et s'éteignent en scintillant.
    private func dust(now: Date) -> some View {
        Canvas { ctx, size in
            // Le Canvas est plus haut que la piste (170 pt) pour que rien
            // ne soit décapité — les coordonnées restent en espace piste.
            ctx.translateBy(x: 0, y: (170 - height) / 2)
            // Les braises du sol D'ABORD — c'est un sol, pas une particule.
            for e in embers {
                let age = now.timeIntervalSince(e.born)
                guard age >= 0, age < Self.emberLife else { continue }
                let u = age / Self.emberLife
                let a = (1 - u) * (1 - u) * 0.14
                let c: Color
                if u < 0.4 {
                    let k = u / 0.4
                    c = Color(red: 1.0,
                              green: 0.86 - (0.86 - 0.42) * k,
                              blue: 0.55 - (0.55 - 0.16) * k)
                } else {
                    let k = (u - 0.4) / 0.6
                    c = Color(red: 1.0 - (1.0 - 0.72) * k,
                              green: 0.42 - (0.42 - 0.13) * k,
                              blue: 0.16 - (0.16 - 0.07) * k)
                }
                ctx.fill(
                    Path(ellipseIn: CGRect(x: e.x - e.r, y: e.y - e.r,
                                           width: e.r * 2, height: e.r * 2)),
                    with: .radialGradient(
                        Gradient(colors: [c.opacity(a),
                                          c.opacity(a * 0.35),
                                          .clear]),
                        center: CGPoint(x: e.x, y: e.y),
                        startRadius: 0, endRadius: e.r))
            }
            for d in dusts {
                let age = now.timeIntervalSince(d.born)
                guard age >= 0, age < Self.dustLife else { continue }
                let u = age / Self.dustLife
                let fade = (1 - u) * (1 - u)
                let tw = 0.55 + 0.45 * sin(age * d.freq + d.phase)
                // La profondeur par la taille : les plus petits grains sont
                // les plus lointains — plus sourds, jamais flous. Le barème
                // suit la nouvelle échelle (max 1 pt), sinon la poudre fine
                // sortait toute au plancher.
                let a = fade * tw * (0.52 + 0.48 * Double(min(d.size, 1)))
                let x = d.x + d.vx * CGFloat(1 - exp(-age * 3)) * 18
                let y = d.y - d.rise * CGFloat(u) * 14
                let r = d.size * (0.8 + 0.5 * CGFloat(u))
                let core = d.gold
                    ? Color(red: 1.0, green: 0.88, blue: 0.70)
                    : Color.white
                let box = CGRect(x: x - r, y: y - r,
                                 width: r * 2, height: r * 2)
                if r < 0.75 {
                    // LE GRAIN À PLAT : sous 0,75 pt (deux pixels), un
                    // dégradé radial ne dessine plus rien qu'un point — et
                    // cent cinquante dégradés par image, si. Le point plat
                    // est le prix de la densité.
                    ctx.fill(Path(ellipseIn: box),
                             with: .color(core.opacity(a * 0.90)))
                } else {
                    ctx.fill(
                        Path(ellipseIn: box),
                        with: .radialGradient(
                            Gradient(colors: [core.opacity(a * 0.95),
                                              core.opacity(a * 0.30),
                                              .clear]),
                            center: CGPoint(x: x, y: y),
                            startRadius: 0, endRadius: r * 2.2))
                }
            }
            // LES PIERRES — des croix taillées, pas des ronds : deux
            // losanges effilés croisés et un cœur vif. Leur scintillement
            // est TRANCHÉ (cube du sinus) : presque éteintes, puis un éclat
            // — c'est l'éclat qui fait la facette.
            for g in gems {
                let age = now.timeIntervalSince(g.born)
                guard age >= 0, age < Self.gemLife else { continue }
                let u = age / Self.gemLife
                let fade = (1 - u) * (1 - u)
                let s = 0.5 + 0.5 * sin(age * g.freq + g.phase)
                let tw = 0.30 + 0.70 * s * s * s
                let a = fade * tw
                let x = g.x + g.vx * CGFloat(1 - exp(-age * 3)) * 16
                let y = g.y - g.rise * CGFloat(u) * 18
                let r = g.ray * (0.85 + 0.35 * CGFloat(u))
                // Blanc glacier — le froid sur la braise.
                let ice = Color(red: 0.90, green: 0.95, blue: 1.0)
                var star = Path()
                star.move(to: CGPoint(x: -r, y: 0))
                star.addLine(to: CGPoint(x: 0, y: -r * 0.13))
                star.addLine(to: CGPoint(x: r, y: 0))
                star.addLine(to: CGPoint(x: 0, y: r * 0.13))
                star.closeSubpath()
                star.move(to: CGPoint(x: 0, y: -r))
                star.addLine(to: CGPoint(x: r * 0.13, y: 0))
                star.addLine(to: CGPoint(x: 0, y: r))
                star.addLine(to: CGPoint(x: -r * 0.13, y: 0))
                star.closeSubpath()
                let placed = star.applying(
                    CGAffineTransform(translationX: x, y: y)
                        .rotated(by: g.tilt))
                ctx.fill(placed, with: .color(ice.opacity(a * 0.85)))
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8,
                                           width: 1.6, height: 1.6)),
                    with: .color(Color.white.opacity(a * 0.95)))
            }
        }
        // Le blend mode est mort ici aussi (le CALQUE, cf. la scène) : les
        // grains sont blancs sur du noir, le par-dessus les rend pareil.
        .allowsHitTesting(false)
        .frame(height: 170)
    }

    private func emit(at x: CGFloat, velocity vx: CGFloat, level: Double) {
        // LE BRUIT MAGIQUE : du cristal semé à la distance, hauteur et
        // densité qui montent avec la course — Paillettes se nourrit de
        // chaque déplacement, avant tout seuil.
        if let ls = lastSoundX {
            Paillettes.shared.travel(abs(x - ls), level: level)
        }
        lastSoundX = x
        // À LA DISTANCE, jamais au temps : un doigt arrêté ne sème rien.
        // Le pas passe de 5 à 3 pt (verdict Kathryn : « plus nombreuses et
        // plus fines ») — la traînée devient continue au lieu d'être
        // pointillée.
        if let last = lastDustX, abs(x - last) < 3 { return }
        lastDustX = x
        // DE LA POUDRE, PAS DES CONFETTIS : trois à six grains par pas, de
        // 0,3 à 1 pt — deux fois plus nombreux et deux fois plus fins
        // qu'avant. Les plus petits sont peints à plat (voir le Canvas) :
        // c'est ce qui rend le nuage gratuit à cette densité.
        let n = Int.random(in: 3...6)
        for _ in 0..<n {
            dusts.append(Dust(
                born: .now,
                x: x - CGFloat.random(in: 4...34),
                y: height / 2 + CGFloat.random(in: -16...16),
                vx: -max(vx, 0) / 900 - CGFloat.random(in: 0.2...1.0),
                rise: CGFloat.random(in: 0.4...1.3),
                size: CGFloat.random(in: 0.30...1.00),
                freq: Double.random(in: 9...24),
                phase: Double.random(in: 0...(2 * .pi)),
                gold: Int.random(in: 0..<5) == 0))
        }
        if dusts.count > 150 { dusts.removeFirst(dusts.count - 150) }
        // Les pierres : une par ~9 pt de course — plus rares que la
        // poussière, sinon elles ne sont plus des pierres. Elles maigrissent
        // avec elle (1,4-2,6 pt) : une taille fine scintille mieux.
        if lastGemX.map({ abs(x - $0) >= 9 }) ?? true {
            lastGemX = x
            gems.append(Diamond(
                born: .now,
                x: x - CGFloat.random(in: 4...28),
                y: height / 2 + CGFloat.random(in: -17...17),
                vx: -CGFloat.random(in: 0.2...0.7),
                rise: CGFloat.random(in: 0.5...1.1),
                ray: CGFloat.random(in: 1.4...2.6),
                freq: Double.random(in: 14...30),
                phase: Double.random(in: 0...(2 * .pi)),
                tilt: Double.random(in: -0.5...0.5)))
            if gems.count > 28 { gems.removeFirst(gems.count - 28) }
        }
        // Le sol s'écrit : une braise par ~9 pt, large et sourde.
        if lastEmberX.map({ abs(x - $0) >= 9 }) ?? true {
            lastEmberX = x
            embers.append(Ember(
                born: .now,
                x: x - CGFloat.random(in: 2...14),
                y: height / 2 + CGFloat.random(in: -8...8),
                r: CGFloat.random(in: 14...26)))
            if embers.count > 12 { embers.removeFirst(embers.count - 12) }
        }
    }

    // MARK: Le pas de temps

    /// Le battement : la phase du tube s'ACCUMULE (elle accélère avec la
    /// course, elle ne saute jamais), la saisie se lisse, la poussière morte
    /// se retire. Tout état s'écrit ICI, jamais dans le rendu.
    private func step(to d: Date, p: CGFloat, ax: CGFloat) {
        let dt = lastFrame.map { min(d.timeIntervalSince($0), 0.05) } ?? 0
        lastFrame = d
        if dt > 0 {
            // 0,75 au repos (et non 0,45) : l'orbite du point chaud doit se
            // VOIR sans qu'on y touche — l'invite, pas un manège.
            rot += dt * (0.75 + 1.1 * Double(grip) + 7.5 * Double(p))
            let auto = Self.cycling
                ? Self.autoP(d.timeIntervalSinceReferenceDate).grip : false
            let target: CGFloat = (dragging || auto || Self.frozen != nil)
                ? 1 : 0
            grip += (target - grip) * CGFloat(min(dt * 9, 1))
            let mood = grip * (0.35 + 0.65 * p)
            onMood(refused ? 0 : mood)
            if dragging {
                // LE GRONDEMENT — le moteur de la lentille, réglé course :
                // il n'existe qu'au doigt et enfle avec la poussée.
                RocketHaptics.shared.dragLevel(Double(mood))
                // LE CRAN DES PERLES : la couronne en compte 24 — chaque
                // perle franchie est un grain dans la main, dans les deux
                // sens. Le bijou se compte au doigt.
                let pearl = Int(p * 24)
                if pearl != lastPearl {
                    lastPearl = pearl
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            }
            // Le doigt synthétique sème comme le vrai : à la distance.
            if Self.cycling, !reduceMotion {
                emit(at: ax, velocity: 0, level: Double(p))
            }
        }
        if dusts.contains(where: {
            d.timeIntervalSince($0.born) >= Self.dustLife }) {
            dusts.removeAll { d.timeIntervalSince($0.born) >= Self.dustLife }
        }
        if gems.contains(where: {
            d.timeIntervalSince($0.born) >= Self.gemLife }) {
            gems.removeAll { d.timeIntervalSince($0.born) >= Self.gemLife }
        }
        if embers.contains(where: {
            d.timeIntervalSince($0.born) >= Self.emberLife }) {
            embers.removeAll { d.timeIntervalSince($0.born) >= Self.emberLife }
        }
    }

    /// LA CHAUFFE — orange, or, blanc : trois paliers, jamais deux (le
    /// dégradé direct passe par un rose sale à mi-course).
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
                if !dragging {
                    dragging = true
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred(intensity: 0.5)
                }
                drag = min(max(v.translation.width, 0), travel)
                if !reduceMotion {
                    emit(at: axPad + drag, velocity: v.velocity.width,
                         level: Double(min(max(drag / travel, 0), 1)))
                }
            }
            .onEnded { _ in
                dragging = false
                lastDustX = nil
                lastGemX = nil
                lastEmberX = nil
                lastSoundX = nil
                RocketHaptics.shared.dragEnd()
                Paillettes.shared.end()
                guard !refused else { return }
                // Le seuil est à 72 % : assez haut pour qu'un frôlement ne
                // parte pas, assez bas pour que le dernier centimètre ne
                // soit pas une épreuve.
                guard drag > travel * 0.72 else {
                    drag = 0
                    return
                }
                guard validate() else {
                    refuse()
                    return
                }
                okBeat += 1
                flashAt = .now
                CommitHaptic.play()
                // Le shimmer du commit : l'arpège des paillettes, collé au
                // flash — la même matière sonore que la traînée du geste.
                Paillettes.shared.announce(after: 0.03)
                drag = travel
                onConfirm()
                // Le pouce revient pendant que la feuille se range.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    drag = 0
                }
            }
    }

    /// LE REFUS. Il se voit, il se sent, et il RENVOIE — le mood retombe
    /// SEC avec lui (pas de rebond : on ne joue pas quand on refuse).
    private func refuse() {
        refused = true
        RefusalHaptic.play()
        drag = 0
        onMood(0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            refused = false
        }
    }
}

// MARK: - L'haptique du commit

/// LA FIN DU SLIDE, DANS LA MAIN : une course qui se termine — deux légers
/// rapprochés qui enflent, un net qui ferme. Écrite à part plutôt que
/// reprise du `slam()` de la carte : deux gestes qui tapent pareil
/// finissent par se confondre dans la main.
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

/// LE REFUS DANS LA MAIN : DEUX coups secs et rapprochés — la façon
/// universelle de dire non. Un coup unique se confond avec une validation ;
/// une montée se confond avec un chargement.
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
