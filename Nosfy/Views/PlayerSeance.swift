import SwiftUI

// MARK: - LE PLAYER DE SÉANCE — le dock qui suit partout
//
// LE PLAYER EST LA FEUILLE DE SÉANCE (le verdict : « séance en cours
// = le galet néon SEUL », la carte flottante est morte — deux fois).
// Ici ne vivent que LE PANNEAU DE PAUSE (le « Terminer » du player y
// passe : c'est lui qui clôt) et LA NOTIF DES PIÈCES — la chaîne de
// fin de séance : trophée, pièces, pop-up booster, dans cet ordre.

// MARK: Le panneau de pause

/// Le jumeau SANS vidéo du panneau de départ : « Terminer la séance ? »,
/// le bilan en une ligne, le diamant qui clôt, l'échappée qui continue.
struct PausePanneauHote: View {
    var ouverte: Bool
    var duree: String
    var series: Int
    var gain: Int
    var onTerminer: () -> Void = {}
    var onContinuer: () -> Void = {}

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                Color.clear
                if ouverte {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { onContinuer() }
                        .transition(.opacity)
                    PausePanneau(W: g.size.width, duree: duree,
                                 series: series, gain: gain,
                                 onTerminer: onTerminer,
                                 onContinuer: onContinuer)
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(ouverte)
        // SONDE (26-08) : si le tap du stop imprime mais que cette ligne se
        // tait, l'état ne traverse pas jusqu'à la racine ; si les deux
        // impriment et que rien ne s'affiche, le panneau est RECOUVERT par un
        // étage plus haut (la racine monte jusqu'à zIndex 20, lui vit à 5).
        .onChange(of: ouverte) { _, v in
            print("[SONDE-STOP] PausePanneauHote voit ouverte = \(v)")
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86),
                   value: ouverte)
    }
}

struct PausePanneau: View {
    var W: CGFloat
    var duree: String
    var series: Int
    var gain: Int
    var onTerminer: () -> Void = {}
    var onContinuer: () -> Void = {}

    @State private var pull: CGFloat = 0
    /// Le chien de garde du glisser (voir la note sur le geste, plus bas).
    @State private var garde: DispatchWorkItem?

    private static let forme = UnevenRoundedRectangle(
        cornerRadii: .init(topLeading: 34, bottomLeading: 0,
                           bottomTrailing: 0, topTrailing: 34),
        style: .continuous)

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 30)
            Text("Terminer la séance ?")
                .font(.inter(20, .semibold))
                .foregroundStyle(Color.inkPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Text(bilan)
                .font(.inter(12.5))
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 7)
                .padding(.horizontal, 30)

            DiamondPrimaryButton(title: "Terminer",
                                 smokeWarmth: 0.55) {
                onTerminer()
            }
            .padding(.horizontal, 26)
            .padding(.top, 30)

            Button { onContinuer() } label: {
                Text("Continuer la séance")
                    .font(.inter(15, .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 10)
            .padding(.bottom, 34)
        }
        .frame(width: W)
        .background {
            ZStack {
                Color.clear.glassEffect(
                    .regular.tint(Color.black.opacity(0.30)),
                    in: Self.forme)
                Self.forme
                    .fill(LinearGradient(stops: [
                        .init(color: .black.opacity(0.93), location: 0),
                        .init(color: .black.opacity(0.6), location: 0.5),
                        .init(color: .black.opacity(0.54), location: 1)
                    ], startPoint: .top, endPoint: .bottom))
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            Self.forme
                .strokeBorder(LinearGradient(stops: [
                    .init(color: Color.white.opacity(0.16), location: 0),
                    .init(color: Color.white.opacity(0.03), location: 0.18),
                    .init(color: .clear, location: 0.45)
                ], startPoint: .top, endPoint: .bottom), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.white.opacity(0.28))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .allowsHitTesting(false)
        }
        .offset(y: pull)
        .contentShape(Self.forme)
        // ⚠️ **LE GLISSER NE PEUT PLUS GELER TOUTE L'APP** (27-08, cause
        // CONFIRMÉE, verdict : « j'ai cliqué stop, l'overlay est apparu, je ne
        // l'ai pas validé, je l'ai juste glissé vers le bas — puis tout est
        // bloqué »). Ce drag n'avait AUCUN filet : s'il mourait sans `onEnded`
        // (le bord bas de l'écran vole le doigt vers le Control Center /
        // l'app-switcher, Reachability, passage en arrière-plan — le piège du
        // geste annulé, déjà payé), `pull` restait grand → le panneau partait
        // hors écran par son `.offset(y: pull)` (INVISIBLE) MAIS `pauseOuverte`
        // restait `true` à la racine. Or l'hôte est `.allowsHitTesting(ouverte)`
        // AU-DESSUS du TabView : son voile plein écran mangeait alors TOUS les
        // touchers de l'app (molette, chevron, stop, ouverture du player),
        // partout, jusqu'au kill — et re-taper Stop réécrivait `true` sur
        // `true` (no-op), d'où « le stop ne réagit plus ».
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { v in
                    pull = max(0, v.translation.height)
                    armerGarde()
                }
                .onEnded { _ in resoudre() })
    }

    /// Ré-armé à chaque image du glisser, annulé au lâcher : s'il aboie
    /// (0,5 s sans image ni `onEnded`), le geste est mort — le doigt est parti
    /// — et on FERME franchement plutôt que de laisser le panneau hors écran
    /// avec le voile encore actif. Fermer = « Continuer la séance » : le choix
    /// sûr (on ne termine jamais par accident).
    private func armerGarde() {
        garde?.cancel()
        let item = DispatchWorkItem {
            garde = nil
            onContinuer()
        }
        garde = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)
    }

    /// Le lâcher : un glisser franc (> 90) ferme, sinon le panneau revient.
    /// Jamais un entre-deux qui laisserait `pauseOuverte` levé sur un panneau
    /// invisible.
    private func resoudre() {
        garde?.cancel()
        garde = nil
        if pull > 90 {
            onContinuer()
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                pull = 0
            }
        }
    }

    private var bilan: String {
        var morceaux = [duree]
        if series > 0 {
            morceaux.append("\(series) série\(series > 1 ? "s" : "")")
        }
        if gain > 0 { morceaux.append("+\(gain) pièces lune") }
        return morceaux.joined(separator: " · ")
    }
}

