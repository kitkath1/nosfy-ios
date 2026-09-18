import SwiftUI
import SwiftData
import AVFoundation
import UIKit

// ⚠️ DEUX PIÈCES ONT QUITTÉ CE FICHIER LE 25-08 (jalon C0 du chantier
// `tools/coffre-v2/`), parce que cette page va être REMPLACÉE et qu'elles sont
// consommées ailleurs :
//   · `CoffreFortPurse` → `CoffreFortPurse.swift` (5 sites : HomeAuroraView,
//     HomeNuit, ProfilLune, BravoLab, SetHistoryRow) ;
//   · `CinematicPlayer` + `CinematicPlayerHost` → `CinematicPlayer.swift`
//     (5 sites : StoryVideo ×2, BravoLab ×3).
// Rien d'autre n'a bougé : la page ci-dessous est la v1, intacte, et son
// exemplaire figé vit dans `tools/coffre-v2/ARCHIVE/`.

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
    /// 1,25 — et le détour par 1,50 aura servi à mesurer pourquoi. La
    /// nouvelle source (`coffre-beau`) cadre le coffre BEAUCOUP plus près que
    /// l'ancienne : à échelle égale l'objet est déjà plus gros, si bien que
    /// « en plus gros » l'a rendu ÉNORME dans le bandeau une fois posé
    /// (verdict Kathryn). L'échelle de repos revient donc à sa cote d'origine,
    /// et c'est le cadrage du film qui donne la taille.
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
    /// LA PARTITION EST RECALÉE SUR `coffre-beau` (18-08). Mesuré sur le
    /// fichier, image par image : l'ancienne source était PLATE (luminance
    /// 15 → 19 sur neuf secondes, rien ne s'y passait — c'est pour ça que la
    /// page s'était fabriqué sa propre caméra). La nouvelle a SA
    /// dramaturgie : noire jusqu'à 1,33 s, ouverture, montée continue, pic à
    /// 5,42 s, puis un RECUL de caméra jusqu'à la fin.
    ///
    /// La seconde noire du début a donc été coupée au montage (le fichier
    /// livré commence 1,00 s après la source) et tous les temps ont reculé
    /// d'autant. Le recul de la page (settle) tombe alors exactement sur le
    /// recul propre de la vidéo : les deux s'ADDITIONNENT — c'est voulu
    /// (verdict Kathryn), le zoom d'ouverture reste à 2,15.
    static let settleAt: Double = 4.60
    static let settleFor: Double = 2.40
    /// Le contenu naît APRÈS que la vidéo se soit posée : un souffle après
    /// l'image, jamais avant elle. La vidéo finit à 7,04 s — elle se fige
    /// sur son plan moyen, qui est l'image de repos.
    static let contentAt: Double = 6.85
}

// MARK: - La page du trésor

/// Une page toute noire, la cinématique du coffre en gros plan qui vient se
/// poser en haut, puis le titre, la pièce et le compte.
struct CoffreFortView: View {
    let coins: Int
    /// L'encoche de l'écran, mesurée par le parcours (la page, elle, ignore
    /// la zone sûre : sa vidéo doit toucher le bord). C'est ce qui permet de
    /// poser le chevron À SA PLACE, celle qu'il occupe sur toutes les autres
    /// pages, au lieu de le coller au bord physique.
    var safeTop: CGFloat = 0
    var onClose: () -> Void = {}

