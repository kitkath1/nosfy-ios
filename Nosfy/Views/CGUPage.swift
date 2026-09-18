import SwiftUI

// ════════════════════════════════════════════════════════════════════════
// LES CONDITIONS GÉNÉRALES D'UTILISATION — la page des Réglages (18-09).
//
// Le texte vit ICI, article par article, dans les deux langues (`L`), pour
// que Kathryn le relise et le corrige ligne à ligne sans toucher à la vue.
// Chaque article dit ce que l'app FAIT vraiment, tel que le site l'atteste :
// Sign in with Apple seul, le profil (prénom, langue, but, exercices
// choisis), les séances et leurs séries, le carnet de pièces, les sachets et
// les cartes, les bilans écrits par une IA au serveur ; rien d'autre n'est
// lu sur le téléphone (aucune clé d'usage Santé, position, photos ni
// contacts dans le projet ; un seul entitlement : Sign in with Apple).
// La page est un texte immobile : aucune horloge, aucun verre, aucun flou.
// ════════════════════════════════════════════════════════════════════════

/// Un article des conditions : son titre et son corps, déjà dans la langue
/// de la personne.
struct CGUArticle: Identifiable {
    let id: Int
    let titre: String
    let corps: String
}

enum CGUTexte {
    /// La date de la version affichée : c'est elle qui fait foi (article 13).
    static var version: String {
        L("Version du 18 septembre 2026", "Version dated 18 September 2026")
    }

    static var intro: String {
        L("""
        Nosfy est une application d'entraînement : elle enregistre tes séances de \
        musculation, de cardio et de natation, et récompense ta régularité par des \
        pièces lune, des sachets et des cartes. En créant un compte ou en utilisant \
        l'app, tu acceptes ces conditions. Elles sont écrites pour être lues en entier.
        """, """
        Nosfy is a training app: it records your strength, cardio and swimming \
        sessions, and rewards your consistency with moon coins, packs and cards. By \
        creating an account or using the app, you accept these terms. They are \
        written to be read in full.
        """)
    }

