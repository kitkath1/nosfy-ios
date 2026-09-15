import SwiftUI

// MARK: - Le banc des notifications (`-notifLab`)

/// LE BANC — les variants EMPILÉS L'UN SOUS L'AUTRE sur du noir vrai
/// (verdict de Kathryn, 28-08 : « mets-les les uns sous les autres »).
///
/// Pourquoi il existe : les deux robes ne se jugent QUE l'une contre
/// l'autre, sur UNE capture, sans changer d'écran. Et il ne veut RIEN
/// dessous — ni splash, ni porte, ni fiche exo (dont le halo orange
/// traversait le scrim et polluait déjà le jugement de la card reward,
/// constaté sur capture le 27-08).
///
/// Les prises :
/// - un tap **rejoue** les deux entrées (le démontage puis la renaissance —
///   jamais une coupe sèche) ;
/// - `-notifFige` : les cards naissent posées (captures immobiles) ;
/// - `-notifT <s>` : l'horloge du projecteur et du tour de pièce, clouée ;
/// - `-notifNu` : pas de bandeau (captures propres).
///
/// ⚠️ `--terminate-running-process` est obligatoire au `simctl launch` :
/// une app déjà vivante revient au premier plan AVEC SES ANCIENS ARGUMENTS.
struct NotifLab: View {
    /// L'entrée est posée : la barre s'est remplie, le chiffre est monté.
    @State private var pose = NotifBanc.fige
    /// L'identité de la pile : elle change à chaque relance, sinon SwiftUI
    /// réutilise les vues et l'entrée ne rejoue pas.
    @State private var tour = 0
    /// L'horloge du projecteur — posée UNE fois au montage. Une `Date` prise
    /// dans le corps renaîtrait à chaque image et gèlerait le balayage.
    @State private var naissance = Date()

    var body: some View {
        ZStack {
            // La nuit vraie — les dalles se jugent sur ÇA, pas sur une page.
            Color.black.ignoresSafeArea()
            pile
            if !NotifBanc.nu { bandeau }
            if NotifBanc.fps { sonde }
        }
        .contentShape(Rectangle())
        .onTapGesture { rejouer() }
        .statusBarHidden()
        .onAppear { poser() }
    }

    // ── LA PILE

    private var pile: some View {
        VStack(spacing: 20) {
            if montre(1) {
                NotifJauge(pose: pose, naissance: naissance)
                    .modifier(EntreeNotif(pose: pose))
            }
            if montre(4) {
                // ROBE 4 — le booster (sachet orange + jauge « connectée »
                // gris → blanc), surtout pour la home. `-notifSeule 4`.
                NotifJauge(sousTitre: "VAULT PROGRESS", libelle: "BOOSTER",
                           gain: 1, fraction: 0.9,
                           pose: pose, naissance: naissance, robe: .booster)
                    .modifier(EntreeNotif(pose: pose))
            }
            if montre(2) {
                NotifGrosTexte(pose: pose, naissance: naissance)
                    .modifier(EntreeNotif(pose: pose))
            }
            if montre(3) {
                NotifChasse(pose: pose, naissance: naissance)
                    .modifier(EntreeNotif(pose: pose))
            }
        }
        .id(tour)
    }

    /// Une robe est à l'écran si le banc entier est demandé (`seule == 0`) ou
    /// si c'est celle qu'on isole (`-notifSeule <n>` : 1 jauge · 2 gros texte ·
    /// 3 châsse · 4 booster).
    private func montre(_ n: Int) -> Bool {
        NotifBanc.seule == 0 || NotifBanc.seule == n
    }

    /// LA SONDE — `-fps`. Le seul juge fiable du « ça lag » : un
    /// `CADisplayLink` compte les battements RÉELLEMENT servis. Compter les
    /// images différentes d'un enregistrement ne mesure PAS la cadence (un
    /// fond lent produit peu d'images différentes en tournant à 60).
    ///
    /// ⚠️ Deux régimes, et ils ne disent pas la même chose : le banc entier
    /// est le PIRE cas (deux cards, deux vidéos, tout vivant en même temps)
    /// — c'est le cas du réglage, pas celui de l'app. `-notifSeule 1|2`
    /// donne le cas VRAI : dans l'app une seule notification est à l'écran.
    private var sonde: some View {
        SondeCadence(quoi: NotifBanc.seule == 0
                     ? "notif-banc" : "notif-seule-\(NotifBanc.seule)")
            .frame(width: 0, height: 0)
    }

    private var bandeau: some View {
        Text("tap · rejoue les deux entrées")
            .font(.inter(11))
            .foregroundStyle(Color.inkMuted)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 26)
            .allowsHitTesting(false)
    }

    // ── LE FILM

    private func poser() {
        guard !NotifBanc.fige else { return }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.85)
            .delay(0.35)) {
            pose = true
        }
    }

    /// Rejouer, c'est la vraie SORTIE suivie de la vraie ENTRÉE — jamais
    /// une coupe sèche : c'est le raccord qu'on juge autant que la pose.
    private func rejouer() {
        guard !NotifBanc.fige else { return }
        withAnimation(.easeIn(duration: 0.22)) { pose = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            tour += 1
            naissance = Date()
            poser()
        }
    }
}

/// L'ARRIVÉE — la dalle descend et s'allume.
///
/// ⚠️ **UN `offset` ET UNE `opacity`, JAMAIS UN REDIMENSIONNEMENT.** La
/// dalle vit à taille constante dès la première image : une surface qui
/// change de taille par image re-layoute tout ce qu'elle contient, et un
/// verre (si on en remettait un jour) y perdrait son flou définitivement.
struct EntreeNotif: ViewModifier {
    let pose: Bool

    func body(content: Content) -> some View {
        content
            .offset(y: pose ? 0 : -26)
            .opacity(pose ? 1 : 0)
    }
}
