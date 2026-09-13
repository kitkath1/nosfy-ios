import AVFoundation
import SwiftUI
import UIKit

// MARK: - LA PORTE — l'entrée dans l'app
//
// Jalon 1 du plan `tools/porte/PLAN-PORTE.md` : LA COQUILLE. Quatre pages de
// texte qui défilent, un grand header vidéo, les dots, la flamme du pied, et le
// bouton collé en bas. Le croisé des quatre vidéos est le jalon 2, le film
// d'arrivée le jalon 3 — ici le header montre la boucle de la page 1, fixe.
//
// LOI 1 DU PLAN — **LA VIDÉO NE BOUGE JAMAIS.** Le header est cadré, dès sa
// première image, dans le rectangle définitif. Il ne grandit pas, ne rétrécit
// pas, ne se recadre pas : c'est la PAGE qui s'habille autour de lui. Conséquence
// technique, et c'est tout l'intérêt : aucune frame d'`AVPlayerLayer` animée,
// donc aucun relayout par image — la cause mesurée du « ça laggue quand on drag
// la card » n'existe pas ici.
//
// LOI 2 — **LE ZOOM EST CUIT, PAS CALCULÉ.** Le mouvement de caméra vit dans le
// fichier (`tools/porte/recuit_porte.sh`). Un `scaleEffect` posé après un masque
// composerait dans un tampon non zoomé puis l'agrandirait : zoom rastérisé, donc
// flou. Il n'y a donc pas une seule transformation d'échelle dans ce fichier.

// MARK: - Les cotes
//
// Toutes relatives, sauf celles qui sont des cotes de COMPOSANT (la hauteur du
// bouton, le fondu de pied). L'écran de référence du plan fait 402 × 874 ; les
// valeurs entre parenthèses sont ce que ces fractions y donnent.
enum PorteMesures {
    /// Le header prend 70 % de la hauteur PHYSIQUE (612 pt sur 874) — la cote
    /// mesurée sur les maquettes, où la vidéo meurt à 70 / 70 / 72 %.
    static let partHeader: CGFloat = 0.70
    /// La marge latérale de tout le contenu — le patron de l'écran de connexion.
    static let margeCote: CGFloat = 26
    /// Le fondu de pied du header : la vidéo meurt dans le noir avant la flamme,
    /// sinon les deux plans se touchent par une arête franche.
    static let fonduPied: CGFloat = 40
    /// Le texte est ancré au BAS de sa zone, à cette distance de son arête.
    static let texteSurArete: CGFloat = 26
    /// LA DESCENTE DU TEXTE sous l'arête du header (V3, verdict 23-08 :
    /// « plus rapprochés du bouton ») — il vit dans la nuit de la flamme, où
    /// il est plus lisible qu'en travers du verre, et l'œil ne fait plus
    /// qu'un saut jusqu'au bouton.
    ///
    /// ⚠️ **ELLE S'OBTIENT EN AGRANDISSANT LE SCROLL, JAMAIS PAR UN PADDING
    /// NÉGATIF.** Payé : un `padding(.bottom, -54)` faisait bien descendre le
    /// bloc, mais **un `ScrollView` CLIPPE son contenu à son cadre** — le
    /// texte sortait dessous et se faisait TRANCHER en deux (verdict : « c'est
    /// cassé, regarde tous les textes »). Le scroll mesure donc
    /// `hHeader + descenteTexte`, et le bloc reste bottom-ancré DEDANS.
    static let descenteTexte: CGFloat = 54
    /// ⚠️ LA ZONE DE TEXTE EST UN GABARIT FIXE (V2, verdict « pas même
    /// hauteur ») : kicker + **2 lignes**, TOP-alignés dedans — la première
    /// ligne de chaque page tombe au même y, au pixel.
    /// 25 (kicker + son pied) + 2 × 33 (inter 27 semibold) + 1 × 4.
    /// ⚠️ DEUX LIGNES EST UNE LOI D'ÉCRITURE, pas une contrainte de place
    /// (verdict 23-08 : « tous sur deux lignes max ») : une page 3 qui
    /// débordait a été RÉÉCRITE, jamais rétrécie.
    static let zoneTexte: CGFloat = 95
    /// Les dots, sous le bloc de texte (qui descend déjà de `descenteTexte`).
    static let dotsSousArete: CGFloat = 18
    /// Le ratio natif de `home-fond-flamme.mp4` (604 × 642). Il est tenu au
    /// pixel : ratio exact = rien n'est rogné par `resizeAspectFill`.
    static let ratioFlamme: CGFloat = 604.0 / 642.0
    /// ⚠️ **LE CURSEUR À RÉGLER AU TÉLÉPHONE (jalon 1).** De combien la flamme
    /// descend sous le bord physique. Là où elle vit aujourd'hui (la home v2)
    /// elle est collée au bord, sans offset : la seule façon de la faire
    /// descendre est d'en sortir une partie de l'écran. Départ 56, plage 0…96.
    static let flammeBas: CGFloat = 56
    /// La hauteur du primaire de la maison (`DiamondPrimaryButton`).
    static let hauteurBouton: CGFloat = 58
    /// Le pied : au-dessus de l'encart bas, jamais collé à lui.
    static let piedBouton: CGFloat = 22
}

// MARK: - Le curseur du carrousel
//
// ⚠️ **`@Observable`, ET SURTOUT PAS UN `@State` SUR LA PAGE.** Un état écrit
// soixante fois par seconde sur la vue qui contient tout, c'est exactement « ça
// saccade, ça colle au doigt » (les quatre remèdes de `ExercisesView`). Ici, le
// corps de la porte N'EN LIT RIEN : seuls `PorteDots` — et, au jalon 2, le
// header — le lisent, donc seuls eux se réévaluent.
@Observable final class EtatPorte {
    /// La position continue dans le carrousel, de 0 à 3.
    var p: Double
    /// L'arrivée est derrière nous : la page 0 reprend sa boucle ordinaire.
    /// Posé quand le créneau pair quitte la page 0 (le film est alors DÉMONTÉ —
    /// le remplacer à ce moment-là ne peut pas se voir), ou au saut d'un tap.
    var arriveeFinie = false

    // MARK: La caresse (V2)
    /// Les derniers points du doigt, horodatés — le protocole du login.
    /// ⚠️ La PAGE ne lit jamais ce tableau : seule la couche de caresse le
    /// consomme, et elle seule se réévalue pendant le geste.
    var traces: [TouchTrace] = []
    /// Le drapeau que la page lit, lui : il ne bascule que deux fois par
    /// caresse (naissance, mort) — le sous-arbre du shader est ABSENT au
    /// repos (la loi MenuNappe : une passe plein écran qui peint du vide).
    var caresseVivante = false

    // MARK: La parallaxe au doigt (V2)
    /// La poussée du doigt sur la vidéo du header, en points (±10). Le gyro
    /// s'y ajoute côté header. Ressort de retour au lâcher.
    var parallaxeDoigt: CGSize = .zero

    // MARK: Le manège (V2)
    /// Le manège 3D est NÉ : monté au premier passage de p au-delà de 2,05,
    /// il ne se démonte plus — chaque `BoosterScene.init` recharge bin +
    /// 7 PNG sans cache et recompile ses pipelines, on ne paie qu'une fois.
    /// `paused` fait le reste.
    var manegeNe = false
    /// La première pose est passée : les suivantes rejouent la cinématique.
    var manegeDejaPose = false
    /// LES TROIS DÉCORS LOURDS NAISSENT SUR TROIS PAGES POSÉES DIFFÉRENTES.
    /// Même doctrine pour les trois : on paie la compilation de leurs
    /// pipelines sur une page IMMOBILE (on est en train de lire), jamais sous
    /// le doigt — et on ne les démonte plus.
    /// ⚠️ ET ON LES ÉCHELONNE : nés au même instant, les deux verres de la
    /// page 3 et le manège cumulaient un trou de **1,42 s** mesuré. Un décor,
    /// une pose.
    ///   · la carte « Sets »  → pose sur la page 1
    ///   · les deux widgets   → pose sur la page 2
    ///   · le manège 3D       → pose sur la page 3
    var sertiNe = false
    var widgetsNes = false

    init(p: Double = 0) { self.p = p }
}

/// ⚠️ **UNE SEULE SONDE PAR SCROLL, SUR UN TYPE COMPOSÉ.** Un
/// `onScrollGeometryChange` dont la closure renvoie une valeur qui ne change pas
/// n'est PLUS JAMAIS rappelé, et deux sondes sur le même ScrollView se volent
/// les rappels. Le champ vivant (`x`) emporte donc le stable (`largeur`) dans le
/// même `Equatable` — la loi payée cinq fois dans le dépôt.
private struct SondePorte: Equatable {
    var x: CGFloat
    var largeur: CGFloat
}

// MARK: - Le contenu des quatre pages

struct PortePage: Identifiable {
    let id: Int
    /// Le sur-titre, page 1 seulement.
    let kicker: String?
    /// Les lignes, écrites à la main : le retour à la ligne est une décision de
    /// composition, jamais le hasard d'une largeur.
    let lignes: [String]
    /// Le fichier de la boucle du header (jalon 2).
    let video: String
}

extension PorteEntree {
    /// L'encre du texte du carrousel : un fondu VERTICAL et court. Voir le
    /// commentaire de `blocTexte` — le fondu diagonal de la maison est fait pour
    /// un titre d'affiche, pas pour deux lignes qu'on lit.
    static let encreTexte = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.96), location: 0.0),
            .init(color: .white.opacity(0.80), location: 1.0)
        ],
        startPoint: .top, endPoint: .bottom
    )

    /// ⚠️ `static let` et non une valeur par défaut de `@State` : une expression
    /// par défaut est évaluée à CHAQUE init de la vue.
    /// ⚠️ UN KICKER SUR LES QUATRE PAGES (V2) : c'est lui qui garantit que la
    /// première ligne tombe au même y partout — et les retours à la ligne sont
    /// ÉCRITS, jamais le hasard d'une largeur.
    static let pages: [PortePage] = [
        PortePage(id: 0, kicker: "WELCOME",
                  lignes: ["Welcome to Woop.", "Training, remembered."],
                  video: "onb-lune-loop"),
        PortePage(id: 1, kicker: "EXERCISES",
                  lignes: ["Pick your exercises,", "log every set as you go."],
                  video: "onb-exos-loop"),
        PortePage(id: 2, kicker: "PROGRESS",
                  lignes: ["Track your performance",
                           "and become your best."],
                  video: "onb-track-loop"),
        PortePage(id: 3, kicker: "BOOSTERS",
                  lignes: ["Finish a session,", "open a booster."],
                  video: "booster-loop"),
    ]
}

// MARK: - La porte

struct PorteEntree: View {
    /// Le même contrat que l'écran de connexion qu'elle remplace : c'est
    /// l'appelant qui décide quoi faire de l'identité.
    var onConnect: (String) -> Void = { _ in }

    // MARK: - LA PORTE APPLE (06-09)

    /// Le verdict de la connexion Apple, remonté à la racine : nouvelle → le
    /// film de Nosfy ; connue → l'app. `onConnect` reste appelé juste avant,
    /// pour que la cérémonie de sortie parte comme avant.
    var onVerdict: (AppleAuth.Verdict) -> Void = { _ in }

    @State private var connexionEnCours = false
    @State private var pannePorte: String?

    /// LE BANC `-porteAppleAuto` : la feuille Apple ne se tape pas en ligne de
    /// commande. Il l'ouvre tout seul, une fois la porte habillée.
    private static let appleAuto = CommandLine.arguments.contains("-porteAppleAuto")

