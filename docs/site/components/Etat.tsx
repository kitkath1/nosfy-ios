import type { Brique, Mesure } from '@/content/types'
import type { Famille } from '@/content'
import { PAGES, LIBELLE_FAMILLE, LIBELLE_LIGNE, badge, QUI_AGIT, compter, compterFamilles, comptePage, aFaire, bons, famille, familleDe, verdict, verdictCourt, ORDRE_CHANTIER, parPage, mesuresPar } from '@/content'
import { Rangee, RangeeMesure, Texte, lireCaptures } from './Composants'
import { Ic } from './Sprite'

/**
 * L'ACCUEIL « ÉTAT » — tout est DÉRIVÉ de content/ à la build : les quatre compteurs, les cards, la
 * liste. Le JS ne fait que filtrer et plier. Le témoin data-attendu dénonce un livrable édité à la main.
 *
 * 30-08, deux retours de Kathryn, le même soir :
 *  · « je veux savoir ce que JE dois faire » → QUATRE familles par qui agit — à trancher (elle), à valider
 *    ensemble (elle et moi), en chantier (moi), bon (personne) — content/index.ts `famille`. Les cinq états
 *    restent la vérité de la source : regroupés à l'affichage, jamais supprimés.
 *  · « il y a trop de pilules, on sait pas quoi faire » + « rajoute des indications vert ou rouge ou blanc
 *    dans les grosses cards » → l'accueil ne montre OUVERT que ce qui la concerne (à trancher, à valider) ;
 *    « en chantier » et « bon » sont PLIÉS en une ligne chacun (public/site.js) ; plus de filtres par domaine
 *    (la card EST la porte du domaine), plus de coût ni de preuve sur les rangées de l'accueil (ils vivent
 *    sur la page de la brique), plus de lien Supabase dans le hero (il est sur Serveur). Chaque card porte
 *    un BADGE en toutes lettres dans sa couleur — blanc · rouge · gris · vert — et une barre verte « N bons
 *    sur M ».
 */
/**
 * Les cards : les 7 pages du rail, sauf l'accueil — même nom, même nombre, même destination.
 * RANGÉES PAR URGENCE (30-08 soir) : à trancher, à valider, en chantier, bon — sinon l'œil trie lui-même
 * une grille de sept alors que toute la page est organisée par qui agit. À égalité, l'ordre du rail.
 */
const URGENCE: Famille[] = ['trancher', 'valider', 'chantier', 'bon']
const CARDS = PAGES.filter((p) => p.id !== 'etat' && p.id !== 'qa')   // 14-09 : le Test QA compte des étapes, pas des briques — pas de card
  .map((p, i) => ({ p, i, f: familleDe(comptePage(p.id)) }))
  .sort((a, b) => URGENCE.indexOf(a.f) - URGENCE.indexOf(b.f) || a.i - b.i)
  .map((x) => x.p)

/**
 * LE DÉTAIL D'UNE CARD (15-09, Kathryn : « les cards doivent passer vert avec le détail en vert, ou pas,
 * pour voir ce qu'il manque ou ce qui est ok ») : sous le compte, les lignes elles-mêmes — d'abord CE QUI
 * MANQUE (à trancher, à valider, en chantier, chacune avec sa bille), puis CE QUI EST BON en vert. Six lignes
 * au plus par card, le reste en « + N » ; la page dit tout. Une card verte ne liste que du vert.
 */
const DETAIL_MAX = 6
const URG: Record<Famille, number> = { trancher: 0, valider: 1, chantier: 2, bon: 3 }
function detailDe(page: string): { fam: Famille; titre: string; id: string }[] {
  const xs: (Brique | Mesure)[] = [...parPage(page as Brique['page']).filter((b) => !b.reference), ...mesuresPar(page as Brique['page'])]
  return xs.map((x) => ({ fam: famille(x), titre: x.titre, id: x.id })).sort((a, b) => URG[a.fam] - URG[b.fam])
}

