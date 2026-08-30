#!/bin/zsh
# Vérifie le site de doc v2 AVANT de commiter — et ne l'ÉCRIT jamais.
#
#   ./tools/docsite/verifier.sh                  # tout (≈ 1 min : plus de CDN à attendre)
#   ./tools/docsite/verifier.sh --sans-captures  # sans Chrome ni sondes (le rapide)
#
# Le livrable docs/site/index.html est produit par `npm run artefact` (next build +
# scripts/inliner.mjs). Ici on le REBÂTIT à côté (out/livrable-verif.html) et on le
# compare octet pour octet au fichier commité : s'ils diffèrent, le livrable ment par
# retard, ou le build n'est pas déterministe — dans les deux cas on refuse.
# Dans l'ordre : le retard (mtime) · tsc · tests/contenu · next build · l'inliner et la
# comparaison · vitest (l'invariant sur le livrable) · la robe au grep · les captures
# (puppeteer + le Chrome installé, viewport MESURÉ — à REGARDER) · les sondes PIL du hero ·
# la largeur à 390 (scrollWidth des 7 pages).
# Sortie lisible ; exit 1 au PREMIER échec. L'ancienne version : verifier-v1.sh.
set -e
export LC_ALL=en_US.UTF-8
cd "$(dirname "$0")/../.."
RACINE=$PWD
SITE=docs/site
LIVRABLE=$SITE/index.html
REBATI=$SITE/out/livrable-verif.html
CAPTURES=tools/docsite/captures
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"   # sans --user-data-dir : Chrome sans tête prend son profil temporaire, et un profil imposé le BLOQUE (mesuré : > 3 min contre 4 s)
PAGES=(etat porte)                      # les pages capturées, par leur hash
SANS_CAPTURES=0; [[ " $* " == *" --sans-captures "* ]] && SANS_CAPTURES=1
typeset -i DEBUT=$SECONDS

etape(){ print "\n── $1" }
ok(){ print "   ✔ $1" }
ko(){ print -u2 "   ✗ $1"; print -u2 "\n✗ refusé après $((SECONDS - DEBUT)) s"; exit 1 }
compteF(){ grep -oF -- "$1" "$LIVRABLE" | wc -l | tr -d ' ' }     # occurrences d'une chaîne (0 sans erreur)
compteE(){ grep -oE -- "$1" "$LIVRABLE" | wc -l | tr -d ' ' }     # occurrences d'un motif
borne(){ # borne "libellé" valeur op attendu — op : = ≤ <
  local lib=$1 v=$2 op=$3 a=$4 bon=0
  case $op in
    '=') [ "$v" -eq "$a" ] && bon=1 ;;
    '≤') [ "$v" -le "$a" ] && bon=1 ;;
    '<') [ "$v" -lt "$a" ] && bon=1 ;;
  esac
  if [ $bon = 1 ]; then ok "$lib : $v (attendu $op $a)"; else ko "$lib : $v (attendu $op $a)"; fi
}

etape "0. les prérequis"
[ -d $SITE/node_modules ] || ko "node_modules absent : (cd $SITE && npm ci)"
node -e 'process.exit(parseInt(process.versions.node, 10) >= 24 ? 0 : 1)' 2>/dev/null || ko "Node ≥ 24 requis (.nvmrc) — $(node --version 2>/dev/null || print 'node absent')"
[ -f $LIVRABLE ] || ko "pas de livrable $LIVRABLE : (cd $SITE && npm run artefact)"
if [ $SANS_CAPTURES = 0 ]; then
  [ -x "$CHROME" ] || ko "Chrome introuvable : $CHROME"
  python3 -c 'import PIL' 2>/dev/null || ko "PIL absent pour python3 (les sondes)"
fi
ok "node $(node --version) · Chrome $([ $SANS_CAPTURES = 0 ] && print 'présent' || print 'ignoré (--sans-captures)')"

