#!/usr/bin/env bash
# @bootwitch:component
# Name: new_script.command
# Display Name: Create Annotated Script
# Type: wrapper
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.2.1
# Purpose: Create an annotated project script and refresh its README reference.
# Calls: scripts/new-script.sh
# Arguments: NAME [scripts|src|tests]; forwarded to the generator.
# Output: Created script and updated README paths on stdout; errors/retry instructions on stderr.
# Returns: 0 when creation and refresh succeed; 3 for a created script with failed refresh; other nonzero statuses for creation errors.
# Dependencies: Bash 3.2+, dirname, scripts/new-script.sh and its dependencies.
# Reads: Generator, script template, README builder, metadata, and project annotations.
# Writes: Through the generator: new executable script, runtime directories, temporary files, and generated README section.
# Safety: The underlying generator validates names and refuses overwrites.
# Example: bash wrappers/new_script.command sample-task scripts
# @bootwitch:end

set -euo pipefail
IFS=$'\n\t'

WRAPPER_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$WRAPPER_DIR/.." && pwd)
exec /bin/bash "$PROJECT_ROOT/scripts/new-script.sh" "$@"
