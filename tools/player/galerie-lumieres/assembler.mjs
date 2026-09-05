// Injecte les propositions des workflows dans le châssis.
//   node assembler.mjs <chassis.html> <sortie.html> <serie1.json> [serie2.json…]
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { resolve } from 'node:path';

const [chassis, out, ...sources] = process.argv.slice(2);

// .json/.output = résultat de workflow ; .mjs = série écrite à la main
const lire = async f => {
  if (f.endsWith('.mjs')) return (await import(pathToFileURL(resolve(f)).href)).default;
  const brut = readFileSync(f, 'utf8');
  const d = JSON.parse(brut.slice(brut.indexOf('{')));
  return (d.result ?? d).propositions;
};

const RECO = 'miroir';           // ma recommandation (direction équaliseur, tranchée 03-09)
const ech = s => String(s ?? '').replace(/[<>&]/g, c => ({ '<': '&lt;', '>': '&gt;', '&': '&amp;' }[c]));

// Où la lumière VIT — le seul axe qui décide vraiment entre elles.
// Classé à la lecture des rendus, pas à la lecture des pitchs (neuf
// propositions sur dix s'étaient auto-classées « blanc profond »).
const OU = {
  reflet: 'sur l’image', perle: 'sur l’image', lentille: 'sur l’image',
  eau: 'sous l’image',
  prisme: 'sur les contours', lisere: 'sur les contours',
  souffle: 'derrière l’image', houle: 'derrière l’image',
  conique: 'derrière l’image', aube: 'derrière l’image',
  aurore: 'toute la card', braise: 'toute la card', voile: 'toute la card',
  strates: 'toute la card', soie: 'toute la card', grain: 'toute la card',
  cordes: 'toute la card', cristal: 'toute la card', fumee: 'toute la card',
  encre: 'toute la card',
  ruban: 'le composant', vumetre: 'le composant',
  corde: 'le composant', pastilles: 'le composant', spectre: 'le composant',
  barres: 'l’équaliseur', miroir: 'l’équaliseur', colonnes: 'l’équaliseur',
  verre: 'l’équaliseur', eventail: 'l’équaliseur', note: 'l’équaliseur', trio: 'l’équaliseur',
};
const ORDRE_OU = ['l’équaliseur', 'le composant', 'sur l’image', 'sous l’image', 'sur les contours', 'derrière l’image', 'toute la card'];

const SERIES = [
  { titre: 'Première série',
    intro: 'Dix façons de faire vivre la lumière : elle passe, elle respire, elle dérive, elle réfracte.' },
  { titre: 'Deuxième série',
    intro: 'Dix autres matières, sur des terrains que la première n’avait pas touchés — l’eau, le tissu, l’encre, la poussière, la taille du cristal.' },
  { titre: 'Troisième série — le composant',
    intro: 'Sa direction : pas le fond, le COMPOSANT. À la place exacte de la barre, un objet de musique qui vit — le fond reste d’un noir intact. Dans la dalle, il devient le glyphe « en lecture », posé à droite du titre comme dans Apple Music ; et chaque composant est montré à la loupe, pour les micro-détails.' },
  { titre: 'Quatrième série — l’équaliseur décliné',
    intro: 'L’objet retenu, décliné en six matières : le miroir sculpté, les perles comptées, le verre taillé, l’éventail, la note qui migre, le trio en canon. Toutes ancrées au CENTRE — jamais au sol, le sol en ferait une jauge — et partout l’équaliseur monte d’un cran de présence dans la dalle.' },
];

const series = await Promise.all(sources.map(lire));
const toutes = series.flat();

