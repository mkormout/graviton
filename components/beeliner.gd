class_name Beeliner
extends EnemyShip

@export var fight_range: float = 400.0
@export var bullet_speed: float = 4400.0

var _target: Node2D = null
var _bullet_scene := preload("res://prefabs/enemies/beeliner/beeliner-bullet.tscn")

const SPREAD_ANGLES := [-0.131, 0.0, 0.131]  # radians: -7.5 deg, 0 deg, +7.5 deg

@onready var _fire_timer: Timer = $FireTimer
@onready var _ammo_dropper: ItemDropper = $AmmoDropper

func _ready() -> void:
	super()
	thrust *= randf_range(0.9, 1.1)
	max_speed *= randf_range(0.9, 1.1)
	_fire_timer.timeout.connect(_on_fire_timer_timeout)

func _tick_state(_delta: float) -> void:
	match current_state:
		State.SEEKING:
			if _target:
				look_at(_target.global_position)
				steer_toward(_target.global_position)
				if global_position.distance_to(_target.global_position) <= fight_range:
					_change_state(State.FIGHTING)
		State.FIGHTING:
			if _target:
				look_at(_target.global_position)
				steer_toward(_target.global_position)

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
