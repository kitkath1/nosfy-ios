#!/usr/bin/env node
/**
 * Rend les schémas Mermaid (docs/site/content/schemas/*.mmd) en SVG, À LA BUILD,
 * dans le Chrome déjà installé (puppeteer-core, executablePath — aucun Chromium à
 * télécharger), puis les passe à l'OBSIDIENNE : fond noir dégradé, rayon 12, bordure
 * en dégradé blanc, la couleur d'état = une bille de 6 px au coin du nœud.
 *
 *   npm run schemas                    # ne rend que les .mmd dont le sha1 a changé
 *   npm run schemas -- --force         # tout
 *   npm run schemas -- --only six-1    # un seul (pour REGARDER avant les autres)
 *
 * Pièges Mermaid payés (skill woop-schema §V) : un rendu PAR schéma avec notre propre
 * id (④), le viewBox garanti (⑥), le thème en HEX seulement (⑦). Le SVG écrit porte
 * <!-- mmd:<sha1> --> : un SVG périmé fait échouer `npm run verif`.
 */
import { createHash } from 'node:crypto'
import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs'
import { join, dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import puppeteer from 'puppeteer-core'

const SITE = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const RACINE = resolve(SITE, '..', '..')
const DOSSIER = join(SITE, 'content/schemas')
const MERMAID = join(SITE, 'node_modules/mermaid/dist/mermaid.min.js')
const POLICE = join(SITE, 'fonts/InterVariable-latin.woff2')
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

const args = process.argv.slice(2)
const force = args.includes('--force')
const only = args.includes('--only') ? args[args.indexOf('--only') + 1] : null

const sha1 = (s) => createHash('sha1').update(s).digest('hex').slice(0, 12)

// La couleur d'état, pour la bille (les 5 couleurs du site — jamais un fond).
const BILLES = { ok: '#5FC98C', fait: '#5FC98C', loc: '#E3B341', dit: '#E3B341', srv: '#5AA9E6', neuf: '#5AA9E6', bad: '#E56A6A' }

// La police en data URI : une page posée par setContent (about:blank) n'a pas le droit de lire un file://.
const POLICE_B64 = existsSync(POLICE) ? readFileSync(POLICE).toString('base64') : ''
const PAGE_HTML = `<!doctype html><html><head><meta charset="utf-8">
<style>
@font-face{font-family:Inter;src:url("data:font/woff2;base64,${POLICE_B64}") format("woff2");font-weight:300 700;font-display:block}
body{margin:0;background:#000;font-family:Inter,-apple-system,sans-serif;line-height:1.25}
#atelier{position:absolute;left:0;top:0;width:1200px}
</style></head><body><div id="atelier"></div></body></html>`

/** Injecté dans la page : rend UN schéma et le passe à l'obsidienne, avec le DOM du navigateur. */
const RENDRE = async (id, code, billes) => {
  const m = window.mermaid
  const { svg } = await m.render('woop-' + id, code)
  const boite = document.createElement('div')
  boite.innerHTML = svg
  document.getElementById('atelier').appendChild(boite)   // attaché AVANT toute mesure : getBBox() vaut zéro hors document
  const el = boite.querySelector('svg')
  const sid = el.id

  // ⑥ viewBox garanti, largeur fluide
  if (!el.getAttribute('viewBox')) {
    const w = parseFloat(el.getAttribute('width')), h = parseFloat(el.getAttribute('height'))
    if (w > 0 && h > 0) el.setAttribute('viewBox', `0 0 ${w} ${h}`)
  }
  el.removeAttribute('height'); el.setAttribute('width', '100%')
  el.setAttribute('role', 'img')

  // L'OBSIDIENNE — un <defs> par SVG, ids uniques (Safari ne résout pas un serveur de
  // peinture partagé ; deux SVG à id égal se superposent)
  const ns = 'http://www.w3.org/2000/svg'
  const defs = document.createElementNS(ns, 'defs')
  defs.innerHTML =
    `<linearGradient id="obs-f-${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#121212"/><stop offset="1" stop-color="#000000"/></linearGradient>` +
    `<linearGradient id="obs-b-${id}" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity=".34"/><stop offset="1" stop-color="#ffffff" stop-opacity=".07"/></linearGradient>`
  el.insertBefore(defs, el.firstChild)

  // La feuille de Mermaid, ALLÉGÉE : ses @keyframes (animations d'arêtes, jamais utilisées) et
  // ses graisses 700 partent — la robe n'a que 300-600, et le poids du livrable compte.
  el.querySelectorAll('style').forEach((st) => {
    st.textContent = st.textContent
      .replace(/@keyframes[^{]+\{(?:[^{}]*\{[^}]*\})*[^}]*\}/g, '')
      .replace(/font-weight:\s*(bolder|bold|700|800|900)/g, 'font-weight:500')
      .replace(/font-weight:\s*normal/g, 'font-weight:400')
  })

  // La feuille obsidienne, APRÈS celle de Mermaid (même spécificité → la dernière gagne),
  // scopée sur l'id du SVG pour tenir sans la page.
  const style = document.createElementNS(ns, 'style')
  style.textContent = `
#${sid}{font-family:Inter,-apple-system,sans-serif;background:transparent;line-height:1.25}
#${sid} foreignObject div,#${sid} foreignObject p,#${sid} .nodeLabel,#${sid} .label,#${sid} .edgeLabel{line-height:1.25;margin:0;max-width:none}
#${sid} .node rect,#${sid} .node polygon,#${sid} .node path,#${sid} .node circle,#${sid} .node ellipse,
#${sid} rect.actor,#${sid} .er.entityBox,#${sid} .statediagram-state rect,#${sid} g.stateGroup rect,#${sid} .cluster rect,#${sid} .node .basic{
  fill:url(#obs-f-${id});stroke:url(#obs-b-${id});stroke-width:1px}
#${sid} .node rect,#${sid} rect.actor,#${sid} .er.entityBox,#${sid} .statediagram-state rect,#${sid} g.stateGroup rect{rx:12;ry:12}
#${sid} .node polygon{stroke-linejoin:round}
#${sid} .cluster rect{fill:transparent;stroke:rgba(255,255,255,.08);rx:16;ry:16}
#${sid} .cluster-label,#${sid} .cluster text,#${sid} .cluster span{fill:rgba(255,255,255,.42);color:rgba(255,255,255,.42);font-size:11px;font-weight:500;letter-spacing:.08em;text-transform:uppercase}
#${sid} .nodeLabel,#${sid} .node text,#${sid} .label,#${sid} .label text,#${sid} .stateLabel,#${sid} .er.entityLabel,#${sid} .er.attributeBox text,#${sid} .actor,#${sid} text.actor,#${sid} .actor-box text{
  fill:rgba(255,255,255,.90);color:rgba(255,255,255,.90);font-family:Inter,-apple-system,sans-serif;font-weight:500;font-size:13px}
#${sid} .node.mut .nodeLabel,#${sid} .node.mut text{fill:rgba(255,255,255,.42);color:rgba(255,255,255,.42);font-weight:400}
#${sid} .node.abs rect,#${sid} .node.abs polygon,#${sid} .node.abs path{stroke-dasharray:4 3}
#${sid} .edgePath path,#${sid} .flowchart-link,#${sid} path.path,#${sid} .messageLine0,#${sid} .messageLine1,#${sid} .relationshipLine,#${sid} .transition,#${sid} .edge-thickness-normal,#${sid} .edge-pattern-solid{
  stroke:rgba(255,255,255,.30)!important;stroke-width:1px!important;fill:none}
#${sid} .edge-pattern-dotted,#${sid} .messageLine1{stroke-dasharray:3 3}
#${sid} marker path,#${sid} marker circle{fill:rgba(255,255,255,.45)!important;stroke:none!important}
#${sid} .edgeLabel,#${sid} .edgeLabel p,#${sid} .edgeLabel span,#${sid} .edgeLabel .labelBkg,#${sid} .edgeLabel rect{background:#000;background-color:#000;fill:#000;color:rgba(255,255,255,.55);font-size:11.5px;font-weight:400}
#${sid} .er.attributeBoxOdd{fill:#0A0A0A;stroke:rgba(255,255,255,.08)} #${sid} .er.attributeBoxEven{fill:#0E0E0E;stroke:rgba(255,255,255,.08)}
#${sid} .er.relationshipLabelBox{fill:#000;opacity:1} #${sid} .er.relationshipLabel{fill:rgba(255,255,255,.55);font-size:11.5px}
#${sid} .actor-line,#${sid} line.loopLine,#${sid} .loopLine{stroke:rgba(255,255,255,.18)!important}
#${sid} .note{fill:#0A0A0A!important;stroke:rgba(255,255,255,.12)!important;rx:8;ry:8} #${sid} .noteText,#${sid} .noteText tspan{fill:rgba(255,255,255,.72)!important;font-size:12px}
#${sid} .messageText,#${sid} .sequenceNumber{fill:rgba(255,255,255,.72);font-size:12px}
#${sid} .start-state,#${sid} .end-state,#${sid} circle.state-start{fill:rgba(255,255,255,.90);stroke:none}
#${sid} .statediagram-state .divider,#${sid} .divider{stroke:rgba(255,255,255,.12)}
#${sid} .flowchart-label{font-weight:500}
`
  el.insertBefore(style, el.firstChild)

  // La bille d'état au coin haut-droit de chaque nœud classé.
  el.querySelectorAll('g.node').forEach((g) => {
    const cls = [...g.classList]
    const forme = g.querySelector('rect, polygon, path, circle, ellipse')
    if (!forme) return
    const b = forme.getBBox()
    const etat = cls.find((c) => c in billes || c === 'abs')
    if (!etat) return
    const c = document.createElementNS(ns, 'circle')
    c.setAttribute('cx', String(b.x + b.width - 10)); c.setAttribute('cy', String(b.y + 10)); c.setAttribute('r', '3')
    c.setAttribute('class', 'bille bille-' + etat)
    if (etat === 'abs') { c.setAttribute('fill', 'none'); c.setAttribute('stroke', 'rgba(255,255,255,.35)'); c.setAttribute('stroke-width', '1') }
    else { c.setAttribute('fill', billes[etat]); c.setAttribute('stroke', 'rgba(255,255,255,.25)'); c.setAttribute('stroke-width', '.5') }
    g.appendChild(c)
  })
  const out = el.outerHTML
  boite.remove()
  return out
}

