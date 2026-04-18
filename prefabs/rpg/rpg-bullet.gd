class_name RpgBullet
extends Bullet

const TURN_FORCE: float = 60000.0

var _target: Node2D = null

func set_target(t: Node2D) -> void:
	_target = t

func _physics_process(delta: float) -> void:
	# Homing: apply force toward target each frame (D-10)
	if _target and is_instance_valid(_target):
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		apply_central_force(dir * TURN_FORCE)
	# else: target invalid or not set — rocket continues in current direction (D-11)
