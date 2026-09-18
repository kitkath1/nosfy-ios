# Compte, gains et progression — déployé le18-09-2026

Migration `20260918083033_compte_gains_et_progression.sql` déployée sur
`ytnnyjkramgiqyxdrkcu`, après l’accord explicite de Kathryn. Historique relu.
Aucune remise à zéro du compte existant ; comptes QA temporaires supprimés.

## Contrat livré

- `synchroniser_seance` : une transaction pour la séance, ses exercices et
  réalisations. Séries prévues exclues ; seules les phases faites de durée
  positive partent. Relations vérifiées et RLS restrictive du parent.
- `sync_complete_at` : réception complète ; le pull incrémental retrouve aussi
  une séance ancienne venant d’être envoyée. Données historiques conservées.
- `cloturer_seance` vérifie propriétaire, fin, réception complète et nombre
  réel de séries avant tout gain. Absente/incomplète/incohérente503 rejouable,
  étrangère403. Verrou par séance et gains idempotents. Vide : aucun sachet.
- File persistée avant réseau, sans suppression arbitraire à200entrées ; ajouts
  concurrents conservés, génération invalidée à la sortie du compte. Au retour
  actif, les séances en attente sont renvoyées avant de rejouer les gains.
- Compte neuf : premier galet en haut. Un galet par séance terminée avec muscu
  faite, effort cardio positif ou longueurs nagées. Deux séances le même jour
  comptent deux fois ; aucune avance pendant une pause ni avec une date future.
  C’est le choix de travail annoncé, en attente d’une préférence contraire.
- Cinq chapitres, sept séances chacun, récompenses à3et7. Contrôle serveur via
  `seances_chemin()`. À35, dernier galet accompli et trésor disponible ; après35,
  historique et gains continuent, sans nouveau cycle ni récompense doublée.
  Les anciens claims restent rejouables. Géométrie fixe, pas pilotée en direct
  par les anciennes clés de comparaison `reward_rules`.

## Vérifications

| Banc | Résultat |
|---|---|
| SQL transaction annulée (22 invariants) | PASS, aucun utilisateur conservé |
| `tools/serveur/verif_gains_progression.py` |35 PASS,2 comptes nettoyés |
| `tools/serveur/verif_compte.py --flow --integrite` |51 PASS,2 comptes nettoyés |
| `tools/serveur/verif_outbox.py` |13 PASS, dont panne/concurrence/changement de compte |
| `tools/serveur/verif_sync.py` |12 PASS, extraction et transport Swift réels |
| `tools/duolingo/verif_route_vide.py` |1074 PASS, de0à36 avec et sans ancien drapeau |
| App Debug simulateur | BUILD SUCCEEDED |

Journaux voisins : résultats sans clé privée, jeton ni donnée personnelle.
Le banc Route compile le calcul ET la lecture des états/dates de production.
Le banc sync intercepte le transport ; les vrais appels distants sont mesurés
séparément par les bancs API. Une compilation n’est pas une QA physique.

## Déploiement et limites

Les anciennes versions, sans RPC de snapshot, conservent leurs nouvelles
clôtures en attente jusqu’à mise à jour. Le nouveau raccord renvoie les séances
pendantes. Ne pas annoncer de perte ni effacer la file pour résoudre un503.

Analyseur Supabase sécurité :52 WARN, surtout permissions de fonctions definer,
plus `phrase_home` sans search_path fixe et protection des mots de passe divulgués
inactive. Aucune fonction interne ajoutée ici n’est accessible au client ; les
points d’entrée authentifiés sont testés. Cette observation ne valide pas toutes
les anciennes fonctions. Aucune alerte n’est masquée pour obtenir du vert.

La session chauffe garde l’iPhone pour76. Aucun contrôle physique ni installation
réalisé par cette session. Restent : vraie feuille Apple et échange/révocation du
jeton, parcours neuf jusqu’aux annonces/stories, rapprochement des séances locales
du compte de développement, Forge/chauffe et version intégrée. La clé Apple est
installée mais la sonde `invalid_grant` antérieure ne prouve pas un vrai échange.
Les CGU finales restent également requises avant publication.

Documentation partagée : artefact+verif PASS48s,23tests ; quatre captures
État/Compte390et1440 relues, aucun débordement sur les dix pages. Site local3111
contrôlé : correctif déployé présent. L’ancien lien Artifact externe ne peut
pas être republié avec les outils de cette session.

## Limite de compilation isolée constatée

L’arbre partagé compile en Debug. La copie isolée sur70503973 échoue en Release :
ToasterGain/VolDePieces absents, anciens cas du switch RecentWorkoutCard,
interface onStopViaPause manquante et expression de NosfyApp non typable.
Ces sites existent déjà dans la base du commit, hors de nos raccords.
Leurs correctifs se trouvent dans les travaux parallèles ; ils ne sont pas
emportés. Journal minimal : `build-isole.log`. La révision intégrée devra être
compilée et qualifiée avant publication. Sessions prévenues dans MULTI-SESSION.

Copie documentaire exacte du commit : artefact+verif PASS16s,23tests ;
État/Compte390et1440 relus. Le livrable partagé conserve les travaux parallèles,
le livrable du commit ne les emporte pas. Aucun push.
