import SwiftUI
import AVFoundation

// MARK: - VARIANT 3 « LA CHÂSSE »

/// *(une châsse : le coffret d'orfèvrerie où l'on garde une relique)*
///
/// LE TROISIÈME REGISTRE, et c'est sa raison d'être : le variant 1 dit un
/// ÉTAT (la jauge), le variant 2 une EXCLAMATION (le mot) — celui-ci est une
/// **MATIÈRE**. Ni jauge, ni typo : un objet précieux. C'est pour ça qu'on
/// n'a PAS remis un mot géant derrière la chauve-souris — ç'aurait été le
/// variant 2 repeint, et trois cards doivent offrir trois réponses.
///
/// Quatre couches, toutes empruntées à la cuisine de la maison :
/// 1. **Nosfy** (`nosfy-notif-loop.mp4`) sur son noir vrai — ✅ **aucun
///    détourage, donc aucun masque** : la seule vidéo des trois cards qui ne
///    coûte pas de rendu hors écran.
/// 2. **La poudre qui naît de ses AILES** — la règle de StoryWin (« la poudre
///    naît DU mouvement ») avec, ici, une cause littérale.
/// 3. **Le « +20 » ET SON HALO** — la recette `nappesOr` de `StorySuite` :
///    la lumière NAÎT DANS le chiffre et respire. ⚠️ C'est le CHIFFRE qui est
///    le bijou : toute la dépense tombe sur l'information, c'est ce qui sépare
///    une notification d'un fond d'écran. (Le chrome irisé a été essayé puis
///    RETIRÉ — verdict du 29-08.)
/// 4. **Le galet de VRAI verre** (`GaletVerre`, réutilisé tel quel) qui
///    dérive et réfracte la bête.
///
/// ⚠️ **LA DÉRIVE DU GALET EST BORNÉE À DROITE, ET C'EST LA LOI DU VERRE QUI
/// L'IMPOSE, PAS LA COMPOSITION.** `.clear` réfracte aux bords mais GIVRE
/// l'intérieur : il ne marche que sur du contenu DOUX. Nosfy sur du noir est
/// doux (une masse sombre, des ailes floues) — le chiffre, lui, est NET.
/// Le galet ne doit donc jamais le survoler.
struct NotifChasse: View {
    var gain: Int = 20
    var libelle: String = "COINS EARNED"
    /// L'entrée est POSÉE.
    var pose: Bool
    var naissance: Date

    /// Le progrès de l'entrée — sa propre rampe, comme dans les deux autres
    /// cards (un seul `withAnimation` par card et par tour : deux au même
    /// tour ne font RIEN).
    @State private var progres: Double = 0

    /// La bête : le fichier fait 640×306 (ratio 2,09), on ne le déforme pas.
    private static let largeurNosfy: CGFloat = 218
    private static let hauteurNosfy: CGFloat = 218 * 306 / 640

