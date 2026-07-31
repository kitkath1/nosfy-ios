import CoreGraphics
import simd

// MARK: - Le rail de la caméra du splash
//
// La cinématique d'ouverture suit le contour du croissant en gros plan : la
// caméra colle au tube de néon et le parcourt d'un bout à l'autre. Il lui
// faut donc, à chaque instant, un point et une direction SUR la courbe —
// et `MoonGlyph` ne donne que dix-huit cubiques de Bézier.
//
// POURQUOI L'ABSCISSE CURVILIGNE, ET PAS LE PARAMÈTRE t. Les dix-huit
// segments pèsent de 1,1 % à 14,0 % du périmètre (rapport 12,6) et, à
// l'intérieur d'un même segment, |B'(u)| descend jusqu'à 0,042 pour une
// moyenne de 0,66. Une caméra qui avancerait à t constant ferait donc des
// à-coups de facteur quinze sans qu'aucun accident de la courbe ne les
// justifie : elle sprinterait sur le dos du croissant et s'arrêterait net
// dans les cornes. On tabule les longueurs cumulées une fois pour toutes et
// on avance en LONGUEUR : la vitesse à l'écran devient celle qu'on écrit
// dans la partition, et rien d'autre.
//
// POURQUOI AUSSI UN ANGLE. La comète du shader n'a pas d'abscisse : elle est
// paramétrée par l'angle autour du centre de la LUT (la SDF n'offre rien de
// mieux, cf. LogoMonolith.metal). Pour que la caméra et la comète regardent
// le même endroit, le rail sait convertir son abscisse en angle DANS LA MÊME
// CONVENTION que le shader — c'est `angle(at:)`, et l'hôte du splash pilote
// la tête de la comète avec. Attention : cet angle n'est PAS monotone le
// long du contour (les deux parois du croissant partagent le même angle,
// c'est la raison d'être du procédé côté shader) — il ne peut donc jamais
// servir à ordonner le parcours, uniquement à le traduire.
//
// Repère : espace unité de `MoonGlyph`, y VERS LE BAS, parcours HORAIRE à
// l'écran, intérieur du croissant à droite du sens de marche.
enum MoonPath {

    // MARK: La table des longueurs

    /// Échantillons par cubique. 64 suffisent largement : l'erreur de corde
    /// décroît en 1/N², et à 64 la longueur totale est stable à 1e-6 près.
    private static let steps = 64

    /// (longueurs cumulées depuis le départ, une entrée par échantillon + la
    /// fermeture ; et la longueur de chaque cubique).
    private static let table: (cum: [Float], segLen: [Float], total: Float) = {
        var cum: [Float] = [0]
        var segLen: [Float] = []
        cum.reserveCapacity(MoonGlyph.segments.count * steps + 1)
        var running: Float = 0
        for i in 0..<MoonGlyph.segments.count {
            var prev = point(segment: i, u: 0)
            var acc: Float = 0
            for k in 1...steps {
                let cur = point(segment: i, u: Float(k) / Float(steps))
                acc += simd_distance(prev, cur)
                running += simd_distance(prev, cur)
                cum.append(running)
                prev = cur
            }
            segLen.append(acc)
        }
        return (cum, segLen, running)
    }()

    /// Le périmètre du croissant, en unités-croissant. Mesuré : 3,977090.
    static var perimeter: Float { table.total }

    // MARK: Évaluation des cubiques

    /// Les quatre points de contrôle d'une cubique — le premier étant
    /// l'arrivée de la précédente (le chemin est fermé, sans doublon).
    private static func controls(_ i: Int)
        -> (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>) {
        let seg = MoonGlyph.segments[i]
        let prev = i == 0 ? MoonGlyph.startPoint : MoonGlyph.segments[i - 1].end
        return (SIMD2(Float(prev.x), Float(prev.y)),
                SIMD2(Float(seg.c1.x), Float(seg.c1.y)),
                SIMD2(Float(seg.c2.x), Float(seg.c2.y)),
                SIMD2(Float(seg.end.x), Float(seg.end.y)))
    }

