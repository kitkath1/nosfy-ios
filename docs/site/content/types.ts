/**
 * LE TYPE QUI EMPÊCHE DE MENTIR.
 *
 * Une pastille est UN enregistrement, écrit une fois, rendu partout. Sa preuve est
 * obligatoire : une brique sans `preuve` ne compile pas. Un état ne se déduit pas —
 * il se lit (`fichier:ligne`) ou se mesure (une sonde HTTP avec son témoin).
 * Les « à mesurer » (◌) sont des `Mesure` : elles n'ont PAS d'état, seulement ce
 * que le code laisse lire — elles ne sont jamais peintes tant qu'on n'a pas mesuré.
 */

/** 🟢 branché · 🟡 local · 🔵 serveur seul · ⚪ absent · 🔴 ment */
export type Etat = 'ok' | 'loc' | 'srv' | 'abs' | 'men'

/** Les huit domaines de l'accueil (les cards) — indépendants des pages. 13-09 : `widgets`. */
export type Domaine = 'eco' | 'chemin' | 'stories' | 'annonces' | 'forge' | 'compte' | 'sync' | 'widgets'

/**
 * Les huit pages du site (v2). Le 30-08, « Économie & annonces » (id `regles`) est devenue
 * DEUX pages : `coffre` (pièces, sachets, argent, profil) et `annonces` (dalles, pop-ups,
 * Welcome Back, le rythme) — tools/annonces/PLAN-COFFRE-ANNONCES.md §7.
 */
export type Page = 'etat' | 'serveur' | 'flow' | 'widgets' | 'coffre' | 'annonces' | 'forge' | 'histoire' | 'porte' | 'qa'

/**
 * LE TEST QA (14-09) — une étape du flow de bout en bout, validée ENSEMBLE : le front (ce
 * qu'elle voit sur son téléphone) et le back (ce que le serveur ou le téléphone tient, lu
 * par moi). Un verdict par côté ; « à valider » tant que personne n'a vu ni lu.
 */
export type VerdictQA = {
  etat: 'a_valider' | 'valide' | 'ko'
  /** la date du verdict (« 14-09 ») */
  le?: string
  /** ce qui a été vu / lu, ou pourquoi c'est KO */
  note?: string
}
export interface EtapeQA {
  id: string
  n: number
  titre: string
  /** le geste qu'elle fait */
  geste: string
  /** ce qu'elle doit voir */
  front: string
  /** ce que le serveur / le téléphone doit tenir, et comment on le lit */
  back: string
  frontVerdict: VerdictQA
  backVerdict: VerdictQA
}

/** ⏱️ une heure · ⏳ une journée · 🧗 un chantier */
export type Cout = '1 h' | '1 j' | 'chantier'

/** Le genre d'une ligne de la carte du serveur. */
export type Genre = 'table' | 'fonction' | 'index' | 'regle' | 'edge'

/**
 * La preuve. Quatre formes, jamais une cinquième :
 *  - un fichier (et ses lignes) lu dans le dépôt ;
 *  - une sonde HTTP réellement lancée, avec sa réponse ;
 *  - un fait git (un fichier non suivi, un commit) ;
 *  - la dette VISIBLE : « preuve à citer » — jamais silencieuse.
 */
export type Preuve =
  | { fichier: string; lignes?: string }
  | { sonde: string; reponse: string }
  | { git: string }
  | { aCiter: true }

export interface Brique {
  /** l'ancre : `b-<slug>` — les id posés dans la v1 sont repris tels quels */
  id: string
  /** ≤ 60 caractères, sans emoji (testé) */
  titre: string
  /** où elle est POSÉE ; ailleurs elle est rendue par <Brique id/> */
  page: Page
  domaine: Domaine
  etat: Etat
  preuve: Preuve
  cout?: Cout
  /** ⚑ le fait qui contredit l'état — l'état RESTE, la rangée porte l'anneau pointillé */
  litige?: string
  /** ≤ 160 caractères, le défaut en une phrase */
  note?: string
  /** pour la carte du serveur */
  genre?: Genre
  nom?: string
  quoi?: string
  valeur?: string
  /** true = ne pas lister dans la to-do (une ligne de référence, pas un chantier) */
  reference?: boolean
}

/** ◌ « à mesurer » : ce que le code laisse lire — JAMAIS un état peint. */
export interface Mesure {
  id: string
  titre: string
  page: Page
  domaine: Domaine
  /** ce que la lecture du code suggère, entre parenthèses sur la rangée */
  lecture?: Etat | 'inconnu'
  preuve: Preuve
  cout?: Cout
  note?: string
}

export interface Sonde {
  id: string
  requete: string
  reponse: string
  prouve: string
}

export interface Schema {
  id: string
  page: Page
  titre: string
  legende?: string
  /** replié par défaut (les schémas secondaires d'une page) */
  plie?: boolean
}

export interface DomaineInfo {
  id: Domaine
  libelle: string
  badge: string
  /** l'onglet vers lequel la card d'accueil mène */
  page: Page
}

export interface PageInfo {
  id: Page
  libelle: string
  /** la phrase : le fait qui commande, une par page */
  phrase: string
  glyphe: string
  hero?: {
    /** la capture montrée (chemin depuis la racine du dépôt), ou null = hero noir */
    capture: string | null
    /** la teinte MESURÉE par tools/docsite/palette.py — jamais choisie */
    teinte?: { t1: string; t2: string; source: string; part: number }
    /** la lune au centre (Compte) */
    lune?: boolean
  }
}
