import UIKit

// MARK: - La forge des cartes-lune (banc `-luneLab`, bouton « Forger »)

/// La chaîne de génération d'une carte du set Lune :
///   1. une FAMILLE est tirée au sort (la surprise commence là) ;
///   2. GPT-5, directeur artistique, invente UNE scène dans cette famille —
///      la charte de la maison imprimée dans chaque appel ;
///   3. gpt-image-1 peint l'illustration (1024×1536, jamais de cadre :
///      le cadre est un ASSET FIXE, carte-cadre.png, posé par le code) ;
///   4. compositing : l'illustration glisse SOUS le cadre dans la fenêtre
///      d'art mesurée (x 0,118..0,881 · y 0,083..0,891 du canvas 1086×1448) ;
///   5. depth v0 analytique (rampe verticale dans la fenêtre, 0,45 neutre
///      sous le cadre) — la vraie depth (Depth Anything) viendra au pool.
///
/// La clé vit dans `.secrets/openai.key` (jamais dans le repo ni le bundle) ;
/// le lanceur la copie dans Documents/ du container simulateur. Sur iPhone,
/// la forge passera par l'Edge Function `forge-card` — jamais de clé dans
/// le binaire.
enum LuneForge {

    // MARK: Le set

    struct Famille {
        let nom: String
        let rarete: String
        let brief: String
        /// L'armature DURE de la famille : ce qui ne se négocie jamais —
        /// recette de composition, dosage braise/nuit, exigences de
        /// texture. GPT-5 n'improvise que la scène À L'INTÉRIEUR.
        let dur: String
    }

