import SwiftUI

// MARK: - La carte échancrée (incrustation)

/// La silhouette de la carte blanche de la fiche d'exercice : un galet aux
/// coins doux, dont le bord BAS se découpe autour de la pastille de séance —
/// l'incrustation des mini-players (la pastille n'a presque pas de bord à
/// elle : c'est le blanc qui la dessine en négatif, et le filet de noir entre
/// les deux qui dit « incrusté »).
///
/// Rien de natif ne sait faire un rayon CONCAVE (`UnevenRoundedRectangle`
/// n'a que des convexes, `subtracting` laisse des angles vifs aux jonctions).
/// Le contour est donc un seul `Path`, avec la géométrie classique du notch :
/// le bord bas arrive, plonge en congé CONVEXE, remonte le long du mur de
/// l'encoche, puis tourne en épaule CONCAVE autour de la pastille. C'est ce
/// raccord en S — deux inversions de courbure — qui fait tout l'effet.
///
/// Les quatre coins de la carte sont des quadratiques (contrôle au sommet) :
/// plus progressives qu'un quart de cercle, elles approchent la courbure
/// continue d'Apple — un arc circulaire à 40 pt de rayon se lirait « dur » à
/// côté des `.continuous` du reste de l'app. Les petits rayons de l'encoche
/// restent circulaires : à cette taille la famille de courbure ne se voit pas.
struct NotchedCardShape: Shape {
    /// Rayon des coins hauts.
    var topRadius: CGFloat = 40
    /// Rayon des coins bas — petits : dans la référence, le bord bas file
    /// presque directement du bord d'écran dans le S de l'encoche.
    var bottomRadius: CGFloat = 8
    /// Distance entre le bord de la carte et le mur de l'encoche. C'est LUI
    /// qui place l'encoche, pas une largeur absolue : la forme n'a pas besoin
    /// de connaître la géométrie de la page.
    var notchInset: CGFloat = 15
    /// Profondeur de l'encoche. À 0, le bord bas redevient plein — c'est la
    /// valeur animée quand la pastille apparaît ou disparaît.
    var notchDepth: CGFloat = 0
    /// Rayon des épaules concaves : celui de la pastille + l'interstice, pour
    /// que le blanc épouse la pierre à distance constante.
    var shoulderRadius: CGFloat = 29
    /// Rayon des congés convexes, là où le bord bas plonge dans l'encoche.
    var filletRadius: CGFloat = 7

    var animatableData: CGFloat {
        get { notchDepth }
        set { notchDepth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let rt = min(topRadius, rect.width / 2, rect.height / 2)
        let rb = min(bottomRadius, rect.width / 2)

        // Sens horaire, départ sur le flanc gauche sous le coin haut.
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rt))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rt, y: rect.minY),
                       control: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rt, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rt),
                       control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rb))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - rb, y: rect.maxY),
                       control: CGPoint(x: rect.maxX, y: rect.maxY))

        let d = max(0, min(notchDepth, rect.height - rt))
        let nx0 = rect.minX + notchInset
        let nx1 = rect.maxX - notchInset
        if d > 0.5, nx1 - nx0 > 1 {
            // Les rayons se replient d'eux-mêmes quand la profondeur fond :
            // pendant l'animation vers 0, l'encoche reste géométriquement
            // possible à chaque image au lieu de se retourner.
            let f = min(filletRadius, d)
            let sr = min(shoulderRadius, d - f, (nx1 - nx0) / 2)

            p.addLine(to: CGPoint(x: nx1 + f, y: rect.maxY))
            // Congé convexe : le bord bas plonge dans l'encoche.
            p.addArc(center: CGPoint(x: nx1 + f, y: rect.maxY - f), radius: f,
                     startAngle: .degrees(90), endAngle: .degrees(180),
                     clockwise: false)
            p.addLine(to: CGPoint(x: nx1, y: rect.maxY - d + sr))
            // Épaule concave : le blanc tourne autour de la pastille.
            p.addArc(center: CGPoint(x: nx1 - sr, y: rect.maxY - d + sr),
                     radius: sr,
                     startAngle: .degrees(0), endAngle: .degrees(-90),
                     clockwise: true)
            p.addLine(to: CGPoint(x: nx0 + sr, y: rect.maxY - d))
            p.addArc(center: CGPoint(x: nx0 + sr, y: rect.maxY - d + sr),
                     radius: sr,
                     startAngle: .degrees(-90), endAngle: .degrees(-180),
                     clockwise: true)
            p.addLine(to: CGPoint(x: nx0, y: rect.maxY - f))
            p.addArc(center: CGPoint(x: nx0 - f, y: rect.maxY - f), radius: f,
                     startAngle: .degrees(0), endAngle: .degrees(90),
                     clockwise: false)
        }

        p.addLine(to: CGPoint(x: rect.minX + rb, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - rb),
                       control: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
