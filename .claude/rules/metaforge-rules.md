# WWW::MetaForge House Rules

Apply to every task in this repository unless explicitly overridden. Bias: caution over
speed on non-trivial work; use judgment on trivial tasks. Loaded automatically by Claude
Code at launch (same priority as `CLAUDE.md`). Subagents get their discipline from the
skills force-loaded via `briefing.skills` — this file is for the orchestrating agent.

## Engineering discipline

1. **Think before coding** — State assumptions. When uncertain, ask rather than guess.
   Present alternatives when ambiguous. Push back when a simpler approach exists. Stop when
   confused; name what's unclear.
2. **Simplicity first** — Minimum code that solves the problem. Nothing speculative. No
   abstractions for single-use code.
3. **Surgical changes** — Touch only what you must. Don't "improve" adjacent code,
   comments or formatting. Match existing style.
4. **Read before you write** — Before new code, read the immediate callers: a `Result/*`
   attribute is consumed by the facade and by `CLI/Cmd/*`. "Looks orthogonal" is dangerous.
5. **Tests verify intent, not just behavior** — A test that can't fail when the logic
   changes is wrong. Reproduce a bug before fixing it; leave a regression test behind.
6. **Surface conflicts, don't average them** — Contradicting patterns: pick one (more
   recent / more tested), explain why, flag the other for cleanup. Don't blend.
7. **Match the codebase's conventions, even if you disagree** — Conformance > taste.
   Surface a harmful convention; don't fork silently.
8. **Fail loud** — "Done" is wrong if anything was skipped silently. "Tests pass" is wrong
   if any were skipped, hung or need the network. Surface uncertainty, don't hide it.

## Delegation

Depends on whether the Agent/Task tool is available to you.

- **You can spawn subagents** (orchestrating main agent): Do NOT touch behavior-relevant
  code yourself — delegate. Your lane: coordinate, inspect, plan, review diffs, run tests,
  manage git, edit non-behavioral docs. Why: only the `metaforge-*` agents get their skills
  force-loaded via `briefing.skills`; you get no briefing and would touch internals with
  too little context.

  | Task | Agent |
  |---|---|
  | Implement / refactor / debug facades, Request, Result classes, cache, CLI | `metaforge-worker` (default) |
  | Write/extend tests and fixtures under `t/` | `metaforge-test-writer` |
  | Pre-release audit (Changes, cpanfile, dist.ini, `$VERSION`, POD) | `metaforge-release-checker` |

- **You cannot spawn subagents** (you ARE a `metaforge-*` agent): The delegation lock does
  not apply — implement, refactor, debug and test per these rules.

Behavior-relevant = everything under `lib/` and `bin/`, plus `t/` and `t/fixtures/`. Pure
prose docs and `Changes` notes are not.

## Hazards

- **The API is the spec, and it moves.** This client supports only the exact live response
  format — no speculative fallbacks, no attributes for fields the API doesn't send. The
  trap: a `//` fallback makes a real API change look like a working client with silently
  wrong data. When the response changes, change the result class *and* its fixture in
  `t/fixtures/` in the same commit.
- **A tidied fixture makes the whole suite lie.** Fixtures must be byte-faithful to the
  real response — same keys, same camelCase, same nesting.
- **`prove -l t/` can hang, not just fail.** Live-API tests hit the network with no
  timeout, so a slow API looks like a wedged suite. Debug per file:
  `timeout 25 perl -Ilib -It/lib t/NN-foo.t`. Never report "tests pass" from a run you
  killed.
- **Dropping a Result attribute breaks the CLI silently at the source level** —
  `CLI/Cmd/*` calls accessors directly and only dies at runtime, which the offline suite
  may not reach. Grep the CLI for the accessor before removing it.

## Coordination — karr board

Ticket coordination is the orchestrating agent's job, so `karr` is always in scope — don't
invoke a skill first, just run it:

- `karr list --compact` / `karr board` — open work · `karr show ID` — detail
- `karr create "Title" --priority high --tags a,b --body '…'` — new ticket
- `karr edit ID -a "note"` · `--claim NAME` · `--block "why"` — update
- `karr move ID in-progress --claim NAME` — start · `karr handoff ID --claim NAME --note "…"` — to review

Drift found mid-change becomes a ticket, not scope creep. **Serialize board mutations when
fanning out** — collect results, then loop `karr move`/`handoff`/`sync` sequentially.
Full command surface: skill `kanban-issues-karr-cli`.

## Release — never without permission

`dzil build` / `dzil test` / `prove -l t/` are fine anytime. `dzil release` and any CPAN
upload are STRICTLY forbidden without the maintainer's explicit go-ahead — even if a plan
lists "release" as the next step. For anything heading toward release: stop and ask.

## Perl specifics — reference, don't restate

Module loading, Moo patterns, cpanfile pinning for Getty-authored deps and house style live
in skills `perl-core` / `perl-moo`; the distribution's architecture and the exact-format
rule live in `metaforge-core` (all force-loaded for `metaforge-*` agents). Do not duplicate
that content here.
