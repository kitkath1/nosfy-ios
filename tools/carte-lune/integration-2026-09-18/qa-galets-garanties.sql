begin;
-- Fixtures isolées et règles forcées dans cette transaction uniquement.
-- ROLLBACK final : aucun compte, gain ou réglage ne reste publié.
do $$
declare u uuid; w uuid; e uuid; b uuid; rec jsonb; again jsonb; c jsonb;
 couleur integer; i integer; avant integer; ids uuid[];
begin
 for couleur in 1..2 loop
  u:=gen_random_uuid(); insert into auth.users(id) values(u);
  perform set_config('request.jwt.claim.sub',u::text,true);
  for i in 1..7 loop
   w:=gen_random_uuid();e:=gen_random_uuid();
   perform public.synchroniser_seance(
     jsonb_build_object('id',w,'user_id',u,'started_at',now()-interval '20 minutes','ended_at',now()-interval '2 seconds'),
     jsonb_build_array(jsonb_build_object('id',e,'user_id',u,'workout_id',w,'exercise_id','hip-thrust','position',0)),
     jsonb_build_array(jsonb_build_object('id',gen_random_uuid(),'user_id',u,'logged_exercise_id',e,'reps',10,'weight',5,'position',0)),
     '[]'::jsonb,'[]'::jsonb);
   rec:=public.cloturer_seance(w,1);
   if i in (2,5) then
    b:=(public.preparer_booster(gen_random_uuid(),false)->>'booster_id')::uuid;
    c:=public.attribuer_carte(b);
    if c->'card'->>'rarete'<>'legendary' then raise exception 'garantie_seances_%',i;end if;
    perform public.confirmer_revelation(b);
   end if;
  end loop;
  if (select count(*) from cartes_prive.seances where user_id=u)<>7 then raise exception 'seances_comptees';end if;
  avant:=(public.etat_coffre()->>'boosters_or')::int;
  update public.reward_rules set value=to_jsonb(case when couleur=1 then 0 else 1 end) where key='chemin_taux_double_legendaire';
  update public.reward_rules set value='1'::jsonb where key='chemin_taux_rare';
  rec:=public.tirer_noeud_chemin(8,false);again:=public.tirer_noeud_chemin(8,false);
  if rec->>'receipt_id'<>again->>'receipt_id' or jsonb_array_length(rec->'booster_ids')<>2 then raise exception 'recu_galet';end if;
  if couleur=1 and (rec->'robes'<>'["lune","noire"]'::jsonb or (rec->'coffre'->>'boosters_noirs')::int<>1 or (rec->'coffre'->>'boosters_or')::int<>avant+1) then raise exception 'galet_mixte';end if;
  if couleur=2 and (rec->'robes'<>'["noire","noire"]'::jsonb or (rec->'coffre'->>'boosters_noirs')::int<>2 or (rec->'coffre'->>'boosters_or')::int<>avant) then raise exception 'galet_double_noir';end if;
  for i in 1..couleur loop
   rec:=public.preparer_booster(gen_random_uuid(),true);
   if (rec->>'prix')::int<>0 then raise exception 'noir_galet_payant';end if;
   b:=(rec->>'booster_id')::uuid;c:=public.attribuer_carte(b);
   if c->'card'->>'rarete'<>'legendary' then raise exception 'noir_galet_non_legendaire';end if;
   perform public.confirmer_revelation(b);
  end loop;
  if (public.etat_coffre()->>'boosters_noirs')::int<>0 then raise exception 'reste_noir';end if;
 end loop;
end $$;
select 'PASS: garanties2/3seances,galets orange+noir et noir+noir,recu unique,deux noirs gratuits et legendaires' resultat;
rollback;