// --- garde-fous ---
const ennuis = [];
for (const p of toutes) {
  if (!new RegExp(`\\.p-${p.id}\\b`).test(p.css)) ennuis.push(`${p.id} : aucun sélecteur .p-${p.id}`);
  const mauvais = [...p.css.matchAll(/@keyframes\s+([\w-]+)/g)].map(m => m[1]).filter(k => !k.startsWith(p.id));
  if (mauvais.length) ennuis.push(`${p.id} : keyframes non préfixés → ${mauvais.join(', ')}`);
  if (/https?:\/\//.test(p.css)) ennuis.push(`${p.id} : ressource externe dans le CSS`);
  if (/<script/i.test([p.fxMini, p.fxMiniTop, p.fxGrand, p.fxGrandTop, p.compo, p.compoMini].join(''))) ennuis.push(`${p.id} : <script> dans le HTML`);
  if (!OU[p.id]) ennuis.push(`${p.id} : pas classé dans OU`);
  // les classes du châssis sont RÉSERVÉES : une proposition qui pose sa
  // classe `.s` écrase le sous-titre de la dalle (payé : verre, trio)
  // structurelles seulement : .art/.title/.chrono/.badge/.stop sont OUVERTES
  // aux propositions, et .gros est la loupe elle-même
  // (b et u sont des BALISES dans les rows, pas des classes — pas réservées)
  const RESERVEES = new Set(['t','s','meta','rows','fx','fx-top','compo-slot','compo-mini','oldbar','page-hint']);
  for (const m of String(p.compo ?? '').concat(p.compoMini ?? '').matchAll(/class="([^"]+)"/g)) {
    for (const cl of m[1].split(/\s+/)) {
      if (RESERVEES.has(cl)) ennuis.push(`${p.id} : classe réservée « ${cl} » dans le compo (écrase le châssis)`);
    }
  }
  if (p.compo) for (const cl of RESERVEES) {
    const re = new RegExp(`\\.p-${p.id}[^{,]*\\s\\.${cl}(?![\\w-])`);
    if (re.test(p.css)) ennuis.push(`${p.id} : sélecteur .${cl} (classe réservée du châssis) dans le CSS`);
  }
  // le bug payé : un sélecteur d'élément nu attrape les <i> de la liste
  for (const bloc of p.css.match(/[^{}]+(?=\{)/g) ?? []) {
    for (const sel of bloc.split(',')) {
      const s = sel.replace(/\/\*[\s\S]*?\*\//g, '').trim();
      if (!s || '@%'.includes(s[0]) || s === 'from' || s === 'to' || s.includes('%')) continue;
      const dernier = s.split(/\s+/).pop().split('>').pop().trim();
      if (/^(i|span|b|u)([.:[]|$)/.test(dernier) && !s.includes('.fx')) {
        ennuis.push(`${p.id} : sélecteur d'élément nu « ${s} » (casse la liste)`);
      }
    }
  }
}
if (ennuis.length) console.log('⚠ ' + [...new Set(ennuis)].join('\n⚠ '));

const coutClasse = { 'léger': 'cout-leger', 'moyen': 'cout-moyen', 'lourd': 'cout-lourd' };

const bloc = p => `
  <section class="specimen" id="${p.id}">
    <div class="spec-text">
      <div class="spec-head">
        <h2 class="spec-name">${ech(p.nom)}</h2>
        ${p.id === RECO ? '<span class="reco">ma recommandation</span>' : ''}
      </div>
      <div class="chips">
        <span class="chip fam">${ech(OU[p.id] ?? '—')}</span>
        <span class="chip ${coutClasse[p.cout] ?? 'cout-moyen'}">à faire : ${ech(p.cout)}</span>
      </div>
      <p class="spec-pitch">${ech(p.pitch)}</p>
      <details class="tech">
        <summary>Comment on le fait dans l'app</summary>
        <div>${ech(p.swift)}</div>
      </details>
    </div>
    <div class="stage">
      <div class="slot">
        <span class="slot-label">Plein écran</span>
        <div class="scale-grand"><div class="grand p-${p.id}${p.compo ? ' has-compo' : ''}">
          <div class="fx">${p.fxGrand ?? ''}</div>
          <div class="grabber"></div>
          <div class="art"></div>
          <div class="badge">8 SETS</div>
          <div class="title">Bench Press</div>
          ${p.compo ? `<div class="compo-slot">${p.compo}</div>` : ''}
          <div class="chrono"><span>IN SESSION</span>24:07</div>
          <div class="rows"><i><b>Bench Press</b><u>4 × 8</u></i><i><b>Incline Press</b><u>3 × 10</u></i><i><b>Cable Fly</b><u>3 × 12</u></i><i><b>Lateral Raise</b><u>3 × 15</u></i></div>
          <div class="fx-top">${p.fxGrandTop ?? ''}</div>
        </div></div>
      </div>
      <div class="slot-col">
        <div class="slot">
          <span class="slot-label">La dalle</span>
          <div class="scale-mini"><div class="mini-wrap">
            <div class="page-hint"><i></i><i></i></div>
            <div class="mini p-${p.id}">
              <div class="fx">${p.fxMini ?? ''}</div>
              <div class="art"></div>
              <div class="meta"><div class="t">Bench Press</div><div class="s">In session · 24 min</div></div>
              ${p.compoMini ? `<div class="compo-mini">${p.compoMini}</div>` : ''}
              <div class="stop"></div>
              <div class="fx-top">${p.fxMiniTop ?? ''}</div>
            </div>
          </div></div>
        </div>
        ${p.compo ? `<div class="slot">
          <span class="slot-label">À la loupe</span>
          <div class="loupe p-${p.id}"><div class="gros">${p.compo}</div></div>
        </div>` : ''}
      </div>
    </div>
  </section>`;

// --- l'index, groupé par OÙ la lumière vit ---
const index = `
  <nav class="index" aria-label="Les propositions">
    ${ORDRE_OU.map(ou => {
      const dedans = toutes.filter(p => OU[p.id] === ou);
      if (!dedans.length) return '';
      return `<div class="index-col">
      <h3>${ou}</h3>
      <ul>${dedans.map(p =>
        `<li><a href="#${p.id}">${ech(p.nom)}${p.id === RECO ? ' <span class="star">◆</span>' : ''}</a></li>`
      ).join('')}</ul>
    </div>`;
    }).join('\n    ')}
  </nav>`;

// L'ARMURE — posée APRÈS le CSS des propositions.
// Les agents peuplent leurs calques de <i>, et certains les visent large
// (mesuré : `.p-souffle i`, spécificité 0-1-1). Or les lignes de la liste
// sont aussi des <i> : elles se retrouvaient empilées les unes sur les
// autres. On réimpose ici la structure du châssis, à spécificité
// supérieure — sans toucher à ce qu'on leur a ouvert (.art, .title,
// .chrono, .badge et leurs couleurs).
const armure = `
/* ===== armure du châssis ===== */
.grand .rows { position: absolute; display: flex; flex-direction: column; }
.grand .rows i {
  position: static; display: flex; align-items: center; justify-content: space-between;
  inset: auto; width: auto; height: 46px; border-radius: 12px;
  transform: none; animation: none; filter: none; mix-blend-mode: normal;
}
.mini .art, .mini .meta, .mini .stop { position: relative; }
.mini .meta { flex: 1; min-width: 0; }
.mini .art, .mini .stop { flex: none; }
`;

const css = toutes.map(p => `/* ===== ${p.nom} (${p.id}) ===== */\n${p.css}`).join('\n\n') + '\n' + armure;

const corps = series.map((props, i) => {
  const s = SERIES[i] ?? { titre: `Série ${i + 1}`, intro: '' };
  const tete = `
  <div class="serie">
    <h2>${s.titre}</h2>
    <p>${s.intro}</p>
  </div>`;
  return tete + props.map(bloc).join('\n');
}).join('\n');

let html = readFileSync(chassis, 'utf8');
html = html.replace('<!-- ANIM-CSS-ICI -->', `<style>\n${css}\n</style>`);
html = html.replace('<!-- INDEX-ICI -->', index);
html = html.replace('<!-- SPECIMENS-ICI -->', corps);
writeFileSync(out, html);

console.log(`✔ ${toutes.length} propositions injectées → ${out}`);
for (const ou of ORDRE_OU) {
  const d = toutes.filter(p => OU[p.id] === ou);
  if (d.length) console.log(`  ${ou} : ${d.map(p => p.nom).join(', ')}`);
}
