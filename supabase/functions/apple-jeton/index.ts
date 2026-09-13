// apple-jeton — l'authorizationCode d'Apple → un refresh token Apple, rangé pour
// le jour où la personne supprime son compte (13-09, plan compte C3).
//
// L'app l'appelle JUSTE APRÈS l'entrée Apple (le code vit 5 minutes, à usage
// unique), avec la session Supabase déjà adoptée : { "code": "<authorizationCode>" }.
// Une panne ici n'empêche pas d'entrer : l'app imprime et continue.
//
// Réponses : { ok: true } · { ok: false, raison: "sans_session" | "code_absent" |
// "cle_absente" | "apple_<status>" | "sans_refresh" }.

import { createClient } from "npm:@supabase/supabase-js@2";
import { APPLE_TOKEN, CLIENT_ID, appelApple, rejouerRevocations, secretApple } from "../_shared/apple.ts";

Deno.serve(async (req) => {
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: auth } = await admin.auth.getUser(jwt);
    const user = auth?.user;
    if (!user) return Response.json({ ok: false, raison: "sans_session" }, { status: 401 });

    const corps = await req.json().catch(() => ({}));
    const code = typeof corps?.code === "string" ? corps.code.trim() : "";
    if (!code) return Response.json({ ok: false, raison: "code_absent" }, { status: 400 });

    const secret = await secretApple();
    if (!secret) return Response.json({ ok: false, raison: "cle_absente" }, { status: 503 });

    const rep = await appelApple(APPLE_TOKEN, {
      client_id: CLIENT_ID, client_secret: secret, code, grant_type: "authorization_code",
    });
    if (!rep.ok) {
      const detail = (await rep.text()).slice(0, 200);
      return Response.json({ ok: false, raison: `apple_${rep.status}`, detail }, { status: 502 });
    }
    const json = await rep.json();
    const refresh = typeof json?.refresh_token === "string" ? json.refresh_token : "";
    if (!refresh) return Response.json({ ok: false, raison: "sans_refresh" }, { status: 502 });

    const { error } = await admin.from("apple_jetons")
      .upsert({ user_id: user.id, refresh_token: refresh, updated_at: new Date().toISOString() });
    if (error) return Response.json({ ok: false, raison: error.message }, { status: 500 });
    // Au passage : quelques révocations ratées d'autres comptes, si la clé est là.
    const rejeu = await rejouerRevocations(admin, 3).catch(() => undefined);
    return Response.json({ ok: true, rejeu });
  } catch (e) {
    return Response.json({ ok: false, raison: String((e as Error)?.message ?? e) }, { status: 500 });
  }
});
