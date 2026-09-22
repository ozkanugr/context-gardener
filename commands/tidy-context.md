---
description: Audit and prune CLAUDE.md / nested CLAUDE.md / project memory files — verify claims against the repo, remove stale/duplicate/ephemeral content, split if bloated.
argument-hint: "[path-to-file] [--apply] [--report-only]"
---

Run a full grooming pass using the `context-gardener` skill, scoped to: $ARGUMENTS

If no path is given, scope to `CLAUDE.md` at the repo root plus any nested `CLAUDE.md` and `.claude/context/*.md` files.

- If `--report-only` is passed: do steps 1–4 of the workflow (find, read, classify, summarize) and stop. Do not write anything.
- If `--apply` is passed: skip the confirmation step and write directly after classifying, then still show a summary of what changed.
- Otherwise: run the full workflow, including presenting the diff and waiting for confirmation before writing.

Follow the context-gardener skill's rules and workflow exactly.