    static var articles: [CGUArticle] {
        let textes: [(String, String)] = [
            (L("L'éditeur et le contact",
               "The publisher and how to reach us"),
             L("""
             Nosfy est éditée en France par la personne responsable de l'app \
             (ci-après « nous »). L'identité complète de l'éditeur et l'adresse de \
             contact figurent sur la fiche App Store de Nosfy ; c'est là que tu nous \
             écris pour toute question sur ces conditions ou sur tes données.
             """, """
             Nosfy is published in France by the person responsible for the app \
             (“we”). The publisher's full identity and contact address are shown on \
             Nosfy's App Store page; that is where you write to us with any question \
             about these terms or your data.
             """)),

            (L("Le compte",
               "Your account"),
             L("""
             Un compte est nécessaire pour utiliser Nosfy. Il se crée uniquement avec \
             Sign in with Apple : nous ne stockons aucun mot de passe. Apple nous \
             transmet un identifiant stable et, si tu as choisi de la partager, ton \
             adresse e-mail (éventuellement une adresse relais). Tu dois avoir au \
             moins 15 ans pour créer un compte. Ton compte est personnel ; tu es \
             responsable de ce qui est fait depuis ton appareil.
             """, """
             An account is required to use Nosfy. It is created only with Sign in \
             with Apple: we store no password. Apple passes us a stable identifier \
             and, if you chose to share it, your email address (possibly a relay \
             address). You must be at least 15 years old to create an account. Your \
             account is personal; you are responsible for what is done from your \
             device.
             """)),

            (L("Ce que Nosfy enregistre",
               "What Nosfy records"),
             L("""
             Pour fonctionner, Nosfy enregistre : le prénom et la langue que tu as \
             donnés à l'arrivée, la raison pour laquelle tu t'entraînes si tu l'as \
             écrite, les exercices que tu as choisis ; tes séances (exercices, \
             séries, charges, répétitions, durées, phases de cardio, longueurs de \
             piscine) ; ta progression (pièces lune, sachets, cartes, chapitres de la \
             Route) et les bilans écrits pour toi. Ces données vivent dans ton \
             téléphone et sur nos serveurs, hébergés par Supabase, pour que ton compte \
             te revienne intact quand tu te reconnectes. Nosfy ne lit ni tes \
             contacts, ni ta position, ni tes photos, ni les données de l'app Santé.
             """, """
             To work, Nosfy records: the first name and language you gave when you \
             arrived, the reason you train if you wrote one, the exercises you chose; \
             your sessions (exercises, sets, loads, reps, durations, cardio phases, \
             pool lengths); your progress (moon coins, packs, cards, chapters of the \
             Route) and the summaries written for you. This data lives on your phone \
             and on our servers, hosted by Supabase, so that your account comes back \
             intact when you sign in again. Nosfy does not read your contacts, your \
             location, your photos or your Health data.
             """)),

            (L("Les textes écrits par une IA",
               "Texts written by an AI"),
             L("""
             Le bilan de ta semaine ou de ton mois est écrit par un modèle \
             d'intelligence artificielle (OpenAI ou Anthropic) à partir d'un résumé \
             chiffré de tes séances (nombre, durées, exercices), dans ta langue, sans \
             ton prénom ni ton e-mail. Ce texte est gardé sur ton compte pour ne pas \
             être réécrit à chaque ouverture. D'autres contenus de l'app (phrases de \
             la Home, illustrations des cartes) ont été générés par IA à l'avance, \
             sans aucune donnée personnelle.
             """, """
             Your weekly or monthly summary is written by an artificial intelligence \
             model (OpenAI or Anthropic) from a numeric digest of your sessions \
             (count, durations, exercises), in your language, without your first name \
             or email. That text is kept on your account so it is not rewritten every \
             time you open the app. Other content in the app (Home phrases, card \
             illustrations) was generated by AI in advance, with no personal data.
             """)),

            (L("Les pièces lune, les sachets et les cartes",
               "Moon coins, packs and cards"),
             L("""
             Les pièces lune, les sachets et les cartes sont des éléments de jeu. Ils \
             n'ont aucune valeur monétaire et ne peuvent être ni achetés, ni vendus, \
             ni échangés, ni transférés vers un autre compte, ni remboursés. Nosfy ne \
             propose aucun achat intégré. Les règles qui les attribuent (gains par \
             séance, raretés, garanties) peuvent évoluer. Ce qui a été gagné reste \
             sur ton compte ; nous ne le retirons qu'en cas de fraude ou d'erreur \
             manifeste.
             """, """
             Moon coins, packs and cards are game items. They have no monetary value \
             and cannot be bought, sold, exchanged, transferred to another account or \
             refunded. Nosfy offers no in-app purchases. The rules that grant them \
             (earnings per session, rarities, guarantees) may change. What has been \
             earned stays on your account; we only remove it in case of fraud or \
             obvious error.
             """)),

            (L("Une app jeune",
               "A young app"),
             L("""
             Nosfy est une jeune application, distribuée d'abord en version de test \
             (TestFlight). Elle peut contenir des défauts et évoluer d'une version à \
             l'autre ; certaines fonctions peuvent être modifiées ou retirées. Nous \
             faisons le nécessaire pour ne pas perdre tes séances, sans pouvoir le \
             garantir en toutes circonstances. Tes retours servent à la corriger.
             """, """
             Nosfy is a young app, first distributed as a test version (TestFlight). \
             It may contain defects and change from one version to the next; some \
             features may be modified or removed. We do what is needed not to lose \
             your sessions, without being able to guarantee it in every situation. \
             Your feedback helps us fix it.
             """)),

            (L("La santé et la sécurité",
               "Health and safety"),
             L("""
             Nosfy n'est pas un dispositif médical et ne donne aucun avis médical. \
             Les séances, les charges et les rythmes que tu enregistres sont les \
             tiens : tu t'entraînes sous ta propre responsabilité, dans les limites \
             de ta condition physique, et tu consultes un professionnel de santé en \
             cas de doute.
             """, """
             Nosfy is not a medical device and gives no medical advice. The sessions, \
             loads and paces you record are your own: you train under your own \
             responsibility, within the limits of your physical condition, and you \
             consult a health professional if in doubt.
             """)),

            (L("Ce qui appartient à qui",
               "Who owns what"),
             L("""
             Tes séances et tes réglages t'appartiennent. L'app, ses textes, ses \
             illustrations, ses cartes, ses vidéos, ses animations et son code sont \
             notre propriété ou celle de nos ayants droit. Tu reçois un droit \
             personnel, gratuit et non exclusif de les utiliser dans Nosfy ; tu ne \
             peux pas les copier, les extraire, les revendre ni les modifier hors de \
             l'app.
             """, """
             Your sessions and settings belong to you. The app, its texts, \
             illustrations, cards, videos, animations and code are our property or \
             that of our rights holders. You receive a personal, free and \
             non-exclusive right to use them within Nosfy; you may not copy, extract, \
             resell or modify them outside the app.
             """)),

            (L("Déconnexion et suppression",
               "Signing out and deleting"),
             L("""
             « Se déconnecter » efface tes données de ce téléphone ; ton compte et \
             son historique restent sur nos serveurs et te reviennent à la \
             reconnexion. « Supprimer mon compte » efface immédiatement et \
             définitivement ton compte, tes séances, tes pièces, tes sachets et tes \
             cartes de nos serveurs, révoque ton lien avec Apple et vide ce téléphone. \
             Rien n'est récupérable ensuite.
             """, """
             “Sign out” erases your data from this phone; your account and its \
             history stay on our servers and come back when you sign in again. \
             “Delete my account” immediately and permanently erases your account, \
             sessions, coins, packs and cards from our servers, revokes your link \
             with Apple and clears this phone. Nothing can be recovered afterwards.
             """)),

            (L("Tes droits sur tes données",
               "Your rights over your data"),
             L("""
             Tu peux à tout moment relire tes séances dans l'app et supprimer ton \
             compte. Tu disposes aussi des droits d'accès, de rectification, \
             d'effacement, de portabilité et d'opposition prévus par le règlement \
             général sur la protection des données (RGPD) ; pour les exercer \
             autrement que par l'app, écris-nous à l'adresse de contact de la fiche \
             App Store. Tes données sont conservées tant que ton compte existe et \
             supprimées avec lui. Nous ne les vendons pas, nous n'affichons aucune \
             publicité et nous n'utilisons aucun traqueur publicitaire. Nos \
             sous-traitants : Apple (identification), Supabase (hébergement et base \
             de données), OpenAI et Anthropic (rédaction des bilans).
             """, """
             You can re-read your sessions in the app and delete your account at any \
             time. You also have the rights of access, rectification, erasure, \
             portability and objection provided by the General Data Protection \
             Regulation (GDPR); to exercise them other than through the app, write \
             to us at the contact address on the App Store page. Your data is kept as \
             long as your account exists and deleted with it. We do not sell it, we \
             show no advertising and we use no advertising tracker. Our processors: \
             Apple (sign-in), Supabase (hosting and database), OpenAI and Anthropic \
             (writing the summaries).
             """)),

            (L("Notifications, widgets et activité en direct",
               "Notifications, widgets and Live Activity"),
             L("""
             Nosfy peut te demander l'autorisation d'afficher des notifications ; \
             elles sont produites sur ton téléphone, jamais envoyées par un serveur. \
             Les widgets et l'activité en direct pendant une séance sont calculés sur \
             ton téléphone, à partir de tes séances, sans appel au serveur.
             """, """
             Nosfy may ask your permission to show notifications; they are produced \
             on your phone, never sent by a server. Widgets and the Live Activity \
             during a session are computed on your phone, from your sessions, with no \
             call to the server.
             """)),

            (L("Responsabilité",
               "Liability"),
             L("""
             Dans les limites permises par la loi, nous ne sommes pas responsables \
             des dommages indirects : perte de données locales, blessure liée à un \
             entraînement, indisponibilité du service. Rien dans ces conditions ne \
             limite les droits que la loi te garantit en tant que consommateur.
             """, """
             To the extent permitted by law, we are not liable for indirect damage: \
             loss of local data, injury related to training, unavailability of the \
             service. Nothing in these terms limits the rights the law guarantees you \
             as a consumer.
             """)),

            (L("Modifications de ces conditions",
               "Changes to these terms"),
             L("""
             Nous pouvons faire évoluer ces conditions. La version en vigueur est \
             celle affichée ici, avec sa date. Une modification importante te sera \
             signalée dans l'app avant de s'appliquer ; si tu la refuses, tu peux \
             supprimer ton compte.
             """, """
             We may update these terms. The version in force is the one shown here, \
             with its date. A significant change will be announced in the app before \
             it applies; if you refuse it, you can delete your account.
             """)),

            (L("Droit applicable",
               "Governing law"),
             L("""
             Ces conditions sont soumises au droit français. En cas de litige, nous \
             chercherons d'abord une solution amiable ; à défaut, les tribunaux \
             français sont compétents, sans préjudice des règles impératives de \
             protection du consommateur de ton pays de résidence.
             """, """
             These terms are governed by French law. In the event of a dispute, we \
             will first seek an amicable solution; failing that, the French courts \
             have jurisdiction, without prejudice to the mandatory consumer \
             protection rules of your country of residence.
             """)),
        ]
        return textes.enumerated().map { i, t in
            CGUArticle(id: i + 1, titre: t.0, corps: t.1)
        }
    }
}

