import SwiftUI
import UIKit

// MARK: - LE RASANT — LA HOME QUAND UNE SÉANCE EST EN COURS (V3, 06-09)
//
// Le plan : `tools/foyer/PLAN-FOYER-V3.md`. La V1 a pris 0/10 (« gros calque »),
// et le calque a été MESURÉ : trois nappes plus larges que l'écran, additionnées
// en plusLighter = un aplat (29,30,34) constant, froid sous un haut chaud.
//
// LES LOIS DE CET ÉCRAN (plan §1 — chacune se vérifie à la pipette) :
//   · UNE SEULE LAMPE : le feu, en bas à GAUCHE (0,34 W). Rien ne brille par le
//     haut. Ce que la lampe n'atteint pas est à #000000 LITTÉRAL.
//   · LE TEST D'EXTINCTION : `-sansFlammes` ⇒ l'écran devient noir sauf l'encre.
//     Un calque survit à l'extinction de sa source ; de la lumière, non.
//   · ROUGE·BLANC·NOIR : l'orange est interdit — corps de feu G/R ≤ 0,22,
//     crêtes blanches ≥ 0,80, R ≥ B partout (le marron mesuré était à 0,52).
//   · LA LOI DE CHUTE : la lumière d'une dalle tombe à ZÉRO avant 40 % de sa
//     hauteur — sinon trois zones tièdes se rejoignent et le calque renaît.
//   · UNE SEULE HORLOGE : la braise. Le chrono est un `Text(timerInterval:)`
//     NATIF (le système avance les chiffres, aucun body ré-évalué). Tout le
//     reste est valeur animable posée UNE fois (skill woop-performance :
//     redessiner coûte 3 à 8 fois plus qu'animer, mesuré A/B sur son iPhone).
//   · UNE SEULE ARÊTE : x = 24. Rien n'est centré.
//
// ⚠️ Le piège maison tient partout ici : un `repeatForever` posé par
// `withAnimation` se fait AVALER si le parent est ré-évalué — chaque phase vit
// dans SA feuille et se réarme par `.task(id:)`.

// MARK: - Le banc

enum FoyerBanc {
    /// `-foyerLab` : l'écran SEUL, à la place de l'app (monté par le châssis —
    /// point de couture, pas encore posé).
    static let actif = CommandLine.arguments.contains("-foyerLab")
    /// `-foyerFige` : tout s'arrête — le squelette de cotes pour le juge.
    static let fige = CommandLine.arguments.contains("-foyerFige")
    /// ⚠️ LE TEST D'EXTINCTION (plan §1.2) : tue TOUTES les couches de feu —
    /// fond, braise, réfractions, lèvre, halos. L'écran doit devenir
    /// LITTÉRALEMENT noir sauf l'encre. La porte de tout verdict.
    static let sansFlammes = CommandLine.arguments.contains("-sansFlammes")
    /// Les barreaux — un moteur arrive toujours avec le sien.
    static let sansChambre = CommandLine.arguments.contains("-sansChambre")
    static let sansFond = CommandLine.arguments.contains("-sansFond")
    static let fondSwiftUI = CommandLine.arguments.contains("-foyerFondSwiftUI")
    static let braisesSwiftUI = CommandLine.arguments.contains("-foyerBraisesSwiftUI")
    static let dallesSwiftUI = CommandLine.arguments.contains("-foyerDallesSwiftUI")
    /// §12.2 — le CRAN ② des flammes (hauteur 56, flou 9) : les deux crans se
    /// montrent côte à côte, elle tranche sur capture.
    static let flammesCran2 = CommandLine.arguments.contains("-foyerCran2")

    /// `-foyerT <secondes>` : le chrono CLOUÉ (24:52 = 1492 · 1:24:10 = 5050).
    static let chronoCloue: Int? = entier("-foyerT")
    /// `-foyerPalier <0…6>` : les séries clouées, pour les sept captures.
    static let palier: Int? = entier("-foyerPalier")

    private static func entier(_ nom: String) -> Int? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: nom), i + 1 < a.count else { return nil }
        return Int(a[i + 1])
    }
}

/// Une tâche annulée ne retire pas une animation `repeatForever` déjà confiée
/// à SwiftUI. La cible revient au repos sans animation quand la page dort ;
/// le prochain réveil peut alors réarmer le même mouvement.
private func poserFoyerSansAnimation(_ mutation: () -> Void) {
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction, mutation)
}

/// Le grand player couvre le Foyer seulement après son arrivée ET son retour
/// éventuel au repos. `PlayerEtat.couvre` décrit déjà l'intention d'ouverture :
/// il ne suffit pas pour arrêter un décor encore visible pendant le mouvement.
@MainActor
@Observable
final class CouvertureFoyer {
    static let shared = CouvertureFoyer()
    private init() {}

    private(set) var recouvert = false
    @ObservationIgnored private var ouverture: UInt = 0
    @ObservationIgnored private var deplacement: UInt = 0
    @ObservationIgnored private var arriveeTerminee = false
    @ObservationIgnored private var deplacementTermine = false

    func commencerOuverture() -> UInt {
        retirer()
        deplacementTermine = true
        return ouverture
    }

    func terminerOuverture(_ jeton: UInt) {
        guard jeton == ouverture else { return }
        arriveeTerminee = true
        recouvert = deplacementTermine
    }

    @discardableResult
    func commencerDeplacement() -> UInt {
        deplacement &+= 1
        deplacementTermine = false
        recouvert = false
        return deplacement
    }

    func terminerDeplacement(_ jeton: UInt) {
        guard jeton == deplacement else { return }
        deplacementTermine = true
        recouvert = arriveeTerminee
    }

    /// Une fermeture ou un démontage invalide aussi les fins d'animations
    /// déjà en attente : aucune ancienne arrivée ne peut endormir le Foyer.
    func retirer() {
        ouverture &+= 1
        deplacement &+= 1
        arriveeTerminee = false
        deplacementTermine = false
        recouvert = false
    }
}

// MARK: - Les cotes — depuis B, jamais depuis l'écran physique

/// ⚠️ `B` = la hauteur RÉELLE du slot de page (709 sur iPhone 15). La racine de
/// `PageCard` vit DANS la zone sûre : coter depuis `UIScreen.bounds.height`
/// (802) pose « Terminer » SOUS la robe, clippé — faute déjà commise une fois.
enum FoyerGeo {
    static let arete: CGFloat = 24

