import SwiftUI

// MARK: - LA CARD ROUTE DE LA HOME
//
// Elle prend la place de l'ardoise « This week » (mise de côté, elle sera
// réemployée). Sa commande, le 29-08 : « refais le composant par le style
// route comme il donne sur la route — deux lignes de texte, Chapitre 1 et
// l'étape X sur X, et tu prends le design des galets de la route mais EN
// TEMPS RÉEL : avant, le jour de la séance faite ou le reward ; au milieu le
// jour actuel avec son halo ; après, le prochain élément, reward ou séance,
// avec la flamme vide. »
//
// LES TROIS RÈGLES TRANCHÉES CE JOUR-LÀ, et elles vivent dans `EcranSpec` :
//  1. le galet du milieu porte une DATE, jamais un rang — c'est la loi de la
//     route (« la date est un estampillage, pas une position »), et le rang
//     est déjà dit par le texte, à dix points de là ;
//  2. « étape X sur 9 » compte TOUS les nœuds du chapitre, récompenses
//     comprises : le chiffre doit se vérifier au doigt sur la route ;
//  3. le nœud du haut s'affiche tel quel, même éteint — une récompense déjà
//     réclamée reste ce qu'il y a juste avant aujourd'hui.
//
// ⚠️ **RIEN N'EST RECOPIÉ DE LA ROUTE.** L'état d'un nœud, sa date, son
// glyphe, le nom et le compte du chapitre viennent tous de
// `EcranSpec.Lecture` / `EcranSpec.apercu` — la même source que la page. La
// coquille, elle, est `ArdoiseFond`, sortie de `SemaineStrip` : la card de la
// route et l'ardoise sont la MÊME matière, pas deux imitations.

/// Le décalage d'une transition — un `ViewModifier` plutôt qu'un
/// `.move(edge:)`, parce que `.move` déplace de TOUTE la hauteur du conteneur
/// (ici la card entière) : la pierre partirait à 138 pt au lieu d'un pas.
private struct Decale: ViewModifier {
    var dy: CGFloat
    func body(content: Content) -> some View { content.offset(y: dy) }
}

/// LA GÉOMÉTRIE DE LA COLONNE — sortie de la card pour qu'on puisse la juger
/// à trois réglages côte à côte, jamais de mémoire.
///
/// ⚠️ **C'EST L'AIR ENTRE LES PIERRES QUI COMMANDE**, et la route l'a déjà
/// payé : « pas de galet qui se touche » lui a coûté trois passes de calage,
/// et son minimum mesuré est **31,6 pt pour des galets de 62** — soit un
/// rapport air/Ø de **0,51**. Un premier jet à 57 de pas et ±18 de serpentin
/// ne laissait que **7,8 pt** entre le nœud d'avant et aujourd'hui : les
/// pierres se touchaient presque.
///
/// L'air ne se règle pas au pas seul : deux voisins sont séparés de
/// `√(A² + P²) − (r₁ + r₂)`, donc c'est le SERPENTIN qui rend l'air le moins
/// cher — il écarte sans rien coûter en hauteur, et la hauteur est bornée par
/// la poignée du pull.
struct CardRouteGeo: Equatable {
    var nom: String
    /// La hauteur de la card. ⚠️ Bornée : 0,620 × 874 = 542 pt de haut, et la
    /// poignée du « pull to start » mange les 112 derniers points → 220 pt au
    /// maximum, et il faut laisser de l'air sous elle.
    var hauteur: CGFloat
    var dSeance: CGFloat
    var dActif: CGFloat
    /// Le pas vertical entre deux nœuds.
    var pas: CGFloat
    /// LE DÉBATTEMENT du serpentin, en points : l'écart horizontal ENTRE deux
    /// pierres voisines (l'actif d'un côté, ses voisins de l'autre, chacun à
    /// la moitié). La route fait le même écart — 76 pt de son axe à son flanc.
    var amplitude: CGFloat
    /// L'axe de la colonne dans la card.
    var axeX: CGFloat
    /// Les pierres ne portent que le JOUR (sans son mois) — obligatoire dès
    /// qu'elles descendent sous Ø 44, voir `GaletEtape.jourSeul`.
    var jourSeul: Bool = false

    /// L'AIR MINIMUM entre deux pierres voisines, calculé comme la route le
    /// calcule — bord à bord, pas centre à centre.
    var air: CGFloat {
        let d = sqrt(amplitude * amplitude + pas * pas)
        return d - (dSeance + dActif) / 2
    }
    /// Le rapport de la route : 31,6 / 62 = 0,51.
    var rapport: CGFloat { air / ((dSeance + dActif) / 2) }

