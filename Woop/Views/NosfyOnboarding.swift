import AVFoundation
import SwiftUI

// MARK: - LE FILM DE NOSFY (06-09) — les cinq écrans de l'onboarding

/// Plan : `tools/porte/PLAN-COMPTE-ONBOARDING.html`.
///
/// **LA LOI D'ÉCRITURE : il n'y a pas d'interface, il y a quelqu'un qui parle.**
/// Aucun titre d'écran, aucun sous-titre, aucun label. Chaque mot affiché est
/// une phrase de Nosfy, en **Inter** — la fonte de la maison, celle de la phrase
/// de la home.
///
/// **L'ALTERNANCE CLAIR / SOURD** (verdict 06-09) : la phrase commence en blanc
/// dégradé, la suite passe au gris, et ainsi de suite — exactement la voix de la
/// home (« Hello Kathryn, » clair · « you've done » sourd). C'est ce battement
/// qui donne le millénaire, pas le corps de la fonte.
///
/// **AUCUN BOUTON, sauf le dernier.** La réponse EST l'action : toucher une card
/// avance le film. Seule la sortie garde un « Entrer » — parce qu'on ne pousse
/// pas quelqu'un dans son app, on l'y invite.
struct NosfyOnboarding: View {

    struct Reponses {
        var langue: String = "fr"
        var prenom: String?
        var but: String?
        var jours: Set<Int> = []
        var objectifHebdo: Int? { jours.isEmpty ? nil : jours.count }
    }

    var onFini: (Reponses) -> Void = { _ in }

    @State private var etape: Etape = .accueil
    /// LE BARREAU de la vidéo (`-sansNosfyVideo`) : le poster à sa place — sans
    /// lui on ne pourra ni l'accuser ni la disculper à la mesure.
    static let sansVideo = CommandLine.arguments.contains("-sansNosfyVideo")
    @State private var reponses = Reponses()
    @State private var replique: String?
    @State private var prenomSaisi = ""
    /// Le champ n'existe qu'une fois la question posée.
    @State private var champOuvert = false
    /// Le halo s'embrase quand il parle — c'est la respiration du film.
    @State private var embrase = false
    /// La sortie : le halo se penche en projecteur, l'anneau flashe une fois.
    @State private var projecteur = false
    @State private var ileFlash = false
    /// L'ALLUMAGE (13-09) : quand le film s'ouvre par-dessus la porte, le halo
    /// n'est pas là d'un coup — il NAÎT de l'île : un point de braise qui
    /// s'épanouit, et l'anneau qui flashe quand il est plein. C'est la
    /// transition login → onboarding : l'île et le halo sont la couture.
    @State private var allume = false
    /// LE HALO PARLE AVEC LUI (13-09, « halo A ») : à CHAQUE mot qui apparaît,
    /// une poussée de +4 % sur un ressort de 0,35 s. Trente mots, trente
    /// poussées — la lumière bouge quand le texte bouge, littéralement. Un
    /// bascule par mot : monte, descend, monte… jamais une horloge régulière.
    @State private var battement = false

