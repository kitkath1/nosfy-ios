import AVFoundation
import SwiftUI
import UIKit

// MARK: - Le lecteur de cinématique
//
// `AVPlayerLayer` nu dans un `UIView`. `VideoPlayer` (AVKit) apporte ses
// commandes de lecture et son propre fond — deux choses dont une cinématique
// ne veut pas.
//
// ⚠️ POURQUOI IL VIT DANS SON PROPRE FICHIER DEPUIS LE 25-08.
// Il habitait `CoffreFortView.swift`, le fichier que la refonte du coffre
// (`tools/coffre-v2/`) remplace entièrement — alors qu'il est consommé par
// CINQ sites hors de cette page : `StoryVideo.swift` (×2) et `BravoLab.swift`
// (×3). Archiver la page sans l'en sortir aurait cassé les stories ET la page
// BRAVO. C'est le jalon C0 du plan.
//
// ⚠️ SA BORNE, ET ELLE EST ÉCRITE AILLEURS DANS LE DÉPÔT.
// `videoGravity = .resizeAspect` est CODÉ EN DUR : ce lecteur ne convient
// qu'à un cadre au ratio EXACT du fichier. `PorteEntree.swift:878-882` a payé
// la leçon — « convenait quand le cadre collait au ratio du fichier à 7e-5
// près ; depuis la marge de parallaxe, il laissait 3,4 pt de colonnes vides »
// — et s'est fait son propre hôte en `fill` + clip. Avant de le réutiliser :
// mesurer le ratio du cadre, ne pas l'hériter.

final class CinematicPlayerHost: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct CinematicPlayer: UIViewRepresentable {
    let player: AVPlayer
    /// Le fond de l'hôte. NOIR partout (une cinématique se joue sur du noir) —
    /// sauf pour un lecteur qui BOUCLE : à chaque bouclage, `AVPlayerLooper`
    /// change d'item et la couche se vide le temps d'une à trois images. Avec
    /// un fond noir, ce vide est un FLASH NOIR (mesuré : luminance 0,0000, une
    /// fois par période) ; avec un fond transparent, c'est l'image posée
    /// dessous qui apparaît — et comme le fichier de boucle commence et finit
    /// sur la même image, c'est exactement celle qu'on devait voir.
    var opaqueBackground: Bool = true

    func makeUIView(context: Context) -> CinematicPlayerHost {
        let view = CinematicPlayerHost()
        view.backgroundColor = opaqueBackground ? .black : .clear
        view.isOpaque = opaqueBackground
        // `resizeAspect`, et non `resizeAspectFill`. La vidéo est en 16:9
        // PAYSAGE, sa place fait 40 % de la hauteur d'un écran de téléphone :
        // remplir imposait de jeter 35 % de la largeur, et ce tiers-là
        // contenait les FLANCS DU COFFRE. À l'écran l'objet n'était plus
        // lisible — une masse sombre coupée des deux côtés.
        //
        // On entre donc la vidéo entière, et c'est `restScale` qui la fait
        // respirer jusqu'aux bords. Le cadre laisse du noir au-dessus et en
        // dessous : sur une page noire absolue, personne ne le verra jamais.
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: CinematicPlayerHost, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
        view.backgroundColor = opaqueBackground ? .black : .clear
        view.isOpaque = opaqueBackground
    }
}
