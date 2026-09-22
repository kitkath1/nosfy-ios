import AVFoundation
import CoreHaptics
import SwiftUI

/// LE SOUFFLE D'ÉTOILE DE L'ÎLE (demande Kathryn 04-09 : « un bruit de
/// magie », puis « un NOUVEAU son, plus subtil, ET haptique ») —
/// `ile-entree.wav` / `ile-sortie.wav`, SYNTHÉTISÉS pour ce geste :
/// des partiels non harmoniques (le grain cristal, jamais la cloche),
/// une attaque de 22 ms (aucun clic), une longue traîne, et un
/// glissando doux — il MONTE quand elle entre, il DESCEND quand elle
/// sort. Le lecteur est RETENU (un `AVAudioPlayer` local meurt avant
/// d'avoir chanté) ; session `.ambient` + `mixWithOthers` : la musique
/// de Kathryn continue.
enum CarillonIle {
    private static var joueur: AVAudioPlayer?
    private static var moteur: CHHapticEngine?

    static func tinter(_ piste: String, volume: Float) {
        guard let url = Bundle.main.url(forResource: piste,
                                        withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        joueur?.stop()
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        joueur = p
        p.volume = volume
        p.play()
    }

    /// LE SCINTILLEMENT — l'haptique du geste, à l'école CoreHaptics de
    /// la maison (`LuneDust`) : un souffle CONTINU très doux qui enfle
    /// et retombe, ponctué de trois transitoires de plus en plus fins.
    /// Rien à voir avec un coup sec : ça pétille sous le doigt.
    static func scintiller(monte: Bool) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics
        else { return }
        if moteur == nil {
            moteur = try? CHHapticEngine()
            moteur?.isAutoShutdownEnabled = true
        }
        guard let m = moteur, (try? m.start()) != nil else { return }
        func p(_ id: CHHapticEvent.ParameterID,
               _ v: Float) -> CHHapticEventParameter {
            CHHapticEventParameter(parameterID: id, value: v)
        }
        // Le souffle : doux, court, jamais un buzz.
        var events: [CHHapticEvent] = [
            CHHapticEvent(eventType: .hapticContinuous,
                          parameters: [p(.hapticIntensity, 0.22),
                                       p(.hapticSharpness, 0.28)],
                          relativeTime: 0, duration: 0.34)
        ]
        // Les paillettes : trois pointes, de plus en plus fines et
        // espacées — elles montent ou descendent selon le sens.
        let temps: [Double] = monte ? [0.02, 0.13, 0.27] : [0.02, 0.11, 0.22]
        let forces: [Float] = monte ? [0.30, 0.22, 0.14] : [0.34, 0.20, 0.11]
        let finesses: [Float] = monte ? [0.55, 0.72, 0.92] : [0.92, 0.70, 0.50]
        for i in 0..<3 {
            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [p(.hapticIntensity, forces[i]),
                             p(.hapticSharpness, finesses[i])],
                relativeTime: temps[i]))
        }
        guard let motif = try? CHHapticPattern(events: events,
                                               parameters: []),
              let lecteur = try? m.makePlayer(with: motif) else { return }
        try? lecteur.start(atTime: CHHapticTimeImmediate)
    }

    /// L'ENTRÉE : elle se pose dans l'île — le souffle qui MONTE.
    static func entree() {
        tinter("ile-entree", volume: 0.26)
        scintiller(monte: true)
    }
    /// LA SORTIE : elle en ressort — le souffle qui DESCEND, plus bas.
    static func sortie() {
        tinter("ile-sortie", volume: 0.20)
        scintiller(monte: false)
    }
}

/// LES BRAISES QUI CHANTENT — l'égaliseur de lumière, UN SEUL composant
/// pour le grand player ET la mini pilule (une source : deux vagues qui
/// divergeraient ne seraient plus une famille).
///
/// ⚠️ UN SEUL `Canvas` (jamais N calques floutés), borné à la bande
/// qu'il éclaire — la loi : un Canvas rasterise TOUTE sa surface, on ne
/// lui donne que le bas. Périodes DÉSACCORDÉES (jamais un métronome),
/// un flou unique par-dessus : ça se lit en VAGUE, pas en barres.
/// Anti-brun : R reste à 1,00 partout.
struct BraisesVague: View {
    /// La force générale (grand player ~0,62 après le verdict
    /// « atténue un peu » ; mini pilule ~0,42 : elle est petite).
    var force: Double = 1
    /// La part BASSE occupée par la vague.
    var partBasse: CGFloat = 0.55
    var colonnes: Int = 7
    var flou: CGFloat = 26
    /// FIGÉE : l'horloge s'arrête (pendant un geste, rien ne doit
    /// redessiner un Canvas — la loi de la maison).
    var fige: Bool = false
    /// LA CADENCE (04-09, lot 2, cause n° 6). La mini vague de la pilule
    /// tourne TOUTE LA SÉANCE : elle passe à 15 Hz. Elle fait 69 pt de
    /// haut et elle est floutée à 11 — à cette échelle, 30 et 15 sont le
    /// même mouvement à l'œil, et c'est une image sur deux qui ne coûte
    /// plus rien (le Canvas, son flou, son `plusLighter` — ET l'ombre du
    /// groupe qui les contient, recalculée avec eux).
    var hz: Double = 30

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation(minimumInterval: 1.0 / hz,
                                    paused: fige || reduceMotion
                                        || scenePhase != .active
                                        || ProtectionThermique.shared.ambianceAuRepos)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                Canvas { ctx, size in
                    let n = max(1, colonnes)
                    let pas = size.width / CGFloat(n)
                    let per: [Double] = [1.9, 2.7, 1.3, 3.1, 1.6, 2.3, 1.1,
                                         2.9, 1.7]
                    for i in 0..<n {
                        let ph = Double(i) * 0.8
                        let k = per[i % per.count]
                        let a = 0.5 + 0.5 * sin(t * 2 * .pi / k + ph)
                        let b = 0.5 + 0.5 * sin(t * 2 * .pi / (k * 1.7) + ph)
                        let niveau = (0.30 + 0.55 * a * (0.55 + 0.45 * b))
                            * force
                        let hCol = size.height * CGFloat(niveau)
                        let x = pas * CGFloat(i)
                        let r = CGRect(x: x + pas * 0.10,
                                       y: size.height - hCol,
                                       width: pas * 0.80, height: hCol)
                        // ⚠️ LA RAMPE EST ROUGE·BLANC·NOIR (verdict Kathryn
                        // 06-09 : « pas de braises marrons !! on a jamais
                        // voulu cette couleur »). MESURÉ sur capture, pixels
                        // clairs de la flamme : l'ancien stop (1 · 0,54 ·
                        // 0,18) rendait G/R = 0,52 — un vert à 0,54 EST de
                        // l'orange, et flouté sur noir il se lit MARRON. La
                        // loi anti-brun (« R reste à 1,00, on désature le
                        // vert ») était tenue à la lettre ; le vert n'était
                        // simplement jamais descendu assez bas. Un ROUGE se
                        // mesure : G/R ≤ 0,22 sur les pixels clairs du corps.
                        // La crête reste BLANCHE et FINE : c'est elle qui
                        // porte la clarté, jamais un orange intermédiaire.
                        let grad = Gradient(stops: [
                            .init(color: .white.opacity(0.85 * niveau),
                                  location: 0),
                            .init(color: Color(red: 1, green: 0.18,
                                               blue: 0.08)
                                .opacity(0.75 * niveau), location: 0.35),
                            .init(color: Color(red: 1, green: 0.07,
                                               blue: 0.03)
                                .opacity(0.45 * niveau), location: 0.75),
                            .init(color: .clear, location: 1)
                        ])
                        ctx.fill(
                            Path(roundedRect: r, cornerRadius: pas * 0.4),
                            with: .linearGradient(
                                grad,
                                startPoint: CGPoint(x: r.midX, y: r.maxY),
                                endPoint: CGPoint(x: r.midX, y: r.minY)))
                    }
                }
                .frame(height: g.size.height * partBasse)
                .blur(radius: flou)
                .blendMode(.plusLighter)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .allowsHitTesting(false)
    }
}

/// L'INVITE QUI RESPIRE — « Choisissez un exercice » avec une LUEUR qui
/// balaye son dégradé de blanc. UN SEUL composant pour la mini pilule
/// ET le grand player (verdict Kathryn : « comme dans le grand ») :
/// deux lueurs qui divergeraient ne seraient plus la même invitation.
struct InviteAnimee: View {
    var taille: CGFloat
    var poids: Font.Weight = .semibold
    /// LE TEXTE BALAYÉ — l'invite par défaut, ou le NOM DE L'EXERCICE EN
    /// COURS (05-09) : « l'exercice en cours avec un effet de balayage de
    /// lumière très Apple pour montrer que c'est en cours ». Une seule
    /// lueur dans toute la maison : deux balayages qui divergeraient ne
    /// seraient plus la même langue.
    var texte: String = "Choisissez un exercice"
    /// ⚠️ ELLE N'AVAIT AUCUNE PORTE (04-09, lot 2, cause n° 7) : une
    /// `TimelineView` sans `paused:`, qui balayait un dégradé sur du
    /// texte 30 fois par seconde — et c'est l'état du DÉBUT DE CHAQUE
    /// SÉANCE, tant qu'aucun exercice n'est choisi, c'est-à-dire pendant
    /// tout le moment où on tripote la bulle. Elle se tait sous le doigt
    /// et sous un onglet caché ; sa lueur descend à 20 Hz (elle traverse
    /// le mot en 2,6 s — personne n'a jamais lu ça en 30 images).
    var fige: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                paused: fige)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900)
            let u = CGFloat((t / 2.6).truncatingRemainder(dividingBy: 1))
            Text(texte)
                .font(.system(size: taille, weight: poids))
                .foregroundStyle(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.40),
                              location: max(0, u - 0.28)),
                        .init(color: .white, location: u),
                        .init(color: .white.opacity(0.40),
                              location: min(1, u + 0.28))
                    ],
                    startPoint: .leading, endPoint: .trailing))
                .lineLimit(1)
        }
    }
}

/// LE TICKET DE SÉRIES — un VRAI ticket de papier (verdict Kathryn
/// 04-09 : « il fait cheap, il faut être plus réaliste »).
///
/// Ce qui fait qu'un ticket EST un ticket, et pas une pastille de
/// couleur : le PAPIER (crème chaud, jamais blanc pur, avec un dégradé
/// qui dit la courbure), les DEUX ENCOCHES semi-circulaires aux flancs
/// (là où on le détache), la LIGNE DE PERFORATION en pointillés, le
/// CHIFFRE en encre sombre pressée dans le papier (letterpress : une
/// ombre haute, une lumière basse), le talon à gauche, et une ombre
/// portée courte qui le décolle de son support.
struct TicketSeries: View {
    var texte: String
    /// L'échelle du ticket (1 = ~104 × 34 pt).
    var echelle: CGFloat = 1

