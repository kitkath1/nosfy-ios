import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// LA CHAMBRE LONGUE — l'écran qui s'ouvre au DOUBLE tap d'un widget
//
// La card avait déjà sa chambre : celle du doigt qui la retourne. Celle-ci
// est la chambre LONGUE — elle se lit en descendant, elle a deux fenêtres,
// et elle meurt en transparence sur la home : on n'a jamais quitté l'écran.
//
// QUATRE LOIS TENUES ICI (payées ailleurs, écrites une fois) :
//
//  ① ELLE NE SE MONTE QUE QUAND ELLE EST OUVERTE. Une vue montée mais
//     cachée REND quand même — c'est le « rideau », et ça a fait chauffer
//     le téléphone. `ChambreLongueHote` ne contient rien tant que
//     `ChambreEtat.ouverte` est nil.
//
//  ② AUCUNE `TimelineView`. Tout ce qui bouge ici est une valeur ANIMABLE
//     (opacité, échelle, offset) : le système l'interpole sans jamais
//     reconstruire le contenu. Mesuré le 05-09 sur son iPhone : redessiner
//     coûte 33-38 % de processeur là où animer coûte 4-18 %. Les rares
//     respirations vivent dans une FEUILLE qui n'existe que chambre ouverte.
//
//  ③ LE VERRE NE SE REDIMENSIONNE PAS. La feuille se TRANSLATE au doigt ;
//     un verre aux bounds vivants devient un blur plat, définitivement.
//
//  ④ LE VIDE GARDE LE DESIGN. Quand une fenêtre n'a aucune séance, chaque
//     chambre dessine EXACTEMENT ses éléments — barres, courbe, cases,
//     portée, bilan — en gris, avec des zéros. Jamais une phrase « rien à
//     afficher » (verdict du 13-09). C'est la loi des cards (`vide: Bool` :
//     le design reste, la chaleur s'éteint), remontée d'un étage.
//
// Le barreau de mesure : `-sansChambre` la neutralise (elle ne s'ouvre
// plus) ; `-chambreLongue hiit|volume|peak|regularite` l'ouvre au lancement
// (le banc : le simulateur ne sait pas double-taper) ; `-chambreVide` lui
// fait lire le calcul sur aucune séance (la loi du vide, en DEBUG où la base
// se ressème seule) ; `-chambreBas` la fait défiler jusqu'en bas.
// ════════════════════════════════════════════════════════════════════════

// MARK: - L'identité d'une card, dans l'environnement

private struct WidgetKindKey: EnvironmentKey {
    static let defaultValue: WidgetKind? = nil
}

extension EnvironmentValues {
    /// Quelle card porte cette vue — posé par `CardsRangee`, lu par
    /// `CardTouche` pour savoir quelle chambre ouvrir.
    var widgetKind: WidgetKind? {
        get { self[WidgetKindKey.self] }
        set { self[WidgetKindKey.self] = newValue }
    }
}

// MARK: - L'état

@Observable
final class ChambreEtat {
    static let shared = ChambreEtat()

    enum Fenetre: String, CaseIterable {
        case semaine, mois
        var nom: String { self == .semaine ? L("Semaine", "Week") : L("Mois", "Month") }
    }

    /// nil = rien n'est monté. C'est la loi ① : l'hôte est vide au repos.
    private(set) var ouverte: WidgetKind?
    var fenetre: Fenetre = .semaine
    /// Publié par `SemaineStats.calcule` — hors de tout `body`. Sa valeur
    /// par défaut est l'état VIDE de toutes les chambres (loi ④).
    var donnees = ChambreDonnees()
    /// L'objectif hebdomadaire (3…10). LE SERVEUR LE TIENT (`user_prefs`,
    /// `definir_objectif` / `objectif_hebdo`) ; ceci est son cache, lu à
    /// l'ouverture de la chambre Regularity, écrit au choix (`choisir`).
    /// ⚠️ UNE SEULE CLÉ LOCALE (13-09, Kathryn : « que le nombre de séances
    /// soit bien lié avec l'onboarding ») : `Goal.cleHebdo` (« objectifHebdo »),
    /// celle que la home lit en `@AppStorage` pour « / N » et la phrase. La
    /// chambre, la home, les cards et le questionnaire de Nosfy (« Combien de
    /// fois par semaine ? » → `ChambreEtat.shared.choisir(n)`) parlent du même
    /// nombre — et le serveur le tient (`user_prefs`).
    var objectif: Int = UserDefaults.standard.object(forKey: Goal.cleHebdo) as? Int ?? 0 {
        didSet { UserDefaults.standard.set(objectif, forKey: Goal.cleHebdo) }
    }
    /// Un choix fait sans session (pas de réseau, pas de compte) attend ici
    /// et part à la prochaine ouverture connectée — jamais un objectif perdu.
    private var objectifEnAttente = UserDefaults.standard.bool(forKey: "woop.chambre.objectif.attente") {
        didSet { UserDefaults.standard.set(objectifEnAttente, forKey: "woop.chambre.objectif.attente") }
    }

    var objectifEffectif: Int { objectif > 0 ? objectif : donnees.objectif }