    /// LA PHRASE EST À LA MÊME HAUTEUR QUE LA HOME DE BASE (verdict 14-09) :
    /// 48 pt fixes depuis le haut du slot — la cote de `HomeNuit` (~3471),
    /// pas une fraction. Même arête, même hauteur : c'est LE MÊME BLOC.
    static let phraseHaut: CGFloat = 48
    /// La chambre : trois dalles qui SE RECOUVRENT (y en fraction de B).
    static let w3 = (y: 0.3526, l: 188.0, h: 68.0)
    static let w2 = (y: 0.4175, l: 246.0, h: 84.0)
    static let w1 = (y: 0.4570, l: 312.0, h: 108.0)
    /// Le chrono CHEVAUCHE W1 (greffe des deux juges) : des chiffres nets
    /// devant un objet flou — la profondeur prouvée d'un coup d'œil.
    static let chrono: CGFloat = 0.625
    /// La carte du jour + ticket, au-dessus du chrono.
    static let carte: CGFloat = 0.500
    static let bouton: CGFloat = 0.770
    static let terminer: CGFloat = 0.852
    /// La braise : 150 pt = 21 % de B (verdict 13-09 : « plus GRANDES, au
    /// moins 20 % de la card du bas, plus diffus, blur, moins condensé »).
    /// ⚠️ ÉCART ASSUMÉ, à elle : le rapport flou/hauteur passe à 0,20 (30/150),
    /// AU-DESSUS du 0,16 de la pastille — c'est sa demande explicite (« plus
    /// diffus »), la loi du rapport cède devant son verdict. Moins condensé =
    /// 9 colonnes au lieu de 13. `-foyerCran2` garde l'ancien 72 pour
    /// comparaison.
    static var braiseH: CGFloat { FoyerBanc.flammesCran2 ? 72 : 150 }
}

// MARK: - La chaleur — deux causes, deux leviers, jamais mélangées

enum FoyerChaleur {
    /// Sept paliers GÉOMÉTRIQUES (une suite arithmétique fait lire les trois
    /// derniers comme un seul — mesuré au tapis).
    static let paliers: [Double] = [0.00, 0.17, 0.37, 0.60, 0.76, 0.89, 1.00]

    static func chaleur(series: Int) -> Double {
        let s = FoyerBanc.palier ?? series
        return paliers[min(max(s, 0), paliers.count - 1)]
    }
    /// LES MINUTES portent le PLAFOND de la lumière (fraction de B depuis le
    /// haut) : 0 min → 0,62 · 45 min → 0,42. La lumière MONTE avec la séance.
    static func plafond(minutes: Int) -> CGFloat {
        0.62 - 0.20 * min(1, CGFloat(minutes) / 45)
    }
}

// MARK: - La rampe du feu — rouge · blanc · noir

/// LA copie du dégradé de `BraisesVague` (rampe corrigée le 06-09 : le corps à
/// G/R ≤ 0,22). C'est la MÊME lumière partout — prouvable à la pipette.
enum RampeFeu {
    static let corps = Color(red: 1, green: 0.18, blue: 0.08)
    static let fond = Color(red: 1, green: 0.07, blue: 0.03)
    /// Le blanc chaud des arêtes rasées (G/R 0,86 : famille du blanc).
    static let rase = Color(red: 1, green: 0.86, blue: 0.74)

    static func degrade() -> LinearGradient {
        LinearGradient(stops: [
            .init(color: .white.opacity(0.85), location: 0),
            .init(color: corps.opacity(0.75), location: 0.35),
            .init(color: fond.opacity(0.45), location: 0.75),
            .init(color: .clear, location: 1)
        ], startPoint: .bottom, endPoint: .top)
    }
}

// MARK: - LA CUISSON DU FOND — le grain brossé × l'enveloppe × la cloche

/// Le fond n'est pas une nappe : c'est une MATIÈRE, cuite UNE fois en image —
/// des colonnes de grain vertical (crêtes 4-14/255) que la lumière du feu
/// remonte en fils. Une matière a des creux à zéro : elle ne PEUT pas
/// redevenir un aplat. Ce qui vit ensuite : deux opacités et un rideau —
/// des valeurs animables, zéro redessin.
enum FoyerCuisine {
    private static var cache: [String: UIImage] = [:]

    static func bande(largeur: CGFloat, hauteur: CGFloat) -> UIImage {
        let cle = "\(Int(largeur))x\(Int(hauteur))"
        if let faite = cache[cle] { return faite }
        let neuve = cuire(CGSize(width: largeur, height: hauteur))
        cache[cle] = neuve
        return neuve
    }

    /// ⚠️ Déterministe (un LCG semé, jamais un `random()`) : la même taille
    /// cuit toujours la même image — les captures se comparent au pixel.
    private static func cuire(_ taille: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        let rendu = UIGraphicsImageRenderer(size: taille, format: format)
        return rendu.image { ctx in
            let cg = ctx.cgContext
            var graine: UInt64 = 0x9E37_79B9_7F4A_7C15
            func alea() -> Double {
                graine = graine &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                return Double((graine >> 33) & 0xFF_FFFF) / Double(0xFF_FFFF)
            }
            let W = taille.width, H = taille.height
            let xFoyer = 0.34 * W
            func cloche(_ x: CGFloat) -> Double {
                let d = Double((x - xFoyer) / (0.55 * W))
                return 0.35 + 0.65 * exp(-d * d)
            }
            // L'enveloppe verticale du feu, v = 0 en BAS — avec un stop
            // EXPLICITE à zéro (jamais une queue asymptotique : plan §3).
            let enveloppe: [(v: CGFloat, e: Double)] = [
                (0.00, 1.0), (0.13, 0.74), (0.30, 0.46), (0.51, 0.22),
                (0.72, 0.081), (0.87, 0.022), (1.00, 0.0)
            ]
            // La couleur du fond : le rouge profond de la rampe.
            let rouge = UIColor(red: 1, green: 0.16, blue: 0.07, alpha: 1)
            let espace = CGColorSpaceCreateDeviceRGB()

            var x: CGFloat = 0
            while x < W {
                let largCol = CGFloat(1.0 + alea() * 2.6)
                let crete = (4.0 + alea() * 10.0) / 255.0
                let a0 = crete * cloche(x + largCol / 2)
                var couleurs: [CGColor] = []
                var lieux: [CGFloat] = []
                for (v, e) in enveloppe {
                    couleurs.append(rouge.withAlphaComponent(a0 * e).cgColor)
                    lieux.append(v)
                }
                if let grad = CGGradient(colorsSpace: espace,
                                         colors: couleurs as CFArray,
                                         locations: lieux) {
                    cg.saveGState()
                    cg.clip(to: CGRect(x: x, y: 0, width: largCol, height: H))
                    cg.drawLinearGradient(grad,
                                          start: CGPoint(x: x, y: H),
                                          end: CGPoint(x: x, y: 0),
                                          options: [])
                    cg.restoreGState()
                }
                x += largCol + CGFloat(1.2 + alea() * 2.4)
            }
        }
    }
}

