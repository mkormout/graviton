---
phase: 01-bug-fixes
plan: 02
subsystem: architecture
tags: [gdscript, godot4, spawn, mount-point, weapon, item, body, explosion]

# Dependency graph
requires: []
provides:
  - "@export var spawn_parent: Node added to body.gd, explosion.gd, item-dropper.gd, mountable-weapon.gd, item.gd, mount-point.gd"
  - "All 7 get_tree().current_scene usages replaced with null-guarded spawn_parent calls"
  - "Null guards with push_warning at every spawn/reparent site"
affects: [01-03-PLAN.md, scene wiring, world.tscn]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "spawn_parent export pattern: editor-wired Node export replaces get_tree().current_scene for all spawning/reparenting"
    - "Null guard pattern: if spawn_parent: ... else: push_warning(...) at every spawn site"

key-files:
  created: []
  modified:
    - components/body.gd
    - components/explosion.gd
    - components/item-dropper.gd
    - components/mountable-weapon.gd
    - components/item.gd
    - components/mount-point.gd

key-decisions:
  - "spawn_parent placed after last existing @export in each file, consistent with CLAUDE.md @export-at-top convention"
  - "mountable-weapon.gd gets a new @export_group('Spawn') section to match existing group structure"
  - "Null guard uses push_warning (editor-visible, non-crashing) rather than assert or silent failure"

patterns-established:
  - "spawn_parent export pattern: all nodes that spawn children use @export var spawn_parent: Node wired in editor"
  - "Null guard at spawn sites: if spawn_parent: ... else: push_warning('spawn_parent not set on ' + name)"

requirements-completed: [BUG-03]

# Metrics
duration: 15min
completed: 2026-04-07
---

# Phase 01 Plan 02: Replace get_tree().current_scene with spawn_parent export

**Editor-wired @export var spawn_parent: Node replaces all 7 fragile get_tree().current_scene calls across 6 component files, with null guards and push_warning fallbacks**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-07T00:00:00Z
- **Completed:** 2026-04-07T00:15:00Z
- **Tasks:** 1
- **Files modified:** 6

## Accomplishments
- Removed all 7 `get_tree().current_scene` usages from components/ — zero remaining
- Added `@export var spawn_parent: Node` to all 6 affected component files
- Added null-guarded spawn/reparent calls with `push_warning` fallback at every site
- Plan 03 (scene wiring) can now proceed — the exports exist in all scripts

## Task Commits

Each task was committed atomically:

1. **Task 1: Add spawn_parent export to all 6 component files and replace get_tree().current_scene** - `52c531f` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `components/body.gd` - Added spawn_parent export; null-guarded die() and add_successor()
- `components/explosion.gd` - Added spawn_parent export; null-guarded generate_debris()
- `components/item-dropper.gd` - Added spawn_parent export; null-guarded drop()
- `components/mountable-weapon.gd` - Added spawn_parent export in new Spawn group; null-guarded fire()
- `components/item.gd` - Added spawn_parent export; null-guarded pick() reparent
- `components/mount-point.gd` - Added spawn_parent export; null-guarded unplug() reparent

## Decisions Made
- Placed `spawn_parent` after the last existing `@export` in each file (CLAUDE.md: exports at top, grouped)
- `mountable-weapon.gd` gets a dedicated `@export_group("Spawn")` to maintain the existing grouped export style
- Used `push_warning` (not assert, not silent) — visible in Godot editor output, non-crashing

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

Worktree setup: initial edits targeted the main repo path instead of the worktree path. Corrected by writing to the worktree-scoped absolute paths. No code changes affected.

## Known Stubs

None - all spawn_parent exports are intentionally unwired at this stage. Plan 03 wires them in the scene. This is expected and documented in the plan's objective.

## Threat Flags

None - no new network endpoints, auth paths, file access patterns, or schema changes introduced. All changes are local GDScript editor-wired properties.

## Next Phase Readiness
- All 6 component scripts now have `@export var spawn_parent: Node`
- Plan 03 (scene wiring) can proceed: wire spawn_parent to the world root node in world.tscn for each component instance
- No blockers

---
*Phase: 01-bug-fixes*
*Completed: 2026-04-07*
