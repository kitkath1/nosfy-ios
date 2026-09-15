-- ════════════════════════════════════════════════════════════════════════
-- MA COLLECTION, SANS LA SCÈNE — 15-09, même heure
--
-- Mesuré juste après 20260915110000 sur le compte de test : 7 familles, 28 cartes,
-- 14 948 octets — dont ~1 850 par famille pour `scene`, le brief entier du directeur
-- artistique. Le mur du profil n'en a pas besoin (il montre l'illustration) ; la scène
-- reste lisible dans `cards` pour qui la voudra. Même signature, même ordre, mêmes clés
-- moins une : aucun appelant ne bouge (SacreServeur.maCollection ne la lisait pas).
-- ════════════════════════════════════════════════════════════════════════

create or replace function public.ma_collection()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
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
$$;
