import SwiftUI
import Observation

// LE GALET-ÉTAPE (§22, réf 2 « LA PASTILLE-BIJOU ») — un ROND parfait,
// l'effet BOUTON à DEUX bordures : anneau externe vif / interstice noir /
// anneau interne discret, la lumière en ARCS INÉGAUX le long des anneaux
// (l'école du liseré fin : lobes en cosinus qui meurent en fondu, jamais
// un anneau égal), dôme de verre fumé sombre. Le peint (`goutteVerre`)
// est une FUMÉE semi-transparente : la lentille native `.clear` vit
// dessous et réfracte la vidéo. L'encre du chiffre vit AU-DESSUS.
//
// La grammaire est MUETTE (LOI 4) : la matière ne meurt jamais (la photo
// est la loi), les états ne jouent que sur une marge fine de gains, la
// taille et la respiration de l'actif. Le refus d'un verrouillé est
// L'IMMOBILITÉ : le press s'avorte à 1 %, les liserés s'allument une
// fois, froid, 0,12 s — un caillou refuse en étant un caillou.

// MARK: - Les états

enum EtapeEtat: Equatable {
    case verrouille          // un caillou d'obsidienne
    case prochain            // verrouillé, mais le glyphe appelle (30 %)
    case actif               // la nacre respire
    case accompli            // la nacre calme
    case parfait             // le souffle d'or dans le liseré
    /// ⚠️ **PASSÉ MAIS NON RÉALISÉ** (26-08). Verdict : « les chiffres doivent
    /// être beaucoup plus éteints, presque fantômes — il doit immédiatement
    /// être compris que cette séance n'a pas été faite ». Il n'existait AUCUN
    /// état pour ça : `etatDe()` ne connaissait que avant / égal / après, donc
    /// un jour raté et un jour réussi rendaient exactement la même pastille.
    case rate
    /// ⚠️ **LE NŒUD-LUNE DU CHAPITRE** (26-08). Verdict : « dans chaque
    /// chapitre, un galet spécial logo Lune, un peu plus gros ; verrouillé il
    /// est sombre et discret, disponible il s'illumine en blanc avec un halo
    /// plus fort ». Il n'en existait qu'UN dans tout le chemin (le nœud-trésor
    /// du 5e écran).
    case lune(dispo: Bool)
    /// LE NŒUD PIÈCE (27-08, audit §4 bis) : l'or en DISQUE — la lune porte
    /// l'or en anneau, la pièce ne porte JAMAIS d'anneau d'or : sa face est
    /// or, son bord reste le cheveu blanc de la famille. Disponible, elle
    /// ouvre la card reward (« +40 pièces ») ; verrouillée, la pièce est en
    /// creux.
    case piece(dispo: Bool)
    /// Un nœud spécial RÉCLAMÉ (lune, trésor ou pièce) : l'or s'éteint, le
    /// glyphe se grave — sinon « Moon Node unlocked » se déclencherait à
    /// chaque lancement (boosters / pièces infinis, audit §4).
    case reclame
}

/// LA DATE D'UN GALET — le jour en grand, le mois sur TROIS lettres.
///
/// ⚠️ Le chemin ne connaissait AUCUNE date : les galets portaient un numéro
/// d'étape 1..10, et `etatDe()` comparait des index. Verdict : « le jour en
/// grand, le mois en dessous, toujours sur 3 lettres » et « le galet en cours
/// montre la vraie date actuelle ».
struct DateGalet: Equatable {
    let jour: Int
    let mois: String

    /// ⚠️ **LE MOIS EST LU CHEZ LA MINI-CARD, PAS REFORMATÉ ICI** — et c'est
    /// un écart que j'ai créé puis mesuré à la capture : mon premier jet
    /// formatait en `en_US`, et le galet affichait « 26 AUG » à dix points de
    /// la mini-card du même jour qui affiche « 26. AOÛT ». Deux dates du même
    /// jour, dans deux langues, sur le même écran.
    ///
    /// La leçon est celle de tout ce chantier : quand deux objets doivent
    /// s'accorder, ils LISENT la même source — ils ne recopient pas la même
    /// intention. `SemaineStrip.mois(_:)` est déjà LE formateur des mois de la
    /// maison ; le jour où la maison passera à l'anglais, les deux suivront
    /// ensemble.
    static func depuis(_ d: Date) -> DateGalet {
        DateGalet(jour: Calendar.current.component(.day, from: d),
                  mois: SemaineStrip.mois(d))
    }
}

// MARK: - La forme de la goutte

/// LA MÊME forme que le shader `goutteVerre` (3 harmoniques + rotation +
/// écrasement), côté SwiftUI — pour la LENTILLE NATIVE qui vit sous le
/// peint. Les deux DOIVENT rester jumelles : un écart = un liseré qui
/// flotte hors du verre.
struct GoutteForme: Shape {
    var graine: Double
    var aspect: CGFloat

    func path(in rect: CGRect) -> Path {
        let s = graine
        let R = rect.width / 2
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rot = 0.0
        var pts: [CGPoint] = []
        for i in 0..<96 {
            let th = Double(i) / 96 * 2 * .pi
            let rho = 1.0   // réf 2 : la pastille est un ROND parfait
            let x = cos(th) * rho
            let ys = sin(th) * rho * aspect
            let xr = cos(-rot) * x - sin(-rot) * ys
            let yr = sin(-rot) * x + cos(-rot) * ys
            pts.append(CGPoint(x: c.x + CGFloat(xr) * R,
                               y: c.y + CGFloat(yr) * R))
        }
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }
}

// MARK: - Le galet

