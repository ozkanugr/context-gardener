# context-gardener

Context files only ever grow: nobody runs a test against a line in `CLAUDE.md` to check it's still true. This plugin gives Claude a skill for verifying every claim against the actual repo before keeping it, plus a hook that nags you (never edits automatically) when a context file has drifted or gotten too big.

## What's inside

- **`skills/context-gardener/SKILL.md`** — the rules: verify before keeping, point instead of copying facts that drift, replace superseded decisions instead of stacking them, dedupe across files, cut ephemeral "currently doing X" state, split by topic once a file gets big, always show the diff before writing.
- **`commands/tidy-context.md`** — `/tidy-context` runs a full pass on demand. Supports `--report-only` (audit, no edits) and `--apply` (skip the confirmation step).
- **`hooks/check-staleness.sh`** — a `SessionStart` hook, zero dependencies (no `jq`, just bash + coreutils). Counts lines across your context files and checks how long it's been since the last grooming pass; if either crosses a threshold, it injects a one-line nudge into the session. It never edits anything itself.

## Install

Two manifests live at the repo root: `.claude-plugin/plugin.json` describes the plugin itself, and `.claude-plugin/marketplace.json` is the separate catalog file `marketplace add` actually reads — it lists the plugin and points `source` at `./` (this same repo root). Both need to be present and pushed for the commands below to work.

```
claude plugin marketplace add ozkanugr/context-gardener
claude plugin install context-gardener@context-gardener
```

To sanity-check before pushing, run `claude plugin validate .` from inside the folder — it catches a missing/malformed `marketplace.json` before you find out the hard way from a teammate's terminal.

For local testing without pushing anywhere:

```
claude plugin marketplace add ./context-gardener
claude plugin install context-gardener@context-gardener
```

## Use it

- On demand: `/tidy-context` (or just `/tidy-context --report-only` if you want a read-only audit first).
- It'll also trigger itself when Claude notices something worth flagging — a CLAUDE.md claim that contradicts what it just saw in the code, for instance.
- Automatically: the `SessionStart` hook will tell Claude when a project's context files are large or stale, and Claude will offer to run it — it won't run unprompted.

## Tune it

Thresholds are env vars, set wherever you configure the hook's environment (or edit the two lines directly in `hooks/check-staleness.sh`):

```
CONTEXT_GARDENER_LINE_THRESHOLD=150   # total lines across all in-scope context files
CONTEXT_GARDENER_DAYS_THRESHOLD=21    # days since the last recorded grooming pass
```

The "last groomed" timestamp lives in `.claude/.context-gardener-log` (one epoch-seconds integer), written by the skill itself at the end of a completed pass — not by the hook. Delete that file to reset the age check; it's safe to `.gitignore` or commit, your call.

Fork and edit `skills/context-gardener/SKILL.md` directly to change the rules (e.g. a stricter line threshold, a different split-by-topic convention, or rules specific to your stack).

## License

MIT.