    private func battre() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { battement.toggle() }
    }
    @State private var minuterieJours: Task<Void, Never>?
    @FocusState private var prenomActif: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Etape: Int, CaseIterable {
        case accueil, langue, prenom, but, jours, bien, bienvenue

        /// Le rang dans la jauge : l'accueil et la langue ne sont pas des
        /// questions — c'est la rencontre, puis le seuil ; la sortie non plus,
        /// la boucle est fermée. « Bien. » est le mot de fin.
        var tiers: Int {
            switch self {
            case .accueil, .langue: return 0
            case .prenom: return 1
            case .but:    return 2
            case .jours, .bien, .bienvenue: return 3
            }
        }
    }

    var body: some View {
        // ⚠️ **LE DÉBORDEMENT DU 06-09 (deuxième cause).** Le halo fait 470 pt de
        // large ; posé comme ENFANT du ZStack, c'est LUI qui donnait sa taille au
        // ZStack — 470 au lieu des 393 de l'écran. Le contenu recevait donc
        // 470 − 60 de marge = 410 pt et sortait de l'écran des deux côtés, marges
        // comprises. Un `.overlay` ne dimensionne PAS son hôte : le halo se pose
        // sur le noir, l'île se pose sur le tout, et seul le noir décide de la
        // largeur.
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    // ⚠️ À LA SORTIE, LE HALO NE S'ÉTEINT PAS : IL SE PENCHE.
                    // (13-09 — la version d'avant le retirait d'un coup et
                    // posait un shader dont la source est codée en dur en haut
                    // à GAUCHE : la lumière sautait dans un coin. C'était la
                    // rupture de continuité que Kathryn a nommée.)
                    HaloIle(embrase: embrase, calme: reduceMotion, projecteur: projecteur,
                            battement: battement)
                        // L'ALLUMAGE : il s'épanouit DEPUIS l'île (ancre en haut),
                        // pas depuis le milieu de l'écran.
                        .scaleEffect(allume ? 1 : 0.18, anchor: .top)
                        .opacity(allume ? 1 : 0)
                }

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                contenu
                    .id(etape)
                    .transition(.fonduFlou)
                Spacer(minLength: 0)
                pied
            }
            .padding(.horizontal, etape == .bienvenue ? 0 : 30)
            .padding(.top, etape == .bienvenue ? 0 : 152)
            .padding(.bottom, etape == .bienvenue ? 0 : 28)
        }
        .overlay(alignment: .top) {
            // L'île reste jusqu'au bout : à la sortie, c'est elle l'interrupteur.
            IleNosfy(tiers: etape.tiers, replique: replique, calme: reduceMotion,
                     flash: ileFlash)
                .opacity(allume ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .onTapGesture {
            prenomActif = false
            // L'accueil se SAUTE d'un tap : Apple laisse toujours passer.
            if etape == .accueil { avancer(passe: true) }
        }
        .onAppear {
            NosfySon.musique(true)
            // L'ALLUMAGE — 1,2 s : le halo s'épanouit depuis l'île sur un
            // ressort lent, et quand il est plein l'anneau FLASHE avec sa voix
            // (moyen). Sous Reduce Motion : tout est là d'un coup.
            if reduceMotion {
                allume = true
            } else {
                withAnimation(.spring(response: 1.2, dampingFraction: 0.8).delay(0.1)) {
                    allume = true
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(520))
                Haptique.fort()
                ileFlash = true
                try? await Task.sleep(for: .milliseconds(180))
                ileFlash = false
            }
            if Self.autoBanc { jouerSeul() }
        }
    }

    // MARK: Les écrans

    @ViewBuilder
    private var contenu: some View {
        switch etape {

        // ── L'ACCUEIL (13-09, `PLAN-ACCUEIL-NOSFY.md`) : la rencontre ──
        // La chauve-souris au milieu, fondue dans le noir ; le texte AU-DESSUS,
        // quatre blocs un à la fois (FR, EN, FR, EN). La règle qui répond à « la
        // vidéo assez haute pour ne pas passer sous les textes » : ce n'est pas
        // la vidéo qu'on monte, c'est LA ZONE DE TEXTE QU'ON FIXE — 160 pt
        // réservés pour le bloc le plus long, texte aligné au bas de la zone,
        // la vidéo dessous ne bouge JAMAIS. Aucun chevauchement, par construction.
        case .accueil:
            VStack(spacing: 24) {
                Tirade(blocs: [
                    [("Bienvenue dans mon univers noir.", true)],
                    [("Welcome to my dark world.", false)],
                    [("Je suis Nosfy, je suis là pour vous aider à vous dépasser.", true)],
                    [("I'm Nosfy, I'm here to help you go further.", false)]
                ], taille: 30, repos: 1.1, onMot: battre) {
                    avancer(passe: false)
                }
                .frame(height: 160, alignment: .bottom)

                // LA BÊTE — 164 × 246 pt (« légèrement plus petite », 13-09 ; le
                // ratio du fichier cuit, 600 × 900). Le fondu est DANS le fichier.
                // Montée ici, DÉMONTÉE dès que l'étape change : une vue montée
                // mais cachée est rendue (le piège du rideau).
                Group {
                    if Self.sansVideo {
                        Image("nosfy-accueil-poster")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        NosfyReel(nom: "nosfy-accueil-loop")
                    }
                }
                .frame(width: 164, height: 246)
                .modifier(Retarde(apres: 0.6))

                Spacer(minLength: 0)
            }

        // ── LE SEUIL : une voix sans nom, dans les deux langues à la fois ──
        case .langue:
            VStack(alignment: .leading, spacing: 30) {
                // LA LUMIÈRE AVANT LE TEXTE (13-09) : le premier mot part à
                // 0,9 s, quand le halo est presque plein — avant, le texte et
                // l'allumage se couraient après.
                // « Quelqu'un vous attend dans le noir » est parti (13-09) :
                // l'accueil l'a présenté, et c'est LUI qui parle — première
                // personne, « dois-je », plus « doit-il ».
                MotsFlou([("Dans quelle langue dois-je vous parler ?", true)],
                         taille: 30, base: 0.4, onMot: battre)
                MotsFlou([("What language should I speak?", false)],
                         taille: 30, base: 1.4)
                    .opacity(0.72)

                VStack(spacing: 11) {
                    CardVerre(titre: "Français") { reponses.langue = "fr"; avancer(passe: false) }
                    CardVerre(titre: "English") { reponses.langue = "en"; avancer(passe: false) }
                }
                .padding(.top, 8)
                .modifier(Retarde(apres: 1.6))
            }

        // ── QUESTION 1 SUR 3 : il se présente, et demande le prénom ──
        case .prenom:
            VStack(alignment: .leading, spacing: 34) {
                // Une phrase à la fois : il parle, il ne récite pas.
                // (13-09) L'accueil l'a déjà présenté — « Bonjour, je me présente »
                // redisait tout. Ici il ENCHAÎNE sur la langue qu'elle vient de
                // choisir : on se comprend, donc on peut se parler.
                Tirade(blocs: [
                    [("Top.", true),
                     ("J'ai trois questions pour vous.", false)],
                    [("La première :", false),
                     ("comment dois-je vous appeler ?", true)]
                ], onMot: battre) {
                    withAnimation(.easeOut(duration: 0.7)) { champOuvert = true }
                }

                // Pas de bouton : le clavier valide. Le champ n'existe qu'une
                // fois la question posée.
                if champOuvert {
                TextField("", text: $prenomSaisi)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        guard !prenomSaisi.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        avancer(passe: false)
                    }
                    .font(.inter(19, .medium))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .focused($prenomActif)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 17)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.06))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(prenomActif ? 0.62 : 0.30),
                                                     .white.opacity(0.06)],
                                            startPoint: .top, endPoint: .bottom),
                                        lineWidth: 1)
                            }
                    }
                    // L'APPARITION À LA APPLE : il sort du flou en montant,
                    // comme les mots — jamais un élément qui « pop ».
                    .transition(.fonduFlou)
                    .task {
                        try? await Task.sleep(for: .milliseconds(500))
                        prenomActif = true
                    }
                }
            }

        // ── QUESTION 2 SUR 3 : l'objectif ──
        case .but:
            VStack(alignment: .leading, spacing: 30) {
                MotsFlou([("Deuxième question.", true),
                          ("Vous voulez vous entraîner pour quoi ?", false)],
                         taille: 30)
                VStack(spacing: 11) {
                    CardVerre(titre: "Être plus fort") { reponses.but = "force"; avancer(passe: false) }
                    CardVerre(titre: "Perdre du poids") { reponses.but = "poids"; avancer(passe: false) }
                    CardVerre(titre: "Être en forme") { reponses.but = "forme"; avancer(passe: false) }
                }
                .modifier(Retarde(apres: 1.9))
            }

        // ── QUESTION 3 SUR 3 : les jours ──
        case .jours:
            VStack(alignment: .leading, spacing: 30) {
                MotsFlou([("Dernière question.", true),
                          ("Combien de fois par semaine ?", false)],
                         taille: 30, onMot: battre)

                SemaineTapable(choisis: reponses.jours) { i in
                    Haptique.leger()
                    if reponses.jours.contains(i) { reponses.jours.remove(i) }
                    else { reponses.jours.insert(i) }
                    armerMinuterieJours()
                }
                .modifier(Retarde(apres: 1.7))

                // Ce n'est pas une légende : c'est LUI qui compte à voix haute.
                if !reponses.jours.isEmpty {
                    MotsFlou([(Self.enLettres(reponses.jours.count) + " fois.", true)], taille: 30)
                        .id(reponses.jours.count)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

        // ── « BIEN. » — le mot de fin, avant que la lumière change de camp ──
        // (13-09, sa demande : « avant le résultat il manque un mot de fin »).
        // L'écran ne porte QUE le mot ; le halo s'embrase avec lui ; 1,6 s, puis
        // le projecteur. Pas de réplique dans l'île : ce mot-là EST l'écran.
        case .bien:
            MotsFlou([("Bien.", true)], taille: 44, onMot: battre)
                .frame(width: 150)
                .frame(maxWidth: .infinity)
                .task {
                    Haptique.fort()
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { embrase = true }
                    try? await Task.sleep(for: .milliseconds(1000))
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { embrase = false }
                    try? await Task.sleep(for: .milliseconds(600))
                    guard etape == .bien else { return }
                    withAnimation(.easeInOut(duration: 0.55)) { etape = .bienvenue }
                }

        // ── LA SORTIE : LE PROJECTEUR ──
        case .bienvenue:
            SortieProjecteur(prenom: reponses.prenom,
                             seances: reponses.jours.count,
                             onInterrupteur: {
                                 // L'INTERRUPTEUR : le flash de l'anneau, sa voix
                                 // (moyen), et le halo qui se penche en projecteur.
                                 Haptique.fort()
                                 ileFlash = true
                                 projecteur = true
                                 Task { @MainActor in
                                     try? await Task.sleep(for: .milliseconds(180))
                                     ileFlash = false
                                 }
                             },
                             onEntrer: { onFini(reponses) })

        }
    }

    private var fragmentsDeSortie: [(String, Bool)] {
        let n = reponses.jours.count
        guard n > 0 else { return [("On commence quand vous voulez.", false)] }
        return [("\(Self.enLettres(n)) fois par semaine.", false),
                ("On commence quand vous voulez.", true)]
    }

    // MARK: Le pied — rien, sauf à la toute fin

    @ViewBuilder
    private var pied: some View {
        if etape == .bienvenue {
            EmptyView()          // le projecteur porte son propre « Entrer »
        } else if etape != .langue {
            Button("Passer") { NosfySon.tap(); avancer(passe: true) }
                .font(.inter(12.5))
                .foregroundStyle(.white.opacity(0.30))
                .underline()
                .padding(.top, 26)
                .padding(.bottom, 6)
                .modifier(Retarde(apres: etape == .prenom ? 8.5 : 2.4))
        }
    }

    // MARK: Le tour — la réplique, l'embrasement, la vibration

    /// LES JOURS se cochent à plusieurs : le film repart 2,4 s après le DERNIER
    /// tap, et la minuterie se remet à zéro à chaque nouveau jour touché.
    private func armerMinuterieJours() {
        minuterieJours?.cancel()
        guard !reponses.jours.isEmpty else { return }
        minuterieJours = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            avancer(passe: false)
        }
    }

    private func avancer(passe: Bool) {
        minuterieJours?.cancel()
        prenomActif = false

        var mot: String?
        switch etape {
        case .accueil:
            // La rencontre n'est pas une réponse : pas de réplique, pas de coup —
            // le texte et la bête s'effacent, le seuil arrive.
            withAnimation(.easeInOut(duration: 0.7)) { etape = .langue }
            return
        case .langue:
            mot = reponses.langue == "fr" ? "Français." : "English."
        case .prenom:
            if passe {
                reponses.prenom = nil
                mot = "Comme vous voulez."
            } else {
                let p = prenomSaisi.trimmingCharacters(in: .whitespaces)
                reponses.prenom = p
                mot = "Enchanté, \(p)."
            }
        case .but:
            if passe { reponses.but = nil; mot = "Comme vous voulez." }
            else { mot = "Bien. Je sais où on va." }
        case .jours:
            if passe {
                reponses.jours = []
                mot = "Cinq, alors. On verra."          // le défaut du serveur
            } else {
                mot = "\(Self.enLettres(reponses.jours.count)) fois. On s'y tient."
            }
        case .bien:
            return                                       // il avance tout seul
        case .bienvenue:
            onFini(reponses)
            return
        }

        guard let suivante = Etape(rawValue: etape.rawValue + 1) else { return }

        // ELLE répond : un coup sec, tout de suite — MOYEN depuis le 13-09
        // (« l'haptique plus fort ») ; le fort est à lui.
        Haptique.moyen()

        // IL parle : le halo s'embrase, l'île s'ouvre — et TROIS coups montants
        // pendant qu'il parle. Deux voix, deux haptiques : le léger est à elle,
        // le moyen est à lui.
        NosfySon.paillette()
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            replique = mot
            embrase = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(110)); Haptique.moyen()
            try? await Task.sleep(for: .milliseconds(150)); Haptique.leger()
            try? await Task.sleep(for: .milliseconds(190)); Haptique.leger()
        }

        // LA PAGE CHANGE DERRIÈRE L'ÎLE, pendant qu'il parle — lentement.
        withAnimation(.easeInOut(duration: 0.85).delay(0.55)) { etape = suivante }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1900))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.92)) {
                replique = nil
                embrase = false
            }
        }
    }

    // MARK: Le banc — il joue tout seul

    /// `-nosfyAuto` : le film se répond à lui-même, du seuil à la sortie. Il ne
    /// remplace aucun verdict au doigt — il sert à CAPTURER les cinq écrans (le
    /// simulateur ne tape pas, et elle ne le voit pas depuis le remote).
    static let autoBanc = CommandLine.arguments.contains("-nosfyAuto")

    private func jouerSeul() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(7))          // le seuil se pose
            reponses.langue = "fr"; avancer(passe: false)

            try? await Task.sleep(for: .seconds(19))         // il se présente, en trois temps
            prenomSaisi = "Margaux"; avancer(passe: false)

            try? await Task.sleep(for: .seconds(6))          // l'objectif
            reponses.but = "poids"; avancer(passe: false)

            try? await Task.sleep(for: .seconds(6))          // les jours
            reponses.jours = [0, 2, 4, 6]
            avancer(passe: false)
        }
    }

    /// Il parle, il ne compte pas en chiffres.
    static func enLettres(_ n: Int) -> String {
        let mots = ["Zéro", "Une", "Deux", "Trois", "Quatre", "Cinq", "Six", "Sept"]
        return mots.indices.contains(n) ? mots[n] : "\(n)"
    }
}

