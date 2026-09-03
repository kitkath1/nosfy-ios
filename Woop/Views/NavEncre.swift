import SwiftUI

// MARK: - LA NAV D'ENCRE — le rail du bas (plan `tools/nav/PLAN-NAV-BANDE.md`)

/// LA NAV DU BAS, jalon 0 : le composant SEUL, jugé au banc `-navEncre`.
///
/// Elle n'est branchée NULLE PART dans l'app — c'est volontaire. Le plan
/// (§1) conclut que sa place définitive est une réserve de CHÂSSIS, pas la
/// bande de `PageCard` ; avant d'y toucher, on juge l'objet.
///
/// LA LOI QUI COMMANDE TOUT (plan §4.1-2) : **la réserve est constante, la
/// nav bouge dedans.** Le repli est un DESSIN — opacité et `offset` — jamais
/// un changement de layout : `hauteur` ne varie pas d'un point entre l'état
/// déployé et l'état replié, et aucune des trois cibles ne change de place
/// dans la mise en page (elles se déplacent à l'`offset`).
///
/// Sinon, mesuré dans le plan §3 : une bande à hauteur variable ferait
/// grandir la card de 52 pt EN CONTINU sous le doigt, et re-layouterait les
/// quatre pages à chaque image — la molette d'exos, le dôme de la fiche, la
/// pill `AVPlayerLayer` de progress et le galet du menu se mettraient tous à
/// voyager.
/// QUATRE destinations — corrigé par Kathryn le 02-09 (« on voit les 4 points »).
/// Le code a bien quatre onglets (`WoopTab`, WoopApp.swift:121) ; une version
/// antérieure du plan en DÉDUISAIT trois, c'était une déduction et pas sa
/// demande. Le profil est un POINT de la nav — reste à trancher si la nav
/// s'affiche sur la page profil (plan §5).
enum NavDest: String, CaseIterable, Hashable {
    case home, exos, prog, profil

    var glyphe: String {
        switch self {
        case .home: "house.fill"
        case .exos: "figure.strengthtraining.functional"
        case .prog: "chart.line.uptrend.xyaxis"
        case .profil: "person"
        }
    }

    var nom: String {
        switch self {
        case .home: "Accueil"
        case .exos: "Entraînements"
        case .prog: "Progression"
        case .profil: "Profil"
        }
    }
}

/// L'ÉTAT PARTAGÉ (plan §4.3) — jamais un `@State` de vue.
///
/// ⚠️ La raison est mesurée : il y a QUATRE instances de `PageCard` (une par
/// page). Un repli piloté par un `@State` local donnerait quatre replis
/// distincts, donc quatre hauteurs de bande — et aucun outil du dépôt ne le
/// signalerait. L'état vit ici, une fois, pour tout le monde.
@Observable
final class NavEtat {
    static let shared = NavEtat()
    private init() {}

    /// L'endroit où l'on est.
    var page: NavDest = .home

    // ════════════════════════════════════════════════════════════════════
    // DEUX RÉGIMES, ET C'EST TOUTE LA MÉCANIQUE (plan §0bis).
    //
    // Kathryn : « la mini nav en mode point ALLONGE la card — si je drag
    // légèrement au niveau de la nav, la card descend et ils deviennent des
    // points ». La card gagne donc VRAIMENT la hauteur : c'est un changement
    // de LAYOUT, voulu.
    //
    // Mais il ne doit pas arriver SOUS LE DOIGT, à 60 Hz : mesuré au plan
    // §3, un layout continu re-mesure les quatre pages à chaque image et
    // fait voyager la molette d'exos, le dôme de la fiche, la pill
    // `AVPlayerLayer` de progress et le galet du menu.
    //
    //   1. SOUS LE DOIGT → `suivi`, continu, ne touche AUCUN layout.
    //   2. AU RELÂCHER    → `mini`, DISCRET, commet la hauteur en 0,25 s.
    //
    // Le régime 2 existe déjà et il est éprouvé : c'est exactement ce que
    // fait `bandeVisible` quand le clavier sort sur Exercices
    // (PageCard.swift:184-185, `.animation(.easeInOut(duration: 0.25))`).
    // ════════════════════════════════════════════════════════════════════

    /// L'ÉTAT COMMIS, discret. C'est LUI — et lui seul — qui a le droit de
    /// changer la hauteur de la card.
    var mini = false

