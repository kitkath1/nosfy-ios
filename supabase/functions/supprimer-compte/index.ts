// supprimer-compte — « Supprimer mon compte », pour de vrai (13-09, plan compte C3).
//
// Appelée par l'app avec la session de la personne, sans corps. Dans l'ordre :
//  1. la RÉVOCATION chez Apple, si on tient son refresh token (apple_jetons) et la
//     clé .p8 — exigence App Store 5.1.1 (v). Un échec s'écrit dans
//     apple_revocations (à rejouer) et N'EMPÊCHE PAS l'effacement ;
//  2. l'EFFACEMENT : auth.admin.deleteUser → la cascade emporte les 12 tables
//     user_id (mesuré le 13-09) et apple_jetons.
// Immédiat et définitif (décision (b) du plan : pas de 30 jours de grâce).
//
// Réponse : { ok: true, revocation: "revoquee" | "aucun_jeton" | "cle_absente" |
// "echec_<status>", user_id } · { ok: false, raison } (401 sans session, 500 si
// l'effacement échoue — alors RIEN n'a été effacé).

import { createClient } from "npm:@supabase/supabase-js@2";
import { APPLE_REVOKE, CLIENT_ID, appelApple, secretApple } from "../_shared/apple.ts";

Deno.serve(async (req) => {
  try {
    const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
    const jwt = (req.headers.get("Authorization") ?? "").replace("Bearer ", "");
    const { data: auth } = await admin.auth.getUser(jwt);
    const user = auth?.user;
    if (!user) return Response.json({ ok: false, raison: "sans_session" }, { status: 401 });

    // 1. Apple
    let revocation = "aucun_jeton";
    const { data: ligne } = await admin.from("apple_jetons")
      .select("refresh_token").eq("user_id", user.id).maybeSingle();
    if (ligne?.refresh_token) {
      const secret = await secretApple();
      if (!secret) {
        revocation = "cle_absente";
        await admin.from("apple_revocations")
          .insert({ user_id: user.id, refresh_token: ligne.refresh_token, echec: "cle_absente" });
      } else {
        const rep = await appelApple(APPLE_REVOKE, {
          client_id: CLIENT_ID, client_secret: secret,
          token: ligne.refresh_token, token_type_hint: "refresh_token",
        });
        if (rep.ok) {
          revocation = "revoquee";
        } else {
          revocation = `echec_${rep.status}`;
          await admin.from("apple_revocations")
            .insert({ user_id: user.id, refresh_token: ligne.refresh_token, echec: revocation });
        }
      }
    }

    // 2. L'effacement — tout part par la cascade.
    const { error } = await admin.auth.admin.deleteUser(user.id);
    if (error) return Response.json({ ok: false, raison: error.message, revocation }, { status: 500 });
    return Response.json({ ok: true, revocation, user_id: user.id });
  } catch (e) {
    return Response.json({ ok: false, raison: String((e as Error)?.message ?? e) }, { status: 500 });
  }
});