    var body: some View {
        ZStack {
            VideoBete(nom: "nosfy-notif-loop")
                .frame(width: Self.largeurNosfy, height: Self.hauteurNosfy)
                .allowsHitTesting(false)
            PoudreAiles(naissance: naissance, p: progres)
            colonne
            galet
            lueurDuCoin
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(RobeSocle())
        .onAppear(perform: caler)
        .onChange(of: pose) { _, _ in caler() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plus \(gain) \(libelle).")
    }

    private func caler() {
        guard !NotifBanc.fige else {
            progres = pose ? 1 : 0
            return
        }
        withAnimation(.easeOut(duration: 1.1)) {
            progres = pose ? 1 : 0
        }
    }

    // ── L'ENCRE, À GAUCHE

    private var colonne: some View {
        VStack(alignment: .leading, spacing: 2) {
            ChiffreHalo(valeur: progres * Double(gain),
                        naissance: naissance)
            Text(libelle)
                .font(.inter(11, .semibold))
                .tracking(1.6)
                .foregroundStyle(Color.inkSecondary)
                .opacity(progres)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .leading)
        .padding(.leading, NotifGeo.pad)
    }

    // ── LE FOND

    /// ⚠️⚠️ **LA NAPPE DU HAUT EST MORTE, ET SA CAUSE VAUT D'ÊTRE ÉCRITE**
    /// (verdict du 29-08 : « on voit la vidéo Nosfy, c'était mieux avant,
    /// enlève le spotlight »).
    ///
    /// Elle était posée **DERRIÈRE** la vidéo. Or le noir d'une couche
    /// vidéo est OPAQUE : il occultait la lueur à l'intérieur de son
    /// rectangle et la laissait voir tout autour. **C'est la lumière
    /// derrière qui dessinait le rectangle** — pas la vidéo elle-même. La
    /// sonde avait relevé le pas (10/255) et je l'avais jugé négligeable ;
    /// sur du noir vrai il ne l'est pas.
    ///
    /// Corollaire à retenir : **on ne pose jamais une lumière derrière un
    /// plan opaque** — elle en trace la silhouette. Si une lueur doit
    /// vivre, elle vit DEVANT, et là où le plan n'est pas.
    ///
    /// Ce qui reste : une lueur **très légère, dans le coin bas droit**
    /// (sa consigne), posée DEVANT tout le monde et hors du cadre de la
    /// bête — elle ne peut donc rien silhouetter.
    private var lueurDuCoin: some View {
        GeometryReader { g in
            RadialGradient(
                stops: [
                    .init(color: .white.opacity(0.075), location: 0),
                    .init(color: .white.opacity(0.028), location: 0.34),
                    .init(color: .white.opacity(0.008), location: 0.62),
                    .init(color: .clear, location: 1)
                ],
                center: .center, startRadius: 0, endRadius: 120)
            .frame(width: 240, height: 240)
            .position(x: g.size.width * 0.94, y: g.size.height * 1.02)
            .blendMode(.screen)
        }
        .allowsHitTesting(false)
    }

    // ── LE VERRE, À DROITE

    /// ⚠️ **IL DOIT ÊTRE POSÉ SUR LA BÊTE, PAS À CÔTÉ.** Premier jet : le
    /// galet vivait au bord droit, sur du noir pur — et il rendait un
    /// **disque GRIS opaque**, pas du verre. C'est la loi qui le dit :
    /// `.clear` réfracte aux bords et GIVRE l'intérieur, donc **sans
    /// nourriture il n'est qu'un givre**. Sur la card reward sa nourriture
    /// est le chiffre géant ; ici c'est Nosfy.
    ///
    /// D'où la position : sur l'AILE DROITE — du contenu doux, la seule
    /// matière que `.clear` sache plier — et loin du « +20 », qui est du
    /// contenu NET et que le verre givrerait.
    ///
    /// ⚠️⚠️ **DÉRIVE 0,34 → 0,12 : « ça fait bizarre le galet qui bouge »**
    /// (verdict du 29-08). Ce n'est PAS une question d'échelle mais de
    /// REGISTRE. Sa course vient de la card reward (±46 pt) : là-bas, dans
    /// une card PORTRAIT, ça flotte. Sur une bande de 138 pt de haut et 356
    /// de large, le même mouvement ne flotte plus — il GLISSE latéralement,
    /// comme un objet qu'on pousse. Dans une bande, un objet RESPIRE, il ne
    /// voyage pas. À 0,12 il palpite sur place — et la réfraction, seul
    /// intérêt du galet, ne demande aucun trajet.
    private var galet: some View {
        GaletVerre(naissance: naissance, diametre: 84, amplitude: 0.12)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 58)
    }
}

// MARK: - Le chiffre et son halo

/// LE « +20 » ET SA LUMIÈRE — la recette `nappesOr` de `StorySuite`, portée
/// sur un chiffre.
///
/// ⚠️ **LE CHROME IRISÉ EST MORT ICI** (verdict du 29-08 : « les dégradés
/// dans le chiffre n'ont rien à voir avec +20 ; un halo de lumière, fondu,
/// et animé »). Les deux passes croisées et le socle de métal froid
/// assombri ont sauté. Ce qui reste est plus simple et plus juste : la
/// lumière NAÎT DANS le chiffre et respire, elle ne le traverse pas.
///
/// ⚠️⚠️ **CE QU'ON GARDE DE L'ÉPISODE CHROME, PARCE QUE ÇA A ÉTÉ PAYÉ** :
/// un additif a besoin de **mi-tons sous lui** pour se lire. Sur un chiffre
/// blanc pur les nappes ne se verraient pas plus que l'irisation ne se
/// voyait (chroma mesurée **2,9/255** avant correction). L'argent du chiffre
/// est donc retenu — jamais du blanc plein.
///
/// ⚠️⚠️⚠️ **L'HORLOGE EST QUANTIFIÉE À 20 Hz.** Le mot de la story
/// recomposé à 60 Hz coûtait **41 img/s** (mesuré). Non négociable.
///
/// ⚠️ **LE GLYPHE EST ALIGNÉ LEADING**, et c'est une correction de BUG :
/// son cadre valait `corps × 2,6` avec le glyphe CENTRÉ dedans, pendant que
/// « COINS EARNED » vivait au bord gauche de la colonne — **21 pt de
/// décalage, relevés sur capture**.
///
/// `Animatable` sur la valeur : le chiffre MONTE avec la rampe d'entrée.
struct ChiffreHalo: View, Animatable {
    var valeur: Double
    let naissance: Date
    var corps: CGFloat = 52