    /// LE SUIVI DU DOIGT, 0 → 1, continu et POSSÉDÉ (écrit SEC, comme `p`
    /// du player). Il ne pilote que du DESSIN : opacité et `offset`.
    var suivi: CGFloat = 0

    /// Le geste est en cours.
    var enSuivi = false

    /// LA VALEUR DE DESSIN : le doigt pendant le geste, l'état commis sinon.
    var r: CGFloat { enSuivi ? suivi : (mini ? 1 : 0) }

    /// L'horloge du chien de garde (plan §4.7 : un `DragGesture` peut mourir
    /// sans `onEnded` — payé sur la lune et sur le player).
    private var derniereFrame: Double = 0

    func saisir() {
        guard !enSuivi else { return }
        enSuivi = true
        armerChien()
    }

    /// Le suivi est RELATIF à l'ancre : le suivi absolu fait sauter la valeur
    /// au premier événement (§3.4nonies du plan player, repayé ici).
    func suivre(depuis ancre: CGFloat, delta: CGFloat) {
        saisir()
        let brut = ancre + delta / Self.course
        // Les butées vivent : au-delà de [0, 1] la sur-course est élastique
        // (tanh, ≤ 6 %) — le doigt sent une butée qui répond, pas un mur.
        if brut > 1 {
            suivi = 1 + 0.06 * tanh((brut - 1) * 6)
        } else if brut < 0 {
            suivi = 0.06 * tanh(brut * 6)
        } else {
            suivi = brut
        }
        derniereFrame = CACurrentMediaTime()
    }

    /// L'élan décide avant la position — et les seuils sont ASYMÉTRIQUES.
    ///
    /// « au léger drag elle se relève » (Kathryn, 02-09) : **remonter doit
    /// demander moins d'engagement que descendre**, sinon on s'enferme dans
    /// l'état mini. D'où deux jeux de seuils, et non un.
    ///
    /// ⚠️ Les chiffres ne sont PAS ceux du player (450 pt/s) : sa course fait
    /// tout l'écran, la nôtre fait 34 pt. À re-mesurer au doigt sur le
    /// TÉLÉPHONE, jamais au simulateur.
    func commettre(velocite: CGFloat) {
        enSuivi = false
        let cible: Bool
        if mini {
            // Depuis mini : un petit geste vers le haut suffit à relever.
            cible = !(velocite < -140 || suivi < 0.78)
        } else {
            // Depuis déployée : il faut un geste franc pour replier.
            cible = velocite > 300 || suivi > 0.45
        }
        poser(cible)
    }

    func basculer() { poser(!mini) }

    /// LE COMMIT DISCRET — le seul endroit du fichier qui change un layout.
    /// 0,25 s, la même durée que `bandeVisible` : la card gagne (ou rend) sa
    /// hauteur EN UNE FOIS, jamais sous le doigt.
    func poser(_ cible: Bool) {
        withAnimation(.easeInOut(duration: 0.25)) {
            mini = cible
            suivi = cible ? 1 : 0
        }
        Haptique.leger()
    }

    /// LE CHIEN : une horloge relue, jamais un minuteur posé par image.
    private func armerChien() {
        derniereFrame = CACurrentMediaTime()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.enSuivi else { return }
            if CACurrentMediaTime() - self.derniereFrame > 0.4 {
                // Le geste est mort sans `onEnded` : on COMMET à l'état
                // stable le plus proche — jamais un état inventé.
                self.commettre(velocite: 0)
            } else {
                self.armerChien()
            }
        }
    }

    /// La course du doigt qui fait un repli complet.
    static let course: CGFloat = 34
}

