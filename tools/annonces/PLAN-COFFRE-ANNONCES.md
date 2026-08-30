# PLAN — LE COFFRE ET LES ANNONCES : ce que Kathryn a tranché le 30-08, ce que le code fait, ce qui change

> Écrit le 30-08-2026 au soir, **avant toute ligne de code** (sa consigne : « ne code pas,
> questionne-moi »). Tout ce qui est affirmé sur le code vient d'une lecture `fichier:ligne`
> relue par un second agent (workflow `comprendre-coffre-annonces`, 8 agents, 356
> lectures, 2 sondes HTTP) — jamais de mémoire. Les numéros de `WoopApp.swift` sont ceux
> de 17:47 : une autre session l'édite, à re-relever avant tout patch.
> La loi qui s'applique : `.claude/skills/woop-backend/SKILL.md` (soldes dérivés, idempotence
> par index, erreurs métier en 200, rien de déployé sans sonde, **la doc dans le même commit**).

---

## §0 — Ce qu'elle a tranché (ses mots, rien de déduit)

| sujet | la décision |
|---|---|
| **le titre** | deux pages : **« Le coffre »** (pièces, sachets, argent, profil) et **« Les annonces »** (dalles, pop-ups, Welcome Back, rythme) |
| **le vert** | un domaine est vert quand **tout est branché ET rien ne ment** |
| **la fin de séance** | story → **une page noire EN PLUS**, « un petit chargement », où les notifs **s'empilent** (pièces, sachet, argent) → **retour sur le CHEMIN, pas la home** : actualisation + animation « séance terminée » sur la route → **puis** la pop-up sachet « Ouvrir » |
| **clôture** | pièces + sachet = **deux événements, deux annonces empilées** — la doctrine reste « une annonce PAR événement » |
| **pop-ups en séance** | rangs **3 / 5 / 10 « et plus », plus aléatoire** ; **le contenu s'adapte, les chiffres changent, avec l'IA** ; **l'IA sert la PROCHAINE** pop-up, jamais attendue |
| **le rythme** | 4 pop-ups max / séance, 1 en pièces, 1 vidéo, 6 dalles ; écart mini **3 séries ET 6 min** ; une dalle **ne consomme pas** le budget |
| **Welcome Back** | **bouton Claim** dans la pop-up, **chaque jour à minuit chez elle** (pas UTC) ; les +10 partent **au tap** ; puis une **dalle « +10 » dans l'app** sur la home — pas une notification iPhone |
| **la jauge** | à 100 pièces **un sachet apparaît tout seul**, le nombre monte (1, 2…), bouton **Ouvrir** ; **les pièces RETOMBENT** (converties) ; le sachet forfaitaire de clôture **s'affiche aussi** |
| **les nombres** | inchangés : 20 / série · +10 / jour · 100 = 1 sachet · 1 argent = 1 noir · nœud 100-200 |
| **le profil** | pièce d'or, pièce d'argent, le géant, le booster noir : **toujours visibles, même à 0** |
| **pièce d'argent** | gagnée (1 / 30 à la clôture) → **une dalle « argent » dans la pile** |
| **nœud du chemin** | la card à gratter **ET une dalle après** (« +176 », robe pièces ou booster) |
| **la flamme 🔥** | **oui : jours d'affilée, comptée au serveur, SANS bonus** |

---

## §1 — Ce qu'il me reste à te demander (réponds « ok » ou corrige — je pars sur le défaut)

Les lecteurs ont trouvé dix points que tes mots ne tranchent pas tout à fait. Le défaut est
entre parenthèses ; « go » sans commentaire = le défaut.

1. **Rang 3 puis rang 5** : deux séries d'écart, sous la règle « 3 séries ET 6 min » que tu as
   validée. *(défaut : les rangs fixes 3 / 5 / 10 gagnent — l'écart ne s'applique qu'aux
   pop-ups tirées au hasard après le 10)*
2. **« 10 et plus »** = 10, puis **un rang au hasard toutes les 5 à 8 séries** (15±, 21±…),
   jamais tous les multiples comme aujourd'hui ; et la **vidéo** une seule fois, au rang 10.
   *(défaut : oui)*
