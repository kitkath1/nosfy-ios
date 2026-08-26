import SwiftUI

// MARK: - Le vol lointain
//
// Pendant les voiles de l'éclipse, une poignée d'oiseaux traverse la nuit —
// très loin, en contre-jour. Ils ne sont VISIBLES que là où ils croisent la
// lueur de la lune : ce sont des silhouettes opaques posées sur un ciel déjà
// noir, exactement comme au cinéma. C'est leur distance qui les rend sûrs —
// un corbeau de près est un dessin animé ; six battements d'ailes minuscules
// devant une lune, c'est du film muet.
//
// Fonction pure de `age`, comme tout le plan : la volée se rejoue à
// l'identique et se fige sous `-moonSplashFreeze`.
struct NightBirds: View {
    /// Secondes depuis le départ de la volée. Négatif = rien.
    var age: Double
    /// Le centre de la lune à l'écran — les trajectoires passent dessous.
    var moon: CGPoint
    /// L'ÉCHELLE DE LA VOLÉE. 1 = le réglage d'origine, calé sur la lune
    /// PLEIN ÉCRAN du plan-séquence.
    ///
    /// ⚠️ La Lune de Sang, elle, fait ~200 pt de large : à l'échelle 1 les
    /// oiseaux mesuraient 7 pt d'envergure pour un trait de 1,1 — mesuré à la
    /// sonde, ils étaient bien dessinés et bien placés, mais indiscernables.
    /// Ce n'est pas un défaut du composant : c'est une distance qui n'est plus
    /// la même. Le réglage de l'archive n'est pas touché (défaut 1).
    var echelle: CGFloat = 1
    /// LE PLUMAGE. Le défaut est la silhouette NOIRE de l'archive — le vrai
    /// contre-jour, qui suppose un DISQUE LUMINEUX derrière l'oiseau.
    ///
    /// ⚠️ **CETTE SUPPOSITION TOMBE SUR LA LUNE DE SANG**, et c'est mesuré :
    /// là-bas il n'y a pas de disque, seulement un croissant de néon
    /// (`soloNeon: 1`). Le ciel sous les six trajectoires y pèse **18,4/255
    /// de moyenne** (médiane 13,7) — un trait noir n'y creuse que 17/255 de
    /// contraste, sur 2,6 pt de large. C'est indiscernable, et c'est pour ça
    /// que Kathryn les cherche encore.
    ///
    /// Quand il n'y a rien derrière pour les découper, les oiseaux doivent
    /// être ÉCLAIRÉS par la seule source de la scène — la lune. Un plumage
    /// ivoire tiède rend le même plan, mais lisible.
    var plumage: Color = .black.opacity(0.92)
    /// LA LUMIÈRE DE LA SCÈNE, 0…1 — les oiseaux MEURENT AVEC LA LUNE. Sans
    /// elle, un plumage clair resterait posé sur un écran déjà noir pendant
    /// toute l'extinction.
    var lumiere: Double = 1
    /// LA FORME. L'archive vole des OISEAUX (deux courbes lisses). La Lune de
    /// Sang vole des **CHAUVES-SOURIS** (verdict 26-08) : à cette taille, ce
    /// qui distingue les deux n'est ni la taille ni la couleur, c'est
    /// l'ANGULARITÉ — pointes franches, coude marqué, échancrure au bord de
    /// fuite. Une courbe molle lit « mouette » quoi qu'on fasse.
    var forme: Forme = .oiseau
    enum Forme { case oiseau, chauveSouris }
    /// LA BANDE DE VOL, en points autour du centre de la lune. Elle règle la
    /// HAUTEUR du couloir ; c'est elle qui décide si la volée passe dans le
    /// halo du croissant ou au-dessus.
    ///
    /// ⚠️ **ET VOICI CE QU'UNE SILHOUETTE NOIRE PEUT ESPÉRER, MESURÉ.**
    /// Le long du couloir (bande −65 → +22 pt), la luminance n'est PAS
    /// uniforme : elle vaut 5-12/255 sur les bords de l'écran et ne monte que
    /// dans le tiers central, là où vit le croissant —
    ///
    ///     x        0    60   120   140   160   200   260   300   360   400
    ///     lum    9,8   6,9  19,3  58,4 182,9  87,9 112,1  45,1  24,5  20,8
    ///
    /// donc **une zone claire de x 140 à 300 pt sur 402**. Une chauve-souris
    /// noire n'est donc visible que pendant sa traversée de ce tiers — environ
    /// **une seconde par individu** — et invisible ailleurs.
    ///
    /// ⚠️ **CE N'EST PAS UN DÉFAUT, C'EST LE PLAN** : « ils ne sont visibles
    /// que là où ils croisent la lueur de la lune ». Une silhouette, par
    /// définition, n'existe que contre de la lumière. Ne pas « corriger » ça
    /// en les éclaircissant — l'ivoire a été essayé le 26-08 et REFUSÉ.
    /// C'est aussi pourquoi la volée est passée à douze : il faut qu'à chaque
    /// instant l'une d'elles soit dans le tiers clair.
    ///
    /// ⚠️ Piège de mesure payé au passage : moyenner la luminance sur TOUTE la
    /// largeur fait dire au halo qu'il porte partout (il donnait 41-95/255) —
    /// c'est le croissant qui gonflait la moyenne. Le profil se lit en x,
    /// jamais en moyenne de bande.
    var bande: ClosedRange<Double> = -34 ... 58
    /// Le nombre d'individus. L'archive en vole six.
    var nombre: Int = 6
    /// LA PROFONDEUR : deux ou trois plans au lieu d'un seul rideau. Les
    /// lointaines sont plus petites, plus lentes et plus fondues ; les proches
    /// plus grandes et plus vives. ⚠️ `false` par défaut — l'archive garde son
    /// rideau plat, au pixel près.
    var profondeur: Bool = false
    /// `-corbeauxSonde` : la volée en ROUGE, pour vérifier qu'elle est
    /// dessinée et OÙ — des silhouettes noires sur une nuit noire ne se
    /// prouvent pas à l'œil. ⚠️ Et c'est elle qui a prouvé le VRAI défaut du
    /// 26-08 : zéro pixel rouge à l'écran, alors que la partition plaçait les
    /// six oiseaux au centre — ils n'étaient pas invisibles, ils n'étaient
    /// pas dessinés (un TupleView sans conteneur, côté `LuneDeSangView`).
    static let sonde = CommandLine.arguments.contains("-corbeauxSonde")

