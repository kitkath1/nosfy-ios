import SwiftUI
import AVFoundation

// MARK: - LES DÉMONS
//
// Les trois boucles qui vivent au milieu des cartes de la pile, une par
// offre : `video_demon_1` pour 100, `_2` pour 200, `_3` pour 300.
//
// TROIS CHOSES QUI NE SE VOIENT PAS ET SANS LESQUELLES ÇA NE MARCHE PAS :
//
// 1. LA BOUCLE PASSE PAR `AVPlayerLooper`, jamais par un observateur
//    `didPlayToEndTime` suivi d'un `seek(.zero)`. La seconde méthode laisse
//    une image noire au raccord — quelques dizaines de millisecondes, mais sur
//    une carte qu'on regarde tourner en boucle, ce hoquet est exactement le
//    genre de détail qui fait « cheap ». Le looper, lui, enfile deux
//    exemplaires du même item dans une file et ne montre jamais de couture.
//
// 2. LE MUET EST OBLIGATOIRE, ET IL N'EST PAS ACQUIS : les trois fichiers
//    portent une piste audio à deux canaux. Trois cartes qui jouent en
//    permanence, ce serait trois pistes par-dessus la musique de qui que ce
//    soit.
//
// 3. `automaticallyWaitsToMinimizeStalling = false`. Les fichiers sont dans le
//    paquet : il n'y a rien à mettre en tampon, et attendre un réseau qu'on
//    n'utilise pas ne fait que retarder la première image.
//
// LE LECTEUR EST ATTACHÉ À LA CARTE, PAS À L'OFFRE, et c'est ce que la
// mécanique du rail permet : l'offre d'une carte ne change JAMAIS d'un cran à
// l'autre — vérifié sur les quatre rangs dans les deux sens, l'indice est
// invariant par la renumérotation. Chaque carte garde donc sa vidéo à vie :
// aucun rechargement, aucune couture, et le lecteur se crée une seule fois.

/// L'hôte : un `AVPlayerLayer` nu. `VideoPlayer` (AVKit) apporterait ses
/// commandes, son fond et sa gestuelle — trois choses dont une carte n'a que
/// faire.
final class DemonLayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct DemonVideo: UIViewRepresentable {
    /// 0, 1 ou 2 — l'indice de l'offre, pas celui de la carte.
    var offre: Int

    final class Coordinator {
        var player: AVQueuePlayer?
        // Le looper DOIT être retenu : relâché, la boucle s'arrête à la fin du
        // premier tour et la carte se fige sur une image noire.
        var looper: AVPlayerLooper?
        var offre = -1
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> DemonLayerView {
        let v = DemonLayerView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        // LE DÉMON RESPIRE DANS LA CARTE, il ne la remplit pas. Les vidéos font
        // 1024 × 1792 (0,571) pour une carte en 0,777 : en `resizeAspectFill`
        // le cadre était couvert en LARGEUR, donc le sujet grossissait d'un
        // tiers et 27 % de la hauteur partait au recadrage — oreilles en haut,
        // pieds en bas. En `resizeAspect` il tient en HAUTEUR, entier et
        // centré, et les bandes latérales qu'il laisse sont noires, donc
        // invisibles sous `plusLighter` : elles ne coûtent rien.
        v.playerLayer.videoGravity = .resizeAspect
        monter(context.coordinator, dans: v)
        return v
    }

    func updateUIView(_ v: DemonLayerView, context: Context) {
        guard context.coordinator.offre != offre else { return }
        monter(context.coordinator, dans: v)
    }

    static func dismantleUIView(_ v: DemonLayerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }

    private func monter(_ c: Coordinator, dans v: DemonLayerView) {
        c.offre = offre
        c.looper?.disableLooping()
        c.player?.pause()

        guard let url = Bundle.main.url(forResource: "video_demon_\(offre + 1)",
                                        withExtension: "mp4") else {
            // Sans le fichier, la carte reste la carte : son obsidienne, son
            // grain, son tube. On ne pose jamais un rectangle noir « en
            // attendant ».
            v.playerLayer.player = nil
            return
        }
        let item = AVPlayerItem(url: url)
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        c.looper = AVPlayerLooper(player: p, templateItem: item)
        c.player = p
        v.playerLayer.player = p
        p.play()
    }
}
