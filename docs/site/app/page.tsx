import type { ComponentType } from 'react'
import { PAGE_PAR_ID } from '@/content/pages'
import type { Page } from '@/content/types'
import { Etat } from '@/components/Etat'
import { Serveur } from '@/components/Serveur'
import { Hero } from '@/components/Composants'
import { dernierePasse } from '@/components/passe'
import Flow from '@/content/pages/flow.mdx'
import Widgets from '@/content/pages/widgets.mdx'
import Coffre from '@/content/pages/coffre.mdx'
import Annonces from '@/content/pages/annonces.mdx'
import Forge from '@/content/pages/forge.mdx'
import Histoire from '@/content/pages/histoire.mdx'
import Porte from '@/content/pages/porte.mdx'
import Qa from '@/content/pages/qa.mdx'
import { HeroQA } from '@/components/QA'

// UNE route : les neuf pages empilées en <section class="page">, le JS n'en montre qu'une.
// C'est la source du fichier unique produit par scripts/inliner.mjs.
// 30-08 : « Économie & annonces » (regles.mdx) est devenue coffre.mdx + annonces.mdx.
// 13-09 : « Widgets » (widgets.mdx) — les quatre widgets, leurs chambres et leur back-end.
// 14-09 : « Test QA » (qa.mdx) — le compte de bout en bout, validé ensemble front et back ; son hero compte des ÉTAPES, pas des briques.
const DOMAINES: [Page, ComponentType][] = [['flow', Flow], ['widgets', Widgets], ['coffre', Coffre], ['annonces', Annonces], ['forge', Forge], ['histoire', Histoire], ['porte', Porte], ['qa', Qa]]

export default function Site() {
  return (
    <>
      <Etat />
      <Serveur />
      {DOMAINES.map(([id, Contenu]) => {
        const p = PAGE_PAR_ID[id]
        return (
          <section key={id} className="page" id={id}>
            <h1>{p.libelle}</h1>
            <p className="phrase">{p.phrase}</p>
            {id === 'qa' ? <HeroQA /> : <Hero page={id} />}
            <Contenu />
          </section>
        )
      })}
      <p className="pied">
        Woop · <span className="mono">ytnnyjkramgiqyxdrkcu</span> · les états sont écrits à la main dans <span className="mono">content/</span>, le build ne fait que la mise en forme · dernière passe le {dernierePasse()}.
      </p>
    </>
  )
}
