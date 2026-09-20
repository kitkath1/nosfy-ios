-- 20260920170000 — LE PLAFOND DE DEUX SÉANCES PAR JOUR S'APPLIQUE DÈS LE 20-09.
--
-- Verdict de Kathryn, 20-09 11:20, après avoir vu « ×4 » sur sa Route (build de
-- l'arbre) : « oui c'est ça : max [deux séances par jour] et sticker, basta »,
-- « ×4 dans la Route : non, impossible ». La migration 20260920160000 avait posé
-- chemin_plafond_depuis au 21-09 pour ne pas lui retirer les quatre séances du
-- matin ; les deux comptes Apple ont été remis à zéro à 11:53 sur son ordre
-- (qa-24, session Compte) : plus rien à préserver. Mesuré avant (compte jetable,
-- 20-09 10:52) : avec la date au 21-09, une troisième séance du jour est PAYÉE
-- (20 pièces + sachet), COMPTÉE (rang 3) et débloque le galet 3 — c'est le ×4.
-- Analyse : tools/production/ANALYSE-WELCOME-BACK-CLAIM-PLAFOND-2026-09-20.md § 3.
--
-- Une ligne de règle, rien d'autre : seances_chemin_plafonnees(), la clôture et
-- la garde des lunes relisent reward_rules à chaque appel (20260920160000:122).
-- Le téléphone porte la même date (Nosfy/Services/PlafondJour.swift, `depuis`),
-- changée dans le même geste. Rien de rétroactif : une séance finie le 19-09
-- ou avant garde son galet (la règle compare le jour local de la FIN).
--
-- Défaire : update public.reward_rules set value = '"2026-09-21"'::jsonb
--           where key = 'chemin_plafond_depuis';

update public.reward_rules
   set value = '"2026-09-20"'::jsonb
 where key = 'chemin_plafond_depuis';
