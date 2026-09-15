import SwiftUI
import UIKit
import QuartzCore

// MARK: - LA BOÎTE NOIRE (05-09) — les callbacks d'affichage, sur SON téléphone
//
// Demande de Kathryn : « tu pourras mettre une sonde sur mon tel, je me
// baladerai, et tu mesureras les latences en direct ».
//
// La loi du dépôt demande une mesure sur le TÉLÉPHONE : l'A/B joué au simulateur le
// 04-09 l'a reprouvé (5 img/s contre 8, les deux effondrés — le
// simulateur ne mesurait que le simulateur).
//
// CE QU'ELLE ENREGISTRE, une ligne par seconde :
//   · la cadence des callbacks CADisplayLink servis par le fil principal ;
//   · LE PIRE TROU de la seconde — c'est ÇA qu'on sent au doigt, pas la
//     moyenne : 58 img/s avec un trou de 300 ms, ça « lague » ;
//   · le CONTEXTE, posé par le châssis et jamais deviné : quel onglet,
//     séance ou pas, player ouvert, pastille en main, île ;
//   · ses MARQUES : elle tape la pastille de la sonde quand ça lague, et
//     l'instant est estampillé. C'est ce qui relie son ressenti au chiffre.
//
// `img` n'est PAS un compteur de nouvelles images présentées par le GPU.
// Les trous montrent que les callbacks n'ont pas été servis régulièrement ;
// ils ne disent pas, seuls, si le fil calcule, attend, ou subit une cadence
// réduite par le système. La preuve GPU demande une trace de rendu.
//
// Elle écrit dans `Documents/vol-<date>.jsonl` — on le récupère après sa
// balade avec `devicectl device copy from`. Rien ne part sur le réseau.
//
// ⚠️ ELLE DOIT ÊTRE QUASI GRATUITE, sinon elle mesure elle-même : UN
// display link qui incrémente deux entiers, UNE ligne de texte par
// seconde, un HUD de texte rafraîchi 1×/s. Aucun Canvas, aucun flou,
// aucune horloge SwiftUI.

enum SondeVolBanc {
    /// Mesurer avec Instruments sans ajouter le display link ni le HUD.
    /// Non mémorisé ; le maintien de l'écran expire après trente minutes.
    static let ecranEveille = CommandLine.arguments.contains("-ecranEveille")

    /// Allumée par le drapeau de lancement OU par la mémoire : une fois
    /// posée depuis le Mac, elle SURVIT aux lancements à la main (elle
    /// ouvre l'app en tapant l'icône, pas depuis Xcode — sans ça la
    /// sonde ne serait jamais allumée quand elle se balade).
    static let cle = "woop.sondeVol"

    static var actif: Bool {
        if CommandLine.arguments.contains("-sondeVol") {
            UserDefaults.standard.set(true, forKey: cle)
            return true
        }
        if CommandLine.arguments.contains("-sansSondeVol") {
            UserDefaults.standard.set(false, forKey: cle)
            return false
        }
        return UserDefaults.standard.bool(forKey: cle)
    }
}

@Observable
final class SondeVol {
    static let shared = SondeVol()
    private init() {}

    // Ce que le HUD montre (relu 1×/s, jamais par image).
    private(set) var img: Double = 0
    private(set) var pireMs: Double = 0
    /// La charge CPU récente des threads du process, lissée par
    /// l'ordonnanceur (100 = un cœur). Ce n'est ni le temps CPU exact de
    /// l'intervalle, ni une mesure du GPU, de l'énergie ou de la température.
    private(set) var cpu: Double = 0
    /// L'état thermique déclaré par iOS : 0 nominal, 1 fair, 2 serious,
    /// 3 critical. Il n'indique ni une température en degrés, ni le moment
    /// exact où un composant commence à réduire ses performances.
    private(set) var thermique: Int = 0
    /// Nombre de passages dans les corps INSTRUMENTÉS depuis la dernière
    /// ligne (environ une seconde, davantage lors d'un gel). Zéro ne dit
    /// rien des sous-vues non instrumentées ni du coût du compositeur.
    private(set) var corpsParSeconde: Int = 0
    private(set) var secondes: Int = 0
    private(set) var marques: Int = 0

