#!/usr/bin/env bash
# Pushes shots/ to the auto-results branch right away (survives a later crash).
set +e
ROOT=${GITHUB_WORKSPACE:-$(pwd)}
URL=$(git -C "$ROOT" remote get-url origin)
HDR=$(git -C "$ROOT" config --get-regexp 'http\..*\.extraheader' | head -1 | cut -d' ' -f2-)
KEY=$(git -C "$ROOT" config --get-regexp 'http\..*\.extraheader' | head -1 | cut -d' ' -f1)
SHA=$(git -C "$ROOT" rev-parse HEAD)
T=$(mktemp -d)
cp -r "$ROOT/shots" "$T/" 2>/dev/null
cd "$T" && git init -q && git checkout -q -b r
echo "$SHA" > shots/SHA.txt
git -c user.name=ci-bot -c user.email=ci-bot@users.noreply.github.com add -f shots
git -c user.name=ci-bot -c user.email=ci-bot@users.noreply.github.com commit -qm "probe $1"
git -c "$KEY=$HDR" push -qf "$URL" r:auto-results
echo "pushed $1"
