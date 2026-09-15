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

    static let hiit = ModeCardio(plage: 0...20, depart: 10, departRecup: 7,
                                 unite: "km/h", libelle: "km/h", pasGlisse: 40,
                                 estNiveau: false)
    static let tapisModere = ModeCardio(plage: 0...20, depart: 7, departRecup: 5,
                                        unite: "km/h", libelle: "km/h", pasGlisse: 40,
                                        estNiveau: false)
    static let escalier = ModeCardio(plage: 1...15, depart: 6, departRecup: 1,
                                     unite: "", libelle: "NIVEAU", pasGlisse: 53,
                                     estNiveau: true)

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
    enum Etat { case court, repos }

    /// Le mode : ce que la commande règle, et ce qu'un segment devient.
    let mode: ModeCardio
    /// L'instant où les pastilles ARRIVENT (l'ancre de toute la scène).
    let naissance: Date
    private(set) var etat: Etat = .court
    /// Le rang du set en cours (1-based).
    private(set) var setIndex = 1
    /// Les sets terminés — le pilote du palier de braise ET du crescendo.
    private(set) var setsFaits = 0
    /// L'ancre du chrono du set en cours.
    private(set) var setDebut: Date?
    /// L'ancre du repos (l'entre-sets montre le temps écoulé, pas un compte).
    private(set) var reposDebut: Date?
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
    /// Le bilan du dernier set fini — ce que la dalle « SET n END » raconte.
    private(set) var dernierBilan: BilanSet?
    /// La dalle est à l'écran (elle se retire seule).
    var dalleVisible = false
    /// La pop-up flammes est à l'écran (elle attend un tap).
    var popupVisible = false

    /// CE QUE LA SCÈNE RAPPORTE (15-09) : l'intervalle fini au stop, la récup
    /// finie à la relance. La scène ne connaît pas SwiftData — c'est la fiche
    /// qui écrit les `CardioPhase` (faites) dans le bloc de son passage.
    var onSetFini: ((BilanSet) -> Void)?
    var onRecupFinie: ((_ secondes: Int, _ vitesse: Double) -> Void)?

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

    /// La durée de l'arrivée : le set 1 démarre quand les pastilles se posent.
    static let arrivee: Double = 0.85

    init(mode: ModeCardio = .hiit, naissance: Date = .now, figee: Bool = false,
         setsFaits: Int = 0) {
        self.mode = mode
        self.naissance = figee ? naissance.addingTimeInterval(-30) : naissance
        self.setsFaits = setsFaits
        self.setIndex = setsFaits + 1
        self.setDebut = self.naissance.addingTimeInterval(Self.arrivee)
        self.vitesse = mode.depart
        self.vitesseEffort = mode.depart
        self.vitesseRecup = mode.departRecup
        self.vitesseChoisie = Int(mode.depart.rounded())
    }

    /// Le tap sur la pastille chrono pendant l'effort : le set est FAIT.
    /// L'intervalle est RAPPORTÉ (la fiche l'écrit), la commande bascule sur
    /// la récup, la fête part.
    func stopper(_ now: Date = .now) {
        guard etat == .court else { return }
        let secondes = setDebut.map { max(0, Int(now.timeIntervalSince($0))) } ?? 0
        let bilan = BilanSet(rang: setIndex, secondes: secondes, vitesse: vitesse, mode: mode)
        dernierBilan = bilan
        etat = .repos
        setsFaits += 1
        setDebut = nil
        reposDebut = now
        // La bascule effort → récup : on garde ce qu'on courait, on propose
        // ce qu'on récupérait la dernière fois.
        vitesseEffort = vitesse
        vitesse = vitesseRecup
        vitesseChoisie = Int(vitesse.rounded())
        onSetFini?(bilan)
        lancerLaFete()
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
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            dalleVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.30)) { self.popupVisible = true }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.20) { [weak self] in
            guard let self else { return }
            withAnimation(.easeIn(duration: 0.28)) { self.dalleVisible = false }
        }
    }

    /// Le tap sur la pastille chrono au repos : la récup est FAITE (elle est
    /// rapportée, à la vitesse qu'on tenait), le set suivant part, la
    /// commande revient à la vitesse d'effort.
    func relancer(_ now: Date = .now) {
        guard etat == .repos else { return }
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
        if secondes > 0 { onRecupFinie?(secondes, vRecup) }
    }

    /// Le palier de braise : `k = min(setsFaits, 6)` — 7 valeurs, pas plus
    /// (au-delà l'écran serait blanc de rouge).
    var palier: Int { min(setsFaits, TapisBraise.paliers.count - 1) }
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
                             haut: h * 0.50, bas: h - 110)
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
        if let b = seance.dernierBilan, seance.dalleVisible {
            VStack {
                // ⚠️ SANS MONTANT (verdict 15-09 : « pas 20 par intervalle,
                // la séance est jugée à l'intensité » — le serveur paie à la
                // clôture). La dalle est une QUITTANCE : ce set est écrit,
                // voilà ce qu'il a été.
                DalleSetFini(rang: b.rang, recap: b.recap)
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
        let p = TapisBraise.paliers[seance.palier]
        let q = TapisBraise.repos(seance.palier)
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
    /// mets juste le temps ») : plus de « SET n », plus de « REST » — le
    /// chrono du set pendant l'effort, le chrono de la récup pendant la
    /// récup (un ton plus bas), et le glyphe qui dit l'état : ⏹ petit et
    /// fixe sous l'effort, ▶ au repos. La braise dit le reste.
    private func encreChrono(now: Date) -> some View {
        let court = seance.etat == .court
        let secondes: Int = {
            if court, let d0 = seance.setDebut { return max(0, Int(now.timeIntervalSince(d0))) }
            if let r0 = seance.reposDebut { return max(0, Int(now.timeIntervalSince(r0))) }
            return 0
        }()
        return VStack(spacing: court ? 4 : 8) {
            Text(chrono(secondes))
                .font(.inter(52, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(court ? 0.94 : 0.66))
            if court {
                glyphe("stop.fill", corps: 19)
                    .opacity(0.78)
                    .padding(.top, 2)
            } else {
                glyphe("play.fill", corps: 34)
            }
        }
        .allowsHitTesting(false)
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
        // Au repos, l'encre dit RÉCUP : la commande règle la vitesse de
        // récupération (la mémoire a basculé au stop), et ça doit se lire.
        let repos = seance.etat == .repos
        let libelle = repos
            ? (seance.mode.estNiveau ? "RÉCUP · NIVEAU" : "RÉCUP · km/h")
            : seance.mode.libelle
        return VStack(spacing: 4) {
            Text(Int(seance.vitesse.rounded()).formatted())
                .font(.inter(52, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(repos ? 0.72 : 0.92))
            Text(libelle)
                .font(.inter(12, .semibold))
                .tracking(3.0)
                .foregroundStyle(Color.white.opacity(0.48))
        }
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
        guard !seance.popupVisible else { return }
        switch seance.etat {
        case .court: seance.stopper()      // la fête part du MODÈLE
        case .repos: seance.relancer()
        }
        // LA COMMANDE SUIT LA MÉMOIRE : le modèle vient de basculer
        // (effort ⇄ récup), la position de la prise se recale dessus —
        // sinon le prochain glissement partirait de l'ancienne valeur.
        vit.recaler(sur: seance.vitesse)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    let rang: Int
    let recap: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SET \(rang) END")
                .font(.inter(11.5, .semibold))
                .tracking(2.6)
                .foregroundStyle(Color.white.opacity(0.52))
            Text(recap)
                .font(.inter(24, .medium))
                .monospacedDigit()
                .foregroundStyle(TapisScene.encreApple)
            Spacer(minLength: 0)
            Text("Saved")
                .font(.inter(12, .medium))
                .foregroundStyle(Color.white.opacity(0.38))
        }
        .padding(NotifGeo.pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(RobeSocle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(rang) terminé, \(recap)")
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
    /// La valeur au moment où le doigt s'est posé, et la course morte du seuil.
    /// ⚠️ C'EST ÇA, LA POSITION ABSOLUE : on ne cumule RIEN. Un événement
    /// perdu, une reprise, un doigt qui s'arrête — rien ne peut faire dériver
    /// une soustraction faite depuis le point de pose. L'entrée angulaire,
    /// elle, additionnait des deltas : elle dérivait à la moindre coupure.
    var base: Double
    var morte: CGFloat = 0
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
    func recaler(sur v: Double) {
        continu = v
        valeur = v
        base = v
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

    var body: some View {
        Color.clear
            .frame(width: largeur, height: max(bas - haut, 0))
            .contentShape(Rectangle())
            .highPriorityGesture(glisse)
            .position(x: largeur / 2, y: (haut + bas) / 2)
    }

    private var glisse: some Gesture {
        // 2 pt et non 8 : la course morte se RETRANCHE (`morte`), elle ne se
        // subit pas — sinon les deux premiers points du geste sont mangés.
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                if !etat.prise {
                    etat.prise = true
                    withAnimation(.easeOut(duration: 0.22)) { etat.arcOuvert = true }
                    tourFermeture += 1
                    etat.base = etat.valeur
                    etat.morte = v.translation.width
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
                    + Double(v.translation.width - etat.morte) / pasGlisse
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
        etat.prise = false
        etat.toucheFin = Date()
        // Le halo blanc + la dalle disent « c'est enregistré ».
        seance.vitesseScellee = Date()
        seance.vitesseChoisie = Int(etat.valeur.rounded())
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
            etat.continu = etat.valeur
        }
        // L'arc se referme — mais pas dans le même souffle : on laisse voir
        // la valeur SE POSER sur son cran avant de replier la règle. Un
        // nouveau toucher annule le repli (on peut se raviser).
        tourFermeture += 1
        let tour = tourFermeture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            guard tour == tourFermeture, !etat.prise else { return }
            withAnimation(.easeInOut(duration: 0.34)) { etat.arcOuvert = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !etat.prise { etat.toucheDebut = nil }
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
