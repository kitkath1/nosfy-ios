import SwiftUI
import UIKit

// MARK: - LE CLAVIER DE BRAISE
//
// Le clavier du système ne se dessine pas : aucune API n'ouvre ses touches, et
// une extension de clavier ne vaut que hors de l'app. Pour que la lumière
// prenne DANS LES TOUCHES, le clavier doit être à nous — celui-ci est une vue
// SwiftUI posée au bas de la card, et le champ de recherche n'est plus un
// `TextField` mais du texte que nous dessinons (c'est le même choix : on ne
// peut pas allumer ce qu'on ne dessine pas).
//
// ⚠️ UN SEUL `Canvas` POUR TOUTES LES TOUCHES. Trente touches qui porteraient
// chacune sa `TimelineView` feraient trente horloges à 60 Hz et autant de
// calques animés — la loi 4 de la page exos. Ici : les touches sont des vues
// MORTES (une forme, une lettre, un liseré), et la lumière est un dessin
// unique posé par-dessus, qui lit la liste des touches récemment enfoncées.
//
// ⚠️ ET LA DISPOSITION EST CALCULÉE UNE FOIS, PARTAGÉE. Les touches et la
// lumière lisent la MÊME géométrie (`Clavier.disposition`) : deux calculs
// séparés sont condamnés à diverger d'un demi-point, et une lumière décalée
// d'un demi-point sur une touche, ça se voit tout de suite.

/// Ce qu'une touche fait.
enum ToucheSorte: Equatable {
    case lettre(String)
    case effacer
    case espace
    /// Range le clavier en gardant le mot — on va lire les résultats.
    case valider
}

/// Une touche posée : sa place, sa sorte. Un `struct` plat, calculé d'un coup.
struct Touche: Identifiable, Equatable {
    let id: Int
    let rect: CGRect
    let sorte: ToucheSorte

    var libelle: String {
        switch sorte {
        case .lettre(let l): return l
        case .effacer: return "delete.left"
        case .espace: return "espace"
        case .valider: return "checkmark"
        }
    }

    var estLettre: Bool { if case .lettre = sorte { return true }; return false }
}

enum Clavier {
    /// AZERTY, sans chiffres ni ponctuation : on cherche un exercice, pas on
    /// écrit une lettre. Les accents non plus — la recherche est déjà sourde
    /// aux accents (`ExosCatalogue.clef`), donc les taper ne sert à rien.
    static let rangs: [[String]] = [
        ["a", "z", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["q", "s", "d", "f", "g", "h", "j", "k", "l", "m"],
        ["w", "x", "c", "v", "b", "n"],
    ]

    static let marge: CGFloat = 5
    static let jeu: CGFloat = 6
    static let hTouche: CGFloat = 46
    static let rayon: CGFloat = 11

    /// La hauteur totale du clavier, hors zone sûre du bas.
    static let hauteur: CGFloat = 4 * hTouche + 3 * jeu + 2 * 9

    /// La disposition complète pour une largeur donnée. Les rangs courts sont
    /// CENTRÉS sur la largeur des rangs longs — un rang de six lettres calé à
    /// gauche fait un clavier bancal.
    static func disposition(_ w: CGFloat) -> [Touche] {
        let utile = w - 2 * marge
        let lw = (utile - 9 * jeu) / 10          // la largeur d'une lettre
        var out: [Touche] = []
        var id = 0
        var y = 9.0

        for rang in rangs {
            let n = CGFloat(rang.count)
            let large = n * lw + (n - 1) * jeu
            var x = marge + (utile - large) / 2
            for l in rang {
                out.append(Touche(id: id,
                                  rect: CGRect(x: x, y: y, width: lw, height: hTouche),
                                  sorte: .lettre(l)))
                id += 1
                x += lw + jeu
            }
            // L'EFFACEMENT vit au bout du rang court, à la place que le rang
            // long lui laisse : deux largeurs de lettre, collé au bord droit.
            if rang.count < 10 {
                let bw = 2 * lw + jeu
                out.append(Touche(id: id,
                                  rect: CGRect(x: w - marge - bw, y: y,
                                               width: bw, height: hTouche),
                                  sorte: .effacer))
                id += 1
            }
            y += hTouche + jeu
        }

        // LE DERNIER RANG : l'espace prend tout, la validation deux largeurs.
        let vw = 2 * lw + jeu
        out.append(Touche(id: id,
                          rect: CGRect(x: marge, y: y,
                                       width: w - 2 * marge - vw - jeu,
                                       height: hTouche),
                          sorte: .espace))
        id += 1
        out.append(Touche(id: id,
                          rect: CGRect(x: w - marge - vw, y: y,
                                       width: vw, height: hTouche),
                          sorte: .valider))
        return out
    }
}

/// Une touche enfoncée : laquelle, et quand. C'est TOUT ce que la lumière lit.
private struct Frappe: Identifiable, Equatable {
    let id: Int
    let touche: Int
    let ne: Date
}

// MARK: - Le clavier

struct ClavierBraise: View {
    @Binding var q: String
    /// La zone sûre du bas. ⚠️ La page IGNORE la zone sûre (c'est elle qui
    /// propose l'écran entier à son ZStack) : sans cette cote portée à la main,
    /// la rangée de l'espace se pose SOUS l'indicateur d'accueil, et le geste
    /// du système lui vole ses touches.
    let safeB: CGFloat
    /// Le rangement du clavier — la touche de validation, et rien d'autre.
    var valider: () -> Void

