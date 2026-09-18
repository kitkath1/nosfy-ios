# Route sans menu inférieur

La Home montée sous Route continuait à demander la barre de navigation.
La racine masque maintenant cette barre pendant depart.cheminOuvert ;
au retour, la demande de la page redevient effective.

Simulateur75 : parcours Route→retour→Exercices réussi. Les trois boutons
du menu sont absents de Route et Entraînements est accessible après retour.
Deux tests du banc Home/Route PASS59,919s au total. Captures route-sans-menu
et navigation-apres-route relues. Release75 puis76 installées ; aucun parcours
physique Route dédié ni verdict thermique déduit de cette preuve simulée.
Aucune séance ni récompense créée pour ce test.

La demande de remonter les en-têtes Home a ensuite été annulée par Kathryn
le18-09 dans la session dédiée. Valeurs48pt/43pt et trajectoire précédentes
conservées. Ce commit ne réintroduit pas cet alignement.
