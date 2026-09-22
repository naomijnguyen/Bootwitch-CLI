#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_cli.sh
# Type: test
# Dates: Created: 2026-09-03 (first tracked; original creation unknown) | Last Updated: 2026-09-21
# Version: 0.3.3
# Purpose: Verify workspace setup, CLI inspection, project/script creation, dry-run, generated projects, and destination refusal.
# Arguments: None.
# Output: CLI integration success message; failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mktemp, mkdir, rm, grep, cmp, Git, and CLI/generated-test dependencies.
# Reads: bin/bootwitch, tests/helpers.sh, bundled templates, and generated fixtures.
# Writes: Temporary projects, generated scripts/docs, and local Git repositories; removes its allocated test directory on exit.
# Safety: Uses a unique temporary root, including paths with spaces; no remote Git operations.
# Example: bash tests/test_cli.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
. "$TEST_DIR/helpers.sh"

TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

CLI=$PROJECT_ROOT/bin/bootwitch

help_output=$(/bin/bash "$CLI" help)
assert_contains "$help_output" 'setup prepares $HOME/Bootwitch'
assert_contains "$help_output" 'init creates one project under $HOME/Bootwitch/Projects'
assert_contains "$help_output" 'Both commands can be run from any working directory.'

# Installed commands are commonly symlinks outside the toolkit directory. The
# entry point must follow the link before looking for its bundled core library.
linked_cli=$TEST_TMP/bootwitch
ln -s "$CLI" "$linked_cli"
linked_help_output=$(/bin/bash "$linked_cli" help)
assert_contains "$linked_help_output" 'Usage:'

list_output=$(/bin/bash "$CLI" list)
assert_contains "$list_output" 'base'
assert_contains "$list_output" 'shell'

templates_output=$(/bin/bash "$CLI" templates)
assert_contains "$templates_output" 'Templates:'
assert_contains "$templates_output" 'wrappers/'
assert_contains "$templates_output" 'modules/'

wizard_output=$(/bin/bash "$CLI" wizard)
assert_contains "$wizard_output" 'Bootwitch'
assert_contains "$wizard_output" 'Default root'

workspace_home=$TEST_TMP/workspace-home
mkdir -p "$workspace_home"

default_preview=$(HOME="$workspace_home" /bin/bash "$CLI" init default-demo --dry-run)
assert_contains "$default_preview" "$workspace_home/Bootwitch/Projects/default-demo"
assert_not_exists "$workspace_home/Bootwitch"

setup_preview=$(HOME="$workspace_home" /bin/bash "$CLI" setup --dry-run)
assert_contains "$setup_preview" "Would prepare Bootwitch workspace: $workspace_home/Bootwitch"
assert_contains "$setup_preview" "$workspace_home/Bootwitch/Projects"
assert_contains "$setup_preview" "$workspace_home/Bootwitch/Documents"
assert_not_exists "$workspace_home/Bootwitch"

if HOME="$workspace_home" /bin/bash "$CLI" setup --workspace '' --dry-run >/dev/null 2>&1; then
  test_fail 'empty workspace path was accepted'
fi

if HOME='' /bin/bash "$CLI" setup --dry-run >/dev/null 2>&1; then
  test_fail 'empty HOME was accepted for workspace setup'
fi
if HOME='' /bin/bash "$CLI" init unsafe-home --dry-run >/dev/null 2>&1; then
  test_fail 'empty HOME was accepted for default project creation'
fi
if env -u HOME /bin/bash "$CLI" setup --dry-run >/dev/null 2>&1; then
  test_fail 'unset HOME was accepted for workspace setup'
fi

workspace_file=$TEST_TMP/workspace-file
: > "$workspace_file"
if /bin/bash "$CLI" setup --workspace "$workspace_file" >/dev/null 2>&1; then
  test_fail 'regular file was accepted as a workspace directory'
fi

workspace_target=$TEST_TMP/workspace-target
workspace_link=$TEST_TMP/workspace-link
mkdir "$workspace_target"
ln -s "$workspace_target" "$workspace_link"
if /bin/bash "$CLI" setup --workspace "$workspace_link" >/dev/null 2>&1; then
  test_fail 'symbolic link was accepted as a workspace directory'
fi

setup_output=$(HOME="$workspace_home" /bin/bash "$CLI" setup)
assert_contains "$setup_output" "Bootwitch workspace ready: $workspace_home/Bootwitch"
assert_exists "$workspace_home/Bootwitch/Projects"
assert_exists "$workspace_home/Bootwitch/Documents"

# Setup is deliberately idempotent and preserves an existing workspace.
HOME="$workspace_home" /bin/bash "$CLI" setup >/dev/null
assert_exists "$workspace_home/Bootwitch/Projects"
assert_exists "$workspace_home/Bootwitch/Documents"

summon_root=$TEST_TMP/summon-root
summon_output=$(printf 'summoned-demo\nshell\n%s\nn\n' "$summon_root" | /bin/bash "$CLI" summon 2>&1)
assert_contains "$summon_output" 'summoning a new project'
assert_contains "$summon_output" 'Created'
assert_exists "$summon_root/summoned-demo/wrappers/hello.command"
assert_not_exists "$summon_root/summoned-demo/.git"

dry_root=$TEST_TMP/dry-run-root
dry_output=$(/bin/bash "$CLI" init preview --root "$dry_root" --dry-run)
assert_contains "$dry_output" 'Would create'
assert_not_exists "$dry_root"

if /bin/bash "$CLI" init '../escape' --root "$TEST_TMP/projects" >/dev/null 2>&1; then
  test_fail 'invalid project name was accepted'
fi

