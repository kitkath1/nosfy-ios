import SwiftUI

// MARK: - LA CARD BOOSTER — « le sachet EST le bouton » (variant B)
//
// Remplace la feuille qui montait du bas (`BoosterPopupHote`, BoosterPopup.swift) :
// bord à bord, poignée de glissement, grosse pilule contourée — la grammaire
// d'une feuille système, pas d'un bijou, et la home restait visible au-dessus.
//
// Ici c'est une CARD centrée, de la même famille que la card reward et la card
// STOP : scrim profond, dalle noire, liseré, spot qui balaie, poudre.
//
// ⚠️ CE QUI FAIT LE VARIANT B, et qu'on ne dilue pas : il n'y a NI mot géant,
// NI slider, NI bouton. Le sachet est gros, centré, et **c'est lui qu'on
// touche**. L'objet EST l'action — un slider dit « engagement », ce qui va au
// STOP mais pas à un cadeau. Un doigt blanc montre le geste.
//
// ⚠️ TOUJOURS LE SACHET ORANGE (verdict Kathryn, 30-08) : jamais le noir. La
// robe ne descend donc plus jusqu'ici — le booster noir a son propre manège.

// MARK: L'hôte à la racine

/// La signature de `BoosterPopupHote` MOINS `robe` (voir ci-dessus). La racine
/// le monte inconditionnellement sur `sacre.popupOuverte` ; c'est l'hôte qui
/// gère son vide.
///
/// Un seul progrès `p` porté par une vue `Animatable`, et des verrous en
/// DRAPEAUX posés par les completions — jamais une garde sur la valeur de `p` :
/// sous `withAnimation` le modèle saute à la cible dès la première image.
struct BoosterCardHote: View {
    var ouverte: Bool
    var onOuvrir: () -> Void = {}
    var onFermer: () -> Void = {}

    @State private var p: Double = 0
    @State private var montee = false
    @State private var posee = false
    @State private var enSortie = false
    /// L'horloge du spot, de la poudre, de la flottaison et du doigt.
    @State private var naissance = Date()
    /// L'envol du sachet — armé au commit, il part AVANT la card.
    @State private var envol = false
    @State private var boum = 0

    var body: some View {
        ZStack {
            Color.clear
            if montee {
                BoosterCard(p: p, envol: envol, naissance: naissance,
                            onOuvrir: commettre,
                            onFermer: { fermer(puis: onFermer) })
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(ouverte)
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0),
                         trigger: boum)
        .onChange(of: ouverte) { _, v in
            if v {
                if !montee { ouvrir() }
            } else if montee, !enSortie {
                fermer(puis: {})
            }
        }
        .onAppear { if ouverte, !montee { ouvrir() } }
    }

    // MARK: le film

    /// L'ENTRÉE — 0,70 s : un peu plus longue que la question du STOP (0,60),
    /// parce que celle-ci OFFRE. Le sachet arrive après la lumière.
    private func ouvrir() {
        naissance = Date().addingTimeInterval(-(BoosterCardBanc.tFige ?? 0))
        enSortie = false
        envol = false
        posee = BoosterCardBanc.fige
        p = BoosterCardBanc.fige ? 1 : 0
        montee = true
        guard !BoosterCardBanc.fige else { return }
        withAnimation(.linear(duration: 0.70)) {
            p = 1
        } completion: {
            posee = true
            boum += 1
        }
    }

    /// « Later », ou le scrim — 0,30 s.
    private func fermer(puis fin: @escaping () -> Void) {
        guard montee, !enSortie else { return }
        enSortie = true
        withAnimation(.easeOut(duration: 0.30)) {
            p = 0
        } completion: {
            montee = false
            fin()
        }
    }

