import SwiftUI
import simd

// MARK: - Le splash : la lune en gros plan, puis le monolithe qui se pose
//
// Un plan-séquence de 11,4 s, en quatre temps :
//
//   0,0 → 1,0   L'ALLUMAGE. Noir. La caméra est déjà collée au tube — onze
//               fois la taille de la scène — et le néon naît sous nos yeux
//               pendant qu'elle pousse.
//   1,0 → 8,0   LE TRAVELLING. Le PAVÉ N'EXISTE PAS : il n'y a que le
//               croissant de néon, seul dans le noir. La comète part et la
//               caméra la suit sur tout le contour, en abscisse curviligne,
//               en reculant sans arrêt de ×11 à ×5,5. Elle lève le pied aux
//               quatre accidents de la courbe (deux cornes, deux crochets).
//   8,0 → 9,7   LE BOOM. Le tube surtend, la caméra décolle en arrière — vite
//               au départ, longuement amortie — et la PIERRE SE MATÉRIALISE
//               autour de la lumière, dans le flash qui couvre son apparition.
//   9,7 → 11,4  L'ENVOL. Il rapetisse en filant vers le haut-gauche pendant
//               que l'aurore de la connexion monte du noir, et se pose avec
//               un rebond court. À partir de là, le doigt le fait tourner.
//
// Le grondement haptique double la partition d'un bout à l'autre : voir
// RocketHaptics.swift. Il part d'un bloc au moteur, jamais image par image —
// une vibration cadencée par la boucle d'affichage tremblerait précisément
// quand le GPU peine, c'est-à-dire pendant le travelling.
//
// TOUT EST FONCTION PURE DU TEMPS — `MoonSplashBeat.at(t:)` —, jamais une
// animation d'état : la scène se rejoue à l'identique image par image, ce qui
// est la condition pour la régler par captures (le banc `-moonSplashLab`,
// et `-moonSplashFreeze <t>` pour figer un instant précis).
//
// LA CAMÉRA VIT DANS LE SHADER, pas dans SwiftUI. Un `scaleEffect` sur la
// scène rastériserait les hairlines et le dither — le fichier du monolithe le
// documente. Ici, `camera` = (cible, zoom) en points de SCÈNE : le shader
// divise son repère, et le tube, le filet, la flaque se re-rendent nets à
// n'importe quel grossissement.

// MARK: - La géométrie d'arrivée
//
/// Où le monolithe se pose, et à quelle taille. Une seule source de vérité :
/// la cinématique s'en sert pour viser, l'écran d'accueil pour l'afficher —
/// sans quoi le raccord entre les deux sauterait d'un cheveu, ce qui est
/// exactement ce qui se voit.
enum MoonLanding {
    /// Le grossissement final : la face de 152 pt tombe à 106 pt — un logo
    /// posé sur la page. À 0,62 (94 pt) l'objet se perdait dans la nuit du
    /// haut, qui est vaste ; il lui faut assez de présence pour tenir le
    /// coin gauche tout seul.
    static let zoom: Float = 0.70
    /// La demi-face nominale du monolithe (celle du banc `-logoLab`).
    static let faceR: Float = 76

    /// Le point d'arrivée du centre de l'objet : à gauche, dans la nuit qui
    /// occupe toute la moitié haute de l'aurore, bien au-dessus du titre.
    static func spot(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.315, y: size.height * 0.335)
    }

    /// Le centre du repère du shader (il place sa scène à 46 % de la hauteur).
    static func sceneCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.5, y: size.height * 0.46)
    }

    /// La cible de caméra qui amène le centre de l'objet sur `q`. Le shader
    /// pose `pC = (position − C)/zoom + cible` : l'objet, qui vit en pC = 0,
    /// se retrouve donc à l'écran en `C − cible·zoom`.
    static func cameraTarget(bringing q: CGPoint, at zoom: Float,
                             in size: CGSize) -> SIMD2<Float> {
        let c = sceneCenter(in: size)
        return SIMD2(Float(c.x - q.x) / zoom, Float(c.y - q.y) / zoom)
    }

    /// La zone qui capte le doigt une fois l'objet posé — son voisinage
    /// immédiat, pas tout l'écran : la caresse de l'aurore doit continuer
    /// de vivre partout ailleurs.
    static func hitRect(in size: CGSize) -> CGRect {
        let q = spot(in: size)
        let r = CGFloat(faceR * zoom) * 1.85
        return CGRect(x: q.x - r, y: q.y - r, width: r * 2, height: r * 2)
    }
}

// MARK: - La partition

struct MoonSplashBeat {
    var camera: SIMD3<Float> = SIMD3(0, 0, 1)
    var cineCtl: SIMD4<Float> = SIMD4(0, 0, 0, -1)
    var reveal: Float = 1
    /// L'aurore de la connexion, sous le monolithe.
    var aurora: Double = 0
    var edgeFade: Float = 0
    /// 1 = le croissant seul dans le noir ; 0 = le monolithe entier.
    var solo: Float = 0
    /// Le plan se rend-il à demi-résolution ? Vrai tant qu'il n'y a que du
    /// néon flou à l'écran — voir `MoonSplashView`.
    var lowRes: Bool = false
    /// La vie de l'objet POSÉ : flottement lent et grésillement rare
    /// (cf. MonolithCanvas). Elle s'allume quand l'objet touche.
    var idleLife: Float = 0

