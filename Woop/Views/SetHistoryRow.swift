import SwiftUI

// MARK: - La ligne d'historique d'une série

/// LA LIGNE DE LA FICHE, née de `StorySetRow` (la story 2) — même gabarit
/// de 58 pt, même lune noire sur son halo, même pièce gelée. Deux choses en
/// plus que la story n'avait pas besoin de savoir : l'état « À VENIR »
/// (la story ne montre que du vécu) et la métrique TEMPS. La story garde
/// sa ligne à elle : deux montages, deux vies — on ne réécrit pas une page
/// commitée pour en habiller une autre.
///
/// À venir : tout baisse d'un ton — les encres s'éteignent, le halo de la
/// lune meurt, et le gain devient une promesse (« À venir ») au lieu d'un
/// chiffre d'or.
struct SetHistoryRow: View {
    let rank: Int
    let reps: Int
    let kilos: Double
    /// Les secondes affichées : le temps sous tension pour une série faite,
    /// le repos prévu pour une série à venir.
    let seconds: Int
    let done: Bool
    var coins: Int = CoffreFortPurse.perSeries

    var body: some View {
        HStack(spacing: 12) {
            moon

            Text("Série \(rank)")
                .font(.inter(15, .medium))
                .foregroundStyle(Color.white.opacity(done ? 0.94 : 0.55))
                .lineLimit(1)
                .fixedSize()

            Spacer(minLength: 6)

            // fixedSize : les métriques ne se REPLIENT jamais — à
            // l'étroit, c'est le titre qui cède (payé : les valeurs
            // passaient à la ligne dans la vraie fiche).
            HStack(spacing: 8) {
                metric("\(reps)", "reps")
                sep
                metric(kiloText, "kg")
                sep
                metric("\(seconds)", "s")
            }
            .fixedSize()
            .layoutPriority(1)

            Spacer(minLength: 6)

            gain
                .fixedSize()
                .layoutPriority(1)
        }
        .padding(.leading, 10)
        .padding(.trailing, 12)
        // 58 → 66 : 4 pt d'air de plus en haut et en bas (15-08) — les
        // petites cartes noires respirent dans la carte dépliée.
        .frame(height: 66)
        // LE GALET DE VERRE FUMÉ (15-08) : un noir profond mais
        // TRANSLUCIDE — la lumière chaude de l'écrin passe dessous et ne
        // se lit qu'en nuances, le texte blanc reste franc. Par-dessus,
        // le couvercle de verre du profil : ce sont ses arêtes qui font
        // lire « galet » et non « rectangle sombre ».
        // CHAQUE LIGNE EST UN GALET D'OBSIDIENNE (15-08) : la même
        // matière que la carte qui les contient — verre fumé noir, huile
        // d'or le long des arêtes, biseau. La ligne FAITE allume sa lampe
        // (`lit`), celle qui attend la garde basse : c'est l'ÉCLAIRAGE
        // qui dit l'état, plus une opacité de texte.
        // (Ni `glassEffect` ni contour dessiné : le premier dédoublait
        // les lignes en fantômes — le matériau réfracte sa voisine — et
        // le second doublait l'arête que le shader trace déjà.)
        // SANS FOND (verdict du 15-08, avec la référence sous les yeux) :
        // la liste est posée DIRECTEMENT sur le verre de la carte — ni
        // capsule, ni arête. C'est le verre qui porte tout ; une
        // sous-carte par ligne cassait la lecture « une seule dalle ».
        .accessibilityElement(children: .combine)
        .accessibilityLabel(done
            ? "Série \(rank) faite : \(reps) répétitions, \(kiloText) kilos"
            : "Série \(rank) à venir")
    }

    /// La lune noire de la maison — le halo ne brûle que pour le vécu.
    /// Le souffle du petit néon — une seule animation par ligne, lancée à
    /// l'apparition et décalée par le rang.
    @State private var neon = false

