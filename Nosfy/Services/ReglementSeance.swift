import Foundation
import SwiftData

/// Le bilan appartient à une séance, jamais au dernier solde global.
struct BilanRecompenseSeance: Codable, Equatable {
    let pieces: Int
    let piecesMuscu: Int?
    let boosters: Int
    let argent: Int
    let top: String?
    let heuresDouble: [String]?
    let minutesDouble: Int?

    init(_ cloture: SacreServeur.ClotureSeance) {
        // booster_ids reste complet après acquittement des annonces, contrairement
        // aux événements visibles et au drapeau booster_neuf du rejeu.
        let events = cloture.recu?.evenements ?? []
        pieces = cloture.piecesTotal
        piecesMuscu = cloture.pieces
        boosters = cloture.boostersGagnes ?? events.filter { $0.genre == "sachet" }.reduce(0) { $0 + $1.montant }
        argent = cloture.argentSeance ? 1 : 0
        top = cloture.faits.first { $0.kind == "top_muscu" || $0.kind == "top_cardio" }?.kind
        let double = cloture.faits.first { $0.kind == "double_jour" }
        heuresDouble = double.map { $0.detail["heures"] as? [String] ?? [] }
        minutesDouble = (double?.detail["minutes"] as? NSNumber)?.intValue
    }
}

@MainActor
final class ReglementSeance {
    static let shared = ReglementSeance()
    var contexte: ModelContext?
    private var repriseEnCours: UUID?
    private var attentes: [UUID: [CheckedContinuation<Void, Never>]] = [:]

    /// Le marqueur et la séance ont déjà été sauvés ensemble. On alimente
    /// l'outbox AVANT la synchro, qui pourra ensuite régler sans perdre le gain.
    func reprendre() async {
        guard EconomieWoop.possible, let contexte else { return }
        let generation = CompteEtat.shared.generationDonnees
        while repriseEnCours == generation {
            await withCheckedContinuation { attentes[generation, default: []].append($0) }
            guard generation == CompteEtat.shared.generationDonnees, !Task.isCancelled else { return }
        }
        repriseEnCours = generation
        defer {
            if repriseEnCours == generation { repriseEnCours = nil }
            attentes.removeValue(forKey: generation)?.forEach { $0.resume() }
        }
        let ticket = await OutboxGains.shared.identiteGeneration
        guard let owner = try? await SupabaseSession.shared.currentUserID(),
              generation == CompteEtat.shared.generationDonnees else { return }
        let workouts = (try? contexte.fetch(FetchDescriptor<Workout>())) ?? []
        let ids = await OutboxGains.shared.seancesARejouer
        guard generation == CompteEtat.shared.generationDonnees else { return }
        let finies = workouts.filter { $0.endedAt != nil && ($0.recompenseARegler || ids.contains($0.remoteID)) }
        let snapshots = finies.map { $0.snapshot() }
        for workout in finies where workout.recompenseARegler {
            await OutboxGains.shared.retenir(.finDeSeance(seance: workout.remoteID, series: workout.seriesPayantes), siGeneration: ticket)
            guard generation == CompteEtat.shared.generationDonnees else { return }
        }
        await SupabaseSync.shared.push(snapshots, proprietaire: owner)
        guard generation == CompteEtat.shared.generationDonnees else { return }
        await OutboxGains.shared.vider()
    }

    /// Appelé sous la garde de génération de l'outbox, avant son acquittement.
    func recevoir(_ cloture: SacreServeur.ClotureSeance) {
        guard let contexte, let id = cloture.workoutId.flatMap(UUID.init(uuidString:)),
              let workout = try? contexte.fetch(FetchDescriptor<Workout>(predicate: #Predicate { $0.remoteID == id })).first
        else { return }
        do {
            workout.bilanRecompense = try JSONEncoder().encode(BilanRecompenseSeance(cloture))
            workout.recompenseARegler = false
            try contexte.save()
        } catch {
            // Le marqueur persiste encore sur disque : prochain lancement,
            // même UUID, même reçu, aucun second versement.
            workout.recompenseARegler = true
            print("[fin-seance] reçu non sauvegardé : \(error)")
        }
    }
}
