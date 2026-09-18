-- Nosfy : catalogue commun, attribution atomique et reçus des récompenses.
-- Additif : aucune carte possédée, aucun gain historique n'est supprimé.
create schema if not exists cartes_prive;
revoke all on schema cartes_prive from public, anon, authenticated;

alter table public.cards add column reference text unique;
alter table public.cards add column monde text;
alter table public.cards add column noms jsonb not null default '{}'::jsonb;
alter table public.cards add column personnage text;
alter table public.cards add column finition text not null default 'peinte';
alter table public.cards add column art_sha256 text;
alter table public.cards add column publication text not null default 'brouillon'
  check(publication in ('brouillon','publiee','retiree'));
-- Les anciens arts restent aux propriétaires, hors des nouveaux tirages.
update public.cards set publication='retiree', noms=jsonb_build_object('fr',famille,'en',famille);
create index cards_publiees_rarete on public.cards(rarete,id) where publication='publiee';
drop policy "le pool est lisible par tous les comptes" on public.cards;
create policy "les cartes possedees restent lisibles" on public.cards for select to authenticated
 using(exists(select 1 from public.user_cards u where u.card_id=cards.id and u.user_id=(select auth.uid())));
create index user_cards_reference on public.user_cards(user_id,card_id);
alter table public.user_cards add column booster_id uuid references public.user_boosters(id) on delete set null;
create unique index user_cards_un_sachet on public.user_cards(booster_id) where booster_id is not null;