    /// La VRAIE feuille Apple (`ASAuthorizationController`) — voir
    /// `Services/AppleAuth.swift`. La cérémonie de sortie ne part QU'APRÈS le
    /// verdict : ouvrir le portail avant de savoir qui entre, c'était le défaut
    /// de l'ancienne porte (elle laissait passer sans condition).
    private func entrerParApple() {
        guard !connexionEnCours else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            connexionEnCours = true
            pannePorte = nil
        }
        Task { @MainActor in
            do {
                let verdict = try await AppleAuth.entrer()
                connexionEnCours = false
                // L'AIGUILLAGE (13-09) : une CONNUE part par la cérémonie de
                // sortie (le portail, la flamme) vers la home — comme avant.
                // Une NOUVELLE ne passe PAS par là : la racine ouvre le film de
                // Nosfy par-dessus la porte, et c'est l'île qui s'allume.
                if !verdict.estNouvelle {
                    if Self.porteSortie && cineLocal == nil { cineLocal = .now }
                    onConnect("")
                }
                onVerdict(verdict)
            } catch let panne as AppleAuth.Panne {
                connexionEnCours = false
                guard panne != .annulee else { return }   // elle a fermé la feuille : rien à dire
                withAnimation(.easeOut(duration: 0.25)) {
                    pannePorte = panne.errorDescription
                }
            } catch {
                connexionEnCours = false
                withAnimation(.easeOut(duration: 0.25)) {
                    pannePorte = error.localizedDescription
                }
            }
        }
    }
    /// Posé par la racine quand le bouton est touché (la cérémonie de sortie,
    /// jalon 5).
    var cineStart: Date? = nil
    /// Le FILM D'ARRIVÉE joue : la page naît nue (flamme éteinte, texte, dots
    /// et bouton absents), le film se déroule dans le header, puis tout se pose
    /// en cascade. La racine le passera selon `woop.porteVue` (jalon 6) ; le
    /// banc l'allume par `-porteArrivee`.
    var arrivee: Bool = PorteEntree.porteArrivee

    /// La partition de l'arrivée, en secondes depuis l'apparition : le
    /// fichier **V4** fait **164** images à 30 img/s — fenêtre 1,20 → 8,042 s
    /// de la source, jouée à **×0,80** (donc plus VITE que tournée), et un
    /// serrage **1,60 → 1,00** en rampe amortie, CUIT par-dessus.
    ///
    /// ⚠️ **LE RALENTI EST MORT, ET IL ÉTAIT LA MOITIÉ DU « ÇA LAGUE »**
    /// (verdict 26-08 : « la vidéo lague, elle est trop lente… l'arrivée
    /// n'est pas assez rapide et majestueuse, plus Zoom »). En V3, 164 images
    /// source étaient étirées sur 274 par `minterpolate=blend` : **40 % du
    /// film n'étaient pas des images** mais des fondus croisés — une image
    /// double sur chaque mouvement de caméra. À ×0,80, 24 img/s tombe
    /// EXACTEMENT sur 30 : une image de sortie par image source, aucune
    /// fabriquée. Le détail et les mesures sont dans `recuit_porte.sh`.
    ///
    /// ⚠️ La constante suit le FICHIER (`ffprobe -count_frames`), jamais le
    /// calcul de durée — et le recuit VÉRIFIE désormais l'accord, parce que
    /// la V3 se dédisait justement là-dessus (le script disait 9,236 s pour
    /// un fichier de 9,133 : le zoom se figeait 6,4 % trop serré, donc à
    /// côté de la maquette d'arrivée que la page habille).
    /// ⚠️ Plus `private` : le four du manège la LIT pour ne plus se caler
    /// sur une horloge murale (WoopApp) — une durée écrite deux fois
    /// finit toujours par se dédire, et celle-ci s'était déjà dédite.
    static let arriveeT: Double = 164.0 / 30.0            // 5,467
    /// La flamme s'allume à T − 1,2 (rampe de 0,8 s), l'habillage à T.
    private static let flammeA: Double = arriveeT - 1.2

    /// La flamme est allumée (toujours vrai hors arrivée).
    @State private var flammeAllumee = false
    /// L'habillage est posé : texte, dots, bouton — et le scroll s'ouvre.
    @State private var habille = false
    /// Le banc de la sortie : `-porteSortie` fait jouer la cérémonie au tap du
    /// bouton, sans racine. En production c'est la RACINE qui pousse
    /// `cineStart` — jamais deux écrivains sur la même horloge.
    private static let porteSortie =
        CommandLine.arguments.contains("-porteSortie")
    @State private var cineLocal: Date?
    /// L'horloge de sortie effective, d'où qu'elle vienne.
    private var sortie: Date? { cineStart ?? cineLocal }

    /// L'état naît sur la page du banc : posé en `onAppear`, le premier rendu
    /// montrait la page 0 puis sautait — un flash de mauvaise vidéo.
    @State private var etat = EtatPorte(p: Double(PorteEntree.pageFigee ?? 0))

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    /// L'horloge de la caresse (le patron du login, à la lettre).
    @State private var lastSample = Date.distantPast
    @State private var lastHaptic = Date.distantPast
    @State private var hapticTick = 0
    /// La position pilotée du banc `-porteAuto` — montée SEULEMENT dans ce
    /// mode. ⚠️ `scrollPosition` est un binding à DOUBLE SENS : tenu par la
    /// page en régime normal, SwiftUI y écrirait au poser et au lâcher du
    /// doigt et invaliderait tout le corps au pire instant (la loi
    /// d'ExercisesView). Au banc, personne ne glisse : il n'y a qu'un écrivain.
    @State private var positionAuto = ScrollPosition()

    // MARK: Les affordances de banc
    //
    // ⚠️ Elles passent par le domaine d'arguments de `NSUserDefaults`
    // (`-portePage 2`), comme `-openTab` et `-moonSplashFreeze`, et NON par
    // `CommandLine.arguments` — c'est la forme maison pour un drapeau qui porte
    // une valeur.

    /// `-portePage <n>` : n'affiche QUE la page n, sans scroll. Une capture par
    /// page sans avoir à simuler un glissement (le simulateur ne sait pas
    /// glisser en ligne de commande).
    private static let pageFigee: Int? = {
        UserDefaults.standard.string(forKey: "portePage").flatMap(Int.init)
            .map { min(max($0, 0), pages.count - 1) }
    }()

    /// `-porteFlamme <v>` : la descente de la flamme, pour balayer la plage
    /// 0…96 en captures au lieu de la juger à l'œil.
    private static let flammeBasBanc: CGFloat = {
        UserDefaults.standard.string(forKey: "porteFlamme")
            .flatMap(Double.init).map { CGFloat($0) } ?? PorteMesures.flammeBas
    }()

    /// `-porteAuto` : le carrousel se balaie tout seul, page par page — le
    /// film du croisé se tourne sans doigt (le simulateur ne sait pas glisser
    /// en ligne de commande). Il passe par le VRAI scroll (`scrollTo` animé),
    /// donc la sonde, les dots et le croisé jouent la mécanique de production.
    private static let porteAuto = CommandLine.arguments.contains("-porteAuto")

    /// `-porteArrivee` : joue le film d'arrivée au banc.
    fileprivate static let porteArrivee =
        CommandLine.arguments.contains("-porteArrivee")

    /// `-porteSans <n>` : éteint les décors pour bissecter la cadence.
    /// 1 = sans la carte Sets, 2 = sans les widgets, 4 = sans le manège,
    /// 8 = sans les vidéos du header (diagnostic : sépare le coût d'un verre
    /// de celui de la CAPTURE du composite vidéo qu'il force).
    /// Cumulables : 7 = la porte nue.
    fileprivate static let sans: Int =
        UserDefaults.standard.string(forKey: "porteSans").flatMap(Int.init) ?? 0

    /// `-porteTrail` : sème une caresse FIGÉE en travers de la page — la
    /// traîne se capture sans doigt (l'école exacte de `-loginTrail`).
    fileprivate static let porteTrail =
        CommandLine.arguments.contains("-porteTrail")

    var body: some View {
        // ⚠️ **LE `GeometryReader` RESPECTE LA SAFE AREA, C'EST SON CONTENU QUI
        // L'IGNORE.** Posé l'inverse, il rend des insets NULS et toutes les
        // cotes du pied glissent (piège payé sur la page exos et le calendrier).
        GeometryReader { geo in
            let encartHaut = geo.safeAreaInsets.top
            let encartBas = geo.safeAreaInsets.bottom
            let W = geo.size.width
            // La hauteur PHYSIQUE de l'écran : c'est d'elle que les 70 % du
            // header sont pris, pas de la hauteur sûre.
            let H = geo.size.height + encartHaut + encartBas
            let hHeader = (H * PorteMesures.partHeader).rounded()

            ZStack(alignment: .top) {
                Color.black

                // ① LA FLAMME — clouée par son arête basse au bord physique,
                // puis poussée de `flammeBas` vers le bas. Elle est le calque du
                // dessous : aucun blend, aucun masque, opacité 1 (la loi du pied
                // de la home). Le header, opaque, lui coupera le haut.
                // ⚠️ **ELLE EST DÉMONTÉE, PLUS SEULEMENT TRANSPARENTE**
                // (26-08). C'est la loi déjà écrite sur les créneaux du header
                // — « un `AVPlayerLayer` à opacité nulle décode quand même » —
                // que ce calque-ci n'avait jamais reçue : pendant les neuf
                // secondes du film, un SECOND lecteur tournait derrière lui
                // pour ne rien montrer.
                //
                // Le montage tombe donc à T − 1,2 s, dans la seconde CALME du
                // film (la caméra est posée), et la pose intégrée de
                // `CalqueVideo` tient l'image jusqu'à `isReadyForDisplay` : le
                // fondu de 0,8 s ne voit jamais un trou. Hors arrivée,
                // `flammeAllumee` est vrai dès l'`onAppear` — rien ne change.
                if flammeAllumee {
                    PorteFlamme(largeur: W)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .offset(y: Self.flammeBasBanc)
                        .transition(.opacity)
                }

                // ② LE HEADER — la vidéo, plein bord, sous l'encoche, pilotée
                // par `p` : le croisé pair/impair du § 4.3 du plan. En mode
                // arrivée, le créneau pair de la page 0 porte le FILM.
                PorteHeader(etat: etat, arrivee: arrivee,
                            largeur: W, hauteur: hHeader)

                // ③ LE CONTENU — les textes qui défilent, les dots, le bouton.
                contenu(W: W, H: H, hHeader: hHeader, encartBas: encartBas)

                // ④ LA SORTIE — LE PORTAIL DE LA LUNE (26-08).
                //
                // ⚠️ **LE RIDEAU NOIR EST MORT.** Verdict de Kathryn : « une
                // grosse bande noire descend, ça lag, on dirait deux écrans
                // superposés — supprime complètement cet effet ». C'était
                // exactement ça : un `Rectangle().fill(.black)` ancré au bord
                // HAUT dont la hauteur croissait de 0 à 70 % de l'écran en
                // 1,45 s. Une bande noire qui descend n'est pas une
                // transition, c'est un store qu'on baisse.
                //
                // À la place, ce que le verdict demande : « la lune devient le
                // point de transition — zoom vers la lune, accélération très
                // douce, elle prend tout l'écran, blur, lumière, profondeur,
                // puis la caméra traverse la lune et la Home se révèle
                // derrière ». Le foyer de la flamme, lui, RESTE : c'est la
                // chaleur qui monte du pied, elle n'a jamais été le problème.
                if let sortie {
                    PortailLune(start: sortie, largeur: W, hauteur: H)
                }
            }
            .frame(width: W, height: H)
            .ignoresSafeArea()
            .environment(\.encartBas, encartBas)
            // LE TAP QUI SAUTE : pendant le film, un toucher pose tout, tout de
            // suite — la loi du splash (« un tap termine à tout instant »).
            // Après l'habillage, le geste ne fait plus rien et ne vole rien :
            // un tap d'ancêtre n'affame pas un Button enfant.
            .onTapGesture { if !habille { sauter() } }
            // LA CARESSE + LA PARALLAXE AU DOIGT (V2) — un geste SIMULTANÉ :
            // il dessine et pousse sans jamais voler le scroll (l'école
            // StoryFlow). La lumière suit le doigt qui feuillette.
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { v in
                        // ⚠️ ET ON N'ÉCHANTILLONNE MÊME PAS près du manège :
                        // sans cette garde, le doigt qui tourne l'anneau
                        // remplirait le tampon de traces pour rien, et la
                        // traîne réapparaîtrait d'un coup au retour vers la
                        // page 3. Le geste de rotation appartient au manège,
                        // entièrement.
                        if etat.p < 2.4 { caresse(en: v.location) }
                        // La poussée : bornée, molle — le gyro fait le reste.
                        if habille && !reduceMotion {
                            etat.parallaxeDoigt = CGSize(
                                width: max(-10, min(10, v.translation.width / 14)),
                                height: max(-8, min(8, v.translation.height / 18)))
                        }
                    }
                    .onEnded { _ in
                        // Le ressort de retour — l'école AuroraBgLab.
                        withAnimation(.spring(response: 0.55,
                                              dampingFraction: 0.55)) {
                            etat.parallaxeDoigt = .zero
                        }
                    }
            )
            // LA COUCHE DE LUMIÈRE — au-dessus de tout, jamais touchable, et
            // ABSENTE au repos : elle ne coûte pas un pixel sans doigt.
            .overlay {
                // ⚠️ PAS DE CARESSE SUR LA PAGE DU MANÈGE (verdict 23-08 :
                // « tu enlèves la couleur qui suit le doigt, on doit pouvoir
                // faire tourner le manège »). Deux raisons, et la seconde
                // suffirait : la traîne SALIT une scène 3D qui a sa propre
                // lumière, et surtout elle dit au doigt qu'il dessine alors
                // qu'ici il TOURNE — deux gestes contradictoires sur le même
                // pixel. Le seuil 2,4 éteint la traîne avant l'arrivée, pas à
                // la pose : elle ne doit pas mourir SOUS le doigt.
                if (etat.caresseVivante || Self.porteTrail) && etat.p < 2.4 {
                    PorteCaresseCouche(etat: etat, bench: Self.porteTrail)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.55),
                         trigger: hapticTick)
        // La sonde de cadence de la maison : `-fps` l'allume, elle ne dessine
        // rien. Deux lecteurs vidéo + le shader du bouton tournent ici — le
        // « ça lag » se juge à cette sonde, jamais à l'œil.
        .sondeCadence("porte")
        .onChange(of: sortie) { _, nv in
            guard nv != nil else { return }
            // L'habillage s'en va à 1,45 s — le reveal joue à l'envers (le
            // même ressort, la même chute de 26 pt). Un seul withAnimation,
            // dans un tour à lui : le piège du double withAnimation ne peut
            // pas mordre ici.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.45) {
                withAnimation(.easeIn(duration: 0.5)) { habille = false }
            }
        }
        // LE GYROSCOPE DE LA PARALLAXE : SkyMotion ne démarre pas tout seul
        // (le bug payé du 19-08 : « la parallaxe lisait des zéros sur
        // téléphone ») et le système coupe ses updates en arrière-plan — on le
        // relance sur le retour. ⚠️ JAMAIS de stop() ici : SkyMotion n'a pas
        // de refcount, un stop couperait le poignet de toute l'app.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                SkyMotion.shared.start(reduceMotion: reduceMotion)
            }
        }
        .onAppear {
            SkyMotion.shared.start(reduceMotion: reduceMotion)
            // Le banc de la sortie se déclenche SEUL à +3 s (le bouton ne se
            // tape pas en ligne de commande — l'école de `-clotureTest`). Au
            // doigt, le bouton reste le déclencheur, et le premier gagne.
            if Self.porteSortie {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if cineLocal == nil { cineLocal = .now }
                }
            }
            if arrivee && reduceMotion {
                // La convention de la maison : reduceMotion court-circuite les
                // cérémonies (le splash saute à sa fin, la connexion se réduit
                // à un fondu). Le film d'arrivée aussi : la porte naît posée.
                sauter()
            } else if arrivee {
                // L'HORLOGE DE L'ARRIVÉE — deux rendez-vous, posés d'un bloc
                // (l'école de `startConnexionCinematic`). Les deux écritures
                // sont idempotentes : si le tap est passé avant, elles ne
                // changent rien.
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.flammeA) {
                    withAnimation(.easeOut(duration: 0.8)) {
                        flammeAllumee = true
                    }
                }
                // ⚠️ **1,1 s AVANT LA FIN DU FILM.** Attendre `arriveeT` pour
                // commencer, c'était faire se succéder deux choses au lieu de
                // les fondre : le film finissait, PUIS la page s'habillait. La
                // dernière seconde du film est calme (la caméra est posée) —
                // c'est exactement là que l'habillage doit naître pour qu'on
                // ne voie aucune couture.
                DispatchQueue.main.asyncAfter(
                    deadline: .now() + Self.arriveeT - 1.1) {
                    habille = true
                    // Le film a été vu en entier : les prochains lancements
                    // ouvrent la porte directement (en RELEASE — en debug la
                    // clé n'est jamais lue, le remède `tutoExosVu`).
                    UserDefaults.standard.set(true, forKey: "woop.porteVue")
                }
            } else {
                flammeAllumee = true
                habille = true
            }
        }
        // Le raccord avec le splash et la home : les trois modificateurs que
        // `MoonSplashView` et `AuroraLoginView` posent tous les deux. Les
        // oublier ferait APPARAÎTRE puis disparaître la barre d'état au raccord.
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        // ⚠️ PAS DE SECONDE `sondeCadence` ICI : elle vivait en double dans ce
        // même `body` (deux `CADisplayLink` sur le fil principal, et le
        // journal imprimait chaque mesure deux fois). Celle du haut suffit.
        .preferredColorScheme(.dark)
    }

    /// L'échantillonnage de la caresse — les cadences du login, à la lettre :
    /// un point tous les ~28 ms, vie 1,4 s, cap 10 points, un souffle au début
    /// de chaque caresse, un tic haptique doux tous les ~90 ms.
    private func caresse(en p: CGPoint) {
        let now = Date()
        if now.timeIntervalSince(lastSample) > 0.5 {
            SparkleChime.shared.breath()
        }
        if now.timeIntervalSince(lastSample) > 0.028 {
            lastSample = now
            etat.traces.append(TouchTrace(point: p, born: now))
            etat.traces.removeAll { now.timeIntervalSince($0.born) > 1.4 }
            if etat.traces.count > 10 {
                etat.traces.removeFirst(etat.traces.count - 10)
            }
            if !etat.caresseVivante { etat.caresseVivante = true }
            // La mort de la couche : 1,6 s après le DERNIER point, si rien
            // n'est venu depuis — le sous-arbre redevient absent.
            let repere = now
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                if lastSample == repere {
                    etat.traces.removeAll()
                    etat.caresseVivante = false
                }
            }
        }
        if now.timeIntervalSince(lastHaptic) > 0.09 {
            lastHaptic = now
            hapticTick += 1
        }
    }

    /// Le saut du tap : le film cède la place à l'état final, d'un coup. La
    /// coupe est sèche — c'est le doigt qui l'a demandée.
    private func sauter() {
        etat.arriveeFinie = true
        withAnimation(.easeOut(duration: 0.4)) {
            flammeAllumee = true
            habille = true
        }
        // Sauté ou vu en entier, le film est derrière : même clé.
        UserDefaults.standard.set(true, forKey: "woop.porteVue")
    }

    // MARK: Le contenu

    private func contenu(W: CGFloat, H: CGFloat, hHeader: CGFloat,
                         encartBas: CGFloat) -> some View {
        VStack(spacing: 0) {
            // LES TEXTES — le SEUL élément qui défile. Le header, les dots, la
            // flamme et le bouton vivent hors du scroll : c'est ce qui permet au
            // header de se croiser (jalon 2) au lieu de glisser latéralement.
            //
            // Le patron de pagination de la maison, couché à l'horizontale :
            // `CoffreFortFlow` (ScrollView + scrollTargetLayout +
            // containerRelativeFrame + scrollTargetBehavior(.paging)). Le dépôt
            // n'a AUCUN `TabView(.page)` — `tabViewStyle` n'y existe pas.
            Group {
                let hTexte = hHeader + PorteMesures.descenteTexte
                if let n = Self.pageFigee {
                    // LE BANC : une seule page, sans scroll (p est né sur n).
                    blocTexte(Self.pages[n])
                        .frame(height: hTexte)
                } else if Self.porteAuto {
                    // LE BANC DU FILM : le vrai scroll, balayé par programme.
                    pagesScroll(hHeader: hTexte)
                        .scrollPosition($positionAuto)
                        .task { await balayage(largeur: W) }
                } else {
                    pagesScroll(hHeader: hTexte)
                        // Pendant le film, la page ne se feuillette pas : un
                        // glissement démonterait le film en plein master (le
                        // créneau meurt à alpha ≈ 0) et le retour le REJOUERAIT.
                        // Le tap saute, le scroll attend l'habillage.
                        .scrollDisabled(!habille)
                }
            }
            .reveal(habille, delay: 0.34)

            // LES DOTS — juste sous l'arête du header, alignés à gauche sur la
            // même marge que le texte.
            PorteDots(etat: etat, total: Self.pages.count)
                .padding(.top, PorteMesures.dotsSousArete)
                .padding(.leading, PorteMesures.margeCote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .reveal(habille, delay: 0)

            Spacer(minLength: 0)

            // LE BOUTON — collé, identique aux quatre pages.
            // ⚠️ Son écrin shader déborde de 34 pt de chaque côté (halos,
            // poussières) : **aucun `clipped()` sur ce pied**, il tronquerait la
            // matière.
            // LE BOUTON PRIMAIRE DE LA MAISON (06-09) — il remplace le diamant :
            // même hauteur (58, `PorteMesures.hauteurBouton`), même débord de
            // 34 pt, et sa poudre de diamant au tap. `respecteLaCasse` parce que
            // « Apple » est un nom propre et que le bouton met tout en casse de
            // phrase (il affichait « … avec apple »).
            BoutonPrimaire(title: "Se connecter avec Apple",
                           glyph: "apple.logo",
                           respecteLaCasse: true) {
                entrerParApple()
            }
            .opacity(connexionEnCours ? 0.5 : 1)
            .allowsHitTesting(!connexionEnCours)
            .overlay(alignment: .bottom) {
                // La panne se dit SOUS le bouton, en une ligne — jamais une
                // alerte système par-dessus la porte.
                if let panne = pannePorte {
                    Text(panne)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 8)
                        .offset(y: 34)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, PorteMesures.margeCote)
            .padding(.bottom, PorteMesures.piedBouton + encartBas)
            .reveal(habille, delay: 0.62)
            // ⚠️ UNE OPACITÉ NULLE RESTE TAPPABLE. Pendant le film, le bouton
            // est invisible mais son rectangle existe : un tap dans sa zone
            // déclencherait la CÉRÉMONIE DE SORTIE en plein film d'arrivée, au
            // lieu du saut. Le doigt ne touche que ce qui est posé.
            .allowsHitTesting(habille)
            .task(id: habille) {
                guard Self.appleAuto, habille else { return }
                try? await Task.sleep(for: .milliseconds(900))
                entrerParApple()
            }
        }
    }

    /// Le scroll des textes — le SEUL élément qui défile (voir `contenu`).
    private func pagesScroll(hHeader: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Self.pages) { page in
                    blocTexte(page)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .frame(height: hHeader)
        .onScrollGeometryChange(for: SondePorte.self, of: { g in
            SondePorte(x: g.contentOffset.x + g.contentInsets.leading,
                       largeur: g.containerSize.width)
        }) { _, s in
            guard s.largeur > 1 else { return }
            let brut = Double(s.x / s.largeur)
            let borne = Double(Self.pages.count - 1)
            let p = min(max(brut, 0), borne)
            if etat.p != p { etat.p = p }
        }
    }

    /// Le balayage du banc `-porteAuto` : 0 → 1 → 2 → 3 → retour à 0, une
    /// pause posée entre chaque glissement — le temps de voir la boucle vivre.
    private func balayage(largeur: CGFloat) async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        for n in [1, 2, 3, 0] {
            withAnimation(.easeInOut(duration: 1.1)) {
                positionAuto.scrollTo(x: largeur * CGFloat(n))
            }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
        }
    }

    /// Un bloc de texte : une ZONE à gabarit fixe (kicker + 3 lignes,
    /// top-alignés), ancrée au bas du header.
    ///
    /// ⚠️ **LE `.frame(maxWidth:.infinity, alignment:.leading)` N'EST PAS
    /// DÉCORATIF — c'était LE bug d'alignement (V2, mesuré).** Sans lui, le
    /// VStack prend la largeur de sa plus longue ligne et
    /// `containerRelativeFrame` le CENTRE dans la page : les textes
    /// commençaient à 54, 57 et 101 pt selon la page au lieu de 26 — et les
    /// dots, eux à 26, paraissaient désalignés alors que c'est le texte qui
    /// flottait.
    private func blocTexte(_ page: PortePage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let kicker = page.kicker {
                Text(kicker)
                    .font(.inter(11, .medium))
                    .tracking(3.2)
                    .foregroundStyle(.white.opacity(0.42))
                    .padding(.bottom, 12)
            }
            Text(page.lignes.joined(separator: "\n"))
                // ⚠️ SEMIBOLD, pas regular (verdict 23-08 : « et plus
                // épais »). Inter a sa vraie graisse au fichier
                // (`Inter-SemiBold`) — jamais `.fontWeight`, qui ferait
                // synthétiser un gras à SwiftUI et baverait sur du néon.
                .font(.inter(27, .semibold))
                // ⚠️ **PAS `WoopGradient.titleFade` ICI, ET C'EST MESURÉ.** Ce
                // dégradé va en DIAGONALE (topLeading → bottomTrailing) et finit
                // à blanc 0,25 : sur un bloc de deux lignes, il éteint la fin de
                // la ligne 2, c'est-à-dire le mot qui porte le message. Relevé
                // à la capture, l'encre tombait de **0,94 à 0,25** en travers du
                // bloc — un facteur 3,7 dans le sens de la lecture. C'est
                // exactement le verdict déjà payé sur le titre de la connexion
                // (« le fondu diagonal éteignait justement le mot-clé »), où le
                // remède avait été de donner au mot-clé sa propre encre.
                //
                // Un texte à LIRE prend donc une encre à lui : un fondu
                // VERTICAL, très court (0,96 → 0,80), qui garde la loi de la
                // lumière d'en haut sans jamais rien éteindre. Décroissance
                // maximale 1,2× au lieu de 3,7×.
                .foregroundStyle(Self.encreTexte)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        // L'ordre des cadres : la LARGEUR d'abord (le bloc s'ancre à gauche
        // dans toute la page), puis la ZONE fixe (la première ligne au même y
        // sur les quatre pages), puis l'ancrage au bas du header.
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: PorteMesures.zoneTexte, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.horizontal, PorteMesures.margeCote)
        .padding(.bottom, PorteMesures.texteSurArete)
        // Le texte ne prend pas le doigt : le scroll doit pouvoir naître
        // n'importe où sur la page.
        .allowsHitTesting(false)
    }
}

