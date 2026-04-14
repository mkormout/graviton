# Project Research Summary

**Project:** Graviton v2.0 Enemies
**Domain:** Wave-based enemy AI for a physics-driven 2D space shooter
**Researched:** 2026-04-11
**Confidence:** HIGH

## Executive Summary

Graviton's enemy system is a layered addition to an already-solid `Body → MountableBody → Ship` hierarchy. The entire codebase already provides the scaffolding enemies need — health/death pipeline, `spawn_parent` propagation, kinetic collision damage, bullet scenes, `Explosion`, and `ItemDropper`. The design work is: build a thin `EnemyShip` base class that adds a state machine and simplified fire, then build five concrete types on top of it. No external plugins, no nav meshes, no shared mutable state between enemies. All movement is via `apply_central_force` steering vectors — the same mechanics that already drive the player ship.

The recommended build order is infrastructure-first. Every hour spent getting `EnemyShip`'s base class right (dying guard, spawn_parent wiring, physics layer assignment, Timer-based fire) saves rework across all five types. The Beeliner is then built to validate the full pipeline end-to-end before any complexity is added. Each subsequent enemy type introduces exactly one new steering behavior — orbit (Flanker), flee (Sniper), proximity-slow (Swarmer) — so mistakes stay localized. The Suicider, despite being the simplest state machine, is built last so the `Explosion` integration path is clean.

The top risk is silent infrastructure failure: a detection `Area2D` with a wrong collision mask will silently keep every enemy in IDLING forever, a missing `dying` guard will fire bullets at enemy death, and a missing `spawn_parent` propagation will crash the bullet spawn path. All three failures are invisible during development unless tested against a real wave spawn, not just a placed scene. Validate against a wave spawn before building any second enemy type.

---

## Key Findings

### Recommended Stack

No new plugins or external dependencies are required. The entire enemy system is built with Godot built-ins. A node-based `StateMachine` + `State` pattern (GDQuest-validated) is preferred over per-enemy `match` blocks because 8 states × 5 types makes flat duplication unmaintainable. States are `Node` children; they access the owning `EnemyShip` via `owner`, not `get_parent()`. Movement uses `apply_central_force()` on `self` — replicating `PropellerMovement` without the `Input` dependency. Detection uses `Area2D` signals, not per-frame distance polling. Fire uses a `Timer` node child, same as `MountableWeapon.shot_timer`.

**Core technologies:**
- **Enum-based StateMachine in EnemyShip base class** — shared 8-state vocabulary; per-type scripts override virtual hooks only
- **`apply_central_force()` steering vectors** — seek, flee, arrive, orbit inline; no NavigationAgent2D (requires nav mesh bake, broken in 4.5, inapplicable to open-space world)
- **`Area2D` + `CircleShape2D` for detection** — signal-driven; collision mask explicitly set to layer 1 (Ships) in code
- **`Timer` node child for fire rate** — consistent with existing MountableWeapon pattern; freed with parent, no orphaned SceneTreeTimers
- **`WaveManager` node in world.tscn** — separate script from world.gd test harness; tracks alive enemies via `tree_exited` signal counter

