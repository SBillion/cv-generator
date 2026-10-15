#!/bin/sh
# CV generator: Markdown + CSS -> A4 PDF (pandoc + headless Chrome).
#
# Generic:  build.sh
# Generic:  build.sh -d ~/Documents/Jobs/CV/Belgique
# Tailored: build.sh -d ~/Documents/Jobs/CV/Belgique -c Acme
# Custom:   build.sh -c Acme -f billion.pdf
#
# Real contact details live in a gitignored secrets.env and are injected into the
# {{LOCATION}} / {{PHONE}} / {{EMAIL}} placeholders at build time.
set -eu

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
OUT_DIR="$HOME/Documents/pro/CV/Belgique"
COMPANY=""
PDF_NAME="Sebastien_Billion_Resume.pdf"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

usage() {
  cat <<EOF
Usage: $(basename "$0") [-d DIR] [-c COMPANY] [-f FILE.pdf] [-h]

  -d DIR        output directory (default: $OUT_DIR)
  -c COMPANY    tailored mode: create DIR/COMPANY/ and build from CV_COMPANY.md
  -f FILE.pdf   output PDF name (default: $PDF_NAME)
  -h            show this help
EOF
}

while getopts "d:c:f:h" opt; do
  case "$opt" in
    d) OUT_DIR=$OPTARG ;;
    c) COMPANY=$OPTARG ;;
    f) PDF_NAME=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

case "$PDF_NAME" in
  *.pdf) ;;
  *) PDF_NAME="$PDF_NAME.pdf" ;;
esac

# Resolve the target directory and the Markdown source.
if [ -n "$COMPANY" ]; then
  SLUG=$(printf '%s' "$COMPANY" | tr ' ' '_')
  TARGET_DIR="$OUT_DIR/$COMPANY"
  SRC_MD="$TARGET_DIR/CV_$SLUG.md"
else
  TARGET_DIR="$OUT_DIR"
  SRC_MD="$SRC_DIR/CV_Generic.md"
fi
mkdir -p "$TARGET_DIR"

# Tailored: seed the company Markdown from the generic template the first time.
if [ -n "$COMPANY" ] && [ ! -f "$SRC_MD" ]; then
  cp "$SRC_DIR/CV_Generic.md" "$SRC_MD"
fi

# Load real values (gitignored) when present; otherwise placeholders stay as-is.
if [ -f "$SRC_DIR/secrets.env" ]; then
  # shellcheck disable=SC1091
  . "$SRC_DIR/secrets.env"
fi
[ -n "${LOCATION:-}" ] || LOCATION='{{LOCATION}}'
[ -n "${PHONE:-}" ] || PHONE='{{PHONE}}'
[ -n "${EMAIL:-}" ] || EMAIL='{{EMAIL}}'

# Build in a temp dir so relative assets resolve and nothing leaks into output.
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT
cp "$SRC_DIR/cv.css" "$BUILD_DIR/cv.css"
if [ -f "$SRC_DIR/photo.jpeg" ]; then
  cp "$SRC_DIR/photo.jpeg" "$BUILD_DIR/photo.jpeg"
fi

sed \
  -e "s|{{LOCATION}}|$LOCATION|g" \
  -e "s|{{PHONE}}|$PHONE|g" \
  -e "s|{{EMAIL}}|$EMAIL|g" \
  "$SRC_MD" > "$BUILD_DIR/cv.md"

pandoc "$BUILD_DIR/cv.md" -f markdown -t html5 -s \
  --metadata title="CV" -c cv.css -o "$BUILD_DIR/cv.html"

"$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$BUILD_DIR/out.pdf" "file://$BUILD_DIR/cv.html" 2>/dev/null

[ -s "$BUILD_DIR/out.pdf" ] || { echo "error: PDF generation failed" >&2; exit 1; }
mv "$BUILD_DIR/out.pdf" "$TARGET_DIR/$PDF_NAME"
echo "generated: $TARGET_DIR/$PDF_NAME"