    // Les temps de la partition. LE TRAVELLING EST LONG, ET C'EST LE SUJET :
    // sept secondes pour un contour de 429 points de scène, soit 61 pt/s —
    // un glissement, pas une course. À cinq secondes le plan « allait quelque
    // part » ; à sept, il RESPIRE, et l'œil a le temps de suivre la comète le
    // long du tube au lieu de la voir passer. Bénéfice second : l'image avance
    // de 6,2 pt entre deux vues, pour un tube qui en fait 15 de large — le
    // recouvrement devient confortable, et le plan cesse d'être saccadé même
    // si la cadence flanche.
    static let ignite = 1.00
    static let travel = 9.00
    static let boom = 1.70
    static let flight = 1.70
    static var total: Double { ignite + travel + boom + flight }

    private static var tTravel: Double { ignite }
    private static var tBoom: Double { ignite + travel }
    private static var tFlight: Double { ignite + travel + boom }

    /// L'ALLUMAGE est très près : ×11, on lit la matière du tube — la paroi
    /// dorée, le fil de plasma, le grain du dépoli.
    static let closeZoom: Float = 10

    /// LE TRAVELLING RECULE À ×6,5, ET C'EST UN CHOIX DE MISE EN SCÈNE, PAS
    /// UNE ÉCONOMIE. À ×11 le cadre montre 36 points de scène de large sur un
    /// croissant qui en fait 108 : on voit un trait lumineux magnifique, mais
    /// on ne reconnaît PAS la lune, et la promesse du plan — « la comète
    /// parcourt les lignes de la lune » — ne se lit plus. À ×6,5 le cadre en
    /// montre 60 sur 108 : la courbe se lit, le tube fait encore 15 pt de
    /// large, et le sujet redevient identifiable.
    /// ON RESTE PRÈS. Le plan recule de ×10 à ×7,5 seulement : à ×5,5 on
    /// prenait du recul, mais on perdait l'intimité de la matière — et
    /// c'était payé en vitesse de défilement. À ×7,5 sur neuf secondes,
    /// l'image n'avance plus que de 5,4 points entre deux vues pour un tube
    /// qui en fait 17 de large : trois fois plus de recouvrement qu'il n'en
    /// faut, et le sujet reste gros dans le cadre.
    static let travelZoom: Float = 7.5

    /// LE CADRAGE EST DÉCENTRÉ, en fractions d'écran. Le point suivi ne se
    /// pose pas au milieu : il vit dans le tiers gauche, un peu au-dessus de
    /// l'axe — la place qu'un objet occupe dans un plan de keynote, où le
    /// centre géométrique est laissé au vide.
    static let framing = CGPoint(x: 0.355, y: 0.435)

    /// LE TRAVELLING SE JOUE À 60 IMAGES/S, ET CE N'EST PAS UN LUXE. Le
    /// contour mesure 3,977 uc, soit 429 points de scène ; le parcourir en
    /// 5 s fait 86 pt/s de scène. Rapporté à la largeur du tube — 2,25 pt —,
    /// l'image avance de 2,86 largeurs de tube par image à 30 Hz : le sujet
    /// ne se recouvre plus d'une image à l'autre et le trait STROBOSCOPE au
    /// lieu de filer. Le grossissement n'y change RIEN, puisqu'il multiplie
    /// des deux côtés — c'est la cadence, et elle seule, qui décide. À 60 Hz
    /// on tombe à 1,43 largeur : le tube se recouvre, le mouvement se lit.
    static let travelFPS: Double = 60

    /// L'AVANCE DE LA COMÈTE — le cœur du plan, et ce qui manquait. Collée au
    /// point suivi, elle reste IMMOBILE DANS LE CADRE : la caméra la suit, donc
    /// seul le fond défile et on ne la voit jamais courir. Il faut que la
    /// caméra LA LAISSE PARTIR puis la rattrape.
    ///
    /// C'est la CAMÉRA qui respire, jamais la comète : celle-ci avance de façon
    /// strictement monotone (une comète ne recule pas). Le retard de la caméra
    /// oscille de 0 à 0,048 d'abscisse — soit jusqu'à 130 points d'écran à
    /// ×6,5 —, trois fois sur la durée du travelling. La comète prend donc
    /// visiblement le large dans le cadre, file le long du tube, et le
    /// mouvement se reprend.
    ///
    /// La dérivée du retard (0,048 × 3 × 2π × 0,5 ≈ 0,45) reste sous la vitesse
    /// de base du plan (≈ 1 à 1,5) : la caméra ralentit, elle ne recule jamais.
    private static let cometLead: Float = 0.05

