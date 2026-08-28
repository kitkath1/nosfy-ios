// LA FORGE CÔTÉ SERVEUR — forge-card
//
// Le flow de récompense : fin de séance → l'app appelle forge-card
// pendant l'animation du booster → tirage POOL-OU-NEUF → la carte sort,
// et elle est au user pour toujours (user_cards).
//
// La clé OpenAI vit ICI (secret OPENAI_API_KEY) — jamais dans l'app.
// Écritures cards/user_cards/storage en service_role : le client ne
// peut RIEN écrire lui-même (défaut-refus RLS).
//
// SOURCE DE VÉRITÉ DES PROMPTS : Woop/Services/LuneForge.swift (et
// tools/carte-lune/PROMPTS.md) — toute évolution de la partition se
// réplique ici à la main. La partition ci-dessous = état du 14-08-2026.

import { createClient } from "npm:@supabase/supabase-js@2";

// ── La partition (copie conforme de LuneForge.swift) ────────────────

const CHARTE = `You are the art director of « Lune », a collector-card set for a premium fitness app. Every card is a vertical illustration that will live inside the same fixed black frame, added later by code — so NEVER draw a frame, border, card edge, text, letters, numbers, logo or watermark.

The set's soul, non-negotiable:
- Deep night, but the card must READ. Every subject is sculpted by a visible light: a moonlight rim, a cold gray sky gradient, a faint atmospheric sheen. Blacks are deep, yet silhouettes always separate cleanly from the background by VALUE — a subject must never sink into the void. Poetic and quietly disquieting — never horror, never gore, never occult or mystical symbols.
- The style anchor of the set (card #1): a night valley in stacked planes — tiered pine ridges descending toward a misty river, sculpted dark clouds parting around a thin orange crescent moon, one warm ember glow at the far horizon, everything else deep warm blacks and cold grays with real value range. Landscape families inherit this DNA.
- THE MOON IS THE SIGNATURE. Every single card carries the BRAND'S moon: a fine barbed-hook crescent (the painter receives the exact glyph as a reference image — always call it "the logo crescent"). Sometimes tiny and lost, sometimes huge, sometimes half-veiled by sculpted clouds or echoed in a reflection, but ALWAYS present.
- The palette is a DUO of nuances, like the anchor card: deep night grays and warm near-blacks WOVEN with dark ember-orange nuances — in cloud bellies, on a horizon, in a reflection. The ember is deep and dark, never bright neon, never yellow; it breathes through the matter of the scene but NEVER becomes an orange fog, haze or glow wash. Values stay readable — never flat pure black.
- Some cards are spectacular, others minimalist — both are right, but minimal never means invisible: even the emptiest card keeps a readable luminous structure. Think of the image seen small, as a card held in a hand: values must carry at a glance.
- Cinematic matte-painting realism: crisp silhouettes, sculpted shadows. No cartoon, no neon kitsch, no fantasy clutter.
- EVERY register is painted at the same masterwork level of detail and finish — sumptuous sculpted clouds, readable textures, layered atmospheric depth. The anchor card's craft is the set's FLOOR: registers change what is STAGED, never the quality of the painting.
- Vertical 2:3. Keep the essential subject in the central safe zone: nothing important in the outer 12% of the image, nor in the top-left medallion area (top fifth of the left half) — the frame overlaps there.

Given a family brief and its hard constraints, invent ONE surprising, specific scene inside that family, with a bold composition. Answer with the final image-generation prompt only — one dense paragraph in English that walks the scene PLANE BY PLANE (foreground, middle ground, far distance — matter and light for each), then places the logo crescent and says where the dark-ember nuances breathe. No preamble, no quotes.`;

