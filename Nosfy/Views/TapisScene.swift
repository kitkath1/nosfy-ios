import SwiftUI

// MARK: - Le player TAPIS — deux pastilles, le chrono qui se tape
//
// Plan : tools/tapis/PLAN-TAPIS-HIIT.md — §V2 (le rejet du J0 et ce qui le
// remplace), §V2.4 bis (la recette de braise, MESURÉE au banc).
//
// ⚠️ CE FICHIER EST LA V2. La V1 a été REJETÉE au simulateur (« les couleurs
// sont noir dégradé beurk ; le premier est coupé par une claque noire »).
// Les trois causes, mesurées, et ce qu'elles imposent ici :
//
// ① LE GRIS venait des BLANCS du feu. Sur un lit LOCAL sombre, les langues
//   blanches de `glowShade` (LiquidLens.metal:604, un plancher à 0,55) et la
//   voix blanche #2 ne lisent plus comme des pointes chaudes : elles
//   DEVIENNENT le pixel le plus clair, donc l'aura. Mesuré : G/R 0,574 et
//   B/R 0,366 — du gris. Remède : le stitchable `braiseGlow`, le même feu
//   sans ses deux registres blancs → G/R 0,336 · B/R 0,026, dans la loi.
//
// ② LA CLAQUE NOIRE était mon `Color.black` opaque dans chaque carré. Ici il
//   n'y a PLUS de carré, PLUS de fond, PLUS de `layerEffect` : la pastille
//   EST la couche de feu (un `colorEffect` sur un Rectangle transparent).
//   C'est exactement ce que Kathryn a validé sur planche. Bonus mesuré : une
//   passe de verre en moins par pastille, et les reflets spéculaires blancs
//   du verre — l'autre agent de grisaille — disparaissent avec.
//
// ③ LE CADRE ÉTAIT TROP PETIT pour la couronne. Le feu vit jusqu'à ~2,6·R ;
//   mon demi-côté valait 1,39·R et mon masque jetait 41 % de l'énergie, en
//   coupant l'anneau (là où la braise EST) et en gardant le cœur mort.
//   Ici : demi-côté 1,80·R (24 % jetés, mesuré ACCEPTABLE) et le masque fond
//   de 0,72 à 1,00 du demi-côté.
//
// TOUT EST FONCTION PURE DU TEMPS (la loi de LiquidLensLab) : l'arrivée, le
// battement de la seconde, la respiration du repos et le pulse de la phrase
// dérivent de dates-ancres — jamais un `withAnimation` sur
// un état, jamais une accumulation. Le chrono survit à l'arrière-plan.

// MARK: - Le MODE : HIIT, escalier, tapis modéré (15-09, plan cardio §B)

/// Ce qui change d'un cardio à l'autre sur le double galet — et RIEN d'autre :
/// la plage de la commande, sa valeur de départ, son unité, et ce qu'un
/// segment devient une fois écrit. Le dessin, le geste, la fête, le fond par
/// paliers sont les mêmes pour les trois (« même layout », verdict 15-09).
struct ModeCardio: Equatable {
    /// La plage de la commande du bas de l'écran.
    let plage: ClosedRange<Double>
    /// La vitesse d'EFFORT au départ (10 km/h : « zéro n'est pas une vitesse
    /// de course », verdict 31-08) et la vitesse de RÉCUP au départ.
    let depart: Double
    let departRecup: Double
    /// « km/h » — ou rien : l'escalier compte en NIVEAUX de machine.
    let unite: String
    /// Ce que l'encre écrit sous la valeur.
    let libelle: String
    /// Points de glisse par cran : toute la plage tient en deux largeurs
    /// d'écran (40 pt × 20 crans = 800 pt ; 53 × 15 = 800 pt).
    let pasGlisse: Double
    /// L'escalier n'est JAMAIS un sprint (verdict 15-09) : ses montées sont
    /// des accélérations, et tout ce qui monte est un effort.
    let estNiveau: Bool
    /// LA GRAMMAIRE (16-09, plan cardio « 16-09 », G5) : le HIIT se court en
    /// SETS et RÉCUPS (un tap = un set fini, le suivant = il repart) ; le
    /// tapis lent et l'escalier se courent AU LONG — une seule course, le
    /// chrono depuis le lancement, le tap = une PAUSE (jamais écrite), un
    /// segment par allure scellée, Finish écrit ce qui court. Payé : elle a
    /// tapé « pour lancer » un tapis lent, c'était un stop, elle a couru
    /// vingt minutes en récup et Finish n'a rien écrit → 0 pièce.
    let auLong: Bool

    /// Le genre d'un segment d'EFFORT à cette vitesse — c'est ce que la
    /// phase écrite portera. HIIT / tapis : sprint au-dessus du seuil de la
    /// maison (15 km/h, `SemaineStats.seuilEffort`), accélération dessous.
    func kindEffort(_ v: Double) -> PhaseKind {
        if estNiveau { return .acceleration }
        return v >= SemaineStats.seuilEffort ? .sprint : .acceleration
    }
    /// Le genre d'une RÉCUP : récupération si on avance encore (« 1 min à
    /// 9 km/h », son exemple), repos si la machine est à zéro.
    func kindRecup(_ v: Double) -> PhaseKind { v > 0 ? .recuperation : .repos }
    /// Le récap de la dalle : « 17 km/h » / « niveau 11 ».
    func valeur(_ v: Double) -> String {
        let n = v.formatted(.number.precision(.fractionLength(0...1)))
        return estNiveau ? "NIVEAU \(n)" : "\(n) KM/H"
    }
    /// L'échelle du graphe de la fiche (G9) : le HIIT garde la définition de
    /// la maison (braise ≥ 15 km/h), l'escalier ses niveaux, le tapis lent
    /// SA course (tout ce qui avance est un effort, chaleur 4 → 12 km/h) —
    /// à 5-9 km/h tout sortait gris (« on dirait que c'est empty »).
    var echelle: EchellePaliers {
        if estNiveau { return .escalier }
        return auLong ? .tapisLent : .tapis
    }

    /// LE PLANCHER DU BARÈME, lu dans `reward_rules` (`cardio_tapis_min_minutes`,
    /// `cardio_escalier_min_minutes`) par `DecideurSerie.chargerRegles` — la
    /// même réponse que `seuil_effort_kmh`. 5 en repli hors ligne, la valeur
    /// de la base. La quittance de Finish s'en sert pour DIRE « sous 5 min,
    /// pas payé » au lieu de laisser croire.
    static var minMinutesTapis: Double = 5
    static var minMinutesEscalier: Double = 5
    /// `cardio_hiit_effort_min_s` : un HIIT n'est payé comme un HIIT que si
    /// un set d'au moins 20 s a atteint le seuil ; sinon le serveur le paie
    /// comme un tapis (toutes les minutes à vitesse > 0, plancher tapis).
    static var hiitEffortMinS: Double = 20
    var minMinutes: Double { estNiveau ? Self.minMinutesEscalier : Self.minMinutesTapis }

    static let hiit = ModeCardio(plage: 0...20, depart: 10, departRecup: 7,
                                 unite: "km/h", libelle: "km/h", pasGlisse: 40,
                                 estNiveau: false, auLong: false)
    static let tapisModere = ModeCardio(plage: 0...20, depart: 7, departRecup: 5,
                                        unite: "km/h", libelle: "km/h", pasGlisse: 40,
                                        estNiveau: false, auLong: true)
    static let escalier = ModeCardio(plage: 1...15, depart: 6, departRecup: 1,
                                     unite: "", libelle: "NIVEAU", pasGlisse: 53,
                                     estNiveau: true, auLong: true)

    /// Le mode d'un exercice du catalogue — nil pour tout ce qui n'a pas de
    /// double galet (la muscu, et la piscine qui se saisit à la main).
    static func pour(_ exercise: Exercise) -> ModeCardio? {
        switch exercise.id {
        case "hiit-tapis": return .hiit
        case "escalier": return .escalier
        case "tapis-lent": return .tapisModere
        default: return nil
        }
    }
}

// MARK: - L'état de la séance tapis

/// L'état vivant du mode tapis — UN observable, jamais des @State éparpillés
/// sur la page (la fiche porte déjà vidéos et shaders : l'Observation ne
/// réveille que les vues qui lisent).
@MainActor @Observable
final class SeanceTapis {
    /// `court` = on avance (un set en HIIT, la course au long) ; `repos` =
    /// l'entre-sets du HIIT (la récup, écrite à la relance) ; `pause` = la
    /// course au long figée (jamais écrite : une pause n'est pas une allure).
    enum Etat { case court, repos, pause }