    private var papier: LinearGradient {
        LinearGradient(stops: [
            .init(color: Color(red: 0.97, green: 0.955, blue: 0.92),
                  location: 0),
            .init(color: Color(red: 0.93, green: 0.905, blue: 0.855),
                  location: 0.55),
            .init(color: Color(red: 0.86, green: 0.825, blue: 0.76),
                  location: 1)
        ], startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let L = 104 * echelle, H = 34 * echelle
        let forme = TicketShape(coin: 5 * echelle, encoche: 5 * echelle)
        return ZStack {
            // LE PAPIER — la dalle entière, d'un seul tenant.
            forme.fill(papier)
            HStack(spacing: 0) {
                // ⚠️ LE TALON RESTE (verdict 04-09 : « je voulais pas que
                // tu coupes la partie gauche avec les pointillés, juste
                // l'icône ») — VIDE, et c'est LUI qui bouge : il se
                // soulève de temps en temps, comme si on allait le
                // DÉCHIRER. Le pivot est la perforation elle-même.
                // ⚠️ LE TALON NE BOUGE PLUS (verdict Kathryn 05-09 :
                // « enlève-lui son animation »). Il se soulevait de 26°
                // toutes les 3,4 s, tout seul, à côté d'une card
                // immobile : un objet qui gigote sans qu'on le touche.
                // Le ticket reste EXACTEMENT le même papier — il est
                // simplement POSÉ. (Et c'est une horloge de moins qui
                // tourne derrière le player.)
                talon
                    .frame(width: 30 * echelle)
                // LE CHIFFRE, en encre pressée dans le papier.
                Text(texte)
                    .font(.system(size: 12.5 * echelle, weight: .heavy))
                    .tracking(0.8 * echelle)
                    .foregroundStyle(Color(red: 0.16, green: 0.14,
                                           blue: 0.11))
                    .shadow(color: .white.opacity(0.55), radius: 0, y: 0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 6 * echelle)
            }
        }
        .frame(width: L, height: H)
        // Le grain du papier : une trame très fine, jamais un bruit gris.
        .overlay {
            forme.fill(
                LinearGradient(colors: [.white.opacity(0.35), .clear,
                                        .black.opacity(0.06)],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing))
                .blendMode(.overlay)
        }
        // L'arête : plus claire en haut (la lumière vient d'en haut).
        .overlay {
            forme.stroke(
                LinearGradient(colors: [.white.opacity(0.75),
                                        Color(red: 0.62, green: 0.58,
                                              blue: 0.50).opacity(0.5)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.55), radius: 6 * echelle,
                y: 3 * echelle)
    }

    /// LE TALON : le papier du bord gauche, sa perforation, et l'ombre
    /// qui naît quand il se décolle.
    private var talon: some View {
        ZStack(alignment: .trailing) {
            TicketShape(coin: 5 * echelle, encoche: 5 * echelle)
                .fill(papier)
                .frame(width: 60 * echelle)
                .frame(width: 30 * echelle, alignment: .leading)
                .clipped()
            // LA PERFORATION : des pointillés, jamais un trait plein.
            Rectangle()
                .fill(Color(red: 0.52, green: 0.48, blue: 0.42).opacity(0.6))
                .frame(width: 1)
                .mask(VStack(spacing: 2.5 * echelle) {
                    ForEach(0..<7, id: \.self) { _ in
                        Rectangle().frame(height: 2 * echelle)
                    }
                })
        }
        .shadow(color: .black.opacity(0.35), radius: 2.5 * echelle, x: 1.5)
    }
}

// MARK: - LA PILULE VAGABONDE (plan `tools/nav/PLAN-NAV-V2-PILULE.md`)
//
// Le player en séance N'EST PLUS une dalle dockée : c'est UNE pilule
// flottante, LARGE (« comme une navigation », l'école Live Activity),
// qu'on drague PARTOUT pour le fun et qui se pose à n'importe quelle
// HAUTEUR — l'x se recentre à l'élan au relâcher. Tap → l'overlay du
// player. Robe : liquid glass NOIR → TRANSPARENT (verre AU REPOS,
// doublure mate PENDANT le mouvement — la loi payée : un verre natif
// animé fait tomber 60 → 14 img/s).
//
// ⚠️ LES RÈGLES ARCHITECTURALES (payées 2 jours, ne jamais revenir) :
//   · le drag est un DragGesture SwiftUI SUR la pilule elle-même —
//     JAMAIS un pan en .background (affamé), JAMAIS un pan-fenêtre ;
//   · la position COMMISE est du VRAI layout (`.position`), jamais un
//     offset résiduel (39f95f9 : pixels ≠ hit-test) ;
//   · le doigt tenu se détecte par @GestureState/.updating (SwiftUI le
//     remet à faux LUI-MÊME si le geste meurt) — JAMAIS un minuteur
//     (le sachet qui se refermait sous le doigt, payé le 30-08) ;
//   · l'état vit dans un @Observable POSSÉDÉ, écrit sec — jamais un
//     @State sur le châssis (la page ré-évaluée par image + 337a6e3).

/// L'ÉTAT DE LA PILULE — un singleton possédé, l'école PlayerEtat.
@Observable
final class PiluleEtat {
    static let shared = PiluleEtat()
    private init() {}

    /// La HAUTEUR COMMISE du centre, en RATIO de la zone utile (survit
    /// aux tailles d'appareil ; persistée par séance).
    var yRatio: CGFloat = 0.82

    /// LA PILULE DANS L'ÎLE (idée Kathryn, J1) : draguée vers le haut,
    /// elle s'ASPIRE dans la Dynamic Island et devient une bordure
    /// animée autour de l'île ; un tap sur l'île la fait RESSORTIR à sa
    /// dernière hauteur.
    ///
    /// ⚠️ DEPUIS LE 05-09 ELLE Y NAÎT (Kathryn : « par défaut quand on
    /// lance un exercice, la notification/pastille va dans le Dynamic
    /// Island »). C'est `WoopApp` qui le pose à l'ouverture de la séance
    /// — la valeur d'ici n'est que le repos d'avant la première.
    var dansIle = false

    /// LA PLAGE UTILE — la hauteur autorisée pour la POSE. Elle vivait en
    /// DUR dans `WoopApp` ; depuis que la cible des pièces la lit aussi
    /// (`ancreGlobale`), elle n'a plus le droit d'exister en deux
    /// exemplaires : une cote recopiée est une cote qui divergera.
    /// Haut : sous la barre d'état. Bas : haut de la nav (H − 60) moins
    /// le débord du ticket (30) moins la demi-pilule (48).
    static var utile: ClosedRange<CGFloat> {
        130...(UIScreen.main.bounds.height - 138)
    }

    /// LA CIBLE DE CE QU'UNE SÉRIE RAPPORTE (les pièces, et demain le
    /// reste), en coordonnées PHYSIQUES. Depuis le 05-09 la pastille est
    /// le SEUL point d'arrivée : la carte des séries de la fiche exo est
    /// archivée (`tools/flow/ANALYSE-PASTILLE-UNIQUE.md`), et ce qui
    /// visait son cadre ne visait plus rien.
    ///
    /// ⚠️ Le `dessin` du doigt n'entre PAS dans le calcul : une cible se
    /// lit à l'instant du départ, elle ne se recalcule pas à chaque image
    /// d'un drag (la loi de la page ré-évaluée par image).
    var ancreGlobale: CGPoint {
        let W = UIScreen.main.bounds.width
        guard !dansIle else {
            return CGPoint(x: W / 2, y: IleGeo.babyCentreY)
        }
        let u = Self.utile
        return CGPoint(x: W / 2,
                       y: u.lowerBound
                           + yRatio * (u.upperBound - u.lowerBound))
    }

    /// LE DESSIN pendant le geste/le vol : offset possédé, écrit SEC.
    var dessin: CGSize = .zero
    var enDrag = false
    var enVol = false
    /// Le geste ou le vol est en cours — la robe passe en doublure mate.
    var enMouvement: Bool { enDrag || enVol }

    @ObservationIgnored private let moteur = MoteurPilule()

    func saisir() {
        moteur.arreter()
        enVol = false
        enDrag = true
    }

    func suivre(_ translation: CGSize) {
        if !enDrag { saisir() }
        dessin = translation
    }

    /// Le relâcher : l'y se COMMET (projeté à l'élan, borné), l'x se
    /// recentre — et le dessin VOLE vers zéro à la vitesse du doigt
    /// (fin de course = 3·distance/vitesse, la recette payée).
    func commettre(velocity: CGSize, dansUtile utile: ClosedRange<CGFloat>,
                   hauteurUtile H: CGFloat) {
        enDrag = false
        guard H > 1 else { dessin = .zero; return }
        let yAvant = utile.lowerBound + yRatio * H
        // ELLE SE POSE LÀ OÙ ON LA LÂCHE (verdict J1 : « elle se pose
        // pas où je veux, ça bouge trop ») : AUCUNE projection au
        // relâcher normal — seul un VRAI flick (> 600 pt/s) prolonge la
        // course, brièvement.
        let elan: CGFloat = abs(velocity.height) > 600
            ? velocity.height * 0.10 : 0
        let yVise = yAvant + dessin.height + elan
        // L'ASPIRATION DANS L'ÎLE (règles Kathryn 04-09) : lâchée en
        // HAUT, ou jetée SUR LES CÔTÉS (elle « disparaît » dans l'île,
        // d'où qu'on la jette) — avec le grand voyage animé côté vue.
        // ⚠️ LA PORTE S'EST RESSERRÉE (04-09, lot 2, cause n° 3). Elle
        // était `xFin < 70 || xFin > W - 70` : un simple déplacement
        // LATÉRAL de ~125 pt suffisait à l'aspirer, sans intention. Un
        // jet sur le côté doit maintenant être un VRAI jet — la vitesse
        // du doigt le dit, la position seule ne le disait pas.
        let W = UIScreen.main.bounds.width
        let xFin = W / 2 + dessin.width
        let jetLateral = (xFin < 56 || xFin > W - 56)
            && abs(velocity.width) > 500
        if yVise < utile.lowerBound - 6 || jetLateral {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                dansIle = true
                dessin = .zero
            }
            CarillonIle.entree()      // souffle + scintillement
            return
        }
        let yCommis = min(max(yVise, utile.lowerBound), utile.upperBound)
        yRatio = (yCommis - utile.lowerBound) / H
        // Le dessin repart d'où sont les PIXELS (continuité parfaite) et
        // vole vers zéro — le layout, lui, a déjà sauté à yCommis.
        dessin = CGSize(width: dessin.width,
                        height: (yAvant + dessin.height) - yCommis)
        volerVersZero(velocity: velocity)
    }

    /// L'ENVOL TOUT SEUL — « dès qu'une session se lance, il vole
    /// directement dans le Dynamic Island » (Kathryn, 05-09).
    ///
    /// ⚠️ C'est EXACTEMENT le vol du doigt, pas une téléportation : le
    /// même ressort, le même `matchedGeometryEffect` côté vue, le même
    /// carillon. Poser `dansIle = true` sec (ce que faisait `WoopApp`
    /// depuis ce matin) faisait NAÎTRE la pastille dans l'île — on ne
    /// voyait pas qu'elle y était allée, donc rien n'apprenait qu'elle
    /// pouvait en revenir.
    func envolerVersIle() {
        guard !dansIle else { return }
        withAnimation(.spring(response: 0.72, dampingFraction: 0.88)) {
            dansIle = true
            dessin = .zero
        }
        CarillonIle.entree()
    }

    /// LA SORTIE DANS LA MAIN — l'école des APPELS IPHONE (verdict
    /// Kathryn 05-09 : « partout, à la simple tap ou drag peu importe où
    /// sur la display island, je peux faire sortir la pilule, plus
    /// morphisme — comme les appels iPhone »). On touche l'île : la
    /// bannière en SORT et se pose JUSTE DESSOUS — jamais à son ancienne
    /// place commise. Avant, elle « réapparaissait » à l'autre bout de
    /// l'écran (yRatio persisté, souvent 0,82 : tout en bas) : le doigt
    /// tirait en haut, l'objet naissait en bas — lu comme un bug, et
    /// c'en était un.
    /// Où la pastille normale atterrit en quittant l'île.
    enum Sortie {
        /// Sous l'île, dans la main — le DRAG : le doigt la porte depuis
        /// sa naissance (jamais l'ancienne place commise : le doigt tire
        /// en haut, l'objet naîtrait en bas — lu comme un bug, mesuré).
        case sousLIle
        /// À sa place COMMISE (yRatio persisté, 0,82 par défaut : juste
        /// au-dessus de la nav) — le TAP (07-09, Kathryn : « elle devient
        /// notre pastille normale qui vient se mettre au-dessus de la nav
        /// bar quasiment, ou peu importe »). Le vol matched rend le
        /// voyage VISIBLE : ce n'est plus la téléportation du 05-09.
        case placeCommise
    }

    func sortirEnMain(vers: Sortie = .sousLIle) {
        guard dansIle else { return }
        moteur.arreter()
        if vers == .sousLIle { yRatio = 0 }
        dessin = .zero
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            dansIle = false
        }
        CarillonIle.sortie()
    }

    /// Le geste est MORT sans onEnded (arrière-plan, doigt volé) : les
    /// pixels reviennent au commis, sans élan.
    func gesteMort() {
        guard enDrag else { return }
        enDrag = false
        volerVersZero(velocity: .zero)
    }

    private func volerVersZero(velocity: CGSize) {
        let depart = dessin
        let distance = Double(max(abs(depart.width), abs(depart.height)))
        guard distance > 0.5 else { dessin = .zero; enVol = false; return }
        let v = Double(max(abs(velocity.width), abs(velocity.height)))
        let duree = v > 60
            ? min(max(3 * distance / v, 0.14), 0.42)
            : min(max(distance / 700, 0.18), 0.42)
        enVol = true
        let t0 = CACurrentMediaTime()
        moteur.demarrer { [weak self] maintenant in
            guard let self else { return }
            let t = min(max((maintenant - t0) / duree, 0), 1)
            let e = 1 - pow(1 - t, 3)
            self.dessin = CGSize(width: depart.width * (1 - e),
                                 height: depart.height * (1 - e))
            if t >= 1 {
                self.moteur.arreter()
                self.dessin = .zero
                self.enVol = false
            }
        }
    }
}

/// Le moteur du vol — le jumeau de `MoteurVol` (consolidation au J3).
private final class MoteurPilule: NSObject {
    private var lien: CADisplayLink?
    private var pas: ((Double) -> Void)?

    func demarrer(_ pas: @escaping (Double) -> Void) {
        arreter()
        self.pas = pas
        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        l.add(to: .main, forMode: .common)
        lien = l
    }

    @objc private func tick(_ l: CADisplayLink) { pas?(l.targetTimestamp) }

    func arreter() {
        lien?.invalidate()
        lien = nil
        pas = nil
    }
}

/// Toute la silhouette partage la prise, avec une marge tactile latérale
/// sans débord bas sur les titres. Le capteur reste réservé à iOS ; les
/// commandes flanquent le capteur ; la lèvre basse reste à y60.
private struct PriseIle: Shape {
    static let flanc: CGFloat = 20
    static let toit: CGFloat = 0
    var sous: CGFloat = 0

    func path(in r: CGRect) -> Path {
        let etendu = CGRect(x: r.minX - Self.flanc,
                            y: r.minY - Self.toit,
                            width: r.width + Self.flanc * 2,
                            height: r.height + Self.toit + sous)
        return Path(roundedRect: etendu, cornerRadius: 34,
                    style: .continuous)
    }
}

/// LE DESSIN DU DOIGT, ISOLÉ — le jumeau d'`OffsetVol` (PlayerMonde).
/// `body(content:)` reçoit l'arbre DÉJÀ CONSTRUIT : le relire soixante
/// fois par seconde ne reconstruit rien. C'est LE remède de la maison
/// contre « la vue qui contient tout se ré-évalue par image ».
private struct DessinPilule: ViewModifier {
    private var etat: PiluleEtat { PiluleEtat.shared }

    func body(content: Content) -> some View {
        content.offset(etat.dessin)
    }
}

/// LA DYNAMIC ISLAND — ses cotes (iPhone 15/15 Pro, coordonnées
/// PHYSIQUES : l'hôte de la pilule doit ignorer la zone sûre).
enum IleGeo {
    static let largeur: CGFloat = 126
    static let hauteur: CGFloat = 37.3
    static let haut: CGFloat = 11
    static var centreY: CGFloat { haut + hauteur / 2 }

    // Chrono et stop flanquent le capteur, sur la même ligne horizontale.
    // Le contact élargit très légèrement le contour ; aucune page ne descend.
    static let capsuleHaut: CGFloat = 4
    static let capsuleBas: CGFloat = 62
    static let capsuleLargeur: CGFloat = 282
    static var capsuleH: CGFloat { capsuleBas - capsuleHaut }
    static var capsuleCentreY: CGFloat { (capsuleHaut + capsuleBas) / 2 }
    static let capsuleContenuY: CGFloat = 33

