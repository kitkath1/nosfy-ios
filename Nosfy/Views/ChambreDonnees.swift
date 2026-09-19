import Foundation

// ════════════════════════════════════════════════════════════════════════
// LES DONNÉES DES CHAMBRES LONGUES — calculées UNE fois, jamais dans un body
//
// Une seule passe sur les séances produit les DEUX fenêtres (semaine, mois)
// des quatre chambres. La valeur par défaut de chaque struct EST l'état
// vide : une chambre qui reçoit `ChambreFenetre()` dessine son design
// entier, en gris — jamais une phrase « rien à afficher » (verdict du 13-09 :
// « quand tout est à zéro on doit avoir le même design avec les mêmes
// éléments graphiques, en mode gris »).
//
// Les lois portées ici sont celles du serveur (`20260905090000_widgets_
// lecture.sql`), pour que la home et le serveur comptent PAREIL :
//  ① la fenêtre précédente est bornée AU MÊME TEMPS ÉCOULÉ (correctif 25-08) ;
//  ② un EFFORT est un passage au-dessus de `SemaineStats.seuilEffort` ;
//  ③ aucune factorisation de cycle — on compte des segments, jamais « × N » ;
//  ④ rien n'est stocké : la série de semaines se dérive comme un solde.
// ════════════════════════════════════════════════════════════════════════

// MARK: - Les briques

/// Un jour de la grille (semaine : 7 · mois : 35).
struct ChambreJour: Identifiable, Equatable {
    var id: Date { date }
    var date: Date
    var numero: Int
    /// Hors de la fenêtre de calcul (les premiers jours de la grille du mois).
    var horsFenetre = false
    var aujourdhui = false
    var futur = false
    var seances = 0
    var sticker: WoopSticker?
    var sticker2: WoopSticker?
    /// 0 = rien · 1 tiède · 2 chaud · 3 foyer — le halo sous le sticker.
    var intensite = 0
    /// Le pic HIIT de ce jour, s'il y en a un — la case de la chambre HIIT.
    var picHiit: Double?
    var fait: Bool { seances > 0 }
}

struct ChambreExo: Identifiable, Equatable {
    var id: String
    var nom: String
    var sticker: WoopSticker
    var volume: Double
    var reps: Int
    var charge: Double
    /// Part du total de la fenêtre, 0…1.
    var part: Double
}

struct ChambreCategorie: Identifiable, Equatable {
    var id: String { categorie.rawValue }
    var categorie: ExerciseCategory
    var sticker: WoopSticker
    var volume: Double
    var part: Double
}

struct ChambreSeanceHiit: Identifiable, Equatable {
    var id: Date { date }
    var date: Date
    var jour: String          // « Mardi 01.09 »
    var pic: Double
    var segments: [SegmentHiit]
    var efforts: Int { segments.filter(\.effort).count }
    var duree: Int { segments.reduce(0) { $0 + $1.secondes } }
}

struct ChambreMarche: Identifiable, Equatable {
    var id: Date { date }
    var date: Date
    var charge: Double
}

struct ChambreAutrePic: Identifiable, Equatable {
    var id: String
    var nom: String
    var sticker: WoopSticker
    var charge: Double
    var reps: Int
    /// nil = premier (pas de précédent) · 0 = égalé · > 0 = record battu.
    var delta: Double?
}

struct ChambreDefi: Equatable {
    /// Le meilleur mois de l'historique (hors mois courant), à battre.
    var cible: Int
    var moisCible: String     // « août »
    var faitesMois: Int
    var reste: Int { max(cible + 1 - faitesMois, 0) }
    /// Le record est tombé : le mois courant a dépassé le meilleur mois.
    var battu: Bool { faitesMois > cible }
    /// « 26 septembre », si le rythme du mois permet une projection.
    var projection: String?
    /// Les séances du mois courant, dans l'ordre — un cran fait = une date.
    var dates: [Date] = []
    /// Séances par jour depuis le 1er du mois — projette un cran à venir.
    var rythme: Double?
}

// MARK: - Une fenêtre

