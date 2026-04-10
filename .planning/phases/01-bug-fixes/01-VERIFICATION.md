---
phase: 01-bug-fixes
verified: 2026-04-07T21:00:00Z
status: human_needed
score: 3/3 must-haves verified (code); 1 behavioral item needs human re-confirmation
overrides_applied: 0
human_verification:
  - test: "Fire weapon, destroy asteroid, pick up item, unmount weapon — full smoke test"
    expected: "Bullets appear in world. Asteroid fragments and debris spawn. Pick sound plays after coin pickup. Weapon flies away on unmount. No 'spawn_parent not set on' warnings in Output panel."
    why_human: "Runtime game behavior requires the Godot engine to run. The Plan 03 checkpoint was approved by the user during execution (see 01-03-SUMMARY.md commit efe98d6) — this item is carried forward for completeness. If the user's approval at checkpoint is accepted as evidence, status can be set to passed."
---

# Phase 01: Bug Fixes Verification Report

**Phase Goal:** Known defects that cause incorrect runtime behavior are eliminated
**Verified:** 2026-04-07T21:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Collision with an asteroid deals expected damage; contact position determined correctly (RayCast2D added to tree before query) | VERIFIED | `ship.gd:body_entered` — `add_child(ray)` at line 40, `ray.force_raycast_update()` at line 41, `to_local(body.global_position)` at line 39, `speed / 10.0` at line 47, `ray.queue_free()` at line 43. No `attack.kinetic = 1000` remains. |
| 2 | Firing and reloading multiple times does not cause ammo to refill more than once per reload cycle | VERIFIED | `mountable-weapon.gd:reload()` at line 67 — `if is_reloading(): return` guard at line 68, `CONNECT_ONE_SHOT` flag at line 71. Old bare `connect("timeout", reloaded)` without flag is absent. |
| 3 | Bullets, explosions, item drops, and debris spawn successfully without reliance on `get_tree().current_scene` | VERIFIED (code) | Zero `get_tree().current_scene` references in entire codebase (confirmed by grep across all `.gd` files). `world.gd` has `setup_spawn_parent()` called on ship (line 40), weapons (line 144), asteroids (line 166). `body.gd` has `_propagate_spawn_parent()` used in `die()` and `add_successor()`. `item-dropper.gd` propagates `spawn_parent` to dropped items. Null guards with `push_warning` at all 7 original call sites. |