// MARK: - Le fond, monté

private struct FondRasant: View {
    var series: Int
    var minutes: Int
    var dort: Bool

    /// Le souffle du foyer : l'OPACITÉ du calque, 0,86 ↔ 1,00 sur 7,3 s —
    /// jamais un rayon, jamais un redessin.
    @State private var souffle = false
    /// Les deux voiles noirs (§12.4) — des offsets, rien d'autre.
    @State private var voleA = false
    @State private var voleB = false

    var body: some View {
        GeometryReader { g in
            let W = g.size.width, H = g.size.height
            // La bande cuite à sa portée MAXIMALE (plafond 0,42 → 0,58 H de
            // lumière) ; les minutes ne la redessinent jamais : un RIDEAU DE
            // NOIR (soustraction pure, incapable de lever un pixel) découvre
            // la hauteur — son offset est une valeur animable, poussée une
            // fois par palier de minutes.
            let bandeH = H * 0.58
            let eclaire = (1 - FoyerChaleur.plafond(minutes: minutes)) * H
            ZStack(alignment: .bottom) {
                Image(uiImage: FoyerCuisine.bande(largeur: W, hauteur: bandeH))
                    .opacity(0.625 + 0.375 * FoyerChaleur.chaleur(series: series))
                    .animation(.easeInOut(duration: 2.5), value: series)
                rideau(W: W, h: bandeH)
                    .offset(y: -(eclaire - 44))
                    .animation(.easeInOut(duration: 2.5), value: minutes)
                // §12.4 — L'ANIMATION NOIRE : deux voiles de NOIR PUR qui
                // dérivent sur la zone éclairée. Soustraction pure, en blend
                // NORMAL — arithmétiquement incapables de lever un pixel,
                // donc incapables de refaire un calque. Périodes premières
                // entre elles, jamais un métronome.
                voile(W: W, large: W * 0.62, phase: voleA, amp: W * 0.26)
                voile(W: W, large: W * 0.48, phase: voleB, amp: -W * 0.34)
            }
            .frame(width: W, height: H, alignment: .bottom)
            .opacity(souffle ? 1.0 : 0.78)
        }
        .allowsHitTesting(false)
        .task(id: dort) { armer() }
    }

    /// Un voile de noir pur aux bords fondus, qui dérive latéralement sur la
    /// zone éclairée. Blend NORMAL : il ne peut qu'assombrir.
    private func voile(W: CGFloat, large: CGFloat, phase: Bool, amp: CGFloat) -> some View {
        LinearGradient(stops: [
            .init(color: .black.opacity(0), location: 0),
            .init(color: .black.opacity(0.70), location: 0.35),
            .init(color: .black.opacity(0.70), location: 0.65),
            .init(color: .black.opacity(0), location: 1)
        ], startPoint: .leading, endPoint: .trailing)
        .frame(width: large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(x: phase ? amp : -amp * 0.4)
        .allowsHitTesting(false)
    }

    private func rideau(W: CGFloat, h: CGFloat) -> some View {
        LinearGradient(stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: 0.82),
            .init(color: .black.opacity(0), location: 1)
        ], startPoint: .top, endPoint: .bottom)
        .frame(width: W, height: h + 60)
    }

    private func armer() {
        poserFoyerSansAnimation {
            souffle = false
            voleA = false
            voleB = false
        }
        guard !dort, !FoyerBanc.fige else { return }
        withAnimation(.easeInOut(duration: 7.3).repeatForever(autoreverses: true)) {
            souffle.toggle()
        }
        withAnimation(.easeInOut(duration: 31).repeatForever(autoreverses: true)) {
            voleA.toggle()
        }
        withAnimation(.easeInOut(duration: 47).repeatForever(autoreverses: true)) {
            voleB.toggle()
        }
    }
}


/// Les neuf colonnes gardent exactement les niveaux et couleurs de BraisesVague.
/// Hauteur et opacité suivent leurs deux sinus au compositeur ; plus de Canvas
/// ni de reconstruction de la Home à 20 Hz. Le flou commun reste celui du dessin.
private struct BraisesFoyerNatives: UIViewRepresentable {
    var force: Double
    var dort: Bool
    final class Vue: UIView {
        private var colonnes: [CAGradientLayer] = []
        private var configuration = CGSize.zero
        private var forcePosee = Double.nan
        var force: Double = 1
        var dort = true
        private let periodes = [1.9, 2.7, 1.3, 3.1, 1.6, 2.3, 1.1, 2.9, 1.7]
        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false; isUserInteractionEnabled = false
            for _ in periodes {
                let c = CAGradientLayer()
                c.colors = [UIColor.white.withAlphaComponent(0.85).cgColor,
                    UIColor(red: 1, green: 0.18, blue: 0.08, alpha: 0.75).cgColor,
                    UIColor(red: 1, green: 0.07, blue: 0.03, alpha: 0.45).cgColor,
                    UIColor.clear.cgColor]
                c.locations = [0, 0.35, 0.75, 1]
                c.startPoint = CGPoint(x: 0.5, y: 1); c.endPoint = CGPoint(x: 0.5, y: 0)
                c.anchorPoint = CGPoint(x: 0.5, y: 1); c.masksToBounds = true
                colonnes.append(c); layer.addSublayer(c)
            }
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() { super.layoutSubviews(); actualiser() }
        override func didMoveToWindow() { super.didMoveToWindow(); actualiser() }
        func actualiser() {
            guard bounds.width > 0, bounds.height > 0 else { return }
            let change = configuration != bounds.size || forcePosee != force
            let arret = dort || window == nil
            guard change || arret || colonnes[0].animation(forKey: "hauteur") == nil else { return }
            configuration = bounds.size; forcePosee = force
            let pas = bounds.width / CGFloat(colonnes.count)
            let t = Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 900)
            for (i, c) in colonnes.enumerated() {
                let k = periodes[i], ph = Double(i) * 0.8
                func niveau(_ t: Double) -> Double {
                    let a = 0.5 + 0.5 * sin(t * 2 * .pi / k + ph)
                    let b = 0.5 + 0.5 * sin(t * 2 * .pi / (k * 1.7) + ph)
                    return (0.30 + 0.55 * a * (0.55 + 0.45 * b)) * force
                }
                let courant = c.presentation()
                let h = arret && !change ? courant?.bounds.height : nil
                let alpha = arret && !change ? courant?.opacity : nil
                CATransaction.begin(); CATransaction.setDisableActions(true)
                c.bounds = CGRect(x: 0, y: 0, width: pas * 0.80,
                                  height: h ?? bounds.height * niveau(t))
                c.position = CGPoint(x: pas * (CGFloat(i) + 0.5), y: bounds.height)
                c.cornerRadius = pas * 0.4
                c.opacity = alpha ?? Float(niveau(t))
                c.removeAllAnimations()
                CATransaction.commit()
                guard !arret else { continue }
                // 17 périodes du premier sinus = 10 du second : raccord exact.
                let duree = k * 17, n = Int(ceil(duree * 20))
                let valeurs = (0...n).map { niveau(t + duree * Double($0) / Double(n)) }
                for (cle, chemin, echelle) in [("hauteur", "bounds.size.height", Double(bounds.height)),
                                               ("lumiere", "opacity", 1.0)] {
                    let a = CAKeyframeAnimation(keyPath: chemin)
                    a.values = valeurs.map { $0 * echelle }
                    a.duration = duree; a.repeatCount = .infinity; a.calculationMode = .linear
                    c.add(a, forKey: cle)
                }
            }
        }
    }
    func makeUIView(context: Context) -> Vue { Vue(frame: .zero) }
    func updateUIView(_ vue: Vue, context: Context) {
        vue.force = force; vue.dort = dort || FoyerBanc.fige
        vue.actualiser()
    }
    static func dismantleUIView(_ vue: Vue, coordinator: ()) {
        vue.dort = true; vue.actualiser()
    }
}