struct ChambreFenetre {
    var debut = Date.distantPast
    var fin = Date.distantPast
    /// « lun 31.08 → dim 06.09 »
    var libelle = ""
    /// Aucune séance dans la fenêtre : le design se dessine en gris.
    var vide = true

    // ── Régularité
    var faites = 0
    var precedent = 0
    var suite = 0
    var recordSuite = 0
    var jours: [ChambreJour] = []
    var defi: ChambreDefi?

    // ── Volume
    var volume = 0.0
    var volumePrec = 0.0
    /// Le cumul point par point (7 jours, ou 5 semaines en Mois).
    var cumul: [Double] = []
    var fantome: [Double] = []
    var axe: [String] = []
    var parSeance = 0.0
    var recordSemaine = 0.0
    var exos: [ChambreExo] = []
    var categories: [ChambreCategorie] = []

    // ── HIIT
    var seancesHiit: [ChambreSeanceHiit] = []
    var picMax = 0.0
    var picPrec = 0.0
    var efforts = 0
    var effortsPrec = 0
    var tempsPics = 0
    var tempsPicsPrec = 0
    var recupMoy = 0
    var recupMoyPrec = 0
    var plusLongTrou = 0
    var plusLongTrouPrec = 0
    /// Le pic des quatre dernières semaines, S-3 → cette semaine.
    var pics4: [Double] = [0, 0, 0, 0]

    // ── Peak
    var peak: PeakEffortInfo?
    var ascension: [ChambreMarche] = []
    var e1rm = 0.0
    var depuisRecord: Int?
    var autres: [ChambreAutrePic] = []
    var recordsBattus = 0

    var delta: Int { faites - precedent }
    var volumeDeltaPct: Int? {
        volumePrec > 0 ? Int(((volume - volumePrec) / volumePrec * 100).rounded()) : nil
    }

    /// LA LOI DU VIDE, ENTIÈRE (14-09, Kathryn : « en mode empty il y a encore des
    /// valeurs, genre dans HIIT j'ai déjà le nombre du défi »). Une fenêtre sans
    /// séance ne montre RIEN qui vienne d'ailleurs : ni le défi du mois, ni les
    /// quatre semaines du record, ni le record de la semaine, ni la fenêtre
    /// précédente, ni l'ascension — tout à zéro, tout en gris. L'historique
    /// revient avec la première séance de la fenêtre.
    func sansRien() -> ChambreFenetre {
        guard vide else { return self }
        var f = self
        f.precedent = 0; f.suite = 0; f.recordSuite = 0; f.defi = nil
        f.volumePrec = 0; f.fantome = []; f.recordSemaine = 0
        f.picPrec = 0; f.effortsPrec = 0; f.tempsPicsPrec = 0
        f.recupMoyPrec = 0; f.plusLongTrouPrec = 0; f.pics4 = [0, 0, 0, 0]
        f.peak = nil; f.ascension = []; f.e1rm = 0; f.depuisRecord = nil
        f.autres = []; f.recordsBattus = 0
        return f
    }
}

// MARK: - Les données

struct ChambreDonnees {
    var objectif = 5
    var semaine = ChambreFenetre()
    var mois = ChambreFenetre()

    /// Le brut : trois fenêtres nues — le point de départ du calcul, rien d'autre.
    private init(brut: Void) {}

    /// L'ÉTAT VIDE N'EST PAS UNE STRUCT À ZÉRO : c'est le calcul sur aucune
    /// séance. Les cases du calendrier ont leurs dates, le libellé de la
    /// semaine existe, le défi n'existe pas, tout le reste est à zéro. La
    /// loi du vide commence ici — la home ne publie rien tant que la base
    /// est vide (`HomeNuit` : `if !workoutsBruts.isEmpty`), et une chambre
    /// qui s'ouvre quand même doit dessiner la même chose.
    init() { self = Self.calcule([], prevues: 5) }

    func fenetre(_ f: ChambreEtat.Fenetre) -> ChambreFenetre {
        f == .semaine ? semaine : mois
    }

