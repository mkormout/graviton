class_name GausscannonBullet
extends Bullet

@export var impact_scene: PackedScene

func collision(body) -> void:
	_spawn_impact(global_position)
	super.collision(body)

func _spawn_impact(pos: Vector2) -> void:
	if not impact_scene or not spawn_parent:
		return
	var fx = PoolManager.acquire(impact_scene)
	fx.global_position = pos
	spawn_parent.call_deferred("add_child", fx)
	# _pool_reset set emitting=false; replay the CPUParticles2D burst.
	if fx is CPUParticles2D:
		(fx as CPUParticles2D).restart()
