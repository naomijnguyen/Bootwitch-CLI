SHELL := /bin/bash


.PHONY: setup check syntax test lint format-check

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
