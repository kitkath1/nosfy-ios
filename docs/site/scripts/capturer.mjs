// Les captures du vérificateur, par puppeteer — jamais par `chrome --screenshot`.
//
// Payé le 30-08 : `--headless --window-size=390,2400 --screenshot` met en page à **500 px**
// (mesuré : innerWidth = 500 pour toute --window-size ≤ 500, la largeur minimale de fenêtre
// du Chrome installé) puis rogne le PNG à 390. Le hero allait de 20 à 389 au lieu de 20 à
// 370, les titres de rangée filaient sous le bord sans points de suspension : la capture
// « 390 » n'était pas une mise en page à 390. `page.setViewport` est la seule largeur qui
// se mesure (clientWidth = 390, lu et vérifié ci-dessous à chaque capture).
//
//   node scripts/capturer.mjs <dossier> <url du livrable, sans #> <largeur> <page> [page…]
//   → <dossier>/<page>-<largeur>.png, l'arrivée (1,5 s) jouée jusqu'au bout
import p from 'puppeteer-core';
import { resolve } from 'node:path';

const [dossier, url, largeurTexte, ...pages] = process.argv.slice(2);
if (!dossier || !url || !largeurTexte || !pages.length) {
  console.error('usage : node scripts/capturer.mjs <dossier> <url> <largeur> <page> [page…]');
  process.exit(2);
}
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const largeur = Number(largeurTexte), hauteur = 2400;
const ATTENTE = 1700;   // l'arrivée dure 1,46 s (HomeNuit.swift:359) : on capture l'état FINAL, jamais un fondu

const b = await p.launch({ executablePath: CHROME, headless: true });
let ko = 0;
try {
  const pg = await b.newPage();
  await pg.setViewport({ width: largeur, height: hauteur, deviceScaleFactor: 1 });
  for (const page of pages) {
    const sortie = resolve(dossier, `${page}-${largeur}.png`);
    try {
      await pg.goto('about:blank');
      await pg.goto(`${url}#${page}`, { waitUntil: 'load' });
      await new Promise(r => setTimeout(r, ATTENTE));
      const mesure = await pg.evaluate(() => ({ sw: document.documentElement.scrollWidth, cw: document.documentElement.clientWidth }));
      await pg.screenshot({ path: sortie, fullPage: false });
      if (mesure.cw !== largeur) { ko++; console.log(`   ✗ ${page}-${largeur}.png : la page est mise en page à ${mesure.cw} px, pas ${largeur}`); continue; }
      console.log(`   ✔ ${page}-${largeur}.png (${largeur} × ${hauteur}, scrollWidth ${mesure.sw})`);
    } catch (e) {
      ko++; console.log(`   ✗ ${page}-${largeur}.png : ${e.message.split('\n')[0]}`);
    }
  }
} finally {
  await b.close();
}
process.exitCode = ko ? 1 : 0;
