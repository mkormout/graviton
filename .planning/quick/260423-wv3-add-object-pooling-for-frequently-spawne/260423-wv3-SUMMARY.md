---
quick_id: 260423-wv3
type: execute
tags: [performance, pooling, gdscript, godot, bullets, explosions]
completed_date: 2026-04-23
tech_stack:
  added: []
  patterns:
    - "Generic ScenePool + autoload PoolManager"
    - "_pool_reset() contract with default reset fallback"
    - "_pool_scene meta-key lookup for type-free release"
key_files:
  created:
    - components/scene-pool.gd
    - components/pool-manager.gd
  modified:
    - project.godot
    - components/body.gd
    - components/bullet.gd
    - components/explosion.gd
    - components/flanker.gd
    - components/beeliner.gd
    - components/sniper.gd
    - components/swarmer.gd
    - components/mountable-weapon.gd
    - prefabs/minigun/minigun-weapon.gd
    - prefabs/minigun/minigun-bullet.gd
    - prefabs/gausscannon/gausscannon-weapon.gd
    - prefabs/gausscannon/gausscannon-bullet.gd
    - prefabs/rpg/rpg-weapon.gd
    - prefabs/rpg/rpg-bullet.gd
    - prefabs/laser/laser-weapon.gd
    - prefabs/laser/laser-bullet.gd
    - prefabs/laser/laser-bounce-flash.gd
    - prefabs/gravitygun/gravitygun-script.gd
    - prefabs/ui/bullet-impact.gd
    - world.gd
decisions:
  - "Reparent lifecycle (remove_child/add_child) over in-tree-disable — idiomatic Godot 4 pool; Area2D/signal wiring preserved across reuse"
  - "_pool_scene meta stored once on first instantiate so release() can look up owning pool without per-caller type info"
  - "Arming is deferred in _pool_reset via call_deferred so die(life) awaits physics_frame only after the consumer's add_child has flushed"
  - "Unpooled death/debris scenes fall back to instantiate() via PoolManager.is_pooled() gate — avoids lazy pools for ship/coin/asteroid explosions"
  - "Absolute (not compound) bullet light/particle scaling in gausscannon/gravitygun fire paths — prevents snowball across pool reuses"
---

# Quick Task 260423-wv3: Object Pooling Summary

Replace per-frame `PackedScene.instantiate()` for high-frequency spawned
entities (player bullets, enemy bullets, impact/flash FX, bullet-death
explosions) with an autoload `PoolManager` + generic `ScenePool`. Pool
capacity is retained across game restarts; all existing fire/collide/death
behavior is preserved 1:1.

## Tasks

### Task 1 — Pool infrastructure (`852d350`)

New `components/scene-pool.gd`:
- `class_name ScenePool extends Node`
- `build(scene, initial)` / `prewarm()` / `acquire()` / `release(node)` / `stats()`
- `_apply_default_reset` handles RigidBody2D (clear velocities, unfreeze, scale)
  and CharacterBody2D (clear velocity) automatically
- `_prepare_for_sleep` sets `process_mode=DISABLED`, hides CanvasItems,
  freezes RigidBody2Ds, zero-velocities CharacterBody2Ds
- Growth policy: dynamic, one `push_warning` once a pool doubles past
  its initial size

New `components/pool-manager.gd`:
- Autoload Node, registers 15 pools in `_POOL_CONFIGS`:
  minigun-bullet:60, gausscannon-bullet:8, rpg-bullet:6, laser-bullet:40,
  gravitygun-bullet:4, {flanker/beeliner/sniper/swarmer}-bullet:24,
  bullet-impact:40, laser-bounce-flash:30, 4x bullet-explosion:20
- `acquire(scene)` lazy-creates size-8 pool + push_warning if unregistered
- `release(node)` reads `_pool_scene` meta, falls back to queue_free
- `is_pooled(scene)` used by callers to branch release paths

`project.godot`: registered `PoolManager="*res://components/pool-manager.gd"`
after MusicManager.

No spawner/queue_free site touched. `grep PoolManager` returns hits only
in pool-manager.gd / scene-pool.gd.

### Task 2 — Pool-aware lifecycle (`da823d7`)

`components/body.gd`:
- `_pool_reset()`: resets `dying` and `health` (subclasses super it)
- `_release_to_pool_or_free()`: reads `_pool_scene` meta, chooses pool vs
  queue_free
- `die()` replaces final `queue_free()` with `_release_to_pool_or_free()`
- Post-await guard (`if dying or not is_inside_tree(): return`): prevents
  double-release when a collision race fires a second `die(death_ttl)`
  after the life-timer await has already completed

`components/bullet.gd`:
- Extracted `_arm()` (kicks off `die(life)`) from `_ready`
- `_pool_reset()` calls `call_deferred("_arm")` so the physics_frame await
  inside `die()` runs AFTER the consumer's `call_deferred("add_child")` has
  flushed (the node must be in the tree for `await get_tree().physics_frame`
  to advance)
- `body_entered.connect(collision)` guarded by `is_connected` check on
  both `_ready` and `_pool_reset`