space_root=$TEST_TMP/'projects with spaces'
/bin/bash "$CLI" init base-demo --template base --root "$space_root" --no-git >/dev/null
base_project=$space_root/base-demo
assert_exists "$base_project/README.md"
assert_exists "$base_project/.bootwitch/project.conf"
assert_not_exists "$base_project/.git"
assert_not_exists "$base_project/.DS_Store"
/bin/bash "$base_project/tests/run.sh" >/dev/null

metadata=$(cat "$base_project/.bootwitch/project.conf")
assert_contains "$metadata" 'PROJECT_NAME=base-demo'
assert_contains "$metadata" 'TEMPLATE=base'

/bin/bash "$CLI" init shell-demo --template shell --root "$space_root" >/dev/null
shell_project=$space_root/shell-demo
assert_exists "$shell_project/.git"
assert_exists "$shell_project/modules/log.sh"
assert_exists "$shell_project/wrappers/run.command"
assert_not_exists "$shell_project/.DS_Store"
/bin/bash "$shell_project/tests/run.sh" >/dev/null

python_created=$(/bin/bash "$shell_project/wrappers/new_script.command" word-demo scripts --language python)
assert_contains "$python_created" 'Created scripts/word-demo.py'
assert_exists "$shell_project/scripts/word-demo.py"
python_help=$(python3 "$shell_project/scripts/word-demo.py" --help)
assert_contains "$python_help" '--text'
assert_contains "$python_help" '--top'
python_words=$(python3 "$shell_project/scripts/word-demo.py" --text 'Bash bash Python' --top 2)
assert_contains "$python_words" 'Total words: 3'
assert_contains "$python_words" 'Unique words: 2'
assert_contains "$python_words" 'bash: 2'
if python3 "$shell_project/scripts/word-demo.py" --top 0 >/dev/null 2>&1; then
  test_fail 'Python starter accepted a nonpositive --top value'
fi
if /bin/bash "$shell_project/wrappers/new_script.command" word-demo scripts --language python >/dev/null 2>&1; then
  test_fail 'Python starter generator overwrote an existing script'
fi
if /bin/bash "$shell_project/wrappers/new_script.command" wrong-language scripts --language ruby >/dev/null 2>&1; then
  test_fail 'generator accepted an unsupported language'
fi
assert_not_exists "$shell_project/scripts/wrong-language.rb"
assert_contains "$(cat "$shell_project/README.md")" 'word-demo.py'

# Generated projects ignore local environment secrets without hiding a
# shareable example file or an ordinary file named "env".
git -C "$shell_project" check-ignore -q -- .env || test_fail '.env is not ignored'
git -C "$shell_project" check-ignore -q -- env/settings || test_fail 'env/ is not ignored'
if git -C "$shell_project" check-ignore -q -- .env.example; then
  test_fail '.env.example is unexpectedly ignored'
fi
if git -C "$shell_project" check-ignore -q -- env; then
  test_fail 'a file named env is unexpectedly ignored'
fi

script_error=$TEST_TMP/new-script-error
script_output=$(/bin/bash "$CLI" new-script cli-probe src --project "$shell_project" 2>"$script_error")
test ! -s "$script_error" || test_fail 'explicit project script creation emitted an unexpected warning'
assert_contains "$script_output" 'Created src/cli-probe.sh'
assert_contains "$script_output" 'README updated:'
assert_contains "$script_output" 'Technical readthrough updated:'
assert_exists "$shell_project/src/cli-probe.sh"
assert_contains "$(cat "$shell_project/README.md")" '### `cli-probe.sh`'
assert_contains "$(cat "$shell_project/docs/technical-readthrough.md")" '### `src/cli-probe.sh`'
/bin/bash "$shell_project/src/cli-probe.sh" >/dev/null

nested_dir=$shell_project/src/'nested folder'
mkdir -p "$nested_dir"
nested_output=$(cd "$nested_dir" && /bin/bash "$CLI" new-script nested-probe tests)
assert_contains "$nested_output" 'Created tests/nested-probe.sh'
assert_exists "$shell_project/tests/nested-probe.sh"

if /bin/bash "$CLI" new-script unsupported --project "$base_project" >/dev/null 2>&1; then
  test_fail 'base project unexpectedly provided the shell script generator'
fi

if /bin/bash "$CLI" init shell-demo --template shell --root "$space_root" >/dev/null 2>&1; then
  test_fail 'existing destination was overwritten'
fi

# Both layers must carry the exact notice; shell README rebuilds preserve it.
cmp "$PROJECT_ROOT/LICENSE" "$PROJECT_ROOT/templates/base/LICENSES/Bootwitch-MIT.txt"
for licensed_project in "$base_project" "$shell_project"; do
  cmp "$PROJECT_ROOT/LICENSE" "$licensed_project/LICENSES/Bootwitch-MIT.txt"
  assert_contains "$(cat "$licensed_project/README.md")" '[Bootwitch MIT license](LICENSES/Bootwitch-MIT.txt)'
done
/bin/bash "$shell_project/wrappers/build_readme.command" >/dev/null
cp "$shell_project/README.md" "$TEST_TMP/licensed-readme.md"
/bin/bash "$shell_project/wrappers/build_readme.command" >/dev/null
cmp "$TEST_TMP/licensed-readme.md" "$shell_project/README.md"
assert_contains "$(cat "$shell_project/README.md")" '[Bootwitch MIT license](LICENSES/Bootwitch-MIT.txt)'
cmp "$PROJECT_ROOT/LICENSE" "$shell_project/LICENSES/Bootwitch-MIT.txt"

printf 'CLI integration tests passed.\n'
