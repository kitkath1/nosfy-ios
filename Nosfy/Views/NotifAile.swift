import SwiftUI

// MARK: - VARIANT 5 « L'AILE » · VARIANT 6 « LE CLIN D'ŒIL »

/// LES DEUX ROBES DEMANDÉES LE 24-09, pour le « +20 » qui tombe **pendant la
/// séance** (la fin d'une série, `ExerciseDetailView` → `ToasterSerie`).
///
/// ⚠️ **CE QU'ELLE A CONSTATÉ CE JOUR-LÀ, ET QUI ÉTAIT VRAI** : « je vois bien
/// les toasters avec la pièce sur le côté +20, mais pas les deux autres
/// variants ». Les variants 2 (le gros texte) et 3 (la châsse) étaient codés
/// depuis le 29-08 et **n'avaient aucun site d'appel** : ils ne vivaient que
/// dans le banc `-notifLab`. En séance, une seule robe sortait — la jauge.
/// `ToasterSerie` (au bas de ce fichier) est ce qui manquait : la robe TOURNE
/// avec le rang de la série, comme `rewardVariant` tourne sur la fiche.
///
/// Les trois registres existants, et pourquoi il en fallait deux de plus :
/// le variant 1 dit un ÉTAT (la jauge), le 2 une EXCLAMATION (le mot géant
/// rogné), le 3 une MATIÈRE (la châsse). Les deux nouveaux disent autre chose
/// encore — le 5 est un GESTE (la bête ouvre son aile vers le chiffre), le 6
/// une COMPLICITÉ : la dalle de la maison, jauge comprise, avec la petite
/// tête qui cligne à la place de la pièce.
///
/// ⚠️ **AUCUN MASQUE, DES DEUX CÔTÉS** : les deux fichiers sont sur du NOIR
/// VRAI (mesuré au seuil 12/255 sur l'enveloppe des films). La bête se fond
/// dans la dalle sans détourage — c'est la seule façon de ne pas forcer un
/// rendu hors écran de tout le plan à chaque image (la loi de `NotifChasse`).
///
/// ⚠️ **LES BOUCLES SONT CUITES DANS LES FICHIERS, EN PING-PONG.** Mesure du
/// 24-09 : AUCUNE coupe sèche n'est bouclable dans ces deux sources — la
/// meilleure paire d'images de `aile.mp4` laisse une couture à 2,53× le
/// plancher, celle de `cline_d'oleil.mp4` à 8,1× (la tête dérive et ne revient
/// jamais), quand l'école `NotifChasse` plafonne à ~2×. Le ping-pong ampute
/// son retour de ses DEUX doublons de bord : la couture vaut alors UN pas
/// d'image, par construction. Relevé sur les fichiers cuits : l'aile coud à
/// 1,12 pour un pas moyen de 1,62 (le raccord est plus doux qu'une image
/// ordinaire du film) ; le clin coud à 1,29 dont 1,23 de bruit de codec pur
/// — le mouvement, lui, est continu. Recette : `tools/notifs/recuit_notif.sh`.
///
/// ⚠️⚠️ **LES DEUX FICHIERS SONT RE-DATÉS À 30 IMG/S**, et c'est son verdict
/// du 24-09 (« effet glitch sur la vidéo du Nosfy »). Les sources sont en
/// 24 img/s : 60 / 24 = 2,5, donc sur un écran 60 Hz chaque image tient 2
/// puis 3 rafraîchissements, en alternance — le pulldown 3:2. Sur une aile
/// qui balaie lentement ça SACCADE, et ce n'est pas un défaut d'image (les
/// images du film au simulateur sont propres une par une : pas max 0,91 pour
/// un médian 0,42, aucun artefact). À 30 img/s chaque image tient exactement
/// 2 rafraîchissements à 60 Hz, 4 à 120 : cadence parfaitement régulière.
/// Rien n'est dupliqué ni interpolé — `minterpolate` fabriquerait des
/// fantômes sur les membranes (l'école duo).

// MARK: - Les prises

/// LES BARREAUX DE CES DEUX ROBES.
///
/// ⚠️ **UN MOTEUR COÛTEUX ARRIVE AVEC SON BARREAU** (la loi du dépôt) : ces
/// deux robes montent un `AVPlayerLayer` dans une dalle qui ne vit que deux
/// secondes. Sans `-sansVideoNotif` on ne pourrait ni les accuser ni les
/// disculper d'une chauffe de séance.
enum RobeNotif: Int {
    case jauge = 1, grosTexte = 2, chasse = 3, aile = 5, clin = 6

