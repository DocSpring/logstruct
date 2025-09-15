#!/usr/bin/env bash

set -e

echo "===> Generating LogStruct TypeScript + Ruby structs"
scripts/generate_structs.rb

echo "===> Running Sorbet"
scripts/typecheck.sh

echo "===> Running TypeScript"
(cd site && npx tsc --noEmit)

echo "===> Running RuboCop"
scripts/rubocop.rb -A

echo "===> Running Prettier"
scripts/prettier.sh --write

echo "===> Running ESLint"
(cd site && npm run lint -- --fix)

echo "===> Running CSpell Spellcheck"
scripts/spellcheck.sh

echo "===> Running TypeScript tests"
(cd site && npm test)

echo "===> Running Ruby and Integration tests"
scripts/all_tests.sh

echo "All checks passed! ✅"
