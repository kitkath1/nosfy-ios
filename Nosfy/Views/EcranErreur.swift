import SwiftUI

// MARK: - L'ÉCRAN D'ERREUR (18-09) — le même pour tout, le mode avion compris

/// Son ordre : « prends ce personnage (erreur.mp4) en boucle, fr et anglais,
/// police Apple, dégradé de blanc en titre et sous-titre très léger comme la
/// partie tuto ». Donc : le noir, la bête qui attend (`erreur-loop.mp4`, muette,
/// en boucle — début et fin identiques, la boucle ne saute pas), UN titre en SF
/// semibold sur le blanc dégradé de la maison (`MotsFlou.blancDegrade`), UN
/// sous-titre en SF à 0,42 de blanc (le sourd de la home et du tuto), et le
/// bouton primaire noir « Réessayer ». Rien d'autre : pas de code, pas de
/// glyphe rouge, pas de card.
///
/// UN message, générique (« Ça n'a pas marché. » — vérifie ta connexion, rien
/// n'est perdu) : il sert pour TOUTE erreur, le mode avion compris. Le cas
/// (`ErreurNosfy.Cas`, réseau / serveur) ne change pas les mots : il va au
/// journal et pilote le rejeu automatique — dès que le réseau revient, l'écran
/// rejoue seul ; le bouton reste pour la main impatiente.
///
/// Il se pose de deux façons : à la racine (`EcranErreurHote`, pour tout site
/// qui appelle `ErreurNosfy.shared.signaler`) ou en place, quand une vue tient
/// déjà tout l'écran (`VerificationCompte`, la sortie de Nosfy).
///
/// Barreaux : `-sansErreurVideo` (le noir à la place de la bête — pour accuser
/// ou disculper le lecteur à la mesure), `-erreurLab reseau|serveur` (l'écran
/// seul au lancement, `EcranErreurLab`), `-erreurHorsLigne` (voir `Reseau`).
struct EcranErreur: View {
    var cas: ErreurNosfy.Cas
    /// Vrai = réglé (l'hôte ferme l'écran) ; faux = toujours en panne.
    var reessayer: @MainActor () async -> Bool
    /// « Plus tard » — nil = l'écran bloque jusqu'au succès.
    var fermer: (@MainActor () -> Void)? = nil

    static let sansVideo = CommandLine.arguments.contains("-sansErreurVideo")

    @State private var enCours = false
    /// Le deuxième échec de suite : le sous-titre le dit, sans s'énerver.
    @State private var echecs = 0
    @State private var pose = false
    private let reseau = Reseau.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// UN SEUL MESSAGE, GÉNÉRIQUE (18-09, son mot : « un message plus générique
    /// car il s'utilisera pour toutes les erreurs et le mode avion »). Le cas
    /// (réseau / serveur) ne change pas les mots : il sert au journal et au
    /// rejeu automatique. Le deuxième échec de suite nomme le mode avion.
    private var titre: String {
        L("Ça n'a pas marché.", "Something went wrong.")
    }

