## Actualisation du18-09 : reconnexion dans le même processus

La relecture tourne aussi quand la porte disparaît après Apple, suivie des
claims Route. L’ancien branchement au seul lancement ne restaurait pas les
séances après une déconnexion/reconnexion sans quitter l’app. Une génération
Compte empêche une réponse antérieure d’insérer des séances ou un curseur dans
le compte suivant. `tools/serveur/verif_pull.py` :9PASS ; preuve dans
`tools/production/compte-iphone-2026-09-18/pull.log`. Les mesures historiques
ci-dessous restent limitées au banc du14-09.

# LE PULL DES SÉANCES — la lecture qui manquait depuis le 29-08

*14-09-2026, 00:10. Sur son mot « continue le backend qui manque ». Court, parce que la
moitié serveur est faite et mesurée (`seances_depuis`, 13-09 soir) : il reste la moitié
app, dans la couche de synchro — pas un écran.*

## 1. Le problème

`SupabaseSync` n'a qu'un `push` (site : b-backend-lecture-manquante, 29-08). Un téléphone
neuf ou réinstallé ne retrouve **rien** : la home et les cards restent vides alors que les
chambres, elles, lisent le serveur (règle « téléphone d'abord, serveur s'il n'a rien »).
Le site dit la conséquence depuis ce soir : « la phrase de la home dit 0 comme les cards »
tant que le pull n'existe pas.

## 2. Le contrat (rien à inventer, tout est mesuré)

`POST /rest/v1/rpc/seances_depuis {p_depuis, p_limite}` rend l'arbre complet
(workouts → exercices → séries / phases, + faits) avec **les uuid que le téléphone a
poussés** : 23 / 43 / 88 / 70 sur le compte de test, exactement la poussée.

## 3. Les règles du pull — cinq, pas plus

1. **Il n'insère que ce qui manque.** Un `Workout` dont le `remoteID` existe déjà
   localement n'est jamais touché ni écrasé — le téléphone reste la source de ce qu'il a
   (une séance poussée puis retouchée localement garde sa version).
2. **Séances finies seulement** (`ended_at` non nul). Une séance ouverte ailleurs ne
   s'importe pas : ce téléphone ne peut pas la continuer.
3. **Incrémental** : `woop.pull.depuis` garde le `serveur_at` du dernier appel ; l'appel
   suivant ne demande que ce qui a fini après. `-pullTout` relit tout.
4. **Ce que le serveur ne porte pas** prend la valeur honnête : les séries d'une séance
   finie arrivent `isDone = true` (elles ont été faites), `durationSeconds = 0`,
   `restSeconds = 0`. Les `faits` ne s'importent pas (l'app les recalcule).
5. **Silencieux** : sans session, sans réseau, en panne → rien ne bouge, une ligne de
   journal `[pull]`. Comme `push`, la démo (`-demoData`) ne pull pas sans `-pullNow` ;
   `-sansPull` coupe tout.

## 4. Où ça tourne

Au même endroit que la poussée de toutes les séances finies (RootView, la tâche de
lancement, WoopApp ~2268) : juste après `push`, `await SupabaseSync.relire(dans: modelContext)`
— sur le MainActor, dans le contexte principal, donc les `@Query` de la home se
rafraîchissent d'elles-mêmes. Une fois par lancement, ~0,2 s réseau + l'insertion.

## 5. La mesure

Simulateur, app désinstallée (base vide), `-skipAuth -sessionBanc -pullNow` :
journal `[pull] seances_depuis(…) → total 23, rendues 23 · insérées 23, ignorées 0 ·
local 23` ; relancer : `insérées 0, ignorées 23` (idempotent) ; `-pullTout` : idem.
La home reste vide sur la semaine courante (la démo s'arrête au 06-09) — la chambre en
fenêtre Mois, elle, a tout. Compte de test nettoyé après (rien n'est écrit au serveur).

## 6. Le site

b-fn-seances-depuis 🔵 → 🟢 · b-sy-jamais-ecrit → « les tables se relisent » 🟢 ·
b-backend-lecture-manquante (histoire) 🟡 → 🟢 · b-ux-home-phrase 🟡 → 🟢 (la phrase
compte les séances du téléphone, qui sont désormais aussi celles du serveur).
