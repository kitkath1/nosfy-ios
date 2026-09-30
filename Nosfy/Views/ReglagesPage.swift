import SwiftUI

// MARK: - L'ONGLET RÉGLAGES (30-09)
//
// Kathryn, 30-09 : « rajoute un onglet dans la navigation "Réglages" : langue
// choisie (ça change toute l'app), et en dessous format de départ de série :
// le user peut choisir le galet blanc ou le slider. Liquid glass, page noire,
// dégradé de blanc, type Apple minimal, très peu de texte. »
//
// SEPT MOTS en tout : Réglages · Langue · Français · English · Départ de
// série · Galet · Slider. Les deux choix se font au COMMUTATEUR OBSIDIENNE —
// la matière du slider, pouce élargi (« reprends le composant slider qu'on a
// partout, l'autre était trop cheap »).
//
// ⚠️ UNE PAGE IMMOBILE QUI NE COÛTE RIEN :
//   · le fond est un dégradé FIXE (aucune `TimelineView`, aucune vidéo) ;
//   · les deux commutateurs figent le temps de leur shader et n'animent que
//     leur pouce, pendant le ressort ;
//   · la vitrine montre des IMAGES : le vrai galet est une lentille géante qui
//     réfracte la page — une miniature vivante coûterait une page entière.
// Un seul verre (la vitrine), posé sur le dégradé : c'est lui qu'il réfracte.
//
// Barreaux : `-sansVitrine`, `-sansCommutateurShader`.
// Plan : tools/reglages/PLAN-REGLAGES-2026-09-30.md

struct ReglagesPage: View {
    @Binding var selection: WoopTab

    /// Le cache de la langue : quand il change, la racine fait renaître
    /// toute l'app (`.id(langueApp)`) — cette page comprise.
    @AppStorage(Langue.cle) private var langueCache: String = Langue.courante
    /// Le cache du départ : le serveur le rafraîchit, le commutateur le suit.
    @AppStorage(DepartSerie.cle) private var departCache: String = DepartSerie.defaut.rawValue

    @State private var choixLangue: Int
    @State private var choixDepart: Int
    @State private var langueEnAttente = false
    @State private var refusLangue = 0
    @State private var arrivee = false

    static let sansVitrine = CommandLine.arguments.contains("-sansVitrine")

    init(selection: Binding<WoopTab>) {
        _selection = selection
        _choixLangue = State(initialValue: Langue.courante == "en" ? 1 : 0)
        _choixDepart = State(initialValue: DepartSerie.courant == .galet ? 0 : 1)
    }

    var body: some View {
        ZStack(alignment: .top) {
            FondReglages()
            VStack(alignment: .leading, spacing: 0) {
                RangeeChips(retour: retour) { EmptyView() }
                titre
                sectionLangue
                    .padding(.top, 40)
                    .modifier(Arrivee(la: arrivee, rang: 0))
                sectionDepart
                    .padding(.top, 34)
                    .modifier(Arrivee(la: arrivee, rang: 1))
                Spacer(minLength: 0)
            }
        }
        .sensoryFeedback(.error, trigger: refusLangue)
        // L'animation vit dans `Arrivee` (une par rang, décalée) : un
        // `withAnimation` ici la doublerait.
        .onAppear { arrivee = true }
        .task { await DepartSerie.rafraichir() }
        .task { await banc() }
        .onChange(of: choixLangue) { _, i in changerLangue(i) }
        .onChange(of: choixDepart) { _, i in changerDepart(i) }
        .onChange(of: departCache) { _, d in suivreLeServeur(d) }
    }

    // MARK: Les pièces

