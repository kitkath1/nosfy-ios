import SwiftUI
import SwiftData
import AVFoundation

// MARK: - LA HOME v2 « CHAMBRE NOIRE » — JALON 1 : LA LUMIÈRE SEULE
//
// Le plan complet : `tools/home-v2/PLAN-HOME-V2.md`. La v1 (aurore + carte
// obsidienne) n'est pas touchée : elle vit toujours dans `HomeAuroraView`, et
// son archive est dans `tools/home-v1-archive/`.
//
// Ce jalon ne livre QU'UNE chose, et c'est volontaire : le noir, et le rasant
// de lumière qui entre par le haut-gauche. Pas de phrase, pas de points, pas
// de lune, pas de mur. On ne juge qu'une question — **est-ce que la lumière
// est belle, et assez rare ?** Si elle ne l'est pas, tout ce qui se poserait
// dessus serait faux.
//
// LE FOND A CHANGÉ LE 21-08 (plan §9) : la page vit sur LA GRANDE CARD VIDÉO
// (`GrandeCardVideo`, plus bas). Le rasant ci-dessous est ARCHIVÉ, rejouable :
//   `-fondRasant`           la chambre noire du jalon 1 reprend la page
//
// LES BANCS, cumulables :
//   `-homeV2`               la page (les valeurs retenues)
//   `-rasantLab`            + la console, onglet lumière
//   `-phraseLab`            + la console, onglet phrase
//   `-rasantFreeze <t>`     fige l'horloge du fond (deux captures comparables :
//                           sans ça, tout diff mesure le temps qui passe)
//   `-rasantAmp <v>`        force le niveau de la lumière (A/B sans doigt)
//   `-noGrain`              retire `WoopGrain` — le seul calque plein écran
//   `-isoRasant`            le rasant SEUL (ni poussières ni grain, barre de
//                           statut cachée) : l'état que mesure
//                           `tools/home-v2/mesure_rasant.py`
//   `-phraseFige <p>`       fige l'arrivée de la phrase à cet avancement
//   `-phraseRejoue`         rejoue l'arrivée en boucle (toutes les 3,4 s)

/// L'horloge du banc. Les respirations et l'air dérivent : deux captures du
/// « même » réglage ne le sont jamais tant que le temps court.
enum RasantHorloge {
    static let freeze: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-rasantFreeze"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return v
    }()

    static func t(_ date: Date) -> Double {
        freeze ?? date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: 900)
    }

    /// L'ATTRIBUTION : le rasant SEUL. Ni poussières, ni grain, ni barre de
    /// statut — **et pas la phrase non plus**. Le drapeau vit ici, et pas dans
    /// une seule vue, parce que « seul » se décide à l'échelle de la PAGE :
    /// mesuré depuis le fond uniquement, la sonde prenait le blanc du texte
    /// pour un sommet de halo à 254 (le même piège que l'heure, un étage plus
    /// haut).
    static let iso = CommandLine.arguments.contains("-isoRasant")
}

// MARK: - Les réglages

/// Tout le rasant est ici, rien n'est en dur dans la vue : le banc les fouette
/// au doigt et la valeur retenue devient le défaut du composant (la loi de
/// `JewelParams` et de `PlayParams`).
///
/// Les longueurs sont en LARGEURS D'ÉCRAN, jamais en points : sur un 402 pt,
/// 0,10 vaut 40 pt — et la géométrie survit au changement d'appareil.
struct RasantParams: Equatable {
    /// La lampe, HORS CADRE : (−40, +30) pt sur un écran de 402. Elle n'est
    /// pas dans le coin, elle est DERRIÈRE le coin — c'est ce qui fait qu'on
    /// voit une lumière et jamais sa source.
    var srcX: Double = -0.10
    var srcY: Double = 0.060
    /// Le rayon LE LONG du faisceau…
    ///
    /// Premier jeu mesuré (1,05 / 0,50 / 52°) : la flaque mourait à y ≈ 210 pt
    /// et se lisait comme une TACHE dans le coin, pas comme une lumière qui
    /// entre. Deuxième (1,25 / 0,60 / 55°) : la bonne taille, mais l'axe à 55°
    /// faisait couler la lumière jusqu'à y ≈ 410 pt — c'est-à-dire DANS le
    /// mur des séances, qui doit rester noir puisque c'est sa propre lampe
    /// (le drag) qui l'éclairera. L'axe est donc rentré à 32° : la flaque
    /// couvre la zone de la PHRASE (x ≤ 281, y ≤ 279 pt) et meurt avant le
    /// mur. Chiffres dérivés du seuil visible du champ à support compact
    /// (L≈8 vers 81 % de l'ellipse pour un exposant de 2,1), jamais devinés.
    var along: Double = 1.10
    /// …et EN TRAVERS. Le rapport des deux EST le rasant : à 1/1 c'est une
    /// tache ronde, à 1/2 c'est une lumière qui coule.
    var across: Double = 0.62
    /// L'axe, en degrés : du coin haut-gauche vers le bas-droit.
    var angle: Double = 32
    /// Le sommet. Cible mesurée : L ≈ 112 sur 255 (la v1 monte à 200 sur 40 %
    /// de l'écran — c'est ce chiffre-là que la doctrine divise par deux).
    ///
    /// ⚠️ Le sommet du CHAMP n'est pas à l'écran (la lampe est hors cadre) :
    /// ce qu'on mesure, c'est le plus clair pixel VISIBLE, sur le bord gauche
    /// vers y ≈ 60 pt. À 0,46 il valait 78 — d'où 0,66. Et il se mesure sur
    /// `-isoRasant` **barre de statut cachée** : sinon la sonde prend l'heure
    /// en blanc pur pour le sommet du halo (piège payé au premier tour, elle
    /// annonçait 108 quand le champ plafonnait à 78). À 0,66 la sonde a rendu
    /// 118,8 : 0,62 pose le sommet à 112 pile.
    var amp: Double = 0.62
    /// La raideur de l'extinction. Haut = un cœur large et une lisière
    /// courte ; bas = une flaque molle qui remplit tout son ellipse. À 2,4 la
    /// lisière se lisait comme le BORD d'une tache ; 2,1 rend le dégradé plus
    /// long, et c'est la longueur du dégradé qui fait le luxe.
    var expo: Double = 2.1
    /// Les deux respirations (±5 %, périodes 37 s et 23 s).
    var souffle: Double = 1.0
    /// La dose de braise. À 0, la lumière reste blanc-chaud et la page perd son
    /// rappel d'orange au repos. À fond (verdict du 20-08 : « encore plus
    /// d'orange ») — et c'est la RAMPE du shader, élargie aux demi-teintes,
    /// qui fait que cet orange se voit au lieu de mourir dans les ombres.
    var braise: Double = 1.0
    /// Le plancher d'ambiance. ZÉRO : sur OLED le vrai noir est la matière.
    /// Le curseur existe pour prouver, en le levant, qu'on n'en veut pas.
    var voile: Double = 0.0
    /// L'air de la pièce (fbm très basse fréquence, multiplicatif). À 0,10 il
    /// faisait une BOSSE lisible dans la queue ; l'air doit se sentir, pas se
    /// voir.
    var air: Double = 0.07
    /// LE CŒUR BLANC — le filament de la lampe. Un lobe serré, en blanc
    /// presque neutre, qui blanchit le centre SANS agrandir la flaque : c'est
    /// la réponse juste à « plus de blanc », puisque monter l'amplitude
    /// donnait le rendu 0,84, écarté au banc.
    var coeur: Double = 0.18
    /// Son rayon, en largeurs d'écran (≈ 80 pt). Petit : un cœur large et
    /// c'est toute la lumière qui devient blanche, la chaleur meurt.
    var coeurTaille: Double = 0.20
    /// LE FLANC — la coulée orangée qui descend le long du bord gauche, sous
    /// la lampe. C'est le seul orange de la page au repos, avec le futur
    /// liseré de la lune — d'où sa dose franche.
    var flanc: Double = 0.72
    /// La hauteur de son cœur (en largeurs d'écran) : sous la flaque blanche,
    /// et mort avant le mur.
    var flancY: Double = 0.46
    /// `-rasantAmp <v>` force le sommet depuis la ligne de commande : c'est le
    /// seul moyen de faire un A/B de NIVEAU au simulateur, où personne ne peut
    /// pousser un curseur. Le banc, lui, garde la main au doigt.
    static func retenus() -> RasantParams {
        var p = RasantParams()
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-rasantAmp"), i + 1 < args.count,
           let v = Double(args[i + 1]) { p.amp = v }
        return p
    }

    /// Les poussières d'étoiles. **ZÉRO par défaut, et c'est un verdict, pas
    /// un oubli** : le premier rendu les a montrées en nappe grise dans le
    /// coin haut-droit — précisément le coin qui doit rester du noir absolu
    /// pour que le liseré de la lune existe. Et une chambre n'a pas de ciel.
    /// Le curseur les rallume, masquées au BAS de la page seulement.
    var etoiles: Double = 0.0
}

// MARK: - Le fond

/// La chambre noire : le noir, le rasant, les poussières là où la lumière
/// n'arrive pas, et le grain de la maison.
struct HomeNuitFond: View {
    var p = RasantParams()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var tilt = BgTilt()

    private static let noGrain = CommandLine.arguments.contains("-noGrain")
    /// L'attribution vit sur `RasantHorloge` : « seul » se décide à l'échelle
    /// de la page, pas de cette vue.
    private static let iso = RasantHorloge.iso

    var body: some View {
        ZStack {
            Color.black

            rasant

            if p.etoiles > 0.001 && !Self.iso { poussieres }

            if !Self.noGrain && !Self.iso {
                // Sans grain, une nappe de cette largeur fait des bandes de
                // Mach sur OLED. Il est plus discret que sur l'aurore : il y a
                // ici beaucoup moins de dégradé à casser.
                WoopGrain(density: 0.030, lightAlpha: 0.022, darkAlpha: 0.030)
            }
        }
        .clipped()
        .ignoresSafeArea()
        .allowsHitTesting(false)
        // En attribution, la barre de statut sort du cadre : ses glyphes sont
        // du BLANC PUR posé en plein dans la zone la plus claire du rasant —
        // toute sonde de sommet les mesure eux, et pas la lumière.
        .statusBarHidden(Self.iso)
        // Le gyroscope s'amorce ICI : la scène est l'endroit juste, tout ce
        // qui vit dessus en profite (la leçon du 19-08 — sur la home aurora
        // personne ne l'appelait et la parallaxe lisait des zéros).
        .onAppear {
            SkyMotion.shared.start(reduceMotion: reduceMotion)
            Paillettes.shared.prepare()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                SkyMotion.shared.start(reduceMotion: reduceMotion)
            }
        }
    }

    /// 30 Hz : c'est un fond qui respire sur 37 secondes, pas une cinématique.
    private var rasant: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = Float(RasantHorloge.t(tl.date))
                let dx = reduceMotion ? 0 : Float(tilt.value.x)
                let dy = reduceMotion ? 0 : Float(tilt.value.y)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.nuitRasant(
                        .float2(geo.size.width, geo.size.height),
                        .float(t),
                        .float2(dx, dy),
                        .float4(Float(p.srcX), Float(p.srcY),
                                Float(p.along), Float(p.across)),
                        .float4(Float(p.amp), Float(p.expo),
                                Float(p.angle), Float(p.souffle)),
                        .float4(Float(p.braise), Float(p.voile),
                                Float(p.air), 0),
                        .float4(Float(p.coeur), Float(p.coeurTaille),
                                Float(p.flanc), Float(p.flancY))))
            }
        }
    }

    /// Les poussières d'étoiles de la maison (`nebulaStars`), s'il en reste.
    ///
    /// Le masque a été un masque RADIAL centré sur la lampe (« une lumière
    /// lave les étoiles autour d'elle ») : mesuré, c'était le pire choix
    /// possible — il les envoyait vivre exactement dans le coin haut-droit,
    /// L max 51 là où la cible est 4. Le coin haut-droit n'est pas un endroit
    /// sombre parmi d'autres : c'est l'écrin du liseré de la lune.
    /// Elles ne vivent donc plus QUE dans le tiers bas.
    private var poussieres: some View {
        StarDustCeiling()
            .opacity(p.etoiles)
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.56),
                    .init(color: .white.opacity(0.55), location: 0.78),
                    .init(color: .white, location: 1.0)
                ], startPoint: .top, endPoint: .bottom)
            }
    }
}

// MARK: - LA PHRASE (jalon 2)
//
// La grammaire du 1ᵉʳ screenshot d'Apple : une phrase courte, découpée en
// FRAGMENTS, un fragment par ligne, et les tons qui ALTERNENT — clair, sourd,
// clair, sourd, clair. Jamais deux clairs collés : c'est l'alternance qui fait
// lire la phrase comme une voix, et pas comme un titre.
//
// POURQUOI UNE LIGNE = UN FRAGMENT, et pas un mot. On voudrait le rendu
// « mot à mot » d'Apple Intelligence, mais SwiftUI ne sait pas flouter ni
// décaler un RUN à l'intérieur d'un paragraphe qui se replie : la
// concaténation de `Text` porte des couleurs, pas des effets. Le découpage
// manuel en lignes rend les deux à la fois — le contrôle typographique exact
// ET une animation par fragment. C'est d'ailleurs ce que fait la référence :
// ses retours à la ligne tombent sur ses fragments.

/// Une ligne de la phrase, son ton — et, pour la dernière, le NOMBRE qu'on
/// peut toucher. Le galet de verre ne s'ajoute pas à côté de la phrase : il
/// EST le chiffre de la phrase. C'est la différence entre un réglage et une
/// phrase dont un mot est vivant.
struct PhraseFragment: Equatable {
    let avant: String
    /// L'objectif, s'il est réglable ici. `nil` : une ligne de texte ordinaire.
    let objectif: Int?
    let apres: String
    let clair: Bool

    init(_ avant: String, objectif: Int? = nil, apres: String = "",
         clair: Bool) {
        self.avant = avant
        self.objectif = objectif
        self.apres = apres
        self.clair = clair
    }

    /// La ligne entière, pour VoiceOver et pour les mesures.
    var texte: String {
        avant + (objectif.map(String.init) ?? "") + apres
    }
}

enum PhraseTexte {
    /// La voix est le **vous** (arbitrage du 20-08). Les retours à la ligne
    /// sont écrits à la main : ils portent le rythme.
    /// ⚠️ EN ANGLAIS (verdict 22-08). Le reste de la page l'était déjà —
    /// « Sessions this week », « Weekly volume », « Your last sessions » : la
    /// phrase d'accueil était la seule pièce en français, et le mélange se
    /// voyait. L'alternance clair / sourd est conservée à la lettre : c'est elle
    /// qui donne son rythme au bloc, pas les mots.
    static func fragments(faits: Int, prevus: Int) -> [PhraseFragment] {
        let mot = faits == 1 ? "workout" : "workouts"
        return [
            PhraseFragment("Hello Kathryn,", clair: true),
            PhraseFragment("you've done", clair: false),
            PhraseFragment("\(faits) \(mot)", clair: true),
            PhraseFragment("this week", clair: false),
            PhraseFragment("out of ", objectif: prevus, apres: " planned.",
                           clair: true)
        ]
    }
}

struct PhraseParams: Equatable {
    var taille: Double = 30
    var tracking: Double = -0.4
    /// L'air entre deux lignes. Serré : une phrase qui respire le fait par ses
    /// MARGES, pas en écartant ses lignes. (Mesuré au rendu : 2 pt donnent un
    /// interligne apparent de 1,27 — les jambages se frôlent sans se toucher,
    /// c'est le rythme de la référence.)
    var interligne: Double = 2
    var largeur: Double = 300
    /// Le ton sourd DANS LE NOIR.
    ///
    /// 0,34 était le chiffre du plan ; mesuré sur le rendu, la ligne « cette
    /// semaine » n'y tenait que **2,9:1** — sous le plancher de 3:1 du grand
    /// texte. Et la référence Apple est bien plus claire qu'on ne le croit :
    /// ses mots sourds tournent autour de rgb(128) — 0,50, pas 0,34. À 0,42 la
    /// ligne passe à 3,4:1 ET se rapproche de la référence : le contraste et le
    /// goût tiraient du même côté.
    var sourd: Double = 0.42
    /// …et dans la flaque de lumière. Mesuré : derrière la deuxième ligne le
    /// fond monte à L ≈ 32, où un sourd constant se ferait manger. Le sourd
    /// SUIT donc LA LAMPE — ce qui tombe juste, puisque tout le reste de la
    /// page lui obéit déjà (loi 1).
    var sourdLumiere: Double = 0.54
    /// Le pied du dégradé du bloc : les lignes du bas sont plus argentées que
    /// celles du haut. UN seul dégradé pour tout le bloc, jamais un par ligne
    /// — sinon chaque ligne recommence à blanc et l'unité se casse.
    var argent: Double = 0.86
    /// L'ARRIVÉE, cinématique. Les premiers chiffres (flou 14, durée 0,42,
    /// retard 0,09) faisaient une apparition PROPRE mais pressée : « pas assez
    /// Apple ». Une arrivée Apple est LENTE et vient de loin — le flou de
    /// départ est énorme, la course longue, et les fragments se suivent de
    /// loin. Le flou de départ de chaque fragment…
    var flou: Double = 30
    /// …l'écart entre deux fragments…
    var retard: Double = 0.14
    /// …la durée de chacun…
    var duree: Double = 0.90
    /// …les points dont il monte…
    var montee: Double = 22
    /// …et son échelle de départ. Le fragment ne monte pas seulement : il
    /// s'APPROCHE (1,05 → 1,00). C'est ce couple flou + échelle qui fait la
    /// mise au point cinématographique, jamais le flou seul.
    var zoom: Double = 1.05
    /// Le retard de la phrase sur la lumière : la pièce s'allume d'abord.
    var retardLumiere: Double = 0.38
    /// La dissolution au scroll : le flou maximal atteint quand la page monte.
    var dissolution: Double = 6
    /// Le plan de la phrase suit le scroll à ce taux : elle TRAÎNE derrière le
    /// mur (0,86 = 14 % de retard).
    var plan: Double = 0.86

    var duréeTotale: Double { duree + 4 * retard }
}

/// Le niveau de la lampe en un point de l'écran, calculé en Swift — LA MÊME
/// loi que `nuitRasant`, aux mêmes constantes. Une seule géométrie, deux
/// lecteurs : le shader la peint, la phrase l'écoute.
enum RasantChamp {
    static func niveau(x: Double, y: Double, ecran: Double,
                       p: RasantParams) -> Double {
        let w = max(ecran, 1)
        let a = p.angle * .pi / 180
        let rx = x / w - p.srcX
        let ry = y / w - p.srcY
        let qx = (rx * cos(a) + ry * sin(a)) / max(p.along, 1e-3)
        let qy = (-rx * sin(a) + ry * cos(a)) / max(p.across, 1e-3)
        let d = (qx * qx + qy * qy).squareRoot()
        return pow(max(0, 1 - d), p.expo)
    }
}

/// La phrase, et son arrivée.
///
/// ⚠️ `View, Animatable` n'est PAS un raffinement : des rampes échelonnées
/// pilotées par un simple `@State` sous `withAnimation` ne jouent qu'au doigt
/// (piège payé). C'est `animatableData` qui garantit que `p` est interpolé à
/// chaque image, et donc que chaque fragment lit SON avancement.
struct PhraseVue: View, Animatable {
    /// L'avancement de l'arrivée, 0 → 1.
    var p: Double
    /// LE FLOU DU DÉPART, posé sur les GLYPHES et pas sur le conteneur. Sur une
    /// boîte, un `.blur` gonfle ses bornes du rayon et floute toute sa surface —
    /// ici 1,47 Mpix par image à 26 pt de rayon, par-dessus le masque que ce
    /// bloc pose déjà. Sur des glyphes, il ne floute que l'encre.
    var flouDepart: CGFloat = 0
    var params = PhraseParams()
    var rasant = RasantParams()
    var fragments: [PhraseFragment] = PhraseTexte.fragments(faits: 4, prevus: 5)
    /// La largeur de l'écran : la phrase en a besoin pour savoir où la lampe
    /// éclaire.
    var ecran: Double = 402
    /// Le haut du bloc, en points depuis le bord haut de l'écran (l'île
    /// comprise) : c'est la coordonnée que lit le champ du rasant.
    var hautEcran: Double = 108

    var animatableData: Double {
        get { p }
        set { p = newValue }
    }

    /// Les réglages du galet (fouettés au banc, onglet « galet »).
    var galet = GaletParams()
    /// L'objectif hebdomadaire, réglable au galet.
    @Binding var objectif: Int
    /// Le panneau du galet est ouvert.
    @Binding var reglageOuvert: Bool

    var body: some View {
        // LE MASQUE S'ARRÊTE À L'AVANT-DERNIÈRE LIGNE, et c'est un arbitrage.
        // Le galet de verre vit DANS la dernière ligne, et un `.mask` posé
        // par-dessus lui mangerait sa transparence en même temps que l'encre —
        // un verre à 87 % d'opacité n'est plus un verre. La dernière ligne
        // porte donc, en dur, la valeur que le dégradé aurait eue à sa hauteur
        // (une bande de 30 pt dans un dégradé de 170 : l'écart avec la rampe
        // continue est invisible, on l'a vérifié en superposant les deux).
        VStack(alignment: .leading, spacing: params.interligne) {
            VStack(alignment: .leading, spacing: params.interligne) {
                ForEach(Array(fragments.dropLast().enumerated()),
                        id: \.offset) { i, f in
                    ligne(f, index: i)
                }
            }
            // LE MASQUE DÉBORDE DU BLOC, sinon il coupe le halo du flou au
            // carré : un `.mask` est dimensionné sur les bornes de son hôte, et
            // le flou de départ diffuse l'encre bien au-delà du bloc.
            // ⚠️ Honnêteté de la mesure : ce n'était PAS la cause du « calque
            // blanc » (le saut au bord valait 2,1/255 avant comme après — j'ai
            // pris un tri d'indices pour une preuve). C'est un défaut latent,
            // réel mais discret, gardé ici parce que la parade ne coûte rien.
            // La vraie cause était le rayon lui-même : voir `DepartCine.flouMax`.
            .mask {
                LinearGradient(colors: [.white,
                                        .white.opacity(params.argent + 0.04)],
                               startPoint: .top, endPoint: .bottom)
                    .padding(-(flouDepart + 6))
            }

            if let derniere = fragments.last {
                ligne(derniere, index: fragments.count - 1)
            }
        }
        .frame(width: params.largeur, alignment: .leading)
    }

    @ViewBuilder
    private func ligne(_ f: PhraseFragment, index: Int) -> some View {
        let u = avancement(index)
        Group {
            if f.objectif != nil {
                // La ligne du nombre : trois morceaux sur la même ligne de
                // base. `firstTextBaseline` et pas `center` — le galet doit
                // s'asseoir sur la ligne d'écriture, sinon le chiffre flotte.
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    mot(f.avant, clair: f.clair, index: index,
                        atenu: params.argent)
                    ObjectifTouche(valeur: $objectif, ouvert: $reglageOuvert,
                                   taille: params.taille,
                                   atenu: params.argent,
                                   arrivee: min(max((u - 0.55) / 0.45, 0), 1))
                    mot(f.apres, clair: f.clair, index: index,
                        atenu: params.argent)
                }
            } else {
                mot(f.texte, clair: f.clair, index: index)
            }
        }
        // Le flou vit sur le TEXTE (et sur le galet), jamais sur un conteneur
        // plein écran : un `.blur` posé sur une boîte pose un voile uniforme
        // sur tout son rectangle (piège payé). Sur des glyphes, il ne floute
        // que l'encre.
        .blur(radius: (1 - u) * params.flou + flouDepart)
        .scaleEffect(1 + (params.zoom - 1) * (1 - u), anchor: .leading)
        .offset(y: (1 - u) * params.montee)
        .opacity(u)
    }

    /// `atenu` remplace, pour la dernière ligne, ce que le masque du bloc
    /// aurait fait — appliqué au TEXTE seul, jamais au galet de verre.
    private func mot(_ t: String, clair: Bool, index: Int,
                     atenu: Double = 1) -> some View {
        Text(t)
            .font(.inter(params.taille, .semibold))
            .tracking(params.tracking)
            .foregroundStyle(.white.opacity((clair ? 1.0 : sourd(index)) * atenu))
            // Le compte des séances ROULE quand il change, comme chez Apple.
            // Posé sur tous les fragments : ceux qui n'ont pas de chiffre n'en
            // font rien, et le jour où la phrase change de mot, elle le fera
            // proprement.
            .contentTransition(.numericText())
    }

    /// L'avancement du fragment `i` : sa rampe part `retard × i` après le
    /// début et dure `duree`.
    private func avancement(_ i: Int) -> Double {
        let t = p * params.duréeTotale - Double(i) * params.retard
        let x = min(max(t / max(params.duree, 1e-3), 0), 1)
        return x * x * (3 - 2 * x)
    }

    /// Le ton sourd de la ligne `i`, relevé de ce que la lampe éclaire à cet
    /// endroit. Le niveau est normalisé par 0,55 : c'est le maximum que le
    /// champ atteint À L'ÉCRAN (son sommet, lui, est hors cadre).
    private func sourd(_ i: Int) -> Double {
        let hauteurLigne = params.taille * 1.14 + params.interligne
        let y = hautEcran + Double(i) * hauteurLigne + hauteurLigne / 2
        let n = min(RasantChamp.niveau(x: 84, y: y, ecran: ecran,
                                       p: rasant) / 0.55, 1)
        return params.sourd + (params.sourdLumiere - params.sourd) * n
    }
}

// MARK: - LE GALET DE L'OBJECTIF