// MARK: - Le header

/// La vidéo du header, dans son rectangle DÉFINITIF, pilotée par `p`.
///
/// **LA RÈGLE PAIR / IMPAIR (§ 4.3 du plan).** Avec `i = floor(p)` et
/// `f = p − i`, les deux pages visibles sont toujours `(i, i+1)` — donc toujours
/// une paire et une impaire. Le créneau A porte les pages PAIRES, le créneau B
/// les IMPAIRES. Conséquence, et c'est tout l'intérêt : **le créneau dont le
/// fichier change est toujours celui qui est démonté** — un créneau ne change de
/// page que lorsqu'on a traversé la page de l'autre, où il était à zéro. Aucun
/// remontage n'est jamais visible, par construction.
///
/// Au repos (`f = 0`), le créneau mort est DÉMONTÉ, pas caché : un
/// `AVPlayerLayer` à opacité nulle décode quand même. Un seul lecteur de header
/// tourne donc entre deux gestes ; deux pendant le seul glissement (le budget
/// mesuré du § 5.4 : 62,6 Mpix/s au repos, 115,9 en pointe). Au remontage, la
/// pose intégrée de `CalqueVideo` tient l'image jusqu'à `isReadyForDisplay`.
///
/// ⚠️ Cette vue est la SEULE (avec les dots) à lire `etat.p` : la page, elle, ne
/// se réévalue pas pendant le glissement. Et rien ici ne touche jamais à la
/// FRAME d'un lecteur — seules les opacités bougent.
private struct PorteHeader: View {
    let etat: EtatPorte
    let arrivee: Bool
    let largeur: CGFloat
    let hauteur: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// LA MARGE DE PARALLAXE : les vidéos sont coupées 10 pt plus larges de
    /// chaque côté (upscale ×1,172 au lieu de ×1,117 — mesuré au plan, matière
    /// verre/lueur : imperceptible, repli à ±6 si le téléphone dit non). Le
    /// mouvement total est BORNÉ à la marge : jamais un bord ne se découvre.
    private static let margePar: CGFloat = 10

