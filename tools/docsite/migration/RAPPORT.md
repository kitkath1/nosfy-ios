# Rapport de migration v1 → v2 (généré par tools/docsite/migrer.py)

| onglet v1 | 🟢 | 🟡 | 🔵 | ⚪ | 🔴 | total |
|---|---|---|---|---|---|---|
| six | 0 | 0 | 0 | 0 | 1 | 1 |
| carte | 22 | 0 | 27 | 3 | 0 | 52 |
| schema | 6 | 0 | 2 | 1 | 0 | 9 |
| diag | 0 | 1 | 1 | 2 | 2 | 6 |
| flow | 0 | 3 | 2 | 3 | 1 | 9 |
| regles | 2 | 0 | 1 | 5 | 0 | 8 |
| forge | 4 | 0 | 3 | 2 | 2 | 11 |
| histoire | 0 | 1 | 1 | 4 | 0 | 6 |
| porte | 1 | 0 | 0 | 5 | 5 | 11 |
| manege | 0 | 0 | 0 | 1 | 0 | 1 |
| **total** | 35 | 5 | 37 | 26 | 11 | **114** |

serveur.ts : 52 · briques.ts : 62 · mesures.ts : 22

## Ids générés (à relire) — 65

- `b-six-voir-compte-pour-la-remise`
- `b-tb-coin-ledger`
- `b-tb-user-boosters`
- `b-tb-reward-rules`
- `b-tb-workouts`
- `b-tb-logged-exercises`
- `b-tb-strength-sets`
- `b-tb-cards`
- `b-fn-cloturer-seance`
- `b-fn-etat-coffre`
- `b-fn-historique-gains`
- `b-fn-claim-booster`
- `b-fn-claim-retour-quotidien`
- `b-fn-reclamer-noeud-chemin`
- `b-fn-roll-rare`
- `b-fn-solde-or`
- `b-rg-pieces-par-serie`
- `b-rg-prix-booster`
- `b-rg-prix-booster-legendaire`
- `b-rg-pieces-retour-quotidien`
- `b-rg-popups-max-seance`
- `b-rg-reward-monetaire-max-seance`
- `b-rg-video-max-seance`
- `b-rg-notifs-max-seance`
- `b-rg-ecart-min-series`
- `b-rg-ecart-min-minutes`
- `b-rg-ecart-exige-les-deux`
- `b-rg-bonus-fort-progres-surprise`
- `b-rg-bonus-plafond-seance`
- `b-rg-meme-fait-max-seance-semaine`
- `b-rg-welcome-cooldown-jours`
- `b-rg-welcome-max-mois`
- `b-rg-annonce-une-par-evenement`
- `b-rg-top-mesures-cardio`
- `b-rg-top-fenetre-jours`
- `b-rg-top-min-seances`
- `b-ed-forge-card`
- `b-sc-workouts`
- `b-sc-coin-ledger`
- `b-sc-user-boosters`
- `b-sc-reward-rules`
- `b-sc-logged-exercises`
- `b-sc-cards`
- `b-sc-user-cards`
- `b-sc-syntheses`
- `b-sc-booster-progress`
- `b-dg-le-solde-repart-a-zero`
- `b-dg-la-collection-est-vide-au`
- `b-dg-une-jauge-bloquee-a-0`
- `b-dg-une-belle-page-qu-on`
- `b-fl-la-troisieme-card-de-la`
- `b-rg-le-versement-lui-part-vraiment`
- `b-rg-booster-orange`
- `b-rg-piece-d-or`
- `b-rg-piece-d-argent`
- `b-rg-le-geant`
- `b-fo-poids-60-27-10-3`
- `b-fo-soit-une-carte-deja-peinte`
- `b-fo-si-on-lui-passe-l`
- `b-fo-le-tirage-la-rarete-le`
- `b-fo-user-cards-se-remplit-a`
- `b-fo-garantie-legendaire-du-sachet-noir`
- `b-st-les-pages-record-muscu-record`
- `b-st-point-d-entree-de-la`
- `b-po-onboarding-les-4-pages-existent`

## Preuves « à citer » (la dette visible) — 37