// MARK: - LA SORTIE : LE PROJECTEUR (06-09)

/// ⚠️ **LA FIN D'UN FILM NE RESSEMBLE PAS À SES QUESTIONS.** Les quatre écrans
/// précédents sont éclairés par une braise au-dessus de la tête — on est dans
/// l'univers noir de Nosfy. Ici la lumière **change de camp** : elle vient d'en
/// face, elle est blanche, elle est sur ELLE. Le halo et l'île s'effacent ; le
/// projecteur ne s'ajoute pas à eux, il les remplace.
///
/// Rien n'est inventé — c'est la robe « YOU MADE IT » (`RewardCard.spotlight`),
/// recomposée avec ses propres pièces publiques :
///   · `NightSpotlight` — le shader plein écran (CounterLab.swift:41)
///   · `WoopGrain`      — le grain de la maison (Atmosphere.swift:294)
///   · `TexteGeant`     — les mots géants (RewardCard.swift:1830)
///
/// On ne passe PAS par `RewardCard` elle-même : elle n'expose pas ses lignes
/// (elle les fabrique depuis son `count`), et lui ajouter un paramètre pour nous
/// toucherait une robe réglée au pixel qui sert ailleurs. Les pièces sont
/// publiques, on les compose.
private struct SortieProjecteur: View {
    var prenom: String?
    var seances: Int
    /// L'île s'allume (t = 0,25 s) : le parent flashe l'anneau, vibre, et
    /// penche le halo en projecteur. Un seul événement déclenche tout.
    var onInterrupteur: () -> Void
    var onEntrer: () -> Void

    /// LES QUATRE TEMPS DE L'APPARITION (§3 du plan) : 0 = le halo seul ·
    /// 1 = l'île allumée, le cône descend · 2 = les mots · 3 = le nombre de
    /// verre et la poudre · 4 = Entrer. Une horloge qui MEURT au dernier temps.
    @State private var temps = 0
    @State private var naissanceMots = Date()
    @State private var naissanceVerre = Date()
    @State private var dissipe = false
    /// La coupe sur blanc (§4) : la caméra entre dans la lumière.
    @State private var voile: Double = 0
    /// L'instant du semis de la poudre — nil tant que le nombre n'est pas là.
    @State private var semee: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// « ALLEZ / MARGAUX / GO ! » — le prénom AU MILIEU, encadré par les deux
    /// mots. C'est lui qu'on doit lire en premier.
    ///
    /// ⚠️ **« ON / COMMENCE / MARGAUX » NE TENAIT PAS** (verdict au téléphone,
    /// 07-09 : « on voit pas le mot COMMENCE et le nom »). Huit lettres à
    /// 112 pt réclament 464 pt sur un écran de 393 : même échelonné, le bloc
    /// devenait si petit que les trois lignes se perdaient. Des mots COURTS
    /// sont la seule vraie réponse — 5, 7 et 4 lettres tiennent en grand.
    ///
    /// Sans prénom (elle a passé la question), il reste deux lignes — et
    /// `TexteGeant` passe alors tout seul de 112 à 128 pt.
    private var lignes: [String] {
        guard let p = prenom?.trimmingCharacters(in: .whitespaces), !p.isEmpty else {
            return ["ALLEZ", "GO !"]
        }
        return ["ALLEZ", p.uppercased(), "GO !"]
    }

