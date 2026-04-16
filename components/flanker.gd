class_name Flanker
extends EnemyShip

@export var fight_range: float = 4500.0
@export var fight_duration: float = 2.5
@export var orbit_entry_range: float = 9500.0
@export var max_follow_distance: float = 12000.0
@export var bullet_speed: float = 6050.0
# Sprite configuration (SPR-01, SPR-02, SPR-05) — per D-03 Flanker = ENM-09
@export var sprite_region: Rect2 = Rect2(870, 30, 360, 720)
@export var sprite_scale: Vector2 = Vector2(1.43, 1.43)
# Gem glow configuration (SPR-04) — per D-04 Flanker gem is orange, D-05 mid-tempo rhythmic
@export var gem_energy_min: float = 0.4
@export var gem_energy_max: float = 1.6
@export var gem_pulse_half_period: float = 0.8

var _target: Node2D = null
var _bullet_scene := preload("res://prefabs/enemies/flanker/flanker-bullet.tscn")
var orbit_direction: float = 1.0

var _radial_drift: float = 0.0
var _drift_timer: float = 0.0
var _fight_remaining: float = 0.0
var _fight_cooldown: float = 0.0
var _fire_started: bool = false

var _lurk_speed: float = 1.0
var _drift_scale: float = 1.0
var _turn_speed: float = 5.0

@onready var _fire_timer: Timer = $FireTimer
@onready var _ammo_dropper: ItemDropper = $AmmoDropper
@onready var _barrel: Node2D = $Barrel

func _ready() -> void:
	super()
	thrust *= randf_range(0.8, 1.2)
	max_speed *= randf_range(0.8, 1.2)
	orbit_direction = 1.0 if randf() > 0.5 else -1.0
	_lurk_speed = randf_range(0.8, 1.2)
	_drift_scale = randf_range(0.8, 1.2)
	_turn_speed = 5.0 * randf_range(0.8, 1.2)
	_fire_timer.timeout.connect(_on_fire_timer_timeout)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	_setup_sprite()
	_setup_gem_light()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is PlayerShip and current_state == State.IDLING:
		_target = body
		_change_state(State.SEEKING)

func _on_detection_area_body_exited(body: Node2D) -> void:
	# Only drop target in SEEKING — LURKING and FIGHTING have their own
	# distance-based leash logic in _tick_state (max_follow_distance check).
	if body == _target and current_state == State.SEEKING:
		_target = null
		_change_state(State.IDLING)

func _tick_state(_delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		_change_state(State.IDLING)
		return

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()

	if current_state != State.FIGHTING and linear_velocity.length_squared() > 100.0:
		rotation = linear_velocity.angle()

	match current_state:
		State.SEEKING:
			if dist < orbit_entry_range:
				_change_state(State.LURKING)
			else:
				steer_toward(_target.global_position)

		State.LURKING:
			if dist < 1.0:
				return
			var toward_norm: Vector2 = to_target / dist

			# Update random drift — changes every 2–4.5s, biased inward so the
			# Flanker drifts into attack range over time rather than circling forever
			_drift_timer -= _delta
			if _drift_timer <= 0.0:
				_radial_drift = randf_range(-0.5, 1.0)
				_drift_timer = randf_range(2.0, 4.5)

			# Leash: pull strongly inward if Flanker wanders too far
			var effective_drift := _radial_drift
			if dist > max_follow_distance:
				effective_drift = 2.0

			var tangential: Vector2 = toward_norm.orthogonal() * orbit_direction * _lurk_speed
			var radial: Vector2 = toward_norm * effective_drift * _drift_scale
			apply_central_force((tangential + radial) * thrust)

			_fight_cooldown -= _delta
			if dist < fight_range and _fight_cooldown <= 0.0:
				_change_state(State.FIGHTING)

		State.FIGHTING:
			var target_angle := to_target.angle()
			rotation = lerp_angle(rotation, target_angle, _turn_speed * _delta)
			steer_toward(_target.global_position)
			if not _fire_started and absf(angle_difference(rotation, target_angle)) < 0.15:
				_fire_started = true
				_fire()
				_fire_timer.start()
			if _fire_started:
				_fight_remaining -= _delta
			if _fight_remaining <= 0.0 or dist > max_follow_distance:
				_change_state(State.LURKING)

func _enter_state(new_state: State) -> void:
	print("[Flanker] _enter_state: %s" % State.keys()[new_state])
	if new_state == State.FIGHTING:
		_fight_remaining = fight_duration
		_fire_started = false
	elif new_state == State.LURKING:
		_radial_drift = randf_range(-0.5, 1.0)
		_drift_timer = randf_range(1.0, 3.0)

func _exit_state(old_state: State) -> void:
	if old_state == State.FIGHTING:
		_fire_timer.stop()
		_fight_cooldown = 5.0

func _fire() -> void:
	if dying:
		return
	var bullet := _bullet_scene.instantiate() as RigidBody2D
	var fire_dir := Vector2.from_angle(global_rotation)
	bullet.rotation = global_rotation
	bullet.linear_velocity = fire_dir * bullet_speed
	if spawn_parent:
		spawn_parent.add_child(bullet)
		bullet.global_position = _barrel.global_position
	else:
		push_warning("Flanker: spawn_parent not set")

func _on_fire_timer_timeout() -> void:
	if dying or current_state != State.FIGHTING:
		return
	_fire()

func die(delay: float = 0.0) -> void:
	if dying:
		return
	_fire_timer.stop()
	_ammo_dropper.drop()
	super(delay)

# SPR-01/02/03/05: Load atlas, configure Sprite2D region, hide Polygon2D fallback on success.
func _setup_sprite() -> void:
	var atlas: Texture2D = load("res://ships_assests.png")
	if atlas == null:
		# SPR-03 fallback: atlas missing — Polygon2D "Shape" stays visible.
		return
	var sprite := $Sprite2D as Sprite2D
	sprite.texture = atlas
	sprite.region_enabled = true
	sprite.region_rect = sprite_region
	sprite.rotation_degrees = -90.0  # atlas art points +Y; Godot facing is +X
	sprite.scale = sprite_scale
	$Shape.visible = false

# SPR-04: Wire viewport culling, start infinite pulse tween on gem light.
func _setup_gem_light() -> void:
	var notifier := $VisibleOnScreenNotifier2D as VisibleOnScreenNotifier2D
	var light := $GemLight as PointLight2D
	light.enabled = false
	notifier.screen_entered.connect(func(): light.enabled = true)
	notifier.screen_exited.connect(func(): light.enabled = false)
	_start_pulse(light)

func _start_pulse(light: PointLight2D) -> void:
	var tween := create_tween()
	tween.set_loops(0)  # 0 = infinite in Godot 4 (verified per RESEARCH Pattern 2)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "energy", gem_energy_max, gem_pulse_half_period)
	tween.tween_property(light, "energy", gem_energy_min, gem_pulse_half_period)