    static let babyHaut: CGFloat = 6
    static let babyBas: CGFloat = 60
    static let babyLargeur: CGFloat = 274
    static let babyContenuY: CGFloat = 33
    static var babyH: CGFloat { babyBas - babyHaut }
    static var babyCentreY: CGFloat { (babyHaut + babyBas) / 2 }

}

// Deux textures, fondu confié au compositeur : aucun rappel SwiftUI à la
// cadence de l'écran. Le blanc Home garde son souffle discret ; ailleurs,
// la braise pulse plus franchement pour signaler la séance active.
private struct IleHaloTexture: View {
    var souffle: Double
    var eclat: Double
    var blanche: Bool
    var body: some View {
        let forme = Capsule()
        let lumiere = blanche ? Color.white : Color(red: 1, green: 0.16, blue: 0.08)
        ZStack {
            Color.black
            forme.inset(by: 2).stroke(lumiere, lineWidth: 7)
                .blur(radius: 5).opacity(0.24 + 0.26 * souffle)
            forme.fill(RadialGradient(
                colors: [.white.opacity(0.22 + 0.16 * eclat), .clear],
                center: .bottomLeading, startRadius: 0, endRadius: 92))
            forme.fill(RadialGradient(
                colors: [lumiere.opacity(0.20 + 0.14 * souffle), .clear],
                center: .topTrailing, startRadius: 0, endRadius: 82))
        }
        .clipShape(forme)
        .overlay {
            forme.strokeBorder(LinearGradient(stops: [
                .init(color: .white.opacity(0.72 + 0.20 * eclat), location: 0),
                .init(color: lumiere.opacity(0.20), location: 0.35),
                .init(color: lumiere.opacity(0.30 + 0.20 * souffle), location: 0.7),
                .init(color: .white.opacity(0.75), location: 1)
            ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
    }
}

private struct IleHaloNatif: UIViewRepresentable {
    var blanche: Bool
    var immobile: Bool

    final class Vue: UIView {
        let lumiere = CALayer()
        var configuration: String?
        var immobile = true
        var discret = true
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isOpaque = false
            layer.masksToBounds = true
            layer.addSublayer(lumiere)
            lumiere.opacity = 0.5
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.cornerRadius = bounds.height / 2
            lumiere.frame = bounds
            CATransaction.commit()
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            actualiser()
        }
        func actualiser() {
            guard !immobile, window != nil else {
                // Conserver la pose à la suspension, sans saut thermique.
                if let pose = lumiere.presentation()?.opacity {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    lumiere.opacity = pose
                    CATransaction.commit()
                }
                lumiere.removeAnimation(forKey: "halo-ile")
                return
            }
            guard lumiere.animation(forKey: "halo-ile") == nil else { return }
            // Home : souffle51 conservé. Ailleurs : une pulsation de2,4s
            // modulée sur4,1s, sans extinction ni mouvement des contrôles.
            // Chaque boucle raccorde exactement ses deux périodes.
            let duree = discret ? 274.7 : 98.4
            let pas = Int(ceil(duree * 15))
            let animation = CAKeyframeAnimation(keyPath: "opacity")
            let discret = self.discret
            animation.values = (0...pas).map { i -> Double in
                let t = Double(i) / Double(pas) * duree
                if discret {
                    return 0.5 + 0.28 * sin(t * 2 * .pi / 4.1)
                        + 0.22 * sin(t * 2 * .pi / 6.7 + 1.3)
                }
                return 0.5 + 0.42 * sin(t * 2 * .pi / 2.4)
                    + 0.08 * sin(t * 2 * .pi / 4.1 + 1.3)
            }
            animation.duration = duree
            animation.repeatCount = .infinity
            animation.calculationMode = .linear
            lumiere.add(animation, forKey: "halo-ile")
        }
    }

    func makeUIView(context: Context) -> Vue { Vue(frame: .zero) }
    func updateUIView(_ vue: Vue, context: Context) {
        let scale = context.environment.displayScale
        let discret = blanche || PiluleBanc.haloDiscret
        let configuration = "\(blanche)-\(discret)-\(scale)"
        if vue.configuration != configuration {
            func texture(_ souffle: Double, _ eclat: Double) -> CGImage? {
                let renderer = ImageRenderer(content:
                    IleHaloTexture(souffle: souffle, eclat: eclat, blanche: blanche)
                        .frame(width: IleGeo.babyLargeur, height: IleGeo.babyH))
                renderer.scale = scale
                return renderer.cgImage
            }
            if let base = texture(discret ? 0.24 : 0.05, 0),
               let pic = texture(discret ? 1 : 1.85, discret ? 0.85 : 1) {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                vue.layer.contents = base
                vue.layer.contentsScale = scale
                vue.lumiere.contents = pic
                vue.lumiere.contentsScale = scale
                CATransaction.commit()
                if vue.discret != discret {
                    vue.lumiere.removeAnimation(forKey: "halo-ile")
                    vue.discret = discret
                }
                vue.configuration = configuration
            }
        }
        vue.immobile = immobile
        vue.actualiser()
    }
    static func dismantleUIView(_ vue: Vue, coordinator: ()) {
        vue.immobile = true
        vue.actualiser()
    }
}

// MARK: - LA VUE

/// LA PILULE — l'hôte la monte `if enSeance` (jamais cachée : le rideau).
/// `utile` = la plage d'y AUTORISÉE pour la POSE (sous la status bar,
/// au-dessus de la bande nav / du mobilier bas) — le SURVOL en drag reste
/// libre partout, seule la pose est bornée.
struct PiluleVagabonde<Contenu: View>: View {
    var etat = PiluleEtat.shared
    var utile: ClosedRange<CGFloat>
    /// Le départ de la séance — l'île affiche le CHRONO qui court.
    var departSeance: Date = .now
    /// LE TICKET DE SÉRIES — il DÉPASSE de la pastille comme un vrai
    /// ticket, et on peut le TIRER (verdict Kathryn 04-09 : « on dirait
    /// qu'on peut le tirer, d'ailleurs on peut aussi le tirer »). `nil`
    /// = pas de ticket.
    var ticketTexte: String? = nil
    /// ⚠️ LA LOI DU RIDEAU (04-09, lot 2) : le grand player la recouvre
    /// entièrement — elle n'a plus RIEN à animer. Ses moteurs se taisent
    /// (braises, île) sans qu'elle se démonte : `morphPlayer` saute à 1,
    /// la démonter ferait un pop pendant que le player monte encore.
    var figee: Bool = false
    /// Sur le Foyer, la pastille libre reste cachée.
    var surHome: Bool = false
    var onOuvrir: () -> Void = {}
    var onStop: () -> Void = {}
    @ViewBuilder var contenu: () -> Contenu

    /// Le voyage pilule ⇄ île : UN morphing (matched geometry), la
    /// « grosse animation » demandée — jamais une téléportation.
    @Namespace private var vol

    /// Le doigt est posé — @GestureState : SwiftUI le remet à faux
    /// LUI-MÊME quand le geste meurt sans onEnded. Zéro minuteur.
    @GestureState private var doigtPose = false
    /// Le tirage du ticket (élastique, pixels seulement).
    @State private var tire: CGSize = .zero


    /// LA FORME ET LES COTES — celles des NOTIFICATIONS (verdict Kathryn
    /// J1 : « comme les notifications, pour consistance ») : la MÊME
    /// constante `NotifGeo.rayon` (28, continu), la même marge latérale,
    /// le même liseré, la même ombre. Deux cards qui ne portent pas le
    /// même bord ne sont plus une famille.
    static var forme: RoundedRectangle { NotifGeo.forme }
    /// ⚠️ LE VERRE PENDANT LE DRAG (04-09 : « je ne vois pas l'effet
    /// liquid glass comme le composant natif AU DRAG »). La loi payée du
    /// dépôt dit qu'un verre aux bounds vivants tombe à 14 img/s — elle
    /// a été mesurée sur l'ANCIEN verre. Le natif d'iOS 26
    /// (`.interactive()`) est fait pour bouger : on l'allume, et on
    /// MESURE (`-fps`, sonde de cadence). `-piluleMate` rend la doublure
    /// mate si la mesure devait le réclamer.
    static var mateAuDrag: Bool {
        CommandLine.arguments.contains("-piluleMate")
    }
    /// « Plus gros, plus de hauteur, la carrure d'une grosse notif Apple. »
    static var hauteur: CGFloat { 96 }

    /// Le liseré des notifications, à l'identique (NotifCard.RobeSocle).
    /// (computed : une struct générique refuse les stored statics.)
    private static var lisere: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white.opacity(0.16), location: 0),
                .init(color: .white.opacity(0.06), location: 0.35),
                .init(color: .white.opacity(0.03), location: 1)
            ],
            startPoint: .top, endPoint: .bottom)
    }

    /// Le doigt de l'ÎLE est posé (auto-remis à faux si le geste meurt).
    ///
    /// V2 (06-09) : ce doigt PILOTE AUSSI LE GONFLEMENT — fine au repos,
    /// grande sous le doigt (« elle peut devenir comme tu as fait quand on
    /// drag, avant de se transformer en pastille »). Le gonflement est un
    /// @GestureState exprès : SwiftUI le dégonfle LUI-MÊME quand le geste
    /// meurt, avec la transaction de reset ci-dessous — zéro minuteur,
    /// zéro remise à plat à écrire, et jamais une rentrée qui naît
    /// gonflée. Pendant le fondu de sortie (0,30 s), le dégonflement est
    /// recouvert par `matchedGeometryEffect` : l'île qui s'éteint suit
    /// déjà le cadre de la pastille.
    @GestureState(resetTransaction: Transaction(
        animation: .spring(response: 0.32, dampingFraction: 0.82)))
    private var doigtIle = false
    /// La translation déjà consommée au moment de la sortie — le doigt a
    /// pu bouger de quelques points avant que la pastille naisse ; sans
    /// cette soustraction elle SAUTE d'autant à la première image.
    @State private var sortieTranslation: CGSize = .zero
    /// D'où le doigt est PARTI sur l'île (V2) — l'origine du seuil de
    /// sortie. Nil entre deux gestes ; remise à nil au relâcher et au
    /// chien de garde.
    @State private var origineIle: CGSize? = nil
    /// Le doigt actuel a tiré la pastille de l'île et la PORTE encore.
    @State private var enMainDepuisIle = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var ambianceFigee: Bool {
        figee || reduceMotion || PiluleBanc.sansSouffleIle || scenePhase != .active
            || ProtectionThermique.shared.ambianceAuRepos
    }

    var body: some View {
        Group {
            // La Live Activity système se masque quand Woop est ouverte.
            // Le repère tactile de l'app doit donc rester monté en séance.
            if surHome {
                ileHome
            } else {
                etatCourant
                    // Le geste survit au passage île → pastille. La prise
                    // définit sa zone ; le stop garde la priorité sur le tap.
                    .gesture(gesteSortieIle)
            }
        }
            .onChange(of: surHome) { _, _ in
                enMainDepuisIle = false
                origineIle = nil
                etat.gesteMort()
            }
            .onChange(of: doigtIle) { _, pose in
                // Le chien de garde de la maison : un drag peut mourir
                // sans `onEnded` — la pastille en main rejoint l'état
                // STABLE le plus proche (sa place commise). V2 : l'origine
                // du seuil se remet à plat aussi (le dégonflement, lui,
                // est automatique — c'est le reset du @GestureState).
                if !pose {
                    origineIle = nil
                    if enMainDepuisIle {
                        enMainDepuisIle = false
                        etat.gesteMort()
                    }
                }
            }
            // LE BANC DE LA SORTIE : elle sort toute seule, une fois, au
            // bout du délai demandé — le film peut alors la juger.
            .onAppear {
                guard let s = PiluleBanc.ileSortie else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + s) {
                    etat.sortirEnMain()
                }
            }
    }

    private var ileHome: some View {
        IleRespirante(departSeance: departSeance, figee: ambianceFigee,
                      chronoFigee: figee || scenePhase != .active,
                      gonflee: false, blanche: true, onStop: onStop)
            .contentShape(PriseIle())
            .onTapGesture(perform: onOuvrir)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Séance en cours")
            .accessibilityHint("Ouvrir le détail de la séance")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("ile-seance-home")
            .position(x: UIScreen.main.bounds.width / 2,
                      y: IleGeo.babyCentreY)
    }

    /// LE GESTE — voir le corps : gonfler + sortir + porter, d'un seul
    /// tenant. V2 (06-09) : la sortie ne part plus au TOUCH-DOWN mais au
    /// SEUIL (12 pt) ou au relâcher — c'est cette fenêtre qui fait
    /// exister la grande sous le doigt, « avant de se transformer en
    /// pastille ». Un tap garde exactement le contrat (posée dessous),
    /// avec en plus un accusé de réception visuel dès le contact.
    private var gesteSortieIle: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($doigtIle) { _, posé, tr in
                // Le premier événement GONFLE (fine → grande). La
                // transaction porte le ressort : c'est elle qui anime
                // frame, offsets et position de l'île.
                if !posé {
                    tr.animation = .spring(response: 0.32,
                                           dampingFraction: 0.78)
                }
                posé = true
            }
            .onChanged { v in
                if etat.dansIle, !enMainDepuisIle {
                    // Premier contact : on note d'où part le doigt.
                    // Rien ne sort encore — la capsule gonfle (updating).
                    // ⚠️ Pas `!doigtIle` comme témoin du premier événement :
                    // `updating` court AVANT `onChanged`, il est déjà vrai.
                    let origine = origineIle ?? v.translation
                    if origineIle == nil { origineIle = origine }
                    // LE SEUIL : le doigt TIRE — la pastille sort dans la
                    // main (la chaîne acquise du 05-09, inchangée).
                    let dx = v.translation.width - origine.width
                    let dy = v.translation.height - origine.height
                    guard dx * dx + dy * dy >= 12 * 12 else { return }
                    enMainDepuisIle = true
                    sortieTranslation = v.translation
                    Haptique.moyen()
                    etat.sortirEnMain()
                    etat.saisir()
                }
                guard enMainDepuisIle else { return }
                etat.suivre(CGSize(
                    width: v.translation.width - sortieTranslation.width,
                    height: v.translation.height - sortieTranslation.height))
            }
            .onEnded { v in
                origineIle = nil
                if etat.dansIle, !enMainDepuisIle {
                    // TAP (relâché sous le seuil) : la chaîne entière —
                    // baby → grande (le gonflement a joué sous le doigt)
                    // → la pastille NORMALE descend en vol matched se
                    // poser à sa place commise, ~au-dessus de la nav
                    // (07-09 : « et après elle devient notre pastille
                    // normale qu'on balade partout »).
                    Haptique.moyen()
                    etat.sortirEnMain(vers: .placeCommise)
                    return
                }
                guard enMainDepuisIle else { return }
                enMainDepuisIle = false
                etat.commettre(
                    velocity: CGSize(width: v.velocity.width,
                                     height: v.velocity.height),
                    dansUtile: utile,
                    hauteurUtile: max(utile.upperBound - utile.lowerBound, 1))
                Haptique.leger()
            }
    }

    @ViewBuilder private var etatCourant: some View {
        if etat.dansIle {
            // Le fondu croisé : la capsule se dissout dans la pastille
            // (et l'inverse) pendant que `matchedGeometryEffect` déplace
            // le cadre. Sans lui, le contenu SAUTE au milieu du voyage.
            //
            // ⚠️ LE FONDU EST ASYMÉTRIQUE (mesuré au film,
            // `tools/flow/films/sortie-ile.mov`, planche 8 img/s) : en
            // fondu symétrique sur le ressort de 0,72 s, il restait
            // ~0,7 s où les DEUX formes étaient à moitié éteintes — on
            // lisait « elle disparaît puis réapparaît », pas un voyage.
            // La forme qui ENTRE naît vite (0,16 s) pour être visible
            // pendant le trajet ; celle qui SORT s'éteint sur 0,30 s.
            ile.transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.16)),
                removal: .opacity.animation(.easeIn(duration: 0.30))))
        } else {
            ZStack {
                // LA CIBLE (demande Kathryn 04-09) : dès qu'on DÉPLACE la
                // pastille, un halo ROUGE + un petit DOIGT s'allument sur
                // l'île — « tu peux la déposer ici ».
                if etat.enDrag { CibleIle(utile: utile) }
                corps
            }
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeOut(duration: 0.16)),
                removal: .opacity.animation(.easeIn(duration: 0.30))))
        }
    }
}

/// LE HALO D'ACCUEIL DE L'ÎLE — visible seulement pendant le drag.
/// Il s'INTENSIFIE quand la pastille approche (le doigt sent qu'il
/// « chauffe »), et le petit doigt dit le geste.
///
/// ⚠️ C'EST UNE VUE À PART DEPUIS LE 04-09 (lot 2, cause n° 12). Il
/// vivait dans le corps de `PiluleVagabonde` et y lisait `etat.dessin`
/// — la position du doigt, écrite à CHAQUE événement et à chaque
/// battement d'écran. Lire une propriété d'`@Observable` dans un corps
/// rend TOUT ce corps dépendant : le halo faisait donc reconstruire la
/// pilule entière (contenu, robe, ombre, ticket) à chaque image du
/// drag. Isolé ici, il est le SEUL à se rejouer.
struct CibleIle: View {
    var utile: ClosedRange<CGFloat>
    private var etat: PiluleEtat { PiluleEtat.shared }

