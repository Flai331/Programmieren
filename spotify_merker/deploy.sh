#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/web"
DEST_DIR="$SCRIPT_DIR/../docs/spotify-merker"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory $SOURCE_DIR does not exist"
  exit 1
fi

rm -rf "$DEST_DIR"
cp -r "$SOURCE_DIR" "$DEST_DIR"

echo "✓ Deployed to $DEST_DIR"
