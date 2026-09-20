import AVFoundation
import SwiftData
import SwiftUI

// MARK: - LA PAGE PROFIL — la maison des cartes

private enum ReposDecorProfil {
    static var actif: Bool {
        ProtectionThermique.shared.ambianceAuRepos
            || CommandLine.arguments.contains("-profilRepos")
    }
    /// LES DÉCORS LÉGERS DE LA BANNIÈRE (20-09 : sur son iPhone, « rien n'est
    /// animé, je ne vois pas Nosfy ») : le téléphone était à « fair », et le
    /// filet `actif` — taillé pour les halos shader à 30 Hz d'avant — coupait
    /// le galet (une couche vidéo de 200 × 110 pt), le spot (une texture qui
    /// respire) et Nosfy pendu (7 s, puis démonté). Ces trois-là ne dorment
    /// qu'à « serious », comme le petit repère du chapitre (`appelAuRepos`).
    /// Le reste du profil (le géant, les flèches, la poignée) garde `actif`.
    static var banniere: Bool {
        ProtectionThermique.shared.appelAuRepos
            || CommandLine.arguments.contains("-profilRepos")
    }
}

/// La refonte du 14-08 (« on va s'amuser un peu !! ») : l'ancienne page à
/// trois cartes est morte. Refaite le 20-09 (« plus Apple ») : la bannière
/// noire au galet de verre venu du bord droit, le médaillon de verre à la
/// première lettre du prénom et le prénom sur une ligne, les quatre pills
/// sur la ligne dessous, les réglages dans leur overlay de verre, et LA
/// COLLECTION : les quatre registres en lignes, du plus petit au
/// légendaire, avec les dos vides qui attendent. Aucun orange.
///
/// Banc : `-profilLab` — la page seule, plein écran.
struct ProfilLuneView: View {
    @Binding var selection: WoopTab

