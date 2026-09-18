# Chauffe76 après redémarrage — protection du Profil

18 septembre2026, iPhone15, iOS26.6.1. Version76 installée relue ; redémarrage
complet autorisé par Kathryn à11:04:40. Sans écouteurs selon sa réponse,
Bluetooth non désactivé. Charge visible, liaison redevenue USB. Aucune séance
ni ouverture de booster de production créée. **Chauffe durable non résolue.**

## Reprise physique76

Deux traces Instruments se coupent avec Device disconnected. La seconde
ne contient que1,475495s ; Nosfy est revenu entre le contrôle initial sans app
et cette capture. Ce fragment n’est ni un témoin app arrêtée ni une preuve
que la charge Bluetooth a disparu. Aucune troisième capture identique.

Premier parcours SKIP avant lancement : thermique1. Arrêt explicite de Nosfy
à11:11:36 ; repos observé jusqu’au nominal à210s,11:15:07. Le lancement
immédiat est refusé par iOS verrouillé. Après déverrouillage confirmé, lancement
à11:18:28 depuis thermique0. Profil vérifié par capture.

Le Profil n’est resté actif que34,3s avant une suspension système, contrairement
à la minute attendue par le runner. Sonde stable t15,2–33,5 :19lignes,
18,3s, CPU médian39%,60,1 callbacks/s, thermique0/protection0. Aucun verdict
de chauffe longue ne se déduit de cette fenêtre. Le runner voit1 à11:19:31,
alors que Nosfy était déjà en arrière-plan depuis11:19:03. Son accès au bouton
Retour expire ; échec119,651s. Le spindump de11:20:01–06 montre le processus
Nosfy suspendu sur les430 prélèvements, fil principal en attente : cet échec
ne prouve pas un gel de son graphe SwiftUI. BTLEServer y est en attente,
dernière exécution293s auparavant ; constat limité à ce prélèvement.

Retour actif sur Profil à11:23:17. Thermique1, puis2 à11:23:45.
Sonde t300,9–320,2 :20lignes/19,3s, CPU médian23%,60,1 callbacks/s,
protection1. Le sachet continue environ30rendus/s, scene non pausée,
isPlaying/rendersContinuously vrais ; les halos et avatar se sont aussi
réarmés. **Défaut confirmé : ces décors ignorent la protection thermique.**
SIGTERM773 confirmé à11:24:22 après collecte. Restauration -sansSondeVol,
puis arrêt863 confirmé11:25:26. Pas de nouvelle capture normale dans cette
passe ; commande de restauration réussie, vérification visuelle antérieure76
conservée séparément. iPhone libéré à Compte, qui prépare77.

## Correctif78 préparé hors appareil

Les halos et le fil de l’avatar suivent désormais la protection déjà active
sur les grands décors. Le sachet décoratif du Profil conserve une capture
transparente de sa pose, puis détache sa scène : une opacité nulle ou un simple
isPlaying=false avaient déjà laissé des rendus dans les campagnes précédentes.
Le tap/tirage est porté par la zone de geste extérieure ; le panneau manipulable
et la cérémonie gardent leur moteur. L’invitation périodique et les flèches se
reposent aussi à chaud. Sous une story, le décor3D du Profil dort désormais.
Au retour nominal, le décor retrouve la scène et sa caméra.

Concession visible à chaud : la bannière, le fil et le sachet cessent leur
animation d’ambiance, sans retirer les commandes. À froid, aucun changement
voulu de cadence ou de dessin. -profilRepos force uniquement ce chemin pour
la QA ; le seuil réel vient de ProtectionThermique. Ce correctif ne remplace
pas une mesure du coût actif ni l’endurance avec séance/écouteurs.

Analyse syntaxique Swift PASS. Compilations Release et vérifications
fonctionnelles78 interrompues à la demande de commit immédiat ; **78 non
installé, aucun verdict TestFlight**. Les seuls hunks Swift sont conservés dans les deux .diff de
cette campagne ; les raccords Compte/Cartes des autres sessions sont exclus
du futur commit. La copie de build inclut l’état de travail partagé à sa prise,
à synchroniser avec77 avant toute installation ultérieure.

## Limites et incidents d’outillage

La garde XCTest ne s’exécute pas pendant l’interrogation bloquée du bouton ;
le processus peut revenir après l’échec sans que defer terminate ait agi.
Le prochain essai doit surveiller l’état actif et s’arrêter hors de ce runner.
CoreDevice info processes est resté lent ; les journaux ont été récupérés via
HouseArrest/USB sans relance. Extraction xcresult refusée en sandbox, réussie
par l’autorisation prévue. Un refus automatique de quota a interrompu une
interrogation ; la reprise autorisée par Kathryn fonctionne ensuite par le même
circuit, sans contournement. Aucun compte effacé ni accessoire désactivé.

Preuves : journaux bruts nav/vol, extrait du spindump limité à Nosfy/BTLEServer,
capture Profil, sorties de test et d’arrêt dans preuves/. Paquets Instruments
et xcresult complets conservés sous /tmp/nosfy-chauffe76-*.