    /// Les familles du set Lune. La rareté n'est PAS une étiquette : c'est
    /// un REGISTRE DE MISE EN SCÈNE (voir `registres`) — le verdict de la
    /// première legendary l'a payé (« pas hyper légendaire » : le
    /// minimalisme est l'élégance du set, la legendary est son opéra).
    /// Le tirage pondéré viendra avec le pool ; au banc, tirage uniforme —
    /// on veut VOIR tout le set.
    static let familles: [Famille] = [
        // COMMON — la nuit ordinaire du set.
        .init(nom: "Forêt de pins", rarete: "common",
              brief: "A very dark pine forest at night, dense black conifers, near-monochrome.",
              dur: "Rows of black spruce silhouettes in at least three depth tiers separated by faint mist; crowns readable against a graded night sky; the logo crescent small and quiet; ember allowed only in the moon and one distant horizon thread."),
        .init(nom: "Vallée noire", rarete: "common",
              brief: "A black valley almost entirely drowned in night, relief barely readable.",
              dur: "A deep valley readable through value steps only — each ridge a darker band; thin mist on the valley floor; the logo crescent faint above; at most one ember whisper at the far end."),
        .init(nom: "Petite lune perdue", rarete: "common",
              brief: "An extremely small orange moon lost in an immense pitch-black night.",
              dur: "A vast graded night sky occupying almost everything; the logo crescent TINY yet razor-sharp; the ground reduced to a low silhouette band; the emptiness stays luminous, never flat."),
        .init(nom: "Montagnes invisibles", rarete: "common",
              brief: "Mountains almost invisible in darkness, only the faintest ridge lines.",
              dur: "Massive ridge lines barely emerging by value, matte; the logo crescent half-veiled by a cloud; one dominant cold gradient; ember reduced to the moon alone."),
        // RARE — la nuit + UNE présence remarquable. Le minimalisme vit ici.
        .init(nom: "Zoom sur la lune", rarete: "rare",
              brief: "A very graphic extreme close-up of an orange crescent moon, almost abstract, logo-like purity.",
              dur: "The logo crescent HUGE and graphic, its barbed hook crisp; surface textured like brushed ember metal; background pure graded night with faint cloud veils crossing the horns."),
        .init(nom: "Lune néon sur ciel noir", rarete: "rare",
              brief: "An entirely black sky with only an orange moon whose light barely reflects somewhere below — no fog, the reflection is the only echo.",
              dur: "The logo crescent as the ONLY light source in a graded black sky; its reflection below (water, wet stone) is the single echo; no other light anywhere."),
        .init(nom: "Lac noir", rarete: "rare",
              brief: "A black lake with a subtle moon reflection, everything else darkness.",
              dur: "A still black lake as a mirror; the logo crescent's reflection broken by exactly one ripple; shorelines as layered silhouettes; mist at the far bank."),
        .init(nom: "Corbeaux", rarete: "rare",
              brief: "A few hyperrealistic black crows, only the faintest sheen on their feathers, near-total darkness.",
              dur: "One to three crows with feather texture readable in cold rim light; a gnarled perch with bark detail; a FULLY painted backdrop — tiered ridges, sculpted clouds; the logo crescent in the sky."),
        .init(nom: "Chauves-souris au ciel", rarete: "rare",
              brief: "Very elegant bat silhouettes crossing the night sky.",
              dur: "Bat silhouettes at varied depths crossing a sculpted cloud sky, wing membranes rim-lit; the logo crescent between clouds; a low landscape band grounding the scene."),
        .init(nom: "Rangée de chauves-souris", rarete: "rare",
              brief: "A small row of black bats perched close together, almost invisible in an extremely deep night.",
              dur: "A row of bats on a wire or branch, bodies sculpted by cold light, ears and claws readable; painted backdrop with tiered depth (hills, mist); the logo crescent present; one tiny ember echo allowed."),
        .init(nom: "Démon aux yeux d'ambre", rarete: "rare",
              brief: "A small entirely-black wolf-dog demon hidden in darkness — practically only its thin yellow-orange eyes are visible.",
              dur: "Near-dark, but the wolf-dog's silhouette separates from the void: muzzle, ears, shoulders hinted by faint cold rim; the thin amber eyes are the ember; the logo crescent faint in the sky; the background keeps readable structure."),
        .init(nom: "Lumière seule", rarete: "rare",
              brief: "The landscape almost completely disappears; only the moon's light structures the composition.",
              dur: "Moonlight as the architect: shafts and pools of cold light structuring a nearly dissolved landscape; the logo crescent visible as the source; ember nuance only where the light grazes."),
        .init(nom: "Forêt aux nuages", rarete: "rare",
              brief: "A sea of sculpted dark clouds resting on black pine tops, in the anchor's cloud language.",
              dur: "A sea of sculpted clouds with real volume and under-lighting resting on pine crowns; at least three cloud tiers; the logo crescent floating above; dark ember nuance in the cloud bellies."),
        .init(nom: "Rivière de braise", rarete: "rare",
              brief: "A tiered night valley where a thin river catches the only ember-orange thread of a distant horizon.",
              dur: "A tiered valley where the river is a thin ember thread catching the horizon glow; forests in layered silhouette; the logo crescent above; ember lives ONLY in river, horizon and moon."),
        .init(nom: "Dragon des ténèbres", rarete: "rare",
              brief: "A great pitch-black fire dragon almost swallowed by the night — smooth-skinned, bat-winged, only its flame-tipped tail truly glowing.",
              dur: "The dragon's DESIGN follows the classic fire-lizard starter body plan: bipedal, standing upright, SMOOTH skin (no scale texture), rounded belly, two backward-curving head horns, small arms, large bat wings, thick tail with a living flame at its tip. VERY black and matte, almost swallowed by darkness, separated from the void by a faint cold rim; the tail-flame is the main ember echo; fully painted backdrop with tiered depth; the logo crescent in the sky."),
        // EPIC — le ciel entre en scène : le drame.
        .init(nom: "Ciel de sang", rarete: "epic",
              brief: "A blood-red sky above a black forest.",
              dur: "The sky as a dark blood-red gradation with sculpted cloud volumes — no flat red; a black forest band below with readable crowns; the logo crescent pale against the red; no pure-black voids in the sky."),
        .init(nom: "Oiseau de braise", rarete: "epic",
              brief: "An immense black legendary bird of prey, phoenix-like silhouette, above a blood-red or black sky, a few ember-orange nuances caught in its feathers.",
              dur: "The bird immense, wing edges readable feather by feather; dark ember nuances caught in the plumage; a dramatic sculpted sky; the landscape dwarfed below; the logo crescent present."),
        .init(nom: "Lune de sang", rarete: "epic",
              brief: "A huge blood-red moon dominating the composition.",
              dur: "The moon huge and blood-dark — STILL the logo's barbed-crescent silhouette (a blood eclipse of the glyph), surface texture readable; sculpted clouds crossing it; landscape minimal below."),
        .init(nom: "Vallée de la lune", rarete: "epic",
              brief: "The mother family — the style anchor itself: a stacked night valley, tiered pine ridges descending to a misty river, sculpted clouds parting around a thin orange crescent.",
              dur: "The anchor's recipe verbatim: tiered pine ridges to a misty river, sculpted clouds parting around the logo crescent, one warm ember glow at the far horizon; nothing less than the anchor's density."),
        // LEGENDARY — le FULL ART : l'opéra du set, jamais le vide.
        .init(nom: "Le démon en majesté", rarete: "legendary",
              brief: "The black wolf-dog demon staged in majesty WITHIN its landscape: a tall silhouette risen on a ridge of the anchor valley, thin amber eyes burning, layered forest and sculpted clouds all around.",
              dur: "Full-art: the demon tall on a ridge, silhouette detailed (fur edges, stance), amber eyes burning far; the valley layered in mist tiers around him; monumental clouds; the logo crescent placed with intent; ember nuances in eyes, sky and horizon."),
        .init(nom: "La vallée souveraine", rarete: "legendary",
              brief: "The anchor valley pushed to its summit: the most sumptuous stacked landscape of the set — grand cloud architecture, deep tiers of forest and mist, moonlight choreographed across every plane.",
              dur: "Full-art: five depth tiers minimum (foreground rock or branch, mid forests, river, far ridges, sky); monumental cloud architecture; moonlight touching every tier; ember nuances woven in clouds, river and horizon."),
        .init(nom: "L'oiseau souverain", rarete: "legendary",
              brief: "The immense black bird of prey in full majesty above the anchor valley, wings spanning the sky, ember nuances caught in its feathers, dark clouds parting in its wake.",
              dur: "Full-art: the full wingspan across the sky with detailed plumage; clouds parting in its wake; the valley below in layered depth; ember nuances in feathers and horizon; the logo crescent visible."),
        .init(nom: "Le dragon de braise", rarete: "legendary",
              brief: "A mighty fire dragon in full majesty over the anchor valley — the classic fire-lizard starter silhouette: bipedal, smooth-skinned, round-bellied, two horns, great bat wings, its thick tail ending in a living flame.",
              dur: "Full-art: the dragon's DESIGN follows the classic fire-lizard starter body plan — standing on two legs, small arms, rounded belly, two backward-curving head horns, large bat wings, thick tail with a living flame at its tip. The hide SMOOTH (no scale texture): black lacquered obsidian, SHINY with iridescent micro-highlights and an ember rim gliding over it; throat and belly warmed by inner ember light; fierce yet SIMPLE in form, zero clutter, zero fairy-tale; layered valley and monumental clouds around; the logo crescent present."),
        .init(nom: "Le cerf d'obsidienne", rarete: "legendary",
              brief: "A great black stag of obsidian standing in the anchor valley, the tips of its antlers glowing like embers.",
              dur: "Full-art: the stag SHINY — lacquered obsidian coat, iridescent micro-highlights, ember-glowing antler tips as the main echo; majestic and quietly disquieting, zero fairy-tale; tiered forest and mist around; the logo crescent in the sky."),
        .init(nom: "La lune souveraine", rarete: "legendary",
              brief: "The moon ITSELF as the character: the logo crescent colossal and shiny, clouds parting around it like a cathedral.",
              dur: "Full-art of the sky: the logo crescent COLOSSAL, lacquered ember material with readable surface texture and iridescent micro-highlights; monumental sculpted clouds parting around it; the landscape reduced to a low silhouette band; the exact opposite of the tiny lost moon."),
    ]

