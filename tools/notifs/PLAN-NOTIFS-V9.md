# NOTIFICATIONS V9 — le variant booster, simplement, et les robes qui varient

Verdict de Kathryn du 29-08 sur le V8 :

> *« oui mais on a 4 variants donc tu peux les faire varier, pas nécessaire
> de prendre que lui pour le backend. Je voulais juste que tu t'inspires du
> variant pièce et que tu mettes une image de booster qui bouge à la place de
> la pièce, pour avoir un variant booster. »*

Deux choses que j'avais **sur-interprétées** dans le V8, et qui sautent :

1. **Le variant 4 n'est pas un « rappel » avec son propre contrat.** J'avais
   bâti tout un §B4 (tapable ou muet, `highPriorityGesture`, « la première
   card qui demande la main »). Non : c'est **la jauge, avec un sachet à la
   place de la pièce**. Un objet remplacé, deux mots changés. Rien d'autre.
2. **Les robes ne sont pas clouées à un moment.** Mon tableau §C2 (la jauge
   pendant la séance, YOU WIN à la clôture, la Châsse aux rewards) était une
   règle que personne n'avait demandée. **Les robes VARIENT.** Le backend n'a
   pas à en choisir une par moment.

Ce qui **tient** du V8 : le §A (le glitch de la pièce, sa cause mesurée à
84 % d'images identiques, le fondu entre deux cases) — je ne le réécris pas.

---

## §A — LE VARIANT BOOSTER : ce que c'est, et ce que ce n'est pas

### A1. Le même template, un objet de moins, un objet de plus

```
+1  BOOSTER EARNED                      ┌────┐
VAULT PROGRESS                          │ ▓▓ │ ← le sachet, qui bouge
▬▬▬▬▬▬▬▬·:·▬▬▬░░░░░░░░░░                └────┘
```

- La dalle, le liseré, la typographie, la barre à grains : **la card 1 telle
  qu'elle est**, sans une ligne de plus.
- La pièce qui tourne (`PieceQuiTourne`) cède sa place à **un sachet
  détouré** — l'image des pop-ups, pas un rendu 3D.
- Les deux lignes de texte : `+1 BOOSTER EARNED` et… **?** la seconde. « VAULT
  PROGRESS » garde son sens (le sachet attend dans le coffre), mais la barre
  mesure des pièces, pas des sachets. Deux options, à trancher sur capture :
  la garder telle quelle (**c'est la même card, c'est le sujet**), ou la
  remplacer par une ligne muette du type `WAITING IN YOUR VAULT`.

### A2. ⚠️ QUEL sachet — j'avais pris le mauvais dans le V8

Le V8 disait `sticker-booster` + `sticker-booster-holo`. **Vérifié dans le
code** (`RewardCheminVariants.swift:437`, `SachetRecompense`) :

| image | ce que c'est | taille | frise holo |
|---|---|---|---|
| **`booster-orange`** | le sachet ORANGE — le type `.orange` du chemin, celui que les pièces achètent ; **?** rien dans le code ne lie explicitement le sachet de fin de séance (`origine = 'seance'`) à une image | 1054×1408, alpha | au repos **non** |
| `sticker-booster` | le sachet **NOIR**, le type `.legendaryBlack` | 794×1278, alpha | oui : liseré au repos à 0,5, et `sticker-booster-holo` à 6 °/s quand il est tenu |

⚠️ Relu contre le code : `SachetRecompense` ne garde le liseré **au repos**
que pour le noir, mais **le holo à la prise ne teste que `tenu`** — un sachet
orange tenu reçoit aussi la frise du noir (`RewardCheminVariants.swift:476`).
Probablement un oubli ; pour nous ça ne change rien, le sachet de la
notification n'est jamais tenu.

Le booster « qu'on gagne » dans 99 % des cas est **l'orange**. Donc le variant
4 porte `booster-orange`, et **pas de frise holo** (elle appartient au noir).

Ce que ça donne en cadeau : **la même card, avec `sticker-booster` + holo à la
place, est la notification d'un légendaire** — une robe de plus pour le prix
d'un `if`. Je ne la fais pas ce tour-ci ; je note qu'elle est gratuite.

⚠️⚠️ **Toujours pas le booster 3D de `BoosterPack`** (SceneKit décode ses
textures sans cache à chaque construction, ~36 Mo, et rend même effacé par
l'opacité). Une notification qui vit trois secondes n'a pas les moyens.

### A3. « Qui bouge » — la lévitation, et un roulis

L'école `CalLab` (les stickers de la story) : **fonctions pures de `t`,
périodes premières entre elles, jamais de `repeatForever`**.

- une lévitation de **±2 pt** en y (période 3,7 s) ;
- un roulis de **±3°** (période 5,3 s) — c'est lui qui fait « l'objet qui
  flotte » plutôt que « l'image qui monte et descend » ;
- pas d'ombre portée (`.shadow` par image = un flou par image — la loi
  **mesurée sur le WIN**, « trois flous par image coûtaient 14 img/s, 42 contre
  56 », que `SachetRecompense` applique par analogie sans l'avoir remesurée
  sur les sachets) — une **ellipse peinte** dessous, comme là-bas.

Une transformation continue : **aucun stroboscope possible**, contrairement à
la planche de la pièce (V8 §A).

### A4. La pose — deux essais au banc, un verdict

La pièce fait 92 pt et **mord** le bord droit de 16 pt. Le sachet est un
portrait (0,75:1) : dans une dalle de 138 pt, il fait ~112 pt de haut pour
~84 pt de large.

Je poserai **les deux** sur le banc, l'une sous l'autre :
- **(a) il mord le bord** comme la pièce — la grammaire de la card 1 ;
- **(b) il tient entier** dans la réserve de droite, avec 12 pt d'air.

Un objet coupé par le bord se lit soit comme une intention (la pièce), soit
comme un bug (un sachet dont on ne voit pas le haut). **Ça se juge sur la
capture, pas sur le papier.**

### A5. Muet, comme les trois autres

Le V8 §B4 est retiré. La dalle ne demande rien au doigt
(`allowsHitTesting(false)` — la même loi que `PillGain` et `PiecesNotif`
aujourd'hui). Si un jour une notification doit ouvrir quelque chose, ce sera
une décision à part, pas celle-ci.

---

## §B — LES ROBES VARIENT (la règle backend, réécrite)

### B1. Ce qui remplace le tableau du V8

> **Toute annonce d'un gain passe par le template des notifications.** Une
> famille de dalles. **Les robes « pièces » (jauge, gros texte, châsse) se
> succèdent en variant** ; la robe « booster » s'affiche quand le gain est un
> sachet.

Il n'y a **pas** de robe par moment. Un +20 de série peut tomber en Châsse, un
+240 de clôture en jauge. C'est ce qui rend le template intéressant : on ne
voit pas trois fois la même card dans une séance.

### B2. Comment « varier » — une proposition, à trancher

| option | ce que ça donne | ce que ça coûte |
|---|---|---|
| **(1) rotation déterministe** — `hash(session_uuid, serie_index) % 3` | jamais deux fois la même d'affilée à séance égale ; **rejouable au banc** (une page qui change d'avis à chaque relance ne se juge pas — la loi du `DecideurSerie`) | rien : c'est du client, aucun appel |
| (2) tirage au hasard client | varie | injugeable au banc ; deux fois la même de suite arrive |
| (3) le serveur choisit | une robe par gain dans la réponse du règlement | ⚠️ la dalle s'affiche AVANT la réponse (loi du §1 du plan backend) — elle devrait donc la choisir seule de toute façon |

**Je recommande (1)**, avec une réserve pour plus tard : le jour où le moteur
de décision (§2 du plan backend) voudra imposer une robe pour un gain
exceptionnel (le gros texte pour un record, par exemple), il pourra la
renvoyer et la dalle l'honorera **si elle est là** — sinon la rotation.

### B3. Ce que le backend doit garantir (inchangé du V8, et vérifié depuis)

- **L'UI affiche le gain tout de suite.** C'est la loi du §1 du plan backend
  et c'est déjà ce que fait `terminerSeance` : ~~la notif part à +1,6 s~~
  **périmé depuis 8e8a0cc (30-08)** — la story part à +2,0 s, puis la capsule
  à **+0,3 s après la fermeture de la story** (`WoopApp.swift:543-556`,
  `enchainerApresStory`) ; l'appel
  `cloturer_seance` vit dans une tâche détachée qui **ne propage jamais son
  échec** (`SacreServeur.reglerFinDeSeance`).
- **Le règlement est idempotent** et passe par l'outbox (`OutboxGains`, un
  index unique partiel par écriture côté serveur) — une annonce locale n'est
  jamais un double crédit.