    var body: some View {
        ZStack {
            // ⚠️ PLUS DE `NightSpotlight` ICI (13-09). Sa source est codée en
            // dur en haut à GAUCHE (`EclipseHalo.metal:236` : size.x × 0,17,
            // ~61° vers le bas-droite) — la lumière sautait dans un coin après
            // quatre écrans centrés sur l'île. Et c'était une TimelineView à
            // 30 Hz qui REDESSINE : la retirer est un gain, pas un coût. Le
            // projecteur est désormais le halo lui-même, penché (`HaloIle`).
            Color.clear
            WoopGrain(density: 0.028, lightAlpha: 0.022, darkAlpha: 0.028)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // TEMPS 2 — les mots arrivent DANS la lumière déjà posée.
                // La lumière avant le texte : la loi de la maison.
                if temps >= 2 {
                    TexteGeant(naissance: naissanceMots, lignes: lignes)
                        // ⚠️ **LE MOT LONG DÉBORDAIT** (vu au sim le 07-09).
                        // `TexteGeant` a `lineLimit(1)` et `fixedSize()` : il ne
                        // se replie jamais, il SORT. À 112 pt en Inter Heavy une
                        // lettre avance d'environ 58 pt tracking compris —
                        // « COMMENCE » (8) réclame 464 pt sur un écran qui en
                        // fait 393, et « MARGAUX » 406. Les deux étaient rognés.
                        //
                        // La card reward ne l'avait jamais vu : ses mots à elle
                        // font quatre lettres (YOU · MADE · IT). Dès qu'un
                        // PRÉNOM entre, la garde par compte de lettres ne suffit
                        // plus — il faut viser une LARGEUR.
                        //
                        // On échelonne le bloc ENTIER, pas chaque mot : les
                        // trois lignes gardent leur rapport, et le mot le plus
                        // long décide pour tout le monde.
                        .scaleEffect(Self.tenirDansLEcran(lignes))
                        .transition(.fonduFlou)
                }

                // TEMPS 3 — LE NOMBRE DE VERRE naît en opacité sous les mots,
                // et LA POUDRE DE DIAMANT (celle de la maison, RewardCard:911)
                // sème de part et d'autre — AUTOUR du verre, jamais dessus
                // (interdit n° 2 de la lentille : les particules ne traversent
                // pas le verre). Les deux cadres latéraux le garantissent par
                // construction, pas par chance.
                if seances > 0 {
                    HStack(spacing: 0) {
                        poudre
                        nombreDeVerre
                        poudre
                    }
                    .frame(height: 230)
                    .opacity(temps >= 3 ? 1 : 0)
                    .animation(.easeOut(duration: 0.5), value: temps)
                }

                Spacer(minLength: 0)

                // TEMPS 4 — Entrer.
                if temps >= 4 {
                    BoutonPrimaire(title: "Entrer", respecteLaCasse: true) { partir() }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 28)
                        .transition(.fonduFlou)
                }
            }

            // LA COUPE SUR BLANC (§4 du plan) — on ne passe pas par le noir, on
            // passe par la lumière qu'on a tenue tout le film. Le voile reste
            // blanc : c'est la racine qui fera arriver la home depuis lui
            // (jalon 3) — le banc s'arrête ici, sur du blanc pur.
            Color.white
                .ignoresSafeArea()
                .opacity(voile)
                .allowsHitTesting(false)
        }
        // Toute la page est tappable : « à la tap de la pop-up elle se dissipe ».
        .contentShape(Rectangle())
        .onTapGesture { partir() }
        // LE ZOOM CINÉMATIQUE : la caméra AVANCE vers le nombre (l'ancre est
        // au centre du chiffre, pas de l'écran). Le verre a déjà été retiré
        // (voir `partir`) : rien de vivant n'est redimensionné.
        .scaleEffect(dissipe ? 1.38 : 1, anchor: UnitPoint(x: 0.5, y: 0.62))
        .animation(.easeIn(duration: 0.55), value: dissipe)
        .preferredColorScheme(.dark)
        .task { await jouer() }
    }

    // MARK: Les quatre temps

    /// L'APPARITION « WAHOU » (§3 du plan), 2,4 s à l'horloge. Un seul événement
    /// déclenche tout — l'île s'allume — et le reste en découle dans l'ordre
    /// d'une scène réelle : la lampe, puis ce qu'elle éclaire, puis l'objet
    /// précieux sous la lampe. Deux voix d'haptique : *moyen* = lui, *léger* =
    /// elle. L'horloge meurt au dernier temps.
    @MainActor
    private func jouer() async {
        try? await Task.sleep(for: .milliseconds(250))
        onInterrupteur()                                          // 0,25 · l'île s'allume · moyen
        temps = 1
        try? await Task.sleep(for: .milliseconds(600))
        naissanceMots = Date()
        withAnimation(.easeOut(duration: 0.5)) { temps = 2 }      // 0,85 · les mots
        Haptique.leger()
        try? await Task.sleep(for: .milliseconds(1050))
        naissanceVerre = Date()
        if !reduceMotion { semee = Date() }
        withAnimation(.easeOut(duration: 0.5)) { temps = 3 }      // 1,90 · le verre + la poudre
        Haptique.leger()
        try? await Task.sleep(for: .milliseconds(90))
        Haptique.leger()
        try? await Task.sleep(for: .milliseconds(410))
        withAnimation(.easeOut(duration: 0.5)) { temps = 4 }      // 2,40 · Entrer
    }

    /// Le nombre de séances : un chiffre PLEIN (il doit exister pour être
    /// réfracté), et par-dessus `GaletVerre` — le galet de la robe `.galet`,
    /// tel qu'il a été validé sur la card reward. Le cône passe DERRIÈRE : c'est
    /// lui qui donne les spéculaires (sans source derrière, un verre est opaque
    /// et gris — la loi des widgets, mesurée).
    ///
    /// ⚠️ Le galet ne change JAMAIS de taille (14 img/s sinon, mesuré) : il naît
    /// en opacité avec son bloc, et il est RETIRÉ au tap — jamais dans le zoom.
    /// Le chiffre plein qui reste est son jumeau plat.
    private var nombreDeVerre: some View {
        Text("\(seances)")
            .font(.inter(190, .heavy))
            .foregroundStyle(.white)
            .fixedSize()
            .overlay {
                if !dissipe {
                    GaletVerre(naissance: naissanceVerre)
                }
            }
    }

    /// Un cadre de poudre de chaque côté du nombre. Avant le semis : rien —
    /// aucune horloge ne tourne pour rien.
    private var poudre: some View {
        Group {
            if let semee {
                PoudreDiamant(largeur: 96, hauteur: 230, naissance: semee)
            } else {
                Color.clear
            }
        }
        .frame(width: 96, height: 230)
        .allowsHitTesting(false)
    }

    /// La largeur utile de l'écran, moins une marge de sécurité.
    private static let utile: CGFloat = 356
    /// L'avance moyenne d'une lettre d'Inter Heavy à 112 pt, tracking −3
    /// compris — mesurée sur la capture du 07-09.
    private static let avance: CGFloat = 58

    static func tenirDansLEcran(_ lignes: [String]) -> CGFloat {
        let plusLong = lignes.map(\.count).max() ?? 1
        return min(1, utile / (CGFloat(plusLong) * avance))
    }

    /// LE ZOOM CINÉMATIQUE (§4 du plan). Au tap : le galet tombe (son jumeau
    /// plat reste, même chiffre, même place), la caméra avance 0,55 s, le voile
    /// monte au blanc à partir de 0,20, et à 0,55 c'est la coupe — sur du blanc
    /// pur. Un tap avant que les mots soient là ne fait rien : on ne zoome pas
    /// sur une scène vide.
    private func partir() {
        guard !dissipe, temps >= 2 else { return }
        NosfySon.tap()
        NosfySon.musique(false)                      // la musique s'éteint avec la page
        Haptique.moyen()
        if !reduceMotion { semee = Date() }          // la poudre du départ, devant le blanc
        dissipe = true                               // le galet tombe · la caméra avance
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeIn(duration: 0.35)) { voile = 1 }   // le cône monte au blanc
            try? await Task.sleep(for: .milliseconds(150))
            Haptique.leger()
            try? await Task.sleep(for: .milliseconds(200))          // 0,55 · coupe sur blanc
            onEntrer()
        }
    }

}


// MARK: - L'ÎLE : la jauge autour du trou, et la voix

