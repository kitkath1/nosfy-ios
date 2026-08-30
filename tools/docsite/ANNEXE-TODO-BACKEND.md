# ANNEXE — La to-do backend lue dans le code (sonde du 30-08-2026)

> Matière brute du plan `PLAN-SITE-PREMIUM.md` §5.5. Chaque ligne est LUE (`fichier:ligne`) ; les `?` ne le sont pas. Rien ici n'est une pastille du site : c'est ce qu'il reste à MESURER avant de peindre.

## 1 · Migrations (`supabase/migrations/`) — 13 fichiers

| fichier | suivi git | contenu |
|---|---|---|
| `0001_init.sql` | suivi | `workouts`, `logged_exercises`, `strength_sets`, `cardio_phases`, `syntheses` (`:77`) |
| `20260729120000_woop_schema.sql` | suivi | recréation des 4 tables + 7 index |
| `20260814180000_cartes_lune.sql` | suivi | `cards`, `user_cards`, bucket `cards` |
| `20260828120000_booster_noir.sql` | suivi | `user_boosters`, `coin_ledger`, 3 index uniques partiels, `claim_booster_legendaire()`, `solde_noir()` |
| `20260828160000_wallet_coffre.sql` | suivi | `booster_progress`, `reward_rules`, `solde_argent()`, `etat_coffre()` |
| `20260828190000_gains_coffre.sql` | suivi | `solde_or()`, `claim_retour_quotidien()`, `cloturer_seance()`, `reclamer_noeud_chemin()`, `historique_gains()`, `claim_booster()`, 3 index |
| `20260829120000_annonces.sql` | suivi | `etat_coffre()` v2 (reste dérivé), `regles_annonces()`, `roll_rare(uuid)`, `cloturer_seance()` v2, **17 clés de rythme** (`:98-151`) |
| `20260829130000_roll_rare_prive.sql` | suivi | `revoke` nominatifs sur `roll_rare` (anon/authenticated/public) |
| `20260829150000_ouvrir_booster.sql` | suivi | `ouvrir_booster(p_legendaire)` — **déclarée NON DÉPLOYÉE** dans le code (`Woop/Services/SacreServeur.swift:325`) |
| **`20260829160000_noeuds_chemin_lus.sql`** | **`??`** | 1 fonction lecture `noeuds_chemin_reclames()` (`:27`) — union `coin_ledger`/`user_boosters`. Aucune table/index |
| **`20260829170000_regles_chemin.sql`** | **`??`** | 5 clés `reward_rules` : `chemin_chapitres/noeuds_par_chapitre/seances_par_chapitre/rang_recompense_milieu/rang_tresor` (`:37-50`). Aucune DDL |
| **`20260830090000_welcome_chaque_connexion.sql`** | **`??`** | `do update` sur 3 clés : `welcome_absence_jours=0`, `welcome_cooldown_jours=0`, `welcome_max_mois=31` (`:37-44`). Aucune DDL |

Les 3 non suivies sont **écrites, non commitées** ; deux d'entre elles sont pourtant décrites comme répondant en HTTP (`tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md:144-145`) — donc déployées avant d'être commitées.

## 2 · Edge functions (`supabase/functions/`) — 2

| fonction | déployée ? | preuve |
|---|---|---|
| `forge-card` | **oui**, vérifiée de bout en bout | `supabase/README.md:53-66`, `tools/sacre/SUPABASE-A-FAIRE.md:26-34`, `tools/sacre/SUPABASE-PIPELINE.md:29` |
| `weekly-synthesis` | **non** — « écrite, PAS déployée » | `supabase/README.md:51` ; code mort côté app (`docs/screens/reward-popup.md:238-241`) |

## 3 · Frontière app ↔ serveur

**RPC appelées** (toutes via `SacreServeur.rpc`, `Woop/Services/SacreServeur.swift:446`) : `etat_coffre` (`:77`), `solde_argent` (`:99`), `claim_booster_legendaire` (`:109`), `cloturer_seance` (`:185`), `claim_retour_quotidien` (`:143`), `reclamer_noeud_chemin` (`:278`), `claim_booster` (`:297`), `ouvrir_booster` (`:329`), `historique_gains` (`:351`), `noeuds_chemin_reclames` (`:380`).
**REST direct** : `reward_rules` en `select` (`SacreServeur.swift:402`) ; `workouts`/`logged_exercises`/`strength_sets`/`cardio_phases` en upsert seul (`SupabaseSync.swift:113-116`).
**Functions** : `functions/v1/forge-card` (`ForgeServeur.swift:45`), `functions/v1/weekly-synthesis` (`SynthesisService.swift:109`).

