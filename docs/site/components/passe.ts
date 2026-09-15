import { readdirSync, statSync } from 'node:fs'
import { join } from 'node:path'

/**
 * « Dernière passe le … » : la date du fichier de content/ modifié LE PLUS RÉCEMMENT, lue au build
 * (serveur, jamais dans le navigateur). Jusqu'au 15-09 c'était une chaîne en dur — « 30 août 2026 »
 * — que toutes les passes de septembre avaient oubliée : le pied du site mentait par retard, comme
 * un livrable. Une date qui se dérive ne s'oublie pas.
 */
export function dernierePasse(): string {
  const racine = join(process.cwd(), 'content')
  let max = 0
  const marche = (d: string) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name)
      if (e.isDirectory()) marche(p)
      else if (/\.(ts|tsx|mdx|json|mmd)$/.test(e.name)) max = Math.max(max, statSync(p).mtimeMs)
    }
  }
  marche(racine)
  return new Intl.DateTimeFormat('fr-FR', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Europe/Paris' }).format(new Date(max))
}