    // ── LE CALCUL ──────────────────────────────────────────────────────
    static func calcule(_ workouts: [Workout], prevues: Int,
                        maintenant: Date = .now) -> ChambreDonnees {
        var cal = Calendar.current
        cal.firstWeekday = 2
        let finies = workouts.filter { !$0.isActive }
            .sorted { $0.startedAt < $1.startedAt }
        var d = ChambreDonnees(brut: ())
        d.objectif = prevues

        // ① les bornes — la fenêtre précédente au MÊME temps écoulé
        guard let sem = cal.dateInterval(of: .weekOfYear, for: maintenant)
        else { return d }
        let ecouleSem = maintenant.timeIntervalSince(sem.start)
        d.semaine = fenetre(finies, cal: cal, maintenant: maintenant,
                            debut: sem.start, fin: maintenant,
                            debutPrec: sem.start.addingTimeInterval(-7 * 86400),
                            finPrec: sem.start.addingTimeInterval(-7 * 86400 + ecouleSem),
                            mois: false, prevues: prevues)
        let debutMois = maintenant.addingTimeInterval(-30 * 86400)
        d.mois = fenetre(finies, cal: cal, maintenant: maintenant,
                         debut: debutMois, fin: maintenant,
                         debutPrec: debutMois.addingTimeInterval(-30 * 86400),
                         finPrec: debutMois,
                         mois: true, prevues: prevues)
        return d
    }

    // swiftlint:disable:next function_parameter_count
    private static func fenetre(_ finies: [Workout], cal: Calendar,
                                maintenant: Date,
                                debut: Date, fin: Date,
                                debutPrec: Date, finPrec: Date,
                                mois: Bool, prevues: Int) -> ChambreFenetre {
        var f = ChambreFenetre()
        f.debut = debut; f.fin = fin
        let cette = finies.filter { $0.startedAt >= debut && $0.startedAt < fin }
        let prec = finies.filter { $0.startedAt >= debutPrec && $0.startedAt < finPrec }
        let avant = finies.filter { $0.startedAt < debut }
        f.vide = cette.isEmpty
        f.libelle = libelle(debut: debut, fin: fin, cal: cal, mois: mois)

        regularite(&f, cette: cette, prec: prec, finies: finies,
                   cal: cal, maintenant: maintenant, debut: debut,
                   mois: mois, prevues: prevues)
        volume(&f, cette: cette, prec: prec, finies: finies,
               cal: cal, debut: debut, fin: fin, mois: mois)
        hiit(&f, cette: cette, prec: prec, finies: finies,
             cal: cal, maintenant: maintenant)
        peak(&f, cette: cette, avant: avant, finies: finies,
             cal: cal, maintenant: maintenant)
        return f
    }

    // MARK: Régularité

