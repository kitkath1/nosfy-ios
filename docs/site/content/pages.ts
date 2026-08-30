import type { DomaineInfo, PageInfo } from './types'

/**
 * Les sept pages du site, dans l'ordre du rail. Le hero d'une page de domaine porte la
 * teinte MESURÉE de la capture qu'il montre (tools/docsite/palette.py — H et S mesurés,
 * V posé à 62 pour tous) ; un écran sans couleur mesurable, ou sans capture, reste noir.
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
    id: 'regles', libelle: 'Économie & annonces', glyphe: 'bell',
    phrase: 'Les prix vivent en base ; le rythme des annonces, lui, est encore décidé par trois modulos.',
    hero: {
      capture: 'tools/coffre-v2/ARCHIVE/coffre-v1.jpg',
      teinte: { t1: '#9E6928', t2: '#9E4809', source: 'coffre-v1.jpg (v1, à re-mesurer sur la capture v2) · #5F3F18 h33 S75 (2e #5E2B06) · V posé à 62', part: 2.67 },
    },
  },
  {
    id: 'forge', libelle: 'Forge', glyphe: 'flame',
    phrase: 'La forge est déployée et sait tout faire — l\'app ne lui dit jamais quel sachet elle ouvre.',
    hero: {
      capture: 'Woop/Assets.xcassets/booster-orange.imageset/booster-orange.png',
      teinte: { t1: '#9E3610', t2: '#9E5425', source: 'booster-orange.png (l\'objet du domaine) · #60210A h16 S90 (2e #924E23) · V posé à 62', part: 5.81 },
    },
  },
  {
    id: 'histoire', libelle: 'Stories', glyphe: 'book',
    phrase: 'Les pages sont peintes ; rien ne calcule encore un record.',
    hero: { capture: null },
  },
  {
    id: 'porte', libelle: 'Compte', glyphe: 'user',
    phrase: 'Sans compte, tout le back-end rend zéro.',
    hero: {
      capture: 'Woop/Assets.xcassets/onb-lune-loop-poster.imageset/onb-lune-loop-poster.jpg',
      teinte: { t1: '#9E501B', t2: '#9E7238', source: 'onb-lune-loop-poster.jpg (le 1er écran de la porte est la lune) · #703913 h26 S83 (2e #DA9F4F) · V posé à 62', part: 9.63 },
      lune: true,
    },
  },
]

export const DOMAINES: DomaineInfo[] = [
  { id: 'compte', libelle: 'Compte', badge: 'CO', page: 'porte' },
  { id: 'sync', libelle: 'Sync', badge: 'SY', page: 'histoire' },
  { id: 'eco', libelle: 'Économie', badge: 'ÉC', page: 'serveur' },
  { id: 'annonces', libelle: 'Annonces', badge: 'AN', page: 'regles' },
  { id: 'forge', libelle: 'Forge', badge: 'FO', page: 'forge' },
  { id: 'chemin', libelle: 'Calendrier · chemin', badge: 'CH', page: 'flow' },
  { id: 'stories', libelle: 'Stories', badge: 'ST', page: 'histoire' },
]

export const PAGE_PAR_ID = Object.fromEntries(PAGES.map((p) => [p.id, p])) as Record<PageInfo['id'], PageInfo>
export const DOMAINE_PAR_ID = Object.fromEntries(DOMAINES.map((d) => [d.id, d])) as Record<DomaineInfo['id'], DomaineInfo>
