import SwiftUI

// MARK: - L'accueil du Sacre : la carte rentre à la maison
//
// Après l'envol (la carte partie « comme un avion »), le profil
// l'ACCUEILLE : auto-scroll vers le registre de sa rareté, la rangée
// s'avance, la carte redescend du ciel — inclinée, elle se redresse à
// l'approche — et se pose sur le premier dos vide, dans une bouffée de
// fumée très fine et un clic de sertissage. Doublon : elle rejoint SA
// carte déjà posée et la pastille ×N tique.
//
// V1 MÉMOIRE : le store vit le temps du process. Supabase (user_cards)
// se branchera ENSEMBLE avec Kathryn — jamais sans elle (la règle).

// MARK: LE GABARIT D'UN EMPLACEMENT (la source unique de vérité)

/// Un dos vide et une carte posée sont LE MÊME OBJET à l'écran : même
/// largeur, même hauteur, même rayon, même place dans la rangée. Ce
/// gabarit est donc partagé par les trois vues (DosVide,
/// CarteCollectionnee, DescenteCarte) — plus jamais deux tailles.
///
/// Le ratio 0,648 est celui du LISERÉ des cartes, mesuré : la carte
/// forgée (1086×1448, liseré à 0,6479) et le dos vide (recadré sur son
/// liseré, 922×1423 → 0,6479) partagent exactement la même silhouette.
/// Les PNG portaient simplement des marges noires différentes.
enum GabaritCarte {
    static let largeur: CGFloat = 80
    static let ratio: CGFloat = 0.6479
    static var hauteur: CGFloat { largeur / ratio }
    static let rayon: CGFloat = 7

    /// L'art de la forge recadré sur son liseré : la vignette prend la
    /// silhouette exacte de l'emplacement (l'armature de la forge est
    /// constante, ces fractions valent pour toutes les cartes).
    static func vignette(_ art: UIImage) -> UIImage {
        guard let cg = art.cgImage else { return art }
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        let rect = CGRect(x: W * 0.0888, y: H * 0.0405,
                          width: W * 0.8214, height: H * 0.9486)
        guard let coupe = cg.cropping(to: rect) else { return art }
        return UIImage(cgImage: coupe, scale: art.scale,
                       orientation: art.imageOrientation)
    }
}

// MARK: Le store de collection (v1 mémoire)

@MainActor
final class CollectionLune: ObservableObject {
    static let shared = CollectionLune()
    struct Obtenue: Identifiable {
        var id = UUID()
        let famille: String
        var count: Int
        let art: UIImage?
        let artPlein: UIImage?
        let depth: UIImage?
    }
    @Published private(set) var registres: [String: [Obtenue]] = [:]
    @Published private(set) var totaux: [String: Int] = [:]
    @Published private(set) var lueAuServeur = false
    private var acquisitions: Set<String> = []
    private var generation = UUID()
    private var lecture = 0

    func destination(rarete: String, famille: String, cardId: String? = nil)
        -> (slot: Int, doublon: Bool, nouvelle: Bool) {
        let liste = registres[rarete] ?? []
        if let cardId, let i = liste.firstIndex(where: { $0.id.uuidString.lowercased() == cardId.lowercased() }) { return (i, true, false) }
        if cardId == nil, let i = liste.firstIndex(where: { $0.famille == famille }) { return (i, true, false) }
        return (liste.count, false, true)
    }

    func poser(rarete: String, famille: String, art: UIImage?, artPlein: UIImage? = nil,
               depth: UIImage? = nil, cardId: String? = nil, acquisitionId: String? = nil) {
        if let acquisitionId, acquisitions.contains(acquisitionId) { return }
        // Une cérémonie de démonstration n'entre jamais dans une collection connectée.
        guard cardId != nil || !EconomieWoop.possible else { return }
        lecture += 1
        if let acquisitionId { acquisitions.insert(acquisitionId) }
        var liste = registres[rarete] ?? []
        let d = destination(rarete: rarete, famille: famille, cardId: cardId)
        if d.doublon { liste[d.slot].count += 1 }
        else {
            liste.append(Obtenue(id: cardId.flatMap(UUID.init(uuidString:)) ?? UUID(),
                famille: famille, count: 1, art: art, artPlein: artPlein, depth: depth))
        }
        registres[rarete] = liste
    }

