# Compte vide : départ de Route — 18 septembre 2026

Contrat demandé par Kathryn : à la première connexion, zéro séance terminée
signifie **premier galet, en haut du chapitre 1**, aucun galet accompli,
aucune date passée inventée, récompenses à venir. Cela reste vrai après
relance et les jours suivants, tant qu'aucune séance n'est terminée.
Une séance ouverte (`endedAt == nil`) n'avance pas la route.

Cause corrigée : `EcranSpec.etapeEtFaits` retournait la démo à deux galets
faits avant même de regarder l'historique vide. La garde vide précède
maintenant cette démo et le mode `-cheminReel`. HomeNuit donne ce même
résultat à CardRoute et à DepartEtat ; DuolinguoPage reçoit étape0, faits[]
et dates[:] et ouvre le chapitre0 (tout en haut). Aucun drapeau de première
visite ou donnée de l'identité Apple n'est nécessaire à ce calcul.

## Contrat backend

Aucune migration ni donnée de progression ajoutée. Un compte neuf conserve
ses zéro séance finie, zéro pièce, zéro sachet et collection vide, déjà
mesurés par `tools/serveur/verif_compte.py --flow` (50 contrôles).
Les règles `chemin_*` décrivent la composition ; elles ne sont pas une
position initiale. Le serveur ne doit pas amorcer deux séances, faits ou
gains pour remplir l'écran. Les sessions restent isolées par compte ; cette
correction ne supprime ni ne réinitialise aucun historique existant.

## Vérification

`python3 tools/duolingo/verif_route_vide.py` : 34 contrôles PASS sur le vrai
Swift extrait avec sa géométrie. Mode normal et `-cheminReel`, vide à J0,
J1 et J40, premier galet de séance en haut, faits/dates vides, récompenses
à venir ; non-régression de l'historique et calcul vide après celui d'un
compte rempli. Journal `tests.log`. Le banc compile l'extrait de production,
sans réécrire son calcul. La source avant correctif échoue au premier cas.

Cela ne mesure pas la navigation physique, la reconnexion réelle ni le
nettoyage inter-comptes. QA : nouveau compte Apple, ouvrir puis refermer
Route et relancer l'app ; vérifier le premier galet et l'absence de faits.
Aucune installation iPhone : téléphone réservé à la session chauffe.

## Limite de production conservée

Le calcul NON VIDE garde son ancien mode démo ; ce correctif ne valide pas
la progression après la première séance. Origine des chapitres, jour versus
séance, progression synchronisée et après35 restent ouverts. Voir la page
Flow et `tools/production/ETAT-PRODUCTION-2026-09-18.md`. Le démarrage vide
corrigé ne suffit pas à déclarer toute l'application prête à publier.