    /// `shaderClock` : l'horloge que l'hôte donne au shader (temps absolu
    /// modulo 900 s, ou la valeur figée). Elle sert à RENDRE LA COMÈTE au
    /// bon moment — voir le raccord dans la phase du boom.
    /// `landsOnAurora` : la cinématique découvre-t-elle l'aurore de la
    /// connexion en se posant ? Vrai au banc, où l'objet arrive sur l'écran
    /// orange. Faux dans l'app réelle, dont l'écran d'authentification n'est
    /// pas celui-là : là, l'objet vole sur du noir et la page suit.
    static func at(_ t: Double, size: CGSize,
                   shaderClock: Float = 0,
                   landsOnAurora: Bool = true) -> MoonSplashBeat {
        var b = MoonSplashBeat()

        // ---- L'abscisse de la caméra sur le contour, et son grossissement.
        let sCam: Float
        let zoom: Float
        var target: SIMD2<Float>
        var cine: Float = 1
        /// La part de décentrage appliquée. Elle se résorbe pendant le boom :
        /// l'objet doit finir CENTRÉ avant de partir se poser, sinon le recul
        /// se ferait en biais et le vol partirait de travers.
        var frameW: Float = 1

        if t < tBoom {
            // Allumage puis travelling : un seul mouvement continu le long du
            // contour. Pendant l'allumage la caméra pousse déjà (×15 → ×13) :
            // une image qui naît immobile est une image morte.
            let pIgnite = clamp01(t / ignite)
            b.reveal = Float(smoothstep(pIgnite))
            let pTravel = clamp01((t - tTravel) / travel)
            // La caméra avance à vitesse RIGOUREUSEMENT constante.
            sCam = arc(at: eased(Float(pTravel)))
            // La comète va un peu plus vite — d'un facteur constant, jamais
            // d'une oscillation : elle DÉRIVE régulièrement vers l'avant du
            // cadre au lieu d'y osciller. Sur les sept secondes elle prend
            // 0,05 d'abscisse, soit 137 points d'écran : on la voit
            // franchement gagner du terrain, sans que rien ne change de
            // régime.
            let sComet = eased(Float(pTravel)) * (1 + cometLead)
            // L'allumage POUSSE : on entre dans le tube, on ne s'en retire
            // pas. (Il partait de ×15 pour finir à ×13 — un travelling
            // arrière de 13 % sous un commentaire qui promettait l'inverse.)
            // Puis le plan RECULE vers ×6,5, où la lune redevient lisible.
            // UN SEUL MOUVEMENT, du début à la fin. Le plan s'ouvre collé à la
            // matière (×11) et recule SANS ARRÊT jusqu'à ×5,5, où le croissant
            // tient presque entier dans le cadre. Pas de palier, pas de
            // respiration sinusoïdale : un travelling arrière continu est ce
            // qu'il y a de plus calme à regarder, et le boom n'a plus qu'à
            // prolonger un geste déjà commencé.
            // Le recul est LINÉAIRE lui aussi — mais en OCTAVES, pas en
            // points : un travelling arrière se perçoit multiplicativement,
            // et interpoler le grossissement à plat donnerait un mouvement qui
            // ralentit visiblement vers la fin.
            zoom = t < tTravel
                ? exp(mix(log(closeZoom * 0.82), log(closeZoom),
                          Float(smoothstep(pIgnite))))
                : exp(mix(log(closeZoom), log(travelZoom), Float(pTravel)))
            target = sceneTarget(arc: sCam)
            b.cineCtl.w = MoonPath.angle(at: sComet)
            b.solo = 1        // le pavé n'existe pas encore
            b.lowRes = true   // il n'y a que du néon flou à dessiner
        } else if t < tFlight {
            // ---- LE BOOM. Le recul est multiplicatif — un travelling arrière
            // se lit en octaves, pas en points —, donc l'interpolation se
            // fait sur le LOGARITHME du grossissement. L'amortissement est
            // franc au départ et long à la fin : c'est ce profil-là qui rend
            // le mouvement puissant sans le rendre brusque.
            let p = clamp01((t - tBoom) / boom)
            let e = 1 - pow(1 - Float(p), 3.0)
            sCam = arc(at: 1)
            zoom = exp(mix(log(closeZoom), 0, e))
            target = sceneTarget(arc: sCam) * (1 - e)
            cine = 1 - e
            frameW = 1 - e
            // La surtension : une décharge brève, pas un projecteur.
            b.cineCtl.y = surge(t)
            // LA RÉVÉLATION. La pierre se matérialise autour de la lumière
            // pendant que le plan recule — et elle le fait DANS LA DÉCHARGE,
            // dont le pic tombe à 0,14 s : le flash couvre l'apparition, si
            // bien qu'on ne voit pas un objet « s'allumer », on découvre qu'il
            // était là. C'est tout l'intérêt d'avoir caché le pavé jusqu'ici.
            b.solo = 1 - Float(smoothstep(clamp01((t - tBoom) / 0.55)))
            // LA COMÈTE NE SE TÉLÉPORTE PAS. Rendre la main d'un coup — en
            // repassant la sentinelle −1 — la ferait sauter à l'autre bout du
            // tube d'une image à l'autre, et à ×13 ce saut fait la moitié de
            // l'écran. On la ramène donc en douceur, par le plus court chemin
            // angulaire, vers la place que sa loi propre lui donne à cet
            // instant : à la fin du boom les deux valeurs coïncident, et la
            // sentinelle peut être rendue sans que rien ne bouge.
            b.cineCtl.w = lerpAngle(MoonPath.angle(at: 1 + cometLead),
                                    naturalHead(shaderClock), e)
        } else {
            // ---- L'ENVOL. Il rapetisse en filant vers son point de pose, et
            // arrive avec un rebond court — un objet qui se pose, pas un
            // calque qui s'aligne.
            let p = clamp01((t - tFlight) / flight)
            let e = spring(Float(p))
            sCam = 1
            zoom = exp(mix(0, log(MoonLanding.zoom), e))
            let c = MoonLanding.sceneCenter(in: size)
            let land = MoonLanding.spot(in: size)
            let q = CGPoint(x: CGFloat(mix(Float(c.x), Float(land.x), e)),
                            y: CGFloat(mix(Float(c.y), Float(land.y), e)))
            target = MoonLanding.cameraTarget(bringing: q, at: zoom, in: size)
            cine = 0
            frameW = 0        // la cible du vol place déjà l'objet elle-même
            // La surtension du boom SURVIT au raccord : à la dernière image du
            // boom elle vaut encore 0,054, ce qui pèse 12 % sur le gain du
            // néon. La couper net ferait clignoter tout l'objet d'une image à
            // l'autre — elle continue donc de mourir dans l'envol.
            b.cineCtl.y = surge(t)
            // L'aurore monte pendant qu'il vole, et le fond du shader s'ouvre
            // en même temps : la lueur du monolithe devient additive sur elle.
            // Sans écran d'accueil orange derrière, on garde le fond noir du
            // shader : ouvrir sur du vide ne ferait qu'éteindre la flaque.
            let a = clamp01((t - tFlight) / (flight * 0.75))
            if landsOnAurora {
                b.aurora = smoothstep(a)
                b.cineCtl.z = Float(smoothstep(a))
            }
            b.edgeFade = Float(smoothstep(a))
            // La vie vient quand l'objet TOUCHE : un objet qui flotterait
            // déjà en vol raconterait deux choses à la fois.
            b.idleLife = Float(smoothstep(clamp01((t - tFlight - flight * 0.3)
                                                  / (flight * 0.6))))
        }

        // Le décentrage. Le shader pose l'objet là où `pC` s'annule, c'est-à-dire
        // en (0,5 w ; 0,46 h) ; pour l'amener ailleurs à l'écran il suffit de
        // décaler la CIBLE de l'écart voulu, ramené en points de scène — donc
        // divisé par le grossissement.
        if frameW > 0 {
            let c = MoonLanding.sceneCenter(in: size)
            let dx = Float(framing.x * size.width - c.x)
            let dy = Float(framing.y * size.height - c.y)
            target -= SIMD2(dx, dy) * (frameW / zoom)
        }

        b.camera = SIMD3(target.x, target.y, zoom)
        b.cineCtl.x = cine
        return b
    }

