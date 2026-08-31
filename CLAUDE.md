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

## CLI

Binary: `bin/metaforge-arcraiders` (installed as `arcraiders`)

Commands use MooX::Cmd + MooX::Options in `lib/WWW/MetaForge/ArcRaiders/CLI/Cmd/`.

Architecture (layers, the result-class contract, the exact-API-format rule) and the
testing/fixture rules live in skill `www-metaforge-core`; the `arcraiders` conventions are
not restated here.

## Delegation

Delegate behavior-relevant code to the right agent instead of touching it yourself —
principle, lanes and project hazards are in `.claude/rules/www-metaforge-rules.md`.

| Task | Agent |
|---|---|
| Implement / refactor / debug facades, Request, Result classes, cache, CLI | `www-metaforge-worker` (default) |
| Write/extend tests and fixtures under `t/` | `www-metaforge-test-writer` |
| Pre-release audit | `www-metaforge-release-checker` |

The agents carry their skills via `briefing.skills` (see `.claude/agents/`); the main agent
delegates rather than loading them. Skill sources live under `.claude/skills/`
(`www-metaforge-core` is project-owned; the `getty-perl-*`, `perl-release-dist-ini` and
`kanban-issues-karr-cli` skills are hardlinked shares — never edit them with Edit/Write,
see skill `manage-skills`).
