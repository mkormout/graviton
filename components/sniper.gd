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

const FIGHTING_THRUST_MULT := 1.5

var _target: Node2D = null
var _strafe_time: float = 0.0
var _bullet_scene := preload("res://prefabs/enemies/sniper/sniper-bullet.tscn")

@onready var _fire_timer: Timer = $FireTimer
@onready var _aim_timer: Timer = $AimTimer
@onready var _ammo_dropper: ItemDropper = $AmmoDropper
@onready var _barrel: Node2D = $Barrel

func _ready() -> void:
	super()
	thrust *= randf_range(0.8, 1.2)
	max_speed *= randf_range(0.8, 1.2)
	_fire_timer.timeout.connect(_on_fire_timer_timeout)
	_aim_timer.timeout.connect(_on_aim_timer_timeout)
	detection_area.body_exited.connect(_on_detection_area_body_exited)

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
		assert(aim_up_time < _fire_timer.wait_time,
			"aim_up_time must be less than FireTimer.wait_time or _fire() will never be called")
		_fire_timer.start()
	elif new_state == State.FLEEING:
		_fire_timer.stop()
		_aim_timer.stop()

func _exit_state(old_state: State) -> void:
	if old_state == State.FIGHTING:
		_fire_timer.stop()
		_aim_timer.stop()

func _on_fire_timer_timeout() -> void:
	if dying or current_state != State.FIGHTING:
		return
	# Start aim-up telegraph — does NOT fire immediately (D-09)
	_aim_timer.start(aim_up_time)

func _on_aim_timer_timeout() -> void:
	if dying or current_state != State.FIGHTING:
		return
	_fire()

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
		print("[Sniper] bullet spawned at %s vel=%s" % [bullet.global_position, bullet.linear_velocity])
	else:
		push_warning("Sniper: spawn_parent not set")

func die(delay: float = 0.0) -> void:
	if dying:
		return
	_fire_timer.stop()
	_aim_timer.stop()
	_ammo_dropper.drop()
	super(delay)
