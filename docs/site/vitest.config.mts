import { defineConfig } from 'vitest/config'

// Les tests lisent des fichiers (le livrable, content/, le dépôt) : Node, rien d'autre.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.ts'],
    passWithNoTests: false,
  },
})
