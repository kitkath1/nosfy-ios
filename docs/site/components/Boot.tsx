'use client'
import { useEffect } from 'react'

/**
 * LE RÉVEIL DE site.js — le seul composant client du site, et il ne rend rien.
 *
 * public/site.js pose des classes (`js`, `entree`, `.in`, `.on`) sur un DOM que React
 * s'apprête à hydrater : en `next dev` l'hydratation est lente, le script la double, et
 * React signale un décalage (« 1 Issue » sur la page de référence). Ici, quand Next est
 * présent, site.js attend ce useEffect — qui court APRÈS l'hydratation. Dans le fichier
 * unique (l'inliner retire tout script Next), site.js démarre seul : voir sa dernière ligne.
 */
export function Boot() {
  useEffect(() => {
    const w = window as unknown as { __woopHydrate?: boolean; woopInit?: () => void }
    w.__woopHydrate = true
    w.woopInit?.()
  }, [])
  return null
}
