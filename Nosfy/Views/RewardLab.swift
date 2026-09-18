import SwiftUI

// MARK: - Le banc des cards reward (`-rewardLab`)

/// LES PRISES DU BANC — lues UNE fois au lancement, jamais par image.
///
/// Elles vivent hors de `RewardLab` parce que les composants de la card
/// (`RewardCard.swift`) doivent pouvoir les lire sans qu'on leur fasse
/// traverser six niveaux de vues : une horloge figée qu'on threade en
/// paramètre finit toujours par manquer à un endroit, et c'est là que la
/// capture ment.
enum RewardBanc {
    /// Le banc est-il en scène ? (Les composants ne changent de
    /// comportement que sous ce drapeau — l'app, elle, ne le voit jamais.)
    static let actif = CommandLine.arguments.contains("-rewardLab")

    /// `-rewardFreeze <p>` — fige l'entrée de la card à un `p` donné.
    /// Sans elle, deux tours de fouettage ne se comparent JAMAIS au même
    /// instant de la rampe (1,45 s d'entrée, tout y bouge).
    static let fige: Double? = number(after: "-rewardFreeze")

    /// `-rewardT <s>` — fige l'horloge des VIES (pluie, onde, trame).
    /// ⚠️ Ce que ça couvre : les composants de ce chantier. La poudre, la
    /// flamme et les vidéos gardent la leur — on ne fige pas ce qu'on ne
    /// travaille pas.
    static let tFige: Double? = number(after: "-rewardT")

    /// `-rewardMire` — les graduations tous les 20 pt, pour lire une
    /// capture sans compter les pixels à la main.
    static let mire = CommandLine.arguments.contains("-rewardMire")

    /// `-rewardNu` — le bandeau de commandes disparaît (captures propres).
    static let nu = CommandLine.arguments.contains("-rewardNu")

    /// `-rewardAuto` — le banc balaie les six robes tout seul (le film de
    /// non-régression : `RewardScene` est commune, tout la touche).
    static let auto = CommandLine.arguments.contains("-rewardAuto")

    /// L'horloge d'un effet : figée sous `-rewardT`, vivante sinon.
    static func horloge(_ t: Double) -> Double { tFige ?? t }

    static func number(after flag: String) -> Double? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: flag), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return v
    }

    static func mot(after flag: String) -> String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: flag), i + 1 < a.count
        else { return nil }
        return a[i + 1]
    }
}

/// LE BANC — la card reward SEULE, sur du noir vrai.
///
/// Pourquoi il existe : jusqu'ici toutes les robes se regardaient à
/// travers `-exoLab`, avec `ExerciseDetailView` entière montée dessous.
/// Le scrim à 0,68 ne la cache pas — la photo, le dôme « Start exercise »
/// et SON HALO ORANGE traversent et polluent le jugement d'une card
/// censée vivre en nuit totale (constaté sur capture le 27-08). Ici : la
/// nuit, la card, rien.
///
/// Les prises :
/// - `-robe <halo|neon|galet|spotlight|fire|welcome|welcomeTexte>` —
///   la robe d'ouverture (défaut : `spotlight`, le chantier du jour) ;
/// - le bandeau du bas change de robe ; fermer la card la REJOUE (la
///   vraie sortie, puis la vraie entrée — jamais une coupe sèche) ;
/// - `-rewardAuto` balaie les six robes seul (le sim n'a pas de doigt) ;
/// - `-rewardFreeze <p>`, `-rewardT <s>`, `-rewardMire`, `-rewardNu`
///   (voir `RewardBanc`).
struct RewardLab: View {
    /// L'ordre du banc : le chantier du jour en tête.
    private static let robes: [(style: RewardStyle, robe: WelcomeRobe,
                                nom: String)] = [
        (.spotlight, .video, "spotlight"),
        (.halo, .video, "halo"),
        (.neon, .video, "neon"),
        (.galet, .video, "galet"),
        (.fire, .video, "fire"),
        (.welcome, .video, "welcome"),
        (.welcome, .texte, "welcomeTexte")
    ]

    @State private var index = RewardLab.indexDemande
    /// La card est en scène. Une fermeture la démonte, un battement plus
    /// tard elle renaît — c'est ça, « rejouer » : la vraie sortie suivie
    /// de la vraie entrée.
    @State private var montre = true
    /// L'identité de la card : elle change à chaque relance, sinon
    /// SwiftUI réutilise la vue et l'entrée ne rejoue pas.
    @State private var tour = 0