const REGISTRES: Record<string, string> = {
  common: "Register COMMON — a calm, simple SUBJECT painted at full masterwork level: the ordinary night of the set rendered sumptuously — layered pine ridges with readable treetops, sculpted dark clouds with faint ember under-lighting, soft atmospheric mist between planes, the fine crescent placed quietly. Simplicity lives in the composition, NEVER in the craft.",
  rare: "Register RARE — the night plus ONE remarkable presence (creature, reflection, graphic close-up), staged with elegance in front of a fully painted backdrop: detailed sky architecture, tiered landscape depth, the presence sculpted by cold rim light with readable texture (fur, feathers, water). The anchor card's level of finish is the FLOOR here — luminous, never a void.",
  epic: "Register EPIC — the sky takes the stage: blood moons, burning skies, immense winged silhouettes — grand atmospheric drama: towering sculpted cloudscapes with dark ember cores, layered light gradients from deep black to dark ember, landscape tiers dwarfed below. Visibly richer and more intense than RARE, still controlled — never kitsch.",
  legendary: "Register LEGENDARY — the FULL-ART opera, visibly ABOVE every other register: an overflowing masterwork — foreground, middle ground and far distance all richly detailed, monumental cloud architecture, choreographed moonlight touching every plane, painterly density worthy of a collector artwork. The central figure (creature, or the moon itself) is SHINY: lacquered, lustrous, magnificent — polished-obsidian material, iridescent micro-highlights catching the moonlight, an ember rim gliding over scales, feathers or fur. Splendor comes from MATERIAL, never from rainbow colors: the palette stays the night/dark-ember duo. Abundant and extraordinary at first glance — never minimal, never empty.",
};

const CONSIGNE_REFS = "Reference image 1 is the brand's moon glyph: paint the moon in this card as EXACTLY this barbed-crescent shape, integrated into the painting (halo, clouds may partly veil it, a reflection may echo it) — never the icon tile itself, only the crescent. Reference image 2 is the set's style anchor card: match its palette of deep night grays woven with dark ember-orange nuances and its painterly finish, without copying its landscape. Scene: ";

const RAPPEL = " Vertical 2:3 full-bleed illustration, cinematic matte painting realism, true deep blacks, the moon painted as EXACTLY the barbed-crescent logo glyph of the first reference image, night grays woven with deep dark ember nuances, no orange fog, no frame, no border, no text.";

type Famille = { nom: string; rarete: string; brief: string; dur: string };