    /// ⚠️ **LA CARD EST UNE ARDOISE, PAS UN PANNEAU** (29-08, son verdict :
    /// « c'est un peu trop gros, ça va casser l'UI de la home — elle doit être
    /// quasiment de la même taille, peut-être 10 px de plus »). L'ardoise
    /// « This week » qu'elle remplace fait **354 × 128** : la cible est 138.
    ///
    /// À cette hauteur, la géométrie n'a plus de jeu, et c'est une chaîne de
    /// contraintes, pas un goût :
    ///  · la pierre du haut doit tenir sous le bord → `pas + Ø/2 ≤ 69` ;
    ///  · l'air vaut `√(A² + pas²) − (r₁+r₂)` et doit rester au rapport de la
    ///    route (0,51) → à pas 45, il faut **A ≥ 44** ;
    ///  · le halo de l'actif (0,95 × Ø) doit mourir avant le bord droit →
    ///    `axe + A + 0,95 Ø ≤ 354` ;
    ///  · et le mois d'une date ne descend pas sous 5,5 pt → **une pierre à
    ///    Ø 38 ne peut plus porter son mois**, elle porte le jour seul.
    /// Ce dernier point n'est pas une perte : le jour reprend la place du mois
    /// (0,42 × Ø), donc il fait 16 pt — plus gros qu'à Ø 44 avec son mois.
    ///
    /// ⚠️ Le pas est descendu de 45 à 42 pour une raison qui ne se voit qu'à
    /// la capture : à 45, la LUNE du haut arrivait à 2 pt du bord de la card —
    /// elle l'embrassait. Une pierre qui touche son cadre se lit comme une
    /// erreur de gabarit, pas comme un objet posé. Trois points de pas lui
    /// rendent 6 pt d'air, et l'air entre pierres ne tombe qu'à 21,3 — soit
    /// exactement le rapport de la route.
    ///
    /// ⚠️ **ET LES VOISINES SONT COUPÉES PAR LES BORDS** (29-08 : « c'est joli
    /// aussi quand c'est coupé par la card en haut et en bas, je veux ça »).
    /// C'est la loi des pochettes du bac de cette maison — la coupe est un
    /// CHOIX, pas un débordement — et elle renverse la contrainte : tant que
    /// les pierres devaient tenir entières dans 138 pt, elles rapetissaient
    /// (Ø 38) ; coupées, elles redeviennent grandes (Ø 44 et 50) et le pas
    /// remonte à 58. On y gagne l'air ET la présence.
    ///
    /// Le pas est calé pour que la coupe soit FRANCHE mais que le centre reste
    /// dedans : centre du haut à 11 pt du bord, donc un quart de la pierre
    /// dehors, et son chiffre entier.
    ///
    /// ⚠️ Et c'est un deuxième argument pour le jour seul : une pierre coupée
    /// qui porterait le mois SOUS son jour se ferait couper le mois. Le jour,
    /// centré, survit à la coupe.
    ///
    /// ⚠️ Les diamètres remontent une dernière fois (44/50 → **48/54**) pour la
    /// même raison : coupée, une pierre ne montre qu'environ trois quarts
    /// d'elle-même, donc elle doit partir plus grande pour peser autant.
    static let compacte = CardRouteGeo(nom: "compacte", hauteur: 138,
                                       dSeance: 48, dActif: 54,
                                       pas: 58, amplitude: 52, axeX: 262,
                                       jourSeul: true)
    /// LE GRAND FORMAT — gardé pour la comparaison : il tient le rapport de la
    /// route avec le mois sous chaque jour, mais il coûte 52 pt de hauteur sur
    /// la home, et c'est ça qui cassait la page.
    static let chemin = CardRouteGeo(nom: "chemin", hauteur: 190,
                                     dSeance: 44, dActif: 52,
                                     pas: 58, amplitude: 52, axeX: 244)

    static let toutes = [compacte, chemin]
}

/// LES MINUTES DE LA SÉANCE — sa propre horloge, à la MINUTE.
///
/// ⚠️ `.periodic(by: 60)` et non `.animation` : un player n'est pas un
/// chronomètre, et la seconde par seconde était un tic (verdict déjà payé sur
/// `WorkoutPill`). Une horloge à la minute ne coûte rien, et elle est SCOPÉE à
/// ce seul texte — elle ne réveille ni la card ni la page.
private struct MinutesSeance: View {
    var depuis: Date?

    var body: some View {
        if let depuis {
            TimelineView(.periodic(from: depuis, by: 60)) { tl in
                let _ = SondeVol.shared.tic(3)
                let m = Int(tl.date.timeIntervalSince(depuis) / 60)
                // ⚠️ COURT PAR OBLIGATION : la gouttière ne fait que 174 pt
                // avant les galets. « Ça vient de commencer » y était tronqué
                // — vu à la capture `chemin-140857.png`, et c'est exactement
                // le défaut que la borne de largeur sert à rendre VISIBLE au
                // lieu de le laisser glisser sous les pierres.
                Text(m < 1 ? "À l'instant" : "Depuis \(m) min")
                    .contentTransition(.numericText())
            }
        } else {
            Text("Séance ouverte")
        }
    }
}

struct CardRoute: View {
    /// L'état du chemin — la même lecture que la route. ⚠️ Elle se calcule
    /// UNE fois chez l'hôte (l'école de `SemaineStats`), jamais dans un
    /// `body` : la home vit sous une `TimelineView` à 60 Hz.
    var lecture: EcranSpec.Lecture
    /// 0 → 1, l'arrivée de la page (la card se pose en queue de phrase).
    var pose: Double = 1
    var verre: Bool = false
    var lisere: Bool = true
    /// LA PORTE DE LA ROUTE. ⚠️ Elle passe par la CARD, jamais par les
    /// galets : ils sont inertes, et c'est exactement pour ça (un enfant qui
    /// a un geste bat le tap de son parent — le bug des mini-cards de
    /// l'ardoise, qui volaient cette même porte).
    var onTap: () -> Void = {}

    // MARK: les cotes

    /// La largeur de l'ardoise, à la gouttière de la phrase.
    static let L: CGFloat = 354

