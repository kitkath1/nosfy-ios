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
enum TreasurePurse {
    static func coins(finishedWorkouts: Int) -> Int { finishedWorkouts * 25 }
}

// MARK: - La partition

/// Les temps de la cinématique, en secondes depuis l'ouverture de la page.
enum TreasureCine {
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

    func makeUIView(context: Context) -> CinematicPlayerHost {
        let view = CinematicPlayerHost()
        view.backgroundColor = .black
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
    }
}

// MARK: - La page du trésor

/// Une page toute noire, la cinématique du coffre en gros plan qui vient se
/// poser en haut, puis le titre, la pièce et le compte.
struct TreasureView: View {
    let coins: Int
    var onClose: () -> Void = {}

    @State private var player: AVPlayer?
    @State private var visible = false
    /// La vidéo a rejoint sa place de repos.
    @State private var settled = false
    /// Le contenu sous la vidéo est né.
    @State private var born = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let H = geo.size.height

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    video(slot: H * TreasureCine.slotRatio,
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
                .padding(.bottom, H * 0.06)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .overlay(alignment: .topLeading) { closeButton }
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
        .offset(y: settled || reduceMotion ? 0 : H * TreasureCine.zoomDrop)
        .opacity(visible ? 1 : 0)
        // La PLACE — 40 % de l'écran — est réservée ici, et elle ne coupe
        // rien : pendant l'ouverture l'image déborde volontiers de l'écran,
        // c'est le plan large.
        .frame(height: slot)
        .allowsHitTesting(false)
    }

    private var zoomNow: CGFloat {
        settled || reduceMotion ? TreasureCine.restScale : TreasureCine.zoom
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
        VStack(spacing: 0) {
            Text("Ton trésor")
                .font(.inter(30, .semibold))
                .tracking(-0.3)
                .foregroundStyle(WoopGradient.silverText)

            Text("Chaque séance terminée y dépose sa pièce.")
                .font(.inter(14))
                .foregroundStyle(Color.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 9)
                .padding(.horizontal, 34)

            Image("piece-woop")
                .resizable()
                .scaledToFit()
                .frame(height: H * 0.15)
                .padding(.top, 30)

            TreasureBadgeView(count: coins)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    /// L'échappée. Elle naît avec le contenu : pendant la cinématique il n'y
    /// a rien à quitter, et un bouton qui attend dans un coin pendant un
    /// plan-séquence le désamorce.
    @ViewBuilder
    private var closeButton: some View {
        if born {
            Button(action: onClose) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 60)
            .transition(.opacity)
            .accessibilityLabel("Fermer")
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

        withAnimation(.easeOut(duration: TreasureCine.fadeIn)) { visible = true }
        p.play()

        guard !reduceMotion else {
            // Ni cadrage ni descente : la vidéo joue à sa place, et le
            // contenu est là dès la première image.
            settled = true
            withAnimation(.easeOut(duration: 0.45)) { born = true }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + TreasureCine.settleAt) {
            withAnimation(.easeInOut(duration: TreasureCine.settleFor)) {
                settled = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + TreasureCine.contentAt) {
            withAnimation(.easeOut(duration: 0.65)) { born = true }
        }
    }
}

// MARK: - Le banc

/// `-coffreLab` : la page du trésor seule, rejouable. Sans lui, chaque tour
/// de réglage coûtait la traversée splash → connexion → home → toucher.
struct TreasureLab: View {
    @State private var run = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // `id` : rejouer, c'est remonter la vue — le lecteur repart de
            // zéro et la partition avec lui.
            TreasureView(coins: 325)
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
struct TreasureBadgeView: View {
    let count: Int

    private static let plateHeight: CGFloat = 36
    /// Le débord de l'hôte : la poussière monte à ~46 pt de la plaque, et le
    /// fondu d'hôte du shader en mange 10 de plus.
    private static let pad: CGFloat = 34

    /// La largeur ne dépend que du NOMBRE de chiffres — le badge ne change
    /// pas de taille entre 111 et 999.
    private var plateWidth: CGFloat {
        CGFloat(String(max(count, 0)).count) * 13 + 42
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
                .font(.inter(19, .semibold))
                .foregroundStyle(Color(red: 0.204, green: 0.114, blue: 0.020))
        }
        .frame(width: hostW, height: hostH)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("\(count) pièces")
    }
}
