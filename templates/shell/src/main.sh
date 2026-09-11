#!/usr/bin/env bash
# @bootwitch:component
# Name: main
# Type: script
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.2
# Purpose: Demonstrate project directories, logging, a report, and success checkpoints.
# Wrapper: wrappers/run.command
# Arguments: Optional --pause enables interactive checkpoint prompts.
# Output: Checkpoints/log messages on stderr; report written to output/run-report.txt.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, basename, mkdir, date, uname, awk, grep, and the sourced project modules.
# Reads: .bootwitch/project.conf, project.header, and paths/log/checkpoint/platform/header modules.
# Writes: Runtime directories, appended logs/project.log, and overwritten output/run-report.txt.
# Safety: Derives write paths from the discovered project root; pause mode requires a terminal.
# Example: bash src/main.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# Bootstrap: this small search is embedded because a moved script must find the
# project before it knows where the reusable project_root module lives.
find_root_for_this_script() {
  local search_dir=$SCRIPT_DIR
  local parent_dir

  while :; do
    if test -f "$search_dir/.bootwitch/project.conf"; then
      printf '%s\n' "$search_dir"
      return 0
    fi
    test "$search_dir" != / || break
    parent_dir=$(dirname -- "$search_dir")
    test "$parent_dir" != "$search_dir" || break
    search_dir=$parent_dir
  done

  printf 'main: cannot find the Bootwitch project root\n' >&2
  return 1
}

PROJECT_ROOT=$(find_root_for_this_script)

. "$PROJECT_ROOT/modules/paths.sh"
. "$PROJECT_ROOT/modules/log.sh"
. "$PROJECT_ROOT/modules/checkpoint.sh"
. "$PROJECT_ROOT/modules/platform.sh"
. "$PROJECT_ROOT/modules/header.sh"


# @bootwitch:function
# Name: project_create_report
# Purpose: Create a small visible report demonstrating a completed project task.
# Arguments: None.
# Output: Writes output/run-report.txt.
# Returns: The status of writing the report.
# How it works: Read safe project facts, add platform and UTC time, then render
# one text file beneath PROJECT_OUTPUT_DIR.
# Safety: The output path is fixed beneath the verified project root.
# @bootwitch:end
project_create_report() {
  local header_file=$PROJECT_ROOT/project.header
  local report_file=$PROJECT_OUTPUT_DIR/run-report.txt

  {
    printf 'Project: %s\n' "$(project_header_get "$header_file" PROJECT_NAME)"
    printf 'Purpose: %s\n' "$(project_header_get "$header_file" PROJECT_PURPOSE)"
    printf 'Platform: %s\n' "$(project_platform)"
    printf 'Created: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$report_file"
}

# @bootwitch:function
# Name: project_verify_report
# Purpose: Confirm the demonstration report exists and contains project data.
# Arguments: None.
# Output: Prints nothing on success.
# Returns: 0 when valid or a non-zero grep/test status when incomplete.
# How it works: Check the file, then search for the expected Project label.
# Safety: Reads only the fixed report beneath PROJECT_OUTPUT_DIR.
# @bootwitch:end
project_verify_report() {
  local report_file=$PROJECT_OUTPUT_DIR/run-report.txt
  test -f "$report_file"
  grep -q '^Project: ' "$report_file"
}

# Function: main
# Purpose: Hold the script's actual workflow in one easy-to-find function.
# Arguments: Optional --pause enables a question after successful checkpoints.
# Output: Checkpoints on stderr, plus a report and project log.
# How it works: Prepare directories, create a report, verify it, and place each
# checkpoint after the function it confirms.
main() {
  export PROJECT_PAUSE_MODE=0
  case "${1:-}" in
    '') ;;
    --pause) PROJECT_PAUSE_MODE=1 ;;
    *) printf 'Usage: %s [--pause]\n' "$(basename -- "$0")" >&2; return 2 ;;
  esac

  project_set_paths "$PROJECT_ROOT"
  project_prepare_directories
  project_checkpoint 'Project folders are ready.'

  project_log info '{{PROJECT_NAME}} workflow started.'
  project_create_report
  project_checkpoint 'Demonstration report was created.'

  project_verify_report
  project_checkpoint 'Demonstration report was verified.'

  project_log info "Report: $PROJECT_OUTPUT_DIR/run-report.txt"
}

# Execution stays at the bottom so the definitions above are easy to navigate.
# Quoted "$@" preserves every original argument, including spaces.
main "$@"