    /// Les frappes vivantes. On n'en garde que six : au-delà, la lumière de la
    /// septième est déjà morte, et la liste ne ferait que grossir sous les
    /// doigts rapides.
    @State private var frappes: [Frappe] = []
    @State private var compte = 0
    /// La touche sous le doigt — le verrou du poser (une frappe par toucher) et
    /// l'enfoncement visible.
    @State private var enfoncee: Int?

    /// Le grain du toucher. Préparé une fois — un générateur créé au moment du
    /// tap répond avec un temps de retard, et un clavier en retard est un
    /// clavier mort.
    private static let grain: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        return g
    }()

    var body: some View {
        GeometryReader { geo in
            let touches = Clavier.disposition(geo.size.width)
            ZStack(alignment: .topLeading) {
                // LES TOUCHES — des vues MORTES. Aucune ne lit l'horloge.
                //
                // ⚠️ ELLES PARTENT AU POSER DU DOIGT, pas au relâcher. Un
                // `onTapGesture` attend que le doigt se lève : sur un clavier,
                // ce délai-là est exactement ce qui fait « cheap ». D'où le
                // `DragGesture(minimumDistance: 0)` et son verrou, qui ne tire
                // qu'une fois par toucher.
                ForEach(touches) { t in
                    ToucheVerre(touche: t, enfoncee: enfoncee == t.id)
                        .frame(width: t.rect.width, height: t.rect.height)
                        .position(x: t.rect.midX, y: t.rect.midY)
                        .gesture(DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard enfoncee != t.id else { return }
                                enfoncee = t.id
                                frapper(t)
                            }
                            .onEnded { _ in enfoncee = nil })
                }
                // LA LUMIÈRE — un seul dessin, posé PAR-DESSUS en `plusLighter`
                // pour que la touche s'allume au lieu d'être recouverte.
                LumiereTouches(touches: touches, frappes: frappes,
                               gel: ExosBanc.frappe)
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            // ⚠️ LE BLEND S'ISOLE. Sans groupe, le `plusLighter` va chercher la
            // vidéo rouge de la page dessous et le clavier entier vire à
            // l'orange.
            .compositingGroup()
        }
        .frame(height: Clavier.hauteur)
        .padding(.bottom, safeB)
        .background {
            // LA DALLE : du noir OPAQUE, jamais un matériau — un
            // `.ultraThinMaterial` n'a que du noir à flouter et rend sa propre
            // matière grise (le piège du calque, payé au bandeau du titre).
            //
            // ⚠️ ET VRAIMENT OPAQUE. À 0,94, les 6 % restants suffisaient à
            // faire passer la MOLETTE au travers : ses graduations et son mot
            // « Tout » flottaient entre les touches. Un clavier translucide sur
            // une scène vivante ne se lit pas comme un parti pris, il se lit
            // comme un bug.
            ZStack(alignment: .top) {
                Color.black
                LinearGradient(colors: [.white.opacity(0.085), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 1.2)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onAppear {
            guard let n = ExosBanc.touche else { return }
            compte += 1
            frappes = [Frappe(id: compte, touche: n, ne: .now)]
            // Figée par `-exosFrappe`, la braise n'a pas besoin d'être relancée.
            guard ExosBanc.frappe == nil else { return }
            Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { _ in
                compte += 1
                frappes = [Frappe(id: compte, touche: n, ne: .now)]
            }
        }
    }

    private func frapper(_ t: Touche) {
        Self.grain.impactOccurred(intensity: t.estLettre ? 0.55 : 0.75)
        Self.grain.prepare()
        switch t.sorte {
        case .lettre(let l): q += l
        case .espace: if !q.isEmpty, q.last != " " { q += " " }
        case .effacer: if !q.isEmpty { q.removeLast() }
        case .valider: valider(); return
        }
        compte += 1
        frappes.append(Frappe(id: compte, touche: t.id, ne: .now))
        if frappes.count > 6 { frappes.removeFirst(frappes.count - 6) }
    }
}

// MARK: - Une touche

/// Le galet de la famille diamant : une forme sombre, un liseré qui n'est vif
/// qu'en haut, la lettre à l'encre argent. Pas de verre natif ici — un
/// `glassEffect` givre le contenu NET posé dessus (la loi du liquid glass), et
/// une lettre, c'est du contenu net.
private struct ToucheVerre: View {
    let touche: Touche
    /// Le doigt est dessus. La touche s'ENFONCE — 3 % suffisent : au-delà, un
    /// clavier qui rebondit se lit comme un jouet.
    var enfoncee = false

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: Clavier.rayon, style: .continuous)
        ZStack {
            forme.fill(Color.white.opacity(touche.estLettre ? 0.055 : 0.028))
            forme.strokeBorder(WoopGradient.diamondRim, lineWidth: 0.6)
                .opacity(touche.estLettre ? 0.55 : 0.34)
            contenu
        }
        .scaleEffect(enfoncee ? 0.97 : 1)
        .animation(.spring(response: 0.20, dampingFraction: 0.7), value: enfoncee)
    }

    @ViewBuilder private var contenu: some View {
        switch touche.sorte {
        case .lettre(let l):
            Text(l.uppercased())
                .font(.inter(18, .medium))
                .foregroundStyle(WoopGradient.silverText)
        case .espace:
            Text("espace")
                .font(.inter(12, .medium))
                .tracking(0.8)
                .foregroundStyle(Color.white.opacity(0.34))
        case .effacer:
            Image(systemName: "delete.left")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.52))
        case .valider:
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BraiseEcriture.braise)
        }
    }
}