/// Le chiffre de la phrase est un OBJET : un galet de verre liquide natif,
/// posé sur la ligne d'écriture, qui **se transforme** en un petit panneau de
/// verre pour choisir de 3 à 7. Ce n'est pas un réglage à côté de la phrase,
/// c'est la phrase dont un mot est vivant — et c'est là que le verre a le plus
/// de sens : il ne décore rien, il dit « ceci se touche ».
///
/// LA LOI DU VERRE, AFFINÉE ICI (20-08) — et c'est le verdict le plus utile
/// de ce jalon :
///
/// **Le `glassEffect` natif ne marche pas sur les PETITS objets posés sur du
/// noir.** Essayé au premier rendu sur un galet de 48 pt : le verre attrape
/// tout le contraste de son bord et devient une BILLE DE CHROME — et le
/// chiffre blanc posé dessus se lit alors comme un TROU dans du métal (zoom
/// à l'appui). Ce n'est pas un réglage à corriger, c'est la matière qui ne
/// tient pas à cette échelle : la lentille a besoin de surface pour avoir
/// quelque chose à réfracter. `.clear` natif reste souverain sur les GRANDES
/// surfaces (la dalle du profil, et ici le panneau de 244 pt).
///
/// Donc : **le panneau est du verre natif, le galet est taillé à la main** —
/// une pastille sombre translucide dont l'arête ne s'allume QUE du côté de la
/// lampe (loi 1 : tout obéit à la source). C'est aussi ce que montrent les
/// références : le bouton « Begin Now » du 3ᵉ écran est une capsule sombre à
/// filet fin, pas une bulle d'argent.
///
/// Les autres lois, tenues : l'encre est posée AU-DESSUS du verre (le natif
/// givre le net) ; le conteneur de verre garde une taille CONSTANTE (des
/// bounds vivants = flou plat définitif) ; et le galet ne prend pas de place
/// quand il s'ouvre — le panneau vit en overlay, sinon la phrase se
/// réécrirait à chaque ouverture.
/// Ce qu'on donne à MANGER au verre, et comment on le taille. Trois curseurs,
/// au banc, onglet « galet ».
struct GaletParams: Equatable {
    /// LE COMBUSTIBLE — le halo doux posé DANS le conteneur, derrière le
    /// verre. C'est la découverte du 20-08 : le verre natif ne montre que ce
    /// qu'il réfracte, et sur du noir il n'a RIEN à courber (surface mesurée à
    /// p95 = 23, « on voit rien »). La première itération était magnifique
    /// parce que le chiffre blanc vivait dans le conteneur et lui servait de
    /// lampe — au prix de sa lisibilité (p95 = 186, chiffre illisible). On lui
    /// rend donc une source, mais DOUCE : un halo, jamais un glyphe.
    /// Cible mesurée : surface p95 entre 130 et 170, chiffre ≥ 7:1.
    var combustible: Double = 0.0
    /// LE LISERÉ TAILLÉ — la bonne idée du galet à la main, gardée par-dessus
    /// le verre natif : vif au coin de la lampe, mort à l'opposé. Un liseré
    /// d'intensité constante fait un bouton ; celui-là fait une pierre.
    var lisere: Double = 0.10
    /// L'ÉCLAT QUI DÉRIVE — ce qui sépare le verre du plastique. Très lent
    /// (période 14 s) et court : un reflet qui court vite est du strass.
    var scintille: Double = 0.0
    /// L'ÉCOLE. Trois, et elles se comparent au lancement plutôt que de
    /// mémoire :
    /// — `.fantome` (défaut, `-homeV2`) : **la silhouette du chiffre, floutée,
    ///   nourrit la lentille ; le chiffre net est posé au-dessus.** Le verre
    ///   mange une forme dense à bords francs — donc il scintille comme
    ///   l'itération 1 — mais le fantôme est CENTRÉ sur le glyphe net, donc il
    ///   se lit comme la lueur du chiffre et non comme un doublon.
    /// — `.pur` (`-galetPur`) : l'itération 1 telle quelle. Rien que le chiffre
    ///   dans le verre, superbe et à peine lisible.
    /// — `.nourri` (`-galetNourri`) : encre nette + halo doux. Propre, moins
    ///   cristallin (surface mesurée 120 contre 186).
    var ecole: GaletEcole = .cuit
    /// Le flou du fantôme. **Mesuré : à 8 pt, la surface tombe à 65** — le flou
    /// étale le blanc, donc il détruit la DENSITÉ et les BORDS FRANCS, qui sont
    /// exactement ce qui fait les caustiques. Le fantôme doit donc rester
    /// presque net (1,5) : ce n'est pas un halo, c'est un glyphe massif.
    var fantome: Double = 1.5
    /// Le grossissement du fantôme. Il est un peu PLUS GROS et plus gras que
    /// le chiffre net qui se pose dessus : la lentille en fait une aura autour
    /// du glyphe lisible, au lieu d'un second chiffre à côté de lui.
    var fantomeGros: Double = 1.30
    /// Sa densité. Proche du blanc plein : c'est la densité qui fait les
    /// caustiques, pas la surface.
    var fantomeDose: Double = 1.00

    // MARK: L'école « dur » — les réglages du cristal peint

    /// La force de tout ce qui brille (arête, contre-lumière, caustique).
    var brillance: Double = 1.0
    /// L'épaisseur de l'arête, en points. C'est la pièce maîtresse : un verre,
    /// c'est d'abord un bord qui accroche la lumière.
    var arete_: Double = 2.4
    /// La dispersion : de combien le rouge et le bleu se décalent sur l'arête.
    var dispersion: Double = 0.7
    /// Le lissage du col, en points. C'est LUI le tuyau : gras à 14, rompu à 3.
    /// ⚠️ Un smooth-min ne PONTE que si le lissage dépasse ~4× l'écart des deux
    /// corps (12 pt d'écart → 24 minimum ; à 17 il ne se passe rien).
    var col: Double = 34.0
    /// LES RUBANS DE CAUSTIQUE — la structure pliée dans le corps du verre.
    /// C'est la pièce qui séparait « galet mat verni » de « cristal » : sans
    /// eux, l'éclairage est radialement monotone (3,0 alternances par ligne
    /// mesurées, contre 5,2 pour le verre natif nourri).
    var rubans: Double = 0.85
    /// Leur pas, en points. Serré = un cristal taillé fin ; large = une goutte.
    var rubanPas: Double = 26.0

    /// LE COMBUSTIBLE NEUTRE de la cuisson : une virgule de lumière et deux
    /// traînées croisées. Surtout PAS un chiffre — l'itération 1 est belle
    /// parce qu'elle plie le glyphe, et cuire ce pliage-là graverait un double
    /// pour toujours.
    var neutre: Double = 0.95

    static func retenus() -> GaletParams {
        let args = CommandLine.arguments
        if args.contains("-galetCuisson") {
            return GaletParams(ecole: .fantome)
        }
        if args.contains("-galetPur") {
            return GaletParams(ecole: .pur)
        }
        if args.contains("-galetFantome") {
            return GaletParams(ecole: .fantome)
        }
        if args.contains("-galetNourri") {
            return GaletParams(combustible: 1.05, lisere: 0.45,
                               scintille: 0.55, ecole: .nourri)
        }
        return GaletParams()
    }
}

enum GaletEcole {
    /// La pastille est une IMAGE CUITE — le rendu du verre natif, capturé une
    /// fois pour toutes. Le panneau et le col restent natifs : c'est la
    /// pastille qu'on regarde, et c'est elle qui devait être parfaite.
    case cuit
    /// Le cristal PEINT par `verreGalet` (VerreGalet.metal) : la seule école
    /// qui ne dépend pas du fond, et la seule sans double — rien n'est
    /// réfracté, donc rien n'est déplacé.
    case dur
    case fantome, pur, nourri
}

/// LE NOMBRE QU'ON TOUCHE — et il n'est plus un objet.
///
/// Six itérations de galet de verre pour finir par le retirer, et la mesure
/// dit pourquoi : la page tient 90 % de ses pixels sous L=24 et une seule
/// lampe, et on y avait posé un objet dont le corps montait à **L 112 de
/// moyenne** — cinq fois plus clair que le fond derrière le texte. Chrome,
/// cuit, peint ou natif : un objet de 56 pt qui est la chose la plus brillante
/// de l'écran se lit comme un AUTOCOLLANT. Ce n'était pas la matière, c'était
/// le niveau et la place.
///
/// Alors la phrase redevient du **type pur** — c'est ce que fait Apple dans
/// les références : le verre vit dans les contrôles et les feuilles, jamais en
/// perle au milieu d'un paragraphe. Le nombre porte juste ce qu'il faut pour
/// dire qu'il se touche (un filet sous lui), et TOUT le verre déménage dans le
/// panneau — 244 pt de surface, la seule échelle où le verre natif est
/// réellement beau, et qui n'existe que quand on le demande.
///
/// Le galet, lui, n'est pas perdu : sa cuisson (`-galetCuisson`), son shader
/// (`VerreGalet.metal`) et ses quatre écoles restent au dossier — c'est
/// l'archive d'un chantier qui a livré ses lois, à défaut de son objet.
struct ObjectifTouche: View {
    @Binding var valeur: Int
    @Binding var ouvert: Bool
    /// La taille du texte de la phrase : le nombre est du texte, il en prend
    /// exactement la taille.
    var taille: Double = 30
    /// L'atténuation de la dernière ligne (ce que le masque du bloc aurait
    /// fait) : le nombre est du texte, il la subit comme les autres mots.
    var atenu: Double = 0.86
    var arrivee: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le doigt sur le panneau, en points depuis son bord gauche.
    @State private var doigt: CGFloat?
    @State private var vise: Int?

    private static let pan = CGSize(width: 244, height: 58)
    private static let pas: CGFloat = 46
    private static let bord: CGFloat = 8
    private static func centre(_ i: Int) -> CGFloat {
        bord + pas * CGFloat(i) + 22
    }

    var body: some View {
        Text("\(valeur)")
            .font(.inter(taille, .semibold))
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(valeur)))
            .foregroundStyle(.white.opacity(atenu))
            // L'AFFORDANCE, et rien de plus : un filet sous le nombre. Il ne
            // doit pas se lire comme un lien — juste assez pour que le doigt
            // sache où aller.
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(.white.opacity(ouvert ? 0.42 : 0.22 * arrivee))
                    .frame(height: 1.6)
                    .offset(y: taille * 0.10)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(reduceMotion ? .easeOut(duration: 0.2)
                              : .spring(response: 0.42,
                                        dampingFraction: 0.80)) {
                    ouvert.toggle()
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Objectif hebdomadaire, \(valeur) entraînements")
            .accessibilityHint("Toucher pour changer")
            // Le panneau vit en overlay : la phrase ne se réécrit pas quand il
            // s'ouvre.
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    if ouvert { panneau }
                }
                .frame(width: Self.pan.width, height: Self.pan.height,
                       alignment: .topLeading)
                .offset(x: -14, y: taille * 1.35)
                .zIndex(60)
            }
    }

    /// LE PANNEAU — le seul verre de la page, et à SON échelle. Le conteneur
    /// natif porte la matière ; l'encre, elle, vit AU-DESSUS de lui (dedans,
    /// le conteneur la lentille et les chiffres sortent givrés, doublés de
    /// fantômes — la loi payée au chantier du galet).
    private var panneau: some View {
        ZStack(alignment: .topLeading) {
            GlassEffectContainer {
                Color.clear
                    .frame(width: Self.pan.width, height: Self.pan.height)
                    .glassEffect(.clear, in: Capsule())
            }
            .frame(width: Self.pan.width, height: Self.pan.height)

            cases
                .frame(width: Self.pan.width, height: Self.pan.height)
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            doigt = v.location.x
                            let i = caseSous(v.location.x)
                            if i != vise {
                                vise = i
                                UISelectionFeedbackGenerator().selectionChanged()
                            }
                        }
                        .onEnded { v in
                            choisir(Goal.hebdoChoix[caseSous(v.location.x)])
                            doigt = nil
                            vise = nil
                        }
                )
        }
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
        .transition(.scale(scale: 0.26, anchor: .topLeading)
            .combined(with: .opacity))
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: doigt)
    }

    /// LE ZOOM DU DOIGT — la loi de la barre du bas d'iOS : ce qui grossit est
    /// ce qu'on SURVOLE, pas ce qui est sélectionné, et le chiffre visé SORT de
    /// la capsule.
    private var cases: some View {
        HStack(spacing: 2) {
            ForEach(Array(Goal.hebdoChoix.enumerated()), id: \.element) { i, n in
                let z = zoom(i)
                let vif = n == valeur
                Text("\(n)")
                    .font(.inter(19, .semibold))
                    .foregroundStyle(.white.opacity(vif || z > 1.05 ? 1 : 0.58))
                    .frame(width: 44, height: 44)
                    .background {
                        if vif {
                            Circle().fill(Color.white.opacity(0.20))
                                .overlay(Circle().strokeBorder(
                                    Color.white.opacity(0.22), lineWidth: 0.8))
                        }
                    }
                    .scaleEffect(z)
                    .offset(y: -(z - 1) * 16)
            }
        }
    }

    private func zoom(_ i: Int) -> CGFloat {
        guard let d = doigt else { return 1 }
        let dx = abs(d - Self.centre(i))
        return 1 + 0.55 * exp(-pow(dx / 34, 2))
    }

    private func caseSous(_ x: CGFloat) -> Int {
        let i = Int(((x - Self.bord - 22) / Self.pas).rounded())
        return min(max(i, 0), Goal.hebdoChoix.count - 1)
    }

    private func choisir(_ n: Int) {
        if n != valeur {
            withAnimation(.easeOut(duration: 0.28)) { valeur = n }
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.2)
                      : .spring(response: 0.42, dampingFraction: 0.82)) {
            ouvert = false
        }
    }
}


// MARK: - LA GRANDE CARD VIDÉO (le complément du 21-08, plan §9 — jalon V1)

/// Le sort du fond. La page vit sur la VIDÉO ; le rasant du jalon 1 est
/// ARCHIVÉ, rejouable derrière ses bancs — on ne détruit pas une lumière
/// mesurée, on la range.
/// `-tirageFige <pt>` : la card tirée et TENUE là. Le simulateur ne sait pas
/// poser un doigt — sans ce banc, le secret sous la card n'est jugeable que
/// sur l'appareil.
enum TirageBanc {
    static let fige: CGFloat? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-tirageFige"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return CGFloat(v)
    }()
}

enum FondBanc {
    /// `-fondRasant` (ou les bancs du rasant) : la chambre noire du jalon 1
    /// reprend la page, la vidéo se tait.
    static let rasant = ["-fondRasant", "-rasantLab", "-isoRasant"]
        .contains { CommandLine.arguments.contains($0) }
}

/// La boucle du fond — l'école exacte de la pop-up booster et du panneau du
/// départ : `AVPlayerLooper` (jamais un seek sur didPlayToEndTime), looper
/// RETENU, muet, démontage qui rend tout. Une différence, parce que la home
/// n'est pas un panneau transitoire : le système suspend le player au passage
/// en arrière-plan, la home REPREND la lecture au retour.
///
/// Le fichier (`home-fond-loop.mp4`, 1080×2348, 24 i/s, 12 s) est CUIT — voir
/// `tools/home-v2/recuit_fond.sh` : pills_glass + flamme fusionnées en écran
/// (en RGB : un blend sur les plans YUV fabrique du magenta), ping-pong
/// (couture 1,0 pour un bruit voisin de 0,7 — sous le seuil), le cadrage du
/// wireframe (la pilule à 65 %, son dôme SOUS la phrase) et le scrim de la
/// phrase dans le fichier (L1-L4 sur du noir absolu, L5 ≤ 52 au pire frame).
/// Rien de tout ça ne se rattrape ici.
struct HomeFondVideo: UIViewRepresentable {
    /// LE SCRUB — 0 → 1. Non nil, la vidéo cesse de jouer et **suit le
    /// geste image par image** : c'est la technique de la page AirPods
    /// d'Apple, et elle n'a rien d'un moteur 3D — un pixel de geste = un
    /// `seek`. Nil, la boucle reprend.
    var scrub: Double?

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var retour: NSObjectProtocol?
        var statut: NSKeyValueObservation?
        /// Le geste tient la vidéo.
        var scrubbing = false
        /// ⚠️ UN SEUL SEEK EN VOL. Empiler les seeks à 60 Hz met AVPlayer à
        /// genoux : on garde la DERNIÈRE cible demandée et on la joue quand
        /// le seek courant rend la main. C'est la coalescence classique, et
        /// sans elle le scrub est une diaporama.
        var enVol = false
        var attente: CMTime?
        deinit {
            if let r = retour { NotificationCenter.default.removeObserver(r) }
            statut?.invalidate()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BoosterLoopLayerView {
        let v = BoosterLoopLayerView()
        // ⚠️ Le fond de la couche est TRANSPARENT, jamais noir : c'est
        // l'image de pose posée dessous qui doit se voir quand le décodeur
        // rate une frame. Une couche noire opaque, et le raté DEVIENT le
        // glitch noir (le défaut payé le 21-08).
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        v.playerLayer.videoGravity = .resizeAspectFill
        v.playerLayer.backgroundColor = UIColor.clear.cgColor
        guard let url = Bundle.main.url(
            forResource: "home-fond-loop", withExtension: "mp4") else {
            // Sans le fichier, l'image de pose tient la page à elle seule.
            return v
        }
        let p = AVQueuePlayer()
        p.isMuted = true
        p.automaticallyWaitsToMinimizeStalling = false
        context.coordinator.looper = AVPlayerLooper(
            player: p, templateItem: AVPlayerItem(url: url))
        context.coordinator.player = p
        v.playerLayer.player = p
        p.play()
        // LE PRÉCHARGEMENT, une fois les tampons prêts : sans lui la
        // première seconde est une suite de frames manquées.
        // ⚠️ `preroll` LÈVE UNE EXCEPTION tant que le statut n'est pas
        // `readyToPlay` — appelé à la construction, il tue l'app au
        // lancement (payé le 21-08). Il s'attache donc au statut.
        context.coordinator.statut = p.observe(\.status, options: [.new]) {
            joueur, _ in
            guard joueur.status == .readyToPlay else { return }
            joueur.preroll(atRate: 1) { fini in
                if fini { joueur.play() }
            }
        }
        context.coordinator.retour = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil, queue: .main) { [weak p] _ in p?.play() }
        return v
    }

    func updateUIView(_ v: BoosterLoopLayerView, context: Context) {
        let c = context.coordinator
        guard let p = c.player else { return }
        guard let scrub else {
            if c.scrubbing {
                c.scrubbing = false
                c.attente = nil
                p.play()
            }
            return
        }
        if !c.scrubbing {
            c.scrubbing = true
            p.pause()
        }
        guard let d = p.currentItem?.duration, d.isNumeric, d.seconds > 0
        else { return }
        let t = CMTime(seconds: d.seconds * min(max(scrub, 0), 1),
                       preferredTimescale: 600)
        Self.viser(p, t, c)
    }

    /// Le seek coalescé : on ne demande jamais deux seeks à la fois.
    private static func viser(_ p: AVQueuePlayer, _ t: CMTime,
                              _ c: Coordinator) {
        guard !c.enVol else { c.attente = t; return }
        c.enVol = true
        p.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            c.enVol = false
            if let suivant = c.attente {
                c.attente = nil
                viser(p, suivant, c)
            }
        }
    }

    static func dismantleUIView(_ v: BoosterLoopLayerView,
                                coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        v.playerLayer.player = nil
    }
}

/// LA GRANDE CARD : la home est UNE surface aux très grands coins arrondis,
/// posée sur la page noire — l'anatomie du puits de l'iPod appliquée à la
/// page entière. Le rayon est CONCENTRIQUE (celui de l'écran moins la marge,
/// la règle d'Apple) : c'est lui qui fait « posé » et pas « collé ».
struct GrandeCardVideo: View {
    /// La naissance de la page, 0 → 1 : la card s'allume en fondu avec une
    /// approche imperceptible (1,015 → 1). Jamais un bounce (la spec).
    var naissance: Double = 1
    /// L'entrée de la PILULE, séparée de la naissance de la card — elle
    /// arrive en DERNIER (cf. `FondDeuxCalques.pilule`).
    var pilule: Double = 1
    /// ⚠️ **LA CARD PREND TOUTE LA LARGEUR** (verdict 22-08 : « on voit trop les
    /// côtés noirs à droite et à gauche, elle doit prendre l'espace »).
    ///
    /// Ce n'est PAS un retour en arrière sur « je dois voir la bordure de la
    /// card » : ce qui donne sa forme à la card, c'est son **arête basse et ses
    /// coins**, et ils restent — c'est le noir SOUS elle qui la dessine, jamais
    /// le noir sur ses flancs. Les côtés, eux, ne montraient qu'une bande de
    /// 10 pt qui coupait la braise en deux.
    ///
    /// Bénéfice mesuré : la vidéo fait 1080 × 2348, soit 0,4599 — l'écran fait
    /// 402 × 874, soit 0,4600. À marge nulle **le cadrage est exact** et on ne
    /// rogne plus les 7,7 pt latéraux qu'on perdait de chaque côté.
    var marge: CGFloat = 0
    /// Les coins du haut suivent alors ceux de l'ÉCRAN, puisque la card les
    /// touche. Un rayon concentrique n'a de sens que pour une forme encartée.
    var rayon: CGFloat = 55
    /// LE RAYON DE L'ÉCRAN — celui que prend le bas de la card, puisqu'il
    /// touche le bord physique.
    var rayonEcran: CGFloat = 55
    /// LA LEVÉE DU TIROIR. ⚠️ La card ne MONTE pas, elle se RACCOURCIT par le
    /// bas : son contenu est repoussé d'autant qu'elle s'est déplacée, donc
    /// son bord haut ne bouge pas d'un pixel. Translater toute la page faisait
    /// remonter la phrase de 96 pt — mesuré à 21 pt du haut au lieu de 117,
    /// « Bonjour » à cheval sur l'heure. Un tiroir qui s'ouvre ne déménage pas
    /// la pièce.
    var levee: CGFloat = 0
    /// LE TEMPS DE LA SCÈNE DE DÉPART, **en secondes** (0 → `DepartCine.T`).
    /// Ce n'était pas une durée qui manquait, c'était une horloge : `scene`
    /// valait `-tirage/150`, donc le film durait ce que durait le geste — 0,2 s.
    var e: Double = 0

    /// L'encart bas de la safe area, LU et jamais écrit en dur — c'est lui que
    /// la marche du padding fait perdre (voir plus bas).
    @Environment(\.encartBas) private var encartBas

    var body: some View {
        Color.black
            .overlay(
                // LE FOND EN DEUX PLANS (voir DepartCine.swift et
                // tools/home-v2/PLAN-SCENE-DEPART.md). La braise est clouée à
                // l'arête basse et ne bouge JAMAIS ; la pilule descend, roule
                // et grossit au-dessus d'elle. Les images de pose sont rentrées
                // DANS chaque calque : posées dehors, en additif, elles
                // s'ajouteraient et on verrait deux pilules.
                FondDeuxCalques(e: e, pilule: pilule)
                // ⚠️ LA CARD DESCEND JUSQU'AU BORD PHYSIQUE. La marge de
                // nuit était appliquée aux QUATRE côtés : mesuré à la
                // capture, 30 px = 10,0 pt de bande noire sous la card,
                // au centre comme aux deux quarts. Verdict : « la card ne
                // descend pas jusqu'au bout du téléphone ».
                //
                // Et le rayon SUIT la loi concentrique au lieu de la
                // casser : une forme qui touche le bord de l'écran prend
                // le rayon DE L'ÉCRAN (55), pas celui d'une forme posée à
                // 10 pt de lui (45). Un seul rayon partout aurait fait
                // rentrer le bas — c'est ce décrochage qui trahit une
                // marge oubliée.
                //
                // Le vide du bas n'est donc plus une marge : c'est la
                // bande que le TIRAGE découvre, et elle n'existe que
                // quand on soulève la card.
                // ⚠️ LA PILULE BOUGE DANS SON CADRE. La transformation est
                // posée AVANT le clip : la forme arrondie la découpe, et la
                // card ne quitte jamais l'écran. J'avais transformé la card
                // ENTIÈRE — elle sortait du cadre et la page se vidait. La
                // card est le CADRE, la vidéo est le CONTENU.
                // ⚠️ TOUT EST ANCRÉ EN BAS, et c'est LA correction. Un zoom
                // ancré au CENTRE fait fuir les bords vers l'extérieur : le
                // bas de la vidéo — LA BRAISE — sortait par le bas, et
                // l'`offset` l'enfonçait encore. On finissait par regarder une
                // zone plus haute de l'image, là où il n'y a que du rouge
                // sombre. La braise ne peut pas survivre à un zoom centré :
                // c'est arithmétique, pas une affaire de réglage.
                //
                // Ancré en BAS, le bord inférieur est CLOUÉ — la braise reste
                // exactement où elle est — et tout ce qui est au-dessus (la
                // pilule) grandit VERS LE BAS. C'est ça, « la vidéo roule du
                // haut vers le bas ». Et l'offset devient inutile : le zoom
                // ancré en bas produit DÉJÀ la descente.
                //
                // Même ancre pour la rotation : au centre elle bascule comme
                // une carte qu'on incline ; en bas, comme un couvercle qui se
                // rabat. C'est le roulé Apple.
                // ⚠️ AUCUNE ANCRE NE PEUT SAUVER UN GROS ZOOM, et c'est
                // arithmétique : une homothétie éloigne TOUT de son ancre.
                //  · ancrée au CENTRE, le bas fuit par le bas → la braise sort ;
                //  · ancrée en BAS, tout grandit VERS LE HAUT → la vidéo
                //    « remonte », ce qui est exactement le contraire du geste
                //    demandé (essayé, et c'était pire).
                // On ne peut pas tenir deux points à la fois avec une seule
                // échelle. Donc le zoom reste MODESTE (×1,15) et c'est le
                // SCRUB qui porte le mouvement : lui change le CONTENU de
                // l'image sans toucher au cadrage, donc sans jamais chasser
                // la braise ni l'arête de la card.
                // ⚠️ PLUS AUCUNE TRANSFORMATION ICI. Elles vivent maintenant sur
                // le SEUL calque pilule, dans `FondDeuxCalques`. Posées ici
                // elles emportaient la braise avec la pilule — c'était
                // arithmétique, pas un réglage.
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: rayon,
                    bottomLeadingRadius: rayonEcran,
                    bottomTrailingRadius: rayonEcran,
                    topTrailingRadius: rayon,
                    style: .continuous))
                .padding(.top, marge)
                .padding(.horizontal, marge)
                .opacity(naissance)
                .scaleEffect(1.015 - 0.015 * naissance)
            )
            .ignoresSafeArea()
            // ⚠️ LA LEVÉE SE RETIRE EN BAS, ET DU NOIR AUSSI. Deux pièges
            // enfilés ici : posée en haut, elle raccourcissait la card par le
            // HAUT (0 pt découvert, mesuré) ; et posée sur le seul contenu,
            // elle laissait le FOND NOIR de la card couvrir toute la page —
            // la bande s'ouvrait vraiment, mais derrière un rideau noir.
            // C'est la card ENTIÈRE qui s'arrête plus haut.
            //
            // ⚠️⚠️ **ET UN PADDING SUR UNE VUE EN `ignoresSafeArea()` COÛTE
            // L'ENCART EN PLUS, D'UN COUP.** Mesuré à trois gels :
            //   levée   0 → arête 874 → raccourcissement   0
            //   levée  60 → arête 780 → raccourcissement  94
            //   levée 156 → arête 684 → raccourcissement 190
            // Soit `levée + 34` dès que la levée quitte zéro. La cause : à zéro
            // la card TOUCHE le bord physique, donc `ignoresSafeArea` réclame
            // les 34 pt de l'encart bas ; au premier point de levée elle ne le
            // touche plus et les PERD tous d'un coup. Ce n'est pas une rampe,
            // c'est une MARCHE — et elle a coûté deux verdicts : « la card ne
            // descend pas assez » (elle montait 50 pt trop haut) et « le texte
            // dépasse la card » (son calage, écrit pour la cote honnête,
            // l'amenait à 6 pt de l'arête au lieu de 40).
            //
            // On retire donc l'encart de la levée demandée. Il se LIT, il ne
            // s'écrit pas en dur : 34 est une cote d'iPhone 17 Pro, pas une loi.
            .padding(.bottom, max(levee - encartBas, 0))
            // BANC `-cotes` : les cotes VIVANTES, écrites à l'écran. La console
            // de simctl n'a pas rendu le stdout de l'app, et une géométrie ne se
            // diagnostique pas par déduction : deux modèles de layout
            // expliquaient les mêmes pixels, il fallait le chiffre.
            // ⚠️ En DERNIER : posé avant l'overlay du contenu, il passait
            // dessous et restait invisible.
            .overlay(alignment: .topTrailing) {
                if CommandLine.arguments.contains("-cotes") {
                    Text("L \(Int(levee)) · e \(String(format: "%.2f", e))")
                        .font(.system(size: 16, weight: .bold,
                                      design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.top, 62)
                        .padding(.trailing, 14)
                }
            }
    }
}

