#!/bin/bash
set -euo pipefail

# Release helper: bump version by +0.1 (minor), reset patch to 0, increment build number, commit, tag, push
# Usage: ./scripts/release_bump_and_push.sh

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -f pubspec.yaml ]]; then
  echo "pubspec.yaml not found; run from repo root" >&2
  exit 1
fi

current_line=$(grep '^version:' pubspec.yaml | head -n1 | awk '{print $2}')
if [[ -z "$current_line" ]]; then
  echo "Unable to read current version from pubspec.yaml" >&2
  exit 1
fi

ver_no_build="${current_line%%+*}"
build_no="${current_line##*+}"
IFS='.' read -r major minor patch <<< "$ver_no_build"

# Bump minor (+0.1), reset patch to 0; increment build number
minor=$((minor + 1))
patch=0
if [[ "$build_no" =~ ^[0-9]+$ ]]; then
  build_no=$((build_no + 1))
else
  build_no=1
fi

new_version="${major}.${minor}.${patch}+${build_no}"

# Update pubspec.yaml (macOS-compatible sed)
sed -i '' "s/^version: .*/version: ${new_version}/" pubspec.yaml

echo "Bumped version: ${current_line} -> ${new_version}"

# Commit, tag, and push
branch=$(git rev-parse --abbrev-ref HEAD)

git add pubspec.yaml
# Include any staged changes already prepared by user
if ! git diff --cached --quiet; then
  git commit -m "chore(release): bump version to ${new_version}"
else
  echo "No staged changes; creating version-only commit"
  git commit -m "chore(release): bump version to ${new_version}" --allow-empty
fi

# Tag as vMAJOR.MINOR (matches prior tagging style like v4.0)
tag_name="v${major}.${minor}"
if git rev-parse -q --verify "refs/tags/${tag_name}" >/dev/null; then
  echo "Tag ${tag_name} already exists; creating patch-style tag instead"
  tag_name="v${major}.${minor}.${patch}"
fi

git tag -a "${tag_name}" -m "Release ${tag_name}"

echo "Pushing branch '${branch}' and tags..."
git push origin "${branch}" --tags

echo "Done: ${new_version} tagged as ${tag_name}" 