    private var titre: some View {
        Text(L("Réglages", "Settings"))
            .font(.inter(34, .bold))
            .tracking(-1.1)
            .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.62)],
                                            startPoint: .top, endPoint: .bottom))
            .padding(.horizontal, 24)
            .padding(.top, 22)
            .accessibilityAddTraits(.isHeader)
    }

    private var sectionLangue: some View {
        VStack(alignment: .leading, spacing: 12) {
            Etiquette(texte: L("Langue", "Language"))
            CommutateurObsidienne(mots: ["Français", "English"],
                                  choix: $choixLangue,
                                  nom: L("Langue", "Language"),
                                  enAttente: langueEnAttente)
        }
        .padding(.horizontal, 20)
    }

    private var sectionDepart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Etiquette(texte: L("Départ de série", "Set start"))
            if !Self.sansVitrine {
                VitrineDepart(slider: choixDepart == 1)
            }
            CommutateurObsidienne(mots: [DepartSerie.galet.nom, DepartSerie.slider.nom],
                                  choix: $choixDepart,
                                  nom: L("Départ de série", "Set start"))
        }
        .padding(.horizontal, 20)
    }

    // MARK: Les actes

    private func retour() {
        withAnimation(.easeOut(duration: 0.3)) { selection = .home }
    }

    /// La langue part au serveur ; on l'ATTEND (le serveur gagne à chaque
    /// `home()`). Réussie, elle pose le cache et toute l'app renaît — cette
    /// page aussi, qui rejoue son arrivée. Refusée, le pouce revient.
    private func changerLangue(_ i: Int) {
        let code = i == 1 ? "en" : "fr"
        guard code != Langue.courante, !langueEnAttente else { return }
        let valeur = code == "en" ? "English" : "Français"
        langueEnAttente = true
        // LE TOASTER (30-09, « confirmation ou chargement ») : il naît en
        // cours, et la MÊME peau passe à la coche quand le serveur répond.
        FileAnnonces.shared.poserReglage(ReglageAnnonce(
            cle: "langue", titre: L("Langue", "Language"), valeur: valeur, etat: .enCours))
        Task { @MainActor in
            let ok = await Langue.changer(code)
            langueEnAttente = false
            // Réussie, l'app a déjà été reconstruite : `L()` parle la nouvelle
            // langue, et ce Task survit à la page qui l'a lancé.
            FileAnnonces.shared.poserReglage(ReglageAnnonce(
                cle: "langue", titre: L("Langue", "Language"), valeur: valeur,
                etat: ok ? .fait : .refuse))
            guard !ok else { return }
            refusLangue += 1
            withAnimation(CommutateurObsidienne.ressort) {
                choixLangue = Langue.courante == "en" ? 1 : 0
            }
        }
    }

    /// Le départ se voit tout de suite (le cache), le serveur suit — et le
    /// toaster dit où il en est.
    private func changerDepart(_ i: Int) {
        let d: DepartSerie = i == 0 ? .galet : .slider
        guard d != DepartSerie.courant else { return }
        let titre = L("Départ de série", "Set start")
        FileAnnonces.shared.poserReglage(ReglageAnnonce(
            cle: "depart", titre: titre, valeur: d.nom, etat: .enCours))
        Task { @MainActor in
            let e = await DepartSerie.choisir(d)
            FileAnnonces.shared.poserReglage(ReglageAnnonce(
                cle: "depart", titre: titre, valeur: d.nom,
                etat: e == .enAttente ? .enAttente : .fait))
        }
    }

    /// LES BANCS (le simulateur ne glisse pas) — des gestes de debug, sur
    /// leur banc seulement :
    ///   `-reglagesDepart galet|slider`  le commutateur du départ y va, 2 s après
    ///   `-reglagesLangue fr|en`         celui de la langue, UNE fois par
    ///                                   lancement (la page renaît ensuite)
    /// Avec `-sessionBanc`, les appels partent au compte de TEST : le journal
    /// `[depart-serie]` / `[langue]` dit ce que le serveur a répondu.
    private static var langueJouee = false
    private static func argument(_ cle: String) -> String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: cle), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    @MainActor private func banc() async {
        #if DEBUG
        if let d = Self.argument("-reglagesDepart") {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(CommutateurObsidienne.ressort) { choixDepart = d == "galet" ? 0 : 1 }
        }
        if let l = Self.argument("-reglagesLangue"), !Self.langueJouee {
            Self.langueJouee = true
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(CommutateurObsidienne.ressort) { choixLangue = l == "en" ? 1 : 0 }
        }
        #endif
    }

    /// Le serveur a répondu avec un autre choix (un autre iPhone, une
    /// réinstallation) : le pouce le rejoint.
    private func suivreLeServeur(_ brut: String) {
        let i = DepartSerie(rawValue: brut) == .galet ? 0 : 1
        guard i != choixDepart else { return }
        withAnimation(CommutateurObsidienne.ressort) { choixDepart = i }
    }
}