    private static func regularite(_ f: inout ChambreFenetre,
                                   cette: [Workout], prec: [Workout],
                                   finies: [Workout], cal: Calendar,
                                   maintenant: Date, debut: Date,
                                   mois: Bool, prevues: Int) {
        f.faites = cette.count
        f.precedent = prec.count

        // ④ la série de semaines, dérivée — jamais un compteur
        var sem = cal.dateInterval(of: .weekOfYear, for: maintenant)!.start
        let aUneSeance: (Date) -> Bool = { s in
            finies.contains { w in
                cal.dateInterval(of: .weekOfYear, for: w.startedAt)?.start == s
            }
        }
        if !aUneSeance(sem) { sem = sem.addingTimeInterval(-7 * 86400) }
        var suite = 0
        while suite < 520, aUneSeance(sem) {
            suite += 1
            sem = sem.addingTimeInterval(-7 * 86400)
        }
        f.suite = suite
        // le record : la plus longue île de semaines consécutives
        let semaines = Set(finies.compactMap {
            cal.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start
        }).sorted()
        var record = 0, courant = 0
        var precS: Date?
        for s in semaines {
            if let p = precS, abs(s.timeIntervalSince(p) - 7 * 86400) < 3600 {
                courant += 1
            } else { courant = 1 }
            record = max(record, courant)
            precS = s
        }
        f.recordSuite = record

        // la grille des jours
        let grilleDebut: Date = mois
            ? cal.dateInterval(of: .weekOfYear, for: maintenant)!.start
                .addingTimeInterval(-4 * 7 * 86400)
            : cal.dateInterval(of: .weekOfYear, for: maintenant)!.start
        let nJours = mois ? 35 : 7
        f.jours = (0..<nJours).map { i in
            let jour = cal.date(byAdding: .day, value: i, to: grilleDebut)!
            let seances = finies.filter { cal.isDate($0.startedAt, inSameDayAs: jour) }
            var j = ChambreJour(date: jour, numero: cal.component(.day, from: jour))
            j.horsFenetre = jour < cal.startOfDay(for: debut)
            j.aujourdhui = cal.isDateInToday(jour)
            j.futur = jour > maintenant
            j.seances = seances.count
            if let s0 = seances.first { j.sticker = WoopSticker.pour(s0) }
            if seances.count > 1 { j.sticker2 = WoopSticker.pour(seances[1]) }
            let effort = seances.reduce(0.0) { $0 + $1.totalVolume + 20 * Double($1.cardioMinutes) }
            j.intensite = seances.isEmpty ? 0 : (effort >= 4000 ? 3 : (effort >= 1500 ? 2 : 1))
            let pic = seances.flatMap { picHiit($0) }.max()
            j.picHiit = pic
            return j
        }

        // le défi : battre le meilleur mois calendaire de l'historique
        let moisCourant = cal.dateInterval(of: .month, for: maintenant)!
        let parMois = Dictionary(grouping: finies.filter { $0.startedAt < moisCourant.start }) {
            cal.dateInterval(of: .month, for: $0.startedAt)!.start
        }
        if let (meilleurDebut, seancesMeilleur) = parMois.max(by: { $0.value.count < $1.value.count }) {
            let duMois = finies.filter { $0.startedAt >= moisCourant.start }
            let faitesMois = duMois.count
            var defi = ChambreDefi(cible: seancesMeilleur.count,
                                   moisCible: nomMois(meilleurDebut),
                                   faitesMois: faitesMois, projection: nil)
            defi.dates = duMois.map(\.startedAt)
            let ecoules = max(cal.dateComponents([.day], from: moisCourant.start, to: maintenant).day ?? 1, 1)
            if faitesMois > 0 {
                let rythme = Double(faitesMois) / Double(ecoules)
                defi.rythme = rythme
                if defi.reste > 0 {
                    let joursRestants = Double(defi.reste) / rythme
                    let quand = cal.date(byAdding: .day, value: Int(joursRestants.rounded(.up)), to: maintenant)!
                    defi.projection = ChambreFmt.dateLongue(quand)
                }
            }
            f.defi = defi
        }
    }

    // MARK: Volume

