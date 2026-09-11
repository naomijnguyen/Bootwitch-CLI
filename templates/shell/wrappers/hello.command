#!/usr/bin/env bash
# @bootwitch:component
# Name: hello.command
# Display Name: Hello Bootwitch
# Type: wrapper
# Dates: Created: 2026-09-09 (first documented; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Provide a friendly first-click welcome for a generated project.
# Arguments: None.
# Output: Bootwitch welcome text on stdout.
# Returns: 0 when the greeting is printed successfully.
# Dependencies: Bash 3.2+.
# Reads: None.
# Writes: None.
# Safety: Read-only; performs no filesystem, Git, network, or service changes.
# Example: bash wrappers/hello.command
# @bootwitch:end

set -euo pipefail
IFS=$'\n\t'

printf 'Hello from Bootwitch.\n'
printf 'Welcome to the coven.\n'
