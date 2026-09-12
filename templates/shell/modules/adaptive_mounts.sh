#!/usr/bin/env bash
# @bootwitch:component
# Name: adaptive_mounts
# Type: module
# Dates: Created: 2026-09-12
# Version: 0.1.1
# Purpose: Resolve project mounts adaptively, detect project language, and select the documentation provider.
# Wrapper: wrappers/build_readme.command, wrappers/initialize_project.command
# Arguments: Source this module; project_mount_resolve_root [PATH], project_mount_detect_language ROOT, project_mount_documentation_module ROOT [LANGUAGE].
# Output: Project root path, detected language, and selected documentation module path.
# Returns: 0 for successful resolution and selection; nonzero for missing roots, unknown markers, or missing providers.
# Dependencies: Bash 3.2+, dirname, find.
# Reads: `.bootwitch/project.conf`, project headers and source files.
# Writes: None.
# Safety: Never imports project source code; only reads marker files and file metadata.
# Example: source modules/adaptive_mounts.sh
# @bootwitch:end

# Function: project_mount_resolve_root
# Purpose: Walk upward from a start location to find the nearest Bootwitch project root.
# Arguments: Optional start path, defaults to the current directory.
# Output: Prints the resolved project root path.
# Returns: 0 when a valid marker is found, 1 if none is found.
project_mount_resolve_root() {
  local start_path=${1:-$PWD}
  local current_dir
  local parent_dir

  if test -f "$start_path"; then
    start_path=$(dirname -- "$start_path")
  fi

  current_dir=$(CDPATH='' cd -P -- "$start_path" 2>/dev/null && pwd) || {
    printf 'adaptive mounts: cannot inspect starting path: %s\n' "$start_path" >&2
    return 1
  }

  while :; do
    if test -f "$current_dir/.bootwitch/project.conf"; then
      printf '%s\n' "$current_dir"
      return 0
    fi

    test "$current_dir" != / || break
    parent_dir=$(dirname -- "$current_dir")
    test "$parent_dir" != "$current_dir" || break
    current_dir=$parent_dir
  done

  printf 'adaptive mounts: no .bootwitch/project.conf found above %s\n' "$start_path" >&2
  return 1
}

# Function: project_mount_detect_language
# Purpose: Infer documentation language from markers and source file types.
# Arguments: $1 is an absolute project root.
# Output: One of shell, python, or unknown.
# Returns: 0 on any successful classification, 2 when the root is not valid.
project_mount_detect_language() {
  local project_root=$1
  local has_shell=0
  local has_python=0

  test -f "$project_root/.bootwitch/project.conf" || {
    printf 'adaptive mounts: invalid project root: %s\n' "$project_root" >&2
    return 2
  }

  # Strong file markers first.
  if test -f "$project_root/src/main.py" || test -f "$project_root/scripts/main.py" || \
     test -f "$project_root/src/observability.py"; then
    printf 'python\n'
    return 0
  fi
  if test -f "$project_root/src/main.sh" || test -f "$project_root/scripts/main.sh"; then
    printf 'shell\n'
    return 0
  fi

  # Fallback by file-type scan across the runnable source families.
  if test -d "$project_root/src"; then
    test -n "$(find "$project_root/src" -type f \( -name '*.sh' -o -name '*.command' \) 2>/dev/null | head -n 1)" && has_shell=1
    test -n "$(find "$project_root/src" -type f -name '*.py' 2>/dev/null | head -n 1)" && has_python=1
  fi
  if test -d "$project_root/scripts"; then
    test -n "$(find "$project_root/scripts" -type f \( -name '*.sh' -o -name '*.command' \) 2>/dev/null | head -n 1)" && has_shell=1
    test -n "$(find "$project_root/scripts" -type f -name '*.py' 2>/dev/null | head -n 1)" && has_python=1
  fi
  if test -d "$project_root/tests"; then
    test -n "$(find "$project_root/tests" -type f \( -name '*.sh' -o -name '*.command' \) 2>/dev/null | head -n 1)" && has_shell=1
    test -n "$(find "$project_root/tests" -type f -name '*.py' 2>/dev/null | head -n 1)" && has_python=1
  fi

  if test "$has_python" -eq 1 && test "$has_shell" -eq 0; then
    printf 'python\n'
    return 0
  fi
  if test "$has_shell" -eq 1 && test "$has_python" -eq 0; then
    printf 'shell\n'
    return 0
  fi
  if test "$has_shell" -eq 1 && test "$has_python" -eq 1; then
    printf 'shell\n'
    return 0
  fi

  printf 'unknown\n'
  return 0
}

# Function: project_mount_documentation_module
# Purpose: Select the documentation module matching the detected language.
# Arguments: $1 is an absolute project root; optional $2 language.
# Output: Prints the documentation module path.
# Returns: 0 when a loadable provider exists, 1 when missing.
project_mount_documentation_module() {
  local project_root=$1
  local language=${2:-$(project_mount_detect_language "$project_root")}
  local documentation_module

  case "$language" in
    shell)
      documentation_module=$project_root/modules/documentation.sh
      ;;
    python)
      if test -f "$project_root/modules/documentation.py.sh" && test ! -L "$project_root/modules/documentation.py.sh"; then
        documentation_module=$project_root/modules/documentation.py.sh
      elif test -f "$project_root/modules/documentation.sh" && test ! -L "$project_root/modules/documentation.sh"; then
        printf 'adaptive mounts: python project detected; using shell-based documentation provider in %s\n' "$project_root/modules/documentation.sh" >&2
        documentation_module=$project_root/modules/documentation.sh
      else
        printf 'adaptive mounts: python documentation module missing for %s\n' "$project_root" >&2
        return 1
      fi
      ;;
    unknown)
      printf 'adaptive mounts: cannot infer language for %s; defaulting to shell documentation provider\n' "$project_root" >&2
      documentation_module=$project_root/modules/documentation.sh
      ;;
    *)
      printf 'adaptive mounts: unsupported language %s for %s\n' "$language" "$project_root" >&2
      return 1
      ;;
  esac

  if test -f "$documentation_module" && test ! -L "$documentation_module"; then
    printf '%s\n' "$documentation_module"
    return 0
  fi

  printf 'adaptive mounts: documentation module not usable: %s\n' "$documentation_module" >&2
  return 1
}
