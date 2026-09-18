import SwiftUI

// LES DEUX VARIANTES DE RÉCOMPENSE, sous la surface à gratter.
//
// Elles sont montées AVANT le grattage et ne bougent pas : c'est le voile
// au-dessus qui s'efface. Rien ici ne se recalcule à la cadence de l'écran.

// MARK: - Variante 01 · les pièces

/// LE HEADER VIDÉO + LE GAIN. La vidéo tourne en boucle, muette, sans
/// contrôles — `AVPlayerLooper` par `DepartLoopVideo`, la seule école de
/// boucle de la maison.
///
/// ⚠️ Le fondu vers le noir est un DÉGRADÉ POSÉ AU-DESSUS, jamais un masque
/// sur la couche vidéo : un masque sur un `AVPlayerLayer` force un rendu hors
/// écran de tout le plan à chaque image.
struct RecompensePieces: View {
    let tirage: RecompenseTiree
    var revele: Bool

    @State private var roule = 0
    @State private var tour: Double = 0
    /// LA PASTILLE DE CRÉDIT (28-08 : « une fois les pièces collectées, il faut
    /// animer une pastille pour montrer que c'est pris en compte »). Elle
    /// arrive APRÈS que le compteur a fini de rouler — sinon elle annonce un
    /// total qu'on est encore en train de compter.
    @State private var pastille = false

    private var noire: Bool { tirage.coinType == .black }

    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 0) {
                header
                Spacer(minLength: 0)
                gain
                Spacer(minLength: 0).frame(height: 74)
            }
        }
        .onChange(of: revele) { _, v in if v { animerLeGain() } }
    }

    private var header: some View {
        DepartLoopVideo(nom: "reward-nosfy-coins")
            .frame(height: 232)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, .black.opacity(0.55), .black],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
            }
            .allowsHitTesting(false)
    }

    /// LE LANGAGE DE LA DERNIÈRE CARD DE LA STORY — le grand `+N` et la pièce.
    /// Relu, pas recopié : deux objets qui se ressemblent divergent à la
    /// première retouche.
    private var gain: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("+\(roule)")
                    .font(.system(size: 54, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(LinearGradient(
                        colors: [Color(white: 1.0), Color(white: 0.78)],
                        startPoint: .top, endPoint: .bottom))
                piece
            }
            Text(noire ? "Black coin — legendary currency" : "coins")
                .font(.system(size: 12, weight: .semibold))
                .tracking(noire ? 1.2 : 2.2)
                .foregroundStyle(.white.opacity(noire ? 0.72 : 0.45))
            pastilleCredit
        }
    }

    /// LA CONFIRMATION — un anneau qui se ferme sur une coche, et le mot. Elle
    /// ne dit pas « bravo », elle dit **c'est porté au compte** : c'est une
    /// quittance, pas une célébration. La célébration, c'est la card entière.
    @ViewBuilder private var pastilleCredit: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(white: 0.10))
                .frame(width: 17, height: 17)
                .background(Circle().fill(Color(white: 0.94)))
                .scaleEffect(pastille ? 1 : 0.2)
            Text("Added to your balance")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background {
            Capsule().fill(Color(white: 0.14))
            Capsule().stroke(.white.opacity(0.10), lineWidth: 0.6)
        }
        .opacity(pastille ? 1 : 0)
        .scaleEffect(pastille ? 1 : 0.88)
        .offset(y: pastille ? 0 : 8)
        .padding(.top, 10)
    }

    /// La pièce noire est la planche `piece-argent` du coffre — cerclage
    /// chrome froid, 72 cases : elle TOURNE. L'or, lui, reste posé.
    @ViewBuilder private var piece: some View {
        if noire {
            PieceSprite(planche: .argent, tour: tour, diametre: 46)
        } else {
            Image("piece-or-mini")
                .resizable().scaledToFit()
                .frame(width: 40, height: 40)
        }
    }

    private func animerLeGain() {
        let cible = tirage.montant
        roule = 0
        for i in 1 ... 18 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.035) {
                roule = Int(Double(cible) * Double(i) / 18.0)
            }
        }
        if noire {
            withAnimation(.easeOut(duration: 2.6)) { tour = 3 }
        }
        // la quittance arrive quand le compteur s'arrête, plus une respiration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.86) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.44, dampingFraction: 0.66)) {
                pastille = true
            }
        }
    }
}

