import SwiftUI
import AVFoundation
import CoreText

// MARK: - LA CARD REWARD — le pop-up noir du chiffre

/// La card de récompense : un pop-up noir portrait (la forme exacte de la
/// réf : ~80 % de largeur, ratio 1,32), posé sur un scrim profond, qui
/// annonce un CHIFFRE (les séries faites). Titre + sous-titre à l'Apple en
/// tête, LE GROS HALO BLANC qui monte du bas (toute la lumière de la card
/// vient d'en bas — verdict), les chiffres voisins de l'odomètre rognés
/// par les flancs.
///
/// LES LOIS PAYÉES QUI TIENNENT CE COMPOSANT :
/// - Le verre `.regular` COMPOSE LE FOND DE PAGE PAR-DESSUS ce qu'on
///   peint dessous (mesuré ici même : dalle noire invisible, page en
///   transparence) : le noir se peint AU-DESSUS du verre — la grammaire
///   de BoosterPopup, seule éprouvée. Dessous, le verre ne garde que la
///   dalle de fond ; tout le décor (voile, halo, fantômes) vit dessus.
/// - Le verre vit à TAILLE CONSTANTE dès la première frame (des bounds
///   vivants = flou plat définitif) : l'entrée est un fondu + un
///   `scaleEffect` (transform, pas un resize), le clip est constant.
/// - L'encre vit au-dessus du verre, jamais dans un conteneur de verre.
/// - Le verre force son propre `.dark` (il rend selon le scheme de SA vue).
/// - Les rampes échelonnées vivent sur UN progrès `p` porté par une vue
///   Animatable — des fondus posés sous un `withAnimation` nu ne jouent
///   qu'au doigt.
/// - Le gyro RÉUTILISE `SkyMotion` (5 CMMotionManager vivent déjà, Apple
///   en veut UN) ; sur du noir l'effet vient de la LUMIÈRE (la nappe du
///   bas, le foil du chiffre), l'inclinaison 3D est un murmure (≤ 2,6°).
///   Le simulateur n'a pas de gyroscope : tout reste posé, rien ne meurt.
/// - Le slot du halo/de l'âme est celui des futures VIDÉOS fond noir.
/// Les DEUX robes de la card — même layout, autre dressage (verdict
/// « rewards cards 2 ») :
/// - `.halo` : la réf Apple Fitness — le gros halo blanc du bas, les
///   voisins d'odomètre, le chiffre en argent.
/// - `.neon` : la réf WWDC « 1 DAY TO GO » — le chiffre NÉON qui bloom
///   (blanc chaud sur un disque sombre), l'unité écrite À PLAT en
///   capitales sombres couchées en perspective ; la lumière vient du
///   chiffre, plus du bas.
/// - `.galet` : le chiffre nu, et PAR-DESSUS un GROS GALET de VRAI verre
///   natif (glassEffect) qui se promène sur lui et le réfracte — le
///   chiffre est la nourriture de la lentille, et le doigt peut saisir
///   le galet (retour élastique, haptique à la prise et au lâcher).
/// - `.spotlight` : la nuit totale, le chiffre en métal sombre, et DANS
///   le glyphe LA MATRICE — une trame de micro-mots presque noirs qui
///   s'éclairent par vagues (plan fin : tools/rewards/PLAN-SPOTLIGHT-V4.md,
///   jalon S1 = la trame morte + un front figé).
/// - `.fire` : le sticker FLAMME NOIRE au centre (l'asset de Kathryn),
///   le chiffre géant DERRIÈRE que seule la lumière révèle, la braise
///   rouge, et au tap une gerbe de petites flammes orange.
/// - `.welcome` : le retour de l'utilisateur — la vidéo chauve-souris
///   PORTRAIT fondue en header, et un bouton CLAIM de verre.
/// LE RETOUR a DEUX robes (`RewardStyle.welcome` + `WelcomeRobe`) :
/// - `.video` : la vidéo chauve-souris portrait en header (livrée) ;
/// - `.texte` : le texte géant « YOU'RE / BACK » derrière, le spotlight
///   du haut, la PASTILLE-LUNE au centre qui vit et s'allume, et la
///   CHAUVE-SOURIS qui TIENT la card par son bord haut.
enum RewardStyle {
    case halo, neon, galet, spotlight, fire, welcome
}

/// Les deux robes de la card Welcome Back.
enum WelcomeRobe {
    case video, texte
}

/// Le bouton du bas quand ce n'est pas le lien « Close » (la sortie de Nosfy) :
/// une capsule de VRAI verre, celle du Claim, sans la pièce.
enum BoutonBas {
    case capsule(String)
}

struct RewardPopup: View {
    /// Le chiffre annoncé — les séries effectuées.
    let count: Int
    let title: String
    let subtitle: String
    /// L'unité sous le chiffre — le « Weeks » de la réf.
    let unit: String
    var style: RewardStyle = .halo
    /// La robe du Welcome Back (ignorée par les autres styles).
    var robe: WelcomeRobe = .video
    /// La vidéo du header (nom de ressource `Nosfy/Media`, sans
    /// extension) — le REWARD à mise en scène : elle SORT de la matière
    /// noire de la card, joue UNE fois, gèle sur sa dernière frame.
    var videoNom: String? = nil
    var onClose: () -> Void
    /// LE CLAIM (welcome) — ce qu'il ENCAISSE avant de fermer. Nil = le bouton
    /// ne fait que fermer (les bancs). Tranché le 30-08 : les +10 partent AU
    /// TAP — c'est ici que la card cesse de mentir « Claim +10 ».
    var onClaim: (() -> Void)? = nil
    /// LA SORTIE DE NOSFY (13-09, PLAN-SORTIE-POPUP § 11) — trois paramètres
    /// OPTIONNELS, `nil` = la robe telle quelle, aucune robe existante ne bouge :
    /// les mots du texte géant (au lieu du nombre en lettres — plusieurs rangées,
    /// échelonnées sur la largeur de la card), le bouton du bas (une capsule de
    /// verre au lieu du lien « Close »), et l'opacité du scrim (0 = le halo du
    /// film reste visible derrière ; le scrim reste MONTÉ : c'est lui qui porte le
    /// « tap partout = fermer »).
    var lignesGeantes: [String]? = nil
    var bouton: BoutonBas? = nil
    var scrim: Double = 0.68
    /// LA TÊTE VIDÉO RÉDUITE (13-09, la robe « première fois » : « plus petit
    /// la vidéo de Nosfy fondue ») — la part de la hauteur de la card que prend
    /// la vidéo de tête. `nil` = la robe telle quelle (welcome 0,56 ; les autres
    /// 0,42) ; le titre suit, posé dans le fondu quel que soit ce réglage.
    var tete: CGFloat? = nil

    /// L'unique progrès de l'entrée [0,1] — toutes les rampes en dérivent.
    /// `-rewardFreeze <p>` le CLOUE : deux tours de fouettage se comparent
    /// enfin au même instant de la rampe (1,45 s d'entrée, tout y bouge).
    @State private var p: Double = RewardBanc.fige ?? 0
    /// La sortie est engagée : le chiffre reste FIGÉ (un odomètre qui
    /// rejoue 4 → 0 en 0,3 s à l'envers, mesuré au film, fait cheap).
    @State private var enSortie = false
    /// L'entrée est POSÉE. La garde « p == 1 » était MORTE (relecture
    /// adverse) : `withAnimation { p = 1 }` écrit le MODÈLE à 1 dès la
    /// première frame — seule la présentation interpole. Un tap scrim ou
    /// Close en pleine entrée fermait la card, figeait le chiffre en plein
    /// count-up, et la completion jouait quand même boum + arpège dans la
    /// sortie. Le verrou est ce drapeau, posé par la completion.
    /// (Sous `-rewardFreeze`, la card naît DÉJÀ posée — et posée d'entrée,
    /// donc `onChange(of: posee)` ne voit aucun changement : pas de
    /// tressaillement dans une capture censée être immobile.)
    @State private var posee = RewardBanc.fige != nil
    /// Un Claim a été demandé : la fermeture ne s'attend plus à `posee` (le
    /// tap pendant l'entrée doit fermer, pas rester ouvert).
    @State private var claimDemande = false
    /// L'horloge de la poudre — posée UNE fois au montage (la scène, elle,
    /// renaît à chaque frame de `p` : une Date prise là-bas gèlerait tout).
    @State private var naissance = Date()
    /// Le BOUM de l'atterrissage (verdict « haptique fort ») — se juge au
    /// téléphone, le simulateur ne vibre pas.
    @State private var boum = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var videoEffective: String? {
        if let videoNom { return videoNom }
        guard style == .welcome, robe == .video else { return nil }
        return "reward-welcome"
    }

    var body: some View {
        RewardScene(p: p, count: count, title: title, subtitle: subtitle,
                    unit: unit, style: style, robe: robe,
                    videoNom: videoEffective,
                    naissance: naissance, enSortie: enSortie,
                    posee: posee, fermer: fermer, onClaim: onClaim,
                    lignesGeantes: lignesGeantes, bouton: bouton, scrim: scrim,
                    tete: tete)
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0),
                             trigger: boum)
            .onAppear {
                SkyMotion.shared.start(reduceMotion: reduceMotion)
                // La card figée ne joue RIEN : ni rampe, ni tick, ni
                // arpège — une capture de réglage, pas une arrivée.
                guard RewardBanc.fige == nil else { return }
                // La petite musique (verdict « premium Apple-like ») parle
                // la langue sonore DÉJÀ dans la maison : le tick du cadran
                // par chiffre (dans la scène), l'arpège de cristal à
                // l'atterrissage — pas un son de bouton importé.
                LensChime.shared.prepare()
                Paillettes.shared.prepare()
                // Linéaire : les smoothsteps internes portent chacun leur
                // propre courbe — une aisance globale les doublerait.
                withAnimation(.linear(duration: 1.45)) {
                    p = 1
                } completion: {
                    posee = true
                    boum += 1
                    Paillettes.shared.announce(after: 0)
                }
            }
            // Au banc (`-rewardAuto`), la card se referme seule par SA
            // sortie — l'aller-retour filmé est le vrai.
            .task {
                // (Au banc `-rewardLab`, c'est LUI qui mène le balayage :
                // deux horloges sur la même card se marcheraient dessus.)
                guard CommandLine.arguments.contains("-rewardAuto"),
                      !RewardBanc.actif
                else { return }
                try? await Task.sleep(for: .seconds(3.6))
                fermer()
            }
    }

    /// LE CLAIM (20-09, retour TestFlight « il faut appuyer 3 à 6 fois ») : le
    /// +10 part, ET la card se ferme MÊME si l'entrée de 1,45 s n'est pas encore
    /// « posée ». Avant, un tap pendant l'entrée encaissait sans fermer (fermer()
    /// était gardé par `posee`) — Kathryn retapait, et le 2e tap était avalé.
    private func claimEtFermer() {
        onClaim?()
        claimDemande = true
        fermer()
    }

    private func fermer() {
        // Un Claim demandé ferme tout de suite ; sinon on attend que l'entrée
        // soit posée (une fermeture en plein fondu d'entrée saute).
        guard !enSortie, posee || claimDemande else { return }
        enSortie = true
        // easeOut : la fin (le lever du scrim, la mort du halo — tout vit
        // dans le bas de `p`) se pose en douceur ; l'easeIn la comprimait
        // en ~6 frames (sauts de 13 pts de luminance mesurés au film).
        withAnimation(.easeOut(duration: 0.42)) {
            p = 0
        } completion: {
            onClose()
        }
    }
}

/// La scène Animatable : c'est ELLE qui déplie `p` image par image, donc
/// les rampes dérivées jouent aussi sous `withAnimation` — et le chiffre
/// compte, puisque le body est ré-évalué à chaque frame de l'entrée.
private struct RewardScene: View, Animatable {
    var p: Double
    let count: Int
    let title: String
    let subtitle: String
    let unit: String
    let style: RewardStyle
    let robe: WelcomeRobe
    let videoNom: String?
    let naissance: Date
    let enSortie: Bool
    /// La card vient de se poser (fin du count-up) : elle TRESSAILLE.
    let posee: Bool
    var fermer: () -> Void
    /// Le Claim du Welcome Back (30-08) : encaisse AVANT de fermer.
    var onClaim: (() -> Void)? = nil
    /// La sortie de Nosfy (13-09) — voir `RewardPopup`.
    var lignesGeantes: [String]? = nil
    var bouton: BoutonBas? = nil
    var scrim: Double = 0.68
    var tete: CGFloat? = nil

    /// La part de la hauteur de la card que prend la vidéo de tête — `tete` si
    /// elle est posée, sinon la robe telle quelle (welcome 0,56 ; les autres
    /// 0,42). Le bloc de tête (titre) en dérive : il se pose dans le fondu.
    private var partTete: CGFloat { tete ?? (style == .welcome ? 0.56 : 0.42) }
    /// Le noir au-dessus de la vidéo quand la tête est réduite (verdict : 20 px).
    private static let noirTete: CGFloat = 20

    /// Le compteur de relance de la vidéo — un tap dessus la rejoue.
    @State private var videoRelance = 0
    /// LA SECOUSSE de la card — arrivée, et le feu qui part.
    @State private var secousse = 0
    /// L'écart du doigt sur la card (CarteGyro l'écrit) — il nourrit le
    /// tilt 3D ET la vie de la vidéo gelée.
    @State private var penteCard = CGSize.zero

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    private static let forme = RoundedRectangle(cornerRadius: 36,
                                                style: .continuous)

    /// LE NOMBRE EN TOUTES LETTRES pour le texte géant.
    /// ⚠️ Il se calcule ICI, côté app — jamais côté IA, comme le corps de
    /// la typo (la loi du contrat backend : l'IA fournit les MOTS d'un
    /// message, jamais la mise en forme d'une donnée).
    private static func enLettres(_ n: Int) -> String {
        let mots = ["ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX",
                    "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN", "TWELVE"]
        return n >= 0 && n < mots.count ? mots[n] : "\(n)"
    }

