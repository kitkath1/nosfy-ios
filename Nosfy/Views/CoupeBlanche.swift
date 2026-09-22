import SwiftUI

// MARK: - LA COUPE BLANCHE (22-09)
//
// « il faut faire une explosion noir blanche » — puis, sur planche :
// « ok le cercle très bien ». Un point blanc s'ouvre au centre, le noir
// monte sous lui, l'écran change DERRIÈRE, puis le disque s'ouvre vers
// l'extérieur en laissant un cheveu de lumière. On ne voit jamais la
// page qu'on quitte.
//
// ⚠️ CE QU'ELLE RÈGLE. Avant elle, chaque changement d'écran du parcours
// de séance laissait voir la page Exercices une fraction de seconde (la
// flamme s'efface, PUIS le lecteur monte : deux mouvements qui ne se
// recouvrent pas). Pendant la coupe, il n'y a plus de « dessous » : le
// changement se fait sous le blanc.
//
// ⚠️ LA LOI DU BALAYAGE EST RESPECTÉE (rappelée quatre fois) : ce n'est
// ni une bande, ni une lame, ni une nappe qui traverse. C'est un disque
// qui s'ouvre depuis le POINT où le doigt vient de taper, avec un bord
// net et un centre. La lumière a une cause.
//
// ⚠️ LA LOI DE LA CHAUFFE : aucune horloge, aucun `TimelineView`, aucun
// `Canvas`, aucun flou. Trois formes et cinq valeurs animables — le
// compositeur fait tout, rien n'est redessiné (« redessiner pour animer
// coûte 3 à 8 fois plus que d'animer »). Elle ne vit que 0,37 s.
//
// ⚠️ LE BLANC NE REMPLIT JAMAIS L'ÉCRAN : le disque plafonne à 0,72 de
// sa boîte, plus étroit qu'un iPhone. Le noir tient les bords. Dans une
// salle sombre, un flash plein écran éblouit — et « la brillance vient
// de la blancheur, jamais de l'épaisseur ».
//
// Son barreau : `-sansCoupe` rend le parcours d'avant (le changement se
// fait tout de suite, sans rien par-dessus). Sans barreau on ne pourrait
// ni l'accuser ni la disculper quand le téléphone chauffe.

enum CoupeBanc {
    static let sans = ProcessInfo.processInfo.arguments.contains("-sansCoupe")
}

/// LE DÉCLENCHEUR. On ne lui demande pas d'animer : on lui donne le
/// geste à faire AU MILIEU, quand le blanc tient l'écran. C'est ce qui
/// garantit que le changement ne se voit pas — l'appelant n'a jamais à
/// deviner un délai.
@MainActor
final class CoupeEtat: ObservableObject {
    static let shared = CoupeEtat()
    private init() {}

    /// Un compteur, pas un booléen : deux coupes qui se suivent doivent
    /// toutes les deux partir (un booléen remis à `true` alors qu'il
    /// l'est déjà ne déclenche aucun `onChange`).
    @Published fileprivate var top: Int = 0
    fileprivate var auMilieu: (() -> Void)?

    /// Le temps que met le blanc à couvrir l'écran. L'appelant n'a pas à
    /// le connaître : il est ici, et la vue le lit.
    static let montee: Double = 0.15
    static let ouverture: Double = 0.22

    func jouer(_ auMilieu: @escaping () -> Void) {
        guard !CoupeBanc.sans else { auMilieu(); return }
        self.auMilieu = auMilieu
        top &+= 1
    }
}

struct CoupeBlanche: View {
    @ObservedObject private var etat = CoupeEtat.shared

    /// LE NOIR qui monte sous le disque : c'est LUI qui cache la page,
    /// pas le blanc. Le blanc n'est que ce qu'on regarde pendant.
    @State private var voile: Double = 0
    /// LE DISQUE — une seule valeur d'échelle et une d'encre.
    @State private var disque: CGFloat = 0.04
    @State private var encreDisque: Double = 0
    /// L'ANNEAU qui le suit dehors : un cheveu de 1,5 pt, jamais un trait
    /// épais (« fake », son mot de rejet).
    @State private var anneau: CGFloat = 0.04
    @State private var encreAnneau: Double = 0

    /// La boîte du disque. À 0,72 il fait 331 pt : plus étroit que les
    /// 393 pt d'un iPhone 15, donc les bords restent noirs.
    private let boite: CGFloat = 460

    var body: some View {
        ZStack {
            Color.black.opacity(voile)
            Circle()
                .fill(.white)
                .frame(width: boite, height: boite)
                .scaleEffect(disque)
                .opacity(encreDisque)
            Circle()
                .stroke(Color.white, lineWidth: 1.5)
                .frame(width: boite, height: boite)
                .scaleEffect(anneau)
                .opacity(encreAnneau)
        }
        .ignoresSafeArea()
        // Elle mange le doigt tant qu'elle tient l'écran : un tap qui
        // passerait au travers atterrirait sur un écran qui n'est déjà
        // plus le bon.
        .allowsHitTesting(voile > 0.02)
        .onChange(of: etat.top) { _, _ in jouer() }
    }

    private func jouer() {
        let milieu = etat.auMilieu
        etat.auMilieu = nil

        // 1 — LE POINT S'OUVRE. Le noir monte avec lui : à la fin de
        // cette phase, la page qu'on quitte n'est plus visible du tout.
        withAnimation(.easeOut(duration: CoupeEtat.montee)) {
            voile = 1
            disque = 0.72
            encreDisque = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + CoupeEtat.montee) {
            // 2 — LE CHANGEMENT, sous le blanc. Sans animation : ce qui
            // bouge ici ne doit surtout pas se voir bouger.
            var tr = Transaction()
            tr.disablesAnimations = true
            withTransaction(tr) { milieu?() }

            // 3 — LE DISQUE S'OUVRE VERS L'EXTÉRIEUR et s'éteint en
            // chemin ; l'anneau le suit dehors. Le voile part avec eux :
            // ce qui apparaît dessous était déjà là.
            anneau = 0.72
            encreAnneau = 0.9
            withAnimation(.easeOut(duration: CoupeEtat.ouverture)) {
                voile = 0
                disque = 2.6
                encreDisque = 0
                anneau = 3.0
                encreAnneau = 0
            }

            DispatchQueue.main.asyncAfter(
                deadline: .now() + CoupeEtat.ouverture + 0.02) {
                disque = 0.04
                anneau = 0.04
            }
        }
    }
}
