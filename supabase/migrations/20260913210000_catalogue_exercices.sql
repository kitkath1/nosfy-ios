-- ════════════════════════════════════════════════════════════════════════
-- LE CATALOGUE DES EXERCICES, AU SERVEUR — généré par tools/widgets/catalogue_sql.py
-- depuis Woop/Models.swift (ExerciseCatalog.all), le 2026-09-13 : 29 exercices.
--
-- Le catalogue Swift reste LA source (l'écran ne lit jamais cette table) ;
-- la table est le miroir que le serveur lit pour NOMMER ce qu'il compte :
-- widget_volume / widget_peak (nom, catégorie), profil().exercices.
-- Un exercice ajouté dans le Swift = une nouvelle migration générée par le script.
-- ════════════════════════════════════════════════════════════════════════

create table if not exists public.exercices (
  id          text primary key,            -- l'id du catalogue Swift (ex. hip-thrust)
  nom         text not null,
  categorie   text not null,               -- Haut · Abdos · Bas · Fessiers · Cardio (ExerciseCategory.rawValue)
  equipement  text not null,               -- barre · halteres · machine · poidsDuCorps · poulie
  tracking    text not null,               -- setsRepsWeight · intervals · steady
  muscle      text not null,
  consigne    text not null,
  erreur      text not null,
  updated_at  timestamptz not null default now()
);
alter table public.exercices enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'exercices' and policyname = 'lecture') then
    create policy "lecture" on public.exercices for select to authenticated using (true);
  end if;
end $$;
grant select on public.exercices to authenticated;
comment on table public.exercices is 'Le miroir du catalogue Swift (ExerciseCatalog.all), écrit par migration seulement (tools/widgets/catalogue_sql.py). Lu par widget_volume, widget_peak, profil() pour nommer les exercices. Aucune écriture depuis l''app.';

