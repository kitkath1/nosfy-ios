-- Ce banc entier est exécuté AVEC la migration dans BEGIN / ROLLBACK.
do $$
declare u uuid:=gen_random_uuid(); v uuid:=gen_random_uuid(); b uuid; op uuid; j jsonb; k jsonb; previous text;
 i integer; n integer; commun integer:=0; attente integer:=0; firstlegend boolean:=false;
begin
 insert into auth.users(id) values(u),(v);
 perform set_config('request.jwt.claim.sub',u::text,true);
 if (public.etat_coffre()->>'boosters_or')::int<>0 then raise exception 'compte_vide'; end if;
 for i in 1..7 loop
   insert into public.cards(famille,rarete,scene,art_path,reference,monde,noms,art_sha256)
   values('QA'||i,case when i=1 then 'common' when i=2 then 'rare' when i=3 then 'epic' else 'legendary' end,
    '', 'qa/'||i, 'qa-'||i,'qa',jsonb_build_object('fr','QA'||i,'en','QA'||i),repeat('a',64));
 end loop;
 update public.cards set publication='publiee' where reference like 'qa-%';
 update public.reward_rules set value='true'::jsonb where key='cartes_catalogue_actif';
 -- Noir offert, repris au-delà de6h, aucune pièce argent requise.
 insert into public.user_boosters(user_id,origine,robe,opened_at) values(u,'cadeau','noire',now()-interval '2 days') returning id into b;
 if (public.etat_coffre()->>'boosters_noirs')::int<>1 or (public.etat_coffre()->>'boosters_or')::int<>0 then raise exception 'stock_noir'; end if;
 op:=gen_random_uuid();j:=public.preparer_booster(op,true);
 if j->>'booster_id'<>b::text or (j->>'prix')::int<>0 then raise exception 'noir_debite'; end if;
 j:=public.attribuer_carte(b);k:=public.attribuer_carte(b);
 if j->'card'->>'rarete'<>'legendary' or j->>'acquisition_id'<>k->>'acquisition_id' then raise exception 'noir_rejeu'; end if;
 if public.preparer_booster(op,true)->>'booster_id'<>b::text then raise exception 'operation_rejouee'; end if;
 perform public.confirmer_revelation(b);
 perform set_config('request.jwt.claim.sub',v::text,true);
 begin perform public.attribuer_carte(b); raise exception 'carte_etrangere_acceptee'; exception when sqlstate 'PT404' then null; end;
 if public.ma_collection()<>'[]'::jsonb then raise exception 'collection_etrangere'; end if;
 -- Refus catalogue : sachet et compteurs intacts.
 insert into public.user_boosters(user_id,origine) values(v,'cadeau') returning id into b;
 op:=gen_random_uuid();perform public.preparer_booster(op,false);
 update public.reward_rules set value='false'::jsonb where key='cartes_catalogue_actif';
 begin perform public.attribuer_carte(b); raise exception 'catalogue_ferme_accepte'; exception when sqlstate 'PT503' then null; end;
 if exists(select 1 from public.user_cards where user_id=v) then raise exception 'attribution_partielle'; end if;
 update public.reward_rules set value='true'::jsonb where key='cartes_catalogue_actif';
 j:=public.attribuer_carte(b);
 if j->'card'->>'rarete'='common' then raise exception 'premiere_commune'; end if;
 perform public.confirmer_revelation(b);
 for i in 1..100 loop
   insert into public.user_boosters(user_id,origine) values(v,'cadeau') returning id into b;
   perform public.preparer_booster(gen_random_uuid(),false); j:=public.attribuer_carte(b);
   if j->'card'->>'rarete'='common' then commun:=commun+1; else commun:=0; end if;
   if commun>2 then raise exception 'trois_communes'; end if;
   select depuis_legendaire into attente from cartes_prive.comptes where user_id=v;
   if attente>=8 then raise exception 'garantie_huit'; end if;
   if i=5 and not (select legendaire_obtenue from cartes_prive.comptes where user_id=v) then raise exception 'garantie_six'; end if;
   previous:=j->>'acquisition_id'; k:=public.attribuer_carte(b);
   if previous<>k->>'acquisition_id' then raise exception 'double_acquisition'; end if;
   perform public.confirmer_revelation(b);
 end loop;
 if (select count(*) from public.user_cards where user_id=v)<>101 then raise exception 'stock_exemplaires'; end if;
 select sum((x->>'nombre')::int) into n from jsonb_array_elements(public.ma_collection()) x;
 if n<>101 then raise exception 'doublons_perdus'; end if;
 -- Immuabilité de l'art publié.
 begin update public.cards set art_path='remplacement' where reference='qa-1'; raise exception 'art_remplace';
 exception when raise_exception then if sqlerrm<>'reference_publiee_immuable' then raise; end if; end;
 -- Gains/conversions sous un reçu :150+80 ->2 sachets,30pièces.
 perform set_config('request.jwt.claim.sub',u::text,true);
 insert into public.coin_ledger(user_id,delta,raison,currency) values(u,80,'cadeau','yellow');
 insert into cartes_prive.recus(user_id,cause,resultat) values(u,'qa:credit','{}'::jsonb) returning id into op;
 perform set_config('nosfy.receipt_id',op::text,true);
 insert into public.coin_ledger(user_id,delta,raison,currency) values(u,150,'cadeau','yellow');
 perform set_config('nosfy.receipt_id','',true);
 j:=cartes_prive.enveloppe(op);
 if public.solde_or()<>30 or jsonb_array_length(j->'booster_ids')<>2 or jsonb_array_length(j->'events')<>3 then raise exception 'conversion_recu'; end if;
 perform public.acquitter_annonces(array(select (e->>'id')::uuid from jsonb_array_elements(j->'events') e));
 if jsonb_array_length(cartes_prive.enveloppe(op)->'events')<>0 then raise exception 'acquittement'; end if;
end $$;
select 'PASS: noirs, reprise2jours, rejeu, isolement, catalogue fermé, garanties6/8, communes,101exemplaires,immuabilité,conversion,annonces' as resultat;
