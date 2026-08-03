import SwiftUI

// MARK: - Barre d'onglets « monolithe » (design system)

// La barre d'onglets bijou : une capsule d'obsidienne noire, et une pastille
// cerclée d'un fil de métal liquide qui VOYAGE d'un onglet à l'autre et
// EXPLOSE sous le doigt. La matière entière vit dans `navMonolith`
// (Woop/NavMonolith.metal) ; ce fichier ne tient que la géométrie, le ressort
// de la pastille et les icônes.
//
// Son banc de fouettage est `NavLab` (`-navLab`) : c'est là qu'on règle, et
// nulle part ailleurs. Les valeurs retenues sont les défauts de `JewelParams`
// ci-dessous.

/// Les réglages du fil de métal liquide. Tout est ici, rien n'est en dur dans
/// la vue : le banc les fouette au doigt, et la valeur retenue devient le
/// défaut du composant.
struct JewelParams: Equatable {
    /// Densité du train de rayures, mesurée sur la HAUTEUR de la pastille.
    /// Une période et demie du haut au bas du cerne : au-delà, c'est un zèbre ;
    /// en deçà, un croissant de lune.
    var repetition: Double = 0.80
    /// Direction du défilement, en degrés. Quasi vertical : les bandes du
    /// chrome doivent courir à l'HORIZONTALE autour du cerne.
    var angle: Double = 94
    /// Douceur des transitions. HAUT = plus de chrome poli, mais la dispersion
    /// meurt : les franges n'existent que sur des marches raides.
    var softness: Double = 0.20
    /// La compression des rayures au contour — LE cœur de l'effet. À 0, le fil
    /// est un trait plat ; à 1, c'est un fil rond qui reflète un studio.
    var contour: Double = 0.88
    /// Le bruit qui fait onduler le bord (le « liquide » du métal liquide).
    var distortion: Double = 0.42
    /// Vitesse de défilement du train de rayures.
    var speed: Double = 0.20
    /// Décalage du canal rouge — la moitié chaude des éclats. Minuscule : à
    /// 0,03 déjà, le fil entier vire à la bulle de savon. On veut DEUX éclats
    /// sur un fil d'argent, pas un arc-en-ciel qui fait le tour.
    var shiftRed: Double = 0.012
    /// Décalage du canal bleu — la frange froide qui borde l'éclat.
    var shiftBlue: Double = 0.024
    /// Largeur d'influence du champ de bord, en points.
    var influence: Double = 7.0
    /// Dose d'or (0 = chrome nu, 1 = or plein).
    var gold: Double = 0.80
    /// Demi-largeur du fil visible, en points.
    var lineW: Double = 1.05
    /// La buée autour du fil. Courte, sinon c'est du néon.
    var glow: Double = 0.30
    /// Le plancher du métal : ce que le fil renvoie dans ses creux. À 0 il se
    /// lit troué ; c'est ce chiffre qui fait la différence entre un anneau et
    /// une guirlande.
    var floorLevel: Double = 0.30
}

