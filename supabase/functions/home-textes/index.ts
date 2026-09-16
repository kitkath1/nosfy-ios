// Génération éditoriale en lots. JAMAIS appelée par le téléphone ou par home().
// Deux modes administrateur : générer un brouillon, puis publier les deux lots
// relus en une seule écriture. Une erreur laisse le catalogue courant intact.
import { assembler, consigne, SCHEMA, valider } from "./contrat.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const secret = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req: Request) => {
  // Le gateway vérifie le JWT. Auth vérifie ensuite le droit administrateur
  // dans CE projet ; comparer un JWT reçu à la chaîne injectée dans l'Edge
  // n'est pas fiable avec les différentes clés de service du projet.
  // On ne lit ni ne conserve le corps de la réponse (aucune donnée utilisateur).
  const authorization = req.headers.get("Authorization");
  if (!secret || !authorization?.startsWith("Bearer ")) {
    return Response.json({ raison: "administrateur_requis" }, { status: 401 });
  }
  let autorise = false;
  try {
    const droit = await fetch(`${url}/auth/v1/admin/users?page=1&per_page=1`, {
      headers: { apikey: secret, Authorization: authorization }, signal: AbortSignal.timeout(5000),
    });
    autorise = droit.ok;
    await droit.body?.cancel();
  } catch { /* Refus fermé si la vérification n'est pas disponible. */ }
  if (!autorise) return Response.json({ raison: "administrateur_requis" }, { status: 401 });
  if (req.method !== "POST") return Response.json({ raison: "methode" }, { status: 405 });
  try {
    const body = await req.json();
    if (body.action === "publier") {
      if (!Array.isArray(body.lots) || body.lots.length !== 2) throw new Error("deux_langues_requises");
      const revision = String(body.revision ?? "");
      if (!/^[a-zA-Z0-9._-]{1,64}$/.test(revision)) throw new Error("revision_invalide");
      const lots = (["fr", "en"] as const).map(langue => {
        const lot = body.lots.find((x: { langue?: string }) => x.langue === langue);
        return valider(lot?.variantes, langue, revision);
      });
      const response = await fetch(`${url}/rest/v1/home_textes_lots?on_conflict=langue`, {
        method: "POST", signal: AbortSignal.timeout(10000),
        headers: { apikey: secret, Authorization: `Bearer ${secret}`, "Content-Type": "application/json", Prefer: "resolution=merge-duplicates" },
        body: JSON.stringify(lots.map(lot => ({ langue: lot.langue, revision, contenu: lot, origine: "ia-relue", updated_at: new Date().toISOString() }))),
      });
      if (!response.ok) return Response.json({ raison: "publication_refusee" }, { status: 502 });
      return Response.json({ ok: true, revision, langues: ["fr", "en"] });
    }
    if (body.action !== "generer" || !["fr", "en"].includes(body.langue)) throw new Error("demande_invalide");
    const key = Deno.env.get("OPENAI_API_KEY");
    if (!key) return Response.json({ raison: "cle_absente" }, { status: 503 });
    const modele = Deno.env.get("HOME_TEXTES_MODEL") ?? "gpt-5";
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST", signal: AbortSignal.timeout(90000),
      headers: { Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ model: modele, reasoning_effort: "minimal", max_completion_tokens: 6500,
        messages: [{ role: "developer", content: consigne(body.langue) }],
        response_format: { type: "json_schema", json_schema: { name: "home_textes", strict: true, schema: SCHEMA } },
      }),
    });
    if (!response.ok) return Response.json({ raison: `modele_${response.status}` }, { status: 502 });
    const answer = await response.json();
    const message = answer.choices?.[0];
    if (message?.finish_reason !== "stop" || message.message?.refusal) throw new Error("generation_incomplete");
    const lot = valider(assembler(JSON.parse(message.message.content), body.langue), body.langue, `ia-${Date.now()}`);
    return Response.json({ lot, modele, publie: false });
  } catch (error) {
    const raison = error instanceof Error ? error.message : "erreur";
    // Aucune réponse du fournisseur ni secret dans les journaux/réponses.
    return Response.json({ raison: /^[a-z_0-9]+$/.test(raison) ? raison : "lot_invalide" }, { status: 400 });
  }
});