/// ⚠️ **LE BUG DU 06-09, VU AU TÉLÉPHONE.** La jauge était une `Capsule` avec un
/// `.rotationEffect(-90°)` pour faire partir le tracé en haut : la rotation
/// retourne la FORME, donc un anneau de 128×39 devenait un anneau de 39×128,
/// dressé et pendant sous l'île. On ne fait pas tourner une forme pour déplacer
/// le départ de son tracé.
///
/// L'anneau ENTOURE le trou physique (126×37 à 11 pt du bord, mesuré) et il est
/// **vivant en permanence** : un reflet tourne autour de lui, et sa lueur
/// respire. Il n'attend pas qu'on lui parle pour exister.
private struct IleNosfy: View {
    var tiers: Int
    var replique: String?
    var calme: Bool
    /// L'INTERRUPTEUR (§3 du plan) : à la sortie, l'anneau FLASHE blanc —
    /// épaisseur ×2,2 pendant 0,18 s — c'est lui qui allume le projecteur.
    var flash: Bool = false

    @State private var tour: Double = 0
    /// La respiration du TRAIT — pas de la forme.
    @State private var souffleTrait = false

    private var ouverte: Bool { replique != nil }
    private static let largeur: CGFloat = 126 + 10
    private static let hauteur: CGFloat = 37 + 10

    /// ⚠️ **VERDICT 06-09 : « l'île ne doit pas GRANDIR ».** L'animation de
    /// l'avancement est dans **l'ÉPAISSEUR DU TRAIT**, jamais dans la taille de
    /// la pastille : elle est un trou physique dans la dalle, la faire enfler
    /// est un mensonge. Chaque question franchie épaissit l'anneau — 1,4 · 2,2 ·
    /// 3,0 · 3,8 — et l'arc voyage lentement pour qu'on VOIE l'étape passer.
    private var epaisseur: CGFloat { 1.4 + CGFloat(tiers) * 0.8 }

    var body: some View {
        Capsule()
            .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            .overlay {
                // LE REFLET QUI TOURNE — la présence permanente de l'île. Son
                // trait respire lui aussi : c'est ça, l'île « animée de base ».
                Capsule()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [.white.opacity(0.02),
                                                        .white.opacity(0.85),
                                                        .white.opacity(0.02)]),
                            center: .center,
                            angle: .degrees(tour)),
                        lineWidth: souffleTrait ? 2.2 : 1.1)
            }
            .overlay {
                // LA JAUGE : l'anneau se remplit ET s'épaissit, une question à
                // la fois. L'arc met 1,3 s à parcourir son tiers — on le voit.
                Capsule()
                    .trim(from: 0, to: min(1, Double(tiers) / 3))
                    .stroke(
                        LinearGradient(colors: [.white, .white.opacity(0.55)],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: flash ? epaisseur * 2.2 + 2
                                                       : (ouverte ? epaisseur + 1.4 : epaisseur),
                                           lineCap: .round))
                    .shadow(color: .white.opacity(flash ? 1 : 0.75), radius: flash ? 18 : 8)
                    .animation(.easeInOut(duration: 1.3), value: tiers)
                    .animation(.spring(response: 0.45, dampingFraction: 0.7), value: ouverte)
                    .animation(.spring(response: 0.22, dampingFraction: 0.6), value: flash)
            }
            .overlay {
                if let replique {
                    Text(replique)
                        .font(.inter(13, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 18)
                        .transition(.opacity)
                }
            }
            // ⚠️ La LARGEUR ne bouge que pour porter la phrase — et seulement
            // pendant qu'il parle. Au repos, l'île garde exactement les cotes du
            // trou : elle ne respire jamais en taille.
            .frame(width: ouverte ? 266 : Self.largeur, height: Self.hauteur)
            .shadow(color: .white.opacity(flash ? 0.95 : (ouverte ? 0.55 : 0.20)),
                    radius: flash ? 30 : (ouverte ? 20 : 9))
            .shadow(color: Color(red: 1, green: 0.5, blue: 0.2).opacity(ouverte ? 0.38 : 0.14),
                    radius: ouverte ? 26 : 15)
            .padding(.top, 11 - 5)
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .onAppear {
                guard !calme else { return }
                withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                    tour = 360
                }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    souffleTrait = true
                }
            }
    }
}

// MARK: - LE HALO — la seule lumière, et elle vit toute seule

/// Halo blanc DERRIÈRE l'île, braise rouge→orange autour.
///
/// ⚠️ **LE BRUN, MESURÉ AU SIM LE 06-09.** Des braises posées en opacité normale
/// sur le noir donnent un nuage BRUN : un orange qu'on éteint perd sa saturation
/// avant sa luminance. Le remède est le mode de fusion, pas la couleur —
/// `.plusLighter` AJOUTE la lumière au noir au lieu de l'y moyenner.
///
/// **TROIS VIES** (verdict 06-09, « beaucoup plus présent et animé de base ») :
/// il RESPIRE lentement, une braise DÉRIVE en dessous à un autre rythme, et il
/// S'EMBRASE quand Nosfy parle. Les trois horloges ont des durées premières
/// entre elles — c'est ce qui empêche l'œil de trouver la boucle.
struct HaloIle: View {
    var embrase: Bool = false
    var calme: Bool = false
    /// LE PROJECTEUR (13-09, `PLAN-SORTIE-PROJECTEUR.md` §1) : à la sortie du
    /// film le halo ne s'éteint pas, il se PENCHE. Les braises quittent la
    /// scène (la couleur s'en va — la fin n'est plus dans l'univers noir de
    /// Nosfy, elle est sur elle) et la capsule blanche derrière l'île s'étire
    /// vers le bas en cône. C'est le MÊME objet qui éclaire les quatre
    /// questions et la sortie : la continuité n'est pas un raccord, c'est une
    /// identité.
    var projecteur: Bool = false
    /// La poussée par mot (voir `NosfyOnboarding.battre`) : +4 % d'échelle, la
    /// capsule blanche 0,58 → 0,74 le temps du mot. Une transformation, jamais
    /// le flou ni la couleur — ça redessinerait.
    var battement: Bool = false

    @State private var respire = false
    @State private var derive = false
    /// La langue de braise fait le tour — le mouvement qui ne pulse pas.
    @State private var tourne = false
    @State private var lent = false

    private static let cote: CGFloat = 380
    private static let ileCentre: CGFloat = 11 + 37 / 2
    private static let coneHauteur: CGFloat = 600

    var body: some View {
        ZStack {
          // LES BRAISES — un seul groupe, pour qu'elles s'éteignent ENSEMBLE
          // quand le projecteur prend la scène (§1 du plan : 0,9 s).
          Group {
            // ① LA NAPPE LENTE — large, sourde, elle ne fait que teinter la nuit.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 0.95, green: 0.30, blue: 0.12).opacity(0.30),
                             Color(red: 0.70, green: 0.06, blue: 0.14).opacity(0.16),
                             .clear],
                    center: .center, startRadius: 10, endRadius: 230))
                .frame(width: 470, height: 470)
                .blur(radius: 44)
                .blendMode(.plusLighter)
                .scaleEffect(lent ? 1.30 : 0.85)
                .opacity(lent ? 1.0 : 0.55)

