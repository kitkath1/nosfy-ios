import SwiftUI

// MARK: - LE POINT DE SÉANCE (24-09) — un point blanc, un pulsar, des paillettes
//
// « Je revois le design de la pastille, c'est horrible. Je pensais à un point
//   blanc minimal avec un effet pulsar et des petites paillettes autour,
//   basta ! » (Kathryn, 24-09.)
//
// Le diamant du 23-09 est SUPPRIMÉ, pas retravaillé — avec lui partent le
// `Canvas`, ses huit facettes et son cœur de braise. Ce qui reste tient en
// trois choses, et rien d'autre :
//
//   · LE POINT — un disque blanc pur de 9 pt, qui respire à peine ;
//   · LE PULSAR — deux anneaux d'un demi-point qui NAISSENT sur le point et
//     s'en éloignent en s'effaçant. La lumière a une cause et un bord : elle
//     part du point, elle n'est jamais une nappe posée autour ;
//   · LES PAILLETTES — cinq grains d'un point, chacun sur SA période
//     (1,7 · 2,3 · 2,9 · 3,3 · 3,7 s, aucune multiple d'une autre), sinon
//     les cinq clignoteraient ensemble et ce serait une guirlande.
//
// ⚠️⚠️ OÙ IL VIT — CE QUI A CHANGÉ LE 24-09.
// « Il n'apparaît que dans le menu et sur aucune page, et il doit être centré
//   à côté des autres icônes dans le menu. »
// Le 23-09 il était posé sur la barre d'onglets, donc il n'existait QUE là où
// la barre existe — c'est-à-dire sur l'Accueil seul : les onglets Exercices et
// Profil masquent la barre (`toolbarVisibility(.hidden, for: .tabBar)`).
// Il a vécu quelques heures sur TOUS les écrans — et sur le vrai téléphone
// c'était un intrus : posé par-dessus le compteur d'une série, il regardait
// par-dessus l'épaule d'une page immersive, qui n'a pas de barre justement
// pour qu'on ne regarde qu'elle (verdict du 24-09 au soir : « pas de bouton
// REC, juste dans le menu, pas dans les pages chrono »).
//
// Il est donc ce qu'il a toujours été : **l'onglet Exercices pendant une
// séance**. Il vit là où la barre vit — l'Accueil seul, les deux autres
// onglets la masquant (`toolbarVisibility(.hidden, for: .tabBar)`). Deux
// exclusions de plus, et la même règle derrière :
//   · sur le LECTEUR il ne se pose pas — on y est déjà, un témoin qui dit
//     « ta séance t'attend » devant la séance elle-même ne dit rien (et c'est
//     aussi ce qui libère le bas de l'écran, où vit le galet Stop) ;
//   · pendant le film de départ non plus : la séance n'a pas encore commencé.
//
// ⚠️ SA HAUTEUR EST MESURÉE, ET ELLE NE DÉPEND PLUS DU CONTENEUR.
// Sur la dalle de l'iPhone 15 (1179 × 2556), le centre des glyphes d'onglet
// est à 2436 px du haut, soit **40 pt au-dessus du bas de l'ÉCRAN**. Le 23-09
// j'ai supposé que la surimpression de la racine s'arrêtait à la zone sûre et
// j'ai écrit 6 pt : si le conteneur descend jusqu'au bas de l'écran, le point
// tombe 34 pt trop bas. On ne suppose plus : la vue IGNORE la zone sûre, donc
// son bas EST le bas de l'écran, et la cote mesurée s'applique telle quelle.
//
// ⚠️ ET IL NE REDESSINE RIEN POUR ANIMER. Huit valeurs animées (opacités,
// échelles) et pas un pixel recalculé. Loi mesurée sur son iPhone le 05-09 :
// redessiner pour animer coûte 33 à 38 % de processeur, animer une valeur en
// coûte 4 à 18 %.
//
// Son barreau : `-sansRec` (rien n'est posé, l'onglet garde son coureur).

/// ⚠️⚠️ LE BARREAU MAÎTRE DE LA SÉANCE (24-09).
///
/// Les effets posés sur la séance sont des animations DÉCLARATIVES : aucune
/// ligne ne s'exécute par image, c'est le compositeur qui les tient. Un tic
/// de la sonde ne les verra jamais (et c'est pour ça que `corps` reste à 0).
/// **Le seul instrument qui peut les accuser ou les disculper est leur
/// barreau**, en A/B sur un téléphone froid.
///
/// Les allumer un par un, c'est six balades ; et la campagne du soir du 24-09
/// a montré qu'on n'a même pas encore la réponse à la question d'avant : y
/// a-t-il seulement un sujet ? `-sansEffetsSeance` éteint TOUT d'un coup et
/// répond à celle-là en deux balades. Les barreaux individuels restent, pour
/// la passe suivante — « une balade = un moteur ».
enum EffetsSeanceBanc {
    static let sans = ProcessInfo.processInfo.arguments
        .contains("-sansEffetsSeance")
}

enum RecBanc {
    static let sans = EffetsSeanceBanc.sans
        || ProcessInfo.processInfo.arguments.contains("-sansRec")
}

