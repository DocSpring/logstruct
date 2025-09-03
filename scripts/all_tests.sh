#!/usr/bin/env bash
set -euo pipefail

echo "Running all tests with merged coverage reports"

# Run the regular unit tests first
echo "Running unit tests..."
scripts/test.rb

# Run the Rails integration tests
echo "Running Rails integration tests..."
scripts/rails_tests.sh

# Merge the coverage reports
echo "Merging coverage reports..."
scripts/merge_coverage.sh

echo "All tests completed!"
echo "Coverage report available at site/public/coverage/index.html"