    var body: some View {
        let pages = PorteEntree.pages
        let p = etat.p
        let i = min(Int(p), pages.count - 1)
        let f = p - Double(i)
        // ⚠️ **LA PARALLAXE DE LA VIDÉO EST COUPÉE (26-08).** Verdict :
        // « aucun mouvement flottant ou déplacement continu après son
        // arrivée ». Le film gelé ne suffisait pas — `SkyMotion` est une
        // DÉRIVE DE CAMÉRA (recentrage 15 s) : la vidéo continuait de glisser
        // toute seule, poignet immobile.
        //
        // Deux bénéfices pour le prix d'un. Le body du header LISAIT
        // `SkyMotion.shared.tilt`, publié à chaque échantillon (30 Hz) sans la
        // moindre bande morte — alors que le plan de la porte l'exige en
        // toutes lettres (PLAN-V2-VIVANT §2.3). Tout le ZStack des créneaux
        // vidéo, l'overlay des décors et le masque du fondu de pied se
        // réévaluaient donc trente fois par seconde dès que le téléphone
        // bougeait d'un cheveu : le commentaire « le header ne se réévalue que
        // pour p » était faux depuis la V2. Il redevient vrai.
        //
        // Les DÉCORS, eux, gardent leur vie (`PorteDecors` lit le gyro pour
        // son compte) : c'est la VIDÉO qui devait se taire, pas la page.
        // La marge `margePar` reste : les cadres sont surdimensionnés et
        // centrés, donc figés au ras du repos — et le jour du zoom-portail,
        // il n'y aura qu'un offset à rebrancher ici.
        let par = CGSize.zero
        // La page du créneau A (paire) et celle du créneau B (impaire), parmi
        // les deux visibles (i, i+1).
        let iA = (i % 2 == 0) ? i : min(i + 1, pages.count - 1)
        let iB = (i % 2 == 1) ? i : min(i + 1, pages.count - 1)
        let alphaA = (i % 2 == 0) ? 1 - f : f
        let alphaB = (i % 2 == 1) ? 1 - f : f

        // ⚠️ L'HÔTE EST `Color.clear`, ET C'EST LA LOI DU DÉPÔT : un ZStack nu
        // prendrait la taille de son plus grand enfant, et un `overlay` le
        // CENTRERAIT (le piège « la fente detail gonfle son hôte », payé deux
        // fois). `Color.clear` accepte la proposition telle quelle.
        Color.clear
            .frame(width: largeur, height: hauteur)
            .overlay {
                ZStack {
                    if (PorteEntree.sans & 8) != 0 { Color.black }
                    // Le seuil de démontage : sous un demi-pour-cent d'encre,
                    // le créneau n'existe pas — c'est lui qui borne le nombre
                    // de lecteurs, pas une opacité à zéro.
                    if alphaA > 0.005 {
                        creneau(pages[iA])
                            .opacity(alphaA)
                            .id(pages[iA].video)
                    }
                    if alphaB > 0.005 {
                        creneau(pages[iB])
                            .opacity(alphaB)
                            .id(pages[iB].video)
                    }
                }
                // ⚠️ LE MOUVEMENT EST UN TRANSFORM, JAMAIS UNE FRAME — la loi
                // payée (« on transforme, on ne redimensionne jamais ») : les
                // cadres des lecteurs sont FIGÉS (surdimensionnés de la
                // marge), seul l'offset vit. Le masque du fondu de pied, lui,
                // reste cloué à l'écran — il ne voyage pas avec la parallaxe.
                .offset(par)
                // ⚠️ Les VIDÉOS ne prennent jamais le doigt ; le manège, SI.
                // Le refus de toucher vit donc ICI, pas sur le header entier.
                .allowsHitTesting(false)
            }
            // LES TROIS DÉCORS (V3) — la carte « Sets », les deux widgets de
            // la home, le manège 3D. ⚠️ **UN SEUL `overlay`, ET C'EST UNE
            // NÉCESSITÉ DE COMPILATION** : chaînés (trois `overlay` de plus
            // sur un body qui portait déjà le croisé, la parallaxe et le
            // masque), le type-checker Swift s'enlisait — « unable to
            // type-check this expression in reasonable time », sans ligne
            // fautive utile. La loi maison de cette famille : casser
            // l'expression, hisser les scalaires pré-typés.
            .overlay { PorteDecors(etat: etat, arrivee: arrivee,
                                   largeur: largeur, hauteur: hauteur) }
            // LE FILM REJOUE AU RETOUR (V3, verdict 23-08 : « quand on revient
            // sur la partie 1, l'écran login rejoue l'animation trop belle »).
            //
            // Rien à armer : le créneau pair PORTE le film tant que
            // `arriveeFinie` est faux, et il est démonté chaque fois qu'on
            // quitte la page 1 (alpha nul → hors du ZStack). Revenir le
            // remonte, `onAppear` repart, le master rejoue du noir. La règle
            // pair/impair garantit que ce remontage tombe TOUJOURS à opacité
            // zéro : on ne voit jamais la couture.
            //
            // ⚠️ Le drapeau ne se pose donc QUE par le tap-saut : il dit « la
            // porte est habillée », plus « le film est consommé ». Sans ce
            // renversement, `iA` le levait au premier glissement et le retour
            // ne montrait que la boucle.
            //
            // ⚠️ ET LE SCROLL RESTE LIBRE pendant ce rejeu-là : `scrollDisabled`
            // ne regarde que `habille`, qui est déjà vrai. Repartir d'un
            // glissement en plein film est sain — le créneau se démonte comme
            // n'importe quelle vidéo.
            //
            // LE TAP-SAUT S'OUBLIE EN PARTANT. Il coupe le film EN COURS (le
            // créneau bascule sur la boucle dans la seconde) ; mais laissé
            // posé, un seul saut aurait tué le rejeu pour toujours. On le
            // lève donc au moment où le créneau pair quitte la page 0 —
            // c'est-à-dire à opacité nulle, là où plus rien ne se voit.
            .onChange(of: iA) { _, nv in
                if nv != 0 && etat.arriveeFinie { etat.arriveeFinie = false }
            }
            // ⚠️ LE FONDU DE PIED EST UN MASQUE, ET IL ARRIVE APRÈS LE CADRE.
            // Il n'y a aucune échelle dans cette vue, donc le masque ne peut pas
            // provoquer le zoom rastérisé de la loi 2.
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white,
                              location: 1 - PorteMesures.fonduPied / hauteur),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom)
            }
            // ⚠️ PAS de allowsHitTesting(false) global ici (V2) : il
            // affamerait le manège. Le refus de toucher vit sur le ZStack des
            // vidéos ; le manège tient le sien, conditionné à la page posée.
    }

    @ViewBuilder
    private func creneau(_ page: PortePage) -> some View {
        // Les cadres plein-champ portent la marge de parallaxe : figés à
        // largeur+2·marge, ils ne changent JAMAIS — c'est l'offset du parent
        // qui bouge.
        let wPar = largeur + 2 * Self.margePar
        let hPar = hauteur + 2 * Self.margePar
        if page.id == 0 {
            // LE FILM D'ARRIVÉE — le master joué une fois, qui GÈLE sur sa
            // dernière image. Il EST le contenu du créneau pair : la règle
            // pair/impair le protège comme n'importe quelle vidéo, et le
            // démonte au même instant sûr — c'est ce qui fait que revenir sur
            // la page 1 REJOUE l'animation, comme le veut le verdict.
            //
            // ⚠️ **LES DEUX BRANCHES DE LA PAGE 0 SONT TRAITÉES ENSEMBLE**
            // (26-08). Avant, `arrivee == false` (la porte déjà vue) ou un
            // tap-saut faisaient tomber la page 0 dans le `else` générique,
            // qui montait `CalqueVideo("onb-lune-loop")` — la MÊME boucle
            // ping-pong, en lecture infinie. Figer le film seul aurait laissé
            // la dérive intacte à tous les lancements suivants : c'était la
            // seconde branche, et elle est fermée ici.
            ReelPorte(master: "onb-arrivee",
                      joue: arrivee && !etat.arriveeFinie,
                      largeur: wPar, hauteur: hPar,
                      pose: "onb-arrivee-poster")
        } else if page.id == 3 {
            // LA PAGE BOOSTER n'a PAS de vidéo : le VRAI manège 3D vit dans
            // son propre calque (voir l'overlay du body) — hors des créneaux,
            // parce qu'il se monte UNE fois et se met en pause, jamais
            // démonté-remonté au fil du doigt.
            Color.clear
        } else {
            // ⚠️ LA VIDÉO JOUE SOUS LES VERRES, ET C'EST VOULU : « la vidéo
            // se reflète justement dans leur verre » (verdict 23-08). J'avais
            // posé une image de pose à la place pour gagner de la cadence au
            // simulateur — mais c'était retirer le sujet pour sauver le
            // chiffre. La home porte ces mêmes verres sur sa vidéo.
            CalqueVideo(nom: page.video, pose: "\(page.video)-poster")
                .frame(width: wPar, height: hPar)
        }
    }
}

