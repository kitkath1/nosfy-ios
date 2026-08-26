import SwiftUI
import simd

// MARK: - LA LUNE DE SANG — le splash de la porte
//
// Jalon 4 de `tools/porte/PLAN-PORTE.md`. Trois états tenus, du plus clair au
// plus éteint, puis le noir — 4,45 s en tout. Le film d'arrivée de la porte
// commence au noir : la couture entre les deux est noir-sur-noir, donc
// introuvable (mesurée : luminance 0,00 sur les deux bords).
//
// ⚠️ CE TABLEAU EST LA PARTITION RÉELLE, pas celle d'un plan périmé — il
// s'était déjà dédit une fois (il décrivait encore la V1 sans plongée, en
// 3,40 s). Les instants se LISENT des statiques ci-dessous, ils ne se
// recopient pas.
//
//   0,00 → 0,45   NAISSANCE     la lueur minuscule au loin (night.x 0 → 1)
//   0,45 → 1,30   PLONGÉE       la caméra fond sur elle (z 0,32 → 1,20),
//                               le tube en veille, LA COMÈTE trace le croissant
//   1,30          LA POSE       coup de frein, surtension du néon, choc haptique
//   1,30 → 1,85   ÉTAT ①        halo ivoire large, tube or, étoiles
//   1,85 → 2,25   fondu         night.w 0 → 0,52
//   2,25 → 2,80   ÉTAT ②        halo orange serré, bandes ambre
//   2,80 → 3,20   fondu         night.w → 1,00 ; la braise s'allume (z 0,40)
//   3,20 → 3,75   ÉTAT ③        lune de sang : halo resserré, tube sang
//   3,75 → 4,45   EXTINCTION    l'implosion douce, tout meurt au noir
//
// ⚠️ 0,55 s PAR PALIER EST UN PLANCHER, PAS UN CONFORT : en dessous, l'œil ne
// lit plus trois états mais un dégradé continu. Si le verdict téléphone dit
// que ça défile, c'est l'EXTINCTION qu'on raccourcit, jamais les paliers —
// et c'est exactement ce qu'on a fait le 26-08 pour payer des fondus plus
// doux à durée totale constante (voir `fondu` et `extinction`).
//
// TOUT EST FONCTION PURE DU TEMPS — `LuneDeSangBeat.at(t:)` — jamais une
// animation d'état : la scène se rejoue à l'identique image par image, la
// condition pour la régler par captures (`-luneSangLab`, `-luneSangFreeze <t>`).
//
// LES TROIS ÉTATS NE SONT PAS PEINTS ICI : ce sont trois valeurs de l'uniform
// `night` du shader `logoMonolith`. Le sang vit sur `night.w` — son canal
// PROPRE depuis le découplage du 22-08 : sur l'ancien `night.y`, une lune
// rouge nette n'était pas exprimable, les nuages avalaient l'écran dès 0,80.
//
// LA CAMÉRA NE BOUGE PAS. Le plan-séquence de 13,95 s reste l'archive
// (`-moonSplashLab`) ; ici la lune est POSÉE, ce sont ses états qui voyagent.
// Une horloge, une image : la partition et le shader lisent le même instant
// (c'est pour ça qu'on appelle `MonolithCanvas`, nu, jamais `MonolithScene`
// qui porte sa propre TimelineView).

// MARK: - La partition

struct LuneDeSangBeat {
    var reveal: Float = 0
    var night: SIMD4<Float> = .zero
    var idleLife: Float = 0
    /// La caméra du shader : (cible x, cible y, zoom). C'est ELLE qui fait la
    /// plongée — jamais un scaleEffect, qui rastériserait les hairlines.
    var camera: SIMD3<Float> = SIMD3(0, 0, 1)
    /// (cine, boom, bgFade, cometHead). `boom` = la SURTENSION du néon à la
    /// pose (le shader multiplie l'énergie par 1 + 2,2·boom) ; `cometHead` =
    /// LA COMÈTE, en abscisse normalisée sur le contour — une sentinelle
    /// négative lui rend son rythme de croisière.
    var cineCtl: SIMD4<Float> = SIMD4(0, 0, 0, -1)
    /// LE LACET D'ARRIVÉE : la lune arrive DE BIAIS et pivote vers sa pose,
    /// en ressort qui dépasse d'un cheveu (l'école exacte de l'archive).
    var yaw: Float = 0

