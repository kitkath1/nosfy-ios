# Le repaire de Nosfy — les propositions (25 → 30-09-2026)

**Rien n'est codé.** Ce dossier garde les pages montrées à Kathryn et leurs liens,
pour les retrouver sans chercher.

## Les liens

| Page | Lien | Ce qu'elle montre |
|---|---|---|
| **Le repaire de Nosfy** (la version en cours) | <https://claude.ai/artifact/2Tk3vehwD3THi9Pxzj4KSj> | Le repaire en 5 écrans (gagner un repas, le nourrir, il grandit, il dort), la démo au doigt, les vidéos à générer avec leurs prompts |
| **Plus de Nosfy** (la première proposition) | <https://claude.ai/artifact/DrNaPDkKEj3XCeVY92nyJk> | La course du repos (maquette jouable, façon jeu du dinosaure) et la première idée du repaire |

Chaque lien garde l'historique de ses versions. Les deux pages sont aussi dans ce
dossier, telles que publiées : `repaire-nosfy.html` et `plus-de-nosfy.html`. Elles
s'ouvrent seules dans un navigateur, sans connexion.

## Le chemin des versions du repaire

1. 22 idées numérotées (lanterne, vraie lune, mur de stickers…) : « pas clair, j'aime pas du tout ».
2. Prendre soin et voir la progression, la démo au doigt, la liste des vidéos avec leurs prompts.
3. Des prompts plus courts, avec « caméra fixe, pas de zoom, Nosfy au centre ».
4. La progression expliquée : un repas par jour d'entraînement, et ce qu'on lui donne.
5. Une vraie barre de progression (7 cases) et des objectifs toujours visibles.
6. **Écran par écran** (la version en ligne) : « pas fan, on comprend pas trop » sur la 5.
   Son avis sur la 6 n'a pas encore été donné.

## La règle retenue jusqu'ici

- 1 jour d'entraînement = 1 repas, comme un galet. La 2ᵉ séance du jour donne une friandise.
- 7 repas = il grandit. 5 stades = les 5 chapitres de la Route. Au 35ᵉ jour, l'envol.
- Sans repas depuis 3 jours, il s'assoupit ; après 5 jours, il dort pendu. Il ne meurt
  jamais et ne perd jamais un stade.
- Ce qu'on lui donne : le repas, la friandise, des objets achetés en pièces, et ses
  stickers qui se posent seuls sur son mur.

## Les prompts (à coller dans Higgsfield)

Toutes les vidéos partent de la même image de départ (I1, ou I2 pour le sommeil).
Réglages : vidéos en 1080p à 30 images par seconde, images de référence en 4K.

| | Prompt | Départ → fin | Joué comment |
|---|---|---|---|
| I1 | `Nosfy, a small black bat with huge ears and big round eyes. Facing the camera, centered, full body. Pure black background.` | image | Existe déjà : le Nosfy de l'accueil |
| I2 | `Same Nosfy, hanging upside down, wings wrapped, eyes closed. Centered. Pure black background.` | image | Existe presque : la vidéo du profil |
| V1 | `Fixed camera, no zoom. Nosfy stays in the center. He slowly turns his head to his right. Black background. 3 seconds.` (puis « to his left ») | I1 → libre | Au doigt : il te suit du regard |
| V2 | `Fixed camera, no zoom. Nosfy stays in the center. He breathes and blinks once. Black background. 6 seconds.` | I1 → I1 | En boucle |
| V3 | `Fixed camera, no zoom. Nosfy stays in the center. He slowly closes his eyes, happy, ears back. Black background. 3 seconds.` | I1 → libre | Au doigt : la caresse |
| V4 | `Fixed camera, no zoom. Nosfy stays in the center. He slowly opens both wings. Black background. 3 seconds.` | I1 → libre | Au doigt : les ailes |
| V5 | `Fixed camera, no zoom. Nosfy stays in the center. He catches a small glowing ember and eats it. Black background. 4 seconds.` | I1 → I1 | Une fois : le repas |
| V6 | `Fixed camera, no zoom. Nosfy stays in the center, hanging upside down, asleep, breathing slowly. Black background. 6 seconds.` | I2 → I2 | En boucle : il dort |
| V7 | `Fixed camera, no zoom. Nosfy stays in the center. He wakes up, drops down and lands facing the camera. Black background. 4 seconds.` | I2 → I1 | Une fois : le réveil |
| V8 | `The camera circles slowly around Nosfy, same distance, no zoom. Nosfy stays in the center, still. Black background. 8 seconds.` | I1 → I1 | Au doigt : il pivote (option) |

« Au doigt » : on ne lit pas la vidéo, le doigt choisit l'image affichée. La démo de la
page le montre avec la vidéo de l'aile qui est déjà dans l'app.
