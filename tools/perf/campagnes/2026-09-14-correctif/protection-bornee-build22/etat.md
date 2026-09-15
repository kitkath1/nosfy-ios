# Build 22 : installé, navigation vérifiée, chauffe non résolue

Actualisation du 15-09 à 14:43. Installation réussie à 14:25:47, conteneur
`F659C60A-7C90-4B84-9626-606BACB7ED3E`, même UUID que ci-dessous. Le refus
initial de lancement était « Locked ». L'automatisation ouvre ensuite la Home
à 14:28:22 : PASS 4,358 s. Le journal confirme Home, application active,
écran éveillé et fond précalculé 393 × 709 ; thermique nominal au lancement.

La comparaison se déroule ensuite à chaud, sans SondeVol, avec maintien
d'écran et diagnostic sans protection borné à 60 s. Les captures montrent
la vraie Home. Les journaux avant/après capture ne montrent pas de sortie du
premier plan. Les deux Time Profiler se terminent et s'exportent :

| Rendu / capture | Durée | CPU Running échantillonné | Dont main | Thermique |
|---|---:|---:|---:|---|
| Deux lecteurs, 14:30:03 | 13,305560 s | 1 828 ms, soit 13,74 % d'un cœur | 1 420 ms | Fair 5,194493 s puis Serious 8,111067 s |
| Fond unique, 14:30:49 | 13,142659 s | 1 784 ms, soit 13,57 % d'un cœur | 1 398 ms | Serious toute la capture |

Ce n'est **pas une campagne énergétique à froid** : dès le lancement du témoin,
le thermique vaut 1 ; le candidat commence à 2. Pas de cadence GPU mesurée dans
ces Time Profiler. L'écart CPU est faible et les conditions thermiques diffèrent :
**aucun gain causal ou durable de chauffe n'est établi**. Les 24 i/s sont la
cadence du fichier, pas une mesure de présentation. Les deux captures Home du
candidat montrent des positions différentes de la pilule et du décor Route ;
elles prouvent du mouvement entre les prises, pas sa continuité.

À 14:31:25,602, `protection-thermique-banc-termine` confirme l'expiration du
diagnostic, environ 60 s après l'initialisation. Home → Exercices → Home →
Profil → Réglages passe ensuite à 14:31:39 en **9,301 s**, thermique 2. Aucune
action de déconnexion, suppression ou création de séance. Retour normal confirmé
par devicectl à 14:31:44.

Les essais SwiftUI suivants sont interrompus par la liaison Xcode. L'attachement
14:34:49 ne sauve que 3,368328 s, sans ligne `swiftui-updates` : aucune animation
ne peut en être accusée. Un lancement suivant est aussi interrompu. macOS voit
toujours en USB le numéro de série du même iPhone. Le service CoreDevice côté
Mac est relancé, sans autre xcodebuild/xctrace actif. La restauration finale via
`testOuvrirHomeEveillee` **passe à 14:42:49 en 4,048 s** : Home ouverte sans
profileur, protection normale, sonde éteinte et écran éveillé pour 30 min.

Les journaux, analyses CPU, provenances et captures de la comparaison sont
archivés ici. Les traces et exports volumineux restent dans `/private/tmp`,
préfixes `woop-home22-{reference,precompose}-142933-cpu`.
QA07 reste validée pour cet accès ; QA04 reste KO. Aucun nouveau retour de
Kathryn ne confirme une baisse de chauffe sur le build 22. Aucun commit.

## État historique avant l'installation, vers 13:30

Release compilé, UUID BD0AC650-8BF1-3F2C-9B69-B460524935FC.
Le diagnostic `-sansProtectionThermique` expire maintenant à 60 s ; la protection
normale reste commandée par les notifications thermiques. Le maintien d'écran
QA est indépendant de la sonde, limité à 30 min, sans préférence persistée.
Le fond unique et son garde de cadrage sont ceux du build 21.

Signatures de Woop et du runner vérifiées hors sandbox : valid on disk,
satisfies its Designated Requirement. Profils non expirés (06 et 14 septembre
2027). Le premier contrôle en sandbox ne pouvait pas établir leur confiance ;
il ne constituait pas une signature invalide. L'iPhone a en revanche refusé
le runner lors de la tentative de 13:15 : intervention sur son autorisation
requise, demandée à Kathryn après vérification locale.

Découverte à 13:30 : iPhone de Frédéric unavailable. **Le build 22 n'est alors pas
installé** ; le dernier build effectivement installé est 21. Son dernier
lancement de diagnostic employait la protection désactivée ; aucun retour
protégé n'a été confirmé après la coupure. Une fermeture complète puis une
réouverture à l'icône rétablit les arguments normaux du build 21.

Documentation : artefact généré (1 862 450 octets), puis vérificateur PASS en
31 s : tests, types, reconstruction et contrôles des pages à 390/1440. Le
premier build Next en sandbox, immobile, a été interrompu et relancé hors
sandbox. Ces vérifications ne valident ni le mouvement du fond, ni son gain
énergétique, ni le cycle du compte sur l'iPhone. Aucun commit.

## Vérifications finales de la reprise

À 14:47, nouvelle lecture du journal impossible : CoreDevice indique à nouveau
« unavailable » puis appareil introuvable. Le dernier lancement confirmé reste
le PASS du retour à la Home normale à 14:42:49 ; aucun lancement de diagnostic
ne lui succède. Ne pas transformer cet échec de lecture en mesure thermique.

Documentation régénérée (1 861 708 octets), `npm run verif` PASS en 45 s,
`git diff --check` PASS. Source et livrable local sont à jour ; la publication
au lien externe Claude n’a pas été effectuée (outil non disponible).
