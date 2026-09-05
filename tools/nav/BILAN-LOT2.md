# BILAN LOT 2 — ce qui a été codé, et ce que le banc a prouvé

04-09. Le plan d'analyse est `PLAN-LOT2-SEANCE.md` ; ceci en est l'exécution.
Tout ce qui est écrit ici a été **mesuré**, pas déduit.

---

## 1 · La cause qu'aucune lecture n'avait vue

Le plan disait « impossible de cliquer sur la bulle » = elle est partie dans l'île.
C'était une cause réelle, mais **ce n'était pas la principale**.

Le banc à vrais touchers a mesuré, sonde par sonde :

| ce qu'on croyait | ce que le doigt a mesuré |
|---|---|
| la pastille se drague, mais elle part dans l'île | **la pastille ne se draguait PAS DU TOUT** |
| son tap ouvre le player | **son tap ne partait jamais** |
| l'overlay ne s'ouvre pas | il s'ouvrait — **par le TICKET**, tout seul |

Les compteurs posés DANS le geste : `chg=0` (son `onChanged` jamais appelé),
`tap=0` (son tap jamais reconnu), et une sonde posée à l'extérieur du même
corps comptait **9 événements de doigt** sur le même geste.

**La cause : le verre natif `.interactive()` de la robe.** Un verre interactif se
déforme sous le doigt — donc il PREND le toucher. Il vit dans le `.background`
du corps, donc dans son CONTENU ; or un `.gesture()` a une précédence
**inférieure** aux gestes du contenu. Le geste de la pastille perdait, à chaque
fois, silencieusement.

Seul le TICKET répondait — parce que lui est en `highPriorityGesture`. Et son
relâcher « franc » appelait `onOuvrir()`. D'où l'illusion : « le tap marche
parfois », « ça ouvre l'overlay tout seul », « la bulle ne bouge pas ».

**Le remède** : le geste de la pastille passe en `highPriorityGesture` — on
passe DEVANT le verre, on ne l'éteint pas (elle veut le voir au drag).

### Et un second vol, du même genre

Le ticket était descendu de 20 pt par un `.offset`. **La loi de la maison le
disait déjà** : `.offset` déplace les PIXELS, pas la zone tactile. Sa prise
était donc restée 20 pt plus haut — c'est-à-dire **en plein centre de la
pastille**, encore élargie de 10 pt par son `contentShape`. Tout drag né au
centre était avalé par le ticket.

**Le remède** : la descente devient du LAYOUT (`alignmentGuide`), le
`contentShape` revient à la forme nue, et un tirage n'ouvre plus le player que
**vers le bas** (c'était « > 40 dans n'importe quel sens » : un geste vers le
haut, celui qui range la pastille, ouvrait le player).

---

## 2 · Ce qui a été corrigé, dans l'ordre du plan

| # | ce qui était cassé | fichier |
|---|---|---|
| ① | le châssis posait `mini = true` à chaque séance, et plus rien ne relevait la nav | `WoopApp.swift` · `NavEncre.swift` |
| ① | le premier tap de chaque séance était confisqué par « en mini, tout tap déploie » | `NavEncre.swift` |
| ② | pilule et grand player montés dans la zone sûre alors que leurs cotes sont physiques : tout tombait 59 pt trop bas | `WoopApp.swift` |
| ② | la pose basse s'asseyait SUR la nav (borne `H−96` → `H−138`) | `WoopApp.swift` |
| ③ | le tap sur l'île ne faisait que l'en sortir : plus aucun chemin vers le player | `PiluleVagabonde.swift` |
| ③ | `dansIle` n'était jamais remis à faux : une fois dedans, on y restait, séance suivante comprise | `WoopApp.swift` |
| ③ | 125 pt de côté suffisaient à l'aspirer sans intention (porte resserrée à un vrai jet) | `PiluleVagabonde.swift` |
| ④ | deux PageCard du même onglet écrasaient la visibilité de la nav → registre par jeton | `NavEncre.swift` · `PageCard.swift` |
| ④ | une voix retirée n'était jamais redonnée au retour d'une fiche → `onAppear` symétrique | `PageCard.swift` |
| ⑤ | `morphPlayer` ne mourait pas avec sa séance : la suivante naissait plein écran | `WoopApp.swift` |
| ⑥ | braises de la pilule à 30 Hz toute la séance → 15 Hz | `PiluleVagabonde.swift` |
| ⑥ | braises PLEIN ÉCRAN du grand player restées à 30 Hz → 15 Hz + gelées hors pose | `PiluleVagabonde.swift` |
| ⑦ | l'invite « Choisissez un exercice » battait à 30 Hz sans aucune porte → 20 Hz + gel | `PiluleVagabonde.swift` |
| ⑧ | deux sondes de debug tournaient en PRODUCTION (garde `-fps` sautée) | `SondeCadence.swift` |
| ⑨ | l'île à 30 Hz, avec un rayon d'ombre ANIMÉ (jamais mis en cache) → 15 Hz, rayon fixe | `PiluleVagabonde.swift` |
| ⑪ | `.offset(etat.dessin)` lu dans le corps : toute la pastille reconstruite à chaque image | `PiluleVagabonde.swift` |
| ⑫ | le halo de cible lisait la position du doigt dans le corps → vue à part | `PiluleVagabonde.swift` |
| + | le grand player appliquait `fermeture` DEUX fois : l'écran descendait au double de la main | `PiluleVagabonde.swift` |
| + | la pilule chantait derrière le grand player (rideau) → moteurs gelés | `WoopApp.swift` |
| + | le banc `-navEncre` n'affichait plus AUCUNE nav : un juge aveugle | `NavEncre.swift` |

