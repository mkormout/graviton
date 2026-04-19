# Phase 18: Weapons Improvements - Pattern Map

**Mapped:** 2026-04-19
**Files analyzed:** 11 new/modified files
**Analogs found:** 11 / 11

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `components/mountable-body.gd` | physics-body | request-response | self (modify line 44–47) | exact |
| `prefabs/gausscannon/gausscannon-weapon.gd` | weapon-script | event-driven | `prefabs/gravitygun/gravitygun-script.gd` | exact |
| `prefabs/rpg/rpg-weapon.gd` | weapon-script | event-driven | `prefabs/gravitygun/gravitygun-script.gd` | role-match |
| `prefabs/minigun/minigun-weapon.gd` | weapon-script | event-driven | `prefabs/gravitygun/gravitygun-script.gd` | role-match |
| `prefabs/laser/laser-weapon.gd` | weapon-script | event-driven | `prefabs/gravitygun/gravitygun-script.gd` | role-match |
| `prefabs/laser/laser-bullet.gd` | bullet-script | request-response | `components/bullet.gd` | role-match |
| `components/body_camera.gd` | camera | event-driven | self (add shake method) | exact |
| `prefabs/ui/weapon-hud.gd` | HUD controller | request-response | `prefabs/ui/wave-hud.gd` | role-match |
| `prefabs/ui/weapon-hud.tscn` | HUD scene | — | `prefabs/ui/wave-hud.tscn` | role-match |
| All weapon `.tscn` scenes (5) | weapon-scene | — | each weapon's existing `.tscn` | exact (add child nodes) |
| `world.gd` | entry-point | event-driven | self (integrate weapon-hud) | exact |

---

## Pattern Assignments

### `components/mountable-body.gd` (bug fix — recoil)

**Analog:** self (one-line change)

**Bug site** (lines 44–47):
```gdscript
if action == Action.RECOIL:
    var vector = -Vector2.from_angle(sender.global_rotation) * meta
    var place = sender.global_position / 100  # BUG: near-zero world coord passed as offset
    apply_impulse(vector, place)
```

**Fixed pattern** — replace the two bug lines with:
```gdscript
if action == Action.RECOIL:
    var vector = -Vector2.from_angle(sender.global_rotation) * meta
    apply_central_impulse(vector)
```

`apply_central_impulse` is already used in `explosion.gd` line 98 and `components/mountable-weapon.gd` line 110 — it is the established project pattern for impulse without torque.

---

### `prefabs/gausscannon/gausscannon-weapon.gd` (weapon-script, event-driven)

**Analog:** `prefabs/gravitygun/gravitygun-script.gd`

**Class declaration pattern** (gravitygun-script.gd lines 1–8):
```gdscript
class_name GravityGun
extends MountableWeapon

@export var area: Area2D
@export var strength: int = 20000
@export var torque: int = 2000000
@export var attack: Damage
```
Copy pattern: `class_name GausscannonWeapon` / `extends MountableWeapon` / `@export` nodes before vars.

**do() override pattern** (gravitygun-script.gd does NOT override do() — it overrides fire()):
```gdscript
# From mountable-weapon.gd lines 79–95 — the do() to override:
func do(_sender: Node2D, action: MountableBody.Action, _where: String, _meta = null):
    if action == MountableBody.Action.FIRE:
        fire()
    if action == MountableBody.Action.RELOAD:
        reload()
    if action == MountableBody.Action.GODMODE:
        use_ammo = false
        use_rate = false
```
For charge weapons: override do() and do NOT call `super()` for FIRE. Only pass through RELOAD and GODMODE.

**Timer creation in _ready() pattern** (mountable-weapon.gd lines 29–38):
```gdscript
func _ready() -> void:
    shot_timer = Timer.new()
    shot_timer.wait_time = rate
    shot_timer.one_shot = true
    add_child(shot_timer)
    reload_timer = Timer.new()
    reload_timer.wait_time = reload_time
    reload_timer.one_shot = true
    add_child(reload_timer)
```
Add `charge_timer` or track charge as a float var — same pattern: create Timer in `_ready()`, `add_child`.