    // LE CONTEXTE — posé par le châssis. `@ObservationIgnored` : il ne
    // doit réveiller aucune vue, il n'est lu qu'à l'écriture.
    @ObservationIgnored var enSeance = false
    @ObservationIgnored var onglet = "?"

    @ObservationIgnored private var lien: CADisplayLink?
    @ObservationIgnored private var coups = 0
    @ObservationIgnored private var pire: CFTimeInterval = 0
    @ObservationIgnored private var precedent: CFTimeInterval = 0
    @ObservationIgnored private var depuis: CFTimeInterval = 0
    @ObservationIgnored private var t0: CFTimeInterval = 0
    @ObservationIgnored private var marqueEnAttente = false
    @ObservationIgnored private var corpsCompte = 0
    @ObservationIgnored private var sortie: FileHandle?
    @ObservationIgnored private(set) var chemin: URL?

    // MARK: la vie de la sonde

    func demarrer() {
        guard lien == nil else { return }
        // ⚠️ L'ÉCRAN NE DORT PAS PENDANT QU'ON MESURE (05-09, payé).
        // Quand il s'endort, la cadence tombe ET le processeur avec :
        // on croit avoir éteint un moteur coûteux alors qu'on a
        // simplement mesuré un écran en veille. Trois essais du 05-09
        // sont partis à la poubelle comme ça (« sansVerreHome 12 % » :
        // zéro seconde à plein régime). Un instrument qui mesure autre
        // chose que ce qu'on croit est pire que pas d'instrument.
        UIApplication.shared.isIdleTimerDisabled = true
        ouvrirLeFichier()
        ecouterLeFond()
        t0 = CACurrentMediaTime()
        depuis = t0
        precedent = t0
        let l = CADisplayLink(target: self, selector: #selector(coup(_:)))
        l.add(to: .main, forMode: .common)
        lien = l
    }

    func arreter() {
        UIApplication.shared.isIdleTimerDisabled = false
        lien?.invalidate()
        lien = nil
        try? sortie?.close()
        sortie = nil
    }

    /// ⚠️ LA SONDE DORT AVEC L'APP. Sans ça, un écran qui s'éteint
    /// s'enregistre comme un trou de vingt secondes : le fichier
    /// raconterait des gels qui n'ont jamais eu lieu, et on chercherait
    /// une cause à un artefact. Un instrument qui ment est pire que pas
    /// d'instrument.
    private func ecouterLeFond() {
        let c = NotificationCenter.default
        c.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                      object: nil, queue: .main) { [weak self] _ in
            self?.lien?.isPaused = true
        }
        c.addObserver(forName: UIApplication.willEnterForegroundNotification,
                      object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            // On repart d'une horloge NEUVE : le temps passé au fond
            // n'appartient à aucune seconde mesurée.
            let t = CACurrentMediaTime()
            self.precedent = t
            self.depuis = t
            self.coups = 0
            self.pire = 0
            self.lien?.isPaused = false
        }
    }

    /// Appelée DANS le corps d'une vue qu'on surveille. Elle ne fait
    /// qu'incrémenter un entier : elle ne doit rien coûter, et surtout
    /// rien invalider (sinon elle se mesurerait elle-même).
    @inline(__always)
    func corps() { corpsCompte &+= 1 }

    /// Les passages dans les closures instrumentées, par groupe :
    ///   0 widgets · 1 nappe/menu · 2 galets · 3 route · 4 semaine.
    /// Ce sont des comptes par intervalle de publication, pas des images
    /// GPU ni nécessairement des Hz : plusieurs vues partagent un groupe,
    /// et un intervalle de gel peut durer plus d'une seconde.
    @inline(__always)
    func tic(_ i: Int) {
        guard i >= 0, i < 5 else { return }
        tics[i] &+= 1
    }
    @ObservationIgnored private var tics = [Int](repeating: 0, count: 5)
    private(set) var ticsParSeconde = [Int](repeating: 0, count: 5)

    /// Elle tape la pastille : « LÀ, ça a lagué ». La marque part dans la
    /// ligne de la seconde en cours.
    func marquer() {
        marqueEnAttente = true
        marques += 1
        Haptique.moyen()
    }