    @Query(sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    /// Une seule valeur porte la présentation ET le cran demandé.
    /// Deux @State séparés laissaient le cover capturer l’ancien cran0.
    private struct DestinationCoffre: Identifiable { let id: Int }
    @State private var destinationCoffre: DestinationCoffre?
    @State private var showReglages = false
    /// Le rebond de la pastille pièces au tap (0 → 1 → 0).
    @State private var coinKick: CGFloat = 0
    /// Le même rebond pour la pastille d'ARGENT — le sien, pour que l'or ne
    /// tressaille pas quand on touche l'argent.
    @State private var argentKick: CGFloat = 0
    /// LA sonde du scroll — une seule, le champ vivant (le piège de la
    /// sonde constante : une sonde qui renvoie une constante ne rappelle
    /// jamais).
    @State private var scrollY: CGFloat = 0
    /// `-profilPli <p>` fige l'apparition du blur (captures).
    private static let pliFreeze: CGFloat? = UserDefaults.standard
        .string(forKey: "profilPli").flatMap { Double($0) }
        .map { CGFloat($0) }
    /// `-profilReglages` ouvre l'overlay réglages au lancement (captures).
    private static let reglagesNow =
        CommandLine.arguments.contains("-profilReglages")
    /// `-sansPiano` : la page arrive en silence (bancs, captures).
    private static let sansPiano = CommandLine.arguments.contains("-sansPiano")
    /// `-sansNosfyPenche` : la page arrive sans Nosfy (bancs, captures).
    private static let sansNosfyPenche =
        CommandLine.arguments.contains("-sansNosfyPenche")
    /// NOSFY PENCHÉ (20-09) : il est là à l'arrivée sur la page, il joue UNE
    /// fois (il pend, se déplie, s'envole) et ne revient pas — tant qu'on
    /// reste. Il revient quand on quitte l'onglet et qu'on y revient.
    @State private var nosfyPenche = false
    /// L'onglet affiché ou non — l'arrivée sur la page joue le piano.
    @Environment(\.ongletCache) private var ongletCache

    /// LE DÉPLIEMENT DE LA CARTE (le geste wahou du 15-08) : on TIRE la
    /// bannière vers le bas, elle grandit et s'arrête juste au-dessus de
    /// la poignée-lune — le reste de la page s'éteint vers le bas, le
    /// booster plonge dans le sol (option A), et KD voyage au centre.
    /// UN SEUL curseur (0 → 1) pilote tout : hauteur, trajet, extinction,
    /// plongée. `-profilCarteP <p>` le fige (captures du voyage).
    private static let carteFreeze: CGFloat? = UserDefaults.standard
        .string(forKey: "profilCarteP").flatMap { Double($0) }
        .map { CGFloat($0) }
    @State private var carteP: CGFloat =
        min(max(ProfilLuneView.carteFreeze ?? 0, 0), 1)
    /// LE PRÉNOM DU PROFIL (14-09, plan compte C4) — la même clé que la home
    /// (`woop.prenom`, cache de `profils.prenom`), lue en `@AppStorage` pour
    /// suivre le serveur ; « Kathryn » n'est plus écrit nulle part.
    @AppStorage(ProfilServeur.clePrenom) private var prenomProfil: String = ""
    private var prenomAffiche: String { prenomProfil.isEmpty ? "—" : prenomProfil }
    /// LA LETTRE DU MÉDAILLON (20-09) : la PREMIÈRE lettre du prénom tapé à
    /// l'onboarding — celui que le serveur garde (`profils.prenom`), relu ici
    /// par sa clé locale. Une seule lettre, jamais deux (« K », pas « KD »).
    /// La ligne sous le nom : il n'existe AUCUN pseudo dans Nosfy (le profil,
    /// c'est langue / prénom / but) — elle dit le prénom en minuscules, en
    /// attendant qu'un pseudo existe pour de vrai (ou qu'elle décide de l'ôter).
    private var initialeProfil: String {
        let s = prenomProfil.trimmingCharacters(in: .whitespaces)
        guard let l = s.first else { return "·" }
        return String(l).uppercased()
    }
    private var pseudoProfil: String {
        prenomProfil.isEmpty ? "@—"
            : "@" + prenomProfil.folding(options: .diacriticInsensitive, locale: .current)
                .lowercased().replacingOccurrences(of: " ", with: "")
    }
    /// Le p au début du geste (la carte se tire depuis n'importe où).
    @State private var carteBase: CGFloat = 0
    /// La prise en main : l'haptique une fois, le verrou du scroll.
    @State private var carteSaisie = false
    /// Un geste MONTANT né sur la carte fermée : mort — on ne vole pas un
    /// scroll qu'on ne peut plus rendre (le prix du highPriorityGesture).
    @State private var carteMorte = false
    /// Le booster PLANQUÉ le temps du dépliement — l'aller-retour du
    /// géant dans le sol, JAMAIS persisté (l'enterrement au doigt, lui,
    /// l'est).
    @State private var boosterPlanque =
        (ProfilLuneView.carteFreeze ?? 0) > 0.04

    // ---- L'ACCUEIL DU SACRE (le raccord de la collection) ----
    /// Le store v1 mémoire — Supabase se branchera AVEC Kathryn.
    @StateObject private var collection = CollectionLune.shared
    /// L'arrivée : en attente (l'auto-scroll roule), puis en vol.
    @State private var arriveeEnAttente: ArriveeCarte?
    @State private var arriveeEnVol: ArriveeCarte?
    @State private var arriveeBegan = Date()
    /// L'art de la carte en approche (vignette gabarit) — la descente et
    /// la pose montrent CE QUE la cérémonie a montré.
    @State private var arriveeArt: UIImage?
    /// Le canvas complet + depth de la carte en approche — la collection
    /// les garde pour l'état résultat (la carte qui s'ouvre au tap).
    @State private var arriveePlein: UIImage?
    @State private var arriveeDepth: UIImage?
    /// LA CARTE OUVERTE (l'état résultat) : tap sur une collectée →
    /// CarteVivante plein écran, chevron maison pour revenir.
    @State private var carteOuverte: CollectionLune.Obtenue?
    @State private var carteOuverteRarete = "rare"
    /// La plongée en cours dans la carte ouverte (le chevron s'efface).
    @State private var carteOuvertePlongee = false
    /// Le slot que la rangée horizontale doit amener au viewport avant
    /// la descente (« rarete-slot »).
    @State private var slotCible: String?
    @State private var fumeeBegan: Date?
    @State private var fumeeCentre: CGPoint = .zero
    /// L'éclat de lumière qui salue la pose.
    @State private var eclatBegan: Date?
    @State private var eclatCadre: CGRect = .zero
    /// La rangée qui s'avance pendant l'accueil (les autres s'assombrissent).
    @State private var rangeeAvancee: String?

    /// L'apparition du blur : comme TOUS les headers Apple — dès que le
    /// contenu passe dessous, le verre est là (rampe courte de 26 pt).
    private var pli: CGFloat {
        if let f = Self.pliFreeze { return min(max(f, 0), 1) }
        return min(max(scrollY / 26, 0), 1)
    }

    private static func sstep(_ v: CGFloat) -> CGFloat {
        let t = min(max(v, 0), 1)
        return t * t * (3 - 2 * t)
    }

    private var economie: EconomieWoop { EconomieWoop.shared }

    /// LE TRÉSOR — servi par `etat_coffre()`, avec la maquette en repli.
    ///
    /// ⚠️⚠️ **CETTE PAGE ET LE COFFRE AFFICHAIENT DEUX NOMBRES DIFFÉRENTS,
    /// EN PERMANENCE.** Ici le solde BRUT ; là-bas le même moins une dépense
    /// SIMULÉE (`boostersEnAttente × 100`). On tapait la pastille, le coffre
    /// s'ouvrait par-dessus, et la grandeur perdait 100 pièces sans qu'aucune
    /// transaction ait eu lieu. Les deux lisent maintenant le même objet.
    private var pieces: Int { economie.or }

    /// LE REPLI — recalculé depuis SwiftData, et poussé à l'arbitre.
    ///
    /// ⚠️ Il n'est plus lu par la vue : c'est `EconomieWoop` qui décide s'il
    /// sert. Cinq écrans qui choisissaient chacun leur vérité, c'était cinq
    /// vérités.
    private var maquette: Int {
        let finies = workouts.filter { !$0.isActive }
        let series = finies.flatMap { $0.exercises ?? [] }
            .reduce(0) { $0 + $1.completedSets }
        return CoffreFortPurse.coins(doneSeries: series)
    }

    var body: some View {
        GeometryReader { geo in
            let p = pli
            let ps = Self.sstep(p)
            ZStack(alignment: .top) {
                ProfilFondNoir()

                ScrollViewReader { deroulez in
                ScrollView {
                    VStack(spacing: 0) {
                        banniere(geo)
                        // Le reste de la page : la carte qui grandit le
                        // POUSSE vers le bas (la sortie demandée), et il
                        // s'éteint vite — la bande sous la carte ouverte
                        // ne doit jamais montrer un lambeau de texte.
                        Group {
                            ongletCartes
                                .padding(.top, 34)
                            registres
                                .padding(.top, 16)
                        }
                        .opacity(1 - min(1, Double(carteP) * 2.4))
                        .allowsHitTesting(carteP < 0.05)
                    }
                    .padding(.bottom, 120)
                }
                // La bannière prend TOUT le haut (la référence) : le
                // scroll monte jusqu'au bord physique de l'écran, le
                // liseré noir de 8 pt fait le tour.
                .ignoresSafeArea(edges: .top)
                // La carte dépliée possède l'écran : le scroll dort.
                .scrollDisabled(carteP > 0.02 || carteSaisie)
                .onScrollGeometryChange(for: CGFloat.self) { g in
                    // BORNÉE à 140 : au-delà, tout ce qui dépend du
                    // scroll est déjà à fond (blur, titre, fondu du
                    // géant) — le champ vivant s'arrête là et le scroll
                    // profond ne réveille PLUS la page (fluidité).
                    min(g.contentOffset.y + g.contentInsets.top, 140)
                } action: { _, y in
                    if abs(y - scrollY) > 0.25 { scrollY = y }
                }
                // L'ACCUEIL, temps 1 : la page défile d'elle-même vers
                // le registre de la rareté, la rangée s'avance, puis la
                // carte entre en descente (temps 2, la couche d'accueil).
                .onChange(of: arriveeEnAttente) { _, a in
                    guard let a else { return }
                    withAnimation(.easeInOut(duration: 0.6)) {
                        deroulez.scrollTo("registre-\(a.rarete)",
                                          anchor: .center)
                    }
                    // Le slot visé peut vivre HORS du viewport de sa
                    // rangée horizontale (5e carte et au-delà) : la
                    // rangée défile AUSSI, sinon la descente vole vers
                    // une ancre invisible et la pose se joue hors
                    // écran.
                    slotCible = "\(a.rarete)-\(a.slot)"
                    withAnimation(.easeOut(duration: 0.35).delay(0.5)) {
                        rangeeAvancee = a.rarete
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                        arriveeBegan = Date()
                        arriveeEnVol = a
                        arriveeEnAttente = nil
                    }
                    // La rangée SE REPOSE avant l'atterrissage : posée à
                    // 1,06 elle décalait la cible — la carte doit tomber
                    // EXACTEMENT dans le gabarit des dos (verdict).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            rangeeAvancee = nil
                        }
                    }
                }
                }

                // LE HEADER FONDU (verdict : « pas de blur dégueu avec
                // trait ») : un DÉGRADÉ NOIR pur qui naît au scroll — du
                // noir plein sous la barre de statut, dissous en rien,
                // sans arête. Le contenu passe dessous et s'y éteint.
                LinearGradient(stops: [
                    .init(color: .black, location: 0.0),
                    .init(color: .black.opacity(0.86), location: 0.42),
                    .init(color: .black.opacity(0.0), location: 1.0),
                ], startPoint: .top, endPoint: .bottom)
                    .frame(height: 148)
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .top)
                    .opacity(ps)
                    .allowsHitTesting(false)

                // Le titre du header : « Profil » se révèle avec le fondu,
                // centré sur la ligne des chips.
                Text("Profil")
                    .font(.inter(17, .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .padding(.top, 4)
                    .opacity(ps)
                    .offset(y: 5 * (1 - ps))
                    .allowsHitTesting(false)

                // La rangée canonique : le chevron EXACTEMENT où il vit
                // sur la fiche d'exercice, les réglages en face.
                RangeeChips(retour: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        selection = .home
                    }
                }) {
                    ChipVerre(symbole: "gearshape", label: "Réglages") {
                        withAnimation(.spring(response: 0.42,
                                              dampingFraction: 0.86)) {
                            showReglages = true
                        }
                    }
                }

                // KD LE VOYAGEUR — une seule vue transformée (la leçon
                // morphPhoto) : elle quitte le trône par une trajectoire
                // bombée et vient se tacker à côté du chevron. Et sur
                // l'ÉLASTIQUE du haut (tirer la page vers le bas), il SUIT
                // le contenu et grossit d'un souffle — la respiration du
                // zoom interne de la fiche, jamais une déchirure.
                // LE VOILE DU FOOTER (le frère jumeau du fondu du haut) :
                // le contenu se dissout vers la barre bijou — jamais un
                // bandeau, jamais un trait.
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(stops: [
                        .init(color: .black.opacity(0.0), location: 0.0),
                        .init(color: .black.opacity(0.62), location: 0.55),
                        .init(color: .black.opacity(0.96), location: 1.0),
                    ], startPoint: .top, endPoint: .bottom)
                        .frame(height: 150)
                }
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)

                // LE BOOSTER TIRABLE : le géant planté dans le sol — on
                // le tire vers le haut, le sheet de verre s'ouvre. Sticky
                // au bas, il S'EFFACE dans la nuit au scroll et revient
                // en haut de course.
                TirageBooster(pieces: pieces, scrollY: scrollY,
                              planque: boosterPlanque)

                // L'overlay des réglages — le panneau de verre in-tree (la
                // sheet système tue le vrai Liquid Glass, leçon du
                // médaillon).
                if showReglages {
                    ReglagesOverlay(pieces: pieces) {
                        withAnimation(.spring(response: 0.4,
                                              dampingFraction: 0.9)) {
                            showReglages = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
        }
        .fullScreenCover(item: $destinationCoffre) { destination in
            CoffreFortFlow(coins: pieces, onClose: { destinationCoffre = nil },
                           pageInitiale: destination.id)
        }
        // ⚠️ **LE REPLI EST POSÉ AVANT LA PREMIÈRE IMAGE.** La pastille porte
        // `contentTransition(.numericText())` : si le solde arrivait de zéro
        // en async, on verrait la roulette défiler à chaque ouverture de la
        // page. `onAppear` court avant l'affichage, `task` non.
        .onAppear { economie.poserMaquette(or: maquette) }
        // Les six nombres seulement — le journal ne sert qu'au coffre.
        .task { await economie.rafraichir() }
        // LE MUR LIT LE SERVEUR (15-09) : `ma_collection()`, habillée hors
        // du fil principal, publiée une fois — la réinstallation ne vide
        // plus « Cartes collectées ». Sans session, il reste la mémoire.
        .task { await collection.relire() }
        // LE PIANO (20-09, « un petit bruit de piano joli quand on arrive
        // sur la page ») : deux notes feutrées, une tierce qui monte,
        // synthétisées (`tools/profil/piano_profil.py`), jouées à chaque
        // arrivée sur l'onglet — jamais au retour d'un cover ni au scroll.
        // Session ambiante, mixée : sa musique continue.
        .onChange(of: ongletCache, initial: true) { _, cache in
            if !cache && !Self.sansPiano {
                CarillonIle.tinter("profil-piano", volume: 0.38)
            }
            // Nosfy : présent à l'arrivée, démonté quand on quitte — il
            // rejouera au retour. Jamais sous protection thermique ni
            // Reduce Motion : la page se passe de lui.
            nosfyPenche = !cache && !Self.sansNosfyPenche
                && !ReposDecorProfil.banniere
                && !UIAccessibility.isReduceMotionEnabled
        }
        .onAppear {
            if Self.reglagesNow { showReglages = true }
            // LE FILET DE L'ONGLET PARESSEUX : quand l'envol bascule sur
            // le profil, la page n'existe pas encore — la demande a donc
            // été posée avant que quiconque écoute. On la relit à la
            // naissance, et on laisse la page se poser avant l'accueil.
            if let c = SacreEtat.shared.arriveeDemandee {
                SacreEtat.shared.arriveeDemandee = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    lancerAccueil(carte: c)
                }
            }
        }
        // ---- L'ACCUEIL DU SACRE ----
        // La couche d'accueil (voile, descente, bouffée) lit les ancres
        // des slots posées par les registres.
        .overlayPreferenceValue(SlotAnchorKey.self) { anchors in
            accueilCouche(anchors)
        }
        // L'ÉTAT RÉSULTAT d'une carte collectée (tap dans la grille).
        .overlay { resultatCouche() }
        // LE SACRE A DÉMÉNAGÉ À LA RACINE (`WoopApp.mainBody`). Monté
        // ici, il vivait SOUS la barre bijou — on pouvait changer
        // d'onglet en pleine cérémonie — et il n'existait qu'une fois la
        // page profil construite : le premier « Ouvrir un Booster »
        // depuis la home ne faisait rien. La page ne garde que
        // l'ACCUEIL : elle écoute la rareté que l'envol lui adresse.
        .onChange(of: SacreEtat.shared.arriveeDemandee) { _, c in
            guard let c else { return }
            SacreEtat.shared.arriveeDemandee = nil
            lancerAccueil(carte: c)
        }
        // Les bancs de l'accueil :
        //   `-profilAccueil <rarete>` joue l'ARRIVÉE seule (boucle
        //     courte : descente, fumée, éclat, compteur) ;
        //   `-profilSacre` ouvre LE FLOW COMPLET — le Sacre monte à la
        //     RACINE comme si la pop-up l'avait demandé (avec
        //     `-boosterCine`, la cérémonie se joue seule jusqu'à l'étage
        //     d'enregistrement ; il ne reste qu'à balayer vers le haut
        //     pour voir l'envol et l'accueil).
        .task {
            if CommandLine.arguments.contains("-profilSacre") {
                try? await Task.sleep(nanoseconds: 700_000_000)
                SacreEtat.shared.ouvrirManege()
            }
            if let r = UserDefaults.standard.string(forKey: "profilAccueil") {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                lancerAccueil(rarete: r)
            }
        }
    }

    /// L'accueil commandé par l'envol du Sacre : la VRAIE carte (la
    /// forge a parlé pendant la cérémonie), son art au gabarit.
    private func lancerAccueil(carte: CarteEnvolee) {
        let d = collection.destination(rarete: carte.rarete,
                                       famille: carte.famille, cardId: carte.cardId)
        arriveeArt = carte.art
        arriveePlein = carte.artPlein
        arriveeDepth = carte.depth
        withAnimation(.easeInOut(duration: 0.3)) {
            arriveeEnAttente = ArriveeCarte(
                rarete: carte.rarete, famille: carte.famille,
                slot: d.slot, doublon: d.doublon, nouvelle: d.nouvelle,
                cardId: carte.cardId, acquisitionId: carte.acquisitionId)
        }
    }

    /// Le banc (`-profilAccueil <rarete>`) : l'arrivée seule, placeholder.
    private func lancerAccueil(rarete: String) {
        lancerAccueil(carte: CarteEnvolee(
            rarete: rarete, famille: ArtDuSacre.famillePlaceholder,
            art: ArtDuSacre.art))
    }

    /// L'ÉTAT RÉSULTAT d'une carte collectée : la CarteVivante règne
    /// sur le noir — le tilt au doigt (droite/gauche), la caresse du
    /// foil, et l'appui long = LA PLONGÉE (« rejouer le film »). Le
    /// chevron maison rend la page profil.
    @ViewBuilder
    private func resultatCouche() -> some View {
        if let o = carteOuverte {
            ZStack {
                Color.black.ignoresSafeArea()
                    .transition(.opacity)
                // LA MÊME SCÈNE que la sortie du booster : la carte
                // vivante règne PLEIN ÉCRAN (les cotes de son banc) —
                // le voyage de la plongée a l'écran entier, le cadre ne
                // flotte plus dans un gabarit de 270 pt (le « niveau de
                // zoom bizarre » : la carte ne sortait jamais son cadre
                // de l'écran, la loi du cadre fantôme violée).
                CarteVivante(art: o.artPlein.map(Image.init(uiImage:)),
                             depth: o.depth.map(Image.init(uiImage:)),
                             rarete: carteOuverteRarete,
                             onDive: { v in
                                 withAnimation(.easeInOut(duration: 0.28)) {
                                     carteOuvertePlongee = v
                                 }
                             },
                             diveOnTap: true)
                    .ignoresSafeArea()
                    .transition(.scale(scale: 0.94)
                        .combined(with: .opacity))
                // Le chevron s'efface pendant le voyage — la plongée
                // règne seule (la loi de la cérémonie).
                if !carteOuvertePlongee {
                    VStack(spacing: 0) {
                        RangeeChips(retour: fermerCarteOuverte) {
                            EmptyView()
                        }
                        Spacer(minLength: 0)
                    }
                    .transition(.opacity)
                }
            }
            .zIndex(40)
        }
    }

    /// La sortie de l'état résultat : rien ne survit — la musique du
    /// sacre s'éteint, le poignet se tait (sinon le sacre chantait
    /// ~10 s sur le profil et le gyro tournait pour toujours).
    private func fermerCarteOuverte() {
        LuneSacre.shared.sortir()
        // Le poignet, lui, se rend au `.onDisappear` de CarteVivante
        // (refcount) — un stop manuel ici décompterait DEUX fois.
        carteOuvertePlongee = false
        withAnimation(.easeInOut(duration: 0.26)) { carteOuverte = nil }
    }

    /// La couche d'accueil : le voile, la DESCENTE (l'avion qui
    /// atterrit), la bouffée du contact — au-dessus de toute la page.
    @ViewBuilder
    private func accueilCouche(_ anchors: [String: Anchor<CGRect>])
        -> some View {
        GeometryReader { g in
            ZStack {
                if arriveeEnVol != nil || arriveeEnAttente != nil {
                    Color.black.opacity(0.22)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                if let a = arriveeEnVol,
                   let anchor = anchors["\(a.rarete)-\(a.slot)"] {
                    let cible = g[anchor]
                    DescenteCarte(art: arriveeArt ?? ArtDuSacre.art,
                                  cible: cible,
                                  began: arriveeBegan) {
                        // L'ATTERRISSAGE : la rangée se met à jour SOUS
                        // la bouffée, le sertissage dans la paume, le
                        // compteur tique.
                        withAnimation(.easeOut(duration: 0.25)) {
                            collection.poser(rarete: a.rarete,
                                             famille: a.famille,
                                             art: arriveeArt ?? ArtDuSacre.art,
                                             artPlein: arriveePlein,
                                             depth: arriveeDepth, cardId: a.cardId, acquisitionId: a.acquisitionId)
                        }
                        fumeeCentre = CGPoint(x: cible.midX, y: cible.midY)
                        fumeeBegan = Date()
                        eclatCadre = cible
                        eclatBegan = Date()
                        // LE SERTISSAGE RENFORCÉ : le coup profond, puis
                        // l'écho sec — la carte se clipse pour de vrai.
                        UIImpactFeedbackGenerator(style: .heavy)
                            .impactOccurred(intensity: 1.0)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
                            UIImpactFeedbackGenerator(style: .rigid)
                                .impactOccurred(intensity: 0.7)
                        }
                        arriveeEnVol = nil
                    }
                }
                if let fb = fumeeBegan {
                    FumeeDArrivee(centre: fumeeCentre, began: fb)
                }
                if let eb = eclatBegan {
                    EclatDePose(cadre: eclatCadre, began: eb)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: L'identité — la bannière, le médaillon, le nom, le trésor

    /// LA BANNIÈRE, REFAITE LE 20-09 (« plus Apple ») : les halos orange
    /// sont MORTS — la dalle est noire, et le galet de verre noir de la
    /// sortie de Nosfy (`duo-galet-noir`, « la pill qui bouge, trop beau »)
    /// vient du bord droit, en plus petit, sa lumière cuite dans le fichier.
    /// Dessous, sur UNE ligne : le médaillon (la première lettre du prénom
    /// de l'onboarding, dans le même verre que les pills) et le prénom ;
    /// puis, sur UNE ligne, les quatre pills. Aucune couleur hors le blanc,
    /// le noir et l'argent — les sachets gardent leur robe, ce sont des
    /// objets.
    private func banniere(_ geo: GeometryProxy) -> some View {
        // La coque : les coins HAUTS au rayon de l'iPhone (55,
        // concentrique au châssis derrière le liseré de 5 pt), le bas
        // plus serré.
        let coque = UnevenRoundedRectangle(
            topLeadingRadius: 55, bottomLeadingRadius: 44,
            bottomTrailingRadius: 44, topTrailingRadius: 55,
            style: .continuous)
        // LE DÉPLIEMENT : fermée, la carte fait ~30 % du haut ; tirée,
        // elle grandit en PRISE DIRECTE sous le doigt et son bord bas
        // s'arrête juste AU-DESSUS de la poignée-lune (la réserve du
        // bas). Le GeometryReader vit dans le safe area : l'écran vrai =
        // taille + les deux insets.
        let ecranH = geo.size.height + geo.safeAreaInsets.top
            + geo.safeAreaInsets.bottom
        // Fermée, la bannière loge trois étages sous la ligne des chips :
        // le vide, la ligne médaillon + prénom, la ligne des pills.
        let base = max(272, geo.size.height * 0.36)
        let cible = ecranH - 5 - 128
        let hauteur = base + (cible - base) * carteP
        let swoop = Self.sstep(min(carteP, 1))
        let largeur = geo.size.width - 10
        // LE MÉDAILLON VOYAGEUR : fermé, il ouvre la ligne du prénom,
        // au-dessus des pills ; déplié il TRÔNE au centre, sous la ligne
        // chevron/réglages. Une seule vue (la leçon morphPhoto), jamais
        // deux.
        let taille = 60 + 30 * swoop
        let pillsH: CGFloat = 38
        let ax = 18 + ((largeur - taille) / 2 - 18) * swoop
        let ayFerme = hauteur - 16 - pillsH - 18 - taille
        let ay = ayFerme * (1 - swoop) + 112 * swoop
        // Le nom : à droite du médaillon fermé ; il naît au CENTRE quand
        // la carte est presque ouverte — jamais deux « Kathryn » à
        // l'écran (celui de la ligne s'éteint bien avant).
        let nomCentre = min(max((carteP - 0.62) / 0.38, 0), 1)
        let nomLigne = 1 - min(1, Double(carteP) * 2.4)
        // LE GALET, COUCHÉ SUR LE CÔTÉ (« la pill plus orientée sur le
        // côté ») : le fichier est debout, on le tourne d'un quart de tour
        // — son ventre (la partie qui brille, 0,62–0,88 de sa hauteur)
        // pointe vers la gauche, à droite de la ligne du médaillon, et sa
        // tête sort par le bord droit. Petit : 0,40 × la hauteur de la
        // bannière d'épaisseur, posé ENTRE la chip Réglages et les pills —
        // il ne passe sous AUCUN verre (un verre sur une vidéo refait son
        // flou à chaque image, 24 fois par seconde). Il grandit avec la
        // carte dépliée.
        let galetL = hauteur * 0.40
        let galetH = galetL * 1560 / 1206
        return ZStack {
            Color.black
            GaletProfil(arriveeDepuis: CGSize(width: 0, height: -64))
                .frame(width: galetL, height: galetH)
                .rotationEffect(.degrees(90))
                // EN MODE ÉCRAN le noir du fichier n'ajoute rien : seules
                // les arêtes claires du verre s'impriment, le rectangle
                // n'existe pas (mesuré sur son téléphone le 13-09).
                .blendMode(.screen)
                // Couché, il s'étend sur galetH en largeur : le bout de son
                // ventre à ≈ 0,60 de la largeur, le reste au-delà du bord.
                .position(x: largeur * 0.60 + galetH * 0.38,
                          y: hauteur * 0.56)
                .allowsHitTesting(false)
            // LE SPOT (20-09) : la lumière de l'angle haut-gauche, qui
            // respire — voir `SpotProfil`.
            SpotProfil(portee: largeur * 0.72)
                .allowsHitTesting(false)
            // NOSFY PENCHÉ EN ARRIÈRE, pendu sous la Dynamic Island, au
            // centre entre les deux chips : 125 pt de haut (le fichier est
            // encodé à cette taille, 668 × 376, 7 s, muet — jamais le 4K).
            // Il joue une fois puis la vue est DÉMONTÉE (pas cachée) : plus
            // de lecteur, plus de couche, zéro coût après son envol.
            if nosfyPenche {
                NosfyPencheProfil { nosfyPenche = false }
                    .frame(width: 125 * 668 / 376, height: 125)
                    .blendMode(.screen)
                    .position(x: largeur / 2, y: 20 + 62.5)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
            // Tout le HAUT de l'écran, Dynamic Island comprise (le
            // scroll ignore le safe area).
            .frame(height: hauteur)
            .clipShape(coque)
            // Plus de dalle de verre en couvercle (20-09) : un verre posé
            // sur une vidéo ne met rien en cache, et le noir n'a rien à
            // réfracter. Reste l'arête.
            .overlay(coque
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
            // LE TRÉSOR SUR LA BANNIÈRE : les deux réserves de sachets,
            // l'argent et l'or, sur UNE ligne, pleine largeur — TOUJOURS
            // visibles, même à 0 (verdict 30-08). La pill booster est LA
            // RÉCUPÉRATION du parcours : dire « Plus tard » à la pop-up ne
            // perd jamais un sachet, on revient le chercher ici — par le
            // coffre, ouvert sur SA page (15-09), dont « Ouvrir » monte le
            // Manège.
            .overlay(alignment: .bottom) {
                tresorBanniere
            }
            // L'identité au centre de la carte ouverte — le SLOT du
            // futur contenu vivra dessous (« plus tard on mettra des
            // choses dedans »).
            .overlay(alignment: .top) {
                if nomCentre > 0.001 {
                    VStack(spacing: 3) {
                        Text(prenomAffiche)
                            .font(.inter(20, .bold))
                            .tracking(-0.2)
                            .foregroundStyle(Color.inkPrimary)
                        Text(pseudoProfil)
                            .font(.inter(12, .semibold))
                            .tracking(0.3)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, 112 + taille + 14)
                    .opacity(nomCentre)
                    .offset(y: 8 * (1 - nomCentre))
                    .allowsHitTesting(false)
                }
            }
            // La ligne fermée : le prénom et sa ligne, à droite du
            // médaillon, alignés sur son centre.
            .overlay(alignment: .topLeading) {
                if nomLigne > 0.001 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prenomAffiche)
                            .font(.inter(19, .bold))
                            .tracking(-0.2)
                            .foregroundStyle(Color.inkPrimary)
                        Text(pseudoProfil)
                            .font(.inter(12, .semibold))
                            .tracking(0.3)
                            .foregroundStyle(Color.inkMuted)
                    }
                    .frame(height: 60, alignment: .center)
                    .offset(x: 18 + 60 + 14, y: ayFerme)
                    .opacity(nomLigne)
                    .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topLeading) {
                // LE TAP DU MÉDAILLON (20-09) : il demande la revisite de
                // Nosfy — le film en mode « souvenir », monté à la racine
                // (`RevisiteNosfy`). Jamais pendant le dépliement de la carte.
                MedaillonProfil(lettre: initialeProfil, taille: taille)
                    .contentShape(Circle())
                    .onTapGesture {
                        guard carteP < 0.05 else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
                        RevisiteNosfy.demander()
                    }
                    .offset(x: ax, y: ay)
            }
            // Le petit liseré NOIR autour (la référence) : 5 pt de nuit
            // entre la bannière et les bords physiques de l'écran —
            // collée au châssis.
            .padding(.horizontal, 5)
            .padding(.top, 5)
            // LE TIRAGE DE LA CARTE : high priority (le pan du scroll
            // gagne sinon), mais seulement quand il a un sens — page en
            // haut de course, ou carte déjà en main / dépliée. Scrollée,
            // la bannière rend la main au scroll (.subviews).
            .highPriorityGesture(
                carteDrag(course: cible - base),
                including: (carteP > 0.02 || carteSaisie || scrollY <= 2)
                    ? .all : .subviews)
    }

    /// Le geste du dépliement — la hauteur en prise directe (1:1), la
    /// butée douce au-delà de l'ouvert, et l'AIMANT au lâcher
    /// (`predictedEnd`, la grammaire de la maison). L'haptique : prise
    /// medium au décollage, coup FERME au dock ouvert, medium au retour.
    private func carteDrag(course: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                if carteMorte { return }
                if !carteSaisie {
                    // Un geste MONTANT sur la carte fermée = un scroll
                    // volé qu'on ne peut plus rendre : il meurt (le
                    // contenu se tire depuis le corps de la page).
                    if carteP < 0.5 && v.translation.height < 0 {
                        carteMorte = true
                        return
                    }
                    carteSaisie = true
                    carteBase = carteP
                    UIImpactFeedbackGenerator(style: .medium)
                        .impactOccurred(intensity: 0.8)
                }
                let brut = carteBase + v.translation.height / course
                carteP = brut <= 1
                    ? max(0, brut)
                    : 1 + (brut - 1) * 0.12
                syncPlanque()
            }
            .onEnded { v in
                defer { carteMorte = false }
                guard carteSaisie else { return }
                carteSaisie = false
                let pred = carteBase
                    + v.predictedEndTranslation.height / course
                // Généreux à l'ouverture (un élan suffit), franc à la
                // fermeture (la carte ne se referme pas par accident).
                let ouvre = carteBase < 0.5 ? pred > 0.28 : pred > 0.55
                UIImpactFeedbackGenerator(style: ouvre ? .heavy : .medium)
                    .impactOccurred(intensity: ouvre ? 0.9 : 0.75)
                withAnimation(.spring(response: 0.52,
                                      dampingFraction: 0.82)) {
                    carteP = ouvre ? 1 : 0
                }
                // Le géant répond au verdict : il plonge quand la carte
                // s'installe, il REJAILLIT quand elle remonte (option A).
                withAnimation(.spring(response: 0.55, dampingFraction: 0.8)
                    .delay(ouvre ? 0 : 0.1)) {
                    boosterPlanque = ouvre
                }
            }
    }

    /// La plongée du géant EN DIRECT pendant le geste : dès que la carte
    /// quitte son perchoir, il glisse dans le sol ; si le doigt remonte
    /// avant de lâcher, il rejaillit — l'aller-retour vivant.
    private func syncPlanque() {
        let np = carteP > 0.04
        guard np != boosterPlanque else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            boosterPlanque = np
        }
    }

    // MARK: Le trésor sur la bannière

    /// LES QUATRE PASTILLES (30-08, `tools/annonces/PLAN-COFFRE-ANNONCES.md`
    /// §0 « le profil ») : le booster noir, le booster orange, la pièce
    /// d'argent, la pièce d'or — **toujours visibles, même à 0** : « sinon
    /// on ne sait pas qu'il existe ». Le géant, lui, vit dans le sol
    /// (`TirageBooster`), pas ici.
    ///
    /// UNE LIGNE (15-09, verdict : « mettre les pills sur la même ligne et
    /// mettre juste la pièce en or et pas son wording »), PLEINE LARGEUR
    /// depuis le 20-09 (sa capture) : la ligne vit SOUS celle du médaillon,
    /// les quatre pills réparties d'un bord à l'autre. L'or reste le plus
    /// près du pouce, où il a toujours été ; l'ordre, de droite à gauche,
    /// est celui du manège du coffre (or · Lune · argent · noir).
    ///
    /// ET LES QUATRE OUVRENT LE COFFRE, AU BON CRAN (« au clic des 4
    /// pastilles liquid glass ça ramène sur la page coffre au bon item ») :
    /// plus de manège direct depuis une pill — le coffre est LA porte, son
    /// bouton « Ouvrir » monte le manège (le chemin qui existe déjà), et une
    /// pill à 0 ne fait plus rien de spécial : elle mène à sa page, qui
    /// dit ce qui manque.
    /// Les `.transition` des pills restent : rien n'apparaît plus, mais le
    /// jour où une pill se cache elles diront la sortie.
    private var tresorBanniere: some View {
        HStack(spacing: 0) {
            PillBooster(nombre: SacreEtat.shared.boostersNoirsEnAttente,
                        robe: .noire) {
                ouvrirCoffre(cran: 3)
            }
            .accessibilityIdentifier("profil-booster-noir")
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            Spacer(minLength: 6)
            PillBooster(nombre: SacreEtat.shared.boostersEnAttente) {
                ouvrirCoffre(cran: 1)
            }
            .accessibilityIdentifier("profil-booster-orange")
            .transition(.scale(scale: 0.7).combined(with: .opacity))
            Spacer(minLength: 6)
            pastilleArgent
            Spacer(minLength: 6)
            pastillePieces
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.8),
                   value: SacreEtat.shared.boostersEnAttente)
        .animation(.spring(response: 0.42, dampingFraction: 0.8),
                   value: SacreEtat.shared.boostersNoirsEnAttente)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    /// La pastille présente le coffre avec sa destination indivisible.
    private func ouvrirCoffre(cran: Int) {
        destinationCoffre = DestinationCoffre(id: cran)
    }

    /// LA PIÈCE D'ARGENT (30-08) — la sœur de la pastille d'or : même
    /// forme, même police, même matière, même geste (rebond puis le
    /// coffre). La pièce est l'image `piece-argent-mini` — une image, pas
    /// une scène : la 3D de l'or coûte déjà une `MoonCoinView`. Visible à
    /// 0, sans mot : la couleur de la pièce dit laquelle c'est.
    private var pastilleArgent: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) {
                argentKick = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.32)) {
                argentKick = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                ouvrirCoffre(cran: 2)
            }
        } label: {
            HStack(spacing: 7) {
                Image("piece-argent-mini")
                    .resizable().scaledToFit()
                    .frame(width: 22, height: 22)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(Double(argentKick) * -14))
                Text("\(economie.argent)")
                    .font(.inter(15, .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(Color.black.opacity(0.5))
                             .interactive(),
                         in: .capsule)
            .scaleEffect(1 + 0.10 * argentKick)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            L("\(economie.argent) pièces d'argent — ouvrir le coffre",
              "\(economie.argent) silver coins — open the vault"))
    }

    /// La pastille de la page BRAVO, en petit, posée SUR la bannière. Au
    /// tap elle SE RÉVEILLE (rebond + brille) puis ouvre le coffre — le
    /// délai est celui du bouton-pièce de la home (0,34 s).
    private var pastillePieces: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) {
                coinKick = 1
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.32)) {
                coinKick = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                ouvrirCoffre(cran: 0)
            }
        } label: {
            HStack(spacing: 7) {
                // La pièce 3D de BRAVO — la recette gelée, en petit.
                // ⚠️ `figee: true` — IL MANQUAIT (05-09). Une pièce déjà
                // posée (`idleLife: 0` + `yawOverride`) rend, figée, une
                // image IDENTIQUE AU PIXEL : c'est le composant lui-même
                // qui le documente (`MoonCoinLab.swift:60-66`), et le même
                // appel le porte déjà ailleurs (`SetHistoryRow.swift:186`).
                // Sans lui : une horloge, un dispatch de shader Metal par
                // battement, et un abonnement au gyroscope — qui publie à
                // 30 Hz (`DemonSky.swift`) — donc la pastille se réévaluait
                // au rythme du poignet, en permanence, pour ne rien montrer
                // de différent.
                MoonCoinView(coinR: 11, draggable: false,
                             yawOverride: 0.34, idleLife: 0, fps: 6,
                             reveal: 0.34, matte: 0, figee: true)
                    // Le métal est décoratif : son tap interne, même sans
                    // action, ne doit pas absorber celui de la pastille.
                    .allowsHitTesting(false)
                    .frame(width: 11 * MoonCoinView.hostScale,
                           height: 11 * MoonCoinView.hostScale)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(Double(coinKick) * -14))
                // Le nombre, sans le mot (15-09 : « juste la pièce en or et
                // pas son wording ») — la pièce dit laquelle c'est, comme
                // pour l'argent.
                Text("\(pieces)")
                    .font(.inter(15, .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(Color.black.opacity(0.5))
                             .interactive(),
                         in: .capsule)
            .scaleEffect(1 + 0.10 * coinKick)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("\(pieces) pièces — ouvrir le coffre",
                              "\(pieces) coins — open the vault"))
    }

    // MARK: Le titre de la collection

    private var ongletCartes: some View {
        // La recette maison des titres (celle d'« Exercices ») : Inter
        // bold, tracking négatif, le dégradé titleFade — LA signature de
        // cohérence entre les pages.
        Text(L("Cartes collectées", "Cards collected"))
            .font(.inter(24, .bold))
            .tracking(-0.3)
            .foregroundStyle(WoopGradient.titleFade)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    // MARK: Les quatre registres

    private static let registresProfil: [(nom: String, sous: String,
                                          pips: Int,
                                          cle: String)] = [
        ("Une Lune", "Normal", 1, "common"),
        ("Deux Lunes", "Plus rare", 2, "rare"),
        ("Trois Lunes", "Très rare", 3, "epic"),
        ("Quatre Lunes", "Légendaire", 4, "legendary"),
    ]

    private var registres: some View {
        VStack(spacing: 22) {
            ForEach(Self.registresProfil, id: \.nom) { reg in
                let collectees = collection.collectees(reg.cle)
                let total = max(collectees.count, collection.totaux[reg.cle] ?? 4)
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        HStack(spacing: 2.5) {
                            ForEach(0..<reg.pips, id: \.self) { _ in
                                CroissantLune(taille: 9,
                                              couleur: .profilBraise
                                                  .opacity(0.55))
                            }
                        }
                        .frame(width: 44, alignment: .leading)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(reg.nom)
                                .font(.inter(15, .semibold))
                                .foregroundStyle(Color.inkPrimary)
                            Text(reg.sous)
                                .font(.inter(11, .regular))
                                .tracking(0.4)
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Text("\(collectees.count) / \(collection.totaux[reg.cle].map(String.init) ?? "—")")
                            .font(.inter(13, .semibold))
                            .monospacedDigit()
                            .foregroundStyle(Color.inkMuted)
                            .contentTransition(.numericText())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .accessibilityIdentifier("profil-registre-\(reg.cle)")
                    .padding(.horizontal, 20)

                    // Les collectées d'abord (l'ordre d'obtention, la
                    // pastille ×N pour les doublons), puis les dos vides
                    // qui attendent. Chaque slot pose son ANCRE : la
                    // descente d'accueil vise ces rectangles.
                    ScrollViewReader { rangee in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(collectees.enumerated()),
                                        id: \.element.id) { i, o in
                                    // TAP = L'ÉTAT RÉSULTAT : la carte
                                    // s'ouvre plein écran (tilt, foil,
                                    // plongée — « rejouer le film »),
                                    // chevron maison pour revenir.
                                    CarteCollectionnee(obtenue: o)
                                        .id("slot-\(reg.cle)-\(i)")
                                        .anchorPreference(
                                            key: SlotAnchorKey.self,
                                            value: .bounds) {
                                            ["\(reg.cle)-\(i)": $0]
                                        }
                                        .onTapGesture {
                                            UIImpactFeedbackGenerator(
                                                style: .light).impactOccurred()
                                            guard o.artPlein != nil else {
                                                Task { await collection.relire() }
                                                return
                                            }
                                            carteOuverteRarete = reg.cle
                                            withAnimation(.spring(
                                                response: 0.42,
                                                dampingFraction: 0.86)) {
                                                carteOuverte = o
                                            }
                                        }
                                }
                                ForEach(collectees.count ..< total,
                                        id: \.self) { i in
                                    DosVide(pips: reg.pips)
                                        .id("slot-\(reg.cle)-\(i)")
                                        .anchorPreference(
                                            key: SlotAnchorKey.self,
                                            value: .bounds) {
                                            ["\(reg.cle)-\(i)": $0]
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        // L'accueil amène le slot visé DANS le viewport
                        // avant la descente (les ancres se re-résolvent
                        // pendant le défilement — la cible reste juste).
                        .onChange(of: slotCible) { _, sc in
                            guard let sc, sc.hasPrefix("\(reg.cle)-")
                            else { return }
                            withAnimation(.easeInOut(duration: 0.45)) {
                                rangee.scrollTo("slot-\(sc)",
                                                anchor: .center)
                            }
                        }
                    }
                }
                .id("registre-\(reg.cle)")
                // L'accueil : la rangée visée S'AVANCE, les autres
                // s'assombrissent — la caméra pousse sans casser le
                // layout.
                .scaleEffect(rangeeAvancee == reg.cle ? 1.06 : 1)
                .opacity(rangeeAvancee == nil || rangeeAvancee == reg.cle
                    ? 1 : 0.55)
                .animation(.easeInOut(duration: 0.35),
                           value: rangeeAvancee)
            }
        }
    }
}