    // MARK: Les instants où la caméra passe les accidents

    /// L'instant de la partition où la caméra atteint l'abscisse `s`. Sert à
    /// caler les retours haptiques sur les quatre virages de la courbe : la
    /// main doit sentir ce que l'œil voit, à l'image près.
    ///
    /// On inverse la chaîne complète : `s` → la progression brute de la table
    /// de vitesse, puis l'inverse analytique du smoothstep, puis le temps.
    static func time(atArc s: Float) -> Double {
        // Position de `s` dans la table (elle est croissante).
        var lo = 0, hi = warp.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if warp[mid] <= s { lo = mid } else { hi = mid }
        }
        let span = max(warp[hi] - warp[lo], 1e-9)
        let x = (Float(lo) + (s - warp[lo]) / span) / Float(warp.count - 1)
        // Inverse de smoothstep : p = 1/2 − sin(asin(1 − 2x)/3).
        let clamped = min(max(x, 0), 1)
        let p = 0.5 - sin(asin(1 - 2 * clamped) / 3)
        return tTravel + Double(min(max(p, 0), 1)) * travel
    }

    /// Les quatre rendez-vous du travelling, dans l'ordre : les deux crochets
    /// (touche brève) et les deux cornes (touche plus ferme — la tangente y
    /// tourne de 160°, c'est le vrai virage).
    static var beats: [(time: Double, hard: Bool)] {
        let L = MoonPath.landmarks
        return [(time(atArc: L.kink1), false),
                (time(atArc: L.horn1), true),
                (time(atArc: L.kink2), false),
                (time(atArc: L.horn2), true)].sorted { $0.time < $1.time }
    }

    /// L'état d'arrivée, figé — ce que voit `reduceMotion`, et ce que doit
    /// afficher l'écran d'accueil pour que le raccord soit invisible.
    static func landed(size: CGSize) -> MoonSplashBeat {
        at(total, size: size)
    }

    // MARK: Le profil de vitesse

    /// L'ease-in-out du plan. Sa DÉRIVÉE DOIT ÊTRE NULLE EN 0 : la caméra est
    /// strictement immobile en panoramique pendant tout l'allumage, et un
    /// démarrage à vitesse non nulle ferait sauter le défilement de zéro à
    /// mille points par seconde en une image. Le mélange tiède qui traînait
    /// ici (0,35·smoothstep + 0,65·p) partait justement à 0,65× — c'est le
    /// coup de fouet qu'on entendait au raccord. Le smoothstep pur pointe à
    /// 1,5× la vitesse moyenne, ce que les ralentissements de la courbe
    /// absorbent sans peine.
    /// LE PLAN EST LINÉAIRE, point. Pas de rampe, pas de ralenti, pas de
    /// rubato : la caméra part à sa vitesse de croisière et n'en change plus
    /// jusqu'au boom. Toute inflexion que j'avais écrite — rampes d'entrée et
    /// de sortie, freinages dans les virages, houle de la comète — se lisait
    /// comme un défaut de MACHINE et non comme une intention. Un travelling
    /// qui ne change jamais de régime ne peut pas donner l'impression de
    /// hoqueter.
    private static let ramp: Float = 0.18

    /// LE PROFIL D'UN VRAI TRAVELLING : on lance, ON TIENT, on arrête. La
    /// vitesse monte en douceur sur les 18 premiers pour cent, reste
    /// RIGOUREUSEMENT CONSTANTE sur les deux tiers du plan, puis redescend de
    /// même. C'est ça, « d'une traite » — et c'est exactement ce qu'un
    /// smoothstep ne sait pas faire : il n'a pas de palier, il accélère
    /// jusqu'au milieu et freine ensuite, si bien que le plan a un ventre
    /// qu'on voit passer. Les deux dérivées restent nulles aux extrémités
    /// (la caméra est immobile pendant l'allumage, elle doit partir de zéro),
    /// et la vitesse de croisière ne vaut que 1,22× la moyenne.
    ///
    /// Intégrale de la rampe en smoothstep : ∫₀¹ u²(3−2u) du = ½, d'où une
    /// course totale de (1 − r) et la normalisation ci-dessous.
    private static func eased(_ p: Float) -> Float {
        min(max(p, 0), 1)
    }

    /// Progression [0,1] → abscisse curviligne [0,1]. La caméra RALENTIT aux
    /// quatre endroits que la courbe rend difficiles : les deux cornes, où la
    /// tangente saute de 160°, et les deux crochets, où le rayon de courbure
    /// tombe sous 0,013 uc. Sans ce plan de vitesse, une abscisse uniforme
    /// ferait passer les virages aussi vite que les longues courbes molles —
    /// et c'est précisément là que l'œil veut s'arrêter.
    private static let warp: [Float] = {
        let L = MoonPath.landmarks
        // D'UNE TRAITE. Les ralentissements étaient à 2,7 et 1,2 : la caméra
        // tombait à moins du tiers de sa vitesse aux cornes puis repartait —
        // quatre coups de frein en sept secondes. C'est ce qui se lisait comme
        // un bug « au début, au niveau de la queue » : la queue du croissant
        // EST la corne à s = 0,2032, atteinte à 2,5 s, où le plan s'arrêtait
        // presque. Un travelling premium est ÉGAL ; l'expression vient de la
        // courbe qu'on suit, pas d'un rubato de caméra. 0,45 et 0,20 laissent
        // une inflexion perceptible (la vitesse ne descend plus qu'à 0,69 aux
        // cornes) sans jamais donner l'impression d'un arrêt. Les fenêtres
        // s'élargissent aussi : un freinage court est un à-coup, un freinage
        // long est une respiration.
        // AUCUN RALENTISSEMENT. Ce qu'il fallait arrondir, ce n'était pas la
        // VITESSE aux virages, c'était le CHEMIN — voir `smoothTargets`.
        // Freiner devant un coin ne supprime pas le coin, ça le souligne.
        let stops: [(c: Float, amp: Float, w: Float)] = []
        _ = L
        // Coût cumulé du parcours : ∫ (1 + Σ ralentissements) ds.
        let n = 2048
        var cost = [Float](repeating: 0, count: n + 1)
        var acc: Float = 0
        for i in 0...n {
            let s = Float(i) / Float(n)
            var w: Float = 1
            for st in stops {
                var d = abs(s - st.c)
                d = min(d, 1 - d)          // le contour est fermé
                let x = d / st.w
                w += st.amp * exp(-x * x)
            }
            if i > 0 { acc += w / Float(n) }
            cost[i] = acc
        }
        // Inversion : une table progression → abscisse, à pas constant.
        let m = 1024
        var table = [Float](repeating: 0, count: m + 1)
        var j = 0
        for i in 0...m {
            let want = Float(i) / Float(m) * acc
            while j < n, cost[j + 1] < want { j += 1 }
            let span = max(cost[j + 1] - cost[j], 1e-9)
            let f = min(max((want - cost[j]) / span, 0), 1)
            table[i] = (Float(j) + f) / Float(n)
        }
        return table
    }()

    private static func arc(at p: Float) -> Float {
        let x = min(max(p, 0), 1) * Float(warp.count - 1)
        let i = Int(x)
        if i >= warp.count - 1 { return warp[warp.count - 1] }
        return mix(warp[i], warp[i + 1], x - Float(i))
    }

    /// L'abscisse du contour → le point de SCÈNE que la caméra doit viser.
    /// Le lacet et le tangage sont ceux du mode cinéma (micro-balancements et
    /// gyroscope amortis) : sans cette immobilité, la cible calculée ici et
    /// l'objet dessiné là-bas divergeraient d'un point ou deux, et à ×13 un
    /// point de scène fait treize points d'écran.
    private static func rawSceneTarget(arc s: Float) -> SIMD2<Float> {
        let p = MoonPath.sample(at: s).position
        let f = MoonPath.facePoint(p, faceR: MoonLanding.faceR,
                                   moonPlace: SIMD3(0.5, 0.485, 0.71))
        return MoonPath.scenePoint(face: f, yaw: 0.2450, pitch: -0.0698,
                                   faceR: MoonLanding.faceR)
    }

    /// LE CHEMIN DE LA CAMÉRA, LISSÉ — et c'est LA correction qui manquait.
    ///
    /// Le contour du croissant a deux COINS : aux cornes, la tangente tourne
    /// de 160° en un point. Une caméra qui suit ce contour au trait près voit
    /// donc sa direction de déplacement s'inverser d'une image à l'autre. À
    /// vitesse constante c'est un COUP DE FOUET ; en freinant, c'est un ARRÊT.
    /// Aucune cadence d'affichage ne rattrape un chemin qui a des coins — on
    /// peut monter à mille images par seconde, le pli reste un pli.
    ///
    /// Un chariot de cinéma ne colle jamais au sujet au millimètre : il GLISSE
    /// et coupe les angles, le sujet dérive un peu dans le cadre aux virages,
    /// et c'est exactement ce qui rend le mouvement soyeux. On convolue donc
    /// le chemin par une gaussienne d'écart-type 0,022 d'abscisse — 9 points
    /// de scène, soit 52 points d'écran à ×5,5. Aux cornes, la caméra passe
    /// au large et le tube vient lui rendre visite ; ailleurs (les raccords
    /// sont quasi G1, moins de 5° de virage) elle reste sur le tracé au point
    /// près.
    ///
    /// Le noyau est CIRCULAIRE : le contour est fermé, il n'y a pas de bord.
    private static let smoothTargets: [SIMD2<Float>] = {
        let n = 1024
        let sigma: Float = 0.022
        var raw = [SIMD2<Float>](repeating: .zero, count: n)
        for i in 0..<n { raw[i] = rawSceneTarget(arc: Float(i) / Float(n)) }

        let half = Int((sigma * 3 * Float(n)).rounded())
        var w = [Float](repeating: 0, count: 2 * half + 1)
        var wsum: Float = 0
        for k in -half...half {
            let x = Float(k) / Float(n) / sigma
            let g = exp(-0.5 * x * x)
            w[k + half] = g
            wsum += g
        }

        var out = [SIMD2<Float>](repeating: .zero, count: n)
        for i in 0..<n {
            var acc = SIMD2<Float>.zero
            for k in -half...half {
                acc += raw[((i + k) % n + n) % n] * w[k + half]
            }
            out[i] = acc / wsum
        }
        return out
    }()

    private static func sceneTarget(arc s: Float) -> SIMD2<Float> {
        let n = smoothTargets.count
        let x = (s - s.rounded(.down)) * Float(n)
        let i = Int(x) % n
        let j = (i + 1) % n
        let f = x - x.rounded(.down)
        return smoothTargets[i] + (smoothTargets[j] - smoothTargets[i]) * f
    }

    // MARK: Petites fonctions

    private static func clamp01(_ x: Double) -> Double { min(max(x, 0), 1) }
    private static func smoothstep(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    private static func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }

    /// La place de la comète quand elle vit sa vie : soixante tours par boucle
    /// de 900 s, soit quinze secondes le tour — la loi écrite dans le shader,
    /// qu'il faut rejouer ici à l'identique pour pouvoir lui rendre la main
    /// sans à-coup.
    private static func naturalHead(_ clock: Float) -> Float {
        let h = clock * 60 / 900
        return h - h.rounded(.down)
    }

    /// Interpolation d'angles sur le cercle : par le plus court chemin, pas à
    /// travers tout le tour. Sans ça, passer de 0,98 à 0,02 ferait reculer la
    /// comète sur 96 % du croissant au lieu d'avancer de 4 %.
    private static func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
        var d = b - a
        d -= (d + 0.5).rounded(.down)
        let r = a + d * t
        return r - r.rounded(.down)
    }

    /// La surtension du boom : une décharge, pas un projecteur. Montée en
    /// 60 ms, mort en 550 ms. Fonction du temps ABSOLU de la partition, pour
    /// qu'elle traverse le raccord boom → envol sans marche.
    private static func surge(_ t: Double) -> Float {
        let d = Float(max(t - tBoom, 0))
        return exp(-d / 0.55) * (1 - exp(-d / 0.06))
    }

    /// Un ressort amorti résolu à la main : il dépasse de 8 % (exp(−ζπ/ω) avec
    /// ζ = 6 et ω = 7,5) à 0,42 de sa course, puis revient. Résolu, jamais
    /// intégré — la partition doit rester une fonction du temps.
    ///
    /// NORMALISÉ pour valoir 1 EXACTEMENT en p = 1 : la forme brute s'arrête à
    /// 0,99728, et ce demi-point de reliquat suffisait à décaler la dernière
    /// image du splash de l'objet que l'écran d'accueil dessine ensuite — au
    /// raccord précis qu'on veut invisible.
    private static let springTail: Float =
        exp(-6.0) * (cos(7.5) + (6.0 / 7.5) * sin(7.5))

    private static func spring(_ p: Float) -> Float {
        if p >= 1 { return 1 }
        let raw = 1 - exp(-6.0 * p) * (cos(7.5 * p) + (6.0 / 7.5) * sin(7.5 * p))
        return raw / (1 - springTail)
    }

    /// L'instant où l'objet TOUCHE — la première fois que le ressort atteint
    /// sa cible, avant de la dépasser : tan(ωx) = −ζ/ω donne x = 0,299 de la
    /// course. C'est là que la vibration doit tomber, pas à la fin du plan.
    static var touchdown: Double { tFlight + flight * 0.299 }
}

