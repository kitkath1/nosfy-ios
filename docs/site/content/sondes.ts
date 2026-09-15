import type { Sonde } from './types'

/**
 * LES SONDES HTTP — les seules preuves DURES du site : un appel réel, sa réponse lue,
 * et un TÉMOIN qui doit échouer (sans lui, quatre 200 d'affilée ne prouvent rien).
 * Reprises de la v1 (29-08 et 30-08). Une sonde ne se copie pas d'un plan : elle se lance.
 */
export const SONDES: Sonde[] = [
  { id: 'workouts-created', requete: 'GET /rest/v1/workouts?select=created_at&limit=1', reponse: '200', prouve: 'la colonne existe — c\'est 20260729120000_woop_schema.sql qui fait foi' },
  { id: 'workouts-updated', requete: 'GET /rest/v1/workouts?select=updated_at&limit=1', reponse: '400', prouve: 'n\'existe pas — 0001_init.sql n\'est pas la vérité' },
  { id: 'logged-rest', requete: 'GET /rest/v1/logged_exercises?select=rest_seconds&limit=1', reponse: '400', prouve: 'n\'existe pas' },
  { id: 'temoin-colonne', requete: 'GET /rest/v1/workouts?select=colonne_qui_nexiste_pas', reponse: '400', prouve: 'le TÉMOIN — il échoue, donc la méthode est bonne' },
  { id: 'calendrier', requete: 'GET /rest/v1/workouts?select=id,started_at,ended_at · logged_exercises · strength_sets · cardio_phases', reponse: '200', prouve: 'de quoi reconstruire un calendrier ENTIER — et SupabaseSync n\'a qu\'un push' },
  { id: 'sticker', requete: 'GET /rest/v1/workouts?select=sticker', reponse: '400', prouve: 'aucune colonne sticker : dans l\'app il est choisi par un modulo, aucune séance ne le décide' },
  { id: 'noeuds', requete: 'POST /rest/v1/rpc/noeuds_chemin_reclames', reponse: '404 PGRST202 avant le push · 200 [] après', prouve: 'la fonction est déployée ; le tour complet est VU le 15-09 (app réinstallée → « 3 nœud(s) déjà payés, appris du serveur ») → 🟢' },
  { id: 'facts', requete: 'GET /rest/v1/workout_facts', reponse: '404 → 200 (30-08)', prouve: 'la table existe, ses trois index aussi ; le rejeu rend 23505 sur workout_facts_unique' },
  // 15-09 — tools/serveur/verif_portes.py (TOUT EST VERT, 31 preuves), compte de test
  { id: 'argent-ferme', requete: 'POST /rest/v1/coin_ledger {delta 1000000} · PATCH · DELETE (Prefer: return=representation)', reponse: '403 42501 · 200 [] · 200 []', prouve: 'aucune policy d\'écriture : l\'argent n\'entre que par les fonctions — et le 204 d\'un PATCH refusé ne prouve rien, le [] si (solde relu 43 → 43)' },
  { id: 'rare-cachees', requete: 'GET /rest/v1/reward_rules?key=like.rare_*', reponse: '200 [30, 45, 10] avant 20260915090000 · 200 [] après', prouve: 'les dés du serveur ne se lisent plus ; chemin_* → 5, 40 clés visibles = regles_annonces(), etat_coffre() rend prix_booster 100 (le definer lit)' },
  { id: 'solde-noir-retiree', requete: 'POST /rest/v1/rpc/solde_noir', reponse: '404 PGRST202', prouve: 'retirée le 28-08 (wallet_coffre.sql:94) — témoins : fonction_inventee_temoin → 404, solde_argent → 200' },
  { id: 'syntheses-absente', requete: 'GET /rest/v1/syntheses?select=id&limit=1', reponse: '404 PGRST205', prouve: 'la table n\'est pas au serveur : 0001_init.sql:77 la déclare, 0001 n\'est pas la vérité — témoin booster_progress → 200 []' },
  { id: 'migrations-35', requete: 'supabase migration list --linked (jeton .secrets, pas ~/.zshenv)', reponse: '35 local = 35 remote', prouve: 'rien en attente, rien d\'orphelin — schema_migrations est sain' },
  // 15-09, étapes 2 → 5 — tools/serveur/verif_{forge,collection,faits}.py, TOUT EST VERT
  { id: 'forge-serrure', requete: 'POST /functions/v1/forge-card {} (un compte jetable)', reponse: '400 sachet requis', prouve: 'pas de sachet, pas de carte — le compte d\'atelier seul peint le pool sans sachet' },
  { id: 'ma-collection', requete: 'POST /rest/v1/rpc/ma_collection', reponse: '200 · 7 familles · Σ 28 = count(*) user_cards', prouve: 'le mur du profil lit le serveur : réinstallée, l\'app retrouve 4 / 4 et 2 / 11' },
  { id: 'faits-cloture', requete: 'POST /rest/v1/rpc/cloturer_seance (8 séries après une de 6)', reponse: '200 faits [top_muscu volume_kg 480 > 300]', prouve: 'le record se calcule au serveur ; rejeu → le stocké ; 2e du jour → double_jour' },
  { id: 'bilan-periode', requete: 'POST /functions/v1/bilan-periode {periode: mois}', reponse: '200 phrase … (3,6 s) · rejoué : cache true (1,5 s)', prouve: 'la phrase du bilan naît au serveur, dans la langue du profil, sur les chiffres des widget_*' },
]
