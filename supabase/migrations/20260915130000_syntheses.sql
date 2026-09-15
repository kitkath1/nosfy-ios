-- ════════════════════════════════════════════════════════════════════════
-- SYNTHESES — la phrase du bilan, gardée une fois par fenêtre (15-09, étape 4b)
--
-- Le défaut (site : b-tb-syntheses ⚪ « la table n'est PAS au serveur », b-edge-weekly ⚪,
-- b-wd-phrase-ia ⚪) : `0001_init.sql:77` déclarait `syntheses` et n'a jamais été posée ;
-- `weekly-synthesis` (août) attendait une clé Anthropic jamais posée et un JWT jamais
-- vérifié ; et la chambre des widgets attend « une phrase écrite par l'IA sous le bilan,
-- un cache par période, un état de repli sans phrase, jamais un spinner » (05-09).
--
-- Cette table est le CACHE : une ligne par personne, par période (`semaine` | `mois`) et
-- par fenêtre (`debut`, la borne de fenetre_bornes — le lundi de la maison, ou J-30), dans
-- la langue du profil au moment où elle est née (la règle du 13-09 : un texte serveur naît
-- dans la langue du profil, l'app ne traduit jamais). Écrite par l'edge function
-- `bilan-periode` (service role) ; lue par la personne (RLS own, select seulement).
-- Une fenêtre en cours peut changer (une séance de plus) : `bilan-periode` réécrit la
-- phrase quand `seances` (le nombre de séances de la fenêtre au moment du calcul) a bougé
-- — sinon elle rend le stocké, sans rappeler le modèle.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.syntheses (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  periode     text not null check (periode in ('semaine', 'mois')),
  debut       date not null,
  langue      text not null default 'fr',
  -- le nombre de séances finies de la fenêtre quand la phrase est née : la clé du recalcul
  seances     integer not null default 0,
  contenu     text not null,
  modele      text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, periode, debut)
);

comment on table public.syntheses is
  'Le cache de la phrase du bilan (bilan-periode) : une par personne, période (semaine | mois) et fenêtre (debut), née dans la langue du profil ; réécrite quand le nombre de séances de la fenêtre change.';
comment on column public.syntheses.seances is
  'Séances finies dans la fenêtre au moment du calcul — si la fenêtre en compte plus aujourd''hui, bilan-periode réécrit la phrase.';

alter table public.syntheses enable row level security;
do $$ begin
  create policy "chacun lit ses bilans"
    on public.syntheses for select to authenticated
    using (auth.uid() = user_id);
exception when duplicate_object then null; end $$;
-- AUCUNE policy d'écriture : seule l'edge function (service role) écrit.

create index if not exists syntheses_user_idx on public.syntheses (user_id, periode, debut desc);
