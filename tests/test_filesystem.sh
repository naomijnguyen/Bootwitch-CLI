#!/usr/bin/env bash
# @bootwitch:component
# Name: tests/test_filesystem.sh
# Type: test
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-11
# Version: 0.1.3
# Purpose: Regress the five reviewed filesystem failures and publication collisions.
# Arguments: None.
# Output: Success message; assertion failures on stderr.
# Returns: 0 on success; nonzero on failure.
# Dependencies: Bash 3.2+, cp, mkdir, mktemp, rm, chmod, cmp, ln, find, grep, cat; CLI dependencies.
# Reads: Toolkit and templates.
# Writes: Owned temporary toolkit copies, generated projects, shims, and sentinels.
# Safety: All fixtures and cleanup stay inside the allocated temporary directory.
# Example: bash tests/test_filesystem.sh
# @bootwitch:end
set -e
set -u
set -o pipefail
ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/bootwitch-filesystem.XXXXXX")
trap 'rm -rf "$TMP"' EXIT
trap 'exit 1' HUP INT TERM
cp -R "$ROOT/." "$TMP/toolkit"
CLI=$TMP/toolkit/bin/bootwitch
fail() { printf '%s\n' "$*" >&2; exit 1; }
create() { /bin/bash "$CLI" init "$1" --root "$TMP/projects" --template "${2:-shell}" --no-git; }
create sentinel >/dev/null
P=$TMP/projects/sentinel
mkdir -p "$P/src/nested/tools"
printf '# user sentinel\n' > "$P/src/nested/tools/sample-task.sh"
chmod 640 "$P/src/nested/tools/sample-task.sh"
cp -p "$P/src/nested/tools/sample-task.sh" "$TMP/expected"
mode_before=$(ls -ld "$P/src/nested/tools/sample-task.sh"); mode_before=${mode_before:0:10}
for _iteration in 1 2; do
  /bin/bash "$P/tests/run.sh" >/dev/null
  cmp "$TMP/expected" "$P/src/nested/tools/sample-task.sh"
  mode_after=$(ls -ld "$P/src/nested/tools/sample-task.sh"); mode_after=${mode_after:0:10}
  test "$mode_before" = "$mode_after"
done
test ! -e "$P/output/run-report.txt"
# RF-002: static directory symlinks must be refused before any external write.
mkdir "$TMP/external"
mv "$P/src" "$P/src-original"
ln -s "$TMP/external" "$P/src"
cp "$P/README.md" "$TMP/readme"
if /bin/bash "$P/scripts/new-script.sh" escaped src >"$TMP/out" 2>"$TMP/err"; then fail 'accepted symlink area'; fi
test ! -e "$TMP/external/escaped.sh"
cmp "$TMP/readme" "$P/README.md"
rm "$P/src"
mv "$P/src-original" "$P/src"
/bin/bash "$P/scripts/new-script.sh" normal src >/dev/null
test -x "$P/src/normal.sh"
grep -q normal "$P/README.md"
# RF-003: reject traversal, dangling destinations, and external template links.
mkdir "$TMP/outside-template"
printf sentinel > "$TMP/outside-template/sentinel"
ln -s "$TMP/outside-template" "$TMP/toolkit/templates/outside"
for template in ../../outside-template outside /tmp ./shell; do
  if create invalid "$template" >"$TMP/out" 2>"$TMP/err"; then fail 'accepted unsafe template'; fi
  test ! -e "$TMP/projects/invalid"
done
mkdir "$TMP/toolkit/templates/custom-name"
create custom custom-name >/dev/null
test -f "$TMP/projects/custom/README.md"
ln -s "$TMP/missing" "$TMP/projects/dangling"
if create dangling >"$TMP/out" 2>"$TMP/err"; then fail 'accepted dangling destination'; fi
# RF-004: do not publish when chmod or discovery fails.
chmod 644 "$TMP/toolkit/templates/shell/wrappers/hello.command"
mkdir "$TMP/shims"
for command in chmod find; do
  printf '#!/bin/bash\nprintf \"Injected command failure\\n\" >&2\nexit 1\n' > "$TMP/shims/$command"
  chmod +x "$TMP/shims/$command"
  if PATH="$TMP/shims:$PATH" create permission >"$TMP/out" 2>"$TMP/err"; then fail 'suppressed permission/discovery failure'; fi
  test -s "$TMP/err"
  test ! -e "$TMP/projects/permission"
  test -z "$(find "$TMP/projects" -name '.bootwitch-permission.*' -print)"
  rm "$TMP/shims/$command"
done
# RF-005 and RF-006 publication collisions/recovery are exercised through the
# actual exclusive rename helper in test_publication.py (run by tests/run.sh).
# A script arriving while rendering must survive the final no-clobber write.
cat > "$TMP/shims/sed" <<'EOF'
#!/bin/bash
printf '# rival script\n' > "$SCRIPT_COLLISION"
exec /usr/bin/sed "$@"
EOF
chmod +x "$TMP/shims/sed"
cp "$P/README.md" "$TMP/readme"
if SCRIPT_COLLISION="$P/src/rival.sh" PATH="$TMP/shims:$PATH" /bin/bash "$P/scripts/new-script.sh" rival src >"$TMP/out" 2>"$TMP/err"; then fail 'replaced late script'; fi
test "$(cat "$P/src/rival.sh")" = '# rival script'
cmp "$TMP/readme" "$P/README.md"
test -z "$(find "$P" -name '.new-script-*' -print)"
printf 'Filesystem regression tests passed (RF-001 through RF-005).\n'