// MARK: - Variante 02 · les boosters

/// LE WIN, REPRIS ET RÉTRÉCI (28-08 : « les boosters sont trop gros, baisse-les,
/// et prends le fond de la card WIN de la story, en doré avec fond fondu — et
/// on peut les bouger comme dans cette fameuse card »).
///
/// ⚠️ **MESURÉ** : dans le WIN les sachets font 130 pt de HAUT (~81 de large)
/// sur une card de 332 × 438 ; les miens faisaient **232 de LARGE**, soit
/// **2,9×**. Ils écrasaient la card. Ici : 150 pt de haut — un peu plus que le
/// WIN parce qu'ils sont le SUJET et pas un accessoire — et le HÉROS du WIN,
/// celui qui dépasse plus que les autres, sans quoi l'alignement est mort.
///
/// ⚠️ **DEUX ROBES** (28-08 : « le légendaire a sa propre combinaison froide,
/// blanche argent ») : l'or partout, le FROID pour le double légendaire. La
/// rareté se lit alors avant même de lire le texte.
// MARK: - Variante 02 · les boosters

/// ⚠️ **UN NOUVEAU VARIANT DE REWARD CARD, ET ON NE TOUCHE PAS À L'AUTRE**
/// (28-08, sa consigne). La robe « YOU MADE IT » de `RewardCard` reste
/// exactement ce qu'elle est ; celle-ci réutilise ses PIÈCES.
///
/// ⚠️ **J'AI PASSÉ QUATRE TOURS À RÉ-INVENTER CE QUI EXISTAIT.** Mon `MotGeant`,
/// mon balayage et ma lampe sont morts : `TexteGeant` + `LampeEventail` font la
/// même chose, en mieux, et ils sont déjà réglés. Ce qui a été sorti de
/// `private` là-bas, c'est de la VISIBILITÉ seulement — cinq lignes, aucun
/// comportement touché.
///
/// Et la leçon que je ne veux plus repayer : dans cette robe, **le texte n'est
/// pas « fondu par opacité », il est SOMBRE et la lampe le RÉVÈLE** — une copie
/// sombre plus une copie claire masquée par le champ de lumière qui descend de
/// la barrette. Je baissais l'opacité d'un texte clair : c'est pour ça que ça
/// rendait plat et gris.
///
/// ⚠️ **CE QUI VARIE VIENT DU BACKEND**, et rien d'autre : le NOMBRE (deuxième
/// ligne) et la LISTE des boosters affichés au pied de la card. Le reste est
/// fixe. Voir `tools/road/AUDIT-ROAD.md`.
struct RecompenseBoosters: View {
    let tirage: RecompenseTiree
    var revele: Bool

    /// LA SAISIE PARTAGÉE (`ObjetSaisissable`, extraite de StoryWin le 27-08
    /// justement pour ça) : on attrape, on traîne, ÇA RESTE OÙ ON LE POSE,
    /// c'est borné à l'intérieur de la card, et le déplacement soulève la poudre.
    @State private var placements: [Int: CGSize] = [:]
    @State private var prises: [Int: CGSize] = [:]
    @State private var tenus: Set<Int> = []
    @State private var grains: [(pos: CGPoint, naissance: Date)] = []
    @State private var saisies = 0
    /// L'instant de la révélation : la lampe et la cascade en partent.
    @State private var naissance = Date()

    private static let hb: CGFloat = 200

