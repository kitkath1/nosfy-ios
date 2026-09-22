-- LE BANC DU PLAFOND DU JOUR (20-09) — exécuté ENTIER dans BEGIN / ROLLBACK par
-- tools/duolingo/verif_plafond_jour.py, sur la base vivante, sous l'identité de deux
-- comptes inventés le temps de la transaction. Rien ne reste : ni compte, ni séance, ni reçu.
--
-- Il joue la règle telle que le téléphone la vivra : synchroniser_seance (avec le fuseau),
-- seances_chemin_plafonnees, la clôture (payée / plafond_jour), la garde des lunes, le
-- fuseau qui change de jour, la séance vide qui ne consomme rien, la date d'entrée en
-- vigueur. Chaque contrôle écrit une ligne dans qa_resultats ; le runner les lit.
create temp table qa_resultats(rang serial, nom text, ok boolean, detail text) on commit drop;

-- Deux aides le temps de la transaction (pg_temp).
-- Une séance avec UNE série (ou vide), finie il y a `p_il_y_a`, avec un fuseau (ou aucun).
create function pg_temp.seance(p_w uuid, p_u uuid, p_il_y_a interval, p_fuseau text, p_travail boolean) returns jsonb
language plpgsql as $f$
declare e uuid := gen_random_uuid(); fin timestamptz := now() - p_il_y_a; wk jsonb; ex jsonb := '[]'; se jsonb := '[]';
begin
  wk := jsonb_build_object('id',p_w,'user_id',p_u,'started_at',fin - interval '12 minutes','ended_at',fin,'notes','QA plafond');
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
  w4 uuid := gen_random_uuid(); w5 uuid := gen_random_uuid(); w6 uuid := gen_random_uuid(); w7 uuid := gen_random_uuid();
  j jsonb; k jsonb; n integer; solde_avant integer; solde_apres integer; erreur text; zone text;
  paris date := (now() at time zone 'Europe/Paris')::date;