/// `fullScreenCover(item:)` réclame un `Identifiable` — l'onglet est déjà sa
/// propre identité.
extension WoopTab: Identifiable {
    public var id: String { rawValue }
}

// MARK: - LE SECRET SOUS LA CARD (idée du 21-08)

/// Quand la grande card se SOULÈVE (tirage vers le HAUT), la bande du BAS se
/// découvre et le croissant de la marque s'y allume — `GlypheLune` (les 18
/// cubiques du logo du splash) au néon d'ambre, la recette EXACTE du bouton
/// central de l'iPod : cœur blanc-chaud (r 2), tube braise (r 14), halo
/// (r 26).
///
/// Il ne FAIT rien, et c'est voulu (« on verra à quoi ça sert plus tard ») :
/// c'est un secret qui respire. Et il vit à la MÊME place que le player de
/// séance (jalon V5) — un seul geste, une seule couche révélée : hors séance
/// le secret, en séance le player.
struct LuneSecrete: View {
    /// 0 → 1 : la découverte, pilotée par le tirage vers le bas.
    var p: Double

    var body: some View {
        GlypheLune()
            .fill(Color(red: 1.00, green: 0.72, blue: 0.42))
            .frame(width: 34, height: 34)
            .shadow(color: Color(red: 1.00, green: 0.965, blue: 0.90)
                .opacity(0.9 * p), radius: 2)
            .shadow(color: Color(red: 1.00, green: 0.42, blue: 0.13)
                .opacity(0.85 * p), radius: 14)
            .shadow(color: Color(red: 1.00, green: 0.42, blue: 0.13)
                .opacity(0.5 * p), radius: 26)
            .opacity(p)
            // Elle ne monte pas, elle S'APPROCHE — le couple échelle +
            // braise, jamais un fondu nu (la loi de la mise au point).
            .scaleEffect(0.82 + 0.18 * p)
            .allowsHitTesting(false)
    }
}

// MARK: - LA SEMAINE (jalon V2) — cinq mini cards, dont des FANTÔMES

/// Les bancs de la semaine. Le simulateur ne finit pas de séance :
/// `-semaineMaterialise` joue la matérialisation (le premier fantôme devient
/// une card noire 2,5 s après l'arrivée), `-semaineFaits <n>` force le compte
/// de faites (sans lui, un objectif inférieur aux faites ne montre AUCUN
/// fantôme — et un fantôme ne se juge qu'en le voyant).
enum SemaineBanc {
    static let materialise =
        CommandLine.arguments.contains("-semaineMaterialise")
    static let faits: Int? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-semaineFaits"), i + 1 < args.count,
              let v = Int(args[i + 1]) else { return nil }
        return max(0, v)
    }()
}

/// La progression de la semaine EN OBJETS — elle remplace les cinq points du
/// plan d'origine (loi 4 : la phrase dit le compte en mots, la semaine en
/// objets, rien d'autre). `prevus` emplacements toujours visibles : les
/// faites en cards NOIRES, opaques, nettes (date + sticker) ; les restantes
/// en FANTÔMES — du verre `.clear` nu, la fumée de la vidéo passe au
/// travers. Pas de progress bar, pas de conteneur autour : des objets posés
/// sur la card (la DA du 21-08).
///
/// Les deux lois du verre, à la lettre :
/// - le verre vit DANS le conteneur, l'encre AU-DESSUS : deux rangées
///   JUMELLES superposées, géométrie identique (l'école du galet de
///   l'objectif) ;
/// - les bounds de chaque verre sont CONSTANTS : la matérialisation est un
///   fondu de calques PAR-DESSUS (la plaque noire couvre le verre), jamais
///   un redimensionnement ni un démontage.
/// LA MINI-CARD D'UN JOUR — LE composant, extrait de l'ardoise « This week »
/// pour que le parcours puisse le RÉEMPLOYER au lieu de l'imiter.
///
/// ⚠️ **VERDICT DU 26-08** : « pour le petit overlay sous le galet, tu as pris
/// le bon composant général, mais il faut reprendre LA VRAIE mini-card carrée
/// utilisée sur la Home dans "Toute la semaine" — vraie mini-card, vraie date,
/// vrai sticker flamme, même design que la Home. Pas une approximation. »
/// C'est littéralement le même code qui rend les deux, maintenant : le jour
/// où l'une bouge, l'autre bouge.
///
/// ⚠️ **LA DATE EST VRAIE, LE STICKER NE L'EST PAS ENCORE — ET C'EST ASSUMÉ.**
/// Même sur la Home, le sticker est choisi par un modulo sur l'index : aucune
/// séance ne le décide. Le câbler aux `Workout` est du backend, que le chantier
/// a repoussé (décision D2 du plan). Réemployer le composant tel quel donne le
/// bon design tout de suite ; le jour où la base parlera, c'est `sticker` qui
/// changera de source, et rien d'autre.
struct MiniCardJour: View {
    let date: Date
    let sticker: String
    /// La journée est FAITE : le sticker est à pleine taille. Sinon il est
    /// rentré à 70 % — la card se lit comme une place, pas comme un acquis.
    var faite: Bool = true
    var largeur: CGFloat = 70
    var hauteur: CGFloat = 78

    private var forme: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            forme.fill(LinearGradient(
                colors: [Color(white: 0.060), Color(white: 0.030)],
                startPoint: .top, endPoint: .bottom))
            forme.strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            GrainTexture.tuile
                .resizable(resizingMode: .tile)
                .opacity(0.05).blendMode(.overlay).clipShape(forme)
            forme.fill(EllipticalGradient(
                stops: [.init(color: .white.opacity(0.07), location: 0),
                        .init(color: .clear, location: 1)],
                center: UnitPoint(x: 0.25, y: 0.08),
                startRadiusFraction: 0, endRadiusFraction: 1.0))
                .blendMode(.plusLighter)
            VStack(alignment: .leading, spacing: 0) {
                Text(SemaineStrip.jour(date))
                    .font(.inter(10, .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text(SemaineStrip.mois(date))
                    .font(.inter(5.5, .semibold)).tracking(0.7)
                    .foregroundStyle(Color(white: 1).opacity(0.45))
            }
            .padding(7)
            // Le sticker vit sous la date, CENTRÉ, et le bord bas de
            // l'ardoise le tranche à mi-corps : on en devine le haut. C'est
            // la loi de la pochette du bac — la coupe est un choix.
            Image(sticker)
                .resizable().scaledToFit()
                .frame(width: 36, height: 36)
                .position(x: largeur * 0.443, y: hauteur * 0.590)
                .scaleEffect(faite ? 1 : 0.7)
        }
        .frame(width: largeur, height: hauteur)
    }
}

struct SemaineStrip: View {
    var faits: Int
    var prevus: Int
    /// 0 → 1, l'arrivée de la page : la semaine se pose en queue de phrase.
    var arrivee: Double = 1
    /// Les fantômes matérialisés EN PLUS des faites (le banc aujourd'hui, la
    /// vraie fin de séance au jalon du flow).
    var materialises: Int = 0
    /// Le tap d'une mini — la story de la séance viendra s'y brancher.
    var onTap: (Int) -> Void = { _ in }
    /// Un cheveu autour de l'ardoise (les cards en ont un, elle non — c'était
    /// l'un des trois écarts). En mode verre il devient le liseré ANGULAIRE
    /// des cards : c'est lui qui fait lire le verre, pas le corps.
    var lisere: Bool = false
    /// L'ARDOISE EN VERRE NATIF — la même matière que les cards. Le fond
    /// vidéo bouge dessous, et c'est ce qu'on veut voir.
    var verre: Bool = false
    /// Le sous-titre gris, au registre des légendes des cards.
    var sousTitre: String = "Your last sessions" 

    /// La mini sous le doigt. Une seule à la fois : on ne presse pas deux
    /// cartes.
    @State private var presse: Int?
    /// L'écart de la mini portée au doigt. Une seule à la fois.
    @State private var porte: CGSize = .zero
    /// Les salves de poudre fine : elles partent à la PRISE et à la POSE, et
    /// s'effacent d'elles-mêmes au bout de 0,95 s.
    @State private var poudres: [SalveMini] = []
    @State private var derniere: CGPoint = .zero
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var n: Int { max(prevus, 1) }
    private var solides: Int { min(faits + materialises, n) }

    private let forme = RoundedRectangle(cornerRadius: 26, style: .continuous)
    private let formeMini = RoundedRectangle(cornerRadius: 10,
                                             style: .continuous)
    private let L: CGFloat = 354
    private let H: CGFloat = 128
    private let miniL: CGFloat = 70
    // ⚠️ PLUS CARRÉE (verdict 22-08) : 70 × 88 tirait au portrait.
    // 70 × 78 la rapproche du carré sans lui rendre sa hauteur de
    // pochette — le bord bas de l'ardoise la tranche toujours.
    private let miniH: CGFloat = 78
    fileprivate static let stickers = ["sticker-bras", "sticker-flamme",
                                   "sticker-basket", "sticker-abricot",
                                   "sticker-chocolat", "sticker-jambes",
                                   "sticker-piscine"]

    /// LE LAYOUT, MESURÉ SUR SON WIREFRAME (verdict 21-08 : « le layout des
    /// mini cards c'est pas comme l'image, regarde bien »). Sonde numpy sur
    /// sa maquette, ramenée en points d'écran :
    /// - l'ardoise est COURTE — 340 × 128 pt (retenu 354 pour aligner ses
    ///   bords sur la gouttière de la phrase). C'est sa brièveté qui TRANCHE
    ///   les minis : elles font 88 de haut pour ~46 de visible, exactement
    ///   la loi des pochettes du bac ;
    /// - les minis ALTERNENT — une sur deux monte de 10 pt et s'incline de
    ///   6° ; les autres restent droites et basses (tops mesurés à 82 et
    ///   72 pt sous le haut de l'ardoise) ;
    /// - le z croît vers la DROITE (la loi du bac : la droite devant) ;
    /// - pas de 55,5 pt pour 62 de large : elles se chevauchent.
    /// Layout FIXE + transforms de RENDU, jamais un HStack (une boîte
    /// tournée gonfle son layout : le piège payé de l'éventail).
    private func angle(_ i: Int) -> Double { i % 2 == 0 ? 0 : 6 }
    private func slotX(_ i: Int) -> CGFloat {
        let pas: CGFloat = 51
        let groupe = CGFloat(n - 1) * pas + miniL
        return (L - groupe) / 2 + miniL / 2 + CGFloat(i) * pas
    }
    private func slotY(_ i: Int) -> CGFloat {
        (i % 2 == 0 ? 66 : 56) + miniH / 2
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // L'ardoise du calendrier. Son niveau est MESURÉ sur le
            // wireframe : **L 27**, soit exactement le `white: 0.11` de la
            // pochette du bac. La mienne tenait L 4 (du noir sur du noir) —
            // elle disparaissait. Elle reste TRANSLUCIDE (opacité 0,90) :
            // les fantômes posés dessus mangent encore la vidéo à travers
            // elle — une ardoise opaque les affamerait.
            // LA MÊME MATIÈRE QUE LES DEUX WIDGETS (verdict 21-08) : un
            // plancher très bas et DEUX lueurs radiales neutres posées sur
            // l'anti-diagonale — jamais un dégradé linéaire. L'ardoise garde
            // un souffle d'opacité pour que les fantômes mangent encore la
            // vidéo.
            if verre {
                GlassEffectContainer(spacing: 0) {
                    Color.clear
                        .frame(width: L, height: H)
                        .glassEffect(.clear, in: forme)
                }
            } else {
                forme.fill(Color(white: 0.016).opacity(0.94))
            }
            forme.fill(RadialGradient(
                colors: [Color(white: 0.150).opacity(0.94), .clear],
                center: .topTrailing, startRadius: 0, endRadius: L * 0.95))
                .opacity(verre ? 0.34 : 1)
            forme.fill(RadialGradient(
                colors: [Color(white: 0.100).opacity(0.94), .clear],
                center: .bottomLeading, startRadius: 0, endRadius: L * 0.62))
                .opacity(verre ? 0.34 : 1)
            GrainTexture.tuile
                .resizable(resizingMode: .tile)
                .opacity(0.05).blendMode(.overlay).clipShape(forme)
            forme.fill(EllipticalGradient(
                stops: [.init(color: .white.opacity(0.06), location: 0),
                        .init(color: .white.opacity(0.015), location: 0.5),
                        .init(color: .clear, location: 1)],
                center: UnitPoint(x: 0.18, y: 0.06),
                startRadiusFraction: 0, endRadiusFraction: 1.1))
                .blendMode(.plusLighter)
            // ⚠️ LE MÊME LISERÉ QUE LES CARDS, et pas un cheveu blanc plat :
            // celui-ci est ANGULAIRE — il meurt dans deux coins et culmine
            // dans les deux autres (le blanc en bas-gauche, l'or en
            // haut-droite). Un trait d'intensité constante lit « bordure » ;
            // deux crêtes lisent « objet éclairé ». C'est la seule façon que
            // l'ardoise appartienne au même monde que ses voisines.
            if lisere {
                forme.stroke(cardLisereConique, lineWidth: 1.6)
                forme.stroke(cardLisereConique, lineWidth: 4.4)
                    .blur(radius: 2.4)
                    .opacity(0.46)
            }

            // ⚠️ LES FANTÔMES DE VERRE SONT MORTS (verdict 22-08 : « enlève
            // les carrés bizarres gris clair »). C'était un `glassEffect`
            // `.clear` monté sur CHAQUE emplacement, y compris les séances
            // pas encore faites — et c'est encore la loi du VERRE À JEUN :
            // posé sur l'ardoise sombre, il n'a presque rien à réfracter et
            // ne rend qu'un rectangle gris. Il était censé laisser passer la
            // nappe de flamme de la vidéo ; l'ardoise, elle, l'en empêche.
            // Une semaine se lit à ce qui est FAIT, pas aux cases vides.

            // L'ENCRE, au-dessus du conteneur : le titre et les faites.
            // Titre mesuré sur le wireframe : 147 pt de large (le mien en
            // tenait 115) et son œil est à 20 pt sous le haut de l'ardoise.
            // LE TITRE ET SON SOUS-TITRE — même famille, même corps que les
            // légendes des cards (0,0430 × 170 = 7,31 pt), même gris sourd :
            // c'est le seul moyen que les trois objets se lisent comme une
            // même page et non comme trois widgets voisins.
            VStack(alignment: .leading, spacing: 3) {
                Text("This week.")
                    .font(.inter(20, .semibold))
                    .foregroundStyle(.white.opacity(0.94))
                Text(sousTitre)
                    .font(.system(size: 8.50, weight: .regular))
                    .tracking(8.50 * 0.030)
                    .foregroundStyle(CardTon.encreDouce)
            }
            .padding(.top, 16).padding(.leading, 22)
            ZStack {
                ForEach(0..<n, id: \.self) { i in
                    mini(i)
                        // L'APPUI A DU POIDS, et il REDRESSE la carte :
                        // l'école des pochettes du calendrier. Une carte
                        // qu'on presse se met droite sous le doigt, elle ne
                        // fait pas que rétrécir.
                        .rotationEffect(.degrees(angle(i)
                                                 * (presse == i ? 0.35 : 1)
                                                 + secousse(i).1))
                        // PORTÉE, elle GRANDIT au lieu de rétrécir : on la
                        // tient au-dessus du tas. Pressée sans bouger, elle
                        // s'enfonce. Deux gestes, deux réponses opposées.
                        .scaleEffect(porteLoin && presse == i ? 1.07
                                     : (presse == i ? 0.94 : 1))
                        .shadow(color: .black.opacity(
                            porteLoin && presse == i ? 0.55 : 0),
                                radius: 14, y: 8)
                        .offset(x: secousse(i).0.width
                                    + (presse == i ? porte.width : 0),
                                y: secousse(i).0.height
                                    + (presse == i ? porte.height : 0)
                                    + (presse == i && !porteLoin ? -4 : 0))
                        .animation(.spring(response: 0.28,
                                           dampingFraction: 0.62),
                                   value: presse)
                        .position(x: slotX(i), y: slotY(i))
                        // La portée passe DEVANT tout le monde — une carte
                        // qu'on soulève et qui reste sous les autres n'est
                        // pas soulevée.
                        .zIndex(presse == i ? 100 : Double(i))
                        .allowsHitTesting(i < solides)
                        // ⚠️ UN SEUL GESTE pour l'appui ET le tap : un
                        // `onLongPressGesture`, même à 0,01 s, VOLE le tap
                        // qui le suit (la loi payée sur le puits de l'iPod
                        // et sur le galet du menu).
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    if presse != i {
                                        presse = i
                                        derniere = v.location
                                        semer(i)
                                        UIImpactFeedbackGenerator(style: .soft)
                                            .impactOccurred()
                                    }
                                    porte = borneMini(v.translation, i)
                                    // LA POUDRE SE SÈME À LA DISTANCE, jamais
                                    // au temps : un doigt qui s'arrête se
                                    // tait. C'est ça qui fait croire à la
                                    // matière.
                                    Paillettes.shared.travel(
                                        hypot(v.location.x - derniere.x,
                                              v.location.y - derniere.y),
                                        level: 0.45)
                                    derniere = v.location
                                }
                                .onEnded { v in
                                    let d = hypot(v.translation.width,
                                                  v.translation.height)
                                    Paillettes.shared.end()
                                    // ELLE SE REPLACE TOUTE SEULE — l'aimant
                                    // de son emplacement. Un ressort peu
                                    // amorti : elle revient et se pose en
                                    // dépassant à peine.
                                    withAnimation(.spring(response: 0.44,
                                                          dampingFraction: 0.70)) {
                                        porte = .zero
                                    }
                                    presse = nil
                                    if d > 24 {
                                        semer(i)
                                        UIImpactFeedbackGenerator(style: .soft)
                                            .impactOccurred()
                                    } else {
                                        onTap(i)
                                    }
                                }
                        )
                }
            }
            .frame(width: L, height: H)

            // LA POUDRE FINE — celle du calendrier, pas la grosse gerbe
            // (verdict 22-08 : « pas les grosses paillettes, les MINI
            // paillettes comme dans la card du mois »). Seize grains par
            // salve, l'étoile-facette de la maison, la gravité, et
            // l'horloge qui DORT quand il n'y a rien à semer.
            PoudreMini(salves: poudres)
                .frame(width: L, height: H)
        }
        .frame(width: L, height: H)
        .clipShape(forme)
        .opacity(pose)
        .offset(y: 14 * (1 - pose))
        .onAppear {
            SkyMotion.shared.start(reduceMotion: reduceMotion)
            Paillettes.shared.prepare()
        }
    }

    /// Une salve de poudre au-dessus de la mini `i`, qui s'oublie toute seule.
    private func semer(_ i: Int) {
        guard !reduceMotion else { return }
        let s = SalveMini(t0: Date(),
                          x: slotX(i) + porte.width,
                          y: slotY(i) + porte.height,
                          graine: Int.random(in: 0 ... 9999))
        poudres.append(s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            poudres.removeAll { $0.id == s.id }
        }
    }

    /// Portée assez loin pour qu'elle quitte son emplacement : au-delà de
    /// 6 pt, ce n'est plus un appui, c'est un transport.
    private var porteLoin: Bool {
        hypot(porte.width, porte.height) > 6
    }

    /// LA MINI RESTE DANS L'ARDOISE. Elle est déjà clippée par la forme, mais
    /// un objet qu'on pousse hors du cadre et qui disparaît sous le doigt se
    /// lit comme un bug : on le retient AVANT le bord.
    private func borneMini(_ t: CGSize, _ i: Int) -> CGSize {
        let x = slotX(i), y = slotY(i)
        let mx = miniL / 2 + 4, my = miniH / 2 - 14
        return CGSize(
            width: min(max(t.width, mx - x), L - mx - x),
            height: min(max(t.height, my - y), H - my - y + 18))
    }

    /// LA SECOUSSE DU TÉLÉPHONE (verdict 22-08 : « quand je secoue le tél même
    /// légèrement elles se secouent »). `SkyMotion` rend une inclinaison déjà
    /// LISSÉE et RECENTRÉE lentement — c'est l'écart à la tenue habituelle qui
    /// compte, jamais l'angle absolu : un téléphone tenu penché dans un canapé
    /// revient au neutre au lieu de rester décalé.
    ///
    /// Chaque carte répond DIFFÉREMMENT — celles de devant (z le plus grand,
    /// la droite) bougent le plus. Un éventail qui se décale d'un bloc est un
    /// calque ; un éventail dont chaque carte a sa propre inertie est une pile
    /// d'objets posés.
    ///
    /// ⚠️ Le simulateur n'a pas de gyroscope : l'inclinaison y reste à zéro et
    /// les cartes sont simplement immobiles. Cela ne se juge qu'au téléphone.
    private func secousse(_ i: Int) -> (CGSize, Double) {
        guard !reduceMotion else { return (.zero, 0) }
        let m = SkyMotion.shared
        let t = m.tilt, k2 = m.shake
        // De 0,45 pour celle du fond à 1,0 pour celle de devant.
        let profondeur = 0.45 + 0.55 * Double(i) / Double(max(n - 1, 1))
        // DEUX RÉPONSES, ET IL FAUT LES DEUX : l'INCLINAISON déplace le tas
        // doucement quand on penche le téléphone (une position), la SECOUSSE
        // le fait sursauter quand on le remue (une impulsion). Le lissage de
        // l'inclinaison est trop lent pour rendre un coup sec — c'est pour ça
        // qu'« elles se secouent » demandait une seconde grandeur.
        let dx = t.dx * 7.0 * profondeur + k2.dx * 13.0 * profondeur
        let dy = t.dy * 3.8 * profondeur + k2.dy * 9.0 * profondeur
        return (CGSize(width: dx, height: dy),
                Double(t.dx) * 1.6 * profondeur
                    + Double(k2.dx) * 3.4 * profondeur)
    }

    /// La pose : la semaine n'arrive que dans le dernier tiers de la course
    /// de la phrase — la lumière, les mots, puis les objets.
    private var pose: Double { min(max((arrivee - 0.70) / 0.30, 0), 1) }

    /// La mini du bac, RÉDUITE (132 → 70 pt) : même ardoise noire (0,040 →
    /// 0,014), même cheveu blanc à 6 %, même grain, même lumière posée
    /// haut-gauche, même date bold + mois sourd, même sticker bas-gauche.
    /// ⚠️ Le dessin vit dans `MiniCardJour` depuis le 26-08 : le parcours
    /// devait RÉEMPLOYER cette card, pas l'imiter (« pas une approximation »).
    /// Ici ne reste que ce qui appartient à l'ardoise — quelle date, quel
    /// sticker, et si la place est encore vide.
    private func mini(_ i: Int) -> some View {
        let faite = i < solides
        return MiniCardJour(date: date(i),
                            sticker: Self.stickers[i % Self.stickers.count],
                            faite: faite,
                            largeur: miniL, hauteur: miniH)
            .opacity(faite ? 1 : 0)
    }

    /// Le sticker d'un rang — le parcours le lit pour choisir le même.
    static func sticker(_ i: Int) -> String {
        stickers[((i % stickers.count) + stickers.count) % stickers.count]
    }

    /// Les dates des faites : les derniers jours jusqu'à aujourd'hui — le
    /// câblage aux vraies séances vient avec le jalon du flow, pas avant.
    private func date(_ i: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -(max(solides, 1) - 1 - i),
                              to: Date()) ?? Date()
    }
    private static let fJour: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "d"
        return f
    }()
    private static let fMois: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "MMM"
        return f
    }()
    static func jour(_ d: Date) -> String { fJour.string(from: d) + "." }
    static func mois(_ d: Date) -> String {
        fMois.string(from: d).replacingOccurrences(of: ".", with: "")
            .uppercased()
    }
}

// MARK: - La page