// MARK: - Le film d'arrivée

/// ⚠️ **ARCHIVE — LA MÉCANIQUE À DEUX LECTEURS EST MORTE LE 26-08.** Le film
/// passait la main à `onb-lune-loop` à son image de raccord, et cette boucle
/// est un ping-pong : la caméra repartait donc en arrière à l'instant même où
/// l'arrivée se posait. Tout le détail (mesures ffmpeg comprises) est écrit
/// sur `ReelPorte` plus bas. Ce qui reste vrai de l'ancienne page, et qui
/// resservira le jour du zoom-portail : `preroll` doit être ATTACHÉ à une
/// observation de `.status` — appelé avant `readyToPlay` il lève une exception
/// et TUE l'app (payé le 21-08, et nous sommes sur l'écran de lancement) ; et
/// un échange de couches se fait SEC, jamais en fondu croisé (la couche
/// entrante n'a pas encore d'image, on composerait contre du noir).
///
/// L'hôte des couches du film : `AVPlayerLayer` en **remplissage**, borné.
/// ⚠️ `CinematicPlayer` (aspect-FIT codé en dur) convenait quand le cadre
/// collait au ratio du fichier à 7e-5 près ; depuis la marge de parallaxe
/// (cadre 422 × 632, ratio 0,668 ≠ 0,657) il laissait 3,4 pt de colonnes
/// vides de chaque côté — que l'offset de parallaxe ferait ENTRER dans le
/// champ. Fill + clip, les deux lignes du remède payé.
private struct ReelHote: UIViewRepresentable {
    let player: AVPlayer

    final class Vue: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> Vue {
        let v = Vue()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.playerLayer.videoGravity = .resizeAspectFill
        v.playerLayer.backgroundColor = UIColor.clear.cgColor
        v.clipsToBounds = true
        v.playerLayer.masksToBounds = true
        v.playerLayer.player = player
        return v
    }

    func updateUIView(_ v: Vue, context: Context) {
        if v.playerLayer.player !== player { v.playerLayer.player = player }
    }

    static func dismantleUIView(_ v: Vue, coordinator: ()) {
        v.playerLayer.player = nil
    }
}

/// LE FILM D'ARRIVÉE — le master, joué UNE fois, qui GÈLE sur sa dernière
/// image. C'est la mécanique de `StoryReel` (StoryVideo.swift:41), réécrite
/// pour deux raisons qui ne se contournent pas : `StoryReel` code sa base de
/// temps à 24 en dur (nos fichiers sont à 30) et son débit à 1,25.
///
/// ⚠️ **LE RELAIS VERS LA BOUCLE EST MORT (26-08), ET C'ÉTAIT LUI, « LE LÉGER
/// MOUVEMENT QUI CRÉE DES BUGS ».** Verdict de Kathryn : « la vidéo arrive,
/// elle se place, elle reste ensuite COMPLÈTEMENT FIXE ».
///
/// Ce qu'on croyait être un flottement ajouté était la MÉCANIQUE du raccord,
/// et la sonde (ffmpeg + numpy sur les fichiers) le dit sans appel.
/// ⚠️ **LES COTES CI-DESSOUS SONT CELLES DU FICHIER V3** (274 images), celui
/// qui portait le bug : elles sont gardées comme la PREUVE du diagnostic, pas
/// comme une description du fichier d'aujourd'hui (V4, 164 images — voir
/// `arriveeT`). Le remède, lui, ne dépend d'aucune de ces cotes : il n'y a
/// plus de second lecteur du tout.
///   · `onb-arrivee.mp4` faisait 274 images à 30 i/s = 9,133 s — exactement
///     `arriveeT`, l'instant où la partition pose l'habillage ;
///   · son image 178 est l'image 0 de `onb-lune-loop.mp4` (écart 0,56/255) ;
///   · sa DERNIÈRE image (273) est l'image 95 de cette boucle (0,56) ;
///   · or la boucle est un PING-PONG de 190 images (f0 ≈ f189 à 1,82 ;
///     f47 ≈ f141 à 2,16) dont l'image 95 est le POINT DE RETOURNEMENT.
/// Donc à la seconde PRÉCISE où le film se posait, la caméra repartait en
/// arrière pour 3,13 s, puis revenait, à l'infini. Et le trou d'`AVPlayerLooper`
/// (1 à 3 images vidées à chaque tour, tous les 6,33 s) découvrait la pose,
/// prise à l'AUTRE extrémité de la course : un saut de cadrage, pas un flash —
/// ce que le détecteur de flash du jalon O1 ne pouvait pas voir, les deux
/// images ayant la même luminance (14,04 contre 14,94).
///
/// Le master porte déjà `actionAtItemEnd = .pause` : sans relais, il gèle tout
/// seul sur son image 273, c'est-à-dire exactement la position finale de
/// l'arrivée. Il n'y a plus de second lecteur, plus de boucle, plus d'observateur
/// de temps — donc plus rien à vider.
private struct ReelPorte: View {
    let master: String
    /// ⚠️ **`joue: false` = LA POSE DIRECTE.** Aux lancements suivants (la
    /// porte déjà vue) et juste après le tap-saut, la page 0 montrait la
    /// boucle ping-pong par un AUTRE chemin (`CalqueVideo`) : figer le film
    /// seul n'aurait rien réglé pour elle. Ici le même fichier est simplement
    /// AMENÉ à sa fin et mis en pause — aucune image de plus à cuire, et la
    /// position est la même au pixel près que celle où le film se termine.
    var joue = true
    let largeur: CGFloat
    let hauteur: CGFloat
    /// La première image du master (elle commence au NOIR) : le filet le temps
    /// que le décodeur présente. Inutile en pose directe — on y saute.
    let pose: String

    @State private var cine: AVPlayer?
    @State private var retour: NSObjectProtocol?
    @State private var finObs: NSObjectProtocol?
    /// L'observation de `.status` qui porte le pré-roulage.
    @State private var pret: NSKeyValueObservation?
    /// Le film est arrivé au bout : la pose de tête n'a plus rien à couvrir,
    /// et surtout elle ne doit PAS reparaître sous une image gelée.
    @State private var posee = false

    var body: some View {
        ZStack {
            if !posee {
                Image(pose)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            if let cine {
                ReelHote(player: cine)
            }
        }
        .frame(width: largeur, height: hauteur)
        .clipped()
        .onAppear(perform: demarre)
        .onDisappear(perform: demonte)
    }

    private func demarre() {
        // ⚠️ L'ASSET VIENT DU CELLIER : chaud, il ne se re-parse pas au
        // moment le plus chargé du lancement.
        guard cine == nil, let item = AssetsVideo.item(master) else { return }

        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        // ⚠️ C'EST LUI QUI FIGE. Sans `.pause`, un `AVPlayer` rembobine à zéro
        // en fin d'item et l'arrivée se rejouerait en boucle.
        p.actionAtItemEnd = .pause
        cine = p

        guard joue else {
            // LA POSE DIRECTE : on saute à la fin, et rien ne bouge jamais.
            // La tolérance nulle est nécessaire — un `seek` approché
            // atterrirait sur l'image clé la plus proche, c'est-à-dire
            // potentiellement des secondes avant la fin.
            posee = true
            Task { @MainActor in
                let fin = try? await item.asset.load(.duration)
                guard let fin, fin.isNumeric else { return }
                await p.seek(to: fin, toleranceBefore: .zero,
                             toleranceAfter: .zero)
                p.pause()
            }
            return
        }

        // LA REPRISE APRÈS L'ARRIÈRE-PLAN — la loi de CalqueVideo : sans elle,
        // une notification pendant le film laisse une image FIGÉE pour
        // toujours. ⚠️ On ne relance QUE si le film n'est pas déjà arrivé au
        // bout : le réveiller posé le ferait rembobiner.
        retour = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { _ in
                guard !posee else { return }
                cine?.play()
            }

        // La fin du film : on lève le drapeau, et la pose de tête se démonte.
        // (`AVPlayerItemDidPlayToEndTime` plutôt qu'un observateur de temps :
        // il ne peut pas manquer sa cible sur une image sautée.)
        finObs = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item, queue: .main) { _ in
                posee = true
            }

        // ⚠️ **ON PRÉ-ROULE AVANT DE JOUER, ET JAMAIS AVANT `readyToPlay`.**
        // C'est la loi payée le 21-08 : `preroll` appelé sur un lecteur qui
        // n'est pas prêt lève une exception et TUE l'app — et nous sommes sur
        // l'écran de lancement. Elle est donc ATTACHÉE à une observation de
        // `.status`, exactement comme le faisait la boucle avant sa mort.
        //
        // Sans ce pré-roulage, `automaticallyWaitsToMinimizeStalling = false`
        // fait partir le film à l'image zéro sans un octet d'avance : les
        // premières secondes hoquettent. Avec, le décodeur a sa réserve et le
        // film part net.
        // ⚠️ KVO et le rappel de `preroll` n'arrivent PAS sur le fil
        // principal : `play()` s'y remet explicitement.
        pret = p.observe(\.status, options: [.initial, .new]) { lecteur, _ in
            guard lecteur.status == .readyToPlay else { return }
            lecteur.preroll(atRate: 1) { ok in
                guard ok else { return }
                DispatchQueue.main.async { lecteur.play() }
            }
        }
    }

    private func demonte() {
        if let retour { NotificationCenter.default.removeObserver(retour) }
        retour = nil
        if let finObs { NotificationCenter.default.removeObserver(finObs) }
        finObs = nil
        pret?.invalidate(); pret = nil
        cine?.pause(); cine?.replaceCurrentItem(with: nil); cine = nil
    }
}

// MARK: - La flamme du pied

/// `home-fond-flamme.mp4`, à son ratio natif et sur toute la largeur. C'est le
/// calque du DESSOUS : pas de blend, pas de masque, opacité 1 — le dégradé de
/// son haut est cuit dans le fichier.
private struct PorteFlamme: View {
    let largeur: CGFloat

    var body: some View {
        CalqueVideo(nom: "home-fond-flamme", pose: "home-fond-flamme-poster")
            .frame(width: largeur,
                   height: largeur / PorteMesures.ratioFlamme)
            .allowsHitTesting(false)
    }
}

// MARK: - Les dots

/// Quatre pastilles ; l'active est une capsule étirée. La position est CONTINUE :
/// pendant le glissement, la capsule se déplace et se déforme avec le doigt.
///
/// ⚠️ Pas de `View, Animatable` ici, et c'est raisonné : `p` n'est jamais posé
/// sous un `withAnimation`, c'est une valeur de géométrie VIVANTE écrite par la
/// sonde du scroll. La loi de l'`Animatable` vaut pour les rampes animées, pas
/// pour un curseur que le doigt tient déjà.
private struct PorteDots: View {
    let etat: EtatPorte
    let total: Int

