import SwiftUI

// MARK: - FouettagePilule — les hooks du banc du LOT 2 (pivot 04-09)
//
// L'ancien banc (`FouettageNav.swift`) fouettait LE REPLI de la nav :
// mini ⇄ déployée, le pan de bande, la dalle du player. Tout ça est MORT
// au pivot du 04-09. Ce banc-ci fouette ce qui l'a remplacé :
//   · la nav FIXE à trois onglets (elle ne doit JAMAIS redevenir des points) ;
//   · la PILULE VAGABONDE (pose, porte de l'île, tap qui ouvre) ;
//   · le GRAND PLAYER (il s'ouvre, et il s'ouvre AUSSI depuis l'île) ;
//   · le registre de visibilité de la nav (elle doit REVENIR).
//
// TOUT est éteint hors `-fouettagePilule` : zéro élément d'accessibilité,
// zéro overlay, zéro écriture en prod. La sonde EXPOSE l'état, elle ne
// l'écrit jamais — ce sont les touchers XCUITest qui agissent.

enum FouettagePilule {
    static let actif = CommandLine.arguments.contains("-fouettagePilule")
}

/// Les faits que les singletons ne portent pas — et les COMPTEURS, parce
/// qu'un état final propre ne prouve pas l'absence d'un flash pendant le
/// geste : seul un compteur côté app le voit.
@Observable
final class FouettagePiluleFaits {
    static let shared = FouettagePiluleFaits()
    private init() {}
    /// Posé par la marque de bande (PageCard sait `enSeance`).
    var enSeance = false
    /// Combien de fois le GRAND player est apparu depuis le lancement.
    var nbGrandPlayer = 0
    /// Combien de fois la pilule est entrée dans l'île.
    var nbEntreesIle = 0
    /// La nav a-t-elle été vue CACHÉE au moins une fois (registre).
    var navFutCachee = false
    /// Combien de fois un DRAG de pastille a COMMENCÉ. Décisif : si ce
    /// compteur reste à 0 alors que la pastille reçoit les taps, le geste
    /// est mangé AVANT elle (un ancêtre le revendique) — ça ne se déduit
    /// pas d'un état final.
    var nbDrag = 0
    /// Combien de fois `onChanged` du drag de la pastille a été APPELÉ —
    /// compté DANS le geste (patch F), le seul témoin qui ne se déduit pas.
    var nbChanged = 0
    /// Combien de fois le TAP de la pastille a été reconnu.
    var nbTap = 0
    /// Un geste posé À L'EXTÉRIEUR de tout le corps de la pastille : il
    /// dit si le toucher ATTEINT seulement la vue, avant de se demander
    /// pourquoi le geste intérieur ne le voit pas.
    var nbDehors = 0
}

/// LA SONDE D'ÉTAT — overlay de la racine, grain 2 pt intouchable.
struct FouettagePiluleSonde: View {
    var body: some View {
        if FouettagePilule.actif { FouettagePiluleSondeCorps() }
    }
}

private struct FouettagePiluleSondeCorps: View {
    let nav = NavEtat.shared
    let pilule = PiluleEtat.shared
    let faits = FouettagePiluleFaits.shared

    private var valeur: String {
        "navVis=\(nav.bandeVisiblePubliee ? 1 : 0);"
            + "navH=\(Int(nav.navH));"
            + "mini=\(nav.mini ? 1 : 0);"
            + "page=\(nav.page.rawValue);"
            + "seance=\(faits.enSeance ? 1 : 0);"
            + "dansIle=\(pilule.dansIle ? 1 : 0);"
            + "enDrag=\(pilule.enDrag ? 1 : 0);"
            + "enVol=\(pilule.enVol ? 1 : 0);"
            + "yRatio=\(String(format: "%.3f", pilule.yRatio));"
            + "gp=\(faits.nbGrandPlayer);"
            + "ile=\(faits.nbEntreesIle);"
            + "navCachee=\(faits.navFutCachee ? 1 : 0);"
            + "drag=\(faits.nbDrag);"
            + "chg=\(faits.nbChanged);"
            + "tap=\(faits.nbTap);"
            + "out=\(faits.nbDehors)"
    }

    var body: some View {
        Color.black.opacity(0.05)
            .frame(width: 2, height: 2)
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityIdentifier("fouettage-pilule-sonde")
            .accessibilityValue(valeur)
            // Les compteurs — écrits HORS body, jamais remis à zéro :
            // chaque cas relance l'app, ils naissent frais.
            .onChange(of: pilule.dansIle) { _, d in
                if d { FouettagePiluleFaits.shared.nbEntreesIle += 1 }
            }
            .onChange(of: pilule.enDrag) { _, d in
                if d { FouettagePiluleFaits.shared.nbDrag += 1 }
            }
            .onChange(of: nav.bandeVisiblePubliee) { _, v in
                if !v { FouettagePiluleFaits.shared.navFutCachee = true }
            }
    }
}

/// LA MARQUE DE BANDE — l'identifiant sur la bande de PageCard (la page
/// VISIBLE seulement ; jamais un `if` structurel sur `ongletCache`, qui
/// recréerait la bande à chaque bascule d'onglet) et la publication de
/// `enSeance`.
struct FouettageBandeMarque: ViewModifier {
    var enSeance: Bool
    @Environment(\.ongletCache) private var ongletCache

    func body(content: Content) -> some View {
        if FouettagePilule.actif {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(ongletCache ? "" : "fouettage-bande")
                .onChange(of: enSeance, initial: true) { _, s in
                    guard !ongletCache else { return }
                    if FouettagePiluleFaits.shared.enSeance != s {
                        FouettagePiluleFaits.shared.enSeance = s
                    }
                }
        } else { content }
    }
}

/// LA MARQUE DE LA PILULE — son rect VISIBLE, c'est ce que le doigt vise.
/// (On ne calcule JAMAIS la position de la pilule côté test : on la LIT.
///  C'est toute la différence entre une sonde et un juge qui affirme.)
struct FouettagePiluleMarque: ViewModifier {
    func body(content: Content) -> some View {
        if FouettagePilule.actif {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("fouettage-pilule")
        } else { content }
    }
}

/// LA MARQUE DE L'ÎLE — présence + rect.
struct FouettageIleMarque: ViewModifier {
    func body(content: Content) -> some View {
        if FouettagePilule.actif {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("fouettage-ile")
        } else { content }
    }
}

/// LA MARQUE DU GRAND PLAYER — sa seule PRÉSENCE est le fait qu'on teste
/// (« pas d'overlay » était le verdict). Le compteur monte à la naissance.
struct FouettageGrandPlayerMarque: ViewModifier {
    func body(content: Content) -> some View {
        if FouettagePilule.actif {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("fouettage-grand-player")
                .onAppear { FouettagePiluleFaits.shared.nbGrandPlayer += 1 }
        } else { content }
    }
}
