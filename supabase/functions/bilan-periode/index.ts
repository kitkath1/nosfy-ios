// LE BILAN ÉCRIT PAR L'IA — bilan-periode (15-09, étape 4b)
//
// Ce que la chambre des widgets attend sous son bilan (05-09) : « une phrase écrite
// par l'IA (“tes départs sont plus rapides, mais tes récups s'allongent”), un cache
// par période, un état de repli sans phrase, jamais un spinner ». Et la règle du
// 13-09 : un texte que le serveur sert NAÎT dans la langue du profil.
//
// Elle remplace `weekly-synthesis` (août, jamais déployée) qui attendait une clé
// Anthropic jamais posée, faisait confiance à un préfixe « Bearer » et laissait
// l'APP envoyer les chiffres. Ici :
//   · le JWT est VÉRIFIÉ (admin.auth.getUser) — 401 sans_session ;
//   · les chiffres viennent du SERVEUR : les quatre widget_* (volume, hiit,
//     regularite, peak) appelés AVEC LE JETON DE LA PERSONNE — les mêmes nombres
//     que la chambre, jamais un chiffre envoyé par le client ;
//   · la langue vient de `profils.langue` (fr par défaut) ;
//   · le cache est `syntheses` (une ligne par personne, période, fenêtre), réécrit
//     seulement quand le nombre de séances de la fenêtre a bougé ;
//   · le modèle : Claude (ANTHROPIC_API_KEY, claude-sonnet-5) s'il est nommé au
//     déploiement, sinon OpenAI (OPENAI_API_KEY, gpt-5 — la clé de la forge, déjà
//     là). Aucun des deux → 503 cle_absente, et l'app garde son repli sans phrase.
//
// POST { periode: "semaine" | "mois" } avec la session de la personne.
// Réponses : 200 { phrase, periode, debut, langue, seances, modele, cache }
//            401 sans_session · 400 periode_invalide · 503 cle_absente ·
//            502 modele_<status> / modele_muet · 200 { phrase: null, raison: "sans_seance" }
//            quand la fenêtre est vide (rien à dire, rien à inventer).

import { createClient } from "npm:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const anon = Deno.env.get("SUPABASE_ANON_KEY")!;

type Periode = "semaine" | "mois";

const CONSIGNE: Record<string, string> = {
  fr: `Tu écris la phrase du bilan d'une app de sport (Woop), sous les chiffres de la période.
Une ou deux phrases courtes, 200 caractères au plus, en français, tutoiement.
Appuie-toi sur UN ou DEUX chiffres présents dans les données (volume, séances, pic de vitesse,
efforts, record) — n'invente rien, ne cite pas de chiffre absent.
NE FAIS AUCUN CALCUL : les écarts sont déjà donnés (ecart_seances, reste_pour_objectif, delta_pct,
progression_kg) — recopie-les tels quels, ou ne les cite pas.
Compare à la période précédente quand un écart est fourni (« +12 % », « deux séances de plus »).
Pas de formule d'accueil, pas de liste, pas d'emoji, pas de guillemets, pas de titre.
Si la période est trop maigre, dis-le en une phrase simple.`,
  en: `You write the review line of a fitness app (Woop), shown under the period's numbers.
One or two short sentences, 200 characters max, in English, second person.
Lean on ONE or TWO numbers present in the data (volume, sessions, top speed, efforts, record)
— never invent a number that is not there.
DO NOT COMPUTE ANYTHING: the differences are already given (ecart_seances, reste_pour_objectif,
delta_pct, progression_kg) — quote them as they are, or leave them out.
Compare with the previous period when a difference is provided ("+12%", "two more sessions").
No greeting, no list, no emoji, no quotes, no title.
If the period is too thin, say so in one plain sentence.`,
};

