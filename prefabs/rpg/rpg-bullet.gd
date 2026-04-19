class_name RpgBullet
extends Bullet

@export var impact_scene: PackedScene

const ACCELERATION: float = 20000.0  # units/s² thrust toward target
const MAX_SPEED: float = 12000.0     # 0.75× previous cap (16000 → 12000)

var _target: Node2D = null

func set_target(t: Node2D) -> void:
	_target = t

func collision(body) -> void:
	_spawn_impact(global_position)
	super.collision(body)

func _spawn_impact(pos: Vector2) -> void:
	if not impact_scene or not spawn_parent:
		return
	var fx = impact_scene.instantiate()
	fx.global_position = pos
	spawn_parent.call_deferred("add_child", fx)

func _physics_process(delta: float) -> void:
	# Homing: steer velocity direction toward target each frame.
	# Using velocity lerp rather than apply_central_force because the bullet
	# mass (5000) and velocity (8000 units/s) make force-based steering
	# completely ineffective — TURN_FORCE would need to be ~40 million N to
	# produce a 1 unit/s² correction at this scale.
	if _target and is_instance_valid(_target):
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		linear_velocity += dir * ACCELERATION * delta
		if linear_velocity.length() > MAX_SPEED:
			linear_velocity = linear_velocity.normalized() * MAX_SPEED
		rotation = dir.angle()
	elif linear_velocity.length_squared() > 0.0:
		rotation = linear_velocity.angle()