/// Une dalle se dessine avec son flou une fois à sa configuration courante.
/// Seule sa position dérive ensuite, sans reconstruire ses dégradés et masques.
private struct DalleFoyerNative<Contenu: View>: UIViewRepresentable {
    var contenu: Contenu
    var largeur: CGFloat
    var hauteur: CGFloat
    var flou: CGFloat
    var derive: CGFloat
    var periode: Double
    var dort: Bool
    var signature: String
    @Environment(\.displayScale) private var echelle
    final class Vue: UIImageView {
        var signature = ""
        var derive: CGFloat = 0
        var periode = 1.0
        var dort = true
        override func didMoveToWindow() { super.didMoveToWindow(); actualiser() }
        func actualiser() {
            guard !dort, window != nil else {
                layer.removeAnimation(forKey: "derive"); return
            }
            guard layer.animation(forKey: "derive") == nil else { return }
            let a = CABasicAnimation(keyPath: "transform.translation.x")
            a.fromValue = -derive; a.toValue = derive; a.duration = periode
            a.autoreverses = true; a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(a, forKey: "derive")
        }
    }
    func makeUIView(context: Context) -> Vue {
        let v = Vue(); v.isUserInteractionEnabled = false; v.contentMode = .center
        return v
    }
    func updateUIView(_ vue: Vue, context: Context) {
        let cle = "\(signature)|\(largeur)|\(hauteur)|\(flou)|\(echelle)"
        if vue.signature != cle {
            let rendu = ImageRenderer(content: contenu.frame(width: largeur, height: hauteur)
                .compositingGroup().blur(radius: flou).padding(flou * 3))
            rendu.scale = echelle
            if let image = rendu.uiImage { vue.image = image; vue.signature = cle }
        }
        vue.derive = derive; vue.periode = periode; vue.dort = dort || FoyerBanc.fige
        vue.actualiser()
    }
    static func dismantleUIView(_ vue: Vue, coordinator: ()) {
        vue.dort = true; vue.actualiser()
    }
}

/// Même bande cuite, rideau et deux voiles ; le compositeur porte les trois
/// mouvements permanents. Aucun état SwiftUI n’interpole le fond à chaque image.
private struct FondRasantNatif: UIViewRepresentable {
    var series: Int
    var minutes: Int
    var dort: Bool

