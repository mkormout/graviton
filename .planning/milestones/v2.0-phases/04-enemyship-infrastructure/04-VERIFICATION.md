---
phase: 04-enemyship-infrastructure
verified: 2026-04-11T00:00:00Z
status: human_needed
score: 9/10 must-haves verified
overrides_applied: 0
human_verification:
  - test: "Run the game (F5) and confirm IDLING->SEEKING transition fires at startup — console shows '[EnemyShip] state: IDLING -> SEEKING'"
    expected: "Console output within first second of play; enemy visibly labeled SEEKING after player ship spawns within 800px"
    why_human: "Runtime behavior — state machine wiring cannot be fully traced from static grep; detection signal requires Godot physics to fire"
  - test: "Kill the enemy (shoot it) and confirm no state transition prints appear after the death explosion begins"
    expected: "No '[EnemyShip] state: ...' prints after the first explosion frame; no crash"
    why_human: "Timing of dying flag vs signal dispatch requires live execution"
  - test: "Fly player ship over a dropped item (coin or weapon drop from any asteroid) and confirm it is picked up"
    expected: "Item disappears; coin counter or inventory updates — confirms Ship._ready() picker null guard did not break PlayerShip"
    why_human: "Requires running game and observing UI state"
  - test: "Press T to spawn a second enemy further away (fly out first), verify it does NOT immediately transition; then fly toward it and confirm IDLING->SEEKING fires on approach"
    expected: "Enemy stays IDLING until player enters 800px radius, then transitions"
    why_human: "Requires player movement interaction in live game"
---

# Phase 4: EnemyShip Infrastructure Verification Report

**Phase Goal:** The EnemyShip base class is complete and safe — all five concrete types can be built on it without rework
**Verified:** 2026-04-11
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | EnemyShip declares a State enum with 8 values and a current_state variable | VERIFIED | `components/enemy-ship.gd` lines 4-13: enum State with IDLING, SEEKING, LURKING, FIGHTING, FLEEING, PATROLLING, EVADING, ESCORTING; line 19: `var current_state: State = State.IDLING` |
| 2 | State transitions go through _change_state which calls _exit_state, updates current_state, then calls _enter_state | VERIFIED | `enemy-ship.gd` lines 51-59: `_exit_state(old_state)` called, `current_state = new_state`, `_enter_state(new_state)` called in order |
| 3 | All state ticking and fire-related logic is guarded by `if dying: return` | VERIFIED | Three dying guards found: line 35 (_physics_process before _tick_state), line 81 (_on_hitbox_body_entered), line 87 (_on_detection_area_body_entered) |
| 4 | Enemy movement uses apply_central_force with max speed clamped in _integrate_forces | VERIFIED | `steer_toward()` lines 61-63 uses `apply_central_force(direction * thrust)`; `_integrate_forces()` lines 39-40 uses `state.linear_velocity.limit_length(max_speed)`. Only linear_velocity write is inside _integrate_forces — no direct assignment elsewhere |
| 5 | Detection area body_entered drives IDLING to SEEKING transition | VERIFIED | `_on_detection_area_body_entered` lines 86-90: `if body is PlayerShip and current_state == State.IDLING: _change_state(State.SEEKING)` |
| 6 | Ship._ready() does not crash when picker is null | VERIFIED | `components/ship.gd` lines 18-19: `if picker: picker.body_entered.connect(picker_body_entered)` — null guard present |
| 7 | A placed EnemyShip scene detects the player and transitions from IDLING to SEEKING (runtime) | human_needed | Script wiring verified; runtime detection requires Godot physics (see Human Verification Required) |
| 8 | The console prints a state transition log when detection fires | VERIFIED | `_change_state()` line 58: `print("[EnemyShip] state: %s -> %s" % [State.keys()[old_state], State.keys()[new_state]])` |
| 9 | The EnemyShip scene has no picker Area2D node | VERIFIED | `prefabs/enemies/base-enemy-ship.tscn`: grep for "Picker" returns 0 matches |
| 10 | The base scene contains CollisionShape2D, Sprite2D, DetectionArea, Barrel, and ItemDropper nodes | VERIFIED | Scene file lines 21-47 contain all five required nodes; additionally HitBox Area2D was added for bullet damage |

**Score:** 9/10 truths verified (1 requires human runtime confirmation)

### Roadmap Success Criteria