    func collectees(_ rarete: String) -> [Obtenue] { registres[rarete] ?? [] }

    func oublier() {
        generation = UUID(); lecture += 1
        registres = [:]; acquisitions = []; totaux = [:]; lueAuServeur = false
    }

    func relire() async {
        let g = generation
        lecture += 1
        let tour = lecture
        do {
            let jwt = try await SupabaseSession.shared.token()
            let familles = try await SacreServeur.maCollection(jwt: jwt)
            let compte = try await CartesServeur.objet("totaux_cartes", jwt: jwt) as? [String: Int] ?? [:]
            var nouveaux: [String: [Obtenue]] = [:]
            for f in familles {
                let habit = await Task.detached(priority: .utility) {
                    guard let nue = await Self.illustration(f) else { return nil as (art: UIImage, depth: UIImage)? }
                    return try? LuneForge.habiller(illustration: nue, rarete: f.rarete)
                }.value
                nouveaux[f.rarete, default: []].append(Obtenue(
                    id: UUID(uuidString: f.cardId) ?? UUID(), famille: f.famille, count: f.nombre,
                    art: habit.map { GabaritCarte.vignette($0.art) }, artPlein: habit?.art, depth: habit?.depth))
            }
            guard g == generation, tour == lecture else { return }
            registres = nouveaux
            acquisitions = Set(familles.flatMap { $0.acquisitions })
            totaux = compte; lueAuServeur = true
            print("[collection] \(familles.count) références · \(familles.reduce(0) { $0 + $1.nombre }) exemplaires")
        } catch { print("[collection] relecture en attente : \(error.localizedDescription)") }
    }

    nonisolated private static func illustration(_ f: SacreServeur.FamilleCollection) async -> UIImage? {
        let dossier = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appending(path: "cartes-lune")
        try? FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        let fichier = dossier.appending(path: "\(f.cardId).png")
        if let data = try? Data(contentsOf: fichier), let image = UIImage(data: data) { return image }
        guard let (data, rep) = try? await URLSession.shared.data(from: f.artURL),
              (rep as? HTTPURLResponse)?.statusCode == 200, let image = UIImage(data: data) else { return nil }
        try? data.write(to: fichier, options: .atomic)
        return image
    }

    func reparerPlaceholder(avec carte: LuneForge.Carte) {
        poser(rarete: carte.famille.rarete, famille: carte.famille.nom,
              art: GabaritCarte.vignette(carte.art), artPlein: carte.art, depth: carte.depth,
              cardId: carte.cardId, acquisitionId: carte.acquisitionId)
    }
}


// MARK: L'ordre d'arrivée (du Sacre vers le profil)

/// Ce que l'ENVOL adresse au profil : la carte vraie (famille + rareté)
/// et sa vignette au gabarit — l'accueil pose ce que la cérémonie a
/// montré, jamais un placeholder si la forge a répondu.
struct CarteEnvolee: Equatable {
    let rarete: String
    let famille: String
    /// La vignette au gabarit (la descente, la grille).
    let art: UIImage?
    /// Le canvas complet + depth pour l'état résultat de la collection.
    var artPlein: UIImage? = nil
    var depth: UIImage? = nil
    var cardId: String? = nil
    var acquisitionId: String? = nil

    static func == (a: CarteEnvolee, b: CarteEnvolee) -> Bool {
        a.rarete == b.rarete && a.famille == b.famille
    }
}

struct ArriveeCarte: Equatable {
    let rarete: String
    let famille: String
    let slot: Int
    let doublon: Bool
    let nouvelle: Bool
    var cardId: String? = nil
    var acquisitionId: String? = nil

