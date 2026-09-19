-- Revoir une story lit les gains historiques, sans rejouer leur règlement.
-- Le schéma des reçus reste privé ; seul le propriétaire peut lire ce bilan.
create or replace function public.recus_seances(p_workouts uuid[])
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare
  u uuid := auth.uid();
  resultat jsonb;
begin
  if u is null then raise sqlstate 'PT401' using message = 'connexion_requise'; end if;
  if coalesce(cardinality(p_workouts), 0) > 500 then
    raise sqlstate 'PT400' using message = 'trop_de_seances';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'workout_id', w.id, 'user_id', u,
    'bilan', jsonb_build_object(
      'pieces', coalesce((r.resultat->>'pieces_total')::integer,
                         (r.resultat->>'pieces')::integer, gains.pieces, 0),
      'piecesMuscu', coalesce((r.resultat->>'pieces')::integer, gains.muscu, 0),
      'boosters', (select count(*) from public.user_boosters b
        where b.user_id = u and (b.receipt_id = r.id or b.workout_id = w.id)),
      'argent', case when coalesce((r.resultat->>'argent_seance')::boolean,
                          gains.argent > 0, false) then 1 else 0 end,
      'top', (select f->>'kind' from jsonb_array_elements(faits.valeur) f
        where f->>'kind' in ('top_muscu', 'top_cardio')
        order by case f->>'kind' when 'top_muscu' then 0 else 1 end limit 1),
      'heuresDouble', (select f->'detail'->'heures' from jsonb_array_elements(faits.valeur) f
        where f->>'kind' = 'double_jour' limit 1),
      'minutesDouble', (select f->'detail'->'minutes' from jsonb_array_elements(faits.valeur) f
        where f->>'kind' = 'double_jour' limit 1)
    )) order by w.started_at, w.id), '[]'::jsonb) into resultat
  from public.workouts w
  left join cartes_prive.recus r on r.user_id = u and r.cause = 'seance:' || w.id::text
  -- Avant les reçus : seules les écritures réellement liées à la séance font foi.
  cross join lateral (
    select coalesce(sum(l.delta) filter (where l.currency = 'yellow'
             and l.raison in ('serie_faite', 'cardio_seance', 'bonus_progres')), 0)::integer as pieces,
           coalesce(sum(l.delta) filter (where l.raison = 'serie_faite'), 0)::integer as muscu,
           coalesce(sum(l.delta) filter (where l.raison = 'piece_argent'), 0)::integer as argent,
           count(*) as lignes
    from public.coin_ledger l where l.user_id = u and l.workout_id = w.id
  ) gains
  cross join lateral (
    select coalesce(r.resultat->'faits', (select jsonb_agg(jsonb_build_object(
      'kind', f.kind, 'detail', f.detail) order by f.kind)
      from public.workout_facts f where f.user_id = u and f.workout_id = w.id), '[]'::jsonb) as valeur
  ) faits
  where w.user_id = u and w.ended_at is not null and w.id = any(p_workouts)
    and (r.resultat is not null or gains.lignes > 0 or exists (
      select 1 from public.user_boosters b where b.user_id = u and b.workout_id = w.id));
  return resultat;
end;
$$;
revoke all on function public.recus_seances(uuid[]) from public, anon;
grant execute on function public.recus_seances(uuid[]) to authenticated;
comment on function public.recus_seances(uuid[]) is
  'Lecture des bilans historiques du compte courant, 500 UUID maximum. Aucun paiement ni annonce ; les anciennes séances utilisent uniquement leurs écritures conservées.';
