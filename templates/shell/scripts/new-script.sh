#!/usr/bin/env bash
# @bootwitch:component
# Name: new-script
# Type: script
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-21
# Version: 0.4.0
# Purpose: Create one annotated Bash or opt-in Python script and refresh both documentation views.
# Wrapper: wrappers/new_script.command
# Arguments: NAME [scripts|src|tests] [--language bash|python]; defaults to scripts and Bash.
# Output: Created script and refreshed README/readthrough paths on stdout; errors and retry instructions on stderr.
# Returns: 0 when creation and refresh succeed; 3 when the script exists but refresh failed; other nonzero statuses for creation errors.
# Dependencies: Bash 3.2+, dirname, basename, sed, date, mktemp, chmod, cat, rm; Python 3 only for Python output; wrappers/build_readme.command and its dependencies.
# Reads: Script template; README builder reads project metadata, README, and annotated scripts.
# Writes: New executable script, temporary files, runtime directories, README component section, and technical readthrough.
# Safety: Validates name and area, refuses existing destinations, and cleans up the exact allocated temporary file.
# Example: bash scripts/new-script.sh word-count scripts --language python
# @bootwitch:end

set -e
set -u
set -o pipefail

PROJECT_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

# Function: usage
# Purpose: Show the supported interface for creating a project script.
# Arguments: None.
# Output: Prints usage text to stdout.
usage() {
  printf 'Usage: %s NAME [scripts|src|tests] [--language bash|python]\n' "$(basename -- "$0")"
}

# Function: valid_script_name
# Purpose: Confirm NAME can safely become one shell filename.
# Arguments: $1 is the name without its optional matching extension.
# Output: None.
# Returns: 0 when the name begins with a letter and contains only letters,
# numbers, underscores, or hyphens; otherwise 1.
valid_script_name() {
  candidate=$1
  case "$candidate" in
    [A-Za-z]*) ;;
    *) return 1 ;;
  esac
  case "$candidate" in
    *[!A-Za-z0-9_-]*) return 1 ;;
    *) return 0 ;;
  esac
}

# Function: main
# Purpose: Create one executable .sh or .py file from the canonical project template.
# Arguments: $1 script name; optional area and --language bash|python.
# Output: Prints created script and updated README paths; reports partial success on refresh failure.
# How it works: Validates both path components, renders into a unique temporary
# file beside the destination, makes it executable, publishes it with a no-clobber write, then
# invokes the README wrapper in a separate Bash process.
# Safety: Only scripts, src, or tests are accepted; existing paths and symlinks
# are refused; cleanup is limited to the exact file returned by mktemp.
main() {
  test "$#" -ge 1 || { usage >&2; return 2; }

  script_input=$1
  shift
  script_area=scripts
  script_language=bash
  area_seen=0
  language_seen=0
  while test "$#" -gt 0; do
    case $1 in
      scripts | src | tests)
        test "$area_seen" -eq 0 || { usage >&2; return 2; }
        script_area=$1
        area_seen=1
        shift ;;
      --language)
        test "$language_seen" -eq 0 && test "$#" -ge 2 || { usage >&2; return 2; }
        script_language=$2
        language_seen=1
        shift 2 ;;
      *) usage >&2; return 2 ;;
    esac
  done

  case $script_language in
    bash) script_extension='sh'; script_name=${script_input%.sh} ;;
    python) script_extension='py'; script_name=${script_input%.py} ;;
    *) printf 'new-script: language must be bash or python\n' >&2; return 2 ;;
  esac

  valid_script_name "$script_name" || {
    printf 'new-script: invalid script name: %s\n' "$script_input" >&2
    return 2
  }

  SCRIPT_TEMPLATE=$PROJECT_ROOT/.bootwitch/templates/script.$script_extension.tpl
  test -f "$SCRIPT_TEMPLATE" || {
    printf 'new-script: template is missing: %s\n' "$SCRIPT_TEMPLATE" >&2
    return 1
  }

  if test -L "$PROJECT_ROOT/$script_area" || test ! -d "$PROJECT_ROOT/$script_area"; then
    printf 'new-script: destination area must be a real project directory: %s\n' "$script_area" >&2
    return 1
  fi
  if test "$script_language" = python && ! command -v python3 >/dev/null 2>&1; then
    printf 'new-script: Python 3 is needed to run the Python starter; no script created\n' >&2
    return 1
  fi
  destination=$PROJECT_ROOT/$script_area/$script_name.$script_extension
  if test -e "$destination" || test -L "$destination"; then
    printf 'new-script: destination already exists: %s\n' "$destination" >&2
    return 1
  fi

  generated_tmp=$(mktemp "$PROJECT_ROOT/$script_area/.new-script-${script_name}.XXXXXX")
  cleanup_generated=$generated_tmp
  trap 'test -n "${cleanup_generated:-}" && test -f "$cleanup_generated" && rm -f "$cleanup_generated"' EXIT
  trap 'exit 1' HUP INT TERM

  script_date=$(date +%Y-%m-%d)
  sed \
    -e "s/{{SCRIPT_NAME}}/$script_name/g" \
    -e "s/{{SCRIPT_AREA}}/$script_area/g" \
    -e "s/{{SCRIPT_CREATED_DATE}}/$script_date/g" \
    -e "s/{{SCRIPT_UPDATED_DATE}}/$script_date/g" \
    "$SCRIPT_TEMPLATE" > "$generated_tmp"
  chmod +x "$generated_tmp"
  # Bash noclobber reserves a regular filename without replacing a late arrival.
  # A failed write leaves the partial file for inspection; never remove a rival's file.
  if ! (set -C; cat "$generated_tmp" > "$destination"); then
    printf 'new-script: could not create destination; inspect before retrying: %s\n' "$destination" >&2
    return 1
  fi
  if ! chmod +x "$destination" || test ! -x "$destination"; then
    printf 'new-script: file created but executable setup failed: %s\n' "$destination" >&2
    return 1
  fi
  rm -f "$generated_tmp"

  cleanup_generated=
  trap - EXIT HUP INT TERM
  printf 'Created %s/%s.%s\n' "$script_area" "$script_name" "$script_extension"

  # Creation is complete: a documentation failure must never remove the script.
  # A separate Bash process retains the builder's own strict error handling.
  if /bin/bash "$PROJECT_ROOT/wrappers/build_readme.command"; then
    return 0
  fi
  printf 'new-script: Script created, but documentation refresh failed: %s/%s.%s\n' "$script_area" "$script_name" "$script_extension" >&2
  printf 'Fix the README builder error above, then retry: bash %q\n' "$PROJECT_ROOT/wrappers/build_readme.command" >&2
  return 3
}

main "$@"