    var animatableData: Double {
        get { valeur }
        set { valeur = newValue }
    }

    private var glyphe: some View {
        Text("+\(Int(valeur.rounded()))")
            .font(.inter(corps, .heavy).monospacedDigit())
            .tracking(-corps * 0.02)
            .fixedSize()
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let brut = NotifBanc.horloge(
                tl.date.timeIntervalSince(naissance))
            let t = (brut * 20).rounded() / 20
            corpsChiffre(t)
        }
        .frame(width: corps * 2.6, height: corps * 1.25,
               alignment: .leading)
    }

    private func corpsChiffre(_ t: Double) -> some View {
        ZStack(alignment: .leading) {
            halo(t)
            // LA GRAVURE — l'ombre interne sous l'encre : imprimé, pas posé.
            glyphe
                .foregroundStyle(Color.black.opacity(0.45))
                .offset(y: -1.6)
            // L'ARGENT RETENU — les mi-tons qui laissent la lumière se lire.
            glyphe
                .foregroundStyle(LinearGradient(
                    stops: Self.argent,
                    startPoint: .top, endPoint: .bottom))
            // LA LUMIÈRE QUI NAÎT DEDANS.
            //
            // ⚠️ **LES DEUX CADRES SONT IMPOSÉS, ET C'EST UNE CORRECTION DE
            // BUG.** Premier jet : `nappes(t).mask { glyphe }` — les nappes
            // sont un ZStack d'ellipses décalées, donc ses bornes sont plus
            // LARGES que le glyphe ; le masque s'y centrait et la copie
            // éclairée sortait décalée à gauche. À l'écran : un « + »
            // FANTÔME au bord de la dalle. Un masque n'aligne rien tout
            // seul — il faut que les deux vues partagent le même cadre.
            nappes(t)
                .frame(width: corps * 2.6, height: corps * 1.25,
                       alignment: .leading)
                .mask {
                    glyphe
                        .frame(width: corps * 2.6, height: corps * 1.25,
                               alignment: .leading)
                }
                .blendMode(.plusLighter)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// LES NAPPES — la recette de `StorySuite` : des bosses de lumière aux
    /// **périodes premières entre elles**, donc jamais un balayage et jamais
    /// un cycle qu'on puisse anticiper. ⚠️ Fonctions pures de `t` : aucun
    /// `repeatForever`, aucun compteur.
    private func nappes(_ t: Double) -> some View {
        let l = corps
        return ZStack {
            ForEach(0 ..< 6, id: \.self) { i in
                let h1 = NotifBanc.hash(i, 11)
                let h2 = NotifBanc.hash(i, 12)
                let h3 = NotifBanc.hash(i, 13)
                let u = (t / Self.periodes[i] + h1)
                    .truncatingRemainder(dividingBy: 1)
                let bosse = pow(max(0, sin(.pi * u)), 5.0)
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Self.lueur.opacity(0.42), .clear],
                        center: .center, startRadius: 0,
                        endRadius: l * CGFloat(0.22 + 0.16 * h2)))
                    .frame(width: l * CGFloat(0.52 + 0.40 * h2),
                           height: l * CGFloat(0.34 + 0.24 * h3))
                    .offset(x: l * (CGFloat(h1) - 0.5) * 1.35,
                            y: l * (CGFloat(h3) - 0.5) * 0.55)
                    .opacity(bosse)
            }
        }
    }

    /// LE HALO DERRIÈRE — il n'est plus un accompagnement à 0,085, il est LE
    /// sujet : plus large, plus présent, et il respire sur sa propre
    /// horloge (période première de celles des nappes).
    private func halo(_ t: Double) -> some View {
        let alpha: Double = 0.16 + 0.05 * sin(t * 0.37)
        return Ellipse()
            .fill(RadialGradient(
                colors: [Self.lueur.opacity(alpha), .clear],
                center: .center, startRadius: 2, endRadius: corps * 1.35))
            .frame(width: corps * 3.0, height: corps * 1.9)
            .offset(x: corps * 0.55)
    }

    // Les tables sortent en `static let` : le type-checker mord dessus.
    private static let lueur = Color(red: 0.90, green: 0.95, blue: 1.0)
    private static let periodes: [Double] = [3.7, 5.3, 7.1, 4.3, 6.7, 5.9]
    private static let argent: [Gradient.Stop] = [
        .init(color: Color(white: 0.90), location: 0),
        .init(color: Color(white: 0.72), location: 0.42),
        .init(color: Color(white: 0.78), location: 0.66),
        .init(color: Color(white: 0.52), location: 1)
    ]
}


