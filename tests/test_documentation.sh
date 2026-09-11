#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_documentation.sh
# Type: test
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-11
# Version: 0.2.3
# Purpose: Verify header rendering, recursive discovery, date/version metadata, automatic refresh, and README preservation.
# Arguments: None.
# Output: README integration success message; failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Python 3; Bash 3.2+, dirname, mktemp, rm, grep, date, mkdir, mv, cat, cp, cmp, head, tail, find, awk, sed, chmod, ls; CLI and builder dependencies.
# Reads: CLI, bundled templates, and generated README/script fixtures.
# Writes: Temporary generated project, scripts, and README fixtures; removes its allocated directory on exit.
# Safety: Runs destructive marker cases only in disposable README fixtures; verifies scripts are read without execution.
# Example: bash tests/test_documentation.sh
# @bootwitch:end

set -euo pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-doc-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

/bin/bash "$PROJECT_ROOT/bin/bootwitch" init docs-demo --template shell --root "$TEST_TMP/projects with spaces" --no-git >/dev/null
project=$TEST_TMP/'projects with spaces'/docs-demo
builder=$project/wrappers/build_readme.command
readme=$project/README.md
start='<!-- BOOTWITCH:DOCS:START -->'
finish='<!-- BOOTWITCH:DOCS:END -->'
printf 'Human introduction\n%s\nOld generated text\n%s\nHuman ending\n' "$start" "$finish" > "$readme"
grep -q '{{SCRIPT_CREATED_DATE}}' "$project/.bootwitch/templates/script.sh.tpl"
grep -q '{{SCRIPT_UPDATED_DATE}}' "$project/.bootwitch/templates/script.sh.tpl"
# Every bundled generated shell file contributes its populated header.
/bin/bash "$builder" >/dev/null
while IFS= read -r -d '' bundled_script; do
  component_name=$(awk '/^# @bootwitch:component$/ { active=1; next } active && /^# Name: / { sub(/^# Name: /, ""); print; exit }' "$bundled_script")
  test -n "$component_name"
  grep -Fq "### \`$component_name\`" "$readme"
  for metadata_field in Dates Version; do
    grep -q "^# $metadata_field: ." "$bundled_script"
  done
done < <(find "$project/wrappers" "$project/modules" "$project/scripts" "$project/src" "$project/tests" -type f \( -name '*.sh' -o -name '*.command' \) -print0)

creation_output=$(/bin/bash "$project/scripts/new-script.sh" sample scripts)
printf '%s\n' "$creation_output" | grep -q '^Created scripts/sample.sh$'
printf '%s\n' "$creation_output" | grep -q '^README updated: '
grep -q '^### `sample.sh`$' "$readme"
/bin/bash "$project/wrappers/new_script.command" sample-test tests >/dev/null
grep -q '^### `sample-test.sh`$' "$readme"
# Both dates belong to script generation; no script metadata tokens may remain.
for generated_script in "$project/scripts/sample.sh" "$project/tests/sample-test.sh"; do
  grep -Fxq "# Dates: Created: $(date +%Y-%m-%d) | Last Updated: $(date +%Y-%m-%d)" "$generated_script"
  grep -Fxq '# Version: 0.1.0' "$generated_script"
  if grep -q '{{SCRIPT_' "$generated_script"; then exit 1; fi
done
# A rebuild must display authored revisions without refreshing their dates.
sed -e 's/ | Last Updated: .*/ | Last Updated: 2001-02-03/' -e 's/^# Version: .*/# Version: 0.1.1/' "$project/scripts/sample.sh" > "$TEST_TMP/revised-script"
cp "$TEST_TMP/revised-script" "$project/scripts/sample.sh"

/bin/bash "$builder" >/dev/null
grep -q '^### `sample.sh`$' "$readme"
grep -q '^### `sample-test.sh`$' "$readme"
grep -q 'bash tests/sample-test.sh' "$readme"
grep -Fq "**Dates:** Created: $(date +%Y-%m-%d)" "$readme"
grep -q '\*\*Calls:\*\* project_build_readme' "$readme"
grep -Fq ' | Last Updated: 2001-02-03' "$readme"
grep -Fq '**Version:** 0.1.1' "$readme"
cmp "$TEST_TMP/revised-script" "$project/scripts/sample.sh"


