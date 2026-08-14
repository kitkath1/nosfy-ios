# Le pipeline des cartes récompense

**LE TEMPLATE DU SET.** Le moteur (shader `CarteLune.metal`, banc
`CarteLuneLab.swift`, sons/haptiques `LuneDust.swift`, forge
`LuneForge.swift`) est COMMUN à toutes les cartes et ne se duplique
jamais.

**LE COMPOSANT-RÉSULTAT S'APPELLE « CarteVivante »** (dans
CarteLuneLab.swift) : la carte avec tout dedans — tilt, foil, fumée du
tap, plongée, haptiques, sons. Contrat de rebranchement (booster,
collection, fin de séance…) : `CarteVivante(art: Image?, depth:
Image?)` et c'est tout — nil/nil affiche carte-lune-1. Le banc
`-luneLab` n'est que son écrin d'atelier. Chaque carte n'apporte que ses fichiers dans `Woop/Media/` :

    carte-<nom>.png            l'illustration (cadre compris)
    carte-<nom>-depth.png      sa profondeur (demi-résolution, gris)
    carte-<nom>-L0..L3.png     ses quatre plans inpaintés (réserve multiplane)

## LA FORGE (le schéma pour les bébés)

Le cadre et le médaillon sont un ASSET FIXE (`carte-cadre.png`,
extrait par `gen_cadre.py`) : l'IA ne peint QUE l'intérieur. C'est ça
qui fait que 50 cartes côte à côte = UNE collection.

    ┌─ tirage ──────────────────────────────────────────────┐
    │  une FAMILLE + son REGISTRE de rareté (au hasard)      │
    └──────────────┬────────────────────────────────────────┘
                   ▼
    ┌─ GPT-5, le directeur ─────────────────────────────────┐
    │  reçoit la CHARTE + la famille + le registre           │
    │  → invente UNE scène (la surprise, c'est lui)          │
    └──────────────┬────────────────────────────────────────┘
                   ▼
    ┌─ gpt-image-1, le peintre ─────────────────────────────┐
    │  peint l'illustration 1024×1536, qualité HIGH          │
    └──────────────┬────────────────────────────────────────┘
                   ▼
    ┌─ le compositing (dans l'app) ─────────────────────────┐
    │  illustration glissée dans la fenêtre 828×1170         │
    │  + carte-cadre.png POSÉ PAR-DESSUS (cadre identique)   │
    │  + depth v0 (rampe) → la carte VIT (tilt, foil,        │
    │    fumée, plongée) sans changer une ligne de shader    │
    └───────────────────────────────────────────────────────┘

Au banc : bouton « Forger une carte », ou `-luneForgeNow`.
`-luneForgeQualite low|medium` (essais pas chers), `-luneForgeFamille
<nom>` (forcer une famille). La clé OpenAI vit dans `.secrets/openai.key`
(JAMAIS dans le repo ni le binaire) ; le sandbox du simulateur ne lit pas
le disque du Mac, le lanceur la copie donc dans Documents/ du container :

    CONT=$(xcrun simctl get_app_container <sim> fr.kathryn.woop data)
    cp .secrets/openai.key "$CONT/Documents/openai.key"

Chaque carte forgée est archivée (art + depth + scène) dans
`~/Downloads/woop-carte-lune/forge/`.

## Les quatre raretés = quatre REGISTRES de mise en scène

La rareté n'est pas une étiquette : c'est une clause du directeur.
Le cadre et le médaillon, eux, restent STRICTEMENT identiques partout.

    common     la nuit ordinaire — compositions simples et calmes
               (pins, petite lune, vallée sobre)
    rare       la nuit + UNE présence remarquable — corbeaux,
               chauves-souris, reflet, les yeux du démon ; le
               minimalisme LUMINEUX vit ici, jamais le vide
    epic       le ciel entre en scène — lune de sang, ciel rouge,
               l'oiseau de braise ; le drame
    legendary  le FULL ART — composition débordante, profondeur
               étagée, nuages sculptés, lumière chorégraphiée :
               l'opéra du set (jamais minimal — payé au banc)

**Les lunes de rareté** : posées PAR LE CODE en bas à gauche, dans la
bande du cadre — 1 croissant (common) · 2 (rare) · 3 (epic) ·
4 (legendary). L'IA ne les peint jamais.

Leçons payées :
- les chauves-souris invisibles → le noir profond est l'ADN, mais chaque
  carte doit SE LIRE : sujet sculpté par une lumière visible, valeurs
  lisibles à taille de carte tenue en main ;
- « pas hyper légendaire » → les registres sont HARDCORE : ils changent
  ce qui est mis en scène, JAMAIS le niveau de peinture. **Carte-lune-1
  est le niveau d'une RARE** — c'est le plancher de finition du set ;
- LA LUNE DU LOGO TOUJOURS : chaque carte porte le croissant fin
  (minuscule, voilé ou en reflet), et l'orangé TRÈS DARK — l'univers de
  l'app — n'est jamais absent, jamais néon.
L'ancrage de style du set = carte-lune-1 (vallée étagée, nuages
sculptés, croissant fin, braise d'horizon UNIQUE, jamais de brume orange).

## Le pool partagé Supabase (le contrat de la gamification)

Une génération n'est PAS reproductible → une carte qui existe est une
image STOCKÉE, canonique. C'est ce qui permet que deux users RETROUVENT
LES MÊMES CARTES et comparent leurs collections.

    le user finit sa séance
          │
          ▼
    un petit BOOSTER apparaît sur la home
          │  « récupérer ma récompense »
          ▼
    ┌─ Edge Function forge-card (Supabase) ─────────────────┐
    │  la clé OpenAI vit ICI (jamais dans l'app)             │
    │  pile ou face pondéré :                                │
    │   ├─ carte EXISTANTE du pool (pondérée par rareté)     │
    │   └─ carte NEUVE (GPT) → elle ENTRE au pool            │
    │  le ratio neuf/pool règle le coût ET le « on a la      │
    │  même ! »                                              │
    └──────────────┬────────────────────────────────────────┘
                   ▼  (pendant ce temps : l'animation booster)
    le user choisit un booster, l'ouvre → LA CARTE SORT
          │
          ▼
    elle est à lui pour toujours (user_cards) ;
    plus tard : sa collection dans son profil

Les tables (projet `ytnnyjkramgiqyxdrkcu`, lié au CLI, token dans
`.secrets/supabase-access-token`) :

    cards        le pool canonique : famille, rareté, prompt/scène,
                 image, depth — lisible par tous (le set partagé)
    user_cards   la collection : user_id, card_id, date, séance
                 d'origine — RLS par user
    storage      bucket `cards` : les PNG (art + depth)

Piège CLI : les migrations de juillet ont été appliquées au dashboard →
`supabase migration repair --status applied` AVANT le premier `db push`.

**L'architecture Supabase complète (comptes, CLI, pièges, déploiement) :
voir `supabase/README.md`.**

## Les scripts (dans l'ordre)

- `mesure.py` — mesure le cadre et les bandes du paysage au pixel.
- `gen_depth.py` — la depth map : PUR PAYSAGE étagé autour du pivot 0,45
  (ciel 1,0 · nuages ~0,72 · montagnes ~0,45 · forêt ~0,16). Les masques de
  vitre (cadre, médaillon) sont ANALYTIQUES dans le shader, jamais ici —
  une rampe de profondeur qui plonge vers 0 traverse le pivot et cisaille.
- `gen_layers.py` — les quatre plans RGBA inpaintés (Telea + flou
  atmosphérique sur le ciel), médaillon effacé du monde, bords fondus.
- `gen_shimmer.py` — le son de poussière (une fois pour tout le set).

Usage : copier la carte dans ce dossier sous le nom `carte-lune-1.png`,
lancer les scripts, copier les sorties dans `Woop/Media/`. Banc : `-luneLab`.

## Demain : FULL IA (le chantier promis)

Aujourd'hui `gen_depth.py`/`gen_layers.py` sont calés sur carte-lune-1
(bandes du paysage, position de la lune, seuils). Pour le set complet :

1. **depth automatique** — Depth Anything V2 en local remplace les bandes
   à la main ;
2. **plans par quantiles** de profondeur au lieu de cotes fixes ;
3. **inpainting IA** derrière chaque plan ;
4. **template de cadre commun au set** (liseré, médaillon, zone morte) —
   écrit une fois, valable pour les 30.

La préparation d'une carte devient alors une ligne de commande, et le
runtime n'a pas à changer d'un caractère : il est déjà générique.

## Le multiplane (palier 2), gardé débranché

`CarteLuneWorld` + `carteLuneAir` + les plans L0..L3 restent dans le code :
la plongée en jeu est le PALIER 1 (une image + dolly interne — verdict :
plus naturel), mais la caméra multiplane est la matière du chantier full-IA
(grands formats, autres usages).
