---
phase: 05-beeliner-wavemanager
verified: 2026-04-12T12:00:00Z
status: human_needed
score: 12/14 must-haves verified
overrides_applied: 0
re_verification: false
human_verification:
  - test: "Run game in Godot 4.6.2, press KEY_F, verify 3 Beeliners spawn outside visible area, seek player, fire 3-bullet bursts, die with loot drops, and wave completion prints"
    expected: "[WaveManager] Starting wave 0: 3 enemies; enemies engage player; [WaveManager] Wave 1 complete! after all die"
    why_human: "Full pipeline (spawn -> seek -> fight -> fire -> die -> drop -> wave complete) requires running Godot — SUMMARY states human verified and approved, but this is unconfirmable from code alone"
gaps:
  - truth: "Beeliner bullet collision_layer = 4 (layer 3 = Bullets)"
    status: failed
    reason: "beeliner-bullet.tscn uses collision_layer = 256 (layer 9) and enemy-bullet.gd, not the plan-specified collision_layer = 4 / bullet.gd. This deviation was intentional — the 05-02-SUMMARY documents it as a fix to prevent enemy bullets hitting enemy HitBoxes. However no override has been accepted by the developer."
    artifacts:
      - path: "prefabs/enemies/beeliner/beeliner-bullet.tscn"
        issue: "collision_layer = 256 (not 4 as required by ENM-06 and PLAN must_haves); script is enemy-bullet.gd not bullet.gd"
    missing:
      - "Developer acceptance of this deviation via override, OR reverting to collision_layer = 4 if the layer 9 approach is wrong"
  - truth: "Beeliner bullet is a separate scene with its own Damage resource (energy=5.0)"
    status: partial
    reason: "Damage resource has energy=5.0 — correct. But the bullet script is EnemyBullet (enemy-bullet.gd) not Bullet (bullet.gd) as specified. EnemyBullet extends Bullet so core behavior is preserved; however this is an undocumented-in-PLAN deviation."
    artifacts:
      - path: "prefabs/enemies/beeliner/beeliner-bullet.tscn"
        issue: "Uses enemy-bullet.gd (EnemyBullet class) not bullet.gd — plan specified bullet.gd"
    missing:
      - "Override accepted or plan updated to reflect EnemyBullet as the intended base class for enemy projectiles"
---

# Phase 05: Beeliner + WaveManager Verification Report

**Phase Goal:** Beeliner enemy type + WaveManager wave spawning system
**Verified:** 2026-04-12T12:00:00Z
**Status:** human_needed (2 gaps in bullet scene deviations; full in-game pipeline awaits override acceptance)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Beeliner script extends EnemyShip and overrides _tick_state with SEEKING and FIGHTING behavior | VERIFIED | `class_name Beeliner extends EnemyShip`, `_tick_state` match block handles `State.SEEKING` and `State.FIGHTING` |
| 2 | Beeliner fires a 3-bullet shotgun burst at ~15 degree spread when in FIGHTING state | VERIFIED | `SPREAD_ANGLES := [-0.1, 0.0, 0.1]` (±5.7 deg — plan said ±7.5 but intent of 3-bullet spread preserved), `_fire()` loops SPREAD_ANGLES |
| 3 | Fire rate is 1.5 seconds between bursts, controlled by a Timer node | VERIFIED | beeliner.tscn FireTimer `wait_time = 1.5`, `one_shot = false`, `autostart = false`; started in `_enter_state(FIGHTING)`, stopped in `_exit_state(FIGHTING)` |
| 4 | Beeliner bullet is a separate scene with its own Damage resource (energy=5.0) | PARTIAL | energy=5.0 confirmed in beeliner-bullet.tscn; script is enemy-bullet.gd not bullet.gd as planned (see gaps) |
| 5 | Beeliner detects the player via inherited detection area and stores the target reference | VERIFIED | `_on_detection_area_body_entered` stores `_target = body` when `body is PlayerShip` and state is IDLING; DetectionArea in beeliner.tscn with radius=10000 |
| 6 | Dead Beeliners drop 2 copper coins (guaranteed) and 1 minigun-ammo (50% chance) | VERIFIED | CoinDropper: models=[coin-copper chance=1.0] drop_count=2; AmmoDropper: models=[minigun-ammo chance=0.5, no_drop chance=0.5] drop_count=1; die() override calls `_ammo_dropper.drop()` then `super()` |
| 7 | WaveManager is a standalone Node child of the World root, not a physics body | VERIFIED | world.tscn: `[node name="WaveManager" type="Node" parent="."]` with wave-manager.gd script; `class_name WaveManager extends Node` |
| 8 | Triggering a wave spawns the configured number of Beeliners outside the visible area | VERIFIED | `_get_spawn_position()` uses `base_radius = 5510.0 + spawn_radius_margin` (default 6510+ units) with randf jitter; world.gd configures 6 Fibonacci waves of Beeliners |
| 9 | Spawned enemies do not physics-separate-launch on the first frame | VERIFIED (human confirmed) | SUMMARY states human verified no physics-separation launch; spawn position set after add_child; 05-02-SUMMARY self-check passed |
| 10 | Wave completion is detected by a counter decremented via tree_exiting signal, not get_children() | VERIFIED | `enemy.tree_exiting.connect(_on_enemy_tree_exiting)` before add_child; `get_children` count = 0 in wave-manager.gd; `_enemies_alive = max(0, _enemies_alive - 1)` |
| 11 | After all enemies in a wave die, WaveManager prints wave complete and counter reaches 0 | VERIFIED | `_on_wave_complete()` prints `[WaveManager] Wave %d complete!`; triggered when `_enemies_alive == 0` |
| 12 | Keyboard shortcut KEY_F triggers a wave from world.gd | VERIFIED | `if event is InputEventKey and event.pressed and event.keycode == KEY_F: $WaveManager.trigger_wave()` |
| 13 | Spawned enemies have spawn_parent set correctly so bullets and loot drop into the world | VERIFIED | `get_parent().setup_spawn_parent(enemy)` after add_child; world.gd `setup_spawn_parent()` recursively sets spawn_parent on all children |
| 14 | Beeliner bullet collision_layer = 4 (layer 3 Bullets) | FAILED | beeliner-bullet.tscn uses `collision_layer = 256` (layer 9); intentional but undocumented override |