create table cartes_prive.comptes (
 user_id uuid primary key references auth.users(id) on delete cascade,
 version bigint not null default 0,
 ordinaires integer not null default 0,
 depuis_legendaire integer not null default 0,
 communes integer not null default 0,
 legendaire_obtenue boolean not null default false,
 seances_au_dernier integer not null default 0
);
create table cartes_prive.seances (
 workout_id uuid primary key references public.workouts(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 counted_at timestamptz not null default now()
);
create index cartes_seances_user on cartes_prive.seances(user_id);
create table cartes_prive.recus (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 cause text not null,
 resultat jsonb,
 created_at timestamptz not null default now(),
 unique(user_id,cause)
);
create table cartes_prive.evenements (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 receipt_id uuid not null references cartes_prive.recus(id) on delete cascade,
 source_id uuid not null,
 genre text not null,
 montant integer not null,
 motif text not null,
 created_at timestamptz not null default clock_timestamp(),
 vu_at timestamptz,
 unique(source_id,genre)
);
create index cartes_evenements_attente on cartes_prive.evenements(user_id,created_at,id) where vu_at is null;
create index cartes_evenements_recu on cartes_prive.evenements(receipt_id);
insert into cartes_prive.comptes(user_id,legendaire_obtenue)
select u.user_id,bool_or(c.rarete='legendary') from public.user_cards u join public.cards c on c.id=u.card_id group by u.user_id;
alter table cartes_prive.comptes enable row level security;
alter table cartes_prive.seances enable row level security;
alter table cartes_prive.recus enable row level security;
alter table cartes_prive.evenements enable row level security;
alter table public.user_boosters add column receipt_id uuid references cartes_prive.recus(id) on delete set null;
alter table public.user_boosters add column revealed_at timestamptz;
update public.user_boosters set revealed_at=coalesce(opened_at,obtained_at) where card_id is not null;
alter table public.coin_ledger add column receipt_id uuid references cartes_prive.recus(id) on delete set null;
create index user_boosters_receipt on public.user_boosters(receipt_id) where receipt_id is not null;
create index coin_ledger_receipt on public.coin_ledger(receipt_id) where receipt_id is not null;

create function cartes_prive.verrouiller() returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid();
begin
 if u is null then raise sqlstate 'PT401' using message='connexion_requise'; end if;
 -- Même verrou que convertir_pieces ; pris avant toute ligne de séance/sachet.
 perform pg_advisory_xact_lock(hashtext(u::text));
 insert into cartes_prive.comptes(user_id,legendaire_obtenue)
 select u,exists(select 1 from public.user_cards uc join public.cards c on c.id=uc.card_id
                 where uc.user_id=u and c.rarete='legendary') on conflict do nothing;
 return u;
end $$;

create function cartes_prive.tracer() returns trigger language plpgsql security definer set search_path='' as $$
declare r uuid:=nullif(current_setting('nosfy.receipt_id',true),'')::uuid; g text;
begin
 -- Les écritures économiques sérialisent aussi les versions du coffre.
 perform pg_advisory_xact_lock(hashtext(new.user_id::text));
 insert into cartes_prive.comptes(user_id,version) values(new.user_id,1)
 on conflict(user_id) do update set version=cartes_prive.comptes.version+1;
 if TG_OP='INSERT' and r is not null then
   if not exists(select 1 from cartes_prive.recus where id=r and user_id=new.user_id) then
     raise exception 'recu_incoherent'; end if;
   new.receipt_id:=r;
   if TG_TABLE_NAME='coin_ledger' then
     if new.delta<=0 then return new; end if;
     g:=case when new.currency='silver' then 'argent' when new.raison='retour_quotidien' then 'retour'
       when new.raison='cardio_seance' then 'cardio' else 'pieces' end;
     insert into cartes_prive.evenements(user_id,receipt_id,source_id,genre,montant,motif)
     values(new.user_id,r,new.id,g,new.delta,new.raison);
   else
     -- Un noir acheté est une dépense confirmée, pas une annonce de cadeau.
     if new.origine<>'legendaire' then
       insert into cartes_prive.evenements(user_id,receipt_id,source_id,genre,montant,motif)
       values(new.user_id,r,new.id,case when new.robe='noire' then 'noir' else 'sachet' end,1,new.origine);
     end if;
   end if;
 end if;
 return new;
end $$;
create trigger cartes_ledger_recu before insert on public.coin_ledger for each row execute function cartes_prive.tracer();
create trigger cartes_sachet_recu before insert or update on public.user_boosters for each row execute function cartes_prive.tracer();

create function cartes_prive.arts_immuables() returns trigger language plpgsql set search_path='' as $$
begin
 if old.publication<>'brouillon' and
   (to_jsonb(new)-'publication') is distinct from (to_jsonb(old)-'publication') then
   raise exception 'reference_publiee_immuable'; end if;
 if new.publication='publiee' and (new.reference is null or new.monde is null or
   new.art_sha256 !~ '^[a-f0-9]{64}$' or new.art_sha256 is null or
   nullif(new.noms->>'fr','') is null or nullif(new.noms->>'en','') is null) then
   raise exception 'reference_incomplete'; end if;
 return new;
end $$;
create trigger cards_immuables before update on public.cards for each row execute function cartes_prive.arts_immuables();

-- Préserver les barèmes et les validations Compte83033 derrière les nouvelles enveloppes.
alter function public.cloturer_seance(uuid,integer) set schema cartes_prive;
alter function public.tirer_noeud_chemin(integer,boolean) set schema cartes_prive;
alter function public.claim_retour_quotidien() set schema cartes_prive;
alter function public.etat_coffre() set schema cartes_prive;

create or replace function public.etat_coffre() returns jsonb language sql stable security definer set search_path='' as $$
 select cartes_prive.etat_coffre() || jsonb_build_object(
 'inventory_version',coalesce((select version from cartes_prive.comptes where user_id=auth.uid()),0),
 'boosters_or',(select count(*) from public.user_boosters where user_id=auth.uid() and revealed_at is null
   and origine<>'legendaire' and coalesce(robe,'lune')<>'noire'),
 'boosters_noirs',(select count(*) from public.user_boosters where user_id=auth.uid() and revealed_at is null
   and (origine='legendaire' or robe='noire')),
 -- Compatibilité des anciennes apps : elles additionnent argent + noirs_ouverts.
 'noirs_ouverts',(select count(*) from public.user_boosters where user_id=auth.uid() and revealed_at is null
   and (origine='legendaire' or robe='noire')),
 'prix_booster_legendaire',greatest(public.regle_num('prix_booster_legendaire',1)::integer,1),
 'boosters',coalesce((select jsonb_agg(jsonb_build_object('id',id,'noir',origine='legendaire' or coalesce(robe,'lune')='noire',
    'origine',origine,'reprise',opened_at is not null) order by obtained_at,id)
   from public.user_boosters where user_id=auth.uid() and revealed_at is null),'[]'::jsonb)
 );
$$;

create function cartes_prive.enveloppe(p_recu uuid,p_rejeu boolean default false) returns jsonb
language sql stable security definer set search_path='' as $$
 select r.resultat || jsonb_build_object('receipt_id',r.id,'user_id',r.user_id,'receipt_replay',p_rejeu,
 'inventory_version',coalesce((select version from cartes_prive.comptes where user_id=r.user_id),0),
 'coffre',public.etat_coffre(),
 'events',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'user_id',e.user_id,'genre',e.genre,'montant',e.montant,
   'motif',e.motif,'source_id',e.source_id,'receipt_id',e.receipt_id) order by e.created_at,e.id)
   from cartes_prive.evenements e where e.receipt_id=r.id and e.vu_at is null),'[]'::jsonb),
 'booster_ids',coalesce((select jsonb_agg(b.id order by b.obtained_at,b.id) from public.user_boosters b
   where b.receipt_id=r.id),'[]'::jsonb))
 from cartes_prive.recus r where r.id=p_recu and r.user_id=auth.uid();
