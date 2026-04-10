# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — Stabilize + Migrate

**Shipped:** 2026-04-10
**Phases:** 3 | **Plans:** 7

### What Was Built

- Fixed RayCast2D collision damage — ray now added to scene tree before query, speed-scaled kinetic damage (speed/10.0)
- Fixed reload signal stacking — CONNECT_ONE_SHOT + is_reloading() guard eliminates duplicate reload cycles
- Replaced all `get_tree().current_scene` spawn parent references with `@export var spawn_parent` propagated recursively through the mount hierarchy
- Eliminated per-frame `find_children()` in `get_mount()` by iterating the pre-cached mounts array
- Replaced string action literals with typed `MountableBody.Action` enum — typos now cause parse errors
- Removed debug print from inventory drag-and-drop hot path
- Migrated project from Godot 4.2.1 to 4.6.2: deprecated connect() calls updated, UID files generated, 4-platform export verified

### What Worked

- Planning bugs before coding caught the full scope (3 bugs vs. guessing one at a time)
- Code review pass on Phase 3 caught 3 additional issues (null guards, invalid bundle ID) that smoke test missed
- Splitting migration into pre-migration fixes (03-01) + editor conversion (03-02) kept each plan small and focused

### What Was Inefficient

- REQUIREMENTS.md traceability table was never updated during execution — all requirements stayed "Pending" despite being shipped
- STATE.md progress tracking drifted from reality (showed 0% complete while phases were finishing)

### Patterns Established

- `@export var spawn_parent: Node` with recursive propagation via mount hierarchy — use this for any node that needs to spawn children into the game world
- `CONNECT_ONE_SHOT` for one-time signal handlers (reload, death) instead of manual disconnect
- `MountableBody.Action` enum — all new action strings must be added as enum values, not raw strings
- Pre-migration deprecation pass as a separate plan before engine conversion

### Key Lessons

1. Keep the traceability table updated during execution, not just at milestone close
2. Code review after migration catches issues the smoke test skips (editor doesn't run all code paths)
3. Godot 4.x migration generates UID files for every script/scene — commit them as a single dedicated commit to keep the diff readable

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 3 | 7 | First milestone — established base patterns |

### Top Lessons (Verified Across Milestones)

1. Small, focused plans (one concern per plan) complete faster and are easier to review
