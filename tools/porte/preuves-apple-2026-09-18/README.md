# Nosfy — clé Apple et nom du produit, 18 septembre 2026

Kathryn a fourni le Key ID `JBXG6FH45V`, puis explicitement autorisé
l'utilisation de `AuthKey_JBXG6FH45V.p8` dans Téléchargements. Le Team ID
`V45F4LUU8D` provient des configurations Debug et Release du projet.

## Clé Apple configurée

`installation.log` : clé EC P-256 lisible ; quatre secrets Apple configurés
puis relus ; appel réel à `apple-jeton` avec la session ordinaire d'un compte
QA temporaire et un code factice. Réponse : **HTTP 502, `apple_400`,
`invalid_grant`**. Le compte QA a été supprimé et son absence relue.

La clé est chargée et la fonction joint Apple. Cette sonde ne valide pas
l'échange d'un véritable code, le rangement d'un refresh token Apple, ni sa
révocation. Ces trois points attendent une connexion native et une suppression
sur une identité dédiée au test. Aucun compte existant, jeton Apple réel ou
téléphone n'a été manipulé.

Le script de pose a été corrigé : fichier temporaire 0600 supprimé après
usage, secrets absents des arguments du processus et des sorties, compte QA
jetable au lieu du compte Forge partagé, contrôle du détail Apple et retrait
de l'affirmation « apple_400 prouve que la clé est bonne ». La clé privée reste
dans son fichier d'origine et dans les secrets Supabase, hors Git.

## Nom public Nosfy

- App et extension : `CFBundleDisplayName` Nosfy / Nosfy Widgets en Debug
  et Release ; `CFBundleName` correspondant dans les deux fichiers Info.plist.
- Textes d'entrée Apple, carrousel de bienvenue, chambre, écran de laboratoire
  et étiquette de récompense passés à Nosfy / NOSFY.
- Site : titre du document, métadonnées, marque du rail, pied de page et
  mentions du produit dans les pages et tableaux actualisés. `CLAUDE.md`
  inscrit le nom choisi pour toutes les sessions.
- Consignes des fonctions `home-textes` et `bilan-periode` : marque Nosfy
  déployée, archives distantes relues et accès sans session refusés. Versions
  respectives **7 et 5**, `ACTIVE`, `verify_jwt=true`. Aucun appel IA payant.
  Preuve : `marque-deploiement.log`.

Les identifiants techniques (`fr.kathryn.woop`, Keychain, cache, schéma URL,
fichiers, types et cibles Xcode) sont conservés pour que le changement de nom
garde les comptes et l'installation existante. Les journaux et anciennes
captures restent des preuves historiques, pas des libellés du nouveau produit.

Les noms des fiches Apple Developer / App Store Connect restent à vérifier
dans le portail : cette session ne dispose pas d'un accès permettant de les
modifier. Le nom visible sur l'iPhone changera lors de la prochaine compilation
et installation par la session responsable ; aucune installation concurrente
n'a été lancée pendant son travail de chauffe.

## Vérifications

`marque-configuration.json` : configuration Release relue par Xcode, identités
conservées, noms des Info.plist relus. Les trois fichiers plist/projet passent
`plutil -lint`. Les cinq fichiers Swift retouchés passent le parseur Swift
(`marque-swift.log`, sortie 0). Recherche des chaînes affichées : aucune
ancienne marque autonome restante. Cela ne remplace pas une compilation
complète de la révision à publier ni la relecture de son rendu sur iPhone.

Le défaut de gains sur une séance absente, déjà documenté dans
`../../production/ETAT-PRODUCTION-2026-09-18.md`, reste ouvert. La pose de la
clé et le changement de nom ne transforment pas ce verdict en feu vert global.

Vérification finale du site : `docs-artefact.log` puis `docs-verif.log`,
sorties 0. Les 23 tests du site passent, livrable identique à son rebuild,
1 868 916 octets, dix pages sans débordement horizontal à 390 px ; captures
État et Compte relues à 390 et 1440 px. Une première passe avait détecté
un titre de la session parallèle trop long et trois références de lignes
déplacées dans RestartSheet ; seuls le titre et les références ont été recalés.
