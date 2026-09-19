import type { Brique, Domaine, Etat, Mesure, Page } from './types'
import { SERVEUR } from './serveur'
import { BRIQUES } from './briques'
import { MESURES } from './mesures'
import { PAGES, DOMAINES } from './pages'
import { ETAPES_QA } from './qa'

export { PAGES, DOMAINES, MESURES, SERVEUR, BRIQUES, ETAPES_QA }
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

/**
 * LES QUATRE FAMILLES (30-08, retour de Kathryn : « je veux savoir ce que JE dois faire ») — ce qu'on LIT
 * à l'accueil, défini par QUI AGIT. Les cinq états et les ◌ restent la vérité de la source ; ils sont
 * REGROUPÉS à l'affichage, jamais supprimés :
 *   à trancher          — elle          : une ◌ (ou une brique) qui attend SA décision — le titre commence par
 *                                          « Trancher », « Définir », « Décider », ou porte « décision ① » (le
 *                                          renvoi à un panneau « … décisions t'attendent » d'une page) ;
 *   à valider ensemble  — elle et moi   : 🔴 l'écran affirme ce que le code ne fait pas ;
 *   en chantier         — moi           : 🟡 local + 🔵 serveur seul + ⚪ absent + les autres ◌ à mesurer, et
 *                                          une 🟢 qui porte un litige (le site et le code se contredisent : à relire) ;
 *   bon                 — personne      : 🟢 branché et vérifié.
 * Une décision DÉJÀ prise (« décision du 30-08 », « tranché le 30-08 » dans une note ou un litige) n'est pas
 * à trancher : c'est du chantier — aligner le code sur la décision.
 */
export type Famille = 'trancher' | 'valider' | 'chantier' | 'bon'
export const FAMILLES: Famille[] = ['trancher', 'valider', 'chantier', 'bon']
/** Le mot du compteur (le hero) et le mot de la ligne (les cards) — « 2 à trancher · 6 à valider · 9 en chantier · 25 bons ». */
export const LIBELLE_FAMILLE: Record<Famille, string> = { trancher: 'à trancher', valider: 'à valider ensemble', chantier: 'en chantier', bon: 'bon' }
export const LIBELLE_LIGNE: Record<Famille, (n: number) => string> = {
  trancher: () => 'à trancher', valider: () => 'à valider', chantier: () => 'en chantier', bon: (n) => (n > 1 ? 'bons' : 'bon'),
}
/** Qui agit — la légende du pied. */
export const QUI_AGIT: Record<Famille, string> = { trancher: 'toi', valider: 'toi et moi', chantier: 'moi', bon: 'personne' }
/** L'ordre des états DANS « en chantier » : local, serveur seul, absent (puis les ◌, puis les litiges). */
export const ORDRE_CHANTIER: Etat[] = ['loc', 'srv', 'abs']
const A_TRANCHER = /^(Trancher|Définir|Décider)\b|\bdécision [①-⑩]/u

export function famille(x: Brique | Mesure): Famille {
  if (A_TRANCHER.test(x.titre)) return 'trancher'
  if (!('etat' in x)) return 'chantier'                       // une ◌ : ce que le code laisse lire, à mesurer
  if (x.etat === 'men') return 'valider'
  if (x.etat === 'ok') return x.litige ? 'chantier' : 'bon'
  return 'chantier'
}

export type Familles = { trancher: number; valider: number; chantier: number; bon: number; mesurer: number; total: number }
/**
 * Le compte par famille, briques ET mesures — `mesurer` dit combien de ◌ (elles comptent dans trancher ou chantier).
 * Les lignes `reference: true` NE COMPTENT PAS (30-08 soir) : c'est le détail d'une to-do déjà comptée — les compteurs
 * du hero, les cards et les groupes de la liste disent ainsi LE MÊME nombre (88 ≠ 55 au premier rendu : payé).
 * Le témoin `data-attendu` (compter().total) reste le compte de TOUTES les pastilles rendues, lui.
 */
export function compterFamilles(briques: Brique[] = TOUTES, mesures: Mesure[] = MESURES): Familles {
  const f: Familles = { trancher: 0, valider: 0, chantier: 0, bon: 0, mesurer: 0, total: 0 }
  for (const b of briques) { if (b.reference) continue; f[famille(b)]++; f.total++ }
  for (const m of mesures) { f[famille(m)]++; f.mesurer++; f.total++ }
  return f
}
/** « 2 à trancher · 6 à valider · 9 en chantier · 25 bons » — les zéros ne s'écrivent pas. */
export const ligneFamilles = (f: Familles) => FAMILLES.filter((k) => f[k]).map((k) => `${f[k]} ${LIBELLE_LIGNE[k](f[k])}`)

