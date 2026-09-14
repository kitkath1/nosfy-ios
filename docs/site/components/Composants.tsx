import { readFileSync, existsSync } from 'node:fs'
import { join } from 'node:path'
import type { ReactNode } from 'react'
import type { Brique, Etat, Mesure, Page, Genre } from '@/content/types'
import { SERVEUR } from '@/content/serveur'
import { BRIQUES } from '@/content/briques'
import { MESURES } from '@/content/mesures'
import { SONDES } from '@/content/sondes'
import { PAGE_PAR_ID, DOMAINE_PAR_ID } from '@/content/pages'
import { EMOJI, compter, compterFamilles, estVert, famille, ligneFamilles, parPage, mesuresPar, preuveTexte, verdict } from '@/content'
import { Ic } from './Sprite'

const RACINE = join(process.cwd(), '..', '..')
const SITE = process.cwd()

/* ── le texte d'un titre : `code` entre accents graves ─────────────────── */
export function Texte({ t }: { t: string }) {
  const parts = t.split('`')
  return <>{parts.map((p, i) => (i % 2 ? <code key={i}>{p}</code> : p))}</>
}

/* ── la pastille : un verre neutre, l'emoji est la seule couleur ────────── */
export function Pastille({ etat, libelle }: { etat: Etat; libelle?: string }) {
  return <span className={`p p-${etat}`}>{EMOJI[etat]}{libelle ? ` ${libelle}` : ''}</span>
}

/* ── une brique en ligne (pastille + titre), pour la prose ──────────────── */
export function Brique({ id }: { id: string }) {
  const b = [...SERVEUR, ...BRIQUES].find((x) => x.id === id)
  if (!b) return <span className="p p-cx">?</span>
  return <span className="brique" id={b.id} data-dom={b.domaine}><Pastille etat={b.etat} /> <Texte t={b.titre} /></span>
}

/* ── la rangée Linear ───────────────────────────────────────────────────── */
function Preuve({ p }: { p: Brique['preuve'] }) {
  const { texte, vide } = preuveTexte(p)
  return <code className={vide ? 'vide' : ''} title={'fichier' in p ? p.fichier : undefined}>{texte}</code>
}

/**
 * `data-fam` = la famille (à trancher · à valider · en chantier · bon, content/index.ts) — ce que les filtres
 * de l'accueil lisent (public/site.js).
 *
 * ⚠️ La BILLE d'une rangée d'accueil porte la FAMILLE, pas l'état (30-08 soir) : sous « À trancher — toi »
 * (bille blanche) les trois lignes montraient une bille grise et deux anneaux vides — la légende qu'on venait
 * de lire ne s'appliquait à aucune ligne. L'état détaillé (🟡 local, 🔵 serveur seul, ⚪ absent, ◌ à mesurer)
 * reste sur la page de la brique, où il a la place d'être expliqué.
 */
export function Rangee({ b, lien }: { b: Brique; lien?: boolean }) {
  return (
    <li className={'r' + (b.litige ? ' litige' : '')} id={lien ? undefined : b.id} data-src={lien ? b.id : undefined} data-onglet={lien ? b.page : undefined}
        data-etat={b.etat} data-fam={famille(b)} data-dom={b.domaine} title={lien ? undefined : b.litige || b.note}>
      {lien ? <i className="pt" data-fam={famille(b)} /> : <Pastille etat={b.etat} />}
      <span className="t"><Texte t={b.titre} /></span>
      <span className="m">
        {lien
          ? <span className="d">{DOMAINE_PAR_ID[b.domaine]?.libelle}</span>
          : <><span className="c">{b.cout ?? ''}</span><Preuve p={b.preuve} /></>}
      </span>
      {lien && <Ic id="chev" className="ic chev" />}
    </li>
  )
}

