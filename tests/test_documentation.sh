#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_documentation.sh
# Type: test
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-21
# Version: 0.5.0
# Purpose: Verify separate component/function views, Bash/Python discovery, refresh, and safe documentation publication.
# Arguments: None.
# Output: README integration success message; failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Python 3; Bash 3.2+, dirname, mktemp, rm, grep, date, mkdir, mv, ln, cat, cp, cmp, head, tail, find, awk, sed, chmod, ls; CLI and builder dependencies.
# Reads: CLI, bundled templates, and generated README/script fixtures.
# Writes: Temporary generated project, scripts, and README fixtures; removes its allocated directory on exit.
# Safety: Runs destructive marker cases only in disposable README fixtures; verifies scripts are read without execution.
# Example: bash tests/test_documentation.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-doc-tests.XXXXXX")
TEST_TMP=$(CDPATH='' cd -P -- "$TEST_TMP" && pwd)
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

/bin/bash "$PROJECT_ROOT/bin/bootwitch" init docs-demo --template shell --root "$TEST_TMP/projects with spaces" --no-git >/dev/null
project=$TEST_TMP/'projects with spaces'/docs-demo
builder=$project/wrappers/build_readme.command
# The reusable context selector preserves caller-first selection and wrapper
# fallback without changing a project while probing either route.
/bin/bash "$PROJECT_ROOT/bin/bootwitch" init docs-other --template shell --root "$TEST_TMP/projects with spaces" --no-git >/dev/null
other_project=$TEST_TMP/'projects with spaces'/docs-other
. "$project/modules/adaptive_mounts.sh"
project_mount_select_context "$other_project" "$project/wrappers"
test "$PROJECT_ROOT" = "$other_project"
test "$PROJECT_LANGUAGE" = shell
test "$PROJECT_DOCUMENTATION_MODULE" = "$other_project/modules/documentation.sh"
project_mount_select_context / "$project/wrappers"
test "$PROJECT_ROOT" = "$project"
if project_mount_select_context / / >/dev/null 2>&1; then
  printf 'Context selector accepted paths without a project marker.\n' >&2
  exit 1
fi
PROJECT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
readme=$project/README.md
technical=$project/docs/technical-readthrough.md
start='<!-- BOOTWITCH:DOCS:START -->'
finish='<!-- BOOTWITCH:DOCS:END -->'
printf 'Human introduction\n%s\nOld generated text\n%s\nHuman ending\n' "$start" "$finish" > "$readme"
grep -q '{{SCRIPT_CREATED_DATE}}' "$project/.bootwitch/templates/script.sh.tpl"
grep -q '{{SCRIPT_UPDATED_DATE}}' "$project/.bootwitch/templates/script.sh.tpl"
test -f "$project/.bootwitch/templates/python-component.header.tpl"
test -f "$project/.bootwitch/templates/function-annotation.tpl"
for metadata_field in Name Type Dates Version Purpose Arguments Output Returns Dependencies Reads Writes Safety Example; do
  grep -q "^# $metadata_field: ." "$project/.bootwitch/templates/python-component.header.tpl"
done
for metadata_field in Name Purpose Arguments Output Returns Reads Writes Safety; do
  grep -q "^# $metadata_field: ." "$project/.bootwitch/templates/function-annotation.tpl"
done
# Every bundled generated shell file begins with the universal header and
# contributes a complete, populated component entry.
/bin/bash "$builder" >/dev/null
while IFS= read -r -d '' bundled_script; do
  test "$(sed -n '1p' "$bundled_script")" = '#!/usr/bin/env bash'
  test "$(sed -n '2p' "$bundled_script")" = '# @bootwitch:component'
  component_name=$(awk '/^# @bootwitch:component$/ { active=1; next } active && /^# Name: / { sub(/^# Name: /, ""); print; exit }' "$bundled_script")
  test -n "$component_name"
  grep -Fq "### \`$component_name\`" "$readme"
  for metadata_field in Name Type Dates Version Purpose Arguments Output Returns Dependencies Reads Writes Safety Example; do
    grep -q "^# $metadata_field: ." "$bundled_script"
  done
done < <(find "$project/wrappers" "$project/modules" "$project/scripts" "$project/src" "$project/tests" -type f \( -name '*.sh' -o -name '*.command' \) -print0)

