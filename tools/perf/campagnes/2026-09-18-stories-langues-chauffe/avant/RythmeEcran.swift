import SwiftUI

/// La Home garde son fond vidéo ; ses ornements n'animent plus en boucle.
/// Portée locale : les mêmes composants ailleurs gardent leur comportement.
/// `-decorHomeAnime` permet de retrouver le témoin pour une mesure ciblée.
private struct DecorHomeAuReposKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var decorHomeAuRepos: Bool {
        get { self[DecorHomeAuReposKey.self] }
        set { self[DecorHomeAuReposKey.self] = newValue }
    }
}

enum DecorHome {
    static let auRepos = !CommandLine.arguments.contains("-decorHomeAnime")
}

/// Le dessin reste posé quand iOS commence à limiter son budget thermique.
/// Ce groupe précis a tenu 60 callbacks/s, pire 17 ms, sur l'iPhone chaud :
/// fond vidéo en pose, fumée arrêtée, galets en pose, vie Route et lentilles
/// natives suspendues. Les gestes, textes et retours d'appui restent actifs.
/// Ce filet évite d'attendre l'état « serious » pour réagir ; il ne constitue
/// pas une preuve que le coût de l'ambiance à froid est résolu.
@Observable
final class ProtectionThermique {
    static let shared = ProtectionThermique()
    private(set) var ambianceAuRepos: Bool
    /// Le petit repère du chapitre reste disponible à « fair » ; il s'arrête
    /// à « serious », indépendamment du banc des grands décors.
    private(set) var appelAuRepos = ProcessInfo.processInfo.thermalState.rawValue >= 2
    @ObservationIgnored private var observation: NSObjectProtocol?
    private static let diagnosticDemande = CommandLine.arguments.contains("-sansProtectionThermique")
    @ObservationIgnored private var diagnosticActif = false

    private init() {
        ambianceAuRepos = !Self.diagnosticDemande && ProcessInfo.processInfo.thermalState != .nominal
        diagnosticActif = Self.diagnosticDemande
        observation = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.actualiser()
        }
        // Le câble a coupé après un profilage réel : la commande de retour
        // au rendu protégé n'a pas atteint le téléphone. Le banc ne doit
        // donc jamais pouvoir laisser la protection désactivée indéfiniment.
        if diagnosticActif {
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
                guard let self else { return }
                self.diagnosticActif = false
                self.actualiser()
                NavDiagnostic.noter("protection-thermique-banc-termine")
            }
        }
    }

    private func actualiser() {
        appelAuRepos = ProcessInfo.processInfo.thermalState.rawValue >= 2
        ambianceAuRepos = !diagnosticActif
            && ProcessInfo.processInfo.thermalState != .nominal
    }

    deinit {
        if let observation { NotificationCenter.default.removeObserver(observation) }
    }
}

// MARK: - LE RYTHME DE L'ÉCRAN (05-09) — un onglet qu'on ne regarde pas se tait
//
// CE QUI A ÉTÉ MESURÉ SUR SON IPHONE 15, et qui a conduit ici :
//   · écran nu, aucune page ............  1 % de processeur
//   · n'importe quelle page, immobile ... 27 % (jusqu'à 39 % sur le Profil)
//   · corps de la page recalculé ........ 0 fois par seconde
// Ce compteur ne couvre que le corps instrumenté : il n'exclut pas le
// travail des feuilles ou du graphe SwiftUI. Les 27–39 % sont le défaut,
// pas un budget acceptable. Comptage historique sur l'accueil au repos :
//   · les deux widgets ....... 18 battements/seconde
//   · les galets du chemin ... 14
//   · la nappe du menu ....... 10
// Chaque battement oblige le téléphone à RECOMPOSER tout l'écran à travers le
// verre. C'est ça qui chauffe — verdict d'usage : « ça chauffe avant ET
// pendant la séance », alors que la cadence, elle, tenait 60.
//
// Le témoin vidéo du 05-09 (27 % contre 27 % CPU) ne mesure ni le GPU ni
// l'énergie et ne l'innocente pas. Les essais à chaud du 14-09 améliorent
// les intervalles avec un fond en pose, sans attribution exclusive. Le ciel
// nébuleuse est archivé ; la fumée d'invitation actuelle reste distincte.
//
// ⚠️ LA RÈGLE, TRANCHÉE PAR KATHRYN LE 05-09 : « OUI, ELLE RESPIRE EN
// PERMANENCE. » La page qu'on REGARDE ne se fige jamais — c'est son dessin, et
// il ne se négocie pas. On ne gagne donc QUE sur ce qui ne se voit pas :
//   ① les onglets qu'on ne regarde pas (le TabView garde les trois pages
//      montées — sans porte, les trois animent en même temps, pour rien) ;
//   ② les cadences invisibles à l'œil (une horloge à la cadence de l'écran sur
//      un objet qui respire en quatre secondes ne se lit pas plus fin à 120 Hz
//      qu'à 30 — c'est trois images sur quatre rendues pour rien).
// L'ordre de réparer la chauffe du 14-09 autorise le filet thermique décrit
// plus haut ; il immobilise les décors à chaud. Cela ne valide ni leur coût
// à froid ni le rendu : voir tools/perf/CORRECTIF-CHAUFFE-2026-09-14.md.

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
    /// Une story plein écran recouvre les pages gardées dans le TabView.
    /// Chaque portail possède sa couverture : une fermeture tardive ne peut
    /// pas réveiller la Home sous une autre story.
    var stories: Set<UUID> = []
    var storyVisible: Bool { !stories.isEmpty }

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
        return shared.storyVisible || shared.ongletActif != onglet
    }
}
