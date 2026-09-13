-- ════════════════════════════════════════════════════════════════════════
-- LA SUPPRESSION DE COMPTE — la part serveur (13-09 soir, plan compte C3, sur son « go »)
--
-- L'App Store (règle 5.1.1 v) exige qu'une app qui entre par Apple RÉVOQUE les
-- jetons Sign in with Apple quand elle supprime le compte. Révoquer demande le
-- refresh token Apple, qu'on n'obtient qu'en échangeant l'`authorizationCode`
-- rendu à l'entrée (5 minutes, usage unique) — ce que Supabase ne fait pas dans
-- le flux id_token. Donc :
--
--  · `apple_jetons` : un refresh token Apple par compte, écrit par l'edge function
--    `apple-jeton` juste après l'entrée, lu par `supprimer-compte` pour révoquer.
--    RLS sans AUCUNE policy : ni anon ni authenticated ne peuvent la lire ou
--    l'écrire — seul le service role (les edge functions) y touche.
--  · `apple_revocations` : quand la révocation échoue chez Apple, on garde le
--    jeton ici (SANS clé étrangère : la ligne survit à l'effacement du compte)
--    pour la rejouer — le compte, lui, est effacé quand même : on ne laisse pas
--    une personne coincée avec un compte qu'elle veut détruire.
--
-- L'effacement lui-même : `auth.admin.deleteUser` (service role) → les 12 tables
-- `user_id` sont en `on delete cascade` (mesuré le 13-09), plus `apple_jetons`.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.apple_jetons (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
alter table public.apple_jetons enable row level security;
revoke all on table public.apple_jetons from anon, authenticated;
comment on table public.apple_jetons is
  'Le refresh token Sign in with Apple de chaque compte, obtenu par l''edge function apple-jeton (échange de l''authorizationCode à l''entrée). Sert UNIQUEMENT à révoquer chez Apple à la suppression du compte (supprimer-compte). Aucune policy : service role seul.';

create table if not exists public.apple_revocations (
  id            bigserial primary key,
  user_id       uuid not null,
  refresh_token text not null,
  echec         text not null,
  cree_le       timestamptz not null default now(),
  revoque_le    timestamptz
);
alter table public.apple_revocations enable row level security;
revoke all on table public.apple_revocations from anon, authenticated;
comment on table public.apple_revocations is
  'Les révocations Apple qui ont ÉCHOUÉ à la suppression d''un compte (sans clé étrangère : la ligne survit au compte). À rejouer (cron à venir) ; revoque_le posé quand c''est fait.';
