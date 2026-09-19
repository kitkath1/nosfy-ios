CREATE OR REPLACE FUNCTION public.attribuer_carte(p_booster uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
end $function$