    /// Ce que le serveur a rendu, par chambre et par fenêtre (« hiit/semaine »),
    /// lu à l'ouverture. La source SEULEMENT quand le téléphone n'a aucune
    /// séance sur la fenêtre — la règle ② de `ChambreServeur`.
    private(set) var serveur: [String: ChambreFenetre] = [:]
    /// Le journal des appels (le banc le lit ; `print` le sort en console).
    private(set) var journal: [String] = []
    /// LA PHRASE DU BILAN, née au serveur (15-09, `bilan-periode`) — par
    /// fenêtre (« semaine » / « mois »), dans la langue du profil, sur les
    /// chiffres des widget_*. Lue à l'ouverture de la chambre HIIT (la seule
    /// qui porte un bloc bilan), EN FOND : la chambre ne l'attend jamais.
    /// Absente = la chambre garde sa phrase à règles — jamais un spinner.
    private(set) var bilanServeur: [String: String] = [:]

    /// La fenêtre que la chambre dessine : le téléphone s'il a des séances,
    /// sinon le serveur s'il en a, sinon le vide du téléphone (ses dates).
    func fenetreAffichee(_ kind: WidgetKind) -> ChambreFenetre {
        let tel = donnees.fenetre(fenetre)
        if !tel.vide { return tel }
        if let s = serveur["\(kind)/\(fenetre.rawValue)"], !s.vide { return s }
        // Vide des deux côtés : RIEN d'ailleurs ne s'affiche (la loi du vide, entière).
        return tel.sansRien()
    }

    /// OUBLIER LA PERSONNE (14-09, plan compte C2 — `Compte.effacerToutCeQuiEstAElle`) :
    /// ce que le serveur avait rendu pour ELLE (les fenêtres) et son objectif —
    /// la prochaine chambre repart vide, jamais avec les pics de la précédente.
    /// `objectif = 0` = « pas d'objectif choisi » (`objectifEffectif` retombe sur
    /// celui des données) ; la clé locale est RETIRÉE, pas écrite à 0 — la home
    /// lit `@AppStorage(Goal.cleHebdo)` avec son défaut, comme une install neuve.
    /// Le questionnaire de Nosfy du compte suivant en pose un neuf.
    func oublier() {
        serveur = [:]
        bilanServeur = [:]
        objectif = 0
        UserDefaults.standard.removeObject(forKey: Goal.cleHebdo)
        objectifEnAttente = false
        donnees = ChambreDonnees()
    }

    /// Le jeton du choix : il avance à chaque `choisir` — la chambre y accroche
    /// le petit check blanc (« pris en compte », 13-09), la home son recalcul.
    private(set) var objectifJeton = 0

    /// Le choix de l'objectif (le tap dans `ObjectifRangee`, le questionnaire
    /// de Nosfy, ou le banc) : la clé locale unique tout de suite, le serveur
    /// ensuite (`definir_objectif`), le check dans la chambre.
    func choisir(_ n: Int) {
        objectif = n
        objectifJeton += 1
        Task { @MainActor in await ecrireObjectif(n) }
    }

    private var serveurJoignable: Bool { WoopConfig.isConfigured && !ChambreServeur.neutralise }

    private func note(_ s: String) {
        journal.append(s)
        print("[chambre-serveur] \(s)")
    }

    @MainActor private func ecrireObjectif(_ n: Int) async {
        guard serveurJoignable else { return }
        do {
            let s = try await ChambreServeur.definirObjectif(n)
            objectif = s; objectifEnAttente = false
            note("definir_objectif(\(n)) → \(s)")
        } catch {
            objectifEnAttente = true
            note("definir_objectif(\(n)) ✗ \(error) — en attente")
        }
    }

    @MainActor private func lireObjectif() async {
        guard serveurJoignable else { return }
        if objectifEnAttente, objectif > 0 { await ecrireObjectif(objectif); return }
        do {
            let s = try await ChambreServeur.objectif()
            withAnimation(.easeOut(duration: 0.35)) { objectif = s }
            note("objectif_hebdo() → \(s)")
        } catch { note("objectif_hebdo() ✗ \(error)") }
    }

    @MainActor private func lireFenetres(_ kind: WidgetKind) async {
        guard serveurJoignable else { return }
        for fen in Fenetre.allCases {
            do {
                let json = try await ChambreServeur.fenetre(kind, fen)
                var f = ChambreDonnees().fenetre(fen)     // le vide daté du téléphone
                let n = ChambreServeur.traduire(kind, json: json, dans: &f)
                // Le brin d'animation du chargement (13-09) : le gris du vide
                // se réchauffe en un demi-souffle quand le serveur répond.
                withAnimation(.easeOut(duration: 0.55)) { serveur["\(kind)/\(fen.rawValue)"] = f }
                note("\(ChambreServeur.nomFonction(kind))(\(fen.rawValue)) → \(n) séance(s) · \(ChambreServeur.detail(kind, f))")
            } catch { note("\(ChambreServeur.nomFonction(kind))(\(fen.rawValue)) ✗ \(error)") }
        }
    }

    /// La phrase du bilan, les deux fenêtres — en fond, après les chiffres.
    @MainActor private func lireBilans() async {
        guard serveurJoignable else { return }
        for fen in Fenetre.allCases {
            let b = await ChambreServeur.bilan(fen)
            if let p = b.phrase {
                withAnimation(.easeOut(duration: 0.35)) { bilanServeur[fen.rawValue] = p }
                note("bilan-periode(\(fen.rawValue)) → « \(p) » (\(b.cache ? "cache" : (b.modele ?? "-")))")
            } else {
                note("bilan-periode(\(fen.rawValue)) → pas de phrase (\(b.raison ?? "?"))")
            }
        }
    }