// MARK: - Le booster tirable

/// Le sachet 3D (celui du chantier booster, réutilisé tel quel — hit-test
/// coupé, ses gestes internes dorment) posé sur le voile du footer. On le
/// TIRE vers le haut : passé le seuil — ou d'un geste vif — le sheet de
/// verre s'ouvre et le sachet SAUTE dans son en-tête (UNE seule vue qui
/// voyage, la leçon morphPhoto). Le panneau dit « N sachets à ouvrir »
/// (OUVRIR monte le Manège à la racine, `SacreEtat`) ou, sans sachet, la
/// jauge du coffre vers le prochain (15-09) ; RETOUR : l'overlay descend et
/// le sachet RESAUTILLE (ressort + haptique).
/// `-profilTirage` ouvre le sheet au lancement (captures).
struct TirageBooster: View {
    @Environment(\.ongletCache) private var ongletCache
    @Environment(\.scenePhase) private var scenePhase

    var pieces: Int
    /// Le scroll de la page : le géant s'efface dans la nuit dès qu'on
    /// descend, et revient en haut de course.
    var scrollY: CGFloat = 0
    /// PLANQUÉ : la carte du profil se déplie au-dessus — le géant plonge
    /// dans le sol (option A) et seule la poignée-lune reste, ENDORMIE
    /// (pas de hit-test : on ne déterre rien sous une carte ouverte).
    /// Jamais persisté, contrairement à `enterre`.
    var planque: Bool = false

