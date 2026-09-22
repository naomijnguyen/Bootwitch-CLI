#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_release.sh
# Type: test
# Dates: Created: 2026-09-16 | Last Updated: 2026-09-21
# Version: 0.2.0
# Purpose: Verify non-mutating formula previews, a functional formula smoke test, and the read-only release verification workflow.
# Arguments: None.
# Output: Release tooling success message; failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, dirname, mktemp, mkdir, cp, cmp, grep, chmod, shasum, python3.
# Reads: tools/bump-brew-formula.sh, Formula/bootwitch.rb, and the release workflow.
# Writes: A temporary fake curl command and formula snapshot; removes its allocated directory on exit.
# Safety: Uses a fake local curl response, never contacts GitHub, and requires dry-run to preserve the tracked formula.
# Example: bash tests/test_release.sh
# @bootwitch:end

set -e
set -u
set -o pipefail

TEST_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH='' cd -- "$TEST_DIR/.." && pwd)
. "$TEST_DIR/helpers.sh"

TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-release-tests.XXXXXX")
trap 'rm -rf "$TEST_TMP"' EXIT HUP INT TERM

mkdir "$TEST_TMP/bin"
cat > "$TEST_TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
case " $* " in
  *' -fsI '*) exit 0 ;;
  *) printf 'synthetic release archive' ;;
esac
EOF
chmod +x "$TEST_TMP/bin/curl"

cp "$PROJECT_ROOT/Formula/bootwitch.rb" "$TEST_TMP/formula-before.rb"
preview_output=$(PATH="$TEST_TMP/bin:$PATH" /bin/bash "$PROJECT_ROOT/tools/bump-brew-formula.sh" --dry-run v9.9.9)
assert_contains "$preview_output" 'version "9.9.9"'
assert_contains "$preview_output" 'dry-run complete for v9.9.9'
cmp "$TEST_TMP/formula-before.rb" "$PROJECT_ROOT/Formula/bootwitch.rb"
grep -Fq 'system bin/"bootwitch", "init", "brew-smoke"' "$PROJECT_ROOT/Formula/bootwitch.rb"
grep -Fq 'assert_path_exists testpath/"brew-smoke/.bootwitch/project.conf"' "$PROJECT_ROOT/Formula/bootwitch.rb"

workflow=$PROJECT_ROOT/.github/workflows/release-brew-formula.yml
grep -Fq '  contents: read' "$workflow"
grep -Fq '          persist-credentials: false' "$workflow"
grep -Fq 'run: bash tools/bump-brew-formula.sh --dry-run "${TAG_NAME}"' "$workflow"
if grep -Eq 'git push|gh release edit' "$workflow"; then
  test_fail 'release verification workflow contains a write operation'
fi

printf 'Release tooling tests passed.\n'