    private static let hauteur: CGFloat = 6
    private static let court: CGFloat = 10
    private static let long: CGFloat = 22
    private static let ecart: CGFloat = 6

    var body: some View {
        HStack(spacing: Self.ecart) {
            ForEach(0..<total, id: \.self) { i in
                // La proximité de la page, de 0 (loin) à 1 (dessus) : elle
                // pilote et la largeur et l'encre, donc la capsule s'étire au
                // rythme exact du doigt.
                let k = max(0, 1 - abs(etat.p - Double(i)))
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.22 + 0.70 * k))
                    .frame(width: Self.court + (Self.long - Self.court) * k,
                           height: Self.hauteur)
            }
        }
    }
}

// MARK: - La sortie : la flamme embrase

/// La cérémonie de sortie (§ 7 du plan). Deux rampes, une horloge :
///
///   0,00 → 1,45   LE RIDEAU — le noir descend sur le header, la vidéo
///                 s'éteint dans l'ordre où on l'a découverte.
///   0,00 → 1,95   LE FOYER — la flamme ne monte PAS : c'est la ZONE qu'elle
///                 éclaire qui grandit (un feu qui prend éclaire plus haut,
///                 il ne se déplace pas — la loi écrite du fond de la home).
///
/// Le foyer est à la couleur MESURÉE du lit (`Feu.lit`, ratio 1 : 0,272 :
/// 0,015) en `.plusLighter` : ajouter du lit à du lit ne change ni teinte ni
/// saturation — ANTI-BRUN PAR CONSTRUCTION, pas par précaution.
///
/// Le rideau est un rectangle nu : sa frame peut vivre par image, ce n'est pas
/// une couche vidéo. La vidéo du header, elle, ne bouge pas d'un pixel — elle
/// est simplement recouverte, puis la racine coupe à 2,10 s sous les braises.
/// LE PORTAIL DE LA LUNE — la sortie de la porte, et l'entrée de la maison.
///
/// ⚠️ **CE QUI A REMPLACÉ LA BANDE NOIRE** (26-08). L'ancienne sortie faisait
/// descendre un rectangle noir depuis le bord haut sur 1,45 s. Verdict :
/// « ça donne l'impression que deux écrans sont simplement superposés ». Et
/// c'est littéralement ce que c'était.
///
/// LA PARTITION, en fonction pure du temps (aucun état, rien à annuler) :
///   0,00 → 0,55   LA LUNE NAÎT — le croissant de la marque, minuscule au
///                 centre, à peine allumé. C'est l'« accélération très
///                 douce » : la course est en `pow(p, 2,4)`, donc le premier
///                 tiers du temps ne consomme que 4 % de la course. On voit
///                 la lune AVANT de la voir grandir.
///   0,55 → 1,60   LA PLONGÉE — l'échelle part vers ×26 : le croissant sort
///                 du cadre par tous les côtés, et son INTÉRIEUR prend
///                 l'écran. C'est ça, « traverser la lune » — on ne fond pas
///                 vers elle, on entre DEDANS.
///   1,10 → 2,10   LA PROFONDEUR — le flou monte avec l'échelle (la mise au
///                 point ne suit pas un objet qui arrive sur l'objectif), et
///                 la nuit se referme derrière : à 2,10 s, l'instant de la
///                 coupe, l'écran est SA lumière, plus la porte.
///
/// ⚠️ **LE CROISSANT EST VECTORIEL, ET C'EST LA CONDITION DE TOUT.**
/// `GlypheLune` est le path des 18 cubiques du logo : à ×26, il reste net.
/// Un bitmap ou une capture de la vidéo se rastériserait — la loi payée du
/// zoom rastérisé, déjà écrite deux fois dans ce dépôt.
///
/// ⚠️ **PAS DE FLASH.** La lumière monte en `smoothstep` sur 1,05 s et
/// plafonne à 0,88 : la maison a un détecteur de flash, et une transition qui
/// claque au blanc est exactement ce qu'il attrape.
private struct PortailLune: View {
    let start: Date
    let largeur: CGFloat
    let hauteur: CGFloat

    private func lisse(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    /// `-portailFige <s>` : la traversée figée à un instant donné. Une
    /// transition de deux secondes ne se capture pas au simulateur (une
    /// capture d'écran coûte ~0,9 s) : sans ce gel, elle n'est jugeable que
    /// sur l'appareil — la loi des bancs de cette maison.
    private static let fige: Double? = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-portailFige"), i + 1 < a.count,
              let v = Double(a[i + 1]) else { return nil }
        return max(0, v)
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = Self.fige ?? tl.date.timeIntervalSince(start)
            // LA COURSE : très lente d'abord, puis elle emporte tout.
            let p = lisse(t / 1.60)
            let course = pow(p, 2.4)
            // Le corps de départ : une pastille, la taille du glyphe dans le
            // cube de verre de la vidéo — la lune qu'on regardait.
            let base = largeur * 0.17
            let echelle = 1 + 25 * course
            let nuit = lisse((t - 0.30) / 1.10)
            // ⚠️ **LA TRAVERSÉE FINIT AU NOIR, ET C'EST UNE LOI DE LA MAISON.**
            // Premier jet : la lumière restait à son plafond, et l'écran
            // devenait un GRIS UNIFORME à 1,9 s — mesuré sur capture. La coupe
            // de 2,10 s tombait donc du gris à la home, en une image. Or ce
            // dépôt a déjà payé deux fois « la feuille système recule la
            // fenêtre et révèle un FOND GRIS » : un aplat gris ne se lit jamais
            // comme une transition, il se lit comme une panne.
            //
            // La partition d'origine le disait déjà, d'ailleurs :
            // « LA COUPE : plein noir derrière le nuage suspendu » (`swapAt`).
            // On est DEDANS la lune à 1,40 s ; de l'autre côté il fait nuit, et
            // c'est sur cette nuit-là que la home se révèle.
            let passage = lisse((t - 1.35) / 0.62)
            let lumiere = 0.88 * lisse(t / 1.05) * (1 - passage)
            let flou = 26 * lisse((t - 0.55) / 1.05)
            let foyer = lisse(t / 1.95)

            ZStack {
                // LA NUIT QUI SE REFERME DERRIÈRE ELLE — un fondu PLEIN CADRE,
                // jamais une bande qui descend : c'est la profondeur de champ
                // qui avale la porte, pas un store.
                Color.black.opacity(min(1, nuit * 0.96 + passage))

                // LE FOYER DE LA FLAMME — il survit au rideau : c'est la
                // chaleur qui monte du pied, elle n'a jamais été le problème.
                EllipticalGradient(
                    colors: [Feu.lit.opacity(0.12 + 0.24 * foyer), .clear],
                    center: UnitPoint(x: 0.5, y: 1.0),
                    endRadiusFraction: 0.5)
                    .frame(width: largeur * 1.4, height: 260 + 480 * foyer)
                    .frame(maxWidth: .infinity, maxHeight: .infinity,
                           alignment: .bottom)
                    .blendMode(.plusLighter)
                    .opacity(1 - nuit)

                // LE HALO — il arrive AVANT le croissant et le déborde : une
                // lune qui grandit sans halo se lit comme un autocollant qui
                // grossit ; avec, elle se lit comme une source qui s'approche.
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(lumiere * 0.55),
                                 Color.white.opacity(lumiere * 0.10), .clear],
                        center: .center, startRadius: 0,
                        endRadius: base * echelle * 1.5))
                    .frame(width: base * echelle * 3.4,
                           height: base * echelle * 3.4)
                    .blendMode(.plusLighter)

                // LE CROISSANT — vectoriel, donc net à toute échelle.
                // ⚠️ `frame` CONSTANT + `scaleEffect` : la loi de la maison
                // (« on transforme, on ne redimensionne jamais »). Un `frame`
                // animé re-layouterait le path à chaque image.
                GlypheLune()
                    .fill(LinearGradient(
                        colors: [Color.white.opacity(lumiere),
                                 Color(white: 0.86).opacity(lumiere * 0.92)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: base, height: base)
                    .scaleEffect(echelle)
                    .blur(radius: flou)
                    .blendMode(.plusLighter)
            }
            .frame(width: largeur, height: hauteur)
            .compositingGroup()
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Les trois décors du header

/// La carte « Sets », les deux widgets de la home, le manège 3D. Ils vivent
/// dans leur propre vue pour deux raisons :
///
/// 1. **la compilation** — chaînés en trois `overlay` sur le body de
///    `PorteHeader`, qui portait déjà le croisé, la parallaxe et le masque, le
///    type-checker Swift s'enlisait (« unable to type-check this expression in
///    reasonable time », sans ligne fautive utile) ;
/// 2. **la réévaluation** — seuls eux lisent les drapeaux de naissance et la
///    proximité ; le header, lui, ne se réévalue que pour `p`.
///
/// ⚠️ LES TROIS NAISSENT SUR TROIS PAGES POSÉES DIFFÉRENTES (§ `EtatPorte`) :
/// on paie la compilation de leurs pipelines sur un écran immobile, jamais
/// sous le doigt — et jamais deux au même instant.
private struct PorteDecors: View {
    let etat: EtatPorte
    /// Le film d'arrivée est en jeu sur cette page. ⚠️ **IL COMMANDE LA
    /// NAISSANCE DU MANÈGE**, et c'est la correction du 26-08 (voir
    /// `delaiManege`).
    let arrivee: Bool
    let largeur: CGFloat
    let hauteur: CGFloat

    /// La poignée du manège — persistante : c'est par elle que la pose se
    /// rejoue (`coordinator.rejoueLaPose()`).
    @State private var manegeHandle = BoosterHandle()
    @State private var dernierePose = Date.distantPast

    /// LE DÉLAI DE NAISSANCE DU MANÈGE — ET C'EST LUI, « LA VIDÉO LAGUE ».
    ///
    /// ⚠️ **MESURÉ À LA SONDE, PAS DÉDUIT** (`-porteNeuve -fps`, banc
    /// `kat-entree`). Le journal met les deux faits côte à côte :
    ///
    ///     [cadence] porte : 56,6 img/s (pire trou 111 ms)
    ///     [booster-bench] lune: geo=false op=1.0          ← BoosterScene.init
    ///     [booster-bench] scène : mylar=false env=booster-studio.hdr
    ///     [cadence] porte : 53,0 img/s (pire trou 128 ms)
    ///     [cadence] porte : 38,1 img/s (pire trou 224 ms)  ← LE TROU
    ///     [cadence] porte : 59,4 img/s (pire trou 26 ms)   ← ça repart
    ///
    /// Un trou de 224 ms, c'est SEPT images de film à 30 i/s qui ne sont
    /// jamais servies. Le fil principal était dans `BoosterScene.init` (le
    /// mesh `.bin`, sept PNG sans cache, puis la compilation des pipelines
    /// Metal), déclenché par `naisManegeApres(1.2)` — donc **1,2 s après le
    /// début du film**, en plein dedans.
    ///
    /// Le calcul « on le paie page 1, pendant qu'on lit le welcome » (mesure
    /// de la V2 : manège 1137 ms contre 396 pour la carte Sets) reste JUSTE —
    /// mais il a été écrit pour la porte DÉJÀ VUE, celle qui naît habillée.
    /// Au premier lancement il n'y a pas de welcome à lire à +1,2 s : il y a
    /// un film. Le délai suit donc ce qui est réellement à l'écran.
    ///
    /// ⚠️ **ET IL ATTEND LE FOUR, PAS SEULEMENT LE FILM.** `WoopApp` allume
    /// son four à `arriveeT + 3,5` et le laisse cuire 1,8 s : c'est LUI qui
    /// compile les pipelines, pour que ce montage-ci ne les paie plus. Naître
    /// avant sa sortie de four, c'était rendre le four inutile — le journal
    /// montrait d'ailleurs `BoosterScene` construite DEUX fois. On se pose
    /// donc derrière : `arriveeT + 5,6`.
    ///
    /// Hors film, rien ne change : 1,2 s, la valeur mesurée de la V2.
    private var delaiManege: Double {
        arrivee && !etat.arriveeFinie ? PorteEntree.arriveeT + 5.6 : 1.2
    }

    var body: some View {
        let p = etat.p
        ZStack {
            sets(p)
            widgets(p)
            manege(p)
        }
        // LE MANÈGE NAÎT SUR LA PAGE 1, EN DIFFÉRÉ — et c'est une décision
        // MESURÉE. La bissection (`-porteSans`) l'a désigné seul coupable :
        //     nue 449 ms · Sets seule 396 · widgets seuls 367 · MANÈGE 1137
        // Son régime permanent, lui, tient 60 img/s : le coût est tout entier
        // dans sa NAISSANCE (bin + 7 PNG sans cache + compilation des
        // pipelines Metal, sur le fil principal).
        //
        // On le paie donc là où l'on s'attarde le plus — la page 1, pendant
        // qu'on lit le welcome — et 2,5 s APRÈS la pose, pour laisser la carte
        // « Sets » se monter d'abord : un décor, un instant.
        // ⚠️ 1,2 s, pas 2,5 : à 2,5 le balayage avait déjà quitté la page (il
        // ne s'y arrête que 2 s) et c'était le REPLI de la page 3 qui payait —
        // exactement ce qu'on voulait éviter. La fenêtre doit tenir dans le
        // temps qu'un humain passe à lire deux lignes.
        // ⚠️ Et seulement SI ON Y EST ENCORE : parti entre-temps, le coût
        // retomberait sous le doigt, ce qu'on cherche précisément à éviter.
        // Le repli reste la pose sur la page 3, pour qui feuillette vite.
        .onChange(of: p > 1.98 && p < 2.02) { _, pose in
            if pose && !etat.manegeNe { etat.manegeNe = true }
        }
        .onChange(of: p < 0.02) { _, pose in
            guard pose else { return }
            if !etat.sertiNe { etat.sertiNe = true }
            naisManegeApres(delaiManege)
        }
        .onChange(of: p > 0.98 && p < 1.02) { _, pose in
            if pose && !etat.widgetsNes { etat.widgetsNes = true }
        }
        .onChange(of: p > 2.98) { _, pose in
            guard pose else { return }
            // La PREMIÈRE pose est la cinématique native du montage ; les
            // suivantes se rejouent, avec un anti-spam d'1,5 s.
            if etat.manegeDejaPose {
                if Date().timeIntervalSince(dernierePose) > 1.5 {
                    manegeHandle.coordinator?.rejoueLaPose()
                }
            } else {
                etat.manegeDejaPose = true
            }
            dernierePose = Date()
        }
        .onAppear {
            // ⚠️ **`onChange` NE SE DÉCLENCHE PAS POUR LA VALEUR INITIALE**, et
            // ça m'a coûté quatre mesures : la porte naît sur la page 1, donc
            // `p < 0.02` est déjà VRAI au montage — l'`onChange` ci-dessus
            // n'était jamais appelé et le manège naissait toujours par son
            // repli, en plein balayage. Toute naissance « à la pose » a besoin
            // de son jumeau ici.
            if p > 2.9 { etat.manegeNe = true }
            if p < 0.02 || p > 0.5 { etat.sertiNe = true }
            if p > 0.9 { etat.widgetsNes = true }
            if p < 0.02 { naisManegeApres(delaiManege) }
            // Les bancs `-portePage <n>` DÉMARRENT sur leur page : le
            // franchissement n'a jamais lieu, la naissance non plus.
        }
    }

    /// La naissance différée du manège : seulement SI ON EST ENCORE sur la
    /// page 1 quand le délai tombe — parti entre-temps, le coût retomberait
    /// sous le doigt, ce qu'on cherche précisément à éviter.
    private func naisManegeApres(_ delai: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delai) {
            if etat.p < 0.02 && !etat.manegeNe { etat.manegeNe = true }
        }
    }

    /// LA CARTE « SETS » — page 2, celle qui dit « log every set as you go » :
    /// la promesse est MONTRÉE. C'est la VRAIE carte de la fiche d'exercice,
    /// en petit, et elle JOUE : les séries se valident une à une, les flammes
    /// s'allument, la jauge monte. Sa cinématique est sa démonstration.
    @ViewBuilder
    private func sets(_ p: Double) -> some View {
        let prox: Double = max(0, 1 - abs(p - 1))
        let montre: Bool =
            etat.sertiNe && prox > 0.005 && (PorteEntree.sans & 1) == 0
        if montre {
            // ⚠️ **AUCUN `scaleEffect` ICI, ET C'EST LA CAUSE DU « FOND
            // NOIR »** (verdict 23-08, répété deux fois). Ce bijou est peint
            // par un shader : mis à l'échelle, SwiftUI le compose dans un
            // tampon puis agrandit ce tampon — la matière (grain, veine,
            // liseré hairline) se rastérise et il ne reste qu'une plaque
            // sombre. Un composant en shader ou en verre se REDIMENSIONNE par
            // sa largeur, jamais par une échelle. (Cousine de la loi payée du
            // zoom rastérisé, StoryVideo.swift:36-54.)
            PorteSeries()
                .flotte(phase: 0.15, ampX: 2.4, ampY: 4.5, periode: 6.4)
                // Remontée de 46 pt : elle se fond dans le décor au lieu de
                // se poser dessus.
                .padding(.top, hauteur * 0.56 - 46)
                .opacity(prox)
                .frame(maxHeight: .infinity, alignment: .top)
                // ⚠️ ELLE PREND LE DOIGT (verdict 23-08 : « le user peut la
                // déplacer comme une pilule ») — mais SEULEMENT une fois la
                // page posée : pendant un glissement, le doigt appartient au
                // feuilletage. Même loi que le manège.
                .allowsHitTesting(prox > 0.98)
        }
    }

    /// LES DEUX WIDGETS DE LA HOME V2 — page 3, celle qui parle de suivre sa
    /// performance. Les VRAIES cards, avec le mois ouvert.
    @ViewBuilder
    private func widgets(_ p: Double) -> some View {
        let prox: Double = max(0, 1 - abs(p - 2))
        let montre: Bool =
            etat.widgetsNes && prox > 0.005 && (PorteEntree.sans & 2) == 0
        if montre {
            // ⚠️ **AUCUN `scaleEffect` ICI NON PLUS** — même cause, même
            // symptôme : un `glassEffect` mis à l'échelle rend un BLUR PLAT,
            // il cesse de lire comme du verre (le piège du verre aux bounds
            // vivants). La cote passe donc dans le `frame` des cards.
            // Remontées de 30 pt (verdict 23-08).
            PorteWidgets()
                .padding(.top, hauteur * 0.56 - 30)
                .opacity(prox)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        }
    }

    /// LE MANÈGE 3D — page 4. Monté UNE fois (chaque init recharge bin +
    /// 7 PNG sans cache et recompile ses pipelines), puis `paused` au fil du
    /// doigt : ⚠️ jamais `opacity(0)` seul, une SCNView effacée par l'opacité
    /// rend quand même à 60 fps (payé). Il échappe à la parallaxe — une scène
    /// 3D a la sienne (le gyro contre-pivote l'anneau).
    @ViewBuilder
    private func manege(_ p: Double) -> some View {
        let montre: Bool = etat.manegeNe && (PorteEntree.sans & 4) == 0
        if montre {
            let prox: Double = max(0, 1 - abs(p - 3))
            BoosterStage(still: false, frozenTear: nil,
                         startOpen: false, gallery: true,
                         handle: manegeHandle,
                         paused: prox < 0.02,
                         panOnly: true, muet: true)
                .frame(width: largeur, height: hauteur)
                .opacity(prox)
                // Le doigt n'appartient au manège que la page POSÉE : pendant
                // un glissement, il appartient au scroll.
                .allowsHitTesting(p > 2.98)
        }
    }
}