3. **« Les chiffres changent avec l'IA »** — la loi de la maison dit : *l'IA écrit les MOTS,
   les nombres viennent des faits* (reps, kg, total, rang, record). Donc l'IA **choisit de
   quel fait parler** et comment le dire ; elle n'invente jamais un chiffre. *(défaut : c'est
   ça — si tu voulais que l'IA choisisse des nombres, dis-le, c'est un autre chantier)*
4. **La pop-up « Ouvrir » après le chemin** : le sachet a déjà été annoncé dans la pile —
   cette pop-up est une **invitation** (« ton sachet t'attend »), pas une seconde annonce.
   *(défaut : invitation)*
5. **La page WIN de la story** (le butin : compteur qui roule, sachet plaqué) dit déjà pièces
   + sachet ; la page noire **les redit** en dalles. *(défaut : oui, c'est le « reçu »)*
6. **L'escale COFFRE du 28-08** (« Ouvrir » → coffre → manège) : tes mots du 30-08 n'en
   parlent plus. *(défaut : « Ouvrir » va **droit au manège**, comme aujourd'hui)*
7. **« Minuit chez toi »** : le serveur ne croit jamais le fuseau du téléphone (voyage dans le
   temps = farm). *(défaut : une règle serveur `fuseau_jour = Europe/Paris`, une ligne à
   changer si tu déménages — pas de table de profil)*
8. **La dalle « +10 »** : au tap tout de suite (le montant est connu), ou après la réponse du
   serveur ? *(défaut : au tap, la loi « le montant est local, le journal rattrape » ; si le
   serveur dit « déjà pris » — autre appareil — rien ne s'affiche de plus)*
9. **Le bouton d'achat** (« 100 coins open one », `claim_booster`) : avec la conversion
   automatique le solde ne dépasse plus jamais 99 — l'achat ne peut plus réussir. *(défaut :
   on le RETIRE de l'app et on ferme la fonction ; « Ouvrir » ouvre un sachet qui existe
   déjà)*
10. **Le booster ORANGE au profil** : tu as nommé l'or, l'argent, le géant et le noir — l'orange
    a le même code (`if > 0`). *(défaut : visible à 0 lui aussi)*

---

## §2 — Ce que le code fait AUJOURD'HUI (relu, pas déduit)

### 2.1 La fin de séance
- `terminerSeance()` (`WoopApp.swift:455-536`) : gain = `séries × piecesParSerie` (taux lu du serveur,
  :472-473) ; **bascule TOUJOURS sur la home** (:489) — et `celebrateFinishedWorkout()`
  (:1666-1673, appelée :1501-1503) force `.home` une seconde fois ; `push` + `cloturer_seance`
  partent en `Task.detached` (:510-513), jamais attendus ; story à +2,0 s (:532-535).
- À la fermeture de la story, `enchainerApresStory()` (:543-556) : capsule `notifPieces = gain`
  (le calcul LOCAL) à +0,3 s, retirée à +3,3 s, puis `SacreEtat.shared.proposer()` à +3,4 s — sur la home.
- La réponse de `cloturer_seance` **est lue** (`SacreServeur.swift:189-226` → `OutboxGains.swift:191-205`
  → `EconomieWoop.appliquer` :207-214 : or, reste, `argent += 1`, `boostersServeur += 1`) mais **aucune
  annonce ne la regarde** : la pièce d'argent finit dans un `print`.
- La story se ferme sur le BUTIN (`StoryFlow.swift:275-307`) — pas de page noire ; le noir n'est que le fond.
- Un seul créneau de dalle : `notifPieces: Int?` (`DepartSeance.swift:43`, hôte `WoopApp.swift:1237-1244`) —
  une seconde écriture **écrase** la première ; robe pièces seule (`PlayerSeance.swift:260-320`).
  Les 3 robes du plan V9 (jauge, gros texte, châsse) ne vivent qu'au banc `-notifLab` ; la robe
  **booster** n'est pas codée ; aucune robe argent.
- Le chemin : `rafraichirReclamees()` ne part qu'à l'`onAppear` de la home (`HomeNuit.swift:2495`) ;
  `DuolinguoPage` n'a aucune séquence « séance terminée » (:1952-1990 = la cascade d'ouverture) ;
  seule la card ROUTE de la home glisse d'un pas à +0,8 s (`HomeNuit.swift:2589-2606`).

### 2.2 Les pop-ups en séance
- `DecideurSerie.pour` (`RestartSheet.swift:608-630`) : `% 10` → vidéo `reward-rare`, `% 5` → halo,
  `% 3` → moment (« Set N — {reps} reps at {kg} kg »), sinon pill. **Tous les multiples** de 3 et
  de 5 (3, 5, 6, 9, 10, 12, 15…), sans hasard, sans budget, sans horloge, sans serveur.
- Textes **en dur** (`ExerciseDetailView.swift:1097-1115`) ; `RewardPopup` n'a pas d'entrée pour des
  lignes géantes (`RewardCard.swift:68-82`), `Text(title)` sans `lineLimit` (:760-778) — l'IA n'a
  nulle part où écrire, un titre long casse la card.
- Les **22 clés de rythme** sont en base (`annonces.sql:96-152`) et `regles_annonces()` les rend
  (:174-181) : **personne ne les lit** (grep : un commentaire, `ExerciseDetailView.swift:2269`).
- `narrate-reward` : **n'existe pas** — sondé le 30-08 : `functions list` → `forge-card` seule
  (ACTIVE v4, `verify_jwt` true) ; `POST /functions/v1/narrate-reward` → 404 ; `weekly-synthesis`
  → 404 aussi (écrite, jamais déployée, jamais montée).

### 2.3 Le Welcome Back
- À chaque `scenePhase == .active` (`WoopApp.swift:83-92`), `reglerRetourQuotidien()`
  (`SacreServeur.swift:282-291`) poste `.retourQuotidien` **une fois par jour UTC** (marqueur
  `UserDefaults`) → `claim_retour_quotidien()` (`gains_coffre.sql:135-162`, jour UTC :146-151) →
  les +10 partent **tout seuls**. Aucune dalle.
- La card `.welcome` existe (2 robes), son « Claim » = `fermer()` (`RewardCard.swift:873-874`),
  **aucune porte de production** (bancs `-welcomeLab` et chip d'atelier seulement).
- Aucune fonction ne dit « disponible aujourd'hui ? » sans créditer.

### 2.4 Le coffre
- `etat_coffre()` : `reste = solde_or % prix_booster` sur le solde **TOTAL** (`sachet_scelle…sql:455-461`) —
  la sonde du site montre `solde_or 1360 → reste 60` : treize tranches de 100 qui ne sont des
  sachets nulle part. La migration du 29-08 l'écrit : « aucune conversion automatique, et c'est
  voulu » (`annonces.sql:38-48`) — **c'est ça que tu viens de trancher dans l'autre sens**.
- `claim_booster()` (`gains_coffre.sql:354-381`) débite 100 au tap, crée un sachet `achat`,
  **sans témoin d'idempotence** (double tap = deux achats) ; atteignable seulement depuis le
  profil quand `boosters == 0` (`ProfilLune.swift:1255-1265`) — le pied du coffre dit « N COINS
  TO GO » inactif (`CoffreV2.swift:2406-2408`).
- La raison `conversion_booster` existe dans le `check` du carnet depuis le 28-08 et **n'a jamais
  été écrite** ; `booster_progress` est morte (ne pas la réveiller — un solde se dérive).
- Le profil : pills noir et orange cachées à 0 (`ProfilLune.swift:562-574`), aucune vue de la pièce
  d'argent, le géant hors inventaire ; home et profil recalculent chacun un solde local.

### 2.5 La flamme
- **Rien**, nulle part : ni fonction, ni clé, ni colonne ; le seul « streak » est hebdomadaire,
  local, dans `CalendarView` que personne ne monte ; la flamme des galets est un glyphe.
  Ce qui permet de la dériver : `workouts.ended_at` (poussé par le client, `SupabaseSync.swift:88`).

### 2.6 La pièce d'argent et le chemin
- `roll_rare` (privée) tire 1/30 à la clôture, pity 45, cooldown 10 ; `cloturer_seance` rend
  `argent:true` **une seule fois** — rejouée, elle rend des zéros (:342-363) : une page noire
  qui recharge après un kill ne pourrait rien relire.
- `tirer_noeud_chemin` rend tout (type, montant, monnaie, robes, rarete) ; côté app la dalle ne
  part que pour les pièces (`RewardChemin.swift:286-294`), rien pour un tirage en sachets.

### 2.7 Ce qui contredit tes mots dans les DOCS (à réécrire, pas seulement le code)
- La doctrine §4 quaterdecies (« la pop-up REMPLACE la dalle ») et le commentaire de la clé
  `annonce_une_par_evenement` interdisent nommément « deux annonces à la fin » ; le site en fait
  un 🔴 — **c'est voulu maintenant**.
- Le plan (§2) interdit « tout déclencheur à position fixe (série 5/10/15) » ; le site range les
  modulos comme LE défaut — **tu veux des rangs fixes 3/5/10, puis du hasard**.
- La loi « jamais de chargement » (le montant est local) — **tu acceptes un petit chargement**
  sur la page noire, parce que l'argent est tiré au serveur.
- Fiches périmées depuis 8e8a0cc / 9ef6da1 : `notification.md:114-115,136,183,223`,
  `duolingo-chemin.md:136-150,176-178`, `coffre-rewards.md:214-220`, `reward-popup.md:221`
  (« workout_facts → 404 » est faux : sondé 400 P0001), `SKILL.md:37-39,118-120,143-146`,
  `SacreServeur.swift:293-299` (commentaire « tirage au front »).

---

## §3 — Le contrat par catégorie (ce tableau n'avait jamais été écrit)

| quand… | annonce | robe | qui sait quoi |
|---|---|---|---|
| série ordinaire | **dalle** « +20 », 2 s | pièces, en rotation | local (le taux vient du serveur) |
| série **3 / 5 / 10**, puis un rang au hasard toutes les 5-8 séries | **pop-up** | `.galet` (3) · `.halo` (5) · `.fire` + vidéo (10) · au hasard ensuite | le rang est tiré au client depuis les **clés serveur** ; le texte vient de l'IA préparée à la série d'avant, sinon gabarit |
| clôture — pièces | dalle dans **la pile** | pièces (jauge) | `cloturer_seance.pieces` |
| clôture — sachet forfaitaire | dalle dans la pile | **booster** (robe 4, à coder) | `booster_neuf` |
| clôture — pièce d'argent (1/30) | dalle dans la pile | **argent** (robe 5, à coder) | `argent` |
| clôture — sachet(s) converti(s) à 100 | dalle dans la pile | booster | `sachets_convertis` (nouveau) |
| après la route animée | **pop-up « Ouvrir »** | la card sachet | invitation, pas une annonce |
| 1er lancement après minuit (Paris) | **pop-up Welcome Back** + bouton **Claim** | `.welcome` (2 robes) | `retour_disponible` (nouveau, lu sans payer) ; le tap paie |
| après le Claim | **dalle « +10 »** sur la home | pièces | au tap |
| nœud du chemin | la card à gratter **+ dalle** | pièces ou booster selon le tirage | `tirer_noeud_chemin` |
| séance record | la story TOP (à la place de la normale) | — | moteur de faits (posé, à appeler — chantier stories, hors lot) |
| la flamme | affichée (home / route), **jamais annoncée** | — | `flamme` dans `etat_coffre` |

Hors contrat, à retirer si rien ne les prend : les robes `.neon` et `.spotlight` (aucun événement).

---

## §4 — LE SERVEUR : trois migrations, une edge function

Ordre imposé par la loi « écrire AVANT de lire » et par les dépendances. Chaque migration
nomme son verdict en tête et pointe ce plan ; `security definer`, `set search_path = public`,
`grant … to authenticated` ; **erreur métier = 200 avec un motif**.

### M1 — `2026083x_conversion_jour_flamme.sql` (le coffre dit vrai)
1. **La clé `fuseau_jour`** = `"Europe/Paris"` dans `reward_rules` (`on conflict do nothing`) et
   une fonction interne `jour_courant()` = `(now() at time zone (clé))::date`. Le jour devient
   **une ligne à changer**, jamais une valeur envoyée par le client (SKILL §4).
2. **`claim_retour_quotidien()`** écrit `jour = jour_courant()` (la ligne :149-151 que son propre
   commentaire désigne). L'index `(user_id, jour)` ne bouge pas.
3. **`convertir_pieces()`** — privée (revoke nominatif `anon`/`authenticated`/`public`, comme
   `roll_rare`) : sous `pg_advisory_xact_lock(hashtext(auth.uid()::text))`, tant que
   `solde_or() ≥ prix_booster` : une ligne `-prix` raison **`conversion_booster`** (existe déjà
   dans le check) + un `user_boosters` **origine `conversion`** (à ajouter au check — recopier la
   DERNIÈRE liste : seance, achat, cadeau, legendaire, chemin, + conversion), même transaction ;
   rend le nombre converti. Témoin d'idempotence = le solde lui-même : un rejeu ne crédite rien,
   donc ne convertit rien.
4. Appelée par un **déclencheur** sur tout crédit jaune du carnet (clôture, retour, chemin,
   cadeau — et les crédits de demain), sauf `annulation` ; les trois réponses gagnent
   `sachets_convertis` (porté par la transaction) et `solde` **après** conversion ;
   `tirer_noeud_chemin` devient `_brut` derrière une enveloppe du même nom. **Le stock d'avant
   est converti à la pose** (« les pièces retombent » vaut pour ce qui est en poche). *(Forme
   réelle, relue le 30-08 soir : plan §4 M1 disait trois appels explicites.)*
   Conséquence par construction : `reste = solde_or % prix` est enfin vrai (solde < 100),
   `boosters_or` compte les convertis — `etat_coffre` ne change pas de formule.
5. **`cloturer_seance` rejouée rend le STOCKÉ**, pas des zéros : sur `unique_violation`, relire la
   ligne `serie_faite` du workout (pieces), le sachet (`booster_id`), et rendre `rejeu: true` +
   `solde_argent` + **`argent_seance`** (la pièce est-elle tombée pour cette séance) — `argent`
   garde son sens « tombée à CET appel », parce que l'app l'incrémente (`EconomieWoop.swift:211`).
   C'est ce qui permet à la page noire de se relire après un kill.
6. **`flamme()`** → `{jours, aujourdhui_fait}` : dates distinctes de `workouts.ended_at` (dans
   `fuseau_jour`) pour `auth.uid()`, jours consécutifs en remontant depuis aujourd'hui (ou hier
   si aujourd'hui n'est pas fait). **Dérivée, jamais stockée, zéro écriture, zéro clé de bonus.**
7. **`etat_coffre()`** gagne quatre clés : `jour` (la date de la maison), `retour_disponible`
   (= pas de `retour_quotidien` à `jour_courant()`), `retour_prochain` (le prochain minuit dans le
   fuseau, timestamptz — l'horloge du +10), `flamme` = `{jours, aujourdhui_fait}` — un seul appel
   au retour au premier plan. *(Forme réelle de la migration, relue le 30-08 soir.)*
8. **`claim_booster()`** : `revoke execute from authenticated` (Q9, défaut) — la porte reste en
   base, fermée ; la fonction passe ⚪ « sans appelant, fermée » sur la carte.

### M2 — `2026083x_rangs_popups.sql` (les rangs vivent en base)
Clés, `do nothing` : `popup_rangs_fixes` `[3,5,10]` · `popup_rang_video` `10` ·
`popup_hasard_ecart_min` `5` · `popup_hasard_ecart_max` `8` · `popup_hasard_apres` `10`
(valeurs = Q2, à confirmer). `regles_annonces()` les rend déjà (elle agrège tout sauf `rare_*`).

### E1 — `supabase/functions/narrate-reward/index.ts` (l'IA écrit la PROCHAINE)
Sur le patron de `forge-card` (`admin.auth.getUser(jwt)` → 401, `OPENAI_API_KEY` en secret,
écritures en service_role) **plus ce que forge-card n'a pas** : un `AbortController` à **10 s**
et un `ms` mesuré dans la réponse. Entrée : les faits de la série N **dans le corps** (rang,
exo, reps, kg, total pièces, record éventuel) — le serveur n'a pas à connaître la séance en
cours (`moteur_faits.sql:20-26` : « l'app calcule, le serveur range »). Sortie **forcée par
schéma JSON** : `{fact_id, title ≤ 22, subtitle ≤ 64, big_lines[1-3] ≤ 8 signes, style ∈ enum,
video ∈ enum, headline:{value, unit}}` — `headline.value` **recopié** d'un fait d'entrée (rejet
serveur sinon → gabarit). Modèle : le même que forge-card (`gpt-5`, `reasoning_effort: low`),
le seul appel IA vérifié en prod. Log `{facts_in, json_out, model, ms}` (console de la
fonction ; une table `reward_narrations (user, workout, serie_index)` unique **seulement** si
le rejeu doit rendre le même texte — pas au J1).

### Ce qu'on ne fait PAS
- Pas de table `popup_servies` : le rang est tiré au client depuis les clés (il ne paie rien) ;
  le budget « 1 vidéo par séance » tient en mémoire de séance.
- Pas de réveil de `booster_progress` ; pas de compteur de flamme stocké ; pas de fuseau client.

---

## §5 — L'APP : ce qui change, par écran

### 5.1 La chaîne de fin de séance (le gros morceau)
1. **Une FILE d'annonces typée** `[Annonce]` (pièces · booster · argent · retour +10) remplace
   `notifPieces: Int?` (`DepartSeance.swift:43`) ; l'hôte de la racine (`WoopApp.swift:1237-1244`)
   les **empile** l'une sous l'autre ; `PiecesNotif` devient un cas de la file ; `PillGain`
   (en séance) garde son créneau mais son verre `.regular` est hors la loi (`SKILL woop-architecture:134`).
2. **Deux robes de plus** : booster (`booster-orange`, V9 §A) et **argent** ; la jauge lit
   `EconomieWoop.reste / prixBooster` (fin du `0,62` en dur) ; un gain qui n'est pas 20 (+176, +10)
   se dessine.
3. **La PAGE NOIRE** (`PileAnnonces.swift`, zIndex entre la story 15 et la poussière 20) montée à
   l'`onClose` de la story : fond noir, petit chargement, **attend la réponse de
   `cloturer_seance`** publiée par l'outbox (plus de `Task.detached` muet : `WoopApp.swift:510-513`,
   `OutboxGains.swift:191-205` publient `ClotureSeance`), **borne 4 s**, repli « local, dit comme
   tel » (pièces × taux, sachet forfaitaire, pas d'argent) sans compte ou hors ligne ; empile
   pièces → sachet(s) → argent ; puis rend la main.
4. **Atterrir sur le CHEMIN** : `selection = .home` (:489) et `celebrateFinishedWorkout()`
   (:1666-1673) → ouvrir le chemin depuis la racine (la lecture `cheminEtat` vit dans `HomeNuit`,
   à partager) ; `rafraichirReclamees()` **à la clôture**, pas seulement à l'`onAppear`.
5. **L'animation « séance terminée » sur la route** (`DuolinguoPage`, drapeau « arrivée
   post-séance ») : la pierre du jour s'estampille, la suivante prend le halo, la colonne avance
   — modèle : le pas de la card ROUTE (`HomeNuit.swift:2589-2606`).
6. **La pop-up « Ouvrir »** à la FIN de cette animation (signal « route posée »), plus à +3,4 s
   après la story (`WoopApp.swift:553-555`) ; `BoosterCardHote` (zIndex 6) est déjà au-dessus du
   chemin (4). Elle va droit au manège (Q6, défaut).

### 5.2 Les pop-ups en séance
7. **`DecideurSerie` → un décideur à budget** : lit `regles_annonces()` en début de séance
   (nouvelle lecture `SacreServeur.reglesAnnonces`), rangs fixes `[3,5,10]`, puis un rang tiré
   (hasard **déterministe par séance** : `hash(workout_id, rang)`) tous les 5-8 ; budget 4 / 1
   pièces / 1 vidéo ; écart 3 séries ET 6 min sur l'horloge de séance (pour les rangs tirés,
   Q1) ; dalles hors budget, plafond 6. Valeurs actuelles en repli hors ligne.
8. **L'IA pour la PROCHAINE** : à la fin de la série N (après `jouerIssue`,
   `ExerciseDetailView.swift:2234-2247`), la fiche envoie les faits à `narrate-reward` et range la
   réponse dans `prochaineAnnonce` ; à N+1 la pop-up lit ce qui est prêt, sinon le **gabarit**
   (le `.moment` actuel généralisé, un par sorte de fait). **Jamais d'attente, jamais de spinner.**
9. **`RewardPopup` apprend à recevoir** `bigLines`, `actionLabel` ; `lineLimit` + troncature sur
   titre / sous-titre, borne de signes dans `TexteGeant` (`RewardCard.swift:68-82, 760-778,
   1825-1843`) — préalable à tout texte IA.

### 5.3 Le Welcome Back
10. **Retirer** `reglerRetourQuotidien()` du `scenePhase` (`WoopApp.swift:83-92`) ; une **porte sur
    la home** : au premier plan, si `etat_coffre().retour_disponible` → la card `.welcome` ;
    **Claim** poste `.retourQuotidien` (outbox + index = idempotence) et pousse la dalle « +10 »
    dans la file au tap (Q8) ; « Later » ferme, la card revient au prochain premier plan du même
    jour. Retirer `piecesRetourQuotidien = 10` (`ExerciseDetailView.swift:2270`) au profit de la
    réponse. Le marqueur UTC local disparaît (le serveur sait).

### 5.4 Le coffre et le profil
11. **Le coffre montre la conversion** : `boosters` inclut les convertis, l'or **retombe** (le
    modèle `EconomieWoop` applique `solde` après conversion, `sachets_convertis` entre dans la
    pile) ; le pied du coffre n'a plus que « OUVRIR » (le « N COINS TO GO » devient la jauge) ;
    **retirer** `acheterBooster()` (`CoffreV2.swift:2542-2551`, `ProfilLune.swift:1255-1265`).
