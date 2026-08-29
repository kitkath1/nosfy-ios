import SwiftUI
import AVFoundation

// MARK: - LES NOTIFICATIONS — la dalle noire qui remplace le toaster de verre

/// LE BANC (`-notifLab`) — les prises, lues UNE fois au lancement.
///
/// Elles vivent hors de `NotifLab` pour la même raison que `RewardBanc` vit
/// hors de `RewardLab` : une horloge figée qu'on threade en paramètre finit
/// toujours par manquer à un endroit, et c'est là que la capture ment.
enum NotifBanc {
    /// Le banc est-il en scène ? (L'app ne voit jamais ce drapeau.)
    static let actif = CommandLine.arguments.contains("-notifLab")

    /// `-notifNu` — le bandeau de commandes disparaît (captures propres).
    static let nu = CommandLine.arguments.contains("-notifNu")

    /// `-notifFige` — les cards naissent DÉJÀ POSÉES : pas de descente, pas
    /// de count-up, pas de remplissage, pas de lettres qui arrivent. Une
    /// capture de réglage se fait sur une image immobile, pas au milieu
    /// d'une rampe.
    static let fige = CommandLine.arguments.contains("-notifFige")

    /// `-notifT <s>` — l'horloge des VIES clouée : le balayage du
    /// projecteur, les grains de la jauge, le tour de pièce. Deux tours de
    /// fouettage ne se comparent JAMAIS s'ils ne sont pas au même instant
    /// du balayage (période ~9,7 s).
    static let tFige: Double? = number(after: "-notifT")

    /// `-fps` — la sonde de cadence (le drapeau maison, partagé avec la
    /// home). Elle ne dessine rien : elle publie une ligne par seconde,
    /// lue par `simctl launch --console-pty` (jamais `log stream`).
    static let fps = CommandLine.arguments.contains("-fps")

    /// `-notifSeule <1|2>` — une seule card à l'écran. C'est le régime
    /// VRAI : dans l'app une notification vit seule. Le banc entier est le
    /// pire cas, celui du réglage.
    static let seule: Int = {
        guard let v = number(after: "-notifSeule") else { return 0 }
        return Int(v)
    }()

    /// L'horloge d'un effet : figée sous `-notifT`, vivante sinon.
    static func horloge(_ t: Double) -> Double { tFige ?? t }

    static func number(after flag: String) -> Double? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: flag), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return v
    }

    /// LE BRUIT DÉTERMINISTE de la maison — la grammaire de `Scintilles` et
    /// de la poudre de la card reward.
    ///
    /// ⚠️ **Aucun tirage au hasard, nulle part.** Une particule tirée au
    /// `random` rend deux captures du même réglage incomparables : on ne
    /// saurait plus si un changement vient du code ou du dé.
    static func hash(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}

// MARK: - LA FORME

/// LA DALLE, ses cotes — relevées sur la capture OPAL de Kathryn
/// (iPhone 16 Pro, 402×874 pt). Elles sont ICI et nulle part ailleurs :
/// le calage de la forme est UN tour de boucle visuelle, pas une chasse
/// aux constantes dispersées dans deux variants.
enum NotifGeo {
    static let hauteur: CGFloat = 138
    static let rayon: CGFloat = 28
    /// La marge latérale de la dalle contre le bord de l'écran.
    static let margeH: CGFloat = 23
    /// Le padding interne du contenu.
    static let pad: CGFloat = 20

    static var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: rayon, style: .continuous)
    }
}

/// LA ROBE DU SOCLE — la dalle noire, son liseré, son ombre.
///
/// ⚠️ **DU NOIR PEINT, PAS DU VERRE**, et trois lois du dépôt convergent :
/// `glassEffect(.regular)` est interdit (le givré laiteux) ; `.clear` givre
/// le contenu NET, or ici tout est du texte ; et un verre aux bounds vivants
/// devient un blur plat définitif — or cette card descend et remonte. C'est
/// aussi ce que montre la réf OPAL : du noir, pas du verre.
///
/// ⚠️ C'est un `ViewModifier` et pas un conteneur générique : `body(content:)`
/// reçoit l'arbre DÉJÀ construit — le relire soixante fois ne reconstruit
/// rien (loi n°6), et aucune closure ne se retrouve en propriété de vue.
///
/// ⚠️⚠️ **ET C'EST LUI QUI COUPE.** Le `clipShape` de la dalle est ce qui
/// rogne le texte géant du variant B : le rognage n'est pas un effet de
/// bord, c'est le prérequis (verdict du 28-08).
struct RobeSocle: ViewModifier {
    /// LE LISERÉ « COMME CETTE CARD » (verdict du 28-08, sur la réf de la
    /// card reward) : 0,07 → 0,02 ne se voyait pas. La lumière vient d'en
    /// haut, le bord doit le DIRE — 0,16 en haut, presque rien en bas. Il
    /// reste à 1 pt : au-delà ce n'est plus un liseré, c'est un cadre.
    /// ⚠️ Il vaut pour les DEUX dalles : deux cards qui ne portent pas le
    /// même bord ne sont plus une famille.
    private static let liseré = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.16), location: 0),
            .init(color: .white.opacity(0.06), location: 0.35),
            .init(color: .white.opacity(0.03), location: 1)
        ],
        startPoint: .top, endPoint: .bottom)

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity,
                   minHeight: NotifGeo.hauteur,
                   maxHeight: NotifGeo.hauteur)
            .background(Color.black)
            .clipShape(NotifGeo.forme)
            .overlay {
                NotifGeo.forme.strokeBorder(Self.liseré, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.55), radius: 22, y: 10)
            .padding(.horizontal, NotifGeo.margeH)
    }
}

