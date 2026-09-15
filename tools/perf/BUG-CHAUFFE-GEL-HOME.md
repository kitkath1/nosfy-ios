# LE GROS BUG : LA HOME QUI CHAUFFE, PUIS QUI GÈLE — le dossier de mesure du 14-09 (RIEN N'EST CORRIGÉ)

**À lire avant de reprendre : [registre des échecs et mesures invalides](ECHECS-CHAUFFE-HOME.md).**

**Document historique du commit c313012.** Les affirmations causales des §§3–4
étaient trop fortes : les compteurs seuls ne prouvent ni une attente du main
ni un GPU saturé/bridé. Les traces ultérieures et leurs limites sont reliées
dans le registre ci-dessus (E02–E04). La chauffe reste ouverte ; l’accès au
Profil a depuis été rétabli. Les observations initiales restent conservées ici.

Son ordre du 14-09, 16 h : « commit pour documenter ce gros bug et le contexte de la QA,
ne fixe pas ». Ce fichier dit ce qui a été MESURÉ sur son iPhone 15 aujourd'hui, ce qui
est exclu, ce qui reste une hypothèse, et par où reprendre. Aucun chiffre n'est déduit.

## 1. Le contexte : le test QA du compte

Deux passages sur son téléphone (compte neuf créé avec Apple, Nosfy, home vide dans sa
langue, widgets, pop-up + visite) — **les étapes 1 à 6 sont validées par elle, front et
back** (onglet Test QA du site, `docs/site/content/qa.ts`). **L'étape 7 (la page profil) est
inatteignable** : « tout s'affiche hyper lentement, quasi impossible de naviguer, c'est
insupportable ». Les deux passages ont été joués avec un binaire DEBUG, téléphone branché.
Son constat de fond : « le téléphone est toujours chaud par défaut à cause de l'app dès que
je la rouvre, ça fait des semaines ».

## 2. Ce qui a été mesuré (la sonde `-sondeVol`, une ligne par seconde, `tools/perf/campagnes/`)

| Heure | Binaire | Lancement | Thermique au départ | Résultat (médiane des secondes, après 15 s de chauffe) | Fichier |
|---|---|---|---|---|---|
| 12:06 | Debug | câble, stable | **0** (froid) | **49,6 img/s · pire 47 ms · cpu 30 %** · horloges à 20 Hz : galets (tic 2) et ciel (tic 4) | `2026-09-14-1206/1-A.jsonl` |
| 12:1x | Debug `-sansVieRoute` | câble | 1 → 2 (chaud) | 44-48 img/s · pire 62-67 ms · max 258-713 ms · cpu 23-26 % | `2026-09-14-1206/2-B.jsonl` |
| 15:50 | **Release** | câble, qui tombe toutes les ~40 s | **2** (chaud) | 9 s à 45-52 img/s / 28 %, puis **3-8 img/s avec 0-4 % de cpu**, trous de 1,0 à 1,7 s | `2026-09-14-1546-binaire/1-R.jsonl` |
| 15:54 | **Release** | **à la main, SANS câble** | **2** (chaud) | 25 s à 48-60 img/s / 23-44 %, puis **40 s à 6-18 img/s avec 2-13 % de cpu**, trous de 300-640 ms, un de 1,6 s, puis retour à 55-60 img/s / 36-40 % | `2026-09-14-1546-binaire/main-R.jsonl` |

Les deux dernières lignes sont le bug tel qu'elle le vit. La dernière est la décisive :
**lancée par elle, sans câble, la Release gèle pareil.**

## 3. Ce que la signature dit — et ce qu'elle exclut

- **La cadence s'effondre PENDANT que le processeur tombe vers zéro.** Un rendu trop lourd
  donnerait l'inverse (cpu haut, cadence basse). Ici le fil principal **attend** : il est
  bloqué sur quelque chose, il ne calcule pas. Par vagues : ~25 s fluide, ~40 s de gel,
  retour fluide.
- **Exclu : le câble / la console de lancement** (l'hypothèse de 15:53) — le gel est là
  sans câble (15:54). Exclu : **le build Debug seul** — la Release gèle. Exclu : **le cpu
  saturé** — il est à 2-13 % pendant le gel.
- **Non exclu, non prouvé : le GPU.** Sur un téléphone à thermique 2 iOS bride le GPU ; la
  home lui donne du travail EN CONTINU (le ciel-shader à 20 Hz `HomeNuit.swift:211`, les
  galets à 20 Hz `GaletEtape.swift:256/957/1021`, le verre, les flous). Un GPU bridé qui ne
  suit plus fait attendre le fil principal à chaque commit d'image — cpu bas, image figée :
  exactement la signature. La sonde ne mesure PAS le GPU : c'est l'hypothèse n° 1, à
  prouver avec `xctrace` (Metal System Trace / temps GPU par image) sur téléphone chaud.
- Une autre attente possible (moins probable, à ne pas écarter sans mesure) : un travail
  synchrone sur le fil principal (disque, Keychain, SwiftData) déclenché par vagues.

## 4. Le cercle, en une phrase

La home immobile brûle **30 % d'un cœur** (froid, mesuré) plus du GPU en continu →
le téléphone monte à thermique 2 en quelques minutes (« toujours chaud dès que je la
rouvre ») → bridé, il ne peut plus payer cette charge continue → gel par vagues. Le skill
appelle 27-39 % « la norme de n'importe quelle page immobile » : **c'est cette norme qui
est le bug.** La Release ne l'enlève pas (mesuré).

## 5. Ce qui n'a PAS été fait (son ordre : ne pas corriger)

- L'A/B Release contre Debug **téléphone froid** (protocole `campagne-binaire.sh`, R D D R)
  : jamais joué, le téléphone n'a pas été froid de l'après-midi.
- La mesure GPU (`xctrace`) qui tranche §3.
- Les barreaux qui accusent une famille à la fois (`-sansCiel`, `-sansGalets` n'existent
  pas ; `-sansVieRoute` et `-sansPlateau` existent).
- Les remèdes du skill (animer au lieu de redessiner : 33-38 % → 4-18 % mesuré le 05-09 ;
  le verre hors de ce qui bouge) — **le dessin ne change pas**, c'est sa règle.
- L'audit statique (workflow, 12 fichiers, lecteurs + contradicteurs) a été **arrêté** en
  cours de contradiction, sur son ordre — rien de lui n'est retenu ici.

## 6. Ce qui a changé dans le code pour mesurer (et rien d'autre)

- `Woop/Views/PlayerMonde.swift:598, 625` : les deux appels `SondeHit.rapporter()` sous
  `#if DEBUG` — la sonde n'existe qu'en DEBUG, **la Release ne compilait plus**. Elle
  compile ; c'est ce binaire (avec la RewardCard définitive de la session porte) qui est
  posé sur son téléphone depuis 15:50, par-dessus, session gardée.
- `tools/perf/campagne-home.sh` (A/B/C par barreau), `tools/perf/campagne-binaire.sh`
  (Release contre Debug, installation par-dessus), `tools/perf/lire-vol.py` (verdict par
  manche, bilan) : le protocole du skill en une commande, réessais quand le câble tombe.