// MARK: - Le fond : noir, et une seule lune de blanc

/// Un dégradé FIXE — c'est lui que le verre de la vitrine réfracte : posé sur
/// du noir pur, le verre ne montrerait rien.
private struct FondReglages: View {
    var body: some View {
        ZStack {
            Color.black
            EllipticalGradient(stops: [
                .init(color: Color.white.opacity(0.17), location: 0.0),
                .init(color: Color.white.opacity(0.05), location: 0.42),
                .init(color: .clear, location: 1.0),
            ], center: UnitPoint(x: 0.5, y: -0.06),
               startRadiusFraction: 0, endRadiusFraction: 0.62)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - L'étiquette

/// La voix des petites légendes de l'app (« DERNIÈRE CHARGE » dans la fiche).
private struct Etiquette: View {
    let texte: String
    var body: some View {
        Text(texte.uppercased())
            .font(.inter(11, .semibold))
            .tracking(1.6)
            .foregroundStyle(Color.white.opacity(0.42))
            .padding(.leading, 4)
    }
}

// MARK: - L'arrivée

/// Les sections montent de 14 pt en fondu, décalées : un ressort unique à la
/// naissance de la page, aucune horloge.
private struct Arrivee: ViewModifier {
    let la: Bool
    let rang: Int
    func body(content: Content) -> some View {
        content
            .opacity(la ? 1 : 0)
            .offset(y: la ? 0 : 14)
            .animation(.spring(response: 0.7, dampingFraction: 0.86)
                .delay(0.09 * Double(rang)), value: la)
    }
}

// MARK: - La vitrine de verre

/// Ce que le choix LANCE, montré au lieu d'être nommé : le dôme du galet
/// blanc, ou le slider au repos. Une plaque de verre `.clear` (le verre validé,
/// sur le dégradé doux du fond) ; les aperçus vivent AU-DESSUS du verre, jamais
/// dessous (un contenu net sous le verre givre).
private struct VitrineDepart: View {
    let slider: Bool

    private static let forme = RoundedRectangle(cornerRadius: 26, style: .continuous)

    var body: some View {
        ZStack {
            if slider {
                ApercuSlider()
                    .transition(.opacity.combined(with: .offset(y: 10)))
            } else {
                ApercuGalet()
                    .transition(.opacity.combined(with: .offset(y: 10)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 132)
        .clipShape(Self.forme)
        .background { Color.clear.glassEffect(.clear, in: Self.forme) }
        .overlay {
            Self.forme.strokeBorder(LinearGradient(
                colors: [Color.white.opacity(0.30), Color.white.opacity(0.04)],
                startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: slider)
        .accessibilityHidden(true)
    }
}

/// Le vrai galet, en image : le dôme nacré de la fiche, capturé au simulateur
/// (asset `reglages-galet`). La lentille vivante réfracte la page entière —
/// on ne la monte pas pour une vignette.
private struct ApercuGalet: View {
    var body: some View {
        GeometryReader { g in
            Image("reglages-galet")
                .resizable()
                .scaledToFit()
                .frame(width: g.size.width)
                .position(x: g.size.width / 2,
                          y: g.size.height - g.size.width * Self.ratio / 2)
        }
    }
    /// Hauteur / largeur de l'image.
    static let ratio: CGFloat = 0.406
}

/// Le slider au repos, dans sa vraie matière (le shader du slider, temps
/// figé), avec sa flèche. Aucune horloge.
private struct ApercuSlider: View {
    private static let h: CGFloat = 56
    var body: some View {
        GeometryReader { g in
            let W = g.size.width - 40
            let pouceH = Self.h * 0.683
            let pouceW = pouceH * 1.68
            let x = Self.h * 0.151 + pouceW / 2
            ZStack(alignment: .topLeading) {
                MatiereObsidienne(x: x, demiLargeur: pouceW / 2, demiHauteur: pouceH / 2,
                                  largeur: W, hauteur: Self.h,
                                  plate: CommutateurObsidienne.sansShader)
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(Color.white.opacity(0.46))
                    .position(x: x, y: Self.h / 2)
            }
            .frame(width: W, height: Self.h)
            .position(x: g.size.width / 2, y: g.size.height / 2)
        }
    }
}
