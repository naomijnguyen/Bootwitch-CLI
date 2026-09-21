# Public repository generator — Bootwitch contract

Status: reusable tool in progress. The current implementation inventories an
explicit manifest; it does **not** yet copy files, build, create a Git repo,
push, or certify an output safe.

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
missing files, duplicate paths, traversal, symlinks, and obvious private path
names, including `AGENTS.md`. The example content must be separately authored and reviewed; labeling
an existing private document as an example does not make it safe.

Do not confuse this export allowlist with `deployments/<name>.json`, which
selects a content pack for a website build, or with a generated
`content-packs/<name>/manifest.json`, which indexes website content. Neither
of those files grants publication permission. A public contributor-agent
guide can be considered later, but the current exporter excludes every
`AGENTS.md` until that guide has its own review path.

## Required next gates before generating a pushable repository

1. Copy only the reviewed manifest entries into a new, exclusive staging
   directory; recheck identity and hashes during copying to prevent races.
2. Verify the stage contains **exactly** declared outputs. Check import/build
   dependencies; an allowlisted entry can still embed private bytes or refer
   to an undeclared source.
3. Run clean install, tests, and build inside the isolated stage, without
   access to the private project. Inspect both source and built client/server
   artifacts for disallowed paths and sensitive content.
4. Obtain independent safety/content review and Jennifer's publication
   approval. Only then initialize a fresh public Git history in the verified
   output. Never reuse the private project's Git history.

Generation and publication remain separate operations. A fresh history on
every run cannot safely update an existing remote via a normal push; repeated
releases need a reviewed diff/PR against the previous public output or an
explicitly designed publishing workflow, not an automatic force push.