    private var moon: some View {
        ZStack {
            // 16-08 : « les petites lunes doivent être blanches, dégradé
            // subtil ». Le halo orange de la série faite devient une lueur
            // NEUTRE — sinon la lune reste chaude quoi qu'on fasse au trait.
            if done {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.white.opacity(0.10), .clear],
                        center: .center, startRadius: 5, endRadius: 15))
            }
            MoonShape()
                .fill(LinearGradient(
                    // Le remplissage s'éclaircit un peu lui aussi : à 0,022
                    // la lune était un trou noir dans lequel le liseré se
                    // noyait.
                    colors: [Color(red: 0.200, green: 0.196, blue: 0.190),
                             Color(red: 0.062, green: 0.060, blue: 0.058)],
                    startPoint: .top, endPoint: .bottom))
                .overlay {
                    // Le contour passe de l'ORANGE (1,0 · 0,56 · 0,18) au
                    // BLANC, avec un dégradé haut → bas d'environ 1,5× :
                    // assez pour donner du relief, pas assez pour faire
                    // motif. C'est le « dégradé subtil » demandé.
                    // 16-08 : « je ne vois pas le blanc des petites lunes,
                    // c'est noir ». Mesuré dans la carte dépliée : le
                    // maximum de la zone plafonnait à 0,10-0,13 — un blanc
                    // à 0,26 d'opacité sur un trait de 0,6 pt, posé sur un
                    // remplissage à 0,022, ne survit pas à l'antialiasing.
                    // Le trait passe à 1,0 pt et l'encre monte : cible
                    // 0,45 au minimum pour une série à venir.
                    MoonShape()
                        .stroke(LinearGradient(
                            // 16-08, second tour : « plus blanc, dégradé ».
                            // Le haut monte au blanc franc et le bas
                            // descend plus bas : le rapport haut/bas passe
                            // de 1,6× à 2,6×, donc le dégradé se LIT au
                            // lieu de se deviner.
                            colors: [Color.white.opacity(done ? 1.00 : 0.92),
                                     Color.white.opacity(done ? 0.52 : 0.35)],
                            startPoint: .top, endPoint: .bottom),
                            lineWidth: 1.0)
                }
                .overlay {
                    // LE PETIT NÉON (16-08) : « une légère animation comme
                    // un petit néon magique de blanc très très fin ». Un
                    // second trait, deux fois plus fin que le premier
                    // (0,3 pt), dont la brillance respire — et DÉCALÉE
                    // d'une lune à l'autre (0,31 s par rang) : cinq lunes
                    // qui pulsent en chœur feraient un clignotant, cinq
                    // qui se répondent font une matière vivante.
                    // Une seule animation par ligne, pas de TimelineView :
                    // la cadence de la fiche est déjà le sujet du moment.
                    MoonShape()
                        .stroke(LinearGradient(
                            colors: [Color.white.opacity(neon ? 0.85 : 0.22),
                                     Color.white.opacity(neon ? 0.32 : 0.07)],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading),
                            lineWidth: 0.5)
                        .blur(radius: 0.5)
                }
                .frame(width: 15, height: 15)
        }
        .frame(width: 32, height: 32)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6)
                .repeatForever(autoreverses: true)
                .delay(Double(rank) * 0.31)) { neon = true }
        }
    }

    /// Le gain — la pièce GELÉE de la maison (draggable: false obligatoire,
    /// une TimelineView par pièce ferait une horloge par ligne). À venir :
    /// pas de pièce, une promesse d'encre.
    @ViewBuilder
    private var gain: some View {
        if done {
            HStack(spacing: 5) {
                Text("+\(coins)")
                    .font(.inter(14, .semibold))
                    .foregroundStyle(Color.woopGold.opacity(0.92))
                    .monospacedDigit()
                MoonCoinView(coinR: 13, draggable: false, yawOverride: 0.34,
                             idleLife: 0, fps: 6, reveal: 0.34, matte: 1)
                    // Le double cadre : l'extérieur porte le bloom du
                    // shader, l'intérieur décide de l'encombrement.
                    .frame(width: 13 * MoonCoinView.hostScale,
                           height: 13 * MoonCoinView.hostScale)
                    .frame(width: 28, height: 28)
            }
        } else {
            Text("À venir")
                .font(.inter(12))
                .foregroundStyle(Color.white.opacity(0.35))
                .frame(height: 28)
        }
    }

    private var sep: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(width: 1, height: 11)
    }

    private func metric(_ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(value)
                .font(.inter(14, .medium))
                .foregroundStyle(Color.white.opacity(done ? 0.80 : 0.45))
                .monospacedDigit()
            Text(unit)
                .font(.inter(10.5))
                .foregroundStyle(Color.white.opacity(done ? 0.38 : 0.22))
        }
    }

    private var kiloText: String {
        kilos == kilos.rounded()
            ? String(Int(kilos)) : String(format: "%.1f", kilos)
    }
}