12. **Le profil** : les quatre objets (+ l'orange, Q10) visibles à 0 (`ProfilLune.swift:562-574`),
    une pill pièce d'argent, le géant dans l'inventaire (:272-277).
13. **Le chemin** : la dalle après la card aussi pour un tirage en sachets, robe booster
    (`RewardChemin.swift:286-294`).
14. **La flamme** : `EtatCoffre.flamme` → `EconomieWoop` → affichée (home et/ou route) ; **aucun
    effet sur l'argent** ; ne pas la confondre avec le glyphe « flame » des galets futurs.

---

## §6 — L'ORDRE, et la porte de sortie de chaque jalon

| jalon | livre | porte de sortie (MESURÉE, compte de test, rejeu compris) | temps |
|---|---|---|---|
| **J0** | ce plan · les fiches périmées réécrites (§2.7) · le site aligné (§7) | `npm run verif` vert ; son go | ½ j |
| **J1 — M1** ✔ **posée le 30-08 à 18:48, sonde TOUT EST VERT (47 preuves)** — 20260830210000 : conversion (stock d'avant converti à la pose : 1 536 → 15 sachets + 36) · jour Paris · `flamme()` · `etat_coffre` +4 clés · clôture rejouée rend le stocké (`argent_seance`) · `claim_booster` fermée (403) | `migration list` avant/après ; `cloturer_seance` ×2 : #1 `sachets_convertis` ≥ 0 et `solde` < 100, #2 `rejeu:true` + le MÊME `pieces/argent/booster_id` ; `claim_retour_quotidien` ×2 : `jour` = date Paris (lu dans le carnet), #2 `credite:false` ; `etat_coffre` : `retour_disponible` false après, `flamme` cohérent avec `workouts` ; `rpc/claim_booster` → 401/403 ; témoin `rpc/fonction_inventee` → 404 ; `-demoData` sans `-syncNow` n'écrit rien | 1 j |
| **J2 — app coffre + Welcome** | file d'annonces + robes booster/argent · conversion affichée · achat retiré · Welcome : porte + Claim → outbox → dalle · profil à 0 · dalle du chemin | sim : Claim → carnet +10 **au tap seulement** ; 100 pièces → « 1 » qui apparaît, or retombé ; profil à 0 ; capture avant/après | 1,5 j |
| **J3 — la fin de séance** | page noire (pile, borne 4 s, repli) · atterrir sur le chemin · animation route · « Ouvrir » après | sim : clôture → story → pile (pièces, sachet, argent forcé au banc) → chemin animé → « Ouvrir » ; kill entre clôture et pile → relance relit le stocké ; hors ligne → repli « local » dit tel quel ; cadence mesurée (`tools/charge.sh` avant) | 2 j |
| **J4 — M2 + décideur** | clés des rangs · `reglesAnnonces` · décideur à budget · gabarits par fait · `RewardPopup` borné | banc : 30 séries → pop-ups à 3, 5, 10 puis 15-18, 21-26… ; jamais 6/9/12 ; ≤ 4 ; une vidéo ; écart tenu | 1 j |
| **J5 — E1 narrate-reward** | l'edge function · l'appel N → N+1 · le repli | `functions list` ; sonde : JSON conforme, `headline.value` = un fait d'entrée, `ms` lu ; un chiffre inventé → rejet → gabarit ; timeout 10 s → gabarit ; au sim la série N+1 lit le texte préparé | 1,5 j |
| **J6 — verdicts** | ses verdicts téléphone ; les pastilles passent 🟢 **après** lecture | elle | — |

≈ **7,5 jours**. Un commit par jalon ; **le site dans chaque commit** ; jamais de trailer.

---

## §7 — LA DOC, dans le même commit que chaque jalon

- **Au J0** (ce commit) : `b-flow-deux-annonces` 🔴 → ⚪ « voulu : la pile n'existe pas » ;
  `b-rg-le-versement-lui-part-vraiment` 🟢 + litige « décision 30-08 : au tap » ;
  `b-rg-notif-budget` → tranché (`reference`) ; `b-edge-weekly` 🔵 → ⚪ (sondé : absente de
  `functions list`, 404) ; `m-trancher-la-conversion` et `m-trancher-le-fuseau` → tranchés.
- **J1** : `convertir_pieces`, `flamme`, `jour_courant`, clé `fuseau_jour` (nouveaux) ;
  `cloturer_seance` / `claim_retour_quotidien` / `tirer_noeud_chemin` / `etat_coffre` (preuve =
  la sonde du J1) ; `claim_booster` ⚪ fermée ; `b-fn-solde-noir` → droppée (`rpc/solde_noir` 404).
- **J2** : `b-wb-porte` ⚪ → 🟢 après la sonde du tap ; `b-fn-claim-retour-quotidien` (site d'appel
  déplacé) ; profil ⚪ → 🟢 ; `b-flow-coffre-parcours`, `b-flow-overlay` (les délais).
- **J3** : `b-flow-retour-chemin` ⚪ → 🟢 ; `b-flow-deux-annonces` ⚪ → 🟢 ; les fiches
  `notification.md` et `duolingo-chemin.md` (chaîne réelle, mesurée).
- **J4** : les 22 + 5 clés de rythme 🔵 → 🟢 (l'appel lu) ; `m-decideur-serie` → tranché.
- **J5** : `b-ed-narrate-reward` ⚪ → 🟢 ; `m-ecrire-narrate-reward` déplacée vers « Les annonces ».
- **Le site lui-même** : la page `regles` devient **deux pages** (« Le coffre », « Les annonces »),
  `eco` pointe sur le coffre ; le **vert** = tout 🟢 et 0 🔴 (déjà la règle des cards — rendu
  visible sur le hero de la page).
- **Les docs à réécrire** (§2.7) : doctrine §4 quaterdecies (une annonce par événement ; la pile ;
  « Ouvrir » = invitation) ; plan §2 (positions fixes voulues, puis hasard) ; `SKILL.md:37-39,
  118-120, 143-146` ; le commentaire de `SacreServeur.swift:293-299`.

---

## §8 — Les questions fermées par ce plan (pour mémoire)
Q5 du 30-08 (rythme) : oui · Q7 (les nombres) : inchangés · le tableau §3 : c'est le contrat.
