#!/bin/sh
# CV generator: Markdown + CSS -> A4 PDF (pandoc + headless Chrome).
#
# The CV source is the canonical archive in the profil repo: PROFIL_DIR/CV.md
# (PROFIL_DIR defaults to ../profil next to this script). No local copy exists.
#
# Render:  build.sh
# Render:  build.sh -d ~/Documents/Jobs/CV/Belgique -r be
# Render:  build.sh -a candidatures/apptweak-2026-11 -r be
# Publish: build.sh -p   (private archive + anonymised copy in ../website/public)
#
# Real contact details live in a gitignored secrets.env. Region (-r fr|be) picks
# the location and phone, and whether the Belgian city is shown.
set -eu

SRC_DIR=$(cd "$(dirname "$0")" && pwd)
PROFIL_DIR=${PROFIL_DIR:-$SRC_DIR/../profil}
OUT_DIR="$HOME/Documents/pro/CV/Belgique"
APP_DIR=""
PUBLIC=0
REGION="fr"
PDF_NAME="Sebastien_Billion_Resume.pdf"
CHROME=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}

usage() {
  cat <<EOF
Usage: $(basename "$0") [-r fr|be] [-d DIR] [-f FILE.pdf] [-a DIR] [-p] [-h]

  -r REGION     fr (default) or be: location, phone and Belgian city on the CV
  -d DIR        output directory (default: $OUT_DIR)
  -f FILE.pdf   output PDF name (default: $PDF_NAME)
  -a DIR        render an application folder: DIR/CV.md -> DIR/CV.pdf, plus
                DIR/LETTRE.md -> DIR/LETTRE.pdf when that file exists.
                The names are fixed, so -d and -f are ignored in this mode.
  -p            publish: render the private archive, then the anonymised CV to
                \$WEBSITE_DIR/public/sebastien-billion-cv.pdf (contact details
                stripped). Cannot be combined with -a.
  -h            show this help
EOF
}

while getopts "r:d:f:a:ph" opt; do
  case "$opt" in
    r) REGION=$OPTARG ;;
    d) OUT_DIR=$OPTARG ;;
    f) PDF_NAME=$OPTARG ;;
    a) APP_DIR=$OPTARG ;;
    p) PUBLIC=1 ;;
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

# The public mode writes into another repo on a fixed path; -a writes fixed names
# into an application folder. Mixing them would publish an application CV.
if [ "$PUBLIC" = 1 ] && [ -n "$APP_DIR" ]; then
  echo "error: -p cannot be combined with -a" >&2
  usage >&2
  exit 2
fi

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

# Publishing must never ship a placeholder or a half-known identity.
if [ "$PUBLIC" = 1 ]; then
  [ -f "$SRC_DIR/secrets.env" ] || {
    echo "error: -p needs $SRC_DIR/secrets.env (real contact details, location)" >&2
    exit 1
  }
  case "$REGION" in
    be) LOC_PUBLIC=${LOCATION_BE:-} ;;
    *) LOC_PUBLIC=${LOCATION_FR:-} ;;
  esac
  [ -n "$LOC_PUBLIC" ] || {
    echo "error: -p needs a non-empty location for region '$REGION' in $SRC_DIR/secrets.env" >&2
    exit 1
  }
  WEBSITE_DIR=${WEBSITE_DIR:-$SRC_DIR/../website}
  PUBLIC_PDF="$WEBSITE_DIR/public/sebastien-billion-cv.pdf"
  [ -d "$WEBSITE_DIR/public" ] || {
    echo "error: -p writes to $WEBSITE_DIR/public, which does not exist" >&2
    exit 1
  }
fi

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

# A private region is removed with a sed range: an unclosed opener would delete
# everything to EOF and publish a truncated CV, so refuse before any render.
check_private_region() {
  _md=$1
  _open=$(grep -c -x -F '<!-- private -->' "$_md" || true)
  _close=$(grep -c -x -F '<!-- /private -->' "$_md" || true)
  if [ "$_open" -ne 1 ] || [ "$_close" -ne 1 ]; then
    echo "error: malformed private region in $_md: expected exactly one" >&2
    echo "       '<!-- private -->' and one '<!-- /private -->'" >&2
    exit 1
  fi
  _first=$(grep -n -x -F '<!-- private -->' "$_md" | cut -d: -f1)
  _last=$(grep -n -x -F '<!-- /private -->' "$_md" | cut -d: -f1)
  if [ "$_first" -ge "$_last" ]; then
    echo "error: malformed private region in $_md: '<!-- /private -->' comes" >&2
    echo "       before '<!-- private -->'" >&2
    exit 1
  fi
}

# render_md SRC_MD CSS_FILE OUT_PDF TITLE [MODE]
# MODE: prive (default) or public. Blanking {{PHONE}}/{{EMAIL}} and coarsening
# {{LOCATION}} is local to this render: the script-level values stay real, so a
# private render in the same call keeps its contact details.
render_md() {
  _md=$1; _css=$2; _out=$3; _title=$4; _mode=${5:-prive}
  case "$_mode" in
    # The published copy keeps a country, never a street or a postcode: the PDF
    # is downloaded, forwarded and indexed, and the site already says how to get
    # in touch.
    public) _phn=""; _mail=""; _loc=${LOCATION_PUBLIC_TEXT:-Belgique} ;;
    *) _phn=$PHN; _mail=$EMAIL; _loc=$LOC ;;
  esac

  if [ "$_mode" = public ]; then
    check_private_region "$_md"
    # Drop the whole region before substitution: no empty bullet survives.
    _private_filter='/^<!-- private -->$/,/^<!-- \/private -->$/d'
  else
    # Markers only (pandoc drops HTML comments): keeps both modes symmetric.
    _private_filter='/^<!-- private -->$/d;/^<!-- \/private -->$/d'
  fi

  sed -e "$_private_filter" "$_md" \
    | sed \
      -e "s|{{LOCATION}}|$_loc|g" \
      -e "s|{{PHONE}}|$_phn|g" \
      -e "s|{{EMAIL}}|$_mail|g" \
      -e "s|{{PLACE}}|$PLACE|g" > "$BUILD_DIR/render.md"

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
  if [ -f "$APP_DIR/LETTRE.md" ]; then
    render_md "$APP_DIR/LETTRE.md" letter.css "$TARGET_DIR/LETTRE.pdf" "Letter"
  elif [ -f "$TARGET_DIR/LETTRE.pdf" ]; then
    # A rerun without the source must not leave a sendable stale letter behind.
    rm -f "$TARGET_DIR/LETTRE.pdf"
    echo "warning: no LETTRE.md, removed stale LETTRE.pdf" >&2
  fi
  exit 0
fi

if [ "$PUBLIC" = 1 ]; then
  # Validate before the first render: a malformed region must leave nothing written.
  check_private_region "$PROFIL_DIR/CV.md"
  # One call, two PDFs: the private archive keeps -d/-f, the public copy has its
  # own fixed path. Each render states its mode so neither can inherit the other.
  render_md "$PROFIL_DIR/CV.md" cv.css "$TARGET_DIR/$PDF_NAME" "CV" prive
  render_md "$PROFIL_DIR/CV.md" cv.css "$PUBLIC_PDF" "CV" public
  echo "published: $PUBLIC_PDF"
else
  render_md "$PROFIL_DIR/CV.md" cv.css "$TARGET_DIR/$PDF_NAME" "CV"
fi