// MARK: - La lumière des touches

/// L'ALLUMAGE. Une touche enfoncée devient un charbon : le cœur s'ouvre d'un
/// coup, le liseré prend le feu, et tout se referme en un demi-battement.
///
/// La courbe n'est pas une simple décroissance : une lumière qui apparaît à son
/// maximum et retombe, c'est un flash d'appareil photo — c'est ça qui fait
/// « cheap ». Ici il y a une ATTAQUE (deux centièmes pour monter) et une TRAÎNE
/// longue et basse. C'est la différence entre un éclair et une braise.
private struct LumiereTouches: View {
    let touches: [Touche]
    let frappes: [Frappe]
    /// LE BANC (`-exosFrappe`) : l'âge imposé de la braise.
    let gel: Double?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            Canvas { ctx, _ in
                for f in frappes {
                    guard f.touche < touches.count else { continue }
                    let t = touches[f.touche]
                    let age = gel ?? max(0, tl.date.timeIntervalSince(f.ne))
                    guard age < 0.9 else { continue }
                    // L'attaque puis la traîne — jamais un flash.
                    let monte = min(age / 0.035, 1)
                    let vie = monte * exp(-(age - 0.035) * 4.6)
                    guard vie > 0.004 else { continue }

                    let c = CGPoint(x: t.rect.midX, y: t.rect.midY)
                    let forme = Path(roundedRect: t.rect,
                                     cornerRadius: Clavier.rayon,
                                     style: .continuous)

                    // 1. LE CHARBON — la braise DANS la touche, découpée par sa
                    // forme : une lueur ronde qui déborde ferait un halo posé
                    // SUR le clavier, pas une touche allumée.
                    //
                    // ⚠️ IL EST POSÉ BAS (62 % de la hauteur), pas au centre.
                    // Une braise TOMBE au fond de son creuset ; centrée, elle
                    // fait un rond de lumière derrière la lettre — un état de
                    // sélection, pas un charbon.
                    let bas = CGPoint(x: c.x, y: t.rect.minY + t.rect.height * 0.66)
                    ctx.drawLayer { l in
                        l.clip(to: forme)
                        let r = max(t.rect.width, t.rect.height) * 0.82
                        l.fill(Path(ellipseIn: CGRect(x: bas.x - r, y: bas.y - r,
                                                      width: 2 * r, height: 2 * r)),
                               with: .radialGradient(Gradient(stops: [
                                .init(color: BraiseEcriture.coeur.opacity(0.42 * vie),
                                      location: 0),
                                .init(color: BraiseEcriture.braise.opacity(0.50 * vie),
                                      location: 0.30),
                                .init(color: BraiseEcriture.profond.opacity(0.34 * vie),
                                      location: 0.66),
                                .init(color: BraiseEcriture.profond.opacity(0),
                                      location: 1)]),
                                     center: bas, startRadius: 0, endRadius: r))
                    }
                    // 2. LE LISERÉ QUI PREND. C'est LUI qui fait la matière :
                    // un trait net contre une lueur floue, l'œil lit du métal
                    // chauffé au lieu d'une tache orange.
                    //
                    // ⚠️ ET IL EST DÉGRADÉ, jamais uni. Un liseré orange d'une
                    // seule valeur tout autour, ce n'est pas du métal chaud :
                    // c'est un anneau de sélection. Froid en haut, blanc en
                    // bas — le bord près du charbon est celui qui brûle.
                    ctx.stroke(forme,
                               with: .linearGradient(
                                Gradient(stops: [
                                    .init(color: BraiseEcriture.profond.opacity(0.34 * vie),
                                          location: 0),
                                    .init(color: BraiseEcriture.braise.opacity(0.80 * vie),
                                          location: 0.52),
                                    .init(color: BraiseEcriture.coeur.opacity(0.98 * vie),
                                          location: 1)]),
                                startPoint: CGPoint(x: 0, y: t.rect.minY),
                                endPoint: CGPoint(x: 0, y: t.rect.maxY)),
                               lineWidth: 1.2)
                    // 3. LE SOUFFLE SOUS LA TOUCHE — la chaleur qui s'échappe
                    // par le bas, écrasée pour rester dans le rang.
                    ctx.drawLayer { l in
                        l.translateBy(x: c.x, y: t.rect.maxY - 2)
                        l.scaleBy(x: 1, y: 0.30)
                        let r = t.rect.width * 1.15
                        l.fill(Path(ellipseIn: CGRect(x: -r, y: -r,
                                                      width: 2 * r, height: 2 * r)),
                               with: .radialGradient(Gradient(stops: [
                                .init(color: BraiseEcriture.braise.opacity(0.22 * vie),
                                      location: 0),
                                .init(color: BraiseEcriture.profond.opacity(0),
                                      location: 1)]),
                                     center: .zero, startRadius: 0, endRadius: r))
                    }
                }
            }
        }
    }
}
