# Renommage Nosfy — 18 septembre 2026

Demande de Kathryn : remplacer Woop dans l’application, les fichiers et Xcode,
et coordonner le changement avec les sessions Cartes et chauffe.

## État

- Avant mise à jour, CoreDevice lit `Woop`, version 73 (`iphone-avant.json`).
- Projet `Nosfy.xcodeproj`, cibles/schémas `Nosfy` et `NosfyWidgets` :
  `xcode-projet.json`. Projet ouvert et schéma Nosfy relus dans Xcode.
- Sources physiques `Nosfy/`, `NosfyShared/`, `NosfyWidgets/` ; fichiers
  `NosfyApp.swift`, `Nosfy.entitlements`, `EconomieNosfy.swift` et
  `NosfyWidgetsBundle.swift`. Contrôle des 571 fichiers déplacés avant édition :
  `deplacements.json` ; tous les contenus, y compris les changements parallèles,
  sont conservés.
- Anciennes entrées locales de compatibilité masquées dans Finder et hors des
  groupes Xcode. Elles permettent aux sessions ouvertes de finir leurs éditions ;
  les nouveaux builds et commits doivent employer les chemins Nosfy. Ne pas
  versionner ces liens. Les captures et journaux historiques gardent leur nom.
- Identifiants conservés : bundle Apple `fr.kathryn.woop`, extension
  `fr.kathryn.woop.WoopWidgets`, URL entrante `woop`, Keychain et clés de stockage.
  Module Swift de l’app toujours `Woop` pour conserver l’identité des modèles.
  Aucun reset, aucune déconnexion ni suppression demandés par ce renommage.
- Références des outils et du site adaptées : `references-modifiees.json`.
  Analyse de syntaxe et montage du banc NosfyUITests : `outils-controle.json`.
- Régressions existantes exécutées via les nouveaux chemins : 12 PASS inscription,
  15 PASS session (`inscription.log`, `session.log`).
- Release 74 : compilation signée réussie (`build-release.log`), signature
  vérifiée avec accès au trousseau (`signature.log`, sortie 0). Les métadonnées
  app et widget sont relues dans `binaire.json`.
- Mise à jour installée le 18-09 à09:37 Paris (`installation.json`,
  `installation.log`). CoreDevice relit **Nosfy, version 74**, même identifiant
  d’application (`iphone-apres.json`). Aucune désinstallation, aucun lancement
  de scénario ni remise à zéro. Le parcours de reconnexion n’est pas rejoué.
- La session Home/Route a accusé réception du renommage et prépare75 avec
  les nouveaux chemins. Téléphone libéré après74 ; aucun retour à74 prévu.
- Documentation autonome régénérée et vérifiée depuis Nosfy : **23 tests PASS**,
  10 pages sans débordement à390px, livrable identique au build. Contrôle final
  terminé en28s (`docs-verif.log`) ; quatre captures390/1440 inspectées.
  Les premiers essais ont rencontré des éditions/générations parallèles ;
  le dernier contrôle inclut les sources partagées à jour.

Cette validation de nom ne qualifie ni la chauffe, ni le parcours Apple complet,
ni la publication en production. Les réserves de la page QA restent ouvertes.
Les noms Apple Developer / App Store Connect ne sont pas vérifiés ici.

## Dossier principal du Bureau

À la précision de Kathryn, la racine physique a aussi été renommée
`/Users/kathryn/Desktop/Nosfy`. Finder affiche ce dossier et Xcode ouvre
`/Users/kathryn/Desktop/Nosfy/Nosfy.xcodeproj` (`xcode-ouvert.log`).
Contrôle : `dossier-principal.json` — même répertoire Git, mêmes fichiers,
aucune copie du dépôt ni perte de changements non committés.

Un répertoire **masqué** à l’ancien emplacement contient seulement des liens
pour les sessions et services déjà ouverts. La racine du bac à sable ne pouvant
pas être un lien, le premier lien racine a été remplacé par ce répertoire.
Les lectures restent possibles ; les anciennes sessions peuvent devoir demander
une escalade pour écrire dans Nosfy. La coordination est dans MULTI-SESSION.md.
`core.worktree` local pointe vers Nosfy : Git lancé par un ancien terminal agit
sur le vrai dépôt. Les nouvelles sessions doivent ouvrir directement Nosfy.

Le service documentaire existant a été adapté au nouveau chemin et rechargé.
Après la fin de l’arrêt asynchrone, le second bootstrap a réussi. Il sert
`http://localhost:3111` depuis Nosfy ; HTTP200, titre Nosfy et mention du dossier
principal relus (`site-local.log`). Le livrable autonome est à jour ; la
republication sur le lien Artifact externe n’a pas été effectuée dans cette session.
