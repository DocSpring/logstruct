#!/usr/bin/env bash
set -euo pipefail

# TODO - add pnpm-lock.yaml support to cspell-lockfile-dicts

echo "Generating lockfile words for root"
npx @docspring/cspell-lockfile-dicts \
  --path .cspell/generated-lockfile-words-root.txt \
  --lockfiles Gemfile.lock pnpm-lock.yaml

# echo "Generating lockfile words for docs"
# npx @docspring/cspell-lockfile-dicts \
#   --path .cspell/generated-lockfile-words-docs.txt \
#   --lockfiles docs/pnpm-lock.yaml