    /// ⚠️⚠️ **`static let prix = 20` A VÉCU ICI, ET IL CONTREDISAIT LE
    /// COFFRE.** Mesuré le 29-08 : ce panneau disait « Utiliser 20 pièces
    /// pour ouvrir un booster ? » pendant que la page Rewards, atteignable
    /// d'un tap depuis la même page, annonçait « bought for 100 coins ». Deux
    /// écrans de la même app, deux prix pour le même objet — et aucun des
    /// deux ne lisait `reward_rules.prix_booster`, qui dit 100 depuis le 28.
    ///
    /// La loi du back-end était pourtant écrite : **l'app LIT les prix, elle
    /// ne les connaît pas.**
    private var economie: EconomieWoop { EconomieWoop.shared }
    private var prix: Int { max(economie.prixBooster, 1) }

    @State private var ouvert =
        CommandLine.arguments.contains("-profilTirage")
    /// La traction du doigt (points vers le haut, ≥ 0).
    @State private var tire: CGFloat = 0
    /// La prise en main : l'haptique du début de traction, une fois.
    @State private var enMain = false
    /// Le REPLANTAGE : à la fermeture du sheet, le géant repart d'enfoui
    /// et rejaillit à sa place — le morphisme inverse du saut.
    @State private var enfoui: CGFloat = 0
    /// La POUSSÉE vers le bas (l'enterrement au doigt).
    @State private var pousse: CGFloat = 0
    /// La remontée d'INVITATION : toutes les ~7 s le sachet se soulève
    /// d'un souffle — « tire-moi » sans un mot.
    @State private var invite: CGFloat = 0
    /// ENTERRÉ : le sachet dort sous le sol, seule sa poignée de braise
    /// dépasse. L'état persiste entre les visites.
    @State private var enterre =
        UserDefaults.standard.bool(forKey: "profilBoosterEnterre")

