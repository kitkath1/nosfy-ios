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
    var id = UUID()
    let annonce: Annonce
    var evenement: EvenementGain? = nil
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
    private var attente: [AnnonceVisible] = []
    /// Le temps qu'une carte tient avant de céder la place.
    var duree: TimeInterval = 2.8
    /// Le souffle entre deux cartes (l'une sort, l'autre entre).
    var entredeux: TimeInterval = 0.4
    /// Invalide la minuterie d'une carte retirée par `vider()` ou remplacée.
    private var jeton = 0

    /// POUSSER UNE ANNONCE — elle prend la place libre, ou attend son tour.
    func pousser(_ a: Annonce) {
        attente.append(AnnonceVisible(annonce: a))
        avancer()
    }

    /// POUSSER UNE PILE — chacune son plein temps, l'une après l'autre (les
    /// pièces, puis le sachet). La file séquence toute seule ; l'`espace`
    /// d'antan n'a plus de rôle (gardé pour ne pas casser les appelants).
    func pousser(_ liste: [Annonce], espace: TimeInterval = 0) {
        attente.append(contentsOf: liste.map { AnnonceVisible(annonce: $0) })
        avancer()
    }

    /// Montre la suivante SI la place est libre ; sinon elle attend.
    private func avancer() {
        guard visible == nil, !attente.isEmpty else { return }
        let v = attente.removeFirst()
        jeton += 1
        let j = jeton
        withAnimation(.spring(response: 0.48, dampingFraction: 0.82)) {
            visible = v
        }
        NavDiagnostic.noter("annonce-visible", destination: String(v.annonce.montant))
        DispatchQueue.main.asyncAfter(deadline: .now() + duree) { [weak self] in
            guard let self, self.jeton == j else { return }
            if let e = v.evenement {
                var vus = Set(UserDefaults.standard.stringArray(forKey: self.cleVus(e.userId)) ?? [])
                vus.insert(e.id)
                UserDefaults.standard.set(Array(vus), forKey: self.cleVus(e.userId))
                Task { await CartesServeur.acquitter(e) }
            }
            withAnimation(.easeOut(duration: 0.35)) { self.visible = nil }
            DispatchQueue.main.asyncAfter(deadline: .now() + self.entredeux) {
                self.avancer()
            }
        }
    }

    private func cleVus(_ user: String) -> String { "woop.annonces.vues.\(user.lowercased())" }

    func pousser(_ events: [EvenementGain]) {
        for e in events {
            guard e.userId.lowercased() == EconomieWoop.shared.proprietaireCartes else { continue }
            let vus = Set(UserDefaults.standard.stringArray(forKey: cleVus(e.userId)) ?? [])
            if vus.contains(e.id) { Task { await CartesServeur.acquitter(e) }; continue }
            guard visible?.evenement?.id != e.id, !attente.contains(where: { $0.evenement?.id == e.id }) else { continue }
            let a: Annonce
            switch e.genre {
            case "argent": a = .argent(e.montant)
            case "retour": a = .retour(e.montant)
            case "cardio": a = .cardio(e.montant)
            case "sachet", "noir": a = .sachet(e.montant)
            default: a = .pieces(e.montant)
            }
            attente.append(AnnonceVisible(id: UUID(uuidString: e.id) ?? UUID(), annonce: a, evenement: e))
        }
        avancer()
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let visible = file.visible
        let fenetre = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
            .first(where: \.isKeyWindow)
        let hautSur = fenetre?.safeAreaInsets.top ?? 0
        let largeur = fenetre?.bounds.width ?? 393
        let haut: CGFloat = hautSur >= 51 ? 11 : max(6, hautSur)
        // Ce socle reste monté quand la file est vide. Le GeometryReader
        // dans cette pile racine ne montait pas sa branche d'annonce.
        VStack(spacing: 0) {
            if let v = visible {
                AnnonceDepuisIle(visible: v, largeur: largeur,
                                 hautSur: hautSur)
                    .id(v.id)
                    .accessibilityIdentifier("annonce-ile-\(v.annonce.montant)")
                    .transition(reduceMotion || CommandLine.arguments.contains("-sansMorphAnnonces")
                        ? .opacity : .modifier(
                        active: MorphAnnonceIle(ouverture: 0),
                        identity: MorphAnnonceIle(ouverture: 1)))
                    .offset(y: haut)
                    .frame(maxWidth: .infinity, alignment: .top)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onChange(of: visible?.id) { _, _ in
            NavDiagnostic.noter("annonces-rendu", destination: String(visible?.annonce.montant ?? 0))
        }
        .onAppear {
            NavDiagnostic.noter("annonces-hote")
            guard CommandLine.arguments.contains("-pileTest") else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 13) {
                NavDiagnostic.noter("annonces-banc")
                FileAnnonces.shared.pousser([.pieces(120), .sachet(1)])
            }
        }
    }
}

/// Une seule peau noire s'ouvre depuis l'île. Ses bornes de layout restent
/// fixes : seul le masque dessiné s'étire, l'encre apparaît ensuite.
private struct MorphAnnonceIle: ViewModifier, Animatable {
    var ouverture: CGFloat
    var animatableData: CGFloat {
        get { ouverture }
        set { ouverture = newValue }
    }

    func body(content: Content) -> some View {
        content
            .environment(\.ouvertureAnnonceIle, min(1, max(0, ouverture)))
            .mask(FormeAnnonceIle(ouverture: ouverture))
    }
}

private struct OuvertureAnnonceIleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private extension EnvironmentValues {
    var ouvertureAnnonceIle: CGFloat {
        get { self[OuvertureAnnonceIleKey.self] }
        set { self[OuvertureAnnonceIleKey.self] = newValue }
    }
}

private struct FormeAnnonceIle: Shape {
    var ouverture: CGFloat
    var animatableData: CGFloat {
        get { ouverture }
        set { ouverture = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let u = min(1, max(0, ouverture))
        let w = min(126, rect.width) + (rect.width - min(126, rect.width)) * u
        let h = 36 + (rect.height - 36) * u
        return Path(roundedRect: CGRect(x: (rect.width - w) / 2, y: 0,
                                        width: w, height: h),
                    cornerRadius: 18 + (NotifGeo.rayon - 18) * u)
    }
}

private struct AnnonceDepuisIle: View {
    let visible: AnnonceVisible
    let largeur: CGFloat
    let hautSur: CGFloat
    @Environment(\.ouvertureAnnonceIle) private var ouverture
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // La réserve protège la caméra. La vue ignore la safe area : elle
        // n'ajoute donc plus deux fois le dégagement supérieur.
        let haut: CGFloat = hautSur >= 51 ? 11 : max(6, hautSur)
        let reserve = hautSur >= 51 ? max(40, hautSur - haut + 3) : 8
        let w = max(126, largeur - 2 * NotifGeo.margeH)
        ZStack(alignment: .top) {
            Color.black
            ToasterAnnonce(annonce: visible.annonce)
                .frame(width: largeur, height: NotifGeo.hauteur)
                .padding(.top, reserve)
                .opacity(reduceMotion ? Double(ouverture) : Double(max(0, (ouverture - 0.40) / 0.60)))
                .offset(y: reduceMotion ? 0 : (1 - ouverture) * -8)
        }
        .frame(width: w, height: reserve + NotifGeo.hauteur)
        .clipped()
        .onAppear {
            NavDiagnostic.noter("annonce-montee", destination: "\(visible.annonce.montant);largeur=\(largeur);haut=\(hautSur)")
            CarillonIle.entree()
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
