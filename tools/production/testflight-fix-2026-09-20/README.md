# Correctifs des retours TestFlight du 19-09 — codés le 20-09

Suite du plan `tools/production/PLAN-DEBUG-TESTFLIGHT-2026-09-20.md`. Sur l'ordre
de Kathryn (« donc code ? t'as fix tout, ignore autre session ») : tout est codé
dans l'arbre, **rien n'est commité** sauf 9362cbad (pop-up boosters) et 58e2b13e
(migration `seances_chemin`, DÉPLOYÉE). L'après-midi, sur ses décisions de 11 h :
TODAY retiré, sticker ×2 seul, cinématique du galet, et la migration
`20260920170000_chemin_plafond_depuis_le_20.sql` (le plafond dès le 20-09) —
**écrite, pas déployée** (sur son mot) avec `PlafondJour.depuis` → 20-09.
Analyse Welcome Back / Claim / plafond :
`tools/production/ANALYSE-WELCOME-BACK-CLAIM-PLAFOND-2026-09-20.md`.
Build simulateur vert (DerivedData de session, 08:56, 09:04, 12:05),
captures ci-dessous prises sur un simulateur créé pour l'occasion
(`nosfy-tf-20260920`, iPhone 17, iOS 26.5). **Aucun téléphone.**

## Ce qui a changé, par retour

| Retour | Fichiers | Ce que Kathryn verra | Mesuré |
|---|---|---|---|
| 1 · crash HIIT | `ChambreHiit.swift:499-511` | la fiche HIIT s'ouvre en séance sans fermer l'app (`largeurs()` rend une entrée à zéro par segment au lieu de `[]`) | sim : séance active + fiche HIIT, processus vivant — `captures/11-hiit-en-seance.jpg` ; **Release iPhone non** |
| 1 · séance ouverte | `NosfyApp.swift` (purge au lancement) | un HIIT laissé ouvert n'est plus effacé ; une séance abandonnée avec travail est réglée (pièces, story) au lieu d'être fermée en silence | non mesuré (banc : kill + relance > 3 h) |
| 1 · galet HIIT serveur | `supabase/migrations/20260920120000_seances_chemin_kind_telephone.sql` | un HIIT seul avance la Route au serveur (`Sprint` / `Accélération` comptés) | **DÉPLOYÉE** le 20-09 (commit 58e2b13e), corps relu ; en base, `kind` ne vaut jamais 'effort' (Récupération 27 · Accélération 23 · Sprint 13 · Repos 12) ; effet sur un galet à mesurer au premier HIIT synchronisé |
| 4 · card STOP cardio | `StopCard.swift`, `NosfyApp.swift:1662` | « cardio · paid at the end » au lieu de « +0 coins » | non capturé |
| 2 · « jour 19 » | `GaletEtape.swift`, `DuolinguoPage.swift`, `CardRoute.swift` | ~~le galet du jour dit **TODAY**~~ → **REFUSÉ par Kathryn l'après-midi (« c'est la date et basta »)** : TODAY retiré, le galet actif porte la date du jour comme les galets faits ; ce qui les distingue = le sticker ×2 et le plafond de deux séances par jour (session Route, `PlafondJour`) | captures 13/14/06 périmées sur ce point (elles montrent TODAY) — à refaire |
| 2 · ×2 | idem | le sticker ×2 existant sur le 2e galet du même jour ; **rien au-delà** (sa décision : « max deux et le sticker, basta » — la capsule « ×3 » est retirée) | `06-routecard-double.jpg` (card Home, banc `-duoLab -routeCard double`) |
| cinématique du galet (sa demande de l'après-midi) | `DuolinguoPage.swift` (`EtatDuo.cine*`, `ZoomCine`, `HaloFete`, la partition de la fête), `HomeNuit.swift` (banc `-cheminFete`) | après la story, sur la Route : la colonne grossit 1,6× autour du galet accompli (0,6 s), le sceau + un halo d'or + l'haptique, l'onde, un second halo, le dézoom (0,7 s) — « la session a été faite » —, l'écran suivant, puis les gains défilent. Verre éteint pendant le zoom, autres galets à 0,45 ; une transformation animée, aucun redessin ; barreau `-sansCineGalet` ; coupée par Réduire les animations et un téléphone chaud | banc `-skipAuth -homeChemin -duoEtape 3 -cheminFete -fermeSeances` : film `16-cine-galet-sim.mp4` (5,5 s), planches `17-…-10ips.png` et `18-…-5ips.png` — l'ordre vu : la Route s'ouvre, le galet « 18 » grossit avec son sceau, le halo d'or s'élargit, la Route revient, « 20 » est l'actif ; ⚠️ le film du sim ne mesure pas les durées (il cale pendant le montage de la Route : images dupliquées), et avant la validation le galet célébré porte la date du jour (état « actif » existant — invisible en vrai, la séance célébrée est du jour) ; **iPhone non mesuré** (réservé par la session Home) |
| 2 · « View » | `DuolinguoPage.swift`, `NosfyApp.swift` (`voirSeanceDepuisChemin`, hôte `HistoriqueStories`) | « View » ouvre la story de la séance du galet (même chemin que le widget Regularity, reçu `recus_seances`) | non mesuré (tap) |
| 6 · lune muette | `GaletEtape.swift:246` | le tap court sur une lune pas encore atteinte ouvre le panneau « Reach this step… » | non mesuré (tap) |
| 6 · panneau qui couvre | `DuolinguoPage.swift` (`degagerRecompenses` + bascule dessous) | le panneau du jour passe **sous** le galet quand la récompense est sur son chemin ; sa coque ferme au tap | `13`, `14` |
| 5 · ticket-verrou | `RewardCheminCard.swift` | le ticket reste, décoratif, sans verrou ; « SCRATCH TO REVEAL » dès l'ouverture | `01-card-avant-en.jpg`, `03-card-avant-fr.jpg` |
| 5 · seuil | idem | 30 % hors bandeau vidéo, puis l'app finit le grattage | non mesuré au doigt |
| 5 · « +0 coins » | `RewardCheminVariants.swift` | le vrai montant sous le voile ; après : « → k booster · N coins left » | `02-card-revelee-en.jpg` |
| 5 · vibration | `RewardCheminCard.swift` | texture légère (tics `.light` 0,35 toutes les ≥ 40 ms) au lieu du grondement de fusée ; barreau `-sansHaptiqueGrattage` | **iPhone seulement** |
| 5 · reprise | `RewardChemin.swift`, `DuolinguoPage.swift`, `NosfyApp.swift` | « Scratch later » ; le galet réclamé non gratté dit « Your reward is waiting · Scratch » et rouvre la card ; reprise auto 1,2 s après le lancement | non mesuré (kill + relance) |
| 3b · conversion | `Annonces.swift`, `EconomieNosfy.swift`, `ReglementSeance.swift`, `StorySuite.swift`, `CoffreV2.swift` | dalle « 100 COINS → 1 BOOSTER », story « 100 coins = 1 booster · N left », module Or « 100 coins = 1 booster, automatically », « Mes gains » : −100 pour un sachet converti | seulement la card (`02`) |
| pop-up « BOOSTERS » (sa capture 09:04) | `RewardCheminVariants.swift` (lignes), `RewardChemin.swift` (fond 0,88), `NosfyApp.swift` (nav cachée) | « REWARD » retiré, le chiffre reste au centre, « BOOSTERS » au pied ; la Home derrière n'est plus qu'une ombre (texte 96 → 31/255 mesuré), la pilule « tire pour commencer » éteinte et la nav du bas cachée sous la card | `15-boosters-revele-fr.jpg` |
| toasters sur la Route (son retour du 20-09) | `DuolinguoPage.swift` (`onCelebrationJouee`), `NosfyApp.swift` | les dalles de pièces / sachets / cardio défilent **sur la Route**, dès que le sceau du galet a joué — plus besoin de revenir à la Home ; la sortie de la Route reste le filet, la pop-up booster attend toujours la sortie | non mesuré (aucun banc sans tap) |
| story « Kathryn, » | `StoryEnded.swift` | le prénom du profil, repli « Your session » | non vu à l'écran |

## Ce qui reste à mesurer (dans l'ordre)

1. **Build 82 sur son iPhone en Release** : HIIT pendant une séance ×3
   (thermique 0), Stop → la Live Activity part.
2. Au doigt : la lune non atteinte, le panneau sous le galet, « View »,
   « Scratch » après un « Scratch later » puis kill/relance.
3. La card à gratter : gratter la moitié basse suffit ; l'haptique avec et sans
   `-sansHaptiqueGrattage` et avec « Réduire les animations ».
4. Le récit des pièces sur une vraie clôture (compte de test, piste A du plan
   § 4.3) : toaster, story, Coffre, « Mes gains ».
5. (Migration déployée.) Rejouer
   `tools/serveur/verif_gains_progression.py` étendu à un HIIT seul.
6. **La cinématique du galet sur son iPhone**, thermique 0, A/B avec
   `-sansCineGalet` (le sim ne mesure ni les durées ni la chauffe) ; les
   réglages à son verdict : zoom 1,6×, deux halos, ≈ 3,1 s avant les gains.
7. Le plafond dès le 20-09 : `supabase db push --include-all` sur son mot,
   relire `reward_rules.chemin_plafond_depuis` (= "2026-09-20"), puis une 3e
   séance sur un compte jetable → `plafond_jour: true`, 0 pièce.

## Réserves connues

- Le tirage déjà stocké chez Kathryn (nœud 3, build 81) n'a ni
  `sachetsConvertis` ni `soldeApres` : la reprise dirait « +147 » sans la ligne
  de conversion (l'information n'existe que dans la réponse du premier Claim).
- `recus_seances` ne rend ni `sachets_convertis` ni `reste` : la story relue
  d'une séance d'avant ce build n'a pas la phrase de conversion (voulu).
- Le « −100 » de « Mes gains » est le prix actuel du serveur, pas celui du jour
  de la conversion.
- Le panneau du jour passe dessous quand une récompense est sur son chemin :
  il couvre alors la suite du chemin (règle du 28-08 assouplie, à son verdict).
- `HomeNuit.swift:2690` construit une seconde `DuolinguoPage` (ancienne route
  depuis la Home) sans `aOuvrir` / `onVoir` : à vérifier qu'elle est morte.
- `ReglementSeance.swift` et `HistoriqueStories.swift` sont `D` dans l'index
  partagé et `??` sur disque : un commit par chemin doit les `git add`.
