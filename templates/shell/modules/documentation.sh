#!/usr/bin/env bash
# @bootwitch:component
# Name: documentation
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-11
# Version: 0.2.0
# Purpose: Build README reference material from project facts and annotations.
# Wrapper: wrappers/build_readme.command
# Arguments: Source with PROJECT_ROOT and project_header_get configured; call project_build_readme or project_render_annotations FILE.
# Output: Rendered Markdown or updated README path on stdout when called.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, modules/header.sh, awk, mktemp, cp, mv, rm.
# Reads: project.header, README.md, and recursive marked shell comments in wrappers/modules/scripts/src/tests.
# Writes: When building, replaces the marked README section and creates/removes a staging directory beside README.md.
# Safety: Validates metadata and annotation blocks before atomic replacement; cleans staging files on failure.
# Example: source modules/documentation.sh
# @bootwitch:end

# Function: project_render_annotations
# Purpose: Validate marked blocks and render their supported fields as Markdown.
# Arguments: $1 is a script path; unmarked comments are ignored.
# Output: Markdown on stdout; file/line diagnostics on stderr.
# Returns: 0 for valid input; nonzero for malformed blocks or read errors.
# Safety: Reads text without executing scripts; callers stage output before use.
project_render_annotations() {
  awk '
    function fail(message) {
      printf "documentation: %s:%d: %s\n", FILENAME, FNR, message > "/dev/stderr"
      failed = 1
      exit 1
    }
    function clear_fields(    key) {
      for (key in field) delete field[key]
    }
    function emit(label, key) {
      if (key in field && field[key] != "") print "- **" label ":** " field[key]
    }
    function render() {
      if (!("Name" in field) || field["Name"] !~ /[^[:space:]]/)
        fail("marked block requires a nonempty Name")
      if (block_type == "component") print "### `" field["Name"] "`"
      else print "#### Function: `" field["Name"] "`"
      print ""
      emit("Type", "Type")
      emit("Display Name", "Display Name")
      emit("Wrapper", "Wrapper")
      emit("Module", "Module")
      emit("Calls", "Calls")
      if ("Dates" in field && field["Dates"] != "") emit("Dates", "Dates")
      else {
        emit("Created", "Created")
        emit("Last Updated", "Last Updated")
      }
      emit("Version", "Version")
      emit("Purpose", "Purpose")
      emit("Arguments", "Arguments")
      emit("Output", "Output")
      emit("Returns", "Returns")
      emit("Dependencies", "Dependencies")
      emit("Reads", "Reads")
      emit("Writes", "Writes")
      emit("How it works", "How it works")
      emit("Safety", "Safety")
      emit("Example", "Example")
      print ""
    }
    { sub(/\r$/, "") }
    /^# @bootwitch:(component|function)$/ {
      if (active) fail("new block before previous closing marker")
      clear_fields()
      block_type = ($0 == "# @bootwitch:component" ? "component" : "function")
      active = 1
      next
    }
    /^# @bootwitch:end$/ {
      if (!active) fail("closing marker without an open block")
      render(); clear_fields(); active = 0; next
    }
    active && /^# [A-Za-z][A-Za-z ]*: / {
      line = substr($0, 3)
      key = line
      sub(/:.*/, "", key)
      value = line
      sub(/^[^:]*: /, "", value)
      if (key in field) fail("duplicate field: " key)
      field[key] = value
    }
    END {
      if (failed) exit 1
      if (active) fail("missing closing marker: # @bootwitch:end")
    }
  ' "$1"
}

