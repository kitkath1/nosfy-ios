import SwiftUI

// MARK: - LE TOASTER D'UN RÉGLAGE (30-09)
//
// Kathryn, 30-09 : « il faut un toaster de confirmation ou chargement quand on
// choisit soit le changement de langue, soit d'affichage ». Il passe par LA
// file de la maison (`FileAnnonces`) et sa peau noire qui s'ouvre depuis l'île
// — la vraie notif Apple qu'elle a demandée pour tous les toasters. Une robe de
// plus, rien d'autre.
//
// UN SEUL toaster par geste : il naît « en cours » (le serveur n'a pas encore
// répondu), puis la MÊME peau passe à « fait » ou « en attente » — la file le
// remplace sur place (`FileAnnonces.poserReglage`), sans se refermer ni se
// rouvrir.

/// Ce que dit la dalle : le réglage, sa nouvelle valeur, et où en est l'écriture.
struct ReglageAnnonce: Equatable {
    enum Etat: Equatable {
        /// Le serveur n'a pas encore répondu.
        case enCours
        /// Enregistré sur le compte.
        case fait
        /// Pas de réseau : gardé sur l'iPhone, renvoyé au prochain passage.
        case enAttente
        /// Refusé : rien n'a changé (la langue revient à l'ancienne).
        case refuse
    }
    /// LA CLÉ du réglage (« langue », « depart ») : deux dalles de même clé
    /// sont le même réglage, la seconde remplace la première. ⚠️ Pas le
    /// titre : la langue change le titre lui-même (« Langue » → « Language »).
    let cle: String
    /// « Langue », « Départ de série » — dans la langue de l'app.
    let titre: String
    let valeur: String
    var etat: Etat
}

/// La robe, dans la peau de l'île : un glyphe d'état, le réglage en capitales,
/// sa valeur en grand. Trois mots, jamais plus.
struct ToasterReglage: View {
    let reglage: ReglageAnnonce

    private var sousTitre: String {
        switch reglage.etat {
        case .enCours: return L("Enregistrement…", "Saving…")
        case .fait: return L("Enregistré", "Saved")
        case .enAttente: return L("Hors ligne · renvoi plus tard", "Offline · will retry")
        case .refuse: return L("Pas de réseau · inchangé", "No connection · unchanged")
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            GlypheReglage(etat: reglage.etat)
            VStack(alignment: .leading, spacing: 3) {
                Text(reglage.titre.uppercased())
                    .font(.inter(11, .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Color.white.opacity(0.42))
                Text(reglage.valeur)
                    .font(.inter(22, .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(LinearGradient(colors: [.white, Color(white: 0.66)],
                                                    startPoint: .top, endPoint: .bottom))
                // Changé NET, sans fondu : le film du 30-09 montrait
                // « Saved » et « Enregistrement… » l'un sur l'autre pendant
                // le fondu (la langue change en même temps que l'état). Le
                // glyphe porte déjà l'animation du passage.
                Text(sousTitre)
                    .font(.inter(13, .medium))
                    .foregroundStyle(Color.white.opacity(0.46))
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, NotifGeo.margeH + NotifGeo.pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Le glyphe d'état : un anneau sombre au liseré fin, et dedans l'attente
/// (le sablier natif d'iOS), la coche, ou le point d'exclamation.
private struct GlypheReglage: View {
    let etat: ReglageAnnonce.Etat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
            Circle()
                .strokeBorder(LinearGradient(colors: [Color.white.opacity(0.45),
                                                      Color.white.opacity(0.08)],
                                             startPoint: .top, endPoint: .bottom),
                              lineWidth: 1)
            interieur
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .id(etat)
        }
        .frame(width: 46, height: 46)
        .animation(.spring(response: 0.38, dampingFraction: 0.7), value: etat)
    }

    @ViewBuilder
    private var interieur: some View {
        switch etat {
        case .enCours:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
        case .fait:
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
        case .enAttente, .refuse:
            Image(systemName: "exclamationmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.8))
        }
    }
}
