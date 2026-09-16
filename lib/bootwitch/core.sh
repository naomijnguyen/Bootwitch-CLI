#!/usr/bin/env bash
# @bootwitch:component
# Name: lib/bootwitch/core.sh
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-16
# Version: 0.4.0
# Purpose: Implement the Bootwitch CLI dispatcher, workspace setup, project and script generation, prompts, and diagnostics.
# Arguments: Source with BOOTWITCH_HOME set; bootwitch_main receives CLI arguments.
# Output: Command results, setup prompts, progress, and diagnostics when functions are called.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Python 3 for init/summon publication; Bash 3.2+, tr, sed, grep, find, mktemp, mkdir, cp, cat, chmod, rm, date; uname for diagnostics; Git unless --no-git.
# Reads: VERSION when sourced; bundled templates, selected generated-project markers, and environment when functions run.
# Writes: Creation functions write staged projects or delegate one script creation to a selected generated project.
# Safety: Validates names/options and project boundaries; dry-run returns before project writes; cleanup targets allocated staging.
# Example: Loaded by the toolkit or its tests; see function contracts above.
# @bootwitch:end

# Read version metadata from the trusted installation root. This file is read as
# text; it is never sourced or evaluated as shell code.
BOOTWITCH_VERSION=$(tr -d '[:space:]' < "$BOOTWITCH_HOME/VERSION")

# Function: bootwitch_usage
# Command: bootwitch help
# Purpose: Show the public commands and their accepted options.
# Arguments: None.
# Output: Prints a static usage block to stdout.
# Safety: Read-only; performs no filesystem, Git, or network operations.
bootwitch_usage() {
  cat <<'EOF'
Usage:
  bootwitch setup [--workspace PATH] [--dry-run]
  bootwitch init NAME [--template base|shell] [--root PATH] [--no-git] [--dry-run]
  bootwitch summon
  bootwitch new-script NAME [scripts|src|tests] [--project PATH]
  bootwitch list
  bootwitch templates
  bootwitch wizard
  bootwitch doctor
  bootwitch help
EOF
}

# Function: bootwitch_error
# Purpose: Give every CLI error the same recognizable "bootwitch:" prefix.
# Arguments: All arguments are joined into one human-readable message.
# Output: Prints one line to stderr.
# How it works: "$*" combines the arguments after the fixed printf format.
# Safety: User text is data, not the printf format, so it cannot become a printf
# instruction.
bootwitch_error() {
  printf 'bootwitch: %s\n' "$*" >&2
}

# Function: bootwitch_color
# Purpose: Print one ANSI color code only when stdout is an interactive terminal.
# Arguments: $1 is a small allowlisted color name.
# Output: Prints an ANSI escape sequence or nothing.
# Safety: Uses a fixed color allowlist; caller text is never evaluated.
bootwitch_color() {
  test -t 1 || return 0
  case "${1:-}" in
    green) printf '\033[32m' ;;
    cyan) printf '\033[36m' ;;
    yellow) printf '\033[33m' ;;
    reset) printf '\033[0m' ;;
  esac
}

# Function: bootwitch_note
# Purpose: Print one friendly setup progress line.
# Arguments: All arguments are joined into one human-readable message.
# Output: Prints a colored message to stdout when interactive, plain otherwise.
# Safety: Read-only display helper.
bootwitch_note() {
  printf '%sbootwitch:%s %s\n' "$(bootwitch_color cyan)" "$(bootwitch_color reset)" "$*"
}

