#!/bin/sh
# CV generator: Markdown + CSS -> A4 PDF (pandoc + headless Chrome).
#
# The CV source is the canonical archive in the profil repo: PROFIL_DIR/CV.md
# (PROFIL_DIR defaults to ../profil next to this script). No local copy exists.
#
# Render:  build.sh
# Render:  build.sh -d ~/Documents/Jobs/CV/Belgique -r be
#
# Real contact details live in a gitignored secrets.env. Region (-r fr|be) picks
# the location and phone, and whether the Belgian city is shown.
set -eu

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
PROFIL_DIR=${PROFIL_DIR:-$SRC_DIR/../profil}
OUT_DIR="$HOME/Documents/pro/CV/Belgique"
APP_DIR=""
REGION="fr"
PDF_NAME="Sebastien_Billion_Resume.pdf"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-r fr|be] [-d DIR] [-f FILE.pdf] [-h]

  -r REGION     fr (default) or be: location, phone and Belgian city on the CV
  -d DIR        output directory (default: $OUT_DIR)
  -f FILE.pdf   output PDF name (default: $PDF_NAME)
  -h            show this help
EOF
}

while getopts "r:d:f:h" opt; do
  case "$opt" in
    r) REGION=$OPTARG ;;
    d) OUT_DIR=$OPTARG ;;
    f) PDF_NAME=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done
case "$REGION" in
  fr|be) ;;
  *) usage; exit 2 ;;
esac
shift $((OPTIND - 1))

case "$PDF_NAME" in
  *.pdf) ;;
  *) PDF_NAME="$PDF_NAME.pdf" ;;
esac

# Resolve the target directory and the Markdown source.
TARGET_DIR="$OUT_DIR"
SRC_MD="$PROFIL_DIR/CV.md"
mkdir -p "$TARGET_DIR"

# Load real values (gitignored) when present; otherwise placeholders stay as-is.
if [ -f "$SRC_DIR/secrets.env" ]; then
  # shellcheck disable=SC1091
  . "$SRC_DIR/secrets.env"
fi
case "$REGION" in
  be) LOC=${LOCATION_BE:-}; PHN=${PHONE_BE:-}; PLACE=" (Liège)" ;;
  *) LOC=${LOCATION_FR:-}; PHN=${PHONE_FR:-}; PLACE="" ;;
esac
[ -n "$LOC" ] || LOC='{{LOCATION}}'
[ -n "$PHN" ] || PHN='{{PHONE}}'
[ -n "${EMAIL:-}" ] || EMAIL='{{EMAIL}}'

# Build in a temp dir so relative assets resolve and nothing leaks into output.
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT
cp "$SRC_DIR/cv.css" "$BUILD_DIR/cv.css"
if [ -f "$SRC_DIR/photo.jpeg" ]; then
  cp "$SRC_DIR/photo.jpeg" "$BUILD_DIR/photo.jpeg"
fi

sed \
  -e "s|{{LOCATION}}|$LOC|g" \
  -e "s|{{PHONE}}|$PHN|g" \
  -e "s|{{EMAIL}}|$EMAIL|g" \
  -e "s|{{PLACE}}|$PLACE|g" \
  "$SRC_MD" > "$BUILD_DIR/cv.md"

pandoc "$BUILD_DIR/cv.md" -f markdown -t html5 -s \
  --metadata title="CV" -c cv.css -o "$BUILD_DIR/cv.html"

"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$BUILD_DIR/out.pdf" "file://$BUILD_DIR/cv.html" 2>/dev/null

[ -s "$BUILD_DIR/out.pdf" ] || { echo "error: PDF generation failed" >&2; exit 1; }
mv "$BUILD_DIR/out.pdf" "$TARGET_DIR/$PDF_NAME"
echo "generated: $TARGET_DIR/$PDF_NAME"