    /// Le mode : ce que la commande règle, et ce qu'un segment devient.
    let mode: ModeCardio
    /// L'instant où les pastilles ARRIVENT (l'ancre de toute la scène).
    let naissance: Date
    private(set) var etat: Etat = .court
    /// Le rang du set en cours (1-based).
    private(set) var setIndex = 1
    /// Les sets terminés — le pilote du palier de braise ET du crescendo.
    private(set) var setsFaits = 0
    /// L'ancre du chrono du set en cours — au long, celle de la FOULÉE en
    /// cours (depuis le lancement ou la reprise) : c'est elle qui fait battre
    /// la braise et se rallumer au départ.
    private(set) var setDebut: Date?
    /// L'ancre du repos (l'entre-sets montre le temps écoulé, pas un compte)
    /// — et de la pause au long (la même respiration lente).
    private(set) var reposDebut: Date?
    /// AU LONG : le temps couru AVANT la foulée en cours (les pauses ne
    /// comptent pas), l'ancre du segment d'allure en cours et son allure.
    /// Le chrono = `couruAvant + (now − setDebut)` ; un segment = ce qui a
    /// été couru à UNE allure, écrit au sceau suivant, à la pause, à Finish.
    private(set) var couruAvant: TimeInterval = 0
    private(set) var segmentDebut: Date?
    private(set) var segmentVitesse: Double
    /// Ce qui a été ÉCRIT (sets en HIIT, segments au long) — la quittance.
    private(set) var segmentsFaits = 0
    private(set) var secondesEcrites = 0
    private(set) var vitesseParSeconde: Double = 0
    /// CE QUE LE BARÈME VERRA : les secondes à vitesse > 0 (sets, récups,
    /// segments — le serveur filtre `speed > 0`), et « un set d'au moins 20 s
    /// au seuil » (la porte du barème HIIT). Les deux comptent aussi ce qui
    /// était DÉJÀ écrit dans ce passage avant cette scène (`dejaSecondes`) :
    /// la quittance juge l'exercice, pas la scène.
    private(set) var secondesAvancees = 0
    private(set) var effortAuSeuil = false
    /// Finish a été glissé : plus aucun tap ne compte, la quittance est là.
    private(set) var terminee = false
    /// Le jeton du POINTAGE au long : un segment qui dure plus de cinq
    /// minutes à la même allure est écrit par tranches — une app tuée, un
    /// STOP par la pilule, ne perdent que la tranche en cours, jamais la
    /// course (loi d'`ecrirePhase` : « une app tuée ne perd que le set en
    /// cours »).
    private var pointageJeton = 0
    static let tranchePointage: TimeInterval = 300
    /// La vitesse COURANTE — la commande l'écrit ; c'est elle que la phase
    /// emporte au stop (l'intervalle) et à la relance (la récup).
    var vitesse: Double
    /// LES DEUX MÉMOIRES (verdict Q2/Q15 du 15-09 : « 30 s à 15 km/h puis
    /// 1 min à 9 km/h, il faut le noter »). Au stop la commande BASCULE sur
    /// la vitesse de récup ; à la relance elle revient à celle de l'effort.
    /// Sans ça une récup non réglée hériterait des 17 km/h de l'effort et le
    /// serveur la compterait comme un effort. Ce qu'elle règle pendant la
    /// récup devient la nouvelle mémoire de récup, et réciproquement.
    private(set) var vitesseEffort: Double
    private(set) var vitesseRecup: Double
    /// L'instant où la vitesse a été SCELLÉE — l'ancre du halo ET de la dalle
    /// de confirmation. Une date, pas un booléen : les deux sont des fonctions
    /// pures du temps, ils ne s'animent pas par un état qu'on pousse.
    var vitesseScellee: Date?
    /// La valeur qu'on vient de choisir — ce que la dalle annonce.
    var vitesseChoisie: Int
    /// Le bilan du dernier set fini — ce que la pop-up flammes raconte.
    private(set) var dernierBilan: BilanSet?
    /// CE QUE LA DALLE DIT — « SET 1 END · 0:45 · 10 KM/H · Saved » au stop,
    /// la quittance « SAVED · 20:00 · 7 KM/H · paid at session end » à Finish.
    private(set) var dalle: TexteDalle?
    /// La dalle est à l'écran (elle se retire seule).
    var dalleVisible = false
    /// La pop-up flammes est à l'écran (elle attend un tap).
    var popupVisible = false

    /// CE QUE LA SCÈNE RAPPORTE (15-09) : l'intervalle fini au stop, la récup
    /// finie à la relance — et, au long (16-09), le segment d'allure fini au
    /// sceau, à la pause, à Finish. La scène ne connaît pas SwiftData — c'est
    /// la fiche qui écrit les `CardioPhase` (faites) dans le bloc de son passage.
    var onSetFini: ((BilanSet) -> Void)?
    var onRecupFinie: ((_ secondes: Int, _ vitesse: Double) -> Void)?
    var onSegmentFini: ((_ rang: Int, _ secondes: Int, _ vitesse: Double) -> Void)?
    /// Événements du player et sceau de la molette seulement, sans tick supplémentaire.
    var onLiveChange: (() -> Void)?

    var livePhase: WorkoutLivePhase {
        switch etat {
        case .court:
            return .init(kind: .effort, startedAt: setDebut,
                         elapsed: mode.auLong ? couruAvant : 0)
        case .repos: return .init(kind: .recovery, startedAt: reposDebut)
        case .pause: return .init(kind: .pause, elapsed: couruAvant)
        }
    }

    struct BilanSet: Equatable {
        let rang: Int
        let secondes: Int
        let vitesse: Double
        let mode: ModeCardio
        /// « 0:45 · 17 KM/H » / « 0:45 · NIVEAU 11 » — le mini-récap.
        var recap: String {
            String(format: "%d:%02d", secondes / 60, secondes % 60) + " · " + mode.valeur(vitesse)
        }
    }

    struct TexteDalle: Equatable {
        let titre: String
        let recap: String
        let pied: String
    }

    /// LA QUITTANCE DE FINISH (G8) : ce qui est écrit, et si le barème le
    /// paiera — « sous 5 min, pas payé » se DIT, il ne se découvre pas à la
    /// clôture avec zéro pièce.
    struct Quittance: Equatable {
        let segments: Int
        let secondes: Int
        /// L'allure moyenne pondérée par le temps (au long) ; en HIIT, la
        /// vitesse n'a pas de moyenne qui parle : 0.
        let vitesse: Double
        let payable: Bool
    }

    /// La durée de l'arrivée : le set 1 démarre quand les pastilles se posent.
    static let arrivee: Double = 0.85

    /// `avance` : le banc `-cardioAvance <s>` fait naître la scène comme si
    /// elle courait depuis s secondes — la seule façon de mesurer un barème
    /// à cinq minutes sans attendre cinq minutes.
    /// `setsFaits` : ce que ce PASSAGE a déjà écrit (une seconde course sur
    /// la même fiche continue la numérotation : rang unique par phase, le
    /// graphe reste dans l'ordre) ; `dejaSecondes` / `dejaAuSeuil` : ce que
    /// le barème en verra, pour que la quittance ne dise pas « pas payé » à
    /// un exercice que le serveur paiera.
    init(mode: ModeCardio = .hiit, naissance: Date = .now, figee: Bool = false,
         setsFaits: Int = 0, avance: TimeInterval = 0,
         dejaSecondes: Int = 0, dejaAuSeuil: Bool = false) {
        self.mode = mode
        self.naissance = (figee ? naissance.addingTimeInterval(-30) : naissance)
            .addingTimeInterval(-avance)
        self.setsFaits = setsFaits
        self.segmentsFaits = setsFaits
        self.setIndex = setsFaits + 1
        self.secondesAvancees = dejaSecondes
        self.effortAuSeuil = dejaAuSeuil
        let depart = self.naissance.addingTimeInterval(Self.arrivee)
        self.setDebut = depart
        self.segmentDebut = depart
        self.vitesse = mode.depart
        self.segmentVitesse = mode.depart
        self.vitesseEffort = mode.depart
        self.vitesseRecup = mode.departRecup
        self.vitesseChoisie = Int(mode.depart.rounded())
        armerLePointage()
    }

    /// LE RANG ÉCRIT au-dessus du chrono (G2) : « SET 1 » pendant l'effort,
    /// et dès le stop « SET 2 » — la récup appartient au set qui vient.
    var rangAffiche: Int { setsFaits + 1 }

    /// LE CHRONO. HIIT : le set en cours, ou la récup écoulée. Au long : le
    /// temps couru depuis le lancement, pauses déduites, figé en pause.
    func secondes(_ now: Date) -> Int {
        if mode.auLong {
            let foulee = setDebut.map { max(0, now.timeIntervalSince($0)) } ?? 0
            return Int(couruAvant + foulee)
        }
        if etat == .court, let d0 = setDebut { return max(0, Int(now.timeIntervalSince(d0))) }
        if let r0 = reposDebut { return max(0, Int(now.timeIntervalSince(r0))) }
        return 0
    }

    /// LE TAP SUR LA PASTILLE CHRONO — un seul geste, l'acte que la pastille
    /// écrit : stop / start set (HIIT), pause / reprise (au long). Le banc et
    /// le lab passent par ici, jamais à côté (deux chemins = un banc qui ment).
    func basculer(_ now: Date = .now) {
        guard !terminee else { return }
        switch etat {
        case .court: mode.auLong ? pauser(now) : stopper(now)
        case .repos: relancer(now)
        case .pause: reprendre(now)
        }
    }

    /// Le tap sur la pastille chrono pendant l'effort : le set est FAIT.
    /// L'intervalle est RAPPORTÉ (la fiche l'écrit), la commande bascule sur
    /// la récup, la fête part.
    func stopper(_ now: Date = .now) {
        guard etat == .court, !mode.auLong else { return }
        let secondes = setDebut.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
        // Un tap dans la première seconde n'est pas un set : rien à écrire,
        // rien à fêter, rien à compter (`ecrirePhase` refuse 0 s — la scène
        // ne doit pas dire « Saved » pour ce qu'il refuse).
        guard secondes > 0 else { return }
        defer { onLiveChange?() }
        let bilan = BilanSet(rang: setIndex, secondes: secondes, vitesse: vitesse, mode: mode)
        dernierBilan = bilan
        dalle = TexteDalle(titre: "SET \(bilan.rang) END", recap: bilan.recap, pied: "Saved")
        etat = .repos
        setsFaits += 1
        setDebut = nil
        reposDebut = now
        // La bascule effort → récup : on garde ce qu'on courait, on propose
        // ce qu'on récupérait la dernière fois.
        vitesseEffort = vitesse
        vitesse = vitesseRecup
        vitesseChoisie = Int(vitesse.rounded())
        compter(secondes, vitesse: bilan.vitesse)
        onSetFini?(bilan)
        lancerLaFete()
    }

    /// LE POINTAGE (au long) : cinq minutes à la même allure, et le segment
    /// est écrit puis rouvert à cette allure. Un jeton par segment ouvert :
    /// un sceau, une pause, Finish l'invalident.
    private func armerLePointage() {
        guard mode.auLong else { return }
        pointageJeton += 1
        let jeton = pointageJeton
        guard let d0 = segmentDebut else { return }
        let echeance = d0.addingTimeInterval(Self.tranchePointage)
        Task { @MainActor [weak self] in
            let reste = echeance.timeIntervalSinceNow
            if reste > 0 { try? await Task.sleep(for: .seconds(reste)) }
            guard let self, self.pointageJeton == jeton, !self.terminee,
                  self.etat == .court, self.segmentDebut != nil else { return }
            let now = Date()
            self.fermerSegment(now)
            self.segmentDebut = now
            self.armerLePointage()
        }
    }

    // MARK: au long — la pause, la reprise, le sceau, et ce qui s'écrit

