#!/usr/bin/env bash
# @bootwitch:component
# Name: permissions
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.1.1
# Purpose: Safely make one project-owned shell file directly runnable.
# Wrapper: wrappers/make_executable.command
# Arguments: Source with PROJECT_ROOT set; project_make_executable PROJECT_RELATIVE_SCRIPT.
# Output: Validated executable path on stdout when called.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, chmod, dirname.
# Reads: Target file, symlink status, and physical parent directory.
# Writes: When called, adds executable permission to one validated .sh or .command file.
# Safety: Refuses absolute paths, traversal, symlinks, directories, and escapes.
# Example: source modules/permissions.sh
# @bootwitch:end

# Function: project_make_executable
# Purpose: Add executable permission to one validated project shell file.
# Arguments: $1 is a project-relative .sh or .command path.
# Output: Prints the validated relative path after success.
# Returns: 0 on success, 1 for an unsafe/missing file, or 2 for bad usage.
# How it works: Reject suspicious path text, resolve the physical parent, prove
# that it remains beneath PROJECT_ROOT, then apply chmod +x to that exact file.
# Safety: Does not accept arbitrary absolute paths or follow a target symlink.
project_make_executable() {
  local relative_path=${1:-}
  local target_path
  local target_parent

  test "$#" -eq 1 || return 2
  case "$relative_path" in
    '' | /* | ../* | */../* | */..) return 1 ;;
    *.sh | *.command) ;;
    *) return 1 ;;
  esac

  target_path=$PROJECT_ROOT/$relative_path
  test -f "$target_path" || return 1
  test ! -L "$target_path" || return 1

  target_parent=$(CDPATH='' cd -P -- "$(dirname -- "$target_path")" 2>/dev/null && pwd) || return 1
  case "$target_parent/" in
    "$PROJECT_ROOT/"*) ;;
    *) return 1 ;;
  esac

  chmod +x "$target_path"
  printf 'Executable: %s\n' "$relative_path"
}
