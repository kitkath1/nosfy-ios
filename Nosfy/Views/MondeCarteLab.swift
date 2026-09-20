import SwiftUI
import UIKit

// MARK: - Banc du monde ouvert d'une légendaire (`-mondeLab`, 20-09)

/// LE TAP OUVRE LE VERRE. Le plan du 20-09 (tools/carte-lune/PLAN-LEGENDAIRE-
/// PLONGEE-2026-09-20.md, § 4) remplace la plongée-film de 14 s (le chemin
/// de caméra écrit pour carte-lune-1 : sur un loup, « les pins au ras du
/// sol » sont les pattes) par ceci :
///
///   1. la carte, en main : le cerf habillé (cadre argent, quatre lunes),
///      la parallaxe VRAIE (profondeur cuite par Depth Anything, plus la
///      rampe commune), inclinable au gyroscope ;
///   2. TAP : le cadre se dissout dans le noir, la scène s'étend BORD À
///      BORD (0,55 s) — la carte a ouvert son verre ;
///   3. dedans, C'EST ELLE QUI CONDUIT : incliner = la parallaxe glisse,
///      glisser = promener le regard, pincer = s'approcher (×2 maximum —
///      jamais au-delà des pixels de la peinture), rien ne bouge tant que
///      le doigt ne bouge pas ; pas de durée ;
///   4. glisser vers le bas (ou double-tap) = le verre se referme, le
///      cadre se reforme.
///
/// Ce banc ne porte PAS encore la matière légendaire (gravure, ciel de
/// paillettes, braises, neige — § 2 du plan) ni les plans séparés (le
/// diorama) : il montre le GESTE et la profondeur vraie, et rien d'autre.
///
/// LE KIT DE LA CARTE vient du dossier Documents de l'app (le pattern de
/// la clé OpenAI : le sandbox ne lit pas le disque du Mac, on copie) :
///   monde-art.png         l'illustration nue (1024×1536)
///   monde-depth-nue.png   sa profondeur (même taille, gris ; 0,45 = pivot)
///   monde-depth.png       la profondeur au format carte (543×724, LuneForge)
/// cuits par tools/carte-lune/cuire_profondeur.py. Sans kit : carte-lune-1.
struct MondeCarteLab: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var kit = KitMonde.charger()
    /// 0 = la carte en main, 1 = le monde ouvert (animé au ressort).
    @State private var ouvert: CGFloat = 0
    @State private var estOuvert = false
    /// Ce qui est MONTÉ : une vue cachée par l'opacité rend quand même
    /// (la loi du rideau) — la carte et son shader, ou les six plans,
    /// ne vivent que le temps de la traversée puis se démontent.
    @State private var afficheCarte = true
    @State private var afficheMonde = false
    /// Le regard : où le doigt a promené l'image, et son point de départ
    /// au début du geste.
    @State private var pan: CGSize = .zero
    @State private var panBase: CGSize = .zero
    /// L'approche : ×1 → ×2, jamais plus.
    @State private var zoom: CGFloat = 1
    @State private var zoomBase: CGFloat = 1
    @State private var glisseVersLeBas = false

    private static let zoomMax: CGFloat = 2.0
    /// `-mondeAuto` : le banc joue le tap seul à 1,2 s et referme à 9 s —
    /// pour FILMER l'ouverture au simulateur, qui n'a ni doigt ni
    /// gyroscope. Jamais dans le produit : là, c'est elle qui conduit.
    private static let auto = CommandLine.arguments.contains("-mondeAuto")
    /// `-mondeDiag` : liserés (rouge = le monde, bleu = la carte) et les tailles à l'écran.
    private static let diag = CommandLine.arguments.contains("-mondeDiag")
    /// `-mondeRelief` : la variante « photo 3D » (SceneKit) au lieu des six plans.
    private static let relief = CommandLine.arguments.contains("-mondeRelief")

    /// Sans gyroscope (simulateur), la carte se balance seule : une
    /// Lissajous lente, deux périodes premières entre elles.
    private static func balancement(_ t: Float) -> SIMD2<Float> {
        SIMD2(0.45 * sin(t * 2 * .pi / 7.3), 0.30 * sin(t * 2 * .pi / 9.7 + 1.2))
    }

    var body: some View {
        GeometryReader { geo in
            let ecran = geo.size
            let carte = CarteVivante.cardSize(in: ecran)
            // L'art dans la carte : aspect-fill dans la fenêtre du cadre
            // (LuneForge.composer) — la largeur de la fenêtre l'emporte.
            let fen = LuneForge.fenetre
            let echelleCarte = carte.width / LuneForge.canvas.width
            let artDansCarte = CGSize(width: fen.width * LuneForge.canvas.width * echelleCarte,
                                      height: fen.width * LuneForge.canvas.width * echelleCarte
                                          * kit.art.size.height / kit.art.size.width)
            // L'art plein écran : aspect-fill de l'écran.
            let s = max(ecran.width / kit.art.size.width, ecran.height / kit.art.size.height)
            let artPlein = CGSize(width: kit.art.size.width * s, height: kit.art.size.height * s)
            let taille = CGSize(width: artDansCarte.width + (artPlein.width - artDansCarte.width) * ouvert,
                                height: artDansCarte.height + (artPlein.height - artDansCarte.height) * ouvert)
            // Le centre de la fenêtre du cadre est un peu au-dessus du
            // centre du canvas : la couture de l'ouverture le suit.
            let decalageFenetre = ((fen.midY - 0.5) * LuneForge.canvas.height) * echelleCarte * (1 - ouvert)

            ZStack {
                Color.black

                TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                        paused: scenePhase != .active)) { tl in
                    let t = Float(tl.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 900))
                    let tilt: SIMD2<Float> = reduceMotion ? SIMD2(0, 0)
                        : (LuneMotion.shared.live ? LuneMotion.shared.tilt : Self.balancement(t))

                    // SUPERPOSÉS, explicitement : sans ZStack, le TimelineView
                    // posait le monde AU-DESSUS de la carte comme une pile
                    // verticale — la carte à 70 % de l'écran, le monde coupé
                    // en haut (payé au banc, 20-09).
                    ZStack {
                    // LE MONDE — dessous : il apparaît pendant que le verre s'ouvre.
                    if afficheMonde { Group {
                        if Self.relief, let fond = kit.fond, let fondDepth = kit.fondDepth {
                            MondeRelief(fond: fond, fondDepth: fondDepth,
                                        creature: kit.creature?.image, creatureProfondeur: kit.creature?.profondeur ?? 0.35,
                                        tilt: tilt, ouvert: ouvert, pan: pan, zoom: zoom, ecran: ecran)
                                .frame(width: ecran.width, height: ecran.height)
                                .scaleEffect(artDansCarte.width / artPlein.width + (1 - artDansCarte.width / artPlein.width) * ouvert)
                        } else if kit.plans.isEmpty {
                            Image(uiImage: kit.art)
                                .resizable()
                                .frame(width: taille.width, height: taille.height)
                                .layerEffect(ShaderLibrary.carteMonde(
                                    .float2(taille.width, taille.height),
                                    .float2(CGFloat(tilt.x), CGFloat(tilt.y)),
                                    .float2(pan.width, pan.height),
                                    .float(26 * ouvert + 8),
                                    .float(0.22 * ouvert),
                                    .image(Image(uiImage: kit.depthNue))),
                                    maxSampleOffset: CGSize(width: 64, height: 64))
                                .scaleEffect(zoom)
                                .offset(pan)
                        } else {
                            MondePlans(plans: kit.plans, taille: taille, tilt: tilt,
                                       ouvert: ouvert, pan: pan, zoom: zoom)
                        }
                    }
                    .frame(width: ecran.width, height: ecran.height)
                    .clipped()
                    .offset(y: decalageFenetre)
                    .opacity(Double(min(1, ouvert * 1.6)))
                    .border(Self.diag ? Color.red : Color.clear, width: 2)
                    .allowsHitTesting(estOuvert)
                    }

                    // LA CARTE — dessus : elle se dissout en grandissant un peu.
                    if afficheCarte { CarteLuneCard(size: carte, tilt: tilt, t: t,
                                  art: Image(uiImage: kit.carte), depth: Image(uiImage: kit.depthCarte))
                        .rotation3DEffect(.degrees(Double(tilt.y) * -7.5), axis: (x: 1, y: 0, z: 0), perspective: 0.42)
                        .rotation3DEffect(.degrees(Double(tilt.x) * 10.5), axis: (x: 0, y: 1, z: 0), perspective: 0.42)
                        .scaleEffect(1 + 0.22 * ouvert)
                        .opacity(Double(1 - min(1, ouvert * 1.4)))
                        .border(Self.diag ? Color.blue : Color.clear, width: 2)
                        .allowsHitTesting(!estOuvert)
                        .onTapGesture { ouvrir() }
                    }
                    }
                }
                .frame(width: ecran.width, height: ecran.height)
                .clipped()
            }
            .frame(width: ecran.width, height: ecran.height)
            .overlay(alignment: .topLeading) {
                if Self.diag {
                    Text("écran \(Int(ecran.width))×\(Int(ecran.height)) · safe \(Int(geo.safeAreaInsets.top))/\(Int(geo.safeAreaInsets.bottom)) · carte \(Int(carte.width))×\(Int(carte.height)) · art \(Int(kit.art.size.width))×\(Int(kit.art.size.height)) · plein \(Int(artPlein.width))×\(Int(artPlein.height)) · taille \(Int(taille.width))×\(Int(taille.height)) · ouvert \(String(format: "%.2f", ouvert))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .padding(.top, 60)
                }
            }
            .contentShape(Rectangle())
            // DEDANS, C'EST ELLE QUI CONDUIT.
            .simultaneousGesture(glisser(ecran: ecran, art: artPlein))
            .simultaneousGesture(pincer())
            .onTapGesture(count: 2) { if estOuvert { fermer() } }
            .onAppear {
                print("[mondeLab] écran \(Int(ecran.width))×\(Int(ecran.height)) · safe \(geo.safeAreaInsets) · carte \(Int(carte.width))×\(Int(carte.height)) · art plein \(Int(artPlein.width))×\(Int(artPlein.height))")
            }
        }
        .ignoresSafeArea()
        .onAppear {
            LuneMotion.shared.start()
            if Self.auto {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { ouvrir() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 9.0) { fermer() }
            }
        }
        .onDisappear { LuneMotion.shared.stop() }
        .statusBarHidden(true)
    }

    // MARK: Les gestes

    private func glisser(ecran: CGSize, art: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { v in
                guard estOuvert else { return }
                let brut = CGSize(width: panBase.width + v.translation.width,
                                  height: panBase.height + v.translation.height)
                pan = Self.borner(brut, ecran: ecran, art: art, zoom: zoom)
                // Le verre se referme si le geste est un glissé FRANC vers
                // le bas, à l'échelle 1 : le mouvement d'une photo qu'on rend.
                glisseVersLeBas = zoom < 1.08 && v.translation.height > 140
                    && abs(v.translation.width) < v.translation.height * 0.6
            }
            .onEnded { v in
                guard estOuvert else { return }
                if glisseVersLeBas && v.predictedEndTranslation.height > 240 {
                    fermer()
                    return
                }
                // L'inertie : l'image continue un peu, puis se pose.
                let fin = CGSize(width: panBase.width + v.predictedEndTranslation.width * 0.6
                                     + v.translation.width * 0.4,
                                 height: panBase.height + v.predictedEndTranslation.height * 0.6
                                     + v.translation.height * 0.4)
                withAnimation(.interpolatingSpring(stiffness: 120, damping: 22)) {
                    pan = Self.borner(fin, ecran: ecran, art: art, zoom: zoom)
                }
                panBase = Self.borner(fin, ecran: ecran, art: art, zoom: zoom)
                glisseVersLeBas = false
            }
    }

    private func pincer() -> some Gesture {
        MagnificationGesture()
            .onChanged { z in
                guard estOuvert else { return }
                zoom = min(max(zoomBase * z, 1), Self.zoomMax)
            }
            .onEnded { _ in
                guard estOuvert else { return }
                zoomBase = zoom
                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                    zoom = min(max(zoom, 1), Self.zoomMax)
                }
                zoomBase = min(max(zoom, 1), Self.zoomMax)
            }
    }

    /// L'image ne quitte jamais l'écran : le regard reste dans la carte.
    private static func borner(_ p: CGSize, ecran: CGSize, art: CGSize, zoom: CGFloat) -> CGSize {
        let mx = max(0, (art.width * zoom - ecran.width) / 2)
        let my = max(0, (art.height * zoom - ecran.height) / 2)
        return CGSize(width: min(max(p.width, -mx), mx), height: min(max(p.height, -my), my))
    }

    // MARK: Ouvrir, fermer

    private func ouvrir() {
        guard !estOuvert else { return }
        LuneMotion.shared.recalibrate()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        estOuvert = true
        pan = .zero; panBase = .zero; zoom = 1; zoomBase = 1
        afficheMonde = true
        withAnimation(reduceMotion ? .easeInOut(duration: 0.35)
                      : .timingCurve(0.25, 0.75, 0.15, 1.0, duration: 0.8)) {
            ouvert = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { if estOuvert { afficheCarte = false } }
    }

    private func fermer() {
        guard estOuvert else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        estOuvert = false
        afficheCarte = true
        withAnimation(.timingCurve(0.3, 0.7, 0.2, 1.0, duration: 0.7)) {
            ouvert = 0
            pan = .zero
            zoom = 1
        }
        panBase = .zero; zoomBase = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { if !estOuvert { afficheMonde = false } }
    }
}