    /// LA PAUSE (G6) : le segment couru est écrit à son allure, le chrono se
    /// fige, rien de la pause ne s'écrit. Aucune fête : on n'a rien fini.
    func pauser(_ now: Date = .now) {
        guard etat == .court, mode.auLong else { return }
        defer { onLiveChange?() }
        fermerSegment(now)
        if let d0 = setDebut { couruAvant += max(0, now.timeIntervalSince(d0)) }
        etat = .pause
        setDebut = nil
        segmentDebut = nil
        reposDebut = now
        pointageJeton += 1
    }

    /// LA REPRISE : la foulée repart, un segment neuf à l'allure courante.
    func reprendre(_ now: Date = .now) {
        guard etat == .pause, !terminee else { return }
        defer { onLiveChange?() }
        etat = .court
        setDebut = now
        segmentDebut = now
        segmentVitesse = vitesse
        reposDebut = nil
        armerLePointage()
    }

    /// LE SCEAU D'UNE ALLURE (G7) : la commande relâchée sur une autre valeur
    /// ferme le segment courant et en ouvre un à la nouvelle allure — c'est
    /// ce qui donne au graphe un profil et au barème ses minutes × km/h.
    /// Sous 5 s de segment, on ne découpe pas : les secondes vont à la
    /// nouvelle allure (un segment de 2 s n'est qu'un tremblement).
    func sceller(_ v: Double, _ now: Date = .now) {
        guard !terminee else { return }
        defer { onLiveChange?() }
        guard mode.auLong else { return }
        guard v != segmentVitesse else { return }
        guard etat == .court, let d0 = segmentDebut else {
            segmentVitesse = v          // en pause : le prochain segment part à cette allure
            return
        }
        if now.timeIntervalSince(d0) >= 5 {
            fermerSegment(now)
            segmentDebut = now
            armerLePointage()
        }
        segmentVitesse = v
    }

    /// Le segment en cours est ÉCRIT (rapporté à la fiche) à son allure.
    /// À 0 (la machine arrêtée, la commande scellée à zéro) rien ne s'écrit
    /// et rien ne se compte : c'est une pause qui ne dit pas son nom, et le
    /// serveur ne voit que `speed > 0` — la quittance doit voir pareil.
    private func fermerSegment(_ now: Date) {
        guard let d0 = segmentDebut else { return }
        let secondes = max(0, Int(now.timeIntervalSince(d0)))
        guard secondes > 0, segmentVitesse > 0 else { return }
        segmentsFaits += 1
        compter(secondes, vitesse: segmentVitesse)
        onSegmentFini?(segmentsFaits, secondes, segmentVitesse)
    }

    private func compter(_ secondes: Int, vitesse v: Double) {
        secondesEcrites += secondes
        vitesseParSeconde += v * Double(secondes)
        if v > 0 { secondesAvancees += secondes }
        if v >= SemaineStats.seuilEffort, Double(secondes) >= Self.effortMinS { effortAuSeuil = true }
    }
    private static var effortMinS: Double { ModeCardio.hiitEffortMinS }

    /// L'ABANDON : la séance s'est fermée sous la scène (le STOP de la
    /// pilule). Plus rien ne s'écrit, plus rien ne se tape, pas de quittance
    /// — la clôture est déjà partie, un segment de plus n'irait nulle part.
    func abandonner(_ now: Date = .now) {
        defer { onLiveChange?() }
        terminee = true
        popupVisible = false
        pointageJeton += 1
        feteJeton += 1
        if etat == .court, let d0 = setDebut { couruAvant += max(0, now.timeIntervalSince(d0)) }
        setDebut = nil
        segmentDebut = nil
    }

    /// FINISH ÉCRIT CE QUI COURT (P1 ④, G3, G8) : le set en cours en HIIT,
    /// le segment en cours au long — un set couru n'est jamais perdu. La
    /// récup du HIIT interrompue par Finish n'est pas un segment : rien. Rend
    /// la quittance (nil si rien n'a jamais été écrit : pas de dalle pour
    /// rien) et la pose à l'écran ; la scène se démonte après elle.
    @discardableResult
    func finir(_ now: Date = .now) -> Quittance? {
        guard !terminee else { return nil }
        defer { onLiveChange?() }
        terminee = true
        popupVisible = false
        if mode.auLong {
            if etat == .court { fermerSegment(now) }
        } else if etat == .court,
                  let secondes = setDebut.map({ max(0, Int(now.timeIntervalSince($0))) }),
                  secondes > 0 {
            let bilan = BilanSet(rang: setIndex, secondes: secondes, vitesse: vitesse, mode: mode)
            dernierBilan = bilan
            setsFaits += 1
            compter(secondes, vitesse: vitesse)
            onSetFini?(bilan)
        }
        // La foulée en cours se replie dans le temps couru (le palier de
        // braise et le chrono ne retombent pas) ; la braise ne se rembobine
        // pas si l'on était déjà au repos (le feu ne re-flashe pas).
        if etat == .court {
            if let d0 = setDebut { couruAvant += max(0, now.timeIntervalSince(d0)) }
            reposDebut = now
        }
        etat = mode.auLong ? .pause : .repos
        setDebut = nil
        segmentDebut = nil
        pointageJeton += 1
        feteJeton += 1
        guard secondesEcrites > 0 else { return nil }
        let moyenne = vitesseParSeconde / Double(secondesEcrites)
        // CE QUE LE BARÈME FERA (lu dans `pieces_cardio_seance`) : au long,
        // les minutes à vitesse > 0 contre le plancher ; en HIIT, la porte
        // « un set ≥ 20 s au seuil », sinon le repli tapis (les mêmes minutes,
        // récups comprises, contre le plancher tapis). Sur l'EXERCICE entier
        // (`dejaSecondes`), pas sur cette scène seule.
        let plancher = mode.minMinutes * 60
        let repli = Double(secondesAvancees) >= plancher
        let payable = mode.auLong ? repli : (effortAuSeuil || repli)
        let q = Quittance(segments: mode.auLong ? segmentsFaits : setsFaits,
                          secondes: secondesEcrites,
                          vitesse: mode.auLong ? moyenne : 0,
                          payable: payable)
        let duree = String(format: "%d:%02d", q.secondes / 60, q.secondes % 60)
        let recap = mode.auLong
            ? duree + " · " + mode.valeur((moyenne * 2).rounded() / 2)
            : "\(q.segments) SET\(q.segments > 1 ? "S" : "") · " + duree
        let minutes = Int(mode.minMinutes.rounded())
        let pied: String
        if payable {
            pied = "Paid at session end"
        } else if mode.auLong {
            pied = "Under \(minutes) min · not paid"
        } else {
            let seuil = Int(SemaineStats.seuilEffort.rounded())
            let minS = Int(ModeCardio.hiitEffortMinS.rounded())
            pied = "No \(minS) s at \(seuil) km/h, under \(minutes) min · not paid"
        }
        dalle = TexteDalle(titre: "SAVED", recap: recap, pied: pied)
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) { dalleVisible = true }
        return q
    }

    /// LA FÊTE vit DANS LE MODÈLE, pas dans le geste : le banc `-tapisAuto`
    /// appelle `stopper()` (le simulateur n'a pas de doigt) et doit voir
    /// EXACTEMENT ce que le doigt déclenche. Deux chemins qui divergent, c'est
    /// un banc qui ment — on ne filme alors plus ce qu'on livre.
    ///
    /// La séquence : dalle à +0 s, pop-up à +0,4 s (elle naît SOUS la dalle
    /// qui descend, pas en même temps), dalle retirée à +3,2 s (la durée
    /// maison). La pop-up, elle, attend le tap : c'est l'instant de repos, et
    /// une card qui s'enfuit n'encourage personne.
    private func lancerLaFete() {
        feteJeton += 1
        let jeton = feteJeton
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            dalleVisible = true
        }
        // Un jeton : Finish dans les 3,2 s d'un stop ne doit ni voir la
        // pop-up remonter, ni sa quittance retirée par le minuteur du set.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { [weak self] in
            guard let self, self.feteJeton == jeton else { return }
            withAnimation(.easeOut(duration: 0.30)) { self.popupVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.20) { [weak self] in
            guard let self, self.feteJeton == jeton else { return }
            withAnimation(.easeIn(duration: 0.28)) { self.dalleVisible = false }
        }
    }
    private var feteJeton = 0

    /// Le tap sur la pastille chrono au repos : la récup est FAITE (elle est
    /// rapportée, à la vitesse qu'on tenait), le set suivant part, la
    /// commande revient à la vitesse d'effort.
    func relancer(_ now: Date = .now) {
        guard etat == .repos, !terminee else { return }
        defer { onLiveChange?() }
        popupVisible = false
        let secondes = reposDebut.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
        let vRecup = vitesse
        etat = .court
        setIndex = setsFaits + 1
        setDebut = now
        reposDebut = nil
        vitesseRecup = vRecup
        vitesse = vitesseEffort
        vitesseChoisie = Int(vitesse.rounded())
        if secondes > 0 {
            // La récup compte pour le barème de repli (minutes à vitesse > 0),
            // pas pour le récap des sets.
            if vRecup > 0 { secondesAvancees += secondes }
            onRecupFinie?(secondes, vRecup)
        }
    }

    /// LA BRAISE (effort, repos) à cet instant. HIIT : le palier des sets
    /// faits, `k = min(setsFaits, 6)` — 7 valeurs, pas plus (au-delà l'écran
    /// serait blanc de rouge). Au long il n'y a pas de set : la braise monte
    /// avec le TEMPS COURU, un palier par trois minutes (plein feu à 18 min),
    /// interpolée entre deux paliers — la course se voit chauffer, sans cran.
    func braise(_ now: Date) -> (p: (ig: Double, chaleur: Double), q: (ig: Double, chaleur: Double)) {
        let n = TapisBraise.paliers.count - 1
        guard mode.auLong else {
            let k = min(setsFaits, n)
            return (TapisBraise.paliers[k], TapisBraise.repos(k))
        }
        let x = min(Double(secondes(now)) / 180.0, Double(n))
        let k = Int(x), f = x - Double(k), k1 = min(k + 1, n)
        func lerp(_ a: (ig: Double, chaleur: Double), _ b: (ig: Double, chaleur: Double)) -> (ig: Double, chaleur: Double) {
            (a.ig + (b.ig - a.ig) * f, a.chaleur + (b.chaleur - a.chaleur) * f)
        }
        return (lerp(TapisBraise.paliers[k], TapisBraise.paliers[k1]),
                lerp(TapisBraise.repos(k), TapisBraise.repos(k1)))
    }
}

