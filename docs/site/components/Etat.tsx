import type { Brique, Mesure } from '@/content/types'
import type { Famille } from '@/content'
import { DOMAINES, MESURES, FAMILLES, LIBELLE_FAMILLE, QUI_AGIT, compter, compterFamilles, parDomaine, aFaire, famille, ligneFamilles, teinteDomaine, verdict, ORDRE_CHANTIER } from '@/content'
import { Rangee, RangeeMesure, lireCaptures } from './Composants'
import { Ic } from './Sprite'

/**
 * L'ACCUEIL « ÉTAT » — tout est DÉRIVÉ de content/ à la build : les quatre compteurs, les cards, la
 * liste. Le JS ne fait que filtrer. Le témoin data-attendu dénonce un livrable édité à la main.
 *
 * 30-08, retour de Kathryn (« je veux savoir ce que JE dois faire ») : l'accueil parle en QUATRE
 * familles définies par qui agit — à trancher (elle), à valider ensemble (elle et moi), en chantier
 * (moi), bon (personne) — content/index.ts `famille`. Les cinq états restent la vérité de la source :
 * ils sont regroupés à l'affichage, jamais supprimés. Ce qui est bon n'est pas une to-do : pas de liste.
 */
const SECTIONS: { fam: Famille; titre: string }[] = [
  { fam: 'trancher', titre: 'Ce que tu dois trancher' },
  { fam: 'valider', titre: 'À valider ensemble' },
  { fam: 'chantier', titre: 'En chantier (rien à faire pour toi)' },
]

export function Etat() {
  const c = compter()
  const f = compterFamilles()
  const vert = f.total > 0 && f.bon === f.total
  const { briques, mesures } = aFaire()
  // dans « en chantier » : local, serveur seul, absent, puis les ◌, puis les 🟢 à litige (à relire)
  const rang = (x: Brique | Mesure) => ('etat' in x ? (x.etat === 'ok' ? 4 : ORDRE_CHANTIER.indexOf(x.etat)) : 3)
  const lignes = (fam: Famille): (Brique | Mesure)[] =>
    [...briques.filter((b) => famille(b) === fam), ...mesures.filter((m) => famille(m) === fam)].sort((a, b) => rang(a) - rang(b))
  const captures = lireCaptures()
  return (
    <section className="page on" id="etat" data-attendu={c.total}>
      <div className={'hero' + (vert ? ' vert' : '')} data-teinte={vert ? 'vert : tout bon' : undefined}>
        <div className="grain" aria-hidden="true" />
        <p className="sur">Back-end · état vérifié · la prochaine chose à faire</p>
        <h1>{verdict(f)}</h1>
        <p className="phrase">Chaque ligne a été <b>lue dans le code</b> ou mesurée au serveur. Rien ici n&apos;est déduit — et le compte se refait à chaque build.</p>
        <div className="familles" role="group" aria-label="Compteurs et filtres">
          {FAMILLES.map((k) => (
            <button key={k} type="button" className={'fam ' + k} data-f={`fam:${k}`}>
              <b>{f[k]}</b>
              <span><i className="pt" data-fam={k} />{LIBELLE_FAMILLE[k]}</span>
            </button>
          ))}
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
          const fd = compterFamilles(parDomaine(d.id), MESURES.filter((m) => m.domaine === d.id))
          const t = teinteDomaine(d.id)
          return (
            <a key={d.id} className={'dom reveal' + (t === 'chantier' ? '' : ' ' + t)} href={`#${d.page}`} data-dom={d.id} data-onglet={d.page} style={{ ['--i' as string]: i }}>
              <span className="sur">{d.libelle}</span>
              <h3>{verdict(fd)}</h3>
              <p className="sous">{ligneFamilles(fd).join(' · ')}</p>
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
        {SECTIONS.map((s) => {
          const xs = lignes(s.fam)
          if (!xs.length) return null
          return (
            <span key={s.fam} style={{ display: 'contents' }}>
              <li className="grp" data-grp={s.fam}><i className="pt" data-fam={s.fam} />{s.titre}<span className="n">{xs.length}</span></li>
              {xs.map((x) => ('etat' in x ? <Rangee key={x.id} b={x} lien /> : <RangeeMesure key={x.id} m={x} lien />))}
            </span>
          )
        })}
        <li className="rien-a-faire" hidden>Rien dans cette sélection.</li>
      </ul>
      <p className="liste fin">Une rangée = un chantier ; sa bille est l&apos;état de l&apos;enregistrement (jaune : vit dans le téléphone · bleu : le serveur l&apos;a, l&apos;app ne l&apos;appelle pas · gris : n&apos;existe pas · creuse : à mesurer), rendu ici et sur sa page. Anneau pointillé = le site et le code se contredisent, à relire. « preuve à citer » = la dette que le README exige de payer. Coût : 1 h · 1 j · chantier. Les compteurs du haut comptent toutes les pastilles ; la liste ne répète pas les lignes de référence (le détail d&apos;une to-do déjà listée).</p>

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

      {/* la légende : une phrase par famille, qui dit QUI agit */}
      <div className="legende-pied">
        <p><i className="pt" data-fam="trancher" /><b>à trancher</b> — {QUI_AGIT.trancher} : une décision qu&apos;on attend de toi ; rien ne bouge avant.</p>
        <p><i className="pt" data-fam="valider" /><b>à valider ensemble</b> — {QUI_AGIT.valider} : l&apos;écran affirme ce que le code ne fait pas ; on le regarde ensemble et on tranche la correction.</p>
        <p><i className="pt" data-fam="chantier" /><b>en chantier</b> — {QUI_AGIT.chantier} : ça se code ou ça se mesure, rien à faire pour toi.</p>
        <p><i className="pt" data-fam="bon" /><b>bon</b> — {QUI_AGIT.bon} : branché et vérifié.</p>
      </div>
    </section>
  )
}
