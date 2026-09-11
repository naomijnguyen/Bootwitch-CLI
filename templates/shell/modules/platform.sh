#!/usr/bin/env bash
# @bootwitch:component
# Name: platform
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Convert the operating-system kernel name into a friendly label.
# Wrapper: wrappers/run.command
# Arguments: Source this module; project_platform takes no arguments.
# Output: Prints macOS, Linux, or unsupported followed by the kernel name.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, uname.
# Reads: Operating-system kernel name from uname.
# Writes: None; defines functions when sourced.
# Safety: Read-only; reports the platform without changing system state.
# Example: source modules/platform.sh
# @bootwitch:end

# Function: project_platform
# Purpose: Give scripts a small portable platform check.
# Arguments: None.
# Output: One friendly platform label.
# Returns: 0 for macOS/Linux or 1 for an unrecognized system.
project_platform() {
  case "$(uname -s)" in
    Darwin) printf 'macOS\n' ;;
    Linux) printf 'Linux\n' ;;
    *) printf 'unsupported:%s\n' "$(uname -s)"; return 1 ;;
  esac
}