    /// LES TAILLES SONT MESURÉES (J1, `-duoLab -duoGalets -vitrine`) : le halo
    /// de l'actif vaut 0,95 × Ø et son pad Ø/2 + 26, donc **il sort de son
    /// propre cadre dès que Ø dépasse 57,8**. Sur la route ça ne coûte rien
    /// (rien ne clippe, 31,6 pt d'air) ; ici l'ardoise CLIPPE ses coins — un
    /// galet à Ø 62 se ferait couper son halo par le bord de la card. Aucun
    /// réglage ne dépasse donc 56.
    ///
    /// L'autre borne est l'encre : le mois vaut 0,125 × Ø, et le plancher de
    /// la maison est 5,5 pt (le mois de la mini-card du calendrier) — donc
    /// **Ø 44 au minimum** pour un galet qui porte une date.
    var geo: CardRouteGeo = .compacte

    /// ⚠️ **LA PIÈCE NE RÉTRÉCIT PLUS** (29-08 : « la deuxième, un peu trop
    /// petites la flamme et la lune »). Sur la route, elle fait 53 contre 62 —
    /// c'est la petite récompense rapide, et elle a 44 pt d'air autour d'elle
    /// pour exister. Ici, ce rapport la mettait à Ø 37,6 **et elle est
    /// coupée** : il n'en restait qu'un croissant de 26 pt. Deux réductions
    /// qui se multiplient ne font pas une nuance, elles font disparaître.
    ///
    /// Dans la card, une récompense n'est donc jamais plus petite qu'une
    /// séance. Ce qui les distingue reste ce qui les distinguait déjà sur la
    /// route : le GLYPHE (le croissant de la maison) et l'or de la
    /// disponibilité — pas la taille.
    ///
    /// ⚠️ Le plafond de la lune n'est plus la hauteur de la card — depuis que
    /// les voisines sont COUPÉES par les bords, une pierre a le droit de
    /// dépasser. Il reste celui du HALO, mesuré au banc : au-delà de Ø 57,8 le
    /// halo sort de son propre cadre, et ici c'est la card qui le trancherait.
    private var dPiece: CGFloat { geo.dSeance }
    private var dLune: CGFloat { min(geo.dSeance * 78 / 62, 56) }

    /// ⚠️ **TROIS PIERRES NE FONT PAS UN SERPENTIN AVEC LE `dx` DE LA ROUTE**
    /// (29-08 : « j'aime bien la disposition en mode serpentin, pas
    /// diagonale »). Et ce n'est pas un réglage raté, c'est arithmétique : la
    /// route pose ses nœuds sur une sinusoïde de période 4 — 0, +76, 0, −76 —
    /// donc **une fois sur deux, trois nœuds consécutifs donnent (+76, 0, −76)**,
    /// c'est-à-dire une DIAGONALE. L'onde ne se lit que sur l'autre phase, où
    /// les deux voisins sont du même côté et l'actif de l'autre.
    ///
    /// La card force donc l'alternance : les voisins à un flanc, l'actif à
    /// l'autre, chacun à la moitié du débattement. Elle garde de la route ce
    /// qui reste vrai — le SENS du virage, pris sur le rang de l'actif : il
    /// bascule quand on avance, donc la card ne dessine pas toujours la même
    /// courbe.
    private func dx(_ rang: Int) -> CGFloat {
        let sens: CGFloat = (apercu.actif.n % 4) < 2 ? 1 : -1
        return (rang == 0 ? 1 : -1) * sens * geo.amplitude / 2
    }

    private var apercu: EcranSpec.Apercu { EcranSpec.apercu(lecture) }

    /// LE DOIGT EST SUR LA BANDE — 0 au repos, 1 pendant le geste. Il allume
    /// le bord de la card, et rien d'autre.
    @State private var defile = false
    /// ⚠️ Le banc force la lueur : elle ne dure que le temps d'un geste, et
    /// ni `simctl` ni `osascript` ne posent un doigt sur cette machine. Sans
    /// ce drapeau, son intensité ne serait jugeable que sur l'appareil.
    var lueurForcee: Bool = false
    /// LE COMPTEUR DES RETOURS — il ne sert qu'à déclencher l'haptique. Un
    /// `trigger:` a besoin d'une valeur qui CHANGE ; un booléen qui repasse à
    /// la même valeur ne déclencherait rien au deuxième retour.
    @State private var recentrages = 0

    /// `-colonne` : l'ancienne composition à TROIS pierres empilées, gardée
    /// pour la comparaison. La bande des neuf est le défaut depuis le 29-08.
    /// `-sansGalet` : l'horloge du galet actif en pause. Bisection — elle
    /// tourne à CADENCE LIBRE (`minimumInterval: nil`) dès que l'état est
    /// `.actif`, et depuis que la card est montée pendant la séance, elle
    /// tourne pendant toute la séance.
    static let sansGalet = CommandLine.arguments.contains("-sansGalet")

    private static let colonneSeule =
        CommandLine.arguments.contains("-colonne")

    /// UNE SÉANCE EST EN COURS (02-09). Un PARAMÈTRE DE VALEUR, jamais un
    /// `@Query` : cette card est aussi montée par son banc `RouteCardLab`, qui
    /// n'a pas de home — un `@Query` y créerait une seconde source de vérité à
    /// côté de celle de `HomeNuit`, et le banc deviendrait aveugle à cet état.
    var enSeance: Bool = false
    /// Le début de la séance ouverte, pour le compteur de minutes.
    var debutSeance: Date? = nil