etape "1. le retard — le livrable est-il plus vieux que sa source ?"
SOURCES=($SITE/content $SITE/app $SITE/components $SITE/public $SITE/fonts $SITE/scripts $SITE/next.config.ts)
retard=$(find ${SOURCES[@]} -type f -newer $LIVRABLE 2>/dev/null | grep -v '/\.' | head -5)
if [ -n "$retard" ]; then
  print -- "$retard" | sed 's/^/     plus récent : /'
  ko "le livrable ment par retard — (cd $SITE && npm run artefact), puis reviens ici"
fi
ok "index.html est plus récent que content/ app/ components/ public/ fonts/ scripts/"

etape "2. tsc --noEmit — une brique sans preuve ne compile pas"
(cd $SITE && npm run -s typecheck) || ko "le type refuse"
ok "types"

etape "3. la source — tests/contenu (ids, titres, preuves qui se lisent, SVG à jour)"
(cd $SITE && npx vitest run tests/contenu.test.ts) || ko "la source ment"

etape "4. next build (export statique → $SITE/out/)"
(cd $SITE && npm run -s build) || ko "next build a échoué"
[ -f $SITE/out/index.html ] || ko "pas de $SITE/out/index.html après le build"
ok "out/index.html"

etape "5. l'inliner — rebâti à côté, comparé au livrable"
(cd $SITE && node scripts/inliner.mjs --out out/livrable-verif.html) || ko "l'inliner refuse"
if cmp -s $REBATI $LIVRABLE; then
  ok "identique octet pour octet : le livrable EST le build (frais, déterministe)"
else
  print "     rebâti $(wc -c < $REBATI | tr -d ' ') o · livrable $(wc -c < $LIVRABLE | tr -d ' ') o · $(cmp $REBATI $LIVRABLE 2>&1 | head -1)"
  ko "le livrable ≠ le build : il ment par retard (npm run artefact) ou le build n'est pas déterministe (deux runs de npm run artefact, puis git diff --stat)"
fi

etape "6. vitest — l'invariant des pastilles et la robe, sur le livrable"
(cd $SITE && npx vitest run) || ko "le livrable ment"

