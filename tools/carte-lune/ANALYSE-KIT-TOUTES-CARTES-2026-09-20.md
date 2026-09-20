# Le même effet pour toutes les cartes — et pourquoi elle retombe sur des chauves-souris

Analyse courte du 20 septembre 2026, soir, avant de coder (sa demande :
« fais une petite analyse avant de coder, pas perdre de temps »). Deux
constats à elle : « pour les autres cartes, fais le même effet — trop beau
pour avoir l'effet cheap » ; « au téléphone, j'ai eu plusieurs fois la même
carte avec des chauves-souris ; il faut générer de nouvelles cartes comme
dit ce matin, communes aux testeurs, avec ces beaux effets, variés selon
légendaire ou pas ».

## 1. Les chauves-souris : ce n'est pas le tirage, c'est le catalogue

Les 14 références publiées (relues par sha256 dans
`integration-2026-09-18/catalogue-publication.json`, fichiers locaux
retrouvés un à un — `profondeur/publiees.json`) :

| rareté | Forêt des Veilles | Cimes Éteintes | Bois Sans Lune |
|---|---|---|---|
| commune (5) | La Veille | Corbeau de suie · La Faille ardente · Le Col des cendres | La Clairière muette |
| **rare (3)** | **Les Veilleuses — chauves-souris** | **Aile d'ambre — chauve-souris** | **Aile de brume — chauve-souris** |
| épique (3) | Le Passage (oiseau) | Loup de cendre | Loup des racines |
| légendaire (3) | Le Souverain (cerf) | Dragon d'obsidienne | Le Grand Silence (corbeau) |

**Les trois rares sont des chauves-souris.** Une ouverture qui tire « rare »
ne peut donner qu'une chauve-souris ; avec trois références, la deuxième
rare est un doublon deux fois sur trois. Ce qu'elle a vu est exactement ce
que le catalogue permet — le serveur fait ce qu'on lui a dit (« anciennes et
nouvelles dans le même tirage », relu le 19-09).

Ce qui le corrige, dans l'ordre :

1. **Les 36 scènes** (session Cartes production, prérequis du lancement) :
   elles ajoutent 12 rares, dont 8 ne sont pas des chauves-souris (le plan
   des 50 : Ronde des Veilleuses, Percée… restent des veilleuses, mais Virage
   d'ambre, Veille d'ambre, Descente de brume… aussi — à vérifier : le plan
   des 50 garde beaucoup de chauves-souris en rare. **À signaler à la
   production : varier les rares**, c'est la rareté la plus tirée après la
   commune).