    /// ON OUVRE — l'ordre est le sujet : le SACHET s'envole d'abord (0,42 s,
    /// il monte et se dissout), PUIS la card s'en va, PUIS le manège s'ouvre.
    /// Le geste doit avoir une conséquence visible avant que l'écran change,
    /// sinon on croit avoir raté son toucher.
    private func commettre() {
        guard montee, posee, !enSortie else { return }
        enSortie = true
        // Le RRRIP se SENT : l'haptique de commit de la maison (celle du
        // slider), pas un simple impact — « haptique fort » (verdict).
        CommitHaptic.play()
        boum += 1
        withAnimation(.easeIn(duration: 0.42)) { envol = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            withAnimation(.easeOut(duration: 0.30)) {
                p = 0
            } completion: {
                montee = false
                onOuvrir()
            }
        }
    }
}

// MARK: - Les cotes partagées (§4 du plan)

/// Les cotes que la card ET son sachet lisent — depuis le bord haut de la card.
private enum CoteBooster {
    /// Le centre du sachet et sa hauteur. v2 (verdict « un peu plus petit ») :
    /// 200 → 176, centre 144 → 136 ; les 12 pt libérés vont à l'air du titre.
    /// Troisième tour (« réduis la taille du booster ») : 176 → 156.
    static let centreSachet: CGFloat = 140
    static let hauteurSachet: CGFloat = 156
    /// La largeur du sachet : le ratio du corps par le plastique (795 / 1334).
    static var largeurSachet: CGFloat { hauteurSachet * 0.596 }
    /// LA LIGNE DE DÉCHIRURE, en fraction de la hauteur du sachet — cuite par
    /// `bake_sachet.py` (y = 62 sur 1334 px : sous le cran, au-dessus du
    /// cadre néon, là où un vrai sachet cède).
    static let ligneDechirure: CGFloat = 62.0 / 1334.0
    /// Au-delà de cette montée, le sachet est parti — on ouvre.
    static let seuilGlisse: CGFloat = 64
    /// L'orange du set Lune — la seule couleur autorisée du parcours booster.
    /// La braise dorée de `PoudreBooster`, à l'identique (BoosterPopup:685).
    static let orange = Color(red: 1.00, green: 0.62, blue: 0.26)
    /// La période de la boucle de la main — le texte vit sur la même horloge.
    static let periodeIndice: Double = 3.0
}

// MARK: - La card

struct BoosterCard: View, Animatable {
    var p: Double
    var envol: Bool
    var naissance: Date
    var onOuvrir: () -> Void
    var onFermer: () -> Void

    /// La main a touché le sachet (écrit UNE fois, par `SachetVivant`) : la
    /// légende baisse la voix. Rien ici n'est écrit par image — ce serait
    /// rejouer la card entière (vidéo, lampe, poudre, encre) à chaque image.
    @State private var touche = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    private static let forme = RoundedRectangle(cornerRadius: 36,
                                                style: .continuous)
    /// Plus courte que la card STOP (1,4458) : pas de slider à loger.
    private static let ratio: CGFloat = 1.40
    /// L'intensité des POINTS du mur : la vidéo = fond + points, et le fond
    /// est le même que `fond` dessous — son opacité ne règle que les points.
    /// 0,8 : tranché sur la planche `dot-composition.png` (0,6 / 0,8 / 1,0).
    private static let points: Double = 0.8