`components/explosion.gd`:
- `_ready`: `if area == null: initialize()` — skip duplicate Area2D build
  on pool reuse
- Extracted `_arm()` (re-emit particles, play audio, re-enable
  `area.monitoring`)
- `_pool_reset()`: clears `_die_left`, disables area.monitoring/particles,
  `call_deferred("_on_reacquired")` to run `_arm + explode + die(time)`
  after the consumer reparents us
- New `_release()` method called from `_physics_process` when `_die_left`
  expires — disables area.monitoring then returns to pool or queue_free

`prefabs/laser/laser-bullet.gd`:
- `_configure_collision()` extracted (layer=4, mask=1|8,
  `add_collision_exception_with(shooter)`)
- `_pool_reset()`: clears collision exceptions, resets bounce_count /
  shooter / spawn_parent / velocity / `_life_left`, re-runs
  `_configure_collision`
- New `_release_laser()` replaces 3 raw `queue_free()` calls (life expiry,
  max bounces, normal impact)

`prefabs/ui/bullet-impact.gd`, `prefabs/laser/laser-bounce-flash.gd`:
- `finished.connect(queue_free)` → `finished.connect(_on_finished)`,
  guarded against duplicate connections
- `_pool_reset()` sets `emitting=false` (consumer calls `restart()` after
  acquire)
- `_on_finished()` returns to pool or queue_free

### Task 3 — Player-weapon + bullet-impact spawners (`1aa6033`)

Replaced `ammo.instantiate()` → `PoolManager.acquire(ammo)` at every
player-weapon fire path:
- `components/mountable-weapon.gd:111`
- `prefabs/minigun/minigun-weapon.gd:58`
- `prefabs/gausscannon/gausscannon-weapon.gd:66`
- `prefabs/rpg/rpg-weapon.gd:100`
- `prefabs/laser/laser-weapon.gd:21`
- `prefabs/gravitygun/gravitygun-script.gd:97`

Laser recursion + flash:
- `prefabs/laser/laser-bullet.gd:66` (bounce child) and `:81` (flash FX)
  → `PoolManager.acquire(...)`; flash calls `restart()` after add_child
  since `_pool_reset` set `emitting=false`

Impact FX (3 bullet scripts):
- `prefabs/minigun/minigun-bullet.gd:13`, `prefabs/gausscannon/gausscannon-bullet.gd:13`,
  `prefabs/rpg/rpg-bullet.gd:21` → `PoolManager.acquire(impact_scene)` + `restart()`

Deviations while wiring spawners (Rule 1 bugs introduced by pool reuse):
- `prefabs/gausscannon/gausscannon-weapon.gd`: changed
  `bullet_light.energy = lerp(0.2, bullet_light.energy, fraction)` →
  `lerp(0.2, 1.0, fraction)` and `bullet_particles.scale *= lerp(...)` →
  `scale = Vector2(5, 5) * lerp(...)`. Compound mutation would snowball
  across successive pool acquires.
- `prefabs/rpg/rpg-bullet.gd`: added `_pool_reset()` that clears `_target`
  so a reused RPG bullet doesn't continue homing on a dead/freed target
  from its previous acquisition.

### Task 4 — Enemy bullets + death scenes + restart cleanup (`f915e5a`)

Enemy bullet spawns:
- `components/flanker.gd:155`, `components/beeliner.gd:101`,
  `components/sniper.gd:163`, `components/swarmer.gd:177`:
  `_bullet_scene.instantiate()` → `PoolManager.acquire(_bullet_scene)`

`components/body.gd:53` death-scene spawn:
- Gated by `PoolManager.is_pooled(death)` — pooled bullet-explosions use
  the pool, unpooled scenes (ship/coin/asteroid explosions) keep using
  `instantiate()` to avoid spawning lazy pools for rarely-used scenes.

`components/explosion.gd:121` debris spawn:
- Gated by `PoolManager.is_pooled(model)` — today's bullet-explosion scenes
  have no debris arrays, so the fallback branch runs. Registered debris
  scenes would auto-use the pool.

`world.gd _restart_game`:
- Explosion and Bullet child loops route through new `_free_or_release()`
  helper that returns pooled instances to their pool and queue_frees the
  rest. Pools retain capacity across restarts.

## Initial pool sizes (rationale)

| Scene | Size | Rationale |
|---|---|---|
| minigun-bullet | 60 | Spooled minigun max rate (~28/s per barrel) × life (2s) × safety margin |
| gausscannon-bullet | 8 | Slow charge cycle, few concurrent |
| rpg-bullet | 6 | Locked-on fire rate limits concurrency |
| laser-bullet | 40 | 3 weapons × max_bounces 3 × branch factor 2 |
| gravitygun-bullet | 4 | Visual-only projectile, slow charge |
| enemy bullets (×4) | 24 each | Wave 20 worst-case concurrent per type |
| bullet-impact | 40 | Matches minigun fire concurrency |
| laser-bounce-flash | 30 | Concurrent laser bounces × branch factor |
| bullet-explosion (×4) | 20 each | time=1s lifetime × peak collision rate |