    /// La grammaire du spectacle : la rareté DICTE la mise en scène. Les
    /// clauses sont HARDCORE (verdict Kathryn : carte-lune-1 est le niveau
    /// d'une RARE — la finition somptueuse est le PLANCHER du set, le
    /// registre ne change que ce qui est mis en scène). Même famille, deux
    /// vies possibles (le démon : rare = les yeux · legendary = en majesté).
    static let registres: [String: String] = [
        "common": "Register COMMON — a calm, simple SUBJECT painted at full masterwork level: the ordinary night of the set rendered sumptuously — layered pine ridges with readable treetops, sculpted dark clouds with faint ember under-lighting, soft atmospheric mist between planes, the fine crescent placed quietly. Simplicity lives in the composition, NEVER in the craft.",
        "rare": "Register RARE — the night plus ONE remarkable presence (creature, reflection, graphic close-up), staged with elegance in front of a fully painted backdrop: detailed sky architecture, tiered landscape depth, the presence sculpted by cold rim light with readable texture (fur, feathers, water). The anchor card's level of finish is the FLOOR here — luminous, never a void.",
        "epic": "Register EPIC — the sky takes the stage: blood moons, burning skies, immense winged silhouettes — grand atmospheric drama: towering sculpted cloudscapes with dark ember cores, layered light gradients from deep black to dark ember, landscape tiers dwarfed below. Visibly richer and more intense than RARE, still controlled — never kitsch.",
        "legendary": "Register LEGENDARY — the FULL-ART opera, visibly ABOVE every other register: an overflowing masterwork — foreground, middle ground and far distance all richly detailed, monumental cloud architecture, choreographed moonlight touching every plane, painterly density worthy of a collector artwork. The central figure (creature, or the moon itself) is SHINY: lacquered, lustrous, magnificent — polished-obsidian material, iridescent micro-highlights catching the moonlight, an ember rim gliding over scales, feathers or fur. Splendor comes from MATERIAL, never from rainbow colors: the palette stays the night/dark-ember duo. Abundant and extraordinary at first glance — never minimal, never empty.",
    ]