// MARK: - La palette, cuite au banc

/// Les valeurs SORTENT du banc `tools/tapis/essai_braise.py`, qui re-joue le
/// shader à la constante près. Elles ne s'inventent pas ici — on les recopie.
enum TapisBraise {
    /// (ig, chaleur) par palier. `ig` porte la FLAMME, `chaleur` la TEINTE.
    ///
    /// ⚠️ `ig` progresse en GÉOMÉTRIE, pas en addition : l'œil lit des
    /// RAPPORTS de luminance. Une suite arithmétique donnait des sauts de
    /// ×1,60 en bas et ×1,08 en haut — mesuré : les trois derniers paliers se
    /// lisaient comme un seul. Ici les sauts vont de ×1,17 à ×1,46.
    ///
    /// G/R mesuré : 0,248 · 0,281 · 0,318 · 0,363 · 0,392 · 0,380 · 0,387,
    /// B/R ≤ 0,035 partout — la loi de la maison (braise 0,30-0,45, B≈0).
    static let paliers: [(ig: Double, chaleur: Double)] = [
        (0.235, -0.34),   // P0 — zéro set : la braise dort
        (0.302, -0.22),
        (0.388, -0.11),
        (0.499,  0.01),   // P3 — braise franche
        (0.641,  0.14),
        (0.824,  0.30),
        (1.000,  0.50),   // P6 — plein feu (≥ 6 sets), la teinte SATURE ici
    ]

    /// L'ENTRE-SETS. ⚠️ **La cendre grise n'existe pas dans cette maison** :
    /// poussé vers le froid, le shader rend `vRacine (1,00 · 0,13 · 0,005)` —
    /// le rouge le plus PROFOND, jamais du gris. Chercher une cendre, c'était
    /// re-fabriquer le défaut rejeté. Le feu RENTRE DANS SES RACINES :
    /// l'`ig` du palier N−2 × 0,62, la chaleur −0,42. Mesuré : G/R 0,258 et
    /// surtout **3,93× moins lumineux** — c'est ce rapport-là qui fait lire
    /// l'état à un mètre, pas une différence de teinte.
    static func repos(_ palier: Int) -> (ig: Double, chaleur: Double) {
        let base = paliers[max(palier - 2, 0)]
        return (base.ig * 0.62, paliers[palier].chaleur - 0.42)
    }

    /// Le demi-côté d'une pastille, en rayons de lentille. Mesuré : à 1,39·R
    /// le cadre jetait 41 % du feu (« TROP ») ; à 1,80·R il en jette 24 %.
    static let demiSurR: CGFloat = 1.80
}

// MARK: - La scène

struct TapisScene: View {
    var seance: SeanceTapis
    /// LA FIN DE L'EXERCICE — pas de la séance (verdict 15-09 : « Finish
    /// dans le double galet termine l'exercice, pas la séance » ; la séance
    /// se termine par la dalle, comme partout). Le slider commet.
    var onFinish: () -> Void = {}
    /// BANC : les horloges clouées à cet instant après la naissance.
    var tempsFige: Double? = nil
    /// L'état de la vitesse. Il vit ICI et pas dans `SeanceTapis` : sa
    /// position continue s'écrit à chaque événement de doigt, et elle ne doit
    /// pas réveiller les shaders de feu.
    @State private var vit: EtatVitesse

    init(seance: SeanceTapis, onFinish: @escaping () -> Void = {},
         tempsFige: Double? = nil) {
        self.seance = seance
        self.onFinish = onFinish
        self.tempsFige = tempsFige
        _vit = State(initialValue: EtatVitesse(depart: seance.vitesse))
    }

