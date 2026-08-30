import { PAGES, TOUTES, compter } from '@/content'
import { Ic } from './Sprite'

/** Le rail : la lune, les 8 pages (30-08 : le coffre et les annonces à la place de « Économie & annonces »), la loi. Les nombres de 🔴 par page sont CALCULÉS. */
export function Rail() {
  const total = compter().total
  return (
    <nav className="rail" id="rail" aria-label="Navigation">
      <div className="marque">
        <svg className="lune" viewBox="0 0 749 718" aria-hidden="true"><use href="#i-lune" /></svg>
        <div><b>Woop</b><span>La chambre des machines</span></div>
      </div>
      <div className="menu">
        {PAGES.map((p, i) => {
          const men = p.id === 'etat' ? compter().men : compter(TOUTES.filter((b) => b.page === p.id)).men
          return (
            <span key={p.id} style={{ display: 'contents' }}>
              {i === 2 && <div className="menu-titre">Domaines</div>}
              <a className={'item' + (p.id === 'etat' ? ' on' : '')} href={`#${p.id}`} data-p={p.id}>
                <Ic id={p.glyphe} /><span className="lib">{p.libelle}</span>
                {men > 0 && <span className="n">{men}</span>}
              </a>
            </span>
          )
        })}
      </div>
      <div className="loi">
        <b>Un état se vérifie, il ne se déduit pas.</b>
        <span>{total} pastilles · dernière passe le 30 août 2026</span>
      </div>
    </nav>
  )
}

export function Barre() {
  return (
    <>
      <header className="barre">
        <svg className="lune" viewBox="0 0 749 718" aria-hidden="true"><use href="#i-lune" /></svg>
        <b data-titre>État</b>
        <button type="button" aria-label="Menu" data-tiroir><Ic id="menu" /></button>
      </header>
      <div className="voile" data-voile />
    </>
  )
}