    private static func volume(_ f: inout ChambreFenetre,
                               cette: [Workout], prec: [Workout],
                               finies: [Workout], cal: Calendar,
                               debut: Date, fin: Date, mois: Bool) {
        f.volume = cette.reduce(0) { $0 + $1.totalVolume }
        f.volumePrec = prec.reduce(0) { $0 + $1.totalVolume }
        f.parSeance = cette.isEmpty ? 0 : f.volume / Double(cette.count)

        // le cumul : 7 jours, ou 5 points (S-4 → auj.)
        if mois {
            let pas = 6.0 * 86400
            var points: [Double] = []
            var pointsPrec: [Double] = []
            var acc = 0.0, accP = 0.0
            for k in 0..<5 {
                let a = debut.addingTimeInterval(Double(k) * pas)
                let b = k == 4 ? fin : debut.addingTimeInterval(Double(k + 1) * pas)
                acc += cette.filter { $0.startedAt >= a && $0.startedAt < b }
                    .reduce(0) { $0 + $1.totalVolume }
                let ap = a.addingTimeInterval(-30 * 86400), bp = b.addingTimeInterval(-30 * 86400)
                accP += prec.filter { $0.startedAt >= ap && $0.startedAt < bp }
                    .reduce(0) { $0 + $1.totalVolume }
                points.append(acc); pointsPrec.append(accP)
            }
            f.cumul = points; f.fantome = pointsPrec
            f.axe = ["S-4", "S-3", "S-2", "S-1", "Auj."]
        } else {
            var acc = 0.0, accP = 0.0
            var points: [Double] = [], pointsPrec: [Double] = []
            for i in 0..<7 {
                let jour = cal.date(byAdding: .day, value: i, to: debut)!
                acc += cette.filter { cal.isDate($0.startedAt, inSameDayAs: jour) }
                    .reduce(0) { $0 + $1.totalVolume }
                let jp = jour.addingTimeInterval(-7 * 86400)
                accP += prec.filter { cal.isDate($0.startedAt, inSameDayAs: jp) }
                    .reduce(0) { $0 + $1.totalVolume }
                points.append(acc); pointsPrec.append(accP)
            }
            f.cumul = points; f.fantome = pointsPrec
            f.axe = ["L", "M", "M", "J", "V", "S", "D"]
        }

        // le record de semaine, sur tout l'historique
        let parSemaine = Dictionary(grouping: finies) {
            cal.dateInterval(of: .weekOfYear, for: $0.startedAt)!.start
        }
        f.recordSemaine = parSemaine.values
            .map { $0.reduce(0) { $0 + $1.totalVolume } }.max() ?? 0

        // les exercices qui portent le total
        var parExo: [String: (nom: String, cat: ExerciseCategory?, vol: Double, reps: Int, charge: Double)] = [:]
        for w in cette {
            for ex in w.orderedExercises where ex.volume > 0 {
                var e = parExo[ex.exerciseID] ?? (ex.name, ex.exercise?.category, 0, 0, 0)
                e.vol += ex.volume
                e.reps += ex.orderedSets.filter(\.isDone).reduce(0) { $0 + $1.reps }
                e.charge = max(e.charge, ex.maxWeight)
                parExo[ex.exerciseID] = e
            }
        }
        let total = max(f.volume, 1)
        f.exos = parExo.map { id, e in
            ChambreExo(id: id, nom: e.nom,
                       sticker: WoopSticker.pour(categorie: e.cat),
                       volume: e.vol, reps: e.reps, charge: e.charge,
                       part: e.vol / total)
        }
        .sorted { $0.volume > $1.volume }
        .prefix(3).map { $0 }

        // la répartition par catégorie (le cardio pèse 0 kg — par construction).
        // LES QUATRE CATÉGORIES SONT TOUJOURS LÀ : une catégorie non travaillée
        // se lit « Jambes · 0 kg », pas « — · 0 kg » (cohérence, 13-09).
        var parCat: [ExerciseCategory: Double] = [:]
        for c in ExerciseCategory.allCases where c != .cardio { parCat[c] = 0 }
        for w in cette {
            for ex in w.orderedExercises where ex.volume > 0 {
                if let c = ex.exercise?.category { parCat[c, default: 0] += ex.volume }
            }
        }
        f.categories = parCat.map { c, v in
            ChambreCategorie(categorie: c, sticker: WoopSticker.pour(categorie: c),
                             volume: v, part: v / total)
        }
        .sorted { $0.volume > $1.volume }
    }

    // MARK: HIIT

    /// Le pic HIIT d'une séance, hors escalier (son `speed` est un niveau).
    private static func picHiit(_ w: Workout) -> Double? {
        w.orderedExercises
            .filter { $0.exerciseID != "escalier" && $0.exercise?.tracking != .setsRepsWeight }
            .flatMap { $0.orderedPhases.map(\.speed) }
            .max()
    }

