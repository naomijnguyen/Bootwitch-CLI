#!/usr/bin/env bash
# @bootwitch:component
# Name: initialize_project.command
# Display Name: Initialize Project
# Type: wrapper
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-12
# Version: 0.2.0
# Purpose: Prepare folders, permissions, and generated component/function documentation.
# Module: modules/paths.sh, modules/permissions.sh, modules/documentation.sh
# Arguments: Optional --pause enables interactive checkpoints.
# Output: Permission changes and both documentation paths on stdout; checkpoints/errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, basename, find, and project_root/paths/log/checkpoint/permissions/header/documentation modules and their dependencies.
# Reads: Project marker, project.header, README, scripts, wrappers, and project modules.
# Writes: Runtime directories, README component section, technical readthrough, and script/wrapper executable permissions.
# Safety: Uses the wrapper location as its boundary and changes only this project.
# Example: bash wrappers/initialize_project.command
# @bootwitch:end

set -e
set -u
set -o pipefail

WRAPPER_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$WRAPPER_DIR/.." && pwd)

. "$PROJECT_ROOT/modules/project_root.sh"
PROJECT_ROOT=$(project_find_root "$WRAPPER_DIR")
. "$PROJECT_ROOT/modules/paths.sh"
. "$PROJECT_ROOT/modules/log.sh"
. "$PROJECT_ROOT/modules/checkpoint.sh"
. "$PROJECT_ROOT/modules/permissions.sh"
. "$PROJECT_ROOT/modules/header.sh"
. "$PROJECT_ROOT/modules/documentation.sh"

# Function: main
# Purpose: Perform the starter's visible, repeatable initialization sequence.
# Arguments: Optional --pause asks after each completed checkpoint.
# Output: Progress checkpoints plus permission and README update messages.
# How it works: Prepare folders, repair known runnable file permissions, rebuild
# generated README documentation, then run bounded syntax/structure checks.
# Safety: Every operation is anchored below the discovered project root.
main() {
  local runnable_file
  local relative_file

  export PROJECT_PAUSE_MODE=0
  case "${1:-}" in
    '') ;;
    --pause) PROJECT_PAUSE_MODE=1 ;;
    *) printf 'Usage: %s [--pause]\n' "$(basename -- "$0")" >&2; return 2 ;;
  esac

  project_set_paths "$PROJECT_ROOT"
  project_prepare_directories
  project_checkpoint 'Project folders are ready.'

  find "$PROJECT_ROOT/wrappers" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/src" \
    -type f \( -name '*.sh' -o -name '*.command' \) -print0 |
    while IFS= read -r -d '' runnable_file; do
      relative_file=${runnable_file#"$PROJECT_ROOT/"}
      project_make_executable "$relative_file"
    done
  project_checkpoint 'Runnable project files are executable.'

  project_build_readme
  project_checkpoint 'README and technical readthrough are refreshed.'

  test -f "$PROJECT_ROOT/project.header"
  test -f "$PROJECT_ROOT/.bootwitch/project.conf"
  find "$PROJECT_ROOT/modules" "$PROJECT_ROOT/scripts" "$PROJECT_ROOT/src" \
    -type f -name '*.sh' -print0 |
    while IFS= read -r -d '' runnable_file; do
      /bin/bash -n "$runnable_file"
    done
  find "$PROJECT_ROOT/wrappers" -type f -name '*.command' -print0 |
    while IFS= read -r -d '' runnable_file; do
      /bin/bash -n "$runnable_file"
    done
  project_checkpoint 'Project structure and shell syntax are verified.'
}

main "$@"
