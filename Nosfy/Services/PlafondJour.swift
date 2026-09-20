import SwiftUI

// MARK: - LE PLAFOND DU JOUR (20-09) — deux séances par jour comptent, pas trois

/// Sa règle du 20-09 : « maximum deux séances par jour dans la Route de galets,
/// pour pas tricher et avoir trop de boosters ». La MÊME règle vit au serveur
/// (`reward_rules.chemin_seances_par_jour_max`, `seances_chemin_plafonnees()`,
/// migration `20260920160000`) : le téléphone l'applique pour répondre tout de
/// suite — la Route, la card Route, les portes de départ — et le serveur tranche
/// (une troisième séance ne paie rien : `plafond_jour`). Le jour est le jour
/// LOCAL du téléphone ; la séance emporte son fuseau au serveur
/// (`workouts.fuseau`, posé par `SupabaseSync`), qui compte le même jour.
///
/// Plan et décisions : `tools/duolingo/PLAN-PLAFOND-2-SEANCES-JOUR-2026-09-20.md`.
enum PlafondJour {

    /// La constante du téléphone — la valeur de `reward_rules` au 20-09. Le
    /// serveur reste la source ; ceci sert à répondre avant lui, pas à décider.
    static let maxParJour = 2

    /// Le plafond vaut pour les séances finies À PARTIR de ce jour (la règle
    /// `chemin_plafond_depuis`, la même au serveur) : les journées d'avant
    /// gardent tous leurs galets — lu le 20-09, son propre compte avait quatre
    /// séances avec travail le matin même. Le banc `-plafondJourDepuis AAAA-MM-JJ`
    /// avance ou recule la date (avec `-demoData` : trois séances aujourd'hui,
    /// deux comptées, la troisième refusée).
    static let depuis: DateComponents = {
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-plafondJourDepuis"), i + 1 < a.count {
            let p = a[i + 1].split(separator: "-").compactMap { Int($0) }
            if p.count == 3 { return DateComponents(year: p[0], month: p[1], day: p[2]) }
        }
        return DateComponents(year: 2026, month: 9, day: 21)
    }()

    /// Le jour local d'une date — trois composantes, comparables.
    static func jour(_ d: Date, calendrier: Calendar = .current) -> DateComponents {
        calendrier.dateComponents([.year, .month, .day], from: d)
    }

    private static func avantLaRegle(_ j: DateComponents) -> Bool {
        (j.year ?? 0, j.month ?? 0, j.day ?? 0) < (depuis.year!, depuis.month!, depuis.day!)
    }

    /// Parmi des dates de fin (des séances AVEC travail, dans n'importe quel
    /// ordre), celles qui COMPTENT : les `maxParJour` premières de chaque jour
    /// local — et toutes celles d'avant la règle. Rendues triées, avec le rang
    /// de chacune dans sa journée (1, 2 : le 2 est le « ×2 »).
    static func comptees(_ dates: [Date], calendrier: Calendar = .current)
        -> [(date: Date, rangJour: Int)] {
        var parJour: [DateComponents: Int] = [:]
        var sortie: [(date: Date, rangJour: Int)] = []
        for d in dates.sorted() {
            let j = jour(d, calendrier: calendrier)
            let rang = (parJour[j] ?? 0) + 1
            parJour[j] = rang
            if avantLaRegle(j) || rang <= maxParJour { sortie.append((d, rang)) }
        }
        return sortie
    }

    /// Combien de séances COMPTÉES aujourd'hui (jour local).
    static func faitesAujourdhui(_ dates: [Date], maintenant: Date = Date(),
                                 calendrier: Calendar = .current) -> Int {
        let aujourdhui = jour(maintenant, calendrier: calendrier)
        return comptees(dates, calendrier: calendrier)
            .filter { jour($0.date, calendrier: calendrier) == aujourdhui }.count
    }

    /// Le plafond est atteint : plus de séance comptée aujourd'hui.
    static func atteint(_ dates: [Date], maintenant: Date = Date(),
                        calendrier: Calendar = .current) -> Bool {
        !avantLaRegle(jour(maintenant, calendrier: calendrier))
            && faitesAujourdhui(dates, maintenant: maintenant, calendrier: calendrier) >= maxParJour
    }

    // MARK: Les mots

    /// Le refus — sa demande : une pop-up NATIVE Apple. Dans la langue du profil
    /// (`L`), comme les autres messages système de l'app (le compte, le réseau).
    static var titre: String {
        L("Deux séances aujourd'hui", "Two sessions today")
    }
    static var message: String {
        L("C'est le maximum d'une journée pour la Route. Revenez demain !",
          "That's the daily maximum for the Route. Come back tomorrow!")
    }
}

extension View {
    /// L'alerte native du refus — la même à toutes les portes : la Home, la
    /// Route, les Exercices. Un seul bouton : il n'y a rien d'autre à faire.
    func alertePlafondJour(_ presente: Binding<Bool>) -> some View {
        alert(PlafondJour.titre, isPresented: presente) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(PlafondJour.message)
        }
    }
}
