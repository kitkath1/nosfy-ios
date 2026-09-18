# Trois familles — preuves documentaires du18-09

Validation en copie isolée, fondée sur le HEAD `b4d8a1eb504efd2e39f8c43c2d8ffd8e4ad7439d`.
`npm run artefact` puis `npm run verif` : PASS,23tests ; types, contenu,
reconstruction identique, autonomie et largeur des10pages contrôlés.
Le livrable autonome reste sous2Mo. Voir les deux journaux.

Galerie :3familles,14images intégrées et décodées, zéro débordement à390/1440.
Six captures relues : Forêt des Veilles, Cimes Éteintes, Bois Sans Lune.
Le contrôle visuel a porté sur ces aperçus ; la mise à jour de base b4d8a1eb
concerne une autre brique documentaire et ne change pas le composant galerie.
Les captures générales Etat/Compte du vérificateur sont également relues.
Le skill Cartes passe son validateur. Les14références sont uniques, les PNG
correspondent aux SHA-256 et restent non publiés. Sélection Bois : clairière v2,
aile/loup/corbeau v3 ; versions antérieures archivées, pas affichées comme sélection.

Aperçus AVIF de224px pour le document autonome. Originaux PNG1024×1536 intacts
sous `tools/carte-lune/`. Reproduction : depuis `docs/site`,
`node scripts/cartes.mjs`, puis `npm run artefact` et `npm run verif`.

Ces preuves valident la documentation, pas le backend ni le rendu iPhone.
Aucune écriture Supabase, génération nouvelle, installation, animation shiny
ou modification Swift pendant cette passe. Les nouveaux seuils de légendaire
sont une proposition non simulée et non déployée, consignée dans le plan.
