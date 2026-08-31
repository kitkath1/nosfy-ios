/**
 * LA VÉRITÉ DE LA SOURCE — content/briques.ts, content/serveur.ts, content/mesures.ts
 * (les enregistrements typés Brique / Mesure de content/types.ts) et content/schemas/.
 *
 *  - ids uniques (une pastille = UN enregistrement, rendu partout) ;
 *  - titre ≤ 60 caractères, sans emoji ;
 *  - une preuve `fichier` pointe un fichier qui EXISTE dans le dépôt, et ses `lignes`
 *    ne dépassent pas la longueur du fichier — la preuve se lit, elle ne se déduit pas ;
 *  - chaque .svg de content/schemas porte <!-- mmd:<sha1> --> du .mmd qu'il rend
 *    (même méthode que scripts/schemas.mjs) : un SVG périmé est refusé.
 *
 * Les trois fichiers n'existent pas encore (J1) : leurs tests SAUTENT tant qu'ils sont
 * absents, ils ne passent pas. Ils sont chargés dynamiquement pour que `tsc` et vitest
 * tournent sans eux.
 */
import { describe, it, expect, beforeAll } from 'vitest'
import { existsSync, readFileSync, readdirSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'
import { createHash } from 'node:crypto'
import type { Brique, Mesure, Preuve } from '../content/types'

const SITE = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const RACINE = resolve(SITE, '..', '..')
const CONTENU = join(SITE, 'content')
const SCHEMAS = join(CONTENU, 'schemas')
const FICHIERS = ['briques', 'serveur', 'mesures'] as const
type Fichier = (typeof FICHIERS)[number]
type Enreg = Brique | Mesure

const EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{23E9}-\u{23FA}\u{FE0F}]/u
const sha1 = (s: string) => createHash('sha1').update(s).digest('hex').slice(0, 12)
const chemin = (f: Fichier) => join(CONTENU, f + '.ts')
const presents = FICHIERS.filter((f) => existsSync(chemin(f)))
const absents = FICHIERS.filter((f) => !existsSync(chemin(f)))

const estEnreg = (x: unknown): x is Enreg =>
  !!x && typeof x === 'object' && typeof (x as Enreg).id === 'string' && typeof (x as Enreg).titre === 'string' && 'preuve' in (x as object)

/** Tous les tableaux d'enregistrements exportés par un fichier de content/, quel que soit leur nom. */
async function charger(f: Fichier): Promise<Enreg[]> {
  const module: Record<string, unknown> = await import(/* @vite-ignore */ pathToFileURL(chemin(f)).href)
  return Object.values(module).flatMap((v) => (Array.isArray(v) && v.length && v.every(estEnreg) ? (v as Enreg[]) : []))
}

const nbLignes = (texte: string) => texte.split('\n').length - (texte.endsWith('\n') ? 1 : 0)
const formeDePreuve = (p: Preuve) => ['fichier', 'sonde', 'git', 'aCiter'].filter((k) => k in p)

