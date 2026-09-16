# Halo52 — la séance se voit vivre hors Home

À la demande de Kathryn, le fond rouge/noir de l’île pulse plus franchement
sur les pages hors Home : période dominante2,4s, modulation4,1s, contraste
renforcé entre les deux textures et reflets blancs. La Home noire conserve
exactement le halo blanc51. Géométrie, chrono, stop et gestes inchangés.
Le compositeur anime toujours deux textures ; aucune horloge SwiftUI ajoutée.
Pause thermique, Reduce Motion, arrière-plan et couverture du détail conservés.
`-ileHaloDiscret` conserve le témoin natif51 ; `-sansSouffleIle` fige le décor.

Release52 compilée, signature vérifiée, installée et version relue18:03:00.
Le parcours tactile physique passe en50,175s : présence, tap, déplacement,
jet, sortie au drag et détail. Captures `iphone-halo52-vif.png` et
`iphone-halo52-creux.png` relues ; elles montrent le composant de démonstration,
pas la Home réelle. Kathryn valide le rendu et demande le commit.

Mesure sur iPhone15 par câble, protections actives, therm0/protection0 :
17 lignes t15,2–31,5 (16,3s), CPU médian1 %,60,1 callbacks/s, pire17ms.
Données : `woop-ile52-vif-vol.jsonl`, résumé `mesure52.json`. Les champs Home
par défaut du lab ne décrivent pas une Home réelle. Pas de mesure GPU,
watts ni chauffe durable ; pas de nouvelle comparaison A/B52 exécutée.
Retour normal par `-sansSondeVol` réussi18:06:20, sans relancer de banc.

L’export initial groupant télémétrie et captures a été refusé par la revue
automatique. Après lecture de `SondeVol.swift:269–298` et de `PiluleLab`,
le contenu est établi : métriques techniques et données de démonstration,
aucune identité ni donnée d’entraînement du compte. Les deux exports ciblés
sont ensuite autorisés et réussissent. Aucun contournement ni export du compte.

## Périmètre du commit

Sélection par chemins et hunks, depuis HEAD fc06e4b : île au premier plan,
Live Activity, lien de reprise, renderer transmis et gestes intégrés,
banc ciblé et preuves de cette campagne. Les autres changements du dépôt
restent hors index, notamment compte/auth, cardio, coffre et pages.
Le garde du retour natif utilise les états d’onboarding existants dans HEAD ;
la variante liée au film autonome non commité reste dans le fichier partagé.

Le montage du banc depuis ce seul candidat réussit. Sa compilation bloque
sur `HomeAuroraView.swift:196`, qui appelle `VolDePieces` : référence déjà
présente dans HEAD, aucune définition suivie par Git. Le fichier est inchangé
par cette session. Le build du contenu exact du commit n’est donc pas validé ;
la Release52 de l’arbre partagé et le parcours iPhone, eux, passent.
Journal complet : `woop-ile52-selection-build.log`. Aucun correctif étranger
n’est ajouté pour masquer cette limite. Les tests simulateur51 et natifs50
restent leurs preuves datées, sans être attribués au candidat52 isolé.
