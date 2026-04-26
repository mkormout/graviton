---
phase: quick-260426-r2b
plan: 01
subsystem: wave-system
tags: [wave-manager, spawn, scheduling, godot]
requires: []
provides:
  - "WaveManager.SpawnGroup: spawn_at, stagger, position_mode (exact/random), distance, distance_min, distance_max, angle_mode (full/arc), angle_center, angle_width, cluster_radius, initial_state"
  - "Reset-safe in-flight spawn cancellation (per-enemy stagger awaits and group create_timer awaits both honor _wave_token)"
affects:
  - components/wave-manager.gd
  - world.gd
key-files:
  modified:
    - components/wave-manager.gd
    - world.gd
decisions:
  - "Use a stable sort by spawn_at on a duplicated groups array so legacy declaration order is preserved among equal-spawn_at groups (and the original waves Dictionary is not mutated)."
  - "Two helpers (_resolve_distance, _resolve_angle) plus the standalone _resolve_base_angle, all small — within the plan's three-helpers cap. Keeps _get_spawn_position itself a 4-line dispatcher."
  - "_change_state(EnemyShip.State[name]) confirmed canonical (enemy-ship.gd line 98); plan's claim verified, no deviation."
  - "spawn_batch_size frame-batching kept exactly as in commit 9dcf1fb; per-enemy stagger awaits ALSO reset spawned_in_frame because they cross frame boundaries anyway."
status: complete
metrics:
  tasks_completed: 3
  tasks_in_plan: 3
  duration_minutes: ~10
  completed_date: 2026-04-26
  human_checkpoint_approved: 2026-04-27
---

# Quick 260426-r2b: Per-group SpawnGroup options Summary

WaveManager gains six per-group axes (spawn_at / stagger / position_mode / angle_mode / cluster_radius / initial_state) with backward-compatible defaults, plus reset-safety for both group-scheduling timers and per-enemy stagger awaits; the perf-test wave now exercises all six on one wave with a regression-canary group.

## What Changed

### `components/wave-manager.gd`

- **Field-spec comment block** added above `@export var waves` documenting all SpawnGroup fields (existing + 6 new) with units, defaults, and the `initial_state` naming-rationale + per-type-implements-its-own-subset note.
- **`_get_spawn_position(group, base_angle)`** (signature change) becomes a 4-line dispatcher delegating to:
  - **`_resolve_distance(group)`** — branches on `position_mode`: `"random"` reads `distance_min`/`distance_max` (push_warning + legacy fallback if missing/invalid); `"exact"` honors explicit `distance` without jitter, otherwise legacy formula `5510 + spawn_radius_margin + randf_range(0, 500)`. Inline comment documents the "exact means exact, no jitter" decision.
  - **`_resolve_angle(group, base_angle, radius)`** — `cluster_radius > 0` ⇒ `base_angle ± randf_range(-cluster_radius/radius, +cluster_radius/radius)` (small-angle approximation). Else `angle_mode "arc"` ⇒ `randf_range(angle_center - angle_width/2, angle_center + angle_width/2)`. Else uniform on TAU.
- **`_resolve_base_angle(group)`** — resolves the per-group base angle ONCE per group's spawn pass (used when `cluster_radius > 0`; harmlessly resolved otherwise so the signature is uniform).
- **`trigger_wave()` rewrite**:
  - Captures `_wave_token` into local `my_token` at the top.
  - Sorts groups by `spawn_at` ascending (stable, on a duplicated array — original `groups` Dictionary unchanged).
  - Tracks `elapsed: float = 0.0`; before each group, awaits `create_timer(group.spawn_at - elapsed)` if the gap is > 0.001s, then bumps `elapsed`.
  - Resolves `base_angle` once per group via `_resolve_base_angle`.
  - Inner loop: per-enemy stagger via `create_timer(stagger / max(count - 1, 1))` between spawns when `stagger > 0`. The existing `spawn_batch_size` frame-batching from commit 9dcf1fb is preserved.
  - Token check after EVERY await (group create_timer, per-batch process_frame, per-enemy stagger create_timer) — mismatched token returns immediately.