2. **Une règle serveur « les inconnues d'abord »** : aujourd'hui seules les
   légendaires inconnues sont prioritaires (`tirer_noeud_chemin`). L'étendre
   à toutes les raretés (une référence jamais possédée avant un doublon,
   tant qu'il en reste) supprime les doublons précoces sans toucher aux
   garanties. C'est une ligne de SQL — **domaine de la session back-end**,
   à lui poser ; je ne touche pas au tirage.
3. Rien à faire côté effets : le kit ne change pas le tirage.

« Commun aux testeurs » : déjà vrai par construction (même référence = mêmes
pixels, 28 API PASS le 19-09) ; le kit est cuit **par référence**, donc le
même effet pour tous.

## 2. Le kit pour les 14 (puis les 50) : tout par script

`cuire_kits.sh` enchaîne `cuire_profondeur.py` (Depth Anything v2 + rembg)
et `cuire_plans.py` (six plans + fond/relief, reconstitution LaMa par tuiles)
sur `publiees.json`. Coût mesuré sur le cerf : ~25 s de profondeur, ~2-3 min
de LaMa ; les 14 en ~30-40 min, sans main. Sorties par référence dans
`profondeur/<nom>/plans/` (~12 Mo). Pour les 36 à venir : la même commande à
la publication (`publier_catalogue.py`), c'est le § 4 du plan du Passage.

Ce qui se vérifie à l'œil, carte par carte, sur la planche `planche-plans.png`
(chaque plan sur magenta + recomposition + test de parallaxe) :
- **le détourage** : une créature bien coupée (les paysages purs — Faille,
  Col, Clairière — n'ont pas de créature : rembg rend alors un masque vide ou
  faux ; le script doit **ignorer un sujet < 3 % ou > 60 % de l'image**) ;
- **la reconstitution** derrière la créature (LaMa) et derrière chaque plan ;
- **les bandes** : cinq quantiles conviennent au cerf ; sur un ciel plein
  (le Passage, l'oiseau) ou un sous-bois fermé (les Bois), les bandes se
  répartissent autrement — c'est le test de parallaxe qui dit s'il y a des
  trous.

## 3. Le même effet, varié par rareté

| rareté | à l'ouverture (le tap) | dedans |
|---|---|---|
| commune | le verre s'ouvre, relief + plans, le doigt conduit | la parallaxe vraie, l'approche ×2 |
| rare | idem | + l'air du monde (brume qui dérive) |
| épique | idem | + la météo du monde (neige / cendres / nacre) |
| légendaire | idem + la cérémonie « sort de la lumière » | + la créature qui vit (respiration, regard, feu), le monde plus large, le piano, le dos gravé |

La différence de rareté vit dans **ce qui est ajouté**, jamais dans une
qualité moindre du geste : une commune n'est plus jamais cheap. Le foil-bande
de la Trois Lunes reste tel quel dans la carte en main.

## 3bis. Son corbeau « moche, l'ancienne DA » — lu au serveur (lecture seule, 20-09 soir)

Requêtes GET avec la clé de service, rien d'écrit :

- `cards` : **23 lignes**. Les **9 anciennes** (Petite lune perdue, Dragon
  des ténèbres, Montagnes invisibles, **L'oiseau souverain — légendaire**,
  Lune néon sur ciel noir, Vallée noire, Forêt de pins ; 14-08 → 31-08, sans
  référence) sont toutes en `publication = 'retiree'`. Les **14 nouvelles**
  (18-09, avec référence et sha256) sont `publiee`. **La prod ne tire que les
  14 de la nouvelle DA** ; la fonction déployée n'appelle pas l'IA à
  l'ouverture (relue le 19-09). La forge locale (`-luneForgeNow`, clé OpenAI
  hors app) est un outil d'atelier, pas un chemin de prod.
- `user_cards` : **28 lignes, un seul compte (be69f505…)**, toutes des
  **anciennes cartes retirées** — dont **« L'oiseau souverain », légendaire,
  deux fois** (20-08 et 30-08). Les comptes Apple (9f5b775d…, 6692fe98…,
  d6228318…) n'ont **aucune** acquisition au serveur (remis à zéro à 11:53
  par la session Compte, sur son ordre).

Donc : si son téléphone est sur le compte be69f505… (l'ancien compte de
développement), **le corbeau moche du profil est « L'oiseau souverain », une
acquisition d'août conservée par la règle « anciennes acquisitions
conservées »** — ce n'est ni une carte de la prod ni un appel IA. Deux
décisions à elle :

1. **Le profil n'affiche plus les cartes retirées** (une ligne dans
   `ma_collection` ou un filtre dans l'app sur `publication = 'publiee'`) —
   domaine des sessions Compte/Profil, à trancher avec elles ; ou
2. remettre ce compte à zéro — **jamais sans son accord explicite** (règle du
   `CLAUDE.md`).

Les chauves-souris répétées viennent, elles, du catalogue (§ 1) : trois rares,
trois chauves-souris.

## 4. Ce que je code ensuite, dans l'ordre

1. `cuire_plans.py` : la garde du sujet vide/faux (§ 2), puis relecture des
   14 planches à l'œil (moi), corrections des cas qui cassent.
2. Le banc : `-mondeCarte <nom>` lit `Documents/monde/<nom>/` (un kit par
   carte) ; planche sim de quatre cartes de raretés et mondes différents,
   relief + plans.
3. Dans l'app (hors banc, sur son go) : le kit voyage avec l'art (cache
   `cartes-lune/<cardId>/`), `CarteVivante` ouvre le monde au tap pour
   toutes les raretés, la plongée-film meurt, la sonde sur iPhone avant
   toute installation chez elle.
4. Les extras par rareté (§ 3) : les étapes 2 à 7 du plan du Passage.

Rien n'est installé sur son iPhone tant qu'elle ne dit pas « installe ».
