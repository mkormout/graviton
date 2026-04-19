class_name GausscannonWeapon
extends MountableWeapon

const CHARGE_MAX: float = 2.0

@export var light: PointLight2D
@export var sparks: CPUParticles2D
@export var muzzle_flash: CPUParticles2D

signal fired_heavy  # Connected to BodyCamera.shake() in world.gd (plan 18-10)

var charge_current: float = 0.0
var _was_charging: bool = false

const _LIGHT_BASE: float = 0.3
const _LIGHT_MAX: float = 4.0

# Damage multiplier: midpoint 2.0, diff 3.0 (50% wider than original 2.0 diff)
const _DAMAGE_MIN_MULT: float = 0.5
const _DAMAGE_MAX_MULT: float = 3.5
# Velocity multiplier: midpoint 0.75, diff 0.75 (50% wider than original 0.5 diff)
const _VEL_MIN_MULT: float = 0.35
const _VEL_MAX_MULT: float = 1.15
# Recoil multiplier: midpoint 0.65, diff 1.05 (50% wider than original 0.7 diff)
const _RECOIL_MIN_MULT: float = 0.1
const _RECOIL_MAX_MULT: float = 1.2

func _physics_process(delta: float) -> void:
	var firing: bool = get_parent() is MountPoint and Input.is_action_pressed("ui_select")

	if firing and can_shoot():
		charge_current = min(charge_current + delta, CHARGE_MAX)
		_was_charging = true

		# Scale PointLight2D energy with charge fraction (D-05)
		if light:
			light.energy = lerp(_LIGHT_BASE, _LIGHT_MAX, charge_current / CHARGE_MAX)

		# At full charge: continuous sparks (D-06)
		if sparks:
			if charge_current >= CHARGE_MAX and not sparks.emitting:
				sparks.one_shot = false
				sparks.emitting = true
	elif _was_charging:
		_was_charging = false
		if sparks:
			sparks.emitting = false
			sparks.one_shot = true
		_fire_charged()
		charge_current = 0.0
		if light:
			light.energy = _LIGHT_BASE

func _fire_charged() -> void:
	if not can_shoot():
		return
	if not ammo or not barrel:
		push_warning("GausscannonWeapon: ammo or barrel not configured")
		return

	var fraction: float = charge_current / CHARGE_MAX
	var scaled_velocity: float = velocity * lerp(_VEL_MIN_MULT, _VEL_MAX_MULT, fraction)
	var scaled_recoil: float = recoil * lerp(_RECOIL_MIN_MULT, _RECOIL_MAX_MULT, fraction)

	# Spawn bullet with scaled velocity (manual spawn — do not call super.fire())
	var instance = ammo.instantiate() as RigidBody2D
	instance.position = barrel.global_position
	instance.rotation = global_rotation
	instance.apply_central_impulse(
		Vector2.from_angle(global_rotation + randf_range(-spread, spread)) * scaled_velocity
	)
	# Scale damage: duplicate the Damage resource and multiply
	if "attack" in instance and instance.attack:
		var scaled_attack = instance.attack.duplicate()
		var mult: float = lerp(_DAMAGE_MIN_MULT, _DAMAGE_MAX_MULT, fraction)
		scaled_attack.energy *= mult
		scaled_attack.kinetic *= mult
		instance.attack = scaled_attack
	if "spawn_parent" in instance:
		instance.spawn_parent = spawn_parent
	# Scale bullet glow and particles with charge — dim at low charge, full at max.
	var bullet_light = instance.get_node_or_null("PointLight2D")
	if bullet_light:
		bullet_light.energy = lerp(0.2, bullet_light.energy, fraction)
	var bullet_particles = instance.get_node_or_null("CPUParticles2D")
	if bullet_particles:
		bullet_particles.scale *= lerp(0.2, 1.0, fraction)
	if spawn_parent:
		spawn_parent.call_deferred("add_child", instance)
	else:
		push_warning("GausscannonWeapon: spawn_parent not set")

	if muzzle_flash:
		muzzle_flash.restart()

	if sound:
		sound.play()
	if use_rate:
		shot_timer.start(rate)
	if use_ammo:
		magazine_current -= 1

	# Recoil via mount
	var mount = get_mount("")
	if mount:
		mount.do(self, Action.RECOIL, scaled_recoil)

	# Camera shake for heavy weapon (D-27)
	fired_heavy.emit()

# Override do() — intercept FIRE and do NOT call super() for it.
# Charge logic runs in _physics_process. Pass through RELOAD and GODMODE.
func do(_sender: Node2D, action: MountableBody.Action, _where: String, _meta = null) -> void:
	if action == MountableBody.Action.RELOAD:
		reload()
	if action == MountableBody.Action.GODMODE:
		use_ammo = false
		use_rate = false
	if action == MountableBody.Action.USE_AMMO:
		use_ammo = false
	if action == MountableBody.Action.USE_RATE:
		use_rate = false
	# FIRE is intentionally NOT handled here — _physics_process manages charge and firing

func get_charge_fraction() -> float:
	return charge_current / CHARGE_MAX
