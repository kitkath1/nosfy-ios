import SwiftData
import SwiftUI

// MARK: - LA PAGE PROFIL — la maison des cartes

/// La refonte du 14-08 (« on va s'amuser un peu !! ») : l'ancienne page à
/// trois cartes est morte. À sa place : le halo de la home versé depuis la
/// DROITE (`bgAuroraProfil`, le champ miroité), le rond aux initiales en
/// dégradé néon sous son fil blanc animé, le badge de niveau, la pastille
/// moonCoin des pièces (tap → elle s'anime, puis le coffre), les réglages
/// dans leur overlay de verre, et LA COLLECTION : les quatre registres en
/// lignes, du plus petit au légendaire, avec les dos vides qui attendent.
///
/// Banc : `-profilLab` — la page seule, plein écran.
struct ProfilLuneView: View {
    @Binding var selection: WoopTab

    @Query(sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var showCoffre = false
    @State private var showReglages = false
    /// Le rebond de la pastille pièces au tap (0 → 1 → 0).
    @State private var coinKick: CGFloat = 0

    /// Le trésor : la règle de la maison, 20 pièces par série faite.
    private var pieces: Int {
        let finies = workouts.filter { !$0.isActive }
        let series = finies.flatMap { $0.exercises ?? [] }
            .reduce(0) { $0 + $1.completedSets }
        return CoffreFortPurse.coins(doneSeries: series)
    }

    var body: some View {
        ZStack {
            ProfilAuroraBackground()
            VStack(spacing: 0) {
                // La rangée canonique : le chevron EXACTEMENT où il vit
                // sur la fiche d'exercice, les réglages en face.
                RangeeChips(retour: {
                    withAnimation(.easeOut(duration: 0.3)) {
                        selection = .home
                    }
                }) {
                    ChipVerre(symbole: "gearshape", label: "Réglages") {
                        withAnimation(.spring(response: 0.42,
                                              dampingFraction: 0.86)) {
                            showReglages = true
                        }
                    }
                }
                ScrollView {
                    VStack(spacing: 0) {
                        identite
                            .padding(.top, 6)
                        ongletCartes
                            .padding(.top, 30)
                        registres
                            .padding(.top, 16)
                    }
                    .padding(.bottom, 120)
                }
            }

            // L'overlay des réglages — le panneau de verre in-tree (la
            // sheet système tue le vrai Liquid Glass, leçon du médaillon).
            if showReglages {
                ReglagesOverlay(pieces: pieces) {
                    withAnimation(.spring(response: 0.4,
                                          dampingFraction: 0.9)) {
                        showReglages = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .fullScreenCover(isPresented: $showCoffre) {
            CoffreFortFlow(coins: pieces, onClose: { showCoffre = false })
        }
    }

    // MARK: L'identité — le rond, le nom, le niveau, le trésor

    private var identite: some View {
        VStack(spacing: 12) {
            RondAvatar(initiales: "KD")
            Text("Kathryn")
                .font(.inter(28, .bold))
                .tracking(-0.3)
                .foregroundStyle(Color.inkPrimary)
            Text("Level 1")
                .font(.inter(12, .semibold))
                .tracking(0.6)
                .foregroundStyle(Color.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().strokeBorder(Color.white.opacity(0.16),
                                           lineWidth: 1))

            // La pastille de la page BRAVO, en petit : le trésor. Au tap
            // elle SE RÉVEILLE (rebond + brille) puis ouvre le coffre —
            // le délai est celui du bouton-pièce de la home (0,34 s).
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.32, dampingFraction: 0.42)) {
                    coinKick = 1
                }
                withAnimation(.easeOut(duration: 0.5).delay(0.32)) {
                    coinKick = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
                    showCoffre = true
                }
            } label: {
                HStack(spacing: 8) {
                    Text("\(pieces)")
                        .font(.inter(17, .bold))
                        .foregroundStyle(Color.inkPrimary)
                        .contentTransition(.numericText())
                    Text("pièces lune")
                        .font(.inter(12, .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.inkMuted)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(.regular.tint(Color.black.opacity(0.45))
                                 .interactive(),
                             in: .capsule)
                .scaleEffect(1 + 0.10 * coinKick)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(pieces) pièces lune — ouvrir le coffre")
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Le titre de la collection

    private var ongletCartes: some View {
        Text("Cartes collectées")
            .font(.inter(21, .bold))
            .tracking(-0.2)
            .foregroundStyle(Color.inkPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    // MARK: Les quatre registres

    private static let registresProfil: [(nom: String, sous: String,
                                          pips: Int, total: Int)] = [
        ("Une Lune", "normal", 1, 4),
        ("Deux Lunes", "plus rare", 2, 11),
        ("Trois Lunes", "très rare", 3, 4),
        ("Quatre Lunes", "légendaire", 4, 6),
    ]

    private var registres: some View {
        VStack(spacing: 22) {
            ForEach(Self.registresProfil, id: \.nom) { reg in
                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        HStack(spacing: 2.5) {
                            ForEach(0..<reg.pips, id: \.self) { _ in
                                CroissantLune(taille: 9,
                                              couleur: .profilBraise
                                                  .opacity(0.55))
                            }
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(reg.nom)
                                .font(.inter(17, .bold))
                                .foregroundStyle(Color.inkPrimary)
                            Text(reg.sous)
                                .font(.inter(11, .semibold))
                                .tracking(0.4)
                                .foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Text("0 / \(reg.total)")
                            .font(.inter(13, .semibold))
                            .foregroundStyle(Color.inkMuted)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.inkMuted)
                    }
                    .padding(.horizontal, 20)

                    // Les dos vides — plus tard, les collectées prendront
                    // leur place (pastille ×N pour les doublons, tap → la
                    // scène de résultat).
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<reg.total, id: \.self) { _ in
                                DosVide(pips: reg.pips)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

// MARK: - Le rond aux initiales

/// Le rond centré : KD très FIN, habillé d'un dégradé de braises
/// SOMBRES qui voyage lentement dans les lettres, posé sur une matière
/// d'obsidienne — noir mat traversé d'un reflet poli qui tourne. Le fil
/// blanc animé de 0,7 pt reste, seul bijou.
struct RondAvatar: View {
    var initiales: String

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let tour = Angle.degrees(
                t.truncatingRemainder(dividingBy: 8.0) / 8.0 * 360.0)
            // Le dégradé des lettres DÉRIVE : son axe tourne sur 13 s —
            // des braises profondes, jamais criardes.
            let phase = t.truncatingRemainder(dividingBy: 13.0) / 13.0
                * 2.0 * .pi
            let ax = 0.5 + 0.5 * cos(phase)
            let ay = 0.5 + 0.5 * sin(phase)
            Text(initiales)
                .font(.inter(22, .light))
                .tracking(3.5)
                .foregroundStyle(LinearGradient(
                    colors: [Color(red: 0.42, green: 0.15, blue: 0.04),
                             Color(red: 0.93, green: 0.44, blue: 0.13),
                             Color(red: 0.55, green: 0.20, blue: 0.06)],
                    startPoint: UnitPoint(x: ax, y: ay),
                    endPoint: UnitPoint(x: 1 - ax, y: 1 - ay)))
                .neonGlow(.profilBraise, radius: 7, opacity: 0.35)
                .frame(width: 72, height: 72)
                .background {
                    // L'obsidienne : noir mat, un reflet poli qui tourne
                    // lentement à contresens, une lueur froide au nord.
                    ZStack {
                        Circle().fill(Color.black)
                        Circle().fill(AngularGradient(stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .white.opacity(0.055),
                                  location: 0.10),
                            .init(color: .clear, location: 0.24),
                            .init(color: .clear, location: 0.55),
                            .init(color: .white.opacity(0.03),
                                  location: 0.66),
                            .init(color: .clear, location: 0.80),
                        ], center: .center, angle: -tour))
                        Circle().fill(RadialGradient(
                            colors: [Color.white.opacity(0.07), .clear],
                            center: UnitPoint(x: 0.35, y: 0.18),
                            startRadius: 0, endRadius: 40))
                    }
                }
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(
                        AngularGradient(stops: [
                            .init(color: .white.opacity(0.05), location: 0.0),
                            .init(color: .white.opacity(0.85), location: 0.12),
                            .init(color: .white.opacity(0.10), location: 0.30),
                            .init(color: .white.opacity(0.05), location: 0.55),
                            .init(color: .white.opacity(0.45), location: 0.78),
                            .init(color: .white.opacity(0.05), location: 1.0),
                        ], center: .center, angle: tour),
                        lineWidth: 0.7))
        }
    }
}

// MARK: - L'overlay des réglages

/// Le panneau de verre in-tree — il monte du bas sur un voile, se referme
/// au drag ou au voile. Dedans : le compte, la déconnexion, la
/// suppression (l'exigence App Store — le câblage réel viendra avec la
/// connexion Apple) et les conditions générales.
struct ReglagesOverlay: View {
    var pieces: Int
    var fermer: () -> Void

    @State private var glisse: CGFloat = 0
    @State private var showCGU = false
    @State private var confirmeSuppression = false
    @State private var noteSuppression = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Le voile : un tap le referme.
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .onTapGesture { fermer() }

            let forme = RoundedRectangle(cornerRadius: 28, style: .continuous)
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 40, height: 4.5)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                Text("Réglages")
                    .font(.inter(21, .bold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                // Le compte — l'échafaudage d'atelier ; le compte Apple
                // prendra cette place au chantier connexion.
                HStack(spacing: 12) {
                    Text("KD")
                        .font(.inter(14, .bold))
                        .tracking(1)
                        .foregroundStyle(Color.profilBraise)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.black.opacity(0.55)))
                        .overlay(Circle().strokeBorder(
                            Color.white.opacity(0.14), lineWidth: 0.7))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kathryn")
                            .font(.inter(16, .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("\(pieces) pièces lune · Level 1")
                            .font(.inter(12, .regular))
                            .foregroundStyle(Color.inkMuted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

                VStack(spacing: 0) {
                    ligne("rectangle.portrait.and.arrow.right",
                          "Se déconnecter") {
                        // La déconnexion d'aujourd'hui : oublier la
                        // session locale — la vraie (Supabase/Apple)
                        // arrive avec le chantier connexion.
                        UserDefaults.standard.removeObject(
                            forKey: "woop.phone")
                        fermer()
                    }
                    separateur
                    ligne("doc.text", "Conditions générales d'utilisation") {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showCGU = true
                        }
                    }
                    separateur
                    ligne("trash", "Supprimer mon compte",
                          teinte: Color(red: 1.0, green: 0.36, blue: 0.26)) {
                        confirmeSuppression = true
                    }
                    if noteSuppression {
                        Text("La suppression réelle sera activée avec la connexion Apple.")
                            .font(.inter(12, .regular))
                            .foregroundStyle(Color.inkMuted)
                            .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 26)
            }
            .frame(maxWidth: .infinity)
            .background {
                Color.clear
                    .glassEffect(.regular.tint(Color.black.opacity(0.55)),
                                 in: forme)
            }
            .overlay(forme.strokeBorder(Color.white.opacity(0.10),
                                        lineWidth: 1))
            .clipShape(forme)
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
            .offset(y: glisse)
            // Le drag FLUIDE : simultané (il vit même par-dessus les
            // lignes-boutons, qui gardent leur tap), suivi du doigt 1:1
            // vers le bas, caoutchouc vers le haut, et la décision de
            // fermeture lit la VITESSE (predictedEnd), pas juste la
            // distance — un petit geste vif ferme, un grand geste lent
            // hésitant revient.
            .simultaneousGesture(DragGesture(minimumDistance: 10)
                .onChanged { v in
                    let h = v.translation.height
                    glisse = h >= 0 ? h : h / 6
                }
                .onEnded { v in
                    if v.predictedEndTranslation.height > 150 {
                        fermer()
                    } else {
                        withAnimation(.spring(response: 0.32,
                                              dampingFraction: 0.82)) {
                            glisse = 0
                        }
                    }
                })
            .transition(.move(edge: .bottom).combined(with: .opacity))

            if showCGU {
                CGUPage {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showCGU = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .alert("Supprimer ton compte ?", isPresented: $confirmeSuppression) {
            Button("Supprimer", role: .destructive) {
                withAnimation { noteSuppression = true }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes cartes et tes pièces seront perdues pour toujours.")
        }
    }

    private var separateur: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 54)
    }

    private func ligne(_ symbole: String, _ titre: String,
                       teinte: Color = .inkPrimary,
                       action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbole)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(teinte)
                    .frame(width: 26)
                Text(titre)
                    .font(.inter(15, .semibold))
                    .foregroundStyle(teinte)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Les conditions générales — le gabarit est posé, LE TEXTE RESTE À
/// RÉDIGER avant l'App Store.
struct CGUPage: View {
    var fermer: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 0) {
                RangeeChips(retour: fermer) { EmptyView() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Conditions générales d'utilisation")
                            .font(.inter(24, .bold))
                            .foregroundStyle(Color.inkPrimary)
                        Text("Le texte des conditions générales sera rédigé avant la publication sur l'App Store.")
                            .font(.inter(15, .regular))
                            .foregroundStyle(Color.inkSecondary)
                        Spacer(minLength: 200)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
            }
        }
    }
}

// MARK: - Le dos vide

/// Une carte qui ATTEND. Au tap, elle répond « je suis vide » : ses
/// liserés s'embrasent (l'image recomposée sur elle-même en écran — seuls
/// les pixels chauds montent, donc le néon suit exactement les traits) et
/// la main sent un petit grain sec. Les lunes de rareté du registre sont
/// posées par le code, comme sur les vraies cartes.
struct DosVide: View {
    var pips: Int
    @State private var pulse: CGFloat = 0

    private static let dos: Image = {
        guard let p = Bundle.main.path(forResource: "carte-dos-vide",
                                       ofType: "png"),
              let ui = UIImage(contentsOfFile: p)
        else { return Image(systemName: "questionmark.diamond") }
        return Image(uiImage: ui)
    }()

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid)
                .impactOccurred(intensity: 0.7)
            withAnimation(.easeOut(duration: 0.16)) { pulse = 1 }
            withAnimation(.easeOut(duration: 0.7).delay(0.16)) { pulse = 0 }
        } label: {
            ZStack {
                Self.dos
                    .resizable()
                    .aspectRatio(1024.0 / 1536.0, contentMode: .fit)
                // Le néon : l'image elle-même, en écran — net puis diffus.
                Self.dos
                    .resizable()
                    .aspectRatio(1024.0 / 1536.0, contentMode: .fit)
                    .blendMode(.screen)
                    .opacity(0.85 * pulse)
                Self.dos
                    .resizable()
                    .aspectRatio(1024.0 / 1536.0, contentMode: .fit)
                    .blur(radius: 5)
                    .blendMode(.screen)
                    .opacity(0.9 * pulse)
            }
            .overlay(alignment: .bottom) {
                HStack(spacing: 3) {
                    ForEach(0..<pips, id: \.self) { _ in
                        CroissantLune(taille: 8,
                                      couleur: .profilBraise
                                          .opacity(0.5 + 0.5 * pulse))
                    }
                }
                .padding(.bottom, 9)
            }
            // Le gabarit EXPLICITE (la maquette : QUATRE dos visibles par
            // rangée) — `aspectRatio(.fit)` seul se cale sur la hauteur
            // proposée et les dos sortaient géants.
            .frame(width: 80, height: 80 * 1536.0 / 1024.0)
            .scaleEffect(1 + 0.035 * pulse)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Emplacement de carte vide")
    }
}

extension Color {
    /// La braise du profil — l'orange sombre de l'univers des cartes.
    static let profilBraise = Color(red: 1.0, green: 0.55, blue: 0.18)
}

// MARK: - Le glyphe du logo

/// LE croissant de la marque, exact : le path de `MoonGlyph` (les 18
/// cubiques du logo, WoopShared) en `Shape` — fini les croissants
/// génériques à deux cercles (verdict : « comme le logo »).
struct GlypheLune: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height / MoonGlyph.unitHeight)
        let dx = rect.midX - s / 2
        let dy = rect.midY - s * MoonGlyph.unitHeight / 2
        func pt(_ p: CGPoint) -> CGPoint {
            CGPoint(x: dx + p.x * s, y: dy + p.y * s)
        }
        var path = Path()
        path.move(to: pt(MoonGlyph.startPoint))
        for seg in MoonGlyph.segments {
            path.addCurve(to: pt(seg.end), control1: pt(seg.c1),
                          control2: pt(seg.c2))
        }
        path.closeSubpath()
        return path
    }
}

/// Le glyphe posé en pastille — petit et DISCRET (« trop de lunes mdr »).
struct CroissantLune: View {
    var taille: CGFloat
    var couleur: Color

    var body: some View {
        GlypheLune()
            .fill(couleur)
            .frame(width: taille, height: taille)
    }
}

// MARK: - Le fond miroité

/// Le ciel de la home, versé depuis la DROITE : même scène à cinq couches
/// (`bgAuroraProfil` = le champ miroité DANS le shader), mêmes étoiles —
/// le champ d'étoiles n'a pas de biais latéral, il reste tel quel.
struct ProfilAuroraBackground: View {
    var body: some View {
        ZStack {
            Color.black
            ProfilAuroraFloor()
            StarDustCeiling()
                .mask {
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.44),
                        .init(color: .white.opacity(0.50), location: 0.68),
                        .init(color: .white.opacity(0.80), location: 1.0),
                    ], startPoint: .top, endPoint: .bottom)
                }
            // Le voile de nuit — LÉGER en haut (verdict Kathryn : le halo
            // doit rester lumineux comme la home), il n'assoit que le bas
            // où vivent les cartes.
            LinearGradient(stops: [
                .init(color: .black.opacity(0.0), location: 0.0),
                .init(color: .black.opacity(0.08), location: 0.42),
                .init(color: .black.opacity(0.16), location: 1.0),
            ], startPoint: .top, endPoint: .bottom)

            WoopGrain()
        }
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

private struct ProfilAuroraFloor: View {
    @StateObject private var tilt = BgTilt()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.bgAuroraProfil(
                        .float2(geo.size.width, geo.size.height), .float(t),
                        .float2(Float(tilt.value.x), Float(tilt.value.y)),
                        .float(1.0)))
            }
        }
    }
}

// MARK: - Le banc

/// `-profilLab` : la page seule, sans la barre bijou — le chevron ne mène
/// nulle part, on fouette le visuel.
struct ProfilLab: View {
    @State private var selection = WoopTab.profile

    var body: some View {
        ProfilLuneView(selection: $selection)
            .statusBarHidden()
            .preferredColorScheme(.dark)
    }
}

#Preview { ProfilLab() }
