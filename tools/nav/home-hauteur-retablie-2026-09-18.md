# Home — retour à la hauteur précédente, 18 septembre 2026

Kathryn préfère les textes des deux Homes et la lune de la Home normale
à leur position initiale, plus basse que les chevrons des autres pages.

- Texte Home normale :48pt sous la zone sûre, dans `HomeNuit.swift`.
- Texte Home noire :48pt, via `FoyerGeo.phraseHaut` dans `Foyer.swift`.
- Lune Home normale :43pt sous la zone sûre.
- Trajet et fondu du texte de départ : formules antérieures rétablies.

Les chevrons des autres pages et la navigation Route restent inchangés.

## Portée du commit

La remontée était encore non committée. Son annulation rétablit les valeurs
déjà présentes dans Git : ce commit enregistre uniquement le choix ci-dessus.
Les autres changements en cours, notamment la progression dans HomeNuit,
restent aux sessions concernées. Aucun fichier Swift ni livrable partagé
n’est ajouté à ce commit.

## Vérification

Analyse syntaxique Swift réussie sur HomeNuit.swift et Foyer.swift.
Au retour de hauteur, les deux fichiers correspondaient octet par octet
aux sources committées précédant l’alignement. Les contrôles documentaires
en copie privée ont passé23 tests ; la documentation partagée conserve
le choix et les ajouts des autres sessions. Aucun nouveau contrôle visuel,
aucune compilation complète de l’app ni installation iPhone dans cette passe.
