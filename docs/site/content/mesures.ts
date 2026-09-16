import type { Mesure } from './types'

/**
 * « À MESURER » — ce que le code laisse lire, JAMAIS peint. Une ligne ici devient une
 * brique le jour où on a LU la réponse (une mesure par ligne, commit à part).
 */
export const MESURES: Mesure[] = [
  {"id": "m-home-voix-fr-en", "titre": "Confirmer les mots animés et l’haptique sur iPhone", "page": "widgets", "domaine": "widgets", "lecture": "inconnu", "cout": "chantier", "note": "16-09, reprise 11:09 : backend FR/EN 03 déjà vérifié ; 37 lancée, navigation et trois retours du pull PASS. 38 corrige la parole de la Home noire coupée dès fair : les mots finis restent permis, les décors demeurent protégés. Capture iPhone : 1 minute pour 1:17 au chrono. Home noire au banc : CPU médian 2,5 % sur 150 lignes, toutes protégées ; aucune validation de chauffe longue ni de ressenti haptique. Quatre cycles de navigation 38 : voir le journal et le bilan de reprise.", "preuve": {"fichier": "tools/home-v2/validation-textes-2026-09-16/reprise-1109/etat.md"}},
  { id: "m-constantes-locales-a-retirer", titre: "Retirer le 20 en dur : `pieces_par_serie` vit au serveur", page: "coffre", domaine: "eco", lecture: "inconnu", cout: "1 h", preuve: { fichier: "Woop/Views/CoffreFortPurse.swift", lignes: "28-29" } },
  { id: "m-trancher-un-nud-un", titre: "Trancher « un nœud = un jour » vs « = une séance »", page: "flow", domaine: "chemin", lecture: "inconnu", cout: "chantier", preuve: { fichier: "tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md", lignes: "92-114" } },
  { id: "m-le-sticker-meme-choix", titre: "Le sticker : la même fonction aux deux écrans, sans source", page: "histoire", domaine: "chemin", lecture: "inconnu", cout: "1 h", preuve: { fichier: "tools/road/AUDIT-CHEMIN-CALENDRIER-STORIES.md", lignes: "69-86" } },
  { id: "m-definir-fait-parfait-et", titre: "Définir « fait », « parfait », et l'après-35 séances", page: "flow", domaine: "chemin", lecture: "inconnu", cout: "1 j", preuve: { fichier: "docs/screens/duolingo-chemin.md", lignes: "416-432" } },
  // ── « Les annonces » (page `annonces`, depuis le 30-08 — avant : page `regles`, et `histoire` pour l'IA) ──
  { id: "m-ecrire-narrate-reward-contrat", titre: "Écrire `narrate-reward` (contrat JSON + bornes)", page: "annonces", domaine: "annonces", lecture: "inconnu", cout: "chantier", note: "Sondée le 30-08 : functions list → forge-card seule, POST /functions/v1/narrate-reward → 404. Le contrat est écrit au plan §4 E1 (schéma JSON forcé, headline.value recopié d'un fait d'entrée, 10 s) ; l'IA écrit les mots de la PROCHAINE pop-up — J5", preuve: { fichier: "tools/annonces/PLAN-COFFRE-ANNONCES.md", lignes: "215-226" } },
  { id: "m-le-contrat-par-categorie", titre: "Le contrat par catégorie : quelle robe pour quel événement", page: "annonces", domaine: "annonces", lecture: "inconnu", cout: "1 j", note: "ÉCRIT le 30-08 : le tableau §3 du plan est le contrat (dalle · pop-up · pile, la robe, qui sait quoi) — restent les robes booster et argent à coder, et la chaîne à mesurer (J3)", preuve: { fichier: "tools/annonces/PLAN-COFFRE-ANNONCES.md", lignes: "154-171" } },
  { id: "m-passer-workout-id-a", titre: "Passer `workout_id` à `forge-card` (colonne toujours nulle)", page: "forge", domaine: "forge", lecture: "inconnu", cout: "1 h", preuve: { fichier: "Woop/Services/ForgeServeur.swift", lignes: "36" } },
  { id: "m-cache-disque-des-png", titre: "Cache disque des PNG de cartes ; `depth_path` null partout", page: "forge", domaine: "forge", lecture: "inconnu", cout: "1 j", preuve: { fichier: "tools/sacre/SUPABASE-A-FAIRE.md", lignes: "56-60" } },
  { id: "m-fermer-la-sortie-par", titre: "Vérifier à l'écran que le chevron meurt à l'engagement", page: "forge", domaine: "forge", lecture: "inconnu", cout: "1 h", preuve: { aCiter: true } },
  { id: "m-rattrapage-hors-ligne-du", titre: "Rattrapage hors-ligne du booster — l'outbox ignore la forge", page: "forge", domaine: "forge", lecture: "inconnu", cout: "1 j", preuve: { fichier: "Woop/Services/OutboxGains.swift", lignes: "42-51" } },
  { id: "m-retirer-le-repli-jwtbanc", titre: "Retirer le repli `jwtBanc()` du chemin de production", page: "porte", domaine: "compte", lecture: "inconnu", cout: "1 h", preuve: { fichier: "Woop/Services/ForgeServeur.swift", lignes: "90-100" } },
  { id: "m-sortir-le-token-perso", titre: "Sortir le token perso du compte pro (`.secrets`)", page: "porte", domaine: "compte", lecture: "inconnu", cout: "1 h", preuve: { fichier: "tools/sacre/SUPABASE-A-FAIRE.md", lignes: "7-12" } },
  // 15-09 (suite) : « DecideurSerie → décideur à budget » (b-rg-rythme 🟢), « fermer forge-card sans booster_id »
  // (b-fo-serrure 🟢) et « valider le JWT dans weekly-synthesis » (bilan-periode vérifie le JWT) sont FAITES.
  // 15-09 : « policies d'écriture wallet / boosters », « vérifier les 4 migrations » et « réparer
  // schema_migrations » sont MESURÉES — devenues b-rls-argent-ferme et b-migrations-posees (serveur.ts).
]
