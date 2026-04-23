---
quick_id: 260423-w6g
type: execute
wave: 1
status: complete
completed: "2026-04-23"
duration: "~7 minutes"
commits:
  - a786197  # Task 1: MountableWeapon
  - 8cda242  # Task 2: Enemies
  - 11c958e  # Task 3: SceneTreeTimer awaits
  - b76ad95  # Task 4: ScoreManager + world death pause
files-created: []
files-modified:
  - components/mountable-weapon.gd
  - prefabs/ui/weapon-hud.gd
  - prefabs/ui/weapon-debug-panel.gd
  - prefabs/minigun/minigun-weapon.gd
  - prefabs/gausscannon/gausscannon-weapon.gd
  - prefabs/laser/laser-weapon.gd
  - prefabs/rpg/rpg-weapon.gd
  - prefabs/gravitygun/gravitygun-script.gd
  - components/flanker.gd
  - components/beeliner.gd
  - components/swarmer.gd
  - components/sniper.gd
  - prefabs/enemies/flanker/flanker.tscn
  - prefabs/enemies/beeliner/beeliner.tscn
  - prefabs/enemies/swarmer/swarmer.tscn
  - prefabs/enemies/sniper/sniper.tscn
  - prefabs/laser/laser-bullet.gd
  - components/explosion.gd
  - components/body.gd
  - components/score-manager.gd
  - world.gd
---

# Quick Task 260423-w6g: Replace non-UI Timer nodes with float counters — Summary

Replaced every gameplay `Timer` node and `SceneTreeTimer` use (`Timer.new()`,
`get_tree().create_timer(...)`) across spawned entities (bullets, enemies,
weapons, explosions, bodies, ScoreManager, world) with either a float counter
ticked in `_physics_process(delta)` or a `physics_frame` yield loop. Timers
now exist ONLY in `prefabs/ui/` (and even there only `Label` node references
named `*_timer` remain, which are not Timer nodes).

## What Changed Per Task

### Task 1 — MountableWeapon base + consumers (commit `a786197`)

- `components/mountable-weapon.gd`: replaced the `reload_timer: Timer` and
  `shot_timer: Timer` nodes (created in `_ready` via `Timer.new()`) with
  three public float fields — `shot_time_left`, `shot_wait_time`,
  `reload_time_left` — ticked in a new `_physics_process(delta)`. `reloaded()`
  is now called directly from the tick loop when `reload_time_left` hits zero
  (no more `timeout.connect(reloaded, CONNECT_ONE_SHOT)`).
- Subclass firing sites converted (`shot_timer.start(rate)` →
  `shot_time_left = rate`): `minigun-weapon.gd` (also
  `shot_timer.wait_time = ...` → `shot_wait_time = ...`),
  `gausscannon-weapon.gd`, `laser-weapon.gd`, `rpg-weapon.gd`,
  `gravitygun-script.gd`.
- UI consumers renamed to the new public fields:
  - `prefabs/ui/weapon-hud.gd`: `weapon.reload_timer.time_left` →
    `weapon.reload_time_left`.
  - `prefabs/ui/weapon-debug-panel.gd`: `weapon.shot_timer.time_left` →
    `weapon.shot_time_left`; `weapon.reload_timer.time_left` →
    `weapon.reload_time_left`.

### Task 2 — Enemy FireTimer/AimTimer (commit `8cda242`)

- Removed `FireTimer` (and `AimTimer` for sniper) Timer child nodes from all
  four enemy scenes: `flanker.tscn`, `beeliner.tscn`, `swarmer.tscn`,
  `sniper.tscn`.
- Replaced the `@onready var _fire_timer: Timer = $FireTimer` + signal
  wiring in each enemy script with a `const _FIRE_INTERVAL: float = W` and
  `_fire_active`/`_fire_left` state, ticked in `_physics_process(delta)`
  using the `+= _FIRE_INTERVAL` drift-preserving pattern. Kept call sites
  1:1 via `_start_fire_timer()` / `_stop_fire_timer()` helpers so the
  existing `_enter_state` / `_exit_state` / `die()` wiring is a pure
  rename of method calls.
- Sniper uses the same pattern twice (FireTimer + AimTimer). The assert in
  `_enter_state(FIGHTING)` now checks `aim_up_time < _FIRE_INTERVAL`
  (instead of `_fire_timer.wait_time`).
- Flanker and Beeliner did not previously override `_physics_process`;
  added a `super(delta)`-preserving override. Swarmer already overrode
  `_physics_process`; the fire-tick block was appended after
  `_apply_cohesion()` but after the `if dying: return` guard so dying
  swarmers don't fire.

### Task 3 — SceneTreeTimer awaits on spawned entities (commit `11c958e`)

- `prefabs/laser/laser-bullet.gd`: replaced
  `get_tree().create_timer(life).timeout.connect(queue_free)` with a
  `_life_left: float` field ticked in the existing `_physics_process`.
  Bullet frees itself when lifetime elapses (before `move_and_collide`).
- `components/explosion.gd`:
  - `explode()`: swapped `await get_tree().create_timer(0.1).timeout` for
    two `await get_tree().physics_frame` yields. Enough frames for the
    deferred Area2D `add_child` to land and for one overlap scan; no
    SceneTreeTimer allocation per explosion.
  - `die(delay)`: replaced the `await get_tree().create_timer(delay).timeout`
    + `queue_free()` pattern with a new `_die_left: float = -1.0` counter.
    `die(delay)` just assigns `_die_left = delay`; `_physics_process`
    ticks it down and calls `queue_free()` when it reaches zero.
