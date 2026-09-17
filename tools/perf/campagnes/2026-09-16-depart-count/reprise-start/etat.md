# Reprise Start sans effet — défaut ouvert, 16 septembre2026

Kathryn signale que Start ne fait rien sur l’iPhone : **le panneau reste
visible**. Ce retour invalide une conclusion globale tirée de la validation
simulateur et du lecteur isolé53. La version53 est relue sur l’iPhone.

Reproduction sur le troisième galet au simulateur : tap par coordonnées au
centre de Start, film et Exercices, une seule séance, PASS23,667s. La séance
QA04F546EA-A762-4A78-806F-DA88C27A8FAE est relue au serveur puis supprimée,
ainsi que le fixture du contrat REST. Aucune autre ligne ni récompense visée.

Les tests des bords donnent un faux diagnostic : le premier ne trouve pas
le panneau (précondition absente) ; le second arrive visuellement à Exercices
mais la minuscule sonde count-state garde page=home. Ce dernier champ ne
peut donc pas servir seul d’assertion après une reprise de séance existante.
Le film XCTest surface53 montre l’arrivée réelle à Exercices. L’essai54
ajoutant contentShape ne change pas ce résultat ; les trois lignes sont
**retirées de la source**. Aucun correctif54 installé, aucune réparation
annoncée sur cette base.

Sur iPhone, le premier runner est bloqué avant exécution par Locked. Une
reprise observe Route sans panneau ; le tap du seul galet du jour fait ensuite
apparaître Start, frame(148,7;448,3;73,7;34), hittable=true, contrôle2,501s.
Les captures restent dans /tmp/woop-count54/panneau-captures (écran personnel,
non incorporé à ces preuves QA). Aucun Start automatique sur ce compte.

L’observation de l’appui manuel commence à20:45:33 puis perd la communication
avec le runner ; journal « connection invalidated », aucun résultat de départ
exploitable, fin21:05:10. Une demande utilisateur d’appui durant une fenêtre
fixe est inadaptée à cette liaison : ne pas la répéter comme si les deux
horloges étaient synchronisées. Aucun nouveau test thermique, sonde non activée.
Dernier relevé CoreDevice : available (paired), liaison connectée non établie.

**Cause non identifiée, défaut toujours ouvert.** Le prochain contrôle doit
suivre l’appui réel sur une liaison rétablie et distinguer réception du toucher,
appel du relais, naissance du film. Ne pas déplacer le bouton ou modifier la
vidéo au hasard. Les modifications de la tâche53 restent non commitées.
