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

// MARK: Le store de collection (v1 mémoire)

final class CollectionLune: ObservableObject {
    static let shared = CollectionLune()

    struct Obtenue: Identifiable {
        let id = UUID()
        let famille: String
        var count: Int
        let art: UIImage?
    }

    /// Les quatre registres, clés = la rareté de la forge.
    @Published private(set) var registres: [String: [Obtenue]] = [:]

    /// Ce que l'arrivée doit savoir AVANT de voler : le slot visé,
    /// doublon ou pas, nouveauté. Ne publie rien — `poser` publiera.
    func destination(rarete: String, famille: String)
        -> (slot: Int, doublon: Bool, nouvelle: Bool) {
        let liste = registres[rarete] ?? []
        if let i = liste.firstIndex(where: { $0.famille == famille }) {
            return (i, true, false)
        }
        return (liste.count, false, true)
    }

    /// La pose (à l'atterrissage) : la rangée se met à jour SOUS la
    /// bouffée de fumée.
    func poser(rarete: String, famille: String, art: UIImage?) {
        var liste = registres[rarete] ?? []
        if let i = liste.firstIndex(where: { $0.famille == famille }) {
            liste[i].count += 1
        } else {
            liste.append(Obtenue(famille: famille, count: 1, art: art))
        }
        registres[rarete] = liste
    }

    func collectees(_ rarete: String) -> [Obtenue] { registres[rarete] ?? [] }
}

// MARK: L'ordre d'arrivée (du Sacre vers le profil)

struct ArriveeCarte: Equatable {
    let rarete: String
    let famille: String
    let slot: Int
    let doublon: Bool
    let nouvelle: Bool

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
                                       ofType: "png") else { return nil }
        return UIImage(contentsOfFile: p)
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
            .frame(width: 80, height: 80 * 1672.0 / 941.0)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.8))
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
                + (cible.width - 66) * sstepD(0.55, 1.0, p)
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
                .frame(width: w, height: w * 1672.0 / 941.0)
                .clipShape(RoundedRectangle(
                    cornerRadius: 8 * w / 80, style: .continuous))
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