---

## 3 · Le banc, re-matricé pour la nouvelle architecture

`tools/nav/fouettage/` testait LE REPLI de la nav — mort au pivot. Il teste
maintenant ce qui l'a remplacé : `monte_banc_pilule.sh`, `BancPilule.swift`,
`FouettagePiluleUITests.swift`, `DiagGestePilule.swift`.

Huit cas, à vrais touchers, chacun rejouant une phrase de son verdict :

1. la nav reste entière en séance (jamais de points) ;
2. le premier tap de nav navigue ;
3. le tap sur la pastille ouvre le grand player ;
4. lâchée, elle se pose là où on la lâche — pas dans l'île ;
5. un déplacement latéral lent ne l'aspire plus ;
6. jetée en haut elle entre dans l'île, et le tap de l'île ouvre le player ;
7. le drag quitte l'île ;
8. la nav revient après des allers-retours d'onglet (le registre).

---

### Le verdict du banc, à vrais touchers

```
test01 nav reste entière en séance ............... passed
test02 le tap de nav navigue du premier coup ..... passed
test03 le tap sur la pastille ouvre le player .... passed
test04 lâchée, elle se pose où on la lâche ....... passed
test05 un déplacement latéral ne l'aspire plus ... passed
test06 l'île se remplit, et son tap OUVRE ........ passed
test07 le drag quitte l'île ...................... passed
test08 la nav revient après aller-retour d'onglet  passed
                                                    8/8
```

(Le banc `-piluleLab` dessinait encore QUATRE glyphes et le point orange :
un juge qui montre un écran qui n'existe plus. Il monte maintenant la VRAIE
`NavBande`, à la géométrie exacte du châssis.)

---

## 4 · Ce que le banc a appris, et qu'elle doit trancher

**L'île tombe dans le trou physique de la Dynamic Island.** Son centre est à
y ≈ 30 : c'est très exactement le trou que le système se réserve. Un toucher n'y
arrive PAS à l'app. Seule la **lèvre basse** de la capsule (sous le trou,
~16 pt) est atteignable au doigt — le banc vise là, et le tap ouvre bien le
player.

Au doigt réel, ça veut dire : **la cible est étroite**. Si le tap sur l'île doit
être confortable, il faut épaissir cette lèvre (l'île descend plus bas que le
trou). C'est un choix de dessin, pas une correction.

---

## 5 · Ce qui n'a PAS été fait, et pourquoi

- **L'ancien `PlayerMonde` reste monté toute la séance** (plan ⑩). Son propre
  commentaire dit son arbre INERTE hors ouverture, et il porte le
  `onChange(of: seance == nil)` de fin de séance : le démonter demande un
  verdict de fin de séance au téléphone, pas une déduction.
- **Le verre `.interactive()` n'a pas été mesuré** (`-fps` vs `-fps -piluleMate`).
  La loi « 60 → 14 img/s » a été mesurée sur l'ANCIEN verre ; le natif d'iOS 26
  n'a jamais été mesuré ici. La sonde est en place, la mesure reste à faire.
- **La chauffe ne se prouve qu'au téléphone.** Les moteurs sont comptés et
  abaissés ; leur poids relatif ne se lit pas dans le code. La méthode reste
  l'A/B, un moteur à la fois, main sur le dos.
  **L'A/B `-sansBord` a été JOUÉ au simulateur, machine calme** : ruban allumé
  ≈ 5 img/s médians, ruban éteint ≈ 8 — les DEUX effondrés. Le simulateur n'est
  pas un instrument valable pour ça (loi du dépôt), et l'écart ne désigne pas
  le ruban comme cause dominante. **Cette mesure est à refaire sur le
  téléphone** ; tant qu'elle n'est pas faite, on ne dit pas ce qui chauffe.
- **Le `bande` de `PageCard` est du code MORT** (déclaré, jamais monté depuis
  que la nav a déménagé). Il entraîne avec lui `BandeCote`, la publication de
  `bandeRectFenetre` et tout `PanBande.swift` (dont `NavPanHote` n'est instancié
  NULLE PART). C'est une dette réelle et un piège — il m'a coûté un tour de
  banc — mais la supprimer est un chantier propre, pas un correctif de séance.
