// Les illustrations sont publiées en atelier. Un tirage n'appelle aucune IA.
// Auth, propriété, rareté, scellement et exemplaire sont vérifiés ensemble en SQL.
Deno.serve(async (req) => {
  if (req.method !== "POST") return Response.json({ error: "POST requis" }, { status: 405 });
  const jwt = req.headers.get("Authorization");
  if (!jwt?.startsWith("Bearer ")) return Response.json({ error: "non connecté" }, { status: 401 });
  const body = await req.json().catch(() => null);
  const id = body?.booster_id;
  if (typeof id !== "string" || !/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(id)) {
    return Response.json({ error: "sachet requis" }, { status: 400 });
  }
  const url = Deno.env.get("SUPABASE_URL")!;
  const headers = { "Authorization": jwt, "apikey": Deno.env.get("SUPABASE_ANON_KEY")!, "Content-Type": "application/json" };
  try {
    const response = await fetch(`${url}/rest/v1/rpc/attribuer_carte`, {
      method: "POST", headers, body: JSON.stringify({ p_booster: id }),
    });
    const result = await response.json();
    if (!response.ok) return Response.json({ error: result.message ?? "attribution indisponible" }, { status: response.status });
    result.card.art_url = `${url}/storage/v1/object/public/cards/${result.card.art_path.split("/").map(encodeURIComponent).join("/")}`;
    // Les clients antérieurs ne savent pas acquitter la réception de l'image.
    // Le contrat2 garde le sachet reprenable jusqu'à confirmer_revelation.
    if (body.contract_version !== 2) {
      const confirmed = await fetch(`${url}/rest/v1/rpc/confirmer_revelation`, {
        method: "POST", headers, body: JSON.stringify({ p_booster: id }),
      });
      if (confirmed.ok) result.coffre = await confirmed.json();
    }
    return Response.json(result);
  } catch {
    return Response.json({ error: "attribution indisponible, reprendre le même sachet" }, { status: 503 });
  }
});
