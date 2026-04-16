class_name Swarmer
extends EnemyShip

@export var fight_range: float = 5000.0
@export var cohesion_radius: float = 900.0
@export var cohesion_thrust_scale: float = 0.4
@export var cohesion_force: float = 700.0
@export var separation_force: float = 1800.0
@export var bullet_speed: float = 3500.0
@export var speed_tier: float = 1.0
# Sprite configuration (SPR-01, SPR-02, SPR-05) — per D-03 Swarmer = ENM-10
@export var sprite_region: Rect2 = Rect2(1295, 50, 360, 650)
@export var sprite_scale: Vector2 = Vector2(0.96, 0.96)
# Gem glow configuration (SPR-04) — per D-04 Swarmer gem is yellow/amber, D-05 quick flicker
@export var gem_energy_min: float = 0.3
@export var gem_energy_max: float = 2.0
@export var gem_pulse_half_period: float = 0.25

var _target: Node2D = null
var _angle_offset: float = 0.0
var _nearby_swarmers: Array[EnemyShip] = []

var _bullet_scene := preload("res://prefabs/enemies/swarmer/swarmer-bullet.tscn")

@onready var _fire_timer: Timer = $FireTimer
@onready var _ammo_dropper: ItemDropper = $AmmoDropper
@onready var _barrel: Node2D = $Barrel
@onready var _cohesion_area: Area2D = $CohesionArea

func _ready() -> void:
	super()
	thrust *= speed_tier
	max_speed *= speed_tier
	thrust *= randf_range(0.8, 1.2)
	max_speed *= randf_range(0.8, 1.2)
	_angle_offset = deg_to_rad(randf_range(-40.0, 40.0))
	_cohesion_area.collision_layer = 0
	_cohesion_area.collision_mask = 1
	_cohesion_area.body_entered.connect(_on_cohesion_area_body_entered)
	_cohesion_area.body_exited.connect(_on_cohesion_area_body_exited)
	_fire_timer.timeout.connect(_on_fire_timer_timeout)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	_setup_sprite()
	_setup_gem_light()

func _on_cohesion_area_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is Swarmer and body != self:
		_nearby_swarmers.append(body)

func _on_cohesion_area_body_exited(body: Node2D) -> void:
	_nearby_swarmers.erase(body)

func _on_detection_area_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is PlayerShip and current_state == State.IDLING:
		_target = body
		_change_state(State.SEEKING)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == _target:
		_target = null
		_change_state(State.IDLING)

func _tick_state(_delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		_change_state(State.IDLING)
		return

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float = to_target.length()
	var force_scale: float = _compute_force_scale()

	match current_state:
		State.SEEKING:
			if dist <= fight_range:
				_change_state(State.FIGHTING)
			else:
				# Apply angle offset to steering direction (D-04)
				var raw_dir := to_target / dist
				var offset_dir := raw_dir.rotated(_angle_offset)
				apply_central_force(offset_dir * thrust * force_scale)
				if linear_velocity.length_squared() > 100.0:
					rotation = lerp_angle(rotation, linear_velocity.angle(), 5.0 * _delta)
		State.FIGHTING:
			var target_angle := to_target.angle()
			rotation = lerp_angle(rotation, target_angle, 5.0 * _delta)
			apply_central_force((to_target / dist) * thrust * force_scale)
			# Hysteresis: 1.2x fight_range to prevent oscillation (D-12)
			if dist > fight_range * 1.2:
				_change_state(State.SEEKING)

func _compute_force_scale() -> float:
	if _nearby_swarmers.is_empty():
		return 1.0
	var closest := cohesion_radius
	for s in _nearby_swarmers:
		if is_instance_valid(s):
			var d := global_position.distance_to(s.global_position)
			if d < closest:
				closest = d
	# Smooth ramp: 1.0 at edge of cohesion zone → cohesion_thrust_scale at center
	var proximity_t := 1.0 - clampf(closest / cohesion_radius, 0.0, 1.0)
	return lerp(1.0, cohesion_thrust_scale, proximity_t)

func _physics_process(delta: float) -> void:
	super(delta)
	if dying:
		return
	_apply_separation()
	_apply_cohesion()

func _apply_separation() -> void:
	for swarmer in _nearby_swarmers:
		if not is_instance_valid(swarmer):
			continue
		var away: Vector2 = global_position - swarmer.global_position
		var dist: float = away.length()
		if dist < 1.0:
			continue  # Coincident -- skip to avoid NaN
		# Linear falloff: max force at dist=0, zero force at dist=cohesion_radius
		var strength: float = separation_force * (1.0 - clampf(dist / cohesion_radius, 0.0, 1.0))
		apply_central_force(away.normalized() * strength)

func _apply_cohesion() -> void:
	if _nearby_swarmers.is_empty():
		return
	var center := Vector2.ZERO
	var valid_count := 0
	for s in _nearby_swarmers:
		if is_instance_valid(s):
			center += s.global_position
			valid_count += 1
	if valid_count == 0:
		return
	center /= float(valid_count)
	var toward_center := center - global_position
	var dist := toward_center.length()
	if dist < 1.0:
		return
	# Pull toward group center; force ramps up with distance from center
	var strength := cohesion_force * clampf(dist / cohesion_radius, 0.0, 1.0)
	apply_central_force(toward_center.normalized() * strength)

func _enter_state(new_state: State) -> void:
	print("[Swarmer] _enter_state: %s" % State.keys()[new_state])
	if new_state == State.FIGHTING:
		_fire()
		_fire_timer.start()

func _exit_state(old_state: State) -> void:
	if old_state == State.FIGHTING:
		_fire_timer.stop()

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
		push_warning("Swarmer: spawn_parent not set")

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
	sprite.rotation_degrees = 90.0  # atlas ships face up (-Y); rotate CW so nose aligns with +X (look_at direction)
	sprite.scale = sprite_scale
	var mat := ShaderMaterial.new()
	mat.shader = load("res://components/enemy-sprite.gdshader")
	sprite.material = mat
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