- `components/body.gd`: `die(delay)` now uses a `physics_frame` yield loop
  (`ceil(delay * Engine.physics_ticks_per_second)` iterations) instead of
  a SceneTreeTimer. Preserves the `await` contract — subclass
  overrides calling `super(delay)` (Flanker, Beeliner, Swarmer, Sniper)
  still behave identically.
- `prefabs/gravitygun/gravitygun-script.gd`: same `physics_frame` loop
  pattern for the 0.1s pause between `apply_damage()` and
  `apply_kickback()` inside `_fire_charged()` — 6 frames at 60 Hz
  (`round(0.1 * physics_ticks_per_second)`).

### Task 4 — ScoreManager combo Timer + world death pause (commit `b76ad95`)

- `components/score-manager.gd`: dropped the `_combo_timer: Timer` node
  (autoload Node was creating a child Timer in `_ready`). Replaced with
  `_combo_time_left: float = 0.0` ticked in a new `_physics_process(delta)`.
  On expiry, calls `_on_combo_expired()` directly (no signal connection).
  `_increment_combo()` sets `_combo_time_left = COMBO_TIMEOUT`; `reset()`
  clears it to `0.0`.
- `world.gd`: `_on_player_died()` replaced
  `await get_tree().create_timer(1.2).timeout` with a `physics_frame`
  yield loop (`round(1.2 * physics_ticks_per_second)` iterations). Death
  screen still appears ~1.2s after the player explosion.
- `world.gd`: only the `_on_player_died` hunk was staged — an unrelated
  pre-existing worktree change (a "Final Wave" entry in `_ready()`) was
  kept out of this commit via `git apply --cached` with a hunk-scoped
  patch, and remains as an unstaged modification in the working tree.

## Verification

- **Full-repo sweep:** `grep -rn 'get_tree().create_timer\|Timer.new()\|type="Timer"\|@onready .*Timer'`
  over `components/`, `prefabs/` (excluding `prefabs/ui/`), and `world.gd`
  returns ZERO live hits after Task 4. Only comment references remain
  (`# (Was: await get_tree().create_timer(0.1).timeout ...)` in
  `explosion.gd` and `gravitygun-script.gd`) documenting the replaced code.
- **Field declaration sweep:** `grep -rn ': Timer\b'` over the same scope
  returns ZERO hits.
- **Enemy scene sweep:** `grep -rn "Timer\|FireTimer\|AimTimer"` across the
  four enemy `.tscn` files returns ZERO hits.
- **Parse check:** `Godot --headless --path . --check-only --quit` completes
  with no script / parse errors. (Godot 4.6.2 used locally; project is
  Godot 4.2.1. Pre-existing UID warnings are unchanged.)

## Behaviors Preserved

- Weapon cooldowns and reload times (MountableWeapon + all 5 subclasses)
- Minigun spool-up rate acceleration via `shot_wait_time` mutation
- Weapon HUD reload bar fill and weapon debug panel cooldown/reload readouts
- Flanker 0.25s fire cadence (4 Hz volleys), Beeliner 1.5s, Swarmer 0.8s,
  Sniper 3s cycle with `aim_up_time` telegraph (two-stage FireTimer →
  AimTimer → fire)
- Enemy stop-on-state-exit and stop-on-die (no rogue bullet after death)
- Laser bullet self-destruct after `life` seconds
- Explosion delay-before-shockwave (enough frames for Area2D to land)
- Explosion despawn after `time` seconds
- Body `die(delay)` timing — subclasses calling `super(delay)` still
  `await`-compatible
- GravityGun charged-fire damage → 0.1s pause → kickback sequencing
- ScoreManager combo expiry at 5s idle; combo increments and audio on
  consecutive kills
- Death screen appears ~1.2s after player ship explosion

## Deviations from Plan

None substantive. One pragmatic adjustment:

- **Task 4, world.gd staging:** The plan listed `world.gd` as modified, but
  the worktree also contained a pre-existing unrelated change (an extra
  "Final Wave" entry in `_ready()`). I used `git apply --cached` with a
  hunk-scoped patch so only the `_on_player_died` death-pause change landed
  in commit `b76ad95`. The pre-existing change remains as an unstaged
  modification for the worktree owner to decide on separately.

## Performance Rationale

Each eliminated `Timer` is one SceneTree-registered object with its own
processing slot and signal plumbing. A float decremented in
`_physics_process` is ~free. At the project's target of 100+ simultaneous
bullets, many dozens of concurrent enemies, and multi-fragment explosions,
the cumulative win shows up most at wave-end and player-death moments —
exactly the frames that otherwise hitch.

## Self-Check: PASSED

- All four commits exist in `git log --oneline -5`:
  `a786197` `8cda242` `11c958e` `b76ad95` — FOUND.
- All 21 listed modified files exist and contain the described changes
  (verified via targeted `grep` sweeps per task).
- SUMMARY.md written to
  `.planning/quick/260423-w6g-find-all-timers-in-enemies-bullets-etc-a/260423-w6g-SUMMARY.md` —
  FOUND.