    @State private var player: AVPlayer?
    @State private var visible = false
    /// La vidéo a rejoint sa place de repos.
    @State private var settled = false
    /// Le contenu sous la vidéo est né.
    @State private var born = false
    /// On est passé devant : les minuteries en vol ne doivent plus rien
    /// rejouer par-dessus (elles ne s'annulent pas, elles se vérifient).
    @State private var skipped = false
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
                // LE RACCOURCI : la place de la vidéo est tapable de bout en
                // bout. La vidéo elle-même reste hors du toucher (elle a des
                // couches, un masque, une échelle : lui accrocher un geste,
                // c'est le perdre au premier changement de cadrage) — c'est
                // une surface claire posée sur sa PLACE qui l'écoute. Un tap
                // ne dispute rien au glissement du parcours.
                .overlay(alignment: .top) {
                    Color.clear
                        .frame(height: H * CoffreFortCine.slotRatio)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: skip)
                        .accessibilityLabel("Voir le détail")
                        .accessibilityAddTraits(.isButton)
                }
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
            //
            // ET C'EST LA PASTILLE DE BRAVO (verdict Kathryn : « la plaque
            // jaune est moche, mets celle de bravo »). La plaque d'or et son
            // nombre brun sont morts : à leur place, la capsule de nuit
            // cerclée d'un fil d'or, sa pièce en anthracite mat et son
            // compte en Inter-Light. Elle vient avec SA réponse au toucher —
            // le souffle court, la fumée sombre, le tintement, la vibration.
            TresorPastille(count: coins)
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
            // LE CHEVRON DE LA MAISON — le composant unique (ChipVerre,
            // la recette de la fiche d'exercice extraite le 14-08 :
            // « le même composant sur toutes les pages »).
            // ET À SA PLACE : la page ignore la zone sûre (sa vidéo touche le
            // bord), si bien qu'un `padding(.top, 16)` le posait à 17 pt du
            // bord PHYSIQUE — en pleine bande de l'îlot, 46 pt plus haut que
            // sur toutes les autres pages. La cote de la maison est celle de
            // `RangeeChips` : 20 sur le flanc, 4 sous l'encoche.
            ChipVerre(symbole: "chevron.left", label: "Fermer",
                      action: onClose)
                .padding(.leading, 20)
                .padding(.top, safeTop + 4)
                .transition(.opacity)
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

    // MARK: Passer devant

    /// LE RACCOURCI — ET IL RESTE SUR CETTE PAGE. Taper la vidéo, c'est
    /// arriver TOUT DE SUITE sur le trésor fini (verdict Kathryn, dit et
    /// redit) : la cérémonie se pose, on ne saute nulle part. Un essai qui
    /// enchaînait sur la page démon a été retiré — le raccourci sert à
    /// abréger l'attente, pas à changer de lieu.
    ///
    /// On ne peut pas « avancer l'horloge » ici comme sur le sommet de la
    /// lentille : cette partition n'est pas une fonction du temps, ce sont
    /// deux minuteries. Passer devant, c'est donc POSER la cérémonie à son
    /// état final — et amener le lecteur sur son image de repos, sinon la
    /// vidéo continuerait de jouer derrière un contenu déjà né. Les
    /// minuteries en vol, elles, se taisent d'elles-mêmes.
    /// `-coffreSkip` : le raccourci se déclenche tout seul à 3 s — le
    /// simulateur ne tape pas, c'est la seule façon de voir la cérémonie se
    /// poser d'un coup.
    private static let skipFire = CommandLine.arguments.contains("-coffreSkip")

    private func skip() {
        if !born {
            skipped = true
            if let item = player?.currentItem, item.duration.isNumeric {
                player?.seek(to: item.duration,
                             toleranceBefore: .zero, toleranceAfter: .zero)
            }
            player?.pause()
            withAnimation(.easeOut(duration: 0.28)) {
                settled = true
                born = true
            }
        }
    }

    // MARK: La mise en route

    private func start() {
        guard player == nil else { return }
        guard let url = Bundle.main.url(forResource: "coffre-beau",
                                        withExtension: "mp4") else {
            // Sans le fichier, la page reste noire et le contenu naît tout
            // de suite : on ne bloque jamais l'utilisatrice sur une absence.
            withAnimation(.easeOut(duration: 0.4)) { settled = true; born = true }
            return
        }
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        // LA MUSIQUE DU COFFRE (verdict Kathryn : « il manque la musique ») —
        // la piste du film, jouée sous la règle de la maison, celle du sacre :
        // catégorie `ambient` + `mixWithOthers`, et MUETTE si quelqu'un écoute
        // déjà quelque chose. Une cinématique ne coupe la musique de personne :
        // elle se tait, elle ne s'impose pas.
        let libre = !AVAudioSession.sharedInstance().isOtherAudioPlaying
        if libre {
            try? AVAudioSession.sharedInstance()
                .setCategory(.ambient, options: [.mixWithOthers])
        }
        p.isMuted = !libre
        // Une cinématique ne se met pas en pause pour attendre le réseau :
        // le fichier est dans le paquet, il n'y a rien à mettre en tampon.
        p.automaticallyWaitsToMinimizeStalling = false
        player = p

        withAnimation(.easeOut(duration: CoffreFortCine.fadeIn)) { visible = true }
        p.play()

        if Self.skipFire {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { skip() }
        }

        guard !reduceMotion else {
            // Ni cadrage ni descente : la vidéo joue à sa place, et le
            // contenu est là dès la première image.
            settled = true
            withAnimation(.easeOut(duration: 0.45)) { born = true }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + CoffreFortCine.settleAt) {
            guard !skipped else { return }
            withAnimation(.easeInOut(duration: CoffreFortCine.settleFor)) {
                settled = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + CoffreFortCine.contentAt) {
            guard !skipped else { return }
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
/// ⚠️ `GainCoffre` a QUITTÉ CE FICHIER le 29-08 pour `Services/EconomieWoop.swift`,
/// pour la raison qui avait déjà sorti `CoffreFortPurse` : le journal des gains
/// n'appartient pas à l'écran qui l'affiche, et laisser l'économie dans le
/// fichier d'une page qu'on démonte fait dépendre les autres du sort d'un écran.
struct CoffreFortFlow: View {
    let coins: Int
    var onClose: () -> Void = {}
    /// Le cran du manège à l'arrivée (15-09 : les quatre pastilles du profil
    /// ouvrent le coffre « au bon item ») — 0 par défaut, la poignée des
    /// quatre appelants existants ne bouge pas d'un caractère.
    var pageInitiale: Int = 0

    /// ⚠️⚠️ **LA REQUÊTE N'EST PLUS LA VÉRITÉ, ELLE EST LE REPLI.** Elle vit
    /// toujours ICI et pas chez les quatre appelants (« la refonte remplace ce
    /// qu'il y a DERRIÈRE, jamais la poignée » — la signature de
    /// `CoffreFortFlow` ne bouge toujours pas d'un caractère). Mais depuis le
    /// branchement, elle ne sert qu'à `EconomieWoop` : sans compte connecté,
    /// c'est elle qui parle ; dès que le serveur a répondu, elle se tait.
    @Query(sort: \Workout.startedAt, order: .reverse) private var seances: [Workout]

    /// ⚠️ CALCULÉE, jamais stockée : une propriété stockée `private` rend le
    /// constructeur mémberwise privé, et cette struct a quatre appelants hors
    /// fichier. « La signature de `CoffreFortFlow` ne bouge pas d'un
    /// caractère » — pas même par accident.
    private var economie: EconomieWoop { EconomieWoop.shared }

    /// LA MAQUETTE — ce que l'app sait dire sans serveur.
    ///
    /// ⚠️ **ELLE NE PEUT PAS MONTRER UN BOOSTER, ET C'EST STRUCTUREL** :
    /// `robe: nil` en dur, parce qu'une séance ne sait pas quels sachets elle
    /// a valus. C'est ce qui rendait la demande du 29-08 (« les gains booster
    /// issus du chemin doivent apparaître ») impossible à satisfaire ici —
    /// alors que `historique_gains()` les rend tous depuis le 28.
    private var maquette: [GainCoffre] {
        seances.filter { !$0.isActive }.compactMap { w in
            let series = w.seriesPayantes
            guard series > 0 else { return nil }
            return GainCoffre(
                id: w.remoteID,
                date: w.endedAt ?? w.startedAt,
                montant: series * CoffreFortPurse.perSeries,
                robe: nil,
                titre: series == 1 ? "1 série" : "\(series) séries")
        }
    }

    /// `-coffreV1` rejoue l'ANCIENNE page (le film du coffre, la pastille) —
    /// elle reste montable, c'est la règle de l'archive.
    private static let v1 = CommandLine.arguments.contains("-coffreV1")

    var body: some View {
        // ⚠️ **L'ENVELOPPE EST MINCE, ET SA SIGNATURE N'A PAS BOUGÉ.** Quatre
        // pages ouvrent cette porte (`HomeNuit`, `HomeAuroraView`,
        // `ProfilLune`, `WoopApp`) : la refonte remplace ce qu'il y a
        // DERRIÈRE, jamais la poignée.
        //
        // ⚠️ **LE PAGER VERTICAL EST MORT** (verdict Kathryn, 25-08 : « la
        // page démon aussi, plus besoin là »). Et c'était le prérequis de la
        // v2 : son drag vertical est désormais pris par la levée de card et
        // la lune — les deux ne pouvaient pas coexister sur le même geste.
        // `HaloDawnLab` n'est pas supprimée pour autant, elle n'est
        // simplement plus atteignable d'ici (son banc la monte toujours).
        Group {
            if Self.v1 {
                ancienne
            } else {
                // ⚠️ **LES DEUX NOMBRES VIENNENT DE LA MÊME SOURCE, ET C'EST
                // TOUT L'OBJET DU CHANTIER.** Avant, l'en-tête recevait
                // `coins` calculé par l'appelant et les lignes étaient
                // reconstruites ici : l'en-tête pouvait donc cesser d'être la
                // somme de ses lignes. Désormais `EconomieWoop` sert les deux,
                // et sa maquette est celle-ci.
                CoffreV2Page(coins: economie.or,
                             gains: economie.journal,
                             onClose: onClose,
                             pageInitiale: pageInitiale)
            }
        }
        // ⚠️ **LE REPLI EST POSÉ AVANT LA PREMIÈRE IMAGE**, jamais après :
        // `onAppear` court avant l'affichage, `task` non. Sans ça la page
        // s'ouvre sur 0 et la roulette de `contentTransition(.numericText())`
        // fait défiler le solde depuis zéro à chaque ouverture du coffre.
        .onAppear { economie.poserMaquette(or: coins, journal: maquette) }
        // 18-09 : le coffre est TOUJOURS un cover — sous lui, la Home (ou le
        // Profil) dormait pour les stories, pas pour lui (suspect n° 2 de
        // l'analyse chauffe du coffre). Ici et pas chez les appelants : la
        // poignée ne bouge pas, et les quatre portes sont couvertes d'un coup.
        .couvreLaHome()
        // Et le journal complet ne se demande QUE si on ouvre la page qui
        // l'affiche — 60 lignes ne servent nulle part ailleurs.
        .task { await economie.rafraichir(avecJournal: true) }
    }

    private var ancienne: some View {
        // LE PROXY EST DEHORS, et lui ne fuit pas la zone sûre : c'est la
        // seule façon de connaître l'encoche pour poser le chevron à sa
        // place, alors que la page, elle, doit toucher les bords.
        GeometryReader { g in
            let safeTop = g.safeAreaInsets.top
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    CoffreFortView(coins: coins, safeTop: safeTop,
                                   onClose: onClose)
                        .containerRelativeFrame(.vertical)
                    HaloDawnLab()
                        .containerRelativeFrame(.vertical)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .background(Color.black)
            // SEUL LE DÉFILEMENT FUIT LA ZONE SÛRE — pas le proxy. Un
            // `ignoresSafeArea` posé sur le GeometryReader lui fait rendre
            // une encoche de ZÉRO (payé une capture : le chevron restait
            // collé au bord physique alors que le calcul était juste).
            .ignoresSafeArea()
        }
        .background(Color.black.ignoresSafeArea())
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - La pastille du trésor

/// LA PASTILLE DE BRAVO, POSÉE SOUS LA PIÈCE. Le composant est le même
/// (`BravoPillView` + `bravoPill.metal`) : capsule de nuit, fil d'or de
/// 0,7 pt, la pièce en anthracite mat et le compte. Ici la caméra vaut 1 et
/// le jaillissement n'existe pas — il ne reste que la respiration du néon,
/// et LA RÉPONSE AU TOUCHER, qu'on garde telle quelle : le souffle court
/// (la même enveloppe que le jaillissement de BRAVO, en plus bref), la
/// fumée sombre, le tintement de pièce et la vibration souple.
///
/// LE TOUCHER EST BORNÉ À LA PASTILLE. Sur BRAVO elle accroche son tap sur
/// tout l'écran (elle y est le dernier enfant du ZStack, rien ne la
/// dispute) ; ici, la vidéo écoute déjà le sien et le parcours attend son
/// glissement — le geste ne peut donc vivre que dans son propre cadre.
private struct TresorPastille: View {
    let count: Int

    @State private var tapAt: Date?
    @State private var tapEnd: Date?
    @State private var tapTick = 0

    private static let height: CGFloat = 54
    /// Le débord : le bloom du fil d'or et la fumée du toucher sortent de la
    /// capsule — l'hôte du shader doit leur laisser de la place.
    private static let pad: CGFloat = 30

    var body: some View {
        let w = Self.height * BravoPillView.ratio
        let hostW = w + Self.pad * 2
        let hostH = Self.height + Self.pad * 2
        let c = CGPoint(x: hostW / 2, y: hostH / 2)
        // L'horloge ne tourne QUE pendant la réponse au toucher : au repos
        // la pastille a déjà la sienne, à 12 Hz, dans son propre corps.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: tapAt == nil)) { tl in
            BravoPillView(center: c,
                          height: Self.height,
                          amount: 1,
                          count: count,
                          cam: 1,
                          neonBoost: 0,
                          flare: tapFlare(tl.date),
                          pulse: 0)
                .overlay {
                    if let tapAt {
                        CoinSmoke(center: c,
                                  radius: Self.height * 0.34,
                                  start: tapAt, end: tapEnd, palette: .dark)
                            .allowsHitTesting(false)
                    }
                }
        }
        .frame(width: hostW, height: hostH)
        .contentShape(Rectangle())
        .onTapGesture(perform: fireTap)
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.7),
                         trigger: tapTick)
        .accessibilityElement()
        .accessibilityLabel("\(count) pièces")
    }

    /// Le souffle du toucher — l'enveloppe de BRAVO, à l'identique.
    private func tapFlare(_ now: Date) -> Double {
        guard let tapAt else { return 0 }
        let x = now.timeIntervalSince(tapAt)
        guard x > 0 else { return 0 }
        return min(x / 0.07, 1) * exp(-max(x - 0.07, 0) / 0.34) * 0.72
    }

    /// Un tintement MINIMAL et une fumée qui se démonte une fois éteinte —
    /// une bouffée n'est pas un état, et un TimelineView qui reste monté
    /// coûte ses images pour rien.
    private func fireTap() {
        tapAt = .now
        tapEnd = nil
        tapTick += 1
        CoinChime.shared.chink()
        let mark = Date.now.addingTimeInterval(0.16)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { tapEnd = mark }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            if tapEnd == mark { tapAt = nil; tapEnd = nil }
        }
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
