# WWW::MetaForge House Rules

The shared house rules come from skilletor — bundle `getty-cpan-dist@getty`: engineering
discipline, the delegation lock, the publish gate, karr coordination, CPAN release. They load
as `.claude/rules/.local.*.md`; if they are missing, run `skilletor sync` and publish nothing
until they load. This file adds what is true only here, and wins where it differs.

## What this repo is

Perl client for the MetaForge gaming APIs. Read first: the immediate callers — a `Result/*`
attribute is consumed by the facade and by `CLI/Cmd/*`.

## Agent team

| Task | Agent |
|---|---|
| Implement / refactor / debug facades, Request, Result classes, cache, CLI | `www-metaforge-worker` (default) |
| Write/extend tests and fixtures under `t/` | `www-metaforge-test-writer` |
| Commits, `Changes`, card → done, pre-release audit | `www-metaforge-release-manager` |
| Read-only research, audit, gap analysis | `www-metaforge-worker` ("read-only, change nothing") |

Behavior-relevant = everything under `lib/` and `bin/`, plus `t/` and `t/fixtures/`. Pure
prose docs and `Changes` notes are not.

## Hazards — the short form (mechanism and background: skill `www-metaforge-core`)

- **The live API is the spec.** No speculative fallbacks, no attributes for fields the API
  never sends. When the response changes, change the result class *and* its byte-faithful
  fixture in `t/fixtures/` in the same commit — a tidied fixture makes the whole suite lie.
- **Live-API tests can hang, not just fail.** No timeout: debug per file with `timeout 25
  perl -Ilib -It/lib t/NN-foo.t`. Never report "tests pass" from a run you killed, or when
  tests hung or needed the network.
- **Grep the CLI before removing a Result attribute** — `CLI/Cmd/*` calls accessors
  directly and dies only at runtime, which the offline suite may not reach.
- **Never edit the downstream twin `p5-mcp-arcraiders` from here.** A change to its method
  signatures, the `Cache` constructor or a Result attribute breaks that repo: record it as a
  karr ticket on its board.

## Perl specifics — reference, don't restate

Module loading, Moo patterns, cpanfile pinning and house style live in `getty-perl-core` /
`getty-perl-moo`; architecture and the exact-format rule in `www-metaforge-core`
(force-loaded for `www-metaforge-*` agents).
