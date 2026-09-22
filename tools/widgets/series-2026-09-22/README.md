# Les séries par semaine et par mois — Regularity (22-09, « go pour Regularity »)

**Verdict de Kathryn, 22-09 :** « go pour Regularity ; conserve la cohérence design
Apple-like, pas de sous-titre ni de texte bidon, peu de texte, dégradé blanc,
minimal, sticker si besoin. » Analyse : `../ANALYSE-SERIES-SEMAINE-MOIS-2026-09-22.md`.

## Ce qui est fait

**La chambre Regularity, bloc « Résumé »** : une troisième ligne, entre les
séances et les semaines d'affilée — le même composant `ligne()` (chiffre Inter 26
en dégradé blanc, nom, sous-ligne « Contre N … », flèche ▲/▼). Semaine :
« Séries cette semaine · Contre 36 la semaine passée » ; Mois : « Séries ce mois-ci
· Contre 33 le mois passé » ; à vide : « 0 · Aucune la semaine passée » en gris.
Pas de sticker (le bloc est typographique, les deux autres lignes n'en ont pas),
pas de phrase. Au passage, le « Aucune la semaine passée » de la ligne des séances
restait en français côté anglais → « None last week » (`sousContre`).

**Le serveur** : `widget_regularite` rend `series`, `series_precedent`,
`series_delta` — `count(*)` de `strength_sets` des séances finies dans la fenêtre
(la définition qui paie à la clôture), comptées à la date de **fin** de séance,
la fenêtre d'avant au même temps écoulé. Migration
`supabase/migrations/20260922103419_widget_regularite_series.sql`, construite
depuis la définition vive (identique au dépôt 20260913211000, vérifié).

**Le téléphone** : `ChambreFenetre.series / seriesPrec` (ChambreDonnees.swift,
Σ `Workout.seriesPayantes` sur la fenêtre, au jour de fin), `sansRien()` les
éteint à vide, `ChambreServeur.regularite` lit les deux clés, le banc
`-widgetsBanc` les imprime, `verif_widgets.py` les compare (31 → 35 preuves).
Banc nouveau : `-chambreMois` ouvre la chambre sur la fenêtre Mois.

## Les preuves

| quoi | fichier | résultat |
|---|---|---|
| migration rejouée + banc, transaction annulée (compte inventé) | `avant-pose.log` | **16 PASS, 0 FAIL** |
| pose par l'API de gestion, historique, définition vive relue | `pose.log` | HTTP 201 · 57 = 57 · `ended_at >= b.debut` · droits authenticated |
| le même banc sur la base posée | `apres-pose.log` | **16 PASS, 0 FAIL** |
| REST sur le compte de test, serveur seul | `verif_widgets-serveur.log` | semaine series 0 / 3 · mois 102 / 33 · 10 ✓ |
| app désinstallée, pull (39 séances), téléphone = serveur | `verif_widgets-telephone.log` | **35 ✓ · 0 ✗ — TOUT EST VERT** (series et series_precedent égaux, deux fenêtres) |
| la chambre au simulateur (compte de test) : Mois, Semaine, vide | `captures/` | 28 séances · 102 séries ▲ +69 · 7 semaines ; semaine vide en gris |
| journal de la chambre (Mois) | `journal-chambre-mois.log` | `[chambre-serveur] widget_regularite(mois) → 28 séance(s)` |

Ce que le banc a mesuré, en clair : le vide rend des zéros ; 8 + 5 séries et une
séance cardio → 13 (la série à 0 rép compte, le cardio non) ; la semaine d'avant est
bornée au même temps écoulé (4, la séance finie après la borne exclue) ; 30 jours →
33 / 9 ; un compte étranger lit 0 ; les clés du 13-09 sont intactes. Et **le litige,
mesuré** : une séance à cheval sur la borne compte dans `precedent` (séances, au
début) mais ses séries suivent sa fin — posé sur le site (`b-fn-fenetre-bornes`).

## Ce qui n'est pas mesuré

- **Son iPhone** : la chambre n'a été vue qu'au simulateur (iPhone 17 Pro).
- **La chauffe** : rien de nouveau à mesurer (du texte statique, aucune horloge,
  aucun verre), mais rien n'a été mesuré non plus.

## Piège payé (22-09) — à ne pas rejouer

Un lancement `-skipAuth -demoData` sème des séances de démo dans la base locale ;
le lancement SUIVANT avec `-sessionBanc` les **pousse sur le compte de test** (la
garde `-demoData` ne vaut que pour le lancement qui sème). Trois coquilles (0 série,
0 phase, créées 08:49:04Z) sont arrivées ainsi sur be69f505 — retirées à 10:55
(`menage-compte-test.log`, 42 → 39 séances). Remède : **désinstaller l'app entre un
lancement démo et un lancement banc**. Autre piège : les séries de la démo
(`seedDemo`) ne sont pas `isDone` → la chambre en démo affiche « 0 séries » ; les
captures sont donc prises sur le compte de test, pas sur la démo.

## Site de doc (même commit)

`b-fn-widget-regularite` (quoi, note, preuve 22-09), `b-wd-semainestats` (35 preuves),
`b-tb-strength-sets` (le piège `is_done`), `b-fn-fenetre-bornes` (le litige
début/fin), `b-migrations-posees` (57 = 57), `widgets.mdx` (tableau vide/plein +
Savoir). Artefact régénéré (2,00 Mo), `npm run verif` vert, republié au même lien
(version 101).