    // MARK: le compteur

    @objc private func coup(_ l: CADisplayLink) {
        let t = l.timestamp
        let dt = t - precedent
        precedent = t
        if dt > pire { pire = dt }
        coups += 1
        let age = t - depuis
        guard age >= 1.0 else { return }
        publier(cadence: Double(coups) / age, pire: pire, t: t)
        coups = 0
        pire = 0
        depuis = t
    }

    private func publier(cadence: Double, pire: CFTimeInterval,
                         t: CFTimeInterval) {
        img = (cadence * 10).rounded() / 10
        pireMs = (pire * 1000).rounded()
        cpu = (Self.cpuPourcent() * 10).rounded() / 10
        thermique = ProcessInfo.processInfo.thermalState.rawValue
        corpsParSeconde = corpsCompte
        corpsCompte = 0
        ticsParSeconde = tics
        for i in tics.indices { tics[i] = 0 }
        secondes += 1
        let marque = marqueEnAttente
        marqueEnAttente = false
        ecrire(t: t - t0, cadence: img, pireMs: pireMs, marque: marque)
        NavDiagnostic.noter("etat")
    }

    // MARK: LE PROCESSEUR — la charge récente du process

    /// Somme des `cpu_usage` Mach : charge récente lissée par thread,
    /// en % d'un cœur. Ce n'est pas un delta de user_time + system_time.
    /// Les autres process et le GPU ne sont pas compris dans cette somme.
    private static func cpuPourcent() -> Double {
        var fils: thread_act_array_t?
        var n: mach_msg_type_number_t = 0
        guard task_threads(mach_task_self_, &fils, &n) == KERN_SUCCESS,
              let fils else { return -1 }
        defer {
            // task_threads rend un droit de port POUR CHAQUE thread en
            // plus du tableau. Libérer seulement le tableau accumulait
            // une référence de plus par thread à chaque échantillon.
            for i in 0 ..< Int(n) {
                mach_port_deallocate(mach_task_self_, fils[i])
            }
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: fils)),
                          vm_size_t(Int(n) * MemoryLayout<thread_t>.stride))
        }
        var total: Double = 0
        for i in 0 ..< Int(n) {
            var info = thread_basic_info()
            var taille = mach_msg_type_number_t(
                MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size)
            let ok = withUnsafeMutablePointer(to: &info) { p in
                p.withMemoryRebound(to: integer_t.self,
                                    capacity: Int(taille)) { q in
                    thread_info(fils[i], thread_flavor_t(THREAD_BASIC_INFO),
                                q, &taille)
                }
            }
            guard ok == KERN_SUCCESS,
                  info.flags & TH_FLAGS_IDLE == 0 else { continue }
            total += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
        }
        return total
    }

    // MARK: le fichier

    private func ouvrirLeFichier() {
        let dossier = FileManager.default.urls(for: .documentDirectory,
                                               in: .userDomainMask)[0]
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        let url = dossier.appendingPathComponent(
            "vol-\(f.string(from: Date())).jsonl")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        sortie = try? FileHandle(forWritingTo: url)
        chemin = url
        print("[sonde-vol] enregistre dans \(url.lastPathComponent)")
    }

    private func ecrire(t: Double, cadence: Double, pireMs: Double,
                        marque: Bool) {
        guard let sortie else { return }
        let p = PlayerEtat.shared
        let pi = PiluleEtat.shared
        // L'onglet se LIT ici plutôt que de compter sur le châssis :
        // pendant le splash et la porte, personne ne l'a encore posé, et
        // une ligne qui dit « ? » ne sert à rien.
        if onglet == "?" { onglet = NavEtat.shared.page.rawValue }
        let bancHome: String = BancCoutHome.demande ? BancCoutHome.shared.phase.rawValue : "inactif"
        // Un format littéral évite une longue résolution des surcharges de +.
        let format = "{\"t\":%.1f,\"img\":%.1f,\"pire\":%.0f,\"onglet\":\"%@\",\"seance\":%d,\"player\":%d,\"ile\":%d,\"drag\":%d,\"marque\":%d,\"gel\":%d,\"cpu\":%.0f,\"therm\":%d,\"corps\":%d,\"tics\":[%d,%d,%d,%d,%d],\"chemin\":%d,\"protection\":%d,\"bancHome\":\"%@\",\"welcome\":%d,\"premiere\":%d}\n"
        let ligne = String(format: format,
            t, cadence, min(pireMs, 2000), onglet,
            enSeance ? 1 : 0,
            (p.ouvert || p.couvre) ? 1 : 0,
            pi.dansIle ? 1 : 0,
            (pi.enDrag || pi.enVol) ? 1 : 0,
            marque ? 1 : 0,
            pireMs > 2000 ? 1 : 0,
            cpu, thermique, corpsParSeconde,
            ticsParSeconde[0], ticsParSeconde[1], ticsParSeconde[2],
            ticsParSeconde[3], ticsParSeconde[4],
            DepartEtat.shared.cheminOuvert ? 1 : 0,
            ProtectionThermique.shared.ambianceAuRepos ? 1 : 0,
            bancHome,
            DepartEtat.shared.welcomeOuverte ? 1 : 0,
            DepartEtat.shared.welcomePremiereOuverte ? 1 : 0)
        if let d = ligne.data(using: .utf8) { sortie.write(d) }
    }
}

