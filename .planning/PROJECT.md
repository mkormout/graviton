# Graviton

## What This Is

A 2D space shooter built in Godot 4.6.2, featuring a component-based ship architecture with hot-swappable weapon mounts, an inventory system, procedurally scattered asteroids, and wave-based enemy ships with state-machine-driven AI. The player pilots a ship, equips weapons from inventory, and battles enemies and asteroids.

## Core Value

The mount-and-weapon system must work reliably — ships can equip, fire, and swap weapons without bugs or silent failures.

## Current Milestone: v2.0 Enemies

**Goal:** Implement a state-machine-driven enemy AI system with an abstract EnemyShip base class and five concrete enemy types that spawn in waves and fight the player.

**Target features:**
- Abstract EnemyShip with virtual state-machine methods
- 8-state machine (idling, seeking, lurking, fighting, fleeing, patrolling, evading, escorting) — each enemy type implements the subset that fits its behavior
- 5 enemy types: Beeliner, Flanker, Sniper, Swarmer, Suicider
- Simplified fire logic (no MountableWeapon/inventory layer)
- Wave-based spawning system
- All enemies integrate with existing Body/health/death/item-drop pipeline

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

### Active

- [ ] Abstract EnemyShip base class with virtual state-machine methods (v2.0)
- [ ] State machine with 8 states; concrete enemies implement their relevant subset (v2.0)
- [ ] Beeliner enemy — charges and fires at player (v2.0)
- [ ] Flanker enemy — circles player before engaging (v2.0)
- [ ] Sniper enemy — keeps distance, fires slow heavy shots, flees when approached (v2.0)
- [ ] Swarmer enemy — weak alone, designed for group behavior (v2.0)
- [ ] Suicider enemy — charges and explodes on contact (v2.0)
- [ ] Simplified enemy fire logic (independent of MountableWeapon/inventory) (v2.0)
- [ ] Wave-based enemy spawning system (v2.0)

### Out of Scope

- Multiplayer — not planned
- Procedural level generation — not planned
- Automated test suite (GUT) — user opted for manual playtesting
- Flocking / Boids behavior — deferred to v2.1 or v3.0

## Context

Godot 4.6.2 project (migrated from 4.2.1 in v1.0). The codebase uses a scene-tree component pattern: ships are `MountableBody` nodes with named `MountPoint` children; behavior comes from GDScript components rather than inheritance. `PlayerShip` and `EnemyShip` are intentionally thin subclasses — movement is handled by the `propeller-movement` component in the scene.

`world.gd` is currently a developer test harness with all input hardcoded (keys Q/W/E/1-6/etc.). This is the main scene and serves as the game entry point.

All v1.0 bugs are fixed. `EnemyShip` class exists at `components/enemy-ship.gd` as a stub — ready to be built out.

## Constraints

- **Engine**: Godot 4.6.2 (GDScript) — no C# or other language targets
- **Enemy fire**: Simplified, not using MountableWeapon/inventory layer
- **Spawning**: Wave-based

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Enemy AI deferred to v2.0 | Approach not yet decided; not blocking stabilization | ✓ Good — clean foundation ready |
| Milestone order: fix → migrate → AI | Migration is easier on clean code; bugs should be fixed before upgrading | ✓ Good — paid off |
| speed / 10.0 kinetic damage formula | Gives 100 damage at 1000 px/s as playtesting baseline | — Pending validation |
| CONNECT_ONE_SHOT for reload signal | Simpler than manual disconnect; idiomatic Godot 4 | ✓ Good |
| @export spawn_parent propagation | Stable scene reference; null guards + push_warning for safety | ✓ Good |
| MountableBody.Action enum | Parse-time typo detection vs. silent string mismatch | ✓ Good |
| Enemy fire simplified (no MountableWeapon) | Reduces coupling; easier to balance enemy difficulty independently | — Pending |
| Wave-based spawning | Classic arcade feel; predictable difficulty scaling | — Pending |

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
*Last updated: 2026-04-11 after v2.0 milestone start*
