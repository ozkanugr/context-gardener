---
name: context-gardener
description: Audit and prune CLAUDE.md, nested CLAUDE.md files, and project memory files so they stay accurate and small in long-running projects. Verifies every retained claim against the actual repo state, removes duplicate/stale/superseded/ephemeral content, and splits bloated files by topic. Invoke with /tidy-context, or on your own whenever you notice a context file that's grown large, hasn't been groomed in a while, or contains a claim that contradicts what you're seeing in the codebase.
license: MIT
metadata:
  tags: [context, claude-md, memory, maintenance, refactoring]
  category: productivity
---

# context-gardener

Context files (`CLAUDE.md`, nested `CLAUDE.md`, `.claude/context/*.md`, memory files) are read on every single turn of every session. Unlike code, nothing ever runs against them to prove they're still true — they only grow, by whoever last had a reason to add a line. Left alone, they end up: 3 versions of the same fact, an "as of last week" note that's now six months stale, an architecture decision described right next to the one that replaced it, and a file so long that the useful 10% is buried in the other 90%.

This skill treats every line in a context file as a **claim to verify**, not a memory to preserve. A line earns its place by being (a) true right now, (b) not said better somewhere else, and (c) durable — not a fact about today.

## Persistence

Once you start a grooming pass (via `/tidy-context` or on your own judgment), see it through: finish classifying every context file in scope before moving to something else in the same turn. This does not mean grooming runs unprompted forever — it means a pass, once started, isn't abandoned half-scanned.

## What makes context files rot

1. **No source of truth.** A fact gets copied into CLAUDE.md instead of pointed at (`uses React 18` drifts the day someone bumps `package.json`; a note that points at `package.json` never drifts).
2. **Accumulation instead of replacement.** A new architectural decision gets appended under the old one ("Update: we now use X instead") rather than replacing it. Six months later both are still there.
3. **Ephemeral state leaking into permanent files.** "Currently debugging the auth flow" or "TODO before Friday" belongs in a task tracker or a commit, not in a file every session reads forever.
4. **Duplication across files.** The same fact lives in root `CLAUDE.md`, a nested `CLAUDE.md`, and a memory file, and only two of the three get updated when it changes.
5. **No size discipline.** One file keeps growing because splitting it takes more effort than not.

## The rules

### 1. Verify before keeping — never take a claim's word for it

Every factual claim about the codebase gets checked against the codebase before you decide to keep it. Read the file it references, grep for the pattern it describes, check `package.json`/`requirements.txt`/`go.mod` for the dependency it names, confirm the path exists.

Bad: skimming CLAUDE.md, deciding it "looks fine," and moving on.
Good: `"Uses Redis for session storage"` → grep the codebase for a Redis client, check the lockfile for a Redis package. If neither exists, the line is stale — cut it or ask the user.

If you can't verify a claim (it's about intent, a convention, or something outside what you can inspect), don't delete it on suspicion alone — flag it to the user instead of silently dropping it.

### 2. Point, don't copy

If the fact already lives somewhere that's guaranteed to stay current (`package.json`, a config file, a README, the code itself), don't restate it in CLAUDE.md — reference where it lives instead.

Bad: `"Dependencies: react 18.2, express 4.18, prisma 5.1..."` (drifts on the next `npm update`)
Good: `"Dependency versions: see package.json"`

Keep facts in CLAUDE.md only for things that live nowhere else: conventions, decisions, non-obvious constraints, things that aren't derivable by reading the repo.

### 3. Decisions supersede; they don't stack

When a new decision replaces an old one, the old line gets replaced, not appended-after with a changelog note. CLAUDE.md is not a diary.

Bad:
```
- We use REST for the API.
- Update (June): We migrated to GraphQL. REST is deprecated.
```
Good:
```
- API is GraphQL (migrated from REST in June; see ADR-014 for why).
```
One line, current state, a pointer to history if the *why* still matters — not the stale claim left standing next to its correction.

### 4. One fact, one file