export function RangeeMesure({ m, lien }: { m: Mesure; lien?: boolean }) {
  return (
    <li className="r nm" id={lien ? undefined : m.id} data-onglet={lien ? m.page : undefined} data-etat="nm" data-fam={famille(m)} data-dom={m.domaine} title={lien ? undefined : m.note}>
      {lien ? <i className="pt" data-fam={famille(m)} /> : <i className="pt" data-etat="nm" />}
      <span className="t"><Texte t={m.titre} />{m.lecture && m.lecture !== 'inconnu' ? <span className="lecture"> ({EMOJI[m.lecture]} au code)</span> : null}</span>
      <span className="m">
        {lien
          ? <span className="d">{DOMAINE_PAR_ID[m.domaine]?.libelle}</span>
          : <><span className="c">{m.cout ?? ''}</span><Preuve p={m.preuve} /></>}
      </span>
      {lien && <Ic id="chev" className="ic chev" />}
    </li>
  )
}

/** Les briques d'une page, filtrées par états ; `mesures` ajoute les ◌ de la page. */
export function Liste({ page, etats, mesures, vide }: { page: Page; etats?: Etat[]; mesures?: boolean; vide?: string }) {
  const bs = parPage(page).filter((b) => !b.genre).filter((b) => !etats || etats.includes(b.etat))
  const ms = mesures ? mesuresPar(page) : []
  if (!bs.length && !ms.length) return vide ? <p className="rien">{vide}</p> : null
  return (
    <ul className="liste">
      {bs.map((b) => <Rangee key={b.id} b={b} />)}
      {ms.map((m) => <RangeeMesure key={m.id} m={m} />)}
    </ul>
  )
}

/**
 * LES RENVOIS (13-09, la page Widgets) : les lignes de la carte du serveur (`genre`) POSÉES sur une page de
 * domaine. Leur pastille vit dans les tables de la carte — l'invariant compte chaque brique UNE fois — donc ici
 * elles sont rendues en RENVOI, la forme de l'accueil : la bille de famille, le titre, le domaine, le chevron ;
 * un clic ouvre la carte du serveur sur la ligne.
 */
export function Renvois({ page, etats, vide }: { page: Page; etats?: Etat[]; vide?: string }) {
  const bs = parPage(page).filter((b) => !!b.genre).filter((b) => !etats || etats.includes(b.etat))
  if (!bs.length) return vide ? <p className="rien">{vide}</p> : null
  return (
    <ul className="liste">
      {bs.map((b) => <Rangee key={b.id} b={{ ...b, page: 'serveur' }} lien />)}
    </ul>
  )
}

/* ── la carte du serveur : une table par genre ──────────────────────────── */
const ENTETES: Record<Genre, string[]> = {
  table: ['', 'Table', 'À quoi ça sert'],
  fonction: ['', 'Fonction', 'Ce qu\'elle fait'],
  regle: ['', 'Clé', 'Valeur', 'Ce que ça règle'],
  edge: ['', 'Edge function', 'Ce qu\'elle fait'],
  index: ['', 'Index', 'Il empêche'],
}
export function Tableau({ genre }: { genre: Genre }) {
  const rows = SERVEUR.filter((b) => b.genre === genre)
  return (
    <div className="tw"><table className={`serveur ${genre}`}>
      <thead><tr>{ENTETES[genre].map((h, i) => <th key={i}>{h}</th>)}</tr></thead>
      <tbody>
        {rows.map((b) => (
          <tr key={b.id} id={b.id} data-dom={b.domaine} className={b.litige ? 'litige' : ''}>
            <td className="etat"><Pastille etat={b.etat} libelle={b.note && b.note.length <= 12 ? b.note : undefined} /></td>
            <td className="mono nom">{b.nom}</td>
            {genre === 'regle' && <td className="num">{b.valeur}</td>}
            <td className="quoi"><Texte t={b.quoi ?? ''} />{b.litige && <span className="litige-note"> ⚑ {b.litige}</span>}</td>
          </tr>
        ))}
      </tbody>
    </table></div>
  )
}

/** Les six videurs — des index, sans état : ils n'existent pas pour être branchés, ils existent pour empêcher. */
export function Videurs() {
  const V = [
    ['coin_ledger_gain_unique', 'Qu\'une même séance crédite deux fois des pièces.'],
    ['user_boosters_seance_unique', 'Qu\'une même séance donne deux sachets.'],
    ['coin_ledger_retour_jour_unique', 'Qu\'on prenne le versement quotidien deux fois le même jour (compté en UTC).'],
    ['coin_ledger_chemin_unique', 'Qu\'un nœud du chemin paie deux fois en pièces.'],
    ['user_boosters_chemin_unique', 'Qu\'un nœud du chemin donne deux sachets.'],
    ['user_boosters_noir_ouvert_unique', 'Qu\'on ait deux sachets noirs en attente à la fois.'],
  ]
  return (
    <div className="tw"><table className="serveur index">
      <thead><tr><th>Index</th><th>Il empêche</th></tr></thead>
      <tbody>{V.map(([n, q]) => <tr key={n}><td className="mono nom">{n}</td><td className="quoi">{q}</td></tr>)}</tbody>
    </table></div>
  )
}

