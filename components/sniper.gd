class_name Sniper
extends EnemyShip

@export var fight_range: float = 11000.0
@export var comfort_range: float = 10000.0
@export var flee_range: float = 4000.0
@export var safe_range: float = 7000.0
@export var aim_up_time: float = 1.0
@export var bullet_speed: float = 10000.0
@export var strafe_force: float = 200.0
@export var strafe_period: float = 4.0
# Sprite configuration (SPR-01, SPR-02, SPR-05) — per D-03 Sniper = ENM-08
@export var sprite_region: Rect2 = Rect2(440, 10, 380, 780)
@export var sprite_scale: Vector2 = Vector2(1.81, 1.81)
# Gem glow configuration (SPR-04) — per D-04 Sniper gem is purple, D-05 slow hypnotic pulse
@export var gem_energy_min: float = 0.2
@export var gem_energy_max: float = 2.5
@export var gem_pulse_half_period: float = 1.5

const FIGHTING_THRUST_MULT := 1.5

var _target: Node2D = null
var _strafe_time: float = 0.0
var _bullet_scene := preload("res://prefabs/enemies/sniper/sniper-bullet.tscn")

@onready var _ammo_dropper: ItemDropper = $AmmoDropper
@onready var _barrel: Node2D = $Barrel

# Float-counter replacement for FireTimer + AimTimer (perf: avoid SceneTree Timers per enemy).
const _FIRE_INTERVAL: float = 3.0   # matches previous FireTimer.wait_time
var _fire_active: bool = false
var _fire_left: float = 0.0
var _aim_active: bool = false
var _aim_left: float = 0.0

func _ready() -> void:
	super()
	thrust *= randf_range(0.8, 1.2)
	max_speed *= randf_range(0.8, 1.2)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	_setup_sprite()
	_setup_gem_light()

func _physics_process(delta: float) -> void:
	super(delta)
	if _fire_active:
		_fire_left -= delta
		if _fire_left <= 0.0:
			_fire_left += _FIRE_INTERVAL  # += preserves sub-frame drift (matches Timer)
			_on_fire_timer_timeout()
	if _aim_active:
		_aim_left -= delta
		if _aim_left <= 0.0:
			_aim_active = false
			_aim_left = 0.0
			_on_aim_timer_timeout()

func _start_fire_timer() -> void:
	_fire_active = true
	_fire_left = _FIRE_INTERVAL

func _stop_fire_timer() -> void:
	_fire_active = false
	_fire_left = 0.0

func _start_aim_timer(duration: float) -> void:
	_aim_active = true
	_aim_left = duration

func _stop_aim_timer() -> void:
	_aim_active = false
	_aim_left = 0.0

func _on_detection_area_body_entered(body: Node2D) -> void:
	if dying:
		return
	if body is PlayerShip and current_state == State.IDLING:
		_target = body
		_change_state(State.SEEKING)

func _on_detection_area_body_exited(body: Node2D) -> void:
	# Only reset in SEEKING — FLEEING/FIGHTING have their own range-based exit logic.
	# Clearing target during FLEEING caused the sniper to go IDLE mid-flee and never return.
	if body == _target and current_state == State.SEEKING:
		_target = null
		_change_state(State.IDLING)

func _tick_state(_delta: float) -> void:
	if not is_instance_valid(_target):
		_target = null
		if current_state != State.IDLING:
			_change_state(State.IDLING)
		return
	var dist := global_position.distance_to(_target.global_position)
	var away := (global_position - _target.global_position).normalized()
	var toward := (_target.global_position - global_position).normalized()

	match current_state:
		State.SEEKING:
			look_at(_target.global_position)
			if dist < flee_range:
				_change_state(State.FLEEING)
			elif dist < fight_range:
				_change_state(State.FIGHTING)
			else:
				steer_toward(_target.global_position)

		State.FIGHTING:
			look_at(_target.global_position)
			# Sinusoidal strafe (D-14)
			_strafe_time += _delta
			var strafe_mult := sin(_strafe_time * TAU / strafe_period)
			var perp := Vector2.from_angle(global_rotation + PI / 2.0) * strafe_mult
			apply_central_force(perp * strafe_force)
			# CRITICAL: Check innermost range first (flee_range), then comfort_range
			if dist < flee_range:
				_change_state(State.FLEEING)
			elif dist < comfort_range:
				# Reverse thrust at reduced power (D-03, D-07)
				apply_central_force(away * thrust * FIGHTING_THRUST_MULT)
			else:
				# Gentle corrective thrust toward player (D-03)
				apply_central_force(toward * thrust * FIGHTING_THRUST_MULT)

		State.FLEEING:
			look_at(_target.global_position)
			if dist > safe_range:
				_change_state(State.SEEKING)
			else:
				# Full reverse thrust
				apply_central_force(away * thrust)

func _enter_state(new_state: State) -> void:
	print("[Sniper] _enter_state: %s" % State.keys()[new_state])
	if new_state == State.FIGHTING:
		_strafe_time = 0.0
		assert(aim_up_time < _FIRE_INTERVAL,
			"aim_up_time must be less than _FIRE_INTERVAL or _fire() will never be called")
		_start_fire_timer()
	elif new_state == State.FLEEING:
		_stop_fire_timer()
		_stop_aim_timer()

func _exit_state(old_state: State) -> void:
	if old_state == State.FIGHTING:
		_stop_fire_timer()
		_stop_aim_timer()

func _on_fire_timer_timeout() -> void:
	if dying or current_state != State.FIGHTING:
		return
	# Start aim-up telegraph — does NOT fire immediately (D-09)
	_start_aim_timer(aim_up_time)

func _on_aim_timer_timeout() -> void:
	if dying or current_state != State.FIGHTING:
		return
	_fire()

func _fire() -> void:
	if dying:
		return
	var bullet := PoolManager.acquire(_bullet_scene) as RigidBody2D
	var fire_dir := Vector2.from_angle(global_rotation)
	bullet.rotation = global_rotation
	bullet.linear_velocity = fire_dir * bullet_speed
	# Propagate spawn_parent so the bullet's death explosion can be parented
	# to the world. Without this, Body.die() acquires a pooled explosion but
	# never adds it to the tree, causing an infinite call_deferred loop.
	bullet.spawn_parent = spawn_parent
	if spawn_parent:
		spawn_parent.add_child(bullet)
		bullet.global_position = _barrel.global_position
		print("[Sniper] bullet spawned at %s vel=%s" % [bullet.global_position, bullet.linear_velocity])
	else:
		push_warning("Sniper: spawn_parent not set")

func die(delay: float = 0.0) -> void:
	if dying:
		return
	_stop_fire_timer()
	_stop_aim_timer()
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
	if _DIAG_ENEMY_FX_DISABLED:
		return  # DIAG: skip infinite pulse Tween
	var tween := create_tween()
	tween.set_loops(0)  # 0 = infinite in Godot 4 (verified per RESEARCH Pattern 2)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "energy", gem_energy_max, gem_pulse_half_period)
	tween.tween_property(light, "energy", gem_energy_min, gem_pulse_half_period)
