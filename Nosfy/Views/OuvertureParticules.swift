import SwiftUI
import MetalKit
import CoreHaptics
import UIKit

// MARK: - L'OUVERTURE (23-09) — elle remplace la flamme noire
//
// « Je veux de la matière, du shader, de l'ouverture magique, avec des
//   milliers de particules inférieures à 0,6 px, like three.js —
//   particules noir, orange, rouge. » (Kathryn, 23-09, après onze refus.)
//
// L'écran se défait en dizaines de milliers de points qui montent,
// s'enroulent et refroidissent du blanc chaud au noir. Derrière eux, un
// voile noir monte, l'écran change dessous, puis tout s'éteint.
//
// ⚠️ POURQUOI ÇA N'EST PAS UNE VUE SwiftUI ANIMÉE. Deux pièges déjà payés
// sur la flamme, tous les deux évités ici par construction :
//   · **SwiftUI n'interpole pas les arguments d'un shader** — un
//     `withAnimation` sur un `@State` passé en uniforme ne produit aucune
//     animation ;
//   · **une vue qui naît n'anime pas** — elle n'a pas de valeur d'avant.
// Ici c'est le RENDU qui tient l'horloge : il lit `CACurrentMediaTime()` à
// chaque image et en déduit l'avancement. SwiftUI ne pilote rien.
//
// ⚠️ AUCUNE PARTICULE N'EXISTE EN MÉMOIRE (voir `Particules.metal`) :
// zéro tampon, zéro allocation par image, un seul appel de dessin.
//
// Son barreau : `-sansOuverture` (le changement se fait tout de suite,
// sans rien par-dessus). `-sansFlamme` et `-sansCoupe` restent des alias :
// ils sont cités dans les plans depuis le 22-09.

enum HaptiqueBanc {
    /// `-sansHaptique` : l'ouverture se joue muette dans la main.
    static let sans = ProcessInfo.processInfo.arguments.contains("-sansHaptique")
}

enum CoupeBanc {
    static let sans = ["-sansOuverture", "-sansFlamme", "-sansCoupe"]
        .contains { ProcessInfo.processInfo.arguments.contains($0) }
}

enum OuvertureBanc {
    /// `-ouvertureLab <p>` : l'ouverture FIGÉE à l'avancement `p`. Une
    /// combustion d'une seconde ne se capture pas au hasard, et le
    /// simulateur ne pose pas de doigt.
    static let fige: Float? = {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-ouvertureLab"), i + 1 < a.count,
              let v = Float(a[i + 1]) else { return nil }
        return v
    }()
    /// `-ouvertureSansGeste` : LE BANC DU CHIEN DE GARDE. Le rendu
    /// n'honore plus rien — on simule exactement la panne qu'on craint (pas
    /// d'appareil Metal, texture absente, app passée en fond). Si le
    /// parcours se termine quand même, c'est que le geste confié n'est
    /// JAMAIS perdu, et donc qu'aucune donnée ne l'est.
    static let sansGeste = ProcessInfo.processInfo.arguments
        .contains("-ouvertureSansGeste")
    /// `-ouvertureBoucle` : elle rejoue sans fin, pour la juger au doigt.
    static let boucle = ProcessInfo.processInfo.arguments
        .contains("-ouvertureBoucle")
    /// `-ouvertureUneFois` : LE BANC DE LA FIN (24-09). Elle joue UNE fois,
    /// cinq secondes après l'arrivée, et rien d'autre. C'est le seul moyen
    /// de prouver en capture que l'écran est PROPRE après le passage — le
    /// défaut qu'elle a photographié le 24-09 (des étincelles et des taches
    /// figées par-dessus le lecteur).
    static let uneFois = ProcessInfo.processInfo.arguments
        .contains("-ouvertureUneFois")
}

/// LE DÉCLENCHEUR. On ne lui demande pas d'animer : on lui donne le geste à
/// faire AU MILIEU, quand le voile tient l'écran. C'est ce qui garantit que
/// le changement ne se voit pas — l'appelant n'a jamais à deviner un délai.
@MainActor
final class CoupeEtat: ObservableObject {
    static let shared = CoupeEtat()
    private init() {}

