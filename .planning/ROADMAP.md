# Roadmap: Graviton

## Overview

Three phases across two milestones stabilize the mount-and-weapon core before upgrading the engine. Milestone 1 fixes known bugs and removes fragile patterns. Milestone 2 migrates the clean codebase to Godot 4.6.2. Enemy AI (Milestone 3) is out of scope until migration is complete.

## Milestones

- 🚧 **Milestone 1 — Stabilize** — Phases 1-2 (bug fixes + code quality)
- 📋 **Milestone 2 — Migrate** — Phase 3 (Godot 4.6.2 upgrade)

## Phases

- [ ] **Phase 1: Bug Fixes** - Fix three known defects that cause incorrect runtime behavior
- [ ] **Phase 2: Code Quality** - Eliminate fragile patterns that cause silent failures and wasted CPU
- [ ] **Phase 3: Godot 4.6.2 Migration** - Upgrade engine and verify the project runs correctly on 4.6.2

## Phase Details

### Phase 1: Bug Fixes
**Goal**: Known defects that cause incorrect runtime behavior are eliminated
**Depends on**: Nothing (first phase)
**Requirements**: BUG-01, BUG-02, BUG-03
**Success Criteria** (what must be TRUE):
  1. Collision with an asteroid deals the expected damage and the contact position is determined correctly (RayCast2D added to scene tree before query)
  2. Firing and reloading a weapon multiple times does not cause ammo to refill more than once per reload cycle
  3. Bullets, explosions, item drops, and debris spawn successfully after any restructuring of the scene hierarchy (no reliance on `get_tree().current_scene`)
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md — Fix RayCast2D collision damage (BUG-01) and reload signal stacking (BUG-02)
- [x] 01-02-PLAN.md — Replace get_tree().current_scene with @export spawn_parent in 6 component files (BUG-03 code)
- [x] 01-03-PLAN.md — Wire spawn_parent exports in Godot editor + propagate to dynamic spawns (BUG-03 wiring)

### Phase 2: Code Quality
**Goal**: Fragile patterns that cause silent failures and excess CPU cost are replaced with robust alternatives
**Depends on**: Phase 1
**Requirements**: QUA-01, QUA-02, QUA-03
**Success Criteria** (what must be TRUE):
  1. Action dispatch uses typed constants — a typo in an action name produces a GDScript error or warning, not silent failure
  2. Mount point lookup does not call `find_children()` inside `_physics_process` — mounts are cached and invalidated only on mount/unmount events
  3. No `print()` calls fire during normal drag-and-drop interactions in the inventory UI
**Plans**: 2 plans

Plans:
- [x] 02-01-PLAN.md — Fix get_mount() cache (QUA-02) and remove drag-and-drop debug print (QUA-03)
- [x] 02-02-PLAN.md — Replace string action literals with typed MountableBody.Action enum across 4 files (QUA-01)

### Phase 3: Godot 4.6.2 Migration
**Goal**: The project opens, runs, and exports correctly on Godot 4.6.2 with no deprecated API warnings or errors
**Depends on**: Phase 2
**Requirements**: MIG-01, MIG-02, MIG-03
**Success Criteria** (what must be TRUE):
  1. Project opens in Godot 4.6.2 editor with no import errors or conversion failures
  2. The game runs in-editor and as an exported build with no runtime errors attributable to deprecated or removed API calls
  3. Export presets produce a working executable for at least one target platform
**Plans**: TBD

## Progress

**Execution Order:** 1 → 2 → 3

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Bug Fixes | 0/3 | Not started | - |
| 2. Code Quality | 0/2 | Not started | - |
| 3. Godot 4.6.2 Migration | 0/? | Not started | - |
