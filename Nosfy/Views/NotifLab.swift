import SwiftUI

// MARK: - Le banc des notifications (`-notifLab`)

/// LE BANC — les variants EMPILÉS L'UN SOUS L'AUTRE sur du noir vrai
/// (verdict de Kathryn, 28-08 : « mets-les les uns sous les autres »).
///
/// Pourquoi il existe : les robes ne se jugent QUE l'une contre l'autre,
/// sur UNE capture, sans changer d'écran. Et il ne veut RIEN dessous —
/// ni splash, ni porte, ni fiche exo (dont le halo orange traversait le
/// scrim et polluait déjà le jugement de la card reward, constaté sur
/// capture le 27-08).
///
/// Les SIX robes, dans l'ordre de la pile (`-notifSeule <n>` en isole une) :
///   1 la jauge · 4 le booster · 2 le gros texte · 3 la châsse ·
///   5 l'aile · 6 le clin d'œil.
/// Les deux dernières sont du 24-09 (`NotifAile.swift`).
///
/// Les prises :
/// - un tap **rejoue** toutes les entrées (le démontage puis la renaissance —
///   jamais une coupe sèche) ;
/// - `-notifFige` : les cards naissent posées (captures immobiles) ;
/// - `-notifT <s>` : l'horloge du projecteur et du tour de pièce, clouée ;
/// - `-notifNu` : pas de bandeau (captures propres) ;
/// - `-sansVideoNotif` : les robes vidéo retombent sur la jauge (le barreau
///   de coût — il vaut aussi pour l'app, cf. `RobeNotif`).
///
/// ⚠️ `--terminate-running-process` est obligatoire au `simctl launch` :
/// une app déjà vivante revient au premier plan AVEC SES ANCIENS ARGUMENTS.
struct NotifLab: View {
    /// L'entrée est posée : la barre s'est remplie, le chiffre est monté.
    @State private var pose = NotifBanc.fige
    /// L'identité de la pile : elle change à chaque relance, sinon SwiftUI
    /// réutilise les vues et l'entrée ne rejoue pas.
    @State private var tour = 0
    /// L'horloge du projecteur — posée UNE fois au montage. Une `Date` prise
    /// dans le corps renaîtrait à chaque image et gèlerait le balayage.
    @State private var naissance = Date()

    /// L'écart entre deux dalles. À SIX robes la pile mesure 898 pt : c'est
    /// lui, avec l'échelle ci-dessous, qui la fait tenir en une capture.
    private static let ecart: CGFloat = 14

    /// Les six robes, dans l'ordre de la pile.
    private static let rangs = [1, 4, 2, 3, 5, 6]

    /// ⚠️ **AU BANC, LA JAUGE VA AU BOUT** (24-09 : « je dois voir
    /// l'animation de tout, dont la progress bar qui va au bout — aujourd'hui
    /// elle va pas au bout »). Ici on juge la COURSE de la barre, pas un état
    /// de coffre : elle part de zéro et monte jusqu'à 1. Dans l'app elle
    /// s'arrête où en est vraiment le coffre, et c'est une autre question
    /// (`fractionCoffre(apres:)`, ExerciseDetailView).
    private static let jaugePleine: Double = 1

    /// Le cycle de la boucle — l'entrée dure ~1,5 s, la barre 0,5 s de plus,
    /// puis on laisse voir la pose avant de tout rejouer.
    private static let cycle: TimeInterval = 5.2

    var body: some View {
        ZStack {
            // La nuit vraie — les dalles se jugent sur ÇA, pas sur une page.
            Color.black.ignoresSafeArea()
            GeometryReader { g in
                let k = echelle(dans: g.size)
                pile
                    .scaleEffect(k, anchor: .center)
                    .frame(width: g.size.width, height: g.size.height)
                if !NotifBanc.nu {
                    bandeau(k)
                        .frame(width: g.size.width, height: g.size.height,
                               alignment: .bottom)
                }
            }
            if NotifBanc.fps { sonde }
        }
        .contentShape(Rectangle())
        .onTapGesture { rejouer() }
        .statusBarHidden()
        .onAppear { poser() }
    }

