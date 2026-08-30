import type { Brique, Domaine, Etat, Mesure, Page } from './types'
import { SERVEUR } from './serveur'
import { BRIQUES } from './briques'
import { MESURES } from './mesures'
import { PAGES, DOMAINES } from './pages'

export { PAGES, DOMAINES, MESURES, SERVEUR, BRIQUES }
export const TOUTES: Brique[] = [...SERVEUR, ...BRIQUES]
export const ETATS: Etat[] = ['men', 'loc', 'srv', 'abs', 'ok']
export const LIBELLE: Record<Etat | 'nm', string> = { ok: 'branché', loc: 'local', srv: 'serveur seul', abs: 'absent', men: 'ment', nm: 'à mesurer' }
export const LIBELLE_PLURIEL: Record<Etat, string> = { ok: 'branchées', loc: 'locales', srv: 'serveur seul', abs: 'absentes', men: 'mentent' }
export const EMOJI: Record<Etat, string> = { ok: '🟢', loc: '🟡', srv: '🔵', abs: '⚪', men: '🔴' }

/** Le compte — sur les enregistrements, jamais tapé. */
export function compter(briques: Brique[] = TOUTES): Record<Etat, number> & { total: number } {
  const c = { ok: 0, loc: 0, srv: 0, abs: 0, men: 0, total: 0 }
  for (const b of briques) { c[b.etat]++; c.total++ }
  return c
}

export const parPage = (page: Page) => TOUTES.filter((b) => b.page === page)
export const parDomaine = (d: Domaine) => TOUTES.filter((b) => b.domaine === d)
export const parId = (id: string) => TOUTES.find((b) => b.id === id)
export const mesuresPar = (page: Page) => MESURES.filter((m) => m.page === page)

/** Ce qui reste à faire : tout ce qui n'est pas 🟢, plus les litiges, plus les ◌. */
export function aFaire(): { briques: Brique[]; mesures: Mesure[] } {
  // `reference: true` = la ligne existe sur sa page mais n'est pas un chantier de plus (le détail d'une
  // to-do agrégée, un symptôme dont la cause est listée, un renvoi) — relecture adverse du 30-08.
  return { briques: TOUTES.filter((b) => !b.reference && (b.etat !== 'ok' || b.litige)), mesures: MESURES }
}

/** La teinte d'une card de domaine : ≥ 1 🔴 rouge · tout 🟢 vert · sinon argent. */
export function teinteDomaine(d: Domaine): 'men' | 'ok' | 'argent' {
  const c = compter(parDomaine(d))
  if (c.men) return 'men'
  if (c.total && c.ok === c.total) return 'ok'
  return 'argent'
}

/** La phrase d'une card ou d'un hero : « 6 briques mentent », « tout est branché »… */
export function verdict(c: ReturnType<typeof compter>, nm = 0): string {
  const br = (n: number) => `${n} brique${n > 1 ? 's' : ''}`
  if (c.men) return `${br(c.men)} ${c.men > 1 ? 'mentent' : 'ment'}`
  if (c.total && c.ok === c.total) return 'tout est branché'
  if (c.loc) return `${br(c.loc)} ${c.loc > 1 ? 'locales' : 'locale'}`
  if (c.abs) return `${br(c.abs)} à écrire`
  if (c.srv) return `${br(c.srv)} sans appelant`
  return nm ? `${nm} à mesurer` : 'rien à dire'
}

/** « 1 h · 1 j · chantier » — un seul vocabulaire, en texte. */
export const coutTexte = (c?: Brique['cout']) => c ?? ''

/** Le texte d'une preuve, à afficher en mono. */
export function preuveTexte(p: Brique['preuve']): { texte: string; vide: boolean } {
  if ('aCiter' in p) return { texte: 'preuve à citer', vide: true }
  if ('fichier' in p) return { texte: p.fichier.split('/').pop()! + (p.lignes ? ':' + p.lignes : ''), vide: false }
  if ('sonde' in p) return { texte: `${p.sonde} → ${p.reponse}`, vide: false }
  return { texte: p.git, vide: false }
}