    @Published fileprivate var top: Int = 0
    private var auMilieu: (() -> Void)?
    private var chien: Task<Void, Never>?
    /// LA PHOTO DE L'ÉCRAN QU'ON QUITTE, prise à l'instant du geste. C'est
    /// elle qui donne aux braises la lumière des vrais pixels — sans elle
    /// on ne voit que de la poussière orange (mesuré le 23-09).
    fileprivate var photo: CGImage?
    /// LE FOYER — le point touché, en fraction d'écran. C'est de lui que
    /// l'ouverture se propage. Par défaut le bas-centre : là où vit le pouce.
    fileprivate var foyer = CGPoint(x: 0.5, y: 0.86)

    /// ⚠️ PLUS LENT QU'AVANT (verdict Kathryn : « plus lent, qu'on voie la
    /// combustion élégamment »). 1,0 s au lieu de 0,64.
    static let duree: Double = 1.5
    /// À quelle fraction l'écran change, sous le voile. ⚠️ Lié au front du
    /// shader : le voile n'est plein partout qu'à 0,60 (voir `voileFragment`).
    static let milieu: Double = 0.62

    // ════════════════════════════════════════════════════════════════════
    // ⚠️⚠️ LA FIN DU PASSAGE SE CALCULE — ELLE NE S'ÉCRIT PAS À LA MAIN.
    //
    // LE DÉFAUT DU 24-09, et il vient d'un nombre en dur. Pour « encore
    // plus d'effet » j'ai donné aux étincelles une vie 2,8 fois plus
    // longue — sans refaire le calcul de la fin, resté à 1,35. À 1,35 les
    // étincelles sont encore VIVANTES, et un `MTKView` qu'on met en pause
    // LAISSE SA DERNIÈRE IMAGE À L'ÉCRAN : elles ne disparaissaient pas,
    // elles se figeaient — avec les taches sombres de la population de
    // fond, née sur les pixels clairs de la photo (sa capture du 24-09).
    //
    // Ces deux bornes sont donc DÉRIVÉES des constantes du shader. Si on
    // retouche une vie, un retard ou le front, elles suivent toutes
    // seules — c'est le seul moyen que ce défaut ne revienne jamais.
    // ════════════════════════════════════════════════════════════════════

    /// La mort de la toute dernière étincelle, en fraction de `duree`.
    /// `vie` max = (0,18 + 0,55 + 0,14) × 2,80 ; `retard` max = le coin le
    /// plus éloigné du foyer, 0,44 × √2, plus 0,10 de dispersion.
    static let fin: Double = 0.44 * 2.0.squareRoot() + 0.10
        + (0.18 + 0.55 + 0.14) * 2.80

    /// Passé ce point, AUCUNE particule ordinaire n'est plus vivante : il
    /// ne reste que les 2,5 % d'étincelles. Même calcul, avec le facteur
    /// de vie le plus long des ordinaires (le fond, 1,25). Le rendu s'en
    /// sert pour ne plus dessiner que la queue — 22 500 points au lieu de
    /// 900 000 pendant la dernière seconde et demie.
    static let queue: Double = 0.44 * 2.0.squareRoot() + 0.10
        + (0.18 + 0.55 + 0.14) * 1.25

    func jouer(depuis foyer: CGPoint? = nil, _ auMilieu: @escaping () -> Void) {
        guard !CoupeBanc.sans else { auMilieu(); return }
        annulerVoile()
        // ⚠️ UN GESTE EN ATTENTE N'EST JAMAIS JETÉ. Deux `jouer` coup sur
        // coup (elle tape vite : deux exercices d'affilée), et l'ancien
        // `auMilieu` était ÉCRASÉ sans avoir tourné — c'est-à-dire un
        // exercice ajouté à la séance qui disparaît en silence. On
        // l'honore avant de prendre le suivant.
        honorer()
        if let foyer { self.foyer = foyer }
        self.auMilieu = auMilieu
        photo = Self.photographier()
        Frisson.partagee.jouer()
        top &+= 1
        // ⚠️ LE CHIEN DE GARDE. Ce qu'on confie à l'ouverture n'est pas
        // décoratif : `onChoisirExo` AJOUTE l'exercice à la séance. Si le
        // rendu ne tourne pas — pas d'appareil Metal, texture absente,
        // couche pas encore posée, app passée en fond pendant le passage —
        // `draw(in:)` sort par sa garde et le geste ne partirait JAMAIS.
        // Ici il part quand même, un peu après l'heure : mieux vaut un
        // changement d'écran sans fondu qu'une séance qui perd une ligne.
        chien?.cancel()
        chien = Task { [attente = Self.duree * Self.milieu + 0.35] in
            try? await Task.sleep(for: .seconds(attente))
            guard !Task.isCancelled else { return }
            self.honorer()
        }
    }

