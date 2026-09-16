# Les deux Homes parlent — plan FR / EN

**16-09 : plan demandé, puis implémentation explicitement autorisée par
l’utilisateur (« tu peux coder »). Réalisation et limites : [bilan du 16-09](BILAN-TEXTES-HOMES-2026-09-16.md). Le plan ci-dessous conserve les intentions initiales.** Les textes de la Home rouge, du pull
de départ et de la Home noire doivent sembler être prononcés, comme ceux de
l'onboarding et des histoires. La langue suit le choix de l'onboarding.

## 1. Ce qui existe, et ce qui manque

Lecture du dépôt le 16-09, complétée par les preuves déjà publiées dans le site.
Pas de nouvelle vérification du serveur de production effectuée pour ce plan.

| Surface | État lu | Travail prévu |
|---|---|---|
| Home rouge | `home().phrases` fournit déjà les états `vide`, `active_zero`, `active`, `seance_debut`, `seance` en FR/EN. La phrase visible garde les chiffres cohérents avec les widgets. Certains replis locaux restent anglais. | Ajouter des variantes, compléter les replis FR/EN et animer la phrase comme une prise de parole. |
| Pull et slider | `DepartMots` contient 27 amorces et 17 boutons locaux, en anglais, avec quelques prénoms « Kathryn » en dur. Le bloc ajoute `slide to start / your session.`. Tirage sans remise, sans appel IA dans ce chemin. | Fournir des variantes IA FR/EN depuis le backend, localiser le bloc entier et le bouton, utiliser le vrai prénom. |
| Home noire en séance | `FoyerPage.phraseArrivee` appelle directement le repli `PhraseTexte.fragmentsSeance(minutes:)`. Le temps vient de la séance ; le texte possède un balayage continu. | Brancher le même contrat serveur que la Home rouge, parler à l'entrée puis lors d'une évolution pertinente, laisser le texte au repos entre deux prises de parole. |
| Référence visuelle | `MotsFlou` dans l'onboarding fait apparaître les mots avec fondu, léger déplacement, flou bref et pauses selon la ponctuation. | Reprendre cette grammaire visuelle et la montrer sur les vraies dimensions des Homes. |

Repères : `DepartCine.swift:526-616`, `HomeNuit.swift:329-438,3218-3222`,
`Foyer.swift:685-693`, `NosfyOnboarding.swift:1485-1598`,
`ProfilServeur.swift:134-180`. Les notes `b-fn-home`, `b-ux-home-phrase` et
`b-po-langue-serveur` décrivent les fondations déjà présentes.

## 2. Comportement à obtenir

### Home rouge

- À l'arrivée, la phrase se révèle par mots ou petits groupes, avec un débit
  naturel, les pauses de ponctuation et l'alternance clair/sourd existante.
- Le texte reste posé après sa dernière syllabe visuelle. Il ne se rejoue pas
  à chaque recalcul de vue, retour d'un popup ou réponse réseau identique.
- Une évolution réelle de l'état (première séance, nouveau total, début/fin de
  séance) autorise une nouvelle phrase. Les chiffres restent ceux des widgets.

### Pull et slider

- À chaque **nouvelle ouverture effective**, choisir une variante différente
  dans le lot de la langue courante, avec son bouton compatible.
- Garder ce choix pendant le geste, son interruption et sa reprise : ni nouveau
  tirage au milieu du mouvement, ni texte qui saute pendant le retour.
- Localiser ensemble l'amorce, l'instruction, le complément, le bouton et
  l'invitation au pull. Le prénom vient du profil ; aucune identité en dur.
- Préserver le tirage sans répétition immédiate et l'épuisement du sac existant.
  La cohérence phrase/bouton prime sur deux tirages indépendants.

### Home noire pendant une séance longue

- À l'entrée : une courte prise de parole adaptée au début de séance, ou au
  temps déjà écoulé si l'app est rouverte au milieu d'une séance.
- Le chrono continue normalement. Quand le nombre de minutes affiché change,
  animer doucement le nombre ou le groupe concerné, sans rejouer toute la tirade.
- Proposer une nouvelle formulation à quelques paliers espacés. Point de départ
  à valider visuellement : début, 5, 15, 30, 45, 60 min, puis toutes les 15 min.
  Ces paliers changent les mots, jamais le décompte réel de la séance.
- Au retour après une absence, montrer directement la phrase du palier actuel ;
  ne pas rejouer en rafale tous les paliers manqués.

## 3. Le backend à prévoir

### Réutiliser les fondations

Conserver `profils.langue`, écrite à l'onboarding, et `home()` comme porte de
lecture. Étendre la réponse de façon additive pour servir des lots de variantes,
en conservant `phrase` et `phrases` pour les versions existantes de l'app.
La langue confirmée par le profil fait référence ; pendant l'onboarding, le choix
local fournit immédiatement la bonne langue. Sans choix connu : langue de l’appareil côté app, français par défaut au serveur.