**Bullet spawn pattern** (mountable-weapon.gd lines 106–118):
```gdscript
if can_shoot():
    var instance = ammo.instantiate() as RigidBody2D
    instance.position = barrel.global_position
    instance.rotation = global_rotation
    instance.apply_central_impulse(
        Vector2.from_angle(
            global_rotation + randf_range(-spread, spread)
        ) * velocity,
    )
    if "spawn_parent" in instance:
        instance.spawn_parent = spawn_parent
    if spawn_parent:
        spawn_parent.call_deferred("add_child", instance)
```
For charged fire: scale `velocity` by charge fraction before passing to `apply_central_impulse`.

**CPUParticles2D one-shot pattern** (propeller-movement.gd lines 14–15):
```gdscript
if particles:
    particles.emitting = active
```
For sparks at full charge: set `sparks.one_shot = false` and `sparks.emitting = true` when `charge_current >= CHARGE_MAX`.

**PointLight2D scaling pattern** (propeller-movement.gd lines 17–18):
```gdscript
if light:
    light.enabled = active
```
Extend to energy scaling: `light.energy = lerp(_light_base, _light_max, charge_current / CHARGE_MAX)`.

**Recoil dispatch pattern** (mountable-weapon.gd lines 131–133):
```gdscript
var mount = get_mount("")
if mount:
    mount.do(self, Action.RECOIL, recoil)
```
For charged recoil: replace `recoil` with `recoil * lerp(0.3, 1.0, charge_fraction)`.

---

### `prefabs/rpg/rpg-weapon.gd` (weapon-script, event-driven)

**Analog:** `prefabs/gravitygun/gravitygun-script.gd` (extends MountableWeapon, overrides fire())

**fire() override pattern** (gravitygun-script.gd lines 9–19):
```gdscript
func fire():
    if not can_shoot():
        return
    super()
    apply_damage()
    await get_tree().create_timer(0.1).timeout
    apply_kickback()
```
RPG override: call `super()` which spawns the bullet, then retrieve the spawned bullet and set `target` on it if locked.

**Area2D / get_tree().get_nodes_in_group pattern** (gravitygun-script.gd lines 22–34):
```gdscript
func apply_kickback():
    var bodies = area.get_overlapping_bodies()
    for item in bodies:
        if not item is RigidBody2D:
            continue
        var body = item as RigidBody2D
        var direction = (body.global_position - global_position).normalized()
```
RPG lock scan: use `get_tree().get_nodes_in_group("enemy")` instead of `area.get_overlapping_bodies()`. Same direction/distance math.

**Instance validity check** — always guard after async or _process:
```gdscript
# Not in current code but required — pattern from RESEARCH.md
if not is_instance_valid(_lock_target):
    _clear_lock()
    return
```

**spawn_parent.call_deferred pattern** (mountable-weapon.gd lines 118):
```gdscript
spawn_parent.call_deferred("add_child", instance)
```
After bullet spawns via super.fire(), get last child of spawn_parent: `var bullet = spawn_parent.get_children().back()` then `bullet.set_target(_lock_target)`.

---

### `prefabs/minigun/minigun-weapon.gd` (weapon-script, event-driven)

**Analog:** `prefabs/gravitygun/gravitygun-script.gd`

**Class + export pattern** (gravitygun-script.gd lines 1–7):
```gdscript
class_name GravityGun
extends MountableWeapon

@export var area: Area2D
@export var strength: int = 20000
```
Minigun: `class_name MinigunWeapon` / `extends MountableWeapon` / `@export var light: PointLight2D` / `@export var sparks: CPUParticles2D`.

**Input.is_action_pressed polling pattern** (propeller-movement.gd lines 12–13):
```gdscript
func _physics_process(delta):
    var active = Input.is_action_pressed(action)
```
Minigun spool: `var firing = Input.is_action_pressed("ui_select")` in `_physics_process(delta)`.

**shot_timer.wait_time mutation** — rate is the `wait_time` of shot_timer (mountable-weapon.gd lines 30–32):
```gdscript
shot_timer = Timer.new()
shot_timer.wait_time = rate
shot_timer.one_shot = true
```
Spool: set `shot_timer.wait_time = lerp(_rate_min, _rate_max, spool)` each physics frame. Cache `_rate_min = rate` in `_ready()` after `super()`.