const FAMILLES: Famille[] = [
  { nom: "Forêt de pins", rarete: "common", brief: "A very dark pine forest at night, dense black conifers, near-monochrome.", dur: "Rows of black spruce silhouettes in at least three depth tiers separated by faint mist; crowns readable against a graded night sky; the logo crescent small and quiet; ember allowed only in the moon and one distant horizon thread." },
  { nom: "Vallée noire", rarete: "common", brief: "A black valley almost entirely drowned in night, relief barely readable.", dur: "A deep valley readable through value steps only — each ridge a darker band; thin mist on the valley floor; the logo crescent faint above; at most one ember whisper at the far end." },
  { nom: "Petite lune perdue", rarete: "common", brief: "An extremely small orange moon lost in an immense pitch-black night.", dur: "A vast graded night sky occupying almost everything; the logo crescent TINY yet razor-sharp; the ground reduced to a low silhouette band; the emptiness stays luminous, never flat." },
  { nom: "Montagnes invisibles", rarete: "common", brief: "Mountains almost invisible in darkness, only the faintest ridge lines.", dur: "Massive ridge lines barely emerging by value, matte; the logo crescent half-veiled by a cloud; one dominant cold gradient; ember reduced to the moon alone." },
  { nom: "Zoom sur la lune", rarete: "rare", brief: "A very graphic extreme close-up of an orange crescent moon, almost abstract, logo-like purity.", dur: "The logo crescent HUGE and graphic, its barbed hook crisp; surface textured like brushed ember metal; background pure graded night with faint cloud veils crossing the horns." },
  { nom: "Lune néon sur ciel noir", rarete: "rare", brief: "An entirely black sky with only an orange moon whose light barely reflects somewhere below — no fog, the reflection is the only echo.", dur: "The logo crescent as the ONLY light source in a graded black sky; its reflection below (water, wet stone) is the single echo; no other light anywhere." },
  { nom: "Lac noir", rarete: "rare", brief: "A black lake with a subtle moon reflection, everything else darkness.", dur: "A still black lake as a mirror; the logo crescent's reflection broken by exactly one ripple; shorelines as layered silhouettes; mist at the far bank." },
  { nom: "Corbeaux", rarete: "rare", brief: "A few hyperrealistic black crows, only the faintest sheen on their feathers, near-total darkness.", dur: "One to three crows with feather texture readable in cold rim light; a gnarled perch with bark detail; a FULLY painted backdrop — tiered ridges, sculpted clouds; the logo crescent in the sky." },
  { nom: "Chauves-souris au ciel", rarete: "rare", brief: "Very elegant bat silhouettes crossing the night sky.", dur: "Bat silhouettes at varied depths crossing a sculpted cloud sky, wing membranes rim-lit; the logo crescent between clouds; a low landscape band grounding the scene." },
  { nom: "Rangée de chauves-souris", rarete: "rare", brief: "A small row of black bats perched close together, almost invisible in an extremely deep night.", dur: "A row of bats on a wire or branch, bodies sculpted by cold light, ears and claws readable; painted backdrop with tiered depth (hills, mist); the logo crescent present; one tiny ember echo allowed." },
  { nom: "Démon aux yeux d'ambre", rarete: "rare", brief: "A small entirely-black wolf-dog demon hidden in darkness — practically only its thin yellow-orange eyes are visible.", dur: "Near-dark, but the wolf-dog's silhouette separates from the void: muzzle, ears, shoulders hinted by faint cold rim; the thin amber eyes are the ember; the logo crescent faint in the sky; the background keeps readable structure." },
  { nom: "Lumière seule", rarete: "rare", brief: "The landscape almost completely disappears; only the moon's light structures the composition.", dur: "Moonlight as the architect: shafts and pools of cold light structuring a nearly dissolved landscape; the logo crescent visible as the source; ember nuance only where the light grazes." },
  { nom: "Forêt aux nuages", rarete: "rare", brief: "A sea of sculpted dark clouds resting on black pine tops, in the anchor's cloud language.", dur: "A sea of sculpted clouds with real volume and under-lighting resting on pine crowns; at least three cloud tiers; the logo crescent floating above; dark ember nuance in the cloud bellies." },
  { nom: "Rivière de braise", rarete: "rare", brief: "A tiered night valley where a thin river catches the only ember-orange thread of a distant horizon.", dur: "A tiered valley where the river is a thin ember thread catching the horizon glow; forests in layered silhouette; the logo crescent above; ember lives ONLY in river, horizon and moon." },
  { nom: "Dragon des ténèbres", rarete: "rare", brief: "A great pitch-black fire dragon almost swallowed by the night — smooth-skinned, bat-winged, only its flame-tipped tail truly glowing.", dur: "The dragon's DESIGN follows the classic fire-lizard starter body plan: bipedal, standing upright, SMOOTH skin (no scale texture), rounded belly, two backward-curving head horns, small arms, large bat wings, thick tail with a living flame at its tip. VERY black and matte, almost swallowed by darkness, separated from the void by a faint cold rim; the tail-flame is the main ember echo; fully painted backdrop with tiered depth; the logo crescent in the sky." },
  { nom: "Ciel de sang", rarete: "epic", brief: "A blood-red sky above a black forest.", dur: "The sky as a dark blood-red gradation with sculpted cloud volumes — no flat red; a black forest band below with readable crowns; the logo crescent pale against the red; no pure-black voids in the sky." },
  { nom: "Oiseau de braise", rarete: "epic", brief: "An immense black legendary bird of prey, phoenix-like silhouette, above a blood-red or black sky, a few ember-orange nuances caught in its feathers.", dur: "The bird immense, wing edges readable feather by feather; dark ember nuances caught in the plumage; a dramatic sculpted sky; the landscape dwarfed below; the logo crescent present." },
  { nom: "Lune de sang", rarete: "epic", brief: "A huge blood-red moon dominating the composition.", dur: "The moon huge and blood-dark — STILL the logo's barbed-crescent silhouette (a blood eclipse of the glyph), surface texture readable; sculpted clouds crossing it; landscape minimal below." },
  { nom: "Vallée de la lune", rarete: "epic", brief: "The mother family — the style anchor itself: a stacked night valley, tiered pine ridges descending to a misty river, sculpted clouds parting around a thin orange crescent.", dur: "The anchor's recipe verbatim: tiered pine ridges to a misty river, sculpted clouds parting around the logo crescent, one warm ember glow at the far horizon; nothing less than the anchor's density." },
  { nom: "Le démon en majesté", rarete: "legendary", brief: "The black wolf-dog demon staged in majesty WITHIN its landscape: a tall silhouette risen on a ridge of the anchor valley, thin amber eyes burning, layered forest and sculpted clouds all around.", dur: "Full-art: the demon tall on a ridge, silhouette detailed (fur edges, stance), amber eyes burning far; the valley layered in mist tiers around him; monumental clouds; the logo crescent placed with intent; ember nuances in eyes, sky and horizon." },
  { nom: "La vallée souveraine", rarete: "legendary", brief: "The anchor valley pushed to its summit: the most sumptuous stacked landscape of the set — grand cloud architecture, deep tiers of forest and mist, moonlight choreographed across every plane.", dur: "Full-art: five depth tiers minimum (foreground rock or branch, mid forests, river, far ridges, sky); monumental cloud architecture; moonlight touching every tier; ember nuances woven in clouds, river and horizon." },
  { nom: "L'oiseau souverain", rarete: "legendary", brief: "The immense black bird of prey in full majesty above the anchor valley, wings spanning the sky, ember nuances caught in its feathers, dark clouds parting in its wake.", dur: "Full-art: the full wingspan across the sky with detailed plumage; clouds parting in its wake; the valley below in layered depth; ember nuances in feathers and horizon; the logo crescent visible." },
  { nom: "Le dragon de braise", rarete: "legendary", brief: "A mighty fire dragon in full majesty over the anchor valley — the classic fire-lizard starter silhouette: bipedal, smooth-skinned, round-bellied, two horns, great bat wings, its thick tail ending in a living flame.", dur: "Full-art: the dragon's DESIGN follows the classic fire-lizard starter body plan — standing on two legs, small arms, rounded belly, two backward-curving head horns, large bat wings, thick tail with a living flame at its tip. The hide SMOOTH (no scale texture): black lacquered obsidian, SHINY with iridescent micro-highlights and an ember rim gliding over it; throat and belly warmed by inner ember light; fierce yet SIMPLE in form, zero clutter, zero fairy-tale; layered valley and monumental clouds around; the logo crescent present." },
  { nom: "Le cerf d'obsidienne", rarete: "legendary", brief: "A great black stag of obsidian standing in the anchor valley, the tips of its antlers glowing like embers.", dur: "Full-art: the stag SHINY — lacquered obsidian coat, iridescent micro-highlights, ember-glowing antler tips as the main echo; majestic and quietly disquieting, zero fairy-tale; tiered forest and mist around; the logo crescent in the sky." },
  { nom: "La lune souveraine", rarete: "legendary", brief: "The moon ITSELF as the character: the logo crescent colossal and shiny, clouds parting around it like a cathedral.", dur: "Full-art of the sky: the logo crescent COLOSSAL, lacquered ember material with readable surface texture and iridescent micro-highlights; monumental sculpted clouds parting around it; the landscape reduced to a low silhouette band; the exact opposite of the tiny lost moon." },
];