    var body: some View {
        GeometryReader { g in
            let l = min(g.size.width * 0.80, 332)
            ZStack {
                // 0,82 et non 0,70 (celui de la card STOP) : celle-ci s'ouvre
                // sur la HOME, dont le titre blanc et la lueur orange du bas
                // traversaient encore. Une card jugée sur un banc noir ne dit
                // rien du voile qu'il lui faut sur une vraie page.
                Color.black.opacity(0.82 * sstepB(0, 0.35, p))
                    .contentShape(Rectangle())
                    .onTapGesture { onFermer() }
                carte(largeur: l, hauteur: l * Self.ratio)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .accessibilityAddTraits(.isModal)
    }

    // MARK: les couches

    private func carte(largeur l: CGFloat, hauteur h: CGFloat) -> some View {
        ZStack {
            Self.forme.fill(Color.black)
            fond
            // LA VIDÉO EST LE MUR (`tools/sacre/bake_dot.py`) : le fond de
            // la card EN PIXELS + la bande de points en écran, vignettée dans
            // le fichier. Bord à bord, opaque, SANS masque (la loi) — et ses
            // bords valent exactement `fond` dessous : pendant l'entrée elle
            // fond dans un mur identique, aucune couture possible.
            VideoBoucle(nom: "booster-dot-loop")
                .frame(width: l, height: h)
                .opacity(Self.points * sstepB(0.15, 0.55, p))
            LampeEventail(naissance: naissance)
                .opacity(sstepB(0.20, 0.65, p))
            PoudreBooster(W: l, slotH: h, naissance: naissance)
                .opacity(sstepB(0.35, 0.80, p))
            // Le sachet, sa lueur et son doigt — la seule vue qui reçoit le
            // toucher, et la seule qui se ré-évalue pendant le glissement.
            SachetVivant(p: p, envol: envol, naissance: naissance,
                         largeur: l, hauteur: h,
                         onOuvrir: onOuvrir,
                         onTouche: { touche = true })
            legende(largeur: l, hauteur: h)
            encre(largeur: l, hauteur: h)
            Self.forme.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.14), location: 0),
                        .init(color: .white.opacity(0.08), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
                .opacity(sstepB(0.12, 0.45, p))
        }
        .clipShape(Self.forme)
        .frame(width: l, height: h)
        .scaleEffect(0.94 + 0.06 * sstepB(0, 0.30, p))
        .opacity(sstepB(0, 0.16, p))
        .shadow(color: .white.opacity(0.14 * sstepB(0.25, 0.65, p)),
                radius: 38, y: 30)
    }

    /// Le mur : quasi-noir en haut (le sachet et le faisceau y vivent), une
    /// lueur de sol basse — la leçon de la card STOP, où le gris derrière un
    /// objet sombre faisait ressortir chaque défaut de bord.
    /// ⚠️ Les mêmes six stops que `bake_dot.py` : la vidéo les porte en pixels.
    private var fond: some View {
        LinearGradient(
            stops: [
                .init(color: Color(white: 0.006), location: 0),
                .init(color: Color(white: 0.014), location: 0.36),
                .init(color: Color(white: 0.050), location: 0.62),
                .init(color: Color(white: 0.066), location: 0.74),
                .init(color: Color(white: 0.028), location: 0.86),
                .init(color: Color(white: 0.008), location: 1)
            ],
            startPoint: .top, endPoint: .bottom)
            .opacity(sstepB(0.10, 0.45, p))
            .allowsHitTesting(false)
    }

    /// LE TEXTE v3 — « drag to open », qui NAÎT ET MEURT DANS LE FLOU : le
    /// vocabulaire déjà codé du coffre (`ArriveeFloue`, CoffreV2:1159 — flou
    /// 9 → 0, 9 pt de montée, opacité), sur l'horloge de la main : il sort du
    /// flou quand elle paraît, tient pendant le glissement, et y rentre quand
    /// elle part. La robe de « pull to start » (Inter 11 medium, tracking 1,6),
    /// en blanc 0,62. Quand la main a touché, il reste, bas et net (0,30).
    private func legende(largeur l: CGFloat, hauteur h: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion || touche)) { tl in
            let c = BoosterCardBanc.phaseMain(tl.date, naissance: naissance)
            // Au diapason de la main (0 → 0,12 ; 0,76 → 0,92) ; posé net et
            // fixe sous « Réduire les animations » et après le contact.
            let q = (touche || reduceMotion) ? 1.0
                : sstepB(0.00, 0.12, c) * (1 - sstepB(0.76, 0.92, c))
            // « Drag to open » — la majuscule (verdict), et l'encre est un
            // DÉGRADÉ DE BLANC qui s'efface vers la droite, comme la main
            // s'efface vers le poignet : la même matière.
            Text("Drag to open")
                .font(.inter(11, .medium))
                .tracking(1.6)
                .foregroundStyle(LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.45),
                        .init(color: .white.opacity(0.25), location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing))
                // Le rayon retombe à 0 EXACT quand le texte dort.
                .blur(radius: (q > 0.995 || q < 0.005) ? 0 : 9 * (1 - q))
                .offset(y: 9 * (1 - q))
                // Le 0,62 / 0,30 vit sur l'OPACITÉ (animable), pas sur la
                // couleur : au contact il FOND en 0,28 s, il ne claque plus.
                .opacity(q * (touche ? 0.30 : 0.62))
        }
        .animation(.easeOut(duration: 0.28), value: touche)
        .frame(width: l, height: h, alignment: .top)
        // La ligne fait ~14 pt : son centre à 272 (§4 du plan).
        .offset(y: 272 - 7)
        .opacity(sstepB(0.60, 0.92, p))
        .allowsHitTesting(false)
    }

    // MARK: l'encre

    private func encre(largeur l: CGFloat, hauteur h: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Text("A booster is waiting!")
                    .font(.inter(22, .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, .white.opacity(0.78)],
                                       startPoint: .top, endPoint: .bottom))
                Text("A Moon set card sleeps inside.")
                    .font(.inter(15))
                    .foregroundStyle(Color.white.opacity(0.55))
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .opacity(sstepB(0.50, 0.80, p))
            .offset(y: 6 * (1 - sstepB(0.50, 0.80, p)))
            .allowsHitTesting(false)

            Button(action: onFermer) {
                Text("Later")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .opacity(sstepB(0.60, 0.92, p))
        }
        .padding(.bottom, 16)
        .frame(width: l, height: h, alignment: .bottom)
    }
}

