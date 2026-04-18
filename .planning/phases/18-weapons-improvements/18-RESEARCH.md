# Phase 18: Weapons Improvements — Research

**Researched:** 2026-04-18
**Domain:** Godot 4 GDScript — weapon mechanics, physics, particle effects, HUD
**Confidence:** HIGH (core Godot APIs verified via Context7; codebase confirmed by direct file reads)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- D-01: Fix recoil bug in `mountable-body.gd` line 44–47. Use `apply_central_impulse(vector)` OR `apply_impulse(vector, to_local(sender.global_position))`.
- D-02: Recoil direction is correct (`-Vector2.from_angle(sender.global_rotation) * meta`) — only impulse application point changes.
- D-03/D-21: Hold fire to charge (Gausscannon 0–2s, GravityGun 0–1.5s). Releasing fires.
- D-04: Gausscannon charge scales damage, velocity, recoil proportional to charge fraction.
- D-05: Gausscannon visual: PointLight2D energy scales from base to bright max.
- D-06: At full charge: CPUParticles2D burst from barrel.
- D-07: Quick tap = base stats.
- D-08: RPG lock cone ~30°, within weapon range, one target per gun.
- D-09: Lock takes 1.5s. Visual: red double-square brackets shrink toward target.
- D-10: Fire without lock = normal rocket; fire with lock = homing.
- D-11: If target dies, lock clears, rocket continues in current direction.
- D-12: Lock builds passively (no hold required). Fire button fires when ready.
- D-13: Minigun ramps fire rate from base to max over 2s continuously.
- D-14: Release → rate drops to base in 0.5s.
- D-15: At max spool: damage × 1.5 AND PointLight2D/CPUParticles2D scales with rate.
- D-16: Laser bounces off all physics bodies, max 3 bounces.
- D-17: Each bounce spawns 2 new bullets (reflected + slight spread). Chain 1→2→4→8.
- D-18: Full damage on every hit.
- D-19: Green CPUParticles2D flash at each bounce contact point.
- D-20: Spawned bullets inherit decremented bounce count.
- D-22: GravityGun shockwave force AND Area2D radius scale with charge fraction.
- D-23: GravityGun visual: PointLight2D pulses faster as charge builds.
- D-24: Muzzle flash (CPUParticles2D one-shot) at barrel on every fire.
- D-25: Bullet trail (Line2D updating per frame OR CPUParticles2D trail).
- D-26: Impact sparks on bullet hit.
- D-27: Screen shake on heavy weapons (Gausscannon, RPG, GravityGun); not Minigun/Laser.
- D-28: Balance pass vs v3.0 HP (enemies at current values — see balance section).
- D-29–D-33: Weapon HUD: ammo counter, reload bar, active weapon icon/name, charge/spool % bar.

### Claude's Discretion
- Exact muzzle flash color and particle count per weapon
- Specific balance numbers for damage, fire rate, spread, ammo per weapon
- Bounce bullet spread angle on reflection
- HUD node structure and exact screen position
- Laser bounce reflection calculation (pure or slightly randomized)
- Whether Minigun spool persists briefly between burst gaps or fully resets on release

### Deferred Ideas (OUT OF SCOPE)
- None — all stated ideas are within Phase 18 scope.
</user_constraints>

---

## Summary

Phase 18 adds six mechanics across all player weapons. The core challenges are:

1. **Recoil bug**: `apply_impulse(vector, place)` in `mountable-body.gd` line 47 passes `sender.global_position / 100` as the offset. Godot 4 docs confirm `apply_impulse`'s position is an offset from the body's origin in **global coordinate axes** (but centered at the body, not world origin). The real fix: pass `Vector2.ZERO` (which is what `apply_central_impulse` does) or `to_local(sender.global_position)` to apply torque at the correct local offset. The division by 100 is the clearest bug — it scales the offset to near-zero but not exactly zero, producing unpredictable off-center torque.

2. **Bullet bounce**: RigidBody2D `body_entered` does NOT provide a collision normal. Bounce implementation requires switching laser bullets to `CharacterBody2D` or `Area2D` with `move_and_collide`. The established Godot pattern uses `CharacterBody2D.move_and_collide()` which returns a `KinematicCollision2D` with `get_normal()`. Since bullets must detect AND reflect, laser bullets should be reclassed to `CharacterBody2D` (extends `Body` will need adjustment) or implemented as `Area2D` nodes with manual raycasting.

3. **Charge pattern**: Hold detection via `Input.is_action_pressed()` polled in `_physics_process()` on the weapon script itself. This keeps world.gd clean — weapons handle their own charge accumulation.

4. **Homing**: Per-frame `apply_central_force()` toward target is physics-correct for `RigidBody2D`. Direct velocity setting each frame is simpler but fights physics — use force-based steering with a per-frame acceleration budget.

5. **HUD world-to-screen**: RPG lock bracket follows target's world position. Use `get_viewport().get_canvas_transform() * target.global_position` to convert world → screen for a CanvasLayer Control node.