    var body: some View {
        GeometryReader { g in
            // LA FORME DE LA RÉF, exactement : portrait, ~80 % de la
            // largeur, ratio hauteur/largeur 1,32 (mesuré sur l'image).
            let l = min(g.size.width * 0.80, 332)
            ZStack {
                // Le scrim — PROFOND (verdict « plus foncé derrière ») ;
                // il porte aussi la sortie au tap.
                Color.black.opacity(scrim * sstep(0, 0.30, p))
                    .contentShape(Rectangle())        // à 0, il porte encore le tap
                    .onTapGesture { fermer() }
                carte(largeur: l, hauteur: l * 1.32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        // Un MODAL pour VoiceOver : sans ce trait, la page reste
        // navigable et ACTIVABLE derrière le scrim (relecture adverse).
        .accessibilityAddTraits(.isModal)
        // TOUTES LES CARDS TRESSAILLENT À L'ARRIVÉE (verdict) — le feu
        // deux fois plus fort (voir le modificateur).
        .onChange(of: posee) { _, pose in
            if pose { secousse += 1 }
        }
        // Le tick du cadran à CHAQUE chiffre qui monte — jamais à la
        // descente (le chiffre est figé en sortie de toute façon).
        .onChange(of: valeurCourante) { avant, apres in
            if apres > avant, apres > 0 { LensChime.shared.flare() }
        }
    }

    /// Le chiffre affiché — la rampe du count-up, FIGÉE en sortie.
    private var valeurCourante: Int {
        enSortie ? count : Int((Double(count) * sstep(0.32, 0.86, p)).rounded())
    }

    // MARK: La card

    private func carte(largeur: CGFloat, hauteur: CGFloat) -> some View {
        CarteGyro(pente: $penteCard,
                  sansTilt: style == .welcome) {
            ZStack {
                // 1. LA DALLE NOIRE — la seule chose que le verre a sous
                //    lui : la card naît noire (le fondu noir des cards
                //    exercices), jamais un pixel de page en transparence.
                Self.forme.fill(Color.black)

                // 2. LE VERRE — la matière liquide de la maison. Ce qu'il
                //    apporte ici : l'arête vivante du matériau et son
                //    modelé sur le scrim ; le corps noir, lui, se peint
                //    AU-DESSUS (la leçon mesurée).
                Color.clear
                    .glassEffect(.regular.tint(Color.black.opacity(0.40)),
                                 in: Self.forme)
                    .environment(\.colorScheme, .dark)

                // 3. LE VOILE NOIR — au-dessus du verre, comme
                //    BoosterPopup : très sombre en tête, il S'OUVRE vers
                //    le bas pour laisser la place au halo. En néon, il
                //    reste sombre partout : la lumière vient du chiffre.
                Self.forme.fill(
                    LinearGradient(
                        stops: style == .halo ? [
                            .init(color: .black.opacity(0.94), location: 0),
                            .init(color: .black.opacity(0.86), location: 0.45),
                            .init(color: .black.opacity(0.55), location: 0.78),
                            .init(color: .black.opacity(0.32), location: 1)
                        ] : [
                            .init(color: .black.opacity(0.96), location: 0),
                            .init(color: .black.opacity(0.92), location: 0.5),
                            .init(color: .black.opacity(0.82), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))

                if style == .halo, videoNom == nil {
                    // 4. LE GROS HALO DU BAS — la fumée blanche de la réf,
                    //    en DEUX couches (la nappe large + le cœur), du bas
                    //    uniquement. C'est le slot des futures vidéos.
                    Self.forme.fill(
                        EllipticalGradient(
                            stops: [
                                .init(color: .white.opacity(0.48), location: 0),
                                .init(color: .white.opacity(0.16), location: 0.55),
                                .init(color: .clear, location: 1)
                            ],
                            center: UnitPoint(x: 0.5, y: 1.14),
                            startRadiusFraction: 0,
                            endRadiusFraction: 1.02))
                        .blendMode(.screen)
                        .opacity(sstep(0.22, 0.60, p))
                    Self.forme.fill(
                        EllipticalGradient(
                            stops: [
                                .init(color: .white.opacity(0.60), location: 0),
                                .init(color: .white.opacity(0.16), location: 0.6),
                                .init(color: .clear, location: 1)
                            ],
                            center: UnitPoint(x: 0.5, y: 1.04),
                            startRadiusFraction: 0,
                            endRadiusFraction: 0.55))
                        .blendMode(.screen)
                        .opacity(sstep(0.30, 0.70, p))

                    // 5. LES CHIFFRES CACHÉS — les voisins de l'odomètre,
                    //    rognés par les flancs, dans la brume : leur flou
                    //    est le leur (au-dessus du voile, le frost du
                    //    verre ne les porte plus).
                    chiffresFantomes(largeur: largeur)
                        .opacity(sstep(0.50, 0.82, p))
                } else {
                    // 4 bis. LA ROBE « YOU MADE IT » (le variant 2 refait,
                    //    T1 — la robe néon brume est MORTE) : le TEXTE
                    //    GÉANT derrière, éclairé par la lampe-barrette et
                    //    son éventail.
                    if style == .spotlight {
                        // LA CARD N'EST PLUS NOIRE : GRIS EN TÊTE, NOIR
                        // AU PIED (« la card est trop noire, fais gris to
                        // noir »). Un fill OPAQUE, pas un noir à alpha :
                        // c'est la matière de la card qui change, pas un
                        // voile de plus. ⚠️ Il remplace le dégradé de noir
                        // que j'avais posé AU-DESSUS de la pluie — celui-là
                        // assombrissait la tête, soit exactement l'inverse.
                        // ⚠️ LE BORD HAUT REPART DU NOIR. Le premier jet
                        // posait 0,165 dès la location 0 : ça faisait une
                        // PLAQUE GRISE PLATE au sommet, sur laquelle le
                        // texte géant se détachait au lieu de s'y fondre
                        // (« le background du haut doit être plus fondu,
                        // ça jure »). Le gris culmine maintenant un peu
                        // PLUS BAS, et la crête de la card retourne au
                        // noir — c'est dans ce noir que le mot se noie.
                        Self.forme.fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(white: 0.012),
                                          location: 0),
                                    .init(color: Color(white: 0.062),
                                          location: 0.09),
                                    .init(color: Color(white: 0.125),
                                          location: 0.26),
                                    .init(color: Color(white: 0.098),
                                          location: 0.44),
                                    .init(color: Color(white: 0.045),
                                          location: 0.68),
                                    .init(color: Color(white: 0.010),
                                          location: 0.90),
                                    .init(color: .black, location: 1)
                                ],
                                startPoint: .top, endPoint: .bottom))

                        // LA VIDÉO DE FOND — sa pluie de chiffres à elle
                        // (`fond_paliette`, recuite en ping-pong CUIT :
                        // aller + retour dans le fichier, jamais un seek
                        // qui rebrousse — le décodeur ne suit pas).
                        // Elle a REMPLACÉ 579 lignes de pluie codée à la
                        // main, archivées dans
                        // tools/rewards/archive/pluie-codee.swift.txt.
                        //
                        // ⚠️ BORD À BORD, c'est la seule pose légale :
                        // « une vidéo posée ailleurs qu'en bord de card
                        // laisse TOUJOURS voir son rectangle » (4 essais,
                        // 4 démarcations, 26-08). Son noir est vrai
                        // (médiane 5 à 18, 5e centile 2) : les fondus
                        // n'ont qu'à éteindre les colonnes de bord, il
                        // n'y a aucun rectangle clair à cacher.
                        VideoReward(nom: "fond-matrice-loop",
                                    relance: 0, boucle: true, entier: false)
                            .frame(width: largeur, height: hauteur)
                            .clipShape(Self.forme)
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.55),
                                              location: 0.13),
                                        .init(color: .white, location: 0.30),
                                        .init(color: .white, location: 0.74),
                                        .init(color: .white.opacity(0.42),
                                              location: 0.90),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .top, endPoint: .bottom))
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white, location: 0.15),
                                        .init(color: .white, location: 0.85),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing))
                            .opacity(sstep(0.10, 0.46, p))
                            .allowsHitTesting(false)

                        // LE TEXTE GÉANT DU HEADER — le composant du
                        // variant 2, monté ici avec le NOMBRE EN TOUTES
                        // LETTRES. Il remplace « Training » et sa ligne de
                        // félicitations, morts par verdict. Posé HAUT : le
                        // chiffre matrice descend pour lui faire place.
                        // LA SORTIE DE NOSFY (13-09) : plusieurs rangées (ALLEZ /
                        // PRÉNOM / GO !) au lieu du nombre en lettres. ⚠️ Un prénom
                        // ne doit PAS se faire manger par les fondus : TexteGeant
                        // fond ses lettres sur les flancs de son PROPRE cadre
                        // (12 → 32 %), et le pied de ses rangées. Son cadre est
                        // donc bien plus large et plus haut que la card (les fondus
                        // tombent hors card, le clip rogne le vide), l'échelle vient
                        // après, autour du centre, et le cadre de LAYOUT reste la
                        // card. À `nil`, rien de tout ça : la robe d'origine.
                        TexteGeant(naissance: naissance,
                                   lignes: lignesGeantes ?? [Self.enLettres(count)])
                            .frame(width: lignesGeantes == nil ? largeur : 1700,
                                   height: lignesGeantes == nil ? hauteur : 900)
                            // PLUS GROS (verdict) — et s'il se coupe dans
                            // les fondus des côtés et du bas, « pas
                            // grave » : ce sont eux qui le mangent, pas
                            // le cadre.
                            .scaleEffect(lignesGeantes.map { Self.echelleGeante($0, largeur: largeur) } ?? 0.96)
                            .frame(width: largeur, height: hauteur)
                            // TOUT EN HAUT (« fais FOUR en haut ») — mais PAS les
                            // trois rangées de Nosfy : à 0,31 « ALLEZ collait trop le
                            // haut de la pop-up » (13-09, la petite régression) ; à
                            // 0,20 le bloc respire sous la crête, et le chiffre se
                            // pose SUR les dernières rangées.
                            .offset(y: -hauteur * (lignesGeantes == nil ? 0.355 : 0.20))
                            // SA LUMIÈRE VIENT DU HAUT DE LA CARD : la
                            // source est au-dessus de lui, hors card —
                            // donc il est CLAIR EN CRÊTE et s'éteint en
                            // descendant. ⚠️ Le sens est l'INVERSE du tour
                            // précédent (où la crête se noyait) : c'est
                            // maintenant le PIED qui meurt dans le noir.
                            .overlay(
                                LinearGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.30),
                                              location: 0),
                                        .init(color: .white.opacity(0.10),
                                              location: 0.34),
                                        .init(color: .clear, location: 0.70)
                                    ],
                                    startPoint: .top, endPoint: .bottom)
                                    .blendMode(.plusLighter)
                                    .allowsHitTesting(false))
                            // PLUS FONDU — MAIS SUR LES CÔTÉS ET LE BAS,
                            // pas partout (« je disais plutôt juste sur
                            // les côtés et le bas, là c'est trop »). Un
                            // voile général et un fondu du HAUT l'avaient
                            // éteint : le mot doit rester franc au cœur,
                            // et se dissoudre en s'approchant des bords.
                            // Deux masques imbriqués multiplient leurs
                            // alphas — flancs d'abord, pied ensuite.
                            .mask(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white, location: 0.24),
                                        .init(color: .white, location: 0.76),
                                        .init(color: .clear, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing))
                            .mask(
                                LinearGradient(
                                    stops: lignesGeantes == nil ? [
                                        // LE PIED SE NOIE DANS LE NOIR
                                        // (« après, le bas du gros texte
                                        // en fondu noir ») — la crête
                                        // reste pleine, c'est de là que
                                        // vient sa lumière.
                                        .init(color: .white, location: 0),
                                        .init(color: .white, location: 0.34),
                                        .init(color: .white.opacity(0.46),
                                              location: 0.66),
                                        .init(color: .clear, location: 0.94)
                                    ] : [
                                        // Trois rangées : le pied est déjà
                                        // noyé par TexteGeant lui-même —
                                        // un second fondu effaçait « GO ! ».
                                        .init(color: .white, location: 0),
                                        .init(color: .white, location: 0.80),
                                        .init(color: .white.opacity(0.55), location: 1)
                                    ],
                                    startPoint: .top, endPoint: .bottom))
                            .opacity(sstep(0.20, 0.52, p))
                            .allowsHitTesting(false)
                    }
                    if style == .fire {
                        // LA BRAISE DE LA SCÈNE — saturée et resserrée au
                        // pied (⚠️ loi anti-brun : R à 1,00, le vert
                        // désaturé ; un premier jet large virait terre).
                        Self.forme.fill(
                            EllipticalGradient(
                                stops: [
                                    .init(color: Color(red: 1.0, green: 0.22,
                                                       blue: 0.04)
                                        .opacity(0.34), location: 0),
                                    .init(color: Color(red: 1.0, green: 0.16,
                                                       blue: 0.02)
                                        .opacity(0.09), location: 0.45),
                                    .init(color: .clear, location: 1)
                                ],
                                center: UnitPoint(x: 0.5, y: 0.98),
                                startRadiusFraction: 0,
                                endRadiusFraction: 0.46))
                            .blendMode(.screen)
                            .opacity(sstep(0.25, 0.62, p))
                        ChiffreRevele(valeur: valeurCourante,
                                      naissance: naissance)
                            .opacity(sstep(0.20, 0.52, p))
                    }
                    if style == .welcome {
                        // LA CARD TOUTE NOIRE (verdict) : du noir PLEIN
                        // sous la vidéo — aucune zone plus claire, donc
                        // AUCUNE démarcation possible.
                        Self.forme.fill(Color.black)
                        if robe == .texte {
                            // LE TEXTE GÉANT DERRIÈRE (deux lignes) et
                            // LE SPOTLIGHT DU HAUT — la grammaire de la
                            // robe « You Made It ».
                            TexteGeant(naissance: naissance,
                                       lignes: ["YOU'RE", "BACK"])
                                .opacity(sstep(0.22, 0.55, p))
                            LampeEventail(naissance: naissance)
                                .opacity(sstep(0.10, 0.42, p))
                        }
                        // (La lampe du haut est morte en welcome : le
                        // projecteur monte DU BAS, sous « Later ».)
                        // LE PROJECTEUR DU BAS : il monte de SOUS
                        // « Later » et balaie (robe vidéo ; la robe
                        // texte a SON spotlight en haut) — la lumière lèche le
                        // pied de la card, la scène naît d'en bas.
                        if robe == .video {
                        TimelineView(.animation(
                            minimumInterval: 1.0 / 30.0)) { tl in
                            let b = balayageSpot(
                                tl.date.timeIntervalSince(naissance))
                            Self.forme.fill(
                                EllipticalGradient(
                                    stops: [
                                        .init(color: .white.opacity(0.26),
                                              location: 0),
                                        .init(color: .white.opacity(0.08),
                                              location: 0.42),
                                        .init(color: .clear, location: 1)
                                    ],
                                    center: UnitPoint(x: 0.5 - 0.26 * b,
                                                      y: 1.06),
                                    startRadiusFraction: 0,
                                    endRadiusFraction: 0.66))
                                .blendMode(.screen)
                        }
                        .opacity(sstep(0.18, 0.52, p))
                        .allowsHitTesting(false)
                        }
                    }
                    if style == .neon {
                        TexteGeant(naissance: naissance)
                            .opacity(sstep(0.22, 0.55, p))
                        LampeEventail(naissance: naissance)
                            .opacity(sstep(0.10, 0.40, p))
                    }
                    // Et le HALO DE SOL — la brume du bas (galet seul :
                    // la robe You-Made-It et le spotlight vivent en nuit
                    // totale, et sous une VIDÉO les nappes lavaient le
                    // corps en gris, mesuré).
                    if style == .galet, videoNom == nil {
                    Self.forme.fill(
                        EllipticalGradient(
                            stops: [
                                .init(color: .white.opacity(0.26), location: 0),
                                .init(color: .white.opacity(0.09),
                                      location: 0.55),
                                .init(color: .clear, location: 1)
                            ],
                            center: UnitPoint(x: 0.5, y: 1.02),
                            startRadiusFraction: 0,
                            endRadiusFraction: 0.85))
                        .blendMode(.screen)
                        .opacity(sstep(0.35, 0.70, p))
                    Self.forme.fill(
                        EllipticalGradient(
                            stops: [
                                .init(color: .white.opacity(0.20), location: 0),
                                .init(color: .clear, location: 1)
                            ],
                            center: UnitPoint(x: 0.5, y: 0.88),
                            startRadiusFraction: 0,
                            endRadiusFraction: 0.5))
                        .blendMode(.screen)
                        .opacity(sstep(0.40, 0.75, p))
                    }
                }

                // ⚠️ LA VIDÉO SOUS LE BOUTON EST MORTE, ET C'EST UNE
                //    LOI : une vidéo posée dans la card laisse TOUJOURS
                //    voir son RECTANGLE sur le noir — masque radial,
                //    masque vertical, plein largeur, en petit : quatre
                //    essais, quatre démarcations (« c'est dégueulasse »).
                //    Une vidéo ne se fond QUE si elle occupe un bord
                //    entier de la card (le header). Ne pas réessayer.

                // 5 bis. LA POUDRE DE DIAMANT (verdict) — les grains
                //    naissent dans le halo et scintillent TRANCHÉ, la
                //    recette de PoudreBooster en monochrome lunaire.
                //    Sur TOUTES les robes (verdict « au global je veux
                //    plus de poudre de diamant »).
                PoudreDiamant(largeur: largeur, hauteur: hauteur,
                              naissance: naissance)
                    .opacity(sstep(0.35, 0.75, p))

                // 5 ter. LA VIDÉO DU HEADER — elle SORT de la matière
                //    noire : fond noir vrai sur card noire, et un fondu
                //    qui la scelle au corps (jamais une coupe). Elle
                //    joue UNE fois et gèle sur sa dernière frame.
                if let nom = videoNom, robe == .video {
                    VStack(spacing: 0) {
                        // LA TÊTE RÉDUITE (`tete` posée) : 20 pt de noir AU-DESSUS
                        // de la vidéo (verdict « plus de noir au-dessus de la vidéo
                        // Nosfy, écart de 20 px ») — la robe d'origine n'en a pas.
                        if tete != nil { Color.clear.frame(height: Self.noirTete) }
                        VideoVivante(nom: nom, relance: videoRelance,
                                     pente: penteCard,
                                     boucle: style == .welcome,
                                     entier: style == .welcome)
                            .frame(height: hauteur * partTete)
                            .overlay(
                                LinearGradient(
                                    stops: [
                                        .init(color: .clear, location: 0),
                                        .init(color: .clear,
                                              location: style == .welcome
                                                  ? 0.14 : 0.55),
                                        .init(color: .black.opacity(0.22),
                                              location: style == .welcome
                                                  ? 0.42 : 0.72),
                                        .init(color: .black.opacity(0.72),
                                              location: style == .welcome
                                                  ? 0.62 : 0.88),
                                        .init(color: .black, location: 0.80),
                                        .init(color: .black, location: 1)
                                    ],
                                    startPoint: .top, endPoint: .bottom))
                            // ⚠️ LA VIDÉO WELCOME EST PORTRAIT : en
                            // aspectFill elle est coupée NET sur les
                            // flancs — ils se noient dans la matière.
                            .mask(
                                LinearGradient(
                                    stops: style == .welcome ? [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.28),
                                              location: 0.15),
                                        .init(color: .white, location: 0.35),
                                        .init(color: .white, location: 0.65),
                                        .init(color: .white.opacity(0.28),
                                              location: 0.85),
                                        .init(color: .clear, location: 1)
                                    ] : [
                                        .init(color: .white, location: 0),
                                        .init(color: .white, location: 1)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing))
                            // LA TÊTE RÉDUITE (`tete` posée) FOND AUSSI PAR LE
                            // HAUT (verdict 14-09 : « on voit la bordure du haut
                            // coupée avec le background noir ») : le bord haut de
                            // la vidéo se dissout dans les 20 pt de noir au lieu
                            // de s'y couper. La robe d'origine ne bouge pas.
                            .mask(
                                LinearGradient(
                                    stops: tete != nil ? [
                                        .init(color: .clear, location: 0),
                                        .init(color: .white.opacity(0.35),
                                              location: 0.14),
                                        .init(color: .white, location: 0.30),
                                        .init(color: .white, location: 1)
                                    ] : [
                                        .init(color: .white, location: 0),
                                        .init(color: .white, location: 1)
                                    ],
                                    startPoint: .top, endPoint: .bottom))
                            // Le tap RELANCE la vidéo (verdict) — le
                            // drag de la card garde son geste (min 3 pt).
                            .contentShape(Rectangle())
                            .onTapGesture { videoRelance += 1 }
                        Spacer(minLength: 0)
                    }
                    .opacity(sstep(0.10, 0.35, p))
                }

                // 6. LE LISERÉ — neutre, allumé PAR LE BAS comme tout le
                //    reste : c'est lui qui détache le noir du noir.
                Self.forme.strokeBorder(
                    LinearGradient(
                        stops: style == .halo ? [
                            .init(color: .white.opacity(0.08), location: 0),
                            .init(color: .white.opacity(0.12), location: 0.5),
                            .init(color: .white.opacity(0.34), location: 1)
                        ] : [
                            // Néon : plus de lumière du bas — un fil
                            // neutre, à peine là.
                            .init(color: .white.opacity(0.14), location: 0),
                            .init(color: .white.opacity(0.08), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 1)
                    .opacity(sstep(0.12, 0.45, p))

                // 7. L'ENCRE — au-dessus de tout.
                encre(largeur: largeur, hauteur: hauteur)
            }
            // Le clip qui ROGNE les fantômes sur les flancs — constant
            // (le verre garde des bounds immobiles, la loi est sauve).
            .clipShape(Self.forme)
        }
        .frame(width: largeur, height: hauteur)
        // LA CHAUVE-SOURIS QUI TIENT LA CARD — « comme si elle était
        // CACHÉE par la card » (verdict) : elle est montée devant
        // (⚠️ en `background` elle n'apparaissait PAS DU TOUT), mais
        // MASQUÉE sous la ligne du bord haut — la card la coupe net,
        // son corps disparaît derrière la matière.
        .overlay(alignment: .top) {
            if style == .welcome, robe == .texte {
                ChauveQuiTient(naissance: naissance, largeur: largeur)
                    .opacity(sstep(0.30, 0.62, p))
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(0.96 + 0.04 * sstep(0, 0.55, p))
        .opacity(sstep(0, 0.16, p))
        // L'ombre est BLANCHE et tombe vers le bas (verdict) : sur du noir
        // une ombre noire n'existe pas — c'est la lumière du halo qui
        // continue sous la card et la détache de la page.
        .shadow(color: .white.opacity(0.14 * sstep(0.25, 0.65, p)),
                radius: 38, y: 30)
        .modifier(Secousse(trigger: secousse,
                           force: style == .fire ? 2 : 1))
    }

    /// La lune sombre du variant néon — une SCÈNE, pas un dégradé : son
    /// bord se lit contre le noir (la marche 0,05 → 0), le champ de
    /// halation éclaire sa moitié haute, sa base se noie dans la brume.
    private func disqueNuit(largeur: CGFloat, hauteur: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(
                stops: [
                    .init(color: .white.opacity(0.15), location: 0),
                    .init(color: .white.opacity(0.10), location: 0.72),
                    .init(color: .white.opacity(0.05), location: 0.92),
                    .init(color: .clear, location: 1)
                ],
                center: .center,
                startRadius: 0,
                endRadius: largeur * 0.47))
            .frame(width: largeur * 0.94, height: largeur * 0.94)
            .offset(y: -hauteur * 0.10)
            .opacity(sstep(0.20, 0.55, p))
    }

    /// Les voisins de l'odomètre — figés à ±1 du chiffre FINAL (les faire
    /// compter aussi brouillerait la lecture), rognés par le clip.
    /// L'OVERLAY SUR `Color.clear`, et ce n'est pas un style : des Text de
    /// 190 pt en offset GONFLENT leur hôte, et le clip de la card se
    /// calculerait sur les bounds gonflés — les fantômes s'échappaient sur
    /// la page (le piège payé de la fente detail, repayé ici même).
    private func chiffresFantomes(largeur: CGFloat) -> some View {
        // L'écart suit la LARGEUR des voisins : calé 0,53·l pour UN
        // digit, un « 13 » deux fois plus large chevauchait le chiffre
        // principal (relecture adverse) — chaque digit de plus pousse
        // les fantômes de 0,13·l vers l'extérieur.
        let digits = CGFloat("\(count + 1)".count)
        let dx = largeur * (0.53 + 0.13 * (digits - 1))
        return Color.clear
            .overlay {
                ZStack {
                    Text("\(max(count - 1, 0))")
                        .offset(x: -dx)
                    Text("\(count + 1)")
                        .offset(x: dx)
                }
                .font(.inter(190, .medium))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.16))
                .blur(radius: 4)
                .offset(y: 6)
            }
            .allowsHitTesting(false)
            // Des nombres parasites pour VoiceOver, du décor pour l'œil.
            .accessibilityHidden(true)
    }

    private func encre(largeur: CGFloat, hauteur: CGFloat) -> some View {
        VStack(spacing: 0) {
            // LE BLOC DE TÊTE À L'APPLE — SAUF dans la robe You-Made-It
            // ET dans la matrice : là, LE TEXTE GÉANT EST LE MESSAGE, la
            // tête meurt (« enlève le titre Training, Congratulations »).
            if style != .neon, style != .spotlight,
               !(style == .welcome && robe == .texte) {
                Text(title)
                    .font(.inter(20, .bold))
                    .tracking(0.2)
                    .foregroundStyle(WoopGradient.silverText)
                    .opacity(sstep(0.36, 0.58, p))
                    .offset(y: 5 * (1 - sstep(0.36, 0.62, p)))
                    // Avec vidéo, le bloc de tête descend SOUS elle — le
                    // titre se pose dans le fondu, comme la réf du plan.
                    // Tête RÉDUITE (`tete` posée) : le bloc de texte est RABAISSÉ
                    // sous la vidéo (verdict), pas dans son fondu — 20 pt de noir
                    // du haut + la vidéo + 5 % de la card.
                    .padding(.top, videoNom == nil ? 26
                             : tete != nil ? Self.noirTete + hauteur * (partTete + 0.05)
                             : hauteur * (partTete - (style == .welcome ? 0.03 : 0.02)))
                Text(subtitle)
                    .font(.inter(13.5))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 34)
                    .padding(.top, 8)
                    .opacity(sstep(0.42, 0.64, p))
                    .offset(y: 5 * (1 - sstep(0.42, 0.68, p)))
            }
            Spacer(minLength: 0)
            if style == .welcome {
                if robe == .texte {
                    PastilleLuneReward(naissance: naissance)
                        .opacity(sstep(0.34, 0.60, p))
                        .scaleEffect(0.88 + 0.12 * sstep(0.34, 0.68, p))
                } else {
                    Color.clear.frame(height: 1)
                }
            } else if style == .fire {
                // LA FLAMME NOIRE — le sticker laqué qui VIT, et dont le
                // tap fait jaillir la gerbe orange.
                FlammeSticker(naissance: naissance,
                              onJet: { secousse += 1 })
                    .opacity(sstep(0.30, 0.58, p))
                    .scaleEffect(0.86 + 0.14 * sstep(0.30, 0.66, p))
            } else if style == .neon {
                // T2 : LE CHIFFRE DE VERRE — le glyphe en glassEffect
                // natif, posé sur le texte qu'il réfracte, saisissable
                // comme la pill.
                ChiffreVerre(valeur: valeurCourante, naissance: naissance)
                    .opacity(sstep(0.32, 0.55, p))
                    .scaleEffect(0.92 + 0.08 * sstep(0.32, 0.62, p))
            } else if style == .spotlight {
                // L'ARRIVÉE du chiffre (verdict « les chiffres s'animent
                // à l'arrivée ») : il se pose d'un souffle pendant que le
                // count-up tourne — transform, jamais un resize.
                // ⚠️ LE CHIFFRE A SA PROPRE VIE, ET ELLE EST VALIDÉE.
                // Il ne reçoit AUCUNE lumière du halo global : les deux
                // backgrounds (celui du chiffre, celui de la card) sont
                // deux animations INDÉPENDANTES. Les avoir branchées sur
                // la même lumière est ce qui a emporté toute la card.
                ChiffreMatrice(valeur: valeurCourante,
                               naissance: naissance)
                    .opacity(sstep(0.26, 0.44, p))
                    // PLUS GROS (verdict du verre) — l'échelle vit sur la
                    // MATRICE, jamais sur le verre : une transform sur un
                    // glassEffect natif coupe son échantillonnage du fond
                    // (loi payée). L'arrivée d'époque (0,94 → 1) est
                    // absorbée dans la rampe.
                    .scaleEffect(1.22 * (0.94 + 0.06 * sstep(0.26, 0.58, p)))
                    // LE VERRE PAR-DESSUS — le vrai Liquid Glass coulé
                    // dans la silhouette du 4 : il réfracte la matrice, la
                    // pluie et le halo qui passent derrière. Posé en
                    // overlay APRÈS l'échelle : lui n'est jamais
                    // transformé, sa taille vient de son frame.
                    .overlay {
                        VerreQuatre(valeur: valeurCourante,
                                    naissance: naissance)
                            .opacity(sstep(0.42, 0.68, p))
                    }
                    // LE CHIFFRE DESCEND (« tu dois aussi baisser un peu
                    // le chiffre au milieu de la carte pour laisser place
                    // à ce magnifique texte »). Son composant ne change
                    // pas d'une ligne : seule sa POSITION bouge.
                    .offset(y: 46 * sstep(0.26, 0.58, p))
            } else {
                ChiffreReward(valeur: valeurCourante,
                              corps: videoNom == nil ? 190 : 118)
                    .opacity(sstep(0.26, 0.44, p))
                    .scaleEffect(0.95 + 0.05 * sstep(0.26, 0.58, p))
                    // LE GALET DE VERRE (variant .galet) — posé SUR le
                    // chiffre en overlay (le layout ne bouge pas), il
                    // arrive une fois le chiffre posé.
                    .overlay {
                        if style == .galet {
                            GaletVerre(naissance: naissance)
                                .opacity(sstep(0.55, 0.85, p))
                        }
                    }
            }
            Spacer(minLength: 0)
            if style == .neon {
                // La ligne calme de la réf (« A new milestone has been
                // reached. ») — le sous-titre, seul, en bas.
                Text(subtitle)
                    .font(.inter(13.5))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .opacity(sstep(0.48, 0.72, p))
            } else if style == .welcome {
                Color.clear.frame(height: 2)
            } else if !unit.isEmpty {
                // L'unité en blanc dans la fumée — halo et galet.
                Text(unit)
                    .font(.inter(19, .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .opacity(sstep(0.48, 0.70, p))
                    .offset(y: 5 * (1 - sstep(0.48, 0.74, p)))
            }
            // LE BOUTON CLAIM (welcome) — la capsule de VRAI verre avec
            // la pièce de la maison ; ailleurs, le lien nu.
            // Le Claim — sauf quand la card porte SON bouton (la robe « première
            // fois » de Nosfy : « Démarrer », rien à encaisser).
            if style == .welcome, bouton == nil {
                BoutonClaim(montant: count, action: claimEtFermer)
                    .opacity(sstep(0.58, 0.86, p))
                    .padding(.bottom, 6)
            }
            // Le BOUTON LIEN (verdict « pour consistance ») : de l'encre
            // nue, pas de cadre — la zone de toucher reste large.
            if case .capsule(let titre)? = bouton {
                // LA SORTIE DE NOSFY : « Entrer », la capsule de verre du Claim.
                BoutonVerre(titre: titre, action: fermer)
                    .opacity(sstep(0.64, 0.90, p))
                    .padding(.bottom, 22)
            } else {
                Button(action: fermer) {
                    Text(style == .welcome ? "Later" : "Close")
                        .font(.inter(15, .medium))
                        .foregroundStyle(Color.white.opacity(0.66))
                        .frame(height: 44)
                        .padding(.horizontal, 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(sstep(0.64, 0.90, p))
                .padding(.bottom, 10)
            }
        }
    }

    /// L'échelle des mots de Nosfy : le mot le plus long doit tenir dans la card
    /// (l'avance d'une lettre LARGE d'Inter Heavy à 112 pt ≈ 86 pt, tracking
    /// compris — le pire cas, pas la moyenne : un prénom n'est pas « ALLEZ »).
    static func echelleGeante(_ lignes: [String], largeur: CGFloat) -> CGFloat {
        let plusLong = lignes.map(\.count).max() ?? 1
        return min(0.96, (largeur - 24) / (CGFloat(plusLong) * 86))
    }

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// LA CAPSULE DE VERRE sans la pièce — la recette exacte de `BoutonClaim` (du
/// VERRE, pas du frost ; conteneur à taille constante), un libellé seul.
private struct BoutonVerre: View {
    let titre: String
    var action: () -> Void

    @State private var appuye = false

    var body: some View {
        Button(action: action) {
            Text(titre)
                .font(.inter(16, .semibold))
                .foregroundStyle(Color.white.opacity(0.95))
                .padding(.horizontal, 36)
                .frame(height: 52)
                .background {
                    GlassEffectContainer(spacing: 0) {
                        Color.clear
                            .glassEffect(.clear.interactive(), in: Capsule())
                    }
                    .environment(\.colorScheme, .dark)
                }
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.42), location: 0),
                                .init(color: .white.opacity(0.10), location: 0.55),
                                .init(color: .white.opacity(0.24), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing),
                        lineWidth: 1))
                .contentShape(Capsule())
                .scaleEffect(appuye ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: appuye)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in appuye = true }
                .onEnded { _ in appuye = false })
    }
}

