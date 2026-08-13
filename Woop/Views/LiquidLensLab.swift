import SwiftUI
import UIKit

// MARK: - Banc de la lentille liquide (`-lensLab`) — BANCS A + B
//
// LA MONTÉE (Banc A, validé) : une page de papier, une bulle de verre que
// le doigt cueille et PORTE — elle grossit en montant, s'étire avec la
// vitesse — et derrière elle la tache d'encre dans l'eau s'écrit sur le
// vrai tracé du geste, vit, boit le papier, sèche.
//
// LE SOMMET (Banc B) : le doigt a terminé son œuvre en haut de l'écran —
// une pause très courte et très puissante : la fusée gronde (rampe
// haptique qui accélère), le zoom plonge DANS la pastille, et l'intérieur
// du verre se remplit de NUIT lunaire — la coupe se cache dans la nuit du
// verre, on entre dans l'objet, jamais dans un décor. Puis la renaissance :
// la pastille reparaît par le haut de l'univers noir et REDESCEND, seule
// (le doigt ne l'accompagne pas), suivie de son encre de nuit — blanche,
// orange, jaune — dans une nuit très sombre : velours lunaire, clarté à
// peine posée, étoiles rares. Elle se pose au centre. Le cadran à sa
// surface, c'est le Banc C.
//
// `-lensFreeze <p>` fige la montée à p ∈ [0,1] (captures au banc).
// `-lensAuto` rejoue le cycle COMPLET en boucle de 11 s (films) — montée,
// sommet, coupe, descente, pose — le simulateur ne drague pas.
// Toute la chorégraphie est FONCTION PURE du temps et du doigt — aucune
// animation SwiftUI sur les uniforms (l'école ConnexionCine).
struct LiquidLensLab: View {
    // MARK: Les prises du vrai parcours
    //
    // Le banc reste EXACTEMENT le banc : toutes ces prises ont la valeur par
    // défaut de `-lensLab`, et `LiquidLensLab()` continue de rendre la même
    // image au pixel. Branchée sur une fiche d'exercice, la cinématique se
    // contente de dire d'autres mots et de savoir sortir.

    /// La promesse du monde blanc — le nom de l'exercice, dans le parcours.
    var headline: String = "Une nouvelle ère\nd'entraînement."
    /// Le mot gravé au-dessus du chrono, une fois la nuit posée.
    var faceLabel: String = "SÉRIE 1"
    /// Le rang de la série — il vient de la FICHE, qui seule sait où elle en
    /// est. Le cadran ne compte plus les séries : un cycle complet (chrono →
    /// saisie → repos → envol) n'en vit qu'UNE, puis rend la main.
    var seriesNumber: Int = 1

    /// CE QUE LA SÉRIE A ÉTÉ : les chiffres saisis dans la feuille, le repos
    /// choisi, et le temps sous tension au moment du « Terminer ». C'est le
    /// paquet que l'envol remonte à la fiche — la donnée ne meurt plus dans
    /// les brouillons du cadran.
    struct SeriesOutcome {
        var reps: Int
        var kilos: Double
        var restSeconds: Int
        var effortSeconds: Int
    }
    /// LA SÉRIE EST FINIE ET LA PASTILLE PARTIE : appelé une fois, quand
    /// l'envol s'achève — la fiche démonte le cadran et pose la page BRAVO.
    /// Sa présence est CE QUI DISTINGUE le parcours du banc.
    var onFinish: ((SeriesOutcome) -> Void)?
    /// Repartir sans rien compter, tant que la nuit n'est pas tombée.
    var onCancel: (() -> Void)?

    /// LE GESTE UNIQUE — la cinquième prise du parcours. Le doigt qui a
    /// commencé sur la fiche d'exercice continue de porter la bulle ICI :
    /// la fiche transmet sa position (en points plein écran, l'espace de
    /// cette vue) tant que SON geste vit, puis le relâcher. La montée,
    /// l'encre, le sommet passent par les MÊMES fonctions que le doigt
    /// interne — pas une deuxième mécanique. `nil`, le défaut, laisse le
    /// banc et le parcours d'hier identiques au pixel.
    struct Handoff: Equatable {
        /// Le doigt, en points plein écran.
        var point: CGPoint
        /// Sa vitesse verticale — l'étirement du verre.
        var velocityY: CGFloat
        /// `false` : le doigt vient de relâcher.
        var live: Bool
    }
    var handoff: Handoff? = nil

    /// La sixième prise : le SOMMET vient d'être franchi — la partition
    /// prend la main. La fiche s'en sert pour désarmer son drag de
    /// retour : dans la nuit du chrono, plus rien ne tire vers le bas.
    /// `nil`, le défaut, ne change rien au banc ni au parcours d'hier.
    var onSummit: (() -> Void)? = nil

    /// Dans le parcours, le chip REJOUER du banc n'a rien à faire.
    private var isJourney: Bool { onFinish != nil }

    // MARK: Le repos

    /// LE CADRAN A DEUX MÉTIERS, et un seul visage. Sous tension il MONTE,
    /// pendant le repos il DESCEND vers zéro — mais c'est le même verre, les
    /// mêmes halos, la même pastille. On ne change pas d'écran entre l'effort
    /// et la récupération : on n'a jamais quitté le cadran.
    @State private var restStart: Date?
    @State private var restDuration: Int = 0
    /// L'ALLUMAGE DU REPOS : 3, 2, 1, GO. Rien dans l'app ne décomptait quoi
    /// que ce soit — et un repos qui démarre en silence ne se remarque pas.
    /// Le vrai repos ne commence qu'APRÈS le GO : un repos de 45 s doit durer
    /// 45 s, pas 42.
    static let igniteBeats: Double = 3
    static let igniteHold: Double = 0.42
    static var igniteSpan: Double { igniteBeats + igniteHold }
    /// L'ENVOL — la fin du repos, et la sortie du cadran. D'abord la
    /// VIBRANCE : la pastille tremble et chauffe sur place, la lumière bat.
    /// Puis l'ASCENSION : une chute libre inversée — elle part lentement et
    /// accélère jusqu'à percer le bord haut, comme elle était arrivée par lui.
    /// Un souffle de noir ferme la partition avant que la fiche pose BRAVO :
    /// la pièce de la page suivante TOMBE de ce même bord — le raccord est
    /// dans le geste, pas dans un fondu.
    static let envolShudder: Double = 0.55
    static let envolRise: Double = 0.75
    static var envolSpan: Double { envolShudder + envolRise + 0.12 }
    /// L'instant du départ — posé par la fin du décompte, ou par le lien
    /// « Passer le repos ». Toute la chorégraphie est fonction pure de lui.
    @State private var envolAt: Date?
    /// `onFinish` ne part qu'UNE fois.
    @State private var envolFired = false
    /// La saisie de la série est ouverte : le cadran passe derrière du verre.
    @State private var entering = false
    /// Ce que le sheet est en train d'écrire.
    @State private var draftReps = 12
    @State private var draftKilos: Double = 20
    @State private var draftRest: Int?
    /// Le chrono affiché à l'instant du « Terminer la série » : c'est LUI le
    /// temps sous tension — pas l'horloge qui continue de courir sous la
    /// feuille et le repos.
    @State private var effortSeconds = 0

    private var resting: Bool { restStart != nil }

