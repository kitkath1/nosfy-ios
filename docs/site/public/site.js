/* ─────────────────────────────────────────────────────────────
   Le seul script du site — vanilla, inliné dans le livrable.
   Il n'écrit JAMAIS un état : tout est calculé à la build. Il fait
   les onglets, le tiroir mobile, les filtres de l'accueil, la lampe
   de l'obsidienne, l'arrivée (une fois), et le témoin du compte.
   ───────────────────────────────────────────────────────────── */
(function () {
  function init() {
  var q = function (sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); };
  document.documentElement.classList.add('js');

  /* ── les onglets ─────────────────────────────────────────── */
  var pages = q('.page'), liens = q('.rail a.item');
  function montrer(id, pousser) {
    var trouve = false;
    pages.forEach(function (p) { var on = p.id === id; p.classList.toggle('on', on); if (on) trouve = true; });
    if (!trouve) return false;
    liens.forEach(function (a) { a.classList.toggle('on', a.dataset.p === id); });
    var actif = liens.filter(function (a) { return a.dataset.p === id; })[0];
    var titre = document.querySelector('.barre [data-titre]');
    if (titre && actif) titre.textContent = (actif.querySelector('.lib') || actif).textContent.trim();
    document.body.classList.remove('tiroir');
    if (pousser) { try { history.replaceState(null, '', '#' + id); } catch (e) {} }
    window.scrollTo(0, 0);
    return true;
  }
  liens.forEach(function (a) { a.addEventListener('click', function (e) { e.preventDefault(); montrer(a.dataset.p, true); }); });
  q('[data-saut]').forEach(function (a) { a.addEventListener('click', function (e) { e.preventDefault(); montrer(a.dataset.saut, true); }); });
  window.WoopNav = { montrer: montrer };

  /* ── le tiroir (≤ 900 px) ─────────────────────────────────── */
  var bouton = document.querySelector('[data-tiroir]'), voile = document.querySelector('[data-voile]');
  if (bouton) bouton.addEventListener('click', function () { document.body.classList.toggle('tiroir'); });
  if (voile) voile.addEventListener('click', function () { document.body.classList.remove('tiroir'); });

  /* ── l'accueil : les quatre compteurs filtrent, deux groupes se plient, une rangée ouvre sa page ──
     Une rangée porte `data-fam` (à trancher · à valider · en chantier · bon — posé par Rangee à la build,
     content/index.ts `famille`) et `data-etat` (les cinq états + nm). Un groupe = une famille. Un groupe
     `data-plie` (en chantier · bon) naît FERMÉ : une ligne et son compte ; le clic (ou le compteur de sa
     famille) le déplie — 30-08, « trop de pilules, on sait pas quoi faire ». */
  var etat = document.getElementById('etat');
  if (etat) {
    var rangees = q('.liste li.r', etat), groupes = q('.liste li.grp', etat), rien = etat.querySelector('.liste .rien-a-faire');
    var fF = {}, fD = {}, plie = {};
    groupes.forEach(function (g) { if (g.hasAttribute('data-plie')) plie[g.dataset.grp] = true; });
    function vide(o) { for (var k in o) if (o[k]) return false; return true; }
    function appliquer() {
      var visibles = 0, parFam = {};
      rangees.forEach(function (li) {
        var fam = li.dataset.fam;
        var ok = (vide(fF) || fF[fam]) && (vide(fD) || fD[li.dataset.dom]);
        var ferme = !!plie[fam] && !fF[fam];   /* un compteur choisi déplie sa famille */
        li.hidden = !ok || ferme;
        if (ok) { visibles++; parFam[fam] = (parFam[fam] || 0) + 1; }
      });
      groupes.forEach(function (g) {
        var k = g.dataset.grp, n = parFam[k] || 0;
        g.hidden = !n; g.classList.toggle('ferme', !!plie[k] && !fF[k]);
        var e = g.querySelector('.n'); if (e) e.textContent = n;
      });
      if (rien) rien.hidden = visibles > 0;
      /* un filtre posé se VOIT et se défait : `body.filtre` fait apparaitre « tout voir » (v2.css) —
         sans ça, un clic curieux sur « 46 bon » vidait la page sans dire comment revenir. */
      document.body.classList.toggle('filtre', !vide(fF) || !vide(fD));
      q('[data-f]').forEach(function (b) {
        var f = b.dataset.f, on = false;
        if (f === '*') on = vide(fF) && vide(fD);
        else if (f.indexOf('fam:') === 0) on = !!fF[f.slice(4)];
        else if (f.indexOf('dom:') === 0) on = !!fD[f.slice(4)];
        if (f !== '*') b.classList.toggle('on', on);
      });
    }
    q('[data-f]').forEach(function (b) {
      b.addEventListener('click', function () {
        var f = b.dataset.f;
        if (f === '*') { fF = {}; fD = {}; }
        else if (f.indexOf('fam:') === 0) { var k = f.slice(4); fF[k] = !fF[k]; }
        else if (f.indexOf('dom:') === 0) { var d = f.slice(4); fD[d] = !fD[d]; }
        appliquer();
      });
    });
    groupes.forEach(function (g) {
      if (!g.hasAttribute('data-plie')) return;
      function bascule() { var k = g.dataset.grp; plie[k] = !plie[k]; appliquer(); }
      g.addEventListener('click', bascule);
      g.addEventListener('keydown', function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); bascule(); } });
    });
    appliquer();
    function viser(o, src) {
      if (!o || !montrer(o, true)) return;
      var s = src && document.getElementById(src);
      if (!s) return;
      setTimeout(function () {
        s.scrollIntoView({ block: 'center' });
        s.classList.add('vise');
        setTimeout(function () { s.classList.add('fin'); }, 1200);
        setTimeout(function () { s.classList.remove('vise', 'fin'); }, 2600);
      }, 60);
    }
    q('[data-aller]', etat).forEach(function (b) {
      b.addEventListener('click', function () { viser(b.dataset.onglet, b.dataset.aller); });
    });
    rangees.forEach(function (li) {
      li.addEventListener('click', function () { viser(li.dataset.onglet, li.dataset.src); });
    });
    q('.dom[data-onglet]', etat).forEach(function (c) {
      c.addEventListener('click', function (e) { e.preventDefault(); montrer(c.dataset.onglet, true); });
    });

    /* le témoin : le livrable est généré ; si quelqu'un l'a édité à la main, le compte diverge et ça se voit */
    var attendu = parseInt(etat.dataset.attendu, 10) || 0;
    var total = q('.page:not(#etat) .p').filter(function (p) { return /\bp-(ok|loc|srv|abs|men)\b/.test(p.className); }).length;
    var alerte = etat.querySelector('.alerte');
    if (alerte && attendu && total !== attendu) { alerte.textContent = '⚠ ' + total + ' ≠ ' + attendu + ' attendues'; alerte.classList.add('on'); }
  }

  /* ── l'obsidienne : la lampe suit le pouce (un centre de dégradé, jamais un flou) ── */
  var calme = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  q('.obs').forEach(function (b) {
    if (calme) return;
    b.addEventListener('pointermove', function (e) { var r = b.getBoundingClientRect(); b.style.setProperty('--mx', (e.clientX - r.left) + 'px'); });
    b.addEventListener('pointerleave', function () { b.style.removeProperty('--mx'); });
  });

  /* ── l'arrivée : une fois, 1,5 s, jamais au changement d'onglet ── */
  document.body.classList.add('entree');
  setTimeout(function () { document.body.classList.remove('entree'); }, 1500);
  if (!calme && 'IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); } });
    }, { threshold: 0.2 });
    q('.reveal').forEach(function (el) { io.observe(el); });
  } else { q('.reveal').forEach(function (el) { el.classList.add('in'); }); }

  /* ── l'amorce ─────────────────────────────────────────────── */
  var depart = (location.hash || '').replace('#', '');
  if (!depart || !montrer(depart, false)) montrer('etat', false);
  }

  /* ── le départ : une fois, et JAMAIS avant l'hydratation de React ──
     Quand Next est présent (next dev, out/), React compare le HTML servi au DOM ; un
     `.in` ou un `.on` posé avant lui = un décalage signalé. components/Boot.tsx appelle
     window.woopInit après l'hydratation. Dans le fichier unique, l'inliner a retiré tout
     script Next : on démarre tout de suite. */
  function demarrer() { if (demarrer.fait) return; demarrer.fait = true; init(); }
  var next = !!window.__next_f || !!document.querySelector('script[src*="_next/"]')  /* sans barre initiale : cette chaîne-là est interdite dans le livrable (inliner) */;
  if (next) { window.woopInit = demarrer; if (window.__woopHydrate) demarrer(); }
  else demarrer();
})();