# Function: bootwitch_expand_path
# Purpose: Convert ~ or ~/... into the current user's home-directory path.
# Arguments: $1 is path text supplied as a default or through --root.
# Output: Prints the expanded path to stdout.
# How it works: A case statement recognizes only "~" and the "~/" prefix; all
# other paths pass through unchanged.
# Safety: Does not use eval, so shell punctuation in input remains inert data.
bootwitch_expand_path() {
  path_value=$1
  case "$path_value" in
    \~) printf '%s\n' "$HOME" ;;
    \~/*) printf '%s/%s\n' "$HOME" "${path_value#'~/'}" ;;
    *) printf '%s\n' "$path_value" ;;
  esac
}

# Function: bootwitch_default_workspace
# Purpose: Return the conventional Bootwitch workspace for the current user.
# Arguments: None.
# Output: Prints $HOME/Bootwitch.
# Safety: Derives the path from HOME and performs no filesystem operations.
bootwitch_default_workspace() {
  printf '%s/Bootwitch\n' "$HOME"
}

# Function: bootwitch_default_projects_root
# Purpose: Return the conventional parent directory for Bootwitch projects.
# Arguments: None.
# Output: Prints $HOME/Bootwitch/Projects.
# Safety: Derives the path from HOME and performs no filesystem operations.
bootwitch_default_projects_root() {
  printf '%s/Projects\n' "$(bootwitch_default_workspace)"
}

# Function: bootwitch_setup
# Command: bootwitch setup [--workspace PATH] [--dry-run]
# Purpose: Prepare the minimal user-owned Bootwitch workspace convention.
# Arguments: Optional workspace override and dry-run flag.
# Output: Prints the directories that would be prepared or the ready workspace.
# Returns: 0 on success, 1 for an unsafe path, or 2 for invalid usage.
# Safety: Creates only the selected workspace plus Projects and Documents;
# refuses files and symbolic links at the selected directory paths and never moves content.
bootwitch_setup() {
  workspace=$(bootwitch_default_workspace)
  dry_run=0

  while test "$#" -gt 0; do
    case "$1" in
      --workspace)
        test "$#" -ge 2 && test -n "$2" || { bootwitch_error '--workspace requires a nonempty value'; return 2; }
        workspace=$2
        shift 2
        ;;
      --dry-run) dry_run=1; shift ;;
      -h | --help) bootwitch_usage; return 0 ;;
      *) bootwitch_error "unknown option: $1"; return 2 ;;
    esac
  done

  workspace=$(bootwitch_expand_path "$workspace")
  projects_directory=$workspace/Projects
  documents_directory=$workspace/Documents

  for workspace_path in "$workspace" "$projects_directory" "$documents_directory"; do
    if test -L "$workspace_path" || { test -e "$workspace_path" && test ! -d "$workspace_path"; }; then
      bootwitch_error "workspace path must be a regular directory: $workspace_path"
      return 1
    fi
  done

  if test "$dry_run" -eq 1; then
    printf 'Would prepare Bootwitch workspace: %s\n' "$workspace"
    printf 'Would ensure directory: %s\n' "$projects_directory"
    printf 'Would ensure directory: %s\n' "$documents_directory"
    return 0
  fi

  mkdir -p "$projects_directory" "$documents_directory" || {
    bootwitch_error "could not prepare workspace: $workspace"
    return 1
  }
  printf 'Bootwitch workspace ready: %s\n' "$workspace"
}

# Function: bootwitch_validate_name
# Purpose: Decide whether a project name is safe to use as one directory name.
# Arguments: $1 is the proposed project name.
# Output: None. Returns 0 for valid or 1 for invalid.
# How it works: The first case rejects unsafe patterns; the second requires the
# first character to be a letter.
# Safety: Rejects leading dots, separators, whitespace, and ".." traversal.
bootwitch_validate_name() {
  project_name=$1
  case "$project_name" in
    '' | .* | *[!A-Za-z0-9._-]* | *..*) return 1 ;;
  esac
  case "$project_name" in
    [A-Za-z]*) return 0 ;;
    *) return 1 ;;
  esac
}

# Function: bootwitch_template_exists
# Purpose: Confirm that a requested template is installed in Bootwitch.
# Arguments: $1 is the template name. Output: None.
# Returns: The result of testing the expected template directory.
# Safety: Looks only beneath the trusted BOOTWITCH_HOME/templates directory.
bootwitch_template_exists() {
  local template_candidate=$1
  case "$template_candidate" in
    '' | .* | *[!A-Za-z0-9._-]* | *..*) return 1 ;;
  esac
  test ! -L "$BOOTWITCH_HOME/templates" &&
    test ! -L "$BOOTWITCH_HOME/templates/$template_candidate" &&
    test -d "$BOOTWITCH_HOME/templates/$template_candidate"
}

# Function: bootwitch_replace_tokens
# Purpose: Personalize copied template files for the new project.
# Arguments: $1 staging directory, $2 validated name, $3 creation date.
# Output: Rewrites staged files in place; prints nothing.
# How it works: Finds template braces and replaces the three project-level
# tokens with sed through a unique temporary file.
# Safety: Operates only inside staging, excludes .git, and preserves spaced
# paths with NUL delimiters.
bootwitch_replace_tokens() {
  target_root=$1
  project_name=$2
  created_date=$3

  # NUL-delimited paths preserve spaces and unusual-but-valid filenames.
  find "$target_root" -type f ! -path '*/.git/*' -print0 |
    while IFS= read -r -d '' target_file; do
      if grep -q '{{' "$target_file"; then
        # Safety: allocate a unique temporary file, then copy its completed
        # contents over the staged file. No origin or existing project is used.
        token_tmp=$(mktemp "${TMPDIR:-/tmp}/bootwitch-token.XXXXXX")
        sed \
          -e "s/{{PROJECT_NAME}}/$project_name/g" \
          -e "s/{{CREATED_DATE}}/$created_date/g" \
          -e "s/{{BOOTWITCH_VERSION}}/$BOOTWITCH_VERSION/g" \
          "$target_file" > "$token_tmp"
        cat "$token_tmp" > "$target_file"
        rm -f "$token_tmp"
      fi
    done
}

# Function: bootwitch_make_executable
# Purpose: Make generated shell entry points directly runnable.
# Arguments: $1 is the unique project staging directory. Output: None.
# How it works: Finds .sh files in staged scripts, tests, and src, plus friendly
# .command files in wrappers.
# Safety: Library/data files and paths outside staging are untouched.
bootwitch_make_executable() {
  local target_root=$1 area pattern manifest executable_file permission_failed
  manifest=$(mktemp "$target_root/.executables.XXXXXX") || return 1
  for area in scripts tests src wrappers; do
    test -e "$target_root/$area" || continue
    pattern='*.sh'
    test "$area" != wrappers || pattern='*.command'
    if ! find "$target_root/$area" -type f -name "$pattern" -print0 > "$manifest"; then
      bootwitch_error "cannot discover executable files: $area"
      rm -f "$manifest"
      return 1
    fi
    permission_failed=0
    while IFS= read -r -d '' executable_file; do
      if ! chmod +x "$executable_file" || test ! -x "$executable_file"; then
        bootwitch_error "cannot make executable: $executable_file"
        permission_failed=1
        break
      fi
    done < "$manifest"
    if test "$permission_failed" -ne 0; then
      rm -f "$manifest"
      return 1
    fi
  done
  rm -f "$manifest"
}

# Function: bootwitch_prompt
# Purpose: Ask one guided setup question with an optional default value.
# Arguments: $1 prompt label, $2 default value.
# Output: Prints the user's answer, or the default when the answer is empty.
# Safety: Reads one plain text line and does not evaluate it.
bootwitch_prompt() {
  prompt_label=$1
  default_value=$2
  answer=

  if test -n "$default_value"; then
    printf '%s [%s]: ' "$prompt_label" "$default_value" >&2
  else
    printf '%s: ' "$prompt_label" >&2
  fi

  IFS= read -r answer || return 1
  if test -n "$answer"; then
    printf '%s\n' "$answer"
  else
    printf '%s\n' "$default_value"
  fi
}

# Function: bootwitch_summon
# Command: bootwitch summon
# Purpose: Guide the user through project creation one choice at a time.
# Arguments: None.
# Output: Prompts for project name, template, root, and Git choice, then prints
# the same progress lines as bootwitch init.
# Safety: Collects plain text choices and delegates all filesystem work to the
# validated bootwitch_init path.
bootwitch_summon() {
  project_name=
  template_choice=
  project_root=
  git_choice=

  bootwitch_note 'summoning a new project'
  bootwitch_templates

  project_name=$(bootwitch_prompt 'Project name' '') || return 1
  template_choice=$(bootwitch_prompt 'Template' 'shell') || return 1
  project_root=$(bootwitch_prompt 'Project root' "$(bootwitch_default_projects_root)") || return 1
  git_choice=$(bootwitch_prompt 'Initialize Git? Y/n' 'Y') || return 1

  case "$git_choice" in
    '' | y | Y | yes | YES | Yes)
      bootwitch_init "$project_name" --template "$template_choice" --root "$project_root"
      ;;
    n | N | no | NO | No)
      bootwitch_init "$project_name" --template "$template_choice" --root "$project_root" --no-git
      ;;
    *)
      bootwitch_error 'Git choice must be yes or no'
      return 2
      ;;
  esac
}

# Function: bootwitch_init
# Command: bootwitch init NAME [options]
# Purpose: Generate one project from base plus an optional template overlay.
# Arguments: Project name, then --template, --root, --no-git, or --dry-run.
# Output: Prints the created destination or a dry-run preview.
# Returns: 0 on success, 1 for an environment/destination problem, or 2 for bad
# command usage.
# How it works: Validates first, assembles in a unique staging directory,
# optionally initializes local Git, then publishes the completed tree with an exclusive atomic rename.
# Safety: Refuses existing destinations, adds no remote or commit, and limits
# emergency cleanup to the exact directory returned by mktemp.
bootwitch_init() {
  # Validate the required positional name before parsing optional flags.
  if test "$#" -lt 1; then
    bootwitch_error 'init requires a project name'
    return 2
  fi

  project_name=$1
  shift
  template_name=base
  project_root=$(bootwitch_default_projects_root)
  initialize_git=1
  dry_run=0

  # Parse an explicit option allowlist. Unknown options fail closed.
  while test "$#" -gt 0; do
    case "$1" in
      --template)
        test "$#" -ge 2 || { bootwitch_error '--template requires a value'; return 2; }
        template_name=$2
        shift 2
        ;;
      --root)
        test "$#" -ge 2 || { bootwitch_error '--root requires a value'; return 2; }
        project_root=$2
        shift 2
        ;;
      --no-git) initialize_git=0; shift ;;
      --dry-run) dry_run=1; shift ;;
      -h | --help) bootwitch_usage; return 0 ;;
      *) bootwitch_error "unknown option: $1"; return 2 ;;
    esac
  done

  # Complete input validation before creating the project root or any files.
  bootwitch_validate_name "$project_name" || {
    bootwitch_error 'project names must start with a letter and contain only letters, numbers, dots, underscores, or hyphens'
    return 2
  }
  if ! bootwitch_template_exists base || ! bootwitch_template_exists "$template_name"; then
    bootwitch_error "unknown template: $template_name"
    return 2
  fi

  # Expansion is limited to HOME; no eval, command substitution, or config
  # sourcing is used for caller-provided paths.
  project_root=$(bootwitch_expand_path "$project_root")
  destination=$project_root/$project_name

  # Never merge into or overwrite an existing file, directory, or symlink.
  if test -e "$destination" || test -L "$destination"; then
    bootwitch_error "destination already exists: $destination"
    return 1
  fi

  # Dry-run exits before mkdir, mktemp, template copying, metadata writes, or
  # Git initialization. It is safe to use for previews.
  if test "$dry_run" -eq 1; then
    printf 'Would create %s using template %s\n' "$destination" "$template_name"
    test "$initialize_git" -eq 1 && printf 'Would initialize an independent Git repository\n'
    return 0
  fi

  # Detect dependencies before writes; do not silently install anything.
  command -v python3 >/dev/null 2>&1 || {
    bootwitch_error 'python3 is required for atomic project publication'
    return 1
  }
  python3 "$BOOTWITCH_HOME/lib/bootwitch/publish.py" --check || return 1

  # Staging beside the destination permits a same-filesystem atomic rename.
  bootwitch_note "making project directory: $project_root"
  mkdir -p "$project_root"
  bootwitch_note 'preparing staging directory'
  staging=$(mktemp -d "$project_root/.bootwitch-${project_name}.XXXXXX")
  cleanup_staging=$staging

  # Safety: cleanup targets only the exact directory returned by mktemp. The
  # non-empty and directory checks guard rm -rf against an unset/broad target.
  trap 'if test -n "${cleanup_staging:-}" && test -d "$cleanup_staging"; then rm -rf "$cleanup_staging"; fi' EXIT
  trap 'exit 1' HUP INT TERM

  # Copy only bundled, trusted template content into the new staging directory.
  # The specialized template overlays base; neither source tree is modified.
  bootwitch_note 'copying base template'
  cp -R "$BOOTWITCH_HOME/templates/base/." "$staging/"
  if test "$template_name" != base; then
    bootwitch_note "overlaying $template_name template"
    cp -R "$BOOTWITCH_HOME/templates/$template_name/." "$staging/"
  fi

  # Metadata is written only inside staging. Values are validated/plain text;
  # consumers use config.sh's allowlisted parser rather than source this file.
  bootwitch_note 'writing project metadata'
  mkdir -p "$staging/.bootwitch"
  created_date=$(date +%Y-%m-%d)
  cat > "$staging/.bootwitch/project.conf" <<EOF
BOOTWITCH_SCHEMA=1
PROJECT_NAME=$project_name
TEMPLATE=$template_name
CREATED_DATE=$created_date
BOOTWITCH_VERSION=$BOOTWITCH_VERSION
EOF

  # These helpers operate only on the unique staged project.
  bootwitch_note 'filling template tokens'
  bootwitch_replace_tokens "$staging" "$project_name" "$created_date"
  bootwitch_note 'making project commands clickable'
  bootwitch_make_executable "$staging" || return 1

  # Git initialization is local to the staged project. Bootwitch does not add a
  # remote, create a commit, authenticate, publish, or contact a network service.
  if test "$initialize_git" -eq 1; then
    command -v git >/dev/null 2>&1 || {
      bootwitch_error 'git is required unless --no-git is supplied'
      return 1
    }
    bootwitch_note 'initializing local Git repository'
    git -C "$staging" init -q
    git -C "$staging" symbolic-ref HEAD refs/heads/main
  fi

  # Preserve the completed tree before entering publication, including signals.
  # The kernel refuses any existing destination in the rename itself.
  cleanup_staging=
  trap 'bootwitch_error "publication interrupted; inspect staging and destination: $staging ; $destination"; exit 1' HUP INT TERM
  bootwitch_note "publishing finished project: $destination"
  if ! python3 "$BOOTWITCH_HOME/lib/bootwitch/publish.py" "$staging" "$destination"; then
    if test -d "$staging"; then
      bootwitch_error "publication failed; prepared project retained: $staging"
      printf 'After resolving the error, retry publication: python3 %q %q %q\n' \
        "$BOOTWITCH_HOME/lib/bootwitch/publish.py" "$staging" "$destination" >&2
    else
      bootwitch_error "publication status uncertain; staging is absent; inspect destination before retrying: $destination"
    fi
    return 1
  fi

  # The staging path no longer exists, so disable the cleanup trap explicitly.
  trap - EXIT HUP INT TERM
  printf '%sCreated%s %s using template %s\n' "$(bootwitch_color green)" "$(bootwitch_color reset)" "$destination" "$template_name"
}

# Function: bootwitch_find_project_root
# Purpose: Find the nearest generated Bootwitch project from a directory.
# Arguments: Optional starting directory; defaults to the current working directory.
# Output: Prints the absolute physical project root.
# Returns: 0 when a regular marker is found; 1 when the path or project is invalid.
# Safety: Reads ancestor markers only, rejects symlink markers, and stops at the filesystem root.
bootwitch_find_project_root() {
  local start_path
  local current_dir

  start_path=$(bootwitch_expand_path "${1:-$PWD}")
  current_dir=$(CDPATH='' cd -P -- "$start_path" 2>/dev/null && pwd) || {
    bootwitch_error "cannot inspect project path: $start_path"
    return 1
  }

  while :; do
    if test -d "$current_dir/.bootwitch" &&
        test ! -L "$current_dir/.bootwitch" &&
        test -f "$current_dir/.bootwitch/project.conf" &&
        test ! -L "$current_dir/.bootwitch/project.conf"; then
      printf '%s\n' "$current_dir"
      return 0
    fi

    test "$current_dir" != / || break
    current_dir=$(dirname -- "$current_dir")
  done

  bootwitch_error "no generated project found above: $start_path"
  return 1
}

# Function: bootwitch_new_script
# Command: bootwitch new-script NAME [scripts|src|tests] [--project PATH]
# Purpose: Create one convention-compliant script through a generated project's own template.
# Arguments: Script name, optional destination area, and optional project path.
# Output: The project-local generator's creation and documentation-refresh messages.
# Returns: The delegated generator status, or 2 for invalid CLI arguments.
# Safety: Resolves a regular project marker and fixed non-symlink generator; delegates from that root only for this explicit command.
bootwitch_new_script() {
  local script_name
  local script_area=scripts
  local project_start=$PWD
  local project_root
  local generator

  test "$#" -ge 1 || {
    bootwitch_error 'new-script requires a script name'
    return 2
  }
  script_name=$1
  shift

  case "${1:-}" in
    scripts | src | tests)
      script_area=$1
      shift
      ;;
  esac

  case "$#" in
    0) ;;
    2)
      test "$1" = --project && test -n "$2" || {
        bootwitch_error 'usage: bootwitch new-script NAME [scripts|src|tests] [--project PATH]'
        return 2
      }
      project_start=$2
      ;;
    *)
      bootwitch_error 'usage: bootwitch new-script NAME [scripts|src|tests] [--project PATH]'
      return 2
      ;;
  esac

  project_root=$(bootwitch_find_project_root "$project_start") || return 1
  generator=$project_root/scripts/new-script.sh
  if test ! -f "$generator" || test -L "$generator"; then
    bootwitch_error "project does not provide a usable shell script generator: $project_root"
    return 1
  fi

  (
    cd "$project_root" || exit 1
    /bin/bash "$generator" "$script_name" "$script_area"
  )
}

# Function: bootwitch_list
# Command: bootwitch list
# Purpose: Show which project templates this release supports.
# Arguments: None.
# Output: Prints one tab-separated name and description per template.
# Safety: Static, read-only output; user directories are not scanned or run.
bootwitch_list() {
  printf 'base\tLanguage-neutral project foundation\n'
  printf 'shell\tBase foundation plus portable Bash tooling\n'
}

# Function: bootwitch_templates
# Command: bootwitch templates
# Purpose: Show the supported templates with their generated project shape.
# Arguments: None.
# Output: Prints a read-only overview of template contents.
# Safety: Reads no user projects and executes no template files.
bootwitch_templates() {
  cat <<'EOF'
Templates:

  base
    Purpose: Language-neutral project foundation.
    Includes:
      README.md, CHANGELOG.md, .editorconfig, .gitignore
      docs/project/ for state, decisions, questions, and updates
      scripts/, src/, and tests/ starter folders

  shell
    Purpose: Base foundation plus portable Bash tooling.
    Includes:
      wrappers/ for clickable commands
      modules/ for project-local reusable behavior
      scripts/new-script.sh for creating annotated scripts
      src/main.sh starter workflow
      logs/, cache/, temp/, and output/ runtime folders
      generated README section from project.header and annotations
      shell-focused generated project tests
EOF
}

# Function: bootwitch_doctor_item
# Purpose: Format one row of the environment diagnostic report.
# Arguments: $1 label, $2 status, and $3 explanatory detail.
# Output: Prints one aligned diagnostic row.
# Safety: Values are data arguments, never part of the printf format string.
bootwitch_doctor_item() {
  label=$1
  status=$2
  detail=$3
  printf '%-18s %-8s %s\n' "$label" "$status" "$detail"
}

# Function: bootwitch_doctor
# Command: bootwitch wizard, bootwitch doctor
# Purpose: Explain which runtime and optional development tools are available.
# Arguments: None.
# Output: Prints Bootwitch, platform, Bash, Git, optional-tool, and root rows.
# How it works: Reads versions and uses command -v to inspect the current PATH.
# Safety: Never installs tools, changes PATH, creates directories, or networks.
bootwitch_doctor() {
  bootwitch_doctor_item 'Bootwitch' ok "$BOOTWITCH_VERSION"
  bootwitch_doctor_item 'Platform' ok "$(uname -s)"
  bootwitch_doctor_item 'Bash' ok "${BASH_VERSION}"

  # command -v checks the current PATH without launching an installer.
  if command -v git >/dev/null 2>&1; then
    bootwitch_doctor_item 'Git' ok "$(git --version)"
  else
    bootwitch_doctor_item 'Git' missing 'required for default project initialization'
  fi

  if command -v python3 >/dev/null 2>&1; then
    if python3 "$BOOTWITCH_HOME/lib/bootwitch/publish.py" --check >/dev/null 2>&1; then
      bootwitch_doctor_item 'Publication' ok 'Python 3 / exclusive rename API available; filesystem checked at publication'
    else
      bootwitch_doctor_item 'Publication' missing 'exclusive rename API unavailable'
    fi
  else
    bootwitch_doctor_item 'Python 3' missing 'required for init/summon publication'
  fi

  if command -v python3 >/dev/null 2>&1 &&
      python3 "$BOOTWITCH_HOME/tools/setup_shellcheck.py" --check >/dev/null 2>&1; then
    bootwitch_doctor_item 'ShellCheck' ok 'pinned project-local tool ready'
  else
    bootwitch_doctor_item 'ShellCheck' missing 'required for make check; run make setup'
  fi

  # Optional tools are informational and never become runtime requirements.
  for optional_tool in shfmt bats; do
    if command -v "$optional_tool" >/dev/null 2>&1; then
      bootwitch_doctor_item "$optional_tool" optional "$(command -v "$optional_tool")"
    else
      bootwitch_doctor_item "$optional_tool" optional 'not installed'
    fi
  done

  bootwitch_doctor_item 'Workspace' info "$(bootwitch_default_workspace)"
  bootwitch_doctor_item 'Default root' info "$(bootwitch_default_projects_root)"
}

# Function: bootwitch_main
# Purpose: Route the first CLI word to one known Bootwitch function.
# Arguments: The complete argument list from bin/bootwitch.
# Output: Whatever the selected command prints.
# Returns: The selected command status, or 2 for an unknown command.
# How it works: Removes the command word and forwards the remaining quoted
# arguments without flattening them.
# Safety: Uses an explicit allowlist; unknown text is never executed.
bootwitch_main() {
  command_name=${1:-help}
  if test "$#" -gt 0; then shift; fi

  case "$command_name" in
    # Idempotently prepares the minimal user-owned workspace convention.
    setup) bootwitch_setup "$@" ;;
    # Guided project creation; delegates writes to bootwitch_init.
    summon) bootwitch_summon "$@" ;;
    # Mutating, bounded scaffolding command; see bootwitch_init safety contract.
    init) bootwitch_init "$@" ;;
    # Explicitly delegates to a selected generated project's bounded generator.
    new-script) bootwitch_new_script "$@" ;;
    # Read-only template inventory.
    list) bootwitch_list ;;
    # Read-only template details.
    templates) bootwitch_templates ;;
    # Read-only local diagnostics.
    wizard | doctor) bootwitch_doctor ;;
    # Read-only usage output.
    help | -h | --help) bootwitch_usage ;;
    # Fail closed instead of attempting dynamic command execution.
    *) bootwitch_error "unknown command: $command_name"; bootwitch_usage >&2; return 2 ;;
  esac
}
