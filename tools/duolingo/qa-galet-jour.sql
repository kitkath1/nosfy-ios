-- LE BANC DU « UN GALET = UN JOUR » (21-09) — exécuté ENTIER dans BEGIN / ROLLBACK par
-- tools/duolingo/verif_galet_jour.py, sur la base vivante, sous l'identité de deux comptes
-- inventés le temps de la transaction. Rien ne reste : ni compte, ni séance, ni reçu, ni claim.
--
-- Il vérifie la règle telle que le téléphone la vivra : `jours_chemin()` (un galet par jour
-- local, 1 ou 2 séances), la garde des lunes qui compte des JOURS, le plafond qui ne bouge
-- pas, et la clôture qui PAIE toujours la deuxième séance du jour (sa décision du 21-09).
create temp table qa_resultats(rang serial, nom text, ok boolean, detail text) on commit drop;

create function pg_temp.seance(p_w uuid, p_u uuid, p_il_y_a interval, p_fuseau text, p_travail boolean) returns jsonb
language plpgsql as $f$
declare e uuid := gen_random_uuid(); fin timestamptz := now() - p_il_y_a; wk jsonb; ex jsonb := '[]'; se jsonb := '[]';
begin
  wk := jsonb_build_object('id',p_w,'user_id',p_u,'started_at',fin - interval '12 minutes','ended_at',fin,'notes','QA galet-jour');
  if p_fuseau is not null then wk := wk || jsonb_build_object('fuseau',p_fuseau); end if;
  if p_travail then
    ex := jsonb_build_array(jsonb_build_object('id',e,'user_id',p_u,'workout_id',p_w,'exercise_id','hip-thrust','position',0));
    se := jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'user_id',p_u,'logged_exercise_id',e,'reps',10,'weight',5,'position',0));
  end if;
  return public.synchroniser_seance(wk, ex, se, '[]'::jsonb, '[]'::jsonb);
end $f$;
create function pg_temp.note(p_nom text, p_ok boolean, p_detail text default null) returns void
language sql as $n$ insert into qa_resultats(nom, ok, detail) values (p_nom, p_ok, p_detail); $n$;

do $$
declare
  u uuid := gen_random_uuid(); v uuid := gen_random_uuid();
  w1 uuid := gen_random_uuid(); w2 uuid := gen_random_uuid(); w3 uuid := gen_random_uuid();
  w4 uuid := gen_random_uuid(); w5 uuid := gen_random_uuid(); w6 uuid := gen_random_uuid();
  j jsonb; k jsonb; n integer; d integer; erreur text;
  paris date := (now() at time zone 'Europe/Paris')::date;
  p1 timestamptz; p2 timestamptz;
begin
  insert into auth.users(id) values (u), (v);
  perform set_config('request.jwt.claim.sub', u::text, true);
  -- Le plafond vaut dès aujourd'hui dans la transaction (sa vraie date est le 20-09).
  update public.reward_rules set value = '"2026-09-01"'::jsonb where key = 'chemin_plafond_depuis';

  -- 1. DEUX séances aujourd'hui = UN jour, deux séances.
  perform pg_temp.seance(w1, u, interval '3 hours', 'Europe/Paris', true);
  perform pg_temp.seance(w2, u, interval '30 minutes', 'Europe/Paris', true);
  select count(*) into n from public.jours_chemin();
  perform pg_temp.note('deux séances le même jour : UNE ligne de jours_chemin', n = 1, n::text);
  select seances, premiere, derniere into d, p1, p2 from public.jours_chemin();
  perform pg_temp.note('le jour compte DEUX séances (le ×2 du téléphone)', d = 2, d::text);
  perform pg_temp.note('première < dernière (la story de chacune est joignable)', p1 < p2,
            p1::text || ' → ' || p2::text);
  perform pg_temp.note('le jour est celui de Paris', (select bool_and(g.jour = paris) from public.jours_chemin() g));

  -- 2. La clôture PAIE toujours la deuxième séance de la journée (sa décision du 21-09).
  j := public.cloturer_seance(w1, 1);
  perform pg_temp.note('clôture 1 : payée', (j->>'pieces')::int > 0
            and coalesce((j->>'plafond_jour')::boolean, false) = false, j->>'pieces');
  j := public.cloturer_seance(w2, 1);
  perform pg_temp.note('clôture 2 : PAYÉE malgré un seul galet', (j->>'pieces')::int > 0
            and coalesce((j->>'plafond_jour')::boolean, false) = false, j->>'pieces');

  -- 3. Une TROISIÈME séance le même jour : ni jour, ni séance de plus, et elle ne paie pas.
  perform pg_temp.seance(w3, u, interval '10 minutes', 'Europe/Paris', true);
  select count(*) into n from public.jours_chemin();
  select seances into d from public.jours_chemin();
  perform pg_temp.note('troisième séance du jour : toujours UN jour, DEUX séances',
            n = 1 and d = 2, n::text || ' jour(s), ' || d::text || ' séance(s)');
  j := public.cloturer_seance(w3, 1);
  perform pg_temp.note('troisième séance : plafond_jour, zéro pièce',
            (j->>'plafond_jour')::boolean and (j->>'pieces')::int = 0, left(j::text, 120));

  -- 4. La garde des lunes compte des JOURS : trois séances sur DEUX jours ne suffisent pas.
  perform pg_temp.seance(w4, u, interval '1 day', 'Europe/Paris', true);
  select count(*) into n from public.seances_chemin_plafonnees();
  select count(*) into d from public.jours_chemin();
  perform pg_temp.note('trois séances comptées, DEUX jours', n = 3 and d = 2,
            n::text || ' séance(s), ' || d::text || ' jour(s)');
  begin
    perform public.tirer_noeud_chemin(3, true);
    perform pg_temp.note('lune du rang 3 REFUSÉE avec 3 séances sur 2 jours', false, 'aucun refus');
  exception when sqlstate 'PT409' then
    get stacked diagnostics erreur = message_text;
    perform pg_temp.note('lune du rang 3 REFUSÉE avec 3 séances sur 2 jours',
              erreur = 'progression_insuffisante', erreur);
  end;

  -- 5. Un TROISIÈME jour l'ouvre.
  perform pg_temp.seance(w5, u, interval '2 days', 'Europe/Paris', true);
  select count(*) into d from public.jours_chemin();
  perform pg_temp.note('trois jours comptés', d = 3, d::text);
  j := public.tirer_noeud_chemin(3, true);
  perform pg_temp.note('lune du rang 3 ACCORDÉE au troisième jour',
            j->>'raison' is null and coalesce(j->>'deja_reclame','false') <> 'true',
            'raison=' || coalesce(j->>'raison','∅') || ' deja_reclame=' || coalesce(j->>'deja_reclame','∅'));

  -- 6. Rejeu : un claim acquis reste rejouable, la garde ne le rejuge pas.
  k := public.tirer_noeud_chemin(3, true);
  perform pg_temp.note('rejeu du même nœud : idempotent, aucun refus',
            k->>'raison' is null, left(k::text, 120));

  -- 7. Une séance VIDE ne fait pas un jour.
  perform pg_temp.seance(w6, u, interval '3 days', 'Europe/Paris', false);
  select count(*) into d from public.jours_chemin();
  perform pg_temp.note('une séance vide ne pose pas de galet', d = 3, d::text);

  -- 8. Un autre compte ne voit rien de tout ça.
  perform set_config('request.jwt.claim.sub', v::text, true);
  perform pg_temp.note('compte étranger : aucun jour', (select count(*) from public.jours_chemin()) = 0);
end $$;

select nom, ok, detail from qa_resultats order by rang;