    /// La charte, imprimée dans CHAQUE appel — c'est elle qui fait que
    /// cinquante cartes côte à côte sont UNE collection.
    private static let charte = """
    You are the art director of « Lune », a collector-card set for a premium \
    fitness app. Every card is a vertical illustration that will live inside \
    the same fixed black frame, added later by code — so NEVER draw a frame, \
    border, card edge, text, letters, numbers, logo or watermark.

    The set's soul, non-negotiable:
    - Deep night, but the card must READ. Every subject is sculpted by a \
    visible light: a moonlight rim, a cold gray sky gradient, a faint \
    atmospheric sheen. Blacks are deep, yet silhouettes always separate \
    cleanly from the background by VALUE — a subject must never sink into \
    the void. Poetic and quietly disquieting — never horror, never gore, \
    never occult or mystical symbols.
    - The style anchor of the set (card #1): a night valley in stacked \
    planes — tiered pine ridges descending toward a misty river, sculpted \
    dark clouds parting around a thin orange crescent moon, one warm ember \
    glow at the far horizon, everything else deep warm blacks and cold \
    grays with real value range. Landscape families inherit this DNA.
    - THE MOON IS THE SIGNATURE. Every single card carries the BRAND'S \
    moon: a fine barbed-hook crescent (the painter receives the exact \
    glyph as a reference image — always call it "the logo crescent"). \
    Sometimes tiny and lost, sometimes huge, sometimes half-veiled by \
    sculpted clouds or echoed in a reflection, but ALWAYS present.
    - The palette is a DUO of nuances, like the anchor card: deep night \
    grays and warm near-blacks WOVEN with dark ember-orange nuances — \
    in cloud bellies, on a horizon, in a reflection. The ember is deep \
    and dark, never bright neon, never yellow; it breathes through the \
    matter of the scene but NEVER becomes an orange fog, haze or glow \
    wash. Values stay readable — never flat pure black.
    - Some cards are spectacular, others minimalist — both are right, but \
    minimal never means invisible: even the emptiest card keeps a \
    readable luminous structure. Think of the image seen small, as a card \
    held in a hand: values must carry at a glance.
    - Cinematic matte-painting realism: crisp silhouettes, sculpted \
    shadows. No cartoon, no neon kitsch, no fantasy clutter.
    - EVERY register is painted at the same masterwork level of detail \
    and finish — sumptuous sculpted clouds, readable textures, layered \
    atmospheric depth. The anchor card's craft is the set's FLOOR: \
    registers change what is STAGED, never the quality of the painting.
    - Vertical 2:3. Keep the essential subject in the central safe zone: \
    nothing important in the outer 12% of the image, nor in the top-left \
    medallion area (top fifth of the left half) — the frame overlaps there.

    Given a family brief and its hard constraints, invent ONE surprising, \
    specific scene inside that family, with a bold composition. Answer \
    with the final image-generation prompt only — one dense paragraph in \
    English that walks the scene PLANE BY PLANE (foreground, middle \
    ground, far distance — matter and light for each), then places the \
    logo crescent and says where the dark-ember nuances breathe. No \
    preamble, no quotes.
    """

