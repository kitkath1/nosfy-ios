// LA CLÉ APPLE, partagée par apple-jeton et supprimer-compte (13-09).
//
// Apple ne parle qu'à un serveur qui signe un « client secret » : un JWT ES256
// signé avec la clé privée .p8 « Sign in with Apple » du compte développeur.
// Les trois secrets, posés par `supabase secrets set` (jamais dans le dépôt) :
//   APPLE_TEAM_ID      — l'identifiant d'équipe (10 caractères)
//   APPLE_KEY_ID       — le Key ID de la clé .p8
//   APPLE_PRIVATE_KEY  — le contenu du fichier .p8 (PEM, retours à la ligne inclus)
// et, optionnel, APPLE_CLIENT_ID (défaut : le bundle id de l'app).
//
// Tant qu'ils manquent, `secretApple()` rend null et les deux fonctions le disent
// (`raison: cle_absente`) — la suppression, elle, marche sans (on efface quand même).

import { importPKCS8, SignJWT } from "npm:jose@5";

export const APPLE_TOKEN = "https://appleid.apple.com/auth/token";
export const APPLE_REVOKE = "https://appleid.apple.com/auth/revoke";
export const CLIENT_ID = Deno.env.get("APPLE_CLIENT_ID") ?? "fr.kathryn.woop";

export async function secretApple(): Promise<string | null> {
  const p8 = Deno.env.get("APPLE_PRIVATE_KEY");
  const kid = Deno.env.get("APPLE_KEY_ID");
  const team = Deno.env.get("APPLE_TEAM_ID");
  if (!p8 || !kid || !team) return null;
  const cle = await importPKCS8(p8.replace(/\\n/g, "\n"), "ES256");
  return await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid })
    .setIssuer(team)
    .setIssuedAt()
    .setExpirationTime("5m")
    .setAudience("https://appleid.apple.com")
    .setSubject(CLIENT_ID)
    .sign(cle);
}

/** Un appel « form » chez Apple (token ou revoke). */
export async function appelApple(url: string, champs: Record<string, string>): Promise<Response> {
  return await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams(champs),
  });
}

/// LE REJEU DES RÉVOCATIONS RATÉES (13-09 soir). Une révocation qui a échoué à la
/// suppression d'un compte dort dans `apple_revocations` (sans clé étrangère : la ligne
/// survit au compte). On la rejoue ici — depuis la fonction `rejouer-revocations`
/// (maintenance, service role) et, opportunément, à chaque entrée Apple et à chaque
/// suppression (quelques lignes au plus, pour ne pas ralentir la personne).
export type Rejeu = { tentees: number; revoquees: number; echecs: number; raison?: string };

// deno-lint-ignore no-explicit-any
export async function rejouerRevocations(admin: any, max = 5): Promise<Rejeu> {
  const { data: lignes } = await admin.from("apple_revocations")
    .select("id, refresh_token").is("revoque_le", null).order("cree_le").limit(max);
  if (!lignes?.length) return { tentees: 0, revoquees: 0, echecs: 0 };
  const secret = await secretApple();
  if (!secret) return { tentees: lignes.length, revoquees: 0, echecs: lignes.length, raison: "cle_absente" };
  let revoquees = 0, echecs = 0;
  for (const l of lignes) {
    const rep = await appelApple(APPLE_REVOKE, {
      client_id: CLIENT_ID, client_secret: secret, token: l.refresh_token, token_type_hint: "refresh_token",
    });
    if (rep.ok) {
      revoquees++;
      await admin.from("apple_revocations").update({ revoque_le: new Date().toISOString() }).eq("id", l.id);
    } else {
      echecs++;
      await admin.from("apple_revocations").update({ echec: `echec_${rep.status}` }).eq("id", l.id);
    }
  }
  return { tentees: lignes.length, revoquees, echecs };
}
