CREATE OR REPLACE FUNCTION public.ma_collection()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(jsonb_agg(jsonb_build_object(
           'famille',  f.famille,
           'rarete',   f.rarete,
           'nombre',   f.nombre,
           'card_id',  f.card_id,
           'art_path', f.art_path,
           'premiere', f.premiere,
           'derniere', f.derniere)
         order by f.premiere), '[]'::jsonb)
  from (
    select c.famille,
           c.rarete,
           count(*)::int                                          as nombre,
           min(u.obtained_at)                                     as premiere,
           max(u.obtained_at)                                     as derniere,
           (array_agg(c.id       order by u.obtained_at desc))[1] as card_id,
           (array_agg(c.art_path order by u.obtained_at desc))[1] as art_path
      from public.user_cards u
      join public.cards c on c.id = u.card_id
     where u.user_id = auth.uid()
     group by c.famille, c.rarete
  ) f;
$function$