// MARK: Le vol des pièces

/// LES PIÈCES QUI RENTRENT À LA MAISON : cinq pièces de braise arquent
/// de la capsule d'annonce vers la petite pièce du coffre — en canon
/// (0,13 s d'écart), chacune sur sa courbe, la récolte se VOIT.
/// Fonction pure du temps : rien à semer, rien à nettoyer.
struct VolDePieces: View {
    var depart: CGPoint
    var cible: CGPoint
    var born: Date

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let age = tl.date.timeIntervalSince(born)
            Canvas { ctx, _ in
                for i in 0 ..< 5 {
                    let t0 = 0.35 + Double(i) * 0.13
                    let u = (age - t0) / 0.6
                    guard u > 0, u < 1 else { continue }
                    let e = u * u * (3 - 2 * u)
                    // La courbe : un arc qui monte puis pique — le
                    // point de contrôle au-dessus du trajet, décalé
                    // par pièce pour que le vol ne soit jamais un rail.
                    let cx = (depart.x + cible.x) / 2
                        + CGFloat(i - 2) * 14
                    let cy = min(depart.y, cible.y) - 46
                        - CGFloat(i) * 7
                    let x = (1 - e) * (1 - e) * depart.x
                        + 2 * (1 - e) * e * cx + e * e * cible.x
                    let y = (1 - e) * (1 - e) * depart.y
                        + 2 * (1 - e) * e * cy + e * e * cible.y
                    // Naît en fondu, meurt en pointe à l'arrivée.
                    let op = u < 0.12 ? u / 0.12
                        : u > 0.86 ? (1 - u) / 0.14 : 1
                    let r = 5.5 - 2.5 * e
                    let rect = CGRect(x: x - r, y: y - r,
                                      width: r * 2, height: r * 2)
                    ctx.opacity = op
                    ctx.fill(Ellipse().path(in: rect),
                             with: .linearGradient(
                                Gradient(colors: [
                                    Color(red: 1.0, green: 0.72,
                                          blue: 0.32),
                                    Color(red: 0.85, green: 0.4,
                                          blue: 0.1)]),
                                startPoint: CGPoint(x: x, y: y - r),
                                endPoint: CGPoint(x: x, y: y + r)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: La notif des pièces

/// LA MINI-NOTIF LIQUID GLASS : à l'arrivée sur la home après la
/// clôture, la capsule de verre descend du haut, le compte ROULE
/// (numericText), trois éclats de braise filent vers la pastille, puis
/// elle se retire — et la pop-up booster prend la suite.
struct PiecesNotif: View {
    var gain: Int
    var visible: Bool

    @State private var compte = 0

    var body: some View {
        HStack(spacing: 9) {
            // La petite pièce : le disque de braise au liseré.
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 1.0, green: 0.72, blue: 0.32),
                                 Color(red: 0.85, green: 0.4, blue: 0.1)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: 20)
                Circle()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    .frame(width: 20, height: 20)
            }
            Text("+\(compte)")
                .font(.inter(16, .bold))
                .foregroundStyle(Color.inkPrimary)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(compte)))
            Text("pièces lune")
                .font(.inter(13, .medium))
                .foregroundStyle(Color.inkMuted)
        }
        .padding(.horizontal, 18)
        .frame(height: 44)
        .background {
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.35))
                .background {
                    Color.clear.glassEffect(.clear,
                                            in: Capsule(style: .continuous))
                }
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .offset(y: visible ? 0 : -110)
        .opacity(visible ? 1 : 0)
        .animation(.spring(response: 0.48, dampingFraction: 0.82),
                   value: visible)
        .onChange(of: visible) { _, v in
            guard v else { compte = 0; return }
            // Le compte roule en trois temps — jamais un chiffre posé.
            let paliers = [gain / 3, gain * 2 / 3, gain]
            for (i, p) in paliers.enumerated() {
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + 0.35 + Double(i) * 0.22) {
                    withAnimation(.easeOut(duration: 0.2)) { compte = p }
                }
            }
        }
        .allowsHitTesting(false)
    }
}
