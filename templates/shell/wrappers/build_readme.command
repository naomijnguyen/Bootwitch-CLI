#!/usr/bin/env bash
# @bootwitch:component
# Name: build_readme.command
# Display Name: Build README
# Type: wrapper
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-12
# Version: 0.2.0
# Purpose: Refresh the README component reference and separate technical readthrough.
# Module: modules/adaptive_mounts.sh, modules/paths.sh, modules/header.sh, modules/documentation.sh
# Calls: project_build_readme
# Arguments: None.
# Output: Updated README and technical-readthrough paths on stdout; errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mkdir, modules/adaptive_mounts.sh, paths, header, and documentation modules plus their dependencies.
# Reads: Project-root marker, project.header, README.md, project modules, and annotated scripts.
# Writes: Runtime directories, staged documentation, the marked README section, and docs/technical-readthrough.md.
# Safety: Preserves authored README text; replaces the generated readthrough; stages both before individual publication.
# Example: bash wrappers/build_readme.command
# @bootwitch:end

set -e
set -u
set -o pipefail

WRAPPER_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
. "$WRAPPER_DIR/../modules/adaptive_mounts.sh"
if ! PROJECT_ROOT=$(project_mount_resolve_root "$PWD"); then
  if ! PROJECT_ROOT=$(project_mount_resolve_root "$WRAPPER_DIR"); then
    exit 1
  fi
fi
if ! PROJECT_LANGUAGE=$(project_mount_detect_language "$PROJECT_ROOT"); then
  exit 1
fi
if ! PROJECT_DOCUMENTATION_MODULE=$(project_mount_documentation_module "$PROJECT_ROOT" "$PROJECT_LANGUAGE"); then
  exit 1
fi

. "$PROJECT_ROOT/modules/paths.sh"
. "$PROJECT_ROOT/modules/header.sh"
# shellcheck disable=SC1090
. "$PROJECT_DOCUMENTATION_MODULE"

project_set_paths "$PROJECT_ROOT"
project_prepare_directories
project_build_readme