    // ════════════════════════════════════════════════════════════════════
    // MARK: - LA COUPE SOURDE (24-09) — la même coupe, sans le feu
    //
    // « Au global il y a trop de fois l'effet paillette dans les
    //   transitions. Conserve-le que pour l'arrivée par le compteur, mais
    //   pas au lancement d'un exercice. » (Kathryn, 24-09.)
    //
    // ⚠️ ON RETIRE LE COSTUME, PAS LA COUPE. Ce que la coupe blanche fait
    // depuis le 22-09 n'est pas décoratif : elle tient l'écran pendant que
    // TROIS choses se réordonnent (la fiche se dépile, l'onglet est rendu à
    // la home, le lecteur se pose). Sans elle, on revoit exactement ce
    // qu'elle avait refusé le 22-09 — « on voit la page exercices entre les
    // deux ». Les retours gardent donc une coupe : un voile noir de 0,30 s,
    // sans une particule, sans haptique, que l'œil ne remarque pas.
    //
    // Le feu, lui, ne joue plus qu'UNE fois par séance : à l'ouverture.
    // ════════════════════════════════════════════════════════════════════

    /// L'opacité du voile sourd, lue par `Ouverture`.
    @Published fileprivate var voile: Double = 0
    /// Le tour du voile en cours : un voile qui se réveille annulé ne doit
    /// jamais effacer celui qui a pris sa place (sinon : écran noir tenu).
    private var tourVoile = 0

    static let dureeVoile: Double = 0.30

    /// `tenue` (25-09) : le noir TENU après la bascule, avant de se lever.
    /// Zéro par défaut — les retours qui ne changent qu'une vue n'en ont
    /// pas besoin. La sortie de la fiche, si : filmée au simulateur, le
    /// voile se levait sur la fiche en train de glisser (le dépilement
    /// garde l'animation de navigation, transaction ou pas), la page
    /// Exercices et ses catégories 66 ms, puis la home 170 ms avant que le
    /// lecteur ne se pose — l'onglet et le lecteur basculent au rendu
    /// SUIVANT, par le canal `ouvrirLecteur`, pas sous ce noir-ci.
    func couper(tenue: Double = 0, _ auMilieu: @escaping () -> Void) {
        guard !CoupeBanc.sans else { auMilieu(); return }
        // Même contrat que `jouer` : un geste en attente n'est jamais jeté.
        honorer()
        self.auMilieu = auMilieu
        tourVoile &+= 1
        let mien = tourVoile
        chien?.cancel()
        chien = Task { [d = Self.dureeVoile] in
            withAnimation(.easeIn(duration: d * 0.45)) { self.voile = 1 }
            try? await Task.sleep(for: .seconds(d * 0.45))
            // ⚠️ LE GARDE-FOU DU NOIR TENU. Si un autre passage a pris la
            // main pendant le sommeil, on se retire sans toucher au voile
            // — son geste, lui, a déjà été honoré par l'appel suivant.
            guard self.tourVoile == mien else { return }
            self.honorer()                       // l'écran change SOUS le noir
            guard tenue > 0 else {
                withAnimation(.easeOut(duration: d * 0.55)) { self.voile = 0 }
                return
            }
            // ⚠️ UNE TÂCHE NEUVE : `honorer()` vient d'annuler celle-ci (elle
            // EST le chien), et un `Task.sleep` annulé rend la main aussitôt
            // — la tenue n'aurait jamais tenu.
            Task {
                try? await Task.sleep(for: .seconds(tenue))
                guard self.tourVoile == mien else { return }
                withAnimation(.easeOut(duration: d * 0.55)) { self.voile = 0 }
            }
        }
    }

