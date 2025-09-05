#!/usr/bin/env bash
set -euo pipefail

# Create a git tag for the current LogStruct version.
# - Reads version from lib/log_struct/version.rb by default
# - Validates that the working tree is clean (unless --allow-dirty)
# - Validates that the tag does not already exist locally or on origin
# - Creates an annotated tag: vX.Y.Z or vX.Y.Z-rcN
# - Optional: --push to push the tag to origin

usage() {
  cat <<'USAGE'
Usage: bash scripts/create_release_tag.sh [--version X.Y.Z[-rcN]] [--push] [--allow-dirty] [--force]

Options:
  --version       Override version (default: read from version.rb)
  --push          Push the created tag to origin
  --allow-dirty   Allow running with uncommitted changes
  --force         Skip version.rb vs --version check
  -h, --help      Show this help

Examples:
  bash scripts/create_release_tag.sh                # uses version.rb
  bash scripts/create_release_tag.sh --push         # create + push
  bash scripts/create_release_tag.sh --version 0.0.2-rc1 --push
USAGE
}

VERSION_OVERRIDE=""
PUSH=false
ALLOW_DIRTY=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      VERSION_OVERRIDE="${2:-}"; shift 2 ;;
    --push)
      PUSH=true; shift ;;
    --allow-dirty)
      ALLOW_DIRTY=true; shift ;;
    --force)
      FORCE=true; shift ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2; usage; exit 1 ;;
  esac
done

# Read version from version.rb
VERSION_RB=$(ruby -e 'print File.read("lib/log_struct/version.rb")[/VERSION\s*=\s*"([^"]+)"/,1]')
if [[ -z "$VERSION_RB" ]]; then
  echo "Error: Could not read version from lib/log_struct/version.rb" >&2
  exit 1
fi

VERSION="${VERSION_OVERRIDE:-$VERSION_RB}"
TAG="v$VERSION"

if [[ -n "$VERSION_OVERRIDE" && "$FORCE" != true && "$VERSION_OVERRIDE" != "$VERSION_RB" ]]; then
  echo "Error: --version ($VERSION_OVERRIDE) does not match version.rb ($VERSION_RB). Use --force to skip." >&2
  exit 1
fi

# Ensure clean working tree unless allowed
if [[ "$ALLOW_DIRTY" != true ]]; then
  if [[ -n $(git status --porcelain) ]]; then
    echo "Error: Working tree has uncommitted changes. Commit or stash, or pass --allow-dirty." >&2
    git status --porcelain
    exit 1
  fi
fi

# Ensure tag doesn't already exist
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  echo "Error: Local tag $TAG already exists." >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  echo "Error: Remote tag $TAG already exists on origin." >&2
  exit 1
fi

echo "Creating annotated tag $TAG"
git tag -a "$TAG" -m "Release $TAG"

if [[ "$PUSH" == true ]]; then
  echo "Pushing tag $TAG to origin"
  git push origin "$TAG"
else
  echo "Tag created locally: $TAG"
  echo "Push with: git push origin $TAG"
fi

