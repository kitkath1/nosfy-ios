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

## Les migrations (piège n° 2)

`supabase/migrations/` contient `0001_init.sql` et
`20260729120000_woop_schema.sql` — **appliquées au DASHBOARD en juillet**,
donc inconnues de `schema_migrations` côté serveur. AVANT tout premier
`db push` :

    … supabase migration repair --status applied 0001
    … supabase migration repair --status applied 20260729120000

Ensuite le flux normal : nouveau fichier dans `migrations/` → `db push`.

## L'app aujourd'hui

Sync REST maison sans SDK (`Woop/Services/SupabaseSync.swift`) : upsert
workouts / logged_exercises / strength_sets / cardio_phases, RLS par user.
Comptes par numéro (table `WoopConfig.accounts`, pas de signup libre).
Edge function `weekly-synthesis` : écrite, PAS déployée.

## Le backend des cartes (à construire — voir tools/carte-lune/README.md)

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