- ⚠️ **« VAULT PROGRESS » ne peut pas être locale.** C'est un solde, et
  `etat_coffre()` rend déjà `reste (0-99)` pour ça. Tant que la dalle n'est
  pas branchée, la barre affiche **`fraction = 0,62`, une constante de démo**
  (`NotifJauge`) — écrit noir sur blanc dans la fiche écran.

### B4. Où ça s'écrit — ⚠️ le numéro du V8 était déjà pris

Le V8 annonçait un « §4 undecies » dans `PLAN-REWARDS-BACKEND.md`. **Il
existe déjà** (« Ce que le coffre attend — le wallet à deux monnaies »),
suivi de duodecies (versement de connexion) et terdecies (boosters du chemin
et de séance). La règle des notifications sera donc le **§4 quaterdecies**.

---

## §C — LA FICHE ÉCRAN

Écrite ce tour-ci, au format des deux fiches existantes (`coffre-rewards.md`,
`duolingo-chemin.md`) : **`docs/screens/notification.md`**. Elle dit ce que la
dalle remplace (les DEUX toasters d'aujourd'hui, pas un), ce qui la déclenche
à chaque moment, quel appel part autour d'elle, et où elle ne peut pas encore
dire la vérité.

**Elle a été relue à l'adverse, ligne par ligne, contre le code** (56
affirmations, 47 confirmées, 9 corrigées). Ce que la relecture a trouvé et que
je n'aurais pas vu seul :