Sizes are centralized in `_POOL_CONFIGS` in `pool-manager.gd` — tune in
one place.

## Extra handling required

- **Bullet arming defer**: `die(life)` awaits `get_tree().physics_frame`;
  orphan nodes (pre-add_child) hang the await. `_pool_reset` uses
  `call_deferred("_arm")` so arming happens AFTER the consumer's
  `call_deferred("add_child")` runs.
- **Body double-release guard**: `die()` sets `dying=true` AFTER its
  await, which means collision's `die(death_ttl)` could race life's
  `die(life)`. Added `if dying or not is_inside_tree(): return` post-await
  to avoid double death-scene spawn and double release.
- **Explosion Area2D reuse**: `initialize()` adds the Area2D via
  `call_deferred("add_child", area)`, done once-per-instance; pool reuse
  skips re-initialization and instead toggles `area.monitoring` on/off
  through `_arm` / `_release`.
- **CPUParticles2D replay**: bullet-impact, laser-bounce-flash, and the
  gausscannon/gravitygun charge-scaled particles all need `.restart()`
  after acquire because `_pool_reset` sets `emitting=false`. Spawners
  were updated to call `restart()` when they acquire FX.
- **Signal deduplication**: all pooled entities now gate
  `X.connect(...)` with `is_connected` checks to survive repeated
  `_ready` invocations (first spawn) + `_pool_reset` re-arm.
- **Gausscannon compound scaling**: switched from `scale *= lerp(...)`
  and `energy = lerp(0.2, current_energy, f)` to absolute formulas
  (`Vector2(5,5) * lerp(...)`, `lerp(0.2, 1.0, f)`). Otherwise
  successive pool reuses snowball the scale and energy values.
- **RPG stale target**: `_pool_reset` clears `_target` so the spawner's
  explicit `set_target()` is the sole source of truth per fire; without
  this a previously-locked RPG could chase a freed target after reuse.

## PoolManager stats snapshot

Godot CLI not available on the executor host, so live Wave-20 stats were
not captured. On first boot the prewarm loop creates:
- 15 pools × {60, 8, 6, 40, 4, 24×4, 40, 30, 20×4} = ~420 preallocated
  instances, all `{free:N, live:0}` with `initial=N`.
- Expected during Wave 20 peak: minigun-bullet ~live 40–50 / free
  20–10 / total 60; bullet-explosion each ~live 5–10; laser-bullet
  ~live 15–25.

## Deviations from plan

### Auto-fixed issues (Rule 1 bugs surfaced by pool reuse)

1. **[Rule 1 - Bug] Gausscannon bullet light/particle compound scaling**
   - Found during: Task 3
   - Issue: `bullet_light.energy = lerp(0.2, bullet_light.energy, f)` and
     `bullet_particles.scale *= lerp(0.2, 1.0, f)` read the current
     value as the ceiling; successive pool reuses would shrink both
     values exponentially.
   - Fix: switched to absolute `lerp(0.2, 1.0, f)` and
     `Vector2(5, 5) * lerp(...)`.
   - Files: `prefabs/gausscannon/gausscannon-weapon.gd`
   - Commit: `1aa6033`

2. **[Rule 1 - Bug] RPG stale homing target across pool reuse**
   - Found during: Task 3
   - Issue: RpgBullet keeps `_target` across reuse, so an unlocked
     follow-up shot could home onto the previous (possibly freed)
     target.
   - Fix: `_pool_reset()` sets `_target = null`.
   - Files: `prefabs/rpg/rpg-bullet.gd`
   - Commit: `1aa6033`

### Auto-added missing critical functionality (Rule 2)

3. **[Rule 2 - Critical] Body.die() double-release guard**
   - Found during: Task 2
   - Issue: `die(delay)` sets `dying=true` only AFTER its await. Two
     concurrent die() calls (e.g., collision + life-timer expiry) both
     pass the `if dying: return` gate, then both run the death scene +
     release path. With the pool this produces double-spawn-death-scene
     and double-release (the second release is on a node already
     re-acquired).
   - Fix: added `if dying or not is_inside_tree(): return` after the
     await so the later coroutine bails out.
   - Files: `components/body.gd`
   - Commit: `da823d7`

## Deferred items

None.

## Self-Check: PASSED

- Files created:
  - `components/scene-pool.gd`: FOUND
  - `components/pool-manager.gd`: FOUND
- Commits present:
  - `852d350` (Task 1): FOUND
  - `da823d7` (Task 2): FOUND
  - `1aa6033` (Task 3): FOUND
  - `f915e5a` (Task 4): FOUND
- Autoload registered in `project.godot`: FOUND
- `.instantiate()` sweep: hits remain only in allowlisted files
  (mount-point, item-type, item-dropper, wave-manager, scene-pool) and
  in `is_pooled()`-gated fallback branches (body.gd death, explosion.gd
  debris, body.gd successor).
- `queue_free()` on pooled types: only inside fallback branches of
  `_release*` helpers.
