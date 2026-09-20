-- LE PLAFOND DU JOUR — sa règle du 20-09 : « maximum deux séances par jour dans la
-- Route de galets, pour pas tricher et avoir trop de boosters ». Analyse et décisions :
-- tools/duolingo/PLAN-PLAFOND-2-SEANCES-JOUR-2026-09-20.md.
--
-- Trois idées, pas une de plus :
--  1. LA RÈGLE DU JEU vit dans reward_rules (chemin_seances_par_jour_max = 2), la même
--     pour tout le monde ; l'app la relit pour COMPARER à sa constante, jamais pour décider.
--  2. LE JOUR d'une séance est le jour LOCAL du téléphone : la séance emporte son fuseau
--     (workouts.fuseau, identifiant IANA, posé par synchroniser_seance) ; sans fuseau
--     (les anciennes versions de l'app), le jour de la maison (fuseau_jour(), Europe/Paris).
--     Le jour de rattachement est celui de la FIN (ended_at), comme le galet.
--  3. seances_chemin() NE CHANGE PAS — c'est « une séance terminée avec travail », et la
--     session Route la redéfinit dans 20260920120000 (les libellés HIIT du téléphone) :
--     le plafond est une fonction PAR-DESSUS, seances_chemin_plafonnees(), qui garde les
--     deux premières séances de chaque jour local. La garde des lunes
--     (cartes_prive.tirer_noeud_chemin) compte celles-là ; la clôture
--     (cartes_prive.cloturer_seance) ne paie RIEN à une séance avec travail au-delà du
--     plafond — ni pièces, ni sachet, ni faits — et le dit (plafond_jour). Une séance vide
--     n'est pas concernée : elle ne paie déjà rien.
--
-- La règle vaut pour les séances finies à partir de chemin_plafond_depuis (le 21-09) : les
-- journées d'avant gardent tous leurs galets. Lu avant la pose, en lecture seule : un seul
-- compte réel avait une journée à plus de deux séances avec travail — le sien, le 20-09
-- (quatre) ; d'où la date. Une lune déjà réclamée n'est jamais reprise (« un ancien claim
-- reste rejouable, aucun nouveau droit n'est inventé »).
-- DOWN (à la main) : drop function seances_chemin_plafonnees ; rejouer
-- 20260918083033:22-88 (synchroniser_seance sans fuseau), :132-147 (garde) et :93-112
-- (clôture) dans cartes_prive ; delete from reward_rules where key in ('chemin_seances_par_jour_max','chemin_plafond_depuis').

insert into public.reward_rules(key,value) values
  ('chemin_seances_par_jour_max','2'::jsonb),
  -- Le plafond ne rétroagit pas : il vaut pour les séances finies À PARTIR de ce jour
  -- (lu le 20-09 : son propre compte avait quatre séances avec travail le matin même ;
  -- une règle rétroactive lui aurait ôté deux galets sous les yeux). Modifiable.
  ('chemin_plafond_depuis','"2026-09-21"'::jsonb)
on conflict(key) do nothing;

alter table public.workouts add column if not exists fuseau text;
comment on column public.workouts.fuseau is
  'Le fuseau du téléphone à la synchronisation (identifiant IANA) : le jour local de la séance, pour le plafond du jour. Null = le jour de la maison (fuseau_jour()).';

-- synchroniser_seance : la fonction de 20260918083033, telle quelle, plus le fuseau.
create or replace function public.synchroniser_seance(p_workout jsonb, p_exercices jsonb,
  p_series jsonb, p_phases jsonb, p_piscines jsonb) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare
  u uuid := auth.uid(); w uuid := (p_workout->>'id')::uuid;
  debut timestamptz := (p_workout->>'started_at')::timestamptz;
  fin timestamptz := (p_workout->>'ended_at')::timestamptz;
  -- LE FUSEAU DU TÉLÉPHONE (20-09) : le jour local de la séance, pour le plafond du jour.
  fz text := nullif(p_workout->>'fuseau','');
begin
  if u is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
  if w is null or debut is null or fin is null or fin<debut or fin>now()+interval '5 minutes' then
    raise sqlstate 'PT400' using message='seance_invalide'; end if;
  if jsonb_typeof(p_exercices) is distinct from 'array' or jsonb_typeof(p_series) is distinct from 'array'
     or jsonb_typeof(p_phases) is distinct from 'array' or jsonb_typeof(p_piscines) is distinct from 'array' then
    raise sqlstate 'PT400' using message='instantane_invalide'; end if;
  if jsonb_array_length(p_exercices)>200 or jsonb_array_length(p_series)>2000
     or jsonb_array_length(p_phases)>5000 or jsonb_array_length(p_piscines)>200 then
    raise sqlstate 'PT400' using message='instantane_trop_grand'; end if;
  -- Les relations du payload doivent décrire CET arbre, sans ids dédoublés.
  if exists(select 1 from jsonb_array_elements(p_exercices) e where (e->>'workout_id')::uuid is distinct from w)
     or exists(select 1 from jsonb_array_elements(p_series||p_phases||p_piscines) c
       where not exists(select 1 from jsonb_array_elements(p_exercices) e where e->>'id'=c->>'logged_exercise_id'))
     or exists(select 1 from jsonb_array_elements(p_exercices) e group by e->>'id' having count(*)>1)
     or exists(select 1 from jsonb_array_elements(p_series) s group by s->>'id' having count(*)>1)
     or exists(select 1 from jsonb_array_elements(p_phases) c group by c->>'id' having count(*)>1) then
    raise sqlstate 'PT400' using message='relations_invalides'; end if;
  if exists(select 1 from jsonb_array_elements(p_series) s where (s->>'reps')::integer<0 or (s->>'weight')::float8<0)
     or exists(select 1 from jsonb_array_elements(p_phases) c where (c->>'seconds')::integer<=0) then
    raise sqlstate 'PT400' using message='travail_invalide'; end if;
  -- Ne pas déplacer un exercice ou une réalisation déjà rattachés ailleurs.
  if exists(select 1 from public.logged_exercises e join jsonb_array_elements(p_exercices) j on e.id=(j->>'id')::uuid where e.workout_id<>w)
     or exists(select 1 from public.strength_sets s join jsonb_array_elements(p_series) j on s.id=(j->>'id')::uuid where s.logged_exercise_id<>(j->>'logged_exercise_id')::uuid)
     or exists(select 1 from public.cardio_phases c join jsonb_array_elements(p_phases) j on c.id=(j->>'id')::uuid where c.logged_exercise_id<>(j->>'logged_exercise_id')::uuid) then
    raise sqlstate 'PT409' using message='identifiant_deja_rattache'; end if;
  -- Un fuseau inconnu ne casse rien : il est ignoré, le jour de la maison prend le relais.
  if fz is not null then
    begin perform now() at time zone fz; exception when others then fz := null; end;
  end if;
  insert into public.workouts as wk(id,user_id,started_at,ended_at,notes,fuseau)
    values(w,u,debut,fin,coalesce(p_workout->>'notes',''),fz)
    on conflict(id) do update set started_at=excluded.started_at,ended_at=excluded.ended_at,notes=excluded.notes,
      fuseau=coalesce(excluded.fuseau,wk.fuseau);
  -- L'upsert prend le verrou de séance : la clôture attend la transaction entière.
  insert into public.logged_exercises(id,user_id,workout_id,exercise_id,position)
    select x.id,u,w,x.exercise_id,x.position from jsonb_to_recordset(p_exercices) as x(id uuid,exercise_id text,position int)
    on conflict(id) do update set exercise_id=excluded.exercise_id,position=excluded.position;
  insert into public.strength_sets(id,user_id,logged_exercise_id,reps,weight,position)
    select x.id,u,x.logged_exercise_id,x.reps,x.weight,x.position
    from jsonb_to_recordset(p_series) as x(id uuid,logged_exercise_id uuid,reps int,weight float8,position int)
    on conflict(id) do update set reps=excluded.reps,weight=excluded.weight,position=excluded.position;
  insert into public.cardio_phases(id,user_id,logged_exercise_id,kind,seconds,speed,incline,cycle_index,position)
    select x.id,u,x.logged_exercise_id,x.kind,x.seconds,x.speed,x.incline,x.cycle_index,x.position
    from jsonb_to_recordset(p_phases) as x(id uuid,logged_exercise_id uuid,kind text,seconds int,speed float8,incline float8,cycle_index int,position int)
    on conflict(id) do update set kind=excluded.kind,seconds=excluded.seconds,speed=excluded.speed,incline=excluded.incline,cycle_index=excluded.cycle_index,position=excluded.position;
  insert into public.piscine_longueurs(logged_exercise_id,user_id,longueurs,metres_par_longueur)
    select x.logged_exercise_id,u,x.longueurs,x.metres_par_longueur
    from jsonb_to_recordset(p_piscines) as x(logged_exercise_id uuid,longueurs int,metres_par_longueur int)
    on conflict(logged_exercise_id) do update set longueurs=excluded.longueurs,metres_par_longueur=excluded.metres_par_longueur;
  -- Remplacer l'instantané de CETTE séance ; conserver tous les autres comptes.
  delete from public.strength_sets s using public.logged_exercises e
    where s.logged_exercise_id=e.id and e.workout_id=w and not exists(select 1 from jsonb_array_elements(p_series) j where (j->>'id')::uuid=s.id);
  delete from public.cardio_phases c using public.logged_exercises e
    where c.logged_exercise_id=e.id and e.workout_id=w and not exists(select 1 from jsonb_array_elements(p_phases) j where (j->>'id')::uuid=c.id);
  delete from public.piscine_longueurs p using public.logged_exercises e
    where p.logged_exercise_id=e.id and e.workout_id=w and not exists(select 1 from jsonb_array_elements(p_piscines) j where (j->>'logged_exercise_id')::uuid=p.logged_exercise_id);
  delete from public.logged_exercises e where e.workout_id=w
    and not exists(select 1 from jsonb_array_elements(p_exercices) j where (j->>'id')::uuid=e.id);
  update public.workouts set sync_complete_at=clock_timestamp() where id=w;
  return jsonb_build_object('ok',true,'workout_id',w,'series',jsonb_array_length(p_series),'phases',jsonb_array_length(p_phases));
end $$;


-- Les deux premières séances avec travail de chaque jour local : ce qui COMPTE pour la Route.
create or replace function public.seances_chemin_plafonnees()
returns table(id uuid, ended_at timestamptz, jour date, rang_jour integer)
language sql stable security invoker set search_path='' as $$
  with regle as (
    select greatest(public.regle_num('chemin_seances_par_jour_max',2)::integer,1) as max_par_jour,
           coalesce((select (r.value #>> '{}')::date from public.reward_rules r where r.key='chemin_plafond_depuis'),
                    date '2026-09-21') as depuis),
  s as (
    select c.id, c.ended_at,
           (c.ended_at at time zone coalesce(w.fuseau, public.fuseau_jour()))::date as jour
    from public.seances_chemin() c
    join public.workouts w on w.id=c.id),
  r as (
    select s.id, s.ended_at, s.jour,
           (row_number() over (partition by s.jour order by s.ended_at, s.id))::integer as rang_jour
    from s)
  select r.id, r.ended_at, r.jour, r.rang_jour
  from r, regle
  where r.jour < regle.depuis or r.rang_jour <= regle.max_par_jour
  order by r.ended_at, r.id
$$;
revoke all on function public.seances_chemin_plafonnees() from public,anon;
grant execute on function public.seances_chemin_plafonnees() to authenticated;

-- La garde des lunes compte les séances plafonnées — le corps de 20260918083033:132-147,
-- déplacé dans cartes_prive par 20260918084850 ; une seule ligne change.
create or replace function cartes_prive.tirer_noeud_chemin(p_noeud integer,p_pieces boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare n integer; seuil integer;
begin
 if auth.uid() is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
 if p_noeud is null or p_noeud<0 or p_noeud>=45 or p_noeud%9 not in (3,8) then
   raise sqlstate 'PT400' using message='noeud_invalide'; end if;
 -- Un ancien claim reste rejouable ; aucun nouveau droit n'est inventé.
 if not exists(select 1 from public.noeuds_chemin_reclames() r where r.noeud_id=p_noeud) then
   select count(*) into n from public.seances_chemin_plafonnees();
   seuil:=(p_noeud/9)*7+case when p_noeud%9=3 then 3 else 7 end;
   if n<seuil then raise sqlstate 'PT409' using message='progression_insuffisante'; end if;
 end if;
 return public.tirer_noeud_chemin_valide_interne(p_noeud,p_pieces);
end $$;

-- La clôture ne paie rien au-delà du plafond — le corps de 20260918083033:93-112, déplacé
-- dans cartes_prive par 20260918084850 ; un bloc s'ajoute avant le paiement.
create or replace function cartes_prive.cloturer_seance(p_workout uuid,p_series integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); w public.workouts; n integer; r jsonb; c jsonb;
begin
  if u is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
  if p_workout is null or p_series is null or p_series<0 then raise sqlstate 'PT400' using message='cloture_invalide'; end if;
  select * into w from public.workouts where id=p_workout for update;
  if not found then raise sqlstate 'PT503' using message='seance_a_synchroniser'; end if;
  if w.user_id<>u then raise sqlstate 'PT403' using message='seance_inaccessible'; end if;
  if w.ended_at is null or w.sync_complete_at is null then raise sqlstate 'PT503' using message='seance_a_synchroniser'; end if;
  if w.ended_at<w.started_at or w.ended_at>now()+interval '5 minutes' then raise sqlstate 'PT400' using message='dates_invalides'; end if;
  select count(*)::integer into n from public.strength_sets s join public.logged_exercises e on e.id=s.logged_exercise_id
    where e.workout_id=p_workout and e.user_id=u and s.user_id=u;
  -- p_series est un contrôle de complétude, jamais la source du montant.
  if n<>p_series then raise sqlstate 'PT503' using message='series_a_synchroniser'; end if;
  -- LE PLAFOND DU JOUR (20-09) : une séance AVEC travail au-delà des deux premières de son
  -- jour local ne paie rien — ni pièces, ni sachet, ni faits — et le dit. La séance reste
  -- (historique, story) ; le reçu de la clôture garde cette réponse : rejouée, la même.
  if exists(select 1 from public.seances_chemin() sc where sc.id=p_workout)
     and not exists(select 1 from public.seances_chemin_plafonnees() sp where sp.id=p_workout) then
    c:=public.etat_coffre();
    return jsonb_build_object('ok',true,'workout_id',p_workout,'plafond_jour',true,
      'pieces',0,'pieces_creditees',false,'pieces_cardio',0,'pieces_total',0,
      'booster_neuf',false,'argent',false,'argent_seance',false,'sachets_convertis',0,'rejeu',false,
      'solde',coalesce((c->>'solde_or')::integer,0),'solde_argent',coalesce((c->>'solde_argent')::integer,0),
      'reste',coalesce((c->>'reste')::integer,0),'prix_booster',coalesce((c->>'prix_booster')::integer,100),
      'faits','[]'::jsonb,'faits_raison','plafond_jour','series_verifiees',n);
  end if;
  r:=public.cloturer_seance_validee_interne(p_workout,n);
  if r->>'booster_id' is null then r:=r||jsonb_build_object('booster_neuf',false); end if;
  return r||jsonb_build_object('series_verifiees',n);
end $$;