    /// Le rappel soudé à la fin du prompt du peintre — la charte tient
    /// même si le directeur s'est laissé emporter.
    private static let rappel = " Vertical 2:3 full-bleed illustration, " +
        "cinematic matte painting realism, true deep blacks, the moon " +
        "painted as EXACTLY the barbed-crescent logo glyph of the first " +
        "reference image, night grays woven with deep dark ember nuances, " +
        "no orange fog, no frame, no border, no text."

    // MARK: Le résultat

    struct Carte {
        let art: UIImage      // le canvas complet 1086×1448, cadre posé
        let depth: UIImage    // 543×724, rampe v0
        let famille: Famille
        let scene: String     // la scène inventée par le directeur
        var cardId: String? = nil
        var acquisitionId: String? = nil
    }

    enum Erreur: LocalizedError {
        case cle, reponse(String), image, cadre, reference
        var errorDescription: String? {
            switch self {
            case .cle: return "clé absente (.secrets/openai.key)"
            case .reponse(let m): return m
            case .image: return "image illisible"
            case .cadre: return "carte-cadre.png absent du bundle"
            case .reference: return "référence absente (carte-logo-ref / carte-lune-1)"
            }
        }
    }

    // MARK: La géométrie (le contrat du set — soudée au shader)

    static let canvas = CGSize(width: 1086, height: 1448)
    /// La fenêtre d'art normalisée (mesure.py) — identique pour TOUTES
    /// les cartes : le cadre est fixe, le shader aussi.
    static let fenetre = CGRect(x: 0.118, y: 0.083,
                                width: 0.881 - 0.118, height: 0.891 - 0.083)

    // MARK: La clé

    private static func cle() -> String? {
        if let env = ProcessInfo.processInfo.environment["OPENAI_API_KEY"],
           !env.isEmpty { return env }
        #if targetEnvironment(simulator)
        // Le sandbox du simulateur iOS 26 INTERDIT le disque du Mac (payé
        // au banc : .secrets/ illisible depuis l'app). La clé est donc
        // copiée dans Documents/ du container par le lanceur :
        //   xcrun simctl get_app_container <sim> fr.kathryn.woop data
        //   cp .secrets/openai.key <container>/Documents/openai.key
        let docs = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first
        if let docs,
           let s = try? String(contentsOf: docs.appending(path: "openai.key"),
                               encoding: .utf8) {
            let clé = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clé.isEmpty { return clé }
        }
        return nil
        #else
        return nil
        #endif
    }

    // MARK: La forge

    /// La chaîne complète. Qualité : défaut HIGH (la carte se juge en
    /// vrai) ; `-luneForgeQualite low|medium` pour les tours d'essai.
    static func forger() async throws -> Carte {
        guard let cle = cle() else { throw Erreur.cle }
        // `-luneForgeFamille <nom>` force une famille (fouettage d'un
        // registre précis, curation du pool) ; sinon, la surprise.
        let famille: Famille
        if let voulu = UserDefaults.standard.string(forKey: "luneForgeFamille"),
           let f = familles.first(where: {
               $0.nom.range(of: voulu, options: [.caseInsensitive,
                                                 .diacriticInsensitive]) != nil
           }) {
            famille = f
        } else {
            famille = familles.randomElement()!
        }

        let scene = try await directeur(famille: famille, cle: cle)
        let brut = try await peintre(prompt: scene + rappel, cle: cle)
        guard let cadre = UIImage(named: "carte-cadre")
                ?? Bundle.main.path(forResource: "carte-cadre", ofType: "png")
                    .flatMap(UIImage.init(contentsOfFile:))
        else { throw Erreur.cadre }

        let (art, depth) = try habiller(illustration: brut,
                                        rarete: famille.rarete)
        let carte = Carte(art: art, depth: depth, famille: famille, scene: scene)
        archiver(carte)
        return carte
    }