mkdir -p "$project/src/nested folder"
mv "$project/scripts/sample.sh" "$project/src/nested folder/sample.sh"
cat > "$project/src/nested folder/read-only-probe.sh" <<'PROBE'
#!/usr/bin/env bash
# @bootwitch:component
# Name: read-only-probe
# Purpose: Confirm documentation reads source without executing it.
# @bootwitch:end
# @bootwitch:function
# Name: probe_function
# Purpose: Confirm marked function documentation is included.
# @bootwitch:end
printf executed > "${0}.executed"
PROBE
/bin/bash "$builder" >/dev/null
grep -q '^### `sample.sh`$' "$readme"
grep -q '^### `read-only-probe`$' "$readme"
grep -q '^#### Function: `probe_function`$' "$readme"
test ! -e "$project/src/nested folder/read-only-probe.sh.executed"
test "$(head -n 1 "$readme")" = 'Human introduction'
test "$(tail -n 1 "$readme")" = 'Human ending'
cp "$readme" "$TEST_TMP/expected"
/bin/bash "$builder" >/dev/null
cmp "$readme" "$TEST_TMP/expected"

for marker_case in missing_start missing_end duplicate_start duplicate_end reversed extra_pair; do
  case "$marker_case" in
    missing_start) printf '%s\n' "$finish" ;;
    missing_end) printf '%s\n' "$start" ;;
    duplicate_start) printf '%s\n' "$start" "$start" ;;
    duplicate_end) printf '%s\n' "$finish" "$finish" ;;
    reversed) printf '%s\n' "$finish" "$start" ;;
    extra_pair) printf '%s\n' "$start" "$finish" "$start" "$finish" ;;
  esac > "$readme"
  printf 'Preserve this trailing text\n' >> "$readme"
  cp "$readme" "$TEST_TMP/expected"
  if /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then
    printf 'README builder accepted invalid markers: %s\n' "$marker_case" >&2
    exit 1
  fi
  cmp "$readme" "$TEST_TMP/expected"
  grep -q 'exactly one ordered marker pair' "$TEST_TMP/stderr"
done
# The last invalid-marker fixture exercises partial success through the wrapper.
cp "$readme" "$TEST_TMP/invalid-readme"
creation_status=0
/bin/bash "$project/wrappers/new_script.command" retained src > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr" || creation_status=$?
test "$creation_status" -eq 3
test -x "$project/src/retained.sh"
grep -q '^Created src/retained.sh$' "$TEST_TMP/stdout"
grep -q 'Script created, but README refresh failed' "$TEST_TMP/stderr"
grep -q 'then retry: bash ' "$TEST_TMP/stderr"
cmp "$readme" "$TEST_TMP/invalid-readme"
cp "$project/src/retained.sh" "$TEST_TMP/retained-script"
# Refusal must neither replace the script nor invoke the builder.
if /bin/bash "$project/scripts/new-script.sh" retained src > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
grep -q 'destination already exists' "$TEST_TMP/stderr"
if grep -q 'documentation:' "$TEST_TMP/stderr"; then exit 1; fi
cmp "$readme" "$TEST_TMP/invalid-readme"
cmp "$project/src/retained.sh" "$TEST_TMP/retained-script"
# Repair only the README, then use the documented recovery command.
printf 'Human introduction\n%s\n%s\nHuman ending\n' "$start" "$finish" > "$readme"
/bin/bash "$builder" >/dev/null
grep -q '^### `retained.sh`$' "$readme"
cmp "$project/src/retained.sh" "$TEST_TMP/retained-script"
# Missing/empty required project values must not publish partial documentation.
cp "$project/project.header" "$TEST_TMP/header-original"
cp "$readme" "$TEST_TMP/readme-original"
for required_key in PROJECT_PURPOSE PROJECT_TYPE PROJECT_VERSION PROJECT_STATUS PRIMARY_WRAPPER; do
  for metadata_case in missing empty; do
    if test "$metadata_case" = missing; then
      sed "/^$required_key=/d" "$TEST_TMP/header-original" > "$project/project.header"
    else
      sed "s/^$required_key=.*/$required_key=   /" "$TEST_TMP/header-original" > "$project/project.header"
    fi
    if /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
    grep -q "$required_key" "$TEST_TMP/stderr"
    cmp "$readme" "$TEST_TMP/readme-original"
  done
done
cp "$TEST_TMP/header-original" "$project/project.header"

