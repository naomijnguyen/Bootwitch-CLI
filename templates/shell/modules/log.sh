#!/usr/bin/env bash
# @bootwitch:component
# Name: log
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Print one timestamped project message and optionally save it to a log.
# Wrapper: wrappers/run.command
# Arguments: Source this module; project_log LEVEL MESSAGE... or project_die MESSAGE...
# Output: Timestamped messages on stderr when called.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, date, dirname.
# Reads: PROJECT_LOG_FILE and its parent-directory availability.
# Writes: When called, appends PROJECT_LOG_FILE if its parent exists; no files written on source.
# Safety: Uses a fixed printf format and never evaluates message text.
# Example: source modules/log.sh
# @bootwitch:end

# Function: project_log
# Purpose: Write one consistently formatted project log line.
# Arguments: $1 is a level; $2 and later arguments form the message.
# Output: Prints one UTC timestamped line to stderr and optionally the log file.
# How it works: Save the level, shift it away, format the remaining message once,
# print it to stderr, then append the same text when PROJECT_LOG_FILE is ready.
# Safety: User text is data in a fixed printf format; it is never executed.
project_log() {
  local log_level=$1
  local log_line
  shift

  log_line=$(printf '%s [%s] %s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$log_level" "$*")
  printf '%s\n' "$log_line" >&2

  if test -n "${PROJECT_LOG_FILE:-}" && test -d "$(dirname -- "$PROJECT_LOG_FILE")"; then
    printf '%s\n' "$log_line" >> "$PROJECT_LOG_FILE"
  fi
}

# Function: project_die
# Purpose: Log one error and return a failing status to the caller.
# Arguments: All arguments form the error message.
# Output: One timestamped error line through project_log.
# Returns: Always 1; it does not directly kill or exit the shell.
project_die() {
  project_log error "$*"
  return 1
}
