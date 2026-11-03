#!/bin/sh
# CV generator: Markdown + CSS -> A4 PDF (pandoc + headless Chrome).
#
# The CV source is the canonical archive in the profil repo: PROFIL_DIR/CV.md
# (PROFIL_DIR defaults to ../profil next to this script). No local copy exists.
#
# Render:  build.sh
# Render:  build.sh -d ~/Documents/Jobs/CV/Belgique -r be
# Render:  build.sh -a candidatures/apptweak-2026-11 -r be
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
Usage: $(basename "$0") [-r fr|be] [-d DIR] [-f FILE.pdf] [-a DIR] [-h]

  -r REGION     fr (default) or be: location, phone and Belgian city on the CV
  -d DIR        output directory (default: $OUT_DIR)
  -f FILE.pdf   output PDF name (default: $PDF_NAME)
  -a DIR        render an application folder: DIR/CV.md -> DIR/CV.pdf, plus
                DIR/LETTRE.md -> DIR/LETTRE.pdf when that file exists.
                The names are fixed, so -d and -f are ignored in this mode.
  -h            show this help
EOF
}

while getopts "r:d:f:a:h" opt; do
  case "$opt" in
    r) REGION=$OPTARG ;;
    d) OUT_DIR=$OPTARG ;;
    f) PDF_NAME=$OPTARG ;;
    a) APP_DIR=$OPTARG ;;
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

# Resolve the target directory; the application mode has fixed file names.
if [ -n "$APP_DIR" ]; then
  TARGET_DIR="$APP_DIR"
  [ -f "$APP_DIR/CV.md" ] || { echo "error: no CV.md in application folder: $APP_DIR" >&2; exit 1; }
else
  TARGET_DIR="$OUT_DIR"
fi
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
if [ -f "$SRC_DIR/letter.css" ]; then
  cp "$SRC_DIR/letter.css" "$BUILD_DIR/letter.css"
fi
if [ -f "$SRC_DIR/photo.jpeg" ]; then
  cp "$SRC_DIR/photo.jpeg" "$BUILD_DIR/photo.jpeg"
fi

# render_md SRC_MD CSS_FILE OUT_PDF TITLE
render_md() {
  _md=$1; _css=$2; _out=$3; _title=$4
  sed \
    -e "s|{{LOCATION}}|$LOC|g" \
    -e "s|{{PHONE}}|$PHN|g" \
    -e "s|{{EMAIL}}|$EMAIL|g" \
    -e "s|{{PLACE}}|$PLACE|g" \
    "$_md" > "$BUILD_DIR/render.md"

  pandoc "$BUILD_DIR/render.md" -f markdown -t html5 -s \
    --metadata title="$_title" -c "$_css" -o "$BUILD_DIR/render.html"

  "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
    --print-to-pdf="$BUILD_DIR/render.pdf" "file://$BUILD_DIR/render.html" 2>/dev/null

  [ -s "$BUILD_DIR/render.pdf" ] || { echo "error: PDF generation failed for $_md" >&2; exit 1; }
  mv "$BUILD_DIR/render.pdf" "$_out"
  echo "generated: $_out"
}

# Application mode: a folder holds CV.md (and optionally LETTRE.md).
if [ -n "$APP_DIR" ]; then
  render_md "$APP_DIR/CV.md" cv.css "$TARGET_DIR/CV.pdf" "CV"
  exit 0
fi

render_md "$PROFIL_DIR/CV.md" cv.css "$TARGET_DIR/$PDF_NAME" "CV"
