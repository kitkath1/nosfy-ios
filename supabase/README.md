# Supabase Woop — l'architecture

Projet **Woop App** : `ytnnyjkramgiqyxdrkcu` · https://ytnnyjkramgiqyxdrkcu.supabase.co
(région eu-west-2, compte **PERSO**).

## LES DEUX COMPTES (le piège n° 1, payé le 14-08)

Il y a DEUX comptes Supabase sur cette machine :

    PRO (Axione)   jeton SUPABASE_ACCESS_TOKEN dans ~/.zshenv → le CLI
                   le RAMASSE EN SILENCE : `supabase login` répond
                   « logged in » et `projects list` sort THOR/AXIONE…
                   Woop n'y est PAS. Ne JAMAIS y toucher.
    PERSO          héberge Woop App. Son token vit dans
                   `.secrets/supabase-access-token` (gitignoré).

**La règle : toute commande Woop se préfixe** —

    SUPABASE_ACCESS_TOKEN=$(cat .secrets/supabase-access-token) supabase …

(jamais modifier ~/.zshenv : le compte pro en dépend.)

## Ce qui est en place (14-08-2026)

- CLI installé (brew, 2.114.0), `supabase init` fait, **`link` fait**
  vers `ytnnyjkramgiqyxdrkcu` (voir `supabase/.temp/project-ref`).
- `.secrets/` (gitignoré, chmod 600) :
  `supabase-access-token` · `supabase.env` (URL + clé publishable
  `sb_publishable_…`, côté client) · `openai.key` (la forge des cartes).
- MCP hébergé (`.mcp.json`, scope projet) : OAuth compte perso. PIÈGE :
  en session VS Code non interactive il reste « auth requise » — passer
  par une session `claude` au terminal, ou par le CLI (préféré).

## Les migrations (vérifiées le 17-09)

`0001_init.sql` et `20260729120000_woop_schema.sql` avaient été appliquées au
DASHBOARD en juillet, donc inconnues de `schema_migrations` — d'où les deux
`migration repair --status applied` d'alors. **C'est fait** : le 17-09,
`supabase migration list --linked` rend 49 locales = 49 distantes, de `0001` à
`20260917184811`, rien en attente, rien d'orphelin. Le flux normal suffit :
nouveau fichier dans `migrations/` → `db push --linked`, et
`tools/serveur/verif_portes.py` recompare la liste à chaque passage.

Le jeton reste celui de `.secrets/supabase-access-token` (celui de `~/.zshenv`
voit un AUTRE projet). Lire l’ensemble des migrations : `0001` ne décrit pas
à elle seule le schéma vivant. `syntheses` a notamment été posée le 15-09.

## L'app aujourd'hui

Connexion native Apple uniquement dans le parcours public. Session Supabase
gardée au Keychain, renouvelée avant expiration. Les comptes par numéro et
le mot de passe dérivé ont été retirés ; le banc e-mail est limité à DEBUG.

`profil()` décide entre Nosfy et la home. `definir_profil` enregistre prénom,
langue, but, objectif et fin d’inscription ; un objectif hors bornes est refusé
avant toute écriture (migration `20260917184811`). L’app attend la confirmation,
garde les réponses en cas de panne et reprend l’inscription après relance.

Sync REST sans SDK (`SupabaseSync.swift`) : push des séances et pull par
`seances_depuis`, RLS par compte. Déconnexion : push puis révocation et nettoyage
local. Suppression : `supprimer-compte` efface l’identité et les données liées.
La clé Apple `.p8` manque encore pour vérifier la révocation chez Apple.

Preuves du parcours et limites :
[`tools/porte/preuves-2026-09-17/README.md`](../tools/porte/preuves-2026-09-17/README.md).
L’état détaillé est dans le [site local, Compte](http://localhost:3111/#porte).

## Le backend des cartes (EN PLACE depuis le 14-08 — voir tools/carte-lune/README.md)

État : migration `20260814180000_cartes_lune.sql` POUSSÉE (après le
`migration repair` des deux migrations de juillet), bucket `cards`
public créé, les 2 références du peintre uploadées dans
`cards/refs/`, la fonction `forge-card` DÉPLOYÉE avec
`OPENAI_API_KEY` en secret, et un tirage de bout en bout VÉRIFIÉ
(user de test `kat44426+woop-forge-test@gmail.com`, pool=1,
collection=1, PNG servi par l'URL publique). Réglages du tirage dans
forge-card : `PART_NEUF` 0,35 · poids 60/27/10/3. ATTENTION : la
partition des prompts y est une COPIE de LuneForge.swift — toute
évolution se réplique à la main. `.secrets/supabase-service-role`
contient la clé service_role (management API, jamais dans l'app).

Le principe : une génération IA n'est pas reproductible → toute carte
est une image STOCKÉE, canonique — c'est ce qui permet que deux users
retrouvent LES MÊMES cartes et comparent leurs collections.

    cards        le pool canonique du set Lune : famille, rareté (les 4
                 registres), scène/prompt, art, depth, créée le.
                 Lecture pour tous les comptes.
    user_cards   user_id · card_id · obtenue le · séance d'origine.
                 RLS par user — la collection.
    storage      bucket `cards` : les PNG (art 1086×1448 + depth).
    forge-card   Edge Function : LA CLÉ OPENAI VIT ICI (jamais dans
                 l'app) — `supabase secrets set OPENAI_API_KEY=…` ;
                 tirage pool-ou-neuf pondéré par rareté, gates de
                 charte, écriture cards + user_cards + storage.

Déploiement type :

    … supabase db push
    … supabase functions deploy forge-card
    … supabase secrets set OPENAI_API_KEY=$(cat .secrets/openai.key)

Le flow user (schéma complet dans tools/carte-lune/README.md) : fin de
séance → booster sur la home → « récupérer » appelle forge-card pendant
l'animation → ouverture → la carte sort → `user_cards` pour toujours.