            // ② LA BRAISE — orange vif au cœur, rouge profond au bord.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.00, green: 0.70, blue: 0.34).opacity(0.95),
                             Color(red: 1.00, green: 0.42, blue: 0.12).opacity(0.62),
                             Color(red: 0.93, green: 0.09, blue: 0.16).opacity(0.34),
                             .clear],
                    center: .center, startRadius: 2, endRadius: 165))
                .frame(width: Self.cote, height: Self.cote)
                .blur(radius: 26)
                .blendMode(.plusLighter)

            // ③ LA BRAISE VAGABONDE — décalée, plus lente : c'est elle qui donne
            //    l'impression que la lumière VIT au lieu de clignoter en bloc.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.00, green: 0.48, blue: 0.16).opacity(0.52),
                             Color(red: 0.88, green: 0.11, blue: 0.17).opacity(0.24),
                             .clear],
                    center: .center, startRadius: 4, endRadius: 135))
                .frame(width: 275, height: 275)
                .blur(radius: 34)
                .blendMode(.plusLighter)
                .offset(x: derive ? 110 : -100, y: derive ? 60 : -40)
                .scaleEffect(derive ? 1.34 : 0.80)

            // ⑤ LA LANGUE DE BRAISE — elle TOURNE lentement autour du centre.
            //    C'est le mouvement qui manquait : les autres pulsent, celle-ci
            //    fait le tour, donc la lumière n'a plus de repos nulle part.
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color(red: 1.00, green: 0.56, blue: 0.20).opacity(0.34),
                             .clear],
                    center: .center, startRadius: 2, endRadius: 95))
                .frame(width: 210, height: 150)
                .blur(radius: 28)
                .blendMode(.plusLighter)
                .offset(y: -34)
                .rotationEffect(.degrees(tourne ? 360 : 0))

          }
          .opacity(projecteur ? 0 : 1)
          .animation(.easeOut(duration: 0.9), value: projecteur)

            // ⑥ LE CÔNE — le projecteur lui-même. Un trapèze ancré à l'île
            //    (`anchor: .top`) qui POUSSE vers le bas : il ne grandit pas
            //    depuis son centre, il part du haut du téléphone. Aucune
            //    horloge : une valeur animée, jamais un redessin.
            //    ⚠️ Pas de `.mask` sur le texte pour le « révéler » — c'est un
            //    balayage, la famille d'effets que les interdits nomment.
            Cone(hautLargeur: 70)
                .fill(LinearGradient(
                    stops: [.init(color: .white.opacity(0.62), location: 0),
                            .init(color: .white.opacity(0.22), location: 0.45),
                            .init(color: .white.opacity(0.0), location: 1)],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 330, height: Self.coneHauteur)
                .blur(radius: 28)
                .blendMode(.plusLighter)
                .scaleEffect(x: 1, y: projecteur ? 1 : 0.02, anchor: .top)
                .opacity(projecteur ? 1 : 0)
                // Le sommet du cône sur le centre de l'île : le ZStack est
                // centré là (voir l'offset plus bas), on le pend de moitié.
                .offset(y: Self.coneHauteur / 2)
                .animation(.easeOut(duration: 0.7), value: projecteur)

            // ④ LE HALO BLANC, derrière l'île — il s'INTENSIFIE quand le
            //    projecteur s'allume : c'est de lui que part le cône.
            Capsule()
                .fill(.white)
                .frame(width: 224, height: 68)
                .blur(radius: 24)
                .opacity(projecteur ? 0.85 : (battement ? 0.92 : 0.58))
                .scaleEffect(projecteur ? 1.25 : 1)
                .blendMode(.plusLighter)
                .animation(.easeOut(duration: 0.7), value: projecteur)
                .animation(.spring(response: 0.35, dampingFraction: 0.55), value: battement)
        }
        // ⚠️ Le cône fait 600 pt de haut : sans cette cote fixe, c'est LUI qui
        // dimensionnerait le ZStack et décalerait tout l'offset ci-dessous.
        .frame(width: Self.cote, height: Self.cote)
        .offset(y: Self.ileCentre - Self.cote / 2)
        // « DIX FOIS PLUS » (13-09) : pas une couche de plus — de l'AMPLITUDE et
        // des périodes plus courtes, sur les mêmes transformations. Le flou et la
        // couleur ne bougent toujours pas : c'est ce qui redessine.
        .scaleEffect((respire ? 1.26 : 0.88) * (embrase ? 1.50 : 1.0) * (battement ? 1.10 : 1.0))
        .opacity((respire ? 1.0 : 0.74) * (embrase ? 1.0 : 0.88))
        .animation(.spring(response: 0.75, dampingFraction: 0.68), value: embrase)
        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: battement)
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            guard !calme else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                respire = true
            }
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                derive = true
            }
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                lent = true
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                tourne = true
            }
        }
    }
}

// MARK: - LA BÊTE : le lecteur de l'accueil

/// `NosfyReel` — l'école de `ReelHote` (PorteEntree) : une `AVPlayerLayer` en
/// `resizeAspect` (la bande a le ratio du fichier, rien à rogner),
/// `clipsToBounds` + `masksToBounds` (SwiftUI ne rattrape pas UIKit), et un
/// `AVPlayerLooper` pour la boucle — jamais un seek qui rebrousse. Muet.
/// Le fichier est cuit par `tools/porte/recuit_nosfy.sh` : ping-pong sans
/// couture, extinctions haut et bas dans le fichier, fond noir vrai.
///
/// ⚠️ `VideoReward` (RewardCard) aurait fait l'affaire — mais il est `private`,
/// et il porte des mécaniques de card (relance, recul, gel) dont l'accueil
/// n'a que faire. Quarante lignes à nous valent mieux qu'un mot dans un
/// fichier partagé.
private struct NosfyReel: UIViewRepresentable {
    let nom: String

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
        guard let url = Bundle.main.url(forResource: nom, withExtension: "mp4") else { return v }
        let item = AVPlayerItem(url: url)
        let lecteur = AVQueuePlayer()
        lecteur.isMuted = true
        lecteur.preventsDisplaySleepDuringVideoPlayback = false
        v.boucle = AVPlayerLooper(player: lecteur, templateItem: item)
        v.lecteur = lecteur
        v.playerLayer.player = lecteur
        lecteur.play()
        return v
    }

    func updateUIView(_ uiView: Vue, context: Context) {}

    /// DÉMONTÉ, pas caché : quand la vue sort de l'arbre, le lecteur s'arrête et
    /// la boucle meurt avec lui.
    static func dismantleUIView(_ uiView: Vue, coordinator: ()) {
        uiView.lecteur?.pause()
        uiView.boucle = nil
        uiView.playerLayer.player = nil
    }
}

// MARK: - LE SON DU FILM (13-09)

/// « Une petite musique de fond magique mais pas princesse, discrète — et quand
/// j'appuie sur un bouton, un bruit. »
///
/// LA MUSIQUE : `MoonSplashTheme` (Woop/Sounds, 15,6 s — le thème de la lune de
/// sang, déjà validé au splash), EN BOUCLE, à 18 %, fondu d'entrée 1,5 s, fondu
/// de sortie 1,2 s. C'est un choix par défaut : je ne peux pas écouter. Pour en
/// changer, poser un fichier dans Woop/Sounds et remplacer `theme` ci-dessous.
/// LES BRUITS : `DialTap` au tap (cards, jours, Passer, Entrer) ; `Paillette`
/// quand Nosfy répond dans l'île.
///
/// Les lecteurs sont RETENUS (un `AVAudioPlayer` local meurt avant d'avoir
/// joué — la leçon de `PiluleVagabonde`). Catégorie `.ambient` : on se mêle à
/// la musique de l'utilisatrice et on respecte l'interrupteur silence.
enum NosfySon {
    private static let theme = "MoonSplashTheme"
    private static var musique: AVAudioPlayer?
    private static var bruits: [String: AVAudioPlayer] = [:]
    private static var sessionPrete = false

    private static func preparerSession() {
        guard !sessionPrete else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        sessionPrete = true
    }

    /// La musique monte quand le film s'ouvre ; elle est la même jusqu'au bout.
    static func musique(_ allumer: Bool) {
        preparerSession()
        if allumer {
            guard musique == nil else { return }
            guard let url = Bundle.main.url(forResource: theme, withExtension: "m4a"),
                  let p = try? AVAudioPlayer(contentsOf: url) else { return }
            p.numberOfLoops = -1
            p.volume = 0
            p.prepareToPlay()
            p.play()
            p.setVolume(0.18, fadeDuration: 1.5)
            musique = p
        } else {
            guard let p = musique else { return }
            p.setVolume(0, fadeDuration: 1.2)
            musique = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { p.stop() }
        }
    }

