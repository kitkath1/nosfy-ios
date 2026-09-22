-- ⚠️ UN GALET = UN JOUR — sa règle du 21-09-2026 : « un galet = 1 jour malgré
-- deux séances, sinon tout s'épuise trop vite ».
--
-- CE QUI CHANGE, et c'est tout : la garde des lunes (nœuds 3 et 7 de chaque
-- chapitre) et du trésor (35) compte des JOURS, plus des séances. Trois jours
-- à une séance ouvrent la lune du rang 3 ; trois séances sur deux jours, non.
--
-- CE QUI NE CHANGE PAS, et c'est voulu :
--   · le plafond « deux séances comptées par jour local » — `seances_chemin_plafonnees()`
--     reste la matière, intacte (20260920160000) ;
--   · la clôture, qui PAIE toujours la deuxième séance du jour : sa décision
--     du 21-09 (« oui c'est ça, un jour = un galet » — ce sont les galets qui
--     s'épuisaient trop vite, pas les pièces) ;
--   · `seances_chemin()`, que la session Route corrige par ailleurs (kind HIIT) :
--     ce fichier ne la touche pas, elle sera reprise automatiquement.
--
-- Rien ne rétroagit de façon douloureuse : les comptes réels ont été remis à
-- zéro le 20-09, et une journée déjà double perd un galet — jamais une lune
-- déjà réclamée (un claim acquis reste rejouable, la garde ne le rejuge pas).
--
-- Banc : tools/duolingo/qa-galet-jour.sql via tools/duolingo/verif_galet_jour.py.

-- LES JOURS DE LA ROUTE : un galet par ligne. `seances` vaut 1 ou 2 (le ×2 du
-- téléphone), `premiere` est la fin qui a ouvert le galet, `derniere` celle
-- qu'on rouvre quand elle demande à revoir la story de la deuxième.
create or replace function public.jours_chemin()
returns table(jour date, seances integer, premiere timestamptz, derniere timestamptz)
language sql stable security invoker set search_path='' as $$
  select p.jour, count(*)::integer, min(p.ended_at), max(p.ended_at)
  from public.seances_chemin_plafonnees() p
  group by p.jour
  order by p.jour
$$;
revoke all on function public.jours_chemin() from public,anon;
grant execute on function public.jours_chemin() to authenticated;

-- La garde des lunes compte les JOURS — le corps de 20260920160000:143-157,
-- une seule ligne change (`jours_chemin()` au lieu de `seances_chemin_plafonnees()`).
create or replace function cartes_prive.tirer_noeud_chemin(p_noeud integer,p_pieces boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n integer; seuil integer;
begin
 if auth.uid() is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
 if p_noeud is null or p_noeud<0 or p_noeud>=45 or p_noeud%9 not in (3,8) then
   raise sqlstate 'PT400' using message='noeud_invalide'; end if;
 -- Un ancien claim reste rejouable ; aucun nouveau droit n'est inventé.
 if not exists(select 1 from public.noeuds_chemin_reclames() r where r.noeud_id=p_noeud) then
   select count(*) into n from public.jours_chemin();
   seuil:=(p_noeud/9)*7+case when p_noeud%9=3 then 3 else 7 end;
   if n<seuil then raise sqlstate 'PT409' using message='progression_insuffisante'; end if;
 end if;
 return public.tirer_noeud_chemin_valide_interne(p_noeud,p_pieces);
end $$;
