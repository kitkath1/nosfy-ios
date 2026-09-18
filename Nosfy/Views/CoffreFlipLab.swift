import SwiftUI
import UIKit

// MARK: - LE RETOURNEMENT DE LA PIÈCE (chantier coffre v2, jalon C5)
//
// Le plan : `tools/coffre-v2/PLAN-COFFRE-V2.md` §4 et §6.3.
//
// POURQUOI UN RETOURNEMENT ET PAS UN MANÈGE À DEUX PIÈCES. Le manège demandait
// un `scaleEffect` et un `.blur` sur la pièce — les deux sont INTERDITS sur du
// verre natif par deux précédents mesurés du dépôt (`PorteEntree.swift:1274`
// « un `glassEffect` mis à l'échelle rend un BLUR PLAT », et
// `MenuCouronne.swift:32` « jamais un `.blur` : il ne sait pas s'arrêter en
// rond » → un voile CARRÉ sur un objet rond). Le retournement supprime le
// problème au lieu de l'arbitrer : il n'y a plus de voyage, donc plus rien à
// zoomer ni à flouter.
//
// ET SURTOUT : `moonCoin` SAIT DÉJÀ FAIRE ÇA. Le shader ne dessine pas un
// disque, il résout la silhouette EXACTE d'un cylindre en lacet (le minimum
// convexe de `|A − B·z| − R` sur l'épaisseur, MoonCoin.metal:97-101) et il
// peint sa TRANCHE (`:334`). Le retournement n'est donc pas une transformation
// SwiftUI posée sur une image : c'est le MÊME objet, vu sous un autre angle,
// calculé. C'est ce qui permettra au verre natif de rester à taille constante
// par-dessus (la loi des bounds vivants) — le verre ne bougera pas, c'est la
// pièce qui tournera dessous.
//
// ⚠️ LE RISQUE CONNU, ET C'EST CE QU'ON VIENT VÉRIFIER ICI. À 90° la face est
// vue par la tranche, et l'inverse du 2×2 de projection
// (`invDet = 1 / max(cos(yaw)·cos(pitch), 1e-5)`, MoonCoin.metal:86) EXPLOSE.
// Deux issues possibles, et seule la capture tranche : soit la pièce se réduit
// à un trait (ce qu'on veut), soit elle DISPARAÎT une image (la sortie
// anticipée `dSil > reach` prend la main). Le banc existe pour voir laquelle.
//
// Bancs :
//   -coffreFlip        la pièce en grand, retournable au doigt
//   -coffreFlipAuto    elle se retourne toute seule, en boucle (le sim ne
//                      pose pas de doigt : sans ça, rien n'est filmable)
//   -coffreFlipFige <deg>   un lacet imposé, pour les captures comparables
//                      (⚠️ le piège de Nyquist : deux captures d'un même
//                      réglage à deux angles différents font « corriger » du
//                      bruit d'angle au lieu de la matière)
//   -coffreFlipSol     la pièce posée sur le sol de la chambre (le fond de
//                      `backgroundcoffre` n'est pas encore cuit : en attendant,
//                      un dégradé calé sur les mesures du §1.2 du plan)

/// La pièce qui se retourne. UN objet, deux faces.
///
/// ⚠️ **CE N'EST PLUS `moonCoin`.** Le premier jet de ce banc montrait le palet
/// d'or de la maison, et le verdict est tombé net : « c'est pas liquid glass ».
/// Il avait raison — la référence de Kathryn n'est pas une pièce de métal, c'est
/// un **cabochon de verre** (cf. l'en-tête de `PieceVerre.metal` et les cotes
/// mesurées de son rendu). Ce banc monte donc `pieceVerre`, et `moonCoin` reste
/// à sa place : le bijou du header et du trésor.
///
/// L'or et le verre neutre ne sont pas deux pièces : c'est `teinte` qui bascule
/// **exactement au passage par la tranche**, là où aucune face n'est visible.
/// C'est ce qui fait qu'on lit un seul objet qu'on retourne, et non deux images
/// qui se remplacent.
struct PieceRetournee: View {
    /// Le lacet, en radians. 0 = le verre de face · π = l'or de face.
    var yaw: Double
    /// Rayon de la pièce, en points.
    var rayon: CGFloat = 66
    /// La vie au repos (flottement + respiration du néon).
    var vie: Float = 1
    /// Teinte imposée (les captures de calibrage) : 0 verre, 1 or.
    var teinteFixe: Float? = nil
    /// LE TANGAGE, en radians — c'est lui qui écrase l'ellipse. À zéro la pièce
    /// est un CERCLE, et c'est ce qui a coûté le premier tour (2,66/10 sur une
    /// pose fausse). La référence est à `acos(0,902)` = 25,6°.
    var tangage: Double = 0

