import type { ReactNode } from 'react'
import localFont from 'next/font/local'
import './styles/robe.css'
import './styles/v2.css'
import { Sprite } from '@/components/Sprite'
import { Rail, Barre } from '@/components/Rail'
import { Boot } from '@/components/Boot'

// Inter, la police de l'app (Nosfy/Fonts/), auto-hébergée : le sous-ensemble latin de la
// variable (opsz + wght), 100 Ko — zéro requête réseau, la même Inter hors ligne.
const inter = localFont({
  src: '../fonts/InterVariable-latin.woff2',
  variable: '--police',
  weight: '300 700',
  display: 'swap',
  fallback: ['-apple-system', 'SF Pro Text', 'system-ui', 'sans-serif'],
})

export const metadata = {
  title: 'Documentation Nosfy',
  description: "L'état vérifié du back-end de Nosfy : ce qui marche, ce qui ment, ce qui manque.",
}

export default function Layout({ children }: { children: ReactNode }) {
  return (
    // suppressHydrationWarning : public/site.js pose `js` sur <html> et `entree` sur <body>
    // AVANT que React ne compare le HTML servi au DOM (script `defer`) — sans ça, le mode dev
    // affiche « 1 Issue » sur la page de référence pour un décalage voulu.
    <html lang="fr" className={inter.variable} suppressHydrationWarning>
      <head>
        <meta charSet="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="color-scheme" content="dark" />
      </head>
      <body suppressHydrationWarning>
        <Sprite />
        <div className="cadre">
          <Rail />
          <main className="corps">
            <Barre />
            {children}
          </main>
        </div>
        <script src="/site.js" defer />
        <Boot />
      </body>
    </html>
  )
}