    // Les temps, en secondes. Les statiques sont la SEULE source des durées :
    // le `.task` de fin et l'haptique les lisent aussi — une durée écrite deux
    // fois finit par se dédire. (La partition V2 du 22-08 au soir : « pas
    // assez spectaculaire » → la plongée.)
    static let naissance = 0.45     // la lueur minuscule au loin
    static let plongee = 0.85       // la caméra fond sur elle
    static let palier = 0.55        // ⚠️ PLANCHER, jamais moins
    /// ⚠️ **0,40 ET NON 0,25 (26-08) — « c'est trop saccadé ».** À 0,25 s, la
    /// teinture bougeait de 0,52 : 2,1 par seconde en moyenne, 3,1 en pointe.
    /// À 0,40 la pointe tombe à 1,95, et le smootherstep de `fondant` enlève
    /// la cassure d'accélération qui restait aux deux bouts.
    static let fondu = 0.40
    /// ⚠️ **ET C'EST L'EXTINCTION QUI PAIE, PAS LES PALIERS.** La règle est
    /// écrite en tête de ce fichier et elle tient : les deux fondus allongés
    /// coûtent 0,30 s, l'extinction les rend (1,00 → 0,70). **Durée totale
    /// INCHANGÉE : 4,45 s.** On adoucit sans rallonger le lancement — et
    /// l'extinction est la seule partie du plan où il ne se passe plus rien
    /// qu'une lumière qui tombe vers un noir sur lequel le film enchaîne.
    static let extinction = 0.70

    /// Les zooms de la caméra : loin → posée → l'implosion rentre d'un cheveu.
    static let zoomLoin: Float = 0.32
    static let zoomPose: Float = 1.20
    static let zoomMort: Float = 1.26

    static var tPose: Double { naissance + plongee }      // 1,30 — le choc
    static var t1: Double { tPose }                       // début état ①
    static var t2: Double { t1 + palier + fondu }         // 2,10 — état ②
    static var t3: Double { t2 + palier + fondu }         // 2,90 — état ③
    static var tMort: Double { t3 + palier }              // 3,45
    static var total: Double { tMort + extinction }       // 4,45

    /// Les battements : FORT à la pose (la main reçoit le choc de l'arrivée),
    /// puis un par état.
    /// ⚠️ **PLUS JOUÉ DEPUIS LE 26-08** — gardé pour l'archive et pour le
    /// jour où l'on voudrait comparer. Voir `souffle`.
    static var battements: [(time: Double, fort: Bool)] {
        [(tPose, true), (t2, false), (t3, false)]
    }

    /// LE SOUFFLE HAPTIQUE — la courbe que la main suit, « rien n'est frappé ».
    ///
    /// Elle épouse la LUMIÈRE, pas la structure : elle monte pendant que la
    /// caméra plonge, culmine à la pose (0,62 — un sommet, pas un choc), puis
    /// s'infléchit doucement sur chaque état et meurt avec l'extinction.
    /// Aucun point ne monte ni ne descend assez vite pour se lire comme un
    /// coup — c'est la condition, et c'est ce qui la distingue de
    /// `battements`.
    static var souffle: [(t: Double, force: Float)] {
        [(0.00, 0.00),
         (naissance, 0.10),          // la lueur naît au loin
         (tPose - 0.20, 0.34),       // la plongée pousse
         (tPose, 0.62),              // LA POSE — le sommet
         (tPose + 0.40, 0.28),       // il retombe, il ne claque pas
         (t2, 0.38),                 // état ② : une inflexion
         (t3, 0.46),                 // état ③ : le sang pèse un peu plus
         (tMort, 0.26),
         (total, 0.00)]              // l'implosion emporte tout
    }

    private static func lisse(_ x: Double) -> Float {
        let c = min(max(x, 0), 1)
        return Float(c * c * (3 - 2 * c))
    }