    /// LA PORTE DES HORLOGES (skill perf §5.①) : la scène s'endort quand son
    /// onglet n'est pas affiché ou qu'un player la recouvre — sauf au banc,
    /// où elle est seule à l'écran.
    private var dort: Bool {
        !TapisBanc.actif
            && (RythmeEcran.dort("exercises") || PlayerEtat.shared.couvre)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()
                TimelineView(.animation(minimumInterval: 1 / 60, paused: dort)) { tl in
                    vivante(w: w, h: h, now: date(tl.date))
                }
                // L'ARC et la FUMÉE : deux vues à part, chacune sur son
                // horloge. L'arc est la SEULE qui suive la position continue.
                AnneauHote(etat: vit, mode: seance.mode,
                           centre: CGPoint(x: w / 2, y: h * Self.yVitesseF),
                           rayon: TapisCotes.rayonAnneau)
                FumeeVitesse(etat: vit,
                             centre: CGPoint(x: w / 2, y: h * Self.yVitesseF),
                             largeur: w, hauteur: h)
                // LA PRISE en premier, les taps DEVANT : dans le
                // chevauchement, c'est le tap du chrono qui doit gagner.
                PriseVitesse(etat: vit, seance: seance, largeur: w,
                             haut: max(0, h * Self.yVitesseF - TapisCotes.rayonDisque - 44),
                             bas: h - 102)
                zonesTactiles(w: w, h: h)
                pied(w: w, h: h)
                fete
            }
        }
    }

    // MARK: LA FÊTE DU STOP — la dalle, puis la pop-up flammes

    /// Deux temps, jamais ensemble : la dalle DIT (« c'est enregistré »), la
    /// pop-up ENCOURAGE. La dalle descend du haut à +0 s ; la pop-up naît à
    /// +0,4 s, sous elle. La dalle est sourde au doigt et se retire seule ; la
    /// pop-up attend un tap, parce que c'est l'instant de repos et qu'une card
    /// qui s'enfuit n'encourage personne.
    @ViewBuilder
    private var fete: some View {
        if let d = seance.dalle, seance.dalleVisible {
            VStack {
                // ⚠️ SANS MONTANT (verdict 15-09 : « pas 20 par intervalle,
                // la séance est jugée à l'intensité » — le serveur paie à la
                // clôture). La dalle est une QUITTANCE : ce set est écrit,
                // voilà ce qu'il a été. À Finish, la même robe dit ce qui est
                // écrit en tout, et si le barème le paiera (G8).
                DalleSetFini(titre: d.titre, recap: d.recap, pied: d.pied)
                    .padding(.horizontal, NotifGeo.margeH)
                    .padding(.top, 10)
                Spacer(minLength: 0)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .allowsHitTesting(false)
            .zIndex(50)
        }
        if let b = seance.dernierBilan, seance.popupVisible {
            RewardPopup(count: b.rang,
                        title: Self.encouragements[b.rang % Self.encouragements.count],
                        subtitle: b.recap,
                        unit: "SETS",
                        style: .fire,
                        onClose: { fermerPopup() })
                .transition(.opacity)
                .zIndex(60)
        }
    }

    private func fermerPopup() {
        withAnimation(.easeOut(duration: 0.28)) { seance.popupVisible = false }
    }

    /// Les mots de l'encouragement — tirés dans l'ordre du rang, jamais au
    /// hasard : deux sets d'affilée ne doivent pas répéter la même phrase.
    private static let encouragements = [
        "KEEP BURNING", "ON FIRE", "ONE MORE", "STILL STANDING", "NO BRAKES",
    ]

    /// L'horloge du banc : `-tapisT` cloue tout à naissance + t.
    private func date(_ d: Date) -> Date {
        guard let t = tempsFige else { return d }
        return seance.naissance.addingTimeInterval(t)
    }

    // MARK: la scène vivante (fonction pure de `now`)

    private func vivante(w: CGFloat, h: CGFloat, now: Date) -> some View {
        // La famille 4 de la sonde : « tapis » — sans ce tic, la scène
        // n'existe pas dans `tics[]` (l'angle mort du skill perf §6.8).
        SondeVol.shared.tic(4)
        let age = now.timeIntervalSince(seance.naissance)
        // L'ARRIVÉE — l'école nightLens : e2 lissé, deux oscillations à la pose.
        let u = min(max(age / SeanceTapis.arrivee, 0), 1)
        let e2 = u * u * (3 - 2 * u)
        let landed = age - SeanceTapis.arrivee
        let rebond = landed > 0 ? 2.6 * sin(landed * 2.1) * exp(-landed * 1.1) : 0
        let court = seance.etat == .court

        // LA VIE DE CHAQUE ÉTAT — deux animations qui ne se ressemblent pas.
        // SET : un BATTEMENT par seconde (attaque 0,10 s, la somme
        //   one(ph)+one(ph+1) traverse la bascule sans pop au wrap).
        // REPOS : une RESPIRATION lente de 4,5 s, aucun battement — le temps
        //   ne se compte plus pareil, et ça se VOIT sans lire un glyphe.
        var vie = 0.0
        if court, let d0 = seance.setDebut, now.timeIntervalSince(d0) > 0 {
            let ph = now.timeIntervalSince(d0).truncatingRemainder(dividingBy: 1.0)
            func one(_ x: Double) -> Double {
                x <= 0 ? 0 : sstep(0, 0.10, x) * exp(-max(x - 0.10, 0) / 0.30)
            }
            vie = one(ph) + one(ph + 1.0)
        } else if let r0 = seance.reposDebut {
            let a = max(0, now.timeIntervalSince(r0))
            vie = 0.5 - 0.5 * cos(a * 2 * .pi / 4.5)
        }

        // LA BASCULE D'ÉTAT SE VOIT : au stop la braise s'effondre en 0,8 s
        // (une décharge, pas un fondu) ; au départ elle se rallume en 0,25 s.
        let ancre = court ? seance.setDebut : seance.reposDebut
        let depuis = ancre.map { max(0, now.timeIntervalSince($0)) } ?? 99
        let bascule = court ? sstep(0, 0.25, depuis) : sstep(0, 0.80, depuis)
        // Au long, la braise monte CONTINÛMENT avec le temps couru (un
        // palier par trois minutes, interpolé) — pas un cran en une image.
        let (p, q) = seance.braise(now)
        let ig = court ? (q.ig + (p.ig - q.ig) * bascule)
                       : (p.ig + (q.ig - p.ig) * bascule)
        let chaleur = court ? (q.chaleur + (p.chaleur - q.chaleur) * bascule)
                            : (p.chaleur + (q.chaleur - p.chaleur) * bascule)
        // L'arrivée allume : rien ne brûle avant que les pastilles se posent.
        let igEntree = ig * Double(sstep(0.15, 1.0, u))

        let yChrono = h * 0.315
        let yVitesse = h * Self.yVitesseF
        let offChrono = (1 - CGFloat(e2)) * -(yChrono + 200) + CGFloat(rebond)
        let offVitesse = (1 - CGFloat(e2)) * (h - yVitesse + 200) - CGFloat(rebond)

        return ZStack {
            PastilleBraise(cote: Self.coteChrono, t: age, ig: igEntree,
                           chaleur: chaleur, pulse: vie)
                .position(x: w / 2, y: yChrono)
                .offset(y: offChrono)
            // Le cadran vitesse : MÊME taille que le chrono (verdict
            // 01-09, il renverse le « plus petit » du 31-08) — la
            // hiérarchie est portée par la braise seule, à 62 %.
            // ⚠️ MAIS quand le cadran s'ouvre, elle S'EMBRASE (62 % → 100 %) :
            // un verre posé sur du noir rend un TROU ou une bille de chrome
            // (la loi du « verre à jeun », p95 = 23). C'est ELLE le repas du
            // verre — sans elle le panneau sort gris, mesuré à la capture.
            // Elle S'EMBRASE sous le doigt (0,62 → 1,00) : c'est la
            // confirmation que la commande a pris, avant même le premier cran.
            PastilleBraise(cote: Self.coteVitesse, t: age * 0.45,
                           ig: igEntree * (vit.prise ? 1.0 : 0.62),
                           chaleur: chaleur - 0.10,
                           pulse: 0)
                .position(x: w / 2, y: yVitesse)
                .offset(y: offVitesse)
            encreChrono(now: now)
                .position(x: w / 2, y: yChrono)
                .offset(y: offChrono)
                .zIndex(10)
            // LE HALO DU SCEAU : un anneau blanc qui s'évase et meurt en
            // 0,60 s autour de la pastille — « pour montrer que c'est
            // enregistré ». Fonction PURE de l'ancre : aucun état à pousser,
            // et il ne se monte QUE pendant ces 0,60 s (au-delà, la vue
            // n'existe pas — rien ne dort à l'écran).
            if let sceau = seance.vitesseScellee {
                let age = now.timeIntervalSince(sceau)
                if age >= 0 && age < Self.dureeSceau {
                    haloSceau(age: age)
                        .position(x: w / 2, y: yVitesse)
                        .zIndex(11)
                }
                // LA CONFIRMATION EN UI : « j'ai bien choisi 15 ». Le halo dit
                // « c'est pris » sans dire QUOI ; la dalle nomme la valeur.
                // Elle vit 1,9 s, fonction pure de l'ancre — au-delà, la vue
                // n'existe pas.
                if age >= 0 && age < Self.dureeDalle {
                    // ⚠️ ELLE VIT SOUS LA VITESSE, PAS EN HAUT. Posée en
                    // haut, elle tombait SUR le chrono (vu à la capture) et
                    // obligeait l'œil à quitter ce qu'il venait de régler.
                    // Ici, elle prend exactement la place que l'arc vient de
                    // libérer : le regard n'a pas à bouger.
                    dalleVitesse(age: age)
                        .position(x: w / 2, y: h * 0.79)
                        .zIndex(12)
                }
            }
            // L'encre de la scène s'efface quand le cadran s'ouvre : il
            // porte la sienne, en grand. Deux fois le même chiffre — l'un net,
            // l'autre flouté sous le verre — c'était le fantôme mesuré à la
            // capture.
            encreVitesse
                .position(x: w / 2, y: yVitesse)
                .offset(y: offVitesse)
                .zIndex(10)
            // (« Tap to stop » et « N MIN · N SETS » sont MORTS — verdict
            // Kathryn 15-09 : « enlève le wording, mets juste le temps ». Les
            // deux vues restent ci-dessous, sans site d'appel.)
        }
        .allowsHitTesting(false)
    }

    // MARK: la phrase (« Tap to stop » / « Tap to start »)

    /// Le pulse est une fonction de l'horloge — jamais un `repeatForever`
    /// d'état (avalé quand un parent se ré-évalue, payé 2× sur PageCard).
    private func phrase(now: Date) -> some View {
        let court = seance.etat == .court
        let texte = court ? "Tap to stop" : "Tap to start"
        let t = now.timeIntervalSince(seance.naissance)
        // La phrase RESPIRE comme l'état : vite pendant l'effort (2,6 s),
        // lentement au repos (4,5 s). Elle dit l'état même de dos.
        let periode = court ? 2.6 : 4.5
        let pulse = 0.32 + 0.58 * (0.5 - 0.5 * cos(t * 2 * .pi / periode))
        let entree = sstep(SeanceTapis.arrivee * 0.7,
                           SeanceTapis.arrivee + 0.4, t)
        return Text(texte)
            .font(.inter(20, .semibold))
            .foregroundStyle(Self.encreApple)
            .opacity(pulse * entree)
    }

    // MARK: les encres

    /// L'encre du chrono.
    ///
    /// ⚠️ L'ALTERNANCE ⏹ EST MORTE (verdict 31-08 : « on doit voir l'icône
    /// stop dans le chrono quand c'est en cours »). Elle était un TUTORIEL :
    /// elle existait pour faire comprendre que la pastille se tape. Un stop
    /// PERMANENT n'a plus rien à apprendre à personne — et garder les deux,
    /// ce serait un glyphe qui clignote à côté d'un glyphe fixe : du bruit.
    /// Le glyphe dit l'ÉTAT, la phrase au-dessus dit le GESTE.
    /// ⚠️ JUSTE LE TEMPS (verdict Kathryn 15-09 : « enlève le wording,
    /// mets juste le temps ») — puis, le 16-09, TROIS MOTS QUI MANQUAIENT
    /// (« on ne comprend pas dans quel set on est ; quand je tape je veux
    /// voir set 2 apparaître ; Start Set dans la pill ») : le RANG au-dessus
    /// du chrono (« SET 1 », et « SET 2 » dès le stop — le chiffre roule), et
    /// au repos, à la place du grand ▶ muet, L'ACTE dans la pastille :
    /// « ▶ START SET 2 ». Le tap fait exactement ce qu'il dit. Au long : pas
    /// de rang, le chrono de la course, ⏸ sous l'effort, « ▶ RESUME » en pause.
    private func encreChrono(now: Date) -> some View {
        let court = seance.etat == .court
        // Finish glissé : le chrono se fige sur ce qui est ÉCRIT (le total
        // de la quittance), plus de rang, plus d'acte — il n'y a plus rien à
        // taper pendant la seconde où la dalle parle.
        let fini = seance.terminee
        let secondes = fini && !seance.mode.auLong ? seance.secondesEcrites : seance.secondes(now)
        return VStack(spacing: court ? 4 : 8) {
            if !seance.mode.auLong, !fini {
                Text("SET \(seance.rangAffiche)")
                    .font(.inter(11, .semibold))
                    .tracking(2.8)
                    .monospacedDigit()
                    .foregroundStyle(Color.white.opacity(0.42))
                    .contentTransition(.numericText(countsDown: false))
                    .animation(.easeOut(duration: 0.45), value: seance.rangAffiche)
                    .padding(.bottom, 2)
            }
            Text(chrono(secondes))
                .font(.inter(52, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(court ? 0.94 : 0.66))
            if fini {
                EmptyView()
            } else if court {
                glyphe(seance.mode.auLong ? "pause.fill" : "stop.fill", corps: 19)
                    .opacity(0.78)
                    .padding(.top, 2)
            } else {
                acte(seance.mode.auLong ? "RESUME" : "START SET \(seance.rangAffiche)")
            }
        }
        .allowsHitTesting(false)
    }

    /// L'ACTE DANS LA PILL : le glyphe ET le mot, dans une capsule à la robe
    /// de la dalle de vitesse — ce que le tap va faire.
    private func acte(_ mot: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
            Text(mot)
                .font(.inter(11.5, .semibold))
                .tracking(2.4)
                .monospacedDigit()
        }
        .foregroundStyle(Self.encreApple)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
        .padding(.top, 2)
    }

    /// LA DALLE DE VITESSE — la confirmation NOMMÉE. Elle entre par le haut,
    /// tient, et s'efface. Rien à toucher : c'est une quittance, pas un
    /// bouton, et on court.
    private func dalleVitesse(age: Double) -> some View {
        let entree = sstep(0, 0.22, age)
        let sortie = 1 - sstep(Self.dureeDalle - 0.35, Self.dureeDalle, age)
        let a = entree * sortie
        return HStack(spacing: 8) {
            Text("\(seance.vitesseChoisie)")
                .font(.inter(19, .medium))
                .monospacedDigit()
                .foregroundStyle(LinearGradient(
                    colors: [.white, .white.opacity(0.70)],
                    startPoint: .top, endPoint: .bottom))
            Text(seance.mode.estNiveau ? "NIVEAU" : "KM/H")
                .font(.inter(11, .semibold))
                .tracking(2.2)
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.10)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8))
        .opacity(a)
        .offset(y: -14 * (1 - entree))
        .allowsHitTesting(false)
    }

    /// L'ONDE DU SCEAU. Deux anneaux : un net qui s'évase vite, et un large
    /// et doux derrière lui — c'est le second qui fait la LUMIÈRE, le premier
    /// seul se lit comme un cercle dessiné.
    ///
    /// ⚠️ Mesuré au film : ma première version tenait 0,60 s mais son opacité
    /// tombait en cubique — le signal blanc ne durait que 0,25 s à l'écran,
    /// trop bref pour dire « c'est enregistré ». La TAILLE garde sa sortie
    /// franche (l'onde doit partir vite), l'OPACITÉ descend beaucoup plus
    /// doucement : ce sont deux courbes, pas une.
    private func haloSceau(age: Double) -> some View {
        let p = age / Self.dureeSceau
        let e = 1 - pow(1 - p, 2.6)          // la taille : franche
        let a = pow(1 - p, 1.5)              // la lumière : elle s'attarde
        let d = Self.coteVitesse * (0.50 + 0.34 * e)
        return ZStack {
            Circle()
                .strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.95 * a), .white.opacity(0.42 * a)],
                    startPoint: .top, endPoint: .bottom),
                              lineWidth: 2.6 - 1.5 * e)
                .frame(width: d, height: d)
            Circle()
                .strokeBorder(Color.white.opacity(0.22 * a), lineWidth: 14 * (0.4 + e))
                .frame(width: d, height: d)
                .blur(radius: 9)
        }
        .allowsHitTesting(false)
    }

    // MARK: l'en-tête — la durée de la SÉANCE

    /// « La durée globale du set en haut quelque part » — lu comme la durée de
    /// la SÉANCE (le chrono de la pastille dit déjà celle du set en cours).
    ///
    /// ⚠️ EN MINUTES, avec une horloge qui bat UNE FOIS PAR MINUTE. C'est la
    /// recette déjà écrite dans la dalle du player (« un player n'est pas un
    /// chronomètre ») : afficher un chiffre qui ne change qu'à la minute ne
    /// justifie pas de réveiller la page soixante fois par seconde. Cette
    /// `TimelineView` est une FEUILLE : elle n'invalide qu'elle-même.
    private var enTete: some View {
        TimelineView(.periodic(from: seance.naissance, by: 60)) { tl in
            let min = max(0, Int(date(tl.date).timeIntervalSince(seance.naissance) / 60))
            Text("\(min) MIN · \(seance.setsFaits) SET\(seance.setsFaits > 1 ? "S" : "")")
                .font(.inter(11, .semibold))
                .tracking(2.8)
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.38))
        }
        .allowsHitTesting(false)
    }

    private var encreVitesse: some View {
        // Pastille à la taille du chrono (01-09) = encre à sa grammaire
        // (52/12, la même que `encreChrono`) — une grande lentille sur
        // une petite encre se lisait vide.
        // Au repos, la commande règle la vitesse de RÉCUP (la mémoire a
        // basculé au stop). Le 15-09 ça se lisait « RÉCUP · km/h » en petit
        // sous le chiffre, trop discret : le saut 10 → 7 passait pour « mes
        // km/h ont changé tout seuls ». Le 16-09 (P1 ③) LA BASCULE EST
        // RACONTÉE : le chiffre ROULE (numericText, 0,5 s) et une capsule
        // « RÉCUP » s'allume au-dessus ; à la relance elle s'éteint.
        let repos = seance.etat == .repos && !seance.terminee
        let pause = seance.etat == .pause
        return VStack(spacing: 4) {
            if repos {
                Text("RÉCUP")
                    .font(.inter(10.5, .semibold))
                    .tracking(2.4)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8))
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Text(Int(seance.vitesse.rounded()).formatted())
                .font(.inter(52, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(repos || pause ? 0.72 : 0.92))
                // `value:` : les chiffres roulent dans le sens de la valeur
                // (10 → 7 descend), pas toujours vers le haut.
                .contentTransition(.numericText(value: seance.vitesse))
            Text(seance.mode.libelle)
                .font(.inter(12, .semibold))
                .tracking(3.0)
                .foregroundStyle(Color.white.opacity(0.48))
        }
        // Le chiffre ne roule QUE quand le modèle bascule (stop / relance) :
        // sous le doigt il suit le cran sec, sinon il traînerait 0,5 s
        // derrière la prise et le clic mentirait.
        // (une seule animation : la capsule change dans la même transaction
        // que le chiffre, elle suit son tempo.)
        .animation(vit.prise ? nil : .easeOut(duration: 0.5), value: seance.vitesse)
        .allowsHitTesting(false)
    }

    // MARK: les zones tactiles

    /// Les taps vivent HORS du TimelineView (des cibles fixes : rien à
    /// ré-évaluer par image) et en `highPriorityGesture` — jamais un
    /// `Button` : un drag d'ancêtre (le tirage PageCard, au J3) l'annulerait
    /// à 2 pt de tremblement (loi WorkoutPill).
    private func zonesTactiles(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Color.clear
                .frame(width: Self.coteChrono * 0.72, height: Self.coteChrono * 0.72)
                .contentShape(Circle())
                .highPriorityGesture(TapGesture().onEnded { tapChrono() })
                .position(x: w / 2, y: h * 0.315)
        }
    }

    private func tapChrono() {
        guard !seance.popupVisible, !seance.terminee else { return }
        let arret = seance.etat == .court
        seance.basculer()                  // la fête part du MODÈLE
        // LA COMMANDE SUIT LA MÉMOIRE : le modèle vient de basculer
        // (effort ⇄ récup), la position de la prise se recale dessus —
        // sinon le prochain glissement partirait de l'ancienne valeur. L'arc
        // GLISSE avec le chiffre (P1 ③), au lieu de sauter.
        vit.recaler(sur: seance.vitesse, anime: true)
        // L'HAPTIQUE DIT L'ACTE (P1 ⑤) : un arrêt = .medium (existe) ; un
        // départ = .rigid léger — ce n'est pas le même geste, ça ne doit pas
        // faire le même bruit dans la main.
        if arret {
            UIImpactFeedbackGenerator(style: seance.mode.auLong ? .soft : .medium).impactOccurred()
        } else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        }
    }



    // MARK: le pied

    /// ⚠️ Le slider descend à 34 pt du bord (il était à 78 : « pas assez en
    /// bas »). Il reste AU-DESSUS de la bande du player (110 pt), et la
    /// molette ouverte le COUVRE — on ne finit pas une session pendant qu'on
    /// règle sa vitesse : le conflit se résout tout seul.
    private func pied(w: CGFloat, h: CGFloat) -> some View {
        SliderObsidienne(label: "Finish", height: 62,
                         labelCentre: true,
                         validate: { true },
                         onConfirm: onFinish)
            .padding(.horizontal, 20)
            .frame(width: w)
            .position(x: w / 2, y: h - 34 - 31)
    }

    // MARK: constantes et outils

    /// Le HÉROS. Demi-côté = 1,80·R ⇒ R = 175 × 0,278 ≈ 97 pt (disque ~194).
    /// L'onde du sceau. 0,75 s : en dessous elle passe pour un clignotement.
    static let dureeSceau: Double = 0.75
    /// La dalle de confirmation : 1,9 s — le temps de la lire en courant,
    /// sans qu'elle s'installe.
    static let dureeDalle: Double = 1.9
    /// La hauteur de la pastille vitesse, en fraction de l'écran. UNE seule
    /// constante : le dessin, l'arc et la prise doivent parler du même repère.
    static let yVitesseF: CGFloat = 0.575
    private static let coteChrono: CGFloat = 350
    /// L'AFFICHEUR — MÊME taille que le chrono (verdict 01-09 : « la
    /// pastille km/h doit être la même taille que celle du chrono ») ;
    /// la hiérarchie ne se joue plus à la taille mais à la BRAISE
    /// (62 % au repos contre 100 %).
    private static let coteVitesse: CGFloat = coteChrono

    /// Le blanc dégradé « très Apple » de la maison.
    static let encreApple = LinearGradient(
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

// MARK: - La pastille : LA COUCHE DE FEU, et rien d'autre

/// ⚠️ Ni `Color.black`, ni `layerEffect`, ni `compositingGroup`. La V1 posait
/// un carré noir opaque sous un verre : le carré faisait la « claque noire »
/// (saut de luminance 231/255 mesuré à sa bordure) et le verre ajoutait ses
/// reflets blancs — le second agent de grisaille. Ce que Kathryn a validé sur
/// planche, c'est la couche de feu SEULE. Elle se compose sur le noir de la
/// page, sans bord, sans plaque, et coûte une passe au lieu de deux.
private struct PastilleBraise: View {
    let cote: CGFloat
    let t: Double
    let ig: Double
    let chaleur: Double
    let pulse: Double

    var body: some View {
        if TapisBanc.sansBraise {
            // LE BARREAU `-sansBraiseTapis` (skill perf : « tout nouveau
            // moteur coûteux arrive avec son barreau ») : la même place, la
            // même taille, un disque de braise PEINT (né flou, aucun shader).
            // C'est l'essai B de la campagne ABBA sur son téléphone.
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.36, blue: 0.02).opacity(0.55 * ig + 0.15),
                         Color(red: 1.0, green: 0.13, blue: 0.0).opacity(0.25 * ig),
                         .clear],
                center: .center, startRadius: 0, endRadius: cote / 2)
                .frame(width: cote, height: cote)
                .allowsHitTesting(false)
        } else {
            let c = Float(cote / 2)
            let rayon = Float(cote / (2 * TapisBraise.demiSurR))
            let sh = ShaderLibrary.braiseGlow(
                .float2(Float(cote), Float(cote)), .float2(c, c), .float(rayon),
                .float(Float(t)), .float(Float(ig)), .float(Float(pulse)),
                .float(Float(chaleur)))
            Rectangle()
                .fill(.white)
                .colorEffect(sh)
                .frame(width: cote, height: cote)
                // Le masque ne coupe plus la braise : il fond de 0,72 à 1,00 du
                // demi-côté (il fondait de 0,44 à 0,86 et jetait l'anneau).
                .mask(RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white, location: 0.72),
                        .init(color: .clear, location: 1.0)]),
                    center: .center, startRadius: 0, endRadius: cote / 2))
                .allowsHitTesting(false)
        }
    }
}

