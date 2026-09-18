# Mini-check du bouton Ouvrir —18-09

À la demande de Kathryn, contrôle réduit pour limiter le coût. Un seul test
sur le simulateur Cartes, binaire Debug déjà installé ; aucune nouvelle
compilation de l’app, aucun accès au téléphone, aucun correctif appliqué.

Compte QA isolé :3orange/3noirs. Depuis Profil, entrée orange, bouton Ouvrir
touché par coordonnées : sonde du manège toujours absente après10secondes.
Même échec reproduit en22,557s. La capture après appui est noire ; aucun
sachet consommé ni carte attribuée (stocks3/3 conservés). Voir mini-check.log,
etat-apres.json et apres-ouvrir.png. Le hit-testing reste une hypothèse :
la capture ne permet pas de distinguer geste, présentation ou démarrage du manège.
Piste locale : PiedCoffre.bouton désactive le hit-testing du primaire et lui
laisse une action vide, en comptant sur un geste prioritaire. La correction
reste à tester ; ce contrôle ne démontre pas encore la cause définitive.

Compte temporaire et jetons nettoyés, simulateur arrêté. Le blocage existant
reste rouge dans la documentation ; aucune nouvelle validation globale.

## Reprise ciblée

Reproduire le passage Profil → coffre orange → Ouvrir, puis distinguer la
fermeture du cover, SacreEtat.manegeOuvert et le montage de BoosterLab.
La hiérarchie après l’échec contient encore les éléments du Profil ; l’écran
noir juste après le tap ne prouve donc pas à lui seul un bouton inactif.
Tester la correction sur orange puis noir avant de fermer le blocage QA.
Ne pas relancer les campagnes backend/chauffe pour ce diagnostic initial.
Les comptes QA précédents sont supprimés : recréer une fixture isolée.

## Reprise du 18-09, 12:15 → 12:40 — le blocage est LEVÉ (simulateur), et la cause n'était pas le bouton

**Verdict mesuré : les quatre scénarios UI (A, B, C, D) PASSENT** sur le simulateur
Cartes (`nosfy-cartes-20260918`, iPhone 17, iOS 26.5), fixture neuve à chaque run
(`fixture_qa.py creer` : compte jetable, 3 orange / 3 noirs, jetons dans Documents).
Log : `apres-correctif-ABCD2.log` (« Executed 4 tests, with 0 failures »), captures
dans `captures-apres/` (profil vide, coffre orange, manège, carte réelle orange,
collection après envol, coffre noir offert, légendaire réelle, collection après
relance, les deux manèges interrompus et repris).

### Ce qui s'est passé, dans l'ordre

1. **`allowsHitTesting(false)` est innocenté.** La piste de ce matin a été testée
   A/B : bouton sans (`build-correctif.log`, test E : PASS, `trace-E.log`) puis avec
   (`build-ab.log`, test E : PASS, `trace-E-ab.log`). Le bouton ouvre le manège dans
   les deux cas. Le code d'origine est conservé.
2. **La vraie cause : le banc tapait PENDANT le film d'arrivée du coffre.** Le coffre
   joue un film de 4 s (la pièce qui tourne, `E0-coffre-t0`), page à opacité 0,
   puis fondu au noir et allumage à ~4,7 s. Le bouton « OUVRIR » vivait déjà dans
   l'arbre d'accessibilité (hiérarchie à t0 : `Button 'OUVRIR' {{36.7, 764.3}}`),
   donc `waitForExistence` rendait la main tout de suite et le tap tombait dans le
   noir : **aucune trace `pied : tap Ouvrir`** (`trace-B2.log`, `trace-final.log`,
   0 tap sur 3 scénarios). Le même test avec 6 s d'attente (test E, `test-E.log`)
   passe : `pied → coffre : ouvrirManege(lune) boosters=3 → sacre → racine :
   manegeOuvert=true`, sonde présente, manège capturé (`E2-apres-tap`).
