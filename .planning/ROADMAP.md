# Roadmap: Graviton

## Milestones

- ✅ **v1.0 Stabilize + Migrate** — Phases 1-3 (shipped 2026-04-10) — [archive](milestones/v1.0-ROADMAP.md)
- 📋 **v2.0 Enemy AI** — Phases 4-9 (planned)

## Phases

<details>
<summary>✅ v1.0 Stabilize + Migrate (Phases 1-3) — SHIPPED 2026-04-10</summary>

- [x] Phase 1: Bug Fixes (3/3 plans) — completed 2026-04-07
- [x] Phase 2: Code Quality (2/2 plans) — completed 2026-04-07
- [x] Phase 3: Godot 4.6.2 Migration (2/2 plans) — completed 2026-04-10

</details>

### 📋 v2.0 Enemy AI

- [ ] **Phase 4: EnemyShip Infrastructure** — Base class with state machine, detection, fire loop, dying guard, and steering helpers
- [ ] **Phase 5: Beeliner + WaveManager** — First enemy type proves the full spawn-detect-fight-die-loot-wave-complete pipeline
- [ ] **Phase 6: Sniper** — Range-holding enemy with flee behavior and slow heavy projectile
- [ ] **Phase 7: Flanker** — Orbit-steering enemy with LURKING state and attack burst
- [ ] **Phase 8: Swarmer** — Cluster-spawned fragile enemy with proximity cohesion
- [ ] **Phase 9: Suicider** — Contact-detonating enemy triggering the existing Explosion component

## Phase Details

### Phase 4: EnemyShip Infrastructure
**Goal**: The EnemyShip base class is complete and safe — all five concrete types can be built on it without rework
**Depends on**: Nothing (v2.0 start; v1.0 shipped)
**Requirements**: ENM-01, ENM-02, ENM-03, ENM-04, ENM-05, ENM-06, ENM-15
**Plans**: 2 plans
Plans:
- [x] 04-01-PLAN.md — EnemyShip base class script + Ship.gd picker null guard
- [x] 04-02-PLAN.md — Base enemy skeleton scene + world.gd test placement
**Success Criteria** (what must be TRUE):
  1. A placed EnemyShip scene detects the player entering its detection radius and transitions out of IDLING — confirmed by state-change log or color modulate
  2. When the enemy dies, the dying guard blocks state transitions and AI ticking — `is_dying` check in `_physics_process` and `_on_detection_area_body_entered` returns early
  3. EnemyShip base class has a `_fire()`-pattern convention documented and a barrel `Node2D` in the skeleton scene — concrete types can override to spawn projectiles (validated in Phase 5)
  4. Enemy movement accelerates and clamps to max speed without jitter — no direct linear_velocity assignments exist in any enemy script
  5. Enemy scenes have no picker Area2D node — enemies do not collect items on overlap

### Phase 5: Beeliner + WaveManager
**Goal**: A wave of Beeliners spawns, charges the player, fires, dies, drops loot, and the WaveManager correctly registers wave completion
**Depends on**: Phase 4
**Requirements**: ENM-07, ENM-12, ENM-13, ENM-14
**Plans**: 2 plans
Plans:
- [x] 05-01-PLAN.md — Beeliner enemy type (script + bullet scene + inherited scene with loot)
- [x] 05-02-PLAN.md — WaveManager script + world.gd integration + human verification
**Success Criteria** (what must be TRUE):
  1. Triggering a wave spawns the configured number of Beeliners outside the visible area with no physics-separation launch on the first frame
  2. Each Beeliner seeks the player, transitions to FIGHTING when in range, and fires projectiles that damage the player
  3. After all Beeliners in a wave are destroyed, the WaveManager detects wave completion and can trigger the next wave — even when enemies are freed via deferred queue
  4. Dead Beeliners drop loot items that the player can pick up

### Phase 6: Sniper
**Goal**: The Sniper keeps a preferred standoff distance, fires slow heavy shots, and retreats when the player closes in
**Depends on**: Phase 5
**Requirements**: ENM-08
**Success Criteria** (what must be TRUE):
  1. The Sniper maintains a visible separation gap from the player rather than closing to melee range
  2. When the player moves inside the Sniper's close-range threshold, the Sniper transitions to FLEEING and moves away
  3. Sniper projectiles are visually and mechanically distinct from Beeliner shots — slower travel speed, higher damage per hit
**Plans**: TBD

### Phase 7: Flanker
**Goal**: The Flanker orbits the player at a consistent radius before breaking into an attack burst, then returns to orbit
**Depends on**: Phase 6
**Requirements**: ENM-09
**Success Criteria** (what must be TRUE):
  1. The Flanker visibly circles the player at a roughly constant radius rather than charging straight in
  2. After orbiting, the Flanker transitions to FIGHTING, fires a burst, then returns to the orbit pattern
  3. Orbit direction and radius vary between Flanker instances — not every Flanker circles identically
**Plans**: TBD

### Phase 8: Swarmer
**Goal**: A cluster of Swarmers spawns together, spreads to attack from multiple angles, and slows down when crowded by groupmates
**Depends on**: Phase 7
**Requirements**: ENM-10
**Success Criteria** (what must be TRUE):
  1. A wave spawns multiple Swarmers in a cluster with no individual launching off screen due to spawn overlap
  2. Swarmers approach the player from different angles rather than all piling onto the same vector
  3. A Swarmer visibly reduces thrust when another Swarmer is within the proximity cohesion radius — the cluster does not pass through itself
**Plans**: TBD

### Phase 9: Suicider
**Goal**: The Suicider charges the player and detonates on contact, dealing explosion-radius damage, and also explodes when shot to death
**Depends on**: Phase 8
**Requirements**: ENM-11
**Success Criteria** (what must be TRUE):
  1. A Suicider that reaches the player triggers an explosion — player ship takes area damage and receives an impulse
  2. A Suicider that is shot to death also triggers the explosion before its scene is freed
  3. The explosion does not trigger more than once per Suicider death — no repeat damage from contact signal spam
**Plans**: TBD

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1. Bug Fixes | v1.0 | 3/3 | Complete | 2026-04-07 |
| 2. Code Quality | v1.0 | 2/2 | Complete | 2026-04-07 |
| 3. Godot 4.6.2 Migration | v1.0 | 2/2 | Complete | 2026-04-10 |
| 4. EnemyShip Infrastructure | v2.0 | 0/2 | Planning | - |
| 5. Beeliner + WaveManager | v2.0 | 0/2 | Planning | - |
| 6. Sniper | v2.0 | 0/? | Not started | - |
| 7. Flanker | v2.0 | 0/? | Not started | - |
| 8. Swarmer | v2.0 | 0/? | Not started | - |
| 9. Suicider | v2.0 | 0/? | Not started | - |