/// L'haptique, isolée pour rester muette au banc si besoin.
enum Haptique {
    static func leger() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - LE RAIL

// ════════════════════════════════════════════════════════════════════════
// DEUX COMPOSANTS DISTINCTS (demandé par Kathryn le 03-09), et un hôte.
//
//   · NavEncre — la nav DÉPLOYÉE : quatre glyphes d'encre.
//   · NavMini  — la MINI NAV : quatre points.
//   · NavBande — l'HÔTE : il porte la géométrie commune, la braise, et le
//     passage de l'un à l'autre.
//
// Pourquoi séparer plutôt qu'un seul objet qui se déforme : chacun des deux
// se dessine et se règle POUR LUI-MÊME, sans que le réglage de l'un tire
// sur l'autre. Le passage devient une affaire de l'hôte.
//
// ⚠️ MAIS LA BRAISE RESTE CHEZ L'HÔTE, et c'est essentiel : c'est **un seul
// point qui voyage**, jamais deux braises qui se relaient d'un composant à
// l'autre. Dupliquée, on perdrait la continuité qui fait tout le geste.
// ════════════════════════════════════════════════════════════════════════

/// LA GÉOMÉTRIE PARTAGÉE — pour que les glyphes et les points tombent aux
/// MÊMES abscisses, et que le passage n'ait rien à rattraper.
enum NavGeo {
    static let pasOuvert: CGFloat = 76
    static let pasReplie: CGFloat = 26
    static let cible: CGFloat = 44

    static var centre: CGFloat { CGFloat(NavDest.allCases.count - 1) / 2 }

    /// Le pas courant, interpolé par le serrage.
    static func pas(_ serrage: CGFloat) -> CGFloat {
        pasOuvert + (pasReplie - pasOuvert) * serrage
    }

    /// L'abscisse du rang `i`, depuis le centre.
    static func x(_ i: Int, _ serrage: CGFloat) -> CGFloat {
        (CGFloat(i) - centre) * pas(serrage)
    }

    /// Une rampe lissée, pour décaler les deux mouvements dans le temps.
    static func lisse(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        guard b > a else { return x >= b ? 1 : 0 }
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    static var rangs: [(i: Int, d: NavDest)] {
        Array(NavDest.allCases.enumerated()).map { (i: $0.offset, d: $0.element) }
    }
}

/// ① LA NAV DÉPLOYÉE — aucun mobilier : pas de capsule, pas de fond. Le noir
/// de la bande fait le conteneur, la page courante se lit à l'ENCRE (blanc
/// plein contre 34 %).
struct NavEncre: View {
    var etat = NavEtat.shared
    /// L'ENCRE, 1 → 0 : combien ce composant est encore présent. Pilotée par
    /// l'hôte, jamais lue depuis l'état — le composant ne connaît pas le repli.
    var encre: CGFloat = 1
    /// Le SERRAGE, 0 → 1 : de quel pas les glyphes se rapprochent.
    var serrage: CGFloat = 0
    /// L'action, remontée à l'hôte.
    var onChoix: (NavDest) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NavGeo.rangs, id: \.d) { rang in
                cible(rang.d, rang.i)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// UNE CIBLE. Ce n'est PAS un `Button` et pas un `.onTapGesture` : la
    /// forme tranchée du dépôt est `contentShape` + zone portée à 44 pt AVANT
    /// le geste + `highPriorityGesture` (`WorkoutPill.swift:79-84`). Un
    /// `Button` se fait annuler dès qu'un recognizer simultané reconnaît —
    /// c'est le « bouton Stop qui ne répond pas », payé le 26-08.
    ///
    /// ⚠️ `highPriorityGesture` ne bat que les ANCÊTRES : il gagne contre le
    /// drag de l'hôte (qui EST son ancêtre), jamais contre un frère.
    private func cible(_ d: NavDest, _ i: Int) -> some View {
        let actif = etat.page == d
        return Image(systemName: d.glyphe)
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(.white.opacity(actif ? 1 : 0.34))
            .frame(width: NavGeo.cible, height: NavGeo.cible)
            .contentShape(Rectangle())
            .highPriorityGesture(TapGesture().onEnded { onChoix(d) })
            .opacity(Double(encre))
            .scaleEffect(0.4 + 0.6 * encre)
            // LE DÉPLACEMENT EST UN OFFSET, PAS UN SPACING : rien ne se
            // re-layoute quand la nav se replie.
            .offset(x: (CGFloat(i) - NavGeo.centre)
                * (NavGeo.pas(serrage) - NavGeo.cible))
            .accessibilityLabel(d.nom)
            .accessibilityAddTraits(actif ? [.isSelected] : [])
    }
}

/// ② LA MINI NAV — les quatre points. Un objet à part entière, réglé POUR
/// LUI-MÊME : il ne cherche pas à ressembler à la nav en plus petit.
///
/// Le point de la page courante est ABSENT ici : c'est la braise de l'hôte
/// qui tient sa place, parce qu'elle voyage.
struct NavMini: View {
    var etat = NavEtat.shared
    /// 0 → 1 : combien les points sont présents.
    var presence: CGFloat = 0
    var serrage: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(NavGeo.rangs, id: \.d) { rang in
                Circle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 5, height: 5)
                    .opacity(Double(presence) * (etat.page == rang.d ? 0 : 1))
                    .offset(x: NavGeo.x(rang.i, serrage))
            }
        }
        .accessibilityHidden(true)
    }
}