    static func == (a: ArriveeCarte, b: ArriveeCarte) -> Bool {
        a.rarete == b.rarete && a.famille == b.famille && a.slot == b.slot
    }
}

/// L'art de la carte de cérémonie (placeholder tant que la forge n'est
/// pas branchée au flux) — le même que CarteVivante.
enum ArtDuSacre {
    static let famillePlaceholder = "carte-lune-1"
    static let art: UIImage? = {
        guard let p = Bundle.main.path(forResource: "carte-lune-1",
                                       ofType: "png"),
              let ui = UIImage(contentsOfFile: p) else { return nil }
        // Recadrée au gabarit dès le départ : la carte qui descend et la
        // vignette qui se pose sont la MÊME image, la même silhouette.
        return GabaritCarte.vignette(ui)
    }()
}

// MARK: Les ancres des slots (rangée → position monde)

struct SlotAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: La carte collectionnée (la vignette du registre)

/// L'art posé dans le gabarit du dos (80×142, rayon 8), liseré fin, et
/// la pastille ×N des doublons. PNG statique — une seule CarteVivante
/// à l'écran, la règle de la maison.
struct CarteCollectionnee: View {
    var obtenue: CollectionLune.Obtenue

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let art = obtenue.art {
                    Image(uiImage: art)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.black
                }
            }
            .frame(width: GabaritCarte.largeur, height: GabaritCarte.hauteur)
            .clipShape(RoundedRectangle(cornerRadius: GabaritCarte.rayon,
                                        style: .continuous))
            if obtenue.count > 1 {
                Text("×\(obtenue.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .overlay(Capsule().stroke(.white.opacity(0.2),
                                              lineWidth: 0.6))
                    .offset(x: -5, y: -5)
            }
        }
    }
}

// MARK: La descente (l'avion qui atterrit)

/// La carte revient du ciel : elle entre inclinée par le haut, grandit à
/// l'approche puis RÉTRÉCIT vers la taille du slot en se redressant —
/// jamais une rotation de face (la loi). Un sillage de fumée très fine
/// l'accompagne ; la bouffée du contact vit dans `FumeeDArrivee`.
struct DescenteCarte: View {
    var art: UIImage?
    var cible: CGRect
    var began: Date
    var onLanded: () -> Void

    @State private var landed = false
    /// La durée du vol.
    static let duree: Double = 0.95

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
            let p = min(max(tl.date.timeIntervalSince(began)
                / Self.duree, 0), 1)
            let e = p * p * (3 - 2 * p)
            // La trajectoire : départ hors cadre en haut, léger arc.
            let x0 = cible.midX + 46
            let y0 = -140.0
            let x = x0 + (cible.midX - x0) * e
            let y = y0 + (cible.midY - y0) * (0.22 * p + 0.78 * e)
            // L'échelle : elle arrive « de loin » (petite), gonfle au
            // plus près de l'œil, puis se pose à la taille du slot.
            let w = 66 + 74 * sin(.pi * min(p * 1.12, 1))
                + (Double(GabaritCarte.largeur) - 66) * sstepD(0.55, 1.0, p)
            // L'assiette : inclinée en entrée, droite à la pose.
            let pitch = -14 * (1 - e)
            ZStack {
                // Le sillage : trois volutes très fines derrière elle.
                Canvas { ctx, size in
                    for k in 1 ..< 5 {
                        let pk = p - Double(k) * 0.06
                        guard pk > 0, pk < 1 else { continue }
                        let ek = pk * pk * (3 - 2 * pk)
                        let sx = x0 + (cible.midX - x0) * ek
                        let sy = y0 + (cible.midY - y0)
                            * (0.22 * pk + 0.78 * ek)
                        let a = p - pk
                        let r = 6 + 90 * a
                        let op = 0.045 * (1 - a * 5)
                        guard op > 0 else { continue }
                        ctx.opacity = op
                        ctx.fill(Ellipse().path(in: CGRect(
                            x: sx - r / 2, y: sy - r / 2,
                            width: r, height: r)), with: .color(.white))
                    }
                }
                .blur(radius: 7)
                .allowsHitTesting(false)
                Group {
                    if let art {
                        Image(uiImage: art)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.black
                    }
                }
                .frame(width: w, height: w / Double(GabaritCarte.ratio))
                .clipShape(RoundedRectangle(
                    cornerRadius: Double(GabaritCarte.rayon) * w
                        / Double(GabaritCarte.largeur),
                    style: .continuous))
                .rotation3DEffect(.degrees(pitch), axis: (x: 1, y: 0, z: 0),
                                  perspective: 0.4)
                .position(x: x, y: y)
                .shadow(color: .black.opacity(0.5), radius: 10, y: 6)
            }
            .onChange(of: p >= 1) { _, done in
                guard done, !landed else { return }
                landed = true
                onLanded()
            }
        }
        .allowsHitTesting(false)
    }
}

