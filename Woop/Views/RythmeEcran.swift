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
    /// `@ObservationIgnored` : il ne doit réveiller aucune vue de lui-même ;
    /// ce sont les portes ci-dessous qui sont lues, et elles ne changent
    /// qu'à la bascule d'onglet — deux fois, pas soixante par seconde.
    var ongletActif = "home"

    /// LA PORTE DES HORLOGES DE L'ACCUEIL — widgets, galets, nappe, route.
    static var dortHome: Bool { dort("home") }

    /// La porte d'une page quelconque, par son onglet.
    static func dort(_ onglet: String) -> Bool {
        if RythmeBanc.eteint { return false }
        return shared.ongletActif != onglet
    }
}
