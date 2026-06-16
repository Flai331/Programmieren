#!/usr/bin/env bash
# ============================================================================
#  Build-Skript für den Wärmefluss-Rechner
#  Baut die Linux-Version und (falls MinGW vorhanden) die Windows-.exe.
# ============================================================================
set -e

SRC="waermefluss.cpp"
cd "$(dirname "$0")"

echo "==> Linux-Build (waermefluss)"
g++ -std=c++17 -Wall -Wextra -O2 -o waermefluss "$SRC"
echo "    fertig: ./waermefluss"

# Windows-Cross-Build, nur wenn der MinGW-Compiler installiert ist.
# Installation unter Debian/Ubuntu:  sudo apt-get install g++-mingw-w64-x86-64
if command -v x86_64-w64-mingw32-g++ >/dev/null 2>&1; then
    echo "==> Windows-Build (waermefluss.exe, statisch gelinkt)"
    x86_64-w64-mingw32-g++ -std=c++17 -O2 \
        -static -static-libgcc -static-libstdc++ \
        -o waermefluss.exe "$SRC"
    echo "    fertig: ./waermefluss.exe (eigenständig, keine DLLs nötig)"
else
    echo "==> MinGW nicht gefunden – Windows-.exe wird übersprungen."
    echo "    Installieren mit: sudo apt-get install g++-mingw-w64-x86-64"
fi

echo "==> Alle Builds abgeschlossen."
