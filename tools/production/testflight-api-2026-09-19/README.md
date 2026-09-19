# Nosfy 1.0 (81) — envoi Apple et fiches, 19 septembre 2026

Kathryn autorise le remplissage des fiches et l'envoi TestFlight par API.
L'archive Release et l'export signés ont réussi. Apple a accepté l'IPA sans
erreur le 19 septembre à 10:18:51, heure de Paris. Le traitement Apple est terminé : build **VALID**, disponible dans App Store
Connect, prêt pour les tests internes ; revue bêta externe soumise, en attente chez Apple.
Les consignes FR/en-GB sont rattachées et relues ; aucune invitation envoyée.

## Mesures terminées

| Élément | Résultat relu | Preuve |
| --- | --- | --- |
| Accès App Store Connect | HTTP 200 avec la clé fournie JBXG6FH45V et l'Issuer ID de Kathryn | `lecture-app-cle-fournie.json` |
| Sources du binaire | Copie figée de 588 fichiers, empreintes SHA-256 | `sources.json` |
| Archive / export | Release iOS, signature distribution, version 1.0 (81) | `archive.log`, `export.log`, `build-81.json` |
| Téléversement | `UPLOAD SUCCEEDED with no errors`, livraison `589d3971-8596-438e-9c45-07ff24f07d15` | `upload.log` |
| Traitement Apple | `COMPLETE`, sans erreur/avertissement ; build `VALID` | `traitement-rest.json`, `traitement-apple.json` |
| Consignes du build | Français et anglais enregistrés puis relus | `finalisation-build.json` |
| Chiffrement | `usesNonExemptEncryption = false` relu chez Apple | `traitement-apple.json` |
| Fiches FR et en-GB | 12 champs textuels identiques après relecture ; e-mail de retour présent dans les deux langues ; catégorie Santé et forme | `fiches-relues.json` |
| Icône | Lune argentée sur fond sombre, compilée et vue ; icônes iPhone/iPad référencées dans Info.plist | `icone-81.png`, `icone-archive.json` |
| Groupe externe | « Premiers testeurs » créé, zéro testeur, lien public désactivé | `groupe-testflight.json` |
| Catalogue du lancement | 14 références publiées : 5 common, 3 rare, 3 epic, 3 legendary ; objectif de Kathryn 50 | `catalogue.json` |

L'ancienne clé 48V7W7DND9 recevait 401, même avec l'Issuer ID ; la clé fournie
ensuite règle l'accès. La clé privée utilisée reste dans Downloads et la
configuration locale est hors dépôt, avec permissions 0600. Aucun jeton JWT
ou contenu de clé dans les preuves.

## Icône : pourquoi elle n'apparaissait pas

La première lecture Apple montre zéro build. L'icône App Store Connect est
extraite du binaire envoyé, pas téléchargée dans un champ de la fiche.
Le projet utilise Icon Composer ; les anciennes entrées AppIcon.appiconset
sans fichier ne prouvent donc pas une icône absente. Le build 81 contient
bien les icônes et leurs références, dont les variantes 1024 × 1024 iPhone
et iPad. Après traitement, Apple expose deux icônes : `icones-apple.json`.
L’image du CDN Apple a été téléchargée et regardée : `icone-apple.png`, même
lune argentée. Le build 81 est sélectionné dans le brouillon App Store 1.0.
Le dessin n’a pas changé ; un délai de cache de l’interface Apple reste possible.

Source Apple : [Ajouter une icône](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon).

## Informations enregistrées et informations encore manquantes

Enregistrés et relus : descriptions TestFlight, e-mail de retours repris du
titulaire Apple, nom et sous-titres, descriptions App Store, mots-clés,
textes promotionnels, copyright du titulaire et catégorie Santé et forme.
Langues fr-FR et en-GB, langue primaire anglaise existante conservée.
Textes exacts : `FICHE-TESTFLIGHT.md` et `fiche-testflight.json`.

