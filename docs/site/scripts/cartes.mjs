// Aperçus documentaires uniquement : aucun recadrage, éclaircissement ou PNG source modifié.
// Rejouer depuis docs/site : node scripts/cartes.mjs
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { resolve, dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createHash } from 'node:crypto'
import sharp from 'sharp'
const site = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const root = resolve(site, '../..')
const manifest = JSON.parse(readFileSync(join(root, 'tools/carte-lune/familles-2026-09-18.json'), 'utf8'))
const output = join(site, 'public/cartes')
mkdirSync(output, { recursive: true })
const families = []
const seen = new Set()
let bytes = 0
for (const family of manifest.families) {
  const cards = []
  for (const card of family.cards) {
    if (seen.has(card.key)) throw new Error(`Référence dupliquée : ${card.key}`)
    seen.add(card.key)
    const original = readFileSync(join(root, card.art))
    if (createHash('sha256').update(original).digest('hex') !== card.sha256) throw new Error(`Original modifié : ${card.key}`)
    const filename = `${family.key}-${card.key}.avif`
    const { data, info } = await sharp(original).resize({ width: 224, withoutEnlargement: true }).avif({ quality: 34, effort: 6 }).toBuffer({ resolveWithObject: true })
    writeFileSync(join(output, filename), data)
    bytes += data.length
    cards.push({ key: card.key, name: card.name, rarity: card.rarity, src: `/cartes/${filename}`, width: info.width, height: info.height })
  }
  families.push({ key: family.key, name: family.name, signature: family.signature.join(' · '), cards })
}
writeFileSync(join(site, 'content/cartes.json'), JSON.stringify(families, null, 2) + '\n')
console.log(`${families.length} familles · ${seen.size} aperçus · ${bytes} octets · originaux vérifiés et conservés`)
