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
    /// gardent tous leurs galets. Posé au 21-09 le matin du 20-09 (son propre
    /// compte avait quatre séances avec travail ce matin-là), puis **ramené au
    /// 20-09 l'après-midi** sur son verdict (« ×4 dans la Route : non,
    /// impossible — max deux et le sticker, basta ») une fois les comptes
    /// Apple remis à zéro (migration `20260920170000`, à déployer avec ce
    /// changement). Le banc `-plafondJourDepuis AAAA-MM-JJ` avance ou recule
    /// la date (avec `-demoData` : trois séances aujourd'hui, deux comptées,
    /// la troisième refusée).
    static let depuis: DateComponents = {
        let a = CommandLine.arguments
        if let i = a.firstIndex(of: "-plafondJourDepuis"), i + 1 < a.count {
            let p = a[i + 1].split(separator: "-").compactMap { Int($0) }
            if p.count == 3 { return DateComponents(year: p[0], month: p[1], day: p[2]) }
        }
        return DateComponents(year: 2026, month: 9, day: 20)
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

    /// ⚠️ **LES JOURS DE LA ROUTE** (21-09, sa règle : « un galet = 1 jour
    /// malgré deux séances, sinon tout s'épuise trop vite »). Un jour LOCAL
    /// qui porte au moins une séance comptée vaut UN galet ; la deuxième
    /// séance de la journée n'en pose pas un second — elle pose le sticker
    /// ×2 sur celui du jour. Le plafond ne bouge pas : il borne ce qui
    /// COMPTE (`comptees`), pas ce qui s'affiche, et la clôture continue de
    /// payer la deuxième (sa décision du 21-09).
    ///
    /// Rendus dans l'ordre des jours. `date` = la PREMIÈRE fin du jour
    /// (celle qui a ouvert le galet, c'est elle que le galet porte),
    /// `derniere` = la dernière (pour retrouver la bonne story),
    /// `seances` = 1 ou 2 — c'est lui, et lui seul, qui dit le ×2.
    static func jours(_ dates: [Date], calendrier: Calendar = .current)
        -> [(date: Date, seances: Int, derniere: Date)] {
        var ordre: [DateComponents] = []
        var parJour: [DateComponents: (premiere: Date, derniere: Date, n: Int)] = [:]
        for (d, _) in comptees(dates, calendrier: calendrier) {
            let j = jour(d, calendrier: calendrier)
            if var e = parJour[j] {
                e.n += 1
                e.derniere = max(e.derniere, d)
                parJour[j] = e
            } else {
                parJour[j] = (d, d, 1)
                ordre.append(j)
            }
        }
        return ordre.compactMap { j in
            parJour[j].map { (date: $0.premiere, seances: $0.n, derniere: $0.derniere) }
        }
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
