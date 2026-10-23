#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Known advisories in the locked Ruby and docs dependencies
bundle exec bundler-audit check --update
cd docs && pnpm audit
