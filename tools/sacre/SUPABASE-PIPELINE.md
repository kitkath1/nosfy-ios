# LE BACK-END DU SACRE — les schémas et la pipeline

**Écrit le 15-08-2026, avant la session Supabase.** Ce document donne les
**schémas** (le SQL à écrire) et la **pipeline** (qui appelle quoi, dans
quel ordre, avec quelle garantie).

Le parcours qu'il sert : [PARCOURS-BOOSTER.md](PARCOURS-BOOSTER.md).
Ce qui manque, en clair : [SUPABASE-A-FAIRE.md](SUPABASE-A-FAIRE.md).

> **RÈGLE ABSOLUE — rien ne se fait sans Kathryn.** Pas de migration
> poussée, pas de fonction déployée, pas de table créée en autonome.
>
> **Piège de compte** — le MCP Supabase de la session pointe *AxioSense*
> (un autre projet). Le repo est lié au bon projet
> (`supabase/.temp/project-ref` = `ytnnyjkramgiqyxdrkcu`). **Passer par
> la CLI, jamais par le MCP.** Et le jeton du `~/.zshenv` est celui du
> compte PRO (Axione) : il ne doit pas servir à Woop.

---

## Ce qui existe déjà

`20260814180000_cartes_lune.sql` — **`cards`** (le pool canonique
partagé : famille, rareté, scène, art_path, depth_path — lisible par
tous, aucun insert client), **`user_cards`** (la collection : user_id,
card_id, obtained_at, workout_id — chacun lit la sienne), le **bucket
`cards`** public en lecture.

L'edge function **`forge-card`** (déployée, vérifiée) tire déjà la
rareté (`common 60 / rare 27 / epic 10 / legendary 3`), pioche le pool à
65 % ou forge du neuf à 35 %, génère, upload, insère `cards` **et**
`user_cards`, et rend l'URL publique.

**Ce qui lui manque, et qui est tout le sujet de ce document** : rien ne
la retient. Elle tire à **chaque appel**. Il n'existe ni booster, ni
solde, ni lecture de collection.

---

## ⚠️ ÉTAT AU 28-08-2026 — DEUX DES TROIS TABLES SONT EN LIGNE

Ce document a été écrit le 15-08 comme du SQL **à passer**. Il ne l'avait
jamais été : au 28-08 la base ne contenait que `cards` et `user_cards`.

Depuis, **deux migrations sont appliquées et vérifiées** :

| migration | ce qu'elle a créé |
| --- | --- |
| `20260828120000_booster_noir.sql` | **`user_boosters`** et **`coin_ledger`** aux schémas ci-dessous, plus `origine = 'legendaire'`, la colonne `currency`, `claim_booster_legendaire()` et l'index unique partiel qui interdit deux réserves ouvertes |
| `20260828160000_wallet_coffre.sql` | **`booster_progress`** (le report 0-99), **`reward_rules`** (les prix), `solde_argent()`, `etat_coffre()` |

**Deux amendements aux schémas écrits plus bas**, tenus par ces migrations :

1. `user_boosters.origine` accepte **`'legendaire'`** (le sachet du booster
   noir, créé au claim et non à la séance) ;
2. `coin_ledger` porte une colonne **`currency in ('yellow','silver')`** —
   deux monnaies, une colonne, deux soldes dérivés. La deuxième s'appelle
   **argent** (le dessin a tranché : la planche `piece-argent` mesure
   186 · 170 · 153 sur ses hautes lumières) et elle ouvre **le booster
   noir** — deux objets, deux noms.

**LE PRIX EST TRANCHÉ ET IL VIT EN BASE**, plus dans le code :
`reward_rules` porte `pieces_par_serie = 20`, `prix_booster = 100`,
`prix_booster_legendaire = 1`. La question ouverte du §2 ci-dessous est donc
close. `claim_booster` (le jaune) devra lire son prix là, comme le fait déjà
`claim_booster_legendaire`.

Reste à écrire de ce document : `gagner_booster`, `claim_booster` (le jaune),
`sceller_booster`, et la table `families`.

---

## LES TROIS TABLES À ÉCRIRE

### 1. `user_boosters` — les sachets gagnés, en attente, ouverts

C'est **la brique qui débloque tout le parcours** : elle remplit le
manège (§3), elle compte dans la pill (§7), elle survit à la fermeture de
l'app, et c'est elle qui interdit d'ouvrir deux fois le même sachet.