creation_output=$(/bin/bash "$project/scripts/new-script.sh" sample scripts)
printf '%s\n' "$creation_output" | grep -q '^Created scripts/sample.sh$'
printf '%s\n' "$creation_output" | grep -q '^README updated: '
printf '%s\n' "$creation_output" | grep -q '^Technical readthrough updated: '
grep -q '^### `sample.sh`$' "$readme"
grep -Fq '### `scripts/sample.sh`' "$technical"
grep -Fq '#### Function: `find_root_for_this_script`' "$technical"
/bin/bash "$project/wrappers/new_script.command" sample-test tests >/dev/null
grep -q '^### `sample-test.sh`$' "$readme"
# Both dates belong to script generation; no script metadata tokens may remain.
for generated_script in "$project/scripts/sample.sh" "$project/tests/sample-test.sh"; do
  grep -Fxq "# Dates: Created: $(date +%Y-%m-%d) | Last Updated: $(date +%Y-%m-%d)" "$generated_script"
  grep -Fxq '# Version: 0.1.0' "$generated_script"
  grep -Fxq 'set -e' "$generated_script"
  grep -Fxq 'set -u' "$generated_script"
  grep -Fxq 'set -o pipefail' "$generated_script"
  if grep -q '^IFS=' "$generated_script"; then exit 1; fi
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
cat > "$project/src/nested folder/python-probe.py" <<'PYPROBE'
#!/usr/bin/env python3
# @bootwitch:component
# Name: python-probe.py
# Type: script
# Dates: Created: 2001-01-01 | Last Updated: 2001-01-01
# Version: 0.1.0
# Purpose: Exercise Python component discovery without executing source.
# Arguments: None.
# Output: Synthetic fixture output only if explicitly executed.
# Returns: Fixture process status.
# Dependencies: Python 3 standard library.
# Reads: No host observation sources.
# Writes: A sentinel only if executed; documentation must never create it.
# Safety: Documentation reads this fixture as text.
# Example: python3 python-probe.py
# @bootwitch:end
# @bootwitch:function
# Name: python_probe_function
# Purpose: Keep Python implementation notes in the technical view.
# Arguments: None.
# Output: A synthetic string.
# Returns: The string synthetic.
# Reads: None.
# Writes: None.
# Safety: No host inspection.
# @bootwitch:end
def python_probe_function():
    return "synthetic"

from pathlib import Path
Path(__file__ + ".executed").write_text("executed")
PYPROBE
ln -s "$project/src/nested folder/python-probe.py" "$project/src/nested folder/ignored-link.py"
/bin/bash "$builder" >/dev/null
grep -q '^### `sample.sh`$' "$readme"
grep -q '^### `read-only-probe`$' "$readme"
grep -q '^#### Function: `probe_function`$' "$technical"
grep -q '^### `python-probe.py`$' "$readme"
grep -q '^#### Function: `python_probe_function`$' "$technical"
test "$(grep -c '^### `python-probe.py`$' "$readme")" -eq 1
test ! -e "$project/src/nested folder/python-probe.py.executed"
if grep -q '^#### Function:' "$readme"; then exit 1; fi
if grep -q 'Exercise Python component discovery' "$technical"; then exit 1; fi
for metadata_field in Type Dates Version Purpose Arguments Output Returns Dependencies Reads Writes Safety Example; do
  metadata_value=$(awk -v key="$metadata_field" 'index($0, "# " key ": ") == 1 { print substr($0, length(key) + 5); exit }' "$project/src/nested folder/python-probe.py")
  grep -Fq "**$metadata_field:** $metadata_value" "$readme"
done
test ! -e "$project/src/nested folder/read-only-probe.sh.executed"
test "$(head -n 1 "$readme")" = 'Human introduction'
test "$(tail -n 1 "$readme")" = 'Human ending'
cp "$readme" "$TEST_TMP/expected"
cp "$technical" "$TEST_TMP/technical-expected"
/bin/bash "$builder" >/dev/null
cmp "$readme" "$TEST_TMP/expected"
cmp "$technical" "$TEST_TMP/technical-expected"

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
  cmp "$technical" "$TEST_TMP/technical-expected"
done
# The last invalid-marker fixture exercises partial success through the wrapper.
cp "$readme" "$TEST_TMP/invalid-readme"
creation_status=0
/bin/bash "$project/wrappers/new_script.command" retained src > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr" || creation_status=$?
test "$creation_status" -eq 3
test -x "$project/src/retained.sh"
grep -q '^Created src/retained.sh$' "$TEST_TMP/stdout"
grep -q 'Script created, but documentation refresh failed' "$TEST_TMP/stderr"
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
cp "$technical" "$TEST_TMP/technical-original"
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
    cmp "$technical" "$TEST_TMP/technical-original"
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
  cmp "$technical" "$TEST_TMP/technical-original"
  test -z "$(find "$project" -maxdepth 1 -name '.bootwitch-readme.*' -print)"
