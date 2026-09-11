# Script headers and README compatibility

The same 13 fields serve two readers: someone opening the script, and the README
builder. Keep those field names and the block markers stable. Shorten the values
before introducing a second format.

## Current concise starter

```bash
#!/usr/bin/env bash
# @bootwitch:component
# Name: sample-task.sh
# Type: script
# Dates: Created: 2026-09-11 | Last Updated: 2026-09-11
# Version: 0.1.0
# Purpose: Prepare runtime folders and log workflow start.
# Arguments: None.
# Output: Timestamped stderr messages.
# Returns: 0 success; nonzero failure.
# Dependencies: Bash 3.2+, dirname, mkdir, date; modules/paths.sh, modules/log.sh.
# Reads: .bootwitch/project.conf (root marker).
# Writes: logs/, cache/, temp/, output/; logs/project.log.
# Safety: Uses the discovered root; stops if absent.
# Example: bash scripts/sample-task.sh
# @bootwitch:end
```

The required fields remain Name, Type, Dates, Version, Purpose, Arguments, Output,
Returns, Dependencies, Reads, Writes, Safety, and Example. Dates still includes
Created and Last Updated. The README builder displays each supported field;
Name becomes the component heading. It reads comments as text and never runs the
script to discover its documentation.

This remains a 16-line block including the shebang and markers. It reduces prose,
not the number of metadata fields. Dependencies and write locations are explicit,
so the shorter example is more precise than vague phrases such as “standard folders.”

## What can be shortened safely

- Prefer “0 success; nonzero failure” to a longer generic return description.
- Name actual paths and commands rather than describing their categories.
- Describe the current starter behavior, then update it when custom code changes.
- Keep function implementation explanations beside the function, outside the file header.
- Omit optional relationship fields unless they help: Wrapper, Module, Calls, Display Name.

## What needs a format decision first

| Proposed reduction | Tradeoff |
| --- | --- |
| Merge Arguments and Example into Usage | Saves one field, but needs parser and test changes to retain both meanings. |
| Merge Output, Reads, and Writes into IO | Saves two fields, but makes terminal output and filesystem effects harder to distinguish. |
| Make boilerplate fields optional | Shortens small wrappers, but removes the universal header shape and may hide missing documentation. |
| Put several fields on one physical line | Saves vertical space, but requires a separator/escaping rule; current parsing treats it as one value. |

These reductions are proposals, not additional supported formats. Existing full
headers remain compatible. The current choice is one stable schema with concise
wording; a future schema change should include a migration and before/after README
comparison rather than silently dropping fields.
