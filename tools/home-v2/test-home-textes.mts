import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { assembler, valider } from '../../supabase/functions/home-textes/contrat.ts';

const lots = JSON.parse(readFileSync(new URL('../../Woop/Resources/home-textes.json', import.meta.url), 'utf8'));
for (const lot of lots) {
  assert.equal(valider(lot.variantes, lot.langue, lot.revision).langue, lot.langue);
  const libres = Object.fromEntries(Object.entries(lot.variantes).map(([etat, rows]: [string, any]) => [etat,
    rows.map((row: any) => etat === 'depart' ? { amorce: row.fragments[0], bouton: row.bouton }
      : { ligne2: row.fragments[1], ligne3: row.fragments[2], ligne4: row.fragments[3] })]));
  const assembles = valider(assembler(libres as any, lot.langue), lot.langue, 'assemblage');
  assert.equal(assembles.variantes.active[0].fragments[2], '{seances}');
  assert.equal(assembles.variantes.seance[0].fragments[2], '{minutes}');
  const fauxNombre = structuredClone(lot.variantes);
  fauxNombre.active[0].fragments[2] = '42 séances';
  assert.throws(() => valider(fauxNombre, lot.langue, 'test'));
  const double = structuredClone(lot.variantes);
  double.depart[1] = double.depart[0];
  assert.throws(() => valider(double, lot.langue, 'test'));
  const mauvaiseLangue = structuredClone(lot.variantes);
  mauvaiseLangue.depart[0].fragments[1] = lot.langue === 'fr' ? 'slide to start' : 'glisse pour lancer';
  assert.throws(() => valider(mauvaiseLangue, lot.langue, 'test'));
  const jeton = structuredClone(lot.variantes);
  jeton.vide[0].fragments[2] = '{email}';
  assert.throws(() => valider(jeton, lot.langue, 'test'));
  const incomplet = structuredClone(lot.variantes);
  incomplet.depart.pop();
  assert.throws(() => valider(incomplet, lot.langue, 'test'));
  const tropLong = structuredClone(lot.variantes);
  tropLong.vide[0].fragments = ['{salut}', 'un mot et un autre mot', 'un mot et un autre mot', 'un mot et un autre mot'];
  assert.throws(() => valider(tropLong, lot.langue, 'test'), /phrase_longue/);
}
for (const path of process.argv.slice(2)) {
  const { lot } = JSON.parse(readFileSync(path, 'utf8'));
  valider(lot.variantes, lot.langue, lot.revision);
}
console.log('FR/EN : lots valides ; chiffres inventés, doublons, mauvais pull, jetons inconnus et lots incomplets refusés.');