/// LA POUDRE DE DIAMANT — la recette éprouvée de `PoudreBooster` (Canvas
/// sous TimelineView 30 Hz, grains-étoiles déterministes par hash,
/// l'additif demandé AU CONTEXTE, jamais à la vue), passée au monochrome :
/// des facettes blanches et bleu-glace qui ne vivent que dans le halo du
/// bas et scintillent TRANCHÉ.
struct PoudreDiamant: View {
    var largeur: CGFloat
    var hauteur: CGFloat
    var naissance: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 44 grains à 30 Hz : une broutille pour le Canvas, assez pour que
    /// la poudre existe.
    private static let grains = 72

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            Canvas { ctx, _ in
                ctx.blendMode = .plusLighter
                for i in 0 ..< Self.grains {
                    let vie = 2.8 + 3.2 * Self.hash(i, 2)
                    let cyc = (t / vie + Self.hash(i, 5))
                        .truncatingRemainder(dividingBy: 1)
                    // Naît dans la fumée du bas et monte d'un souffle.
                    let cx = largeur / 2
                        + (Self.hash(i, 1) - 0.5) * largeur * 0.86
                    let base = 0.50 + 0.46 * Self.hash(i, 3)
                    let cy = hauteur * base
                    let x = cx + sin(t * (0.35 + 0.5 * Self.hash(i, 8))
                                     + Self.hash(i, 9) * 6.28) * 8
                    let y = cy - CGFloat(cyc) * hauteur * 0.30
                    // Entre en douceur, meurt en montant, scintille
                    // TRANCHÉ — et brille d'autant plus qu'il est né bas,
                    // dans la lumière (la loi du métal : les paillettes ne
                    // vivent que dans la lumière).
                    let s = sin(.pi * cyc)
                    let tw = 0.5 + 0.5 * sin(t * (7 + 12 * Self.hash(i, 4))
                                             + Self.hash(i, 6) * 6.28)
                    let bas = 0.30 + 0.70 * (base - 0.50) / 0.46
                    let a = s * s * (0.18 + 0.82 * tw * tw * tw) * bas
                    guard a > 0.02 else { continue }
                    let r = CGFloat(0.6 + 1.5 * Self.hash(i, 7))
                    // Deux glaces : le blanc pur et le bleu-diamant.
                    let c = Self.hash(i, 10) < 0.4
                        ? Color.white
                        : Color(red: 0.90, green: 0.95, blue: 1.00)
                    var etoile = Path()
                    etoile.move(to: CGPoint(x: -r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: -r * 0.22))
                    etoile.addLine(to: CGPoint(x: r, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r * 0.22))
                    etoile.closeSubpath()
                    etoile.move(to: CGPoint(x: 0, y: -r))
                    etoile.addLine(to: CGPoint(x: r * 0.22, y: 0))
                    etoile.addLine(to: CGPoint(x: 0, y: r))
                    etoile.addLine(to: CGPoint(x: -r * 0.22, y: 0))
                    etoile.closeSubpath()
                    ctx.fill(etoile.applying(
                        CGAffineTransform(translationX: x, y: y)
                            .rotated(by: (Self.hash(i, 11) - 0.5) * 0.9)),
                             with: .color(c.opacity(a * 0.85)))
                    // Le cœur vif — c'est lui la facette.
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - 0.45, y: y - 0.45,
                                               width: 0.9, height: 0.9)),
                        with: .color(Color.white.opacity(a * 0.9)))
                }
            }
        }
        .allowsHitTesting(false)
        .frame(width: largeur, height: hauteur)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}

