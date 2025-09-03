#!/usr/bin/env bash
set -euo pipefail

echo "Generating lockfile words for root"
npx @docspring/cspell-lockfile-dicts \
  --path .cspell/generated-lockfile-words-root.txt \
  --lockfiles Gemfile.lock package-lock.json

echo "Generating lockfile words for site"
npx @docspring/cspell-lockfile-dicts \
  --path .cspell/generated-lockfile-words-site.txt \
  --lockfiles site/package-lock.json
