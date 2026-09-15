# Build30 — invitation native, navigation vérifiée ; chauffe encore ouverte

**Concession visuelle confirmée par l’utilisateur sur30 : le widget Chapitre a perdu ses animations.** Le fond liquide (`FondLiquide`) et le liseré tournant (`LisereTournant`) ne sont plus montés quand `decorHomeAuRepos` est vrai ; les halos/ondes d’appel sont retirés et la respiration du halo interne du galet est figée. Ce changement est permanent sur la Home actuelle, même à froid ; ce n’est pas seulement la protection thermique. Il contribue potentiellement au gain global28, sans attribution isolée de chacun de ces effets. Le rendu complet demandé reste donc à restaurer avec un coût maîtrisé. Les deux chevrons natifs30 sont un autre composant, pas une remise en animation du Chapitre.

15 septembre 2026. Installé à21:51:44, Release30, UUID **8CFBC1D4-0B4B-3725-AD2A-C74F1000E4B8**.
Retour utilisateur final sur30 vers21:58 : **« je trouve que ça chauffe beaucoup moins »**. Amélioration ressentie confirmée. Le branchement pendant ce retour n’est pas précisé ; la tenue prolongée reste à confirmer.

## Décision et preuve visuelle

Les deux chevrons de « pull to start » passent de la boucle SwiftUI à un CAShapeLayer natif : opacité0,34→0,80 et translation verticale0→−2pt, période2,6s, décalage0,18s et courbes conservés. Aucun état SwiftUI écrit pendant cette animation. La vue native ignore les touches ; les gestes restent chez l’hôte. Reduce Motion, scène inactive, Home cachée et protection thermique arrêtent l’animation. Le témoin précédent reste sous `-chevronsSwiftUI`.

Les huit captures XCTest de `woop-captures-invite30-animee` montrent le mouvement et le changement d’intensité des chevrons ainsi que les flammes. Planche relue à l’œil : `planche-invitation.png`. La simple différence de pixels n’est pas une mesure isolée des chevrons (le fond vidéo change aussi). Aucun appui sur l’invitation. Diagnostic animé ouvert21:54:31, retour normal confirmé21:54:42 ; pas de protection laissée désactivée.

## Mesures (sonde, pas watts ni cadence GPU)

Fenêtre standard **15 < t ≤35s** (20 échantillons). Le résumé oral précédent retenait16≤t≤35 (19 échantillons, médiane4 % sur29) ; le calcul ci-dessous utilise le seuil écrit dans le skill de façon identique pour les trois essais.

| Version / condition | CPU médian (min–max) | Callbacks/s | Pire intervalle | Thermique / protection |
|---|---:|---:|---:|---|
|29, invitation SwiftUI complète|3 % (1–12)|60,1|17ms|0 /0|
|29, invitation retirée `-sansInvite`|1 % (0–1)|60,1|17ms|0 /0|
|30, invitation native, premier relevé|1 % (0–1)|60,1|17ms|**1 /1**|

Les29 isolent le coût de l’invitation sur le même binaire ; la mesure30 n’établit **pas** son gain animé, car la protection avait déjà posé le fond et les chevrons. Ne pas annoncer «3→1 % grâce au natif» à partir de cette table. Les trois fenêtres ont Home, aucune séance/player, aucun Welcome/première arrivée, aucun gel marqué. Les journaux et calculs bruts sont conservés.

Le retour normal de21:54:42 commence à thermique0, monte le fond précomposé puis passe à1 (démontage du lecteur enregistré). Cela interdit de clore la chauffe sur ces seules preuves. Demande envoyée à l’utilisateur de tester quelques minutes hors charge ; il confirme ensuite beaucoup moins de chauffe sans préciser s’il a débranché. Batterie lue à21:30 :93 %, charge active (preuve dans le dossier28). Ce contexte ne prouve pas que la charge cause le bug initial.

## Navigation et lecteurs

Home → Exercices → Home → Profil → Réglages PASS en **9,267s**, journal `validation30/navigation.log`. Aucun appui Se déconnecter/Supprimer mon compte, aucun cycle complet de compte.

Le29 ferme réellement les lecteurs vidéo Home/Exos au démontage : cadence demandée nulle avant annulations, prerolls annulés, notifications/KVO retirées, file vidée et références détachées. Les rappels ne relancent que le lecteur encore détenu. Voir `../lecteurs-fermes-build29/` pour les événements rate0/items0 ; ce n’est pas une preuve de la cause principale de chauffe.

## Pistes closes pour cette itération

Les Power Profiler28 attachés **par PID** fonctionnent : à froid, CPU4,962 % avec verre,4,897 % sans verre. Les scores de puissance anonymes ne montrent pas de gain clair ; pas de watts ni de métrique GPU par processus. Le verre normal est conservé. Ne pas refaire le banc complet d’ornements ni conclure sur une Home protégée.

## Livré et restant

Build30 installé ; sources locales non commitées. Sonde désactivée, protection normale, maintien éveillé30min à compter de21:54:42. Captures et navigation validées. **Restent le coût30 animé à froid et la tenue prolongée. L’utilisateur confirme une amélioration nette de la chaleur sur30 ; le branchement n’est pas précisé**. QA04 KO ; QA07 confirme seulement l’accès aux écrans. Aucun résultat de suppression/onboarding ajouté.

Documentation locale30 : `npm run artefact` réussi après correction effective de QA, puis `npm run verif` vert en15s. Livrable local régénéré ; publication externe Artifact non disponible. Aucun commit.

Après le retour sur le Chapitre : concession visuelle explicitée dans QA04 et E50 ; artefact régénéré, vérification finale verte en17s.
