# Banc 25 — vérifier la Home réellement découverte

**Pas de nouveau gain de chauffe déclaré.** Même protection de décor que24.
Les bancs23/24 ne vérifiaient pas les fenêtres au-dessus de la Home. Le test
Home prêt de 16:07 a explicitement touché Later avant sa capture : elle ne
pouvait pas prouver l'absence de Welcome back pendant la mesure précédente.
Les journaux23/24 portent aussi une pièce de rayon12, présente dans le bouton
Claim de RewardCard. Cette lacune invalide l'attribution des anciens chiffres
à la Home seule ; conserver les données et cette réserve sans les effacer.

Le banc 25 ferme Welcome back au départ comme le bouton Later, sans Claim,
puis vérifie son absence et celle de la première arrivée, de la porte, du
manège et des autres contextes déjà exclus. Une apparition ultérieure
interrompt la mesure. Les champs welcome/premiere sont écrits chaque seconde.
Une capture de la fenêtre de Woop est prise après chaque changement de phase,
avant les10–15 secondes exclues. Six captures attendues, y compris les deux
phases complètes et le noir. Les numéros de fichiers sont consignés dans nav.

Release 25 lancée vers 16:19:45. Les captures ajoutent un travail ponctuel en
transition : elles ne sont pas dans les fenêtres stables analysées. La
compilation, l'installation et les chiffres25 sont encore à vérifier.

## Installation et lancement confirmés

Release 25 BUILD SUCCEEDED, UUID **C31237ED-8388-3D9D-B15B-33CC54ED680B**.
Installation16:22:49, conteneur `55948157-D5CC-4521-8482-E87F140EB639`,
databaseSequenceNumber5388. Lancement16:22:51 confirmé, enchaîné directement
après l'installation pour éviter le verrouillage entre les deux opérations.
Le parcours Home → Exercices → Home → Profil → Réglages était repassé sur 24
à 16:20:50 en 8,973 s, sans déconnexion, Claim ou suppression.

## Banc complet vérifié, collecte à 16:25:59

Vol `vol-20260915-162256.jsonl` : 164 lignes. Nav `nav-20260915-162251.jsonl` :
183 lignes. Six phases, six captures enregistrées, restauration complète et
arrêt de sonde à 16:25:43,874. Au premier plan et écran éveillé. Les champs
`welcome=0` et `premiere=0` sont présents pendant toute la mesure. Aucun
événement Later dans ce lancement : le panneau n'était pas ouvert, la garde
a confirmé son absence. Aucun Claim ni autre changement de compte.

| Phase | n stable | CPU médian | Callbacks/s | Plus grand intervalle | Thermique/protection |
|---|---:|---:|---:|---:|---|
| Complète initiale | 20 | 1 % | 60,1 | 33 ms | 1 / 1 |
| Sans widgets | 16 | 1 % | 60,1 | 17 ms | 1 / 1 |
| Sans Route | 16 | 1 % | 60,1 | 17 ms | 1 / 1 |
| Fond seul | 16 | 1 % | 60,1 | 17 ms | 1 / 1 |
| Nu | 15 | 1 % | 60,0 | 17 ms | 1 / 1 |
| Complète finale | 16 | 1 % | 60,1 | 17 ms | 1 / 1 |

15 s de préparation exclues au départ, 10 s aux transitions, captures avant
ces exclusions. Aucun gel marqué. CPU = charge récente Mach ; callbacks =
service du main, pas cadence GPU. La protection est active : l'ambiance est
posée. **Cette mesure valide un coût faible de la Home protégée sur ce passage,
pas le coût du rendu animé à froid ni une température physique.** Pas de
comparaison causale en pourcentage avec les bancs23/24 non certifiés.

[Capture initiale réellement lue](home-initiale.png) : vraie Home complète,
phrase, deux widgets, Route, pièce, invite et navigation visibles, aucun
panneau de bienvenue. Six noms de captures sont dans nav. À 16:27, récupération
des cinq autres bloquée : CoreDevice 1011 puis aucun iPhone dans IOUSB. Les
fichiers restent dans les Documents de Woop ; pas de nouveau banc à lancer
pour les récupérer.

La sonde est arrêtée et le maintien éveillé demandé reprend pour 30 minutes
(après quoi la veille normale revient). Un retour utilisateur sur la chauffe
et la navigation a été demandé après ce banc. QA04 reste KO en attendant la
validation d'usage et du comportement à froid. QA07 conserve le PASS24 de
16:20:50. Le cycle complet du compte n'a pas été exécuté.

Documentation locale régénérée, puis `npm run verif` PASS ; journaux joints.
Liens du registre et du relevé vérifiés, `git diff --check` PASS. Aucun commit.
Le lien Artifact externe n’a pas été republié : outil absent. À 16:29:49,
IOUSB ne voit aucun iPhone et CoreDevice indique unavailable. Reconnexion
demandée pour les captures restantes, la navigation25 et la mesure à froid ;
aucun nouveau lancement tenté sans l’appareil.

À la reprise de 19:45, captures Nu et Complète finale récupérées puis lues :
les suppressions et la restauration annoncées sont visibles, sans fenêtre
couvrante. Voir [Nu](nu.png) et [Home finale](home-finale.png).
