import type { EtapeQA } from './types'

/**
 * LE TEST QA DE BOUT EN BOUT — le compte, du login à la suppression (14-09-2026).
 *
 * Son ordre, mot pour mot : « je vais tester avec mon tel, et après documente ce test dans
 * la partie compte, et crée un onglet Test QA avec ce flow qu'on valide ensemble niveau
 * front et back ». Chaque étape dit ce qu'ELLE doit voir (le front, sur son iPhone) et ce
 * que le serveur ou le téléphone doit tenir (le back, lu par moi : une requête, un journal,
 * un fichier). Deux verdicts par étape, un par côté. Un verdict ne se peint qu'après avoir
 * été VU (elle) ou LU (moi) — jamais déduit du code, la règle du site.
 *
 * Le journal : `xcrun devicectl device process launch --console --device <UDID> fr.kathryn.woop`
 * (le câble ; le Wi-Fi lâche). Le serveur : `select …` par l'API de gestion, projet
 * ytnnyjkramgiqyxdrkcu. Le simulateur ne sait pas ouvrir la feuille Apple : ce qui s'y est
 * mesuré le 14-09 est dit pour mémoire, le verdict attend son téléphone.
 */
export const ETAPES_QA: EtapeQA[] = [
  {
    id: 'qa-01-porte', n: 1, titre: 'Le lancement, téléphone vierge',
    geste: 'Ouvrir Nosfy après une installation propre (aucun argument, aucune session).',
    front: 'Le mini splash (la lune de sang), puis la porte : le film d\'arrivée, le carrousel, « Se connecter avec Apple ». Aucune pop-up, aucun Welcome Back.',
    back: 'Aucune session gardée (`SupabaseSession.sessionGardee()` faux : pas d\'identité Apple, rien au Keychain). Journal : aucune ligne `[home-serveur]`, `[welcome-back] retenue : la porte, le film ou le splash tient l\'écran`. Serveur : auth.users ne porte que le compte du banc.',
    frontVerdict: { etat: 'valide', le: '14-09', note: 'son premier retour : « de la partie login à la fin de l\'onboarding », rien à redire sur la porte' },
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur avant son test : auth.users = 1 (le banc) ; 2e passage 15:30, journal par le câble : `[welcome-back] retenue : la porte, le film ou le splash tient l\'écran` ×3 sous la porte, aucune ligne [home-serveur]' },
  },
  {
    id: 'qa-02-apple', n: 2, titre: 'Apple : la création du compte',
    geste: 'Toucher « Se connecter avec Apple », valider la feuille native avec son Apple ID.',
    front: 'La feuille Apple, puis la porte se dissout dans le flou et le film de Nosfy commence — c\'est une NOUVELLE.',
    back: "Serveur : nouvelle identité Apple ; profil incomplet puis onboarding. Depuis la clé installée le 18-09, un authorizationCode frais doit être échangé par apple-jeton et son refresh rangé dans apple_jetons. La sonde à code factice ne mesure pas cet échange réel ; le verdict du 14-09 ci-dessous reste historique.",
    frontVerdict: { etat: 'valide', le: '14-09', note: 'la feuille, puis le film — son retour ne dit rien contre' },
    backVerdict: { etat: 'valide', le: '14-09', note: '2e passage 15:31, journal par le câble : `[compte] apple-jeton → 503 cle_absente — on entre quand même`, `[PORTE] profil() → existe=false`, `[PORTE] verdict = NOUVELLE → onboarding · e3920e3a` ; serveur : auth.users e3920e3a, provider apple, email null, apple_jetons 0 (1er passage 09:40 : idem sur 0fac947b)' },
  },
  {
    id: 'qa-03-nosfy', n: 3, titre: 'Nosfy : langue, prénom, le reste',
    geste: 'Choisir la langue, donner son prénom (obligatoire), le but, l\'objectif hebdo, puis « Entrer ».',
    front: 'Le film dans la langue choisie ; sans prénom, l\'input passe au rouge et « Passer » n\'existe pas ; la pop-up de fin (« Allez <prénom>, go ») lisible, en grand ; à « Entrer », la cérémonie de connexion (les braises) puis la home.',
    back: '`definir_profil(langue, prenom, but, objectif)` : profils (langue, prenom, but, onboarding_termine_at posé), user_prefs (objectif). Journal `[NOSFY] definir_profil → existe=true onboarding_termine=true prenom=…`. Cache : woop.langue, woop.prenom, woop.premiere_fois=true.',
    frontVerdict: { etat: 'ko', le: '14-09', note: '1er passage : « tout est bien en anglais ou en français selon mon choix, comme le nombre d\'exercices choisis : top » ; 2e passage 15:33 (tout en anglais) : Nosfy OK, MAIS la pop-up de fin « LET\'S / KATHRYN / GO ! » est ENCORE trop petite (capture) — sa règle, répétée : « ça doit toujours être harmonieux, gros texte, même si le nom est coupé c\'est le design, ne le bouge plus jamais » → les trois rangées à la même échelle géante, coupées au bord si besoin (session porte, RewardCard/TexteGeant)' },
    backVerdict: { etat: 'valide', le: '14-09', note: '2e passage 15:33, journal par le câble : `[NOSFY] langue=en prenom=Kathryn but=forme objectif=3`, `[chambre-serveur] definir_objectif(3) → 3`, `[NOSFY] definir_profil → existe=true onboarding_termine=true prenom=Kathryn objectif=3` ; serveur : profils Kathryn / en / forme, user_prefs 3 (1er passage 09:41 : « Kiki Style » / fr / force / 7)' },
  },
  {
    id: 'qa-04-home-vide', n: 4, titre: 'La home de la première fois',
    geste: 'Regarder la home qui arrive après Nosfy, sans rien toucher, trois secondes.',
    front: 'La phrase dans SA langue avec SON prénom (fr : « Hey X, / et si on faisait / ta première / séance ? »), les widgets vides (la loi du vide), la card ROUTE « CHAPITRE 1 · Commence ton entraînement › » (en : « Start your workout ») qui VIT (la lampe du bord respire, un reflet traverse le titre, une onde naît du galet du jour, le fond de verre respire). AUCUN Welcome Back. Trois secondes après la home — un peu plus si home() est lent — la pop-up « Bienvenue » / « Welcome » : la vidéo de Nosfy qui saute sur les galets, « Laisse Nosfy te guider : séances, progrès, récompenses. », CTA « Commencer » / « Start ». Et la home doit rester FLUIDE.',
    back: '`home()` → premiere_fois=true, visite_home=false, langue, phrases dans sa langue ; `etat_coffre.retour_disponible=false` (S4 : aucune séance finie). Journal `[home-serveur] home() → … première fois true · visite false`, `[home-serveur] phrases → active, active_zero, seance, seance_debut, vide`, `[welcome-back] retenue : première arrivée (c\'est Nosfy qui parle)`. La porte de la pop-up (app) : woop.welcome.premiere.vue faux ET premiere_fois vrai ET visite_home faux ET aucun manège ni pop-up du Sacre ouverts.',
    frontVerdict: {"etat": "ko", "le": "16-09", "note": "16-09, version42 installée et lancée après déverrouillage : comparaison dans le même binaire, tous les moteurs actifs, thermique0/protection0. Ancien rendu : CPU médian20 % sur31 lignes (t20,7–51,2) ; natif :3 % sur105 lignes (t90,4–195,9), puis3 % sur25 lignes au retour au natif. Cadence60,1 callbacks/s et pire17ms dans ces fenêtres. Fond, braises et silhouettes conservés ; interpolation confiée au compositeur et silhouettes mises en cache. Gain CPU mesuré, environ85 %, pas une mesure de watts. Endurance interrompue par un appel puis app inactive : chauffe longue encore ouverte. Prototype booster40 retiré faute de gain établi. 16-09, retours 39/41 : une nouvelle variante courte à chaque arrivée réelle sur les deux Homes ; même phrasé flou que l’onboarding. Sur Home noire, compteur à la minute réelle et nouvelle formulation toutes les cinq minutes visibles. Aucun tirage ni réveil des minutes hors écran, aucun appel IA au geste. Rouge : 3 variantes aux retours, PASS 21,732 s ; noire : 3 variantes à trois minutes, PASS 27,896 s. Le texte reste présent même quand une protection coupe son animation. Haptique ressentie non confirmée. tools/perf/campagnes/2026-09-16-retours-et-profil/etat.md 16-09, décompte53 : lecteur isolé iPhone, fin/relectures/tap/arrière-plan PASS99,016s ; therm0, récupération0 % CPU arrondi sur20lignes/19,2s. Ce test de six secondes ne valide pas la chauffe durable de Home. Preuves : tools/perf/campagnes/2026-09-16-depart-count/etat.md. 17-09 : forte chauffe signalée pendant le diagnostic Start, Route laissée ouverte pendant les compilations. Nosfy arrêté à09:01:39 ; suite sur simulateur. La réparation du montage vidéo ne clôt pas la chauffe. Voir la reprise-start-17 de cette campagne."},
    backVerdict: { etat: 'valide', le: '14-09', note: '2e passage 15:33, journal par le câble : `[home-serveur] home() → prénom Kathryn · 0 / 3, reste 3 · en séance false · 0 séances en tout · première fois true · visite false · langue en`, `[home-serveur] phrases → active, active_zero, seance, seance_debut, vide`, `[welcome-back] retenue : première arrivée (c\'est Nosfy qui parle)` — la règle tient des deux côtés' },
  },
  {
    id: 'qa-05-widgets', n: 5, titre: 'Les widgets : le détail et l\'objectif',
    geste: 'Toucher un widget pour ouvrir sa chambre ; dans Regularity, changer l\'objectif de la semaine ; revenir.',
    front: 'La chambre s\'ouvre en glissant, fluide ; ses parties sont GRISES (rien des deux côtés : défi « — », pics à zéro) ; l\'objectif se choisit (3 → 10) avec un petit check blanc « pris en compte » et une haptique, et le mini-widget suit au retour ; la chambre se referme au geste et rend la home.',
    back: 'La chambre lit `widget_regularite(\'semaine\')` etc. (journal `[chambre-serveur] widget_… →`) ; le choix écrit `definir_objectif(n)` → user_prefs.objectif_hebdo (journal `[chambre-serveur] definir_objectif(n) → n`) ; la clé locale `objectifHebdo` suit.',
    frontVerdict: { etat: 'valide', le: '17-09', note: '17-09 : fermeture des overlays difficile et saut final signalés ; version60 encore saccadée selon le retour iPhone ; 61 installée : descente lente physique réussie en10,090s, film sans remontée ; retour utilisateur validé (« top c cool »), voir tools/perf/campagnes/2026-09-17-fermeture-widgets/etat.md. Historique14-09 : 1er passage : « ça bug quand je clique sur le détail, l\'overlay n\'est pas fluide » (téléphone chaud) ; « je peux changer le nombre et ça update bien dans le mini widget » ; « il manque un feedback : pastille blanche + haptique » → fait (pastille blanche, haptique .medium). 2e passage 15:35, build à jour : « les étapes 1 à 6 sont ok niveau front et back »' },
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur à 09:4x : user_prefs.objectif_hebdo = 7 pour son compte — le choix de la chambre est bien arrivé' },
  },
  {
    id: 'qa-06-visite', n: 6, titre: 'La visite guidée',
    geste: '« Commencer » sur la pop-up, puis suivre les quatre temps (ou « Passer », ou toucher l\'objet net).',
    front: 'La brume : la home s\'enfonce dans le noir flouté, l\'objet net en sort, les mots se disent mot après mot — « Commencer. » (la card ROUTE entière), « Tes progrès. » (les widgets), « Ton profil. » (le glyphe Profil de la nav), « Tes pièces. » (la pièce du trésor en haut à droite), chacun avec sa sourde ; sous les mots « Touche pour continuer », puis « Touche pour commencer » au dernier ; « Passer » en haut à gauche ; un tic clair à chaque temps, la paillette à la fin ; une vibration lourde à l\'entrée et à la fin, moyenne à chaque suivant. Toucher l\'objet net termine aussi la visite, l\'objet répond derrière. À la fin : la home telle quelle, la brume levée en 0,8 s.',
    back: '`marquer_visite_home()` part de `finirVisite()` dans les TROIS sorties (dernier tap, « Passer », traversée), une fois : profils.visite_home_le posé, `home().visite_home=true`. Journal `[premiere-arrivee] marquer_visite_home() → répondu (la date est posée au serveur)` ou `a échoué : …`. Cache : woop.welcome.premiere.vue passe à vrai à la fermeture de la pop-up (avant la visite) — la pop-up ne rejoue pas localement même si l\'app est tuée pendant la visite ; la visite, elle, rejoue au prochain lancement tant que visite_home est faux au serveur.',
    frontVerdict: { etat: 'valide', le: '14-09', note: '2e passage 15:35 (en anglais) : « les étapes 1 à 6 sont ok niveau front et back » — la pop-up et la visite comprises ; serveur : visite_home_le posé 15:34' },
    backVerdict: { etat: 'valide', le: '14-09', note: '2e passage 15:34 : profils.visite_home_le posé 75 s après definir_profil — marquer_visite_home() est bien parti de l\'app (1er passage 09:42 : idem, 26 s)' },
  },
  {
    id: 'qa-07-profil', n: 7, titre: 'Le profil à son prénom',
    geste: 'Onglet Profil, puis la roue des Réglages.',
    front: 'La bannière : le rond à ses initiales, son prénom, « @prenom » en minuscules, Level 1 ; les Réglages : son prénom, « 0 pièces lune · Level 1 », « Se déconnecter », les CGU, « Supprimer mon compte » en rouge. Plus jamais « Kathryn », « KD » ni « @kathrynd ».',
    back: 'Rien au serveur : la page lit le cache woop.prenom (= profils.prenom, posé par definir_profil et rafraîchi par home()).',
    frontVerdict: {"etat": "valide", "le": "16-09", "note": "39 : retour Exercices/Profil/Home avec changement de phrase PASS 21,732 s ; même parcours sur Home noire41 PASS 27,896 s. Accès Réglages testé sur37 (10,754 s), quatre cycles sur38 (66,259 s). Aucun nouveau cycle de compte ni suppression. tools/perf/campagnes/2026-09-16-retours-et-profil/etat.md"},
    backVerdict: { etat: 'valide', le: '14-09', note: 'rien à lire au serveur ; profils.prenom = « Kiki Style », c\'est ce que la page doit dire' },
  },
  {
    id: 'qa-08-relance', n: 8, titre: 'La relance : la home direct',
    geste: 'Tuer l\'app (balayer), la rouvrir.',
    front: 'Le mini splash, puis la home DIRECT : pas de porte, pas de feuille Apple, pas de pop-up (déjà vue), pas de Welcome Back, sa phrase avec son prénom.',
    back: 'La session gardée (identité Apple + refresh au Keychain) se rafraîchit en silence. Journal : `[home-serveur] home() → …` sans aucune ligne `[PORTE]` ; `[welcome-back] retenue : première arrivée`. Serveur : auth.sessions du compte ≥ 1.',
    frontVerdict: { etat: 'a_valider' },
    backVerdict: { etat: 'a_valider', le: '17-09', note: 'Renouvellement corrigé : 15 assertions locales du vrai actor, puis 12 appels concurrents sur session QA réelle → un jeton renouvelé cohérent et etat_coffre 200. Reprise69 : relance de la session conservée sans skipAuth et navigation Home/Exercices/Profil PASS20,692s sur iPhone ; home et annonces répondent au journal physique. Nouvelle entrée Apple et une heure complète app ouverte restent à mesurer. tools/serveur/verif_session.py' },
  },
  {
    id: 'qa-09-deconnexion', n: 9, titre: 'Se déconnecter',
    geste: 'Réglages → « Se déconnecter ».',
    front: '« Déconnexion… » sur la ligne, puis la porte revient (le carrousel, sans le film d\'entrée). Plus rien à elle sur le téléphone.',
    back: '`POST /auth/v1/logout?scope=global` : auth.sessions du compte = 0. Le téléphone : 14 clés effacées (prénom, langue, phrases, première fois, pop-up vue, visite faite, objectif, pull, chemin, outbox…), SwiftData vide, Keychain vide. Journal `[session] logout → le refresh est révoqué au serveur`, `[compte] effacé : 14 clés, les séances, la chambre, l\'économie`, `[compte] la porte est rendue (deconnexion)`.',
    frontVerdict: { etat: 'a_valider' },
    backVerdict: {"etat": "a_valider", "le": "17-09", "note": "14-09 : chemin app mesuré au simulateur. 17-09 : logout global réel sur compte temporaire, ancien refresh refusé ; 15 tests Swift du renouvellement et nettoyage du brouillon vérifiés. Le bouton et le nettoyage complet restent à rejouer sur iPhone. tools/porte/preuves-2026-09-17/compte.log"},
  },
  {
    id: 'qa-10-reconnexion', n: 10, titre: 'Se reconnecter : un compte connu',
    geste: 'Sur la porte, « Se connecter avec Apple » à nouveau, même Apple ID.',
    front: 'La feuille Apple, puis DIRECT la cérémonie de connexion et la home — pas de Nosfy. Sa phrase avec son prénom, la pop-up ne rejoue pas (la visite est faite au serveur).',
    back: '`profil()` → onboarding_termine=true → journal `[PORTE] verdict = CONNUE → app`. Le pull : `[pull] seances_depuis(tout) → total 0`. `home().visite_home=true` → `[welcome-back] retenue : première arrivée` (toujours aucune séance).',
    frontVerdict: { etat: 'a_valider' },
    backVerdict: {"etat": "a_valider", "le": "17-09", "note": "17-09 : reconnexion du compte temporaire, profil terminé, visite et séance retrouvés ; 32 vérifications backend vertes. La feuille Apple après déconnexion reste à rejouer sur iPhone. tools/porte/preuves-2026-09-17/compte.log"},
  },
  {
    id: 'qa-11-suppression', n: 11, titre: 'Supprimer mon compte',
    geste: 'Réglages → « Supprimer mon compte » → l\'alerte → « Supprimer ».',
    front: '« Suppression… » sur la ligne, puis la porte revient. Rouvrir l\'app : la porte encore.',
    back: "Après une connexion Apple fraîche avec jeton rangé : supprimer-compte révoque chez Apple puis efface auth.users et les données liées, et le téléphone revient à la porte. Une révocation ratée doit rester dans apple_revocations pour reprise. Clé installée le 18-09 ; ce cycle réel reste à mesurer sur un compte dédié.",
    frontVerdict: { etat: 'a_valider' },
    backVerdict: {"etat": "a_valider", "le": "17-09", "note": "14-09 : chemin app mesuré au simulateur. 17-09 : supprimer-compte appelé avec la session QA, compte et séance effacés, profils et préférences absents, refresh refusé. La suppression depuis le bouton iPhone et la révocation Apple restent à valider. tools/porte/preuves-2026-09-17/compte.log"},
  },
  {"id": "qa-12-inscription-panne", "n": 12, "titre": "Inscription interrompue : réponses conservées", "geste": "À la fin de Nosfy, couper le réseau avant Entrer, puis rétablir le réseau et toucher Réessayer.", "front": "La home attend. Le message explique que les réponses sont conservées ; Réessayer termine l’inscription après confirmation du serveur.", "back": "definir_profil doit confirmer ok:true et onboarding_termine:true. Une erreur réseau, un refus HTTP 200 ok:false ou une réponse incomplète conservent le brouillon et le marqueur d’inscription.", "frontVerdict": {"etat": "a_valider"}, "backVerdict": {"etat": "valide", "le": "17-09", "note": "Client Swift réel compilé et testé avec réseau remplacé : 12 PASS. Backend réel : objectif 99 refusé sans inscription partielle, puis profil valide accepté. Rendu du message non mesuré sur iPhone."}},
  {"id": "qa-13-reprise-nosfy", "n": 13, "titre": "Relance avant la fin de l’inscription", "geste": "Fermer l’application pendant l’inscription ou après un échec d’enregistrement, puis rouvrir.", "front": "Nosfy reprend ; si les réponses avaient été soumises, elles sont récupérées pour terminer. Une connexion interrompue avant lecture du profil affiche une vérification avec Réessayer en cas de panne.", "back": "InscriptionCompte garde woop.onboarding.du, woop.onboarding.verifier et le brouillon. Profil terminé confirmé : marqueurs et brouillon retirés. Déconnexion/suppression : brouillon effacé pour le compte suivant.", "frontVerdict": {"etat": "a_valider"}, "backVerdict": {"etat": "valide", "le": "17-09", "note": "Mémoire d’inscription et client profil testés par verif_inscription.py ; compilation Release réussie. Fermeture puis relance de ce nouveau parcours encore à jouer sur iPhone."}},

  {"id": "qa-14-premiere-seance", "n": 14, "titre": "Compte neuf : première séance jusqu’aux stories", "geste": "Sur un compte Apple dédié au test neuf, finir une séance avec une série réelle, suivre les annonces et la story, ouvrir le coffre ; relancer puis revenir le lendemain.", "front": "Au départ, collection et gains vides. Après la séance, ses propres pièces et son sachet, annonces cohérentes, story adaptée, widgets mis à jour ; gains conservés à la relance, accueil du lendemain cohérent. Tirage de carte qualifié avec la session Forge.", "back": "Même identité, synchronisation atomique avant gain ; absente/partielle/incohérente503, étrangère403. Rejeu idempotent et reprise hors ligne. Parcours Apple/iPhone complet reste à mesurer.", "frontVerdict": {"etat": "a_valider"}, "backVerdict": {"etat": "a_valider", "le": "18-09", "note": "Migration déployée.51 contrôles Compte et35 gains/progression PASS sur comptes jetables,13 Outbox et12 sync Swift PASS ; compilation Debug partagée réussie. Release isolée bloquée par dépendances front antérieures hors Compte ; voir build-isole.log. Le parcours physique ne se déduit pas de ces bancs."}},
  {"id": "qa-15-compte-existant", "n": 15, "titre": "Compte existant : conserver et retrouver son historique", "geste": "Après la session chauffe, comparer la session iPhone au profil serveur et inventorier les séances locales, synchronisées et en attente. Préserver l’historique avant tout test de déconnexion ; vérifier ensuite relance et reconnexion.", "front": "Les séances, pièces, sachets et cartes de ce compte restent les siennes. L’inscription ne rejoue pas ; les données d’un autre compte n’apparaissent pas.", "back": "Identité identique sur iPhone et serveur ; différences d’historique expliquées, file de synchronisation rattrapée, aucune écriture attribuée au mauvais compte. Le test n’efface pas le compte personnel.", "frontVerdict": {"etat": "a_valider"}, "backVerdict": {"etat": "a_valider", "le": "18-09", "note": "Lecture seule : le profil Apple au prénom connu porte une séance ouverte, aucune terminée ; préfixe différent du test du 14-09. Les ~38 séances du téléphone ne sont pas réconciliées. Ce constat ne prouve pas une perte. tools/production/preuves-2026-09-18/backend.json"}},
  {
    id: 'qa-route-compte-vide', n: 17, titre: 'Compte neuf : le premier galet',
    geste: 'Avec un compte sans séance terminée, ouvrir Route, revenir puis relancer l’app et rouvrir Route.',
    front: 'Chapitre1 tout en haut, premier galet actif, aucun galet fait ni date passée. Récompenses à venir.',
    back: 'Zéro séance terminée : EcranSpec rend étape0, faits[] et dates[:]. Aucune séance ni récompense créée pour meubler la route.',
    frontVerdict: { etat: 'a_valider', note: 'Correctif18-09 non installé sur iPhone ; la session chauffe conserve le téléphone.' },
    backVerdict: { etat: 'a_valider', note: '1074 contrôles de calcul/lecture Swift PASS de0à36séances ;35 API PASS jusqu’au trésor final. Correspondance compte/iPhone encore à confirmer.' },
  },
  {"id": "qa-18-chauffe-parcours", "n": 18, "titre": "Chauffe : Profil, stories, manège, carte et séance", "geste": "Depuis un iPhone nominal, parcourir Profil, stories complètes, manège3D et carte, puis revenir à l’accueil plusieurs minutes ; rejouer avec séance en cours et écouteurs. Interrompre le stress si iOS atteint serious.", "front": "Gestes et rendu conservés, moteurs rendus hors écran, récupération sans charge persistante après fermeture.", "back": "Aucune séance ni ouverture de booster de production créée par le diagnostic ; historique et écouteurs conservés.", "frontVerdict": {"etat": "ko", "le": "18-09", "note": "18-09 : Release76 installée. Parcours physique Profil/stories/booster/carte67,505s et manège/retour normal35,585s PASS. Arrêts haptiques booster et carte observés ; gyro stories rendu. Home après carte CPU5% sur9lignes/8,2s, thermique1. Endurance SKIP au départ non nominal ; seconde passe sonde0→1. BTLEServer environ97% d’un cœur app arrêtée sur75. Chauffe durable, séance prolongée et confort avec écouteurs restent ouverts. tools/perf/campagnes/2026-09-18-chauffe75-profil-manege/etat.md"}, "backVerdict": {"etat": "a_valider", "note": "Campagne locale de rendu ; aucune validation backend ou de gains déduite."}},
]