    /// Le feu reprend la main sur un voile en cours : on le lève, sinon il
    /// resterait posé pour toujours par-dessus la combustion.
    private func annulerVoile() {
        tourVoile &+= 1
        guard voile != 0 else { return }
        withAnimation(.easeOut(duration: 0.18)) { voile = 0 }
    }

    /// Exécute le geste confié, AU PLUS UNE FOIS. Le rendu et le chien de
    /// garde passent tous les deux par ici : le premier arrivé gagne.
    fileprivate func honorer() {
        chien?.cancel(); chien = nil
        guard let geste = auMilieu else { return }
        auMilieu = nil
        var tr = Transaction(); tr.disablesAnimations = true
        withTransaction(tr) { geste() }
    }

    /// ⚠️ `drawHierarchy(afterScreenUpdates: false)` ET PAS
    /// `layer.render(in:)` : cette app est pleine de calques Metal, de
    /// verres et de vidéos, que `render(in:)` rend NOIRS. On lit le
    /// dernier cadre présenté, à l'échelle 1 (un point = un pixel) : on ne
    /// cherche qu'une couleur par particule, pas du détail.
    private static func photographier() -> CGImage? {
        guard let f = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let w = f.windows.first(where: \.isKeyWindow) ?? f.windows.first,
              w.bounds.width > 1
        else { return nil }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let img = UIGraphicsImageRenderer(bounds: w.bounds, format: format)
            .image { _ in w.drawHierarchy(in: w.bounds, afterScreenUpdates: false) }
        return img.cgImage
    }
}

// MARK: - La vue

struct Ouverture: View {
    @ObservedObject private var etat = CoupeEtat.shared

    var body: some View {
        ZStack {
            NuageVue(top: etat.top)
            // LE VOILE SOURD — noir, court, sans une particule. Il ne coûte
            // qu'une opacité animée : à 0 il n'est même pas composé.
            Color.black.opacity(etat.voile)
        }
            .ignoresSafeArea()
            // ⚠️ ELLE NE PREND JAMAIS LE DOIGT. Le calque couvre l'écran en
            // permanence (le monter à la demande coûterait une compilation
            // de pipeline au pire moment) : il doit donc être transparent
            // au toucher, toujours.
            .allowsHitTesting(false)
            // LES BANCS. ⚠️ Ils doivent passer par `jouer` comme le doigt :
            // c'est LUI qui photographie l'écran. Un banc qui se contente
            // de figer l'horloge ne montre que l'émission propre des
            // braises, sur une photo vide — et fait croire à un échec
            // (payé le 23-09).
            .task {
                guard OuvertureBanc.fige != nil || OuvertureBanc.boucle
                        || OuvertureBanc.uneFois else { return }
                try? await Task.sleep(for: .seconds(5))   // l'écran se pose
                CoupeEtat.shared.jouer {}
                guard OuvertureBanc.boucle else { return }
                // ⚠️ LE REPOS DE LA BOUCLE SUIT LA VRAIE FIN (24-09).
                // `duree + 0,6` relançait le passage alors que les
                // étincelles du précédent vivaient encore : le banc
                // empilait deux passages et ne montrait plus rien de juste.
                while !Task.isCancelled {
                    try? await Task.sleep(
                        for: .seconds(CoupeEtat.duree * CoupeEtat.fin + 0.6))
                    CoupeEtat.shared.jouer {}
                }
            }
    }
}

// MARK: - Le calque Metal

/// ⚠️ IL DOIT CORRESPONDRE AU `struct Passage` de `Particules.metal`, au
/// rembourrage près : `float2` s'aligne sur 8 octets, donc 8 + 8 + 4 + 4.
private struct Passage {
    var taille: SIMD2<Float>
    var foyer: SIMD2<Float>
    var avance: Float
    /// La borne des étincelles : les points dont le numéro est inférieur
    /// sont des étincelles. ⚠️ C'est ce qui permet de ne dessiner QUE la
    /// queue à la fin du passage — un tirage au hasard les aurait semées
    /// dans tout l'intervalle, et il aurait fallu les 900 000 jusqu'au bout.
    var etincelles: Float
}