    /// ⚠️⚠️ **L'ORDRE DU TOUR DE RÔLE — UNE DE CHAQUE, ET LA PIÈCE EN
    /// DERNIER** (24-09 : « fais en sorte de bien alterner pendant la session
    /// entre les robes, limite une de chaque à chaque fois — on voit tout le
    /// temps celle de la pièce ! »). Cinq robes, cinq tours : chacune passe
    /// UNE fois avant qu'aucune ne repasse. Et la jauge à la pièce ferme la
    /// marche, parce que c'était elle, le problème.
    ///
    /// ⚠️ **LA ROBE BOOSTER (la 4 du banc) N'EST PAS DANS CE TOUR**, et ce
    /// n'est pas un oubli : ce qu'elle pose à droite est le SACHET ORANGE,
    /// la quittance d'un booster gagné. Sur un « +20 COINS EARNED » elle
    /// annoncerait un sachet que personne n'a eu — une robe qui ment sur
    /// l'événement. Elle garde son événement à elle (`Annonce.sachet`).
    static let tourDeRole: [RobeNotif] = [.grosTexte, .aile, .clin,
                                          .chasse, .jauge]

    /// Cette robe monte-t-elle un lecteur vidéo ? (La jauge est la seule qui
    /// n'en monte pas : le mot géant a sa matrice, la châsse et les deux
    /// nouvelles ont leur bête.)
    var porteUneVideo: Bool { self != .jauge }

    /// `-sansVideoNotif` — les robes vidéo retombent sur la jauge.
    static let sansVideo = CommandLine.arguments.contains("-sansVideoNotif")

    /// `-robeNotif <1|2|3|5|6>` — une robe CLOUÉE pour la séance entière
    /// (filmer une robe précise sans enchaîner cinq séries).
    static let forcee: RobeNotif? = {
        guard let v = NotifBanc.number(after: "-robeNotif"),
              let r = RobeNotif(rawValue: Int(v)) else { return nil }
        return r
    }()

    /// LA ROBE D'UN TOUR — déterministe, et chacune passe une fois avant
    /// qu'aucune ne repasse. C'est son mot du 29-08 (« les robes VARIENT,
    /// aucune n'est clouée à un moment ») tenu pour de bon.
    ///
    /// ⚠️ **LE TOUR, PAS LE RANG DE LA SÉRIE.** Premier jet : je comptais sur
    /// le rang. Mais les rangs 3, 5 et 10 sont des rangs de POP-UP
    /// (`DecideurSerie.rangsFixes`) : ils ne posent jamais de toaster, et
    /// certaines robes seraient tombées deux fois moins souvent que les
    /// autres — une rotation qui boite. Un compteur de toasters POSÉS donne
    /// un tour égal à chacune, exactement.
    ///
    /// ⚠️ **LA CHALEUR A LE DERNIER MOT.** Téléphone chaud, aucun lecteur ne
    /// monte : la jauge dit la même chose sans vidéo.
    static func pour(tour: Int) -> RobeNotif {
        let choisie = forcee
            ?? tourDeRole[(max(tour, 1) - 1) % tourDeRole.count]
        guard choisie.porteUneVideo else { return choisie }
        guard !sansVideo, !ProtectionThermique.shared.ambianceAuRepos else {
            return .jauge
        }
        return choisie
    }
}

// MARK: - VARIANT 5 « L'AILE »