describe.skipIf(!presents.length)(`content/ (${presents.join(', ') || 'aucun fichier'}${absents.length ? ` — absents : ${absents.join(', ')}` : ''})`, () => {
  const parFichier = new Map<Fichier, Enreg[]>()
  let tous: Enreg[] = []

  beforeAll(async () => {
    for (const f of presents) parFichier.set(f, await charger(f))
    tous = [...parFichier.values()].flat()
  })

  it('chaque fichier présent exporte au moins un tableau de briques', () => {
    for (const f of presents) expect(parFichier.get(f)?.length, `${f}.ts : aucun tableau Brique[] / Mesure[] exporté`).toBeGreaterThan(0)
  })

  it('les ids sont uniques (sur les trois fichiers)', () => {
    const vus = new Map<string, number>()
    for (const e of tous) vus.set(e.id, (vus.get(e.id) ?? 0) + 1)
    const doublons = [...vus].filter(([, n]) => n > 1).map(([id, n]) => `${id} ×${n}`)
    expect(doublons, doublons.join(', ')).toEqual([])
    for (const e of tous) expect(e.id, `id vide`).toMatch(/^[a-z0-9][a-z0-9-]*$/)
  })

  it('titre ≤ 60 caractères, sans emoji, JAMAIS coupé par …', () => {
    const longs = tous.filter((e) => [...e.titre].length > 60).map((e) => `${e.id} (${[...e.titre].length})`)
    const emojis = tous.filter((e) => EMOJI.test(e.titre)).map((e) => e.id)
    // ⚠️ 30-08 soir : la migration avait TRONQUÉ 12 titres à 60 caractères en collant un « … » à la fin
    // (« Le set défini à un seul endroit (Swift + Deno + totaux du… ») — illisibles, et la colonne avait
    // 600 px de vide à droite. Un titre se RÉÉCRIT court ; il ne se coupe pas.
    const coupes = tous.filter((e) => /…\s*$/.test(e.titre)).map((e) => e.id)
    expect(longs, 'titres > 60 : ' + longs.join(', ')).toEqual([])
    expect(emojis, 'titres avec emoji : ' + emojis.join(', ')).toEqual([])
    expect(coupes, 'titres coupés par … (à réécrire, pas à tronquer) : ' + coupes.join(', ')).toEqual([])
  })

  it('chaque preuve a UNE forme (fichier · sonde · git · aCiter)', () => {
    const fautives = tous.filter((e) => formeDePreuve(e.preuve).length !== 1).map((e) => `${e.id} → ${JSON.stringify(e.preuve)}`)
    expect(fautives, fautives.join('\n')).toEqual([])
  })

  it('preuve.fichier existe dans le dépôt, et lignes ≤ longueur du fichier', () => {
    const manquants: string[] = []
    const horsFichier: string[] = []
    for (const e of tous) {
      if (!('fichier' in e.preuve)) continue
      const abs = join(RACINE, e.preuve.fichier)
      if (!existsSync(abs)) { manquants.push(`${e.id} → ${e.preuve.fichier}`); continue }
      if (!e.preuve.lignes) continue
      const numeros = (e.preuve.lignes.match(/\d+/g) ?? []).map(Number)
      const max = Math.max(0, ...numeros)
      const total = nbLignes(readFileSync(abs, 'utf8'))
      if (!numeros.length) horsFichier.push(`${e.id} → lignes « ${e.preuve.lignes} » illisibles`)
      else if (max > total) horsFichier.push(`${e.id} → ${e.preuve.fichier}:${e.preuve.lignes} (le fichier a ${total} lignes)`)
    }
    const fautes = [...manquants.map((m) => 'absent : ' + m), ...horsFichier.map((h) => 'lignes : ' + h)]
    expect(fautes, 'preuves qui ne se lisent pas :\n' + fautes.join('\n')).toEqual([])
  })
})

describe('content/schemas', () => {
  const mmd = existsSync(SCHEMAS) ? readdirSync(SCHEMAS).filter((f) => f.endsWith('.mmd')).sort() : []
  const svg = existsSync(SCHEMAS) ? readdirSync(SCHEMAS).filter((f) => f.endsWith('.svg')).sort() : []

  it('il y a des .mmd', () => { expect(mmd.length).toBeGreaterThan(0) })

  it('chaque .svg porte <!-- mmd:<sha1> --> de son .mmd', () => {
    const perimes: string[] = []
    for (const f of mmd) {
      const id = f.replace(/\.mmd$/, '')
      const s = join(SCHEMAS, id + '.svg')
      if (!existsSync(s)) { perimes.push(`${id} : pas de SVG — npm run schemas -- --only ${id}`); continue }
      const attendu = `<!-- mmd:${sha1(readFileSync(join(SCHEMAS, f), 'utf8'))} -->`
      const premiere = readFileSync(s, 'utf8').split('\n')[0].trim()
      if (premiere !== attendu) perimes.push(`${id} : SVG périmé (${premiere.slice(0, 24)} ≠ ${attendu})`)
    }
    expect(perimes, perimes.join('\n')).toEqual([])
  })

  it('aucun .svg orphelin (sans .mmd)', () => {
    const orphelins = svg.filter((s) => !mmd.includes(s.replace(/\.svg$/, '.mmd')))
    expect(orphelins, orphelins.join(', ')).toEqual([])
  })

  it.skipIf(!existsSync(join(SCHEMAS, 'index.json')))('index.json et les .mmd se répondent', () => {
    const index = JSON.parse(readFileSync(join(SCHEMAS, 'index.json'), 'utf8')) as { id: string }[]
    const ids = index.map((s) => s.id).sort()
    const fichiers = mmd.map((f) => f.replace(/\.mmd$/, ''))
    expect(ids.filter((id) => !fichiers.includes(id)), 'dans index.json sans .mmd').toEqual([])
    expect(fichiers.filter((id) => !ids.includes(id)), '.mmd hors index.json').toEqual([])
  })
})