**PointLight2D / CPUParticles2D per-frame scale** (propeller-movement.gd lines 14–18):
```gdscript
if particles:
    particles.emitting = active
if light:
    light.enabled = active
```
Minigun: `light.energy = lerp(0.0, 3.0, spool)` / `sparks.emitting = spool > 0.05`.

---

### `prefabs/laser/laser-weapon.gd` (weapon-script, event-driven)

**Analog:** `prefabs/gravitygun/gravitygun-script.gd`

Laser weapon may be minimal — only needed if per-weapon muzzle flash or visual override is required. Pattern is identical to GravityGun: `class_name LaserWeapon` / `extends MountableWeapon` / override `fire()` to trigger `muzzle_flash.restart()` then call `super()`.

**fire() + muzzle flash pattern**:
```gdscript
func fire():
    if not can_shoot():
        return
    if muzzle_flash:
        muzzle_flash.restart()
    super()
```
Reference: `gravitygun-script.gd` lines 9–13 for structure; CPUParticles2D `restart()` confirmed by RESEARCH.md Pattern 6.

---

### `prefabs/laser/laser-bullet.gd` (bullet-script, request-response)

**Analog:** `components/bullet.gd`

**bullet.gd full script** (lines 1–19):
```gdscript
class_name Bullet
extends Body

@export var life: float = 2.0
@export var attack: Damage
@export var death_ttl: float = 0.1

func _ready():
    body_entered.connect(collision)
    die(life)

func collision(body):
    if body is Body:
        if attack:
            body.damage(attack)
        else:
            push_warning("Bullet %s has no attack resource assigned" % name)
    die(death_ttl)
```

**LaserBullet divergence:** Instead of `extends Body` (which is `RigidBody2D`), must use `CharacterBody2D`. Do NOT connect `body_entered` — use `move_and_collide()` in `_physics_process`. Key fields to replicate:
- `@export var attack: Damage` — same
- `@export var spawn_parent: Node` — same (needed for spawning child bullets and effects)
- `die()` logic: replace with `queue_free()` directly (no health needed on bullets)
- Life timer pattern from `body.gd` lines 43–44: `await get_tree().create_timer(delay).timeout` → replicate as `get_tree().create_timer(2.0).timeout.connect(queue_free)` in `_ready()`.

**spawn_parent.call_deferred pattern** (body.gd lines 83–85 / mountable-weapon.gd line 118):
```gdscript
if spawn_parent:
    spawn_parent.call_deferred("add_child", successor)
else:
    push_warning("spawn_parent not set on " + name)
```
Bounce child bullets: `spawn_parent.call_deferred("add_child", child_bullet)`.

**Damage application pattern** (bullet.gd lines 13–16):
```gdscript
if body is Body:
    if attack:
        body.damage(attack)
    else:
        push_warning("Bullet %s has no attack resource assigned" % name)
```
Replicate exactly in `_on_impact(collision: KinematicCollision2D)`. Cast `collision.get_collider()` to `Body`.

---

### `components/body_camera.gd` (camera, add shake method)

**Analog:** self (add `shake()` method)

**Existing Tween pattern from score-hud.gd** (lines 58–65):
```gdscript
func _animate_score_flash() -> void:
    if _score_tween and _score_tween.is_running():
        _score_tween.kill()
    _score_value.add_theme_color_override("font_color", Color.WHITE)
    _score_tween = _score_value.create_tween()
    _score_tween.tween_property(_score_value, "theme_override_colors/font_color", Color(1.0, 1.0, 0.7), 0.1)
    _score_tween.chain().tween_property(_score_value, "theme_override_colors/font_color", Color.WHITE, 0.2)
```
Pattern: kill existing tween before creating new one, use `create_tween()` on node, chain with `.chain()`.