// MARK: - Le témoin

struct PointSeance: View {
    /// Une séance tourne, et le lecteur n'est pas déjà à l'écran.
    let visible: Bool
    /// La barre d'onglets est sous nos pieds : il faut couvrir le coureur.
    /// Ailleurs, aucun disque noir — il se verrait sur un écran qui n'est
    /// pas noir.
    let surBarre: Bool
    /// Le tap ouvre le lecteur. ⚠️ C'est LUI qui prend le doigt désormais,
    /// y compris sur la barre : hors barre il n'y a aucun onglet dessous
    /// pour répondre, et deux comportements pour un même point seraient
    /// deux bugs à venir.
    let ouvrir: () -> Void

    /// Le disque blanc. ⚠️ 14 pt et pas 9 (24-09 : « plus gros le bouton
    /// REC, même taille que les autres »). Un glyphe d'onglet fait ~20 pt de
    /// large mais il est CREUX (un trait) ; un disque PLEIN de la même cote
    /// pèserait deux fois plus lourd à l'œil. À 14 pt plein, entouré de son
    /// néon et de ses anneaux, la marque occupe la même place que la maison
    /// et le profil — c'est la masse visuelle qu'on égalise, pas le nombre.
    /// ⚠️ MESURÉ, PAS ESTIMÉ (capture du simulateur, seuil de luminance
    /// 110) : le glyphe de la maison fait 24,7 × 15,7 pt ; le disque
    /// blanc en fait 14 — la même masse — et ce sont ses anneaux et son
    /// néon qui débordent jusqu'à 32 × 20. « Plus gros », sans écraser
    /// ses voisines.
    private static let cote: CGFloat = 14
    /// Le centre du point, au-dessus du BAS DE L'ÉCRAN (mesuré, cf. l'entête).
    private static let hauteur: CGFloat = 40
    /// La zone qui prend le doigt. En dessous de 44 pt, c'est une cible qu'on
    /// rate — et le point fait 9 pt.
    private static let cible: CGFloat = 44

    @State private var respire = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var actif: Bool { visible && !RecBanc.sans }
    private var anime: Bool { respire && !reduceMotion }

    var body: some View {
        Group {
            if actif {
                Button(action: ouvrir) {
                    ZStack {
                        // ⚠️ LE DISQUE QUI COUVRE LE COUREUR, seulement sur
                        // la barre. La barre est noire : un disque noir un
                        // peu plus large suffit, sans bord.
                        if surBarre {
                            Circle().fill(.black)
                                .frame(width: 42, height: 42)
                        }
                        NeonBraise(anime: anime, cote: Self.cote)
                        Pulsar(anime: anime, cote: Self.cote)
                        PaillettesDuPoint(anime: anime)
                        // LE POINT. Blanc pur, jamais gris : la brillance
                        // vient de la blancheur.
                        // ⚠️ IL BAT PLUS FRANCHEMENT (24-09 : « animation
                        // dix fois plus poussée »). L'opacité descend plus
                        // bas et l'échelle entre dans la danse : c'est
                        // l'ÉCART qui se voit, jamais le niveau moyen.
                        Circle()
                            .fill(.white)
                            .frame(width: Self.cote, height: Self.cote)
                            .opacity(anime ? 1.0 : 0.55)
                            .scaleEffect(anime ? 1.10 : 0.88)
                            .animation(anime
                                ? .easeInOut(duration: 1.15).repeatForever(autoreverses: true)
                                : .easeOut(duration: 0.2), value: anime)
                    }
                    .frame(width: Self.cible, height: Self.cible)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L("Reprendre la séance", "Back to your session")))
                .padding(.bottom, Self.hauteur - Self.cible / 2)
                .transition(.opacity)
            }
        }
        // ⚠️ IL SE POSE PAR RAPPORT AU BAS DE L'ÉCRAN, PAS À SON CONTENEUR.
        // C'est l'erreur du 23-09 : la cote est mesurée sur la dalle, elle
        // ne vaut donc que si le bas d'ici EST le bas de l'écran. On prend
        // tout l'espace, hors zone sûre, et on s'aligne en bas.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea()
        // Hors séance, ce plein écran ne doit rien intercepter.
        .allowsHitTesting(actif)
        .animation(.easeInOut(duration: 0.35), value: actif)
        // ⚠️ RÉ-ARMÉ DANS LA FEUILLE — un `repeatForever` posé par un parent
        // se fait avaler dès que ce parent est ré-évalué (piège payé sur
        // `PageCard.swift`), et la respiration s'arrêterait sans rien dire.
        // `task(id:)` l'éteint aussi dès que la séance se ferme.
        .task(id: actif) { respire = actif }
    }
}

// MARK: - Le pulsar

/// Deux anneaux qui naissent SUR le point et s'en éloignent. Le second part à
/// mi-course : on voit toujours une onde, jamais un battement à vide.
///
/// ⚠️ UN DEMI-POINT D'ÉPAISSEUR — un pixel et demi sur sa dalle. Un anneau
/// épais serait un rond de néon ; c'est la finesse qui fait la lumière.
private struct Pulsar: View {
    let anime: Bool
    let cote: CGFloat