/* ── le schéma : un SVG pré-rendu, inline ───────────────────────────────── */
export function Schema({ id, titre, legende, plie }: { id: string; titre?: string; legende?: string; plie?: boolean }) {
  const chemin = join(SITE, 'content/schemas', id + '.svg')
  const svg = existsSync(chemin) ? readFileSync(chemin, 'utf8').replace(/^<!--[^>]*-->\n?/, '') : ''
  const fig = (
    <figure className="plan" data-schema={id}>
      {svg ? <div className="svg" dangerouslySetInnerHTML={{ __html: svg }} /> : <p className="sans-plan">Schéma non rendu : `npm run schemas`.</p>}
      {legende && <figcaption>{legende}</figcaption>}
    </figure>
  )
  if (!plie) return fig
  return <details className="bloc plie"><summary><b>{titre ?? id}</b></summary>{fig}</details>
}

/* ── le hero de domaine ─────────────────────────────────────────────────── */
type Ecran = { nom: string; legende: string; fichier: string | null; largeur?: number; hauteur?: number; composant?: string }
type Captures = { flow: Ecran[]; onboarding?: Ecran[]; popups?: Ecran[]; hero: Record<string, { fichier: string | null; largeur?: number; hauteur?: number }> }
export function lireCaptures(): Captures {
  const p = join(SITE, 'content/captures.json')
  if (!existsSync(p)) return { flow: [], onboarding: [], popups: [], hero: {} }
  try { return JSON.parse(readFileSync(p, 'utf8')) } catch { return { flow: [], onboarding: [], popups: [], hero: {} } }
}

/* ── le catalogue des pop-ups et des toasters (14-09) ─────────────────────── */
// « Fais des screenshots de toutes les variantes de pop-up qu'on a, toutes les robes, et les
// toaster notifications ; nomme-les bien en composant pour qu'on puisse éditer ou pas. »
// Une figure par variante, EN COULEUR (on juge des robes, pas un flow), le composant Swift
// sous la légende — c'est lui qu'on édite, ou pas. Les captures viennent du banc de chaque
// composant (tools/docsite/capturer-popups.sh) ; une variante non capturée le dit.
export function PopUps() {
  const ecrans = lireCaptures().popups ?? []
  return (
    <>
      <div className="flow-titre">
        <h2>Le catalogue des pop-ups et des toasters</h2>
        <p>Toutes les robes qui existent dans le code, une capture chacune, prise sur le banc du composant au simulateur (figée quand le banc le permet). Sous chaque capture : le composant Swift et sa robe — c&apos;est ce qu&apos;on décide d&apos;éditer, ou pas. Pour rejouer une capture : <code>tools/docsite/capturer-popups.sh</code>.</p>
      </div>
      <div className="flow flow-couleur popups">
        {ecrans.length ? ecrans.map((f) => (
          <figure key={f.nom} className={'ecran' + (f.fichier ? '' : ' vide')} data-ecran={f.nom}>
            {f.fichier ? <img src={`/captures/popups/${f.fichier.split('/').pop()}`} width={f.largeur} height={f.hauteur} alt={f.legende} loading="lazy" decoding="async" /> : <span className="cadre-vide" />}
            <figcaption>{f.legende}{f.fichier ? '' : ' · à capturer'}{f.composant ? <><br /><code>{f.composant}</code></> : null}</figcaption>
          </figure>
        )) : <p className="rien">`npm run captures` pour embarquer les captures.</p>}
      </div>
    </>
  )
}