// MARK: - VARIANT A « LA JAUGE »

/// LE GAIN DE PIÈCES — le gain en tête, la jauge à particules, et la pièce
/// qui TOURNE en mordant le bord droit.
///
/// ⚠️ **LE TITRE A SAUTÉ** (verdict du 28-08). « SET COMPLETE » était un
/// label d'état : la card mène maintenant avec ce qu'elle rapporte, et le
/// reste est du décor administratif.
///
/// Elle hérite du contrat de `PillGain` (`RestartSheet.swift`) : elle
/// n'interrompt rien. Ce qui change, c'est la robe.
struct NotifJauge: View {
    /// ⚠️ **EN CAPITALES** (verdict du 29-08, demandé DEUX fois : je ne
    /// l'avais appliqué qu'au variant 3). Le tracking positif n'est pas un
    /// ornement : des capitales serrées font un mur.
    var sousTitre: String = "VAULT PROGRESS"
    var libelle: String = "COINS EARNED"
    var gain: Int = 20
    /// Où en est le coffre APRÈS ce gain [0,1].
    var fraction: Double = 0.62
    /// L'entrée est POSÉE : la barre se remplit, le chiffre monte.
    var pose: Bool
    /// L'horloge des grains et du tour de pièce.
    var naissance: Date

    /// La largeur réservée à la pièce — le texte et la barre s'arrêtent
    /// avant elle (la réf OPAL : la jauge fait les deux tiers de la dalle).
    private static let reservePiece: CGFloat = 86
    /// Le diamètre VISIBLE de la pièce (la case de planche vaut ×1,18).
    private static let diametrePiece: CGFloat = 92
    /// Ce que la pièce passe SOUS le bord droit — le clip de la dalle la
    /// rogne sur le coin arrondi. C'est ça, « elle touche ».
    private static let morsure: CGFloat = 16
    /// LE TOUR DE LA GROSSE PIÈCE — LENT. C'est une ambiance, pas un
    /// numéro : à la période du variant B (5,5 s) une pièce de 92 pt
    /// devient le sujet de la card et mange le gain.
    private static let periodePiece: Double = 9

    var body: some View {
        colonne
            .padding(NotifGeo.pad)
            .padding(.trailing, Self.reservePiece)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .topLeading)
            .overlay(alignment: .trailing) { piece }
            .modifier(RobeSocle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Plus \(gain) coins earned. \(sousTitre).")
    }

    // ── L'ENCRE

    private var colonne: some View {
        VStack(alignment: .leading, spacing: 0) {
            ligneGain
            Text(sousTitre)
                .font(.inter(11.5, .semibold))
                .tracking(1.4)
                .foregroundStyle(Color.inkSecondary)
                .padding(.top, 5)
            Spacer(minLength: 8)
            BarreParticules(fraction: pose ? fraction : 0,
                            naissance: naissance)
        }
    }

    /// « +20 coins earned » — LE TITRE de la card, et le chiffre MONTE
    /// pendant l'entrée.
    private var ligneGain: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            ChiffreQuiMonte(valeur: pose ? Double(gain) : 0)
            Text(libelle)
                .font(.inter(14, .semibold))
                .tracking(0.8)
                .foregroundStyle(Color.inkSecondary)
        }
    }

    // ── LA PIÈCE QUI TOUCHE, ET QUI TOURNE

    private var piece: some View {
        PieceQuiTourne(diametre: Self.diametrePiece,
                       periode: Self.periodePiece,
                       naissance: naissance)
            .background {
                RadialGradient(
                    colors: [Color(red: 1.00, green: 0.74, blue: 0.34)
                        .opacity(0.13), .clear],
                    center: .center, startRadius: 2,
                    endRadius: Self.diametrePiece * 0.68)
            }
            .shadow(color: .black.opacity(0.65), radius: 12, y: 7)
            .offset(x: Self.morsure)
            .allowsHitTesting(false)
    }
}

// MARK: - La jauge à particules

