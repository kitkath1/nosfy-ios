# Build 20 : le fond unique n'a pas été exercé

Installation réussie le 15-09 à 11:56:33, UUID DCB73D15-7450-38A1-B527-4775B4B27CC7.
Premier lancement refusé par le verrouillage. Lancement effectif à 11:57:52.
Le diagnostic `fond-precompose-repli` indique **393 × 709 pt**, alors que le
fichier de comparaison a été préparé pour 393 × 660 pt. La taille 660 provenait
du drawable Metal figé à son premier layout, pas des bounds du slot stabilisé.
Le garde de taille a correctement conservé les deux calques habituels.
**Aucune conclusion sur l'efficacité de la vidéo unique à partir de ce build.**

Une capture Time Profiler + Power Profiler est sauvée pour PID20238, mais son
export TOC échoue par signal11/code139. Elle ne fournit donc aucun chiffre
exploité ici. Le collecteur a copié le nav puis échoué sur une liste de sondages
périodiques vide (normal sans SondeVol) ; le fichier nav reste exploitable. Son
vol sélectionné était celui de 11:31:28, antérieur au banc : écarté.

Le script restaure la version normale à 11:58:55 et sa préparation Home passe.
Une deuxième tentative à 11:59:15 n'effectue aucun test : noms de resultBundle
réutilisés, code64 ; elle relance à nouveau l'app normale à 11:59:18. Pas de
capture concurrente ni de mesure à attribuer à cette tentative. À 12:00:48,
le mode écran éveillé sans compteurs est lancé à la demande de Kathryn.

Le build21 prépare le bon cadrage et allonge la veille QA à trente minutes,
non persistée. Le script de comparaison emploie des noms uniques et vérifie
le montage du fond unique avant d'enregistrer. L'endurance et le rendu restent
à mesurer sur le téléphone.
