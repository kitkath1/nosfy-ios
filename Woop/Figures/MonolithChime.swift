import AVFoundation

// MARK: - Le son de la lumière
//
// Quand le doigt tourne le monolithe, les reflets balaient la laque — et la
// lumière a désormais un son. Deux murmures, dans l'esthétique du thème :
// rien n'est frappé, tout gonfle.
//
//   L'EFFLEUREMENT — on saisit : un souffle court, deux partiels hauts qui
//   respirent. Rejoué avec parcimonie pendant le geste, jamais en rafale, à
//   un volume qui suit la VITESSE du doigt : tourner lentement murmure,
//   tourner franchement éclaire.
//
//   LA GLISSADE — on relâche : l'inertie emporte l'objet, la lumière file
//   sur la laque et s'éloigne (glissement de hauteur de −5 %). Son volume
//   suit l'élan du relâcher.
//
// La hauteur varie d'un rien à chaque lecture (`rate` ±6 %) : deux gestes ne
// sonnent jamais exactement pareil — un objet, pas un widget. Mixé en
// `.ambient` + `mixWithOthers`, comme tous les murmures de la maison :
// jamais par-dessus la musique de l'utilisatrice.
@MainActor
final class MonolithChime {
    static let shared = MonolithChime()

    private var graze: AVAudioPlayer?
    private var glide: AVAudioPlayer?
    private var lastGraze = Date.distantPast

    private init() {}

    func prepare() {
        guard graze == nil else { return }
        try? AVAudioSession.sharedInstance()
            .setCategory(.ambient, options: [.mixWithOthers])
        func load(_ name: String) -> AVAudioPlayer? {
            guard let url = Bundle.main.url(forResource: name,
                                            withExtension: "wav") else { return nil }
            let p = try? AVAudioPlayer(contentsOf: url)
            p?.enableRate = true
            p?.prepareToPlay()
            return p
        }
        graze = load("MoonGraze")
        glide = load("MoonGlide")
    }

    /// Pendant le geste. `speed` ∈ [0,1] — la vitesse angulaire, normalisée
    /// par l'hôte. Garde-fou de cadence : un murmure au plus tous les 0,26 s,
    /// sinon le glissement continu devient une crécelle.
    func turn(speed: Double) {
        guard let graze, Date().timeIntervalSince(lastGraze) > 0.26 else { return }
        lastGraze = Date()
        graze.volume = Float(0.10 + 0.26 * min(max(speed, 0), 1))
        graze.rate = Float(0.94 + 0.12 * Double.random(in: 0...1))
        graze.currentTime = 0
        graze.play()
    }

    /// Au relâcher. `fling` ∈ [0,1] — l'élan restant du geste.
    func release(fling: Double) {
        guard let glide, fling > 0.08 else { return }
        glide.volume = Float(0.12 + 0.30 * min(max(fling, 0), 1))
        glide.rate = Float(0.92 + 0.10 * min(max(fling, 0), 1))
        glide.currentTime = 0
        glide.play()
    }
}
