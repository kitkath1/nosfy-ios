#!/bin/zsh
# LE RECUT DU THÈME POUR LA LUNE DE SANG — § 2 de PLAN-V7-DOUCEUR.md.
#
# Verdict Kathryn (26-08) : « le son de la lune de sang ! avant il y avait
# quelque chose ! ». Elle a raison, et rien n'avait été supprimé :
# `Woop/Sounds/MoonSplashTheme.m4a` (15,556 s) est intact dans le dépôt, et sa
# classe `MoonTheme` (RocketHaptics.swift) est complète — volume, mixage
# `.ambient`, fondu de sortie. Simplement, elle n'est appelée QUE depuis
# `MoonSplash.swift`, le plan-séquence de 13,95 s mis en archive : le jour où
# la Lune de Sang est devenue le splash, le thème est devenu ORPHELIN.
# Exactement le sort des corbeaux.
#
# ⚠️ ON NE RE-SYNTHÉTISE RIEN. Les scripts d'origine (`moonmusic5.py`) n'ont
# jamais été commités et sont perdus avec le scratchpad de leur session. On
# COUPE dans le fichier existant — la même loi que le recuit des vidéos.
#
# ⚠️ ET ON N'ÉCRASE PAS LA SOURCE : `MoonSplashTheme.m4a` reste tel quel,
# l'archive `-moonSplashLab` le joue encore en entier. On écrit un fichier
# NEUF.
#
# ── LA FORME DU THÈME, MESURÉE (RMS 10 ms) ─────────────────────────────────
#   0,00 → 1,00   silence
#   1,00 → 6,30   la montée (le bourdon qui enfle)
#   6,300         ★ L'IMPACT — onset mesuré (pic RMS à 6,380)
#   6,40 → 11,3   le pad qui s'ouvre puis se pose
#  11,29 → 13,49  le creux
#  13,77 → 14,45  ★ LE GESTE FINAL — « le petit bruit de fin »
#
# ── LE CALAGE SUR LA PARTITION DE LA LUNE DE SANG ──────────────────────────
# La partition (LuneDeSang.swift) : naissance 0→0,45 · plongée 0,45→1,30 ·
# LA POSE à 1,30 · trois états 1,30→3,75 · extinction 3,75→4,45.
#
# ⚠️ **L'IMPACT DU THÈME SE POSE SUR LA POSE DE LA LUNE**, et c'est tout
# l'intérêt du recut : départ = 6,300 − 1,30 = **5,000 s**. Le bourdon monte
# donc pendant la naissance et la plongée, et claque quand la caméra s'arrête.
# Une seconde d'écart et le son commente une image qui n'est plus là.
set -e
cd "$(dirname "$0")"
SRC=../../Woop/Sounds/MoonSplashTheme.m4a
DEST=../../Woop/Sounds/LuneSangTheme.m4a

# A — LA MONTÉE + LE PAD : 5,000 → 9,000 (4,00 s). Contigus dans la source,
# donc AUCUN raccord au milieu : l'impact et le pad qui le suit sont le
# matériau d'origine, intact.
# ⚠️ Le fondu d'entrée de 0,30 s n'est pas cosmétique : à 5,000 s la source est
# en pleine montée (~23 % du pic), une coupe sèche y ferait un CLIC.
#
# B — LE GESTE FINAL : 13,60 → 15,556 (on prend 0,17 s avant l'onset mesuré à
# 13,77 pour ne pas manger son attaque), retardé à 3,55 s et fondu-enchaîné.
# Il tombe donc sur l'EXTINCTION, et il ring out 1,06 s APRÈS la fin du plan —
# dans la couture noire, pendant que le film d'arrivée démarre. La continuité
# sonore par-dessus une couture visuelle invisible : c'est gratuit, et c'est
# ce qui fait « un film » plutôt que « deux écrans ».
#
# ⚠️ `normalize=0` sur l'amix : sans lui, ffmpeg DIVISE chaque entrée par le
# nombre d'entrées et le thème sort deux fois trop bas.
ffmpeg -y -v error -i "$SRC" -filter_complex "\
[0:a]atrim=start=5.0:end=9.0,asetpts=PTS-STARTPTS,\
afade=t=in:st=0:d=0.30,afade=t=out:st=3.55:d=0.45[a];\
[0:a]atrim=start=13.60:end=15.556,asetpts=PTS-STARTPTS,\
adelay=3550|3550,afade=t=in:st=3.55:d=0.45,\
afade=t=out:st=5.10:d=0.40[b];\
[a][b]amix=inputs=2:normalize=0[out]" \
  -map "[out]" -c:a aac -b:a 96k "$DEST"

echo "thème lune de sang → $DEST"
ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$DEST" \
  | awk '{printf "   durée %.3f s  (le plan fait 4,45 s : la queue ring out dans la couture noire)\n", $1}'