/// LA JAUGE — un trait de 4 pt, un dégradé blanc froid → blanc pur, et des
/// GRAINS DE LUMIÈRE qui dérivent dans le remplissage puis s'éteignent au
/// front (verdict du 28-08 : « un effet lumineux magnifique, imprégné avec
/// des particules qui remplissent la progress bar »).
///
/// ⚠️ **UN `Canvas`, PAS N CALQUES.** Ce qui se redessine par image est UN
/// dessin (loi n°4) : vingt-six petites vues animées, c'est vingt-six
/// invalidations par image. Et le `Canvas` est minuscule ici — la loi
/// « un Canvas plein écran rasterise toute sa surface même vide » ne mord
/// pas sur une bande de 240 × 18 pt.
///
/// ⚠️⚠️ **UN `Canvas` N'EST PAS ANIMABLE.** Sans `Animatable` sur sa valeur
/// pilote, le remplissage CLAQUE d'un coup au lieu de monter. Il n'y a
/// qu'un pilote ici (la fraction), donc pas besoin d'`AnimatablePair`.
///
/// ⚠️⚠️⚠️ **LES GRAINS SONT DÉTERMINISTES**, par hash — jamais un tirage au
/// hasard : deux captures du même réglage doivent être comparables.
struct BarreParticules: View, Animatable {
    var fraction: Double
    let naissance: Date

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    /// LE TRAIT — 7 → 4 → **3 pt** (verdicts des 28 et 29-08). À 3 pt il
    /// n'est plus un objet, il est une ligne de lumière : c'est le gain qui
    /// doit peser, pas la jauge.
    static let trait: CGFloat = 3
    /// La bande de DESSIN. Le halo du front a le droit d'y respirer ; les
    /// grains, non (voir `grainsDeLumiere`).
    static let bande: CGFloat = 18

    /// 26 → 40 grains, et plus FINS. Dans un trait de 3 pt un gros point
    /// bouche la jauge ; un flux dense la fait respirer.
    private static let grains = 40

    var body: some View {
        let f = min(max(fraction, 0), 1)
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = NotifBanc.horloge(tl.date.timeIntervalSince(naissance))
            Canvas { ctx, size in
                var c = ctx
                Self.dessiner(&c, size, f, t)
            }
        }
        .frame(height: Self.bande)
        .allowsHitTesting(false)
    }

    // ── LE DESSIN

    private static func dessiner(_ ctx: inout GraphicsContext,
                                 _ size: CGSize,
                                 _ f: Double, _ t: Double) {
        let y = size.height / 2
        piste(&ctx, size, y)
        let w = size.width * f
        guard w > 0.5 else { return }
        remplissage(&ctx, size, y, w)
        // ⚠️ LES GRAINS SONT CLIPPÉS, PAS RÉGLÉS. Baisser leur amplitude
        // avait déjà été essayé (±5,8 → ±4 pt) et ça n'a PAS suffi : sur
        // la capture du 28-08 des grains vivaient encore hors du trait.
        // Un réglage, un grain un peu gros ou un peu rapide revient le
        // violer. Le chemin du remplissage posé en clip est une GARANTIE :
        // à partir d'ici aucune particule ne PEUT sortir — ni au-dessus,
        // ni au-dessous, ni au-delà du front.
        var dedans = ctx
        dedans.clip(to: Path(roundedRect: CGRect(x: 0, y: y - trait / 2,
                                                 width: w, height: trait),
                             cornerRadius: trait / 2))
        grainsDeLumiere(&dedans, size, y, f, t)
        // Le halo et la tête, EUX, ont le droit de déborder : c'est de la
        // lumière, pas de la matière. Ils se dessinent hors du clip.
        lueurDuFront(&ctx, y, w)
        tete(&ctx, y, w)
    }

    private static func piste(_ ctx: inout GraphicsContext,
                              _ size: CGSize, _ y: CGFloat) {
        let r = CGRect(x: 0, y: y - trait / 2, width: size.width,
                       height: trait)
        ctx.fill(Path(roundedRect: r, cornerRadius: trait / 2),
                 with: .color(.white.opacity(0.07)))
    }

    private static func remplissage(_ ctx: inout GraphicsContext,
                                    _ size: CGSize, _ y: CGFloat,
                                    _ w: CGFloat) {
        let r = CGRect(x: 0, y: y - trait / 2, width: w, height: trait)
        ctx.fill(
            Path(roundedRect: r, cornerRadius: trait / 2),
            with: .linearGradient(
                Gradient(stops: [
                    .init(color: .white.opacity(0.32), location: 0),
                    .init(color: .white.opacity(0.66), location: 0.55),
                    .init(color: .white, location: 1)
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: 0)))
    }

    /// LE HALO DU FRONT — la lumière que le remplissage pousse devant lui.
    /// Un dégradé radial, PAS un `blur` : le flou pose un voile uniforme
    /// sur tout le rectangle de son hôte, et il coûte 27 img/s.
    private static func lueurDuFront(_ ctx: inout GraphicsContext,
                                     _ y: CGFloat, _ w: CGFloat) {
        // 0,30 / 26 pt au premier jet : le halo lisait comme un MORCEAU DE
        // BARRE EN PLUS, blanc et carré, posé après le front — il mentait
        // sur le gain. Un halo se devine, il ne se compte pas.
        let r: CGFloat = 15
        let box = CGRect(x: w - r, y: y - r, width: r * 2, height: r * 2)
        ctx.fill(
            Path(ellipseIn: box),
            with: .radialGradient(
                Gradient(colors: [Color.white.opacity(0.17),
                                  Color.white.opacity(0)]),
                center: CGPoint(x: w, y: y),
                startRadius: 0, endRadius: r))
    }

    /// LES GRAINS — ils dérivent vers la droite, respirent, et **ne vivent
    /// que SOUS le front** : une particule au-delà de la fraction serait
    /// de la lumière qui ment sur le gain.
    private static func grainsDeLumiere(_ ctx: inout GraphicsContext,
                                        _ size: CGSize, _ y: CGFloat,
                                        _ f: Double, _ t: Double) {
        for i in 0..<grains {
            let depart = NotifBanc.hash(i, 1)
            let vitesse = 0.045 + NotifBanc.hash(i, 2) * 0.085
            let x = (depart + t * vitesse)
                .truncatingRemainder(dividingBy: 1)
            guard x < f else { continue }
            let phase = t * (0.8 + NotifBanc.hash(i, 3) * 1.4)
                + NotifBanc.hash(i, 4) * 6.283
            // L'oscillation reste large : c'est le CLIP qui contient les
            // grains, et un mouvement bridé au ras du trait donnerait une
            // file d'attente, pas un flux. Ils montent, ils butent, ils
            // disparaissent — comme des bulles sous une vitre.
            let dy = sin(phase) * (trait * 0.75 + 1.2)
            // ⚠️ **DES GRAINS, PAS DES POIS** (verdict du 29-08 : « les
            // particules sont beaucoup trop grosses »). 0,35-0,90 faisait
            // jusqu'à 1,8 pt de diamètre dans un trait de 3 : la moitié de
            // la hauteur de la jauge pour UN point. Ramené à 0,22-0,62.
            let rayon = 0.22 + NotifBanc.hash(i, 5) * 0.40
            // Le fondu au front : un grain ne se coupe pas net sur la
            // bordure du remplissage, il s'y éteint.
            let bord = min(1.0, (f - x) / 0.07)
            // LA PIQÛRE CUBÉE — la loi de la poudre de diamant : un grain
            // CLIGNOTE, il ne luit pas. Sans le cube on obtient des points
            // allumés en permanence, c'est-à-dire de la saleté.
            let tw = 0.5 + 0.5 * sin(phase * (4.0 + 7.0 * NotifBanc.hash(i, 7)))
            let vie = 0.18 + 0.82 * tw * tw * tw
            let a = bord * vie * 0.95
            guard a > 0.02 else { continue }
            let cx = x * size.width
            let box = CGRect(x: cx - rayon, y: y + dy - rayon,
                             width: rayon * 2, height: rayon * 2)
            ctx.fill(Path(ellipseIn: box),
                     with: .color(.white.opacity(a)))
        }
    }

    private static func tete(_ ctx: inout GraphicsContext,
                             _ y: CGFloat, _ w: CGFloat) {
        let r: CGFloat = 2.6
        let box = CGRect(x: w - r, y: y - r, width: r * 2, height: r * 2)
        ctx.fill(Path(ellipseIn: box), with: .color(.white))
    }
}

