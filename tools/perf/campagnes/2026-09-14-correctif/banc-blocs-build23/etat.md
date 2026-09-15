# Build 23 — banc complet récupéré, chauffe toujours KO

**Réserve16:18 : la Home seule n'est pas certifiée.** Les bancs ne vérifiaient
pas Welcome back. La capture du test16:07 est prise APRÈS un tap Later.
Les chiffres ci-dessous restent archivés mais leur attribution exclusive
à la Home est invalide. [Banc25 corrigé](../banc-verifie-build25/etat.md).

Registre : [échecs et mesures invalides](../../../ECHECS-CHAUFFE-HOME.md).

Ce build ajoute un test diagnostic uniquement sur argument `-bancCoutHome`.
Il ne constitue pas encore un correctif validé de la chauffe. Sans cet argument,
la Home conserve le rendu du build 22. Le working tree partagé contient aussi
les changements des autres sessions : ce n'est pas un checkout propre de c313012.

Le parcours prévu, après 5 s de préparation : complète 35 s, sans widgets 25 s,
sans Route 25 s, fond seul 25 s, nu 25 s, complète 25 s. La sonde enregistre sans
HUD puis s'arrête. Le banc garde la protection thermique normale ; les phases
fond seul peuvent donc utiliser le poster si le téléphone est chaud. La page
normale revient automatiquement même si la liaison Mac disparaît. Changement
de contexte (onglet, arrière-plan, Route, visite, séance/player) : arrêt du banc.
Le maintien de veille QA demandé par Kathryn reprend ensuite pour 30 min.

Première compilation interrompue (code 75) après plus de dix minutes sans
résultat. L'échantillon joint montre la résolution de contraintes Swift active.
Format JSON SondeVol simplifié, puis compilation 23b avec durées de fonctions.
Ce paragraphe décrit l’étape historique avant installation. Les fichiers source
et leurs SHA256 sont conservés pour relier les futurs résultats au code essayé.

## Compilation effectivement terminée, 15-09 vers 15:21

Release 23b : BUILD SUCCEEDED. Lanceur XCTest : TEST BUILD SUCCEEDED.
UUID de Woop : **FC2E4135-F615-3329-A696-EF03F4E57545**.
Le journal de durées donne BancCoutHome.executer 40,60 ms, SondeVol.ecrire
7,02 ms, HomeNuitPage.mobilierScene 1 124,56 ms. Plusieurs autres vues dépassent
6–12 s de vérification chacune ; la compilation complète est longue, sans
preuve qu'une seule expression ajoutée ait expliqué toute l'attente.
Le contrôle direct de types devenu redondant a été interrompu ; la preuve de
compilation est le vrai build Release ci-dessus. Première installation lancée à 15:23:16 : timeout 30 s ; la reprise réussit à 15:26. Dernière lecture du verrouillage à 15:16 : passcodeRequired=true.

## État réel à 15:38, le 15-09

Installation confirmée : conteneur `09260A50-F02E-4F4D-A37F-11DBB89DEA2A`.
Lancement direct à 15:27:47 refusé avec Security. À 15:29:46, le runner XCTest
démarre mais son appel à ouvrir Woop échoue en 0,164 s avec le même refus.
Signature locale valide, certificat app identique à celui du runner et présent
dans leurs deux profils, identifiants et droits cohérents. Pas de défaut local
de signature établi. Le lancement direct réussit à 15:33:56, sans modification
de signature ; SpringBoard confirme l'app active et visible. La cause du refus
antérieur reste inconnue. Journaux et comparaison des certificats archivés ici.

La sonde démarre à 15:34:02. Données après exclusion de préparation/transitions :

| Phase | n retenu | CPU médian | Callbacks/s médians | Plus grand intervalle | Thermique / protection |
|---|---:|---:|---:|---:|---|
| Complète, première phase | 20 | 16 % | 48,75 | 69 ms | 0 puis 1 / 0 puis 1 |
| Sans widgets | 15 | 8 % | 60,1 | 17 ms | 1 / 1 |
| Sans Route | 0 | — | — | — | Deux lignes brutes seulement |

À 15:35:05, l'app devient inactive puis passe en arrière-plan. Le banc rétablit
la Home complète, écrit `banc-home-fin` et arrête la sonde. Ce filet fonctionne.
La raison du changement d'application n'est pas établie. Les phases fond seul,
nu et retour complet de fin n'ont pas été mesurées. La transition thermique
confond le premier écart CPU : **ne pas attribuer huit points aux seuls widgets,
ni annoncer une baisse de chauffe**. Cadence = callbacks, pas rendu GPU.

Reprise unique à 15:36:56 : refus explicite **Locked**, aucun nouveau banc.
Le déverrouillage et trois minutes sur la Home ont été demandés à Kathryn ;
aucune réponse reçue à cet instant. Ne pas affirmer que l'app reste actuellement
ouverte après un lancement `--terminate-existing` refusé. Le dernier arrêt de
sonde et la restauration observés sont ceux de 15:35:05.