    var body: some View {
        Canvas(opaque: false, colorMode: .nonLinear,
               rendersAsynchronously: false) { ctx, size in
            guard age >= 0 else { return }
            for i in 0..<nombre {
                let h1 = Self.hash(i, 3), h2 = Self.hash(i, 17)
                let h3 = Self.hash(i, 31)
                // LE PLAN DE PROFONDEUR : 0,50 au fond, 1,00 au premier plan.
                // Fixé à 1 quand `profondeur` est faux — l'archive intacte.
                let loin: Double = profondeur
                    ? 0.50 + 0.50 * Self.hash(i, 53) : 1.0

                // Une volée lâche : chacun part à son heure, sur sa ligne.
                let a = age - (Double(i) * 0.16 + 0.4 * h1)
                guard a > 0 else { continue }

                // Traversée de droite à gauche — trois secondes et des
                // poussières, chacun à son allure. Les proches vont plus vite :
                // c'est la parallaxe, et c'est elle qui fait la profondeur bien
                // plus que la taille.
                let span: Double = Double(size.width) + 160.0
                let v: Double = span / ((3.1 + 0.6 * h2) / loin)
                let xd: Double = Double(size.width) + 60.0 - v * a
                guard xd > -60.0 else { continue }
                let drift: Double =
                    bande.lowerBound
                    + (bande.upperBound - bande.lowerBound) * h3
                let bob: Double = 9.0 * sin(a * 1.3 + h1 * 6.3)
                let x = CGFloat(xd)
                let y = moon.y + CGFloat(drift + bob)

                let w = CGFloat(3.2 + 3.4 * h2) * echelle * CGFloat(loin)
                let phase: Double = a * 2.0 * Double.pi * (2.6 + 1.6 * h1)
                let flap = CGFloat(sin(phase + h3 * 6.3))
                let tip: CGFloat = -w * (0.55 * flap + 0.15)

                var p = Path()
                switch forme {
                case .oiseau:
                    // Le glyphe du lointain : deux courbes, les ailes battent.
                    p.move(to: CGPoint(x: x - w, y: y + tip))
                    p.addQuadCurve(to: CGPoint(x: x, y: y),
                                   control: CGPoint(x: x - w * 0.45,
                                                    y: y + w * 0.22))
                    p.addQuadCurve(to: CGPoint(x: x + w, y: y + tip),
                                   control: CGPoint(x: x + w * 0.45,
                                                    y: y + w * 0.22))
                case .chauveSouris:
                    // LA CHAUVE-SOURIS : une ligne brisée, jamais une courbe.
                    // Pointe → coude (le pli du bras) → échancrure du bord de
                    // fuite → petit corps → et le miroir. Les angles vifs
                    // (`miter`) font tout le travail à dix points d'envergure.
                    let coude = CGFloat(0.52), creux = CGFloat(0.24)
                    p.move(to: CGPoint(x: x - w, y: y + tip))
                    p.addLine(to: CGPoint(x: x - w * coude,
                                          y: y + tip * 0.30 + w * 0.10))
                    p.addLine(to: CGPoint(x: x - w * creux, y: y + w * 0.26))
                    p.addLine(to: CGPoint(x: x, y: y + w * 0.06))
                    p.addLine(to: CGPoint(x: x + w * creux, y: y + w * 0.26))
                    p.addLine(to: CGPoint(x: x + w * coude,
                                          y: y + tip * 0.30 + w * 0.10))
                    p.addLine(to: CGPoint(x: x + w, y: y + tip))
                }
                // Les lointaines sont plus fondues — l'air entre elle et nous.
                let voile = profondeur ? 0.60 + 0.40 * loin : 1.0
                ctx.stroke(p, with: .color(NightBirds.sonde
                                           ? .red
                                           : plumage.opacity(lumiere * voile)),
                           style: StrokeStyle(
                               lineWidth: 1.1 * echelle * CGFloat(loin),
                               lineCap: forme == .oiseau ? .round : .butt,
                               lineJoin: forme == .oiseau ? .round : .miter))
            }
        }
        .allowsHitTesting(false)
    }

    private static func hash(_ i: Int, _ salt: Int) -> Double {
        var v = UInt64(truncatingIfNeeded: i &* 0x9E3779B1 &+ salt &* 0x85EBCA6B)
        v ^= v >> 15; v = v &* 0x2545F491_4F6CDD1D; v ^= v >> 13
        return Double(v % 100_000) / 100_000
    }
}
