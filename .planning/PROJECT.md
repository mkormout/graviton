# Graviton

## What This Is

A 2D space shooter built in Godot 4.6.2, featuring a component-based ship architecture with hot-swappable weapon mounts, an inventory system, procedurally scattered asteroids, and wave-based enemy ships with state-machine-driven AI. The player pilots a ship, equips weapons from inventory, and battles five distinct enemy types that spawn in configurable waves.

## Core Value

The mount-and-weapon system must work reliably — ships can equip, fire, and swap weapons without bugs or silent failures.

## Requirements

### Validated

- ✓ Player ship is controllable and movable — existing
- ✓ Weapons can be mounted/unmounted at runtime — existing
- ✓ Multiple weapon types (minigun, laser, gausscannon, RPG, gravitygun) — existing
- ✓ Inventory system with drag-and-drop UI — existing
- ✓ Asteroids spawn and collide with ships — existing
- ✓ Item drops (coins, ammo, weapons, health) — existing
- ✓ Ammo tracking and reload system — existing
- ✓ Collision damage fires correctly with accurate contact position — v1.0 (BUG-01)
- ✓ Reload signal does not stack duplicate connections — v1.0 (BUG-02)
- ✓ Spawn parents use stable node references instead of `get_tree().current_scene` — v1.0 (BUG-03)
- ✓ Action dispatch uses typed constants instead of raw strings — v1.0 (QUA-01)
- ✓ Mount lookup does not call `find_children()` every physics frame — v1.0 (QUA-02)
- ✓ Debug `print()` statements removed from hot paths — v1.0 (QUA-03)
- ✓ Game runs correctly on Godot 4.6.2 — v1.0 (MIG-01, MIG-02, MIG-03)
- ✓ Abstract EnemyShip base class with virtual state-machine methods — v2.0 (ENM-01–ENM-06, ENM-15)
- ✓ State machine with 8 states; concrete enemies implement their relevant subset — v2.0
- ✓ Beeliner enemy — charges and fires at player — v2.0 (ENM-07)
- ✓ Sniper enemy — keeps distance, fires slow heavy shots, flees when approached — v2.0 (ENM-08)
- ✓ Flanker enemy — circles player before engaging — v2.0 (ENM-09)
- ✓ Swarmer enemy — weak alone, cluster attack with cohesion — v2.0 (ENM-10)
- ✓ Suicider enemy — charges and explodes on contact — v2.0 (ENM-11)
- ✓ Simplified enemy fire logic (independent of MountableWeapon/inventory) — v2.0
- ✓ Wave-based enemy spawning system with WaveManager — v2.0 (ENM-12, ENM-13, ENM-14)

### Active

*(None — v3.0 requirements to be defined in /gsd-new-milestone)*

### Out of Scope

- Multiplayer — not planned
- Procedural level generation — not planned
- Automated test suite (GUT) — user opted for manual playtesting
- Flocking / Boids behavior — deferred to v3.0 or later
- Predictive targeting for Sniper — deferred
- Pre-wave HUD announcement and audio sting — deferred
- Escort / Patrol state implementation — deferred
- NavigationAgent2D pathfinding — no nav mesh in open space; regression risk

## Context

Godot 4.6.2 project. ~2,073 LOC GDScript across components and prefabs.

Five enemy types implemented: Beeliner (charge + fire), Sniper (standoff + aim telegraph + flee), Flanker (orbital LURKING + attack burst), Swarmer (cluster cohesion + separation), Suicider (locked-vector torpedo + contact explosion). All share the EnemyShip base class with 8-state machine, dying guard, and force-based steering.

WaveManager (standalone World child) drives wave spawning via configurable wave arrays. Wave HUD and enemy radar UI added in Phase 8. Enemy bullet layer (Layer 9) prevents friendly fire. All enemies have Polygon2D visual identity (distinct shape + color per type).

`world.gd` remains a developer test harness — waves triggered manually with KEY_F. No menu, save system, or game loop yet.

## Constraints

- **Engine**: Godot 4.6.2 (GDScript) — no C# or other language targets
- **Enemy fire**: Simplified, not using MountableWeapon/inventory layer
- **Spawning**: Wave-based

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Enemy AI deferred to v2.0 | Approach not yet decided; not blocking stabilization | ✓ Good — clean foundation ready |
| Milestone order: fix → migrate → AI | Migration is easier on clean code; bugs should be fixed before upgrading | ✓ Good — paid off |
| speed / 10.0 kinetic damage formula | Gives 100 damage at 1000 px/s as playtesting baseline | ✓ Good — felt fair in v2.0 playtesting |
| CONNECT_ONE_SHOT for reload signal | Simpler than manual disconnect; idiomatic Godot 4 | ✓ Good |
| @export spawn_parent propagation | Stable scene reference; null guards + push_warning for safety | ✓ Good |
| MountableBody.Action enum | Parse-time typo detection vs. silent string mismatch | ✓ Good |
| Enemy fire simplified (no MountableWeapon) | Reduces coupling; easier to balance enemy difficulty independently | ✓ Good — each type tunes independently |
| Wave-based spawning | Classic arcade feel; predictable difficulty scaling | ✓ Good — WaveManager clean and extensible |
| No fire loop in EnemyShip base class | Concrete types implement fire independently | ✓ Good — Suicider has no fire, others vary freely |
| HitBox Area2D (mask=4) for bullet detection | Avoids modifying all bullet scenes | ✓ Good |
| tree_exiting signal for wave completion | Handles deferred queue_free correctly | ✓ Good — no missed deaths |
| Flat scene for enemy types (not true inheritance) | Avoids Godot .tscn inheritance complications | ✓ Good |
| ContactArea2D separate from DetectionArea in Suicider | Clean separation of target acquisition vs. contact detection | ✓ Good |
| Polygon2D visual identity per enemy type | Could not distinguish enemies visually at a glance during playtest | ✓ Good — added in Phase 9 playtest |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-14 after v2.0 milestone completion*
