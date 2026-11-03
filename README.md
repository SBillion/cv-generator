# cv-generator

Markdown + CSS → A4 PDF CV, built with [pandoc](https://pandoc.org) and
headless Chrome. The CV content lives in the `profil` repo: this tool only
renders it.

## Requirements

- `pandoc`
- Google Chrome (macOS path used: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`)
- Fonts used: **Bodoni 72** (name) and **Avenir Next** (body) — both ship with macOS.

## Usage

```sh
./build.sh [-r fr|be] [-d DIR] [-f FILE.pdf] [-a DIR] [-h]
```

| Flag | Meaning | Default |
| --- | --- | --- |
| `-r REGION` | `fr` (default) or `be`: location, phone, and the Belgian city on the CV | `fr` |
| `-d DIR` | output directory | `~/Documents/pro/CV/Belgique` |
| `-f FILE.pdf` | output PDF name (`.pdf` added if missing) | `Sebastien_Billion_Resume.pdf` |
| `-a DIR` | render an application folder: `DIR/CV.md` → `DIR/CV.pdf`, plus `DIR/LETTRE.md` → `DIR/LETTRE.pdf` when present. Names are fixed, so `-d` and `-f` are ignored | — |
| `-h` | show help | — |

Examples:

```sh
./build.sh                                            # -> OUT_DIR/Sebastien_Billion_Resume.pdf
./build.sh -d ~/Documents/Jobs/CV/Belgique            # into that folder
./build.sh -r be -f billion                           # Belgian contact details, custom name
./build.sh -a ../profil/candidatures/apptweak-2026-11 -r be   # CV.pdf + LETTRE.pdf
```

The CV is read from `$PROFIL_DIR/CV.md`, where `PROFIL_DIR` defaults to
`../profil` relative to this script (override it in the environment to point
elsewhere). `secrets.env` remains the only source of real contact details.

## Application folders

`-a DIR` renders a whole application folder from the `profil` repo in one call:
`DIR/CV.md` with `cv.css` to `DIR/CV.pdf`, and `DIR/LETTRE.md` with
`letter.css` to `DIR/LETTRE.pdf` when that file exists. The output names are
part of the folder contract, so `-d` and `-f` do not apply. Without `-a`, the
generic single-CV path is unchanged.

## Contact placeholders

The Markdown source uses `{{PHONE}}` and `{{EMAIL}}`. Real values
are read from `secrets.env` (gitignored) and injected at build time:

```sh
cp secrets.env.example secrets.env   # then edit it
```

Without `secrets.env`, the placeholders are left untouched in the PDF.

## Files

```
build.sh                  build script (flags above)
cv.css                    print stylesheet for the CV (A4)
letter.css                print stylesheet for the cover letter (A4)
secrets.env.example       template for local contact details
photo.jpeg                your photo (gitignored, optional)
```

The CV content itself is not here: it lives in `$PROFIL_DIR/CV.md`.
