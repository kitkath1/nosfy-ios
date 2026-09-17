# Invitation exercice, Profil blanc et panneau Start — 17 septembre2026

## Portée

Suite au départ vidéo57 confirmé par Kathryn et commité séparément en
`7c6d2bd`. La vidéo et ses preuves ont été commitées séparément. La suite est
autorisée au commit par Kathryn le17-09 (« commit le reste »). La session backend/story est indépendante.

- Après la fin ou le passage du film : une carte réelle dans la brume de la
  visite Home, « Choisissez un exercice » / « Choose an exercise », Passer / Skip.
  La langue vient du cache d’onboarding `Langue`, sans requête supplémentaire.
- Un nouveau Start rejoue l’invitation ; revenir simplement dans l’onglet ne
  la rejoue pas. Mode cards/liste conservé. Une recherche vide et un ancien
  détail ne doivent pas cacher l’exercice proposé.
- Le temps Profil de la visite allume le vrai glyphe en blanc : UIImage fixe,
  opacité Core Animation, aucun `TimelineView` ajouté ni boucle SwiftUI.
  Arrière-plan, onglet couvert, Reduce Motion et protection thermique arrêtent
  l’animation ; le glyph reste blanc fixe. Démontage : animation retirée.
  Barreau `-sansAppelProfilVisite`.
- Route avait une attente explicite de2,1s avant Start, puis jusqu’à quatre
  reprises de0,5s. Le panneau est désormais posé à la naissance avec le galet
  courant ; l’ouverture tactile prend0,26s. La date et l’étape sont déjà
  locales : aucun appel serveur ni loader artificiel requis pour ce panneau.

## Coût et validation

L’ancien guide Exercices redessinait deux fenêtres dans un `TimelineView`.
Il est remplacé par une brume à géométrie fixe et un phrasé d’entrée fini.
Le fond vidéo Exercices passe à sa pose pendant l’invitation ; il reprend
après. L’ancre n’est publiée que pendant le guide. Aucune preuve d’énergie
ou de chauffe durable n’est déduite du simulateur ou de ces choix de code.

Compilation et parcours sur copie isolée `/tmp/woop-count53/banc` ; aucun
lancement iPhone pendant les builds. Simulateur réservé :
`6A504B5A-F76C-4EC1-B09A-E9CA4673B32A`. Tests `VisiteDepartUITests`,
`-sansServeur` ; aucune nouvelle campagne d’écriture backend nécessaire.

Premier build refusé : identifiant d’accessibilité du mode liste référençait
un nom hors portée. Une première reprise compilait encore le mauvais nom `ex` ; correction finale
sur `rc.exercise.id`, puis Release simulateur58 réussie.
Résultats et captures consignés ci-dessous.

## Premier parcours58 au simulateur

Tests1–3 réussis : départ réel sans countProbe → vidéo → invitation FR →
Passer et aller-retour d’onglet27,385s ; invitation EN → vraie fiche15,904s ;
mode liste11,029s. Captures exportées et lues : la vraie carte reste visible,
le texte de la visite et le lien Passer sont présents.

Test4 échoué19,668s : aucune visite Home montée. Relance au journal console :
pas d’entrée `visite-home` malgré le banc demandé ; capture Home immobile avec
séance locale ouverte. Le montage conditionnel lisait l’état depuis la closure
`overlayPreferenceValue`. Nouveau `VisiteHomeHote` permanent dans cette closure :
son `body` observe l’ouverture et les ancres ; le guide se monte indépendamment
d’un nouveau mouvement géométrique. Le second banc ne contient plus la sonde
countProbe, pour éviter qu’une lecture parasite masque ce défaut.

La reprise avec cet hôte seul échoue19,316s ; la remise du simulateur en Home
sans séance échoue18,724s aussi. Ce n’était donc pas seulement un mauvais
contexte de banc. Trace suivante : `visite=true`, aucun `visite-home` monté.
Le jeu d’ancres à la racine reste vide à travers l’hôte de l’onglet. Ajout d’un
relevé de cadres globaux sur les vrais éléments, uniquement pendant la visite
et sur l’onglet visible ; géométrie inchangée, aucune écriture périodique.
Le guide convertit ces cadres dans son repère, le doigt reste au même endroit.
Les tests sont explicitement réservés au simulateur ; `-fermeSeances` prépare
sa Home en retirant seulement les fixtures locales du banc, avec -sansServeur.
Aucune de ces préparations n’est lancée sur l’iPhone personnel.

