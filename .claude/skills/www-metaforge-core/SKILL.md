---
name: www-metaforge-core
description: "Load before editing WWW::MetaForge — the MetaForge.app game data API client: layers, endpoints, the result-class contract, the exact-API-format rule, the hazards and the downstream twin."
---

# WWW::MetaForge — core

Perl client library for the [MetaForge.app](https://metaforge.app) game data API.
Moo objects, no inheritance-heavy design: an API facade builds Request objects,
runs them through a UA, and turns JSON into Result objects.

## Layers

| Layer | Where | Job |
|---|---|---|
| API facade | `WWW::MetaForge::ArcRaiders`, `WWW::MetaForge::GameMapData` | public methods (`items`, `quests`, `traders`, `markers`, …), caching, pagination |
| Request | `*/Request.pm` | build an `HTTP::Request`; owns URL + query construction |
| Result | `*/Result/*.pm` | parse one API record via `from_hashref($data)` |
| Cache | `WWW::MetaForge::Cache` | optional response cache shared by both APIs |
| CLI | `WWW::MetaForge::ArcRaiders::CLI` + `CLI/Cmd/*` | MooX::Cmd + MooX::Options; `bin/metaforge-arcraiders` (installed as `arcraiders`) |

Two API namespaces are deliberately separate: `ArcRaiders` and `GameMapData`
each have their own `Request` and their own `MapMarker` result class. Do not
merge them or make one `use` the other.

## Endpoints

```
https://metaforge.app/api/arc-raiders/{items,quests,arcs,traders,event-timers}
https://metaforge.app/api/game-map-data?tableID=arc_map_data&mapID={dam,spaceport,riven-tides,stella-montis,...}
```

## Result-class contract

- Constructor for API data is always `from_hashref($class, $data)` — never a
  hand-rolled `new` call from the API layer.
- Every result keeps the untouched response record in `_raw` (`HashRef`,
  required). Attributes are the curated view; `_raw` is the escape hatch.
- Attributes are `is => 'ro'` with a `Types::Standard` `isa`. `ArrayRef`/
  `HashRef` attributes get `default => sub { [] }` / `sub { {} }`, not `Maybe`.
- API keys are camelCase, attributes are snake_case; the mapping happens in
  `from_hashref` and nowhere else.

## The one hard rule: exact API format only

**Support ONLY the exact format the live API returns. No speculative
fallbacks.** No `$data->{price} // $data->{trader_price}`, no attributes for
fields the API does not send, no "in case they rename it" branches. When the
API changes, the result class changes and the fixture changes with it — that is
the whole point of the design. A speculative fallback hides a real API change
behind a silently-wrong value.

Corollary: an attribute that only ever holds `undef` because the API never
sends the field is a bug — delete it.

## Hazards — the mechanisms behind the short rules

**The API is the spec, and it moves.** The trap: a `//` fallback makes a real
API change look like a working client with silently wrong data. When the
response changes, change the result class *and* its fixture in `t/fixtures/` in
the same commit — a fixture that lags behind the class lets the suite pass
against a format the API no longer sends.

**A tidied fixture makes the whole suite lie.** Fixtures must be byte-faithful
to the real response — same keys, same camelCase, same nesting. "Tidy" JSON is
the classic way to freeze a stale format into the test suite.

**`prove -l t/` can hang, not just fail.** The live-API tests hit the network
with no timeout, so a slow API looks like a wedged suite. Debug per file:
`timeout 25 perl -Ilib -It/lib t/NN-foo.t`. Never report "tests pass" from a
run you killed.

**Dropping a Result attribute breaks the CLI silently at the source level.**
`CLI/Cmd/*` calls accessors directly and only dies at runtime, which the
offline suite may not reach. Grep the CLI for the accessor before removing it.

**A downstream twin consumes this distribution.** `p5-mcp-arcraiders`
(`MCP::ArcRaiders`) `use`s `WWW::MetaForge::ArcRaiders` and
`WWW::MetaForge::Cache` directly — it constructs the facade with an injected
`ua`/`cache` and reads Result accessors. Changing the `ArcRaiders` public
method signatures, the `Cache` constructor/namespace behaviour, or a Result
attribute is a breaking change *for that repo too*. It is a separate
distribution: never edit it from here — record the impact as a karr ticket on
the `p5-mcp-arcraiders` board (cross-repo handoff), not a direct change.

## Testing

```bash
prove -l t/                    # MockUA fixtures, no network
USE_LIVE_API=1 prove -l t/     # against the live API
```

- Default runs go through `t/lib/MockUA.pm`; fixtures live in `t/fixtures/` and
  **must be byte-faithful to the real API response** (same keys, same casing,
  same nesting). A hand-tidied fixture makes the suite lie.
- `Test::More` + `done_testing`, one `subtest` per behavior. Read a neighbouring
  test file before adding one.
- Some tests only run with `USE_LIVE_API=1`; those hit the network and can hang
  when the API is slow — run a single file with a timeout when debugging.

## Related

- `p5-mcp-arcraiders` — the downstream twin (`MCP::ArcRaiders`). What changes
  here is breaking there; its board (`karr` in that repo) takes the ticket.