    /// LE FONDU DES ÉTATS — et il n'est PAS `lisse`.
    ///
    /// Verdict 26-08 : « adoucir les transitions entre les différents états,
    /// c'est trop saccadé ». Deux causes, cumulées :
    ///
    /// 1. `lisse` est un smoothstep : sa dérivée PREMIÈRE s'annule aux deux
    ///    bouts, mais sa dérivée SECONDE y saute d'un coup. Sur une teinture
    ///    qui bascule de 0,52 en un quart de seconde, cette cassure
    ///    d'accélération est exactement ce que l'œil appelle « un à-coup » :
    ///    la couleur ne se met pas en route, elle PART.
    /// 2. Le fondu ne durait que 0,25 s — soit une vitesse moyenne de 2,1 par
    ///    seconde et une pointe à 3,1. C'est une bascule, pas un fondu.
    ///
    /// `fondant` est un smootherstep (quintique de Perlin) : dérivées
    /// première ET seconde nulles aux deux bouts. Rien ne démarre, rien ne
    /// s'arrête — ça FOND. Réservé aux fondus d'état (`night.w`, `night.z`) :
    /// la plongée, la pose et l'extinction gardent `lisse`, leur nervosité
    /// est voulue.
    private static func fondant(_ x: Double) -> Float {
        let c = min(max(x, 0), 1)
        return Float(c * c * c * (c * (c * 6 - 15) + 10))
    }

    /// LA PART DE COURANT — « les états, mais plus fondus, pas aussi coupés »
    /// (verdict 26-08).
    ///
    /// ⚠️ **CECI RÉVOQUE UNE LOI ÉCRITE EN TÊTE DE CE FICHIER**, et la
    /// révocation est délibérée : « 0,55 s par palier est un plancher : en
    /// dessous, l'œil ne lit plus trois états mais un dégradé continu. » Cette
    /// loi défendait la LISIBILITÉ des trois états. La demande vise la
    /// FLUIDITÉ — « comme un film, doux, mélodieux ». Les deux ne peuvent pas
    /// être maximales ensemble.
    ///
    /// Le compromis n'est PAS de raccourcir les paliers (ça, c'est toujours
    /// interdit) : c'est de leur enlever leur immobilité. La teinture est
    /// mélangée à une rampe continue qui traverse tout le plan, de sorte
    /// qu'elle **RALENTIT sur chaque état au lieu de s'y arrêter**. Les trois
    /// états restent lisibles par leur COULEUR (0 → 0,52 → 1,00, l'écart le
    /// plus large possible), plus par un arrêt du mouvement.
    ///
    /// 0 = les marches d'avant. 1 = une rampe droite, plus d'états du tout.
    /// 0,30 : mesuré comme le point où la vitesse ne tombe plus jamais à zéro
    /// tout en gardant trois plages nettement plus lentes que les fondus.
    static let courant: Float = 0.30

    /// La surtension de la pose : une décharge, pas un projecteur — montée en
    /// 60 ms, morte en 550 ms (la courbe exacte du boom de l'archive).
    private static func surtension(_ t: Double) -> Float {
        let d = Float(max(t - tPose, 0))
        return exp(-d / 0.55) * (1 - exp(-d / 0.06))
    }

    /// Un ressort amorti résolu à la main — il dépasse de 8 % puis revient.
    /// ⚠️ NORMALISÉ pour valoir 1 EXACTEMENT en p = 1 : la forme brute
    /// s'arrête à 0,99728, et ce demi-point de reliquat suffit à décaler la
    /// pose finale (la leçon payée du raccord de l'archive).
    private static let queueRessort: Float =
        exp(-6.0) * (cos(7.5) + (6.0 / 7.5) * sin(7.5))

    private static func ressort(_ p: Float) -> Float {
        if p >= 1 { return 1 }
        let x = max(p, 0)
        let brut = 1 - exp(-6 * x) * (cos(7.5 * x) + (6.0 / 7.5) * sin(7.5 * x))
        return brut / (1 - queueRessort)
    }

