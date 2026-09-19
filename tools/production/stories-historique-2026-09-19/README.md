# Stories restaurées et séances des jours — 19 septembre 2026

Le reçu de récompenses revient désormais avec les anciennes séances après
reconnexion et restauration. La lecture retrouve aussi le reçu d’une séance
déjà présente dans SwiftData, même si le curseur de synchronisation a avancé.
Le widget Regularity et sa grille ouvrent les
stories du jour choisi. Plusieurs séances le même jour proposent un choix
par heure ; une seule s’ouvre directement. Un jour vide ne crée aucune story.

Les **50 cartes sont requises pour le lancement** selon Kathryn. La session
Cartes les prend en charge ; aucun art ni catalogue modifié ici. Le présent
correctif ne vaut ni distribution TestFlight, ni validation Apple native.

## Résultats mesurés

| Contrôle | Résultat | Preuve |
|---|---|---|
| Vrais clients Swift → Supabase → nouvelle base SwiftData | 24 PASS | `swift-live.log` |
| Lecture des reçus par API, deux comptes séparés | 17 PASS | `recus-api.log` |
| Pull : pannes, reprise, compte changé, reçu manquant malgré curseur | 17 PASS | `pull.log` |
| Clôture durable, story, Welcome Back et migration SwiftData | 35 PASS | `fin-seance.log` |
| Jours locaux, plusieurs séances, séance ouverte exclue, changements d’heure | 5 PASS | `jours.log` |
| Compilation Debug simulateur, sources finales | BUILD SUCCEEDED | `build-final.log` |
| Gestes sur les vraies vues avec historique de banc | 3 PASS, 0 échec | `ui-verifie.log`, `historique-verifie.xcresult` |

Les tests connectés acquittent les annonces et ouvrent le booster avant la
restauration : la story retrouve toujours son bilan exact. Relire le reçu
ne change ni le solde, ni la version du coffre, ni les annonces. Les faits
TOP et double séance sont relus sans recalculer l’histoire depuis les règles
actuelles. Une ancienne séance sans reçu privé utilise seulement ses gains
effectivement conservés dans le carnet et les boosters liés.

Trois comptes QA temporaires ont été supprimés après les contrôles connectés.
Aucun compte personnel ni téléphone utilisé. Le banc UI copie le projet dans
un dossier temporaire et y injecte ses données : aucun argument de test ni
donnée de fixture ajouté à l’app livrée. Les tests de dates ont révélé qu’une
séance encore ouverte pouvait passer le filtre de travail fait ; le filtre
exige maintenant une date de fin, puis les cinq contrôles sont passés.

## Lecture serveur déployée

Migration `supabase/migrations/20260919073635_recus_seances_lecture.sql`,
fonction `recus_seances(uuid[])`, déployée et enregistrée dans le registre
des migrations ; aucun autre fichier SQL en attente appliqué. Preuve :
`deploiement.json`.

La fonction est `STABLE`, en lecture seule, limitée à 500 UUID par appel.
Elle contrôle `auth.uid()`, limite toutes ses lectures au propriétaire,
interdit l’exécution anonyme et n’appelle aucun paiement ni acquittement.
Le client lit par lots de 100, vérifie le propriétaire et la génération du
compte et conserve les reçus dans SwiftData. Une panne laisse le reçu éligible
à une nouvelle lecture ; les séances en attente de règlement restent à
l’outbox. Le clic d’historique ne déclenche pas de nouvelle clôture.

Les advisors Supabase ont été relus (`advisors.json`, 58 diagnostics). Un
avertissement concerne cette fonction :
`authenticated_security_definer_function_executable`. Son accès au schéma
privé des reçus exige ce contexte, avec `search_path` vide et filtrage du
propriétaire testé entre comptes. Ce constat ne signifie pas que l’ensemble
des diagnostics de sécurité du projet est résolu.

## Rejouer les contrôles

Depuis la racine, avec les secrets de QA déjà configurés :

```sh
python3 tools/serveur/verif_front_back_live.py
python3 tools/serveur/verif_recus_seances.py
python3 tools/serveur/verif_pull.py
python3 tools/serveur/verif_fin_seance.py
swiftc Nosfy/Models.swift tools/story/historique/JoursTests.swift -o /tmp/nosfy-historique-jours
/tmp/nosfy-historique-jours
python3 tools/story/historique/preparer.py
```

Le dernier script affiche le chemin de la copie UI. Y lancer le schéma
`NosfyUITests` avec `xcodebuild test`, destination simulateur dédiée et
`CODE_SIGNING_ALLOWED=NO`. Identifiant du simulateur : `simulateur.txt` ;
copie utilisée : `banc-chemin.txt`. Les tests vérifient le montant réellement
lu par `StorySession` après le clic et gardent les captures dans le résultat
XCTest. Ils ne simulent pas une première inscription Apple.

Les trois parcours sont repassés sur les sources finales : 0 échec en
26,309 s. Une tentative intermédiaire a été interrompue pendant l’installation
du runner Xcode ; le simulateur était arrêté au contrôle. Après son démarrage
explicite, le binaire final déjà compilé a passé les trois tests. Les journaux
de cette tentative restent dans `ui-final.log` et `historique-final.xcresult`.
Les empreintes des sources finales sont conservées dans `sources.json`.

## Documentation et limites de lancement

Les briques Stories et la fonction Serveur passent au vert pour leurs preuves
nommées. L’accès par jour passe également au vert : trois parcours UI sur simulateur réussis. Pages
Stories, Widgets, Compte, QA et Cartes, carte Serveur et mesure TestFlight
actualisées. Livrable régénéré puis vérifié : **23 tests PASS**, dix pages
sans débordement à 390 px et livrable identique au build (`doc-artefact.log`,
`doc-verif.log`). Captures État, Widgets et Stories regardées ; sous-titre
Stories périmé corrigé et capture finale relue. Le rapport TestFlight précédent est amendé : les 50 cartes
conditionnent le lancement et le défaut de reçu est corrigé.

Restent la version signée et distribuée dans TestFlight, son entrée Apple
réelle et son parcours à J+1, ainsi que les réserves physiques déjà recensées.
Aucune archive envoyée. La restauration ne peut pas reconstituer un gain
qui n’a jamais été enregistré au serveur.

## Chemins propres à ce correctif, non commités

- App : `Nosfy/Models.swift`, `Nosfy/Services/SupabaseSync.swift`,
  `Nosfy/Views/HistoriqueStories.swift`, `Nosfy/Views/ChambreRegularite.swift`,
  `Nosfy/Views/ChambreLongue.swift`,
  `Nosfy/Views/WidgetsCards.swift`.
- Serveur et bancs : migration citée, `tools/serveur/verif_recus_seances.py`,
  `tools/serveur/tests/front_back_live.swift`,
  `tools/serveur/tests/pull_regression.swift`, `tools/story/historique/`,
  ce dossier de preuves.
- Documentation : `CLAUDE.md`, `MULTI-SESSION.md`,
  `docs/site/content/{briques,mesures,serveur,qa,pages}.ts`,
  `docs/site/content/pages/{histoire,widgets,porte,qa,forge}.mdx`,
  `docs/site/components/Serveur.tsx`, `docs/site/index.html`,
  les README des passes `analyse-testflight-2026-09-19` et
  `reverification-front-back-2026-09-19`.

Plusieurs fichiers sont partagés avec les chantiers précédents. Ne pas les
commiter en bloc sans isoler les modifications. Aucun commit ni push demandé
ou effectué par cette passe.