    private static func point(segment i: Int, u: Float) -> SIMD2<Float> {
        let (p0, c1, c2, p3) = controls(i)
        let v = 1 - u
        return v * v * v * p0 + 3 * v * v * u * c1
             + 3 * v * u * u * c2 + u * u * u * p3
    }

    /// La dérivée de Bernstein. Elle ne s'annule nulle part à l'intérieur des
    /// segments (minimum mesuré 0,042) : la tangente est définie partout sauf
    /// aux deux cornes, où elle SAUTE de ~160° — c'est une propriété de la
    /// forme, pas un défaut, et la partition du splash y ralentit.
    private static func derivative(segment i: Int, u: Float) -> SIMD2<Float> {
        let (p0, c1, c2, p3) = controls(i)
        let v = 1 - u
        return 3 * v * v * (c1 - p0) + 6 * v * u * (c2 - c1) + 3 * u * u * (p3 - c2)
    }

    // MARK: Le rail

    struct Sample {
        /// En espace unité `MoonGlyph`.
        var position: SIMD2<Float>
        /// Normalisée, dans le sens de parcours des segments.
        var tangent: SIMD2<Float>
    }

    /// Le point du contour à l'abscisse curviligne normalisée `s` ∈ [0,1),
    /// repliée proprement en dehors (le contour est fermé : la caméra peut
    /// faire plusieurs tours sans cas particulier).
    static func sample(at s: Float) -> Sample {
        let (seg, u) = locate(s)
        let d = derivative(segment: seg, u: u)
        let len = simd_length(d)
        return Sample(position: point(segment: seg, u: u),
                      tangent: len > 1e-6 ? d / len : SIMD2(1, 0))
    }