/* ── le bandeau de l'onboarding (13-09 : « une capture de chaque étape ») ─── */
// La même robe que « Le flow » de l'accueil : de vraies captures du simulateur, fondues
// au noir, dans l'ordre du film ; les étapes qui n'existent pas encore restent « à capturer ».
export function Onboarding() {
  const ecrans = lireCaptures().onboarding ?? []
  return (
    <>
      <div className="flow-titre">
        <h2>L'onboarding, étape par étape</h2>
        <p>Le film de Nosfy tel qu'il joue au simulateur (`-nosfy -nosfyAuto -rewardAuto`), en noir et blanc — la robe du site ne porte la couleur qu'à quatre endroits, et le halo de Nosfy n'en fait pas partie. Les quatre temps de la visite guidée de la Home restent à capturer : elle n'existe pas encore.</p>
      </div>
      <div className="flow flow-sourd">
        {ecrans.length ? ecrans.map((f) => (
          <figure key={f.nom} className={'ecran' + (f.fichier ? '' : ' vide')} data-ecran={f.nom}>
            {f.fichier ? <img src={`/captures/onboarding/${f.fichier.split('/').pop()}`} width={f.largeur} height={f.hauteur} alt={f.legende} loading="lazy" decoding="async" /> : <span className="cadre-vide" />}
            <figcaption>{f.legende}{f.fichier ? '' : ' · à capturer'}</figcaption>
          </figure>
        )) : <p className="rien">`npm run captures` pour embarquer les captures.</p>}
      </div>
    </>
  )
}

export function Hero({ page }: { page: Page }) {
  const info = PAGE_PAR_ID[page]
  // ⚠️ le compte du hero est celui des FAMILLES (30-08 soir) — `compter()` garde les lignes `reference: true`
  // et affichait « Serveur · 87 briques » quand la card de l'accueil, elle, annonçait 55.
  const f = compterFamilles(parPage(page), mesuresPar(page))
  const c = { total: f.total }
  const cap = lireCaptures().hero[page]
  const teinte = info.hero?.teinte
  // LE VERT (30-08) : tout bon sur la page (briques ET ◌) → la classe `vert` (app/styles/v2.css) prend la
  // teinte de l'état à la place de la teinte mesurée — la même règle que les cards et le hero de l'accueil.
  // La teinte mesurée est posée en style inline (elle gagnerait sur la classe) : on ne la pose pas.
  const vert = estVert(f)
  const noir = !teinte && !vert
  const style = teinte && !vert ? ({ '--t1': teinte.t1, '--t2': teinte.t2 } as React.CSSProperties) : undefined
  return (
    <div className={'hero-dom' + (vert ? ' vert' : noir ? ' noir' : '')} style={style} data-teinte={vert ? 'vert : tout branché, rien ne ment' : teinte?.source}>
      {!noir && <div className="grain" aria-hidden="true" />}
      {cap?.fichier ? (
        <img src={`/captures/hero/${cap.fichier.split('/').pop()}`} width={cap.largeur} height={cap.hauteur} alt="" decoding="async" />
      ) : info.hero?.lune ? (
        <svg className="lune" viewBox="0 0 749 718" aria-hidden="true"><use href="#i-lune" /></svg>
      ) : (
        <span className="a-capturer">à capturer</span>
      )}
      <p className="sur">{info.libelle} · {c.total} brique{c.total > 1 ? 's' : ''}</p>
      <p className="verdict">{verdict(f)}</p>
      {/* la même ligne à quatre familles que les cards de l'accueil ; les zéros ne s'écrivent pas */}
      <p className="comptes">{ligneFamilles(f).join(' · ')}</p>
    </div>
  )
}

/* ── panneaux ───────────────────────────────────────────────────────────── */
export function Decision({ children, titre = 'À trancher' }: { children: ReactNode; titre?: string }) {
  return <div className="decision"><b>{titre}</b><div>{children}</div></div>
}
export function Savoir({ children, titre = 'Ce qu\'il faut savoir' }: { children: ReactNode; titre?: string }) {
  return <details className="bloc savoir"><summary><b>{titre}</b></summary><div className="corps-savoir">{children}</div></details>
}

/* ── les sondes HTTP : la seule preuve dure ─────────────────────────────── */
export function Sondes() {
  return (
    <ul className="sondes">
      {SONDES.map((s) => (
        <li key={s.id}><code className="req">{s.requete}</code><code className="rep">{s.reponse}</code><span>{s.prouve}</span></li>
      ))}
    </ul>
  )
}