    var body: some View {
        // ⚠️ **UNE SEULE HORLOGE POUR LE POINT ET POUR LE HALO**, et elle
        // n'existe QUE pendant une séance. Deux horloges donneraient deux
        // souffles qui dérivent l'un par rapport à l'autre ; et une horloge
        // permanente sur cette card serait un coût permanent sur la page dont
        // la cadence est le chantier.
        //
        // ⚠️ Fonction PURE DU TEMPS, pas un `@State` + `repeatForever` : cette
        // card est démontée à chaque film de départ (`if verreMonte`), et un
        // état de phase y sauterait à chaque aller-retour de la home.
        if enSeance {
            TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                    paused: reduceMotion || RythmeEcran.dortHome)) { tl in
                let _ = SondeVol.shared.tic(3)
                corps(souffle(tl.date.timeIntervalSinceReferenceDate))
            }
        } else {
            corps(0)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// LES DEUX PÉRIODES, PREMIÈRES ENTRE ELLES — la loi des liserés. Et
    /// encore d'autres que celles du contour d'écran (6,1 / 9,7) et de la
    /// fumée (7,3 / 11,7) : trois respirations à l'écran ne doivent jamais
    /// tomber en phase, sinon toute la page se met à battre ensemble.
    private func souffle(_ t: Double) -> Double {
        guard enSeance, !reduceMotion else { return enSeance ? 0.8 : 0 }
        let a = sin(t * 2 * .pi / 4.7)
        let b = sin(t * 2 * .pi / 7.9 + 0.8)
        return 0.62 + 0.26 * a + 0.12 * b
    }

    @ViewBuilder
    private func corps(_ s: Double) -> some View {
        ZStack(alignment: .topLeading) {
            ArdoiseFond(largeur: Self.L, hauteur: geo.hauteur, rayon: 26,
                        verre: verre, lisere: lisere,
                        // ⚠️ LE HALO DE SÉANCE PASSE PAR LA LUEUR DE
                        // L'ARDOISE, pas par le halo du galet actif : celui-là
                        // sort de son propre cadre au-delà de Ø 57,8 (on est à
                        // 54), la bande le masque et la card le clippe — il
                        // serait tranché deux fois. Et `GaletEtape` est PARTAGÉ
                        // avec la page route, qui est validée.
                        lueur: enSeance ? s
                             : ((defile || lueurForcee) ? 1 : 0))
            texte(s)
            if Self.colonneSeule {
                colonne
            } else {
                bande.padding(.leading, 146)
            }
        }
        .frame(width: Self.L, height: geo.hauteur)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        // LA PORTE — une seule surface, celle de la card entière.
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onTapGesture(perform: onTap)
        .opacity(pose)
        .offset(y: 14 * (1 - pose))
    }

    // MARK: les deux lignes

    /// LA MÊME GRAMMAIRE QUE LA DALLE DE LA ROUTE : un sur-titre gris
    /// interlettré, un titre en dégradé blanc. La card et la dalle sont le
    /// même objet vu deux fois — elles ne peuvent pas parler deux langues.
    ///
    /// ⚠️ **IL EST CENTRÉ EN HAUTEUR, PAS POSÉ EN HAUT** (29-08). Collé au
    /// bord haut, il laissait tout le bas-gauche de la card VIDE pendant que
    /// les trois pierres se serraient à droite : la card se lisait comme un
    /// rectangle à moitié rempli. Centré, les deux masses se répondent —
    /// le texte à gauche, le chemin à droite, sur le même axe.
    /// LA GOUTTIÈRE RÉELLE du texte — et elle n'était bornée NULLE PART.
    /// Le bloc s'étendait sur les 354 pt de la card alors que les galets
    /// commencent à x = 146 : « Étape 3 sur 9 » est court, donc ça ne se
    /// voyait pas. Un libellé de séance plus long serait passé SOUS les
    /// pierres, sans erreur ni warning. 354 − 22 (marge) − 146 (les galets)
    /// − 12 (l'air) = 174.
    private static let gouttiere: CGFloat = 174

    @ViewBuilder
    private func texte(_ s: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                // LE POINT VIVANT — il ne dit qu'une chose : ça tourne.
                // ⚠️ SOURD AU DOIGT : la porte de la route est le tap de la
                // card ENTIÈRE, et un enfant qui a une zone tactile la
                // volerait (le bug des mini-cards, payé deux fois — c'est
                // aussi pourquoi les neuf galets sont `inerte: true`).
                if enSeance {
                    // LE POINT VIVANT — il ne dit qu'une chose : ça tourne.
                    // ⚠️ **TROIS GESTES SUR LE MÊME SOUFFLE** (verdict 02-09 :
                    // « anime le bouton blanc »). Une opacité seule se remarque
                    // mal sur 6 pt : le point RESPIRE aussi en taille, et une
                    // auréole naît sous lui au sommet. Les trois lisent le même
                    // `s`, donc ils ne peuvent pas se désaccorder.
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .scaleEffect(0.82 + 0.34 * s)
                        .opacity(0.42 + 0.58 * s)
                        .background {
                            Circle()
                                .fill(.white)
                                .frame(width: 6, height: 6)
                                .scaleEffect(1.6 + 1.5 * s)
                                .opacity(0.16 * s)
                                .blur(radius: 3)
                        }
                        .allowsHitTesting(false)
                }
                Text(enSeance ? "SÉANCE EN COURS"
                              : "CHAPITRE \(apercu.chapitre)")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.6)
                    .foregroundStyle(enSeance
                                     ? Color(white: 0.72)
                                     : Color(white: 0.52))
            }
            ligneBasse
        }
        .lineLimit(1)
        .padding(.leading, 22)
        .frame(width: Self.gouttiere + 22, alignment: .leading)
        .frame(width: Self.L, height: geo.hauteur, alignment: .leading)
    }

    /// ⚠️ **DEUX TRANSITIONS, PAS UNE.** `.numericText()` est un ODOMÈTRE : il
    /// est fait pour des CHIFFRES qui roulent. Il reste sur « Étape R sur T »,
    /// où seuls les nombres bougent. Mais lui faire jouer un changement de
    /// PHRASE ferait rouler des lettres — au mieux un fondu bizarre, au pire
    /// illisible, et c'est précisément la ligne qui doit dire que l'app est
    /// vivante. Le passage repos ↔ séance change donc d'IDENTITÉ de vue et
    /// passe en fondu.
    @ViewBuilder
    private var ligneBasse: some View {
        Group {
            if enSeance {
                MinutesSeance(depuis: debutSeance)
            } else {
                Text("Étape \(apercu.rang) sur \(apercu.total)")
                    .contentTransition(.numericText())
            }
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(LinearGradient(
            colors: [Color(white: 1.0), Color(white: 0.82)],
            startPoint: .top, endPoint: .bottom))
        .id(enSeance)
        .transition(.opacity)
    }

    // MARK: les trois galets

    /// UNE PIERRE DE LA COLONNE — le nœud ET son rang. ⚠️ **L'IDENTITÉ EST
    /// CELLE DU NŒUD, pas celle de la place.** C'est toute la condition de
    /// l'animation d'avancée : si les trois pierres sont trois vues stables
    /// dont le contenu change, SwiftUI fait un FONDU CROISÉ — les chiffres se
    /// substituent sur place et rien ne bouge. Identifiées par leur `id` de
    /// nœud, la même pierre change de rang, donc elle GLISSE ; celle qui sort
    /// et celle qui entre sont, elles, de vraies naissances et de vraies
    /// morts. C'est la loi du dépliage : il vit dans les DONNÉES.
    private struct Pierre: Identifiable {
        let e: EcranSpec.EtapeSpec
        let rang: Int
        var id: Int { e.id }
    }

    private var pierres: [Pierre] {
        var out: [Pierre] = []
        if let a = apercu.avant { out.append(Pierre(e: a, rang: -1)) }
        out.append(Pierre(e: apercu.actif, rang: 0))
        if let p = apercu.apres { out.append(Pierre(e: p, rang: 1)) }
        return out
    }

    // MARK: - LA BANDE DU CHAPITRE (29-08)

    /// ⚠️ **LES NEUF NŒUDS DU CHAPITRE, ET ON SCROLLE DEDANS** (sa demande :
    /// « ajoute le scroll dans la card, on voit les 9 galets du chapitre en
    /// cours ; et au vrai tap on entre dans la route »).
    ///
    /// ⚠️⚠️ **LE SCROLL EST HORIZONTAL, ET CE N'EST PAS UN GOÛT.** La home
    /// entière vit sous le « pull to start » — un `DragGesture` VERTICAL qui
    /// couvre la page. Un scroll vertical dans la card lui disputerait le
    /// doigt à chaque geste, et c'est le piège du bouton sous le drag
    /// d'ancêtre, déjà payé ici. Deux gestes ne se partagent proprement que
    /// s'ils ont des AXES différents : la page tire vers le haut, la card
    /// défile sur le côté, et personne ne vole personne.
    ///
    /// ⚠️ **LA COUPE CHANGE D'AXE, ELLE NE DISPARAÎT PAS.** Elle lui plaisait
    /// en haut et en bas ; ici ce sont les bords GAUCHE et DROIT de la bande
    /// qui tranchent les pierres — et c'est mieux, parce qu'une bande coupée
    /// dit « ça continue », ce qui est exactement ce qu'un chemin doit dire.
    private var chapitreNoeuds: [EcranSpec.EtapeSpec] {
        EcranSpec.etapes.filter { $0.ecran == apercu.actif.ecran }
    }

    /// La largeur laissée à la bande : la card moins le bloc de texte.
    private var largeurBande: CGFloat { Self.L - 146 }

    /// ⚠️ **LE FONDU DES DEUX BORDS** (29-08 : « blur effect au top et au
    /// bottom, pour que ce soit naturel »). C'est un MASQUE, jamais un
    /// `.blur` : un flou par objet coûte 27 img/s dans cette maison — mesuré —
    /// et un `.blur` posé sur la bande laisserait en plus son calque sur tout
    /// le rectangle de l'hôte (la loi du flou qui laisse son voile). Un
    /// dégradé d'opacité ne coûte rien et dit la même chose : le chemin ne
    /// commence pas au bord de la card, il le TRAVERSE.
    private var fonduBords: LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear,       location: 0.00),
            .init(color: .white,       location: 0.22),
            .init(color: .white,       location: 0.78),
            .init(color: .clear,       location: 1.00)
        ], startPoint: .top, endPoint: .bottom)
    }

    private var bande: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                // ⚠️ **PARESSEUX, ET C'EST MESURÉ** : en `HStack` les NEUF
                // galets existent tout le temps, donc neuf passes de shader
                // Metal par image pour en montrer quatre. Coût relevé au banc,
                // même build, machine calme : **27,6 img/s contre 39,1** pour
                // la colonne à trois pierres — 30 % de la home. Le `Lazy` ne
                // construit que ce que la fenêtre voit.
                LazyVStack(spacing: 0) {
                    ForEach(chapitreNoeuds) { e in
                        galetBande(e)
                            .frame(height: geo.pas)
                            .id(e.id)
                    }
                }
                // Les deux bouts doivent pouvoir se CENTRER : sans ces marges,
                // le premier et le dernier nœud restent collés à leur bord et
                // ne peuvent jamais venir au milieu.
                .padding(.vertical, (geo.hauteur - geo.pas) / 2)
                // ⚠️ **LE TAP DOIT ÊTRE POSÉ SUR LE CONTENU DU SCROLL** (sa
                // demande : « au VRAI tap on entre dans la route »). Le
                // `onTapGesture` de la card ne reçoit RIEN sous la bande : un
                // `ScrollView` prend le doigt sur toute sa surface. Posé ici,
                // SwiftUI tranche tout seul entre les deux — le glissement
                // appartient au défilement, le toucher immobile au tap. Et le
                // `contentShape` est obligatoire : sans lui, l'air ENTRE les
                // pierres n'est pas une cible, et c'est la moitié de la bande.
                .contentShape(Rectangle())
                .onTapGesture { onTap() }
            }
            .frame(width: largeurBande, height: geo.hauteur)
            .mask(fonduBords)
            // ⚠️ AUJOURD'HUI EST AU MILIEU À L'OUVERTURE, et sans animation :
            // une bande qui arrive en glissant se lit comme un mouvement qu'on
            // a raté, pas comme une position.
            .onAppear { proxy.scrollTo(apercu.actif.id, anchor: .center) }
            .onChange(of: apercu.actif.id) { _, id in
                withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            // ⚠️ **LE CHEMIN REVIENT À AUJOURD'HUI QUAND ON LÂCHE** (30-08 :
            // « quand on scrolle et qu'on arrête, ça revient au jour
            // actuel »). La card n'est pas un explorateur : elle dit où on en
            // est. On peut regarder ailleurs, mais elle se remet en place.
            //
            // ⚠️ **ET SEULEMENT APRÈS UN GESTE HUMAIN.** Le recentrage est
            // lui-même une animation, donc il repasse par `.animating` puis
            // `.idle` : sans la garde sur l'ancienne phase, il se
            // redéclencherait sur sa propre retombée — une boucle qui ne
            // s'arrête jamais. On ne recentre qu'en sortant de `.tracking`,
            // `.interacting` ou `.decelerating`.
            .onScrollPhaseChange { avant, apres in
                let auDoigt = avant == .tracking || avant == .interacting
                    || avant == .decelerating
                withAnimation(.easeOut(duration: 0.22)) {
                    defile = apres != .idle
                }
                guard apres == .idle, auDoigt else { return }
                // ⚠️ **L'HAPTIQUE PART AVEC LE RESSORT, PAS À SON ARRIVÉE.**
                // Le retour dure 0,55 s : une secousse à la fin arriverait
                // après que le doigt a lâché, et se lirait comme un incident.
                // Posée au départ, elle DIT le mouvement — c'est la card qui
                // reprend sa place, et on le sent au moment où on la voit.
                recentrages &+= 1
                withAnimation(.spring(response: 0.55,
                                      dampingFraction: 0.88)) {
                    proxy.scrollTo(apercu.actif.id, anchor: .center)
                }
            }
            // ⚠️ **UN `trigger:`, PAS UN APPEL IMPÉRATIF DANS LA FERMETURE**
            // (l'école de la maison, cf. `HomeAuroraView`) : SwiftUI joue le
            // retour au bon moment du cycle, et il ne peut pas se jouer deux
            // fois pour un seul changement. `.light` à 0,55 — la card se
            // repose, elle ne cogne pas : c'est le même registre que la pose
            // d'un galet, jamais celui d'un refus.
            .sensoryFeedback(.impact(weight: .light, intensity: 0.55),
                             trigger: recentrages)
        }
    }

    /// Une pierre de la bande. Le serpentin de la route est TRANSPOSÉ : son
    /// `dx` (±76, période 4) devient le `dy` de la bande — les neuf nœuds
    /// d'un chapitre y dessinent donc l'onde ENTIÈRE, ce que trois pierres ne
    /// pouvaient pas faire.
    private func galetBande(_ e: EcranSpec.EtapeSpec) -> some View {
        let actif = e.id == apercu.actif.id
        let taille: CGFloat = {
            if e.moon { return dLune }
            if e.piece { return dPiece }
            return actif ? geo.dActif : geo.dSeance
        }()
        return GaletEtape(etat: lecture.etat(e),
                          glyphe: lecture.glyphe(e),
                          glypheLune: e.special,
                          taille: taille,
                          graine: Double(e.id),
                          figee: Self.sansGalet,
                          lentille: false,
                          date: lecture.date(e),
                          jourSeul: geo.jourSeul,
                          inerte: true)
            // Le serpentin retrouve son axe NATUREL : le `dx` de la route est
            // un écart horizontal, et la bande défile maintenant à la
            // verticale — c'est la même courbe que la page, pas une copie.
            .offset(x: e.dx * (geo.amplitude / 2) / 76)
    }

    private var colonne: some View {
        ZStack {
            ForEach(pierres) { p in
                galet(p.e, rang: p.rang)
                    // ⚠️ **LA COUPE EST CE QUI REND L'ARRIVÉE POSSIBLE.** Une
                    // pierre qui entre vient de SOUS le bord et une pierre qui
                    // sort passe au-dessus : elles ne surgissent pas dans le
                    // vide, elles traversent l'arête. La card clippe déjà —
                    // c'est le même choix qui donne le dessin au repos et le
                    // mouvement à l'avancée.
                    .transition(.asymmetric(
                        insertion: .modifier(active: Decale(dy: geo.pas),
                                             identity: Decale(dy: 0))
                            .combined(with: .opacity),
                        removal: .modifier(active: Decale(dy: -geo.pas),
                                           identity: Decale(dy: 0))
                            .combined(with: .opacity)))
            }
        }
        .frame(width: Self.L, height: geo.hauteur)
    }

    /// ⚠️ **LE GALET EST INERTE** : sur la home, le doigt appartient à la page
    /// (le « pull to start ») et à la card (la porte de la route). Un galet
    /// qui garde ses gestes mangerait les deux.
    ///
    /// ⚠️ **ET SA LENTILLE EST COUPÉE.** Le natif ne se justifie que là où une
    /// vidéo passe dessous ; ici il vit sur l'ardoise, qui est déjà du verre —
    /// deux captures de fond empilées pour peindre un voile gris. Son sort
    /// définitif se tranche à la cadence (J5), pas à l'œil.
    private func galet(_ e: EcranSpec.EtapeSpec, rang: Int) -> some View {
        let etat = lecture.etat(e)
        let taille: CGFloat = {
            if e.moon { return dLune }
            if e.piece { return dPiece }
            return rang == 0 ? geo.dActif : geo.dSeance
        }()
        return GaletEtape(etat: etat,
                          glyphe: lecture.glyphe(e),
                          glypheLune: e.special,
                          taille: taille,
                          graine: Double(e.id),
                          figee: Self.sansGalet,
                          lentille: false,
                          date: lecture.date(e),
                          jourSeul: geo.jourSeul,
                          inerte: true)
            .position(x: geo.axeX + dx(rang),
                      y: geo.hauteur / 2 + CGFloat(rang) * geo.pas)
    }
}