/// Le chiffre géant — encre en dégradé blanc → transparent, dont l'axe
/// PENCHE avec le téléphone : le foil de la maison, en gradient pur.
/// Monospacé : le layout ne respire pas entre 9 et 10.
private struct ChiffreReward: View {
    let valeur: Int
    /// Le corps de la fonte — 190 en pleine card, réduit quand une
    /// vidéo occupe le header.
    var corps: CGFloat = 190

    var body: some View {
        let tilt = SkyMotion.shared.tilt
        Text("\(valeur)")
            .font(.inter(corps, .medium))
            .monospacedDigit()
            .tracking(-2)
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white.opacity(0.92), location: 0.55),
                        .init(color: .white.opacity(0.50), location: 1)
                    ],
                    startPoint: UnitPoint(x: 0.5 - 0.30 * tilt.dx, y: 0),
                    endPoint: UnitPoint(x: 0.5 + 0.30 * tilt.dx, y: 1)))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

// MARK: - Le spotlight (jalon S1 : la trame morte)

/// LE CHIFFRE-MATRICE — le métal sombre, et DANS le glyphe la trame de
/// micro-mots. S1 : la trame est MORTE (repos 0,07) avec UN front de
/// vague FIGÉ aux deux tiers (l'état reduceMotion du plan) pour juger
/// contenu/typo/densité sur capture. Les vagues vivantes sont S2.
///
/// L'architecture qui tiendra la cadence en S2 : la trame ne se
/// redessine JAMAIS — deux couches de LA MÊME trame (sombre + claire),
/// le front n'est qu'un MASQUE en gradient, et le tout est masqué par
/// le glyphe (l'allumage coupe donc mi-token, caractère par caractère,
/// gratuitement). La trame déborde le glyphe : elle vit en overlay du
/// chiffre et le masque-glyphe fait le rognage — l'hôte ne gonfle pas
/// (la fente).
private struct ChiffreMatrice: View {
    let valeur: Int

    /// La comparaison restante du jalon S1 (sur captures) : `-spotAlea`
    /// (aléatoire pur vs 70/30 bribes réelles). LE VIOLET EST MORT
    /// (verdict : « ça existe pas dans l'app — des nuances de blanc,
    /// mais pas plus »).
    private static let alea = CommandLine.arguments.contains("-spotAlea")

    /// L'horloge des vagues et de la pluie.
    let naissance: Date

    /// Le tic des MUTATIONS — un caractère change de temps en temps,
    /// jamais plus (le tic Matrix, subliminal).
    @State private var mut = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func glyphe() -> Text {
        Text("\(valeur)")
            .font(.inter(160, .heavy))
            .monospacedDigit()
            .tracking(-1)
    }

