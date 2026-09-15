# Build 18 : accès au compte confirmé, chauffe toujours ouverte

Release installé le 15-09 à 11:18:18, UUID F9ADB92B-9B85-328A-85FE-4B339198CD7A.
Le parcours Home → Exercices → Home → Profil → Réglages passe en 8,671 s à
11:20:02. Kathryn confirme ensuite : « Navigation possible, mais le téléphone
chauffe encore ». La capture reglages18.png montre les deux actions de compte ;
aucune déconnexion ni suppression exécutée. QA07 devient valide pour cet accès,
QA04 reste KO. Le cycle complet de compte reste à tester.

La correction CardRoute suspend ses feuilles décoratives cachées sans recréer
la card ni sa bande défilante. Aucun gain énergétique propre n'est attribué.

## Liserés figés / habituels, protection thermique active

Même build ; `-liserePose 0` à 11:24:07 puis rendu habituel à 11:24:58.
SondeVol et navProbe allumés pour les deux. Les préparations XCTest prouvent
la Home. Fenêtre commune 15 ≤ t ≤ 40 s :

| Rendu | n | CPU médian | Callbacks/s médians | Plus grand intervalle | Thermique |
|---|---:|---:|---:|---:|---|
| pose | 25 | 13 % | 60.1 | 34 ms | [1] |
| actif | 25 | 14 % | 60.1 | 67 ms | [1] |

La manche pose contient une navigation réelle au Profil vers t42,6–43,7 s,
puis retour Home : cette partie est exclue. La différence CPU de la fenêtre
commune est faible et ne prouve pas une baisse de chauffe. Ce banc ne justifie
pas d'immobiliser les liserés par défaut. Rendu normal, sans compteurs, restauré
à 11:25:50 ; préparation Home PASS 3,383 s.

Les captures Time Profiler suivantes sont une autre comparaison : leur résultat
ne doit pas être attribué aux liserés ni à la correction de cycle de vie.
