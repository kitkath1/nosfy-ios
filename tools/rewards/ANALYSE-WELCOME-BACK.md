# ANALYSE — LE WELCOME BACK PASSE À « CHAQUE CONNEXION, UNE FOIS PAR JOUR »

**30-08.** Son verdict : « le welcome back, modifie dans le backend : c'est à
**chaque connexion**, pas tous les 4 jours, et **une fois par jour** ! Et il y a
**deux variants de cards** + **notification avec pièce**. »

> Ce qui porte `fichier:ligne` est vérifié dans le code ; ce qui porte une
> valeur de `reward_rules` est lu en base.

---

## 1 · L'état exact avant le changement

Il faut séparer deux choses que le mot « welcome back » désigne en même temps :
**l'argent** et **la card**. Elles n'ont pas du tout le même état.

### L'argent — il fait DÉJÀ ce qu'elle demande

`claim_retour_quotidien()` (migration `20260828190000`, lignes 135-158) verse
`pieces_retour_quotidien` = **10 pièces**, et sa garde est un
`unique_violation` attrapé sur l'index partiel
`coin_ledger_retour_jour_unique (user_id, jour) where raison = 'retour_quotidien'`.

Donc **une fois par jour calendaire, quoi qu'il arrive** — et un second appel
n'est pas une erreur, il rend `credite: false`. Côté app,
`SacreServeur.reglerRetourQuotidien()` le poste **à chaque retour au premier
plan**, avec un marqueur local qui n'est là que par politesse (l'idempotence est
l'index, pas le marqueur).

⚠️ **Il n'y a donc rien à changer sur l'argent** : « à chaque connexion, une
fois par jour » est déjà exactement ce qui tourne, et c'est déployé.

### La card — c'est ELLE qui était bridée à 4 jours

Trois règles, posées le 29-08 dans `20260829120000_annonces.sql` (134-136) :

| clé | valeur | ce qu'elle bride |
|---|---|---|
| `welcome_absence_jours` | **4** | il fallait 4 jours d'absence pour que la card se montre |
| `welcome_cooldown_jours` | **14** | deux semaines de pause entre deux cards |
| `welcome_max_mois` | **2** | deux cards par mois au maximum |

⚠️ **ET PERSONNE NE LES LIT.** Grep sur tout le Swift : aucune de ces trois clés
n'est consommée par l'app. Elles sont 🔵 « serveur seul » dans le site, et c'est
exact — ce sont des règles écrites d'avance pour une porte qui n'existe pas
encore. **Changer leurs valeurs ne casse donc rien** : ça change la règle du jeu
avant que la porte ne l'applique, ce qui est le bon ordre.

### Les deux variants de card — ils existent

`RewardLab.swift:83-84` : la robe `.welcome` a **deux** variantes montées au
banc — `welcome` (fond **vidéo**) et `welcomeTexte` (robe **texte**). Ateliers :
`-welcomeLab` et `-welcomeTexte` (`ExerciseDetailView.swift:835-843`).

### La notification à la pièce — elle existe aussi

`PiecesNotif` est la capsule qui descend avec le compte des pièces (elle sert
déjà la fin de séance). Rien à créer : il faudra la **brancher** sur le
versement du retour quotidien le jour où la porte s'ouvrira.

---

## 2 · Ce que je change, et pourquoi si peu

**Uniquement les trois valeurs**, dans `reward_rules` — pas une ligne de Swift,
pas une fonction, pas un index :

| clé | avant | après | lecture |
|---|---|---|---|
| `welcome_absence_jours` | 4 | **0** | aucune absence requise : **à chaque connexion** |
| `welcome_cooldown_jours` | 14 | **0** | aucune pause entre deux |
| `welcome_max_mois` | 2 | **31** | au plus un par jour, donc plus de plafond mensuel réel |

⚠️ **Pourquoi 31 et pas « illimité »** : la clé est un nombre, et la porte qui la
lira un jour doit pouvoir écrire `count < welcome_max_mois` sans cas
particulier. 31 est le plus grand nombre de jours d'un mois : c'est « un par
jour » exprimé dans l'unité de la clé, pas une désactivation déguisée.

⚠️ **Ce qui GARANTIT le « une fois par jour » n'est pas ces clés — c'est
l'index.** Les trois valeurs disent quand la CARD a le droit de se montrer ;
l'argent, lui, est tenu par `coin_ledger_retour_jour_unique`. Même si la porte
se trompait et proposait la card trois fois, le versement ne partirait qu'une
fois. C'est la loi de la maison : l'idempotence est un index, jamais un
compteur.

---

## 3 · Ce que ça n'ouvre PAS, et il faut le dire

La card **n'a toujours aucune porte de production** — elle ne vit qu'au banc.
Ce changement rend la règle conforme à ce qu'elle veut ; il ne fabrique pas
l'écran qui la respecte. Restent donc, dans l'ordre :

1. la porte : qui décide de montrer la card, et où (au retour au premier plan,
   après la splash ?) ;
2. **? lequel des deux variants** — vidéo ou texte — et à quel moment l'un
   plutôt que l'autre ;
3. brancher `PiecesNotif` sur le `credite: true` du versement, pour que la pièce
   se voie tomber.

---

## 4 · La documentation part avec le changement

C'est la loi du dépôt (« une modification backend qui ne touche pas le site est
une modification inachevée ») : la table des règles du site et sa section
« Le Welcome Back » sont mises à jour **dans le même mouvement**, avec les
nouvelles valeurs et la phrase qui dit ce qui reste absent.