struct GaletEtape: View {
    let etat: EtapeEtat
    /// Le glyphe : un chiffre d'étape laqué (école cadran), ou un croissant
    /// pour les jalons — jamais les glyphes Duolingo.
    var numero: Int? = nil
    var glyphe: String? = nil
    /// La LARGEUR de la goutte (§22 : 60 au repos, 66 pour l'actif, 82
    /// pour le nœud-trésor) — la hauteur en découle par l'écrasement.
    var taille: CGFloat = 60
    /// La graine de forme : chaque goutte du chemin est unique.
    var graine: Double = 0
    /// LA LENTILLE NATIVE — le verre `.clear` qui RÉFRACTE la vidéo qui
    /// bouge dessous (l'orbe, les flammes). Légal ici : le contenu est
    /// DOUX (la loi affinée du 20-08). Sur le noir pur elle est invisible
    /// — les cheveux peints portent la goutte. Coupée hors des écrans
    /// voisins (le budget verre).
    var lentille: Bool = true
    /// LA DATE — quand elle est là, elle REMPLACE le numéro et le glyphe :
    /// un galet qui porte une date ne porte plus un rang.
    var date: DateGalet? = nil
    /// LE JOUET (27-08, point 7 tranché « en mode jouet : on peut les
    /// déplacer partout et ils reviennent à leur place ») : le galet se
    /// porte après un MAINTIEN, suit le doigt au bout d'un élastique, et
    /// revient en ressort au lâcher. `portable` = actif, fait, spécial
    /// disponible — un verrouillé refuse par l'immobilité.
    var portable: Bool = false
    var onTap: () -> Void = {}
    /// La prise et le lâcher, pour le parent (zIndex devant, scroll qui
    /// dort, panneau qui se ferme) — deux appels par port, jamais par image.
    var onPort: (Bool) -> Void = { _ in }

    /// L'écrasement de la goutte : plus large que haute, comme une goutte
    /// posée (la réf « CHAPITRE 1 » : ~0,72), jitté par graine — aucune
    /// goutte n'est tombée pareil.
    static let aspect: CGFloat = 1.0
    private var aspectGoutte: CGFloat {
        Self.aspect
    }

    /// Les horodatages des rampes — un uniform de shader n'est pas
    /// animable par SwiftUI : la timeline fait la pente (école pressLevel).
    @State private var presseDepuis: Date? = nil
    @State private var relacheA: Date = .distantPast
    @State private var refusA: Date = .distantPast
    /// La bouffée de FUMÉE du press (sa demande : « quand on appuie ça
    /// sort de la fumée ») — horodatée, fonction pure du temps.
    @State private var fumeeA: Date = .distantPast
    @State private var doigt: CGPoint = .zero
    /// LE PORT : l'écart à SA place (repart toujours de zéro), et « en
    /// main ». Un @State du galet SEUL — écrit par image pendant le port,
    /// il ne rejoue que cette vue, jamais les 45 autres (la page
    /// ré-évaluée par image).
    @State private var porte: CGSize = .zero
    @State private var enMain = false
    /// LE CHIEN DE GARDE DU PRESS (bug latent confirmé au fouet du 27-08) :
    /// un drag ANNULÉ par le scroll — ou par le port prioritaire — n'appelle
    /// jamais `onEnded`, et `presseDepuis` restait posé : galet enfoncé,
    /// tilté, TimelineView à vie. Un minuteur ne convient pas (un press est
    /// immobile, un DragGesture ne rappelle pas un doigt immobile) : un
    /// `@GestureState` retombe à `false` quand le geste finit OU est annulé
    /// — c'est sa raison d'être. Zéro horloge.
    @GestureState private var tenu = false
    @State private var debutDrag: CGPoint? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le pad du raster : le liseré, son halo et l'ombre vivent au bord —
    /// toute énergie meurt AVANT le bord du pad (le CADRE FANTÔME).
    private var pad: CGFloat { 26 }
    /// `-jouetSonde` : la vie du port en console (contact, PRISE, port,
    /// LÂCHER) — le sim ne pose pas de doigt, l'appareil dit la vérité.
    private static let sondeJouet = CommandLine.arguments.contains("-jouetSonde")

