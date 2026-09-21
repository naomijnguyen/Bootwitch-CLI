#!/usr/bin/env bash
# @bootwitch:component
# Name: adaptive_mounts
# Type: module
# Dates: Created: 2026-09-12 | Last Updated: 2026-09-21
# Version: 0.2.0
# Purpose: Compose project-root discovery, language detection, and documentation-provider selection.
# Wrapper: wrappers/build_readme.command, wrappers/initialize_project.command
# Arguments: Source this module; project_mount_select_context WRAPPER_PATH [PROJECT_PATH], or call its individual helpers.
# Output: Selected context variables and individual helper results.
# Returns: 0 for successful resolution and selection; nonzero for missing roots, unknown markers, or missing providers.
# Dependencies: Bash 3.2+, dirname, find, modules/project_root.sh.
# Reads: `.bootwitch/project.conf`, project headers and source files.
# Writes: None.
# Safety: Never imports project source code; only reads marker files and file metadata.
# Example: source modules/adaptive_mounts.sh
# @bootwitch:end

# Keep the upward walk in one generated-project module. The toolkit CLI has a
# separate, stricter explicit-path boundary and must not use this helper.
. "$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/project_root.sh"

# Function: project_mount_resolve_root
# Purpose: Walk upward from a start location to find the nearest Bootwitch project root.
# Arguments: Optional start path, defaults to the current directory.
# Output: Prints the resolved project root path.
# Returns: 0 when a valid marker is found, 1 if none is found.
project_mount_resolve_root() {
  project_find_root "${1:-$PWD}"
}

# Function: project_mount_select_context
# Purpose: Select the wrapper's project by default, or an explicitly requested project.
# Arguments: $1 wrapper location; optional $2 explicit project path.
# Output: Sets PROJECT_ROOT, PROJECT_LANGUAGE, PROJECT_DOCUMENTATION_MODULE.
# Returns: 0 on complete selection; nonzero if no root or provider is usable.
# Safety: Resolves a marked project and a regular provider; does not source it.
project_mount_select_context() {
  local wrapper_path=$1
  local project_path=${2:-$wrapper_path}

  PROJECT_ROOT=$(project_mount_resolve_root "$project_path") || return 1
  PROJECT_LANGUAGE=$(project_mount_detect_language "$PROJECT_ROOT") || return 1
  # ShellCheck cannot see that the sourcing wrapper reads this shared value.
  # shellcheck disable=SC2034
  PROJECT_DOCUMENTATION_MODULE=$(project_mount_documentation_module "$PROJECT_ROOT" "$PROJECT_LANGUAGE") || return 1
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