    /// LES TROIS LIGNES. Le mot de plus de 4 lettres prendra 0,88× tout seul
    /// dans `TexteGeant`, et le clip de la card le rognera — c'est la loi de
    /// cette robe, le rognage est ASSUMÉ (« MADE » touche les deux bords dans
    /// la référence, « IT » non : même corps, largeurs différentes).
    /// ⚠️ **DEUX LIGNES, PLUS TROIS** (28-08, sur sa référence TWICE/TODAY).
    /// « WIN » est mort. Et ce n'est pas qu'une ligne en moins : `TexteGeant`
    /// change de régime à deux lignes — **corps 128 au lieu de 112**,
    /// interligne −12 au lieu de −16 (« deux lignes respirent plus que trois »,
    /// dit son code). Le bloc devient donc plus GROS et plus SERRÉ tout seul.
    ///
    /// ⚠️ Et surtout : le fondu de la seconde ligne est **GRATUIT**. L'encre du
    /// composant va de **blanc 0,40 en haut → 0,17 au milieu → 0,06 en bas**,
    /// sur tout le bloc. À deux lignes, « 2 » vit dans 0,40→0,17 et
    /// « BOOSTERS » dans 0,17→0,06 : la seconde est trois à six fois plus
    /// sourde que la première, **sans un seul masque ajouté**. C'est exactement
    /// l'écart TWICE / TODAY de sa référence. Je passais mon temps à empiler
    /// des masques pour fabriquer ce que la position dans le bloc donne.
    /// ⚠️ **LE MOT LONG AU-DESSUS, LE CHIFFRE AU MILIEU** (28-08, son choix
    /// entre les deux options que je lui avais proposées).
    ///
    /// « UNLOCKED » fait 8 lettres : `TexteGeant` lui applique 0,88× (sa règle
    /// pour les mots de plus de 4 lettres) et **le clip de la card le rogne aux
    /// deux bords** — c'est l'effet de coupe premium qu'elle cherchait, et il
    /// vient de la LONGUEUR du mot, pas d'un réglage.
    ///
    /// Le chiffre est la seconde ligne : il vit donc dans la moitié basse du
    /// dégradé interne (0,17 → 0,06), là où « TODAY » vit dans sa référence.
    ///
    /// ⚠️ **TROIS LIGNES, ET `REWARD`** (28-08 : « les mots sont trop longs,
    /// unlock ou collected, fais plus court mais plus long que Win — et on ne
    /// voit plus booster en bas, le 3ᵉ mot est trop fondu »).
    ///
    /// LE MOT SE CHOISIT À LA RÈGLE, PAS AU GOÛT. Dans cette fonte, une lettre
    /// avance d'environ **0,78 em** et `tracking(-3)` en retire 3 pt. À trois
    /// lignes le corps est 112, et tout mot de plus de 4 lettres prend le
    /// 0,88× de `TexteGeant` → 98,6 pt, soit ~74 pt la lettre, sur une card de
    /// 321 (× 0,96 d'échelle) :
    ///
    /// | mot        | lettres | largeur / card | ce qu'on lit          |
    /// |------------|---------|----------------|-----------------------|
    /// | `WIN`      | 3       | 1,00 ×         | entier, aucune coupe  |
    /// | **`REWARD`** | **6** | **1,33 ×**     | **coupé, LISIBLE**    |
    /// | `UNLOCKED` | 8       | 1,77 ×         | « LOCK » — le CONTRE-SENS |
    /// | `COLLECTED`| 9       | 1,99 ×         | « LLECT »             |
    ///
    /// `UNLOCKED` sur une card de récompense affichait **LOCK**. Ce n'était pas
    /// une affaire de goût.
    ///
    /// ⚠️ Le fondu des lignes 2 et 3 reste **GRATUIT** : l'encre de `TexteGeant`
    /// va de blanc **0,40 en haut → 0,17 au milieu → 0,06 en bas** sur tout le
    /// bloc. `REWARD` vit dans 0,40→0,27, le chiffre dans 0,22→0,15,
    /// `BOOSTERS` dans 0,12→0,08 : une décroissance de ~1,8× par ligne, sans
    /// un seul masque ajouté. C'est l'écart TWICE / TODAY de sa référence.
    private var lignes: [String] {
        ["REWARD", "\(tirage.boosters.count)", "BOOSTERS"]
    }

