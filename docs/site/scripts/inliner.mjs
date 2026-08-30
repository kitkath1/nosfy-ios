#!/usr/bin/env node
/**
 * L'INLINER — de l'export Next (out/index.html) au LIVRABLE : UN fichier autonome.
 *
 *   node scripts/inliner.mjs                          # out/index.html → index.html
 *   node scripts/inliner.mjs --in <out> --out <html>  # pour un banc (l'export factice)
 *   node scripts/inliner.mjs --public <dir> --js <site.js>
 *
 * Next.js n'est qu'un COMPILATEUR (plan v2 §1) : on ne sert jamais out/. Ce script
 *  (a) retire TOUS les <script> (runtime Next, payload RSC self.__next_f…) et les
 *      <link rel="preload"/"modulepreload"/"preconnect"…> ;
 *  (b) inline chaque <link rel="stylesheet" href="/_next/static/css/…"> en <style> ;
 *  (c) remplace les url(/_next/static/media/….woff2) et url(/…) des CSS par des data URI ;
 *  (d) remplace les <img src="/captures/…"> (public/) par des data URI ;
 *  (e) inline public/site.js — le SEUL script — juste avant </body> ;
 *  (f) garantit <meta charset="utf-8"> en tête et conserve <title> ;
 *  (g) retire les attributs Next (data-nscript, data-precedence…) et le bruit RSC <!--$--> ;
 *  (h) REFUSE (exit 1) s'il reste « /_next/ », « cdn. », plus d'un <script>, une
 *      requête réseau (src/href/url() en http), ou si le fichier pèse > 2 000 000 o.
 * Déterministe : rien ne dépend de l'heure ; deux runs = le même fichier, octet pour octet.
 * Zéro dépendance : Node seul.
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs'
import { join, dirname, resolve, extname } from 'node:path'
import { fileURLToPath } from 'node:url'

const SITE = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const args = process.argv.slice(2)
const option = (cle, defaut) => { const i = args.indexOf(cle); return i >= 0 && args[i + 1] ? resolve(args[i + 1]) : defaut }
const IN = option('--in', join(SITE, 'out'))
const OUT = option('--out', join(SITE, 'index.html'))
const PUBLIC = option('--public', join(SITE, 'public'))
const SITE_JS = option('--js', join(SITE, 'public', 'site.js'))
const POIDS_MAX = 2_000_000

const MIME = {
  '.woff2': 'font/woff2', '.woff': 'font/woff', '.ttf': 'font/ttf', '.otf': 'font/otf',
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png', '.gif': 'image/gif',
  '.webp': 'image/webp', '.avif': 'image/avif', '.svg': 'image/svg+xml', '.ico': 'image/x-icon',
  '.mp4': 'video/mp4', '.webm': 'video/webm', '.css': 'text/css',
}

const compteurs = {
  scripts: 0, links: 0, css: 0, cssOctets: 0, urls: 0, urlsOctets: 0, images: 0, imagesOctets: 0,
  attributs: 0, commentaires: 0, meta: 0,
}
const notes = []
const refus = (message) => { console.error('✗ inliner : ' + message); process.exit(1) }

/** Un chemin absolu du site (/_next/…, /captures/…) → le fichier sur disque : out/ d'abord, public/ ensuite. */
function fichierLocal(chemin) {
  const propre = decodeURIComponent(chemin.replace(/[?#].*$/, ''))
  const candidats = propre.startsWith('/_next/') ? [join(IN, propre)] : [join(IN, propre), join(PUBLIC, propre)]
  const trouve = candidats.find((c) => existsSync(c))
  if (!trouve) refus(`fichier introuvable pour « ${chemin} » (cherché : ${candidats.join(' · ')})`)
  return trouve
}

function dataUri(chemin) {
  const f = fichierLocal(chemin)
  const mime = MIME[extname(f).toLowerCase()]
  if (!mime) refus(`type inconnu pour « ${chemin} » (${extname(f)})`)
  const octets = readFileSync(f)
  return { uri: `data:${mime};base64,${octets.toString('base64')}`, octets: octets.length }
}

const estLocal = (u) => u.startsWith('/') && !u.startsWith('//')
const estReseau = (u) => /^(https?:)?\/\//i.test(u)

/**
 * Les url(…) d'un texte CSS (feuille ou attribut style) → data URI.
 *  - url(/…) : absolu du site (out/ puis public/) ;
 *  - url(../media/x.woff2) : RELATIF au fichier CSS (c'est ainsi que Turbopack écrit
 *    les polices de next/font : mesuré sur le chunk 2n8k1qcy4jo47.css) — résolu depuis
 *    `base`, le dossier de la feuille ; sans base, laissé tel quel (refusé à la fin).
 *  Jamais touchés : data:, #ancre (les dégradés des SVG), %23 (une ancre dans un data URI).
 */
function inlinerUrls(texte, base = null) {
  return texte.replace(/url\(\s*(['"]?)([^'")\s]+)\1\s*\)/g, (m, q, u) => {
    if (/^(data:|#|%23|https?:|\/\/)/i.test(u)) return m
    let fichier
    if (u.startsWith('/')) fichier = fichierLocal(u)
    else if (base) { fichier = resolve(base, u.replace(/[?#].*$/, '')); if (!existsSync(fichier)) refus(`url relative introuvable : ${u} (depuis ${base})`) }
    else return m
    const mime = MIME[extname(fichier).toLowerCase()]
    if (!mime) refus(`type inconnu pour « ${u} » (${extname(fichier)})`)
    const octets = readFileSync(fichier)
    compteurs.urls++; compteurs.urlsOctets += octets.length
    return `url(data:${mime};base64,${octets.toString('base64')})`
  })
}

/** Un src / srcset / poster local d'une balise média → data URI. */
function inlinerMedia(tag) {
  return tag.replace(/\b(src|srcset|poster)="([^"]*)"/g, (m, attr, valeur) => {
    if (attr === 'srcset') {
      const parts = valeur.split(',').map((p) => {
        const [u, ...desc] = p.trim().split(/\s+/)
        if (!estLocal(u)) return p.trim()
        const { uri, octets } = dataUri(u); compteurs.images++; compteurs.imagesOctets += octets
        return [uri, ...desc].join(' ')
      })
      return `srcset="${parts.join(', ')}"`
    }
    if (!estLocal(valeur)) return m
    const { uri, octets } = dataUri(valeur); compteurs.images++; compteurs.imagesOctets += octets
    return `${attr}="${uri}"`
  })
}

function main() {
  const entree = join(IN, 'index.html')
  if (!existsSync(entree)) refus(`pas d'export à lire : ${entree} (npm run build d'abord)`)
  if (!existsSync(SITE_JS)) refus(`site.js introuvable : ${SITE_JS}`)
  let html = readFileSync(entree, 'utf8')

  // (a) tous les scripts — le runtime Next, le payload RSC, les manifestes
  html = html.replace(/<script\b[^>]*>[\s\S]*?<\/script\s*>/gi, () => { compteurs.scripts++; return '' })

  // (a)+(b) les <link> : la feuille devient <style> ; le reste est une requête → retiré
  html = html.replace(/<link\b[^>]*>/gi, (tag) => {
    const rel = (tag.match(/\brel="([^"]*)"/i)?.[1] ?? '').toLowerCase().trim()
    const href = tag.match(/\bhref="([^"]*)"/i)?.[1] ?? ''
    if (rel.split(/\s+/).includes('stylesheet')) {
      if (estReseau(href)) refus(`feuille de style externe : ${href} — tout doit être local`)
      const f = estLocal(href) ? fichierLocal(href) : resolve(IN, href)
      if (!existsSync(f)) refus(`feuille introuvable : ${href}`)
      const css = readFileSync(f, 'utf8')
      if (/<\/style/i.test(css)) refus(`la feuille ${href} contient « </style » — impossible à inliner`)
      compteurs.css++; compteurs.cssOctets += Buffer.byteLength(css)
      return `<style>${inlinerUrls(css, dirname(f))}</style>`   // les url() relatives se résolvent depuis la feuille, pas depuis la page
    }
    if (/\b(?:icon|apple-touch-icon)\b/.test(rel) && estLocal(href)) {
      const { uri } = dataUri(href); compteurs.links++
      return tag.replace(/\bhref="[^"]*"/i, `href="${uri}"`)
    }
    compteurs.links++
    if (!/\b(?:preload|modulepreload|prefetch|preconnect|dns-prefetch|prerender)\b/.test(rel)) notes.push('link retiré : ' + tag)
    return ''
  })

  // (c) les url(/…) — dans les <style> inlinés comme dans les attributs style="…"
  html = inlinerUrls(html)

  // (d) les médias locaux
  html = html.replace(/<(?:img|source|video|audio)\b[^>]*>/gi, inlinerMedia)

  // (g) le bruit Next / RSC
  html = html.replace(/\s(?:data-nscript|data-precedence|data-n-g|data-n-p|data-href|nonce)(?:="[^"]*")?(?=[\s/>])/g, () => { compteurs.attributs++; return '' })
  html = html.replace(/<meta\s+name="next-size-adjust"[^>]*>/gi, () => { compteurs.meta++; return '' })
  html = html.replace(/<!--(?:\$|\/\$|\$\?|\$!| )-->/g, () => { compteurs.commentaires++; return '' })

  // (f) charset en tête, <title> conservé
  html = html.replace(/<meta\s+charset="[^"]*"\s*\/?>/gi, '')
  if (!/<head\b[^>]*>/i.test(html)) refus('pas de <head> dans l\'export')
  html = html.replace(/<head\b[^>]*>/i, (m) => m + '<meta charset="utf-8">')
  const titre = html.match(/<title\b[^>]*>([\s\S]*?)<\/title>/i)
  if (!titre) refus('pas de <title> : le livrable n\'aurait pas de nom (artefact, onglet)')

  // (e) le seul script
  const js = readFileSync(SITE_JS, 'utf8')
  if (/<\/script/i.test(js)) refus('site.js contient « </script » — impossible à inliner')
  const balise = `<script>\n${js.trimEnd()}\n</script>\n`
  html = /<\/body\s*>/i.test(html) ? html.replace(/<\/body\s*>(?![\s\S]*<\/body)/i, balise + '</body>') : html + balise
  if (!html.endsWith('\n')) html += '\n'

  // (h) les refus — le livrable est autonome ou il n'est pas
  const nb = (re) => (html.match(re) ?? []).length
  const poids = Buffer.byteLength(html)
  const scripts = nb(/<script\b/gi)
  const reseau = [
    ...(html.match(/\b(?:src|poster)="(?:https?:)?\/\/[^"]*"/gi) ?? []),
    ...(html.match(/<link\b[^>]*\bhref="(?:https?:)?\/\/[^"]*"/gi) ?? []),
    ...(html.match(/url\(\s*['"]?(?:https?:)?\/\/[^)]*\)/gi) ?? []),
    ...(html.match(/@import\s+[^;]+/gi) ?? []),
  ]
  const restes = nb(/\/_next\//g), cdn = nb(/cdn\./g)
  const urlsNues = html.match(/url\(\s*['"]?(?!data:|#|%23)[^'")\s]+['"]?\s*\)/gi) ?? []   // une url() qui n'est ni data: ni #ancre = une requête, ou un chemin mort

  console.log(`inliner : ${entree}`)
  console.log(`   retirés  : ${compteurs.scripts} <script> · ${compteurs.links} <link> · ${compteurs.attributs} attributs Next · ${compteurs.commentaires} commentaires RSC · ${compteurs.meta} meta`)
  console.log(`   inlinés  : ${compteurs.css} feuille(s) (${compteurs.cssOctets} o) · ${compteurs.urls} url() (${compteurs.urlsOctets} o) · ${compteurs.images} média(s) (${compteurs.imagesOctets} o) · site.js (${Buffer.byteLength(js)} o)`)
  console.log(`   titre    : ${titre[1].trim()}`)
  for (const n of notes) console.log('   ⚠ ' + n)
  console.log(`   livrable : ${OUT} · ${poids} o (${(poids / 1e6).toFixed(2)} Mo) · ${scripts} <script>`)

  if (restes) refus(`il reste ${restes} « /_next/ » dans le livrable`)
  if (cdn) refus(`il reste ${cdn} « cdn. » dans le livrable`)
  if (scripts > 1) refus(`${scripts} <script> — un seul est permis (site.js)`)
  if (reseau.length) refus(`requête(s) réseau : ${reseau.slice(0, 3).join(' · ')}`)
  if (urlsNues.length) refus(`url() non inlinée(s) : ${urlsNues.slice(0, 3).join(' · ')}`)
  if (poids > POIDS_MAX) refus(`${poids} o > ${POIDS_MAX} — on baisse la qualité JPEG, jamais le nombre de captures`)

  mkdirSync(dirname(OUT), { recursive: true })
  writeFileSync(OUT, html)
  console.log('   ✔ écrit')
}

main()
