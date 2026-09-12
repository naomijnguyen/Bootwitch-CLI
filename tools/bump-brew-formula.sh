#!/usr/bin/env bash
# @bootwitch:component
# Name: tools/bump-brew-formula.sh
# Type: script
# Dates: Created: 2026-09-12 | Last Updated: 2026-09-12
# Version: 0.1.0
# Purpose: Update the hosted Homebrew formula for the current Bootwitch release tag.
# Arguments: Optional tag (defaults to v$(cat VERSION)); --dry-run supported.
# Output: Rewrites Formula/bootwitch.rb and prints a short confirmation.
# Returns: 0 on success.
# Dependencies: Bash, curl, shasum, python3.
# Reads: VERSION and Formula/bootwitch.rb.
# Writes: Formula/bootwitch.rb.
# Safety: Fails closed if the target tag tarball cannot be fetched.
# Example: bash tools/bump-brew-formula.sh v0.2.1
# @bootwitch:end

set -euo pipefail

BOOTWITCH_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$BOOTWITCH_ROOT"

dry_run=0
if test "${1:-}" = --dry-run; then
  dry_run=1
  shift
fi

target_tag=${1:-v$(tr -d '[:space:]' < "$BOOTWITCH_ROOT/VERSION")}

if test -z "${target_tag}"; then
  echo "error: cannot resolve target tag" >&2
  exit 1
fi

tarball_url="https://github.com/naomijnguyen/bootwitch/archive/refs/tags/${target_tag}.tar.gz"
if ! curl -fsI "$tarball_url" >/dev/null 2>&1; then
  echo "error: release tarball not available: ${tarball_url}" >&2
  exit 1
fi

formula_file="$BOOTWITCH_ROOT/Formula/bootwitch.rb"
release_sha=$(curl -Lfs "$tarball_url" | shasum -a 256 | awk '{print $1}')
release_version=${target_tag#v}

python3 - "$formula_file" "$target_tag" "$tarball_url" "$release_sha" "$release_version" <<'PY'
import pathlib
import re
import sys

path, tag, url, sha, version = sys.argv[1:]
text = pathlib.Path(path).read_text()
text = re.sub(r"^url '.*'\n", f"url '{url}'\n", text, count=1, flags=re.MULTILINE)
text = re.sub(r"^sha256 '.*'\n", f"sha256 '{sha}'\n", text, count=1, flags=re.MULTILINE)
text = re.sub(r"^  version '.*'\n", f"  version '{version}'\n", text, count=1, flags=re.MULTILINE)
pathlib.Path(path).write_text(text)
PY

if test "$dry_run" -eq 1; then
  echo "dry-run complete for ${target_tag}"
  exit 0
fi

echo "Updated ${formula_file} for ${target_tag}"