    var body: some View {
        ZStack {
            fond
            // ⚠️ **LE FONDU SE FAIT AUX FLANCS ET AU PIED, JAMAIS EN GÉNÉRAL**
            // (la loi écrite dans `RewardCard`, en citant son verdict d'alors :
            // « je disais plutôt juste sur les côtés et le bas, là c'est trop.
            // Un voile général et un fondu du HAUT l'avaient ÉTEINT »). Le mot
            // doit rester FRANC AU CŒUR et se dissoudre en s'approchant des
            // bords. Mon réflexe aurait été de baisser l'opacité : c'est
            // exactement ce que ce commentaire interdit.
            //
            // Ces deux masques sont ceux que les autres robes appliquent en
            // HÔTE, par-dessus ceux de `TexteGeant`. Je les montais sans eux.
            TexteGeant(naissance: naissance, lignes: lignes)
                .scaleEffect(0.96)
                // ⚠️ **SUR-FONDU ANNULÉ.** Au tour d'avant j'avais élargi les
                // flancs à 32 % et tué le pied à 0,82 pour éteindre « WIN » —
                // et j'avais noyé les TROIS lignes. Retour aux masques hôtes
                // d'origine : le fondu vient maintenant de la POSITION dans le
                // bloc, pas d'un masque que j'empile.
                .mask(LinearGradient(
                    stops: [.init(color: .clear, location: 0),
                            .init(color: .white, location: 0.24),
                            .init(color: .white, location: 0.76),
                            .init(color: .clear, location: 1)],
                    startPoint: .leading, endPoint: .trailing))
                // ⚠️ **LE MASQUE DE PIED EST SUPPRIMÉ, ET C'EST LUI QUI TUAIT
                // LA TROISIÈME LIGNE.** Il valait 0,46 à 66 % et `clear` à
                // 94 % — or `BOOSTERS` vit entre 71 % et 93 % du bloc. Il se
                // faisait donc éteindre DEUX FOIS : une par l'encre du
                // composant (0,12 à 0,08 là où il est), une par ce masque
                // (× 0,80 puis × 0). Effectif : **0,05 en haut du mot, ZÉRO en
                // bas** — « le 3ᵉ mot est trop fondu » n'était pas un réglage
                // trop timide, c'était une extinction.
                //
                // Et la ligne juste au-dessus dit déjà la loi : « le fondu
                // vient de la POSITION dans le bloc, pas d'un masque que
                // j'empile ». Le dégradé interne de `TexteGeant` EST le fondu
                // du pied — il descend à 0,06 tout seul. Mon masque ne faisait
                // que le repayer une seconde fois. Il ne reste que les FLANCS,
                // qui eux ne font pas double emploi.
                // ⚠️ **ON ÉLOIGNE LE MOT DE LA SOURCE.** `TexteGeant` a un corps
                // FIXE de 112 pt quelle que soit la card ; la mienne fait 424 de
                // haut, donc trois lignes en remplissent 90 % et la première est
                // COLLÉE à la lampe. 26 pt de plus, et elle en reçoit
                // franchement moins — c'est physique, pas cosmétique.
                .offset(y: -18)
            // ⚠️ **BAISSER LA LAMPE N'EST PAS POSER UN VOILE.** Le commentaire
            // de la robe interdit le voile général et le fondu par le haut,
            // parce qu'ils ÉTEIGNENT le mot. Une source moins forte, elle,
            // laisse le mot franc au cœur et le laisse mourir aux bords —
            // c'est exactement l'effet demandé. Et c'est local à ce variant :
            // l'autre robe garde sa lampe entière.
            // la lampe reprend sa force pleine : c'est elle qui allume le « 2 »
            // et laisse « BOOSTERS » dans l'ombre, puisqu'il en est plus loin.
            LampeEventail(naissance: naissance)
            // ⚠️ **LES PAILLETTES D'AMBIANCE** (28-08 : « il manque les paillettes
            // qu'on a sur les autres cards »). `TexteGeant` porte déjà ses
            // `Scintilles`, mais elles ne vivent QUE dans les lettres. Les
            // autres cards ont en plus `PoudreDiamant` — des grains sur toute
            // la surface. C'est ça qui manquait.
            PoudreDiamant(largeur: CardRecompense.largeur,
                          hauteur: CardRecompense.hauteur,
                          naissance: naissance)
            sachets
            levre
            if !grains.isEmpty {
                PoudreGrattage(grains: grains).allowsHitTesting(false)
            }
        }
        // ⚠️ `ObjetSaisissable` lit ses gestes dans l'espace nommé « storyFlow ».
        .coordinateSpace(name: "storyFlow")
        .onChange(of: revele) { _, v in if v { naissance = Date() } }
    }