async function main() {
  if (!existsSync(MERMAID)) throw new Error('mermaid absent : npm install dans docs/site')
  if (!existsSync(CHROME)) throw new Error('Chrome introuvable : ' + CHROME)
  const fichiers = readdirSync(DOSSIER).filter((f) => f.endsWith('.mmd')).sort()
    .filter((f) => !only || f.startsWith(only))
  const aFaire = fichiers.filter((f) => {
    const svg = join(DOSSIER, f.replace(/\.mmd$/, '.svg'))
    if (force || !existsSync(svg)) return true
    const h = sha1(readFileSync(join(DOSSIER, f), 'utf8'))
    return !readFileSync(svg, 'utf8').startsWith(`<!-- mmd:${h} -->`)
  })
  if (!aFaire.length) { console.log('schémas : rien à rendre (%d à jour)', fichiers.length); return }

  const navigateur = await puppeteer.launch({ executablePath: CHROME, headless: true, args: ['--disable-gpu', '--allow-file-access-from-files'] })
  try {
    const page = await navigateur.newPage()
    await page.setViewport({ width: 1400, height: 1000, deviceScaleFactor: 1 })
    await page.setContent(PAGE_HTML, { waitUntil: 'load' })
    await page.addScriptTag({ path: MERMAID })
    // La police doit être CHARGÉE avant que Mermaid mesure ses boîtes : fonts.ready ne charge
    // pas une police que rien n'utilise encore → on la demande explicitement.
    await page.evaluate(() => Promise.all([document.fonts.load('400 13px Inter'), document.fonts.load('500 13px Inter')]).then(() => document.fonts.ready))
    // ⑦ le thème, UNE fois, en hex — la robe vient de la feuille obsidienne injectée après.
    await page.evaluate(() => window.mermaid.initialize({
      startOnLoad: false, securityLevel: 'loose', theme: 'base',
      fontFamily: 'Inter, -apple-system, system-ui, sans-serif',
      flowchart: { htmlLabels: true, padding: 14, nodeSpacing: 40, rankSpacing: 44, curve: 'basis' },
      themeVariables: {
        fontSize: '13px', background: '#000000', primaryColor: '#121212', primaryTextColor: '#E8E8E8', primaryBorderColor: '#2A2A2A',
        lineColor: '#5C5C5C', secondaryColor: '#0C0C0C', tertiaryColor: '#000000', mainBkg: '#121212', nodeBorder: '#2A2A2A', textColor: '#E8E8E8',
        clusterBkg: '#000000', clusterBorder: '#1E1E1E', edgeLabelBackground: '#000000', labelBackground: '#000000',
        actorBkg: '#121212', actorBorder: '#2A2A2A', actorTextColor: '#E8E8E8', signalColor: '#8A8A8A', signalTextColor: '#C9C9C9',
        noteBkgColor: '#0A0A0A', noteTextColor: '#B8B8B8', noteBorderColor: '#1F1F1F',
        attributeBackgroundColorOdd: '#0A0A0A', attributeBackgroundColorEven: '#0E0E0E',
      },
    }))
    let n = 0
    for (const f of aFaire) {
      const code = readFileSync(join(DOSSIER, f), 'utf8')
      const id = f.replace(/\.mmd$/, '')
      try {
        // ④ un par un, avec notre id
        const svg = await page.evaluate(RENDRE, id, code, BILLES)
        writeFileSync(join(DOSSIER, id + '.svg'), `<!-- mmd:${sha1(code)} -->\n` + svg + '\n')
        n++; console.log('  ●', id, (svg.length / 1024).toFixed(0) + ' Ko')
      } catch (e) {
        console.error('  ✗', id, e.message.split('\n')[0]); process.exitCode = 1
      }
    }
    console.log('schémas : %d rendus sur %d', n, aFaire.length)
  } finally {
    await navigateur.close()
  }
}

main().catch((e) => { console.error(e); process.exit(1) })
