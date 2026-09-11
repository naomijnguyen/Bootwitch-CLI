#!/usr/bin/env bash
# @bootwitch:component
# Name: run_with_pauses.command
# Display Name: Run Project With Pauses
# Type: wrapper
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Run the same project workflow and ask after every checkpoint.
# Module: modules/checkpoint.sh
# Calls: wrappers/run.command
# Arguments: None; supplies --pause to the run wrapper.
# Output: Workflow checkpoints and continuation prompts on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, an interactive terminal, wrappers/run.command and its dependencies.
# Reads: Terminal input, wrappers/run.command, src/main.sh, and workflow inputs.
# Writes: Through the workflow: runtime directories, project log, and report; may stop between steps.
# Safety: Pause behavior is explicit and refuses non-interactive input.
# Example: bash wrappers/run_with_pauses.command
# @bootwitch:end

set -euo pipefail
IFS=$'\n\t'

WRAPPER_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
exec /bin/bash "$WRAPPER_DIR/run.command" --pause "$@"