/// La brique locale du smoothstep (le fichier vit seul).
private func sstepD(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let k = min(max((x - a) / (b - a), 0), 1)
    return k * k * (3 - 2 * k)
}

// MARK: L'éclat de la pose

/// LA LUMIÈRE SALUE LA CARTE POSÉE : un anneau de lueur blanc-or naît
/// sur les liserés du slot et s'évase en s'éteignant, avec un souffle
/// intérieur très bref — jamais un flash plein écran, un salut.
struct EclatDePose: View {
    var cadre: CGRect
    var began: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
            let t = tl.date.timeIntervalSince(began)
            if t >= 0, t < 0.75 {
                let p = min(t / 0.7, 1.0)
                let e = 1 - (1 - p) * (1 - p)
                ZStack {
                    RoundedRectangle(cornerRadius: 8 + 10 * e,
                                     style: .continuous)
                        .stroke(Color(red: 1, green: 0.86, blue: 0.6)
                            .opacity(0.85 * (1 - p)),
                            lineWidth: 1.6 + 1.4 * (1 - p))
                        .frame(width: cadre.width + 36 * e,
                               height: cadre.height + 36 * e)
                        .blur(radius: 0.6 + 3 * e)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.white.opacity(0.20 * (1 - e)))
                        .frame(width: cadre.width, height: cadre.height)
                        .blur(radius: 6)
                }
                .position(x: cadre.midX, y: cadre.midY)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: La bouffée du contact

/// L'atterrissage souffle la poussière du slot : huit volutes très
/// fines qui s'écartent et s'évanouissent (0,6 s), dans le langage de
/// la fumée d'envol.
struct FumeeDArrivee: View {
    var centre: CGPoint
    var began: Date

    private func fract(_ x: Double) -> Double { x - x.rounded(.down) }
    private func r(_ i: Int, _ s: Double) -> Double {
        fract(sin(Double(i) * 127.1 + s * 311.7) * 43758.5453)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { tl in
            let t = tl.date.timeIntervalSince(began)
            Canvas { ctx, _ in
                guard t >= 0, t < 0.65 else { return }
                let p = t / 0.65
                for i in 0 ..< 8 {
                    let ang = Double(i) / 8 * 2 * .pi + r(i, 1) * 0.8
                    let dist = (14 + 26 * r(i, 2)) * sstepD(0, 1, p)
                    let x = centre.x + cos(ang) * dist * 1.25
                    let y = centre.y + sin(ang) * dist * 0.7 - 8 * p
                    let rad = 5 + 26 * p * (0.6 + 0.4 * r(i, 3))
                    let op = 0.10 * (1 - p) * (1 - p)
                    ctx.opacity = op
                    ctx.fill(Ellipse().path(in: CGRect(
                        x: x - rad / 2, y: y - rad / 2,
                        width: rad, height: rad)), with: .color(.white))
                }
            }
            .blur(radius: 6)
        }
        .allowsHitTesting(false)
    }
}