private struct NuageVue: UIViewRepresentable {
    let top: Int

    func makeCoordinator() -> Nuage { Nuage() }

    func makeUIView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        v.delegate = context.coordinator
        v.isOpaque = false
        v.backgroundColor = .clear
        v.layer.isOpaque = false
        v.clearColor = MTLClearColorMake(0, 0, 0, 0)
        v.framebufferOnly = true
        v.isUserInteractionEnabled = false
        // ⚠️ IL NE DESSINE QUE PENDANT L'OUVERTURE. Hors passage, la boucle
        // est arrêtée : un `MTKView` laissé à 60 img/s sur une app de
        // séance, c'est la batterie et la chauffe pour rien.
        v.isPaused = true
        v.enableSetNeedsDisplay = false
        context.coordinator.preparer(v)
        return v
    }

    func updateUIView(_ v: MTKView, context: Context) {
        context.coordinator.vu(top: top, vue: v,
                               photo: CoupeEtat.shared.photo)
    }
}

@MainActor
private final class Nuage: NSObject, MTKViewDelegate {
    /// ⚠️ 900 000 POINTS, ET C'EST LE CHIFFRE QUI DÉCIDE DE TOUT.
    /// Mesuré le 23-09, sur écran noir : 60 000 ⇒ luminance moyenne 2,4 sur
    /// 255 ; 320 000 ⇒ 0,6 une fois le voile posé. De la poussière, deux
    /// fois. **La matière vient du NOMBRE, jamais de l'opacité ni de la
    /// taille de chaque point** — c'est sa loi (« la brillance vient de la
    /// blancheur, jamais de l'épaisseur ») appliquée à la lettre : ici la
    /// lumière est l'ACCUMULATION de milliers de dépôts minuscules.
    /// Grossir les points donnerait du coton ; les éclaircir, du néon.
    /// À 900 000 le nuage se recouvre enfin (≈ 1,3 fois l'écran).
    private let nombre = 900_000
    /// Les 2,5 % d'étincelles occupent les PREMIERS numéros — voir
    /// `Passage.etincelles`.
    private var borne: Int { nombre / 40 }

    private var file: MTLCommandQueue?
    private var pipePoints: MTLRenderPipelineState?
    private var pipeVoile: MTLRenderPipelineState?
    private var curl: MTLTexture?
    private var ecran: MTLTexture?
    private var noir: MTLTexture?
    private var chargeur: MTKTextureLoader?
    private var depart: CFTimeInterval?
    private var dernierTop = 0
    private var milieuFait = false
    private var taille = CGSize(width: 1, height: 1)
    /// Le prochain cadre doit être VIDE, puis la boucle s'arrête.
    private var doitNettoyer = false
    /// Le filet : si le rendu se tait en plein passage, il nettoie quand même.
    private var chien: Task<Void, Never>?
    nonisolated(unsafe) private var observateur: NSObjectProtocol?

    deinit {
        if let observateur { NotificationCenter.default.removeObserver(observateur) }
    }

