CREATE OR REPLACE FUNCTION public.tirer_noeud_chemin(p_noeud integer, p_pieces boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare n integer; seuil integer;
begin
 if auth.uid() is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
 if p_noeud is null or p_noeud<0 or p_noeud>=45 or p_noeud%9 not in (3,8) then
   raise sqlstate 'PT400' using message='noeud_invalide'; end if;
 -- Un ancien claim reste rejouable ; aucun nouveau droit n'est inventé.
 if not exists(select 1 from public.noeuds_chemin_reclames() r where r.noeud_id=p_noeud) then
   select count(*) into n from public.seances_chemin();
   seuil:=(p_noeud/9)*7+case when p_noeud%9=3 then 3 else 7 end;
   if n<seuil then raise sqlstate 'PT409' using message='progression_insuffisante'; end if;
 end if;
 return public.tirer_noeud_chemin_valide_interne(p_noeud,p_pieces);
end $function$
