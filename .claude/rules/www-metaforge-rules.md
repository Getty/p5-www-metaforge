# WWW::MetaForge House Rules

Apply to every task in this repository unless explicitly overridden. Bias: caution over
speed on non-trivial work; use judgment on trivial tasks. Loaded automatically at launch
(same priority as `CLAUDE.md`). Subagents get their discipline via `briefing.skills`.

## Engineering discipline

1. **Think before coding** — State assumptions, ask rather than guess, present alternatives
   when ambiguous, push back if a simpler approach exists, stop when confused, name what is unclear.
2. **Simplicity first** — Minimum code that solves the problem. Nothing speculative, no
   abstraction for single-use code.
3. **Surgical changes** — Touch only what you must; don't "improve" adjacent code, comments
   or formatting. Match existing style.
4. **Read before you write** — Before new code, read the immediate callers: a `Result/*`
   attribute is consumed by the facade and by `CLI/Cmd/*`. "Looks orthogonal" is dangerous.
5. **Tests verify intent** — Reproduce a bug before fixing it; leave a regression test
   behind. A test that can't fail when the logic changes is wrong.
6. **Surface conflicts, don't average them** — pick one (more recent / more tested), explain why,
   flag the other for cleanup. Conformance > taste: surface a harmful convention, don't fork silently.
7. **Fail loud** — "Done" is wrong if anything was skipped silently; "Tests pass" is wrong
   if any were skipped, hung or need the network. Surface uncertainty, don't hide it.

## Delegation

This rule depends on whether the Agent/Task tool is available to you.

- **You can spawn subagents** (orchestrating main agent): Do NOT touch behavior-relevant code
  yourself — delegate. Your lane: coordinate, inspect, plan, review diffs, run tests, edit
  non-behavioral docs. When in doubt, delegate. Why: only the `www-metaforge-*` agents are briefed.

  | Task | Agent |
  |---|---|
  | Implement / refactor / debug facades, Request, Result classes, cache, CLI | `www-metaforge-worker` (default) |
  | Write/extend tests and fixtures under `t/` | `www-metaforge-test-writer` |
  | Commits, `Changes`, card → done, pre-release audit | `www-metaforge-release-manager` |

- **You cannot spawn subagents** (you ARE a `www-metaforge-*` agent): The delegation lock does
  not apply — implement, refactor, debug and test per these rules.

Behavior-relevant = everything under `lib/` and `bin/`, plus `t/` and `t/fixtures/`. Pure
prose docs and `Changes` notes are not.

**Only `www-metaforge-release-manager` commits.** A worker leaves a commit-ready tree and hands
its card to `review`; you then dispatch the release-manager to cut the commit and close the card.

## Hazards — the short form (mechanism and background: skill `www-metaforge-core`)

- **The live API is the spec.** No speculative fallbacks, no attributes for fields the API never
  sends. When the response changes, change the result class *and* its byte-faithful fixture in
  `t/fixtures/` in the same commit — a tidied fixture makes the whole suite lie.
- **Live-API tests can hang, not just fail.** No timeout: debug per file with `timeout 25 perl
  -Ilib -It/lib t/NN-foo.t`. Never report "tests pass" from a run you killed.
- **Grep the CLI before removing a Result attribute** — `CLI/Cmd/*` calls accessors
  directly and dies only at runtime, which the offline suite may not reach.
- **Never edit the downstream twin `p5-mcp-arcraiders` from here.** A change to its method
  signatures, the `Cache` constructor or a Result attribute breaks that repo: record it as a
  karr ticket on its board.

## Coordination — karr board (always in scope)

`karr` is the internal board — git-native, state in `refs/karr/*`, one board per repo.
Ticket coordination is the orchestrating agent's job: just use it, don't invoke a skill first.

- `karr list --compact` / `karr board` — open work · `karr show ID` — detail
- `karr create "Title" --priority high --tags a,b --body '…'` — new ticket
- `karr edit ID -a "note"` · `--claim NAME` · `--block "why"` — update
- `karr move ID in-progress --claim NAME` — start · `karr handoff ID --claim NAME --note "…"` — to review

Drift found mid-change becomes a ticket, not scope creep. **Serialize board mutations when fanning
out** — collect results, then loop `karr move`/`handoff`/`sync` sequentially. Surface: skill
`kanban-issues-karr-coordination`.

## Release — never without permission

`dzil build` / `dzil test` / `prove -l t/` are fine anytime. `dzil release`, any CPAN upload,
`git push` and any tag are STRICTLY forbidden without the maintainer's explicit go-ahead — even
if a plan lists "release" as the next step: stop and ask.

## Public issues — never act without instruction

GitHub carries real humans' bug reports under the maintainer's account; **karr** is the internal
board. Never list, read, comment on, edit, close or create a GitHub issue on your own initiative —
only on explicit instruction.

## Perl specifics — reference, don't restate

Module loading, Moo patterns, cpanfile pinning and house style live in `getty-perl-core` /
`getty-perl-moo`; architecture and the exact-format rule in `www-metaforge-core` (force-loaded for
`www-metaforge-*` agents). Don't duplicate that here.