    /// TabView garde le profil monté derrière la home : son SCNView ne
    /// doit pas continuer à rendre. La même porte couvre les deux sachets.
    private var dort: Bool {
        ongletCache || scenePhase != .active || SacreEtat.shared.manegeOuvert
            || RythmeEcran.shared.storyVisible
    }
    /// À 110 pt de scroll, le fondu du footer vaut exactement zéro.
    /// L'invitation a sa propre porte : elle ne pilote ni le rendu 3D
    /// ni les gestes, et ne se réveille pas pour vérifier une invisibilité.
    private var invitationAuRepos: Bool {
        dort || ReposDecorProfil.actif || scrollY >= 110 || ouvert || enterre || planque
            || tire != 0 || pousse != 0
    }
    private var cadenceBooster: Int {
        CommandLine.arguments.contains("-profil60Hz") ? 60 : 30
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width

            ZStack(alignment: .bottom) {
                // Le voile + le sheet de verre.
                if ouvert {
                    Color.black.opacity(0.10)
                        .ignoresSafeArea()
                        .onTapGesture { fermer() }
                        .transition(.opacity)

                    sheet(W: W)
                        .transition(.move(edge: .bottom)
                            .combined(with: .opacity))
                }

                // LE SOL : le sachet GÉANT planté sous l'écran — on ne
                // voit que son sommet qui dépasse, et on l'EXTRAIT au
                // doigt. La bande de nuit pleine largeur avale le fond
                // noir du SCNView (fichier de la session booster — sa
                // transparence sera une ligne chez elle) ; le masque
                // fond son arête haute. Au seuil, le sol L'AVALE et il
                // rejaillit dans le sheet — « bim il arrive dans
                // l'overlay ».
                if !ouvert {
                    // Le fondu de nuit : PLEIN jusqu'à 40 pt (la ZONE
                    // MORTE — le tressaillement d'insets au montage et
                    // l'auto-scroll d'accueil laissaient un scroll
                    // résiduel qui rendait le géant MI-FANTÔME au
                    // repos : « le booster est transparent »), effacé
                    // à ~110 pt.
                    let fondu = 1 - min(max((scrollY - 40) / 70, 0), 1)

                    if !enterre && !planque {
                        // LE GÉANT NU : la lune à moitié visible, coupe
                        // nette au bord (le fondu du bas était moins
                        // bien — verdict). `invite` = la remontée
                        // périodique qui dit « tire-moi » sans un mot.
                        // TRANSITION LÉGÈRE (l'opacité seule) : le
                        // `.move` rejouait une entrée théâtrale à chaque
                        // remontage/planque — l'offset porte déjà toute
                        // la géographie du géant.
                        BoosterStage(still: false, frozenTear: nil,
                                     startOpen: false,
                                     // Effacé par le scroll ou sous le
                                     // manège : le rendu se SUSPEND
                                     // (l'opacité seule ne suspend pas
                                     // un SCNView — 60 fps pour rien).
                                     paused: dort || fondu < 0.02,
                                     poseAuRepos: ReposDecorProfil.actif,
                                     preferredFramesPerSecond: cadenceBooster)
                            .frame(width: 560, height: 700)
                            .rotationEffect(.degrees(-8))
                            .allowsHitTesting(false)
                            .offset(x: 0,
                                    y: 385 + enfoui + pousse - tire - invite)
                            .opacity(fondu)
                            .ignoresSafeArea(edges: .bottom)
                            .transition(.opacity)

                        // LES FLÈCHES D'INVITE, posées sur la crête du
                        // sachet (dans SES pixels — plus jamais un texte
                        // qui flotte sur les cartes) : les deux chevrons
                        // en dégradé de blanc, l'onde qui remonte.
                        // TOUJOURS MONTÉES, effacées par l'opacité — le
                        // `if fondu > 0.1` structurel insérait/retirait
                        // ce sous-arbre à CHAQUE frame de scroll autour
                        // du seuil : le « beug sévère » des réapparitions.
                        FlechesInvite(taille: 15, paused: dort || ReposDecorProfil.actif || fondu <= 0)
                            .offset(x: 0,
                                    y: -152 + enfoui + pousse
                                        - tire - invite)
                            .opacity(Double(fondu))

                        // La zone de traction : TIRER ouvre, POUSSER
                        // enterre — le geste miroir. Un tap ouvre
                        // aussi (l'affordance des pressés). RÉDUITE À
                        // LA CRÊTE du sachet et sourde dès que le
                        // scroll l'efface : à 300×200 dès fondu 0,1
                        // elle VOLAIT les scrolls et les taps de la
                        // grille des cartes au bas du premier écran.
                        Color.clear
                            .frame(width: 300, height: 180)
                            .contentShape(Rectangle())
                            .allowsHitTesting(fondu > 0.6)
                            .onTapGesture { ouvrir() }
                                .gesture(DragGesture(minimumDistance: 4)
                                    .onChanged { v in
                                        if !enMain {
                                            enMain = true
                                            UIImpactFeedbackGenerator(
                                                style: .medium)
                                                .impactOccurred(intensity: 0.95)
                                        }
                                        let h = v.translation.height
                                        tire = max(0, -h)
                                        pousse = max(0, h) * 0.85
                                    }
                                    .onEnded { v in
                                        enMain = false
                                        let pred = v.predictedEndTranslation
                                            .height
                                        if -pred > 130 {
                                            ouvrir()
                                        } else if pred > 90 {
                                            enterrer()
                                        } else {
                                            UIImpactFeedbackGenerator(
                                                style: .soft)
                                                .impactOccurred(intensity: 0.6)
                                            withAnimation(.spring(
                                                response: 0.42,
                                                dampingFraction: 0.5)) {
                                                tire = 0
                                                pousse = 0
                                            }
                                        }
                                    })
                    } else {
                        // LA POIGNÉE : le croissant du logo en NÉON —
                        // le tube du splash : cœur crème incandescent,
                        // double halo de braise qui respire. Les flèches
                        // blanches l'invitent. Un tap (ou un tirage) et
                        // le géant rejaillit.
                        VStack(spacing: 7) {
                            FlechesInvite(taille: 12, paused: dort || ReposDecorProfil.actif || fondu <= 0)
                            // ⚠️ LA BRAISE NE SE REDESSINE PLUS, ELLE
                            // S'ANIME (05-09, voir `LisereRespirant`) :
                            // l'horloge refabriquait deux gaussiennes et le
                            // cœur vingt fois par seconde pour bouger deux
                            // alphas. `-souffleHorloge` rejoue l'ancienne.
                            if SouffleBanc.horloge {
                            TimelineView(.animation(
                                minimumInterval: RythmeEcran.pas,
                                paused: RythmeEcran.dort("profile"))) { tl in
                                let t = tl.date.timeIntervalSinceReferenceDate
                                let vie = 0.75
                                    + 0.25 * sin(t * 2 * .pi / 3.1)
                                ZStack {
                                    // Le halo large — l'air embrasé.
                                    GlypheLune()
                                        .fill(Color.profilBraise)
                                        .frame(width: 34, height: 34)
                                        .blur(radius: 9)
                                        .opacity(0.75 * vie)
                                    // Le halo serré — le verre du tube.
                                    GlypheLune()
                                        .fill(Color.profilBraise)
                                        .frame(width: 34, height: 34)
                                        .blur(radius: 2.5)
                                        .opacity(0.95 * vie)
                                    // Le cœur crème — le gaz incandescent.
                                    GlypheLune()
                                        .fill(Color(red: 1.0, green: 0.93,
                                                    blue: 0.80))
                                        .frame(width: 30, height: 30)
                                }
                            }
                            .frame(width: 40, height: 40)
                            } else {
                                PoigneeBraise(paused: dort || ReposDecorProfil.actif || fondu <= 0)
                            }
                        }
                        .offset(y: 6)
                        .padding(18)
                        .contentShape(Rectangle())
                        .onTapGesture { deterrer() }
                        .gesture(DragGesture(minimumDistance: 6)
                            .onEnded { v in
                                if v.predictedEndTranslation.height < -40 {
                                    deterrer()
                                }
                            })
                        // Sous la carte dépliée, la poignée VEILLE mais
                        // ne répond pas — on ne déterre rien tant que la
                        // carte possède l'écran. Effacée par le scroll,
                        // elle devient sourde aussi (plus de branche
                        // structurelle sur `fondu` : le sous-arbre est
                        // STABLE, l'opacité fait tout).
                        .allowsHitTesting(!planque && fondu > 0.1)
                        .opacity(Double(fondu))
                        .transition(.opacity)
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height,
                   alignment: .bottom)
            .task(id: invitationAuRepos) {
                // La remontée d'INVITATION : toutes les ~7 s, le sachet
                // se soulève d'un souffle et se repose — « tire-moi »
                // sans un mot. Aucun réveil périodique hors de l'écran.
                defer {
                    var tr = Transaction()
                    tr.disablesAnimations = true
                    withTransaction(tr) { invite = 0 }
                }
                guard !invitationAuRepos, !Task.isCancelled else { return }
                let horloge = ContinuousClock()
                var prochaine = horloge.now
                    + .seconds(Double.random(in: 6.0...8.5))
                while !Task.isCancelled {
                    do { try await horloge.sleep(until: prochaine) }
                    catch { return }
                    guard !Task.isCancelled, !invitationAuRepos else { return }
                    prochaine = horloge.now
                        + .seconds(Double.random(in: 6.0...8.5))
                    withAnimation(.easeInOut(duration: 0.55)) {
                        invite = 9
                    }
                    // Le retour attend dans la task annulable : aucun
                    // délai d'animation ne survit à la sortie de l'écran.
                    do { try await horloge.sleep(for: .seconds(0.55)) }
                    catch { return }
                    guard !Task.isCancelled, !invitationAuRepos else { return }
                    withAnimation(.easeInOut(duration: 0.75)) {
                        invite = 0
                    }
                }
            }
        }
    }

    /// Le bruit du SAUT : « BoosterLeve » — l'arpège mineur en clochettes
    /// composé maison (gen_leve.py : sol, si bémol, ré — l'ascension
    /// poétique et mélancolique, un souffle d'air dessous). Le whoop de
    /// MoonGlide était trop triste (verdict).
    private static let sautChime: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "BoosterLeve",
                                        withExtension: "wav")
        else { return nil }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.volume = 0.3
        p?.prepareToPlay()
        return p
    }()

    /// L'ouverture — par le tirage ou par le chevron : le sol l'avale,
    /// il rejaillit dans le sheet. Haptique LOURDE + l'arpège du lever.
    private func ouvrir() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Self.sautChime?.currentTime = 0
        Self.sautChime?.play()
        withAnimation(.easeIn(duration: 0.14)) { tire = 0; pousse = 0 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)
            .delay(0.1)) {
            ouvert = true
        }
    }

    /// L'ENTERREMENT : on pousse le géant vers le bas, il s'enfonce —
    /// seule sa poignée de braise reste. L'état persiste.
    private func enterrer() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.9)
        UserDefaults.standard.set(true, forKey: "profilBoosterEnterre")
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            enterre = true
            pousse = 0
            tire = 0
        }
    }

    /// LE RAPPEL : la poignée tirée (ou tapée), le géant rejaillit du
    /// sol en ressort — avec l'arpège du lever.
    private func deterrer() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
        Self.sautChime?.currentTime = 0
        Self.sautChime?.play()
        UserDefaults.standard.set(false, forKey: "profilBoosterEnterre")
        enfoui = 320
        withAnimation(.easeOut(duration: 0.12)) { enterre = false }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.62)
            .delay(0.1)) {
            enfoui = 0
        }
    }

    /// La fermeture — LE MORPHISME INVERSE : le sheet descend (souple,
    /// sans rebond parasite) pendant que le géant SORT du sol et se
    /// replante dans le footer, en ressort. Haptique forte au départ.
    private func fermer() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.9)
        // Le géant repart d'enfoui — posé AVANT que le sol ne réapparaisse.
        enfoui = 250
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            ouvert = false
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.62)
            .delay(0.16)) {
            enfoui = 0
        }
    }

    /// LA PORTE DU MANÈGE — un sachet en réserve s'ouvre, gratuitement :
    /// c'est tout l'intérêt de l'avoir gagné. Le Manège se monte à la
    /// RACINE : on pose l'état partagé, personne n'a besoin d'écouter (la
    /// leçon de l'onglet paresseux — cf. `BoosterPopup.swift`). Sans sachet,
    /// le bouton n'existe pas (le mat du coffre à sa place) : rien à
    /// ouvrir, rien à acheter — l'ACHAT EST MORT (30-08 soir, Q9 :
    /// `claim_booster` révoquée, les 100 pièces deviennent un sachet toutes
    /// seules).
    private func ouvrirReserve() {
        guard economie.boosters > 0 else { return }
        SacreEtat.shared.ouvrirManege()
        fermer()
    }

    /// LE PANNEAU, EN DEUX VARIANTS (15-09, tranché par Kathryn : « deux
    /// variants : N SACHETS À OUVRIR ; et en cas de pas possible, la jauge —
    /// même composant que dans le coffre — pour dire le nombre de pièces
    /// qu'il faut »).
    ///
    /// ⚠️ Il disait « Utiliser 100 pièces pour ouvrir un booster ? » depuis
    /// le 29-08 — un texte qui promettait une transaction MORTE depuis le
    /// 30-08 (la conversion) : avec un sachet en réserve, OUVRIR l'ouvrait
    /// gratuitement ; sans, le tap ne faisait qu'une vibration. Un 🔴 posé
    /// sur le site (b-rg-le-geant), fermé ici. Et « Il t'en restera N » ne
    /// pouvait plus jamais s'écrire : le solde ne dépasse plus 99.
    ///
    /// Le vocabulaire est celui de la page du sachet Lune du coffre
    /// (`PiedCoffre`) : le compte en titre, la barre fine `BarreFine` avec
    /// la mini pièce d'or (« 43 / 100 »), le primaire quand il y a quelque
    /// chose à ouvrir, le MAT quand il n'y a rien (la 5ᵉ loi d'Opal : même
    /// place, même hauteur, le bijou en moins). Dans les deux langues.
    private func sheet(W: CGFloat) -> some View {
        let forme = RoundedRectangle(cornerRadius: 28, style: .continuous)
        let sachets = economie.boosters
        // Ce qu'il manque vers le PROCHAIN sachet — le solde est déjà la
        // jauge (`reste = solde`, < prix par construction depuis le 30-08).
        let manque = max(prix - economie.reste, 0)
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 10) {
                // LE TRÔNE : le sachet NU sur le verre — VIVANT : ses
                // gestes internes sont réveillés (le pan du chantier
                // booster le fait tourner sous le doigt — c'est pour ça
                // que le sheet n'a PAS de drag-fermeture), et par-dessus
                // sa respiration interne, une DANSE lente : balancement
                // ±2,5° et souffle d'échelle, périodes premières.
                TimelineView(.animation(minimumInterval: RythmeEcran.pas,
                                        paused: dort || ReposDecorProfil.actif)) { tl in
                    let t = tl.date.timeIntervalSinceReferenceDate
                    BoosterStage(still: false, frozenTear: nil,
                                 startOpen: false, paused: dort,
                                 preferredFramesPerSecond: cadenceBooster)
                        .frame(width: 240, height: 300)
                        .rotationEffect(.degrees(
                            2.5 * sin(t * 2 * .pi / 7.3)))
                        .scaleEffect(
                            1 + 0.025 * sin(t * 2 * .pi / 11.0 + 1.4))
                }
                .transition(.scale(scale: 0.6)
                    .combined(with: .opacity))
                .frame(height: 250)
                .padding(.top, 2)
                // LE COMPTE, EN TITRE : ce qu'il y a à ouvrir — ou ce qui
                // manque vers le prochain sachet. Le nombre vient du
                // serveur (`etat_coffre` : sachets, reste, prix), jamais
                // d'ici.
                Text(sachets > 0
                     ? L(sachets == 1 ? "1 sachet à ouvrir"
                                      : "\(sachets) sachets à ouvrir",
                         sachets == 1 ? "1 pack to open"
                                      : "\(sachets) packs to open")
                     : L("Il te manque \(manque) pièces",
                         "\(manque) more coins to go"))
                    .font(.inter(20, .bold))
                    .tracking(-0.2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.inkPrimary)
                    .contentTransition(.numericText())

                if sachets > 0 {
                    // NOTRE bouton primary — le diamant du trio auth, fumée
                    // dorée (la page est de braise). Il n'existe que s'il y
                    // a quelque chose à ouvrir.
                    DiamondPrimaryButton(title: L("OUVRIR", "OPEN"),
                                         smokeWarmth: 0.6) {
                        ouvrirReserve()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                } else {
                    // LA JAUGE DU COFFRE, telle quelle : la barre fine, la
                    // légende « 43 / 100 » avec la mini pièce d'or, la
                    // lueur de la page du sachet Lune (`PiedCoffre`).
                    BarreFine(jauge: .compte(courant: economie.reste,
                                             cible: prix, monnaie: .or),
                              lueur: CoffreV2Page.lueurSachetLune,
                              remplie: 1)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    // LE MAT DU COFFRE (la 5ᵉ loi d'Opal, `PiedCoffre.bouton`) :
                    // même place, même hauteur que le primaire, le bijou en
                    // moins — jamais un bouton grisé qui a l'air cassé.
                    // `.clear` et pas `.regular` : le givré est interdit.
                    Text(L("Verrouillé", "Locked"))
                        .font(.inter(18, .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .glassEffect(.clear, in: .capsule)
                        .padding(.horizontal, 24)
                }
                // Le retour en LIEN nu — pas de fond (verdict).
                Button(action: fermer) {
                    Text(L("RETOUR", "BACK"))
                        .font(.inter(13, .semibold))
                        .tracking(2.2)
                        .foregroundStyle(Color.inkMuted)
                        .padding(12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, -2)
            }
            .padding(.top, 14)
            .padding(.bottom, 30)
            .frame(maxWidth: .infinity)
            // Sans .interactive() — le verre interactif vole les drags.
            .glassEffect(.clear, in: forme)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
    }
}

// MARK: - Le médaillon et le galet

/// LE MÉDAILLON (20-09, « le design médaillon comme le bouton stop ») : le
/// MÊME dessin que `MedaillonStop` (WorkoutPill.swift) — le disque laqué
/// dont la lumière prend en haut-gauche, le liseré aux crans du médaillon,
/// la bague qui flare dehors du bord — sans son halo chaud (aucun orange
/// sur cette page), et dedans la PREMIÈRE lettre du prénom tapé à
/// l'onboarding, en blanc. Rien ne bouge tant que le doigt ne bouge pas.
/// Il remplace le rond aux initiales orange (« hors sujet, pas assez
/// Apple »).
struct MedaillonProfil: View {
    var lettre: String
    var taille: CGFloat = 60

    var body: some View {
        let k = taille / 34
        ZStack {
            // Le disque laqué — la lumière prend en haut-gauche (les
            // rayons de MedaillonStop, à l'échelle).
            Circle()
                .fill(RadialGradient(
                    colors: [Color(white: 0.105), Color(white: 0.035)],
                    center: UnitPoint(x: 0.38, y: 0.30),
                    startRadius: 2 * k, endRadius: 24 * k))
            Text(lettre)
                .font(.inter(taille * 0.40, .semibold))
                // Blanc pur, pas le blanc chaud du player : aucune
                // chaleur sur cette page.
                .foregroundStyle(Color.white.opacity(0.94))
        }
        .frame(width: taille, height: taille)
        // Le liseré premium, aux crans du médaillon.
        .overlay {
            Circle()
                .stroke(AngularGradient(stops: LisereMedaillon.crans,
                                        center: .center, angle: .zero),
                        lineWidth: 0.8)
        }
        // La bague : `stroke` centré, elle déborde DEHORS du disque.
        .overlay {
            Circle()
                .stroke(AngularGradient(stops: LisereMedaillon.bague,
                                        center: .center, angle: .zero),
                        lineWidth: 2.4)
                .frame(width: taille + 2.5, height: taille + 2.5)
                .blur(radius: 1.0)
                .blendMode(.plusLighter)
                .opacity(0.85)
        }
        .accessibilityLabel(L("Profil de \(lettre)", "\(lettre)'s profile"))
    }
}

/// LE SPOT (20-09, « un petit halo spotlight qui vient de l'angle gauche,
/// en diagonale, en haut » puis « plus marqué et animé ») : un cône de
/// lumière blanche né dans l'angle haut-gauche, ouvert sur la diagonale
/// descendante (45°), qui meurt avant le milieu de la bannière. Le cône =
/// un angulaire centré sur l'angle, sa portée = un radial en masque,
/// aplatis UNE fois en texture (`drawingGroup`).
///
/// IL RESPIRE, IL NE BALAIE PAS : sa source ne bouge pas, son bord ne
/// tourne pas — seule son intensité monte et descend (opacité) et sa
/// portée s'étire d'un souffle (échelle depuis l'angle), période 4,5 s.
/// Deux valeurs ANIMABLES sur une texture fixe : rien n'est redessiné
/// (la loi « ne pas redessiner pour animer »). La phase vit ICI, dans la
/// feuille, ré-armée par `task(id:)` — le body de la bannière est
/// ré-évalué au scroll, un `repeatForever` posé chez lui serait avalé.
/// Il dort avec la page (onglet caché, arrière-plan, Reduce Motion,
/// protection thermique) : au repos, pleine lumière, immobile.
private struct SpotProfil: View {
    var portee: CGFloat

    @Environment(\.ongletCache) private var ongletCache
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var monte = false
    /// 1 = pleine lumière (le repos), 0 = le creux du souffle.
    @State private var souffle: Double = 1

    private var immobile: Bool {
        !monte || ongletCache || scenePhase != .active || reduceMotion
            || RythmeEcran.dort("profile") || ReposDecorProfil.banniere
    }

    var body: some View {
        Rectangle()
            .fill(AngularGradient(stops: [
                .init(color: .white.opacity(0.00), location: 0.000),
                .init(color: .white.opacity(0.00), location: 0.040),
                .init(color: .white.opacity(0.14), location: 0.090),
                .init(color: .white.opacity(0.34), location: 0.125),
                .init(color: .white.opacity(0.14), location: 0.160),
                .init(color: .white.opacity(0.00), location: 0.210),
                .init(color: .white.opacity(0.00), location: 1.000),
            ], center: .topLeading, angle: .zero))
            .mask(RadialGradient(
                colors: [.white, .white.opacity(0.55), .clear],
                center: .topLeading,
                startRadius: 0, endRadius: portee))
            .drawingGroup()
            .blendMode(.plusLighter)
            .opacity(0.55 + 0.45 * souffle)
            .scaleEffect(0.94 + 0.06 * souffle, anchor: .topLeading)
            .task(id: immobile) {
                guard !Task.isCancelled else { return }
                armer(immobile)
            }
            .onAppear { monte = true }
            .onDisappear {
                monte = false
                armer(true)
            }
    }

    private func armer(_ immobile: Bool) {
        var tr = Transaction()
        tr.disablesAnimations = true
        withTransaction(tr) { souffle = 1 }
        guard !immobile else { return }
        withAnimation(.easeInOut(duration: 4.5)
            .repeatForever(autoreverses: true)) { souffle = 0 }
    }
}

/// NOSFY PENCHÉ (20-09, « la vidéo de Nosfy penché en arrière, qui
/// disparaît et ne revient pas ») — `profil-nosfy-penche.mp4`, le fichier
/// `nosfy_penché.mp4` de ses Téléchargements ré-encodé à la taille d'écran
/// (668 × 376, H.264, sans piste son, 324 ko). Il joue UNE fois, finit dans
/// son propre noir, et prévient : l'hôte le démonte alors — le lecteur, la
/// couche et l'observateur meurent avec la vue. Aucune boucle, aucune
/// horloge.
struct NosfyPencheProfil: UIViewRepresentable {
    var onFin: () -> Void

    final class Vue: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var lecteur: AVPlayer?
        var finObservee: NSObjectProtocol?
    }

    func makeUIView(context: Context) -> Vue {
        let v = Vue()
        v.backgroundColor = .black
        v.clipsToBounds = true
        v.playerLayer.masksToBounds = true
        v.playerLayer.videoGravity = .resizeAspect
        guard let url = Bundle.main.url(forResource: "profil-nosfy-penche",
                                        withExtension: "mp4") else {
            DispatchQueue.main.async(execute: onFin)
            return v
        }
        let item = AVPlayerItem(url: url)
        let lecteur = AVPlayer(playerItem: item)
        lecteur.isMuted = true
        lecteur.actionAtItemEnd = .pause
        lecteur.preventsDisplaySleepDuringVideoPlayback = false
        let fin = onFin
        v.finObservee = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item,
            queue: .main) { _ in fin() }
        v.lecteur = lecteur
        v.playerLayer.player = lecteur
        lecteur.play()
        return v
    }

    func updateUIView(_ uiView: Vue, context: Context) {}

    static func dismantleUIView(_ uiView: Vue, coordinator: ()) {
        if let o = uiView.finObservee {
            NotificationCenter.default.removeObserver(o)
        }
        uiView.lecteur?.pause()
        uiView.playerLayer.player = nil
    }
}

