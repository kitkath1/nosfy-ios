import SwiftData
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

    /// (La langue n'a pas besoin d'être observée ici : quand son cache change,
    /// la racine fait renaître toute l'app — `.id(langueApp)` — cette page
    /// comprise, qui relit `Langue.courante` à sa naissance.)
    /// Le cache du départ : le serveur le rafraîchit, le commutateur le suit.
    @AppStorage(DepartSerie.cle) private var departCache: String = DepartSerie.defaut.rawValue

    @State private var choixLangue: Int
    @State private var choixDepart: Int
    @State private var langueEnAttente = false
    @State private var refusLangue = 0
    @State private var arrivee = false
    @State private var showCGU = false

    static let sansVitrine = CommandLine.arguments.contains("-sansVitrine")

    init(selection: Binding<WoopTab>) {
        _selection = selection
        _choixLangue = State(initialValue: Langue.courante == "en" ? 1 : 0)
        _choixDepart = State(initialValue: DepartSerie.courant == .galet ? 0 : 1)
    }

    /// (05-10, TestFlight 87 : « pas le menu, que le chevron, et le
    /// comportement à la Spotify au drag vers le bas pour fermer »).
    @State private var tirage = TirageVersLeBas()

    var body: some View {
        ZStack(alignment: .top) {
            FondReglages()
            // Tout tient sur un iPhone 15 : pas de défilement, donc aucun
            // conflit entre le pouce des commutateurs et le pan d'une
            // ScrollView. Sur un écran plus court, la page défile.
            ViewThatFits(in: .vertical) {
                contenu
                ScrollView(showsIndicators: false) { contenu }
            }
            // Les conditions générales, en plein écran par-dessus (la même
            // page que le panneau du Profil ouvrait).
            if showCGU {
                CGUPage {
                    withAnimation(.easeOut(duration: 0.25)) { showCGU = false }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(tirage.geste(seuil: 120, onFermer: fermerParTirage), isEnabled: !showCGU)
        .modifier(DecalageTirage(etat: tirage, page: true))
        .modifier(NavCachee(jeton: "reglages", actif: selection == .settings))
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

    private var contenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            RangeeChips(retour: retour) { EmptyView() }
            titre
            sectionLangue
                .padding(.top, 32)
                .modifier(Arrivee(la: arrivee, rang: 0))
            sectionDepart
                .padding(.top, 28)
                .modifier(Arrivee(la: arrivee, rang: 1))
            // (06-10, « changer la couleur au-delà de la séance en cours ») :
            // le même choix que le petit bouton du cadran.
            SectionFlammes()
                .padding(.top, 28)
                .modifier(Arrivee(la: arrivee, rang: 1))
            // LE COMPTE (30-09, « rajoute en dessous la partie settings du
            // Profil, design type Apple, en lignes ») : ce que le panneau du
            // Profil portait — la personne, la déconnexion, les conditions,
            // la suppression. Les deux commutateurs au-dessus ne bougent pas.
            SectionCompte(montrerCGU: {
                withAnimation(.easeOut(duration: 0.25)) { showCGU = true }
            })
            .padding(.top, 28)
            .modifier(Arrivee(la: arrivee, rang: 2))
            Spacer(minLength: 24)
        }
    }

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

    /// Tirée vers le bas : la page finit de descendre, puis l'accueil.
    private func fermerParTirage() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) { tirage.tire = 900 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            selection = .home
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { tirage.remettre() }
        }
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
        .frame(height: 116)
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

// MARK: - Le compte, en lignes (30-09)

/// Ce que portait le panneau « Réglages » du Profil (`ReglagesOverlay`), posé
/// ici en LIGNES, à la manière des Réglages d'iOS : un groupe arrondi, des
/// rangées de 50 pt, un filet décalé sous chaque icône, le chevron gris.
/// Monochrome — seule la suppression garde sa teinte d'alerte, comme avant.
///
/// Les actes sont ceux du panneau, à la lettre : `Compte.deconnecter` (pousser
/// ce qui attend, révoquer, tout effacer, la porte), `Compte.supprimer`
/// (`supprimer-compte`, après confirmation), et les conditions générales. Un
/// refus (hors ligne, serveur) se lit sous le groupe ; rien n'est effacé.
private struct SectionCompte: View {
    var montrerCGU: () -> Void

    @Environment(\.modelContext) private var modelContext
    private let compte = CompteEtat.shared
    private let economie = EconomieWoop.shared
    @State private var confirmeSuppression = false

    private static let forme = RoundedRectangle(cornerRadius: 22, style: .continuous)
    private static let alerte = Color(red: 1.0, green: 0.36, blue: 0.26)

    private var prenom: String { ProfilServeur.prenomLocal ?? "—" }
    private var initiale: String {
        let p = (ProfilServeur.prenomLocal ?? "").trimmingCharacters(in: .whitespaces)
        guard let l = p.first else { return "·" }
        return String(l).uppercased()
    }
    private var pieces: Int { economie.or }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Etiquette(texte: L("Compte", "Account"))
            VStack(spacing: 0) {
                entete
                filet
                ligne("rectangle.portrait.and.arrow.right",
                      compte.travail == "Déconnexion…"
                          ? L("Déconnexion…", "Signing out…")
                          : L("Se déconnecter", "Sign out")) {
                    guard compte.travail == nil else { return }
                    Task { @MainActor in
                        _ = await Compte.deconnecter(contexte: modelContext)
                    }
                }
                filet
                ligne("doc.text", L("Conditions générales d'utilisation", "Terms of Use"),
                      action: montrerCGU)
                filet
                ligne("trash",
                      compte.travail == "Suppression…"
                          ? L("Suppression…", "Deleting…")
                          : L("Supprimer mon compte", "Delete my account"),
                      teinte: Self.alerte) {
                    guard compte.travail == nil else { return }
                    confirmeSuppression = true
                }
            }
            .background(Self.forme.fill(Color.white.opacity(0.045)))
            .overlay {
                Self.forme.strokeBorder(LinearGradient(
                    colors: [Color.white.opacity(0.14), Color.white.opacity(0.04)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1)
            }
            .clipShape(Self.forme)
            if let panne = compte.panne {
                Text(panne)
                    .font(.inter(12, .regular))
                    .foregroundStyle(Color.inkMuted)
                    .padding(.horizontal, 6)
            }
        }
        .padding(.horizontal, 20)
        .alert(L("Supprimer ton compte ?", "Delete your account?"),
               isPresented: $confirmeSuppression) {
            Button(L("Supprimer", "Delete"), role: .destructive) {
                Task { @MainActor in
                    _ = await Compte.supprimer(contexte: modelContext)
                }
            }
            Button(L("Annuler", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("Tes séances, tes cartes et tes pièces seront perdues pour toujours.",
                   "Your sessions, cards and coins will be lost forever."))
        }
    }

    /// La personne : l'initiale du médaillon, le prénom, les pièces.
    private var entete: some View {
        HStack(spacing: 12) {
            Text(initiale)
                .font(.inter(16, .semibold))
                .foregroundStyle(Color.inkPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Color.black.opacity(0.55)))
                .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(prenom)
                    .font(.inter(16, .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text(pieces == 1 ? L("1 pièce lune", "1 moon coin")
                                 : L("\(pieces) pièces lune", "\(pieces) moon coins"))
                    .font(.inter(12, .regular))
                    .foregroundStyle(Color.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Le filet d'iOS : décalé pour commencer sous le texte, jamais sous l'icône.
    private var filet: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 0.5)
            .padding(.leading, 56)
    }

    private func ligne(_ symbole: String, _ titre: String,
                       teinte: Color = .inkPrimary,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbole)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(teinte)
                    .frame(width: 26)
                Text(titre)
                    .font(.inter(15, .semibold))
                    .foregroundStyle(teinte)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(LigneAppuyee())
    }
}

/// L'appui d'une ligne d'iOS : la rangée s'éclaire d'un voile, rien d'autre.
private struct LigneAppuyee: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.white.opacity(configuration.isPressed ? 0.07 : 0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// LA COULEUR DES FLAMMES DU CADRAN (06-10) : cinq pastilles, la choisie
/// cerclée de blanc. Le même réglage que le petit bouton du cadran.
private struct SectionFlammes: View {
    @State private var choix = CouleurFlammes.courante

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Etiquette(texte: L("Couleur des flammes", "Flame colour"))
            HStack(spacing: 14) {
                ForEach(CouleurFlammes.allCases, id: \.self) { c in
                    Circle()
                        .fill(RadialGradient(colors: [c.pastille, c.pastille.opacity(0.55)],
                                             center: .init(x: 0.4, y: 0.35), startRadius: 2, endRadius: 22))
                        .frame(width: 38, height: 38)
                        .overlay(Circle().strokeBorder(.white.opacity(choix == c ? 0.95 : 0.14),
                                                       lineWidth: choix == c ? 2 : 1).padding(-4))
                        .frame(width: 50, height: 50)
                        .contentShape(Circle())
                        .onTapGesture {
                            Haptique.leger()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { choix = c }
                            CouleurFlammes.courante = c
                        }
                        .accessibilityLabel(c.nom)
                        .accessibilityAddTraits(choix == c ? [.isButton, .isSelected] : .isButton)
                }
                Spacer(minLength: 0)
            }
            Text(choix == .rouge ? L("Rouge (par défaut)", "Red (default)") : choix.nom)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .onAppear { choix = CouleurFlammes.courante }
    }
}
