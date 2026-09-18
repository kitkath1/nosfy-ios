CREATE OR REPLACE FUNCTION public.tirer_noeud_chemin_valide_interne(p_noeud integer, p_pieces boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v jsonb;
begin
  v := public.tirer_noeud_chemin_brut(p_noeud, p_pieces);
  return v || jsonb_build_object('sachets_convertis', public.convertis_transaction());
end $function$