// MARK: - Le kit de la carte

/// L'art nu, sa profondeur vraie, et la carte habillée (cadre + lunes,
/// par LuneForge — le même compositing que la forge). Depuis Documents,
/// sinon carte-lune-1 et sa rampe.
struct KitMonde {
    let art: UIImage
    let depthNue: UIImage
    let carte: UIImage
    let depthCarte: UIImage
    /// LES PLANS DU DIORAMA (kit v2, `cuire_plans.py`) : du plus loin au
    /// plus proche, chacun avec sa profondeur (0,45 = le pivot). Vide :
    /// le monde retombe sur l'image unique déformée par la profondeur.
    let plans: [(image: UIImage, profondeur: Float, nom: String)]
    /// Pour le RELIEF : le fond sans la créature et sa profondeur continue.
    let fond: UIImage?
    let fondDepth: UIImage?
    var creature: (image: UIImage, profondeur: Float, nom: String)? { plans.first { $0.nom == "la créature" } }

    /// `-mondeCarte <nom>` : le kit de CETTE carte, dans `Documents/monde/<nom>/`
    /// (la cuisson `cuire_kits.sh` en produit un par référence publiée) ;
    /// sans le drapeau, les fichiers à la racine de Documents (le cerf du banc).
    static func charger() -> KitMonde {
        let racine = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let carte = UserDefaults.standard.string(forKey: "mondeCarte")
        let docs = carte.map { racine.appending(path: "monde/\($0)") } ?? racine
        func doc(_ nom: String) -> UIImage? {
            UIImage(contentsOfFile: docs.appending(path: nom).path)
        }
        func media(_ nom: String) -> UIImage? {
            guard let p = Bundle.main.path(forResource: nom, ofType: "png") else { return nil }
            return UIImage(contentsOfFile: p)
        }
        var plans: [(image: UIImage, profondeur: Float, nom: String)] = []
        if let data = try? Data(contentsOf: docs.appending(path: "monde-plans.json")),
           let liste = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for (k, p) in liste.enumerated() {
                guard let im = doc("monde-plan-\(k + 1).png"),
                      let prof = p["profondeur"] as? Double else { continue }
                plans.append((im, Float(prof), p["nom"] as? String ?? ""))
            }
        }
        if let art = doc("monde-art.png"), let dn = doc("monde-depth-nue.png"),
           let habit = try? LuneForge.habiller(illustration: art, rarete: "legendary") {
            let dc = doc("monde-depth.png") ?? habit.depth
            print("[mondeLab] kit \(carte ?? "racine") : art \(Int(art.size.width))×\(Int(art.size.height)), profondeur vraie, \(plans.count) plans")
            return KitMonde(art: art, depthNue: dn, carte: habit.art, depthCarte: dc, plans: plans,
                            fond: doc("monde-fond.png"), fondDepth: doc("monde-fond-depth.png"))
        }
        let c = media("carte-lune-1") ?? UIImage()
        let d = media("carte-lune-1-depth") ?? UIImage()
        print("[mondeLab] pas de kit dans Documents : carte-lune-1 et sa rampe")
        return KitMonde(art: c, depthNue: d, carte: c, depthCarte: d, plans: [], fond: nil, fondDepth: nil)
    }
}


