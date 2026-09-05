# PASSATION — la performance et la chauffe de la HOME

*Écrit le 05-09-2026, à la fin d'une journée entière de mesures sur l'iPhone 15
de Kathryn. À lire EN ENTIER avant de toucher une ligne. Le skill
`woop-performance` contient la méthode ; ce document contient l'état.*

---

## LE PROMPT À COLLER POUR LA PROCHAINE SESSION

> Charge le skill `woop-performance` et lis `tools/nav/PASSATION-PERF-HOME.md`
> AVANT toute chose.
>
> Sujet : la page d'accueil de Woop chauffe le téléphone dès qu'on l'ouvre, sans
> rien faire. On a trouvé la cause et démontré le remède ; il reste à l'appliquer
> partout.
>
> LA CAUSE, mesurée : l'app ne recalcule rien (le corps de la page est réévalué
> 0 fois par seconde) mais elle REDESSINE en continu. Des `TimelineView` battent
> ~100 fois par seconde pour animer deux ou trois scalaires, et chaque battement
> reconstruit des dégradés, des traits et des flous gaussiens SOUS un verre natif
> — qui ne peut donc rien mettre en cache.
>
> LE REMÈDE, mesuré et validé à l'œil par Kathryn : on n'anime plus en
> redessinant. Une valeur animable (opacité, échelle, rotation) est interpolée
> par le système sans reconstruire le contenu. A/B sur son téléphone, à cadence
> égale : processeur 33-38 % → 4-18 %, battements 122 → 24.
>
> CE QUI RESTE : appliquer le même geste aux cinq horloges d'ambiance de
> `HomeNuit.swift` et aux huit `TimelineView` restantes de `WidgetsCards.swift`.
> La liste exacte est au §4 de ce document.
>
> ⚠️ Trois règles non négociables : on mesure sur SON téléphone et jamais au
> simulateur · on ne change JAMAIS le rendu sans le lui montrer d'abord · on ne
> lui annonce pas un gain qu'on n'a pas mesuré.

---

## 1. CE QU'ELLE VIT, dans ses mots

- « ça chauffe alors que j'ai juste ouvert sur la homepage et rien fait »
- « dès que je lance Woop ça rechauffe »
- « on tourne en rond » — dit après une demi-journée de mesures fausses. **Elle
  avait raison** : voir les pièges au §5.
- Sur la respiration : **« oui, elle respire en permanence »** — la page qu'on
  REGARDE ne doit pas se figer. Ce n'est pas négociable, et ça exclut toute
  optimisation qui consiste à éteindre.
- Sur les vidéos et le verre : « sans perdre les vidéos et tout, on est en
  2026 ». Elle ne veut pas moins de dessin, elle veut le même moins cher.

---

## 2. L'ÉTAT MESURÉ (iPhone 15, sonde de vol, téléphone froid)

| | processeur |
|---|---|
| écran NU (le châssis rend du noir, aucune page) | **1 %** |
| n'importe quelle page, immobile | **27 à 39 %** |

**Le châssis ne coûte rien : tout est dans les pages.** Une page statique devrait
être à 2 %. Le Profil seul coûtait même **39 %**, plus que l'accueil — donc ce
n'est pas « la home a un mauvais widget », c'est un MOTIF partagé.

**Le corps de la page est recalculé 0 fois par seconde.** SwiftUI ne refait
aucune mise en page. Le coût est du REDESSIN, pas du calcul.

Battements d'horloges comptés sur l'accueil immobile, avant tout correctif :
la home 32/s · les widgets 30/s · la nappe du menu 16/s · les galets 15/s —
soit **93 à 128 par seconde**.

---

## 3. CE QUI EST FAIT, ET CE QUE ÇA A DONNÉ

| geste | preuve |
|---|---|
| **le ruban de séance retiré** | balades de Kathryn : en séance **9,3 → 30,2 img/s** (×3,2). Elle a tranché : « enlève le ruban c'est pas grave » — c'est DÉFINITIF, gravé dans `PageCard.swift:289` |
| **18 horloges de l'accueil alignées sur un pas commun (20 Hz) + fermées quand l'onglet n'est pas affiché** | 37,5 % → 27,5 % sur une mesure |
| **9 horloges du Profil et d'Exercices fermées** | pas encore chiffré (téléphone jamais froid depuis) |
| **le galet du chemin : cadence écran (120 Hz) → 20 Hz** | inclus dans le lot ci-dessus |
| **la pièce de lune du Profil figée** (`figee: true`) | rendu identique au pixel, documenté par le composant |
| **le liseré des widgets : animé au lieu d'être redessiné** | **A/B alterné, cadence égale : cpu 33-38 % → 4-18 %, battements 122 → 24.** Rendu validé par Kathryn : « non ça me va » |
| **la nappe du menu : idem** | codé, poussé, **pas encore mesuré séparément** |

### Innocentés — mesurés, ne pas y revenir

- **les calques vidéo du fond** : image de pose à la place → 37 % contre 38 %.
- **le verre de la card route** : sa balade donne 23,4 img/s sans lui contre
  30,2 avec. Remis.