**`offset` property exists on Camera2D** — body_camera.gd already uses `zoom` property; `offset` follows same pattern. Add `shake()`:
```gdscript
func shake(magnitude: float = 8.0, duration: float = 0.3) -> void:
    if _shake_tween and _shake_tween.is_running():
        _shake_tween.kill()
    _shake_tween = create_tween()
    for _i in range(6):
        _shake_tween.tween_property(self, "offset",
            Vector2(randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude)),
            duration / 6.0)
    _shake_tween.tween_property(self, "offset", Vector2.ZERO, 0.05)
```
Signal name `fired_heavy` emitted by Gausscannon/RPG/GravityGun weapon scripts. `world.gd` connects: `weapon.fired_heavy.connect($ShipCamera.shake)` or BodyCamera self-connects via groups.

---

### `prefabs/ui/weapon-hud.gd` (HUD controller, request-response)

**Analog:** `prefabs/ui/wave-hud.gd`

**CanvasLayer + @onready pattern** (wave-hud.gd lines 1–10):
```gdscript
class_name WaveHud
extends CanvasLayer

@onready var _panel: Panel = $Panel
@onready var _wave_label: Label = $Panel/VBox/WaveLabel
@onready var _count_label: Label = $Panel/VBox/CountLabel
```
WeaponHud: `class_name WeaponHud` / `extends CanvasLayer` / `@onready` nodes for ammo label, reload bar, charge bar, weapon name label, lock bracket Control.

**_ready() + visibility init pattern** (wave-hud.gd lines 13–17):
```gdscript
func _ready() -> void:
    _panel.visible = false
    _countdown_label.visible = false
    _announcement_label.modulate.a = 0.0
    _wave_clear_label.visible = false
```
WeaponHud `_ready()`: set `reload_bar.visible = false` / `charge_bar.visible = false` / `lock_bracket.visible = false`.

**_process polling pattern** (hud.gd lines 23–44):
```gdscript
func _process(_delta):
    if not ship:
        return
    if not initialized:
        if ship:
            mount_front = ship.get_mount("")
            ...
        initialized = true
        return
    weapon_front.weapon = mount_front.body_opposite
    health.value = ship.health
```
WeaponHud: poll `mount_front.body_opposite` each frame to get active weapon. Check `is_instance_valid()` before accessing weapon properties.

**connect_to_X pattern** (wave-hud.gd lines 19–25 / score-hud.gd lines 26–30):
```gdscript
func connect_to_wave_manager(wm: WaveManager) -> void:
    wm.wave_started.connect(_on_wave_started)
    ...
```
WeaponHud: `func connect_to_ship(ship: MountableBody) -> void` sets `_ship = ship`.

**Label text formatting** (wave-hud.gd line 31 / score-hud.gd line 35):
```gdscript
_wave_label.text = "WAVE %d" % wave_number
_score_value.text = "%d" % new_score
```
WeaponHud ammo: `ammo_label.text = "%d / %d" % [weapon.magazine_current, weapon.ammo_current]`.

**Tween animation pattern** (wave-hud.gd lines 37–43):
```gdscript
if _announce_tween and _announce_tween.is_running():
    _announce_tween.kill()
_announce_tween = _announcement_label.create_tween()
_announce_tween.tween_property(_announcement_label, "modulate:a", 1.0, 0.3)
```
WeaponHud: optional flash on reload complete — same pattern.

---

### Weapon `.tscn` files — adding child nodes (all 5 weapons)

**Analog:** `components/explosion.gd` + `components/propeller-movement.gd`

**CPUParticles2D already used in explosion.tscn** (explosion.gd lines 6–7, 47–48):
```gdscript
@export var particles: CPUParticles2D
...
if particles:
    particles.emitting = true
```
Pattern: add `CPUParticles2D` as a child of `Barrel` node in each weapon `.tscn`. Export reference in weapon script: `@export var muzzle_flash: CPUParticles2D`. Configure in scene: `one_shot = true`, `explosiveness = 0.9`, `lifetime = 0.15`, `amount = 8`.

**PointLight2D export pattern** (propeller-movement.gd lines 6–7):
```gdscript
@export var light: PointLight2D
...
if light:
    light.enabled = active
```
Gausscannon/GravityGun/Minigun scenes: add `PointLight2D` child to barrel area, export in weapon script. Already present in GravityGun scene.

---

### `world.gd` (entry-point integration)

**Analog:** self (add weapon-hud instantiation in `_ready()`)

