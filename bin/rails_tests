#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_APP_DIR="$PROJECT_ROOT/rails_test_app/logstruct_test_app"
CREATE_APP_SCRIPT="$PROJECT_ROOT/rails_test_app/create_app.rb"
VERSION_FILE="$TEST_APP_DIR/.rails_version"
RAILS_VERSION="${RAILS_VERSION:-"7.0.8"}"
FORCE_RECREATE="${FORCE_RECREATE:-false}"

# Show what we're testing
echo "Testing LogStruct with Rails ${RAILS_VERSION}"

# Check if bundler is installed
if ! gem list -i "^bundler$" > /dev/null 2>&1; then
  echo "Installing bundler..."
  gem install bundler
fi

# Check if Rails version file doesn't exist or version has changed
if [ -d "$TEST_APP_DIR" ]; then
  if [ ! -f "$VERSION_FILE" ]; then
    echo "Rails version file not found. Forcing recreation of test app..."
    FORCE_RECREATE="true"
  else
    PREVIOUS_VERSION=$(cat "$VERSION_FILE")
    if [ "$PREVIOUS_VERSION" != "$RAILS_VERSION" ]; then
      echo "Rails version changed (${PREVIOUS_VERSION} -> ${RAILS_VERSION})"
      echo "Forcing recreation of test app..."
      FORCE_RECREATE="true"
    fi
  fi
fi

# Only recreate the app if FORCE_RECREATE is set or the app doesn't exist
if [ "$FORCE_RECREATE" = "true" ] && [ -d "$TEST_APP_DIR" ]; then
  echo "Removing existing test app: $TEST_APP_DIR"
  rm -rf "$TEST_APP_DIR"
fi

# Create the test app if it doesn't exist
if [ ! -d "$TEST_APP_DIR" ]; then
  echo "Creating Rails test app..."

  # Make sure the create_app.rb script exists
  if [ ! -f "$CREATE_APP_SCRIPT" ]; then
    echo "Error: Create app script not found at $CREATE_APP_SCRIPT"
    echo "Make sure all template files are in place before running this script."
    exit 1
  fi

  # Create the test app with the specified Rails version
  RAILS_VERSION="$RAILS_VERSION" ruby "$CREATE_APP_SCRIPT"
else
  echo "Using existing test app at $TEST_APP_DIR"
  
  # Still copy templates to ensure latest code is used
  echo "Updating template files..."
  RAILS_VERSION="$RAILS_VERSION" SKIP_APP_CREATION="true" ruby "$CREATE_APP_SCRIPT"
  
  # Make sure the version file is up to date
  echo "$RAILS_VERSION" > "$VERSION_FILE"
  echo "Updated Rails version file to $RAILS_VERSION"
fi

# Run the tests in the test app
echo "Running integration tests in Rails test app..."
cd "$TEST_APP_DIR"

# Make sure the database is set up
bin/rails db:migrate

# Run the tests
bin/rails test

echo "All Rails integration tests completed!"
