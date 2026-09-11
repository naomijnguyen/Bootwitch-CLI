# Project memory

This folder keeps the current project context understandable between work
sessions. It complements the public-facing `README.md`: the main README
explains the project to a visitor, while these files record its working state,
decisions, questions, and history.

## Files

- `state.md` is the current source of truth and the best place to resume work.
- `decisions.md` records choices, alternatives, and reasons.
- `questions.md` holds unresolved questions without losing them in chat.
- `updates/` contains one consistently formatted summary for each substantial
  work session or milestone.

## After a work session

1. Copy `updates/update-template.md` to a dated, descriptive filename such as
   `2026-09-03-shell-template-review.md`.
2. Fill in only what happened; write `None` when a section matters but had no
   changes.
3. Record the conversation link when one is available. Always include its task
   ID or a descriptive title as a fallback reference.
4. Record the Git commit before and after the work. Use `Not committed` when
   changes intentionally remain under review.
5. Refresh `state.md` so it describes the project now, not its full history.
6. Move settled questions into `decisions.md` when an answer affects the
   project direction.

Keep private information, credentials, personal paths, and raw chat transcripts
out of this folder because project documentation may later be published.