    var body: some View {
        // LE HALO BOUGE (demande Kathryn) : une horloge propre, deux
        // périodes désaccordées — il respire ET flotte légèrement, il
        // n'est jamais figé. Surface minuscule, aucune taille animée.
        // 20 Hz : il ne vit que le temps d'un drag, mais il vit PENDANT
        // le drag — c'est le pire moment pour prendre une image de plus.
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900)
            cibleCorps(t: t)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    @ViewBuilder
    private func cibleCorps(t: Double) -> some View {
        let rouge = Color(red: 1, green: 0.20, blue: 0.05)
        let braise = Color(red: 1, green: 0.54, blue: 0.18)
        let h = IleGeo.hauteur + 12
        let forme = RoundedRectangle(cornerRadius: h / 2, style: .continuous)
        // La proximité : 0 loin, 1 sur l'île (la pastille part du bas).
        let H = max(utile.upperBound - utile.lowerBound, 1)
        let yCourant = utile.lowerBound + etat.yRatio * H + etat.dessin.height
        let d = max(0, yCourant - IleGeo.centreY)
        let proche = max(0, min(1, 1 - d / 260))
        // Le souffle du halo (2,3 s) et son flottement (3,7 s) — deux
        // périodes qui ne repassent jamais ensemble.
        let souffle = 0.5 + 0.5 * sin(t * 2 * .pi / 2.3)
        let flot = sin(t * 2 * .pi / 3.7)
        let vif = 0.20 + 0.55 * Double(proche) + 0.18 * souffle
        VStack(spacing: 10) {
            ZStack {
                forme.inset(by: -10)
                    .fill(rouge)
                    .blur(radius: 22)
                    .opacity(vif)
                    .scaleEffect(1 + 0.10 * proche + 0.05 * souffle)
                forme
                    .strokeBorder(
                        LinearGradient(colors: [braise, rouge],
                                       startPoint: .top, endPoint: .bottom)
                            .opacity(0.45 + 0.40 * Double(proche)
                                     + 0.15 * souffle),
                        style: .init(lineWidth: 1.6, dash: [7, 6]))
            }
            .frame(width: IleGeo.largeur + 66, height: h)
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5 + 0.4 * Double(proche)
                                                + 0.1 * souffle))
                .shadow(color: rouge.opacity(0.8), radius: 6)
                .scaleEffect(0.9 + 0.2 * proche)
                .offset(y: -2.5 * souffle)     // le doigt fait signe
        }
        .offset(y: 3 * flot)                   // le halo flotte
        .position(x: UIScreen.main.bounds.width / 2, y: IleGeo.centreY)
    }
}

// La suite de la pilule — l'île, le corps, la robe, le ticket. (Elle
// vit en extension depuis que `CibleIle` s'est détachée : le halo
// devait sortir du corps pour cesser de le faire rejouer par image.)
extension PiluleVagabonde {

