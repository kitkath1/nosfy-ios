import SwiftUI
import AVFoundation
import UIKit

// MARK: - La bourse
//
// LA MONNAIE N'EXISTE PAS ENCORE DANS WOOP. Aucun modèle SwiftData ne porte
// de pièces (Workout, LoggedExercise, StrengthSet, CardioPhase — c'est tout),
// et aucune règle ne dit ce qu'une séance rapporte. Ce point d'accès est donc
// une MAQUETTE assumée, tenue en UN SEUL endroit : le jour où l'économie est
// tranchée, c'est ce corps-là qu'on remplace, et pas une ligne de la page ne
// bouge.
enum CoffreFortPurse {
    static func coins(finishedWorkouts: Int) -> Int { finishedWorkouts * 25 }
}

// MARK: - La partition

/// Les temps de la cinématique, en secondes depuis l'ouverture de la page.
enum CoffreFortCine {
    /// Le cadrage de REPOS.
    ///
    /// La source est en 16:9 ; pour qu'elle couvre 40 % de la hauteur d'un
    /// téléphone il faudrait la grossir de 1,55 et JETER 35 % de sa largeur
    /// — c'est-à-dire les flancs du coffre. Essayé : l'objet n'était plus
    /// lisible. À 1,0 il est entier mais l'image tombe à 26 % de l'écran et
    /// flotte dans sa place.
    ///
    /// 1,25 est le compromis MESURÉ : l'image occupe 31 % de la hauteur, il
    /// reste 50 pt de rogne de chaque côté — et ces 50 pt-là ne contiennent
    /// que le bokeh sombre du fond, jamais le coffre. Surtout, le fondu du
    /// masque est calé sur l'IMAGE : il grandit avec elle, donc les bords
    /// haut et bas — les seuls dont la coupe se voyait — restent éteints.
    static let restScale: CGFloat = 1.25
    /// La part d'écran réservée au bloc vidéo.
    static let slotRatio: CGFloat = 0.40
    /// Le cadrage d'ouverture : le coffre déborde largement et tombe au
    /// milieu de l'écran.
    static let zoom: CGFloat = 2.15
    /// Le décalage qui descend le coffre au centre (en fraction de hauteur).
    static let zoomDrop: CGFloat = 0.20
    /// La vidéo apparaît en fondu : la feuille monte sur du NOIR, et c'est
    /// la lumière qui la révèle — jamais l'inverse.
    static let fadeIn: Double = 0.55
    /// La descente vers la place de repos commence — le coffre est ouvert,
    /// la plaque va glisser.
    static let settleAt: Double = 5.60
    static let settleFor: Double = 2.40
    /// Le contenu naît APRÈS que la vidéo se soit posée : un souffle après
    /// l'image, jamais avant elle.
    static let contentAt: Double = 7.85
}

// MARK: - Le lecteur

/// `AVPlayerLayer` nu dans un `UIView`. `VideoPlayer` (AVKit) apporte ses
/// commandes de lecture et son propre fond — deux choses dont une
/// cinématique ne veut pas.
final class CinematicPlayerHost: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

struct CinematicPlayer: UIViewRepresentable {
    let player: AVPlayer
    /// Le fond de l'hôte. NOIR partout (une cinématique se joue sur du noir) —
    /// sauf pour un lecteur qui BOUCLE : à chaque bouclage, `AVPlayerLooper`
    /// change d'item et la couche se vide le temps d'une à trois images. Avec
    /// un fond noir, ce vide est un FLASH NOIR, une fois par période ; avec un
    /// fond transparent, c'est l'image posée dessous qui apparaît — et comme
    /// le fichier de boucle commence et finit sur la même image, c'est
    /// exactement celle qu'on devait voir.
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

// MARK: - La page du trésor

/// Une page toute noire, la cinématique du coffre en gros plan qui vient se
/// poser en haut, puis le titre, la pièce et le compte.
struct CoffreFortView: View {
    let coins: Int
    var onClose: () -> Void = {}

