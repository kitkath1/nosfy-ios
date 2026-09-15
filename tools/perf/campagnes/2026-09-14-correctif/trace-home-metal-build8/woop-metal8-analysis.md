# Metal System Trace — vraie Home, build 8, protection active

**La trace contient du travail GPU réel, principalement dans `backboardd`, mais aucune saturation GPU permanente : environ 32,53 % du temps GPU couvert est Active. Un retard d’affichage de 1,88 s coïncide avec une longue plage GPU Idle.** Ce relevé situe donc le coût du compositeur et un incident de présentation ; il ne démontre pas que la chaleur bloque le GPU.

## Contexte vérifié

- Source : `/private/tmp/woop-home-build8-metal.trace`, iPhone de Frédéric, iPhone 15/A16, Woop PID **17148**, build 8.
- Fenêtre TOC : **15 septembre 2026, 07:45:18.161 → 07:45:27.788, Europe/Paris**, durée exacte des lignes **9,627343893 s**. L’outil avait reçu une limite de 8 s : les dénominateurs ci-dessous utilisent les données réellement exportées.
- Home avec ses deux widgets, Route et « pull to start », vérifiée sur `/private/tmp/woop-current8.png` ; la capture d’écran précède l’enregistrement et ne prouve pas chaque image de celui-ci.
- **Protection thermique active**, établie par la sonde autour de la capture. La table thermique donne **Fair pendant 100 % des 9,627 s**, `Current`, `is-induced=0`. Il ne s’agit pas du scénario historique Serious sans protection. Ne pas substituer une valeur thermique postérieure à celle de cette fenêtre.
- La trace, volumineuse et instrumentée, peut perturber l’exécution. Les chiffres de présentation ci-dessous décrivent cet enregistrement, pas un essai d’usage sans instruments. La sonde de référence est `tools/perf/campagnes/2026-09-14-correctif/build8-home-reference.jsonl` ; ses callbacks ne sont pas des présentations à l’écran.

## Méthode et données réellement présentes

Résolution complète des `id/ref` XML avant lecture des lignes ; valeurs temporelles brutes en ns. Pour l’activité GPU, **union temporelle des intervalles**, tous canaux confondus : les périodes qui se chevauchent ne sont pas additionnées deux fois. Les unions par processus ou canal peuvent se chevaucher entre elles et ne s’additionnent pas.

| Table | Lignes réelles | Ce qu’elle permet |
|---|---:|---|
| `metal-gpu-intervals` | **140 146** | Exécutions GPU, canaux, processus, latence CPU→GPU, accès aux surfaces |
| `metal-gpu-state-intervals` | **275 294** | Alternance globale Active/Idle du GPU |
| `displayed-surfaces-interval` | **262** | Durées de présentation et latences CPU→display disponibles |
| `displayed-surfaces-per-second` | **10** | Comptage direct des échanges de surfaces |
| `gpu-performance-state-intervals` | **946** | État de performance, avec couverture partielle |
| `gpu-performance-device-state-intervals` | **946** | Libellés Minimum/Medium/Maximum des mêmes périodes |
| `device-thermal-state-intervals` | **1** | Fair sur toute la capture |
| `ca-client-buffer-wait-interval` | **0** | Aucune attente de drawable exploitable dans cet export |
| `display-compositor-interval` / `display-compositor-events-interval` | **0 / 0** | Aucune période de compositeur CPU exploitable dans ces tables |
| `ca-client-present-request` / `ca-client-presented-handler` | **0 / 0** | Aucun événement exploitable |

Une table vide n’est pas une preuve d’absence d’attente. Shader Timeline est désactivée et aucun jeu de compteurs shader n’est sélectionné dans les réglages : pas de classement par shader ni de bande passante mesurée ici.

## Activité GPU : compositeur dominant

Les exécutions couvrent t=**0,329195833 à 9,618694375 s**, soit **9,289498542 s**. Leur union est **3,021758769 s Active**, soit **32,5288 % du temps couvert** et **31,3873 % de la capture entière**. Les 0,337845351 s sans données ne doivent pas être présentées comme Idle.

| Processus des exécutions | Intervalles | Union GPU | Part de la durée totale de capture |
|---|---:|---:|---:|
| `backboardd (70)` | 138 870 | **2 994,347 ms** | 31,10 % |
| `Woop (17148)` | 973 | **41,118 ms** | 0,427 % |
| Non attribué | 303 | 8,077 ms | 0,084 % |

Cela établit que **la majeure partie du travail GPU de cet écran est effectuée dans le compositeur**, plutôt que sous le seul PID Woop. `backboardd` compose aussi d’autres éléments système : cette attribution processus ne permet pas d’accuser une vue de l’app ni d’imputer tout ce temps exclusivement à Woop.

Canaux, unions non additives : Fragment **2 871,137 ms**, Vertex **358,487 ms**, Compute **32,297 ms**. Les 140 146 lignes sont toutes `Active`; profondeur 0 : 137 950, profondeur 1 : 2 184, profondeur 2 : 12. La durée d’une ligne va de 1,625 µs à **1,474 ms**. Additionner naïvement toutes les durées donnerait 3 279,223 ms et surestimerait l’activité.

Contre-vérification indépendante : l’union des périodes étiquetées Active dans la table d’états redonne **exactement 3,021758769 s**, à la ns près. Après traitement de 184,996 µs de conflit Active/Idle, il reste Active exclusif **3,021573773 s**, Idle exclusif **6,267739773 s** : environ **32,53 % / 67,47 %** du temps couvert.