// MARK: - La carte « Sets » de la page 2

/// La carte de la fiche d'exercice, en démonstration : les séries se valident
/// une à une, en boucle. C'est SA cinématique — les cinq flammes qui
/// s'allument, la jauge-braise qui monte, le compte qui roule en
/// `numericText` — et elle raconte la page mieux qu'une phrase.
///
/// ⚠️ L'horloge vit DANS ce composant, pas dans la page : la porte ne doit
/// pas se réévaluer pour une flamme qui s'allume. Et elle meurt avec lui —
/// le sous-arbre entier est absent hors de la page 2.
private struct PorteSeries: View {
    @State private var done = 0
    /// LA PILULE SE DÉPLACE (verdict 23-08 : « le user peut la déplacer comme
    /// une pilule partout dans l'écran »). Le déplacement est PERSISTANT le
    /// temps de la page : on la pose où l'on veut, elle y reste.
    @State private var pose: CGSize = .zero
    @State private var depuis: CGSize = .zero

    var body: some View {
        // ⚠️ La commodité `FlammeJauge(done:)` ne prend PAS `total`/`contrat`
        // (extension `where Detail == EmptyView`) : dès qu'on veut la ligne de
        // contrat, il faut l'init mémoire complète et fermer le `detail`
        // soi-même.
        // ⚠️ **`bouge: false` — MON OPTIMISATION AVAIT MANGÉ LA MATIÈRE.**
        // En course, le bijou éteint ses deux couches les plus chères : le
        // GRAIN tuilé et la VEINE d'or. Je l'avais forcé en permanence pour
        // gagner de la cadence — et la carte lisait « plaque noire » au lieu
        // du verre gonflé de la fiche d'exercice (verdict 23-08). Ces deux
        // couches SONT sa matière : les éteindre, c'est livrer autre chose.
        // La cadence se gagne ailleurs (l'image de pose sous le verre, § plus
        // haut, a rendu 60 img/s à la page 3).
        // LA FORME ENCASTRÉE — celle de la fiche d'exercice. `bandeau` ouvre
        // en tête une bande où le composant NE DESSINE RIEN D'OPAQUE : c'est
        // par ce trou que le verre (et la vidéo qui s'y reflète) remonte, et
        // c'est lui qui fait le « verre gonflé ». Il y pose aussi la poignée
        // et les cinq flammes en encre sombre. `dansEcrin` rentre les rayons
        // et éteint la veine d'or — deux bijoux ne se disputent pas le bord.
        FlammeJauge(done: done, total: 5,
                    contrat: "5 sets · 12 reps · 20 kg",
                    dansEcrin: true,
                    bandeau: 40,
                    liseré: 1,
                    detail: { EmptyView() })
            // LE VERRE — ⚠️ **`.clear`, EXACTEMENT COMME `CardCorps`**, et
            // surtout PAS le `.regular.tint(black 0,30)` de la dalle du
            // player, que j'avais recopié : un verre TEINTÉ NOIR à 30 %, donc
            // un fond sombre — c'était ça, le « fond noir opaque » (et
            // `.regular` est de toute façon interdit par la loi maison).
            //
            // La dalle, elle, n'existe déjà plus : `dansEcrin` la rend
            // transparente (« dans l'écrin, la dalle n'existe plus — le
            // médaillon, le titre et la jauge sont posés DIRECTEMENT sur le
            // verre »). Il ne manquait donc que le bon verre dessous.
            .background {
                GlassEffectContainer(spacing: 0) {
                    Color.clear.glassEffect(
                        .clear,
                        in: RoundedRectangle(cornerRadius: 26,
                                             style: .continuous))
                }
            }
            // La largeur EST la taille (jamais une échelle : elle
            // rastériserait le shader). 230 au lieu de 268 — « trop grosse,
            // trop présente », verdict 25-08.
            .frame(width: 230)
            .offset(x: pose.width, y: pose.height)
            // ⚠️ Le geste vit ICI, sur la pilule elle-même, et il est
            // SIMULTANÉ : posé en `.gesture`, il volerait le feuilletage à
            // toute la page — on ne peut plus quitter la page 2 (l'école
            // StoryFlow : décider au lâcher, jamais confisquer le doigt).
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { v in
                        pose = CGSize(width: depuis.width + v.translation.width,
                                      height: depuis.height + v.translation.height)
                    }
                    .onEnded { _ in depuis = pose }
            )
            .task {
                // Un cycle lent : une série toutes les 1,1 s, une respiration
                // de 2 s à plein, puis on repart de zéro.
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_100_000_000)
                    guard !Task.isCancelled else { return }
                    if done >= 5 {
                        // ⚠️ LA REMISE À ZÉRO EST UNE COUPE, JAMAIS UNE
                        // ANIMATION. Animée, la jauge se VIDAIT et les cinq
                        // flammes s'éteignaient une à une en ressort — la
                        // carte semblait « disparaître en fondu toutes les
                        // cinq secondes » (verdict 23-08). Un cycle de démo
                        // se rembobine hors champ, il ne se joue pas à
                        // l'envers.
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx) { done = 0 }
                    } else {
                        withAnimation(.spring(response: 0.5,
                                              dampingFraction: 0.8)) {
                            done += 1
                        }
                        if done == 5 {
                            try? await Task.sleep(nanoseconds: 2_400_000_000)
                        }
                    }
                }
            }
    }
}