// MARK: - Le sachet vivant : l'objet, sa lueur, son doigt — et le geste

/// LE SACHET, SA LUEUR ET SON INDICE, dans UNE vue à part. C'est ELLE qui
/// possède `prise` (écrit à CHAQUE IMAGE du glissement) et `touche` : sur
/// `BoosterCard`, qui contient tout (vidéo, lampe, poudre, encre, liseré), un
/// `@State` écrit par image aurait rejoué le corps entier à chaque image du
/// doigt — la loi de la page qui se ré-évalue par image (relecture adverse,
/// 30-08). Ici le drag ne ré-évalue que le sachet et sa lueur.
private struct SachetVivant: View {
    var p: Double
    var envol: Bool
    var naissance: Date
    var largeur: CGFloat
    var hauteur: CGFloat
    var onOuvrir: () -> Void
    /// Appelé UNE fois, au premier contact — la légende de la card baisse.
    var onTouche: () -> Void

    /// Le doigt de l'utilisatrice a-t-il pris le sachet ? (la montée, freinée)
    /// C'est aussi LA PROFONDEUR DE DÉCHIRURE : `prise / seuilGlisse` ∈ [0, 1].
    /// Au banc, `-boosterPrise <pt>` la cloue (on ne juge pas un geste au hasard).
    @State private var prise: CGFloat = BoosterCardBanc.priseFige ?? 0
    /// La main a touché : l'indice n'a plus rien à apprendre, il s'éteint.
    @State private var touche = false
    /// Le jeton du chien de garde (voir `armerChienDeGarde`).
    @State private var jeton = 0
    /// LES CRANS — un tic léger tous les 12 pt de déchirure (la grammaire des
    /// crans du slider). Le sim ne vibre pas : verdict téléphone.
    @State private var cran = 0
    @State private var dernierCran = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            lueur
            sachet
        }
    }

    /// LA LUEUR DE SCÈNE (§18.5 du coffre, `CoffreV2.lueurObjet`) : le sachet
    /// ne transporte plus sa lumière — l'asset est DURCI, sa lueur jetée — elle
    /// est refaite ICI, en radial. Et elle peut ce qu'un halo peint dans des
    /// pixels ne saura jamais : respirer, s'allumer quand on le prend
    /// (+ 0,25 sur la course), s'éteindre AVANT lui au commit.
    /// Un dégradé, jamais un `.blur` (une passe hors écran par image de geste).
    private var lueur: some View {
        let w = CoteBooster.largeurSachet
        let d = Double(min(1, prise / CoteBooster.seuilGlisse))
        // « Le halo derrière s'allume très fort » (verdict, troisième tour) :
        // de 0,55 à 1,0 sur la déchirure, et il s'élargit.
        return Ellipse()
            .fill(RadialGradient(
                colors: [CoteBooster.orange.opacity(0.42),
                         CoteBooster.orange.opacity(0)],
                center: .center, startRadius: 0,
                endRadius: w * (0.95 + 0.25 * d)))
            .frame(width: w * (1.9 + 0.4 * d), height: w * (2.1 + 0.4 * d))
            .offset(y: -prise * 0.3)
            .opacity((0.55 + 0.45 * d) * sstepB(0.30, 0.70, p))
            // Centrée 12 pt sous le centre du sachet.
            .frame(width: largeur, height: hauteur, alignment: .top)
            .offset(y: CoteBooster.centreSachet + 12 - w * 1.05)
            .allowsHitTesting(false)
    }

    /// ⚠️ UN SEUL GESTE porte le tap ET le glissement (`minimumDistance: 0`).
    /// Un `Button` posé sous un `DragGesture` se fait annuler dès que le drag
    /// reconnaît — piège déjà payé dans ce dépôt. Ici on décide À LA LEVÉE :
    /// course courte = un tap, montée franche = un glissement. Les deux
    /// ouvrent.
    private var sachet: some View {
        let d = Double(min(1, prise / CoteBooster.seuilGlisse))
        let flotte = TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                             paused: reduceMotion)) { tl in
            let t = tl.date.timeIntervalSince(naissance)
            dechirure(d: d)
                // La respiration : il PLANE, il ne tremble pas.
                .offset(y: reduceMotion ? 0 : CGFloat(sin(t * 0.9) * 4))
                .rotationEffect(.degrees(reduceMotion ? 0
                                         : sin(t * 0.62 + 1.1) * 1.4))
        }
        return flotte
            // Tenu, il grossit d'un rien.
            .scaleEffect(1 + 0.03 * d)
            // L'arrivée : il tombe dans la lumière APRÈS elle.
            .opacity(sstepB(0.34, 0.72, p))
            .scaleEffect(0.88 + 0.12 * sstepB(0.34, 0.80, p))
            .overlay { indice }
            // « Haptique fort » (verdict) : les crans sont LOURDS — on
            // déchire du plastique, pas du papier.
            .sensoryFeedback(.impact(weight: .heavy, intensity: 0.9),
                             trigger: cran)
            // ⚠️ LA ZONE DE TOUCHER EST LE SACHET (+ 12 pt de confort), pas la
            // card. Posée ICI, avant le cadrage `largeur × hauteur` : posée
            // après, elle valait toute la card ET 48 pt de scrim sous elle —
            // un tap sur le titre, ou juste sous la card, ouvrait le booster
            // (relecture adverse, 30-08). ~146 × 200 pt : bien au-delà des 44.
            .contentShape(Rectangle().inset(by: -12))
            .gesture(geste)
            .frame(width: largeur, height: hauteur, alignment: .top)
            .offset(y: CoteBooster.centreSachet - CoteBooster.hauteurSachet / 2)
    }

    /// LA DÉCHIRURE (PLAN §13) — deux pièces cuites au pixel l'une sur
    /// l'autre (`bake_sachet.py` v4) : le CAPUCHON monte avec le doigt et
    /// bascule vers l'arrière ; le CORPS reste et s'affaisse de 2 pt ; entre
    /// les deux, la FENTE s'allume — la carte qui dort dedans respire. Au
    /// commit (`envol`), le capuchon PART (+40 pt, il s'efface) et le corps
    /// reste ouvert : le manège reprend la déchirure là où la card l'a laissée.
    /// Lâchée avant le seuil, `prise` retombe au ressort et tout se referme.
    private func dechirure(d: Double) -> some View {
        let h = CoteBooster.hauteurSachet
        let w = CoteBooster.largeurSachet
        let fenteY = -h / 2 + h * CoteBooster.ligneDechirure
        // ⚠️ LE CAPUCHON PÈLE, IL NE S'ENVOLE PAS : à 1:1 sous le doigt, il
        // quittait le sachet dès 24 pt (mesuré sur `dechirure-prises.png`) —
        // une bande qui part, pas un sachet qui s'ouvre. Il suit le doigt à
        // 0,35 (22 pt au seuil) : de la résistance, et la bascule fait le reste.
        let levee = prise * 0.35
        return ZStack {
            Image("booster-hero-corps")
                .resizable()
                .scaledToFit()
                .frame(height: h)
                .offset(y: 2 * d)
            // LA LUMIÈRE DE LA FENTE — ENTRE les deux lèvres (le milieu de
            // l'écart), blanc au cœur, l'orange du set aux bords, en additif ;
            // son flou retombe à 0 exact quand elle dort.
            Capsule()
                .fill(LinearGradient(
                    colors: [.white, CoteBooster.orange.opacity(0.9)],
                    startPoint: .top, endPoint: .bottom))
                // Une FENTE, pas une lampe (v8 : 20 pt de haut, flou 6, 0,95
                // — un nuage blanc au-dessus du sachet) : fine, contenue dans
                // la largeur du corps, et elle ne dépasse jamais l'écart.
                .frame(width: w * 0.80, height: 2 + 8 * d)
                .blur(radius: d > 0.01 ? 4 : 0)
                .blendMode(.plusLighter)
                .offset(y: fenteY - levee / 2)
                .opacity(d * 0.75)
            Image("booster-hero-cap")
                .resizable()
                .scaledToFit()
                .frame(height: h)
                .offset(y: -levee)
                // Il bascule vers l'arrière, charnière sur la ligne de déchirure.
                .rotation3DEffect(.degrees(-14 * d), axis: (x: 1, y: 0, z: 0),
                                  anchor: UnitPoint(x: 0.5,
                                                    y: CoteBooster.ligneDechirure),
                                  perspective: 0.6)
                .offset(y: envol ? -40 : 0)
                .opacity(envol ? 0 : 1)
        }
    }

    private var geste: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                if !touche {
                    touche = true
                    onTouche()
                }
                // Seule la MONTÉE compte, et elle freine : on doit sentir
                // qu'on tire sur quelque chose.
                prise = max(0, -v.translation.height) * 0.62
                let c = Int(prise / 12)
                if c != dernierCran {
                    dernierCran = c
                    cran += 1
                }
                armerChienDeGarde()
            }
            .onEnded { v in
                jeton += 1                      // désarme le chien de garde
                dernierCran = 0
                let monte = -v.translation.height * 0.62
                let court = abs(v.translation.height) < 10
                    && abs(v.translation.width) < 10
                if court || monte >= CoteBooster.seuilGlisse {
                    prise = 0
                    onOuvrir()
                } else {
                    withAnimation(.spring(response: 0.34,
                                          dampingFraction: 0.7)) { prise = 0 }
                }
            }
    }

    /// LE CHIEN DE GARDE — un `DragGesture` peut mourir sans `onEnded`
    /// (arrière-plan, appel, présentation ; la loi du geste annulé). Sans lui,
    /// le sachet resterait levé et la lueur allumée jusqu'au prochain toucher,
    /// et un seuil franchi ne commettrait jamais. Réarmé à chaque image ; il ne
    /// tire que si le doigt s'est tu 0,6 s — un doigt qui TIENT le sachet en
    /// l'air si longtemps sans bouger est rare, et au-dessus du seuil c'est un
    /// commit, pas une perte.
    private func armerChienDeGarde() {
        jeton += 1
        let j = jeton
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard j == jeton, prise > 0 else { return }
            if prise >= CoteBooster.seuilGlisse {
                prise = 0
                onOuvrir()
            } else {
                withAnimation(.spring(response: 0.34,
                                      dampingFraction: 0.7)) { prise = 0 }
            }
        }
    }

    /// LA MAIN v3 — « Apple, full dégradé blanc, un filament qui glisse
    /// derrière, le texte flouté » (verdict Kathryn 30-08, après-midi : la v2
    /// en contour + lueur lisait comme un curseur, « trop cheap »).
    ///
    /// La main est PLEINE (`hand.point.up.fill`, 26 pt), remplie d'un dégradé
    /// de blanc, avec une ombre portée qui la décolle du sachet — ni contour,
    /// ni lueur additive : la matière fait le premium, pas l'effet. DERRIÈRE
    /// elle glisse un FILAMENT blanc de 1,5 pt : c'est lui qui dit « glisse »,
    /// la main ne fait que montrer où.
    ///
    /// La boucle (3,0 s, `CoteBooster.periodeIndice`) :
    ///   0 → 0,12     elle paraît (opacité + 4 pt de montée)
    ///   0,12 → 0,22  elle TOUCHE (s'enfonce de 6 %, un anneau fin s'ouvre)
    ///   0,22 → 0,62  elle MONTE de 60 pt, le filament s'allonge derrière
    ///   0,62 → 0,76  elle s'efface, le filament se dissout
    ///   0,76 → 1     silence — le texte rentre dans le flou (côté card)
    /// Elle s'éteint dès que la main touche : un tuto qui insiste après coup
    /// passe pour un défaut. Elle n'attrape jamais le doigt.
    private var indice: some View {
        // ⚠️ L'horloge s'arrête au premier contact (le fondu de sortie vit sur
        // l'opacité externe, il joue quand même) — sinon elle tourne à 30 Hz
        // pour toute la vie de la card sur du contenu invisible. Et sous
        // « Réduire les animations » on rend une main STATIQUE, pas une
        // horloge gelée à c ≈ 0 (= rien du tout) — relecture adverse, 30-08.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion || touche)) { tl in
            let c = BoosterCardBanc.phaseMain(tl.date, naissance: naissance)
            if reduceMotion {
                corpsIndice(parait: 1, anneau: 0, monte: 0, part: 1)
            } else {
                corpsIndice(parait: sstepB(0.00, 0.12, c),
                            anneau: sstepB(0.12, 0.22, c),
                            monte: sstepB(0.22, 0.62, c),
                            part: 1 - sstepB(0.62, 0.76, c))
            }
        }
        .opacity(touche ? 0 : sstepB(0.72, 1.0, p))
        .animation(.easeOut(duration: 0.28), value: touche)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// v4 (verdict « pas assez premium » sur le film `main-boucle.png`) : la
    /// v3 faisait 26 pt et son fondu ne laissait qu'un bout de doigt — un
    /// curseur ; le filament était une BARRE raide posée à côté. Ici : la
    /// main des indices Apple (40 pt), blanche pleine jusqu'à la paume, qui
    /// meurt au poignet, avec SA lumière dessous (le même glyphe, très
    /// flouté, additif — ni ombre, ni bord : un halo) ; et derrière elle une
    /// COMÈTE, pas une barre — un halo large et doux, un cœur fin et vif.
    private func corpsIndice(parait: Double, anneau: Double,
                             monte: Double, part: Double) -> some View {
        let vie = parait * part
        let y = -64 * monte + 6 * (1 - parait)
        // Le contact : une bosse — rien avant, rien après.
        let bosse = 4 * anneau * (1 - anneau)
        // La comète part de la pulpe et s'allonge vers le BAS pendant la
        // montée — son pied reste où la main a touché.
        let longueur = 8 + 60 * monte
        let traine = vie * sstepB(0.04, 0.30, monte)
        return ZStack {
            // LA COMÈTE — le halo large…
            Capsule()
                .fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.45), location: 0.3),
                        .init(color: .white.opacity(0.45), location: 0.7),
                        .init(color: .white.opacity(0), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 10, height: longueur)
                // Les rayons de flou retombent à 0 EXACT quand la comète dort
                // (55 % de la boucle) : la loi d'ArriveeFloue.
                .blur(radius: traine > 0.005 ? 5 : 0)
                .blendMode(.plusLighter)
                // Ancrée sur la PULPE (x −5 après la rotation de −8°, y −19
                // pour un glyphe de 40 pt), pas sur la paume.
                .offset(x: -5, y: y - 19 + longueur / 2)
                .opacity(traine * 0.8)
            // …et son cœur.
            Capsule()
                .fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white, location: 0.35),
                        .init(color: .white, location: 0.7),
                        .init(color: .white.opacity(0), location: 1)
                    ],
                    startPoint: .top, endPoint: .bottom))
                .frame(width: 2, height: longueur)
                .blur(radius: traine > 0.005 ? 0.8 : 0)
                .blendMode(.plusLighter)
                .offset(x: -5, y: y - 19 + longueur / 2)
                .opacity(traine)
            // LE CONTACT — le disque doux d'Apple, et son anneau fin, sous la
            // pulpe du doigt.
            Circle()
                .fill(Color.white.opacity(0.16 * bosse * vie))
                .frame(width: 22 + 30 * anneau, height: 22 + 30 * anneau)
                .blur(radius: bosse > 0.005 ? 3 : 0)
                .offset(x: -5, y: -18)
            Circle()
                .stroke(Color.white.opacity(0.55 * bosse * vie), lineWidth: 1)
                .frame(width: 22 + 30 * anneau, height: 22 + 30 * anneau)
                .offset(x: -5, y: -18)
            // LA MAIN et sa lumière.
            ZStack {
                main
                    .foregroundStyle(Color.white.opacity(0.32))
                    .blur(radius: vie > 0.005 ? 10 : 0)
                    .blendMode(.plusLighter)
                // « Plus fine, et de dégradé blanc encore plus » : le fondu
                // commence dès le tiers haut — la pulpe et le doigt sont
                // pleins, la paume s'efface déjà.
                main
                    .foregroundStyle(LinearGradient(
                        stops: [
                            .init(color: .white, location: 0),
                            .init(color: .white, location: 0.30),
                            .init(color: .white.opacity(0), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom))
            }
            .rotationEffect(.degrees(-8))
            .scaleEffect(1 - 0.06 * bosse)
            .offset(y: y)
            .opacity(vie)
        }
        // Du tiers bas du sachet, un peu à droite du centre : elle monte vers
        // le croissant sans jamais le couvrir.
        .offset(x: 18, y: CoteBooster.hauteurSachet * 0.23)
    }

    /// Le glyphe — la main des indices Apple. 34 pt en graisse `.light`
    /// (verdict « la petite main plus fine » : la v4 à 40 pt regular pesait).
    private var main: some View {
        Image(systemName: "hand.point.up.fill")
            .font(.system(size: 34, weight: .light))
    }
}