- **`_spawn_enemy(group, base_angle)`** (signature change): after `add_child` + position assignment + `setup_spawn_parent`, reads `group.initial_state` (default `"IDLING"`); if non-default and valid, calls `enemy._change_state(EnemyShip.State[name])`; if non-default and unknown enum key, push_warning + leave in IDLING. The `state_name != "IDLING"` early-out preserves byte-identical behavior for legacy groups.
- **`_wave_token` private var** declared with one-line "incremented in trigger_wave AND reset; checked after every await" comment.
- **`reset()`** increments `_wave_token` so any in-flight `trigger_wave` coroutine cancels at its next await checkpoint.

### `world.gd`

The first wave dictionary (`Performance test 2`, waves[0]) is replaced with a 5-stage version. Total still 250 enemies (50 per group). All other waves (waves[1..20], starting `# Wave 1 — Suiciders`) are byte-identical.

| Stage | Time | Enemy | Count | Features exercised |
|------:|-----:|-------|------:|---|
| 0 | 0s | Beeliner | 50 | **NONE — regression canary** (full circle, default ring) |
| 1 | 4s | Flanker | 50 | `stagger: 2.0`, `position_mode: random` (4500..8500), `angle_mode: arc` (-PI/2 ± PI/6 = north 60°) |
| 2 | 6s | Swarmer | 50 | `position_mode: exact` (5000), `cluster_radius: 800` (≈ ±9° tight blob) |
| 3 | 8s | Sniper | 50 | `position_mode: exact` (8000), `angle_mode: arc` (0 ± PI/8 = east 45°), `initial_state: "FIGHTING"` |
| 4 | 12s | Suicider | 50 | `stagger: 4.0`, `position_mode: random` (4000..5500) |

Coverage matrix satisfied: spawn_at (5 distinct values), stagger (2 groups), position_mode random (2), position_mode exact w/ explicit distance (2), angle_mode arc (2), cluster_radius > 0 (1), initial_state non-default (1), all-defaults canary (1).

## Verification

- `godot --headless --check-only --quit components/wave-manager.gd` — no SCRIPT ERROR / Parse Error.
- `godot --headless --check-only --quit world.gd` — no SCRIPT ERROR / Parse Error.
- (Trailing `ERROR: 16 resources still in use at exit` is benign Godot 4.6.2 shutdown noise from autoload cleanup ordering — observed equally on the unmodified base commit; not a script issue.)

## Deviations from Plan

None. The plan's claim about `_change_state(EnemyShip.State[name])` was verified at `components/enemy-ship.gd:98` — used as-is.

## Commits

| Task | Commit | Message |
|---|---|---|
| 1 | `c26c778` | `feat(waves): per-group spawn_at, position_mode, stagger, angle, cluster, initial_state` |
| 2 | `5f3b3b8` | `feat(waves): restructure perf-test wave to exercise new SpawnGroup options` |

## Outstanding

- **Task 3 (human-verify)** NOT executed by this agent — user verifies in-game per the plan's checklist (regression canary at Stage 0, arc + layered drip at Stage 1, tight cluster at Stage 2, immediate engagement at Stage 3, late drip at Stage 4, plus Play-Again reset checks during both group-scheduling phase and stagger drip phase).

## Self-Check: PASSED

- [x] `components/wave-manager.gd` exists and contains `_wave_token`, `_resolve_distance`, `_resolve_angle`, `_resolve_base_angle`, `_get_spawn_position(group: Dictionary, base_angle: float)`, `_spawn_enemy(group: Dictionary, base_angle: float)`, `initial_state` handling.
- [x] `world.gd` `Performance test 2` entry has 5 staged groups covering all six axes.
- [x] Commit `c26c778` exists in `git log`.
- [x] Commit `5f3b3b8` exists in `git log`.