/// La home v2 telle qu'elle existe à ce stade : la grande card vidéo, la
/// phrase, la semaine. Les widgets, le slider, la levée et le menu viendront
/// s'y poser (jalons V3 à V7 du plan §9) — la page grandit, elle ne se
/// réécrit pas.
struct HomeNuitPage: View {
    var rasant = RasantParams.retenus()
    var phrase = PhraseParams()
    var galet = GaletParams.retenus()
    var faits: Int = SemaineBanc.faits ?? 4

    /// Les fantômes matérialisés en plus (le banc `-semaineMaterialise`).
    @State private var materialises = 0

    /// L'OBJECTIF, réglé au galet de verre et gardé d'une session à l'autre.
    /// `@AppStorage` et non un `@State` : un objectif qu'on choisit et que
    /// l'app oublie au relancement n'est pas un objectif.
    @AppStorage(Goal.cleHebdo) private var prevus: Int = Goal.weeklyTarget
    /// Le panneau du galet est-il ouvert. `-galetOuvert` l'ouvre au
    /// lancement : le simulateur ne sait pas poser un doigt sur un galet.
    @State private var reglageOuvert =
        CommandLine.arguments.contains("-galetOuvert")

    /// L'arrivée. Figée par `-phraseFige <p>`, ou par `-arriveeFige <s>` qui
    /// reconstitue TOUTE la cinématique à un instant donné (lumière comprise) —
    /// le seul moyen d'en juger le déroulé sur des images fixes.
    @State private var arrivee: Double =
        PhraseHorloge.instant.map { PhraseHorloge.avanceePhrase($0) }
        ?? PhraseHorloge.fige ?? 0
    /// LA NAISSANCE DE LA LUMIÈRE, 0 → 1. La pièce s'allume avant que les mots
    /// n'existent — et elle s'allume en trois gestes à la fois : la lampe
    /// ENTRE par la gauche, sa flaque se resserre (une mise au point, faite
    /// dans le shader et non au `.blur` : un flou plein écran animé coûterait
    /// une passe hors écran par image) et son niveau monte.
    @State private var naissance: Double =
        PhraseHorloge.instant.map { PhraseHorloge.avanceeLumiere($0) }
        ?? (PhraseHorloge.fige != nil ? 1 : 0)
    /// L'unique sonde de scroll de la page. ⚠️ UNE seule : une sonde
    /// `onScrollGeometryChange` qui renvoie une constante ne rappelle plus
    /// jamais, et deux sondes sur le même scroll se volent les rappels.
    @State private var scroll: CGFloat = CGFloat(PhraseHorloge.forceScroll ?? 0)

    /// La page est-elle DÉJÀ née. `onAppear` se rejoue — au retour d'onglet, à
    /// un remontage de sous-arbre, et ici simplement quand l'objectif change :
    /// la capture l'a pris en flagrant délit, le panneau du banc se rouvrait
    /// tout seul huit secondes après. Sans ce verrou, c'est la CINÉMATIQUE
    /// D'ARRIVÉE entière qui rejoue en pleine page (la leçon de l'aube de la
    /// v1, payée deux fois).
    @State private var deja = false

    /// ⚠️ Sans lui, `paused: reduceMotion` figerait la page à mi-scène. Le
    /// chemin court est EXPLICITE : pas d'horloge, pas de rotation, pas de
    /// rate — l'état final, sans le trajet.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - LA PIÈCE DU TRÉSOR (retour de la v1, verdict 24-08)

    /// L'horloge de la fumée de la pièce, ou `nil` si personne n'y touche.
    @State private var fumeePiece: Date?
    /// L'instant où le doigt s'est levé (la bouffée retombe de là).
    @State private var fumeePieceFin: Date?
    /// La page du trésor.
    @State private var coffreOuvert = false

    /// LE TIRAGE de la card géante (verdict 21-08 : « je dois pouvoir drag
    /// toute la home ») — le déplacement RENDU, déjà élastiqué.
    @State private var tirage: CGFloat = TirageBanc.fige ?? 0
    /// §23 LE BRANCHEMENT — le chemin (la Duolinguo_page) et, par-dessus
    /// lui, la RED PAGE EXO quand le panneau du galet a confirmé.
    @State private var cheminOuvert = false
    @State private var exoOuvert = false
    /// §23 — LE PIÈGE DES INSETS (payé sur l'ardoise du player) : un
    /// ScrollView `ignoresSafeArea` monté SOUS un cover re-négocie ses
    /// insets à chaque passe et fait RESPIRER la page au-dessus. Une fois
    /// l'exo posée, le chemin se DÉMONTE (il ne doit pas survivre — le
    /// retour de l'exo replie tout jusqu'à la home).
    @State private var cheminDemonte = false
    @Environment(\.modelContext) private var modelContext
    /// Le verrou de l'haptique du secret : la braise ne se sent qu'UNE fois
    /// par découverte, pas à chaque image passée au-dessus du seuil.
    @State private var luneSentie = false

    // MARK: - LE FLOW DE LA SÉANCE (22-08)

    /// OÙ LE MENU ENVOIE. ⚠️ La home v2 vit encore dans son banc — `-homeV2`
    /// monte `HomeNuitLab()` **à la place de toute l'app**, il n'y a pas de
    /// `TabView` dedans, et l'onglet Accueil monte toujours `HomeAuroraView`.
    /// Le routage est donc écrit ici mais n'a de destination QUE ce que
    /// l'appelant lui donne : le banc présente les vraies pages en plein écran,
    /// et le jour où la v2 prend l'onglet, le même point d'appel pilotera
    /// `selection`. On n'invente pas une navigation qui n'existe pas.
    var onRoute: (WoopTab) -> Void = { _ in }
    /// §23 — dans le monde TabView, le départ du chemin ROUTE vers
    /// l'onglet exercices (une seule RED PAGE EXO montée) au lieu
    /// d'empiler un cover par-dessus le chemin.
    var exoParRoute = false

    /// L'ordre de la colonne — il doit suivre `MenuItems.titres` à la lettre.
    static let destinations: [WoopTab] = [.profile, .progress, .exercises]

    /// Le galet est rangé au mur : le slider reprend la largeur libérée.
    @State private var galetRange = false
    @State private var menuOuvert = false
    /// LA SÉANCE TOURNE. Tant qu'elle tourne, la card reste SOULEVÉE et
    /// refuse de se refermer : le player n'est pas un tiroir qu'on range,
    /// c'est l'état de la page.
    ///
    /// ⚠️ **DÉRIVÉ DE LA BASE, PLUS JAMAIS ÉCRIT À LA MAIN** (26-08). C'était
    /// un `@State` local, mis à `true` par les deux départs et remis à
    /// `false` **nulle part dans le dépôt** — la séance avait DEUX machines à
    /// états qui ne se parlaient pas : `Workout.endedAt` en base (écrite par
    /// `terminerSeance()`), et ce drapeau. D'où, après la clôture : le player
    /// fantôme dont le chrono continuait de tourner, le menu rangé dans sa
    /// pastille, l'invite de tirage éteinte, les curseurs cloués à zéro et le
    /// geste de tirage qui sortait avant le cran — la home n'était pas
    /// seulement mal peinte, elle était VERROUILLÉE. Il n'y a plus qu'une
    /// machine à états, et c'est la base. Le patron est celui de la page
    /// exercices (`ExercisesView.swift:361`), écrit quinze lignes à côté.
    @Query(filter: #Predicate<Workout> { $0.endedAt == nil },
           sort: \Workout.startedAt, order: .reverse)
    private var seancesOuvertes: [Workout]

    /// Le banc `-homeSeance` n'a aucune séance en base : son chrono part du
    /// lancement. `static let` = évalué une fois, jamais dans le body.
    private static let bancSeance =
        CommandLine.arguments.contains("-homeSeance")
    private static let bancDepart = Date()

    private var enSeance: Bool {
        Self.bancSeance || !seancesOuvertes.isEmpty
    }
    private var debutSeance: Date? {
        Self.bancSeance ? Self.bancDepart : seancesOuvertes.first?.startedAt
    }

    /// LE TIROIR EST VERROUILLÉ OUVERT. ⚠️ C'est le PRÉREQUIS du départ au
    /// tirage : sans lui on tire, le slider paraît, on lâche pour attraper le
    /// pouce — et tout retombe. C'est ce cran, et lui seul, qui sépare un
    /// tiroir d'un jouet.
    @State private var tiroirOuvert = false
    /// L'AXE DU GESTE, verrouillé au premier mouvement franc. ⚠️ Sans lui, un
    /// glissement HORIZONTAL (le pouce du slider) nourrissait aussi le tirage
    /// de la page : le moindre soupçon de vertical refermait le tiroir, et le
    /// galet rentrait au coin en plein milieu du geste. Un axe se décide UNE
    /// fois — le tester à chaque image le ferait osciller.
    @State private var axeVertical: Bool?
    /// LE POINT DE DÉPART DU GESTE EN COURS. `nil` = aucun doigt. Il sert à
    /// deux choses, et les deux réparent « parfois rien ne se passe » : repérer
    /// qu'un NOUVEAU geste commence (donc remettre l'état à plat), et savoir
    /// qu'un geste est encore censé être en cours (donc armer le chien de
    /// garde).
    @State private var tirageDebut: CGPoint?
    /// Le jeton du chien de garde — l'école de `SliderObsidienne.stale` : une
    /// vérification différée n'agit que si elle est encore la dernière.
    @State private var tirageJeton = 0
    /// LE PORTE-DEMANDES DE LA RANGÉE DE WIDGETS — créé UNE fois, jamais
    /// recréé : c'est son identité qui rend la rangée prouvablement égale.
    @State private var demandes = DemandesCards()

    /// Le coefficient de la sonde : 0 éteint le flou visé, sous le doigt.
    private func coefSonde(_ n: Int) -> CGFloat {
        guard tirageDebut != nil else { return 1 }
        return (Self.pullSonde == 4 || Self.pullSonde == n) ? 0 : 1
    }

