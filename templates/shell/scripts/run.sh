#!/usr/bin/env bash
# @bootwitch:component
# Name: scripts/run.sh
# Type: wrapper
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.2
# Purpose: Forward to the project run wrapper through a stable script entry point.
# Arguments: Optional --pause; forwarded to wrappers/run.command.
# Output: Workflow checkpoints/errors on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, wrappers/run.command and its dependencies.
# Reads: wrappers/run.command and its source/module dependencies.
# Writes: Through the workflow: runtime directories, logs/project.log, and output/run-report.txt.
# Safety: Uses a project-relative target and preserves arguments and exit status.
# Example: bash scripts/run.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

PROJECT_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

# Utility: run.sh
# Purpose: Give users one stable command that launches the project's main file.
# How it works: exec replaces this wrapper with main.sh, while quoted "$@"
# forwards every argument exactly as it was received.
# Safety: The target is anchored to PROJECT_ROOT, not PATH or the caller's
# current working directory.
exec /bin/bash "$PROJECT_ROOT/wrappers/run.command" "$@"
