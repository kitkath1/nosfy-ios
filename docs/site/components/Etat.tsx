import type { Etat as E } from '@/content/types'
import { DOMAINES, TOUTES, MESURES, compter, parDomaine, aFaire, teinteDomaine, verdict, LIBELLE, LIBELLE_PLURIEL } from '@/content'
import { Pastille, Rangee, RangeeMesure, lireCaptures } from './Composants'
import { Ic } from './Sprite'

/**
 * L'ACCUEIL « ÉTAT » — tout est DÉRIVÉ de content/ à la build : les compteurs, les cards,
 * la liste 🔴 d'abord. Le JS ne fait que filtrer. Le témoin data-attendu dénonce un
 * livrable édité à la main.
 */
export function Etat() {
  const c = compter()
  const { briques, mesures } = aFaire()
  const groupes: (E | 'nm')[] = ['men', 'nm', 'loc', 'srv', 'abs', 'ok']
  const captures = lireCaptures()
  return (
    <section className="page on" id="etat" data-attendu={c.total}>
      <div className="hero">
        <div className="grain" aria-hidden="true" />
        <p className="sur">Back-end · état vérifié</p>
        <h1>Ce qui marche, ce qui ment,<br />ce qui manque.</h1>
        <p className="phrase">Chaque pastille a été <b>lue dans le code</b> ou mesurée au serveur. Rien ici n&apos;est déduit — et le compte se refait à chaque build.</p>
        <div className="compteurs" role="group" aria-label="Compteurs et filtres d'état">
          {(['men', 'loc', 'srv', 'abs', 'ok'] as E[]).map((e) => (
            <button key={e} type="button" className="pill" data-f={`etat:${e}`} style={{ ['--c' as string]: `var(--${e})` }}>
              <i className="pt" data-etat={e} /><b>{c[e]}</b> {LIBELLE_PLURIEL[e]}
            </button>
          ))}
          <button type="button" className="pill" data-f="etat:nm"><i className="pt" data-etat="nm" /><b>{mesures.length}</b> à mesurer</button>
          <span className="pill alerte" role="status" />
        </div>
        <div className="actions">
          <a className="obs" href="https://supabase.com/dashboard/project/ytnnyjkramgiqyxdrkcu/editor" target="_blank" rel="noopener">
            <span className="lib">Ouvrir dans Supabase</span><Ic id="arrow" />
          </a>
        </div>
      </div>

      <div className="doms">
        {DOMAINES.map((d, i) => {
          const cd = compter(parDomaine(d.id))
          const nm = MESURES.filter((m) => m.domaine === d.id).length
          const t = teinteDomaine(d.id)
          return (
            <a key={d.id} className={'dom reveal' + (t === 'argent' ? '' : ' ' + t)} href={`#${d.page}`} data-dom={d.id} data-onglet={d.page} style={{ ['--i' as string]: i }}>
              <span className="sur">{d.libelle}</span>
              <h3>{verdict(cd, nm)}</h3>
              <p className="sous">
                {cd.total ? `${cd.total} brique${cd.total > 1 ? 's' : ''} · ` : ''}
                {(['men', 'loc', 'srv', 'abs', 'ok'] as E[]).filter((e) => cd[e]).map((e) => <i key={e}><span className="pt" data-etat={e} />{cd[e]} {LIBELLE[e]}</i>)}
                {nm > 0 && <i><span className="pt" data-etat="nm" />{nm} à mesurer</i>}
              </p>
            </a>
          )
        })}
      </div>

      <div className="filtres" role="group" aria-label="Filtres par domaine">
        <button type="button" className="pill" data-f="*">Tout</button>
        <span className="sep" aria-hidden="true" />
        {DOMAINES.map((d) => <button key={d.id} type="button" className="pill" data-f={`dom:${d.id}`}>{d.libelle}</button>)}
      </div>

      <ul className="liste">
        {groupes.map((g) => {
          const bs = g === 'nm' ? [] : briques.filter((b) => b.etat === g)
          const ms = g === 'nm' ? mesures : []
          if (!bs.length && !ms.length) return null
          return (
            <span key={g} style={{ display: 'contents' }}>
              <li className="grp" data-grp={g}><i className="pt" data-etat={g} />{LIBELLE[g]}<span className="n">{bs.length + ms.length}</span></li>
              {bs.map((b) => <Rangee key={b.id} b={b} lien />)}
              {ms.map((m) => <RangeeMesure key={m.id} m={m} lien />)}
            </span>
          )
        })}
      </ul>
      <p className="liste fin">Une rangée = une brique ; son état est celui de l&apos;enregistrement, rendu ici et sur sa page. Bille creuse = à mesurer avant de peindre. Anneau pointillé = le site et le code se contredisent. « preuve à citer » = la dette que le README exige de payer.</p>

      <div className="flow-titre">
        <h2>Le flow</h2>
        <p>De vraies captures du simulateur, fondues au noir. Les écrans vides restent à capturer (un build).</p>
      </div>
      <div className="flow">
        {captures.flow.length ? captures.flow.map((f) => (
          <figure key={f.nom} className={'ecran' + (f.fichier ? '' : ' vide')} data-ecran={f.nom}>
            {f.fichier ? <img src={`/captures/flow/${f.fichier.split('/').pop()}`} width={f.largeur} height={f.hauteur} alt={f.legende} loading="lazy" decoding="async" /> : <span className="cadre-vide" />}
            <figcaption>{f.legende}{f.fichier ? '' : ' · à capturer'}</figcaption>
          </figure>
        )) : <p className="rien">`npm run captures` pour embarquer les captures.</p>}
      </div>

      <p className="legende-pied">
        <span>Se lit ainsi</span>
        <Pastille etat="ok" libelle="branché" /><Pastille etat="loc" libelle="local" /><Pastille etat="srv" libelle="serveur seul" /><Pastille etat="abs" libelle="absent" /><Pastille etat="men" libelle="ment" />
        <span>· coût : 1 h · 1 j · chantier · {TOUTES.length} pastilles, {MESURES.length} à mesurer</span>
      </p>
    </section>
  )
}
