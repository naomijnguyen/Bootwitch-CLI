#!/usr/bin/env bash
# @bootwitch:component
# Name: log-maintenance.sh
# Type: script
# Dates: Created: 2026-09-12 | Last Updated: 2026-09-12
# Version: 0.2.0
# Purpose: Centralize maintenance note recording in changelog and release notes.
# Arguments: --version <x.y.z>, --changelog <text>, optional --release-note <text>.
# Output: Updated CHANGELOG.md and matching docs/release-notes/v<version>.md.
# Returns: 0 on success; nonzero on invalid input or missing documentation files.
# Dependencies: Bash, awk, grep, date, mktemp, mv.
# Reads: CHANGELOG.md and an existing docs/release-notes/v<version>.md.
# Writes: CHANGELOG.md and the matching release note through sibling temporary files.
# Safety: Validates version syntax, requires known files, and skips duplicate notes.
# Example: bash tools/log-maintenance.sh --version 0.2.2 --changelog "Refined adaptive mounts"
# @bootwitch:end

set -e
set -u
set -o pipefail

show_help() {
  cat <<'EOF'
Usage:
  tools/log-maintenance.sh --version <x.y.z> --changelog <text> [--release-note <text>]

Examples:
  bash tools/log-maintenance.sh --version 0.2.2 --changelog "Added adaptive mount metadata fallback."
  bash tools/log-maintenance.sh \
    --version 0.2.2 \
    --changelog "Fixed lint-safe dynamic source handling." \
    --release-note "Post-release fix: fixed adaptive mount metadata and dynamic source lint handling."
EOF
}

ROOT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
CHANGELOG_FILE="$ROOT_DIR/CHANGELOG.md"

VERSION=""
CHANGELOG_NOTE=""
RELEASE_NOTE=""

while test "$#" -gt 0; do
  case "$1" in
    --version)
      if test "$#" -lt 2 || test -z "${2:-}"; then
        echo "error: --version requires a value" >&2
        exit 1
      fi
      VERSION=$2
      shift 2
      ;;
    --changelog)
      if test "$#" -lt 2 || test -z "${2:-}"; then
        echo "error: --changelog requires a value" >&2
        exit 1
      fi
      CHANGELOG_NOTE=$2
      shift 2
      ;;
    --release-note)
      if test "$#" -lt 2; then
        echo "error: --release-note requires a value" >&2
        exit 1
      fi
      RELEASE_NOTE=$2
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "error: unsupported arg: $1" >&2
      show_help
      exit 1
      ;;
  esac
done

if test -z "$VERSION" || test -z "$CHANGELOG_NOTE"; then
  echo "error: --version and --changelog are required" >&2
  show_help
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]]; then
  echo "error: --version must be a safe semantic version such as 0.2.1" >&2
  exit 1
fi

if test -z "$RELEASE_NOTE"; then
  RELEASE_NOTE=$CHANGELOG_NOTE
fi

if test ! -f "$CHANGELOG_FILE"; then
  echo "error: missing changelog file: $CHANGELOG_FILE" >&2
  exit 1
fi

release_file="$ROOT_DIR/docs/release-notes/v${VERSION}.md"
if test ! -f "$release_file"; then
  legacy_release_file="$ROOT_DIR/docs/release-notes/${VERSION}.md"
  if test -f "$legacy_release_file"; then
    release_file=$legacy_release_file
  else
    echo "error: missing release note: $release_file" >&2
    exit 1
  fi
fi

DATE_STAMP=$(date +%Y-%m-%d)
UNRELEASED_BULLET="- [${DATE_STAMP}] ${CHANGELOG_NOTE}"
RELEASE_BULLET="- ${RELEASE_NOTE}"

tmp_changelog=""
tmp_release=""
cleanup() {
  test -z "$tmp_changelog" || rm -f "$tmp_changelog"
  test -z "$tmp_release" || rm -f "$tmp_release"
}
trap cleanup EXIT

if ! grep -Fq -- "] ${CHANGELOG_NOTE}" "$CHANGELOG_FILE"; then
  tmp_changelog=$(mktemp "${CHANGELOG_FILE}.tmp.XXXXXX")
  awk -v bullet="$UNRELEASED_BULLET" '
  /^## Unreleased/ {
    print $0
    if (!added) {
      print ""
      print bullet
      added = 1
    }
    next
  }
  {
    print
  }
END {
  if (!added) {
    print ""
    print "## Unreleased"
    print ""
    print bullet
  }
}
  ' "$CHANGELOG_FILE" > "$tmp_changelog"

  mv "$tmp_changelog" "$CHANGELOG_FILE"
  tmp_changelog=""
fi

if ! grep -Fqx -- "$RELEASE_BULLET" "$release_file"; then
  tmp_release=$(mktemp "${release_file}.tmp.XXXXXX")
  awk -v bullet="$RELEASE_BULLET" '
    /^## Post-release maintenance$/ {
      print
      if (!section_seen) {
        print ""
        print bullet
        section_seen = 1
        skip_blank = 1
      }
      next
    }
    skip_blank && /^$/ {
      skip_blank = 0
      next
    }
    /^## Validation$/ && !section_seen {
      print "## Post-release maintenance"
      print ""
      print bullet
      print ""
      section_seen = 1
    }
    {
      print
    }
    END {
      if (!section_seen) {
        print ""
        print "## Post-release maintenance"
        print ""
        print bullet
      }
    }
  ' "$release_file" > "$tmp_release"
  mv "$tmp_release" "$release_file"
  tmp_release=""
fi

printf 'Logged maintenance note for v%s:\n' "$VERSION"
printf '  - %s\n' "$CHANGELOG_NOTE"