Contrat proposé pour chaque variante : identifiant stable, langue, état ou
surface, fragments ordonnés avec leur intention clair/sourd, jetons de données
autorisés, et libellé du slider pour le départ. Le lot porte une révision.
Les noms exacts du champ additionnel et du stockage seront fixés lors de
l'implémentation ; aucun nouveau service général de conversation n'est nécessaire.

### Générer des lots, servir immédiatement

L'IA prépare au serveur des variantes dans **chaque langue**, avec une rédaction
française naturelle. Précision utilisateur du 16-09 : conserver quelques anglicismes
ponctuels (flow, reset, Let’s go), sans basculer le texte entier en anglais. Le modèle suit le choix déjà configuré côté projet ; sa clé
reste au serveur. Le premier lot visé contient au moins autant de diversité que
les 27 amorces de départ actuelles, dans chaque langue.

Les lots sont générés et validés à l'avance, puis lus depuis un stockage/cache.
Un pull, une seconde de chrono ou un retour de page ne déclenche pas un appel au
modèle. L'app dispose du lot avant le geste et d'un repli FR/EN immédiat si le
réseau, le modèle ou le lot ne sont pas disponibles.

Validation avant publication : langue, doublons, ton, structure, cohérence
phrase/bouton, jetons autorisés et contraintes de longueur. Les limites visuelles
sont confirmées dans l'app avec Inter et le vrai prénom, pas avec un simple
compteur de caractères. Une version de lot peut être retirée sans bloquer l'écran.

### Garder les faits exacts

L'IA fournit la formulation autour de jetons tels que prénom, nombre de séances
ou minutes. Elle ne calcule pas les performances et n'invente pas les chiffres.
Les données viennent du profil et des mêmes sources que les widgets/la séance.
Le temps écoulé continue à se calculer localement depuis le début de séance,
y compris hors ligne ; aucune requête serveur par minute.

Le cache et le tirage sont associés à la langue et à la révision du lot. Les
valeurs personnalisées restent rattachées au compte courant. Un changement de
langue ou de compte ne peut afficher une ancienne phrase dans l'autre langue.

## 4. Animation et budget de rendu

Adapter le phrasé de `MotsFlou` : apparition douce par mots, déplacement court,
contraste clair/sourd, pause après une virgule ou une phrase. Garder les cotes
actuelles : quatre fragments pour les phrases Home, trois pour le départ, et
le raccord du pull ancré par le bas. Valider FR et EN ensemble, y compris noms
longs et nombres à plusieurs chiffres.

Le calendrier des mots se calcule une fois par nouvelle réplique. L'animation
est finie ; les tâches sont annulées quand l'écran disparaît. Aucun ajout
d'horloge de rendu continue, de requête IA répétée ni de flou animé permanent.
Le balayage continu du texte de la Home noire devient une prise de parole
ponctuelle. La traduction et le chrono ne doivent pas reconstruire toute la Home.

Prévoir Reduce Motion et VoiceOver : texte accessible complet et stable, sans
annonce de chaque mot ni de chaque seconde. Au repos après la phrase, vérifier
le coût sur iPhone avec les animations normales ; une protection thermique
déclenchée ne suffit pas à valider ce budget.

## 5. Ordre de réalisation après validation du plan

1. **Contrat éditorial FR/EN** : montrer quelques variantes des trois surfaces,
   dans leurs cotes réelles, avec les cas 0/1/plusieurs et un prénom long.
2. **Backend** : lots IA bilingues validés, stockage/version, lecture par
   `home()`, replis et compatibilité avec le contrat actuel.
3. **Langue et branchements iOS** : cache par langue/version, départ complet
   bilingue, vrai prénom, Home noire raccordée aux mêmes phrases serveur.
4. **Animation commune** : une réplique finie à l'arrivée, choix stable pendant
   le pull, mise à jour discrète des minutes et paroles aux paliers retenus.
5. **QA réelle** : onboarding FR puis EN, rouge/pull/noire, retour d'arrière-plan,
   perte réseau, changement de compte/langue, gestes interrompus et longue séance.

## 6. Conditions de validation

- Langue de l’onboarding respectée, y compris hors ligne, dans le slider et sur
  la Home noire. En français, quelques anglicismes intentionnels sont autorisés
  à la demande de l’utilisateur ; pas de phrase entière issue du mauvais lot.
- Prénom réel, données exactes, pluriels corrects ; aucun « Kathryn » de maquette.
- Diversité visible au pull, aucun changement de mots au milieu d'un geste.
- Sensation de parole naturelle montrée sur téléphone, texte stable après lecture.
- Chrono juste après 30–60 min et retour d'arrière-plan ; aucun rattrapage de paroles.
- Coût stable une fois les mots apparus ; test d'endurance avec les protections
  non déclenchées pour valider le rendu normal, navigation toujours accessible.

**État : développé et déployé après autorisation.** Le site backend décrit le
lot 03 et la version 37, avec la QA appareil encore ouverte. Les preuves et les
échecs sont dans le [bilan de réalisation](BILAN-TEXTES-HOMES-2026-09-16.md).
