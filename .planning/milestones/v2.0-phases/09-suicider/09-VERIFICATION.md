---
phase: 09-suicider
verified: 2026-04-13T12:00:00Z
status: human_needed
score: 7/8
overrides_applied: 0
human_verification:
  - test: "Contact detonation damages and launches player"
    expected: "Suicider reaching the player triggers explosion with visible particles/audio, player health decreases, player receives visible impulse/knockback"
    why_human: "Requires running the game in Godot editor. Cannot verify physics impulse or visual explosion output programmatically."
  - test: "Shot-to-death also explodes"
    expected: "Shooting a Suicider to 0 HP triggers suicider-explosion.tscn at its position with damage radius"
    why_human: "Requires running the game. Body.die() instantiation of death scene is engine-driven at runtime."
  - test: "No double-trigger per Suicider death"
    expected: "Exactly one explosion per Suicider regardless of whether contact or bullet killed it"
    why_human: "Requires runtime observation — dying flag guard works in code but real-world signal timing (two simultaneous body_entered signals) must be confirmed in play."
  - test: "Locked-vector dodge window observable"
    expected: "Moving the player ship sideways after a Suicider locks on results in the Suicider flying past the original position, not tracking the new position"
    why_human: "Requires interactive play to confirm the AI does not live-track player position after lock."
---

# Phase 9: Suicider — Verification Report

**Phase Goal:** The Suicider charges the player and detonates on contact, dealing explosion-radius damage, and also explodes when shot to death
**Verified:** 2026-04-13T12:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Suicider script extends EnemyShip with IDLING and SEEKING states only | VERIFIED | `components/suicider.gd` line 2: `extends EnemyShip`. No `State.FIGHTING`, `State.FLEEING`, `State.LURKING` present. Only `State.SEEKING` branch in `_tick_state`. |
| 2 | Suicider locks target position on SEEKING entry — does not track live player position | VERIFIED | `_enter_state()` snapshots `_target.global_position` into `_locked_target_pos` once at SEEKING entry (line 37). `_tick_state` steers toward `_locked_target_pos`, never `_target.global_position` directly. |
| 3 | Suicider thrust ramps up as distance to locked target decreases | VERIFIED | Line 63: `var thrust_mult := clampf(1.0 + (1.0 - dist / detection_radius), 1.0, 2.0)` — multiplier increases as dist shrinks. |
| 4 | Suicider re-acquires target when it overshoots the locked position | VERIFIED | Line 56–61: overshoot check `linear_velocity.dot(to_locked) < 0.0` calls `_reacquire_target()` which re-snapshots player position. FAR_THRESHOLD=4000 brake prevents infinite drift. |
| 5 | Suicider die() override calls super() with no fire or drop logic | VERIFIED | Lines 69–72: `die()` checks `if dying: return` then `super(delay)`. No `_fire_timer`, no `_ammo_dropper`, no `drop()` call. |
| 6 | Explosion component can detect PlayerShip via hit_ships export | VERIFIED | `explosion.gd` line 14: `@export var hit_ships: bool = false`. Lines 41–42: `if hit_ships: area.set_collision_mask_value(1, true)` — backward-compatible; original `set_collision_mask_value(1, false)` at line 37 preserved. |
| 7 | Suicider explosion has high energy damage, strong knockback, large radius | VERIFIED | `suicider-explosion.tscn`: `radius=675.0`, `power=15000`, Damage sub-resource `energy=17500.0`, `kinetic=5000.0`, `hit_ships=true`. Values tuned up from original plan (450/10000/350/100) after playtest. |
| 8 | A Suicider that reaches the player triggers explosion — player takes area damage and impulse | HUMAN NEEDED | Code path is correct (ContactArea2D → die() → Body.die() spawns death scene), but actual damage+impulse delivery to player requires runtime confirmation. |

**Score:** 7/8 truths verified (1 requires human testing)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `components/suicider.gd` | Suicider enemy type script with `class_name Suicider` | VERIFIED | 73-line file, fully substantive, extends EnemyShip |
| `components/explosion.gd` | `hit_ships` export for ship-layer detection | VERIFIED | `@export var hit_ships: bool = false` at line 14; conditional mask at line 41–42 |
| `prefabs/enemies/suicider/suicider-explosion.tscn` | Suicider explosion scene referencing explosion.gd | VERIFIED | References `res://components/explosion.gd`; all node types present |
| `prefabs/enemies/suicider/suicider.tscn` | Suicider enemy scene referencing suicider.gd | VERIFIED | References `res://components/suicider.gd`; flat scene pattern |
| `world.gd` | WaveManager Suicider wave with `suicider_model` preload | VERIFIED | Line 14: `var suicider_model = preload(...)`. Line 62: first wave `{ "enemy_scene": suicider_model, "count": 3 }` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `components/suicider.gd` | `components/enemy-ship.gd` | `extends EnemyShip` | WIRED | Line 2 confirmed |
| `prefabs/enemies/suicider/suicider.tscn` | `components/suicider.gd` | script assignment | WIRED | `ExtResource("1_suicider")` → `path="res://components/suicider.gd"` |
| `prefabs/enemies/suicider/suicider.tscn` | `prefabs/enemies/suicider/suicider-explosion.tscn` | death export var | WIRED | `death = ExtResource("2_death")` → `path="res://prefabs/enemies/suicider/suicider-explosion.tscn"` |
| `world.gd` | `prefabs/enemies/suicider/suicider.tscn` | preload + WaveManager waves | WIRED | Line 14 preload; line 62 in waves array |

### Data-Flow Trace (Level 4)

