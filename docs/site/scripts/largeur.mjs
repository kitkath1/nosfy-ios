// La sonde de largeur : à 390 px, AUCUNE des 8 pages ne doit faire défiler la page
// de côté. Payé le 30-08 : le spotlight `.page::before` faisait 1200 px centré, la
// page mesurait 795 px sur un écran de 390 — invisible sur une capture, sensible au pouce.
//
//   node scripts/largeur.mjs [chemin du livrable]     → sort 1 si une page dépasse
import p from 'puppeteer-core';
import { resolve } from 'node:path';

const site = resolve(process.argv[2] ?? 'index.html');
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PAGES = ['etat', 'serveur', 'flow', 'widgets', 'coffre', 'annonces', 'forge', 'histoire', 'porte'];   // 30-08 : coffre + annonces à la place de regles · 13-09 : widgets
const LARGEUR = 390;

const b = await p.launch({ executablePath: CHROME, headless: true });
try {
  const pg = await b.newPage();
  await pg.setViewport({ width: LARGEUR, height: 844, deviceScaleFactor: 1 });
  await pg.goto('file://' + site);
  await new Promise(r => setTimeout(r, 600));
  const mesures = await pg.evaluate((pages) => {
    const out = {};
    for (const id of pages) {
      document.querySelectorAll('.page').forEach(s => { s.style.display = 'none'; });
      const page = document.querySelector('#' + id);
      if (!page) { out[id] = { sw: -1, coupables: ['page introuvable'] }; continue; }
      page.style.display = 'block';
      const coupables = [];
      page.querySelectorAll('*').forEach(e => {
        const w = e.getBoundingClientRect();
        if (w.right <= innerWidth + 1 || w.width === 0) return;
        let a = e.parentElement, cache = false;
        while (a && a !== document.body) { if (getComputedStyle(a).overflowX !== 'visible') { cache = true; break; } a = a.parentElement; }
        if (!cache) coupables.push(e.tagName.toLowerCase() + (e.className ? '.' + String(e.className).split(' ').join('.') : '') + ' → ' + Math.round(w.right) + ' px');
      });
      out[id] = { sw: document.documentElement.scrollWidth, coupables: coupables.slice(0, 5) };
    }
    return out;
  }, PAGES);
  let ko = 0;
  for (const [id, m] of Object.entries(mesures)) {
    if (m.sw === LARGEUR) { console.log(`   ✔ ${id} : ${m.sw} px`); continue; }
    ko++;
    console.log(`   ✗ ${id} : la page mesure ${m.sw} px sur un écran de ${LARGEUR}` + (m.coupables.length ? ' — ' + m.coupables.join(' · ') : ' — aucun élément visible ne dépasse : chercher un ::before/::after'));
  }
  process.exitCode = ko ? 1 : 0;
} finally {
  await b.close();
}
