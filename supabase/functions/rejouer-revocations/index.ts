// rejouer-revocations — la maintenance des révocations Apple ratées (13-09 soir).
//
// Réservée au SERVICE ROLE (un cron, un script d'admin) : le jeton porté doit être
// celui du service role, pas celui d'une personne. Rejoue jusqu'à `max` lignes de
// `apple_revocations` sans `revoque_le` (défaut 50), rend le bilan.
//
// Réponses : 200 { ok: true, tentees, revoquees, echecs, raison? } · 401 sans jeton ·
// 403 si le jeton n'est pas le service role.

import { createClient } from "npm:@supabase/supabase-js@2";
import { rejouerRevocations } from "../_shared/apple.ts";

function roleDuJeton(jwt: string): string | null {
  try {
    const [, corps] = jwt.split(".");
    const json = JSON.parse(atob(corps.replace(/-/g, "+").replace(/_/g, "/")));
    return typeof json?.role === "string" ? json.role : null;
  } catch {
    return null;
  }
}

Deno.serve(async (req) => {
  try {
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "").trim();
    if (!jwt) return Response.json({ ok: false, raison: "sans_jeton" }, { status: 401 });
    if (roleDuJeton(jwt) !== "service_role") {
      return Response.json({ ok: false, raison: "service_role_requis" }, { status: 403 });
    }
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const corps = await req.json().catch(() => ({}));
    const max = Number.isInteger(corps?.max) && corps.max > 0 ? Math.min(corps.max, 200) : 50;
    const bilan = await rejouerRevocations(admin, max);
    return Response.json({ ok: true, ...bilan });
  } catch (e) {
    return Response.json({ ok: false, raison: String((e as Error)?.message ?? e) }, { status: 500 });
  }
});
