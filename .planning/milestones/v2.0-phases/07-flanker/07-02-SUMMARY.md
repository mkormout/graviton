---
phase: 07-flanker
plan: "02"
subsystem: enemy-ai
tags: [flanker, scene, wave-manager, playtest, checkpoint-approved]
dependency_graph:
  requires: [components/flanker.gd, prefabs/enemies/base-enemy-ship.tscn, world.gd]
  provides: [prefabs/enemies/flanker/flanker.tscn, world.gd (flanker wave)]
  affects: [phase-07 complete]
tech_stack:
  added: []
  patterns: [inherited-scene, wave-manager-integration, checkpoint-human-verify]
key_files:
  created:
    - prefabs/enemies/flanker/flanker.tscn
  modified:
    - world.gd
    - components/flanker.gd
decisions:
  - "linear_damp=0.0 set explicitly to prevent orbital spiral decay (RESEARCH.md Pitfall 1); Godot editor later removed it as it matches the RigidBody2D default — behavior unchanged"
  - "LURKING redesigned post-plan: replaced P-controller orbit with random radial drift (changes every 2–4.5s, biased inward) — orbit_radius and orbit_correction_strength removed"
  - "FIGHTING redesigned: timer-based burst (fight_duration=2.5s) + 5s cooldown instead of distance-based return_range exit"
  - "Smooth aim-then-fire: lerp_angle toward player, fire only after angle_difference < 0.15 rad"
  - "Velocity-based facing (rotation = linear_velocity.angle()) applied outside FIGHTING; FIGHTING uses lerp_angle instead"
  - "_turn_speed base raised 3.0 → 5.0 (range 4.0–6.0 rad/s) after playtest — snappier aim feel"
  - "Per-instance randomization: _lurk_speed, _drift_scale, _turn_speed each ±20%; bullet_speed raised 5500→6050 (+10%)"
metrics:
  duration_seconds: 600
  completed_date: "2026-04-13"
  tasks_completed: 3
  tasks_total: 3
  files_created: 1
  files_modified: 2
---

# Phase 07 Plan 02: Flanker Scene + World Integration Summary

**One-liner:** Flanker scene wired into WaveManager, behavior tuned through playtest to free-drift orbit with smooth aim-then-fire attack burst.

## What Was Built

### Task 1: prefabs/enemies/flanker/flanker.tscn

Flanker inherited scene normalized by Godot editor with correct UIDs. Key config:
- `FireTimer.wait_time = 0.25` — rapid fire
- `CoinDropper` (2 copper coins, chance=1.0) + `AmmoDropper` (50% minigun ammo)
- `max_speed=2000`, `thrust=1500`, `detection_radius=10000`
- No picker Area2D (ENM-15)

### Task 2: world.gd

`flanker_model` preload added, Flanker wave (count=3) inserted after Sniper wave. Press F three times to spawn for playtest.

### Task 3: Playtest + Behavior Redesign (checkpoint approved)

Playtest revealed the original P-controller orbit was too rigid — `orbit_radius=7000` never naturally reached `fight_range=4500`. Multiple behavior iterations applied:

1. **Free drift orbit** — replaced P-controller with random radial perturbation (±20% scaled per instance). Flanker naturally wanders in/out, drifting into fight range organically.
2. **Timer-based FIGHTING** — 2.5s burst + 5s cooldown replaces distance-based return.
3. **Smooth aim-then-fire** — `lerp_angle` pivot at 5.0 rad/s base; fire starts only after alignment (< 0.15 rad error).
4. **Velocity-based facing** outside FIGHTING — ship visually tracks direction of travel during orbit.
5. **Per-instance variation** — `_lurk_speed`, `_drift_scale`, `_turn_speed` each ±20%; `bullet_speed` +10%.

## Deviations from Plan

- Original `orbit_radius`, `return_range`, `orbit_correction_strength` exports removed — replaced by `max_follow_distance`, `fight_duration` and the drift system.
- Behavior redesigned iteratively during playtest checkpoint rather than matching plan spec exactly.

## Threat Mitigations Applied

- **T-07-04**: FireTimer `autostart=false` + state guard in `_on_fire_timer_timeout` — active only during FIGHTING.
- **T-07-06**: `collision_mask=3` prevents Flanker from interacting with items/coins. No picker Area2D.

## Self-Check: PASSED

- `prefabs/enemies/flanker/flanker.tscn` — FOUND
- `world.gd` contains `flanker_model` — FOUND
- Playtest checkpoint — APPROVED by user
- All behavior iterations committed atomically
