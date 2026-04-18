class_name MinigunWeapon
extends MountableWeapon

const SPOOL_UP_TIME: float = 2.0
const SPOOL_DOWN_TIME: float = 0.5
const DAMAGE_MAX_MULTIPLIER: float = 1.5

@export var light: PointLight2D
@export var sparks: CPUParticles2D

var spool: float = 0.0    # 0.0 = idle, 1.0 = full speed

var _rate_min: float = 0.0
var _rate_max: float = 0.0

func _ready() -> void:
	super()
	_rate_min = rate
	_rate_max = max(rate * 0.2, 0.01)  # 5x speed at max spool; clamped to avoid 0 wait_time

func _physics_process(delta: float) -> void:
	var firing: bool = Input.is_action_pressed("ui_select")

	if firing:
		spool = min(spool + delta / SPOOL_UP_TIME, 1.0)
	else:
		spool = max(spool - delta / SPOOL_DOWN_TIME, 0.0)

	# Update fire rate — lower wait_time = faster fire (D-13, D-14)
	if shot_timer:
		shot_timer.wait_time = lerp(_rate_min, _rate_max, spool)

	# Glow scales with spool (D-15)
	if light:
		light.energy = lerp(0.0, 3.0, spool)

	# Particle emission on/off (D-15)
	if sparks:
		sparks.emitting = spool > 0.05

# Override fire() to apply damage multiplier at max spool (D-15)
func fire() -> void:
	if not ammo or not barrel:
		push_warning("MinigunWeapon %s: ammo or barrel not configured" % name)
		return

	if not has_ammo() and not is_reloading():
		if empty_sound and not empty_sound.playing:
			empty_sound.play()
		return

	if not can_shoot():
		return

	var instance = ammo.instantiate() as RigidBody2D
	instance.position = barrel.global_position
	instance.rotation = global_rotation
	instance.apply_central_impulse(
		Vector2.from_angle(global_rotation + randf_range(-spread, spread)) * velocity
	)

	# Scale damage at max spool (D-15)
	if spool >= 0.95 and "attack" in instance and instance.attack:
		var scaled_attack = instance.attack.duplicate()
		scaled_attack.energy *= DAMAGE_MAX_MULTIPLIER
		scaled_attack.kinetic *= DAMAGE_MAX_MULTIPLIER
		instance.attack = scaled_attack

	if "spawn_parent" in instance:
		instance.spawn_parent = spawn_parent
	if spawn_parent:
		spawn_parent.call_deferred("add_child", instance)
	else:
		push_warning("MinigunWeapon: spawn_parent not set")

	if sound:
		sound.play()
	if use_rate:
		shot_timer.start(shot_timer.wait_time)  # Use current spooled rate
	if use_ammo:
		magazine_current -= 1

	var mount = get_mount("")
	if mount:
		mount.do(self, Action.RECOIL, recoil)

# Expose spool for HUD
func get_spool() -> float:
	return spool