    private static func hiit(_ f: inout ChambreFenetre,
                             cette: [Workout], prec: [Workout],
                             finies: [Workout], cal: Calendar,
                             maintenant: Date) {
        let seuil = SemaineStats.seuilEffort
        let fmt = DateFormatter(); fmt.locale = Locale(identifier: "fr_FR")
        fmt.dateFormat = "EEEE dd.MM"

        func seances(_ ws: [Workout]) -> [ChambreSeanceHiit] {
            ws.compactMap { w in
                let phases = w.orderedExercises
                    .filter { $0.exerciseID != "escalier" && $0.exercise?.tracking != .setsRepsWeight }
                    .flatMap(\.orderedPhases)
                guard phases.contains(where: { $0.speed >= seuil }) else { return nil }
                let segs = phases.map {
                    SegmentHiit(secondes: $0.seconds, vitesse: $0.speed, effort: $0.speed >= seuil)
                }
                return ChambreSeanceHiit(date: w.startedAt,
                                         jour: fmt.string(from: w.startedAt).capitalized,
                                         pic: phases.map(\.speed).max() ?? 0,
                                         segments: segs)
            }
        }
        let sc = seances(cette), sp = seances(prec)
        f.seancesHiit = sc
        f.picMax = sc.map(\.pic).max() ?? 0
        f.picPrec = sp.map(\.pic).max() ?? 0
        f.efforts = sc.reduce(0) { $0 + $1.efforts }
        f.effortsPrec = sp.reduce(0) { $0 + $1.efforts }
        f.tempsPics = sc.flatMap(\.segments).filter(\.effort).reduce(0) { $0 + $1.secondes }
        f.tempsPicsPrec = sp.flatMap(\.segments).filter(\.effort).reduce(0) { $0 + $1.secondes }
        func recupMoy(_ s: [ChambreSeanceHiit]) -> Int {
            let r = s.flatMap(\.segments).filter { !$0.effort }
            return r.isEmpty ? 0 : r.reduce(0) { $0 + $1.secondes } / r.count
        }
        f.recupMoy = recupMoy(sc); f.recupMoyPrec = recupMoy(sp)
        func trou(_ ws: [Workout]) -> Int {
            let dates = ws.map(\.startedAt).sorted()
            guard dates.count > 1 else { return 0 }
            return zip(dates, dates.dropFirst())
                .map { Int($1.timeIntervalSince($0) / 86400) }.max() ?? 0
        }
        f.plusLongTrou = trou(cette); f.plusLongTrouPrec = trou(prec)

        // les quatre dernières semaines, S-3 → cette semaine
        let semaine0 = cal.dateInterval(of: .weekOfYear, for: maintenant)!.start
        f.pics4 = (0..<4).reversed().map { k in
            let a = semaine0.addingTimeInterval(Double(-k) * 7 * 86400)
            let b = a.addingTimeInterval(7 * 86400)
            return finies.filter { $0.startedAt >= a && $0.startedAt < b }
                .compactMap { picHiit($0) }.max() ?? 0
        }
    }

    // MARK: Peak

    private static func peak(_ f: inout ChambreFenetre,
                             cette: [Workout], avant: [Workout],
                             finies: [Workout], cal: Calendar,
                             maintenant: Date) {
        var maxAvant: [String: Double] = [:]
        for w in avant {
            for ex in w.orderedExercises where ex.maxWeight > 0 {
                maxAvant[ex.exerciseID] = max(maxAvant[ex.exerciseID] ?? 0, ex.maxWeight)
            }
        }
        struct Pic { var id: String; var nom: String; var cat: ExerciseCategory?
                     var charge: Double; var reps: Int; var precedent: Double? }
        var pics: [String: Pic] = [:]
        for w in cette {
            for ex in w.orderedExercises where ex.maxWeight > 0 {
                var p = pics[ex.exerciseID] ?? Pic(id: ex.exerciseID, nom: ex.name,
                                                   cat: ex.exercise?.category, charge: 0,
                                                   reps: 0, precedent: maxAvant[ex.exerciseID])
                if ex.maxWeight >= p.charge {
                    let reps = ex.orderedSets.filter { $0.isDone && $0.weight == ex.maxWeight }.map(\.reps).max() ?? 0
                    if ex.maxWeight > p.charge { p.charge = ex.maxWeight; p.reps = reps }
                    else { p.reps = max(p.reps, reps) }
                }
                pics[ex.exerciseID] = p
            }
        }
        guard !pics.isEmpty else { return }
        // le meilleur : le plus gros record battu ; à défaut le plus lourd
        let tri = pics.values.sorted { a, b in
            let da = a.precedent.map { a.charge - $0 } ?? -1
            let db = b.precedent.map { b.charge - $0 } ?? -1
            if (da > 0) != (db > 0) { return da > 0 }
            if da > 0 { return da > db }
            return a.charge > b.charge
        }
        let top = tri[0]
        let delta = top.precedent.map { top.charge - $0 }
        f.peak = PeakEffortInfo(
            titre: top.nom,
            valeur: "\(poids(top.charge)) kg",
            delta: (delta ?? 0) > 0 ? "+\(poids(delta!))" : nil,
            precedent: top.precedent.map { poids($0) },
            chambreHaut: "\(poids(top.charge)) kg × \(top.reps)",
            chambreBas: top.precedent.map { "previous best · \(poids($0)) kg" } ?? "first time",
            nouveau: (delta ?? 0) > 0)
        f.e1rm = top.charge * (1 + Double(top.reps) / 30)
        f.recordsBattus = tri.filter { t in (t.precedent.map { p in t.charge - p } ?? 0) > 0 }.count
        f.autres = tri.dropFirst().map { t in
            ChambreAutrePic(id: t.id, nom: t.nom,
                            sticker: WoopSticker.pour(categorie: t.cat),
                            charge: t.charge, reps: t.reps,
                            delta: t.precedent.map { p in t.charge - p })
        }

        // l'ascension : chaque fois que la charge max de cet exercice a monté
        var marches: [ChambreMarche] = []
        var record = 0.0
        for w in finies {
            for ex in w.orderedExercises where ex.exerciseID == top.id && ex.maxWeight > record {
                record = ex.maxWeight
                marches.append(ChambreMarche(date: w.startedAt, charge: record))
            }
        }
        f.ascension = marches
        if let derniere = marches.last?.date {
            f.depuisRecord = cal.dateComponents([.day], from: derniere, to: maintenant).day
        }
    }