/// Les réglages du bouton play central — le galet noir dans lequel le glyphe
/// est extrudé en laque. Même logique que `JewelParams` : le banc les fouette,
/// la valeur retenue devient le défaut.
struct PlayParams: Equatable {
    /// Rayon du galet, en points. Il DÉBORDE largement de la capsule par le
    /// haut : c'est ce débordement qui le sort du rang des onglets.
    var radius: Double = 33
    /// De combien il remonte au-dessus du centre de la barre.
    var rise: Double = 20
    /// L'air qu'il se réserve de chaque côté dans la barre. Presque rien :
    /// le galet MORD sur ses voisins, il n'attend pas qu'on lui fasse place.
    var gap: Double = 1
    /// Dureté du lobe spéculaire. ÉNORME, et c'est le point : sous ~150 le
    /// glyphe est du métal brossé, au-delà de 300 c'est de l'émail noir.
    var gloss: Double = 696
    /// Largeur du chanfrein du glyphe, en points. C'est sur cette rampe seule
    /// que vit le reflet. Large — un chanfrein étroit donne une arête coupante
    /// de métal ; c'est l'épaisseur qui fait le bourrelet de laque.
    var chamfer: Double = 4.19
    /// Rayon du triangle play, en points.
    var glyph: Double = 11
    /// Le rasant du galet : son anneau extérieur. LE « un peu plus de reflet »
    /// que la barre — elle plafonne à 3 % de spéculaire, lui va bien au-delà.
    var fresnel: Double = 0.239
    /// Demi-largeur de l'anneau de métal liquide.
    var ringW: Double = 1.0
    /// Sa dose. À ZÉRO : l'or de la pastille suffit, un second cercle doré
    /// autour du galet et le bouton devient un jouet. Le galet se tient par
    /// son rasant, pas par un sertissage.
    var ringAmt: Double = 0
    /// La buée courte collée au galet — son sertissage.
    var halo: Double = 0.10
    /// Le SOUFFLE : la lueur permanente du glyphe. Une respiration continue,
    /// jamais un clignotement — un néon qui accroche se lit comme une panne,
    /// pas comme une invitation.
    var breath: Double = 0.72
    /// Sa vitesse. Lent : c'est une braise, pas un cœur qui s'emballe.
    var breathSpeed: Double = 1.0
    /// Combien la lueur dérive vers le BLANC. C'est la TEMPÉRATURE qui varie,
    /// pas la luminosité — beaucoup plus doux à l'œil qu'une pulsation.
    var whiteness: Double = 0.55
    /// L'INVITE : la nappe large et douce autour du galet, celle qui appelle le
    /// doigt avant même qu'on le pose. Le réglage est étroit — trop courte, ce
    /// n'est qu'un contour ; trop forte, c'est du néon.
    var invite: Double = 0.20
    /// L'arrondi du triangle, en fraction de son rayon. Rond, le play cesse de
    /// se lire ; anguleux, il redevient un pictogramme.
    var round: Double = 0.10
}

// MARK: - La barre

/// La barre d'onglets « monolithe » : une capsule d'obsidienne, et une pastille
/// cerclée d'or qui VOYAGE d'un onglet à l'autre. Toute la matière vit dans
/// `navMonolith` (Woop/NavMonolith.metal) ; ici, la géométrie, le ressort de la
/// pastille et les icônes — dessinées en SwiftUI par-dessus, jamais dans le
/// shader : une glyphe SF doit rester nette et lisible par VoiceOver.
struct JewelTabBar: View {
    let items: [(icon: String, label: String)]
    @Binding var selection: Int
    var params: JewelParams = JewelParams()
    /// Le bouton play central. `nil` : la barre d'origine, sans disque, à
    /// slots égaux — le banc s'en sert pour comparer avant/après.
    var play: PlayParams?
    var onPlay: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Marge de débordement : l'ombre portée vit DEHORS, en alpha.
    private static let pad: CGFloat = 40
    /// Retrait de la pastille par rapport à l'arête de la barre. Serré : au
    /// repos la pastille remplit franchement la barre — c'est la proportion de
    /// la référence. Elle n'a plus besoin de place pour grossir depuis que le
    /// shader la laisse SORTIR de la capsule.
    private static let inset: CGFloat = 8
    /// Retrait latéral : la pastille de la référence est plus ramassée qu'un
    /// simple créneau — elle serre la glyphe au lieu de remplir sa case.
    private static let insetX: CGFloat = 14
    /// Durée du voyage de la pastille.
    private static let travel: TimeInterval = 0.42

    // La position de la pastille se mémorise en INDICE DE CASE, jamais en
    // points : la largeur de la barre change entre le premier passage de layout
    // et le suivant (safe area, rotation, insets), et une position figée en
    // points reste alors sur l'ancienne grille — la pastille se retrouve entre
    // deux icônes. L'indice, lui, survit à tout changement de largeur.
    @State private var fromU: CGFloat = -1
    @State private var toU: CGFloat = -1
    @State private var moveStart: Date = .distantPast
    @State private var pressedAt: Date = .distantPast
    @State private var isDown = false
    @State private var dragAt: Date = .distantPast
    @State private var dragging = false
    /// Le dernier battement du geste. Sert de GARDE-FOU : un DragGesture
    /// ANNULÉ — volé par un ScrollView ou par la pagination du TabView —
    /// n'appelle jamais `onEnded`. Sans ce chien de garde, la pastille reste
    /// gonflée à fond pour toujours et le dernier onglet survolé reste
    /// sélectionné. On ne peut pas corriger l'état pendant le rendu ; on lit
    /// donc la péremption au lieu de l'écrire.
    @State private var lastPulse: Date = .distantPast
    /// Le doigt sur le galet : sa propre rampe, indépendante de la pastille.
    @State private var playAt: Date = .distantPast
    @State private var playDown = false
    @State private var playPulse: Date = .distantPast