etape "7. la robe et l'autonomie, au grep sur $LIVRABLE"
borne "emoji dans un h1/h2/h3" $(compteE '<h[123][^>]*>[^<]*[🟢🟡🔵⚪🔴🧨🧭🚩⛔⚠️🎴⏱️⏳🧗◌⚑]') '=' 0
# La robe se juge sur la PAGE, hors des SVG pré-rendus (même sémantique que tests/invariant) ; ce que les
# SVG portent en plus (la feuille Mermaid : bold/bolder, `dash`, `edge-animation-frame`) est DIT, pas refusé —
# c'est à scripts/schemas.mjs de l'alléger.
sansSvg=$(perl -0pe 's/<svg\b.*?<\/svg>//gs' $LIVRABLE)
graisses=$(print -r -- "$sansSvg" | grep -oE 'font-weight:\s*[0-9]+' | sed 's/font-weight://' | sort -u | tr '\n' ' ')
hors=$(print -r -- "$sansSvg" | grep -oE '.{0,50}font-weight:\s*[a-z0-9]+' | grep -vE 'font-weight:\s*(300|400|500|600)$' | sort -u || true)
if [ -z "$hors" ]; then ok "graisses de la page : ${graisses}(⊆ 300 400 500 600)"; else print -r -- "$hors" | head -4 | sed 's/^/     …/'; ko "graisses hors robe (bold/bolder/normal/700…)"; fi
horsSvg=$(grep -oE 'font-weight:\s*[a-z0-9]+' $LIVRABLE | grep -vE 'font-weight:\s*(300|400|500|600)$' | sort | uniq -c | sort -rn | tr -s ' ' | tr '\n' ';' || true)
[ -n "$horsSvg" ] && print "   ⚠ dans les SVG, hors robe (à alléger dans schemas.mjs) :$horsSvg"
kfSite=$(print -r -- "$sansSvg" | grep -oF '@keyframes' | wc -l | tr -d ' '); kfTotal=$(compteF '@keyframes')
borne "@keyframes de la page (arrive · allume · reveal)" $kfSite '≤' 3
[ $((kfTotal - kfSite)) -gt 0 ] && print "   ⚠ $((kfTotal - kfSite)) @keyframes dans les SVG ($(perl -0ne 'while(/<svg\b.*?<\/svg>/gs){my $s=$&;while($s=~/\@keyframes ([\w-]+)/g){$n{$1}++}} print join(" ",sort keys %n)' $LIVRABLE) — boilerplate Mermaid, à retirer dans schemas.mjs)"
borne "backdrop-filter (règles, hors -webkit-)" $(compteE '(^|[^-])backdrop-filter:') '≤' 4
familles=$(grep -oE 'font-family:[^;}"]+' $LIVRABLE | sort -u)
etrangeres=$(print -r -- "$familles" | grep -viE '^font-family:\s*(var\(--(sans|mono)\)|Inter([^a-zA-Z]|$)|-apple-system|ui-monospace|"SF Mono"|Menlo|monospace|system-ui)' || true)
if [ -z "$etrangeres" ]; then ok "familles : $(print -r -- "$familles" | grep -c . ) formes, toutes Inter ou mono système"; else ko "famille étrangère : $(print -r -- "$etrangeres" | head -3 | tr '\n' ' ')"; fi
borne "dates relatives (depuis/posé/réparé aujourd'hui, ce matin)" $(compteE "depuis aujourd|pos[ée]e? aujourd|répar[ée]e? aujourd|ce matin") '=' 0
borne "%%{init" $(compteF '%%{init') '=' 0
borne "classDef" $(compteE '(^|[^A-Za-z0-9_])classDef([^A-Za-z0-9_]|$)') '=' 0
borne "/_next/" $(compteF '/_next/') '=' 0
borne "<script" $(compteF '<script') '≤' 1
borne "cdn." $(compteF 'cdn.') '=' 0
borne "transition sur un filtre" $(compteE 'transition:[^;{}]*filter') '=' 0
borne "poids (o)" $(wc -c < $LIVRABLE | tr -d ' ') '<' 2000000

if [ $SANS_CAPTURES = 1 ]; then
  print "\n✔ tout est vert (sans captures ni sondes) en $((SECONDS - DEBUT)) s"
  exit 0
fi

etape "8. les captures Chrome sans tête (à REGARDER, pas à supposer) → $CAPTURES/"
mkdir -p $CAPTURES
U="file://$RACINE/$LIVRABLE"
# Par puppeteer, jamais `chrome --screenshot` : à --window-size=390 le Chrome installé met en page
# plus large (largeur de fenêtre minimale) et ROGNE le PNG — une capture « 390 » qui n'en est pas une.
for l in 1440 390; do
  (cd $RACINE/docs/site && node scripts/capturer.mjs "$RACINE/$CAPTURES" "$U" $l $PAGES) || ko "capture à $l refusée"
done
for p in $PAGES; do for l in 1440 390; do [ -s "$CAPTURES/$p-$l.png" ] || ko "capture vide : $p-$l"; done; done
# Plus de `chrome --dump-dom` : en v2 les compteurs sont calculés à la build, ils se lisent dans le
# livrable. (Et un Chrome sans --user-data-dir attend le verrou du profil sans fin dès qu'un Chrome
# sans tête fantôme traîne — payé le 30-08 : 10 min de blocage.)
print "   $(grep -o 'id="etat"[^>]*' $LIVRABLE | head -1) · $(grep -o 'data-f="etat:' $LIVRABLE | wc -l | tr -d ' ') compteurs statiques"

etape "9. les sondes PIL — le hero de Compte à 1440 (la teinte meurt dans le noir, rien ne bave dessous)"
python3 - "$CAPTURES/porte-1440.png" "$LIVRABLE" <<'PY' || ko "sonde du hero"
import sys
from PIL import Image, ImageChops
capture, livrable = sys.argv[1], sys.argv[2]
html = open(livrable, encoding='utf-8').read()
if 'class="hero-dom' not in html:
    print('   ○ pas de .hero-dom dans le livrable : sondes du hero sautées'); sys.exit(0)