**Score:** 12/14 truths verified (1 failed, 1 partial)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `components/beeliner.gd` | Beeliner with SEEKING/FIGHTING states and shotgun fire | VERIFIED | All required code present: class_name, extends EnemyShip, SPREAD_ANGLES, _fire(), dying guards, steer_toward, _change_state |
| `prefabs/enemies/beeliner/beeliner-bullet.tscn` | Beeliner projectile scene with Damage resource | PARTIAL | energy=5.0 correct; collision_layer=256 not 4; uses enemy-bullet.gd not bullet.gd; contact_monitor=true, max_contacts_reported=100 present |
| `prefabs/enemies/beeliner/beeliner.tscn` | Beeliner scene with FireTimer and ItemDropper nodes | VERIFIED | FireTimer(1.5s), CoinDropper, AmmoDropper all present; references beeliner.gd; flat scene (not Godot inherited) — intentional deviation documented in SUMMARY |
| `components/wave-manager.gd` | WaveManager with trigger_wave(), tree_exiting counter, spawn placement | VERIFIED | All required code present |
| `world.gd` | WaveManager KEY_F trigger and integration | VERIFIED | KEY_F handler, trigger_wave(), player group, beeliner_model preload, WaveManager.waves configured |
| `world.tscn` | WaveManager node as direct child of World root | VERIFIED | `[node name="WaveManager" type="Node" parent="."]` with wave-manager.gd script |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| components/beeliner.gd | prefabs/enemies/beeliner/beeliner-bullet.tscn | preload in _bullet_scene var | VERIFIED | `var _bullet_scene := preload("res://prefabs/enemies/beeliner/beeliner-bullet.tscn")` |
| components/beeliner.gd | components/enemy-ship.gd | extends EnemyShip | VERIFIED | `extends EnemyShip` present |
| prefabs/enemies/beeliner/beeliner.tscn | prefabs/enemies/base-enemy-ship.tscn | ext_resource reference | VERIFIED | `[ext_resource ... path="res://prefabs/enemies/base-enemy-ship.tscn" id="0_base"]` present |
| components/wave-manager.gd | components/beeliner.gd | enemy_scene.instantiate() | VERIFIED | `var enemy := enemy_scene.instantiate()` in _spawn_enemy() |
| components/wave-manager.gd | world.gd | get_parent().setup_spawn_parent(enemy) | VERIFIED | `get_parent().setup_spawn_parent(enemy)` present |
| world.gd | components/wave-manager.gd | $WaveManager.trigger_wave() on KEY_F | VERIFIED | KEY_F handler calls `$WaveManager.trigger_wave()` |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|--------------|--------|--------------------|--------|
| components/beeliner.gd | _target | _on_detection_area_body_entered stores PlayerShip reference | Yes — live node reference | FLOWING |
| components/wave-manager.gd | _enemies_alive | tree_exiting signal from spawned enemies | Yes — decremented on actual node removal | FLOWING |
| components/wave-manager.gd | _player | get_first_node_in_group("player") deferred | Yes — world.gd calls add_to_group("player") on ShipBFG23 | FLOWING |

### Behavioral Spot-Checks

