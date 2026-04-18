class_name MinigunBullet
extends Bullet

@export var impact_scene: PackedScene

func collision(body) -> void:
	_spawn_impact(global_position)
	super.collision(body)

func _spawn_impact(pos: Vector2) -> void:
	if not impact_scene or not spawn_parent:
		return
	var fx = impact_scene.instantiate()
	fx.global_position = pos
	spawn_parent.call_deferred("add_child", fx)