begin
  insert into auth.users(id) values (u), (v);
  perform set_config('request.jwt.claim.sub', u::text, true);

  -- 0. La règle est là, et le banc la fait valoir AUJOURD'HUI (la vraie date d'entrée en
  --    vigueur est le 21-09 ; ici, dans la transaction annulée, on la recule).
  perform pg_temp.note('règle chemin_seances_par_jour_max = 2',
            public.regle_num('chemin_seances_par_jour_max', 0) = 2, public.regle_num('chemin_seances_par_jour_max', 0)::text);
  perform pg_temp.note('règle chemin_plafond_depuis posée',
            exists(select 1 from public.reward_rules where key = 'chemin_plafond_depuis'),
            (select value::text from public.reward_rules where key = 'chemin_plafond_depuis'));
  update public.reward_rules set value = '"2026-09-01"'::jsonb where key = 'chemin_plafond_depuis';

  -- 1. Trois séances avec travail aujourd'hui, à Paris.
  perform pg_temp.seance(w1, u, interval '30 minutes', 'Europe/Paris', true);
  perform pg_temp.seance(w2, u, interval '20 minutes', 'Europe/Paris', true);
  perform pg_temp.seance(w3, u, interval '10 minutes', 'Europe/Paris', true);
  perform pg_temp.note('fuseau enregistré sur la séance',
            (select fuseau from public.workouts where id = w1) = 'Europe/Paris');
  select count(*) into n from public.seances_chemin();
  perform pg_temp.note('seances_chemin : les trois séances avec travail', n = 3, n::text);
  select count(*) into n from public.seances_chemin_plafonnees();
  perform pg_temp.note('seances_chemin_plafonnees : deux seulement', n = 2, n::text);
  perform pg_temp.note('les deux premières du jour comptent (rangs 1 et 2)',
            (select array_agg(p.id order by p.ended_at) from public.seances_chemin_plafonnees() p) = array[w1, w2]
            and (select array_agg(p.rang_jour order by p.ended_at) from public.seances_chemin_plafonnees() p) = array[1, 2]);
  perform pg_temp.note('le jour est le jour de Paris',
            (select bool_and(p.jour = paris) from public.seances_chemin_plafonnees() p));

  -- 2. La clôture : les deux premières paient, la troisième dit plafond_jour et ne paie rien.
  j := public.cloturer_seance(w1, 1);
  perform pg_temp.note('clôture 1 : payée', (j->>'pieces')::int > 0 and coalesce((j->>'plafond_jour')::boolean, false) = false, j->>'pieces');
  j := public.cloturer_seance(w2, 1);
  perform pg_temp.note('clôture 2 : payée', (j->>'pieces')::int > 0 and coalesce((j->>'plafond_jour')::boolean, false) = false, j->>'pieces');
  solde_avant := (public.etat_coffre()->>'solde_or')::int;
  j := public.cloturer_seance(w3, 1);
  solde_apres := (public.etat_coffre()->>'solde_or')::int;
  perform pg_temp.note('clôture 3 : plafond_jour, zéro pièce, pas de sachet',
            (j->>'plafond_jour')::boolean and (j->>'pieces')::int = 0 and (j->>'pieces_total')::int = 0
            and (j->>'booster_neuf')::boolean = false and j->>'faits_raison' = 'plafond_jour',
            j::text);
  perform pg_temp.note('clôture 3 : le solde ne bouge pas', solde_apres = solde_avant, solde_avant::text || ' → ' || solde_apres::text);
  perform pg_temp.note('clôture 3 : le solde renvoyé est le vrai (pas 0)', (j->>'solde')::int = solde_apres, j->>'solde');
  perform pg_temp.note('clôture 3 : aucun événement de gain', jsonb_array_length(coalesce(j->'events', '[]'::jsonb)) = 0);
  k := public.cloturer_seance(w3, 1);
  perform pg_temp.note('clôture 3 rejouée : même réponse, rejeu', (k->>'plafond_jour')::boolean and (k->>'rejeu')::boolean and (k->>'pieces')::int = 0);

  -- 3. La garde des lunes compte les séances plafonnées : 2 < 3 → refus.
  --    (rang 3 du chapitre 0 = la piste des PIÈCES : p_pieces = true, sinon « piste_invalide »)
  begin
    perform public.tirer_noeud_chemin(3, true);
    perform pg_temp.note('lune du rang 3 refusée avec 2 séances comptées', false, 'aucun refus');
  exception when sqlstate 'PT409' then
    get stacked diagnostics erreur = message_text;
    perform pg_temp.note('lune du rang 3 refusée avec 2 séances comptées', erreur = 'progression_insuffisante', erreur);
  end;
  -- Une séance HIER : elle compte (troisième séance comptée).
  perform pg_temp.seance(w4, u, interval '1 day', 'Europe/Paris', true);
  select count(*) into n from public.seances_chemin_plafonnees();
  perform pg_temp.note('une séance d''hier compte : trois séances comptées', n = 3, n::text);
  -- ⚠️ 21-09, SA RÈGLE « UN GALET = UN JOUR » : la lune ne compte plus des
  -- séances mais des JOURS (migration 20260921090000). Trois séances sur DEUX
  -- jours ne l'ouvrent donc plus — et c'est voulu. L'ouverture au troisième
  -- JOUR est vérifiée par tools/duolingo/qa-galet-jour.sql.
  begin
    perform public.tirer_noeud_chemin(3, true);
    perform pg_temp.note('lune du rang 3 refusée : 3 séances mais 2 jours (règle du 21-09)', false, 'aucun refus');
  exception when sqlstate 'PT409' then
    get stacked diagnostics erreur = message_text;
    perform pg_temp.note('lune du rang 3 refusée : 3 séances mais 2 jours (règle du 21-09)',
              erreur = 'progression_insuffisante', erreur);
  end;

  -- 4. Le fuseau change le jour : une séance finie il y a 5 min de l'autre côté
  --    de la ligne de date tombe un AUTRE jour local → elle compte dans SA journée.
  --    ⚠️ 21-09 : le fuseau ne peut pas être écrit en dur — Pago Pago (UTC−11) ne
  --    recule d'un jour que le matin à Paris, et ce banc échouait tous les
  --    après-midi. On choisit celui qui décale VRAIMENT à l'instant du banc.
  zone := case when (now() at time zone 'Pacific/Pago_Pago')::date <> paris
               then 'Pacific/Pago_Pago' else 'Pacific/Kiritimati' end;
  perform pg_temp.note('un fuseau qui change le jour existe à cette heure',
            (now() at time zone zone)::date <> paris, zone);
  perform pg_temp.seance(w5, u, interval '5 minutes', zone, true);
  perform pg_temp.note('séance de l''autre bout du monde : rattachée à un autre jour que Paris',
            (select p.jour from public.seances_chemin_plafonnees() p where p.id = w5) is not null
            and (select p.jour from public.seances_chemin_plafonnees() p where p.id = w5) <> paris
            and (select p.rang_jour from public.seances_chemin_plafonnees() p where p.id = w5) <= 2,
            (select p.jour::text || ' rang ' || p.rang_jour from public.seances_chemin_plafonnees() p where p.id = w5));

  -- 5. Un fuseau inconnu n'est pas une erreur : il est ignoré, le jour de la maison prend le relais.
  perform pg_temp.seance(w6, u, interval '4 minutes', 'Mars/Olympus', true);
  perform pg_temp.note('fuseau inconnu ignoré (null), séance acceptée',
            exists(select 1 from public.workouts where id = w6 and fuseau is null));
  perform pg_temp.note('fuseau inconnu → jour de Paris → au-delà du plafond, non comptée',
            not exists(select 1 from public.seances_chemin_plafonnees() p where p.id = w6));

  -- 6. Une séance VIDE ne consomme pas le quota et n'est pas concernée par le plafond.
  perform pg_temp.seance(w7, u, interval '3 minutes', 'Europe/Paris', false);
  select count(*) into n from public.seances_chemin_plafonnees();
  perform pg_temp.note('séance vide : le compte ne bouge pas', n = 4, n::text);
  j := public.cloturer_seance(w7, 0);
  perform pg_temp.note('séance vide : clôture sans plafond_jour ni pièce',
            coalesce((j->>'plafond_jour')::boolean, false) = false and coalesce((j->>'pieces')::int, 0) = 0, left(j::text, 100));

  -- 7. Avant la date d'entrée en vigueur, rien n'est plafonné.
  update public.reward_rules set value = '"2999-01-01"'::jsonb where key = 'chemin_plafond_depuis';
  select count(*) into n from public.seances_chemin_plafonnees();
  perform pg_temp.note('avant chemin_plafond_depuis : toutes les séances avec travail comptent',
            n = (select count(*) from public.seances_chemin()), n::text);

  -- 8. Un autre compte ne voit rien de tout ça.
  perform set_config('request.jwt.claim.sub', v::text, true);
  perform pg_temp.note('compte étranger : progression vide', (select count(*) from public.seances_chemin_plafonnees()) = 0);
end $$;

select nom, ok, detail from qa_resultats order by rang;
