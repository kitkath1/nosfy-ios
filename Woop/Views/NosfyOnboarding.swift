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

    @State private var etape: Etape = .intro
    /// L'INTRO (PLAN-INTRO-NUIT.md) : −1 = le noir · 0/1/2 = les trois temps du
    /// poème · 3 = la citation sur le noir. Une horloge qui meurt à l'accueil.
    @State private var tempsIntro = -1
    /// LE BARREAU de la vidéo (`-sansNosfyVideo`) : le poster à sa place — sans
    /// lui on ne pourra ni l'accuser ni la disculper à la mesure.
    static let sansVideo = CommandLine.arguments.contains("-sansNosfyVideo")
    @State private var reponses = Reponses()
    @State private var replique: String?
    @State private var prenomSaisi = ""
    /// Le refus du prénom vide (13-09) : le message du champ est rouge.
    @State private var prenomRefuse = false
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

    /// L'intro et la fin sont des plans : pas de marge, pas de halo.
    private var pleinEcran: Bool { etape == .bienvenue || etape == .fin }

    /// L'ALLUMAGE — 1,2 s : le halo s'épanouit depuis l'île sur un ressort lent,
    /// et quand il est plein l'anneau FLASHE avec sa voix (fort). Il se joue à
    /// l'ACCUEIL, après le noir de l'intro — la lumière naît de ce noir-là. Sous
    /// Reduce Motion : tout est là d'un coup. Ma musique est déjà montée
    /// pendant la dernière seconde du plan (voir `jouerIntro`).
    private func allumer() {
        NosfySon.musique(true)                       // sans effet si elle joue déjà
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
    }

    /// L'HORLOGE DE L'INTRO (PLAN-INTRO-NUIT.md §4) : les trois temps du poème
    /// sur le vol, la passation du son à 7,0 s (la piste de la vidéo s'éteint
    /// dans le fichier pendant que la mienne monte), la citation sur le noir à
    /// 8,3 s, l'accueil à 10,5 s. Elle meurt si elle tape.
    @MainActor
    private func jouerIntro() async {
        // ⚠️ « ÇA VA TROP VITE » (13-09 soir) : à 0,6 / 3,2 / 5,8 chaque phrase
        // était remplacée avant d'avoir fini de se poser. Les temps s'écartent,
        // le troisième tient sur la lune ET sur le noir qui suit (le plan tient
        // sa dernière image, noire — invisible sur le noir), la citation arrive
        // à 10,8, l'accueil à 14,0. Le mot par mot est ralenti d'un tiers.
        // Sur la vidéo ralentie à 12 s (PLAN-INTRO-NUIT §11) : les temps à
        // 1,0 / 5,0 / 8,6 (le troisième sur la lune, ≈ 8,7 s ralentie), la
        // passation du son à 10,5, la citation à 13,4, l'accueil à 17,0.
        let pas: [(Double, Int)] = [(1.0, 0), (5.0, 1), (8.6, 2)]
        var t = 0.0
        for (quand, temps) in pas {
            try? await Task.sleep(for: .seconds(quand - t)); t = quand
            guard etape == .intro else { return }
            withAnimation(.easeInOut(duration: 0.9)) { tempsIntro = temps }
        }
        try? await Task.sleep(for: .seconds(10.5 - t)); t = 10.5
        guard etape == .intro else { return }
        NosfySon.musique(true)                       // la passation : 1,5 s de montée
        try? await Task.sleep(for: .seconds(13.4 - t)); t = 13.4
        guard etape == .intro else { return }
        Haptique.fort()
        withAnimation(.easeInOut(duration: 0.9)) { tempsIntro = 3 }
        try? await Task.sleep(for: .seconds(17.0 - t))
        guard etape == .intro else { return }
        withAnimation(.easeInOut(duration: 0.9)) { etape = .accueil }
    }

    // MARK: - LA LANGUE DU FILM (13-09 : « j'ai cliqué anglais, ça devrait
    // faire le chemin en anglais »)

    /// Le choix du seuil bascule TOUT ce qui suit : les questions, les cards,
    /// les répliques de l'île, Passer, la sortie. Une table à deux colonnes,
    /// ici, dans le film — la traduction de l'APP est un autre chantier
    /// (269 chaînes, voir PLAN-COMPTE-ONBOARDING §05).
    private var en: Bool { reponses.langue == "en" }
    private func L(_ fr: String, _ en: String) -> String { self.en ? en : fr }

    /// « Quatre fois. » / « Four times. » — il parle, il ne compte pas en chiffres.
    static func fois(_ n: Int, en: Bool) -> String {
        if en {
            let mots = ["Zero", "Once", "Twice", "Three", "Four", "Five", "Six", "Seven"]
            let m = mots.indices.contains(n) ? mots[n] : "\(n)"
            return n <= 2 ? "\(m)." : "\(m) times."
        }
        return enLettres(n) + " fois."
    }
    @State private var minuterieJours: Task<Void, Never>?
    @FocusState private var prenomActif: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Etape: Int, CaseIterable {
        case intro, accueil, langue, prenom, but, jours, bien, fin, bienvenue

        /// Le rang dans la jauge : l'intro, l'accueil et la langue ne sont pas
        /// des questions — le plan, la rencontre, le seuil ; la sortie non plus,
        /// la boucle est fermée. « Bien. » est le mot de fin, « fin » son plan.
        var tiers: Int {
            switch self {
            case .intro, .accueil, .langue: return 0
            case .prenom: return 1
            case .but:    return 2
            case .jours, .bien, .fin, .bienvenue: return 3
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
            .padding(.horizontal, pleinEcran ? 0 : 30)
            // L'intro n'a pas de halo à ménager : le poème monte plus haut.
            .padding(.top, pleinEcran ? 0 : (etape == .intro ? 96 : 152))
            .padding(.bottom, pleinEcran ? 0 : 28)
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
            // LE PRÉNOM EST OBLIGATOIRE (13-09, sa règle) : un tap à côté du champ
            // vide ne ferme pas le clavier, il REFUSE — le message passe au rouge.
            if etape == .prenom, champOuvert, prenomVide { refuserPrenom(); return }
            prenomActif = false
            // L'intro, l'accueil et la fin se SAUTENT d'un tap : Apple laisse
            // toujours passer.
            if etape == .intro || etape == .accueil || etape == .fin { avancer(passe: true) }
        }
        .onAppear {
            if etape == .accueil { allumer() }          // (si un jour on entre par là)
            if Self.autoBanc { jouerSeul() }
        }
        .onChange(of: etape) { _, e in
            switch e {
            case .accueil:
                allumer()                                  // la lumière naît APRÈS le plan
            case .fin:
                // Le halo et l'île s'effacent pendant son regard.
                withAnimation(.easeOut(duration: 0.6)) { allume = false }
            case .bienvenue:
                // Le projecteur les rallume — et c'est LA FÊTE qui joue, pas D.
                withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { allume = true }
                NosfySon.fete(true)
            default:
                break
            }
        }
    }

    // MARK: Les écrans

    @ViewBuilder
    private var contenu: some View {
        switch etape {

        // ── L'INTRO « NUIT » (13-09, `PLAN-INTRO-NUIT.md`) : 8 s, et rien de
        // plus. Le plan de cinéma en bande fondue au milieu, le poème au-dessus
        // (la nuit EST la séance), les deux langues ensemble ; à son noir, la
        // citation ; puis l'accueil s'allume. Ni halo ni île : la lumière n'est
        // pas encore née. Sous le poème : LA PISTE DE LA VIDÉO, puis la mienne.
        case .intro:
            VStack(spacing: 24) {
                Group {
                    if (0...2).contains(tempsIntro) {
                        // « La même taille, plus gros, plus beau » (13-09 soir) :
                        // les deux langues à 30 — la couleur les distingue, pas
                        // le corps. FR clair, EN sourd.
                        VStack(alignment: .leading, spacing: 14) {
                            MotsFlou([(IntroPoeme.fr[tempsIntro], true)], taille: 30, lenteur: 1.35)
                            MotsFlou([(IntroPoeme.en[tempsIntro], false)], taille: 30, base: 1.3, lenteur: 1.35)
                        }
                        .id(tempsIntro)
                        .transition(.fonduFlou)
                    } else if tempsIntro == 3 {
                        // NIETZSCHE, sur le noir — on ne corrige pas une citation.
                        VStack(alignment: .leading, spacing: 12) {
                            MotsFlou([(IntroPoeme.citation, true)], taille: 30)
                            Text(IntroPoeme.auteur)
                                .font(.inter(13))
                                .foregroundStyle(.white.opacity(0.42))
                                .modifier(Retarde(apres: 1.1))
                        }
                        .id(3)
                        .transition(.fonduFlou)
                    }
                }
                .frame(height: 220, alignment: .bottom)      // 4 lignes à 30, jamais de chevauchement

                // LA BANDE — 300 × 200 pt (3:2, le ratio du fichier cuit 990 × 660),
                // sa vignette elliptique fondue DANS le fichier, ralentie ×1,5 (12 s).
                // Elle joue UNE fois, avec SON son, finit dans son noir et le tient ;
                // démontée à la citation.
                if tempsIntro < 3 {
                    Group {
                        if Self.sansVideo {
                            Image("nosfy-nuit-poster").resizable().aspectRatio(contentMode: .fit)
                        } else {
                            NosfyReel(nom: "nosfy-nuit", boucle: false, muet: false)
                        }
                    }
                    .frame(width: 300, height: 200)
                    .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .task { await jouerIntro() }

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
                    [(L("Top.", "Great."), true),
                     (L("J'ai trois questions pour vous.", "I have three questions for you."), false)],
                    [(L("La première :", "First:"), false),
                     (L("comment dois-je vous appeler ?", "what should I call you?"), true)]
                ], onMot: battre) {
                    withAnimation(.easeOut(duration: 0.7)) { champOuvert = true }
                }

                // Pas de bouton : le clavier valide. Le champ n'existe qu'une
                // fois la question posée.
                if champOuvert {
                // LE PRÉNOM EST OBLIGATOIRE (13-09, sa règle : « pas de skip, mais un
                // message qui devient rouge dans l'input si le user tape à côté ») :
                // le seul rouge du film. Il ne vient qu'après un geste faux (retour
                // vide, tap à côté), il part au premier caractère.
                TextField("", text: $prenomSaisi,
                          prompt: Text(L("Votre prénom", "Your first name"))
                              .foregroundStyle(prenomRefuse ? Self.rougeRefus : .white.opacity(0.30)))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit {
                        guard !prenomVide else { refuserPrenom(); return }
                        avancer(passe: false)
                    }
                    .onChange(of: prenomSaisi) { _, _ in
                        if prenomRefuse { withAnimation(.easeOut(duration: 0.2)) { prenomRefuse = false } }
                    }
                    .font(.inter(19, .medium))
                    .foregroundStyle(.white)
                    .tint(prenomRefuse ? Self.rougeRefus : .white)
                    .focused($prenomActif)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 17)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(prenomRefuse ? Self.rougeRefus.opacity(0.08) : .white.opacity(0.06))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: prenomRefuse
                                                ? [Self.rougeRefus.opacity(0.85), Self.rougeRefus.opacity(0.35)]
                                                : [.white.opacity(prenomActif ? 0.62 : 0.30), .white.opacity(0.06)],
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
                MotsFlou([(L("Deuxième question.", "Second question."), true),
                          (L("Vous voulez vous entraîner pour quoi ?", "What do you train for?"), false)],
                         taille: 30, onMot: battre)
                VStack(spacing: 11) {
                    CardVerre(titre: L("Être plus fort", "Get stronger")) { reponses.but = "force"; avancer(passe: false) }
                    CardVerre(titre: L("Perdre du poids", "Lose weight")) { reponses.but = "poids"; avancer(passe: false) }
                    CardVerre(titre: L("Être en forme", "Stay in shape")) { reponses.but = "forme"; avancer(passe: false) }
                }
                .modifier(Retarde(apres: 1.9))
            }

        // ── QUESTION 3 SUR 3 : les jours ──
        case .jours:
            VStack(alignment: .leading, spacing: 30) {
                MotsFlou([(L("Dernière question.", "Last question."), true),
                          (L("Combien de fois par semaine ?", "How many times a week?"), false)],
                         taille: 30, onMot: battre)

                SemaineTapable(choisis: reponses.jours, en: en) { i in
                    Haptique.leger()
                    if reponses.jours.contains(i) { reponses.jours.remove(i) }
                    else { reponses.jours.insert(i) }
                    armerMinuterieJours()
                }
                .modifier(Retarde(apres: 1.7))

                // Ce n'est pas une légende : c'est LUI qui compte à voix haute.
                if !reponses.jours.isEmpty {
                    MotsFlou([(Self.fois(reponses.jours.count, en: en), true)], taille: 30)
                        .id(reponses.jours.count)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }

        // ── « BIEN. » — le mot de fin, avant que la lumière change de camp ──
        // (13-09, sa demande : « avant le résultat il manque un mot de fin »).
        // L'écran ne porte QUE le mot ; le halo s'embrase avec lui ; 1,6 s, puis
        // le projecteur. Pas de réplique dans l'île : ce mot-là EST l'écran.
        case .bien:
            MotsFlou([(L("Bien.", "Good."), true)], taille: 44, onMot: battre)
                .frame(width: 150)
                .frame(maxWidth: .infinity)
                .task {
                    Haptique.fort()
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { embrase = true }
                    try? await Task.sleep(for: .milliseconds(1000))
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.9)) { embrase = false }
                    try? await Task.sleep(for: .milliseconds(600))
                    guard etape == .bien else { return }
                    withAnimation(.easeInOut(duration: 0.55)) { etape = .fin }
                }

        // ── LA FIN « END » (13-09, `PLAN-INTRO-NUIT.md` §8) : le dernier regard ──
        // Un plan PORTRAIT, plein écran, une fois, avec SON son — ma musique se
        // retire pendant son regard (le silence est ce qui le rend important) et
        // revient avec le projecteur. Le halo et l'île s'effacent ; le noir de
        // sa fin est exactement ce que l'interrupteur du projecteur attend.
        case .fin:
            Group {
                if Self.sansVideo {
                    Image("nosfy-end-poster").resizable().aspectRatio(contentMode: .fill)
                } else {
                    NosfyReel(nom: "nosfy-end", boucle: false, muet: false, remplir: true)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .task {
                NosfySon.musique(false)                       // elle se retire, 1,2 s
                try? await Task.sleep(for: .seconds(8.1))
                guard etape == .fin else { return }
                withAnimation(.easeInOut(duration: 0.55)) { etape = .bienvenue }
            }

        // ── LA SORTIE : LE PROJECTEUR ──
        case .bienvenue:
            SortieProjecteur(prenom: reponses.prenom,
                             seances: reponses.jours.count,
                             en: en,
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
        } else if etape == .but || etape == .jours {
            // « Passer » n'existe que sur le BUT et les JOURS — pas sur un plan (vu
            // au sim le 13-09 : il s'affichait sur la vidéo de fin), et PLUS SUR LE
            // PRÉNOM (13-09, sa règle : « le user ne peut pas passer le prénom »).
            Button(L("Passer", "Skip")) { NosfySon.tap(); avancer(passe: true) }
                .font(.inter(12.5))
                .foregroundStyle(.white.opacity(0.30))
                .underline()
                .padding(.top, 26)
                .padding(.bottom, 6)
                .modifier(Retarde(apres: 2.4))
        }
    }

    // MARK: Le prénom obligatoire

    /// Le rouge du refus — le seul rouge du film.
    private static let rougeRefus = Color(red: 1.0, green: 0.30, blue: 0.20)

    private var prenomVide: Bool { prenomSaisi.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Le refus : le message du champ passe au rouge, un coup léger, le clavier
    /// reste — on ne sort pas d'une question obligatoire.
    private func refuserPrenom() {
        withAnimation(.easeOut(duration: 0.25)) { prenomRefuse = true }
        Haptique.leger()
        prenomActif = true
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
        case .intro:
            // Un tap saute le plan : Apple laisse toujours passer.
            withAnimation(.easeInOut(duration: 0.7)) { etape = .accueil }
            return
        case .fin:
            withAnimation(.easeInOut(duration: 0.55)) { etape = .bienvenue }
            return
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
                mot = L("Comme vous voulez.", "As you wish.")
            } else {
                let p = prenomSaisi.trimmingCharacters(in: .whitespaces)
                reponses.prenom = p
                mot = L("Enchanté, \(p).", "Nice to meet you, \(p).")
            }
        case .but:
            if passe { reponses.but = nil; mot = L("Comme vous voulez.", "As you wish.") }
            else { mot = L("Bien. Je sais où on va.", "Good. I know where we're going.") }
        case .jours:
            if passe {
                reponses.jours = []
                mot = L("Cinq, alors. On verra.", "Five, then. We'll see.")   // le défaut du serveur
            } else {
                mot = L("\(Self.enLettres(reponses.jours.count)) fois. On s'y tient.",
                        "\(Self.fois(reponses.jours.count, en: true).dropLast()) We'll hold to it.")
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

    /// ⚠️ PILOTÉ PAR L'ÉTAPE, plus par des durées (13-09 soir) : la version aux
    /// `sleep` fixes tapait au mauvais écran dès qu'un plan s'ajoutait au film —
    /// elle s'est perdue sur les jours à l'arrivée de l'intro. Ici il ATTEND
    /// d'être à l'étape, laisse le temps qu'elle se dise, puis agit. Les jours
    /// passent par la vraie minuterie (2,2 s après le « dernier tap »).
    private func jouerSeul() {
        Task { @MainActor in
            func attendre(_ e: Etape, puis s: Double) async -> Bool {
                var n = 0
                while etape != e {
                    try? await Task.sleep(for: .milliseconds(200))
                    n += 1
                    if n > 600 { return false }              // 2 min : on abandonne
                }
                try? await Task.sleep(for: .seconds(s))
                return etape == e
            }
            if await attendre(.intro, puis: 6)   { avancer(passe: true) }
            if await attendre(.accueil, puis: 8) { avancer(passe: true) }
            if await attendre(.langue, puis: 5)  { reponses.langue = "fr"; avancer(passe: false) }
            if await attendre(.prenom, puis: 9)  { prenomSaisi = "Margaux"; avancer(passe: false) }
            if await attendre(.but, puis: 6)     { reponses.but = "poids"; avancer(passe: false) }
            if await attendre(.jours, puis: 4)   { reponses.jours = [0, 2, 4, 6]; armerMinuterieJours() }
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
    /// La langue du film — « LET'S / MARGAUX / GO ! » et « Enter ».
    var en: Bool = false
    /// L'île s'allume (t = 0,25 s) : le parent flashe l'anneau, vibre, et
    /// penche le halo en projecteur. Un seul événement déclenche tout.
    var onInterrupteur: () -> Void
    var onEntrer: () -> Void

    /// LES TEMPS DE L'APPARITION (PLAN-SORTIE-POPUP § 11) : 0 = le halo seul ·
    /// 1 = l'île allumée, le cône descend, le galet monte du bord · 2 = LA POP-UP
    /// DE BASE est montée (elle arrive par sa propre rampe, 1,45 s) · 3 = elle est
    /// posée : la pluie de diamant. Une horloge qui MEURT au dernier temps.
    @State private var temps = 0
    /// Le galet de verre noir monte du bord bas (fondu 0,9 s).
    @State private var galet = false
    /// La sortie est engagée (un seul départ).
    @State private var dissipe = false
    /// Le zoom cinématique — APRÈS que la card est partie : rien de vivant n'est
    /// jamais redimensionné (le verre se retire, la caméra avance ensuite).
    @State private var zoom = false
    /// La coupe sur blanc (§4) : la caméra entre dans la lumière.
    @State private var voile: Double = 0
    /// LA PLUIE — la poudre de diamant sur TOUT l'écran, quand la fin est là.
    @State private var pluie: Date?
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
            return en ? ["LET'S", "GO !"] : ["ALLEZ", "GO !"]
        }
        return en ? ["LET'S", p.uppercased(), "GO !"] : ["ALLEZ", p.uppercased(), "GO !"]
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

            // TEMPS 1 — LE GALET DE VERRE NOIR (13-09, sa consigne : « la pilule
            // noire / blanche du chapitre 1 "le verre noir" de la route, debout,
            // coupée, fondue, en bas de la page ») : il monte du bord, sous la card.
            galetDuBas

            // TEMPS 2 — LA POP-UP DE BASE (PLAN-SORTIE-POPUP § 11) : la robe
            // « You Made It » telle qu'elle est — sa lampe, sa matrice, le chiffre
            // en vrai Liquid Glass posé SUR les mots — avec nos mots, la capsule
            // « Entrer », et le scrim à 0 (le cône reste visible ; le scrim,
            // transparent, porte le « tap partout = entrer »). Elle arrive par sa
            // propre rampe, se ferme par sa propre sortie, et `onClose` nous rend
            // la main pour le zoom et la coupe.
            if temps >= 2 {
                RewardPopup(count: seances, title: "", subtitle: "", unit: "",
                            style: .spotlight,
                            onClose: { partir() },
                            lignesGeantes: lignes,
                            bouton: .capsule(en ? "Enter" : "Entrer"),
                            scrim: 0)
                    // (13-09, son verdict : « animation, transition, plus de blur »)
                    // Elle sort du flou en montant, comme tout ce qui apparaît dans
                    // le film — par-dessus sa propre rampe d'arrivée.
                    .transition(.fonduFlou)
            }

            // LA PLUIE DE DIAMANT — partout, quand l'écran de fin est complet.
            // ⚠️ Elle tombe SUR le verre : la poudre de la maison (RewardCard:911)
            // est validée sur cette card même ; l'interdit n° 2 de la lentille
            // vise les particules-points, pas ses facettes.
            if let pluie {
                GeometryReader { geo in
                    PoudreDiamant(largeur: geo.size.width, hauteur: geo.size.height,
                                  naissance: pluie)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
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
        // Toute la page est tappable. Avant la pop-up, un tap l'appelle d'un coup ;
        // une fois là, c'est SON scrim (transparent) qui prend les taps → fermer.
        .contentShape(Rectangle())
        .onTapGesture { if temps < 2 { NosfySon.tap(); arriverALaFin() } }
        // LE ZOOM CINÉMATIQUE : la caméra AVANCE vers la place de la card (l'ancre
        // est son centre, pas celui de l'écran). La card a déjà été retirée (voir
        // `partir`) : rien de vivant n'est redimensionné.
        .scaleEffect(zoom ? 1.38 : 1, anchor: UnitPoint(x: 0.5, y: 0.43))
        .animation(.easeIn(duration: 0.55), value: zoom)
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
        guard temps < 1 else { return }                           // elle a sauté à la fin
        onInterrupteur()                                          // 0,25 · l'île s'allume · fort
        temps = 1
        try? await Task.sleep(for: .milliseconds(600))
        guard temps < 2 else { return }
        arriverALaFin()                                           // 0,85 · la pop-up naît
    }

    /// LA POP-UP ARRIVE — à 0,85 s, ou d'un tap avant (13-09, son verdict :
    /// « même si j'appuie plusieurs fois, ça doit m'amener à l'écran de fin avec
    /// des paillettes partout ; et seulement là, dès que j'appuie, la home »).
    /// Elle se pose seule (sa rampe de 1,45 s : count-up, secousse, boum) ; à la
    /// pose, LA PLUIE de diamant tombe sur tout l'écran — c'est la fête.
    private func arriverALaFin() {
        guard temps < 2 else { return }
        if temps < 1 { onInterrupteur() }
        withAnimation(.easeOut(duration: 0.7)) { temps = 2 }     // la pop-up, en fondu-flou
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1450))
            guard temps == 2 else { return }
            temps = 3
            if !reduceMotion { pluie = Date() }
            // LE GALET NE MONTE QU'APRÈS la pop-up (13-09, son verdict : « le
            // galet est déjà présent avant l'apparition de la page ! »).
            galet = true
        }
    }

    /// LE GALET DE VERRE NOIR — `duo-galet-noir.mp4`, le fichier même de l'écran 1
    /// de la route (déjà cuit, déjà dans le bundle) : debout, AU RAS DU BAS —
    /// ≈ 110 pt émergent du bord, le reste est sous l'écran, sa tête fondue dans
    /// le noir (13-09, son verdict : « coupée, fondue vers le bas de l'écran, pas
    /// au niveau de la pop-up »). Il ne s'approche jamais de la pop-up : un verre
    /// posé sur une vidéo ne met rien en cache (loi mesurée).
    /// Barreau : `-sansNosfyVideo` (celui de `NosfyReel`).
    private var galetDuBas: some View {
        GeometryReader { g in
            // Assez petit pour vivre SOUS la card (son bas est à ≈ 645 pt), assez
            // grand pour qu'on voie le verre : 50 % de large, 254 pt de haut.
            let l = g.size.width * 0.50
            let h = l * 1560 / 1206
            NosfyReel(nom: "duo-galet-noir", boucle: true, muet: true)
                .frame(width: l, height: h)
                // La tête se fond dans le noir (elle passe sous la card, invisible),
                // et le pied se fond VERS LE BAS DE L'ÉCRAN — après le ventre.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.7), location: 0.26),
                            .init(color: .white, location: 0.42),
                            .init(color: .white, location: 0.93),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
                // ⚠️ SON RECTANGLE SE VOYAIT (son téléphone, 13-09 : « un problème
                // avec le footer, le background du bas et la pilule ») : le noir
                // du fichier est pur, la page au-dessus est un noir grainé éclairé
                // par le pied du cône — le bord haut de la vidéo faisait une marche.
                // En ÉCRAN, le noir n'ajoute rien : seules les arêtes claires du
                // verre s'impriment, le rectangle n'existe plus. ⚠️ Et en écran,
                // ce qu'on VOIT du galet, c'est son VENTRE (le reflet) : à 110 pt
                // visibles il restait sous le bord (« on ne voit pas la pilule »).
                // Le ventre vit à 85-92 % de la hauteur : il est à ~25 pt du bas.
                .blendMode(.screen)
                .opacity(galet ? 0.95 : 0)
                .offset(y: galet ? 0 : 34)
                .animation(.easeOut(duration: 1.1), value: galet)
                .position(x: g.size.width / 2, y: g.size.height + 12 - h / 2)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// LA SORTIE (§ 11 du plan) — appelée par `onClose` de la pop-up, donc APRÈS
    /// sa propre sortie de 0,42 s (le verre s'est retiré, il n'est jamais
    /// transformé) : la caméra avance 0,55 s, le voile monte au blanc, et c'est
    /// la coupe — sur du blanc pur. (Un tap avant la pose ne ferme rien : la
    /// pop-up garde ses taps tant qu'elle n'est pas posée — sa loi.)
    private func partir() {
        guard !dissipe else { return }
        dissipe = true
        temps = 3
        NosfySon.tap()
        NosfySon.musique(false)                      // la musique s'éteint avec la page
        NosfySon.fete(false)
        Haptique.moyen()
        Task { @MainActor in
            zoom = true                                             // la caméra avance
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeIn(duration: 0.35)) { voile = 1 }   // le cône monte au blanc
            try? await Task.sleep(for: .milliseconds(150))
            Haptique.leger()
            try? await Task.sleep(for: .milliseconds(200))          // coupe sur blanc
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
                    stops: [.init(color: .white.opacity(0.85), location: 0),
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

// MARK: - LE POÈME DE L'INTRO (PLAN-INTRO-NUIT.md §2-3)

/// La nuit EST la séance. Trois temps, les deux langues ensemble (la langue
/// n'est pas encore choisie), et le mot « courage » n'est jamais dit : Nietzsche
/// le dit à sa façon, sur le noir. On ne corrige pas une citation : elle tutoie,
/// le film continue de vouvoyer.
private enum IntroPoeme {
    static let fr = ["La nuit ne demande pas si l'on est prêt.",
                     "Elle demande si l'on y va.",
                     "Chaque séance est une nuit."]
    static let en = ["The night doesn't ask if you're ready.",
                     "It asks if you'll go.",
                     "Every workout is a night."]
    static let citation = "Deviens ce que tu es."
    static let auteur = "Nietzsche"
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
    /// L'accueil BOUCLE (la bête immobile) ; l'intro et la fin jouent UNE fois et
    /// finissent dans leur propre noir — le temps les enchaîne, pas le lecteur.
    var boucle: Bool = true
    /// L'accueil est muet (la boucle n'a pas de son utile) ; l'intro et la fin
    /// gardent LEUR piste — c'est elle qu'on entend, puis ma musique (§9 du plan).
    var muet: Bool = true
    /// La fin est un plan PORTRAIT fait pour l'écran entier : il remplit.
    var remplir: Bool = false

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
        v.playerLayer.videoGravity = remplir ? .resizeAspectFill : .resizeAspect
        guard let url = Bundle.main.url(forResource: nom, withExtension: "mp4") else { return v }
        let item = AVPlayerItem(url: url)
        let lecteur: AVQueuePlayer
        if boucle {
            lecteur = AVQueuePlayer()
            v.boucle = AVPlayerLooper(player: lecteur, templateItem: item)
        } else {
            lecteur = AVQueuePlayer(items: [item])
            lecteur.actionAtItemEnd = .pause              // il finit dans son noir, et s'y tient
        }
        lecteur.isMuted = muet
        lecteur.preventsDisplaySleepDuringVideoPlayback = false
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
    /// ⚠️ « C'est toujours la même musique que le splash, j'aime pas du tout »
    /// (13-09). Le thème du splash est SORTI. `NosfyTheme` n'existe pas encore
    /// dans Woop/Sounds : tant qu'il n'y est pas, `url(forResource:)` rend nil et
    /// le film est SILENCIEUX — mieux qu'une musique qu'elle déteste. Les
    /// variantes se fabriquent par tools/porte/theme_nosfy.py ; la retenue
    /// sera copiée sous ce nom.
    private static let theme = "NosfyTheme"
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
            // 50 % d'un master à −24 LUFS : discret mais PRÉSENT. À 18 % (premier
            // jet) le haut-parleur du téléphone ne rendait presque rien (13-09).
            p.setVolume(0.5, fadeDuration: 1.5)
            musique = p
        } else {
            guard let p = musique else { return }
            p.setVolume(0, fadeDuration: 1.2)
            musique = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { p.stop() }
        }
    }

    /// Le tap et la paillette sont des CRISTAUX du thème (theme_nosfy.py) :
    /// la même matière que la musique — on n'entend pas « un son d'interface
    /// sur une musique », on entend Nosfy.
    /// LA MUSIQUE DE FIN (13-09 soir : « avec le résultat, un peu plus joyeuse,
    /// LET'S GO MARGAUX ») — `NosfyFin` (F · fête, theme_nosfy2.py : la même
    /// matière que D, en majeur, des arpèges qui montent, un pouls doux). Elle
    /// remplace D au projecteur ; D s'était déjà retirée pendant « end ».
    private static let themeFin = "NosfyFin"
    private static var fete: AVAudioPlayer?

    static func fete(_ allumer: Bool) {
        preparerSession()
        if allumer {
            guard fete == nil else { return }
            guard let url = Bundle.main.url(forResource: themeFin, withExtension: "m4a"),
                  let p = try? AVAudioPlayer(contentsOf: url) else { return }
            p.numberOfLoops = -1
            p.volume = 0
            p.prepareToPlay()
            p.play()
            p.setVolume(0.6, fadeDuration: 1.2)
            fete = p
        } else {
            guard let p = fete else { return }
            p.setVolume(0, fadeDuration: 1.0)
            fete = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { p.stop() }
        }
    }

    static func tap() { bruit("NosfyTap", "wav", volume: 0.6) }
    static func paillette() { bruit("NosfyPaillette", "wav", volume: 0.55) }

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

    /// `lenteur` étire le phrasé (1 = le film ; 1,35 = l'intro, qui a le temps).
    init(_ fragments: [(String, Bool)], taille: CGFloat = 22, base: Double = 0,
         onMot: (() -> Void)? = nil, lenteur: Double = 1) {
        self.taille = taille
        self.mots = Self.calendrier(fragments, base: base, lenteur: lenteur)
        self.onMot = onMot
    }

    /// Combien de temps la tirade met à se dire, en entier — la dernière
    /// apparition comprise. C'est ce que `Tirade` attend avant d'enchaîner.
    static func duree(_ fragments: [(String, Bool)]) -> Double {
        (calendrier(fragments, base: 0, lenteur: 1).last?.retard ?? 0) + 0.78
    }

    /// LE PHRASÉ, calculé une fois — voir la note ci-dessous.
    private static func calendrier(_ fragments: [(String, Bool)], base: Double,
                                   lenteur: Double) -> [Mot] {
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
                t += (0.05 + lettres * 0.013 + grain) * lenteur
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

    var en: Bool = false
    private var lettres: [String] {
        en ? ["M", "T", "W", "T", "F", "S", "S"] : ["L", "M", "M", "J", "V", "S", "D"]
    }

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
