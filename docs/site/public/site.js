/* ─────────────────────────────────────────────────────────────
   Le seul script du site — vanilla, inliné dans le livrable.
   Il n'écrit JAMAIS un état : tout est calculé à la build. Il fait
   les onglets, le tiroir mobile, les filtres de l'accueil, la lampe
   de l'obsidienne, l'arrivée (une fois), et le témoin du compte.
   ───────────────────────────────────────────────────────────── */
(function () {
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

  /* ── l'accueil : filtres + clic d'une rangée ─────────────── */
  var etat = document.getElementById('etat');
  if (etat) {
    var rangees = q('.liste li.r', etat), groupes = q('.liste li.grp', etat);
    var fE = {}, fD = {};
    function vide(o) { for (var k in o) if (o[k]) return false; return true; }
    function appliquer() {
      rangees.forEach(function (li) {
        var ok = (vide(fE) || fE[li.dataset.etat]) && (vide(fD) || fD[li.dataset.dom]);
        li.hidden = !ok;
      });
      groupes.forEach(function (g) {
        var k = g.dataset.grp, vis = rangees.filter(function (li) { return li.dataset.etat === k && !li.hidden; }).length;
        g.hidden = !vis; var n = g.querySelector('.n'); if (n) n.textContent = vis;
      });
      q('[data-f]').forEach(function (b) {
        var f = b.dataset.f, on = false;
        if (f === '*') on = vide(fE) && vide(fD);
        else if (f.indexOf('etat:') === 0) on = !!fE[f.slice(5)];
        else if (f.indexOf('dom:') === 0) on = !!fD[f.slice(4)];
        b.classList.toggle('on', on);
      });
    }
    q('[data-f]').forEach(function (b) {
      b.addEventListener('click', function () {
        var f = b.dataset.f;
        if (f === '*') { fE = {}; fD = {}; }
        else if (f.indexOf('etat:') === 0) { var k = f.slice(5); fE[k] = !fE[k]; }
        else if (f.indexOf('dom:') === 0) { var d = f.slice(4); fD[d] = !fD[d]; }
        appliquer();
      });
    });
    appliquer();
    rangees.forEach(function (li) {
      li.addEventListener('click', function () {
        var o = li.dataset.onglet, src = li.dataset.src;
        if (!o || !montrer(o, true)) return;
        var s = src && document.getElementById(src);
        if (!s) return;
        setTimeout(function () {
          s.scrollIntoView({ block: 'center' });
          s.classList.add('vise');
          setTimeout(function () { s.classList.add('fin'); }, 1200);
          setTimeout(function () { s.classList.remove('vise', 'fin'); }, 2600);
        }, 60);
      });
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
})();