    /// ⚠️ **LE BORD HAUT REPART DU NOIR**, et c'est le piège que j'ai
    /// re-fabriqué : j'avais posé 0,155 dès le sommet, soit exactement la
    /// « PLAQUE GRISE PLATE » que le commentaire de la robe dit d'éviter, en
    /// citant son verdict d'alors — « le background du haut doit être plus
    /// fondu, ça jure ». Le gris culmine SOUS la crête (0,125 à 26 %), et la
    /// crête retourne au noir : c'est dans ce noir que le mot se noie.
    private var fond: some View {
        LinearGradient(
            stops: [.init(color: Color(white: 0.012), location: 0),
                    .init(color: Color(white: 0.062), location: 0.09),
                    .init(color: Color(white: 0.125), location: 0.26),
                    .init(color: Color(white: 0.098), location: 0.44),
                    .init(color: Color(white: 0.045), location: 0.68),
                    .init(color: Color(white: 0.010), location: 0.90),
                    .init(color: .black, location: 1)],
            startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }

    // MARK: la poche

    /// ⚠️ **UNE SEULE HORLOGE POUR TOUTE LA POCHE**, jamais une par sachet.
    private var sachets: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { tl in
            poche(t: tl.date.timeIntervalSince(naissance))
        }
    }

    private func poche(t: Double) -> some View {
        let l = CardRecompense.largeur, h = CardRecompense.hauteur
        let wb = Self.hb * 0.70
        let bornes = Bornes(x: l / 2 - wb * 0.30,
                            haut: -h / 2 + Self.hb * 0.55, bas: h / 2)
        let centre = CGPoint(x: l / 2, y: h / 2)
        return ZStack {
            ForEach(Array(tirage.boosters.enumerated()), id: \.offset) { i, b in
                sachet(i: i, type: b, t: t, centre: centre, bornes: bornes)
            }
        }
    }

    private func sachet(i: Int, type: TypeBooster, t: Double,
                        centre: CGPoint, bornes: Bornes) -> some View {
        let p = pose(i)
        let n = nage(i: i, t: t)
        // L'ENTRÉE EST UNE CASCADE SERRÉE : 100 ms d'écart, 120 ms de course —
        // l'ordre de grandeur de la référence (48 à 190 ms). Une arrivée molle
        // serait un vol, pas une chute.
        let u = min(max((t - 0.15 - Double(i) * 0.10) / 0.12, 0), 1)
        let venue = 1 - pow(1 - u, 3.0)
        return ObjetSaisissable(
            cle: i, centre: centre, bornes: bornes,
            base: CGPoint(x: p.dx + n.dx,
                          y: p.dy + n.dy + CGFloat(1 - venue) * 190),
            revient: false,
            placements: $placements, prises: $prises,
            tenus: $tenus, grains: $grains, saisies: $saisies) {
                SachetRecompense(type: type, tenu: tenus.contains(i),
                                 naissance: naissance)
                    .frame(height: Self.hb * (i == 0 ? 1.10 : 1.0))
                    .rotationEffect(.degrees(p.angle + n.deg))
                    .opacity(min(1, u * 2.5))
            }
            .zIndex(Double(i == 0 ? 3 : i))
    }

    /// LA NAGE — trois horloges **premières** (non commensurables : elles ne se
    /// resynchronisent jamais, donc le mouvement ne bat jamais la mesure).
    /// Houle ±18 pt, dérive ±6, balancement ±4,5° — les amplitudes du WIN.
    private func nage(i: Int, t: Double) -> (dx: CGFloat, dy: CGFloat, deg: Double) {
        let phi = Double(i) * 2.1
        let houle = CGFloat(sin(t * 0.53 + phi)) * 18
        let derive = CGFloat(sin(t * 0.31 + phi * 1.7)) * 6
        let balance = sin(t * 0.41 + phi * 0.9) * 4.5
        return (derive, houle, balance)
    }

    /// Coupés à MOITIÉ et ils se CHEVAUCHENT. Le HÉROS est le premier — 10 %
    /// plus grand, devant, plus incliné.
    private func pose(_ i: Int) -> (dx: CGFloat, dy: CGFloat, angle: Double) {
        let bases: [(CGFloat, CGFloat, Double)] = [
            (-40, 214, -13), (34, 198, 9), (2, 226, -4),
        ]
        let b = bases[i % bases.count]
        return (b.0, b.1, b.2)
    }

