class_name GravityGun
extends MountableWeapon

const CHARGE_MAX: float = 1.5
const STRENGTH_MIN_MULT: float = 1.0
const STRENGTH_MAX_MULT: float = 2.5
const AREA_MIN_MULT: float = 1.0
const AREA_MAX_MULT: float = 2.5

@export var area: Area2D
@export var strength: int = 20000
@export var torque: int = 2000000
@export var attack: Damage
@export var light: PointLight2D  # PointLight2D node for charge-pulse visual (D-23)
@export var muzzle_flash: CPUParticles2D

signal fired_heavy  # Connected to BodyCamera.shake() in world.gd (plan 18-10)

var charge_current: float = 0.0
var _was_charging: bool = false
var _base_area_scale: Vector2 = Vector2.ONE

const _PULSE_FREQ_MIN: float = 2.0   # radians/sec at charge = 0
const _PULSE_FREQ_MAX: float = 12.0  # radians/sec at full charge

func _ready() -> void:
	super()
	if area:
		_base_area_scale = area.scale

func _process(_delta: float) -> void:
	# PointLight2D pulses faster as charge builds (D-23)
	if light and charge_current > 0.0:
		var fraction: float = charge_current / CHARGE_MAX
		var freq: float = lerp(_PULSE_FREQ_MIN, _PULSE_FREQ_MAX, fraction)
		var t: float = Time.get_ticks_msec() * 0.001
		light.energy = lerp(0.5, 3.0, sin(t * freq) * 0.5 + 0.5)
	elif light:
		light.energy = 0.5  # resting glow

func _physics_process(delta: float) -> void:
	var firing: bool = Input.is_action_pressed("ui_select")

	if firing and can_shoot():
		charge_current = min(charge_current + delta, CHARGE_MAX)
		_was_charging = true
	elif _was_charging:
		_was_charging = false
		_fire_charged()
		charge_current = 0.0
		if light:
			light.energy = 0.5

func _fire_charged() -> void:
	if not can_shoot():
		return

	var fraction: float = charge_current / CHARGE_MAX

	# Scale area for this fire (D-22)
	var area_mult: float = lerp(AREA_MIN_MULT, AREA_MAX_MULT, fraction)
	if area:
		area.scale = _base_area_scale * area_mult

	# Temporarily scale strength by charge fraction
	var orig_strength: int = strength
	strength = int(strength * lerp(STRENGTH_MIN_MULT, STRENGTH_MAX_MULT, fraction))

	# Handle ammo, rate, and sound directly (no projectile spawn — gravity gun uses area)
	if use_rate:
		shot_timer.start(rate)
	if use_ammo:
		magazine_current -= 1
	if sound:
		sound.play()

	apply_damage()
	await get_tree().create_timer(0.1).timeout
	apply_kickback()

	# Restore area and strength
	strength = orig_strength
	if area:
		area.scale = _base_area_scale

	if muzzle_flash:
		muzzle_flash.restart()

	# Camera shake on charged fire (D-27)
	fired_heavy.emit()

# Override do() — intercept RELOAD and mode toggles; FIRE is self-managed via _physics_process
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
	# FIRE intentionally not forwarded — charge self-manages via _physics_process

# Expose charge fraction for Weapon HUD
func get_charge_fraction() -> float:
	return charge_current / CHARGE_MAX

func apply_kickback() -> void:
	var bodies = area.get_overlapping_bodies()
	for item in bodies:
		if not item is RigidBody2D:
			continue
		var body: RigidBody2D = item as RigidBody2D
		var direction: Vector2 = (body.global_position - global_position).normalized()
		var distance: float = (body.global_position - global_position).length()
		var impulse: Vector2 = direction * distance * strength
		body.apply_central_impulse(impulse)
		body.apply_torque_impulse(randf_range(-1, 1) * distance * torque)

func apply_damage() -> void:
	var bodies = area.get_overlapping_bodies()
	for item in bodies:
		if not item is Body:
			continue
		var body: RigidBody2D = item as RigidBody2D
		var dmg: Damage = Damage.new()
		dmg.energy = attack.energy if attack else 0.0
		dmg.kinetic = attack.kinetic if attack else 0.0
		var distance: float = (body.global_position - global_position).length()
		var loss: float = 1 - min(distance / strength, 1)
		dmg.energy *= loss
		dmg.kinetic *= loss
		body.damage(dmg)