    private static let frozen: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-lensFreeze"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return min(max(v, 0), 1)
    }()

    private static let cycling = CommandLine.arguments.contains("-lensAuto")

    /// `-envolFire` (parcours seulement) : le banc de la FIN DU REPOS. Sitôt
    /// le cadran posé et son chip levé, la série se prend toute seule — repos
    /// de 3 s, sans feuille ni slide — et l'envol part à l'heure. Le
    /// simulateur ne drague pas et ne tape pas : c'est la seule façon de voir
    /// le décompte, la vibrance, l'ascension et la coupe vers BRAVO en film.
    private static let envolFire = CommandLine.arguments.contains("-envolFire")
    /// `-sheetFire` (parcours seulement) : la FEUILLE DE SAISIE s'ouvre toute
    /// seule sitôt le chip levé — le banc du sheet, pour le juger sur le
    /// cadran VIVANT et ses halos (on ne juge un verre que sur ce qui vit
    /// dessous, jamais sur du noir).
    private static let sheetFire = CommandLine.arguments.contains("-sheetFire")

    /// Le papier de la maison — le crème de la dalle d'exercice.
    private static let paper = Color(red: 0.956, green: 0.952, blue: 0.942)
    private static let ink = Color.black.opacity(0.88)

    private struct Sample {
        var pos: CGPoint
        var at: Date
    }

    /// Le doigt en cours, sinon nil.
    @State private var fingerLoc: CGPoint?
    /// Le chemin écrit par le doigt — la matière de l'encre.
    @State private var dragPath: [Sample] = []
    /// Relâcher : le liquide retombe — ressort pur du temps, l'encre sèche.
    @State private var release: (climb: Double, x: CGFloat, at: Date)?
    /// L'étirement lissé (vitesse verticale du doigt) — le verre est liquide.
    @State private var stretch: Double = 0
    /// LE SOMMET : le doigt a atteint le haut — la partition prend la main
    /// (pause-fusée, coupe, descente). REJOUER la relâche.
    @State private var summitAt: Date?
    @State private var summitFx: CGFloat?
    /// LA RAFALE : un tap sur le cadran posé fait sortir les flammes —
    /// l'instant du toucher et son azimut (depuis le centre).
    @State private var flareAt: Date?
    @State private var flareAng: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                let now = tl.date
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                let se = summitElapsed(now: now, t: t)
                ZStack {
                    if let e = se, e >= SummitCine.cutAt {
                        // L'UNIVERS NOIR : renaissance et descente.
                        nightWorld(w: w, h: h, t: t,
                                   ne: e - SummitCine.cutAt,
                                   ax: summitX(w: w), now: now)
                    } else {
                        let d = drive(now: now, t: t, w: w, h: h)
                        let lens = flared(lensState(w: w, h: h, t: t,
                                                    climb: d.climb,
                                                    fx: d.fx), se: se)
                        let e = se ?? 0
                        let zAnchor = UnitPoint(
                            x: lens.center.x / max(w, 1),
                            y: lens.center.y / max(h, 1))
                        whiteWorld(w: w, h: h, t: t, climb: d.climb,
                                   lens: lens, d: d,
                                   nightFill: SummitCine.nightFill(e))
                            .scaleEffect(SummitCine.scale(e),
                                         anchor: zAnchor)
                            .blur(radius: SummitCine.blur(e))
                    }
                    // L'ÉCHAPPÉE. Tant que le doigt n'a pas atteint le
                    // sommet, on doit pouvoir revenir : sans elle, entrer
                    // dans la lentille serait un piège. Elle meurt avec le
                    // monde blanc — la nuit, elle, se termine par le bouton.
                    if isJourney, summitAt == nil, let onCancel {
                        Button(action: onCancel) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.32))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Revenir à l'exercice")
                        .position(x: 42, y: 64)
                    }
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(h: h),
                         isEnabled: Self.frozen == nil && !Self.cycling
                                    && summitAt == nil)
                // LE TAP SUR LE CADRAN POSÉ : les flammes sortent un peu,
                // du côté touché — un souffle, un tick, jamais un menu.
                .simultaneousGesture(SpatialTapGesture().onEnded { v in
                    let nowD = Date()
                    let tt = nowD.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 900)
                    guard let e = summitElapsed(now: nowD, t: tt),
                          e - SummitCine.cutAt - SummitCine.enter
                            - SummitCine.descend > 0.8 else { return }
                    flareAt = nowD
                    flareAng = Double(atan2(v.location.y - h * 0.5,
                                            v.location.x - w * 0.5))
                    RocketHaptics.shared.tapFlare()
                    LensChime.shared.flare()
                })
                // LE GESTE UNIQUE : le doigt de la fiche entre par la
                // même porte que le doigt interne. À l'apparition, s'il
                // est déjà posé, la bulle naît DÉJÀ soulevée sous lui.
                .onChange(of: handoff) { _, hf in
                    guard isJourney, let hf else { return }
                    if hf.live {
                        fingerMoved(hf.point, velocityY: hf.velocityY,
                                    h: h)
                    } else {
                        fingerLifted(h: h)
                    }
                }
                // LE BATTEMENT DU REPOS. La fin du décompte est un ÉVÉNEMENT,
                // pas un zéro qui s'affiche : chaque frame vérifie l'horloge
                // et arme l'envol à l'instant exact — l'école du Canvas de la
                // fumée (l'état s'écrit dans l'onChange, jamais dans le rendu).
                // Pur du temps, donc revenir d'arrière-plan après un repos
                // écoulé déclenche l'envol tout seul, sans rattrapage.
                .onChange(of: now) { _, d in heartbeat(d) }
                .onAppear {
                    if isJourney, let hf = handoff, hf.live {
                        fingerMoved(hf.point, velocityY: hf.velocityY,
                                    h: h)
                    }
                }
            }
        }
        // LE CADRAN NE RECULE PLUS SOUS LA FEUILLE. Le recul (0,972)
        // découvrait la FICHE BLANCHE qui vit derrière la lentille — les
        // « traits blancs » autour de l'écran (16 pt aux flancs, 36 pt en
        // haut : exactement les 2,8 % du recul). Le voile seul suffit : il
        // assombrit le cadran pour que ses chiffres ne se battent pas avec
        // ceux de la feuille — et PAS DE FLOU MANUEL : le matériau natif
        // fait DÉJÀ le sien, flouter la source avant qu'il l'échantillonne
        // aplatissait la réfraction en dalle sombre.
        .overlay {
            Color.black.opacity(entering ? 0.22 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .animation(.easeInOut(duration: 0.34), value: entering)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // LA SAISIE DE LA SÉRIE — au-dessus de CE cadran, jamais ailleurs.
        // NOTRE panneau, PAS un sheet système : la présentation d'iOS 26
        // recule toute la fenêtre et révèle un fond gris (le cadre mesuré
        // autour de l'écran), et un verre posé dans SA couche n'échantillonne
        // jamais la vraie scène — deux tentatives payées. Ici la feuille vit
        // dans l'arbre du cadran : le Liquid Glass réfracte l'auréole POUR DE
        // VRAI, comme les chips du header sur la braise.
        .overlay(alignment: .bottom) {
            GeometryReader { g in
                ZStack(alignment: .bottom) {
                    Color.clear
                    if entering {
                        SetEntrySheet(rank: seriesNumber,
                                      reps: $draftReps,
                                      kilos: $draftKilos,
                                      rest: $draftRest,
                                      onDismiss: { entering = false }) {
                            guard let secs = draftRest else { return }
                            // Le slide est allé au bout : la série est prise,
                            // le repos part, et c'est le MÊME cadran qui se
                            // met à descendre.
                            restDuration = secs
                            restStart = .now
                            entering = false
                        }
                        .frame(height: g.size.height * 0.62)
                        .transition(.move(edge: .bottom))
                    }
                }
                .ignoresSafeArea()
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86),
                       value: entering)
        }
        .onAppear {
            RocketHaptics.shared.prepare()
            LensTheme.shared.prepare()
            LensChime.shared.prepare()
            Paillettes.shared.prepare()
        }
        // Le banc vivait seul et pour toujours ; dans le parcours la vue
        // s'en va, et le thème ne doit pas lui survivre.
        .onDisappear {
            LensTheme.shared.stop()
            RocketHaptics.shared.dragEnd()
            Paillettes.shared.cancelAnnounce()
        }
    }

    /// Le temps écoulé depuis le sommet — doigt (état) ou cycle auto (pur).
    private func summitElapsed(now: Date, t: Double) -> Double? {
        if Self.cycling {
            let tau = t.truncatingRemainder(dividingBy: 14.5)
            return tau > 3.85 ? tau - 3.85 : nil
        }
        if Self.frozen != nil { return nil }
        if let s = summitAt { return now.timeIntervalSince(s) }
        return nil
    }

    /// L'abscisse du sommet : là où le doigt a fini (ou le chemin auto).
    private func summitX(w: CGFloat) -> CGFloat {
        if let fx = summitFx { return fx }
        return w * 0.5 + w * 0.055 * CGFloat(sin(9.1))
    }

    /// La braise chauffe avec le grondement du sommet — fonction pure,
    /// le ViewBuilder n'accepte pas de mutation.
    private func flared(_ lens: Lens, se: Double?) -> Lens {
        guard let e = se else { return lens }
        var l = lens
        l.ember = max(l.ember, SummitCine.flare(e))
        return l
    }

    // MARK: Le monde blanc

    /// Tout ce qui doit passer À TRAVERS le verre vit dans cette couche :
    /// papier, grain, encre, textes. Le layerEffect la réfracte en bloc.
    private func whiteWorld(w: CGFloat, h: CGFloat, t: Double,
                            climb: Double, lens: Lens,
                            d: Drive, nightFill: Double) -> some View {
        // Les scalaires SORTIS de l'appel : le type-checker abandonne sinon
        // (leçon des 36 arguments de navMonolith).
        let sizeW = Float(w), sizeH = Float(h)
        let cX = Float(lens.center.x), cY = Float(lens.center.y)
        let rad = Float(lens.radius)
        let f0 = Float(lens.f0), dispV = Float(lens.disp)
        let emberV = Float(lens.ember), squashV = Float(lens.squash)
        let tS = Float(t)
        let nightV = Float(nightFill)
        let lensShader = ShaderLibrary.liquidLens(
            .float2(sizeW, sizeH), .float2(cX, cY), .float(rad),
            .float(f0), .float(dispV), .float(emberV),
            .float(squashV), .float(1.0), .float(tS),
            .float(0.0), .float(0.0), .float(0.0), .float(nightV),
            .float(0.0), .float(0.0), .float(0.0), .float(nightV))
        let hasTrail = d.sta.count >= 8 && d.dry < 0.999
        // La tache NAÎT en fondu avec la longueur du chemin — jamais de
        // seuil qui pop (la leçon du calque rectangulaire).
        let birthV = Float(sstep(24, 170, Double(d.pathLen)))
        let trailShader = ShaderLibrary.inkTrail(
            .float2(sizeW, sizeH), .floatArray(d.sta),
            .float2(Float(d.boundsMin.x), Float(d.boundsMin.y)),
            .float2(Float(d.boundsMax.x), Float(d.boundsMax.y)),
            .float(tS), .float(Float(d.dry)), .float(birthV),
            .float(1.0), .float(0.0), .float2(cX, cY))
        return ZStack {
            Self.paper
            // Le grain du papier : il se tord lui aussi sous le verre.
            WoopGrain(density: 0.030, lightAlpha: 0.020, darkAlpha: 0.045)
                .allowsHitTesting(false)
            // L'ENCRE : le filament écrit par le doigt, peint dans la
            // couche que le verre réfracte — la pill repasse dessus et le
            // tord. Démontée sitôt sèche : plus un pixel de shader pour rien.
            if hasTrail {
                Rectangle()
                    .fill(.white)
                    .colorEffect(trailShader)
                    .allowsHitTesting(false)
            }
            Text(headline)
                .font(.inter(27, .medium))
                .foregroundStyle(Self.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .blur(radius: 5 * sstep(0.18, 0.50, climb))
                .opacity(1 - sstep(0.12, 0.45, climb))
                .position(x: w / 2, y: h * 0.42 - 26 * sstep(0.08, 0.55, climb))
            // Le titre que la lentille vient déchirer en arc-en-ciel : il
            // n'existe vraiment qu'à travers le verre — dès que le limbe le
            // couvre, l'original s'efface pour ne laisser QUE la copie
            // réfractée (sinon les deux se lisent : glitch, pas verre).
            let covered = sstep(-95, 10,
                                h * 0.60 - (lens.center.y - lens.radius))
            Text("Start Training")
                .font(.inter(31, .semibold))
                .foregroundStyle(Self.ink)
                .opacity(sstep(0.38, 0.62, climb) * (1 - 0.85 * covered))
                .position(x: w / 2, y: h * 0.60)
            Text("Glisse vers le haut")
                .font(.inter(13, .medium))
                .foregroundStyle(Color.black.opacity(0.35))
                .opacity(1 - sstep(0.04, 0.22, climb))
                .position(x: w / 2, y: h - 42)
        }
        .frame(width: w, height: h)
        .compositingGroup()
        .layerEffect(lensShader,
                     maxSampleOffset: CGSize(width: 110, height: 110))
    }

    // MARK: La chorégraphie

    /// Tout ce que la frame doit savoir : la montée, le doigt, l'encre.
    private struct Drive {
        var climb: Double
        var fx: CGFloat
        var sta: [Float] = []
        var boundsMin: CGPoint = .zero
        var boundsMax: CGPoint = .zero
        var pathLen: CGFloat = 0
        var dry: Double = 1
    }

    /// La montée depuis la hauteur du doigt : 0 au bord bas, 1 en haut.
    private func climbOf(y: CGFloat, h: CGFloat) -> Double {
        min(max(Double((h * 0.90 - y) / (h * 0.72)), 0), 1.06)
    }

    private func drive(now: Date, t: Double,
                       w: CGFloat, h: CGFloat) -> Drive {
        if let f = Self.frozen {
            return cyclePose(tau: 0.8 + 3.0 * f, t: t, w: w, h: h,
                             still: true)
        }
        if Self.cycling {
            // 14,5 comme summitElapsed : les DEUX horloges du banc sur le
            // même cycle — le 11.0 hérité du Banc A désynchronisait la
            // phase blanche dès le deuxième tour de film.
            return cyclePose(tau: t.truncatingRemainder(dividingBy: 14.5),
                             t: t, w: w, h: h, still: false)
        }
        // LE SOMMET (doigt) : la pill tenue en haut pendant la pause-fusée,
        // son encre figée dont les âges continuent de courir.
        if summitAt != nil, let fx = summitFx {
            var d = Drive(climb: 1.02, fx: fx)
            let pts = dragPath.map { (pos: $0.pos,
                                      age: now.timeIntervalSince($0.at)) }
            if let tr = stations(from: pts) {
                d.sta = tr.sta; d.boundsMin = tr.bMin
                d.boundsMax = tr.bMax; d.pathLen = tr.len
                d.dry = 0
            }
            return d
        }
        if let loc = fingerLoc {
            var d = Drive(climb: climbOf(y: loc.y, h: h), fx: loc.x)
            let pts = dragPath.map { (pos: $0.pos,
                                      age: now.timeIntervalSince($0.at)) }
            if let tr = stations(from: pts) {
                d.sta = tr.sta; d.boundsMin = tr.bMin
                d.boundsMax = tr.bMax; d.pathLen = tr.len
                d.dry = 0
            }
            return d
        }
        if let r = release {
            let e = now.timeIntervalSince(r.at)
            // Rappel amorti avec un souffle de rebond : du liquide, pas un
            // ressort de tiroir.
            let c = max(r.climb * exp(-6.0 * e) * cos(5.2 * e), -0.05)
            var d = Drive(climb: c,
                          fx: w / 2 + (r.x - w / 2) * CGFloat(exp(-4.0 * e)))
            let pts = dragPath.map { (pos: $0.pos,
                                      age: now.timeIntervalSince($0.at)) }
            if let tr = stations(from: pts) {
                d.sta = tr.sta; d.boundsMin = tr.bMin
                d.boundsMax = tr.bMax; d.pathLen = tr.len
                // L'encre boit le papier et s'efface pendant la retombée.
                d.dry = sstep(0.25, 2.0, e)
            }
            return d
        }
        return Drive(climb: 0, fx: w / 2)
    }

    /// La montée SANS doigt (`-lensAuto`, `-lensFreeze`) : le même geste,
    /// écrit en fonction pure — repos (0→0,8 s), montée (0,8→3,8 s), tenue
    /// (3,8→4,5 s), retombée et séchage, silence, boucle à 7 s.
    private func cyclePose(tau: Double, t: Double,
                           w: CGFloat, h: CGFloat, still: Bool) -> Drive {
        func finger(_ tp: Double) -> CGPoint {
            let u = min(max((tp - 0.8) / 3.0, 0), 1)
            let e = u * u * (3 - 2 * u)
            var y = h * 0.90 - CGFloat(e) * h * 0.72
            var x = w * 0.5 + w * 0.055 * CGFloat(sin(u * 8.5 + 0.6))
            // Le CROCHET : à mi-course le doigt part à droite et REDESCEND
            // un souffle — le repli du chemin que le vrai doigt fait, celui
            // qui tirait des traits : chaque film le teste désormais.
            let hook = sstep(0.38, 0.52, u) * (1 - sstep(0.52, 0.70, u))
            x += w * 0.16 * CGFloat(hook)
            y += h * 0.045 * CGFloat(hook)
            return CGPoint(x: x, y: y)
        }
        if tau < 0.8 && !still { return Drive(climb: 0, fx: w / 2) }
        let riseTau = min(tau, 3.8)
        // Le chemin déjà parcouru, rééchantillonné comme un vrai drag.
        var pts: [(pos: CGPoint, age: Double)] = []
        let n = 30
        for i in 0...n {
            let tp = 0.8 + (riseTau - 0.8) * Double(i) / Double(n)
            // Les âges RÉELS, même figé : le bas de la tache a l'âge du
            // geste — la vitesse et le séchage se jugent en capture.
            pts.append((finger(tp), tau - tp))
        }
        let loc = finger(riseTau)
        var d = Drive(climb: climbOf(y: loc.y, h: h), fx: loc.x)
        d.dry = 0
        if let tr = stations(from: pts) {
            d.sta = tr.sta; d.boundsMin = tr.bMin
            d.boundsMax = tr.bMax; d.pathLen = tr.len
        }
        return d
    }

    /// Rééchantillonne le chemin du doigt en 24 stations (x, y, âge,
    /// flânerie) uniformes en ABSCISSE CURVILIGNE — le vrai tracé, quel
    /// que soit le geste : descentes, crochets, boucles. Le paramétrage
    /// par la hauteur seule tirait des traits droits dès que le chemin se
    /// repliait (le bug des « traits pas naturels » de Kathryn).
    /// La FLÂNERIE (doigt lent = la flaque gonfle) est calculée ici puis
    /// lissée 1-2-1 : aucune marche entre stations. Station 0 = la pointe
    /// (le doigt), station K-1 = la base (le départ du geste).
    private func stations(from pts: [(pos: CGPoint, age: Double)])
        -> (sta: [Float], bMin: CGPoint, bMax: CGPoint, len: CGFloat)? {
        guard pts.count >= 2 else { return nil }
        // Longueurs cumulées le long du chemin.
        var cum = [CGFloat](repeating: 0, count: pts.count)
        for i in 1..<pts.count {
            cum[i] = cum[i - 1] + hypot(pts[i].pos.x - pts[i - 1].pos.x,
                                        pts[i].pos.y - pts[i - 1].pos.y)
        }
        let S = cum[pts.count - 1]
        guard S > 14 else { return nil }
        let K = 24
        var xs = [Double](repeating: 0, count: K)
        var ys = [Double](repeating: 0, count: K)
        var ages = [Double](repeating: 0, count: K)
        var i = pts.count - 2
        var bMin = CGPoint(x: CGFloat.greatestFiniteMagnitude,
                           y: CGFloat.greatestFiniteMagnitude)
        var bMax = CGPoint(x: -CGFloat.greatestFiniteMagnitude,
                           y: -CGFloat.greatestFiniteMagnitude)
        for k in 0..<K {
            // k = 0 à la pointe (fin du chemin), k = K-1 à la base.
            let s = S * (1 - CGFloat(k) / CGFloat(K - 1))
            while i > 0 && cum[i] > s { i -= 1 }
            let a = pts[i]
            let b = pts[i + 1]
            let seg = cum[i + 1] - cum[i]
            let u = seg > 0.001 ? Double((s - cum[i]) / seg) : 0
            xs[k] = Double(a.pos.x) + Double(b.pos.x - a.pos.x) * u
            ys[k] = Double(a.pos.y) + Double(b.pos.y - a.pos.y) * u
            ages[k] = a.age + (b.age - a.age) * u
            bMin.x = min(bMin.x, CGFloat(xs[k]))
            bMin.y = min(bMin.y, CGFloat(ys[k]))
            bMax.x = max(bMax.x, CGFloat(xs[k]))
            bMax.y = max(bMax.y, CGFloat(ys[k]))
        }
        let dsStep = Double(S) / Double(K - 1)
        var raw = [Double](repeating: 0, count: K)
        for k in 0..<K {
            let a0 = ages[max(k - 1, 0)]
            let a1 = ages[min(k + 1, K - 1)]
            let dAge = abs(a1 - a0) / Double(min(k + 1, K - 1)
                                             - max(k - 1, 0))
            let vel = dsStep / max(dAge, 1e-4)
            raw[k] = 1 - sstep(250, 1400, vel)
        }
        var sta: [Float] = []
        sta.reserveCapacity(4 * K)
        for k in 0..<K {
            let l = (raw[max(k - 1, 0)] + 2 * raw[k]
                     + raw[min(k + 1, K - 1)]) / 4
            sta.append(Float(xs[k]))
            sta.append(Float(ys[k]))
            sta.append(Float(ages[k]))
            sta.append(Float(l))
        }
        return (sta, bMin, bMax, S)
    }

    /// L'état de la lentille — géométrie et matière de la montée.
    struct Lens {
        var center: CGPoint
        var radius: CGFloat
        var f0 = 0.80, disp = 0.22, ember = 0.0, squash = 1.0
        /// L'onde de la goutte (atterrissage) — amplitude et phase.
        var ripple = 0.0, ripplePhase = 0.0
        /// Le pouls du chrono — l'enveloppe du battement de la seconde.
        var pulse = 0.0
    }

    private func lensState(w: CGFloat, h: CGFloat, t: Double,
                           climb: Double, fx: CGFloat) -> Lens {
        // LE DOIGT PORTE LA PILL : l'émergence libère la bulle du bord bas,
        // puis elle monte posée au-dessus du doigt et GROSSIT en montant.
        let e = sstep(0.0, 0.30, climb)
        // Au repos la bulle respire — deux périodes sans rapport entier.
        let calm = 1 - sstep(0.0, 0.22, climb)
        let R0 = w * 0.66 + 2.6 * CGFloat(sin(t * 0.63)) * CGFloat(calm)
        let Rc = w * 0.26 + w * 0.115 * CGFloat(sstep(0.28, 1.0, climb))
        let radius = R0 + (Rc - R0) * CGFloat(e)
        let cyRest = h - 24 + 3.5 * CGFloat(sin(t * 0.80)) * CGFloat(calm)
                     + radius
        let cyRide = h * 0.90 - CGFloat(climb) * h * 0.72 - radius * 0.55
        let cy = cyRest + (cyRide - cyRest) * CGFloat(e)
        let cx = w / 2 + (fx - w / 2) * CGFloat(sstep(0.06, 0.34, climb))
        var lens = Lens(center: CGPoint(x: cx, y: cy), radius: radius)
        lens.f0 = 0.80 - 0.14 * sstep(0.30, 0.95, climb)
        lens.disp = 0.22 + 1.50 * sstep(0.40, 0.85, climb)
        // La braise s'allume dès les premiers centimètres et respire sur
        // toute la montée — elle ne meurt plus : elle attend le banc C.
        var ember = sstep(0.02, 0.12, climb)
                    * (0.50 + 0.35 * sin(.pi * min(max(climb, 0) / 0.92, 1.0)))
        ember = max(ember, (0.10 + 0.05 * sin(t * 0.9)) * calm)
        lens.ember = ember
        // Le liquide qui pousse au bord est plus large que haut ; porté
        // vite, il s'étire — la vitesse du doigt est dans `stretch`.
        lens.squash = (1 + 0.10 * (1 - e)) * (1 - stretch)
        return lens
    }

    private func dragGesture(h: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                fingerMoved(v.location, velocityY: v.velocity.height, h: h)
            }
            .onEnded { _ in
                fingerLifted(h: h)
            }
    }

    /// Le corps du geste, EXTRAIT tel quel : le doigt interne et le
    /// `handoff` de la fiche passent par la même porte — une seule
    /// mécanique de montée, d'encre et de sommet.
    private func fingerMoved(_ loc: CGPoint, velocityY: CGFloat,
                             h: CGFloat) {
        guard summitAt == nil else { return }
        let now = Date()
        if fingerLoc == nil {
            dragPath = [Sample(pos: loc, at: now)]
        }
        // LA POUSSIÈRE SONORE : semée à la distance parcourue sur le
        // chemin blanc — le doigt qui s'arrête se tait.
        if let prev = fingerLoc {
            Paillettes.shared.travel(hypot(loc.x - prev.x, loc.y - prev.y),
                                     level: climbOf(y: loc.y, h: h))
        }
        fingerLoc = loc
        release = nil
        // La vitesse verticale, lissée → l'étirement du verre.
        let target = min(max(Double(-velocityY) / 2600, -0.05), 0.14)
        stretch += (target - stretch) * 0.25
        // LE GRONDEMENT DU DRAG : n'existe qu'au doigt posé, en
        // crescendo avec la montée — muet au simulateur.
        RocketHaptics.shared.dragLevel(climbOf(y: loc.y, h: h))
        if let last = dragPath.last,
           hypot(loc.x - last.pos.x, loc.y - last.pos.y) > 7 {
            dragPath.append(Sample(pos: loc, at: now))
            if dragPath.count > 90 {
                dragPath.removeFirst(dragPath.count - 90)
            }
        }
        // LE SOMMET : le doigt a terminé son œuvre — la partition
        // prend la main, la fusée gronde.
        if climbOf(y: loc.y, h: h) >= 0.985 {
            summitAt = now
            summitFx = loc.x
            fingerLoc = nil
            stretch = 0
            let touch = SummitCine.cutAt + SummitCine.enter
                        + SummitCine.descend
            // Le grondement du drag passe le relais à la fusée,
            // et LE THÈME entre en scène — la partition est fixe
            // à partir d'ici (silence après l'arrivée).
            RocketHaptics.shared.dragEnd()
            LensTheme.shared.play()
            RocketHaptics.shared.surge(
                rise: SummitCine.cutAt - 0.05,
                contact: touch, beat: touch + 4.5)
            // LES CHIFFRES AFFLEURENT (landed 4,5) : là où le thème
            // sonnait un dong grave, c'est désormais une paillette qui
            // monte — la voix de la poussière du geste, une octave plus
            // haut. Même instant que le battement haptique.
            Paillettes.shared.announce(after: touch + 4.5)
            onSummit?()
        }
    }

    private func fingerLifted(h: CGFloat) {
        RocketHaptics.shared.dragEnd()
        Paillettes.shared.end()
        guard summitAt == nil, let loc = fingerLoc else { return }
        fingerLoc = nil
        stretch = 0
        release = (climbOf(y: loc.y, h: h), loc.x, .now)
    }

    // MARK: La fin du repos

    /// Le battement : armé chaque frame par l'horloge du TimelineView. Deux
    /// événements seulement — le décompte touche zéro (l'envol part), et
    /// l'envol s'achève (le résultat remonte à la fiche, UNE fois).
    private func heartbeat(_ d: Date) {
        guard isJourney else { return }
        // Le banc de l'envol : le repos s'arme tout seul, chip levé.
        if Self.envolFire, restStart == nil, let s = summitAt,
           d.timeIntervalSince(s) > SummitCine.cutAt + SummitCine.enter
               + SummitCine.descend + 7.2 {
            restDuration = 3
            restStart = d
        }
        // Le banc de la feuille : elle s'ouvre toute seule, chip levé.
        if Self.sheetFire, !entering, restStart == nil, let s = summitAt,
           d.timeIntervalSince(s) > SummitCine.cutAt + SummitCine.enter
               + SummitCine.descend + 7.2 {
            draftRest = nil
            entering = true
        }
        guard let rs = restStart else { return }
        if envolAt == nil,
           d.timeIntervalSince(rs) >= Self.igniteSpan + Double(restDuration) {
            startEnvol(d)
        }
        if let ea = envolAt, !envolFired,
           d.timeIntervalSince(ea) >= Self.envolSpan {
            envolFired = true
            onFinish?(SeriesOutcome(reps: draftReps,
                                    kilos: draftKilos,
                                    restSeconds: restDuration,
                                    effortSeconds: effortSeconds))
        }
    }

    /// Le départ — par le décompte ou par le lien « Passer le repos » :
    /// même envol, même partition, même main.
    private func startEnvol(_ d: Date = .now) {
        guard envolAt == nil else { return }
        envolAt = d
        EnvolHaptic.play(liftAt: Self.envolShudder)
    }

    // MARK: L'univers noir — la renaissance et la descente

    /// La géométrie de la descente : la pastille perce le bord haut un
    /// souffle après la coupe, tombe avec grâce (étirée par sa vitesse),
    /// se pose au centre avec un tremblement amorti. Fonction pure de `ne`.
    private func nightLens(w: CGFloat, h: CGFloat, t: Double,
                           ne: Double, ax: CGFloat,
                           dateNow: Date = .distantPast,
                           envol ev: Double = -1) -> Lens {
        let u = min(max((ne - SummitCine.enter) / SummitCine.descend, 0), 1)
        let e2 = u * u * (3 - 2 * u)
        // PETITE à la renaissance — elle grossit surtout en arrivant.
        let radius = w * 0.115 + w * 0.185 * CGFloat(sstep(0.35, 1.0, u))
        let cyStart = -radius - 60
        let cyEnd = h * 0.50
        var cy = cyStart + (cyEnd - cyStart) * CGFloat(e2)
        let cx = ax + (w / 2 - ax) * CGFloat(sstep(0.20, 0.90, u))
        // L'étirement suit la vitesse (dérivée de la course), et meurt
        // à l'approche de la pose.
        let vel = 6 * u * (1 - u)
        var squash = 1 - 0.10 * min(vel / 1.5, 1) * (1 - sstep(0.85, 1.0, u))
        let landed = ne - (SummitCine.enter + SummitCine.descend)
        var radiusV = radius
        var ripple = 0.0
        var pulseV = 0.0
        if landed > 0 {
            // L'ATTERRISSAGE EN GOUTTE : écrasement au contact, rebond
            // plus haut, retombée — deux oscillations lisibles, et l'onde
            // circulaire qui traverse la surface du verre.
            squash *= 1 + 0.11 * sin(landed * 14.5) * exp(-landed * 3.2)
            cy += CGFloat(2.6 * sin(landed * 2.1) * exp(-landed * 1.1))
            ripple = exp(-landed * 2.8)
            // L'ÉVAPORATION est l'affaire de l'encre seule : la pastille
            // veille, sereine — aucune gorgée, aucun pouls de perle.
            // L'ANNONCE : après le silence, l'écho visuel du battement —
            // la pastille pèse une fois, discrètement.
            let bt = landed - 4.5
            radiusV *= 1 + 0.012 * CGFloat(exp(-bt * bt / (0.18 * 0.18)))
            // LE POULS DU CHRONO : attaque 0,10 s (3 frames — plus
            // jamais un scale qui claque en 1 frame), retombée douce ;
            // la somme one(x) + one(x+1) laisse la queue traverser la
            // seconde sans pop au wrap. La LUMIÈRE bat sur la même
            // enveloppe (uniform pulse → limbe, arcs, miroir).
            // Calé sur la MÊME horloge que les chiffres (origine 5.6) :
            // la pastille bat pile quand la seconde bascule.
            if landed > 5.6 {
                let ph = (landed - 5.6).truncatingRemainder(dividingBy: 1.0)
                let on = sstep(5.6, 6.6, landed)
                func one(_ u: Double) -> Double {
                    u <= 0 ? 0 : sstep(0, 0.10, u) * exp(-max(u - 0.10, 0) / 0.30)
                }
                pulseV = (one(ph) + one(ph + 1.0)) * on
                radiusV *= 1 + CGFloat(0.009 * pulseV)
            }
        }
        // L'ALLUMAGE DU REPOS : la bulle GONFLE D'UN COUP et se recale au
        // centre. Écrit ici, dans la fonction pure du temps, et non par un
        // `withAnimation` sur une variable — c'est la loi de ce fichier, et
        // c'est ce qui garantit que rien ne dérive : la taille est une
        // FONCTION de l'instant du slide, pas un état qu'on pousse.
        //
        // Le coup part fort (montée en 0,16 s), retombe en deux oscillations
        // amorties, et se stabilise 14 % plus gros qu'à l'effort : le repos
        // n'est pas une parenthèse, c'est l'autre moitié de l'exercice, et sa
        // scène est plus grande.
        var cxV = cx
        if let rs = restStart {
            let a = max(0, dateNow.timeIntervalSince(rs))
            let rise = sstep(0, 0.16, a)
            let ring = exp(-a * 3.4) * cos(a * 12.0)
            radiusV *= 1 + CGFloat(rise * (0.14 + 0.30 * ring))
            // Le recentrage : si le doigt avait biaisé la bulle, elle revient
            // franchement au milieu pendant la même course.
            let k = CGFloat(sstep(0, 0.34, a))
            cxV += (w / 2 - cxV) * k
            cy += (h * 0.50 - cy) * k
        }
        // L'ENVOL. Deux temps, écrits ici comme tout le reste — fonction pure
        // de l'instant du départ, jamais un `withAnimation`.
        //
        // LA VIBRANCE d'abord : la pastille TREMBLE sur place — deux
        // sinusoïdes rapides sans rapport entier, l'amplitude monte avec elle.
        // Ce n'est pas un ressort qui joue : c'est une énergie qui s'accumule
        // et qui va la porter. Elle gonfle un souffle en même temps.
        //
        // Puis l'ASCENSION : une chute libre INVERSÉE (q², le miroir exact de
        // sa descente d'arrivée) — elle part d'un rien et accélère jusqu'à
        // percer le bord haut. Le tremblement meurt au décollage : on ne
        // tremble plus quand on est porté. L'étirement vertical dit la
        // vitesse, comme à l'aller.
        let vib = ev >= 0 ? min(max(ev / Self.envolShudder, 0), 1) : 0.0
        if ev >= 0 {
            let q = max(0, (ev - Self.envolShudder) / Self.envolRise)
            let tremble = vib * (1 - min(q * 2.2, 1))
            cxV += CGFloat(sin(ev * 86.0) * 2.6 * tremble)
            cy += CGFloat(sin(ev * 71.0 + 1.3) * 2.1 * tremble)
            radiusV *= 1 + CGFloat(0.055 * vib)
            cy -= (h * 0.5 + radiusV + 80) * CGFloat(q * q)
            squash *= 1 - 0.16 * min(q * 1.6, 1)
        }
        var lens = Lens(center: CGPoint(x: cxV, y: cy), radius: radiusV)
        lens.pulse = pulseV
        lens.f0 = 0.72
        // Dispersion quasi nulle sur TOUTE la nuit : chaque frange verte
        // mesurée venait d'elle (même à 0,35, des étincelles G≈2R
        // survivaient sur la descente) — le verre de nuit ne disperse pas.
        lens.disp = 0.12
        // La braise vit pendant la chute, s'apaise en braise de VEILLE une
        // fois posée — sur la nuit, une pastille sans braise est invisible.
        // Elle souffle une fois avec le battement de l'annonce.
        let fall = 0.24 * (1 - sstep(0.0, 1.2, max(landed, 0)))
        let veille = (0.11 + 0.05 * sin(t * 0.9))
                     * sstep(0.6, 1.6, max(landed, 0))
        let bt = max(landed, 0) - 4.5
        let echo = 0.20 * exp(-bt * bt / (0.20 * 0.20))
        lens.ember = min(max(fall, veille) + echo, 1.0)
        lens.squash = squash
        lens.ripple = ripple
        lens.ripplePhase = max(landed, 0) * 30
        // La vibrance CHAUFFE : la braise remonte comme au sommet, et la
        // lumière bat sur l'enveloppe du tremblement — c'est tout le verre
        // qui annonce le départ, pas seulement sa position.
        if vib > 0 {
            lens.ember = min(lens.ember + 0.5 * vib, 1.0)
            lens.pulse = max(lens.pulse, 0.9 * vib)
        }
        return lens
    }

    /// L'encre de la descente : le chemin RÉEL de la pastille, rééchantillonné
    /// comme un drag — blanche, orange, jaune, elle éclaire la nuit.
    private func nightTrail(w: CGFloat, h: CGFloat,
                            ne: Double, ax: CGFloat) -> Drive {
        var d = Drive(climb: 0, fx: ax)
        guard ne > SummitCine.enter + 0.10 else { return d }
        // LE CHEMIN S'ARRÊTE À LA POSE. La fenêtre glissante suivait la
        // pastille immobile : tous les points convergeaient, stations()
        // tombait sous ses gardes (S ≤ 14) et TOUTE l'encre se démontait
        // d'un coup ~1,9 s après l'atterrissage — le « battement noir »
        // mesuré par les juges, rejeté deux fois par Kathryn. Figé à la
        // pose, le chemin demeure, ses âges courent, et la condensation
        // a une matière à contracter pendant que le halo s'étend.
        let land = SummitCine.enter + SummitCine.descend
        let neP = min(ne, land)
        var pts: [(pos: CGPoint, age: Double)] = []
        let t0 = max(SummitCine.enter, neP - 1.9)
        let n = 30
        for i in 0...n {
            let tp = t0 + (neP - t0) * Double(i) / Double(n)
            let l = nightLens(w: w, h: h, t: 0, ne: tp, ax: ax)
            // Âges capés : live plancher 0,27 — le condensat respire et
            // garde ses caustiques À DEMEURE (sans borne, live → 0,03 :
            // un cœur mort).
            pts.append((l.center, min(ne - tp, 2.6)))
        }
        if let tr = stations(from: pts) {
            d.sta = tr.sta; d.boundsMin = tr.bMin
            d.boundsMax = tr.bMax; d.pathLen = tr.len
            let landed = ne - (SummitCine.enter + SummitCine.descend)
            // LE REPLI : après la pose, l'encre est bue par la pastille —
            // le front du repli est piloté par `dry` côté shader (nuit).
            // Lent, majestueux. Elle rejoindra les halos au Banc D.
            d.dry = sstep(1.0, 3.8, max(landed, 0))
        }
        return d
    }

    /// Le monde noir : velours lunaire, clarté à peine posée, étoiles
    /// rares — et la pastille de verre qui descend, réfractant sa nuit et
    /// son encre. Le REJOUER du banc apparaît une fois posée.
    private func nightWorld(w: CGFloat, h: CGFloat, t: Double,
                            ne: Double, ax: CGFloat,
                            now: Date) -> some View {
        // L'envol en cours, sinon -1. Le chemin d'encre, lui, ne le voit
        // JAMAIS : il rejoue des instants passés de la pastille, et l'envol
        // n'appartient qu'au présent.
        let ev = envolAt.map { now.timeIntervalSince($0) } ?? -1
        let lens = nightLens(w: w, h: h, t: t, ne: ne, ax: ax, dateNow: now,
                             envol: ev)
        let d = nightTrail(w: w, h: h, ne: ne, ax: ax)
        let sizeW = Float(w), sizeH = Float(h)
        let cX = Float(lens.center.x), cY = Float(lens.center.y)
        let rad = Float(lens.radius)
        let f0 = Float(lens.f0), dispV = Float(lens.disp)
        let emberV = Float(lens.ember), squashV = Float(lens.squash)
        let tS = Float(t)
        // LA LAQUE : la matière condensée emplit le verre par sa
        // profondeur — et y RESTE : le cadran est ce condensat.
        // 0,66 : la nuit emplit le verre mais le monde chaud ET le
        // condensat restent LISIBLES à travers le dôme — le cadran est la
        // pill de base, remplie (le sommet, lui, garde sa nuit à 0,9).
        let lacquerV = Float(0.66 * sstep(0.55, 1.0, d.dry))
        // Tôt et long : la lumière orbitale vit déjà quand l'encre finit
        // sa contraction — et le LANGAGE du verre (nScene) bascule sur
        // CETTE rampe : la fenêtre du jour meurt pendant que les arcs
        // naissent, mathématiquement ensemble.
        // Au décollage, le halo S'ÉTEINT : la lumière appartenait à la
        // pastille posée — elle ne reste pas au sol quand l'objet part.
        let igV = Float(sstep(0.08, 0.85, d.dry))
            * Float(1 - sstep(Self.envolShudder,
                              Self.envolShudder + 0.5, max(ev, 0)))
        let lensShader = ShaderLibrary.liquidLens(
            .float2(sizeW, sizeH), .float2(cX, cY), .float(rad),
            .float(f0), .float(dispV), .float(emberV),
            .float(squashV), .float(1.0), .float(tS),
            .float(0.0), .float(0.0), .float(0.0), .float(lacquerV),
            .float(Float(lens.ripple)), .float(Float(lens.ripplePhase)),
            .float(Float(lens.pulse)), .float(igV))
        // La couche d'encre ne se démonte JAMAIS sur la nuit : le
        // condensat est l'intérieur permanent du cadran.
        let hasTrail = d.sta.count >= 8
        let birthV = Float(sstep(24, 170, Double(d.pathLen)))
        let trailShader = ShaderLibrary.inkTrail(
            .float2(sizeW, sizeH), .floatArray(d.sta),
            .float2(Float(d.boundsMin.x), Float(d.boundsMin.y)),
            .float2(Float(d.boundsMax.x), Float(d.boundsMax.y)),
            .float(tS), .float(Float(d.dry)), .float(birthV),
            .float(1.0), .float(1.0), .float2(cX, cY))
        // LE HALO : l'énergie diffusée s'allume derrière la pastille —
        // les quatre voix du vrai cadran — et y RESTE.
        // La rafale du tap : attaque 2 frames, retombée douce ~0,35 s.
        let fe = flareAt.map { now.timeIntervalSince($0) } ?? 99.0
        let flareV = Float(sstep(0, 0.06, fe)
                           * exp(-max(fe - 0.06, 0) / 0.45))
        let glowShader = ShaderLibrary.eclipseGlow(
            .float2(sizeW, sizeH), .float2(cX, cY), .float(rad),
            .float(tS), .float(igV), .float(Float(lens.pulse)),
            .float(flareV), .float(Float(flareAng)))
        let landed = ne - (SummitCine.enter + SummitCine.descend)
        // LES CHIFFRES : ils affleurent du condensat, au battement.
        let faceIn = sstep(4.5, 5.6, max(landed, 0))
        // Le chip n'apparaît qu'après l'affleurement.
        let chipIn = min(max((landed - 6.3) / 0.5, 0), 1)
        // LE TEMPS DÉFILE : le chrono compte dès que la surface est
        // prête — même origine que le pouls (5,6) : chaque bascule de
        // seconde EST un battement de la pastille.
        let elapsed = max(0, Int(landed - 5.6))
        // LES DEUX MÉTIERS DU CADRAN. Sous tension, il monte depuis le
        // sommet ; en repos, il descend vers zéro depuis l'instant du slide.
        // Même verre, mêmes halos, même pastille — on ne change pas d'écran
        // entre l'effort et la récupération, sinon le repos devient un
        // ailleurs et on perd le fil de l'exercice.
        // L'âge de l'allumage : négatif tant qu'il n'y a pas de repos.
        let ignite: Double = restStart.map { now.timeIntervalSince($0) } ?? -1
        let counting = ignite >= 0 && ignite < Self.igniteSpan
        let left: Int? = restStart.map {
            max(0, restDuration
                - Int(max(0, now.timeIntervalSince($0) - Self.igniteSpan)))
        }
        // Pendant l'allumage, le cadran ne montre plus l'heure : il montre le
        // compte. C'est le même verre, la même place — seul le contenu change.
        let countWord: String? = {
            guard counting else { return nil }
            let n = Int(Self.igniteBeats - ignite) + 1
            return n >= 1 ? String(min(n, Int(Self.igniteBeats))) : "GO"
        }()
        let shown = left ?? elapsed
        let timeStr = countWord ?? String(format: "%d:%02d",
                                          shown / 60, shown % 60)
        let faceTitle = counting ? "REPOS DANS" : (resting ? "REPOS" : faceLabel)
        // Chaque chiffre TOMBE : il arrive gros, se pose, et s'efface avant le
        // suivant. Un compte à rebours dont les chiffres se remplacent sans
        // bouger n'est pas un compte à rebours, c'est une horloge.
        let beatPhase = counting ? ignite - floor(ignite) : 0
        let countScale = counting
            ? 1.0 + 0.55 * exp(-beatPhase * 7.0) : 1.0
        let countFade = counting
            ? min(1, beatPhase * 9) * (1 - sstep(0.78, 1.0, beatPhase)) : 1.0
        // Le verre du sheet a besoin que le fond RECULE : sans ça les deux
        // plans se disputent l'œil et la feuille a l'air collée sur l'image.
        let veil: Double = entering ? 1 : 0
        return ZStack {
            ZStack {
                Color.black
                NightSpotlight()
                    .allowsHitTesting(false)
                NightStars(t: t)
                    .allowsHitTesting(false)
                // L'énergie de l'encre, devenue halo — DERRIÈRE l'objet,
                // réfractée par son verre : elle s'y reflète, à demeure.
                Rectangle()
                    .fill(.white)
                    .colorEffect(glowShader)
                    .allowsHitTesting(false)
                if hasTrail {
                    Rectangle()
                        .fill(.white)
                        .colorEffect(trailShader)
                        .allowsHitTesting(false)
                }
                WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
                    .allowsHitTesting(false)
            }
            .frame(width: w, height: h)
            .compositingGroup()
            .layerEffect(lensShader,
                         maxSampleOffset: CGSize(width: 110, height: 110))
            // LES CHIFFRES DU CADRAN — la continuité directe du condensat,
            // affleurant du fond de la laque, sous les reflets du verre.
            // Pendant la vibrance ils TREMBLENT AVEC la pastille (leur
            // position est son centre) et s'effacent avant le décollage :
            // l'objet part entier, pas ses chiffres.
            if faceIn > 0.001 {
                VStack(spacing: 6) {
                    Text(faceTitle)
                        .font(.inter(12, .semibold))
                        .tracking(3.0)
                        .foregroundStyle(resting
                                         ? Color(red: 1.0, green: 0.62, blue: 0.22)
                                            .opacity(0.90)
                                         : Color.white.opacity(0.50))
                    Text(timeStr)
                        .font(.inter(counting ? 64 : 46,
                                     counting ? .semibold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(Color.white.opacity(0.92))
                        .scaleEffect(countScale)
                        .opacity(countFade)
                }
                .opacity(faceIn * (1 - sstep(0.05, 0.32, max(ev, 0))))
                .blur(radius: (1 - faceIn) * 7)
                .scaleEffect(0.95 + 0.05 * faceIn)
                .position(lens.center)
                .allowsHitTesting(false)
            }
            // LA SORTIE. Dans le parcours, le cadran n'est plus un cul-de-sac :
            // le primaire de la maison affleure une fois les chiffres posés,
            // et rend le temps sous tension à la fiche.
            if isJourney {
                // DEUX MOMENTS, DEUX POIDS. Sous tension, « Terminer la
                // série » est LE geste de la page : un CTA plein. Pendant le
                // repos, la série est déjà prise et la sortie viendra toute
                // seule à la fin du décompte — ce qui reste n'est qu'une
                // échappée : « Passer le repos », un lien d'encre seule
                // (l'école du footer de BRAVO — sur la nuit, un cadre clair
                // se lit comme un bug). Le fondu croisé est écrit sur
                // l'horloge du repos, comme tout le reste du fichier.
                let chipInS = chipIn * chipIn * (3 - 2 * chipIn)
                let igniteT = max(ignite, 0)
                DiamondPrimaryButton(title: "Terminer la série") {
                    effortSeconds = elapsed
                    draftRest = nil
                    entering = true
                }
                .padding(.horizontal, 26)
                .opacity(chipInS * (1 - sstep(0, 0.25, igniteT)))
                .allowsHitTesting(chipIn > 0.6 && !resting)
                .position(x: w / 2, y: h - 78)
                Button { startEnvol(now) } label: {
                    Text("Passer le repos")
                        .font(.inter(15, .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(chipInS * sstep(0.30, 0.70, igniteT)
                         * (1 - sstep(0, 0.18, max(ev, 0))))
                .allowsHitTesting(resting && envolAt == nil)
                .position(x: w / 2, y: h - 72)
            } else if !Self.cycling {
                Button {
                    summitAt = nil
                    summitFx = nil
                    fingerLoc = nil
                    release = nil
                    dragPath = []
                    flareAt = nil
                    RocketHaptics.shared.dragEnd()
                    LensTheme.shared.stop()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("REJOUER")
                            .font(.inter(11, .semibold))
                            .tracking(2.6)
                    }
                    .foregroundStyle(Color.white.opacity(0.55))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Capsule().stroke(Color.white.opacity(0.16),
                                                 lineWidth: 1))
                }
                .opacity(chipIn * chipIn * (3 - 2 * chipIn))
                .position(x: w / 2, y: h - 52)
            }
        }
        .frame(width: w, height: h)
        .clipped()
    }

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }
}

// MARK: - L'haptique de l'envol

/// LE DÉPART DANS LA MAIN. Quatre grains qui enflent pendant que la pastille
/// tremble — l'énergie qui s'accumule —, puis UN coup net au décollage.
/// Écrite à part, comme le veut la maison : le slam de la carte, la course du
/// galet et le grondement de la fusée ont chacun leur signature, et deux
/// gestes qui tapent pareil finissent par se confondre dans la main.
enum EnvolHaptic {
    static func play(liftAt: Double) {
        let soft = UIImpactFeedbackGenerator(style: .soft)
        let rigid = UIImpactFeedbackGenerator(style: .rigid)
        soft.prepare(); rigid.prepare()
        for (i, t) in [0.0, 0.14, 0.27, 0.40].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                soft.impactOccurred(intensity: 0.30 + 0.16 * Double(i))
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + liftAt) {
            rigid.impactOccurred(intensity: 1.0)
        }
    }
}