/** Le VERT : tout bon — UNE règle, pour les cards de l'accueil, le hero de l'accueil et le hero d'une page. */
export const estVert = (f: Familles) => f.total > 0 && f.bon === f.total

/** La famille d'un GROUPE (une card, un hero) : ≥ 1 à trancher blanche · ≥ 1 à valider rouge · tout bon verte · sinon en chantier. */
export function familleDe(f: Familles): Famille {
  if (f.trancher || f.valider) return f.valider > f.trancher ? 'valider' : 'trancher'
  if (estVert(f)) return 'bon'
  return 'chantier'
}
/** Le badge d'une card : les DEUX mots quand la card cumule — « 1 à trancher · 6 à valider ». */
export function badge(f: Familles): string {
  const p: string[] = []
  if (f.trancher) p.push(`${f.trancher} à trancher`)
  if (f.valider) p.push(`${f.valider} à valider`)
  return p.length ? p.join(' · ') : estVert(f) ? 'tout est bon' : 'en chantier'
}
/** La teinte d'une card de domaine : la même règle, sur les briques d'un domaine. */
export function teinteDomaine(d: Domaine): Famille {
  return familleDe(compterFamilles(parDomaine(d), MESURES.filter((m) => m.domaine === d)))
}
/**
 * Le compte d'une PAGE — briques ET ◌, hors lignes de référence.
 *
 * ⚠️ C'est l'unité des cards de l'accueil depuis le 30-08 soir. Avant, elles comptaient par DOMAINE et
 * ouvraient la page du domaine : mesuré au navigateur, la card « Économie » annonçait « 1 à valider »
 * en rouge et menait au « Coffre », dont le hero disait « tout est en chantier, rien à faire pour toi »
 * — la brique en cause (`etat_coffre()` à la home) est du domaine `eco` mais vit sur la page `serveur`.
 * Une card dit maintenant EXACTEMENT ce que sa page contient : la contradiction n'est plus possible.
 */
export const comptePage = (p: Page) => compterFamilles(parPage(p), mesuresPar(p))

/**
 * La phrase d'un hero : ce qui l'attend, ELLE — les DEUX familles quand les deux existent (30-08 soir).
 * Avant, le h1 s'arrêtait à la première : il disait « 3 décisions t'attendent » pendant que le rail, qui
 * additionne les deux, affichait 12 sur la même ligne. Et « TOUT est en chantier » était faux dès qu'une
 * page avait 5 bons sur 8 : on chiffre.
 */
export function verdict(f: Familles): string {
  // les deux familles font UN nombre : le détail est dit par les deux compteurs juste dessous, pas deux fois
  if (f.trancher && f.valider) return `${f.trancher + f.valider} choses t'attendent`
  if (f.trancher) return f.trancher > 1 ? `${f.trancher} décisions t'attendent` : `1 décision t'attend`
  if (f.valider) return `${f.valider} à valider ensemble`
  if (f.chantier) return `${f.chantier} en chantier`
  if (f.bon) return 'Tout est bon.'
  return 'rien à dire'
}

/** Le mot du BADGE d'une card (30-08, Kathryn : « rajoute des indications vert ou rouge ou blanc dans les grosses cards »). */
export const BADGE_FAMILLE: Record<Famille, string> = { trancher: 'à trancher', valider: 'à valider', chantier: 'en chantier', bon: 'bon' }
/** La phrase d'une CARD : courte — le badge dit déjà la famille, la phrase dit la prochaine chose à faire. */
export function verdictCourt(f: Familles): string {
  if (f.trancher && f.valider) return `${f.trancher} à trancher · ${f.valider} à valider`
  if (f.trancher) return f.trancher > 1 ? `${f.trancher} décisions t'attendent` : `1 décision t'attend`
  if (f.valider) return `${f.valider} à valider ensemble`
  if (f.chantier) return 'voir les points ouverts'
  if (f.bon) return 'tout est bon'
  return 'rien à dire'
}
/** Les 🟢 LISTABLES : branchées, sans litige, hors lignes de référence — « ce qui est bon », plié à l'accueil (30-08 soir). */
export const bons = (briques: Brique[] = TOUTES) => briques.filter((b) => !b.reference && b.etat === 'ok' && !b.litige)

/** « 1 h · 1 j · chantier » — un seul vocabulaire, en texte. */
export const coutTexte = (c?: Brique['cout']) => c ?? ''

/** Le texte d'une preuve, à afficher en mono. */
export function preuveTexte(p: Brique['preuve']): { texte: string; vide: boolean } {
  if ('aCiter' in p) return { texte: 'preuve à citer', vide: true }
  if ('fichier' in p) return { texte: p.fichier.split('/').pop()! + (p.lignes ? ':' + p.lignes : ''), vide: false }
  if ('sonde' in p) return { texte: `${p.sonde} → ${p.reponse}`, vide: false }
  return { texte: p.git, vide: false }
}