// MARK: - La poudre née des ailes

/// LA POUDRE DE DIAMANT — la recette de la maison (Canvas sous TimelineView
/// 30 Hz, grains-étoiles DÉTERMINISTES par hash, l'additif demandé AU
/// CONTEXTE et jamais à la vue).
///
/// ⚠️ **ELLE NAÎT DU MOUVEMENT** — la règle de `StoryWin`, et ici la cause
/// est littérale : les grains montent des POINTES D'AILES, et leur densité
/// suit le battement (période 1,5 s, celle du fichier recuit). Une pluie
/// posée par-dessus n'aurait rien dit.
///
/// ⚠️ Jamais de `repeatForever` : tout est fonction pure de `t` (école
/// CalLab). Une horloge par effet, périodes premières entre elles.
struct PoudreAiles: View, Animatable {
    let naissance: Date
    /// L'entrée : la poudre ne tombe pas avant que la card soit là.
    var p: Double

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    /// La période du battement — celle du fichier recuit (51 img à 34 i/s).
    private static let battement: Double = 1.5
    private static let grains = 34
    /// L'écart des pointes d'ailes au centre de la dalle.
    private static let envergure: CGFloat = 96

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = NotifBanc.horloge(tl.date.timeIntervalSince(naissance))
            Canvas { ctx, size in
                var c = ctx
                // L'ADDITIF SE DEMANDE AU CONTEXTE, pas à la vue : posé sur
                // la vue il compose avec la dalle entière.
                c.addFilter(.colorMultiply(.white))
                c.blendMode = .plusLighter
                Self.semer(&c, size, t, p)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// ⚠️⚠️ **UN GRAIN DE POUDRE DE DIAMANT EST UNE ÉTOILE, PAS UN DISQUE**
    /// (verdict du 29-08 : « les particules ne sont pas de la poudre de
    /// diamant, elles sont beaucoup trop grosses »). Elle avait raison, et
    /// la recette de la maison était sous mon nez : `PoudreDiamant` dessine
    /// **deux losanges croisés** dont la demi-largeur ne vaut que **0,22 ×
    /// la longueur** — à rayon égal, une étoile est cinq fois plus fine
    /// qu'un disque. Plus un cœur de 0,9 pt, et c'est tout.
    ///
    /// ⚠️ Et le SCINTILLEMENT est **cubé** (`tw³`, 7 à 19 Hz) : les grains
    /// ne brillent pas en continu, ils PIQUENT. C'est ça qui fait la poudre
    /// — sans le cube, on obtient des points allumés en permanence.
    private static func semer(_ ctx: inout GraphicsContext, _ size: CGSize,
                              _ t: Double, _ p: Double) {
        guard p > 0.02 else { return }
        let cx = size.width / 2
        let cy = size.height / 2
        // LE BATTEMENT : les ailes se referment, la poudre part. Le front
        // est une fonction pure du temps, jamais un compteur.
        let phase = (t / battement).truncatingRemainder(dividingBy: 1)
        let souffle = pow(max(0, sin(phase * .pi)), 2.2)
        for i in 0..<grains {
            // Chaque grain appartient à une aile — gauche ou droite.
            let aile: CGFloat = NotifBanc.hash(i, 1) < 0.5 ? -1 : 1
            let vie = (t * (0.30 + NotifBanc.hash(i, 2) * 0.34)
                       + NotifBanc.hash(i, 3))
                .truncatingRemainder(dividingBy: 1)
            // Il naît à la pointe de l'aile et s'en éloigne en montant.
            let x = cx + aile * envergure * (0.72 + 0.34 * CGFloat(vie))
                + CGFloat(NotifBanc.hash(i, 4) - 0.5) * 26
            let y = cy - CGFloat(vie) * 44
                + CGFloat(NotifBanc.hash(i, 5) - 0.5) * 20
            // LA PIQÛRE — rapide et cubée : le grain clignote, il ne luit
            // pas. C'est la moitié de ce qui fait « de la poudre ».
            let tw = 0.5 + 0.5 * sin(t * (7 + 12 * NotifBanc.hash(i, 7))
                                     + NotifBanc.hash(i, 8) * 6.283)
            let a = (1 - vie) * (1 - vie) * souffle * p
                * (0.16 + 0.84 * tw * tw * tw) * 0.85
            guard a > 0.02 else { continue }
            let r = CGFloat(0.55 + 1.3 * NotifBanc.hash(i, 6))
            let teinte = NotifBanc.hash(i, 9) < 0.4
                ? Color.white
                : Color(red: 0.90, green: 0.95, blue: 1.00)
            ctx.fill(
                etoile(r).applying(
                    CGAffineTransform(translationX: x, y: y)
                        .rotated(by: (NotifBanc.hash(i, 10) - 0.5) * 0.9)),
                with: .color(teinte.opacity(a * 0.85)))
            // LE CŒUR — 0,9 pt, et pas un de plus.
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - 0.45, y: y - 0.45,
                                       width: 0.9, height: 0.9)),
                with: .color(Color.white.opacity(a * 0.9)))
        }
    }

    /// L'ÉTOILE À QUATRE BRANCHES — deux losanges croisés, demi-largeur
    /// 0,22 × la longueur. C'est la forme de la maison, à la lettre.
    private static func etoile(_ r: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -r, y: 0))
        p.addLine(to: CGPoint(x: 0, y: -r * 0.22))
        p.addLine(to: CGPoint(x: r, y: 0))
        p.addLine(to: CGPoint(x: 0, y: r * 0.22))
        p.closeSubpath()
        p.move(to: CGPoint(x: 0, y: -r))
        p.addLine(to: CGPoint(x: r * 0.22, y: 0))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addLine(to: CGPoint(x: -r * 0.22, y: 0))
        p.closeSubpath()
        return p
    }
}

