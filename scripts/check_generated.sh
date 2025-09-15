#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd "$(dirname "$0")/.." && pwd)
cd "$root_dir"

if [ -z "${CI:-}" ]; then
  echo "Skipping codegen sync check in non-CI environment."
  exit 0
fi

echo "Checking generated log structs are up to date..."

# Run the generator
ruby scripts/generate_structs.rb >/dev/null

# Detect changes
if ! git diff --quiet --exit-code lib/log_struct/log/; then
  echo "ERROR: Generated files are out of date. Run: ruby scripts/generate_structs.rb" >&2
  echo "Changed files:" >&2
  git diff --name-only lib/log_struct/log/ >&2
  exit 1
fi

echo "Generated files are up to date."