    func preparer(_ v: MTKView) {
        guard let d = v.device, let bib = d.makeDefaultLibrary() else { return }
        file = d.makeCommandQueue()

        func pipe(_ vs: String, _ fs: String, points: Bool) -> MTLRenderPipelineState? {
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = bib.makeFunction(name: vs)
            desc.fragmentFunction = bib.makeFunction(name: fs)
            let a = desc.colorAttachments[0]!
            a.pixelFormat = v.colorPixelFormat
            a.isBlendingEnabled = true
            // ⚠️ PRÉMULTIPLIÉ, et c'est ce qui rend l'additif possible : un
            // fragment (rgb, 0) laisse le fond intact et AJOUTE sa couleur.
            // Le compositeur de Core Animation fait le reste.
            a.rgbBlendOperation = .add
            a.alphaBlendOperation = .add
            a.sourceRGBBlendFactor = .one
            a.sourceAlphaBlendFactor = .one
            a.destinationRGBBlendFactor = points ? .one : .oneMinusSourceAlpha
            a.destinationAlphaBlendFactor = points ? .one : .oneMinusSourceAlpha
            return try? d.makeRenderPipelineState(descriptor: desc)
        }
        pipePoints = pipe("particuleSommet", "particuleFragment", points: true)
        pipeVoile  = pipe("voileSommet", "voileFragment", points: false)

        let ch = MTKTextureLoader(device: d)
        chargeur = ch
        curl = try? ch.newTexture(name: "particules-curl", scaleFactor: 1,
                                  bundle: .main, options: nil)
        // Le repli : un pixel noir. Le shader lit TOUJOURS une texture
        // d'écran ; s'il n'y a pas de photo, les braises n'ont que leur
        // émission propre.
        let dn = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: 1, height: 1, mipmapped: false)
        noir = d.makeTexture(descriptor: dn)
        var zero: [UInt8] = [0, 0, 0, 255]
        noir?.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0,
                      withBytes: &zero, bytesPerRow: 4)

        // ⚠️ LA DEUXIÈME PORTE (24-09). L'app qui passe en arrière-plan
        // pendant un passage arrête le rendu — et la dernière image reste
        // affichée, exactement comme à la mise en pause. On la ferme avec
        // la même règle : on n'éteint jamais sans avoir nettoyé. Le geste
        // confié, lui, est honoré tout de suite : une séance ne perd pas
        // une ligne parce qu'on a reçu un appel.
        observateur = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil, queue: .main
        ) { [weak self, weak v] _ in
            MainActor.assumeIsolated {
                guard let self, let v, !v.isPaused else { return }
                CoupeEtat.shared.honorer()
                self.nettoyer(v)
            }
        }

        if OuvertureBanc.fige != nil || OuvertureBanc.boucle {
            depart = CACurrentMediaTime()
            v.isPaused = false
        }
    }

    func vu(top: Int, vue: MTKView, photo: CGImage?) {
        guard top != dernierTop else { return }
        dernierTop = top
        // Une allocation PAR PASSAGE (pas par image) : c'est le prix de la
        // photo, et il se paie pendant que l'écran est déjà couvert.
        if let photo { ecran = try? chargeur?.newTexture(cgImage: photo, options: nil) }
        depart = CACurrentMediaTime()
        milieuFait = false
        doitNettoyer = false
        vue.isPaused = false
        // ⚠️ LA TROISIÈME PORTE : l'écran change de hiérarchie sous le
        // calque et `draw(in:)` cesse d'être appelé. Le chien ne réveille
        // pas le passage — il le NETTOIE, une fois son temps écoulé.
        chien?.cancel()
        chien = Task { [attente = CoupeEtat.duree * CoupeEtat.fin + 0.5] in
            try? await Task.sleep(for: .seconds(attente))
            guard !Task.isCancelled, !vue.isPaused else { return }
            self.nettoyer(vue)
        }
    }

    /// ⚠️⚠️ LA SEULE FAÇON DE S'ARRÊTER — ON N'ÉTEINT JAMAIS SANS NETTOYER.
    /// Un `MTKView` mis en pause laisse sa dernière image à l'écran. Trois
    /// chemins mènent à l'extinction (la fin du passage, l'arrière-plan, le
    /// chien de garde) et tous les trois passent par ici : on redemande un
    /// cadre, ce cadre-là est VIDE, et c'est lui qui reste.
    private func nettoyer(_ v: MTKView) {
        doitNettoyer = true
        v.isPaused = false
        v.draw()                  // un cadre tout de suite, synchrone
    }

    func mtkView(_ v: MTKView, drawableSizeWillChange size: CGSize) { taille = size }

    func draw(in v: MTKView) {
        guard let file, let pipePoints, let pipeVoile, let curl, let noir,
              let desc = v.currentRenderPassDescriptor,
              let dessin = v.currentDrawable,
              let tampon = file.makeCommandBuffer(),
              let enc = tampon.makeRenderCommandEncoder(descriptor: desc)
        else { return }

        // ─── LE CADRE VIDE, PUIS LE SOMMEIL ────────────────────────────
        // Il est encodé sans un seul dessin : le `loadAction` du `MTKView`
        // efface déjà la cible avec `clearColor` (transparent). Rien à
        // effacer à la main, rien à laisser derrière.
        if doitNettoyer {
            doitNettoyer = false
            chien?.cancel(); chien = nil
            enc.endEncoding()
            tampon.present(dessin)
            tampon.commit()
            v.isPaused = true
            return
        }

        // ─── L'HORLOGE EST ICI, pas dans SwiftUI ───────────────────────
        var avance: Float
        if let f = OuvertureBanc.fige {
            avance = f
        } else {
            let t = (CACurrentMediaTime() - (depart ?? 0)) / CoupeEtat.duree
            if OuvertureBanc.boucle {
                avance = Float(t.truncatingRemainder(dividingBy: 1.0))
            } else {
                avance = Float(min(max(t, 0), CoupeEtat.fin))
                // LE CHANGEMENT, sous le voile, exactement une fois.
                if !milieuFait, t >= CoupeEtat.milieu {
                    milieuFait = true
                    if !OuvertureBanc.sansGeste { CoupeEtat.shared.honorer() }
                }
                // ⚠️ LA FIN EST CALCULÉE (`CoupeEtat.fin`), et on ne s'y
                // endort pas : on nettoie. C'est le défaut du 24-09.
                // Ici le cadre courant EST le cadre vide — on n'encode
                // rien de plus, et on ne rappelle pas `nettoyer` : on est
                // déjà dans un `draw`, le relancer serait ré-entrant.
                if t > CoupeEtat.fin {
                    chien?.cancel(); chien = nil
                    enc.endEncoding()
                    tampon.present(dessin)
                    tampon.commit()
                    v.isPaused = true
                    return
                }
            }
        }

        // ⚠️ UN SEUL ÉTAT, LU PAR LES DEUX PIPELINES. Le voile calcule son
        // front avec la MÊME formule et la MÊME avance que les points : le
        // noir arrive exactement là où les braises viennent de partir.
        var pa = Passage(taille: SIMD2(Float(taille.width), Float(taille.height)),
                         foyer: SIMD2(Float(CoupeEtat.shared.foyer.x),
                                      Float(CoupeEtat.shared.foyer.y)),
                         avance: avance, etincelles: Float(borne))
        let octets = MemoryLayout<Passage>.stride

        // LE VOILE d'abord : il noircit ce que les braises ont quitté.
        enc.setRenderPipelineState(pipeVoile)
        enc.setFragmentBytes(&pa, length: octets, index: 0)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        // LES POINTS, par-dessus, en additif.
        enc.setRenderPipelineState(pipePoints)
        enc.setVertexBytes(&pa, length: octets, index: 0)
        enc.setVertexTexture(curl, index: 0)
        enc.setVertexTexture(ecran ?? noir, index: 1)
        // ⚠️ LA QUEUE NE COÛTE PLUS QUE SA QUEUE. Passé `CoupeEtat.queue`,
        // il ne reste que les étincelles en vie — et comme elles occupent
        // les premiers numéros, on s'arrête à leur borne : 22 500 points
        // au lieu de 900 000 pendant la dernière seconde et demie. Les
        // autres seraient de toute façon jetées hors du cadre par le
        // shader ; autant ne pas les appeler.
        let combien = Double(avance) > CoupeEtat.queue ? borne : nombre
        enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: combien)

        enc.endEncoding()
        tampon.present(dessin)
        tampon.commit()
    }
}

