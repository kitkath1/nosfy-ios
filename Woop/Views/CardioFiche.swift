import SwiftUI

// MARK: - LA FICHE CARDIO — ce qui s'ajoute à la robe muscu (15-09)
//
// Plan : tools/cardio/PLAN-CARDIO.md (§C le graphe, §E la piscine). La fiche
// (`ExerciseDetailView`) porte les trois robes ; ici vivent les deux vues qui
// n'existent que pour le cardio : le graphe des segments à la place de la
// description, et le compteur de longueurs à la place du galet.

// MARK: Le graphe des segments, à la place de la description

/// « Une fois la session terminée on retrouve à la place de la description
/// le graphe du widget HIIT — exactement le même composant » (verdict
/// 15-09). C'est `PaliersVue`, celle de la chambre, avec son échelle (km/h
/// ou niveaux), sa légende, et une ligne de tête à la grammaire de l'étage
/// 2 de la chambre (« Mardi 15.09 · 6:40 · 6 segments »).
///
/// Il arrive comme la description : dans la même vague que le titre,
/// décalé (`ArriveeDouce`). Aucune horloge : `PaliersVue` n'en a pas.
struct GrapheCardioFiche: View {
    let segments: [SegmentHiit]
    let titre: String
    let echelle: EchellePaliers
    /// LE VIDE (verdict 15-09 : « en courbe en mode empty quand on n'a pas
    /// commencé ») — la silhouette de la chambre, en gris, la loi du vide :
    /// le même dessin, jamais une phrase « rien à afficher ».
    var vide: Bool = false
    let vu: Bool