    /// L'HABILLAGE — partagé entre la forge locale et ForgeServeur :
    /// l'illustration nue (du peintre ou du pool) devient une carte du
    /// set (cadre + lunes de rareté) avec sa depth v0.
    /// LE CADRE DES LÉGENDAIRES (28-08, verdict Kathryn : « pour les cartes
    /// légendaires pas de bordure orangée, c'est full noir avec un peu de
    /// blanc, très très premium »). Même forme au pixel près — le cadre est
    /// mesuré à la fenêtre d'illustration et au placement des lunes —, la
    /// braise seulement remplacée par un argent froid, cuit hors ligne par
    /// `tools/sacre/bake_cadre_legendaire.py`.
    static func nomDuCadre(_ rarete: String) -> String {
        rarete == "legendary" ? "carte-cadre-legendaire" : "carte-cadre"
    }

    static func habiller(illustration: UIImage,
                         rarete: String) throws -> (art: UIImage, depth: UIImage) {
        let nom = nomDuCadre(rarete)
        guard let cadre = UIImage(named: nom)
                ?? Bundle.main.path(forResource: nom, ofType: "png")
                    .flatMap(UIImage.init(contentsOfFile:))
        else { throw Erreur.cadre }
        return (composer(illustration: illustration, cadre: cadre,
                         rarete: rarete),
                depthV0())
    }

    /// GPT-5 invente la scène. Les modèles gpt-5 raisonnent : l'effort bas
    /// suffit largement pour une direction artistique, et un budget de
    /// sortie généreux évite le piège du raisonnement qui mange tout le
    /// `max_completion_tokens` (contenu vide sans erreur).
    private static func directeur(famille: Famille, cle: String) async throws -> String {
        var corps: [String: Any] = [
            "model": "gpt-5",
            "messages": [
                ["role": "system", "content": charte],
                ["role": "user", "content":
                    "Family « \(famille.nom) »: \(famille.brief)\n"
                    + "Hard constraints (non-negotiable): \(famille.dur)\n"
                    + (registres[famille.rarete] ?? "")],
            ],
            "max_completion_tokens": 2000,
            "reasoning_effort": "low",
        ]
        var data = try await poster("https://api.openai.com/v1/chat/completions",
                                    corps: corps, cle: cle, tolerer400: true)
        if data == nil {
            // Champ refusé par l'API du jour : on rejoue nu.
            corps.removeValue(forKey: "reasoning_effort")
            data = try await poster("https://api.openai.com/v1/chat/completions",
                                    corps: corps, cle: cle, tolerer400: false)
        }
        guard let data,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choix = (json["choices"] as? [[String: Any]])?.first,
              let message = choix["message"] as? [String: Any],
              let texte = message["content"] as? String,
              !texte.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { throw Erreur.reponse("directeur muet") }
        return texte.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// gpt-image-1 peint — par l'endpoint EDITS, avec deux RÉFÉRENCES :
    /// le glyphe du logo (la lune de CHAQUE carte est cette forme exacte,
    /// `input_fidelity high` pour qu'elle tienne) et carte-lune-1
    /// (l'ancrage de style — nuit tissée de braises). 1024×1536, le seul
    /// portrait de l'API — la fenêtre est découpée en aspect-fill au
    /// compositing. Qualité ÉLEVÉE par défaut (consigne Kathryn) —
    /// `-luneForgeQualite low|medium` pour les tours d'essai.
    private static func peintre(prompt: String, cle: String) async throws -> UIImage {
        let qualite = UserDefaults.standard.string(forKey: "luneForgeQualite")
            ?? "high"
        guard let logo = Bundle.main.url(forResource: "carte-logo-ref",
                                         withExtension: "png"),
              let ancre = Bundle.main.url(forResource: "carte-lune-1",
                                          withExtension: "png")
        else { throw Erreur.reference }

        let consigne = "Reference image 1 is the brand's moon glyph: paint "
            + "the moon in this card as EXACTLY this barbed-crescent shape, "
            + "integrated into the painting (halo, clouds may partly veil "
            + "it, a reflection may echo it) — never the icon tile itself, "
            + "only the crescent. Reference image 2 is the set's style "
            + "anchor card: match its palette of deep night grays woven "
            + "with dark ember-orange nuances and its painterly finish, "
            + "without copying its landscape. Scene: "

        let borne = "woop-forge-\(UUID().uuidString)"
        var corps = Data()
        func champ(_ nom: String, _ valeur: String) {
            corps.append(Data("--\(borne)\r\nContent-Disposition: form-data; name=\"\(nom)\"\r\n\r\n\(valeur)\r\n".utf8))
        }
        func fichier(_ url: URL) throws {
            // PIÈGE : Xcode convertit les PNG du bundle au format CgBI
            // propriétaire (« Invalid image file or mode », payé au banc).
            // UIImage sait le lire — on recode en PNG STANDARD à l'envoi.
            guard let ui = UIImage(contentsOfFile: url.path),
                  let octets = ui.pngData()
            else { throw Erreur.reference }
            corps.append(Data("--\(borne)\r\nContent-Disposition: form-data; name=\"image[]\"; filename=\"\(url.lastPathComponent)\"\r\nContent-Type: image/png\r\n\r\n".utf8))
            corps.append(octets)
            corps.append(Data("\r\n".utf8))
        }
        champ("model", "gpt-image-1")
        champ("prompt", consigne + prompt)
        champ("size", "1024x1536")
        champ("quality", qualite)
        champ("input_fidelity", "high")
        try fichier(logo)
        try fichier(ancre)
        corps.append(Data("--\(borne)--\r\n".utf8))

        var req = URLRequest(url: URL(string:
            "https://api.openai.com/v1/images/edits")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(cle)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(borne)",
                     forHTTPHeaderField: "Content-Type")
        req.httpBody = corps
        req.timeoutInterval = 300
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            let détail = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { $0 as? [String: Any] }
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? "HTTP \(code)"
            throw Erreur.reponse(détail)
        }
        guard let json = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
              let b64 = ((json["data"] as? [[String: Any]])?.first?["b64_json"])
                as? String,
              let png = Data(base64Encoded: b64),
              let image = UIImage(data: png)
        else { throw Erreur.image }
        return image
    }