    /// À l'ouverture : l'objectif (Regularity), puis les deux fenêtres — et
    /// pour HIIT la phrase du bilan, en fond (3-4 s la première fois).
    @MainActor private func lireServeur(_ kind: WidgetKind) async {
        if kind == .regularite {
            await lireObjectif()
            if let n = ChambreServeur.bancObjectif { await ecrireObjectif(n) }
        }
        await lireFenetres(kind)
        if kind == .hiitPeak { Task { @MainActor in await lireBilans() } }
    }

    private static let neutralisee = CommandLine.arguments.contains("-sansChambre")

    /// Le banc du VIDE : `-chambreVide` fait lire aux chambres le calcul sur
    /// AUCUNE séance. C'est la seule façon de voir la loi du vide en DEBUG :
    /// la base y est ressemée à chaque lancement (`seedDemoIfNoneFinished`
    /// sème sans argument dès que les 21 derniers jours sont clairsemés),
    /// désinstaller ne suffit donc pas — mesuré le 13-09, huit captures dont
    /// quatre « vides » identiques aux pleines.
    static let bancVide = CommandLine.arguments.contains("-chambreVide")

    /// Le banc du BAS : `-chambreBas` fait défiler le rouleau jusqu'en bas
    /// 1,4 s après l'ouverture — pour capturer le bilan, le podium, les
    /// records, que le premier écran ne montre pas.
    static let bancBas = CommandLine.arguments.contains("-chambreBas")

    /// Le banc : `-chambreLongue hiit` ouvre la chambre au lancement.
    static var bancKind: WidgetKind? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-chambreLongue"), a.indices.contains(i + 1)
        else { return nil }
        switch a[i + 1] {
        case "hiit": return .hiitPeak
        case "volume": return .volume
        case "peak": return .peakEffort
        case "regularite", "reg": return .regularite
        default: return nil
        }
    }

    func ouvrir(_ kind: WidgetKind?) {
        guard !Self.neutralisee, let kind else { return }
        fenetre = .semaine
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.44)) {
            ouverte = kind
        }
        Task { @MainActor in await lireServeur(kind) }
    }

    func fermer() {
        withAnimation(.timingCurve(0.30, 0, 0.40, 1, duration: 0.32)) {
            ouverte = nil
        }
    }
}

// MARK: - L'hôte : vide au repos

/// À poser en SATELLITE de la home (un `.overlay` sur `PageCard`, après elle) :
/// les satellites échappent aux `.animation(value:)` de `pageEnCard`, qui
/// neutralisent le `withAnimation` ambiant de tout ce qui vit dans le slot.
struct ChambreLongueHote: View {
    @State private var etat = ChambreEtat.shared

    var body: some View {
        ZStack {
            if let kind = etat.ouverte {
                ChambreLongue(kind: kind)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .identity))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(etat.ouverte != nil)
        .task {
            // le banc — une fois, après que la home a posé ses données
            guard let k = ChambreEtat.bancKind, etat.ouverte == nil else { return }
            try? await Task.sleep(for: .seconds(0.8))
            etat.ouvrir(k)
        }
    }
}

// MARK: - La feuille

struct ChambreLongue: View {
    let kind: WidgetKind

    @State private var etat = ChambreEtat.shared
    /// Le tirage du doigt : il TRANSLATE la feuille (loi ③).
    @State private var tirage: CGFloat = 0
    @State private var rouleauEnHaut = true
    @State private var priseAcceptee: Bool?
    @State private var fermeture = false
    @State private var hauteur: CGFloat = 0
    @GestureState private var doigtPose = false
    /// Regularity : la rangée d'objectif, ouverte par le héros.
    @State private var objectifOuvert = false
    /// Le check blanc « pris en compte », 1,6 s après un choix d'objectif.
    @State private var objectifCheck = false

    private var f: ChambreFenetre { etat.fenetreAffichee(kind) }

    var body: some View {
        ZStack(alignment: .top) {
            voile
            feuille
        }
        .accessibilityAction(.escape, fermer)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { hauteur = $0 }
        .allowsHitTesting(!fermeture)
        .onChange(of: doigtPose) { _, pose in
            guard !pose, !fermeture, priseAcceptee != nil else { return }
            priseAcceptee = nil
            withAnimation(.easeOut(duration: 0.22)) { tirage = 0 }
        }
    }

