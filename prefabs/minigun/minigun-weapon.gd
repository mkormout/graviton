class_name MinigunWeapon
extends MountableWeapon

const SPOOL_UP_TIME: float = 1.2
const SPOOL_DOWN_TIME: float = 0.5
const DAMAGE_MIN_MULT: float = 0.875  # spool=0: slightly weaker than base
const DAMAGE_MAX_MULT: float = 1.625  # spool=1: 50% wider range than original 1.5x cliff

@export var light: PointLight2D
@export var sparks: CPUParticles2D
@export var muzzle_flash: CPUParticles2D

var spool: float = 0.0    # 0.0 = idle, 1.0 = full speed

var _rate_min: float = 0.0
var _rate_max: float = 0.0

func _ready() -> void:
	super()
	_rate_min = 0.5            # 2 shots/sec when cold — noticeable slow start
	_rate_max = max(rate / 5.6, 0.01)  # 5.6x speed at full spool

func _physics_process(delta: float) -> void:
	# Only respond to player input while mounted; dropped weapons must not spool up.
	var mounted: bool = get_parent() is MountPoint
	var firing: bool = mounted and Input.is_action_pressed("ui_select")

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

	# Continuous damage scaling across full spool range
	if "attack" in instance and instance.attack:
		var scaled_attack = instance.attack.duplicate()
		var mult: float = lerp(DAMAGE_MIN_MULT, DAMAGE_MAX_MULT, spool)
		scaled_attack.energy *= mult
		scaled_attack.kinetic *= mult
		instance.attack = scaled_attack

	if "spawn_parent" in instance:
		instance.spawn_parent = spawn_parent
	if spawn_parent:
		spawn_parent.call_deferred("add_child", instance)
	else:
		push_warning("MinigunWeapon: spawn_parent not set")

	if muzzle_flash:
		muzzle_flash.restart()

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