    /// s normalisé → (cubique, paramètre local). Recherche binaire dans la
    /// table puis interpolation linéaire entre deux échantillons : à 64 pas
    /// par cubique, l'erreur de vitesse résiduelle reste sous le pour mille.
    private static func locate(_ s: Float) -> (Int, Float) {
        let cum = table.cum
        let target = (s - s.rounded(.down)) * table.total
        var lo = 0, hi = cum.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if cum[mid] <= target { lo = mid } else { hi = mid }
        }
        let span = max(cum[hi] - cum[lo], 1e-9)
        let frac = min(max((target - cum[lo]) / span, 0), 1)
        let seg = min(lo / steps, MoonGlyph.segments.count - 1)
        let k = lo - seg * steps
        return (seg, (Float(k) + frac) / Float(steps))
    }

    // MARK: Traductions d'espace

    /// Le centre du carré de la LUT, en espace unité (cf. MoonSDF).
    private static let lutCenter = SIMD2<Float>(0.5, Float(MoonGlyph.unitHeight) / 2)

    /// Espace unité → coordonnée de texture de la LUT — la MÊME formule que
    /// `MoonSDF.makeLUT`, d'où la constante de padding partagée.
    static func lutUV(_ p: SIMD2<Float>) -> SIMD2<Float> {
        (p - lutCenter) / MoonSDF.padding + 0.5
    }

    /// L'angle « comète » d'un point du contour, dans la convention EXACTE du
    /// shader (`atan2(uv.y − 0,5 ; uv.x − 0,5)/2π + 0,5`), replié dans [0,1).
    /// Non monotone le long du contour : à ne jamais utiliser pour ordonner.
    static func angle(at s: Float) -> Float {
        let uv = lutUV(sample(at: s).position) - 0.5
        let a = atan2(uv.y, uv.x) / (2 * .pi) + 0.5
        return a - a.rounded(.down)
    }

    /// Espace unité → point de la FACE AVANT du monolithe, en points de
    /// scène. Obtenu en inversant la chaîne du shader
    /// `uv = (pF/(2·faceR) + 0,5 − moonPlace.xy)/(padding·k) + 0,5`
    /// puis en y injectant `uv = (p − centre)/padding + 0,5` : le padding se
    /// simplifie et il reste une simple homothétie de rapport 2·faceR·k —
    /// soit 107,9 pt par unité-croissant au cadrage nominal.
    static func facePoint(_ p: SIMD2<Float>, faceR: Float,
                          moonPlace: SIMD3<Float>) -> SIMD2<Float> {
        let k = moonPlace.z
        let place = SIMD2<Float>(moonPlace.x, moonPlace.y)
        return 2 * faceR * ((p - lutCenter) * k + place - 0.5)
    }

    /// Point de la face → point de SCÈNE (le repère de `pC` dans le shader),
    /// pour un lacet et un tangage donnés. C'est la projection orthographique
    /// du shader, écrite à l'endroit : `pC = M·pF + Ez·hD`, avec M de
    /// colonnes (Ex, Ey). N'est exacte que si le shader tourne en mode
    /// cinéma, où les micro-balancements et le gyroscope sont amortis — sans
    /// quoi la caméra chasserait le tube d'un point ou deux.
    static func scenePoint(face pF: SIMD2<Float>, yaw: Float, pitch: Float,
                           faceR: Float) -> SIMD2<Float> {
        let cy = cos(yaw), sy = sin(yaw), cp = cos(pitch), sp = sin(pitch)
        let hD = faceR * 0.42
        return SIMD2(cy * pF.x + sy * hD,
                     sy * sp * pF.x + cp * pF.y - cy * sp * hD)
    }

    // MARK: Les accidents du parcours

    /// Les quatre endroits où la caméra doit lever le pied, en abscisse
    /// normalisée. Calculés, jamais recopiés — mais les valeurs attendues
    /// sont notées pour que toute dérive saute aux yeux :
    ///   corne droite 0,2032 · corne basse 0,7800 (virages de ~160°)
    ///   crochet de la vague droite 0,1341 (rayon 0,0079 uc)
    ///   encoche du bord bas       0,4082 (rayon 0,0123 uc)
    static let landmarks: (horn1: Float, horn2: Float, kink1: Float, kink2: Float) = {
        // Les cornes SONT des fins de cubique : leur abscisse se lit dans la
        // table, il n'y a rien à chercher.
        func arcAtEnd(of segment: Int) -> Float {
            table.cum[(segment + 1) * steps] / table.total
        }
        // Les deux crochets, eux, vivent à l'intérieur d'un segment : on y
        // cherche le minimum du rayon de courbure |B'|³/|B'×B''|.
        func tightest(in segment: Int) -> Float {
            var best = (radius: Float.greatestFiniteMagnitude, u: Float(0))
            for k in 1..<600 {
                let u = Float(k) / 600
                let d1 = derivative(segment: segment, u: u)
                let d2 = secondDerivative(segment: segment, u: u)
                let cross = abs(d1.x * d2.y - d1.y * d2.x)
                let speed = simd_length(d1)
                guard cross > 1e-9, speed > 1e-6 else { continue }
                let r = speed * speed * speed / cross
                if r < best.radius { best = (r, u) }
            }
            // Longueur parcourue dans le segment jusqu'à ce u.
            var acc: Float = 0
            var prev = point(segment: segment, u: 0)
            let n = 256
            for k in 1...n {
                let cur = point(segment: segment, u: best.u * Float(k) / Float(n))
                acc += simd_distance(prev, cur); prev = cur
            }
            return (table.cum[segment * steps] + acc) / table.total
        }
        return (horn1: arcAtEnd(of: 5), horn2: arcAtEnd(of: 15),
                kink1: tightest(in: 3), kink2: tightest(in: 10))
    }()

    private static func secondDerivative(segment i: Int, u: Float) -> SIMD2<Float> {
        let (p0, c1, c2, p3) = controls(i)
        let v = 1 - u
        return 6 * v * (c2 - 2 * c1 + p0) + 6 * u * (p3 - 2 * c2 + c1)
    }
}