```sql
create table public.user_boosters (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  origine     text not null default 'seance'
              check (origine in ('seance', 'achat', 'cadeau')),
  workout_id  uuid,                       -- la séance qui l'a gagné
  obtained_at timestamptz not null default now(),
  opened_at   timestamptz,                -- null = il tourne sur le manège
  card_id     uuid references public.cards (id)   -- rempli à l'ouverture
);

-- UNE SÉANCE = UN BOOSTER, jamais deux. C'est cet index qui protège
-- contre la séance rejouée, la séance reprise et le multi-appareil.
create unique index user_boosters_seance_unique
  on public.user_boosters (user_id, workout_id)
  where workout_id is not null;

-- La requête du manège et de la pill.
create index user_boosters_attente_idx
  on public.user_boosters (user_id, obtained_at)
  where opened_at is null;

alter table public.user_boosters enable row level security;
create policy "chacun voit ses boosters"
  on public.user_boosters for select to authenticated
  using (auth.uid() = user_id);
-- AUCUNE policy d'insert/update client : tout passe par les fonctions.
```

### 2. `coin_ledger` — le grand livre des pièces

Aujourd'hui les pièces sont **calculées** (`CoffreFortPurse.coins`,
20 par série faite) : il n'existe aucun solde stocké, donc **on ne peut
rien débiter**. Un grand livre est la seule forme auditable : le solde
est la somme, et l'historique explique chaque mouvement.

```sql
create table public.coin_ledger (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  delta      integer not null check (delta <> 0),  -- +20 gain / -20 dépense
  raison     text not null
             check (raison in ('serie_faite', 'ouverture_booster',
                               'doublon', 'cadeau', 'annulation')),
  workout_id uuid,
  booster_id uuid references public.user_boosters (id),
  created_at timestamptz not null default now()
);

create index coin_ledger_user_idx on public.coin_ledger (user_id);

-- L'ANTI-DOUBLE-CRÉDIT : une séance ne crédite qu'une fois, même si la
-- sync la rejoue trois fois (mode avion, changement d'appareil).
create unique index coin_ledger_gain_unique
  on public.coin_ledger (user_id, raison, workout_id)
  where workout_id is not null and delta > 0;

alter table public.coin_ledger enable row level security;
create policy "chacun lit son grand livre"
  on public.coin_ledger for select to authenticated
  using (auth.uid() = user_id);
```

    solde = select coalesce(sum(delta), 0)
              from coin_ledger where user_id = auth.uid()

~~**À trancher ensemble** : le prix d'un booster~~ → **TRANCHÉ le 28-08 et
posé en base** : `reward_rules.prix_booster = 100` (conversion cumulée avec
report, §4 sexies de la note rewards), `prix_booster_legendaire = 1` pièce
d'argent. Reste ouvert : **si un doublon rembourse quelque chose**.

### 3. `families` — la source unique des 25 familles

Les familles et leurs raretés vivent **en double** (Deno + `LuneForge.
swift`), et les totaux des registres **en triple** (`ProfilLune.
registresProfil` affiche 4 / 11 / 4 / 6 en dur). Chaque ajout de famille
demanderait aujourd'hui trois modifications cohérentes.

```sql
create table public.families (
  nom    text primary key,
  rarete text not null
         check (rarete in ('common', 'rare', 'epic', 'legendary')),
  actif  boolean not null default true
);

alter table public.families enable row level security;
create policy "les familles sont publiques"
  on public.families for select to authenticated using (true);
```

Les totaux des registres deviennent alors un `count(*) group by rarete`,
et non plus trois constantes à tenir synchronisées à la main.

---

## LA PIPELINE — qui appelle quoi

```
  FIN DE SÉANCE                    OUVERTURE                    AFFICHAGE
  ─────────────                    ─────────                    ─────────
  finish()                         « Ouvrir un Booster »        page profil
     │                                    │                          │
     ▼                                    ▼                          ▼
  rpc gagner_booster(workout)       fn open-booster()         view ma_collection
     │  +20 pièces (ledger)               │                          │
     │  +1 sachet (user_boosters)         ├─ 1. claim_booster()  ◀── LA GARDE
     ▼                                    │      verrou + débit + réserve
  la pill affiche 1                       │                          │
                                          ├─ 2. tirage / forge       │
                                          │      (forge-card actuel) │
                                          │                          │
                                          └─ 3. sceller_booster()    │
                                                 user_cards + card_id
                                                        │            │
                                                        ▼            ▼
                                                  rareté, famille, art
                                                  nouvelle ou doublon
```

### Étape A — `gagner_booster(workout_id)`

Appelée à la fin d'une séance. Crédite les pièces **et** crée le sachet,
dans **une seule transaction**. Rejouable sans danger : les deux index
uniques ci-dessus absorbent les doublons (`on conflict do nothing`).
C'est ce qui rend le **mode avion** possible — l'app promet le booster
localement et rejoue l'appel au premier lancement connecté, autant de
fois qu'il le faut.

### Étape B — `claim_booster()` : **LA GARDE D'IDEMPOTENCE**

C'est le cœur. Sans elle, on peut appeler la forge en boucle et remplir
sa collection gratuitement. Elle fait, dans une transaction :