/* ── le lexique : les six idées, une ligne chacune ──────────────────────── */
export function Lexique() {
  const L = [
    ['Le carnet', 'le solde n\'est stocké nulle part : c\'est l\'addition de coin_ledger, refaite à chaque fois.'],
    ['Le videur', 'un index unique refuse une deuxième ligne pour la même séance — il ne se remet jamais à zéro.'],
    ['Idempotent', 'tu peux sonner dix fois, il n\'ouvre qu\'une porte : le serveur ne crédite qu\'une fois.'],
    ['La file d\'attente', 'sans réseau, la demande attend dans le téléphone et repart seule — sûre grâce au videur.'],
    ['RLS', 'la clé de l\'app est publique ; ce qui protège tes données, c\'est « chacun ne voit que ses lignes ».'],
    ['Les prix en base', '« 20 pièces par série » vit dans reward_rules : le changer ne demande pas de version.'],
  ]
  return <dl className="lexique">{L.map(([t, d]) => <div key={t}><dt>{t}</dt><dd>{d}</dd></div>)}</dl>
}

/* ── le dictionnaire des colonnes (plié) ────────────────────────────────── */
export function Dictionnaire() {
  const p = join(SITE, 'content/dictionnaire.json')
  const d: Record<string, { titre: string; html: string }> = existsSync(p) ? JSON.parse(readFileSync(p, 'utf8')) : {}
  const summaries = BRIQUES.filter((b) => b.page === 'serveur' && b.genre === 'table' && b.quoi === 'dictionnaire')
  const autres = BRIQUES.filter((b) => b.page === 'serveur' && b.genre === 'table' && b.quoi !== 'dictionnaire')
  const cle = (b: Brique) => Object.keys(d).find((k) => b.nom && k.startsWith(b.nom.replace(/_/g, '-').split(' ')[0].toLowerCase()))
  return (
    <div className="dictionnaire">
      {summaries.map((b) => {
        const k = cle(b)
        return (
          <details className="bloc" key={b.id}>
            <summary id={b.id} data-dom={b.domaine}><Pastille etat={b.etat} /> <b><Texte t={b.titre} /></b></summary>
            {k && d[k] ? <div dangerouslySetInnerHTML={{ __html: d[k].html }} /> : <p className="note">Colonnes : voir la migration citée en preuve.</p>}
          </details>
        )
      })}
      <details className="bloc">
        <summary><b>cards · user_cards · syntheses · booster_progress</b></summary>
        <div className="tw"><table className="serveur table">
          <thead><tr><th></th><th>Table</th><th>État</th></tr></thead>
          <tbody>{autres.map((b) => (
            <tr key={b.id} id={b.id} data-dom={b.domaine}><td className="etat"><Pastille etat={b.etat} /></td><td className="mono nom">{b.nom}</td><td className="quoi"><Texte t={b.quoi ?? ''} /></td></tr>
          ))}</tbody>
        </table></div>
      </details>
      {['ddl', 'le-mod-le-up-down'].map((k) => d[k] && (
        <details className="bloc" key={k}><summary><b>{d[k].titre}</b></summary><div dangerouslySetInnerHTML={{ __html: d[k].html }} /></details>
      ))}
    </div>
  )
}

/* ── le menu Supabase : un seul, plié ───────────────────────────────────── */
export function MenuSupabase() {
  const P = 'https://supabase.com/dashboard/project/ytnnyjkramgiqyxdrkcu'
  const L: [string, string][] = [['Tables', '/editor'], ['Fonctions', '/database/functions'], ['Index', '/database/indexes'], ['Comptes', '/auth/users'], ['Edge functions', '/functions'], ['Journaux', '/logs/explorer'], ['Éditeur SQL', '/sql/new']]
  return (
    <details className="menu-sb">
      <summary className="pill">Ouvrir dans Supabase <Ic id="arrow" /></summary>
      <div>{L.map(([l, u]) => <a key={u} href={P + u} target="_blank" rel="noopener">{l}<Ic id="arrow" /></a>)}</div>
    </details>
  )
}