    /// LA BASCULE DE MATIÈRE, cachée par la tranche.
    private var teinte: Float {
        if let t = teinteFixe { return t }
        return cos(yaw) >= 0 ? 0 : 1
    }

    /// L'hôte déborde : le bloom du verre porte plus loin que le métal, mais
    /// moins qu'on ne croit (`reach` mesuré à 0,34 R). 2,6 suffit, et chaque
    /// dixième de trop est du remplissage payé pour du vide.
    static let hostScale: CGFloat = 2.6

    var body: some View {
        let cote = rayon * Self.hostScale
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = Float(tl.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 900))
            Rectangle()
                .fill(.white)
                .frame(width: cote, height: cote)
                .colorEffect(ShaderLibrary.pieceVerre(
                    .float2(Float(cote), Float(cote)),
                    .float(t),
                    .float2(0, 0),
                    // ⚠️ Le lacet passe BRUT, sans la butée de 0,84 rad de
                    // `MoonCoinView` : cette butée existe pour un bijou qu'on
                    // fait osciller dans le header. Ici la pièce doit pouvoir
                    // faire son demi-tour entier.
                    .float(Float(yaw)),
                    .float(Float(rayon)),
                    .float(1),
                    .float(vie),
                    .float3(MoonSDF.padding, MoonSDF.tightRange, MoonSDF.wideRange),
                    .float3(0.5, 0.485, 0.71),
                    // rimIn MESURÉ sur sa référence : la face s'arrête à 0,62
                    // et le tore de verre occupe tout le reste.
                    // Le TANGAGE est le 4ᵉ curseur — c'est lui qui donne
                    // l'ellipse (cf. `PieceVerre.metal`).
                    .float4(MoonCoinView.knob("pieceRim", 0.62),
                            MoonCoinView.knob("pieceMoon", 0.865),
                            teinte, Float(tangage)),
                    .image(MoonSDF.image)))
        }
        .frame(width: cote, height: cote)
    }
}

// MARK: - Le banc

/// `-coffreFlip` : la pièce, en grand, qu'on retourne au pouce.
struct CoffreFlipLab: View {
    /// `-coffreFlipFige <deg>` : lacet imposé, vie coupée.
    private static let fige: Double? =
        (UserDefaults.standard.object(forKey: "coffreFlipFige") as? NSNumber)?
            .doubleValue
    private static let auto = CommandLine.arguments.contains("-coffreFlipAuto")
    private static let sol = CommandLine.arguments.contains("-coffreFlipSol")
    /// `-pieceCalibre` : LA POSE DE CALIBRAGE. La pièce SEULE, sur du noir
    /// absolu, au lacet et à la taille de la référence de Kathryn — c'est la
    /// seule image que `compare_piece.py` sait noter. Sans elle on compare
    /// deux objets vus sous deux angles et on « corrige » du bruit de pose.
    /// `-pieceCalibreOr` fait la même chose avec le verre ambre.
    static let calibre = CommandLine.arguments.contains("-pieceCalibre")
        || CommandLine.arguments.contains("-pieceCalibreOr")
    private static let calibreOr = CommandLine.arguments.contains("-pieceCalibreOr")

    /// Le lacet courant, en radians.
    @State private var yaw: Double = 0
    /// Le lacet au moment de la prise — sans lui, reprendre une pièce déjà
    /// tournée la ferait sauter à l'origine du doigt.
    @State private var yawPrise: Double = 0
    /// L'horloge de l'auto-retournement.
    @State private var depart = Date()

    /// Radians par point glissé. Une demi-tour (π) demande **270 pt** de
    /// pouce : assez pour que le geste ait du corps, assez peu pour qu'un
    /// balayage confortable suffise.
    private static let radParPoint: Double = .pi / 270