    private var voile: some View {
        Color.black.opacity(0.34 * (1 - min(tirage / 400, 1)))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: fermer)
    }

    private var feuille: some View {
        VStack(spacing: 0) {
            // L'en-tête se tire toujours ; le contenu seulement depuis son haut.
            VStack(spacing: 0) {
                grabber
                entete
            }
            .contentShape(Rectangle())
            .gesture(tirer(depuisContenu: false))
            rouleau
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(fondFeuille)
        .clipShape(formeFeuille)
        .overlay(alignment: .top) { ourlet }
        .padding(.top, 62)
        .offset(y: tirage)
    }

    private var formeFeuille: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: 38, bottomLeadingRadius: 0,
                               bottomTrailingRadius: 0, topTrailingRadius: 38,
                               style: .continuous)
    }

    /// Le dégradé DEMANDÉ : noir en haut, gris au milieu, transparent en bas —
    /// la home reste visible dessous, on n'a pas changé d'écran.
    private var fondFeuille: some View {
        LinearGradient(
            stops: [
                .init(color: Color(white: 0.078).opacity(0.985), location: 0.00),
                .init(color: Color(white: 0.055).opacity(0.965), location: 0.30),
                .init(color: Color(white: 0.039).opacity(0.830), location: 0.66),
                .init(color: Color(white: 0.031).opacity(0.360), location: 0.88),
                .init(color: Color(white: 0.024).opacity(0.000), location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom)
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
    }

    private var ourlet: some View {
        formeFeuille
            .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
            .allowsHitTesting(false)
    }

    private var grabber: some View {
        Capsule()
            .fill(Color.white.opacity(0.22))
            .frame(width: 36, height: 3.5)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture(perform: fermer)
    }

    // ── L'EN-TÊTE
    private var entete: some View {
        // Plus d'eyebrow « 03 · HIIT Peak » : « ça alourdit » (verdict du 13-09).
        // Le héros ouvre la feuille.
        VStack(alignment: .leading, spacing: 0) {
            heros.padding(.top, 6)
            if !ChambreTextes.sous(kind, f, etat.fenetre, objectif: etat.objectifEffectif).isEmpty {
                sousTitre.padding(.top, 7)
            }
            if kind == .regularite, objectifOuvert {
                ObjectifRangee(objectif: etat.objectifEffectif, check: objectifCheck) { n in
                    etat.choisir(n)
                }
                .padding(.top, 14)
                .onChange(of: etat.objectifJeton) { _, _ in
                    withAnimation(.easeOut(duration: 0.2)) { objectifCheck = true }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.easeIn(duration: 0.35)) { objectifCheck = false }
                    }
                }
            }
            selecteur.padding(.top, 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.bottom, 4)
        .chambreVide(f.vide && kind != .regularite)
    }

    private var heros: some View {
        let (v, u) = ChambreTextes.heros(kind, f, objectif: etat.objectifEffectif)
        return HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(v).font(.inter(40, .semibold)).encreMetal()
            Text(u).font(.system(size: 15)).foregroundStyle(CardTon.encreSourde)
            if kind == .regularite {
                // L'objectif se change ici : le glyphe du sélecteur d'iOS, pas
                // une phrase (verdict du 13-09 : « aère, pas de "tape pour" »).
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(CardTon.encreSourde)
                    .padding(.leading, 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard kind == .regularite else { return }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
            withAnimation(.easeOut(duration: 0.24)) { objectifOuvert.toggle() }
        }
    }

    private var sousTitre: some View {
        Text(ChambreTextes.sous(kind, f, etat.fenetre, objectif: etat.objectifEffectif))
            .font(.system(size: 12))
            .foregroundStyle(CardTon.encreSourde)
    }

    /// Le sélecteur : verre noir, deux segments. Il ne change QUE la fenêtre
    /// de calcul — jamais la page, jamais l'ordre des blocs.
    private var selecteur: some View {
        HStack(spacing: 0) {
            ForEach(ChambreEtat.Fenetre.allCases, id: \.self) { fen in
                Text(fen.nom)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(etat.fenetre == fen ? Color.white : CardTon.encreSourde)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 7)
                    .background {
                        if etat.fenetre == fen {
                            Capsule().fill(Color.white.opacity(0.10))
                        }
                    }
                    .contentShape(Capsule())
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
                        withAnimation(.easeOut(duration: 0.22)) { etat.fenetre = fen }
                    }
            }
        }
        .padding(3)
        .background {
            Capsule().fill(Color.white.opacity(0.045))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
        }
    }

    // ── LE ROULEAU
    private var rouleau: some View {
        ScrollView(showsIndicators: false) {
            ChambreContenu(kind: kind, f: f, fenetre: etat.fenetre)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 140)
                .background(ChambreRouleauSansRebond())
                // Le passage du vide (gris) aux données se fait en fondu — le
                // `.chambreVide` de chaque bloc (saturation, opacité) suit.
                .animation(.easeOut(duration: 0.55), value: f.vide)
        }
        // Le banc `-chambreBas` ouvre le rouleau par le bas (le simulateur ne
        // sait pas glisser ; les captures du bilan, du podium et des records
        // passent par là). Un `scrollTo` différé n'a rien fait le 13-09 :
        // l'ancre par défaut, elle, est posée avant le premier rendu.
        .defaultScrollAnchor(ChambreEtat.bancBas ? .bottom : .top)
        // Un booléen de frontière, pas une publication de chaque pixel défilé.
        .onScrollGeometryChange(for: Bool.self) { g in
            g.contentOffset.y + g.contentInsets.top <= 1
        } action: { _, enHaut in
            rouleauEnHaut = enHaut
        }
        .simultaneousGesture(tirer(depuisContenu: true))
        .mask {
            LinearGradient(stops: [
                .init(color: .clear, location: 0.00),
                .init(color: .black, location: 0.03),
                .init(color: .black, location: 0.84),
                .init(color: .clear, location: 1.00),
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    private func fermer() {
        fermer(vitesse: 0)
    }

    private func fermer(vitesse: CGFloat) {
        guard !fermeture else { return }
        fermeture = true
        // La sortie prolonge LE MÊME offset. La home et sa nav ne sont
        // réactivées qu'une fois la feuille hors écran, sans second « move ».
        let destination = max(hauteur, tirage + 1)
        let elan = max(0, vitesse) / max(1, destination - tirage)
        withAnimation(.interpolatingSpring(duration: 0.30, bounce: 0,
                                          initialVelocity: Double(elan)),
                      completionCriteria: .removed) {
            tirage = destination
        } completion: {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { etat.fermer() }
        }
    }

    private func tirer(depuisContenu: Bool) -> some Gesture {
        // L'espace de mesure reste fixe quand la feuille et son rouleau bougent.
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .updating($doigtPose) { _, pose, _ in pose = true }
            .onChanged { v in
                guard !fermeture else { return }
                if priseAcceptee == nil {
                    priseAcceptee = (!depuisContenu || rouleauEnHaut)
                        && v.translation.height > abs(v.translation.width)
                }
                guard priseAcceptee == true else { return }
                var transaction = Transaction(animation: nil)
                transaction.disablesAnimations = true
                withTransaction(transaction) { tirage = max(0, v.translation.height) }
            }
            .onEnded { v in
                let prise = priseAcceptee == true
                priseAcceptee = nil
                guard prise, !fermeture else { return }
                if tirage >= 72 || (tirage >= 16 && v.predictedEndTranslation.height > 180) {
                    fermer(vitesse: v.velocity.height)
                } else {
                    withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) { tirage = 0 }
                }
            }
    }
}

/// Le rouleau continue à défiler normalement, mais ne tire pas le contenu
/// élastiquement pendant que le même doigt descend toute la feuille.
/// Réglage local à CE ScrollView ; aucun delegate, timer ou geste supplémentaire.
private struct ChambreRouleauSansRebond: UIViewRepresentable {
    final class Repere: UIView {
        weak var rouleau: UIScrollView?
        private var rebondInitial = true

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { installer() }
        }

        func installer() {
            var parent = superview
            while let vue = parent {
                if let scroll = vue as? UIScrollView {
                    guard rouleau !== scroll else { return }
                    restituer()
                    rouleau = scroll
                    rebondInitial = scroll.bounces
                    scroll.bounces = false
                    return
                }
                parent = vue.superview
            }
        }

        func restituer() {
            rouleau?.bounces = rebondInitial
            rouleau = nil
        }
    }

    func makeUIView(context: Context) -> Repere {
        let vue = Repere()
        vue.isUserInteractionEnabled = false
        return vue
    }

    func updateUIView(_ vue: Repere, context: Context) { vue.installer() }

    static func dismantleUIView(_ vue: Repere, coordinator: ()) { vue.restituer() }
}

