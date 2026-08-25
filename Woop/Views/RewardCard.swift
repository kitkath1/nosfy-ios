import SwiftUI

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
enum RewardStyle {
    case halo, neon, galet, spotlight
}

struct RewardPopup: View {
    /// Le chiffre annoncé — les séries effectuées.
    let count: Int
    let title: String
    let subtitle: String
    /// L'unité sous le chiffre — le « Weeks » de la réf.
    let unit: String
    var style: RewardStyle = .halo
    var onClose: () -> Void

    /// L'unique progrès de l'entrée [0,1] — toutes les rampes en dérivent.
    @State private var p: Double = 0
    /// La sortie est engagée : le chiffre reste FIGÉ (un odomètre qui
    /// rejoue 4 → 0 en 0,3 s à l'envers, mesuré au film, fait cheap).
    @State private var enSortie = false
    /// L'entrée est POSÉE. La garde « p == 1 » était MORTE (relecture
    /// adverse) : `withAnimation { p = 1 }` écrit le MODÈLE à 1 dès la
    /// première frame — seule la présentation interpole. Un tap scrim ou
    /// Close en pleine entrée fermait la card, figeait le chiffre en plein
    /// count-up, et la completion jouait quand même boum + arpège dans la
    /// sortie. Le verrou est ce drapeau, posé par la completion.
    @State private var posee = false
    /// L'horloge de la poudre — posée UNE fois au montage (la scène, elle,
    /// renaît à chaque frame de `p` : une Date prise là-bas gèlerait tout).
    @State private var naissance = Date()
    /// Le BOUM de l'atterrissage (verdict « haptique fort ») — se juge au
    /// téléphone, le simulateur ne vibre pas.
    @State private var boum = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        RewardScene(p: p, count: count, title: title, subtitle: subtitle,
                    unit: unit, style: style, naissance: naissance,
                    enSortie: enSortie, fermer: fermer)
            .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0),
                             trigger: boum)
            .onAppear {
                SkyMotion.shared.start(reduceMotion: reduceMotion)
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
                guard CommandLine.arguments.contains("-rewardAuto")
                else { return }
                try? await Task.sleep(for: .seconds(3.6))
                fermer()
            }
    }

    private func fermer() {
        guard posee, !enSortie else { return }
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
    let naissance: Date
    let enSortie: Bool
    var fermer: () -> Void

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    private static let forme = RoundedRectangle(cornerRadius: 36,
                                                style: .continuous)

    var body: some View {
        GeometryReader { g in
            // LA FORME DE LA RÉF, exactement : portrait, ~80 % de la
            // largeur, ratio hauteur/largeur 1,32 (mesuré sur l'image).
            let l = min(g.size.width * 0.80, 332)
            ZStack {
                // Le scrim — PROFOND (verdict « plus foncé derrière ») ;
                // il porte aussi la sortie au tap.
                Color.black.opacity(0.68 * sstep(0, 0.30, p))
                    .onTapGesture { fermer() }
                carte(largeur: l, hauteur: l * 1.32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        // Un MODAL pour VoiceOver : sans ce trait, la page reste
        // navigable et ACTIVABLE derrière le scrim (relecture adverse).
        .accessibilityAddTraits(.isModal)
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
        CarteGyro {
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

                if style == .halo {
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
                    // 4 bis. LE DISQUE DE LA NUIT (réf WWDC, néon seul) —
                    //    la lune sombre derrière le chiffre : à peine plus
                    //    claire que le noir, elle donne sa profondeur au
                    //    bloom. La pill, elle, veut une scène nue.
                    if style == .neon {
                        disqueNuit(largeur: largeur, hauteur: hauteur)
                    }
                    // Et le HALO DE SOL — monté d'un cran (verdict
                    // « augmente le halo ») : la brume dans laquelle les
                    // capitales couchées TREMPENT, en deux nappes.
                    // (Pas en spotlight : là, la nuit est totale — la
                    // seule lumière viendra de la lampe, jalon S3.)
                    if style != .spotlight {
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

                // 5 bis. LA POUDRE DE DIAMANT (verdict) — les grains
                //    naissent dans le halo et scintillent TRANCHÉ, la
                //    recette de PoudreBooster en monochrome lunaire.
                //    (Pas en spotlight : la nuit y est nue, la matière
                //    vit DANS le chiffre.)
                if style != .spotlight {
                    PoudreDiamant(largeur: largeur, hauteur: hauteur,
                                  naissance: naissance)
                        .opacity(sstep(0.35, 0.75, p))
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
                    lineWidth: 2)
                    .opacity(sstep(0.12, 0.45, p))

                // 7. L'ENCRE — au-dessus de tout.
                encre(hauteur: hauteur)
            }
            // Le clip qui ROGNE les fantômes sur les flancs — constant
            // (le verre garde des bounds immobiles, la loi est sauve).
            .clipShape(Self.forme)
        }
        .frame(width: largeur, height: hauteur)
        .scaleEffect(0.96 + 0.04 * sstep(0, 0.55, p))
        .opacity(sstep(0, 0.16, p))
        // L'ombre est BLANCHE et tombe vers le bas (verdict) : sur du noir
        // une ombre noire n'existe pas — c'est la lumière du halo qui
        // continue sous la card et la détache de la page.
        .shadow(color: .white.opacity(0.14 * sstep(0.25, 0.65, p)),
                radius: 38, y: 30)
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

    private func encre(hauteur: CGFloat) -> some View {
        VStack(spacing: 0) {
            // LE BLOC DE TÊTE À L'APPLE (verdict) : titre plein blanc,
            // sous-titre gris discret sur deux lignes, tout centré.
            Text(title)
                .font(.inter(20, .bold))
                .tracking(0.2)
                .foregroundStyle(WoopGradient.silverText)
                .opacity(sstep(0.36, 0.58, p))
                .offset(y: 5 * (1 - sstep(0.36, 0.62, p)))
                .padding(.top, 26)
            Text(subtitle)
                .font(.inter(13.5))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 34)
                .padding(.top, 8)
                .opacity(sstep(0.42, 0.64, p))
                .offset(y: 5 * (1 - sstep(0.42, 0.68, p)))
            Spacer(minLength: 0)
            if style == .neon {
                // UN SEUL BLOC centré : le chiffre S'ASSOIT sur les
                // capitales couchées — pas d'air entre eux (un Spacer
                // entre les deux les aurait écartés).
                VStack(spacing: -30) {
                    ChiffreNeon(valeur: valeurCourante,
                                allume: sstep(0.30, 0.72, p))
                        .opacity(sstep(0.26, 0.44, p))
                    UnitePlate(texte: unit)
                        .padding(.horizontal, 16)
                        .opacity(sstep(0.44, 0.70, p))
                        .offset(y: 8 * (1 - sstep(0.44, 0.74, p)))
                }
            } else if style == .spotlight {
                ChiffreMatrice(valeur: valeurCourante,
                               naissance: naissance)
                    .opacity(sstep(0.26, 0.44, p))
            } else {
                ChiffreReward(valeur: valeurCourante)
                    .opacity(sstep(0.26, 0.44, p))
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
            // L'unité en blanc dans la fumée — halo ET pill (en néon elle
            // vit couchée dans le bloc central).
            if style != .neon {
                Text(unit)
                    .font(.inter(19, .semibold))
                    .foregroundStyle(Color.white.opacity(0.95))
                    .opacity(sstep(0.48, 0.70, p))
                    .offset(y: 5 * (1 - sstep(0.48, 0.74, p)))
            }
            // Le BOUTON LIEN (verdict « pour consistance ») : de l'encre
            // nue, pas de cadre — la zone de toucher reste large.
            Button(action: fermer) {
                Text("Close")
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

    private func sstep(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// LA POUDRE DE DIAMANT — la recette éprouvée de `PoudreBooster` (Canvas
/// sous TimelineView 30 Hz, grains-étoiles déterministes par hash,
/// l'additif demandé AU CONTEXTE, jamais à la vue), passée au monochrome :
/// des facettes blanches et bleu-glace qui ne vivent que dans le halo du
/// bas et scintillent TRANCHÉ.
private struct PoudreDiamant: View {
    var largeur: CGFloat
    var hauteur: CGFloat
    var naissance: Date

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 44 grains à 30 Hz : une broutille pour le Canvas, assez pour que
    /// la poudre existe.
    private static let grains = 44

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
                    let base = 0.60 + 0.36 * Self.hash(i, 3)
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
                    let bas = 0.30 + 0.70 * (base - 0.60) / 0.36
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

    var body: some View {
        let tilt = SkyMotion.shared.tilt
        Text("\(valeur)")
            .font(.inter(190, .medium))
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
        "1280KG", "PR", "W4", "+4KG", "WOOP"
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

/// LE CHIFFRE NÉON (réf WWDC « 1 DAY TO GO ») — le tube blanc-chaud qui
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
private struct GaletVerre: View {
    var naissance: Date

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
            let x = (sin(t * 0.55) * 46 + sin(t * 1.07 + 1.7) * 11) * libre
                + 22 * tilt.dx
            let y = (cos(t * 0.43 + 0.8) * 34 + sin(t * 0.83) * 7) * libre
                + 15 * tilt.dy
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
            .frame(width: 152, height: 152)
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

/// La feuille gyro : elle SEULE relit `SkyMotion` à 30 Hz (le contenu,
/// passé en valeur, se diffe à vide) — la page en dessous n'entend rien.
/// La nappe est une LUMIÈRE posée sur la face (l'effet, sur du noir, vient
/// d'elle) ; l'inclinaison 3D reste un murmure.
private struct CarteGyro<Contenu: View>: View {
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
            .rotation3DEffect(.degrees(2.6 * tilt.dx),
                              axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(-2.2 * tilt.dy),
                              axis: (x: 1, y: 0, z: 0))
    }
}
