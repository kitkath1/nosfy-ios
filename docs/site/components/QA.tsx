import { ETAPES_QA } from '@/content'
import type { EtapeQA, VerdictQA } from '@/content/types'
import { Texte } from './Composants'

/**
 * LE TEST QA (14-09, Kathryn : « un onglet Test QA avec ce flow qu'on valide ensemble niveau
 * front et back »). Une étape par rangée, deux verdicts par étape : le FRONT (ce qu'elle voit
 * sur son iPhone) et le BACK (ce que le serveur ou le téléphone tient, lu par moi).
 *
 * ⚠️ Les verdicts ne sont PAS des pastilles (`.p`) : le témoin `data-attendu` du site compte
 * toutes les pastilles rendues et les compare aux données — une étape QA n'est pas une
 * brique, elle porte sa propre robe (`.qv`).
 */
const LIBELLE_VERDICT: Record<VerdictQA['etat'], string> = { a_valider: 'à valider', valide: 'validé', ko: 'KO' }
const SIGNE_VERDICT: Record<VerdictQA['etat'], string> = { a_valider: '☐', valide: '✓', ko: '✗' }

function Verdict({ v, cote }: { v: VerdictQA; cote: 'front' | 'back' }) {
  const titre = [LIBELLE_VERDICT[v.etat], v.le, v.note].filter(Boolean).join(' · ')
  return (
    <span className={`qv qv-${v.etat}`} title={titre}>
      <b>{SIGNE_VERDICT[v.etat]}</b> {cote} {v.etat === 'valide' && v.le ? <i>{v.le}</i> : null}
    </span>
  )
}

export function compterQA(etapes: EtapeQA[] = ETAPES_QA) {
  const c = { etapes: etapes.length, verdicts: etapes.length * 2, valides: 0, ko: 0, aValider: 0 }
  for (const e of etapes) for (const v of [e.frontVerdict, e.backVerdict]) {
    if (v.etat === 'valide') c.valides++
    else if (v.etat === 'ko') c.ko++
    else c.aValider++
  }
  return c
}

/** Le hero de la page : il compte des ÉTAPES et des verdicts, pas des briques. */
export function HeroQA() {
  const c = compterQA()
  const verdict = c.ko ? `${c.ko} KO à corriger` : c.aValider ? `${c.aValider} verdicts à poser ensemble` : 'Tout est validé.'
  const tout = c.valides === c.verdicts && c.verdicts > 0
  return (
    <div className={'hero-dom' + (tout ? ' vert' : ' noir')} data-teinte={tout ? 'vert : tout validé' : 'hero noir : le test QA'}>
      <span className="a-capturer">front · back</span>
      <p className="sur">Test QA · {c.etapes} étapes · {c.verdicts} verdicts</p>
      <p className="verdict">{verdict}</p>
      <p className="comptes">{[c.valides ? `${c.valides} validés` : '', c.aValider ? `${c.aValider} à valider` : '', c.ko ? `${c.ko} KO` : ''].filter(Boolean).join(' · ')}</p>
    </div>
  )
}

/** Le parcours, en table (`compact` : la liste courte des étapes et de leurs verdicts, pour la page Compte). */
export function ParcoursQA({ compact }: { compact?: boolean }) {
  if (compact) {
    return (
      <ol className="qa-compact">
        {ETAPES_QA.map((e) => (
          <li key={e.id}>
            <a href={`#${e.id}`}><b>{e.titre}</b></a>
            <span className="qa-verdicts"><Verdict v={e.frontVerdict} cote="front" /><Verdict v={e.backVerdict} cote="back" /></span>
          </li>
        ))}
      </ol>
    )
  }
  return (
    <div className="tw tw-qa"><table className="qa">
      <thead><tr><th>#</th><th>L'étape · le geste</th><th>Le front — ce qu'elle voit</th><th>Le back — ce que le serveur et le téléphone tiennent</th><th>Verdicts</th></tr></thead>
      <tbody>
        {ETAPES_QA.map((e) => (
          <tr key={e.id} id={e.id} className={e.frontVerdict.etat === 'ko' || e.backVerdict.etat === 'ko' ? 'ko' : ''}>
            <td className="num">{e.n}</td>
            <td className="etape"><b><span className="num-inline">{e.n}. </span>{e.titre}</b><br /><span className="geste"><Texte t={e.geste} /></span></td>
            <td className="front"><Texte t={e.front} /></td>
            <td className="back"><Texte t={e.back} /></td>
            <td className="verdicts">
              <Verdict v={e.frontVerdict} cote="front" />
              {e.frontVerdict.note && <span className="qa-note">{e.frontVerdict.note}</span>}
              <Verdict v={e.backVerdict} cote="back" />
              {e.backVerdict.note && <span className="qa-note">{e.backVerdict.note}</span>}
            </td>
          </tr>
        ))}
      </tbody>
    </table></div>
  )
}