// MARK: - La dalle « SET n END » — une quittance, sans montant

/// Ce que le stop laisse à l'écran pendant 3,2 s : le set est ÉCRIT, et
/// voilà ce qu'il a été. Pas de pièce, pas de jauge (verdict 15-09 : le
/// cardio est payé par un barème de séance, au serveur, à la clôture — pas
/// à l'intervalle). La robe est le socle des dalles de la maison
/// (`RobeSocle`), pour que ça se lise comme une notification et non comme un
/// panneau.
private struct DalleSetFini: View {
    let titre: String
    let recap: String
    let pied: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titre)
                .font(.inter(11.5, .semibold))
                .tracking(2.6)
                .foregroundStyle(Color.white.opacity(0.52))
            Text(recap)
                .font(.inter(24, .medium))
                .monospacedDigit()
                .foregroundStyle(TapisScene.encreApple)
            Spacer(minLength: 0)
            Text(pied)
                .font(.inter(12, .medium))
                .foregroundStyle(Color.white.opacity(0.38))
        }
        .padding(NotifGeo.pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(RobeSocle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(titre), \(recap), \(pied)")
    }
}

// MARK: - LA VITESSE : LE BAS DE L'ÉCRAN, EN PERMANENCE
//
// « Quand on court on doit pouvoir toucher l'écran facilement EN BAS pour
// changer, surtout à grosse vitesse » (verdict 01-09). Cette phrase est la
// spécification, et elle a tué la molette qui s'ouvrait : à 17 km/h, on ne
// vise pas une pastille pour déplier un panneau, puis on cherche une prise,
// puis on referme. On touche le bas de l'écran et ça change.
//
// ⚠️⚠️ LA CAUSE DU « ÇA NE MARCHE PAS », TROUVÉE ET NOMMÉE :
//     VoileCadran(...).offset(y: haut).contentShape(Rectangle())
// `.offset` déplace les PIXELS ; il ne déplace PAS le cadre de LAYOUT. Le
// `.contentShape` posé après lui décrivait donc un rectangle À LA PLACE
// D'ORIGINE — la bande prenante était 190 pt TROP HAUTE. Arithmétique :
//     centre de la pastille  418 pt → DANS la zone (0-451)
//     les graduations        558 pt → dehors
//     les chiffres     465 → 602 pt → TOUS dehors
// Elle ne pouvait toucher que le vide au-dessus de la pastille. Et comme le
// `Color.clear` de fermeture était juste derrière, un doigt sur les chiffres
// ne tombait pas dans le vide : il FERMAIT la molette. « Elle s'ouvre pas »
// était en réalité « elle se referme à chaque toucher ».
// C'est la loi maison, écrite et non appliquée : LES PIXELS ET LE HIT-TEST
// SONT DEUX CHOSES.
//
// LA RÉPONSE V5 : plus rien à ouvrir, plus rien à fermer, plus aucun `.offset`
// sous un geste. Six mécanismes disparaissent d'un coup — le tap d'ouverture
// (ce qui ne marchait pas), le panneau, la fermeture auto, le chien de garde,
// l'entrée angulaire et son centre, l'état `moletteOuverte`. Chacun était un
// endroit où ça pouvait se coincer ; aucun ne servait l'usage réel.

