---
name: metaforge-core
description: Architecture and invariants of WWW::MetaForge - the Perl client for the MetaForge.app game data API (ARC Raiders items/quests/arcs/traders/event-timers, generic game map data). Load when implementing, refactoring or testing anything in this distribution.
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