// MARK: - Les deux widgets de la page 3

/// Les deux cards de la home v2, en démonstration : le volume de la semaine,
/// et la régularité **ouverte sur son mois** (verdict 23-08 : « prends celui
/// de la régularité avec les mois »).
///
/// ⚠️ La grille des trente et un points n'existe QUE chambre ouverte, et la
/// chambre s'ouvre au DOIGT — sur la porte les cards sont inertes, elle ne
/// s'ouvrirait donc jamais. D'où `chambreImposee` : l'hôte anime l'ouverture
/// lui-même, une fois, à l'arrivée. Les points arrivent en cascade dans
/// l'ordre de lecture, c'est la cinématique du composant.
private struct PorteWidgets: View {
    /// La cote des cards. 136 = les 170 du composant, réduits — mais par le
    /// CADRE, jamais par une échelle : un verre mis à l'échelle rend un blur
    /// plat et cesse de lire comme du verre.
    static let cote: CGFloat = 136
    /// La descente de la seconde card.
    static let decale: CGFloat = 18

    @State private var mois: Double = 0

    var body: some View {
        // ⚠️ **CARRÉES, ET C'EST IMPÉRATIF** (verdict 23-08). Elles n'avaient
        // AUCUNE taille : composées à la main, hors de `CardsRangee`, elles
        // perdaient le `.frame(170 × 170)` que son `slotVue` leur donne — et
        // prenaient donc leur taille naturelle, haute, qui débordait sur le
        // texte. Le carré n'est pas un goût : c'est la forme du composant.
        //
        // ⚠️ ET LE VERRE NATIF RESTE (`verre: true`). Je l'avais retiré en
        // chassant une hypothèse de cadence — que la bissection a ensuite
        // DÉMENTIE : les deux cards coûtent 367 ms, le manège 1137. Le verre
        // n'y était pour rien, et la home les porte en verre : elles doivent
        // se ressembler.
        //
        // LE DÉCALÉ : la seconde descend de 18 pt. Deux carrés alignés au
        // cordeau lisent « tableau » ; décalés, ils lisent « posés ».
        // ⚠️ **AUCUN `GlassEffectContainer` AUTOUR — la home n'en met pas**,
        // et pour cause : `CardCorps` porte DÉJÀ le sien à l'intérieur
        // (WidgetsCards.swift:270). En ajouter un par-dessus IMBRIQUE deux
        // conteneurs, et le verre s'y dégrade — il cesse de réfracter et lit
        // comme une card sombre (verdict 25-08 : « pas les deux widgets »).
        // La home compose ses deux slots dans un simple `HStack`. On fait
        // pareil.
        HStack(alignment: .top, spacing: 14) {
            CardVolume(lisere: true, verre: true)
                .frame(width: Self.cote, height: Self.cote)
                .flotte(phase: 0.0, periode: 5.6)
            CardSeances(lisere: true, verre: true,
                        chambreImposee: mois,
                        // ⚠️ **PAS DE PLAQUE.** La chambre ouverte fait
                        // tomber un noir à 93 % derrière l'encre — c'est
                        // l'arbitrage de lisibilité de la home (« le verre
                        // pour l'ambiance, le noir pour lire »), et c'est ce
                        // qui bouchait le Liquid Glass.
                        plaque: 0)
                .frame(width: Self.cote, height: Self.cote)
                .offset(y: Self.decale)
                .flotte(phase: 0.42, periode: 6.7)
        }
        .padding(.horizontal, PorteMesures.margeCote)
        .task {
            // Le mois s'ouvre après un souffle : on voit d'abord la semaine
            // (ce que la card EST), puis elle se déplie. Sans ce temps, la
            // cascade des points naît hors champ pendant le fondu de la page.
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 1.1)) { mois = 1 }
        }
    }
}

// MARK: - Le flottement

/// LE FLOTTEMENT DES DÉCORS (verdict 23-08 : « qu'ils flottent légèrement,
/// pour un aspect plus vivant »). Une dérive lente sur deux sinus désaccordés
/// — jamais un cercle, qui lit « manège » — d'amplitude minuscule : à ±4 pt on
/// ne voit pas l'objet bouger, on voit qu'il n'est pas mort.
///
/// ⚠️ **C'EST UN `ViewModifier`, ET C'EST LA RAISON D'ÊTRE DE LA FORME.**
/// `body(content:)` reçoit l'arbre DÉJÀ CONSTRUIT : la `TimelineView` ne
/// réévalue donc que l'`offset`, jamais les cards ni le bijou. Écrit à
/// l'endroit — une TimelineView autour de l'appel — chaque card se
/// reconstruirait trente fois par seconde (la loi payée d'ExercisesView).
///
/// ⚠️ Un `offset` est une TRANSLATION, pas un redimensionnement : les bounds
/// du verre ne bougent pas d'un pixel, donc le piège du « verre aux bounds
/// vivants » (blur plat définitif) ne peut pas mordre.
private struct Flotte: ViewModifier {
    /// Le déphasage : deux objets côte à côte ne doivent jamais monter
    /// ensemble, sinon c'est le plateau qui bouge, pas les objets.
    var phase: Double = 0
    var ampX: CGFloat = 2.0
    var ampY: CGFloat = 4.0
    var periode: Double = 6.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            // ⚠️ **30 Hz, ET LA MONTÉE À LA FRÉQUENCE DE L'ÉCRAN A ÉTÉ
            // ESSAYÉE PUIS RÉVOQUÉE À LA MESURE (26-08).**
            //
            // Verdict : « je veux garder le flottement, rends-le plus fluide,
            // ça lag de fou ». J'ai remplacé cet échantillonnage par une
            // animation DÉCLARATIVE (`repeatForever`), en pariant qu'une
            // animation confiée au serveur de rendu serait à la fois plus
            // lisse ET moins chère, puisque le corps de la vue cesse d'être
            // réévalué. **Le pari est faux, et le chiffre est sans appel :
            // la page 3 est tombée de 60,0 à 14,0 img/s** — exactement le
            // « 60 → 14 » que l'histoire de ce fichier annonçait déjà.
            //
            // LA LEÇON, et elle vaut pour tout le dépôt : **déplacer du verre
            // natif coûte PAR IMAGE, quel que soit QUI pilote le mouvement.**
            // Le verre re-capture son fond à chaque position — ici un fond
            // qui est une vidéo en train de jouer, le pire cas mesuré du
            // dépôt. Doubler la cadence du mouvement double la note. Ce n'est
            // donc pas la façon d'animer qu'il faut changer, c'est le fait
            // que LA VITRE BOUGE.
            //
            // ⚠️ Et le « saccadé » ne vient probablement PAS d'ici : à ±4 pt
            // sur 6 s, un pas de 1/30 s déplace **0,14 pt**, très en dessous
            // du seuil de perception. Le vrai suspect est que la page entière
            // perd des images sur l'appareil — le simulateur, lui, tenait 60.
            // La seule sortie qui garde le flottement ET la cadence est de
            // faire dériver le CONTENU en laissant la vitre immobile ; c'est
            // écrit au § 4 de tools/porte/PLAN-V7-DOUCEUR.md, et ça touche
            // `CardCorps`, partagé avec la home.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate / periode + phase
                let a = t * 2 * .pi
                content
                    // 0,63 sur l'axe X : un rapport IRRATIONNEL, pour que les
                    // deux axes ne se rejoignent jamais — la trajectoire ne se
                    // referme pas, elle dérive.
                    .offset(x: ampX * CGFloat(sin(a * 0.63)),
                            y: ampY * CGFloat(sin(a)))
            }
        }
    }
}

private extension View {
    func flotte(phase: Double = 0, ampX: CGFloat = 2.0,
                ampY: CGFloat = 4.0, periode: Double = 6.0) -> some View {
        modifier(Flotte(phase: phase, ampX: ampX, ampY: ampY,
                        periode: periode))
    }
}

// MARK: - La caresse

/// La lumière qui sort du doigt — le shader `porteCaresse` (les maths du
/// login, extraites de `bgAuroraLogin`), en couche additive au-dessus de la
/// page. Elle n'est MONTÉE que pendant une caresse (`etat.caresseVivante`) :
/// au repos, pas une passe, pas un pixel.
private struct PorteCaresseCouche: View {
    let etat: EtatPorte
    /// Le banc `-porteTrail` : six lueurs figées en travers de la page, la
    /// plus jeune en tête — l'âge fige la traîne au milieu de sa vie (les
    /// cotes exactes du banc du login).
    var bench = false

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900))
                // ⚠️ L'HÔTE EST NOIR OPAQUE, JAMAIS .clear (le `* color.a`
                // final annulerait tout — le piège payé de la gerbe), et le
                // plusLighter fait l'addition : noir additif = identité.
                Rectangle()
                    .fill(.black)
                    .colorEffect(ShaderLibrary.porteCaresse(
                        .float2(geo.size.width, geo.size.height), .float(t),
                        .floatArray(bench
                            ? Self.trailFige(geo.size)
                            : Self.triplets(de: etat.traces, a: tl.date))))
                    .blendMode(.plusLighter)
            }
        }
    }

    private static func trailFige(_ size: CGSize) -> [Float] {
        (0..<6).flatMap { i -> [Float] in
            let f = CGFloat(i)
            return [Float(size.width * (0.72 - 0.09 * f)),
                    Float(size.height * (0.36 + 0.05 * f + 0.008 * f * f)),
                    Float(0.06 + 0.13 * Double(i))]
        }
    }

    /// Les triplets (x, y, âge) du protocole du login — sentinelle comprise :
    /// un buffer vide planterait le `floatArray`.
    private static func triplets(de traces: [TouchTrace],
                                 a now: Date) -> [Float] {
        var arr: [Float] = []
        for tr in traces {
            let age = Float(now.timeIntervalSince(tr.born))
            if age < 1.4 {
                arr += [Float(tr.point.x), Float(tr.point.y), age]
            }
        }
        return arr.isEmpty ? [-4000, -4000, 9] : arr
    }
}

// MARK: - La révélation

private extension View {
    /// L'entrée d'un bloc de l'habillage : il monte de 26 pt en fondu, avec son
    /// retard propre — la cascade dans la nuit. (Le même geste que le
    /// formulaire de l'auth ; son `reveal` est privé à AuthView.swift.)
    /// ⚠️ **L'HABILLAGE NE CLAQUE PLUS, IL SE POSE** (26-08). Verdict : « tout
    /// est long à arriver alors que ça doit être MAJESTUEUX ».
    ///
    /// Ce qui se passait : neuf secondes où rien n'arrive, puis TOUT en moins
    /// d'une seconde — trois marches de 0,12 s sous un RESSORT qui dépasse et
    /// revient. Le dépôt a déjà écrit la loi ailleurs, mot pour mot : « un
    /// ressort dépasse et revient : sur un plan de cette lenteur c'est le seul
    /// geste qui pourrait encore faire cheap ».
    ///
    /// Désormais : une courbe qui DÉCÉLÈRE (jamais de rebond), presque deux
    /// fois plus longue, et une montée plus ample — un objet lourd se pose
    /// lentement, c'est ce qui fait la majesté. Les retards sont étalés au
    /// site d'appel, et l'habillage part AVANT la fin du film : il se fond
    /// dans sa dernière seconde au lieu de lui succéder.
    func reveal(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 34)
            .animation(.timingCurve(0.16, 0.84, 0.22, 1, duration: 1.15)
                .delay(delay), value: shown)
    }
}

#Preview {
    PorteEntree()
}