    /// `-pullSonde <n>` — la bisection du coût du geste.
    private static let pullSonde: Int = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-pullSonde"), i + 1 < a.count,
              let n = Int(a[i + 1]) else { return 0 }
        return n
    }()
    // MARK: - LES DEUX CURSEURS (refonte 22-08 : « tu vas trop vite »)
    //
    // ⚠️ LE DÉFAUT N'ÉTAIT PAS UNE DURÉE, C'ÉTAIT UNE ARCHITECTURE. `scene`
    // valait `-tirage/150` : le pouce était le projectionniste, et un pouce
    // parcourt 150 pt en 0,20 s. Aucune courbe ne répare ça.
    //
    // Deux curseurs, qui ne se croisent jamais :
    //  · `g` — LA PRISE, collée au pouce, réversible, saturante. Elle ne fait
    //    QUE de la lumière : le net qui décroche, la bande qui s'ouvre. La
    //    pilule, la braise, le slider et la nouvelle phrase ne bougent pas d'un
    //    pixel sous le doigt — c'est cette immobilité qui fait exister la chute.
    //  · `e` — LE TEMPS, en SECONDES, parti au cran, que plus rien n'accélère.

    /// L'instant du cran. `nil` = repos, ou doigt posé.
    @State private var depart: Date?
    /// Ce que le doigt avait déjà consommé au cran : toutes les fenêtres du
    /// mobilier sont écrites en `max(gCran, …)`, donc le TAP produit la même
    /// scène que le TIRAGE — la partition fait elle-même le travail du doigt.
    @State private var gCran: Double = 0
    /// ⚠️ VERROU DU VERRE. Le verre natif ignore `.opacity` : on le DÉMONTE. Mais
    /// un pouce lent qui traverse le seuil le monterait et le démonterait en
    /// boucle. Une bascule par cycle, remontage seulement quand le doigt est
    /// revenu au repos.
    @State private var verreMonte = true

    // MARK: - LE MODE ÉDITION DES WIDGETS (« la vitrine », 22-08)
    //
    // Le plan : `tools/home-v2/PLAN-EDITION-WIDGETS.md`. L'ÉTAT VIT ICI et
    // pas dans les cards : tout `@State` posé dedans meurt au démontage
    // `verreMonte` (le film de départ démonte le verre).

    /// LES DEUX SLOTS, persistés — le précédent maison : `Goal.cleHebdo`.
    /// `"vide"` = le fantôme.
    @AppStorage("widgetSlot0") private var slot0Brut: String =
        WidgetKind.regularite.rawValue
    @AppStorage("widgetSlot1") private var slot1Brut: String =
        WidgetKind.volume.rawValue
    /// Le mode édition (respiration + pastilles). `-editFige <p>` le fige.
    @State private var edition = EditionBanc.fige != nil
    @State private var editionP: Double = EditionBanc.fige ?? 0
    /// La drop-list : le slot qui la porte, et son curseur d'ouverture.
    @State private var listeSlot: Int?
    @State private var listeP: Double = 0
    /// Le refus du dernier widget (pop-up flottante, auto-dismiss).
    @State private var refusP: Double = 0
    @State private var refusJeton = 0
    /// LA VITRINE : le slot en cours de changement, et le widget emporté
    /// (`nil` = slot fantôme, c'est un ajout).
    @State private var vitrineSlot: Int?
    @State private var vitrineDepart: WidgetKind?
    /// Le recul de la home pendant la vitrine — il entre dans le `max` de
    /// `MenuHote` : le trio du menu (flou 7 + échelle + extinction), sans
    /// dupliquer la pile. La vidéo, elle, ne recule jamais.
    @State private var reculVitrine: Double = 0
    /// La poudre d'une suppression (transitoire, démontée à 1 s).
    @State private var poudreSlot: Int?
    @State private var poudreDepuis: Date = .distantPast

    private var slots: [WidgetKind?] {
        [WidgetKind(rawValue: slot0Brut), WidgetKind(rawValue: slot1Brut)]
    }

    /// LES STATS RÉELLES — calculées UNE fois à l'apparition (jamais dans
    /// le body : la page vit sous une TimelineView 60 Hz, le piège de la
    /// page ré-évaluée par image est déjà payé). `nil` = pas de données
    /// (le banc nu) : les cards gardent leurs défauts.
    @Query private var workoutsBruts: [Workout]
    @State private var stats: SemaineStats?

    /// Le compte affiché : le banc (`-semaineFaits`) prime, puis les vraies
    /// données, puis le défaut.
    private var faitsAffiche: Int {
        if SemaineBanc.faits != nil { return faits }
        return stats?.faites ?? faits
    }

    /// LES WIDGETS VIDES (le cas empty, verdict 22-08) : le design reste,
    /// grisé. Un widget dont la semaine n'a rien à dire ne MENT pas avec
    /// ses défauts de banc. `-widgetsVides` force les quatre (capture).
    private var widgetsVides: Set<WidgetKind> {
        if CommandLine.arguments.contains("-widgetsVides") {
            return Set(WidgetKind.allCases)
        }
        guard let s = stats else {
            // Pas une seule séance terminée : rien n'est vrai — tout est
            // gris (sauf au banc forcé, qui passe par -semaineFaits).
            return workoutsBruts.isEmpty && SemaineBanc.faits == nil
                ? Set(WidgetKind.allCases) : []
        }
        var v: Set<WidgetKind> = []
        if s.faites == 0 { v.insert(.regularite) }
        if s.volumeValeur == "0.0" { v.insert(.volume) }
        if s.hiit == nil { v.insert(.hiitPeak) }
        if s.peak == nil { v.insert(.peakEffort) }
        return v
    }

    private func ecrireSlot(_ i: Int, _ k: WidgetKind?) {
        if i == 0 { slot0Brut = k?.rawValue ?? "vide" }
        else { slot1Brut = k?.rawValue ?? "vide" }
    }

    /// PAS DE DOUBLON (arbitrage C) : la vitrine n'offre que le possible —
    /// le widget déjà posé sur l'autre slot n'y apparaît pas.
    private func choixPour(_ i: Int) -> [WidgetKind] {
        WidgetKind.allCases.filter { $0 != slots[1 - i] }
    }

    /// LA FRAME ÉCRAN DU SLOT — le vol de la vitrine part de là et y
    /// revient. Elle tient compte du zoom arrière du mode édition (0,96
    /// autour du centre de la rangée, qui est à x = 201) : sans ça la
    /// prise de relais saute de 4 pt et de 4 %.
    private func origineSlot(_ i: Int, _ h: CGFloat) -> CGRect {
        let z = 1 - 0.04 * editionP
        let cx = 201 + (CGFloat(24 + i * 184 + 85) - 201) * z
        let cy = h * 0.375 + 85
        let cote = 170 * z
        return CGRect(x: cx - cote / 2, y: cy - cote / 2,
                      width: cote, height: cote)
    }

    /// LA PRISE, 0 → 1, collée au pouce.
    private var g: Double {
        guard !enSeance else { return 0 }
        return min(max(Double(-tirage) / Double(Self.leveeTiroir), 0), 1)
    }

    /// L'instant de la fermeture. Elle a sa propre horloge : rejouer la
    /// partition à l'envers ferait de chaque sortie un événement.
    @State private var ferme: Date?
    /// Le `e` d'où la fermeture est partie — elle ne repart pas toujours de T.
    @State private var eFerme: Double = DepartCine.T
    /// ⚠️ **LE GEL, ET C'EST LE CORRECTIF DES ALLER-RETOURS** (verdict 22-08 :
    /// « la fluidité n'est pas assez fluide si on fait des aller-retours non
    /// stop »). Ce n'était pas une lenteur, c'était un SAUT : un doigt qui se
    /// posait en plein film mettait `depart` à nil, et `e` retombait
    /// instantanément sur l'état posé — de 0,6 à 1,95 en UNE image. Maintenant
    /// le doigt GÈLE la scène là où elle en est, et la reprise repart de là.
    @State private var eGele: Double?
    /// Le verrou de l'armement : le cran ne se sent qu'au franchissement, pas à
    /// chaque image passée au-delà.
    @State private var cranSenti = false

    /// LE TEMPS DE LA SCÈNE. Hors horloge il retombe sur l'état posé (0 ou T),
    /// AU CENTIÈME : aucune image ne change à la bascule.
    private func eNow(_ now: Date) -> Double {
        guard !enSeance else { return 0 }
        if let f = eGele { return f }
        if let d = depart { return min(now.timeIntervalSince(d), DepartCine.T) }
        if let f = ferme {
            // La durée est PROPORTIONNELLE à ce qu'il reste à défaire : fermer
            // depuis un quart de film ne peut pas prendre le même temps que
            // fermer depuis la fin, sinon un aller-retour court traîne.
            let duree = Self.dureeFermeture * max(eFerme / DepartCine.T, 0.30)
            let p = min(now.timeIntervalSince(f) / duree, 1)
            return eFerme * (1 - DepartCine.bezier(0.30, 0, 0.12, 1, p))
        }
        return tiroirOuvert ? DepartCine.T : 0
    }

    /// 1,25 s — 64 % de l'aller. À 0,72 s (37 %) la cascade se tassait et on
    /// ne voyait plus le flou : « il faut que le retour soit aussi fluide ».
    private static let dureeFermeture: Double = 1.25

    /// ⚠️ **UNE SEULE ARÊTE POUR LES DEUX ÉTATS** (verdict 22-08 : « la card doit
    /// descendre comme quand on ouvre le player, même niveau, et le slider est
    /// dans cet espace »). Elle avait raison au point près : mesuré, l'état
    /// player posait l'arête à **734** et l'état tiroir à **684** — 50 pt
    /// d'écart, parce que les deux cotes étaient réglées séparément ET que le
    /// padding mentait de 34 (voir `GrandeCardVideo`).
    ///
    /// Un seul endroit, trois contenus : le secret, le slider, le player. C'était
    /// déjà l'intention écrite dans le code, elle n'était pas tenue.
    /// 874 − 140 = **734**.
    private static var leveeSeance: CGFloat { 140 }
    /// LA LEVÉE DU TIROIR — **la même que celle de la séance**, et c'est la
    /// consigne : le slider vit dans l'espace que le player ouvrirait.
    ///
    /// La bande fait 140 pt et se répartit ainsi, de haut en bas :
    ///   34 d'air au-dessus du slider · 62 de slider · 10 jusqu'à la safe area ·
    ///   34 de réserve d'indicateur.
    ///
    /// ⚠️ Les 34 du haut sont MESURÉS, pas choisis : la gerbe de poudre du
    /// commit monte à `64,76 − h/2` = **33,8 pt** au-dessus du cadre du slider.
    /// En dessous, la poudre blanche se poserait sur l'arête de la card.
    /// Contrôle : 734 + 34 + 62 + 10 + 34 = 874.
    private static var leveeTiroir: CGFloat { leveeSeance }
    /// Le seuil du cran, mesuré sur le tirage RENDU (déjà élastiqué).
    ///
    /// ⚠️ **RECALÉ DE 95 À 52 LE 26-08** — verdict : « pas besoin d'atteindre
    /// une distance énorme pour déclencher l'état, le drag doit fonctionner au
    /// moindre mouvement suffisamment intentionnel ».
    /// Le calcul, refait sur le POUCE : `tirage = 140·tanh(net/190)`, donc
    /// franchir 95 demandait `atanh(95/140)·190 + 14` = **171 pt de pouce**
    /// pour ouvrir (et 179 pour refermer). C'est plus de la moitié de la
    /// hauteur utile d'un iPhone : le geste n'était pas exigeant, il était
    /// hors de portée. À 52, il en demande **80** — franc, intentionnel, et
    /// atteignable d'un pouce qui ne lâche pas le téléphone.
    private static var seuilCran: CGFloat { 52 }
    /// Le seuil de REFERMETURE, en hystérésis sous le cran (sinon il claque au
    /// moindre frémissement). Recalé dans le même rapport : 42 → 26.
    private static var seuilFerme: CGFloat { 26 }
    /// LA POIGNÉE DU PULL — la hauteur de la bande qui prend le doigt au bas
    /// de la card. Elle DÉBORDE le dessin de l'invite : on ne doit pas viser.
    private static var poigneePull: CGFloat { 112 }
    /// LE REPOS DE LA CARD : zéro hors séance, la levée pendant. Tout le
    /// tirage se mesure PAR RAPPORT À LUI — sinon la card retomberait sur
    /// le player à chaque lâcher.
    private var reposCard: CGFloat {
        if enSeance { return -Self.leveeSeance }
        return tiroirOuvert ? -Self.leveeTiroir : 0
    }

    /// La découverte du secret : la card se SOULÈVE (tirage NÉGATIF), et la
    /// lune se lève dans la bande du bas. Elle ne commence qu'après 70 pt
    /// (un secret se mérite) et culmine à 130 — dans l'élastique, jamais à
    /// sa butée.
    private var luneP: Double {
        guard !enSeance else { return 0 }
        return min(max((-Double(tirage) - 70) / 60, 0), 1)
    }

    /// LE PLAYER SE MONTRE À 55 % DE LA COURSE, pas à l'ouverture : on le voit
    /// VENIR, on ne le découvre pas.
    private var playerP: Double {
        guard enSeance else { return 0 }
        return min(max(-Double(tirage) / (Double(Self.leveeSeance) * 0.55),
                       0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            // ⚠️ TOUTE LA PAGE VIT DANS `MenuHote` : c'est lui qui porte le
            // galet, la couronne et le recul du mobilier. Le FOND (la vidéo)
            // ne recule jamais — une couche UIKit ne sait pas s'échelonner
            // dans une transaction SwiftUI, elle SAUTE. Le mobilier, lui,
            // s'éloigne : sans quoi le disque `.clear` de la couronne
            // GIVRERAIT l'encre nette de la phrase.
            // ⚠️ **UNE SEULE HORLOGE, ET ELLE EST LE PRÉREQUIS DE TOUT.**
            // `Chambre(p: e)` nourri par une `Date` ne joue RIEN : `Chambre`
            // est `Animatable`, donc SwiftUI n'interpole que si la valeur
            // change DANS UNE TRANSACTION. Une horloge murale n'invalide aucun
            // body — au lâcher, la pilule descendrait seule (elle a sa propre
            // couche) et TOUT LE RESTE GÈLERAIT.
            //
            // Elle est PAUSÉE au repos ET sous le doigt : là, `e` vaut 0 et la
            // page se réévalue de toute façon parce que `tirage` est un
            // `@State`. Coût d'horloge au repos : zéro. Elle ne tourne que
            // pendant les 1,95 s du film.
            //
            // 60 Hz et pas 30 : la pointe de la chute est à 452 pt/s, soit
            // 7,5 pt par image à 60 Hz — 15 à 30 Hz, sur un objet net de 288 pt.
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: reduceMotion
                                        || (depart == nil && ferme == nil))) { tl in
                let e = eNow(tl.date)
                MenuHote(ouvert: $menuOuvert,
                         onChoix: { i in
                             guard Self.destinations.indices.contains(i) else { return }
                             onRoute(Self.destinations[i])
                         },
                         // ⚠️ LA COLONNE, PAS LA COURONNE (verdict 22-08 : « on
                         // remet le menu liste »). Les deux formes cohabitaient
                         // le temps de l'A/B et le code le disait déjà : « la
                         // colonne est validée, on ne la jette pas sur une
                         // intuition ». La couronne n'est pas supprimée pour
                         // autant — elle se rejoue à son banc `-couronneLab`.
                         //
                         // ⚠️ CE QUI CHANGE DANS LA MAIN, ET C'EST LA SEULE
                         // CHOSE : l'appui TENU faisait éclore la couronne ; la
                         // colonne s'ouvre au TAP. L'appui tenu se retrouve donc
                         // sans emploi — laissé inerte, pas réaffecté au hasard.
                         // Le port libre, le rangement dans le mur, les bornes,
                         // la chute et le néon armé ne dépendent pas du drapeau :
                         // le galet ne sait même pas que le menu a changé.
                         couronne: false,
                         onRange: { galetRange = $0 },
                         // LE GALET S'EFFACE DÈS QUE LA BANDE PARLE. Tiroir
                         // ouvert, la rangée du bas appartient au slider puis au
                         // player : le galet s'encastre dans le mur, sinon il se
                         // pose littéralement DESSUS (vu en capture).
                         rangerDemande: enSeance || tiroirOuvert
                             || vitrineSlot != nil,
                         // Le slider est dans la bande : pendant qu'il est là, le
                         // galet ne dispute plus le doigt. Et pendant la
                         // vitrine, TOUT le bas se tait.
                         verrouille: (tiroirOuvert && !enSeance)
                             || vitrineSlot != nil,
                         reculExterne: reculVitrine) {
                    // ⚠️ LE VOILE NOIR EST MORT (verdict 22-08 : « l'écran noir
                    // non ! »). La card CHAUDE reste, c'est elle la scène.
                    fondPage(e)
                } contenu: {
                    // ⚠️ LA SONDE DU PULL (`-pullSonde <n>`) : elle éteint une
                    // couche à la fois pour savoir laquelle coûte les trous de
                    // 1,3 s mesurés sous le doigt. 1 = pas de mobilier,
                    // 2 = pas de card vidéo, 3 = ni l'un ni l'autre.
                    if Self.pullSonde == 1 || Self.pullSonde == 3 {
                        Color.clear
                    } else {
                    // ⚠️ **LE PONT ANIMATABLE, ENFIN BRANCHÉ** (26-08).
                    // Verdict : « l'arrivée sur la home est trop statique — je
                    // veux une micro-profondeur, un très léger décalage entre
                    // les widgets, les mini-cards qui se mettent en place ».
                    //
                    // Les rangs d'apparition ÉTAIENT déjà écrits (`pose` de la
                    // rangée à `(arrivee − 0,55)/0,30`, celui de la semaine à
                    // `(arrivee − 0,70)/0,30`) — ils ne jouaient simplement
                    // jamais. `CardsRangee` et `SemaineStrip` sont de simples
                    // `View` : sous `withAnimation`, SwiftUI ne réévalue pas le
                    // body à chaque pas, il interpole les MODIFICATEURS. Il
                    // voyait donc une opacité aller de 0 à 1 et la menait
                    // linéairement sur les 1,46 s, en écrasant la fenêtre —
                    // tout ce qui n'est pas la phrase arrivait ENSEMBLE, sans
                    // décalage ni profondeur. C'est le piège que le dépôt
                    // documente lui-même (« les rampes sur p sous withAnimation
                    // ne jouent qu'au doigt ; la forme robuste est une struct
                    // View Animatable sur p ») — et le remède, `Chambre`, était
                    // déjà écrit, déjà payé, déjà en production dans la vitrine.
                    // Il n'a fallu inventer AUCUNE fenêtre : celles qui
                    // existaient se remettent à jouer.
                    //
                    // ⚠️ PAS une `TimelineView` à la place : celle du body de
                    // la home est volontairement pausée au repos, la réveiller
                    // rejouerait le piège de la page ré-évaluée par image.
                    Chambre(p: arrivee) { a in
                        mobilierScene(geo, g, e, a)
                    }
                    }
                }
                // ⚠️ **LE TIRAGE VIT ICI, ET EN SIMULTANÉ** (26-08) — voir la
                // note sur `fondPage`. `.simultaneousGesture` et jamais
                // `.gesture` : posé en exclusif sur la page, il AFFAMERAIT le
                // slider, le galet, les cards et l'ardoise ; en simultané, il
                // écoute par-dessus leur épaule et son verrou d'axe le fait
                // sortir dès que le mouvement n'est pas le sien.
                // ⚠️ **EN SÉANCE, LE TIRAGE SE TAIT** (26-08, verdict n° 1 :
                // « le bouton Stop ne répond pas… je ne peux pas non plus
                // ouvrir / drag le menu correctement »).
                //
                // Le tirage est page-large et son seuil est à 2 pt : en
                // séance, la bande découverte porte LE PLAYER, et le menu
                // vit juste au-dessus. Un drag d'ancêtre qui reconnaît au
                // deuxième point ANNULE le bouton qu'il couvre et vole
                // l'amorce du galet — le stop ne partait pas, le menu ne
                // s'attrapait plus. Or en séance le tiroir est DÉJÀ ouvert
                // (c'est le départ qui l'a levé) : le tirage n'a plus rien à
                // faire, il ne peut que nuire. On le démonte, on ne remonte
                // pas son seuil — la fluidité du pull a été payée en mesures.
                .simultaneousGesture(enSeance ? nil : tirageGeste)
                .overlay {
                    // L'OVERLAY DU DÉPART — déjà écrit (la vidéo de la lune qui
                    // se charge). Le slider l'ouvre, « Commencer » le referme et
                    // lance la séance.
                    DepartPanneauHote(
                        ouverte: DepartEtat.shared.panneauOuvert,
                        onCommencer: { commencer() },
                        onFermer: { DepartEtat.shared.fermer() })
                }
                .overlay {
                    // LA VITRINE — au-dessus de MenuHote (l'école
                    // DepartPanneauHote) : posée dans `contenu:` elle
                    // hériterait du flou du retrait et de l'offset du
                    // tirage. Le widget vole du slot au centre, le carousel
                    // à crans autour de lui.
                    if let vs = vitrineSlot {
                        VitrineHote(slot: vs,
                                    choix: choixPour(vs),
                                    depart: vitrineDepart,
                                    origine: origineSlot(vs, geo.size.height),
                                    faites: faitsAffiche, prevues: prevus,
                                    volume: stats?.volumeValeur ?? "8.4",
                                    volumeUnite: stats?.volumeUnite ?? "kg",
                                    jours: stats?.jours ?? CardJour.semaineRef,
                                    gain: stats?.gain ?? "+12%",
                                    moyenne: stats?.moyenne ?? "1.2 kg",
                                    piedSeances: stats?.pied
                                        ?? "1 session left to hit your goal",
                                    joursFaits: stats?.joursFaits,
                                    moisFaits: stats?.moisFaits,
                                    hiit: stats?.hiit ?? HiitPeakInfo(),
                                    peak: stats?.peak ?? PeakEffortInfo(),
                                    vides: widgetsVides,
                                    auto: VitrineBanc.auto,
                                    onSortie: {
                                        withAnimation(.timingCurve(
                                            0.30, 0, 0.20, 1,
                                            duration: 0.50)) {
                                            reculVitrine = 0
                                        }
                                    },
                                    onFini: { fermerVitrine($0) })
                    }
                }
                // L'encart bas, LU ici et transmis à la card : c'est lui que la
                // marche du padding lui faisait perdre.
                .environment(\.encartBas, geo.safeAreaInsets.bottom)
            }
        }
        // LA FUMÉE DE LA PIÈCE se dessine ICI, au niveau de la page et
        // AU-DESSUS de MenuHote — la grammaire exacte de la v1 : la pièce
        // publie sa place (l'ancre traverse toute la hiérarchie), et le
        // nuage — qui déborde de près de cent points — s'étale sans
        // rencontrer le bord d'un hôte qui l'aurait tranché au couteau.
        // Palette CLAIRE, et c'est MESURÉ : la sombre — composée « à peine
        // plus claire que la nuit » pour la page du trésor — culmine ici à
        // 0,45/255 de moyenne dans l'anneau de la pièce, c'est-à-dire
        // nulle part. Le coin est noir absolu : seule une fumée pâle y
        // existe, et son gain de 0,30 la garde en souffle, pas en nuage.
        .overlayPreferenceValue(CoffreFortCoinBounds.self) { anchor in
            GeometryReader { proxy in
                if let anchor, let fumeePiece {
                    let box = proxy[anchor]
                    CoinSmoke(center: CGPoint(x: box.midX, y: box.midY),
                              radius: CoffreFortCoinButton.diameter / 2,
                              start: fumeePiece, end: fumeePieceFin,
                              palette: .light)
                }
            }
            .allowsHitTesting(false)
        }
        // Plein écran, pas une feuille : la cinématique du trésor doit
        // couvrir TOUTE la page (la loi de la v1 — une cinématique avec du
        // mobilier qui flotte par-dessus n'est plus une cinématique).
        .fullScreenCover(isPresented: $cheminOuvert) {
            // §23 — LE CHEMIN. La page est agnostique : le chevron ferme,
            // le panneau confirmé démarre la séance et pose la RED PAGE
            // EXO par-dessus (cover imbriqué — le retour de l'exo replie
            // tout jusqu'à la home, card levée).
            ZStack {
                if cheminDemonte {
                    Color.black.ignoresSafeArea()
                } else {
                    DuolinguoPage(onRetour: { cheminOuvert = false },
                                  onDemarrer: { demarrerDepuisChemin() })
                }
            }
                .environment(\.colorScheme, .dark)
                .fullScreenCover(isPresented: $exoOuvert) {
                    ExercisesView(selection: Binding(
                        get: { .exercises },
                        set: { nouveau in
                            if nouveau == .home {
                                exoOuvert = false
                                cheminOuvert = false
                            }
                        }))
                        .environment(\.colorScheme, .dark)
                }
        }
        .fullScreenCover(isPresented: $coffreOuvert) {
            CoffreFortFlow(
                // La règle des pièces : 20 par SÉRIE faite — le trésor
                // compte les séries de toutes les séances terminées.
                coins: CoffreFortPurse.coins(
                    doneSeries: workoutsBruts
                        .filter { !$0.isActive }
                        .flatMap { $0.exercises ?? [] }
                        .reduce(0) { $0 + $1.completedSets })
            ) {
                coffreOuvert = false
            }
        }
        // ⚠️ **LE BORD BAS EST À NOUS D'ABORD** (26-08). Le screenshot où TOUT
        // l'écran de l'iPhone descend — status bar et Dynamic Island comprises,
        // chevron gris au-dessus — n'est pas un bug de Woop : c'est la
        // REACHABILITY d'iOS. Vérifié : aucune feuille système sur le chemin de
        // la home v2, aucune transformation de fenêtre, et le seul chevron de
        // la page est blanc et en bas — le code ne peut pas produire cette
        // image. Or le geste qu'on demande ici (tirer vers le bas) commence
        // naturellement à 24-34 pt du bord bas, c'est-à-dire PILE dans la bande
        // que le système se réserve.
        //
        // `defersSystemGestures` ne DÉSACTIVE pas la Reachability — aucune app
        // ne le peut, et c'est un réglage d'accessibilité qui appartient à
        // l'utilisatrice. Elle la DIFFÈRE : le premier glissement depuis ce
        // bord revient à la page, il en faut un second pour réveiller le
        // système. Le vrai filet reste le chien de garde du geste : même volé,
        // le doigt ne doit plus laisser la page cassée derrière lui.
        .defersSystemGestures(on: .bottom)
        // `-fps` : la sonde de cadence (le SEUL juge fiable du « ça lag »).
        .sondeCadence("home")
        .onAppear {
            guard !deja else { return }
            deja = true
            // La séance tournait déjà au lancement : la card est LEVÉE dès la
            // première image, sans animation — on ne rejoue pas une
            // cinématique pour un état qu'on ne fait que retrouver.
            if enSeance { tirage = reposCard }
            // `-tiroirOuvert` : le tiroir déjà tiré, pour juger le slider
            // dans la bande sans doigt.
            // §23 banc : `-homeChemin` — la porte du chemin déjà ouverte
            // (le film de l'arrivée + panneau sans doigt).
            if CommandLine.arguments.contains("-homeChemin") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    cheminOuvert = true
                }
            }
            if CommandLine.arguments.contains("-tiroirOuvert"), !enSeance {
                tiroirOuvert = true
                tirage = reposCard
            }
            // `-coffreSmoke` : la bouffée part SEULE, deux secondes après
            // l'arrivée, et la page du trésor ne s'ouvre pas (c'est l'action
            // du bouton, pas le toucher, qui l'ouvre). Le simulateur ne sait
            // pas poser un doigt — sans ce banc, la fumée n'est vérifiable
            // que sur l'appareil. Le même nom que la v1 : même bouffée.
            if CommandLine.arguments.contains("-coffreSmoke") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    toucherPiece(true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        toucherPiece(false)
                    }
                }
            }
            // `-departAuto` : LE FILM REJOUÉ EN BOUCLE. Le simulateur ne sait
            // pas poser un doigt — et une cinématique de 1,95 s ne se juge pas
            // sur des images fixes : on ne voit ni le rythme, ni les
            // atterrissages décalés, ni un palier de décodage. Sans ce banc, on
            // signe une scène qu'on n'a jamais regardée bouger.
            // Cycle : 1,2 s de repos · le film · 1,4 s de pose · la fermeture.
            // `-homeMenuAuto` : la colonne s'ouvre et se referme toute seule.
            // ⚠️ Un nom à elle, pas `-menuRejoue` : celui-là est intercepté plus
            // haut par `WoopApp` et monte `MenuLab` À LA PLACE de la home.
            // Le simulateur ne sait pas poser un doigt et `simctl` n'a pas de
            // commande `tap` — sans ce banc, le menu de la home n'est jugeable
            // qu'à la main, donc jamais en capture.
            if CommandLine.arguments.contains("-homeMenuAuto") {
                Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                    menuOuvert.toggle()
                }
            }
            // ⚠️ **LE BANC DU DOIGT** (`-pullAuto`) : il écrit `tirage` à 60 Hz
            // exactement comme le ferait un pouce — aller-retour continu sur la
            // course du tiroir. C'est le SEUL moyen de mesurer le régime qui
            // lague : `simctl` ne sait pas poser un doigt, et un verdict « pas
            // fluide » sans chiffre ne se répare pas, il se devine.
            if CommandLine.arguments.contains("-pullAuto") {
                let t0 = Date()
                Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0,
                                     repeats: true) { _ in
                    let e = Date().timeIntervalSince(t0)
                    // Un va-et-vient de 2,4 s sur toute la course.
                    let u = (sin(e * 2 * .pi / 2.4) + 1) / 2
                    tirageDebut = .zero          // le banc « pose le doigt »
                    tirage = -CGFloat(u) * Self.leveeTiroir
                }
            }
            if CommandLine.arguments.contains("-departAuto") {
                Timer.scheduledTimer(withTimeInterval: 5.5, repeats: true) { _ in
                    lancer(gDepart: 0)
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + DepartCine.T + 1.4) { fermer() }
                }
            }
            if CommandLine.arguments.contains("-camTest") {
                Timer.scheduledTimer(withTimeInterval: 2.4,
                                     repeats: true) { _ in
                    withAnimation(.timingCurve(0.25, 0.1, 0.25, 1,
                                               duration: 1.1)) {
                        tiroirOuvert.toggle()
                        tirage = tiroirOuvert ? -Self.leveeTiroir : 0
                    }
                }
            }
            jouerArrivee()
            jouerGaletBanc()
            jouerSemaineBanc()
            jouerEditionBanc()
            // LES VRAIES DONNÉES — une fois, ici. Les widgets neufs (HIIT
            // Peak, Peak Effort) tombent sur leurs défauts si le calcul ne
            // trouve rien (base vide, pas de cardio…).
            if !workoutsBruts.isEmpty {
                stats = SemaineStats.calcule(workoutsBruts, prevues: prevus)
            }
        }
        // ⚠️ **LA HOME SE REMET DEBOUT À LA CLÔTURE** (26-08). Elle ne le
        // faisait NULLE PART : après « Terminer », la racine écrivait bien
        // `endedAt` en base, mais la page restait dans son état de séance —
        // player fantôme, widgets démontés, tiroir ouvert, pull sorti avant
        // le cran. Un SEUL `onChange`, une SEULE transaction.
        // LES DEMANDES DE LA RANGÉE — elle ne porte plus les actions, elle les
        // demande ; c'est ici qu'on exécute. Ce `onChange` ne se réveille qu'au
        // TAP, jamais pendant un geste.
        .onChange(of: demandes.jeton) { _, _ in
            switch demandes.derniere {
            case .edition: entrerEdition()
            case .pastille(let i): ouvrirListe(i)
            case .fantome(let i): ouvrirVitrine(i)
            case .sortieEdition: sortirEdition()
            case .none: break
            }
        }
        .onChange(of: enSeance) { _, encore in
            guard encore else { rendreLaHome(); return }
            // LA SÉANCE TOURNAIT DÉJÀ AU LANCEMENT. Le `@Query` n'est
            // renseigné qu'APRÈS la première image : la card naît basse, on
            // apprend la séance à l'image d'après, et elle se lève.
            // ⚠️ Pas de `initial: true` : au lancement sans séance, il ferait
            // tourner `rendreLaHome()` avant même l'`onAppear`, et le banc
            // `-tiroirOuvert` serait défait par sa propre page.
            // ⚠️ Les gardes empêchent la DOUBLE levée : les deux départs
            // lèvent déjà la card eux-mêmes (le tiroir est ouvert, ou la
            // course est posée), et deux animations sur `tirage` se
            // dévoreraient.
            guard tirage == 0, !tiroirOuvert,
                  depart == nil, ferme == nil else { return }
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62)) {
                tirage = reposCard
            }
        }
    }

    /// LE RETOUR À L'ÉTAT POSÉ, après une séance qui vient de se clore.
    ///
    /// ⚠️ **CE N'EST PAS `fermer()`** : celle-là joue un film de 1,25 s à
    /// rebours (elle défait une cinématique de départ qu'on est en train de
    /// regarder). Ici il n'y a rien à défaire — on RETROUVE un état, on ne
    /// rejoue pas une cérémonie. Un fondu court, et la page est là.
    ///
    /// ⚠️ **UN SEUL `withAnimation` SUR `tirage`** : deux au même tour sur la
    /// même valeur ne jouent rien (la loi payée du dépôt), et un aller-retour
    /// se ferait en keyframes — ce n'en est pas un.
    private func rendreLaHome() {
        // Les horloges du film d'abord, hors animation : elles ne se
        // fondent pas, elles s'éteignent.
        depart = nil
        ferme = nil
        eGele = nil
        gCran = 0
        // Le geste, remis à plat — sinon le premier tirage d'après hérite
        // d'un axe et d'une course périmés (c'est le même trou que celui
        // du geste annulé).
        axeVertical = nil
        cranSenti = false
        luneSentie = false
        // ⚠️ LE VERRE REMONTE, ET C'EST LUI QUI REND LES WIDGETS : les deux
        // rangées ne sont montées que `if verreMonte`, que le film de départ
        // avait posé à `false` et que SEULE `fermer()` remontait — jamais
        // appelée sur le chemin slider → chemin → séance → fin. C'est la
        // cause entière de la « home vide » du verdict.
        verreMonte = true
        withAnimation(.easeOut(duration: 0.34)) {
            tiroirOuvert = false
            tirage = 0
            if PhraseHorloge.forceScroll == nil { scroll = 0 }
        }
        // La semaine vient de changer d'une séance : les widgets doivent le
        // dire au retour, pas au prochain lancement.
        if !workoutsBruts.isEmpty {
            stats = SemaineStats.calcule(workoutsBruts, prevues: prevus)
        }
    }

    /// LE FOND : la bande révélée tout au fond, la card par-dessus, et le
    /// geste du tirage — il couvre toute la page, et les gestes des enfants
    /// (le slider, le galet) gagnent sur lui.
    private func fondPage(_ e: Double) -> some View {
        ZStack(alignment: .topLeading) {
                // LE SECRET, tout au fond : la card le couvre au repos, et
                // le tirage vers le bas le découvre.
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if enSeance {
                        // LE PLAYER — la dalle de la maison, déjà écrite
                        // (`WorkoutPill(docked:)`). Un seul geste, une seule
                        // bande : hors séance le secret, en séance le player.
                        WorkoutPill(exercise: ExerciseCatalog.all[0],
                                    startedAt: debutSeance,
                                    docked: true,
                                    lisere: false)
                            .opacity(playerP)
                            .offset(y: 16 * (1 - playerP))
                    } else {
                        ZStack {
                            // LA LUNE — le secret d'aujourd'hui, intact
                            // pendant toute la montée. Elle s'efface quand la
                            // piste arrive : le secret DEVIENT la clé.
                            // ⚠️ ELLE SE COUCHE, ELLE NE SE COUPE PLUS. Le
                            // `tiroirOuvert ? 0 : 1` l'éteignait en UNE image,
                            // et elle n'était animée que par le ressort du
                            // lâcher — supprimé. Sa fenêtre comble en plus le
                            // trou de la bande : elle la tient jusqu'à 0,45 s,
                            // le slider n'entre qu'à 0,95.
                            LuneSecrete(p: luneP)
                                .opacity(1 - DepartCine.sstep(0, 0.45, e))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .center)
                // ⚠️ Les 46 pt appartiennent à la LUNE, pas à la bande : le
                // slider les ajoutait aux siens (46 + 26 = 72) et passait
                // 18 pt DERRIÈRE la card, donc invisible.
                // ⚠️ Le player ne touche PAS le bord : à ras, son bouton
                // stop et le départ de la veine se collaient à l'arête
                // physique. 14 pt le décollent, et la levée grandit d'autant
                // pour garder l'air sous la card.
                .padding(.bottom, enSeance ? 14 : (tiroirOuvert ? 0 : 46))
                .ignoresSafeArea(edges: .bottom)

                // TOUTE LA HOME EST UNE CARD, ET ELLE SE TIENT : le drag la
                // déplace EN BLOC (fond vidéo, phrase, semaine) avec une
                // résistance d'élastique, et elle revient en ressort —
                // l'école de la carte dépliable du profil. La couche
                // révélée dessous (le player en séance, la surprise) vient
                // au jalon V5 : le geste, lui, est déjà le bon.
                Group {
                    if FondBanc.rasant {
                        HomeNuitFond(p: rasantNe)
                    } else {
                        // ⚠️ LA CARD SE RACCOURCIT TOUJOURS — c'est son ARÊTE
                        // BASSE, avec ses coins, qui dit qu'elle est une
                        // card. En la laissant courir jusqu'au bord de
                        // l'écran (essayé pour « pas de fond noir »), on
                        // supprime la seule chose qui lui donne une forme, et
                        // la page n'a plus d'objet. Le noir sous elle n'est
                        // pas un fond : c'est la PAGE, et c'est là que vit le
                        // slider.
                        if Self.pullSonde == 2 || Self.pullSonde == 3 {
                            Color(white: 0.05)
                        } else {
                        GrandeCardVideo(naissance: naissance,
                                        // LA PILULE EN DERNIER : elle n'entre
                                        // qu'une fois la phrase posée et les
                                        // widgets en place — fenêtre 0,80 →
                                        // 1,00 de l'arrivée, la plus tardive
                                        // de la partition (les widgets sont à
                                        // 0,55, la semaine à 0,70).
                                        pilule: PilP.entree(arrivee),
                                        levee: max(-tirage, 0),
                                        e: e)
                        }
                    }
                }
                // Le tirage vers le BAS déplace toujours toute la home (« je
                // dois pouvoir drag toute la home », validé). Le tirage vers
                // le HAUT, lui, ne déplace plus rien : il raccourcit.
                .offset(y: max(tirage, 0))
        }
        .contentShape(Rectangle())
        // ⚠️ **LE GESTE N'EST PLUS ICI** (26-08). `fondPage` est la couche de
        // FOND de `MenuHote` : elle vit SOUS tout le mobilier. Le tirage
        // n'attrapait donc le doigt que sur les rares zones où rien n'est
        // dessiné — cards, ardoise de la semaine, minis, galet, pièce et
        // nombre de l'objectif se le prenaient les uns après les autres — et
        // le retour, doigt posé sur la card, ne fonctionnait quasiment jamais.
        // Il est monté d'un cran, en geste SIMULTANÉ sur le résultat de
        // `MenuHote` : il couvre la page entière et cohabite avec les gestes
        // des enfants au lieu de leur perdre le doigt (son verrou d'axe le
        // rend inoffensif pour tout ce qui glisse à l'horizontale).
    }

    // ⚠️ `mobilier(_:)` et son `Chambre(p: scene)` sont MORTS. `Chambre` est
    // `Animatable` : elle ne sert qu'à une valeur animée par une TRANSACTION.
    // Nourrie par une horloge elle ne joue rien — c'est l'unique
    // `TimelineView` du `body` qui livre `e` image par image, maintenant.

    /// LES FENÊTRES DE LA CAMÉRA. L'ordre n'est pas décoratif : **le NET part
    /// avant la géométrie**, et le noir arrive AVANT les mots — la loi de la
    /// maison, la lumière avant le texte.
    private func fenScene(_ s: Double, _ a: Double, _ b: Double) -> Double {
        min(max((s - a) / (b - a), 0), 1)
    }

    /// LES TROIS LIGNES de la phrase d'arrivée. ⚠️ TROIS, mesuré à la vraie
    /// fonte (Inter-SemiBold 30 pt sur 330 pt de large : 316 / 313 / 147). Toute
    /// cote calculée sur deux lignes est fausse de 38 pt.
    /// ⚠️ EN ANGLAIS, ET EN ALTERNANCE CLAIR / SOURD comme la phrase d'accueil.
    /// C'est le même bloc qui a voyagé : il doit garder sa voix, son rythme et
    /// son contraste, pas seulement son corps et sa gouttière.
    /// Le sourd est plus haut ici (0,62 contre 0,42) : le bloc atterrit sur la
    /// BRAISE, pas sur la nuit — un gris de nuit s'y ferait manger.
    /// Seule la PREMIÈRE ligne change ; les deux autres sont la charnière de la
    /// phrase et ne bougent pas. Tirée dans `lancer()`, jamais dans un `body`.
    @State private var ligneUne = DepartMots.lignes[0]
    @State private var libelleSlider = DepartMots.boutons[0]
    private var motsArrivee: [(String, Bool)] {
        [(ligneUne, true), ("slide to start", false), ("your session.", true)]
    }

    @ViewBuilder
    private func mobilierScene(_ geo: GeometryProxy,
                               _ g: Double,
                               _ e: Double,
                               _ arr: Double) -> some View {
        // ── CE QUE FAIT LE DOIGT, ET RIEN D'AUTRE ────────────────────────────
        // Le net décroche sous le pouce, et il finit tout seul au cran (ou fait
        // tout le chemin au TAP, qui n'a pas de doigt). D'où le `max` : les deux
        // chemins produisent la MÊME scène, la partition faisant elle-même le
        // travail que le doigt aurait fait.
        //
        // ⚠️ TROIS RAYONS DIFFÉRENTS, PAS UN SEUL. Trois plans au même rayon,
        // c'est un MASQUE ; trois rayons différents, c'est une PROFONDEUR DE
        // CHAMP. C'est la définition numérique du verdict « des éléments
        // masqués ». (Le 6 est un plafond DUR : un blur sur du verre natif
        // empile deux passes.)
        let net = max(min(g / 0.45, 1), DepartCine.sstep(0, DepartCine.netFor, e))
        // SONDE 4 : le mobilier reste MONTÉ, mais ses flous meurent sous le
        // doigt. Elle tranche la question « est-ce la construction de l'arbre
        // ou le RENDU des passes hors écran qui coûte ? ». Le banc `-pullAuto`
        // pose lui aussi `tirageDebut` : sans ça la sonde ne verrait rien.
        // ⚠️ **LE VERRE NE SE FLOUTE PAS PENDANT QU'ON LE DÉPLACE** (26-08) —
        // et c'est LA cause du « gros problème de fluidité » du pull.
        //
        // Le fichier savait déjà que ce flou-là est cher : « un blur posé sur
        // du VERRE NATIF empile deux passes — c'est l'opération la plus chère
        // de la page ». Il l'avait plafonné à 6 pt. Il l'avait laissé VIVANT
        // sous le doigt.
        //
        // SONDE DE CADENCE, home pendant un tirage (banc `-fps -pullAuto`,
        // bisection `-pullSonde`) :
        //     tout monté ................  36,8 img/s · min 6,5 · trou 681 ms
        //     sans le mobilier ..........  60,0        · min 51  · trou 170 ms
        //     flou des WIDGETS coupé ....  53,5        · min 39  · trou 359 ms
        //     flou de la semaine coupé ..  35,6        · min 7,0 · trou 566 ms
        //     flou de la pièce coupé ....  36,0        · min 7,3 · trou 563 ms
        // Un trou de 681 ms, c'est plus d'une demi-seconde sans une image
        // pendant que le doigt bouge : voilà « parfois rien ne se passe »,
        // voilà pourquoi un TAP marchait mieux qu'un drag (un événement
        // survit, soixante non), et voilà pourquoi le pouce glissait jusque
        // dans la bande de la Reachability.
        //
        // ⚠️ ET ON FLOUTAIT DU VIDE : l'opacité vaut `1 − net`, donc au moment
        // où le flou atteint son maximum la card est TRANSPARENTE. On payait
        // deux passes hors écran pour flouter quelque chose d'invisible.
        //
        // La loi appliquée est celle de la maison, déjà écrite sur le bijou
        // de la fiche exo : « EN COURSE, le bijou allège sa parure — la
        // fluidité prime sur des détails que l'œil ne voit pas en mouvement ».
        // Sous le doigt : pas de flou. Le recul se dit par l'opacité et
        // l'offset, qui ne coûtent rien. Au lâcher il n'y a AUCUN pop : le
        // geste finit soit fermé (net = 0, flou nul de toute façon), soit
        // ouvert (net = 1, opacité nulle). Et pendant le FILM — le moment où
        // l'on REGARDE la dissolution — la profondeur de champ joue en entier.
        // `-flouAvant` : l'A/B sur le MÊME binaire — les deux flous
        // reprennent leur comportement d'avant le 26-08. C'est comme ça qu'on
        // mesure un avant/après sur l'appareil sans rebâtir l'histoire (le
        // commit d'avant ne compile pas seul : du travail d'une autre session
        // y manque).
        let enGeste = tirageDebut != nil && !FlouBanc.avant
        let flouCards: CGFloat = enGeste ? 0 : coefSonde(5)
        let flouSemaine = coefSonde(6), flouPiece = coefSonde(7)
        // ── CE QUE FAIT L'HORLOGE ────────────────────────────────────────────
        let chute = DepartCine.chuteTexte(e)
        let flou = DepartCine.sstep(DepartCine.flouAt,
                                    DepartCine.flouAt + DepartCine.flouFor, e)
        let mort = DepartCine.sstep(DepartCine.fadeAt,
                                    DepartCine.fadeAt + DepartCine.fadeFor, e)
        let slid = DepartCine.slider(e)
        // ⚠️ **UN SEUL BLOC QUI SE TRANSFORME, PLUS DEUX QUI SE CROISENT**
        // (verdict 22-08 : « que ça soit bien ce texte qui s'écrit / qui se
        // transforme du blur, et pas l'autre texte qui vient du bas »).
        //
        // Avant : l'ancien mourait en vol et le nouveau NAISSAIT EN BAS en
        // montant de 90 pt. On voyait donc un départ et une arrivée — deux
        // objets — au lieu d'une métamorphose.
        //
        // Maintenant : les deux textes occupent **le même cadre**, partagent
        // **le même offset**, et l'échange des mots est CACHÉ AU SOMMET DU FLOU.
        // C'est la seule façon honnête : on ne voit pas un objet changer de
        // mots, on le voit sortir du net et revenir au net en disant autre
        // chose. Et à 26 pt de rayon, la différence de hauteur entre 5 lignes et
        // 3 est invisible — c'est ce qui permet de changer le nombre de lignes
        // sans que le bloc saute.
        let cloche = DepartCine.clocheTexte(e)          // 0 → 26 → 0
        let bascule = DepartCine.bascule(e)             // le fondu croisé, 0,12 s
        ZStack(alignment: .topLeading) {
            // LA PHRASE D'ARRIVÉE. ⚠️ MÊME CORPS, MÊME GRAISSE, MÊME GOUTTIÈRE
            // que la phrase d'accueil (30 semibold, 24 pt de marge) : c'est LE
            // MÊME BLOC qui a voyagé et changé de mots — maintenant pour de bon.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(motsArrivee.enumerated()), id: \.offset) { i, m in
                    // LA POSE, LIGNE PAR LIGNE (verdict 22-08 : « plus
                    // cinématique douce type Apple quand le texte arrive en
                    // bas »). Le bloc revenait au net d'un seul coup — trois
                    // lignes qui redeviennent nettes ENSEMBLE, c'est un
                    // interrupteur. Décalées de 0,10 s, c'est une vague.
                    // ⚠️ Le retard ne joue QUE sur la remontée au net : à la
                    // descente les trois lignes floutent ensemble, sinon le bloc
                    // se déchire.
                    let r = Double(i) * 0.10
                    let net = DepartCine.poseLigne(e, retard: r)
                    Text(m.0)
                        .font(.inter(30, .semibold))
                        .foregroundStyle(.white.opacity(m.1 ? 0.94 : 0.62))
                        // Le flou vit sur les GLYPHES. Posé sur un conteneur il
                        // pose un voile clair uniforme aux coins carrés, que ni
                        // masque ni blend ne rattrapent (piège payé).
                        .blur(radius: net > 0.995 ? 0
                              : max(cloche, DepartCine.flouMax * (1 - net)))
                        .offset(y: 9 * (1 - net))
                }
            }
                .fixedSize(horizontal: false, vertical: true)
                .opacity(bascule * DepartCine.matiere(e))
                // ⚠️ ELLE EST ÉPINGLÉE À LA SAFE AREA, PAS À L'ARÊTE. Sa marge
                // au-dessus de l'arête vaut `encart − levée + padBottom` : la
                // règle `padBottom = levée + 6` la pose à 40 pt de l'arête, et
                // elle ne tient QUE depuis que le raccourcissement est linéaire
                // (avant, la marche des 34 pt la ramenait à 6 pt : « le texte
                // dépasse la card »).
                .frame(width: geo.size.width - 72, alignment: .leading)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .bottomLeading)
                .padding(.leading, 24)
                .padding(.bottom, Self.leveeTiroir + 6)
                // ⚠️ LE MÊME BAS QUE LA PHRASE D'ACCUEIL, À CHAQUE IMAGE. Elle
                // est posée à sa place FINALE, donc on la recule de toute la
                // course et on la ramène : `chute − course`. L'accueil, lui, est
                // posé à sa place de DÉPART et avance de `chute`. Leurs bas sont
                // alors confondus en permanence — c'est ce qui autorise le fondu
                // croisé à n'importe quel instant sans que la dernière ligne,
                // celle qu'on lit, ne bouge d'un pixel.
                .offset(y: chute - DepartCine.courseTexte)
                .allowsHitTesting(false)

            // LE SLIDER VIT DANS L'ESPACE NOIR SOUS LA CARD — celui que la
            // card ouvre en se raccourcissant, jamais une nappe posée sur la
            // page. C'est le MÊME espace que le player en séance : un seul
            // endroit, trois contenus, et la cohérence d'expérience avec lui.
            SliderObsidienne(label: libelleSlider,
                             height: 62,
                             // §23 : la course validée ouvre LE CHEMIN —
                             // le panneau du galet reprend la proposition
                             // (l'overlay lune du départ reste au banc).
                             onConfirm: { ouvrirChemin() })
                // ⚠️ 12 ET NON 24 (verdict 22-08 : « il doit quasi faire tout
                // l'écran, s'arrêter aux petites bordures noires »). Contrôle
                // géométrique : le point le plus à gauche de la capsule est
                // (12, 799) ; le coin de l'écran a son centre en (55, 819) et
                // 55 de rayon ; la distance vaut 47,4 < 55 — la capsule reste
                // DANS l'écran, elle ne mord pas sur l'arrondi.
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity,
                       alignment: .bottom)
                // 10 pt sous la safe area, et c'est l'air du HAUT qui commande :
                // la gerbe de poudre du commit monte à 33,8 pt hors cadre, il
                // lui faut donc 34 entre l'arête de la card (734) et le haut du
                // slider. 734 + 34 + 62 = 830, et 840 − 830 = 10.
                // Le slider occupe donc **768..830**.
                .padding(.bottom, 10)
                // ⚠️ IL MONTE, IL NE S'ESSUIE PLUS. Le `scaleEffect(x:)` était
                // un essuie-glace : la capsule est peinte par un SDF, et un
                // scale en x change le rayon apparent de ses calottes, la
                // géométrie de son spéculaire et l'étalement de son ombre à
                // CHAQUE image — on regardait la matière se déformer pendant
                // 0,6 s. Une échelle UNIFORME de 0,93 dit la même chose en
                // disant la vérité.
                .opacity(DepartCine.sstep(DepartCine.slidAt,
                                          DepartCine.slidAt + 0.53, e))
                .scaleEffect(0.93 + 0.07 * slid, anchor: .bottom)
                .offset(y: 30 * (1 - slid))
                .blur(radius: slid > 0.96 ? 0 : 7 * (1 - slid))
                .allowsHitTesting(e > 1.88)
                Group {
                    PhraseVue(p: arr, flouDepart: cloche
                                + 3.5 * min(g / 0.37, 1),
                              params: phrase, rasant: rasant,
                              fragments: PhraseTexte.fragments(
                                faits: faitsAffiche, prevus: prevus),
                              ecran: geo.size.width,
                              hautEcran: geo.safeAreaInsets.top + 48,
                              galet: galet,
                              objectif: $prevus,
                              reglageOuvert: $reglageOuvert)
                        .padding(.leading, 24)
                        // 56 pt sous la barre. Le ScrollView est MORT (la
                        // home tient sur un écran, c'est le TIRAGE qui la
                        // déplace) : plus d'`ignoresSafeArea`, le padding
                        // se mesure depuis la safe area — 48 nu.
                        .padding(.top, 48)
                        // ⚠️ LE PREMIER PALIER SE JOUE SOUS LE DOIGT (0 → 3,5 pt)
                        // et il dit « la pièce change » ; le second (→ 22) dit
                        // « ce plan est parti ». Le flou vit sur les GLYPHES —
                        // `PhraseVue` le pose ligne par ligne, jamais sur un
                        // conteneur.
                        // Le premier palier se joue SOUS LE DOIGT (0 → 3,5 pt) :
                        // il dit « la pièce change ». Ensuite c'est LA MÊME
                        // CLOCHE que la phrase d'arrivée — le même flou, sur ce
                        // qui est désormais le même bloc.
                        // ⚠️ **LA CLOCHE EST PARTIE SUR LES GLYPHES** (param
                        // `flouDepart` de `PhraseVue`), et il ne reste ici que
                        // la dissolution du scroll. Posée sur le CONTENEUR, elle
                        // gonflait ses bornes de ±78 px et floutait 1,47 Mpix par
                        // image, par-dessus la passe de masque que `PhraseVue`
                        // pose déjà — le piège exact que ce fichier dénonce trois
                        // lignes plus haut.
                        .blur(radius: dissolution)
                        // ⚠️ ELLE NE MEURT PLUS EN VOL : ELLE SE CHANGE. Son
                        // extinction EST le fondu croisé — 0,12 s au sommet du
                        // flou — et l'autre bloc prend sa place au même endroit,
                        // au même instant, avec le même bas. C'était la demande :
                        // un texte qui se transforme, pas un texte remplacé.
                        .opacity((1 - 0.70 * min(max((scroll - 40) / 120, 0), 1))
                                 * (1 - bascule)
                                 * DepartCine.matiere(e))
                        // Elle descend de 403 pt : de sa place (bas à 291)
                        // jusqu'à celle de la phrase d'arrivée (bas à 694). Plus
                        // loin que la pilule (334) — le plan du devant va plus
                        // loin que celui du fond, c'est la parallaxe, et elle est
                        // dans le bon sens.
                        .offset(y: chute)
                        // Le plan traîne : 14 % de retard sur le tirage —
                        // la parallaxe INTERNE de la card.
                        .offset(y: -scroll * (1 - phrase.plan))
                        .opacity(RasantHorloge.iso ? 0 : 1)

                    // LES DEUX CARDS (jalon V3) : les séances et le volume.
                    // TOUT EN VERRE (verdict 22-08, et il renverse ma
                    // prudence) : le givre ne vient PAS du verre, il vient de
                    // l'encre placée SOUS lui. Ici l'encre de chaque card est
                    // au-dessus de son propre verre — il n'a donc que la vidéo
                    // à manger, et c'est exactement ce qu'on veut voir bouger
                    // dessous. Le liseré angulaire reste : c'est par ses
                    // BORDS qu'un Liquid Glass se lit, jamais par son corps.
                    // ⚠️ **LE VERRE EST DÉMONTÉ, PAS ÉTEINT.** `verreAt = 0.26`
                    // était déclaré et lu NULLE PART : les deux cards gardaient
                    // leur `glassEffect(.clear)` ET leur gaussienne de 6 pt
                    // pendant 1,69 s des 1,95 s du film, à opacité ZÉRO. Une
                    // capture de fond de verre natif force la résolution en
                    // texture de tout le composite situé dessous — donc de toute
                    // la chaîne vidéo — deux fois par image, pour peindre du
                    // vide. Le dépôt le savait déjà (MenuCouronne garde son
                    // disque par `if p > 0.01`), la leçon n'avait pas été portée
                    // ici.
                    if verreMonte {
                    CardsRangee(faites: faitsAffiche, prevues: prevus,
                                volume: stats?.volumeValeur ?? "8.4",
                                volumeUnite: stats?.volumeUnite ?? "kg",
                                moyenne: stats?.moyenne ?? "1.2 kg",
                                gain: stats?.gain ?? "+12%",
                                jours: stats?.jours ?? CardJour.semaineRef,
                                pied: stats?.pied
                                    ?? "1 session left to hit your goal",
                                joursFaits: stats?.joursFaits,
                                moisFaits: stats?.moisFaits,
                                hiit: stats?.hiit ?? HiitPeakInfo(),
                                peak: stats?.peak ?? PeakEffortInfo(),
                                arrivee: arr, lisere: true, verre: true,
                                slots: slots,
                                vides: widgetsVides,
                                edition: editionP,
                                editionActive: edition,
                                masque: vitrineSlot,
                                // ⚠️ UNE RÉFÉRENCE STABLE, PLUS QUATRE
                                // CLOSURES — voir `DemandesCards` : c'était
                                // la cause mesurée des trous de 681 ms sous
                                // le doigt.
                                demandes: demandes,
                                editable: true)
                        .environment(\.harmonieInter, true)
                        .padding(.leading, 24)
                        .padding(.top, geo.size.height * 0.375)
                        .offset(y: 8 * net)
                        // ⚠️ FLOU PLAFONNÉ À 6 pt. Un blur posé sur du VERRE
                        // NATIF empile deux passes de flou — c'est
                        // l'opération la plus chère de la page, et au-delà de
                        // 6 pt on ne distingue plus rien : on payait pour du
                        // vide, à chaque image du tirage.
                        .blur(radius: 6 * net * flouCards)
                        .opacity(1 - net)
                        // ⚠️ ELLES NE SONT PLUS SOURDES. Le `false` datait du
                        // temps où les cards n'étaient que du mobilier ; avec
                        // la chambre noire elles répondent au doigt, et il
                        // n'atteignait tout simplement jamais leur geste.
                        .opacity(RasantHorloge.iso ? 0 : 1)
                    }

                    // LA SEMAINE — la 3e card : son tap ouvre LE CHEMIN
                    // (§23, sa demande : « celle avec les mini cards des
                    // dates »). Les minis garderont leur story au jalon
                    // flow ; aujourd'hui la card entière est la porte.
                    if verreMonte {
                    SemaineStrip(faits: faitsAffiche, prevus: prevus,
                                 arrivee: arr,
                                 materialises: materialises,
                                 lisere: true, verre: true)
                        .contentShape(RoundedRectangle(cornerRadius: 22))
                        .onTapGesture { ouvrirChemin() }
                        .padding(.leading, 24)
                        .padding(.top, geo.size.height * 0.620)
                        .offset(y: 8 * net)
                        // ⚠️ FLOU PLAFONNÉ À 6 pt. Un blur posé sur du VERRE
                        // NATIF empile deux passes de flou — c'est
                        // l'opération la plus chère de la page, et au-delà de
                        // 6 pt on ne distingue plus rien : on payait pour du
                        // vide, à chaque image du tirage.
                        .blur(radius: 6 * net * flouSemaine)
                        .opacity(1 - net)
                        .opacity(RasantHorloge.iso ? 0 : 1)
                    }

                    // LE MODE ÉDITION — la drop-list pendue à la pastille,
                    // la poudre d'une suppression, le refus du dernier
                    // widget. Tous aux coordonnées de la rangée (les mêmes
                    // ancres : leading 24 + 184 par slot, top 0,375 × h).
                    if listeSlot != nil || listeP > 0.005 {
                        let ls = listeSlot ?? 0
                        Chambre(p: listeP) { lp in
                            ListeEdition(p: lp,
                                         onChanger: { ouvrirVitrine(ls) },
                                         onSupprimer: { supprimerWidget(ls) })
                        }
                        // Pendue par son bord DROIT à la pastille (la
                        // grammaire du panneau de l'objectif), clampée à
                        // 12 pt du bord de l'écran.
                        .padding(.leading,
                                 min(24 + CGFloat(ls) * 184 + 181,
                                     geo.size.width - 12)
                                 - ListeEdition.largeur)
                        .padding(.top, geo.size.height * 0.375 + 14)
                    }
                    if let ps = poudreSlot {
                        PoudreAdieu(depuis: poudreDepuis)
                            .frame(width: 230, height: 230)
                            .padding(.leading, 24 + CGFloat(ps) * 184 - 30)
                            .padding(.top, geo.size.height * 0.375 - 30)
                    }
                    if refusP > 0.005 {
                        Chambre(p: refusP) { rp in RefusPopup(p: rp) }
                            .frame(maxWidth: .infinity)
                            .padding(.top, geo.size.height * 0.375 - 88)
                            .allowsHitTesting(false)
                    }

                    // LA RANGÉE DU BAS — le slider de départ, à la place que
                    // le galet du menu lui laisse. Les cotes sont celles de
                    // `MenuNappe` : marge 24, galet 62, écart 12.
                    //
                    // ⚠️ QUAND LE GALET EST RANGÉ AU MUR, LE SLIDER PREND SA
                    // PLACE. Sans ça la rangée garderait un trou de 74 pt
                    // devant un objet qui n'est plus là — et une mise en page
                    // qui garde la place d'un absent se lit comme un bug.
                    // ⚠️ CENTRÉE SUR LA CARD, pas sur ce que le galet lui
                    // laisse : l'invite parle du geste de TOUTE la page, un
                    // libellé décentré de 36 pt se lit comme une erreur. Elle
                    // n'a aucune surface, le galet peut donc la chevaucher
                    // sans dommage — et il gagne le doigt, il est au-dessus.
                    // LA FUMÉE D'INVITE — elle dit « c'est ici qu'on tire »
                    // sans un mot de plus. Même matière que le galet et les
                    // sections (`knobSmoke`), mais un régime OPPOSÉ : les
                    // autres sont gestuelles et n'existent que sous le doigt,
                    // celle-ci est PERMANENTE et respire.
                    // ⚠️ MONTÉE, PAS SEULEMENT TRANSPARENTE. C'est la seule
                    // bouffée permanente de l'app : une `TimelineView` à 30 Hz
                    // et une passe de shader sur 220 × 220 @3x, soit 13 Mpix/s
                    // de remplissage TANT QU'ELLE EXISTE. Une `.opacity(0)` ne
                    // l'arrêterait pas — le sous-arbre continuerait de battre
                    // pendant toute la scène de départ et toute la séance, pour
                    // peindre du vide. (C'est exactement la leçon du `rate`
                    // resté à 2,2 et du verre jamais démonté.)
                    if !enSeance, net < 0.02, arr > 0.4,
                       vitrineSlot == nil {
                        FumeeInvite()
                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                   alignment: .bottom)
                            .opacity(arr)
                            .allowsHitTesting(false)
                    }
                    // ⚠️ **LA POIGNÉE DU PULL** (26-08). L'app désigne cette
                    // bande au doigt (« pull to start ») — et elle ne portait
                    // qu'un `onTapGesture`. C'est LA raison littérale du
                    // verdict « un tap fonctionne mieux que le geste » : sur
                    // la seule zone qu'on invite à tirer, seul le tap était
                    // servi. La bande de prise déborde maintenant le dessin de
                    // l'invite (112 pt) pour qu'on n'ait pas à viser.
                    ZStack(alignment: .bottom) {
                        Color.clear
                            .frame(height: Self.poigneePull)
                            .contentShape(Rectangle())
                        InviteTirage(actif: !tiroirOuvert)
                            .padding(.leading, 24)
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                    }
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottom)
                        .opacity(enSeance ? 0 : arr * (1 - net))
                        // ⚠️ **VIVANTE MÊME TIROIR OUVERT** (26-08, second
                        // tour). Elle était sourde dès que le tiroir s'ouvrait
                        // — donc AU RETOUR il n'y avait plus aucune poignée là
                        // où le pouce se pose. C'est l'autre moitié de « dans
                        // le sens inverse, ça bug ». (Le slider vit PLUS BAS,
                        // dans la bande découverte : les deux ne se disputent
                        // rien.)
                        .allowsHitTesting(!enSeance)
                        .onTapGesture {
                            // L'INVITE EST TAPABLE : sans ça le départ passe
                            // derrière un geste, et on ajoute une étape au
                            // flow. ⚠️ UN SEUL SITE D'APPEL avec le cran :
                            // c'est ce qui garantit — par construction, pas par
                            // promesse — que le tap donne LA MÊME scène que le
                            // tirage. (Le film refuse pendant l'édition.)
                            guard !edition, vitrineSlot == nil else { return }
                            // La MÊME bande ouvre et referme : maintenant
                            // qu'elle reste vivante tiroir ouvert, un tap
                            // dessus doit faire le chemin inverse — sinon elle
                            // rejouerait l'ouverture sur un tiroir déjà ouvert.
                            if tiroirOuvert { fermer() } else { lancer(gDepart: 0) }
                        }
                        .animation(.spring(response: 0.42,
                                           dampingFraction: 0.84),
                                   value: galetRange)

                    // LA PIÈCE DU TRÉSOR — la porte du coffre, revenue de
                    // la v1 (verdict 24-08 : « en noir pas or, plus
                    // premium, plus Apple, néon discret »). La matière est
                    // celle de BRAVO : `matte: 1` éteint le MÉTAL seul —
                    // l'anthracite garde ses reflets, sa tranche et son
                    // épaisseur — et le croissant descend de lui-même à
                    // 52 % : le néon discret est DANS la matière, pas dans
                    // une opacité posée dessus.
                    // Alignée sur l'œil de la première ligne de la phrase
                    // (top 48 + centre de ligne 18 − rayon 23 = 43), à la
                    // marge miroir du texte (24).
                    CoffreFortCoinButton(onPress: { toucherPiece($0) },
                                         action: { ouvrirCoffre() },
                                         matte: 1)
                        .padding(.top, 43)
                        .padding(.trailing, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .topTrailing)
                        // Elle recule avec le mobilier : la grammaire des
                        // cards (offset 8, flou plafonné 6, extinction) —
                        // et elle naît avec la phrase.
                        .offset(y: 8 * net)
                        .blur(radius: 6 * net * flouPiece)
                        .opacity((1 - net) * arr)
                        .opacity(RasantHorloge.iso ? 0 : 1)
                        // Sourde dès que la page fait autre chose : le
                        // film, l'édition, la vitrine — un bouton qui
                        // s'estompe ne doit plus prendre le doigt.
                        .allowsHitTesting(net < 0.02 && !edition
                                          && vitrineSlot == nil)
                }
                .offset(y: max(tirage, 0))
        }
        // Le rattrapeur : un tap hors du panneau du galet le referme
        // (les taps des enfants gagnent — le panneau garde les siens).
        // Et c'est aussi LA SORTIE du mode édition : tap n'importe où hors
        // des widgets — la liste d'abord, le mode ensuite.
        // ⚠️ **AVEC SA FORME** (26-08). Sans `contentShape`, un `ZStack` dont
        // les enfants sont posés en `.position`/`.frame(alignment:)` n'a de
        // surface tactile QUE là où ses enfants dessinent : le « tap sur une
        // zone vide » ne rattrapait donc rien du tout — la loi payée du
        // dépôt (« une vue sans taille intrinsèque n'attrape pas les gestes »).
        .contentShape(Rectangle())
        .onTapGesture {
            if listeSlot != nil { fermerListe(); return }
            if edition, vitrineSlot == nil { sortirEdition(); return }
            guard reglageOuvert else { return }
            withAnimation(.spring(response: 0.40,
                                  dampingFraction: 0.84)) {
                reglageOuvert = false
            }
        }
    }

    /// Le doigt se pose, le doigt se lève — l'horloge de la fumée vit dans
    /// la page parce que c'est elle qui la dessine (la grammaire de la v1).
    private func toucherPiece(_ pose: Bool) {
        if pose {
            fumeePiece = .now
            fumeePieceFin = nil
        } else {
            let marque = Date.now
            fumeePieceFin = marque
            // La bouffée s'éteint en ~0,45 s ; on démonte le sous-arbre une
            // fois qu'il ne reste rien à dessiner, pour rendre les 30 Hz du
            // TimelineView. Une autre bouffée a pu naître entre-temps : on
            // n'éteint que la SIENNE.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                guard fumeePieceFin == marque else { return }
                fumeePiece = nil
                fumeePieceFin = nil
            }
        }
    }

    /// Le toucher fume, PUIS la page s'ouvre. Ouverte au même instant, la
    /// fumée serait recouverte avant d'avoir été vue.
    private func ouvrirCoffre() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            coffreOuvert = true
        }
    }

    /// Le geste du tirage : l'élastique (course max 150 pt, en tanh — la
    /// card suit presque le doigt au départ puis se retient), la
    /// dissolution de la phrase nourrie par le tirage VERS LE HAUT
    /// (l'ancienne course du scroll, même formule), et le retour en
    /// ressort au lâcher. Les gestes des enfants gagnent (le panneau du
    /// galet garde son drag-loupe).
    private var tirageGeste: some Gesture {
        // ⚠️ **2 pt** (26-08, second tour). Verdict : « il faut qu'à peine
        // j'effleure, je puisse drag ». Le chemin faisait DEUX seuils en
        // série — 6 pt pour que le geste existe, puis 8 pt pour que l'axe se
        // décide : rien ne bougeait avant ~8 pt de pouce. Le reconnaisseur
        // descend à 2 et la décision d'axe à 4 (voir plus bas) : la card suit
        // dès le premier point franchi.
        DragGesture(minimumDistance: 2)
            .onChanged { g in
                // ⚠️ **LE GESTE ANNULÉ NE LAISSE PLUS SON ÉTAT DERRIÈRE LUI**
                // (26-08). Un drag qui meurt sans `onEnded` — l'app passe en
                // arrière-plan, ou le SYSTÈME vole le geste au bord bas (la
                // Reachability, cf. le screenshot où tout l'écran descend) —
                // laissait `axeVertical` et la course périmés : le tirage
                // suivant ne répondait plus, et la card pouvait rester bloquée
                // à mi-chemin. C'était ça, « parfois ça marche, parfois rien ».
                // La remise à plat se fait sur le CHANGEMENT DE `startLocation`,
                // l'école déjà écrite dans ExercisesView (l. 731).
                if tirageDebut != g.startLocation {
                    tirageDebut = g.startLocation
                    axeVertical = nil
                    cranSenti = false
                    luneSentie = false
                }
                armerChienDeGarde()
                // LE MODE ÉDITION TIENT LA PAGE : un doigt qui dérive
                // pendant l'édition (ou la vitrine) ne nourrit pas le
                // tirage — sinon le wiggle et le film se disputent l'écran.
                guard !edition, vitrineSlot == nil else { return }
                // LE VERROU D'AXE, avant tout le reste.
                if axeVertical == nil {
                    let dx = abs(g.translation.width)
                    let dy = abs(g.translation.height)
                    guard max(dx, dy) > 4 else { return }
                    axeVertical = dy > dx
                }
                guard axeVertical == true else { return }
                var t = g.translation.height
                // EN SÉANCE, LA CARD NE SE REFERME PAS. Elle résiste au
                // doigt qui la pousse vers le bas (course divisée par 4,
                // jamais bloquée net : un objet qui ne bouge PAS DU TOUT se
                // lit comme une panne, pas comme un refus).
                if enSeance, t > 0 { t *= 0.25 }
                // ⚠️ UN DOIGT QUI SE POSE PENDANT LE FILM LE COUPE, et la scène
                // rebrousse vers la prise. Sans ça, la fin de la cinématique
                // s'exécuterait par-dessus l'état que le doigt vient d'imposer.
                // (Et c'est LA raison structurelle du curseur linéaire : on ne
                // peut pas lire la position d'un ressort en vol, donc on ne peut
                // pas la passer au doigt. Une cinématique en ressort est une
                // prison, par construction.)
                // ⚠️ LE DOIGT GÈLE LA SCÈNE, IL NE LA REMET PAS À L'ÉTAT POSÉ.
                // Sans ce gel, poser le doigt en plein film faisait sauter `e`
                // de sa valeur courante à 0 ou à T en UNE image — c'était ça, le
                // « pas fluide en aller-retour ».
                if depart != nil || ferme != nil {
                    eGele = eNow(Date())
                    depart = nil
                    ferme = nil
                }
                // ⚠️ LE SEUIL DU GESTE EST DÉJÀ CONSOMMÉ : le premier événement
                // porte les 6 pt de `minimumDistance`, donc la prise SAUTERAIT
                // d'autant à l'instant du contact si on ne les retirait pas.
                let net = t < 0 ? min(t + 2, 0) : max(t - 2, 0)
                // ⚠️ **L'ÉLASTIQUE COMMENCE À 1 : 1, ET C'ÉTAIT ÇA « À PEINE
                // J'EFFLEURE »** (26-08, troisième tour).
                //
                // Le diviseur valait 190 pour une levée de 140 : la pente à
                // l'origine était donc de **0,737 : 1**. La card ne suivait
                // JAMAIS le doigt — même au premier millimètre elle résistait
                // de 26 % :
                //     doigt  5 pt → card 3,7    doigt 10 pt → card 7,4
                //     doigt 40 pt → card 29,0
                // Un élastique doit se sentir AU BOUT de la course, jamais au
                // contact : on pose, ça colle ; on insiste, ça se retient.
                //
                // Diviseur = LEVÉE : la pente à l'origine vaut exactement 1,
                // et la saturation reste à la levée. Une seule constante, et
                // la relation devient lisible — « la card fait ce que fait le
                // pouce, jusqu'à sa butée ».
                tirage = reposCard
                    + Self.leveeTiroir
                    * CGFloat(tanh(Double(net) / Double(Self.leveeTiroir)))
                // ⚠️ **LE RETOUR SUIT LE DOIGT, IL NE SE CONTENTE PAS DE GELER.**
                // Geler avait supprimé le saut, mais geler c'est ne rien faire :
                // on tirait vers le bas et RIEN ne bougeait jusqu'au lâcher.
                // Tiroir ouvert, un drag descendant pilote la scène en 1:1 — la
                // pilule remonte sous le pouce, le texte se refloute, le slider
                // redescend — et on peut changer d'avis à mi-chemin.
                //
                // L'ASYMÉTRIE EST VOULUE, et c'est la règle d'Apple : une
                // PRÉSENTATION se JOUE (l'ouverture reste un film de 1,95 s que
                // le doigt n'accélère pas), un REJET se MANIPULE. On ne touche
                // donc pas au pull avant.
                // ⚠️ `self.g` : la closure du geste s'appelle déjà `g`, et elle
                // masque le curseur. Et c'est posé APRÈS la mise à jour de
                // `tirage`, sinon on lirait la valeur de l'image précédente.
                if tiroirOuvert, t > 0 {
                    eGele = DepartCine.T * self.g
                }
                // `-phraseScroll <pt>` FIGE la course : une dissolution ne
                // se juge pas sans la voir à mi-chemin.
                if PhraseHorloge.forceScroll == nil {
                    scroll = max(0, -t)
                }
                // Un panneau ouvert pendant que la card bouge se décolle
                // de son galet : il se referme.
                if reglageOuvert, abs(t) > 12 {
                    withAnimation(.easeOut(duration: 0.22)) {
                        reglageOuvert = false
                    }
                }
                // L'ARMEMENT SE SENT SOUS LE DOIGT (verdict 22-08 : « plus
                // haptique quand on pull »). Franchir le cran dit « tu peux
                // lâcher » — la grammaire du slider, appliquée à la page. Une
                // fois par franchissement, et réversible : c'est un armement,
                // pas un commit.
                if !enSeance {
                    let arme = tirage < -Self.seuilCran
                    if arme != cranSenti {
                        cranSenti = arme
                        UIImpactFeedbackGenerator(style: arme ? .rigid : .light)
                            .impactOccurred(intensity: arme ? 0.55 : 0.30)
                    }
                }
                // La braise du secret : une seule fois par découverte.
                if luneP >= 1, !luneSentie {
                    luneSentie = true
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred()
                } else if luneP < 0.15 {
                    luneSentie = false
                }
            }
            .onEnded { fin in
                // Le geste s'est terminé PROPREMENT : le chien de garde n'a
                // plus rien à surveiller.
                tirageDebut = nil
                tirageJeton &+= 1
                guard !edition, vitrineSlot == nil else {
                    axeVertical = nil
                    return
                }
                luneSentie = false
                cranSenti = false
                let vertical = axeVertical == true
                axeVertical = nil
                // Un geste horizontal n'a jamais touché au tiroir : il n'a
                // rien à décider en partant.
                guard vertical else { return }
                // LE CRAN. Au-delà de 95 pt il s'aimante, en deçà de 42 il se
                // referme. Entre les deux il garde son état — une hystérésis,
                // sinon il claque au moindre frémissement.
                //
                // ⚠️ PLUS AUCUN RESSORT SUR CE CHEMIN. Un ressort dépasse et
                // revient : sur un plan de cette lenteur c'est le seul geste qui
                // pourrait encore faire cheap. Et surtout, il portait TOUTE la
                // scène en 0,46 s — c'était ça, « tu vas trop vite ».
                if enSeance {
                    withAnimation(.timingCurve(0.30, 0, 0.20, 1, duration: 0.42)) {
                        tirage = reposCard
                        if PhraseHorloge.forceScroll == nil { scroll = 0 }
                    }
                    return
                }
                // ⚠️ **LA DÉCISION SE PREND SUR LA COURSE DU GESTE ET SON
                // SENS — PLUS SUR LA POSITION ABSOLUE DE LA CARD** (26-08,
                // second tour). Et c'est une RÉGRESSION QUE J'AVAIS
                // INTRODUITE le matin même, chiffrable :
                //
                //     OUVRIR   (la card part de 0)     163 pt → 80 pt   ✅
                //     REFERMER (la card part de −140)  171 pt → 223 pt  ❌
                //
                // Parce que le seuil de fermeture se mesurait par rapport à
                // ZÉRO alors que la card est à −140 quand elle est ouverte :
                // BAISSER le seuil AUGMENTE la course à parcourir. Les deux
                // sens n'étaient pas symétriques par construction, et j'ai
                // optimisé l'un en aggravant l'autre. Verdict : « pareil dans
                // le sens inverse, ça bug ».
                //
                // Désormais les deux sens lisent la MÊME grandeur — les points
                // de pouce parcourus depuis le contact — et le même seuil.
                // Un LANCER franc suffit aussi : au-delà de 420 pt/s le sens
                // de la vitesse décide seul, sans distance à atteindre. C'est
                // la grammaire des feuilles d'iOS, et c'est ce que veut le
                // verdict « au moindre mouvement suffisamment intentionnel ».
                let course = fin.translation.height
                let vitesse = fin.velocity.height
                let lance = abs(vitesse) > 420
                let versLeHaut = lance ? vitesse < 0 : course < 0
                let assez = lance || abs(course) >= Self.coursePouce
                if !assez {
                    // Pas assez : on RETOURNE à l'état d'où l'on vient.
                    if tiroirOuvert { lancer(gDepart: g) } else { fermer() }
                } else if versLeHaut {
                    lancer(gDepart: g)
                } else {
                    fermer()
                }
            }
    }

    /// LA COURSE DE POUCE QUI DÉCIDE — la même dans les deux sens, et c'est
    /// tout l'intérêt. 80 pt : franc, intentionnel, et atteignable d'un pouce
    /// qui ne lâche pas le téléphone.
    private static var coursePouce: CGFloat { 80 }

    /// LE CHIEN DE GARDE DE PÉREMPTION. Un `DragGesture` peut mourir sans
    /// jamais appeler `onEnded` : l'app passe en arrière-plan, une présentation
    /// démarre, ou le SYSTÈME lui vole le doigt — c'est exactement ce qui se
    /// passe quand la Reachability d'iOS se déclenche au bord bas, là où le
    /// pouce commence naturellement ce geste-ci. Sans filet, la page restait
    /// figée à mi-course, l'axe verrouillé, et le tirage suivant ne répondait
    /// plus.
    ///
    /// Réarmé à chaque événement ; seule la dernière vérification agit (le
    /// jeton). 0,30 s : plus long qu'un trou d'événements normal, plus court
    /// qu'un blocage perceptible.
    private func armerChienDeGarde() {
        tirageJeton &+= 1
        let mien = tirageJeton
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            guard tirageJeton == mien, tirageDebut != nil else { return }
            tirageDebut = nil
            axeVertical = nil
            cranSenti = false
            luneSentie = false
            // On rejoint l'état STABLE le plus proche — jamais un état
            // inventé : `reposCard` sait déjà lequel (séance, tiroir, repos).
            guard depart == nil, ferme == nil, abs(tirage - reposCard) > 0.5
            else { return }
            withAnimation(.easeOut(duration: 0.26)) { tirage = reposCard }
        }
    }

    /// LE DÉPART — **un seul site d'appel pour le cran ET pour le tap.** C'est
    /// ce qui garantit par construction que les deux chemins donnent la même
    /// scène : `gDepart` vaut 0 au tap, et toutes les fenêtres du mobilier sont
    /// écrites en `max(gCran, …)`, donc la partition fait elle-même le travail
    /// que le doigt aurait fait.
    private func lancer(gDepart: Double) {
        gCran = gDepart
        // ⚠️ ON REPREND OÙ LE DOIGT A GELÉ. En reculant la date de naissance de
        // l'horloge de ce qui est déjà joué, la reprise est CONTINUE : un
        // aller-retour ne rejoue jamais le début du film.
        let deja = eGele ?? 0
        // LE TIRAGE, ICI ET NULLE PART AILLEURS. Dans un `body` il rejouerait
        // plusieurs fois par image et le texte changerait en plein fondu.
        // On ne re-tire pas sur une REPRISE (le film n'a pas fini) : la phrase
        // changerait sous le doigt.
        if deja < 0.01 {
            let t = DepartMots.tirer()
            ligneUne = t.ligne
            libelleSlider = t.bouton
        }
        eGele = nil
        depart = Date().addingTimeInterval(-deja)
        tiroirOuvert = true
        verreMonte = false
        // LA CARD FINIT DE SE POSER. Le `withAnimation` ne porte plus la scène —
        // il ne porte que la MÉCANIQUE du tiroir et les booléens qui en
        // dépendent (le rangement du galet dans `MenuNappe`, la fermeture de la
        // couronne). Sans lui, le galet se couperait en une image.
        // La courbe démarre raccordée à la vitesse du doigt : l'élastique `tanh`
        // a déjà décéléré, donc le raccord est payé par la géométrie du geste et
        // pas par une rampe.
        withAnimation(.timingCurve(0.10, 0.55, 0.36, 1,
                                   duration: gDepart > 0 ? 0.28 : 0.58)) {
            tirage = -Self.leveeTiroir
            if PhraseHorloge.forceScroll == nil { scroll = 0 }
        }
        // L'ARMEMENT. Le `.rigid` du lâcher ET celui du tap de l'invite ont
        // disparu : il y en avait TROIS en moins de 0,5 s, dont deux annonçaient
        // le même événement. Le lâcher se sent par l'arrêt du mouvement.
        UIImpactFeedbackGenerator(style: gDepart > 0 ? .rigid : .soft)
            .impactOccurred()
        // La fin de l'horloge. Un `asyncAfter` qui ne LIVRE aucune valeur est
        // légal (école `MenuNappe`) ; ce qui est interdit, c'est d'échelonner
        // des arrivées par des réveils.
        let mien = depart
        DispatchQueue.main.asyncAfter(deadline: .now() + DepartCine.T - deja) {
            guard depart == mien else { return }   // le doigt a repris la main
            depart = nil                            // `e` retombe sur T, au centième
        }
        // LES DEUX SECOUSSES DU FILM (verdict 22-08 : « plus haptique quand on
        // pull et quand l'animation se fait »). Elles ne livrent AUCUNE valeur —
        // un `asyncAfter` qui ne fait que sentir est légal, c'est échelonner des
        // ARRIVÉES par des réveils qui est interdit.
        // ⚠️ Et jamais depuis la closure du `TimelineView` : une évaluation de
        // body n'a pas le droit d'avoir d'effet de bord, elle est rejouée plus
        // d'une fois par image et on vibrerait en rafale.
        for (quand, style) in [(1.30, UIImpactFeedbackGenerator.FeedbackStyle.soft),
                               (1.86, .light)] where quand > deja {
            DispatchQueue.main.asyncAfter(deadline: .now() + quand - deja) {
                guard depart == mien else { return }
                UIImpactFeedbackGenerator(style: style).impactOccurred()
            }
        }
    }

    /// LA FERMETURE — 1,25 s, soit 64 % de l'aller. Une fermeture est une
    /// obéissance, pas une cérémonie : rejouer la partition à l'envers ferait de
    /// chaque sortie un événement, et un événement subi dix fois par jour
    /// devient une lenteur.
    private func fermer() {
        // Elle part de LÀ OÙ ON EN EST, pas de T : un aller-retour interrompu à
        // un quart de film ne doit pas défaire une seconde et quart de scène.
        let depuis = eGele ?? (depart != nil ? DepartCine.T : (tiroirOuvert ? DepartCine.T : 0))
        depart = nil
        eGele = nil
        gCran = 0
        verreMonte = true
        guard depuis > 0.001 || tiroirOuvert else { return }
        eFerme = depuis
        ferme = Date()
        let duree = Self.dureeFermeture * max(depuis / DepartCine.T, 0.30)
        // …pendant que la mécanique du tiroir (et les booléens du galet) rentre
        // sur la même durée et la même courbe.
        withAnimation(.timingCurve(0.30, 0, 0.12, 1, duration: duree)) {
            tiroirOuvert = false
            tirage = 0
            if PhraseHorloge.forceScroll == nil { scroll = 0 }
        }
        let mienne = ferme
        DispatchQueue.main.asyncAfter(deadline: .now() + duree) {
            guard ferme == mienne else { return }
            ferme = nil
        }
    }

    // MARK: - Le flow de l'édition des widgets

    /// L'ENTRÉE EN ÉDITION — haptic sec, zoom arrière, respiration,
    /// pastilles. Un seul curseur (`editionP`), fenêtres dérivées dans
    /// `CardsRangee`.
    private func entrerEdition() {
        guard !edition, vitrineSlot == nil else { return }
        withAnimation(.easeOut(duration: 0.20)) { reglageOuvert = false }
        edition = true
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        withAnimation(.timingCurve(0.22, 1, 0.36, 1,
                                   duration: reduceMotion ? 0.25 : 0.42)) {
            editionP = 1
        }
    }

    /// La sortie : tap n'importe où hors des widgets. Pas de bouton
    /// « OK », pas de temporisation — le mode reste tant qu'on ne le
    /// quitte pas (la grammaire d'iOS). Et le SILENCE : rien dans la main.
    private func sortirEdition() {
        guard edition, vitrineSlot == nil else { return }
        fermerListe()
        edition = false
        withAnimation(.timingCurve(0.30, 0, 0.40, 1, duration: 0.34)) {
            editionP = 0
        }
    }

    private func ouvrirListe(_ i: Int) {
        listeSlot = i
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.34)) {
            listeP = 1
        }
    }

    private func fermerListe() {
        guard listeSlot != nil else { return }
        withAnimation(.easeOut(duration: 0.22)) { listeP = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
            if listeP < 0.01 { listeSlot = nil }
        }
    }

    /// LA SUPPRESSION — la loi 5 : jamais le dernier widget. Refusée, elle
    /// s'excuse (RefusalHaptic + pop-up flottante) ; acceptée, la card part
    /// en PAILLETTES (la loi du swap) et le slot devient un FANTÔME.
    private func supprimerWidget(_ i: Int) {
        fermerListe()
        guard slots[1 - i] != nil else { refuserSuppression(); return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        poudreSlot = i
        poudreDepuis = Date()
        // La card meurt SOUS la poudre : une image de grains d'abord.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            ecrireSlot(i, nil)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            poudreSlot = nil
        }
    }

    private func refuserSuppression() {
        RefusalHaptic.play()
        refusJeton += 1
        let mien = refusJeton
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.30)) {
            refusP = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard refusJeton == mien else { return }
            withAnimation(.easeIn(duration: 0.35)) { refusP = 0 }
        }
    }

    private func ouvrirVitrine(_ i: Int) {
        guard vitrineSlot == nil else { return }
        fermerListe()
        vitrineDepart = slots[i]
        vitrineSlot = i
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62)) {
            reculVitrine = 1
        }
    }

    /// Le verdict de la vitrine. Le recul, lui, s'est déjà relâché pendant
    /// le vol (`onSortie`) — ceci n'est que l'écriture et le démontage.
    private func fermerVitrine(_ choisi: WidgetKind?) {
        if let s = vitrineSlot, let k = choisi { ecrireSlot(s, k) }
        vitrineSlot = nil
        vitrineDepart = nil
        if reculVitrine > 0.01 {
            withAnimation(.easeOut(duration: 0.25)) { reculVitrine = 0 }
        }
    }

    /// Les bancs du mode édition — le sim ne sait ni long-press ni drag.
    private func jouerEditionBanc() {
        if let f = SlotsBanc.force {
            slot0Brut = f.first ?? WidgetKind.regularite.rawValue
            slot1Brut = f.count > 1 ? f[1] : "vide"
        }
        if EditionBanc.ouvre || EditionBanc.liste != nil
            || EditionBanc.refus || EditionBanc.supprime {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                entrerEdition()
                if let l = EditionBanc.liste {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        ouvrirListe(l)
                    }
                }
                if EditionBanc.refus || EditionBanc.supprime {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        supprimerWidget(0)
                    }
                }
            }
        }
        if VitrineBanc.ouvre {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                entrerEdition()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    ouvrirVitrine(0)
                }
            }
        }
    }

    // MARK: - Le flow du départ

    /// LE SLIDER PROPOSE, IL NE DÉCIDE PAS. Sa course validée ouvre l'overlay
    /// (la vidéo de la lune qui se charge) — c'est là qu'on confirme.
    private func demarrer() {
        DepartEtat.shared.proposer()
    }

    /// §23 — LA PORTE DU CHEMIN (le slider validé, ou la card semaine).
    private func ouvrirChemin() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        cheminDemonte = false
        cheminOuvert = true
    }

    /// §23 — le panneau du galet a confirmé : la séance démarre (le même
    /// état que « Commencer » du slider — la card sera levée au retour),
    /// et la RED PAGE EXO arrive par-dessus le chemin.
    private func demarrerDepuisChemin() {
        ouvrirSeanceEnBase()
        tirage = reposCard
        if exoParRoute {
            // le monde TabView : le chemin se replie, l'onglet exo prend
            // la scène avec la séance qui tourne.
            cheminOuvert = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                onRoute(.exercises)
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            exoOuvert = true
        }
        // le cover posé, le chemin fantôme se démonte (piège des insets).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            cheminDemonte = true
        }
    }

    /// « COMMENCER » — et la card SE LÈVE TOUTE SEULE pour présenter le
    /// player. On ne bascule PAS vers les exercices (arbitrage du 22-08) :
    /// la séance s'annonce là où on l'a lancée.
    ///
    /// ⚠️ La levée part 0,12 s APRÈS la fermeture du panneau : deux
    /// mouvements simultanés se dévorent, et c'est le panneau qui doit
    /// libérer la scène avant que la card ne bouge.
    private func commencer() {
        DepartEtat.shared.fermer()
        // ⚠️ **LA SÉANCE S'OUVRE EN BASE, ICI AUSSI** (26-08). Ce chemin ne
        // posait qu'un drapeau local : « Commencer » depuis le slider
        // n'écrivait AUCUN `Workout`, et la page exercices — qui, elle, lit
        // déjà la base — ne voyait donc aucune séance. Maintenant que la home
        // dérive son état de la base comme elle, les deux départs doivent y
        // écrire la même chose. C'est aussi ce qui permet à la clôture de
        // ramener la home à son état normal : elle a quelque chose à fermer.
        ouvrirSeanceEnBase()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62)) {
                tirage = reposCard
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    /// LA VRAIE SÉANCE (même en démo) : le geste exact de `startWorkout()` —
    /// un `Workout` ouvert de plus serait inaffichable, donc jamais de
    /// doublon. C'est la SEULE écriture de l'état « en séance » : le drapeau
    /// de la page en découle, il ne le décide pas.
    private func ouvrirSeanceEnBase() {
        let ouverts = (try? modelContext.fetch(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endedAt == nil }))) ?? []
        guard ouverts.isEmpty else { return }
        let seance = Workout()
        modelContext.insert(seance)
        try? modelContext.save()
        WorkoutActivityController.ensure(seance)
    }

    /// Le banc de la matérialisation : 2,5 s après l'arrivée, le premier
    /// fantôme devient une card noire — fondu de calques + le sticker qui
    /// se pose en ressort, et l'haptique douce de la maison.
    private func jouerSemaineBanc() {
        guard SemaineBanc.materialise else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.80)) {
                materialises += 1
            }
        }
    }

    private var dissolution: CGFloat {
        min(CGFloat(phrase.dissolution), max(scroll - 40, 0) / 22)
    }

    /// La lampe pendant sa naissance. Les trois gestes de l'allumage, chacun
    /// une interpolation d'une constante déjà réglée — rien de neuf n'est
    /// inventé pour la cinématique, c'est le même luminaire qui arrive.
    private var rasantNe: RasantParams {
        guard naissance < 0.999 else { return rasant }
        let e = naissance
        var r = rasant
        // Elle ENTRE par la gauche : 0,24 largeur d'écran de course (≈ 96 pt).
        r.srcX = rasant.srcX - 0.24 * (1 - e)
        // Elle MONTE, en partant d'un souffle (12 %) et non de rien : un fondu
        // depuis le noir absolu se lit comme un écran qui s'allume, pas comme
        // une lumière qui entre.
        r.amp = rasant.amp * (0.12 + 0.88 * e)
        // Elle SE FAIT : d'abord une brume large et molle (extinction 1,25,
        // rayons ×1,32), puis la flaque nette. C'est la mise au point.
        r.expo = 1.25 + (rasant.expo - 1.25) * e
        r.along = rasant.along * (1.32 - 0.32 * e)
        r.across = rasant.across * (1.32 - 0.32 * e)
        // Le cœur blanc et le flanc orangé n'arrivent qu'à la fin de la
        // course : ce sont les DÉTAILS de la lampe, ils se posent une fois
        // qu'elle est en place.
        let tard = min(max((e - 0.45) / 0.55, 0), 1)
        r.coeur = rasant.coeur * tard
        r.flanc = rasant.flanc * tard
        return r
    }

    /// L'arrivée, et sa reprise en boucle au banc (`-phraseRejoue`) : une
    /// arrivée se juge en la REGARDANT arriver, et le simulateur ne sait pas
    /// relancer une page.
    private func jouerArrivee() {
        guard PhraseHorloge.fige == nil, PhraseHorloge.instant == nil
        else { return }
        lancer()
        guard PhraseHorloge.rejoue else { return }
        // La boucle du banc : l'arrivée entière, puis deux secondes de pose,
        // puis on éteint et on recommence. Une arrivée se juge en la REGARDANT
        // arriver, et le simulateur ne sait pas relancer une page.
        let cycle = 1.15 + phrase.retardLumiere + phrase.duréeTotale + 2.0
        Timer.scheduledTimer(withTimeInterval: cycle, repeats: true) { _ in
            withAnimation(.easeIn(duration: 0.45)) {
                arrivee = 0
                naissance = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { lancer() }
        }
    }

    /// LA CINÉMATIQUE D'ARRIVÉE. La lumière d'abord, les mots ensuite — la loi
    /// de la maison (« l'oreille arrive avant l'œil », ici la lampe avant la
    /// phrase). 1,15 s pour que la pièce s'allume, la phrase part à 0,38 s et
    /// tient 1,46 s : ~1,9 s en tout. C'est LENT, et c'est le sujet.
    /// Le banc qui se sert lui-même (`-galetChoisit <n>`).
    private func jouerGaletBanc() {
        guard let n = GaletBanc.choisit else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.80)) {
                reglageOuvert = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.28)) { prevus = n }
                withAnimation(.spring(response: 0.40, dampingFraction: 0.84)) {
                    reglageOuvert = false
                }
            }
        }
    }

    private func lancer() {
        withAnimation(.easeOut(duration: 1.15)) { naissance = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + phrase.retardLumiere) {
            // `.linear` et pas `.easeOut` : la courbe de chaque fragment est
            // déjà dans `avancement(_:)`. Une courbe par-dessus l'autre écrase
            // les retards — les cinq fragments arriveraient presque ensemble.
            withAnimation(.linear(duration: phrase.duréeTotale)) { arrivee = 1 }
        }
    }
}