    /// Le rang devant lequel s'ouvre la fente du galet. Au milieu de la liste :
    /// avec quatre onglets, deux à gauche, deux à droite, et le disque tombe
    /// EXACTEMENT au centre de la barre.
    private var mid: Int { items.count / 2 }

    var body: some View {
        GeometryReader { geo in
            let barW = geo.size.width
            let barH = geo.size.height
            let w = barW + Self.pad * 2
            let h = barH + Self.pad * 2
            // La fente que le galet se réserve. Les onglets se partagent le
            // reste — ils rétrécissent, ils ne se chevauchent jamais.
            let playW = play.map { CGFloat($0.radius * 2 + $0.gap * 2) } ?? 0
            let slot = max(barW - playW, 1) / CGFloat(max(items.count, 1))
            let pillHH = barH * 0.5 - Self.inset
            let pillHW = slot * 0.5 - Self.insetX
            let playR = CGFloat(play?.radius ?? 0)
            let playRise = CGFloat(play?.rise ?? 0)

            // `.topLeading` partout : le rectangle du shader est PLUS GRAND que
            // la barre (marge d'ombre), et un ZStack centré le recentrerait —
            // les icônes partiraient alors d'un demi-`pad` sur la droite,
            // désalignées de la pastille qui, elle, vit dans le shader.
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                        paused: reduceMotion)) { tl in
                    let now = tl.date
                    let t = Float(now.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 900))
                    let m = motion(at: now, slot: slot, playW: playW)
                    let press = pressLevel(at: now)
                    let ignite = playLevel(at: now)
                    let playX = slot * CGFloat(mid) + playW * 0.5