    /// La hauteur de la grille (24 rangées de ~10 pt) — la période de la
    /// pluie : deux copies empilées défilent, le raccord est invisible.
    private static let hGrille: CGFloat = 24 * 10 + 23 * 2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            corps(t: tl.date.timeIntervalSince(naissance))
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(0.7))
                mut += 1
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func corps(t: Double) -> some View {
        let tilt = SkyMotion.shared.tilt
        return glyphe()
            // La face métal — sombre : le chiffre n'existe que là où la
            // lumière le touchera (S3, la lampe).
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.34), location: 0),
                        .init(color: .white.opacity(0.14), location: 0.5),
                        .init(color: .white.opacity(0.07), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom))
            // LE DÉGRADÉ BLANC LÉGER AUTOUR (verdict) — le souffle qui
            // détache le chiffre de la nuit, jamais un néon.
            .background {
                glyphe()
                    .foregroundStyle(Color.white)
                    .blur(radius: 24)
                    .opacity(0.15)
            }
            // LE REFLET AU SOL (verdict — l'effet miroir de la maison) :
            // le glyphe retourné, écrasé d'un souffle, qui meurt vite.
            .background(alignment: .top) {
                glyphe()
                    .foregroundStyle(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.22),
                                      location: 0),
                                .init(color: .white.opacity(0.05),
                                      location: 0.45),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .bottom, endPoint: .top))
                    .scaleEffect(x: 1, y: -0.92, anchor: .center)
                    .blur(radius: 1.5)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.6), location: 0),
                                .init(color: .clear, location: 0.55)
                            ],
                            startPoint: .top, endPoint: .bottom))
                    .opacity(0.5)
                    .offset(y: 158)
            }
            .overlay {
                ZStack {
                    // La trame au repos — presque noire, une texture
                    // qu'on devine, pas qu'on lit.
                    pluie(t: t)
                        .opacity(0.10)
                    // LES VAGUES — la même trame, claire, masquée par
                    // des fronts qui RESPIRENT et dérivent (périodes
                    // premières entre elles, le gyro incline la course).
                    pluie(t: t)
                        .mask(vagues(t: t, tilt: tilt))
                }
                // Le glyphe rogne tout : la matrice n'existe QUE dans
                // le mot.
                .mask(glyphe())
            }
    }

    /// LA PLUIE — la trame défile lentement vers le bas, deux copies
    /// empilées pour un raccord invisible. La trame elle-même ne se
    /// redessine JAMAIS par frame (entrées stables hors `mut`).
    private func pluie(t: Double) -> some View {
        let y = CGFloat((t * 7.0)
            .truncatingRemainder(dividingBy: Double(Self.hGrille)))
        return ZStack {
            TrameMatrice(alea: Self.alea, mut: mut)
                .offset(y: y)
            TrameMatrice(alea: Self.alea, mut: mut)
                .offset(y: y - Self.hGrille)
        }
    }

    /// Les deux fronts vivants — le maître large, l'écho latéral faible.
    private func vagues(t: Double, tilt: CGVector) -> some View {
        ZStack {
            EllipticalGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.5), location: 0.5),
                    .init(color: .clear, location: 1)
                ],
                center: UnitPoint(
                    x: 0.42 + 0.22 * sin(t * 0.23) + 0.15 * tilt.dx,
                    y: 0.36 + 0.20 * cos(t * 0.17) + 0.12 * tilt.dy),
                startRadiusFraction: 0,
                endRadiusFraction: 0.80)
            EllipticalGradient(
                stops: [
                    .init(color: .white.opacity(0.6), location: 0),
                    .init(color: .clear, location: 1)
                ],
                center: UnitPoint(
                    x: 0.68 - 0.24 * sin(t * 0.31 + 2.1),
                    y: 0.70 + 0.16 * cos(t * 0.29 + 0.8)),
                startRadiusFraction: 0,
                endRadiusFraction: 0.45)
        }
    }
}

/// LE 4 DE VERRE (card matrice) — le vrai Liquid Glass coulé dans la
/// silhouette du chiffre, par-dessus SA matrice (validée, intouchée) :
/// c'est elle, la pluie et le halo qu'il réfracte. Et LES NUANCES ROUGE
/// ET BLANC (verdict « avec des nuances de rouge et blanc, trop beau »),
/// PEINTES PAR-DESSUS le verre — la loi du galet : jamais d'ombre
/// dessous, jamais de transform ; toute la vie passe par l'offset et par
/// ce qu'on peint dessus.
struct VerreQuatre: View {
    let valeur: Int
    var naissance: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var prise = CGSize.zero
    @State private var enMain = false
    @State private var grab = 0
    @State private var drop = 0

    /// Le rouge de la maison — anti-brun : R à 1, le vert désaturé.
    private static let braise = Color(red: 1.0, green: 0.18, blue: 0.03)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            let tilt = SkyMotion.shared.tilt
            let libre: CGFloat = enMain ? 0.25 : 1
            // Dérive COURTE (la loi du galet, cause 3) : le verre doit
            // rester sur sa matrice — c'est elle qu'il réfracte, au-delà
            // il n'a plus rien à plier.
            let x = (sin(t * 0.50) * 7 + sin(t * 0.93 + 1.7) * 3) * libre
                + 8 * tilt.dx
            let y = (cos(t * 0.41 + 0.8) * 5 + sin(t * 0.77) * 2) * libre
                + 5 * tilt.dy
            verre.offset(x: x, y: y)
        }
        .offset(prise)
        .gesture(saisie)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: grab)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7),
                         trigger: drop)
        .accessibilityLabel("\(valeur)")
    }

    private var verre: some View {
        let forme = FormeGlyphe(texte: "\(valeur)")
        return Color.clear
            // La taille vit ICI, dans le frame — jamais dans une échelle.
            .frame(width: 126, height: 158)
            .glassEffect(.clear.interactive(), in: forme)
            .environment(\.colorScheme, .dark)
            // Le fil d'arête — BLANC en crête, BRAISE au pied : la
            // première des deux nuances.
            .overlay(
                forme.stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.55), location: 0),
                            .init(color: .white.opacity(0.10),
                                  location: 0.55),
                            .init(color: Self.braise.opacity(0.85),
                                  location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 1.1))
            // La nappe interne — la seconde nuance : un souffle blanc en
            // crête, la braise qui monte du pied. En .screen, opacités
            // BASSES : des nuances, jamais une teinte qui repeint (et
            // jamais le laiteux).
            .overlay(
                forme.fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.14), location: 0),
                            .init(color: .clear, location: 0.40),
                            .init(color: Self.braise.opacity(0.26),
                                  location: 0.72),
                            .init(color: Self.braise.opacity(0.55),
                                  location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .blendMode(.screen)
                    .allowsHitTesting(false))
            .contentShape(forme)
    }

    private var saisie: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !enMain {
                    enMain = true
                    grab += 1
                }
                prise = v.translation
            }
            .onEnded { _ in
                enMain = false
                drop += 1
                // Le ressort vit sur le MODIFICATEUR `.offset(prise)` —
                // la leçon payée : une valeur modèle lue dans le calcul
                // par frame sauterait à sa cible sous withAnimation.
                withAnimation(.spring(response: 0.48,
                                      dampingFraction: 0.68)) {
                    prise = .zero
                }
            }
    }
}

/// LA TRAME — la grille de micro-mots, rendue UNE fois (contenu par
/// hash déterministe, jamais un random par frame). Une rangée = UN Text
/// (le mi-token vient des masques, pas du découpage).
private struct TrameMatrice: View {
    let alea: Bool
    /// Le tic des mutations — UN mot change par tic, jamais plus.
    let mut: Int

    private static let alphabet =
        Array("ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz0123456789+")
    /// Les bribes réelles de la maison — ce qu'une vague laisse
    /// attraper : des fragments de SA séance.
    private static let bribes = [
        "24KG", "12X3", "AUG25", "SETS", "+20", "REST60", "17KMH",
        "1280KG", "PR", "W4", "+4KG", "NOSFY"
    ]

    var body: some View {
        // Hors layout : la grille déborde, l'hôte ne doit rien sentir.
        Color.clear
            .overlay {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(0..<24, id: \.self) { r in
                        Text(Self.ligne(r, alea: alea, mut: mut))
                            .font(.system(size: 8, weight: .semibold,
                                          design: .monospaced))
                            .tracking(0.5)
                            .foregroundStyle(Self.encre(r))
                            .lineLimit(1)
                            .fixedSize()
                            .offset(x: CGFloat(Self.hash(r, 40) * 34.0) - 17)
                    }
                }
            }
    }

    /// L'encre d'une rangée — DES NUANCES DE BLANC, rien d'autre (le
    /// violet est mort par verdict) : trois blancs tirés par hash, la
    /// trame respire sans jamais changer de couleur.
    private static func encre(_ r: Int) -> Color {
        let n = hash(r, 50)
        if n < 0.30 { return Color.white.opacity(0.70) }
        if n < 0.65 { return Color.white.opacity(0.84) }
        return Color.white.opacity(0.96)
    }

    private static func ligne(_ r: Int, alea: Bool, mut: Int) -> String {
        // LA MUTATION : au tic `mut`, UN SEUL mot de UNE rangée change
        // (le tic Matrix, subliminal) — tout le reste est éternel.
        let rMut = mut % 24
        let cMut = (mut / 24 + mut) % 7
        var mots: [String] = []
        for c in 0..<7 {
            let graine = r * 31 + c
                + ((r == rMut && c == cMut) ? (mut + 1) * 7919 : 0)
            // 70/30 : le fond aléatoire, et les bribes réelles semées
            // (positions stables par hash — elles ne bougent jamais).
            if !alea, hash(graine, 20) < 0.30 {
                mots.append(bribes[Int(hash(graine, 21)
                                       * Double(bribes.count))])
            } else {
                let long = 5 + Int(hash(graine, 22) * 4)
                var mot = ""
                for k in 0..<long {
                    mot.append(alphabet[Int(hash(graine * 13 + k, 23)
                                            * Double(alphabet.count))])
                }
                mots.append(mot)
            }
        }
        return mots.joined(separator: " :.. ")
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return min(s - floor(s), 0.999)
    }
}

// MARK: - Welcome Back, robe TEXTE : la pastille et la chauve-souris

/// LA PASTILLE-LUNE DE LA CARD REWARD (l'asset de Kathryn,
/// détouré) — ⚠️ `PastilleLune` tout court existe déjà dans
/// WidgetEdition : ne pas reprendre ce nom — on ne la retouche
/// pas, ON L'ÉCLAIRE : elle flotte, s'incline au gyro, et son
/// paillettage S'ALLUME au passage du faisceau (même horloge que le
/// spotlight). La lune gravée prend son souffle chaud quand la lumière
/// la traverse, et ses propres paillettes vivent DANS sa silhouette.
private struct PastilleLuneReward: View {
    let naissance: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cote: CGFloat = 124

    var body: some View {
        // 30 Hz : le flottement est LENT, 60 Hz coûtait le double pour
        // rien (la card laguait).
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            let b = balayageSpot(t)
            let tilt = SkyMotion.shared.tilt
            // Elle FLOTTE — trois horloges premières, jamais une boucle.
            let flotte = CGFloat(sin(t * 0.62) * 7 + sin(t * 1.13 + 0.9) * 3)
            let derive = CGFloat(cos(t * 0.47 + 1.4) * 5)
            let souffle = 1 + 0.022 * sin(t * 0.83)
            Image("sticker-pastille-lune")
                .resizable()
                .scaledToFit()
                .frame(width: Self.cote, height: Self.cote)
                // ⚠️ UNE SEULE IMAGE (la cadence est payée ici) : la
                // lumière est un DÉGRADÉ posé sur sa forme, jamais une
                // deuxième copie du sticker en colorMultiply — trois
                // copies à 60 Hz faisaient lager la card.
                .overlay {
                    RoundedRectangle(cornerRadius: Self.cote * 0.22,
                                     style: .continuous)
                        .fill(
                            EllipticalGradient(
                                stops: [
                                    .init(color: .white.opacity(0.30),
                                          location: 0),
                                    .init(color: .white.opacity(0.07),
                                          location: 0.45),
                                    .init(color: .clear, location: 1)
                                ],
                                center: UnitPoint(x: 0.5 - 0.55 * b,
                                                  y: 0.22 + 0.10 * b),
                                startRadiusFraction: 0,
                                endRadiusFraction: 0.55))
                        .blendMode(.screen)
                        .padding(2)
                        .allowsHitTesting(false)
                }
                // Le halo qui la décolle de la nuit.
                .background(
                    Circle()
                        .fill(RadialGradient(
                            stops: [
                                .init(color: .white.opacity(0.16),
                                      location: 0),
                                .init(color: .clear, location: 1)
                            ],
                            center: .center,
                            startRadius: 0, endRadius: 130))
                        .frame(width: 200, height: 200)
                        .blur(radius: 14)
                        .allowsHitTesting(false))
                .scaleEffect(souffle)
                // ⚠️ PLUS AUCUNE ROTATION 3D : elle force une passe de
                // rendu HORS ÉCRAN à chaque image — c'est elle qui
                // faisait lager la card (verdict). Il ne reste que des
                // TRANSFORMS plats : offset et scale, gratuits.
                .offset(x: derive, y: flotte)
        }
        .frame(height: 168)
        .accessibilityHidden(true)
    }
}

/// LA CHAUVE-SOURIS QUI TIENT LA CARD (l'asset détouré : le rectangle
/// blanc effacé, LES GRIFFES gardées, le fond noir transparent). Elle
/// se balance très lentement — elle porte un poids.
private struct ChauveQuiTient: View {
    let naissance: Date
    let largeur: CGFloat

    /// ⚠️ ELLE NE BOUGE PAS, ET C'EST VOULU (verdict) : son
    /// balancement imposait un TimelineView de plus sur la card — la
    /// pastille laguait déjà. Une image STATIQUE ne coûte rien : elle
    /// est simplement POSÉE, ses pattes sur la bordure.
    var body: some View {
        let l = largeur * 0.34
        Image("sticker-chauve-tient")
            .resizable()
            .scaledToFit()
            .frame(width: l)
            .offset(y: -l * 1.30 + 45)
            .accessibilityHidden(true)
    }
}

// MARK: - La robe FIRE (variant 4) et le bouton CLAIM

/// LA SECOUSSE — le tressaillement sec de la card : un aller-retour
/// amorti en KEYFRAMES (un aller-retour ne se fait JAMAIS en deux
/// `withAnimation` sur la même valeur — la loi maison).
private struct Secousse: ViewModifier {
    let trigger: Int
    /// 1 = l'arrivée de n'importe quelle card ; 2 = le feu (verdict :
    /// « pour la flamme, deux fois plus forte »).
    var force: CGFloat = 1

    func body(content: Content) -> some View {
        KeyframeAnimator(initialValue: CGSize.zero,
                         trigger: trigger) { val in
            content.offset(val)
        } keyframes: { _ in
            KeyframeTrack(\.width) {
                SpringKeyframe(-19 * force, duration: 0.045)
                SpringKeyframe(17 * force, duration: 0.06)
                SpringKeyframe(-12 * force, duration: 0.06)
                SpringKeyframe(8 * force, duration: 0.06)
                SpringKeyframe(-4 * force, duration: 0.07)
                SpringKeyframe(0, duration: 0.13)
            }
            KeyframeTrack(\.height) {
                SpringKeyframe(11 * force, duration: 0.05)
                SpringKeyframe(-8 * force, duration: 0.07)
                SpringKeyframe(4 * force, duration: 0.07)
                SpringKeyframe(0, duration: 0.18)
            }
        }
    }
}

