import type { ComponentType } from 'react'
import { PAGE_PAR_ID } from '@/content/pages'
import type { Page } from '@/content/types'
import { Etat } from '@/components/Etat'
import { Serveur } from '@/components/Serveur'
import { Hero } from '@/components/Composants'
import Flow from '@/content/pages/flow.mdx'
import Regles from '@/content/pages/regles.mdx'
import Forge from '@/content/pages/forge.mdx'
import Histoire from '@/content/pages/histoire.mdx'
import Porte from '@/content/pages/porte.mdx'

// UNE route : les sept pages empilées en <section class="page">, le JS n'en montre qu'une.
// C'est la source du fichier unique produit par scripts/inliner.mjs.
const DOMAINES: [Page, ComponentType][] = [['flow', Flow], ['regles', Regles], ['forge', Forge], ['histoire', Histoire], ['porte', Porte]]

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
            <Hero page={id} />
            <Contenu />
          </section>
        )
      })}
      <p className="pied">
        Woop · <span className="mono">ytnnyjkramgiqyxdrkcu</span> · les états sont écrits à la main dans <span className="mono">content/</span>, le build ne fait que la mise en forme · dernière passe le 30 août 2026.
      </p>
    </>
  )
}
