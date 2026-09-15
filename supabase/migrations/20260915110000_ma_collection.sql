-- ════════════════════════════════════════════════════════════════════════
-- MA COLLECTION — le mur du profil lit enfin le serveur (15-09, étape 2)
--
-- Le défaut (site : b-fo-mur 🔴, b-fo-lire-user-cards 🔵, b-tb-user-cards) : `user_cards`
-- se remplit à chaque forge et AUCUNE ligne de l'app ne la lit. Le mur « Cartes
-- collectées · N / 4 » du profil compte en mémoire (CollectionLune, SacreAccueil.swift) :
-- une réinstallation, et il repart à zéro alors que les cartes sont là.
--
-- `ma_collection()` rend la collection de la personne, GROUPÉE COMME LE MUR L'AFFICHE :
-- une entrée par famille (le slot), avec le nombre d'exemplaires (la pastille ×N), la
-- carte la plus récente de la famille (id, scène, chemin de l'illustration dans le bucket
-- public `cards`) et les dates. L'app habille l'illustration (cadre, lunes, depth) comme
-- après une forge — le serveur ne rend jamais une image, seulement son chemin.
--
-- Sans session : EXECUTE révoqué à anon → 401 (la loi de profil() / home()).
-- Une collection vide rend [] (la loi du vide : jamais null).
-- Vérification : tools/serveur/verif_collection.py (compte de test, puis un compte jetable
-- à 0 carte) ; côté app : le profil au banc -sessionBanc -openTab profile.
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
           'scene',    f.scene,
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
           (array_agg(c.scene    order by u.obtained_at desc))[1] as scene,
           (array_agg(c.art_path order by u.obtained_at desc))[1] as art_path
      from public.user_cards u
      join public.cards c on c.id = u.card_id
     where u.user_id = auth.uid()
     group by c.famille, c.rarete
  ) f;
$$;

comment on function public.ma_collection() is
  'La collection de la personne, groupée par famille comme le mur du profil : nombre d''exemplaires, carte la plus récente (id, scène, art_path dans le bucket public cards), dates. [] sans carte ; 401 sans session.';

revoke all on function public.ma_collection() from public;
revoke all on function public.ma_collection() from anon;
grant execute on function public.ma_collection() to authenticated;
