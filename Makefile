SHELL := /bin/bash
RELEASE_VERSION ?= $(shell tr -d '[:space:]' < VERSION)
export NOTE
export RELEASE_NOTE
export RELEASE_VERSION


.PHONY: setup check syntax test lint format-check log

setup:
	@python3 tools/setup_shellcheck.py

check: syntax test lint

syntax:
	@find bin lib tests templates -type f \( -name '*.sh' -o -name '*.command' -o -name 'bootwitch' \) -print0 | xargs -0 -n1 /bin/bash -n

test:
	@/bin/bash tests/run.sh

lint:
	@python3 tools/setup_shellcheck.py --check
	@find bin lib tests templates -type f \( -name '*.sh' -o -name '*.command' -o -name 'bootwitch' \) -print0 | xargs -0 "$(CURDIR)/.tools/bin/shellcheck" -x -e SC1091 -e SC2016

format-check:
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -d bin lib tests templates; \
	else \
		echo 'shfmt not installed; skipping optional format check'; \
	fi

# Automatically log a small release maintenance note in CHANGELOG.md and release notes.
# Usage:
#   make log NOTE="Your maintenance summary"
#   make log RELEASE_VERSION=0.2.1 NOTE="Your maintenance summary"
log:
	@test -n "$${NOTE:-}" || { echo 'error: NOTE is required' >&2; exit 2; }
	@/bin/bash tools/log-maintenance.sh \
		--version "$${RELEASE_VERSION}" \
		--changelog "$${NOTE}" \
		--release-note "$${RELEASE_NOTE:-}"