Le téléphone fourni ensuite par Kathryn est enregistré, ainsi que les contacts
et notes dans les deux fiches de revue. La relecture confirme tous les champs
requis, sans recopier le numéro dans les preuves. Le build est rattaché au
groupe « Premiers testeurs ». La soumission bêta est acceptée HTTP 201 et
relue **WAITING_FOR_REVIEW** (`soumission-beta.json`, `revue-beta-relue.json`).
Le refus 409 initial est résolu. Lien public fermé, groupe sans testeurs,
notifications automatiques désactivées en attendant l’ouverture autorisée.
Les URL publiques confidentialité et assistance restent à fournir pour
compléter la fiche publique App Store.

La fiche App Store reste **PREPARE_FOR_SUBMISSION**. Cette passe ne constitue
pas une soumission App Store : captures, questionnaire de confidentialité,
classification d'âge et autres exigences de cette publication restent à
compléter ou vérifier. Les boosters aléatoires devront notamment être
déclarés dans le questionnaire d'âge ; aucun « non » de convenance posé.

## Conditions d'ouverture aux testeurs

1. **Fait** : traitement Apple terminé et consignes FR/EN rattachées au build.
2. **Fait** : téléphone et notes enregistrés, demande de revue soumise.
   **Attente Apple** : acceptation de cette revue pour les testeurs externes.
3. **50 références réellement publiées et vérifiées** par la session Cartes.
4. Premier parcours réel dans ce binaire : entrée Apple, inscription, home
   vide, séance, stories, galet, booster, collection, reconnexion puis J+1.

Les tests automatiques déjà réussis restent décrits dans
`../stories-historique-2026-09-19/README.md` et
`../analyse-testflight-2026-09-19/README.md` ; ils ne sont pas rebaptisés en
validation d'un binaire TestFlight encore non installé. Aucun téléphone
personnel ni compte personnel modifié, aucun testeur invité.

## Vérification finale

Les 588 fichiers du manifeste restent identiques à l’arbre courant après
l’envoi ; aucun ajout de source dans les quatre dossiers du build
(`sources-comparees-apres-envoi.json`). Documentation : artefact puis verif
réussis, 23 tests, dix pages à 390 px sans débordement ; captures Compte et
état relues. Journaux : `doc-artefact.log`, `doc-verif.log`.
Le premier contrôle documentaire avait détecté deux nouvelles briques non
affichées en page QA : elles sont maintenant rendues en page Compte, puis
le livrable a été reconstruit et vérifié avec succès.

## Reprise

`../appstore_connect.py` lit la configuration privée locale et crée des
jetons courts pour l'API officielle Apple. `appliquer-fiche.py` relit les
locales existantes avant création/mise à jour. Le téléphone et les URL
éventuels sont lus dans la configuration privée, jamais codés dans le script.
Ce script ne soumet aucune version et n'invite personne.
`finaliser-build.py` rattache les consignes après `VALID`, sélectionne le build
dans le brouillon 1.0 et relit les icônes/statuts. La notification automatique
du build est désactivée avant l’ouverture aux testeurs ; pas de lien public.

Chemins propres de cette passe :

- `tools/production/appstore_connect.py`
- `tools/production/testflight-api-2026-09-19/`
- paragraphes TestFlight de `MULTI-SESSION.md`
- lignes TestFlight de `docs/site/content/briques.ts`, `mesures.ts`
- paragraphes TestFlight de `docs/site/content/pages/qa.mdx`, `porte.mdx`
- `docs/site/index.html` régénéré après les sources
- `tools/docsite/captures/etat-1440.png`, `etat-390.png`, `porte-1440.png`, `porte-390.png` régénérés par le vérificateur

Les fichiers documentaires sont partagés avec d'autres sessions. Aucun
changement de l’index Git. Commit/push ensuite autorisés par Kathryn ;
sélection et documentation vérifiées dans une copie isolée.