Le livrable documentaire partagé a dépassé sa limite pendant cette tâche :
2051403octets contre2000000. Six captures de story sont arrivées en parallèle.
Leurs sources ne sont pas modifiées par cette session. Les contenus flow et
visite sont actualisés ; la livraison HTML complète attend un build accepté.

Le relevé seul n’a pas suffi : test4 encore rouge18,470s. Le montage a donc
quitté complètement `overlayPreferenceValue` : overlay indépendant, avec les
cadres réels publiés par les éléments pendant la visite. L’hôte conditionnel
est désormais toujours monté et observe l’ouverture. Le test5 ajoute le vrai
passage Commencer → progrès → Profil, au-delà du raccourci de banc vers Profil.
Les changements story arrivés dans WoopApp en parallèle ne sont ni retirés de
l’arbre ni recopiés par-dessus la copie de validation de cette session.


## Clôture58 — 10:09 Paris

Le montage final montre le glyphe Profil blanc et le tap ouvre effectivement
Profil. Un premier essai final échouait seulement sur l’assertion du banc :
la page Profil ne conserve pas le bouton de navigation Profil. Assertion
corrigée pour reconnaître son bouton Réglages ; aucun changement app associé.
Les deux derniers parcours passent : Profil direct11,645s ; Commencer →
progrès → Profil12,209s. Les trois parcours Exercices passaient déjà ; pas de
nouvelle modification de leur implémentation après cette validation.

Build Release appareil58 réussi, version57 relue avant installation, version58
installée à10:08 puis relue par devicectl. Aucun lancement sur l’iPhone pendant
cette campagne, aucun effacement de ses données ni séance créée. Le coût et
la chauffe durable de58 restent à mesurer sur appareil. Les captures du
simulateur prouvent le rendu et les tests prouvent les taps, pas ce coût.

Les empreintes de sources58.json viennent de la copie réellement compilée
`/tmp/woop-ile48-propre-prod`, pas de l’arbre partagé modifié en parallèle.
Le manifeste ne prétend pas que tout le dépôt partagé a été validé.

Documentation : schéma flow-1 rendu, typecheck et neuf tests de contenu verts.
Les sources flow et visite sont à jour. L’export HTML partagé a échoué à
2051403octets (>2000000) : index.html conserve donc le livrable57 déjà commité.
Les captures story de l’autre session sont laissées intactes. Le lien externe
n’a pas été republié. Cette suite tutorial/Start reste non commitée ; le commit
vidéo seul est 7c6d2bd.


## Livraison du commit et rejeu demandé — 10:14 Paris

L’export du seul contenu autorisé est construit sur HEAD + les hunks de cette
session dans `/tmp/woop-tuto58-commit/snapshot`. Il pèse1994506octets et passe
la limite2Mo sans toucher aux captures story du travail parallèle. Le livrable
commité correspond à ces sources sélectionnées ; les sources story non
commitées restent dans le dépôt partagé et ne sont pas incluses dans ce HTML.
Le premier contrôle de cet export isolé a échoué sur les liens vers
`docs/screens` absents de la copie : liens ajoutés, reprise du contrôle.

À sa demande, iPhone déverrouillé et version58 relue : lancement unique avec
`-sansSondeVol -openTab home -visiteHome 1`, accepté par devicectl à10:14:16.
Ce mode rejoue la visite Home, sans refaire Sign in with Apple ni effacer
les données. Le banc ne marque pas la visite au serveur. Le lancement seul
ne prouve pas le rendu ; Kathryn teste la visite, puis Route → Start → vidéo
→ guide Exercices. Aucun Start automatique ni nouvelle mesure thermique.
À une prochaine ouverture normale sans ces arguments, le rejeu n’est plus
forcé. Les données et la langue d’onboarding restent celles de son compte.

Contrôle final du livrable sélectionné : `npm run verif` intégral réussi
en16s (types, contenu, reconstruction identique, invariants, captures et
largeur390 des dix pages). Captures État mobile et Compte desktop relues.
Le HTML accompagne les sources sélectionnées dans ce commit ; publication
au lien externe toujours indisponible dans cette session.