// MARK: - LE FRISSON (23-09) — ce que la combustion fait dans la main
//
// « Trop bien, rajoute haptique. » (Kathryn, 23-09.)
//
// ⚠️ PAS UN `UIImpactFeedbackGenerator`. Un « toc » générique sur une
// combustion d'une seconde et demie, c'est exactement le « cheap » qu'on
// vient de passer la journée à chasser : le doigt sentirait un bouton
// pendant que l'œil voit du feu. Core Haptics donne ce que le dessin
// raconte, et rien d'autre :
//
//   · L'ALLUMAGE — une transitoire nette, sous le pouce, à l'instant zéro.
//     C'est la CAUSE du passage : la main la sent avant que l'œil la voie.
//   · LA COMBUSTION — un continu grave (netteté 0,20) dont l'intensité
//     suit la même courbe que le nuage : elle monte, culmine quand l'écran
//     a disparu, et MEURT avec les braises. Un continu plat vibrerait ;
//     celui-ci brûle.
//   · LES CRÉPITEMENTS — sept transitoires faibles et sèches, semées au
//     hasard pendant la montée. Ce sont les étincelles, dans la main.
//
// ⚠️ LE SIMULATEUR N'A PAS DE MOTEUR HAPTIQUE : rien de ceci n'est
// vérifiable ici, et ça ne se juge que sur son iPhone. Son barreau :
// `-sansHaptique`.