/// LE CHIFFRE QUI MONTE — `Animatable` sur sa valeur, et SEUL à se
/// redessiner : un count-up lu dans le corps de la card ferait re-évaluer
/// la card entière soixante fois par seconde (loi n°2).
struct ChiffreQuiMonte: View, Animatable {
    var valeur: Double
    var corps: CGFloat = 24

    var animatableData: Double {
        get { valeur }
        set { valeur = newValue }
    }

    var body: some View {
        Text("+\(Int(valeur.rounded()))")
            .font(.inter(corps, .heavy).monospacedDigit())
            .foregroundStyle(Color.inkPrimary)
    }
}

// MARK: - VARIANT B « LE GROS TEXTE »

/// YOU / WIN — deux lignes géantes COUPÉES par la dalle, presque noyées
/// dans le noir, que SEUL le projecteur du haut révèle, et LA pièce qui
/// tourne au CENTRE.
///
/// Les quatre verdicts du 28-08 qui font cette card, et rien d'autre :
/// 1. **Le rognage est un prérequis** — « cropper un peu du U et de WIN ».
///    D'où DEUX lignes : sur une ligne unique on ne peut couper que les
///    lettres des extrémités, jamais le U de YOU.
/// 2. **Beaucoup plus fondu** — la base tombe à 0,12 : sans la lampe on ne
///    lit presque rien. C'est la lumière qui écrit le mot, plus l'encre.
/// 3. **Le spot part de la partie HAUTE**, il est ÉPAIS, et son champ est
///    ÉTROIT — « parfois une partie du mot est complètement dans le noir ».
///    Un champ qui couvre tout ne fait jamais d'ombre.
/// 4. **Les lettres arrivent une par une.**
struct NotifGrosTexte: View {
    var lignes: [String] = ["YOU WIN"]
    var gain: Int = 20
    /// L'entrée est POSÉE.
    var pose: Bool
    /// L'horloge du projecteur et du tour de pièce — posée UNE fois par
    /// l'hôte.
    var naissance: Date

    /// LA PIÈCE EST AU CENTRE (verdict, dit deux fois : « elle ne tourne
    /// pas sur le N, elle est au centre de la notification »). C'est
    /// l'objet héros — le rôle du « 4 » de verre de la réf.
    private static let diametrePiece: CGFloat = 54

    /// LE PROGRÈS DES LETTRES — il a SA propre horloge, plus lente que la
    /// descente de la dalle : six lettres qui s'allument l'une après
    /// l'autre demandent une seconde, la dalle en veut six dixièmes. Une
    /// seule rampe pour les deux et l'escalier des lettres se tasse en un
    /// fondu de bloc.
    @State private var progres: Double = 0

