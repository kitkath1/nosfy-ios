import SwiftUI

// MARK: - Carte Objectif — la crête

/// Profil de la crête : la carte est un rounded-rect dont le bord haut s'élève
/// en mesa — un plateau central aux épaules douces, comme si le haut de la
/// carte avait été découpé pour laisser entrer le ciel.
///
/// Le profil vit ICI, en un seul endroit, et part tel quel en uniforms vers le
/// shader `objectiveCrest` : la forme Swift et la matière Metal restent
/// jumelles au point près — c'est ce qui soude la nébuleuse à la bordure.
struct CrestProfile {
    /// Hauteur de l'élévation, en points : le plateau culmine à `rise`
    /// au-dessus des épaules.
    var rise: CGFloat = 46
    /// Profondeur de chute de la corniche, en points : l'unité de `dy` dans
    /// le shader — la matière a pratiquement disparu à ~2 × `fall`.
    var fall: CGFloat = 62
    var cornerRadius: CGFloat = 30
    /// Épaules, en fractions de largeur : montée [xa→xb], descente [xc→xd].
    /// Asymétrie de la référence : montée gauche LONGUE et douce (~18 % de
    /// largeur), descente droite courte et franche (~11 %), plateau vraiment
    /// plat sur ~47 % — une mesa aux genoux nets, pas une colline.
    var xa: CGFloat = 0.10
    var xb: CGFloat = 0.28
    var xc: CGFloat = 0.75
    var xd: CGFloat = 0.86

    /// 0 aux épaules, 1 sur le plateau — C1 partout : la crête n'a aucun angle.
    func plateau(_ u: CGFloat) -> CGFloat {
        smoothstep(xa, xb, u) * (1 - smoothstep(xc, xd, u))
    }

    /// Ordonnée du bord haut (0 = sommet du plateau, `rise` = épaules).
    func edgeY(_ u: CGFloat) -> CGFloat { rise * (1 - plateau(u)) }

    private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// La silhouette : quatre coins arrondis classiques, et entre les deux coins
/// hauts une crête échantillonnée à pas fin (1,5 pt — l'erreur de corde est
/// invisible bien avant ça). Le profil étant plat au droit des coins
/// (`xa > cornerRadius / largeur`), les arcs se raccordent sans couture.
struct ObjectiveCrestShape: Shape {
    var profile = CrestProfile()

    func path(in rect: CGRect) -> Path {
        let radius = min(profile.cornerRadius, rect.width / 2,
                         (rect.height - profile.rise) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + profile.rise + radius))
        path.addArc(center: CGPoint(x: rect.minX + radius,
                                    y: rect.minY + profile.rise + radius),
                    radius: radius, startAngle: .degrees(180),
                    endAngle: .degrees(270), clockwise: false)

        let x0 = rect.minX + radius, x1 = rect.maxX - radius
        let steps = max(Int((x1 - x0) / 1.5), 8)
        for i in 0...steps {
            let x = x0 + (x1 - x0) * CGFloat(i) / CGFloat(steps)
            path.addLine(to: CGPoint(x: x, y: rect.minY + profile.edgeY((x - rect.minX) / rect.width)))
        }

