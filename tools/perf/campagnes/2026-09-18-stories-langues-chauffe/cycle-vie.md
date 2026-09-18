# Arrêt du booster au relais et au démontage

La scène3D et les horloges du résultat suivent l’arrière-plan. Le relais à la
carte détache la scène masquée et coupe ses liens de rendu/gyroscope. Le
démontage devient définitif : les rappels tardifs ne réarment pas les moteurs.

Release73 installée le18-09 : parcours stories→booster→accueil PASS220,326s ;
carrousel interrompu puis repris PASS17,868s. Compteur SceneKit stable546
après relais, aucune vue3D dans115 états après fermeture. CPU accueil médian5%
avant et après ; thermique1 avant les stories, puis1 jusqu’au bout, en charge.
Cette preuve valide l’arrêt des moteurs testés, pas une disparition de la chauffe.

Le18-09, Kathryn signale de nouveau une forte chauffe sur75 après séance,
manège, carte et Profil. Une correction complémentaire du cycle haptique est
en préparation76 ; elle n’est pas comprise dans ce commit ni déclarée validée.