/// LE GALET DE VERRE NOIR DU PROFIL (20-09) : `duo-galet-noir.mp4`, le
/// fichier même de la sortie de Nosfy (« la pill qui bouge, en gros sur le
/// côté, en continu, trop beau »), joué ici EN PLUS PETIT, son centre
/// au-delà du bord droit de la bannière. Il GLISSE depuis le bord à chaque
/// arrivée sur l'onglet (un offset et une opacité, jamais une taille).
///
/// Il DORT dès qu'on ne le voit pas — onglet caché, app en arrière-plan,
/// bannière hors du viewport, réduction des animations, protection
/// thermique : le lecteur est mis en pause, pas seulement caché (le piège
/// du rideau). Barreau : `-sansGaletProfil` (le poster à sa place).
struct GaletProfil: View {
    /// D'où il glisse à l'arrivée, dans SON repère (avant la rotation de
    /// l'hôte) : couché d'un quart de tour, un −y devient un +x, le bord
    /// droit.
    var arriveeDepuis = CGSize(width: 64, height: 0)
    private static let sansVideo =
        CommandLine.arguments.contains("-sansGaletProfil")

    @Environment(\.ongletCache) private var ongletCache
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var monte = false
    @State private var visibleDansScroll = true
    /// L'arrivée depuis le bord (0 → 1), rejouée à chaque retour sur
    /// l'onglet.
    @State private var arrive = false

