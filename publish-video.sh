#!/usr/bin/env bash
# Publish a screen recording to github.com/yaaryvp/shift2028-preview
#
#   ./publish-video.sh /path/to/recording.mp4  ["optional title"]
#
# GitHub renders an .mp4 committed to a repo inline in the file view, so a committed
# video gets a link that PLAYS in the browser. The hard limits are the reason for the
# branch below: 100MB per file is refused outright, and GitHub warns above 50MB.
# Anything larger goes to a Release asset instead, which has a 2GB limit but downloads
# rather than plays.
set -euo pipefail

REPO_DIR="C:/Users/yaary/shift2028-preview"
SRC="${1:?usage: publish-video.sh <file> [title]}"
TITLE="${2:-Shift2028 at work}"
FFMPEG="/c/tools/ffmpeg/ffmpeg"

[ -f "$SRC" ] || { echo "no such file: $SRC" >&2; exit 1; }

BYTES=$(stat -c%s "$SRC")
MB=$(( BYTES / 1024 / 1024 ))
BASE="shift2028-$(date +%Y%m%d).mp4"
echo "source: $SRC  (${MB} MB)"

cd "$REPO_DIR"

if [ "$MB" -lt 45 ]; then
  cp "$SRC" "video/$BASE"
  git add "video/$BASE"
  git -c user.name="Yaary" -c user.email="yaary.vidanpeled@gmail.com" \
      commit -q -m "video: $TITLE"
  git push -q origin master
  echo
  echo "PLAYS IN BROWSER:"
  echo "  https://github.com/yaaryvp/shift2028-preview/blob/master/video/$BASE"
else
  echo "…${MB} MB is too large to commit comfortably. Compressing first."
  OUT="$(dirname "$SRC")/compressed-$BASE"
  # CRF 28 + 1280px wide is the usual sweet spot for a screen recording:
  # text stays readable and a few minutes lands well under the limit.
  "$FFMPEG" -y -loglevel error -i "$SRC" \
    -vf "scale='min(1280,iw)':-2" -c:v libx264 -crf 28 -preset slow \
    -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 96k "$OUT"
  NEWMB=$(( $(stat -c%s "$OUT") / 1024 / 1024 ))
  echo "compressed: ${MB} MB -> ${NEWMB} MB"
  if [ "$NEWMB" -lt 45 ]; then
    cp "$OUT" "video/$BASE"
    git add "video/$BASE"
    git -c user.name="Yaary" -c user.email="yaary.vidanpeled@gmail.com" \
        commit -q -m "video: $TITLE"
    git push -q origin master
    echo
    echo "PLAYS IN BROWSER:"
    echo "  https://github.com/yaaryvp/shift2028-preview/blob/master/video/$BASE"
  else
    TAG="video-$(date +%Y%m%d-%H%M)"
    gh release create "$TAG" "$OUT" --title "$TITLE" --notes "Screen recording of Shift2028 in development."
    echo
    echo "DOWNLOAD LINK (too large to play inline):"
    gh release view "$TAG" --json assets --jq '.assets[].url'
  fi
fi
