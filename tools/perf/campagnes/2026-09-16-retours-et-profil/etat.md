# Retours des textes et nouvelle mesure de chauffe — 16 septembre 2026

## État au 16-09, 12:40

**42 est installée et lancée ; la charge continue de la Home noire a baissé.**
Comparaison natif/ancien/natif dans le même binaire, toutes les animations
permises, thermique0/protection0 : **3 % → 20 % → 3 % CPU médians**, soit environ
85 % de charge CPU en moins. Les trois fenêtres gardent60,1 callbacks/s et un
pire intervalle17ms. Ce sont des mesures du processus, pas des watts.

Les retours des deux Homes sont vérifiés sur39/41. **La chauffe durable reste
ouverte** : l’endurance42 a été interrompue par un appel puis une app inactive ;
le test du palier5min est arrêté, et une fenêtre inactive ne compte pas comme
une séance fluide. Le lancement initialLocked a été résolu après déverrouillage.

Téléphone : iPhone15, iOS26.6.1, câble branché ; l’icône de charge est visible.
La sonde conserve CPU, callbacks et catégorie thermique, pas watts ni degrés.
Le banc `-homeSeance` affiche la Home noire sans créer de séance ; son champ
`seance=0` doit être interprété avec les arguments et les captures.

## Comportement des textes

- Un sac par langue/état choisit une variante différente à chaque visite réelle.
  Les recalculs de vue ne relancent pas le texte ; les paliers cachés ne sont
  ni tirés ni rejoués au retour.
- Le compteur de minutes se recale sur l’instant réel de la séance, avec un
  réveil à la prochaine minute seulement quand la Home est visible. La phrase
  se renouvelle toutes les cinq minutes écoulées pendant cette visibilité.
- `ParoleLigne` conserve les mots, le flou12→0, le mouvement de5pt et l’haptique
  soft du phrasé onboarding. La nouvelle clé de visite masque les mots dès leur
  première image ; aucun flash de texte complet avant l’animation.
- Visibilité, sélection et autorisation d’animer sont séparées. Reduce Motion
  et la protection serious ne doivent pas faire disparaître le texte ni bloquer
  le nouveau choix au retour. Le backend et les lots03 ne sont pas redéployés.

### Preuves

| Contrôle | Résultat |
|---|---|
| Modèle Swift réel | FR/EN, vrais nombres/prénom, sacs sans répétition ; zéro tirage caché, retour unique après plusieurs paliers et absence de rejeu par recalcul : PASS. |
| Rouge39 : Home→Exercices→Home→Profil→Home | PASS21,732s. Trois formulations différentes, même total5. Captures de flou progressif et texte net conservées. |
| Noire40, téléphone serious | ÉCHEC : la protection bloquait encore le renouvellement. Le même texte persistait au retour. |
| Noire41 : même parcours | PASS27,896s. Trois formulations différentes, toutes au compteur3min. |
| Formulation au palier visible de5min | Logique testée dans le modèle ; la capture4min seule ne valide pas le passage réel à5min. À compléter sans réactivation parasite. |
| Haptique ressentie | Non confirmée par l’utilisateur. Le test automatisé ne peut pas la sentir. |

Les parcours n’ont appuyé ni sur Claim, ni sur suppression/déconnexion, ni sur
un bouton de début/fin de séance. Les tests noirs utilisent le banc sans données.

## Mesures et essais

| Écran et fenêtre | CPU médian | Contexte / portée |
|---|---:|---|
| Rouge39, t150,8–226,9, 76 lignes | 1 % | thermique2/protection1 ; 60,1 callbacks/s, pire31ms. Écran dégagé mais protégé. |
| Rouge39 après retours, t280,7–330,5, 50 lignes | 1 % | thermique1/protection1 ; 60,1 callbacks/s, pire17ms. |
| Profil40, panneau booster dégagé, t135,1–158,4, 24 lignes | 41,5 % | thermique1/protection1 ; SceneKit30rendus/s. Prototype de balancement natif, sans gain établi. |
| Noire40, t248,7–368,5, 119 lignes | 21 % | thermique0/protection0, Home visible : charge permanente encore trop élevée. |
| Noire41 avec seul fond natif, derniers30s avant t168,7 | 19,5 % | thermique0/protection0 ; amélioration insuffisante. Fenêtre indicative avant comparaison à binaire constant. |
| Noire42 native, t90,4–195,9, 105 lignes | 3 % | thermique0/protection0 ; aucun gel,60,1 callbacks/s, pire17ms. |
| Noire42 anciens moteurs, t20,7–51,2, 31 lignes | 20 % | Même binaire,3 drapeaux des anciens moteurs ; thermique0/protection0,60,1 callbacks/s, pire17ms. |
| Noire42 retour natif, t20,3–44,7, 25 lignes | 3 % | thermique0/protection0,60,1 callbacks/s, pire17ms. Fenêtre suivante interrompue. |

Les catégories thermiques identiques ne prouvent pas des fréquences identiques.
Le CPU ne mesure ni le GPU ni la puissance. Aucun de ces essais ne valide une
longue séance sans chauffe. La hausse jusqu’à serious sous Welcome Back est
conservée ; le stress a été suspendu pour observer la récupération sur Home.