    private var dort: Bool {
        !monte || !visibleDansScroll || ongletCache
            || scenePhase != .active || reduceMotion
            || RythmeEcran.dort("profile") || ReposDecorProfil.banniere
    }

    var body: some View {
        Group {
            if Self.sansVideo || reduceMotion {
                Image("duo-galet-noir-poster")
                    .resizable().aspectRatio(contentMode: .fit)
            } else {
                GaletProfilVideo(joue: !dort)
            }
        }
        .opacity(arrive ? 1 : 0)
        .offset(x: arrive ? 0 : arriveeDepuis.width,
                y: arrive ? 0 : arriveeDepuis.height)
        .onAppear { monte = true }
        .onDisappear { monte = false }
        .onGeometryChange(for: Bool.self) { geo in
            guard let viewport = geo.bounds(of: .scrollView(axis: .vertical))
            else { return true }
            let visible = CGRect(origin: .zero, size: geo.size)
                .intersection(viewport)
            return !visible.isNull && !visible.isEmpty
        } action: { visibleDansScroll = $0 }
        // L'arrivée : quand l'onglet se montre, le galet glisse depuis le
        // bord ; quand il se cache, il repart au bord, prêt à revenir.
        .onChange(of: ongletCache, initial: true) { _, cache in
            if cache {
                var tr = Transaction()
                tr.disablesAnimations = true
                withTransaction(tr) { arrive = false }
            } else {
                withAnimation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 1.4)) {
                    arrive = true
                }
            }
        }
        .onChange(of: dort, initial: true) { _, repos in
            NavDiagnostic.noter("galet-profil-repos", destination: repos ? "1" : "0")
        }
    }
}

/// Le lecteur du galet : une couche AVPlayerLayer en boucle, muette, que
/// l'hôte met en pause quand il dort. Démonté, le lecteur s'arrête et la
/// boucle meurt avec lui.
struct GaletProfilVideo: UIViewRepresentable {
    var joue: Bool

    final class Vue: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        var lecteur: AVQueuePlayer?
        var boucle: AVPlayerLooper?
    }

    func makeUIView(context: Context) -> Vue {
        let v = Vue()
        v.backgroundColor = .black
        v.clipsToBounds = true
        v.playerLayer.masksToBounds = true
        v.playerLayer.videoGravity = .resizeAspect
        guard let url = Bundle.main.url(forResource: "duo-galet-noir",
                                        withExtension: "mp4") else { return v }
        let item = AVPlayerItem(url: url)
        let lecteur = AVQueuePlayer()
        v.boucle = AVPlayerLooper(player: lecteur, templateItem: item)
        lecteur.isMuted = true
        lecteur.preventsDisplaySleepDuringVideoPlayback = false
        v.lecteur = lecteur
        v.playerLayer.player = lecteur
        if joue { lecteur.play() }
        return v
    }

    func updateUIView(_ uiView: Vue, context: Context) {
        guard let lecteur = uiView.lecteur else { return }
        let enCours = lecteur.rate > 0
        if joue && !enCours { lecteur.play() }
        if !joue && enCours { lecteur.pause() }
    }

    static func dismantleUIView(_ uiView: Vue, coordinator: ()) {
        uiView.lecteur?.pause()
        uiView.boucle = nil
        uiView.playerLayer.player = nil
    }
}

// MARK: - L'overlay des réglages

/// Le panneau de verre in-tree — il monte du bas sur un voile, se referme
/// au drag ou au voile. Dedans : le compte, la déconnexion, la
/// suppression et les conditions générales.
/// LE COMPTE EST VRAI (14-09, plan compte C2 / C3-app / C4 — `Compte.swift`) :
/// le prénom du profil (`woop.prenom`, la même clé que la home), « Se
/// déconnecter » pousse, révoque, efface tout ce qui est à elle et rend la
/// porte ; « Supprimer mon compte » appelle `supprimer-compte` puis fait de
/// même. Un refus (hors ligne, serveur) se lit sous les lignes, rien n'est
/// effacé.
struct ReglagesOverlay: View {
    var pieces: Int
    var fermer: () -> Void

    @Environment(\.modelContext) private var modelContext
    private let compte = CompteEtat.shared

    @State private var glisse: CGFloat = 0
    @State private var showCGU = false
    @State private var confirmeSuppression = false