// MARK: - LE HUD — minuscule, en haut à gauche, et TAPABLE

/// Ce qu'elle voit pendant sa balade : la cadence, le pire trou de la
/// seconde, et le compte de ses marques. Un tap = « ça a lagué LÀ ».
/// Une pression longue éteint la sonde pour de bon.
struct SondeVolHUD: View {
    @State private var sonde = SondeVol.shared

    /// La couleur dit l'état sans qu'elle ait à lire : vert = fluide,
    /// orange = ça décroche, rouge = c'est mauvais. Le seuil porte sur
    /// LE PIRE TROU, jamais sur la moyenne — c'est le trou qu'on sent.
    private var teinte: Color {
        if sonde.pireMs > 100 { return Color(red: 1, green: 0.24, blue: 0.16) }
        if sonde.pireMs > 40 { return Color(red: 1, green: 0.60, blue: 0.10) }
        return Color(red: 0.30, green: 0.85, blue: 0.45)
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(teinte).frame(width: 7, height: 7)
            Text("\(Int(sonde.img))")
                .font(.system(size: 12, weight: .bold)).monospacedDigit()
            Text("\(Int(sonde.pireMs))ms")
                .font(.system(size: 11, weight: .medium)).monospacedDigit()
                .foregroundStyle(.white.opacity(0.65))
            // La charge CPU, indépendante de la cadence des callbacks.
            Text("\(Int(sonde.cpu))%")
                .font(.system(size: 11, weight: .semibold)).monospacedDigit()
                .foregroundStyle(sonde.cpu > 120
                                 ? Color(red: 1, green: 0.35, blue: 0.2)
                                 : .white.opacity(0.8))
            if sonde.thermique > 0 {
                Text(String(repeating: "▲", count: sonde.thermique))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.1))
            }
            if sonde.marques > 0 {
                Text("•\(sonde.marques)")
                    .font(.system(size: 11, weight: .bold)).monospacedDigit()
                    .foregroundStyle(Color(red: 1, green: 0.35, blue: 0.25))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.72)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
        .contentShape(Capsule())
        .onTapGesture { SondeVol.shared.marquer() }
        .onLongPressGesture(minimumDuration: 1.2) {
            UserDefaults.standard.set(false, forKey: SondeVolBanc.cle)
            SondeVol.shared.arreter()
            Haptique.moyen()
        }
        .padding(.leading, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity,
               alignment: .topLeading)
        .ignoresSafeArea()
    }
}

/// L'ÉCRAN NU — `-ecranNu` : le châssis rend du NOIR à la place des
/// pages, la sonde restant allumée. Il ne sert qu'à une chose, et c'est
/// la plus utile : donner le PLANCHER. Ce qui reste consommé quand plus
/// aucune page n'est rendue n'appartient pas aux pages.
enum EcranNu {
    static let actif = CommandLine.arguments.contains("-ecranNu")
}