    // ── LA PILE

    private var pile: some View {
        VStack(spacing: Self.ecart) {
            if montre(1) {
                NotifJauge(fraction: Self.jaugePleine,
                           pose: pose, naissance: naissance)
                    .modifier(EntreeNotif(pose: pose))
            }
            if montre(4) {
                // ROBE 4 — le booster (sachet orange + jauge « connectée »
                // gris → blanc), surtout pour la home. `-notifSeule 4`.
                NotifJauge(sousTitre: "VAULT PROGRESS", libelle: "BOOSTER",
                           gain: 1, fraction: Self.jaugePleine,
                           pose: pose, naissance: naissance, robe: .booster)
                    .modifier(EntreeNotif(pose: pose))
            }
            if montre(2) {
                NotifGrosTexte(pose: pose, naissance: naissance)
                    .modifier(EntreeNotif(pose: pose))
            }
            if montre(3) {
                NotifChasse(pose: pose, naissance: naissance)
                    .modifier(EntreeNotif(pose: pose))
            }
            if montre(5) {
                // ROBE 5 — l'aile (24-09) : la bête à gauche ouvre son aile
                // vers le chiffre. `-notifSeule 5`.
                NotifAile(fraction: Self.jaugePleine,
                          pose: pose, naissance: naissance)
                    .modifier(EntreeNotif(pose: pose))
            }
            if montre(6) {
                // ROBE 6 — le clin d'œil (24-09) : le montant en gros, la
                // petite tête qui cligne à droite. `-notifSeule 6`.
                NotifClin(fraction: Self.jaugePleine,
                          pose: pose, naissance: naissance)
                    .modifier(EntreeNotif(pose: pose))
            }
        }
        .id(tour)
    }

    /// Une robe est à l'écran si le banc entier est demandé (`seule == 0`) ou
    /// si c'est celle qu'on isole (`-notifSeule <n>` : 1 jauge · 2 gros texte ·
    /// 3 châsse · 4 booster · 5 aile · 6 clin d'œil).
    private func montre(_ n: Int) -> Bool {
        NotifBanc.seule == 0 || NotifBanc.seule == n
    }

    /// ⚠️ **LA PILE SE MET À L'ÉCHELLE POUR TENIR EN UNE SEULE CAPTURE**
    /// (24-09, à l'arrivée des robes 5 et 6). Six dalles de 138 pt font
    /// 898 pt : l'iPhone 16 Pro en offre 781 hors encoche. Sans ce facteur,
    /// les deux dernières naissent **hors cadre** — et une vue hors cadre
    /// n'est pas rendue du tout (le piège du `ScrollView`, déjà payé dans ce
    /// dépôt) : le banc dirait « elles n'existent pas » alors qu'elles
    /// existent. À une seule robe (`-notifSeule <n>`) le facteur vaut 1 :
    /// **c'est là qu'on juge une cote**, jamais sur la planche réduite.
    private func echelle(dans taille: CGSize) -> CGFloat {
        let n = CGFloat(Self.rangs.filter { montre($0) }.count)
        guard n > 0 else { return 1 }
        let haut = n * NotifGeo.hauteur + (n - 1) * Self.ecart
        // Le bandeau a SA place réservée : sans ces 34 pt il se posait SUR la
        // sixième dalle (relevé sur la première planche du 24-09).
        let reserve: CGFloat = NotifBanc.nu ? 24 : 58
        return min(1, (taille.height - reserve) / max(haut, 1))
    }

    /// LA SONDE — `-fps`. Le seul juge fiable du « ça lag » : un
    /// `CADisplayLink` compte les battements RÉELLEMENT servis. Compter les
    /// images différentes d'un enregistrement ne mesure PAS la cadence (un
    /// fond lent produit peu d'images différentes en tournant à 60).
    ///
    /// ⚠️ Deux régimes, et ils ne disent pas la même chose : le banc entier
    /// est le PIRE cas (six cards, TROIS vidéos, tout vivant en même temps)
    /// — c'est le cas du réglage, pas celui de l'app. `-notifSeule <n>`
    /// donne le cas VRAI : dans l'app une seule notification est à l'écran.
    private var sonde: some View {
        SondeCadence(quoi: NotifBanc.seule == 0
                     ? "notif-banc" : "notif-seule-\(NotifBanc.seule)")
            .frame(width: 0, height: 0)
    }