/// LE CHIFFRE RÉVÉLÉ — le chiffre ÉNORME qui prend TOUTE la card,
/// presque invisible au repos : c'est LA LUMIÈRE qui le découvre, au
/// balayage du spotlight. Son pied PLONGE dans le footer, coupé et
/// fondu (flancs et bas) — l'effet majestueux. La technique de la
/// matrice : le glyphe ne se redessine pas, le MASQUE glisse dessus.
private struct ChiffreRevele: View {
    let valeur: Int
    let naissance: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func glyphe() -> Text {
        Text("\(valeur)")
            .font(.inter(430, .bold))
            .monospacedDigit()
            .tracking(-16)
    }

    /// Le métal : blanc franc en crête, et la BRAISE au pied — le rouge
    /// reste saturé (loi anti-brun), il n'envahit jamais le blanc.
    private var metal: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white.opacity(0.62), location: 0.30),
                .init(color: .white.opacity(0.26), location: 0.58),
                .init(color: Color(red: 1.0, green: 0.34, blue: 0.12)
                    .opacity(0.22), location: 0.80),
                .init(color: Color(red: 1.0, green: 0.20, blue: 0.04)
                    .opacity(0.10), location: 1)
            ],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            let b = balayageSpot(tl.date.timeIntervalSince(naissance))
            Color.clear
                .overlay {
                    ZStack {
                        // La braise : ce qu'on devine du chiffre dans
                        // l'ombre — presque rien (verdict « beaucoup
                        // plus caché : c'est la lumière qui le découvre »).
                        glyphe()
                            .foregroundStyle(Color.white.opacity(0.028))
                        // LE RÉVÉLÉ : le métal découpé par le faisceau.
                        glyphe()
                            .foregroundStyle(metal)
                            .mask(
                                EllipticalGradient(
                                    stops: [
                                        .init(color: .white, location: 0),
                                        .init(color: .white.opacity(0.62),
                                              location: 0.30),
                                        .init(color: .white.opacity(0.18),
                                              location: 0.62),
                                        .init(color: .clear, location: 1)
                                    ],
                                    center: UnitPoint(x: 0.5 - 0.58 * b,
                                                      y: 0.30 + 0.12 * b),
                                    startRadiusFraction: 0,
                                    endRadiusFraction: 0.60))
                    }
                    .fixedSize()
                    // Les FLANCS se noient (il sort de la nuit).
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.35),
                                      location: 0.10),
                                .init(color: .white, location: 0.30),
                                .init(color: .white, location: 0.70),
                                .init(color: .white.opacity(0.35),
                                      location: 0.90),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .leading, endPoint: .trailing))
                    // …et LE PIED PLONGE AU FOOTER, déjà fondu.
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.55),
                                      location: 0),
                                .init(color: .white, location: 0.18),
                                .init(color: .white.opacity(0.75),
                                      location: 0.62),
                                .init(color: .white.opacity(0.22),
                                      location: 0.86),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top, endPoint: .bottom))
                    .offset(y: 92)
                }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// LA FLAMME NOIRE ET SA VOLÉE — le sticker laqué de Kathryn au centre,
/// qui RESPIRE, se balance et vacille (trois horloges premières entre
/// elles : jamais une boucle) ; au TAP — et une PREMIÈRE FOIS toute
/// seule à l'arrivée — des dizaines de petits stickers flamme ORANGE
/// jaillissent en gerbe et retombent.
private struct FlammeSticker: View {
    let naissance: Date
    /// La scène est prévenue : elle SECOUE la card.
    var onJet: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var jet: Date?
    @State private var boum = 0

    /// « Des dizaines » de flammes par gerbe.
    private static let grains = 42

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            // Elle VIT : respiration ample, balancement, vacillement.
            let souffle = 1 + 0.075 * sin(t * 1.35)
                + 0.030 * sin(t * 2.30 + 1.1)
            let flotte = CGFloat(sin(t * 0.75) * 11
                                 + sin(t * 1.62 + 0.7) * 4)
            let balance = sin(t * 0.93 + 0.3) * 4.5 + sin(t * 1.71) * 1.8
            ZStack {
                if let jet {
                    gerbe(age: tl.date.timeIntervalSince(jet))
                }
                Image("sticker-flamme-noir")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 158)
                    .scaleEffect(x: souffle - 0.018 * sin(t * 1.35),
                                 y: souffle, anchor: .bottom)
                    .rotationEffect(.degrees(balance), anchor: .bottom)
                    .offset(y: flotte)
                    // La braise sous le sticker : il ne flotte pas dans
                    // le vide, il COUVE.
                    .background(
                        Ellipse()
                            .fill(RadialGradient(
                                stops: [
                                    .init(color: Color(red: 1, green: 0.30,
                                                       blue: 0.06)
                                        .opacity(0.44), location: 0),
                                    .init(color: .clear, location: 1)
                                ],
                                center: .center,
                                startRadius: 0, endRadius: 90))
                            .frame(width: 210, height: 150)
                            .blur(radius: 18)
                            .blendMode(.screen)
                            .allowsHitTesting(false))
            }
        }
        .frame(height: 250)
        // Seule la flamme écoute le doigt (la gerbe est du décor).
        .contentShape(Circle().inset(by: 40))
        .onTapGesture {
            jet = Date()
            boum += 1
            onJet()
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0),
                         trigger: boum)
        .accessibilityLabel("Flamme")
        // LA PREMIÈRE GERBE PART SEULE : la card arrive, le feu jaillit
        // — l'utilisateur découvre le geste en le voyant.
        .task {
            try? await Task.sleep(for: .seconds(0.55))
            jet = Date()
            boum += 1
            onJet()
        }
        // Le banc : `-fireAuto` tape la flamme tout seul.
        .task {
            guard CommandLine.arguments.contains("-fireAuto") else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.4))
                jet = Date()
                boum += 1
                onJet()
            }
        }
    }

    /// La gerbe : chaque grain part en éventail, tourne, retombe et
    /// s'éteint — trajectoire déterministe par hash, le sprite résolu
    /// UNE fois (jamais par grain — la loi PoudreBooster).
    private func gerbe(age: Double) -> some View {
        Canvas { ctx, size in
            guard age < 2.6 else { return }
            let sprite = ctx.resolve(Image("sticker-flamme"))
            let cx = size.width / 2
            let cy = size.height / 2
            for i in 0 ..< Self.grains {
                let retard = Self.hash(i, 9) * 0.22
                let u = age - retard
                guard u > 0, u < 2.4 else { continue }
                let angle = (-Double.pi / 2)
                    + (Self.hash(i, 1) - 0.5) * 2.1
                let vitesse = 210 + 340 * Self.hash(i, 2)
                let x = cx + CGFloat(cos(angle) * vitesse * u)
                let y = cy + CGFloat(sin(angle) * vitesse * u
                                     + 430 * u * u)
                let taille = CGFloat(15 + 26 * Self.hash(i, 3))
                let vie = 1.5 + 0.9 * Self.hash(i, 4)
                let a = max(0, 1 - u / vie)
                guard a > 0.02 else { continue }
                var couche = ctx
                couche.opacity = a
                couche.translateBy(x: x, y: y)
                couche.rotate(by: .radians(
                    (Self.hash(i, 5) - 0.5) * 5 + u * 3.4
                    * (Self.hash(i, 6) - 0.5)))
                couche.draw(sprite,
                            in: CGRect(x: -taille / 2, y: -taille / 2,
                                       width: taille, height: taille))
            }
        }
        .allowsHitTesting(false)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}

/// LE BOUTON CLAIM (robe welcome) — la capsule de VRAI verre qui porte
/// le gain : le « +20 » à l'or de la maison et la PIÈCE 3D gelée
/// (`MoonCoinView`, jamais une image — la recette de BRAVO).
private struct BoutonClaim: View {
    let montant: Int
    var action: () -> Void

    @State private var appuye = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text("Claim")
                    .font(.inter(16, .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                Text("+\(montant)")
                    .font(.inter(16, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.woopGold.opacity(0.95))
                MoonCoinView(coinR: 12, draggable: false,
                             yawOverride: 0.34, idleLife: 0, fps: 6,
                             reveal: 0.34, matte: 1)
                    .frame(width: 12 * MoonCoinView.hostScale,
                           height: 12 * MoonCoinView.hostScale)
                    .frame(width: 26, height: 26)
                    // ⚠️ LA PIÈCE 3D NE PREND PAS LE TAP (20-09) : `MoonCoinView`
                    // porte son propre `onTapGesture` (MoonCoinLab) — au bout
                    // droit de la capsule, il volait le tap au bouton, et le
                    // Claim ne partait pas. Elle est décorative ici.
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 26)
            .frame(height: 52)
            .background {
                // DU VERRE, PAS DU FROST (verdict) : `.clear` — la
                // LENTILLE, celle qui PLIE ce qui passe dessous ; le
                // `.regular` ne fait que dépolir. Dans un
                // GlassEffectContainer à TAILLE CONSTANTE (le piège des
                // bounds vivants). Ce qu'il réfracte : LA GROSSE
                // PILULE NOIRE peinte juste dessous (voir `souffleVideo`
                // dans la scène) — sans matière derrière lui, un verre
                // sur du noir est un TROU.
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .glassEffect(.clear.interactive(), in: Capsule())
                }
                .environment(\.colorScheme, .dark)
            }
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.42), location: 0),
                            .init(color: .white.opacity(0.10), location: 0.55),
                            .init(color: .white.opacity(0.24), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    lineWidth: 1))
            .contentShape(Capsule())
            .scaleEffect(appuye ? 0.96 : 1)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: appuye)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in appuye = true }
                .onEnded { _ in appuye = false })
        // ⚠️ LE +10 DU WELCOME BACK NE PARTAIT PAS AU TAP (bug Kathryn 16-09).
        // Cause : le fond du bouton est un VERRE `.interactive()` (`glassEffect(
        // .clear.interactive())`) — et un verre interactif VOLE le geste de son
        // hôte (le `Button`), donc `action` (reclamerRetour) ne se déclenchait
        // jamais. Remède du dépôt : un `highPriorityGesture(TapGesture)` qui
        // gagne le tap sur le verre. Idempotent : reclamerRetour se garde
        // (retourDisponible) si jamais le Button passait aussi.
        .highPriorityGesture(TapGesture().onEnded { action() })
    }
}

// MARK: - La robe « You Made It » (le variant 2 refait)

/// LE BALAYAGE DU SPOT (verdict « il doit aller de droite à gauche ») —
/// l'horloge PARTAGÉE du faisceau : la lampe penche son cône ET la
/// lumière posée sur les lettres suivent la même sinusoïde, au même
/// instant. Période ~9,7 s.
func balayageSpot(_ t: Double) -> Double {
    // Deux harmoniques (périodes premières entre elles) : la course est
    // large ET jamais mécanique — le projecteur CHERCHE.
    let v = sin(t * 0.62) * 0.78 + sin(t * 0.29 + 1.3) * 0.30
    return max(-1, min(1, v))
}

/// LE TEXTE GÉANT — les trois rangées qui remplissent la card, rognées
/// par les flancs (jamais rétrécies), en argent sombre ÉCLAIRÉ PAR LA
/// LAMPE : une copie sombre + une copie claire masquée par le champ de
/// lumière qui descend de la barrette (la technique de la matrice — la
/// trame ne se redessine pas, seule la lumière la révèle). Hors layout
/// (la fente ne gonfle pas), le clip de la card rogne.
struct TexteGeant: View {
    /// L'horloge du scintillement.
    let naissance: Date
    /// LES MOTS — jamais en dur (contrat du plan backend : l'IA les
    /// fournira). Le corps se calcule ICI, jamais côté IA : le Design
    /// System décide de la typo. Deux lignes respirent plus que trois.
    var lignes: [String] = ["YOU", "MADE", "IT"]

    private var corps: CGFloat { lignes.count <= 2 ? 128 : 112 }

    /// ⚠️ **LE MOT LONG DÉBORDAIT** (06-09). Le garde-fou n'avait qu'UN palier —
    /// au-delà de 4 caractères, ×0,88, une fois pour toutes — avec
    /// `lineLimit(1)` et `fixedSize()` : un mot de dix lettres sortait de la
    /// card et se faisait couper par son clip. Sans conséquence tant que les
    /// mots étaient à nous (« YOU MADE IT », « YOU'RE BACK », un nombre en
    /// lettres) ; inacceptable dès qu'ils portent un PRÉNOM.
    ///
    /// L'échelle devient continue au-delà de 8 — et **rigoureusement identique
    /// à l'ancienne en deçà**, pour qu'aucune robe existante ne bouge d'un
    /// pixel (tous nos mots font 8 caractères ou moins).
    static func echelle(_ n: Int) -> CGFloat {
        if n > 8 { return 0.88 * (8.0 / CGFloat(n)) }
        return n > 4 ? 0.88 : 1
    }

