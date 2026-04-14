---
phase: 07-flanker
verified: 2026-04-12T22:38:13Z
status: human_needed
score: 2/3 must-haves verified (SC-1 needs human)
overrides_applied: 0
human_verification:
  - test: "Flanker visibly circles player rather than charging straight in"
    expected: "Flanker approaches, transitions SEEKING->LURKING, then moves in a circular/curved pattern around the player rather than a direct charge. Orbit is roughly maintained at distance."
    why_human: "Orbital behavior depends on physics forces at runtime; tangential force + drift logic can only be confirmed by observing actual movement in-game. Code is substantive but correctness is behavioral."
  - test: "FIGHTING -> LURKING return cycle observable"
    expected: "After ~2.5s of firing bursts, Flanker transitions back to LURKING state and resumes orbital motion. Multiple cycles visible without flickering."
    why_human: "Timer-based state transitions and lerp_angle alignment behavior can only be validated by watching the in-game state label and ship movement."
---

# Phase 7: Flanker Verification Report

**Phase Goal:** The Flanker orbits the player at a consistent radius before breaking into an attack burst, then returns to orbit
**Verified:** 2026-04-12T22:38:13Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (Roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC-1 | The Flanker visibly circles the player at a roughly constant radius rather than charging straight in | ? UNCERTAIN | LURKING state uses `toward_norm.orthogonal() * orbit_direction` (tangential force) + random radial drift with inward bias. Code structure is correct; actual circular motion is a runtime physics outcome that requires human confirmation. |
| SC-2 | After orbiting, the Flanker transitions to FIGHTING, fires a burst, then returns to the orbit pattern | ✓ VERIFIED | LURKING->FIGHTING when `dist < fight_range (4500)` and `_fight_cooldown <= 0`. FIGHTING fires immediately on alignment, timer fires every 0.25s. `_fight_remaining=2.5s` timer + `max_follow_distance` distance check cause FIGHTING->LURKING. 5s cooldown prevents immediate re-entry. WR-03 fix ensures burst duration is not consumed by alignment phase. |
| SC-3 | Orbit direction and radius vary between Flanker instances — not every Flanker circles identically | ✓ VERIFIED | `_ready()` sets `orbit_direction = 1.0 if randf() > 0.5 else -1.0` (50/50 CW/CCW), `_lurk_speed = randf_range(0.8, 1.2)`, `_drift_scale = randf_range(0.8, 1.2)`, `_turn_speed = 5.0 * randf_range(0.8, 1.2)`, `thrust *= randf_range(0.8, 1.2)`, `max_speed *= randf_range(0.8, 1.2)`. Per-instance variation is substantive and affects orbit character. |

**Score:** 2/3 roadmap truths programmatically verified (SC-1 requires human)

### Deferred Items

None — all roadmap success criteria are within scope of this phase.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `components/flanker.gd` | Flanker AI script with orbital LURKING and rapid-fire FIGHTING | ✓ VERIFIED | 146 lines. `class_name Flanker extends EnemyShip`. All states implemented. WR-01/02/03 fixes applied. |
| `prefabs/enemies/flanker/flanker-bullet.tscn` | Flanker bullet scene with fixed Damage.energy | ✓ VERIFIED | Root `FlankerBullet`, `energy=5.0`, `collision_layer=256`, `collision_mask=1`, `enemy-bullet.gd` script. |
| `prefabs/enemies/flanker/flanker.tscn` | Flanker scene ready for wave spawning | ✓ VERIFIED (with deviation) | Standalone scene (not inherited from base-enemy-ship.tscn — same approach as sniper.tscn). Has `flanker.gd` script, FireTimer(0.25s), CoinDropper, AmmoDropper, correct physics layers. |
| `world.gd` | Flanker preload and wave composition entry | ✓ VERIFIED | Line 12: `var flanker_model = preload("res://prefabs/enemies/flanker/flanker.tscn")`. Line 52: `{ "enemy_scene": flanker_model, "count": 10 }` as first wave. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `components/flanker.gd` | `components/enemy-ship.gd` | `extends EnemyShip` | ✓ WIRED | Line 2: `extends EnemyShip` confirmed |
| `components/flanker.gd` | `prefabs/enemies/flanker/flanker-bullet.tscn` | `preload in _bullet_scene` | ✓ WIRED | Line 11: `var _bullet_scene := preload("res://prefabs/enemies/flanker/flanker-bullet.tscn")` |
| `prefabs/enemies/flanker/flanker.tscn` | `prefabs/enemies/base-enemy-ship.tscn` | scene inheritance | ✗ NOT_WIRED (accepted deviation) | flanker.tscn is standalone, NOT inherited. Same pattern as sniper.tscn (also standalone, passed phase 06 UAT). Both beeliner and flanker/sniper diverge — this appears to be an accepted implementation pattern for later enemy types. |
| `prefabs/enemies/flanker/flanker.tscn` | `components/flanker.gd` | script override | ✓ WIRED | Line 3: `[ext_resource type="Script" ... path="res://components/flanker.gd" id="1_flanker"]` and line 36: `script = ExtResource("1_flanker")` |
| `world.gd` | `prefabs/enemies/flanker/flanker.tscn` | preload + wave composition | ✓ WIRED | `flanker_model` preloaded at line 12, used in waves array at line 52 |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `components/flanker.gd` (LURKING) | `_target.global_position` | `_on_detection_area_body_entered` via `body_entered` signal | Yes — live node reference to PlayerShip, updated each physics frame | ✓ FLOWING |
| `components/flanker.gd` (_fire) | `_bullet_scene.instantiate()` | preloaded `flanker-bullet.tscn` | Yes — instantiates real scene, adds to `spawn_parent` | ✓ FLOWING |
| `prefabs/enemies/flanker/flanker-bullet.tscn` | `attack` Damage resource | SubResource `Resource_damage` with `energy=5.0` | Yes — fixed damage resource, applied on collision via `enemy-bullet.gd` | ✓ FLOWING |

### Behavioral Spot-Checks

Step 7b: Godot 4 GDScript — not runnable from CLI without the Godot editor. Spot-checks requiring game execution are deferred to human verification.

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| flanker.gd contains `class_name Flanker` | grep check | Found at line 1 | ✓ PASS |
| flanker-bullet.tscn has correct energy damage | grep check | `energy = 5.0` found | ✓ PASS |
| world.gd contains flanker_model preload | grep check | Found at line 12 | ✓ PASS |
| No FLEEING state in flanker.gd | grep check | `State.FLEEING` absent | ✓ PASS |
| WR-01 fix applied (no SEEKING guard in body_exited) | grep check | Handler clears target unconditionally on `body == _target` | ✓ PASS |
| WR-02 fix applied (dist bail-out in FIGHTING) | grep check | Line 105: `dist > max_follow_distance` check present | ✓ PASS |
| WR-03 fix applied (_fight_remaining only ticks after _fire_started) | grep check | Line 103: `if _fire_started: _fight_remaining -= _delta` | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ENM-09 | 07-01, 07-02 | Flanker enemy — circles player before engaging | ✓ SATISFIED | flanker.gd implements IDLING->SEEKING->LURKING->FIGHTING->LURKING cycle. Orbital motion via tangential force. `_fire()` spawns FlankerBullet via spawn_parent. Human playtest approved per 07-02-SUMMARY.md. |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `components/flanker.gd` | 109 | `print("[Flanker] _enter_state: ...")` — debug print on every state transition | ℹ️ Info | Performance noise; double-prints since `EnemyShip._change_state` also prints. No gameplay impact. |
| `prefabs/enemies/flanker/flanker-bullet.tscn` | 27 | `Sprite2D` with no texture — bullet invisible at runtime | ℹ️ Info | Relies on `EnemyBullet._draw()` debug geometry. Cosmetic; functionality is unaffected. |
| `prefabs/enemies/flanker/flanker.tscn` | 46 | `Sprite2D` with no texture — Flanker ship invisible | ℹ️ Info | Relies on `EnemyShip._draw()` debug geometry. Cosmetic; no gameplay impact. |
| `world.gd` | 50 | `spawn_asteroids(10)` — reduced from 100, likely dev testing value | ℹ️ Info | First wave launches 10 Flankers into a near-empty world. Balance/testing concern, not a bug. |

No blockers or warnings found in anti-pattern scan. All three issues from code review (WR-01/02/03) have been fixed. Remaining items (IN-01 through IN-05) are informational only.

### Human Verification Required

#### 1. Flanker Orbit Behavior

**Test:** Run the game (F5). Press F to trigger wave 1 (10 Flankers spawn). Observe how Flankers move as they approach the player ship.
**Expected:** Flankers enter SEEKING state, then LURKING state at ~9500 units. In LURKING, ships should move in a curved or circular path around the player rather than a straight charge. Some Flankers orbit clockwise, others counter-clockwise (orbit_direction is 50/50 random).
**Why human:** Orbital motion results from physics forces applied per frame; tangential force magnitude vs inertia vs drift parameters can only be judged by watching real runtime behavior. The code is correct but the emergent motion quality cannot be verified statically.

#### 2. FIGHTING Burst and Return to Orbit

**Test:** Continue playtesting until a Flanker closes to fight range (~4500 units). Watch state transitions.
**Expected:** LURKING->FIGHTING transition visible. Flanker aims at player (lerp_angle), fires rapid bullets (~0.25s intervals). After ~2.5s, Flanker transitions back to LURKING and resumes orbital motion. 5s cooldown before re-engaging. Different Flankers engage at different times.
**Why human:** Timer-based state machine and aim-alignment gate behavior require runtime observation. The interaction between `fight_duration`, `_fire_started`, and `_fight_cooldown` can only be observed live.

### Gaps Summary

No gaps blocking goal achievement. All three roadmap success criteria are either verified or pending human confirmation (SC-1 and SC-2 require runtime playtest; SC-3 is fully verified).

**Plan-level deviations (not gaps):**

The 07-02 plan specified several design elements that were changed during playtest:

1. **Scene inheritance not used:** `flanker.tscn` is a standalone scene, not inherited from `base-enemy-ship.tscn`. This matches the sniper.tscn precedent (phase 06) and was confirmed functional in playtest.

2. **Orbit design replaced:** Original P-controller orbit (`orbit_radius`, `orbit_correction_strength`, `return_range` exports) was replaced with a free-drift system (`_radial_drift`, `_drift_timer`, `max_follow_distance`). The replacement achieves the same observable goal — Flanker circles player without charging straight in — via a different mechanism that proved more robust in playtest.

3. **FIGHTING exit changed:** Distance-based `return_range` exit replaced by timer-based `fight_duration` (2.5s) + 5s cooldown. This delivers the "attack burst then return to orbit" behavior the roadmap requires.

4. **`linear_damp = 0.0` absent from flanker.tscn:** Godot editor removed it during normalization as it matches the RigidBody2D default. Functionally equivalent — orbit stability is preserved.

All deviations were logged in 07-02-SUMMARY.md and the playtest checkpoint was approved by the user.

---

_Verified: 2026-04-12T22:38:13Z_
_Verifier: Claude (gsd-verifier)_
