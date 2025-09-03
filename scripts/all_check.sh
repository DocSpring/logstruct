#!/usr/bin/env bash

set -e

echo "===> Running Sorbet"
scripts/typecheck.sh

echo "===> Running LogStruct TypeScript Export"
scripts/export_typescript_types.rb

echo "===> Running TypeScript"
(cd site && npx tsc --noEmit)

echo "===> Running RuboCop"
scripts/rubocop.rb

echo "===> Running Prettier"
scripts/prettier.sh --check

echo "===> Running ESLint"
(cd site && npm run lint)

echo "===> Running CSpell Spellcheck"
scripts/spellcheck.sh

echo "===> Running TypeScript tests"
(cd site && npm test)

echo "===> Running Ruby and Integration tests"
scripts/all_tests.sh

echo "All checks passed! ✅"