$$;

create or replace function public.cloturer_seance(p_workout uuid,p_series integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=cartes_prive.verrouiller(); r cartes_prive.recus; j jsonb;
begin
 if p_workout is null or p_series is null or p_series<0 then raise sqlstate 'PT400' using message='cloture_invalide'; end if;
 select * into r from cartes_prive.recus where user_id=u and cause='seance:'||p_workout::text;
 if found then return cartes_prive.enveloppe(r.id,true)||jsonb_build_object('rejeu',true,'booster_neuf',false,
   'pieces_creditees',false,'argent',false,'sachet_cardio',false,'cardio_rejeu',true,'sachets_convertis',0); end if;
 insert into cartes_prive.recus(user_id,cause) values(u,'seance:'||p_workout::text) returning * into r;
 perform set_config('nosfy.receipt_id',r.id::text,true);
 j:=cartes_prive.cloturer_seance(p_workout,p_series);
 if j->>'booster_id' is not null then
   insert into cartes_prive.seances(workout_id,user_id) values(p_workout,u) on conflict do nothing;
 end if;
 update cartes_prive.recus set resultat=j where id=r.id;
 perform set_config('nosfy.receipt_id','',true);
 return cartes_prive.enveloppe(r.id);
end $$;

create or replace function public.tirer_noeud_chemin(p_noeud integer,p_pieces boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=cartes_prive.verrouiller(); r cartes_prive.recus; j jsonb;
begin
 select * into r from cartes_prive.recus where user_id=u and cause='galet:'||p_noeud::text;
 if found then return cartes_prive.enveloppe(r.id,true)||jsonb_build_object('deja_reclame',true,'sachets_convertis',0); end if;
 insert into cartes_prive.recus(user_id,cause) values(u,'galet:'||p_noeud::text) returning * into r;
 perform set_config('nosfy.receipt_id',r.id::text,true);
 j:=cartes_prive.tirer_noeud_chemin(p_noeud,p_pieces);
 update cartes_prive.recus set resultat=j where id=r.id;
 perform set_config('nosfy.receipt_id','',true);
 return cartes_prive.enveloppe(r.id);
end $$;

create or replace function public.claim_retour_quotidien() returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=cartes_prive.verrouiller(); r cartes_prive.recus; j jsonb;
begin
 select * into r from cartes_prive.recus where user_id=u and cause='retour:'||public.jour_courant()::text;
 if found then return cartes_prive.enveloppe(r.id,true)||jsonb_build_object('credite',false,'montant',0,'sachets_convertis',0); end if;
 insert into cartes_prive.recus(user_id,cause) values(u,'retour:'||public.jour_courant()::text) returning * into r;
 perform set_config('nosfy.receipt_id',r.id::text,true);
 j:=cartes_prive.claim_retour_quotidien();
 if j->>'raison'='premiere_seance_requise' then
   delete from cartes_prive.recus where id=r.id;
   perform set_config('nosfy.receipt_id','',true); return j; end if;
 update cartes_prive.recus set resultat=j where id=r.id;
 perform set_config('nosfy.receipt_id','',true);
 return cartes_prive.enveloppe(r.id);
end $$;

create function public.preparer_booster(p_operation uuid,p_legendaire boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
declare u uuid:=cartes_prive.verrouiller(); r cartes_prive.recus; b public.user_boosters; prix integer:=0; reprise boolean;
begin
 if p_operation is null or p_legendaire is null then raise sqlstate 'PT400' using message='operation_requise'; end if;
 select * into r from cartes_prive.recus where user_id=u and cause='ouvrir:'||p_operation::text;
 if found then
   if (r.resultat->>'noir')::boolean<>p_legendaire then raise sqlstate 'PT409' using message='operation_differente'; end if;
   return cartes_prive.enveloppe(r.id,true); end if;
 if not coalesce((select value='true'::jsonb from public.reward_rules where key='cartes_catalogue_actif'),false)
    or (select count(distinct rarete) from public.cards where publication='publiee')<>4 then
   raise sqlstate 'PT503' using message='catalogue_en_preparation'; end if;
 insert into cartes_prive.recus(user_id,cause) values(u,'ouvrir:'||p_operation::text) returning * into r;
 perform set_config('nosfy.receipt_id',r.id::text,true);
 select * into b from public.user_boosters where user_id=u and revealed_at is null
   and (origine='legendaire' or coalesce(robe,'lune')='noire')=p_legendaire
   order by (opened_at is null),obtained_at,id limit 1 for update;
 reprise:=b.opened_at is not null;
 if b.id is null and p_legendaire then
   prix:=greatest(public.regle_num('prix_booster_legendaire',1)::integer,1);
   if public.solde_argent()<prix then raise sqlstate 'PT409' using message='argent_insuffisant'; end if;
   insert into public.user_boosters(user_id,origine,robe,opened_at) values(u,'legendaire','noire',now()) returning * into b;
   insert into public.coin_ledger(user_id,delta,raison,currency,booster_id)
     values(u,-prix,'ouverture_booster_noir','silver',b.id);
 elsif b.id is null then raise sqlstate 'PT409' using message='aucun_sachet';
 elsif b.opened_at is null then update public.user_boosters set opened_at=now() where id=b.id;
 end if;
 update cartes_prive.recus set resultat=jsonb_build_object('ouvert',true,'booster_id',b.id,'noir',p_legendaire,
   'reprise',reprise,'prix',prix,'solde_argent',public.solde_argent()) where id=r.id;
 perform set_config('nosfy.receipt_id','',true);
 return cartes_prive.enveloppe(r.id);
end $$;

create or replace function public.ouvrir_booster(p_legendaire boolean default false) returns jsonb
language plpgsql security definer set search_path='' as $$
begin return public.preparer_booster(gen_random_uuid(),p_legendaire);
exception when sqlstate 'PT409' then return jsonb_build_object('ouvert',false,'raison',sqlerrm); end $$;
create or replace function public.claim_booster_legendaire() returns jsonb
language plpgsql security definer set search_path='' as $$
begin return public.preparer_booster(gen_random_uuid(),true);
exception when sqlstate 'PT409' then return jsonb_build_object('ouvert',false,'raison',sqlerrm); end $$;

insert into public.reward_rules(key,value) values('cartes_catalogue_actif','false'::jsonb) on conflict do nothing;

create function public.attribuer_carte(p_booster uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=cartes_prive.verrouiller(); b public.user_boosters; c public.cards; a public.user_cards; w uuid;
 p cartes_prive.comptes; n integer; noir boolean; rare text; alea double precision; reprise boolean:=false;
begin
 select * into b from public.user_boosters where id=p_booster and user_id=u for update;
 if not found then raise sqlstate 'PT404' using message='sachet_inconnu'; end if;
 if b.opened_at is null then raise sqlstate 'PT409' using message='sachet_non_ouvert'; end if;
 if b.card_id is not null then
   select * into c from public.cards where id=b.card_id;
   select * into a from public.user_cards where booster_id=b.id and user_id=u;
   -- L'historique antérieur n'est pas ré-attribué faute de preuve de provenance.
   reprise:=true;
 else
   if not coalesce((select value='true'::jsonb from public.reward_rules where key='cartes_catalogue_actif'),false) then
     raise sqlstate 'PT503' using message='catalogue_en_preparation'; end if;
   if (select count(distinct rarete) from public.cards where publication='publiee')<>4 then
     raise sqlstate 'PT503' using message='catalogue_incomplet'; end if;
   select * into p from cartes_prive.comptes where user_id=u for update;
   select count(*) into n from cartes_prive.seances where user_id=u;
   noir:=b.origine='legendaire' or coalesce(b.robe,'lune')='noire';
   if noir or p.depuis_legendaire+1 >= (case when p.legendaire_obtenue then 8 else 6 end)
     or n-p.seances_au_dernier >= (case when p.legendaire_obtenue then 3 else 2 end) then rare:='legendary';
   else
     alea:=random();
     -- Retirer les communes puis renormaliser (35/15/5), sans changer les poids entre rares+.
     if p.ordinaires=0 or p.communes>=2 then alea:=0.45+alea*0.55; end if;
     rare:=case when alea<0.45 then 'common' when alea<0.80 then 'rare' when alea<0.95 then 'epic' else 'legendary' end;
   end if;
   -- Les trois premières légendaires distinctes sont découvertes avant les doublons.
   select * into c from public.cards c0 where publication='publiee' and rarete=rare
     order by case when rare='legendary' and exists(select 1 from public.user_cards uc where uc.user_id=u and uc.card_id=c0.id)
       then 1 else 0 end,random() limit 1;
   if c.id is null then raise sqlstate 'PT503' using message='rarete_indisponible'; end if;
   w:=b.workout_id;
   if w is null and b.receipt_id is not null then
     select substring(cause from 8)::uuid into w from cartes_prive.recus
       where id=b.receipt_id and user_id=u and cause like 'seance:%';
   end if;
   insert into public.user_cards(user_id,card_id,booster_id,workout_id)
     values(u,c.id,b.id,w) returning * into a;
   update public.user_boosters set card_id=c.id where id=b.id;
   update cartes_prive.comptes set
     ordinaires=ordinaires+case when noir then 0 else 1 end,
     depuis_legendaire=case when rare='legendary' then 0 when noir then depuis_legendaire else depuis_legendaire+1 end,
     communes=case when noir then communes when rare='common' then communes+1 else 0 end,
     legendaire_obtenue=legendaire_obtenue or rare='legendary',
     seances_au_dernier=case when rare='legendary' then n else seances_au_dernier end
     where user_id=u;
 end if;
 return jsonb_build_object('card',jsonb_build_object('id',c.id,'reference',c.reference,'famille',c.famille,
   'noms',c.noms,'monde',c.monde,'rarete',c.rarete,'finition',c.finition,'scene',c.scene,'art_path',c.art_path,
   'art_sha256',c.art_sha256,'fraiche',false),
   'acquisition_id',a.id,'booster_id',b.id,'workout_id',a.workout_id,'rejeu',reprise,
   'coffre',public.etat_coffre());
end $$;

create or replace function public.ma_collection() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(jsonb_build_object('famille',c.famille,'rarete',c.rarete,'nombre',u.nombre,
   'card_id',c.id,'art_path',c.art_path,'art_sha256',c.art_sha256,'noms',c.noms,'monde',c.monde,
   'reference',c.reference,'finition',c.finition,'premiere',u.premiere,'derniere',u.derniere,
   'acquisitions',u.acquisitions) order by u.premiere,c.id),'[]'::jsonb)
 from (select card_id,count(*)::int nombre,min(obtained_at) premiere,max(obtained_at) derniere,
   jsonb_agg(jsonb_build_object('id',id,'booster_id',booster_id,'workout_id',workout_id,'obtained_at',obtained_at) order by obtained_at,id) acquisitions
   from public.user_cards where user_id=auth.uid() group by card_id) u join public.cards c on c.id=u.card_id;
$$;
create function public.confirmer_revelation(p_booster uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=cartes_prive.verrouiller();
begin
 update public.user_boosters set revealed_at=coalesce(revealed_at,now())
 where id=p_booster and user_id=u and card_id is not null;
 if not found then raise sqlstate 'PT404' using message='carte_inconnue'; end if;
 return public.etat_coffre();
end $$;
create function public.totaux_cartes() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_object_agg(rarete,total),'{}'::jsonb) from
 (select rarete,count(*)::int total from public.cards c where publication='publiee' or
    exists(select 1 from public.user_cards u where u.user_id=auth.uid() and u.card_id=c.id) group by rarete) t;
$$;
create function public.annonces_en_attente() returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(j order by created_at,id),'[]'::jsonb) from
 (select id,created_at,jsonb_build_object('id',id,'user_id',user_id,'genre',genre,'montant',montant,'motif',motif,
   'source_id',source_id,'receipt_id',receipt_id) j from cartes_prive.evenements
  where user_id=auth.uid() and vu_at is null order by created_at,id limit 100) e;
$$;
create function public.acquitter_annonces(p_ids uuid[]) returns void language sql security definer set search_path='' as $$
 update cartes_prive.evenements set vu_at=coalesce(vu_at,now()) where user_id=auth.uid() and id=any(p_ids);
$$;
-- Nouveau nom pour conserver le type de retour de l'ancienne fonction.
create function public.historique_gains_identifie(p_limite integer default 60) returns jsonb
language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(to_jsonb(h) order by quand desc,id),'[]'::jsonb) from (
 select id,created_at quand,'coins'::text genre,raison motif,delta montant,currency monnaie,null::text robe,receipt_id
   from public.coin_ledger where user_id=auth.uid() and delta>0
 union all select id,obtained_at,'booster',origine,1,null,case when origine='legendaire' then 'noire' else coalesce(robe,'lune') end,receipt_id
   from public.user_boosters where user_id=auth.uid()
 order by 2 desc,1 limit least(greatest(coalesce(p_limite,60),1),200)) h;
$$;

revoke all on all tables in schema cartes_prive from public,anon,authenticated;
revoke all on all functions in schema cartes_prive from public,anon,authenticated;
revoke all on function public.etat_coffre(), public.cloturer_seance(uuid,integer), public.tirer_noeud_chemin(integer,boolean),
 public.claim_retour_quotidien(),public.preparer_booster(uuid,boolean),public.ouvrir_booster(boolean),public.claim_booster_legendaire(),
 public.attribuer_carte(uuid),public.ma_collection(),public.totaux_cartes(),public.annonces_en_attente(),public.acquitter_annonces(uuid[]),
 public.historique_gains_identifie(integer),public.confirmer_revelation(uuid) from public,anon;
grant execute on function public.etat_coffre(), public.cloturer_seance(uuid,integer), public.tirer_noeud_chemin(integer,boolean),
 public.claim_retour_quotidien(),public.preparer_booster(uuid,boolean),public.ouvrir_booster(boolean),public.claim_booster_legendaire(),
 public.attribuer_carte(uuid),public.ma_collection(),public.totaux_cartes(),public.annonces_en_attente(),public.acquitter_annonces(uuid[]),
 public.historique_gains_identifie(integer),public.confirmer_revelation(uuid) to authenticated;

notify pgrst,'reload schema';
