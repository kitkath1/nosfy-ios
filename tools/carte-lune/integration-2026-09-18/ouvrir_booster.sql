CREATE OR REPLACE FUNCTION public.ouvrir_booster(p_legendaire boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_id uuid;
begin
  -- ⚠️ LA FENÊTRE (relecture adverse 30-08) : avant cette migration, aucun
  -- manège n'a jamais scellé son sachet — chaque compte porte des ORPHELINS
  -- (ouverts, sans carte). Sans borne, les N prochaines ouvertures les
  -- rendraient un par un et le compteur `boosters_or` ne descendrait pas
  -- pendant N sachets. La reprise ne vise qu'un quit entre la consommation
  -- et la forge : six heures, pas l'histoire du compte.
  select id into v_id
    from public.user_boosters
   where user_id = auth.uid()
     and opened_at is not null
     and opened_at > now() - interval '6 hours'
     and card_id is null
     and (case when p_legendaire then origine = 'legendaire'
                                 else origine <> 'legendaire' end)
   order by opened_at desc
   limit 1;
  if v_id is not null then
    return jsonb_build_object('ouvert', true, 'booster_id', v_id, 'reprise', true);
  end if;

  select id into v_id
    from public.user_boosters
   where user_id = auth.uid()
     and opened_at is null
     and (case when p_legendaire then origine = 'legendaire'
                                 else origine <> 'legendaire' end)
   order by obtained_at asc
   limit 1
     for update skip locked;

  if v_id is null then
    return jsonb_build_object('ouvert', false, 'raison', 'aucun_sachet'::text);
  end if;

  update public.user_boosters
     set opened_at = now()
   where id = v_id;

  return jsonb_build_object('ouvert', true, 'booster_id', v_id, 'reprise', false);
end $function$