    var body: some View {
        // Un nœud-lune VERROUILLÉ refuse comme un caillou : l'immobilité est
        // la grammaire du refus dans cette maison.
        let verrouille = etat == .verrouille || etat == .prochain
            || etat == .lune(dispo: false) || etat == .piece(dispo: false)
        // La timeline ne tourne que si quelque chose vit : la respiration
        // de l'actif, ou une rampe de press/refus en vol (± une seconde).
        TimelineView(.animation(minimumInterval: nil, paused: pauseTimeline)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let press = rampePress(ctx.date)
            corps(t: t, press: press, verrouille: verrouille)
        }
        .frame(width: taille + 2 * pad, height: taille + 2 * pad)
        // LE JOUET : soulevé (×1,06) et déplacé — posés AVANT contentShape
        // et les gestes (l'ordre du galet du menu), sinon le repère du drag
        // voyage avec la vue qu'il porte.
        .scaleEffect(enMain ? 1.06 : 1)
        .offset(x: porte.width, y: porte.height)
        .animation(.spring(response: 0.32, dampingFraction: 0.7), value: enMain)
        // la zone de tap colle au bouton (Ø + 4) : à 30 pt d'air elle ne
        // vole pas le doigt du voisin.
        .contentShape(Circle().inset(by: pad - 2))
        // LE PORT — prioritaire, mais il ne reconnaît qu'APRÈS le maintien :
        // un swipe rapide né sur le galet reste un scroll (le LongPress
        // échoue au-delà de 10 pt avant t), un tap court reste un tap
        // (le drag bas). `.subviews` pour un galet non portable — jamais
        // `.none`, qui éteindrait aussi le drag bas.
        .highPriorityGesture(portGeste, including: portable ? .all : .subviews)
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($tenu) { _, tenu, _ in tenu = true }
                .onChanged { g in
                    doigt = g.location
                    // remise à plat : un nouveau toucher (startLocation
                    // différent) repart propre même si le précédent est mort
                    // sans onEnded.
                    if debutDrag != g.startLocation {
                        debutDrag = g.startLocation
                        presseDepuis = nil
                    }
                    if presseDepuis == nil {
                        presseDepuis = Date()
                        if !verrouille {
                            fumeeA = Date()
                            UIImpactFeedbackGenerator(style: .medium)
                                .impactOccurred(intensity: 0.85)
                        }
                    }
                }
                .onEnded { g in
                    relacheA = Date()
                    presseDepuis = nil
                    // Un TAP, pas la fin d'un scroll qui passait par là :
                    // au-delà de 12 pt de course, le geste appartient au
                    // défilement.
                    let course = hypot(g.translation.width, g.translation.height)
                    guard course < 12 else { return }
                    if verrouille {
                        // LE REFUS : rien ne bouge. Le liseré s'allume une
                        // fois, froid ; une haptique sèche. C'est tout.
                        refusA = Date()
                        UIImpactFeedbackGenerator(style: .rigid)
                            .impactOccurred(intensity: 0.6)
                    } else {
                        onTap()
                    }
                }
        )
        // le geste est fini OU annulé (scroll, port) : le press se libère
        // sans horloge.
        .onChange(of: tenu) { _, encore in
            if !encore, presseDepuis != nil {
                presseDepuis = nil
                relacheA = Date()
            }
        }
    }

    /// LE PORT : maintien 0,20 s (0,14 était sous tous les seuils de la
    /// maison et dans la durée d'un tap appuyé), puis le doigt emmène le
    /// galet au bout d'un élastique. Le premier rappel `.second(true, nil)`
    /// = « porté, translation zéro » : la prise. Au lâcher : ressort à UN
    /// dépassement — et si la course est restée courte, le TAP est
    /// RÉ-ÉMIS (le port a annulé le drag bas : sans ça tout tap tenu
    /// mourrait — « un LongPress vole le tap », payé trois fois).
    private var portGeste: some Gesture {
        // ⚠️ COORDONNÉES GLOBALES (27-08, « je n'arrive pas à drag ») : en
        // `.local`, le repère du drag est celui de la vue — or la vue BOUGE
        // avec l'offset qu'il produit. Le doigt immobile paraît reculer, la
        // translation se dévore elle-même (≈ 46 % de la course, et l'élastique
        // finit de l'écraser). En global, le repère ne bouge jamais.
        LongPressGesture(minimumDuration: 0.20, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0,
                                           coordinateSpace: .global))
            .onChanged { valeur in
                guard case .second(true, let drag) = valeur else {
                    if Self.sondeJouet, case .first(true) = valeur {
                        print("[JOUET] contact (maintien en cours)")
                    }
                    return
                }
                if Self.sondeJouet {
                    print("[JOUET] port  dx=\(Int(drag?.translation.width ?? 0)) dy=\(Int(drag?.translation.height ?? 0))")
                }
                if !enMain {
                    if Self.sondeJouet { print("[JOUET] PRISE") }
                    enMain = true
                    // le port annule le drag bas sans onEnded : le press se
                    // libère ici (ceinture au @GestureState).
                    presseDepuis = nil
                    relacheA = Date()
                    UIImpactFeedbackGenerator(style: .medium)
                        .impactOccurred(intensity: 0.9)
                    onPort(true)
                }
                if let drag { porte = elastique(drag.translation) }
            }
            .onEnded { valeur in
                var course: CGFloat = 0
                if case .second(true, let drag) = valeur, let drag {
                    course = hypot(drag.translation.width,
                                   drag.translation.height)
                }
                let etaitEnMain = enMain
                if Self.sondeJouet { print("[JOUET] LÂCHER course=\(Int(course)) enMain=\(etaitEnMain)") }
                enMain = false
                withAnimation(reduceMotion
                              ? .easeOut(duration: 0.2)
                              : .spring(response: 0.55, dampingFraction: 0.58)) {
                    porte = .zero
                }
                if etaitEnMain {
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred(intensity: 0.6)
                    onPort(false)
                    // le tap tenu : une seule ouverture, jamais perdue.
                    if course < 12 { onTap() }
                }
            }
    }

    /// L'élastique : 0,85 × d jusqu'à 120 pt, puis une compression
    /// logarithmique — il va « partout », mais il résiste.
    private func elastique(_ t: CGSize) -> CGSize {
        let d = hypot(t.width, t.height)
        guard d > 0.5 else { return .zero }
        let r: CGFloat = d <= 120
            ? 0.85 * d
            : 0.85 * 120 + 60 * log(1 + (d - 120) / 60)
        return CGSize(width: t.width / d * r, height: t.height / d * r)
    }

    private var pauseTimeline: Bool {
        if reduceMotion { return true }
        if enMain { return false }
        if etat == .actif || etat == .parfait { return false }
        if etat == .lune(dispo: true) || etat == .piece(dispo: true) { return false }
        if presseDepuis != nil { return false }
        let now = Date()
        return now.timeIntervalSince(relacheA) > 1.0
            && now.timeIntervalSince(refusA) > 1.0
            && now.timeIntervalSince(fumeeA) > 1.5
    }

    /// La rampe horodatée : montée 0,10 s, descente 0,26 s, en smoothstep —
    /// un interrupteur claque, une matière se repose (école JewelTabBar).
    /// Un verrouillé n'accorde que 1 % : le press s'avorte.
    private func rampePress(_ now: Date) -> Double {
        func lisse(_ u: Double) -> Double {
            let v = min(max(u, 0), 1); return v * v * (3 - 2 * v)
        }
        if let debut = presseDepuis {
            return lisse(now.timeIntervalSince(debut) / 0.10)
        }
        return 1 - lisse(now.timeIntervalSince(relacheA) / 0.26)
    }

    @ViewBuilder
    private func corps(t: Double, press: Double, verrouille: Bool) -> some View {
        let D = taille
        let H = D * aspectGoutte
        let centre = CGPoint(x: pad + D / 2, y: pad + D / 2)
        let pressAmpl = verrouille ? 0.01 : 0.03
        let enfonce = 1 - pressAmpl * press
        // Le souffle de l'actif : la respiration asymétrique de la maison.
        // Le nœud-lune DISPONIBLE respire lui aussi : c'est sa promesse.
        let vivant = (etat == .actif || etat == .parfait
                      || etat == .lune(dispo: true)
                      || etat == .piece(dispo: true)) && !reduceMotion
        let souffle = vivant ? LaunchPebble.breath(t, lag: 0) : 0
        // Le flash froid du refus : une pente qui meurt en 0,12 s.
        let refus = max(0, 1 - Date(timeIntervalSinceReferenceDate: t)
            .timeIntervalSince(refusA) / 0.12)

        // ⚠️ **LE HALO DE L'ACTIF, ET IL VIT DANS LE GALET** (26-08). Verdict :
        // « le jour sélectionné doit être beaucoup plus identifiable — halo
        // blanc élégant, lumière interne, petite réaction au tap ». Il n'avait
        // AUCUN halo : le seul du chemin était posé par la page, et seulement
        // quand le panneau de départ était ouvert. Entre deux galets, les gains
        // du shader vont de 0,85 à 1,0 et l'encre de 0,85 à 1,0 : à l'œil, rien
        // ne distinguait le jour d'aujourd'hui de la veille.
        //
        // Il vit ICI et pas dans la page, pour la même raison que la pastille
        // vit dans sa card : un halo qui n'est pas DE l'objet se décale du sien
        // au premier scroll. Il RESPIRE avec lui (la même horloge, aucune
        // seconde), et il grossit sous le doigt — c'est ça, la réaction au tap.
        // ⚠️ MESURÉ, PAS ESTIMÉ. Premier réglage à 0,30 : sonde sur capture,
        // l'anneau de l'actif rendait 61,7 de luminance contre 59,5 et 52,7
        // pour ses voisins accomplis — **+4 %**, c'est-à-dire rien. L'encre,
        // elle, tranchait déjà (101,7 contre 62). Un halo « élégant » qui ne
        // se mesure pas n'existe pas : il monte à 0,55, et son plancher de
        // respiration passe de 0,62 à 0,78 — le souffle le fait vivre, il ne
        // doit pas le faire disparaître entre deux battements.
        let halo: Double = {
            switch etat {
            // aujourd'hui : le halo le plus fort du chemin (« je n'arrive pas
            // à distinguer la session de today »)
            case .actif: return 0.72
            case .lune(let dispo): return dispo ? 0.62 : 0
            case .piece(let dispo): return dispo ? 0.35 : 0
            default: return 0
            }
        }()
        // LE HALO EN POINTS ABSOLUS (27-08) : à ×1,5, un halo ∝ Ø couvrait
        // trois voisins (223 pt) — l'inverse de « lumière contrôlée ». L'actif
        // porte le plus large (0,9 Ø ≈ 84 pt : il déborde sans couvrir).
        let haloR: CGFloat = (etat == .actif ? D * 0.9 : max(D * 0.62, 68))
            + 8 * press
        ZStack {
            if halo > 0.001 {
                Circle()
                    .fill(RadialGradient(
                        colors: [.white.opacity(halo * (0.78 + 0.22 * souffle)),
                                 .white.opacity(halo * 0.22), .clear],
                        center: .center, startRadius: D * 0.14,
                        endRadius: haloR))
                    .frame(width: haloR * 2.3, height: haloR * 2.3)
                    .position(centre)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            // Le reflet au sol : la goutte est POSÉE — à peine visible.
            // LE MIROIR DU SOL — la réf : sous chaque goutte, un reflet
            // doux étiré vers le bas sur la dalle noire.
            Ellipse()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.08), .clear],
                    center: .center, startRadius: 0, endRadius: D * 0.42))
                .frame(width: D * 0.88, height: D * 0.30)
                .position(x: centre.x, y: centre.y + H / 2 + D * 0.15)
                .blur(radius: 6)
            Ellipse()
                .fill(RadialGradient(
                    colors: [.white.opacity(0.05), .clear],
                    center: .center, startRadius: 0, endRadius: D * 0.26))
                .frame(width: D * 0.55, height: D * 0.10)
                .position(x: centre.x, y: centre.y + H / 2 + D * 0.05)
                .blur(radius: 3)
            // LA LENTILLE NATIVE — sous le peint : elle plie la vidéo qui
            // passe derrière la goutte (taille CONSTANTE, jamais animée —
            // la loi des bounds vivants).
            // Coupée pendant le port : le verre qui bouge coûte 60 → 14 img/s
            // (la loi mesurée sur le galet du menu, qui troque son verre
            // contre une doublure en transport).
            if lentille && !enMain {
                Color.clear
                    .glassEffect(.clear, in: GoutteForme(graine: graine,
                                                         aspect: aspectGoutte))
                    .frame(width: D, height: D)
                    .position(centre)
            }
            // LA GOUTTE PEINTE — la fumée semi-transparente + les cheveux
            // de lumière du shader `goutteVerre`, AU-DESSUS du natif.
            Rectangle()
                .fill(.white)
                .frame(width: D + 2 * pad, height: D + 2 * pad)
                .colorEffect(goutteShader(souffle: souffle,
                                          press: press, refus: refus))
            // ⚠️ **LE LISERÉ D'ÉTAT — IL N'EXISTAIT PAS** (26-08, verdict
            // n° 5 : « la différence entre accompli / actif / à venir n'est
            // pas assez évidente… les galets futurs doivent avoir des
            // bordures BEAUCOUP plus claires / visibles… on doit comprendre
            // instantanément FAIT / EN COURS / À VENIR sans réfléchir »).
            //
            // Jusqu'ici l'état ne se disait QUE par une marge fine dans la
            // matière (`gainsEtat` : 0,85 contre 0,92 contre 1,0 — trois
            // pouièmes de lumière) et par l'encre. C'est illisible d'un
            // coup d'œil, et c'était le verdict.
            //
            // Le liseré tranche parce qu'il change de NATURE, pas
            // d'intensité :
            //   · À VENIR  → un ANNEAU CLAIR ET CONTINU, la promesse d'un
            //     bouton qu'on n'a pas encore ouvert — c'est le plus visible
            //     des trois bords, exactement ce qu'elle demande ;
            //   · EN COURS → pas d'anneau du tout : l'actif porte déjà son
            //     HALO (il est le seul), deux marqueurs se battraient ;
            //   · FAIT     → un trait fin, sourd, fermé : l'affaire est
            //     classée, il ne réclame plus rien ;
            //   · RATÉ     → rien, comme son encre fantôme ;
            //   · LUNE     → l'or, et lui seul a le droit d'être coloré.
            // (Plus aucun anneau SwiftUI par-dessus le shader — 27-08, sa
            // référence : « moins de liseré parfait partout ». L'or de la
            // lune vit dans les cheveux du shader, `chaud` ≥ 0,9.)
            // LE GLYPHE LAQUÉ — l'encre vit AU-DESSUS du verre peint.
            glypheVue
                .position(x: centre.x, y: centre.y + 1)
        }
        .compositingGroup()
        // LA FUMÉE DU PRESS — trois volutes pâles qui s'échappent du
        // bouton et se dissolvent (l'école Pil-3 B), une bouffée par
        // press, fonction pure du temps.
        .overlay {
            let u = min(max((t - fumeeA.timeIntervalSinceReferenceDate) / 1.3, 0), 1)
            if u > 0 && u < 1 {
                ForEach(0..<3, id: \.self) { i in
                    let ui = min(max(u * 1.4 - Double(i) * 0.12, 0), 1)
                    let derive: CGFloat = [-14, 10, -4][i]
                    Ellipse()
                        .fill(Color(white: 0.88)
                            .opacity(0.24 * (1 - ui) * (ui > 0 ? 1 : 0)))
                        .frame(width: D * (0.30 + 0.45 * ui),
                               height: D * (0.22 + 0.30 * ui))
                        .offset(x: derive * ui + [8, -10, 2][i],
                                y: -H * 0.34 - D * 0.62 * ui)
                        .blur(radius: 5 + 7 * ui)
                }
            }
        }
        .scaleEffect(enfonce)
        // Le micro-tilt vers le doigt — le « légèrement 3D » du brief.
        .rotation3DEffect(
            .degrees(4 * press),
            axis: axeTilt,
            anchor: .center, perspective: 0.6)
    }

    // MARK: la matière par état

    /// Les gains de la goutte (rim, pool, or) — la grammaire reste MUETTE :
    /// l'état se dit par l'intensité de la lumière, jamais par la couleur
    /// (l'or du parfait excepté, dans la nappe basse seulement).
    private var gainsEtat: (rim: Float, pool: Float, chaud: Float) {
        // UNE MATIÈRE PAR ÉTAT (27-08) — rare contre continu : le passé porte
        // le cheveu RARE (gain 0,6, profil resserré), le futur l'anneau
        // CONTINU (plancher haut). Les gains seuls ne pouvaient rien (ils
        // multiplient tout uniformément) : c'est `profilEtat` qui tranche.
        // rim = la clarté des arcs : le futur CLAIR (1,0), le passé SOURD
        // (0,6), le raté presque éteint (0,35). chaud ≥ 0,9 = les cheveux
        // eux-mêmes passent à l'or (la lune disponible, le réclamé) — plus
        // aucun anneau SwiftUI ne s'ajoute par-dessus.
        switch etat {
        case .verrouille: return (0.90, 0.85, 0)
        case .prochain: return (1.0, 0.92, 0)
        case .actif: return (1.0, 1.0, 0)
        case .accompli: return (0.60, 0.90, 0)
        case .parfait: return (0.60, 0.90, 0.5)
        // Le raté ne MEURT pas — la photo reste la loi, la matière ne meurt
        // jamais. Il s'éteint : c'est son ENCRE qui devient fantôme.
        case .rate: return (0.35, 0.80, 0)
        // La lune verrouillée est la plus sombre du chemin ; disponible, ses
        // cheveux sont d'OR — le seul galet coloré, l'or en anneau.
        case .lune(let dispo): return dispo ? (1.0, 1.0, 1.0) : (0.45, 0.72, 0)
        // La pièce : cheveux blancs (l'or vit dans le disque du glyphe).
        case .piece(let dispo): return dispo ? (1.0, 1.0, 0) : (0.45, 0.72, 0)
        // Réclamé : l'or éteint dans les cheveux.
        case .reclame: return (0.45, 0.85, 1.0)
        }
    }

    /// LE LISERÉ D'ÉTAT — voir la note longue dans `corps`. `nil` = pas
    /// d'anneau (l'actif, qui porte son halo ; le raté, qui s'efface).
    ///
    /// ⚠️ **Les valeurs sont hautes exprès.** La leçon du halo du 26-08 est
    /// payée : un premier réglage « élégant » donnait +2,2 de luminance sur
    /// ses voisins, c'est-à-dire RIEN, et il a fallu monter à 0,55 pour
    /// atteindre +32,9. Un bord « à venir » à 0,18 se serait perdu de la même
    /// façon sur une page qui porte du feu.
    /// LE PROFIL DE L'ANNEAU PAR ÉTAT : (plancher, resserré) et la fumée
    /// du dôme — ce que le shader lit pour dire « continu » ou « rare ».
    ///   · futur      → plancher 0,55 (lointain) / 0,70 (prochain), fumée
    ///     0,20 : le verre VIDE à l'anneau continu, la vidéo au travers ;
    ///   · passé      → plancher 0, resserré : le cheveu rare ;
    ///   · actif, spéciaux → le bijou (0,45 / 0,52).
    private var profilEtat: (plancher: Float, serre: Float, fumee: Float) {
        // SA RÉFÉRENCE VAUT POUR TOUS LES ÉTATS (27-08, « plus fin, moins de
        // liseré parfait partout ») : le cheveu RARE partout (resserré = 1),
        // le verre sombre partout (fumée 0,52). L'état se dit par la CLARTÉ
        // des arcs (`gainsEtat`), par un FILET de continuité à peine là pour
        // le futur (« bordures plus visibles » sans anneau plein), par le
        // glyphe (date / flamme / croissant / pièce) et par le halo de
        // l'actif. L'anneau continu et épais du futur — c'était moi, pas elle.
        // ⚠️ L'ACTIF EST L'EXCEPTION (27-08, « je n'arrive pas à distinguer la
        // session de today ») : dans un chemin de cheveux rares, AUJOURD'HUI
        // est le SEUL anneau plein — le bouton-bijou entier (plancher 0,45,
        // lobes du bijou) — et il respire. Tout le reste est rare.
        switch etat {
        case .verrouille:          return (0.08, 1, 0.52)
        case .prochain:            return (0.12, 1, 0.52)
        case .actif:               return (0.45, 0, 0.52)
        case .accompli, .parfait:  return (0, 1, 0.52)
        case .rate:                return (0, 1, 0.52)
        case .lune(let dispo):     return (dispo ? 0.14 : 0, 1, 0.52)
        case .piece(let dispo):    return (dispo ? 0.14 : 0, 1, 0.52)
        case .reclame:             return (0.06, 1, 0.52)
        }
    }

    private var axeTilt: (x: CGFloat, y: CGFloat, z: CGFloat) {
        // L'axe perpendiculaire au vecteur centre→doigt : le galet
        // s'incline vers le point de contact.
        let c = CGPoint(x: pad + taille / 2, y: pad + taille / 2)
        let vx = doigt.x - c.x, vy = doigt.y - c.y
        let n = max(1, sqrt(vx * vx + vy * vy))
        return (x: vy / n, y: -vx / n, z: 0)
    }

    @ViewBuilder private var glypheVue: some View {
        // La réf : des chiffres BLANCS, droits, poids moyen — jamais
        // rounded (le chiffre de la réf est un SF droit).
        let laque = LinearGradient(
            colors: [Color(white: 0.92), Color(white: 0.74)],
            startPoint: .top, endPoint: .bottom)
        let alpha: Double = {
            switch etat {
            case .verrouille: return 0.85
            case .prochain: return 0.90
            case .actif: return 1.0
            case .accompli, .parfait: return 0.92
            // ⚠️ **PRESQUE FANTÔME** : 0,22 contre 0,92 pour un jour réussi.
            // C'est un rapport de QUATRE — au verdict, « beaucoup plus
            // éteints » ne se joue pas sur une marge fine. La matière, elle,
            // reste : ce n'est pas un trou dans le chemin, c'est un jour
            // qu'on n'a pas rempli.
            case .rate: return 0.22
            case .lune(let dispo): return dispo ? 1.0 : 0.42
            case .piece(let dispo): return dispo ? 1.0 : 0.42
            case .reclame: return 0.45
            }
        }()
        // L'or du glyphe : la lune disponible et la pièce disponible sont
        // les seuls glyphes colorés du chemin ; réclamé, l'or est sourd.
        let or = LinearGradient(
            colors: [FlammePalette.or, FlammePalette.or.opacity(0.72)],
            startPoint: .top, endPoint: .bottom)
        let dore: Bool = {
            switch etat {
            case .lune(let d), .piece(let d): return d
            case .reclame: return true
            default: return false
            }
        }()
        Group {
            if let d = date {
                // LE JOUR EN GRAND, LE MOIS SUR TROIS LETTRES DESSOUS.
                // L'interlettrage du mois est la grammaire des sur-titres de
                // la maison ; son corps est le tiers du jour, pas la moitié —
                // c'est le JOUR qu'on lit à distance.
                VStack(spacing: taille * 0.005) {
                    Text("\(d.jour)")
                        .font(.system(size: taille * 0.34, weight: .medium))
                        .monospacedDigit()
                    Text(d.mois)
                        .font(.system(size: taille * 0.125, weight: .semibold))
                        .tracking(taille * 0.014)
                }
            } else if let g = glyphe {
                // le contour `flame` du futur est un CHEVEU : poids ultra-
                // léger, alpha bas — « translucide mais identifiable ».
                let contour = g == "flame"
                Image(systemName: g)
                    .font(.system(size: taille * 0.26,
                                  weight: contour ? .ultraLight : .regular))
                    .opacity(contour ? 0.45 : 1)
            } else if let n = numero {
                Text("\(n)")
                    .font(.system(size: taille * 0.27, weight: .regular))
            }
        }
        .foregroundStyle(dore ? or : laque)
        .opacity(alpha)
    }

    /// `goutteVerre` — 8 × float2, l'arité au float près (page BLANCHE
    /// sinon). Ra.x est la DEMI-largeur ; la forme vient de la graine, les
    /// états jouent sur les gains ET sur le profil de l'anneau (plancher,
    /// resserré, fumée — `profilEtat`).
    private func goutteShader(souffle: Double, press: Double,
                              refus: Double) -> Shader {
        let R = Float(taille / 2)
        let c = Float(pad + taille / 2)
        let g = gainsEtat
        let p = profilEtat
        // ⚠️ ARITÉ : 8 × float2, exactement celle du shader (page BLANCHE
        // sans erreur sinon).
        return ShaderLibrary.goutteVerre(
            .float2(c, c),
            .float2(R, Float(aspectGoutte)),
            .float2(Float(graine), g.chaud),
            .float2(g.rim, g.pool),
            .float2(Float(press), Float(souffle)),
            // divers.y = LA LARGEUR DU CHEVEU EN POINTS (27-08) : 0,55 pt
            // (= le 0,53 pt d'aujourd'hui à Ø 62, figé) — à ×1,5 une largeur
            // en rr aurait épaissi tout le chemin. Le shader garde son repli
            // 0,017·rr quand il reçoit 0.
            .float2(Float(refus), 0.55),
            .float2(p.plancher, p.serre),
            .float2(p.fumee, 1.0))
    }
}

