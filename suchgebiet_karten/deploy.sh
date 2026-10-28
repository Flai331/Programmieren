#!/bin/bash
# Kopiert die Web-App nach docs/ (GitHub Pages).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/web"
DEST_DIR="$SCRIPT_DIR/../docs/suchgebiet-karten"

rm -rf "$DEST_DIR"
cp -r "$SOURCE_DIR" "$DEST_DIR"

echo "✓ Deployed to $DEST_DIR"