/// Les conditions générales, dans la robe des Réglages : le noir, Inter, les
/// encres blanches en dégradé. Un texte qui se lit d'une traite, sans
/// décor : c'est la page la moins chère de l'app, et elle doit le rester.
struct CGUPage: View {
    var fermer: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 0) {
                RangeeChips(retour: fermer) { EmptyView() }
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Conditions générales d'utilisation", "Terms of Use"))
                                .font(.inter(24, .bold))
                                .foregroundStyle(Color.inkPrimary)
                            Text(CGUTexte.version)
                                .font(.inter(12, .medium))
                                .tracking(0.6)
                                .foregroundStyle(Color.inkMuted)
                        }

                        Text(CGUTexte.intro)
                            .font(.inter(15, .regular))
                            .foregroundStyle(Color.inkSecondary)
                            .lineSpacing(3)

                        ForEach(CGUTexte.articles) { article in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(article.id). \(article.titre)")
                                    .font(.inter(15, .semibold))
                                    .foregroundStyle(Color.inkPrimary)
                                Text(article.corps)
                                    .font(.inter(14, .regular))
                                    .foregroundStyle(Color.inkSecondary)
                                    .lineSpacing(3)
                            }
                        }

                        Spacer(minLength: 160)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
            }
        }
    }
}
