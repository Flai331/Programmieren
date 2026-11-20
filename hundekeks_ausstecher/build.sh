#!/bin/sh
# Erzeugt die eigenständige Web-Version (GitHub Pages) aus app.html
cd "$(dirname "$0")"
{ printf '<!doctype html>\n<html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><style>:root{padding-top:env(safe-area-inset-top,0px);padding-bottom:env(safe-area-inset-bottom,0px)}body{margin:0}img{max-width:100%%}[hidden]{display:none!important}</style></head><body>\n'; cat app.html; printf '\n</body></html>\n'; } > ../docs/hundekeks/index.html
