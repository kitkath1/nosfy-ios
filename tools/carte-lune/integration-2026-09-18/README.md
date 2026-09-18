# Cartes — intégration du18 septembre2026

Migration84850 et forge-card déployées sur ytnnyjkramgiqyxdrkcu à la demande de
Kathryn.14 images approuvées publiées et SHA256 distants vérifiés ; UUID stables,
noms FR/EN,3familles. Anciennes cartes conservées, retirées des nouveaux tirages.
Aucun appel IA pendant l’ouverture. Deux manèges : orange ordinaire, noir
légendaire garanti. Noir offert par Route gratuit avant achat contre argent.

## Preuves mesurées

- deploiement-migration.log et deploiement-forge.log : pose effective.
- publication-images.log, activation-catalogue.log, catalogue-publication.json.
- qa-api.json/log :28 PASS ;2comptes QA nettoyés.20 appels de forge simultanés
  =1exemplaire ;8 préparations d’achat noir =1débit. Noir offert après2jours
  gratuit, rejeu post-révélation, origine serveur, RLS, annonces/acquittement,
  reconnexion et mêmes3légendaires/pixels sur deux comptes.
- qa-regression-gains.log :35 PASS après déploiement,2comptes QA nettoyés.
- qa-transaction.sql exécuté avec migration avant déploiement, en rollback :
  catalogue fermé,101exemplaires, garanties6/8ouvertures,2communes maximum,
  immuabilité, conversions et acquittement.
- qa-galets-garanties.sql/log : PASS sur fonctions déployées, BEGIN/ROLLBACK.
  14séances synchronisées sur2comptes temporaires ; garanties2/3séances,
  galets orange+noir et noir+noir, reçus uniques,3noirs gratuits légendaires.
  Aucun compte, gain ni réglage de test conservé.
- rythme-simule.json :16000parcours déterministes,1/2/3/5ordinaires par séance,
  avec/sans noir chaque7séances. Première légendaire≤2séances, puis≤3si ouverture.
  Médiane catalogue complet sans noir55/22/14/9séances. Taux de base45/35/15/5
  augmentés par garanties ; aucune rétention mesurée.
- cadres-reels-14.jpg :14PNG passés par LuneForge.habiller au simulateur.
  Revue : sujets cadrés, lunes intactes, poses distinctes, Cimes cuivre et Bois
  noir/nacre lisibles. Contraste physique et shiny animé encore ouverts.

## Raccord

Clôture/galet/retour → reçu identifié → coffre versionné → annonces confirmées.
Retenue pendant story/galet, acquittement après présentation et cache par compte.
Préparation par UUID persistant ; attribution/exemplaire/scellement atomiques ;
vrais pixels vérifiés avant révélation. Confirmation retire le sachet du stock.
Reprise conserve la carte, sans consommer la suivante. Collection par card_id,
acquisition_id, totaux serveur et cases manquantes vides. Les PNG publics ne
constituent pas un catalogue techniquement secret.

## Verdict de clôture

Debug compilé avec le correctif de destination ; Release compilé sur la source
prise avant ce dernier correctif Profil. Logs conservés. Le banc UI final donne
1PASS/4 : collection vide et accès orange au bon cran confirmés. Les trois
scénarios suivants ne franchissent pas le bouton Ouvrir au simulateur ; la
sonde du manège n’apparaît pas. Ni révélation ni retour collection ne sont
validés dans cette nouvelle app. Échec consigné, aucun verdict global vert.
→ **Levé le 18-09 à 12:40** : cause et correctif dans
`../ouverture-ui-2026-09-18/README.md` (le banc tapait pendant le film
d'arrivée ; 4 scénarios PASS au simulateur ; téléphone non mesuré).

La reprise des API et les garanties restent PASS. Ne pas confondre ces preuves
avec le parcours visuel. La publication de l’app reste suspendue à la correction
ou qualification du bouton Ouvrir puis à une QA complète des deux manèges.
Le compte temporaire du banc UI est nettoyé lors de la clôture ; aucun compte
personnel modifié. iPhone réservé par Compte, pas d’installation par cette passe.
Chauffe durable, haptique et shiny animé restent ouverts.

## Sécurité et publication documentaire

advisors-avant/apres.json conservés :7nouveaux avis SECURITY DEFINER accessibles
à authenticated, usage intentionnel des RPC. search_path vide, ownership/auth.uid,
révocation anon/PUBLIC et schéma privé fermé. Avis relus, pas effacés ; ce n’est
pas un audit global de toutes les RPC historiques.
Source documentaire et livrable autonome actualisés :23tests PASS, vérificateur16s, quatre captures desktop/mobile relues. L’ancien lien
claude.ai nécessite l’outil Artifact absent de cette session ; ne pas déclarer
sa republication sans confirmation. Commit Cartes/Forge demandé ensuite par Kathryn ; seuls ses raccords, sa documentation et ses preuves sont sélectionnés. Aucun push. Les builds ci-dessus portent sur l’arbre partagé ; contrôle documentaire et syntaxe Swift de la sélection relancés avant commit.

Sélection de commit : syntaxe Swift15 fichiers PASS ; livrable isolé1999526octets,23tests PASS, captures desktop/mobile relues. Les changements des autres sessions restent hors index. Voir commit-artefact.log et commit-verif.log.