/// `-galetChoisit <n>` : le banc ouvre le panneau et choisit `n` tout seul,
/// 1,2 s après l'arrivée. Le simulateur ne sait pas poser un doigt — sans ce
/// déclencheur, le CÂBLAGE (le roulement du chiffre, la fermeture, le
/// stockage) n'est vérifiable que sur l'appareil.
enum GaletBanc {
    static let choisit: Int? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-galetChoisit"), i + 1 < args.count,
              let v = Int(args[i + 1]), Goal.hebdoChoix.contains(v)
        else { return nil }
        return v
    }()
}

enum PhraseHorloge {
    /// `-phraseFige <p>` : l'arrivée figée à un avancement donné (0 → 1).
    static let fige: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-phraseFige"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return min(max(v, 0), 1)
    }()
    static let rejoue = CommandLine.arguments.contains("-phraseRejoue")

    /// `-arriveeFige <secondes>` : la cinématique d'arrivée reconstituée à cet
    /// instant — la lumière ET la phrase, au même moment. Les deux avancements
    /// sont recalculés ici avec les mêmes courbes que les animations : c'est
    /// une reconstitution, pas une capture, et c'est assumé (une capture
    /// d'écran ne sait pas s'arrêter au milieu d'un ressort).
    static let instant: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-arriveeFige"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return max(v, 0)
    }()

    /// L'allumage de la pièce : easeOut sur 1,15 s (approché en puissance —
    /// l'écart avec la bézier d'Apple est invisible sur une image fixe).
    static func avanceeLumiere(_ t: Double) -> Double {
        let x = min(max(t / 1.15, 0), 1)
        return 1 - pow(1 - x, 2.5)
    }

    /// La phrase : elle part 0,38 s après la lumière et tient 1,46 s.
    static func avanceePhrase(_ t: Double) -> Double {
        min(max((t - 0.38) / 1.46, 0), 1)
    }

    /// `-phraseScroll <pt>` : la course du scroll, figée.
    static let forceScroll: Double? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-phraseScroll"), i + 1 < args.count,
              let v = Double(args[i + 1]) else { return nil }
        return max(v, 0)
    }()
}