    @State private var player: AVPlayer?
    @State private var visible = false
    /// La vidéo a rejoint sa place de repos.
    @State private var settled = false
    /// Le contenu sous la vidéo est né.
    @State private var born = false
    /// L'horloge de la fumée de la pièce, ou `nil` si personne n'y touche.
    @State private var smokeStart: Date?
    @State private var smokeEnd: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    video(slot: H * CoffreFortCine.slotRatio,
                          screenWidth: geo.size.width, screenHeight: H)
                    Spacer(minLength: 0)
                    content(screenHeight: H)
                        .opacity(born ? 1 : 0)
                        .offset(y: born ? 0 : 14)
                    Spacer(minLength: 0)
                }
                // Le groupe respire dans TOUT ce qui reste sous la vidéo,
                // au lieu de se tasser sous elle en laissant un quart
                // d'écran de nuit vide. Et il se pose un peu au-dessus du
                // milieu : centré au cordeau, il paraît tomber trop bas —
                // l'œil place le centre optique plus haut que le centre
                // géométrique.
                .padding(.bottom, H * 0.14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .overlay(alignment: .topLeading) { closeButton }
        .overlay(alignment: .bottom) { descente }
        .onAppear(perform: start)
        .onDisappear { player?.pause() }
    }

    // MARK: La vidéo

    @ViewBuilder
    private func video(slot: CGFloat, screenWidth W: CGFloat,
                       screenHeight H: CGFloat) -> some View {
        Group {
            if let player {
                CinematicPlayer(player: player)
            } else {
                Color.black
            }
        }
        // Le cadre A EXACTEMENT le format de la source (16:9). C'est la
        // condition pour que le fondu de bords serve à quelque chose : en
        // `resizeAspect` dans un cadre plus haut, l'image ne touche plus ses
        // bords, et un masque calé sur le CADRE ne fond que du noir. Mesuré
        // sur capture : la luminance tombait de 13,16 à 0,000 en douze
        // pixels — une couture franche en travers de l'écran, exactement ce
        // que le masque était censé empêcher.
        .frame(width: W, height: W * 9.0 / 16.0)
        .clipped()
        // Le fondu, calé sur l'image elle-même. MESURÉ sur le fichier : la
        // bande haute est à 1–5/255 (elle passerait seule), mais la bande
        // BASSE est à 20/255 avec des pointes à 91 — c'est le sol éclairé du
        // rendu 3D. C'est elle qu'il faut éteindre.
        .mask(edgeMask)
        .scaleEffect(zoomNow, anchor: .center)
        .offset(y: settled || reduceMotion ? 0 : H * CoffreFortCine.zoomDrop)
        .opacity(visible ? 1 : 0)
        // La PLACE — 40 % de l'écran — est réservée ici, et elle ne coupe
        // rien : pendant l'ouverture l'image déborde volontiers de l'écran,
        // c'est le plan large.
        .frame(height: slot)
        .allowsHitTesting(false)
    }

    private var zoomNow: CGFloat {
        settled || reduceMotion ? CoffreFortCine.restScale : CoffreFortCine.zoom
    }

