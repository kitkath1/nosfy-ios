# Les prompts de la forge — la partition complète

**Source de vérité : `Woop/Services/LuneForge.swift`** (ce fichier
documente l'état du 14-08-2026 soir — si le Swift change, ce fichier suit).

## L'anatomie d'un appel (qui dit quoi)

    CHARTE (system)  +  FAMILLE (brief + ARMATURE DURE)  +  REGISTRE
                     │
                     ▼   GPT-5 (reasoning_effort low, budget 2000)
             LA SCÈNE, plan par plan (premier plan / moyens / lointain)
                     │
                     ▼   + LA CONSIGNE DES RÉFÉRENCES + LE RAPPEL
             gpt-image-1 /v1/images/EDITS · 1024×1536 · high
             avec DEUX IMAGES DE RÉFÉRENCE (input_fidelity high) :
               1. carte-logo-ref.png — LE GLYPHE de la marque
               2. carte-lune-1.png — l'ancrage de style

La surprise vit dans UNE case : la scène. Tout le reste est une ARMATURE
dure — c'est elle qui fait que 50 cartes = une collection.

## LES RÉFÉRENCES DU PEINTRE (la loi du logo)

La lune de CHAQUE carte est le glyphe exact de la marque — le croissant
fin à pointe barbelée. Un prompt texte ne sait pas dicter une forme
vectorielle : le peintre reçoit donc le glyphe EN IMAGE
(`Woop/Media/carte-logo-ref.png`, copie de `logo_lumière.png` du bureau)
avec `input_fidelity high`. Consigne soudée en tête du prompt, verbatim :

> Reference image 1 is the brand's moon glyph: paint the moon in this
> card as EXACTLY this barbed-crescent shape, integrated into the
> painting (halo, clouds may partly veil it, a reflection may echo it) —
> never the icon tile itself, only the crescent. Reference image 2 is
> the set's style anchor card: match its palette of deep night grays
> woven with dark ember-orange nuances and its painterly finish,
> without copying its landscape. Scene: …

## LA CHARTE (system prompt, verbatim)

> You are the art director of « Lune », a collector-card set for a
> premium fitness app. Every card is a vertical illustration that will
> live inside the same fixed black frame, added later by code — so NEVER
> draw a frame, border, card edge, text, letters, numbers, logo or
> watermark.
>
> The set's soul, non-negotiable:
> - Deep night, but the card must READ. Every subject is sculpted by a
>   visible light: a moonlight rim, a cold gray sky gradient, a faint
>   atmospheric sheen. Blacks are deep, yet silhouettes always separate
>   cleanly from the background by VALUE — a subject must never sink
>   into the void. Poetic and quietly disquieting — never horror, never
>   gore, never occult or mystical symbols.
> - The style anchor of the set (card #1): a night valley in stacked
>   planes — tiered pine ridges descending toward a misty river,
>   sculpted dark clouds parting around a thin orange crescent moon, one
>   warm ember glow at the far horizon, everything else deep warm blacks
>   and cold grays with real value range. Landscape families inherit
>   this DNA.
> - THE MOON IS THE SIGNATURE. Every single card carries the BRAND'S
>   moon: a fine barbed-hook crescent (the painter receives the exact
>   glyph as a reference image — always call it "the logo crescent").
>   Sometimes tiny and lost, sometimes huge, sometimes half-veiled by
>   sculpted clouds or echoed in a reflection, but ALWAYS present.
> - The palette is a DUO of nuances, like the anchor card: deep night
>   grays and warm near-blacks WOVEN with dark ember-orange nuances —
>   in cloud bellies, on a horizon, in a reflection. The ember is deep
>   and dark, never bright neon, never yellow; it breathes through the
>   matter of the scene but NEVER becomes an orange fog, haze or glow
>   wash. Values stay readable — never flat pure black.
> - Some cards are spectacular, others minimalist — both are right, but
>   minimal never means invisible: even the emptiest card keeps a
>   readable luminous structure. Think of the image seen small, as a
>   card held in a hand: values must carry at a glance.
> - Cinematic matte-painting realism: crisp silhouettes, sculpted
>   shadows. No cartoon, no neon kitsch, no fantasy clutter.
> - EVERY register is painted at the same masterwork level of detail
>   and finish — sumptuous sculpted clouds, readable textures, layered
>   atmospheric depth. The anchor card's craft is the set's FLOOR:
>   registers change what is STAGED, never the quality of the painting.
> - Vertical 2:3. Keep the essential subject in the central safe zone:
>   nothing important in the outer 12% of the image, nor in the top-left
>   medallion area (top fifth of the left half) — the frame overlaps
>   there.
>
> Given a family brief and its hard constraints, invent ONE surprising,
> specific scene inside that family, with a bold composition. Answer
> with the final image-generation prompt only — one dense paragraph in
> English that walks the scene PLANE BY PLANE (foreground, middle
> ground, far distance — matter and light for each), then places the
> logo crescent and says where the dark-ember nuances breathe. No
> preamble, no quotes.

## LES 4 REGISTRES (la rareté est une mise en scène, verbatim)

**Leçon fondatrice : carte-lune-1 est le niveau d'une RARE.** Le
registre change ce qui est mis en scène, JAMAIS le niveau de peinture.

**common** — la nuit ordinaire, peinte en chef-d'œuvre :
> Register COMMON — a calm, simple SUBJECT painted at full masterwork
> level: the ordinary night of the set rendered sumptuously — layered
> pine ridges with readable treetops, sculpted dark clouds with faint
> ember under-lighting, soft atmospheric mist between planes, the fine
> crescent placed quietly. Simplicity lives in the composition, NEVER
> in the craft.

**rare** — la nuit + UNE présence :
> Register RARE — the night plus ONE remarkable presence (creature,
> reflection, graphic close-up), staged with elegance in front of a
> fully painted backdrop: detailed sky architecture, tiered landscape
> depth, the presence sculpted by cold rim light with readable texture
> (fur, feathers, water). The anchor card's level of finish is the
> FLOOR here — luminous, never a void.

**epic** — le ciel entre en scène :
> Register EPIC — the sky takes the stage: blood moons, burning skies,
> immense winged silhouettes — grand atmospheric drama: towering
> sculpted cloudscapes with dark ember cores, layered light gradients
> from deep black to dark ember, landscape tiers dwarfed below. Visibly
> richer and more intense than RARE, still controlled — never kitsch.

**legendary** — le FULL ART, l'opéra du set, et la matière SHINY :
> Register LEGENDARY — the FULL-ART opera, visibly ABOVE every other
> register: an overflowing masterwork — foreground, middle ground and
> far distance all richly detailed, monumental cloud architecture,
> choreographed moonlight touching every plane, painterly density
> worthy of a collector artwork. The central figure (creature, or the
> moon itself) is SHINY: lacquered, lustrous, magnificent —
> polished-obsidian material, iridescent micro-highlights catching the
> moonlight, an ember rim gliding over scales, feathers or fur.
> Splendor comes from MATERIAL, never from rainbow colors: the palette
> stays the night/dark-ember duo. Abundant and extraordinary at first
> glance — never minimal, never empty.

La règle shiny en une phrase : les créatures **rares sont MATES**
(sculptées par la lumière froide), les **legendary sont LAQUÉES**
(obsidienne polie, elles brillent de l'intérieur) — le vocabulaire
matière de l'app (galet laqué, verre noir de feu).

## LE RAPPEL (soudé à la fin du prompt du peintre, verbatim)

> Vertical 2:3 full-bleed illustration, cinematic matte painting
> realism, true deep blacks, the moon painted as EXACTLY the
> barbed-crescent logo glyph of the first reference image, night grays
> woven with deep dark ember nuances, no orange fog, no frame, no
> border, no text.

## LES 25 FAMILLES — brief + ARMATURE DURE

Chaque famille porte maintenant son armature (« Hard constraints »),
soudée au message du directeur : la recette qui ne se négocie pas.
GPT-5 n'improvise que la scène à l'intérieur.

### common
- **Forêt de pins** — *A very dark pine forest at night, dense black conifers, near-monochrome.*
  Armature : rows of black spruce silhouettes in ≥3 depth tiers separated by faint mist; crowns readable against a graded sky; the logo crescent small and quiet; ember only in the moon and one distant horizon thread.
- **Vallée noire** — *A black valley almost entirely drowned in night, relief barely readable.*
  Armature : valley readable through value steps only — each ridge a darker band; thin mist floor; crescent faint above; at most one ember whisper at the far end.
- **Petite lune perdue** — *An extremely small orange moon lost in an immense pitch-black night.*
  Armature : vast graded sky occupying almost everything; the logo crescent TINY yet razor-sharp; ground reduced to a low silhouette band; emptiness stays luminous, never flat.
- **Montagnes invisibles** — *Mountains almost invisible in darkness, only the faintest ridge lines.*
  Armature : massive ridges barely emerging by value, matte; crescent half-veiled by a cloud; one dominant cold gradient; ember reduced to the moon alone.

### rare
- **Zoom sur la lune** — *A very graphic extreme close-up of an orange crescent moon, almost abstract, logo-like purity.*
  Armature : the logo crescent HUGE and graphic, barbed hook crisp; surface like brushed ember metal; background pure graded night, faint cloud veils crossing the horns.
- **Lune néon sur ciel noir** — *An entirely black sky with only an orange moon whose light barely reflects somewhere below.*
  Armature : the crescent as the ONLY light source; its reflection below (water, wet stone) is the single echo; no other light anywhere.
- **Lac noir** — *A black lake with a subtle moon reflection, everything else darkness.*
  Armature : still lake as mirror; the crescent's reflection broken by exactly one ripple; shorelines as layered silhouettes; mist at the far bank.
- **Corbeaux** — *A few hyperrealistic black crows, faint sheen on their feathers.*
  Armature : 1-3 crows, feather texture readable in cold rim light; gnarled perch with bark detail; FULLY painted backdrop (tiered ridges, sculpted clouds); crescent in the sky.
- **Chauves-souris au ciel** — *Very elegant bat silhouettes crossing the night sky.*
  Armature : bats at varied depths crossing a sculpted cloud sky, membranes rim-lit; crescent between clouds; a low landscape band grounding the scene.
- **Rangée de chauves-souris** — *A small row of black bats perched close together.*
  Armature : a row of bats on a wire/branch, bodies sculpted by cold light, ears and claws readable; backdrop with tiered depth (hills, mist); crescent present; one tiny ember echo allowed.
- **Démon aux yeux d'ambre** — *An entirely-black wolf-dog demon, only its thin amber eyes visible.*
  Armature : near-dark but the silhouette separates (muzzle, ears, shoulders in faint cold rim); the amber eyes are the ember; crescent faint in the sky; background keeps readable structure.
- **Lumière seule** — *The landscape almost disappears; only the moon's light structures the composition.*
  Armature : moonlight as the architect — shafts and pools of cold light structuring a nearly dissolved landscape; the crescent visible as the source; ember only where the light grazes.
- **Forêt aux nuages** — *A sea of sculpted dark clouds resting on black pine tops.*
  Armature : cloud sea with real volume and under-lighting on pine crowns; ≥3 cloud tiers; crescent floating above; dark ember in the cloud bellies.
- **Rivière de braise** — *A tiered night valley where a thin river catches the ember thread of the horizon.*
  Armature : tiered valley, the river a thin ember thread; forests in layered silhouette; crescent above; ember ONLY in river, horizon and moon.
- **Dragon des ténèbres** — *A great pitch-black fire dragon almost swallowed by the night — smooth-skinned, only its flame-tipped tail truly glowing.*
  Armature : le GABARIT du starter feu classique — bipède debout, peau LISSE (pas d'écailles), ventre rond, deux cornes recourbées, petits bras, grandes ailes de chauve-souris, queue épaisse à flamme vivante. Very black and matte, separated from the void by a faint cold rim; the tail-flame is the main ember echo; fully painted backdrop; crescent in the sky.

### epic
- **Ciel de sang** — *A blood-red sky above a black forest.*
  Armature : dark blood-red gradation with sculpted cloud volumes, no flat red; black forest band with readable crowns; crescent pale against the red; no pure-black voids in the sky.
- **Oiseau de braise** — *An immense black bird of prey, phoenix-like, ember nuances in its feathers.*
  Armature : the bird immense, wing edges readable feather by feather; ember nuances in plumage; dramatic sculpted sky; landscape dwarfed; crescent present.
- **Lune de sang** — *A huge blood-red moon dominating the composition.*
  Armature : the moon huge and blood-dark — STILL the logo's barbed-crescent silhouette (a blood eclipse of the glyph), surface texture readable; sculpted clouds crossing it; landscape minimal.
- **Vallée de la lune** — *The mother family: the style anchor itself.*
  Armature : the anchor's recipe verbatim — tiered ridges to a misty river, sculpted clouds parting around the crescent, one warm ember at the horizon; nothing less than the anchor's density.

### legendary
- **Le démon en majesté** — *The demon staged in majesty WITHIN its landscape.*
  Armature : full-art — the demon tall on a ridge, silhouette detailed (fur edges, stance), amber eyes burning far; valley in mist tiers around; monumental clouds; crescent placed with intent; ember in eyes, sky, horizon.
- **La vallée souveraine** — *The anchor valley pushed to its summit.*
  Armature : full-art — ≥5 depth tiers (foreground rock/branch, mid forests, river, far ridges, sky); monumental cloud architecture; moonlight on every tier; ember woven in clouds, river, horizon.
- **L'oiseau souverain** — *The immense bird in full majesty above the anchor valley.*
  Armature : full-art — full wingspan across the sky, detailed plumage; clouds parting in its wake; valley below in layered depth; ember in feathers and horizon; crescent visible.
- **Le dragon de braise** — *A mighty fire dragon in full majesty — the classic fire-lizard starter silhouette, its thick tail ending in a living flame.*
  Armature : full-art — le GABARIT du starter feu classique (bipède, petits bras, ventre rond, deux cornes, grandes ailes, queue-flamme) ; peau LISSE sans écailles : obsidienne noire laquée, SHINY (micro-reflets iridescents, liseré de braise), gorge et ventre chauffés de l'intérieur ; féroce mais SIMPLE de forme, zéro fioritures ; vallée étagée et nuages monumentaux ; crescent present.
- **Le cerf d'obsidienne** — *A great black stag of obsidian, the tips of its antlers glowing like embers.*
  Armature : full-art — the stag SHINY (lacquered obsidian coat, iridescent micro-highlights); ember-glowing antler tips as the main echo; majestic, quietly disquieting, zero fairy-tale; tiered forest and mist; crescent in the sky.
- **La lune souveraine** — *The moon ITSELF as the character: the logo crescent colossal and shiny.*
  Armature : full-art of the sky — the logo crescent COLOSSAL, lacquered ember material, readable surface texture, iridescent micro-highlights; monumental clouds parting like a cathedral; landscape reduced to a low silhouette band; the exact opposite of the tiny lost moon.

Le démon a DEUX vies : rare (les yeux seuls) et legendary (en majesté) —
et le DRAGON aussi : rare (des ténèbres, tout noir mat) et legendary
(de braise, shiny laqué).

## Les lunes de rareté (posées par le code, jamais par l'IA)

En bas à gauche, dans la bande du cadre : 1 croissant (common) ·
2 (rare) · 3 (epic) · 4 (legendary). Braise mate, discrètes, enfilées
sur le liseré fin.