    /// LE CRAN. Une pièce ne s'immobilise pas de champ : au lâcher elle tombe
    /// sur la face la plus proche. C'est ça qui en fait un objet et pas un
    /// curseur.
    private func poser(_ elan: Double) {
        let vise = yaw + elan * Self.radParPoint * 0.35
        let cible = (vise / .pi).rounded() * .pi
        withAnimation(.spring(response: 0.52, dampingFraction: 0.82)) {
            yaw = cible
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
    }

    var body: some View {
        if Self.calibre { calibrage } else { banc }
    }

    /// LA POSE DE CALIBRAGE — la pièce seule, centrée, sur du noir absolu.
    ///
    /// ⚠️ Le lacet est celui de la référence, et il se DÉDUIT, il ne se choisit
    /// pas : son rendu montre une ellipse de ratio **0,902**, donc la normale
    /// de la face fait `acos(0,902) = 25,6°` avec l'axe de vue. Le shader
    /// ajoute 0,052 rad (3,0°) de lacet de repos, qu'on retranche.
    private var calibrage: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            PieceRetournee(yaw: 0,
                           rayon: 150,
                           vie: 0,
                           teinteFixe: Self.calibreOr ? 1 : 0,
                           // Le tangage de la référence, MOINS le tangage de
                           // repos du shader (−0,045 rad).
                           tangage: acos(0.902) + 0.045)
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
    }

    private var banc: some View {
        ZStack {
            if Self.sol {
                // LE SOL DE LA CHAMBRE, en attendant la cuisson de la vidéo.
                // Calé sur les mesures du plan §1.2 : noir absolu jusqu'à 45 %,
                // la barre à 49,4 %, le sol qui plafonne à L 152 et SE
                // DÉSATURE (sat 0,72 sous la barre → 0,02 en bas).
                GeometryReader { g in
                    let h = g.size.height
                    ZStack(alignment: .top) {
                        Color.black
                        LinearGradient(stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.455),
                            .init(color: Color(red: 1.0, green: 0.545, blue: 0.0),
                                  location: 0.492),
                            .init(color: Color(red: 1.0, green: 1.0, blue: 0.867),
                                  location: 0.4945),
                            .init(color: Color(red: 0.816, green: 0.378, blue: 0.226),
                                  location: 0.55),
                            .init(color: Color(red: 0.698, green: 0.557, blue: 0.539),
                                  location: 0.63),
                            .init(color: Color(red: 0.598, green: 0.584, blue: 0.586),
                                  location: 0.80),
                            .init(color: Color(red: 0.564, green: 0.559, blue: 0.563),
                                  location: 1.0)
                        ], startPoint: .top, endPoint: .bottom)
                        .frame(height: h)
                    }
                }
                .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            TimelineView(.animation(minimumInterval: Self.auto ? 1.0 / 60.0 : 3600)) { tl in
                // L'AUTO : un demi-tour toutes les 2,2 s, avec une pose de
                // 0,9 s sur chaque face. Le simulateur ne pose pas de doigt —
                // sans ce banc, le passage par la tranche n'est pas filmable,
                // et c'est précisément ce qu'on vient voir.
                let a: Double = {
                    guard Self.auto else { return yaw }
                    let cycle = 3.1
                    let e = tl.date.timeIntervalSince(depart)
                        .truncatingRemainder(dividingBy: cycle * 2)
                    let tour = e < cycle ? e : e - cycle
                    let base = e < cycle ? 0.0 : Double.pi
                    let p = min(max((tour - 0.9) / 2.2, 0), 1)
                    // easeInOut : elle démarre et finit doucement, comme une
                    // pièce qu'on retourne à la main.
                    let s = p * p * (3 - 2 * p)
                    return base + s * .pi
                }()
                PieceRetournee(yaw: Self.fige.map { $0 * .pi / 180 } ?? a,
                               rayon: 66,
                               vie: Self.fige == nil ? 1 : 0)
                    // La pièce est posée SUR le sol : son centre à 63 % de la
                    // hauteur, la cote du plan §3.4.
                    .position(x: UIScreen.main.bounds.width / 2,
                              y: Self.sol
                                 ? UIScreen.main.bounds.height * 0.63
                                 : UIScreen.main.bounds.height * 0.46)
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { v in
                        if yawPrise == .infinity { yawPrise = yaw }
                        yaw = yawPrise + v.translation.width * Self.radParPoint
                    }
                    .onEnded { v in
                        yawPrise = .infinity
                        poser(v.predictedEndTranslation.width
                              - v.translation.width)
                    }
            )

            // La légende du banc : l'angle, pour que la capture soit lisible.
            VStack {
                Spacer()
                Text(String(format: "%.0f°", yaw * 180 / .pi))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 28)
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .onAppear { yawPrise = .infinity }
    }
}