@MainActor
private final class Frisson {
    static let partagee = Frisson()
    private init() {}

    private var moteur: CHHapticEngine?
    private lazy var possible = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    func jouer() {
        guard !HaptiqueBanc.sans, !CoupeBanc.sans else { return }
        guard possible else { replier(); return }
        do {
            let m = try demarrer()
            try m.makePlayer(with: motif()).start(atTime: CHHapticTimeImmediate)
        } catch {
            // ⚠️ AUCUN `try!` ICI. Le moteur haptique se fait couper par le
            // système (appel entrant, Mode Avion basse consommation) et par
            // l'arrière-plan : une ouverture ne doit jamais faire tomber
            // l'app parce que le téléphone a décidé de ne pas vibrer.
            replier()
        }
    }

    /// Le repli quand Core Haptics n'est pas là : deux impacts natifs. Ce
    /// n'est pas la même chose, et c'est assumé — mieux vaut ça que rien.
    private func replier() {
        guard !HaptiqueBanc.sans, !CoupeBanc.sans else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.9)
    }

    private func demarrer() throws -> CHHapticEngine {
        if let moteur { try moteur.start(); return moteur }
        let m = try CHHapticEngine()
        m.playsHapticsOnly = true
        // Il s'éteint tout seul entre deux passages : un moteur haptique
        // laissé allumé consomme pour rien.
        m.isAutoShutdownEnabled = true
        m.resetHandler = { [weak m] in try? m?.start() }
        try m.start()
        moteur = m
        return m
    }

    private func motif() -> CHHapticPattern {
        let d = CoupeEtat.duree
        let fin = d * 0.62                    // la combustion meurt au milieu
        func p(_ id: CHHapticEvent.ParameterID, _ v: Float) -> CHHapticEventParameter {
            CHHapticEventParameter(parameterID: id, value: v)
        }
        var evts: [CHHapticEvent] = [
            // L'allumage.
            CHHapticEvent(eventType: .hapticTransient,
                          parameters: [p(.hapticIntensity, 0.92), p(.hapticSharpness, 0.62)],
                          relativeTime: 0),
            // La combustion.
            CHHapticEvent(eventType: .hapticContinuous,
                          parameters: [p(.hapticIntensity, 0.55), p(.hapticSharpness, 0.20)],
                          relativeTime: 0.02, duration: fin - 0.02)
        ]
        // Les crépitements — semés, jamais réguliers : un rythme se
        // reconnaît, et ce n'est plus du feu.
        for (t, i) in [(0.11, 0.30), (0.19, 0.22), (0.26, 0.38), (0.34, 0.26),
                       (0.41, 0.34), (0.49, 0.20), (0.56, 0.28)] {
            evts.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [p(.hapticIntensity, Float(i)), p(.hapticSharpness, 0.85)],
                relativeTime: d * t))
        }
        // ⚠️ LA COURBE EST CE QUI FAIT LA COMBUSTION. Sans elle, le continu
        // est un buzz de téléphone : ici l'intensité suit le nuage — elle
        // monte, culmine quand l'écran a disparu, et tombe à zéro.
        let courbe = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0,        value: 0.15),
                .init(relativeTime: d * 0.28, value: 0.80),
                .init(relativeTime: d * 0.46, value: 1.00),
                .init(relativeTime: fin,      value: 0.00)
            ],
            relativeTime: 0)
        return (try? CHHapticPattern(events: evts, parameterCurves: [courbe]))
            ?? (try! CHHapticPattern(events: [evts[0]], parameters: []))
    }
}
