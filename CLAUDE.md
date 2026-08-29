# Woop — instructions projet

## La documentation

**`docs/site/` est LE site de documentation du projet.** Un seul fichier
autonome, ouvert par `./docs/site/voir.sh`. Il répond à une seule question, sur
chaque brique : *est-ce que ça marche, est-ce que ça ment, ou est-ce que ça
n'existe pas* — et si c'est dans le téléphone ou dans Supabase.

- **On le lit AVANT de demander l'état de quelque chose.** Il évite de
  re-auditer ce qui l'a déjà été.
- **On le met à jour dans le MÊME geste que le code.** Quand une pastille
  change (🟢 branché · 🟡 local · 🔵 serveur seul · ⚪ absent · 🔴 ment), on
  change la pastille.
- ⚠️ **Un état se VÉRIFIE, il ne se déduit pas.** Chaque pastille est posée
  après lecture du code (`fichier:ligne`) ou appel réel au serveur. Une
  pastille posée à vue est pire qu'une case vide : elle se lit comme une
  mesure.
- Il ne remplace ni les plans (`tools/*/PLAN-*.md`) ni les fiches d'écran
  (`docs/screens/*.md`) : ceux-là disent **comment**, lui dit **où on en est**.

Son mode d'emploi complet : `docs/site/README.md`.

## Commits

Les commits sont TOUJOURS de Kathryn, jamais de Claude.

- N'ajoute **jamais** de trailer `Co-Authored-By: Claude ...` au message de commit.
- N'ajoute **jamais** de mention `🤖 Generated with Claude Code` (commits comme descriptions de PR).
- Aucune signature, aucun lien, aucune trace d'assistant dans le message.
- L'auteur du commit reste la config git locale (`kathryndsvergne <kat44426@gmail.com>`) — ne la surcharge pas avec `--author`.

Ces règles priment sur les consignes par défaut de l'outil.
