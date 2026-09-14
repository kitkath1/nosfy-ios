import SwiftUI

// MARK: - LE RYTHME DE L'ÉCRAN (05-09) — un onglet qu'on ne regarde pas se tait
//
// CE QUI A ÉTÉ MESURÉ SUR SON IPHONE 15, et qui a conduit ici :
//   · écran nu, aucune page ............  1 % de processeur
//   · n'importe quelle page, immobile ... 27 % (jusqu'à 39 % sur le Profil)
//   · corps de la page recalculé ........ 0 fois par seconde
// SwiftUI ne refaisait AUCUN calcul de mise en page — et pourtant ça brûlait.
// La cause, comptée horloge par horloge sur l'accueil au repos, personne n'y
// touchant :
//   · les deux widgets ....... 18 battements/seconde
//   · les galets du chemin ... 14
//   · la nappe du menu ....... 10
// Chaque battement oblige le téléphone à RECOMPOSER tout l'écran à travers le
// verre. C'est ça qui chauffe — verdict d'usage : « ça chauffe avant ET
// pendant la séance », alors que la cadence, elle, tenait 60.
//
// Sont innocents, et mesurés tels : le fond vidéo (image de pose : 27 % contre
// 27 %), le ciel nébuleuse (plus monté sur les pages actuelles), le gyroscope,
// le galet seul, la pièce, l'invite, le grain.
//
// ⚠️ LA RÈGLE, TRANCHÉE PAR KATHRYN LE 05-09 : « OUI, ELLE RESPIRE EN
// PERMANENCE. » La page qu'on REGARDE ne se fige jamais — c'est son dessin, et
// il ne se négocie pas. On ne gagne donc QUE sur ce qui ne se voit pas :
//   ① les onglets qu'on ne regarde pas (le TabView garde les trois pages
//      montées — sans porte, les trois animent en même temps, pour rien) ;
//   ② les cadences invisibles à l'œil (une horloge à la cadence de l'écran sur
//      un objet qui respire en quatre secondes ne se lit pas plus fin à 120 Hz
//      qu'à 30 — c'est trois images sur quatre rendues pour rien).
// Tout ce qui toucherait à l'allure attend son verdict.

enum RythmeBanc {
    /// `-sansRepos` : le mécanisme débranché (les trois onglets animent en
    /// même temps, comme avant). C'est le barreau de l'A/B.
    static let eteint = CommandLine.arguments.contains("-sansRepos")
}

@Observable
final class RythmeEcran {
    static let shared = RythmeEcran()
    private init() {}

    /// L'onglet AFFICHÉ — posé par le châssis, jamais deviné.
    /// ⚠️ PAS de `@ObservationIgnored`, et c'est PORTEUR : c'est son
    /// observation qui fait qu'un `dort()` lu dans un body réveille la vue
    /// à la bascule d'onglet — et que les `.task(id:)` des feuilles animées
    /// (ChevronAppel, PointMois, …) se ré-arment. Il ne change qu'à la
    /// bascule — deux fois, pas soixante par seconde : l'observer ne coûte
    /// rien. Une session qui « réparerait » en posant l'attribut rendrait
    /// toutes les portes sourdes.
    var ongletActif = "home"

    /// ⚠️ LE PAS COMMUN — LA TROUVAILLE DU 05-09, et celle qui garde le
    /// dessin intact.
    ///
    /// Mesuré sur son iPhone 15, accueil immobile, personne n'y touchant :
    ///   la home 32 battements/s · les widgets 30 · la nappe 16 · les
    ///   galets 15 — soit ≈ 93 par seconde.
    /// Ces quatre familles battaient à des cadences DIFFÉRENTES (12, 20,
    /// 24, 30 Hz et même la cadence de l'écran). Deux horloges désaccordées
    /// ne tombent pas sur les mêmes images : leurs redessins s'ajoutent au
    /// lieu de se confondre, et le compositeur repasse sur tout l'écran —
    /// à travers le verre — presque à chaque image.
    ///
    /// Le remède ne coûte AUCUN dessin : elles battent désormais TOUTES sur
    /// le même pas. Tout continue de respirer (verdict Kathryn : « oui, elle
    /// respire en permanence »), mais les battements se confondent — une
    /// recomposition au lieu de quatre.
    ///
    /// 20 Hz : la plus lente des quatre cadences d'origine était 12 Hz, la
    /// plus rapide 30. Vingt est au-dessus de ce que l'œil distingue sur une
    /// respiration de plusieurs secondes, et divise le compte par quatre.
    static let pas: Double = 1.0 / 20.0

    /// LA PORTE DES HORLOGES DE L'ACCUEIL — widgets, galets, nappe, route.
    static var dortHome: Bool { dort("home") }

    /// La porte d'une page quelconque, par son onglet.
    static func dort(_ onglet: String) -> Bool {
        if RythmeBanc.eteint { return false }
        return shared.ongletActif != onglet
    }
}
