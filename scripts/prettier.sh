#!/usr/bin/env bash
set -euo pipefail

PRETTIER_ARG="${1:---write}"

# Format / check YAML files with Prettier
pnpm exec prettier "**/*.{yml,yaml}" "$PRETTIER_ARG"