// MARK: - Le banc

/// `-homeV2` : la page. `-rasantLab` / `-phraseLab` ajoutent la console, sur
/// l'onglet correspondant.
struct HomeNuitLab: View {
    private enum Onglet: String, CaseIterable {
        case lumiere = "lumière", phrase, galet
    }

    @State private var r = RasantParams.retenus()
    @State private var f = PhraseParams()
    @State private var gp = GaletParams.retenus()
    @State private var onglet: Onglet =
        CommandLine.arguments.contains("-phraseLab") ? .phrase : .lumiere

    private static let console = CommandLine.arguments.contains("-rasantLab")
        || CommandLine.arguments.contains("-phraseLab")

    var body: some View {
        if CommandLine.arguments.contains("-galetCuisson") {
            // LE BANC DE CUISSON. La pastille seule, à SA taille finale (le
            // verre natif ne se redimensionne pas : une capture faite à une
            // autre échelle ne serait pas la même matière), posée à 40 pt du
            // coin sur du noir absolu, sans chiffre et sans panneau. C'est
            // exactement ce qu'on met en boîte.
            ZStack(alignment: .topLeading) {
                Color.black.ignoresSafeArea()
                GaletCuisson(cote: 56, m: gp)
                    .offset(x: 40, y: 40)
            }
            .statusBarHidden()
            .preferredColorScheme(.dark)
        } else {
            banc
        }
    }

