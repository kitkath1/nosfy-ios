# Reprise du 15 septembre, 19:38 — mesurer la Home animée

La résolution de la chauffe reste ouverte. Aucun nouveau gain déclaré.

## Version et essais interrompus

À 19:39, CoreDevice retrouve le conteneur installé25
`55948157-D5CC-4521-8482-E87F140EB639`. La source du dépôt a évolué depuis
l’installation (HEAD 3a86bab) : ne pas attribuer une future comparaison26/25
à une modification unique. Les comparaisons de blocs seront internes au même
binaire.

- Lancement25 à 19:38:15 : état thermique0, fond précomposé 393×709 actif,
  capture de la vraie Home. Appui Exercices à 19:38:23 ; arrêt automatique
  du banc. Seulement deux secondes de sonde, aucune fenêtre stable.
- Relance25 à 19:39:56 : arrêt du banc à 19:40:02, avant le premier relevé.
  Le fond et la pièce apparaissent à 19:40:07. Le test abandonnait dès qu’une
  garde était fausse après cinq secondes ; la raison n’était pas enregistrée.
  **La garde fautive précise n’est pas connue.** Aucune nouvelle donnée vol :
  le fichier « le plus récent » est encore celui de 19:38. Ne pas les mélanger.
- Vérification XCTest à 19:42:25 : Home présente, bouton Profil accessible,
  aucune fenêtre Later à fermer, PASS en 3,896 s. Cette vérification ultérieure
  ne prouve pas l’écran pendant le lancement précédent.
- Power Profiler demandé quinze secondes : attente de connexion puis
  `Timed out waiting for device to boot`, code13. Aucune mesure de puissance.

## Réparation du diagnostic26

Après les cinq secondes initiales, attendre au maximum trente secondes que la
Home soit découverte, avec deux secondes de contexte valide continu. Fermer
Welcome back comme Later si elle arrive pendant la préparation, sans Claim.
La navigation et le passage en arrière-plan annulent ; les obstacles et la
raison d’arrêt sont maintenant écrits dans nav. Les protections thermiques
et le rendu de production ne sont pas changés par cette réparation.
Compilation Release26 en cours. Aucun résultat26 à ce stade.

## Build26 installé et banc terminé

Release BUILD SUCCEEDED. UUID `75E5407D-5755-33DF-AFD2-10FF2E17FCAE`.
Installation 19:47:01, lancement 19:47:06, conteneur
`083A6C2C-CCB3-48BF-A717-69159792697D`.
Sonde vol-20260915-194713, 170 secondes, fin automatique confirmée.

| Phase | n stable | CPU médian | Callbacks/s | Pire intervalle | Thermique |
|---|---:|---:|---:|---:|---|
| complete | 21 | 0 % | 60.0 | 18 ms | [1] |
| sansWidgets | 16 | 1.0 % | 60.1 | 52 ms | [0, 1] |
| sansRoute | 17 | 13 % | 49.6 | 161 ms | [0] |
| fondSeul | 16 | 1.0 % | 60.1 | 17 ms | [0] |
| nu | 16 | 0.0 % | 60.0 | 24 ms | [0] |
| complete | 16 | 14.0 % | 32.5 | 122 ms | [0] |

Welcome/première arrivée absents dans les lignes ; premier plan vérifié.
Le téléphone commence déjà chaud (1), puis passe à nominal0. La phase
sansWidgets mélange ces états : ne pas lui attribuer un gain. À nominal0,
fond seul peu coûteux côté CPU et régulier ; retour du coût et des
ralentissements avec les éléments superposés. Pas de mesure GPU/puissance.
Les six captures restent à récupérer pour confirmer chaque scène.

Build27 ajoute uniquement au diagnostic une attente autonome à froid
(châssis nu, environ cinq minutes au maximum, restauration au terme).
Deux fichiers étrangers changent pendant la compilation27 :
ExerciseDetailView.swift et Services/Annonces.swift. Il faudra comparer
avec/sans fumée sur le même binaire27, sans attribuer l’écart26/27 à elle seule.