// MARK: - Le contenu, par widget

struct ChambreContenu: View {
    let kind: WidgetKind
    let f: ChambreFenetre
    let fenetre: ChambreEtat.Fenetre

    var body: some View {
        switch kind {
        case .hiitPeak:   ChambreHiit(f: f, fenetre: fenetre)
        case .volume:     ChambreVolume(f: f, fenetre: fenetre)
        case .peakEffort: ChambrePeak(f: f, fenetre: fenetre)
        case .regularite: ChambreRegularite(f: f, fenetre: fenetre)
        }
    }
}

// MARK: - Les textes de l'en-tête

enum ChambreTextes {
    static func nom(_ k: WidgetKind) -> String {
        switch k {
        case .regularite: return "Regularity"
        case .volume:     return "Volume"
        case .hiitPeak:   return "HIIT Peak"
        case .peakEffort: return "Peak Effort"
        }
    }

    static func heros(_ k: WidgetKind, _ f: ChambreFenetre, objectif: Int) -> (String, String) {
        switch k {
        case .regularite: return ("\(f.faites)", "/ \(objectif) séances")
        case .volume:     return (ChambreFmt.kg(f.volume).replacingOccurrences(of: " kg", with: ""), "kg")
        case .hiitPeak:   return (f.seancesHiit.isEmpty ? "0,0" : ChambreFmt.kmh(f.picMax), "km/h")
        case .peakEffort:
            // « 35 kg » → le chiffre en héros, l'unité en petit — comme les
            // trois autres chambres.
            let v = f.peak?.valeur ?? "0 kg"
            return v.hasSuffix(" kg") ? (String(v.dropLast(3)), "kg") : (v, "")
        }
    }

    static func sous(_ k: WidgetKind, _ f: ChambreFenetre,
                     _ fen: ChambreEtat.Fenetre, objectif: Int) -> String {
        let quand = fen == .semaine ? L("de la semaine", "this week") : L("des 30 derniers jours", "in the last 30 days")
        switch k {
        case .regularite:
            // Rien : « 8 / 5 séances » se suffit (verdict du 13-09 — « enlève
            // le sous-titre, tous ces mini-textes parasites »).
            return ""
        case .volume:     return L("Soulevés \(fen == .semaine ? "cette semaine" : "en 30 jours")", "Lifted \(fen == .semaine ? "this week" : "in 30 days")")
        case .hiitPeak:   return L("Meilleur intervalle \(quand)", "Top interval \(quand)")
        case .peakEffort: return f.peak.map { "\($0.titre) · × \($0.chambreHaut.split(separator: "×").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "")" }
                                 ?? ""
        }
    }
}

