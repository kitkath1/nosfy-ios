import SwiftUI
import UIKit

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

    /// LA dalle à l'écran — UNE seule (Option A, verdict Kathryn 15-09 : la
    /// belle pastille est GRANDE, on ne l'empile pas ; les événements se
    /// disent L'UN APRÈS L'AUTRE — les pièces, PUIS le sachet).
    private(set) var visible: AnnonceVisible?
    /// Ce qui attend son tour.
    private var attente: [Annonce] = []
    /// Le temps qu'une carte tient avant de céder la place.
    var duree: TimeInterval = 2.8
    /// Le souffle entre deux cartes (l'une sort, l'autre entre).
    var entredeux: TimeInterval = 0.4
    /// Invalide la minuterie d'une carte retirée par `vider()` ou remplacée.
    private var jeton = 0

    /// POUSSER UNE ANNONCE — elle prend la place libre, ou attend son tour.
    func pousser(_ a: Annonce) {
        attente.append(a)
        avancer()
    }

    /// POUSSER UNE PILE — chacune son plein temps, l'une après l'autre (les
    /// pièces, puis le sachet). La file séquence toute seule ; l'`espace`
    /// d'antan n'a plus de rôle (gardé pour ne pas casser les appelants).
    func pousser(_ liste: [Annonce], espace: TimeInterval = 0) {
        attente.append(contentsOf: liste)
        avancer()
    }

    /// Montre la suivante SI la place est libre ; sinon elle attend.
    private func avancer() {
        guard visible == nil, !attente.isEmpty else { return }
        let v = AnnonceVisible(annonce: attente.removeFirst())
        jeton += 1
        let j = jeton
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            visible = v
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duree) { [weak self] in
            guard let self, self.jeton == j else { return }
            withAnimation(.easeOut(duration: 0.35)) { self.visible = nil }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.entredeux) {
                self.avancer()
            }
        }
    }

    func vider() {
        jeton += 1
        attente.removeAll()
        withAnimation(.easeOut(duration: 0.25)) { visible = nil }
    }
}

// MARK: - L'hôte, à la racine

/// LA PILE, montée UNE fois à la racine (zIndex 9, en haut, sous rien) — les
/// dalles se posent l'une sous l'autre et ne prennent aucun toucher.
struct PileAnnoncesHote: View {
    private var file = FileAnnonces.shared

    /// LE DÉGAGEMENT DU HAUT, DEVICE PAR DEVICE (bug Kathryn 16-09 : « le toaster
    /// disparaît dans le Dynamic Island »). Le 54 fixe passait sur un iPhone SANS
    /// île mais PAS sur un iPhone à Dynamic Island (inset ~59) : on lit l'inset
    /// RÉEL de la fenêtre (l'île + la barre d'état) et on pose le toaster JUSTE
    /// dessous — aussi haut que possible, jamais une valeur qui ment selon le modèle.
    private var degagementHaut: CGFloat {
        let insetHaut = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets.top ?? 47
        return insetHaut + 6
    }

    var body: some View {
        VStack(spacing: 0) {
            if let v = file.visible {
                ToasterAnnonce(annonce: v.annonce)
                    .id(v.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        // Sous le Dynamic Island (Kathryn 15-09 puis 16-09) — le dégagement est
        // maintenant l'inset RÉEL de la fenêtre (device par device), pas un 54 fixe
        // qui disparaissait dans l'île sur les iPhone à Dynamic Island.
        .padding(.top, degagementHaut)
        .allowsHitTesting(false)
        .onAppear {
            // `-pileTest` : la séquence des annonces (pièces → sachet) se joue
            // seule — le simulateur ne finit pas une séance pour de vrai.
            guard CommandLine.arguments.contains("-pileTest") else { return }
            // Après le splash (≈10 s), pour que la séquence se voie SUR la home.
            DispatchQueue.main.asyncAfter(deadline: .now() + 13) {
                FileAnnonces.shared.pousser([.pieces(120), .sachet(1)])
            }
        }
    }
}

/// LA DALLE D'ANNONCE, en BELLE pastille (Option A) : chaque événement dit par
/// SA robe — les pièces (et cardio, retour) par la robe pièce, le sachet par la
/// robe booster. La jauge lit toujours le coffre (reste / prix). Les gros mots
/// restent en anglais.
struct ToasterAnnonce: View {
    let annonce: Annonce

    private var fraction: Double {
        Double(EconomieWoop.shared.reste)
            / Double(max(EconomieWoop.shared.prixBooster, 1))
    }

    @ViewBuilder
    var body: some View {
        switch annonce {
        case .pieces(let n):
            ToasterGain(gain: n, fraction: fraction, libelle: "COINS EARNED")
        case .cardio(let n):
            ToasterGain(gain: n, fraction: fraction, libelle: "CARDIO COINS")
        case .retour(let n):
            ToasterGain(gain: n, fraction: fraction, libelle: "DAILY BONUS")
        case .argent(let n):
            // ⚠️ Pas encore de robe ARGENT (une pièce d'argent détourée à
            // faire) : la robe pièce en attendant. Rare (1 sur 30).
            ToasterGain(gain: n, fraction: fraction, libelle: "SILVER COINS")
        case .sachet(let n):
            ToasterGain(gain: n, fraction: fraction, robe: .booster,
                        libelle: "BOOSTER")
        }
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