    /// LA LÈVRE — le pied de la card est le palier le plus noir et les sachets
    /// s'y enfoncent. Sans elle ils sont rognés ; avec elle ils sont DEDANS.
    private var levre: some View {
        LinearGradient(
            stops: [.init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.45), location: 0.55),
                    .init(color: .black.opacity(0.88), location: 1)],
            startPoint: .top, endPoint: .bottom)
            .frame(height: CardRecompense.hauteur * 0.22)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .allowsHitTesting(false)
    }
}

/// LE SACHET — l'asset détouré, son liseré de repos si c'est le légendaire, et
/// son holo à la prise. ⚠️ L'irisation se peint en `plusLighter` : posée en
/// blanc sur une frise déjà claire, et **l'irisation meurt**. Des couleurs
/// saturées, une intensité basse : le holo COLORE, il n'éclaire pas.
///
/// ⚠️ L'arc tourne à **6 °/s**, pas 24 : un sachet posé dans une card n'est pas
/// un objet qu'on incline à la main.
struct SachetRecompense: View {
    let type: TypeBooster
    var tenu: Bool = false
    var naissance: Date = Date()

    var body: some View {
        ZStack {
            Image(type == .orange ? "booster-orange" : "sticker-booster")
                .resizable().scaledToFit()
                .overlay { liserePose }
                .overlay { holoTenu }
        }
        .scaleEffect(tenu ? 1.04 : 1)
        // ⚠️ **PAS D'OMBRE SUR UN OBJET QUI BOUGE** (28-08, « l'animation lag
        // des boosters »). C'est la loi mesurée du WIN, mot pour mot : « Un
        // DÉGRADÉ, jamais un `blur` : **trois flous par image coûtaient
        // 14 img/s** (42 contre 56 mesurés) ». J'avais trois `.shadow()` sur
        // trois sachets qui nagent à la cadence de l'écran — donc trois flous
        // recalculés à chaque image. Remplacés par une ellipse PEINTE, qui ne
        // coûte rien.
        .background {
            Ellipse()
                .fill(RadialGradient(
                    colors: [.black.opacity(tenu ? 0.62 : 0.50), .clear],
                    center: .center, startRadius: 0, endRadius: 90))
                .frame(width: 190, height: 96)
                .offset(y: 74)
        }
        .animation(.easeOut(duration: 0.18), value: tenu)
    }

    /// Le liseré AU REPOS du légendaire — un reflet, pas une robe : à pleine
    /// force l'irisation mange le noir du sachet.
    @ViewBuilder private var liserePose: some View {
        if type == .legendaryBlack {
            Image("sticker-booster-holo")
                .resizable().scaledToFit()
                .blendMode(.plusLighter)
                .opacity(0.5)
        }
    }

    /// ⚠️ **L'HORLOGE DU HOLO NE SE MONTE QUE QUAND LE SACHET EST TENU**
    /// (28-08, « l'animation lag des boosters »). Elle tournait sur les TROIS
    /// sachets en permanence, alors qu'un seul peut être tenu à la fois : deux
    /// `TimelineView` de trop, à 30 Hz, sous une card qui a déjà cinq horloges.
    @ViewBuilder private var holoTenu: some View {
        if tenu {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                holo(angle: tl.date.timeIntervalSince(naissance) * 6)
            }
        }
    }

    private func holo(angle: Double) -> some View {
        let irise = AngularGradient(
            colors: [Color(red: 0.05, green: 0.85, blue: 1.0),
                     Color(red: 1.0, green: 0.25, blue: 0.85),
                     Color(red: 1.0, green: 0.78, blue: 0.15),
                     Color(red: 0.20, green: 1.0, blue: 0.45),
                     Color(red: 0.05, green: 0.85, blue: 1.0)],
            center: .center, angle: .degrees(angle))
        return ZStack {
            Image("sticker-booster-holo")
                .resizable().scaledToFit()
                .foregroundStyle(irise)
                .blur(radius: 3.5)
                .opacity(0.55)
            Image("sticker-booster-holo")
                .resizable().scaledToFit()
                .foregroundStyle(irise)
                .opacity(0.62)
        }
        .blendMode(.plusLighter)
    }
}
