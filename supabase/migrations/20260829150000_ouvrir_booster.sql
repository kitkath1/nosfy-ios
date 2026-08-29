-- ═══════════════════════════════════════════════════════════════════
-- OUVRIR UN SACHET — la pile de boosters cesse de ne faire que grossir
--
-- ⚠️⚠️ **`opened_at` N'ÉTAIT MIS À JOUR PAR AUCUNE LIGNE DU DÉPÔT.** Audit
-- du 29-08, vérifié par grep exhaustif sur `supabase/` : la colonne est
-- DÉCLARÉE (`booster_noir.sql:34`), INDEXÉE (`user_boosters_attente_idx …
-- where opened_at is null`), LUE par `etat_coffre()` — et les deux seuls
-- `insert` qui l'écrivent la posent à la NAISSANCE d'une ligne légendaire.
-- Aucun `update` nulle part.
--
-- Conséquence, le jour où le coffre lit le serveur : `boosters_or` compte
-- toutes les séances jamais faites **sans jamais rien retirer**. Le compteur
-- du coffre monterait indéfiniment, et le bouton OUVRIR resterait allumé
-- pour l'éternité — la même invariance que le `max(1, n − 1)` local qu'on
-- vient de tuer, mais côté serveur, où elle ne se voit pas en lisant l'app.
--
-- ⚠️ **ET LA FORGE N'A JAMAIS SU QUEL SACHET ELLE OUVRAIT.**
-- `BoosterLab:2260` appelle `ForgeServeur.tirer(jwt:)` sans `boosterId`. Deux
-- choses en découlaient : aucune idempotence d'ouverture, et — plus grave —
-- **la garantie « légendaire » du booster noir n'était jamais armée**, le
-- manège noir tirant exactement comme le jaune. Cette fonction rend l'id du
-- sachet consommé précisément pour que la forge puisse le sceller.
--
-- Analyse : ../../tools/coffre-v2/BACKEND-COFFRE.md
-- Écrans  : ../../docs/screens/coffre-rewards.md
-- ═══════════════════════════════════════════════════════════════════

-- ── LE PLUS ANCIEN SACHET NON OUVERT DE LA BONNE PILE ────────────────
--
-- ⚠️ **DEUX PILES QUI NE SE CROISENT JAMAIS** (verdict Kathryn : « on n'aura
-- jamais les deux ensemble »). `origine = 'legendaire'` d'un côté, tout le
-- reste de l'autre. Ouvrir un noir qui retirerait un jaune ferait fondre la
-- mauvaise pile sous les yeux de la joueuse — c'est déjà la règle du
-- décompte local (`WoopApp:1180`), elle devient celle du serveur.
--
-- ⚠️ **`for update skip locked`** : deux ouvertures simultanées (un double
-- tap, une reprise pendant que la première tourne) prendraient sinon LA MÊME
-- ligne, et l'une des deux consommerait un sachet déjà consommé. Avec le
-- saut, la seconde prend le suivant — ou n'en trouve aucun, ce qui est la
-- vérité.
--
-- ⚠️ **LE PLUS ANCIEN D'ABORD** (`obtained_at asc`) : une file, pas une
-- pile. Quelqu'un qui gagne un sachet par séance pendant un mois doit vider
-- ce qu'il a gagné en premier — sinon les plus vieux ne sortent jamais, et
-- le jour où l'origine d'un sachet vaudra quelque chose (un sachet de
-- chemin ne tire pas comme un sachet de séance), c'est le mauvais qui
-- s'ouvrirait.
create or replace function public.ouvrir_booster(
  p_legendaire boolean default false
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
begin
  select id into v_id
    from public.user_boosters
   where user_id = auth.uid()
     and opened_at is null
     and (case when p_legendaire then origine = 'legendaire'
                                 else origine <> 'legendaire' end)
   order by obtained_at asc
   limit 1
     for update skip locked;

  if v_id is null then
    -- ⚠️ **PAS UNE ERREUR, UN FAIT.** `claim_booster_legendaire` rend un 500
    -- sur une condition métier, et c'est une incohérence relevée le 29-08 :
    -- « je n'ai plus de sachet » n'est pas une panne, c'est une réponse. Un
    -- client qui doit lire un code HTTP pour savoir s'il lui reste des
    -- boosters ne peut pas distinguer ça d'un serveur tombé.
    return jsonb_build_object('ouvert', false, 'raison', 'aucun_sachet');
  end if;

  update public.user_boosters
     set opened_at = now()
   where id = v_id;

  return jsonb_build_object('ouvert', true, 'booster_id', v_id);
end $$;

revoke all on function public.ouvrir_booster(boolean) from public;
revoke all on function public.ouvrir_booster(boolean) from anon;
-- ⚠️ **LE `revoke ... from public` NE SUFFIT PAS SUR SUPABASE**, et ça a été
-- payé le 29-08 sur `roll_rare` : les default privileges accordent `execute`
-- NOMINATIVEMENT à `anon`, `authenticated` et `service_role`. Révoquer de
-- `PUBLIC` ne retire donc rien à `anon`, dont le grant est nominatif. Il
-- faut le nommer — d'où la ligne ci-dessus, qui n'est pas décorative.
--
-- Ici `authenticated` GARDE le droit : c'est le client qui ouvre ses propres
-- sachets, et la clause `user_id = auth.uid()` le borne à sa pile. Le pire
-- qu'un appel répété puisse faire est de vider SA propre réserve.
grant execute on function public.ouvrir_booster(boolean) to authenticated;