/// ③ L'HÔTE — il porte la géométrie commune, LA BRAISE, et le passage d'un
/// composant à l'autre. C'est lui qui possède le geste ; les deux enfants ne
/// savent rien du repli, ils reçoivent des fractions.
struct NavBande: View {
    var etat = NavEtat.shared
    /// La hauteur utile. CONSTANTE — voir la loi en tête de fichier.
    var hauteur: CGFloat = 60

    /// La valeur de repli, bornée pour le DESSIN (la sur-course élastique ne
    /// doit pas faire déborder les interpolations).
    private var r: CGFloat { min(max(etat.r, 0), 1) }

    /// L'encre s'éteint AVANT que les glyphes ne se rapprochent : dans l'autre
    /// ordre, ils se font écraser par le bord qui arrive et ça « pompe ».
    /// D'où trois rampes décalées sur la MÊME valeur possédée.
    private var encre: CGFloat { 1 - NavGeo.lisse(0, 0.42, r) }
    private var serrage: CGFloat { NavGeo.lisse(0.16, 1, r) }
    private var presence: CGFloat { NavGeo.lisse(0.45, 1, r) }

    var body: some View {
        ZStack {
            NavMini(presence: presence, serrage: serrage)
            braise
            NavEncre(encre: encre, serrage: serrage, onChoix: aller)
        }
        .frame(maxWidth: .infinity)
        // LA HAUTEUR NE BOUGE JAMAIS (la loi de ce fichier).
        .frame(height: hauteur)
        // ⚠️ UNE SEULE forme tactile, PLEINE, au conteneur : sinon le doigt
        // qui tombe entre deux points traverse jusqu'à la page.
        .contentShape(Rectangle())
        .gesture(tirage)
    }

    /// LE DÉTAIL QUI FAIT TOUT, et la raison pour laquelle la braise vit chez
    /// l'hôte : **un seul** point qui voyage d'un endroit à l'autre — jamais
    /// deux braises qui se relaient d'un composant à l'autre. C'est ce qui
    /// donne la continuité.
    private var braise: some View {
        let i = NavDest.allCases.firstIndex(of: etat.page) ?? 0
        return Capsule()
            .fill(Color(red: 1, green: 0.54, blue: 0.18))
            .frame(width: 5 + 13 * serrage, height: 5)
            .shadow(color: Color(red: 1, green: 0.48, blue: 0.14).opacity(0.75),
                    radius: 5)
            .offset(x: NavGeo.x(i, serrage), y: 15 - 15 * serrage)
    }

    // MARK: le geste

    /// ⚠️ AU BANC SEULEMENT. À l'intégration, ce `DragGesture` DOIT devenir un
    /// pan maître UIKit unique posé sur la bande (plan §4ter) : entre frères
    /// il n'y a AUCUNE passation — celui qui a pris le doigt le garde jusqu'au
    /// lever, donc un repli poursuivi sur la dalle n'ouvrirait jamais le player.
    private var tirage: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                if !etat.enSuivi { ancre = etat.r }
                // Vers le BAS on replie : le delta est + vers le bas.
                etat.suivre(depuis: ancre, delta: v.translation.height)
            }
            .onEnded { v in
                etat.commettre(velocite: v.velocity.height)
            }
    }

    @State private var ancre: CGFloat = 0

    private func aller(_ d: NavDest) {
        guard etat.page != d else {
            // Un tap sur l'onglet courant, nav repliée, la redéploie.
            if etat.mini { etat.poser(false) }
            return
        }
        withAnimation(.timingCurve(0.32, 0.72, 0, 1, duration: 0.38)) {
            etat.page = d
        }
        Haptique.leger()
    }
}

// MARK: - LE BANC — `-navEncre`