Not applicable — suicider.gd is AI/physics logic, not a data-rendering component. No state variables render to UI.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| suicider.gd has no FIGHTING/FLEEING/LURKING states | `grep -c "State.FIGHTING\|State.FLEEING\|State.LURKING" components/suicider.gd` | 0 | PASS |
| suicider.gd uses locked position not live tracking | `grep "steer_toward.*_target.global_position" components/suicider.gd` | no match | PASS |
| suicider.gd has _reacquire_target (not _change_state re-lock) | `grep "_reacquire_target" components/suicider.gd` | found at lines 39, 57 | PASS |
| suicider.tscn has no Barrel/FireTimer/AmmoDropper/CoinDropper | `grep -c "Barrel\|FireTimer\|AmmoDropper\|CoinDropper" suicider.tscn` | 0 | PASS |
| suicider.tscn ContactArea collision_mask=1 | confirmed in tscn line 58 | `collision_mask = 1` | PASS |
| explosion.gd original mask=1 line preserved | line 37: `area.set_collision_mask_value(1, false)` intact | preserved | PASS |
| suicider-explosion.tscn has hit_ships=true | line 46 in tscn | `hit_ships = true` | PASS |

### Specific Checks Requested

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| suicider.gd: IDLING/SEEKING states only | No other states in tick | Only `State.SEEKING` branch; IDLING is default | PASS |
| suicider.gd: locked-vector torpedo mechanic | `_locked_target_pos` snapshot at SEEKING entry | `_enter_state()` sets `_locked_target_pos = _target.global_position` | PASS |
| suicider.gd: braking on far miss | FAR_THRESHOLD brake | `FAR_THRESHOLD = 4000.0`; brake applied when `distance_to(_target) > FAR_THRESHOLD` | PASS |
| suicider.tscn: ContactArea2D with mask=1 | `collision_mask = 1` on ContactArea | Confirmed | PASS |
| suicider.tscn: death=suicider-explosion.tscn | death export points to explosion scene | `death = ExtResource("2_death")` resolves to suicider-explosion.tscn | PASS |
| suicider.tscn: no Barrel/FireTimer/droppers | Absent | None found in scene | PASS |
| suicider-explosion.tscn: hit_ships=true | `hit_ships = true` | Confirmed at line 46 | PASS |
| suicider-explosion.tscn: radius=675 | ~675 | `radius = 675.0` (tuned up from plan's 450 after playtest) | PASS |
| world.gd: preloads suicider_model | preload line present | Line 14: `var suicider_model = preload("res://prefabs/enemies/suicider/suicider.tscn")` | PASS |
| world.gd: suicider_model in WaveManager.waves | First wave entry | `{ "enemy_scene": suicider_model, "count": 3 }` at line 62 | PASS |
| explosion.gd: hit_ships export | `@export var hit_ships: bool = false` | Line 14 confirmed | PASS |
| All 5 enemy types have Polygon2D visual shapes | Polygon2D node in each .tscn | Beeliner: hexagon yellow; Flanker, Sniper, Swarmer confirmed via grep; Suicider: circle red (line 33–35 of suicider.tscn) | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ENM-11 | 09-01-PLAN, 09-02-PLAN | Suicider contact-detonating enemy | SATISFIED | suicider.gd + suicider.tscn + suicider-explosion.tscn all exist and are wired; playtest reported passed by executor |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None | — | No TODO/FIXME/placeholder/empty return found in created files | — | — |

Notable: `suicider-explosion.tscn` uses `radius=675.0` and `energy=17500.0`/`kinetic=5000.0` instead of the plan's original `radius=450`/`energy=350`/`kinetic=100`. This is documented in 09-02-SUMMARY.md as intentional playtest tuning, not a deviation — values were iterated through 8 commits. Not a stub or placeholder.

### Human Verification Required

#### 1. Contact detonation damages and launches player

**Test:** Run the game (F5 in Godot editor). Press F to trigger the first wave (3 Suiciders). Let one Suicider reach the player ship without firing.
**Expected:** Explosion particles + audio play at Suicider position. Player ship loses health. Player ship receives a visible impulse away from the explosion center.
**Why human:** Physics impulse delivery and damage application require the engine's Area2D overlap detection to fire at runtime. Cannot verify with static analysis.

#### 2. Shot-to-death also triggers explosion

**Test:** Fire at an approaching Suicider until its HP reaches 0. Observe what happens at the Suicider's position.
**Expected:** suicider-explosion.tscn spawns at the Suicider's world position. Explosion particles, audio, and light play. Player takes damage if within radius (~675 units).
**Why human:** Body.die() instantiates the death scene via engine call_deferred — runtime only.

#### 3. No double-trigger per Suicider death

**Test:** In any test, watch for duplicate explosions. Also try: shoot a Suicider while it's in contact range (so both bullet damage and ContactArea fire simultaneously).
**Expected:** Exactly one explosion per Suicider. No stacked damage.
**Why human:** The `dying` flag guard is correct in code, but concurrent signal timing in physics must be confirmed at runtime.

#### 4. Locked-vector dodge window is observable

**Test:** When a Suicider first detects the player (transitions from IDLING to SEEKING), immediately strafe sideways. Watch whether the Suicider tracks your new position or continues toward your original position.
**Expected:** Suicider continues toward the position you were at when it entered SEEKING. It should fly past if you move enough, then re-acquire.
**Why human:** AI state-machine behavior and position locking are interactive — cannot verify the player experience of the dodge window programmatically.

### Gaps Summary

No automated gaps found. All artifacts exist, are substantive, and are correctly wired. Explosion values deviate from original plan (radius 450→675, damage 350→17500) due to playtest tuning — this is the correct final state per 09-02-SUMMARY.md decisions.

The phase is blocked on human verification for runtime behavior confirmation (contact detonation physics, death explosion spawning, double-trigger guard, dodge window feel). These 4 items require playing the game.

---

_Verified: 2026-04-13T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