    private var rangées: some View {
        VStack(spacing: lignes.count <= 2 ? -12 : -16) {
            ForEach(0..<lignes.count, id: \.self) { i in
                Text(lignes[i])
                    .font(.inter(corps * Self.echelle(lignes[i].count), .heavy))
                    .tracking(-3)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    var body: some View {
        Color.clear
            .overlay {
                ZStack {
                    // La base — l'argent qui meurt vers le bas, et
                    // L'OMBRE CONTINUE (verdict) : chaque rangée porte
                    // son ombre sur la suivante (elles se chevauchent),
                    // le relief coule de haut en bas.
                    rangées
                        .foregroundStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.40),
                                          location: 0),
                                    .init(color: .white.opacity(0.17),
                                          location: 0.5),
                                    .init(color: .white.opacity(0.06),
                                          location: 1)
                                ],
                                startPoint: .top, endPoint: .bottom))
                        .shadow(color: .black.opacity(0.85),
                                radius: 9, y: 10)
                    // La lumière de la lampe POSÉE sur les lettres — la
                    // copie claire, masquée par le champ qui descend de
                    // la barrette.
                    // La lumière SUIT LE BALAYAGE du spot — même horloge
                    // que le cône de la lampe (les rangées, statiques, ne
                    // se redessinent pas : seul le masque glisse).
                    TimelineView(.animation(
                        minimumInterval: 1.0 / 30.0)) { tl in
                        let b = balayageSpot(
                            tl.date.timeIntervalSince(naissance))
                        rangées
                            .foregroundStyle(Color.white.opacity(0.65))
                            .mask(
                                EllipticalGradient(
                                    stops: [
                                        .init(color: .white, location: 0),
                                        .init(color: .white.opacity(0.35),
                                              location: 0.45),
                                        .init(color: .clear, location: 1)
                                    ],
                                    center: UnitPoint(x: 0.5 - 0.42 * b,
                                                      y: 0.02),
                                    startRadiusFraction: 0,
                                    endRadiusFraction: 0.85))
                    }
                    // LE SCINTILLEMENT (verdict) — des étoiles infimes
                    // qui ne vivent QUE dans les lettres, plus denses là
                    // où la lampe les touche.
                    Scintilles(naissance: naissance)
                        .mask(rangées)
                }
                // Le PIED SE NOIE avant la ligne du bas (la réf : la
                // dernière rangée à demi avalée par le noir) — jamais de
                // collision avec le sous-titre.
                // LE FONDU MAJESTUEUX (verdict) : le texte se noie dans
                // le noir vers le BAS…
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white.opacity(0.92),
                                  location: 0.42),
                            .init(color: .white.opacity(0.45),
                                  location: 0.66),
                            .init(color: .white.opacity(0.12),
                                  location: 0.82),
                            .init(color: .clear, location: 0.92)
                        ],
                        startPoint: .top, endPoint: .bottom))
                // …ET SUR LES CÔTÉS, franchement : les lettres sortent
                // de la nuit au lieu d'être coupées par le bord.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white.opacity(0.30),
                                  location: 0.12),
                            .init(color: .white, location: 0.32),
                            .init(color: .white, location: 0.68),
                            .init(color: .white.opacity(0.30),
                                  location: 0.88),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading, endPoint: .trailing))
                .offset(y: 6)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// L'éventail du plafonnier — le trapèze COURT et doux.
struct Eventail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX - 30, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + 30, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX + 118, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX - 118, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// LA LAMPE-BARRETTE (réf « You Made It ») — l'objet accroché au bord
/// haut de la card, et son éventail de lumière : court, doux, flancs
/// FONDUS (jamais d'arête franche — un trait à bord franc sur du noir
/// est de l'encre, pas de la lumière).
struct LampeEventail: View {
    /// L'horloge du balayage — la même que la lumière des lettres.
    var naissance: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            corps(balayage: balayageSpot(
                tl.date.timeIntervalSince(naissance)))
        }
    }

    private func corps(balayage: Double) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // L'éventail — dégradé qui meurt vite, flancs fondus.
                // DEUX ÉVENTAILS (verdict « améliore le spotlight ») :
                // la nappe LARGE et douce, et le CŒUR étroit plus vif —
                // la lumière a un corps et une âme. LE FAISCEAU BALAIE
                // de droite à gauche, ancré à sa source.
                Group {
                Eventail()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.33),
                                      location: 0),
                                .init(color: .white.opacity(0.10),
                                      location: 0.5),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top, endPoint: .bottom))
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.04),
                                .init(color: .white, location: 0.30),
                                .init(color: .white, location: 0.70),
                                .init(color: .clear, location: 0.96)
                            ],
                            startPoint: .leading, endPoint: .trailing))
                    .blur(radius: 13)
                    .frame(height: 196)
                    .blendMode(.screen)
                Eventail()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.50),
                                      location: 0),
                                .init(color: .white.opacity(0.15),
                                      location: 0.4),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top, endPoint: .bottom))
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.22),
                                .init(color: .white, location: 0.42),
                                .init(color: .white, location: 0.58),
                                .init(color: .clear, location: 0.78)
                            ],
                            startPoint: .leading, endPoint: .trailing))
                    .blur(radius: 9)
                    .frame(height: 148)
                    .scaleEffect(x: 0.55, y: 1, anchor: .top)
                    .blendMode(.screen)
                }
                .rotationEffect(.degrees(19 * balayage),
                                anchor: UnitPoint(x: 0.5, y: 0.03))
                // La bouche — le fin trait de lumière SOUS la barrette,
                // discret : c'est l'éventail qui parle.
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 44, height: 2)
                    .blur(radius: 2)
                    .offset(y: 9)
                // (La barrette est MORTE — verdict « enlève la petite
                // pillule » : la source est une simple ouverture de
                // lumière au bord, l'objet n'existe plus.)
            }
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// LE SCINTILLEMENT des lettres — la recette PoudreBooster réduite à
/// l'infime : ~16 étoiles qui ne vivent que masquées PAR les glyphes,
/// plus denses en crête (là où la lampe touche), l'additif au contexte.
struct Scintilles: View {
    var naissance: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            Canvas { ctx, size in
                ctx.blendMode = .plusLighter
                for i in 0 ..< 16 {
                    let x = size.width * CGFloat(Self.hash(i, 1))
                    let haut = Self.hash(i, 3)
                    let y = size.height * CGFloat(haut)
                    let tw = 0.5 + 0.5 * sin(t * (5 + 9 * Self.hash(i, 4))
                                             + Self.hash(i, 6) * 6.28)
                    // La crête scintille plus que le pied.
                    let a = (0.9 - 0.6 * haut) * tw * tw * tw * 0.9
                    guard a > 0.03 else { continue }
                    let r = CGFloat(0.5 + 0.9 * Self.hash(i, 7))
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x - r / 2, y: y - r / 2,
                                               width: r, height: r)),
                        with: .color(.white.opacity(a)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}

/// LA FORME DU GLYPHE — le contour réel du chiffre (CoreText), en
/// SF Rounded black (la rondeur de la réf), ajusté dans son rect : la
/// silhouette qui reçoit le VRAI verre.
// (interne depuis le 13-09 : la sortie de Nosfy coule son chiffre dans le même verre)
struct FormeGlyphe: Shape {
    let texte: String

    func path(in rect: CGRect) -> Path {
        // La fonte de l'APP (verdict « trop arrondie ») : Inter-Bold,
        // le même dessin que tous les chiffres de la maison.
        let police = UIFont(name: "Inter-Bold", size: 200)
            ?? UIFont.systemFont(ofSize: 200, weight: .bold)
        let ct = police as CTFont
        let compose = CGMutablePath()
        var avanceX: CGFloat = 0
        for scalaire in texte.unicodeScalars {
            var uc = UniChar(scalaire.value)
            var glyphe = CGGlyph()
            guard CTFontGetGlyphsForCharacters(ct, &uc, &glyphe, 1)
            else { continue }
            if let chemin = CTFontCreatePathForGlyph(ct, glyphe, nil) {
                let tf = CGAffineTransform(translationX: avanceX, y: 0)
                compose.addPath(chemin, transform: tf)
            }
            var avance = CGSize.zero
            CTFontGetAdvancesForGlyphs(ct, .horizontal, &glyphe,
                                       &avance, 1)
            avanceX += avance.width
        }
        let boite = compose.boundingBoxOfPath
        guard boite.width > 0, boite.height > 0 else { return Path() }
        let echelle = min(rect.width / boite.width,
                          rect.height / boite.height)
        var t = CGAffineTransform.identity
        t = t.translatedBy(x: rect.midX, y: rect.midY)
        // CoreText vit y vers le HAUT : l'échelle négative retourne.
        t = t.scaledBy(x: echelle, y: -echelle)
        t = t.translatedBy(x: -boite.midX, y: -boite.midY)
        guard let pose = compose.copy(using: &t) else { return Path() }
        return Path(pose)
    }
}

/// LE CHIFFRE DE VERRE (T2, réf « You Made It ») — le VRAI Liquid Glass
/// coulé DANS la silhouette du chiffre : le texte géant derrière est
/// réellement réfracté à travers lui. Et il se SAISIT comme la pill (la
/// recette galet : dérive discrète + gyro, drag au doigt, haptique
/// prise/lâcher, ressort au lâcher SUR LE MODIFICATEUR — la leçon).
// (interne depuis le 13-09 : la pop-up de sortie de Nosfy — « le chiffre en liquid glass,
// pas de galet » — est le second hôte de ce verre)
struct ChiffreVerre: View {
    let valeur: Int
    var naissance: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var prise = CGSize.zero
    @State private var enMain = false
    @State private var grab = 0
    @State private var drop = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            let tilt = SkyMotion.shared.tilt
            let libre: CGFloat = enMain ? 0.25 : 1
            let x = (sin(t * 0.50) * 24 + sin(t * 0.93 + 1.7) * 8) * libre
                + 18 * tilt.dx
            let y = (cos(t * 0.41 + 0.8) * 18 + sin(t * 0.77) * 6) * libre
                + 12 * tilt.dy
            verre.offset(x: x, y: y)
        }
        .offset(prise)
        .gesture(saisie)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: grab)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7),
                         trigger: drop)
        .accessibilityLabel("\(valeur)")
    }

    private var verre: some View {
        let forme = FormeGlyphe(texte: "\(valeur)")
        return Color.clear
            .frame(width: 192, height: 192)
            .glassEffect(.clear.interactive(), in: forme)
            .environment(\.colorScheme, .dark)
            // Le fil qui dessine l'arête du verre sur le noir.
            .overlay(
                forme.stroke(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.30), location: 0),
                            .init(color: .white.opacity(0.06), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom),
                    lineWidth: 1))
            .contentShape(forme)
    }

    private var saisie: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !enMain {
                    enMain = true
                    grab += 1
                }
                prise = v.translation
            }
            .onEnded { _ in
                enMain = false
                drop += 1
                withAnimation(.spring(response: 0.48,
                                      dampingFraction: 0.68)) {
                    prise = .zero
                }
            }
    }
}

/// LE CHIFFRE NÉON (réf WWDC « 1 DAY TO GO ») — MORT (la robe brume est
/// remplacée par « You Made It ») ; gardé le temps du ménage. — le tube blanc-chaud qui
/// BLOOM : trois couches du même glyphe (le souffle d'or large, le corps
/// chaud, le cœur blanc), l'allumage suit `allume` — le néon s'embrase
/// pendant le count-up au lieu d'arriver déjà allumé.
private struct ChiffreNeon: View {
    let valeur: Int
    /// L'allumage [0,1] — pilote l'intensité du bloom.
    var allume: Double

    private func glyphe() -> Text {
        Text("\(valeur)")
            .font(.inter(190, .semibold))
            .monospacedDigit()
            .tracking(-2)
    }

    var body: some View {
        ZStack {
            // LA BRUME — très large, très diluée : elle n'a plus de forme
            // de chiffre, c'est un climat. (La version « champ + tube
            // surexposé + grain » a été essayée et RECALÉE — « horrible,
            // je préférais d'avant » : cette robe-ci est la bonne.)
            glyphe()
                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.55))
                .blur(radius: 72)
                .opacity(0.38 * allume)
            // Le souffle d'or — large et doux, plus chaud vers le HAUT.
            glyphe()
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 1.0, green: 0.82,
                                               blue: 0.50), location: 0),
                            .init(color: Color(red: 1.0, green: 0.72,
                                               blue: 0.36), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
                .blur(radius: 44)
                .opacity(0.42 * allume)
            // Le corps chaud — un voile, pas un cerne.
            glyphe()
                .foregroundStyle(Color(red: 1.0, green: 0.93, blue: 0.78))
                .blur(radius: 15)
                .opacity(0.55 * allume)
            // Le cœur — BLANC (jamais beurre), la chaleur ne vit qu'au
            // pied du glyphe.
            glyphe()
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.62),
                            .init(color: Color(red: 1.0, green: 0.94,
                                               blue: 0.82), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
        }
        .compositingGroup()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .allowsHitTesting(false)
    }
}

/// LES CAPITALES COUCHÉES (le « DAY TO GO ») — l'unité à PLAT : graisse
/// lourde, encre sombre à peine allumée en crête, couchée en perspective
/// par une rotation X ancrée en bas — elle s'enfuit vers le fond de la
/// card, sous la lumière du chiffre.
private struct UnitePlate: View {
    let texte: String

    private func mot() -> Text {
        Text(texte.uppercased())
            .font(.inter(100, .heavy))
            .tracking(7)
    }

    var body: some View {
        ZStack {
            // L'épaisseur — le même mot, plus sombre, décalé : l'extrusion.
            mot()
                .foregroundStyle(Color.white.opacity(0.08))
                .offset(y: 5)
            // La face — SOMBRE (à peine plus claire que la nuit), la
            // crête seule attrape la lumière du chiffre.
            mot()
                .foregroundStyle(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.36), location: 0),
                            .init(color: .white.opacity(0.15), location: 0.45),
                            .init(color: .white.opacity(0.06), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
        }
        // LE PIED FONDU : le bas du mot se dissout dans le halo de sol —
        // le masque vit AVANT la rotation, il fond le bord PROCHE, celui
        // qui trempe dans la brume.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 0.52),
                    .init(color: .white.opacity(0.25), location: 0.85),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom))
        // L'inclinaison : 40° et une perspective modérée. (La version
        // « extrusion réelle 30°, mot géant rogné » a été essayée et
        // RECALÉE — cette robe-ci est celle qu'elle préfère.)
        .rotation3DEffect(.degrees(40), axis: (x: 1, y: 0, z: 0),
                          anchor: .bottom, perspective: 0.55)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .allowsHitTesting(false)
        .accessibilityLabel(texte)
    }
}