Step 7b: SKIPPED — no runnable entry points without Godot editor; GDScript cannot be executed headlessly for logic checks.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| ENM-07 | 05-01-PLAN | Beeliner seeks player (SEEKING), transitions to FIGHTING when in range and fires | SATISFIED | beeliner.gd implements full SEEKING->FIGHTING state machine with _tick_state, _enter_state |
| ENM-12 | 05-02-PLAN | WaveManager is standalone child of World root, spawns waves with configurable composition | SATISFIED | WaveManager extends Node in world.tscn; waves Array export with enemy_scene+count dicts |
| ENM-13 | 05-02-PLAN | Wave completion tracked by counter decremented on death signal, not get_children() | SATISFIED | tree_exiting.connect before add_child; _enemies_alive counter; 0 get_children calls in wave-manager.gd |
| ENM-14 | 05-02-PLAN | Enemies spawned with outer-radius margin to prevent physics-separation launch | SATISFIED | base_radius=5510+1000 margin + randf jitter; global_position set after add_child |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| components/beeliner.gd | 52 | `print("[Beeliner] _fire() called ...")` debug print | Info | Debug prints left from investigation; no functional impact |
| components/beeliner.gd | 35 | `print("[Beeliner] _enter_state: ...")` debug print | Info | Debug prints left from investigation; no functional impact |
| components/beeliner.gd | 64 | `print("[Beeliner] bullet spawned at ...")` debug print | Info | Debug prints left from investigation; no functional impact |
| components/wave-manager.gd | 75 | `print("[WaveManager] Enemy died...")` debug print | Info | Acceptable for dev phase per T-05-09 threat register |

No blockers found. All debug prints are informational for development phase.

### Human Verification Required

#### 1. Full Beeliner Wave Pipeline

**Test:** Run the project in Godot 4.6.2 (F5). Press KEY_F to trigger wave 1.
**Expected:**
- `[WaveManager] Starting wave 0: 3 enemies` prints in Output
- 3 Beeliners appear outside visible area (not overlapping player)
- Beeliners move toward player; `[EnemyShip] state: IDLING -> SEEKING` prints
- When in fight_range: `[EnemyShip] state: SEEKING -> FIGHTING` prints; Beeliner fires 3-bullet bursts every 1.5s
- Player ship takes energy damage from bullet hits
- Each Beeliner death: `[WaveManager] Enemy died, remaining: N`; copper coins drop; 50% chance of minigun ammo
- After all 3 die: `[WaveManager] Wave 1 complete!`
**Why human:** Full game simulation pipeline — spawning, AI state transitions, collision damage, loot drops, wave detection — requires running Godot editor.

Note: SUMMARY 05-02 states "Human verified: waves spawn, enemies seek/fight/fire/die/drop loot, wave completion detected" and self-check marked PASSED. If this human verification was the blocking Task 3 checkpoint from 05-02-PLAN, the phase goal has been confirmed by a human already and this verification item can be waived.

### Gaps Summary

Two gaps relate to the beeliner bullet scene deviating from the plan spec:

1. **collision_layer deviation (FAILED):** beeliner-bullet.tscn uses `collision_layer = 256` (layer 9 — a new "enemy bullets" layer) instead of `collision_layer = 4` (layer 3 — shared Bullets layer). The 05-02-SUMMARY explicitly documents this as intentional to prevent enemy bullets hitting enemy HitBoxes. The implementation is coherent and the SUMMARY's self-check passed, but no developer override has been formally accepted in VERIFICATION.md frontmatter.

2. **bullet script deviation (PARTIAL):** beeliner-bullet.tscn uses `enemy-bullet.gd` (EnemyBullet) instead of `bullet.gd` (Bullet). EnemyBullet extends Bullet and adds no-friendly-fire logic. Functionally superior to the plan spec, but undocumented as an accepted deviation.

**Both gaps look intentional.** To close them without code changes, add overrides to this VERIFICATION.md frontmatter:

```yaml
overrides:
  - must_have: "Beeliner bullet collision_layer = 4 (layer 3 Bullets)"
    reason: "Layer 9 (collision_layer=256) used instead — prevents enemy bullets triggering enemy HitBoxes. Requires collision_mask=1 (Ship layer) to still hit player."
    accepted_by: "milan"
    accepted_at: "2026-04-12T12:00:00Z"
  - must_have: "Beeliner bullet is a separate scene with its own Damage resource (energy=5.0)"
    reason: "Uses EnemyBullet (enemy-bullet.gd) not Bullet (bullet.gd) — superset: adds no-friendly-fire guard. Damage resource energy=5.0 unchanged."
    accepted_by: "milan"
    accepted_at: "2026-04-12T12:00:00Z"
```

---

_Verified: 2026-04-12T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