    final class Vue: UIView {
        let bande = CALayer()
        let rideau = CAGradientLayer()
        let voiles = [CAGradientLayer(), CAGradientLayer()]
        var series = 0
        var minutes = 0
        var dort = true
        private var taille = CGSize.zero
        private var minutesPosees: Int?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            isUserInteractionEnabled = false
            layer.opacity = 0.78
            layer.addSublayer(bande)
            rideau.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
            rideau.locations = [0, 0.82, 1]
            layer.addSublayer(rideau)
            for voile in voiles {
                voile.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.70).cgColor,
                                UIColor.black.withAlphaComponent(0.70).cgColor, UIColor.clear.cgColor]
                voile.locations = [0, 0.35, 0.65, 1]
                voile.startPoint = CGPoint(x: 0, y: 0.5)
                voile.endPoint = CGPoint(x: 1, y: 0.5)
                layer.addSublayer(voile)
            }
        }
        required init?(coder: NSCoder) { fatalError() }
        override func layoutSubviews() {
            super.layoutSubviews()
            actualiser()
        }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            actualiser()
        }
        func actualiser() {
            guard bounds.width > 0, bounds.height > 0 else { return }
            let W = bounds.width, H = bounds.height, bandeH = H * 0.58
            let nouvelleTaille = taille != bounds.size
            let ancienY = rideau.presentation()?.position.y ?? rideau.position.y
            let ancienneOpacite = bande.presentation()?.opacity ?? bande.opacity
            let opacite = Float(0.625 + 0.375 * FoyerChaleur.chaleur(series: series))
            CATransaction.begin(); CATransaction.setDisableActions(true)
            if nouvelleTaille {
                taille = bounds.size
                bande.contents = FoyerCuisine.bande(largeur: W, hauteur: bandeH).cgImage
                bande.frame = CGRect(x: 0, y: H - bandeH, width: W, height: bandeH)
                for (i, voile) in voiles.enumerated() {
                    let amp = W * (i == 0 ? 0.26 : -0.34)
                    voile.frame = CGRect(x: -amp * 0.4, y: 0,
                                         width: W * (i == 0 ? 0.62 : 0.48), height: H)
                    voile.removeAnimation(forKey: "derive")
                }
            }
            bande.opacity = opacite
            let eclaire = (1 - FoyerChaleur.plafond(minutes: minutes)) * H
            rideau.frame = CGRect(x: 0, y: H - (bandeH + 60) - (eclaire - 44),
                                  width: W, height: bandeH + 60)
            CATransaction.commit()
            if !nouvelleTaille, !dort {
                if minutesPosees != minutes {
                    ponctuelle(rideau, cle: "position.y", de: ancienY, vers: rideau.position.y)
                }
                if abs(ancienneOpacite - opacite) > 0.0001 {
                    ponctuelle(bande, cle: "opacity", de: Double(ancienneOpacite), vers: Double(opacite))
                }
            }
            minutesPosees = minutes
            guard !dort, window != nil else {
                layer.removeAnimation(forKey: "souffle")
                rideau.removeAllAnimations(); bande.removeAllAnimations()
                voiles.forEach { $0.removeAnimation(forKey: "derive") }
                return
            }
            boucle(layer, cle: "souffle", chemin: "opacity", de: 0.78, vers: 1, duree: 7.3)
            for (i, voile) in voiles.enumerated() {
                let amp = W * (i == 0 ? 0.26 : -0.34)
                boucle(voile, cle: "derive", chemin: "transform.translation.x",
                       de: 0, vers: amp * 1.4, duree: i == 0 ? 31 : 47)
            }
        }
        private func boucle(_ cible: CALayer, cle: String, chemin: String,
                            de: Double, vers: Double, duree: Double) {
            guard cible.animation(forKey: cle) == nil else { return }
            let a = CABasicAnimation(keyPath: chemin)
            a.fromValue = de; a.toValue = vers; a.duration = duree
            a.autoreverses = true; a.repeatCount = .infinity
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cible.add(a, forKey: cle)
        }
        private func ponctuelle(_ cible: CALayer, cle: String, de: Double, vers: Double) {
            let a = CABasicAnimation(keyPath: cle)
            a.fromValue = de; a.toValue = vers; a.duration = 2.5
            a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cible.add(a, forKey: cle)
        }
    }
    func makeUIView(context: Context) -> Vue { Vue(frame: .zero) }
    func updateUIView(_ vue: Vue, context: Context) {
        vue.series = series; vue.minutes = minutes
        vue.dort = dort || FoyerBanc.fige
        vue.actualiser()
    }
    static func dismantleUIView(_ vue: Vue, coordinator: ()) {
        vue.dort = true; vue.actualiser()
    }
}

// Le texte parle une fois avec ParoleLigne, puis reste au repos.

// MARK: - Le point de veille

/// Un point de 5 pt qui respire — c'est TOUT l'en-tête. « ● SÉANCE EN COURS »
/// est mort : zéro capitale de section (sa propre règle des chambres), le
/// compte de séries dit déjà que ça tourne.
private struct PointVeille: View {
    var dort: Bool
    @State private var vif = false

    var body: some View {
        Circle()
            .fill(.white)
            .frame(width: 5, height: 5)
            .opacity(vif ? 1.0 : 0.45)
            .task(id: dort) { armer() }
    }
    private func armer() {
        poserFoyerSansAnimation { vif = false }
        guard !dort, !FoyerBanc.fige else { return }
        withAnimation(.easeInOut(duration: 2.9).repeatForever(autoreverses: true)) {
            vif.toggle()
        }
    }
}

// MARK: - La chambre — trois dalles floues, « au milieu, qu'on aperçoit »

/// ⚠️ On ne floute PAS de vraies cards (sans verre elles sont OPAQUES et
/// assombrissent ; avec verre on rallume le poste n°1). Une dalle est une
/// SILHOUETTE : la forme d'un widget, dessinée comme des bords de lumière.
private struct Dalle: View {
    var largeur: CGFloat
    var hauteur: CGFloat
    /// 1,00 (proche) · 0,58 · 0,31 (loin) — module la réfraction.
    var distance: Double
    var flou: CGFloat
    var chaleur: Double
    var feu: Bool
    /// Le chiffre DEVINÉ (W1 seulement) : les dalles ne sont pas de la
    /// décoration, elles portent une information qu'on connaît déjà.
    var fantome: String? = nil
    var deriveX: CGFloat
    var periode: Double
    var dort: Bool

