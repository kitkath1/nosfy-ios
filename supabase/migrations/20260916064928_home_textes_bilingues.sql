-- Home FR/EN : catalogue commun, sans prénom, compteur ni autre donnée privée.
-- Les clients lisent ; seule l'administration peut publier un lot relu.
create table public.home_textes_lots (
  langue text primary key check (langue in ('fr', 'en')),
  revision text not null check (length(revision) between 1 and 64),
  contenu jsonb not null check (
    jsonb_typeof(contenu) = 'object' and contenu->>'schema' = '1'
    and contenu->>'langue' = langue and contenu->>'revision' = revision
    and jsonb_typeof(contenu->'variantes') = 'object'
    and (contenu->'variantes') ?& array['vide','active_zero','active','seance_debut','seance','depart']
  ),
  origine text not null,
  updated_at timestamptz not null default now()
);
alter table public.home_textes_lots enable row level security;
revoke all on public.home_textes_lots from public, anon, authenticated;
grant select on public.home_textes_lots to authenticated;
grant select, insert, update, delete on public.home_textes_lots to service_role;
-- Les phrases sont communes à tous les comptes : aucune colonne user_id ici.
create policy home_textes_lecture on public.home_textes_lots for select to authenticated using (true);
comment on table public.home_textes_lots is 'Gabarits de Home sans données personnelles ; lots FR/EN validés, publiés par home-textes, servis par home().';

