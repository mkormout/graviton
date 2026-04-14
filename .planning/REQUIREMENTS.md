# Requirements: Graviton

**Defined:** 2026-04-11
**Core Value:** The mount-and-weapon system must work reliably — ships can equip, fire, and swap weapons without bugs or silent failures.

## v2 Requirements (Milestone 2 — Enemies)

### AI Infrastructure

- [ ] **ENM-01**: EnemyShip base class defines `State` enum (idling, seeking, lurking, fighting, fleeing, patrolling, evading, escorting) and virtual `_tick_state`, `_enter_state`, `_exit_state` methods for concrete types to override
- [ ] **ENM-02**: EnemyShip base class guards all state ticks and fire calls against the `dying` flag so AI does not execute during the death delay
- [ ] **ENM-03**: Enemy movement uses `apply_central_force` steering vectors; maximum speed clamped in `_integrate_forces`, never by direct `linear_velocity` assignment
- [ ] **ENM-04**: Enemy detection uses `Area2D` with explicit layer/mask bits; mask values documented in code comments referencing the physics layer table in `world.gd`
- [ ] **ENM-05**: Enemy fire uses a simplified `Timer`-based fire loop that instantiates a bullet scene at a barrel `Node2D` using `spawn_parent.add_child()` — not `get_tree().current_scene`
- [ ] **ENM-06**: Enemy projectiles carry a fixed energy `Damage` resource configured per enemy type (not speed-scaled)

### Enemy Types

- [ ] **ENM-07**: Beeliner — seeks player using SEEKING state, transitions to FIGHTING when in range and fires; no picker node in scene
- [ ] **ENM-08**: Sniper — maintains standoff distance in SEEKING, fires slow heavy shots in FIGHTING, transitions to FLEEING when player enters close range
- [ ] **ENM-09**: Flanker — orbits player in LURKING state using tangential steering force + radius correction before entering FIGHTING; no picker node in scene
- [ ] **ENM-10**: Swarmer — low HP, cluster-spawned, reduces thrust when near group members (proximity cohesion without full Boids); no picker node in scene
- [ ] **ENM-11**: Suicider — seeks player in SEEKING, triggers existing `Explosion` component on `body_entered` contact; no picker node in scene; no fire logic

### Wave Spawning

- [ ] **ENM-12**: `WaveManager` node is a standalone child of the World root, spawns enemy waves with configurable wave composition (enemy type + count)
- [ ] **ENM-13**: Wave completion is tracked by a counter decremented on each enemy death signal — not by `get_children()` count — to handle deferred frees correctly
- [ ] **ENM-14**: Enemies are spawned with a minimum outer-radius margin from occupied positions to prevent physics-separation launch on the first frame
- [ ] **ENM-15**: All enemy scenes omit the picker `Area2D` node (enemies do not collect items)

## Future Requirements (Deferred)

- Flocking / Boids behavior for Swarmers — deferred to v2.1+
- Predictive targeting for Sniper — deferred to v2.1+
- Pre-wave HUD announcement and audio sting — deferred to v2.1+
- Escort state implementation — deferred to v2.1+
- Patrol waypoint system — deferred to v2.1+

## Out of Scope

| Feature | Reason |
|---------|--------|
| Flocking / Boids | Deferred — get single-enemy AI solid first |
| NavigationAgent2D pathfinding | No nav mesh in open space; 4.5 regression risk |
| LimboAI plugin | C++ GDExtension, adds external dependency, no benefit over native GDScript state machine |
| MountableWeapon for enemies | Reduces coupling; easier to balance enemy difficulty independently |
| Multiplayer | Not planned |
| Automated test suite (GUT) | User opted for manual playtesting |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ENM-01 | Phase 4 | Pending |
| ENM-02 | Phase 4 | Pending |
| ENM-03 | Phase 4 | Pending |
| ENM-04 | Phase 4 | Pending |
| ENM-05 | Phase 4 | Pending |
| ENM-06 | Phase 4 | Pending |
| ENM-07 | Phase 5 | Pending |
| ENM-08 | Phase 6 | Pending |
| ENM-09 | Phase 7 | Pending |
| ENM-10 | Phase 8 | Pending |
| ENM-11 | Phase 9 | Pending |
| ENM-12 | Phase 5 | Pending |
| ENM-13 | Phase 5 | Pending |
| ENM-14 | Phase 5 | Pending |
| ENM-15 | Phase 4 | Pending |

**Coverage:**
- v2 requirements: 15 total
- Mapped to phases: 15
- Unmapped: 0

---
*Requirements defined: 2026-04-11*
*Last updated: 2026-04-11 after v2.0 roadmap created*