## Présentation : retard réel dans la trace, GPU au repos pendant l’essentiel

La surface 121 reste affichée de **t=6,039154875 à 7,919590416**, soit **1 880,436 ms**. Au même endroit, le GPU reste continûment Idle de **6,171038125 à 7,878980208**, soit **1 707,942 ms**. La présentation suivante attribuée à Woop (frame 341, surface app 713) porte une latence **CPU→display de 1 793,130 ms**.

Un autre maintien de surface dure **499,259 ms**, de t=1,196589583 à 1,695848541. Ces deux longues durées n’ont pas de latence CPU→display renseignée sur leur propre ligne ; les valeurs citées proviennent des lignes suivantes quand disponibles.

| Seconde relative | Échanges de surfaces, table dédiée | Temps GPU Active, union des exécutions |
|---|---:|---:|
| 1–2 | 23 | 353,143 ms |
| 2–3 | 30 | 422,641 ms |
| 3–4 | 41 | 425,752 ms |
| 4–5 | 38 | 412,642 ms |
| 5–6 | 42 | 438,288 ms |
| 6–7 | **2** | **73,580 ms** |
| 7–8 | **3** | **36,188 ms** |
| 8–9 | 33 | 345,122 ms |

Ce sont des échanges de surfaces mesurés, pas les callbacks CADisplayLink. Une surface immobile peut être réutilisée sans nouvel échange ; la table ne mesure pas à elle seule la fluidité perçue d’une vue censée rester immobile. Ici, la très grande latence CPU→display est un indice distinct d’un retard de présentation.

Sur les 262 intervalles affichés : médiane **33,276 ms**, p95 **49,920 ms**, maximum **1 880,436 ms** ; 247 lignes nomment Woop. Les 247 latences CPU→display disponibles ont médiane **49,287 ms**, p95 **66,378 ms**, maximum **1 793,130 ms**. Toutes les lignes indiquent `direct-to-display=0` ; leurs raisons de non-présentation directe ne sont pas renseignées.

Les latences CPU→GPU des exécutions sont beaucoup plus courtes :

| Processus | Médiane | p95 | Maximum |
|---|---:|---:|---:|
| Woop, 973 valeurs | 0,612 ms | 9,115 ms | **19,105 ms** |
| backboardd, 138 870 valeurs | 2,620 ms | 5,628 ms | **11,914 ms** |

**Le long incident de cette capture n’est pas une plage de calcul GPU continu à saturation.** Son origine exacte reste indéterminée : travail CPU, ordonnanceur, synchronisation, pipeline de présentation ou perturbation de mesure nécessitent des données complémentaires. Une latence d’exécution GPU courte n’exclut pas une attente ailleurs dans le pipeline.

## Surfaces réellement utilisées

Les libellés d’accès GPU montrent notamment :

| Surface | Dimensions exportées | Accès observés |
|---|---|---:|
| 514 / 121 / 441 | **1179×2556** | 7 266 / 6 044 / 5 777 intervalles mentionnant une écriture |
| 659 | **1080×2348** | 283 intervalles mentionnant une lecture |
| 668 | **1206×964** | 283 lectures |
| 671 | **604×642** | 283 lectures |
| 713 | **256×256** | 280 lectures |

Les dimensions 1206×964 et 604×642 correspondent aux deux sources vidéo locales auditées auparavant. **Relire une texture ne prouve pas que son lecteur vidéo continue à décoder ou avancer** : une pose peut rester dans un IOSurface, puis être recomposée à chaque changement d’un autre élément. La trace seule n’identifie pas le rôle exact des surfaces 659/713, ni quel masque ou verre déclenche leur réutilisation. Le temps d’un intervalle mentionnant un accès n’est pas le coût exclusif de cet accès.

## État de performance et portée

Les états de performance renseignent Maximum **5,025256491 s**, Medium **2,178017084 s**, Minimum **0,386098958 s**, sur seulement **7,589372533 s** couvertes. La plage Idle de 1,708 s est intégralement étiquetée **Maximum** : cet état ne signifie donc pas « GPU occupé à 100 % ». La table porte `is-induced=1` et « due to active device conditions », tandis que les réglages annoncent `Induced GPU Performance State: Default` ; elle ne donne aucune fréquence MHz ni plafond thermique permettant de quantifier un bridage.

La mesure montre **une composition GPU persistante même sous protection**, et un retard d’affichage durant lequel le GPU est largement Idle. Elle ne suffit pas à nommer le décor responsable, à mesurer l’énergie consommée ou à valider une baisse durable de température. Elle justifie une comparaison du même écran avec une seule source d’animation isolée, en conservant la présentation, les états thermiques et les attentes comme mesures distinctes.

## Artefacts reproductibles

- Parseur id/ref : `/private/tmp/woop-metal8-parse.py` ; calculs d’unions : `/private/tmp/woop-metal8-analyse.py`.
- Exports GPU et présentation : `/private/tmp/woop-metal8-gpu-intervals.xml`, `/private/tmp/woop-metal8-display-waits.xml`, `/private/tmp/woop-metal8-surfaces-per-second.xml`, `/private/tmp/woop-metal8-compositor-events.xml`.
- Tables résolues : `/private/tmp/woop-metal8-gpu-intervals.json`, `/private/tmp/woop-metal8-display-waits.json` ; résultats détaillés `/private/tmp/woop-metal8-quantitative.txt`.
- Analyse indépendante des quatre tables d’états : `/private/tmp/woop-metal8-state-analysis.md`, scripts et JSON voisins.

Aucun changement de code, build, lancement ou geste sur l’appareil pendant cette analyse.