3. **`accessibilityHidden(pageOp == 0)` ne suffit pas** : posé sur le ZStack de la page
   (`build-final.log`, run B C D : 3 échecs) puis sur `contenu(sc)` (`build-essai2.log`,
   test E2/E3 : `OUVRIR` toujours dans la hiérarchie à t0). XCUITest ignore ce
   modificateur — mesuré deux fois. La ligne reste sur `contenu(sc)` pour VoiceOver
   (non mesurée : c'est sa sémantique documentée, pas une preuve).
4. **Le correctif : le pied ne monte son bouton qu'une fois la page allumée**
   (`PiedCoffre.allume`, posé depuis `contenu(sc)` avec `pageOp > 0` ;
   `Color.clear` de 58 pt à sa place tant que le projecteur est éteint — la grille des
   quatre pages ne bouge pas). Un bouton qui n'existe pas ne peut ni être lu par
   VoiceOver ni être tapé par le banc pendant le film. `build-allume.log`, puis run
   A B C D (`apres-correctif-ABCD.log`) : **Ouvrir franchi dans les 4** (4 traces
   `pied`, `trace-ABCD.log`), C et D PASS.
5. **Deux hypothèses fausses des tests d'origine**, corrigées dans
   `CartesUITests-apres.swift` (l'original reste `CartesUITests.swift`) :
   - **A** lançait `-cartesExporter` (l'habillage de 14 arts, une preuve séparée déjà
     livrée : `integration-2026-09-18/cadres-reels-14.jpg`) sans sa fixture
     (`cartes-qa-arts.json`) — l'app affichait « QA indisponible ». Retiré : A
     contrôle deux portes, collection vide, coffre orange.
   - **B** tapait le chevron du résultat et attendait le profil. Par conception
     (`NosfyApp.swift`, `onRetourHome`), le chevron rend la **HOME** — la sortie du
     parcours ; hiérarchie de fin : « Bonjour, ta prochaine séance ». La sortie vers la
     collection est l'**envol** (la carte glissée vers le haut, `BoosterLab.swift`,
     `envoler()`). B glisse désormais la carte ; la pill orange revient, la sonde dit
     `references=1`, capture `collection-premiere-carte.jpg` (« Deux Lunes 1 / 3 »).
6. Trace de banc ajoutée, DEBUG et `-cartesQA` seulement : `traceQA()`
   (`CartesQABanc.swift`, `Logger` subsystem `fr.kathryn.woop` catégorie `cartesQA`),
   posée au tap du pied, dans `CoffreV2.ouvrirManege`, `SacreEtat.ouvrirManege` et à la
   racine (`manegeOuvert`). Lecture : `log stream --predicate 'subsystem ==
   "fr.kathryn.woop" AND category == "cartesQA"'`.

### Pièges payés cette fois

- Le runner XCUITest en cache (mémoire du 07-09) : désinstallé avant chaque run
  (`simctl uninstall fr.kathryn.woop.NavRuntimeUITests.xctrunner`).
- Une capture noire au simulateur n'est pas une preuve de bouton mort : c'était le
  film d'arrivée, que la capture ne montre pas.
- `app.debugDescription` **avant** le geste (pièce jointe `E0-hierarchie-t0`) : c'est
  lui qui a montré le bouton présent à t0.

### Ce qui reste ouvert (et n'est pas peint en vert)

- **Rien n'a été mesuré sur son téléphone** : simulateur seul, `-boosterCine`.
- L'exporteur d'arts (`-cartesExporter`) n'a pas été rejoué ici.
- Chauffe, haptique, shiny animé : hors périmètre, toujours ouverts.
- Après le run, la fixture a été nettoyée (`fixture_qa.py nettoyer`) ; aucun compte
  personnel touché. Le simulateur est éteint.

Fichiers modifiés dans l'arbre (non commités) : `Nosfy/Views/CoffreV2.swift`
(`PiedCoffre.allume`, `accessibilityHidden` sur `contenu`, trace, commentaires),
`Nosfy/Services/CartesQABanc.swift` (`traceQA`), `Nosfy/Views/BoosterPopup.swift` et
`Nosfy/NosfyApp.swift` (une trace chacun), et ce dossier.
