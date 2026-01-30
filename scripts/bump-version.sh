#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION_FILE="$SCRIPT_DIR/../lib/log_struct/version.rb"

usage() {
  echo "Usage: $0 {major|minor|patch}"
  echo
  echo "Bumps the version in lib/log_struct/version.rb"
  echo
  echo "Examples:"
  echo "  $0 patch   # 0.1.11 -> 0.1.12"
  echo "  $0 minor   # 0.1.11 -> 0.2.0"
  echo "  $0 major   # 0.1.11 -> 1.0.0"
  exit 1
}

if [[ $# -ne 1 ]]; then
  usage
fi

BUMP_TYPE="$1"

if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
  echo "Error: Invalid bump type '$BUMP_TYPE'"
  usage
fi

# Extract current version
CURRENT_VERSION=$(grep -oE 'VERSION = "[0-9]+\.[0-9]+\.[0-9]+"' "$VERSION_FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')

if [[ -z "$CURRENT_VERSION" ]]; then
  echo "Error: Could not find VERSION in $VERSION_FILE"
  exit 1
fi

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump the appropriate component
case "$BUMP_TYPE" in
  major)
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
    ;;
  minor)
    MINOR=$((MINOR + 1))
    PATCH=0
    ;;
  patch)
    PATCH=$((PATCH + 1))
    ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"

# Update the version file
sed -i '' "s/VERSION = \"$CURRENT_VERSION\"/VERSION = \"$NEW_VERSION\"/" "$VERSION_FILE"

echo "Bumped version: $CURRENT_VERSION -> $NEW_VERSION"