        path.addArc(center: CGPoint(x: rect.maxX - radius,
                                    y: rect.minY + profile.rise + radius),
                    radius: radius, startAngle: .degrees(270),
                    endAngle: .degrees(0), clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(0),
                    endAngle: .degrees(90), clockwise: false)
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                    radius: radius, startAngle: .degrees(90),
                    endAngle: .degrees(180), clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Corniche de nébuleuse

/// La matière : voir `objectiveCrest` + `objectiveCrestStars` dans
/// DemonSky.metal. Deux passes, comme le ciel : le diffus en DEMI-résolution
/// (upscale bilinéaire invisible sur du vaporeux, ÷4 de coût), la poudre
/// d'étoiles en pleine (sub-pixel), composée en `plusLighter` — de la lumière
/// ajoutée au verre, jamais un calque qui le grise. Même horloge globale que
/// le ciel (mod 900 s) : la carte est une fenêtre sur le même cosmos.
private struct CrestNebula: View {
    let profile: CrestProfile
    var paused: Bool

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let h = max(geo.size.height, 1)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
                let t = Float(timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                let shoulders = Shader.Argument.float4(
                    profile.xa, profile.xb, profile.xc, profile.xd)

                ZStack(alignment: .topLeading) {
                    // Le shader travaille en unités relatives à `fall` : les
                    // uniforms divisés par deux suffisent à la demi-résolution.
                    Rectangle()
                        .fill(.black)
                        .frame(width: w / 2, height: h / 2)
                        .colorEffect(Self.dithered(ShaderLibrary.objectiveCrest(
                            .float2(w / 2, h / 2), .float(t), shoulders,
                            .float2(profile.rise / 2, profile.fall / 2),
                            .image(NebulaNoise.image))))
                        .scaleEffect(2, anchor: .topLeading)

                    Rectangle()
                        .fill(.black)
                        .frame(width: w, height: h)
                        .colorEffect(ShaderLibrary.objectiveCrestStars(
                            .float2(w, h), .float(t), shoulders,
                            .float2(profile.rise, profile.fall),
                            .image(NebulaNoise.image)))
                        .blendMode(.plusLighter)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private static func dithered(_ shader: Shader) -> Shader {
        var s = shader
        s.dithersColor = true
        return s
    }
}

// MARK: - Liseré de lumière

/// Le fil lumineux qui cerne la silhouette. Trois passes concentriques —
/// halo large, lueur serrée, fil net — parce qu'une vraie source a une PSF,
/// pas un contour. Les halos débordent de la carte (traits centrés, jamais
/// rognés) : la lumière appartient au ciel, pas à la carte. Calques
/// statiques : Core Animation les met en cache, le coût est payé une fois.
private struct CrestBorder: View {
    let profile: CrestProfile
    /// Objectif atteint : le fil se réchauffe vers l'or-récompense — la seule
    /// célébration, discrète, dans la famille chromatique documentée.
    var achieved: Bool = false

    private var glow: Color {
        achieved ? Color(red: 1.0, green: 0.93, blue: 0.75) : .white
    }

    /// Un tube néon FIN et régulier, comme la référence : le fil reste allumé
    /// tout autour (le bas garde ~70 % de la brillance du haut), le bloom est
    /// serré et constant — pas un projecteur en haut et un fil mort en bas.
    private var line: LinearGradient {
        LinearGradient(
            stops: [.init(color: achieved ? Color(red: 1.0, green: 0.95, blue: 0.82) : .white,
                          location: 0.0),
                    .init(color: .white.opacity(0.80), location: 0.35),
                    .init(color: .white.opacity(0.70), location: 1.0)],
            startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let shape = ObjectiveCrestShape(profile: profile)
        ZStack {
            shape.stroke(glow.opacity(achieved ? 0.28 : 0.20), lineWidth: 8)
                .blur(radius: 16)
            shape.stroke(glow.opacity(0.55), lineWidth: 2.2)
                .blur(radius: 2.5)
            shape.stroke(line, lineWidth: 1.1)
        }
        .mask {
            // À peine plus respirant en haut ; jamais éteint. Le débord du
            // flou (rayon 16 sur trait de 8) porte à ~50 pt hors de la
            // forme : le masque va plus loin, sinon il tranche le halo.
            LinearGradient(stops: [.init(color: .white, location: 0.0),
                                   .init(color: .white.opacity(0.82), location: 1.0)],
                           startPoint: .top, endPoint: .bottom)
                .padding(-64)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
    }
}

// MARK: - La carte

/// Verre noir liquide sous une corniche de nébuleuse, cerclé d'un fil de
/// lumière. Réservée à l'objectif hebdomadaire : une app dont toutes les
/// surfaces portent un ciel n'a plus de hiérarchie.
///
/// Empilement (arrière → avant) : assise noire (porte l'ombre, seul calque
/// immuable — cf. MistyMetalSurface), nébuleuse animée, grain, voile
/// spéculaire, liseré, contenu.
struct ObjectiveCrestCard<Content: View>: View {
    var profile = CrestProfile()
    /// Objectif hebdomadaire atteint : le liseré se réchauffe.
    var achieved: Bool = false
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var onScreen = true

    private var paused: Bool { !onScreen || reduceMotion }

    /// Le verre : quasi noir, à peine plus clair en haut (la nébuleuse
    /// l'éclaire par transparence), fondu dans le fond en bas.
    private var glass: LinearGradient {
        LinearGradient(
            stops: [.init(color: Color(red: 0.050, green: 0.050, blue: 0.068), location: 0.0),
                    .init(color: Color(red: 0.022, green: 0.022, blue: 0.032), location: 0.45),
                    .init(color: Color(red: 0.010, green: 0.010, blue: 0.016), location: 1.0)],
            startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        let shape = ObjectiveCrestShape(profile: profile)

        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.init(top: profile.rise + 32, leading: 22, bottom: 26, trailing: 22))
            .background {
                ZStack {
                    // L'ombre est accrochée au seul calque qui ne change
                    // jamais : sur le groupe entier, le flou de rayon 26
                    // serait recalculé à chaque image de la nébuleuse.
                    shape.fill(glass)
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.8), radius: 26, y: 16)

                    CrestNebula(profile: profile, paused: paused)
                        .clipShape(shape)
                        .blendMode(.plusLighter)

                    WoopGrain(density: 0.05, lightAlpha: 0.026, darkAlpha: 0.034)
                        .clipShape(shape)

                    // Voile spéculaire : la lumière de la crête glisse sur le
                    // verre — c'est lui qui fait « liquide » plutôt que « mat ».
                    shape.fill(
                        LinearGradient(
                            stops: [.init(color: .white.opacity(0.045), location: 0.0),
                                    .init(color: .white.opacity(0.010), location: 0.30),
                                    .init(color: .clear, location: 0.60),
                                    .init(color: .white.opacity(0.014), location: 1.0)],
                            startPoint: .top, endPoint: .bottom))
                }
            }
            .overlay { CrestBorder(profile: profile, achieved: achieved) }
            // La zone tappable est la silhouette exacte : le verre entier
            // répond, les encoches découpées (du ciel, pas de la carte) non.
            .contentShape(shape)
            // Hors écran, la corniche s'endort — même dégradation sans risque
            // que MistyMetalSurface (hors ScrollView la valeur reste à true).
            .onScrollVisibilityChange(threshold: 0.02) { visible in
                onScreen = visible
            }
    }
}
