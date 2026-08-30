import type { MDXComponents } from 'mdx/types'
import { Brique, Liste, Schema, Decision, Savoir, Hero, Tableau, Lexique, Sondes } from '@/components/Composants'

// Les composants disponibles dans la prose MDX des pages (content/pages/*.mdx).
// La prose ne porte JAMAIS un état : elle place une <Brique id/> qui le lit.
export function useMDXComponents(components: MDXComponents): MDXComponents {
  return { Brique, Liste, Schema, Decision, Savoir, Hero, Tableau, Lexique, Sondes, ...components }
}
