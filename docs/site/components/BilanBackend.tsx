import type { ReactNode } from 'react'
import { parId } from '@/content'

/** Le bilan backend suit ses preuves ; les mesures de l’app restent séparées. */
export function BilanBackend({ titre, ids, children }: {
  titre: string; ids: string[]; children: ReactNode
}) {
  const briques = ids.map(id => {
    const brique = parId(id)
    if (!brique) throw new Error(`Brique backend inconnue : ${id}`)
    return brique
  })
  const valide = briques.length > 0 && briques.every(b => b.etat === 'ok' && !b.litige)
  return (
    <div className="decision">
      <b style={{ color: valide ? 'var(--ok)' : 'var(--encre-2)' }}>
        {titre} : {valide ? 'tout bon' : 'à vérifier'}
      </b>
      <div>{children}</div>
    </div>
  )
}