// ── Le tirage ───────────────────────────────────────────────────────

/// Part de cartes NEUVES dans les tirages (le reste sert le pool — c'est
/// lui qui fait le « on a la même ! » et qui tient les coûts).
const PART_NEUF = 0.35;

/// Les poids de rareté du tirage (le grain de la collection).
const POIDS: Record<string, number> = { common: 60, rare: 27, epic: 10, legendary: 3 };

function tireRarete(): string {
  const total = Object.values(POIDS).reduce((a, b) => a + b, 0);
  let d = Math.random() * total;
  for (const [r, p] of Object.entries(POIDS)) { d -= p; if (d <= 0) return r; }
  return "common";
}

// ── La forge ────────────────────────────────────────────────────────

async function directeur(f: Famille, cle: string): Promise<string> {
  const rep = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { Authorization: `Bearer ${cle}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "gpt-5",
      messages: [
        { role: "system", content: CHARTE },
        { role: "user", content: `Family « ${f.nom} »: ${f.brief}\nHard constraints (non-negotiable): ${f.dur}\n${REGISTRES[f.rarete] ?? ""}` },
      ],
      max_completion_tokens: 2000,
      reasoning_effort: "low",
    }),
  });
  if (!rep.ok) throw new Error(`directeur: ${await rep.text()}`);
  const json = await rep.json();
  const scene = json.choices?.[0]?.message?.content?.trim();
  if (!scene) throw new Error("directeur muet");
  return scene;
}

async function peintre(scene: string, refs: Blob[], cle: string): Promise<Uint8Array> {
  const form = new FormData();
  form.append("model", "gpt-image-1");
  form.append("prompt", CONSIGNE_REFS + scene + RAPPEL);
  form.append("size", "1024x1536");
  form.append("quality", "high");
  form.append("input_fidelity", "high");
  form.append("image[]", refs[0], "carte-logo-ref.png");
  form.append("image[]", refs[1], "carte-lune-1.png");
  const rep = await fetch("https://api.openai.com/v1/images/edits", {
    method: "POST",
    headers: { Authorization: `Bearer ${cle}` },
    body: form,
  });
  if (!rep.ok) throw new Error(`peintre: ${await rep.text()}`);
  const json = await rep.json();
  const b64 = json.data?.[0]?.b64_json;
  if (!b64) throw new Error("peintre muet");
  return Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
}

// ── Le service ──────────────────────────────────────────────────────

Deno.serve(async (req) => {
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Qui forge ? Le JWT du user, vérifié côté serveur.
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: auth } = await admin.auth.getUser(jwt);
    const user = auth?.user;
    if (!user) return Response.json({ error: "non connecté" }, { status: 401 });

    const corps = await req.json().catch(() => ({}));
    const workoutId = corps.workout_id ?? null;

    // ⚠️ LES MANETTES D'ATELIER SONT UNE PORTE OUVERTE, et le booster noir
    // la rend grave. `famille` et `force_new` laissent LE CLIENT choisir sa
    // carte : « La lune souveraine », à volonté, sans pièce noire. Le défaut
    // existe depuis le premier jour et ne se voyait pas — une légendaire
    // garantie n'a de valeur que si elle ne s'obtient pas autrement.
    //
    // Elles ne répondent donc plus qu'au compte d'ATELIER, nommé au
    // déploiement. `FORGE_DEV_USER` non renseigné = manettes fermées pour
    // tout le monde (et le banc `CarteLuneLab` perd ses leviers : c'est le
    // prix, et il se rend en une variable d'environnement).
    if (user.id !== Deno.env.get("FORGE_DEV_USER")) {
      delete corps.famille;
      delete corps.force_new;
    }

    // ── LE BOOSTER NOIR : la rareté vient du SERVEUR, jamais du client ──
    //
    // Le client envoie l'`id` de la réserve que `claim_booster_legendaire()`
    // vient de lui créer — RIEN D'AUTRE. C'est la fonction qui relit la
    // ligne, vérifie qu'elle appartient bien à l'appelant, et déduit de son
    // `origine` qu'il faut servir le registre légendaire. Un paramètre
    // `rarete` accepté du client serait la faille de tout le système : une
    // légendaire garantie est la seule certitude que l'app vende.
    //
    // Sans `booster_id`, RIEN NE CHANGE : la table peut ne pas exister
    // encore (migration 20260828120000 non appliquée), on ne l'interroge pas.
    const boosterId = typeof corps.booster_id === "string" ? corps.booster_id : null;
    let rareteImposee: string | null = null;
    if (boosterId) {
      const { data: b } = await admin.from("user_boosters")
        .select("id, origine, card_id")
        .eq("id", boosterId).eq("user_id", user.id).maybeSingle();
      if (!b) return Response.json({ error: "booster inconnu" }, { status: 404 });
      // IDEMPOTENCE : un sachet DÉJÀ scellé rend SA carte. Un double tap, un
      // réseau qui coupe, un retour arrière ne tirent jamais une deuxième
      // carte — c'est la garde de `claim_booster`, appliquée à la forge.
      if (b.card_id) {
        const { data: dejaLa } = await admin.from("cards")
          .select("*").eq("id", b.card_id).maybeSingle();
        if (dejaLa) {
          const { data: pubDeja } = admin.storage.from("cards")
            .getPublicUrl(dejaLa.art_path);
          return Response.json({
            card: {
              id: dejaLa.id, famille: dejaLa.famille, rarete: dejaLa.rarete,
              scene: dejaLa.scene, art_url: pubDeja.publicUrl, fraiche: false,
            },
          });
        }
      }
      if (b.origine === "legendaire") rareteImposee = "legendary";
    }

    // ── Pool ou neuf ?
    let carte: { id: string; famille: string; rarete: string; scene: string; art_path: string } | null = null;
    let fraiche = false;
    const forceNeuf = corps.force_new === true || typeof corps.famille === "string";

    if (!forceNeuf && Math.random() >= PART_NEUF) {
      const rarete = rareteImposee ?? tireRarete();
      const { data } = await admin.from("cards").select("*").eq("rarete", rarete);
      if (data && data.length > 0) carte = data[Math.floor(Math.random() * data.length)];
      // Pool vide pour cette rareté → on forgera une neuve de cette rareté.
      if (!carte) {
        const du = FAMILLES.filter((f) => f.rarete === rarete);
        corps.famille = du[Math.floor(Math.random() * du.length)].nom;
      }
    }

    // LA GARANTIE TIENT AUSSI SUR LE CHEMIN « NEUVE ». Sans cette ligne, le
    // tirage 35 % qui saute le pool forgeait une famille prise AU HASARD
    // dans les 25 — donc une commune, avec une pièce noire. La rareté
    // imposée doit borner LES DEUX chemins, pas seulement celui du pool.
    if (!carte && rareteImposee && typeof corps.famille !== "string") {
      const du = FAMILLES.filter((f) => f.rarete === rareteImposee);
      corps.famille = du[Math.floor(Math.random() * du.length)].nom;
    }

    if (!carte) {
      const cle = Deno.env.get("OPENAI_API_KEY");
      if (!cle) return Response.json({ error: "OPENAI_API_KEY absent" }, { status: 500 });

      const voulu = typeof corps.famille === "string" ? corps.famille.toLowerCase() : null;
      const famille = voulu
        ? FAMILLES.find((f) => f.nom.toLowerCase().includes(voulu)) ?? FAMILLES[Math.floor(Math.random() * FAMILLES.length)]
        : FAMILLES[Math.floor(Math.random() * FAMILLES.length)];

      const [logo, ancre] = await Promise.all([
        admin.storage.from("cards").download("refs/carte-logo-ref.png"),
        admin.storage.from("cards").download("refs/carte-lune-1.png"),
      ]);
      if (!logo.data || !ancre.data) return Response.json({ error: "références absentes du bucket" }, { status: 500 });

      const scene = await directeur(famille, cle);
      const png = await peintre(scene, [logo.data, ancre.data], cle);

      const id = crypto.randomUUID();
      const artPath = `art/${id}.png`;
      const up = await admin.storage.from("cards").upload(artPath, png, { contentType: "image/png" });
      if (up.error) throw up.error;

      const ins = await admin.from("cards")
        .insert({ id, famille: famille.nom, rarete: famille.rarete, scene, art_path: artPath })
        .select().single();
      if (ins.error) throw ins.error;
      carte = ins.data;
      fraiche = true;
    }

    // La carte entre dans la collection — pour toujours.
    const uc = await admin.from("user_cards")
      .insert({ user_id: user.id, card_id: carte!.id, workout_id: workoutId });
    if (uc.error) throw uc.error;

    // LE SCELLEMENT : le sachet porte désormais SA carte. C'est ce qui rend
    // l'idempotence ci-dessus vraie — sans lui, un rejeu retirerait.
    if (boosterId) {
      await admin.from("user_boosters")
        .update({ card_id: carte!.id })
        .eq("id", boosterId).eq("user_id", user.id).is("card_id", null);
    }

    const { data: pub } = admin.storage.from("cards").getPublicUrl(carte!.art_path);
    return Response.json({
      card: {
        id: carte!.id, famille: carte!.famille, rarete: carte!.rarete,
        scene: carte!.scene, art_url: pub.publicUrl, fraiche,
      },
    });
  } catch (e) {
    return Response.json({ error: String(e?.message ?? e) }, { status: 500 });
  }
});
