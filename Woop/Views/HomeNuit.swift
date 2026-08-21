import SwiftUI
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
    static func fragments(faits: Int, prevus: Int) -> [PhraseFragment] {
        let mot = faits == 1 ? "entraînement" : "entraînements"
        return [
            PhraseFragment("Bonjour Kathryn,", clair: true),
            PhraseFragment("vous avez fait", clair: false),
            PhraseFragment("\(faits) \(mot)", clair: true),
            PhraseFragment("cette semaine", clair: false),
            PhraseFragment("sur ", objectif: prevus, apres: " prévus.",
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
            .mask {
                LinearGradient(colors: [.white,
                                        .white.opacity(params.argent + 0.04)],
                               startPoint: .top, endPoint: .bottom)
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
        .blur(radius: (1 - u) * params.flou)
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
    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var retour: NSObjectProtocol?
        var statut: NSKeyValueObservation?
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

    func updateUIView(_ v: BoosterLoopLayerView, context: Context) {}

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
    /// La marge de nuit autour de la card, et le rayon concentrique
    /// (écran ≈ 55 pt sur les iPhone récents, moins la marge).
    var marge: CGFloat = 10
    var rayon: CGFloat = 45
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

    var body: some View {
        Color.black
            .overlay(
                ZStack {
                    // L'IMAGE DE POSE, dessous : c'est le FILET du fond.
                    // Le décodage du simulateur est logiciel et rate des
                    // frames ; sans elle, un raté peint tout l'écran en
                    // NOIR (« des fois glitch noir »). Avec elle, un raté
                    // ne fait que figer l'image une frame — invisible.
                    Image("home-fond-poster")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    HomeFondVideo()
                }
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
            .padding(.bottom, levee)
    }
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
    private static let stickers = ["sticker-bras", "sticker-flamme",
                                   "sticker-basket", "sticker-abricot",
                                   "sticker-chocolat"]

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
            forme.fill(Color(white: 0.016).opacity(0.94))
            forme.fill(RadialGradient(
                colors: [Color(white: 0.150).opacity(0.94), .clear],
                center: .topTrailing, startRadius: 0, endRadius: L * 0.95))
            forme.fill(RadialGradient(
                colors: [Color(white: 0.100).opacity(0.94), .clear],
                center: .bottomLeading, startRadius: 0, endRadius: L * 0.62))
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
            Text("Cette semaine.")
                .font(.inter(20, .semibold))
                .foregroundStyle(.white.opacity(0.94))
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
    private func mini(_ i: Int) -> some View {
        let faite = i < solides
        return ZStack(alignment: .topLeading) {
            formeMini.fill(LinearGradient(
                colors: [Color(white: 0.060), Color(white: 0.030)],
                startPoint: .top, endPoint: .bottom))
            formeMini.strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            GrainTexture.tuile
                .resizable(resizingMode: .tile)
                .opacity(0.05).blendMode(.overlay).clipShape(formeMini)
            formeMini.fill(EllipticalGradient(
                stops: [.init(color: .white.opacity(0.07), location: 0),
                        .init(color: .clear, location: 1)],
                center: UnitPoint(x: 0.25, y: 0.08),
                startRadiusFraction: 0, endRadiusFraction: 1.0))
                .blendMode(.plusLighter)
            VStack(alignment: .leading, spacing: 0) {
                Text(Self.jour(date(i)))
                    .font(.inter(10, .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text(Self.mois(date(i)))
                    .font(.inter(5.5, .semibold)).tracking(0.7)
                    .foregroundStyle(Color(white: 1).opacity(0.45))
            }
            .padding(7)
            // Le sticker vit sous la date, CENTRÉ, et le bord bas de
            // l'ardoise le tranche à mi-corps : on en devine le haut. C'est
            // la loi de la pochette du bac — la coupe est un choix.
            Image(Self.stickers[i % Self.stickers.count])
                .resizable().scaledToFit()
                .frame(width: 36, height: 36)
                .position(x: 31, y: 46)
                .scaleEffect(faite ? 1 : 0.7)
        }
        .frame(width: miniL, height: miniH)
        .opacity(faite ? 1 : 0)
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

    /// LE TIRAGE de la card géante (verdict 21-08 : « je dois pouvoir drag
    /// toute la home ») — le déplacement RENDU, déjà élastiqué.
    @State private var tirage: CGFloat = TirageBanc.fige ?? 0
    /// Le verrou de l'haptique du secret : la braise ne se sent qu'UNE fois
    /// par découverte, pas à chaque image passée au-dessus du seuil.
    @State private var luneSentie = false

    // MARK: - LE FLOW DE LA SÉANCE (22-08)

    /// Le galet est rangé au mur : le slider reprend la largeur libérée.
    @State private var galetRange = false
    @State private var menuOuvert = false
    /// LA SÉANCE TOURNE. Tant qu'elle tourne, la card reste SOULEVÉE et
    /// refuse de se refermer : le player n'est pas un tiroir qu'on range,
    /// c'est l'état de la page.
    @State private var enSeance = CommandLine.arguments.contains("-homeSeance")
    @State private var debutSeance: Date?

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

    /// La hauteur à laquelle la card se tient pendant la séance — assez pour
    /// découvrir le player en entier, jamais plus.
    private static var leveeSeance: CGFloat { 106 }
    /// La levée du tiroir hors séance : le slider fait 62, plus l'air.
    private static var leveeTiroir: CGFloat { 116 }
    /// Le seuil du cran, mesuré sur le tirage RENDU (déjà élastiqué) : au-delà
    /// il reste ouvert, en deçà il revient. Le plan le fixe à 90.
    private static var seuilCran: CGFloat { 90 }
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
            MenuHote(ouvert: $menuOuvert, couronne: true,
                     onRange: { galetRange = $0 },
                     // LE GALET S'EFFACE DÈS QUE LA BANDE PARLE. Tiroir
                     // ouvert, la rangée du bas appartient au slider puis au
                     // player : le galet s'encastre dans le mur, sinon il se
                     // pose littéralement DESSUS (vu en capture).
                     rangerDemande: enSeance || tiroirOuvert,
                     // Le slider est dans la bande : pendant qu'il est là, le
                     // galet ne dispute plus le doigt.
                     verrouille: tiroirOuvert && !enSeance) {
                fondPage
            } contenu: {
                mobilier(geo)
            }
            .overlay {
                // L'OVERLAY DU DÉPART — déjà écrit (la vidéo de la lune qui
                // se charge). Le slider l'ouvre, « Commencer » le referme et
                // lance la séance.
                DepartPanneauHote(
                    ouverte: DepartEtat.shared.panneauOuvert,
                    onCommencer: { commencer() },
                    onFermer: { DepartEtat.shared.fermer() })
            }
        }
        .onAppear {
            guard !deja else { return }
            deja = true
            // La séance tournait déjà au lancement : la card est LEVÉE dès la
            // première image, sans animation — on ne rejoue pas une
            // cinématique pour un état qu'on ne fait que retrouver.
            if enSeance { tirage = reposCard }
            // `-tiroirOuvert` : le tiroir déjà tiré, pour juger le slider
            // dans la bande sans doigt.
            if CommandLine.arguments.contains("-tiroirOuvert"), !enSeance {
                tiroirOuvert = true
                tirage = reposCard
            }
            jouerArrivee()
            jouerGaletBanc()
            jouerSemaineBanc()
        }
    }

    /// LE FOND : la bande révélée tout au fond, la card par-dessus, et le
    /// geste du tirage — il couvre toute la page, et les gestes des enfants
    /// (le slider, le galet) gagnent sur lui.
    private var fondPage: some View {
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
                            LuneSecrete(p: luneP)
                                .opacity(tiroirOuvert ? 0 : 1)
                            // LE SLIDER, dans la bande. La piste se DÉROULE
                            // depuis la gauche au lieu de paraître : une
                            // barre qui apparaît d'un bloc est une image,
                            // une barre qui se déroule est un objet.
                            SliderObsidienne(label: "Démarrer",
                                             height: 62,
                                             onConfirm: { demarrer() })
                                .padding(.horizontal, 24)
                                // 28 pt d'air sous l'arête de la card : à 46
                                // le slider passait DERRIÈRE elle de 12 pt et
                                // se lisait comme collé.
                                .padding(.bottom, 26)
                                .opacity(tiroirOuvert ? 1 : 0)
                                .scaleEffect(x: tiroirOuvert ? 1 : 0.30,
                                             anchor: .leading)
                                .allowsHitTesting(tiroirOuvert)
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
                        GrandeCardVideo(naissance: naissance,
                                        levee: max(-tirage, 0))
                    }
                }
                // Le tirage vers le BAS déplace toujours toute la home (« je
                // dois pouvoir drag toute la home », validé). Le tirage vers
                // le HAUT, lui, ne déplace plus rien : il raccourcit.
                .offset(y: max(tirage, 0))
        }
        .contentShape(Rectangle())
        .gesture(tirageGeste)
    }

    /// LE MOBILIER : ce qui recule quand la couronne éclôt.
    @ViewBuilder
    private func mobilier(_ geo: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
                Group {
                    PhraseVue(p: arrivee, params: phrase, rasant: rasant,
                              fragments: PhraseTexte.fragments(
                                faits: faits, prevus: prevus),
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
                        // La dissolution : passé 40 pt de tirage vers le
                        // haut, la phrase s'efface dans la nuit.
                        .blur(radius: dissolution)
                        .opacity(1 - 0.70 * min(max((scroll - 40) / 120, 0), 1))
                        // Le plan traîne : 14 % de retard sur le tirage —
                        // la parallaxe INTERNE de la card.
                        .offset(y: -scroll * (1 - phrase.plan))
                        .opacity(RasantHorloge.iso ? 0 : 1)

                    // LES DEUX CARDS (jalon V3) : les séances et le volume.
                    CardsRangee(faites: faits, prevues: prevus,
                                arrivee: arrivee)
                        .padding(.leading, 24)
                        .padding(.top, geo.size.height * 0.375)
                        .allowsHitTesting(false)
                        .opacity(RasantHorloge.iso ? 0 : 1)

                    // LA SEMAINE — le mobilier de la page, sourd au doigt
                    // tant que le tap-story n'est pas câblé (jalon flow).
                    SemaineStrip(faits: faits, prevus: prevus,
                                 arrivee: arrivee,
                                 materialises: materialises)
                        .padding(.leading, 24)
                        .padding(.top, geo.size.height * 0.620)
                        .opacity(RasantHorloge.iso ? 0 : 1)

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
                    InviteTirage(actif: !tiroirOuvert)
                        .padding(.leading, 24)
                        .padding(.trailing, 24)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity,
                               alignment: .bottom)
                        .opacity(enSeance || tiroirOuvert ? 0 : arrivee)
                        .allowsHitTesting(!enSeance && !tiroirOuvert)
                        .onTapGesture {
                            // L'INVITE EST TAPABLE : sans ça le départ passe
                            // derrière un geste, et on ajoute une étape au
                            // flow. Un tap lève la card tout seule — le geste
                            // reste pour qui préfère tirer.
                            withAnimation(.spring(response: 0.50,
                                                  dampingFraction: 0.84)) {
                                tiroirOuvert = true
                                tirage = -Self.leveeTiroir
                            }
                            UIImpactFeedbackGenerator(style: .rigid)
                                .impactOccurred()
                        }
                        .animation(.spring(response: 0.42,
                                           dampingFraction: 0.84),
                                   value: galetRange)
                }
                .offset(y: max(tirage, 0))
        }
        // Le rattrapeur : un tap hors du panneau du galet le referme
        // (les taps des enfants gagnent — le panneau garde les siens).
        .onTapGesture {
            guard reglageOuvert else { return }
            withAnimation(.spring(response: 0.40,
                                  dampingFraction: 0.84)) {
                reglageOuvert = false
            }
        }
    }

    /// Le geste du tirage : l'élastique (course max 150 pt, en tanh — la
    /// card suit presque le doigt au départ puis se retient), la
    /// dissolution de la phrase nourrie par le tirage VERS LE HAUT
    /// (l'ancienne course du scroll, même formule), et le retour en
    /// ressort au lâcher. Les gestes des enfants gagnent (le panneau du
    /// galet garde son drag-loupe).
    private var tirageGeste: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { g in
                // LE VERROU D'AXE, avant tout le reste.
                if axeVertical == nil {
                    let dx = abs(g.translation.width)
                    let dy = abs(g.translation.height)
                    guard max(dx, dy) > 8 else { return }
                    axeVertical = dy > dx
                }
                guard axeVertical == true else { return }
                var t = g.translation.height
                // EN SÉANCE, LA CARD NE SE REFERME PAS. Elle résiste au
                // doigt qui la pousse vers le bas (course divisée par 4,
                // jamais bloquée net : un objet qui ne bouge PAS DU TOUT se
                // lit comme une panne, pas comme un refus).
                if enSeance, t > 0 { t *= 0.25 }
                tirage = reposCard + 150 * CGFloat(tanh(Double(t) / 190))
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
                // La braise du secret : une seule fois par découverte.
                if luneP >= 1, !luneSentie {
                    luneSentie = true
                    UIImpactFeedbackGenerator(style: .soft)
                        .impactOccurred()
                } else if luneP < 0.15 {
                    luneSentie = false
                }
            }
            .onEnded { _ in
                luneSentie = false
                let vertical = axeVertical == true
                axeVertical = nil
                // Un geste horizontal n'a jamais touché au tiroir : il n'a
                // rien à décider en partant.
                guard vertical else { return }
                // LE CRAN. Hors séance, c'est ici que le tiroir décide de
                // rester ouvert — au-delà de 90 pt il s'aimante, en deçà de
                // 40 il se referme. Entre les deux, il garde son état :
                // une hystérésis, sinon il claque au moindre frémissement.
                if !enSeance {
                    withAnimation(.spring(response: 0.46,
                                          dampingFraction: 0.82)) {
                        if tirage < -Self.seuilCran { tiroirOuvert = true }
                        else if tirage > -40 { tiroirOuvert = false }
                    }
                }
                withAnimation(.spring(response: 0.50,
                                      dampingFraction: 0.86)) {
                    tirage = reposCard
                    if PhraseHorloge.forceScroll == nil { scroll = 0 }
                }
                if tiroirOuvert || enSeance {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
            }
    }

    // MARK: - Le flow du départ

    /// LE SLIDER PROPOSE, IL NE DÉCIDE PAS. Sa course validée ouvre l'overlay
    /// (la vidéo de la lune qui se charge) — c'est là qu'on confirme.
    private func demarrer() {
        DepartEtat.shared.proposer()
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
        debutSeance = Date()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            enSeance = true
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.62)) {
                tirage = reposCard
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
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

    private var banc: some View {
        ZStack(alignment: .bottom) {
            HomeNuitPage(rasant: r, phrase: f, galet: gp)

            if Self.console {
                reglages
                    .transition(.move(edge: .bottom))
            }
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
