declare module '*.mdx' {
  import type { ComponentType } from 'react'
  const Contenu: ComponentType<Record<string, unknown>>
  export default Contenu
}
