-- ═══════════════════════════════════════════════════════════════════════════
-- LE CHEMIN PEUT ENFIN DIRE CE QU'IL A DÉJÀ PAYÉ
-- ═══════════════════════════════════════════════════════════════════════════
--
-- VERDICT APPLIQUÉ (29-08, audit de la card ROUTE de la home) : « après une
-- réinstallation, la card propose une récompense déjà payée ». Le serveur
-- refuse de payer deux fois — les deux index le tiennent — mais **l'écran
-- ment**, et un écran qui ment sur un cadeau est pire qu'un cadeau perdu.
--
-- Analyse : docs/screens/duolingo-chemin.md § 7.5, et l'onglet « 1 · Le flow »
-- du site (docs/site/index.html), section « La card ROUTE de la home ».
--
-- LE FAIT : le serveur SAIT déjà quels nœuds ont payé —
-- `coin_ledger.noeud_id` (raison 'chemin') et `user_boosters.noeud_id`
-- (origine 'chemin'), chacun sous un index unique partiel posé le 28-08. Il ne
-- savait pas le DIRE : aucune des treize fonctions ne rendait ces nœuds, donc
-- l'app ne pouvait relire que son `UserDefaults` (`chemin.reclamees`) — qui se
-- remet à zéro à la réinstallation. C'est exactement la loi de la maison :
-- l'idempotence est un index, jamais un compteur ; ici l'index tient l'argent,
-- et c'est l'affichage qui restait local.
--
-- CETTE MIGRATION N'AJOUTE NI TABLE, NI COLONNE, NI INDEX. Elle ouvre une
-- LECTURE sur ce qui existe déjà — donc elle ne peut rien casser à la pose, et
-- rien ne dépend d'elle tant que le client ne l'appelle pas.
-- ═══════════════════════════════════════════════════════════════════════════

create or replace function public.noeuds_chemin_reclames()
returns table (noeud_id integer)
language sql
stable
security definer
set search_path = public
as $$
  -- ⚠️ `union` ET NON `union all` : un même nœud peut avoir payé DEUX fois,
  -- dans deux tables (des pièces ET un sachet — c'est le cas de la lune de fin
  -- de chapitre). Ce qu'on rend est un ENSEMBLE de nœuds, pas une liste de
  -- paiements : le doublon serait un mensonge de plus.
  --
  -- ⚠️ Chaque colonne est TYPÉE, même sans littéral : dans un `union` rendu
  -- par une `returns table`, une résolution ambiguë échoue à la CRÉATION de la
  -- fonction, pas à l'appel — et c'est le genre d'échec qu'on découvre le soir
  -- du déploiement.
  select cl.noeud_id::integer
    from public.coin_ledger cl
   where cl.user_id = auth.uid()
     and cl.raison  = 'chemin'
     and cl.noeud_id is not null
  union
  select ub.noeud_id::integer
    from public.user_boosters ub
   where ub.user_id = auth.uid()
     and ub.origine = 'chemin'
     and ub.noeud_id is not null
$$;

-- `security definer` + `search_path` fixé : la fonction ne lit QUE les lignes
-- de l'appelant (`auth.uid()`), jamais celles d'un autre — la clause vaut RLS
-- ici, puisque c'est elle qui filtre.
grant execute on function public.noeuds_chemin_reclames() to authenticated;