- `b-six-voir-compte-pour-la-remise`
- `b-dg-le-solde-repart-a-zero`
- `b-dg-la-collection-est-vide-au`
- `b-dg-une-jauge-bloquee-a-0`
- `b-dg-une-belle-page-qu-on`
- `b-flow-retour-chemin`
- `b-flow-coffre-parcours`
- `b-flow-overlay`
- `b-flow-deux-annonces`
- `b-fl-la-troisieme-card-de-la`
- `b-route-reclamee`
- `b-rg-le-versement-lui-part-vraiment`
- `b-rg-booster-orange`
- `b-profil-noir`
- `b-rg-piece-d-or`
- `b-rg-piece-d-argent`
- `b-rg-le-geant`
- `b-fo-poids-60-27-10-3`
- `b-fo-soit-une-carte-deja-peinte`
- `b-fo-si-on-lui-passe-l`
- `b-fo-le-tirage-la-rarete-le`
- `b-fo-user-cards-se-remplit-a`
- `b-fo-garantie-legendaire-du-sachet-noir`
- `b-st-moteur-faits`
- `b-st-top`
- `b-st-les-pages-record-muscu-record`
- `b-st-variant-serveur`
- `b-st-point-d-entree-de-la`
- `b-po-onboarding-les-4-pages-existent`
- `b-po-signup`
- `b-po-keychain`
- `b-po-supprimer`
- `b-po-deconnecter`
- `b-po-profil`
- `b-po-dire`
- `b-po-migrer`
- `b-mn-detecte`

## Preuves fichier:ligne NON résolues dans le dépôt — 0


## Titres tronqués à 60 — 0


## Sans domaine — 0




## Relecture adverse du 30-08 (workflow `relire-migration-docsite-v2`, 21 agents, ≈ 16 min)

Chaque section v1 (HEAD 6fbd13f) comparée pastille par pastille à `content/*.ts`, puis
chaque divergence contredite par un second agent. **114 = 114, aucun état changé, aucune
pastille perdue ni inventée.** Mais le rapport ci-dessus mentait sur un point : « Titres
tronqués à 60 — 0 » comptait APRÈS la coupe (`migrer.py:209` tronque, `:297` compte).

**21 divergences confirmées, corrigées à la main** (jamais dans le HTML) :
- 12 **titres coupés à 60 qui perdaient la fin porteuse du défaut** — « tour complet *jamais
  vu* », « aucun *Swift ne les lit* », « appelée en :109, *répond 500* », « jamais appelées
  *du client* », « où il *COMMENCE : nulle part* », « le rangement est posé, *le calcul
  reste* » ; trois blocs de la Forge dont le corps avait remplacé le titre (« La rareté est
  décidée au serveur », « Deux vitesses », « Elle sait sceller et garantir ») ; les quatre
  lignes du profil sans leur en-tête (« Profil : … ») ; `b-st-top` qui promettait deux
  chantiers pour un coût.
- **14 coûts perdus** : la migration lisait la section, le coût vivait sur le renvoi
  d'accueil (`serveur.ts` n'avait AUCUN `cout:`).
- **3 preuves régressées** : une sonde lancée devenue « à citer » (`b-route-reclamee`),
  une migration citée à l'accueil perdue (`b-st-moteur-faits`), une preuve qui pointait
  l'URL au lieu des identifiants (`b-po-identifiants` : `Supabase.swift:11,16,27-35`).
- Les lignes `SacreServeur.swift` relevées à HEAD 9ef6da1 (l'ancien :99/:109/:351/:380
  pointaient 4 à 32 lignes trop haut).

**16 réfutées** (v1 identique, ou postérieur au site), **16 mineures** (5 reprises : deux
titres pendants, `b-sc-logged-exercises`, `b-deux-nombres`, `b-compteur-descend`).

**L'accueil** : 79 rangées dérivées contre 47 renvois en v1 — le même fait s'y répétait
(`user_cards` ×4, les 16 clés de rythme une à une). Le drapeau `reference: true` (déjà dans
le type, ignoré par `aFaire()`) est posé sur 35 enregistrements (jamais sur un 🔴 : le compte des mensonges reste égal à la liste) : le détail d'une to-do
agrégée, un symptôme dont la cause est listée, un renvoi. Ils restent rendus sur leur page
et comptés dans les 114.