/// Le drapeau vit AVEC son banc (le patron de `StopBanc` / `TapisBanc`) :
/// pas de doublon dans `WoopApp`, deux lignes de branchement et c'est tout.
enum NavBanc {
    static let actif = CommandLine.arguments.contains("-navEncre")

    /// `-navRegime mini|player|fermee` — naître dans un régime donné, pour
    /// les captures automatisées (le simulateur ne se tape pas en ligne de
    /// commande). Sans lui, on naît sur `nav`.
    static var regime: NavRegime {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-navRegime"), i + 1 < a.count,
              let r = NavRegime(rawValue: a[i + 1]) else { return .nav }
        return r
    }

    /// `-navPage home|exos|prog|profil` — naître SUR UNE VRAIE PAGE, la nav
    /// posée par-dessus. C'est le test « ça ne casse sur aucune page »
    /// (Kathryn, 03-09), automatisable en capture.
    static var page: NavDest? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-navPage"), i + 1 < a.count else { return nil }
        return NavDest(rawValue: a[i + 1])
    }
}

/// Les quatre régimes du bas, ceux qu'on compare au banc.
enum NavRegime: String, CaseIterable {
    case nav, mini, player, fermee

    var titre: String {
        switch self {
        case .nav: "nav"
        case .mini: "mini nav"
        case .player: "player + mini"
        case .fermee: "fermée"
        }
    }

    var quoi: String {
        switch self {
        case .nav:
            "La nav déployée : quatre glyphes, la braise sous le tien. "
                + "La bande prend 78 pt, la card s'arrête à son haut."
        case .mini:
            "Les quatre POINTS : la card S'ALLONGE de 52 pt vers le bas. "
                + "Sous le doigt rien ne se re-layoute — la hauteur ne se "
                + "commet qu'au relâcher, en 0,25 s."
        case .player:
            "Le player AU-DESSUS, la mini nav SOUS lui — l'ordre validé. "
                + "La bande empile la dalle (76) sur les points (24)."
        case .fermee:
            "Pendant l'exercice : la bande entière se retire et la card "
                + "reprend toute la place. C'est ta loi."
        }
    }

    /// LA COTE DE LA DALLE, par régime — un changement DISCRET, jamais sous
    /// le doigt. `bandeH = 18 + dockH + 2 − 18 = dockH + 2`.
    ///
    /// LA RÉFÉRENCE VALIDÉE (03-09) : en séance, la dalle du player passe
    /// AU-DESSUS et la mini nav vit SOUS elle — l'empilement que Kathryn a
    /// validé au banc. Coût assumé et connu : la dalle quitte sa position
    /// canonique de 24 pt en séance → la constante du fouettage et les cinq
    /// juges seront recalés à l'intégration (plan §6).
    var dockH: CGFloat {
        switch self {
        case .nav: 76        // bande 78
        case .mini: 24       // bande 26 → la card gagne 52 pt
        case .player: 100    // bande 102 — dalle 76 EMPILÉE sur points 24
        case .fermee: 76     // sans objet, la bande est masquée
        }
    }
}