    private var sousTitre: String {
        echecs >= 2
            ? L("Toujours rien. Vérifie le mode avion ou le Wi‑Fi, puis réessaie dans un instant.",
                "Still nothing. Check airplane mode or Wi‑Fi, then try again in a moment.")
            : L("Vérifie ta connexion, puis réessaie. Rien n'est perdu : tout reste sur ton téléphone.",
                "Check your connection, then try again. Nothing is lost — everything stays on your phone.")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                // LA BÊTE — 3:4 comme le fichier (750 × 1000), sur le noir, sans
                // verre ni flou dessus (un verre posé sur une vidéo ne met rien
                // en cache). Le poster noir tient sa place au barreau.
                Group {
                    if Self.sansVideo { Color.black }
                    else { NosfyReel(nom: "erreur-loop") }
                }
                .frame(width: 210, height: 280)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 12) {
                    Text(titre)
                        .font(.system(size: 30, weight: .semibold))
                        .tracking(-30 * 0.026)
                        .foregroundStyle(MotsFlou.blancDegrade)
                        .accessibilityIdentifier("erreur-titre")
                    Text(sousTitre)
                        .font(.system(size: 17))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("erreur-sous-titre")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 26)
                // Le texte SE POSE (le geste du film : flou 8 → 0, +5 pt, 0,96 → 1).
                .blur(radius: pose ? 0 : 8)
                .opacity(pose ? 1 : 0)
                .scaleEffect(pose ? 1 : 0.96, anchor: .leading)
                .offset(y: pose ? 0 : 5)
                .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.9).delay(0.25),
                           value: pose)

                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    ZStack {
                        BoutonPrimaire(title: L("Réessayer", "Try again")) { relancer() }
                            .opacity(enCours ? 0 : 1)
                        if enCours {
                            ProgressView().tint(.white.opacity(0.7))
                        }
                    }
                    .frame(height: BoutonPrimaire.hauteur)
                    .accessibilityIdentifier("erreur-reessayer")

                    if let fermer {
                        Button(L("Plus tard", "Later")) { fermer() }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.30))
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("erreur-plus-tard")
                    }
                }
                .opacity(pose ? 1 : 0)
                .animation(.easeOut(duration: 0.6).delay(0.7), value: pose)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 30)
            .padding(.top, 40)
            .padding(.bottom, 28)
        }
        .preferredColorScheme(.dark)
        .onAppear { pose = true }
        // LE MODE AVION QUI S'ÉTEINT : le réseau revient, on rejoue sans rien
        // demander — c'est ce que la personne attend en voyant l'écran.
        .onChange(of: reseau.enLigne) { avant, apres in
            guard !avant, apres, !enCours else { return }
            relancer()
        }
    }

    private func relancer() {
        guard !enCours else { return }
        enCours = true
        Task { @MainActor in
            // Une réponse instantanée fait clignoter le bouton ; 0,6 s minimum.
            let debut = Date()
            let regle = await reessayer()
            let reste = 0.6 - Date().timeIntervalSince(debut)
            if reste > 0 { try? await Task.sleep(for: .seconds(reste)) }
            enCours = false
            if !regle { echecs += 1 }
            else { echecs = 0 }
        }
    }
}

// MARK: - L'hôte, à la racine

/// Posé UNE fois dans `RootView`, au-dessus de tout (zIndex 60) : rend la
/// demande courante d'`ErreurNosfy` et la ferme quand le rejeu réussit.
struct EcranErreurHote: View {
    private let erreurs = ErreurNosfy.shared

    var body: some View {
        if let d = erreurs.courante {
            EcranErreur(cas: d.cas, reessayer: { await rejouer(d) }, fermer: renoncer(d))
                .id(d.id)
                .transition(.opacity)
                .zIndex(60)
        }
    }

    private func rejouer(_ d: ErreurNosfy.Demande) async -> Bool {
        let regle = await d.reessayer()
        if regle { withAnimation(.easeOut(duration: 0.4)) { erreurs.fermer() } }
        return regle
    }

    private func renoncer(_ d: ErreurNosfy.Demande) -> (@MainActor () -> Void)? {
        guard let f = d.fermer else { return nil }
        return {
            withAnimation(.easeOut(duration: 0.4)) { erreurs.fermer() }
            f()
        }
    }
}

// MARK: - Le banc

/// `-erreurLab reseau` ou `-erreurLab serveur` : l'écran seul au lancement,
/// « Réessayer » échoue deux fois puis réussit (on voit les deux sous-titres et
/// la fermeture). Avec `-erreurHorsLigne`, le cas serveur se dit hors ligne.
struct EcranErreurLab: View {
    @State private var ferme = false
    @State private var essais = 0

    static var demande: Bool { CommandLine.arguments.contains("-erreurLab") }
    private static var cas: ErreurNosfy.Cas {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-erreurLab"), i + 1 < args.count, args[i + 1] == "reseau" {
            return .horsLigne
        }
        return .serveur(detail: "banc")
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if ferme {
                Text(L("Réglé.", "Fixed."))
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(MotsFlou.blancDegrade)
                    .accessibilityIdentifier("erreur-lab-regle")
            } else {
                EcranErreur(cas: Self.cas, reessayer: {
                    essais += 1
                    try? await Task.sleep(for: .seconds(0.8))
                    return essais >= 3
                }, fermer: { ferme = true })
                .onChange(of: essais) { _, n in if n >= 3 { withAnimation { ferme = true } } }
            }
        }
    }
}