    var body: some View {
        ZStack {
            MotGeant(p: progres, lignes: lignes, naissance: naissance)
            halo
            voileBas
            blocPiece
            ligneGain
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(RobeSocle())
        .onAppear(perform: caler)
        .onChange(of: pose) { _, _ in caler() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lignes.joined(separator: " ")). "
                            + "Plus \(gain) coins.")
    }

    /// ⚠️ **UN SEUL `withAnimation`, ET IL PILOTE UN SEUL PROGRÈS.** Deux
    /// `withAnimation` au même tour ne font RIEN (loi payée) : l'escalier
    /// des six lettres vit dans la rampe de `progres`, pas dans six
    /// animations concurrentes.
    private func caler() {
        guard !NotifBanc.fige else {
            progres = pose ? 1 : 0
            return
        }
        withAnimation(.easeOut(duration: 1.0)) {
            progres = pose ? 1 : 0
        }
    }

    // ── LA LUMIÈRE

    /// LE HALO DU HAUT — « plus blur stp !! » (verdict du 28-08).
    ///
    /// ⚠️ **L'`Eventail` A DES FLANCS.** Le trapèze du premier jet, même
    /// fondu vers le bas, garde deux DROITES sur les côtés — et une droite
    /// sur du noir se lit comme de l'encre, pas comme de la lumière. Il est
    /// remplacé par un radial très large, sans arête d'aucune sorte.
    ///
    /// ⚠️⚠️ **AUCUN `.blur`.** La loi est sans appel : `.blur` pose un voile
    /// UNIFORME sur tout le rectangle de son hôte (ce n'est pas un flou
    /// local) et il coûte **27 img/s par objet** — mesuré dans ce dépôt. Le
    /// « flou » se fabrique aux dégradés à arrêts multiples.
    ///
    /// Il penche du MÊME côté que le champ posé sur les lettres
    /// (coefficient 0,40, cf. `MotGeant.champ`) : une seule lampe dans la
    /// card, jamais deux lumières qui se contredisent.
    private var halo: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let b = balayageSpot(
                NotifBanc.horloge(tl.date.timeIntervalSince(naissance)))
            GeometryReader { g in
                RadialGradient(
                    stops: [
                        .init(color: .white.opacity(0.20), location: 0),
                        .init(color: .white.opacity(0.085), location: 0.27),
                        .init(color: .white.opacity(0.028), location: 0.56),
                        .init(color: .white.opacity(0.006), location: 0.80),
                        .init(color: .clear, location: 1)
                    ],
                    center: .center, startRadius: 0, endRadius: 190)
                .frame(width: 380, height: 380)
                .position(x: g.size.width * (0.5 - 0.40 * b), y: 4)
                .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
    }

    /// LE PIED SE NOIE — le géant s'éteint vers le bas pour que le « +20 »
    /// se lise sur du noir, jamais sur une jambe de lettre.
    private var voileBas: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.48),
                .init(color: .black.opacity(0.55), location: 0.76),
                .init(color: .black.opacity(0.90), location: 1)
            ],
            startPoint: .top, endPoint: .bottom)
        .allowsHitTesting(false)
    }

    // ── LA PIÈCE, AU CENTRE

    /// Deux couches, et l'ordre EST le sujet : un objet posé nu sur une
    /// lettre ne lit pas (mesuré au J1) — un objet sans SOL n'est pas
    /// devant, il est collé. La pièce se creuse donc sa place dans le mot
    /// avant de s'y poser.
    private var blocPiece: some View {
        ZStack {
            creuxSombre
            PieceQuiTourne(diametre: Self.diametrePiece,
                           naissance: naissance)
        }
    }

    private var creuxSombre: some View {
        RadialGradient(
            stops: [
                .init(color: .black.opacity(0.90), location: 0),
                .init(color: .black.opacity(0.66), location: 0.45),
                .init(color: .clear, location: 1)
            ],
            center: .center, startRadius: 0, endRadius: 62)
        .frame(width: 124, height: 124)
        .allowsHitTesting(false)
    }

    private var ligneGain: some View {
        HStack(spacing: 6) {
            Text("+\(gain)")
                .font(.inter(13, .heavy).monospacedDigit())
                .foregroundStyle(Color.inkPrimary)
            Text("COINS")
                .font(.inter(12, .semibold))
                .tracking(1.6)
                .foregroundStyle(Color.inkSecondary)
        }
        .opacity(pose ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .bottomLeading)
        .padding(.leading, NotifGeo.pad)
        .padding(.bottom, 15)
    }
}

// MARK: - Le mot géant

/// UNE LETTRE DU MOT — descendue DANS LA DONNÉE avec son rang global.
///
/// ⚠️ Le rang ne se calcule pas dans la boucle : `ForEach(Array(x
/// .enumerated()), id: \.offset)` remplace l'identité de la donnée par une
/// clé de position — la loi payée du dépôt. Le rang descend dans la donnée,
/// la boucle reste `ForEach(lettres)` nue.
struct LettreGeante: Identifiable, Equatable {
    let id: Int
    let ch: String
}