/// LE GALET DE VERRE — le VRAI Liquid Glass (verdict « un gros galet,
/// pas une pill »), pas une peinture : un galet `glassEffect` qui se
/// promène SUR le chiffre et le réfracte — le chiffre blanc est sa
/// nourriture — et que LE DOIGT peut saisir : il suit la main (haptique
/// à la prise), et retombe en ressort sur sa dérive au lâcher.
///
/// Les lois : taille CONSTANTE (les bounds vivants tuent le verre), tout
/// mouvement est un OFFSET (transform), le verre force son `.dark`.
/// LE RESSORT DU LÂCHER vit sur le MODIFICATEUR `.offset(prise)` — la
/// seule voie animée : lire un @State sous withAnimation dans le calcul
/// du Timeline rendrait la valeur MODÈLE (la garde morte, déjà payée) et
/// le galet CLAQUERAIT au lieu de revenir. `reduceMotion` : la dérive se
/// pose, le doigt garde la main.
/// ⚠️ `internal` depuis le 29-08 : la notification « La Châsse » le
/// réutilise TEL QUEL. Le dépôt a déjà payé la copie d'une recette
/// (`PoudreDiamant`, dupliquée dans `StorySuite` faute d'accès) et son
/// propre commentaire dit « le jour où l'arbre est calme, l'une des deux
/// meurt ». Une recette, un endroit.
struct GaletVerre: View {
    var naissance: Date
    /// Le diamètre du galet. 152 est la valeur de la card reward ; une
    /// dalle de notification en veut ~92.
    var diametre: CGFloat = 152
    /// L'échelle de la DÉRIVE. À 1 le galet promène ±46 pt en x et ±34 en
    /// y — la course d'une card portrait. Sur une dalle de 138 pt de haut
    /// il sortirait du cadre : la notification la rentre.
    var amplitude: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// L'écart posé par le doigt — vivant pendant le drag, ressort à zéro
    /// au lâcher.
    @State private var prise = CGSize.zero
    @State private var enMain = false
    /// Les battements haptiques : la prise, puis le lâcher.
    @State private var grab = 0
    @State private var drop = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            let tilt = SkyMotion.shared.tilt
            // La dérive se fait discrète sous le doigt : la main commande.
            let libre: CGFloat = enMain ? 0.25 : 1
            let a = amplitude
            let x = ((sin(t * 0.55) * 46 + sin(t * 1.07 + 1.7) * 11) * libre
                + 22 * tilt.dx) * a
            let y = ((cos(t * 0.43 + 0.8) * 34 + sin(t * 0.83) * 7) * libre
                + 15 * tilt.dy) * a
            galet
                .offset(x: x, y: y)
        }
        .offset(prise)
        .gesture(saisie)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.9),
                         trigger: grab)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7),
                         trigger: drop)
        .accessibilityHidden(true)
    }

    /// Le corps de la pastille — RONDE et un peu plus petite (verdict),
    /// verre `.clear` : le rim courbe est ce qui PLIE le mieux la lumière
    /// du chiffre. Son BORDER est du verre lui aussi : un anneau de
    /// crête épais + son écho intérieur — jamais une nappe pleine (frost).
    private var galet: some View {
        Color.clear
            .frame(width: diametre, height: diametre)
            .glassEffect(.clear.interactive(), in: Circle())
            .environment(\.colorScheme, .dark)
            // L'anneau de verre : la crête épaisse qui prend la lumière…
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.42), location: 0),
                            .init(color: .white.opacity(0.10),
                                  location: 0.55),
                            .init(color: .white.opacity(0.22), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing),
                    lineWidth: 3))
            // …et son écho intérieur, décollé d'un souffle : l'épaisseur
            // du bord se lit, c'est elle le « border liquid glass ».
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.10),
                                      lineWidth: 1)
                    .padding(4))
            .contentShape(Circle())
    }

    private var saisie: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !enMain {
                    enMain = true
                    grab += 1
                }
                prise = v.translation
            }
            .onEnded { _ in
                enMain = false
                drop += 1
                withAnimation(.spring(response: 0.48,
                                      dampingFraction: 0.68)) {
                    prise = .zero
                }
            }
    }
}

// MARK: - La vidéo du header

private final class VideoRewardUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
}

/// LE LECTEUR DU HEADER — une vidéo fond noir qui sort de la matière de
/// la card : lecture UNIQUE, muette, et STOP SUR LA DERNIÈRE FRAME
/// (`actionAtItemEnd = .pause`) — le fondu permanent, jamais une coupe.
/// Pièges payés appliqués : aspectFill déborde son cadre →
/// `clipsToBounds + masksToBounds` ; `AVPlayerLayer` ne coûte rien
/// (mesure SondeCadence du 18-08) ; ressource NUE de `Nosfy/Media`,
/// chargée par le bundle.
/// LA VIE DE LA VIDÉO GELÉE (verdict : « quand on bouge la card en
/// gyroscopique, la vidéo bouge en arrière — on a le sentiment que
/// c'est vivant — et elle revient à la fin quand ça ne bouge plus ») :
/// la feuille qui SEULE écoute le tilt (doigt + gyro) et le convertit
/// en RECUL du playhead (≤ 2,4 s).
private struct VideoVivante: View {
    let nom: String
    let relance: Int
    let pente: CGSize
    /// La vidéo tourne EN CONTINU (le welcome) au lieu de geler sur sa
    /// dernière frame (les rewards).
    var boucle: Bool = false
    /// ⚠️ Le welcome est un PORTRAIT : en `aspectFill` son bas est
    /// coupé et LA LUNE DU CUBE DISPARAÎT (verdict). Il s'affiche donc
    /// entier (`aspectFit`) — le noir autour se fond dans la card.
    var entier: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let tilt = SkyMotion.shared.tilt
        let force = reduceMotion ? 0 : min(1.0,
            (abs(Double(pente.width)) + abs(Double(pente.height))) / 130.0
            + (abs(tilt.dx) + abs(tilt.dy)) * 0.55)
        VideoReward(nom: nom, relance: relance,
                    recul: boucle ? 0 : 2.4 * force, boucle: boucle,
                    entier: entier)
    }
}

private struct VideoReward: UIViewRepresentable {
    let nom: String
    /// Le compteur de RELANCE (verdict « quand j'appuie sur une vidéo,
    /// ça la relance ») : chaque incrément rembobine et rejoue.
    var relance: Int = 0
    /// Le RECUL demandé par le tilt, en secondes en arrière de la fin.
    /// ⚠️ LA LOI DU MANÈGE (« on ne seeke JAMAIS dans une vidéo au
    /// doigt » — 4 295 img/s demandées contre 15-25 servies, mesuré et
    /// mort) : ici les seeks sont CHAÎNÉS SUR COMPLÉTION — jamais plus
    /// vite que le décodeur ne sert — cible LISSÉE par tiers, tolérances
    /// ouvertes, et rien ne bouge tant que la lecture initiale n'est pas
    /// GELÉE. Si le banc montre une saccade : le repli est la planche de
    /// sprites du manège.
    var recul: Double = 0
    /// En boucle, le lecteur repart de zéro à la fin (welcome).
    var boucle: Bool = false
    /// Vidéo entière (aspectFit) plutôt que remplie (aspectFill).
    var entier: Bool = false

    final class Coordinateur {
        var boucleArmee = false
        var derniereRelance = 0
        weak var lecteur: AVPlayer?
        var duree: Double = 0
        var finie = false
        var cible: Double = 0
        var courant: Double = 0
        var enSeek = false

        /// La lecture initiale est-elle arrivée au gel ?
        func verifierFinie() {
            guard !finie, let lecteur,
                  let item = lecteur.currentItem else { return }
            let d = item.duration.seconds
            guard d.isFinite, d > 0 else { return }
            duree = d
            if lecteur.rate == 0,
               lecteur.currentTime().seconds > d - 0.15 {
                courant = lecteur.currentTime().seconds
                cible = courant
                finie = true
            }
        }

        func viser(_ t: Double) {
            cible = t
            avancer()
        }

        private func avancer() {
            guard let lecteur, finie, !enSeek else { return }
            let pas = cible - courant
            guard abs(pas) > 0.03 else { return }
            courant += pas * 0.35
            enSeek = true
            let tol = CMTime(seconds: 0.05, preferredTimescale: 600)
            lecteur.seek(
                to: CMTime(seconds: courant, preferredTimescale: 600),
                toleranceBefore: tol, toleranceAfter: tol
            ) { [weak self] _ in
                guard let self else { return }
                self.enSeek = false
                DispatchQueue.main.async { self.avancer() }
            }
        }
    }

    func makeCoordinator() -> Coordinateur { Coordinateur() }

    func makeUIView(context: Context) -> VideoRewardUIView {
        let v = VideoRewardUIView()
        v.clipsToBounds = true
        v.layer.masksToBounds = true
        v.backgroundColor = .black
        guard let url = Bundle.main.url(forResource: nom,
                                        withExtension: "mp4")
        else { return v }
        let lecteur = AVPlayer(url: url)
        lecteur.isMuted = true
        lecteur.actionAtItemEnd = boucle ? .none : .pause
        if boucle, !context.coordinator.boucleArmee {
            context.coordinator.boucleArmee = true
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: lecteur.currentItem, queue: .main) { [weak lecteur] _ in
                    lecteur?.seek(to: .zero)
                    lecteur?.play()
                }
        }
        let couche = v.layer as! AVPlayerLayer
        couche.player = lecteur
        couche.videoGravity = entier ? .resizeAspect
                                     : .resizeAspectFill
        context.coordinator.lecteur = lecteur
        lecteur.play()
        return v
    }

    func updateUIView(_ v: VideoRewardUIView, context: Context) {
        let c = context.coordinator
        // La RELANCE (le tap) — seule un VRAI changement du compteur
        // rembobine, jamais les frames d'animation.
        if c.derniereRelance != relance,
           let lecteur = (v.layer as? AVPlayerLayer)?.player {
            c.derniereRelance = relance
            c.finie = false
            c.courant = 0
            lecteur.seek(to: .zero, toleranceBefore: .zero,
                         toleranceAfter: .zero)
            lecteur.play()
            return
        }
        // En boucle, rien à seeker : la vidéo vit d'elle-même.
        guard !boucle else { return }
        // LA VIE AU TILT — active seulement une fois la lecture gelée.
        c.verifierFinie()
        if c.finie {
            c.viser(max(0, c.duree - 0.05 - recul))
        }
    }
}

/// La feuille gyro : elle SEULE relit `SkyMotion` à 30 Hz (le contenu,
/// passé en valeur, se diffe à vide) — la page en dessous n'entend rien.
/// La nappe est une LUMIÈRE posée sur la face (l'effet, sur du noir, vient
/// d'elle) ; l'inclinaison 3D reste un murmure.
private struct CarteGyro<Contenu: View>: View {
    /// LE TILT AU DOIGT (verdict « effet gyroscopique au drag de la
    /// pop-up ») : le drag couche la card en 3D — gauche/droite surtout,
    /// un souffle en vertical — et elle revient en ressort au lâcher.
    /// Le ressort vit sur la VALEUR animée du modificateur (la leçon) ;
    /// en `simultaneousGesture` : Close, le galet et le scrim gardent
    /// leurs gestes. L'écart vit CHEZ LA SCÈNE (binding) : la vie de la
    /// vidéo gelée s'en nourrit aussi.
    @Binding var pente: CGSize
    /// La card porte un verre natif : pas de rotation 3D (voir plus bas).
    var sansTilt: Bool = false
    @ViewBuilder var contenu: () -> Contenu

    private static var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
    }

    var body: some View {
        let tilt = SkyMotion.shared.tilt
        contenu()
            .overlay {
                // La nappe gyro — DU BAS, comme toute lumière de la card
                // (verdict « halos du bas uniquement ») : elle glisse le
                // long du bord bas avec la main. Le simulateur, sans
                // gyroscope, la garde posée au centre bas.
                EllipticalGradient(
                    stops: [
                        .init(color: .white.opacity(0.10), location: 0),
                        .init(color: .white.opacity(0.03), location: 0.5),
                        .init(color: .clear, location: 1)
                    ],
                    center: UnitPoint(x: 0.5 + 0.30 * tilt.dx,
                                      y: 1.04 + 0.10 * tilt.dy),
                    startRadiusFraction: 0,
                    endRadiusFraction: 0.85)
                    .blendMode(.plusLighter)
                    .clipShape(Self.forme)
                    .allowsHitTesting(false)
            }
            // LA LUMIÈRE DU TILT (verdict « un peu de lumière discrète
            // quand il y a l'effet gyroscopique ») : une bande douce qui
            // traverse la face quand la card se couche — éteinte au
            // repos, un souffle au maximum, elle suit le côté levé.
            .overlay {
                let force = min(1.0,
                    (abs(Double(pente.width))
                     + abs(Double(pente.height))) / 130.0
                    + (abs(tilt.dx) + abs(tilt.dy)) * 0.55)
                let cx = 0.5 + max(-0.42, min(0.42,
                    Double(pente.width) * 0.0035 + tilt.dx * 0.30))
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: max(0, cx - 0.30)),
                        .init(color: .white.opacity(0.10 * force),
                              location: cx),
                        .init(color: .clear, location: min(1, cx + 0.30))
                    ],
                    startPoint: .leading, endPoint: .trailing)
                    .blendMode(.plusLighter)
                    .clipShape(Self.forme)
                    .allowsHitTesting(false)
            }
            // ⚠️ LE TILT EST COUPÉ quand la card porte un VERRE NATIF
            // (le bouton claim) : sous un `rotation3DEffect`, le verre
            // GROSSIT et se détache (bug vu et revu). Le correctif
            // `compositingGroup` répare le verre mais tue sa
            // réfraction : les deux sont incompatibles. Sur ces
            // cards-là, le verre gagne — le gyro doux suffit.
            .rotation3DEffect(
                .degrees(sansTilt ? 0
                         : 2.6 * tilt.dx
                         + max(-11, min(11, pente.width * 0.085))),
                axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(
                .degrees(sansTilt ? 0
                         : -2.2 * tilt.dy
                         - max(-7, min(7, pente.height * 0.055))),
                axis: (x: 1, y: 0, z: 0))
            .simultaneousGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in pente = v.translation }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.42,
                                              dampingFraction: 0.62)) {
                            pente = .zero
                        }
                    })
    }
}