    /// Une passe horizontale masquée par une passe verticale : les deux
    /// alphas se multiplient, et le cadre s'éteint sur ses quatre bords.
    private var edgeMask: some View {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.075),
            .init(color: .black, location: 0.925),
            .init(color: .clear, location: 1.0)
        ], startPoint: .leading, endPoint: .trailing)
        .mask(
            LinearGradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .black, location: 0.055),
                // Le bas s'éteint sur 14 % — deux fois plus que le haut.
                // C'est là qu'est le sol éclairé, et c'est le seul bord dont
                // la coupe se voyait à l'œil nu.
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1.0)
            ], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: Le titre, la pièce, le compte

    @ViewBuilder
    private func content(screenHeight H: CGFloat) -> some View {
        // La pièce vaut 15 % de la hauteur d'écran, comme demandé.
        let coinR = H * 0.075

        VStack(spacing: 0) {
            Text("Ton trésor")
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.silverText)

            // La coupure est IMPOSÉE. Sur une ligne, le sous-titre faisait
            // 288 px de large contre 141 au titre : un T renversé, bas-lourd,
            // qui ouvrait le bloc au lieu de le refermer. Et il cassait tout
            // seul, très mal, au premier cran de Dynamic Type au-dessus de L.
            Text("Chaque séance terminée\ny dépose sa pièce.")
                .font(.inter(14))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                // `fixedSize` vertical : sans lui SwiftUI laisse le texte se
                // faire écraser par la largeur idéale de ses frères et le
                // TRONQUE — mesuré à l'écran, « Chaque séance terminée… »
                // avec des points de suspension, alors que la place est là.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 9)
                .padding(.horizontal, 30)

            // LA PIÈCE, VIVANTE — plus le PNG. Elle prend la même softbox
            // que tout le reste, elle tourne au doigt, et son croissant
            // respire. Elle règle aussi un reproche du jury : l'emblème était
            // joué DEUX FOIS sur la page (le croissant du coffre, puis celui
            // de la pièce), la seconde en plus gros et sans rien apporter.
            //
            // LE GABARIT EST OBLIGATOIRE. L'hôte du shader fait 3,4 rayons
            // (il lui faut de la place pour son halo) : laissé libre, il
            // impose sa taille et la pièce vient RECOUVRIR le titre — mesuré
            // à 138 pt de débord vers le haut. Ce `Color.clear` fixe la place
            // en layout, et l'overlay laisse la lumière sortir (SwiftUI ne
            // rogne pas une overlay).
            //
            // Repères, depuis le haut de la boîte : centre de la pièce à
            // 1 rayon, centre du reflet à 3 rayons — ils se touchent donc
            // exactement à 2 rayons, le bas du métal.
            let host = coinR * MoonCoinView.hostScale

            Color.clear
                // 2,95 rayon et non 3,3 : c'est ce gabarit — la place
                // réservée au reflet — qui tenait la pastille à 85 pt sous le
                // métal, pas son `padding`. Le reflet meurt maintenant à 2,93
                // rayon (voir les arrêts du masque), donc la place suit.
                .frame(width: coinR * 2, height: coinR * 2.95)
                .overlay(alignment: .top) {
                    ZStack(alignment: .top) {
                        // LE HALO. Très bas — 4 % de pic sur deux rayons et
                        // demi. Plus fort, il fusionne avec le bloom que la
                        // pièce porte déjà et l'objet cesse d'être un bijou
                        // pour devenir une lampe posée sur la page.
                        RadialGradient(
                            colors: [Color(red: 1.0, green: 0.78, blue: 0.36)
                                        .opacity(0.040), .clear],
                            center: .center, startRadius: coinR * 0.5,
                            endRadius: coinR * 2.5)
                            .frame(width: coinR * 5, height: coinR * 5)
                            .offset(y: -coinR * 1.5)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)

                        MoonCoinView(coinR: coinR, onTap: fireSmoke)
                            // LA FUMÉE SOMBRE. Elle sort de la pièce, sur la
                            // nuit de la page — à peine plus claire qu'elle.
                            // C'est l'inverse exact du header, où le fond est
                            // le halo orange : là-bas une fumée sombre ferait
                            // une tache, ici une fumée claire ferait un nuage
                            // posé sur l'écran.
                            .overlay {
                                if let smokeStart {
                                    CoinSmoke(center: CGPoint(x: host / 2,
                                                              y: host / 2),
                                              radius: coinR,
                                              start: smokeStart, end: smokeEnd,
                                              palette: .dark)
                                }
                            }
                            .offset(y: coinR - host / 2)

                        // LE REFLET. Le procédé des cartes de l'accueil :
                        // l'objet RETOURNÉ sous lui-même, éteint en dégradé.
                        // Comme c'est le MÊME shader, il suit le lacet tout
                        // seul — tourner la pièce fait danser son reflet, sans
                        // une ligne de synchronisation.
                        MoonCoinView(coinR: coinR, draggable: false)
                            .scaleEffect(y: -1)
                            .mask(
                                // Les arrêts sont calés sur la géométrie : le
                                // reflet naît là où les deux métaux se
                                // touchent (0,21 de son cadre) et meurt avant
                                // le bas du gabarit (0,62).
                                LinearGradient(stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: .black.opacity(0.30),
                                          location: 0.21),
                                    .init(color: .clear, location: 0.47)
                                ], startPoint: .top, endPoint: .bottom)
                            )
                            .blur(radius: 3.0)
                            .offset(y: coinR * 3 - host / 2)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.top, 24)

            // La pastille REMONTE (verdict du 2026-08-07). Descendue à 26 pt
            // pour ne pas former « une sucette » avec la pièce, elle partait
            // trop loin : le gouffre entre les deux cassait le groupe au lieu
            // de l'aérer. À 6 pt elle respire encore — le reflet de la pièce
            // meurt avant elle — sans se décrocher du compte qu'elle porte.
            CoffreFortBadgeView(count: coins)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
    }

    /// L'échappée. Elle naît avec le contenu : pendant la cinématique il n'y
    /// a rien à quitter, et un bouton qui attend dans un coin pendant un
    /// plan-séquence le désamorce.
    @ViewBuilder
    private var closeButton: some View {
        if born {
            // LE CHEVRON DE LA MAISON, à l'identique de la fiche
            // d'exercice : 44 pt, coin continu de 15, verre fumé noir, liseré
            // blanc à 8 %. L'ancien — un `chevron.down` dans un rond de
            // matériau — était le seul élément non-or de la page, et il
            // tombait en plein sur le coffre.
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 44, height: 44)
                    .background {
                        Color.clear.glassEffect(
                            .regular.tint(Color.black.opacity(0.5)).interactive(),
                            in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                    .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.leading, 20)
            .padding(.top, 16)
            .transition(.opacity)
            .accessibilityLabel("Fermer")
        }
    }

    /// Le toucher de la pièce : la bouffée naît, puis se démonte une fois
    /// éteinte pour rendre les 30 Hz du TimelineView. (L'haptique et le
    /// tintement partent, eux, depuis `MoonCoinView` — au plus près du
    /// doigt.)
    private func fireSmoke() {
        smokeStart = .now
        smokeEnd = nil
        let mark = Date.now.addingTimeInterval(0.14)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            smokeEnd = mark
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard smokeEnd == mark else { return }
            smokeStart = nil
            smokeEnd = nil
        }
    }

    /// L'INVITE À DESCENDRE. Les trois chevrons de la page démon
    /// (`SlotChevrons`) — ce sont déjà les flèches de la maison, en cascade
    /// déphasée pour se lire comme un mouvement et non comme trois
    /// clignotants. Les reprendre ici, c'est dire au doigt que la page
    /// continue AVEC LE MÊME SIGNE que celui qu'il retrouvera en bas.
    ///
    /// Elles naissent avec le contenu : pendant la cinématique il n'y a rien
    /// à aller chercher, et une invite qui clignote sous un plan-séquence le
    /// désamorce.
    @ViewBuilder
    private var descente: some View {
        if born {
            SlotChevrons()
                .padding(.bottom, 26)
                .transition(.opacity)
        }
    }

    // MARK: La mise en route

    private func start() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "coffre-salut",
                                        withExtension: "mp4") else {
            // Sans le fichier, la page reste noire et le contenu naît tout
            // de suite : on ne bloque jamais l'utilisatrice sur une absence.
            withAnimation(.easeOut(duration: 0.4)) { settled = true; born = true }
            return
        }
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        // La piste audio a été retirée à l'encodage ; le muet est une
        // ceinture — une cinématique ne coupe pas la musique de personne.
        p.isMuted = true
        // Une cinématique ne se met pas en pause pour attendre le réseau :
        // le fichier est dans le paquet, il n'y a rien à mettre en tampon.
        p.automaticallyWaitsToMinimizeStalling = false
        player = p

        withAnimation(.easeOut(duration: CoffreFortCine.fadeIn)) { visible = true }
        p.play()

        guard !reduceMotion else {
            // Ni cadrage ni descente : la vidéo joue à sa place, et le
            // contenu est là dès la première image.
            settled = true
            withAnimation(.easeOut(duration: 0.45)) { born = true }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + CoffreFortCine.settleAt) {
            withAnimation(.easeInOut(duration: CoffreFortCine.settleFor)) {
                settled = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + CoffreFortCine.contentAt) {
            withAnimation(.easeOut(duration: 0.65)) { born = true }
        }
    }
}

