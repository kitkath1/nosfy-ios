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
    /// Posé par la racine quand le bouton est touché (la cérémonie de sortie,
    /// jalon 5).
    var cineStart: Date? = nil
    /// Le FILM D'ARRIVÉE joue : la page naît nue (flamme éteinte, texte, dots
    /// et bouton absents), le film se déroule dans le header, puis tout se pose
    /// en cascade. La racine le passera selon `woop.porteVue` (jalon 6) ; le
    /// banc l'allume par `-porteArrivee`.
    var arrivee: Bool = PorteEntree.porteArrivee

    /// La partition de l'arrivée, en secondes depuis l'apparition : le
    /// fichier V3 fait **274** images à 30 img/s — fenêtre 1,20 s de la
    /// source, ralenti ×1,35, et un serrage 1,16 → 1,00 CUIT par-dessus
    /// (verdict 23-08 : « encore plus spectaculaire »).
    /// ⚠️ La constante suit le FICHIER (`ffprobe -count_frames`), jamais le
    /// calcul : `minterpolate` ne rend pas exactement le compte théorique.
    private static let arriveeT: Double = 274.0 / 30.0            // 9,133
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
                PorteFlamme(largeur: W)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .offset(y: Self.flammeBasBanc)
                    // Pendant l'arrivée, la flamme n'existe pas encore : elle
                    // s'allume à T − 1,2 s, en 0,8 s — le feu prend AVANT que
                    // le texte se pose, c'est lui qui annonce la page.
                    .opacity(flammeAllumee ? 1 : 0)

                // ② LE HEADER — la vidéo, plein bord, sous l'encoche, pilotée
                // par `p` : le croisé pair/impair du § 4.3 du plan. En mode
                // arrivée, le créneau pair de la page 0 porte le FILM.
                PorteHeader(etat: etat, arrivee: arrivee,
                            largeur: W, hauteur: hHeader)

                // ③ LE CONTENU — les textes qui défilent, les dots, le bouton.
                contenu(W: W, H: H, hHeader: hHeader, encartBas: encartBas)

                // ④ LA SORTIE — « LA FLAMME EMBRASE » (§ 7 du plan, tranché
                // 22-08). Trois rampes sur la MÊME horloge, en fonction pure
                // du temps : le header meurt par le haut (un MASQUE, jamais
                // une frame animée), le foyer de la flamme enfle, l'habillage
                // s'en va. La coupe à 2,10 s appartient à la racine, sous le
                // nuage de braises — rien ici ne la connaît.
                if let sortie {
                    PorteSortie(start: sortie, largeur: W, hauteur: H,
                                hHeader: hHeader)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.arriveeT) {
                    withAnimation(.easeOut(duration: 0.4)) { habille = true }
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
            .reveal(habille, delay: 0.12)

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
            DiamondPrimaryButton(title: "SE CONNECTER", glyph: "apple.logo") {
                // Le banc `-porteSortie` joue la cérémonie ici ; en production
                // c'est la racine qui la déclenche (et qui coupe à 2,10 s).
                if Self.porteSortie && cineLocal == nil { cineLocal = .now }
                onConnect("")
            }
            .padding(.horizontal, PorteMesures.margeCote)
            .padding(.bottom, PorteMesures.piedBouton + encartBas)
            .reveal(habille, delay: 0.24)
            // ⚠️ UNE OPACITÉ NULLE RESTE TAPPABLE. Pendant le film, le bouton
            // est invisible mais son rectangle existe : un tap dans sa zone
            // déclencherait la CÉRÉMONIE DE SORTIE en plein film d'arrivée, au
            // lieu du saut. Le doigt ne touche que ce qui est posé.
            .allowsHitTesting(habille)
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
        // LA PARALLAXE (V2) : le poignet (SkyMotion, ±6 pt — la dérive de
        // caméra de la maison, recentrage 15 s) + le doigt (±6 pt, ressort au
        // lâcher), sommés puis bornés à la marge. reduceMotion tue les deux —
        // la double garde de l'école SkyMotion (le moteur refuse déjà de
        // démarrer, mais un autre écran a pu le lancer).
        let tilt = reduceMotion ? CGVector.zero : SkyMotion.shared.tilt
        let doigt = reduceMotion ? .zero : etat.parallaxeDoigt
        let par = CGSize(
            width: max(-Self.margePar, min(Self.margePar,
                tilt.dx * 6 + doigt.width * 0.6)),
            height: max(-Self.margePar, min(Self.margePar,
                tilt.dy * 6 + doigt.height * 0.6)))
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
            .overlay { PorteDecors(etat: etat, largeur: largeur,
                                   hauteur: hauteur) }
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
        if page.id == 0 && arrivee && !etat.arriveeFinie {
            // LE FILM D'ARRIVÉE — le master joué une fois, puis la boucle qui
            // prend le relais à l'image de raccord. Il EST le contenu du
            // créneau pair : la règle pair/impair le protège comme n'importe
            // quelle vidéo, et le démonte au même instant sûr.
            // ⚠️ Le raccord 178@30 est IMPRIMÉ par `recuit_porte.sh` (il le
            // calcule : total − 96). Le script et cette ligne changent
            // ENSEMBLE — un recut qui déplace la fin sans qu'on relise ici
            // casserait le seul raccord qui doit rester invisible.
            ReelPorte(master: "onb-arrivee", boucle: "onb-lune-loop",
                      imageRaccord: 178, baseTemps: 30,
                      pose: "onb-arrivee-poster",
                      poseBoucle: "onb-lune-loop-poster",
                      largeur: wPar, hauteur: hPar)
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

/// Le master joué UNE fois, et la boucle qui prend le relais à l'image de
/// raccord. C'est la mécanique éprouvée de `StoryReel` (StoryVideo.swift:41),
/// réécrite pour deux raisons qui ne se contournent pas : `StoryReel` code sa
/// base de temps à 24 en dur (nos fichiers sont à 30 — l'image 60 y deviendrait
/// la 75) et son débit à 1,25 (le nôtre est 1,0 : les fichiers sortent à
/// 30 img/s, DEUX battements pleins à 60 Hz, le battement 3:2 n'existe pas).
///
/// Les lois recopiées de l'original, aucune n'est décorative :
///  · LA BOUCLE D'ABORD, montée et amorcée avant que le master parte — elle
///    doit être à sa première image quand le relais tombe ;
///  · `preroll` ATTACHÉ à une observation de `.status` — appelé avant
///    `readyToPlay` il lève une exception et TUE l'app (payé le 21-08, et nous
///    sommes sur l'écran de lancement) ;
///  · L'ÉCHANGE EST SEC, jamais un fondu : les deux couches montrent la même
///    image (la première de la boucle EST l'image 60 du master, écart mesuré
///    0,42/255), donc un échange en une frame est invisible par construction —
///    un fondu croisé, lui, composerait contre du noir pendant que la couche
///    entrante n'a pas encore d'image ;
///  · LE MASTER EST DÉMONTÉ 0,6 s après le relais : un lecteur en pause reste
///    un décodeur vivant ;
///  · l'image de pose SOUS les lecteurs — le trou du bouclage (1 à 3 images à
///    chaque tour d'`AVPlayerLooper`) tombe sur elle, jamais sur du noir.
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

private struct ReelPorte: View {
    let master: String
    let boucle: String
    /// L'image de raccord, dans la base de temps du fichier.
    let imageRaccord: Int64
    let baseTemps: Int32
    /// ⚠️ **DEUX FILETS, PAS UN** — le bug des « petits écrans noirs » (payé
    /// 22-08 au soir, diagnostic mesuré). `AVPlayerLooper` vide sa couche 1 à
    /// 3 images À CHAQUE TOUR de boucle ; le trou tombe sur la pose. Avec une
    /// seule pose — celle du master, qui commence au NOIR (luminance 0,00) —
    /// chaque tour clignotait noir, pile à l'instant où le ping-pong inverse
    /// son sens : « ça bouge un peu et ça montre des petits écrans noirs ».
    /// La loi de StoryReel : un filet PAR fichier, commuté par `onLoop` — le
    /// trou montre alors la première image de la boucle, c'est-à-dire
    /// exactement ce qu'on devait voir.
    let pose: String
    let poseBoucle: String
    let largeur: CGFloat
    let hauteur: CGFloat

    @State private var cine: AVPlayer?
    @State private var loop: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var loopReady: NSKeyValueObservation?
    @State private var handoff: Any?
    @State private var retour: NSObjectProtocol?
    @State private var onLoop = false

    var body: some View {
        ZStack {
            Image(onLoop ? poseBoucle : pose)
                .resizable()
                .aspectRatio(contentMode: .fill)
            if let cine {
                ReelHote(player: cine)
                    .opacity(onLoop ? 0 : 1)
            }
            if let loop {
                ReelHote(player: loop)
                    .opacity(onLoop ? 1 : 0)
            }
        }
        .frame(width: largeur, height: hauteur)
        .clipped()
        .onAppear(perform: demarre)
        .onDisappear(perform: demonte)
    }

    private func demarre() {
        guard cine == nil,
              let urlM = Bundle.main.url(forResource: master,
                                         withExtension: "mp4"),
              let urlB = Bundle.main.url(forResource: boucle,
                                         withExtension: "mp4") else { return }

        // La boucle, prête avant le départ du master.
        let q = AVQueuePlayer()
        q.isMuted = true
        q.automaticallyWaitsToMinimizeStalling = false
        looper = AVPlayerLooper(player: q, templateItem: AVPlayerItem(url: urlB))
        loopReady = q.observe(\.status, options: [.initial, .new]) { p, _ in
            guard p.status == .readyToPlay else { return }
            p.preroll(atRate: 1) { _ in }
        }
        loop = q

        let p = AVPlayer(playerItem: AVPlayerItem(url: urlM))
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        p.actionAtItemEnd = .pause
        cine = p

        handoff = p.addBoundaryTimeObserver(
            forTimes: [NSValue(time: CMTime(value: imageRaccord,
                                            timescale: baseTemps))],
            queue: .main) { [weak p] in
                loop?.play()
                // Les 50 ms laissent au décodeur le temps de présenter sa
                // première image ; se tromper d'une image ne coûte rien, elles
                // sont identiques.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    onLoop = true
                    p?.pause()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if let handoff { cine?.removeTimeObserver(handoff) }
                    handoff = nil
                    cine?.replaceCurrentItem(with: nil)
                    cine = nil
                }
            }

        // LA REPRISE APRÈS L'ARRIÈRE-PLAN — la loi de CalqueVideo, qu'une
        // première version avait perdue : sans elle, une notification pendant
        // le film laissait une image FIGÉE pour toujours. On ne relance que la
        // couche VIVANTE : réveiller la boucle avant le relais l'avancerait en
        // douce, et le raccord sauterait.
        retour = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { _ in
                if onLoop { loop?.play() } else { cine?.play() }
            }

        p.play()
    }

    private func demonte() {
        if let handoff { cine?.removeTimeObserver(handoff) }
        handoff = nil
        if let retour { NotificationCenter.default.removeObserver(retour) }
        retour = nil
        loopReady?.invalidate(); loopReady = nil
        cine?.pause(); cine?.replaceCurrentItem(with: nil); cine = nil
        loop?.pause(); looper?.disableLooping(); looper = nil; loop = nil
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
private struct PorteSortie: View {
    let start: Date
    let largeur: CGFloat
    let hauteur: CGFloat
    let hHeader: CGFloat

    private func lisse(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(start)
            let rideau = lisse(t / 1.45)
            let foyer = lisse(t / 1.95)
            Color.clear
                // LE RIDEAU — collé au bord haut, il grandit vers le bas.
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.black)
                        .frame(width: largeur,
                               height: max(hHeader * rideau, 1))
                        .opacity(rideau > 0 ? 1 : 0)
                }
                // LE FOYER — ancré au bord bas ; son rayon vertical grandit.
                .overlay(alignment: .bottom) {
                    EllipticalGradient(
                        colors: [Feu.lit.opacity(0.12 + 0.24 * foyer), .clear],
                        center: UnitPoint(x: 0.5, y: 1.0),
                        endRadiusFraction: 0.5)
                        .frame(width: largeur * 1.4,
                               height: 260 + 480 * foyer)
                        .blendMode(.plusLighter)
                }
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
    let largeur: CGFloat
    let hauteur: CGFloat

    /// La poignée du manège — persistante : c'est par elle que la pose se
    /// rejoue (`coordinator.rejoueLaPose()`).
    @State private var manegeHandle = BoosterHandle()
    @State private var dernierePose = Date.distantPast

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
            naisManegeApres(1.2)
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
            if p < 0.02 { naisManegeApres(1.2) }
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
            // ⚠️ **12 Hz, PAS 30 — ET C'EST CE QUI REND LA FLUIDITÉ.**
            // Un verre qui BOUGE force la recapture de son fond à chaque
            // déplacement : mesuré, la page 3 passait de **60 à 14 img/s** le
            // jour où le flottement est arrivé. Ce n'est pas le flottement qui
            // est cher, c'est sa CADENCE — à 30 Hz on demandait trente
            // recaptures par seconde du composite vidéo, pour une dérive de
            // 4 pt sur 6 s. C'est exactement le précédent du liseré de
            // `CardCorps` (WidgetsCards.swift:236) : « une dérive de 3° sur
            // 9 s n'a aucun besoin de 60 images par seconde ».
            TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { tl in
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
    func reveal(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 26)
            .animation(.spring(response: 0.65, dampingFraction: 0.85)
                .delay(delay), value: shown)
    }
}

#Preview {
    PorteEntree()
}