**Défini mais jamais appelé (🔵)** : `regles_annonces()` (`20260829120000_annonces.sql:174`), `solde_or()` (`20260828190000_gains_coffre.sql:25`), `solde_noir()` (`20260828120000_booster_noir.sql:191`), table `booster_progress` (créée `wallet_coffre.sql:50`, plus lue depuis `annonces.sql:24-46`), table `syntheses` (`0001_init.sql:77`), table `user_cards` (jamais lue), 20 des 27 clés `reward_rules`.
**Appelé mais pas défini (🔴)** : aucun — sauf `ouvrir_booster`, appelé (`SacreServeur.swift:329`) alors que sa migration est marquée non déployée.

## 4 · Inventaire

| # | titre | domaine | état | coût | preuve | ✔/? |
|---|---|---|---|---|---|---|
| 1 | Écrire `SupabaseSync.pull` (workouts + enfants) | Sync | 🔴 | 🧗 | `Woop/Services/SupabaseSync.swift:70` (aucun `select`) ; `tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md:147-149` | ✔ |
| 2 | Unifier la définition du jour d'une séance | Calendrier-chemin | 🔴 | ⏱️ | `tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md:51-58` | ✔ |
| 3 | Faire lire le même choix de sticker aux deux écrans | Calendrier-chemin | 🔴 | ⏱️ | `tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md:69-76` | ✔ |
| 4 | Inventer une source de sticker (colonne ou règle) | Calendrier-chemin | ⚪ | ⏳ | `tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md:78-86` | ✔ |
| 5 | Trancher « où commence un chapitre » (origine serveur) | Calendrier-chemin | ⚪ | 🧗 | `docs/screens/duolingo-chemin.md:304-307` ; `supabase/migrations/20260829170000_regles_chemin.sql:16-23` | ✔ |
| 6 | Trancher « un nœud = un jour » vs « = une séance » | Calendrier-chemin | 🔴 | 🧗 | `tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md:92-114` | ✔ |
| 7 | Définir ce qu'est un jour « fait » (séance sans série ?) | Calendrier-chemin | ⚪ | ⏱️ | `docs/screens/duolingo-chemin.md:308-310` | ✔ |
| 8 | Définir ou supprimer l'état `parfait` | Calendrier-chemin | ⚪ | ⏱️ | `docs/screens/duolingo-chemin.md:311-312` | ✔ |
| 9 | Trancher le comportement au-delà de 35 séances | Calendrier-chemin | ⚪ | ⏳ | `docs/screens/duolingo-chemin.md:316` | ✔ |
| 10 | Commiter les 3 migrations non suivies | Économie | 🔵 | ⏱️ | `git status` : `20260829160000`, `20260829170000`, `20260830090000` en `??` | ✔ |
| 11 | Déployer / re-vérifier `ouvrir_booster` | Économie | 🔴 | ⏱️ | `Woop/Services/SacreServeur.swift:325-326` ; `Woop/Services/EconomieWoop.swift:274-279` | ✔ |
| 12 | Faire lire `etat_coffre()` à la home et au profil | Économie | 🔴 | ⏱️ | `Woop/Views/ProfilLune.swift:129` ; `HomeAuroraView.swift:246` ; `HomeNuit.swift:2279` ; `docs/screens/duolingo-chemin.md:272-276` | ✔ |
| 13 | Supprimer `CoffreFortPurse.perSeries = 20` | Économie | 🟡 | ⏱️ | `Woop/Views/CoffreFortPurse.swift:28-29` | ✔ |
| 14 | Supprimer le `+20` de BRAVO | Économie | 🟡 | ⏱️ | `Woop/Views/BravoLab.swift:642` | ✔ |
| 15 | Remplacer `piecesRetourQuotidien = 10` par la base | Économie | 🟡 | ⏱️ | `Woop/Views/ExerciseDetailView.swift:2269-2270` | ✔ |
| 16 | Appeler `regles_annonces()` (jamais appelée) | Annonces | 🔵 | ⏳ | `supabase/migrations/20260829120000_annonces.sql:174` ; aucun appel Swift | ✔ |
| 17 | Consommer les 17 clés de rythme de `reward_rules` | Annonces | 🔵 | 🧗 | `…annonces.sql:98-151` ; grep Swift : 0 lecture | ✔ |
| 18 | Consommer les 3 clés `welcome_*` | Annonces | 🔵 | ⏳ | `20260830090000_welcome_chaque_connexion.sql:21-24` ; `tools/rewards/ANALYSE-WELCOME-BACK.md:43-47` | ✔ |
| 19 | Construire la porte de production du Welcome Back | Annonces | ⚪ | ⏳ | `tools/rewards/ANALYSE-WELCOME-BACK.md:90-95` | ✔ |
| 20 | Brancher le bouton `Claim` de la card welcome | Annonces | 🔴 | ⏱️ | `docs/screens/reward-popup.md:223` | ✔ |
| 21 | Brancher `PiecesNotif` sur `credite: true` | Annonces | ⚪ | ⏱️ | `tools/rewards/ANALYSE-WELCOME-BACK.md:98-99` | ✔ |
| 22 | Créditer les pop-ups `.moment` / `.reward` | Annonces | 🔴 | ⏳ | `docs/screens/reward-popup.md:222` | ✔ |
| 23 | Remplacer `DecideurSerie` (% 10/5/3) par un moteur serveur | Annonces | 🟡 | 🧗 | `docs/screens/reward-popup.md:220` ; `tools/rewards/PLAN-REWARDS-BACKEND.md:1240-1245` | ✔ |
| 24 | Ajouter `serie_index` / `facts` à l'outbox | Annonces | 🟡 | ⏳ | `tools/rewards/PLAN-REWARDS-BACKEND.md:1298-1300` ; `Woop/Services/OutboxGains.swift:42-51` | ✔ |
| 25 | Écrire le fact engine (`workout_facts` → 404) | Stories | ⚪ | 🧗 | `tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md:122-124` ; `docs/screens/reward-popup.md:221` | ✔ |
| 26 | Ouvrir une story en fin de séance (aujourd'hui : calendrier seul) | Stories | ⚪ | ⏳ | `tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md:120-121` | ✔ |
| 27 | Écrire `narrate-reward` (le contrat JSON + bornes) | Stories | ⚪ | 🧗 | `docs/screens/reward-popup.md:226`, `:243-255` | ✔ |
| 28 | Déployer ou supprimer `weekly-synthesis` | Stories | ⚪ | ⏱️ | `supabase/README.md:51` | ✔ |
| 29 | Valider le JWT dans `weekly-synthesis` (préfixe seul) | Compte | 🔴 | ⏱️ | `docs/screens/reward-popup.md:241` | ? |
| 30 | Monter `ProgressionView` ou supprimer `SynthesisCard` + `syntheses` | Stories | ⚪ | ⏱️ | `Woop/Views/ProgressionView.swift:14` jamais instanciée ; `supabase/migrations/0001_init.sql:77` | ✔ |
| 31 | Remonter le tirage du chemin au serveur | Économie | 🟡 | ⏳ | `Woop/Views/RewardChemin.swift:73-76` ; `docs/screens/duolingo-chemin.md:277-279` | ✔ |
| 32 | Remonter les compteurs de pitié du chemin | Économie | 🟡 | ⏳ | `Woop/Views/RewardChemin.swift:138-145` ; `docs/screens/duolingo-chemin.md:292` | ✔ |
| 33 | Remonter `chemin.tirages` (le journal par nœud) | Calendrier-chemin | 🟡 | ⏳ | `docs/screens/duolingo-chemin.md:290` ; `RewardChemin.swift:123-129` | ✔ |
| 34 | Aligner `claim_booster_legendaire` : 500 P0002 → 200 + motif | Économie | 🔴 | ⏱️ | `tools/rewards/PLAN-REWARDS-BACKEND.md:1320-1324` ; `docs/screens/notification.md` §6.5 (sonde 500) | ✔ |
| 35 | Fermer la lecture des clés de rareté (table à part sans policy) | Économie | 🔴 | ⏳ | `tools/rewards/PLAN-REWARDS-BACKEND.md:1272-1275` ; `…annonces.sql:179` | ✔ |
| 36 | Supprimer ou réalimenter `booster_progress` (table morte) | Économie | 🔵 | ⏱️ | `20260828160000_wallet_coffre.sql:50` ; `20260829120000_annonces.sql:24,46` | ✔ |
| 37 | Retirer `solde_or()` et `solde_noir()` (jamais appelées) | Économie | 🔵 | ⏱️ | `20260828190000_gains_coffre.sql:25` ; `20260828120000_booster_noir.sql:191` | ✔ |
| 38 | Trancher la conversion automatique pièces → sachets | Économie | ⚪ | ⏳ | `docs/screens/coffre-rewards.md:287-292` ; `tools/coffre-v2/BACKEND-COFFRE.md:114-123` | ✔ |
| 39 | Trancher le fuseau du « jour » (UTC vs profil) | Économie | 🟡 | ⏳ | `docs/screens/coffre-rewards.md:254-262` ; `SacreServeur.swift:248-253` | ✔ |
| 40 | Passer `booster_id` à `forge-card` (garde légendaire jamais armée) | Forge | 🔴 | ⏱️ | `ForgeServeur.swift:39-43` ; appel réel sans id `BoosterLab.swift:2260` ; id jeté `WoopApp.swift:1222-1223` | ✔ |
| 41 | Passer `workout_id` à `forge-card` (colonne toujours nulle en prod) | Forge | 🟡 | ⏱️ | `ForgeServeur.swift:36` ; `BoosterLab.swift:2260` | ✔ |
| 42 | Retirer le repli `jwtBanc()` du chemin de production | Compte | 🔴 | ⏱️ | `ForgeServeur.swift:90-100` (identifiants en dur) ; `BoosterLab.swift:2253-2260` ; mise en garde `docs/screens/reward-popup.md:257-259` | ✔ |
| 43 | Garde serveur d'idempotence sur `forge-card` (consommer un sachet) | Forge | ⚪ | ⏳ | `tools/sacre/SUPABASE-A-FAIRE.md:78-82` | ✔ |
| 44 | Écrire le `CollectionStore` qui lit `user_cards` | Forge | 🔴 | 🧗 | `Woop/Views/SacreAccueil.swift:12-13`, `:48` (store mémoire) ; `tools/sacre/SUPABASE-A-FAIRE.md:45-54` | ✔ |
| 45 | Cache disque des PNG de cartes | Forge | ⚪ | ⏳ | `tools/sacre/SUPABASE-A-FAIRE.md:56-60` | ✔ |
| 46 | Source unique des 25 familles (Deno + Swift + totaux profil) | Forge | 🟡 | ⏳ | `tools/sacre/SUPABASE-A-FAIRE.md:36-39`, `:101-106` ; `supabase/README.md:62-64` | ✔ |
| 47 | Générer `depth_path` (null partout) | Forge | ⚪ | ⏳ | `tools/sacre/SUPABASE-A-FAIRE.md:109-111` | ✔ |
| 48 | Trancher : un doublon de famille rapporte-t-il des pièces ? | Forge | ⚪ | ⏱️ | `tools/sacre/SUPABASE-A-FAIRE.md:115-117` | ✔ |
| 49 | Rattrapage hors-ligne du booster (outbox couvre l'argent, pas la forge) | Forge | ⚪ | ⏳ | `tools/sacre/SUPABASE-A-FAIRE.md:91-94` ; `OutboxGains.swift:42-51` (3 cas, aucun forge) | ✔ |
| 50 | Remplacer l'auth par numéro + mot de passe dérivable | Compte | 🔴 | 🧗 | `Woop/Services/Supabase.swift:27-35` (2 comptes en dur, mot de passe = `woop-33…-2026`) | ✔ |
| 51 | Sortir URL/clé anon du binaire vers Info.plist obligatoire | Compte | 🟡 | ⏱️ | `Woop/Services/Supabase.swift:11,16` ; `ForgeServeur.swift:15-16` (repli en dur) | ✔ |
| 52 | Vérifier/réparer `schema_migrations` avant tout `db push` | Sync | 🔴 | ⏱️ | `supabase/README.md:34-44` (deux migrations posées au dashboard) | ✔ |
| 53 | Écrire les policies d'écriture des tables wallet/boosters | Économie | ⚪ | ⏳ | `tools/sacre/SUPABASE-A-FAIRE.md:113-114` | ? |
| 54 | Trancher `notif_consomme_budget` | Annonces | 🔵 | ⏱️ | `tools/rewards/PLAN-REWARDS-BACKEND.md:1315-1317` | ✔ |
| 55 | Trancher `ecart_exige_les_deux` (OU vs ET) | Annonces | 🔵 | ⏱️ | `tools/rewards/PLAN-REWARDS-BACKEND.md:1318` | ✔ |
| 56 | Écrire le contrat par catégorie (quelle robe pour quel événement) | Annonces | ⚪ | ⏳ | `docs/screens/reward-popup.md:224` | ✔ |
| 57 | Sortir le token perso du compte pro (`.secrets/supabase-access-token`) | Compte | 🔴 | ⏱️ | `tools/sacre/SUPABASE-A-FAIRE.md:7-12` ; `supabase/README.md:6-21` | ✔ |
| 58 | Faire redescendre les jours « faits » du serveur (`EtatDuo.faits` démo) | Calendrier-chemin | 🟡 | ⏳ | `tools/flow/BUGS-RESTANTS.md:467-469` | ✔ |

## DÉPENDANCES

- **#1 (`pull`) bloque #2, #3, #6, #7, #25, #26, #58** — les trois écrans dérivent de SwiftData ; sans lecture, unifier une définition ne répare qu'un appareil neuf (`AUDIT…:147-149`).
- **#6 (nœud = jour ou séance) bloque #5, #7, #8, #9** — la composition (`regles_chemin.sql`) dit de quoi un chapitre est fait, jamais quand il commence (`20260829170000_regles_chemin.sql:16-23`).
- **#25 (fact engine) bloque #26, #27, #56, #23** — les variants TOP SESSION / ×2 sont peints et inatteignables (`AUDIT…:126`).
- **#12 (lire `etat_coffre` partout) bloque #13, #14, #15** — supprimer les constantes avant que les écrans lisent le serveur ferait tomber les nombres à zéro hors ligne.
- **#11 (`ouvrir_booster` déployée) bloque #40** — sans `opened_at`, le sachet consommé n'a pas d'id à sceller.
- **#40 bloque #43 et #44** — pas de `booster_id` ⇒ pas d'idempotence de forge, pas de lien carte↔sachet.
- **#16 (`regles_annonces`) bloque #17, #18, #54, #55** — un appel agrégé, puis toutes les clés suivent sans changement de client.
- **#19 (porte Welcome Back) bloque #18, #20, #21**.
- **#52 (`migration repair`) bloque #10 et #11** — un `db push` avant réparation rejouerait `0001` et `20260729120000`.
- **#50 (vraie auth) bloque #42** — tant qu'il n'y a que deux comptes en dur, le repli banc est la seule porte d'un appareil non appairé.

## CE QUE JE N'AI PAS PU VÉRIFIER

- **Le déploiement réel de chaque migration.** Pas de base locale, pas de `supabase migration list` (le dépôt note lui-même « CLI non connectée : 401 » — `docs/screens/notification.md` §6.5). Les mentions « déployé » viennent de sondes HTTP consignées dans les docs (29-08), pas d'une table `schema_migrations` que j'aurais lue. En particulier : `20260829150000_ouvrir_booster.sql` est **commitée mais déclarée non déployée** (`SacreServeur.swift:325`), et `20260830090000_welcome_chaque_connexion.sql` (30-08) n'a **aucune trace de sonde** — son état est inconnu.
- **L'état des secrets de `forge-card`** (`OPENAI_API_KEY`) et le contenu de `.secrets/` : gitignorés, non lus.
- **Le contenu réel de `reward_rules` en prod** : les valeurs citées sont celles des fichiers SQL ; un `do nothing` (`regles_chemin.sql:51`) n'écrase pas une valeur préexistante.
- **Les policies RLS effectivement en vigueur** : lues dans les migrations, jamais interrogées.
- **`docs/site/index.html`** : exclu de ma passe par consigne — les états 🔵/🟡/⚪/🔴 ci-dessus sont dérivés du code et des plans, pas du site.