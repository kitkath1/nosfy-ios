# TestFlight — plan du 18 septembre 2026

Demande de Kathryn : lancer TestFlight, pour qu'un nouvel utilisateur
joue l'app de bout en bout. Ce plan part de l'état vérifié
(`ETAT-PRODUCTION-2026-09-18.md`, page Test QA du site, `MULTI-SESSION.md`)
et de deux mesures faites ce matin. Il ne repeint aucun verdict.

## Mesuré ce matin (11:50 Paris)

| Mesure | Résultat | Preuve |
|---|---|---|
| Archive Release de l'arbre partagé, build 79 | `ARCHIVE SUCCEEDED`, 0 erreur, 50 avertissements Swift | scratchpad `archive-79.log` |
| Export pour App Store Connect (méthode `app-store-connect`, signature automatique) | `EXPORT SUCCEEDED` ; certificat « Cloud Managed Apple Distribution », profils « iOS Team Store Provisioning Profile » app + widgets ; `Nosfy.ipa` 339 Mo | scratchpad `export-79/DistributionSummary.plist` |
| Versions dans l'archive | app et widgets : 1.0 (79), iOS minimum 26.0, `NSSupportsLiveActivities` vrai, entitlement Sign in with Apple présent | `plutil` sur l'archive |
| Serveur | `ACTIVE_HEALTHY`, Apple activé (`fr.kathryn.woop`), trois secrets Apple posés, 6 fonctions `ACTIVE`, migrations locales = distantes jusqu'à `20260918084850` | `etat_backend.py`, API de gestion |
| Aucune source modifiée pendant l'archive, aucun autre `xcodebuild` actif | vrai | `find -newer`, `pgrep` |

Ce que ces mesures ne disent PAS : que le binaire marche sur le téléphone
(77 jamais installé, 76 sans le raccord `synchroniser_seance`), ni que
la compte neuf passe la feuille Apple réelle (jamais mesurée depuis la pose
de la clé le 18-09).

## Ce qui bloque l'envoi (par ordre)

1. **HEAD ne compile pas seul.** L'archive vient de l'arbre partagé :
   77 fichiers Swift/projet modifiés non committés (~2 600 lignes),
   4 Swift non suivis (`PlayerSeance.swift`, `CartesServeur.swift`,
   `CartesQABanc.swift`, `OrphanProbe.swift`), la migration
   `20260918084850` déployée mais non suivie, `forge-card/index.ts` v8
   déployé mais non committé. Un build TestFlight sans SHA est un build
   qu'on ne pourra pas rejouer ni relire.
2. **Fiche App Store Connect** : pas vérifiée (aucun accès depuis ce dépôt).
   Il faut une fiche au bundle `fr.kathryn.woop`, nom Nosfy, SKU, langue.
   La clé API `~/.appstoreconnect/private_keys/AuthKey_48V7W7DND9.p8`
   existe (5 août) mais son Issuer ID n'est nulle part : soit Kathryn le
   donne, soit l'envoi passe par le compte Xcode déjà connecté
   (`kathryn@soluo-avocats.fr`, c'est lui qui a signé l'export).
3. **Conformité : posée le 18-09 à 12:36** — `ITSAppUsesNonExemptEncryption = false`
   dans `Nosfy/Info.plist` et `NosfyWidgets/Info.plist` ; `Nosfy/PrivacyInfo.xcprivacy`
   (aucun pistage ; UserDefaults CA92.1, systemUptime 35F9.1 ; identifiant Apple,
   e-mail, prénom, séances, « but » liés à la personne, usage app). Vérifié dans le
   bundle compilé (plutil : manifeste présent, clé `false` app + extension). Les
   widgets n'appellent aucune API à raison requise. L'archive 79 ne les porte pas :
   **re-archiver en 80** avant l'envoi. App Store Connect non lu.
4. **CGU** : texte posé l'après-midi du 18-09 dans `Nosfy/Views/CGUPage.swift`
   (14 articles, FR et EN par `L()`, version datée), à la place du texte
   d'attente de `ProfilLune.swift`. Reste à elle : la relecture juridique
   (identité de l'éditeur et adresse de contact, aujourd'hui renvoyées à la
   fiche App Store ; âge minimal 15 ans ; droit français) et l'affichage
   vérifié dans Réglages. Pas bloquant pour des testeurs internes ;
   nécessaire pour la revue externe et l'App Store.

## Ce qui n'est pas mesuré sur le téléphone (Test QA)

QA 08–13 (relance, déconnexion, reconnexion, suppression, inscription
interrompue), 14 (compte neuf → première séance → stories → coffre),
15 (compte existant restitué), 17 (Route du compte vide) : `a_valider`.
QA 18 (chauffe Profil/manège) : `ko`. QA 19 (Cartes) : « Ouvrir » non
franchi dans 3 scénarios sur 4 au simulateur, révélation non validée.

