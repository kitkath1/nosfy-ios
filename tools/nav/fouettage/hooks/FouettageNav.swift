import SwiftUI

// MARK: - FouettageNav — les hooks du banc de la nav (tools/nav/fouettage)
//
// TOUT est éteint hors `-fouettageNav` : zéro élément d'accessibilité,
// zéro overlay, zéro écriture en prod. La sonde EXPOSE l'état, elle ne
// l'écrit jamais — ce sont les touchers XCUITest qui agissent.

enum FouettageNav {
    static let actif = CommandLine.arguments.contains("-fouettageNav")
}

/// Les faits que les singletons ne portent pas, plus les COMPTEURS que
/// les assertions « jamais » exigent : un état final propre ne prouve
/// pas l'absence d'un flash d'ouverture PENDANT le geste — seul un
/// compteur côté app le voit (le geste XCUITest est synchrone, le test
/// ne peut pas échantillonner pendant).
@Observable
final class FouettageFaits {
    static let shared = FouettageFaits()
    private init() {}
    /// Posé par la marque (PageCard est la seule vue qui sait `enSeance`).
    var enSeance = false
    /// Le rect FENÊTRE de la bande VISIBLE — MESURÉ (03-09, banc
    /// adverse) : `frame(in:.global)` inclut l'offset des ancêtres, le
    /// rect est donc déjà le visible, RIEN à ajouter. C'est la géométrie
    /// que le banc VISE (celle que le doigt voit) — PAS la publication
    /// de prod `bandeRectFenetre`, qui la double-décale de 18 pt (défaut
    /// relevé au rapport). Observable : la sonde se ré-évalue.
    var bandeRect: CGRect = .zero
    /// Le maximum de `p` atteint depuis le lancement.
    var pMax: CGFloat = 0
    /// Combien de fois `ouvert` est passé à `true` depuis le lancement.
    var nbOuvertures = 0
}

/// LA SONDE D'ÉTAT — overlay de la racine, grain 2 pt intouchable.
struct FouettageNavSonde: View {
    var body: some View {
        if FouettageNav.actif { FouettageSondeCorps() }
    }
}

private struct FouettageSondeCorps: View {
    let nav = NavEtat.shared
    let player = PlayerEtat.shared
    let faits = FouettageFaits.shared
    private var valeur: String {
        "mini=\(nav.mini ? 1 : 0);"
            + "suivi=\(String(format: "%.2f", nav.suivi));"
            + "enSuivi=\(nav.enSuivi ? 1 : 0);"
            + "navH=\(Int(nav.navH));"
            + "page=\(nav.page.rawValue);"
            + "pMonte=\(player.monte ? 1 : 0);"
            + "pOuvert=\(player.ouvert ? 1 : 0);"
            + "p=\(String(format: "%.3f", player.p));"
            + "pMax=\(String(format: "%.3f", faits.pMax));"
            + "ouv=\(faits.nbOuvertures);"
            + "seance=\(faits.enSeance ? 1 : 0);"
            + "bandeY=\(Int(faits.bandeRect.minY.rounded()));"
            + "bandeH=\(Int(faits.bandeRect.height.rounded()))"
    }
    var body: some View {
        Color.black.opacity(0.05)
            .frame(width: 2, height: 2)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("fouettage-nav-sonde")
            .accessibilityValue(valeur)
            // Les compteurs — écrits HORS body, jamais remis à zéro :
            // chaque cas relance l'app, les compteurs naissent frais.
            .onChange(of: player.ouvert) { _, o in
                if o { FouettageFaits.shared.nbOuvertures += 1 }
            }
            .onChange(of: player.p) { _, p in
                if p > FouettageFaits.shared.pMax {
                    FouettageFaits.shared.pMax = p
                }
            }
    }
}

/// LA MARQUE DE BANDE — l'identifiant `fouettage-bande` sur la bande de
/// PageCard (la page VISIBLE seulement : les trois cachées portent un
/// identifiant vide — jamais un `if` structurel sur `ongletCache`, qui
/// recréerait la bande à chaque bascule d'onglet), le TÉMOIN blanc du
/// volet film (12×6 pt au haut-gauche de la bande), et la publication
/// de la géométrie visible vers `FouettageFaits`.
struct FouettageBandeMarque: ViewModifier {
    var enSeance: Bool
    @Environment(\.ongletCache) private var ongletCache
    func body(content: Content) -> some View {
        if FouettageNav.actif {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(ongletCache ? "" : "fouettage-bande")
                .overlay(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: 12, height: 6)
                        .padding(.leading, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .onGeometryChange(for: CGRect.self) {
                    $0.frame(in: .global)
                } action: { r in
                    // MESURÉ (03-09, banc adverse) : `frame(in:.global)`
                    // INCLUT l'offset des ancêtres — le rect est déjà le
                    // rect VISIBLE, on n'ajoute RIEN (le `+descente` de la
                    // publication de prod est un double compte, cf rapport).
                    guard !ongletCache else { return }
                    if FouettageFaits.shared.bandeRect != r {
                        FouettageFaits.shared.bandeRect = r
                    }
                    if FouettageFaits.shared.enSeance != enSeance {
                        FouettageFaits.shared.enSeance = enSeance
                    }
                }
                .onChange(of: ongletCache, initial: true) { _, cache in
                    guard !cache else { return }
                    if FouettageFaits.shared.enSeance != enSeance {
                        FouettageFaits.shared.enSeance = enSeance
                    }
                }
                .onChange(of: enSeance) { _, s in
                    guard !ongletCache else { return }
                    FouettageFaits.shared.enSeance = s
                }
        } else { content }
    }
}