/// LE MOT GÉANT — deux lignes qui DÉBORDENT la dalle, et dont chaque lettre
/// arrive individuellement.
///
/// ⚠️ **`Animatable` SUR SON PROGRÈS, ET IL VIT ICI.** Deux raisons payées :
/// des rampes échelonnées posées sous un `withAnimation` nu ne jouent qu'au
/// doigt (loi de `RewardCard`) ; et si `p` vivait sur la card, la card
/// ENTIÈRE se ré-évaluerait soixante fois par seconde pendant l'entrée
/// (loi n°2).
///
/// ⚠️ **Le corps est choisi POUR déborder** — 104 pt, deux lignes : le mot
/// sort de la dalle en largeur ET en hauteur, et c'est le `clipShape` du
/// socle qui coupe. **Jamais rétréci** : une police réduite pour « tenir »
/// tue l'effet.
struct MotGeant: View, Animatable {
    var p: Double
    /// ⚠️ **UNE SEULE LIGNE, ET C'EST LA GÉOMÉTRIE QUI TRANCHE.** Le premier
    /// jet V2 mettait « YOU » et « WIN » sur deux lignes, en croyant copier
    /// la réf. **Mesuré : le rognage ÉCHOUAIT** — de 257 à 350 pt la dalle
    /// était à 0-6/255, le mot s'arrêtait cent points avant le bord. Trois
    /// lettres à un corps qui tient DEUX lignes dans 138 pt ne peuvent pas
    /// déborder 356 pt de large ; la réf de Kathryn est un cadre presque
    /// carré (1,2:1), cette dalle fait 2,6:1. Le rognage étant le prérequis,
    /// c'est la mise en page qui cède : une ligne, plus grosse.
    var lignes: [String] = ["YOU WIN"]
    let naissance: Date
    /// Le corps est choisi POUR déborder : ~4,76 pt de largeur par point de
    /// corps (relevé au J1), soit ~495 pt à 104 — la dalle en montre 356,
    /// et coupe le Y à gauche, le N à droite.
    var corps: CGFloat = 104
    /// LE RAYON DU CHAMP DU PROJECTEUR — **étroit devant le mot**, et c'est
    /// LA condition du verdict « parfois une partie du mot est complètement
    /// dans le noir » : un champ qui couvre tout n'a jamais d'ombre.
    static let rayonSpot: CGFloat = 152
    /// Le foyer est HAUT (verdict : « le spotlight part de la partie
    /// haute »), juste sous le bord supérieur de la dalle.
    static let foyerSpot: CGFloat = 14

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    /// L'écart entre deux lettres qui s'allument.
    private static let retard: Double = 0.055
    /// La durée d'allumage d'UNE lettre.
    private static let duree: Double = 0.34

    // ── LA DÉCOUPE

    private func lettres(_ i: Int) -> [LettreGeante] {
        var out: [LettreGeante] = []
        var rang = 0
        for (j, mot) in lignes.enumerated() {
            for ch in mot {
                if j == i { out.append(LettreGeante(id: rang,
                                                    ch: String(ch))) }
                rang += 1
            }
        }
        return out
    }

    /// LA RAMPE LOCALE d'une lettre — un seul progrès `p` pilote tout le
    /// mot, chaque lettre n'en lit que sa fenêtre.
    private func avancement(_ rang: Int) -> Double {
        let d = Double(rang) * Self.retard
        return min(max((p - d) / Self.duree, 0), 1)
    }

    private func lettre(_ l: LettreGeante) -> some View {
        let a = avancement(l.id)
        return Text(l.ch)
            .font(.inter(corps, .heavy))
            .lineLimit(1)
            .fixedSize()
            .opacity(a)
            .offset(y: (1 - a) * 14)
    }

    private func rangée(_ i: Int) -> some View {
        HStack(spacing: -corps * 0.055) {
            ForEach(lettres(i)) { l in lettre(l) }
        }
    }

    private var rangées: some View {
        VStack(alignment: .leading, spacing: -corps * 0.30) {
            ForEach(0..<lignes.count, id: \.self) { i in rangée(i) }
        }
        .fixedSize()
    }

    // ── LES DEUX COPIES

