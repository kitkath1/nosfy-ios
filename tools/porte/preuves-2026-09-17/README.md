# Compte — livraison du 17-09-2026

Kathryn demande du code et la documentation à jour. Message de coordination
déposé dans `MULTI-SESSION.md` ; cette session ne modifie pas la Forge.
Le renouvellement de session déjà présent dans l’arbre a été conservé et retesté.

## Corrigé

- `definir_profil` refusait indirectement un objectif invalide, mais ignorait
  ce refus et terminait le profil. Migration `20260917184811` appliquée :
  validation de l’objectif avant toute écriture, droits anon/PUBLIC fermés.
- La fin de Nosfy attend la confirmation du profil. Les refus métier HTTP 200
  et les réponses incomplètes sont traités comme des erreurs.
- Une panne garde les réponses et propose Réessayer. Une relance reprend
  l’inscription ; le brouillon soumis retrouve la dernière étape.
- Une panne de lecture du profil après Apple ne signifie plus « nouvelle ».
  Une connexion interrompue reprend cette vérification au lancement.
- Le brouillon et les marqueurs sont effacés au nettoyage du compte.
- Documentation Compte et ses trois schémas actualisés ; verdicts iPhone
  distincts des tests automatiques.

## Preuves

| Vérification | Résultat |
|---|---|
| `compte-avant.log` | 27 PASS, 2 FAIL : objectif invalide accepté et profil partiellement terminé |
| `migration-dry-run.log` / `migration.log` | seule migration Compte appliquée, aucune autre migration ni secret |
| `compte.log` | 32 PASS, 0 FAIL, deux comptes jetables supprimés après test |
| `compte-flow-2026-09-18.log` | 50 PASS, 0 FAIL : ajoute collection vide, première série, pièces et sachet, idempotence, isolation des gains, reconnexion et cascade étendue |
| `inscription.log` | 12 PASS : vrai client Swift, réseau remplacé |
| `session.log` | 15 PASS : renouvellement, concurrence, panne et révocation |
| `inscription-commit.log` / `session-commit.log` | mêmes 12 + 15 contrôles sur les seules sources préparées pour le commit |
| `docs-commit-artefact.log` / `docs-commit-verif.log` | livrable Compte isolé sous 2 Mo ; tous les contrôles verts, captures 390 et 1440 px relues |
| `build-release.log` | BUILD SUCCEEDED, Release pour simulateur, aucune installation iPhone |
| `migrations.log` | 49 fichiers locaux = 49 migrations distantes |
| `docs-artefact.log` / `docs-verif.log` | livrable autonome généré, contrôles du site verts, largeur 390 px sans débordement |
| `advisors.log` | sortie 0, 53 avertissements ; celui de `definir_profil` signale son appel autorisé aux utilisateurs connectés |

`definir_profil` reste une RPC `SECURITY DEFINER` existante, intentionnellement
appelable par `authenticated` : elle filtre exclusivement sur `auth.uid()`,
refuse l’absence d’identité, fixe son `search_path` et n’accepte aucun identifiant
de propriétaire en paramètre. L’accès anon est refusé et l’isolation de deux
comptes est testée. Les autres avertissements du projet ne sont pas résolus
par cette livraison Compte ; le journal complet les conserve.

Le banc réel crée des identités e-mail confirmées sans envoyer d’e-mail.
Il utilise ensuite leurs jetons utilisateur pour les appels, écrit une séance,
la retrouve après reconnexion, appelle `supprimer-compte` et relit l’effacement.
L’administration ne sert qu’à créer les comptes QA, vérifier la cascade et
garantir leur nettoyage. Aucun compte existant ni aucune carte modifiés.

## Compilation du commit isolé (18-09)

La Release du 17-09 a réussi dans l’arbre partagé. La compilation du seul
commit Compte sur `dba590bc` échoue dans des interfaces hors Compte déjà
incohérentes dans ce HEAD : `ToasterGain` / `VolDePieces` absents, switch des
catégories incomplet, `onStopViaPause` appelé mais absent du composant.
Le compilateur signale aussi un délai sur le filtre `fantomes` de WoopApp ;
son expression est inchangée, mais ce diagnostic n’est pas résolu ici.
Les autres sessions gardent leurs corrections d’interface. Aucun de ces
changements n’est embarqué pour faire artificiellement passer le commit.
Journal complet : `build-commit-arm64.log`. Les 12 + 15 contrôles Swift isolés,
les 50 contrôles Supabase et le vérificateur documentaire passent.

## Limites conservées dans le site

La feuille Apple, le nouveau message de panne et le cycle complet de compte
sur iPhone n’ont pas été rejoués dans cette livraison. Les verdicts visuels
correspondants restent « à valider ». La clé Sign in with Apple `.p8` manque
toujours pour vérifier la révocation Apple ; cela ne bloque pas la connexion
native ni le parcours serveur mesuré ici.

Le 18-09, Kathryn demande le commit et autorise explicitement l’inclusion du
socle Compte antérieur nécessaire (Keychain, déconnexion, suppression, pull).
Le tirage, la génération et les modifications de documentation Forge restent
hors de ce commit. Les helpers d’authentification des bancs déjà présents dans
`ForgeServeur.swift` font partie du socle : ils sont requis par `SupabaseSession`
en Debug et retirent la connexion de test en Release.
Les captures Compte comprimées déjà présentes sont reprises et les schémas
sont simplifiés pour respecter le plafond de 2 Mo du livrable.

Le vérificateur documentaire lit aussi les preuves antérieures du dépôt.
`tools/nav/PLAN-ILE-TOUCHABLE.md`, déjà cité par le HEAD mais encore non committé
par sa session, est disponible pendant la vérification et reste hors du commit
Compte. Ce prérequis documentaire ancien ne concerne pas la compilation iOS.

Commandes de reproduction :

```sh
python3 tools/serveur/verif_inscription.py
python3 tools/serveur/verif_session.py
python3 tools/serveur/verif_compte.py
python3 tools/serveur/verif_compte.py --flow
cd docs/site
npm run schemas -- --only porte-
npm run artefact
npm run verif
```