// MARK: - La mire des matières (`-pillMire`, §20 Pil-1)

/// LA MIRE DES MATIÈRES — les candidats du « à faire » (A natif /
/// B liquidLens / C peint enrichi), le métal sablé v1 (D) et l'actif (E),
/// sur DEUX fonds : le noir pur et le feu (les poses réelles de la page).
/// La question de Pil-1 : « le à-faire : natif, liquidLens ou peint ? »
struct PillMireLab: View {
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 26) {
                Text("SUR LE NOIR").etiquette
                rangee()
                ZStack {
                    HStack(spacing: 0) {
                        Image("duo-feu-blanc-poster").resizable().scaledToFill()
                        Image("duo-feu-rouge-poster").resizable().scaledToFill()
                    }
                    .frame(height: 190).clipped()
                    rangee()
                }
                Text("SUR LE FEU").etiquette
                // §20 Pil-3 — LE PRESS : « quand on appuie, de la fumée ou
                // de la lumière sort ». Les deux candidats, à presser.
                HStack(spacing: 30) {
                    VStack(spacing: 6) {
                        PressDemo(fumee: false)
                        Text("A — la lumière").etiquette
                    }
                    VStack(spacing: 6) {
                        PressDemo(fumee: true)
                        Text("B — la fumée").etiquette
                    }
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .environment(\.colorScheme, .dark)
    }

    private func rangee() -> some View {
        HStack(spacing: 22) {
            VStack(spacing: 6) {
                boutonNatif(date: nil, ame: 0.16)
                Text("à faire").etiquette
            }
            VStack(spacing: 6) {
                boutonNatif(date: "25 AUG", ame: 0.30)
                Text("actif").etiquette
            }
            VStack(spacing: 6) {
                pillMetal(date: "12 JUN", taille: 76)
                Text("fait — métal").etiquette
            }
        }
    }

    /// LE BOUTON NATIF NOURRI (son verdict Pil-1 : « on part en natif,
    /// mais on doit VOIR que c'est un bouton ») — le verre à jeun rendait
    /// un trou : on le NOURRIT (une âme peinte dessous, qu'il réfracte),
    /// et on lui donne le corps d'un bouton Duolingo : le FLANC épais
    /// sous la face, l'ombre portée de l'élévation. L'encre vit AU-DESSUS
    /// du verre, jamais dedans (la loi de la molette).
    private func boutonNatif(date: String?, ame: Double) -> some View {
        let D: CGFloat = 76
        return ZStack {
            // l'ombre portée : le bouton est POSÉ sur la page
            Ellipse()
                .fill(Color.black.opacity(0.6))
                .frame(width: D * 0.92, height: D * 0.30)
                .offset(y: D * 0.50)
                .blur(radius: 7)
            // le flanc : l'épaisseur que le press mangera
            Circle()
                .fill(Color(white: 0.055))
                .frame(width: D, height: D)
                .offset(y: 5)
            // l'âme : ce que le verre réfracte — la nacre qui nourrit
            Circle()
                .fill(RadialGradient(
                    stops: [
                        .init(color: Color(white: ame + 0.14), location: 0),
                        .init(color: Color(white: ame), location: 0.55),
                        .init(color: Color(white: ame * 0.55), location: 1),
                    ],
                    center: UnitPoint(x: 0.42, y: 0.36),
                    startRadius: 0, endRadius: D * 0.62))
                .frame(width: D - 2, height: D - 2)
            Ellipse()
                .fill(Color.white.opacity(0.20))
                .frame(width: D * 0.55, height: D * 0.30)
                .offset(x: -D * 0.10, y: -D * 0.22)
                .blur(radius: 6)
            // LA FACE DE VERRE NATIF — elle a maintenant de quoi vivre
            Circle()
                .fill(Color.clear)
                .glassEffect(.clear, in: Circle())
                .frame(width: D, height: D)
            // l'encre AU-DESSUS du verre
            if let date {
                Text(date)
                    .font(.system(size: D * 0.20, weight: .bold,
                                  design: .rounded))
                    .kerning(0.6)
                    .foregroundStyle(LinearGradient(
                        colors: [Color(white: 1.0), Color(white: 0.80)],
                        startPoint: .top, endPoint: .bottom))
            }
        }
        .frame(width: D + 24, height: D + 24)
    }

    /// D — LE MÉTAL SABLÉ v1 : le shader `pillMetal` + le NÉON blanc
    /// autour du noir (anneau fin) + la DATE gravée en creux (l'emboss :
    /// encre sombre, lumière sur la lèvre basse).
    private func pillMetal(date: String, taille: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 0.08)) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate)
            let pad: CGFloat = 12
            ZStack {
                // le bouton est POSÉ : l'ombre de l'élévation + le flanc
                Ellipse()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: taille * 0.92, height: taille * 0.30)
                    .offset(y: taille * 0.50)
                    .blur(radius: 7)
                Circle()
                    .fill(Color(white: 0.04))
                    .frame(width: taille, height: taille)
                    .offset(y: 5)
                Rectangle()
                    .fill(.white)
                    .frame(width: taille + 2 * pad, height: taille + 2 * pad)
                    .colorEffect(ShaderLibrary.pillMetal(
                        .float2(Float(pad + taille / 2), Float(pad + taille / 2)),
                        .float2(Float(taille / 2), t),
                        .float2(0.016, 0.8)))
                // LE NÉON BLANC autour du noir — fin, calme, constant.
                Circle()
                    .stroke(Color.white.opacity(0.75), lineWidth: 1.4)
                    .frame(width: taille + 1, height: taille + 1)
                    .blur(radius: 0.6)
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 4)
                    .frame(width: taille + 3, height: taille + 3)
                    .blur(radius: 3.5)
                // LA DATE GRAVÉE : l'encre enfoncée, la lèvre basse allumée.
                Text(date)
                    .font(.system(size: taille * 0.20, weight: .bold,
                                  design: .rounded))
                    .kerning(0.8)
                    .foregroundStyle(Color(white: 0.04))
                    .shadow(color: .white.opacity(0.30), radius: 0.4, y: 0.8)
            }
        }
        .frame(width: taille + 24, height: taille + 24)
    }
}