/// L'état de la vitesse — un observable À PART : la position continue s'écrit
/// à chaque événement de doigt, et elle ne doit pas réveiller les shaders de
/// feu de la scène.
@MainActor @Observable
final class EtatVitesse {
    /// La position CONTINUE, en km/h fractionnaires. Elle ne sort jamais d'ici.
    var continu: Double
    /// La valeur CRANTÉE — la seule qui parte dans l'état de séance.
    var valeur: Double
    /// La valeur au moment où le doigt s'est posé.
    /// ⚠️ C'EST ÇA, LA POSITION ABSOLUE : on ne cumule RIEN. Un événement
    /// perdu, une reprise, un doigt qui s'arrête — rien ne peut faire dériver
    /// une soustraction faite depuis le point de pose. L'entrée angulaire,
    /// elle, additionnait des deltas : elle dérivait à la moindre coupure.
    var base: Double
    var prise = false
    var dernierClic: Date?
    /// Les deux horodatages de la FUMÉE.
    var toucheDebut: Date?
    var toucheFin: Date?
    /// L'arc est DÉPLIÉ. Il s'ouvre au doigt et se referme une fois la vitesse
    /// choisie (verdict 01-09) : en courant, l'écran doit revenir au calme —
    /// on ne laisse pas une règle graduée sous les yeux pendant l'effort.
    var arcOuvert = false

    /// Le départ vient du MODE (10 km/h pour le HIIT, niveau 6 pour
    /// l'escalier…) — plus jamais un 10 en dur à trois endroits.
    init(depart: Double = 10) {
        continu = depart
        valeur = depart
        base = depart
    }

    /// Recaler la commande sur une valeur que le MODÈLE vient de poser (la
    /// bascule effort ⇄ récup) — sans clic, sans halo : rien n'a été choisi.
    /// `anime` : l'arc glisse vers la valeur (0,5 s, le même tempo que le
    /// chiffre qui roule) ; la valeur crantée et la base, elles, sont posées
    /// tout de suite — un doigt qui arrive pendant le glissement part du bon
    /// endroit.
    func recaler(sur v: Double, anime: Bool = false) {
        valeur = v
        base = v
        // Le glissement ne s'anime que si l'arc est VISIBLE : caché (opacité
        // 0), il rendrait quand même ses 0,5 s de Canvas (la loi du rideau).
        if anime && arcOuvert {
            withAnimation(.easeOut(duration: 0.5)) { continu = v }
        } else {
            continu = v
        }
    }
}

/// LA PRISE — une bande FRANCHE, avec un vrai cadre de layout, construite
/// exactement comme les zones de tap qui, elles, marchent :
/// `frame` → `contentShape` → `gesture` → `position`. **Aucun `.offset`.**
private struct PriseVitesse: View {
    let etat: EtatVitesse
    var seance: SeanceTapis
    let largeur: CGFloat
    let haut: CGFloat
    let bas: CGFloat

    /// Points de glisse par cran et bornes : ils viennent du MODE (la
    /// molette de la maison qui marche en demande 62 ; le HIIT 40, parce que
    /// la course entière 0-20 doit tenir en deux largeurs d'écran quand on
    /// court, et l'escalier 53 pour que ses 15 niveaux tiennent la même
    /// course). Un seul endroit, plus deux copies qui divergent.
    private var pasGlisse: Double { seance.mode.pasGlisse }
    private var vMin: Double { seance.mode.plage.lowerBound }
    private var vMax: Double { seance.mode.plage.upperBound }

    @State private var clic = UIImpactFeedbackGenerator(style: .rigid)
    /// Le jeton du repli différé : un nouveau toucher l'invalide.
    @State private var tourFermeture = 0
    @GestureState private var doigtPose = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Color.clear
            .frame(width: largeur, height: max(bas - haut, 0))
            .contentShape(Rectangle())
            .highPriorityGesture(glisse)
            .position(x: largeur / 2, y: (haut + bas) / 2)
            // Après Finish, plus rien ne se règle : un sceau de plus dirait
            // « c'est enregistré » pour une allure qui ne s'écrit plus.
            .allowsHitTesting(!seance.terminee)
            // LE CHIEN DE GARDE (loi §4 : « un DragGesture n'appelle pas
            // toujours onEnded » — l'app qui passe en arrière-plan pendant le
            // glissement). Pas un minuteur : un doigt immobile n'est pas un
            // doigt parti. La sortie de scène COMMET le sceau — au long, le
            // segment ferme à l'allure choisie, il ne reste pas à l'ancienne.
            .onChange(of: scenePhase) { _, phase in
                if phase != .active, etat.prise { relacher() }
            }
            .onChange(of: doigtPose) { _, pose in
                // GestureState retombe aussi si iOS annule le geste sans onEnded.
                if !pose, etat.prise { relacher() }
            }
            .onDisappear {
                if etat.prise { relacher() }
                tourFermeture += 1
                etat.arcOuvert = false
                etat.toucheDebut = nil
                etat.toucheFin = nil
            }
    }

    private var glisse: some Gesture {
        // Le contact ouvre, même sans déplacement. Le même geste prend la
        // glisse ensuite : aucun second appui ni premier mouvement perdu.
        DragGesture(minimumDistance: 0)
            .updating($doigtPose) { _, pose, _ in pose = true }
            .onChanged { v in
                guard !seance.terminee else { return }
                if !etat.prise {
                    etat.prise = true
                    withAnimation(.easeOut(duration: 0.16)) { etat.arcOuvert = true }
                    tourFermeture += 1
                    etat.base = etat.valeur
                    etat.toucheDebut = Date()
                    etat.toucheFin = nil
                    // Le clic PRÉPARÉ à la saisie : la latence du premier coup
                    // tue le crantage (leçon iPod).
                    clic.prepare()
                }
                // LA POSITION ABSOLUE. Glisser vers la DROITE fait MONTER la
                // vitesse — le sens d'un curseur, et celui que les chiffres
                // suivent à l'écran.
                var p = etat.base
                    + Double(v.translation.width) / pasGlisse
                // Élastique aux bornes : la matière RÉSISTE, elle ne bute pas.
                if p < vMin { p = vMin + (p - vMin) * 0.30 }
                if p > vMax { p = vMax + (p - vMax) * 0.30 }
                etat.continu = p
                poser(p)
            }
            .onEnded { _ in relacher() }
    }

    /// ⚠️ LA VITESSE S'ÉCRIT AU CRAN, JAMAIS EN CONTINU : `seance.vitesse` est
    /// lue par la scène, qui porte les deux shaders de feu. L'écrire soixante
    /// fois par seconde les réveillerait à chaque image.
    private func poser(_ p: Double) {
        let cran = min(max(p.rounded(), vMin), vMax)
        guard cran != etat.valeur else { return }
        etat.valeur = cran
        seance.vitesse = cran
        // Le clic : FORT, avec un PLANCHER de 40 ms — on saute des CLICS,
        // jamais des crans (la position est continue : elle ne peut pas en
        // sauter un).
        let maintenant = Date()
        let assezVieux = etat.dernierClic.map {
            maintenant.timeIntervalSince($0) >= 0.04
        } ?? true
        if assezVieux {
            clic.impactOccurred(intensity: 0.85)
            etat.dernierClic = maintenant
        }
    }

    private func relacher() {
        guard etat.prise else { return }
        etat.prise = false
        etat.toucheFin = Date()
        let aChange = etat.valeur != etat.base
        if aChange, !seance.terminee {
            // Un tap ouvre seulement la molette. La confirmation et le
            // segment d'allure sont réservés à un changement de valeur.
            seance.vitesseScellee = Date()
            seance.vitesseChoisie = Int(etat.valeur.rounded())
            seance.sceller(etat.valeur)
        }
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
            etat.continu = etat.valeur
        }
        // L'arc se referme — mais pas dans le même souffle : on laisse voir
        // la valeur SE POSER sur son cran avant de replier la règle. Un
        // nouveau toucher annule le repli (on peut se raviser).
        tourFermeture += 1
        let tour = tourFermeture
        // Après un tap, laisser le temps de reprendre la molette en courant.
        // Après un réglage, garder le repli bref qui libère l'écran.
        DispatchQueue.main.asyncAfter(deadline: .now() + (aChange ? 0.55 : 2.4)) {
            guard tour == tourFermeture, !etat.prise else { return }
            withAnimation(.easeInOut(duration: 0.34)) { etat.arcOuvert = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard tour == tourFermeture, !etat.prise else { return }
            etat.toucheDebut = nil
        }
    }
}