// MARK: - La robe partagée

enum ChambreTon {
    /// Le vert du bilan — la PREMIÈRE teinte hors rampe de l'app (demandée
    /// le 05-09), tenue basse en saturation, réservée à l'indicateur.
    static let vert = Color(red: 0.435, green: 0.812, blue: 0.592)
    /// Le rouge du recul : une braise, dans la rampe.
    static let rouge = Color(red: 1.00, green: 0.42, blue: 0.29)
    static let graphite = Color(white: 0.455)
    static let encre4 = Color(white: 0.353)
    static let encre5 = Color(white: 0.25)
    static let case_ = Color.white.opacity(0.045)
}

extension View {
    /// Le dégradé métallique des gros chiffres : #FFFFFF → #DCDCDC.
    func encreMetal() -> some View {
        foregroundStyle(LinearGradient(colors: [Color(white: 1.0), Color(white: 0.863)],
                                       startPoint: .top, endPoint: .bottom))
    }

    /// LOI ④ — le vide garde le design : même dessin, chaleur éteinte.
    func chambreVide(_ vide: Bool) -> some View {
        saturation(vide ? 0 : 1).opacity(vide ? 0.55 : 1)
    }
}

/// Le titre d'un bloc, à la Apple : un ou deux mots, jamais de capitales.
/// Le titre d'un bloc, et à droite un chiffre en monospace s'il y en a un.
/// Aucune mention de geste (« tape un jour ») : verdict du 13-09, l'écran
/// doit se comprendre seul — ce qui répond au doigt le montre par son état
/// (l'anneau du jour choisi, la marche qui s'éclaire, le cran au liseré).
struct BlocTitre: View {
    var texte: String
    var droite: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(texte).font(.inter(16.5, .semibold)).encreMetal()
            Spacer(minLength: 0)
            if let droite {
                Text(droite)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(CardTon.encreSourde)
            }
        }
    }
}

struct PorteeItem: Identifiable {
    let id = UUID()
    var valeur: String
    var libelle: String
    var chaud = false
    var unite: String? = nil
}

/// Une portée aérée : des chiffres, leurs libellés, de l'air — jamais une
/// grille à cases.
struct Portee: View {
    var items: [PorteeItem]
    var grand = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(items) { it in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        if it.chaud {
                            Text(it.valeur).font(.inter(grand ? 22 : 20, .semibold))
                                .foregroundStyle(CardTon.encreChaude)
                        } else {
                            Text(it.valeur).font(.inter(grand ? 22 : 20, .semibold)).encreMetal()
                        }
                        if let u = it.unite {
                            Text(u).font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(CardTon.encreSourde)
                        }
                    }
                    Text(it.libelle)
                        .font(.system(size: 10))
                        .foregroundStyle(ChambreTon.encre4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// Le chevron du bilan : ▲ vert / ▼ rouge — il porte le sens avant le chiffre.
struct ChevronIndic: View {
    var monte: Bool
    var body: some View {
        Triangle(haut: monte)
            .fill(monte ? ChambreTon.vert : ChambreTon.rouge)
            .frame(width: 8, height: 5)
    }
    struct Triangle: Shape {
        var haut: Bool
        func path(in r: CGRect) -> Path {
            var p = Path()
            if haut {
                p.move(to: CGPoint(x: r.midX, y: r.minY))
                p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
            } else {
                p.move(to: CGPoint(x: r.minX, y: r.minY))
                p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
                p.addLine(to: CGPoint(x: r.midX, y: r.maxY))
            }
            p.closeSubpath(); return p
        }
    }
}

struct BilanFait: Identifiable {
    let id = UUID()
    var nom: String
    var delta: String
    var detail: String
}

/// LE BILAN — la balance : ce qui monte, ce qui cède, et la phrase.
struct BilanVue: View {
    var titre: String
    var monte: [BilanFait]
    var recule: [BilanFait]
    var phrase: String
    var vide: Bool
    @State private var eph: String?
    @State private var jeton = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            BlocTitre(texte: titre)
            HStack(alignment: .top, spacing: 22) {
                colonne(L("En progrès", "Up"), monte, true)
                colonne(L("En recul", "Down"), recule, false)
            }
            .padding(.top, 4)
            phraseVue.padding(.top, 20)
        }
        .chambreVide(vide)
    }