**HUD instantiation pattern** (world.gd lines 61–63):
```gdscript
_wave_hud = wave_hud_model.instantiate()
add_child(_wave_hud)
_wave_hud.connect_to_wave_manager($WaveManager)
```
WeaponHud integration:
```gdscript
var weapon_hud_model = preload("res://prefabs/ui/weapon-hud.tscn")
# in _ready():
var weapon_hud = weapon_hud_model.instantiate()
add_child(weapon_hud)
weapon_hud.connect_to_ship($ShipBFG23)
```

**_restart_game() reconnection pattern** (world.gd lines 444–446):
```gdscript
$ShipCamera.body = ship
$Hud.ship = ship
$Hud.initialized = false
```
Add `weapon_hud.connect_to_ship(ship)` in `_restart_game()` after new ship is created.

**notify_weapons dispatch** (world.gd lines 257–263):
```gdscript
func notify_weapons(action: MountableBody.Action):
    $ShipBFG23.do(null, action, "")
    $ShipBFG23.do(null, action, "left")
    $ShipBFG23.do(null, action, "right")
```
No change needed for charge weapons — `world.gd` continues sending FIRE every frame KEY_SPACE is held. Charge weapons ignore FIRE in their `do()` override and self-poll `Input.is_action_pressed`.

---

## Shared Patterns

### extends MountableWeapon + class_name
**Source:** `prefabs/gravitygun/gravitygun-script.gd` lines 1–2
**Apply to:** All new per-weapon scripts (GausscannonWeapon, RpgWeapon, MinigunWeapon, LaserWeapon)
```gdscript
class_name GravityGun
extends MountableWeapon
```

### can_shoot() guard
**Source:** `prefabs/gravitygun/gravitygun-script.gd` lines 9–11
**Apply to:** All weapon fire() overrides
```gdscript
func fire():
    if not can_shoot():
        return
```

### super() call in fire()
**Source:** `prefabs/gravitygun/gravitygun-script.gd` line 13
**Apply to:** RPG, LaserWeapon (NOT Gausscannon/GravityGun — they manage fire themselves)
```gdscript
super()
```

### spawn_parent.call_deferred("add_child", node)
**Source:** `components/mountable-weapon.gd` line 118 / `components/body.gd` line 84
**Apply to:** All scripts that spawn nodes at runtime (laser bullet children, impact FX, RPG bullet)
```gdscript
if spawn_parent:
    spawn_parent.call_deferred("add_child", instance)
else:
    push_warning("spawn_parent not set on " + name)
```

### Input.is_action_pressed in _physics_process
**Source:** `components/propeller-movement.gd` lines 11–12
**Apply to:** GausscannonWeapon, GravityGun (charge), MinigunWeapon (spool)
```gdscript
func _physics_process(delta):
    var active = Input.is_action_pressed(action)
```
For weapons, action is `"ui_select"` (KEY_SPACE mapping — verify in project Input Map).

### create_tween() + kill guard
**Source:** `prefabs/ui/score-hud.gd` lines 58–64 / `prefabs/ui/wave-hud.gd` lines 37–38
**Apply to:** BodyCamera.shake(), WeaponHud animations
```gdscript
if _tween and _tween.is_running():
    _tween.kill()
_tween = create_tween()
```

### apply_central_impulse (no torque)
**Source:** `components/explosion.gd` line 98 / `components/mountable-weapon.gd` line 110
**Apply to:** Recoil fix in mountable-body.gd, any new impulse application
```gdscript
body.apply_central_impulse(impulse)
```

### CanvasLayer + _process polling + @onready nodes
**Source:** `prefabs/ui/wave-hud.gd` / `prefabs/ui/hud.gd`
**Apply to:** weapon-hud.gd
```gdscript
class_name WeaponHud
extends CanvasLayer
@onready var _some_node: Label = $Path/To/Node
func _process(_delta):
    if not _ship:
        return
    # read weapon state, update labels/bars
```

---

## No Analog Found

All files have analogs in the codebase. No entries.

---

## Metadata

**Analog search scope:** `components/`, `prefabs/`, `prefabs/ui/`, `prefabs/gravitygun/`, `world.gd`
**Files read:** 13
**Pattern extraction date:** 2026-04-19
