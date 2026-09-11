#!/usr/bin/env bash
# @bootwitch:component
# Name: checkpoint
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Mark completed steps and optionally ask before continuing.
# Wrapper: wrappers/run_with_pauses.command
# Arguments: Source with project_log available; project_checkpoint MESSAGE...
# Output: Prints a checkpoint and, in pause mode, a Continue question.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, modules/log.sh and its dependencies; terminal for pause mode.
# Reads: PROJECT_PAUSE_MODE; terminal input when pause mode is enabled.
# Writes: When called, appends the configured project log through project_log.
# Safety: Pause mode refuses non-interactive input instead of hanging automation.
# Example: source modules/checkpoint.sh
# @bootwitch:end

# Function: project_checkpoint
# Purpose: Make the last successfully completed workflow step visible.
# Arguments: All arguments form the checkpoint message.
# Output: Logs one checkpoint; optionally prints and reads a continuation prompt.
# Returns: 0 to continue, 1 when the user stops, or 2 without an interactive tty.
# How it works: Log first, then consult PROJECT_PAUSE_MODE. Enter or y continues;
# n stops cleanly. Normal mode never asks for input.
# Safety: Prompts only when explicitly enabled and stdin is a terminal.
project_checkpoint() {
  local answer

  project_log checkpoint "$*"
  test "${PROJECT_PAUSE_MODE:-0}" = 1 || return 0

  test -t 0 || {
    project_log error 'Pause mode requires an interactive terminal.'
    return 2
  }

  printf 'Continue? [Y/n] ' >&2
  IFS= read -r answer
  case "$answer" in
    '' | y | Y | yes | YES | Yes) return 0 ;;
    *) project_log info 'Stopped at checkpoint by user request.'; return 1 ;;
  esac
}
