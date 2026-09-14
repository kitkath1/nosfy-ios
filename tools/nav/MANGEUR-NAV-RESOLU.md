# LE VOLEUR DU PREMIER TAP DE NAV — NOMMÉ : LA TABBAR NATIVE (13-09)

> **Enquête close, preuve au dump.** Le « 2ᵉ mangeur » ouvert depuis le 07-09
> (cas 02/08 du banc pilule : le premier tap de nav sur la home en séance ne
> navigue jamais) est identifié. Dossier pour la session nav/pilule — le remède
> est chez elle (banc + éventuellement l'app).

---

## §1 · LA PREUVE

`app.debugDescription` imprimé **juste avant le tap** de `test02` (l'école : le
hit-test d'accessibilité se LIT, il ne se devine pas). Au point visé
(196,5 · 813), DEUX navigations coexistent dans l'arbre d'accessibilité :

```
TabBar {{0, 769}, {393, 83}}  label: 'Barre d'onglets'          ← LA NATIVE
  Button {{150, 773}, {94, 54}}  'Exercices'                     ← 94 × 54, hit-testable
Other  {{98.7, 791}, {196, 44}}                                  ← LA NAVBANDE CUSTOM
  Image {{174.7, 791}, {44, 44}}  'Entraînements'                ← la vraie cible, 44 × 44
```

**La TabBar native est dans l'arbre et hit-testable MALGRÉ
`.toolbarVisibility(.hidden, for: .tabBar)` posé sur chaque page.**

## §2 · LE MÉCANISME

Au lancement en séance, le `Button` natif pas encore neutralisé **absorbe le
premier tap par coordonnée sans naviguer** ; la fenêtre se referme en ~1-2 s.

**La contre-épreuve** : en ajoutant ~2 s (l'impression du dump) avant le tap,
`test02` PASSE (12,7 s, vert — 13-09). C'est ce qui explique l'intermittence
qui a promené trois sessions : 2 pass / 7 fail le 07-09 dans des conditions
quasi identiques ; le 08 vert ici et rouge là le 13-09.

## §3 · RÉFUTÉS EN ROUTE — ne pas recreuser

| hypothèse | réfutée par |
|---|---|
| le splash couvre le tap | conteneur CHAUD (porte vue) → test02 échoue quand même |
| la NavBande démontée pendant l'arrivée | `navCachee=0` dans toutes les sondes d'échec (le compteur existait) |
| les gestes du Foyer | 07-09 : Foyer entièrement démonté → échec quand même |
| PanBande / delaysTouchesBegan | plus besoin d'y aller : le dump montre le voleur au-dessus |
| le poids/les couches du Foyer | fond, chambre, flammes éteints un à un → échec quand même |

## §4 · REMÈDES CANDIDATS (session nav)

1. **Banc** : avant le PREMIER tap de chaque cas, attendre que la TabBar native
   ne soit plus hit-testable — ou taper l'ÉLÉMENT custom (par identifier) au
   lieu d'une coordonnée.
2. **App, à évaluer** : pourquoi la TabBar native reste-t-elle dans l'arbre
   d'accessibilité malgré le `.hidden` ? Si elle absorbe de vrais doigts dans
   les 2 premières secondes, c'est un défaut utilisateur, pas seulement de banc.

## §5 · LES DEUX LEÇONS D'INSTRUMENT

- **`app.debugDescription` avant le geste** : une ligne, et le voleur sort
  nommé avec son frame — après deux jours de bissections à l'aveugle.
- ⚠️ `centreGlyphe(1)` = midX + 0 : **Exercices est le glyphe du MILIEU**
  (home 0 · exercices 1 · profil 2). Le « midX+76 » cité dans les échanges
  vise PROFIL.

*(Historique complet : mémoire `woop-piege-runner-xcuitest-cache` — le runner
en cache, le faux mur, les gestes haute priorité du Foyer.)*