    private static func poster(_ url: String, corps: [String: Any],
                               cle: String, tolerer400: Bool) async throws -> Data? {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(cle)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: corps)
        req.timeoutInterval = 240
        let (data, rep) = try await URLSession.shared.data(for: req)
        let code = (rep as? HTTPURLResponse)?.statusCode ?? 0
        if code == 400 && tolerer400 { return nil }
        guard (200..<300).contains(code) else {
            let détail = (try? JSONSerialization.jsonObject(with: data))
                .flatMap { $0 as? [String: Any] }
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String } ?? "HTTP \(code)"
            throw Erreur.reponse(détail)
        }
        return data
    }

    // MARK: Le compositing — l'illustration sous le cadre

    /// Le nombre de LUNES DE RARETÉ (en bas à gauche, posées par le code
    /// dans le template — jamais par l'IA) : 1 common · 2 rare · 3 epic ·
    /// 4 legendary.
    static let lunesRarete = ["common": 1, "rare": 2, "epic": 3,
                              "legendary": 4]

    private static func composer(illustration: UIImage, cadre: UIImage,
                                 rarete: String) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let win = CGRect(x: fenetre.origin.x * canvas.width,
                         y: fenetre.origin.y * canvas.height,
                         width: fenetre.width * canvas.width,
                         height: fenetre.height * canvas.height)
        return UIGraphicsImageRenderer(size: canvas, format: format)
            .image { ctx in
                UIColor.black.setFill()
                ctx.fill(CGRect(origin: .zero, size: canvas))
                // Aspect-fill dans la fenêtre : le 2:3 généré est plus
                // élancé que la fenêtre, l'excédent part en haut et en bas.
                let échelle = max(win.width / illustration.size.width,
                                  win.height / illustration.size.height)
                let taille = CGSize(width: illustration.size.width * échelle,
                                    height: illustration.size.height * échelle)
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: win)
                illustration.draw(in: CGRect(
                    x: win.midX - taille.width / 2,
                    y: win.midY - taille.height / 2,
                    width: taille.width, height: taille.height))
                ctx.cgContext.restoreGState()
                cadre.draw(in: CGRect(origin: .zero, size: canvas))
                lunes(dans: ctx.cgContext, rarete: rarete)
            }
    }

    /// Les petits croissants de rareté, dans la bande basse du cadre
    /// (sous l'octogone, à droite du chanfrein bas-gauche). Braise mate :
    /// la couleur des liserés, un souffle de halo, jamais néon.
    private static func lunes(dans ctx: CGContext, rarete: String) {
        let n = lunesRarete[rarete] ?? 1
        let r: CGFloat = 7
        let y: CGFloat = 1316
        // Les lunes suivent le CADRE, jamais l'inverse : une légendaire au
        // liseré d'argent qui garderait trois croissants de braise aurait
        // l'air d'un montage. Blanc froid, même valeur, même halo.
        let braise = rarete == "legendary"
            ? UIColor(red: 0.93, green: 0.95, blue: 1.0, alpha: 0.92)
            : UIColor(red: 1.0, green: 0.55, blue: 0.18, alpha: 0.92)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 4,
                      color: braise.withAlphaComponent(0.55).cgColor)
        ctx.setFillColor(braise.cgColor)
        for i in 0..<n {
            let c = CGPoint(x: 212 + CGFloat(i) * 24, y: y)
            let a = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            // Le croissant FIN du logo : le disque moins son jumeau décalé
            // vers le haut-droit (clip sur A, remplissage pair-impair).
            let b = a.offsetBy(dx: r * 0.42, dy: -r * 0.30)
            ctx.saveGState()
            ctx.addEllipse(in: a)
            ctx.clip()
            ctx.addEllipse(in: a)
            ctx.addEllipse(in: b)
            ctx.fillPath(using: .evenOdd)
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    // MARK: La depth v0 — la rampe qui suffit au voyage

    /// Rampe verticale DANS la fenêtre (haut = ciel 1,0 → bas = proche
    /// 0,10, le pivot 0,45 traversé aux deux tiers), 0,45 NEUTRE sous le
    /// cadre : au pivot, déplacement nul — les gardes analytiques du shader
    /// font le reste. La vraie depth par carte viendra avec le pool.
    private static func depthV0() -> UIImage {
        let taille = CGSize(width: canvas.width / 2, height: canvas.height / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: taille, format: format)
            .image { ctx in
                UIColor(white: 0.45, alpha: 1).setFill()
                ctx.fill(CGRect(origin: .zero, size: taille))
                let win = CGRect(x: fenetre.origin.x * taille.width,
                                 y: fenetre.origin.y * taille.height,
                                 width: fenetre.width * taille.width,
                                 height: fenetre.height * taille.height)
                let espace = CGColorSpaceCreateDeviceGray()
                let grad = CGGradient(
                    colorsSpace: espace,
                    colors: [CGColor(gray: 1.0, alpha: 1),
                             CGColor(gray: 0.72, alpha: 1),
                             CGColor(gray: 0.45, alpha: 1),
                             CGColor(gray: 0.10, alpha: 1)] as CFArray,
                    locations: [0, 0.38, 0.66, 1])!
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: win)
                ctx.cgContext.drawLinearGradient(
                    grad,
                    start: CGPoint(x: win.midX, y: win.minY),
                    end: CGPoint(x: win.midX, y: win.maxY),
                    options: [])
                ctx.cgContext.restoreGState()
            }
    }

    // MARK: L'archive — chaque carte forgée est gardée

    /// Le simulateur écrit dans le dossier durable du chantier : les tirages
    /// se jugent en planche, et les élues monteront au pool telles quelles.
    private static func archiver(_ carte: Carte) {
        #if targetEnvironment(simulator)
        let dossier = "/Users/kathryn/Downloads/woop-carte-lune/forge"
        try? FileManager.default.createDirectory(
            atPath: dossier, withIntermediateDirectories: true)
        let horodatage = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let nom = "\(horodatage)-\(carte.famille.rarete)"
        try? carte.art.pngData()?.write(
            to: URL(fileURLWithPath: "\(dossier)/\(nom).png"))
        try? carte.depth.pngData()?.write(
            to: URL(fileURLWithPath: "\(dossier)/\(nom)-depth.png"))
        try? "\(carte.famille.nom) [\(carte.famille.rarete)]\n\(carte.scene)\n"
            .write(toFile: "\(dossier)/\(nom).txt",
                   atomically: true, encoding: .utf8)
        #endif
    }
}