**Primary recommendation:** Follow the `GravityGun extends MountableWeapon` pattern for all per-weapon mechanics. Create `GausscannonWeapon`, `RpgWeapon`, `MinigunWeapon`, `LaserWeapon` scripts. Keep `world.gd` untouched for charge input — weapons self-poll.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Recoil impulse application | Weapon (MountableBody) | — | Physics call lives on the body receiving the force |
| Charge state & timer | Weapon script | — | Per-weapon, not global; avoids polluting world.gd |
| Fire dispatch (hold/tap) | Weapon script via `_physics_process` | world.gd FIRE action triggers check | World sends FIRE; weapon decides to queue vs fire based on charge |
| Homing steering | Bullet script (`_physics_process`) | — | Bullet applies own force; RPG weapon only provides target ref |
| RPG lock acquisition | Weapon script (`_process`) | — | Weapon scans cone each frame, no physics involved |
| Bounce reflection | Laser bullet script | — | Bullet detects own collision and spawns children |
| Spool state | Weapon script (`_physics_process`) | — | Rate lerp is per-weapon, not global |
| Muzzle flash | Weapon script (on fire) | Barrel CPUParticles2D | Flash lives in weapon scene |
| Bullet trail | Bullet script | Line2D child node | Trail updates each frame in bullet's `_process` |
| Impact FX | Bullet script (on collision) | Spawned CPUParticles2D one-shot | Bullet spawns effect at collision point |
| Screen shake | Camera script (`BodyCamera`) | Triggered by signal from weapon | Weapon emits signal; camera reacts |
| Weapon HUD | `WeaponHud` CanvasLayer | Queries active weapon state | Reads from mounted weapon each frame |
| RPG lock bracket UI | `WeaponHud` CanvasLayer | Converts target world→screen | Control node repositioned each frame |

---

## Standard Stack

### Core — Godot 4.2.1 Built-in APIs Used

| Node/API | Purpose | Notes |
|----------|---------|-------|
| `RigidBody2D.apply_central_impulse(impulse: Vector2)` | Recoil (no torque) | Confirmed in Godot docs [VERIFIED: Context7] |
| `RigidBody2D.apply_central_force(force: Vector2)` | Homing per-frame steering | Frame-rate independent via delta |
| `CharacterBody2D.move_and_collide(motion: Vector2)` | Laser bullet bounce | Returns `KinematicCollision2D` with `get_normal()` |
| `Vector2.bounce(normal: Vector2)` | Reflection vector calc | Built-in; angle of incidence = angle of reflection |
| `Vector2.reflect(normal: Vector2)` | Alternative reflection | Same math; `bounce` = negated `reflect` output |
| `Input.is_action_pressed(action)` | Hold-to-charge detection | Poll in `_physics_process` on weapon script |
| `CPUParticles2D` with `one_shot = true` | Muzzle flash, impact sparks, bounce flash | Set `emitting = true` to trigger once |
| `PointLight2D.energy` | Glow scaling during charge/spool | Tween or direct set in `_process` |
| `Camera2D.offset` | Screen shake | Tween to random offset then back to `Vector2.ZERO` |
| `Tween` (create_tween) | Animate offset, light energy, multiplier pulse | Already used in `score-hud.gd` |
| `Line2D` | Bullet trail | `add_point()` each frame; clear old points |
| `CanvasLayer` + `Control` | Weapon HUD | Extends existing `hud.gd` pattern |
| `get_viewport().get_canvas_transform()` | World→screen for RPG bracket | Converts world-space to CanvasLayer space |

### Existing Codebase Assets (Reuse, Don't Re-create)

| Asset | Location | Reuse For |
|-------|----------|-----------|
| `PointLight2D` already in GravityGun scene | `prefabs/gravitygun/gravitygun.tscn` | Established barrel-glow pattern |
| `CPUParticles2D` pattern | `propeller-movement.gd` (`emitting = true/false`) | One-shot pattern |
| `Tween` pulse loops | `beeliner.gd` (`set_loops(0)`) | Infinite glow pulse |
| `apply_central_impulse` | Used in `explosion.gd`, `mount-point.gd` | Correct pattern for center impulse |
| `GravityGun extends MountableWeapon` | `prefabs/gravitygun/gravitygun-script.gd` | Template for per-weapon override |
| `Explosion` `Area2D` + `get_overlapping_bodies()` | `components/explosion.gd` | GravityGun charge area scaling |
| `Timer` nodes created in `_ready()` | `components/mountable-weapon.gd` | Pattern for charge_timer, spool_timer |
| `score-hud.gd` CanvasLayer | `prefabs/ui/score-hud.gd` | HUD layout/animation reference |

---

## Architecture Patterns

### System Architecture Diagram

```
world.gd _process()
    │
    └──[KEY_SPACE pressed]──► notify_weapons(FIRE)
                                    │
                                    ▼
                          MountableBody.do(FIRE)
                                    │
                              MountPoint.do()
                                    │
                                    ▼
                          MountableWeapon.do(FIRE)
                                    │
                                    ▼
                    ┌─── weapon.fire() ──────────────────────┐
                    │                                         │
              [normal weapon]                     [charge weapon: Gausscannon/GravityGun]
                    │                                         │
              bullet spawned                   fire() checks charge_fraction
              immediately                      then scales damage/velocity
                    │                                         │
                    ▼                                         ▼
             Bullet._ready()                         bullet spawned with
          body_entered → collision()                 scaled impulse
                    │
         ┌──────────┴──────────┐
    [regular bullet]    [laser bullet]
         │                     │
      die() called       CharacterBody2D
                         move_and_collide()
                               │
                          bounce detected
                               │
                     spawn 2 child bullets
                     with decremented bounce_count
                               │
                          contact_flash() (CPUParticles2D)

Spool loop (Minigun):
_physics_process(delta):
    if fire held → spool_current = lerp(spool_current, 1.0, delta / spool_up_time)
    else         → spool_current = lerp(spool_current, 0.0, delta / spool_down_time)
    shot_timer.wait_time = lerp(rate_base, rate_max, spool_current)
    light.energy = lerp(light_min, light_max, spool_current)

RPG lock loop:
_process(delta):
    scan_cone() → find enemy in 30° cone within range
    lock_timer += delta → when >= 1.5s: locked = true
    bracket UI repositioned to target screen position

Charge loop (Gausscannon / GravityGun):
_physics_process(delta):
    if Input.is_action_pressed("ui_select"):
        charge_current = min(charge_current + delta, charge_max)
    else if was_charging:
        fire_charged()
        charge_current = 0.0
    light.energy = lerp(light_min, light_max, charge_current / charge_max)
```