    /// LA BASE — le relief dans le noir. 0,34 → 0,12 → **0,10**, et son
    /// dégradé se CREUSE (verdicts des 28 et 29-08 : « beaucoup plus
    /// fondu », « plus fondu premium »). Ce qui fait le premium de sa réf
    /// n'est pas un gris uniforme : c'est une matière qui MEURT vers le
    /// bas. L'ombre portée continue reste — le relief coule de haut en bas.
    private var base: some View {
        rangées
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.10), location: 0),
                        .init(color: .white.opacity(0.038), location: 0.52),
                        .init(color: .white.opacity(0.012), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.9), radius: 10, y: 9)
    }

    /// LA LUMIÈRE POSÉE SUR LES LETTRES — la copie claire, masquée par le
    /// champ du projecteur. Les rangées, statiques, ne se redessinent pas :
    /// seul le masque glisse.
    ///
    /// ⚠️⚠️ **LE MASQUE VIT DANS LE REPÈRE DE LA DALLE, PAS DANS CELUI DU
    /// MOT.** Premier jet V2 : le masque était posé sur `rangées`, dont le
    /// cadre DÉBORDE la card de cent points de chaque côté — le cône
    /// éclairait donc à côté de ce qu'on voit. Mesuré : aucune zone claire
    /// sur les lettres, elles plafonnaient à 60-78/255 partout. D'où la
    /// couche : `Color.clear` prend la taille de la dalle, le mot est son
    /// overlay (hors layout, coupé par le socle), et c'est CETTE couche
    /// qu'on masque.
    ///
    /// ⚠️ Et le champ est un **radial en POINTS**, pas un `EllipticalGradient`
    /// : ce dernier prend l'aspect de son cadre — sur une dalle 2,6:1 il
    /// donne une lentille écrasée qui ne descend jamais. Un cône vient
    /// d'en haut, il est rond.
    /// Le champ du projecteur — élargi (152 → 170) et sa rampe allongée à
    /// quatre arrêts (verdict « plus blur »). ⚠️ Sans perdre les zones
    /// noires, qui sont un ACQUIS MESURÉ (pic 214 sur « OU », creux 8-30
    /// sur « WIN », rapport 7×) : un halo plus doux qui éclairerait tout
    /// le mot serait une régression, et la sonde doit rester ≥ 5×.
    private func champ(_ b: Double) -> some View {
        GeometryReader { g in
            RadialGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white.opacity(0.62), location: 0.34),
                    .init(color: .white.opacity(0.26), location: 0.62),
                    .init(color: .clear, location: 1)
                ],
                center: .center,
                startRadius: 0, endRadius: Self.rayonSpot)
            .frame(width: Self.rayonSpot * 2, height: Self.rayonSpot * 2)
            .position(x: g.size.width * (0.5 - 0.40 * b),
                      y: Self.foyerSpot)
        }
    }

    private var coucheBase: some View {
        Color.clear.overlay { base.offset(y: Self.assiette) }
    }

    /// LE GLYPHE — le mot en blanc plein, qui sert de POCHOIR à la matrice.
    /// Il porte les mêmes opacités par lettre que la base : une lettre pas
    /// encore arrivée n'ouvre aucune fenêtre.
    private var coucheGlyphe: some View {
        Color.clear.overlay {
            rangées
                .foregroundStyle(Color.white)
                .offset(y: Self.assiette)
        }
    }

    /// ⚠️⚠️ **LA MATRICE N'EXISTE QUE DANS LE MOT** — la grammaire exacte
    /// de la robe `.spotlight` de la card reward, reprise à la lettre. Les
    /// lettres cessent d'être peintes : elles deviennent une FENÊTRE sur
    /// `fond-matrice-loop.mp4`, et c'est la colonne de lumière du film qui
    /// les allume en passant.
    ///
    /// Le pochoir n'est pas le glyphe nu : c'est le glyphe **multiplié par
    /// le champ du projecteur**, avec un PLANCHER. Le plancher (0,14) laisse
    /// deviner la trame partout dans le mot — sans lui les lettres hors
    /// lampe seraient du vide, pas de la matière. Le champ, lui, tient le
    /// verdict « parfois une partie du mot est complètement dans le noir ».
    private var matriceDansLeMot: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let b = balayageSpot(
                NotifBanc.horloge(tl.date.timeIntervalSince(naissance)))
            ZStack {
                eclat(b)
                VideoMatrice()
                    .mask {
                        ZStack {
                            Color.white.opacity(Self.plancherTrame)
                            champ(b)
                        }
                        .mask { coucheGlyphe }
                    }
                    .blendMode(.screen)
            }
        }
    }

    /// L'ÉCLAT — la copie claire des lettres, SOUS la matrice.
    ///
    /// ⚠️ **MESURÉ, PAS SUPPOSÉ.** Le premier jet V3 retirait cette couche
    /// en pariant que la vidéo suffirait à allumer le mot. La sonde a dit
    /// non : les lettres sont tombées de **214 à 111** de pic (le 226 de la
    /// capture était la PIÈCE, pas le texte). La trame est une texture
    /// sombre — elle donne le grain, elle ne donne pas la lumière.
    ///
    /// Elle vit DESSOUS, et la matrice passe en `.screen` par-dessus : sur
    /// une lettre allumée à 0,50, un caractère clair de la trame monte à
    /// ~0,95 et un creux reste à ~0,57. La texture survit à la lumière au
    /// lieu d'être lavée par elle.
    private func eclat(_ b: Double) -> some View {
        Color.clear
            .overlay {
                rangées
                    .foregroundStyle(Color.white.opacity(0.50))
                    .offset(y: Self.assiette)
            }
            .mask { champ(b) }
    }

    /// LES DEUX FONDUS CROISÉS — « dégradés et fondus sur les côtés de la
    /// notification, et top » (verdict du 29-08).
    ///
    /// ⚠️ **C'EST UN RENVERSEMENT ASSUMÉ.** Le J1 coupait NET, sur sa
    /// consigne « en coupé ». Les deux tiennent ensemble : le mot déborde
    /// toujours la dalle (on n'en voit jamais la totalité — le rognage est
    /// intact), mais ses bords se NOIENT dans le noir au lieu d'être
    /// tranchés par une arête.
    ///
    /// ⚠️ Conséquence sur la mesure : « l'encre touche le bord » ne veut
    /// plus rien dire, puisque le bord est justement là où l'encre s'éteint.
    /// La sonde devient **la largeur rendue du mot contre la dalle**, qui
    /// doit rester ≥ 1,25× — c'est elle qui interdit de rétrécir le texte
    /// en douce pour le faire « tenir ».
    ///
    /// Un SEUL masque sur le composite (les deux dégradés se composent
    /// entre eux d'abord) : chaque masque posé sur une couche vidéo coûte
    /// un rendu hors écran de tout le plan, on n'en paie pas deux.
    private var fonduBords: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.28), location: 0.09),
                .init(color: .white, location: 0.25),
                .init(color: .white, location: 0.75),
                .init(color: .white.opacity(0.28), location: 0.91),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading, endPoint: .trailing)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.45), location: 0),
                    .init(color: .white, location: 0.20),
                    .init(color: .white, location: 0.60),
                    .init(color: .white.opacity(0.34), location: 0.84),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .top, endPoint: .bottom))
    }

    /// Le mot est remonté : le bas de la dalle appartient au « +20 COINS ».
    private static let assiette: CGFloat = -10
    /// Ce que la trame garde hors du faisceau — la matière des lettres.
    /// 0,14 laissait les lettres non éclairées à 12-35/255 : du vide, pas
    /// de la matière. 0,24 les fait exister sans les allumer.
    private static let plancherTrame: Double = 0.24

    var body: some View {
        ZStack {
            coucheBase
            matriceDansLeMot
        }
        .mask { fonduBords }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - La matrice

/// LA COUCHE VIDÉO de `fond-matrice-loop.mp4`.
///
/// ⚠️ **BORD À BORD, C'EST LA SEULE POSE LÉGALE.** Le commentaire de la
/// card reward est catégorique : *« une vidéo posée ailleurs qu'en bord de
/// card laisse TOUJOURS voir son rectangle — 4 essais, 4 démarcations,
/// 26-08 »*. Elle occupe donc la dalle ENTIÈRE, et c'est le glyphe qui
/// découpe. Son noir est vrai (médiane 5-18, 5ᵉ centile 2) : il n'y a aucun
/// rectangle clair à cacher.
///
/// ⚠️ Le fichier est PORTRAIT (1080×1426, 0,76:1) et la dalle fait 2,6:1 :
/// en `resizeAspectFill` on n'en voit qu'une bande horizontale. La trame
/// étant faite de colonnes, une bande en garde le grain — mais ça se
/// REGARDE sur capture avant d'être déclaré bon.
///
/// ⚠️ `AVPlayerLooper`, JAMAIS un `seek(.zero)` sur `didPlayToEndTime` (il
/// laisse une image noire au raccord), le looper RETENU par le
/// coordinateur, et muet. Et `clipsToBounds` **ET** `masksToBounds` :
/// SwiftUI ne rattrape pas UIKit.
final class MatriceLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct VideoMatrice: UIViewRepresentable {
    final class Coordinator {
        var player: AVQueuePlayer?
        /// Relâché, la boucle s'arrête au premier tour et le plan se fige.
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MatriceLayerView {
        let v = MatriceLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.clipsToBounds = true
        v.layer.masksToBounds = true
        v.playerLayer.videoGravity = .resizeAspectFill
        guard let url = Bundle.main.url(forResource: "fond-matrice-loop",
                                        withExtension: "mp4") else {
            // Sans le fichier, le mot reste sa base sombre. On ne pose
            // jamais un rectangle noir « en attendant ».
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
        // Rien à mettre en tampon : le fichier est dans le paquet.
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(
            player: p, templateItem: AVPlayerItem(url: url))
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        return v
    }

    func updateUIView(_ v: MatriceLayerView, context: Context) {}

    static func dismantleUIView(_ v: MatriceLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

// MARK: - La pièce qui tourne

/// LA PIÈCE QUI TOURNE — `PieceSprite` sur sa planche de 72 cases.
///
/// ⚠️ **PAS UNE VIDÉO.** `DepartCine.swift` porte les trois mesures qui ont
/// tué le seek : la planche est chargée une fois, et le tour ne fait plus que
/// choisir une case. Le `@State` du tour vit ICI, dans une vue minuscule :
/// une animation `repeatForever` posée sur la card ferait re-évaluer la card
/// entière à chaque image.
struct PieceQuiTourne: View {
    var diametre: CGFloat = 54
    /// La durée d'un tour complet.
    var periode: Double = 5.5
    var naissance: Date

    @State private var tour: Double = 0

    var body: some View {
        PieceSprite(planche: .or, tour: tour, diametre: diametre)
            .shadow(color: .black.opacity(0.6), radius: 10, y: 6)
            .onAppear(perform: lancer)
            .allowsHitTesting(false)
    }

    private func lancer() {
        // L'horloge clouée : la pièce se pose sur SA case et n'en bouge
        // plus — une capture de réglage est immobile.
        if let t = NotifBanc.tFige {
            tour = (t / periode).truncatingRemainder(dividingBy: 1)
            return
        }
        withAnimation(.linear(duration: periode)
            .repeatForever(autoreverses: false)) {
            tour = 1
        }
    }
}