Deno.serve(async (req) => {
  try {
    const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

    // Qui demande ? Le JWT de la personne, vérifié — plus jamais un préfixe.
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: auth } = await admin.auth.getUser(jwt);
    const user = auth?.user;
    if (!user) return Response.json({ raison: "sans_session" }, { status: 401 });

    const corps = await req.json().catch(() => ({}));
    const periode: Periode = corps.periode === "mois" ? "mois" : corps.periode === "semaine" || corps.periode == null ? "semaine" : "" as Periode;
    if (!periode) return Response.json({ raison: "periode_invalide" }, { status: 400 });

    // La langue du profil — la seule vérité (13-09) ; fr sans profil.
    const { data: profil } = await admin.from("profils").select("langue").eq("user_id", user.id).maybeSingle();
    const langue = profil?.langue === "en" ? "en" : "fr";

    // Les chiffres : les quatre widget_*, AVEC LE JETON DE LA PERSONNE (auth.uid()).
    const rpc = async (nom: string, args: Record<string, unknown>) => {
      const r = await fetch(`${url}/rest/v1/rpc/${nom}`, {
        method: "POST",
        headers: { apikey: anon, Authorization: `Bearer ${jwt}`, "Content-Type": "application/json" },
        body: JSON.stringify(args),
      });
      if (!r.ok) throw new Error(`${nom} ${r.status} ${await r.text()}`);
      return await r.json();
    };
    const [bornes, regularite, volume, hiit, peak] = await Promise.all([
      rpc("fenetre_bornes", { p_fenetre: periode }),
      rpc("widget_regularite", { p_fenetre: periode }),
      rpc("widget_volume", { p_fenetre: periode }),
      rpc("widget_hiit", { p_fenetre: periode }),
      rpc("widget_peak", { p_fenetre: periode }),
    ]);
    const debut = String((Array.isArray(bornes) ? bornes[0] : bornes)?.debut ?? "").slice(0, 10);
    const seances = Number(regularite?.faites ?? 0);
    if (!debut) return Response.json({ raison: "fenetre_illisible" }, { status: 500 });

    // Rien à dire sur une fenêtre vide — et rien à inventer (la loi du vide).
    if (seances === 0) {
      return Response.json({ phrase: null, raison: "sans_seance", periode, debut, langue, seances });
    }

    // Le cache : la même fenêtre, le même nombre de séances → la phrase stockée.
    const { data: deja } = await admin.from("syntheses")
      .select("contenu, modele, seances, langue")
      .eq("user_id", user.id).eq("periode", periode).eq("debut", debut).maybeSingle();
    if (deja && deja.seances === seances && deja.langue === langue) {
      return Response.json({ phrase: deja.contenu, periode, debut, langue, seances, modele: deja.modele, cache: true });
    }

    // Ce qu'on donne au modèle : un RÉSUMÉ nommé, pas les quatre réponses brutes
    // (10 Ko de jours et de segments qui l'égarent — mesuré : « 21 actions »).
    const meilleur = (peak?.pics ?? []).find((p: { nom?: string }) => p?.nom) ?? null;
    const exo = (volume?.exercices ?? [])[0] ?? null;
    const donnees = JSON.stringify({
      periode: periode === "mois" ? (langue === "en" ? "last 30 days" : "les 30 derniers jours") : (langue === "en" ? "this week" : "cette semaine"),
      seances: { faites: regularite?.faites, periode_precedente: regularite?.precedent,
                 ecart_seances: Number(regularite?.faites ?? 0) - Number(regularite?.precedent ?? 0),
                 objectif_hebdo: regularite?.objectif ?? null,
                 reste_pour_objectif: periode === "semaine" && regularite?.objectif != null
                   ? Math.max(Number(regularite.objectif) - Number(regularite?.faites ?? 0), 0) : null },
      volume_kg: { total: volume?.volume, periode_precedente: volume?.precedent, delta_pct: volume?.delta_pct, par_seance: volume?.par_seance,
                   exercice_le_plus_travaille: exo ? { nom: exo.nom, volume_kg: exo.volume } : null },
      cardio: { pic_vitesse_kmh: hiit?.pic, pic_precedent: hiit?.pic_precedent, efforts: hiit?.efforts, efforts_precedents: hiit?.efforts_precedent,
                temps_de_pics_s: hiit?.temps_pics, recup_moyenne_s: hiit?.recup_moy, recup_precedente_s: hiit?.recup_moy_precedent },
      records: { battus: peak?.records_battus, meilleur: meilleur ? { nom: meilleur.nom, charge_kg: meilleur.charge, progression_kg: meilleur.delta } : null,
                 jours_depuis_le_dernier: peak?.depuis_record },
    });
    // Le modèle — Claude s'il est nommé, sinon la clé de la forge.
    const anthropic = Deno.env.get("ANTHROPIC_API_KEY");
    const openai = Deno.env.get("OPENAI_API_KEY");
    let phrase = "";
    let modele = "";
    if (anthropic) {
      modele = "claude-sonnet-5";
      const r = await fetch("https://api.anthropic.com/v1/messages", {
        method: "POST",
        headers: { "x-api-key": anthropic, "anthropic-version": "2023-06-01", "Content-Type": "application/json" },
        body: JSON.stringify({
          model: modele, max_tokens: 200, system: CONSIGNE[langue],
          messages: [{ role: "user", content: donnees }],
        }),
      });
      if (!r.ok) return Response.json({ raison: `modele_${r.status}`, detail: (await r.text()).slice(0, 200) }, { status: 502 });
      const j = await r.json();
      phrase = (j.content ?? []).filter((b: { type: string }) => b.type === "text").map((b: { text: string }) => b.text).join(" ").trim();
    } else if (openai) {
      modele = "gpt-5";
      const r = await fetch("https://api.openai.com/v1/chat/completions", {
        method: "POST",
        headers: { Authorization: `Bearer ${openai}`, "Content-Type": "application/json" },
        body: JSON.stringify({
          model: modele,
          messages: [{ role: "system", content: CONSIGNE[langue] }, { role: "user", content: donnees }],
          // ⚠️ mesuré le 15-09 : à 400 jetons, la réflexion de gpt-5 mangeait tout et la
          // réponse arrivait VIDE (modele_muet) ; « minimal » répond en 2-3 s sans réfléchir.
          max_completion_tokens: 1500,
          reasoning_effort: "minimal",
        }),
      });
      if (!r.ok) return Response.json({ raison: `modele_${r.status}`, detail: (await r.text()).slice(0, 200) }, { status: 502 });
      const j = await r.json();
      phrase = String(j.choices?.[0]?.message?.content ?? "").trim();
    } else {
      return Response.json({ raison: "cle_absente" }, { status: 503 });
    }
    phrase = phrase.replace(/^["«»\s]+|["«»\s]+$/g, "");
    if (!phrase) return Response.json({ raison: "modele_muet" }, { status: 502 });

    // Le cache s'écrit (service role : la table n'a aucune policy d'écriture).
    const { error } = await admin.from("syntheses").upsert({
      user_id: user.id, periode, debut, langue, seances, contenu: phrase, modele,
      updated_at: new Date().toISOString(),
    }, { onConflict: "user_id,periode,debut" });
    if (error) console.error("syntheses upsert", error);

    return Response.json({ phrase, periode, debut, langue, seances, modele, cache: false });
  } catch (e) {
    console.error("bilan-periode", e);
    return Response.json({ raison: "erreur", detail: String(e).slice(0, 200) }, { status: 500 });
  }
});
