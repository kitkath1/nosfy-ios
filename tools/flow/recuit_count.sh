#!/bin/bash
# Le film de départ : 1080×1920,24Hz, une lecture, audio conservé.
set -euo pipefail
ici="$(cd "$(dirname "$0")" && pwd)"
source_count="${1:-$HOME/Downloads/count.mp4}"
cible_count="${2:-$ici/../../Woop/Media/count.mp4}"
mkdir -p "$(dirname "$cible_count")"
ffmpeg -hide_banner -loglevel warning -y -i "$source_count" \
  -map 0:v:0 -map '0:a:0?' \
  -vf 'scale=1080:1920:flags=lanczos,fade=t=in:st=0:d=0.12,fade=t=out:st=5.80:d=0.20' \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p \
  -c:a aac -b:a 128k -af 'afade=t=out:st=5.75:d=0.20' \
  -movflags +faststart "$cible_count"
ffprobe -v error -show_entries stream=codec_name,width,height,r_frame_rate \
  -show_entries format=duration,size -of json "$cible_count"