    var body: some View {
        // ⚠️ 200 pt, pas plus : c'est la place entre le sous-titre et la
        // crête du galet d'aube (mesuré à la capture : à 190 pt de graphe,
        // la légende et le rail passaient SOUS le galet).
        VStack(alignment: .leading, spacing: 8) {
            Text(vide ? "— · 0:00 · 0 segment" : titre)
                .font(.inter(14, .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.55))
                .modifier(ArriveeDouce(vu: vu, retard: 0.48))
            PaliersVue(segments: vide ? silhouette : segments,
                       vide: vide, echelle: echelle)
                .frame(height: 138)
                .modifier(ArriveeDouce(vu: vu, retard: 0.60))
            LegendePaliers(echelle: echelle)
                .modifier(ArriveeDouce(vu: vu, retard: 0.76))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .chambreVide(vide)
    }

    /// La silhouette de la chambre est écrite en km/h (4 → 20). Sur une
    /// autre échelle (les niveaux 1 → 15 de l'escalier), ses 16-18 km/h
    /// dépassaient le plafond : les barres montaient à plein et touchaient
    /// la ligne de tête (vu à la capture du 15-09). On la RAMÈNE dans
    /// l'échelle, même dessin, même respiration — la loi du vide.
    private var silhouette: [SegmentHiit] {
        guard echelle != .tapis else { return PaliersVue.silhouette }
        let de = EchellePaliers.tapis, vers = echelle
        let etendue = max(de.max - de.min, 1)
        return PaliersVue.silhouette.map { s in
            let u = (min(max(s.vitesse, de.min), de.max) - de.min) / etendue
            return SegmentHiit(secondes: s.secondes,
                               vitesse: vers.min + u * (vers.max - vers.min),
                               effort: s.effort)
        }
    }
}

// MARK: Le compteur de longueurs (la piscine)

/// L'état du compteur — UN observable à part : le « + » ne réveille que la
/// pastille, jamais la fiche entière (la loi de la page ré-évaluée).
@MainActor @Observable
final class CompteurLongueurs {
    var longueurs: Int = 0
    var metres: Int = 25
    /// Les bassins proposés.
    static let bassins = [25, 50]
}

/// « Pas de galet pour la piscine : le user saisit à la main le nombre de
/// longueurs sur X mètres, avec un petit plus blanc dégradé » (verdict
/// 15-09). À la place exacte du galet : le NOMBRE en grand, « longueurs ·
/// 25 m · 300 m » dessous, le « + » blanc dégradé à droite, un « − » discret
/// à gauche (une erreur de doigt ne doit pas être définitive), et les deux
/// bassins au-dessus.
///
/// ⚠️ LA MATIÈRE, v1 : un galet d'obsidienne peint (verre fumé noir, arête
/// en dégradé de blanc) — PAS un `glassEffect` : sur la nuit de la page un
/// verre n'a rien à réfracter, il rend un trou (loi du verre à jeun). Le
/// seul verre qui vit sur cette page porte son propre jour (le galet
/// d'aube, `liquidLens`) ; s'il faut sa matière ici, c'est un chantier à
/// part, sur verdict.
struct CompteurLongueursVue: View {
    let compteur: CompteurLongueurs
    var onPlus: () -> Void = {}
    var onMoins: () -> Void = {}
    var onBassin: (Int) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 14) {
            bassins
            HStack(spacing: 18) {
                bouton("minus", corps: 44, encre: 0.45, action: onMoins)
                    .opacity(compteur.longueurs > 0 ? 1 : 0.35)
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    Text("\(compteur.longueurs)")
                        .font(.inter(56, .light))
                        .tracking(-2)
                        .monospacedDigit()
                        .foregroundStyle(TapisScene.encreApple)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.22), value: compteur.longueurs)
                    // Une seule ligne, jamais repliée (mesuré : « 100 m »
                    // passait à la ligne entre les deux boutons).
                    Text(legende)
                        .font(.inter(12, .medium))
                        .tracking(0.4)
                        .foregroundStyle(Color.white.opacity(0.42))
                        .lineLimit(1)
                        .fixedSize()
                }
                .layoutPriority(1)
                Spacer(minLength: 0)
                bouton("plus", corps: 68, encre: 0.95, action: onPlus)
            }
            .padding(.horizontal, 22)
        }
        .padding(.top, 18)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(Color(white: 0.075))
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(LinearGradient(
                            colors: [.white.opacity(0.26), .white.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom), lineWidth: 1)
                }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }

    private var legende: String {
        let n = compteur.longueurs
        let mot = n > 1 ? "longueurs" : "longueur"
        return "\(mot) · \(compteur.metres) m · \(n * compteur.metres) m"
    }

    /// Les deux bassins — deux capsules, la choisie en clair.
    private var bassins: some View {
        HStack(spacing: 8) {
            ForEach(CompteurLongueurs.bassins, id: \.self) { m in
                let choisi = m == compteur.metres
                Text("\(m) m")
                    .font(.inter(12, .semibold))
                    .tracking(0.4)
                    .foregroundStyle(Color.white.opacity(choisi ? 0.92 : 0.40))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(choisi ? 0.14 : 0.04)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(choisi ? 0.22 : 0.08), lineWidth: 0.8))
                    .contentShape(Capsule())
                    // Jamais un `Button` sous un drag d'ancêtre (loi §4).
                    .highPriorityGesture(TapGesture().onEnded { onBassin(m) })
            }
        }
    }

    /// Le « + » (et le « − ») : un disque, une arête en dégradé de blanc, le
    /// glyphe en encre Apple. `encre` règle la présence — le plus est le
    /// héros, le moins se devine.
    private func bouton(_ glyphe: String, corps: CGFloat, encre: Double,
                        action: @escaping () -> Void) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06 * encre + 0.02))
            Circle()
                .strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.85 * encre), .white.opacity(0.18 * encre)],
                    startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
            Image(systemName: glyphe)
                .font(.system(size: corps * 0.40, weight: .medium))
                .foregroundStyle(LinearGradient(
                    colors: [.white.opacity(encre), .white.opacity(0.55 * encre)],
                    startPoint: .top, endPoint: .bottom))
        }
        .frame(width: corps, height: corps)
        .contentShape(Circle())
        .highPriorityGesture(TapGesture().onEnded { action() })
        .accessibilityLabel(glyphe == "plus" ? "Une longueur de plus" : "Une longueur de moins")
    }
}