**Score:** 3/3 truths verified in code

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `components/ship.gd` | Fixed `body_entered` — RayCast2D added to tree, speed-scaled damage | VERIFIED | `add_child(ray)`, `force_raycast_update()`, `to_local()`, `speed / 10.0`, `ray.queue_free()` all present at lines 37-48 |
| `components/mountable-weapon.gd` | Fixed reload — `CONNECT_ONE_SHOT` + `is_reloading()` guard | VERIFIED | Guard at line 68, `CONNECT_ONE_SHOT` at line 71; no bare `connect("timeout", reloaded)` |
| `components/body.gd` | `spawn_parent` export + null-guarded `die()` and `add_successor()` + `_propagate_spawn_parent()` | VERIFIED | `@export var spawn_parent: Node` at line 11; `node.spawn_parent = spawn_parent` propagation in `die()` at line 44; `_propagate_spawn_parent()` defined at line 59 and called in `add_successor()` at line 76 |
| `components/explosion.gd` | `spawn_parent` export + null-guarded `generate_debris()` | VERIFIED | `@export var spawn_parent: Node` at line 14; null-guarded `spawn_parent.call_deferred("add_child", node)` at lines 73-76 |
| `components/item-dropper.gd` | `spawn_parent` export + null-guarded `drop()` + propagates to dropped items | VERIFIED | `@export var spawn_parent: Node` at line 5; duck-typed propagation `if "spawn_parent" in node: node.spawn_parent = spawn_parent` at lines 19-20; null-guarded add at lines 21-24 |
| `components/mountable-weapon.gd` | `spawn_parent` accessible (inherited) + null-guarded `fire()` + propagates to bullets | VERIFIED | Inherits `spawn_parent` from `Body` via `MountableBody` (no duplicate export — correct). Duck-typed propagation `if "spawn_parent" in instance: instance.spawn_parent = spawn_parent` at lines 111-112; null-guarded add at lines 113-116 |
| `components/item.gd` | `spawn_parent` accessible (inherited) + null-guarded `pick()` reparent | VERIFIED | Inherits `spawn_parent` from `Body`. Null-guarded `pick_sound.reparent(spawn_parent)` at lines 11-14 |
| `components/mount-point.gd` | `spawn_parent` export + null-guarded `unplug()` reparent | VERIFIED | `@export var spawn_parent: Node` at line 10; null-guarded `body_opposite.reparent(spawn_parent)` at lines 44-47 |
| `world.gd` | `setup_spawn_parent()` helper called at all static spawn sites | VERIFIED | `setup_spawn_parent($ShipBFG23)` in `_ready()` at line 40; `setup_spawn_parent(weapon)` in `mount_weapon()` at line 144; `setup_spawn_parent(asteroid)` in `add_asteroid()` at line 166 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ship.gd:body_entered` | RayCast2D collision point | `add_child(ray)` before `force_raycast_update()` | WIRED | Lines 40-41; ordering correct |
| `mountable-weapon.gd:reload` | `reload_timer.timeout` signal | `CONNECT_ONE_SHOT` flag | WIRED | Line 71; flag present |
| `body.gd:die` | `spawn_parent.add_child(node)` | null guard then `add_child` | WIRED | Lines 45-48 |
| `body.gd:die` | `node.spawn_parent = spawn_parent` | propagation before `add_child` | WIRED | Line 44; set before tree entry |
| `body.gd:add_successor` | `_propagate_spawn_parent(successor)` | recursive propagation | WIRED | Line 76; propagates to all children including `ItemDropper` |
| `mountable-weapon.gd:fire` | `spawn_parent.call_deferred("add_child", instance)` | null guard then deferred add | WIRED | Lines 113-116 |
| `world.gd:_ready` | `setup_spawn_parent($ShipBFG23)` | recursive tree walk | WIRED | Line 40 |
| `world.gd:mount_weapon` | `setup_spawn_parent(weapon)` | called before `mount_weapon()` | WIRED | Lines 143-145; set before mounting |
| `world.gd:add_asteroid` | `setup_spawn_parent(asteroid)` | called after `add_child` | WIRED (safe) | Lines 165-166; `_ready()` runs first but spawn_parent not used in `_ready()` — only used at destroy time |

### Data-Flow Trace (Level 4)

Not applicable — this phase fixes runtime defects in game logic (physics, signals, spawn), not data-rendering pipelines.

### Behavioral Spot-Checks

Step 7b: SKIPPED — requires Godot engine to run; no standalone CLI entry point exists. Behavioral verification was performed manually by the user at the Plan 03 checkpoint (approved, commit referenced as `Task 2: Checkpoint approved by user` in 01-03-SUMMARY.md).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| BUG-01 | 01-01-PLAN.md | RayCast2D not in tree when queried; hardcoded damage | SATISFIED | `ship.gd:body_entered` fully rewritten with correct tree-based query and speed-scaled damage |
| BUG-02 | 01-01-PLAN.md | Reload signal stacks on every `reload()` call | SATISFIED | `CONNECT_ONE_SHOT` + `is_reloading()` guard both present in `mountable-weapon.gd` |
| BUG-03 | 01-02-PLAN.md, 01-03-PLAN.md | `get_tree().current_scene` fragile references in 6 components | SATISFIED | Zero references remain anywhere in the codebase; spawn_parent pattern fully implemented across all affected components |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `world.gd` | 165-166 | `add_child(asteroid)` before `setup_spawn_parent(asteroid)` | Info | `_ready()` of asteroid runs before `spawn_parent` is set. Safe because asteroids do not use `spawn_parent` in `_ready()` — only on death. Not a defect. |
| `components/ship.gd` | 42 | `var contact_point = ray.get_collision_point()` — variable assigned but never used | Info | Intentional per plan decision: retained for Phase 2 hit effects. Not a defect. |

No blockers or warnings found.

### Human Verification Required

#### 1. Full Gameplay Smoke Test

**Test:** Run the game (F5 in Godot editor). Perform all four scenarios:
- (a) Fire weapons (Space or Q/W/E) — bullets must appear in world, no crash
- (b) Destroy an asteroid — successor fragments and explosion debris must spawn
- (c) Pick up a coin — no crash; pick sound plays briefly after pickup
- (d) Unmount a weapon (A/S/D keys) — weapon must fly away into world, no crash
- (e) Check Output panel — no "spawn_parent not set on" warnings

**Expected:** All four scenarios complete without errors. No push_warning messages in Output.

**Why human:** Godot engine must be running. The Plan 03 checkpoint was approved by the user during execution — this item is included to formally record that human sign-off is part of the acceptance gate. If the user's prior checkpoint approval is accepted, this item is already satisfied.

### Gaps Summary

No code-level gaps found. All three roadmap success criteria are satisfied by verifiable code changes. The only open item is human re-confirmation of the gameplay smoke test, which was already performed at the Plan 03 checkpoint.

---

_Verified: 2026-04-07T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