    static func tap() { bruit("DialTap", "wav", volume: 0.55) }
    static func paillette() { bruit("Paillette", "wav", volume: 0.5) }

    private static func bruit(_ nom: String, _ ext: String, volume: Float) {
        preparerSession()
        let p: AVAudioPlayer
        if let existant = bruits[nom] {
            p = existant
        } else {
            guard let url = Bundle.main.url(forResource: nom, withExtension: ext),
                  let neuf = try? AVAudioPlayer(contentsOf: url) else { return }
            neuf.prepareToPlay()
            bruits[nom] = neuf
            p = neuf
        }
        p.volume = volume
        p.currentTime = 0
        p.play()
    }
}

/// LA VOIX FORTE (13-09, « l'haptique plus fort ») : un troisième coup, lourd,
/// déclaré ICI — `NavEncre.swift` est aux autres sessions. La grammaire monte
/// d'un cran : elle répond = moyen, il parle = fort, le flash de l'île = fort.
/// Pas de coup par mot : trente vibrations en dix secondes n'appuient plus,
/// elles engourdissent. Le simulateur n'a pas de moteur : verdict au téléphone.
extension Haptique {
    private static let lourd = UIImpactFeedbackGenerator(style: .heavy)
    static func fort() {
        lourd.impactOccurred(intensity: 1.0)
        lourd.prepare()
    }
}

/// Le trapèze du projecteur : étroit au sommet (la largeur de l'île), il
/// s'ouvre jusqu'au bas de son cadre.
private struct Cone: Shape {
    var hautLargeur: CGFloat = 70
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - hautLargeur / 2, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + hautLargeur / 2, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - LE FONDU-FLOU DU TEXTE, mot par mot

/// Chaque mot sort du flou en montant, décalé sur le précédent, avec une
/// respiration après chaque ponctuation forte. C'est un débit de parole, jamais
/// une machine à écrire — et il est LENT (verdict 06-09 : « plus lent, à la
/// Apple »).
///
/// ⚠️ **INTER**, la fonte de la maison — la même que « Hello Kathryn, » sur la
/// home. Le premier jet était en `.system(design: .rounded)` : verdict au
/// téléphone, « ce n'est pas du tout ça ».
///
/// **L'ALTERNANCE** : un fragment `clair` est en blanc dégradé, le suivant en
/// gris sourd. C'est la voix de la home, reprise mot pour mot.
struct MotsFlou: View {

    private struct Mot: Identifiable {
        let id: Int
        let texte: String
        let clair: Bool
        let retard: Double
    }

    private let mots: [Mot]
    private let taille: CGFloat
    /// Prévenu à CHAQUE mot qui apparaît — c'est ce qui fait battre le halo.
    private let onMot: (() -> Void)?

    @State private var poses = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le sourd de la nuit — la même valeur que la phrase de la home.
    private static let sourd: Double = 0.42

    init(_ fragments: [(String, Bool)], taille: CGFloat = 22, base: Double = 0,
         onMot: (() -> Void)? = nil) {
        self.taille = taille
        self.mots = Self.calendrier(fragments, base: base)
        self.onMot = onMot
    }

    /// Combien de temps la tirade met à se dire, en entier — la dernière
    /// apparition comprise. C'est ce que `Tirade` attend avant d'enchaîner.
    static func duree(_ fragments: [(String, Bool)]) -> Double {
        (calendrier(fragments, base: 0).last?.retard ?? 0) + 0.78
    }

    /// LE PHRASÉ, calculé une fois — voir la note ci-dessous.
    private static func calendrier(_ fragments: [(String, Bool)], base: Double) -> [Mot] {
        var t = base
        var sortie: [Mot] = []
        var n = 0
        // ⚠️ **UNE CADENCE RÉGULIÈRE S'ENTEND COMME UNE MACHINE** (verdict
        // 06-09 : « comme si l'IA parlait vraiment, c'est pas prédéfini »). Trois
        // choses cassent la mécanique : un mot LONG prend plus de temps qu'un
        // mot court, la ponctuation tient une vraie respiration, et un décalage
        // minuscule — tiré des lettres du mot, donc toujours le même — empêche
        // l'oreille de trouver le métronome.
        for (i, fragment) in fragments.enumerated() {
            if i > 0 { t += 0.34 }               // le silence entre deux fragments
            let mots = fragment.0.split(separator: " ").map(String.init)
            for (j, mot) in mots.enumerated() {
                if j > 0, let dernier = mots[j - 1].last, ".?!:,;".contains(dernier) {
                    t += ",;".contains(dernier) ? 0.16 : 0.40   // la respiration
                }
                sortie.append(Mot(id: n, texte: mot, clair: fragment.1, retard: t))

                let lettres = Double(mot.count)
                let grain = Double(mot.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 5) * 0.012
                t += 0.05 + lettres * 0.013 + grain
                n += 1
            }
        }
        return sortie
    }

    var body: some View {
        // « ENCORE PLUS APPLE » (13-09) — ce n'est pas UNE chose mais quatre :
        // le tracking serré (−2,6 % du corps), une montée de 5 pt seulement
        // (il se POSE, il ne monte pas), une échelle 0,96 → 1 (le mot arrive de
        // légèrement plus loin), et surtout la COURBE : départ vif, très long
        // amortissement — c'est elle qu'on sent et qu'on ne capture pas.
        Flot(espaceH: taille * 0.27, espaceV: taille * 0.58) {
            ForEach(mots) { mot in
                Text(mot.texte)
                    .font(.inter(taille, .semibold))
                    .tracking(-taille * 0.026)
                    .foregroundStyle(mot.clair
                                     ? AnyShapeStyle(Self.blancDegrade)
                                     : AnyShapeStyle(Color.white.opacity(Self.sourd)))
                    .blur(radius: poses ? 0 : 8)
                    .opacity(poses ? 1 : 0)
                    .scaleEffect(poses ? 1 : 0.96)
                    .offset(y: poses ? 0 : 5)
                    .animation(reduceMotion ? nil
                               : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.9).delay(mot.retard),
                               value: poses)
            }
        }
        // La tirade prend TOUTE la largeur offerte et s'aligne à gauche : sans
        // ça elle est centrée par son parent, et le débordement revient.
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { poses = true }
        // LE BATTEMENT : une horloge qui suit le phrasé et MEURT au dernier mot.
        .task {
            guard let onMot, !reduceMotion else { return }
            var t = 0.0
            for mot in mots {
                let d = mot.retard - t
                if d > 0 { try? await Task.sleep(for: .seconds(d)) }
                guard !Task.isCancelled else { return }
                t = mot.retard
                onMot()
            }
        }
    }

    /// Le blanc dégradé de la maison — blanc en haut, gris perle en bas.
    private static let blancDegrade = LinearGradient(
        colors: [.white,
                 Color(red: 0.86, green: 0.85, blue: 0.90),
                 Color(red: 0.62, green: 0.60, blue: 0.67)],
        startPoint: .top, endPoint: .bottom)
}

// MARK: - LA TIRADE : une phrase à la fois

/// ⚠️ **ONZE LIGNES SUR UN ÉCRAN, VU AU TÉLÉPHONE LE 06-09.** À 30 pt — la
/// taille de la home — trois blocs empilés remplissaient l'écran du haut en bas :
/// le texte montait DANS le halo (illisible sur la braise) et il ne restait plus
/// un point d'air.
///
/// Quelqu'un qui parle ne pose pas tout son discours d'un coup : il dit une
/// phrase, puis la suivante. Chaque phrase remplace donc la précédente **dans le
/// même fondu-flou** que les pages — elle sort du flou, elle y retourne. L'écran
/// respire, et on écoute au lieu de lire.
private struct Tirade: View {
    let blocs: [[(String, Bool)]]
    var taille: CGFloat = 30
    /// Le silence après la dernière syllabe, avant d'enchaîner.
    var repos: Double = 1.35
    var onMot: (() -> Void)? = nil
    var onFini: () -> Void = {}