1. **verrouille** le plus ancien booster non ouvert
   (`for update skip locked` — le multi-appareil ne peut pas en prendre
   deux) ;
2. **vérifie le solde** et **écrit le débit** au grand livre ;
3. **marque `opened_at`** — le sachet est réservé, plus personne ne peut
   l'ouvrir ;
4. si le booster est **déjà ouvert et déjà scellé**, elle rend
   simplement sa carte : un retour en arrière, un réseau qui coupe, un
   double tap ne tirent **jamais** une deuxième carte.

```sql
create or replace function public.claim_booster(p_booster uuid default null)
returns public.user_boosters
language plpgsql security definer set search_path = public as $$
declare b public.user_boosters;
declare solde integer;
begin
  -- Le retour idempotent AVANT tout : déjà ouvert et scellé ? on rend.
  if p_booster is not null then
    select * into b from public.user_boosters
     where id = p_booster and user_id = auth.uid();
    if found and b.card_id is not null then return b; end if;
  end if;

  select * into b from public.user_boosters
   where user_id = auth.uid() and opened_at is null
     and (p_booster is null or id = p_booster)
   order by obtained_at
   for update skip locked
   limit 1;
  if not found then
    raise exception 'aucun booster disponible' using errcode = 'P0001';
  end if;

  select coalesce(sum(delta), 0) into solde
    from public.coin_ledger where user_id = auth.uid();
  if solde < 20 then
    raise exception 'pièces insuffisantes' using errcode = 'P0002';
  end if;

  insert into public.coin_ledger (user_id, delta, raison, booster_id)
    values (auth.uid(), -20, 'ouverture_booster', b.id);

  update public.user_boosters set opened_at = now()
   where id = b.id returning * into b;
  return b;
end $$;
```

### Étape C — le tirage, puis `sceller_booster(booster_id, card_id)`

Le tirage reste ce que fait déjà `forge-card` (rareté pondérée, pool ou
neuf, génération, upload). Une fois la carte connue : insert
`user_cards` **et** écriture de `card_id` sur le booster, ensemble.

**Si le tirage échoue** (OpenAI en panne, timeout) : on **relâche** —
`opened_at` revient à null et une ligne `annulation` de +20 rend les
pièces. Un sachet réservé sans carte est un bug visible (la pill compte
faux) : ne jamais le laisser dans cet état.

### Étape D — la lecture de la collection

Personne côté Swift ne lit `user_cards` : `CollectionLune`
([SacreAccueil.swift](../../Woop/Views/SacreAccueil.swift)) est un store
**en mémoire** qui meurt avec le process. C'est *le* vrai trou : la page
profil oublie tout au relancement.

```sql
create view public.ma_collection with (security_invoker = true) as
select c.id as card_id, c.famille, c.rarete, c.scene, c.art_path,
       min(uc.obtained_at)  as obtenue_le,   -- l'ORDRE des emplacements
       count(*)::int        as exemplaires   -- la pastille ×N des doublons
  from public.user_cards uc
  join public.cards c on c.id = uc.card_id
 where uc.user_id = auth.uid()
 group by c.id;
```

`min(obtained_at)` donne **l'ordre « à la suite »** des emplacements du
profil ; `exemplaires` donne la pastille des doublons. Côté app il faut
un `CollectionStore` (REST maison, dans l'idiome de `SupabaseSync.
swift`, sans SDK) **plus un cache disque par `card_id`** — sinon la page
profil retélécharge toute la collection à chaque affichage. Repli
pendant le téléchargement : le dos vide fait très bien l'affaire.

---

## L'ordre d'exécution de la session Supabase

1. **`user_boosters` + `gagner_booster`** — la brique qui débloque le
   parcours de bout en bout (le manège et la pill deviennent vrais).
2. **`claim_booster` + `sceller_booster`** — la garde d'idempotence
   greffée sur `forge-card`. Sans elle, tout le reste est décoratif.
3. **`ma_collection` + le `CollectionStore` + le cache d'images** — la
   page profil cesse d'oublier.
4. **`coin_ledger`** et le prix d'ouverture (à trancher).
5. **Le rattrapage hors-ligne** (la salle sans réseau).
6. **`families`** — la source unique, et les totaux des registres qui
   cessent d'être des constantes.

## Les points à trancher ensemble

- **Le prix** d'un booster, et ce que rapporte un **doublon**.
- Que se passe-t-il quand un **registre est complet** ?
- `depth_path` est **null partout** : l'app utilise sa depth analytique
  v0. On génère, ou on assume et on documente.
- Vérifier que la migration `20260814180000` est bien **poussée en
  remote** — ça n'a jamais été confirmé.
- L'auth du vrai flux : `ForgeServeur.jwtBanc()` est un JWT **de banc**,
  il faut la session du compte connecté.
- Un access token **perso** rangé dans `.secrets/supabase-access-token`
  (jamais celui du compte pro).
