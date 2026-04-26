---
slug: pool-damage-death-crash
status: resolved
trigger: "After object-pooling refactor (PoolManager autoload + ScenePool for bullets/explosions/impact FX/debris), the game crashes when something receives damage or dies — unclear which path triggers it"
created: 2026-04-25
updated: 2026-04-25
---

# Debug Session: pool-damage-death-crash

## Symptoms

- **Expected**: Bullets hit targets and apply damage; targets die cleanly without crashing the game. Pooled bodies recycle through despawn → pool checkout without engine errors.
- **Actual**: Game crashes when something takes damage or dies. Unclear whether the crash is on the damage path (e.g. bullet `body_entered` → `damage()`) or on the death path (e.g. `Body.die()` → successor spawn / pool return / `queue_free` / `Item` drop).
- **Error messages**: Not yet captured. Need to repro and read the Godot console / stderr.
- **Timeline**: Started after the object-pooling refactor (quick task `260423-wv3-add-object-pooling-for-frequently-spawne`, commit `f915e5a`, 2026-04-23). Several follow-up fixes since then (`92132d7` stopped toggling `freeze`/`sleeping`, `d9e60c4` fixed bullet velocity assignment) addressed earlier pool issues but did not resolve the damage/death crash.
- **Reproduction**: Mount a weapon, fire at an enemy or take damage, observe crash. Exact trigger (incoming damage vs death) needs to be isolated.

## Recent Pool-Related Commits

- `d9e60c4` fix(pool): set bullet linear_velocity without /mass + sync add_child
- `a64688e` debug(pool): try minigun fire without /mass division
- `c461136` fix(debug): annotate target_velocity as Vector2 to satisfy parser
- `4bab2e3` debug(pool): add prints + match flanker pattern in minigun fire
- `92132d7` fix(pool): stop toggling RigidBody2D.freeze/sleeping on pool transitions
- `f915e5a` feat(quick): add object pooling for frequently-spawned scenes (root)

## Suspected Areas

- `PoolManager` autoload + `ScenePool` checkout/return logic
- `Body.damage()` / `Body.die()` flow when pooled bodies are involved
- `Bullet.body_entered` signal handler — may fire after the bullet has been returned to the pool, hitting a freed/reset instance
- `ItemDropper` / successor-spawn on death — may try to use a stale pooled scene
- Signal connections persisting across pool checkout/return (re-entry / duplicate signal fire)

## Current Focus

hypothesis: "Enemy bullets (flanker, beeliner, sniper, swarmer) never set bullet.spawn_parent = spawn_parent after pool acquire. When those bullets die, Body.die() acquires a pooled explosion but spawn_parent is null so add_child is never called. The orphaned explosion enters an infinite call_deferred('_on_reacquired') loop until Godot's message queue overflows and crashes."
test: "Static code analysis — confirmed across all four enemy _fire() methods"
expecting: "Setting bullet.spawn_parent = spawn_parent in each enemy _fire() before add_child will stop the orphaned explosion loop"
next_action: "FIXED — applied to flanker.gd, beeliner.gd, sniper.gd, swarmer.gd"
reasoning_checkpoint: "Traced Body.die() pool path: acquire explosion -> set node.spawn_parent = spawn_parent (null on enemy bullets) -> if spawn_parent: add_child (skipped) -> Explosion._pool_reset -> call_deferred(_on_reacquired) -> is_inside_tree() = false -> call_deferred(_on_reacquired) again -> infinite loop -> message queue overflow -> crash."

## Evidence

- timestamp: 2026-04-25T00:00:00Z
  file: components/flanker.gd
  observation: "_fire() acquires bullet from PoolManager but never sets bullet.spawn_parent before add_child. Body.die() on the bullet then acquires a pooled explosion, sets node.spawn_parent = null, skips add_child, and the explosion enters an infinite deferred loop."

- timestamp: 2026-04-25T00:00:00Z
  file: components/beeliner.gd
  observation: "Same pattern as flanker — _fire() does not set bullet.spawn_parent."

- timestamp: 2026-04-25T00:00:00Z
  file: components/sniper.gd
  observation: "Same pattern as flanker — _fire() does not set bullet.spawn_parent."

- timestamp: 2026-04-25T00:00:00Z
  file: components/swarmer.gd
  observation: "Same pattern as flanker — _fire() does not set bullet.spawn_parent."

- timestamp: 2026-04-25T00:00:00Z
  file: components/body.gd
  observation: "Body.die() line 88: node.spawn_parent = spawn_parent (unconditional). Line 89-91: if spawn_parent: spawn_parent.add_child(node) else push_warning. When spawn_parent is null the explosion is acquired from pool but never parented."

- timestamp: 2026-04-25T00:00:00Z
  file: components/explosion.gd
  observation: "Explosion._on_reacquired() checks is_inside_tree(); if false, call_deferred('_on_reacquired') again. With no parent ever assigned this loops indefinitely per bullet death, accumulating deferred calls until crash."

- timestamp: 2026-04-25T00:00:00Z
  file: components/mountable-weapon.gd
  observation: "Player weapon fire() does set spawn_parent on pooled bullets (line 121-122: if 'spawn_parent' in instance: instance.spawn_parent = spawn_parent). This is the pattern enemy scripts were missing."

## Eliminated Hypotheses

- Signal connections persisting across pool checkout/return: Bullet._pool_reset() guards against duplicate body_entered connections, and the dying flag blocks re-entry. Not the crash.
- Body.die() double-release: The dying flag and is_inside_tree() checks in both die() coroutines correctly prevent double-death. Not the crash.
- RigidBody2D freeze/sleeping desync: Fixed in commit 92132d7 (collision layer zeroing replaces freeze/sleeping). Not the current crash.

## Resolution

root_cause: "Enemy bullet scripts (flanker, beeliner, sniper, swarmer) acquire pooled bullets via PoolManager.acquire() but never assign bullet.spawn_parent = spawn_parent. When those bullets die, Body.die() acquires a pooled explosion, finds spawn_parent=null, skips add_child, and the orphaned explosion node enters an infinite call_deferred('_on_reacquired') loop (Explosion._on_reacquired checks is_inside_tree() — always false for an unparented node — and re-defers itself every frame). This accumulates unbounded deferred calls until Godot's message queue exhausts memory and crashes."
fix: "Add bullet.spawn_parent = spawn_parent in each enemy _fire() method (flanker, beeliner, sniper, swarmer) immediately after PoolManager.acquire(), mirroring the pattern used by MountableWeapon.fire() for player bullets."
verification: "Fire each enemy type, confirm explosions appear at bullet death locations and no crash occurs. Pool stats should show balanced live/free counts for bullet-explosion pools."
files_changed:
  - components/flanker.gd
  - components/beeliner.gd
  - components/sniper.gd
  - components/swarmer.gd
