-- ════════════════════════════════════════════════════════════════════════
-- `fuseau_jour()` RAPIDE — le correctif du 13-09
--
-- MESURÉ le 13-09 sur le compte de test, avec 23 séances et 88 séries :
-- `widget_volume('semaine')` → 57014 « canceling statement due to statement
-- timeout » (12,7 s au chronomètre depuis le rôle postgres). Le bloc du
-- record de semaine seul : 8 324 ms, pour 88 lignes.
--
-- La cause : `fuseau_jour()` validait le fuseau par
--   exists (select 1 from pg_timezone_names t where t.name = …)
-- et `pg_timezone_names` est une vue qui ÉNUMÈRE LES FICHIERS de fuseaux à
-- chaque lecture (~95 ms). Comme la fonction est STABLE (pas IMMUTABLE), un
-- `group by date_trunc('week', w.started_at at time zone public.fuseau_jour())`
-- l'évalue par ligne : 88 × 95 ms. Trois fonctions l'appellent dans leurs
-- requêtes (`widget_volume`, `widget_hiit`, `widget_peak`) ; la quatrième
-- (`widget_regularite`) la lit une fois dans une variable et ne souffrait pas.
--
-- Le remède : la même fonction, la même valeur, la même garantie (un fuseau
-- inconnu retombe sur UTC), mais la validation se fait PAR TENTATIVE —
-- `now() at time zone v` lève 22023 si le nom est inconnu — au lieu de
-- balayer la vue. Coût : des microsecondes. Aucune signature ne change,
-- aucun appelant ne bouge.
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.fuseau_jour()
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v text;
begin
  select r.value #>> '{}' into v from public.reward_rules r where r.key = 'fuseau_jour';
  if v is null or v = '' then
    return 'UTC';
  end if;
  begin
    perform now() at time zone v;    -- 22023 si le fuseau n'existe pas
  exception when others then
    return 'UTC';
  end;
  return v;
end;
$$;

grant execute on function public.fuseau_jour() to authenticated;