### Trace SwiftUI noire40

Enregistrement `SwiftUI`, attaché au PID vivant,12s demandées. La table exportée
est conservée compressée dans `trace40-updates.xml.gz`, son inventaire et son
résumé à côté. Après2s :96 337 mises à jour, dominées en nombre par cadres,
opacités, flous et Canvas. Les vues créées avant l’attache sont nommées
« unknown view » par Instruments : **cela n’attribue pas chaque coût à une vue**.
La trace ne sert pas de mesure CPU et son acquisition est exclue d’un A/B.
Trace brute locale : `/private/tmp/woop-noire40-trace/noire40.trace`.

### Prototypes conservés et limites d’automatisation

1. La référence38 est quittée hors protocole : profil/panneau booster à la place
   de la Home. L’assertion du boutonperson échoue ; ce n’est pas un gel de navigation.
2. Les premiers relevés après relance sont sous Welcome Back. Ils sont exclus.
   Pour le panneau40, la bienvenue apparaît après la vérification initiale du
   runner : la comparaison est invalide. Le runner attend désormais jusqu’à6s
   cette présentation asynchrone avant de fermer seulement Later.
3. Le balancement du booster40 transféré à Core Animation ne donne pas de gain
   établi. Il est retiré du code ; patch et hunk conservés ici. Aucun diagnostic
   GPU ne peut être déduit de son CPU41,5 %.
4. La première préparation d’archive refuse un compte de hunks incorrect avant
   toute écriture. Reprise après lecture du diff ; changements étrangers préservés.
5. Le test noir40 expose le couplage sélection/protection. Corrigé41 puis testé.
6. Après installation42, lancementLocked et `passcodeRequired:true`. La capture
   copiée ensuite provenait encore de41 (horloge12:09), **pas de42** ; elle ne sert
   pas de preuve42. Déverrouillage demandé pendant le travail indépendant.

## Moteurs42 mesurés

Le fond conserve sa bande cuite, son rideau et ses voiles. Les braises reprennent
les neuf colonnes, mêmes couleurs et deux sinus ; le raccord mathématique est
17 périodes du premier sinus =10 du second. Hauteur et opacité sont confiées à
Core Animation. Les silhouettes gardent leur dessin SwiftUI, rendu en image à
leur configuration puis déplacé nativement. Les moteurs se coupent hors fenêtre,
au démontage, et selon la visibilité. Les anciennes versions restent accessibles
par `-foyerFondSwiftUI`, `-foyerBraisesSwiftUI`, `-foyerDallesSwiftUI` pour comparer
le même binaire et le même dessin. Le profil n’utilise plus le prototype40.

Comparaison courte réalisée ; captures42 hors appel conservées. Les premiers
instants avec le bandeau d’appel sont exclus et la capture montrant le nom du
contact n’est pas archivée dans le dépôt. La seconde séquence s’interrompt :
`applicationState=1`, journal arrêté après56,4s, Welcome Back présent à la fin.
Le runner trouve encore des éléments d’accessibilité sous cette couverture,
ce qui ne valide pas une Home visible. Test palier arrêté, nouvelle disponibilité
demandée sans toucher à l’appel.

Suite : vérifier le palier sans réactivation parasite, puis plusieurs minutes
normales et retours de pages, sans interruption extérieure.
À12:27, la restauration attendait la fin de l’interruption. À12:39, nettoyage
réussi sans ramener Woop devant l’utilisateur : `--no-activate`, `-sansSondeVol`,
`-ecranEveille`, `-openTab home`, sans le banc de séance. CoreDevice confirme
`activatedWhenStarted:false` et la préférence relue vaut `woop.sondeVol:false`.
Le retour normal est préparé ; aucun contrôle visuel après cette relance discrète.

## Fin de contrôle documentaire

Le premier vérificateur refuse un titre de65 caractères (limite60). Titre
raccourci. La deuxième passe valide23 tests et le livrable identique, puis
Chrome ne démarre pas dans le bac à sable ; reprise avec le droit de lancement.
Le journal du test palier interrompu termine sur une erreur d’écriture du
xcresult incomplet : aucun succès palier ne doit en être déduit.

À12:34, collecte seule, sans activer l’app : reprise brève après399s sans lignes,
puis `scene-background` / `applicationState=2`. Trois nouvelles lignes ne
transforment pas cet intervalle en endurance. Les journaux sont conservés ; nettoyage discret réalisé ensuite, décrit ci-dessus.

Contrôle documentaire final : PASS16s,23 tests ; artefact identique au build,
largeurs vérifiées sur les neuf pages. Capture390 relue. Source et HTML autonome
régénérés ; le lien externe Claude ne peut pas être republié avec les outils
de cette session. Le site local reste la référence : http://localhost:3111.

Le premier index isolé refuse de se préparer car une autre session a commité
entre-temps. Aucune mutation ; copie documentaire actualisée sur8c628ba,
artefact isolé régénéré. Les sources et l’index des autres travaux sont préservés.
