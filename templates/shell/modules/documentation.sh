#!/usr/bin/env bash
# @bootwitch:component
# Name: documentation
# Type: module
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-12
# Version: 0.4.0
# Purpose: Build a component README reference and a separate function-level technical readthrough.
# Wrapper: wrappers/build_readme.command
# Arguments: Source with PROJECT_ROOT and project_header_get configured; call project_build_readme or project_render_annotations FILE.
# Output: Selected annotation Markdown or updated README/readthrough paths on stdout.
# Returns: 0 on success; nonzero on failure. See function comments for individual statuses.
# Dependencies: Bash 3.2+, modules/header.sh, awk, mktemp, cp, cat, mv, rm.
# Reads: project.header, README.md, and recursive marked comments in .sh, .command, and .py files under wrappers/modules/scripts/src/tests.
# Writes: Replaces the marked README section and generated docs/technical-readthrough.md; creates/removes staging.
# Safety: Renders both documents before publication; each replacement is atomic, but the pair is not one transaction.
# Example: source modules/documentation.sh
# @bootwitch:end

# Function: project_render_annotations
# Purpose: Validate marked blocks and render their supported fields as Markdown.
# Arguments: $1 is a script path; optional $2 selects component, function, or all (default).
# Output: Markdown on stdout; file/line diagnostics on stderr.
# Returns: 0 for valid input; nonzero for malformed blocks or read errors.
# Safety: Reads text without executing scripts; callers stage output before use.
project_render_annotations() {
  local annotation_view=${2:-all}
  case "$annotation_view" in
    component | function | all) ;;
    *) printf 'documentation: unsupported annotation view\n' >&2; return 2 ;;
  esac
  awk -v selected_view="$annotation_view" '
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
      if (selected_view != "all" && selected_view != block_type) return
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
# Purpose: List shell and Python sources in stable bytewise path order, including hidden folders.
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
        *.sh | *.command | *.py) printf '%s\0' "$entry" || return 1 ;;
      esac
    fi
  done
)

# Function: project_build_readme
# Purpose: Render both documentation views, then publish each completed file.
# Arguments: None; PROJECT_ROOT and project_header_get must be available.
# Output: Updated README and technical-readthrough paths on stdout; failures on stderr.
# Returns: 0 when both outputs publish; nonzero on failure, with a retry message if only the readthrough publishes.
# Safety: Renders both outputs before replacement; preserves existing file modes; rejects symlink destinations.
# How it works: Publish the readthrough first, then README. The two renames are not a joint transaction; concurrent edits are not locked.
project_build_readme() (
  local header_file=$PROJECT_ROOT/project.header
  local readme_file=$PROJECT_ROOT/README.md
  local technical_file=$PROJECT_ROOT/docs/technical-readthrough.md
  local marker_start='<!-- BOOTWITCH:DOCS:START -->'
  local marker_end='<!-- BOOTWITCH:DOCS:END -->'
  local work_dir key value component_dir component_file function_count
  local -a metadata

  test -f "$header_file" && test -f "$readme_file" && test ! -L "$readme_file" || {
    printf 'documentation: requires project.header and a regular, non-symlink README.md\n' >&2
    return 1
  }
  test -d "$PROJECT_ROOT/docs" && test ! -L "$PROJECT_ROOT/docs" &&
    test ! -L "$technical_file" || {
    printf 'documentation: requires a regular docs directory and a non-symlink readthrough destination\n' >&2
    return 1
  }
  if test -e "$technical_file" && test ! -f "$technical_file"; then
    printf 'documentation: technical readthrough destination must be a regular file\n' >&2
    return 1
  fi
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
  if test -f "$technical_file"; then
    cp -p "$technical_file" "$work_dir/technical" || return 1
  fi
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
    printf 'Function details are generated separately in the [technical readthrough](docs/technical-readthrough.md).\n\n' || return 1
    while IFS= read -r -d '' component_file; do
      project_render_annotations "$component_file" component || return 1
    done < "$work_dir/components"
  } > "$work_dir/section" || return 1

  {
    printf '# Technical readthrough\n\n' || return 1
    printf 'Generated from marked function annotations in shell and Python source. Edit those comments and rebuild; direct edits to this file are replaced.\n\n' || return 1
    printf 'For commands, dependencies, and component-level behavior, see the [README reference](../README.md#component-reference).\n\n' || return 1
    printf 'Only marked function blocks are included. Ordinary comments and Python docstrings remain in the source.\n\n## Function reference\n\n' || return 1
    function_count=0
    while IFS= read -r -d '' component_file; do
      project_render_annotations "$component_file" function > "$work_dir/functions" || return 1
      test -s "$work_dir/functions" || continue
      function_count=$((function_count + 1))
      printf '### `%s`\n\n[View source](<../%s>)\n\n' "${component_file#"$PROJECT_ROOT"/}" "${component_file#"$PROJECT_ROOT"/}" || return 1
      cat "$work_dir/functions" || return 1
    done < "$work_dir/components"
    if test "$function_count" -eq 0; then
      printf 'No marked function annotations are present yet.\n' || return 1
    fi
  } > "$work_dir/technical" || return 1

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

  mv -f "$work_dir/technical" "$technical_file" || return 1
  if ! mv -f "$work_dir/readme" "$readme_file"; then
    printf 'documentation: technical readthrough updated, but README publication failed; rerun the documentation builder to refresh both\n' >&2
    return 1
  fi
  printf 'README updated: %s\n' "$readme_file"
  printf 'Technical readthrough updated: %s\n' "$technical_file"
)
