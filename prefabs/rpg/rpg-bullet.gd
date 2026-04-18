class_name RpgBullet
extends Bullet

@export var impact_scene: PackedScene

const TURN_FORCE: float = 60000.0

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
	# Homing: apply force toward target each frame (D-10)
	if _target and is_instance_valid(_target):
		var dir: Vector2 = (_target.global_position - global_position).normalized()
		apply_central_force(dir * TURN_FORCE)
	# else: target invalid or not set — rocket continues in current direction (D-11)