    /// ⚠️ TROIS ANNEAUX, ET PLUS VIFS (24-09). Avec deux, il y avait un
    /// temps mort entre deux ondes ; avec trois décalés d'un tiers, il en
    /// part toujours une. L'épaisseur, elle, NE BOUGE PAS : un demi-point.
    /// « La brillance vient de la blancheur, jamais de l'épaisseur. »
    private static let periode: Double = 1.9

    var body: some View {
        ZStack {
            anneau(0)
            anneau(Self.periode / 3)
            anneau(Self.periode * 2 / 3)
        }
    }

    private func anneau(_ retard: Double) -> some View {
        Circle()
            .strokeBorder(.white, lineWidth: 0.5)
            .frame(width: cote, height: cote)
            .scaleEffect(anime ? 2.6 : 1.0)
            .opacity(anime ? 0.0 : 0.85)
            .animation(anime
                ? .easeOut(duration: Self.periode)
                    .repeatForever(autoreverses: false).delay(retard)
                : .linear(duration: 0), value: anime)
    }
}

// MARK: - Les paillettes

/// Cinq grains d'un point autour du témoin. ⚠️ CHACUN SA PÉRIODE, et aucune
/// n'est multiple d'une autre : cinq grains sur la même horloge, c'est une
/// guirlande — elle l'a refusé pour les carrés de zones, ça vaut ici aussi.
private struct PaillettesDuPoint: View {
    let anime: Bool

    /// angle (degrés), rayon (pt), côté (pt), période (s), creux
    /// ⚠️ SEPT, ET AUCUNE PÉRIODE MULTIPLE D'UNE AUTRE — sinon elles
    /// finissent par clignoter ensemble et c'est une guirlande.
    private static let grains: [(Double, CGFloat, CGFloat, Double, Double)] = [
        (-58,  16.0, 1.6, 1.3, 0.04),
        ( 24,  19.5, 1.1, 1.7, 0.02),
        (112,  15.0, 1.4, 2.1, 0.06),
        (196,  21.0, 1.1, 2.3, 0.02),
        (268,  17.5, 1.5, 2.9, 0.05),
        (150,  22.5, 1.0, 3.1, 0.03),
        (330,  14.0, 1.2, 3.7, 0.04),
    ]

    var body: some View {
        ZStack {
            ForEach(Array(Self.grains.enumerated()), id: \.offset) { _, g in
                let (a, r, c, p, creux) = g
                Circle()
                    .fill(.white)
                    .frame(width: c, height: c)
                    .offset(x: r * cos(a * .pi / 180), y: r * sin(a * .pi / 180))
                    .opacity(anime ? 0.98 : creux)
                    .animation(anime
                        ? .easeInOut(duration: p).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.2), value: anime)
            }
        }
    }
}


// MARK: - Le néon de braise

/// « Un mini néon orange rouge blanc derrière » (Kathryn, 24-09.)
///
/// Un foyer minuscule DERRIÈRE le point : blanc chaud au cœur, orange,
/// puis le rouge de braise qui meurt — et plus rien. Ce sont ses trois
/// couleurs, dans cet ordre, et il n'y en a pas d'autres.
///
/// ⚠️ EN FRACTIONS, jamais en points. Un dégradé dont le rayon dépasse son
/// cadre est TRANCHÉ net au bord, et une lumière coupée net est un
/// rectangle — c'est le défaut du calque orange du 24-09, payé le matin
/// même. `endRadiusFraction: 0.5` garantit qu'il s'éteint avant son bord,
/// quelle que soit la taille.
///
/// ⚠️ DEUX VALEURS ANIMÉES, aucun redessin. Et il respire sur 1,9 s quand
/// le point bat sur 1,15 : les deux ne se rattrapent jamais.
private struct NeonBraise: View {
    let anime: Bool
    let cote: CGFloat

    var body: some View {
        EllipticalGradient(
            // ⚠️ SATURÉ ET SERRÉ, SINON C'EST DU MARRON. Des couleurs
            // chaudes à mi-opacité étalées sur du noir donnent une fumée
            // brune — son mot de rejet, dit le 06-09 : « pas de braises
            // marrons !! ». Ce qui fait un NÉON, c'est l'inverse : très
            // opaque, et sur un petit rayon. La couleur tient alors debout.
            stops: [
                .init(color: .white.opacity(0.72), location: 0),
                .init(color: Color(red: 1.00, green: 0.50, blue: 0.13)
                    .opacity(0.72), location: 0.24),
                .init(color: Color(red: 0.92, green: 0.10, blue: 0.02)
                    .opacity(0.42), location: 0.46),
                .init(color: .clear, location: 1)
            ],
            center: .center,
            startRadiusFraction: 0, endRadiusFraction: 0.5)
            .frame(width: cote * 2.7, height: cote * 2.7)
            .opacity(anime ? 1.0 : 0.30)
            .scaleEffect(anime ? 1.14 : 0.84)
            .animation(anime
                ? .easeInOut(duration: 1.9).repeatForever(autoreverses: true)
                : .easeOut(duration: 0.2), value: anime)
    }
}