    /// Le prénom de la personne, et sa première lettre — celle du médaillon.
    private var prenom: String { ProfilServeur.prenomLocal ?? "—" }
    private var initiale: String {
        let p = (ProfilServeur.prenomLocal ?? "").trimmingCharacters(in: .whitespaces)
        guard let l = p.first else { return "·" }
        return String(l).uppercased()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Le voile : PRESQUE RIEN — le verre doit refléter le monde
            // derrière lui, le voile ne fait que capter le tap de sortie.
            Color.black.opacity(0.10)
                .ignoresSafeArea()
                .onTapGesture { fermer() }

            let forme = RoundedRectangle(cornerRadius: 28, style: .continuous)
            // Le conteneur d'iOS 26 : c'est LUI qui allume la vraie
            // lentille du Liquid Glass sur les grandes formes.
            GlassEffectContainer {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 40, height: 4.5)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                Text(L("Réglages", "Settings"))
                    .font(.inter(21, .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Le compte — l'échafaudage d'atelier ; le compte Apple
                // prendra cette place au chantier connexion.
                HStack(spacing: 12) {
                    Text(initiale)
                        .font(.inter(16, .semibold))
                        .foregroundStyle(Color.inkPrimary)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .overlay(Circle().strokeBorder(
                            Color.white.opacity(0.14), lineWidth: 0.7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(prenom)
                            .font(.inter(16, .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text(pieces == 1 ? L("1 pièce lune", "1 moon coin")
                                         : L("\(pieces) pièces lune", "\(pieces) moon coins"))
                            .font(.inter(12, .regular))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

                VStack(spacing: 0) {
                    // `compte.travail` est une CLÉ d'état (« Déconnexion… » /
                    // « Suppression… », posée par Compte.swift), pas un texte
                    // affiché : l'affichage passe par L(), la clé ne bouge pas.
                    ligne("rectangle.portrait.and.arrow.right",
                          compte.travail == "Déconnexion…"
                              ? L("Déconnexion…", "Signing out…")
                              : L("Se déconnecter", "Sign out")) {
                        // LA DÉCONNEXION VRAIE (C2) : pousser ce qui attend
                        // (hors ligne → refus), /auth/v1/logout, effacer tout ce
                        // qui est à elle, la porte. Le panneau se ferme quand
                        // c'est fait ; un refus reste lisible dessous.
                        guard compte.travail == nil else { return }
                        Task { @MainActor in
                            if await Compte.deconnecter(contexte: modelContext) == .faite { fermer() }
                        }
                    }
                    separateur
                    ligne("doc.text", L("Conditions générales d'utilisation", "Terms of Use")) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showCGU = true
                        }
                    }
                    separateur
                    ligne("trash",
                          compte.travail == "Suppression…"
                              ? L("Suppression…", "Deleting…")
                              : L("Supprimer mon compte", "Delete my account"),
                          teinte: Color(red: 1.0, green: 0.36, blue: 0.26)) {
                        guard compte.travail == nil else { return }
                        confirmeSuppression = true
                    }
                    if let panne = compte.panne {
                        Text(panne)
                            .font(.inter(12, .regular))
                            .foregroundStyle(Color.inkMuted)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 26)
            }
            .frame(maxWidth: .infinity)
            // LE LIQUID GLASS CLAIR (verdict : « ça doit refléter
            // derrière ») : Glass.clear — le verre le plus lentille
            // d'iOS 26. SANS .interactive() : le verre interactif CAPTE
            // les touchers pour son shimmer et volait le drag du panneau
            // (« le drag ne marche plus » — payé).
            .glassEffect(.clear, in: forme)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            .offset(y: glisse)
            .contentShape(Rectangle())
            // Le drag IMPARABLE : priorité haute avec distance minimale —
            // le panneau suit le doigt 1:1 partout (même en partant d'une
            // ligne-bouton : un tap ne bouge pas de 12 pt, le geste échoue
            // et le bouton reçoit son tap). Caoutchouc vers le haut, et la
            // fermeture lit la VITESSE (predictedEnd) : un petit geste vif
            // ferme, un grand geste hésitant revient en ressort.
            .highPriorityGesture(DragGesture(minimumDistance: 12)
                .onChanged { v in
                    let h = v.translation.height
                    glisse = h >= 0 ? h : h / 6
                }
                .onEnded { v in
                    if v.predictedEndTranslation.height > 150 {
                        fermer()
                    } else {
                        withAnimation(.spring(response: 0.32,
                                              dampingFraction: 0.82)) {
                            glisse = 0
                        }
                    }
                })
            .transition(.move(edge: .bottom).combined(with: .opacity))

            if showCGU {
                CGUPage {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showCGU = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .alert(L("Supprimer ton compte ?", "Delete your account?"), isPresented: $confirmeSuppression) {
            Button(L("Supprimer", "Delete"), role: .destructive) {
                // LA SUPPRESSION VRAIE (C3-app) : `supprimer-compte` — le serveur
                // révoque le jeton Apple (si la clé est là) et efface auth.users,
                // la cascade emporte tout ; puis l'app oublie tout, la porte.
                // Immédiat et définitif. Un refus (réseau) n'efface rien.
                Task { @MainActor in
                    if await Compte.supprimer(contexte: modelContext) == .faite { fermer() }
                }
            }
            Button(L("Annuler", "Cancel"), role: .cancel) {}
        } message: {
            Text(L("Tes séances, tes cartes et tes pièces seront perdues pour toujours.",
                   "Your sessions, cards and coins will be lost forever."))
        }
    }

    private var separateur: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 54)
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
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// Les conditions générales (`CGUPage`) et leur texte, article par article
// dans les deux langues, vivent dans `CGUPage.swift` (18-09).

// MARK: - Le dos vide

/// Une carte qui ATTEND. Au tap, elle répond « je suis vide » : ses
/// liserés s'embrasent (l'image recomposée sur elle-même en écran — seuls
/// les pixels chauds montent, donc le néon suit exactement les traits) et
/// la main sent un petit grain sec. Les lunes de rareté du registre sont
/// posées par le code, comme sur les vraies cartes.
struct DosVide: View {
    @Environment(\.ongletCache) private var ongletCache
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pips: Int
    @State private var visibleDansViewport = false
    @State private var pulse: CGFloat = 0
    /// Le RÊVE : toutes les 5–9 s visibles, un frisson de liseré très bas.
    /// Les 25 dos restent montés : seuls ceux qu'on regarde se réveillent.
    @State private var frisson: CGFloat = 0

    private var dort: Bool {
        ongletCache || scenePhase != .active || reduceMotion
            || !visibleDansViewport
    }

    private static let dos: Image = {
        guard let p = Bundle.main.path(forResource: "carte-dos-vide",
                                       ofType: "png"),
              let ui = UIImage(contentsOfFile: p)
        else { return Image(systemName: "questionmark.diamond") }
        // MINIATURE une fois pour toutes : 25 dos qui compressent chacun
        // le PNG de 1024×1536 à 80 pt à chaque composition, c'était le
        // scroll qui rame — on rend à 2× la taille d'affichage, fini.
        let taille = CGSize(width: GabaritCarte.largeur * 2,
                            height: GabaritCarte.hauteur * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let mini = UIGraphicsImageRenderer(size: taille, format: format)
            .image { _ in
                ui.draw(in: CGRect(origin: .zero, size: taille))
            }
        return Image(uiImage: mini)
    }()

    /// ⚠️ **LA MINIATURE SE CUIT AVANT L'OUVERTURE** (26-08). `static let` =
    /// `dispatch_once` : le PREMIER qui la touche paie — et jusqu'ici c'était
    /// le premier rendu du Profil, donc le fil PRINCIPAL, à l'instant précis
    /// où la page se monte. Décoder un PNG 1024×1536 et le re-rastériser là,
    /// c'est une part directe du « la page met trop de temps à apparaître ».
    /// Le fourneau la touche en fond de cale pendant le splash ; à l'ouverture
    /// il ne reste qu'une lecture.
    static func chauffer() { _ = dos }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid)
                .impactOccurred(intensity: 0.7)
            guard !dort else { return }
            withAnimation(.easeOut(duration: 0.16)) { pulse = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.16)) { pulse = 0 }
        } label: {
            // L'anneau est ÉTEINT par défaut (le dos désaturé, gris
            // sombre) et il S'ALLUME en orange — au tap (pleine flamme),
            // ou quand son horloge le décide (une braise DISCRÈTE, à
            // peine 45 % — verdict « plus discret et subtil »).
            let allume = dort ? 0 : max(pulse, frisson * 0.45)
            ZStack {
                Self.dos
                    .resizable()
                    .aspectRatio(GabaritCarte.ratio, contentMode: .fill)
                    .saturation(0.05)
                    .brightness(-0.015)
                Self.dos
                    .resizable()
                    .aspectRatio(GabaritCarte.ratio, contentMode: .fill)
                    .opacity(allume)
                Self.dos
                    .resizable()
                    .aspectRatio(GabaritCarte.ratio, contentMode: .fill)
                    .blendMode(.screen)
                    .opacity(0.55 * allume)
                Self.dos
                    .resizable()
                    .aspectRatio(GabaritCarte.ratio, contentMode: .fill)
                    .blur(radius: 5)
                    .blendMode(.screen)
                    .opacity(0.5 * allume)
            }
            // LE GABARIT PARTAGÉ : un dos vide et une carte posée sont
            // le même objet à l'écran — même largeur, même hauteur, même
            // rayon, même place. (Le padding d'air a été retiré : le PNG
            // a des coins carrés, c'est le clip qui fait l'arrondi — en
            // rétrécissant l'image il tuait les coins ET faisait dépasser
            // les cartes posées.)
            .frame(width: GabaritCarte.largeur, height: GabaritCarte.hauteur)
            .clipShape(RoundedRectangle(cornerRadius: GabaritCarte.rayon,
                                        style: .continuous))
            .scaleEffect(1 + 0.035 * (dort ? 0 : pulse))
            // Une extinction différée a déjà posé le modèle à zéro :
            // lui réassigner zéro ne suffit pas à couper son interpolation.
            // Seul le dessin se remonte au changement de porte, en pose ;
            // le Button et ses gestes gardent leur identité.
            .id(dort)
            .transaction { tr in
                if dort {
                    tr.animation = nil
                    tr.disablesAnimations = true
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Emplacement de carte vide")
        .onGeometryChange(for: Bool.self) { geo in
            // Deux défilements imbriqués : être dans la rangée ne prouve
            // pas que cette rangée est encore dans le viewport de la page.
            guard let vertical = geo.bounds(of: .scrollView(axis: .vertical)),
                  let horizontal = geo.bounds(of: .scrollView(axis: .horizontal))
            else { return false }
            let visible = CGRect(origin: .zero, size: geo.size)
                .intersection(vertical).intersection(horizontal)
            return !visible.isNull && !visible.isEmpty
        } action: { visibleDansViewport = $0 }
        .task(id: dort) {
            poser()
            guard !dort else { return }
            // Reprise avec un délai neuf : aucun rattrapage des allumages
            // manqués, aucune horloge ni travail périodique hors écran.
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(Double.random(in: 5.0...9.0)))
                } catch { return }
                guard !Task.isCancelled, !dort else { return }
                // La braise se réveille LENTEMENT et s'éteint encore plus
                // lentement — un souffle, pas un clignotement.
                withAnimation(.easeInOut(duration: 0.9)) { frisson = 1 }
                withAnimation(.easeOut(duration: 1.5).delay(0.9)) {
                    frisson = 0
                }
            }
        }
        .onDisappear { poser() }
    }

    private func poser() {
        var tr = Transaction()
        tr.animation = nil
        tr.disablesAnimations = true
        withTransaction(tr) {
            pulse = 0
            frisson = 0
        }
    }
}

extension Color {
    /// La braise du profil — l'orange sombre de l'univers des cartes.
    static let profilBraise = Color(red: 1.0, green: 0.55, blue: 0.18)
}

// MARK: - Les flèches d'invite

/// LA POIGNÉE QUI RESPIRE SANS SE REDESSINER (05-09) — la sœur animée de
/// la poignée de braise du géant enterré. Les deux halos floutés et le
/// cœur sont construits UNE fois (gaussiennes rasterisées et mises en
/// cache) ; seuls deux alphas de calque sont interpolés par le rendu.
/// La phase vit ICI, dans la feuille : le body de TirageBooster est
/// ré-évalué à chaque image de scroll (`scrollY`), un `repeatForever`
/// posé chez lui serait avalé (le piège PageCard).
/// ⚠️ Écarts DÉCLARÉS : easeInOut autoreversé ≈ le sinus (l'école) ; la
/// respiration repart du creux au remontage ; et Reduce Motion pose la
/// braise à mi-course (0,75) — l'ancienne forme l'ignorait.
private struct PoigneeBraise: View {
    var paused: Bool = false

    @Environment(\.ongletCache) private var ongletCache
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var monte = false

    private var dort: Bool {
        paused || !monte || ongletCache || scenePhase != .active
            || reduceMotion || RythmeEcran.dort("profile")
    }

    /// LA phase — la seule chose qui bouge. Au repos : le point milieu.
    @State private var vie: Double = 0.75

    var body: some View {
        ZStack {
            // Le halo large — l'air embrasé.
            GlypheLune()
                .fill(Color.profilBraise)
                .frame(width: 34, height: 34)
                .blur(radius: 9)
                .opacity(0.75 * vie)
            // Le halo serré — le verre du tube.
            GlypheLune()
                .fill(Color.profilBraise)
                .frame(width: 34, height: 34)
                .blur(radius: 2.5)
                .opacity(0.95 * vie)
            // Le cœur crème — le gaz incandescent.
            GlypheLune()
                .fill(Color(red: 1.0, green: 0.93, blue: 0.80))
                .frame(width: 30, height: 30)
        }
        .frame(width: 40, height: 40)
        .task(id: dort) {
            guard !Task.isCancelled else { return }
            armer(dort)
        }
        .onAppear { monte = true }
        .onDisappear {
            monte = false
            armer(true)
        }
    }

    private func armer(_ dort: Bool) {
        guard !dort else {
            var tr = Transaction()
            tr.disablesAnimations = true
            withTransaction(tr) { vie = 0.75 }
            return
        }
        vie = 0.5
        withAnimation(.easeInOut(duration: 3.1 / 2)
            .repeatForever(autoreverses: true)) {
            vie = 1.0
        }
    }
}

/// LES DEUX FLÈCHES minimales en dégradé de blanc — l'invite « tire vers
/// le haut », élégante : une onde d'opacité remonte de l'une à l'autre,
/// jamais un clignotement.
/// ⚠️ L'ONDE NE SE REDESSINE PLUS, ELLE S'ANIME (05-09) — le jumeau de
/// `ChevronAppel` (HomeNuit) : arceau demi-sinus de 0,85 s (montée
/// easeOutSine, descente easeInSine, écart ≈ 3 % de la course) puis
/// plancher 0,85 s à coût NUL ; déphasage 0,2435 s préservé (0,9 rad).
/// Échéances RECALÉES sur l'horloge (jamais k += 1 : la rafale après
/// suspension). Écarts DÉCLARÉS : Reduce Motion pose au plancher 0,30
/// (l'ancienne forme l'ignorait) ; l'onde repart recalée au réveil au
/// lieu de geler mi-arceau. `-souffleHorloge` rejoue l'ancienne forme.
struct FlechesInvite: View {
    var taille: CGFloat = 15
    /// Le footer reste monté quand son fondu l'a entièrement effacé.
    /// Cette porte vient de l'hôte qui connaît ce fondu.
    var paused: Bool = false

    @Environment(\.ongletCache) private var ongletCache
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var immobile: Bool {
        paused || ongletCache || scenePhase != .active
            || reduceMotion || RythmeEcran.dort("profile")
    }

    var body: some View {
        if SouffleBanc.horloge {
            TimelineView(.animation(minimumInterval: RythmeEcran.pas,
                                    paused: immobile)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                VStack(spacing: -taille * 0.34) {
                    ForEach(0..<2, id: \.self) { i in
                        Image(systemName: "chevron.up")
                            .font(.system(size: taille, weight: .medium))
                            .foregroundStyle(LinearGradient(
                                colors: [.white.opacity(0.95),
                                         .white.opacity(0.35)],
                                startPoint: .top, endPoint: .bottom))
                            .opacity(0.30 + 0.55 * max(0,
                                sin(t * 2 * .pi / 1.7
                                    + Double(1 - i) * 0.9)))
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 3)
            }
            .allowsHitTesting(false)
        } else {
            VStack(spacing: -taille * 0.34) {
                // Le haut (i = 0) a +0,9 rad d'avance sur le bas :
                // 0,9 / 2π × 1,7 s ≈ 0,2435 s de retard pour le bas.
                FlecheOnde(taille: taille, retard: 0, immobile: immobile)
                FlecheOnde(taille: taille, retard: 0.2435, immobile: immobile)
            }
            .shadow(color: .black.opacity(0.5), radius: 3)
            .allowsHitTesting(false)
        }
    }
}

/// Une flèche de l'onde : le chevron bâti une fois, seul son alpha bouge.
private struct FlecheOnde: View {
    var taille: CGFloat
    var retard: Double
    var immobile: Bool

    @State private var v: Double = 0

    private static let periode = 1.7
    private static let arceau = 0.425

    var body: some View {
        Image(systemName: "chevron.up")
            .font(.system(size: taille, weight: .medium))
            .foregroundStyle(LinearGradient(
                colors: [.white.opacity(0.95),
                         .white.opacity(0.35)],
                startPoint: .top, endPoint: .bottom))
            .opacity(0.30 + 0.55 * v)
            .task(id: immobile) { await onduler() }
    }

    @MainActor
    private func onduler() async {
        guard !immobile else {
            var tr = Transaction()
            tr.disablesAnimations = true
            withTransaction(tr) { v = 0 }
            return
        }
        let horloge = ContinuousClock()
        let origine = horloge.now
        var k = 0
        while !Task.isCancelled {
            let ecoule = origine.duration(to: horloge.now)
            let sec = Double(ecoule.components.seconds)
                + Double(ecoule.components.attoseconds) / 1e18
            k = max(k, Int(((sec - retard) / Self.periode).rounded(.up)))
            let echeance = origine
                + .seconds(retard + Double(k) * Self.periode)
            try? await horloge.sleep(until: echeance)
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.39, 0.575, 0.565, 1,
                                       duration: Self.arceau)) { v = 1 }
            try? await horloge.sleep(until: echeance + .seconds(Self.arceau))
            guard !Task.isCancelled else { return }
            withAnimation(.timingCurve(0.47, 0, 0.745, 0.715,
                                       duration: Self.arceau)) { v = 0 }
            k += 1
        }
    }
}

// MARK: - Le glyphe du logo

/// LE croissant de la marque, exact : le path de `MoonGlyph` (les 18
/// cubiques du logo, WoopShared) en `Shape` — fini les croissants
/// génériques à deux cercles (verdict : « comme le logo »).
struct GlypheLune: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height / MoonGlyph.unitHeight)
        let dx = rect.midX - s / 2
        let dy = rect.midY - s * MoonGlyph.unitHeight / 2
        func pt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: dx + p.x * s, y: dy + p.y * s)
        }
        var path = Path()
        path.move(to: pt(MoonGlyph.startPoint))
        for seg in MoonGlyph.segments {
            path.addCurve(to: pt(seg.end), control1: pt(seg.c1),
                          control2: pt(seg.c2))
        }
        path.closeSubpath()
        return path
    }
}

/// Le glyphe posé en pastille — petit et DISCRET (« trop de lunes mdr »).
struct CroissantLune: View {
    var taille: CGFloat
    var couleur: Color

    var body: some View {
        GlypheLune()
            .fill(couleur)
            .frame(width: taille, height: taille)
    }
}

// MARK: - Le fond de nuit

/// La page est rendue au NOIR : un dégradé subtil et profond (verdict :
/// « un fond noir dégradé joli, pas métal ») — chaud en haut, éteint en
/// bas. Le grain de la maison par-dessus.
struct ProfilFondNoir: View {
    var body: some View {
        ZStack {
            Color.black
            // Le fond : gris neutre, plus de chaleur brune (20-09, « on
            // remove le orange ») — la page est noire, argent, blanche.
            LinearGradient(stops: [
                .init(color: Color(white: 0.066), location: 0.0),
                .init(color: Color(white: 0.028), location: 0.38),
                .init(color: .black, location: 1.0),
            ], startPoint: .top, endPoint: .bottom)
            WoopGrain()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Le banc

/// `-profilLab` : la page seule, sans la barre bijou — le chevron ne mène
/// nulle part, on fouette le visuel.
struct ProfilLab: View {
    @State private var selection = WoopTab.profile

    var body: some View {
        ProfilLuneView(selection: $selection)
            .statusBarHidden()
            .preferredColorScheme(.dark)
            // Au banc, personne ne pose l'onglet affiché : sans lui, les
            // portes `dort("profile")` disent oui et le galet reste figé.
            .onAppear { RythmeEcran.shared.ongletActif = "profile" }
    }
}

#Preview { ProfilLab() }
