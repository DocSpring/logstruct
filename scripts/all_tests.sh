#!/usr/bin/env bash
set -euo pipefail

echo "Running all tests with merged coverage reports"

# Ensure generated files are in sync
scripts/check_generated.sh

# Run the regular unit tests first
scripts/test.rb

# Run the Rails integration tests
scripts/rails_tests.sh

# Merge the coverage reports
scripts/merge_coverage.sh


echo "All tests completed!"
echo "Coverage report available at docs/public/coverage/index.html"