    // MARK: Formats

    private static func poids(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v)
    }

    private static func nomMois(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "MMMM"
        return f.string(from: d)
    }

    private static func libelle(debut: Date, fin: Date, cal: Calendar, mois: Bool) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR")
        if mois {
            f.dateFormat = "dd.MM"
            return "\(f.string(from: debut)) → \(f.string(from: fin))"
        }
        // « lun 07.09 → dim 13.09 » : le point du jour abrégé (« lun. ») tombe,
        // celui de la date reste — les deux formats sont séparés pour ça.
        f.dateFormat = "EEE"
        let dim = cal.date(byAdding: .day, value: 6, to: debut)!
        func jour(_ d: Date) -> String {
            "\(f.string(from: d).replacingOccurrences(of: ".", with: "")) \(ChambreFmt.jourCourt(d))"
        }
        let s = "\(jour(debut)) → \(jour(dim))"
        return s.prefix(1).uppercased() + s.dropFirst()   // « Lun 07.09 → dim 13.09 »
            .replacingOccurrences(of: "→", with: "→")
    }
}

// MARK: - Le sticker d'une catégorie

extension WoopSticker {
    /// Le mapping tranché le 26-08 : bras = haut, chocolat = abdos, jambes =
    /// bas, abricot = fessiers, basket = cardio. Sans catégorie : la flamme.
    static func pour(categorie: ExerciseCategory?) -> WoopSticker {
        switch categorie {
        case .haut: return .bras
        case .abdos: return .chocolat
        case .bas: return .jambes
        case .fessiers: return .abricot
        case .cardio: return .basket
        case nil: return .flamme
        }
    }
}

// MARK: - Les formats partagés des chambres

enum ChambreFmt {
    static func mmss(_ s: Int) -> String { String(format: "%d:%02d", s / 60, s % 60) }
    static func kmh(_ v: Double) -> String {
        String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
    static func kg(_ v: Double) -> String {
        let n = Int(v.rounded())
        let f = NumberFormatter(); f.groupingSeparator = " "; f.usesGroupingSeparator = true
        f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return (f.string(from: NSNumber(value: n)) ?? "\(n)") + " kg"
    }
    static func poids(_ v: Double) -> String {
        v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    }
    static func jourCourt(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "dd.MM"; return f.string(from: d)
    }
    /// « mardi 08.09 »
    static func jourLong(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE dd.MM"; return f.string(from: d)
    }
    /// « 26 septembre »
    static func dateLongue(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "d MMMM"; return f.string(from: d)
    }
}