insert into public.home_textes_lots(langue, revision, contenu, origine) values ('fr', 'repli-2026-09-16', $lot${"schema":1,"langue":"fr","revision":"repli-2026-09-16","variantes":{"vide":[{"id":"fr-vide-1","fragments":["{salut}","et si on faisait","ta première","séance ?"],"bouton":null},{"id":"fr-vide-2","fragments":["{salut}","ta première séance","t’attend.","On y va."],"bouton":null},{"id":"fr-vide-3","fragments":["{salut}","une nouvelle","histoire commence.","À toi de jouer."],"bouton":null}],"active_zero":[{"id":"fr-active_zero-1","fragments":["{salut}","pas encore","de séance","cette semaine."],"bouton":null},{"id":"fr-active_zero-2","fragments":["{salut}","cette semaine","reste à écrire.","On commence ?"],"bouton":null},{"id":"fr-active_zero-3","fragments":["{salut}","une nouvelle semaine,","un premier pas.","À ton rythme."],"bouton":null}],"active":[{"id":"fr-active-1","fragments":["{salut}","déjà","{seances}","cette semaine."],"bouton":null},{"id":"fr-active-2","fragments":["{salut}","cette semaine,","{seances}","à ton actif."],"bouton":null},{"id":"fr-active-3","fragments":["{salut}","tu en es à","{seances}","cette semaine."],"bouton":null}],"seance_debut":[{"id":"fr-seance_debut-1","fragments":["{allez}","on y est,","la séance","commence."],"bouton":null},{"id":"fr-seance_debut-2","fragments":["{allez}","place à toi,","la séance","est lancée."],"bouton":null},{"id":"fr-seance_debut-3","fragments":["{allez}","un premier geste,","puis la suite.","À ton rythme."],"bouton":null}],"seance":[{"id":"fr-seance-1","fragments":["{allez}","déjà","{minutes}","dans les jambes."],"bouton":null},{"id":"fr-seance-2","fragments":["{allez}","tu en es à","{minutes}","à ton rythme."],"bouton":null},{"id":"fr-seance-3","fragments":["{allez}","la séance dure","{minutes}","un geste à la fois."],"bouton":null}],"depart":[{"id":"fr-depart-1","fragments":["{allez}","glisse pour lancer","ta séance."],"bouton":"C’est parti"},{"id":"fr-depart-2","fragments":["À toi de jouer,","glisse pour lancer","ta séance."],"bouton":"On y va"},{"id":"fr-depart-3","fragments":["On se retrouve,","glisse pour lancer","ta séance."],"bouton":"À toi"},{"id":"fr-depart-4","fragments":["Prends ton temps,","glisse pour lancer","ta séance."],"bouton":"Commencer"},{"id":"fr-depart-5","fragments":["Rien à prouver,","glisse pour lancer","ta séance."],"bouton":"Lance-toi"},{"id":"fr-depart-6","fragments":["Un pas de plus,","glisse pour lancer","ta séance."],"bouton":"C’est parti"},{"id":"fr-depart-7","fragments":["Te voilà,","glisse pour lancer","ta séance."],"bouton":"On y va"},{"id":"fr-depart-8","fragments":["Fais-toi confiance,","glisse pour lancer","ta séance."],"bouton":"À toi"},{"id":"fr-depart-9","fragments":["À ton rythme,","glisse pour lancer","ta séance."],"bouton":"Commencer"},{"id":"fr-depart-10","fragments":["Le moment est là,","glisse pour lancer","ta séance."],"bouton":"Lance-toi"},{"id":"fr-depart-11","fragments":["Place au sport,","glisse pour lancer","ta séance."],"bouton":"C’est parti"},{"id":"fr-depart-12","fragments":["Allume le feu,","glisse pour lancer","ta séance."],"bouton":"On y va"},{"id":"fr-depart-13","fragments":["Fais-toi plaisir,","glisse pour lancer","ta séance."],"bouton":"À toi"},{"id":"fr-depart-14","fragments":["Tout commence ici,","glisse pour lancer","ta séance."],"bouton":"Commencer"},{"id":"fr-depart-15","fragments":["Un peu de cran,","glisse pour lancer","ta séance."],"bouton":"Lance-toi"},{"id":"fr-depart-16","fragments":["On se lance,","glisse pour lancer","ta séance."],"bouton":"C’est parti"},{"id":"fr-depart-17","fragments":["Le canapé attendra,","glisse pour lancer","ta séance."],"bouton":"On y va"},{"id":"fr-depart-18","fragments":["Laisse-toi tenter,","glisse pour lancer","ta séance."],"bouton":"À toi"},{"id":"fr-depart-19","fragments":["Les poids t’attendent,","glisse pour lancer","ta séance."],"bouton":"Commencer"},{"id":"fr-depart-20","fragments":["Réveille la force,","glisse pour lancer","ta séance."],"bouton":"Lance-toi"},{"id":"fr-depart-21","fragments":["À toi la suite,","glisse pour lancer","ta séance."],"bouton":"C’est parti"},{"id":"fr-depart-22","fragments":["Ouvre le bal,","glisse pour lancer","ta séance."],"bouton":"On y va"},{"id":"fr-depart-23","fragments":["C’est ton moment,","glisse pour lancer","ta séance."],"bouton":"À toi"},{"id":"fr-depart-24","fragments":["Change de tempo,","glisse pour lancer","ta séance."],"bouton":"Commencer"},{"id":"fr-depart-25","fragments":["Retrouve ton élan,","glisse pour lancer","ta séance."],"bouton":"Lance-toi"},{"id":"fr-depart-26","fragments":["Une envie de bouger,","glisse pour lancer","ta séance."],"bouton":"C’est parti"},{"id":"fr-depart-27","fragments":["Fais place à toi,","glisse pour lancer","ta séance."],"bouton":"On y va"}]}}$lot$::jsonb, 'repli');
insert into public.home_textes_lots(langue, revision, contenu, origine) values ('en', 'repli-2026-09-16', $lot${"schema":1,"langue":"en","revision":"repli-2026-09-16","variantes":{"vide":[{"id":"en-vide-1","fragments":["{salut}","your first workout","is waiting.","Let’s go."],"bouton":null},{"id":"en-vide-2","fragments":["{salut}","a new chapter","starts here.","Make it yours."],"bouton":null},{"id":"en-vide-3","fragments":["{salut}","your first step","is yours to take.","Whenever you’re ready."],"bouton":null}],"active_zero":[{"id":"en-active_zero-1","fragments":["{salut}","no workout yet","this week.","Let’s go."],"bouton":null},{"id":"en-active_zero-2","fragments":["{salut}","this week","is a blank page.","Make a start."],"bouton":null},{"id":"en-active_zero-3","fragments":["{salut}","a fresh week,","a first step.","At your own pace."],"bouton":null}],"active":[{"id":"en-active-1","fragments":["{salut}","you’ve done","{seances}","this week."],"bouton":null},{"id":"en-active-2","fragments":["{salut}","this week,","{seances}","in the books."],"bouton":null},{"id":"en-active-3","fragments":["{salut}","you’re at","{seances}","this week."],"bouton":null}],"seance_debut":[{"id":"en-seance_debut-1","fragments":["{allez}","you’re in","a session","right now."],"bouton":null},{"id":"en-seance_debut-2","fragments":["{allez}","your session","starts here.","Make it yours."],"bouton":null},{"id":"en-seance_debut-3","fragments":["{allez}","one first move,","then the next.","At your own pace."],"bouton":null}],"seance":[{"id":"en-seance-1","fragments":["{allez}","you’ve been at it","{minutes}","so far."],"bouton":null},{"id":"en-seance-2","fragments":["{allez}","you’re at","{minutes}","at your own pace."],"bouton":null},{"id":"en-seance-3","fragments":["{allez}","this session is","{minutes}","one move at a time."],"bouton":null}],"depart":[{"id":"en-depart-1","fragments":["{allez}","slide to start","your session."],"bouton":"Let’s go"},{"id":"en-depart-2","fragments":["There you are,","slide to start","your session."],"bouton":"Start"},{"id":"en-depart-3","fragments":["Good to see you,","slide to start","your session."],"bouton":"Make a start"},{"id":"en-depart-4","fragments":["Take your time,","slide to start","your session."],"bouton":"Begin"},{"id":"en-depart-5","fragments":["Nothing to prove,","slide to start","your session."],"bouton":"Your move"},{"id":"en-depart-6","fragments":["One more step,","slide to start","your session."],"bouton":"Let’s go"},{"id":"en-depart-7","fragments":["You showed up,","slide to start","your session."],"bouton":"Start"},{"id":"en-depart-8","fragments":["Trust yourself,","slide to start","your session."],"bouton":"Make a start"},{"id":"en-depart-9","fragments":["At your own pace,","slide to start","your session."],"bouton":"Begin"},{"id":"en-depart-10","fragments":["Your moment is here,","slide to start","your session."],"bouton":"Your move"},{"id":"en-depart-11","fragments":["Make room to move,","slide to start","your session."],"bouton":"Let’s go"},{"id":"en-depart-12","fragments":["Start the fire,","slide to start","your session."],"bouton":"Start"},{"id":"en-depart-13","fragments":["Make it yours,","slide to start","your session."],"bouton":"Make a start"},{"id":"en-depart-14","fragments":["It starts here,","slide to start","your session."],"bouton":"Begin"},{"id":"en-depart-15","fragments":["A little courage,","slide to start","your session."],"bouton":"Your move"},{"id":"en-depart-16","fragments":["Let’s get moving,","slide to start","your session."],"bouton":"Let’s go"},{"id":"en-depart-17","fragments":["The couch can wait,","slide to start","your session."],"bouton":"Start"},{"id":"en-depart-18","fragments":["Give it a go,","slide to start","your session."],"bouton":"Make a start"},{"id":"en-depart-19","fragments":["The weights miss you,","slide to start","your session."],"bouton":"Begin"},{"id":"en-depart-20","fragments":["Wake your strength,","slide to start","your session."],"bouton":"Your move"},{"id":"en-depart-21","fragments":["Your next chapter,","slide to start","your session."],"bouton":"Let’s go"},{"id":"en-depart-22","fragments":["Make the first move,","slide to start","your session."],"bouton":"Start"},{"id":"en-depart-23","fragments":["This is your time,","slide to start","your session."],"bouton":"Make a start"},{"id":"en-depart-24","fragments":["Change the tempo,","slide to start","your session."],"bouton":"Begin"},{"id":"en-depart-25","fragments":["Find your rhythm,","slide to start","your session."],"bouton":"Your move"},{"id":"en-depart-26","fragments":["Ready to move,","slide to start","your session."],"bouton":"Let’s go"},{"id":"en-depart-27","fragments":["A moment for you,","slide to start","your session."],"bouton":"Start"}]}}$lot$::jsonb, 'repli');

