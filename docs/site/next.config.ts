import type { NextConfig } from 'next'
import createMDX from '@next/mdx'

// Next.js sert de COMPILATEUR : export statique, une seule route, zéro composant
// client. Le livrable (docs/site/index.html) est produit par tools/docsite/inliner.mjs
// à partir de out/index.html — c'est LUI qu'on ouvre, jamais out/ en file://.
const config: NextConfig = {
  output: 'export',
  trailingSlash: true,
  pageExtensions: ['ts', 'tsx', 'md', 'mdx'],
  images: { unoptimized: true },
  reactStrictMode: true,
  devIndicators: false,
}

const withMDX = createMDX({})

export default withMDX(config)
