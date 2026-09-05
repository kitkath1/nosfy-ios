// TROISIÈME SÉRIE — LE COMPOSANT. Écrite à la main, micro-détail par
// micro-détail. Pas de fond : l'objet de musique lui-même, à la place
// exacte de la barre. Chaque période est non ronde ; tout boucle en
// alternate (aller-retour) ou en événement-puis-repos — rien ne se
// remplit, rien ne voyage dans un rail, rien ne se compte.
export default [

/* ═══════════════ 1. L'ÉQUALISEUR CALME ═══════════════
   Les barres « en lecture » d'Apple Music, élevées : ancrées au CENTRE
   (jamais au sol — le sol en ferait une jauge), cœur lumineux, reflet
   posé dessous comme sur un dock laqué. Elles dansent LENTEMENT, et
   l'une d'elles se repose parfois. */
{
  id: 'barres',
  nom: "L'Équaliseur calme",
  cout: 'léger',
  pitch: "Sept lames verticales ancrées au centre, cœur blanc brillant et pointes qui meurent, chacune sur sa propre horloge lente — et leur reflet respire dessous, comme posées sur du laqué. C'est le glyphe « en lecture » d'Apple Music, ralenti jusqu'au luxe : ça danse à peine, ça ne mesure rien.",
  swift: "Sept Capsule() dans un HStack, chaque hauteur = f(t) pure lue dans UN TimelineView(.animation) scoped au composant, paused sur enMouvement. scaleEffect seul (aucune taille animée), le reflet = le même HStack scaleEffect(y: -1) + opacité + blur léger. Zéro Canvas, zéro Metal — la moins chère des six.",
  compo: `<span class="eq">
    <span class="lueur"></span><span class="sol"></span>
    <i class="b b1"></i><i class="b b2"></i><i class="b b3"></i><i class="b b4"></i><i class="b b5"></i><i class="b b6"></i><i class="b b7"></i>
  </span>`,
  compoMini: `<span class="eqm">
    <i class="bm bm1"></i><i class="bm bm2"></i><i class="bm bm3"></i><i class="bm bm4"></i><i class="bm bm5"></i>
  </span>`,
  css: `
.p-barres .eq{ position:relative; display:flex; align-items:center; gap:4.5px; height:30px;
  animation:barres-ensemble 11.3s ease-in-out infinite alternate; }
/* un souffle de halo SERRÉ sur le composant (pas un fond : il meurt à 40 px) */
.p-barres .lueur{ position:absolute; left:50%; top:50%; width:92px; height:46px;
  margin:-23px 0 0 -46px; border-radius:50%;
  background:radial-gradient(50% 50% at 50% 50%,
    rgba(255,255,255,.075) 0%, rgba(213,202,255,.038) 48%, rgba(165,139,255,.014) 66%, transparent 80%);
  animation:barres-lueur 9.7s ease-in-out infinite alternate; will-change:opacity; }
@keyframes barres-lueur{ from{opacity:.5} to{opacity:1} }
/* le sol : la trace du laqué sous les reflets */
.p-barres .sol{ position:absolute; left:50%; top:calc(50% + 15px); width:64px; height:1px;
  margin-left:-32px;
  background:linear-gradient(90deg, transparent, rgba(255,255,255,.10) 30%, rgba(255,255,255,.10) 70%, transparent); }
.p-barres .b{
  display:block; width:2.8px; height:22px; border-radius:1.8px; position:relative;
  background:linear-gradient(180deg,
    rgba(178,155,255,.24) 0%, rgba(255,255,255,.50) 22%,
    rgba(255,255,255,.98) 50%,
    rgba(255,255,255,.50) 78%, rgba(178,155,255,.24) 100%);
  will-change:transform;
}
/* le reflet : accroché à la barre, il scale AVEC elle — une seule horloge */
.p-barres .b::after{
  content:""; position:absolute; top:calc(100% + 4px); left:0; right:0; height:56%;
  border-radius:inherit; filter:blur(.5px);
  background:linear-gradient(180deg, rgba(255,255,255,.20), rgba(255,255,255,0) 82%);
}
/* la barre du milieu est l'ancre optique : un souffle plus claire */
.p-barres .b4{ filter:brightness(1.14); }
/* sept horloges, toutes étrangères ; b2 se REPOSE au creux de sa course */
.p-barres .b1{ animation:barres-d1 5.3s cubic-bezier(.45,.05,.55,.95) -1.2s infinite alternate; }
.p-barres .b2{ animation:barres-d2 6.7s cubic-bezier(.45,.05,.55,.95) -3.1s infinite alternate; }
.p-barres .b3{ animation:barres-d3 4.9s cubic-bezier(.45,.05,.55,.95) -0.7s infinite alternate; }
.p-barres .b4{ animation:barres-d4 7.7s cubic-bezier(.45,.05,.55,.95) -5.3s infinite alternate; }
.p-barres .b5{ animation:barres-d5 5.9s cubic-bezier(.45,.05,.55,.95) -2.3s infinite alternate; }
.p-barres .b6{ animation:barres-d6 6.3s cubic-bezier(.45,.05,.55,.95) -4.1s infinite alternate; }
.p-barres .b7{ animation:barres-d7 5.1s cubic-bezier(.45,.05,.55,.95) -1.9s infinite alternate; }
@keyframes barres-d1{ 0%{transform:scaleY(.30)} 34%{transform:scaleY(.82)} 58%{transform:scaleY(.44)} 100%{transform:scaleY(.94)} }
@keyframes barres-d2{ 0%{transform:scaleY(.72)} 26%{transform:scaleY(.34)} 52%{transform:scaleY(.22)} 64%{transform:scaleY(.22)} 100%{transform:scaleY(.88)} }
@keyframes barres-d3{ 0%{transform:scaleY(.52)} 40%{transform:scaleY(.96)} 72%{transform:scaleY(.38)} 100%{transform:scaleY(.70)} }
@keyframes barres-d4{ 0%{transform:scaleY(.88)} 30%{transform:scaleY(.46)} 62%{transform:scaleY(1.0)} 100%{transform:scaleY(.34)} }
@keyframes barres-d5{ 0%{transform:scaleY(.38)} 36%{transform:scaleY(.90)} 70%{transform:scaleY(.52)} 100%{transform:scaleY(.26)} }
@keyframes barres-d6{ 0%{transform:scaleY(.64)} 24%{transform:scaleY(.30)} 58%{transform:scaleY(.86)} 100%{transform:scaleY(.48)} }
@keyframes barres-d7{ 0%{transform:scaleY(.26)} 44%{transform:scaleY(.72)} 76%{transform:scaleY(.40)} 100%{transform:scaleY(.90)} }
/* l'ensemble respire, imperceptiblement */
@keyframes barres-ensemble{ from{transform:scaleY(1)} to{transform:scaleY(1.05)} }

/* la dalle : l'équaliseur PRÉSENT — un vrai objet à côté du stop,
   plus seulement un glyphe */
.p-barres .eqm{ display:flex; align-items:center; gap:3.4px; height:24px; }
.p-barres .bm{
  display:block; width:2.6px; height:19px; border-radius:1.6px;
  background:linear-gradient(180deg,
    rgba(178,155,255,.22) 0%, rgba(255,255,255,.50) 24%,
    rgba(255,255,255,.96) 50%,
    rgba(255,255,255,.50) 76%, rgba(178,155,255,.22) 100%);
  will-change:transform;
}
.p-barres .bm3{ filter:brightness(1.12); }
.p-barres .bm1{ animation:barres-d3 4.9s cubic-bezier(.45,.05,.55,.95) -0.7s infinite alternate; }
.p-barres .bm2{ animation:barres-d1 5.3s cubic-bezier(.45,.05,.55,.95) -2.9s infinite alternate; }
.p-barres .bm3{ animation:barres-d5 5.9s cubic-bezier(.45,.05,.55,.95) -1.1s infinite alternate; }
.p-barres .bm4{ animation:barres-d2 6.7s cubic-bezier(.45,.05,.55,.95) -4.7s infinite alternate; }
.p-barres .bm5{ animation:barres-d6 6.3s cubic-bezier(.45,.05,.55,.95) -2.1s infinite alternate; }
.p-barres .gros{ transform:scale(3.1); }
`,
},

/* ═══════════════ 2. LE RUBAN ═══════════════
   La forme d'onde de la dictée, en ruban : une ligne maîtresse, son écho
   PERLÉ (des grains de lumière enfilés sur la même courbe), et un fil
   violet plus lent dessous. Les eaux glissent en sens contraires et
   REVIENNENT — jamais un défilement. */
{
  id: 'ruban',
  nom: 'Le Ruban',
  cout: 'moyen',
  pitch: "Une onde continue comme celle de la dictée, mais tissée : la ligne maîtresse brille, son écho est un collier de perles enfilées sur la même courbe, et un fil violet dérive dessous, plus lent. Les trois glissent en sens contraires puis reviennent sur leurs pas — c'est un ruban qu'on balance, pas une piste qu'on lit.",
  swift: "Trois Path sinusoïdaux pré-calculés dans UN petit Canvas 240×28 (Animatable sur la phase), ou trois Shape + offset — phase = f(t) d'un seul TimelineView scoped, paused sur enMouvement. Le perlé = strokeStyle(dash:). Coût réel : un Canvas compact, mesurer sa cadence au banc avant verdict.",
  compo: `<span class="rb">
    <svg class="w wv" viewBox="0 0 440 26" width="440" height="26" aria-hidden="true">
      <path class="pv" d="M0 13 C 14 24, 28 24, 42 13 S 70 2, 84 13 S 112 24, 126 13 S 154 2, 168 13 S 196 24, 210 13 S 238 2, 252 13 S 280 24, 294 13 S 322 2, 336 13 S 364 24, 378 13 S 406 2, 420 13 S 434 20, 440 16" fill="none"/>
    </svg>
    <svg class="w we" viewBox="0 0 440 26" width="440" height="26" aria-hidden="true">
      <path class="pe" d="M0 13 C 12 5, 26 5, 38 13 S 62 21, 76 13 S 100 5, 114 13 S 138 21, 152 13 S 176 5, 190 13 S 214 21, 228 13 S 252 5, 266 13 S 290 21, 304 13 S 328 5, 342 13 S 366 21, 380 13 S 404 5, 418 13 S 434 18, 440 14" fill="none"/>
    </svg>
    <svg class="w wm" viewBox="0 0 440 26" width="440" height="26" aria-hidden="true">
      <path class="pm" d="M0 13 C 14 4, 28 4, 42 13 S 70 22, 84 13 S 112 4, 126 13 S 154 22, 168 13 S 196 4, 210 13 S 238 22, 252 13 S 280 4, 294 13 S 322 22, 336 13 S 364 4, 378 13 S 406 22, 420 13 S 448 4, 440 13" fill="none"/>
      <path class="ph" d="M0 13 C 14 4, 28 4, 42 13 S 70 22, 84 13 S 112 4, 126 13 S 154 22, 168 13 S 196 4, 210 13 S 238 22, 252 13 S 280 4, 294 13 S 322 22, 336 13 S 364 4, 378 13 S 406 22, 420 13 S 448 4, 440 13" fill="none"/>
    </svg>
  </span>`,
  compoMini: `<span class="rbm">
    <svg viewBox="0 0 30 14" width="30" height="14" aria-hidden="true">
      <path class="pmm" d="M0 7 C 3 2.5, 6 2.5, 9 7 S 15 11.5, 18 7 S 24 2.5, 27 7 S 31 10, 30 8" fill="none"/>
    </svg>
  </span>`,
  css: `
.p-ruban .rb{ position:relative; width:220px; height:26px; display:block; overflow:hidden;
  -webkit-mask-image:linear-gradient(90deg, transparent 0%, #000 13%, #000 87%, transparent 100%);
  mask-image:linear-gradient(90deg, transparent 0%, #000 13%, #000 87%, transparent 100%); }
.p-ruban .w{ position:absolute; left:0; top:0; will-change:transform; }
/* la maîtresse : trait 1.6 + halo (le même path, flouté, dessous) */
.p-ruban .pm{ stroke:rgba(255,255,255,.88); stroke-width:1.6; stroke-linecap:round; }
.p-ruban .ph{ stroke:rgba(255,255,255,.30); stroke-width:3.4; stroke-linecap:round; filter:blur(2.2px); }
.p-ruban .wm{ animation:ruban-va 11.3s ease-in-out infinite alternate; }
/* l'écho PERLÉ : des grains enfilés sur la courbe, à contre-courant */
.p-ruban .pe{ stroke:rgba(255,255,255,.42); stroke-width:1.9; stroke-linecap:round;
  stroke-dasharray:.1 6.5; }
.p-ruban .we{ animation:ruban-vient 15.9s ease-in-out -6.2s infinite alternate; }
/* le fil violet, le plus lent, presque un souvenir */
.p-ruban .pv{ stroke:rgba(133,93,255,.34); stroke-width:1; stroke-linecap:round; }
.p-ruban .wv{ animation:ruban-va 19.7s ease-in-out -3.4s infinite alternate; }
@keyframes ruban-va{ from{transform:translate3d(0,0,0)} to{transform:translate3d(-196px,0,0)} }
@keyframes ruban-vient{ from{transform:translate3d(-196px,0,0)} to{transform:translate3d(0,0,0)} }

/* la dalle : une maille d'onde qui balance */
.p-ruban .rbm{ display:block; width:30px; height:14px; }
.p-ruban .pmm{ stroke:rgba(255,255,255,.72); stroke-width:1.3; stroke-linecap:round; fill:none;
  animation:ruban-mini 7.9s ease-in-out infinite alternate; transform-origin:50% 50%; }
@keyframes ruban-mini{ from{transform:translateX(0) scaleY(1)} to{transform:translateX(-6px) scaleY(.62)} }
.p-ruban .gros{ transform:scale(2.2); }
`,
},

/* ═══════════════ 3. LE VU-MÈTRE ═══════════════
   L'objet de studio : une aiguille qui balance sur DEUX pendules
   étrangers (elle ne refait jamais deux fois le même geste), un pivot
   bombé qui accroche la lumière, et la lampe d'or qui ne s'allume
   presque jamais. */
{
  id: 'vumetre',
  nom: 'Le Vu-mètre',
  cout: 'moyen',
  pitch: "Une aiguille de studio balance devant neuf graduations muettes — portée par deux pendules étrangers, elle ne refait jamais deux fois le même geste. Le pivot est une perle bombée qui tient la lumière, et tout en haut, la petite lampe d'or ne s'allume qu'une fois par seize secondes, comme un signal qui passe. Le studio, pas la salle de sport.",
  swift: "Un ZStack : graduations en Path statique, aiguille = Capsule().rotationEffect(a1(t)+a2(t)) — deux sinus étrangers lus dans UN TimelineView scoped, paused sur enMouvement. La lampe = opacité f(t) à créneau rare. Aucune taille animée, aucun Canvas plein écran ; le seul soin réel est le dégradé de l'aiguille.",
  compo: `<span class="vu">
    <svg class="grads" viewBox="0 0 64 34" width="64" height="34" aria-hidden="true">
      <line x1="12.9" y1="13.4" x2="9.5" y2="9.7" class="g"/>
      <line x1="17.3" y1="10.1" x2="14.7" y2="5.9" class="g"/>
      <line x1="22.3" y1="7.7" x2="20.5" y2="3.1" class="g"/>
      <line x1="27.5" y1="6.3" x2="26.6" y2="1.4" class="g"/>
      <line x1="32.0" y1="5.8" x2="32.0" y2="0.8" class="g gc"/>
      <line x1="36.5" y1="6.3" x2="37.4" y2="1.4" class="g"/>
      <line x1="41.7" y1="7.7" x2="43.5" y2="3.1" class="g"/>
      <line x1="46.7" y1="10.1" x2="49.3" y2="5.9" class="g"/>
      <line x1="51.1" y1="13.4" x2="54.5" y2="9.7" class="g gd"/>
    </svg>
    <span class="bras"><span class="aig"></span></span>
    <span class="pivot"></span>
    <span class="lampe"></span>
    <span class="socle"></span>
  </span>`,
  compoMini: `<span class="vum">
    <span class="brasm"><span class="aigm"></span></span>
    <span class="pivotm"></span>
  </span>`,
  css: `
.p-vumetre .vu{ position:relative; width:64px; height:34px; display:block; }
.p-vumetre .grads{ position:absolute; inset:0; }
.p-vumetre .g{ stroke:rgba(255,255,255,.24); stroke-width:1; stroke-linecap:round; }
.p-vumetre .gc{ stroke:rgba(255,255,255,.46); }
.p-vumetre .gd{ stroke:rgba(242,191,83,.46); }
/* deux pendules étrangers : le bras porte l'aiguille, chacun sa période */
.p-vumetre .bras{ position:absolute; left:50%; bottom:6px; width:0; height:0;
  animation:vumetre-p1 7.1s ease-in-out infinite alternate; will-change:transform; }
.p-vumetre .aig{ position:absolute; bottom:0; left:-.75px; width:1.5px; height:23px;
  transform-origin:50% 100%; border-radius:1px;
  background:linear-gradient(180deg,
    #fff 0%, rgba(255,255,255,.92) 18%, rgba(255,255,255,.60) 55%, rgba(255,255,255,.22) 100%);
  box-shadow:0 0 7px rgba(255,255,255,.22);
  animation:vumetre-p2 4.3s cubic-bezier(.42,0,.58,1) -1.7s infinite alternate; will-change:transform; }
@keyframes vumetre-p1{ from{transform:rotate(-13deg)} to{transform:rotate(13deg)} }
@keyframes vumetre-p2{ from{transform:rotate(-9deg)}  to{transform:rotate(9deg)} }
/* le pivot : une perle bombée, lumière à 10 h */
.p-vumetre .pivot{ position:absolute; left:50%; bottom:3.5px; width:5.5px; height:5.5px;
  margin-left:-2.75px; border-radius:50%;
  background:radial-gradient(circle at 34% 28%,
    #fff 0%, rgba(255,255,255,.75) 22%, rgba(150,150,165,.55) 46%,
    rgba(40,40,50,.9) 72%, #0A0A0F 100%);
  box-shadow:0 0 4px rgba(255,255,255,.18); }
/* la lampe d'or : voilée 15 s, vivante 1 s */
.p-vumetre .lampe{ position:absolute; right:1px; top:1px; width:3.5px; height:3.5px; border-radius:50%;
  background:radial-gradient(circle, rgba(242,191,83,.95) 0%, rgba(242,191,83,0) 72%);
  animation:vumetre-lampe 16.9s linear infinite; }
@keyframes vumetre-lampe{
  0%,90%{opacity:.10; transform:scale(1)}
  92%{opacity:.95; transform:scale(1.5)}
  94%{opacity:.35; transform:scale(1.1)}
  96%,100%{opacity:.10; transform:scale(1)} }
.p-vumetre .socle{ position:absolute; left:6px; right:6px; bottom:0; height:1px;
  background:linear-gradient(90deg, transparent, rgba(255,255,255,.16) 28%, rgba(255,255,255,.16) 72%, transparent); }

/* la dalle : l'aiguille seule, même double pendule */
.p-vumetre .vum{ position:relative; width:22px; height:16px; display:block; }
.p-vumetre .brasm{ position:absolute; left:50%; bottom:2.5px; width:0; height:0;
  animation:vumetre-p1 7.1s ease-in-out infinite alternate; }
.p-vumetre .aigm{ position:absolute; bottom:0; left:-.6px; width:1.2px; height:11px;
  transform-origin:50% 100%; border-radius:1px;
  background:linear-gradient(180deg, rgba(255,255,255,.95), rgba(255,255,255,.25));
  animation:vumetre-p2 4.3s cubic-bezier(.42,0,.58,1) -1.7s infinite alternate; }
.p-vumetre .pivotm{ position:absolute; left:50%; bottom:1px; width:3px; height:3px; margin-left:-1.5px;
  border-radius:50%; background:radial-gradient(circle at 35% 30%, #fff, rgba(70,70,82,.9) 70%); }
.p-vumetre .gros{ transform:scale(2.9); }
`,
},

/* ═══════════════ 4. LA CORDE ═══════════════
   Une corde de piano tendue, presque immobile — un frisson y dérive.
   Toutes les onze secondes, quelque chose la PINCE : elle vibre en
   fantômes, l'éclat traverse, puis elle se rassoit. Le silence entre
   deux notes est le luxe. */
{
  id: 'corde',
  nom: 'La Corde',
  cout: 'moyen',
  pitch: "Une corde de piano tendue en travers, presque immobile — un frisson de lumière y dérive à peine. Puis quelque chose la pince : un éclat file le long du fil, la corde vibre en fantômes une seconde, et se rassoit. Le composant vit dans le silence entre deux notes — c'est lui, le luxe.",
  swift: "Trois Capsule() hairline superposées (la corde + 2 fantômes en opacité f(t) à décroissance), l'éclat = un petit LinearGradient en offset f(t) actif 4 % du cycle. Un seul TimelineView scoped, paused sur enMouvement. Le frisson au repos = background offset. Simple, mais l'ÉVÉNEMENT devra un jour s'accrocher à la vraie série validée.",
  compo: `<span class="cd">
    <span class="fil"></span>
    <span class="fg fg1"></span>
    <span class="fg fg2"></span>
    <span class="rip rip1"></span>
    <span class="rip rip2"></span>
  </span>`,
  compoMini: `<span class="cdm">
    <span class="film"></span>
    <span class="ripm"></span>
  </span>`,
  css: `
.p-corde .cd{ position:relative; width:220px; height:22px; display:block; }
.p-corde .fil, .p-corde .fg{ position:absolute; left:0; right:0; top:50%; height:1px; border-radius:.5px;
  background:linear-gradient(90deg, transparent 0%, rgba(255,255,255,.52) 14%, rgba(255,255,255,.52) 86%, transparent 100%); }
.p-corde .fil{ box-shadow:0 0 5px rgba(255,255,255,.10); }
/* le frisson au repos : une clarté qui dérive sur le fil, aller-retour */
.p-corde .fil::after{ content:""; position:absolute; inset:-1px 0; border-radius:inherit;
  background:linear-gradient(90deg, transparent 0%, rgba(255,255,255,.55) 8%, transparent 16%);
  background-size:280px 100%; background-repeat:no-repeat; opacity:.30;
  animation:corde-frisson 14.9s ease-in-out infinite alternate; }
@keyframes corde-frisson{ from{background-position:-60px 0} to{background-position:200px 0} }
/* la vibration : deux fantômes à décroissance, juste après le pincement */
.p-corde .fg{ opacity:0; filter:blur(.6px); will-change:transform,opacity; }
.p-corde .fg1{ animation:corde-vib1 11.3s linear infinite; }
.p-corde .fg2{ animation:corde-vib2 11.3s linear infinite; }
@keyframes corde-vib1{
  0%,6.5%{opacity:0; transform:translateY(0)}
  8%{opacity:.55; transform:translateY(-2.2px)}
  10%{opacity:.30; transform:translateY(1.6px)}
  12%{opacity:.38; transform:translateY(-1.1px)}
  14.5%{opacity:.16; transform:translateY(.7px)}
  18%,100%{opacity:0; transform:translateY(0)} }
@keyframes corde-vib2{
  0%,6.5%{opacity:0; transform:translateY(0)}
  8.6%{opacity:.45; transform:translateY(2.2px)}
  10.6%{opacity:.26; transform:translateY(-1.5px)}
  12.6%{opacity:.30; transform:translateY(1px)}
  15%{opacity:.12; transform:translateY(-.6px)}
  18%,100%{opacity:0; transform:translateY(0)} }
/* le pincement : l'éclat traverse en 0,7 s, puis 10 s de silence ;
   une réponse plus douce revient de l'autre côté sur SA propre horloge */
.p-corde .rip{ position:absolute; top:50%; margin-top:-3.5px; width:44px; height:7px; border-radius:4px;
  background:radial-gradient(50% 50% at 50% 50%, rgba(255,255,255,.85) 0%, rgba(255,255,255,.25) 55%, transparent 78%);
  mix-blend-mode:screen; opacity:0; will-change:transform,opacity; }
.p-corde .rip1{ animation:corde-note1 11.3s cubic-bezier(.3,.1,.5,1) infinite; }
.p-corde .rip2{ animation:corde-note2 17.9s cubic-bezier(.3,.1,.5,1) -5.1s infinite; }
@keyframes corde-note1{
  0%{transform:translateX(-46px); opacity:0}
  1%{opacity:.9}
  6.5%{transform:translateX(224px); opacity:0}
  100%{transform:translateX(224px); opacity:0} }
@keyframes corde-note2{
  0%{transform:translateX(224px); opacity:0}
  1%{opacity:.38}
  6%{transform:translateX(-46px); opacity:0}
  100%{transform:translateX(-46px); opacity:0} }

/* la dalle : le fil court, une note discrète */
.p-corde .cdm{ position:relative; width:26px; height:14px; display:block; }
.p-corde .film{ position:absolute; left:0; right:0; top:50%; height:1px;
  background:linear-gradient(90deg, transparent, rgba(255,255,255,.55) 30%, rgba(255,255,255,.55) 70%, transparent); }
.p-corde .ripm{ position:absolute; top:50%; margin-top:-2px; width:12px; height:4px; border-radius:2px;
  background:radial-gradient(50% 50% at 50% 50%, rgba(255,255,255,.8), transparent 75%);
  mix-blend-mode:screen; opacity:0;
  animation:corde-notem 11.3s cubic-bezier(.3,.1,.5,1) infinite; }
@keyframes corde-notem{
  0%{transform:translateX(-12px); opacity:0}
  1.2%{opacity:.8}
  7%{transform:translateX(28px); opacity:0}
  100%{transform:translateX(28px); opacity:0} }
.p-corde .gros{ transform:scale(2.2); }
`,
},

/* ═══════════════ 5. LES PASTILLES ═══════════════
   Cinq perles qui respirent en vague — la vague passe, puis REVIENT
   (alternate : aucun sens de lecture). Celle du centre est l'ancre ;
   toutes les treize secondes, elle lâche un anneau, comme une goutte
   dans l'eau noire. */
{
  id: 'pastilles',
  nom: 'Les Pastilles',
  cout: 'léger',
  pitch: "Cinq perles de lumière respirent en vague — la vague traverse, puis revient sur ses pas, aucun sens ne s'installe. Chaque perle a son point de lumière à dix heures, celle du centre est un souffle plus grande, et toutes les treize secondes elle lâche un anneau qui s'évanouit, comme une goutte posée sur de l'eau noire.",
  swift: "Cinq Circle() en HStack, scaleEffect+opacité = f(t + phase_i) d'UN TimelineView scoped, paused sur enMouvement. L'anneau = un Circle().stroke en scale/opacité sur créneau rare. Avec le reflet radial en AngularGradient figé, zéro coût caché — l'autre candidate « léger » avec l'équaliseur.",
  compo: `<span class="pa">
    <i class="d d1"></i><i class="d d2"></i><i class="d d3"></i><i class="d d4"></i><i class="d d5"></i>
    <span class="ring"></span>
  </span>`,
  compoMini: `<span class="pam">
    <i class="dm dm1"></i><i class="dm dm2"></i><i class="dm dm3"></i>
  </span>`,
  css: `
.p-pastilles .pa{ position:relative; display:flex; align-items:center; gap:8px; height:26px; }
.p-pastilles .d{ display:block; width:3.8px; height:3.8px; border-radius:50%;
  background:radial-gradient(circle at 38% 32%,
    rgba(255,255,255,.98) 0%, rgba(255,255,255,.62) 40%, rgba(255,255,255,.14) 100%);
  box-shadow:0 0 6px rgba(255,255,255,.18);
  will-change:transform,opacity; }
.p-pastilles .d1{ animation:pastilles-vague 6.1s cubic-bezier(.45,.05,.55,.95) -0.00s infinite alternate; }
.p-pastilles .d2{ animation:pastilles-vague 6.1s cubic-bezier(.45,.05,.55,.95) -0.75s infinite alternate; }
.p-pastilles .d3{ animation:pastilles-vague 6.1s cubic-bezier(.45,.05,.55,.95) -1.50s infinite alternate; }
.p-pastilles .d4{ animation:pastilles-vague 6.1s cubic-bezier(.45,.05,.55,.95) -2.25s infinite alternate; }
.p-pastilles .d5{ animation:pastilles-vague 6.1s cubic-bezier(.45,.05,.55,.95) -3.00s infinite alternate; }
@keyframes pastilles-vague{
  from{ transform:scale(.66); opacity:.34 }
  to{   transform:scale(1.30); opacity:1 } }
/* l'ancre : la perle du centre, un souffle plus grande et plus claire */
.p-pastilles .d3{ width:4.4px; height:4.4px; filter:brightness(1.12); }
/* la goutte : un anneau lâché par le centre toutes les 13,1 s */
.p-pastilles .ring{ position:absolute; left:50%; top:50%; width:10px; height:10px;
  margin:-5px 0 0 -5px; border-radius:50%;
  border:.8px solid rgba(255,255,255,.5);
  opacity:0; will-change:transform,opacity; }
.p-pastilles .ring{ animation:pastilles-goutte 13.1s cubic-bezier(.2,.4,.4,1) infinite; }
@keyframes pastilles-goutte{
  0%,84%{ transform:scale(.4); opacity:0 }
  86%{ opacity:.55 }
  100%{ transform:scale(3.6); opacity:0 } }

/* la dalle : trois perles */
.p-pastilles .pam{ display:flex; align-items:center; gap:5px; height:12px; }
.p-pastilles .dm{ display:block; width:2.8px; height:2.8px; border-radius:50%;
  background:radial-gradient(circle at 38% 32%, rgba(255,255,255,.95), rgba(255,255,255,.15));
  will-change:transform,opacity; }
.p-pastilles .dm1{ animation:pastilles-vague 6.1s cubic-bezier(.45,.05,.55,.95) -0.0s infinite alternate; }
.p-pastilles .dm2{ animation:pastilles-vague 6.1s cubic-bezier(.45,.05,.55,.95) -1.5s infinite alternate; }
.p-pastilles .dm3{ animation:pastilles-vague 6.1s cubic-bezier(.45,.05,.55,.95) -3.0s infinite alternate; }
.p-pastilles .gros{ transform:scale(3.4); }
`,
},

/* ═══════════════ 6. LE SPECTRE ═══════════════
   Trois silhouettes de spectre superposées, remplies de blanc profond,
   qui se fondent l'une dans l'autre — la FORME respire, rien ne se
   remplit. Une crête fine coiffe la plus vivante. */
{
  id: 'spectre',
  nom: 'Le Spectre',
  cout: 'moyen',
  pitch: "Trois silhouettes de son superposées, remplies d'un blanc qui meurt vers le bas, se fondent l'une dans l'autre : la forme respire, aucun remplissage, aucun front. Une crête d'un demi-point coiffe la silhouette la plus vivante, et l'ensemble se soulève à peine, comme une masse d'air qui écoute.",
  swift: "Trois Path fermés pré-dessinés dans un Canvas 240×26 (ou trois Shape), opacités croisées = f(t) d'UN TimelineView scoped, paused sur enMouvement, scaleY léger ancré en bas via scaleEffect(anchor:.bottom). La crête = le même path en stroke. Compact et sûr — le seul soin est d'accorder les trois horloges.",
  compo: `<span class="sp">
    <svg viewBox="0 0 220 28" width="220" height="28" aria-hidden="true">
      <defs>
        <linearGradient id="spectre-fill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="rgba(255,255,255,.50)"/>
          <stop offset=".45" stop-color="rgba(255,255,255,.20)"/>
          <stop offset="1" stop-color="rgba(255,255,255,0)"/>
        </linearGradient>
      </defs>
      <path class="s1" d="M0 28 L0 22 C 26 12, 48 18, 72 13 C 98 8, 124 19, 150 14 C 172 10, 196 17, 220 20 L220 28 Z" fill="url(#spectre-fill)"/>
      <path class="s2" d="M0 28 L0 19 C 30 22, 52 9, 82 15 C 110 20, 138 7, 166 13 C 190 18, 206 14, 220 17 L220 28 Z" fill="url(#spectre-fill)"/>
      <path class="s3" d="M0 28 L0 23 C 36 18, 62 21, 96 18 C 130 15, 158 21, 188 18 C 202 17, 212 19, 220 21 L220 28 Z" fill="url(#spectre-fill)"/>
      <path class="cr" d="M0 22 C 26 12, 48 18, 72 13 C 98 8, 124 19, 150 14 C 172 10, 196 17, 220 20" fill="none"/>
    </svg>
  </span>`,
  compoMini: `<span class="spm">
    <svg viewBox="0 0 26 12" width="26" height="12" aria-hidden="true">
      <path class="sm" d="M0 12 L0 9 C 6 4, 10 7, 14 5 C 18 3, 22 7, 26 8 L26 12 Z" fill="rgba(255,255,255,.32)"/>
      <path class="cm" d="M0 9 C 6 4, 10 7, 14 5 C 18 3, 22 7, 26 8" fill="none"/>
    </svg>
  </span>`,
  css: `
.p-spectre .sp{ display:block; width:220px; height:28px;
  -webkit-mask-image:linear-gradient(90deg, transparent, #000 12%, #000 88%, transparent);
  mask-image:linear-gradient(90deg, transparent, #000 12%, #000 88%, transparent); }
.p-spectre .sp path{ transform-box:fill-box; transform-origin:50% 100%; will-change:opacity,transform; }
.p-spectre .s1{ animation:spectre-r1 10.3s ease-in-out infinite alternate; }
.p-spectre .s2{ animation:spectre-r2 13.7s ease-in-out -4.3s infinite alternate; }
.p-spectre .s3{ animation:spectre-r3 8.1s  ease-in-out -2.1s infinite alternate; }
@keyframes spectre-r1{ from{opacity:.92; transform:scaleY(1)}    to{opacity:.22; transform:scaleY(.86)} }
@keyframes spectre-r2{ from{opacity:.18; transform:scaleY(.82)}  to{opacity:.78; transform:scaleY(1.06)} }
@keyframes spectre-r3{ from{opacity:.55; transform:scaleY(1.04)} to{opacity:.14; transform:scaleY(.88)} }
/* la crête : un demi-point de blanc sur la silhouette maîtresse,
   la MÊME horloge que s1 — elles vivent et meurent ensemble */
.p-spectre .cr{ stroke:rgba(255,255,255,.55); stroke-width:.7; stroke-linecap:round;
  animation:spectre-r1 10.3s ease-in-out infinite alternate; }

/* la dalle : une seule silhouette qui respire */
.p-spectre .spm{ display:block; width:26px; height:12px; }
.p-spectre .sm{ transform-box:fill-box; transform-origin:50% 100%;
  animation:spectre-r2 13.7s ease-in-out infinite alternate; }
.p-spectre .cm{ stroke:rgba(255,255,255,.6); stroke-width:.7; fill:none;
  animation:spectre-r2 13.7s ease-in-out infinite alternate; }
.p-spectre .gros{ transform:scale(2.2); }
`,
},
]
