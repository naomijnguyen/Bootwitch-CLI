#!/usr/bin/env bash
# @bootwitch:component
# Name: make_executable.command
# Display Name: Make Script Executable
# Type: wrapper
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Provide a friendly entry point for changing one script's permission.
# Module: modules/permissions.sh
# Calls: project_make_executable
# Arguments: One PROJECT_RELATIVE_SCRIPT path.
# Output: Validated executable path on stdout; usage/errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, basename, modules/project_root.sh, modules/permissions.sh, chmod.
# Reads: Project-root marker, project_root/permissions modules, and target file metadata.
# Writes: Adds executable permission to the validated target.
# Safety: The module refuses unsafe, external, missing, or unexpected targets.
# Example: bash wrappers/make_executable.command src/main.sh
# @bootwitch:end

set -euo pipefail
IFS=$'\n\t'

WRAPPER_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$WRAPPER_DIR/.." && pwd)

. "$PROJECT_ROOT/modules/project_root.sh"
PROJECT_ROOT=$(project_find_root "$WRAPPER_DIR")
. "$PROJECT_ROOT/modules/permissions.sh"

test "$#" -eq 1 || {
  printf 'Usage: %s PROJECT_RELATIVE_SCRIPT\n' "$(basename -- "$0")" >&2
  exit 2
}

project_make_executable "$1"
