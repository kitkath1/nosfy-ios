import SwiftUI

// MARK: - LES ANNONCES : une file, des dalles qui S'EMPILENT
//
// ⚠️⚠️ **UN SEUL CRÉNEAU, C'ÉTAIT LE DÉFAUT.** Jusqu'au 30-08 la dalle des pièces
// était un `Int?` (`DepartEtat.notifPieces`) : une seconde écriture ÉCRASAIT la
// première, la clôture et le chemin se battaient pour la même case, et il n'y
// avait qu'une robe — les pièces. Un sachet gagné, une pièce d'argent tombée,
// le +10 du retour n'avaient nulle part où se dire.
//
// Tranché par Kathryn le 30-08 (tools/annonces/PLAN-COFFRE-ANNONCES.md §0, §3) :
// **une annonce PAR ÉVÉNEMENT, et à la clôture elles s'EMPILENT** l'une sous
// l'autre — pièces, sachet, argent. Chaque événement a sa robe ; la robe ne
// décide de rien, l'événement vient du serveur ou d'un fait local dit tel quel.
//
// La file vit ici, à côté de l'économie, parce qu'elle est nourrie par elle :
// `EconomieWoop.appliquer(ClotureSeance)` y pousse la pièce d'argent et les
// sachets convertis quand le serveur répond ; la chaîne de fin de séance y
// pousse les pièces et le sachet forfaitaire ; le chemin y pousse son tirage ;
// le Claim du Welcome Back y pousse ses +10 AU TAP (Q8 : « le montant est
// local, le journal rattrape »).
//
// ⚠️ **ELLE N'ÉCRIT JAMAIS UN ÉTAT** : une dalle est une quittance, pas une
// vérité. Le solde vit dans `EconomieWoop`, le carnet au serveur.

/// UN ÉVÉNEMENT À DIRE — la robe de la dalle en découle.
enum Annonce: Equatable {
    /// « +N pièces lune » — la clôture (séries × taux), le chemin en pièces.
    case pieces(Int)
    /// « +N sachet(s) » — le forfaitaire de clôture, les convertis (100 → 1),
    /// le chemin en sachets.
    case sachet(Int)
    /// « +N pièce d'argent » — `roll_rare`, 1 chance sur 30 à la clôture.
    case argent(Int)
    /// « +N · retour du jour » — le Welcome Back, au tap du Claim.
    case retour(Int)
    /// « +N cardio » — le barème de séance calculé par le serveur (15-09),
    /// dit quand `cloturer_seance` répond.
    case cardio(Int)

    var montant: Int {
        switch self {
        case .pieces(let n), .sachet(let n), .argent(let n), .retour(let n),
             .cardio(let n): return n
        }
    }
}

/// Une annonce POSÉE : son identité est celle de son passage, pas de son
/// contenu — deux « +20 » d'affilée sont deux dalles.
struct AnnonceVisible: Identifiable, Equatable {
    let id = UUID()
    let annonce: Annonce
}

@MainActor
@Observable
final class FileAnnonces {
    static let shared = FileAnnonces()
    private init() {}

    /// Ce qui est à l'écran, dans l'ordre d'arrivée (la plus ancienne en haut).
    private(set) var visibles: [AnnonceVisible] = []
    /// Combien de temps une dalle reste (la capsule d'avant : 3,0 s + sa sortie).
    var duree: TimeInterval = 3.2
    /// Jamais plus de quatre à l'écran : au-delà, la plus ancienne part.
    var plafond = 4

    /// POUSSER UNE ANNONCE — elle descend, s'empile sous les précédentes, et se
    /// retire toute seule après `duree`.
    func pousser(_ a: Annonce) {
        let v = AnnonceVisible(annonce: a)
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            visibles.append(v)
            if visibles.count > plafond { visibles.removeFirst() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duree) { [weak self] in
            self?.retirer(v.id)
        }
    }

    /// POUSSER UNE PILE — l'une après l'autre, à `espace` d'écart, pour que
    /// l'œil les compte (la clôture : pièces, sachet, argent).
    func pousser(_ liste: [Annonce], espace: TimeInterval = 0.45) {
        for (i, a) in liste.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * espace) { [weak self] in
                self?.pousser(a)
            }
        }
    }

    func retirer(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.35)) {
            visibles.removeAll { $0.id == id }
        }
    }

    func vider() {
        withAnimation(.easeOut(duration: 0.25)) { visibles.removeAll() }
    }
}

// MARK: - L'hôte, à la racine

/// LA PILE, montée UNE fois à la racine (zIndex 9, en haut, sous rien) — les
/// dalles se posent l'une sous l'autre et ne prennent aucun toucher.
struct PileAnnoncesHote: View {
    private var file = FileAnnonces.shared

    var body: some View {
        VStack(spacing: 8) {
            ForEach(file.visibles) { v in
                DalleAnnonce(annonce: v.annonce)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .allowsHitTesting(false)
    }
}

// MARK: - La dalle, et ses robes

/// LA DALLE — la capsule de verre de la maison (`PiecesNotif`, 29-08 : verre
/// `.clear` sous noir 0,35, 44 pt, Inter), avec la robe de son événement :
/// la pièce d'or, le sachet orange, la pièce d'argent. Le compte ROULE en trois
/// paliers — jamais un chiffre posé.
struct DalleAnnonce: View {
    let annonce: Annonce
    @State private var compte = 0

    private var libelle: String {
        switch annonce {
        case .pieces:        return "pièces lune"
        case .cardio:        return "cardio"
        case .retour:        return "retour du jour"
        case .sachet(let n): return n > 1 ? "sachets" : "sachet"
        case .argent(let n): return n > 1 ? "pièces d'argent" : "pièce d'argent"
        }
    }

    var body: some View {
        HStack(spacing: 9) {
            glyphe
            Text("+\(compte)")
                .font(.inter(16, .bold))
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(compte)))
            Text(libelle)
                .font(.inter(13, .medium))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.35))
                .background {
                    Color.clear.glassEffect(.clear,
                                            in: Capsule(style: .continuous))
                }
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .onAppear(perform: rouler)
    }

    /// La robe : ce qu'on a gagné, dit par l'objet — jamais par un mot de plus.
    @ViewBuilder
    private var glyphe: some View {
        switch annonce {
        case .pieces, .retour, .cardio:
            // La petite pièce d'or : le disque de braise au liseré (la même
            // que `PiecesNotif`, pour que la dalle des pièces ne change pas).
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.72, blue: 0.32),
                                 Color(red: 0.85, green: 0.4, blue: 0.1)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: 20)
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    .frame(width: 20, height: 20)
            }
        case .sachet:
            // Le sachet ORANGE détouré (`booster-orange`, la robe 4 du plan
            // V9 — « le sachet à la place de la pièce »).
            Image("booster-orange")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
        case .argent:
            // La pièce d'argent de la maison (`piece-argent-mini`).
            Image("piece-argent-mini")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        }
    }

    private func rouler() {
        compte = 0
        let n = annonce.montant
        // Un petit nombre (1 sachet, 1 pièce d'argent) n'a rien à faire rouler.
        guard n >= 3 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.2)) { compte = n }
            }
            return
        }
        let paliers = [n / 3, n * 2 / 3, n]
        for (i, p) in paliers.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35 + Double(i) * 0.22) {
                withAnimation(.easeOut(duration: 0.2)) { compte = p }
            }
        }
    }
}