    @State private var vole = false

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: 0.1175 * largeur, style: .circular)
    }

    var body: some View {
        Group {
            if FoyerBanc.dallesSwiftUI {
                ancienCorps
            } else {
                DalleFoyerNative(contenu: corps, largeur: largeur, hauteur: hauteur,
                    flou: flou, derive: deriveX, periode: periode, dort: dort,
                    signature: "\(distance)|\(chaleur)|\(feu)|\(fantome ?? "")")
                    .frame(width: largeur, height: hauteur)
            }
        }
    }

    private var ancienCorps: some View {
        corps
            .frame(width: largeur, height: hauteur)
            // Contenu FIGÉ, UN groupe, UN flou à rayon FIXE — puis seulement
            // des transforms. (⚠️ L'hypothèse « flou figé = payé une fois »
            // n'a jamais été mesurée ici : c'est le J0 du plan.)
            .compositingGroup()
            .blur(radius: flou)
            .offset(x: vole ? deriveX : -deriveX)
            .task(id: dort) { armer() }
    }

    private var corps: some View {
        ZStack(alignment: .bottom) {
            // L'ARÊTE QUE LA LUMIÈRE RASE — seule la lèvre basse brille, et
            // tout tombe à zéro avant 40 % de la hauteur (LA LOI DE CHUTE).
            if feu {
                forme.strokeBorder(
                    LinearGradient(stops: [
                        .init(color: RampeFeu.rase.opacity(0.58), location: 0),
                        .init(color: RampeFeu.rase.opacity(0.08), location: 0.35),
                        .init(color: .clear, location: 0.40),
                        .init(color: .clear, location: 1)
                    ], startPoint: .bottom, endPoint: .top),
                    lineWidth: 1.1)

                // LA RÉFRACTION — la copie du dégradé de la braise qui a
                // TRAVERSÉ le verre : écrasée (un bloc concentre), REMONTÉE
                // de 10 pt (une vitre DÉPLACE l'image — la signature optique),
                // masquée par la forme. Même lumière, prouvable à la pipette.
                RampeFeu.degrade()
                    .frame(width: largeur, height: hauteur)
                    .scaleEffect(y: 0.30, anchor: .bottom)
                    .offset(y: -10)
                    .blur(radius: 16)
                    .opacity(0.40 * distance * (0.55 + 0.45 * chaleur))
                    .blendMode(.plusLighter)
                    .clipShape(forme)
            }
            if let f = fantome {
                Text(f)
                    .font(.inter(62, .semibold))
                    .foregroundStyle(.white.opacity(0.26))
                    .padding(.leading, 22)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func armer() {
        poserFoyerSansAnimation { vole = false }
        guard !dort, !FoyerBanc.fige else { return }
        withAnimation(.easeInOut(duration: periode).repeatForever(autoreverses: true)) {
            vole.toggle()
        }
    }
}

// MARK: - Le chrono

/// ⚠️ `Text(timerInterval:)` NATIF — le système avance les chiffres, notre
/// body n'est JAMAIS ré-évalué. Il ne reste qu'UNE horloge à l'écran : la
/// braise. Le dégradé vertical dit que les chiffres sont éclairés PAR EN
/// DESSOUS — c'est la lampe, jusque dans la typo.
private struct ChronoRasant: View {
    var depuis: Date

    var body: some View {
        chiffre
            .font(.system(size: 80, weight: .ultraLight))
            .monospacedDigit()
            .tracking(-3)
            .foregroundStyle(LinearGradient(
                colors: [.white.opacity(0.96), .white.opacity(0.62)],
                startPoint: .bottom, endPoint: .top))
    }

    @ViewBuilder
    private var chiffre: some View {
        if let s = FoyerBanc.chronoCloue {
            Text(Self.format(s))
        } else {
            Text(timerInterval: depuis...depuis.addingTimeInterval(20 * 3600),
                 countsDown: false)
        }
    }

    static func format(_ s: Int) -> String {
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%d:%02d", m, sec)
    }
}

// MARK: - LA PAGE

/// LE RASANT. Un corps qui est une addition de vues NOMMÉES (le mur du
/// type-checker ne se voit qu'en build propre — payé au commit `337a6e3`).
struct FoyerPage: View {
    var depuisSeance: Date
    /// `Workout.seriesPayantes` — jamais `setCount` (l'écart a coûté un audit).
    var series: Int
    /// Relues sur ÉVÉNEMENT par l'hôte, jamais dérivées dans un corps.
    var minutes: Int
    var arrivee: Double = 1
    /// Le sticker du jour (la mini-card) — fourni par l'hôte depuis la séance.
    var sticker: String = "sticker-flamme"
    var onChoisir: () -> Void = {}
    var onDetail: () -> Void = {}
    var onTerminer: () -> Void = {}

    /// La phrase exige deux liaisons pour un galet qui n'existe plus (02-09) :
    /// jamais lues, elles satisfont la signature.
    @State private var objectifInerte = 4
    @State private var reglageInerte = false
    /// LA PRESSION (verdict 13-09 : « tout l'écran change pour comprendre
    /// qu'on peut afficher l'overlay ») — vraie tant que le doigt est posé
    /// sur la carte ou le chrono : la lumière du feu monte d'un cran PARTOUT.
    /// Trois opacités animables, zéro redessin.
    @State private var presse = false
    /// L'IMPULSION du ticket : une respiration brève toutes les ~9 s — une
    /// boucle à silence (rien ne tourne entre deux impulsions).
    @State private var impulsion = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var pageInactive: Bool {
        RythmeEcran.dortHome || DepartEtat.shared.homeDort
            || CouvertureFoyer.shared.recouvert
            || scenePhase != .active
    }
    private var dort: Bool {
        pageInactive || reduceMotion || ProtectionThermique.shared.ambianceAuRepos
    }
    private var feu: Bool { !FoyerBanc.sansFlammes }
    private var chaleur: Double { FoyerChaleur.chaleur(series: series) }
    private var seriesAffichees: Int { FoyerBanc.palier ?? series }

    var body: some View {
        GeometryReader { geo in
            let B = geo.size.height
            ZStack(alignment: .topLeading) {
                fond
                braises
                chambre(B)
                phraseArrivee(B)
                chronoGeant(B)
                carteJour(B)
                bandeDePrise(B)
                boutonChoisir(geo.size.width, B)
                lienTerminer(geo.size.width, B)
            }
            .frame(width: geo.size.width, height: B, alignment: .topLeading)
        }
    }

    // MARK: les vues nommées

    @ViewBuilder
    private var fond: some View {
        if feu, !FoyerBanc.sansFond {
            Group {
                if FoyerBanc.fondSwiftUI {
                    FondRasant(series: seriesAffichees, minutes: minutes, dort: dort)
                } else {
                    FondRasantNatif(series: seriesAffichees, minutes: minutes, dort: dort)
                }
            }
                // LA PRESSION ALLUME LA PIÈCE — « 10 fois plus marqué »
                // (verdict 14-09) : le fond passe de 0,60 à 1,0 sous le
                // doigt, ET une nappe d'ALLUMAGE monte par-dessus (ci-après).
                // Toujours des opacités animables, zéro redessin.
                .opacity(presse ? 1.0 : 0.60)
                .animation(.easeOut(duration: 0.14), value: presse)
            // L'ALLUMAGE : un dégradé rouge→blanc-chaud, en plusLighter, qui
            // n'existe QUE sous le doigt (0 au repos — il ne coûte rien et ne
            // peut pas refaire un calque : il meurt au relâcher).
            allumage
                .opacity(presse ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.14), value: presse)
        }
    }

    /// L'ALLUMAGE sous la pression : toute la moitié basse s'embrase, du
    /// rouge profond au blanc chaud vers la braise. Rouge·blanc·noir tenu.
    private var allumage: some View {
        GeometryReader { g in
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.38),
                .init(color: RampeFeu.fond.opacity(0.22), location: 0.62),
                .init(color: RampeFeu.corps.opacity(0.42), location: 0.84),
                .init(color: RampeFeu.rase.opacity(0.55), location: 1.0)
            ], startPoint: .top, endPoint: .bottom)
            .frame(width: g.size.width, height: g.size.height)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    /// LA SOURCE — la seule chose de l'écran qui émet. 41 pt, toujours : c'est
    /// sa PORTÉE qui monte avec les minutes (le fond), pas elle. Elle bat sur
    /// le pas commun et dort sous un onglet caché.
    @ViewBuilder
    private var braises: some View {
        if feu {
            Group {
                if FoyerBanc.braisesSwiftUI {
                    BraisesVague(force: (0.62 + 0.20 * chaleur) * (presse ? 2.2 : 1.0),
                                 partBasse: 1.0, colonnes: 9,
                                 flou: FoyerBanc.flammesCran2 ? 11 : 30,
                                 fige: dort || FoyerBanc.fige, hz: 1 / RythmeEcran.pas)
                } else {
                    BraisesFoyerNatives(force: (0.62 + 0.20 * chaleur) * (presse ? 2.2 : 1.0), dort: dort)
                        .blur(radius: FoyerBanc.flammesCran2 ? 11 : 30)
                        .blendMode(.plusLighter)
                }
            }
                .frame(height: FoyerGeo.braiseH)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func chambre(_ B: CGFloat) -> some View {
        if !FoyerBanc.sansChambre {
            Dalle(largeur: FoyerGeo.w3.l, hauteur: FoyerGeo.w3.h,
                  distance: 0.31, flou: 14, chaleur: chaleur, feu: feu,
                  deriveX: 2, periode: 23.7, dort: dort)
                .padding(.leading, FoyerGeo.arete)
                .padding(.top, B * FoyerGeo.w3.y)
            Dalle(largeur: FoyerGeo.w2.l, hauteur: FoyerGeo.w2.h,
                  distance: 0.58, flou: 10, chaleur: chaleur, feu: feu,
                  deriveX: 3, periode: 17.1, dort: dort)
                .padding(.leading, FoyerGeo.arete)
                .padding(.top, B * FoyerGeo.w2.y)
            Dalle(largeur: FoyerGeo.w1.l, hauteur: FoyerGeo.w1.h,
                  distance: 1.00, flou: 6, chaleur: chaleur, feu: feu,
                  deriveX: 3, periode: 13.3, dort: dort)
                .padding(.leading, FoyerGeo.arete)
                .padding(.top, B * FoyerGeo.w1.y)
        }
    }


    /// Nouvelle phrase à chaque visite et toutes les cinq minutes visibles.
    /// Les minutes courantes sont relues immédiatement au retour, sans rattrapage.
    private func phraseArrivee(_ B: CGFloat) -> some View {
        let courantes = max(0, Int(Date().timeIntervalSince(depuisSeance) / 60))
        let etat = courantes < 1 ? "seance_debut" : "seance"
        let mots = PhraseTexte.serveur(etat, nombre: courantes)
            ?? PhraseTexte.fragmentsSeance(minutes: courantes)
        return PhraseVue(p: arrivee, fragments: mots,
                  // Une réplique finie reste possible à « fair », comme les
                  // retours d'appui ; les décors gardent leur repos thermique.
                  paroleActive: !pageInactive,
                  animationParole: !ProtectionThermique.shared.appelAuRepos,
                  etatVoix: etat, nombreVoix: courantes, palierVoix: courantes / 5,
                  objectif: $objectifInerte,
                  reglageOuvert: $reglageInerte)
            .opacity(0.88)
            .padding(.leading, FoyerGeo.arete)
            .padding(.top, FoyerGeo.phraseHaut)
    }

    /// §12.3 — le halo de tap : un dégradé radial PRÉ-PEINT dont seule
    /// l'OPACITÉ flashe au tap (0,12 s à l'attaque, 0,35 s à l'extinction).
    /// Déclenché, jamais en boucle — et AUCUN geste de plus (leçon du mangeur
    /// de nav : le flash vit dans le tap existant).
    /// LA CARTE DU JOUR + LE TICKET (verdict 07-09, sa capture) : la mini-card
    /// datée avec son sticker, EN PETIT, au-dessus du chrono — et le ticket de
    /// papier « N SETS » qui la chevauche. **C'est la porte VISIBLE de
    /// l'overlay des séries** (« il faut un bouton ou un effet de tap pour
    /// comprendre qu'on peut afficher l'overlay ») : un ticket, ça se tire.
    /// Composants de la maison tels quels : `MiniCardJour` (70×78 par défaut)
    /// et `TicketSeries` — le ticket remplace la barre de traits ET le chiffre
    /// fantôme de la dalle (UN seul endroit dit le compte).
    private func carteJour(_ B: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            MiniCardJour(date: depuisSeance, sticker: sticker,
                         stickerBasGauche: true)
            TicketSeries(texte: "\(seriesAffichees) SETS", echelle: 0.82)
                .rotationEffect(.degrees(-4))
                .offset(x: 46, y: 34)
        }
        .scaleEffect(impulsion ? 1.015 : 1.0, anchor: .leading)
        .padding(.leading, FoyerGeo.arete)
        .padding(.top, B * FoyerGeo.carte)
        .task(id: dort) { await battreImpulsion() }
    }

    @State private var haloTap = false

    /// LA PRESSION-PORTE : pose → `presse` (l'écran monte) ; relâcher sans
    /// glisser → le halo, l'haptique, l'overlay. Un `DragGesture(0)` simple —
    /// jamais un `highPriorityGesture` (leçon des deux voleurs de taps).
    /// LA BANDE DE PRISE (verdict 14-09 : « même si je touche à droite de la
    /// carte ou du chrono, ça doit marcher ») — une zone PLEINE LARGEUR, de la
    /// carte au bas du chrono, invisible, qui porte le geste. La carte et le
    /// chrono ne prennent plus le doigt eux-mêmes : la bande le fait pour eux.
    private func bandeDePrise(_ B: CGFloat) -> some View {
        Color.clear
            .frame(height: B * (FoyerGeo.chrono - FoyerGeo.carte) + 88)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(gesteDetail)
            .padding(.top, B * FoyerGeo.carte - 8)
    }

    /// LE GROS HAPTIQUE (verdict 14-09 : « c'est trop beau, rajoute un gros
    /// haptique ») — un coup LOURD à la pose, à l'instant où l'écran
    /// s'allume ; un second, rigide, au relâcher quand l'overlay s'ouvre.
    private static let lourd = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigide = UIImpactFeedbackGenerator(style: .rigid)

    private var gesteDetail: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !presse {
                    presse = true
                    Self.lourd.impactOccurred(intensity: 1.0)
                    Self.lourd.prepare()
                }
            }
            .onEnded { v in
                presse = false
                let d = abs(v.translation.width) + abs(v.translation.height)
                guard d < 12 else { return }
                Self.rigide.impactOccurred(intensity: 1.0)
                withAnimation(.easeOut(duration: 0.12)) { haloTap = true }
                withAnimation(.easeIn(duration: 0.35).delay(0.12)) { haloTap = false }
                onDetail()
            }
    }

    /// L'impulsion du ticket : toutes les ~9,3 s, UNE respiration de 0,7 s —
    /// « ça propose d'ouvrir ». Boucle à silence, réarmée par `.task(id:)`,
    /// morte sous un onglet caché.
    private func battreImpulsion() async {
        poserFoyerSansAnimation { impulsion = false }
        guard !dort, !FoyerBanc.fige else { return }
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(9.3)) }
            catch { return }
            guard !presse else { continue }
            withAnimation(.easeInOut(duration: 0.35)) { impulsion = true }
            do { try await Task.sleep(for: .milliseconds(360)) }
            catch { return }
            withAnimation(.easeInOut(duration: 0.35)) { impulsion = false }
        }
    }

    private func chronoGeant(_ B: CGFloat) -> some View {
        // ⚠️ LE MANGEUR DE NAV, PAYÉ LE 06-09 (banc à vrais touchers, cas 02
        // et 08 : « LE PREMIER TAP EST ENCORE CONFISQUÉ », bissection en 7
        // passes) : ce bloc portait un `highPriorityGesture` — hérité du
        // réflexe « jamais un Button sous un drag d'ancêtre », alors que le
        // Foyer n'a AUCUN drag d'ancêtre (le tirage est démonté en séance).
        // Un geste haute-priorité arbitre au niveau de la FENÊTRE : il
        // battait le tap de la NAV au châssis, et plus rien ne naviguait.
        // Deuxième faute dans la même ligne : le `contentShape` était posé
        // APRÈS les paddings — la zone tactile couvrait tout le rect paddé.
        // → un tap SIMPLE, sur une zone bornée AVANT les paddings.
        ChronoRasant(depuis: depuisSeance)
            .background {
                RadialGradient(colors: [.white.opacity(0.16), .clear],
                               center: .center, startRadius: 0, endRadius: 190)
                    .opacity(haloTap ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
            .padding(.leading, FoyerGeo.arete)
            .padding(.top, B * FoyerGeo.chrono)
    }


    /// Le composant de la maison, pleine colonne — et LA LÈVRE : le feu le
    /// RASE par en dessous, on ne l'éclaire pas.
    private func boutonChoisir(_ W: CGFloat, _ B: CGFloat) -> some View {
        // ⚠️ LE MÊME MOT QUE L'OVERLAY (24-09 : « sur la home noire, mets le
        // wording "add exercise" pour consistance avec l'overlay »). Cet
        // écran-ci n'existe QU'EN SÉANCE — il porte le chrono, les séries et
        // le lien Terminer : « ajouter » y est donc la vérité, comme dans le
        // lecteur. Un même geste ne change plus de verbe selon la porte par
        // laquelle on l'atteint.
        BoutonPrimaire(title: L("Ajouter un exercice", "Add an exercise")) { onChoisir() }
            .overlay {
                if feu {
                    ZStack {
                        // au repos : le fil rasé, discret
                        Capsule().strokeBorder(
                            LinearGradient(stops: [
                                .init(color: RampeFeu.rase.opacity(0.34), location: 0),
                                .init(color: .clear, location: 0.45),
                                .init(color: .clear, location: 1)
                            ], startPoint: .bottom, endPoint: .top),
                            lineWidth: 1)
                        // sous le doigt : L'ANNEAU DE FEU — blanc chaud plein,
                        // 2 pt, et une lueur rouge autour (dégradé pré-peint,
                        // opacité seule — jamais un flou animé)
                        Capsule().strokeBorder(RampeFeu.rase.opacity(0.95), lineWidth: 2)
                            .opacity(presse ? 1.0 : 0.0)
                        Capsule().strokeBorder(RampeFeu.corps.opacity(0.75), lineWidth: 10)
                            .blur(radius: 8)
                            .opacity(presse ? 1.0 : 0.0)
                            .blendMode(.plusLighter)
                    }
                    .frame(height: BoutonPrimaire.hauteur)
                    .animation(.easeOut(duration: 0.14), value: presse)
                    .allowsHitTesting(false)
                }
            }
            .frame(width: W - 2 * FoyerGeo.arete)
            .padding(.leading, FoyerGeo.arete)
            .padding(.top, B * FoyerGeo.bouton)
    }

    /// « Terminer la séance » — un verbe + son objet = une action. Encre
    /// NEUTRE posée sur le sol CHAUD du feu (jamais chaud sur chaud). Pas de
    /// LE STOP DE L'OVERLAY, AU CENTRE (verdict 07-09 : « à la place du
    /// bouton lien terminer tu mets le bouton stop de l'overlay au centre »).
    /// C'est `MedaillonStop`, LE composant du player — le même objet partout,
    /// jamais un mime. Seule exception assumée à l'arête x=24 : elle l'a
    /// demandé centré.
    private func lienTerminer(_ W: CGFloat, _ B: CGFloat) -> some View {
        MedaillonStop(taille: 68, action: onTerminer)
            .frame(maxWidth: .infinity)
            .padding(.top, B * FoyerGeo.terminer)
    }
}

// MARK: - LE BANC : `-foyerLab`

struct FoyerLab: View {
    private let depart = Date().addingTimeInterval(-1492)
    @State private var series = 3
    @State private var minutes = 24
    @State private var arrivee: Double = 0
    @State private var dernier = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            FoyerPage(depuisSeance: depart,
                      series: series,
                      minutes: minutes,
                      arrivee: arrivee,
                      onChoisir: { noter("choisir") },
                      onDetail: { noter("détail") },
                      onTerminer: { noter("terminer") })
            barre
        }
        .preferredColorScheme(.dark)
        .task {
            guard !FoyerBanc.fige else { arrivee = 1; return }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.linear(duration: 1.46)) { arrivee = 1 }
        }
    }

    private var barre: some View {
        VStack(spacing: 6) {
            if !dernier.isEmpty {
                Text(dernier).font(.inter(11)).foregroundStyle(.white.opacity(0.5))
            }
            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { n in
                    Button("\(n)") { series = n; minutes = n * 9 }
                        .font(.inter(12, .semibold))
                        .foregroundStyle(series == n ? .black : .white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(series == n
                                                  ? Color.white
                                                  : Color.white.opacity(0.10)))
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func noter(_ quoi: String) {
        dernier = "tap : \(quoi)"
        print("[FOYER] tap \(quoi)")
    }
}
