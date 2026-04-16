class_name Beeliner
extends EnemyShip

@export var fight_range: float = 400.0
@export var bullet_speed: float = 4400.0
@export var jitter_force: float = 300.0
# Sprite configuration (SPR-01, SPR-02, SPR-05) — per D-03 Beeliner = ENM-07
@export var sprite_region: Rect2 = Rect2(20, 10, 390, 700)
@export var sprite_scale: Vector2 = Vector2(1.76, 1.76)
# Gem glow configuration (SPR-04) — per D-04 Beeliner gem is green, D-05 steady rhythmic pulse
@export var gem_energy_min: float = 0.5
@export var gem_energy_max: float = 1.8
@export var gem_pulse_half_period: float = 0.6

var _target: Node2D = null
var _bullet_scene := preload("res://prefabs/enemies/beeliner/beeliner-bullet.tscn")

const SPREAD_ANGLES := [-0.1, 0.0, 0.1]  # radians: -7.5 deg, 0 deg, +7.5 deg
var _jitter_timer: float = 0.0
var _jitter_dir: float = 1.0

@onready var _fire_timer: Timer = $FireTimer
@onready var _ammo_dropper: ItemDropper = $AmmoDropper

func _ready() -> void:
	super()
	thrust *= randf_range(0.8, 1.2)
	max_speed *= randf_range(0.8, 1.2)
	_fire_timer.timeout.connect(_on_fire_timer_timeout)
	_setup_sprite()
	_setup_gem_light()

func _tick_state(_delta: float) -> void:
	match current_state:
		State.SEEKING:
			if _target:
				look_at(_target.global_position)
				steer_toward(_target.global_position)
				if global_position.distance_to(_target.global_position) <= fight_range:
					_change_state(State.FIGHTING)
				# Perpendicular jitter (D-13)
				_jitter_timer -= _delta
				if _jitter_timer <= 0.0:
					_jitter_timer = randf_range(1.0, 2.0)
					_jitter_dir = 1.0 if randf() > 0.5 else -1.0
				var perp := Vector2.from_angle(global_rotation + PI / 2.0) * _jitter_dir
				apply_central_force(perp * jitter_force)
		State.FIGHTING:
			if _target:
				look_at(_target.global_position)
				steer_toward(_target.global_position)
				# Perpendicular jitter (D-13)
				_jitter_timer -= _delta
				if _jitter_timer <= 0.0:
					_jitter_timer = randf_range(1.0, 2.0)
					_jitter_dir = 1.0 if randf() > 0.5 else -1.0
				var perp := Vector2.from_angle(global_rotation + PI / 2.0) * _jitter_dir
				apply_central_force(perp * jitter_force)

func _enter_state(new_state: State) -> void:
	print("[Beeliner] _enter_state: %s" % State.keys()[new_state])
	if new_state == State.FIGHTING:
		_fire()
		_fire_timer.start()

func _exit_state(old_state: State) -> void:
	if old_state == State.FIGHTING:
		_fire_timer.stop()

func _on_detection_area_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is PlayerShip and current_state == State.IDLING:
		_target = body
		_change_state(State.SEEKING)

func _fire() -> void:
	print("[Beeliner] _fire() called — dying=%s spawn_parent=%s" % [dying, spawn_parent])
	if dying:
		return
	for angle_offset in SPREAD_ANGLES:
		var bullet := _bullet_scene.instantiate() as RigidBody2D
		var fire_dir := Vector2.from_angle(global_rotation + angle_offset)
		bullet.rotation = global_rotation + angle_offset
		bullet.linear_velocity = fire_dir * bullet_speed
		if spawn_parent:
			spawn_parent.add_child(bullet)
			# Spawn past HitBox radius (300) to avoid self-collision
			bullet.global_position = global_position + fire_dir * 350.0
			print("[Beeliner] bullet spawned at %s vel=%s" % [bullet.global_position, bullet.linear_velocity])
		else:
			push_warning("Beeliner: spawn_parent not set")

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