    static func at(_ t: Double) -> LuneDeSangBeat {
        var b = LuneDeSangBeat()
        // L'atmosphère (étoiles, halo de clair de lune) s'installe pendant la
        // naissance : c'est elle qui fait la NUIT, les états ne font que la
        // teinter.
        b.night.x = lisse(t / naissance)

        // LA CAMÉRA. Elle part à ×0,32 (la lune est une lueur minuscule) et
        // FOND sur elle en exponentielle p^1,6 — la courbe de la plongée de
        // l'archive : lente au départ, elle avale la fin. Le reveal suit la
        // course : la lune naît PENDANT qu'on l'approche, pas avant.
        // ⚠️ LE NÉON RESTE BAS PENDANT LA COURSE, ET C'EST TOUTE LA MISE EN
        // SCÈNE. Mesuré : à pleine puissance le tube sature à 254 et la
        // comète, qui sature au même niveau, DISPARAÎT dedans — elle courait
        // (point chaud déplacé de 57 px en 0,1 s) sans qu'on la voie. En
        // tenant le tube à 0,52, la comète devient la seule chose brillante :
        // c'est elle qui TRACE le croissant. Puis l'embrasement, à la pose.
        if t < naissance {
            b.camera.z = Self.zoomLoin
            b.reveal = 0.30 * b.night.x
        } else if t < tPose {
            let p = Float(lisse((t - naissance) / plongee))
            let e = pow(p, 1.6)
            b.camera.z = Self.zoomLoin
                + (Self.zoomPose - Self.zoomLoin) * e
            b.reveal = 0.30 + 0.22 * e          // le tube reste en veille
        } else {
            b.camera.z = Self.zoomPose
            // L'EMBRASEMENT : 0,52 → 1 en 0,30 s, sous la surtension. La
            // comète s'éteint pile là (§ cineCtl.w) — sa course meurt DANS
            // la lumière qu'elle a allumée.
            b.reveal = 0.52 + 0.48 * lisse((t - tPose) / 0.30)
        }

        // LA SURTENSION : le néon surtend sous le coup de frein de la pose.
        b.cineCtl.y = surtension(t)

        // LA COMÈTE — le levier de spectacle que le shader tenait en réserve
        // (verdict 23-08 : « encore plus spectaculaire »). Une décharge de
        // lumière court DANS le tube, tête nette et traîne derrière. Elle
        // fait UN TOUR ET DEMI pendant la plongée, accélérant en même temps
        // que la caméra (la même exponentielle p^1,6 — elle est portée par le
        // mouvement, elle ne le double pas), et s'arrête net à la pose : sa
        // course EST le coup de frein que la surtension fait claquer.
        // Sentinelle négative = pas de comète (le rythme de croisière du
        // shader ne doit pas s'inviter pendant les paliers).
        if t >= naissance * 0.5 && t < tPose {
            let q = Float(min(max((t - naissance * 0.5)
                                  / (tPose - naissance * 0.5), 0), 1))
            b.cineCtl.w = fmod(pow(q, 1.6) * 1.5, 1.0)
        } else if t >= tPose && t < tPose + 0.22 {
            // Elle s'éteint SUR la pose, pas avant : la tête reste plantée
            // à l'arrivée le temps que la surtension éclate.
            b.cineCtl.w = fmod(1.5, 1.0)
        } else {
            b.cineCtl.w = -1
        }

        // LE LACET : la lune arrive DE BIAIS (~12°) et pivote vers sa pose
        // pendant que la plongée finit — dépasse d'un cheveu, revient. Ce qui
        // rend le geste riche, ce ne sont pas les degrés : ce sont les
        // REFLETS qui balayent le verre pendant qu'elle tourne.
        b.yaw = 0.21 * (1 - ressort(Float(min(max(t / (tPose + 0.35), 0), 1))))

        // Le grésillement du néon posé : la lune ne doit jamais avoir l'air
        // ARRÊTÉE pendant les paliers.
        //
        // ⚠️ **LA MICRO-VIE PASSE PAR LES UNIFORMES QUI EXISTENT DÉJÀ**
        // (§5 du plan V7, salve 1 — « plus animé, plus de détail, genre 10
        // fois plus »). La règle du chantier est que tout détail doit être
        // peint dans une surface DÉJÀ payée : aucune couche de plus, aucune
        // horloge de plus, aucun shader à recompiler. `idleLife` pilote déjà
        // le grésillement du tube — on lui donne une respiration fine et
        // IRRÉGULIÈRE (trois sinus de périodes premières entre elles, donc
        // qui ne se rejoignent jamais) au lieu d'une valeur plate.
        // ⚠️ Ça reste une fonction PURE du temps : les captures de
        // `-luneSangFreeze` restent déterministes.
        let vie = 1
            + 0.16 * sin(t * 5.31)
            + 0.09 * sin(t * 11.70 + 1.7)
            + 0.05 * sin(t * 23.30 + 0.4)
        b.idleLife = lisse((t - tPose) / 0.3) * Float(vie)
        // ET LE HALO RESPIRE — très lentement, hors phase avec les états,
        // pour que la nuit elle-même ne soit jamais figée. ±3 % : on ne voit
        // pas l'atmosphère bouger, on voit qu'elle n'est pas morte.
        b.night.x *= Float(1 + 0.03 * sin(t * 1.63 + 0.9))

        // Le sang : deux marches lissées, tenues entre les fondus. Les
        // tremblements de l'agonie (drops, gasp) vivent DANS le shader sur
        // cette courbe — ils jouent tout seuls pendant les rampes.
        // LES MARCHES (ce qu'on avait) et LE COURANT (une seule rampe qui
        // traverse tout le plan), mélangés : voir `courant`.
        let marches = 0.52 * fondant((t - (t1 + palier)) / fondu)
                    + 0.48 * fondant((t - (t2 + palier)) / fondu)
        let flot = lisse((t - t1) / (tMort - t1))
        b.night.w = marches * (1 - courant) + flot * courant
        // La braise du contour s'allume avec le second fondu — même
        // traitement, sinon elle réintroduirait la marche qu'on vient
        // d'enlever, et c'est l'élément le plus visible des trois.
        let braiseMarche = fondant((t - (t2 + palier)) / fondu)
        let braiseFlot = lisse((t - (t2 - fondu)) / (tMort - t2 + fondu))
        b.night.z = 0.40 * (braiseMarche * (1 - courant)
                            + braiseFlot * courant)

        if t >= tMort {
            // L'IMPLOSION DOUCE : la lumière tombe PENDANT que la caméra
            // rentre d'un cheveu — la lune ne s'éteint pas, elle se referme.
            // La braise du contour meurt en dernier, comme sur l'éclipse.
            let a = (t - tMort) / extinction
            let chute = 1 - lisse(a / 0.8)
            b.reveal *= chute
            b.night.x *= chute
            b.idleLife *= chute
            b.night.z *= 1 - lisse((a - 0.25) / 0.75)
            b.camera.z = Self.zoomPose
                + (Self.zoomMort - Self.zoomPose) * lisse(a)
        }
        return b
    }
}