// MARK: - La partition du sommet
//
// Le doigt a fini son œuvre : une pause tenue (la fusée gronde), le zoom
// en chute DANS le verre (l'école ConnexionCine : 8^(u^1,8), le flou
// couvre la trame avant qu'elle ne se voie), la nuit qui remplit
// l'intérieur — et LA COUPE, cachée dans la nuit du verre : l'écran est
// déjà tout entier l'intérieur de l'objet quand le monde change dessous.
enum SummitCine {
    /// La pause tenue — la fusée gronde, rien ne bouge encore. MAJESTUEUSE :
    /// on laisse le grondement peser avant le premier millimètre de chute.
    static let hold: Double = 0.50
    /// Le zoom en chute — long, retenu au départ, violent à la fin.
    static let dive: Double = 1.40
    /// LA COUPE — l'écran est plein de la nuit du verre.
    static let cutAt: Double = hold + dive
    /// La renaissance perce le bord haut un souffle après la coupe…
    static let enter: Double = 0.22
    /// …et la descente cinématique dure jusqu'à la pose.
    static let descend: Double = 2.30

    static func diveU(_ e: Double) -> Double {
        min(max((e - hold) / dive, 0), 1)
    }
    static func scale(_ e: Double) -> CGFloat {
        CGFloat(pow(8.0, pow(diveU(e), 2.05)))
    }
    static func blur(_ e: Double) -> CGFloat {
        CGFloat(16 * s(0.35, 1.0, diveU(e)))
    }
    /// La nuit s'installe dans le verre PENDANT la chute et s'achève
    /// avant elle : un battement de nuit pure précède la coupe.
    static func nightFill(_ e: Double) -> Double { s(0.22, 0.72, diveU(e)) }

