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
    geste: 'Ouvrir Woop après une installation propre (aucun argument, aucune session).',
    front: 'Le mini splash (la lune de sang), puis la porte : le film d\'arrivée, le carrousel, « Se connecter avec Apple ». Aucune pop-up, aucun Welcome Back.',
    back: 'Aucune session gardée (`SupabaseSession.sessionGardee()` faux : pas d\'identité Apple, rien au Keychain). Journal : aucune ligne `[home-serveur]`, `[welcome-back] retenue : la porte, le film ou le splash tient l\'écran`. Serveur : auth.users ne porte que le compte du banc.',
    frontVerdict: { etat: 'valide', le: '14-09', note: 'son premier retour : « de la partie login à la fin de l\'onboarding », rien à redire sur la porte' },
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur avant son test : auth.users = 1 (le banc) ; 2e passage 15:30, journal par le câble : `[welcome-back] retenue : la porte, le film ou le splash tient l\'écran` ×3 sous la porte, aucune ligne [home-serveur]' },
  },
  {
    id: 'qa-02-apple', n: 2, titre: 'Apple : la création du compte',
    geste: 'Toucher « Se connecter avec Apple », valider la feuille native avec son Apple ID.',
    front: 'La feuille Apple, puis la porte se dissout dans le flou et le film de Nosfy commence — c\'est une NOUVELLE.',
    back: 'Serveur : auth.users +1 (provider apple, sans e-mail — on ne demande rien à Apple). `profil()` → existe=false → journal `[PORTE] verdict = NOUVELLE → onboarding`. L\'authorizationCode part à `apple-jeton` : journal `[compte] apple-jeton → 503 cle_absente — on entre quand même` (sa clé .p8 n\'est pas posée), donc aucune ligne dans apple_jetons.',
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
    frontVerdict: {"etat": "ko", "le": "15-09", "note": "15-09,23:02 : build34 Release réellement installé, CPU Home médian1 % pendant180,7s,164 relevés après15s. 76 relevés nominal0 et88 thermique1 ; retour nominal à143,1s. Cadence60,1 callbacks/s,17ms maximum. Le petit point des séances entretenait un repeatForever SwiftUI : même33, thermique1/protection1, souffle actif12 % CPU(n12), seul souffle posé1 %(n20).34 conserve sa respiration avec deux petites textures et Core Animation ; onde du Chapitre et chevrons visibles. 3 retours du pull puis Profil PASS35,164s ; navigation complète PASS9,231s. 4 cycles Exercices/Profil PASS66,481s ; dernières75s de récupération Home1 % CPU, thermique1. Chauffe ressentie prolongée et première arrivée sans compte restent à confirmer : QA04 ouverte. 35 compilé avec branchement autonome pour les commits, installation refusée23:28 (liaison CoreDevice indisponible), non validé sur téléphone. Dernière installation confirmée34, compteurs éteints23:02:12. Registre56 entrées, preuves tools/perf/campagnes/2026-09-15-reprise-autonome/etat.md."},
    backVerdict: { etat: 'valide', le: '14-09', note: '2e passage 15:33, journal par le câble : `[home-serveur] home() → prénom Kathryn · 0 / 3, reste 3 · en séance false · 0 séances en tout · première fois true · visite false · langue en`, `[home-serveur] phrases → active, active_zero, seance, seance_debut, vide`, `[welcome-back] retenue : première arrivée (c\'est Nosfy qui parle)` — la règle tient des deux côtés' },
  },
  {
    id: 'qa-05-widgets', n: 5, titre: 'Les widgets : le détail et l\'objectif',
    geste: 'Toucher un widget pour ouvrir sa chambre ; dans Regularity, changer l\'objectif de la semaine ; revenir.',
    front: 'La chambre s\'ouvre en glissant, fluide ; ses parties sont GRISES (rien des deux côtés : défi « — », pics à zéro) ; l\'objectif se choisit (3 → 10) avec un petit check blanc « pris en compte » et une haptique, et le mini-widget suit au retour ; la chambre se referme au geste et rend la home.',
    back: 'La chambre lit `widget_regularite(\'semaine\')` etc. (journal `[chambre-serveur] widget_… →`) ; le choix écrit `definir_objectif(n)` → user_prefs.objectif_hebdo (journal `[chambre-serveur] definir_objectif(n) → n`) ; la clé locale `objectifHebdo` suit.',
    frontVerdict: { etat: 'valide', le: '14-09', note: '1er passage : « ça bug quand je clique sur le détail, l\'overlay n\'est pas fluide » (téléphone chaud) ; « je peux changer le nombre et ça update bien dans le mini widget » ; « il manque un feedback : pastille blanche + haptique » → fait (pastille blanche, haptique .medium). 2e passage 15:35, build à jour : « les étapes 1 à 6 sont ok niveau front et back »' },
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
    frontVerdict: {"etat": "valide", "le": "15-09", "note": "Build34 installé, version réelle relue sur l’iPhone. Home → Exercices → Home → Profil → Réglages PASS9,231s ; 4 cycles Exercices/Profil avec défilement PASS66,481s ; 3 retours du pull puis Profil PASS35,164s. Aucun appui sur Se déconnecter ou Supprimer mon compte, aucune séance démarrée. Valide l’accès et les retours ; cycle complet du compte et chauffe ressentie prolongée non validés.35 compile mais installation refusée faute de liaison. Preuves : tools/perf/campagnes/2026-09-15-reprise-autonome/etat.md."},
    backVerdict: { etat: 'valide', le: '14-09', note: 'rien à lire au serveur ; profils.prenom = « Kiki Style », c\'est ce que la page doit dire' },
  },
  {
    id: 'qa-08-relance', n: 8, titre: 'La relance : la home direct',
    geste: 'Tuer l\'app (balayer), la rouvrir.',
    front: 'Le mini splash, puis la home DIRECT : pas de porte, pas de feuille Apple, pas de pop-up (déjà vue), pas de Welcome Back, sa phrase avec son prénom.',
    back: 'La session gardée (identité Apple + refresh au Keychain) se rafraîchit en silence. Journal : `[home-serveur] home() → …` sans aucune ligne `[PORTE]` ; `[welcome-back] retenue : première arrivée`. Serveur : auth.sessions du compte ≥ 1.',
    frontVerdict: { etat: 'a_valider' },
    backVerdict: { etat: 'a_valider', note: 'mesuré au simulateur le 14-09 : relance sans argument → home, home() répond (capture capB)' },
  },
  {
    id: 'qa-09-deconnexion', n: 9, titre: 'Se déconnecter',
    geste: 'Réglages → « Se déconnecter ».',
    front: '« Déconnexion… » sur la ligne, puis la porte revient (le carrousel, sans le film d\'entrée). Plus rien à elle sur le téléphone.',
    back: '`POST /auth/v1/logout?scope=global` : auth.sessions du compte = 0. Le téléphone : 14 clés effacées (prénom, langue, phrases, première fois, pop-up vue, visite faite, objectif, pull, chemin, outbox…), SwiftData vide, Keychain vide. Journal `[session] logout → le refresh est révoqué au serveur`, `[compte] effacé : 14 clés, les séances, la chambre, l\'économie`, `[compte] la porte est rendue (deconnexion)`.',
    frontVerdict: { etat: 'a_valider' },
    backVerdict: { etat: 'a_valider', note: 'mesuré au simulateur le 14-09 (`-deconnexionAuto`, capture capC : sessions 0, plist vide)' },
  },
  {
    id: 'qa-10-reconnexion', n: 10, titre: 'Se reconnecter : un compte connu',
    geste: 'Sur la porte, « Se connecter avec Apple » à nouveau, même Apple ID.',
    front: 'La feuille Apple, puis DIRECT la cérémonie de connexion et la home — pas de Nosfy. Sa phrase avec son prénom, la pop-up ne rejoue pas (la visite est faite au serveur).',
    back: '`profil()` → onboarding_termine=true → journal `[PORTE] verdict = CONNUE → app`. Le pull : `[pull] seances_depuis(tout) → total 0`. `home().visite_home=true` → `[welcome-back] retenue : première arrivée` (toujours aucune séance).',
    frontVerdict: { etat: 'a_valider' },
    backVerdict: { etat: 'a_valider', note: 'l\'aiguillage CONNUE mesuré le 13-09 (b0d4727) ; à relire sur son téléphone après une vraie déconnexion' },
  },
  {
    id: 'qa-11-suppression', n: 11, titre: 'Supprimer mon compte',
    geste: 'Réglages → « Supprimer mon compte » → l\'alerte → « Supprimer ».',
    front: '« Suppression… » sur la ligne, puis la porte revient. Rouvrir l\'app : la porte encore.',
    back: 'Edge `supprimer-compte` → `{ ok: true, revocation: "aucun_jeton" }` (sans clé .p8, aucun refresh Apple n\'a pu être rangé). Serveur : auth.users sans la ligne, profils / workouts / user_prefs emportés par la cascade. Le téléphone : tout effacé, comme à la déconnexion. Journal `[compte] supprimer-compte → ok · révocation Apple : aucun_jeton`, `[compte] la porte est rendue (suppression)`.',
    frontVerdict: { etat: 'a_valider' },
    backVerdict: { etat: 'a_valider', note: 'mesuré au simulateur le 14-09 (`-suppressionAuto`, capture capF : auth.users et profils sans la ligne)' },
  },
]