im = Image.open(capture).convert('RGB'); W, H = im.size; px = im.load()
RAIL, HERO, SEUIL = 260, 400, 40   # rail exclu (x < 260) ; hero = 400 px à ≥ 901 px (plan v2 §3.1) ; ≤ 40 px saturés par ligne = des billes et des emoji, jamais un aplat
xc = W // 2
# le masque des pixels COLORÉS : S > .30 et V > .25 (la même loi que palette.py)
_, S, V = im.convert('HSV').split()
masque = ImageChops.multiply(S.point(lambda s: 255 if s > 76 else 0), V.point(lambda v: 255 if v > 64 else 0))
def noir(p, tol=4): return max(p) <= tol
# 1. le haut du hero = la première ligne (y ≥ 80) dont le pixel à 50 % est coloré ; le bas = haut + 400
colonne = list(masque.crop((xc, 80, xc + 1, min(H, 1000))).getdata())
haut = next((80 + i for i, v in enumerate(colonne) if v), None)
if haut is None:
    bas = 700
    print('   ○ aucune teinte à x=%d (hero noir ?) : bas posé à %d, sonde du noir sautée' % (xc, bas))
else:
    bas = haut + HERO
    # (a) à 95 % du hero et 12 px sous lui : NOIR (#000 ± 4) — la teinte meurt dans le noir
    for y in (bas - 20, bas + 12):
        p = px[xc, y]
        if not noir(p):
            print('   ✗ (%d, %d) = #%02X%02X%02X, attendu #000 ± 4 : la teinte ne meurt pas dans le noir' % (xc, y, p[0], p[1], p[2])); sys.exit(1)
    # (b) les rangées de la bordure basse (bas-3 … bas+2) : GRISES, jamais teintées — un dégradé de fond qui se
    #     répète sous la bordure (background-origin padding-box) y laisse un trait de couleur d'un pixel
    for y in range(bas - 3, bas + 3):
        if masque.getpixel((xc, y)):
            p = px[xc, y]
            print('   ✗ (%d, %d) = #%02X%02X%02X : la bordure basse du hero est TEINTÉE (le fond se répète sous la bordure — background-origin:border-box, ou background-clip:padding-box)' % (xc, y, p[0], p[1], p[2])); sys.exit(1)
    print('   ✔ hero de y=%d à %d : (%d, %d) et (%d, %d) sont noirs (#000 ± 4), la bordure basse est grise' % (haut, bas, xc, bas - 20, xc, bas + 12))
# 2. sous le hero (bordure comprise), aucune LIGNE teintée hors du rail
pire = (0, None)
for y in range(max(bas - 3, 0), H):
    n = masque.crop((RAIL, y, W, y + 1)).histogram()[255]
    if n > pire[0]: pire = (n, y)
if pire[0] > SEUIL:
    n, y = pire
    x = RAIL + masque.crop((RAIL, y, W, y + 1)).getbbox()[0]; p = px[x, y]
    print('   ✗ ligne y=%d : %d pixels saturés hors rail (> %d), ex. (%d, %d) = #%02X%02X%02X — de la couleur sous le hero' % (y, n, SEUIL, x, y, p[0], p[1], p[2])); sys.exit(1)
print('   ✔ sous y=%d : au pire %d pixel(s) saturé(s) par ligne hors rail (≤ %d)' % (max(bas - 3, 0), pire[0], SEUIL))
PY

etape "10. la largeur à 390 — aucune des 7 pages ne défile de côté (scrollWidth = 390, mesuré page affichée)"
# La largeur du PNG ne prouve rien (--window-size la fixe) : un document de 795 px se capture à 390 et
# Chrome y met en page les rangées à 795 — les titres partent sous le bord sans points de suspension.
(cd $RACINE/docs/site && node scripts/largeur.mjs index.html) || ko "une page déborde à 390"

print "\n✔ tout est vert en $((SECONDS - DEBUT)) s — REGARDE $CAPTURES/*.png avant de commiter"