    /// L'ÎLE HABITÉE : la dégaine Live Activity — capsule noire qui
    /// englobe la Dynamic Island, CHRONO à gauche du trou, STOP à
    /// droite. LE PULSAR (v2, « 10× plus premium ») : plus aucun bloc
    /// qui clignote — un champ de braise en COUCHES qui respire sur des
    /// périodes désaccordées à plancher jamais nul (l'école du souffle
    /// du ruban : un sinus seul devient un clignotant), et des ÉCLATS
    /// BLANCS rares et brefs — le vrai battement d'un pulsar, jamais un
    /// métronome. UNE horloge, surface minuscule. Anti-brun : R = 1,00.
    private var ile: some View {
        // ⚠️ L'ÎLE NE SE REDESSINE PLUS, ELLE S'ANIME (05-09, voir
        // `LisereRespirant` §③ et la loi des rampes Animatable) :
        // l'horloge 15 Hz reconstruisait TOUT ileCorps — le médaillon et
        // ses dégradés angulaires, trois gaussiennes, le liseré — quinze
        // fois par seconde, PENDANT TOUTE LA SÉANCE, pour neuf opacités.
        // La forme animée garde l'IDENTITÉ des couches (flous cuits une
        // fois, médaillon et chrono jamais ré-évalués) et un conteneur
        // Animatable réapplique les mêmes formules — arithmétique
        // IDENTIQUE, y compris le saut du mod 900 (qui existait déjà).
        // ⚠️ Écart déclaré : l'origine de phase passe de l'horloge absolue
        // à l'instant d'armement. `-souffleHorloge` rejoue l'ancienne.
        Group {
            if SouffleBanc.horloge {
                // ⚠️ 15 Hz, PAS 30 (04-09, lot 2, cause n° 9) : un souffle
                // de braise sur une capsule de 49 pt ne se lit pas plus
                // fin à 30 — et c'est un cycle sur deux de rendu qui
                // disparaît.
                TimelineView(.animation(minimumInterval: 1.0 / 15.0,
                                        paused: ambianceFigee)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 900)
                    ileCorps(t: t, maintenant: tl.date)
                }
            } else {
                IleRespirante(departSeance: departSeance, figee: ambianceFigee,
                              chronoFigee: figee || scenePhase != .active,
                              gonflee: doigtIle, onStop: onStop)
            }
        }
        // ⚠️⚠️ LA PRISE DESCEND SOUS LE TROU — ELLE S'EST RETROUVÉE
        // ENFERMÉE (05-09, verdict téléphone : « j'ai masqué la
        // notification dans la Dynamic Island pendant un exercice, et
        // impossible de la ressortir, donc impossible de stopper la
        // séance »).
        //
        // LA CAUSE, mesurée au banc le 04-09 : le centre de l'île tombe à
        // y ≈ 30, c'est-à-dire DANS le trou physique de la Dynamic Island,
        // que le système se réserve — un toucher n'y arrive JAMAIS à
        // l'app. Il ne restait que la lèvre basse de la capsule, six
        // points de haut. Autant dire rien, et rien du tout à 8 img/s.
        //
        // La prise couvre maintenant la capsule PLUS 44 pt EN DESSOUS :
        // un tap « juste sous l'île » — le geste naturel — ouvre le
        // player, d'où le gros stop est accessible. Le dessin ne bouge
        // pas d'un pixel : c'est la ZONE TACTILE qui descend.
        .contentShape(PriseIle())
        .accessibilityElement(children: .contain)
        // ⚠️ LE CONTRAT DU 06-09 (il a remplacé « le tap ouvre le
        // player » du 04-09) : tap OU drag n'importe où sur le bloc → la
        // pastille SORT, posée juste dessous — le player s'ouvre depuis
        // ELLE. Et V2 : le premier contact GONFLE la capsule (fine →
        // grande), la sortie part au seuil ou au relâcher — voir
        // `gesteSortieIle`.
        // ⚠️⚠️ L'ÎLE N'A PLUS DE GESTE À ELLE (05-09, troisième passe) :
        // il vit sur le PARENT (`gesteSortieIle`), qui survit au
        // démontage de cette branche — voir `body`. La `contentShape`
        // ci-dessus reste : c'est elle qui définit OÙ le parent entend.
        // Le stop, lui, garde son `highPriorityGesture` : il gagne dans
        // son disque, comme partout.
        //
        // ⚠️ UNE SEULE SOURCE DE GÉOMÉTRIE À LA FOIS. Depuis que les deux
        // formes se FONDENT (le recouvrement de 0,30 s), l'île et la
        // pastille sont montées ENSEMBLE pendant la transition — deux
        // `matchedGeometryEffect` sources du même id au même instant, et
        // les cadres SAUTENT (le glitch connu, et « ça bug » sur toutes
        // les pages). `isSource:` tranche : la forme qui correspond à
        // l'état COURANT est la source, l'autre la suit en s'éteignant.
        .matchedGeometryEffect(id: "pilule-vol", in: vol,
                               isSource: etat.dansIle)
        // Le chrono et le stop restent à y33, de part et d'autre du
        // capteur. Le contact élargit le contour sans abaisser son contenu.
        .position(x: UIScreen.main.bounds.width / 2,
                  y: doigtIle || SouffleBanc.horloge
                      ? IleGeo.capsuleCentreY : IleGeo.babyCentreY)
        .accessibilityIdentifier("seance-ile")
    }

    // ⚠️ LA POIGNÉE EST MORTE (verdict Kathryn 05-09 : « enlève le
    // trait sous le display island, ça sert à rien »). Elle avait vécu
    // trois heures : une barre sous la capsule qui faisait signe à
    // l'arrivée et à chaque série. Ce qui fait comprendre qu'on peut la
    // tirer, ce n'est pas un dessin — c'est le VOL qu'on a vu à l'aller,
    // et une sortie qui répond au premier doigt (ci-dessous).

    /// Le souffle principal : deux périodes premières entre elles,
    /// plancher 0,32 — la braise ne meurt jamais, elle COUVE.
    private static func souffle(_ t: Double) -> Double {
        0.62 + 0.25 * sin(t * 2 * .pi / 4.1)
             + 0.13 * sin(t * 2 * .pi / 6.7 + 1.3)
    }

    /// L'éclat : le BATTEMENT du pulsar — un pic bref (sinus élevé au
    /// cube, ne garde que les crêtes), sur sa propre période.
    private static func eclat(_ t: Double) -> Double {
        let s = max(0, sin(t * 2 * .pi / 5.3 + 0.7))
        return s * s * s
    }

    @ViewBuilder
    private func ileCorps(t: Double, maintenant: Date) -> some View {
        let braise = Color(red: 1, green: 0.54, blue: 0.18)
        let rouge = Color(red: 1, green: 0.20, blue: 0.05)
        // LA CAPSULE D'APPEL (go Kathryn 06-09, la carte du toucher au
        // banc réel : y 5→54 MORT sur toute la largeur, vivant sûr dès
        // ~y 70). L'ancienne capsule-anneau posait le stop et le chrono
        // dans une zone où le doigt n'existe pas — « la pop-up stop
        // JAMAIS » : il n'avait jamais été tapable, et personne ne
        // l'avait su avant de mesurer.
        let forme = RoundedRectangle(cornerRadius: 34, style: .continuous)
        let s = Self.souffle(t)
        let s2 = Self.souffle(t * 0.77 + 210)      // la nappe large, déphasée
        let e = Self.eclat(t)
        VStack(spacing: 0) {
            // LA TÊTE — le trou physique vit ici : on ne peint rien
            // dessus, et on n'y pose RIEN d'interactif (zone morte).
            Spacer().frame(height: IleGeo.hauteur + 14)
            // LE PONT BAS — la partie VIVANTE. Stop à gauche (un vrai
            // bouton, enfin), chrono à droite ; et tout tap ou drag sur
            // la capsule sort la pastille (le geste du parent).
            HStack(spacing: 0) {
                MedaillonStop(lueur: true, action: {
                    Haptique.moyen()
                    onStop()
                })
                    .scaleEffect(0.76)
                    .frame(width: 48, height: 36)
                    .shadow(color: braise.opacity(0.25 + 0.3 * s), radius: 5)
                Spacer(minLength: 8)
                Text(Self.chrono(depuis: departSeance, a: maintenant))
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.80 + 0.2 * e))
                    .shadow(color: .white.opacity(0.35 * e), radius: 3)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
        .frame(width: IleGeo.capsuleLargeur, height: IleGeo.capsuleH)
        // LE CHAMP DE BRAISE, en couches — du serré au large (inchangé,
        // simplement porté par la nouvelle forme : zéro moteur de plus) :
        .background {
            // ① la nappe ROUGE profonde, large et lente (la couveuse)
            forme.inset(by: -8)
                .fill(rouge)
                .blur(radius: 24)
                .opacity(0.06 + 0.16 * s2)
            // ② le bloom ORANGE→ROUGE, le corps du pulse
            forme.inset(by: -3)
                .fill(LinearGradient(colors: [braise, rouge],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .blur(radius: 12)
                .opacity(0.10 + 0.26 * s)
            // ③ le CŒUR blanc-chaud — l'éclat rare et bref du pulsar
            forme
                .fill(Color.white)
                .blur(radius: 6)
                .opacity(0.55 * e)
        }
        .background(forme.fill(Color.black))
        // Le liseré : la lumière vient d'EN HAUT (la loi des dalles).
        .overlay {
            forme.strokeBorder(
                LinearGradient(stops: [
                    .init(color: .white.opacity(0.55 + 0.45 * e), location: 0),
                    .init(color: braise.opacity(0.55 + 0.30 * s), location: 0.45),
                    .init(color: rouge.opacity(0.35 + 0.25 * s), location: 1)
                ], startPoint: .top, endPoint: .bottom),
                lineWidth: 1.1)
        }
        // ⚠️ LE RAYON D'OMBRE EST FIXE (04-09) : le souffle passe dans
        // l'OPACITÉ — une gaussienne à rayon vivant ne se met pas en cache.
        .shadow(color: braise.opacity(0.18 + 0.30 * s), radius: 9)
        .shadow(color: .white.opacity(0.30 * e), radius: 4)
    }

    /// L'ÎLE QUI RESPIRE SANS SE REDESSINER — la feuille qui ARME. La
    /// phase (un temps qui court de 0 à 900 s en linéaire, rebouclé) vit
    /// ici ; `figee` désarme par Transaction (aucun fondu parasite pendant
    /// que le player monte — la raison d'être de `figee`).
    private struct IleRespirante: View {
        var departSeance: Date
        var figee: Bool
        /// Le chrono reste exact même si la chaleur ou Reduce Motion
        /// immobilisent les lueurs. Il dort seulement hors de vue.
        var chronoFigee: Bool
        /// V2 (06-09) : un doigt est posé sur l'île — la capsule est
        /// GRANDE. Au repos elle est FINE. Le bool vient du @GestureState
        /// du parent : il se dégonfle tout seul quand le geste meurt.
        var gonflee: Bool
        var blanche: Bool = false
        var onStop: () -> Void

        @State private var tAnim: Double = 0

        var body: some View {
            // ⚠️ Le médaillon et le chrono sont construits ICI, une fois
            // par (rare) ré-évaluation, et passés en VALEURS au décor :
            // le body Animatable tourne à chaque image, et une closure
            // re-créée là-bas rendrait le médaillon « inégalable, re-rendu
            // à chaque passage » (la leçon DemandesCards). Une valeur
            // stockée inchangée reste prouvablement égale.
            IleDecor(
                t: figee ? 0 : tAnim,
                gonflee: gonflee,
                blanche: blanche,
                figee: figee,
                medaillon: Image(systemName: "stop.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white.opacity(0.08)))
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 0.8))
                    .frame(width: 54, height: 58)
                    .contentShape(Rectangle())
                    .highPriorityGesture(TapGesture().onEnded {
                        Haptique.moyen()
                        onStop()
                    })
                    .accessibilityLabel("Arrêter la séance")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("seance-ile-stop"),
                // LE CHRONO — un contenu qui change à 1 Hz : sa PROPRE
                // horloge, serrée sur le seul Text (l'école du .periodic
                // du GrandPlayer).
                chrono: TimelineView(.animation(minimumInterval: 1.0,
                                                paused: chronoFigee)) {
                    [departSeance] tl in
                    Text(PiluleVagabonde.chrono(depuis: departSeance,
                                                a: tl.date))
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .accessibilityIdentifier("seance-ile-chrono")
                })
                // Retirer l'identité animée arrête effectivement la rampe
                // infinie au repos ; le geste reste sur son parent stable.
                .id(figee && PiluleBanc.haloSwiftUI)
                .task(id: figee) {
                    if PiluleBanc.haloSwiftUI { armer() }
                }
        }

        private func armer() {
            var tr = Transaction()
            tr.disablesAnimations = true
            guard !figee else {
                // Figée : on gèle où on est (l'ancien `paused:` gelait le
                // dernier dessin) — aucune écriture animée.
                withTransaction(tr) { tAnim = tAnim }
                return
            }
            withTransaction(tr) { tAnim = 0 }
            withAnimation(.linear(duration: 900)
                .repeatForever(autoreverses: false)) {
                tAnim = 900
            }
        }
    }

    /// Décor isolé : l'opacité anime des gradients et un flou de rayon
    /// constant. Chrono et stop gardent leur identité hors de cette rampe.
    private struct IleDecor<M: View, C: View>: View, Animatable {
        var t: Double
        /// V2 : fine (repos) ou grande (sous le doigt). ⚠️⚠️ JAMAIS dans
        /// `animatableData` — la loi n° 2 de la campagne du 05-09 : un
        /// attribut ne porte qu'UNE animation ; fusionné dans la paire,
        /// le ressort du gonflement REMPLACERAIT le `repeatForever` de
        /// 900 s du souffle. Le gonflement anime des attributs DISJOINTS
        /// (frame, offset, padding — la transaction du geste), `t` garde
        /// son animation à lui.
        var gonflee: Bool
        var blanche: Bool
        var figee: Bool
        let medaillon: M
        let chrono: C

        var animatableData: Double {
            get { t }
            set { t = newValue }
        }

        var body: some View {
            let souffle = PiluleVagabonde.souffle(t)
            let eclat = PiluleVagabonde.eclat(t)
            HStack(spacing: 0) {
                chrono.frame(width: 54)
                // 138 pt libres pour le capteur physique de 126 pt.
                Spacer(minLength: 138)
                medaillon
            }
            .frame(width: IleGeo.babyLargeur - 28, height: 58)
            .frame(width: gonflee ? IleGeo.capsuleLargeur : IleGeo.babyLargeur,
                   height: gonflee ? IleGeo.capsuleH : IleGeo.babyH)
            .background {
                if PiluleBanc.haloSwiftUI {
                    IleHaloTexture(souffle: souffle, eclat: eclat, blanche: blanche)
                } else {
                    IleHaloNatif(blanche: blanche, immobile: figee)
                }
            }
        }
    }


    // (La sortie vit désormais dans `PiluleEtat.sortirEnMain()` — UN seul
    //  chemin, que le doigt, le banc `-ileSortie` et demain le tuto
    //  empruntent pareil. Deux sorties finissent toujours par diverger.)

    private static func chrono(depuis: Date, a: Date) -> String {
        let s = max(0, Int(a.timeIntervalSince(depuis)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var corps: some View {
        let H = max(utile.upperBound - utile.lowerBound, 1)
        let y = utile.lowerBound + etat.yRatio * H
        return contenu()
            .frame(width: UIScreen.main.bounds.width - NotifGeo.margeH * 2,
                   height: Self.hauteur)
            .background { robe }
            .clipShape(Self.forme)
            .overlay { Self.forme.strokeBorder(Self.lisere, lineWidth: 1) }
            .compositingGroup()
            .shadow(color: .black.opacity(0.55), radius: 22, y: 10)
            // ⚠️ LE TICKET VIT APRÈS LE CLIP : dans le contenu il serait
            // coupé par la robe — c'est justement son DÉBORD qui le fait
            // lire comme un ticket qu'on peut tirer.
            .overlay(alignment: .bottom) { ticket }
            .contentShape(Self.forme)
            // ⚠️ LE DRAG D'ABORD, LE TAP ENSUITE — UN SEUL GESTE
            // EXCLUSIF (04-09, TROUVÉ AU BANC À VRAIS TOUCHERS).
            // C'étaient deux gestes séparés : `.onTapGesture` PUIS
            // `.gesture(drag)`. Or un `.gesture()` a une précédence
            // INFÉRIEURE aux gestes déjà posés sur le contenu : le TAP
            // gagnait. Un geste rapide sur la pastille (une main qui la
            // jette, pas une main qui la promène) était donc lu comme un
            // tap et OUVRAIT LE PLAYER au lieu de la déplacer — mesuré
            // au banc : 3 tentatives sur 3, la pastille n'a pas bougé
            // d'un pixel et le player s'est ouvert à chaque fois.
            // `exclusively(before:)` dit l'ordre une bonne fois : si le
            // doigt BOUGE, c'est un drag ; s'il ne bouge pas, c'est un
            // tap. (Le ticket garde son `highPriorityGesture` : un
            // descendant prioritaire bat toujours ce geste-ci.)
            //
            // ⚠️⚠️ ET C'EST UN `highPriorityGesture`, PAS UN `.gesture`
            // — LA CAUSE PREMIÈRE DE « IMPOSSIBLE DE CLIQUER SUR LA
            // BULLE » (04-09, mesurée au banc, sonde par sonde).
            // La robe pose un verre natif `.interactive()` : ce verre se
            // déforme sous le doigt, donc IL PREND LE TOUCHER. Il vit
            // dans le `.background` du corps, donc dans son CONTENU — et
            // un `.gesture()` a une précédence INFÉRIEURE aux gestes du
            // contenu. Résultat mesuré : une sonde `simultaneousGesture`
            // posée à l'extérieur comptait 9 événements de doigt pendant
            // que le geste de la pastille en comptait ZÉRO (chg=0,
            // tap=0). La pastille n'a JAMAIS été ni déplaçable ni
            // tapable ; seul le ticket répondait, parce que LUI est
            // prioritaire — et c'est lui qui ouvrait le player, ce qui
            // ressemblait à un tap qui marche.
            // (Le verre reste `.interactive()` : c'est ce qu'elle a
            //  demandé à voir au drag. On lui passe devant, on ne
            //  l'éteint pas.)
            .highPriorityGesture(
                // ⚠️ `.global`, JAMAIS l'espace local : la pilule BOUGE
                // avec le doigt — un drag lu dans son propre repère se
                // course lui-même (translation ≈ doigt MOINS vue) et
                // « glitche partout » (verdict Kathryn, J1 essai 1).
                DragGesture(minimumDistance: 6, coordinateSpace: .global)
                    .updating($doigtPose) { _, s, _ in s = true }
                    .onChanged { v in etat.suivre(v.translation) }
                    .onEnded { v in
                        etat.commettre(
                            velocity: CGSize(width: v.velocity.width,
                                             height: v.velocity.height),
                            dansUtile: utile, hauteurUtile: H)
                        Haptique.leger()
                    }
                    .exclusively(before: TapGesture().onEnded {
                        guard !etat.enVol, !etat.enDrag else { return }
                        Haptique.moyen()
                        onOuvrir()
                    }))
            .onChange(of: doigtPose) { _, pose in
                if !pose { etat.gesteMort() }
            }
            // LA POSITION COMMISE EST DU LAYOUT ; le dessin (drag + vol)
            // est un offset possédé par-dessus.
            .matchedGeometryEffect(id: "pilule-vol", in: vol,
                                   isSource: !etat.dansIle)
            .position(x: UIScreen.main.bounds.width / 2, y: y)
            // ⚠️ L'OFFSET VIT DANS UN MODIFIER (04-09, lot 2, cause
            // n° 11) — le patron exact d'`OffsetVol` du player
            // (PlayerMonde.swift). `.offset(etat.dessin)` posé ICI lisait
            // `dessin` DANS le corps : or `dessin` est écrit à chaque
            // événement du doigt PUIS à chaque battement d'écran pendant
            // le vol de rappel. Tout le corps en dépendait, donc SwiftUI
            // reconstruisait par image le contenu (mini-card, invite,
            // chrono, médaillon stop et ses deux dégradés angulaires), la
            // robe, le groupe de composition, l'ombre de rayon 22 et le
            // ticket. C'est le piège déjà payé, mot pour mot : un état
            // écrit par image sur la vue qui contient tout.
            .modifier(DessinPilule())
            .allowsHitTesting(!PlayerEtat.shared.monte)
            // La sonde passe par le MODIFIER (04-09, cause n° 8) : appelée
            // en direct, elle sautait la garde `-fps` et laissait un
            // `CADisplayLink` tourner en production.
            .sondeCadence("pilule")
            .accessibilityIdentifier("seance-pastille")
    }

    /// LE TICKET TIRABLE — gros, en débord au coin haut-droit. On peut
    /// le TIRER : il suit le doigt à l'élastique, et un tirage franc
    /// OUVRE le player (le geste qu'il promet à l'œil, il le tient).
    @ViewBuilder
    private var ticket: some View {
        if let texte = ticketTexte {
            // SOUS la pastille (verdict 04-09), à demi sorti : c'est le
            // débord qui dit « tire-moi ».
            // SANS icône et CENTRÉ sous la pastille (verdict 04-09).
            TicketSeries(texte: texte, echelle: 1.15)
                // ⚠️ LA DESCENTE DE 20 pt EST DU LAYOUT, PAS UN OFFSET
                // (04-09, TROUVÉ AU BANC — la loi payée le disait déjà :
                // « .offset déplace les PIXELS, pas la zone tactile »).
                // Le ticket était descendu par `.offset(y: 20)` : à l'œil
                // il pendait sous la pastille, mais sa PRISE était restée
                // 20 pt plus haut — c'est-à-dire EN PLEIN CENTRE de la
                // pastille, encore élargie de 10 pt par le contentShape.
                // Son `highPriorityGesture` bat celui de son ancêtre :
                // TOUT drag de la pastille était donc avalé par le
                // ticket, et son relâcher « franc » OUVRAIT LE PLAYER.
                // Mesuré : 4 formes de geste sur 4, la pastille n'a pas
                // bougé d'un pixel (chg=0, tap=0) et le player s'est
                // ouvert à chaque fois. La pastille n'a JAMAIS été
                // déplaçable — voilà « impossible de cliquer sur la
                // bulle » et « ça ouvre l'overlay tout seul ».
                // Seul le TIRAGE élastique reste un offset : pendant le
                // geste, la prise a le droit de ne pas suivre.
                .contentShape(Rectangle())
                // Le DÉBORD est du layout : la marge négative raccourcit
                // le cadre, donc le ticket sort de 20 pt sous la pastille
                // — et sa PRISE sort avec lui. (Un `.offset` aurait laissé
                // la prise 20 pt plus haut, en plein centre de la
                // pastille : c'est le bug qu'on vient de payer.)
                .padding(.bottom, -20)
                .offset(x: tire.width * 0.5, y: tire.height * 0.5)
                .rotationEffect(.degrees(-1 + Double(tire.width) * 0.06),
                                anchor: .top)
                // ⚠️ highPriorityGesture : il bat le drag de la pastille,
                // qui est son ANCÊTRE (la topologie maison).
                .highPriorityGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { v in
                            // Élastique : il suit, mais il résiste.
                            tire = CGSize(
                                width: v.translation.width * 0.5,
                                height: v.translation.height * 0.5)
                        }
                        .onEnded { v in
                            // ⚠️ ON TIRE UN TICKET VERS LE BAS (04-09).
                            // C'était « > 40 dans N'IMPORTE QUEL sens » —
                            // donc un geste vers le HAUT, celui qui range
                            // la pastille, ouvrait le player.
                            let franc = v.translation.height > 40
                            withAnimation(.spring(response: 0.34,
                                                  dampingFraction: 0.7)) {
                                tire = .zero
                            }
                            if franc {
                                Haptique.moyen()
                                onOuvrir()
                            }
                        })
        }
    }

    /// LA ROBE : le dégradé NOIR → TRANSPARENT sur le verre au REPOS
    /// (l'école du composant d'exercice du player, `VerreOuMat` — verre
    /// teinté noir) ; le NOIR PEINT pendant le mouvement (la loi des
    /// notifications ET du dépôt : un verre qui bouge = 60 → 14 img/s).
    @ViewBuilder
    private var robe: some View {
        // NOIR → TRANSPARENT : opaque en haut, il s'EFFACE vers le bas —
        // c'est par là que le verre se voit.
        // ⚠️ L'ENCRE S'ALLÈGE (04-09 : « il manque le verre natif ») —
        // à 0,90 en haut elle ÉTOUFFAIT le verre : on ne voyait le
        // liquid glass que dans le dernier tiers. Le dégradé reste noir
        // → transparent, mais il laisse le verre parler partout.
        let encre = LinearGradient(
            stops: [.init(color: .black.opacity(0.42), location: 0),
                    .init(color: .black.opacity(0.22), location: 0.5),
                    .init(color: .black.opacity(0.04), location: 1)],
            startPoint: .top, endPoint: .bottom)
        if etat.enMouvement && Self.mateAuDrag {
            // La doublure mate — le repli si la cadence ne tenait pas.
            Self.forme.fill(Color.black.opacity(0.72))
            Self.forme.fill(encre)
        } else {
            // AU REPOS : ⚠️ LE VERRE D'ABORD, L'ENCRE PAR-DESSUS — dans
            // l'autre ordre (payé) le dégradé opaque masquait le verre
            // et « le liquid glass ne se voyait pas ». C'est le verre du
            // composant d'exercice du player (VerreOuMat).
            Color.clear
                .glassEffect(
                    .regular.tint(Color.black.opacity(0.16)).interactive(),
                    in: .rect(cornerRadius: NotifGeo.rayon))
            Self.forme.fill(encre)
            // ⚠️ LA VAGUE EST MORTE ICI (go Kathryn 06-09, plan
            // PLAN-ILE-TOUCHABLE.md §3-④ : « allège », et UN SEUL FEU à
            // l'écran — le Foyer pose le sien sur la home en séance).
            // C'était un Canvas 9 colonnes + flou 11 + plusLighter à
            // 15 Hz, qui tournait TOUTE la séance dès que la pastille
            // était dehors — personne ne l'avait compté au budget de
            // chauffe. `BraisesVague` reste entier : le grand player
            // garde la sienne (c'est le détail, il est plein écran et
            // ne vit que le temps qu'on le regarde).
        }
    }
}

// MARK: - LE BANC : `-piluleLab`

enum PiluleBanc {
    static let actif = CommandLine.arguments.contains("-piluleLab")
    static let homeNoire = CommandLine.arguments.contains("-piluleLabHome")
    static let sansSouffleIle = CommandLine.arguments.contains("-sansSouffleIle")
    static let haloSwiftUI = CommandLine.arguments.contains("-ileHaloSwiftUI")
    static let haloDiscret = CommandLine.arguments.contains("-ileHaloDiscret")
    /// `-piluleSortie` : la séance démarre avec la pastille SORTIE de
    /// l'île (le régime d'avant le 05-09). Le simulateur ne drague pas :
    /// sans ce barreau, l'état « pastille dehors » — donc la page qui
    /// recule derrière elle — n'est pas capturable.
    static let horsIle = CommandLine.arguments.contains("-piluleSortie")
    static let piluleOuverte =
        CommandLine.arguments.contains("-piluleOuverte")
    /// `-ileSortie <s>` : la pastille SORT de l'île toute seule au bout de
    /// `s` secondes. Le simulateur ne tape pas — c'est le seul moyen de
    /// FILMER le morphing de sortie et de le juger image par image.
    static let ileSortie: Double? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-ileSortie"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return v
    }()
}

/// J1 du plan : la pilule SEULE sur une fausse page — drag partout,
/// pose bornée, recentrage à l'élan, tap, stop, doigt mort. La nav
/// FIXE rabaissée est esquissée en bas (le futur §2) et un faux galet
/// blanc se montre pour éprouver la borne basse.
struct PiluleLab: View {
    @State private var galetVisible = false
    @State private var ouvertures = 0
    @State private var stops = 0
    /// `nil` = aucun exercice choisi (l'invite en dégradé de blanc).
    @State private var exoChoisi: String? = nil
    /// LE MORPHISME (demande Kathryn) : 0 = la pastille, 1 = l'overlay
    /// plein écran. C'est une VALEUR CONTINUE, pas un booléen : la
    /// forme se DÉPLIE (largeur, hauteur, position, rayon) depuis les
    /// cotes exactes de la pastille — un transfert de matière, jamais
    /// une échelle uniforme (qui écrasait sa silhouette large).
    /// `-piluleOuverte` : le banc naît PLAYER OUVERT — le simulateur ne
    /// tape pas, et la tête du player (le nom balayé, la card du jour)
    /// n'était capturable qu'au doigt.
    /// ⚠️ PAS `-playerOuvert` : ce barreau EXISTE DÉJÀ et appartient à
    /// `PlayerMondeHote` (PlayerMonde.swift:374) — le lui voler ouvrait
    /// DEUX players à la fois. La loi de la maison vaut aussi pour les
    /// barreaux : on grep tous les sites d'un nom avant de le poser.
    @State private var morph: CGFloat = PiluleBanc.piluleOuverte ? 1 : 0
    /// LES TROIS ENTRÉES DU PLAYER, à essayer au doigt (04-09 : « propose
    /// une autre animation ») — AUCUNE ne met à l'échelle quoi que ce
    /// soit : Kathryn refuse le grossissement.
    @State private var style: StylePlayer = .glisse
    private var overlayOuvert: Bool { morph > 0.001 }
    private var setsFaits: Int {
        Self.groupesDemo.reduce(0) { $0 + $1.done }
    }
    /// La partition de démonstration — à l'intégration elle viendra de
    /// `groupesSeance()` : mêmes types, même composant, rien à réécrire.
    private static let groupesDemo: [SlateGroupe] = {
        Array(ExerciseCatalog.all.prefix(3)).enumerated().map { i, e in
            SlateGroupe(id: e.id, exercise: e, rows: (0..<4).map { j in
                SlateLigne(reps: 12, kilos: 20, seconds: 60,
                           done: i == 0 ? j < 2 : false)
            })
        }
    }()

    /// Le « départ de séance » du banc — le chrono de l'île court dessus.
    private let depart = Date().addingTimeInterval(-7 * 60)

    var body: some View {
        GeometryReader { g in
            // Coordonnées PHYSIQUES (l'île vit au-dessus de la zone sûre).
            // LA RÈGLE DE POSE BASSE, tranchée par Kathryn (04-09) :
            // « juste au-dessus » de la nav — jamais dessus. Le bas de la
            // pilule s'arrête à ~4 pt du haut de la rangée (nav : 44 de
            // glyphes + 26 d'assise = son haut à H−70 ; pilule demi-haute
            // 48 → centre max H−122). Le SURVOL en drag reste libre.
            let hautUtile: CGFloat = 130
            let basUtile: CGFloat = g.size.height - 122
            let m = 1 - pow(1 - min(max(morph, 0), 1), 3.0)
            ZStack {
                // ⚠️ CE QUI REND UNE FEUILLE CHÈRE : LE MONDE DERRIÈRE
                // RECULE (verdict 04-09 : « trop cheap »). Un glissement
                // seul reste plat ; ici la page s'éloigne, s'arrondit et
                // s'assombrit pendant que le player monte — la
                // profondeur des feuilles natives d'iOS. Ce sont des
                // effets de DESSIN (échelle, opacité), aucun layout.
                // ⚠️ LE FOND NE RECULE PLUS : il s'assombrit, c'est
                // tout. Kathryn refuse TOUT changement de taille à
                // l'écran (04-09) — la profondeur se dit ici par la
                // lumière, jamais par l'échelle.
                Group {
                    fauxFond
                    if galetVisible { fauxGalet }
                    navFixeEsquisse
                }
                .overlay {
                    Color.black.opacity(0.45 * Double(m))
                        .allowsHitTesting(false)
                }
                PiluleVagabonde(utile: hautUtile...basUtile,
                                departSeance: depart,
                                ticketTexte: "\(setsFaits) SETS",
                                surHome: PiluleBanc.homeNoire,
                                onOuvrir: {
                                    ouvertures += 1
                                    Haptique.leger()
                                    withAnimation(.spring(
                                        response: 0.62,
                                        dampingFraction: 0.86)) {
                                        morph = 1
                                    }
                                },
                                onStop: { stops += 1 }) {
                    fauxContenu
                }
                // La pastille appartient au monde d'en dessous : elle
                // recule et s'efface avec lui.
                .opacity(1 - Double(min(m * 2.2, 1)))
                // LE MORPHISME : l'overlay NAÎT de la pastille, où
                // qu'elle soit (l'ancre suit sa position réelle) —
                // c'est le rendu que Kathryn veut juger.
                if overlayOuvert {
                    GrandPlayer(
                        morph: $morph,
                        style: style,
                        ecranTaille: g.size,
                        ancreY: hautUtile + PiluleEtat.shared.yRatio
                            * (basUtile - hautUtile),
                        depart: depart,
                        exoChoisi: exoChoisi,
                        groupes: Self.groupesDemo,
                        onStop: { stops += 1 })
                }
                if !overlayOuvert { pupitre }
            }
        }
        // ⚠️ SUR LE GeometryReader, pas sur le ZStack : sinon le mètre
        // (g.size) mesure la zone SÛRE (759 pt) pendant que le contenu
        // s'étend plein écran (852) — toutes les bornes montaient de
        // ~93 pt (« j'arrive pas à la descendre », vérifié capture).
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }

    private var fauxContenu: some View {
        HStack(spacing: 10) {
            // LE MINI BADGE CALENDRIER — le MÊME objet que dans le
            // grand player (`MiniCardJour`, la vraie date + le sticker
            // du jour) : une seule matière d'un bout à l'autre.
            // L'IMAGE DU JOUR + LE BADGE DE SÉRIES (verdict 04-09) :
            // ⚠️ le badge est posé DANS la largeur réservée à la card —
            // en `offset` il MORDAIT sur le titre (« on voit plus le
            // texte, In session coupé sur 3 lignes »). Ici la colonne
            // fait 84 pt et le badge vit dedans, bien lisible.
            MiniCardJour(date: depart, sticker: "sticker-flamme")
                .scaleEffect(0.80)
                .frame(width: 68, height: 68)
                .frame(width: 74, height: 76)
            VStack(alignment: .leading, spacing: 3) {
                // LE TITRE (règle Kathryn 04-09) : sans exercice choisi,
                // l'INVITE en dégradé de blanc ; avec, le NOM. Le
                // sous-titre « In session » reste dans les deux cas.
                // Le titre se RÉDUIT plutôt que de se tronquer (verdict
                // 04-09 : « on voit plus le texte ») — jusqu'à 80 %.
                if let nom = exoChoisi {
                    Text(nom)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    // LA MÊME INVITE ANIMÉE QUE LE GRAND PLAYER.
                    // Le banc doit montrer l'état de PROD, sinon il
                    // mesure autre chose que l'app (loi de la maison).
                    InviteAnimee(taille: 17,
                                 fige: PiluleEtat.shared.enMouvement)
                        .minimumScaleFactor(0.8)
                }
                Text("In session · 7 min")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 10)
            // LE STOP — highPriorityGesture : il bat le drag qui
            // l'ENVELOPPE (un ancêtre), la topologie maison.
            // LE VRAI STOP DE L'ANCIEN PLAYER (`MedaillonStop`) — le
            // disque laqué, son liseré, sa lueur. Il porte DÉJÀ la forme
            // maison anti-Button (contentShape + highPriorityGesture) :
            // il bat le drag de la pilule, qui est son ANCÊTRE.
            // LE STOP — GROSSI (verdict 04-09 : « trop petit ») : il
            // est la seule action de la pastille, il doit se viser sans
            // regarder.
            // LE STOP — encore grossi (verdict 04-09, deuxième passe :
            // « beaucoup trop petit »). Il tient presque la hauteur de
            // la pastille : c'est SON action.
            // Gros à l'œil, SOBRE en largeur : son cadre de layout fait
            // 60 pt (le dessin déborde dedans) — sinon il mangeait la
            // place du titre (verdict 04-09 : « on voit plus le texte »).
            MedaillonStop(lueur: true, action: { stops += 1 })
                .scaleEffect(1.22)
                .frame(width: 60, height: 60)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
    }

    private var fauxFond: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 0.55, green: 0.12, blue: 0.04)
                                        .opacity(0.55), .clear],
                           center: .init(x: 0.3, y: 1.02),
                           startRadius: 10, endRadius: 430)
            VStack(alignment: .leading, spacing: 14) {
                Text("Hello Kathryn,")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
                Text("la pilule se drague partout —\nelle se pose où tu veux.")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
            }
            .padding(24)
            .padding(.top, 40)
        }
        .ignoresSafeArea()
    }

    /// LA NAV FIXE — LA VRAIE, plus une esquisse (04-09).
    /// ⚠️ Elle dessinait encore QUATRE glyphes et le point orange : un
    /// banc qui montre un écran qui n'existe plus est un juge qui ment.
    /// Elle monte maintenant `NavBande` avec la géométrie EXACTE du
    /// châssis (rangée de `navH`, 18 pt au-dessus du bord PHYSIQUE) —
    /// trois onglets, pas de braise.
    private var navFixeEsquisse: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            NavBande(hauteur: NavEtat.shared.navH)
                .padding(.bottom, 18)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Le faux galet blanc de la fiche — la zone que la POSE doit fuir.
    private var fauxGalet: some View {
        VStack {
            Spacer()
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(red: 1, green: 0.99, blue: 0.96),
                             Color(red: 0.72, green: 0.66, blue: 0.57)],
                    center: .init(x: 0.5, y: 1.1),
                    startRadius: 30, endRadius: 320))
                .frame(width: 430, height: 220)
                .offset(y: 120)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var pupitre: some View {
        VStack {
            HStack(spacing: 8) {
                Button {
                    galetVisible.toggle()
                } label: {
                    Text(galetVisible ? "fiche (galet)" : "page simple")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Color.white, in: Capsule())
                }
                Button {
                    exoChoisi = exoChoisi == nil
                        ? "Woodchopper poulie haute" : nil
                } label: {
                    Text(exoChoisi == nil ? "sans exo" : "avec exo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(exoChoisi == nil ? .white : .black)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(exoChoisi == nil
                                    ? Color.white.opacity(0.15) : Color.white,
                                    in: Capsule())
                }
                Button {
                    let tous = StylePlayer.allCases
                    let i = tous.firstIndex(of: style) ?? 0
                    style = tous[(i + 1) % tous.count]
                } label: {
                    Text(style.titre)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10).frame(height: 26)
                        .background(Color(red: 1, green: 0.7, blue: 0.3),
                                    in: Capsule())
                }
                Text("ouvrir ×\(ouvertures)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 70)
            Spacer()
        }
    }
}