private extension Text {
    var etiquette: some View {
        self.font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.45))
    }
}

/// §20 Pil-3 — LE PRESS DU BOUTON : au maintien la lumière s'accumule
/// sous la face (l'énergie), au relâcher elle S'ÉCHAPPE — en bloom (A) ou
/// en volutes de fumée pâle (B, esquisse). Rampes horodatées, fonctions
/// pures du temps (la maison : un @State par image est interdit).
private struct PressDemo: View {
    let fumee: Bool
    @State private var presseDepuis: Date? = nil
    @State private var relacheA: Date = .distantPast
    @State private var burstA: Date = .distantPast

    var body: some View {
        let D: CGFloat = 84
        TimelineView(.animation(minimumInterval: nil,
                                paused: pauseTimeline)) { ctx in
            let now = ctx.date
            let press = rampe(now)
            let u = burst(now)
            ZStack {
                // l'échappée au relâcher
                if u < 1 {
                    if fumee {
                        volutes(u: u, D: D)
                    } else {
                        Circle()
                            .fill(RadialGradient(
                                colors: [Color(red: 1, green: 0.96,
                                               blue: 0.88).opacity(0.45 * (1 - u)),
                                         .clear],
                                center: .center, startRadius: 0,
                                endRadius: D * (0.7 + 0.8 * u)))
                            .frame(width: D * 2.2, height: D * 2.2)
                            .blendMode(.plusLighter)
                    }
                }
                // la lumière qui s'ACCUMULE au maintien
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.30 * press), .clear],
                        center: .center, startRadius: 0, endRadius: D * 0.9))
                    .frame(width: D * 1.8, height: D * 1.8)
                    .blendMode(.plusLighter)
                corpsBouton(D: D, press: press)
                    .offset(y: 3.5 * press)
            }
            .frame(width: D + 60, height: D + 60)
        }
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if presseDepuis == nil {
                    presseDepuis = Date()
                    UIImpactFeedbackGenerator(style: .medium)
                        .impactOccurred(intensity: 0.85)
                }
            }
            .onEnded { _ in
                relacheA = Date()
                burstA = Date()
                presseDepuis = nil
                UIImpactFeedbackGenerator(style: .light)
                    .impactOccurred(intensity: 0.6)
            })
    }

    private var pauseTimeline: Bool {
        if presseDepuis != nil { return false }
        return Date().timeIntervalSince(burstA) > 1.6
            && Date().timeIntervalSince(relacheA) > 0.5
    }

    private func rampe(_ now: Date) -> Double {
        func lisse(_ v: Double) -> Double {
            let u = min(max(v, 0), 1); return u * u * (3 - 2 * u)
        }
        if let d = presseDepuis { return lisse(now.timeIntervalSince(d) / 0.12) }
        return 1 - lisse(now.timeIntervalSince(relacheA) / 0.30)
    }

    private func burst(_ now: Date) -> Double {
        min(max(now.timeIntervalSince(burstA) / (fumee ? 1.4 : 0.55), 0), 1)
    }

    /// les volutes : trois souffles pâles qui montent et se dissolvent
    private func volutes(u: Double, D: CGFloat) -> some View {
        ForEach(0..<3, id: \.self) { i in
            let fi = Double(i)
            let ui = min(max((u * 1.4 - fi * 0.12), 0), 1)
            let derive: CGFloat = [-14, 10, -4][i]
            Ellipse()
                .fill(Color(white: 0.88).opacity(0.26 * (1 - ui) * (ui > 0 ? 1 : 0)))
                .frame(width: D * (0.30 + 0.45 * ui),
                       height: D * (0.22 + 0.30 * ui))
                .offset(x: derive * ui + [8, -10, 2][i],
                        y: -D * 0.30 - D * 0.75 * ui)
                .blur(radius: 5 + 7 * ui)
        }
    }

    private func corpsBouton(D: CGFloat, press: Double) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.6))
                .frame(width: D * 0.92, height: D * 0.30)
                .offset(y: D * 0.50 - 3.5 * press)
                .blur(radius: 7)
            Circle().fill(Color(white: 0.055))
                .frame(width: D, height: D).offset(y: 5 - 3.5 * press)
            Circle()
                .fill(RadialGradient(
                    stops: [.init(color: Color(white: 0.40), location: 0),
                            .init(color: Color(white: 0.28), location: 0.55),
                            .init(color: Color(white: 0.16), location: 1)],
                    center: UnitPoint(x: 0.42, y: 0.36),
                    startRadius: 0, endRadius: D * 0.62))
                .frame(width: D - 2, height: D - 2)
            Ellipse().fill(Color.white.opacity(0.20))
                .frame(width: D * 0.55, height: D * 0.30)
                .offset(x: -D * 0.10, y: -D * 0.22)
                .blur(radius: 6)
            Circle().fill(Color.clear)
                .glassEffect(.clear, in: Circle())
                .frame(width: D, height: D)
            Text("25 AUG")
                .font(.system(size: D * 0.19, weight: .bold, design: .rounded))
                .kerning(0.6)
                .foregroundStyle(LinearGradient(
                    colors: [Color(white: 1.0), Color(white: 0.80)],
                    startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - La mire (`-duoGalets`)

/// LA MIRE DU GALET-ÉTAPE (§22) : le serpentin RÉEL de l'écran « La
/// braise rouge » (la spec verbatim, jamais une copie), sur le noir de la
/// page, états mélangés comme en situation — 1-3 accomplis, 4 parfait,
/// 5 actif, 6 prochain, le reste verrouillé. La mire EST la vérité.
struct GaletEtapeLab: View {
    @State private var actifTape = 0

    var body: some View {
        GeometryReader { geo in
            let k = geo.size.height / 874.0
            ZStack(alignment: .topLeading) {
                Color.black
                ForEach(EcranSpec.etapes.filter { $0.ecran == 3 }) { e in
                    // « la mire EST la vérité » : les mêmes tailles, les
                    // mêmes glyphes que la route (dates, flamme, croissant,
                    // pièce) — plus des numéros qu'elle ne rend pas.
                    let quel = etatMire(e)
                    GaletEtape(etat: quel,
                               numero: nil,
                               glyphe: e.moon ? "moon.fill"
                                   : (e.piece ? "circle.inset.filled"
                                      : (quel == .prochain || quel == .verrouille
                                         ? "flame" : nil)),
                               taille: e.moon ? 117 : (e.piece ? 80 : 93),
                               graine: Double(e.id),
                               date: dateMire(e, quel),
                               portable: quel == .actif || quel == .accompli
                                   || quel == .parfait,
                               onTap: { actifTape += 1 })
                        .position(x: geo.size.width / 2 + e.dx,
                                  y: e.y * k)
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .environment(\.colorScheme, .dark)
    }

    /// S1 S2 ¢ S3 S4 ☾ S5 S6 ☾ — faits, pièce disponible, parfait, actif,
    /// lune fermée, prochain, verrouillé, trésor fermé.
    private func etatMire(_ e: EcranSpec.EtapeSpec) -> EtapeEtat {
        switch e.n {
        case 0, 1: return .accompli
        case 2: return .piece(dispo: true)
        case 3: return .parfait
        case 4: return .actif
        case 5: return .lune(dispo: false)
        case 6: return .prochain
        case 8: return .lune(dispo: false)
        default: return .verrouille
        }
    }

    private func dateMire(_ e: EcranSpec.EtapeSpec, _ quel: EtapeEtat) -> DateGalet? {
        guard !e.special else { return nil }
        switch quel {
        case .accompli, .parfait, .actif, .rate:
            let jours = [0: -3, 1: -2, 3: -1, 4: 0][e.n] ?? 0
            let d = Calendar.current.date(byAdding: .day, value: jours, to: Date())!
            return DateGalet.depuis(d)
        default: return nil
        }
    }
}
