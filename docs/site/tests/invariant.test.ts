/**
 * L'INVARIANT DU LIVRABLE — docs/site/index.html, lu tel qu'il sera ouvert.
 *
 * Ce que le grep de verifier.sh v1 vérifiait à l'œil, ici en refus : le compte des
 * pastilles = data-attendu (plus une de légende par état), la robe (pas d'emoji dans
 * un titre, ≤ 4 flous, graisses 300-600, pas de date relative), l'autonomie (pas de
 * /_next/, un seul <script>, pas de CDN, pas de Mermaid au runtime), les animations
 * (≤ 3 @keyframes, jamais un flou en transition), le poids (< 2 Mo).
 * Un livrable qui échoue ici ne se commite pas et ne se republie pas.
 */
import { describe, it, expect } from 'vitest'
import { existsSync, readFileSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const SITE = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const LIVRABLE = join(SITE, 'index.html')
const html = existsSync(LIVRABLE) ? readFileSync(LIVRABLE, 'utf8') : ''

const ETATS = ['ok', 'loc', 'srv', 'abs', 'men'] as const
/** Les blocs emoji (🟢🟡🔵⚪🔴🧨🧭🚩⛔⚠️🎴⏱️⏳🧗…) — jamais dans un titre. */
const EMOJI = /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{23E9}-\u{23FA}\u{FE0F}]/u
const POIDS_MAX = 2_000_000

const compter = (re: RegExp, texte = html) => (texte.match(re) ?? []).length
const sansBalises = (s: string) => s.replace(/<[^>]+>/g, '')

describe('le livrable', () => {
  it('existe', () => {
    expect(existsSync(LIVRABLE), `${LIVRABLE} absent : npm run artefact`).toBe(true)
    expect(html.length).toBeGreaterThan(0)
  })

  it('pèse moins de 2 000 000 octets', () => {
    expect(Buffer.byteLength(html)).toBeLessThan(POIDS_MAX)
  })
})

describe("l'invariant des pastilles", () => {
  it('compte de contenu = data-attendu (+ 1 de légende par état)', () => {
    const section = html.match(/<section\b[^>]*\bid="etat"[^>]*>/)?.[0]
    expect(section, '<section id="etat"> introuvable').toBeDefined()
    const attendu = Number(section!.match(/\bdata-attendu="(\d+)"/)?.[1])
    expect(attendu, 'data-attendu manquant sur #etat').toBeGreaterThan(0)

    // la légende : une occurrence par état, hors contenu
    const legendes = [...html.matchAll(/<(\w+)\b[^>]*\bclass="[^"]*\blegende\b[^"]*"[^>]*>([\s\S]*?)<\/\1>/g)].map((m) => m[2]).join('\n')
    const detail: Record<string, number> = {}
    let total = 0
    for (const k of ETATS) {
      const brut = compter(new RegExp(`class="p p-${k}\\b`, 'g'))
      const legende = compter(new RegExp(`class="p p-${k}\\b`, 'g'), legendes)
      expect(legende, `légende ${k} : ${legende} occurrences (≤ 1)`).toBeLessThanOrEqual(1)
      detail[k] = brut - legende
      total += brut - legende
    }
    expect(total, `pastilles de contenu ${JSON.stringify(detail)} = ${total} ≠ data-attendu ${attendu}`).toBe(attendu)
  })
})

describe('la robe', () => {
  it('0 emoji dans h1 / h2 / h3', () => {
    const fautifs = [...html.matchAll(/<h([123])\b[^>]*>([\s\S]*?)<\/h\1>/g)]
      .map((m) => sansBalises(m[2]).trim())
      .filter((t) => EMOJI.test(t))
    expect(fautifs, fautifs.join(' | ')).toEqual([])
  })

  it('backdrop-filter ≤ 4 règles', () => {
    expect(compter(/(?<!-)backdrop-filter\s*:/g)).toBeLessThanOrEqual(4)
  })

  it('graisses ⊆ {300, 400, 500, 600}', () => {
    // les SVG pré-rendus portent la feuille de Mermaid (allégée par schemas.mjs) : on juge la robe de la PAGE
    const sansSvg = html.replace(/<svg[\s\S]*?<\/svg>/g, '')
    const valeurs = [...sansSvg.matchAll(/font-weight\s*:\s*([a-z0-9]+)/g)].map((m) => m[1])
    const permises = new Set(['300', '400', '500', '600'])
    const fautives = [...new Set(valeurs.filter((v) => !permises.has(v)))]
    expect(fautives, `graisses hors robe : ${fautives.join(', ')}`).toEqual([])
  })

  it('0 date relative (« depuis aujourd\'hui », « posé aujourd\'hui », « ce matin »)', () => {
    const trouves = html.match(/depuis aujourd|pos[ée]e? aujourd|répar[ée]e? aujourd|ce matin/gi) ?? []
    expect(trouves, trouves.join(' | ')).toEqual([])
  })
})

describe("l'autonomie", () => {
  it('0 « /_next/ »', () => { expect(compter(/\/_next\//g)).toBe(0) })
  it('≤ 1 <script', () => { expect(compter(/<script\b/gi)).toBeLessThanOrEqual(1) })
  it('0 « cdn. »', () => { expect(compter(/cdn\./g)).toBe(0) })
  it('0 « %%{init » (pas de Mermaid au runtime)', () => { expect(compter(/%%\{init/g)).toBe(0) })
  it('0 classDef', () => { expect(compter(/\bclassDef\b/g)).toBe(0) })
})

describe('les animations', () => {
  it('≤ 3 @keyframes (hors SVG)', () => { expect((html.replace(/<svg[\s\S]*?<\/svg>/g, '').match(/@keyframes\b/g) ?? []).length).toBeLessThanOrEqual(3) })
  it('0 transition sur un filtre', () => {
    const fautives = html.match(/transition\s*:[^;{}]*filter/g) ?? []
    expect(fautives, fautives.join(' | ')).toEqual([])
  })
})
