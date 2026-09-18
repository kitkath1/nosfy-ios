import { PAGES, TOUTES, MESURES, compterFamilles } from '@/content'
import { Ic } from './Sprite'
import { dernierePasse } from './passe'

/**
 * Le rail : la lune, les 8 pages (30-08 : le coffre et les annonces à la place de « Économie & annonces »), la loi.
 *
 * Le nombre d'une page = CE QUI L'ATTEND, ELLE : à trancher + à valider ensemble (30-08 soir). Avant, c'était
 * les 🔴 seuls — le rail disait « État 9 » quand douze lignes la concernaient, et le blanc « à trancher » n'était
 * compté nulle part. Un seul vocabulaire du hero au rail.
 */
export function Rail() {
  // le pied dit le MÊME total que les compteurs du hero (113) — « 136 pastilles » comptait les lignes de référence
  const total = compterFamilles().total
  return (
    <nav className="rail" id="rail" aria-label="Navigation">
      <div className="marque">
        <svg className="lune" viewBox="0 0 749 718" aria-hidden="true"><use href="#i-lune" /></svg>
        <div><b>Nosfy</b><span>La chambre des machines</span></div>
      </div>
      <div className="menu">
        {PAGES.map((p, i) => {
          const f = p.id === 'etat'
            ? compterFamilles()
            : compterFamilles(TOUTES.filter((b) => b.page === p.id), MESURES.filter((m) => m.page === p.id))
          const n = p.id === 'etat' ? 0 : f.trancher + f.valider   // pas de nombre sur « État » : on y est, le hero le dit en grand
          return (
            <span key={p.id} style={{ display: 'contents' }}>
              {i === 2 && <div className="menu-titre">Domaines</div>}
              <a className={'item' + (p.id === 'etat' ? ' on' : '')} href={`#${p.id}`} data-p={p.id}>
                <Ic id={p.glyphe} /><span className="lib">{p.libelle}</span>
                {n > 0 && <span className="n" title={`${f.trancher} à trancher · ${f.valider} à valider ensemble`}>{n}</span>}
              </a>
            </span>
          )
        })}
      </div>
      <div className="loi">
        <b>Un état se vérifie, il ne se déduit pas.</b>
        <span>{total} pastilles · dernière passe le {dernierePasse()}</span>
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