1. **`-notifSeule 3` n'isole pas la Châsse** (V9-0 ci-dessous).
2. **Welcome Back est atteignable en production** : le chip « … » du header
   de la fiche exo (« prêté à la card reward le temps de l'atelier ») est
   monté sans drapeau et fait tourner les six robes — deux taps.
3. **`settleSeries` n'écrit pas en SwiftData** : la fin d'une série ne persiste
   rien du tout (brouillon en mémoire) — la seule écriture est `save()`.
4. **Le vol de pièces de la home est en archive** (`HomeAuroraView`) : la
   capsule d'aujourd'hui descend seule.
5. `terminerSeance` **bascule toujours sur la home**, même à gain zéro ; seuls
   le trophée, la notif et la pop-up sont gardés.

---

## §D — LES JALONS

| # | Ce qui sort | Comment on le juge |
|---|---|---|
| **V9-0** | ⚠️ **Le bug du banc** : `-notifSeule 3` n'isole pas la Châsse (`NotifLab.swift:51` teste `seule != 2` au lieu de `seule != 2 && seule != 3` — la jauge reste montée). Trouvé par la relecture adverse de la fiche écran : **la mesure « Châsse seule 60,0 img/s » portait deux dalles** — conservatrice, pas fausse, mais mal étiquetée | une ligne, puis **remesurer** la Châsse vraiment seule |
| **V9-1** | Le fondu entre deux cases de la planche (V8 §A) | **la même sonde** : images identiques 84 % → ~0, cadence à 60 |
| **V9-2** | Le variant booster — `booster-orange`, lévitation + roulis, **deux poses** (mord / entier) | capture + film |
| **V9-3** | `docs/screens/notification.md` | **fait ce tour-ci** — relecture |
| **V9-4** | Le §4 quaterdecies dans le plan backend | relecture |
| **V9-5** | Ton verdict | — |

---

## §E — CE QUI RESTE OUVERT

1. **La seconde ligne du variant booster** (§A1) — sur capture.
2. **La pose du sachet** (§A4) — sur capture, deux essais.
3. **Le plan aux pièces** (`nosfy_pièces_sol`, 0,85:1 contre une dalle
   2,58:1) — pas tranché.
4. **La durée d'affichage** : `PillGain` tient 2,0 s, `PiecesNotif` 3,0 s
   (clôture) ou 3,2 s (chemin). Les films du banc mettent ~1,3 s à se poser
   (0,35 s de délai + 0,62 s de ressort + la barre). **?** — 3,2 s partout
   me semble le minimum pour lire le chiffre ET voir la barre monter.
5. **La langue** : `PillGain` parle anglais (« this session »), `PiecesNotif`
   français (« pièces lune »). Le template est en anglais. À trancher une
   fois pour toutes — **?**.
6. **La cadence sur téléphone** — jamais mesurée.
7. **Rien n'est commité** (quatre fichiers nouveaux dont
   `nosfy-notif-loop.mp4` à `git add`er explicitement, trois modifiés).