/// Les trois entrées possibles du player — aucune ne grossit.
enum StylePlayer: String, CaseIterable {
    /// Il MONTE du bas, à sa taille finale. Rien ne change de taille.
    case glisse
    /// Il apparaît en FONDU, immobile. Le geste le plus sobre.
    case fondu
    /// Un RIDEAU le révèle du haut vers le bas, sur place.
    case rideau

    var titre: String {
        switch self {
        case .glisse: "glisse"
        case .fondu: "fondu"
        case .rideau: "rideau"
        }
    }
}

/// LE GRAND PLAYER (banc) — UNE VUE À PART, et c'est une LOI, pas un
/// rangement : `fermeture` s'écrit à 60 Hz pendant le drag. Laissé en
/// `@State` sur le banc, il ré-évaluait TOUTE la page à chaque image
/// (fond, pastille, les deux Canvas de braises) — le « glitch de ouf »
/// du 04-09, exactement le piège payé « un @State écrit par image sur
/// la vue qui contient tout ». Isolé ici, seul le player se rejoue.
struct GrandPlayer: View {
    @Binding var morph: CGFloat
    var style: StylePlayer = .glisse
    let ecranTaille: CGSize
    var ancreY: CGFloat = 0
    let depart: Date
    let exoChoisi: String?
    let groupes: [SlateGroupe]
    /// Le sticker du jour — la vraie mini-card de séance.
    var sticker: String = "sticker-flamme"
    var onStop: () -> Void = {}
    /// LE LECTEUR CHOISIT (22-09) : un exercice tapé dans une zone. Le
    /// player ne navigue pas, il rend l'intention à la racine.
    var onChoisirExo: (Exercise) -> Void = { _ in }
    /// CE QUE NOSFY PROPOSE (22-09) — calculé par la racine à l'ouverture,
    /// depuis l'historique réel. Vide = l'app n'a rien à proposer, et le
    /// lecteur le dit au lieu d'inventer.
    var propositions: [PropositionExo] = []
    /// La séance n'a encore aucun exercice : le lecteur s'ouvre sur la
    /// proposition, tête déjà repliée.
    var seanceVide: Bool = false

    @State private var fermeture: CGFloat = 0
    @State private var fermeturePrise = false
    @State private var deplies: Set<String> = []
    /// LA TÊTE REPLIÉE (22-09, verdict Kathryn : « le header de notre
    /// overlay au scroll peut devenir un mode petit pour laisser place
    /// aux catégories »). 0 la tête en grand — le ticket, le sticker, le
    /// ruban, le nom balayé, la session — 1 la tête en une ligne. C'est
    /// une VALEUR ANIMABLE, jamais deux vues échangées : le ticket
    /// rétrécit, il ne disparaît pas (la loi du 05-09, « redessiner pour
    /// animer coûte 3 à 8 fois plus qu'animer »).
    @State private var repli: CGFloat = GrandPlayer.bancRepli
    /// L'exercice déjà lancé depuis CE lecteur : sa rangée de proposition
    /// se coche sans attendre l'aller-retour SwiftData.
    @State private var lances: Set<String> = []
    /// La zone ouverte : ses exercices remplacent la partition, dans le
    /// MÊME composant. `nil` = la séance.
    @State private var zone: ExerciseCategory? = GrandPlayer.bancZone