// MARK: - La vue

struct LuneDeSangView: View {
    var onFinish: () -> Void = {}

    /// L'horloge : posée SEULEMENT quand la LUT du croissant est prête —
    /// toucher `MoonSDF.image` sur le fil principal pendant la cuisson bloque
    /// et fait sauter le début du plan (la loi du grand splash).
    @State private var start: Date?
    @State private var finished = false

    /// `-luneSangFreeze <t>` fige la partition à l'instant t — la scène se
    /// règle par captures. ⚠️ Comme `-moonSplashFreeze`, le drapeau coupe le
    /// minuteur de fin : la porte ne s'ouvre plus que d'un tap. C'est voulu.
    private static let freeze: Double? = UserDefaults.standard
        .string(forKey: "luneSangFreeze").flatMap(Double.init)

    /// `-corbeauxEchelle <n>` : la taille de la volée, réglable au lancement.
    /// Cette lune-ci fait ~200 pt quand l'archive en faisait 800 : la volée se
    /// calibre à l'œil, sur l'appareil, pas au jugé dans le code.
    private static let corbeauxOff =
        CommandLine.arguments.contains("-corbeauxOff")

    /// ⚠️ **2,4 → 1,6 (26-08) : « plus petit ».** Le défaut de l'archive (1)
    /// était calé sur une lune PLEIN ÉCRAN ; 2,4 avait été trouvé pour cette
    /// lune-ci quand la volée était en ivoire et devait s'imposer. En noir et
    /// sur douze individus, la même taille ferait un vol de corbeaux au
    /// premier plan — l'effet que le fichier NightBirds décrit comme « un
    /// dessin animé ». Réglable au lancement : `-corbeauxEchelle <n>`.
    private static var echelleCorbeaux: CGFloat {
        CGFloat(UserDefaults.standard.string(forKey: "corbeauxEchelle")
            .flatMap(Double.init) ?? 1.6)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let size = CGSize(width: geo.size.width,
                              height: geo.size.height
                                  + geo.safeAreaInsets.top
                                  + geo.safeAreaInsets.bottom)
            ZStack {
                Color.black
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
                    let t = Self.freeze
                        ?? start.map { tl.date.timeIntervalSince($0) } ?? 0
                    let b = LuneDeSangBeat.at(reduceMotion
                                              ? LuneDeSangBeat.t3 : t)
                    // ⚠️ **LE `ZStack` EST OBLIGATOIRE, ET SON ABSENCE EST
                    // EXACTEMENT POURQUOI LES CORBEAUX AVAIENT DISPARU**
                    // (26-08). Le contenu de ce `TimelineView` était un
                    // TupleView nu — deux vues sans conteneur de disposition :
                    // le canvas du monolithe, puis la volée. Seule la PREMIÈRE
                    // était posée. Mesuré : zéro pixel rouge à l'écran sous
                    // `-corbeauxSonde`, alors que la partition place les six
                    // oiseaux au centre exact (x 118-228 pt, y 410-494 pt à
                    // t = 2,2 s). Ils n'étaient ni mal placés ni invisibles :
                    // ils n'étaient pas DESSINÉS.
                    ZStack {
                    // `soloNeon: 1` — LE PAVÉ N'EXISTE PAS : il n'y a que le
                    // croissant dans la nuit, comme sur la maquette (et comme
                    // la phase « nuit » de l'archive : solo 1 + night.x 1 =
                    // le néon seul sous le clair de lune). La caméra vient de
                    // la partition : c'est elle qui fait la plongée.
                    MonolithCanvas(size: size, t: Float(
                                       tl.date.timeIntervalSinceReferenceDate
                                           .truncatingRemainder(dividingBy: 900)),
                                   userYaw: b.yaw,
                                   reveal: b.reveal,
                                   camera: b.camera,
                                   cineCtl: b.cineCtl,
                                   soloNeon: 1,
                                   idleLife: b.idleLife,
                                   night: b.night)

                    // ⚠️ **LES CORBEAUX SONT RENDUS AU SPLASH** (26-08).
                    // Verdict : « il manque les corbeaux, cherche dans les
                    // commits ». Ils n'avaient pas été supprimés — ils sont
                    // partis SANS QUE PERSONNE NE LE DÉCIDE, le jour où le
                    // plan-séquence de 13,95 s (`MoonSplashView`) a cédé la
                    // place à la Lune de Sang : ils n'étaient montés que
                    // là-bas, et le fichier `NightBirds.swift` est resté
                    // intact dans le dossier, orphelin.
                    //
                    // Ils reprennent leur rôle d'origine à la lettre : six
                    // silhouettes NOIRES, très loin, en contre-jour — elles ne
                    // se voient que là où elles croisent la lueur de la lune.
                    // « Un corbeau de près est un dessin animé ; six
                    // battements d'ailes minuscules devant une lune, c'est du
                    // film muet. »
                    //
                    // ⚠️ La lune est AU CENTRE : la caméra de cette partition
                    // ne bouge que son `z` (le zoom), jamais sa cible — donc
                    // le centre de l'écran EST le centre de la lune, et il n'y
                    // a rien à recalculer.
                    //
                    // Ils partent 0,2 s AVANT la pose : le premier traverse
                    // pendant que le croissant s'allume, les derniers pendant
                    // les états tenus. La traversée dure ~3,4 s et l'écran
                    // meurt au noir à 4,45 s : la queue de la volée s'éteint
                    // avec le reste, exactement comme elle le faisait sous les
                    // voiles de l'archive.
                    // `-corbeauxOff` : la volée éteinte. C'est la SEULE
                    // mesure propre — deux captures qui ne diffèrent QUE par
                    // les oiseaux. (Les compter par leur couleur ne marche
                    // pas : la lune de SANG en porte, et le filtre l'attrape.)
                    if !reduceMotion, !Self.corbeauxOff {
                        // ⚠️ **LA VOLÉE EST RESSERRÉE — ×1,7 SUR L'ÂGE.**
                        // La partition d'origine étalait six départs sur 1,2 s
                        // pour une traversée de 3,4 s chacun : sur les 13,95 s
                        // du plan-séquence, la volée avait le temps de passer.
                        // Ici l'écran meurt à 4,45 s — sonde `-corbeauxSonde`
                        // (la volée peinte en ROUGE, parce que des silhouettes
                        // noires sur une nuit noire ne se prouvent pas à
                        // l'œil) : à mi-course, UN SEUL oiseau était à l'écran,
                        // et au-dessus de la lueur. Accélérer l'âge resserre
                        // les départs ET la traversée d'un seul coup, et les
                        // ailes battent d'autant plus vite — ce qui est juste,
                        // ce sont des oiseaux qui passent, pas qui planent.
                        // ⚠️ **×1,25 ET NON ×1,7** : la volée passait TROP
                        // VITE. Calculé sur la partition (6 trajectoires,
                        // écran 402 pt) : à ×1,7 il ne reste plus un seul
                        // oiseau en vol dès **t = 3,3 s**, alors que la lune
                        // ne meurt qu'à 3,45 et l'écran à 4,45 — la volée
                        // était partie avant la fin du plan. À ×1,25 elle
                        // tient jusqu'à ~3,8 s et s'éteint AVEC la scène,
                        // ce que le commentaire d'origine promettait déjà.
                        //     t=      1,3  1,8  2,3  2,8  3,3  3,8
                        //     ×1,70    2    6    6    6    0    0
                        //     ×1,25    2    6    6    6    6    4
                        let age = (t - LuneDeSangBeat.tPose + 0.35) * 1.25
                        if age >= 0 {
                            // ⚠️ **LE CANVAS EST UN COULOIR, PAS UN ÉCRAN —
                            // ET C'EST MESURÉ.** À douze individus en plein
                            // écran, la lune tombait à 43,5 / 41,1 / 30,4
                            // img/s là où elle tenait 60. Bissection à
                            // `-corbeauxOff` : la micro-vie était INNOCENTE
                            // (60 / 60 / 60 sans la volée), tout le coût
                            // était le `Canvas`.
                            //
                            // Un `Canvas` SwiftUI re-rasterise TOUTE sa
                            // surface à chaque image, qu'on y dessine six
                            // traits ou zéro. Or les chauves-souris tiennent
                            // dans une bande de 200 pt (`bande` −75…+20, plus
                            // le battement ±9 et l'envergure) : on rasterisait
                            // 874 pt de haut pour en peindre 200.
                            // La hauteur est donc CLOUÉE, et `moon` passe en
                            // coordonnées du couloir.
                            let couloir: CGFloat = 200
                            NightBirds(age: age,
                                       moon: CGPoint(x: size.width / 2,
                                                     y: couloir / 2),
                                       echelle: Self.echelleCorbeaux,
                                       // ⚠️ **NOIRES, ET C'EST LA CONSIGNE**
                                       // (verdict 26-08, répété). L'ivoire de
                                       // la veille est révoqué : ce sont des
                                       // ombres chinoises, pas des lucioles.
                                       //
                                       // Une silhouette n'existe que contre de
                                       // la lumière : elles ne se voient que
                                       // pendant leur traversée du tiers
                                       // central, ~1 s chacune (le profil
                                       // mesuré est sur `NightBirds.bande`).
                                       // D'où DOUZE : pour qu'à chaque instant
                                       // l'une d'elles soit dans la lueur.
                                       plumage: .black.opacity(0.88),
                                       // Elles s'éteignent avec la lune.
                                       lumiere: Double(b.reveal),
                                       forme: .chauveSouris,
                                       bande: -75 ... 20,
                                       // La volée s'épaissit (§5, salve 1) :
                                       // douze individus sur deux ou trois
                                       // plans, dans le MÊME Canvas — pas une
                                       // vue de plus, pas une horloge de plus.
                                       nombre: 12,
                                       profondeur: true)
                                .frame(width: size.width, height: couloir)
                                .allowsHitTesting(false)
                        }
                    }
                    }
                }
                // Le grain de la maison, à la dose du splash : les nappes
                // sombres bandent sur OLED.
                WoopGrain(density: 0.018, lightAlpha: 0.014, darkAlpha: 0.013)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        // La loi du splash : un tap termine à tout instant. Le callback fait
        // foi, jamais la durée nominale.
        .onTapGesture { finish(saute: true) }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        .task {
            RocketHaptics.shared.prepare()
            // ⚠️ **LE THÈME REVIENT (26-08), ET IL N'AVAIT JAMAIS ÉTÉ
            // SUPPRIMÉ.** Verdict : « le son de la lune de sang ! avant il y
            // avait quelque chose ! ». `MoonSplashTheme.m4a` et sa classe
            // `MoonTheme` sont intacts dans le dépôt depuis toujours — mais
            // `MoonSplashView` était son SEUL appelant, et le jour où cette
            // vue-ci est devenue le splash, le thème est devenu orphelin.
            // Le même sort que les corbeaux, à trois fichiers de distance.
            //
            // `LuneSangTheme` est son recut sur CETTE partition : l'impact du
            // thème tombe à 1,300 s, c'est-à-dire sur `tPose` au centième
            // (vérifié au RMS), et son geste final couvre l'extinction.
            // ⚠️ Muet sous `-luneSangFreeze` : une capture doit être
            // déterministe, et un son qui démarre sur une image figée n'a
            // aucun sens.
            if Self.freeze == nil { MoonTheme.shared.prepare("LuneSangTheme") }
            // La LUT se LIT du bundle (deux millisecondes) ; ce qui se chauffe
            // vraiment, c'est la compilation du shader. On attend quand même :
            // une horloge posée avant `isReady` mange le début du plan.
            // ⚠️ Le `try?` AVALE l'annulation : sur une vue démontée, un
            // `sleep` annulé revient immédiatement et la boucle tournerait à
            // CHAUD jusqu'à `isReady`. La garde rend l'attente annulable.
            while !MoonSDF.isReady {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(nanoseconds: 40_000_000)
            }
            guard Self.freeze == nil else { return }
            if reduceMotion {
                // La convention de la maison : reduceMotion réduit la
                // cérémonie à un fondu. Pas de thème non plus — il est écrit
                // POUR la cérémonie qu'on vient de supprimer.
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard !Task.isCancelled else { return }
                finish(saute: true)
                return
            }
            start = .now
            // ⚠️ LE SON ET L'HORLOGE PARTENT AU MÊME INSTANT, et c'est la
            // condition du calage : tout le recut est construit sur
            // « impact = tPose ». Un `play()` posé même 100 ms plus loin
            // décollerait le son de l'image.
            MoonTheme.shared.play()
            // LE SOUFFLE part D'UN BLOC au moteur — jamais cadencé par la
            // boucle d'affichage. Un seul événement continu qui suit la
            // lumière, plus les trois coups frappés d'avant.
            RocketHaptics.shared.respire(duree: LuneDeSangBeat.total,
                                         points: LuneDeSangBeat.souffle)
            try? await Task.sleep(nanoseconds:
                UInt64(LuneDeSangBeat.total * 1_000_000_000))
            // Une vue démontée ne déclare pas de fin : le callback appartient
            // à l'écran encore monté.
            guard !Task.isCancelled else { return }
            finish(saute: false)
        }
    }

