// Exécute les fonctions ET le branchement pool/neuf du fichier déployable.
// Aucun réseau, aucune carte peinte, aucune écriture de compte.
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import vm from 'node:vm'
import assert from 'node:assert/strict'

const require = createRequire(new URL('../../../docs/site/package.json', import.meta.url))
const ts = require('typescript')
const source = readFileSync(new URL('../../../supabase/functions/forge-card/index.ts', import.meta.url), 'utf8')
const definitions = source.slice(source.indexOf('type Famille ='), source.indexOf('// ── La forge'))
const choix = source.slice(source.indexOf('    // ── Pool ou neuf ?'), source.indexOf('      const [logo, ancre]'))
const code = `${definitions}\nasync function choisir(corps, rareteImposee, admin) {
${choix}
return { rarete: famille.rarete, famille: famille.nom, neuf: true };
} return { ...carte, neuf: false };
}`
const context = vm.createContext({ Math: Object.create(Math), Deno: { env: { get: () => 'test' } } })
vm.runInContext(ts.transpileModule(code, { compilerOptions: { target: ts.ScriptTarget.ES2022 } }).outputText, context)

async function tirer(r, branche, pool, imposee = null, corps = {}) {
  const aleas = imposee ? [branche, 0.999] : [r, branche, 0.999]
  context.Math.random = () => aleas.shift() ?? 0.999
  const admin = { from: () => ({ select: () => ({ eq: (_, rarete) => ({ data: pool.filter(c => c.rarete === rarete) }) }) }) }
  return await context.choisir(corps, imposee, admin)
}
const raretes = ['common', 'rare', 'epic', 'legendary']
const pool = raretes.map(rarete => ({ rarete, id: rarete }))
for (const [nom, branche, catalogue] of [['pool', 0.9, pool], ['neuve', 0.1, pool], ['pool vide', 0.9, []]]) {
  const comptes = Object.fromEntries(raretes.map(r => [r, 0]))
  for (let i = 0; i < 10000; i++) {
    const carte = await tirer((i + 0.5) / 10000, branche, catalogue)
    comptes[carte.rarete]++
  }
  assert.deepEqual(comptes, { common: 6000, rare: 2700, epic: 1000, legendary: 300 })
  console.log(`PASS ${nom} : 60 / 27 / 10 / 3 sur 10 000 tirages déterministes`)
}
for (const catalogue of [pool, []]) {
  for (const branche of [0.1, 0.9]) {
    assert.equal((await tirer(0, branche, catalogue, 'legendary')).rarete, 'legendary')
  }
}
assert.equal((await tirer(0, 0.1, [], 'legendary', { famille: 'Une Lune' })).rarete, 'legendary')
console.log('PASS garantie légendaire, avec pool, neuf, pool vide et famille incompatible')