    init(blocs: [[(String, Bool)]], taille: CGFloat = 30, repos: Double = 1.35,
         onMot: (() -> Void)? = nil, onFini: @escaping () -> Void = {}) {
        self.blocs = blocs
        self.taille = taille
        self.repos = repos
        self.onMot = onMot
        self.onFini = onFini
    }

    @State private var index = 0

    var body: some View {
        MotsFlou(blocs[index], taille: taille, onMot: onMot)
            .id(index)
            .transition(.fonduFlou)
            .task(id: index) {
                let attente = MotsFlou.duree(blocs[index]) + repos
                try? await Task.sleep(for: .seconds(attente))
                guard !Task.isCancelled else { return }
                if index + 1 < blocs.count {
                    withAnimation(.easeInOut(duration: 0.8)) { index += 1 }
                } else {
                    onFini()
                }
            }
    }
}

/// Une mise en page qui va à la ligne — SwiftUI n'en a pas, et le fondu mot par
/// mot en a besoin (chaque mot doit être une vue à part pour porter son retard).
struct Flot: Layout {
    var espaceH: CGFloat = 6
    var espaceV: CGFloat = 6

    /// ⚠️ **LE DÉBORDEMENT DU 06-09, VU AU SIM.** Ce calcul rendait `large`
    /// comme largeur — c'est-à-dire 340 pt en dur quand SwiftUI ne propose
    /// AUCUNE largeur (la passe de mesure « unspecified »). Le VStack parent
    /// adoptait donc 340, plus large que les 333 disponibles, et centrait le
    /// bloc : le texte sortait de l'écran des DEUX côtés.
    ///
    /// La règle : une mise en page rend **la largeur qu'elle occupe vraiment**,
    /// jamais celle qu'on lui a proposée.
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let large: CGFloat = {
            guard let l = proposal.width, l.isFinite, l > 0 else { return 10_000 }
            return l
        }()
        var x: CGFloat = 0, y: CGFloat = 0, ligne: CGFloat = 0, occupee: CGFloat = 0
        for vue in subviews {
            let t = vue.sizeThatFits(.unspecified)
            if x + t.width > large, x > 0 {
                occupee = max(occupee, x - espaceH)
                x = 0; y += ligne + espaceV; ligne = 0
            }
            x += t.width + espaceH
            ligne = max(ligne, t.height)
        }
        occupee = max(occupee, x - espaceH)

        // ⚠️ **LE CHEVAUCHEMENT DU 06-09, VU AU TÉLÉPHONE.** Rendre `occupee`
        // (plus étroit que la proposition) semblait propre — mais alors
        // `placeSubviews` reçoit des bornes PLUS ÉTROITES que celles qui ont
        // servi à mesurer : les mots se replient sur plus de lignes que prévu,
        // la hauteur annoncée est trop petite, et le bloc suivant se pose PAR
        // DESSUS. « Bienvenue, Margaux. » et la phrase de sortie s'écrivaient
        // l'une sur l'autre.
        //
        // La règle : **mesurer et placer sur la MÊME largeur.** On rend donc la
        // largeur proposée dès qu'elle est finie ; `occupee` ne sert que pour la
        // passe « unspecified », où personne ne place rien.
        return CGSize(width: large == 10_000 ? occupee : large, height: y + ligne)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, ligne: CGFloat = 0
        for vue in subviews {
            let t = vue.sizeThatFits(.unspecified)
            if x + t.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += ligne + espaceV; ligne = 0
            }
            vue.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(t))
            x += t.width + espaceH
            ligne = max(ligne, t.height)
        }
    }
}

// MARK: - LA TRANSITION : le fondu-flou, la signature du film

/// ⚠️ `.blur` pose un voile uniforme sur TOUT le rectangle de l'hôte : le flou se
/// met donc sur la couche de CONTENU, jamais sur la page — le halo et l'île ne
/// bronchent pas d'un pixel pendant le passage.
private struct FlouAnime: ViewModifier, Animatable {
    var rayon: CGFloat
    var animatableData: CGFloat {
        get { rayon }
        set { rayon = newValue }
    }
    func body(content: Content) -> some View { content.blur(radius: rayon) }
}

extension AnyTransition {
    /// Sortante : elle s'éloigne dans le flou. Entrante : elle en sort. Elles se
    /// croisent — il y a un instant où l'écran ne porte que le halo, et c'est ce
    /// trou-là qui fait la respiration.
    static var fonduFlou: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: FlouAnime(rayon: 22), identity: FlouAnime(rayon: 0))
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.965)),
            removal: .modifier(active: FlouAnime(rayon: 26), identity: FlouAnime(rayon: 0))
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.05)))
    }
}

/// Fait entrer un bloc APRÈS la tirade, sans le faire clignoter au montage.
private struct Retarde: ViewModifier {
    var apres: Double
    @State private var pose = false
    func body(content: Content) -> some View {
        content
            .opacity(pose ? 1 : 0)
            .blur(radius: pose ? 0 : 10)
            .offset(y: pose ? 0 : 10)
            .animation(.easeOut(duration: 0.7), value: pose)
            .task {
                try? await Task.sleep(for: .seconds(apres))
                pose = true
            }
    }
}

// MARK: - Les réponses : une card = une réponse, et le film avance

/// ⚠️ **PLUS DE BOUTON (06-09).** Toucher la card répond ET avance : il n'y a
/// plus rien entre elle et la suite. La card s'allume une fraction de seconde
/// avant que la page parte — elle voit ce qu'elle a choisi.
///
/// ⚠️ La card allumée gagne en LUMIÈRE, jamais en taille : du verre qu'on
/// redimensionne image par image tombe à 14 img/s (loi mesurée).
private struct CardVerre: View {
    var titre: String
    var action: () -> Void

    @State private var allumee = false

    var body: some View {
        Button {
            NosfySon.tap()
            withAnimation(.easeOut(duration: 0.22)) { allumee = true }
            action()
        } label: {
            Text(titre)
                .font(.inter(17, .semibold))
                .foregroundStyle(.white.opacity(allumee ? 1 : 0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 19)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(
                            colors: allumee
                                ? [.white.opacity(0.26), .white.opacity(0.10)]
                                : [.white.opacity(0.10), .white.opacity(0.035)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(.white.opacity(allumee ? 0.50 : 0.14), lineWidth: 1)
                        }
                        .shadow(color: .white.opacity(allumee ? 0.16 : 0), radius: 16)
                }
        }
        .buttonStyle(.plain)
    }
}

/// Le composant de la card Régularité, retourné : mêmes lettres, mêmes perles,
/// mais on CHOISIT au lieu de constater. Plusieurs jours se cochent, donc c'est
/// le seul écran qui ne part pas au premier tap.
private struct SemaineTapable: View {
    var choisis: Set<Int>
    var onTap: (Int) -> Void

    private let lettres = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let on = choisis.contains(i)
                Button {
                    NosfySon.tap()
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.68)) { onTap(i) }
                } label: {
                    VStack(spacing: 8) {
                        Text(lettres[i])
                            .font(.inter(12.5, .medium))
                            .foregroundStyle(.white.opacity(on ? 0.95 : 0.36))
                        Circle()
                            .fill(.white.opacity(on ? 1 : 0.16))
                            .frame(width: 6, height: 6)
                            .shadow(color: .white.opacity(on ? 0.9 : 0), radius: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(.white.opacity(on ? 0.13 : 0.035))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(.white.opacity(on ? 0.44 : 0.12), lineWidth: 1)
                            }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}