    private func colonne(_ titre: String, _ faits: [BilanFait], _ haut: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titre).font(.system(size: 10)).foregroundStyle(ChambreTon.encre4)
                .padding(.bottom, 9)
            ForEach(faits.isEmpty ? Self.silhouette : faits) { fait in
                HStack {
                    Text(fait.nom).font(.system(size: 12)).foregroundStyle(CardTon.encreDouce)
                    Spacer(minLength: 6)
                    HStack(spacing: 6) {
                        if !vide, fait.nom != "—" { ChevronIndic(monte: haut) }
                        Text(fait.delta)
                            .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(vide || fait.nom == "—" ? ChambreTon.encre4 : (haut ? ChambreTon.vert : ChambreTon.rouge))
                    }
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { montrer(fait.detail) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let silhouette = [BilanFait(nom: "—", delta: "—", detail: ""),
                                     BilanFait(nom: "—", delta: "—", detail: "")]

    @ViewBuilder
    private var phraseVue: some View {
        if (eph ?? phrase).isEmpty { EmptyView() } else { phraseLigne }
    }

    private var phraseLigne: some View {
        HStack(alignment: .bottom) {
            Text(eph ?? phrase)
                .font(.system(size: 13.5))
                .foregroundStyle(eph == nil ? CardTon.encreDouce : CardTon.encreSourde)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeOut(duration: 0.2), value: eph)
            Spacer(minLength: 12)
            if eph == nil, !vide {
                HStack(spacing: 3) {
                    Text("◦").foregroundStyle(CardTon.ambre)
                    Text("Nosfy").tracking(1)
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(ChambreTon.encre5)
            }
        }
    }

    private func montrer(_ detail: String) {
        guard !vide, !detail.isEmpty else { return }
        jeton += 1; let mien = jeton
        eph = detail
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            if jeton == mien { eph = nil }
        }
    }
}

// MARK: - La grille du calendrier (la même grammaire partout)

/// Une case : le sticker en héros, le halo d'intensité dessous, la date
/// pour les jours vides — la cellule de la page Progress, remontée ici.
struct ChambreCase: View {
    var jour: ChambreJour
    var taille: CGFloat
    var selectionne = false
    /// La chambre HIIT écrit le pic dans la case au lieu du sticker.
    var montrerPic = false
    var stickers = true

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: taille * 0.28, style: .continuous)
    }
    private var actif: Bool { montrerPic ? jour.picHiit != nil : jour.fait }
    /// En mode pic : un jour couru SANS effort (pic sous 15 km/h) garde son
    /// chiffre mais n'a pas de halo — le halo dit l'effort, pas la présence
    /// (cohérence avec « Efforts · + de 15 km/h », 13-09).
    private var intensite: Int {
        guard montrerPic, let p = jour.picHiit else { return jour.intensite }
        return p >= 18 ? 3 : (p >= 17 ? 2 : (p >= SemaineStats.seuilEffort ? 1 : 0))
    }

    var body: some View {
        ZStack {
            forme.fill(Color.white.opacity(actif ? 0.055 : 0.04))
            if actif, intensite > 0 { halo }
            if montrerPic, let p = jour.picHiit {
                Text(ChambreFmt.kmh(p))
                    .font(.system(size: taille * 0.22, weight: .medium, design: .monospaced))
                    .foregroundStyle(intensite > 0 ? CardTon.encreDouce : ChambreTon.encre4)
            } else if stickers, jour.fait, let s = jour.sticker {
                if let s2 = jour.sticker2 {
                    Image(s2.asset).resizable().scaledToFit()
                        .frame(width: taille * 0.44, height: taille * 0.44)
                        .offset(x: -6, y: -2).opacity(0.9)
                }
                Image(s.asset).resizable().scaledToFit()
                    .frame(width: taille * 0.52, height: taille * 0.52)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            } else {
                Text("\(jour.numero)")
                    .font(.system(size: taille * 0.24))
                    .foregroundStyle(jour.horsFenetre || jour.futur ? ChambreTon.encre5 : ChambreTon.encre4)
            }
        }
        .frame(width: taille, height: taille)
        .opacity(jour.horsFenetre ? 0.34 : 1)
        .overlay {
            // Deux anneaux qui ne se confondent pas : le jour choisi est PLEIN
            // (liseré fort + un voile chaud), aujourd'hui n'est qu'un fil.
            if selectionne {
                forme.fill(CardTon.chaleur(0.78).opacity(0.09))
                forme.strokeBorder(CardTon.chaleur(0.78).opacity(0.92), lineWidth: 1.5)
            } else if jour.aujourdhui {
                forme.strokeBorder(CardTon.chaleur(0.72).opacity(0.5), lineWidth: 1)
            }
        }
        .contentShape(forme)
    }

    /// Trois niveaux : tiède · chaud · foyer — chaque dégradé fond vers
    /// l'alpha 0 de SA teinte, jamais vers un gris (le brun).
    private var halo: some View {
        let t: Double = intensite == 3 ? 0.78 : (intensite == 2 ? 0.55 : 0.30)
        let a: Double = intensite == 3 ? 0.38 : (intensite == 2 ? 0.26 : 0.17)
        let r: CGFloat = intensite == 3 ? taille * 0.62 : (intensite == 2 ? taille * 0.50 : taille * 0.40)
        return RadialGradient(colors: [CardTon.chaleur(t).opacity(a), CardTon.chaleur(t).opacity(0)],
                              center: UnitPoint(x: 0.5, y: 0.5), startRadius: 0, endRadius: r)
            .blendMode(.plusLighter)
    }
}

/// La grille : 7 lettres, puis 7 ou 35 cases. Une seule grammaire de
/// calendrier dans l'app.
struct ChambreGrille: View {
    var jours: [ChambreJour]
    var selection: Date? = nil
    var montrerPic = false
    var stickers = true
    var onTap: ((ChambreJour) -> Void)? = nil