# Marked blocks must close, have a name, and avoid ambiguous structure.
for block_case in unclosed missing_name blank_name nested orphan duplicate; do
  case "$block_case" in
    unclosed) printf '# @bootwitch:component\n# Name: broken\n' ;;
    missing_name) printf '# @bootwitch:component\n# Purpose: broken\n# @bootwitch:end\n' ;;
    blank_name) printf '# @bootwitch:component\n# Name:   \n# @bootwitch:end\n' ;;
    nested) printf '# @bootwitch:component\n# Name: broken\n# @bootwitch:function\n' ;;
    orphan) printf '# @bootwitch:end\n' ;;
    duplicate) printf '# @bootwitch:component\n# Name: broken\n# Name: repeated\n# @bootwitch:end\n' ;;
  esac > "$project/scripts/broken.sh"
  if /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
  grep -q 'scripts/broken.sh:[0-9]' "$TEST_TMP/stderr"
  cmp "$readme" "$TEST_TMP/readme-original"
  test -z "$(find "$project" -maxdepth 1 -name '.bootwitch-readme.*' -print)"
done
rm "$project/scripts/broken.sh"

# Legacy dates remain readable; compact dates take precedence when both exist.
cat > "$project/scripts/legacy.sh" <<'LEGACY'
# @bootwitch:component
# Name: legacy-dates
# Created: 2000-01-02
# Last Updated: 2000-02-03
# @bootwitch:end
# @bootwitch:component
# Name: compact-dates
# Dates: Created: 2001-01-02 | Last Updated: 2001-02-03
# Created: must-not-render
# Last Updated: must-not-render
# @bootwitch:end
LEGACY
/bin/bash "$builder" >/dev/null
grep -Fq '**Created:** 2000-01-02' "$readme"
grep -Fq '**Last Updated:** 2000-02-03' "$readme"
grep -Fq '**Dates:** Created: 2001-01-02 | Last Updated: 2001-02-03' "$readme"
if grep -q 'must-not-render' "$readme"; then exit 1; fi

# Simulate publication failure: old content and mode survive, staging is removed.
cp "$readme" "$TEST_TMP/readme-original"
mkdir "$TEST_TMP/failing-bin"
printf '#!/bin/bash\nexit 1\n' > "$TEST_TMP/failing-bin/mv"
chmod +x "$TEST_TMP/failing-bin/mv"
if PATH="$TEST_TMP/failing-bin:$PATH" /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
cmp "$readme" "$TEST_TMP/readme-original"
test -z "$(find "$project" -maxdepth 1 -name '.bootwitch-readme.*' -print)"
# Simulate a partial rendering write after staging starts, before publication.
rm "$TEST_TMP/failing-bin/mv"
real_awk=$(command -v awk)
cat > "$TEST_TMP/failing-bin/awk" <<'AWKFAIL'
#!/bin/bash
case "$*" in
  *'/section'*) printf 'partial render\n'; printf 'simulated render failure\n' >&2; exit 1 ;;
esac
exec "$BOOTWITCH_TEST_REAL_AWK" "$@"
AWKFAIL
chmod +x "$TEST_TMP/failing-bin/awk"
if BOOTWITCH_TEST_REAL_AWK="$real_awk" PATH="$TEST_TMP/failing-bin:$PATH" /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
grep -q 'simulated render failure' "$TEST_TMP/stderr"
cmp "$readme" "$TEST_TMP/readme-original"
test -z "$(find "$project" -maxdepth 1 -name '.bootwitch-readme.*' -print)"
chmod 640 "$readme"
/bin/bash "$builder" >/dev/null
# Portable permission comparison, without platform-specific stat flags.
python3 -c 'import os, stat, sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o640' "$readme"

# Directory insertion order must not affect generated documentation.
mkdir "$project/src/order-check"
printf '# @bootwitch:component\n# Name: order-z\n# @bootwitch:end\n' > "$project/src/order-check/z.sh"
printf '# @bootwitch:component\n# Name: order-a\n# @bootwitch:end\n' > "$project/src/order-check/a.sh"
/bin/bash "$builder" >/dev/null
cp "$readme" "$TEST_TMP/ordered-readme"
mv "$project/src/order-check" "$TEST_TMP/order-original"
mkdir "$project/src/order-check"
cp "$TEST_TMP/order-original/a.sh" "$project/src/order-check/a.sh"
cp "$TEST_TMP/order-original/z.sh" "$project/src/order-check/z.sh"
/bin/bash "$builder" >/dev/null
cmp "$readme" "$TEST_TMP/ordered-readme"

printf 'README integration tests passed.\n'
