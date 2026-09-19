import type { DomaineInfo, PageInfo } from './types'

/**
 * Les huit pages du site, dans l'ordre du rail. Le hero d'une page de domaine porte la
 * teinte MESURÉE de la capture qu'il montre (tools/docsite/palette.py — H et S mesurés,
 * V posé à 62 pour tous) ; un écran sans couleur mesurable, ou sans capture, reste noir.
 * Quand tout y est branché et que rien n'y ment, le hero passe au VERT (--ok) — la règle
 * des cards de l'accueil, rendue sur la page (tranché le 30-08 ; aucune page n'y est).
 *
 * 30-08 : « Économie & annonces » (id `regles`) est devenue DEUX pages, « Le coffre » et
 * « Les annonces » — tools/annonces/PLAN-COFFRE-ANNONCES.md §0 et §7. Le coffre garde la
 * capture et la teinte mesurée de l'ancienne page ; les annonces n'ont pas de capture.
 */
export const PAGES: PageInfo[] = [
  { id: 'etat', libelle: 'État', glyphe: 'gauge', phrase: 'Ce qui marche, ce qui ment, ce qui manque.' },
  { id: 'serveur', libelle: 'Serveur', glyphe: 'server', phrase: 'Tout ce qui existe côté Supabase, et si l\'app s\'en sert.' },
  {
    id: 'flow', libelle: 'Flow', glyphe: 'route',
    phrase: 'Deux entrées — la séance, la balade — et cinq écarts avec le code.',
    hero: {
      capture: 'tools/road/shots/j4-home-serpentin.png',
      teinte: { t1: '#9E4503', t2: '#9E2300', source: 'j4-home-serpentin.png · #8F3F02 h26 S99 (2e #661700) · V posé à 62', part: 9.21 },
    },
  },
  {
    // 13-09 — demandé par Kathryn (« une section dédiée aux widgets et à leur back-end ») : les quatre
    // widgets de la home, leurs chambres, leurs données, et les fonctions serveur qui les recalculent.
    id: 'widgets', libelle: 'Widgets', glyphe: 'widgets',
    phrase: 'Le téléphone et le serveur comptent pareil — mesuré ; la chambre lit le serveur quand le téléphone n\'a rien.',
    hero: { capture: null },
  },
  {
    id: 'coffre', libelle: 'Le coffre', glyphe: 'coins',
    phrase: 'Le solde se dérive, le sachet naît à 100, et le profil montre tout, même à 0.',
    hero: {
      capture: 'tools/coffre-v2/ARCHIVE/coffre-v1.jpg',
      teinte: { t1: '#9E6928', t2: '#9E4809', source: 'coffre-v1.jpg (v1, à re-mesurer sur la capture v2) · #5F3F18 h33 S75 (2e #5E2B06) · V posé à 62', part: 2.67 },
    },
  },
  {
    id: 'annonces', libelle: 'Les annonces', glyphe: 'bell',
    phrase: 'Une annonce par événement ; à la clôture elles s\'empilent.',
    hero: { capture: null },
  },
  {
    id: 'forge', libelle: 'Cartes', glyphe: 'flame',
    phrase: 'Trois univers, 14 scènes publiées, 50 prévues. Un catalogue commun à tous ; shiny animé et endurance restent ouverts.',
    hero: {
      capture: 'Nosfy/Assets.xcassets/booster-orange.imageset/booster-orange.png',
      teinte: { t1: '#9E3610', t2: '#9E5425', source: 'booster-orange.png (l\'objet du domaine) · #60210A h16 S90 (2e #924E23) · V posé à 62', part: 5.81 },
    },
  },
  {
    id: 'histoire', libelle: 'Stories', glyphe: 'book',
    phrase: 'Le serveur calcule les records à la clôture ; les pages attendent de les lire.',
    hero: { capture: null },
  },
  {
    id: 'porte', libelle: 'Compte', glyphe: 'user',
    phrase: 'De la première connexion au compte retrouvé.',
    hero: {
      capture: 'Nosfy/Assets.xcassets/onb-lune-loop-poster.imageset/onb-lune-loop-poster.jpg',
      teinte: { t1: '#9E501B', t2: '#9E7238', source: 'onb-lune-loop-poster.jpg (le 1er écran de la porte est la lune) · #703913 h26 S83 (2e #DA9F4F) · V posé à 62', part: 9.63 },
      lune: true,
    },
  },
  {
    // 14-09 — demandé par Kathryn (« crée un onglet Test QA avec ce flow qu'on valide ensemble
    // niveau front et back ») : le compte de bout en bout, une étape par ligne, deux verdicts.
    id: 'qa', libelle: 'Test QA', glyphe: 'check',
    phrase: 'Le compte, du login à la suppression : ce qu\'elle voit, ce que le serveur tient, validé ensemble.',
    hero: { capture: null },
  },
]

export const DOMAINES: DomaineInfo[] = [
  { id: 'compte', libelle: 'Compte', badge: 'CO', page: 'porte' },
  { id: 'sync', libelle: 'Sync', badge: 'SY', page: 'histoire' },
  { id: 'widgets', libelle: 'Widgets', badge: 'WI', page: 'widgets' },
  { id: 'eco', libelle: 'Économie', badge: 'ÉC', page: 'coffre' },
  { id: 'annonces', libelle: 'Annonces', badge: 'AN', page: 'annonces' },
  { id: 'forge', libelle: 'Cartes', badge: 'CA', page: 'forge' },
  { id: 'chemin', libelle: 'Calendrier · chemin', badge: 'CH', page: 'flow' },
  { id: 'stories', libelle: 'Stories', badge: 'ST', page: 'histoire' },
]

export const PAGE_PAR_ID = Object.fromEntries(PAGES.map((p) => [p.id, p])) as Record<PageInfo['id'], PageInfo>
export const DOMAINE_PAR_ID = Object.fromEntries(DOMAINES.map((d) => [d.id, d])) as Record<DomaineInfo['id'], DomaineInfo>