    /// ⚠️ `saute` DISTINGUE LES DEUX FINS, et le thème en dépend.
    ///
    /// Le plan dure 4,45 s, le thème 5,506 : sa dernière seconde ring out
    /// EXPRÈS dans la couture noire, pendant que le film d'arrivée démarre —
    /// c'est ce qui relie les deux écrans par le son quand l'image, elle, est
    /// noire des deux côtés. Une fin naturelle ne doit donc RIEN couper.
    ///
    /// Un tap, lui, coupe : l'utilisatrice a demandé à passer, et le fondu de
    /// 0,35 s de `MoonTheme.stop()` existe précisément pour que ça ne claque
    /// pas.
    private func finish(saute: Bool) {
        guard !finished else { return }
        finished = true
        // ⚠️ À LA FIN NATURELLE ON NE COUPE RIEN. Le souffle haptique s'est
        // éteint tout seul (sa durée EST celle du plan) et le thème doit
        // continuer : sa dernière seconde est écrite pour ring out dans la
        // couture noire, pendant que le film d'arrivée démarre.
        // `stop(theme:)` existe pour ça — un `stop()` nu emporterait la queue.
        RocketHaptics.shared.stop(theme: saute)
        onFinish()
    }
}

// MARK: - Le banc (`-luneSangLab`)

/// La partition en boucle à la demande : elle joue, puis « Rejouer ».
/// `-luneSangFreeze <t>` fige un instant (le bouton ne sert alors à rien,
/// la vue figée EST la capture).
struct LuneSangLab: View {
    @State private var run = UUID()
    @State private var finie = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            LuneDeSangView {
                withAnimation(.easeOut(duration: 0.3)) { finie = true }
            }
            .id(run)
            if finie {
                Button("Rejouer") {
                    finie = false
                    run = UUID()
                }
                .font(.inter(14, .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 560)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    LuneDeSangView()
}