// MARK: - Le banc

enum BoosterCardBanc {
    /// `-boosterCardFige` — la card naît POSÉE (captures immobiles).
    static let fige = CommandLine.arguments.contains("-boosterCardFige")
    /// `-boosterCardT <s>` — les horloges naissent à `s` (aligne la PHASE de
    /// deux lancements ; elle ne les FIGE pas, les TimelineView tournent).
    static let tFige: Double? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-boosterCardT"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return v
    }()
    /// `-boosterMainPhase <0…1>` — la boucle de la main et du texte CLOUÉE à
    /// cette phase (0,18 = le toucher, 0,45 = la montée avec le filament,
    /// 0,70 = la sortie). Une capture au hasard tombe où elle tombe ; pour
    /// comparer deux robes de main il faut le même instant.
    static let mainPhase: Double? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-boosterMainPhase"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return v
    }()

    /// `-boosterPrise <pt>` — la déchirure CLOUÉE à cette montée (0 / 24 / 48 /
    /// 64 = le seuil) : on ne juge pas un geste au hasard.
    static let priseFige: CGFloat? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-boosterPrise"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return CGFloat(v)
    }()

    /// La phase de la boucle de la main à l'instant `date`, clouée au banc.
    static func phaseMain(_ date: Date, naissance: Date) -> Double {
        if let c = mainPhase { return c }
        let t = date.timeIntervalSince(naissance)
        return t.truncatingRemainder(dividingBy: CoteBooster.periodeIndice)
            / CoteBooster.periodeIndice
    }
}

private func sstepB(_ a: Double, _ b: Double, _ x: Double) -> Double {
    let t = min(max((x - a) / (b - a), 0), 1)
    return t * t * (3 - 2 * t)
}
