# CLAUDE.md

## Project Overview

Perl client library for [MetaForge.app](https://metaforge.app) game data API.

## Modules

- **WWW::MetaForge::ArcRaiders** - ARC Raiders game API (items, quests, arcs, traders, events)
- **WWW::MetaForge::GameMapData** - Generic map marker API (separate from ArcRaiders)

## Key API Endpoints

```
ArcRaiders:     https://metaforge.app/api/arc-raiders/{items,quests,arcs,traders,event-timers}
GameMapData:    https://metaforge.app/api/game-map-data?tableID=arc_map_data&mapID={dam,spaceport,...}
```

## Testing

```bash
prove -l t/                    # Run with MockUA fixtures
USE_LIVE_API=1 prove -l t/     # Run against live API
```

Fixtures in `t/fixtures/` must match exact API response format.

## CLI

Binary: `bin/metaforge-arcraiders` (installed as `arcraiders`)

Commands use MooX::Cmd + MooX::Options in `lib/WWW/MetaForge/ArcRaiders/CLI/Cmd/`.

## Code Style

- Moo for OOP
- Result classes parse API responses via `from_hashref()`
- Request classes build HTTP::Request objects
- Support ONLY exact API format - no speculative fallbacks

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it yourself —
principle, lanes and project hazards are in `.claude/rules/metaforge-rules.md`.

| Task | Agent |
|---|---|
| Implement / refactor / debug facades, Request, Result classes, cache, CLI | `metaforge-worker` (default) |
| Write/extend tests and fixtures under `t/` | `metaforge-test-writer` |
| Pre-release audit | `metaforge-release-checker` |

The agents carry their skills via `briefing.skills` (see `.claude/agents/`); the main agent
delegates rather than loading them. Skill sources live under `.claude/skills/`
(`metaforge-core` is project-owned; the `perl-*` and `kanban-issues-karr-cli` skills are
hardlinked shares — never edit them with Edit/Write, see skill `manage-skills`).