/// LE BANC : la VRAIE `PageCard` de la home, avec les quatre régimes du bas —
/// nav, mini nav, player + mini nav, fermée. On juge les jeux d'animation
/// entre eux, et surtout **que le bas de la card ne bouge pas** entre les
/// trois premiers (plan §3 : c'est là que tout se casse).
///
/// ⚠️ Le banc MONTE `PageCard` mais ne la modifie pas — le fichier appartient
/// à la session home.
struct NavEncreLab: View {
    private var etat = NavEtat.shared
    @State private var regime: NavRegime = NavBanc.regime
    /// La fausse page affichée DANS la card — home, exos, fiche, progress.
    /// Toutes se lèvent pareil : ce sont des page cards (le composant
    /// travaillé pendant des jours), la nav vit dans la bande en dessous.
    @State private var pageBanc: NavDest = NavBanc.page ?? .home
    @State private var reperes = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            carte
            if reperes { trait }
            pupitre
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .onAppear { etat.mini = regime == .mini || regime == .player }
    }

    // MARK: la vraie robe

    private var carte: some View {
        // ⚠️ `dockH` est la SEULE valeur qui change la hauteur de la card,
        // et elle est DISCRÈTE : un régime, une cote, jamais sous le doigt.
        PageCard(dockH: regime.dockH,
                 enSeance: regime != .fermee,
                 bandeVisible: regime != .fermee,
                 luneAuDrag: false,
                 page: { contenu },
                 dalle: { bande })
    }

    /// LE CONTENU DE LA BANDE, par régime — LA RÉFÉRENCE VALIDÉE (03-09) :
    /// en séance, la dalle du player AU-DESSUS et la mini nav SOUS elle.
    @ViewBuilder
    private var bande: some View {
        switch regime {
        case .nav, .mini:
            NavBande(hauteur: regime.dockH)
        case .player:
            VStack(spacing: 0) {
                dallePlayer
                    .frame(height: 76)
                NavBande(hauteur: 24)
            }
        case .fermee:
            Color.clear
        }
    }

    /// La vraie dalle du player, montée comme sur Progress.
    private var dallePlayer: some View {
        WorkoutPill(exercise: ExerciseCatalog.all[0],
                    progress: 0.45,
                    docked: true,
                    lisere: false,
                    doneSeries: 2,
                    exoCount: 4,
                    jour: .now,
                    jourSticker: "sticker-flamme",
                    titreCourant: ExerciseCatalog.all[0].name)
    }

    // MARK: les fausses pages — des page cards, comme la fausse home

    @ViewBuilder
    private var contenu: some View {
        switch pageBanc {
        case .home: contenuHome
        case .exos: contenuExos
        case .profil: contenuFiche
        case .prog: contenuProg
        }
    }

    // ── LA FAUSSE HOME (la référence validée) ──

    private var contenuHome: some View {
        ZStack {
            aurore
            VStack(alignment: .leading, spacing: 16) {
                Text("Hello Kathryn,")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
                Text("you've done\n7 workouts\nthis week.")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                widgets
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 78)
        }
    }

    private var aurore: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 0.91, green: 0.35, blue: 0.16),
                                    Color(red: 0.55, green: 0.08, blue: 0.03),
                                    .clear],
                           center: .init(x: 0.2, y: 1.04),
                           startRadius: 8, endRadius: 460)
            RadialGradient(colors: [Color(red: 1, green: 0.45, blue: 0.15)
                                        .opacity(0.42), .clear],
                           center: .init(x: 0.62, y: 0.98),
                           startRadius: 4, endRadius: 300)
        }
        .ignoresSafeArea()
    }

    private var widgets: some View {
        HStack(spacing: 11) {
            widget("7", "/ 5", "Sessions this week")
            widget("8358", "kg", "Weekly volume")
        }
    }

    private func widget(_ v: String, _ u: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(v).font(.system(size: 25, weight: .bold))
                    .foregroundStyle(.white)
                Text(u).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.42))
            }
            Text(l).font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.46))
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.06), in:
                        RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous)
            .strokeBorder(.white.opacity(0.09)))
    }

    // ── LA FAUSSE PAGE EXERCICES — avec SA MOLETTE, clippée par la card ──

    private var contenuExos: some View {
        ZStack(alignment: .bottom) {
            fondSombre
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    rondOutil("chevron.left")
                    Text("Exercices")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    rondOutil("magnifyingglass")
                }
                grilleExos
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 66)
            molette
        }
    }

    private var grilleExos: some View {
        HStack(alignment: .top, spacing: 11) {
            VStack(spacing: 11) {
                carteExo("Développé couché à la barre", "Pectoraux, triceps", "BARRE")
                carteExo("Tirage vertical à la machine", "Grand dorsal", "MACHINE")
            }
            VStack(spacing: 11) {
                Color.clear.frame(height: 24)
                carteExo("Papillon à la machine", "Pectoraux", "MACHINE")
                carteExo("Tirage vers soi à la poulie", "Haut du dos", "POULIE")
            }
        }
    }

    private func carteExo(_ n: String, _ m: String, _ t: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.05))
                .frame(height: 64)
            Text(n).font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(m).font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.42))
            Text(t).font(.system(size: 8.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 7).padding(.vertical, 2.5)
                .background(.white.opacity(0.07), in: Capsule())
        }
        .padding(11)
        .background(.white.opacity(0.045), in:
                        RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// LA MOLETTE « Tout » — ancrée au bas de la card, à moitié clippée par
    /// son bord, comme sur la vraie page : quand la card se lève ou
    /// s'allonge, elle suit SON bord, jamais celui de l'écran.
    private var molette: some View {
        VStack(spacing: 8) {
            Text("Tout")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
            ZStack {
                Circle()
                    .strokeBorder(.white.opacity(0.22),
                                  style: .init(lineWidth: 10, dash: [1.5, 5.5]))
                    .frame(width: 168, height: 168)
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.23),
                                                  Color(white: 0.12),
                                                  Color(white: 0.07)],
                                         center: .init(x: 0.4, y: 0.3),
                                         startRadius: 4, endRadius: 70))
                    .overlay(Circle().strokeBorder(.white.opacity(0.11)))
                    .frame(width: 112, height: 112)
                Circle().fill(.white.opacity(0.7))
                    .frame(width: 4, height: 4)
                    .offset(y: -40)
            }
        }
        .offset(y: 72)
    }

    // ── LA FAUSSE FICHE EXERCICE — avec SON DÔME, clippé par la card ──

    private var contenuFiche: some View {
      GeometryReader { g in
        ZStack(alignment: .bottom) {
            fondFiche
            VStack(alignment: .leading, spacing: 0) {
                rondOutil("chevron.left")
                Spacer().frame(height: 14)
                Text("🪓").font(.system(size: 56))
                    .frame(maxWidth: .infinity)
                Spacer().frame(height: 16)
                Text("Woodchopper\npoulie haute")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                Text("Abdos • Obliques et transverse")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.44))
                    .padding(.top, 5)
                carteTraining
                    .padding(.top, 16)
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 62)
            dome
        }
        .frame(width: g.size.width, height: g.size.height)
        // ⚠️ LES COINS DU BAS RESPECTÉS comme les autres pages (verdict 03-09).
        // Le dôme est posé par un `.offset` qui le sort des bounds : on lit la
        // VRAIE taille du slot (GeometryReader, cadre non gonflé par un
        // ignoresSafeArea) et on taille à la robe (coins bas 30) — le crème
        // s'arrête net sur l'arrondi, le noir réapparaît dessous.
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0, bottomLeadingRadius: 30,
            bottomTrailingRadius: 30, topTrailingRadius: 0, style: .continuous))
      }
    }

    private var carteTraining: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(.black.opacity(0.5))
                Circle().strokeBorder(Color(red: 1, green: 0.63, blue: 0.3)
                    .opacity(0.5))
                Text("🔥").font(.system(size: 21))
            }
            .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 3) {
                Text("Sets 0").font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                Text("12 reps · 20 kg").font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.44))
            }
            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(colors: [Color(red: 0.18, green: 0.12, blue: 0.09),
                                    Color(red: 0.07, green: 0.05, blue: 0.04)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color(red: 1, green: 0.6, blue: 0.28).opacity(0.22)))
    }

    /// LE DÔME « Start exercise » — la moitié haute d'une grande ellipse
    /// crème, qui monte du bord bas de la card et suit ce bord.
    private var dome: some View {
        ZStack(alignment: .top) {
            Ellipse()
                .fill(RadialGradient(colors: [Color(red: 1, green: 0.99, blue: 0.96),
                                              Color(red: 0.94, green: 0.9, blue: 0.82),
                                              Color(red: 0.72, green: 0.66, blue: 0.57)],
                                     center: .init(x: 0.5, y: 1.1),
                                     startRadius: 30, endRadius: 320))
                .frame(width: 430, height: 260)
                .shadow(color: Color(red: 1, green: 0.6, blue: 0.28).opacity(0.5),
                        radius: 26, y: -8)
            VStack(spacing: 3) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(0.5)
                Text("Start exercise")
                    .font(.system(size: 14.5, weight: .medium))
            }
            .foregroundStyle(Color(red: 0.32, green: 0.26, blue: 0.2).opacity(0.7))
            .padding(.top, 22)
        }
        .offset(y: 150)
    }

    // ── LA FAUSSE PROGRESS — avec son calendrier et son bouton ──

    private var contenuProg: some View {
        ZStack {
            fondSombre
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    rondOutil("chevron.left")
                    Text("Progress")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                    Spacer()
                }
                blocSemaine
                blocCalendrier
                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 66)
        }
    }

    private var blocSemaine: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("This week.").font(.system(size: 19, weight: .bold))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                miniJour("31.", "AOÛT", "🍑")
                miniJour("1.", "SEPT", "🍑")
                miniJour("2.", "SEPT", "🍫")
                miniJour("3.", "SEPT", "🔥")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.05), in:
                        RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func miniJour(_ j: String, _ m: String, _ e: String) -> some View {
        VStack(spacing: 3) {
            Text(j).font(.system(size: 11, weight: .bold))
            Text(m).font(.system(size: 7, weight: .semibold)).opacity(0.5)
            Text(e).font(.system(size: 15))
        }
        .foregroundStyle(.white)
        .frame(width: 52, height: 62)
        .background(.white.opacity(0.06), in:
                        RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var blocCalendrier: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Septembre 2026")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
            grilleCal
            Capsule().fill(.black.opacity(0.65))
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                .overlay(Text("Voir dans le lecteur")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white))
                .frame(height: 46)
        }
        .padding(14)
        .background(.white.opacity(0.05), in:
                        RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var grilleCal: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
        return LazyVGrid(columns: cols, spacing: 5) {
            ForEach(1...21, id: \.self) { j in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(j <= 3 ? Color(red: 1, green: 0.48, blue: 0.18)
                        .opacity(0.22) : .white.opacity(0.05))
                    .frame(height: 26)
                    .overlay(Text("\(j)").font(.system(size: 9))
                        .foregroundStyle(.white.opacity(j <= 3 ? 0.9 : 0.42)))
            }
        }
    }

    // ── les fonds et petits outils ──

    private var fondSombre: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 0.55, green: 0.12, blue: 0.04)
                                        .opacity(0.5), .clear],
                           center: .init(x: 0.3, y: 1.05),
                           startRadius: 10, endRadius: 420)
        }
        .ignoresSafeArea()
    }

    private var fondFiche: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(red: 1, green: 0.55, blue: 0.2)
                                        .opacity(0.16), .clear],
                           center: .init(x: 0.5, y: 0),
                           startRadius: 10, endRadius: 340)
        }
        .ignoresSafeArea()
    }

    private func rondOutil(_ s: String) -> some View {
        Image(systemName: s)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .frame(width: 34, height: 34)
            .background(.white.opacity(0.06), in:
                            RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    // MARK: les repères et le pupitre

    /// LE TÉMOIN : le bas de la card. Il ne bouge qu'aux commits discrets.
    private var trait: some View {
        let bande = regime == .fermee ? 0 : regime.dockH + 2
        return GeometryReader { g in
            Rectangle()
                .fill(Color.red.opacity(0.55))
                .frame(height: 1)
                .overlay(alignment: .leading) {
                    Text("bas de card · bande \(Int(bande)) pt")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                        .padding(.leading, 8)
                        .offset(y: -8)
                }
                .position(x: g.size.width / 2, y: g.size.height - bande)
        }
        .allowsHitTesting(false)
    }

    private var pupitre: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(NavRegime.allCases, id: \.self) { r in
                    boutonRegime(r)
                }
                Spacer(minLength: 8)
                Button { reperes.toggle() } label: {
                    Image(systemName: reperes ? "ruler.fill" : "ruler")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 30, height: 26)
                        .background(.white.opacity(0.08), in: Capsule())
                }
            }
            HStack(spacing: 6) {
                boutonPage(.home, "home")
                boutonPage(.exos, "exos")
                boutonPage(.profil, "fiche")
                boutonPage(.prog, "prog")
                Spacer(minLength: 8)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    private func boutonRegime(_ r: NavRegime) -> some View {
        let on = regime == r
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { regime = r }
            etat.poser(r == .mini || r == .player)
        } label: {
            Text(r.titre)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(on ? .black : .white.opacity(0.66))
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(on ? Color.white : Color.white.opacity(0.1),
                            in: Capsule())
        }
    }

    private func boutonPage(_ d: NavDest, _ titre: String) -> some View {
        let on = pageBanc == d
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) { pageBanc = d }
        } label: {
            Text(titre)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(on ? .black : .white.opacity(0.6))
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(on ? Color.white : Color.white.opacity(0.1),
                            in: Capsule())
        }
    }
}

#Preview {
    NavEncreLab()
}
