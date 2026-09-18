# Mini-check du bouton Ouvrir —18-09

À la demande de Kathryn, contrôle réduit pour limiter le coût. Un seul test
sur le simulateur Cartes, binaire Debug déjà installé ; aucune nouvelle
compilation de l’app, aucun accès au téléphone, aucun correctif appliqué.

Compte QA isolé :3orange/3noirs. Depuis Profil, entrée orange, bouton Ouvrir
touché par coordonnées : sonde du manège toujours absente après10secondes.
Même échec reproduit en22,557s. La capture après appui est noire ; aucun
sachet consommé ni carte attribuée (stocks3/3 conservés). Voir mini-check.log,
etat-apres.json et apres-ouvrir.png. Le hit-testing reste une hypothèse :
la capture ne permet pas de distinguer geste, présentation ou démarrage du manège.
Piste locale : PiedCoffre.bouton désactive le hit-testing du primaire et lui
laisse une action vide, en comptant sur un geste prioritaire. La correction
reste à tester ; ce contrôle ne démontre pas encore la cause définitive.

Compte temporaire et jetons nettoyés, simulateur arrêté. Le blocage existant
reste rouge dans la documentation ; aucune nouvelle validation globale.

## Reprise ciblée

Reproduire le passage Profil → coffre orange → Ouvrir, puis distinguer la
fermeture du cover, SacreEtat.manegeOuvert et le montage de BoosterLab.
La hiérarchie après l’échec contient encore les éléments du Profil ; l’écran
noir juste après le tap ne prouve donc pas à lui seul un bouton inactif.
Tester la correction sur orange puis noir avant de fermer le blocage QA.
Ne pas relancer les campagnes backend/chauffe pour ce diagnostic initial.
Les comptes QA précédents sont supprimés : recréer une fixture isolée.