**Explicitly rejected:**
- NavigationAgent2D — overkill for open-space; regression in 4.5 (issue #110686), no nav mesh applicable
- LimboAI plugin — C++ GDExtension, Godot 4.6.2 support unconfirmed
- MountableWeapon for enemy fire — carries inventory, reload, mount sync; none needed by AI
- Shared mutable state between enemies — group effects emerge from local rules only

### Expected Features

**Must have (table stakes) — all enemy types:**
- Detects player within configurable range
- Moves toward or away from player via steering forces
- Fires projectiles or deals contact damage
- Has health and dies via existing `Body` pipeline
- Drops loot via `ItemDropper` (configured per type)
- Visual state feedback (color modulate on aggro/damage)

**Per-type non-negotiable behaviors:**

| Enemy | Table stakes |
|-------|-------------|
| Beeliner | Charges directly, fires while charging, high thrust + low health |
| Flanker | Orbits at constant radius before attacking, breaks orbit for attack burst |
| Sniper | Maintains preferred range band, flees when player closes, slow visible shots |
| Swarmer | Spawns in clusters, individually fragile, attacks from multiple angles |
| Suicider | Charges immediately, detonates on contact AND when shot to death |

**Should have (differentiators per type):**
- Beeliner: burst fire rhythm, flee at 15% health
- Flanker: randomized orbit direction, varied radius per instance (220–350px)
- Sniper: charge-up telegraph, lateral repositioning to maintain LoS
- Swarmer: proximity-slow when near groupmates (30% thrust reduction within 80px), jitter offset
- Suicider: speed ramp-up over 2s, audio scream on detection, direction re-evaluation every 0.3s

**Defer to v2.1+:**
- Predictive aiming for Sniper
- Incoming-projectile evasion for Flanker
- True Boids flocking for Swarmer (explicitly out of scope in PROJECT.md)

**Project-wide anti-features (never build):**
- NavigationAgent2D, MountableWeapon for enemies, health bars, healing/respawning enemies, true Boids

### Architecture Approach

`EnemyShip` is a thin extension of the existing `Ship` class. It adds: a `State` enum, a `current_state` variable, virtual `_tick_state` / `_enter_state` / `_exit_state` hooks, a single `fire_timer` Timer node, and an `@export var detection_area: Area2D`. Concrete types live in `prefabs/` and override only the virtual methods relevant to their behavior. `WaveManager` is a new `Node` child of the world root — not embedded in `world.gd` — handling spawn timing, `spawn_parent` propagation, and wave completion detection via a decremented integer counter.

**Major components:**
1. **`EnemyShip` (components/enemy-ship.gd, modified)** — state machine scaffold, detection wiring, fire_timer, dying guard, steering helpers
2. **Five prefabs (beeliner, flanker, sniper, swarmer, suicider in prefabs/)** — PackedScenes with `.gd` scripts overriding `_tick_state`; no shared state between types
3. **`WaveManager` (new Node in world.tscn)** — wave definitions, spawn_parent setup walk, alive_count tracking, next-wave timing

### Critical Pitfalls

1. **AI tick runs after `die()` — null crashes and ghost bullets (C-1)** — Guard every `_physics_process` and `_tick_state` with `if dying: return`. Override `die()` in `EnemyShip` to set `dying = true` before `super(delay)` to cover the delay-window gap (pitfall m-5).

2. **Detection Area2D collision mask mismatch silently breaks all AI (C-3)** — Set mask in code: `detection_area.collision_layer = 0; detection_area.set_collision_mask_value(1, true)` (layer 1 = Ships per world.gd). A wrong mask means every enemy stays in IDLING with no error.

3. **`spawn_parent` not propagated to enemies or their bullets (C-4)** — WaveManager must call `_setup_spawn_parent(enemy)` before `spawn_parent.add_child(enemy)`. Enemy `fire()` must check `if not spawn_parent` and warn. Shortcuts to `get_tree().current_scene` were a v1.0 regression (BUG-03) — do not reintroduce.

4. **Direct `linear_velocity` assignment fights the physics integrator (C-2)** — Use `apply_force()` / `apply_central_impulse()` only from `_physics_process`. Max-speed capping must live in `_integrate_forces(state)`.

5. **Wave completion never triggers due to deferred free timing race (M-4)** — Do not count alive enemies via `get_children()`. Decrement an integer counter in `_on_enemy_died()` and use `call_deferred("_check_wave_complete")`.

---

## Implications for Roadmap

### Phase 1: EnemyShip Infrastructure
**Rationale:** Every pitfall in the critical category is a base-class concern. Building the base class correctly before any concrete type prevents rework across all five subsequent types.
**Delivers:** `EnemyShip` base class — state enum, virtual hooks, detection Area2D wiring, simplified fire logic, dying guard, steering helpers (seek/flee/arrive), spawn_parent integration.
**Addresses:** Table stakes shared across all enemy types.
**Avoids:** C-1 (dying guard), C-2 (velocity assignment), C-3 (layer mask), C-4 (spawn_parent), m-4 (find_children in tick).

### Phase 2: Beeliner + WaveManager
**Rationale:** Beeliner validates the complete pipeline end-to-end (spawn → detect → charge → fire → die → loot → wave complete) with minimum debugging complexity. WaveManager must exist here because wave-spawn context is required to expose M-4 and C-4 in a real setting.
**Delivers:** Beeliner prefab; WaveManager with single-type waves; alive_count tracking; spawn-from-edge positioning; cluster-spawn helper stub.
**Uses:** Seek steering; inline fire method; existing Bullet + Damage resource.
**Avoids:** M-4 (wave completion race), M-5 (spawn overlap).

### Phase 3: Sniper
**Rationale:** Sniper introduces the `FLEEING` state — the first state reversal. It also introduces a slow, high-damage projectile (distinct bullet tuning). One new concept per phase.
**Delivers:** Sniper prefab with preferred-range band, flee behavior, charge-up telegraph, slow/high-damage bullet.
**Avoids:** M-2 (orphaned timer on death — state-duration delay must use Timer node child, not SceneTreeTimer).

### Phase 4: Flanker
**Rationale:** Orbit steering is the most mechanically complex new behavior (tangential force + spring-correction for radius). Isolating it prevents tuning interference from other work.
**Delivers:** Flanker prefab with LURKING orbit state, randomized direction/radius, attack burst, return to orbit.
**Avoids:** M-1 (oscillating transitions — orbit/fight threshold needs hysteresis constants).

### Phase 5: Swarmer
**Rationale:** Swarmer depends on WaveManager cluster-spawn support (mature by this phase) and validates multiple concurrent enemies without shared state interference.
**Delivers:** Swarmer prefab; cluster-spawn mode in WaveManager; proximity-slow; multi-type wave compositions.
**Avoids:** M-5 (spawn overlap — cluster spawn uses minimum separation radius with iteration limit).

### Phase 6: Suicider
**Rationale:** Simplest state machine (one state: SEEKING) but requires contact explosion trigger and death explosion trigger. Building last ensures Explosion integration is clean and item-drop-on-kamikaze-death is validated.
**Delivers:** Suicider prefab with speed ramp-up, contact detonation, shot-to-death detonation, explosion chain damage.
**Avoids:** M-3 (contact signal spam — `bodies_inside` tracking to prevent repeat damage calls).

### Phase 7: Wave Polish and Escalation
**Rationale:** Wave composition tuning is only meaningful after all enemy types exist.
**Delivers:** Wave escalation data (wave definitions as Resource arrays), wave announcement HUD, breathing-room timers, first-appearance structure for each new enemy type.

### Phase Ordering Rationale

- Infrastructure before types: base class pitfalls appear in every concrete type; fix once in Phase 1, not five times.
- Beeliner proves the pipeline: fastest path to a working end-to-end flow before adding complexity.
- One new concept per type: Sniper adds flee; Flanker adds orbit; Swarmer adds group spawn; Suicider adds contact explosion. Isolation keeps debugging surface small.
- WaveManager built with Beeliner, not after all types: wave spawn is required to surface M-4 and C-4 in a realistic context.

### Research Flags

Phases with standard patterns (skip additional research):
- **Phase 1 (EnemyShip base):** Patterns fully documented in ARCHITECTURE.md with file/line references. GDQuest state machine pattern is verified.
- **Phase 2 (Beeliner + WaveManager):** Seek steering and wave-counter patterns are straightforward; all integration points identified in ARCHITECTURE.md.
- **Phase 6 (Suicider):** Explosion component already exists; contact detection pattern documented in PITFALLS.md M-3.

Phases that may benefit from targeted research during planning:
- **Phase 4 (Flanker orbit):** Orbit spring-correction tuning under RigidBody2D physics load is not fully characterized. Consider a quick isolated prototype before committing inspector values.
- **Phase 5 (Swarmer cluster spawn):** Minimum-separation placement algorithm needs a safety iteration limit to avoid an infinite loop on dense worlds; worth a brief design pass.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All recommendations based on existing codebase patterns + GDQuest verified pattern; NavigationAgent2D regression confirmed via official issue tracker |
| Features | HIGH (core), MEDIUM (tuning values) | Core behaviors well-established from multiple sources; specific ranges and fire rates are starting points for playtesting |
| Architecture | HIGH | Derived from direct inspection of production source files with file/line references; no inference required |
| Pitfalls | HIGH | Critical pitfalls verified against official Godot docs and confirmed-present code patterns in production files |

**Overall confidence:** HIGH

### Gaps to Address

- **`Ship.picker_body_entered` on enemies:** `Ship._ready()` connects a picker Area2D for item pickup. Enemies do not need item pickup. The architecture notes suggest omitting the picker node or using a flag, but this is not yet explicit in EnemyShip. Decide in Phase 1 before the Beeliner scene is authored.

- **Collision mask layer number:** Layer 1 is documented as "Ship" in world.gd comments, but the exact bit index should be confirmed against the live project settings before any enemy scene is committed. One verification step at the start of Phase 1.

- **Enemy bullet Damage resource:** The `Damage` resource has `energy` and `kinetic` fields. Research does not specify which field enemy bullets should populate, or whether enemies need custom Damage resources vs. reusing existing ammo resources. Decide in Phase 1 fire-logic design — it affects all subsequent types.

- **Suicider explosion scene:** Whether Suicider needs a distinct Explosion scene (larger radius, higher damage) or a configured instance of the existing one. Decide in Phase 6 design, not earlier.

---

## Sources

### Primary (HIGH confidence)
- GDQuest Finite State Machine tutorial — node-based StateMachine + State pattern (gdquest.com)
- Godot official docs — RigidBody2D, Area2D collision masks, _integrate_forces (docs.godotengine.org)
- Direct codebase inspection — `components/body.gd`, `components/ship.gd`, `components/enemy-ship.gd`, `components/mountable-weapon.gd`, `components/bullet.gd`, `components/item-dropper.gd`, `world.gd`
- Enemy NPC Design Patterns in Shooter Games — ACM DL (academic)
- Keys to Rational Enemy Design — GDKeys

### Secondary (MEDIUM confidence)
- Steering Behaviors Godot 4 — GitHub konbel
- Battle Circle AI — Tutsplus/Envato (orbit AI)
- Gravity Ace devlog — drone AI in a physics-based space shooter
- The Level Design Book — enemy archetype design principles
- Unleashing Chaos: Mastering Enemy Waves — wave design principles

### Tertiary (reference)
- Godot issue #110686 — NavigationAgent2D regression in 4.5 (confirms avoidance recommendation)
- LimboAI asset library — evaluated and rejected

---
*Research completed: 2026-04-11*
*Ready for roadmap: yes*
