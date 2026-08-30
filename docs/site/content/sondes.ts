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
  { id: 'noeuds', requete: 'POST /rest/v1/rpc/noeuds_chemin_reclames', reponse: '404 PGRST202 avant le push · 200 [] après', prouve: 'la fonction est déployée ; le tour complet sur un compte connecté n\'a pas été vu → 🔵, pas 🟢' },
  { id: 'facts', requete: 'GET /rest/v1/workout_facts', reponse: '404 → 200 (30-08)', prouve: 'la table existe, ses trois index aussi ; le rejeu rend 23505 sur workout_facts_unique' },
]