-- Refuser d'écraser une évolution concurrente de home(). Aucun renommage de RPC,
-- aucune copie contournant son contrôle auth.uid() ni ses droits existants.
do $guard$
begin
  if pg_get_functiondef('public.home()'::regprocedure) <> $attendu$CREATE OR REPLACE FUNCTION public.home()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  p public.profils%rowtype;
  r jsonb;
  v_enc timestamptz;
  v_total integer;
  v_langue text;
  v_min integer;
  v_etat text;
  v_faites integer;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  r := public.widget_regularite('semaine');
  v_faites := coalesce((r->>'faites')::int, 0);
  select w.started_at into v_enc from public.workouts w
   where w.user_id = v_uid and w.ended_at is null order by w.started_at desc limit 1;
  select count(*) into v_total from public.workouts w where w.user_id = v_uid and w.ended_at is not null;
  v_langue := coalesce(nullif(p.langue, ''), 'fr');
  v_min := case when v_enc is null then 0 else floor(extract(epoch from (now() - v_enc)) / 60)::int end;
  v_etat := case
    when v_enc is not null and v_min < 1 then 'seance_debut'
    when v_enc is not null then 'seance'
    when p.onboarding_termine_at is not null and v_total = 0 then 'vide'
    else 'active' end;
  return jsonb_build_object(
    'prenom',             p.prenom,
    'langue',             v_langue,
    'premiere_fois',      p.onboarding_termine_at is not null and v_total = 0,
    'visite_home',        p.visite_home_le is not null,
    'onboarding_termine', p.onboarding_termine_at is not null,
    'faites',             r->'faites',
    'objectif',           r->'objectif',
    'reste',              r->'reste',
    'en_seance',          v_enc is not null,
    'minutes_en_seance',  v_min,
    'derniere_seance_at', (select max(w.ended_at) from public.workouts w where w.user_id = v_uid and w.ended_at is not null),
    'seances_total',      v_total,
    'phrase', jsonb_build_object(
      'etat', v_etat,
      'fragments', public.phrase_home(v_etat, v_langue, p.prenom,
                     case when v_etat = 'active' then v_faites else v_min end)),
    'phrases', jsonb_build_object(
      'vide',         public.phrase_home('vide', v_langue, p.prenom, 0),
      'active',       public.phrase_home('active', v_langue, p.prenom, greatest(v_faites, 1)),
      'active_zero',  public.phrase_home('active', v_langue, p.prenom, 0),
      'seance_debut', public.phrase_home('seance_debut', v_langue, p.prenom, 0),
      'seance',       public.phrase_home('seance', v_langue, p.prenom, greatest(v_min, 1)))
  );
