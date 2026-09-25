#!/bin/sh
# Verkleinert die exportierten Modelle für die App: Texturen höchstens
# 1024 px (Laterne 256 px), Geometrie mit Meshopt komprimiert.
#
#   sh optimize.sh <glb-ordner> ../../assets/city3d/models
set -e
QUELLE=$1
ZIEL=$2
GT="$(dirname "$0")/../../web3d/node_modules/.bin/gltf-transform"
mkdir -p "$ZIEL"
for f in "$QUELLE"/*.glb; do
  name=$(basename "$f")
  groesse=1024
  [ "$name" = "laterne.glb" ] && groesse=256
  "$GT" resize "$f" /tmp/_klein.glb --width $groesse --height $groesse >/dev/null
  "$GT" meshopt /tmp/_klein.glb "$ZIEL/$name" >/dev/null
  echo "$name $(($(stat -c %s "$ZIEL/$name") / 1024)) KB"
done