// MARK: - La couche vidéo de Nosfy

/// ⚠️ **AUCUN MASQUE, ET C'EST TOUT L'INTÉRÊT.** Le fichier est sur du NOIR
/// VRAI : la bête se fond dans la dalle sans détourage, comme la vidéo de
/// `DepartSeance`. C'est la seule vidéo des trois cards qui ne force pas un
/// rendu hors écran de tout son plan à chaque image.
///
/// ⚠️ Le fichier a été RECUIT avant d'entrer (`nosfy-notif-loop.mp4`,
/// 640×306, 78 Ko) : la source faisait 3836×2160 / 4,7 Mo, soit 35× la
/// résolution utile pour un objet de ~110 pt.
///
/// ⚠️ **LA BOUCLE EST CUITE DANS LE FICHIER, ET SA COUTURE EST MESURÉE.**
/// Une coupe sèche à 1,5 s donnait un écart de 2,58 contre un plancher de
/// 0,48 entre deux images consécutives — **cinq fois le plancher**, un
/// claquement visible. Le battement NATUREL dure 51 images (2,125 s) et sa
/// couture vaut 0,996 : c'est ce cycle-là qu'on a pris, puis RETIMÉ à 1,5 s
/// (`trim + setpts` DANS le graphe — `-ss` ne coupe pas le graphe ffmpeg).
///
/// ⚠️ `Woop/Media` contient des ressources NUES : `Image(nom)` n'y trouve
/// RIEN, en silence. Le chargement passe par le bundle.
final class NosfyLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// ⚠️ **ELLE PORTE UN NOM DE FICHIER DEPUIS LE 24-09**, parce que deux robes
/// de plus s'en servent (`NotifAile`, `NotifClin`) et qu'un troisième calque
/// copié-collé aurait été un troisième `AVPlayerLooper` à corriger le jour où
/// celui-ci a un défaut. Le contrat ne change pas : un fichier sur du NOIR
/// VRAI, recuit à la taille utile, sa boucle cuite dedans.
struct VideoBete: UIViewRepresentable {
    /// Le nom du fichier `.mp4` dans le bundle — sans extension.
    var nom: String = "nosfy-notif-loop"

    final class Coordinator {
        var player: AVQueuePlayer?
        /// Relâché, la boucle s'arrête au premier tour et le plan se fige.
        var looper: AVPlayerLooper?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> NosfyLayerView {
        let v = NosfyLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.clipsToBounds = true
        v.layer.masksToBounds = true
        // Le cadre est au ratio EXACT du fichier : rien n'est recadré.
        v.playerLayer.videoGravity = .resizeAspect
        guard let url = Bundle.main.url(forResource: nom,
                                        withExtension: "mp4") else {
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        // AVPlayerLooper, JAMAIS un `seek(.zero)` sur `didPlayToEndTime` :
        // il laisse une image noire au raccord.
        context.coordinator.looper = AVPlayerLooper(
            player: p, templateItem: AVPlayerItem(url: url))
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        return v
    }

    func updateUIView(_ v: NosfyLayerView, context: Context) {}

    static func dismantleUIView(_ v: NosfyLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}