### Recommended Per-Weapon Script Names

```
prefabs/
├── gausscannon/
│   └── gausscannon-weapon.gd   # NEW — extends MountableWeapon, holds charge logic
├── rpg/
│   └── rpg-weapon.gd           # NEW — extends MountableWeapon, holds lock-on logic
├── minigun/
│   └── minigun-weapon.gd       # NEW — extends MountableWeapon, holds spool logic
├── laser/
│   └── laser-weapon.gd         # NEW — extends MountableWeapon (optional, may not need override)
│   └── laser-bullet.gd         # MODIFY — change to CharacterBody2D, add bounce_count
prefabs/ui/
│   └── weapon-hud.tscn + weapon-hud.gd  # NEW — CanvasLayer, ammo/reload/charge
```

### Pattern 1: Recoil Bug Fix

**The bug** (line 47, `mountable-body.gd`):
```gdscript
var place = sender.global_position / 100
apply_impulse(vector, place)
```

**What Godot 4 docs say** about `apply_impulse(impulse, position)`:
> "position is the offset from the body origin in global coordinates."
[VERIFIED: Context7 / godot-docs class_rigidbody2d.md]

This means `position` is an offset vector whose axes align with the global axes, but whose origin is the body's center. So `sender.global_position / 100` is passing a tiny displacement in world-space direction from the ship's center — not a meaningful offset. The division by 100 was likely an attempt to scale it down, but any non-zero value here creates off-center torque.