    private static let indexDemande: Int = {
        guard let m = RewardBanc.mot(after: "-robe"),
              let i = robes.firstIndex(where: { $0.nom == m })
        else { return 0 }
        return i
    }()

    private var courante: (style: RewardStyle, robe: WelcomeRobe,
                           nom: String) {
        Self.robes[index % Self.robes.count]
    }

    var body: some View {
        ZStack {
            // La nuit vraie — la card se juge sur ÇA, pas sur une page.
            Color.black.ignoresSafeArea()

            if montre {
                RewardPopup(
                    count: 4,
                    title: courante.style == .welcome
                        ? "Welcome back" : "Training",
                    subtitle: courante.style == .welcome
                        ? "Your next session is waiting for you."
                        : "Congratulations, you've completed your training!",
                    unit: "Sets",
                    style: courante.style,
                    robe: courante.robe,
                    videoNom: courante.style == .welcome
                        ? "reward-welcome" : nil,
                    onClose: { rejouer() })
                .id(tour)
                .transition(.identity)
            }

            if RewardBanc.mire { mireOverlay }
        }
        .overlay(alignment: .bottom) {
            if !RewardBanc.nu { bandeau }
        }
        .task { await balayage() }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    // MARK: Le bandeau

    /// Les commandes, au ras du bord bas : assez loin de la card (elle
    /// s'arrête bien au-dessus) pour ne rien mordre, et supprimables d'un
    /// drapeau quand la capture compte.
    private var bandeau: some View {
        HStack(spacing: 18) {
            fleche("chevron.left") { changer(-1) }
            Text(courante.nom)
                .font(.system(size: 12, weight: .semibold,
                              design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.62))
                .frame(minWidth: 104)
            fleche("chevron.right") { changer(1) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.white.opacity(0.07)))
        .padding(.bottom, 6)
    }

    private func fleche(_ nom: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: nom)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.75))
                .frame(width: 34, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Les mouvements du banc

    /// Rejouer la MÊME robe : la card vient de jouer sa sortie, on la
    /// démonte, et elle renaît un battement plus tard.
    private func rejouer() {
        montre = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            tour += 1
            montre = true
        }
    }

    /// Changer de robe : on ne joue PAS la sortie (on ne juge pas une
    /// sortie qu'on n'a pas demandée) — coupe nette, puis la vraie entrée
    /// de la robe suivante.
    private func changer(_ pas: Int) {
        montre = false
        index = (index + pas + Self.robes.count) % Self.robes.count
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            tour += 1
            montre = true
        }
    }

    /// `-rewardAuto` : le balayage des sept robes, chacune tenue le temps
    /// de son entrée + une pose. C'est le film de non-régression.
    private func balayage() async {
        guard RewardBanc.auto, RewardBanc.fige == nil else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5.2))
            guard !Task.isCancelled else { return }
            changer(1)
        }
    }

    // MARK: La mire

    /// Les graduations : les 20 pt, et les axes du centre. Elle se pose
    /// PAR-DESSUS tout — c'est un calque de mesure, pas un décor.
    private var mireOverlay: some View {
        GeometryReader { g in
            Canvas { ctx, taille in
                var petites = Path()
                var grandes = Path()
                var y: CGFloat = 0
                while y <= taille.height {
                    let p = Path { $0.move(to: CGPoint(x: 0, y: y))
                        $0.addLine(to: CGPoint(x: taille.width, y: y)) }
                    if Int(y) % 100 == 0 { grandes.addPath(p) }
                    else { petites.addPath(p) }
                    y += 20
                }
                var x: CGFloat = 0
                while x <= taille.width {
                    let p = Path { $0.move(to: CGPoint(x: x, y: 0))
                        $0.addLine(to: CGPoint(x: x, y: taille.height)) }
                    if Int(x) % 100 == 0 { grandes.addPath(p) }
                    else { petites.addPath(p) }
                    x += 20
                }
                ctx.stroke(petites, with: .color(.white.opacity(0.06)),
                           lineWidth: 0.5)
                ctx.stroke(grandes, with: .color(.cyan.opacity(0.22)),
                           lineWidth: 0.5)
                let axes = Path {
                    $0.move(to: CGPoint(x: taille.width / 2, y: 0))
                    $0.addLine(to: CGPoint(x: taille.width / 2,
                                           y: taille.height))
                    $0.move(to: CGPoint(x: 0, y: taille.height / 2))
                    $0.addLine(to: CGPoint(x: taille.width,
                                           y: taille.height / 2))
                }
                ctx.stroke(axes, with: .color(.cyan.opacity(0.42)),
                           lineWidth: 0.5)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