// MARK: - Le parcours

/// Deux pages plein écran empilées : le coffre-fort, puis la PAGE DÉMON.
/// On descend d'un geste, on remonte du même.
///
/// POURQUOI UN PAGER ET PAS UNE NAVIGATION. Les deux pages sont le même
/// lieu — le trésor et ce qu'on y gagne. Une pile de navigation les
/// séparerait par une transition latérale et un bouton retour, c'est-à-dire
/// par la grammaire de « je change d'écran ». Le défilement paginé dit
/// l'inverse : c'est la même scène, elle continue plus bas.
///
/// LE PIÈGE DU GESTE, et pourquoi ça marche quand même. La page démon a pour
/// geste central de TIRER UNE CARTE VERS LE BAS — la même direction que le
/// pager. Ça ne se dispute pas, parce que sa `DragGesture` a une distance
/// minimale de ZÉRO : elle prend le doigt à l'instant du contact et gagne
/// donc sur le défilement partout où il y a une carte. Ailleurs sur la page,
/// c'est le pager qui répond. À vérifier sur appareil : c'est le genre
/// d'arbitrage que le simulateur juge mal.
///
/// `LazyVStack` : la page démon porte quatre cartes à shader, une aurore
/// plein écran et son grain. Les monter d'avance ferait tourner tout ça
/// derrière le coffre-fort, invisible et payé plein tarif — la leçon déjà
/// payée sur la home, dont le ciel tournait derrière le splash.
struct CoffreFortFlow: View {
    let coins: Int
    var onClose: () -> Void = {}

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                CoffreFortView(coins: coins, onClose: onClose)
                    .containerRelativeFrame(.vertical)
                HaloDawnLab()
                    .containerRelativeFrame(.vertical)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .background(Color.black)
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Le banc

/// `-coffreLab` : la page du trésor seule, rejouable. Sans lui, chaque tour
/// de réglage coûtait la traversée splash → connexion → home → toucher.
struct CoffreFortLab: View {
    @State private var run = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // `id` : rejouer, c'est remonter la vue — le lecteur repart de
            // zéro et la partition avec lui.
            CoffreFortFlow(coins: 325)
                .id(run)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                run += 1
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.trailing, 18)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Le badge

/// Une plaque d'or en capsule, le nombre posé dessus, et la poussière qui la
/// nimbe. La plaque, son liseré, son balayage et la poudre vivent dans UN
/// shader (`treasureBadge`) ; le texte, lui, reste du texte — il doit rester
/// lisible, sélectionnable par l'accessibilité, et net à toutes les tailles.
struct CoffreFortBadgeView: View {
    let count: Int