- **le ciel nébuleuse** : plus monté sur les pages actuelles.
- **le gyroscope** : `tilt` a sa bande morte ; `shake` n'en a pas mais son seul
  lecteur est ailleurs.

### Le seul poste isolé qui reste

**Le verre natif : ~9 points.** Six verres de l'accueil éteints → 37 % → 28 %.
⚠️ **Ne pas l'attaquer de front** : un verre ne coûte que parce que ce qu'il y a
DESSOUS change. Le geste ③ traite la cause par en dessous. **On re-mesure le
verre APRÈS avoir fini les horloges**, et seulement s'il reste un écart.

---

## 4. CE QUI RESTE À FAIRE — la liste exacte

Le même geste, partout : **animer au lieu de redessiner**. La recette complète
et ses deux factorisations sont au §5-③ du skill `woop-performance`.

| site | ce que le temps y fait | animable ? |
|---|---|---|
| `HomeNuit.swift:209` | à lire | probablement |
| `HomeNuit.swift:4698` | à lire | probablement |
| `HomeNuit.swift:4835` | à lire | probablement |
| `HomeNuit.swift:4874` (`InviteTirage`) | opacités de chevrons | **oui** |
| `HomeNuit.swift:4953` | salves | à lire |
| `WidgetsCards.swift:1019` et 7 autres | à lire une par une | |
| `ProfilLune.swift:1238, 1420, 1504, 1929, 2032` | opacités, rotations, échelles | **oui** a priori |
| `GaletEtape.swift:246` | un shader nourri du temps | **NON** — un shader a besoin du temps ; ne pas y toucher |

**⚠️ NE PAS TOUCHER** : `HomeNuit.swift:2733` — l'horloge du film de départ
(1/60, `paused: depart == nil && ferme == nil`). Elle porte les 1,95 s de la
cinématique et elle est déjà pausée au repos.

**Les barreaux existants** : `-sondeVol` · `-souffleHorloge` (rejoue l'ancienne
forme : le témoin de l'A/B) · `-sansRepos` · `-ecranNu` · `-fondPose` ·
`-sansVerreHome` · `-sansVerreRoute`/`-avecVerreRoute` · `-sansBord`.
**Tout nouveau geste arrive avec le sien.**

---

## 5. LES PIÈGES — chacun a coûté au moins une heure

1. **L'écran qui s'endort** : la cadence tombe et le processeur avec. On croit
   avoir éteint un moteur coûteux ; on a mesuré une veille. (`SondeVol` tient
   l'écran éveillé — toute mesure prise sans ça est à jeter.)
2. **Le drapeau oublié** : une demi-journée d'essais jouée sans `-skipAuth`,
   donc sur la PORTE et pas sur la home. Tous les « ça ne change rien » de cette
   série étaient faux. **La ligne `onglet` de la sonde est la preuve d'écran.**
3. **La chaleur qui s'accumule** : au-dessus de l'état thermique 1, iOS bride.
   **Relancer l'app en boucle pour mesurer maintient le téléphone chaud** — une
   partie de ce qu'elle a senti venait de mes propres campagnes. Thermique lu à
   la première seconde ; si ≥ 1, on attend.
4. **Comparer deux cadences différentes** : un % à 21 img/s et un % à 60 img/s
   n'ont pas le même dénominateur.
5. **Le profileur d'Apple ne s'attache pas** à ce téléphone (« Timed out waiting
   for device to boot ») alors que tout est correct : mode développeur activé,
   appairé, câble, DDI disponible. Essayé en `--launch`, `--attach`, par UDID et
   par nom. **Ne pas y reperdre une heure** ; pistes non épuisées : `Animation
   Hitches`, `Metal System Trace`, MetricKit.
6. **Deux `allowsHitTesting` sur la même pile ne s'additionnent pas** : le
   dernier posé décide. Un correctif de zone tactile peut être effacé en silence
   par un modificateur posé plus loin (payé sur l'ancien menu de fumée).
7. **Un workflow d'experts n'est pas une preuve.** Une étude à 18 agents a rendu
   un plan détaillé dont **les 12 contradicteurs ont rejeté les 12
   propositions** ; le rédacteur a écrit quand même. Ne citer d'un plan que ce
   qu'on a re-vérifié soi-même dans le code.

---

## 6. CE QU'ON NE SAIT TOUJOURS PAS

- **La part GPU.** La sonde ne voit que les fils de l'app : le serveur de rendu
  et le GPU lui sont structurellement invisibles. C'est probablement pour ça que
  le % de processeur ne bougeait pas entre 60 et 21 img/s.
- **Le reste des 27 %.** Les gestes faits n'expliquent pas tout, et il ne faut
  pas prétendre le contraire avant de l'avoir mesuré à froid.
- **Les trois lots déjà posés n'ont pas tous leur chiffre** : son téléphone n'est
  jamais redescendu à l'état thermique 0 de la journée. **La première chose à
  faire à la prochaine session : une mesure de référence à froid.**