/// L'ARC — visible EN PERMANENCE, en veilleuse, il s'allume sous le doigt.
/// En courant, on voit sa vitesse ET ses voisines sans rien toucher.
/// C'est la SEULE vue qui suive la position continue : le reste de l'écran
/// ne doit pas se redessiner par image de geste (la loi de la molette de la
/// page exos, découpée en trois pour cette raison exacte).
private struct AnneauHote: View {
    let etat: EtatVitesse
    let mode: ModeCardio
    let centre: CGPoint
    let rayon: CGFloat

    var body: some View {
        AnneauCrans(continu: etat.continu, prise: etat.prise ? 1 : 0,
                    centre: centre, rayon: rayon,
                    vMin: mode.plage.lowerBound, vMax: mode.plage.upperBound)
            .opacity(etat.arcOuvert ? 1 : 0)
            .allowsHitTesting(false)
    }
}

/// LA FUMÉE — elle ne lit que ses deux horodatages, et n'existe QUE sous le
/// doigt : sa propre loi est « tout dort au repos, l'hôte n'est même pas monté
/// sans toucher ». Un `colorEffect` permanent à 30 Hz, c'est 60 → 16 img/s.
private struct FumeeVitesse: View {
    let etat: EtatVitesse
    let centre: CGPoint
    let largeur: CGFloat
    let hauteur: CGFloat

    var body: some View {
        if let debut = etat.toucheDebut {
            TimelineView(.animation(minimumInterval: 1 / 30)) { tl in
                let now = tl.date
                let age = now.timeIntervalSince(debut)
                let relache = etat.toucheFin.map { now.timeIntervalSince($0) } ?? 0
                let bouffee = min(age / 0.10, 1.0) * exp(-max(relache, 0) / 0.45)
                let t = now.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.knobSmoke(
                        .float2(Float(largeur), Float(hauteur)),
                        .float(Float(t)),
                        .float4(Float(centre.x), Float(centre.y),
                                Float(TapisCotes.rayonDisque),
                                Float(TapisCotes.rayonAnneau)),
                        .float(Float(bouffee)),
                        .float(Float(age))))
            }
            .frame(width: largeur, height: hauteur)
            .allowsHitTesting(false)
        }
    }
}

/// Les cotes de l'organe vitesse, en un seul endroit — c'est en les laissant
/// diverger entre le dessin et le geste que la molette est morte une fois.
enum TapisCotes {
    static let rayonDisque: CGFloat = 92
    static let rayonAnneau: CGFloat = 128
    static let rayonValeurs: CGFloat = 180
    /// Le pas angulaire de l'AFFICHAGE (l'entrée, elle, est linéaire).
    static let pasCran: Double = .pi / 12       // 15°
    // (vMin / vMax vivaient ici ET dans la prise — deux copies. Depuis le
    // 15-09 les bornes viennent du MODE, un seul endroit.)
}
private struct AnneauCrans: View, Animatable {
    /// La position CONTINUE, en km/h — elle décide de tout : quels chiffres
    /// sont dessinés, et où. Un seul pilote, donc aucun risque que le décompte
    /// et le dessin divergent.
    var continu: Double
    var prise: Double
    var centre: CGPoint
    var rayon: CGFloat
    /// Les bornes du mode (0-20 km/h, niveaux 1-15).
    var vMin: Double = 0
    var vMax: Double = 20

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(continu, prise) }
        set { continu = newValue.first; prise = newValue.second }
    }

    /// L'ARC DU BAS. Le pouce y tourne naturellement, et surtout la main ne
    /// couvre pas la valeur au centre — on lit ce qu'on règle. (0 = à droite,
    /// +π/2 = vers le bas : l'axe des y descend.)
    private static let focal: Double = .pi / 2
    private static let demiArc: Double = 1.32          // ±75,6°

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, _ in
            let pas = TapisCotes.pasCran
            let courante = continu.rounded()
            // Les voisines : ±4 km/h autour de la valeur. Au-delà, l'arc les
            // éteint de toute façon — on ne dessine pas ce qui ne se voit pas.
            var k = -4.0
            while k <= 4 {
                let v = courante + k
                if v < vMin || v > vMax { k += 1; continue }
                // L'angle : la valeur courante tombe sur le focal, et `cran`
                // fait glisser tout l'anneau entre deux crans.
                let theta = Self.focal + (v - continu) * pas
                let ecart = abs(atan2(sin(theta - Self.focal), cos(theta - Self.focal)))
                if ecart > Self.demiArc { k += 1; continue }
                // ⚠️ LE FONDU DOIT ATTEINDRE ZÉRO PILE AU BORD DE L'ARC.
                // Avec un coefficient arbitraire (1,02), il valait encore
                // 0,10 à la coupure : chaque chiffre APPARAISSAIT et
                // DISPARAISSAIT d'un coup à 0,28 d'opacité. C'était ça, le
                // « pas fluide » — pas la cadence, un pop de bord.
                let fade = pow(max(0, cos(ecart * (.pi / 2) / Self.demiArc)), 1.35)
                if fade > 0.02 {
                    trait(ctx, theta: theta, fade: fade * (0.55 + 0.45 * prise))
                    // La valeur courante n'est PAS sur l'arc : elle est en
                    // grand au centre. Deux fois le même chiffre, c'est une
                    // hésitation.
                    if abs(v - courante) > 0.01, !TapisBanc.sansChiffres {
                        chiffre(ctx, v: Int(v), theta: theta, fade: fade)
                    }
                }
                k += 1
            }
            index(ctx)
        }
        .allowsHitTesting(false)
    }

    /// Une graduation. GROSSE : 22 pt de haut, 3 pt de large — la maquette
    /// disait « pas assez grosse », et 1,2 pt de trait ne se voit pas en
    /// courant.
    private func trait(_ ctx: GraphicsContext, theta: Double, fade: Double) {
        let c = CGPoint(x: centre.x + rayon * cos(theta),
                        y: centre.y + rayon * sin(theta))
        var p = Path()
        // Plus FIN et plus LONG : un trait de 3 pt fait barre de peinture ;
        // à 1,8 pt sur 26, il fait aiguille.
        p.addRoundedRect(in: CGRect(x: -0.9, y: -13, width: 1.8, height: 26),
                         cornerSize: CGSize(width: 0.9, height: 0.9))
        var sous = ctx
        sous.translateBy(x: c.x, y: c.y)
        sous.rotate(by: .radians(theta + .pi / 2))
        // ⚠️ UN DÉGRADÉ, PAS UN APLAT. Un trait blanc uni se lit comme une
        // barre de peinture ; le même trait dégradé du dedans vers le dehors
        // a une LUMIÈRE — c'est ce qui fait « très beau » et rien d'autre.
        sous.fill(p, with: .linearGradient(
            Gradient(colors: [.white.opacity(fade),
                              .white.opacity(fade * 0.18)]),
            startPoint: CGPoint(x: 0, y: -13),
            endPoint: CGPoint(x: 0, y: 13)))
    }

    /// Les valeurs voisines, en blanc dégradé, dessinées DANS le même Canvas.
    /// Elles s'éteignent en s'éloignant du bas : la maison écrit cette rampe
    /// `max(0,16 ; 0,85 − 0,30·n)` sur son éventail de molette.
    private func chiffre(_ ctx: GraphicsContext, v: Int, theta: Double,
                         fade: Double) {
        let r = TapisCotes.rayonValeurs
        let c = CGPoint(x: centre.x + r * cos(theta),
                        y: centre.y + r * sin(theta))
        // ⚠️ FIN, PAS GRAS (verdict : « plus fin les chiffres, plus de
        // dégradé, plus de côté type Apple »). Un `.semibold` sur un cadran
        // fait tableau de bord de voiture ; c'est le `.light` à grand corps,
        // serré, qui fait le chiffre Apple — la même famille que l'heure de
        // l'écran verrouillé. Et le dégradé descend PLUS BAS (0,55) : sur du
        // fin, il a la place de se voir sans effacer la lettre.
        let opac = max(0.14, min(0.96, 0.16 + 0.84 * fade))
        let t = Text("\(v)")
            .font(.inter(30, .light))
            .monospacedDigit()
            .tracking(-0.5)
            .foregroundStyle(LinearGradient(
                colors: [.white.opacity(opac), .white.opacity(opac * 0.55)],
                startPoint: .top, endPoint: .bottom))
        ctx.draw(ctx.resolve(t), at: c, anchor: .center)
    }

    /// L'INDEX : le repère fixe, en bas, qui dit « c'est ça, ta valeur ». Il
    /// est dessiné ICI et pas dans le verre — le verre ne doit jamais se
    /// reconstruire par image.
    private func index(_ ctx: GraphicsContext) {
        let c = CGPoint(x: centre.x, y: centre.y + rayon - 30)
        var p = Path()
        p.addEllipse(in: CGRect(x: c.x - 2.6, y: c.y - 2.6, width: 5.2, height: 5.2))
        ctx.fill(p, with: .linearGradient(
            Gradient(colors: [.white.opacity(0.55 + 0.45 * prise),
                              .white.opacity((0.55 + 0.45 * prise) * 0.55)]),
            startPoint: CGPoint(x: c.x, y: c.y - 2.6),
            endPoint: CGPoint(x: c.x, y: c.y + 2.6)))
    }
}