// MARK: - La vue

struct MoonSplashView: View {
    /// La cinématique découvre-t-elle l'aurore de la connexion en se posant ?
    /// Au banc, oui : c'est l'écran d'arrivée. Dans l'app réelle, l'écran qui
    /// suit le splash est l'authentification — un tout autre fond —, alors
    /// l'objet se pose sur du noir et la page prend le relais.
    /// (Déclaré AVANT `onFinish` : l'init mémberwise suit l'ordre des
    /// propriétés, et la closure finale doit rester la dernière.)
    var landsOnAurora: Bool = true
    var onFinish: () -> Void = {}

    /// `-moonSplashFreeze <t>` fige la partition à t secondes.
    private static let freeze: Double? = UserDefaults.standard
        .string(forKey: "moonSplashFreeze").flatMap(Double.init)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var finished = false
    /// La cinématique ne commence QUE quand la LUT est cuite et le shader
    /// compilé. Démarrer avant, c'est offrir sa première seconde à un fil
    /// principal bloqué — et repartir ensuite là où l'horloge murale est
    /// arrivée, donc en sautant le début du plan.
    @State private var armed = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Color.black.ignoresSafeArea()

                TimelineView(.animation(minimumInterval: 1.0 / MoonSplashBeat.travelFPS,
                                        paused: reduceMotion || !armed)) { tl in
                    let t = Self.freeze
                        ?? (reduceMotion ? MoonSplashBeat.total
                                         : (armed ? tl.date.timeIntervalSince(start) : 0))
                    // L'horloge du shader, calculée ICI pour que la partition
                    // puisse rendre la comète exactement là où la loi du
                    // shader la mettra ensuite.
                    let clock = Self.freeze.map { Float(120 + $0) }
                        ?? Float(tl.date.timeIntervalSinceReferenceDate
                            .truncatingRemainder(dividingBy: 900))
                    let b = MoonSplashBeat.at(t, size: size,
                                              shaderClock: clock,
                                              landsOnAurora: landsOnAurora)
                    ZStack {
                        // L'aurore de la connexion, qui monte sous l'objet.
                        if b.aurora > 0.001 {
                            AuroraLoginBackground()
                                .ignoresSafeArea()
                                .opacity(b.aurora)
                                .allowsHitTesting(false)
                        }
                        // Quand la partition est figée, l'horloge du shader
                        // DOIT l'être aussi : la respiration du néon, le
                        // grain du dépoli et la dérive des accents vivent sur
                        // `t`, et sans ça deux captures du même instant ne se
                        // ressembleraient pas. La base 120 s est arbitraire ;
                        // ce qui compte est qu'elle soit stable et que deux
                        // instants différents montrent des phases différentes.
                        // UNE SEULE HORLOGE POUR TOUT LE PLAN. La scène du banc
                        // porte sa propre `TimelineView` ; l'imbriquer ici en
                        // ferait deux, qui tiqueraient chacune de leur côté —
                        // la caméra calculée à un instant, le shader dessiné à
                        // un autre. Personne n'est en retard, et pourtant le
                        // plan avance par à-coups. On dessine donc la toile
                        // nue, cadencée par la seule horloge du splash.
                        // LE TRAVELLING SE REND À DEMI-RÉSOLUTION, et il n'y
                        // perd rien : tant que le pavé n'existe pas, il n'y a
                        // pas un seul détail fin à l'écran — le tube fait 37
                        // pixels de large à ×5,5 sur une dalle 3x, et le fil
                        // de plasma, qui est ce qu'il y a de plus mince dans
                        // toute la scène, en fait encore 9. À demi-résolution
                        // ils tombent à 18 et 4,7 : largement au-dessus du
                        // seuil où quoi que ce soit se met à créneler. On
                        // divise le nombre de pixels par QUATRE.
                        //
                        // Le grossissement doit suivre la taille du tampon,
                        // sinon on verrait deux fois plus de scène : le shader
                        // pose `pC = (position − C)/zoom`, et `position` est
                        // désormais en coordonnées de tampon. Tout le reste du
                        // cadrage est en FRACTIONS de la taille, donc invariant.
                        //
                        // On repasse en pleine résolution au boom, à l'instant
                        // précis où la pierre apparaît — le flash de la
                        // décharge couvre la bascule —, parce que le monolithe,
                        // lui, porte des traits d'un pixel.
                        let px: CGFloat = b.lowRes ? 0.5 : 1
                        let buf = CGSize(width: size.width * px,
                                         height: size.height * px)
                        // LA TOILE N'EXISTE PAS TANT QUE LE DÉCOR N'EST PAS
                        // PRÊT. Le garde `armed` ne suffisait pas : la toile
                        // était CONSTRUITE au premier passage du corps, donc
                        // elle touchait `MoonSDF.image` — et le fil principal
                        // entrait dans son verrou — avant même que `.task` ait
                        // eu la parole. Suspendre l'horloge n'empêche pas
                        // d'évaluer le contenu une première fois.
                        if armed || Self.freeze != nil {
                        MonolithCanvas(size: buf, t: clock,
                                       reveal: b.reveal,
                                       faceR: MoonLanding.faceR,
                                       camera: SIMD3(b.camera.x, b.camera.y,
                                                     b.camera.z * Float(px)),
                                       cineCtl: b.cineCtl,
                                       edgeFade: b.edgeFade,
                                       soloNeon: b.solo,
                                       idleLife: b.idleLife)
                            .frame(width: buf.width, height: buf.height)
                            .drawingGroup()
                            .scaleEffect(1 / px, anchor: .topLeading)
                            .frame(width: size.width, height: size.height,
                                   alignment: .topLeading)
                            .ignoresSafeArea()
                        }
                    }
                }

