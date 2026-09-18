CREATE OR REPLACE FUNCTION public.convertis_transaction()
 RETURNS integer
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(nullif(current_setting('woop.convertis', true), ''), '0')::int;
$function$