insert into public.exercices (id, nom, categorie, equipement, tracking, muscle, consigne, erreur) values
  ('woop-haute', 'Woodchopper poulie haute', 'Abdos', 'poulie', 'setsRepsWeight', 'Obliques et transverse', 'Tu tires la poulie du haut vers la hanche opposée, le buste d''un bloc.', 'Tirer avec les bras en laissant le bassin tourner avec le buste.'),
  ('woop-basse', 'Woodchopper poulie basse', 'Abdos', 'poulie', 'setsRepsWeight', 'Obliques et chaîne antérieure', 'La même diagonale, mais de bas en haut, jusqu''au-dessus de l''épaule.', 'Cambrer le bas du dos en fin de montée.'),
  ('flexion-laterale', 'Flexion latérale poulie basse', 'Abdos', 'poulie', 'setsRepsWeight', 'Obliques', 'Tu inclines le buste sur le côté, puis tu te redresses lentement.', 'Pencher le buste vers l''avant plutôt que strictement sur le côté.'),
  ('rotation-milieu', 'Rotation poulie médiane', 'Abdos', 'poulie', 'setsRepsWeight', 'Obliques et transverse', 'Bras tendus devant la poitrine, tu fais pivoter le tronc.', 'Plier les coudes, ce qui transforme l''exercice en tirage.'),
  ('gainage-militaire', 'Gainage militaire avec tirage', 'Abdos', 'poulie', 'setsRepsWeight', 'Transverse et anti-rotation', 'En planche haute, tu tires d''une main sans que rien ne bouge.', 'Laisser la hanche pivoter au moment du tirage.'),
  ('crunch-machine', 'Crunch à la machine assistée', 'Abdos', 'machine', 'setsRepsWeight', 'Grand droit', 'Tu enroules le buste vertèbre par vertèbre, et tu souffles en bas.', 'Tirer sur les poignées avec les bras au lieu d''enrouler le buste.'),
  ('crunch-poulie', 'Crunch à genoux à la poulie', 'Abdos', 'poulie', 'setsRepsWeight', 'Grand droit', 'À genoux, tu enroules le buste vers les cuisses.', 'Tirer avec les bras et pivoter des hanches au lieu d''enrouler le buste.'),
  ('gainage', 'Gainage', 'Abdos', 'poidsDuCorps', 'setsRepsWeight', 'Transverse et gainage profond', 'Une ligne droite des talons à la tête, tenue sans creuser.', 'Laisser le bassin s''affaisser, ou remonter les fesses pour souffler.'),
  ('crunch-sol', 'Crunch au sol', 'Abdos', 'poidsDuCorps', 'setsRepsWeight', 'Grand droit', 'Tu décolles les omoplates en soufflant, le bas du dos au sol.', 'Tirer sur la nuque avec les mains.'),
  ('chevilles', 'Toucher de chevilles', 'Abdos', 'poidsDuCorps', 'setsRepsWeight', 'Obliques', 'Le buste relevé, tu touches une cheville puis l''autre.', 'Tendre les bras vers les pieds sans fléchir le buste.'),
  ('developpe-couche', 'Développé couché à la barre', 'Haut', 'barre', 'setsRepsWeight', 'Pectoraux, triceps, épaules', 'Tu descends la barre au milieu de la poitrine, coudes à 45°.', 'Faire rebondir la barre sur la poitrine pour relancer la montée.'),
  ('papillon', 'Papillon à la machine', 'Haut', 'machine', 'setsRepsWeight', 'Pectoraux', 'Tu refermes les bras devant toi en serrant la poitrine.', 'Tendre complètement les bras et tirer avec les épaules.'),
  ('tirage-vertical', 'Tirage vertical à la machine', 'Haut', 'machine', 'setsRepsWeight', 'Grand dorsal', 'Tu tires la barre vers la poitrine, coudes le long du corps.', 'Se balancer en arrière pour arracher la charge.'),
  ('tirage-vers-soi', 'Tirage vers soi à la poulie', 'Haut', 'poulie', 'setsRepsWeight', 'Haut du dos et arrière d''épaule', 'Tu amènes les mains vers le visage, coudes hauts.', 'Tirer des bras seuls en laissant les épaules monter vers les oreilles.'),
  ('curl-machine', 'Curl à la machine', 'Haut', 'machine', 'setsRepsWeight', 'Biceps', 'Coudes calés, tu montes franchement et tu freines la descente.', 'Lâcher la descente et laisser le bras retomber d''un coup.'),
  ('elevations-laterales', 'Élévations latérales aux haltères', 'Haut', 'halteres', 'setsRepsWeight', 'Deltoïdes latéraux', 'Tu montes les bras jusqu''à l''horizontale, sans à-coup.', 'Balancer le buste pour lancer les haltères plus haut.'),
  ('squat-barre', 'Squat à la barre', 'Bas', 'barre', 'setsRepsWeight', 'Quadriceps et fessiers', 'Les hanches partent en arrière jusqu''à la cuisse parallèle.', 'Décoller les talons et laisser les genoux rentrer à la remontée.'),
  ('presse-jambes', 'Presse à jambes', 'Bas', 'machine', 'setsRepsWeight', 'Quadriceps et fessiers', 'Tu descends jusqu''à l''angle droit, puis tu pousses sans verrouiller.', 'Décoller le bas du dos du dossier pour aller chercher de l''amplitude.'),
  ('souleve-de-terre', 'Soulevé de terre', 'Bas', 'barre', 'setsRepsWeight', 'Ischio-jambiers, fessiers et dos', 'Dos plat, tu pousses dans le sol et tu te redresses d''un bloc.', 'Arrondir le bas du dos en démarrant par les épaules.'),
  ('extension-lombaire', 'Extension lombaire au banc', 'Bas', 'machine', 'setsRepsWeight', 'Lombaires et ischio-jambiers', 'Charnière de hanche, tu remontes jusqu''à l''alignement — pas plus.', 'Terminer en hyperextension, le dos cambré au-dessus de la ligne.'),
  ('kickback', 'Kickback à la poulie', 'Fessiers', 'poulie', 'setsRepsWeight', 'Grand fessier', 'La jambe part en arrière, le buste ne bouge pas.', 'Cambrer le bas du dos pour aller chercher de l''amplitude.'),
  ('pull-through', 'Pull-through à la poulie', 'Fessiers', 'poulie', 'setsRepsWeight', 'Fessiers et ischio-jambiers', 'Les fesses partent en arrière, puis les hanches poussent en avant.', 'Faire un squat au lieu d''une charnière de hanche.'),
  ('abduction', 'Abduction latérale à la poulie', 'Fessiers', 'poulie', 'setsRepsWeight', 'Moyen fessier', 'Jambe tendue, tu l''ouvres sur le côté et tu la ramènes lentement.', 'Se pencher du côté opposé pour lever la jambe plus haut.'),
  ('squat-poulie', 'Squat à la poulie', 'Fessiers', 'poulie', 'setsRepsWeight', 'Quadriceps et fessiers', 'Tu t''assois vers l''arrière, genoux dans l''axe des pieds.', 'Laisser les genoux rentrer vers l''intérieur à la remontée.'),
  ('hip-thrust', 'Hip thrust à la machine', 'Fessiers', 'machine', 'setsRepsWeight', 'Grand fessier', 'Tu pousses par les hanches, et tu marques une pause en haut.', 'Terminer en cambrant le dos plutôt qu''en serrant les fessiers.'),
  ('hiit-tapis', 'HIIT sur tapis de course', 'Cardio', 'machine', 'intervals', 'Cardio-respiratoire', 'Alterne phases rapides et récupérations. Un cycle regroupe plusieurs phases.', 'Partir trop vite sur le premier cycle et s''écrouler sur les suivants.'),
  ('escalier', 'Escalier', 'Cardio', 'machine', 'steady', 'Fessiers et cardio', 'Montée continue, buste droit, sans s''appuyer sur les barres.', 'Se suspendre aux poignées, ce qui annule le travail des jambes.'),
  ('tapis-lent', 'Tapis à allure modérée', 'Cardio', 'machine', 'steady', 'Endurance fondamentale', 'Allure conversationnelle, tenue longtemps.', 'Monter l''allure jusqu''à sortir de la zone d''endurance.'),
  ('piscine', 'Piscine', 'Cardio', 'poidsDuCorps', 'steady', 'Cardio-respiratoire et corps entier', 'Allure régulière, corps aligné à la surface, la respiration calée sur le cycle de bras.', 'Lever la tête pour respirer : le bassin descend et les jambes se mettent à traîner.')
on conflict (id) do update set
  nom = excluded.nom, categorie = excluded.categorie, equipement = excluded.equipement,
  tracking = excluded.tracking, muscle = excluded.muscle, consigne = excluded.consigne,
  erreur = excluded.erreur, updated_at = now();
