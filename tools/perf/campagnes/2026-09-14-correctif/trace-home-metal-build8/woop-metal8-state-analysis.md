# Home build8 — état GPU et thermique

Trace : `/private/tmp/woop-home-build8-metal.trace`, iPhone 15/A16, app Woop pid 17148. Capture 2026-09-15 07:45:18.161→07:45:27.788 Europe/Paris ; durée exacte des lignes thermiques **9,627343893 s**. Contexte fourni : Home réelle, protection thermique active.

## Méthode

Export des quatre tables par `xcrun xctrace export`, analyse des `<row>` uniquement avec résolution complète des attributs `id/ref`. Temps bruts en nanosecondes. Analyse reproductible : `/private/tmp/woop-metal8-state-analyse.py` et `/private/tmp/woop-metal8-state-union.py`.

## Thermique

**Fair durant 100 % de la capture**, une ligne de t=0 à 9,627343893 s ; piste `Current`, `is-induced=0`. Aucun passage à Serious/Critical enregistré dans cette fenêtre.

## GPU A16 : activité globale du périphérique

**275 294 lignes** : 172 712 Active, 102 582 Idle. Couverture sans trou de t=0,329195833 à 9,618694375 s, soit **9,289498542 s** ; les 0,337845351 s restantes de la capture ne sont pas couvertes par cette table.

| État exclusif après union des intervalles | Durée | % couvert | % capture totale |
|---|---:|---:|---:|
| Active | 3.021573773 s | 32.5268 % | 31.3853 % |
| Idle | 6.267739773 s | 67.4712 % | 65.1035 % |
| Active,Idle | 0.000184996 s | 0.0020 % | 0.0019 % |

Le chevauchement contradictoire Active+Idle représente seulement **184,996 µs**. Les sommes naïves de lignes comptent en plus 79,084 µs de double couverture Active. L’occupation observée est donc **environ 32,53 % Active sur le temps couvert**, pas une activité GPU continue.

Plus longue plage Idle : **1,707942083 s**, de t=6,171038125 à 7,878980208 s. Deuxième : 181,487875 ms, de 1,488283750 à 1,669771625 s. Plus longue union Active continue : 2,671875 ms. Les lignes représentent de très nombreuses alternances brèves (durée médiane des lignes Active : 5,667 µs ; Idle : 17,042 µs).

| Fenêtre relative | Temps Active exclusif |
|---|---:|
| 1–2 s | 353.130 ms |
| 2–3 s | 422.628 ms |
| 3–4 s | 425.729 ms |
| 4–5 s | 412.629 ms |
| 5–6 s | 438.270 ms |
| 6–7 s | 73.580 ms |
| 7–8 s | 36.188 ms |
| 8–9 s | 345.095 ms |

## Performance GPU

**946 lignes** dans chacune des deux tables de performance. Correspondance vérifiée ligne à ligne des bornes et durées : `state=3 → Maximum`, `2 → Medium`, `1 → Minimum`. Accélérateur 835, `desired-state=0` sur toutes les lignes.

| État exporté | Lignes | Durée | % des durées renseignées | % capture totale |
|---|---:|---:|---:|---:|
| Maximum | 417 | 5.025256491 s | 66.214 % | 52.198 % |
| Medium | 405 | 2.178017084 s | 28.698 % | 22.623 % |
| Minimum | 124 | 0.386098958 s | 5.087 % | 4.010 % |

Total renseigné **7,589372533 s** (78,8314 % de la capture), de t=0,346727583 à 9,618813083 s avec **541 trous** ; plus grand trou interne 20,949333 ms. Ne pas extrapoler un état à ces trous.

La table lisible donne `is-induced=1` et le texte « GPU Performance state due to active device conditions » à toutes ces lignes, tandis que les réglages de capture disent `Induced GPU Performance State: Default`. Il faut conserver ces champs tels quels : cet export ne donne ni fréquence MHz ni plafond matériel disponible et ne prouve pas un bridage thermique. `Maximum` est un **état de performance**, pas un pourcentage d’occupation : il coexiste notamment avec le long intervalle GPU Idle.

## Portée et limites

- Tables GPU au niveau du périphérique A16 : elles n’ont **aucune colonne processus**. Ces 32,53 % ne sont pas attribuables à Woop seul ; les autres processus et la capture participent potentiellement au contexte.
- Fair est établi ; une saturation GPU permanente ou un GPU empêché de travailler par la chaleur n’est pas établi ici.
- La capture courte sous protection thermique ne reproduit pas à elle seule le scénario historique de gel sur téléphone Serious ; elle ne valide pas non plus une baisse de chauffe durable.
- Pour attribuer la charge à une vue/commande, corréler avec les intervalles GPU par processus, commandes et attentes du fil principal.

## Fichiers

- `/private/tmp/woop-metal8-state-device-thermal-state-intervals.xml`
- `/private/tmp/woop-metal8-state-gpu-performance-state-intervals.xml`
- `/private/tmp/woop-metal8-state-gpu-performance-device-state-intervals.xml`
- `/private/tmp/woop-metal8-state-metal-gpu-state-intervals.xml`
- `/private/tmp/woop-metal8-state-analysis.json`
- `/private/tmp/woop-metal8-state-union.json`
