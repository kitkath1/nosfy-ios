// QUATRIÈME SÉRIE — L'ÉQUALISEUR DÉCLINÉ. Six matières du même objet,
// écrites à la main. Toutes ancrées au CENTRE (jamais au sol : le sol en
// ferait une jauge), toutes sur des horloges non rondes, toutes en
// aller-retour — rien ne se compte, rien ne se remplit.
export default [

/* ═══════════════ 1. LE MIROIR ═══════════════
   Treize lames d'un point, symétriques autour d'un axe-hairline, comme
   une onde sculptée dans le métal : le cœur brille où la lame croise
   l'axe, les pointes meurent. Une lumière dérive le long de l'axe. */
{
  id: 'miroir',
  nom: 'Le Miroir',
  cout: 'léger',
  pitch: "Treize lames d'un point, en miroir parfait autour d'un axe fin comme un cheveu — une onde sculptée plutôt qu'un équaliseur : le cœur de chaque lame s'allume là où elle croise l'axe, les pointes meurent en fumée, et une lumière lente dérive le long de l'axe comme un doigt sur la tranche d'un instrument.",
  swift: "Treize Capsule() de 1,2 pt en HStack, scaleEffect(y:) = f(t + phase_i) d'UN TimelineView scoped, paused sur enMouvement ; l'axe = un Rectangle hairline, sa lumière = un LinearGradient en offset f(t). Transform et opacité seulement — aussi léger que l'équaliseur calme.",
  compo: `<span class="mr">
    <span class="axe"></span><span class="axelum"></span>
    <i class="l l1"></i><i class="l l2"></i><i class="l l3"></i><i class="l l4"></i><i class="l l5"></i><i class="l l6"></i><i class="l l7"></i><i class="l l8"></i><i class="l l9"></i><i class="l l10"></i><i class="l l11"></i><i class="l l12"></i><i class="l l13"></i>
  </span>`,
  compoMini: `<span class="mrm">
    <span class="axem"></span>
    <i class="lm lm1"></i><i class="lm lm2"></i><i class="lm lm3"></i><i class="lm lm4"></i><i class="lm lm5"></i><i class="lm lm6"></i><i class="lm lm7"></i>
  </span>`,
  css: `
.p-miroir .mr{ position:relative; display:flex; align-items:center; gap:5.5px; height:30px; padding:0 4px; }
.p-miroir .axe{ position:absolute; left:-6px; right:-6px; top:50%; height:1px;
  background:linear-gradient(90deg, transparent, rgba(255,255,255,.16) 12%, rgba(255,255,255,.16) 88%, transparent); }
/* la lumière qui dérive le long de l'axe, aller-retour */
.p-miroir .axelum{ position:absolute; left:-6px; right:-6px; top:50%; margin-top:-1px; height:2px;
  background:radial-gradient(28px 2.4px at 20% 50%, rgba(255,255,255,.55), transparent 72%);
  background-repeat:no-repeat; filter:blur(.3px);
  animation:miroir-derive 12.7s ease-in-out infinite alternate; }
@keyframes miroir-derive{ from{background-position:-14px 0} to{background-position:76px 0} }
.p-miroir .l{
  display:block; width:1.2px; height:24px; border-radius:.8px; will-change:transform;
  background:linear-gradient(180deg,
    rgba(255,255,255,0) 0%, rgba(255,255,255,.28) 22%,
    rgba(255,255,255,.92) 50%,
    rgba(255,255,255,.28) 78%, rgba(255,255,255,0) 100%); }
.p-miroir .l1{  animation:miroir-o1 6.1s cubic-bezier(.45,.05,.55,.95) -0.4s infinite alternate; }
.p-miroir .l2{  animation:miroir-o2 5.3s cubic-bezier(.45,.05,.55,.95) -2.1s infinite alternate; }
.p-miroir .l3{  animation:miroir-o3 7.1s cubic-bezier(.45,.05,.55,.95) -1.3s infinite alternate; }
.p-miroir .l4{  animation:miroir-o1 5.9s cubic-bezier(.45,.05,.55,.95) -3.6s infinite alternate; }
.p-miroir .l5{  animation:miroir-o2 6.7s cubic-bezier(.45,.05,.55,.95) -0.9s infinite alternate; }
.p-miroir .l6{  animation:miroir-o3 5.1s cubic-bezier(.45,.05,.55,.95) -2.7s infinite alternate; }
.p-miroir .l7{  animation:miroir-o1 7.7s cubic-bezier(.45,.05,.55,.95) -1.8s infinite alternate; filter:brightness(1.12); }
.p-miroir .l8{  animation:miroir-o2 5.7s cubic-bezier(.45,.05,.55,.95) -4.2s infinite alternate; }
.p-miroir .l9{  animation:miroir-o3 6.3s cubic-bezier(.45,.05,.55,.95) -0.6s infinite alternate; }
.p-miroir .l10{ animation:miroir-o1 5.5s cubic-bezier(.45,.05,.55,.95) -3.1s infinite alternate; }
.p-miroir .l11{ animation:miroir-o2 7.3s cubic-bezier(.45,.05,.55,.95) -1.5s infinite alternate; }
.p-miroir .l12{ animation:miroir-o3 5.9s cubic-bezier(.45,.05,.55,.95) -2.4s infinite alternate; }
.p-miroir .l13{ animation:miroir-o1 6.5s cubic-bezier(.45,.05,.55,.95) -0.2s infinite alternate; }
@keyframes miroir-o1{ 0%{transform:scaleY(.22)} 36%{transform:scaleY(.78)} 64%{transform:scaleY(.38)} 100%{transform:scaleY(.96)} }
@keyframes miroir-o2{ 0%{transform:scaleY(.66)} 30%{transform:scaleY(.26)} 58%{transform:scaleY(.88)} 100%{transform:scaleY(.30)} }
@keyframes miroir-o3{ 0%{transform:scaleY(.40)} 26%{transform:scaleY(.92)} 60%{transform:scaleY(.24)} 74%{transform:scaleY(.24)} 100%{transform:scaleY(.72)} }

.p-miroir .mrm{ position:relative; display:flex; align-items:center; gap:3.4px; height:22px; }
.p-miroir .axem{ position:absolute; left:-3px; right:-3px; top:50%; height:1px; background:rgba(255,255,255,.22); }
.p-miroir .lm{ display:block; width:1.3px; height:18px; border-radius:.8px; will-change:transform;
  background:linear-gradient(180deg, transparent, rgba(255,255,255,.95) 50%, transparent); }
.p-miroir .lm1{ animation:miroir-o2 5.3s cubic-bezier(.45,.05,.55,.95) -0.8s infinite alternate; }
.p-miroir .lm2{ animation:miroir-o1 6.1s cubic-bezier(.45,.05,.55,.95) -2.6s infinite alternate; }
.p-miroir .lm3{ animation:miroir-o3 5.7s cubic-bezier(.45,.05,.55,.95) -1.1s infinite alternate; }
.p-miroir .lm4{ animation:miroir-o1 7.1s cubic-bezier(.45,.05,.55,.95) -3.9s infinite alternate; }
.p-miroir .lm5{ animation:miroir-o2 6.5s cubic-bezier(.45,.05,.55,.95) -0.3s infinite alternate; }
.p-miroir .lm6{ animation:miroir-o3 5.1s cubic-bezier(.45,.05,.55,.95) -2.2s infinite alternate; }
.p-miroir .lm7{ animation:miroir-o1 6.9s cubic-bezier(.45,.05,.55,.95) -1.7s infinite alternate; }
.p-miroir .gros{ transform:scale(2.8); }
`,
},

/* ═══════════════ 2. LES COLONNES DE PERLES ═══════════════
   L'équaliseur en points comptés : sept colonnes de cinq perles, la
   colonne « monte » en allumant ses perles une à une depuis l'épine
   centrale — les consoles de studio, refaites en joaillerie. */
{
  id: 'colonnes',
  nom: 'Les Colonnes de perles',
  cout: 'léger',
  pitch: "Sept colonnes de cinq perles minuscules : la rangée du centre est une épine toujours allumée, et chaque colonne respire en allumant ses perles voisines une à une, puis les hautes, rarement — du comptage de console de studio, refait en joaillerie. Rien ne glisse : la lumière s'allume ou se tait, par perles entières.",
  swift: "Trente-cinq Circle() de 2 pt en grille, opacité = f(t, colonne, rangée) à PLATEAUX (pas de rampe : la perle est allumée ou éteinte, le fondu dure 120 ms) — un seul TimelineView scoped, paused sur enMouvement. C'est le moins cher en pixels et le plus horloger en écriture.",
  compo: `<span class="co">
    <span class="c c1"><i class="px r1"></i><i class="px r2"></i><i class="px r3"></i><i class="px r4"></i><i class="px r5"></i></span>
    <span class="c c2"><i class="px r1"></i><i class="px r2"></i><i class="px r3"></i><i class="px r4"></i><i class="px r5"></i></span>
    <span class="c c3"><i class="px r1"></i><i class="px r2"></i><i class="px r3"></i><i class="px r4"></i><i class="px r5"></i></span>
    <span class="c c4"><i class="px r1"></i><i class="px r2"></i><i class="px r3"></i><i class="px r4"></i><i class="px r5"></i></span>
    <span class="c c5"><i class="px r1"></i><i class="px r2"></i><i class="px r3"></i><i class="px r4"></i><i class="px r5"></i></span>
    <span class="c c6"><i class="px r1"></i><i class="px r2"></i><i class="px r3"></i><i class="px r4"></i><i class="px r5"></i></span>
    <span class="c c7"><i class="px r1"></i><i class="px r2"></i><i class="px r3"></i><i class="px r4"></i><i class="px r5"></i></span>
  </span>`,
  compoMini: `<span class="com">
    <span class="cm"><i class="pm pr1"></i><i class="pm pr2"></i><i class="pm pr3"></i></span>
    <span class="cm cmb"><i class="pm pr1"></i><i class="pm pr2"></i><i class="pm pr3"></i></span>
    <span class="cm cmc"><i class="pm pr1"></i><i class="pm pr2"></i><i class="pm pr3"></i></span>
    <span class="cm"><i class="pm pr1"></i><i class="pm pr2"></i><i class="pm pr3"></i></span>
    <span class="cm cmb"><i class="pm pr1"></i><i class="pm pr2"></i><i class="pm pr3"></i></span>
  </span>`,
  css: `
.p-colonnes .co{ display:flex; align-items:center; gap:7px; height:30px; }
.p-colonnes .c{ display:flex; flex-direction:column; align-items:center; gap:2.8px; }
.p-colonnes .px{ display:block; width:2.2px; height:2.2px; border-radius:50%;
  background:radial-gradient(circle at 38% 32%, rgba(255,255,255,.98) 0%, rgba(255,255,255,.55) 45%, rgba(255,255,255,.10) 100%);
  will-change:opacity; }
/* l'épine : la perle centrale, un souffle plus grande, toujours vivante */
.p-colonnes .px.r3{ width:2.7px; height:2.7px; opacity:.95;
  animation:colonnes-epine 9.7s ease-in-out infinite alternate; }
@keyframes colonnes-epine{ from{opacity:.78} to{opacity:1} }
/* les voisines s'allument par plateaux, les hautes rarement */
.p-colonnes .px.r2, .p-colonnes .px.r4{ animation:colonnes-mid var(--d,7.1s) linear var(--dl,0s) infinite; }
.p-colonnes .px.r1, .p-colonnes .px.r5{ animation:colonnes-ext var(--d,7.1s) linear var(--dl,0s) infinite; }
@keyframes colonnes-mid{
  0%,20%{opacity:.16} 22%{opacity:.90} 64%{opacity:.90} 66%{opacity:.16} 100%{opacity:.16} }
@keyframes colonnes-ext{
  0%,38%{opacity:.08} 40%{opacity:.80} 54%{opacity:.80} 56%{opacity:.08} 100%{opacity:.08} }
.p-colonnes .c1{ --d:6.1s;  --dl:-1.2s; }
.p-colonnes .c2{ --d:7.9s;  --dl:-4.6s; }
.p-colonnes .c3{ --d:5.3s;  --dl:-2.1s; }
.p-colonnes .c4{ --d:8.7s;  --dl:-0.6s; }
.p-colonnes .c5{ --d:6.7s;  --dl:-3.3s; }
.p-colonnes .c6{ --d:7.3s;  --dl:-5.1s; }
.p-colonnes .c7{ --d:5.9s;  --dl:-1.8s; }

.p-colonnes .com{ display:flex; align-items:center; gap:5px; height:22px; }
.p-colonnes .cm{ display:flex; flex-direction:column; align-items:center; gap:2.6px; }
.p-colonnes .pm{ display:block; width:2.6px; height:2.6px; border-radius:50%;
  background:radial-gradient(circle at 38% 32%, rgba(255,255,255,.98), rgba(255,255,255,.14)); }
.p-colonnes .pm.pr2{ width:3px; height:3px; opacity:.95; }
.p-colonnes .cm .pm.pr1, .p-colonnes .cm .pm.pr3{ animation:colonnes-mid 6.7s linear -2.4s infinite; }
.p-colonnes .cmb .pm.pr1, .p-colonnes .cmb .pm.pr3{ animation:colonnes-ext 7.9s linear -0.9s infinite; }
.p-colonnes .cmc .pm.pr1, .p-colonnes .cmc .pm.pr3{ animation:colonnes-mid 5.3s linear -4.1s infinite; }
.p-colonnes .gros{ transform:scale(3.0); }
`,
},

/* ═══════════════ 3. LE VERRE TAILLÉ ═══════════════
   Cinq pavés de verre liquide qui respirent : corps translucide,
   arête hairline, éclat spéculaire en biais — et sous chacun, la
   caustique violette que le verre projette sur le sol noir. */
{
  id: 'verre',
  nom: 'Le Verre taillé',
  cout: 'moyen',
  pitch: "Cinq pavés de verre liquide dansent lentement : corps translucide, arête d'un demi-point, un éclat spéculaire en biais dans la masse — et sous chaque pavé, la caustique violette qu'il projette sur le sol noir grandit et meurt avec lui. Le Liquid Glass de l'app, taillé en objet de musique.",
  swift: "Cinq RoundedRectangle en dégradé + arête (strokeBorder .5 pt) + éclat (LinearGradient masqué), scaleEffect(y:) f(t) d'UN TimelineView scoped, paused sur enMouvement ; la caustique = une Ellipse violette floutée dont l'échelle suit la lame. ⚠️ PAS de glassEffect natif (verre animé = 60→14 img/s, loi payée) : tout est peint, rien n'est du vrai verre.",
  compo: `<span class="ve">
    <i class="vs s1"><b class="ecl"></b><b class="ca"></b></i>
    <i class="vs s2"><b class="ecl"></b><b class="ca"></b></i>
    <i class="vs s3"><b class="ecl"></b><b class="ca"></b></i>
    <i class="vs s4"><b class="ecl"></b><b class="ca"></b></i>
    <i class="vs s5"><b class="ecl"></b><b class="ca"></b></i>
  </span>`,
  compoMini: `<span class="vem">
    <i class="sm sm1"></i><i class="sm sm2"></i><i class="sm sm3"></i>
  </span>`,
  css: `
.p-verre .ve{ display:flex; align-items:center; gap:6px; height:34px; }
.p-verre .vs{ display:block; position:relative; width:6.5px; height:24px; border-radius:3px;
  background:linear-gradient(168deg,
    rgba(255,255,255,.26) 0%, rgba(255,255,255,.10) 34%,
    rgba(233,228,255,.07) 60%, rgba(255,255,255,.16) 100%);
  box-shadow:
    inset 0 0 0 .5px rgba(255,255,255,.30),
    inset 0 .5px 0 rgba(255,255,255,.45),
    0 0 8px rgba(255,255,255,.05);
  will-change:transform; overflow:visible; }
/* l'éclat spéculaire, en biais dans la masse */
.p-verre .ecl{ position:absolute; inset:0; border-radius:inherit; overflow:hidden; display:block; }
.p-verre .ecl::after{ content:""; position:absolute; left:-40%; right:-40%; top:16%; height:26%;
  background:linear-gradient(90deg, transparent, rgba(255,255,255,.55) 48%, transparent);
  transform:rotate(-24deg); filter:blur(.4px); }
/* la caustique : le violet que le verre pose au sol */
.p-verre .ca{ position:absolute; left:50%; top:calc(100% + 4px); width:16px; height:5px;
  margin-left:-8px; border-radius:50%; display:block;
  background:radial-gradient(50% 50% at 50% 50%, rgba(133,93,255,.42) 0%, rgba(133,93,255,.10) 60%, transparent 82%);
  filter:blur(1.4px); }
.p-verre .s1{ animation:verre-d1 7.9s cubic-bezier(.45,.05,.55,.95) -1.1s infinite alternate; }
.p-verre .s2{ animation:verre-d2 6.1s cubic-bezier(.45,.05,.55,.95) -3.4s infinite alternate; }
.p-verre .s3{ animation:verre-d3 8.9s cubic-bezier(.45,.05,.55,.95) -0.5s infinite alternate; filter:brightness(1.10); }
.p-verre .s4{ animation:verre-d2 7.1s cubic-bezier(.45,.05,.55,.95) -4.8s infinite alternate; }
.p-verre .s5{ animation:verre-d1 6.7s cubic-bezier(.45,.05,.55,.95) -2.2s infinite alternate; }
@keyframes verre-d1{ 0%{transform:scaleY(.42)} 38%{transform:scaleY(.92)} 68%{transform:scaleY(.55)} 100%{transform:scaleY(.80)} }
@keyframes verre-d2{ 0%{transform:scaleY(.85)} 32%{transform:scaleY(.40)} 66%{transform:scaleY(.98)} 100%{transform:scaleY(.48)} }
@keyframes verre-d3{ 0%{transform:scaleY(.55)} 30%{transform:scaleY(1.0)} 58%{transform:scaleY(.38)} 72%{transform:scaleY(.38)} 100%{transform:scaleY(.90)} }

.p-verre .vem{ display:flex; align-items:center; gap:4.5px; height:22px; }
.p-verre .sm{ display:block; width:4.4px; height:17px; border-radius:2.2px;
  background:linear-gradient(168deg, rgba(255,255,255,.30), rgba(255,255,255,.10) 55%, rgba(255,255,255,.18));
  box-shadow:inset 0 0 0 .5px rgba(255,255,255,.28); will-change:transform; }
.p-verre .sm1{ animation:verre-d1 6.7s cubic-bezier(.45,.05,.55,.95) -1.9s infinite alternate; }
.p-verre .sm2{ animation:verre-d3 7.9s cubic-bezier(.45,.05,.55,.95) -0.4s infinite alternate; }
.p-verre .sm3{ animation:verre-d2 6.1s cubic-bezier(.45,.05,.55,.95) -3.0s infinite alternate; }
.p-verre .gros{ transform:scale(2.7); }
`,
},

/* ═══════════════ 4. L'ÉVENTAIL ═══════════════
   Sept lames déployées depuis un pivot-perle, comme un éventail ou une
   aigrette : chacune respire le long de SON axe, les pointes dessinent
   une aigrette de lumière qui s'ouvre et se referme. */
{
  id: 'eventail',
  nom: "L'Éventail",
  cout: 'léger',
  pitch: "Sept lames déployées depuis une perle-pivot, comme un éventail à peine ouvert : chacune respire le long de son propre axe, et leurs pointes dessinent une aigrette de lumière qui s'ouvre et se referme sans jamais battre la mesure. Un arc-hairline fantôme retient l'ensemble.",
  swift: "Sept Capsule() chacune dans un rotationEffect fixe ((i−4)×8°, anchor bas) + scaleEffect(y:, anchor:.bottom) = f(t) d'UN TimelineView scoped, paused sur enMouvement ; le pivot = un Circle, l'arc = un Path statique à 8 %. Géométrie figée, seul scaleY vit — léger et sûr.",
  compo: `<span class="ev">
    <svg class="arc" viewBox="0 0 96 40" width="96" height="40" aria-hidden="true">
      <path d="M14 16 A 40 40 0 0 1 82 16" fill="none"/>
    </svg>
    <span class="r rr1"><i class="f"></i></span>
    <span class="r rr2"><i class="f"></i></span>
    <span class="r rr3"><i class="f"></i></span>
    <span class="r rr4"><i class="f"></i></span>
    <span class="r rr5"><i class="f"></i></span>
    <span class="r rr6"><i class="f"></i></span>
    <span class="r rr7"><i class="f"></i></span>
    <span class="piv"></span>
  </span>`,
  compoMini: `<span class="evm">
    <span class="rm rm1"><i class="fm"></i></span>
    <span class="rm rm2"><i class="fm"></i></span>
    <span class="rm rm3"><i class="fm"></i></span>
    <span class="rm rm4"><i class="fm"></i></span>
    <span class="rm rm5"><i class="fm"></i></span>
    <span class="pivm"></span>
  </span>`,
  css: `
.p-eventail .ev{ position:relative; width:96px; height:40px; display:block; }
.p-eventail .arc path{ stroke:rgba(255,255,255,.09); stroke-width:1; }
.p-eventail .r{ position:absolute; left:50%; bottom:7px; width:0; height:0; display:block; }
.p-eventail .f{ position:absolute; bottom:0; left:-1px; width:2px; height:24px; border-radius:1.2px;
  transform-origin:50% 100%; will-change:transform;
  background:linear-gradient(180deg,
    rgba(255,255,255,.88) 0%, rgba(255,255,255,.42) 42%, rgba(255,255,255,.10) 100%); }
.p-eventail .rr1{ transform:rotate(-24deg); } .p-eventail .rr1 .f{ opacity:.55;
  animation:eventail-b1 6.1s cubic-bezier(.45,.05,.55,.95) -0.7s infinite alternate; }
.p-eventail .rr2{ transform:rotate(-16deg); } .p-eventail .rr2 .f{ opacity:.72;
  animation:eventail-b2 5.3s cubic-bezier(.45,.05,.55,.95) -2.4s infinite alternate; }
.p-eventail .rr3{ transform:rotate(-8deg); }  .p-eventail .rr3 .f{ opacity:.88;
  animation:eventail-b3 7.3s cubic-bezier(.45,.05,.55,.95) -1.2s infinite alternate; }
.p-eventail .rr4{ transform:rotate(0deg); }   .p-eventail .rr4 .f{
  animation:eventail-b1 6.7s cubic-bezier(.45,.05,.55,.95) -3.8s infinite alternate; }
.p-eventail .rr5{ transform:rotate(8deg); }   .p-eventail .rr5 .f{ opacity:.88;
  animation:eventail-b2 5.9s cubic-bezier(.45,.05,.55,.95) -0.4s infinite alternate; }
.p-eventail .rr6{ transform:rotate(16deg); }  .p-eventail .rr6 .f{ opacity:.72;
  animation:eventail-b3 5.1s cubic-bezier(.45,.05,.55,.95) -2.9s infinite alternate; }
.p-eventail .rr7{ transform:rotate(24deg); }  .p-eventail .rr7 .f{ opacity:.55;
  animation:eventail-b1 7.1s cubic-bezier(.45,.05,.55,.95) -1.7s infinite alternate; }
@keyframes eventail-b1{ 0%{transform:scaleY(.38)} 34%{transform:scaleY(.88)} 66%{transform:scaleY(.50)} 100%{transform:scaleY(.98)} }
@keyframes eventail-b2{ 0%{transform:scaleY(.82)} 28%{transform:scaleY(.36)} 60%{transform:scaleY(.94)} 100%{transform:scaleY(.44)} }
@keyframes eventail-b3{ 0%{transform:scaleY(.50)} 30%{transform:scaleY(.96)} 62%{transform:scaleY(.30)} 76%{transform:scaleY(.30)} 100%{transform:scaleY(.78)} }
.p-eventail .piv{ position:absolute; left:50%; bottom:4.5px; width:4.5px; height:4.5px; margin-left:-2.25px;
  border-radius:50%;
  background:radial-gradient(circle at 36% 30%, #fff 0%, rgba(255,255,255,.7) 26%, rgba(120,120,135,.6) 52%, #0B0B10 100%);
  box-shadow:0 0 5px rgba(255,255,255,.20); }

.p-eventail .evm{ position:relative; width:34px; height:22px; display:block; }
.p-eventail .rm{ position:absolute; left:50%; bottom:3px; width:0; height:0; display:block; }
.p-eventail .fm{ position:absolute; bottom:0; left:-.7px; width:1.4px; height:15px; border-radius:.9px;
  transform-origin:50% 100%; will-change:transform;
  background:linear-gradient(180deg, rgba(255,255,255,.85), rgba(255,255,255,.08)); }
.p-eventail .rm1{ transform:rotate(-22deg); } .p-eventail .rm1 .fm{ opacity:.6;
  animation:eventail-b2 5.3s cubic-bezier(.45,.05,.55,.95) -1.1s infinite alternate; }
.p-eventail .rm2{ transform:rotate(-11deg); } .p-eventail .rm2 .fm{ opacity:.8;
  animation:eventail-b1 6.1s cubic-bezier(.45,.05,.55,.95) -3.2s infinite alternate; }
.p-eventail .rm3{ transform:rotate(0deg); }   .p-eventail .rm3 .fm{
  animation:eventail-b3 6.7s cubic-bezier(.45,.05,.55,.95) -0.6s infinite alternate; }
.p-eventail .rm4{ transform:rotate(11deg); }  .p-eventail .rm4 .fm{ opacity:.8;
  animation:eventail-b2 5.7s cubic-bezier(.45,.05,.55,.95) -2.5s infinite alternate; }
.p-eventail .rm5{ transform:rotate(22deg); }  .p-eventail .rm5 .fm{ opacity:.6;
  animation:eventail-b1 5.1s cubic-bezier(.45,.05,.55,.95) -1.4s infinite alternate; }
.p-eventail .pivm{ position:absolute; left:50%; bottom:1px; width:3px; height:3px; margin-left:-1.5px;
  border-radius:50%; background:radial-gradient(circle at 36% 30%, #fff, rgba(80,80,95,.8) 70%); }
.p-eventail .gros{ transform:scale(2.4); }
`,
},

/* ═══════════════ 5. LA NOTE ═══════════════
   Sept lames blanches — et UNE porte un cœur violet qui migre de lame
   en lame, sans ordre lisible, comme une note qui se promène dans
   l'accord. Sous la lame élue, un souffle violet au sol. */
{
  id: 'note',
  nom: 'La Note',
  cout: 'léger',
  pitch: "Sept lames blanches dansent — et une seule, à chaque instant, porte un cœur violet qui pose son souffle au sol sous elle. Toutes les six secondes la note migre vers une autre lame, sans ordre lisible : c'est une note qui se promène dans l'accord, jamais un curseur qui avance.",
  swift: "L'équaliseur calme + un index « élu » qui saute selon une permutation figée (4,5,3,6,2,7,1), crossfade 800 ms — l'overlay violet = un LinearGradient en opacité f(t), le souffle = une Ellipse floutée liée à la même opacité. Un TimelineView scoped, paused sur enMouvement. Léger, et le premier candidat à s'accrocher plus tard à la VRAIE série validée.",
  compo: `<span class="no">
    <i class="q q1"><b class="v"></b></i>
    <i class="q q2"><b class="v"></b></i>
    <i class="q q3"><b class="v"></b></i>
    <i class="q q4"><b class="v"></b></i>
    <i class="q q5"><b class="v"></b></i>
    <i class="q q6"><b class="v"></b></i>
    <i class="q q7"><b class="v"></b></i>
  </span>`,
  compoMini: `<span class="nom-g">
    <i class="qm qm1"><b class="vm"></b></i>
    <i class="qm qm2"><b class="vm"></b></i>
    <i class="qm qm3"><b class="vm"></b></i>
    <i class="qm qm4"><b class="vm"></b></i>
  </span>`,
  css: `
.p-note .no{ display:flex; align-items:center; gap:4.5px; height:30px; }
.p-note .q{ display:block; position:relative; width:2.5px; height:21px; border-radius:1.6px;
  background:linear-gradient(180deg,
    rgba(255,255,255,.14) 0%, rgba(255,255,255,.46) 22%,
    rgba(255,255,255,.92) 50%,
    rgba(255,255,255,.46) 78%, rgba(255,255,255,.14) 100%);
  will-change:transform; }
.p-note .q1{ animation:note-d1 5.3s cubic-bezier(.45,.05,.55,.95) -1.2s infinite alternate; }
.p-note .q2{ animation:note-d2 6.7s cubic-bezier(.45,.05,.55,.95) -3.1s infinite alternate; }
.p-note .q3{ animation:note-d3 4.9s cubic-bezier(.45,.05,.55,.95) -0.7s infinite alternate; }
.p-note .q4{ animation:note-d1 7.7s cubic-bezier(.45,.05,.55,.95) -5.3s infinite alternate; }
.p-note .q5{ animation:note-d2 5.9s cubic-bezier(.45,.05,.55,.95) -2.3s infinite alternate; }
.p-note .q6{ animation:note-d3 6.3s cubic-bezier(.45,.05,.55,.95) -4.1s infinite alternate; }
.p-note .q7{ animation:note-d1 5.1s cubic-bezier(.45,.05,.55,.95) -1.9s infinite alternate; }
@keyframes note-d1{ 0%{transform:scaleY(.30)} 34%{transform:scaleY(.82)} 58%{transform:scaleY(.44)} 100%{transform:scaleY(.94)} }
@keyframes note-d2{ 0%{transform:scaleY(.72)} 26%{transform:scaleY(.34)} 52%{transform:scaleY(.22)} 64%{transform:scaleY(.22)} 100%{transform:scaleY(.88)} }
@keyframes note-d3{ 0%{transform:scaleY(.52)} 40%{transform:scaleY(.96)} 72%{transform:scaleY(.38)} 100%{transform:scaleY(.70)} }
/* le cœur violet + son souffle au sol : la même opacité pilote les deux */
.p-note .v{ position:absolute; inset:0; border-radius:inherit; display:block; opacity:0;
  background:linear-gradient(180deg,
    rgba(165,139,255,.10) 0%, rgba(165,139,255,.55) 24%,
    rgba(133,93,255,1) 50%,
    rgba(165,139,255,.55) 76%, rgba(165,139,255,.10) 100%);
  box-shadow:0 9px 12px -2px rgba(133,93,255,.45), 0 0 7px rgba(133,93,255,.35);
  will-change:opacity; }
/* la promenade : 41,3 s, ordre 4 → 5 → 3 → 6 → 2 → 7 → 1 */
.p-note .q4 .v{ animation:note-s0 41.3s linear infinite; }
.p-note .q5 .v{ animation:note-s1 41.3s linear infinite; }
.p-note .q3 .v{ animation:note-s2 41.3s linear infinite; }
.p-note .q6 .v{ animation:note-s3 41.3s linear infinite; }
.p-note .q2 .v{ animation:note-s4 41.3s linear infinite; }
.p-note .q7 .v{ animation:note-s5 41.3s linear infinite; }
.p-note .q1 .v{ animation:note-s6 41.3s linear infinite; }
@keyframes note-s0{ 0%{opacity:0} 1.6%{opacity:1} 12.7%{opacity:1} 14.3%{opacity:0} 100%{opacity:0} }
@keyframes note-s1{ 0%,14.3%{opacity:0} 15.9%{opacity:1} 27.0%{opacity:1} 28.6%{opacity:0} 100%{opacity:0} }
@keyframes note-s2{ 0%,28.6%{opacity:0} 30.2%{opacity:1} 41.3%{opacity:1} 42.9%{opacity:0} 100%{opacity:0} }
@keyframes note-s3{ 0%,42.9%{opacity:0} 44.5%{opacity:1} 55.6%{opacity:1} 57.2%{opacity:0} 100%{opacity:0} }
@keyframes note-s4{ 0%,57.2%{opacity:0} 58.8%{opacity:1} 69.9%{opacity:1} 71.5%{opacity:0} 100%{opacity:0} }
@keyframes note-s5{ 0%,71.5%{opacity:0} 73.1%{opacity:1} 84.2%{opacity:1} 85.8%{opacity:0} 100%{opacity:0} }
@keyframes note-s6{ 0%,85.8%{opacity:0} 87.4%{opacity:1} 98.4%{opacity:1} 100%{opacity:0} }

.p-note .nom-g{ display:flex; align-items:center; gap:3.6px; height:22px; }
.p-note .qm{ display:block; position:relative; width:2.6px; height:17px; border-radius:1.6px;
  background:linear-gradient(180deg, rgba(255,255,255,.16), rgba(255,255,255,.86) 50%, rgba(255,255,255,.16));
  will-change:transform; }
.p-note .qm1{ animation:note-d3 4.9s cubic-bezier(.45,.05,.55,.95) -0.7s infinite alternate; }
.p-note .qm2{ animation:note-d1 5.3s cubic-bezier(.45,.05,.55,.95) -2.9s infinite alternate; }
.p-note .qm3{ animation:note-d2 5.9s cubic-bezier(.45,.05,.55,.95) -1.1s infinite alternate; }
.p-note .qm4{ animation:note-d3 6.7s cubic-bezier(.45,.05,.55,.95) -4.7s infinite alternate; }
.p-note .vm{ position:absolute; inset:0; border-radius:inherit; display:block; opacity:0;
  background:linear-gradient(180deg, rgba(165,139,255,.2), rgba(133,93,255,1) 50%, rgba(165,139,255,.2));
  box-shadow:0 0 5px rgba(133,93,255,.4); will-change:opacity; }
.p-note .qm2 .vm{ animation:note-mm0 23.6s linear infinite; }
.p-note .qm4 .vm{ animation:note-mm1 23.6s linear infinite; }
.p-note .qm1 .vm{ animation:note-mm2 23.6s linear infinite; }
.p-note .qm3 .vm{ animation:note-mm3 23.6s linear infinite; }
@keyframes note-mm0{ 0%{opacity:0} 2.8%{opacity:1} 22.2%{opacity:1} 25%{opacity:0} 100%{opacity:0} }
@keyframes note-mm1{ 0%,25%{opacity:0} 27.8%{opacity:1} 47.2%{opacity:1} 50%{opacity:0} 100%{opacity:0} }
@keyframes note-mm2{ 0%,50%{opacity:0} 52.8%{opacity:1} 72.2%{opacity:1} 75%{opacity:0} 100%{opacity:0} }
@keyframes note-mm3{ 0%,75%{opacity:0} 77.8%{opacity:1} 97.2%{opacity:1} 100%{opacity:0} }
.p-note .gros{ transform:scale(3.0); }
`,
},

/* ═══════════════ 6. LE TRIO ═══════════════
   L'extrême minimal : trois lames seulement, larges, très lentes, en
   canon (la même phrase jouée à un temps d'écart), leur reflet laqué
   dessous et un souffle de halo derrière. Le geste AirPods. */
{
  id: 'trio',
  nom: 'Le Trio',
  cout: 'léger',
  pitch: "Trois lames seulement — larges, très lentes, jouant la même phrase en canon à un temps d'écart, comme trois voix. Leur reflet respire sur le laqué, un halo discret respire derrière, et rien d'autre : c'est le geste le plus minimal de la famille, celui qui fait le plus confiance au silence.",
  swift: "Trois Capsule() + le MÊME keyframe décalé de −0,8 s et −1,6 s (le canon est gratuit : une seule f(t), trois phases), reflet en scaleEffect(y:-1)+opacité, halo = RadialGradient en opacité f(t). Un TimelineView scoped, paused sur enMouvement. Le moins d'encre de toute la page.",
  compo: `<span class="tr">
    <span class="halo"></span>
    <i class="tt t1"></i><i class="tt t2"></i><i class="tt t3"></i>
  </span>`,
  compoMini: `<span class="trm">
    <i class="tm tm1"></i><i class="tm tm2"></i><i class="tm tm3"></i>
  </span>`,
  css: `
.p-trio .tr{ position:relative; display:flex; align-items:center; gap:9px; height:34px; }
.p-trio .halo{ position:absolute; left:50%; top:50%; width:74px; height:44px;
  margin:-22px 0 0 -37px; border-radius:50%;
  background:radial-gradient(50% 50% at 50% 46%,
    rgba(255,255,255,.10) 0%, rgba(233,228,255,.05) 42%, rgba(165,139,255,.02) 62%, transparent 78%);
  animation:trio-halo 9.7s ease-in-out infinite alternate; will-change:opacity,transform; }
@keyframes trio-halo{ from{opacity:.45; transform:scale(.92)} to{opacity:1; transform:scale(1.06)} }
.p-trio .tt{ display:block; position:relative; width:3.5px; height:24px; border-radius:2px;
  background:linear-gradient(180deg,
    rgba(255,255,255,.20) 0%, rgba(255,255,255,.55) 20%,
    rgba(255,255,255,.98) 50%,
    rgba(255,255,255,.55) 80%, rgba(255,255,255,.20) 100%);
  will-change:transform; }
.p-trio .tt::after{ content:""; position:absolute; top:calc(100% + 4px); left:0; right:0; height:52%;
  border-radius:inherit; filter:blur(.6px);
  background:linear-gradient(180deg, rgba(255,255,255,.17), rgba(255,255,255,0) 80%); }
/* le canon : la MÊME phrase, à un temps d'écart */
.p-trio .t1{ animation:trio-phrase 8.9s cubic-bezier(.45,.05,.55,.95) -0.8s infinite alternate; }
.p-trio .t2{ animation:trio-phrase 8.9s cubic-bezier(.45,.05,.55,.95)  0s   infinite alternate; filter:brightness(1.10); }
.p-trio .t3{ animation:trio-phrase 8.9s cubic-bezier(.45,.05,.55,.95) -1.6s infinite alternate; }
@keyframes trio-phrase{
  0%{transform:scaleY(.30)} 26%{transform:scaleY(.88)} 46%{transform:scaleY(.52)}
  62%{transform:scaleY(.52)} 82%{transform:scaleY(.98)} 100%{transform:scaleY(.38)} }

.p-trio .trm{ display:flex; align-items:center; gap:5.5px; height:22px; }
.p-trio .tm{ display:block; width:3px; height:16px; border-radius:1.8px;
  background:linear-gradient(180deg, rgba(255,255,255,.2), rgba(255,255,255,.95) 50%, rgba(255,255,255,.2));
  will-change:transform; }
.p-trio .tm1{ animation:trio-phrase 8.9s cubic-bezier(.45,.05,.55,.95) -0.8s infinite alternate; }
.p-trio .tm2{ animation:trio-phrase 8.9s cubic-bezier(.45,.05,.55,.95)  0s   infinite alternate; }
.p-trio .tm3{ animation:trio-phrase 8.9s cubic-bezier(.45,.05,.55,.95) -1.6s infinite alternate; }
.p-trio .gros{ transform:scale(3.0); }
`,
},
]