    /// `-lecteurReplie` : le player naît TÊTE REPLIÉE, carrés visibles —
    /// le simulateur ne glisse pas la partition.
    /// `-lecteurZone <n>` : la zone `n` ouverte (0 Haut … 4 Cardio).
    static let bancRepli: CGFloat =
        (CommandLine.arguments.contains("-lecteurReplie")
         || bancZone != nil) ? 1 : 0
    static let bancZone: ExerciseCategory? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-lecteurZone"), i + 1 < a.count,
              let n = Int(a[i + 1]),
              ExerciseCategory.allCases.indices.contains(n) else { return nil }
        return ExerciseCategory.allCases[n]
    }()

    private var setsFaits: Int { groupes.reduce(0) { $0 + $1.done } }
    private var setsTotal: Int { groupes.reduce(0) { $0 + $1.rows.count } }
    private var exoCourant: SlateGroupe {
        groupes.first(where: { $0.done < $0.rows.count }) ?? groupes[0]
    }
    #if DEBUG
    static let crieGeste = CommandLine.arguments.contains("-dragSonde")
    nonisolated(unsafe) static var dernierGeste: Double = 0
    nonisolated(unsafe) static var dernierY: CGFloat = 0
    #endif
    private static var margeHaute: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.safeAreaInsets.top) ?? 59
    }

    /// LE GRAND PLAYER — LE VRAI MORPHISME : il naît aux COTES EXACTES
    /// de la pastille (largeur, 96 pt, rayon 28, position) et se DÉPLIE
    /// jusqu'au plein écran, rayon vers 0. Chaque dimension est
    /// interpolée à part : la silhouette large est respectée tout du
    /// long (une échelle uniforme l'écraserait).
    ///
    /// LE CONTENU est celui de l'ANCIEN player (verdict Kathryn) : la
    /// mini-card du jour + le badge de séries en tête, le nom d'exercice
    /// (ou l'invite animée), les FLAMMES CONDENSÉES avec la session et
    /// le chrono à la place de la barre, puis la partition qui scrolle
    /// SOUS un en-tête FIXE. Ce qui change : le morphisme et les
    /// braises.
    var body: some View {
        let ecran = ecranTaille
        _ = ancreY
        let e = min(max(morph, 0), 1)
        // ⚠️ RIEN NE GRANDIT (verdict Kathryn 04-09 : « je veux pas que
        // ça grandisse, c'est horrible ») : le player MONTE DU BAS d'un
        // seul bloc, à sa taille finale, et redescend de même. L'aller
        // et le retour sont LE MÊME mouvement — c'est ce qui le rend
        // évident sous le doigt (l'école Spotify, celle de sa fermeture).
        // Le contenu n'est donc jamais remis en page : zéro reflow.
        let d = 1 - pow(1 - e, 3.0)          // décolle vite, se pose doux
        let enGeste = fermeture > 0.5
        let tir = min(fermeture / 140, 1)
        // ⚠️ AUCUN GROSSISSEMENT, dans AUCUN style (verdict 04-09,
        // répété : « il grossit, c'est horrible »). Le player est
        // TOUJOURS à sa taille finale ; seul CHANGE la façon dont il
        // arrive : il monte, il se fond, ou un rideau le révèle.
        let montee = style == .glisse ? (1 - d) * ecran.height : 0
        let opac = style == .glisse ? min(1, d * 2.2)
            : (style == .fondu ? d : 1)
        let encre = style == .rideau ? 1 : min(1, d * 2.2)
        let rayon = NotifGeo.rayon * max(style == .glisse ? 1 - d : 0, tir)
        return ZStack {
            LinearGradient(colors: [Color(white: 0.07), .black],
                           startPoint: .top, endPoint: .bottom)
            // ⚠️ 15 Hz ET GELÉE HORS POSE (relecture adverse 04-09) :
            // celle-ci est PLEIN ÉCRAN — la plus chère de l'app. Elle
            // était restée à 30 alors que la mini est passée à 15, et
            // elle tournait pendant tout le geste de fermeture.
            BraisesVague(force: 0.62,
                         fige: enGeste || morph < 0.98, hz: 15)
                .opacity(Double(encre))
            VStack(spacing: 0) {
                teteFixe(encre: encre, enGeste: enGeste)
                // LES CINQ ZONES — elles n'apparaissent QUE quand la tête
                // s'est repliée : deux bandeaux pleins au-dessus de la
                // liste, c'est ce qui rendrait l'écran lourd.
                // ⚠️ LES CARRÉS SONT TOUJOURS LÀ. Point. (Verdict Kathryn
                // 22-09, deux fois : « il faut que ce soit fluide, le fait
                // d'avoir le résumé ET le fait de pouvoir ajouter un exo »,
                // puis « après le Go il manque dans l'overlay la catégorie
                // abdos et tout, tous les carrés là ! ».)
                //
                // Ils ont été conditionnels deux fois, et deux fois c'était
                // faux : d'abord au repli de la tête — donc invisibles tant
                // qu'on n'avait pas scrollé —, puis seulement devant la
                // partition — donc absents juste après le Go, au moment
                // précis où l'on choisit. Une porte qui n'est pas toujours
                // au même endroit n'est pas une porte.
                barreZones
                // LA CARTE « SUIVANT » EST DESCENDUE DANS LE PIED (22-09) :
                // elle y était en double avec le bouton d'action, et elle
                // mangeait 74 pt au-dessus de la partition.
                contenu.scrollDisabled(enGeste)
                    .modifier(BancBoucleLecteur(tape: {
                        if let p = propositions.first { lancer(p.exercise) }
                    }))
            }
            .opacity(Double(encre))
            .overlay(alignment: .bottom) {
                piedExercices(encre: encre, enGeste: enGeste)
            }
        }
        .frame(width: ecran.width, height: ecran.height)
        .clipShape(RoundedRectangle(cornerRadius: rayon, style: .continuous))
        // LE RIDEAU : un masque qui DESCEND et révèle le player sur
        // place — il ne bouge pas, il se dévoile.
        .mask {
            if style == .rideau {
                VStack(spacing: 0) {
                    Rectangle().frame(height: ecran.height * d)
                    Color.clear
                }
            } else {
                Rectangle()
            }
        }
        .opacity(Double(opac))
        .overlay {
            RoundedRectangle(cornerRadius: rayon, style: .continuous)
                .strokeBorder(.white.opacity(0.12 * tir), lineWidth: 1)
        }
        // LA MONTÉE + LE DOIGT, dans le MÊME offset : des pixels,
        // jamais un layout (la loi payée).
        // ⚠️ UN SEUL OFFSET (04-09, lot 2). Il y en avait DEUX :
        // `.offset(y: montee + fermeture)` puis `.offset(y: fermeture)` —
        // le doigt était compté deux fois et l'écran descendait au DOUBLE
        // de sa vitesse. Le commentaire du second parlait encore d'un
        // `.position` qui n'existe plus : c'était un résidu.
        // Le drag bouge des PIXELS, jamais un layout (la loi payée) :
        // `position` re-mesurait tout l'arbre à chaque image — dont le
        // GeometryReader de la partition. C'était le « glitch de ouf ».
        .offset(y: montee + fermeture)
        .simultaneousGesture(dragFermeture)
        // LA MESURE (loi : une sonde qui mesure, pas un juge qui
        // affirme) — `-fps` imprime la cadence RÉELLE du player, et
        // `dragSonde` l'intervalle entre deux événements du doigt : on
        // saura si le trou est au RENDU ou dans les ÉVÉNEMENTS.
        // ⚠️ PAR LE MODIFIER : appelée en direct, elle sautait la garde.
        .sondeCadence("player-morph")
        .accessibilityIdentifier("seance-detail")
        // LA SÉANCE EST VIDE : le lecteur s'ouvre TÊTE REPLIÉE, carrés
        // visibles, la proposition de Nosfy dessous — il n'y a rien
        // d'autre à montrer, et c'est exactement ce qu'on veut après le Go.
        // ⚠️ LA GRANDE TÊTE EST L'ÉTAT DE REPOS (verdict Kathryn 22-09 :
        // « et la vue qu'on avait de base avec le gros sticker ? »). Le
        // lecteur s'ouvre AVEC sa carte du jour en grand, son sticker
        // flamme, son ticket de séries et son nom balayé — le composant
        // qu'elle a dessiné et qui vit aussi sur la page noire.
        //
        // Il ne se replie QU'AU SCROLL, et c'est sa règle à elle : « le
        // header de notre overlay au scroll peut devenir un mode petit pour
        // laisser place aux catégories ». Les cinq carrés sont donc la
        // récompense du geste, pas ce qui chasse le sticker d'entrée.
        //
        // (Avant, un `onAppear` repliait la tête dès que la séance était
        //  vide : on n'a JAMAIS vu la grande tête au départ.)
        .onDisappear { CouvertureFoyer.shared.retirer() }
    }

    /// L'EN-TÊTE FIXE — il ne scrolle jamais, et c'est LUI qui porte le
    /// drag-pour-fermer (la partition garde son scroll : chacun sa zone).
    private func teteFixe(encre: CGFloat, enGeste: Bool) -> some View {
        // LE REPLI, EN GÉOMÉTRIE PURE : une seule valeur pilote la taille
        // du ticket, la fonte du nom, l'air autour. Aucune vue n'est
        // montée ni démontée pendant le scroll.
        let r = repli
        let carte: CGFloat = 150 - 108 * r        // 150 → 42
        let echelle: CGFloat = 1.55 - 1.15 * r    // 1,55 → 0,40
        let nom: CGFloat = 1 - r                  // le grand nom s'efface
        return VStack(spacing: 10 - 5 * r) {
            Capsule().fill(.white.opacity(0.22))
                .frame(width: 40, height: 5)
                // LA VRAIE MARGE HAUTE : le banc ignore la zone sûre,
                // donc `safeAreaInsets` y vaut 0 — sans cette mesure au
                // niveau de la FENÊTRE, la tête passait SOUS l'île
                // (verdict 04-09 : « le haut est trop haut, caché »).
                .padding(.top, Self.margeHaute + 30)
            // LA MINI-CARD DU JOUR + LE BADGE DE SÉRIES (l'ancien player).
            // L'IMAGE DU JOUR + LE BADGE, BEAUCOUP plus grands (verdict
            // 04-09) : c'est la pièce maîtresse de la tête.
            teteLigne(carte: carte, echelle: echelle, r: r, nom: nom)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(dragFermeture)
    }

    /// LA LIGNE DE TÊTE — en grand elle est une colonne (ticket, nom,
    /// session), repliée elle devient une rangée : la vignette, le nom et
    /// le chrono, le ruban à droite. Les MÊMES vues dans les deux cas.
    @ViewBuilder
    private func teteLigne(carte: CGFloat, echelle: CGFloat,
                           r: CGFloat, nom: CGFloat) -> some View {
        if r > 0.5 {
            // ⚠️ L'AIR EST UN MATÉRIAU (verdict 22-09 : « plus d'espace,
            // aéré à la Apple »). Les cotes d'un en-tête compact iOS : la
            // gouttière à 24, le titre qui respire, le ruban qui ne
            // l'écrase pas.
            HStack(spacing: 14) {
                miniCarte(carte: carte, echelle: echelle, r: r)
                VStack(alignment: .leading, spacing: 3) {
                    titreOverlay(16)
                    chronoSession.font(.system(size: 11, weight: .medium))
                }
                Spacer(minLength: 10)
                TicketSeries(texte: "\(setsFaits) SETS", echelle: 0.58)
                    .fixedSize()
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 20)
        } else {
            miniCarte(carte: carte, echelle: echelle, r: r)
            titreOverlay(25).padding(.top, 2).opacity(Double(nom))
            chronoSession.padding(.top, 2).padding(.bottom, 14)
        }
    }

    private func miniCarte(carte: CGFloat, echelle: CGFloat,
                           r: CGFloat) -> some View {
        MiniCardJour(date: depart, sticker: sticker)
            .scaleEffect(echelle)
            .frame(width: carte, height: carte)
                // LE TICKET DE PAPIER — il RESTE ici, dans le DÉTAIL
                // (verdict Kathryn 05-09, correction du même jour : « il
                // fallait pas enlever le ticket avec le nombre de sets
                // total sur le détail de la session ; il fallait
                // n'enlever que sur la pastille, et enlever SON
                // ANIMATION »). C'est donc son talon qui s'est tu (voir
                // `TicketSeries`), pas le ticket.
            // LE TICKET DE PAPIER reste collé à la carte tant qu'elle est
            // grande ; replié, il passe à droite de la ligne (voir
            // `teteLigne`), jamais il ne disparaît.
            .overlay(alignment: .trailing) {
                TicketSeries(texte: "\(setsFaits) SETS", echelle: 0.95)
                    .rotationEffect(.degrees(-4))
                    .offset(x: 44, y: 10)
                    .opacity(Double(1 - r))
            }
            .padding(.top, 10 - 8 * r)
    }
            // ⚠️ À LA PLACE DE LA BARRE (verdict Kathryn) : les FLAMMES
            // condensées, la session en cours et le chrono, sur une
            // ligne. Les flammes sont GELÉES (t constant : aucune
            // horloge de plus, la loi de la partition).
            // (La ligne de braises sous le titre est RETIRÉE — verdict
            //  04-09 : « ça fait lourd ». La vague du bas suffit à dire
            //  que ça tourne ; ici, le chrono seul.)
    /// LE CHRONO DE SESSION — une seule horloge, la même dans les deux
    /// tailles de tête.
    private var chronoSession: some View {
        TimelineView(.periodic(from: depart, by: 1)) { tl in
            let s = max(0, Int(tl.date.timeIntervalSince(depart)))
            Text("session · \(s / 60):\(String(format: "%02d", s % 60))")
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
        }
        .font(.system(size: 13, weight: .medium))
    }

    /// LA PARTITION — le vrai composant de l'ancien player.
    ///
    /// ⚠️ SANS ScrollView AUTOUR : `SlateListe` porte DÉJÀ le sien (et
    /// un `GeometryReader` qui impose la largeur, SessionSlate.swift:295).
    /// Emboîtée dans un second scroll, son GeometryReader recevait une
    /// hauteur proposée NULLE et la liste disparaissait — l'écran noir
    /// du 04-09. Elle prend ici la place restante du VStack, comme dans
    /// `ScenePlayer`. Le clic-pour-déplier revient avec elle (l'état
    /// `deplies` vit chez l'hôte, la loi payée).
    /// CE QUE MONTRE LE LECTEUR : ta séance, ou les exercices d'une zone.
    /// Le MÊME cadre, le même masque, la même place — seul le contenu
    /// change (verdict 22-09 : « ça remplace les rangées, dans le même
    /// composant, on ne change pas d'écran »).
    /// CE QUE MONTRE LE LECTEUR, dans l'ordre : la zone qu'on vient
    /// d'ouvrir, sinon la proposition de Nosfy tant que la séance est
    /// vide, sinon ta partition.
    @ViewBuilder
    private var contenu: some View {
        if let z = zone {
            listeZone(z)
        } else if seanceVide, !propositions.isEmpty {
            listePropositions
        } else {
            partition
        }
    }

    /// LA PROPOSITION DE NOSFY — la zone du jour et ses charges, lues dans
    /// l'historique. Un tap lance. « Choisir autre chose » n'est pas un
    /// bouton : les cinq carrés sont juste au-dessus.
    private var listePropositions: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                enTetePropose
                ForEach(propositions) { p in
                    RangeeZoneLecteur(exercise: p.exercise,
                                      detail: p.detail(),
                                      lance: lances.contains(p.exercise.id))
                        .contentShape(RoundedRectangle(cornerRadius: 14,
                                                       style: .continuous))
                        .highPriorityGesture(TapGesture().onEnded {
                            lancer(p.exercise)
                        })
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 2)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
        .transition(.opacity)
        .mask(Self.fondu)
    }

    private var enTetePropose: some View {
        HStack(spacing: 8) {
            Text("Nosfy propose")
                .font(.inter(10.5, .semibold))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
            if let z = propositions.first?.exercise.category {
                Text(z.rawValue)
                    .font(.inter(10.5, .medium))
                    .foregroundStyle(.white.opacity(0.32))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 12)
    }

    /// AJOUTER UN EXERCICE, DEPUIS LE BAS DE LA SÉANCE — on ouvre
    /// directement la zone où l'on travaille : un tap pour une liste, au
    /// lieu de deux. Sans exercice en cours, on rend simplement les
    /// carrés. ⚠️ Il OUVRE une liste, il ne choisit RIEN : c'est elle qui
    /// choisit, toujours.
    private func ajouterUnExercice() {
        Haptique.leger()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
            zone = zoneCourante
            repli = 1
        }
    }

    /// La zone où l'on est : celle du dernier exercice de la séance, sinon
    /// celle que Nosfy avait proposée.
    private var zoneCourante: ExerciseCategory? {
        groupes.last?.exercise.category ?? propositions.first?.exercise.category
    }

    /// LANCER UN EXERCICE — LE CHANGEMENT SE FAIT SOUS LE BLANC (22-09).
    /// Avant : le lecteur descendait, l'onglet basculait, la fiche montait
    /// — trois mouvements décalés, et la page Exercices visible entre deux.
    /// Maintenant, la coupe tient l'écran et tout bascule derrière elle.
    #if DEBUG
    /// `-boucleAuto` — le banc tape le bouton du pied à notre place. Une
    /// seule fois : sans le verrou, le lecteur relancerait un exercice à
    /// chaque retour et la boucle ne s'arrêterait jamais.
    nonisolated(unsafe) static var boucleFaite = false
    static let bancBoucle = ProcessInfo.processInfo.arguments
        .contains("-boucleAuto")
    #endif

    private func lancer(_ exo: Exercise) {
        Haptique.moyen()
        lances.insert(exo.id)
        CoupeEtat.shared.jouer {
            onChoisirExo(exo)
            poserFerme()
        }
    }

    /// Le même fondu pour les listes d'exercices. Leur pied ne porte que
    /// le Stop, donc il peut descendre un peu plus bas que celui de la
    /// partition.
    private static let fondu = LinearGradient(stops: [
        .init(color: .clear, location: 0),
        .init(color: .black, location: 0.04),
        .init(color: .black, location: 0.80),
        .init(color: .clear, location: 0.90)
    ], startPoint: .top, endPoint: .bottom)

    /// LA BARRE DES ZONES — les carrés anatomiques de la bibliothèque,
    /// en petit. Un tap ouvre la zone ; un second la referme et rend la
    /// séance.
    private var barreZones: some View {
        HStack(spacing: 10) {
            ForEach(ExerciseCategory.allCases) { z in
                CarreZoneMini(zone: z, choisie: zone == z)
                    .contentShape(RoundedRectangle(cornerRadius: 13,
                                                   style: .continuous))
                    .highPriorityGesture(TapGesture().onEnded {
                        Haptique.leger()
                        withAnimation(.spring(response: 0.34,
                                              dampingFraction: 0.84)) {
                            zone = (zone == z) ? nil : z
                            repli = 1
                        }
                    })
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 22)
    }

    /// LES EXERCICES D'UNE ZONE — une rangée par exercice, la vignette,
    /// le nom, le muscle. Un tap LANCE : le player rend l'intention et
    /// se referme.
    private func listeZone(_ z: ExerciseCategory) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(ExerciseCatalog.exercises(in: z)) { exo in
                    RangeeZoneLecteur(exercise: exo,
                                      detail: exo.muscle,
                                      lance: lances.contains(exo.id))
                        .contentShape(RoundedRectangle(cornerRadius: 14,
                                                       style: .continuous))
                        .highPriorityGesture(TapGesture().onEnded {
                            lancer(exo)
                        })
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 2)
            .padding(.bottom, 150)
        }
        .scrollIndicators(.hidden)
        .transition(.opacity)
        .mask(Self.fondu)
    }

    private var partition: some View {
        SlateListe(groupes: groupes,
                   courant: groupes.first?.id ?? "",
                   // ⚠️ LA PLACE DU PIED EST RÉSERVÉE (mesuré au banc
                   // 22-09) : à 120, le bouton d'action et le Stop
                   // flottaient par-dessus « Set 3 » et la rangée 02 — le
                   // défaut exact de l'ancien « Page exercices ». Le pied
                   // fait ~170 pt (bouton 48 + espace 10 + médaillon 96 +
                   // marge 14) : on lui en donne 176.
                   basAir: 176,
                   deplies: $deplies,
                   onScroll: { y in replier(y > 26) },
                   onAjouter: ajouterUnExercice)
            .equatable()
            .padding(.horizontal, 12)
            // Le fondu du bas commence AVANT le pied (0,80 au lieu de
            // 0,88) : en cours de défilement, ce qui passe dessous s'est
            // déjà éteint. Rien ne se lit à travers un bouton.
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.04),
                .init(color: .black, location: 0.70),
                .init(color: .clear, location: 0.80)
            ], startPoint: .top, endPoint: .bottom))
    }

    /// LE REPLI DE LA TÊTE — écrit SEULEMENT quand il change d'état (le
    /// scroll remonte une valeur par image ; l'écrire par image
    /// rejouerait le player entier). Ouvrir une zone le force.
    private func replier(_ compacte: Bool) {
        let cible: CGFloat = (compacte || zone != nil) ? 1 : 0
        guard abs(repli - cible) > 0.01 else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            repli = cible
        }
    }

    /// LE PIED — LE STOP, ET RIEN D'AUTRE.
    ///
    /// ⚠️ AUCUN BOUTON N'Y PROPOSE D'EXERCICE (verdict Kathryn 22-09, deux
    /// refus de suite) : « pourquoi il y a écrit commencer développé
    /// couché, non je veux pas ça », puis « le suivant, le presse à jambe,
    /// non il y a pas ça — on doit choisir un exo MANUELLEMENT ». Le
    /// lecteur ne décide de rien : il montre, elle choisit.
    ///
    /// ⚠️ « PAGE EXERCICES » EST MORT LUI AUSSI. Ce bouton ne fermait pas
    /// le lecteur, il CHANGEAIT D'ONGLET, et l'onglet ne revenait jamais
    /// tout seul : c'est lui qui posait la page Exercices derrière le
    /// lecteur pour tout le reste de la séance.
    ///
    /// Reste le médaillon, au même pixel du début à la fin de la séance —
    /// le seul geste qui termine, et le pouce le trouve sans regarder.
    private func piedExercices(encre: CGFloat, enGeste: Bool) -> some View {
        MedaillonStop(lueur: true, action: {
            Haptique.moyen()
            onStop()
        })
            .scaleEffect(1.35)
            .frame(width: 96, height: 96)
            // Le stop DESCEND encore (verdict 04-09, 2e passe).
            .padding(.bottom, 14)
            .opacity(Double(encre))
    }

    /// LE DRAG-POUR-FERMER (école Spotify) — posé sur la TÊTE
    /// seule : la partition garde son scroll, la fermeture garde
    /// son geste (verdict « j'ai du mal à drag vers le bas » : le
    /// ScrollView le volait).
    private var dragFermeture: some Gesture {
        // ⚠️ `.global`, JAMAIS le repère local : le geste est posé sur la
        // vue QUE LE GESTE DÉPLACE — en local, l'overlay descend, donc la
        // translation rétrécit, donc il remonte… MESURÉ à la sonde le
        // 04-09 : une oscillation 330 ⇄ 388 pt à 60 img/s, doigt
        // immobile. Le rendu était à 60 img/s : ce n'était pas un
        // problème de performance, mais une BOUCLE DE RÉTROACTION.
        // (Même piège, même remède que le drag de la pastille.)
        DragGesture(minimumDistance: 14, coordinateSpace: .global)
            .onChanged { v in
                // DESCENDANT et FRANC seulement : un geste horizontal ou
                // montant appartient à la partition.
                guard v.translation.height > 0,
                      abs(v.translation.height) > abs(v.translation.width)
                else { return }
                if !fermeturePrise {
                    fermeturePrise = true
                    CouvertureFoyer.shared.commencerDeplacement()
                }
                #if DEBUG
                if Self.crieGeste {
                    let m = CACurrentMediaTime()
                    let dt = (m - Self.dernierGeste) * 1000
                    Self.dernierGeste = m
                    print(String(format:
                        "[drag] dt=%.0f ms  y=%.0f  saut=%.0f",
                        dt, v.translation.height,
                        v.translation.height - Self.dernierY))
                    Self.dernierY = v.translation.height
                }
                #endif
                fermeture = v.translation.height
            }
            .onEnded { v in
                guard fermeturePrise else { return }
                fermeturePrise = false
                if v.translation.height > 120 || v.velocity.height > 480 {
                    fermer()
                } else {
                    let couverture = CouvertureFoyer.shared
                    let jeton = couverture.commencerDeplacement()
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.82),
                                  completionCriteria: .removed) {
                        fermeture = 0
                    } completion: {
                        guard morph >= 0.98, !fermeturePrise,
                              fermeture == 0 else { return }
                        couverture.terminerDeplacement(jeton)
                    }
                }
            }
    }

    /// LE TITRE DE L'OVERLAY — l'invite S'ANIME (demande Kathryn) : une
    /// lueur qui BALAYE le dégradé de blanc, en boucle douce. Le nom de
    /// l'exercice, lui, reste posé (c'est un fait, pas une invitation).
    @ViewBuilder
    /// CE QUE DIT LA TÊTE — le nom de l'exercice en cours, sinon
    /// « Choisissez un exercice » tant que rien n'est fait, et « Séance en
    /// cours » dès qu'il y a du travail derrière.
    ///
    /// ⚠️ ELLE MENTAIT (relevé 22-09 sur capture) : elle disait
    /// « choisissez un exercice » au-dessus d'une partition qui montrait
    /// déjà un exercice fait, deux séries et deux flammes — `exoChoisi`
    /// tombe à `nil` dès qu'aucun exercice n'est ouvert. On lit maintenant
    /// `groupes`, c'est-à-dire ce qui est RÉELLEMENT affiché dessous.
    private var nomDeLaTete: String {
        if let nom = exoChoisi, !nom.isEmpty { return nom }
        // ⚠️ `seanceVide`, PAS `groupes.isEmpty` (mesuré au simulateur
        // 22-09) : la partition n'est JAMAIS vide — elle porte toujours au
        // moins un groupe, même sans une seule série faite. Elle disait donc
        // « Séance en cours » au-dessus d'un ticket « 0 SETS ».
        return seanceVide ? "Choisissez un exercice" : "Séance en cours"
    }

    /// ⚠️ LA TAILLE SE PASSE EN PARAMÈTRE (relevé 22-09, le titre coupé
    /// « Choisissez un ex… ») : `InviteAnimee` PORTE sa propre
    /// `.font(.system(size: taille))`, donc un `.font()` posé autour d'elle
    /// est ignoré sans le moindre avertissement. La tête repliée demandait
    /// 15 pt et recevait 25 : le titre débordait de sa ligne.
    ///
    /// Le nom est balayé par la lumière (verdict 05-09 : « l'exercice en
    /// cours avec un effet de balayage très Apple pour montrer que c'est en
    /// cours ») — une seule lueur dans la maison, et elle se tait sous le
    /// doigt comme tout le reste.
    private func titreOverlay(_ taille: CGFloat) -> some View {
        InviteAnimee(taille: taille, texte: nomDeLaTete,
                     fige: fermeture > 0.5 || morph < 0.98)
            .multilineTextAlignment(.center)
            .padding(.horizontal, taille > 20 ? 28 : 0)
    }

    func fermer() {
        Haptique.leger()
        CouvertureFoyer.shared.retirer()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
            morph = 0
            fermeture = 0
        }
    }

    /// LA FERMETURE SANS MOUVEMENT — sous la coupe blanche, le lecteur ne
    /// doit pas se voir descendre : il n'est simplement plus là quand le
    /// blanc s'ouvre. Pas d'haptique non plus : le tap en a déjà donné une.
    func poserFerme() {
        CouvertureFoyer.shared.retirer()
        var tr = Transaction()
        tr.disablesAnimations = true
        withTransaction(tr) {
            morph = 0
            fermeture = 0
        }
    }

}

