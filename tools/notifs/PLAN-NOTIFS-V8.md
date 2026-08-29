# NOTIFICATIONS V8 — le glitch de la pièce, le 4ᵉ variant, et la règle backend

Verdict de Kathryn du 29-08. Trois sujets, dont un bug dont la cause est
**mesurée**.

---

## §A — LE GLITCH DE LA PIÈCE : la cause, et pourquoi ce n'est pas un réglage

Ton verdict : *« la vidéo glitch un peu, fix »*.

### A1. Ce que la sonde dit

Card 1 seule, filmée puis dépouillée image par image sur la zone de la
pièce :

| | mesuré |
|---|---|
| images **identiques à la précédente** | **84 %** |
| changements réels | **9,6 pas par seconde** |
| ce que l'écran sert | 60 img/s |

**La pièce avance dix fois par seconde pendant que l'écran en sert
soixante.** Ce n'est pas un à-coup, c'est du **stop-motion** — et c'est
exactement ce que l'œil appelle « ça glitche ».

### A2. La cause n'est pas un bug, c'est l'arithmétique de la planche

`PieceSprite` choisit **une case parmi 72**. Le tour dure 9 s, que j'ai
choisis délibérément (« c'est une ambiance, pas un numéro »).
**72 ÷ 9 = 8 cases par seconde.** Une planche de sprites jouée LENTEMENT
est *toujours* stroboscopique — il n'y a pas d'images entre les cases.

⚠️ **C'est une loi générale à écrire** : sur `CoffreV2` la même planche ne
glitche pas parce qu'elle est **pilotée au doigt** et va vite ; le défaut
n'apparaît qu'en dessous de ~24 pas/s.

### A3. Trois remèdes, et celui que je prends

1. ✅ **LE FONDU ENTRE DEUX CASES** — on dessine la case `k` **et** la case
   `k+1`, croisées sur la partie fractionnaire du tour. Huit pas par seconde
   redeviennent un mouvement continu, **à n'importe quelle vitesse**. C'est
   le seul remède qui garde la lenteur que tu as validée.
   - ⚠️ Il entre en **paramètre additif** (`fondu: Bool = false`) : `CoffreV2`
     ne doit rien voir passer — sa planche est rapide et n'a pas le défaut.
   - Coût : deux `cropping(to:)` par image au lieu d'un. Le commentaire du
     dépôt est formel — *« `cropping(to:)` ne copie RIEN, c'est une fenêtre
     sur les mêmes octets »*. Donc quasi gratuit. **Mesuré quand même.**
2. Accélérer à ~3 s le tour (24 pas/s). Ça marche, mais la pièce redevient
   un numéro — ce que tu as justement écarté.
3. La figer. Honnête, mais on perd la vie.

### A4. Ce que ça n'affecte PAS

Le booster du variant 4 (§B) bouge par **lévitation** — une transformation
continue, pas une planche. Il n'a pas ce défaut et n'aura pas ce remède.

---

## §B — LE 4ᵉ VARIANT : « LE SACHET QUI ATTEND »

*« à la place de la pièce, tu mets un booster qui bouge »* — et le contexte
que tu donnes est ce qui décide de tout : *« à la fin d'une séance, si on a
un booster, qu'on clique sur "later" et qu'on ne l'ouvre pas, on verra
cette notification. »*

### B1. C'est le MÊME template, et c'est le sujet

On ne redessine rien. La card 1 (la jauge), objet remplacé :

```
+1  BOOSTER WAITING                    ╔═══╗
FROM YOUR LAST SESSION                 ║ ☾ ║ ← le sachet, qui lévite
                                       ╚═══╝
▬▬▬▬▬▬▬▬·:·▬▬▬░░░░░░░░░░
```

C'est la démonstration de ce que tu dis toi-même : **les variants sont un
template**. Le quatrième le prouve en ne coûtant qu'un objet et deux mots.

### B2. L'objet — il existe déjà, détouré

- **`sticker-booster`** (794×1278, alpha) : le sachet noir au liseré irisé,
  logo lune. Détouré, prêt.
- **`sticker-booster-holo`** (même taille) : le MASQUE de la frise irisée.

C'est la paire exacte de `StoryWin` : le sticker, plus un `AngularGradient`
**cyan → magenta → or → cyan** masqué par le holo, dont la teinte tourne.
Là-bas elle tourne à 24 °/s **à la prise** ; ici, sans doigt, elle tournera
lentement et seule.

⚠️⚠️ **SURTOUT PAS LE BOOSTER 3D DE `BoosterPack`.** Une scène SceneKit
décode ses textures **sans cache à chaque construction** (~36 Mo mesurés
ici) et **rend même quand elle est effacée par l'opacité** — il faut la
mettre en pause. Dans une notification qui naît et meurt en deux secondes,
c'est exclu.

### B3. « Qui bouge » — la lévitation glaciale

L'école `CalLab`, celle des stickers de la story : **±2 pt, horloges
premières entre elles, JAMAIS de `repeatForever`** — tout est fonction pure
de `t`. Une transformation continue : aucun stroboscope possible (§A4).

### B4. ⚠️ LA SEULE VRAIE QUESTION, ET ELLE TOUCHE AU CONTRAT

Les trois premières cards **n'interrompent rien** — c'est la raison d'être
héritée de `PillGain` : *« soixante pour cent des séries ne méritent pas une
pop-up, elles méritent qu'on dise merci et qu'on s'efface »*. Le doigt n'a
jamais rien à faire.

**Celle-ci est différente** : elle est un RAPPEL. Elle existe parce que tu
as dit « later ». Deux lectures, et elles ne donnent pas la même card :

- **(a) Elle est TAPABLE** et rouvre la pop-up booster. C'est utile — mais
  elle cesse d'être un toaster et devient un bouton flottant. ⚠️ Et un
  `Button` sous un geste d'ancêtre se fait annuler dès que le drag reconnaît
  (loi payée) : il faudrait `.contentShape` +
  `.highPriorityGesture(TapGesture())`.
- **(b) Elle est MUETTE**, comme les trois autres : elle rappelle que le
  sachet t'attend, et tu iras l'ouvrir où il vit.

**Je pars sur (a), tapable** — un rappel qu'on ne peut pas suivre est une
frustration, et c'est toi qui as décrit le flow. Mais je te le signale parce
que c'est la première fois qu'une de ces cards demande la main.

---

## §C — LA RÈGLE BACKEND (à noter, comme tu l'as demandé)

Ta phrase : *« les 3 variants c'est un template utilisé dans l'app quand on
termine un step, ou quand on a claim avec welcome back… elles vont
intervenir à chaque fois qu'on a gagné des coins : dans la partie session en
cours, une fois terminée, et pour les rewards. »*

### C1. Où ça s'écrit

Dans `tools/rewards/PLAN-REWARDS-BACKEND.md`, en **§4 undecies — LES
NOTIFICATIONS DE GAIN**, et le §1 (l'outbox) le porte déjà à moitié.

### C2. La règle, écrite

> **Toute annonce d'un gain de pièces passe par le template des
> notifications.** Il n'y a plus de « pill » ni de bandeau ad hoc : une seule
> famille de dalles, quatre robes, trois moments.

| Moment | Ce qui se passe | Robe |
|---|---|---|
| **Pendant la séance** | une série finie rapporte | la jauge |
| **À la clôture** | la séance est réglée | la jauge, ou « YOU WIN » les grands jours |
| **Aux rewards / au claim** | Welcome Back, un nœud du chemin, le coffre | La Châsse (Nosfy), ou le sachet si c'est un booster |

### C3. Ce que le backend doit garantir — et ce qu'il ne doit PAS faire

- ✅ **L'UI affiche le gain TOUT DE SUITE.** C'est déjà la loi du §1 du plan
  backend : *« l'UI a le droit d'afficher le gain tout de suite, le ledger
  rattrape »*. Une notification qui attendrait le réseau serait un toaster
  qui arrive après la série suivante.
- ✅ **Le montant vient de l'outbox locale**
  (`{session_uuid, serie_index, type, facts, montant, ts}`), et le règlement
  au `settle_session` est **idempotent** par
  `(user_id, session_uuid, serie_index, raison)` — rejouer un batch ne
  crédite jamais deux fois.
- ⚠️ **La jauge, elle, ne peut PAS être locale.** « Vault progress » est un
  SOLDE, et un solde est dérivé du ledger côté serveur. Tant que le coffre
  n'est pas branché, elle affiche une valeur de démonstration — **et il faut
  que ce soit écrit noir sur blanc**, sinon on livrera un jour une barre qui
  ment sur l'argent du joueur.
- ⚠️ **Le CHOIX de la robe est une décision serveur**, pas un tirage client.
  Il rejoint `DecideurSerie` (aujourd'hui délibérément bête et
  déterministe : *« une place, pas un moteur »*) et le §2 du plan backend.

---

## §D — LES JALONS

| # | Ce qui sort | Comment on le juge |
|---|---|---|
| **V8-1** | Le fondu entre deux cases de la planche | **la même sonde qu'aujourd'hui** : le taux d'images identiques doit tomber de 84 % à ~0, et la cadence rester à 60 |
| **V8-2** | Le 4ᵉ variant : sachet + frise holo + lévitation | capture + film |
| **V8-3** | Le tap (si on retient (a)) | au doigt — ⚠️ **je ne peux pas le prouver au simulateur**, ce sera un verdict téléphone |
| **V8-4** | Le §4 undecies dans le plan backend | relecture |
| **V8-5** | Ton verdict | — |

---

## §E — CE QUI RESTE OUVERT DEPUIS HIER

1. **Le plan aux pièces** (`nosfy_pièces_sol`) : sa boîte utile fait 0,85:1,
   la dalle 2,58:1 — **la mesure interdit de tenir la bête ET les pièces**
   dans 138 pt. Soit la card 3 devient plus haute, soit on garde la
   chauve-souris qui vole. Tu n'as pas tranché.
2. **La cadence sur TÉLÉPHONE.** Mesurée au simulateur (La Châsse seule :
   60,0 img/s, pire trou 17 ms), jamais sur l'appareil. Tout ce que je dis
   de la fluidité réelle reste une opinion.
3. **Rien n'est commité.** Quatre fichiers nouveaux, trois modifiés, plus
   `nosfy-notif-loop.mp4` qui devra être **`git add`é explicitement** (le
   groupe `Woop` est synchronisé, mais trois fichiers ont déjà manqué au
   dépôt).
