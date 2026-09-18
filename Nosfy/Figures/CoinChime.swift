import AVFoundation

// MARK: - Le tintement de la pièce
//
// La doctrine sonore de la maison est « rien n'est frappé, tout gonfle »
// (voir MonolithChime). Une pièce, elle, TINTE — c'est le seul endroit de
// l'app où l'on frappe quelque chose. On s'en écarte donc sciemment, mais on
// garde tout le reste de la règle : session `.ambient` + `mixWithOthers`
// (jamais par-dessus la musique de l'utilisatrice), volume bas, et hauteur
// variée à chaque lecture pour qu'aucune deux touchers ne sonnent pareil.
//
// Le son lui-même est SYNTHÉTISÉ (Woop/Media/CoinChink.wav) : aucun métal
// n'existait dans le paquet. Huit modes inharmoniques — les rapports d'un
// disque, pas ceux d'une gamme — sur 300 ms, attaque adoucie à 4 ms.
@MainActor
final class CoinChime {
    static let shared = CoinChime()

    /// Trois exemplaires en rotation : deux touchers rapprochés se
    /// superposent au lieu de se couper l'un l'autre. Un tintement tronqué
    /// s'entend immédiatement — c'est le bruit d'un bouton, plus d'un objet.
    private var players: [AVAudioPlayer] = []
    private var next = 0

    private init() {}

    func prepare() {
        guard players.isEmpty,
              let url = Bundle.main.url(forResource: "CoinChink",
                                        withExtension: "wav") else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        players = (0..<3).compactMap { _ in
            guard let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
            p.enableRate = true
            p.volume = 0.30
            p.prepareToPlay()
            return p
        }
    }

    /// - Parameters:
    ///   - volume: 0,30 est le tintement de la maison. La page du trésor
    ///     ouvre sa pièce à **0,14 et rate 0,72** (verdict du 26-08 : « un
    ///     plus petit bruit, élégant, très discret, premium ») — le même
    ///     métal, mais bas et grave : un objet lourd qu'on approche, pas un
    ///     bouton qu'on presse. ⚠️ Le volume est posé À CHAQUE lecture et pas
    ///     à la préparation : les trois exemplaires tournent, et un volume
    ///     réglé une fois resterait collé à celui qui l'a reçu.
    ///   - rate: `nil` = la variation maison (±6 %).
    func chink(volume: Float = 0.30, rate: Float? = nil) {
        prepare()
        guard !players.isEmpty else { return }
        let p = players[next % players.count]
        next += 1
        p.volume = volume
        // ±6 %, comme le monolithe : une pièce coulée deux fois ne sonne pas
        // deux fois pareil, et l'oreille repère une répétition exacte bien
        // avant de savoir dire pourquoi ça sonne faux.
        p.rate = rate ?? Float.random(in: 0.94...1.06)
        p.currentTime = 0
        p.play()
    }
}