    private static let plateHeight: CGFloat = 54
    /// Le débord de l'hôte : la poussière monte à ~46 pt de la plaque, et le
    /// fondu d'hôte du shader en mange 10 de plus.
    private static let pad: CGFloat = 34

    /// La largeur ne dépend que du NOMBRE de chiffres — le badge ne change
    /// pas de taille entre 111 et 999.
    private var plateWidth: CGFloat {
        CGFloat(String(max(count, 0)).count) * 25 + 56
    }

    var body: some View {
        let w = plateWidth
        let h = Self.plateHeight
        let hostW = w + Self.pad * 2
        let hostH = h + Self.pad * 2

        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = Float(timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                Rectangle()
                    .fill(.white)
                    .frame(width: hostW, height: hostH)
                    .colorEffect(ShaderLibrary.treasureBadge(
                        .float2(Float(hostW), Float(hostH)),
                        .float4(Float(hostW / 2), Float(hostH / 2),
                                Float(w), Float(h)),
                        .float(t),
                        .float(1.0)
                    ))
            }
            // L'encre : un brun profond, pas du noir — sur l'or, le noir pur
            // fait un trou, le brun fait une gravure.
            Text("\(count)")
                .font(.inter(38, .semibold))
                .foregroundStyle(Color(red: 0.204, green: 0.114, blue: 0.020))
        }
        .frame(width: hostW, height: hostH)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("\(count) pièces")
    }
}