/// LA BÊTE OUVRE SON AILE, À GAUCHE, ET L'AILE DÉSIGNE LE GAIN.
///
/// ⚠️ **LE FILM SE JOUE À L'ENVERS, ET C'EST LE SUJET DE LA ROBE.** La source
/// part aile DÉPLOYÉE et la replie à la fin : à l'endroit, Nosfy RANGE son
/// aile pendant que la dalle arrive — exactement le contraire de ce qu'elle a
/// demandé (« un Nosfy qui montre l'aile »). Le fichier est donc cuit
/// retourné, et cadré pour que le déploiement tombe entre 0,08 s et 0,68 s :
/// le toaster de séance ne vit que ~2,3 s, l'ouverture doit être finie quand
/// l'œil arrive sur le chiffre.
///
/// ⚠️ **PAS DE POUDRE ICI, ET C'EST VOULU.** `PoudreAiles` est la signature du
/// variant 3 (ses grains montent de DEUX pointes d'ailes, à ±96 pt du centre
/// de la dalle) : la reposer sur une bête décentrée en sèmerait à côté, et
/// ferait de cette robe la châsse repeinte. Trois cards doivent offrir trois
/// réponses — cinq, cinq.
struct NotifAile: View {
    var gain: Int = 20
    var libelle: String = "COINS EARNED"
    /// Où en est le coffre APRÈS ce gain [0,1] — la MÊME jauge que les autres
    /// robes (24-09, sa demande : « si, une barre pour l'aile aussi »). La
    /// colonne de droite est donc la grammaire de la maison EN MIROIR : le
    /// chiffre et son libellé en tête, la jauge au pied ; la bête tient la
    /// gauche, l'encre tient la droite.
    var fraction: Double = 0.62
    /// L'entrée est POSÉE.
    var pose: Bool
    var naissance: Date

    /// Le progrès de l'entrée — sa propre rampe, comme dans les autres cards
    /// (un seul `withAnimation` par card et par tour : deux au même tour ne
    /// font RIEN, la loi payée).
    @State private var progres: Double = 0

    /// Le fichier fait 480×368 (ratio 1,304) : la bête prend TOUTE la hauteur
    /// de la dalle et son aile déployée mange la moitié gauche. On ne la
    /// déforme pas — le cadre est au ratio exact.
    private static let hauteurBete: CGFloat = NotifGeo.hauteur
    private static let largeurBete: CGFloat = NotifGeo.hauteur * 480 / 368