// MARK: - Le banc (`-duoLab -routeCard <cas>`)

/// LE BANC DE LA CARD — la card SEULE, sur le noir, dans les cinq situations
/// que le chemin sait produire. C'est le tour de boucle court : aucune donnée
/// réelle, aucune home, on juge le dessin.
///
/// ⚠️ Il passe par `-duoLab` parce que la racine (`WoopApp`) est tenue par un
/// autre chantier en ce moment : on n'ouvre pas un fichier que quelqu'un
/// d'autre est en train d'écrire.
///
/// Les cas — ils ne sont pas inventés, ils sont les positions réelles d'un
/// chapitre `S S S ◆ S S S S ☾` :
///   `debut`        rang 1 — le tout premier nœud : il n'y a RIEN au-dessus ;
///   `milieu`       rang 3 — la récompense arrive juste dessous, éteinte ;
///   `apresReward`  rang 5 — la récompense est passée, RÉCLAMÉE, au-dessus
///                  (le cas qu'elle a tranché : on l'affiche telle quelle) ;
///   `finChapitre`  rang 8 — le trésor du chapitre attend juste dessous ;
///   `chap2`        le chapitre 2, dont la récompense du milieu est la lune.
struct RouteCardLab: View {
    private static let cas: String = {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: "-routeCard"), i + 1 < a.count,
              !a[i + 1].hasPrefix("-") else { return "milieu" }
        return a[i + 1]
    }()

    /// `-planche` : les trois réglages l'un sous l'autre, dans le même cas.
    /// Un réglage ne se juge pas seul — il se juge contre son voisin.
    private static let planche = CommandLine.arguments.contains("-planche")

    /// `-planCas` : le MÊME réglage dans quatre situations du chemin. Un
    /// réglage qui tient au cas courant et casse au premier nœud du chapitre
    /// n'est pas un réglage, c'est une chance.
    private static let planCas = CommandLine.arguments.contains("-planCas")
    private static let cas4 = ["debut", "apresReward", "finChapitre", "chap2"]

    /// ⚠️ `-avance` : LE SEUL MOYEN DE JUGER L'ANIMATION. Dans l'app, l'étape
    /// n'avance qu'à la clôture d'une séance — et en mode démo elle n'avance
    /// **jamais** (le chemin rend toujours « étape 3 »). Sans ce banc,
    /// l'animation d'avancée serait du code qu'on ne peut pas regarder.
    /// Le chemin avance d'une séance toutes les 2,6 s.
    private static let avance = CommandLine.arguments.contains("-avance")
    /// `-bandeLueur` : la card comme si un doigt était en train de la faire
    /// défiler — le seul moyen de juger l'intensité de la lueur sans appareil.
    private static let lueur = CommandLine.arguments.contains("-bandeLueur")
    @State private var pas = 0
    @State private var horloge: Timer?

    var body: some View {
        ZStack {
            Color.black
            if Self.planCas {
                VStack(spacing: 4) {
                    ForEach(Self.cas4, id: \.self) { c in
                        VStack(spacing: 2) {
                            CardRoute(lecture: Self.lecture(c), geo: .compacte)
                            Text(Self.legende(c))
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(Color(white: 0.42))
                        }
                    }
                }
            } else {
                VStack(spacing: 14) {
                    Text(Self.legende(Self.cas))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color(white: 0.42))
                    ForEach(Self.planche ? CardRouteGeo.toutes
                                         : [CardRouteGeo.compacte], id: \.nom) { g in
                        VStack(spacing: 4) {
                            CardRoute(lecture: Self.lecture(Self.cas,
                                                            decalage: pas),
                                      geo: g,
                                      lueurForcee: Self.lueur)
                                // LE FANTÔME DE L'ARDOISE — 354 × 128, la
                                // taille de « This week ». Une card qui dit
                                // « à peine plus grande » doit le PROUVER,
                                // pas le promettre.
                                .overlay {
                                    if Self.planche {
                                        RoundedRectangle(cornerRadius: 26,
                                                         style: .continuous)
                                            .strokeBorder(style: StrokeStyle(
                                                lineWidth: 1, dash: [4, 4]))
                                            .foregroundStyle(Color.orange
                                                .opacity(0.55))
                                            .frame(width: 354, height: 128)
                                    }
                                }
                            Text(Self.cotes(g))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(g.air < 20 ? Color.red
                                                 : Color(white: 0.42))
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .environment(\.colorScheme, .dark)
        .onAppear {
            guard Self.avance, horloge == nil else { return }
            horloge = Timer.scheduledTimer(withTimeInterval: 2.6,
                                           repeats: true) { _ in
                // LA COURBE DE L'AVANCÉE : un ressort à peine amorti, jamais
                // un ease — une pierre qui monte d'un cran doit se POSER,
                // c'est un objet, pas un fondu.
                withAnimation(.spring(response: 0.62, dampingFraction: 0.86)) {
                    pas += 1
                }
            }
        }
        .onDisappear { horloge?.invalidate(); horloge = nil }
    }

    /// Les cotes du réglage, CALCULÉES — l'air bord à bord entre deux pierres
    /// voisines, et son rapport à leur taille. La route tient 31,6 pt pour des
    /// galets de 62, soit 0,51 : c'est l'étalon.
    private static func cotes(_ g: CardRouteGeo) -> String {
        let air = String(format: "%.1f", g.air).replacingOccurrences(
            of: ".", with: ",")
        let rap = String(format: "%.2f", g.rapport).replacingOccurrences(
            of: ".", with: ",")
        return "\(g.nom)  H \(Int(g.hauteur))  Ø \(Int(g.dSeance))/"
            + "\(Int(g.dActif))  pas \(Int(g.pas))  serpentin ±"
            + "\(Int(g.amplitude))  ·  AIR \(air) pt  (rapport \(rap) "
            + "contre 0,51 sur la route)"
    }

    /// L'étape de chaque cas, et l'état qui va avec : tout ce qui précède est
    /// FAIT (avec sa vraie estampille), la récompense d'avant est réclamée
    /// quand le cas le demande.
    static func lecture(_ cas: String, decalage: Int = 0) -> EcranSpec.Lecture {
        let base: Int = {
            switch cas {
            case "debut": return 0          // chapitre 1, rang 1
            case "apresReward": return 4    // rang 5, la pièce est derrière
            case "finChapitre": return 7    // rang 8, le trésor est dessous
            case "chap2": return 9 + 4      // chapitre 2, rang 5
            default: return 2               // rang 3, la pièce est dessous
            }
        }()
        // `-avance` : on avance de SÉANCE en séance, jamais de nœud en nœud —
        // l'étape n'est jamais un nœud spécial (le calendrier ne compte que
        // les séances), et c'est ce qui fait qu'une récompense se glisse
        // parfois entre deux jours.
        let etape: Int = {
            guard decalage != 0, let j = EcranSpec.jour(deId: base) else {
                return base
            }
            return EcranSpec.id(pourJour: j + decalage)
        }()
        var faits: Set<Int> = []
        var dates: [Int: Date] = [:]
        for e in EcranSpec.etapes where e.id < etape && !e.special {
            faits.insert(e.id)
            dates[e.id] = Calendar.current.date(
                byAdding: .day, value: e.id - etape, to: Date())
        }
        // La récompense DÉPASSÉE est réclamée : c'est elle qu'on veut voir
        // au-dessus d'aujourd'hui, gravée et éteinte.
        let reclamees = Set(EcranSpec.etapes
            .filter { $0.special && $0.id < etape }.map(\.id))
        return EcranSpec.Lecture(etape: etape, faits: faits,
                                 datesFaites: dates, reclamees: reclamees)
    }

    private static func legende(_ cas: String) -> String {
        let l = lecture(cas)
        let a = EcranSpec.apercu(l)
        let nom = { (e: EcranSpec.EtapeSpec?) -> String in
            guard let e else { return "—" }
            if e.moon { return "lune" }
            if e.piece { return "pièce" }
            return "séance"
        }
        return "\(cas)  ·  \(a.nom)  ·  avant \(nom(a.avant))"
            + "  ·  après \(nom(a.apres))"
    }
}

/// LE BARREAU DU VERRE DE LA ROUTE (05-09) — `-sansVerreRoute` éteint le
/// verre natif de la card ROUTE, et RIEN d'autre. C'est la seule façon de
/// répondre à « est-ce ce verre qui coûte, en séance ? » : un moteur à la
/// fois, mesuré sur SON téléphone, jamais déduit.
enum CardRouteBanc {
    /// ⚠️ IL SURVIT AUX RELANCES (05-09). Un barreau qui s'évapore quand
    /// elle ferme et rouvre l'app à la main mesurerait l'inverse de ce
    /// qu'on croit — et une mesure qui ment est pire que pas de mesure.
    /// `-sansVerreRoute` l'éteint, `-avecVerreRoute` le rallume.
    static let cle = "woop.sansVerreRoute"

    static let sansVerre: Bool = {
        if CommandLine.arguments.contains("-sansVerreRoute") {
            UserDefaults.standard.set(true, forKey: cle)
            return true
        }
        if CommandLine.arguments.contains("-avecVerreRoute") {
            UserDefaults.standard.set(false, forKey: cle)
            return false
        }
        return UserDefaults.standard.bool(forKey: cle)
    }()
}