    /// ⚠️ **LE FACTEUR EST IMPRIMÉ**, et ce n'est pas un ornement : une
    /// planche réduite qu'on croit à l'échelle est une planche qui ment sur
    /// les cotes (la loi « rien ne se juge à taille de carte seule »).
    private func bandeau(_ k: CGFloat) -> some View {
        Text(k < 0.999
             ? "rejoue seul · tap pour relancer   ·   pile à \(Int((k * 100).rounded())) %"
             : "rejoue seul · tap pour relancer")
            .font(.inter(11))
            .foregroundStyle(Color.inkMuted)
            .padding(.bottom, 10)
            .allowsHitTesting(false)
    }

    // ── LE FILM

    private func poser() {
        guard !NotifBanc.fige else { return }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.85)
            .delay(0.35)) {
            pose = true
        }
        relancer()
    }

    /// ⚠️ **LE BANC REJOUE TOUT SEUL** (24-09 : « je dois voir l'animation de
    /// tout »). Une capture ne montre pas une animation, et taper l'écran à
    /// la main pendant qu'on filme fait bouger le film. Le cycle complet —
    /// sortie, renaissance, chiffre qui monte, barre qui court jusqu'au bout —
    /// se rejoue toutes les 5,2 s, sans qu'on touche à rien.
    ///
    /// ⚠️ Un `Timer` répétitif n'est pas nécessaire : la relance est CHAÎNÉE
    /// et porte le numéro du tour qui l'a créée. Un tap pendant l'attente
    /// avance `tour`, et la relance en vol se sabre elle-même — sinon deux
    /// horloges finiraient par battre en même temps.
    private func relancer() {
        let mien = tour
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.cycle) {
            guard tour == mien else { return }
            rejouer()
        }
    }

    /// Rejouer, c'est la vraie SORTIE suivie de la vraie ENTRÉE — jamais
    /// une coupe sèche : c'est le raccord qu'on juge autant que la pose.
    private func rejouer() {
        guard !NotifBanc.fige else { return }
        withAnimation(.easeIn(duration: 0.22)) { pose = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            tour += 1
            naissance = Date()
            // ⚠️⚠️ **LE `poser()` EST UN AUTRE TOUR DE BOUCLE, ET C'ÉTAIT
            // TOUT LE BUG** (24-09 : « je vois pas l'animation de la barre
            // de progression qui part et se remplit, elle reste figée »).
            //
            // `tour` change l'IDENTITÉ de la pile : SwiftUI la DÉTRUIT et la
            // recrée. Or **une vue qui NAÎT ne s'anime pas** — elle apparaît
            // avec la valeur qu'on lui donne, il n'y a pas de « avant » à
            // interpoler. Posés dans la MÊME transaction, `tour` et `pose`
            // faisaient donc naître la barre DÉJÀ PLEINE, et `Animatable`
            // n'y pouvait rien : il n'était jamais appelé.
            //
            // MESURÉ au film avant correctif (73,6 img/s, largeur remplie
            // image par image) : 18 → 173 → 320. Deux claquements, aucune
            // rampe. Un tour de boucle de plus suffit : la pile RENAÎT à
            // zéro, puis la rampe part d'une vue qui existe déjà.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                poser()
            }
        }
    }
}

/// L'ARRIVÉE — la dalle descend et s'allume.
///
/// ⚠️ **UN `offset` ET UNE `opacity`, JAMAIS UN REDIMENSIONNEMENT.** La
/// dalle vit à taille constante dès la première image : une surface qui
/// change de taille par image re-layoute tout ce qu'elle contient, et un
/// verre (si on en remettait un jour) y perdrait son flou définitivement.
struct EntreeNotif: ViewModifier {
    let pose: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: pose ? 0 : -26)
            .opacity(pose ? 1 : 0)
    }
}