// MARK: - Le diorama : les plans qui s'écartent

/// Six plans (kit v2), du plus loin au plus proche. Chacun est une IMAGE
/// ENTIÈRE qui se décale et grandit selon sa distance — jamais des pixels
/// tirés. Trois voix, toutes animables :
///   · l'inclinaison (le gyroscope, le doigt) : le lointain suit l'œil, le
///     proche va à contre-sens — la parallaxe vraie ;
///   · l'ouverture (`ouvert` 0 → 1) : les plans PARTENT du proche au
///     lointain — le rocher grossit et sort du cadre, le cerf vient se
///     poser, la lune ne bouge pas : la traversée du verre ;
///   · l'approche (`zoom` 1 → 2) : pincer, c'est avancer — les plans
///     s'écartent, le proche sort, le lointain reste.
/// Le doigt qui glisse promène tout (`pan`), avec une part différentielle :
/// le proche suit plus que le lointain.
struct MondePlans: View {
    var plans: [(image: UIImage, profondeur: Float, nom: String)]
    var taille: CGSize
    var tilt: SIMD2<Float>
    var ouvert: CGFloat
    var pan: CGSize
    var zoom: CGFloat

    /// Le pivot : ce qui est à cette profondeur ne bouge pas.
    private static let pivot: CGFloat = 0.45
    /// La course de parallaxe à pleine inclinaison, monde ouvert (points).
    private static let course: CGFloat = 46
    /// Le sur-balayage : chaque plan est un peu plus grand que l'écran, pour
    /// que sa course ne découvre jamais son bord.
    private static let marge: CGFloat = 1.12

    var body: some View {
        ZStack {
            ForEach(Array(plans.enumerated()), id: \.offset) { _, p in
                let rel = CGFloat(p.profondeur) - Self.pivot            // + loin, − proche
                let proche = max(0, -rel)                               // 0 au pivot, ~0,2 au premier plan
                // la traversée : le proche grandit en s'ouvrant ; l'approche : il grandit encore
                let echelle = Self.marge
                    * (1 + ouvert * proche * 0.85)
                    * (1 + (zoom - 1) * (0.35 + 1.6 * proche))
                let c = Self.course * ouvert
                let dx = -CGFloat(tilt.x) * rel * c - pan.width * rel * 0.30
                let dy = -CGFloat(tilt.y * 0.72) * rel * c - pan.height * rel * 0.30
                    + ouvert * proche * 70          // le proche descend : on passe au-dessus
                Image(uiImage: p.image)
                    .resizable()
                    .frame(width: taille.width, height: taille.height)
                    .scaleEffect(echelle)
                    .offset(x: dx + pan.width, y: dy + pan.height)
            }
        }
    }
}
