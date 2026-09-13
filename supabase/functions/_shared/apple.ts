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
