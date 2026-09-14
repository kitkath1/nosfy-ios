# VERDICTS DU 05-09 SUR LES WIDGETS / LES CHAMBRES LONGUES

> **Rien n'est codé.** Ces verdicts ont été dictés pendant le chantier du Foyer
> (`tools/foyer/PLAN-FOYER.md`), puis Kathryn a précisé : *« j'ai confondu la
> session quand je parlais des widgets HIIT »*. Ils appartiennent donc **au
> chantier des widgets**, pas à celui de la home en séance. Rangés ici pour ne
> pas être perdus, et pour ne pas polluer le plan du Foyer.

Ses mots, verbatim :

> « j'imagine le composant *tour* au scroll et on voit tous les jours blur effect
> on passe du mardi ou jeudi comme ça on peut comparer aussi pas mal ça
> (généralement il y a pas plus de 5 HIIT par semaine ! donc faut recalibrer le
> composant du haut !) » · « j'aime » · « donc les cercles tour avec tous les
> jours faits en hiit » · « au scroll » · « horizontal »
>
> Puis, sur la légende « Anneau intérieur : mardi dernier, même échelle — 7:40,
> 43 % du tour » : **« enlève ça et tu mets le jour en dessous ; quand c'est le
> meilleur tu mets *meilleur jour* avec un sticker flamme, ou tu compares par
> rapport à la semaine précédente, en bien ou en mal ! »**
>
> Et : **« pareil les marches de la séance : c'est pour UNE séance, c'est pas le
> récap semaine ou mois, attention ! »**

---

## 1 · L'ANNEAU DE COMPARAISON EST MORT

La légende « Anneau intérieur : mardi dernier, même échelle » disparaît. À la
place, **sous le tour**, l'un OU l'autre — jamais les deux :

- le **jour**, et s'il est le meilleur : **« meilleur jour » + un sticker flamme**
  (le registre `WoopSticker` existe déjà) ;
- ou la **comparaison à la semaine précédente**, en bien ou en mal.

## 2 · `tours` CHANGE DE SENS — c'est une autre donnée, pas un réglage

Aujourd'hui `HiitPeakInfo.tours = 4` (`Woop/Views/WidgetsCards.swift:2164`) = les
**répétitions d'UN segment** (« 4 × 40 s »), dessinées par la chambre (`:1463`).
Sa demande : **un cercle par JOUR fait en HIIT**.

`SemaineStats.hiitPeak` (`WidgetsCards.swift:2299`) ne rend aujourd'hui que le
**meilleur segment de la semaine** — il faudrait qu'il rende **un tour par jour**.
⚠️ **Non chiffré : je n'ai pas lu comment.** C'est le premier geste du chantier.

## 3 · LE SCROLL HORIZONTAL À VOISINS FLOUTÉS — deux pièges déjà payés

- ⚠️ `onScrollGeometryChange` avec une valeur **constante ne rappelle jamais**, et
  il faut **une sonde par scroll** (piège maison).
- ⚠️ Un flou **par cercle** est un `.blur` par objet : **27 img/s**. Le flou doit
  être **un seul**, posé sur le conteneur — ou remplacé par **opacité + échelle**,
  bien moins cher et suffisant pour dire « ce n'est pas celui-là ». À trancher sur
  capture, pas sur le papier.

## 4 · « LE COMPOSANT DU HAUT » À RECALIBRER — à faire préciser

≤ 5 HIIT par semaine, donc « le composant du haut » doit être recalibré. **Reste à
lui demander** : « le composant du haut » = la **FACE** de la card HIIT (au-dessus
de sa chambre), ou autre chose ?

## 5 · LA RÈGLE, ET ELLE VAUT PARTOUT

> **Un composant qui parle d'UNE SÉANCE ne montre jamais un récap semaine ou mois.**

Dictée à propos des « marches de la séance », mais c'est une règle générale : elle
vaut pour toutes les chambres longues. À porter dans les fiches d'écran.