done
rm "$project/scripts/broken.sh"
# A malformed function must fail even while rendering the component-only view.
printf '# @bootwitch:component\n# Name: malformed-function\n# @bootwitch:end\n# @bootwitch:function\n# Name: unfinished\n' > "$project/scripts/broken.py"
if /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
grep -q 'missing closing marker' "$TEST_TMP/stderr"
cmp "$readme" "$TEST_TMP/readme-original"
cmp "$technical" "$TEST_TMP/technical-original"
rm "$project/scripts/broken.py"

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
cp "$technical" "$TEST_TMP/technical-original"
mkdir "$TEST_TMP/failing-bin"
printf '#!/bin/bash\nexit 1\n' > "$TEST_TMP/failing-bin/mv"
chmod +x "$TEST_TMP/failing-bin/mv"
if PATH="$TEST_TMP/failing-bin:$PATH" /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
cmp "$readme" "$TEST_TMP/readme-original"
cmp "$technical" "$TEST_TMP/technical-original"
test -z "$(find "$project" -maxdepth 1 -name '.bootwitch-readme.*' -print)"
# A late README publication failure reports the already-published readthrough.
real_mv=$(command -v mv)
cat > "$TEST_TMP/failing-bin/mv" <<'MVFAIL'
#!/bin/bash
case "$3" in
  */README.md) exit 1 ;;
esac
exec "$BOOTWITCH_TEST_REAL_MV" "$@"
MVFAIL
printf '# @bootwitch:function\n# Name: late_publication_probe\n# Purpose: Verify partial publication reporting.\n# @bootwitch:end\n' > "$project/scripts/late-publication.sh"
if BOOTWITCH_TEST_REAL_MV="$real_mv" PATH="$TEST_TMP/failing-bin:$PATH" /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
grep -q 'technical readthrough updated, but README publication failed' "$TEST_TMP/stderr"
cmp "$readme" "$TEST_TMP/readme-original"
grep -q 'late_publication_probe' "$technical"
cp "$technical" "$TEST_TMP/technical-original"
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
cmp "$technical" "$TEST_TMP/technical-original"
test -z "$(find "$project" -maxdepth 1 -name '.bootwitch-readme.*' -print)"
chmod 640 "$readme"
/bin/bash "$builder" >/dev/null
# Portable permission comparison, without platform-specific stat flags.
python3 -c 'import os, stat, sys; assert stat.S_IMODE(os.stat(sys.argv[1]).st_mode) == 0o640' "$readme"

# Symlinked readthrough destinations must not replace their target or README.
cp "$readme" "$TEST_TMP/readme-original"
mv "$technical" "$TEST_TMP/saved-technical"
cp "$TEST_TMP/saved-technical" "$TEST_TMP/technical-original"
ln -s "$TEST_TMP/saved-technical" "$technical"
if /bin/bash "$builder" > "$TEST_TMP/stdout" 2> "$TEST_TMP/stderr"; then exit 1; fi
cmp "$readme" "$TEST_TMP/readme-original"
cmp "$TEST_TMP/saved-technical" "$TEST_TMP/technical-original"
rm "$technical"
mv "$TEST_TMP/saved-technical" "$technical"

# Directory insertion order must not affect generated documentation.
mkdir "$project/src/order-check"
printf '# @bootwitch:component\n# Name: order-z\n# @bootwitch:end\n' > "$project/src/order-check/z.sh"
printf '# @bootwitch:component\n# Name: order-a\n# @bootwitch:end\n' > "$project/src/order-check/a.sh"
/bin/bash "$builder" >/dev/null
cp "$readme" "$TEST_TMP/ordered-readme"
cp "$technical" "$TEST_TMP/ordered-technical"
mv "$project/src/order-check" "$TEST_TMP/order-original"
mkdir "$project/src/order-check"
cp "$TEST_TMP/order-original/a.sh" "$project/src/order-check/a.sh"
cp "$TEST_TMP/order-original/z.sh" "$project/src/order-check/z.sh"
/bin/bash "$builder" >/dev/null
cmp "$readme" "$TEST_TMP/ordered-readme"
cmp "$technical" "$TEST_TMP/ordered-technical"

printf 'README integration tests passed.\n'
