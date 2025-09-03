#!/usr/bin/env bash
set -euo pipefail

# Check spelling using CSpell
pnpm exec cspell "**/*.{rb,md,js,json}" --no-progress 