| # | Success Criterion | Status | Evidence |
|---|-------------------|--------|----------|
| SC1 | EnemyShip scene detects player entering detection radius, transitions out of IDLING | human_needed | Static wiring confirmed; runtime behavior requires human |
| SC2 | Dying guard blocks state transitions and AI ticking on enemy death | VERIFIED (static) | `if dying: return` in _physics_process (line 35) and _on_detection_area_body_entered (line 87) |
| SC3 | `_fire()`-pattern convention documented and barrel Node2D in skeleton scene | VERIFIED | Fire convention comment block lines 92-96; Barrel node at position (40,0) in scene line 44 |
| SC4 | Enemy movement clamps to max speed — no direct linear_velocity assignments in any enemy script | VERIFIED | Only write is `state.linear_velocity = state.linear_velocity.limit_length(max_speed)` inside `_integrate_forces` — the sanctioned Godot 4 RigidBody2D pattern |
| SC5 | Enemy scenes have no picker Area2D node | VERIFIED | 0 occurrences of "Picker" in `base-enemy-ship.tscn` |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `components/enemy-ship.gd` | EnemyShip base class with state machine, steering, detection | VERIFIED | 97 lines; substantive implementation with 8-state enum, 3 virtual methods, _change_state helper, steer_toward, _integrate_forces, detection handler, HitBox handler, debug _draw, fire convention comment |
| `components/ship.gd` | Null guard on picker connection | VERIFIED | Line 18: `if picker:` wraps the `picker.body_entered.connect` call |
| `prefabs/enemies/base-enemy-ship.tscn` | Skeleton scene for EnemyShip base | VERIFIED | 49 lines; references enemy-ship.gd script; contains all required nodes; no Picker/MountPoint/Inventory |
| `world.gd` | Test enemy instance for Phase 4 verification | VERIFIED | Line 9: `var enemy_model = preload("res://prefabs/enemies/base-enemy-ship.tscn")`; lines 146-151: `spawn_test_enemy()`; line 47: called in _ready(); line 133-134: KEY_T handler |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `components/enemy-ship.gd` | `components/ship.gd` | `extends Ship` | VERIFIED | Line 2 of enemy-ship.gd: `extends Ship` |
| `components/enemy-ship.gd` | `components/body.gd` | `dying` flag inheritance | VERIFIED | `dying` used on lines 35, 81, 87 — inherited from Body via Ship chain |
| `prefabs/enemies/base-enemy-ship.tscn` | `components/enemy-ship.gd` | script attachment on root node | VERIFIED | Scene line 3: `ExtResource type="Script" path="res://components/enemy-ship.gd"`; line 19: `script = ExtResource("1_enemyship")` |
| `world.gd` | `prefabs/enemies/base-enemy-ship.tscn` | preload and instantiation | VERIFIED | Line 9: preload; `spawn_test_enemy()` calls `enemy_model.instantiate()` |
| `enemy-ship.gd` DetectionArea | `$DetectionArea` scene node | @onready binding | VERIFIED | enemy-ship.gd line 21: `@onready var detection_area: Area2D = $DetectionArea`; scene node named "DetectionArea" at line 26 of tscn |
| `enemy-ship.gd` HitBox | `$HitBox` scene node | @onready binding | VERIFIED | enemy-ship.gd line 22: `@onready var hitbox: Area2D = $HitBox`; scene node named "HitBox" at line 35 of tscn |

### Data-Flow Trace (Level 4)

Not applicable for this phase — no data-rendering components. EnemyShip produces behavioral state (not displayed data). Debug _draw() reads `current_state` which is set by `_change_state()` which is called from `_on_detection_area_body_entered()` — state display is live and non-hollow.

### Behavioral Spot-Checks

| Behavior | Check | Result | Status |
|----------|-------|--------|--------|
| enemy-ship.gd has no fire loop | `grep -c "Timer\|fire()\|bullet_scene" components/enemy-ship.gd` | 0 | PASS |
| scene has no picker node | `grep -c "Picker" prefabs/enemies/base-enemy-ship.tscn` | 0 | PASS |
| dying guard count | `grep -c "if dying" components/enemy-ship.gd` | 3 | PASS |
| linear_velocity only in _integrate_forces | only 1 write, inside _integrate_forces | confirmed | PASS |
| State enum value count | IDLING, SEEKING, LURKING, FIGHTING, FLEEING, PATROLLING, EVADING, ESCORTING | 8 values | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ENM-01 | 04-01 | State enum + virtual _tick/_enter/_exit methods | SATISFIED | enum State lines 4-13; _tick_state/enter_state/_exit_state lines 42-49 |
| ENM-02 | 04-01 | dying guard on all state ticks and fire calls | SATISFIED | `if dying: return` in _physics_process (line 35) and both signal handlers |
| ENM-03 | 04-01 | apply_central_force + _integrate_forces clamp, no direct linear_velocity write | SATISFIED | steer_toward lines 61-63; _integrate_forces lines 39-40; no other linear_velocity assignments |
| ENM-04 | 04-01 | Area2D with explicit layer/mask bits and inline comment | SATISFIED | _ready() lines 27-30 set layer/mask with physics layer comment |
| ENM-05 | 04-01 | Fire pattern convention (convention only — validated in Phase 5) | CONVENTION DOCUMENTED | Comment block lines 92-96; Barrel node in scene. Full validation deferred to Phase 5 per D-07 and ROADMAP SC3 |
| ENM-06 | 04-01 | Fixed energy Damage per enemy type (convention only in Phase 4) | CONVENTION DOCUMENTED | Fire convention comment references ENM-06; implementation deferred to Phase 5 per D-07 |
| ENM-15 | 04-01, 04-02 | No picker Area2D in enemy scenes | SATISFIED | 0 occurrences of "Picker" in base-enemy-ship.tscn |