# Function: project_collect_annotations
# Purpose: List shell files in stable bytewise path order, including hidden folders.
# Arguments: $1 is a directory to traverse.
# Output: NUL-delimited paths; errors on stderr.
# Returns: 0 on success; nonzero for an unreadable directory.
# Safety: Skips symlinks and isolates shell options in a subshell.
project_collect_annotations() (
  export LC_ALL=C
  shopt -s nullglob dotglob
  local entry
  test -r "$1" && test -x "$1" || {
    printf 'documentation: cannot read directory: %s\n' "$1" >&2
    return 1
  }
  for entry in "$1"/*; do
    test ! -L "$entry" || continue
    if test -d "$entry"; then
      project_collect_annotations "$entry" || return 1
    elif test -f "$entry"; then
      case "$entry" in
        *.sh | *.command) printf '%s\0' "$entry" || return 1 ;;
      esac
    fi
  done
)

# Function: project_build_readme
# Purpose: Validate all input and atomically publish the generated README section.
# Arguments: None; PROJECT_ROOT and project_header_get must be available.
# Output: Updated README path on stdout; precise failures on stderr.
# Returns: 0 on success; nonzero leaves the existing README intact before publication.
# Safety: Stages beside README, preserves file permissions, cleans up on exit,
# and isolates traps in a subshell. Concurrent human edits are not locked.
project_build_readme() (
  local header_file=$PROJECT_ROOT/project.header
  local readme_file=$PROJECT_ROOT/README.md
  local marker_start='<!-- BOOTWITCH:DOCS:START -->'
  local marker_end='<!-- BOOTWITCH:DOCS:END -->'
  local work_dir key value component_dir component_file
  local -a metadata

  test -f "$header_file" && test -f "$readme_file" && test ! -L "$readme_file" || {
    printf 'documentation: requires project.header and a regular, non-symlink README.md\n' >&2
    return 1
  }
  if ! awk -v start="$marker_start" -v finish="$marker_end" '
    $0 == start { starts++; start_line = NR }
    $0 == finish { finishes++; finish_line = NR }
    END { exit !(starts == 1 && finishes == 1 && start_line < finish_line) }
  ' "$readme_file"; then
    printf 'documentation: README must contain exactly one ordered marker pair\n' >&2
    return 1
  fi

  metadata=()
  for key in PROJECT_PURPOSE PROJECT_TYPE PROJECT_VERSION PROJECT_STATUS PRIMARY_WRAPPER; do
    if ! value=$(project_header_get "$header_file" "$key") || [[ "$value" != *[![:space:]]* ]]; then
      printf 'documentation: %s: missing or empty required field %s\n' "$header_file" "$key" >&2
      return 1
    fi
    metadata+=("$value")
  done

  work_dir=$(mktemp -d "$PROJECT_ROOT/.bootwitch-readme.XXXXXX") || return 1
  trap 'rm -rf -- "$work_dir"' EXIT
  trap 'exit 1' HUP INT TERM
  # The stage lives on the README filesystem so final rename is atomic.
  cp -p "$readme_file" "$work_dir/readme" || return 1
  : > "$work_dir/components" || return 1
  for component_dir in wrappers modules scripts src tests; do
    test ! -L "$PROJECT_ROOT/$component_dir" || continue
    test -d "$PROJECT_ROOT/$component_dir" || continue
    project_collect_annotations "$PROJECT_ROOT/$component_dir" >> "$work_dir/components" || return 1
  done

  {
    printf '## Project overview\n\n' || return 1
    printf -- '- **Purpose:** %s\n- **Type:** %s\n- **Version:** %s\n- **Status:** %s\n- **Primary wrapper:** `%s`\n\n' "${metadata[@]}" || return 1
    printf '## Standard folders\n\n' || return 1
    printf -- '- `wrappers/` - friendly entry points\n- `modules/` - reusable project behavior\n- `scripts/`, `src/`, and `tests/` - project scripts and checks\n- `logs/`, `cache/`, `temp/`, and `output/` - runtime files\n\n' || return 1
    printf '## Component reference\n\n' || return 1
    while IFS= read -r -d '' component_file; do
      project_render_annotations "$component_file" || return 1
    done < "$work_dir/components"
  } > "$work_dir/section" || return 1

  awk -v start="$marker_start" -v finish="$marker_end" -v insert="$work_dir/section" '
    $0 == start {
      print
      while ((read_status = (getline inserted_line < insert)) > 0) print inserted_line
      close(insert)
      if (read_status < 0) exit 1
      skipping = 1
      next
    }
    $0 == finish { skipping = 0; print; next }
    !skipping { print }
  ' "$readme_file" > "$work_dir/readme" || return 1

  mv -f "$work_dir/readme" "$readme_file" || return 1
  printf 'README updated: %s\n' "$readme_file"
)