## Bancs rejoués le 18-09 à 12:18 (session CGU, sans téléphone ni simulateur)

14 bancs PASS : Route vide 1277, compte `--flow` 50, gains/progression 35,
parcours rewards (compte neuf → séances → lune → cartes → reconnexion), cartes
28, portes 34, widgets serveur 10, collection 9 (banc corrigé : slots par
référence, comme `ma_collection` depuis 84850), session 15, sync 12, pull 9,
outbox 13, inscription 12, live activity 16. A/B/C lancés en parallèle (comptes
jetables ou lecture seule), D en série.

**12:32-12:40, suite** : les trois bancs ont été portés sur `synchroniser_seance`
(faits sur compte jetable) et rejoués en série : **cardio 22 ✓, faits 14 ✓,
coffre 53 ✓**. Le barème, les faits et la conversion tiennent après 083033 ;
la séance jamais poussée ne paie plus (503, solde inchangé). Litiges levés sur
le site. Le paragraphe ci-dessous décrit l'état d'avant portage.

Trois bancs ne prouvaient plus rien à 12:19 :
`verif_cardio` (3 ✓ · 21 ✗), `verif_faits` (2 ✓ · 12 ✗), `verif_backend_coffre`
(partiel). Cause unique : ils sèment leurs séances par REST et `cloturer_seance`
répond `503 seance_a_synchroniser` depuis 083033. Le serveur fait ce que la
carte dit ; les montants cardio, les faits et la conversion n'ont pas été
re-mesurés après 083033. `verif_forge` et `verif_backend_sachet` non lancés
(ils font peindre une carte par OpenAI). Journaux hors Git : scratchpad de la
session, `bancs/*.log`.

Ce que ces bancs ne disent toujours pas : la feuille Apple réelle, la relance,
la déconnexion/reconnexion et la première séance **sur l'iPhone** (QA 8-11,
14, 15, 17). C'est l'étape 5, à deux, au câble.

## Le plan

| Étape | Qui | Durée | Contenu |
|---|---|---|---|
| 1. Sceller la version | Claude, sur ordre « commit » | 15 min | Un commit d'intégration par chemins explicites : `Nosfy/`, `NosfyShared/`, `NosfyWidgets/`, `Nosfy.xcodeproj/project.pbxproj`, `supabase/migrations/20260918084850*`, `supabase/functions/forge-card/`, `docs/site/`. Tag `testflight-79`. Les sessions Cartes/Compte/chauffe ont annoncé leur clôture dans `MULTI-SESSION.md` ; vérifier qu'aucune n'écrit avant. |
| 2. Conformité | Claude, même commit | 10 min | `ITSAppUsesNonExemptEncryption = NO` dans les deux Info.plist ; `PrivacyInfo.xcprivacy` app (UserDefaults CA92.1, boot time 35F9.1) ; réserves ajoutées en page QA du site, artefact + vérificateur. Puis re-archiver en 80 (l'archive 79 ne contient pas ces fichiers). |
| 3. Fiche App Store Connect | Kathryn | 5–10 min | Créer l'app (Nosfy, `fr.kathryn.woop`) si elle n'existe pas ; donner l'Issuer ID de la clé 48V7W7DND9 ou laisser l'envoi passer par Xcode. |
| 4. Envoi | Claude, sur ordre | 10 min + 10–30 min de traitement Apple | `xcodebuild -exportArchive … destination upload`. Puis groupe interne, Kathryn testeuse, installation depuis l'app TestFlight (le conteneur est gardé, sa session reste). |
| 5. QA du téléphone | Kathryn + Claude au câble | 45–60 min | Dans l'ordre de la page Test QA : 08 relance, 09 déconnexion, 10 reconnexion (les 2 séances et 50 pièces doivent revenir), puis compte NEUF (second Apple ID, ou suppression 11 de son compte avec son accord explicite) : 02–07, 17 Route au premier galet, 14 première séance → gains → story → coffre → « Ouvrir » un sachet (le point KO du sim). Chaque verdict écrit dans `qa.ts` après lecture du journal. |
| 6. Testeurs externes | plus tard | 1–2 jours de Beta App Review | Exige l'URL de politique de confidentialité, les CGU, un contact. Pas avant que 5 soit vert. |

## Réserves qui restent vraies après TestFlight

- Chauffe : QA 18 `ko`, correctif 78 non installé. Un testeur sentira le
  téléphone chauffer sur Profil/manège.
- Intégrité : 52 avertissements de l'analyseur sécurité Supabase (fonctions
  `security definer` exposées), non revus globalement.
- Poids : 339 Mo (66 vidéos). Téléchargement Wi-Fi conseillé aux testeurs.
- iOS 26.0 minimum : un testeur sous iOS 25 ne pourra pas installer.