    /// La braise chauffe avec le grondement — la fusée avant le départ.
    static func flare(_ e: Double) -> Double {
        0.30 + 0.55 * min(e / cutAt, 1.0)
    }

    private static func s(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let u = min(max((x - a) / (b - a), 0), 1)
        return u * u * (3 - 2 * u)
    }
}

// MARK: - Les étoiles rares
//
/// La nuit n'est pas un noir plat : quatorze étoiles posées une fois
/// (hash pur), qui respirent à peine — des billes douces (cœur net + halo),
/// jamais des points durs.
private struct NightStars: View {
    let t: Double
    var body: some View {
        Canvas { ctx, sz in
            for i in 0..<14 {
                let s = Double(i) * 39.7 + 11.3
                let hx = abs((sin(s * 12.9898) * 43758.5453)
                    .truncatingRemainder(dividingBy: 1))
                let hy = abs((sin(s * 78.233) * 24634.6345)
                    .truncatingRemainder(dividingBy: 1))
                let x = sz.width * (0.06 + 0.88 * hx)
                let y = sz.height * (0.05 + 0.80 * hy)
                let breath = 0.5 + 0.5 * sin(t * (0.35 + 0.22 * hx) + s)
                let a = 0.05 + 0.13 * breath * breath
                let r: Double = hx > 0.72 ? 1.6 : 1.1
                ctx.fill(Path(ellipseIn:
                    CGRect(x: x - r * 2.2, y: y - r * 2.2,
                           width: r * 4.4, height: r * 4.4)),
                         with: .color(.white.opacity(a * 0.25)))
                ctx.fill(Path(ellipseIn:
                    CGRect(x: x - r / 2, y: y - r / 2,
                           width: r, height: r)),
                         with: .color(.white.opacity(a)))
            }
        }
    }
}
