# Scellement des deux premières familles — 18 septembre 2026

Périmètre artistique : La Forêt des Veilles (quatre références) et Les Cimes
Éteintes (quatre créatures noir/orange validées, deux paysages communs ajoutés).
Noms FR/EN, prompts, empreintes, plan et skill conservés. Aucun appel applicatif,
aucune migration ou nouvelle publication Supabase dans cette passe.

Le manifeste d’atelier contient dix références : fichiers présents, noms dans
les deux langues, dix clés distinctes et SHA-256 revérifiés. Le skill passe le
validateur. Les images gardent le statut non publié ; les cadrages iPhone,
l’animation shiny et la production restent ouverts.

## Documentation isolée pour le commit

Snapshot sur HEAD `15f283c8`, limité aux lignes Cartes. `npm run artefact`, puis
`npm run verif` : PASS en23s,23tests. Captures Cartes390 et1440 regardées ;
largeur mesurée sans débordement. Les changements des autres sessions restent
hors de ce snapshot. Le livrable courant reste construit depuis l’arbre partagé.

Trois références de lignes héritées vers RestartSheet dépassaient sa longueur,
déjà743lignes dans HEAD. Les définitions ont été relues et les seuls champs
`preuve.lignes` recalés sur519–743, sans état ni comportement changé. Le script
Apple utilisé par les tests du snapshot est celui de HEAD, non le wrapper local
non committé. Les schémas historiques Forge du30août, explicitement périmés,
sont conservés en source mais retirés du rendu actif ; l’artefact respecte2Mo.

Le contrôle documentaire valide le contenu et son rendu ; il ne prouve pas
le fonctionnement sur iPhone ou l’absence de chauffe. La troisième famille,
Les Bois Sans Lune, reste en revue et hors du manifeste scellé. Sa règle
« mêmes personnages, poses et scènes distinctes » est mémorisée au skill,
au plan et dans la page Cartes.
