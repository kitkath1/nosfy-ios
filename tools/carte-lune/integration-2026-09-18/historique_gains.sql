CREATE OR REPLACE FUNCTION public.historique_gains(p_limite integer DEFAULT 60)
 RETURNS TABLE(quand timestamp with time zone, genre text, motif text, montant integer, monnaie text, robe text)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  -- ⚠️ **CHAQUE LITTÉRAL EST TYPÉ.** Dans un `union all` rendu par une
  -- fonction `returns table`, un littéral nu reste de type `unknown` :
  -- Postgres essaie de le résoudre depuis l'autre branche, et quand les deux
  -- branches en ont un au même rang (`'coins'` / `'booster'`), il échoue à la
  -- CRÉATION de la fonction — pas à l'appel. Une migration qui casse à la
  -- pose est la pire des surprises.
  select created_at,
         'coins'::text, raison::text, delta::integer,
         currency::text, null::text
    from public.coin_ledger
   where user_id = auth.uid() and delta > 0
  union all
  select obtained_at,
         'booster'::text, origine::text, 1::integer,
         null::text,
         (case when origine = 'legendaire' then 'noire'
               else coalesce(robe, 'lune') end)::text
    from public.user_boosters
   where user_id = auth.uid()
   order by 1 desc
   limit greatest(coalesce(p_limite, 60), 1);
$function$