**Fix option A — simplest, no torque:**
```gdscript
# mountable-body.gd line 44-47
if action == Action.RECOIL:
    var vector = -Vector2.from_angle(sender.global_rotation) * meta
    apply_central_impulse(vector)
```
[VERIFIED: Context7 — apply_central_impulse = apply_impulse at body's center of mass]

**Fix option B — torque at weapon mount point:**
```gdscript
if action == Action.RECOIL:
    var vector = -Vector2.from_angle(sender.global_rotation) * meta
    # Convert weapon world position to offset from ship's center
    var offset = sender.global_position - global_position
    apply_impulse(vector, offset)
```

D-01 says "Fix the root cause." Option A (`apply_central_impulse`) matches the intent of D-02 (direction is correct, only application point is wrong). **Use Option A.**

### Pattern 2: Hold-to-Charge (Gausscannon / GravityGun)

Charge logic lives entirely in the weapon script. World.gd sends FIRE normally; the weapon intercepts it.

```gdscript
# gausscannon-weapon.gd
class_name GausscannonWeapon
extends MountableWeapon

const CHARGE_MAX: float = 2.0

@export var light: PointLight2D
@export var sparks: CPUParticles2D

var charge_current: float = 0.0
var _was_charging: bool = false
var _light_base: float = 0.3
var _light_max: float = 4.0

func _physics_process(delta: float) -> void:
    var firing = Input.is_action_pressed("ui_select")  # KEY_SPACE mapped to ui_select

    if firing and can_shoot():
        charge_current = min(charge_current + delta, CHARGE_MAX)
        _was_charging = true
        if light:
            light.energy = lerp(_light_base, _light_max, charge_current / CHARGE_MAX)
        if charge_current >= CHARGE_MAX and sparks and not sparks.emitting:
            sparks.one_shot = false
            sparks.emitting = true  # continuous at full charge

    elif _was_charging:
        _was_charging = false
        if sparks:
            sparks.emitting = false
        _fire_charged()
        charge_current = 0.0
        if light:
            light.energy = _light_base

func _fire_charged() -> void:
    if not can_shoot():
        return
    var fraction: float = charge_current / CHARGE_MAX
    # Scale projectile velocity
    var scaled_velocity = velocity * lerp(0.5, 1.0, fraction)
    # Scale recoil sent upstream
    var scaled_recoil = recoil * lerp(0.3, 1.0, fraction)
    # Spawn bullet with scaled velocity (override base fire())
    _spawn_bullet(scaled_velocity)
    # Trigger recoil manually
    var mount = get_mount("")
    if mount:
        mount.do(self, Action.RECOIL, scaled_recoil)

func do(_sender: Node2D, action: MountableBody.Action, _where: String, _meta = null):
    # Intercept FIRE — do NOT call super fire() here; charge handles it
    if action == MountableBody.Action.RELOAD:
        reload()
    if action == MountableBody.Action.GODMODE:
        use_ammo = false
        use_rate = false
```

**Key insight:** world.gd sends FIRE every frame KEY_SPACE is held. Do NOT call `super.do(FIRE)` in the charge weapon's `do()` — the weapon self-manages firing via `_physics_process` polling.

**GravityGun charging** follows identical pattern with `CHARGE_MAX = 1.5` and scales `strength` and `area.scale`.

### Pattern 3: Homing Bullet (RPG)

Two steps: (a) lock acquisition on the weapon, (b) per-frame steering on the bullet.

**Lock acquisition in `rpg-weapon.gd`:**
```gdscript
const LOCK_TIME: float = 1.5
const CONE_ANGLE: float = PI / 6.0  # 30 degrees half-angle
const LOCK_RANGE: float = 3000.0

var _lock_target: Node2D = null
var _lock_progress: float = 0.0  # 0.0 to 1.0
var locked: bool = false

func _process(delta: float) -> void:
    _update_lock(delta)

func _update_lock(delta: float) -> void:
    if _lock_target and not is_instance_valid(_lock_target):
        _clear_lock()
        return

    # Scan for best target in cone
    var candidate = _scan_cone()

    if candidate == null:
        _lock_progress = max(0.0, _lock_progress - delta * 2.0)  # fade out
        if _lock_progress <= 0.0:
            _clear_lock()
        return

    if candidate != _lock_target:
        _lock_target = candidate
        _lock_progress = 0.0
        locked = false

    _lock_progress = min(_lock_progress + delta / LOCK_TIME, 1.0)
    locked = _lock_progress >= 1.0

func _scan_cone() -> Node2D:
    var enemies = get_tree().get_nodes_in_group("enemy")
    var best: Node2D = null
    var best_dist: float = LOCK_RANGE

    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var dir_to_enemy = (enemy.global_position - barrel.global_position).normalized()
        var forward = Vector2.from_angle(global_rotation)
        var angle = forward.angle_to(dir_to_enemy)
        var dist = global_position.distance_to(enemy.global_position)

        if abs(angle) <= CONE_ANGLE and dist <= best_dist:
            best = enemy
            best_dist = dist

    return best

func _clear_lock() -> void:
    _lock_target = null
    _lock_progress = 0.0
    locked = false
```

**Homing bullet per-frame steering (`rpg-bullet.gd` or `bullet.gd` subclass):**
```gdscript
# rpg-bullet.gd — extends Body (which extends RigidBody2D)
var target: Node2D = null
const TURN_FORCE: float = 50000.0

func _physics_process(delta: float) -> void:
    if not target or not is_instance_valid(target):
        return
    var dir = (target.global_position - global_position).normalized()
    apply_central_force(dir * TURN_FORCE)
```

**Passing target to bullet in `rpg-weapon.gd.fire()`:**
```gdscript
func fire() -> void:
    super()  # spawns bullet normally
    # Get the just-spawned bullet (last child of spawn_parent)
    if locked and _lock_target:
        # Set target on bullet after spawn
        var bullets = spawn_parent.get_children()
        var bullet = bullets[bullets.size() - 1]
        if bullet.has_method("set_target"):
            bullet.set_target(_lock_target)
```

**Better approach:** Override `fire()` completely to spawn bullet then set target directly on instance before `add_child`.

### Pattern 4: Laser Bullet Bounce

**Core constraint:** `RigidBody2D.body_entered` signal does NOT provide collision normal.
[VERIFIED: Context7 — signal only provides the colliding body reference]

**Solution: Change laser bullet from `RigidBody2D`/`Body` to `CharacterBody2D`.**

This is the only Godot-correct approach to get collision normals without a physics server query. The Godot docs explicitly use this for bouncing projectiles. [VERIFIED: Context7 — using_character_body_2d.md bounce example]

```gdscript
# laser-bullet.gd (reclassed from Body/RigidBody2D to CharacterBody2D)
class_name LaserBullet
extends CharacterBody2D

@export var attack: Damage
@export var speed: float = 20000.0
@export var max_bounces: int = 3
@export var spread_angle: float = 0.15  # radians, Claude's discretion

var bounce_count: int = 0
var _bounce_flash: PackedScene  # preload CPUParticles2D one-shot scene

func _ready() -> void:
    # life timer — die after 2s regardless
    var t = get_tree().create_timer(2.0)
    t.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
    var collision = move_and_collide(velocity * delta)
    if collision:
        _on_impact(collision)

func _on_impact(collision: KinematicCollision2D) -> void:
    var hit_body = collision.get_collider()

    # Deal damage
    if hit_body is Body:
        hit_body.damage(attack)

    # Spawn green flash at contact point
    _spawn_flash(collision.get_position())

    if bounce_count >= max_bounces:
        queue_free()
        return

    # Reflect velocity
    var normal = collision.get_normal()
    var reflected = velocity.bounce(normal)

    # Spawn 2 child bullets
    for i in range(2):
        var spread = randf_range(-spread_angle, spread_angle)
        _spawn_child_bullet(reflected.rotated(spread))

    queue_free()  # original bullet dies; children continue

func _spawn_child_bullet(new_velocity: Vector2) -> void:
    var child = duplicate()  # inherits same scene
    child.velocity = new_velocity
    child.bounce_count = bounce_count + 1
    child.global_position = global_position
    if spawn_parent:
        spawn_parent.call_deferred("add_child", child)
```

**Collision layer note:** Laser bullets (layer 3) already collide with layer 1 (ships), 2 (weapons), 4 (asteroids). Verify collision_mask includes all bounce targets.

**Why not RigidBody2D with RayCast2D?** A raycast fires in one direction; `move_and_collide` handles the full swept collision correctly and is the established Godot pattern.

### Pattern 5: Minigun Spool

Spool is a continuous lerp, not stepped. Rate decreasing means faster firing.

```gdscript
# minigun-weapon.gd
class_name MinigunWeapon
extends MountableWeapon

const SPOOL_UP_TIME: float = 2.0
const SPOOL_DOWN_TIME: float = 0.5
const DAMAGE_MAX_MULTIPLIER: float = 1.5

@export var light: PointLight2D
@export var sparks: CPUParticles2D

var spool: float = 0.0  # 0.0 = idle, 1.0 = full speed
var _rate_min: float  # set from rate in _ready
var _rate_max: float  # fastest rate at full spool

func _ready() -> void:
    super()
    _rate_min = rate         # base rate (slow)
    _rate_max = rate * 0.2   # 5× faster at full spool (Claude's discretion)

func _physics_process(delta: float) -> void:
    var firing = Input.is_action_pressed("ui_select")

    if firing:
        spool = min(spool + delta / SPOOL_UP_TIME, 1.0)
    else:
        spool = max(spool - delta / SPOOL_DOWN_TIME, 0.0)

    # Update fire rate (lower wait_time = faster fire)
    shot_timer.wait_time = lerp(_rate_min, _rate_max, spool)

    # Glow scales with spool
    if light:
        light.energy = lerp(0.0, 3.0, spool)
    if sparks:
        sparks.emission_sphere_radius = lerp(0.0, 20.0, spool)
        sparks.emitting = spool > 0.05

func get_attack_multiplier() -> float:
    return lerp(1.0, DAMAGE_MAX_MULTIPLIER, spool)
```

**Damage scaling:** Override bullet damage in `fire()`. Since damage lives in the bullet resource (`.tres`), scale it at fire time by duplicating and modifying, or passing multiplier to bullet.

**Spool persistence between short gaps** (Claude's discretion): Use `spool > 0.0` rather than resetting on exact key-up — natural given the lerp approach.

### Pattern 6: Muzzle Flash / Impact FX

**Muzzle flash** — add a `CPUParticles2D` node named `MuzzleFlash` as a child of `Barrel` in each weapon scene:
```gdscript
# In weapon fire() after bullet spawns:
if muzzle_flash:
    muzzle_flash.restart()  # restarts one-shot emission
    muzzle_flash.emitting = true
```

`CPUParticles2D` config: `one_shot = true`, `lifetime = 0.15`, `amount = 8`, `explosiveness = 0.9`.

**Impact FX** — spawn a one-shot CPUParticles2D scene at bullet's collision position:
```gdscript
# In bullet collision():
func _spawn_impact(pos: Vector2) -> void:
    var fx = impact_scene.instantiate()
    fx.global_position = pos
    if spawn_parent:
        spawn_parent.call_deferred("add_child", fx)
        # fx auto-frees after emitting (one_shot = true, queue_free in _ready after timer)
```

**Bullet trail** — `Line2D` child on the bullet scene, append `global_position` each `_process` frame, keep last N points:
```gdscript
func _process(_delta: float) -> void:
    trail.add_point(to_local(global_position))
    if trail.get_point_count() > 12:
        trail.remove_point(0)
```
Note: since bullet moves each physics frame, use `global_position` and convert to Line2D local space.

### Pattern 7: Screen Shake

Add `shake(duration, magnitude)` to `BodyCamera`:
```gdscript
# body_camera.gd addition
func shake(duration: float, magnitude: float) -> void:
    var tween = create_tween()
    var steps = int(duration * 30)
    for i in range(steps):
        var rand_offset = Vector2(
            randf_range(-magnitude, magnitude),
            randf_range(-magnitude, magnitude)
        )
        tween.tween_property(self, "offset", rand_offset, duration / steps)
    tween.tween_property(self, "offset", Vector2.ZERO, 0.05)
```

Trigger from weapon via signal. Weapon emits `fired_heavy`; world.gd or `BodyCamera` connects it.

[VERIFIED: Context7 — Camera2D.offset property used for shake]

### Pattern 8: RPG Lock Bracket HUD

The lock bracket is a `Control` node inside the `WeaponHud` CanvasLayer. Each frame, convert the RPG weapon's locked target world position to screen position:

```gdscript
# weapon-hud.gd _process():
if rpg_weapon and rpg_weapon.lock_target:
    var cam = get_viewport().get_camera_2d()
    if cam:
        # World to viewport position
        var world_pos = rpg_weapon.lock_target.global_position
        var screen_pos = get_viewport().get_canvas_transform() * world_pos
        lock_bracket.position = screen_pos - lock_bracket.size / 2
        lock_bracket.visible = true

        # Animate bracket size shrinking as lock_progress → 1.0
        var progress = rpg_weapon.lock_progress
        var bracket_size = lerp(120.0, 30.0, progress)
        lock_bracket.custom_minimum_size = Vector2(bracket_size, bracket_size)
    else:
        lock_bracket.visible = false
```

**Bracket visual:** Two concentric `NinePatchRect` or `Panel` Control nodes styled red. Or draw in `_draw()` using `draw_rect` with `filled = false` for two rectangles.

[VERIFIED: Context7 — `get_viewport().get_canvas_transform()` for 2D world→screen]

### Pattern 9: Weapon HUD Structure

```
WeaponHud (CanvasLayer, layer = 2)
└── Panel (anchored bottom-center)
    └── VBoxContainer
        ├── WeaponNameLabel (Label)
        ├── AmmoLabel ("12 / 48")
        ├── ReloadBar (ProgressBar, hidden unless reloading)
        └── ChargeBar (ProgressBar, hidden unless charge weapon / spool)

LockBracket (Control, position set dynamically, hidden by default)
    ├── OuterRect (Panel, red border)
    └── InnerRect (Panel, red border, smaller)
```

In `_process()`:
```gdscript
func _process(_delta: float) -> void:
    var weapon = _get_active_weapon()
    if not weapon:
        return

    ammo_label.text = "%d / %d" % [weapon.magazine_current, weapon.ammo_current]
    weapon_name_label.text = weapon.name

    reload_bar.visible = weapon.is_reloading()
    if weapon.is_reloading():
        var elapsed = weapon.reload_time - weapon.reload_timer.time_left
        reload_bar.value = elapsed / weapon.reload_time

    # Charge/spool bar
    if weapon.has_method("get_charge_fraction"):
        charge_bar.visible = true
        charge_bar.value = weapon.get_charge_fraction()
    elif weapon.has_method("get_spool"):
        charge_bar.visible = true
        charge_bar.value = weapon.spool
    else:
        charge_bar.visible = false
```

### Anti-Patterns to Avoid

- **Polling `body_entered` for bounce normal:** RigidBody2D signal does not return collision normal — attempting to calculate normal from positions post-collision is inaccurate. Use `CharacterBody2D.move_and_collide()`.
- **Setting `linear_velocity` directly every frame on RigidBody2D:** Fights the physics engine. Use `apply_central_force()` for homing.
- **Passing world coordinates to `apply_impulse` position:** The position parameter is an offset from body origin (global-axis-aligned). Pass `sender.global_position - global_position` not `sender.global_position`.
- **One CPUParticles2D for all weapons:** Each weapon needs its own `MuzzleFlash` node so particles inherit the barrel's position/rotation.
- **Charge logic in world.gd:** Would require world to know weapon types. Keep it in weapon scripts.
- **Recursive bullet spawning without bounce counter:** Without `max_bounces` decrement, one laser bullet spawns infinite bullets. Always decrement before spawning children.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reflection vector | Custom angle math | `Vector2.bounce(normal)` | Built-in; handles edge cases |
| World→screen position | Manual matrix math | `get_viewport().get_canvas_transform() * world_pos` | Engine transform chain |
| Collision normal for bounce | Raycasting + position delta | `CharacterBody2D.move_and_collide()` → `.get_normal()` | Only correct way for swept collision |
| Camera shake | Sinusoidal offset function | `Camera2D.offset` + `Tween` | Tween already used in project |
| Particle one-shot | Manual timer + queue_free | `CPUParticles2D.one_shot = true` + `restart()` | Built-in; handles lifetime |
| Tween for light pulsing | Custom float lerp in `_process` | `create_tween().set_loops(0)` | Already in project (beeliner.gd) |

---

## Common Pitfalls

### Pitfall 1: `apply_impulse` offset confusion

**What goes wrong:** Passing `sender.global_position` as the position argument makes the ship spin unpredictably. The position is NOT a world coordinate — it is an offset vector from the body's center, using global (non-rotated) axes.
**Why it happens:** The Godot 4 docs say "offset from body origin in global coordinates" — "global coordinates" means the axes are world-aligned, not that it's a world position.
**How to avoid:** For pure directional recoil, always use `apply_central_impulse`.
**Warning signs:** Ship spins or drifts sideways when recoil fires.

### Pitfall 2: RigidBody2D body_entered has no collision normal

**What goes wrong:** Attempting to calculate a bounce direction from a `body_entered` signal. The signal only provides the colliding body, not the collision point or normal.
**Why it happens:** `body_entered` is a simple overlap notification, not a collision report.
**How to avoid:** Use `CharacterBody2D` + `move_and_collide()` for any projectile that needs to bounce.
**Warning signs:** Bullets pass through walls on bounce, or bounce in wrong direction.

### Pitfall 3: Charge weapon fires on FIRE action from world.gd

**What goes wrong:** If the weapon's `do()` calls `super()` for the FIRE action, the base `MountableWeapon.fire()` executes immediately on first KEY_SPACE press, bypassing charge.
**Why it happens:** The do() dispatch calls `fire()` immediately without checking charge state.
**How to avoid:** Override `do()` in the charge weapon and do NOT call `super()` for FIRE. Let `_physics_process` handle firing via release detection.
**Warning signs:** Gausscannon/GravityGun fire instantly without charging.

### Pitfall 4: Laser bullet collision layer not covering all bounce surfaces

**What goes wrong:** Bounced bullets pass through ships or asteroids because collision masks are inherited but not correct on spawned child bullets.
**Why it happens:** `duplicate()` copies the scene but collision layers may be unset or mis-set.
**How to avoid:** Explicitly set `collision_layer` and `collision_mask` in `_ready()` of the laser bullet script.
**Warning signs:** Laser passes through certain physics bodies but bounces off others.

### Pitfall 5: Minigun spool rate goes to zero wait_time

**What goes wrong:** If `_rate_max` is set to 0 or a very small value, the shot timer fires every frame, overwhelming the physics engine.
**Why it happens:** `shot_timer.wait_time = 0` means "fire as fast as possible" — no cooldown.
**How to avoid:** Clamp `_rate_max` to a reasonable minimum (e.g., `0.01` seconds = 100 rounds/sec max).
**Warning signs:** Extreme frame drops when firing minigun at full spool.

### Pitfall 6: Bullet trail Line2D position accumulation drift

**What goes wrong:** Trail points drift in world space because Line2D is a child of the bullet and its `add_point` uses local space.
**Why it happens:** Bullet's position changes each frame; `to_local(global_position)` would always be `Vector2.ZERO`.
**How to avoid:** Either keep Line2D NOT as a child (make it a spawn_parent child and pass position), OR set the trail points in global space by setting the Line2D's `global_transform` to identity first. Simplest: place fixed-length trail as a `Line2D` in local space with hardcoded points along the -X axis (behind the bullet).
**Warning signs:** Trail spirals or appears at wrong positions.

### Pitfall 7: RPG lock target reference goes stale

**What goes wrong:** `_lock_target` reference is not checked with `is_instance_valid()` before accessing. When target dies, `_lock_target` still holds a freed instance, causing errors.
**Why it happens:** Godot does not auto-null custom variables when a node is freed (only `@onready` and weakrefs).
**How to avoid:** Always check `is_instance_valid(_lock_target)` before accessing target position. Clear lock on invalid.
**Warning signs:** "Invalid get index on freed object" errors when enemies die during lock.

---

## Code Examples

### Verified: apply_impulse position semantics
Source: Godot docs (Context7 / godot-docs class_rigidbody2d.md)
```gdscript
# apply_impulse(impulse: Vector2, position: Vector2 = Vector2(0, 0))
# position = offset from body's center of mass, in GLOBAL axes (not rotated by body)
# Example: apply recoil with no torque:
apply_central_impulse(-Vector2.from_angle(sender.global_rotation) * recoil_magnitude)

# Example: apply recoil at weapon mount offset (creates intentional torque):
var offset = sender.global_position - global_position  # world-space offset from ship center
apply_impulse(-Vector2.from_angle(sender.global_rotation) * recoil_magnitude, offset)
```

### Verified: bounce reflection
Source: Context7 / godot-docs tutorials/physics/using_character_body_2d.md
```gdscript
func _physics_process(delta: float) -> void:
    var collision = move_and_collide(velocity * delta)
    if collision:
        velocity = velocity.bounce(collision.get_normal())
        # collision.get_collider() returns the hit body
        # collision.get_position() returns the contact point
```

### Verified: CPUParticles2D one-shot trigger
Source: Context7 / godot-docs classes/class_cpuparticles2d.md
```gdscript
# Setup (in _ready or scene):
muzzle_flash.one_shot = true
muzzle_flash.emitting = false

# Trigger on fire:
func _trigger_muzzle_flash() -> void:
    muzzle_flash.restart()  # resets and re-emits
```

### Verified: Camera2D shake via offset + Tween
Source: Context7 / godot-docs classes/class_camera2d.md
```gdscript
func shake(magnitude: float = 8.0, duration: float = 0.3) -> void:
    var tween = create_tween()
    for _i in range(6):
        tween.tween_property(self, "offset",
            Vector2(randf_range(-magnitude, magnitude),
                    randf_range(-magnitude, magnitude)),
            duration / 6.0)
    tween.tween_property(self, "offset", Vector2.ZERO, 0.05)
```

### Verified: World to screen position (2D)
Source: Context7 / godot-docs tutorials/2d/2d_transforms.md
```gdscript
# Convert world position to screen/CanvasLayer position:
var canvas_pos = get_viewport().get_canvas_transform() * target.global_position
lock_bracket_control.position = canvas_pos
```

### Verified: Input hold detection
Source: Context7 / godot-docs tutorials/inputs/input_examples.md
```gdscript
func _physics_process(delta: float) -> void:
    if Input.is_action_pressed("ui_select"):  # KEY_SPACE default mapping
        charge_current += delta
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `apply_impulse(v, global_pos)` for recoil | `apply_central_impulse(v)` or correct offset | Always Godot 4 | Eliminates unintended torque |
| Manual reflection math | `Vector2.bounce(normal)` | Godot 4+ | Single line, correct edge cases |
| RigidBody2D for bouncing bullets | CharacterBody2D + move_and_collide | Godot 4 | Only way to get collision normal |
| Setting `linear_velocity` directly in homing | `apply_central_force()` per frame | Always physics best practice | Respects physics integration |

**Deprecated/outdated (Godot 3 patterns to avoid):**
- `KinematicBody2D` → replaced by `CharacterBody2D` in Godot 4
- `move_and_slide_with_snap` → removed in Godot 4
- `yield()` → use `await` in Godot 4

---

## Balance Pass Data

### Enemy HP Values (verified from `.tscn` files)
[VERIFIED: direct file read]

| Enemy | max_health | Notes |
|-------|------------|-------|
| Swarmer | 30 | Fast, numerous |
| Suicider | 40 | Rushes player |
| Beeliner | 60 | Mid-range, spread shots |
| Flanker | 80 | Flanking maneuver |
| Sniper | 100 | Long range, high HP |

### Current Weapon Damage (verified from `.tscn`/`.tres` files)
[VERIFIED: direct file read]

| Weapon | Damage (energy+kinetic) | Rate | Notes |
|--------|------------------------|------|-------|
| Minigun | 10 kinetic per bullet | 0.02s | 50 shots/sec; ~500 DPS |
| Gausscannon | 200E + 500K = 700 per shot | 0.5s | 1400 DPS |
| RPG | 100K direct + 3000K explosion | 2.0s | Very high burst |
| Laser | 100E per bullet | 0.1s | 1000 DPS |
| GravityGun | 500K area | 2.0s | Area effect |

### Recommended Balance Numbers (Claude's Discretion)
[ASSUMED — needs tuning playtest; these are starting suggestions]

The v3.0 buff doubled enemy HP. Weapons need ~1.5–2× effective DPS. Recommended adjustments:

| Weapon | Change | Rationale |
|--------|--------|-----------|
| Minigun base | No change; spool mechanic adds 50% at max | Spool is the buff |
| Gausscannon base | Add 50E (total 250E+500K), charge multiplies 1×-3× | Charge rewards skill |
| RPG | Direct hit: 200K; explosion: 4000K area | Homing justifies slow rate |
| Laser | 150E per bullet; bounces multiply | Bounce chains are the DPS multiplier |
| GravityGun | Charge multiplies base 1×-2.5× (force + area) | Charged is primary use case |

---

## Open Questions

1. **Charge weapon and world.gd FIRE key conflict**
   - What we know: `world.gd` sends FIRE every frame in `_process` when KEY_SPACE is held. Charge weapons must not fire on receipt of FIRE action.
   - What's unclear: Should weapons suppress FIRE entirely, or should charge accumulate AND a quick-tap fire at minimum charge?
   - Recommendation: D-07 says "quick tap = base stats." So `do(FIRE)` from world.gd should start charging. On key release, weapon fires. The weapon's `do()` override ignores FIRE (doesn't call super) and lets `_physics_process` detect hold via `is_action_pressed`.

2. **Laser bullet as CharacterBody2D — Body compatibility**
   - What we know: `Bullet` extends `Body` extends `RigidBody2D`. `CharacterBody2D` is a different branch of `PhysicsBody2D`.
   - What's unclear: Whether `LaserBullet` needs to fully reimplement `Body`'s health/die logic.
   - Recommendation: `LaserBullet` does not need health — bullets don't take damage. Implement `die()` and `damage()` directly. Or create a minimal base class for laser bullet.

3. **Multiple active weapons and HUD**
   - What we know: Player can have 3 weapons mounted (front, left, right). HUD shows "active weapon."
   - What's unclear: Which weapon is "active" — the one most recently fired, or always front?
   - Recommendation: Show the front mount (`""`) weapon by default. This matches the existing `weapon_front` debug display in `hud.gd`.

---

## Environment Availability

Step 2.6: SKIPPED — phase is code-only modifications to existing GDScript files and scenes within Godot 4. No external CLI tools, services, or runtimes beyond the Godot editor are required.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Minigun `rate_max = rate * 0.2` (5× speed) is a good starting value | Balance Pass / Minigun spool | Rate may be too fast or too slow; tunable |
| A2 | RPG LOCK_RANGE = 3000.0 is appropriate | RPG Lock pattern | Range may be too short/long for gameplay; tunable |
| A3 | Laser bounce spread = 0.15 radians (~8.6°) | Laser Bounce pattern | May need tighter/wider; tunable |
| A4 | Screen shake magnitude=8, duration=0.3 for heavy weapons | Screen Shake pattern | May feel too strong/weak; tunable |
| A5 | Recommended balance numbers (Gausscannon 250E+500K etc.) | Balance Pass section | Requires playtest to confirm |
| A6 | `is_action_pressed("ui_select")` maps to KEY_SPACE | Charge pattern | Depends on Input Map; verify in project settings |

---

## Sources

### Primary (HIGH confidence)
- `/godotengine/godot-docs` (Context7) — `apply_impulse`, `apply_central_impulse`, `Vector2.bounce`, `CharacterBody2D.move_and_collide`, `CPUParticles2D.one_shot`, `Camera2D.offset`, `Input.is_action_pressed`, `get_viewport().get_canvas_transform()`
- Direct codebase reads — `mountable-body.gd`, `mountable-weapon.gd`, `bullet.gd`, `gravitygun-script.gd`, `explosion.gd`, `hud.gd`, `score-hud.gd`, `world.gd`, all weapon `.tscn` files, all enemy `.tscn` files

### Secondary (MEDIUM confidence)
- Godot Forum discussion on `apply_impulse` position semantics — confirmed "local space offset with global axis orientation" interpretation
- WebSearch on `apply_impulse` behavior — confirmed long-standing community confusion; no Godot-4-specific breaking change

### Tertiary (LOW confidence — see Assumptions Log)
- Balance numbers: all marked [ASSUMED] — based on ratio analysis of existing damage vs HP values

---

## Metadata

**Confidence breakdown:**
- Recoil fix: HIGH — API confirmed in docs, bug site confirmed in codebase
- Bounce approach: HIGH — CharacterBody2D/move_and_collide is the Godot-documented pattern
- Charge pattern: HIGH — `Input.is_action_pressed` + `_physics_process` is standard Godot 4
- Homing: HIGH — `apply_central_force` per frame confirmed correct for RigidBody2D
- HUD world→screen: HIGH — canvas_transform pattern confirmed in docs
- Minigun spool: HIGH — lerp in _physics_process is straightforward
- Balance numbers: LOW — requires playtest

**Research date:** 2026-04-18
**Valid until:** 2026-05-18 (Godot 4.2.1 APIs are stable; no breaking changes expected before 4.6 migration)