QA04 reste KO. QA07 conserve les validations antérieures 18/22 ; navigation23
et cycle complet du compte non rejoués. Aucune suppression, déconnexion, séance
ou récompense déclenchée. Aucun commit. Source et livrable du site régénérés après cette actualisation ; vérificateur
PASS en 15 s (types, tests, reconstruction, pages à 390/1440 sans débordement).
Liens du registre et du présent relevé vérifiés ; `git diff --check` PASS.
Le lien Artifact externe n’est pas republié, outil absent.

Le parseur final conserve les lignes `gel=1` au premier plan et signale le
plafond de 2 000 ms ; il ne les assimile pas à la veille. Le brouillon les
écartait à tort. Aucune ligne de ce relevé ne porte ce drapeau, donc les
chiffres publiés ci-dessus sont inchangés.

## Banc complet du 15-09 à 15:42, récupéré par USB à 15:54–15:55

Après confirmation du déverrouillage par Kathryn, lancement confirmé à 15:42:12.
Journaux réels : `vol-20260915-154224.jsonl` (163 lignes),
`nav-20260915-154219.jsonl` (187 lignes). Les six phases sont présentes,
restauration complète et `banc-home-fin` vers 15:45:10. Tout le banc est sur
Home, `applicationState=0`, `ecranEveille=true`. Aucun passage en arrière-plan
dans cette fenêtre. Même UUID 23b, sans HUD ni profileur connecté.

| Phase | n stable | CPU médian | Callbacks/s | Intervalle max | Thermique/protection |
|---|---:|---:|---:|---:|---|
| Complète initiale | 20 | 15,5 % | 48,05 | 294 ms | 0 puis 1 |
| Sans widgets | 15 | 8 % | 60,1 | 17 ms | 1 |
| Sans Route | 16 | 11,5 % | 60,1 | 17 ms | 1 |
| Fond seul | 16 | 1 % | 60,1 | 17 ms | 1 |
| Nu | 15 | 1 % | 60,0 | 17 ms | 1 |
| Complète finale | 16 | 12 % | 60,1 | 17 ms | 1 |

Préparation exclue : 15 s première phase, 10 s suivantes. Aucune ligne gel=1.
Le fond est protégé à chaud : ces résultats ne mesurent pas le coût de la vidéo
animée seule. « Nu » conserve MenuHote et le châssis global ; ce n'est pas le
RootView vide. L'écart fond seul → complète finale localise une charge CPU
continue dans le mobilier de la Home et ses interactions avec le rendu. Les
coûts individuels ne s'additionnent pas nécessairement. Les phases successives
ne sont pas une campagne énergétique contrôlée : pas de verdict de chauffe.

### Collecte enfin récupérée, sans relancer le banc

De 15:45 à 15:54 : CoreDevice 1011 malgré liste connected, USB physique visible
et ideviceinfo lisant le bon nom. `afcclient -u … --documents` annonce « No
device found » ; sans -u, --documents échoue InstallationLookupFailed.
`afcclient --container fr.kathryn.woop` donne accès au conteneur de développement.
Une session interactive différée se déconnecte ; les commandes ls/get fournies
immédiatement sur stdin fonctionnent. Les deux nouveaux fichiers sont lus et
analysés, première tentative partielle conservée séparément.

Repli reproductible : `python3 tools/perf/collecte_usb.py /private/tmp/nom-neuf`.
Le script exige que le seul iPhone USB soit celui de cette campagne, puis copie
uniquement les derniers journaux vol/nav. Vérifier leur date : le dernier vol
peut être ancien si aucune sonde n'a tourné. Aucun UIFileSharingEnabled ajouté.

Comparaison ciblée suivante lancée à 15:56:59 : même banc et même binaire, seul
argument supplémentaire `-sansInvite` (retire l'invite « pull to start »).
La collecte précoce à 15:58:44 refuse de choisir un appareil car idevice_id
renvoie une liste vide. Aucun résultat n'en est déduit ; attendre le journal
complet et rétablir ensuite la Home sans cet argument.

### Comparaison sans invite interrompue (collecte à 16:00)

Le nouveau vol 15:57:05 contient cinq lignes, aucune après la préparation.
L'app devient inactive à 15:57:10,380 puis passe en arrière-plan à
15:57:10,967. Le banc s'arrête et restaure la phase complète à 15:57:11,270.
**Aucune mesure stable exploitable, aucun verdict sur l'invite.** À 15:57:45
l'app redevient active mais le banc ponctuel ne redémarre pas, conformément
à sa garde. Au lancement, thermique 2 : nouvelle preuve que l'inconfort
utilisateur persiste, pas une mesure causale de température.