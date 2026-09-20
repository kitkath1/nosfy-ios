# La musique des légendaires — majestueuse, au piano, très belle

Plan du 20 septembre 2026, sur ses mots : « il faut une musique différente et
très majestueuse, piano, très belle, pour les cartes légendaires » — après
« j'aime pas l'effet carillon, je préfère le piano dramatique » (matin) et
« en vidéo ce n'est pas possible, c'est cheap » (la créature ne vivra jamais par
une boucle vidéo : shader et masques seulement — règle ajoutée dans CLAUDE.md).
**Rien n'est composé, rien n'est branché** : c'est le plan.

---

## 1. Où elle joue — les moments d'une légendaire, et ce qui sonne aujourd'hui

| moment | ce qu'on entend aujourd'hui | fichier · site d'appel | demain |
|---|---|---|---|
| le manège noir (on choisit le sachet) | la veillée : bourdon, cordes, cœur, chœur, piano dramatique (20-09, commit 917d5e51) | `manege-noir-drame.caf` · `BoosterAmbience.manegeNoir` | **inchangé** — c'est l'attente, la tension |
| la carte se présente (sortie du sachet noir) | le sacre noir : chœur qui s'élève + **pluie de cloches** (18-09) | `sacre-noir.caf` · `BoosterAmbience.sacreNoir` | **LA PIÈCE AU PIANO** — c'est ici que la légendaire est belle |
| on entre dans la carte (le verre s'ouvre) | rien de branché pour la légendaire (`sacre-legendaire.caf` du 15-08 existe dans le bundle, jamais joué ; la plongée-film jouait la piste de la rareté) | `LuneSacre.dive(rarete:)` · `LuneDust.swift:187` | **la même pièce**, reprise depuis son thème (pas depuis le début) |
| la carte ouverte depuis le profil (« rejouer ») | idem plongée | `ProfilLune.resultatCouche` | la même pièce |
| la collection (la grille) | silence | — | silence — la règle de la grille |
| la cérémonie « elle sort de la lumière » (plan légendaire § 3) | n'existe pas | — | la pièce commence **sur le point de lumière**, le premier accord tombe quand la carte tourne vers elle |

Une seule pièce, donc, pour tout ce qui est *la carte elle-même* ; la veillée
reste au manège. Jamais deux musiques en même temps (`BoosterAmbience.sounding`
tient déjà cette règle : la plongée s'efface devant le manège).

## 2. La pièce — caractère

**Majestueuse, pas dramatique.** La veillée du manège est sombre et tendue
(mineur, tambour, montée). La pièce de la légendaire est l'inverse : elle
**s'ouvre**. Le vocabulaire : un piano seul d'abord, ample, dans le grave,
puis le thème en octaves, et sous lui des cordes qui n'apparaissent qu'au
sommet — jamais de percussion, jamais de cloche, jamais de chœur (il reste au
sacre orange si on veut). L'image musicale de « elle sort de la lumière ».

- **Tonalité** : ré mineur qui **s'élève** vers fa majeur (le relatif) au
  sommet, puis redescend — la nuit de Nosfy, avec une trouée de lune. Tout
  le set est en ré (la veillée aussi) : les deux musiques peuvent se fondre.
- **Tempo** : 66 à la noire, 4/4, rubato écrit (les temps forts légèrement
  retenus, les arpèges qui accélèrent vers le sommet de la phrase).
- **Durée** : 32 s pour la version « sacre » (une seule écoute, la carte se
  présente en ~12 s puis reste), bouclable proprement (dernier accord tenu qui
  meurt dans le premier arpège) parce que `BoosterAmbience` joue en boucle.
- **Structure** (8 mesures, 4 phrases) :
  1. *l'arpège seul* — main gauche, ré mineur brisé en croches (D2 A2 D3 F3
     A3 F3 D3 A2), pianissimo, pédale ; le thème entre à la 2e mesure : la
     quinte puis l'octave (A4 → D5), tenues ;
  2. *la question* — si bémol majeur (Bb2 F3 Bb3 D4 F4), le thème monte
     (F5 E5 D5), un peu plus fort ;
  3. **le sommet** — fa majeur puis do majeur (la trouée) : le thème en
     **octaves** à la main droite (A5/A4 → G5 → F5 → E5), la main gauche en
     accords pleins, forte, pédale longue — c'est là que les cordes entrent
     (un pad doux, deux voix, pas plus) et que la carte tourne vers elle ;
  4. *la retombée* — sol mineur puis la (dominante) qui **ne résout pas
     tout de suite** : le dernier accord (A3 C#4 E4 G4) meurt sur trois
     secondes… et le premier arpège de ré mineur reprend : la boucle est la
     résolution.
- **Dynamique** : pp → mp → **f** → p. La majesté vient du **contraste**, pas
  du volume : la pièce respire.
- **L'espace** : une salle, pas une église — réverbération 1,8 s, pré-délai
  20 ms, le piano un peu à gauche, les cordes larges.

## 3. Un vrai piano — les quatre voies, du moins cher au plus beau

Le piano de la veillée est **synthétisé** (partiels inharmoniques en numpy) :
correct sous un bourdon et un tambour, **pas assez beau seul**. Pour une pièce
de piano nu, il faut un piano **échantillonné** (des enregistrements de vraies
cordes frappées, une par note et par nuance).

| voie | ce que c'est | qualité | coût | ce qu'il faut |
|---|---|---|---|---|
| A · la banque d'Apple | `gs_instruments.dls` (2 Mo, dans macOS) rendue hors ligne par `fluidsynth` | un piano General MIDI : propre, un peu plat | 10 min | `brew install fluid-synth` + une partition MIDI (écrite par script) |
| B · un piano échantillonné libre | Salamander Grand (Yamaha C5, 16 nuances, CC0) en SF2 (~1 Go) ou une réduction 4 nuances (~200 Mo), rendu par `fluidsynth` | **très beau**, crédible seul | 30 min + téléchargement | même chaîne que A, la banque en plus |
| C · le sampler d'iOS dans un script Swift | `AVAudioUnitSampler` + la banque d'Apple, rendu hors ligne (`enableManualRenderingMode`) | = A, sans brew | 1 h | rien à installer, plus de code |
| D · une pianiste | une vraie interprétation enregistrée | la plus belle, et la seule qui ait du rubato vrai | un cachet, un délai | un studio, ou un piano et un bon micro |

**Recommandation : B**, avec A comme filet (la même partition rendue par les
deux ; elle écoute et tranche). La partition est **écrite une fois** (un
fichier MIDI produit par script : notes, vélocités, pédale) : elle sert aux
quatre voies, et se corrige en éditant des chiffres, pas en réenregistrant.
Le rendu passe ensuite dans le pipeline maison (numpy : cordes, réverbération,
crête −9 dBFS, boucle) et sort en `.caf` 48 kHz comme les autres pistes.

## 4. Le branchement — trois constantes, un banc

1. `BoosterAmbience.sacreNoir` → la nouvelle piste (la présentation dans le
   manège noir) ; `sacre-noir.caf` (chœur + cloches) reste dans le bundle,
   débranché — comme `manege-nappe.caf`.
2. `LuneSacre.piste("legendary")` (`LuneDust.swift:187`) → la même piste,
   avec un **point d'entrée** au thème (`AVAudioPlayerNode.scheduleSegment`
   à partir de la mesure 3) : quand on entre dans la carte, on n'attend pas
   l'intro.
3. Le banc `-mondeLab` appelle `LuneSacre.shared.dive(rarete: "legendary")`
   à l'ouverture du verre : elle l'entend sur son iPhone avec le geste.
4. Niveaux : 0,30 comme les sacres ; fondu d'entrée 0,6 s, de sortie 1,2 s ;
   jamais par-dessus la playlist de séance (`isOtherAudioPlaying`, déjà là).
5. Le site : la brique « Sachet noir : laque, néon, musiques » dit encore
   « pluie de cloches » — elle passe à « piano », avec la preuve d'écoute.

## 5. Ce qui se juge, et comment

- **Son oreille d'abord** : la preview `.wav` ouverte sur le Mac, puis la
  pièce **dans l'app**, au moment où la carte sort du sachet noir (le banc
  `-boosterLab -boosterNoir`), et à l'ouverture du verre (`-mondeLab`).
- Les mesures du pipeline : crête −9 dBFS, boucle sans saut (< le 99,9e
  centile des voisins), aucun clic aux changements d'accord — comme pour la
  veillée.
- Deux versions à écouter côte à côte si le temps le permet : piano seul, et
  piano + cordes au sommet. Elle choisit.

## 6. Ordre, si elle dit oui

1. La partition (MIDI par script, 8 mesures, vélocités, pédale). 30 min.
2. Le rendu A (banque d'Apple) → preview. 20 min, `brew install fluid-synth`.
3. Le rendu B (Salamander) → preview. 30 min + le téléchargement.
4. Cordes, réverbération, boucle, `.caf`. 30 min.
5. Les trois constantes + le banc. 20 min. Compilation : 5 à 30 min selon la
   charge du Mac.
6. Son verdict sur iPhone ; puis commit sur son ordre, site mis à jour.

Rien de tout cela ne touche le tirage, le serveur, ni les cartes publiées.