                // Le grain de la maison, MOITIÉ DOSE : le shader dithère déjà
                // lui-même, la leçon du banc du monolithe vaut ici aussi.
                WoopGrain(density: 0.018, lightAlpha: 0.014, darkAlpha: 0.013)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.dark)
        // On peut toujours passer : un splash qu'on ne peut pas couper est
        // une punition, pas une entrée.
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        // Les retours tombent sur l'image, pas à côté : mêmes horaires que la
        // partition (le mécanisme du splash bouteille).
        // Les retours ne sont PAS pilotés image par image : le motif complet
        // part d'un bloc au moteur haptique, qui tient sa propre horloge. Un
        // grondement cadencé par la boucle d'affichage tremblerait à chaque
        // fois que le GPU prend du retard — c'est-à-dire exactement pendant le
        // travelling, là où il doit être le plus régulier.
        .onDisappear { RocketHaptics.shared.stop() }
        .task {
            // LE MOTEUR HAPTIQUE D'ABORD : démarrer un CHHapticEngine coûte
            // quelques dizaines de millisecondes, et on ne les paie pas sur
            // la première image du plan.
            RocketHaptics.shared.prepare()
            MoonTheme.shared.prepare()
            guard Self.freeze == nil else { return }
            if reduceMotion {
                try? await Task.sleep(for: .seconds(1.2))
                finish(); return
            }
            // ON N'OUVRE PAS LE RIDEAU AVANT QUE LE DÉCOR SOIT PRÊT. Tant que
            // la LUT cuit et que le shader se compile, l'écran reste noir et
            // l'horloge n'a pas démarré — c'est du noir, exactement ce que la
            // première seconde du plan montre de toute façon. Sans cette
            // garde, la première image bloquait le fil principal puis le plan
            // reprenait là où le temps était arrivé : il SAUTAIT son début.
            while !MoonSDF.isReady {
                try? await Task.sleep(for: .milliseconds(16))
                if Task.isCancelled { return }
            }
            start = Date()
            armed = true
            // L'image, le grondement et la musique partent SUR LA MÊME LIGNE.
            MoonTheme.shared.play()
            RocketHaptics.shared.launch(ignite: MoonSplashBeat.ignite,
                                        travel: MoonSplashBeat.travel,
                                        boom: MoonSplashBeat.boom,
                                        flight: MoonSplashBeat.flight,
                                        beats: MoonSplashBeat.beats)
            // Une seule attente : la fin du plan. Tout le rythme haptique
            // est parti d'un bloc au moteur, il n'a plus besoin d'être
            // réveillé ici. Le garde d'annulation reste : passer le splash
            // d'un toucher doit arrêter la séquence, pas la laisser courir.
            func wait(until when: Double) async -> Bool {
                let left = when - Date().timeIntervalSince(start)
                if left > 0 { try? await Task.sleep(for: .seconds(left)) }
                return !Task.isCancelled
            }
            guard await wait(until: MoonSplashBeat.total) else { return }
            finish()
        }
    }

    private func finish() {
        RocketHaptics.shared.stop()
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

// MARK: - Le monolithe posé

/// Ce que l'écran d'accueil affiche une fois la cinématique finie : le MÊME
/// rendu que sa dernière image — même grossissement, même place —, mais rendu
/// à la main et non plus par la partition. Le fond du shader est ouvert
/// (`bgFade`), donc seul le corps du pavé occulte : la flaque, le halo et le
/// filet passent en additif sur l'aurore.
struct LandedMonolithView: View {
    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let aim = MoonLanding.cameraTarget(
                bringing: MoonLanding.spot(in: size),
                at: MoonLanding.zoom, in: size)
            // `revealOverride: 1` est OBLIGATOIRE : sans lui, la scène relance
            // sa rampe d'allumage de 2 s à sa naissance — donc le monolithe
            // arriverait ÉTEINT au raccord précis que la cinématique passe
            // 1,7 s à rendre invisible.
            MonolithScene(faceR: MoonLanding.faceR,
                          camera: SIMD3(aim.x, aim.y, MoonLanding.zoom),
                          cineCtl: SIMD4(0, 0, 1, -1),
                          edgeFade: 1,
                          revealOverride: 1,
                          hitArea: MoonLanding.hitRect(in: size),
                          idleLife: 1)
        }
        .ignoresSafeArea()
    }
}

#Preview { MoonSplashView() }
#Preview("Figé — le travelling") {
    MoonSplashView()
}