Before adding or keeping a claim, check whether it's already stated elsewhere in scope (root `CLAUDE.md`, nested `CLAUDE.md` files, memory files). If it is, keep it in the most specific applicable file and remove the copies — or promote it to a shared file the others can point at instead of promote-by-copy.

### 5. Ephemeral state doesn't belong in a permanent file

Anything phrased as "currently," "as of [date]," "in progress," "TODO," "WIP," or describing the state of a specific task rather than a fact about the project is a candidate for removal, not preservation, once you're grooming. If it's still relevant, it belongs in an issue tracker, a `TODO.md`, or a commit message — not in a file every future session pays the token cost of reading.

Exception: a standing convention that happens to use present tense ("currently we require 90% test coverage on new modules") is not ephemeral — the tell is whether it describes a task's status or a rule that holds until someone changes it.

### 6. Cap size; split by domain, not by dumping

If a context file is pushing past what's comfortable to read in one pass (rough guide: **~150 lines** for a single `CLAUDE.md`), don't just trim harder — split it. Move a self-contained topic (e.g. "database conventions," "deploy process," "testing philosophy") into `.claude/context/<topic>.md` and leave a one-line pointer plus a short index in `CLAUDE.md` itself, so the router file stays small and the detail loads only when relevant. This mirrors how a large SKILL.md should point to `references/` instead of growing forever — same principle, applied to project memory.

Don't split preemptively — a 40-line CLAUDE.md that's all still true doesn't need fragmenting. Split when size is actually getting in the way of the file doing its job.

### 7. Show your work before writing

Grooming is a destructive edit to a file the user depends on every session. Before writing changes:
- Summarize what you're removing and why (stale / duplicate / ephemeral / superseded), grouped, not line-by-line if the list is long.
- Summarize what you're keeping but rewording (verbose → tightened), only if the rewording changes meaning — pure style tightening doesn't need a line-by-line justification.
- Flag anything you couldn't verify either way and ask, rather than guessing.
- Get a go-ahead before writing, unless the user invoked this expecting a direct edit (e.g. `/tidy-context --apply` or has said "just do it" this session) — treat this the same as any other destructive-action rule: confirm first by default.

### 8. Record the pass

After a grooming pass completes and is applied, write the current time to `.claude/.context-gardener-log` (one epoch-seconds integer, overwrite the file). This is what the maintenance hook uses to know when the context was last groomed — without it, the hook can't tell "just groomed" from "never touched."

## Workflow

1. **Find scope.** Locate `CLAUDE.md` at the repo root, any nested `CLAUDE.md` in subdirectories, and `.claude/context/*.md`. If the user named a specific file, scope to that one.
2. **Read and atomize.** Break each file into individual claims — ideally one bullet, one claim. Prose paragraphs get mentally (or actually) split into their component claims for classification.
3. **Classify each claim** against rules 1–5: current-and-unique / stale / duplicate / superseded / ephemeral / unverifiable.
4. **Resolve.** Keep current-and-unique claims (tightened to a fact if they were prose). Remove or correct stale ones. Collapse duplicates to one location. Replace superseded ones. Cut ephemeral ones (or offer to move them somewhere more appropriate, like an issue). Ask about unverifiable ones you're unsure of.
5. **Check size.** If what remains still exceeds the size guideline, split by domain per rule 6.
6. **Present the diff, get confirmation, write.**
7. **Log the pass** per rule 8.

## When to break the rules

1. **User just wants a report, not an edit.** "What's stale in my CLAUDE.md?" is a read-only audit — do steps 1–4, present findings, don't write anything unless asked.
2. **File is small and current.** If a pass finds nothing wrong, say so briefly and stop — don't manufacture changes to look thorough.
3. **Genuine ambiguity about whether something is still true.** Ask the user rather than guessing in either direction (neither "keep everything just in case" nor "cut anything I can't 100% verify").
4. **The user explicitly wants a specific claim kept even though you can't verify it** (e.g., a forward-looking convention that isn't in the code yet). Respect that — note it as intentional rather than re-flagging it on the next pass.
