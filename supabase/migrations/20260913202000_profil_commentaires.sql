-- ════════════════════════════════════════════════════════════════════════
-- LES NOTES DANS LE SCHÉMA — 13-09, Kathryn : « rajoute cette documentation
-- et note dans le backend aussi, c'est important pour les tests ».
--
-- Ce qu'un test, un script ou une session future doit savoir en lisant la
-- base elle-même (\d+ profils, ou information_schema), sans ouvrir le dépôt.
-- ════════════════════════════════════════════════════════════════════════

comment on table  public.profils is
  'Le profil d''un compte (13-09). Écrit par definir_profil() à la fin du questionnaire de Nosfy et par la page profil ; lu par profil(). Les comptes se créent UNIQUEMENT par Apple (décision du 13-09).';
comment on column public.profils.prenom is
  'Le prénom saisi (onboarding ou page profil). IL APPARAÎT SUR LA HOME (« Hello Kathryn, ») et sur la page profil : le serveur est la source, l''app n''en garde qu''un cache (UserDefaults woop.prenom). Sans prénom, la home dit « Hello there, ».';
comment on column public.profils.langue is
  'La langue du questionnaire (« fr » / « en »).';
comment on column public.profils.but is
  'La réponse libre « pourquoi tu t''entraînes » de Nosfy.';
comment on column public.profils.onboarding_termine_at is
  'L''AIGUILLAGE : posée = on connaît la personne, la home direct ; null = le questionnaire de Nosfy. Posée une fois par definir_profil(onboarding_termine = true), jamais défaite. Remplace le critère « aucune ligne user_prefs », faux depuis que la chambre Regularity écrit user_prefs.';

comment on table  public.exercices_choisis is
  'Les exercices choisis par la personne (13-09), par id du catalogue Swift (ExerciseCatalog : nom, catégorie, muscles restent dans l''app), avec leur ordre. Écrite par choisir_exercices(ids), qui remplace l''ensemble. Vide tant que l''app ne l''appelle pas.';
comment on column public.exercices_choisis.exercise_id is
  'L''id du catalogue Swift (ex. hip-thrust, pull-through). Le serveur ne connaît pas le nom.';

comment on function public.profil() is
  'Tout ce qu''on sait de la personne, JAMAIS null (loi du vide) : existe, onboarding_termine (l''aiguillage), langue, prenom, but, objectif_hebdo (user_prefs ou défaut), exercices[], seances, compte_cree_at. Session obligatoire (EXECUTE révoqué à anon).';
comment on function public.definir_profil(text, text, text, integer, boolean) is
  'La fin du questionnaire en UN appel : upsert du profil (null ne vide rien), relais de l''objectif à definir_objectif (user_prefs, 1..14), date de fin d''onboarding posée une fois. Rend profil().';
comment on function public.choisir_exercices(text[]) is
  'Remplace l''ensemble des exercices choisis par la liste, dans l''ordre ; rend la liste.';

comment on table  public.user_prefs is
  'Une préférence par compte : objectif_hebdo (1..14). Écrite par definir_objectif() — depuis la chambre Regularity (ChambreEtat.choisir) ou via definir_profil() ; lue par objectif_hebdo() et widget_regularite. Côté app, la clé locale unique est objectifHebdo (Goal.cleHebdo).';