    private static let lettres = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        GeometryReader { g in
            let gout: CGFloat = 8
            let s = (g.size.width - gout * 6) / 7
            let lignes = max(jours.count / 7, 1)
            VStack(spacing: gout) {
                HStack(spacing: gout) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(Self.lettres[i]).font(.system(size: 10.5))
                            .foregroundStyle(ChambreTon.encre4)
                            .frame(width: s)
                    }
                }
                ForEach(0..<lignes, id: \.self) { l in
                    HStack(spacing: gout) {
                        ForEach(0..<7, id: \.self) { c in
                            let i = l * 7 + c
                            if jours.indices.contains(i) {
                                let j = jours[i]
                                ChambreCase(jour: j, taille: s,
                                            selectionne: selection.map { Calendar.current.isDate($0, inSameDayAs: j.date) } ?? false,
                                            montrerPic: montrerPic, stickers: stickers)
                                    .onTapGesture {
                                        let actif = montrerPic ? j.picHiit != nil : j.fait
                                        guard actif else { return }
                                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6)
                                        onTap?(j)
                                    }
                            } else {
                                Color.clear.frame(width: s, height: s)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: hauteur)
    }

    private var hauteur: CGFloat {
        let lignes = CGFloat(max(jours.count / 7, 1))
        // largeur du rouleau 337 : case (337 − 48) / 7 ≈ 41,3
        let s: CGFloat = (337 - 48) / 7
        return 13 + 8 + lignes * s + (lignes - 1) * 8
    }
}

/// « Le halo dit l'intensité » : trois galets qui chauffent.
struct LegendeHalo: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { i in
                Circle().fill(CardTon.chaleur(0.30 + 0.24 * Double(i)).opacity(0.55 + 0.15 * Double(i)))
                    .frame(width: 6, height: 6)
            }
            Text("Le halo dit l'intensité").font(.system(size: 10.5))
                .foregroundStyle(CardTon.encreSourde).padding(.leading, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

/// La rangée d'objectif : 3 à 10, le choix en un geste.
struct ObjectifRangee: View {
    var objectif: Int
    var check = false
    var onChoix: (Int) -> Void
    var body: some View {
        // Pas d'étiquette : la rangée s'ouvre sous « 8 / 5 séances », elle se
        // comprend seule (verdict du 13-09).
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                ForEach(3...10, id: \.self) { n in
                    let on = n == objectif
                    Text("\(n)")
                        .font(.system(size: 13, weight: on ? .semibold : .medium))
                        .foregroundStyle(on ? Color(white: 0.043) : CardTon.encreSourde)
                        .frame(width: 31, height: 31)
                        .background {
                            if on {
                                Circle().fill(LinearGradient(colors: [CardTon.chaleur(1), CardTon.chaleur(0.75)],
                                                             startPoint: .top, endPoint: .bottom))
                            } else { Circle().fill(Color.white.opacity(0.045)) }
                        }
                        .contentShape(Circle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                            withAnimation(.easeOut(duration: 0.18)) { onChoix(n) }
                        }
                }
                // LE CHECK BLANC (13-09, « un petit check pour montrer que ça a
                // été pris en compte — blanc, plus joli ») : il naît au choix,
                // s'efface seul ; le serveur, lui, est écrit dans le même geste.
                if check {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.leading, 6)
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }
        }
    }
}

/// Un rang « exercice » : sticker, nom, sous-ligne, valeur, et la jauge de
/// 2 pt qui dit la part — aucun trait, aucune bordure.
struct RangExo: View {
    var sticker: WoopSticker?
    var nom: String
    var sous: String
    var valeur: String
    var part: Double
    var delta: String? = nil
    var vide = false
    /// La barre de part sous le rang (Volume : la part du total). Sans elle
    /// (Peak), rien ne souligne le rang — l'air sépare, jamais un trait.
    var barre = true

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 12) {
                if let s = sticker, !vide {
                    Image(s.asset).resizable().scaledToFit().frame(width: 22, height: 22)
                } else {
                    Circle().fill(Color.white.opacity(0.07)).frame(width: 22, height: 22)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(nom).font(.system(size: 13)).foregroundStyle(CardTon.encre)
                    Text(sous).font(.system(size: 10.5)).foregroundStyle(ChambreTon.encre4)
                }
                Spacer(minLength: 8)
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(valeur).font(.inter(14, .semibold)).encreMetal()
                    if let d = delta {
                        Text(d).font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(CardTon.encreChaude)
                    }
                }
            }
            if barre {
                GeometryReader { g in
                    Capsule().fill(Color.white.opacity(0.06)).frame(height: 2)
                    Capsule().fill(LinearGradient(colors: [CardTon.chaleur(0.40), CardTon.chaleur(0.60), CardTon.chaleur(0.78)],
                                                  startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(g.size.width * part, part > 0 ? 6 : 0), height: 2)
                }
                .frame(height: 2)
                .padding(.leading, 34)
            }
        }
        .padding(.vertical, barre ? 6 : 9)
    }
}

/// Une capsule de soie — la matière des courbes de la maison.
struct Capsule2: View {
    var couleur: Color
    var largeur: CGFloat
    var body: some View {
        Capsule().fill(couleur).frame(width: largeur, height: 2.2)
    }
}
