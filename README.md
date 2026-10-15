# cv-generator

Markdown + CSS → A4 PDF CV, generic or tailored per company, built with
[pandoc](https://pandoc.org) and headless Chrome.

## Requirements

- `pandoc`
- Google Chrome (macOS path used: `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`)
- Fonts used: **Bodoni 72** (name) and **Avenir Next** (body) — both ship with macOS.

## Usage

```sh
./build.sh [-d DIR] [-c COMPANY] [-f FILE.pdf] [-h]
```

| Flag | Meaning | Default |
| --- | --- | --- |
| `-d DIR` | output directory | `~/Documents/pro/CV/Belgique` |
| `-c COMPANY` | tailored mode: create `DIR/COMPANY/` | — (generic) |
| `-f FILE.pdf` | output PDF name (`.pdf` added if missing) | `Sebastien_Billion_Resume.pdf` |
| `-h` | show help | — |

Examples:

```sh
./build.sh                                            # generic -> OUT_DIR/Sebastien_Billion_Resume.pdf
./build.sh -d ~/Documents/Jobs/CV/Belgique            # generic into that folder
./build.sh -d ~/Documents/Jobs/CV/Belgique -c Acme    # tailored: .../Belgique/Acme/CV_Acme.md + PDF
./build.sh -c Acme -f billion                         # .../Acme/billion.pdf
```

In tailored mode, the first run seeds `CV_<COMPANY>.md` from `CV_Generic.md`.
Edit that file, then run the same command again to regenerate the PDF.

## Contact placeholders

The Markdown files use `{{LOCATION}}`, `{{PHONE}}` and `{{EMAIL}}`. Real values
are read from `secrets.env` (gitignored) and injected at build time:

```sh
cp secrets.env.example secrets.env   # then edit it
```

Without `secrets.env`, the placeholders are left untouched in the PDF.

## Files

```
build.sh                  build script (flags above)
cv.css                    print stylesheet (A4)
CV_Generic.md             generic CV template (placeholders)
secrets.env.example       template for local contact details
examples/                 reference tailored CVs (placeholders)
photo.jpeg                your photo (gitignored, optional)
```
