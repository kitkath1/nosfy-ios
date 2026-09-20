# La sortie de Nosfy refaite — 20-09-2026 (simulateur seul)

Sa demande, sur son ancienne capture « Let's go, Kathryn » : garder le spotlight
qui vient du haut de la page, **enlever la pop-up**, « Let's go, [prénom] » en
dégradé de blanc, le nombre de séances entre les deux traits Apple-like, un
bouton primaire en bas, la pilule de verre qui bouge **en grand sur le côté, en
continu**, et le petit sticker flamme qu'on a déjà — « quand on appuie les
flammes sortent ». Plus minimal, Apple style. Puis : tout en anglais **sauf le
bouton primaire** ; et la flamme qui **s'anime** quand elle crache.

Code : `Nosfy/Views/NosfyOnboarding.swift` — `SortieProjecteur` (refaite),
`FlammeVive`, `GerbeFlammes`, `Naissance` (nouvelles).

## Ce qui est à l'écran

| couche | quoi | coût |
|---|---|---|
| le projecteur | `HaloIle` penché depuis l'île — inchangé (13-09) | inchangé |
| le galet | `duo-galet-noir.mp4` (le fichier de l'écran 1 de la route, déjà sur cet écran en petit), 1,42 × la largeur, centre à 0,37 l à droite du milieu, pied au-dessus du bouton, `blendMode(.screen)`, **plus de `.mask`** (la tête s'éteint dans le fichier) | une `AVPlayerLayer` + un blend ; le masque d'avant (rendu hors écran par image) est parti |
| les mots | « YOU'RE READY » 12,5 espacé · « Let's go, » en `MotsFlou` 54 · le prénom seul, `minimumScaleFactor(0.5)` (un prénom long rétrécit, il n'est jamais coupé) · `blancDegrade` | naissances à valeur animée, une fois |
| le nombre | ses jours par semaine entre deux traits de 1 pt, « sessions a week » (5 si elle a passé : le défaut du serveur, que Nosfy a dit) | statique |
| la flamme | `sticker-flamme-noir` 62 pt + braise statique ; repos = 2 `repeatForever` (±3°, 1,5 % d'échelle) ; **saut** à images-clés à chaque jet ; gerbe = 40 `sticker-flamme` dans un `Canvas` qui n'existe que 2,5 s | zéro horloge au repos ; canvas 440 × 460 pendant la gerbe seulement |
| le bouton | `BoutonPrimaire` — « Start my first session » / « Commencer ma première séance » — le seul texte traduit | inchangé |

L'apparition (mon choix) : 0,25 s l'île s'allume (cône, haptique fort) et le
galet **glisse** depuis le bord droit (offset + opacité, 1,6 s) · 1,10 s les mots
se posent un à un, le nombre, la flamme naît (ressort) et crache **toute seule**
une première fois (on découvre le geste) · 2,40 s le bouton monte. Un tap avant la
pose saute tout ; une fois posée, seul le bouton fait entrer — la flamme crache.
La sortie (zoom 1,38 + coupe sur blanc) est celle du 13-09.

Ce qui est parti : la robe « You Made It » (`RewardPopup`), le chiffre de verre,
la pluie de diamant, le petit galet au ras du bas.

## Le prénom et la langue — la chaîne, lue

**Le prénom n'est jamais en dur.** L'écran affiche `reponses.prenom` — ce que
la personne a tapé à la question 1 (`prenomSaisi` rogné, posé dans `avancer`) ;
« Kathryn » sur les captures est ce que le banc a reçu par `-nosfyPrenom`, et le
défaut du banc est « Margaux » (la persona de `-nosfyAuto`), pas un vrai
prénom. L'écran parle la langue de `reponses.langue` (le seuil). Le bouton
appelle `finir()` → `onFini(reponses)` → `NosfyApp.ecrireProfil` →
`ProfilServeur.definirProfil(langue:prenom:…)` → RPC `definir_profil`
(`p_prenom`, `p_langue` tels quels) → `Langue.poser(p.langue)` avec la langue
**confirmée par le serveur** ; la home relit le prénom par `home()`. Rien de ce
chemin n'a bougé ici ; il est 🟢 au site (verif_compte.py, 32 PASS le 17-09, 50
avec `--flow` le 18-09). Sans profil au serveur : le banc `-nosfySortie` pose le
prénom de `-nosfyPrenom` — banc seulement.

## Bancs

```
-nosfy -nosfySortie -parcoursMaquette -nosfyPrenom Margaux -nosfyLangue en
        -fireAuto          # la flamme crache toutes les 3,4 s (le sim ne tape pas)
        -nosfySortieAuto   # le bouton se presse seul 5 s après la pose
        -sansNosfyVideo    # le poster à la place du galet
```

## Mesuré (simulateur iPhone 16 « nosfy-sortie-20260920 », 393 × 852)

- `pose-en.png`, `pose-fr.png` : l'état posé, dans les deux langues.
- `gerbe-en.png` : la gerbe et le saut de la flamme.
- `apparition-planche-en.jpg` (2 im/s) : noir → île → cône → galet → mots →
  flamme → bouton, puis la lumière qui voyage dans le verre.
- `sortie-fr-apparition-et-coupe.mp4`, `coupe-planche-fr.jpg` (8 im/s) : le
  zoom, le voile blanc, puis — **un noir** : l'overlay « Enregistrement… »
  (`sortieDemandee`, la session écran d'erreur, dans l'index d'une autre session)
  couvre le film en noir avant sa dissolution. Ce n'est pas mon hunk ; à
  arbitrer (le voile blanc pourrait rester sous l'attente).

## Non mesuré — reste ouvert

- **Son téléphone** : cadence et thermique de la couche vidéo agrandie sous
  `.screen` (à froid, `-sondeVol`, A/B `-sansNosfyVideo`), le rendu du blend sur
  l'appareil (validé le 13-09 sur ce fichier en petit, pas en grand), les
  haptiques (fort au jet), le doigt sur la flamme et le bouton.
- Sur le sim, le fond derrière le film au banc `-nosfy` est la porte (aucun
  compte) : dans le vrai parcours, c'est la home.
