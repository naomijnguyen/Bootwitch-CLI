# Public repository generator — Bootwitch contract

Status: reusable tool in progress. The current implementation inventories an
explicit manifest and copies verified files into a private staging run. It does
**not** build, create a Git repo, push, or certify an output safe.

Each project owns a reviewed `exports/github-safe.json` file. Bootwitch owns validation,
staging, verification, and eventual repo creation. The manifest lists individual
files, never whole directories or glob patterns. A source may be classified as
`source`, `example-content`, `public-asset`, or `build-config`. Private
maintainer/agent documents have no export class. For example:

```json
{
  "version": 1,
  "target": "github-safe",
  "files": [
    {"kind": "source", "source": "site/app.js", "output": "app.js"},
    {"kind": "example-content", "source": "content-packs/example/intro.md", "output": "content/intro.md"}
  ]
}
```

Run the current read-only preflight with
`python3 lib/bootwitch/public_export.py PROJECT_ROOT`. It reads only
`PROJECT_ROOT/exports/github-safe.json` and reports
selected paths, sizes, and SHA-256 hashes, never file bodies. It rejects
missing files, duplicate or file/parent-colliding output paths (including
case-only variants), traversal, symlinks, and obvious private path
names, including `AGENTS.md` and `local-private/`. The example content must be separately authored and reviewed; labeling
an existing private document as an example does not make it safe.

Stage an approved manifest into a separate output tree with
`python3 lib/bootwitch/export_stage.py PROJECT_ROOT /path/to/export-runs`.
The `export-runs` directory must be outside the project (neither tree may
contain the other). Bootwitch creates it privately with a root marker, or
reuses an existing private, correctly marked root; it refuses an unmarked or
symlinked output root. Each run gets its own `run-<uuid>/source/` tree with
only the declared output files. It opens source paths without following
symlinks and checks source identity, byte count, and SHA-256 while copying.
A copy failure retains a marked `failed` run for review and eventual manual
cleanup. A successful run has status `staged`, which is **not** publication
approval. The caller must review the staged source and later build artifacts;
the manifest path rules cannot detect secrets or private text inside an
otherwise allowed file.

Do not confuse this export allowlist with `deployments/<name>.json`, which
selects a content pack for a website build, or with a generated
`content-packs/<name>/manifest.json`, which indexes website content. Neither
of those files grants publication permission. A public contributor-agent
guide can be considered later, but the current exporter excludes every
`AGENTS.md` until that guide has its own review path.

## Required next gates before generating a pushable repository

1. Verify the stage contains **exactly** declared outputs. Check import/build
   dependencies; an allowlisted entry can still embed private bytes or refer
   to an undeclared source.
2. Run clean install, tests, and build inside the isolated stage, without
   access to the private project. Inspect both source and built client/server
   artifacts for disallowed paths and sensitive content.
3. Obtain independent safety/content review and Jennifer's publication
   approval. Only then initialize a fresh public Git history in the verified
   output. Never reuse the private project's Git history.

Generation and publication remain separate operations. A fresh history on
every run cannot safely update an existing remote via a normal push; repeated
releases need a reviewed diff/PR against the previous public output or an
explicitly designed publishing workflow, not an automatic force push.

## Failed-run cleanup

The optional cleanup command handles marked failed staging runs:

```sh
python3 lib/bootwitch/export_prune.py /path/to/export-runs
python3 lib/bootwitch/export_prune.py /path/to/export-runs --apply
```

The first command only previews eligible directories; the second removes
them. Nothing runs on a schedule. The tool accepts only an `export-runs`
directory with a regular `.bootwitch-export-output.json` file containing
`{"version":1,"purpose":"bootwitch-export-runs"}`. A direct child must be
named `run-<uuid>` and contain a regular `.bootwitch-export-run.json` with
`version: 1`, a matching `run_id`, `status: "failed"`, and an ISO `created_at`.
Both the run's recorded creation and every file/directory modification must
be more than 14 days old. Approved runs, recently touched material, unmarked
folders, and symlinks are left alone. The exporter creates these markers
only for its own output; do not add them to an existing hand-maintained
directory. This is cooperative local cleanup, not protection against a hostile
process replacing paths concurrently.