const SECTIONS: { fam: Famille; titre: string; plie?: boolean }[] = [
  { fam: 'trancher', titre: 'À trancher — toi' },
  { fam: 'valider', titre: 'À valider ensemble — toi et moi' },
  { fam: 'chantier', titre: 'En chantier — travaux et prérequis ouverts', plie: true },
  { fam: 'bon', titre: 'Bon — branché et vérifié', plie: true },
]

export function Etat() {
  const c = compter()
  const f = compterFamilles()
  const vert = f.total > 0 && f.bon === f.total
  const { briques, mesures } = aFaire()
  // dans « en chantier » : local, serveur seul, absent, puis les ◌, puis les 🟢 à litige (à relire)
  const rang = (x: Brique | Mesure) => ('etat' in x ? (x.etat === 'ok' ? 4 : ORDRE_CHANTIER.indexOf(x.etat)) : 3)
  const lignes = (fam: Famille): (Brique | Mesure)[] =>
    fam === 'bon'
      // même règle que les trois autres sections : sinon une 🟢 dont le titre commence par « Définir » se
      // range sous « Bon » avec data-fam="trancher", et site.js recompte deux nombres qui ne collent plus.
      ? bons().filter((b) => famille(b) === 'bon')
      : [...briques.filter((b) => famille(b) === fam), ...mesures.filter((m) => famille(m) === fam)].sort((a, b) => rang(a) - rang(b))
  const captures = lireCaptures()
  // « Commencer par » : la PREMIÈRE chose à faire, nommée — le sur-titre le promettait, le compte seul ne le disait pas
  const premier = (lignes('trancher')[0] ?? lignes('valider')[0]) as Brique | Mesure | undefined
  return (
    <section className="page on" id="etat" data-attendu={c.total}>
      <div className={'hero' + (vert ? ' vert' : '')} data-teinte={vert ? 'vert : tout bon' : undefined}>
        <div className="grain" aria-hidden="true" />
        <p className="sur">Back-end · état vérifié · la prochaine chose à faire</p>
        <h1>{verdict(f)}</h1>
        {premier && (
          <p className="commencer">
            Commencer par <button type="button" className="lien" data-aller={premier.id} data-onglet={premier.page}><Texte t={premier.titre} /></button>
          </p>
        )}
        {/* DEUX compteurs en grand — ce qui l'attend ; le reste sur une ligne grise : « 55 en chantier · 46 bons ».
            Avant, les quatre étaient à 44 px et les deux gros nombres qui ne la concernent pas criaient le plus fort. */}
        <div className="familles" role="group" aria-label="Ce qui t'attend">
          {(['trancher', 'valider'] as Famille[]).map((k) => (
            <button key={k} type="button" className={'fam ' + k} data-f={f[k] ? `fam:${k}` : undefined} disabled={!f[k]}>
              <b>{f[k]}</b>
              <span><i className="pt" data-fam={k} />{LIBELLE_FAMILLE[k]}<em>{QUI_AGIT[k]}</em></span>
            </button>
          ))}
          <span className="pill alerte" role="status" />
        </div>
        <p className="reste">
          {(['chantier', 'bon'] as Famille[]).map((k) => (
            <button key={k} type="button" className="lien-fam" data-f={f[k] ? `fam:${k}` : undefined} disabled={!f[k]}><i className="pt" data-fam={k} /><b>{f[k]}</b> {LIBELLE_LIGNE[k](f[k])}</button>
          ))}
          <span>voir les points ouverts</span>
          <button type="button" className="lien-fam tout" data-f="*">tout voir</button>
        </p>
      </div>

      <p className="legende-pied">
        Vérification du 19 septembre : clients Swift et Supabase, séances, annonces, coffre, stories et cartes.
        {' '}<a href="#qa" data-saut="qa">Voir les résultats et les points encore ouverts</a>.
        {' '}Les états ci-dessous suivent les preuves de chaque section.
      </p>

      {/* LES GROSSES CARDS : une par PAGE (le même nom, le même nombre et la même destination que le rail),
          le badge dit la famille en toutes lettres dans sa couleur, la barre dit la part de bon. */}
      <div className="doms">
        {CARDS.map((p, i) => {
          const fd = comptePage(p.id)
          const t = familleDe(fd)
          return (
            <a key={p.id} className={'dom reveal ' + t} href={`#${p.id}`} data-onglet={p.id} data-fam={t} style={{ ['--i' as string]: i }}>
              {/* LE NOM EN GROS (30-08 soir) : « rien à faire pour toi » occupait le plus gros corps sur trois cards
                  sur sept — la même phrase trois fois — pendant que le seul mot qui les distingue était en 11 px gris. */}
              <h3>{p.libelle}</h3>
              <span className="badge"><i className="pt" data-fam={t} />{badge(fd)}</span>
              {/* une seule ligne de compte, en toutes lettres ; la barre verte est partie : elle répétait ce texte,
                  et sur une card rouge elle affichait 67 % de vert — la seule couleur disait l'inverse du badge. */}
              <p className="sous">{fd.bon} branchée{fd.bon > 1 ? 's' : ''} sur {fd.total} · {verdictCourt(fd)}</p>
              {(() => {
                const d = detailDe(p.id)
                const manque = d.filter((x) => x.fam !== 'bon')
                const bon = d.filter((x) => x.fam === 'bon')
                // ce qui manque d'abord ; une card verte ne montre que du vert
                const montre = [...manque, ...bon].slice(0, DETAIL_MAX)
                const reste = d.length - montre.length
                return (
                  <ul className="detail" aria-label={manque.length ? 'Ce qui manque, puis ce qui est bon' : 'Tout est bon'}>
                    {montre.map((x) => (
                      <li key={x.id} className={x.fam}><i className="pt" data-fam={x.fam} /><span><Texte t={x.titre} /></span></li>
                    ))}
                    {reste > 0 && <li className="plus">+ {reste} autre{reste > 1 ? 's' : ''}{manque.length > DETAIL_MAX ? ` (dont ${manque.length - DETAIL_MAX} qui manque${manque.length - DETAIL_MAX > 1 ? 'nt' : ''})` : bon.length > montre.filter((x) => x.fam === 'bon').length ? ', toutes bonnes' : ''}</li>}
                  </ul>
                )
              })()}
            </a>
          )
        })}
      </div>

      {/* la légende : une ligne, qui dit QUI agit — la bille de chaque rangée est l'état de l'enregistrement */}
      <p className="legende-pied">
        <span><i className="pt" data-fam="trancher" /><b>à trancher</b> = toi</span>
        <span><i className="pt" data-fam="valider" /><b>à valider</b> = toi et moi</span>
        <span><i className="pt" data-fam="chantier" /><b>en chantier</b> = moi</span>
        <span><i className="pt" data-fam="bon" /><b>bon</b> = branché et vérifié</span>
        <span>Une rangée ouvre la page de sa brique — le coût et la preuve y vivent.</span>
      </p>

      <ul className="liste">
        {SECTIONS.map((s) => {
          const xs = lignes(s.fam)
          if (!xs.length) return null
          return (
            <span key={s.fam} style={{ display: 'contents' }}>
              <li className={'grp' + (s.plie ? ' ferme' : '')} data-grp={s.fam} data-plie={s.plie ? '' : undefined} role={s.plie ? 'button' : undefined} tabIndex={s.plie ? 0 : undefined}>
                <i className="pt" data-fam={s.fam} />{s.titre}<span className="n">{xs.length}</span>{s.plie && <Ic id="chev" className="ic chev" />}
              </li>
              {xs.map((x) => ('etat' in x ? <Rangee key={x.id} b={x} lien /> : <RangeeMesure key={x.id} m={x} lien />))}
            </span>
          )
        })}
        <li className="rien-a-faire" hidden>Rien dans cette sélection.</li>
      </ul>

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

    </section>
  )
}