end;
$function$
$attendu$ then
    raise exception 'home() a changé : relire sa définition avant cette migration';
  end if;
end;
$guard$;

CREATE OR REPLACE FUNCTION public.home()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_uid uuid := auth.uid();
  p public.profils%rowtype;
  r jsonb;
  v_enc timestamptz;
  v_total integer;
  v_langue text;
  v_min integer;
  v_etat text;
  v_faites integer;
begin
  if v_uid is null then
    return jsonb_build_object('erreur', 'sans_session');
  end if;
  select * into p from public.profils where user_id = v_uid;
  r := public.widget_regularite('semaine');
  v_faites := coalesce((r->>'faites')::int, 0);
  select w.started_at into v_enc from public.workouts w
   where w.user_id = v_uid and w.ended_at is null order by w.started_at desc limit 1;
  select count(*) into v_total from public.workouts w where w.user_id = v_uid and w.ended_at is not null;
  v_langue := coalesce(nullif(p.langue, ''), 'fr');
  v_min := case when v_enc is null then 0 else floor(extract(epoch from (now() - v_enc)) / 60)::int end;
  v_etat := case
    when v_enc is not null and v_min < 1 then 'seance_debut'
    when v_enc is not null then 'seance'
    when p.onboarding_termine_at is not null and v_total = 0 then 'vide'
    else 'active' end;
  return jsonb_build_object(
    'prenom',             p.prenom,
    'langue',             v_langue,
    'premiere_fois',      p.onboarding_termine_at is not null and v_total = 0,
    'visite_home',        p.visite_home_le is not null,
    'onboarding_termine', p.onboarding_termine_at is not null,
    'faites',             r->'faites',
    'objectif',           r->'objectif',
    'reste',              r->'reste',
    'en_seance',          v_enc is not null,
    'minutes_en_seance',  v_min,
    'derniere_seance_at', (select max(w.ended_at) from public.workouts w where w.user_id = v_uid and w.ended_at is not null),
    'seances_total',      v_total,
    'phrase', jsonb_build_object(
      'etat', v_etat,
      'fragments', public.phrase_home(v_etat, v_langue, p.prenom,
                     case when v_etat = 'active' then v_faites else v_min end)),
    'textes', (select contenu from public.home_textes_lots where langue = v_langue),
    'phrases', jsonb_build_object(
      'vide',         public.phrase_home('vide', v_langue, p.prenom, 0),
      'active',       public.phrase_home('active', v_langue, p.prenom, greatest(v_faites, 1)),
      'active_zero',  public.phrase_home('active', v_langue, p.prenom, 0),
      'seance_debut', public.phrase_home('seance_debut', v_langue, p.prenom, 0),
      'seance',       public.phrase_home('seance', v_langue, p.prenom, greatest(v_min, 1)))
  );
end;
$function$
;
revoke execute on function public.home() from public, anon;
grant execute on function public.home() to authenticated;
