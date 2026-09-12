#!/usr/bin/env bash
# @bootwitch:component
# Name: build_readme.command
# Display Name: Build README
# Type: wrapper
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-12
# Version: 0.2.0
# Purpose: Refresh the README component reference and separate technical readthrough.
# Module: modules/documentation.sh
# Calls: project_build_readme
# Arguments: None.
# Output: Updated README and technical-readthrough paths on stdout; errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mkdir, project_root/paths/header/documentation modules and their dependencies.
# Reads: Project-root marker, project.header, README.md, project modules, and annotated scripts.
# Writes: Runtime directories, staged documentation, the marked README section, and docs/technical-readthrough.md.
# Safety: Preserves authored README text; replaces the generated readthrough; stages both before individual publication.
# Example: bash wrappers/build_readme.command
# @bootwitch:end

set -e
set -u
set -o pipefail

WRAPPER_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$WRAPPER_DIR/.." && pwd)

. "$PROJECT_ROOT/modules/project_root.sh"
PROJECT_ROOT=$(project_find_root "$WRAPPER_DIR")
. "$PROJECT_ROOT/modules/paths.sh"
. "$PROJECT_ROOT/modules/header.sh"
. "$PROJECT_ROOT/modules/documentation.sh"

project_set_paths "$PROJECT_ROOT"
project_prepare_directories
project_build_readme
