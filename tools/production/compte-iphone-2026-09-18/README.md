# Compte iPhone — contrôle du18septembre2026

## Lecture réelle de76

Après libération par la session chauffe, copie en lecture seule du store et
lecture de l’identifiant mémorisé : compte Apple `9f5b775d`, **2 séances terminées**,
une série faite chacune. Les deux UUID et nombres de séries correspondent au
serveur. File des gains vide ;2sachets et0carte. La Home journalise également
2séances au total. Cette installation ne contient pas les~38séances évoquées
au début ; aucun effacement effectué pendant ce contrôle.

La copie du store et les préférences complètes restent en dossier temporaire
privé, hors Git. Seuls agrégats et préfixes figurent dans `lecture76.json`.

Le binaire76 installé ne contient pas `synchroniser_seance` ; les marqueurs
`sync_complete_at` des deux séances restent nuls après relance. Il précède le
raccord Compte : ne pas annoncer la migration client installée sur76.

## Reconnexion Apple et version77

Kathryn a confirmé être disponible pour Face ID. Nosfy a été ouvert sur le
profil avec le vrai parcours Apple, puis la session chauffe a repris l’appareil
pour un redémarrage autorisé. Le test de déconnexion/reconnexion est suspendu
pendant son contrôle ; aucun jeton Apple n’était encore rangé à la lecture.
Aucune suppression du compte demandée ni effectuée.

Version77 préparée en copie privée : Compte courant et raccords partagés Cartes.
Installation conditionnée à la libération du téléphone et à la disponibilité
des contrats serveur Cartes ; aucun de leurs déploiements pris ici.

## Dernier trésor

Lecture complémentaire : son état et la validation serveur étaient disponibles
à35, mais le bouton et le geste comparaient encore l’étape active à l’ID du
trésor. Correction : `Lecture.peutReclamer` sert désormais au galet, au bouton
et au geste. Le dernier trésor n’exige plus de36e étape active.1074 contrôles du
vrai calcul/lecture Swift PASS après cette correction ; parcours tactile à faire.

Après le déploiement Cartes84850 par sa session, les35 contrôles API Compte
repassent ; les deux comptes temporaires sont nettoyés. Release iPhone77
compilée une première fois ; recompilation après les correctifs de restitution ci-dessous en cours.

## Parcours compte neuf, lune, cartes et reconnexion

Banc `tools/serveur/verif_parcours_rewards.py` : **40 contrôles API PASS** sur
le serveur déployé, deux identités e-mail temporaires nettoyées. Aucun gain ni
carte injectés par l’administrateur : inscription, sept séances complètes,
clôtures, seuil3, lune verrouillée à6 et disponible à7, reçu unique au rejeu,
ouverture depuis les vrais stocks, cartes issues des sachets lunaires présentes
par leur provenance. Une nouvelle session retrouve exactement profil, séances,
claims, pièces, sachets, collection et annonces ; l’autre compte reste vide.
L’acquittement des annonces persiste et un rejeu ne les réannonce pas.
Ce banc valide la chaîne serveur, pas la feuille Apple ni les gestes iPhone.
Le premier passage a rencontré une assertion de banc erronée : la liste des
claims contient des objets noeud_id, pas des entiers ; corrigée selon le client.

## Restitution client après Apple et changement de compte

Défaut constaté : la tâche de lancement relisait les séances, mais le retour de
la porte après reconnexion ne le faisait pas. La tâche compte.enPorte relit
maintenant l’historique puis les galets réclamés. La Home recalcule ses widgets
et sa Route quand les séances sont relues ou effacées, et les claims actualisés. Les états Route et reward sont
vidés à la déconnexion ; une génération invalide les retours réseau antérieurs
avant toute insertion, mémorisation de curseur, claim ou présentation.

`verif_pull.py` exécute le vrai pull Swift avec réseau différé et stockage de
test : **9 PASS** (séances/séries/cardio/piscine, rejeu, réponse ancienne écartée,
échec réseau sans curseur, nouvelle lecture). La compilation iOS complète
vérifie les types SwiftData. Ce banc n’est pas une mesure réseau iPhone.
`verif_route_vide.py` : **2554 PASS**, dont autorisation du bouton/geste à chaque
seuil0…36 et récompense déjà prise indisponible. Le35e galet libère bien le
trésor final ; compte vide au premier galet. Test tactile distinct.

## Clôture de cette session

Commit demandé avant la fin de la QA physique. Les versions intermédiaires77
ont compilé ; la compilation finale après correction de restitution n’a pas
encore de verdict relu.77 n’a pas été installé par cette session. Reconnexion
Apple, création native neuve et révocation restent non validées. Aucun effacement
du compte iPhone. La validation documentaire a d’abord été interrompue par le
quota du contrôle automatique ; son résultat de clôture figure dans le journal.
