import Foundation

// MARK: - La bourse
//
// LA MONNAIE N'EXISTE PAS ENCORE DANS WOOP. Aucun modèle SwiftData ne porte
// de pièces (Workout, LoggedExercise, StrengthSet, CardioPhase — c'est tout),
// et aucune règle ne dit ce qu'une séance rapporte. Ce point d'accès est donc
// une MAQUETTE assumée, tenue en UN SEUL endroit : le jour où l'économie est
// tranchée, c'est ce corps-là qu'on remplace, et pas une ligne de la page ne
// bouge.
//
// ⚠️ POURQUOI ELLE VIT DANS SON PROPRE FICHIER DEPUIS LE 25-08.
// Elle habitait `CoffreFortView.swift`, c'est-à-dire le fichier que la refonte
// du coffre (chantier `tools/coffre-v2/`) remplace entièrement. Or elle est
// consommée par CINQ sites HORS de cette page :
//
//     HomeAuroraView.swift · HomeNuit.swift · ProfilLune.swift
//     BravoLab.swift (`perSeries`) · SetHistoryRow.swift (valeur par défaut)
//
// Laisser l'économie de l'app dans le fichier d'une page qu'on démonte, c'est
// faire dépendre cinq compilations du sort d'un écran. Elle en sort AVANT
// toute autre ligne du chantier — c'est le jalon C0 du plan.
enum CoffreFortPurse {
    /// L'ÉCONOMIE EST TRANCHÉE (13 août 2026) : chaque SÉRIE terminée
    /// rapporte 20 pièces. La fiche, BRAVO et le coffre disent le même
    /// nombre.
    ///
    /// ⚠️ **LU, PLUS CONNU (15-09).** Jusqu'ici c'était `static let perSeries
    /// = 20` — la dernière copie Swift d'une règle qui vit en base
    /// (`reward_rules.pieces_par_serie`, rendue par `etat_coffre()` et posée
    /// dans `EconomieWoop.piecesParSerie`). La pill « +20 · 100 this
    /// session » lisait déjà le serveur ; l'ardoise du player et BRAVO
    /// lisaient ce 20-là. Deux endroits pour un nombre, c'est le jour où
    /// l'un bouge que l'écran et la base racontent deux histoires. Le 20 ne
    /// survit qu'en SECOURS, avant la première réponse — celui
    /// d'`EconomieWoop`, le même que partout. Rien ne change à l'écran.
    @MainActor static var perSeries: Int { EconomieWoop.shared.piecesParSerie }
    @MainActor static func coins(doneSeries: Int) -> Int { doneSeries * perSeries }
}
