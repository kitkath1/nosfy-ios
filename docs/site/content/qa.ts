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
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur avant son test : auth.users = 1 (le banc) ; le journal du téléphone n\'a pas été lu (Wi-Fi)' },
  },
  {
    id: 'qa-02-apple', n: 2, titre: 'Apple : la création du compte',
    geste: 'Toucher « Se connecter avec Apple », valider la feuille native avec son Apple ID.',
    front: 'La feuille Apple, puis la porte se dissout dans le flou et le film de Nosfy commence — c\'est une NOUVELLE.',
    back: 'Serveur : auth.users +1 (provider apple, sans e-mail — on ne demande rien à Apple). `profil()` → existe=false → journal `[PORTE] verdict = NOUVELLE → onboarding`. L\'authorizationCode part à `apple-jeton` : journal `[compte] apple-jeton → 503 cle_absente — on entre quand même` (sa clé .p8 n\'est pas posée), donc aucune ligne dans apple_jetons.',
    frontVerdict: { etat: 'valide', le: '14-09', note: 'la feuille, puis le film — son retour ne dit rien contre' },
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur à 09:40 : auth.users 0fac947b, provider apple, email null, 1 session, apple_jetons 0 (cohérent avec cle_absente) ; la ligne [PORTE] du journal non lue' },
  },
  {
    id: 'qa-03-nosfy', n: 3, titre: 'Nosfy : langue, prénom, le reste',
    geste: 'Choisir la langue, donner son prénom (obligatoire), le but, l\'objectif hebdo, puis « Entrer ».',
    front: 'Le film dans la langue choisie ; sans prénom, l\'input passe au rouge et « Passer » n\'existe pas ; la pop-up de fin (« Allez <prénom>, go ») lisible, en grand ; à « Entrer », la cérémonie de connexion (les braises) puis la home.',
    back: '`definir_profil(langue, prenom, but, objectif)` : profils (langue, prenom, but, onboarding_termine_at posé), user_prefs (objectif). Journal `[NOSFY] definir_profil → existe=true onboarding_termine=true prenom=…`. Cache : woop.langue, woop.prenom, woop.premiere_fois=true.',
    frontVerdict: { etat: 'ko', le: '14-09', note: 'son retour : « tout est bien en anglais ou en français selon mon choix, comme le nombre d\'exercices choisis : top » — MAIS la pop-up de fin « Allez <prénom>, go » a la taille de police CASSÉE, trop petite : « ça doit être plus gros » (session porte)' },
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur à 09:41 : profils prenom « Kiki Style », langue fr, but force, onboarding_termine_at 09:41:36 ; user_prefs objectif 7 (changé ensuite dans la chambre)' },
  },
  {
    id: 'qa-04-home-vide', n: 4, titre: 'La home de la première fois',
    geste: 'Regarder la home qui arrive après Nosfy, sans rien toucher, trois secondes.',
    front: 'La phrase dans SA langue avec SON prénom (fr : « Hey X, / et si on faisait / ta première / séance ? »), les widgets vides (la loi du vide), la card ROUTE « CHAPITRE 1 · Commence ton entraînement › » (en : « Start your workout ») qui VIT (la lampe du bord respire, un reflet traverse le titre, une onde naît du galet du jour, le fond de verre respire). AUCUN Welcome Back. Trois secondes après la home — un peu plus si home() est lent — la pop-up « Bienvenue » / « Welcome » : la vidéo de Nosfy qui saute sur les galets, « Laisse Nosfy te guider : séances, progrès, récompenses. », CTA « Commencer » / « Start ». Et la home doit rester FLUIDE.',
    back: '`home()` → premiere_fois=true, visite_home=false, langue, phrases dans sa langue ; `etat_coffre.retour_disponible=false` (S4 : aucune séance finie). Journal `[home-serveur] home() → … première fois true · visite false`, `[home-serveur] phrases → active, active_zero, seance, seance_debut, vide`, `[welcome-back] retenue : première arrivée (c\'est Nosfy qui parle)`. La porte de la pop-up (app) : woop.welcome.premiere.vue faux ET premiere_fois vrai ET visite_home faux ET aucun manège ni pop-up du Sacre ouverts.',
    frontVerdict: { etat: 'ko', le: '14-09', note: 'VALIDÉ par elle : « j\'arrive bien sur la home vide, nickel avec la bonne langue, le bon nom, tout est empty même les widgets ». KO : « tout lag énormément sur la home » — à mesurer sur son iPhone (skill woop-performance, sonde -sondeVol / -fps) ; suspect n° 1 par la loi mesurée du 05-09 (verre animé = 60 → 14 img/s) : la card ROUTE vivante et le fond de verre qui respire (59a5c77), dans ce binaire' },
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur : profil complet et 0 séance → premiere_fois vrai, retour_disponible faux par construction (S4) ; les lignes [home-serveur] / [welcome-back] du journal non lues' },
  },
  {
    id: 'qa-05-widgets', n: 5, titre: 'Les widgets : le détail et l\'objectif',
    geste: 'Toucher un widget pour ouvrir sa chambre ; dans Regularity, changer l\'objectif de la semaine ; revenir.',
    front: 'La chambre s\'ouvre en glissant, fluide ; ses parties sont GRISES (rien des deux côtés : défi « — », pics à zéro) ; l\'objectif se choisit (3 → 10) avec un petit check blanc « pris en compte » et une haptique, et le mini-widget suit au retour ; la chambre se referme au geste et rend la home.',
    back: 'La chambre lit `widget_regularite(\'semaine\')` etc. (journal `[chambre-serveur] widget_… →`) ; le choix écrit `definir_objectif(n)` → user_prefs.objectif_hebdo (journal `[chambre-serveur] definir_objectif(n) → n`) ; la clé locale `objectifHebdo` suit.',
    frontVerdict: { etat: 'ko', le: '14-09', note: 'son retour : « ça bug quand je veux cliquer sur le détail des widgets et l\'overlay n\'est pas fluide » ; « je peux changer le nombre de 4 à 7 et ça update bien dans le mini widget » ✓ ; « il manque un petit feedback comme quoi c\'est pris en compte : la pastille devient blanche par exemple, plus une haptique » — à corriger (session back-end : la chambre)' },
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur à 09:4x : user_prefs.objectif_hebdo = 7 pour son compte — le choix de la chambre est bien arrivé' },
  },
  {
    id: 'qa-06-visite', n: 6, titre: 'La visite guidée',
    geste: '« Commencer » sur la pop-up, puis suivre les quatre temps (ou « Passer », ou toucher l\'objet net).',
    front: 'La brume : la home s\'enfonce dans le noir flouté, l\'objet net en sort, les mots se disent mot après mot — « Commencer. » (la card ROUTE entière), « Tes progrès. » (les widgets), « Ton profil. » (le glyphe Profil de la nav), « Tes pièces. » (la pièce du trésor en haut à droite), chacun avec sa sourde ; sous les mots « Touche pour continuer », puis « Touche pour commencer » au dernier ; « Passer » en haut à gauche ; un tic clair à chaque temps, la paillette à la fin ; une vibration lourde à l\'entrée et à la fin, moyenne à chaque suivant. Toucher l\'objet net termine aussi la visite, l\'objet répond derrière. À la fin : la home telle quelle, la brume levée en 0,8 s.',
    back: '`marquer_visite_home()` part de `finirVisite()` dans les TROIS sorties (dernier tap, « Passer », traversée), une fois : profils.visite_home_le posé, `home().visite_home=true`. Journal `[premiere-arrivee] marquer_visite_home() → répondu (la date est posée au serveur)` ou `a échoué : …`. Cache : woop.welcome.premiere.vue passe à vrai à la fermeture de la pop-up (avant la visite) — la pop-up ne rejoue pas localement même si l\'app est tuée pendant la visite ; la visite, elle, rejoue au prochain lancement tant que visite_home est faux au serveur.',
    frontVerdict: { etat: 'a_valider', note: 'son premier retour ne dit rien de la pop-up ni de la visite — à lui demander' },
    backVerdict: { etat: 'valide', le: '14-09', note: 'lu au serveur : profils.visite_home_le = 09:42:02, 26 s après la fin de Nosfy — marquer_visite_home() est bien parti de l\'app' },
  },
  {
    id: 'qa-07-profil', n: 7, titre: 'Le profil à son prénom',
    geste: 'Onglet Profil, puis la roue des Réglages.',
    front: 'La bannière : le rond à ses initiales, son prénom, « @prenom » en minuscules, Level 1 ; les Réglages : son prénom, « 0 pièces lune · Level 1 », « Se déconnecter », les CGU, « Supprimer mon compte » en rouge. Plus jamais « Kathryn », « KD » ni « @kathrynd ».',
    back: 'Rien au serveur : la page lit le cache woop.prenom (= profils.prenom, posé par definir_profil et rafraîchi par home()).',
    frontVerdict: { etat: 'ko', le: '14-09', note: 'son retour : « je ne peux pas aller dans la page profil pour voir le nom, ça ne marche pas (je pense bug de latence) » — l\'onglet ne répond pas après le passage par la chambre ; à reproduire (une chambre restée montée qui avale les taps ? le lag ?) ; au simulateur la page rendait « Jetable », rond « J », « @jetable » (capG4)' },
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
