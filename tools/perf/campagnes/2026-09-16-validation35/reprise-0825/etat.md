# Reprise du 16 septembre, 08:25–08:36 (Paris)

Version 35 déjà installée, aucun nouveau correctif dans cette reprise.
Après déverrouillage, le contrôle `testHomePretePourMesure` passe à 08:25:51
(3,296 s), puis à 08:29:17 (1,570 s) et 08:32:57 (3,005 s).
Il ferme la fenêtre d’arrivée et vérifie la Home ; il ne prouve pas un parcours
Home → Profil → Réglages. Le blocage d’automatisation E57 n’est plus présent.

## Deux endurances interrompues, aucune validée

- A, 08:27 : début sur Home, CPU médian des 25 dernières secondes 1 %, thermique 0,
  protection 0. Au premier contrôle, l’écran est passé sur Exercices : arrêt à
  08:27:48. Les dix minutes prévues et les cycles de navigation ne sont pas faits.
- B, 08:30 : début nominal, CPU 1 %. Le contrôle de 08:31:02 trouve thermique 1
  et protection 1 : ce faible CPU ne valide plus le rendu normal. À 08:31:33,
  l’écran est sur Exercices et une séance est active : arrêt du protocole.
- Ces changements de page/séance ne résultent pas des gestes du protocole,
  qui attendait sur la Home. Leur auteur n’est pas établi par ces journaux.
  Ils invalident les fenêtres d’endurance, sans prouver une panne de l’app.

## Home noire : observation courte

Le journal `vol-20260916-083251.jsonl` observe une séance déjà active.
Après les 15 premières secondes : 79 échantillons Home noire, t = 15,2 à 94,4 s,
CPU médian 20 %, thermique 0, protection 0. La séance cesse ensuite dans les
états observés ; nous n’avons pas commandé sa clôture. Sur la Home hors séance,
102 échantillons de t = 95,4 à 197,9 s donnent un CPU médian de 1 %, thermique 0,
protection 0. Voir `resume-fenetres.json` et les journaux bruts.

Ces fenêtres ne sont pas un A/B causal, une mesure de puissance GPU ni une
validation de chauffe sur une longue séance. Aucun enregistrement Instruments
n’a été effectué dans cette reprise. Aucun gain sur la Home noire n’est annoncé.

## Arrêt et nouvelle demande

L’utilisateur demande ensuite un plan pour les textes animés FR/EN des deux
Homes et du pull, puis précise « fais un plan, ne code pas ». Investigation
arrêtée ; lancement normal avec `-sansSondeVol -openTab home` accepté à 08:36:11,
sans maintien éveillé demandé. Aucun compte supprimé, aucune séance créée ou
terminée par notre protocole. La chauffe prolongée reste non validée.

Plan : [textes des Homes FR/EN](../../../../home-v2/PLAN-TEXTES-HOMES-FR-EN-2026-09-16.md).