    /// LA DESTINATION OUVERTE PAR LE MENU. Le banc n'a pas de `TabView` — il
    /// monte la page seule. Pour que le routage soit JUGEABLE aujourd'hui et pas
    /// seulement le jour de la promotion, il présente la vraie page en plein
    /// écran. Le point d'appel est le même que celui qui pilotera `selection`.
    @State private var route: WoopTab? = {
        // `-homeRoute <profile|progress|exercises>` : la destination ouverte au
        // lancement. Le simulateur ne sait pas taper un item de menu, et
        // `simctl` n'a pas de commande `tap` — sans ce banc, le routage ne se
        // vérifie qu'à la main.
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-homeRoute"), i + 1 < a.count else { return nil }
        return WoopTab(rawValue: a[i + 1])
    }()

    private var banc: some View {
        ZStack(alignment: .bottom) {
            HomeNuitPage(rasant: r, phrase: f, galet: gp,
                         onRoute: { route = $0 })

            if Self.console {
                reglages
                    .transition(.move(edge: .bottom))
            }
        }
        .fullScreenCover(item: $route) { t in
            Group {
                switch t {
                case .profile:   ProfilLuneView(selection: .constant(.profile))
                case .progress:  CalendarStickersPage(onBack: { route = nil })
                case .exercises: ExercisesView(selection: .constant(.exercises))
                default:         Color.black.ignoresSafeArea()
                }
            }
            .overlay(alignment: .topTrailing) {
                // Le banc n'a pas d'onglets : il faut une sortie, sinon la page
                // est un cul-de-sac.
                Button { route = nil } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(12)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .padding(.top, 62)
                .padding(.trailing, 16)
            }
            .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
    }

    private var reglages: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 12) {
                Picker("", selection: $onglet) {
                    ForEach(Onglet.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
                Spacer()
                Button("défauts") {
                    r = RasantParams.retenus(); f = PhraseParams()
                    gp = GaletParams.retenus()
                }
                .font(.inter(11))
                .foregroundStyle(Color.inkSecondary)
            }
            .padding(.bottom, 6)

            if onglet == .galet {
                row("brillance", $gp.brillance, 0, 2.20)
                row("arête pt", $gp.arete_, 0.8, 9.0)
                row("dispersion", $gp.dispersion, 0, 5.0)
                row("col pt", $gp.col, 1.0, 48.0)
                row("rubans", $gp.rubans, 0, 2.20)
                row("ruban pas", $gp.rubanPas, 6.0, 60.0)
                row("fantôme flou", $gp.fantome, 0, 12)
                row("fantôme gros", $gp.fantomeGros, 1.00, 1.60)
                row("fantôme dose", $gp.fantomeDose, 0, 1.00)
                row("combustible", $gp.combustible, 0, 1.60)
                row("liseré", $gp.lisere, 0, 1.00)
                row("scintille", $gp.scintille, 0, 1.00)
            } else if onglet == .lumiere {
                row("lampe x", $r.srcX, -0.40, 0.30)
                row("lampe y", $r.srcY, -0.20, 0.40)
                row("le long", $r.along, 0.30, 2.00)
                row("en travers", $r.across, 0.15, 1.20)
                row("angle", $r.angle, 0, 90)
                row("sommet", $r.amp, 0.10, 0.90)
                row("extinction", $r.expo, 0.8, 5.0)
                row("braise", $r.braise, 0, 1)
                row("cœur blanc", $r.coeur, 0, 0.60)
                row("taille cœur", $r.coeurTaille, 0.10, 0.90)
                row("flanc orangé", $r.flanc, 0, 0.80)
                row("hauteur flanc", $r.flancY, 0, 0.80)
                row("air", $r.air, 0, 0.45)
                row("souffle", $r.souffle, 0, 2)
                row("voile", $r.voile, 0, 0.05)
                row("étoiles", $r.etoiles, 0, 1)
            } else {
                row("taille", $f.taille, 20, 42)
                row("tracking", $f.tracking, -1.5, 0.5)
                row("interligne", $f.interligne, -4, 14)
                row("largeur", $f.largeur, 200, 360)
                row("sourd", $f.sourd, 0.15, 0.70)
                row("sourd lum.", $f.sourdLumiere, 0.15, 0.80)
                row("argent", $f.argent, 0.50, 1.00)
                row("flou", $f.flou, 0, 60)
                row("retard", $f.retard, 0, 0.40)
                row("durée", $f.duree, 0.15, 1.80)
                row("montée", $f.montee, 0, 60)
                row("zoom", $f.zoom, 1.00, 1.20)
                row("retard lum.", $f.retardLumiere, 0, 1.20)
                row("dissolution", $f.dissolution, 0, 14)
                row("plan", $f.plan, 0.50, 1.00)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .background(Color.black.opacity(0.72))
        .ignoresSafeArea(edges: .bottom)
    }

    private func row(_ name: String, _ value: Binding<Double>,
                     _ lo: Double, _ hi: Double) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.inter(11))
                .foregroundStyle(Color.inkMuted)
                .frame(width: 78, alignment: .leading)
            Slider(value: value, in: lo...hi)
                .tint(Color.woopGold)
            Text(String(format: abs(hi) > 20 ? "%.0f" : "%.3f",
                        value.wrappedValue))
                .font(.inter(10).monospacedDigit())
                .foregroundStyle(Color.inkSecondary)
                .frame(width: 46, alignment: .trailing)
        }
        .frame(height: 26)
    }
}

#Preview {
    HomeNuitLab()
}

// MARK: - Le cristal peint (l'école « dur »)

/// L'hôte de `verreGalet` : un rectangle blanc, padé de 34 pt pour que
/// l'énergie meure avant son bord (le piège du cadre fantôme), et décalé pour
/// que le galet tombe pile à l'origine de son emplacement dans la phrase.
///
/// Le shader dessine LES DEUX corps et leur col : il n'y a plus de conteneur
/// de verre, plus de `spacing` à deviner, plus de fantôme — et plus de double,
/// puisque rien n'est réfracté.
struct VerreGaletDur: View {
    var cote: CGFloat
    var pan: CGSize
    var descente: CGFloat
    /// 0 = fermé (le panneau est avalé DANS le galet), 1 = ouvert.
    var ouvert: Double
    var m = GaletParams()

    /// La marge de bloom. Large : c'est de l'alpha, ça ne coûte que des pixels
    /// transparents, et c'est ce qui évite qu'une arête vienne buter sur le
    /// bord de l'hôte.
    private static let pad: CGFloat = 34

    var body: some View {
        let w = pan.width + 2 * Self.pad
        let h = cote + descente + pan.height + 2 * Self.pad
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let t = Float(RasantHorloge.t(tl.date))
            Rectangle()
                // JAMAIS `.clear` sous un `colorEffect` : l'alpha nul de
                // l'hôte avale tout le rendu (la leçon d'ExoHeaderGlow).
                .fill(.white)
                .colorEffect(ShaderLibrary.verreGalet(
                    .float2(Float(w), Float(h)),
                    .float(t),
                    .float4(Float(Self.pad + cote / 2),
                            Float(Self.pad + cote / 2),
                            Float(cote / 2), Float(cote * 0.34)),
                    .float4(Float(Self.pad - 8 + pan.width / 2),
                            Float(Self.pad + cote + descente + pan.height / 2),
                            Float(pan.width / 2), Float(pan.height / 2)),
                    .float4(Float(ouvert), Float(m.brillance),
                            Float(m.arete_), Float(m.dispersion)),
                    .float4(Float(m.scintille), Float(m.col),
                            Float(m.rubans), Float(m.rubanPas))))
                .frame(width: w, height: h)
        }
        .frame(width: w, height: h)
        .offset(x: -Self.pad, y: -Self.pad)
        .allowsHitTesting(false)
    }
}

// MARK: - La cuisson du verre

/// LA PASTILLE À CUIRE : verre natif, nourri d'une forme NEUTRE.
///
/// Tout le chantier tient dans cette vue. Le verre natif est magnifique parce
/// qu'il plie ce qu'il y a derrière lui ; nourri du chiffre il faisait un
/// double, nourri de rien il ne montrait rien. Nourri d'une **virgule de
/// lumière** — deux traînées croisées et un point chaud, aucune forme
/// reconnaissable — il donne le même cristal, sans rien à dédoubler. On le
/// capture une fois, et il devient une image.
struct GaletCuisson: View {
    var cote: CGFloat
    var m = GaletParams()

    var body: some View {
        GlassEffectContainer(spacing: 20) {
            Color.clear
                .frame(width: cote, height: cote)
                .glassEffect(.clear.interactive(),
                             in: RoundedRectangle(cornerRadius: cote * 0.34,
                                                  style: .continuous))
                .overlay { combustibleNeutre }
        }
        .frame(width: cote, height: cote)
    }

    /// La forme neutre : deux lames de lumière qui se croisent (ce sont elles
    /// que la lentille plie en rubans) et un point chaud décentré vers la
    /// lampe. Dense et à BORDS FRANCS — un flou ne fait pas de caustiques.
    private var combustibleNeutre: some View {
        ZStack {
            // ⚠️ MESURÉ : à 0,30 de hauteur, les lames couvrent 70 % de la
            // pastille et la lentille ne montre plus qu'un blanc plein. Un
            // chiffre, lui, n'occupe qu'un quart de la surface EN TRAITS FINS —
            // c'est ce rapport-là qu'il faut imiter, pas la densité.
            Capsule()
                .fill(.white.opacity(m.neutre))
                .frame(width: cote * 0.80, height: cote * 0.115)
                .rotationEffect(.degrees(-34))
                .offset(x: -cote * 0.04, y: -cote * 0.05)
            Capsule()
                .fill(.white.opacity(m.neutre * 0.9))
                .frame(width: cote * 0.52, height: cote * 0.075)
                .rotationEffect(.degrees(26))
                .offset(x: cote * 0.09, y: cote * 0.16)
            Circle()
                .fill(.white.opacity(m.neutre))
                .frame(width: cote * 0.13)
                .offset(x: -cote * 0.22, y: -cote * 0.21)
        }
        .blur(radius: 0.6)
    }
}

// MARK: - L'invite du tirage

/// DEUX CHEVRONS ET UN MOT — l'invite qui apprend le geste.
///
/// Elle remplace le slider dans la rangée du bas : le départ vit désormais
/// DANS le tiroir, et l'action principale de l'app passe donc derrière un
/// geste. L'invite doit être **permanente** — jamais un indice qui s'efface
/// après le premier lancement — sinon on cache le départ.
///
/// TROIS LOIS :
///   • **C'est une LUMIÈRE, pas un bouton.** Aucune surface derrière : Apple
///     n'entoure jamais un élément actif, il le rend plus présent. Un chip
///     sous deux chevrons serait la grammaire d'Android.
///   • **Les deux chevrons ne respirent pas ensemble.** Le haut part le
///     premier, le bas le suit de 0,18 s — c'est ce décalage qui fait
///     « ça monte » plutôt que « ça clignote ».
///   • **L'anglais** : les micro-libellés de la home sont déjà en anglais
///     (« sessions this week », « weekly volume »). Le français est réservé
///     aux actions.
/// LA FUMÉE SOUS « PULL TO START » — la seule bouffée PERMANENTE de l'app, et
/// c'est un choix : les deux autres (le galet, les sections) sont gestuelles et
/// n'existent que sous le doigt. Celle-ci a un travail à faire — dire où tirer.
///
/// ⚠️ ELLE RESPIRE SUR DEUX PÉRIODES INCOMMENSURABLES (7,3 s et 11,7 s). Un
/// seul sinus se reconnaît en trois cycles et devient un clignotant ; deux
/// périodes premières entre elles ne repassent jamais par le même état. C'est
/// la loi déjà payée sur les liserés des cards et sur la caméra du panneau de
/// départ.
///
/// ⚠️ ET SON AMPLITUDE EST BASSE (0,06 → 0,32 de bouffée). Une invite qui se
/// voit est une alarme. Celle-ci doit se remarquer au bout de deux secondes,
/// pas à la première image.
///
/// ⚠️ L'ÂGE EST FIGÉ À 1,2 s, pas croissant. Il pilote deux choses dans le
/// shader : la glisse radiale du bruit, et l'onde du toucher qui meurt en
/// `exp(-age/0,32)`. Figé là, l'onde est éteinte (2 %) — une invite ne « tape »
/// pas — et la glisse reste constante pendant que la dérive temporelle `t`
/// fait vivre les volutes. Laissé libre, il grandirait sans borne et les
/// volutes dégénéreraient en rayons droits.
private struct FumeeInvite: View {
    /// La boîte du panache : le foyer est en BAS, la fumée occupe tout le
    /// dessus. Rien de carré ni de centré — un panache a un pied.
    private static let larg: CGFloat = 210
    private static let haut: CGFloat = 200
    /// Le foyer, dans la boîte : sur le chevron, à 18 pt du bas.
    private static let foyerY: CGFloat = 182
    /// De combien la boîte descend sous la ligne du bloc d'invite, pour que le
    /// pied du panache tombe sur le chevron et pas sur les mots.
    private static let assise: CGFloat = 96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 900)
                // ⚠️ DEUX PÉRIODES INCOMMENSURABLES (7,3 s et 11,7 s). Un seul
                // sinus se reconnaît en trois cycles et devient un clignotant ;
                // deux périodes premières entre elles ne repassent jamais par le
                // même état. La loi des liserés des cards.
                // ⚠️ Et l'amplitude est HAUTE : cette invite est posée sur la
                // BRAISE, la zone la plus claire de l'écran. À 0,19 son alpha
                // tombait à 7 % et la fumée était rigoureusement invisible —
                // mesuré. Sur du noir la même valeur aurait suffi.
                let souffle = 0.52 + 0.26 * sin(t * 2 * .pi / 7.3)
                    + 0.14 * sin(t * 2 * .pi / 11.7 + 1.7)
                Rectangle()
                    .fill(.white)
                    .colorEffect(ShaderLibrary.panacheInvite(
                        .float2(Float(Self.larg), Float(Self.haut)),
                        .float(t),
                        .float2(Float(Self.larg / 2), Float(Self.foyerY)),
                        .float(Float(max(souffle, 0))),
                        .float(1.0)
                    ))
                    .frame(width: Self.larg, height: Self.haut)
                    .offset(y: Self.haut - Self.assise)
            }
        }
    }
}

struct InviteTirage: View {
    /// L'invite respire tant qu'on n'a pas compris. Une fois le tiroir
    /// ouvert, elle se tait : une invite qui continue après coup est du bruit.
    var actif: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            VStack(spacing: 3) {
                chevron(souffle(t, 0))
                chevron(souffle(t, 0.18))
                Text("pull to start")
                    .font(.inter(11, .medium))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(.top, 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .contentShape(Rectangle())
        }
    }

    /// La respiration d'un chevron : 0 au repos, 1 au sommet de l'appel.
    private func souffle(_ t: Double, _ retard: Double) -> Double {
        guard actif, !reduceMotion else { return 0 }
        let p = 2.6
        let x = ((t - retard).truncatingRemainder(dividingBy: p)) / p
        // Un appel bref, puis un long silence : une invite qui bat sans
        // arrêt devient un stroboscope.
        return x < 0.34 ? sin(x / 0.34 * .pi) : 0
    }

    @ViewBuilder
    private func chevron(_ v: Double) -> some View {
        Chevron()
            .stroke(Color.white.opacity(0.34 + 0.46 * v),
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round,
                                       lineJoin: .round))
            .frame(width: 17, height: 6)
            .offset(y: CGFloat(-2 * v))
    }
}

/// Le chevron nu — deux segments, rien d'autre.
struct Chevron: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

// MARK: - La poudre fine des minis

/// Une salve : un point de départ et une graine.
struct SalveMini: Identifiable, Equatable {
    let id = UUID()
    let t0: Date
    let x: CGFloat
    let y: CGFloat
    let graine: Int
}

/// LA POUDRE FINE — la recette EXACTE du calendrier (`PoudreCran`), portée du
/// cadran à une carte qu'on soulève.
///
/// TROIS LOIS, toutes payées là-bas :
///   • **SEIZE grains, pas plus.** Entre quinze et quatre-vingts on tombe dans
///     la neige de télévision ; ce qui fait la poudre, c'est que chaque grain
///     est MENU et FAIBLE — c'est la masse qui brille, jamais l'individu.
///   • **L'ÉTOILE-FACETTE**, jamais un point rond : deux losanges croisés et
///     un cœur blanc. C'est la croix, pas la tache, qui dit « pierre ».
///   • **L'HORLOGE DORT** quand il n'y a rien à semer. Hors salve, cette vue
///     ne coûte pas une image.
struct PoudreMini: View {
    let salves: [SalveMini]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: salves.isEmpty || reduceMotion)) { tl in
            Canvas { ctx, _ in
                ctx.blendMode = .plusLighter
                for s in salves { dessiner(s, ctx: &ctx, quand: tl.date) }
            }
        }
        .allowsHitTesting(false)
    }

    private func dessiner(_ s: SalveMini, ctx: inout GraphicsContext,
                          quand: Date) {
        let age = quand.timeIntervalSince(s.t0)
        for i in 0 ..< 16 {
            let g = s.graine &+ i
            let vie: Double = 0.42 + 0.38 * Self.hachis(g, 2)
            let cyc: Double = age / vie
            guard cyc > 0, cyc < 1 else { continue }
            // Elles s'écartent en gerbe vers le haut, puis la gravité les
            // rattrape : un nuage isotrope ne serait que du bruit de capteur.
            let ang: Double = -.pi / 2
                + (Self.hachis(g, 1) - 0.5) * 2.1
            let v: CGFloat = 26.0 + 52.0 * CGFloat(Self.hachis(g, 3))
            let t = CGFloat(age)
            let x: CGFloat = s.x + CGFloat(cos(ang)) * v * t
            let y: CGFloat = s.y + CGFloat(sin(ang)) * v * t + 150.0 * t * t
            let tw: Double = 0.5 + 0.5
                * sin(age * (7.0 + 12.0 * Self.hachis(g, 5))
                      + Self.hachis(g, 6) * 6.28)
            let a: Double = sin(.pi * cyc) * sin(.pi * cyc)
                * (0.25 + 0.75 * tw * tw * tw)
            guard a > 0.02 else { continue }
            let r: CGFloat = CGFloat(0.7 + 1.2 * Self.hachis(g, 7))
            let c: Color = Self.hachis(g, 8) < 0.34
                ? Color.white
                : Color(red: 0.96, green: 0.97, blue: 1.00)
            var etoile = Path()
            etoile.move(to: CGPoint(x: -r, y: 0))
            etoile.addLine(to: CGPoint(x: 0, y: -r * 0.22))
            etoile.addLine(to: CGPoint(x: r, y: 0))
            etoile.addLine(to: CGPoint(x: 0, y: r * 0.22))
            etoile.closeSubpath()
            etoile.move(to: CGPoint(x: 0, y: -r))
            etoile.addLine(to: CGPoint(x: r * 0.22, y: 0))
            etoile.addLine(to: CGPoint(x: 0, y: r))
            etoile.addLine(to: CGPoint(x: -r * 0.22, y: 0))
            etoile.closeSubpath()
            ctx.fill(etoile.applying(CGAffineTransform(
                translationX: x, y: y)),
                with: .color(c.opacity(a * 0.85)))
            ctx.fill(Path(ellipseIn: CGRect(
                x: x - 0.4, y: y - 0.4, width: 0.8, height: 0.8)),
                with: .color(Color.white.opacity(a * 0.9)))
        }
    }

    private static func hachis(_ i: Int, _ k: Int) -> Double {
        let s = sin(Double(i) * 12.9898 + Double(k) * 78.233) * 43758.5453
        return s - floor(s)
    }
}


/// LA FENÊTRE D'ENTRÉE DE LA PILULE ROUGE.
///
/// ⚠️ Elle vit HORS de `mobilierScene` (donc hors de la `Chambre`) : la card
/// vidéo est peinte par la couche de FOND, qui n'a pas de curseur interpolé.
/// Le fondu est donc porté par `arrivee` directement — et c'est licite ici,
/// précisément parce que c'est UNE opacité sur UNE vue : SwiftUI l'interpole
/// de 0 à 1, et le retard vient de la fenêtre, pas d'un échelonnement à
/// respecter. (Le piège des rampes échelonnées ne mord que s'il y a plusieurs
/// fenêtres à tenir ensemble.)
enum PilP {
    static func entree(_ arrivee: Double) -> Double {
        min(max((arrivee - 0.80) / 0.20, 0), 1)
    }
}


/// `-flouAvant` — l'A/B des deux flous, sur le même binaire.
enum FlouBanc {
    static let avant = CommandLine.arguments.contains("-flouAvant")
}
