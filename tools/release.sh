#!/bin/sh
# Builds dist/BReST-<version>.zip from the last commit: players unzip it into Interface/AddOns.
# The folder inside must stay BrzEnhancedSwingTimer, the textures and fonts are loaded from it.
set -e
cd "$(dirname "$0")/.."

version=$(sed -n 's/^## Version: *//p' BrzEnhancedSwingTimer.toc | tr -d '\r')
[ -n "$version" ] || { echo "no version in the .toc" >&2; exit 1; }

if [ -n "$(git status --porcelain --untracked-files=no | grep -v '^ M .gitignore$' || true)" ]; then
    echo "warning: uncommitted changes, the zip only has what is committed" >&2
fi

mkdir -p dist
out="dist/BReST-$version.zip"
rm -f "$out"
git archive --format=zip --prefix=BrzEnhancedSwingTimer/ -o "$out" HEAD
echo "$out"
unzip -l "$out" | tail -n 1
