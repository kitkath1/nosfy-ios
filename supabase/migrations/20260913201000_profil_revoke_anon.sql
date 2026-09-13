-- ════════════════════════════════════════════════════════════════════════
-- LE PROFIL N'EST PAS POUR L'ANONYME — 13-09, mesuré dans la foulée de
-- 20260913200000 : `POST /rest/v1/rpc/profil` avec la seule clé publiable
-- (sans jeton) rendait 200 {"erreur":"sans_session"} — inoffensif (aucune
-- donnée, `auth.uid()` est null), mais Postgres accorde EXECUTE à PUBLIC sur
-- toute fonction créée : le `grant … to authenticated` n'avait rien fermé.
-- Ici on ferme : seule une session peut appeler les trois fonctions.
-- ════════════════════════════════════════════════════════════════════════

revoke execute on function public.profil()                                          from public, anon;
revoke execute on function public.definir_profil(text, text, text, integer, boolean) from public, anon;
revoke execute on function public.choisir_exercices(text[])                         from public, anon;