                    Rectangle()
                        .fill(.white)
                        .frame(width: w, height: h)
                        .colorEffect(Self.dithered(ShaderLibrary.navMonolith(
                            .float2(w, h), .float(t), .float(Float(Self.pad)),
                            .float4(Float(m.x), Float(pillHW * m.zoomW),
                                    Float(pillHH * m.zoom), Float(press)),
                            .float4(Float(params.repetition),
                                    Float(params.angle * .pi / 180),
                                    Float(params.softness), Float(params.contour)),
                            .float4(Float(params.distortion), Float(params.speed),
                                    Float(params.shiftRed), Float(params.shiftBlue)),
                            .float4(Float(params.influence), Float(params.gold),
                                    Float(params.lineW), Float(params.glow)),
                            .float(Float(params.floorLevel)),
                            .float4(Float(playX), Float(playRise),
                                    Float(playR), Float(play?.breath ?? 0)),
                            .float4(Float(play?.gloss ?? 0),
                                    Float(play?.chamfer ?? 1),
                                    Float(play?.glyph ?? 1),
                                    Float(play?.fresnel ?? 0)),
                            .float4(Float(play?.ringW ?? 1),
                                    Float(play?.ringAmt ?? 0),
                                    Float(ignite),
                                    Float(play?.halo ?? 0)),
                            .float4(Float(play?.round ?? 0.1),
                                    Float(play?.breathSpeed ?? 1),
                                    Float(play?.whiteness ?? 0.55),
                                    Float(play?.invite ?? 0)))))
                        .offset(x: -Self.pad, y: -Self.pad)
                }
                .allowsHitTesting(false)

                TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                        paused: reduceMotion)) { tl in
                    let clock = tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 900)
                    HStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                            // La fente du galet s'ouvre AVANT l'onglet du
                            // milieu : deux icônes, le disque, deux icônes.
                            if i == mid, playW > 0 {
                                Color.clear.frame(width: playW)
                            }
                            slotView(index: i, item: item, slot: slot, clock: clock)
                        }
                    }
                    .frame(width: barW, height: barH)
                }
                .frame(width: barW, height: barH)
                // Un SEUL geste pour toute la barre : le doigt choisit l'onglet
                // sous lui et peut GLISSER d'une case à l'autre sans lever —
                // la pastille le suit et reste zoomée tant qu'on n'a pas lâché.
                // Quatre gestes par case ne sauraient pas faire ça.
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            // La fente du galet ne sélectionne RIEN : sans ce
                            // filtre, glisser sur le bouton ferait basculer
                            // l'onglet du milieu sous le doigt.
                            guard let i = tabIndex(atX: v.location.x, slot: slot,
                                                   playW: playW) else { return }
                            if selection != i { selection = i }
                            if !isDown { pressedAt = .now; isDown = true }
                            if !dragging { dragAt = .now; dragging = true }
                            lastPulse = .now
                        }
                        .onEnded { _ in
                            pressedAt = .now; isDown = false
                            dragAt = .now; dragging = false
                        }
                )

                // Le galet : sa zone de toucher vit AU-DESSUS de la rangée, donc
                // elle capte le doigt avant elle. Le dessin, lui, est entièrement
                // dans le shader — ici il n'y a qu'un disque transparent.
                if play != nil {
                    Circle()
                        .fill(.clear)
                        .frame(width: playR * 2, height: playR * 2)
                        .contentShape(.circle)
                        .position(x: barW * 0.5, y: barH * 0.5 - playRise)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !playDown { playAt = .now; playDown = true }
                                    playPulse = .now
                                }
                                .onEnded { _ in
                                    playAt = .now; playDown = false
                                    onPlay()
                                }
                        )
                        .accessibilityLabel("Démarrer une séance")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onPlay() }
                }
            }
            .frame(width: barW, height: barH, alignment: .topLeading)
            .onAppear {
                // Premier rendu : la pastille est DÉJÀ en place, elle n'arrive
                // pas en glissant depuis la gauche.
                fromU = CGFloat(selection); toU = CGFloat(selection)
            }
            .onChange(of: selection) { _, _ in
                let target = CGFloat(selection)
                guard target != toU else { return }
                fromU = motion(at: .now, slot: slot, playW: playW).u
                toU = target
                moveStart = .now
            }
        }
        // Un choc FRANC, pas le petit clic de sélection : la pastille est un
        // objet lourd qui se pose, le doigt doit le sentir arriver.
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1.0), trigger: selection)
    }

    private func slotView(index i: Int, item: (icon: String, label: String),
                          slot: CGFloat, clock: TimeInterval) -> some View {
        let active = i == selection
        // Le blanc de l'onglet actif n'est pas UN blanc. Il dérive entre un
        // ivoire chaud et un blanc de projecteur froid, sur deux périodes
        // incommensurables — l'œil y lit une source de lumière, jamais une
        // couleur choisie. Un blanc fixe, à côté, a l'air éteint.
        let warm = 0.5 + 0.5 * sin(clock * 0.83)
        let cool = 0.5 + 0.5 * sin(clock * 0.57 + 1.7)
        let lit = Color(red: 1.0,
                        green: 0.966 + 0.034 * warm,
                        blue: 0.926 + 0.074 * cool)
        return Image(systemName: item.icon)
            .font(.system(size: 19, weight: active ? .semibold : .regular))
            .foregroundStyle(active ? lit : Color.inkMuted)
            // Le halo respire avec la teinte : c'est la lampe qui palpite, pas
            // une ombre portée qui grossit.
            .shadow(color: .white.opacity(active ? 0.20 + 0.18 * warm : 0),
                    radius: active ? 5 + 3 * cool : 0)
            .frame(width: slot)
            .frame(maxHeight: .infinity)
            .animation(.easeOut(duration: 0.22), value: active)
            .accessibilityLabel(item.label)
            .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { selection = i }
    }

    /// Où en est la pastille, et de combien elle s'étire. Le ressort est intégré
    /// ici plutôt que confié à `withAnimation` : un uniform de shader n'est pas
    /// animable par SwiftUI, mais la timeline nous donne l'instant à chaque
    /// image — autant s'en servir.
    /// L'onglet sous l'abscisse `x`, ou `nil` si le doigt est dans la fente du
    /// galet — elle n'appartient à personne.
    private func tabIndex(atX x: CGFloat, slot: CGFloat, playW: CGFloat) -> Int? {
        let leftEnd = slot * CGFloat(mid)
        if playW > 0, x >= leftEnd, x < leftEnd + playW { return nil }
        let shifted = x < leftEnd ? x : x - playW
        return min(max(Int(shifted / max(slot, 1)), 0), items.count - 1)
    }

    private func motion(at date: Date, slot: CGFloat, playW: CGFloat)
        -> (x: CGFloat, u: CGFloat, zoom: CGFloat, zoomW: CGFloat) {
        // La pastille TRAVERSE la fente du galet au lieu de sauter par-dessus :
        // l'offset s'ouvre linéairement sur le dernier pas avant le milieu.
        // Elle passe donc DERRIÈRE le disque — qui la couvre, puisqu'il est
        // peint après elle dans le shader.
        func point(_ u: CGFloat) -> CGFloat {
            slot * (u + 0.5)
                + playW * min(max(u - CGFloat(mid) + 1, 0), 1)
        }
        guard fromU >= 0, toU >= 0 else {
            let u = CGFloat(selection)
            return (point(u), u, 1, 1)
        }
        if reduceMotion { return (point(toU), toU, 1, 1) }
        let u = min(max(date.timeIntervalSince(moveStart) / Self.travel, 0), 1)
        let v = u - 1
        // easeOutBack : la pastille dépasse d'un cheveu puis se pose. C'est ce
        // dépassement, et lui seul, qui fait un objet lourd plutôt qu'un fondu.
        let c1 = 1.70158, c3 = c1 + 1
        let e = 1 + c3 * v * v * v + c1 * v * v
        let cur = fromU + (toU - fromU) * e

        // Le zoom monte à ×1,38 : la pastille passe de 48 à 66 pt sous le doigt
        // et déborde d'un cheveu de la capsule. Le shader ne la clippe plus à
        // la barre — ce léger débordement suffit à la faire DÉCOLLER, alors
        // qu'une pastille bien plus grosse cessait d'être un onglet.
        //
        // La LARGEUR ne suit qu'aux deux tiers : à plein régime, une croissance
        // uniforme ferait une saucisse qui avale deux cases. En montant moins
        // vite en largeur qu'en hauteur, la pastille s'ARRONDIT — une bulle qui
        // se soulève plutôt qu'un rectangle qu'on tire.
        let bump = 0.10 * sin(.pi * u)
        let zoom = 1 + bump + 0.28 * dragLevel(at: date)
        let zoomW = 1 + (zoom - 1) * 0.62
        return (point(cur), cur, zoom, zoomW)
    }

    /// La tenue du doigt qui traîne : 0 lâché, 1 en glisse. Montée vive à la
    /// prise, retombée plus lente au dépôt.
    private func dragLevel(at date: Date) -> Double {
        let (down, ref) = held(at: date, flag: dragging, since: dragAt)
        let dur = down ? 0.13 : 0.30
        let raw = min(max(date.timeIntervalSince(ref) / dur, 0), 1)
        let eased = raw * raw * (3 - 2 * raw)
        return down ? eased : 1 - eased
    }

    /// Le doigt est-il ENCORE là ? Un geste vivant bat à chaque image ; passé
    /// `stale`, on considère qu'il a été annulé et on fait retomber la rampe
    /// depuis l'instant du dernier battement.
    private static let stale: TimeInterval = 0.18
    private func held(at date: Date, flag: Bool, since: Date) -> (Bool, Date) {
        guard flag else { return (false, since) }
        let quiet = date.timeIntervalSince(lastPulse)
        if quiet > Self.stale { return (false, lastPulse.addingTimeInterval(Self.stale)) }
        return (true, since)
    }

    /// La rampe du doigt : 0 au repos, 1 posé. Montée vive, retombée plus lente.
    private func pressLevel(at date: Date) -> Double {
        let (down, ref) = held(at: date, flag: isDown, since: pressedAt)
        let dur = down ? 0.10 : 0.26
        let raw = min(max(date.timeIntervalSince(ref) / dur, 0), 1)
        let eased = raw * raw * (3 - 2 * raw)
        return down ? eased : 1 - eased
    }

    /// L'allumage du galet. Il s'allume PLUS VITE qu'il ne s'éteint — un
    /// interrupteur claque, une braise met du temps à mourir. C'est cette
    /// dissymétrie, et rien d'autre, qui fait la chaleur de l'objet.
    private func playLevel(at date: Date) -> Double {
        guard play != nil else { return 0 }
        var down = playDown
        var ref = playAt
        if playDown, date.timeIntervalSince(playPulse) > Self.stale {
            down = false
            ref = playPulse.addingTimeInterval(Self.stale)
        }
        let dur = down ? 0.07 : 0.42
        let raw = min(max(date.timeIntervalSince(ref) / dur, 0), 1)
        let eased = raw * raw * (3 - 2 * raw)
        return down ? eased : 1 - eased
    }

    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}
