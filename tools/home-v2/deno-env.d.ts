// Surface Deno utilisée par cette fonction, pour le contrôle TypeScript local
// sans installer un runtime. Le bundler Supabase vérifie aussi au déploiement.
declare const Deno: {
  env: { get(name: string): string | undefined };
  serve(handler: (request: Request) => Response | Promise<Response>): void;
};