// MARK: - Le lecteur de séance : les zones et leurs exercices (22-09)

/// UN CARRÉ DE ZONE, EN PETIT — le même asset anatomique que l'accueil
/// des exercices (`typo-<zone>`), cuit par script. Choisi, il porte son
/// liseré blanc et sa zone s'éclaire.
private struct CarreZoneMini: View {
    let zone: ExerciseCategory
    let choisie: Bool

    private static let forme = RoundedRectangle(cornerRadius: 13, style: .continuous)

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .background {
                ZStack {
                    Self.forme.fill(
                        LinearGradient(colors: [Color(white: 0.16), .black],
                                       startPoint: .top, endPoint: .bottom))
                    Image("typo-\(zone.assetLecteur)")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                    Image("typo-\(zone.assetLecteur)-lueur")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fill)
                        .opacity(choisie ? 0.9 : 0.22)
                }
            }
            .overlay(alignment: .bottom) {
                Text(zone.rawValue)
                    .font(.inter(8.5, .semibold))
                    .foregroundStyle(.white.opacity(choisie ? 0.95 : 0.7))
                    .padding(.bottom, 4)
            }
            .clipShape(Self.forme)
            .overlay {
                Self.forme.strokeBorder(
                    .white.opacity(choisie ? 0.85 : 0.12),
                    lineWidth: choisie ? 1.2 : 0.5)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(zone.rawValue)
            .accessibilityAddTraits(choisie ? [.isButton, .isSelected] : .isButton)
    }
}

/// UNE RANGÉE D'EXERCICE DANS LE LECTEUR — la grammaire des rangées de
/// la partition : la vignette, le nom, le muscle, rien d'autre. Elle se
/// tape pour lancer.
private struct RangeeZoneLecteur: View {
    let exercise: Exercise
    /// La ligne sous le nom : la dernière charge quand on la connaît,
    /// le muscle sinon. Jamais un chiffre inventé.
    var detail: String = ""
    /// Déjà lancé depuis ce lecteur : la rangée porte sa coche.
    var lance: Bool = false

    private static let forme = RoundedRectangle(cornerRadius: 14, style: .continuous)
    private static let vignette = RoundedRectangle(cornerRadius: 10, style: .continuous)

    var body: some View {
        HStack(spacing: 14) {
            ExercisePhoto(exercise: exercise)
                .frame(width: 44, height: 44)
                .clipShape(Self.vignette)
            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.inter(14, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .lineLimit(1)
                Text(detail.isEmpty ? exercise.muscle : detail)
                    .font(.inter(10))
                    .foregroundStyle(.white.opacity(0.46))
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Image(systemName: lance ? "checkmark" : "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(lance ? 0.6 : 0.35))
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .frame(height: 68)
        .background(Self.forme.fill(.white.opacity(0.05)))
        .overlay { Self.forme.strokeBorder(.white.opacity(0.1), lineWidth: 0.5) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(exercise.name), \(exercise.muscle)")
        .accessibilityAddTraits(.isButton)
    }
}

private extension ExerciseCategory {
    /// Le nom de l'asset anatomique, partagé avec l'accueil des exercices.
    var assetLecteur: String {
        switch self {
        case .haut: return "haut"
        case .abdos: return "abdos"
        case .bas: return "bas"
        case .fessiers: return "fessiers"
        case .cardio: return "cardio"
        }
    }
}

/// LE BANC DE LA BOUCLE — il tape le bouton du pied 2,4 s après l'ouverture
/// du lecteur, une seule fois. Isolé dans un modificateur pour que le corps
/// du lecteur ne grossisse pas d'un `task` de plus (le mur du type-checker
/// n'est jamais loin dans ce fichier).
private struct BancBoucleLecteur: ViewModifier {
    var tape: () -> Void
    func body(content: Content) -> some View {
        #if DEBUG
        content.task {
            guard GrandPlayer.bancBoucle, !GrandPlayer.boucleFaite else { return }
            GrandPlayer.boucleFaite = true
            try? await Task.sleep(for: .seconds(2.4))
            tape()
        }
        #else
        content
        #endif
    }
}
