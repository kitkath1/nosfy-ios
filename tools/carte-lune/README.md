# Le pipeline des cartes récompense

**LE TEMPLATE DU SET.** Le moteur (shader `CarteLune.metal`, banc
`CarteLuneLab.swift`, sons/haptiques `LuneDust.swift`) est COMMUN à toutes
les cartes et ne se duplique jamais. Chaque carte n'apporte que ses
fichiers dans `Woop/Media/` :

    carte-<nom>.png            l'illustration (cadre compris)
    carte-<nom>-depth.png      sa profondeur (demi-résolution, gris)
    carte-<nom>-L0..L3.png     ses quatre plans inpaintés (réserve multiplane)

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
