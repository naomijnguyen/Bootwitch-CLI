#!/usr/bin/env bash
# @bootwitch:component
# Name: run.command
# Display Name: Run Project
# Type: wrapper
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Start the project through one friendly, stable entry point.
# Module: modules/checkpoint.sh
# Calls: src/main.sh
# Arguments: Optional --pause; forwarded to src/main.sh.
# Output: Workflow checkpoints/log messages on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, src/main.sh and its dependencies.
# Reads: src/main.sh, project.header, project-root marker, and workflow modules.
# Writes: Through main.sh: runtime directories, logs/project.log, and output/run-report.txt.
# Safety: Resolves main.sh from this wrapper's project rather than PATH.
# Example: bash wrappers/run.command
# @bootwitch:end

set -euo pipefail
IFS=$'\n\t'

WRAPPER_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$WRAPPER_DIR/.." && pwd)

exec /bin/bash "$PROJECT_ROOT/src/main.sh" "$@"