    var body: some View {
        ZStack {
            bete
            lueurDeLAile
            colonne
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(RobeSocle())
        .onAppear(perform: caler)
        .onChange(of: pose) { _, _ in caler() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plus \(gain) \(libelle).")
    }

    private func caler() {
        guard !NotifBanc.fige else {
            progres = pose ? 1 : 0
            return
        }
        withAnimation(.easeOut(duration: 1.0)) {
            progres = pose ? 1 : 0
        }
    }

    // ── LA BÊTE, À GAUCHE

    private var bete: some View {
        VideoBete(nom: "nosfy-aile-loop")
            .frame(width: Self.largeurBete, height: Self.hauteurBete)
            .frame(maxWidth: .infinity, maxHeight: .infinity,
                   alignment: .leading)
            .allowsHitTesting(false)
    }

    /// LA LUEUR A UNE CAUSE, ET C'EST LA POINTE DE L'AILE — elle se lève avec
    /// le déploiement (`progres`) et meurt où l'aile s'arrête.
    ///
    /// ⚠️ **DEVANT, JAMAIS DERRIÈRE.** Le noir d'une couche vidéo est OPAQUE :
    /// une lueur posée dessous dessine le RECTANGLE du plan (la nappe morte du
    /// variant 3, 29-08). Celle-ci est posée par-dessus tout le monde, en
    /// `.screen` — elle ne peut rien silhouetter.
    private var lueurDeLAile: some View {
        GeometryReader { g in
            RadialGradient(
                stops: [
                    .init(color: .white.opacity(0.070), location: 0),
                    .init(color: .white.opacity(0.026), location: 0.34),
                    .init(color: .white.opacity(0.007), location: 0.63),
                    .init(color: .clear, location: 1)
                ],
                center: .center, startRadius: 0, endRadius: 108)
            .frame(width: 216, height: 216)
            .position(x: Self.largeurBete * 0.94, y: g.size.height * 0.36)
            .blendMode(.screen)
            .opacity(progres)
        }
        .allowsHitTesting(false)
    }

    // ── L'ENCRE, À DROITE — là où l'aile pointe

    /// ⚠️ **LA COLONNE COMMENCE OÙ L'AILE FINIT.** Son bord gauche est calé
    /// sur la largeur de la bête (moins 4 pt) : la jauge ne passe jamais sous
    /// la membrane, et rien n'est mesuré à la main — si le fichier change de
    /// ratio, la colonne suit.
    private var colonne: some View {
        VStack(alignment: .trailing, spacing: 0) {
            ChiffreQuiMonte(valeur: progres * Double(gain), corps: 34)
            Text(libelle)
                .font(.inter(11, .semibold))
                .tracking(1.6)
                .foregroundStyle(Color.inkSecondary)
                .opacity(progres)
                .padding(.top, 3)
            Spacer(minLength: 8)
            BarreParticules(fraction: pose ? fraction : 0,
                            naissance: naissance, grains: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.vertical, NotifGeo.pad)
        .padding(.trailing, NotifGeo.pad)
        .padding(.leading, Self.largeurBete - 4)
    }
}

// MARK: - VARIANT 6 « LE CLIN D'ŒIL »

/// LA DALLE DE LA MAISON, ET LA PETITE TÊTE QUI CLIGNE À LA PLACE DE LA PIÈCE.
///
/// ⚠️ **PREMIER JET REFUSÉ, ET LA LEÇON VAUT D'ÊTRE ÉCRITE** (24-09) : j'avais
/// dessiné une mise en page à moi — « +20 » énorme en blanc plein, « PIÈCES »
/// dessous, la tête à droite, rien d'autre. Son verdict : « trop cheap le +20
/// pièces en blanc, mets le même layout que les autres toasters avec la barre
/// de progression ». Une ROBE n'est pas une mise en page de plus : c'est ce
/// qu'on pose à DROITE de la dalle commune. Le gabarit (le chiffre en tête, le
/// sous-titre, la jauge du coffre) est la FAMILLE — on n'en sort pas pour
/// faire joli, sinon la notification n'a plus de maison.
///
/// ⚠️ **LE CLIN TOMBE À ~0,84 s**, et c'est cuit dans le fichier : mesuré au
/// piqué des yeux (le compte de pixels > 200 dans la zone des yeux passe de
/// ~40 à 13 sur deux battements), la source clignait à 1,3 s — trop tard pour
/// une dalle qui vit ~2,3 s. Le fichier est coupé six images plus tôt et
/// re-daté à 30 img/s ; le ping-pong le fait revenir toutes les ~1,8 s.
struct NotifClin: View {
    var sousTitre: String = "VAULT PROGRESS"
    var libelle: String = "COINS EARNED"
    var gain: Int = 20
    /// Où en est le coffre APRÈS ce gain [0,1] — la MÊME jauge que la robe
    /// pièce, lue au même endroit.
    var fraction: Double = 0.62
    /// L'entrée est POSÉE.
    var pose: Bool
    var naissance: Date

    var body: some View {
        NotifJauge(sousTitre: sousTitre, libelle: libelle, gain: gain,
                   fraction: fraction, pose: pose, naissance: naissance,
                   robe: .clin)
    }
}

// MARK: - LE TOASTER DE SÉRIE — celui qui fait TOURNER les robes

/// LE « +20 » DE LA FIN D'UNE SÉRIE, dans la robe de son rang.
///
/// C'est le site d'appel qui manquait depuis le 29-08 — les robes 2 et 3
/// étaient codées et n'avaient AUCUN chemin vers l'écran. Il ne décide rien
/// d'autre que la ROBE : le gain, la progression du coffre et le libellé sont
/// ceux de `ToasterGain`. Cinq robes, chacune une fois par tour de rôle.
struct ToasterSerie: View {
    let gain: Int
    /// La progression du coffre APRÈS ce gain [0,1] — ce que dit la jauge.
    var fraction: Double = 0
    /// LE TOUR — le combientième toaster de la séance. C'est lui qui fait
    /// tourner les robes (jamais le rang de la série : voir `RobeNotif.pour`).
    var tour: Int = 1
    var libelle: String = "COINS EARNED"

    @State private var pose = false
    @State private var naissance = Date()

    var body: some View {
        Group {
            switch RobeNotif.pour(tour: tour) {
            case .jauge:
                ToasterGain(gain: gain, fraction: fraction, libelle: libelle)
            case .grosTexte:
                // La robe 2 « YOU WIN » — codée le 28-08, et qui n'était
                // jamais sortie du banc jusqu'ici.
                NotifGrosTexte(gain: gain, pose: pose, naissance: naissance)
            case .chasse:
                // La robe 3 « la châsse » — même histoire (29-08).
                NotifChasse(gain: gain, libelle: libelle,
                            pose: pose, naissance: naissance)
            case .aile:
                NotifAile(gain: gain, libelle: libelle, fraction: fraction,
                          pose: pose, naissance: naissance)
            case .clin:
                NotifClin(libelle: libelle, gain: gain, fraction: fraction,
                          pose: pose, naissance: naissance)
            }
        }
        .onAppear {
            naissance = Date()
            withAnimation(.easeOut(duration: 0.5)) { pose = true }
        }
    }
}
