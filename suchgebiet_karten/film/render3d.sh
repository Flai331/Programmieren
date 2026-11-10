#!/bin/bash
# 3D-Film rendern (fortsetzbar): zwei Prozesse teilen sich die Abschnitte, danach Zusammenbau und Musik
cd "$(dirname "$0")"
export NODE_PATH=$(npm root -g)
PART=0/2 node compose3d.js > compose3d-0.log 2>&1 &
PART=1/2 node compose3d.js > compose3d-1.log 2>&1 &
wait
node compose3d.js > compose3d.log 2>&1 || exit 1
grep -q Fertig compose3d.log || exit 1
[ -n "$1" ] && OFFSETS=offsets-3d.json IN=RHS-Einsatz-Scheuen-3D-ohne-Ton.mp4 OUT=RHS-Einsatz-Scheuen-3D.mp4 python3 musik.py "$1"