Note: ENM-05 and ENM-06 are mapped to Phase 4 in REQUIREMENTS.md traceability but the ROADMAP SC3 explicitly states "validated in Phase 5." The context decisions D-06 and D-07 confirm Phase 4 establishes convention only. These items are correctly deferred.

### Deferred Items

Items not yet fully met but explicitly addressed in later milestone phases.

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | ENM-05: Actual fire loop implementation (Timer + bullet instantiation) | Phase 5 | ROADMAP SC3: "validated in Phase 5"; CONTEXT D-07: "ENM-05 is validated at Phase 5 (first concrete implementation)" |
| 2 | ENM-06: Fixed energy Damage resource per enemy type | Phase 5 | CONTEXT D-07: convention established in Phase 4, implementation in concrete enemy types |

### Anti-Patterns Found

| File | Lines | Pattern | Severity | Impact |
|------|-------|---------|----------|--------|
| `components/enemy-ship.gd` | 65-78 | `_draw()` debug visuals — circles, arrow, state label | INFO | Development scaffolding; not stub behavior. Summary notes removal before Phase 5. No gameplay impact. |
| `components/enemy-ship.gd` | 58 | `print()` in `_change_state` | INFO | Development debug per D-18. Visible in editor Output only. Not user-facing. |
| `world.gd` | 133-134 | KEY_T respawn shortcut | INFO | Development utility per Plan 02 Task 2. Will be replaced by WaveManager in Phase 5. |

No blockers found. No stubs. No empty implementations.

### Human Verification Required

The following items require running the game in the Godot editor to confirm. These were approved by the user during Plan 02 Task 3 (blocking gate), recorded in 04-02-SUMMARY.md. The automated verifier cannot confirm runtime behavior without re-running the game.

**1. IDLING to SEEKING detection transition**

**Test:** Run the game (F5). The test enemy spawns 600px to the right of the player ship — within the 800px detection radius. Check the Output panel.
**Expected:** Within the first second, console shows `[World] Test enemy spawned at (...)` followed by `[EnemyShip] state: IDLING -> SEEKING`. The state label drawn above the enemy should read "STATE: SEEKING".
**Why human:** Godot Area2D `body_entered` signal requires physics engine to be running; cannot be triggered by static file analysis.

**2. Dying guard blocks post-death transitions**

**Test:** Shoot the test enemy until it dies. Watch the Output panel during and after the death explosion.
**Expected:** No `[EnemyShip] state: ...` prints appear after the first explosion frame. No null reference errors in the Output panel. Game continues without crash.
**Why human:** Timing relationship between `dying = true`, signal dispatch, and `queue_free()` requires live execution to confirm.

**3. PlayerShip picker still functional (null guard regression)**

**Test:** Fly the player ship over a dropped item (any coin or ammo drop from an asteroid).
**Expected:** Item is picked up — coin counter increases or ammo inventory updates. Confirms `Ship._ready()` null guard (`if picker:`) did not break PlayerShip behavior.
**Why human:** Requires observing UI state changes during live gameplay.

**4. Detection radius boundary (distance-based trigger)**

**Test:** Press T to spawn a new enemy, then fly the player ship at least 900px away before pressing T again. The newly spawned enemy should stay IDLING. Then fly back toward it slowly.
**Expected:** No state transition until player enters the 800px radius, then `[EnemyShip] state: IDLING -> SEEKING` fires.
**Why human:** Requires player-controlled spatial movement to test boundary condition.

### Gaps Summary

No implementation gaps found. All artifacts exist, are substantive, and are wired. The only open items are four runtime verification checks that require running the game — all of which were previously confirmed by the user in the Plan 02 blocking gate (04-02-SUMMARY.md Task 3 "approved by user").

The phase goal "EnemyShip base class is complete and safe — all five concrete types can be built on it without rework" is satisfied by the static evidence. The human verification items are confirmation steps, not gap closure requirements.

---

_Verified: 2026-04-11_
_Verifier: Claude (gsd-verifier)_
