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

    var body: some View {
        GeometryReader { g in
            TimelineView(.animation(minimumInterval: 1.0 / hz,
                                    paused: fige)) { tl in
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
        guard !dansIle else { return CGPoint(x: W / 2, y: IleGeo.centreY) }
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

/// LA PRISE DE L'ÎLE — la capsule, PLUS une lèvre de 44 pt en dessous.
///
/// Une `contentShape` a le droit de déborder les bornes de sa vue (c'est
/// ce que faisait déjà `inset(by: -10)`) : on s'en sert pour descendre la
/// zone tactile SOUS le trou physique de la Dynamic Island, seul endroit
/// où un toucher arrive encore à l'app. Le dessin, lui, ne bouge pas.
private struct PriseIle: Shape {
    /// Ce qui déborde : 12 pt sur les flancs (le doigt vise large), rien
    /// en haut (au-dessus c'est la barre d'état, elle ne nous appartient
    /// pas), et 44 pt en dessous — la lèvre atteignable.
    static let flanc: CGFloat = 12
    /// 60 et non 44 (05-09) : c'est la SEULE zone de l'île qu'un doigt
    /// atteigne — le trou physique appartient au système. Chaque point
    /// gagné ici est un « j'arrive pas à la retirer » de moins.
    static let sous: CGFloat = 60

    func path(in r: CGRect) -> Path {
        let etendu = CGRect(x: r.minX - Self.flanc, y: r.minY,
                            width: r.width + Self.flanc * 2,
                            height: r.height + Self.sous)
        return Path(roundedRect: etendu, cornerRadius: 26,
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

    var body: some View {
        etatCourant
    }

    @ViewBuilder private var etatCourant: some View {
        if etat.dansIle {
            // Le fondu croisé : la capsule se dissout dans la pastille
            // (et l'inverse) pendant que `matchedGeometryEffect` déplace
            // le cadre. Sans lui, le contenu SAUTE au milieu du voyage.
            ile.transition(.opacity)
        } else {
            ZStack {
                // LA CIBLE (demande Kathryn 04-09) : dès qu'on DÉPLACE la
                // pastille, un halo ROUGE + un petit DOIGT s'allument sur
                // l'île — « tu peux la déposer ici ».
                if etat.enDrag { CibleIle(utile: utile) }
                corps
            }
            .transition(.opacity)
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
        // ⚠️ 15 Hz, PAS 30 (04-09, lot 2, cause n° 9) : un souffle de
        // braise sur une capsule de 49 pt ne se lit pas plus fin à 30 —
        // et c'est un cycle sur deux de rendu qui disparaît.
        TimelineView(.animation(minimumInterval: 1.0 / 15.0,
                                paused: figee)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900)
            ileCorps(t: t, maintenant: tl.date)
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
        // ⚠️ LE TAP OUVRE LE PLAYER (04-09, lot 2, cause n° 3). Avant, il
        // ne faisait que la sortir de l'île — et comme le corps de la
        // pilule n'est plus monté quand elle y est, LE TAP QUI OUVRE LE
        // PLAYER N'EXISTAIT PLUS DU TOUT. C'était, mot pour mot,
        // « impossible de cliquer sur la bulle, pas d'overlay ».
        // L'île est un état du player, pas une impasse : on la touche,
        // le player s'ouvre. Le DRAG, lui, la fait ressortir.
        // ⚠️ MÊME ORDRE EXCLUSIF QUE LA PASTILLE (04-09) : le drag
        // d'abord, le tap ensuite. En deux gestes séparés, le tap gagnait
        // — l'île n'avait donc plus AUCUNE sortie au doigt, et maintenant
        // que son tap ouvre le player, on y serait entré pour ne plus
        // jamais en sortir.
        // ⚠️⚠️ TOUT LA FAIT SORTIR (verdict Kathryn 05-09 : « la moindre
        // drag ou tirage ou tap, elle sort du display island — souvent
        // c'est bloqué, j'arrive pas à la retirer »).
        //
        // Le 04-09, le tap OUVRAIT LE PLAYER : c'était la réparation d'un
        // autre défaut (l'île sans issue), et ça a créé celui-ci — le
        // seul geste qui atteignait vraiment l'app servait à autre chose,
        // donc la sortie n'existait qu'au drag, dans une lèvre de 44 pt
        // sous un trou que le système se réserve. D'où « c'est bloqué ».
        // Désormais : tap ET drag la font SORTIR ; le player s'ouvre
        // depuis la pastille, qui est grande et à portée.
        // Le seuil de drag tombe à 3 pt (c'était 8) : un doigt qui
        // s'appuie et glisse à peine doit suffire.
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { _ in sortirDeLIle() }
                .exclusively(before: TapGesture().onEnded {
                    Haptique.moyen()
                    sortirDeLIle()
                }))
        .matchedGeometryEffect(id: "pilule-vol", in: vol)
        .position(x: UIScreen.main.bounds.width / 2, y: IleGeo.centreY)
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
        let h = IleGeo.hauteur + 12
        let forme = RoundedRectangle(cornerRadius: h / 2, style: .continuous)
        let s = Self.souffle(t)
        let s2 = Self.souffle(t * 0.77 + 210)      // la nappe large, déphasée
        let e = Self.eclat(t)
        HStack(spacing: 0) {
            // ⚠️⚠️ LE CHRONO A CHANGÉ DE CÔTÉ (verdict Kathryn 05-09 :
            // « le time, il est collé sur l'heure »). Écarter ne suffisait
            // PAS : mesuré, l'heure du système finit à 91 pt et notre
            // chrono commençait à 104 — treize points d'air, et pourtant
            // les deux se lisaient comme UNE SEULE chaîne, parce que ce
            // sont deux textes blancs, à chiffres fixes, sur la même
            // ligne de base. Deux horloges côte à côte restent deux
            // horloges.
            //
            // Le remède est géométrique, pas cosmétique : le seul côté
            // libre est le DROIT (l'heure mange 50→91 à gauche, le wifi
            // et la pile ne commencent qu'à ~325 à droite). Le chrono y
            // va, et le STOP prend le slot étroit de gauche — un DISQUE
            // à côté d'un texte ne se confond avec rien.
            // Le stop y est aussi plus gros (« un peu plus gros aussi ») :
            // 0,62 → 0,76.
            MedaillonStop(lueur: true, action: {
                Haptique.moyen()
                onStop()
            })
            // ⚠️ COLLÉ AU TROU, PAS CENTRÉ DANS SON SLOT — les bandes
            // libres du haut de l'écran sont MESURÉES (capture
            // `tools/flow/captures/ile-v6-haut.png`, iPhone 15 Pro) :
            // l'heure du système finit à 93 pt, le trou commence à 133,
            // le wifi commence à ~318. Il reste donc QUARANTE points à
            // gauche et cinquante à droite, pas un de plus. Centré dans
            // ses 58 pt, le médaillon mordait le « 5 » de 10:55.
                .scaleEffect(0.72)
                .frame(width: 58, height: 42, alignment: .trailing)
                .shadow(color: braise.opacity(0.25 + 0.3 * s), radius: 5)
            // LE TROU : l'île physique vit ici, on ne peint rien dessus.
            Spacer().frame(width: IleGeo.largeur + 8)
            // ⚠️ PAS DE FLAMMES ICI (verdict Kathryn, 05-09 : « enlève
            // les flammes de la mini pastille : on a que l'animation qui
            // rentre dedans et basta »). Elles y ont vécu une heure : la
            // capsule s'élargissait, le chrono passait sous l'heure du
            // système. L'île dit le TEMPS et donne le STOP — rien
            // d'autre. Ce qu'une série rapporte se lit dans la pastille
            // tirée et dans le détail.
            // LE CHRONO — il dit que ça TOURNE, et c'est ce qu'elle en
            // garde (« on comprend bien que c'est en cours avec le
            // time »). Aligné à GAUCHE dans son slot : il s'appuie sur le
            // bord du trou et laisse ses 25 pt d'air avant le wifi.
            Text(Self.chrono(depuis: departSeance, a: maintenant))
                // 13 et non 14 : à 14, « 28:59 » fait 50 pt et finissait
                // à 4 pt du wifi — l'air se voit, l'absence d'air aussi.
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.80 + 0.2 * e))
                .shadow(color: .white.opacity(0.35 * e), radius: 3)
                .lineLimit(1)
                .frame(width: 58, alignment: .leading)
                .padding(.leading, 3)
        }
        .frame(height: h)
        // LE CHAMP DE BRAISE, en couches — du serré au large :
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
        // Le liseré : la lumière vient d'EN HAUT (la loi des dalles) —
        // blanc-chaud au sommet, braise aux flancs, rouge au bas ; il
        // respire avec le souffle et s'embrase à l'éclat.
        .overlay {
            forme.strokeBorder(
                LinearGradient(stops: [
                    .init(color: .white.opacity(0.55 + 0.45 * e), location: 0),
                    .init(color: braise.opacity(0.55 + 0.30 * s), location: 0.45),
                    .init(color: rouge.opacity(0.35 + 0.25 * s), location: 1)
                ], startPoint: .top, endPoint: .bottom),
                lineWidth: 1.1)
        }
        // ⚠️ LE RAYON D'OMBRE EST FIXE (04-09, lot 2, cause n° 9) : il
        // valait `7 + 5 * s`. Une gaussienne dont le RAYON change ne se
        // met pas en cache — elle était recalculée à chaque image. Le
        // souffle passe dans l'OPACITÉ, qui est un simple facteur : à
        // l'œil c'est le même battement, au GPU c'est un flou cuit une
        // fois. (La même loi vaut partout : faire respirer l'opacité,
        // jamais le rayon.)
        .shadow(color: braise.opacity(0.18 + 0.30 * s), radius: 9)
        .shadow(color: .white.opacity(0.30 * e), radius: 4)
    }


    /// ⚠️ LA SORTIE ÉTAIT BRUTALE (verdict Kathryn 05-09 : « quand on
    /// quitte le display island, c'est trop brutal »). Deux causes, les
    /// deux traitées : le ressort était COURT (0,50 s, amorti à 0,80 —
    /// il arrivait sec), et surtout les deux formes se REMPLACENT (l'île
    /// et le corps sont deux branches d'un `if`) : le cadre se morphait
    /// pendant que le CONTENU sautait d'un coup. Le ressort s'allonge
    /// (0,72 / 0,88) et chaque branche entre et sort en fondu — la
    /// matière se dissout dans l'autre pendant que le cadre voyage.
    private func sortirDeLIle() {
        guard etat.dansIle else { return }
        CarillonIle.sortie()      // souffle + scintillement
        withAnimation(.spring(response: 0.72, dampingFraction: 0.88)) {
            etat.dansIle = false
        }
    }

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
            .matchedGeometryEffect(id: "pilule-vol", in: vol)
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
            // LES MÊMES BRAISES, EN PETIT (demande Kathryn) : la mini
            // pilule chante comme le grand player — même composant,
            // force réduite, taillée par la robe. Elle s'ÉTEINT pendant
            // le mouvement (la loi : rien qui s'anime sous le doigt).
            BraisesVague(force: 0.42, partBasse: 0.72,
                         colonnes: 9, flou: 11,
                         fige: etat.enMouvement || figee, hz: 15)
                .clipShape(Self.forme)
        }
    }
}

// MARK: - LE BANC : `-piluleLab`

enum PiluleBanc {
    static let actif = CommandLine.arguments.contains("-piluleLab")
    /// `-piluleSortie` : la séance démarre avec la pastille SORTIE de
    /// l'île (le régime d'avant le 05-09). Le simulateur ne drague pas :
    /// sans ce barreau, l'état « pastille dehors » — donc la page qui
    /// recule derrière elle — n'est pas capturable.
    static let horsIle = CommandLine.arguments.contains("-piluleSortie")
    static let playerOuvert = CommandLine.arguments.contains("-playerOuvert")
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
    /// `-playerOuvert` : le banc naît PLAYER OUVERT — le simulateur ne
    /// tape pas, et la tête du player (le nom balayé, la card du jour)
    /// n'était capturable qu'au doigt.
    @State private var morph: CGFloat = PiluleBanc.playerOuvert ? 1 : 0
    /// LES TROIS ENTRÉES DU PLAYER, à essayer au doigt (04-09 : « propose
    /// une autre animation ») — AUCUNE ne met à l'échelle quoi que ce
    /// soit : Kathryn refuse le grossissement.
    @State private var style: StylePlayer = .glisse
    private var overlayOuvert: Bool { morph > 0.001 }
    @State private var retours = 0
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
                        onStop: { stops += 1 },
                        onExos: { retours += 1 })
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
    var onExos: () -> Void = {}

    @State private var fermeture: CGFloat = 0
    @State private var deplies: Set<String> = []

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
                partition.scrollDisabled(enGeste)
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
    }

    /// L'EN-TÊTE FIXE — il ne scrolle jamais, et c'est LUI qui porte le
    /// drag-pour-fermer (la partition garde son scroll : chacun sa zone).
    private func teteFixe(encre: CGFloat, enGeste: Bool) -> some View {
        VStack(spacing: 10) {
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
            MiniCardJour(date: depart, sticker: sticker)
                .scaleEffect(1.55)
                .frame(width: 150, height: 150)
                // LE TICKET DE PAPIER — il RESTE ici, dans le DÉTAIL
                // (verdict Kathryn 05-09, correction du même jour : « il
                // fallait pas enlever le ticket avec le nombre de sets
                // total sur le détail de la session ; il fallait
                // n'enlever que sur la pastille, et enlever SON
                // ANIMATION »). C'est donc son talon qui s'est tu (voir
                // `TicketSeries`), pas le ticket.
                .overlay(alignment: .trailing) {
                    TicketSeries(texte: "\(setsFaits) SETS",
                                 echelle: 0.95)
                        .rotationEffect(.degrees(-4))
                        .offset(x: 44, y: 10)
                }
                .padding(.top, 10)
            // LE NOM DE L'EXERCICE, ou l'invite animée.
            titreOverlay
                .padding(.top, 2)
            // ⚠️ À LA PLACE DE LA BARRE (verdict Kathryn) : les FLAMMES
            // condensées, la session en cours et le chrono, sur une
            // ligne. Les flammes sont GELÉES (t constant : aucune
            // horloge de plus, la loi de la partition).
            // (La ligne de braises sous le titre est RETIRÉE — verdict
            //  04-09 : « ça fait lourd ». La vague du bas suffit à dire
            //  que ça tourne ; ici, le chrono seul.)
            TimelineView(.periodic(from: depart, by: 1)) { tl in
                let s = max(0, Int(tl.date.timeIntervalSince(depart)))
                Text("session · \(s / 60):\(String(format: "%02d", s % 60))")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.top, 2)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(dragFermeture)
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
    private var partition: some View {
        SlateListe(groupes: groupes,
                   courant: groupes.first?.id ?? "",
                   basAir: 120,
                   deplies: $deplies)
            .equatable()
            .padding(.horizontal, 12)
            .mask(LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.04),
                .init(color: .black, location: 0.88),
                .init(color: .clear, location: 1)
            ], startPoint: .top, endPoint: .bottom))
    }

    /// LE PIED — le retour à la page exercices de l'ancien player.
    private func piedExercices(encre: CGFloat, enGeste: Bool) -> some View {
        VStack(spacing: 10) {
            // LE MÉDAILLON STOP — il MANQUAIT (verdict 04-09). Comme
            // dans l'ancien player : au-dessus de « Page exercices »,
            // en grand, c'est l'action forte de l'écran.
            MedaillonStop(lueur: true, action: {
                Haptique.moyen()
                onStop()
            })
                .scaleEffect(1.35)
                .frame(width: 96, height: 96)
            piedTexte(encre: encre, enGeste: enGeste)
        }
        // Le stop DESCEND encore (verdict 04-09, 2e passe).
        .padding(.bottom, 14)
        .opacity(Double(encre))
    }

    private func piedTexte(encre: CGFloat, enGeste: Bool) -> some View {
        Text("Page exercices")
            .font(.inter(15, .semibold))
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 24)
            .padding(.vertical, 13)
            .modifier(VerreOuMat(pose: encre > 0.9 && !enGeste))
            .contentShape(Capsule())
            .highPriorityGesture(TapGesture().onEnded {
                Haptique.leger()
                onExos()
                fermer()
            })
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
                if v.translation.height > 120 || v.velocity.height > 480 {
                    fermer()
                } else {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.82)) {
                        fermeture = 0
                    }
                }
            }
    }

    /// LE TITRE DE L'OVERLAY — l'invite S'ANIME (demande Kathryn) : une
    /// lueur qui BALAYE le dégradé de blanc, en boucle douce. Le nom de
    /// l'exercice, lui, reste posé (c'est un fait, pas une invitation).
    @ViewBuilder
    private var titreOverlay: some View {
        if let nom = exoChoisi {
            // ⚠️ LE NOM EST BALAYÉ PAR LA LUMIÈRE (verdict Kathryn 05-09,
            // en remplacement du ticket : « l'exercice en cours avec un
            // effet de balayage de lumière très Apple pour montrer que
            // c'est en cours »). C'est la MÊME lueur que l'invite — un
            // seul balayage dans la maison — et elle se tait sous le
            // doigt comme elle : rien ne s'anime pendant un geste.
            InviteAnimee(taille: 25, texte: nom,
                         fige: fermeture > 0.5 || morph < 0.98)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        } else {
            // La même porte que dans la pilule : rien ne s'anime sous
            // le doigt (relecture adverse 04-09 — c'était la dernière
            // horloge qui battait encore pendant le geste).
            InviteAnimee(taille: 25, fige: fermeture > 0.5 || morph < 0.98)
        }
    }

    func fermer() {
        Haptique.leger()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
            morph = 0
            fermeture = 0
        }
    }

}
