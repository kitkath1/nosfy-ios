import SwiftUI

// MARK: - LA PORTE (06-09) — l'écran d'entrée, Apple et rien d'autre

/// Écran 00 du plan (`tools/porte/PLAN-COMPTE-ONBOARDING.html`).
///
/// Le noir tient tout. La seule source est le halo blanc DERRIÈRE l'île, et la
/// braise — rouge vers orange — qui l'entoure. Un seul bouton, et c'est le
/// nôtre : `BoutonPrimaire`, avec sa poudre de diamant au tap. Pas de bouton
/// Apple noir et blanc.
///
/// La feuille Apple est la VRAIE feuille native (`ASAuthorizationController`),
/// pas une maquette — voir `Services/AppleAuth.swift`.
struct PorteApple: View {

    /// Ce que la racine fait du verdict : nouvelle → le film de Nosfy ;
    /// connue → l'app.
    var onVerdict: (AppleAuth.Verdict) -> Void = { _ in }

    @State private var etat: Etat = .repos
    @State private var souffle = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Etat: Equatable {
        case repos
        case ouvre
        case verdict(AppleAuth.Verdict)
        case panne(String, interrupteur: Bool)
    }

    // MARK: Les cotes de l'île — mesurées, pas devinées

    /// L'île fait 126 pt de large pour 125 réels (HaloDawnLab.swift:630), 37 de
    /// haut, et son bord haut est à 11 pt du sommet de l'écran.
    private static let ileLargeur: CGFloat = 126
    private static let ileHauteur: CGFloat = 37
    private static let ileHaut: CGFloat = 11

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            halo
            bordureIle

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text("Nosfy")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white,
                                     Color(red: 0.78, green: 0.76, blue: 0.83),
                                     Color(red: 0.55, green: 0.53, blue: 0.60)],
                            startPoint: .top, endPoint: .bottom))

                Spacer(minLength: 0)

                corpsDuBas
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 22)
            }
            .ignoresSafeArea(.keyboard)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                souffle = true
            }
        }
    }

    // MARK: Le halo — la seule lumière de l'écran

    /// ⚠️ **LE BRUN, MESURÉ AU SIM LE 06-09.** Premier jet : des braises posées en
    /// opacité normale sur le noir. Résultat à l'écran — un nuage BRUN, et pas
    /// une braise. C'est la loi déjà payée sur l'aurore de la home : un orange
    /// qu'on éteint en opacité perd sa saturation avant sa luminance, et le brun
    /// est exactement ça — un orange désaturé à mi-luminance.
    ///
    /// Le remède est le mode de fusion, pas la couleur : `.plusLighter` AJOUTE
    /// la lumière au noir au lieu de l'y moyenner. La saturation tient jusqu'au
    /// bout, et les braises restent des braises.
    private static let cote: CGFloat = 300
    private static var ileCentre: CGFloat { ileHaut + ileHauteur / 2 }

    private var halo: some View {
        ZStack {
            // LA BRAISE : orange vif au cœur, rouge profond au bord. Serrée
            // autour de l'île — pas un nuage au milieu de l'écran.
            Circle()
                .fill(RadialGradient(
                    colors: [Color(red: 1.00, green: 0.66, blue: 0.30).opacity(0.90),
                             Color(red: 1.00, green: 0.38, blue: 0.10).opacity(0.55),
                             Color(red: 0.90, green: 0.07, blue: 0.14).opacity(0.30),
                             .clear],
                    center: .center, startRadius: 2, endRadius: 145))
                .frame(width: Self.cote, height: Self.cote)
                .blur(radius: 24)
                .blendMode(.plusLighter)

            // LE HALO BLANC, derrière l'île : une capsule floue, plus large
            // qu'elle, qui la fait flotter au lieu de la poser.
            Capsule()
                .fill(Color.white)
                .frame(width: 186, height: 58)
                .blur(radius: 20)
                .opacity(0.50)
                .blendMode(.plusLighter)
        }
        // Le centre du groupe (haut 300) posé sur le centre de l'île, pas sur
        // celui de l'écran : sans ça le halo tombe au milieu de la page.
        .offset(y: Self.ileCentre - Self.cote / 2)
        .scaleEffect(souffle ? 1.05 : 1.0)
        .opacity(souffle ? 1.0 : 0.80)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    /// La bordure blanche de l'île — « trop belle » (verdict 05-09). Vive en
    /// haut, éteinte en bas : la même arête de lumière que le bouton velours.
    private var bordureIle: some View {
        Capsule()
            .strokeBorder(
                LinearGradient(
                    stops: [.init(color: .white.opacity(0.92), location: 0.0),
                            .init(color: .white.opacity(0.34), location: 0.45),
                            .init(color: .white.opacity(0.10), location: 1.0)],
                    startPoint: .top, endPoint: .bottom),
                lineWidth: 1.4)
            // 3 pt de plus que l'île de chaque côté : l'anneau se voit AUTOUR
            // de la pastille noire que le système dessine par-dessus l'app.
            .frame(width: Self.ileLargeur + 6, height: Self.ileHauteur + 6)
            .shadow(color: .white.opacity(0.55), radius: 10)
            .padding(.top, Self.ileHaut - 3)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }

    // MARK: Le bas de l'écran

    @ViewBuilder
    private var corpsDuBas: some View {
        switch etat {
        case .repos, .ouvre:
            VStack(spacing: 14) {
                BoutonPrimaire(title: "Se connecter avec Apple",
                               glyph: "apple.logo",
                               respecteLaCasse: true) {
                    entrer()
                }
                .disabled(etat == .ouvre)
                .opacity(etat == .ouvre ? 0.5 : 1)

                Text("En continuant, tu acceptes les conditions\net la politique de confidentialité.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.34))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

        case .verdict(let verdict):
            // L'AIGUILLAGE, à l'écran : c'est ce que la racine consommera.
            VStack(spacing: 10) {
                Text(verdict.estNouvelle ? "Nouveau compte" : "Compte connu")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [.white, Color(red: 0.72, green: 0.70, blue: 0.78)],
                                       startPoint: .top, endPoint: .bottom))
                Text(verdict.estNouvelle
                     ? "Aucune ligne user_prefs → le film de Nosfy"
                     : "Un profil existe → l'app, directement")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                Text(verdict.userID)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.26))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .multilineTextAlignment(.center)
            .transition(.opacity)

        case .panne(let quoi, let interrupteur):
            VStack(spacing: 12) {
                Text(interrupteur ? "La feuille Apple a répondu.\nLe serveur, pas encore."
                                  : "Ça n'a pas abouti.")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .multilineTextAlignment(.center)
                Text(quoi)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.40))
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                BoutonPrimaire(title: "Réessayer") { entrer() }
                    .padding(.top, 4)
            }
        }
    }

    // MARK: Le tour

    private func entrer() {
        guard etat != .ouvre else { return }
        withAnimation(.easeOut(duration: 0.2)) { etat = .ouvre }

        Task { @MainActor in
            do {
                let verdict = try await AppleAuth.entrer()
                withAnimation(.easeOut(duration: 0.45)) { etat = .verdict(verdict) }
                onVerdict(verdict)
            } catch let panne as AppleAuth.Panne {
                if panne == .annulee {
                    withAnimation(.easeOut(duration: 0.2)) { etat = .repos }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        etat = .panne(panne.errorDescription ?? "inconnue",
                                      interrupteur: panne.estInterrupteurServeur)
                    }
                }
            } catch {
                withAnimation(.easeOut(duration: 0.3)) {
                    etat = .panne(error.localizedDescription, interrupteur: false)
                }
            }
        }
    }
}
