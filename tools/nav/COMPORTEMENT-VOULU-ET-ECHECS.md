# LA NAV — le comportement voulu, et le journal de MES échecs (03-09)

Écrit à la demande de Kathryn, après ~10 h bloquées. Deux parties : ce que j'ai
compris qu'elle veut (à valider), et la liste franche de ce que j'ai raté, pour
qu'aucune session ne le repaie.

---

## PARTIE 1 — LE COMPORTEMENT VOULU (ma compréhension, à corriger par Kathryn)

### Les états
- **Les pages sont TOUJOURS relevées** : une bande noire existe en bas en
  permanence et porte la nav — séance ou pas.
- **Exceptions** : pendant un exercice EN COURS (du galet blanc à la fin du
  repos) la bande disparaît entièrement ; jamais sur coffre/profil non plus (à
  reconfirmer pour profil, qui est une destination de la nav).

### Hors séance
- **Par défaut : nav DÉPLOYÉE** — 4 icônes + la braise sous l'onglet courant.
- **Drag léger vers le bas** → la nav devient **mini** (4 points) ET **la card
  s'allonge** (elle gagne vraiment la hauteur, changement de layout commis au
  relâcher, pas sous le doigt).
- **Drag vers le haut** → la nav se **redéploie**.
- Ça doit être **fluide et naturel** — « comme de l'eau ».

### En séance
- **La dalle du player est AU-DESSUS**, la nav **EN DESSOUS**.
- **Drag haut/bas sur la nav** → passe **mini ⇄ grosse** SOUS le player (les
  allers-retours), sans déclencher l'overlay.
- **Tap (ou drag franc vers le haut) sur la DALLE** → ouvre le player (overlay).

### Ce qui NE doit JAMAIS arriver (les bugs qu'elle constate)
1. Le drag qui **ne fait rien**.
2. **Quitter l'app** (retour à l'écran d'accueil iPhone) au drag.
3. **La page « se barre »** (tout l'écran descend) au drag.
4. En séance, **impossible** de passer mini ⇄ nav (ça ouvre le player à la
   place, ou rien).
5. **Ça lag / ça chauffe.**

Sa phrase : « c'est pas si compliqué ». Elle a raison : le comportement est
simple. C'est mon IMPLÉMENTATION qui a échoué, pas la spec.

---

## PARTIE 2 — LE JOURNAL DE MES ÉCHECS (pour ne pas les repayer)

### É1 — Patchs empilés au lieu d'une architecture
J'ai traité les gestes par rustines successives (pan en background, puis tap
grabber, puis inset de prise, puis bouclier). Chaque rustine a interagi mal avec
la précédente. **Leçon : la gestuelle de la nav est UN système, à concevoir d'un
bloc, pas à patcher.**

### É2 — Le pan maître posé en `.background` : reçoit-il seulement le doigt ?
Le `UIPanGestureRecognizer` vit sur une UIView en `.background` de la bande,
DERRIÈRE le `contentShape` SwiftUI de la nav. Soupçon fort, jamais prouvé sur
device : **le drag est peut-être gobé par SwiftUI et n'atteint jamais le pan** →
« le drag ne marche pas ». À trancher par le hit-testing, pas par l'intuition.

### É3 — L'inset de prise (`.padding(.bottom, descente)`) a tué le drag
En voulant remonter la prise hors de la zone système, j'ai réduit la zone
active du pan au point de casser le drag mini⇄grosse. Reverté.

### É4 — Le bouclier système au mauvais niveau, puis suspect de GEL
`.defersSystemGestures`/`.persistentSystemOverlays` posés dans chaque page (ne
remontent pas au contrôleur racine → n'empêchent pas « quitter l'app »), puis
remontés à la racine — et le lot qui a suivi a **GELÉ l'app**. Tout ce lot est
reverté. Cause du gel à confirmer par le workflow (suspect : tempête de mise à
jour de préférence, ou l'inset, ou le grabber overlay).

### É5 — Reachability promise « réglée » alors qu'elle est un mur iOS
J'ai laissé croire que le bouclier réglait « la page se barre » (Reachability).
FAUX : aucune app ne peut désactiver Reachability. La seule parade est
géométrique (le doigt ne doit pas naître dans la strip du bord ~20 pt) ou le
TAP (immobile, jamais volé). À dire honnêtement, jamais survendre.

### É6 — Trop d'installs non testables au doigt
J'ai réinstallé des builds que je ne peux pas juger au simulateur (les gestes se
jugent au doigt). Chaque install non concluante a coûté du temps et de la
confiance. **Leçon : ne réinstaller qu'un plan VÉRIFIÉ, et dire ce que je ne
peux pas prouver.**

### É7 — La fluidité jamais alignée sur la recette payée du player
Le commit du repli est un `withAnimation(0.25)` à durée FIXE — il ne prolonge
pas la vitesse du doigt comme le player (fin de course = 3·distance/vitesse).
D'où le « pas fluide comme de l'eau ». Jamais corrigé.

### La règle que je me redonne
Concevoir le système entier, le faire attaquer par un adversaire, ne montrer
qu'un plan vérifié, dire la vérité dure (Reachability), et ne jamais repatcher à
l'aveugle.
